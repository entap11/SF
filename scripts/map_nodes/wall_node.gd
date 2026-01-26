@tool
extends Node2D
class_name WallNode

@export var grid_pos: Vector2i = Vector2i.ZERO
@export var size: Vector2 = Vector2(64, 12):
	set(value):
		size = value
		queue_redraw()
@export var color: Color = Color(0.1, 0.1, 0.1, 0.9):
	set(value):
		color = value
		queue_redraw()
@export var centered: bool = true:
	set(value):
		centered = value
		queue_redraw()

func _ready() -> void:
	add_to_group("map_wall")
	queue_redraw()

func _draw() -> void:
	var offset := -size * 0.5 if centered else Vector2.ZERO
	draw_rect(Rect2(offset, size), color, true)
