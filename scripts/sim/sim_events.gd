extends Node

signal tower_fire(tower_id: int, owner_id: int, tier: int, tower_pos: Vector2, target_unit_id: int, target_pos: Vector2)
signal tower_hit(tower_id: int, owner_id: int, tier: int, tower_pos: Vector2, target_unit_id: int, hit_pos: Vector2)
signal hive_kind_changed(hive_id: int, owner_id: int, world_pos: Vector2, prev_kind: String, next_kind: String)

func _ready() -> void:
	add_to_group("sim_events")
