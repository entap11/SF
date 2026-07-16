extends SceneTree

const InputBridgeScript := preload("res://scripts/arena_helpers/input_bridge_utils.gd")

var _failed: bool = false


func _initialize() -> void:
	var world_layer := CanvasLayer.new()
	world_layer.offset = Vector2(23.0, 31.0)
	root.add_child(world_layer)
	var container := SubViewportContainer.new()
	container.position = Vector2(92.0, 74.0)
	container.size = Vector2(820.0, 1320.0)
	container.stretch = true
	world_layer.add_child(container)
	var subviewport := SubViewport.new()
	subviewport.size = Vector2i(820, 1320)
	subviewport.disable_3d = true
	container.add_child(subviewport)
	var map_root := Node2D.new()
	map_root.position = Vector2(37.0, -29.0)
	map_root.scale = Vector2(1.08, 0.94)
	subviewport.add_child(map_root)
	var camera := Camera2D.new()
	camera.ignore_rotation = false
	camera.global_position = Vector2(410.0, 660.0)
	camera.zoom = Vector2(1.22, 1.22)
	subviewport.add_child(camera)
	await process_frame
	camera.make_current()
	await process_frame

	var helper: ArenaInputBridgeUtils = InputBridgeScript.new()
	for screen_angle_deg in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		# Camera canvas transforms are inverse transforms, matching the shell controller.
		camera.rotation_degrees = -screen_angle_deg
		camera.force_update_scroll()
		await process_frame
		_test_role_round_trip(helper, container, subviewport, map_root, "hive tap", Vector2(160.0, 210.0), screen_angle_deg)
		_test_role_round_trip(helper, container, subviewport, map_root, "lane hit", Vector2(395.0, 505.0), screen_angle_deg)
		_test_role_round_trip(helper, container, subviewport, map_root, "buff target", Vector2(610.0, 845.0), screen_angle_deg)
		_test_role_round_trip(helper, container, subviewport, map_root, "screen-to-world physics query", Vector2(280.0, 1010.0), screen_angle_deg)
		_test_drag_round_trip(helper, container, subviewport, map_root, Vector2(180.0, 260.0), Vector2(690.0, 1040.0), screen_angle_deg)

	var hud_point := Vector2(30.0, 30.0)
	var outside: Dictionary = helper.root_screen_to_arena_local(hud_point, container, subviewport, map_root, true)
	_expect(not bool(outside.get("ok", false)), "HUD point must not enter the battlefield SubViewport")
	_expect(str(outside.get("reason", "")) == "outside_world_viewport", "HUD rejection must identify the viewport boundary")

	world_layer.queue_free()
	if not _failed:
		print("BATTLEFIELD_SCREEN_ANGLE_INPUT_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_role_round_trip(
	helper: ArenaInputBridgeUtils,
	container: SubViewportContainer,
	subviewport: SubViewport,
	map_root: Node2D,
	role: String,
	target_local: Vector2,
	screen_angle_deg: float
) -> void:
	var projected: Dictionary = helper.arena_local_to_root_screen(target_local, container, subviewport, map_root)
	_expect(bool(projected.get("ok", false)), "%s should project at %+.1f°" % [role, screen_angle_deg])
	if not bool(projected.get("ok", false)):
		return
	var resolved: Dictionary = helper.root_screen_to_arena_local(
		projected.get("root_screen_pos", Vector2.ZERO), container, subviewport, map_root, false
	)
	_expect(bool(resolved.get("ok", false)), "%s should inverse-map at %+.1f°" % [role, screen_angle_deg])
	var actual_local: Vector2 = resolved.get("arena_local_pos", Vector2.INF) as Vector2
	_expect(actual_local.distance_to(target_local) <= 0.02, "%s must resolve the same gameplay point at %+.1f°" % [role, screen_angle_deg])

	var subviewport_pos: Vector2 = projected.get("subviewport_pos", Vector2.ZERO) as Vector2
	var actual_world: Vector2 = helper.screen_to_world(subviewport, Vector2.INF, subviewport_pos)
	var expected_world: Vector2 = map_root.to_global(target_local)
	_expect(actual_world.distance_to(expected_world) <= 0.02, "%s canonical screen-to-world must include camera roll at %+.1f°" % [role, screen_angle_deg])


func _test_drag_round_trip(
	helper: ArenaInputBridgeUtils,
	container: SubViewportContainer,
	subviewport: SubViewport,
	map_root: Node2D,
	start_local: Vector2,
	end_local: Vector2,
	screen_angle_deg: float
) -> void:
	# Lane creation and grab-throw deletion consume the same local press/move/release
	# positions. Prove both drag endpoints survive the presentation transform.
	_test_role_round_trip(helper, container, subviewport, map_root, "drag press", start_local, screen_angle_deg)
	_test_role_round_trip(helper, container, subviewport, map_root, "drag move/release", end_local, screen_angle_deg)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BATTLEFIELD_SCREEN_ANGLE_INPUT_SMOKE: %s" % message)
