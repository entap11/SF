extends SceneTree
## Isolated design study. No production UI or authoritative match state is changed.

const HiveScene := preload("res://scenes/hive/HiveNode.tscn")
const FONT := preload("res://assets/fonts/brand/Iceland/Iceland-Regular.ttf")
const Growth := preload("res://scripts/sim/hive_growth_rules.gd")
const COLORS: Array[Color] = [Color(1.0, 0.82, 0.0), Color(1.0, 0.16, 0.24), Color(0.45, 1.0, 0.24), Color(0.16, 0.46, 1.0)]

class StatusIndicators:
	extends Node2D
	var power: int = 5
	var capacity: int = 1
	var used: int = 0
	var font: Font
	var font_size: int = 72
	func _draw() -> void:
		var width: float = maxf(float(capacity) * 30.0 + 12.0, font.get_string_size(str(power), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12.0)
		draw_string_outline(font, Vector2(-width * 0.5, 7), str(power), HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 3, Color(0.015, 0.02, 0.03, 0.95))
		draw_string(font, Vector2(-width * 0.5, 7), str(power), HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(0.97, 0.98, 1.0))
		for slot in range(capacity):
			var center := Vector2((float(slot) - (float(capacity) - 1.0) * 0.5) * 30.0, 27.0)
			var points := PackedVector2Array()
			for vertex in range(6):
				points.append(center + Vector2.from_angle(PI * 0.5 + TAU * float(vertex) / 6.0) * 12.0)
			if slot >= used:
				draw_colored_polygon(points, Color(0.94, 0.97, 1.0))
			points.append(points[0])
			draw_polyline(points, Color(0.015, 0.02, 0.03, 0.95), 4.5, true)
			draw_polyline(points, Color(0.84, 0.90, 0.96), 1.5, true)

var _hives: Array[Node2D] = []
var _plates: Array[Node2D] = []
var _status: Label
var _owner: int = 1
var _used: int = 0
var _selected: bool = false
var _large_power: int = 35

func _init() -> void:
	call_deferred("run")

func label_at(text: String, rect: Rect2, size: int, color := Color(0.90, 0.94, 0.98)) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	root.add_child(label)
	return label

func run() -> void:
	root.size = Vector2i(1080, 1920)
	RenderingServer.set_default_clear_color(Color(0.065, 0.080, 0.102))
	label_at("HIVE INDICATOR STUDY", Rect2(0, 32, 1080, 70), 52)
	label_at("Existing art · enlarged for comparison", Rect2(0, 105, 1080, 50), 32, Color(0.60, 0.68, 0.76))
	label_at("CURRENT", Rect2(60, 180, 420, 50), 38)
	label_at("NUMBER + LANES", Rect2(600, 180, 420, 50), 38)
	for tier in range(3):
		var y: float = 445 + float(tier) * 465
		label_at(["SMALL · 1 LANE", "MEDIUM · 2 LANES", "LARGE · 3 LANES"][tier], Rect2(0, y + 155, 1080, 55), 32, Color(0.60, 0.68, 0.76))
		for column in range(2):
			var hive: Node2D = HiveScene.instantiate()
			root.add_child(hive)
			hive.position = Vector2(270 + column * 540, y)
			hive.scale = Vector2.ONE * 1.7
			_hives.append(hive)
			if column == 1:
				var plate := StatusIndicators.new()
				plate.font = FONT
				plate.z_index = 100
				hive.add_child(plate)
				_plates.append(plate)
	_status = label_at("", Rect2(25, 1655, 1030, 60), 34)
	label_at("Filled = available    Hollow = occupied", Rect2(25, 1715, 1030, 50), 34)
	label_at("1–4 owner    Space slots    S selection    P large number", Rect2(25, 1790, 1030, 55), 28, Color(0.60, 0.68, 0.76))
	root.window_input.connect(on_input)
	await process_frame
	update_reference()
	if "--capture" in OS.get_cmdline_user_args():
		await capture("01-available")
		_used = 1
		update_reference()
		await capture("02-one-occupied")
		_used = 3
		_selected = true
		update_reference()
		await capture("03-selected-full")
		_owner = 2
		_selected = false
		_large_power = 125
		update_reference()
		await capture("04-red-large-number")
		print("HIVE_INDICATOR_REFERENCE: CAPTURED")
		quit()

func update_reference() -> void:
	for index in range(_hives.size()):
		var tier: int = index / 2
		var power: int = [5, 15, _large_power][tier]
		var capacity: int = Growth.lane_budget_for_power(power)
		var used: int = mini(_used, capacity)
		var hive: Node2D = _hives[index]
		hive.call("apply_render", _owner, power, 27.0, COLORS[_owner - 1], 14, "Hive", used, capacity)
		hive.call("set_selected", _selected, COLORS[_owner - 1])
		if index % 2 == 1:
			var visual: Node2D = hive.get_node("Visual")
			# Hide only presentation layers in this fixture; the live game is untouched.
			visual.get_node("PowerProjection").hide()
			visual.get_node("LaneBudgetIndicators").hide()
			visual.get_node("LanePortLayer").hide()
			var plate: Node2D = _plates[tier]
			var holder: Node2D = visual.get("_power_label_holder")
			var power_label: Label = visual.get("_power_label")
			plate.set("font_size", roundi(float(power_label.label_settings.font_size) * 0.5 * absf(holder.global_scale.x / hive.global_scale.x)))
			var backing: Control = visual.get("_power_backing")
			plate.position = Vector2(0, hive.to_local(backing.get_global_transform().origin).y + 40)
			plate.set("power", power)
			plate.set("capacity", capacity)
			plate.set("used", used)
			plate.queue_redraw()
	_status.text = "Player %d · up to %d occupied · %s" % [_owner, _used, "selected" if _selected else "idle"]

func on_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_owner = event.keycode - KEY_1 + 1
		KEY_SPACE:
			_used = (_used + 1) % 4
		KEY_S:
			_selected = not _selected
		KEY_P:
			_large_power = 125 if _large_power == 35 else 35
		KEY_ESCAPE:
			quit()
	update_reference()

func capture(name: String) -> void:
	var folder: String = OS.get_environment("SF_HIVE_REFERENCE_DIR")
	if folder.is_empty():
		folder = "res://artifacts/hive-indicator-reference"
	DirAccess.make_dir_recursive_absolute(folder)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
