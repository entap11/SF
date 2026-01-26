extends Node2D
class_name LinkNode

@export var a_id: int = 0
@export var b_id: int = 0

func _ready() -> void:
	add_to_group("map_link")
