class_name ShellMvpMapUtils
extends RefCounted

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")

func list_json_maps() -> Array[String]:
	return MAP_LOADER.list_maps()
