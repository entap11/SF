extends SceneTree

const MapSchema := preload("res://scripts/maps/map_schema.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")

func _init() -> void:
	await process_frame
	_test_hive_occlusion_prunes_candidates()
	_test_wall_occlusion_prunes_candidates()
	_test_wall_padding_blocks_near_miss()
	_test_auto_lane_generation_blocks_near_miss_crossing()
	_test_gbase_runtime_pair_is_blocked()
	_test_delta_lane_topology_survives_power_growth()
	_test_delta_h2_h8_is_connectable()
	_test_existing_invalid_lane_cannot_be_enabled()
	_test_lane_intent_repeats_are_idempotent()
	_test_lane_budget_block_preserves_existing_routes()
	_test_friendly_feed_reverse_replaces_only_same_friendly_lane()
	_test_swarm_cooldown_blocks_same_source()
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

func _test_wall_padding_blocks_near_miss() -> void:
	var result := MapSchema._auto_generate_lanes([
		{"id": 1, "grid_pos": [0, 0], "kind": "Hive"},
		{"id": 2, "grid_pos": [4, 1], "kind": "Hive"}
	], 5, 2, {
		"symmetric": false,
		"walls": [
			{"dir": "v", "x": 2, "y": 1}
		]
	})
	_assert_true(bool(result.get("ok", false)), "auto lane generation should succeed with wall padding")
	var lanes: Array = result.get("lanes", [])
	_assert_true(not _has_candidate(lanes, 1, 2), "lane half-width should block near-miss wall crossings")

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
	var path := "res://maps/nomansland/MAP_nomansland__GBASE__1p.json"
	if not MAP_LOADER.list_maps().has(path):
		print("LANE_OCCLUSION_SMOKE: SKIP missing GBASE lane regression map")
		return
	var loaded: Dictionary = MAP_LOADER.load_map(path)
	if not bool(loaded.get("ok", false)):
		print("LANE_OCCLUSION_SMOKE: SKIP missing GBASE lane regression map")
		return
	var state := GameState.new()
	state.load_from_map_dict(loaded.get("data", {}) as Dictionary)
	_assert_true(not state.can_connect(2, 10), "GBASE pair 2->10 should be occluded by center hives")

func _test_delta_lane_topology_survives_power_growth() -> void:
	var loaded: Dictionary = MAP_LOADER.load_map("res://maps/delta/MAP_delta__SBASE__3p.json")
	_assert_true(bool(loaded.get("ok", false)), "Delta map should load for lane topology regression")
	var state := GameState.new()
	state.load_from_map_dict(loaded.get("data", {}) as Dictionary)
	var blocker := state.find_hive_by_id(3)
	_assert_true(blocker != null, "Delta blocker hive should exist")
	blocker.power = 50
	_assert_true(state.can_connect(6, 4), "Delta H6->H4 should not become blocked when nearby hives power up")

func _test_delta_h2_h8_is_connectable() -> void:
	var loaded: Dictionary = MAP_LOADER.load_map("res://maps/delta/MAP_delta__SBASE__3p.json")
	_assert_true(bool(loaded.get("ok", false)), "Delta map should load for H2-H8 lane regression")
	var state := GameState.new()
	state.load_from_map_dict(loaded.get("data", {}) as Dictionary)
	_assert_true(state.can_connect(2, 8), "Delta H2->H8 should be connectable with narrowed lanes")
	_assert_true(state.can_connect(8, 2), "Delta H8->H2 should be connectable with narrowed lanes")

func _test_existing_invalid_lane_cannot_be_enabled() -> void:
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_assert_true(ops_state != null, "OpsState autoload should exist")
	var map_dict := {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 10, "kind": "Hive"},
			{"id": 3, "x": 2, "y": 0, "owner_id": 0, "power": 10, "kind": "Hive"}
		]
	}
	var state: GameState = ops_state.call("reset_state_from_map", map_dict)
	ops_state.set("match_phase", 1)
	state.lanes.append(LaneData.new(101, 1, 2, 1, false, false))
	state.rebuild_indexes()
	var result: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "attack")
	_assert_true(not bool(result.get("ok", false)), "existing invalid lane should not be enabled")
	_assert_eq(int(result.get("lane_id", -1)), 101, "existing invalid lane should be identified")
	_assert_true(str(result.get("reason", "")) == "blocked", "existing invalid lane should report blocked")

func _test_lane_intent_repeats_are_idempotent() -> void:
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_assert_true(ops_state != null, "OpsState autoload should exist")
	var map_dict := {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 10, "kind": "Hive"},
			{"id": 3, "x": 0, "y": 4, "owner_id": 2, "power": 10, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2},
			{"a_id": 1, "b_id": 3}
		]
	}
	var state: GameState = ops_state.call("reset_state_from_map", map_dict)
	ops_state.set("match_phase", 1)
	var first: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "attack")
	_assert_true(bool(first.get("ok", false)), "first attack route should open")
	var repeat: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "attack")
	_assert_true(bool(repeat.get("ok", false)), "repeated attack route should remain accepted")
	_assert_true(state.intent_is_on(1, 2), "repeated attack route should not toggle off")
	var second: Dictionary = ops_state.call("apply_lane_intent", 1, 3, "attack")
	_assert_true(bool(second.get("ok", false)), "second outgoing route should open within budget")
	_assert_true(state.intent_is_on(1, 2), "opening second route should not switch off first route")
	_assert_true(state.intent_is_on(1, 3), "second route should be active")

func _test_lane_budget_block_preserves_existing_routes() -> void:
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_assert_true(ops_state != null, "OpsState autoload should exist")
	var map_dict := {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 13, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 10, "kind": "Hive"},
			{"id": 3, "x": 0, "y": 4, "owner_id": 2, "power": 10, "kind": "Hive"},
			{"id": 4, "x": 4, "y": 4, "owner_id": 2, "power": 10, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2},
			{"a_id": 1, "b_id": 3},
			{"a_id": 1, "b_id": 4}
		]
	}
	var state: GameState = ops_state.call("reset_state_from_map", map_dict)
	ops_state.set("match_phase", 1)
	var first: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "attack")
	_assert_true(bool(first.get("ok", false)), "first route should open")
	var second: Dictionary = ops_state.call("apply_lane_intent", 1, 3, "attack")
	_assert_true(bool(second.get("ok", false)), "second route should open at two-lane budget")
	var third: Dictionary = ops_state.call("apply_lane_intent", 1, 4, "attack")
	_assert_true(not bool(third.get("ok", false)), "third route should be blocked by source budget")
	_assert_true(str(third.get("reason", "")) == "budget", "third route should report budget")
	_assert_true(state.intent_is_on(1, 2), "budget block should not replace first route")
	_assert_true(state.intent_is_on(1, 3), "budget block should not replace second route")
	_assert_true(not state.intent_is_on(1, 4), "budget block should not open third route")
	_assert_eq(state.lane_index_between(1, 4), -1, "budget block should not create an inactive runtime lane")
	_assert_eq(state.swarm_requests.size(), 0, "route creation should not enqueue swarms")

func _test_friendly_feed_reverse_replaces_only_same_friendly_lane() -> void:
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_assert_true(ops_state != null, "OpsState autoload should exist")
	var map_dict := {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 13, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 1, "power": 13, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2}
		]
	}
	var state: GameState = ops_state.call("reset_state_from_map", map_dict)
	ops_state.set("match_phase", 1)
	var first_feed: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "feed")
	_assert_true(bool(first_feed.get("ok", false)), "friendly feed route should open")
	_assert_true(state.intent_is_on(1, 2), "friendly feed should send from first source")
	var reverse_feed: Dictionary = ops_state.call("apply_lane_intent", 2, 1, "feed")
	_assert_true(bool(reverse_feed.get("ok", false)), "friendly reverse feed should be accepted")
	_assert_true(not state.intent_is_on(1, 2), "friendly reverse should replace the opposite direction on the same lane")
	_assert_true(state.intent_is_on(2, 1), "friendly reverse should activate the new source direction")

func _test_swarm_cooldown_blocks_same_source() -> void:
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_assert_true(ops_state != null, "OpsState autoload should exist")
	var map_dict := {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 10, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2}
		]
	}
	var state: GameState = ops_state.call("reset_state_from_map", map_dict)
	ops_state.set("match_phase", 1)
	var open_result: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "attack")
	_assert_true(bool(open_result.get("ok", false)), "attack route should open before swarm")
	var first_swarm: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "swarm")
	_assert_true(bool(first_swarm.get("ok", false)), "first swarm should be accepted")
	var second_swarm: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "swarm")
	_assert_true(not bool(second_swarm.get("ok", false)), "second same-source swarm should be blocked")
	_assert_true(str(second_swarm.get("reason", "")) == "cooldown", "second same-source swarm should report cooldown")
	_assert_true(int(state.swarm_requests.size()) == 1, "cooldown should not enqueue duplicate swarm")
	state.set("_sim_time_us", int(state.get("_sim_time_us")) + 5000000)
	var third_swarm: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "swarm")
	_assert_true(bool(third_swarm.get("ok", false)), "same-source swarm should be accepted after cooldown")
	_assert_true(int(state.swarm_requests.size()) == 2, "post-cooldown swarm should enqueue")

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
