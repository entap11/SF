extends Node2D
class_name TowerNode

const SFLog = preload("res://scripts/util/sf_log.gd")

@export var tower_id: int = 0
@export var grid_pos: Vector2i = Vector2i.ZERO
@export var required_hive_ids: Array[int] = []

func _ready() -> void:
	add_to_group("map_tower")
	add_to_group("sf_tower")
	if OS.is_debug_build():
		SFLog.info("TOWER_NODE_READY", {"id": tower_id, "path": str(get_path())})
