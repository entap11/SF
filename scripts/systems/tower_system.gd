# NOTE: Tower simulation extracted from Arena for refactor safety. Uses state-only mutation.
# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name TowerSystem
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const StructureControlSystem := preload("res://scripts/systems/structure_control_system.gd")
const StructureControlSolver := preload("res://scripts/sim/structure_control.gd")
const SimEvents := preload("res://scripts/sim/sim_events.gd")
const DEFAULT_CELL_SIZE := 64.0
const AIRSPACE_HALF_W: float = 260.0
const AIRSPACE_HALF_H: float = 160.0
const TOWER_EVAL_LOG_MS: int = 1000

const BARRACKS_MIN_REQ := 3
const BARRACKS_MAX_REQ := 6
const MAX_CYCLE_LEN := 10
const STRUCTURE_CANDIDATE_MAX := 12
const BUFF_MIN_MULT := 0.1
const tower_base_radius_px: float = DEFAULT_CELL_SIZE * 0.75

var state: GameState = null
var towers: Array = []
var world_towers: Array[Node2D] = []
var tower_control_ms: Dictionary = {}
var structure_sets: Array = []
var structure_positions: Array = []
var _buff_mod_provider: Callable = Callable()
var _last_eval_log_ms_by_id: Dictionary = {}
var _last_no_target_ms_by_id: Dictionary = {}
var _sim_events: SimEvents = null
var _structure_control_system: Object = null

func bind_state(state_ref: GameState) -> void:
	state = state_ref
	towers.clear()
	structure_sets.clear()
	structure_positions.clear()
	reset_control_ms()
	world_towers.clear()
	_bind_structure_control_system()
	var state_towers_count: int = 0
	if state != null and state.towers != null:
		state_towers_count = int(state.towers.size())
	SFLog.info("TOWER_BIND_SIM_DATA", {"state_towers": state_towers_count})
	if state != null and state.towers != null and state.towers.size() > 0:
		_init_from_state_towers(state.towers)
		SFLog.info("TOWER_BIND_INIT_FROM_STATE", {"count": int(towers.size())})

func bind_world_towers(nodes: Array[Node2D]) -> void:
	world_towers = nodes

func reset_control_ms() -> void:
	tower_control_ms = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0}

func set_buff_mod_provider(provider: Callable) -> void:
	_buff_mod_provider = provider

func set_sim_events(sim_events: SimEvents) -> void:
	_sim_events = sim_events

func init_from_map(map_model: Dictionary) -> void:
	towers = []
	structure_sets = []
	structure_positions = []
	for t in map_model.get("towers", []):
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = t
		var tower_node_id: int = int(td.get("node_id", td.get("id", -1)))
		var t_pos: Array = td.get("grid_pos", [0, 0])
		var t_grid_pos := Vector2i(int(t_pos[0]), int(t_pos[1]))
		var temp: Dictionary = td.duplicate(true)
		temp["grid_pos"] = t_grid_pos
		var control_ids: Array = _tower_adjacent_control_ids(temp)
		var t_computed: Array = control_ids.duplicate()
		structure_sets.append(t_computed)
		if t_computed.size() >= BARRACKS_MIN_REQ:
			structure_positions.append(_structure_center_for_required(t_computed, _cell_center(t_grid_pos)))
		towers.append({
			"id": int(td.get("id", -1)),
			"node_id": tower_node_id,
			"grid_pos": t_grid_pos,
			"control_hive_ids": control_ids,
			"required_hive_ids": t_computed,
			"active": false,
			"owner_id": 0,
			"active_owner_id": 0,
			"tier": 1,
			"shot_accum_ms": 0.0
		})
	if state != null:
		state.towers = towers
	SFLog.info("TOWER_INIT", {"count": towers.size()})

func get_structure_sets() -> Array:
	return structure_sets

func get_structure_positions() -> Array:
	return structure_positions

func compute_required_hives_for_structure(pos: Vector2i, required: Array, existing_sets: Array = [], structure_positions_in: Array = []) -> Array:
	return _structure_required_hives_for(pos, required, existing_sets, structure_positions_in)

func tick(dt: float, unit_system: UnitSystem) -> void:
	if state == null:
		return
	if OpsState.has_outcome():
		return
	# If we bound before state.towers was populated, recover here.
	if (towers.is_empty() or (state.towers != null and state.towers.size() != towers.size())) and state.towers != null and state.towers.size() > 0:
		_init_from_state_towers(state.towers)
		SFLog.info("TOWER_LATE_INIT", {"count": towers.size()})
	var dt_ms: float = dt * 1000.0
	var now_ms: int = Time.get_ticks_msec()
	for tower in towers:
		var control_ids: Array = StructureControlSystem.control_ids_for(tower)
		var owner_id: int = int(tower.get("owner_id", 0))
		var next_tier: int = _tower_tier_for_owner(control_ids, owner_id)
		tower["active_owner_id"] = owner_id
		tower["active"] = owner_id != 0
		_log_tower_eval(tower, owner_id, control_ids, now_ms)
		if owner_id == 0:
			tower["tier"] = 1
			tower["shot_accum_ms"] = 0.0
			continue
		tower["tier"] = next_tier
		tower_control_ms[owner_id] = float(tower_control_ms.get(owner_id, 0.0)) + dt_ms
		var tier: int = int(tower.get("tier", 1))
		tower["shot_accum_ms"] = float(tower.get("shot_accum_ms", 0.0)) + dt_ms
		var interval_ms: float = _tower_interval_ms_for(owner_id, tier)
		while float(tower["shot_accum_ms"]) >= interval_ms:
			var shot: bool = _tower_shoot(tower, unit_system)
			if shot:
				tower["shot_accum_ms"] = float(tower["shot_accum_ms"]) - interval_ms
				continue
			# No target: keep gate ready so first target fires immediately.
			tower["shot_accum_ms"] = interval_ms
			break

func _set_tower_inactive(tower: Dictionary) -> void:
	tower["active"] = false
	tower["owner_id"] = 0
	tower["tier"] = 1
	tower["shot_accum_ms"] = 0.0

func _log_tower_state_change(tower: Dictionary, prev_active: bool, prev_owner: int, prev_tier: int) -> void:
	var active := bool(tower.get("active", false))
	var owner := int(tower.get("owner_id", 0))
	var tier := int(tower.get("tier", 1))
	if active == prev_active and owner == prev_owner and tier == prev_tier:
		return
	SFLog.info("TOWER_STATE", {
		"tower_id": int(tower.get("id", -1)),
		"active": active,
		"owner_id": owner,
		"tier": tier
	})

func _hive_tier(power: int) -> int:
	if power >= 50:
		return 4
	if power >= 25:
		return 3
	if power >= 10:
		return 2
	return 1

func _tower_interval_ms(tier: int) -> float:
	match tier:
		1:
			return 3000.0
		2:
			return 2500.0
		3:
			return 2000.0
		4:
			return 1500.0
	return 3000.0

func _tower_interval_ms_for(owner_id: int, tier: int) -> float:
	var base: float = _tower_interval_ms(tier)
	if owner_id <= 0:
		return base
	var pct: float = _buff_mod(owner_id, "tower_fire_rate_pct")
	var rate_mult: float = maxf(BUFF_MIN_MULT, 1.0 + pct)
	return maxf(80.0, base / rate_mult)

func _tower_range_px(tier: int) -> float:
	var base_radius: float = 160.0
	match tier:
		1:
			return base_radius
		2:
			return base_radius * 1.20
		3:
			return base_radius * 1.20 * 1.15
		4:
			return base_radius * 1.20 * 1.15 * 1.10
	return base_radius

func _tower_shoot(tower: Dictionary, unit_system: UnitSystem) -> bool:
	if unit_system == null or not bool(tower.get("active", false)):
		return false
	var tower_pos: Vector2 = _tower_center_pos(tower)
	var tier: int = int(tower.get("tier", 1))
	var tower_owner: int = int(tower.get("owner_id", 0))
	var range_px: float = _tower_range_px(tier)
	var range_sq: float = range_px * range_px
	var best_id: int = -1
	var best_owner: int = 0
	var best_dist: float = INF
	var best_pos: Vector2 = Vector2.ZERO
	var units_seen: int = 0
	var units_in_lane: int = 0
	var units_in_range: int = 0
	var units_bad_lane: int = 0
	for unit in unit_system.units:
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		units_seen += 1
		var ud: Dictionary = unit
		var lane_id: int = int(ud.get("lane_id", -1))
		if lane_id <= 0:
			units_bad_lane += 1
			continue
		units_in_lane += 1
		if int(ud.get("owner_id", 0)) == tower_owner:
			continue
		var pos: Vector2 = _unit_position(ud)
		var dist: float = tower_pos.distance_squared_to(pos)
		if dist <= range_sq:
			units_in_range += 1
			if dist < best_dist:
				best_dist = dist
				best_id = int(ud.get("id", -1))
				best_owner = int(ud.get("owner_id", 0))
				best_pos = pos
	if best_id == -1:
		var interval_ms: float = _tower_interval_ms_for(tower_owner, tier)
		var cooldown_remaining: float = maxf(0.0, interval_ms - float(tower.get("shot_accum_ms", 0.0)))
		_log_no_target(
			tower,
			units_seen,
			units_in_lane,
			units_in_range,
			units_bad_lane,
			cooldown_remaining
		)
		return false
	var tower_id: int = int(tower.get("id", -1))
	if _sim_events != null:
		_sim_events.emit_signal("tower_fire", tower_id, tower_owner, tier, tower_pos, best_id, best_pos)
	var now_ms: int = Time.get_ticks_msec()
	SFLog.info("TOWER_TRY_FIRE", {
		"tower": tower_id,
		"now_ms": now_ms,
		"can_fire": true,
		"target": best_id
	})
	SFLog.info("TOWER_FIRE", {
		"tower_id": tower_id,
		"target_id": best_id,
		"tower_owner": tower_owner,
		"tier": tier
	})
	var cooldown_ms: float = _tower_interval_ms_for(tower_owner, tier)
	tower["cooldown_remaining"] = cooldown_ms
	tower["cooldown_ms"] = cooldown_ms
	tower["last_fire_ms"] = now_ms
	if unit_system.apply_tower_hit(best_id, tower_owner, tower_id, 0, tower_pos, tier):
		SFLog.info("TOWER_HIT", {
			"tower_id": tower_id,
			"unit_id": best_id,
			"tower_owner": tower_owner
		})
		SFLog.info("TOWER_SHOT", {
			"tower_id": tower_id,
			"victim_unit_id": best_id,
			"victim_owner": best_owner,
			"tier": tier
		})
		return true
	return false

func _log_tower_eval(tower: Dictionary, owner_id: int, control_ids: Array, now_ms: int) -> void:
	var tower_id: int = int(tower.get("id", -1))
	if tower_id <= 0:
		return
	var last_ms: int = int(_last_eval_log_ms_by_id.get(tower_id, 0))
	if now_ms - last_ms < TOWER_EVAL_LOG_MS:
		return
	_last_eval_log_ms_by_id[tower_id] = now_ms
	SFLog.info("TOWER_EVAL", {
		"tower_id": tower_id,
		"owner_id": owner_id,
		"tier": int(tower.get("tier", 1)),
		"active": bool(tower.get("active", false)),
		"control_count": control_ids.size()
	})

func _log_no_target(
	tower: Dictionary,
	units_seen: int,
	units_in_lane: int,
	units_in_range: int,
	units_bad_lane: int,
	cooldown_remaining: float
) -> void:
	var tower_id: int = int(tower.get("id", -1))
	if tower_id <= 0:
		return
	var now_ms: int = Time.get_ticks_msec()
	var last_ms: int = int(_last_no_target_ms_by_id.get(tower_id, 0))
	if now_ms - last_ms < TOWER_EVAL_LOG_MS:
		return
	_last_no_target_ms_by_id[tower_id] = now_ms
	SFLog.info("TOWER_TARGET_SCAN", {
		"tower_id": tower_id,
		"owner_id": int(tower.get("owner_id", 0)),
		"active": bool(tower.get("active", false)),
		"units_seen": units_seen,
		"units_in_lane": units_in_lane,
		"units_in_range": units_in_range,
		"units_bad_lane": units_bad_lane,
		"world_nodes": world_towers.size(),
		"cooldown_remaining": cooldown_remaining
	})
	if OS.is_debug_build() and units_seen > 0 and units_in_range == 0:
		SFLog.info("TOWER_DEBUG_NO_TARGET_BUT_UNITS_EXIST", {
			"tower_id": tower_id,
			"owner_id": int(tower.get("owner_id", 0)),
			"units_seen": units_seen
		})

func _tower_center_pos(tower_data: Dictionary) -> Vector2:
	var gp_v: Variant = tower_data.get("grid_pos", null)
	if gp_v is Vector2i:
		return _cell_center(gp_v as Vector2i)
	if gp_v is Array:
		var gp_arr: Array = gp_v as Array
		if gp_arr.size() >= 2:
			return _cell_center(Vector2i(int(gp_arr[0]), int(gp_arr[1])))
	var required: Array = tower_data.get("required_hive_ids", [])
	if required.is_empty():
		return _cell_center(tower_data.get("grid_pos", Vector2i.ZERO))
	var sum := Vector2.ZERO
	var count := 0
	for hive_id_v in required:
		var hive: HiveData = state.find_hive_by_id(int(hive_id_v))
		if hive == null:
			continue
		sum += _cell_center(hive.grid_pos)
		count += 1
	if count == 0:
		return _cell_center(tower_data.get("grid_pos", Vector2i.ZERO))
	return sum / float(count)

func _unit_position(unit: Dictionary) -> Vector2:
	var pos_v: Variant = unit.get("pos")
	if pos_v is Vector2:
		return pos_v
	var from_pos_v: Variant = unit.get("from_pos")
	var to_pos_v: Variant = unit.get("to_pos")
	if from_pos_v is Vector2 and to_pos_v is Vector2:
		return (from_pos_v as Vector2).lerp(to_pos_v as Vector2, clampf(float(unit.get("t", 0.0)), 0.0, 1.0))
	var from_id := int(unit.get("from_id", -1))
	var to_id := int(unit.get("to_id", -1))
	if from_id <= 0 or to_id <= 0 or state == null:
		return Vector2.ZERO
	var from_pos := state.hive_world_pos_by_id(from_id)
	var to_pos := state.hive_world_pos_by_id(to_id)
	var pts := GameState.lane_edge_points(from_pos, to_pos)
	var a_edge: Vector2 = pts.get("a_edge", from_pos)
	var b_edge: Vector2 = pts.get("b_edge", to_pos)
	return a_edge.lerp(b_edge, clampf(float(unit.get("t", 0.0)), 0.0, 1.0))

func _tower_tier_for_owner(control_ids: Array, owner_id: int) -> int:
	if owner_id == 0:
		return 1
	var min_tier: int = 4
	for hive_id_v in control_ids:
		var hive_id: int = int(hive_id_v)
		var hive: HiveData = state.find_hive_by_id(hive_id)
		if hive == null or hive.owner_id != owner_id:
			return 1
		min_tier = min(min_tier, _hive_tier(hive.power))
	return min_tier

func _kill_enemy_units_in_airspace(tower: Dictionary, owner_id: int, unit_system: UnitSystem) -> void:
	if unit_system == null or owner_id == 0:
		return
	var tower_id: int = int(tower.get("id", -1))
	var tower_pos: Vector2 = _tower_center_pos(tower)
	var tier: int = int(tower.get("tier", 1))
	var kills: Array = []
	for unit_any in unit_system.units:
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_any as Dictionary
		var unit_owner: int = int(unit.get("owner_id", 0))
		if unit_owner == 0 or unit_owner == owner_id:
			continue
		var pos: Vector2 = _unit_position(unit)
		if _unit_in_airspace(tower_pos, pos):
			kills.append({
				"id": int(unit.get("id", -1)),
				"owner": unit_owner
			})
	for kill_any in kills:
		var kill_data: Dictionary = kill_any as Dictionary
		var unit_id: int = int(kill_data.get("id", -1))
		if unit_id <= 0:
			continue
		if unit_system.apply_tower_hit(unit_id, owner_id, tower_id, 0, tower_pos, tier):
			SFLog.info("TOWER_KILL", {
				"tower_id": tower_id,
				"unit_id": unit_id,
				"tower_owner": owner_id,
				"unit_owner": int(kill_data.get("owner", 0))
			})

func _unit_in_airspace(tower_pos: Vector2, unit_pos: Vector2) -> bool:
	return (
		absf(unit_pos.x - tower_pos.x) <= AIRSPACE_HALF_W
		and absf(unit_pos.y - tower_pos.y) <= AIRSPACE_HALF_H
	)

func _init_from_state_towers(towers_src: Array) -> void:
	towers.clear()
	for td_any in towers_src:
		if typeof(td_any) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = td_any as Dictionary
		if int(td.get("id", -1)) <= 0:
			continue
		_ensure_tower_fields(td)
		towers.append(td)

func _ensure_tower_fields(td: Dictionary) -> void:
	var tower_id: int = int(td.get("id", -1))
	if not td.has("node_id"):
		td["node_id"] = tower_id
	var control_ids: Array = _tower_adjacent_control_ids(td)
	td["control_hive_ids"] = control_ids
	td["required_hive_ids"] = control_ids.duplicate()
	if not td.has("active"):
		td["active"] = false
	td["active_owner_id"] = int(td.get("owner_id", 0))
	if not td.has("tier"):
		td["tier"] = 1
	if not td.has("shot_accum_ms"):
		td["shot_accum_ms"] = 0.0

func _tower_adjacent_control_ids(tower_data: Dictionary) -> Array:
	if state == null:
		return []
	var tower_id: int = int(tower_data.get("id", -1))
	if tower_id <= 0:
		return []
	var center: Vector2 = _tower_control_center(tower_data)
	var lanes_src: Array = []
	if state.map_lanes != null and not state.map_lanes.is_empty():
		lanes_src = state.map_lanes
	elif state.lanes != null and not state.lanes.is_empty():
		lanes_src = state.lanes
	else:
		var candidates_v: Variant = state.lane_candidates
		if typeof(candidates_v) == TYPE_ARRAY:
			lanes_src = candidates_v as Array
	var hive_entries: Array = []
	for hive in state.hives:
		var hive_id: int = int(hive.id)
		if hive_id <= 0:
			continue
		hive_entries.append({
			"id": hive_id,
			"pos": state.hive_world_pos_by_id(hive_id)
		})
	var picked: Dictionary = StructureControlSolver.pick_min_enclosing_cycle_from_nearest(
		hive_entries,
		lanes_src,
		center,
		"tower",
		tower_id,
		tower_base_radius_px,
		BARRACKS_MIN_REQ,
		MAX_CYCLE_LEN
	)
	return picked.get("ids", [])

func _tower_control_center(tower_data: Dictionary) -> Vector2:
	var gp_v: Variant = tower_data.get("grid_pos", null)
	if gp_v is Vector2i:
		return _cell_center(gp_v as Vector2i)
	if gp_v is Array:
		var gp_arr: Array = gp_v as Array
		if gp_arr.size() >= 2:
			return _cell_center(Vector2i(int(gp_arr[0]), int(gp_arr[1])))
	return _tower_center_pos(tower_data)

func _buff_mod(pid: int, key: String) -> float:
	if _buff_mod_provider.is_valid():
		var out: float = float(_buff_mod_provider.call(pid, key))
		return out
	return 0.0

func _cell_center(cell: Vector2i) -> Vector2:
	if state != null and state.grid_spec != null:
		return state.grid_spec.grid_to_world(cell)
	return Vector2(
		(float(cell.x) + 0.5) * DEFAULT_CELL_SIZE,
		(float(cell.y) + 0.5) * DEFAULT_CELL_SIZE
	)

func _structure_required_hives_for(pos: Vector2i, required: Array, existing_sets: Array, structure_positions: Array) -> Array:
	var valid: Array = []
	var seen: Dictionary = {}
	for hive_id_v in required:
		var hive_id: int = int(hive_id_v)
		if seen.has(hive_id):
			continue
		var hive: HiveData = state.find_hive_by_id(hive_id)
		if hive == null:
			continue
		seen[hive_id] = true
		valid.append(hive_id)
	var self_center: Vector2 = _cell_center(pos)
	if valid.size() >= BARRACKS_MIN_REQ and valid.size() <= BARRACKS_MAX_REQ:
		if _structure_selection_ok(valid, existing_sets, structure_positions, self_center):
			return valid
	var preferred_size: int = valid.size()
	return _structure_pick_required_hives(pos, existing_sets, structure_positions, preferred_size)

func _structure_pick_required_hives(pos: Vector2i, existing_sets: Array, structure_positions: Array, preferred_size: int) -> Array:
	var entries: Array = []
	for hive in state.hives:
		var d: Vector2i = hive.grid_pos - pos
		var d2: int = d.x * d.x + d.y * d.y
		entries.append({"id": hive.id, "d2": d2})
	entries.sort_custom(Callable(self, "_barracks_entry_less"))
	if entries.is_empty():
		return []
	var candidate_count: int = min(entries.size(), STRUCTURE_CANDIDATE_MAX)
	var candidates: Array = []
	for i in range(candidate_count):
		candidates.append(entries[i])
	var min_req: int = min(BARRACKS_MIN_REQ, candidate_count)
	var max_req: int = min(BARRACKS_MAX_REQ, candidate_count)
	if max_req < min_req:
		min_req = candidate_count
		max_req = candidate_count
	var preferred: int = preferred_size
	if preferred < min_req or preferred > max_req:
		preferred = max_req
	var sizes: Array = [preferred]
	for size in range(min_req, max_req + 1):
		if size == preferred:
			continue
		sizes.append(size)
	var best_state_global: Dictionary = {"penalty": 1_000_000, "score": 1_000_000_000, "set": []}
	for size in sizes:
		var best_state: Dictionary = {"penalty": 1_000_000, "score": 1_000_000_000, "set": []}
		_structure_search_best(candidates, size, 0, [], 0, existing_sets, structure_positions, _cell_center(pos), best_state)
		if best_state["penalty"] == 0:
			return best_state["set"]
		if best_state["penalty"] < int(best_state_global["penalty"]) or (best_state["penalty"] == int(best_state_global["penalty"]) and best_state["score"] < int(best_state_global["score"])):
			best_state_global = best_state
	return []

func _structure_search_best(entries: Array, size: int, start_idx: int, current: Array, sum_d2: int, existing_sets: Array, structure_positions: Array, self_center: Vector2, best_state: Dictionary) -> void:
	if current.size() == size:
		var penalty: int = _structure_selection_penalty(current, existing_sets, structure_positions, self_center)
		if penalty < int(best_state["penalty"]) or (penalty == int(best_state["penalty"]) and sum_d2 < int(best_state["score"])):
			best_state["penalty"] = penalty
			best_state["score"] = sum_d2
			best_state["set"] = current.duplicate()
		return
	if start_idx >= entries.size():
		return
	if current.size() + (entries.size() - start_idx) < size:
		return
	for i in range(start_idx, entries.size()):
		var entry: Dictionary = entries[i]
		current.append(int(entry["id"]))
		_structure_search_best(entries, size, i + 1, current, sum_d2 + int(entry["d2"]), existing_sets, structure_positions, self_center, best_state)
		current.pop_back()

func _structure_selection_ok(candidate: Array, existing_sets: Array, structure_positions: Array, self_center: Vector2) -> bool:
	return _structure_selection_penalty(candidate, existing_sets, structure_positions, self_center) == 0

func _structure_selection_penalty(candidate: Array, existing_sets: Array, structure_positions: Array, self_center: Vector2) -> int:
	var candidate_set: Dictionary = {}
	for hive_id_v in candidate:
		candidate_set[int(hive_id_v)] = true
	var penalty: int = 0
	for other in existing_sets:
		var other_arr: Array = other
		if other_arr.is_empty():
			continue
		var overlap: int = 0
		for hive_id_v in other_arr:
			if candidate_set.has(int(hive_id_v)):
				overlap += 1
		var limit: int = int(float(min(candidate.size(), other_arr.size())) * 2.0 / 3.0)
		if overlap > limit:
			penalty += overlap - limit
	var hull_violations: int = _structure_hull_violation_count(candidate, structure_positions)
	if hull_violations > 0:
		penalty += hull_violations * 1000
	var candidate_center: Vector2 = _structure_center_for_required(candidate, self_center)
	if _structure_point_inside_existing_hulls(candidate_center, existing_sets):
		penalty += 1000
	return penalty

func _structure_center_for_required(required: Array, fallback_center: Vector2) -> Vector2:
	if required.is_empty():
		return fallback_center
	var sum := Vector2.ZERO
	var count := 0
	for hive_id_v in required:
		var hive: HiveData = state.find_hive_by_id(int(hive_id_v))
		if hive == null:
			continue
		sum += _cell_center(hive.grid_pos)
		count += 1
	if count == 0:
		return fallback_center
	return sum / float(count)

func _structure_point_inside_existing_hulls(point: Vector2, existing_sets: Array) -> bool:
	for other in existing_sets:
		var other_arr: Array = other
		if other_arr.size() < 3:
			continue
		var points: Array = []
		for hive_id_v in other_arr:
			var hive: HiveData = state.find_hive_by_id(int(hive_id_v))
			if hive != null:
				points.append(_cell_center(hive.grid_pos))
		if points.size() < 3:
			continue
		var hull: Array = _convex_hull(points)
		if hull.size() < 3:
			continue
		if _point_in_convex_polygon(point, hull):
			return true
	return false

func _bind_structure_control_system() -> void:
	if _structure_control_system != null and is_instance_valid(_structure_control_system):
		return
	var sim_runner: Node = get_parent()
	if sim_runner == null or not sim_runner.has_method("get_structure_control_system"):
		sim_runner = _find_sim_runner()
	if sim_runner == null or not sim_runner.has_method("get_structure_control_system"):
		return
	var scs: Object = sim_runner.call("get_structure_control_system")
	if scs == null:
		return
	_structure_control_system = scs
	if _structure_control_system.has_signal("structure_owner_changed"):
		var signal_obj = _structure_control_system.structure_owner_changed
		if not signal_obj.is_connected(_on_structure_owner_changed):
			signal_obj.connect(_on_structure_owner_changed)

func _find_sim_runner() -> Node:
	var n: Node = self
	while n != null:
		var sr: Node = n.get_node_or_null("SimRunner")
		if sr != null:
			return sr
		n = n.get_parent()
	var scene: Node = get_tree().current_scene
	if scene != null:
		return scene.find_child("SimRunner", true, false)
	return null

func _on_structure_owner_changed(
	structure_type: String,
	structure_id: int,
	prev_owner: int,
	next_owner: int,
	control_ids: Array
) -> void:
	if structure_type != "tower":
		return
	for td in towers:
		if typeof(td) != TYPE_DICTIONARY:
			continue
		if int(td.get("id", -1)) != structure_id:
			continue
		var now_ms: int = Time.get_ticks_msec()
		_reset_fire_gate_for_capture(td, next_owner, now_ms)
		SFLog.info("TOWER_CAPTURE_RESET", {
			"tower": structure_id,
			"owner": next_owner,
			"now_ms": now_ms,
			"next_fire_at_ms": now_ms
		})
		return

func _reset_fire_gate_for_capture(tower: Dictionary, owner_id: int, _now_ms: int) -> void:
	# Cooldown must ONLY exist between shots.
	tower["cooldown_remaining"] = 0.0
	tower["cooldown_ms"] = 0.0
	tower["last_fire_ms"] = -1
	tower["target_unit_id"] = -1
	if owner_id <= 0:
		tower["shot_accum_ms"] = 0.0
		return
	var tier: int = int(tower.get("tier", 1))
	tower["shot_accum_ms"] = _tower_interval_ms_for(owner_id, tier)

func _structure_hull_violation_count(candidate: Array, structure_positions: Array) -> int:
	if candidate.size() < 3:
		return 0
	var points: Array = []
	for hive_id_v in candidate:
		var hive: HiveData = state.find_hive_by_id(int(hive_id_v))
		if hive != null:
			points.append(_cell_center(hive.grid_pos))
	if points.size() < 3:
		return 0
	var hull: Array = _convex_hull(points)
	if hull.size() < 3:
		return 0
	var violations: int = 0
	for pos_v in structure_positions:
		var point: Vector2 = pos_v
		if _point_in_convex_polygon(point, hull):
			violations += 1
	return violations

func _convex_hull(points: Array) -> Array:
	var pts: Array = points.duplicate()
	pts.sort_custom(Callable(self, "_point_less"))
	if pts.size() <= 2:
		return pts
	var lower: Array = []
	for p in pts:
		while lower.size() >= 2 and _cross(lower[lower.size() - 2], lower[lower.size() - 1], p) <= 0.0:
			lower.pop_back()
		lower.append(p)
	var upper: Array = []
	for i in range(pts.size() - 1, -1, -1):
		var p: Vector2 = pts[i]
		while upper.size() >= 2 and _cross(upper[upper.size() - 2], upper[upper.size() - 1], p) <= 0.0:
			upper.pop_back()
		upper.append(p)
	lower.pop_back()
	upper.pop_back()
	return lower + upper

func _point_less(a: Vector2, b: Vector2) -> bool:
	if a.x == b.x:
		return a.y < b.y
	return a.x < b.x

func _cross(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b - a).cross(c - a)

func _point_in_convex_polygon(p: Vector2, poly: Array) -> bool:
	if poly.size() < 3:
		return false
	var sign_val: float = 0.0
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var cross_val: float = _cross(a, b, p)
		if abs(cross_val) < 0.001:
			continue
		if sign_val == 0.0:
			sign_val = sign(cross_val)
		elif sign_val * cross_val < 0.0:
			return false
	return true

func _barracks_entry_less(a: Dictionary, b: Dictionary) -> bool:
	var ad2: int = int(a["d2"])
	var bd2: int = int(b["d2"])
	if ad2 == bd2:
		return int(a["id"]) < int(b["id"])
	return ad2 < bd2
