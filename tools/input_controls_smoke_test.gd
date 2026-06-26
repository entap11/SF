extends SceneTree

class FakeArena:
	extends Node2D

	var active_player_id: int = 1
	var DRAG_DEADZONE_PX: float = 8.0
	var grid_spec: Object = null
	var dirty_reasons: Array[String] = []
	var tap_log: Array[int] = []

	func _handle_tap(hive_id: int, _dev_pid: int = -1) -> void:
		tap_log.append(hive_id)

	func mark_render_dirty(reason: String = "") -> void:
		dirty_reasons.append(reason)

	func _cell_from_point(local_pos: Vector2) -> Vector2i:
		return Vector2i(roundi(local_pos.x), roundi(local_pos.y))

	func _cell_center(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x), float(cell.y))

	func _pick_lane(_local_pos: Vector2) -> Variant:
		return null

	func _pick_lane_hit(_local_pos: Vector2) -> Dictionary:
		return {"ok": false, "lane_id": -1, "t": 0.0}


var _failed: bool = false

func _initialize() -> void:
	await process_frame
	_test_tap_tap_enemy_lane_creation()
	_test_tap_tap_friendly_feed_and_reverse()
	_test_tap_tap_active_lane_reinstances_swarm()
	if not _failed:
		print("INPUT_CONTROLS_SMOKE: PASS")
	quit(1 if _failed else 0)

func _test_tap_tap_enemy_lane_creation() -> void:
	var harness: Dictionary = _make_harness(2)
	if _harness_missing(harness, "enemy lane"):
		return
	var input: Variant = harness.get("input")
	var api: Variant = harness.get("api")
	var state: Variant = harness.get("state")
	_tap_hive(input, api, 1, Vector2(0, 0))
	_expect_eq(input.selected_src_id, 1, "first tap should select owned source hive")
	_tap_hive(input, api, 2, Vector2(4, 0))
	_expect_true(state.intent_is_on(1, 2), "tap/tap owned source to enemy destination should create attack lane")
	_expect_true(not state.intent_is_on(2, 1), "tap/tap attack should not create reverse enemy lane")

func _test_tap_tap_friendly_feed_and_reverse() -> void:
	var harness: Dictionary = _make_harness(1)
	if _harness_missing(harness, "friendly lane"):
		return
	var input: Variant = harness.get("input")
	var api: Variant = harness.get("api")
	var state: Variant = harness.get("state")
	_tap_hive(input, api, 1, Vector2(0, 0))
	_tap_hive(input, api, 2, Vector2(4, 0))
	_expect_true(state.intent_is_on(1, 2), "tap/tap owned source to friendly destination should create feed lane")
	_expect_true(not state.intent_is_on(2, 1), "initial friendly feed should be one-way")
	_tap_hive(input, api, 2, Vector2(4, 0))
	_tap_hive(input, api, 1, Vector2(0, 0))
	_expect_true(not state.intent_is_on(1, 2), "tap/tap opposite friendly source should clear previous direction")
	_expect_true(state.intent_is_on(2, 1), "tap/tap opposite friendly source should reverse feed lane")

func _test_tap_tap_active_lane_reinstances_swarm() -> void:
	var harness: Dictionary = _make_harness(2)
	if _harness_missing(harness, "swarm lane"):
		return
	var input: Variant = harness.get("input")
	var api: Variant = harness.get("api")
	var state: Variant = harness.get("state")
	_tap_hive(input, api, 1, Vector2(0, 0))
	_tap_hive(input, api, 2, Vector2(4, 0))
	_expect_true(state.intent_is_on(1, 2), "lane should be active before reinstance")
	_tap_hive(input, api, 1, Vector2(0, 0))
	_tap_hive(input, api, 2, Vector2(4, 0))
	_expect_eq(state.swarm_requests.size(), 1, "tap/tap same active lane direction should enqueue one swarm")
	var req: Dictionary = state.swarm_requests[0] as Dictionary
	_expect_eq(int(req.get("src", -1)), 1, "tap/tap swarm src")
	_expect_eq(int(req.get("dst", -1)), 2, "tap/tap swarm dst")

func _make_harness(dst_owner_id: int) -> Dictionary:
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_expect_true(ops_state != null, "OpsState autoload should exist")
	if ops_state != null and ops_state.has_method("reset_match_state"):
		ops_state.call("reset_match_state")
	var map_dict := {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": dst_owner_id, "power": 20, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2}
		]
	}
	var state: Variant = ops_state.call("reset_state_from_map", map_dict)
	ops_state.set("match_phase", 1)
	ops_state.set("input_locked", false)
	ops_state.set("input_locked_reason", "")
	ops_state.set("winner_id", 0)
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var arena_api_script: Script = load("res://scripts/systems/arena_api.gd")
	var input_system_script: Script = load("res://scripts/systems/input_system.gd")
	_expect_true(arena_api_script != null, "ArenaAPI script should load")
	_expect_true(input_system_script != null, "InputSystem script should load")
	if arena_api_script == null or input_system_script == null:
		return {}
	var api: Variant = arena_api_script.new(arena)
	api.bind_state(state)
	var input: Variant = input_system_script.new()
	input.setup(SelectionState.new())
	return {
		"arena": arena,
		"api": api,
		"input": input,
		"state": state
	}

func _tap_hive(input: Variant, api: Variant, hive_id: int, local_pos: Vector2) -> void:
	if input == null or api == null:
		_expect_true(false, "tap harness should have input and api")
		return
	input.handle_pointer_event({
		"type": "press",
		"button": MOUSE_BUTTON_LEFT,
		"local_pos": local_pos,
		"world_pos": local_pos,
		"screen_pos": local_pos,
		"is_touch": true,
		"hive_id": hive_id,
		"lane_id": -1
	}, api)
	input.handle_pointer_event({
		"type": "release",
		"button": MOUSE_BUTTON_LEFT,
		"local_pos": local_pos,
		"world_pos": local_pos,
		"screen_pos": local_pos,
		"is_touch": true,
		"hive_id": hive_id,
		"lane_id": -1
	}, api)

func _harness_missing(harness: Dictionary, label: String) -> bool:
	var missing := harness.is_empty() or harness.get("input") == null or harness.get("api") == null or harness.get("state") == null
	if missing:
		_expect_true(false, "%s harness should initialize" % label)
	return missing

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("INPUT_CONTROLS_SMOKE: %s" % message)

func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failed = true
	push_error("INPUT_CONTROLS_SMOKE: %s actual=%s expected=%s" % [message, str(actual), str(expected)])
