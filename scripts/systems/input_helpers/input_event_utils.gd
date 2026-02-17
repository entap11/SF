class_name InputEventUtils
extends RefCounted

static func is_dev_mouse_override() -> bool:
	return OS.is_debug_build() or Engine.is_editor_hint()

static func dev_mouse_pid_from_button(button_index: int) -> int:
	if not is_dev_mouse_override():
		return -1
	if button_index == MOUSE_BUTTON_LEFT:
		return 1
	if button_index == MOUSE_BUTTON_RIGHT:
		return 2
	return -1

static func player_id_from_button(button_index: int, arena_api: Object, dev_pid: int = -1) -> int:
	if dev_pid != -1:
		return dev_pid
	if is_dev_mouse_override():
		if button_index == MOUSE_BUTTON_LEFT:
			return 1
		if button_index == MOUSE_BUTTON_RIGHT:
			return 2
	if arena_api != null and arena_api.has_method("get_active_player_id"):
		var active_pid: int = int(arena_api.call("get_active_player_id"))
		if active_pid >= 1 and active_pid <= 4:
			return active_pid
	return 1

static func get_viewport_from_arena(arena_api: Object) -> Viewport:
	if arena_api == null:
		return null
	var arena_v: Variant = arena_api.get("_arena")
	if arena_v == null or not (arena_v is Node):
		return null
	return (arena_v as Node).get_viewport()

static func get_screen_pos_from_event(event: InputEvent, arena_api: Object) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	var viewport := get_viewport_from_arena(arena_api)
	if viewport != null:
		return viewport.get_mouse_position()
	return Vector2.ZERO

static func get_world_pos_from_event(event: InputEvent, arena_api: Object) -> Vector2:
	var screen_pos := get_screen_pos_from_event(event, arena_api)
	var viewport := get_viewport_from_arena(arena_api)
	if viewport != null:
		var inv := viewport.get_canvas_transform().affine_inverse()
		return inv * screen_pos
	if arena_api != null:
		var arena_v: Variant = arena_api.get("_arena")
		if arena_v is Node2D:
			return (arena_v as Node2D).get_global_mouse_position()
	return screen_pos
