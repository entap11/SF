class_name ShellMvpMapUtils
extends RefCounted

func list_json_maps() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://maps/json")
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		if not name.to_lower().ends_with(".json"):
			continue
		out.append("res://maps/json/%s" % name)
	dir.list_dir_end()
	out.sort()
	return out
