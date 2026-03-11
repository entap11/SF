extends SceneTree

const MapSchema := preload("res://scripts/maps/map_schema.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")

func _init() -> void:
	await process_frame
	_test_hive_occlusion_prunes_candidates()
	_test_wall_occlusion_prunes_candidates()
	_test_auto_lane_generation_blocks_near_miss_crossing()
	_test_gbase_runtime_pair_is_blocked()
	print("LANE_OCCLUSION_SMOKE: PASS")
	quit(0)

func _test_hive_occlusion_prunes_candidates() -> void:
	var state := GameState.new()
	state.load_from_map_dict({
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "kind": "Hive"},
			{"id": 3, "x": 2, "y": 0, "owner_id": 0, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2},
			{"a_id": 1, "b_id": 3},
			{"a_id": 2, "b_id": 3}
		]
	})
	_assert_true(not state.can_connect(1, 2), "third hive should occlude the straight lane")
	_assert_eq(_candidate_count(state.lane_candidates), 2, "occluded hive lane should be removed from candidates")
	_assert_true(_has_candidate(state.lane_candidates, 1, 3), "unoccluded candidate 1-3 should remain")
	_assert_true(_has_candidate(state.lane_candidates, 2, 3), "unoccluded candidate 2-3 should remain")

func _test_wall_occlusion_prunes_candidates() -> void:
	var state := GameState.new()
	state.load_from_map_dict({
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "kind": "Hive"}
		],
		"walls": [
			{"dir": "v", "x": 2, "y": 0}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2}
		]
	})
	_assert_true(not state.can_connect(1, 2), "wall should occlude the lane")
	_assert_eq(_candidate_count(state.lane_candidates), 0, "wall-blocked lane should be removed from candidates")

func _test_auto_lane_generation_blocks_near_miss_crossing() -> void:
	var result := MapSchema._auto_generate_lanes([
		{"id": 1, "grid_pos": [0, 0], "kind": "Hive"},
		{"id": 2, "grid_pos": [4, 1], "kind": "Hive"},
		{"id": 3, "grid_pos": [2, 0], "kind": "Hive"}
	], 5, 2, {"symmetric": false})
	_assert_true(bool(result.get("ok", false)), "auto lane generation should succeed")
	var lanes: Array = result.get("lanes", [])
	_assert_true(not _has_candidate(lanes, 1, 2), "auto lanes should block a near-miss lane through a hive body")
	_assert_true(_has_candidate(lanes, 1, 3), "auto lanes should keep the unoccluded local link")
	_assert_true(_has_candidate(lanes, 2, 3), "auto lanes should keep the unoccluded local link")

func _test_gbase_runtime_pair_is_blocked() -> void:
	var loaded: Dictionary = MAP_LOADER.load_map("res://maps/nomansland/MAP_nomansland__GBASE__1p.json")
	_assert_true(bool(loaded.get("ok", false)), "GBASE map should load for lane regression")
	var state := GameState.new()
	state.load_from_map_dict(loaded.get("data", {}) as Dictionary)
	_assert_true(not state.can_connect(2, 10), "GBASE pair 2->10 should be occluded by center hives")

func _candidate_count(candidates: Array) -> int:
	return candidates.size()

func _has_candidate(candidates: Array, a_id: int, b_id: int) -> bool:
	for lane_any in candidates:
		if typeof(lane_any) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = lane_any as Dictionary
		var aa: int = int(lane.get("a_id", lane.get("from", 0)))
		var bb: int = int(lane.get("b_id", lane.get("to", 0)))
		var lo: int = mini(aa, bb)
		var hi: int = maxi(aa, bb)
		if lo == mini(a_id, b_id) and hi == maxi(a_id, b_id):
			return true
	return false

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	_fail("%s (expected %d, got %d)" % [label, expected, actual])

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_fail(label)

func _fail(message: String) -> void:
	push_error("LANE_OCCLUSION_SMOKE: %s" % message)
	quit(1)
