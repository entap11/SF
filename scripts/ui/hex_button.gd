class_name HexButton
extends Control

signal pressed

const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")

const CUT_FULL := 0
const CUT_LEFT := 1
const CUT_RIGHT := 2

@export var text: String = "HEX"
@export var sprite_key: String = "":
	set(value):
		_sprite_key = value
		_apply_sprite()
	get:
		return _sprite_key
@export var fill_color: Color = Color(0.12, 0.12, 0.16)
@export var border_color: Color = Color(0.9, 0.7, 0.2)
@export var text_color: Color = Color(0.95, 0.9, 0.75)
@export var border_width: float = 2.0
@export var font: Font
@export var font_size: int = 18
@export var cut_side: int = CUT_FULL

var _is_hovered := false
var _is_pressed := false
var _skin_tex: TextureRect = null
var _sprite_key: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_sprite()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_pressed = true
			queue_redraw()
		else:
			if _is_pressed:
				emit_signal("pressed")
			_is_pressed = false
			queue_redraw()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_is_pressed = true
			queue_redraw()
		else:
			if _is_pressed:
				emit_signal("pressed")
			_is_pressed = false
			queue_redraw()

func _on_mouse_entered() -> void:
	_is_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_is_pressed = false
	queue_redraw()

func _apply_sprite() -> void:
	if _sprite_key.is_empty():
		return
	var registry := SpriteRegistry.get_instance()
	if registry == null:
		return
	var tex: Texture2D = registry.get_tex(_sprite_key)
	if tex == null:
		return
	if _skin_tex == null:
		_skin_tex = TextureRect.new()
		_skin_tex.name = "SkinTex"
		_skin_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_skin_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		_skin_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_skin_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_skin_tex.stretch_mode = TextureRect.STRETCH_SCALE
		_skin_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(_skin_tex)
	_skin_tex.texture = tex
	text = ""
	queue_redraw()

func _draw() -> void:
	if _skin_tex != null:
		return
	var pts := _shape_points(size)
	var fill := fill_color
	if _is_hovered:
		fill = fill.lightened(0.12)
	if _is_pressed:
		fill = fill.lightened(0.2)
	draw_polygon(pts, [fill])
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, border_color, border_width, true)
	if font != null and text != "":
		var min_x := pts[0].x
		var max_x := pts[0].x
		var min_y := pts[0].y
		var max_y := pts[0].y
		for p in pts:
			min_x = min(min_x, p.x)
			max_x = max(max_x, p.x)
			min_y = min(min_y, p.y)
			max_y = max(max_y, p.y)
		var center := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.5 - font_size * 0.15)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

func _shape_points(bounds: Vector2) -> PackedVector2Array:
	var w := bounds.x
	var h := bounds.y
	var dx := w * 0.22
	var cut_x := w * 0.5
	if cut_side == CUT_LEFT:
		var pts := PackedVector2Array([
			Vector2(dx, 0.0),
			Vector2(cut_x, 0.0),
			Vector2(cut_x, h),
			Vector2(dx, h),
			Vector2(0.0, h * 0.5)
		])
		return _offset_points(pts, Vector2(cut_x, 0.0))
	if cut_side == CUT_RIGHT:
		var pts := PackedVector2Array([
			Vector2(cut_x, 0.0),
			Vector2(w - dx, 0.0),
			Vector2(w, h * 0.5),
			Vector2(w - dx, h),
			Vector2(cut_x, h)
		])
		return _offset_points(pts, Vector2(-cut_x, 0.0))
	return PackedVector2Array([
		Vector2(dx, 0.0),
		Vector2(w - dx, 0.0),
		Vector2(w, h * 0.5),
		Vector2(w - dx, h),
		Vector2(dx, h),
		Vector2(0.0, h * 0.5)
	])

func _offset_points(points: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for p in points:
		shifted.append(p + delta)
	return shifted
