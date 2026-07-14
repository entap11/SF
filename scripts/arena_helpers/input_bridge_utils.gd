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


func root_screen_to_arena_local(
	root_screen_pos: Vector2,
	container: SubViewportContainer,
	subviewport: SubViewport,
	map_root: Node2D,
	require_inside_container: bool = true
) -> Dictionary:
	if container == null:
		return {"ok": false, "reason": "viewport_container_missing"}
	if subviewport == null:
		return {"ok": false, "reason": "subviewport_missing"}
	if map_root == null:
		return {"ok": false, "reason": "map_root_missing"}
	if container.size.x <= 0.0 or container.size.y <= 0.0:
		return {"ok": false, "reason": "viewport_container_empty"}
	if subviewport.size.x <= 0 or subviewport.size.y <= 0:
		return {"ok": false, "reason": "subviewport_empty"}
	var root_to_container: Transform2D = container.get_global_transform_with_canvas().affine_inverse()
	var container_local: Vector2 = root_to_container * root_screen_pos
	if require_inside_container and not Rect2(Vector2.ZERO, container.size).has_point(container_local):
		return {
			"ok": false,
			"reason": "outside_world_viewport",
			"root_screen_pos": root_screen_pos,
			"container_local_pos": container_local
		}
	var viewport_scale: Vector2 = Vector2(
		float(subviewport.size.x) / container.size.x,
		float(subviewport.size.y) / container.size.y
	)
	var subviewport_pos: Vector2 = container_local * viewport_scale
	var world_pos: Vector2 = subviewport.get_canvas_transform().affine_inverse() * subviewport_pos
	return {
		"ok": true,
		"root_screen_pos": root_screen_pos,
		"container_local_pos": container_local,
		"subviewport_pos": subviewport_pos,
		"world_pos": world_pos,
		"arena_local_pos": map_root.to_local(world_pos)
	}


func arena_local_to_root_screen(
	arena_local_pos: Vector2,
	container: SubViewportContainer,
	subviewport: SubViewport,
	map_root: Node2D
) -> Dictionary:
	if container == null:
		return {"ok": false, "reason": "viewport_container_missing"}
	if subviewport == null:
		return {"ok": false, "reason": "subviewport_missing"}
	if map_root == null:
		return {"ok": false, "reason": "map_root_missing"}
	if container.size.x <= 0.0 or container.size.y <= 0.0:
		return {"ok": false, "reason": "viewport_container_empty"}
	if subviewport.size.x <= 0 or subviewport.size.y <= 0:
		return {"ok": false, "reason": "subviewport_empty"}
	var world_pos: Vector2 = map_root.to_global(arena_local_pos)
	var subviewport_pos: Vector2 = subviewport.get_canvas_transform() * world_pos
	var container_scale: Vector2 = Vector2(
		container.size.x / float(subviewport.size.x),
		container.size.y / float(subviewport.size.y)
	)
	var container_local: Vector2 = subviewport_pos * container_scale
	var root_screen_pos: Vector2 = container.get_global_transform_with_canvas() * container_local
	return {
		"ok": true,
		"arena_local_pos": arena_local_pos,
		"world_pos": world_pos,
		"subviewport_pos": subviewport_pos,
		"container_local_pos": container_local,
		"root_screen_pos": root_screen_pos
	}
