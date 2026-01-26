extends RefCounted
class_name MapBuilder

const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")

func build_into(arena: Node, map_path: String) -> bool:
	if arena == null:
		push_error("MAPBUILDER: arena is null. map_path=" + map_path)
		return false
	if map_path.strip_edges().is_empty():
		push_error("MAPBUILDER: map_path is empty")
		return false

	var normalized_path := MAP_SCHEMA.normalize_path(map_path)
	if normalized_path != map_path:
		map_path = normalized_path

	if not FileAccess.file_exists(map_path):
		push_error("MAPBUILDER: map file does not exist: " + map_path)
		return false

	var file := FileAccess.open(map_path, FileAccess.READ)
	if file == null:
		push_error("MAPBUILDER: failed to open: " + map_path)
		return false

	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MAPBUILDER: JSON parse failed (not a Dictionary): " + map_path)
		return false

	var human: Dictionary = parsed
	var result: Dictionary = MAP_SCHEMA.build_internal_map(human)
	if not result.get("ok", false):
		push_error("MAPBUILDER: " + str(result.get("error", "unknown error")))
		return false

	var internal: Dictionary = result.get("data", {})
	if internal.is_empty():
		push_error("MAPBUILDER: internal map data is empty")
		return false

	if str(internal.get("id", "")) == "":
		internal["id"] = map_path.get_file().trim_suffix(".json")
	if str(internal.get("name", "")) == "":
		internal["name"] = internal.get("id", "")

	if arena.has_method("load_from_map"):
		arena.call("load_from_map", internal)
		var hr := arena.get_node_or_null("MapRoot/HiveRenderer")
		var lr := arena.get_node_or_null("MapRoot/LaneRenderer")
		if hr != null and hr.has_method("set_model"):
			hr.call("set_model", internal)
		if lr != null and lr.has_method("set_model"):
			lr.call("set_model", internal)
		if lr != null and hr != null and lr.has_method("set_hive_nodes") and hr.has_method("get_hive_nodes_by_id"):
			lr.call("set_hive_nodes", hr.call("get_hive_nodes_by_id"))
		if arena.has_method("set_model"):
			arena.call("set_model", internal)
		print("RENDER MODEL SET: hives=", (internal.get("hives", []) as Array).size(), " lanes=", (internal.get("lanes", []) as Array).size())
		var arena_model: Variant = arena.get("model")
		print("ARENA MODEL TYPE:", typeof(arena_model))
		if typeof(arena_model) == TYPE_DICTIONARY:
			print("ARENA MODEL KEYS:", (arena_model as Dictionary).keys())
			print("ARENA HIVES COUNT:",
				(arena_model.get("hives", []) as Array).size(),
				" NODES COUNT:",
				(arena_model.get("nodes", []) as Array).size()
			)
		print("ARENA render_version:", arena.get("render_version"))
		print("MAPBUILDER: built internal map ", internal.get("id", "UNKNOWN"), " hives=", (internal.get("hives", []) as Array).size())
		return true

	push_error("MAPBUILDER: Arena has no load_from_map(data) method")
	return false
