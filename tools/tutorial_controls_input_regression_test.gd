extends SceneTree
## Small fixtures exercise the real controller, InputSystem and OpsState command
## path. Only lesson setup uses fixtures; all tested actions are pointer events.

const Tutorial = preload("res://scripts/arena_helpers/tutorial_controls_controller.gd")

class TestArena:
	extends Node2D
	var active_player_id: int = 1
	var DRAG_DEADZONE_PX: float = 8.0
	var grid_spec: Object = null
	var controller: RefCounted
	var state: GameState
	var sim_running: bool = true
	func _handle_tap(hive_id: int, _pid: int = -1) -> void:
		controller.on_hive_clicked(hive_id, state, 1)
	func mark_render_dirty(_reason: String = "") -> void: pass
	func _cell_center(cell: Vector2i) -> Vector2: return Vector2(cell) * 64.0
	func _cell_from_point(point: Vector2) -> Vector2i: return Vector2i((point / 64.0).round())
	func _pick_lane(_point: Vector2) -> Variant: return null
	func _pick_lane_hit(_point: Vector2) -> Dictionary: return {"ok": false}
	func pause_sim() -> void: sim_running = false
	func resume_sim() -> void: sim_running = true

var ops: Node
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	await process_frame
	ops = root.get_node("OpsState")
	for touch in [false, true]:
		_test_feed_repeats(touch)
		for step in [Tutorial.STEP_REMAKE_FRIEND_LANE, Tutorial.STEP_ATTACK_ENEMY_HIVE, Tutorial.STEP_ATTACK_ENEMY_FROM_START, Tutorial.STEP_TAKE_NEUTRAL_HIVE, Tutorial.STEP_ATTACK_ENEMY_FROM_NEUTRAL, Tutorial.STEP_SWARM_BY_OVERLAP]:
			_test_source_retry(step, touch)
			_test_aborted_drag(step, touch)
		_test_watch_step(Tutorial.STEP_CONTEST_ENEMY_LANE, touch)
		_test_watch_step(Tutorial.STEP_WAIT_OVERLAP_SWARM_HIT, touch)
		_test_chained_swarms(touch)
		_test_next_swarm_recharge(touch)
	_test_second_finger()
	_test_skip_releases_pause()
	print("TUTORIAL_INPUT_REGRESSION: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _fixture(step: String) -> Dictionary:
	ops.reset_match_state()
	var state: GameState = ops.reset_state_from_map({
		"hives": [
			{"id": 1, "x": 2, "y": 6, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 8, "y": 6, "owner_id": 0 if step == Tutorial.STEP_TAKE_NEUTRAL_HIVE else 1, "power": 30, "kind": "Hive"},
			{"id": 3, "x": 2, "y": 17, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 4, "x": 15, "y": 17, "owner_id": 2, "power": 50, "kind": "Hive"}],
		"lane_candidates": [{"a_id": 1, "b_id": 3}, {"a_id": 1, "b_id": 2}, {"a_id": 1, "b_id": 4}, {"a_id": 2, "b_id": 4}, {"a_id": 3, "b_id": 4}]
	})
	ops.match_phase = 1
	ops.input_locked = false
	ops.winner_id = 0
	if step in [Tutorial.STEP_SWARM_BY_OVERLAP, Tutorial.STEP_WAIT_OVERLAP_SWARM_HIT, Tutorial.STEP_CONTEST_ENEMY_LANE]:
		for source in [1, 2, 3]: ops.apply_lane_intent(source, 4, "attack")
	var arena := TestArena.new()
	root.add_child(arena)
	var input: Variant = load("res://scripts/systems/input_system.gd").new()
	input.setup(SelectionState.new())
	var api: Variant = load("res://scripts/systems/arena_api.gd").new(arena)
	api.bind_state(state)
	var controller := Tutorial.new()
	arena.controller = controller
	arena.state = state
	controller._active = true
	controller._last_state = state
	controller._anchor_ids = {"start_hive": 1, "neutral_hive": 2, "friend_hive": 3, "enemy_hive": 4}
	controller._pause_sim_cb = arena.pause_sim
	controller._resume_sim_cb = arena.resume_sim
	controller._current_step = step
	controller._bind_signal_once()
	controller._enter_step(step)
	return {"arena": arena, "input": input, "api": api, "controller": controller, "state": state}

func _dispose(h: Dictionary) -> void:
	h.controller.hide(true)
	h.arena.controller = null
	h.arena.free()

func _event(h: Dictionary, kind: String, hive_id: int, touch: bool, finger: int = 0) -> bool:
	var point := Vector2(640, 640)
	if hive_id > 0:
		point = h.arena._cell_center(h.state.find_hive_by_id(hive_id).grid_pos)
	var ev := {"type": kind, "button": MOUSE_BUTTON_LEFT, "is_touch": touch, "touch_index": finger,
		"hive_id": hive_id, "lane_id": -1, "local_pos": point, "world_pos": point, "screen_pos": point}
	var allowed: bool = h.controller.should_allow_pointer_event(ev, h.state)
	if allowed:
		h.input.handle_pointer_event(ev, h.api)
		h.controller.on_pointer_event_handled(ev, h.state, h.input.selected_src_id)
	h.controller.tick(h.state, 1)
	return allowed

func _tap(h: Dictionary, hive_id: int, touch: bool) -> void:
	_event(h, "press", hive_id, touch)
	_event(h, "release", hive_id, touch)

func _source(step: String) -> int:
	if step in [Tutorial.STEP_ATTACK_ENEMY_FROM_START, Tutorial.STEP_TAKE_NEUTRAL_HIVE]: return 1
	if step == Tutorial.STEP_ATTACK_ENEMY_FROM_NEUTRAL: return 2
	return 3

func _target(step: String) -> int:
	if step == Tutorial.STEP_REMAKE_FRIEND_LANE: return 1
	if step == Tutorial.STEP_TAKE_NEUTRAL_HIVE: return 2
	return 4

func _test_source_retry(step: String, touch: bool) -> void:
	var h := _fixture(step)
	var source := _source(step)
	var target := _target(step)
	_tap(h, source, touch)
	_tap(h, source, touch)
	_expect(h.input.selected_src_id == source, step + ": repeated source remains selected")
	_expect(h.state.swarm_requests.is_empty(), step + ": source taps do not issue a swarm")
	_tap(h, target, touch)
	_expect(h.state.intent_is_on(source, target), step + ": next destination completes action")
	if step == Tutorial.STEP_SWARM_BY_OVERLAP:
		_expect(h.state.swarm_requests.size() == 1, "overlap creates exactly one swarm")
	var count: int = h.state.swarm_requests.size()
	var deadline: int = h.controller._pending_next_step_at_ms
	_tap(h, target, touch)
	_expect(h.state.swarm_requests.size() == count, step + ": repeated destination cannot add a swarm")
	_expect(h.controller._pending_next_step_at_ms == deadline, step + ": repeat cannot reset dwell")
	_dispose(h)

func _test_aborted_drag(step: String, touch: bool) -> void:
	var h := _fixture(step)
	var source := _source(step)
	_event(h, "press", source, touch)
	_event(h, "motion", -1, touch)
	_event(h, "release", -1, touch)
	_expect(h.controller._active_pointer_key.is_empty(), step + ": aborted drag releases pointer")
	_tap(h, source, touch)
	_tap(h, _target(step), touch)
	_expect(h.state.intent_is_on(source, _target(step)), step + ": aborted drag can be retried")
	if step == Tutorial.STEP_SWARM_BY_OVERLAP:
		_expect(h.state.swarm_requests.size() == 1, "aborted swarm drag can be retried")
	_dispose(h)

func _test_feed_repeats(touch: bool) -> void:
	var h := _fixture(Tutorial.STEP_FEED_FRIEND)
	_tap(h, 3, touch)
	_expect(h.state.intent_is_on(1, 3), "feed accepted on first destination tap")
	_expect(not _event(h, "press", 3, touch), "extra feed tap blocked while watching arrivals")
	_expect(not _event(h, "release", 3, touch), "blocked feed release also consumed")
	_expect(h.state.swarm_requests.is_empty(), "extra feed tap cannot enqueue swarm")
	_dispose(h)

func _test_watch_step(step: String, touch: bool) -> void:
	var h := _fixture(step)
	_expect(not _event(h, "press", 3, touch), step + ": watching does not accept new gestures")
	_expect(not _event(h, "release", 3, touch), step + ": blocked release consumed")
	_tap(h, 4, touch)
	_expect(h.state.swarm_requests.is_empty(), step + ": repeats cannot change the demonstration")
	_dispose(h)

func _test_second_finger() -> void:
	var h := _fixture(Tutorial.STEP_ATTACK_ENEMY_HIVE)
	_expect(_event(h, "press", 3, true, 0), "first finger owns source gesture")
	_expect(not _event(h, "press", 4, true, 1), "second finger cannot replace source gesture")
	_expect(not _event(h, "release", 4, true, 1), "second release is consumed")
	_event(h, "release", 3, true, 0)
	_tap(h, 4, true)
	_expect(h.state.intent_is_on(3, 4), "first gesture remains usable after second finger")
	_dispose(h)

func _resolve_swarm_fixture(h: Dictionary) -> void:
	# Represent an arrival for this controller fixture. The full viewport
	# walkthrough separately waits for real SwarmSystem arrivals and capture.
	ops.sim_mutate("tutorial_test_swarm_resolved", func() -> void:
		h.state.swarm_requests.clear()
		h.state.swarm_packets.clear()
	)
	h.controller.tick(h.state, 1)

func _test_chained_swarms(touch: bool) -> void:
	var h := _fixture(Tutorial.STEP_SWARM_BY_OVERLAP)
	var expected_sources: Array[int] = [3, 2, 1]
	for index in range(expected_sources.size()):
		var source: int = expected_sources[index]
		if index > 0:
			_expect(h.controller._anchor_id(h.controller._swarm_prompt_source_anchor) == source, "next swarm highlights another hive")
		_tap(h, source, touch)
		_tap(h, 4, touch)
		_expect(h.controller.current_step_id() == Tutorial.STEP_WAIT_OVERLAP_SWARM_HIT, "each accepted swarm waits for its result")
		_expect(h.controller._swarm_launch_count == index + 1, "each accepted swarm counts once")
		_tap(h, 4, touch)
		_expect(h.controller._swarm_launch_count == index + 1, "extra destination tap is not another swarm")
		_resolve_swarm_fixture(h)
		_expect(h.controller.current_step_id() == Tutorial.STEP_SWARM_BY_OVERLAP, "uncaptured enemy always gets another guided swarm")
		_expect(h.controller._pending_next_step_id.is_empty(), "next swarm does not add a post-hit dwell")
		_expect(h.arena.sim_running, "successive swarm prompts keep production and cooldowns running")
	ops.sim_mutate("tutorial_test_capture", func() -> void:
		h.state.find_hive_by_id(4).owner_id = 1
	)
	h.controller.tick(h.state, 1)
	_expect(h.controller.completed_this_match(), "actual capture ends the swarm sequence")
	_dispose(h)

func _test_next_swarm_recharge(touch: bool) -> void:
	var h := _fixture(Tutorial.STEP_SWARM_BY_OVERLAP)
	_tap(h, 3, touch)
	_tap(h, 4, touch)
	ops.sim_mutate("tutorial_test_sources_recharging", func() -> void:
		h.state.find_hive_by_id(2).power = 1
		h.state.swarm_cooldown_until_us[1] = h.state._sim_time_us + 1000000
	)
	_resolve_swarm_fixture(h)
	_expect(h.controller._swarm_prompt_source_anchor == Tutorial.ANCHOR_NEUTRAL_HIVE, "recharge keeps the next hive in rotation")
	_expect(h.arena.sim_running, "recharge prompt cannot freeze the source's recovery")
	_expect(not _event(h, "press", 2, touch), "recharging source cannot consume a swarm attempt")
	_event(h, "release", 2, touch)
	_expect(h.controller._swarm_launch_count == 1, "rejected attempt does not advance the sequence")
	ops.sim_mutate("tutorial_test_source_recovered", func() -> void:
		h.state.find_hive_by_id(2).power = 2
	)
	_tap(h, 2, touch)
	_tap(h, 4, touch)
	_expect(h.controller._swarm_launch_count == 2, "recovered source accepts the next swarm")
	_dispose(h)

func _test_skip_releases_pause() -> void:
	var h := _fixture(Tutorial.STEP_CANCEL_LANE_GRAB_THROW)
	_expect(not h.arena.sim_running, "cancel lesson pauses before gesture")
	h.controller.hide(true)
	_expect(h.arena.sim_running, "hiding cancel lesson releases its pause")
	_dispose(h)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	push_error("TUTORIAL_INPUT_REGRESSION: " + message)
