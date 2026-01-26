extends Control
class_name MapLeaderboardPanel

signal closed

@export var contest_id: String = ""
@export var map_id: String = ""

@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var list_box: VBoxContainer = $Panel/VBox/Scroll/Entries
@onready var pinned_label: Label = $Panel/VBox/Pinned
@onready var play_button: Button = $Panel/VBox/Buttons/Play
@onready var back_button: Button = $Panel/VBox/Buttons/Back
@onready var contest_state := get_node_or_null("/root/ContestState")

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	play_button.pressed.connect(_on_play_pressed)
	_refresh()

func _refresh() -> void:
	title_label.text = "Leaderboard: %s" % map_id
	for child in list_box.get_children():
		child.queue_free()
	if contest_state == null:
		return
	var entries: Array = contest_state.get_leaderboard_entries(contest_id, map_id)
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No entries yet."
		list_box.add_child(empty_label)
	else:
		for entry in entries:
			var row := Label.new()
			var rank := int(entry.get("rank", 0))
			var name := str(entry.get("player_name", "Player"))
			var hive := str(entry.get("hive_name", ""))
			var score := int(entry.get("best_score", 0))
			row.text = "%d. %s  %s  %d" % [rank, name, hive, score]
			list_box.add_child(row)
	pinned_label.text = "Your best: %d" % contest_state.get_best_score(contest_id, map_id)

func _on_play_pressed() -> void:
	if contest_state == null:
		return
	var context: Dictionary = contest_state.build_run_context(contest_id, map_id)
	if not context.is_empty():
		print("TP RUN", context)

func _on_back_pressed() -> void:
	closed.emit()
