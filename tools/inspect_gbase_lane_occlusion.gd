extends SceneTree

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const GameStateScript := preload("res://scripts/state/game_state.gd")

func _init() -> void:
	await process_frame
	var loaded: Dictionary = MAP_LOADER.load_map("res://maps/nomansland/MAP_nomansland__GBASE__1p.json")
	if not bool(loaded.get("ok", false)):
		push_error("inspect failed: map load")
		quit(1)
		return
	var data: Dictionary = loaded.get("data", {}) as Dictionary
	var state = GameStateScript.new()
	state.load_from_map_dict(data)
	var rows: Array = []
	for a_hive in state.hives:
		for b_hive in state.hives:
			if a_hive == null or b_hive == null:
				continue
			var a_id: int = int(a_hive.id)
			var b_id: int = int(b_hive.id)
			if b_id <= a_id:
				continue
			var can: bool = state.can_connect(a_id, b_id)
			var lane_seg: Dictionary = state._lane_segment_world(a_hive, b_hive)
			var seg_a: Vector2 = lane_seg.get("a", state._hive_world_pos(a_hive))
			var seg_b: Vector2 = lane_seg.get("b", state._hive_world_pos(b_hive))
			var min_dist: float = 999999.0
			var min_hive: int = -1
			for h in state.hives:
				if h == null:
					continue
				var h_id: int = int(h.id)
				if h_id == a_id or h_id == b_id:
					continue
				var ab := seg_b - seg_a
				var t := 0.0
				var denom := ab.length_squared()
				if denom > 0.0:
					t = clampf((state._hive_world_pos(h) - seg_a).dot(ab) / denom, 0.0, 1.0)
				var p := seg_a + ab * t
				var d: float = p.distance_to(state._hive_world_pos(h))
				if d < min_dist:
					min_dist = d
					min_hive = h_id
			rows.append({
				"a": a_id,
				"b": b_id,
				"can": can,
				"min_hive": min_hive,
				"min_dist": min_dist
			})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("min_dist", 0.0)) < float(b.get("min_dist", 0.0))
	)
	for i in range(mini(20, rows.size())):
		print(rows[i])
	quit(0)
