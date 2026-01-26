@tool
extends Node2D

@export var grid_w: int = 8:
	set(value):
		grid_w = max(1, value)
		queue_redraw()
@export var grid_h: int = 12:
	set(value):
		grid_h = max(1, value)
		queue_redraw()
@export var cell_size: Vector2 = Vector2(64, 64):
	set(value):
		cell_size = value
		queue_redraw()
@export var line_color: Color = Color(0.7, 0.7, 0.7, 0.25):
	set(value):
		line_color = value
		queue_redraw()
@export var border_color: Color = Color(0.9, 0.9, 0.9, 0.5):
	set(value):
		border_color = value
		queue_redraw()
@export var origin_color: Color = Color(1.0, 0.35, 0.35, 0.8):
	set(value):
		origin_color = value
		queue_redraw()
@export var draw_origin: bool = true:
	set(value):
		draw_origin = value
		queue_redraw()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var width_px := grid_w * cell_size.x
	var height_px := grid_h * cell_size.y
	for x in range(grid_w + 1):
		var x_pos := x * cell_size.x
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, height_px), line_color, 1.0)
	for y in range(grid_h + 1):
		var y_pos := y * cell_size.y
		draw_line(Vector2(0, y_pos), Vector2(width_px, y_pos), line_color, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(width_px, height_px)), border_color, false, 2.0)
	if draw_origin:
		draw_circle(Vector2(0, 0), 6.0, origin_color)
