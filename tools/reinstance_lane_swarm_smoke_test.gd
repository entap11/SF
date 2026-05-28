extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	await process_frame
	_test_input_source_routes_active_lane_to_swarm()
	_test_enemy_lane_swarm_intent()
	_test_friendly_lane_swarm_intent()
	if not _failed:
		print("REINSTANCE_LANE_SWARM_SMOKE: PASS")
	quit(1 if _failed else 0)

func _test_input_source_routes_active_lane_to_swarm() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/systems/input_system.gd")
	_expect_true(source.contains("var action := \"swarm\" if lane_active else \"establish\""), "repeat lane action should be logged as swarm")
	_expect_true(source.contains("if lane_active:\n\t\t\treturn _issue_swarm_intent_result(from_id, to_id, player_id)"), "active lane repeat should route to swarm intent")

func _test_enemy_lane_swarm_intent() -> void:
	var state := _reset_state(2)
	var ops_state := _ops_state()
	var first: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "attack")
	_expect_true(bool(first.get("ok", false)), "enemy lane should open before repeat swarm")
	_expect_true(state.intent_is_on(1, 2), "enemy lane should be active before repeat swarm")
	var repeat: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "swarm")
	_expect_true(bool(repeat.get("ok", false)), "enemy lane repeat swarm intent should be accepted")
	_expect_eq(str(repeat.get("intent", "")), "swarm", "enemy lane repeat should return swarm intent")
	_expect_eq(state.swarm_requests.size(), 1, "enemy lane repeat should enqueue one swarm")
	_expect_swarm_request(state.swarm_requests[0], 1, 2, "enemy lane repeat")

func _test_friendly_lane_swarm_intent() -> void:
	var state := _reset_state(1)
	var ops_state := _ops_state()
	var first: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "feed")
	_expect_true(bool(first.get("ok", false)), "friendly lane should open before repeat swarm")
	_expect_eq(str(first.get("intent", "")), "feed", "friendly lane should resolve to feed")
	_expect_true(state.intent_is_on(1, 2), "friendly lane should be active before repeat swarm")
	var repeat: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "swarm")
	_expect_true(bool(repeat.get("ok", false)), "friendly lane repeat swarm intent should be accepted")
	_expect_eq(str(repeat.get("intent", "")), "swarm", "friendly lane repeat should return swarm intent")
	_expect_eq(state.swarm_requests.size(), 1, "friendly lane repeat should enqueue one swarm")
	_expect_swarm_request(state.swarm_requests[0], 1, 2, "friendly lane repeat")

func _reset_state(dst_owner_id: int) -> GameState:
	var ops_state := _ops_state()
	var map_dict := {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": dst_owner_id, "power": 10, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2}
		]
	}
	var state: GameState = ops_state.call("reset_state_from_map", map_dict)
	ops_state.set("match_phase", 1)
	return state

func _ops_state() -> Node:
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_expect_true(ops_state != null, "OpsState autoload should exist")
	return ops_state

func _expect_swarm_request(request: Variant, expected_src: int, expected_dst: int, label: String) -> void:
	_expect_true(typeof(request) == TYPE_DICTIONARY, "%s swarm request should be a dictionary" % label)
	if typeof(request) != TYPE_DICTIONARY:
		return
	var data: Dictionary = request as Dictionary
	_expect_eq(int(data.get("src", -1)), expected_src, "%s swarm src" % label)
	_expect_eq(int(data.get("dst", -1)), expected_dst, "%s swarm dst" % label)

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("REINSTANCE_LANE_SWARM_SMOKE: %s" % message)

func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failed = true
	push_error("REINSTANCE_LANE_SWARM_SMOKE: %s actual=%s expected=%s" % [message, str(actual), str(expected)])
