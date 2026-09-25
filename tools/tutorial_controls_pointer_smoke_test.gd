extends SceneTree
## Runs the tutorial through viewport mouse/touch events. No lane, capture,
## arrival, power or tutorial-clock mutations are used to advance the lessons.
## Run in an isolated user directory: tutorial launch updates profile progress.

var shell: Node
var arena: Node
var controller: RefCounted
var ops: Node
var anchors: Dictionary
var touch: bool = false
var use_drag: bool = false
var repeat_inputs: bool = false
var capture_dir: String = ""
var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		touch = touch or arg == "--touch"
		use_drag = use_drag or arg == "--drag"
		repeat_inputs = repeat_inputs or arg == "--repeat-inputs"
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
	if not bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)):
		_fail("Use an isolated custom user directory to protect the player's profile")
		return
	root.size = Vector2i(1080, 1920)
	await process_frame
	ops = root.get_node("OpsState")
	shell = load("res://scenes/Shell.tscn").instantiate()
	root.add_child(shell)
	current_scene = shell
	shell.call("_on_tutorial_pressed")
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		arena = shell.call("_resolve_runtime_arena_node")
		if arena != null:
			controller = arena.get("_tutorial_controls_controller")
			if controller != null and controller.is_active() and shell.get("arena_root").modulate.a == 1.0:
				break
		await process_frame
	if controller == null or not controller.is_active():
		_fail("Tutorial did not start")
		return
	# Let the real loading cover finish releasing before sending viewport input.
	var cover: Node = root.get_node("MainMenuLoadingCoordinator")
	while bool(cover.call("is_match_transition_active")) and Time.get_ticks_msec() < deadline:
		await process_frame
	anchors = controller.get_anchor_ids()
	await process_frame
	await _capture("01_select_start")
	var ring: Control = controller.get("_source_ring")
	var ring_point: Vector2 = ring.get_global_transform_with_canvas() * (ring.size * 0.5)
	if ring_point.distance_to(_hive_point("start_hive")) > 2.0:
		_fail("First highlight must align with the clickable hive: ring=%s hive=%s" % [ring_point, _hive_point("start_hive")])
		return
	await _tap("start_hive")
	if not await _wait_step("feed_friend"): return
	await _tap("friend_hive")
	if repeat_inputs:
		await _tap("friend_hive")
		await _tap("friend_hive")
	if not await _wait_step("reverse_feed"): return
	await _tap("friend_hive")
	await _tap("start_hive")
	if repeat_inputs:
		await _tap("start_hive")
	if not await _wait_step("cancel_lane_grab_throw"): return
	await _capture("02_cancel_lane")
	await _throw_lane()
	if not await _wait_step("remake_friend_lane"): return
	await _pair("friend_hive", "start_hive")
	if repeat_inputs:
		await _tap("start_hive")
	if not await _wait_step("attack_enemy_hive"): return
	await _capture("03_attack")
	await _pair("friend_hive", "enemy_hive")
	if not await _wait_step("contest_enemy_lane"): return
	if repeat_inputs:
		await _pair("friend_hive", "enemy_hive")
	if not await _wait_step("attack_enemy_from_start"): return
	await _pair("start_hive", "enemy_hive")
	if repeat_inputs:
		await _pair("start_hive", "enemy_hive")
	if not await _wait_step("take_neutral_hive"): return
	await _pair("start_hive", "neutral_hive")
	if repeat_inputs:
		await _tap("neutral_hive")
	if not await _wait_step("attack_enemy_from_neutral"): return
	await _capture("04_attack_from_gray")
	await _pair("neutral_hive", "enemy_hive")
	if not await _wait_step("swarm_intro"): return
	if not await _wait_step("swarm_by_overlap"): return
	await _capture("05_swarm")
	await _pair("friend_hive", "enemy_hive")
	if not await _wait_step("wait_overlap_swarm_hit"): return
	if repeat_inputs:
		await _pair("start_hive", "enemy_hive")
	# Follow the next highlighted hive all the way to capture. No free-play
	# fallback: dropping the prompts after the first swarm is a regression.
	deadline = Time.get_ticks_msec() + 90000
	var last_swarm_source: String = "friend_hive"
	while is_instance_valid(arena) and controller.is_active() and Time.get_ticks_msec() < deadline:
		if controller.current_step_id() == "finish_fight":
			_fail("Swarm guidance ended before capture")
			return
		if controller.current_step_id() == "swarm_by_overlap":
			var snapshot: Dictionary = controller.smoke_snapshot()
			var source: String = str(snapshot.get("swarm_prompt_source_anchor", ""))
			if source.is_empty() or source == last_swarm_source:
				_fail("Next swarm must highlight another hive")
				return
			if bool(snapshot.get("swarm_prompt_ready", false)):
				await _pair(source, "enemy_hive")
				last_swarm_source = source
				print("TUTORIAL_POINTER_SWARM: count=%d source=%s" % [int(controller.smoke_snapshot().get("swarm_launch_count", 0)), source])
		await process_frame
	if not controller.completed_this_match():
		_fail("Guided successive swarms did not capture the enemy hive")
		return
	await _capture("06_complete")
	print("TUTORIAL_POINTER_SMOKE: PASS touch=%s drag=%s repeats=%s" % [touch, use_drag, repeat_inputs])
	quit(0)

func _wait_step(expected: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if controller.current_step_id() == expected:
			print("TUTORIAL_POINTER_STEP: " + expected)
			return true
		await process_frame
	await _capture("FAIL_" + expected)
	_fail("Expected %s, got %s; snapshot=%s" % [expected, controller.current_step_id(), str(controller.smoke_snapshot())])
	return false

func _hive_point(anchor: String) -> Vector2:
	var state: GameState = ops.call("get_state")
	var hive: HiveData = state.find_hive_by_id(int(anchors[anchor]))
	var local_pos: Vector2 = arena.call("_cell_center", hive.grid_pos)
	var projection: Dictionary = arena.call("buff_arena_local_to_root_screen", local_pos)
	return projection.get("root_screen_pos", Vector2.INF)

func _pointer(kind: String, point: Vector2) -> void:
	var event: InputEvent
	if touch:
		if kind == "motion":
			var drag := InputEventScreenDrag.new()
			drag.position = point
			drag.index = 0
			event = drag
		else:
			var tap := InputEventScreenTouch.new()
			tap.position = point
			tap.index = 0
			tap.pressed = kind == "press"
			event = tap
	elif kind == "motion":
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		event = motion
	else:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = kind == "press"
		event = click
	root.push_input(event, true)
	await create_timer(0.08).timeout

func _tap(anchor: String) -> void:
	var point := _hive_point(anchor)
	await _pointer("press", point)
	await _pointer("release", point)
	await create_timer(0.2).timeout

func _pair(source: String, target: String) -> void:
	if not use_drag:
		await _tap(source)
		if repeat_inputs and controller.current_step_id() != "finish_fight":
			await _tap(source)
		await _tap(target)
		return
	await _pointer("press", _hive_point(source))
	await _pointer("motion", _hive_point(source).lerp(_hive_point(target), 0.5))
	await _pointer("motion", _hive_point(target))
	await _pointer("release", _hive_point(target))

func _throw_lane() -> void:
	var source := _hive_point("friend_hive")
	var target := _hive_point("start_hive")
	var point := source.lerp(target, 0.32)
	await _pointer("press", point)
	await _pointer("motion", point + Vector2(140, 0))
	await _pointer("release", point + Vector2(140, 0))

func _capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	# Read back after drawing. A hidden/minimized test window may stop drawing;
	# screenshots must not prevent the input walkthrough from making progress.
	RenderingServer.frame_post_draw.connect(func() -> void:
		root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")), CONNECT_ONE_SHOT)
	await create_timer(0.15).timeout

func _fail(message: String) -> void:
	failed = true
	push_error("TUTORIAL_POINTER_SMOKE: " + message)
	quit(1)
