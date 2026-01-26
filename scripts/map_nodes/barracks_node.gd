extends Node2D
class_name BarracksNode

@export var barracks_id: int = 0
@export var grid_pos: Vector2i = Vector2i.ZERO
@export var required_hive_ids: Array[int] = []

func _ready() -> void:
	add_to_group("map_barracks")
