extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	await process_frame
	_test_input_source_routes_active_lane_to_swarm()
	_test_lane_double_tap_is_mothballed()
	_test_lane_double_tap_implementation_is_retained()
	_test_lane_double_tap_retains_first_lane()
	_test_lane_renderer_can_project_locked_overlap_lane()
	_test_tutorial_skips_mothballed_double_tap()
	_test_enemy_lane_swarm_intent()
	_test_friendly_lane_swarm_intent()
	_test_retract_lane_does_not_enqueue_swarm()
	if not _failed:
		print("REINSTANCE_LANE_SWARM_SMOKE: PASS")
	quit(1 if _failed else 0)

func _test_input_source_routes_active_lane_to_swarm() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/systems/input_system.gd")
	_expect_true(source.contains("var action := \"swarm\" if lane_active else \"establish\""), "repeat lane action should be logged as swarm")
	_expect_true(source.contains("if lane_active:\n\t\t\treturn _issue_swarm_intent_result(from_id, to_id, player_id)"), "active lane repeat should route to swarm intent")

func _test_lane_double_tap_is_mothballed() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/systems/input_system.gd")
	_expect_true(source.contains("const ENABLE_LANE_DOUBLE_TAP_ACTION := false"), "lane double-tap should remain explicitly mothballed")
	_expect_true(source.contains("if not ENABLE_LANE_DOUBLE_TAP_ACTION:\n\t\treturn false\n\treturn _handle_lane_double_tap"), "public lane double-tap entry should reject while mothballed")
	_expect_true(source.contains("if ENABLE_LANE_DOUBLE_TAP_ACTION and _is_lane_double_tap"), "normal lane clicks should not activate double-tap while mothballed")
	var input_script: Script = load("res://scripts/systems/input_system.gd")
	if input_script != null:
		var input: Variant = input_script.new()
		input.setup(SelectionState.new())
		_expect_true(not input.handle_lane_double_tap(Vector2.ZERO, 1, 1, null), "mothballed public entry should reject without touching lane state")

func _test_lane_double_tap_implementation_is_retained() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/systems/input_system.gd")
	_expect_true(source.contains("const LANE_SOURCE_RETRACT_T := 0.50"), "mothballed source-half threshold should remain available")
	_expect_true(source.contains("LANE_DBL_RETRACT"), "mothballed retract implementation should remain available")
	_expect_true(source.contains("arena_api.retract_lane(src_id, dst_id, player_id)"), "mothballed retract action should remain available")

func _test_lane_double_tap_retains_first_lane() -> void:
	var input_script: Script = load("res://scripts/systems/input_system.gd")
	_expect_true(input_script != null, "input system should load for overlap lock test")
	if input_script == null:
		return
	var input: Variant = input_script.new()
	input.setup(SelectionState.new())
	input._record_lane_tap(41, Vector2(100.0, 100.0), 1)
	_expect_true(input._is_pending_lane_double_tap(Vector2(112.0, 100.0), 1, true), "nearby second tap should retain the first lane even if nearest lane changes")
	_expect_true(input._is_lane_double_tap(41, Vector2(112.0, 100.0), 1, true), "locked first lane should complete the double-tap")
	_expect_true(not input._is_lane_double_tap(42, Vector2(112.0, 100.0), 1, true), "overlapping challenger lane should not replace the first lane")

func _test_lane_renderer_can_project_locked_overlap_lane() -> void:
	var renderer_script: Script = load("res://scripts/renderers/lane_renderer.gd")
	_expect_true(renderer_script != null, "lane renderer should load for overlap projection test")
	if renderer_script == null:
		return
	var renderer: Node2D = renderer_script.new()
	get_root().add_child(renderer)
	renderer.model = {
		"lanes": [
			{"lane_id": 41, "a_id": 1, "b_id": 2, "send_a": true, "send_b": false},
			{"lane_id": 42, "a_id": 3, "b_id": 4, "send_a": true, "send_b": false}
		]
	}
	renderer.set("_hive_lane_anchor_local_by_id", {
		1: Vector2(0.0, 0.0),
		2: Vector2(100.0, 0.0),
		3: Vector2(50.0, -50.0),
		4: Vector2(50.0, 50.0)
	})
	renderer.set("_hive_cache_dirty", false)
	var crossing := Vector2(50.0, 0.0)
	var nearest: Dictionary = renderer.pick_lane_at_world_pos(crossing, 30.0)
	_expect_eq(int(nearest.get("lane_id", -1)), 42, "ordinary nearest pick may choose the later overlapping lane")
	var locked: Dictionary = renderer.pick_lane_by_id_at_world_pos(crossing, 41, 30.0)
	_expect_true(bool(locked.get("hit", false)), "locked overlap lane should remain pickable")
	_expect_eq(int(locked.get("lane_id", -1)), 41, "locked overlap projection should return the requested lane")
	_expect_true(absf(float(locked.get("t", -1.0)) - 0.5) <= 0.001, "locked lane should report its own tap position")
	renderer.queue_free()

func _test_tutorial_skips_mothballed_double_tap() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/arena_helpers/tutorial_controls_controller.gd")
	_expect_true(source.contains("# Lane double-tap is mothballed because overlaps cannot reliably"), "tutorial should document why the lesson is skipped")
	_expect_true(source.contains("if _overlap_swarm_seen:\n\t\t\t# Lane double-tap is mothballed"), "tutorial should skip the mothballed lesson after the supported swarm lands")
	_expect_true(source.contains("return STEP_FINISH_FIGHT"), "tutorial should continue to free play after the supported swarm lesson")

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

func _test_retract_lane_does_not_enqueue_swarm() -> void:
	var state := _reset_state(2)
	var ops_state := _ops_state()
	var first: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "attack")
	_expect_true(bool(first.get("ok", false)), "attack route should open before retract")
	ops_state.call("retract_lane", 1, 2, 1)
	_expect_true(not state.intent_is_on(1, 2), "retract should disable outgoing lane")
	_expect_eq(state.swarm_requests.size(), 0, "retract should not enqueue swarm")

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
