extends Control

@onready var map_select: OptionButton = %MapSelect

# Keep this simple: hardcode a few maps first (you can replace with Directory scan later)
var maps := [
	"res://maps/json/MAP_TEST_8x12.json",
	"res://maps/json/MAP_SKETCH_SYM_8x12.json"
]

func _ready() -> void:
	map_select.clear()
	for m in maps:
		map_select.add_item(m)
	map_select.select(0)

func _on_start_pressed() -> void:
	var chosen := map_select.get_item_text(map_select.selected)
	get_node("/root/Gamebot").set_vs(chosen)
	get_tree().change_scene_to_file("res://scenes/dev/DevMapRunner.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
