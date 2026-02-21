extends RefCounted
class_name MapCatalog

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")

static func list_json_maps() -> Array[String]:
	return MAP_LOADER.list_maps()
