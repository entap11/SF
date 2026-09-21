extends SceneTree
const Layout = preload("res://scripts/maps/map_layout_contract.gd")
const Compiler = preload("res://tools/map_sketch_compile.gd")
const Renderer = preload("res://scripts/renderers/wall_renderer.gd")
const LegacySegment = preload("res://scenes/renderers/WallGrowthBarrierSegment.tscn")

class Board extends Node2D:
	var hives: Array = []
	var overlay := false
	var barriers: Array = []
	func _draw() -> void:
		draw_rect(Rect2(-32, -32, 1152, 1792), Color("242e3a"))
		for x in range(19): draw_line(Vector2(x * 64 - 32, -32), Vector2(x * 64 - 32, 1760), Color(0.42, 0.52, 0.65, 0.07), 1)
		for y in range(29): draw_line(Vector2(-32, y * 64 - 32), Vector2(1120, y * 64 - 32), Color(0.42, 0.52, 0.65, 0.07), 1)

class Hives extends Node2D:
	var data: Array = []
	var barriers: Array = []
	var overlay := false
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for hive in data:
			var p: Vector2 = hive.pos * 64
			var c: Color = [Color("738497"), Color("e9b852"), Color("ec757a"), Color("71aef2"), Color("8ac997")][clampi(hive.owner, 0, 4)]
			draw_circle(p + Vector2(5, 7), 25, Color(0.02, 0.025, 0.035, 0.45))
			var polygon := PackedVector2Array()
			for i in range(6): polygon.append(p + Vector2.from_angle(PI / 6 + i * TAU / 6) * 23)
			draw_colored_polygon(polygon, c.darkened(0.65))
			polygon.append(polygon[0])
			draw_polyline(polygon, c, 2.5, true)
			draw_circle(p, 11, c.darkened(0.18))
			if hive.owner > 0: draw_string(font, p + Vector2(-15, -33), "P%d" % hive.owner, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, c)
		if overlay:
			for segment in barriers: draw_line(segment.a, segment.b, Color("f4b959"), 3, true)

func _init() -> void: call_deferred("_run")

func _label(text: String, p: Vector2, font_size: int, color: Color = Color("dfe7f0")) -> void:
	var label := Label.new()
	label.text = text
	label.position = p
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	root.add_child(label)

func _run() -> void:
	root.title = "Swarmfront — Wall authoring comparison"
	root.size = Vector2i(1320, 920)
	root.content_scale_size = Vector2i(1320, 920)
	root.transparent_bg = false
	RenderingServer.set_default_clear_color(Color("111722"))
	_label("SWARMFRONT   /   WALL AUTHORING PILOT", Vector2(28, 18), 26)
	_label("Actual Godot wall rendering · hive markers are schematic · existing references remain unchanged", Vector2(28, 54), 15, Color("9baac0"))
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/_future/rink_rat/MAP_rink_rat__SBASE__4p.json"))
	var draft: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://map_sources/rink_rat_symmetry.draft.json"))
	var pilot: Dictionary = Compiler.compile(draft).data
	for index in range(3):
		var x := 28.0 + index * 436
		_label(["01  ORIGINAL SEGMENTS", "02  CONTINUOUS WALLS", "03  SYMMETRIC PILOT"][index], Vector2(x, 98), 18)
		_label(["28 separate wall pieces", "Same barriers · four connected structures", "One sector · four equivalent corner starts"][index], Vector2(x, 126), 13, Color("9baac0"))
		var source: Dictionary = pilot if index == 2 else original
		var board := Board.new()
		board.position = Vector2(x + 12, 181)
		board.scale = Vector2.ONE * 0.35
		board.z_index = -20
		root.add_child(board)
		var wall_root := Node2D.new()
		wall_root.position = board.position
		wall_root.scale = board.scale
		root.add_child(wall_root)
		var segments: Array = []
		for segment in Layout.walls(source): segments.append({"a": segment.a * 64, "b": segment.b * 64})
		if index == 0:
			for segment in segments:
				var piece := LegacySegment.instantiate()
				wall_root.add_child(piece)
				piece.set_segment(segment.a, segment.b)
		else:
			var renderer := Renderer.new()
			wall_root.add_child(renderer)
			renderer.set_wall_segments(segments)
		var hives := Hives.new()
		hives.position = board.position
		hives.scale = board.scale
		hives.data = Layout.hive_entries(source)
		hives.barriers = segments
		hives.overlay = OS.get_environment("SF_MAP_BARRIER_OVERLAY") == "1"
		hives.z_index = 10
		root.add_child(hives)
		_label(["Reference: unequal top/side starting positions", "Visual change only: no gameplay geometry moved", "Cleaned curves and new starting ownership"][index], Vector2(x, 826), 12, Color("abb8ca"))
	_label("Authoring preview · sandbox only · compare finished walls with the exact barrier overlay before promotion", Vector2(28, 878), 14, Color("bda773"))
	var output: String = OS.get_environment("SF_MAP_AUTHORING_CAPTURE_DIR")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		print("MAP_WALL_PREVIEW: scene ready")
		for frame in range(10): await process_frame
		RenderingServer.force_draw(false)
		var name := "wall-comparison-barriers.png" if OS.get_environment("SF_MAP_BARRIER_OVERLAY") == "1" else "wall-comparison.png"
		root.get_texture().get_image().save_png(output.path_join(name))
		print("MAP_WALL_PREVIEW: saved " + name)
		quit()
