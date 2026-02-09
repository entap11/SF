extends RefCounted
class_name MapCatalog
const SFLog := preload("res://scripts/util/sf_log.gd")

const MAP_DIR := "res://maps/json"
const REQUIRED_SCHEMA := "swarmfront.map.v1.xy"
const CANON_GRID_W := 8
const CANON_GRID_H := 12

static func list_json_maps() -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(MAP_DIR)
	if da == null:
		if SFLog.LOGGING_ENABLED:
			push_warning("MAP_CATALOG: could not open dir: %s" % MAP_DIR)
		return out

	da.list_dir_begin()
	var paths: Array[String] = []
	while true:
		var f := da.get_next()
		if f == "":
			break
		if da.current_is_dir():
			continue
		if f.to_lower().ends_with(".json"):
			paths.append(MAP_DIR + "/" + f)
	da.list_dir_end()

	for p in paths:
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var txt := f.get_as_text().strip_edges()
		if txt.length() < 2:
			continue
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var map_d: Dictionary = parsed as Dictionary
		if not _is_supported_map(map_d):
			continue
		out.append(p)

	out.sort()
	return out

static func _is_supported_map(map_d: Dictionary) -> bool:
	var schema: String = str(map_d.get("_schema", ""))
	if schema != REQUIRED_SCHEMA:
		return false
	var w: int = int(map_d.get("width", map_d.get("grid_width", 0)))
	var h: int = int(map_d.get("height", map_d.get("grid_height", 0)))
	return w == CANON_GRID_W and h == CANON_GRID_H
