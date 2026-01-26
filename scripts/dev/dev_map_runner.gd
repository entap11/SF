extends Node

var allowed_maps: PackedStringArray = PackedStringArray([
	"res://maps/json/MAP_SKETCH_LR_8x12_v1xy_TOWER_1.json",
	"res://maps/json/MAP_TEST_8x12.json",
])

func _ready() -> void:
	var arena: Node2D = _find_arena() as Node2D
	if arena == null:
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
	else:
		push_warning("DevMapRunner: DevMapLoader not found")

func _has_property(obj: Object, prop_name: String) -> bool:
	for p in obj.get_property_list():
		if String(p.name) == prop_name:
			return true
	return false

func _find_arena() -> Node:
	var a: Node = get_node_or_null("Arena")
	if a != null:
		return a
	return find_child("Arena", true, false)

func _find_dev_map_loader() -> Node:
	var d: Node = get_node_or_null("DevMapLoader")
	if d != null:
		return d
	return find_child("DevMapLoader", true, false)
