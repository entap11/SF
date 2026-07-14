extends SceneTree

const ControllerScript := preload("res://scripts/renderers/buff_lane_global_targeting_controller.gd")

class VisualArena:
	extends Node2D
	var map_root: Node2D = null
	var controller: Node = null
	var viewport_size: Vector2 = Vector2(900, 650)
	var excluded_bottom_px: float = 92.0
	var transform_revision: int = 1

	func buff_arena_local_to_root_screen(arena_local_pos: Vector2) -> Dictionary:
		return {"ok": true, "root_screen_pos": map_root.to_global(arena_local_pos)}

	func get_buff_targeting_transform_signature() -> String:
		return "%d|%s|%s" % [transform_revision, str(map_root.global_transform), str(viewport_size)]

	func get_buff_global_targeting_query(root_screen_pos: Vector2) -> Dictionary:
		var playfield := Rect2(Vector2(18, 18), viewport_size - Vector2(36, excluded_bottom_px + 30))
		var valid: bool = playfield.has_point(root_screen_pos)
		var root_points := PackedVector2Array([
			playfield.position,
			Vector2(playfield.end.x, playfield.position.y),
			playfield.end,
			Vector2(playfield.position.x, playfield.end.y)
		])
		var arena_points := PackedVector2Array()
		if valid:
			for point in root_points:
				arena_points.append(map_root.to_local(point))
		return {"valid": valid, "boundary_arena_local_points": arena_points}

	func notify_buff_lane_render_nodes_changed() -> void:
		if controller != null and controller.has_method("notify_render_nodes_changed"):
			controller.call("notify_render_nodes_changed")


class EndpointMarker:
	extends Node2D
	var color: Color = Color(0.20, 0.78, 1.0, 1.0)

	func _ready() -> void:
		z_index = 4
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 23.0, Color(0.025, 0.05, 0.08, 1.0))
		draw_circle(Vector2.ZERO, 18.0, color)
		draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 48, Color(0.72, 0.82, 0.92, 0.72), 2.0, true)


class FingerOverlay:
	extends Node2D

	func _ready() -> void:
		z_index = 80
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 51.0, Color(0.045, 0.055, 0.075, 0.84))
		draw_arc(Vector2.ZERO, 51.0, 0.0, TAU, 72, Color(0.86, 0.90, 0.98, 0.62), 2.0, true)
		draw_circle(Vector2(0, -61), 15.0, Color(0.94, 0.73, 0.17, 0.97))


var _output_dir: String = "res://artifacts/buff_targeting_loop3"
var _capture_size: Vector2i = Vector2i(900, 650)
var _capture_viewport: SubViewport = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "Loop3CaptureViewport"
	_capture_viewport.disable_3d = true
	_capture_viewport.size = _capture_size
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_capture_viewport)
	var root_node := Node2D.new()
	root_node.name = "BuffLaneGlobalTargetVisualHarness"
	_capture_viewport.add_child(root_node)

	var backdrop := ColorRect.new()
	backdrop.name = "ArenaBackdrop"
	backdrop.color = Color(0.035, 0.055, 0.075, 1.0)
	backdrop.size = Vector2(_capture_size)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -100
	root_node.add_child(backdrop)

	var hud_exclusion := ColorRect.new()
	hud_exclusion.name = "ExcludedHudAndBuffStripRegion"
	hud_exclusion.color = Color(0.025, 0.035, 0.055, 0.96)
	hud_exclusion.position = Vector2(0, 558)
	hud_exclusion.size = Vector2(900, 92)
	hud_exclusion.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_exclusion.z_index = 70
	root_node.add_child(hud_exclusion)

	var arena := VisualArena.new()
	arena.name = "VisualArena"
	root_node.add_child(arena)
	var map_root := Node2D.new()
	map_root.name = "MapRoot"
	map_root.position = Vector2(70, 72)
	root_node.add_child(map_root)
	arena.map_root = map_root

	var renderer_script: Script = load("res://scripts/renderers/lane_renderer.gd") as Script
	var renderer: Node2D = renderer_script.new() as Node2D
	renderer.name = "LaneRenderer"
	map_root.add_child(renderer)
	var controller: Node2D = ControllerScript.new() as Node2D
	controller.name = "BuffLaneGlobalTargetPresentation"
	map_root.add_child(controller)
	arena.controller = controller
	controller.call("setup", arena, renderer)
	renderer.call("setup", null, null, arena)

	var positions: Dictionary = {
		1: Vector2(80, 90), 2: Vector2(680, 110),
		3: Vector2(100, 390), 4: Vector2(680, 410),
		5: Vector2(90, 235), 6: Vector2(690, 270)
	}
	var hive_nodes: Dictionary = {}
	for hive_id_any in positions.keys():
		var hive_id: int = int(hive_id_any)
		var marker := EndpointMarker.new()
		marker.name = "HiveMarker_%d" % hive_id
		marker.position = positions[hive_id] as Vector2
		marker.color = Color(0.18, 0.76, 1.0, 1.0) if hive_id <= 4 else Color(0.98, 0.30, 0.26, 1.0)
		map_root.add_child(marker)
		hive_nodes[hive_id] = marker
	renderer.call("set_hive_nodes", hive_nodes)
	var lanes: Array = [
		{"lane_id": 1, "a_id": 1, "b_id": 2, "send_a": true, "send_b": false},
		{"lane_id": 2, "a_id": 3, "b_id": 4, "send_a": true, "send_b": false},
		{"lane_id": 3, "a_id": 1, "b_id": 4, "send_a": true, "send_b": false},
		{"lane_id": 4, "a_id": 3, "b_id": 2, "send_a": false, "send_b": true},
		{"lane_id": 5, "a_id": 5, "b_id": 6, "send_a": true, "send_b": false}
	]
	renderer.call("set_model", {
		"map_id": "loop3_visual_fixture",
		"cell_size": 64,
		"sim_running": true,
		"sim_time_s": 2.0,
		"hives": [
			{"id": 1, "owner_id": 1}, {"id": 2, "owner_id": 1},
			{"id": 3, "owner_id": 1}, {"id": 4, "owner_id": 1},
			{"id": 5, "owner_id": 2}, {"id": 6, "owner_id": 2}
		],
		"lanes": lanes
	})
	for _i in range(12):
		await process_frame

	var finger := FingerOverlay.new()
	finger.name = "SimulatedThumb"
	finger.position = map_root.to_global(Vector2(370, 100))
	root_node.add_child(finger)
	var lane_preview := {"ok": true, "target_type": "lane", "eligible_target_ids": [1, 2, 3]}
	controller.call("begin_or_update", 9001, lane_preview, "", null, finger.position)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	controller.call("set_phase_override", 0.08)
	await _warm_capture_readbacks(10)
	await _capture_after_frames("lane_travel_phase_008_phone.png", 4)
	controller.call("set_phase_override", 0.58)
	await _warm_capture_readbacks(10)
	await _capture_after_frames("lane_travel_phase_058_selected_under_thumb_phone.png", 8)

	# Alternate wide/aspect + zoom fixture uses the same production components.
	_capture_size = Vector2i(1100, 620)
	_capture_viewport.size = _capture_size
	backdrop.size = Vector2(_capture_size)
	hud_exclusion.position = Vector2(0, 532)
	hud_exclusion.size = Vector2(1100, 88)
	arena.viewport_size = Vector2(_capture_size)
	arena.excluded_bottom_px = 88.0
	map_root.position = Vector2(150, 55)
	map_root.scale = Vector2(0.94, 0.94)
	arena.transform_revision += 1
	finger.position = map_root.to_global(Vector2(370, 100))
	controller.call("force_recompute", "alternate_aspect_zoom")
	await _capture_after_frames("lane_selected_alternate_aspect_zoom.png", 5)

	# Global valid boundary, invalid HUD region, then complete cancellation cleanup.
	map_root.scale = Vector2.ONE
	map_root.position = Vector2.ZERO
	arena.transform_revision += 1
	finger.position = Vector2(550, 290)
	var global_preview := {"ok": true, "target_type": "global", "eligible_target_ids": ["global"]}
	controller.call("begin_or_update", 9002, global_preview, "", null, finger.position)
	controller.call("set_phase_override", 0.36)
	await _capture_after_frames("global_valid_boundary_wide.png", 4)
	finger.position = Vector2(550, 570)
	controller.call("update_finger", 9002, finger.position)
	await _capture_after_frames("global_invalid_hud_cleared.png", 4)
	controller.call("clear", 9002, true, "visual_harness_cancel")
	finger.visible = false
	await _capture_after_frames("cleanup_after_cancel.png", 12)

	print("BUFF_LANE_GLOBAL_TARGETING_VISUAL_CAPTURE: PASS")
	for filename in [
		"lane_travel_phase_008_phone.png",
		"lane_travel_phase_058_selected_under_thumb_phone.png",
		"lane_selected_alternate_aspect_zoom.png",
		"global_valid_boundary_wide.png",
		"global_invalid_hud_cleared.png",
		"cleanup_after_cancel.png"
	]:
		print(ProjectSettings.globalize_path(_output_dir.path_join(filename)))
	_capture_viewport.queue_free()
	quit(0)


func _capture_after_frames(filename: String, frame_count: int) -> void:
	var image: Image = null
	var final_score: int = -1
	for _attempt in range(8):
		var wait_frames: int = frame_count if _attempt == 0 else 2
		for _i in range(wait_frames):
			await process_frame
		var candidate: Image = _capture_viewport.get_texture().get_image()
		if candidate.get_width() != _capture_size.x or candidate.get_height() != _capture_size.y:
			candidate.resize(_capture_size.x, _capture_size.y, Image.INTERPOLATE_LANCZOS)
		final_score = _image_fixture_detail_score(candidate)
		image = candidate.duplicate()
	if image == null or final_score < 8:
		push_error("BUFF_LANE_GLOBAL_TARGETING_VISUAL_CAPTURE: blank GPU readback %s" % filename)
		quit(1)
	var path: String = ProjectSettings.globalize_path(_output_dir.path_join(filename))
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("BUFF_LANE_GLOBAL_TARGETING_VISUAL_CAPTURE: save failed %s error=%d" % [path, error])
		quit(1)


func _warm_capture_readbacks(frame_count: int) -> void:
	for _i in range(frame_count):
		await process_frame
	for _i in range(8):
		await process_frame
		_capture_viewport.get_texture().get_image()


func _image_fixture_detail_score(image: Image) -> int:
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return 0
	var bright_samples: int = 0
	for y in range(0, image.get_height(), 10):
		for x in range(0, image.get_width(), 10):
			var color: Color = image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) > 0.42:
				bright_samples += 1
	return bright_samples
