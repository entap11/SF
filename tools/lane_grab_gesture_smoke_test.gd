extends SceneTree
## Exercises the production pointer handler, picker, preview and OpsState retract.
## Only the surrounding scene is a fixture; commands use the real ArenaAPI.

const Readability = preload("res://scripts/renderers/combat_readability.gd")

class GestureArena:
	extends Node2D
	var active_player_id: int = 1
	var grid_spec: Object = null
	var lane_renderer: Node2D
	var camera: Camera2D = null
	var DRAG_DEADZONE_PX: float = 8.0
	var retract_calls: Array = []

	func _handle_tap(_id: int, _pid: int = -1) -> void:
		pass

	func mark_render_dirty(_reason: String = "") -> void:
		pass

	func _cell_center(cell: Vector2i) -> Vector2:
		return (Vector2(cell) + Vector2(0.5, 0.5)) * 64.0

	func _cell_from_point(point: Vector2) -> Vector2i:
		return Vector2i((point / 64.0).floor())

	func _pick_lane(_point: Vector2) -> LaneData:
		return null

	func _retract_lane(src: int, dst: int, owner: int) -> void:
		retract_calls.append([src, dst, owner])
		get_node("/root/OpsState").retract_lane(src, dst, owner)

var ops: Node
var failed: bool = false
var cases: int = 0
var capture_dir: String = ""

func _initialize() -> void:
	await process_frame
	ops = root.get_node("OpsState")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
			root.size = Vector2i(800, 700)
	for readable in [false, true]:
		ProjectSettings.set_setting(Readability.SETTING, readable)
		for touch in [false, true]:
			for actor in [1, 2]:
				for action in ["hold", "short", "along", "throw", "negative_throw", "threshold", "return", "early", "second_touch", "lock", "retracted", "captured"]:
					await _gesture_case(readable, touch, actor, action)
			await _enemy_case(touch)
			for friendly in [false, true]:
				for reverse in [false, true]:
					await _one_way_case(touch, friendly, reverse)
	print("LANE_GRAB_GESTURE_SMOKE: %s (%d cases)" % ["FAIL" if failed else "PASS", cases])
	quit(1 if failed else 0)

func _make_harness(actor: int = 1, opposing: bool = true, friendly: bool = false, transformed: bool = true) -> Dictionary:
	ops.reset_match_state()
	var state: GameState = ops.reset_state_from_map({
		"hives": [
			{"id": 1, "x": 0, "y": 4, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 10, "y": 4, "owner_id": 1 if friendly else 2, "power": 50, "kind": "Hive"},
			{"id": 3, "x": 5, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 4, "x": 5, "y": 8, "owner_id": 2, "power": 50, "kind": "Hive"}],
		"lane_candidates": [{"a_id": 1, "b_id": 2}, {"a_id": 3, "b_id": 4}]
	})
	ops.match_phase = 1
	ops.input_locked = false
	ops.winner_id = 0
	ops.apply_lane_intent(1, 2, "feed" if friendly else "attack")
	if opposing:
		ops.apply_lane_intent(2, 1, "attack")
	ops.apply_lane_intent(3, 4, "attack")
	var arena := GestureArena.new()
	arena.active_player_id = actor
	root.add_child(arena)
	var map_root := Node2D.new()
	map_root.name = "MapRoot"
	# Exercise local/world conversion with the same kinds of anisotropic scale,
	# translation and small angle used by the battlefield presentation.
	if transformed:
		map_root.position = Vector2(37, 29)
		map_root.scale = Vector2(1.08, 0.94)
		map_root.rotation_degrees = 3.0
	arena.add_child(map_root)
	var renderer: Node2D = load("res://scripts/renderers/lane_renderer.gd").new()
	renderer.name = "LaneRenderer"
	map_root.add_child(renderer)
	arena.lane_renderer = renderer
	renderer.state = state
	renderer.set_process(false)
	var input: Variant = load("res://scripts/systems/input_system.gd").new()
	input.setup(SelectionState.new())
	renderer.sel = input.selection
	var api: Variant = load("res://scripts/systems/arena_api.gd").new(arena)
	api.bind_state(state)
	var lane: LaneData = state.lanes[state.lane_index_between(1, 2)]
	var h := {"arena": arena, "renderer": renderer, "input": input, "api": api, "state": state, "lane": lane}
	_sync_renderer(h)
	return h

func _sync_renderer(h: Dictionary) -> void:
	var sample := {"sim_running": true, "viewer_owner_id": h.arena.active_player_id, "hives": [], "lanes": []}
	for hive: HiveData in h.state.hives:
		sample.hives.append({"id": hive.id, "owner_id": hive.owner_id, "grid_pos": hive.grid_pos,
			"pos": h.arena._cell_center(hive.grid_pos), "radius_px": 24.0, "power": hive.power})
	for lane: LaneData in h.state.lanes:
		sample.lanes.append({"lane_id": lane.id, "a_id": lane.a_id, "b_id": lane.b_id,
			"send_a": lane.send_a, "send_b": lane.send_b, "front_t": lane.last_impact_f})
	h.renderer.set_model(sample)
	h.renderer.call("_rebuild_lane_sprites_now")
	h.renderer.call("_update_lane_visuals", 0.0)

func _event(h: Dictionary, kind: String, point: Vector2, touch: bool, finger: int = 0) -> void:
	# No supplied lane ID: acquisition must use the production renderer picker.
	var world: Vector2 = h.arena.get_node("MapRoot").to_global(point)
	h.input.handle_pointer_event({"type": kind, "button": MOUSE_BUTTON_LEFT,
		"local_pos": point, "world_pos": world, "screen_pos": world,
		"is_touch": touch, "touch_index": finger, "hive_id": -1, "lane_id": -1}, h.api)

func _gesture_case(readable: bool, touch: bool, actor: int, action: String) -> void:
	cases += 1
	var label := "%s readable=%s touch=%s actor=%d" % [action, readable, touch, actor]
	# The exact boundary uses an unrotated axis to avoid float round-trip error;
	# the remaining cases exercise the transformed battlefield.
	var h := _make_harness(actor, true, false, action != "threshold")
	var endpoints: Dictionary = h.renderer.get_lane_endpoints_world(h.lane.id, 1, 2)
	_expect(bool(endpoints.get("ok", false)), label + ": endpoints available")
	if not bool(endpoints.get("ok", false)):
		h.arena.free()
		return
	var a: Vector2 = h.api.world_to_map_local(endpoints.start_world)
	var b: Vector2 = h.api.world_to_map_local(endpoints.end_world)
	var axis: Vector2 = (b - a).normalized()
	var normal := Vector2(-axis.y, axis.x)
	# Start beyond the old contested front, on the offset visible track.
	var start: Vector2 = a.lerp(b, 0.75 if actor == 1 else 0.25) + normal * (4.5 if actor == 1 else -4.5)
	var capture: bool = readable and not touch and action == "throw" and not capture_dir.is_empty()
	if capture:
		await _capture(h, "p%d_1_before" % actor)
	_event(h, "press", start, touch)
	_expect(h.input._lane_grab_state == "candidate", label + ": real picker acquires lane")
	_expect(h.input._lane_grab_lane_id == h.lane.id, label + ": correct lane acquired")
	if action != "early":
		# Advance only the ephemeral press clock; production tick must arm it.
		h.input._lane_grab_press_ms = Time.get_ticks_msec() - h.input.LANE_GRAB_ARM_MS
		h.input.tick(0.0, h.api)
		_expect(h.input._lane_grab_state == "armed", label + ": hold arms without committing")
		var preview: Dictionary = h.renderer._lane_grab_preview
		_expect(not preview.is_empty(), label + ": preview displayed")
		if not preview.is_empty():
			_expect((preview.source_world as Vector2).is_equal_approx(endpoints.start_world if actor == 1 else endpoints.end_world), label + ": bend anchored at owned hive")
		_check_preview_routes(h, readable, actor, true, label)
		if capture:
			await _capture(h, "p%d_2_armed" % actor)
		h.input.tick(0.0, h.api)
		_expect(h.input._lane_grab_state == "armed", label + ": stationary hold never becomes throw-ready")
	var finish := start
	match action:
		"short":
			finish = a.lerp(b, 0.75 if actor == 1 else 0.25) + normal * 43.0
		"along":
			finish += axis * (-90.0 if actor == 1 else 90.0)
		"threshold":
			finish = a.lerp(b, 0.75 if actor == 1 else 0.25) + normal * 44.0
		"negative_throw":
			finish -= normal * 70.0
		"throw", "early", "return", "second_touch", "lock", "retracted", "captured":
			finish += normal * 70.0
	_event(h, "motion", finish, touch)
	if capture:
		await _capture(h, "p%d_3_throw_ready" % actor)
	if action == "return":
		finish = start
		_event(h, "motion", finish, touch)
	if action == "second_touch" and touch:
		_event(h, "release", finish, touch, 1)
		_expect(h.arena.retract_calls.is_empty(), label + ": other finger cannot commit")
	if action == "lock":
		h.input.set_inputs_locked(true, "gesture_test")
	if action == "retracted":
		ops.retract_lane(actor, 3 - actor, actor)
		_sync_renderer(h)
		# The external command isn't a gesture command.
		h.state.lane_retract_requests.clear()
	if action == "captured":
		# Simulate a completed capture in the canonical test fixture. A different
		# owned side on this pair must not authorize retracting the original side.
		h.state.find_hive_by_id(actor).owner_id = 3 - actor
		h.state.find_hive_by_id(3 - actor).owner_id = actor
	_expect(h.arena.retract_calls.is_empty(), label + ": no mutation before release")
	_event(h, "release", finish, touch)
	var should_delete: bool = action in ["throw", "negative_throw", "threshold", "second_touch"]
	_expect(h.arena.retract_calls.size() == (1 if should_delete else 0), label + ": exactly the expected retract command")
	_expect(h.state.lane_retract_requests.size() == (1 if should_delete else 0), label + ": authority received expected request")
	if should_delete and not h.arena.retract_calls.is_empty():
		_expect(h.arena.retract_calls[0] == [actor, 3 - actor, actor], label + ": command preserves direction and owner")
	_expect(h.state.intent_is_on(actor, 3 - actor) == (not should_delete and action != "retracted"), label + ": owned direction state")
	_expect(h.state.intent_is_on(3 - actor, actor), label + ": opposing direction preserved")
	_expect(h.state.intent_is_on(3, 4), label + ": crossing lane preserved")
	_expect(h.input._lane_grab_state == "idle", label + ": gesture cleaned up")
	_expect(h.renderer._lane_grab_preview.is_empty(), label + ": preview cleaned up")
	_sync_renderer(h)
	_check_preview_routes(h, readable, actor, false, label)
	if capture:
		await _capture(h, "p%d_4_released" % actor)
	_event(h, "release", finish, touch)
	_expect(h.arena.retract_calls.size() == (1 if should_delete else 0), label + ": duplicate release cannot retract twice")
	h.arena.free()
	await process_frame

func _check_preview_routes(h: Dictionary, readable: bool, actor: int, grabbing: bool, label: String) -> void:
	h.renderer.call("_update_lane_visuals", 0.0)
	var curve: Line2D = h.renderer.get_node_or_null("LaneGrabTensionLine")
	_expect((curve != null and curve.visible) if grabbing else (curve == null or not curve.visible), label + ": curve visibility matches gesture")
	if not readable:
		return
	var entry: Dictionary = h.renderer._lane_nodes_by_key[h.renderer._lane_key_by_id[h.lane.id]]
	var selected: Node2D = entry.get("readable_a" if actor == 1 else "readable_b")
	var opposite: Node2D = entry.get("readable_b" if actor == 1 else "readable_a")
	_expect(selected != null and selected.visible == (not grabbing and h.state.intent_is_on(actor, 3 - actor)), label + ": straight route hidden only for grab/retraction")
	_expect(opposite != null and opposite.visible, label + ": opposing route stays visible")
	if grabbing:
		_expect(h.renderer.readability_context.focus_lane == h.lane.id, label + ": grabbed lane owns readability focus")
		_expect(h.renderer.readability_context.connections.has(1) and h.renderer.readability_context.connections.has(2), label + ": both endpoints emphasized")

func _one_way_case(touch: bool, friendly: bool, reverse: bool) -> void:
	cases += 1
	var owner: int = 2 if reverse and not friendly else 1
	var h := _make_harness(owner, false, friendly)
	var src: int = 2 if reverse else 1
	var dst: int = 3 - src
	if reverse:
		ops.retract_lane(1, 2, 1)
		ops.apply_lane_intent(src, dst, "feed" if friendly else "attack")
		h.state.lane_retract_requests.clear()
		_sync_renderer(h)
	var endpoints: Dictionary = h.renderer.get_lane_endpoints_world(h.lane.id, 1, 2)
	var start: Vector2 = h.api.world_to_map_local((endpoints.start_world as Vector2).lerp(endpoints.end_world, 0.7))
	_event(h, "press", start, touch)
	h.input._lane_grab_press_ms = Time.get_ticks_msec() - h.input.LANE_GRAB_ARM_MS
	h.input.tick(0.0, h.api)
	_event(h, "motion", start + Vector2(0, 70), touch)
	_expect(h.arena.retract_calls.is_empty(), "one-way pull must wait for release")
	_event(h, "release", start + Vector2(0, 70), touch)
	_expect(h.arena.retract_calls == [[src, dst, owner]], "one-way attack/feed retracts only the acquired direction")
	_expect(not h.state.intent_is_on(src, dst) and not h.state.intent_is_on(dst, src), "one-way lane inactive after throw")
	h.arena.free()
	await process_frame

func _enemy_case(touch: bool) -> void:
	cases += 1
	var h := _make_harness(2, false)
	var endpoints: Dictionary = h.renderer.get_lane_endpoints_world(h.lane.id, 1, 2)
	var world: Vector2 = (endpoints.start_world as Vector2).lerp(endpoints.end_world, 0.7)
	var start: Vector2 = h.api.world_to_map_local(world)
	_expect(h.renderer.pick_lane_at_world_pos(world, 30).get("hit", false), "enemy-only route must be pickable before ownership check")
	_event(h, "press", start, touch)
	_expect(h.input._lane_grab_state == "idle", "enemy-only lane cannot be grabbed")
	_event(h, "motion", start + Vector2(0, 70), touch)
	_event(h, "release", start + Vector2(0, 70), touch)
	_expect(h.arena.retract_calls.is_empty() and h.state.intent_is_on(1, 2), "enemy-only lane cannot be deleted")
	h.arena.free()
	await process_frame

func _capture(h: Dictionary, tag: String) -> void:
	var title := Label.new()
	title.position = Vector2(20, 20)
	title.text = "Lane gesture fixture | " + tag
	root.add_child(title)
	h.renderer.call("_update_lane_visuals", 0.0)
	for frame in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	var snapshot: Image = root.get_texture().get_image()
	_expect(snapshot != null and not snapshot.is_empty(), "capture must contain GPU pixels")
	if snapshot != null and not snapshot.is_empty():
		_expect(snapshot.save_png(capture_dir.path_join(tag + ".png")) == OK, "capture saved")
	title.free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("LANE_GRAB_GESTURE_SMOKE: " + message)
