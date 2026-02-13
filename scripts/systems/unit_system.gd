# NOTE: Update unit motion to travel-time based t, resolve opposite-lane collisions, and keep debug logs gated.
# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name UnitSystem
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")
const MapSchema := preload("res://scripts/maps/map_schema.gd")
const SimTuning := preload("res://scripts/sim/sim_tuning.gd")
const SimEvents := preload("res://scripts/sim/sim_events.gd")
const HiveNodeScript := preload("res://scripts/hive/hive_node.gd")

const BASE_MS := 1000.0
const PER_POWER_MS := 2.0
const BONUS_10_MS := 2.0
const BONUS_25_MS := 2.0
const MIN_MS := 250.0
const MAX_SPAWNS_PER_TICK := 5
const UNIT_RADIUS_PX := 0.0
const EDGE_MIN_DIST_PX := 1.0
const ARRIVE_EPS_PX := 0.5
const ARRIVE_EPS_T: float = 0.995
const PASS_THROUGH_EMIT_RATE_MULT: float = 2.0
const PASS_THROUGH_PIPELINE_MULT: float = 1.25
const PASS_THROUGH_LOG_INTERVAL_MS: int = 1000

var state: GameState = null
var units: Array = []
var units_set_version: int = 0
var unit_id_counter := 1
var sim_time_us := 0
var spawn_accum_by_lane: Dictionary = {}
var _next_external_unit_id := 1
var render_units: Array[Dictionary] = []
var _next_uid: int = 1
var win_system: WinSystem = null
var debug_unit_speed_log: bool = false
var debug_unit_tick_log: bool = false
var debug_collisions: bool = false
var use_lane_system_spawns: bool = true
var _last_unit_speed_log_ms: int = 0
var _last_unit_tick_log_ms: int = 0
var _last_unit_speed_id: int = -1
var _last_unit_speed_pos: Vector2 = Vector2.ZERO
var _last_pressure_warn_ms: Dictionary = {}
var _in_owner_update: bool = false
var _sim_events: SimEvents = null
var _lane_gate_block_log_ms: Dictionary = {}
var _lane_gate_open_logged: Dictionary = {}
var _last_lane_cap_block_ms: Dictionary = {}
var _last_units_set_count: int = -1
var _last_units_set_sig: int = 0
var _pass_through_queue_by_key: Dictionary = {}
var _pass_through_emit_accum_ms_by_key: Dictionary = {}
var _pass_through_last_log_ms_by_key: Dictionary = {}

const UNIT_SPEED_LOG_INTERVAL_MS := 1000
const PRESSURE_WARN_INTERVAL_MS := 1000
const UNIT_GATE_LOG_INTERVAL_MS := 500
const LANE_CAP_LOG_INTERVAL_MS := 1000

func setup(_sim_tuning: SimTuning = null) -> void:
	return

func bind_state(state_ref: GameState) -> void:
	state = state_ref
	SFLog.allow_tag("HIVE_FLIP")
	units.clear()
	units_set_version = 0
	_last_units_set_count = -1
	_last_units_set_sig = 0
	render_units.clear()
	unit_id_counter = 1
	_next_uid = 1
	sim_time_us = 0
	spawn_accum_by_lane.clear()
	_lane_gate_block_log_ms.clear()
	_lane_gate_open_logged.clear()
	_last_lane_cap_block_ms.clear()
	_pass_through_queue_by_key.clear()
	_pass_through_emit_accum_ms_by_key.clear()
	_pass_through_last_log_ms_by_key.clear()
	if state != null:
		state.unit_system = self
		state.units_set_version = units_set_version
		state.units_by_lane.clear()
		state.units_by_lane["_all"] = units

func set_sim_events(sim_events: SimEvents) -> void:
	_sim_events = sim_events

func tick(dt: float) -> void:
	if state == null:
		return
	sim_time_us += int(round(dt * 1000000.0))
	_process_lane_retract_requests()
	if not use_lane_system_spawns:
		_spawn_units(dt)
	_update_units(dt)
	resolve_lane_interactions(state, sim_time_us)
	_process_arrivals()
	_drain_pass_through_queues(dt)
	_sync_units_to_state()

func _spawn_units(dt: float) -> void:
	if state == null:
		return
	var dt_ms := dt * 1000.0
	var spawn_ids := _spawn_ids()
	for lane in state.lanes:
		var ld: LaneData = lane
		var a: HiveData = state.find_hive_by_id(int(ld.a_id))
		var b: HiveData = state.find_hive_by_id(int(ld.b_id))
		if a == null or b == null:
			continue
		var lane_len := _lane_length(ld)
		if ld.send_a and int(a.owner_id) > 0 and _spawn_allowed(spawn_ids, int(a.id)):
			if _lane_established(ld, true, lane_len):
				_accum_spawn(ld, true, a, b, dt_ms)
			else:
				_log_unit_gate_blocked(int(ld.id), int(a.id), int(b.id), "build", float(ld.build_t))
		if ld.send_b and int(b.owner_id) > 0 and _spawn_allowed(spawn_ids, int(b.id)):
			if _lane_established(ld, false, lane_len):
				_accum_spawn(ld, false, b, a, dt_ms)
			else:
				_log_unit_gate_blocked(int(ld.id), int(b.id), int(a.id), "build", float(ld.build_t))

func _accum_spawn(lane: LaneData, from_is_a: bool, from_hive: HiveData, to_hive: HiveData, dt_ms: float) -> void:
	var lane_id := int(lane.id)
	var side := "a" if from_is_a else "b"
	var key := "%d:%s" % [lane_id, side]
	var accum := float(spawn_accum_by_lane.get(key, 0.0))
	accum += dt_ms
	var interval_ms := _spawn_interval_ms_for_power(int(from_hive.power))
	var lane_cap := _lane_hard_cap_units(_lane_length(lane))
	var spawned := 0
	while accum >= interval_ms and spawned < MAX_SPAWNS_PER_TICK:
		var pressure := _lane_side_pressure(lane, from_is_a)
		if pressure >= float(lane_cap):
			accum = minf(accum, interval_ms)
			_log_lane_cap_blocked(
				lane_id,
				int(from_hive.id),
				int(to_hive.id),
				("A" if from_is_a else "B"),
				pressure,
				lane_cap
			)
			break
		accum -= interval_ms
		_spawn_unit(from_hive, to_hive, lane, from_is_a)
		spawned += 1
	spawn_accum_by_lane[key] = accum

func _spawn_unit(from_hive: HiveData, to_hive: HiveData, lane: LaneData, from_is_a: bool) -> void:
	if state == null:
		return
	var a_hive: HiveData = state.find_hive_by_id(int(lane.a_id))
	var b_hive: HiveData = state.find_hive_by_id(int(lane.b_id))
	if a_hive == null or b_hive == null:
		return
	_log_unit_gate_open_once(
		int(lane.id),
		int(from_hive.id),
		int(to_hive.id),
		float(lane.build_t)
	)
	var edge_points := _edge_points(a_hive, b_hive)
	if edge_points.is_empty():
		return
	var unit_id := unit_id_counter
	var a_pos: Vector2 = edge_points[0]
	var b_pos: Vector2 = edge_points[1]
	var dir := 1 if from_is_a else -1
	var t := 0.0 if from_is_a else 1.0
	var pos := a_pos.lerp(b_pos, t)
	var unit := {
		"id": unit_id,
		"from_id": int(from_hive.id),
		"to_id": int(to_hive.id),
		"owner_id": int(from_hive.owner_id),
		"amount": 1,
		"lane_id": int(lane.id),
		"a_id": int(lane.a_id),
		"b_id": int(lane.b_id),
		"lane_key": state.lane_key(int(lane.a_id), int(lane.b_id)),
		"dir": dir,
		"t": t,
		"from_pos": a_pos,
		"to_pos": b_pos,
		"pos": pos
	}
	unit_id_counter += 1
	if SFLog.verbose_sim:
		SFLog.info("UNIT_SPAWN", {
			"iid": int(state.iid),
			"unit_id": unit_id,
			"lane_id": int(lane.id),
			"owner_id": int(from_hive.owner_id),
			"from_id": int(from_hive.id),
			"to_id": int(to_hive.id)
		})
	if a_pos.distance_to(b_pos) <= ARRIVE_EPS_PX:
		_adjust_lane_pressure(int(lane.id), from_is_a, 1)
		unit["t"] = 1.0 if from_is_a else 0.0
		unit["pos"] = b_pos if from_is_a else a_pos
		_apply_unit_arrival(unit)
		return
	_adjust_lane_pressure(int(lane.id), from_is_a, 1)
	units.append(unit)
	_sync_units_to_state()

func _update_units(dt: float) -> void:
	if units.is_empty():
		return
	var delta_px := float(SimTuning.UNIT_SPEED_PX_PER_SEC) * dt
	for i in range(units.size()):
		var unit: Dictionary = units[i] as Dictionary
		unit = _ensure_unit_edges(unit)
		var dir := _unit_dir(unit)
		var lane_len := _unit_lane_len(unit)
		if lane_len <= 0.001:
			units[i] = unit
			continue
		var delta_t := delta_px / lane_len
		var t := clampf(float(unit.get("t", 0.0)) + (float(dir) * delta_t), 0.0, 1.0)
		unit["t"] = t
		unit = _update_unit_pos_from_t(unit)
		units[i] = unit

func resolve_lane_interactions(state_ref: GameState, now_us: int) -> void:
	if units.is_empty():
		return
	if state_ref == null:
		return
	var lanes: Dictionary = {}
	for i in range(units.size()):
		var unit: Dictionary = units[i] as Dictionary
		var lane_id := int(unit.get("lane_id", -1))
		if lane_id <= 0:
			continue
		var entry: Dictionary = lanes.get(lane_id, {"ab": [], "ba": []})
		var dir := _unit_dir(unit)
		if dir >= 0:
			(entry["ab"] as Array).append(i)
		else:
			(entry["ba"] as Array).append(i)
		lanes[lane_id] = entry

	var remove_indices: Array[int] = []
	var remove_set: Dictionary = {}

	for lane_id in lanes.keys():
		var entry: Dictionary = lanes[lane_id]
		var ab: Array = entry.get("ab", [])
		var ba: Array = entry.get("ba", [])
		if ab.is_empty() or ba.is_empty():
			continue
		ab.sort_custom(Callable(self, "_sort_unit_index_by_t"))
		ba.sort_custom(Callable(self, "_sort_unit_index_by_t"))
		while not ab.is_empty() and not ba.is_empty():
			var a_idx := int(ab[ab.size() - 1])
			var b_idx := int(ba[0])
			if remove_set.has(a_idx):
				ab.pop_back()
				continue
			if remove_set.has(b_idx):
				ba.pop_front()
				continue
			var a: Dictionary = units[a_idx]
			var b: Dictionary = units[b_idx]
			var lane_len := _unit_lane_len(a)
			if lane_len <= 0.001:
				lane_len = _unit_lane_len(b)
			if lane_len <= 0.001:
				break
			var a_t := float(a.get("t", 0.0))
			var b_t := float(b.get("t", 0.0))
			if a_t < b_t:
				break
			var a_owner := int(a.get("owner_id", 0))
			var b_owner := int(b.get("owner_id", 0))
			var a_amt: int = int(a.get("amount", 0))
			var b_amt: int = int(b.get("amount", 0))
			var collision_t := clampf((a_t + b_t) * 0.5, 0.0, 1.0)
			if _are_allied_owners(a_owner, b_owner):
				var keep_ab := a_t >= (1.0 - b_t)
				if keep_ab:
					a_amt += b_amt
					_adjust_lane_pressure(int(lane_id), true, b_amt)
					_adjust_lane_pressure(int(lane_id), false, -b_amt)
					a["amount"] = a_amt
					a["t"] = collision_t
					a = _update_unit_pos_from_t(a)
					units[a_idx] = a
					_mark_unit_remove(b_idx, remove_indices, remove_set)
					ba.pop_front()
					if debug_collisions:
						SFLog.info("UNIT_MERGE", {"lane_id": lane_id, "keep": "ab", "amount": a_amt})
				else:
					b_amt += a_amt
					_adjust_lane_pressure(int(lane_id), true, -a_amt)
					_adjust_lane_pressure(int(lane_id), false, a_amt)
					b["amount"] = b_amt
					b["t"] = collision_t
					b = _update_unit_pos_from_t(b)
					units[b_idx] = b
					_mark_unit_remove(a_idx, remove_indices, remove_set)
					ab.pop_back()
					if debug_collisions:
						SFLog.info("UNIT_MERGE", {"lane_id": lane_id, "keep": "ba", "amount": b_amt})
				continue
			var a_before := a_amt
			var b_before := b_amt
			var kill: int = min(a_amt, b_amt)
			a_amt -= kill
			b_amt -= kill
			if kill > 0:
				_adjust_lane_pressure(int(lane_id), true, -kill)
				_adjust_lane_pressure(int(lane_id), false, -kill)
				OpsState.add_units_killed(a_owner, kill)
				OpsState.add_units_killed(b_owner, kill)
			a["amount"] = a_amt
			b["amount"] = b_amt
			a["t"] = collision_t
			b["t"] = collision_t
			a = _update_unit_pos_from_t(a)
			b = _update_unit_pos_from_t(b)
			units[a_idx] = a
			units[b_idx] = b
			if kill > 0:
				var front_t: float = float(collision_t)
				var from_pos_v: Variant = a.get("from_pos")
				var to_pos_v: Variant = a.get("to_pos")
				var p0: Vector2 = Vector2.ZERO
				var p1: Vector2 = Vector2.ZERO
				var has_geom: bool = false
				if from_pos_v is Vector2 and to_pos_v is Vector2:
					p0 = from_pos_v
					p1 = to_pos_v
					has_geom = true
				else:
					from_pos_v = b.get("from_pos")
					to_pos_v = b.get("to_pos")
					if from_pos_v is Vector2 and to_pos_v is Vector2:
						p0 = from_pos_v
						p1 = to_pos_v
						has_geom = true
				var impact: Vector2 = Vector2.ZERO
				var lane_dir: Vector2 = Vector2.RIGHT
				if has_geom:
					impact = p0.lerp(p1, front_t)
					var dir_vec: Vector2 = p1 - p0
					if dir_vec.length_squared() > 0.000001:
						lane_dir = dir_vec.normalized()
					if debug_collisions:
						SFLog.info("UNIT_COLLISION_GEOM", {
							"lane_id": lane_id,
							"p0": p0,
							"p1": p1,
							"front_t": front_t,
							"impact": impact,
							"at_us": now_us
						})
				else:
					var a_pos_any: Variant = a.get("pos", Vector2.ZERO)
					var b_pos_any: Variant = b.get("pos", Vector2.ZERO)
					var a_pos: Vector2 = a_pos_any if a_pos_any is Vector2 else Vector2.ZERO
					var b_pos: Vector2 = b_pos_any if b_pos_any is Vector2 else Vector2.ZERO
					impact = (a_pos + b_pos) * 0.5
					var fallback_dir: Vector2 = b_pos - a_pos
					if fallback_dir.length_squared() > 0.000001:
						lane_dir = fallback_dir.normalized()
				if _sim_events != null:
					var vfx_intensity: float = clampf(float(kill) * 0.5, 0.6, 2.0)
					_sim_events.emit_signal(
						"unit_collision",
						impact,
						lane_dir,
						a_owner,
						b_owner,
						int(lane_id),
						vfx_intensity
					)
					var death_intensity: float = clampf(float(kill) * 0.55, 0.7, 2.0)
					_emit_unit_death_event(a, "collision", death_intensity, impact, lane_dir)
					_emit_unit_death_event(b, "collision", death_intensity, impact, lane_dir)
				if debug_collisions:
					SFLog.info("UNIT_COLLISION_PRE", {
						"lane_id": lane_id,
						"a_before": a_before,
						"b_before": b_before,
						"kill": kill,
						"at_us": now_us,
						"front_t": front_t
					})
					SFLog.info("UNIT_COLLISION_POST", {
						"lane_id": lane_id,
						"a_after": a_amt,
						"b_after": b_amt,
						"killed": kill,
						"at_us": now_us,
						"front_t": collision_t
					})
			if a_amt <= 0:
				_mark_unit_remove(a_idx, remove_indices, remove_set)
				ab.pop_back()
			if b_amt <= 0:
				_mark_unit_remove(b_idx, remove_indices, remove_set)
				ba.pop_front()

	if not remove_indices.is_empty():
		remove_indices.sort()
		for i in range(remove_indices.size() - 1, -1, -1):
			units.remove_at(remove_indices[i])

func _unit_dir(unit: Dictionary) -> int:
	var dir := int(unit.get("dir", 0))
	if dir != 0:
		return dir
	var from_id := int(unit.get("from_id", -1))
	var a_id := int(unit.get("a_id", -1))
	var b_id := int(unit.get("b_id", -1))
	if from_id > 0 and a_id > 0 and b_id > 0:
		return 1 if from_id == a_id else -1
	return 1

func _unit_lane_len(unit: Dictionary) -> float:
	var from_pos_v: Variant = unit.get("from_pos")
	var to_pos_v: Variant = unit.get("to_pos")
	if from_pos_v is Vector2 and to_pos_v is Vector2:
		return (from_pos_v as Vector2).distance_to(to_pos_v as Vector2)
	return 0.0

func _update_unit_pos_from_t(unit: Dictionary) -> Dictionary:
	var from_pos_v: Variant = unit.get("from_pos")
	var to_pos_v: Variant = unit.get("to_pos")
	if from_pos_v is Vector2 and to_pos_v is Vector2:
		var from_pos: Vector2 = from_pos_v
		var to_pos: Vector2 = to_pos_v
		var t := clampf(float(unit.get("t", 0.0)), 0.0, 1.0)
		unit["pos"] = from_pos.lerp(to_pos, t)
	return unit

func scoop_units_for_swarm(
	from_id: int,
	to_id: int,
	owner_id: int,
	lane_id: int,
	prev_t: float,
	curr_t: float,
	swarm_dir: int = 0,
	band_min_px: float = -1.0,
	band_max_px: float = -1.0,
	lane_len_px: float = 0.0
) -> int:
	if units.is_empty() or owner_id <= 0:
		return 0
	var scooped := 0
	var min_t: float = minf(prev_t, curr_t)
	var max_t: float = maxf(prev_t, curr_t)
	var desired_dir: int = swarm_dir
	if desired_dir == 0 and lane_id > 0:
		var lane := _find_lane_by_id(lane_id)
		if lane != null:
			if from_id == int(lane.a_id) and to_id == int(lane.b_id):
				desired_dir = 1
			elif from_id == int(lane.b_id) and to_id == int(lane.a_id):
				desired_dir = -1
	for i in range(units.size() - 1, -1, -1):
		var unit: Dictionary = units[i] as Dictionary
		if int(unit.get("owner_id", 0)) != owner_id:
			continue
		if lane_id > 0 and int(unit.get("lane_id", -1)) != lane_id:
			continue
		var unit_dir: int = _unit_dir(unit)
		if desired_dir != 0 and unit_dir != desired_dir:
			continue
		var t := float(unit.get("t", 0.0))
		if band_min_px >= 0.0 and band_max_px >= 0.0 and lane_len_px > 0.0:
			var unit_px := t * lane_len_px
			if unit_px < band_min_px or unit_px > band_max_px:
				continue
		else:
			if t < min_t or t > max_t:
				continue
		var amount: int = int(unit.get("amount", 1))
		if amount > 0:
			var from_is_a := _unit_dir(unit) >= 0
			_adjust_lane_pressure(lane_id, from_is_a, -amount)
			scooped += amount
		units.remove_at(i)
	if scooped > 0:
		_sync_units_to_state()
	return scooped

func _find_lane_by_id(lane_id: int) -> LaneData:
	if state == null or lane_id <= 0:
		return null
	for lane in state.lanes:
		if lane is LaneData:
			var ld := lane as LaneData
			if int(ld.id) == lane_id:
				return ld
	return null

func _adjust_lane_pressure(lane_id: int, from_is_a: bool, delta: int) -> void:
	if state == null or delta == 0:
		return
	var lane := _find_lane_by_id(lane_id)
	if lane == null:
		return
	if from_is_a:
		var next := float(lane.a_pressure) + float(delta)
		if next < 0.0:
			_warn_pressure_underflow(lane_id, "A", float(lane.a_pressure), delta)
			next = 0.0
		lane.a_pressure = next
	else:
		var next := float(lane.b_pressure) + float(delta)
		if next < 0.0:
			_warn_pressure_underflow(lane_id, "B", float(lane.b_pressure), delta)
			next = 0.0
		lane.b_pressure = next

func _warn_pressure_underflow(lane_id: int, side: String, current: float, delta: int) -> void:
	var key := "%d:%s" % [lane_id, side]
	var now_ms := Time.get_ticks_msec()
	var last_ms := int(_last_pressure_warn_ms.get(key, 0))
	if now_ms - last_ms < PRESSURE_WARN_INTERVAL_MS:
		return
	_last_pressure_warn_ms[key] = now_ms
	SFLog.warn("LANE_PRESSURE_UNDERFLOW", {
		"lane_id": lane_id,
		"side": side,
		"current": current,
		"delta": delta
	})

func _mark_unit_remove(idx: int, remove_indices: Array[int], remove_set: Dictionary) -> void:
	if remove_set.has(idx):
		return
	remove_set[idx] = true
	remove_indices.append(idx)

func _sort_unit_index_by_t(a: int, b: int) -> bool:
	var ua: Dictionary = units[a]
	var ub: Dictionary = units[b]
	var ta := float(ua.get("t", 0.0))
	var tb := float(ub.get("t", 0.0))
	if ta == tb:
		return int(ua.get("id", 0)) < int(ub.get("id", 0))
	return ta < tb

func _are_allied_owners(owner_a: int, owner_b: int) -> bool:
	var a_id: int = int(owner_a)
	var b_id: int = int(owner_b)
	if a_id <= 0 or b_id <= 0:
		return false
	if OpsState != null and OpsState.has_method("are_allies"):
		return bool(OpsState.call("are_allies", a_id, b_id))
	return a_id == b_id

func _apply_unit_arrival(unit: Dictionary) -> void:
	if state == null:
		return
	var owner_id := int(unit.get("owner_id", 0))
	var to_id := int(unit.get("to_id", -1))
	if owner_id <= 0 or to_id <= 0:
		return
	var hive: HiveData = state.find_hive_by_id(to_id)
	if hive == null:
		return
	if _in_owner_update:
		SFLog.error("REENTRANT_OWNER_UPDATE", {
			"to_id": to_id,
			"owner_id": owner_id,
			"stack": get_stack()
		})
		return
	_in_owner_update = true
	var amount: int = int(unit.get("amount", 1))
	var skip_pressure := bool(unit.get("skip_pressure", false))
	if amount > 0 and not skip_pressure:
		var from_is_a := _unit_dir(unit) >= 0
		_adjust_lane_pressure(int(unit.get("lane_id", -1)), from_is_a, -amount)
	OpsState.add_units_landed(owner_id, amount)
	var before_owner := int(hive.owner_id)
	var before_power := int(hive.power)
	var friendly_arrival: bool = _are_allied_owners(before_owner, owner_id)
	var pass_owner: int = owner_id if owner_id > 0 else before_owner
	if friendly_arrival and before_owner > 0:
		pass_owner = before_owner
	var arrive_source: String = str(unit.get("arrive_source", "unit_system"))
	if _sim_events != null and arrive_source != "recall":
		var impact_kind: String = "feed"
		var impact_intensity: float = 0.6
		if not friendly_arrival:
			impact_kind = "attack"
			impact_intensity = 1.0
		var impact_pos: Vector2 = _arrival_impact_world_pos(unit, to_id)
		var impact_dir: Vector2 = _arrival_impact_dir(unit)
		var impact_lane_id: int = int(unit.get("lane_id", -1))
		var impact_unit_id: int = int(unit.get("id", -1))
		_sim_events.emit_signal(
			"unit_impact",
			impact_kind,
			impact_pos,
			impact_dir,
			owner_id,
			impact_intensity,
			impact_lane_id,
			impact_unit_id,
			to_id
		)
	if friendly_arrival:
		var before_power_same_owner: int = int(hive.power)
		var raw_after: int = before_power_same_owner + amount
		hive.power = min(SimTuning.MAX_POWER, raw_after)
		if before_power_same_owner >= SimTuning.MAX_POWER:
			_pass_through_arrival(hive, pass_owner, amount)
		else:
			var overflow: int = maxi(0, raw_after - SimTuning.MAX_POWER)
			if overflow > 0:
				_pass_through_arrival(hive, pass_owner, overflow)
	else:
		hive.power -= amount
		if hive.power <= 0:
			hive.owner_id = owner_id
			hive.power = clampi(SimTuning.CAPTURE_START_POWER, 1, SimTuning.MAX_POWER)
			if state.has_method("_clear_all_outgoing_from"):
				state.call("_clear_all_outgoing_from", int(hive.id))
		else:
			hive.power = clampi(int(hive.power), 1, SimTuning.MAX_POWER)
	var after_owner := int(hive.owner_id)
	var after_power := int(hive.power)
	if before_owner != after_owner:
		SFLog.warn("HIVE_FLIP", {
			"hive_id": to_id,
			"from": before_owner,
			"to": after_owner,
			"after_power": after_power
		})
		if win_system != null and win_system.has_method("notify_hive_owner_changed"):
			win_system.notify_hive_owner_changed()
		elif state.has_method("evaluate_full_control_win"):
			state.call("evaluate_full_control_win")
	var side := "A" if _unit_dir(unit) >= 0 else "B"
	if SFLog.verbose_sim:
		SFLog.throttled_info("ARRIVE_APPLY", {
			"lane_id": int(unit.get("lane_id", -1)),
			"side": side,
			"src": int(unit.get("from_id", -1)),
			"dst": to_id,
			"amount": amount,
			"owner": owner_id,
			"before_owner": before_owner,
			"before_power": before_power,
			"after_owner": after_owner,
			"after_power": after_power,
			"arrive_source": arrive_source
		}, 250)
	if arrive_source == "recall":
		SFLog.info("UNIT_RECALL_ARRIVE", {
			"lane_id": int(unit.get("lane_id", -1)),
			"src": int(unit.get("to_id", -1)),
			"owner": owner_id,
			"amount": amount
		})
	_in_owner_update = false

func _pass_through_arrival(hive: HiveData, owner_id: int, payload: int) -> void:
	if state == null or hive == null or owner_id <= 0 or payload <= 0:
		return
	var targets: Array = _pass_through_targets(hive)
	if targets.is_empty():
		return
	var key: int = _pass_through_key(int(hive.id), owner_id)
	var prev_queue: int = int(_pass_through_queue_by_key.get(key, 0))
	_pass_through_queue_by_key[key] = prev_queue + payload

func _pass_through_targets(hive: HiveData) -> Array:
	var outgoing: Array = []
	if state == null or hive == null:
		return outgoing
	var hive_id: int = int(hive.id)
	for lane_any in state.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		if int(lane.a_id) == hive_id and bool(lane.send_a):
			outgoing.append({"target_id": int(lane.b_id), "lane_id": int(lane.id)})
		elif int(lane.b_id) == hive_id and bool(lane.send_b):
			outgoing.append({"target_id": int(lane.a_id), "lane_id": int(lane.id)})
	if outgoing.is_empty():
		return outgoing
	if hive.pass_preferred_targets.is_empty():
		return outgoing
	var preferred: Array = []
	for preferred_target_any in hive.pass_preferred_targets:
		var preferred_target: int = int(preferred_target_any)
		for entry_any in outgoing:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			if int(entry.get("target_id", -1)) == preferred_target:
				preferred.append(entry)
				break
	if preferred.is_empty():
		return outgoing
	return preferred

func _spawn_pass_through_unit(hive: HiveData, owner_id: int, target_id: int, lane_id: int) -> void:
	if hive == null or owner_id <= 0 or target_id <= 0 or lane_id <= 0:
		return
	var lane: LaneData = _find_lane_by_id(lane_id)
	if lane == null:
		return
	var a_id: int = int(lane.a_id)
	var b_id: int = int(lane.b_id)
	var from_id: int = int(hive.id)
	var dir: int = 0
	if from_id == a_id and target_id == b_id:
		dir = 1
	elif from_id == b_id and target_id == a_id:
		dir = -1
	else:
		return
	var pass_unit: Dictionary = {
		"from_id": from_id,
		"to_id": target_id,
		"owner_id": owner_id,
		"amount": 1,
		"lane_id": lane_id,
		"a_id": a_id,
		"b_id": b_id,
		"dir": dir,
		"arrive_source": "pass_through"
	}
	spawn_unit(pass_unit)

func _drain_pass_through_queues(dt: float) -> void:
	if state == null or _pass_through_queue_by_key.is_empty():
		return
	var dt_ms: float = maxf(0.0, dt * 1000.0)
	var keys: Array = _pass_through_queue_by_key.keys()
	keys.sort()
	for key_any in keys:
		var key: int = int(key_any)
		var queued: int = int(_pass_through_queue_by_key.get(key, 0))
		if queued <= 0:
			_pass_through_queue_by_key.erase(key)
			_pass_through_emit_accum_ms_by_key.erase(key)
			_pass_through_last_log_ms_by_key.erase(key)
			continue
		var hive_id: int = _pass_through_key_hive_id(key)
		var owner_id: int = _pass_through_key_owner_id(key)
		var hive: HiveData = state.find_hive_by_id(hive_id)
		if hive == null or int(hive.owner_id) != owner_id:
			_pass_through_queue_by_key.erase(key)
			_pass_through_emit_accum_ms_by_key.erase(key)
			_pass_through_last_log_ms_by_key.erase(key)
			continue
		if int(hive.power) < int(SimTuning.MAX_POWER):
			continue
		var targets: Array = _pass_through_targets(hive)
		if targets.is_empty():
			continue
		var emit_rate: float = _pass_through_emit_rate_units_per_sec(hive)
		var emit_accum_ms: float = float(_pass_through_emit_accum_ms_by_key.get(key, 0.0))
		emit_accum_ms += dt_ms
		var releasable_by_rate: int = int(floor((emit_accum_ms / 1000.0) * emit_rate))
		if releasable_by_rate <= 0:
			_pass_through_emit_accum_ms_by_key[key] = emit_accum_ms
			continue
		var inflight_now: int = _pass_through_inflight_count(hive_id, owner_id)
		var pipeline_cap: int = _pass_through_pipeline_cap_units(hive, emit_rate)
		var pipeline_room: int = maxi(0, pipeline_cap - inflight_now)
		var release_count: int = mini(mini(queued, releasable_by_rate), pipeline_room)
		if release_count <= 0:
			_pass_through_emit_accum_ms_by_key[key] = emit_accum_ms
			_log_pass_through_congested_once_per_sec(key, hive_id, owner_id, queued, inflight_now, pipeline_cap)
			continue
		var target_count: int = targets.size()
		var released: int = 0
		for _i in range(release_count):
			var target_index: int = int(hive.pass_rr_index % target_count)
			var target_any: Variant = targets[target_index]
			if typeof(target_any) != TYPE_DICTIONARY:
				break
			var target: Dictionary = target_any as Dictionary
			var target_id: int = int(target.get("target_id", -1))
			var lane_id: int = int(target.get("lane_id", -1))
			hive.pass_rr_index += 1
			_spawn_pass_through_unit(hive, owner_id, target_id, lane_id)
			released += 1
		if released <= 0:
			_pass_through_emit_accum_ms_by_key[key] = emit_accum_ms
			continue
		queued -= released
		emit_accum_ms = maxf(0.0, emit_accum_ms - (float(released) * (1000.0 / emit_rate)))
		_pass_through_emit_accum_ms_by_key[key] = emit_accum_ms
		if queued > 0:
			_pass_through_queue_by_key[key] = queued
		else:
			_pass_through_queue_by_key.erase(key)
			_pass_through_emit_accum_ms_by_key.erase(key)
			_pass_through_last_log_ms_by_key.erase(key)

func _pass_through_key(hive_id: int, owner_id: int) -> int:
	return int((hive_id << 3) | (owner_id & 0x7))

func _pass_through_key_hive_id(key: int) -> int:
	return int(key >> 3)

func _pass_through_key_owner_id(key: int) -> int:
	return int(key & 0x7)

func _pass_through_emit_rate_units_per_sec(hive: HiveData) -> float:
	if hive == null:
		return 0.0
	var single_interval_ms: float = float(_spawn_interval_ms_for_power(int(hive.power)))
	var single_rate: float = 1000.0 / maxf(1.0, single_interval_ms)
	return maxf(0.0, single_rate * PASS_THROUGH_EMIT_RATE_MULT)

func _pass_through_pipeline_cap_units(hive: HiveData, emit_rate_units_per_sec: float) -> int:
	if hive == null or emit_rate_units_per_sec <= 0.0:
		return 0
	var avg_travel_time_sec: float = _pass_through_avg_travel_time_sec(hive)
	if avg_travel_time_sec <= 0.0:
		avg_travel_time_sec = 1.0
	return maxi(1, int(ceil(emit_rate_units_per_sec * avg_travel_time_sec * PASS_THROUGH_PIPELINE_MULT)))

func _pass_through_avg_travel_time_sec(hive: HiveData) -> float:
	if state == null or hive == null:
		return 0.0
	var targets: Array = _pass_through_targets(hive)
	if targets.is_empty():
		return 0.0
	var speed_px_s: float = maxf(1.0, float(SimTuning.UNIT_SPEED_PX_PER_SEC))
	var travel_sum_s: float = 0.0
	var valid_count: int = 0
	for target_any in targets:
		if typeof(target_any) != TYPE_DICTIONARY:
			continue
		var lane_id: int = int((target_any as Dictionary).get("lane_id", -1))
		var lane: LaneData = _find_lane_by_id(lane_id)
		if lane == null:
			continue
		var lane_len_px: float = _lane_length(lane)
		if lane_len_px <= 0.0:
			continue
		travel_sum_s += lane_len_px / speed_px_s
		valid_count += 1
	if valid_count <= 0:
		return 0.0
	return travel_sum_s / float(valid_count)

func _pass_through_inflight_count(hive_id: int, owner_id: int) -> int:
	if hive_id <= 0 or owner_id <= 0:
		return 0
	var count: int = 0
	for unit_any in units:
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_any as Dictionary
		if str(unit.get("arrive_source", "")) != "pass_through":
			continue
		if int(unit.get("from_id", -1)) != hive_id:
			continue
		if int(unit.get("owner_id", 0)) != owner_id:
			continue
		count += 1
	return count

func _log_pass_through_congested_once_per_sec(key: int, hive_id: int, owner_id: int, queued: int, inflight_now: int, pipeline_cap: int) -> void:
	var now_ms: int = Time.get_ticks_msec()
	var last_ms: int = int(_pass_through_last_log_ms_by_key.get(key, 0))
	if now_ms - last_ms < PASS_THROUGH_LOG_INTERVAL_MS:
		return
	_pass_through_last_log_ms_by_key[key] = now_ms
	SFLog.info("PASS_THROUGH_CONGESTED", {
		"hive_id": hive_id,
		"owner_id": owner_id,
		"queue": queued,
		"inflight": inflight_now,
		"pipeline_cap": pipeline_cap
	})

func _arrival_impact_world_pos(unit: Dictionary, to_hive_id: int) -> Vector2:
	var pos_any: Variant = unit.get("pos", null)
	if pos_any is Vector2:
		return pos_any as Vector2
	if state != null and to_hive_id > 0:
		var hive_center: Vector2 = state.hive_world_pos_by_id(to_hive_id)
		return _lane_anchor_world_from_center(hive_center)
	return Vector2.ZERO

func _arrival_impact_dir(unit: Dictionary) -> Vector2:
	var from_any: Variant = unit.get("from_pos", null)
	var to_any: Variant = unit.get("to_pos", null)
	if from_any is Vector2 and to_any is Vector2:
		var from_pos: Vector2 = from_any as Vector2
		var to_pos: Vector2 = to_any as Vector2
		var dir_vec: Vector2 = to_pos - from_pos
		if dir_vec.length_squared() > 0.000001:
			var travel_dir: Vector2 = dir_vec.normalized()
			if _unit_dir(unit) < 0:
				travel_dir = -travel_dir
			return travel_dir
	return Vector2.RIGHT

func _unit_world_pos(unit: Dictionary) -> Vector2:
	var pos_any: Variant = unit.get("pos", null)
	if pos_any is Vector2:
		return pos_any as Vector2
	var from_any: Variant = unit.get("from_pos", null)
	var to_any: Variant = unit.get("to_pos", null)
	if from_any is Vector2 and to_any is Vector2:
		var t: float = clampf(float(unit.get("t", 0.0)), 0.0, 1.0)
		return (from_any as Vector2).lerp(to_any as Vector2, t)
	return Vector2.ZERO

func _unit_travel_dir(unit: Dictionary) -> Vector2:
	var from_any: Variant = unit.get("from_pos", null)
	var to_any: Variant = unit.get("to_pos", null)
	if from_any is Vector2 and to_any is Vector2:
		var dir_vec: Vector2 = (to_any as Vector2) - (from_any as Vector2)
		if dir_vec.length_squared() > 0.000001:
			var forward: Vector2 = dir_vec.normalized()
			if _unit_dir(unit) < 0:
				forward = -forward
			return forward
	return Vector2.RIGHT

func _emit_unit_death_event(
	unit: Dictionary,
	reason: String,
	intensity: float = 1.0,
	pos_hint: Variant = null,
	dir_hint: Variant = null
) -> void:
	if _sim_events == null:
		return
	var owner_id: int = int(unit.get("owner_id", 0))
	if owner_id <= 0:
		return
	var world_pos: Vector2 = _unit_world_pos(unit)
	if pos_hint is Vector2:
		world_pos = pos_hint as Vector2
	var lane_dir: Vector2 = _unit_travel_dir(unit)
	if dir_hint is Vector2:
		var hint_dir: Vector2 = dir_hint as Vector2
		if hint_dir.length_squared() > 0.000001:
			lane_dir = hint_dir.normalized()
	var lane_id: int = int(unit.get("lane_id", -1))
	var unit_id: int = int(unit.get("id", -1))
	var amount: int = maxi(1, int(unit.get("amount", 1)))
	var vfx_intensity: float = clampf(maxf(intensity, float(amount) * 0.35), 0.5, 2.0)
	_sim_events.emit_signal(
		"unit_death",
		world_pos,
		lane_dir,
		owner_id,
		vfx_intensity,
		lane_id,
		unit_id,
		reason
	)

func _unit_has_arrived(unit: Dictionary) -> bool:
	var dir: int = _unit_dir(unit)
	var t: float = clampf(float(unit.get("t", 0.0)), 0.0, 1.0)
	var arrived_by_t: bool = (dir >= 0 and t >= ARRIVE_EPS_T) or (dir < 0 and t <= (1.0 - ARRIVE_EPS_T))
	if arrived_by_t:
		return true
	var from_pos_v: Variant = unit.get("from_pos", null)
	var to_pos_v: Variant = unit.get("to_pos", null)
	if not (from_pos_v is Vector2 and to_pos_v is Vector2):
		return false
	var from_pos: Vector2 = from_pos_v as Vector2
	var to_pos: Vector2 = to_pos_v as Vector2
	var target_pos: Vector2 = to_pos if dir >= 0 else from_pos
	var pos_v: Variant = unit.get("pos", null)
	var pos: Vector2 = from_pos.lerp(to_pos, t)
	if pos_v is Vector2:
		pos = pos_v as Vector2
	return pos.distance_to(target_pos) <= ARRIVE_EPS_PX

func _process_arrivals() -> void:
	if units.is_empty():
		return
	for i in range(units.size() - 1, -1, -1):
		var unit: Dictionary = units[i] as Dictionary
		if _unit_has_arrived(unit):
			var t: float = clampf(float(unit.get("t", 0.0)), 0.0, 1.0)
			if SFLog.verbose_sim:
				SFLog.info("UNIT_ARRIVED", {
					"unit_id": int(unit.get("id", -1)),
					"lane": int(unit.get("lane_id", -1)),
					"dst": int(unit.get("to_id", -1)),
					"t": snapped(t, 0.001)
				})
			_apply_unit_arrival(unit)
			units.remove_at(i)

func _process_lane_retract_requests() -> void:
	if state == null:
		return
	var requests_v: Variant = state.lane_retract_requests
	if typeof(requests_v) != TYPE_ARRAY:
		return
	var requests: Array = requests_v as Array
	if requests.is_empty():
		return
	for req_any in requests:
		if typeof(req_any) != TYPE_DICTIONARY:
			continue
		var req: Dictionary = req_any as Dictionary
		var lane_id: int = int(req.get("lane_id", -1))
		var from_id: int = int(req.get("from_id", -1))
		var owner_id: int = int(req.get("owner_id", 0))
		if lane_id <= 0 or from_id <= 0:
			continue
		var recalled: int = _recall_units_for_lane(lane_id, from_id, owner_id)
		if recalled > 0:
			SFLog.info("UNIT_RECALL_START", {
				"lane_id": lane_id,
				"src": from_id,
				"owner": owner_id,
				"amount": recalled
			})
	state.lane_retract_requests = []

func _recall_units_for_lane(lane_id: int, from_id: int, owner_id: int) -> int:
	var recalled: int = 0
	for i in range(units.size()):
		var unit: Dictionary = units[i] as Dictionary
		if int(unit.get("lane_id", -1)) != lane_id:
			continue
		if int(unit.get("from_id", -1)) != from_id:
			continue
		if owner_id > 0 and int(unit.get("owner_id", 0)) != owner_id:
			continue
		if bool(unit.get("returning", false)):
			continue
		var amount: int = int(unit.get("amount", 1))
		recalled += amount
		unit = _recall_unit(unit)
		units[i] = unit
	return recalled

func _recall_unit(unit: Dictionary) -> Dictionary:
	var old_from_id: int = int(unit.get("from_id", -1))
	var old_to_id: int = int(unit.get("to_id", -1))
	if old_from_id <= 0 or old_to_id <= 0:
		return unit
	unit["from_id"] = old_to_id
	unit["to_id"] = old_from_id
	var t: float = float(unit.get("t", 0.0))
	unit["t"] = 1.0 - t
	var from_pos_v: Variant = unit.get("from_pos", null)
	var to_pos_v: Variant = unit.get("to_pos", null)
	if from_pos_v is Vector2 and to_pos_v is Vector2:
		unit["from_pos"] = to_pos_v
		unit["to_pos"] = from_pos_v
	var a_id: int = int(unit.get("a_id", -1))
	var b_id: int = int(unit.get("b_id", -1))
	var new_from_id: int = int(unit.get("from_id", -1))
	if new_from_id == a_id:
		unit["dir"] = 1
	elif new_from_id == b_id:
		unit["dir"] = -1
	else:
		unit["dir"] = -int(unit.get("dir", 1))
	unit["returning"] = true
	unit["arrive_source"] = "recall"
	unit["skip_pressure"] = true
	unit = _update_unit_pos_from_t(unit)
	return unit

func apply_tower_hit(victim_unit_id: int, tower_owner_id: int, source_tower_id: int, _now_us: int, tower_pos: Vector2 = Vector2.ZERO, tower_tier: int = -1) -> bool:
	if victim_unit_id <= 0:
		return false
	for i in range(units.size()):
		var unit: Dictionary = units[i] as Dictionary
		if int(unit.get("id", -1)) != victim_unit_id:
			continue
		if tower_owner_id > 0 and _are_allied_owners(int(unit.get("owner_id", 0)), tower_owner_id):
			return false
		var hit_pos: Vector2 = Vector2.ZERO
		var pos_v: Variant = unit.get("pos", null)
		if pos_v is Vector2:
			hit_pos = pos_v
		else:
			var from_pos_v: Variant = unit.get("from_pos", null)
			var to_pos_v: Variant = unit.get("to_pos", null)
			if from_pos_v is Vector2 and to_pos_v is Vector2:
				var t: float = clampf(float(unit.get("t", 0.0)), 0.0, 1.0)
				hit_pos = (from_pos_v as Vector2).lerp(to_pos_v as Vector2, t)
		if _sim_events != null:
			_sim_events.emit_signal("tower_hit", source_tower_id, tower_owner_id, tower_tier, tower_pos, victim_unit_id, hit_pos)
		var amount: int = int(unit.get("amount", 1))
		if amount > 0:
			var from_is_a := _unit_dir(unit) >= 0
			_adjust_lane_pressure(int(unit.get("lane_id", -1)), from_is_a, -amount)
			OpsState.add_units_killed(tower_owner_id, amount)
		return _remove_unit(victim_unit_id, "tower_hit")
	return false

func _lane_anchor_world_from_center(center_world: Vector2) -> Vector2:
	return HiveNodeScript.lane_anchor_world_from_center(center_world)

func _edge_points(from_hive: HiveData, to_hive: HiveData) -> Array:
	if state == null or from_hive == null or to_hive == null:
		return []
	var a_pos: Vector2 = state.hive_world_pos_by_id(int(from_hive.id))
	var b_pos: Vector2 = state.hive_world_pos_by_id(int(to_hive.id))
	var ep: Dictionary = HiveNodeScript.compute_lane_endpoints_world(a_pos, b_pos)
	var start_edge: Vector2 = ep.get("a", _lane_anchor_world_from_center(a_pos))
	var end_edge: Vector2 = ep.get("b", _lane_anchor_world_from_center(b_pos))
	if start_edge.distance_to(end_edge) < EDGE_MIN_DIST_PX:
		end_edge = start_edge
	return [start_edge, end_edge]

func _ensure_unit_edges(unit: Dictionary) -> Dictionary:
	if state == null:
		return unit
	var a_id := int(unit.get("a_id", -1))
	var b_id := int(unit.get("b_id", -1))
	if a_id <= 0 or b_id <= 0:
		return unit
	var a_hive: HiveData = state.find_hive_by_id(a_id)
	var b_hive: HiveData = state.find_hive_by_id(b_id)
	if a_hive == null or b_hive == null:
		return unit
	var edge_points := _edge_points(a_hive, b_hive)
	if edge_points.is_empty():
		return unit
	unit["from_pos"] = edge_points[0]
	unit["to_pos"] = edge_points[1]
	unit["pos"] = edge_points[0].lerp(edge_points[1], clampf(float(unit.get("t", 0.0)), 0.0, 1.0))
	return unit

func _sync_units_to_state() -> void:
	if state == null:
		return
	_refresh_units_set_version()
	var all_v: Variant = state.units_by_lane.get("_all")
	if all_v != units:
		state.units_by_lane["_all"] = units

func _refresh_units_set_version() -> void:
	if state == null:
		return
	var count: int = units.size()
	var sig: int = _units_set_signature()
	if count == _last_units_set_count and sig == _last_units_set_sig:
		state.units_set_version = units_set_version
		return
	_last_units_set_count = count
	_last_units_set_sig = sig
	units_set_version += 1
	state.units_set_version = units_set_version

func _units_set_signature() -> int:
	var sig: int = units.size()
	var xor_ids: int = 0
	for unit_any in units:
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_any as Dictionary
		xor_ids = xor_ids ^ int(unit.get("id", -1))
	sig = (sig * 31 + xor_ids) & 0x7fffffff
	return sig

func _remove_unit(unit_id: int, reason: String) -> bool:
	for i in range(units.size()):
		var unit: Dictionary = units[i] as Dictionary
		if int(unit.get("id", -1)) != unit_id:
			continue
		_emit_unit_death_event(unit, reason)
		units.remove_at(i)
		_sync_units_to_state()
		if SFLog.verbose_sim:
			SFLog.info("UNIT_REMOVED", {"unit_id": unit_id, "reason": reason})
		return true
	return false

func spawn_unit(unit: Dictionary) -> void:
	if state == null:
		return
	var lane_id := int(unit.get("lane_id", -1))
	if lane_id > 0:
		var established := false
		var build_t := 0.0
		var lane_any = state.find_lane_by_id(lane_id)
		if lane_any is LaneData:
			var ld := lane_any as LaneData
			build_t = float(ld.build_t)
			established = ld.is_built()
		if not established:
			_log_unit_gate_blocked(
				lane_id,
				int(unit.get("from_id", -1)),
				int(unit.get("to_id", -1)),
				"build",
				build_t
			)
			return
		_log_unit_gate_open_once(
			lane_id,
			int(unit.get("from_id", -1)),
			int(unit.get("to_id", -1)),
			build_t
		)
	if not unit.has("id") or int(unit.get("id", 0)) <= 0:
		unit["id"] = _next_external_unit_id
		_next_external_unit_id += 1
	if not unit.has("amount") or int(unit.get("amount", 0)) <= 0:
		unit["amount"] = 1
	var dir := _unit_dir(unit)
	if not unit.has("t"):
		unit["t"] = 0.0 if dir >= 0 else 1.0
	elif dir < 0 and float(unit.get("t", 0.0)) <= 0.0:
		unit["t"] = 1.0
	unit = _ensure_unit_edges(unit)
	unit = _update_unit_pos_from_t(unit)
	units.append(unit)
	_sync_units_to_state()

func export_units_render() -> Array:
	return units.duplicate(true)

func spawn_render_unit(lane_id: int, a_id: int, b_id: int, owner_id: int, from_side: String) -> void:
	var from_id := a_id
	var to_id := b_id
	if from_side == "B":
		from_id = b_id
		to_id = a_id
	var from_pos := Vector2.ZERO
	var to_pos := Vector2.ZERO
	if state != null:
		var a_pos: Vector2 = state.hive_world_pos_by_id(a_id)
		var b_pos: Vector2 = state.hive_world_pos_by_id(b_id)
		from_pos = _lane_anchor_world_from_center(a_pos)
		to_pos = _lane_anchor_world_from_center(b_pos)
	var dir := 1 if from_side == "A" else -1
	var t := 0.0 if dir >= 0 else 1.0
	var pos := from_pos.lerp(to_pos, t)
	render_units.append({
		"id": _next_uid,
		"lane_id": lane_id,
		"a_id": a_id,
		"b_id": b_id,
		"from_id": from_id,
		"to_id": to_id,
		"owner_id": owner_id,
		"dir": dir,
		"t": t,
		"from_side": from_side,
		"from_pos": from_pos,
		"to_pos": to_pos,
		"pos": pos
	})
	_next_uid += 1

func tick_render_units(dt: float) -> void:
	var delta_px := float(SimTuning.UNIT_SPEED_PX_PER_SEC) * dt
	for i in range(render_units.size() - 1, -1, -1):
		var u: Dictionary = render_units[i] as Dictionary
		var dir := int(u.get("dir", 1))
		var from_pos_v: Variant = u.get("from_pos")
		var to_pos_v: Variant = u.get("to_pos")
		if not (from_pos_v is Vector2 and to_pos_v is Vector2):
			continue
		var from_pos: Vector2 = from_pos_v
		var to_pos: Vector2 = to_pos_v
		var lane_len := from_pos.distance_to(to_pos)
		if lane_len <= 0.001:
			continue
		var delta_t := delta_px / lane_len
		var t := clampf(float(u.get("t", 0.0)) + (float(dir) * delta_t), 0.0, 1.0)
		u["t"] = t
		u["pos"] = from_pos.lerp(to_pos, t)
		render_units[i] = u
		var arrived := (dir >= 0 and t >= 1.0) or (dir < 0 and t <= 0.0)
		if arrived:
			render_units.remove_at(i)
	if debug_unit_speed_log:
		_log_unit_speed(render_units)

func _log_unit_speed(units_in: Array) -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_unit_speed_log_ms < UNIT_SPEED_LOG_INTERVAL_MS:
		return
	if units_in.is_empty():
		return
	var u: Dictionary = units_in[0]
	var from_pos_v: Variant = u.get("from_pos")
	var to_pos_v: Variant = u.get("to_pos")
	if not (from_pos_v is Vector2 and to_pos_v is Vector2):
		return
	var from_pos: Vector2 = from_pos_v
	var to_pos: Vector2 = to_pos_v
	var t: float = clampf(float(u.get("t", 0.0)), 0.0, 1.0)
	var pos := from_pos.lerp(to_pos, t)
	var lane_len := from_pos.distance_to(to_pos)
	var unit_id := int(u.get("id", -1))
	var elapsed_s := float(now_ms - _last_unit_speed_log_ms) / 1000.0
	var speed_px_s := 0.0
	if _last_unit_speed_id == unit_id and elapsed_s > 0.0:
		speed_px_s = pos.distance_to(_last_unit_speed_pos) / elapsed_s
	_last_unit_speed_log_ms = now_ms
	_last_unit_speed_id = unit_id
	_last_unit_speed_pos = pos
	SFLog.info("UNIT_SPEED_DEBUG", {
		"unit_id": unit_id,
		"lane_id": int(u.get("lane_id", -1)),
		"lane_len": lane_len,
		"speed_px_s": speed_px_s
	})

func _lane_length(lane: LaneData) -> float:
	if state == null:
		return 0.0
	var a_pos := state.hive_world_pos_by_id(int(lane.a_id))
	var b_pos := state.hive_world_pos_by_id(int(lane.b_id))
	return a_pos.distance_to(b_pos)

func _lane_hard_cap_units(lane_len: float) -> int:
	var px_per_unit: float = maxf(1.0, float(SimTuning.LANE_HARD_CAP_PX_PER_UNIT))
	var raw_cap: int = int(round(maxf(1.0, lane_len) / px_per_unit))
	return clampi(raw_cap, int(SimTuning.LANE_HARD_CAP_MIN_UNITS), int(SimTuning.LANE_HARD_CAP_MAX_UNITS))

func _lane_side_pressure(lane: LaneData, from_is_a: bool) -> float:
	return float(lane.a_pressure) if from_is_a else float(lane.b_pressure)

func _lane_established(lane: LaneData, from_is_a: bool, lane_len: float) -> bool:
	if lane_len <= 0.0:
		return false
	return lane.is_built()

func _lane_front_t(lane_id: int) -> float:
	return float(OpsState.lane_front_by_lane_id.get(lane_id, 0.0))

func _log_unit_gate_blocked(lane_id: int, src_id: int, dst_id: int, intent: String, build_t: float) -> void:
	var now_ms := Time.get_ticks_msec()
	var last_ms := int(_lane_gate_block_log_ms.get(lane_id, 0))
	if now_ms - last_ms < UNIT_GATE_LOG_INTERVAL_MS:
		return
	_lane_gate_block_log_ms[lane_id] = now_ms
	SFLog.info("UNIT_GATE_BLOCKED", {
		"lane_id": lane_id,
		"src": src_id,
		"dst": dst_id,
		"intent": intent,
		"front_t": _lane_front_t(lane_id),
		"build_t": build_t
	})

func _log_unit_gate_open_once(lane_id: int, src_id: int, dst_id: int, build_t: float) -> void:
	if _lane_gate_open_logged.has(lane_id):
		return
	_lane_gate_open_logged[lane_id] = true
	SFLog.info("UNIT_GATE_OPEN", {
		"lane_id": lane_id,
		"src": src_id,
		"dst": dst_id,
		"front_t": _lane_front_t(lane_id),
		"build_t": build_t
	})

func _log_lane_cap_blocked(lane_id: int, src_id: int, dst_id: int, side: String, pressure: float, cap_units: int) -> void:
	var key := "%d:%s" % [lane_id, side]
	var now_ms := Time.get_ticks_msec()
	var last_ms := int(_last_lane_cap_block_ms.get(key, 0))
	if now_ms - last_ms < LANE_CAP_LOG_INTERVAL_MS:
		return
	_last_lane_cap_block_ms[key] = now_ms
	SFLog.info("UNIT_LANE_CAP_BLOCK", {
		"lane_id": lane_id,
		"src": src_id,
		"dst": dst_id,
		"side": side,
		"pressure": pressure,
		"cap_units": cap_units
	})

func _spawn_interval_ms_for_power(power: int) -> int:
	var p := maxi(1, power)
	return maxi(50, 1000 - (p - 1) * 2)

func _spawn_ids() -> Dictionary:
	var ids: Dictionary = {}
	var spawns: Array = state.spawns
	for spawn_v in spawns:
		if typeof(spawn_v) != TYPE_DICTIONARY:
			continue
		var sd: Dictionary = spawn_v
		var hive_id := int(sd.get("hive_id", sd.get("id", -1)))
		if hive_id > 0:
			ids[hive_id] = true
	return ids

func _spawn_allowed(spawn_ids: Dictionary, hive_id: int) -> bool:
	if spawn_ids.is_empty():
		return true
	return spawn_ids.has(hive_id)
