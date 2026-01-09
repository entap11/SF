class_name InputSystem
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")

const DOUBLE_TAP_MS := 300
const DOUBLE_TAP_DIST_PX := 20.0

var selection: SelectionState = null
var _last_tap_time_ms: int = 0
var _last_tap_pos: Vector2 = Vector2.ZERO
var _handling_click: bool = false
var _click_log_once: bool = false
var _press_active: bool = false
var _press_prev_selected_id: int = -1
var _press_prev_selected_lane_id: int = -1
var _press_hive_id: int = -1
var _press_lane_id: int = -1
var _hover_hive_id: int = -1
var _selected_hive_id: int = -1
var _dragging: bool = false
var _drag_src_id: int = -1

func setup(selection_state: SelectionState) -> void:
	if selection_state != null:
		selection = selection_state
	else:
		selection = SelectionState.new()

func tick(_dt: float, _arena_api: ArenaAPI) -> void:
	pass

func handle_input(event: InputEvent, arena_api: ArenaAPI) -> Array:
	var commands: Array = []
	if selection == null or arena_api == null:
		return commands
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if arena_api.get_sim_running():
				arena_api.set_sim_running(false)
				arena_api.dbg("SF: sim_running = false (paused)")
			else:
				arena_api.dbg("SF: sim start blocked (use DevMapLoader)")
		if event.keycode == KEY_B:
			var next_debris: bool = not arena_api.get_debris_enabled()
			arena_api.set_debris_enabled(next_debris)
			arena_api.dbg("SF: debris_enabled = %s" % str(next_debris))
		if event.keycode == KEY_1:
			arena_api.set_active_player_id(1)
			arena_api.dbg("SF: active_player_id = 1")
		if event.keycode == KEY_2:
			arena_api.set_active_player_id(2)
			arena_api.dbg("SF: active_player_id = 2")
		if event.keycode == KEY_3:
			arena_api.set_active_player_id(3)
			arena_api.dbg("SF: active_player_id = 3")
		if event.keycode == KEY_4:
			arena_api.set_active_player_id(4)
			arena_api.dbg("SF: active_player_id = 4")
		if event.keycode == KEY_Z:
			arena_api.try_activate_buff_slot(arena_api.get_active_player_id(), 0)
		if event.keycode == KEY_X:
			arena_api.try_activate_buff_slot(arena_api.get_active_player_id(), 1)
		if event.keycode == KEY_C:
			arena_api.try_activate_buff_slot(arena_api.get_active_player_id(), 2)
	return commands

func handle_pointer_event(ev: Dictionary, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	var event_type: String = str(ev.get("type", ""))
	var button_index: int = int(ev.get("button", MOUSE_BUTTON_LEFT))
	if button_index != MOUSE_BUTTON_LEFT:
		return
	var local_pos: Vector2 = ev.get("local_pos", Vector2.ZERO)
	if event_type == "press":
		var hid := arena_api.pick_hive_id_local(local_pos)
		var active_pid := _get_active_pid(arena_api)
		if hid > 0:
			var owner_id := int(arena_api.get_hive_owner_id(hid))
			if owner_id == active_pid:
				if _selected_hive_id <= 0 or hid == _selected_hive_id:
					_apply_selection(arena_api, hid)
		else:
			var had_selection := _selected_hive_id > 0
			_apply_selection(arena_api, -1)
			if had_selection:
				SFLog.info("DESELECT", {})
		if _selected_hive_id > 0:
			_dragging = true
			_drag_src_id = _selected_hive_id
		else:
			_dragging = false
			_drag_src_id = -1
		return
	if event_type == "release":
		if _dragging and _drag_src_id > 0:
			var target_id := arena_api.pick_hive_id_local(local_pos)
			if target_id > 0 and target_id != _drag_src_id:
				var target_owner := int(arena_api.get_hive_owner_id(target_id))
				var active_pid := _get_active_pid(arena_api)
				if target_owner == active_pid:
					SFLog.info("INTENT_FEED", {"src": _drag_src_id, "dst": target_id})
				elif target_owner != 0:
					SFLog.info("INTENT_ATTACK", {"src": _drag_src_id, "dst": target_id})
				else:
					SFLog.info("INVALID_TARGET", {"src": _drag_src_id, "dst": target_id})
		_dragging = false
		_drag_src_id = -1
		return
	if event_type == "motion":
		return

func handle_press(local_pos: Vector2, dev_pid: int, arena_api: ArenaAPI, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	if selection == null or arena_api == null:
		return
	var hive_id: int = _hover_hive_id
	var lane: LaneData = arena_api.pick_lane(local_pos)
	var lane_id: int = lane.id if lane != null else -1
	_handle_press(local_pos, hive_id, lane_id, dev_pid, arena_api, button_index)

func handle_release(local_pos: Vector2, dev_pid: int, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	var hive_id: int = _hover_hive_id
	var lane: LaneData = arena_api.pick_lane(local_pos)
	var lane_id: int = lane.id if lane != null else -1
	_handle_release(local_pos, hive_id, lane_id, dev_pid, arena_api, MOUSE_BUTTON_LEFT)

func handle_drag(local_pos: Vector2, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	var hive_id: int = arena_api.hive_id_at_point(local_pos)
	var lane: LaneData = arena_api.pick_lane(local_pos)
	var lane_id: int = lane.id if lane != null else -1
	_handle_drag(local_pos, hive_id, lane_id, arena_api)

func handle_tap(hive_id: int, dev_pid: int, arena_api: ArenaAPI) -> void:
	_handle_tap(hive_id, dev_pid, arena_api)

func handle_lane_double_tap(local_pos: Vector2, dev_pid: int, pid: int, arena_api: ArenaAPI) -> bool:
	return _handle_lane_double_tap(local_pos, dev_pid, pid, arena_api)

func clear_tap_state() -> void:
	if selection == null:
		return
	selection.clear_tap_state()

func clear_selection() -> void:
	if selection == null:
		return
	selection.clear_selection()

func reset_drag() -> void:
	if selection == null:
		return
	selection.reset_drag()

func handle_hive_hovered(hive_id: int, _global_pos: Vector2) -> void:
	_hover_hive_id = hive_id

func handle_hive_unhovered(hive_id: int) -> void:
	if _hover_hive_id == hive_id:
		_hover_hive_id = -1

func _get_active_pid(arena_api: ArenaAPI) -> int:
	if arena_api == null:
		return 1
	if arena_api.has_method("get_active_pid"):
		return int(arena_api.call("get_active_pid"))
	if "active_pid" in arena_api:
		return int(arena_api.active_pid)
	if arena_api.has_method("get_state"):
		var st = arena_api.call("get_state")
		if st is Dictionary and st.has("active_pid"):
			return int(st["active_pid"])
	return 1

func _owner_color(owner_id: int) -> Color:
	match owner_id:
		1:
			return Color(1.0, 0.8235, 0.0, 1.0)
		2:
			return Color(0.0667, 0.0667, 0.0667, 1.0)
		3:
			return Color(1.0, 0.0, 0.0, 1.0)
		4:
			return Color(0.0, 0.35, 1.0, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)

func _apply_selection(arena_api: ArenaAPI, hive_id: int) -> void:
	var changed := hive_id != _selected_hive_id
	_selected_hive_id = hive_id
	if selection != null:
		selection.selected_hive_id = hive_id
		selection.selected_lane_id = -1
	var hr := _get_hive_renderer(arena_api)
	var owner_id := 0
	if hive_id > 0:
		owner_id = arena_api.get_hive_owner_id(hive_id)
		if hr != null and hr.has_method("set_selected_hive"):
			hr.call("set_selected_hive", hive_id, _owner_color(owner_id))
		if changed:
			SFLog.info("SELECT", {"src": hive_id})
		return
	if hr != null:
		if hr.has_method("clear_selected_hive"):
			hr.call("clear_selected_hive")
		elif hr.has_method("set_selected_hive"):
			hr.call("set_selected_hive", -1, _owner_color(0))

func _get_hive_renderer(arena_api: ArenaAPI) -> Object:
	if arena_api == null:
		return null
	var arena: Node = arena_api._arena
	if arena == null:
		return null
	var renderer_v: Variant = arena.get("hive_renderer")
	if renderer_v != null:
		return renderer_v
	return arena.get_node_or_null("MapRoot/HiveRenderer")

func _get_viewport_from_arena(arena_api: ArenaAPI) -> Viewport:
	if arena_api == null:
		return null
	var arena: Node = arena_api._arena
	if arena == null:
		return null
	return arena.get_viewport()

func _get_screen_pos_from_event(event: InputEvent, arena_api: ArenaAPI) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	var viewport := _get_viewport_from_arena(arena_api)
	if viewport != null:
		return viewport.get_mouse_position()
	return Vector2.ZERO

func _get_world_pos_from_event(event: InputEvent, arena_api: ArenaAPI) -> Vector2:
	var screen_pos := _get_screen_pos_from_event(event, arena_api)
	var viewport := _get_viewport_from_arena(arena_api)
	if viewport != null:
		var inv := viewport.get_canvas_transform().affine_inverse()
		return inv * screen_pos
	if arena_api != null and arena_api._arena is Node2D:
		return (arena_api._arena as Node2D).get_global_mouse_position()
	return screen_pos

func handle_hive_pressed(hive_id: int, button: int, global_pos: Vector2, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	var local_pos := arena_api.world_to_map_local(global_pos)
	var dev_pid: int = _dev_mouse_pid_from_button(button)
	_handle_press(local_pos, hive_id, -1, dev_pid, arena_api, button)

func handle_hive_released(hive_id: int, button: int, global_pos: Vector2, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	var local_pos := arena_api.world_to_map_local(global_pos)
	var dev_pid: int = _dev_mouse_pid_from_button(button)
	_handle_release(local_pos, hive_id, -1, dev_pid, arena_api, button)

func _handle_hive_clicked(hive_id: int, button: int, global_pos: Vector2, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	handle_hive_pressed(hive_id, button, global_pos, arena_api)

func _handle_hive_released(hive_id: int, button: int, global_pos: Vector2, arena_api: ArenaAPI) -> void:
	handle_hive_released(hive_id, button, global_pos, arena_api)

func _is_dev_mouse_override() -> bool:
	return OS.is_debug_build() or Engine.is_editor_hint()

func _dev_mouse_pid_from_button(button_index: int) -> int:
	if not _is_dev_mouse_override():
		return -1
	# Dev convenience mapping:
	# Left mouse = P1
	# Right mouse = P2
	if button_index == MOUSE_BUTTON_LEFT:
		return 1
	if button_index == MOUSE_BUTTON_RIGHT:
		return 2
	return -1

func _handle_press(local_pos: Vector2, hive_id: int, lane_id: int, dev_pid: int, arena_api: ArenaAPI, button_index: int) -> void:
	if _handling_click:
		print("HIVE: re-entrant click blocked")
		return
	_handling_click = true
	if button_index == MOUSE_BUTTON_LEFT or button_index == MOUSE_BUTTON_RIGHT:
		reset_drag()
		_handling_click = false
		return
	_press_active = true
	_press_prev_selected_id = selection.selected_hive_id
	_press_prev_selected_lane_id = selection.selected_lane_id
	_press_hive_id = hive_id
	_press_lane_id = lane_id
	var arena: Node = arena_api._arena if arena_api != null else null
	if arena != null:
		arena._handle_tap(hive_id, -1)
	else:
		print("HIVE: arena is NULL at click time")
	if button_index == MOUSE_BUTTON_LEFT:
		arena_api.set_active_player_id(1)
	elif button_index == MOUSE_BUTTON_RIGHT:
		arena_api.set_active_player_id(2)
	var now_ms: int = Time.get_ticks_msec()
	var is_double: bool = (now_ms - _last_tap_time_ms) <= DOUBLE_TAP_MS and _last_tap_pos.distance_to(local_pos) <= DOUBLE_TAP_DIST_PX
	_last_tap_time_ms = now_ms
	_last_tap_pos = local_pos
	var player_id: int = dev_pid if dev_pid != -1 else arena_api.get_active_player_id()
	if hive_id > 0:
		var hive_owner := -1
		var friendly := false
		var hive: HiveData = arena_api.find_hive_by_id(hive_id)
		if hive != null:
			hive_owner = int(hive.owner_id)
			friendly = hive_owner == player_id
		SFLog.info("HIVE_CLICK_DEBUG", {
			"hive_id": hive_id,
			"hive_owner_id": hive_owner,
			"player_id": player_id,
			"dev_pid": dev_pid,
			"active_pid": arena_api.get_active_player_id(),
			"friendly": friendly
		})
	var barracks_id: int = arena_api.barracks_id_at_point(local_pos)
	if barracks_id != -1 and is_double:
		if _toggle_barracks_selector(barracks_id, dev_pid, arena_api):
			_handling_click = false
			return
	if arena_api.get_barracks_select_id() != -1:
		if barracks_id != -1 and barracks_id == arena_api.get_barracks_select_id():
			_end_barracks_selector(arena_api)
			_handling_click = false
			return
		if hive_id > 0:
			if _barracks_selector_toggle_hive(hive_id, dev_pid, arena_api):
				_handling_click = false
				return
		_end_barracks_selector(arena_api)
		_handling_click = false
		return
	if is_double and lane_id != -1:
		if _handle_lane_double_tap(local_pos, dev_pid, player_id, arena_api):
			_handling_click = false
			return
	if hive_id > 0:
		var hive: HiveData = arena_api.find_hive_by_id(hive_id)
		if hive == null:
			reset_drag()
			_handling_click = false
			return
		selection.drag_active = true
		selection.drag_moved = false
		selection.drag_start_hive_id = hive_id
		selection.drag_start_owner_id = hive.owner_id
		selection.drag_start_pos = local_pos
		selection.drag_current_pos = local_pos
		selection.drag_hover_hive_id = -1
		selection.last_vibe_target_id = -1
		selection.drag_dev_pid = dev_pid
		selection.selected_hive_id = hive_id
		selection.selected_lane_id = -1
		selection.selected_cell = arena_api.cell_from_point(local_pos)
	else:
		selection.drag_active = false
		selection.drag_moved = false
		selection.drag_start_hive_id = -1
		selection.drag_start_owner_id = -1
		selection.drag_hover_hive_id = -1
		selection.last_vibe_target_id = -1
		selection.drag_dev_pid = dev_pid
	_handling_click = false
	arena_api.mark_render_dirty("input_press")

func _handle_release(local_pos: Vector2, _hive_id: int, lane_id: int, dev_pid: int, arena_api: ArenaAPI, _button_index: int) -> void:
	if not _press_active:
		return
	_press_active = false
	selection.drag_current_pos = local_pos
	var gesture_pid: int = selection.drag_dev_pid
	if gesture_pid == -1:
		gesture_pid = dev_pid
	var player_id: int = gesture_pid if gesture_pid != -1 else arena_api.get_active_player_id()
	var end_id: int = arena_api.pick_hive_id_local(local_pos)
	if selection.drag_active and selection.drag_moved and selection.drag_start_hive_id > 0:
		var start_id: int = selection.drag_start_hive_id
		if end_id > 0 and end_id != start_id:
			_apply_hive_to_hive_action(start_id, end_id, player_id, gesture_pid, arena_api)
		reset_drag()
		arena_api.mark_render_dirty("input_release")
		return
	if _press_hive_id > 0:
		_handle_click_hive(_press_prev_selected_id, _press_hive_id, player_id, gesture_pid, arena_api, local_pos)
	else:
		_handle_click_ground(_press_lane_id, local_pos, arena_api)
	reset_drag()
	arena_api.mark_render_dirty("input_release")

func _handle_drag(local_pos: Vector2, _hive_id: int, _lane_id: int, arena_api: ArenaAPI) -> void:
	if not selection.drag_active:
		return
	selection.drag_current_pos = local_pos
	if selection.drag_current_pos.distance_to(selection.drag_start_pos) >= arena_api.get_drag_deadzone_px():
		selection.drag_moved = true
	arena_api.mark_render_dirty("input_drag")
	if not selection.drag_moved:
		return
	var hover_id: int = arena_api.pick_hive_id_local(local_pos)
	if hover_id > 0 and hover_id != selection.drag_start_hive_id:
		if arena_api.lane_exists_between(selection.drag_start_hive_id, hover_id):
			if hover_id != selection.last_vibe_target_id:
				Input.vibrate_handheld(30)
				selection.last_vibe_target_id = hover_id
			selection.drag_hover_hive_id = hover_id
			return
	selection.drag_hover_hive_id = -1
	selection.last_vibe_target_id = -1

func _handle_tap(hive_id: int, dev_pid: int, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	if hive_id <= 0:
		clear_tap_state()
		return
	var hive: HiveData = arena_api.find_hive_by_id(hive_id)
	if hive == null:
		clear_tap_state()
		return
	selection.tap_first_id = hive_id
	selection.tap_first_owner_id = hive.owner_id
	selection.tap_dev_pid = dev_pid

func _handle_click_hive(prev_selected_id: int, clicked_id: int, player_id: int, dev_pid: int, arena_api: ArenaAPI, local_pos: Vector2) -> void:
	var hive: HiveData = arena_api.find_hive_by_id(clicked_id)
	if hive == null:
		clear_tap_state()
		return
	if prev_selected_id != -1 and prev_selected_id != clicked_id:
		_apply_hive_to_hive_action(prev_selected_id, clicked_id, player_id, dev_pid, arena_api)
	selection.selected_hive_id = clicked_id
	selection.selected_lane_id = -1
	selection.selected_cell = arena_api.cell_from_point(local_pos)
	clear_tap_state()

func _handle_click_ground(lane_id: int, local_pos: Vector2, arena_api: ArenaAPI) -> void:
	if lane_id != -1:
		var lane: LaneData = arena_api.find_lane_by_id(lane_id)
		if lane != null:
			selection.selected_hive_id = -1
			selection.selected_lane_id = lane.id
			selection.selected_cell = arena_api.cell_from_point(local_pos)
			arena_api.dbg("SF: Lane selected id=%d a=%d b=%d dir=%d" % [lane.id, lane.a_id, lane.b_id, lane.dir])
			return
	selection.selected_hive_id = -1
	selection.selected_lane_id = -1
	selection.selected_cell = arena_api.cell_from_point(local_pos)
	arena_api.dbg("SF: Cell selected %d,%d" % [selection.selected_cell.x, selection.selected_cell.y])
	clear_tap_state()

func _apply_hive_to_hive_action(from_id: int, to_id: int, player_id: int, dev_pid: int, arena_api: ArenaAPI) -> void:
	if from_id <= 0 or to_id <= 0 or from_id == to_id:
		return
	var from_hive: HiveData = arena_api.find_hive_by_id(from_id)
	var to_hive: HiveData = arena_api.find_hive_by_id(to_id)
	if from_hive == null or to_hive == null:
		return
	var from_friendly: bool = from_hive.owner_id == player_id
	var to_friendly: bool = to_hive.owner_id == player_id
	if from_friendly and to_friendly:
		if arena_api.intent_is_on(from_id, to_id):
			arena_api.try_swarm(from_id, to_id, player_id)
		else:
			_issue_intent(from_id, to_id, player_id, dev_pid, arena_api)
		return
	if from_friendly and not to_friendly:
		var lane_exists: bool = arena_api.lane_index_between(from_id, to_id) != -1
		if not lane_exists:
			_issue_intent(from_id, to_id, player_id, dev_pid, arena_api)
		return
	if not from_friendly and to_friendly:
		if arena_api.intent_is_on(to_id, from_id):
			arena_api.retract_lane(to_id, from_id, player_id)

func _issue_intent(from_id: int, to_id: int, player_id: int, dev_pid: int, arena_api: ArenaAPI) -> void:
	if dev_pid != -1:
		arena_api.apply_dev_intent(from_id, to_id, player_id)
		return
	arena_api.apply_intent_pair(from_id, to_id)

func _handle_lane_double_tap(local_pos: Vector2, dev_pid: int, pid: int, arena_api: ArenaAPI) -> bool:
	var lane: LaneData = arena_api.pick_lane(local_pos)
	if lane == null:
		return false
	var player_id: int = pid
	if player_id == -1:
		player_id = dev_pid if dev_pid != -1 else arena_api.get_active_player_id()
	var a: HiveData = arena_api.find_hive_by_id(lane.a_id)
	var b: HiveData = arena_api.find_hive_by_id(lane.b_id)
	if a == null or b == null:
		return false
	var a_pos: Vector2 = arena_api.cell_center(a.grid_pos)
	var b_pos: Vector2 = arena_api.cell_center(b.grid_pos)
	var tap_f: float = _project_t_on_segment(local_pos, a_pos, b_pos)
	var mode: String = arena_api.lane_mode(a, b)
	var side: String = _lane_side_for_tap(lane, mode, tap_f)
	if side == "":
		return false
	var side_owner: int = a.owner_id if side == "a" else b.owner_id
	var side_hive_id: int = a.id if side == "a" else b.id
	var other_hive_id: int = b.id if side == "a" else a.id
	if mode == "friendly":
		var send_side: String = ""
		if lane.send_a:
			send_side = "a"
		elif lane.send_b:
			send_side = "b"
		if send_side == "":
			return false
		if side_owner == player_id:
			if side == send_side:
				if arena_api.intent_is_on(side_hive_id, other_hive_id):
					return arena_api.try_swarm(side_hive_id, other_hive_id, player_id)
				return false
			var from_id: int = a.id if send_side == "a" else b.id
			var to_id: int = b.id if send_side == "a" else a.id
			if arena_api.intent_is_on(from_id, to_id):
				arena_api.retract_lane(from_id, to_id, player_id)
				return true
			return false
		return false
	if mode == "opposing":
		var player_side := ""
		if player_id == a.owner_id:
			player_side = "a"
		elif player_id == b.owner_id:
			player_side = "b"
		if player_side == "":
			return false
		var enemy_side := "b" if player_side == "a" else "a"
		var player_hive_id: int = a.id if player_side == "a" else b.id
		var enemy_hive_id: int = b.id if player_side == "a" else a.id
		if not arena_api.intent_is_on(player_hive_id, enemy_hive_id):
			return false
		if side == player_side:
			arena_api.retract_lane(player_hive_id, enemy_hive_id, player_id)
			return true
		if side == enemy_side:
			return arena_api.try_swarm(player_hive_id, enemy_hive_id, player_id)
		return false
	if side_owner == player_id:
		if arena_api.intent_is_on(side_hive_id, other_hive_id):
			return arena_api.try_swarm(side_hive_id, other_hive_id, player_id)
		return false
	if player_id == a.owner_id and side == "b":
		if arena_api.intent_is_on(a.id, b.id):
			arena_api.retract_lane(a.id, b.id, player_id)
			return true
	if player_id == b.owner_id and side == "a":
		if arena_api.intent_is_on(b.id, a.id):
			arena_api.retract_lane(b.id, a.id, player_id)
			return true
	return false

func _lane_side_for_tap(lane: LaneData, mode: String, tap_f: float) -> String:
	var mid_deadzone: float = 0.02
	if mode == "opposing" and lane.send_a and lane.send_b:
		var impact_f: float = clampf(lane.last_impact_f, 0.0, 1.0)
		if tap_f < impact_f - mid_deadzone:
			return "a"
		if tap_f > impact_f + mid_deadzone:
			return "b"
		return ""
	if tap_f < 0.5 - mid_deadzone:
		return "a"
	if tap_f > 0.5 + mid_deadzone:
		return "b"
	return ""

func _project_t_on_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	if ab.length_squared() == 0.0:
		return 0.0
	var t: float = (p - a).dot(ab) / ab.length_squared()
	return clampf(t, 0.0, 1.0)

func _toggle_barracks_selector(barracks_id: int, dev_pid: int, arena_api: ArenaAPI) -> bool:
	if arena_api.get_barracks_select_id() == barracks_id:
		_end_barracks_selector(arena_api)
		return true
	return _start_barracks_selector(barracks_id, dev_pid, arena_api)

func _start_barracks_selector(barracks_id: int, dev_pid: int, arena_api: ArenaAPI) -> bool:
	var b: Dictionary = arena_api.barracks_by_id(barracks_id)
	if b.is_empty():
		return false
	if not bool(b.get("active", false)):
		return false
	var owner_id: int = int(b.get("owner_id", 0))
	var player_id: int = dev_pid if dev_pid != -1 else arena_api.get_active_player_id()
	if owner_id == 0 or owner_id != player_id:
		return false
	arena_api.set_barracks_select_id(barracks_id)
	arena_api.set_barracks_select_pid(player_id)
	arena_api.clear_barracks_select_targets()
	arena_api.set_barracks_select_changed(false)
	arena_api.dbg("SF: barracks %d select ON" % barracks_id)
	return true

func _end_barracks_selector(arena_api: ArenaAPI) -> void:
	var select_id: int = arena_api.get_barracks_select_id()
	if select_id == -1:
		return
	if arena_api.get_barracks_select_changed():
		var b: Dictionary = arena_api.barracks_by_id(select_id)
		if not b.is_empty():
			b["preferred_targets"] = arena_api.get_barracks_select_targets().duplicate()
	arena_api.dbg("SF: barracks %d select OFF" % select_id)
	arena_api.set_barracks_select_id(-1)
	arena_api.set_barracks_select_pid(-1)
	arena_api.clear_barracks_select_targets()
	arena_api.set_barracks_select_changed(false)

func _barracks_selector_toggle_hive(hive_id: int, dev_pid: int, arena_api: ArenaAPI) -> bool:
	var select_id: int = arena_api.get_barracks_select_id()
	if select_id == -1:
		return false
	var b: Dictionary = arena_api.barracks_by_id(select_id)
	if b.is_empty():
		return false
	var player_id: int = dev_pid if dev_pid != -1 else arena_api.get_active_player_id()
	if arena_api.get_barracks_select_pid() != -1 and player_id != arena_api.get_barracks_select_pid():
		return false
	var required: Array = b.get("required_hive_ids", [])
	if not required.has(hive_id):
		return false
	var hive: HiveData = arena_api.find_hive_by_id(hive_id)
	if hive == null:
		return false
	var owner_id: int = int(b.get("owner_id", 0))
	if hive.owner_id != owner_id:
		return false
	var targets := arena_api.get_barracks_select_targets()
	if targets.has(hive_id):
		targets.erase(hive_id)
		arena_api.dbg("SF: barracks %d select REMOVE %d" % [select_id, hive_id])
	else:
		targets.append(hive_id)
		arena_api.dbg("SF: barracks %d select ADD %d" % [select_id, hive_id])
	arena_api.set_barracks_select_changed(true)
	return true
