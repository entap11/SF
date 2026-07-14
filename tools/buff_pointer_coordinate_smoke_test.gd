extends SceneTree

const InputBridgeScript := preload("res://scripts/arena_helpers/input_bridge_utils.gd")

var _failed: bool = false


func _init() -> void:
	var world_layer := CanvasLayer.new()
	world_layer.offset = Vector2(19.0, 27.0)
	root.add_child(world_layer)
	var container := SubViewportContainer.new()
	container.position = Vector2(73.0, 41.0)
	container.size = Vector2(960.0, 540.0)
	container.stretch = true
	world_layer.add_child(container)
	var subviewport := SubViewport.new()
	subviewport.size = Vector2i(1280, 720)
	subviewport.disable_3d = true
	container.add_child(subviewport)
	var map_root := Node2D.new()
	map_root.position = Vector2(31.0, -17.0)
	map_root.scale = Vector2(1.15, 0.9)
	subviewport.add_child(map_root)
	var camera := Camera2D.new()
	subviewport.add_child(camera)
	await process_frame
	camera.make_current()
	await process_frame

	var helper: ArenaInputBridgeUtils = InputBridgeScript.new()
	var stable_target_local := Vector2(180.0, 125.0)
	_test_round_trip(helper, container, subviewport, map_root, camera, stable_target_local, Vector2(250.0, 170.0), Vector2(1.0, 1.0), "default camera")
	_test_round_trip(helper, container, subviewport, map_root, camera, stable_target_local, Vector2(420.0, 260.0), Vector2(1.8, 1.8), "zoomed camera")
	container.size = Vector2(700.0, 900.0)
	await process_frame
	_test_round_trip(helper, container, subviewport, map_root, camera, stable_target_local, Vector2(310.0, 450.0), Vector2(0.85, 0.85), "portrait framing")

	var outside: Dictionary = helper.root_screen_to_arena_local(
		Vector2(-200.0, -200.0), container, subviewport, map_root, true
	)
	_expect(not bool(outside.get("ok", false)) and str(outside.get("reason", "")) == "outside_world_viewport", "HUD/outside release should fail conversion")

	world_layer.queue_free()
	if not _failed:
		print("BUFF_POINTER_COORDINATE_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_round_trip(
	helper: ArenaInputBridgeUtils,
	container: SubViewportContainer,
	subviewport: SubViewport,
	map_root: Node2D,
	camera: Camera2D,
	target_local: Vector2,
	camera_position: Vector2,
	camera_zoom: Vector2,
	label: String
) -> void:
	camera.global_position = camera_position
	camera.zoom = camera_zoom
	camera.force_update_scroll()
	var projected: Dictionary = helper.arena_local_to_root_screen(target_local, container, subviewport, map_root)
	_expect(bool(projected.get("ok", false)), "%s should project target" % label)
	if not bool(projected.get("ok", false)):
		return
	var resolved: Dictionary = helper.root_screen_to_arena_local(
		projected.get("root_screen_pos", Vector2.ZERO), container, subviewport, map_root, false
	)
	_expect(bool(resolved.get("ok", false)), "%s should resolve projected point" % label)
	var actual: Vector2 = resolved.get("arena_local_pos", Vector2.INF) as Vector2
	_expect(actual.distance_to(target_local) <= 0.01, "%s should round-trip the same stable world target: expected=%s actual=%s" % [label, target_local, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_POINTER_COORDINATE_SMOKE: %s" % message)
