extends SceneTree

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")

func _init() -> void:
	await process_frame

	var map_paths: Array[String] = MAP_LOADER.list_maps()
	if map_paths.is_empty():
		_fail("no maps discovered; check registry filters and sandbox settings")
		return

	var failures: Array[String] = []
	var summaries: Array[String] = []
	for path in map_paths:
		var loaded: Dictionary = MAP_LOADER.load_map(path)
		if not bool(loaded.get("ok", false)):
			failures.append("%s :: %s" % [path, str(loaded.get("err", "unknown_error"))])
			continue
		var data: Dictionary = loaded.get("data", {}) as Dictionary
		var hives: int = (data.get("hives", []) as Array).size()
		var lanes: int = (data.get("lanes", []) as Array).size()
		summaries.append("%s hives=%d lanes=%d" % [path.get_file(), hives, lanes])

	if not failures.is_empty():
		for failure in failures:
			push_error("MAP_CATALOG_SMOKE: %s" % failure)
		push_error("MAP_CATALOG_SMOKE: %d/%d map(s) failed" % [failures.size(), map_paths.size()])
		quit(1)
		return

	print("MAP_CATALOG_SMOKE: PASS maps=%d" % map_paths.size())
	for summary in summaries:
		print("MAP_CATALOG_SMOKE: %s" % summary)
	quit(0)

func _fail(message: String) -> void:
	push_error("MAP_CATALOG_SMOKE: %s" % message)
	quit(1)
