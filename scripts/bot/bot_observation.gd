# Derived player-visible facts only. No mutable HiveData/LaneData references,
# hidden objectives, queued commands, or internal enemy cooldowns leave here.
extends RefCounted

const Baseline := preload("res://scripts/bot/baseline_bot_policy.gd")
const MapSchema := preload("res://scripts/maps/map_schema.gd")

static func capture(state: GameState, seat: int, teams: Dictionary, now_ms: int) -> Dictionary:
	var hives: Dictionary = {}
	var ids: Array = []
	for hive in state.hives:
		if not hive is HiveData:
			continue
		var id := int(hive.id)
		ids.append(id)
		hives[str(id)] = {"id": id, "owner": int(hive.owner_id), "power": int(hive.power), "x": int(hive.grid_pos.x), "y": int(hive.grid_pos.y), "outgoing": state.count_active_outgoing(id), "open_slots": maxi(0, state.lanes_allowed_for_power(int(hive.power)) - state.count_active_outgoing(id))}
	ids.sort()
	var routes: Array[Dictionary] = []
	var walls: Array = MapSchema._wall_segments_from_walls(state.walls)
	var geometry := Baseline.new()
	for src_id in ids:
		var src: HiveData = state.find_hive_by_id(src_id)
		if int(src.owner_id) != seat:
			continue
		for dst_id in ids:
			if src_id == dst_id or not state.can_connect(src_id, dst_id):
				continue
			var dst: HiveData = state.find_hive_by_id(dst_id)
			if geometry._pair_intersects_wall(src, dst, walls):
				continue
			var own_swarm_ready_ms := int(int(state.swarm_cooldown_until_us.get(src_id, state.swarm_cooldown_until_us.get(str(src_id), 0))) / 1000)
			routes.append({"src": src_id, "dst": dst_id, "active": state.is_outgoing_lane_active(src_id, dst_id), "swarm_ready_ms": own_swarm_ready_ms, "distance": Vector2(src.grid_pos).distance_to(Vector2(dst.grid_pos))})
	var pressure: Array[Dictionary] = []
	for lane in state.lanes:
		if not lane is LaneData:
			continue
		for direction in [0, 1]:
			var src_id: int = int(lane.a_id) if direction == 0 else int(lane.b_id)
			var dst_id: int = int(lane.b_id) if direction == 0 else int(lane.a_id)
			var active: bool = bool(lane.send_a) if direction == 0 else bool(lane.send_b)
			if active and hives.has(str(src_id)):
				pressure.append({"src": src_id, "dst": dst_id, "owner": int(hives[str(src_id)]["owner"])})
	var incoming: Array[Dictionary] = []
	# A bounded near-arrival estimate from visible moving forces, not queued spawns.
	for unit in state.units_by_lane.get("_all", []):
		if typeof(unit) == TYPE_DICTIONARY:
			_append_incoming(incoming, unit, false)
	for packet in state.swarm_packets:
		if typeof(packet) == TYPE_DICTIONARY:
			_append_incoming(incoming, packet, true)
	return {"observed_ms": now_ms, "seat": seat, "teams": teams.duplicate(true), "hives": hives, "ids": ids, "routes": routes, "pressure": pressure, "incoming": incoming}

static func _append_incoming(out: Array[Dictionary], unit: Dictionary, swarm: bool) -> void:
	var progress := float(unit.get("t", 0.0))
	if int(unit.get("dir", 1)) < 0:
		progress = 1.0 - progress
	if progress < 0.4:
		return
	out.append({"src": int(unit.get("from_id", -1)), "dst": int(unit.get("to_id", -1)), "owner": int(unit.get("owner_id", 0)), "amount": maxi(1, int(unit.get("count", 1) if swarm else unit.get("amount", 1))), "swarm": swarm})
