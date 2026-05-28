class_name ArenaInputBridgeUtils
extends RefCounted

const MOUSE_BUTTON_P4_PRIMARY: int = 8
const MOUSE_BUTTON_P4_SECONDARY: int = 9

func is_dev_mouse_override() -> bool:
	return OS.is_debug_build() or Engine.is_editor_hint()

func is_player_pointer_button(button_index: int) -> bool:
	return player_id_for_dev_pointer_button(button_index) != -1

func player_id_for_dev_pointer_button(button_index: int) -> int:
	if button_index == MOUSE_BUTTON_LEFT:
		return 1
	if button_index == MOUSE_BUTTON_RIGHT:
		return 2
	if button_index == MOUSE_BUTTON_MIDDLE:
		return 3
	if button_index == MOUSE_BUTTON_P4_PRIMARY or button_index == MOUSE_BUTTON_P4_SECONDARY:
		return 4
	return -1

func dev_mouse_pid(event: InputEventMouseButton) -> int:
	if not is_dev_mouse_override():
		return -1
	return player_id_for_dev_pointer_button(event.button_index)

func screen_to_world(viewport: Viewport, fallback_world_pos: Vector2, screen_pos: Vector2) -> Vector2:
	if viewport == null:
		return fallback_world_pos
	# Canonical screen->world conversion from viewport canvas transform.
	var canvas_xform: Transform2D = viewport.get_canvas_transform()
	return canvas_xform.affine_inverse() * screen_pos

func pointer_local_from_screen(viewport: Viewport, map_root: Node2D, fallback_world_pos: Vector2, screen_pos: Vector2) -> Vector2:
	var world_pos: Vector2 = screen_to_world(viewport, fallback_world_pos, screen_pos)
	if map_root == null:
		return world_pos
	return map_root.to_local(world_pos)
