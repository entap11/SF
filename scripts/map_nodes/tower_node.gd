extends Node2D
class_name TowerNode

@export var tower_id: int = 0
@export var grid_pos: Vector2i = Vector2i.ZERO
@export var required_hive_ids: Array[int] = []

func _ready() -> void:
	add_to_group("map_tower")
