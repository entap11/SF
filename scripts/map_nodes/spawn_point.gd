extends Node2D
class_name SpawnPoint

@export var spawn_id: int = 0
@export var team_id: int = 0
@export var grid_pos: Vector2i = Vector2i.ZERO

func _ready() -> void:
	add_to_group("map_spawn")
