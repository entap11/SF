extends Control

@onready var map_select: OptionButton = %MapSelect

var maps: Array[String] = []

func _ready() -> void:
	maps = MapCatalog.list_json_maps()
	map_select.clear()
	for m in maps:
		map_select.add_item(m)
	if maps.is_empty():
		map_select.add_item("No maps found")
		map_select.disabled = true
		return
	map_select.disabled = false
	map_select.select(0)

func _on_start_pressed() -> void:
	if maps.is_empty():
		return
	var chosen := map_select.get_item_text(map_select.selected)
	get_node("/root/Gamebot").set_vs(chosen)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
