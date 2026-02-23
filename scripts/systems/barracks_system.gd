# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name BarracksSystem
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const StructureControlSystem := preload("res://scripts/systems/structure_control_system.gd")
const StructureControlSolver := preload("res://scripts/sim/structure_control.gd")
const DEFAULT_CELL_SIZE := 64.0
const BARRACKS_MIN_REQ := 3
const BARRACKS_MAX_REQ := 6
const barracks_base_radius_px: float = DEFAULT_CELL_SIZE * 0.4
const tower_base_radius_px: float = DEFAULT_CELL_SIZE * 0.75
const base_margin_px: float = DEFAULT_CELL_SIZE * 0.1
const MAX_EXACT_K := 5
const MAX_ADJ_LANES := 12
const MAX_HIVES_OUT := BARRACKS_MAX_REQ
const MAX_CYCLE_LEN := 10
signal barracks_activated(barracks_id: int, owner_id: int)

var state: GameState = null
var structure_selector: TowerSystem = null
var barracks: Array = []
var barracks_control_ms: Dictionary = {}
var _last_barracks_snapshot: Dictionary = {}
var _logged_control_ids: Dictionary = {}
var _logged_adj_lanes: Dictionary = {}
var _logged_pick_lanes: Dictionary = {}
var _logged_pick_mode: Dictionary = {}
var _logged_cycle_candidates: Dictionary = {}
var _logged_cycle_pick: Dictionary = {}
var _logged_cycle_fail: Dictionary = {}
var _logged_lane_accept: Dictionary = {}
var _logged_lane_reject: Dictionary = {}
var _spawn_disabled_logged: bool = false

func bind_state(state_ref: GameState) -> void:
	state = state_ref
	barracks.clear()
	barracks_control_ms = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0}
	_last_barracks_snapshot.clear()
	_logged_control_ids.clear()
	_logged_adj_lanes.clear()
	_logged_pick_lanes.clear()
	_logged_pick_mode.clear()
	_logged_cycle_candidates.clear()
	_logged_cycle_pick.clear()
	_logged_cycle_fail.clear()
	_logged_lane_accept.clear()
	_logged_lane_reject.clear()
	_spawn_disabled_logged = false
	_ensure_barracks_control_ids()

func set_structure_selector(selector: TowerSystem) -> void:
	structure_selector = selector
	_ensure_barracks_control_ids()

func tick(_dt: float) -> void:
	if state == null:
		return
	if OpsState.has_outcome():
		return
	if OpsState.match_over:
		if not _spawn_disabled_logged:
			_spawn_disabled_logged = true
			SFLog.info("SPAWN_DISABLED", {"system": "barracks"})
		return
	barracks = state.barracks
	_ensure_barracks_control_ids()
	_log_barracks_changes(barracks)
	_tick_barracks_spawns(_dt)

func _ensure_barracks_fields(b: Dictionary) -> void:
	if not b.has("required_hive_ids") or typeof(b.get("required_hive_ids")) != TYPE_ARRAY:
		b["required_hive_ids"] = []
	if not b.has("control_hive_ids") or typeof(b.get("control_hive_ids")) != TYPE_ARRAY:
		b["control_hive_ids"] = []
	if not b.has("spawn_accum_ms"):
		b["spawn_accum_ms"] = 0.0
	if not b.has("route_targets") or typeof(b.get("route_targets")) != TYPE_ARRAY:
		b["route_targets"] = []
	if not b.has("route_hive_ids") or typeof(b.get("route_hive_ids")) != TYPE_ARRAY:
		b["route_hive_ids"] = []
	if not b.has("route_mode"):
		b["route_mode"] = "round_robin"
	if not b.has("route_cursor"):
		b["route_cursor"] = int(b.get("rr_index", 0))
	if not b.has("preferred_targets") or typeof(b.get("preferred_targets")) != TYPE_ARRAY:
		b["preferred_targets"] = []
	if not b.has("rr_index"):
		b["rr_index"] = int(b.get("route_cursor", 0))
	if not b.has("tier"):
		b["tier"] = 1
	if not b.has("active"):
		b["active"] = false
	var route_targets: Array = b.get("route_targets", [])
	var route_hive_ids: Array = b.get("route_hive_ids", [])
	if route_targets.is_empty() and not route_hive_ids.is_empty():
		b["route_targets"] = route_hive_ids.duplicate()
	elif route_hive_ids.is_empty() and not route_targets.is_empty():
		b["route_hive_ids"] = route_targets.duplicate()
	var route_ids: Array = b.get("route_hive_ids", [])
	if route_ids.is_empty():
		var preferred_v: Variant = b.get("preferred_targets", [])
		if typeof(preferred_v) == TYPE_ARRAY and (preferred_v as Array).size() > 0:
			b["route_hive_ids"] = (preferred_v as Array).duplicate()
			if (b.get("route_targets", []) as Array).is_empty():
				b["route_targets"] = b.get("route_hive_ids", []).duplicate()

func _ensure_barracks_control_ids() -> void:
	if state == null:
		return
	for b_any in state.barracks:
		if typeof(b_any) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = b_any as Dictionary
		var barracks_id: int = int(b.get("id", -1))
		if barracks_id <= 0:
			continue
		_ensure_barracks_fields(b)
		var req: Array = b.get("required_hive_ids", [])
		var control: Array = b.get("control_hive_ids", [])
		if req.is_empty() and not control.is_empty():
			b["required_hive_ids"] = control.duplicate()
			req = b["required_hive_ids"]
		if control.is_empty():
			var computed: Array = _barracks_adjacent_control_ids(b)
			if computed.size() >= BARRACKS_MIN_REQ:
				if req.is_empty():
					b["required_hive_ids"] = computed
				b["control_hive_ids"] = computed.duplicate()
				_log_control_ids_once(barracks_id, computed)
			elif not req.is_empty():
				b["control_hive_ids"] = req.duplicate()

func _log_control_ids_once(barracks_id: int, control_ids: Array) -> void:
	if _logged_control_ids.has(barracks_id):
		return
	_logged_control_ids[barracks_id] = true
	SFLog.info("BARRACKS_CONTROL_IDS", {"id": barracks_id, "control_ids": control_ids})

func _log_adj_lanes_once(barracks_id: int, adj_lane_count: int) -> void:
	if _logged_adj_lanes.has(barracks_id):
		return
	_logged_adj_lanes[barracks_id] = true
	SFLog.info("BARRACKS_ADJ_LANES", {"id": barracks_id, "adj_count": adj_lane_count})

func _log_pick_lanes_once(barracks_id: int, k: int, lane_labels: Array, unique_hives: Array, coverage_deg: float, sum_dist: float) -> void:
	if _logged_pick_lanes.has(barracks_id):
		return
	_logged_pick_lanes[barracks_id] = true
	SFLog.info("BARRACKS_PICK_LANES", {
		"id": barracks_id,
		"k": k,
		"chosen": lane_labels,
		"unique_hives": unique_hives,
		"coverage_deg": coverage_deg,
		"sum_dist": sum_dist
	})

func _log_pick_mode_once(barracks_id: int, mode: String, k: int, adj_considered: int, unique_hives: int, coverage_deg: float, largest_gap_deg: float) -> void:
	if _logged_pick_mode.has(barracks_id):
		return
	_logged_pick_mode[barracks_id] = true
	SFLog.info("BARRACKS_PICK_MODE", {
		"id": barracks_id,
		"mode": mode,
		"k": k,
		"adj_considered": adj_considered,
		"unique_hives": unique_hives,
		"coverage_deg": coverage_deg,
		"largest_gap_deg": largest_gap_deg
	})

func _log_cycle_candidate(barracks_id: int, cycle: Array, perimeter: float, contains: bool) -> void:
	if _logged_cycle_candidates.has(barracks_id):
		return
	SFLog.info("BARRACKS_CYCLE_CANDIDATE", {
		"id": barracks_id,
		"len": cycle.size(),
		"perimeter": perimeter,
		"contains": contains,
		"hives": cycle
	})

func _log_cycle_candidates_done(barracks_id: int) -> void:
	_logged_cycle_candidates[barracks_id] = true

func _log_cycle_pick_once(barracks_id: int, cycle: Array, perimeter: float) -> void:
	if _logged_cycle_pick.has(barracks_id):
		return
	_logged_cycle_pick[barracks_id] = true
	SFLog.info("BARRACKS_CYCLE_PICK", {
		"id": barracks_id,
		"len": cycle.size(),
		"perimeter": perimeter,
		"hives": cycle
	})

func _log_cycle_fail_once(barracks_id: int, reason: String, adj_count: int) -> void:
	if _logged_cycle_fail.has(barracks_id):
		return
	_logged_cycle_fail[barracks_id] = true
	SFLog.info("BARRACKS_CYCLE_FAIL", {
		"id": barracks_id,
		"reason": reason,
		"adj_count": adj_count
	})

func _log_lane_accept_once(kind: String, structure_id: int, lane_label: String, dist: float) -> void:
	var key := "%s:%d:%s" % [kind, structure_id, lane_label]
	if _logged_lane_accept.has(key):
		return
	_logged_lane_accept[key] = true
	SFLog.info("STRUCTURE_LANE_ACCEPT", {
		"kind": kind,
		"structure_id": structure_id,
		"lane": lane_label,
		"d": dist
	})

func _log_lane_reject_once(kind: String, structure_id: int, lane_label: String, dist: float, threshold: float) -> void:
	var key := "%s:%d:%s" % [kind, structure_id, lane_label]
	if _logged_lane_reject.has(key):
		return
	_logged_lane_reject[key] = true
	SFLog.info("STRUCTURE_LANE_REJECT", {
		"kind": kind,
		"structure_id": structure_id,
		"lane": lane_label,
		"d": dist,
		"threshold": threshold
	})

func _log_lane_eval(kind: String, structure_id: int, lane_label: String, dist: float, threshold: float, is_adj: bool) -> void:
	SFLog.info("STRUCTURE_LANE_EVAL", {
		"kind": kind,
		"id": structure_id,
		"lane": lane_label,
		"d": dist,
		"threshold": threshold,
		"is_adj": is_adj
	})

func _barracks_adjacent_control_ids(barracks_data: Dictionary) -> Array:
	if state == null:
		return []
	var barracks_id: int = int(barracks_data.get("id", -1))
	if barracks_id < 0:
		return []
	var center: Vector2 = _cell_center(_barracks_grid_pos(barracks_data))
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
		"barracks",
		barracks_id,
		barracks_base_radius_px,
		BARRACKS_MIN_REQ,
		MAX_CYCLE_LEN
	)
	return picked.get("ids", [])

func _barracks_cycle_control_ids(barracks_id: int, center: Vector2, adj_lanes: Array) -> Array:
	var hive_positions: Dictionary = _hive_positions_for_lanes(adj_lanes)
	if hive_positions.is_empty():
		_log_cycle_fail_once(barracks_id, "missing_positions", adj_lanes.size())
		return []
	var picked: Dictionary = StructureControlSolver.pick_min_enclosing_cycle(
		adj_lanes,
		hive_positions,
		center,
		BARRACKS_MIN_REQ,
		MAX_CYCLE_LEN,
		"barracks",
		barracks_id
	)
	var ids: Array = picked.get("ids", [])
	if ids.is_empty():
		var cycle_count: int = int(picked.get("cycle_count", 0))
		if cycle_count == 0:
			_log_cycle_fail_once(barracks_id, "no_cycles", adj_lanes.size())
		else:
			_log_cycle_fail_once(barracks_id, "no_containing", adj_lanes.size())
		return []
	_log_cycle_candidates_done(barracks_id)
	return ids

func _cycle_lex_less(a: Array[int], b: Array[int]) -> bool:
	var n: int = min(a.size(), b.size())
	for i in range(n):
		var av := int(a[i])
		var bv := int(b[i])
		if av < bv:
			return true
		if av > bv:
			return false
	return a.size() < b.size()

func _hive_positions_for_lanes(adj_lanes: Array) -> Dictionary:
	var out: Dictionary = {}
	for lane in adj_lanes:
		var a_id := int(lane.get("a_id", 0))
		var b_id := int(lane.get("b_id", 0))
		if a_id > 0 and not out.has(a_id):
			out[a_id] = state.hive_world_pos_by_id(a_id)
		if b_id > 0 and not out.has(b_id):
			out[b_id] = state.hive_world_pos_by_id(b_id)
	return out

func _finalize_lane_pick(barracks_id: int, mode: String, pick: Dictionary, adj_considered: int, center: Vector2) -> Array:
	var unique_hives: Array = pick.get("unique_hives", [])
	var k: int = int(pick.get("k", 0))
	var sum_dist: float = float(pick.get("sum_dist", 0.0))
	var lane_labels: Array = pick.get("lane_labels", [])
	var pruned: Array = _prune_hives_for_coverage(unique_hives, center, MAX_HIVES_OUT)
	var stats := _coverage_stats_for_hives(pruned, center)
	var coverage: float = float(stats.get("coverage", 0.0))
	var gap: float = float(stats.get("largest_gap", 0.0))
	_log_pick_lanes_once(barracks_id, k, lane_labels, pruned, rad_to_deg(coverage), sum_dist)
	_log_pick_mode_once(barracks_id, mode, k, adj_considered, pruned.size(), rad_to_deg(coverage), rad_to_deg(gap))
	return pruned

func _adjacent_lanes(center: Vector2, structure_id: int, kind: String, base_radius_px: float) -> Array:
	var lanes_src: Array = []
	if state.lanes != null and not state.lanes.is_empty():
		lanes_src = state.lanes
	else:
		var candidates_v: Variant = state.lane_candidates
		if typeof(candidates_v) == TYPE_ARRAY:
			lanes_src = candidates_v as Array
	var out: Array = []
	for lane_any in lanes_src:
		var lane_id: int = -1
		var a_id: int = -1
		var b_id: int = -1
		if lane_any is LaneData:
			var ld: LaneData = lane_any as LaneData
			lane_id = int(ld.id)
			a_id = int(ld.a_id)
			b_id = int(ld.b_id)
		elif lane_any is Dictionary:
			var lane_dict: Dictionary = lane_any as Dictionary
			lane_id = int(lane_dict.get("lane_id", lane_dict.get("id", -1)))
			a_id = int(lane_dict.get("a_id", lane_dict.get("from", lane_dict.get("from_hive", 0))))
			b_id = int(lane_dict.get("b_id", lane_dict.get("to", lane_dict.get("to_hive", 0))))
		if a_id <= 0 or b_id <= 0:
			continue
		var a_pos: Vector2 = state.hive_world_pos_by_id(a_id)
		var b_pos: Vector2 = state.hive_world_pos_by_id(b_id)
		var lane_label: String = "%d-%d" % [a_id, b_id]
		var base_radius: float = float(base_radius_px)
		if base_radius > 0.0 and StructureControlSolver.segment_intersects_circle(a_pos, b_pos, center, base_radius):
			continue
		var threshold: float = float(base_radius_px + base_margin_px)
		var d: float = StructureControlSolver.distance_point_to_segment(center, a_pos, b_pos)
		var is_adj: bool = d <= threshold
		_log_lane_eval(kind, structure_id, lane_label, d, threshold, is_adj)
		if not is_adj:
			_log_lane_reject_once(kind, structure_id, lane_label, d, threshold)
			continue
		_log_lane_accept_once(kind, structure_id, lane_label, d)
		var key: String = "%d:%d" % [mini(a_id, b_id), maxi(a_id, b_id)]
		out.append({
			"key": key,
			"lane_id": lane_id,
			"a_id": a_id,
			"b_id": b_id,
			"dist": d
		})
	out.sort_custom(Callable(self, "_adj_lane_less"))
	if out.size() > MAX_ADJ_LANES:
		out = out.slice(0, MAX_ADJ_LANES)
	return out

func _adj_lane_less(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("dist", 0.0)) < float(b.get("dist", 0.0))

func _pick_adjacent_lane_subset(adj_lanes: Array, center: Vector2) -> Dictionary:
	var best_global: Dictionary = {}
	for k in range(1, MAX_EXACT_K + 1):
		if adj_lanes.size() < k:
			break
		var best_for_k: Dictionary = {
			"coverage": -1.0,
			"sum_dist": INF,
			"lanes": [],
			"unique_hives": []
		}
		_search_lane_subsets(adj_lanes, k, 0, [], 0.0, center, best_for_k)
		if float(best_for_k.get("coverage", -1.0)) >= 0.0:
			best_global = best_for_k
			best_global["k"] = k
			break
	if best_global.is_empty():
		return {}
	return _lane_pick_with_labels(best_global)

func _search_lane_subsets(adj_lanes: Array, k: int, start_idx: int, current: Array, current_dist: float, center: Vector2, best_state: Dictionary) -> void:
	if current.size() == k:
		var unique_hives: Array = _unique_hives_for_lanes(current)
		var count := unique_hives.size()
		if count < BARRACKS_MIN_REQ or count > BARRACKS_MAX_REQ:
			return
		var stats := _coverage_stats_for_hives(unique_hives, center)
		var coverage := float(stats.get("coverage", 0.0))
		var threshold := _coverage_threshold_rad(count)
		if coverage < threshold:
			return
		var best_cov: float = float(best_state.get("coverage", -1.0))
		var best_dist: float = float(best_state.get("sum_dist", INF))
		if coverage > best_cov or (is_equal_approx(coverage, best_cov) and current_dist < best_dist):
			best_state["coverage"] = coverage
			best_state["largest_gap"] = float(stats.get("largest_gap", 0.0))
			best_state["sum_dist"] = current_dist
			best_state["lanes"] = current.duplicate(true)
			best_state["unique_hives"] = unique_hives
		return
	if start_idx >= adj_lanes.size():
		return
	if current.size() + (adj_lanes.size() - start_idx) < k:
		return
	for i in range(start_idx, adj_lanes.size()):
		var lane: Dictionary = adj_lanes[i]
		current.append(lane)
		_search_lane_subsets(adj_lanes, k, i + 1, current, current_dist + float(lane.get("dist", 0.0)), center, best_state)
		current.pop_back()

func _unique_hives_for_lanes(lanes_in: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for lane in lanes_in:
		var a_id := int(lane.get("a_id", 0))
		var b_id := int(lane.get("b_id", 0))
		if a_id > 0 and not seen.has(a_id):
			seen[a_id] = true
			out.append(a_id)
		if b_id > 0 and not seen.has(b_id):
			seen[b_id] = true
			out.append(b_id)
	out.sort()
	return out

func _coverage_stats_for_hives(hive_ids: Array, center: Vector2) -> Dictionary:
	if hive_ids.size() < 2:
		return {"coverage": 0.0, "largest_gap": TAU}
	var angles: Array = []
	for hive_id_v in hive_ids:
		var hive_id: int = int(hive_id_v)
		var hive: HiveData = state.find_hive_by_id(hive_id)
		if hive == null:
			continue
		var pos: Vector2 = _cell_center(hive.grid_pos)
		var angle := atan2(pos.y - center.y, pos.x - center.x)
		angles.append(angle)
	if angles.size() < 2:
		return {"coverage": 0.0, "largest_gap": TAU}
	angles.sort()
	var max_gap := 0.0
	for i in range(angles.size()):
		var a0 := float(angles[i])
		var a1 := float(angles[(i + 1) % angles.size()])
		var gap := a1 - a0
		if gap < 0.0:
			gap += TAU
		if gap > max_gap:
			max_gap = gap
	return {"coverage": TAU - max_gap, "largest_gap": max_gap}

func _coverage_for_hives(hive_ids: Array, center: Vector2) -> float:
	var stats := _coverage_stats_for_hives(hive_ids, center)
	return float(stats.get("coverage", 0.0))

func _coverage_threshold_rad(count: int) -> float:
	if count <= 3:
		return deg_to_rad(240.0)
	if count == 4:
		return deg_to_rad(270.0)
	return deg_to_rad(300.0)

func _candidate_hive_ids_from_lanes(adj_lanes: Array) -> Array:
	var candidate: Dictionary = {}
	for lane in adj_lanes:
		var a_id := int(lane.get("a_id", 0))
		var b_id := int(lane.get("b_id", 0))
		if a_id > 0:
			candidate[a_id] = true
		if b_id > 0:
			candidate[b_id] = true
	var out: Array = []
	for hive_id_v in candidate.keys():
		out.append(int(hive_id_v))
	out.sort()
	return out

func _best_lane_seed(adj_lanes: Array, center: Vector2) -> Dictionary:
	var best: Dictionary = {}
	for k in range(1, MAX_EXACT_K + 1):
		if adj_lanes.size() < k:
			break
		var best_for_k: Dictionary = {
			"coverage": -1.0,
			"sum_dist": INF,
			"lanes": [],
			"unique_hives": [],
			"largest_gap": TAU
		}
		_search_lane_subsets_any(adj_lanes, k, 0, [], 0.0, center, best_for_k)
		if float(best_for_k.get("coverage", -1.0)) >= 0.0:
			best = best_for_k
			best["k"] = k
			break
	if best.is_empty():
		return {}
	return _lane_pick_with_labels(best)

func _search_lane_subsets_any(adj_lanes: Array, k: int, start_idx: int, current: Array, current_dist: float, center: Vector2, best_state: Dictionary) -> void:
	if current.size() == k:
		var unique_hives: Array = _unique_hives_for_lanes(current)
		var count := unique_hives.size()
		if count < BARRACKS_MIN_REQ or count > MAX_HIVES_OUT:
			return
		var stats := _coverage_stats_for_hives(unique_hives, center)
		var coverage := float(stats.get("coverage", 0.0))
		var best_cov: float = float(best_state.get("coverage", -1.0))
		var best_dist: float = float(best_state.get("sum_dist", INF))
		if coverage > best_cov or (is_equal_approx(coverage, best_cov) and current_dist < best_dist):
			best_state["coverage"] = coverage
			best_state["largest_gap"] = float(stats.get("largest_gap", 0.0))
			best_state["sum_dist"] = current_dist
			best_state["lanes"] = current.duplicate(true)
			best_state["unique_hives"] = unique_hives
		return
	if start_idx >= adj_lanes.size():
		return
	if current.size() + (adj_lanes.size() - start_idx) < k:
		return
	for i in range(start_idx, adj_lanes.size()):
		var lane: Dictionary = adj_lanes[i]
		current.append(lane)
		_search_lane_subsets_any(adj_lanes, k, i + 1, current, current_dist + float(lane.get("dist", 0.0)), center, best_state)
		current.pop_back()

func _greedy_fill_lanes(adj_lanes: Array, center: Vector2, seed: Dictionary) -> Dictionary:
	var selected: Array = []
	var selected_keys: Dictionary = {}
	var sum_dist := 0.0
	if seed.has("lanes"):
		for lane in seed.get("lanes", []):
			selected.append(lane)
			selected_keys[lane.get("key", "")] = true
			sum_dist += float(lane.get("dist", 0.0))
	var unique_hives: Array = _unique_hives_for_lanes(selected)
	var stats := _coverage_stats_for_hives(unique_hives, center)
	var coverage := float(stats.get("coverage", 0.0))
	while unique_hives.size() < MAX_HIVES_OUT:
		var best_lane: Dictionary = {}
		var best_score := 0.0
		var best_cov := coverage
		var best_gap := float(stats.get("largest_gap", TAU))
		for lane in adj_lanes:
			var key := str(lane.get("key", ""))
			if selected_keys.has(key):
				continue
			var trial_lanes: Array = selected.duplicate(true)
			trial_lanes.append(lane)
			var trial_hives: Array = _unique_hives_for_lanes(trial_lanes)
			if trial_hives.size() > MAX_HIVES_OUT:
				continue
			var trial_stats := _coverage_stats_for_hives(trial_hives, center)
			var trial_cov := float(trial_stats.get("coverage", 0.0))
			var improvement := trial_cov - coverage
			if improvement <= 0.0:
				continue
			var dist := maxf(float(lane.get("dist", 0.0)), 0.001)
			var score := improvement / dist
			if score > best_score:
				best_score = score
				best_lane = lane
				best_cov = trial_cov
				best_gap = float(trial_stats.get("largest_gap", TAU))
		if best_lane.is_empty():
			break
		selected.append(best_lane)
		selected_keys[best_lane.get("key", "")] = true
		sum_dist += float(best_lane.get("dist", 0.0))
		unique_hives = _unique_hives_for_lanes(selected)
		coverage = best_cov
		stats = {"coverage": best_cov, "largest_gap": best_gap}
	return {
		"lanes": selected,
		"unique_hives": unique_hives,
		"coverage": coverage,
		"largest_gap": float(stats.get("largest_gap", TAU)),
		"sum_dist": sum_dist,
		"k": selected.size()
	}

func _lane_pick_with_labels(pick: Dictionary) -> Dictionary:
	var lane_labels: Array = []
	for lane in pick.get("lanes", []):
		var a_id := int(lane.get("a_id", 0))
		var b_id := int(lane.get("b_id", 0))
		lane_labels.append("%d-%d" % [a_id, b_id])
	pick["lane_labels"] = lane_labels
	return pick

func _prune_hives_for_coverage(hive_ids: Array, center: Vector2, desired_count: int) -> Array:
	var ids: Array = hive_ids.duplicate()
	if ids.size() <= desired_count:
		return ids
	while ids.size() > desired_count:
		var distances: Array = []
		for hive_id_v in ids:
			var hive_id: int = int(hive_id_v)
			var hive: HiveData = state.find_hive_by_id(hive_id)
			if hive == null:
				continue
			var pos: Vector2 = _cell_center(hive.grid_pos)
			distances.append({"id": hive_id, "d2": pos.distance_squared_to(center)})
		distances.sort_custom(Callable(self, "_adj_farther_first"))
		var removed := false
		for entry in distances:
			var candidate_ids: Array = ids.duplicate()
			candidate_ids.erase(int(entry.get("id", -1)))
			if candidate_ids.size() < BARRACKS_MIN_REQ:
				continue
			var coverage := _coverage_for_hives(candidate_ids, center)
			if coverage >= _coverage_threshold_rad(candidate_ids.size()):
				ids = candidate_ids
				removed = true
				break
		if not removed:
			break
	return ids

func _adj_farther_first(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("d2", 0.0)) > float(b.get("d2", 0.0))

func _pick_barracks_control_ids(candidate_ids: Array, center: Vector2) -> Array:
	if candidate_ids.is_empty():
		return []
	var entries: Array = []
	for hive_id_v in candidate_ids:
		var hive_id: int = int(hive_id_v)
		var hive: HiveData = state.find_hive_by_id(hive_id)
		if hive == null:
			continue
		var pos: Vector2 = _cell_center(hive.grid_pos)
		var d2: float = pos.distance_squared_to(center)
		entries.append({"id": hive_id, "d2": d2})
	if entries.is_empty():
		return []
	entries.sort_custom(Callable(self, "_adj_entry_less"))
	if entries.size() >= 4:
		entries = entries.slice(0, 4)
	elif entries.size() < BARRACKS_MIN_REQ:
		return []
	var out: Array = []
	for entry in entries:
		out.append(int(entry.get("id", -1)))
	return out

func _adj_entry_less(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("d2", 0.0)) < float(b.get("d2", 0.0))

func _log_barracks_changes(list: Array) -> void:
	var present_ids: Dictionary = {}
	for b_any in list:
		if typeof(b_any) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = b_any as Dictionary
		var id: int = int(b.get("id", -1))
		if id <= 0:
			continue
		present_ids[id] = true
		var owner_id: int = int(b.get("owner_id", 0))
		var prev_v: Variant = _last_barracks_snapshot.get(id, null)
		if prev_v == null:
			SFLog.info("BARRACKS_APPEAR", {
				"id": id,
				"owner_id": owner_id,
				"grid_pos": b.get("grid_pos", Vector2i.ZERO)
			})
		else:
			var prev_owner: int = int(prev_v)
			if prev_owner != owner_id:
				SFLog.info("BARRACKS_CHANGED", {
					"id": id,
					"from": prev_owner,
					"to": owner_id
				})
		_last_barracks_snapshot[id] = owner_id
	for id_v in _last_barracks_snapshot.keys():
		var id: int = int(id_v)
		if not present_ids.has(id):
			_last_barracks_snapshot.erase(id)

func _tick_barracks_spawns(dt: float) -> void:
	if state == null:
		return
	var unit_system: UnitSystem = state.unit_system
	if unit_system == null:
		return
	var dt_ms: float = dt * 1000.0
	for b_any in barracks:
		if typeof(b_any) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = b_any as Dictionary
		var barracks_id: int = int(b.get("id", -1))
		if barracks_id <= 0:
			continue
		_ensure_barracks_fields(b)
		var was_active: bool = bool(b.get("active", false))
		var control_ids: Array = StructureControlSystem.control_ids_for(b)
		var owner_id: int = int(b.get("owner_id", 0))
		var is_controlled: bool = bool(b.get("is_controlled", owner_id > 0))
		if not is_controlled or control_ids.size() < BARRACKS_MIN_REQ:
			b["active"] = false
			b["tier"] = 1
			b["spawn_accum_ms"] = 0.0
			continue
		var min_tier: int = _barracks_tier_for_owner(control_ids, owner_id)
		if min_tier <= 0:
			b["active"] = false
			b["tier"] = 1
			b["spawn_accum_ms"] = 0.0
			continue
		b["active"] = true
		b["tier"] = min_tier
		if not was_active:
			emit_signal("barracks_activated", barracks_id, owner_id)
		barracks_control_ms[owner_id] = float(barracks_control_ms.get(owner_id, 0.0)) + dt_ms
		b["spawn_accum_ms"] = float(b.get("spawn_accum_ms", 0.0)) + dt_ms
		var interval_ms: float = _barracks_interval_ms(min_tier)
		while float(b.get("spawn_accum_ms", 0.0)) >= interval_ms:
			b["spawn_accum_ms"] = float(b.get("spawn_accum_ms", 0.0)) - interval_ms
			var targets: Array = _barracks_targets(b, owner_id)
			if targets.is_empty():
				b["spawn_accum_ms"] = 0.0
				break
			var route_mode: String = str(b.get("route_mode", "round_robin"))
			var cursor: int = int(b.get("route_cursor", b.get("rr_index", 0)))
			if cursor < 0:
				cursor = 0
			var idx: int = cursor % targets.size()
			var target_id: int = int(targets[idx])
			b["route_cursor"] = cursor + 1
			b["rr_index"] = int(b.get("route_cursor", 0))
			SFLog.info("BARRACKS_ROUTE_PICK", {
				"id": barracks_id,
				"target_hive_id": target_id,
				"mode": route_mode,
				"cursor": cursor
			})
			_spawn_barracks_unit(b, target_id, owner_id, unit_system)
			SFLog.info("BARRACKS_SPAWN", {
				"id": barracks_id,
				"owner_id": owner_id,
				"target_id": target_id
			})

func _barracks_interval_ms(tier: int) -> float:
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

func _barracks_targets(barracks_data: Dictionary, owner_id: int) -> Array:
	var allowed: Array = []
	var allowed_lookup: Dictionary = {}
	var control_v: Variant = barracks_data.get("control_hive_ids", [])
	if typeof(control_v) == TYPE_ARRAY:
		for hive_id_v in control_v as Array:
			var hive_id: int = int(hive_id_v)
			if hive_id <= 0 or allowed_lookup.has(hive_id):
				continue
			var hive: HiveData = state.find_hive_by_id(hive_id)
			if hive != null and hive.owner_id == owner_id:
				allowed_lookup[hive_id] = true
				allowed.append(hive_id)
	if allowed.is_empty():
		var required_v: Variant = barracks_data.get("required_hive_ids", [])
		if typeof(required_v) == TYPE_ARRAY:
			for hive_id_v in required_v as Array:
				var hive_id: int = int(hive_id_v)
				if hive_id <= 0 or allowed_lookup.has(hive_id):
					continue
				var hive: HiveData = state.find_hive_by_id(hive_id)
				if hive != null and hive.owner_id == owner_id:
					allowed_lookup[hive_id] = true
					allowed.append(hive_id)
	if allowed.is_empty():
		return []
	allowed.sort()
	var route_v: Variant = barracks_data.get("route_targets", [])
	if typeof(route_v) != TYPE_ARRAY or (route_v as Array).is_empty():
		route_v = barracks_data.get("route_hive_ids", [])
	if typeof(route_v) != TYPE_ARRAY or (route_v as Array).is_empty():
		route_v = barracks_data.get("preferred_targets", [])
	var route: Array = []
	if typeof(route_v) == TYPE_ARRAY:
		var seen: Dictionary = {}
		for target_id_v in route_v as Array:
			var target_id: int = int(target_id_v)
			if allowed_lookup.has(target_id) and not seen.has(target_id):
				seen[target_id] = true
				route.append(target_id)
	if route.is_empty():
		return allowed
	return route

func _barracks_tier_for_owner(control_ids: Array, owner_id: int) -> int:
	var min_tier: int = 4
	for hive_id_v in control_ids:
		var hive_id: int = int(hive_id_v)
		var hive: HiveData = state.find_hive_by_id(hive_id)
		if hive == null or hive.owner_id != owner_id:
			return 0
		min_tier = min(min_tier, _hive_tier(hive.power))
	return min_tier

func _hive_tier(power: int) -> int:
	if power >= 50:
		return 4
	if power >= 25:
		return 3
	if power >= 10:
		return 2
	return 1

func _barracks_center_pos(barracks_data: Dictionary) -> Vector2:
	var required_v: Variant = barracks_data.get("required_hive_ids", [])
	if typeof(required_v) != TYPE_ARRAY or (required_v as Array).is_empty():
		return _cell_center(_barracks_grid_pos(barracks_data))
	var sum := Vector2.ZERO
	var count := 0
	for hive_id_v in required_v as Array:
		var hive: HiveData = state.find_hive_by_id(int(hive_id_v))
		if hive == null:
			continue
		sum += _cell_center(hive.grid_pos)
		count += 1
	if count == 0:
		return _cell_center(_barracks_grid_pos(barracks_data))
	return sum / float(count)

func _barracks_grid_pos(barracks_data: Dictionary) -> Vector2i:
	var gp_v: Variant = barracks_data.get("grid_pos", Vector2i.ZERO)
	if gp_v is Vector2i:
		return gp_v as Vector2i
	if gp_v is Array:
		var gp_arr: Array = gp_v as Array
		if gp_arr.size() >= 2:
			return Vector2i(int(gp_arr[0]), int(gp_arr[1]))
	var x: int = int(barracks_data.get("x", 0))
	var y: int = int(barracks_data.get("y", 0))
	return Vector2i(x, y)

func _cell_center(cell: Vector2i) -> Vector2:
	if state != null and state.grid_spec != null:
		return state.grid_spec.grid_to_world(cell)
	return Vector2(
		(float(cell.x) + 0.5) * DEFAULT_CELL_SIZE,
		(float(cell.y) + 0.5) * DEFAULT_CELL_SIZE
	)

func _barracks_target_pos(target_id: int, from_pos: Vector2) -> Vector2:
	var target_pos: Vector2 = state.hive_world_pos_by_id(target_id)
	var dir := target_pos - from_pos
	if dir.length_squared() <= 0.0001:
		return target_pos
	var dir_n := dir.normalized()
	return target_pos - dir_n * GameState.HIVE_RADIUS_PX

func _spawn_barracks_unit(barracks_data: Dictionary, target_id: int, owner_id: int, unit_system: UnitSystem) -> void:
	var from_pos: Vector2 = _barracks_center_pos(barracks_data)
	var to_pos: Vector2 = _barracks_target_pos(target_id, from_pos)
	var barracks_id: int = int(barracks_data.get("id", -1))
	var unit: Dictionary = {
		"from_id": -barracks_id,
		"to_id": target_id,
		"owner_id": owner_id,
		"amount": 1,
		"lane_id": -1,
		"dir": 1,
		"t": 0.0,
		"from_pos": from_pos,
		"to_pos": to_pos,
		"pos": from_pos,
		"arrive_source": "barracks",
		"skip_pressure": true
	}
	SFLog.info("BARRACKS_DELIVER", {
		"id": barracks_id,
		"target_hive_id": target_id,
		"amount": int(unit.get("amount", 1))
	})
	unit_system.spawn_unit(unit)
