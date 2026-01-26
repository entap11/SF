extends Node

var next_mode: String = ""
var next_map_id: String = ""

func set_vs(map_id: String) -> void:
	next_mode = "VS"
	next_map_id = map_id
