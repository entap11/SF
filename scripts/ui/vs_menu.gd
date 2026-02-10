extends Control

@onready var map_select: OptionButton = %MapSelect
@onready var team_mode_button: Button = %TeamMode

var maps: Array[String] = []
var _team_mode: String = "2v2"

func _ready() -> void:
	maps = MapCatalog.list_json_maps()
	map_select.clear()
	for m in maps:
		map_select.add_item(m)
	if maps.is_empty():
		map_select.add_item("No maps found")
		map_select.disabled = true
	else:
		map_select.disabled = false
		map_select.select(0)
	_init_team_mode()
	if team_mode_button != null and not team_mode_button.pressed.is_connected(_on_team_mode_pressed):
		team_mode_button.pressed.connect(_on_team_mode_pressed)

func _on_start_pressed() -> void:
	if maps.is_empty():
		return
	var chosen := map_select.get_item_text(map_select.selected)
	get_node("/root/Gamebot").set_vs(chosen)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _init_team_mode() -> void:
	var mode_from_ops: String = "2v2"
	if OpsState.has_method("get_team_mode_override"):
		mode_from_ops = str(OpsState.call("get_team_mode_override")).strip_edges().to_lower()
	_set_team_mode(mode_from_ops)

func _on_team_mode_pressed() -> void:
	var next_mode: String = "ffa" if _team_mode == "2v2" else "2v2"
	_set_team_mode(next_mode)

func _set_team_mode(mode: String) -> void:
	var normalized: String = str(mode).strip_edges().to_lower()
	if normalized != "ffa":
		normalized = "2v2"
	_team_mode = normalized
	if team_mode_button != null:
		team_mode_button.text = "Mode: FFA" if _team_mode == "ffa" else "Mode: 2v2"
	if OpsState.has_method("set_team_mode_override"):
		OpsState.call("set_team_mode_override", _team_mode)
