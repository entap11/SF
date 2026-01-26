@tool
extends Node

const CONTESTS_DIR := "res://data/contests"

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	var dir := DirAccess.open(CONTESTS_DIR)
	if dir == null:
		push_error("ContestResourceCheck: cannot open %s" % CONTESTS_DIR)
		return
	for file_name in dir.get_files():
		if file_name.ends_with(".tres"):
			var res := load("%s/%s" % [CONTESTS_DIR, file_name])
			assert(res is ContestDef)
