class_name DevMapPicker
extends Control
const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")

@onready var map_select: OptionButton = $Panel/VBox/MapSelect
@onready var output_label: Label = $Panel/VBox/Output
@onready var load_button: Button = $Panel/VBox/Buttons/Load
@onready var start_button: Button = $Panel/VBox/Buttons/Start

var map_paths: Array[String] = []
var last_valid_data: Dictionary = {}

func _ready() -> void:
	_refresh_list()
	map_select.item_selected.connect(_on_map_selected)
	load_button.pressed.connect(_on_load_pressed)
	start_button.pressed.connect(_on_start_pressed)
	if map_paths.size() > 0:
		_on_map_selected(0)
	else:
		_output_error(["No maps found"])

func _refresh_list() -> void:
	map_select.clear()
	map_paths = MAP_LOADER.list_maps()
	map_paths.sort()
	for path in map_paths:
		map_select.add_item(path.get_file())

func _on_map_selected(index: int) -> void:
	last_valid_data = {}
	if index < 0 or index >= map_paths.size():
		_output_error(["Invalid selection"])
		return
	_output_info(["Selected: %s" % map_paths[index]])

func _on_load_pressed() -> void:
	var result: Dictionary = _load_selected_map()
	if not result.get("ok", false):
		_output_error([result.get("error", "Unknown error")])
		return
	last_valid_data = result.get("data", {})
	var arena := _ensure_arena()
	if arena == null:
		_output_error(["Arena not found."])
		return
	arena.call("load_from_map", last_valid_data)
	var index := map_select.selected
	var label := map_paths[index].get_file() if index >= 0 and index < map_paths.size() else "unknown"
	_output_info(["Loaded: %s" % label])

func _on_start_pressed() -> void:
	_output_error(["Start disabled: use DevMapLoader Start instead."])

func _load_selected_map() -> Dictionary:
	if map_paths.is_empty():
		return {"ok": false, "error": "No maps available"}
	var index := map_select.selected
	if index < 0 or index >= map_paths.size():
		return {"ok": false, "error": "Invalid selection"}
	var path := map_paths[index]
	var result: Dictionary = MAP_LOADER.load_map(path)
	if not bool(result.get("ok", false)):
		return {"ok": false, "error": str(result.get("err", "Invalid map"))}
	return {"ok": true, "data": result.get("data", {})}

func _ensure_arena() -> Node:
	var current := get_tree().current_scene
	if current != null:
		var arena_existing: Node = current.get_node_or_null("WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")
		if arena_existing != null:
			return arena_existing
	var main_scene_res := load("res://scenes/Main.tscn") as PackedScene
	if main_scene_res == null:
		if SFLog.LOGGING_ENABLED:
			push_error("DEV_MAP_PICKER: failed to load Main.tscn")
		return null
	var main_scene: Node = main_scene_res.instantiate()
	get_tree().root.add_child(main_scene)
	get_tree().current_scene = main_scene
	return main_scene.get_node_or_null("WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")

func _output_info(lines: Array) -> void:
	output_label.text = "\n".join(lines)

func _output_error(lines: Array) -> void:
	var prefixed: Array = []
	for line in lines:
		prefixed.append("ERR: %s" % line)
	output_label.text = "\n".join(prefixed)
