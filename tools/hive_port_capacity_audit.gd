extends SceneTree

const MapLoader := preload("res://scripts/maps/map_loader.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var degree_histogram: Dictionary = {}
	var ranked_maps: Array[Dictionary] = []
	var global_max_degree: int = 0
	var global_max_map: String = ""
	var loaded_count: int = 0
	var failed_count: int = 0
	for path in MapLoader.list_maps():
		var result: Dictionary = MapLoader.load_map(path)
		if not bool(result.get("ok", false)):
			failed_count += 1
			continue
		loaded_count += 1
		var model: Dictionary = result.get("data", {}) as Dictionary
		var degree: Dictionary = {}
		for lane_any in model.get("lane_candidates", []) as Array:
			if typeof(lane_any) != TYPE_DICTIONARY:
				continue
			var lane: Dictionary = lane_any as Dictionary
			var a_id: int = int(lane.get("a_id", lane.get("from", 0)))
			var b_id: int = int(lane.get("b_id", lane.get("to", 0)))
			if a_id <= 0 or b_id <= 0 or a_id == b_id:
				continue
			degree[a_id] = int(degree.get(a_id, 0)) + 1
			degree[b_id] = int(degree.get(b_id, 0)) + 1
		var map_max_degree: int = 0
		for degree_any in degree.values():
			var hive_degree: int = int(degree_any)
			map_max_degree = maxi(map_max_degree, hive_degree)
			degree_histogram[hive_degree] = int(degree_histogram.get(hive_degree, 0)) + 1
		var map_id: String = str(model.get("id", path.get_file().get_basename()))
		ranked_maps.append({"map": map_id, "max_degree": map_max_degree})
		if map_max_degree > global_max_degree:
			global_max_degree = map_max_degree
			global_max_map = map_id
	ranked_maps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_degree: int = int(a.get("max_degree", 0))
		var b_degree: int = int(b.get("max_degree", 0))
		if a_degree != b_degree:
			return a_degree > b_degree
		return str(a.get("map", "")) < str(b.get("map", ""))
	)
	print("HIVE_PORT_CAPACITY_AUDIT maps=%d failed=%d max_degree=%d max_map=%s" % [
		loaded_count,
		failed_count,
		global_max_degree,
		global_max_map
	])
	print("HIVE_PORT_CAPACITY_HISTOGRAM %s" % JSON.stringify(degree_histogram))
	for i in range(mini(12, ranked_maps.size())):
		var entry: Dictionary = ranked_maps[i]
		print("HIVE_PORT_CAPACITY_MAP degree=%d map=%s" % [
			int(entry.get("max_degree", 0)),
			str(entry.get("map", ""))
		])
	quit(0 if failed_count == 0 else 1)
