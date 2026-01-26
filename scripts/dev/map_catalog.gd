extends RefCounted
class_name MapCatalog

const MAP_DIR := "res://maps/json"

static func list_json_maps() -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(MAP_DIR)
	if da == null:
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
		out.append(p)

	out.sort()
	return out
