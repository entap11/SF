extends SceneTree

const Presentation := preload("res://scripts/renderers/buff_freeze_lane_presentation.gd")
const WIDTH: int = 960
const HEIGHT: int = 640

class StudyArena:
	extends Node2D
	func get_buff_presentation_owner_color(_owner: int) -> Color:
		return Color(0.96, 0.75, 0.15)

class LaneFixture:
	extends Node2D
	var points := PackedVector2Array([Vector2(160, 310), Vector2(375, 265), Vector2(580, 330), Vector2(800, 285)])
	func get_buff_target_lane_probe(id: int) -> Dictionary:
		return {"valid": id == 1, "points": points}
	func _draw() -> void:
		draw_polyline(points, Color(0.35, 0.39, 0.47), 10.0, true)
		for i in range(1, points.size()):
			var tangent: Vector2 = (points[i] - points[i - 1]).normalized()
			var normal: Vector2 = tangent.orthogonal()
			for j in range(1, 5):
				var point: Vector2 = points[i - 1].lerp(points[i], float(j) / 5.0)
				draw_polyline(PackedVector2Array([point - tangent * 5.0 + normal * 5.0, point, point - tangent * 5.0 - normal * 5.0]), Color(0.89, 0.67, 0.23, 0.8), 2.0, true)

class Background:
	extends Node2D
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 640), Color(0.035, 0.055, 0.075))
		for x in range(0, 961, 40):
			draw_line(Vector2(x, 0), Vector2(x, 640), Color(0.17, 0.23, 0.28, 0.17), 1.0)
		for y in range(0, 641, 40):
			draw_line(Vector2(0, y), Vector2(960, y), Color(0.17, 0.23, 0.28, 0.17), 1.0)

var _output: String

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_output = OS.get_environment("SF_MENU_CAPTURE_DIR")
	if _output.is_empty():
		push_error("Set SF_MENU_CAPTURE_DIR for the visual review output")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_output.path_join("frames"))
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_root().content_scale_size = Vector2i(WIDTH, HEIGHT)
	get_root().size = Vector2i(WIDTH, HEIGHT)
	DisplayServer.window_set_size(Vector2i(WIDTH, HEIGHT))
	var arena := StudyArena.new()
	get_root().add_child(arena)
	var background := Background.new()
	background.z_index = -100
	arena.add_child(background)
	var lanes := LaneFixture.new()
	lanes.z_index = -5
	arena.add_child(lanes)
	var view := Presentation.new()
	arena.add_child(view)
	view.setup(arena, lanes)
	var hive_texture := load("res://assets/sprites/sf_skin_v1/hive_medium_no_indicators_cropped.png") as Texture2D
	var bee_texture := load("res://assets/sprites/sf_skin_v1/unit_rendered_alpha.png") as Texture2D
	for point: Vector2 in [lanes.points[0], lanes.points[-1]]:
		var hive := Sprite2D.new()
		hive.texture = hive_texture
		hive.position = point
		hive.scale = Vector2.ONE * 110.0 / float(hive_texture.get_width())
		hive.z_index = 1
		arena.add_child(hive)
	var bees: Array[Sprite2D] = []
	for i in range(12):
		var bee := Sprite2D.new()
		bee.texture = bee_texture
		bee.scale = Vector2.ONE * 26.0 / float(bee_texture.get_width())
		bee.modulate = Color(1.0, 0.85, 0.40) if i < 6 else Color(1.0, 0.42, 0.39)
		bee.z_index = 0
		arena.add_child(bee)
		bees.append(bee)
	_label(arena, "FREEZE LANE", Vector2(48, 36), 32)
	_label(arena, "Dramatic frost · readable combat", Vector2(48, 83), 20, Color(0.66, 0.81, 0.9))
	var stage_label: Label = _label(arena, "", Vector2(48, 515), 25)
	_label(arena, "Enemies stop advancing. Your bees keep moving. Combat continues.", Vector2(48, 565), 18, Color(0.73, 0.8, 0.85))
	var total: float = 0.0
	for i in range(1, lanes.points.size()):
		total += lanes.points[i - 1].distance_to(lanes.points[i])
	for frame in range(216):
		var tick: int = frame / 3
		var active: bool = tick >= 6 and tick < 56
		var effect: Dictionary = {"activation_id": "freeze-study", "match_id": "visual-study", "buff_id": "FREEZE_LANE",
			"owner_id": 1, "target_type": "lane", "target_id": 1, "started_tick": 6, "expires_tick": 56, "duration_ticks": 50, "status": "active"}
		view.apply_authoritative_snapshot({"match_id": "visual-study", "tick": tick, "effects": [effect] if active else []})
		view.set_process(false) # The harness advances decorative time explicitly.
		view.set("_subtick", float(frame % 3) / 30.0)
		view.queue_redraw()
		stage_label.text = "Ready" if tick < 6 else ("Freeze!" if tick < 13 else ("Enemy advance frozen" if active else ("Shatter & thaw" if tick < 62 else "Lane clear")))
		var elapsed: float = float(frame) / 30.0
		for i in range(bees.size()):
			var friend: bool = i < 6
			var travel_time: float = elapsed if friend else (0.6 if active else elapsed - (5.0 if tick >= 56 else 0.0))
			var distance: float = fposmod(float(i % 6) * 90.0 + travel_time * 32.0, total - 110.0) + 55.0
			if not friend:
				distance = total - distance
			var sample: Dictionary = Presentation._sample_path(lanes.points, distance)
			var tangent: Vector2 = sample["tangent"]
			bees[i].position = sample["point"] + tangent.orthogonal() * (5.0 if friend else -5.0)
			bees[i].rotation = tangent.angle() + (0.0 if friend else PI)
		await process_frame
		await RenderingServer.frame_post_draw
		var capture: Image = get_root().get_texture().get_image()
		capture.save_png(_output.path_join("frames/%03d.png" % frame))
		if frame in [22, 85, 171, 200]:
			var label: String = {22: "activation", 85: "active", 171: "thaw", 200: "clear"}[frame]
			capture.save_png(_output.path_join(label + ".png"))
	view.clear_presentation()
	arena.queue_free()
	await process_frame
	print("BUFF_FREEZE_VISUAL_HARNESS: PASS 216 frames; production renderer with staged read-only snapshots")
	quit(0)

func _label(parent: Node, text: String, position: Vector2, size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
