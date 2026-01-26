# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name SwarmSystem
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")
const SimTuning := preload("res://scripts/sim/sim_tuning.gd")

const SWARM_SPEED_MULT := 2.0
const SWARM_MAX_START := 5
const SWARM_PICKUP_HALF_PX: float = 10.0
const SWARM_PICKUP_RADIUS_PX: float = SWARM_PICKUP_HALF_PX * 2.0
const SWARM_SHOCK_MS: int = 2000
const EDGE_MIN_DIST_PX := 1.0

var state: GameState = null
var swarm_packets: Array = []
var _next_swarm_id: int = 1

func bind_state(state_ref: GameState) -> void:
	state = state_ref
	swarm_packets.clear()
	_next_swarm_id = 1
	if state != null:
		state.swarm_packets = swarm_packets

func tick(dt: float, unit_system: UnitSystem) -> void:
	if state == null:
		return
	if OpsState.has_outcome():
		return
	_consume_swarm_requests()
	_update_swarms(dt, unit_system)

func _consume_swarm_requests() -> void:
	var queue: Array = state.swarm_requests
	if queue.is_empty():
		return
	for req in queue:
		if typeof(req) != TYPE_DICTIONARY:
			continue
		var d := req as Dictionary
		var src_id := int(d.get("src", -1))
		var dst_id := int(d.get("dst", -1))
		_spawn_swarm(src_id, dst_id)
	queue.clear()

func _spawn_swarm(src_id: int, dst_id: int) -> void:
	if src_id <= 0 or dst_id <= 0 or state == null:
		return
	var lane_index := state.lane_index_between(src_id, dst_id)
	if lane_index == -1:
		_log_swarm_ignored(src_id, dst_id, "no_lane")
		return
	var lane_any: Variant = state.lanes[lane_index]
	if not (lane_any is LaneData):
		_log_swarm_ignored(src_id, dst_id, "no_lane")
		return
	var lane := lane_any as LaneData
	var from_is_a := false
	if src_id == int(lane.a_id) and dst_id == int(lane.b_id):
		from_is_a = true
	elif src_id == int(lane.b_id) and dst_id == int(lane.a_id):
		from_is_a = false
	else:
		_log_swarm_ignored(src_id, dst_id, "no_lane")
		return
	var send_enabled := bool(lane.send_a if from_is_a else lane.send_b)
	if not send_enabled:
		_log_swarm_ignored(src_id, dst_id, "not_enabled")
		return
	var from_hive: HiveData = state.find_hive_by_id(src_id)
	var to_hive: HiveData = state.find_hive_by_id(dst_id)
	if from_hive == null or to_hive == null:
		_log_swarm_ignored(src_id, dst_id, "no_lane")
		return
	var owner_id := int(from_hive.owner_id)
	if owner_id <= 0:
		_log_swarm_ignored(src_id, dst_id, "not_enabled")
		return
	var power_before := int(from_hive.power)
	if power_before <= 1:
		_log_swarm_ignored(src_id, dst_id, "no_power")
		return
	var start_count := clampi(power_before - 1, 1, SWARM_MAX_START)
	var power_after := power_before - start_count
	from_hive.power = power_after
	if state.hive_spawn_block_until_us == null:
		state.hive_spawn_block_until_us = {}
	var now_us: int = int(state._sim_time_us)
	var block_until_us: int = now_us + (SWARM_SHOCK_MS * 1000)
	state.hive_spawn_block_until_us[src_id] = block_until_us
	SFLog.info("SWARM_SHOCK_APPLY", {
		"src": src_id,
		"until_us": block_until_us,
		"ms": SWARM_SHOCK_MS
	})

	var edge_points := _edge_points(int(lane.a_id), int(lane.b_id))
	if edge_points.is_empty():
		_log_swarm_ignored(src_id, dst_id, "no_lane")
		return
	var a_edge: Vector2 = edge_points[0]
	var b_edge: Vector2 = edge_points[1]
	var dir := 1 if from_is_a else -1
	var t := 0.0 if from_is_a else 1.0

	var packet := {
		"id": _next_swarm_id,
		"lane_id": int(lane.id),
		"a_id": int(lane.a_id),
		"b_id": int(lane.b_id),
		"from_id": src_id,
		"to_id": dst_id,
		"owner_id": owner_id,
		"count": start_count,
		"dir": dir,
		"t": t,
		"from_pos": a_edge,
		"to_pos": b_edge,
		"pos": a_edge.lerp(b_edge, t)
	}
	_next_swarm_id += 1
	swarm_packets.append(packet)
	SFLog.info("SWARM_SPAWN", {
		"swarm_id": int(packet.get("id", -1)),
		"lane_id": int(lane.id),
		"side": "A" if from_is_a else "B",
		"src": src_id,
		"dst": dst_id,
		"start_count": start_count,
		"src_power_before": power_before,
		"src_power_after": power_after
	})

func _update_swarms(dt: float, unit_system: UnitSystem) -> void:
	if swarm_packets.is_empty():
		return
	var speed_px := float(SimTuning.UNIT_SPEED_PX_PER_SEC) * SWARM_SPEED_MULT
	for i in range(swarm_packets.size() - 1, -1, -1):
		var packet: Dictionary = swarm_packets[i]
		var from_pos_v: Variant = packet.get("from_pos")
		var to_pos_v: Variant = packet.get("to_pos")
		if not (from_pos_v is Vector2 and to_pos_v is Vector2):
			continue
		var from_pos: Vector2 = from_pos_v
		var to_pos: Vector2 = to_pos_v
		var lane_len := from_pos.distance_to(to_pos)
		if lane_len <= 0.001:
			_apply_swarm_arrival(packet, unit_system)
			swarm_packets.remove_at(i)
			continue
		var dir: int = int(packet.get("dir", 1))
		var prev_t: float = float(packet.get("t", 0.0))
		var delta_t := (speed_px * dt) / lane_len
		var next_t := clampf(prev_t + (float(dir) * delta_t), 0.0, 1.0)
		packet["t"] = next_t
		packet["pos"] = from_pos.lerp(to_pos, next_t)

		if unit_system != null:
			var lane_id: int = int(packet.get("lane_id", -1))
			var owner_id: int = int(packet.get("owner_id", 0))
			var swarm_dir: int = dir
			var side: String = "A" if swarm_dir >= 0 else "B"
			var candidates_lane: int = 0
			var candidates_owner: int = 0
			var candidates_dir: int = 0
			var units_arr: Array = unit_system.units
			for unit_any in units_arr:
				if typeof(unit_any) != TYPE_DICTIONARY:
					continue
				var unit: Dictionary = unit_any as Dictionary
				if int(unit.get("lane_id", -1)) != lane_id:
					continue
				candidates_lane += 1
				if int(unit.get("owner_id", 0)) != owner_id:
					continue
				candidates_owner += 1
				var unit_dir: int = unit_system._unit_dir(unit)
				if unit_dir == swarm_dir:
					candidates_dir += 1
			packet["prev_px"] = prev_t * lane_len
			packet["next_px"] = next_t * lane_len
			var prev_px: float = float(packet.get("prev_px", 0.0))
			var next_px: float = float(packet.get("next_px", 0.0))
			var band_min_px: float = minf(prev_px, next_px) - SWARM_PICKUP_HALF_PX
			var band_max_px: float = maxf(prev_px, next_px) + SWARM_PICKUP_HALF_PX
			var picked := unit_system.scoop_units_for_swarm(
				int(packet.get("from_id", -1)),
				int(packet.get("to_id", -1)),
				owner_id,
				lane_id,
				prev_t,
				next_t,
				swarm_dir,
				band_min_px,
				band_max_px,
				lane_len
			)
			if picked > 0:
				var new_count := int(packet.get("count", 0)) + picked
				packet["count"] = new_count
				SFLog.info("SWARM_PICKUP", {
					"swarm_id": int(packet.get("id", -1)),
					"lane_id": lane_id,
					"picked": picked,
					"new_count": new_count,
					"band_min_px": band_min_px,
					"band_max_px": band_max_px
				})
			SFLog.info("SWARM_PICKUP_SCAN", {
				"swarm_id": int(packet.get("id", -1)),
				"lane_id": lane_id,
				"side": side,
				"swarm_dir": swarm_dir,
				"candidates_lane": candidates_lane,
				"candidates_owner": candidates_owner,
				"candidates_dir": candidates_dir,
				"picked": picked,
				"count_after": int(packet.get("count", 0))
			})

		var arrived := (dir >= 0 and next_t >= 1.0) or (dir < 0 and next_t <= 0.0)
		if arrived:
			_apply_swarm_arrival(packet, unit_system)
			swarm_packets.remove_at(i)
		else:
			swarm_packets[i] = packet

func _apply_swarm_arrival(packet: Dictionary, unit_system: UnitSystem) -> void:
	var count := int(packet.get("count", 0))
	if count <= 0:
		return
	var dst_id := int(packet.get("to_id", -1))
	if unit_system != null:
		var unit := {
			"from_id": int(packet.get("from_id", -1)),
			"to_id": dst_id,
			"owner_id": int(packet.get("owner_id", -1)),
			"amount": count,
			"lane_id": int(packet.get("lane_id", -1)),
			"a_id": int(packet.get("a_id", -1)),
			"b_id": int(packet.get("b_id", -1)),
			"dir": int(packet.get("dir", 1)),
			"skip_pressure": true,
			"arrive_source": "swarm_system"
		}
		unit_system._apply_unit_arrival(unit)
	SFLog.info("SWARM_ARRIVE", {
		"swarm_id": int(packet.get("id", -1)),
		"dst": dst_id,
		"count": count
	})

func _edge_points(a_id: int, b_id: int) -> Array:
	if state == null:
		return []
	var a_pos := state.hive_world_pos_by_id(a_id)
	var b_pos := state.hive_world_pos_by_id(b_id)
	var dir_vec := b_pos - a_pos
	if dir_vec.length_squared() <= 0.0001:
		dir_vec = Vector2.RIGHT
	else:
		dir_vec = dir_vec.normalized()
	var start_edge := a_pos + dir_vec * GameState.HIVE_RADIUS_PX
	var end_edge := b_pos - dir_vec * GameState.HIVE_RADIUS_PX
	if start_edge.distance_to(end_edge) < EDGE_MIN_DIST_PX:
		end_edge = start_edge
	return [start_edge, end_edge]

func _log_swarm_ignored(src_id: int, dst_id: int, reason: String) -> void:
	SFLog.info("SWARM_IGNORED", {
		"src": src_id,
		"dst": dst_id,
		"reason": reason
	})
