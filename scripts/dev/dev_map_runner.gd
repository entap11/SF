extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")

var allowed_maps: PackedStringArray = PackedStringArray([
	"res://maps/json/MAP_SKETCH_LR_8x12_v1xy_BARRACKS_1.json",
	"res://maps/json/MAP_TEST_8x12.json",
])

func _ready() -> void:
	var arena: Node2D = _find_arena() as Node2D
	if arena == null:
		if SFLog.LOGGING_ENABLED:
			push_error("DevMapRunner: Arena not found")
		return
	var dml: Node = _find_dev_map_loader()
	if dml != null:
		if dml.has_method("set_arena"):
			dml.call("set_arena", arena)
		elif _has_property(dml, "arena"):
			dml.set("arena", arena)
		if _has_property(dml, "allowed_maps"):
			dml.set("allowed_maps", allowed_maps)
		elif dml.has_method("set_allowed_maps"):
			dml.call("set_allowed_maps", allowed_maps)
		var next_map_id: String = ""
		var gamebot: Node = get_node_or_null("/root/Gamebot")
		if gamebot != null and _has_property(gamebot, "next_map_id"):
			next_map_id = str(gamebot.get("next_map_id"))
		if not next_map_id.is_empty():
			if _has_property(dml, "map_id"):
				dml.set("map_id", next_map_id)
			if dml is CanvasItem:
				(dml as CanvasItem).visible = false
			if dml.has_method("_on_load_pressed"):
				SFLog.info("DEV_MAP_AUTOLOAD", {"map_id": next_map_id})
				dml.call("_on_load_pressed")
				if arena.has_method("start_sim"):
					arena.call("start_sim")
	else:
		if SFLog.LOGGING_ENABLED:
			push_warning("DevMapRunner: DevMapLoader not found")

func _has_property(obj: Object, prop_name: String) -> bool:
	for p in obj.get_property_list():
		if String(p.name) == prop_name:
			return true
	return false

func _find_arena() -> Node:
	var current: Node = get_tree().current_scene
	if current != null:
		var arena: Node = current.get_node_or_null("WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")
		if arena != null:
			return arena
	var a: Node = get_node_or_null("Arena")
	if a != null:
		return a
	return find_child("Arena", true, false)

func _find_dev_map_loader() -> Node:
	var d: Node = get_node_or_null("DevMapLoader")
	if d != null:
		return d
	return find_child("DevMapLoader", true, false)
