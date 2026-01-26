class_name HexGrid
extends Control

@export var cell_size: float = 84.0
@export var line_color: Color = Color(0.35, 0.36, 0.4, 0.12)
@export var line_width: float = 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if cell_size <= 0.0:
		return
	var w := cell_size
	var h := cell_size * 0.866
	var x_step := w * 0.75
	var cols := int(ceil(size.x / x_step)) + 1
	var rows := int(ceil(size.y / h)) + 1
	for col in range(cols):
		for row in range(rows):
			var x := col * x_step
			var y := row * h + (col % 2) * h * 0.5
			_draw_hex(Vector2(x, y), w, h)

func _draw_hex(center: Vector2, w: float, h: float) -> void:
	var dx := w * 0.5
	var dy := h * 0.5
	var pts := PackedVector2Array([
		center + Vector2(-dx * 0.5, -dy),
		center + Vector2(dx * 0.5, -dy),
		center + Vector2(dx, 0.0),
		center + Vector2(dx * 0.5, dy),
		center + Vector2(-dx * 0.5, dy),
		center + Vector2(-dx, 0.0)
	])
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, line_color, line_width, true)
