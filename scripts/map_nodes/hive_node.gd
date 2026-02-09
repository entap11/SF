extends Node2D
class_name HiveNode

@export var hive_id: int = 0
@export var grid_pos: Vector2i = Vector2i.ZERO
@export_enum("Neutral:0", "P1 Yellow:1", "P2 Red:2", "P3 Green:3", "P4 Blue:4")
var owner_id: int = 0

func _ready() -> void:
	add_to_group("map_hive")
