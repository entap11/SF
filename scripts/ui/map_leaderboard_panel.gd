extends Control
class_name MapLeaderboardPanel
const SFLog := preload("res://scripts/util/sf_log.gd")

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
	var entries: Array = []
	if contest_state.has_method("get_stage_race_map_leaderboard"):
		entries = contest_state.call("get_stage_race_map_leaderboard", contest_id, map_id, 25) as Array
	else:
		entries = contest_state.get_leaderboard_entries(contest_id, map_id)
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
			var time_ms := _entry_time_ms(entry)
			row.text = "%d. %s  %s  %s" % [rank, name, hive, _format_time_ms(time_ms)]
			list_box.add_child(row)
	pinned_label.text = "Your best: %s" % _format_time_ms(contest_state.get_best_score(contest_id, map_id))

func _on_play_pressed() -> void:
	if contest_state == null:
		return
	var context: Dictionary = contest_state.build_run_context(contest_id, map_id)
	if not context.is_empty():
		if SFLog.LOGGING_ENABLED:
			print("TP RUN", context)

func _on_back_pressed() -> void:
	closed.emit()

func _entry_time_ms(entry: Dictionary) -> int:
	if entry.has("time_ms"):
		return maxi(0, int(entry.get("time_ms", 0)))
	if entry.has("best_time_ms"):
		return maxi(0, int(entry.get("best_time_ms", 0)))
	return maxi(0, int(entry.get("best_score", 0)))

func _format_time_ms(value: int) -> String:
	var ms: int = maxi(0, value)
	var minutes: int = ms / 60000
	var seconds: int = (ms % 60000) / 1000
	var millis: int = ms % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, millis]
