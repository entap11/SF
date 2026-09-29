extends ArenaAPI
## Use deterministic hive picking without a renderer/physics world in pointer tests.

func pick_hive_id_local(local_pos: Vector2) -> int:
	for hive in get_state().hives:
		if local_pos.distance_to(grid_to_world(hive.grid_pos)) <= get_hive_pick_radius_px(hive.id):
			return hive.id
	return -1
