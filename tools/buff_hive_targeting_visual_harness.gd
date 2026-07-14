extends SceneTree

const ControllerScript := preload("res://scripts/renderers/buff_hive_targeting_controller.gd")
const HiveNodeScene := preload("res://scenes/hive/HiveNode.tscn")

class VisualArena:
	extends Node2D
	var map_root: Node2D = null
	var viewport_size: Vector2 = Vector2(900.0, 650.0)

	func root_screen_to_buff_arena_local(root_screen_pos: Vector2) -> Dictionary:
		if not Rect2(Vector2.ZERO, viewport_size).has_point(root_screen_pos):
			return {"ok": false, "reason": "outside_world_viewport"}
		return {"ok": true, "arena_local_pos": map_root.to_local(root_screen_pos)}

	func buff_arena_local_to_root_screen(arena_local_pos: Vector2) -> Dictionary:
		return {"ok": true, "root_screen_pos": map_root.to_global(arena_local_pos)}

	func buff_arena_local_to_world(arena_local_pos: Vector2) -> Vector2:
		return map_root.to_global(arena_local_pos)


class FingerOverlay:
	extends Node2D

	func _ready() -> void:
		z_index = 60
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 52.0, Color(0.055, 0.065, 0.085, 0.82))
		draw_arc(Vector2.ZERO, 52.0, 0.0, TAU, 72, Color(0.82, 0.86, 0.94, 0.58), 2.0, true)
		draw_circle(Vector2(0.0, -62.0), 16.0, Color(0.92, 0.76, 0.18, 0.96))


var _output_dir: String = "res://artifacts/buff_targeting_loop2"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(900, 650))
	var root_node := Node2D.new()
	root_node.name = "BuffHiveTargetVisualHarness"
	get_root().add_child(root_node)

	var backdrop := ColorRect.new()
	backdrop.name = "ArenaBackdrop"
	backdrop.color = Color(0.055, 0.075, 0.095, 1.0)
	backdrop.size = Vector2(900.0, 650.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -100
	root_node.add_child(backdrop)

	var arena := VisualArena.new()
	arena.name = "VisualArena"
	root_node.add_child(arena)
	var map_root := Node2D.new()
	map_root.name = "MapRoot"
	map_root.position = Vector2(70.0, 105.0)
	root_node.add_child(map_root)
	arena.map_root = map_root

	var renderer_script: Script = load("res://scripts/renderers/hive_renderer.gd") as Script
	var renderer: Node2D = renderer_script.new() as Node2D
	renderer.name = "HiveRenderer"
	map_root.add_child(renderer)
	var controller: Node2D = ControllerScript.new()
	controller.name = "BuffHiveTargetPresentation"
	map_root.add_child(controller)
	controller.call("setup", arena, renderer)

	var specs: Array[Dictionary] = [
		{"id": 1, "owner": 1, "power": 8, "pos": Vector2(115.0, 235.0), "color": Color(0.18, 0.78, 1.0, 1.0)},
		{"id": 2, "owner": 1, "power": 28, "pos": Vector2(330.0, 250.0), "color": Color(0.18, 0.78, 1.0, 1.0)},
		{"id": 3, "owner": 2, "power": 18, "pos": Vector2(545.0, 225.0), "color": Color(1.0, 0.28, 0.28, 1.0)},
		{"id": 4, "owner": 1, "power": 52, "pos": Vector2(705.0, 375.0), "color": Color(0.18, 0.78, 1.0, 1.0)},
		{"id": 5, "owner": 2, "power": 38, "pos": Vector2(195.0, 455.0), "color": Color(1.0, 0.28, 0.28, 1.0)}
	]
	for spec: Dictionary in specs:
		var hive: Node2D = HiveNodeScene.instantiate() as Node2D
		var hive_id: int = int(spec.id)
		hive.name = "HiveNode_%d" % hive_id
		hive.position = spec.pos as Vector2
		hive.set("hive_id", hive_id)
		renderer.add_child(hive)
		(renderer.get("hive_nodes_by_id") as Dictionary)[hive_id] = hive

	await process_frame
	for spec: Dictionary in specs:
		var hive_id: int = int(spec.id)
		var hive: Node = (renderer.get("hive_nodes_by_id") as Dictionary)[hive_id]
		hive.call(
			"apply_render",
			int(spec.owner),
			int(spec.power),
			27.0,
			spec.color as Color,
			14,
			"Hive",
			1,
			3
		)

	var finger := FingerOverlay.new()
	finger.name = "SimulatedFingerAndDragSprite"
	finger.position = map_root.to_global(Vector2(330.0, 250.0))
	root_node.add_child(finger)

	controller.call("begin_or_update", 9001, [1, 2, 4], -1, finger.position)
	for _i in range(8):
		await process_frame

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	controller.call("set_phase_override", 0.0)
	await _capture_after_frames("eligible_pulse_low.png", 3)
	controller.call("set_phase_override", 1.0)
	finger.visible = false
	await _capture_after_frames("eligible_pulse_high.png", 3)
	finger.visible = true
	await _capture_after_frames("previewed_high_with_fingertip.png", 3)

	controller.call("clear", 9001, true, "visual_harness_cancel")
	finger.visible = false
	await _capture_after_frames("cleanup_after_cancel.png", 3)

	print("BUFF_HIVE_TARGETING_VISUAL_CAPTURE: PASS")
	for filename in [
		"eligible_pulse_low.png",
		"eligible_pulse_high.png",
		"previewed_high_with_fingertip.png",
		"cleanup_after_cancel.png"
	]:
		print(ProjectSettings.globalize_path(_output_dir.path_join(filename)))
	root_node.queue_free()
	quit(0)


func _capture_after_frames(filename: String, frame_count: int) -> void:
	for _i in range(frame_count):
		await process_frame
	var image: Image = get_root().get_texture().get_image()
	if image.get_width() >= 900 and image.get_height() >= 650:
		image = image.get_region(Rect2i(0, 0, 900, 650))
	var path: String = ProjectSettings.globalize_path(_output_dir.path_join(filename))
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("BUFF_HIVE_TARGETING_VISUAL_CAPTURE: save failed %s error=%d" % [path, error])
		quit(1)
