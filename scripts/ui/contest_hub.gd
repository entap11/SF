extends Control
class_name ContestHub
const SFLog := preload("res://scripts/util/sf_log.gd")

signal closed

@export var contest_id: String = ""

@onready var name_label: Label = $Panel/VBox/Header/Name
@onready var time_label: Label = $Panel/VBox/Header/Time
@onready var cap_label: Label = $Panel/VBox/Header/Cap
@onready var enter_button: Button = $Panel/VBox/Header/Enter
@onready var back_button: Button = $Panel/VBox/Header/Back
@onready var map_list: VBoxContainer = $Panel/VBox/MapsList
@onready var contest_state := get_node_or_null("/root/ContestState")

var contest: ContestDef

func _ready() -> void:
	enter_button.pressed.connect(_on_enter_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_load_contest()
	_refresh()

func _load_contest() -> void:
	if contest_state == null:
		contest = null
		return
	contest = contest_state.get_contest(contest_id)

func _refresh() -> void:
	if contest == null:
		name_label.text = "Contest"
		time_label.text = ""
		cap_label.text = ""
		enter_button.visible = false
		return
	name_label.text = contest.name
	time_label.text = _format_remaining(contest.end_ts)
	cap_label.text = _cap_text(contest.buff_cap_per_map)
	if contest_state != null:
		enter_button.visible = not contest_state.is_entered(contest.id)
	else:
		enter_button.visible = false
	_build_maps()

func _build_maps() -> void:
	for child in map_list.get_children():
		child.queue_free()
	if contest == null:
		return
	for map_id in contest.map_ids:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var map_button := Button.new()
		map_button.text = map_id
		map_button.pressed.connect(func(): _open_leaderboard(map_id))
		var score_label := Label.new()
		var best_score := 0
		if contest_state != null:
			best_score = contest_state.get_best_score(contest.id, map_id)
		score_label.text = "Best: %d" % best_score
		score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var play_button := Button.new()
		play_button.text = "Play Map"
		play_button.pressed.connect(func(): _on_play_map(map_id))
		row.add_child(map_button)
		row.add_child(score_label)
		row.add_child(play_button)
		map_list.add_child(row)

func _on_enter_pressed() -> void:
	if contest == null:
		return
	if contest_state == null:
		return
	contest_state.enter_contest(contest.id)
	_refresh()

func _on_play_map(map_id: String) -> void:
	if contest == null:
		return
	if contest_state == null:
		return
	var context: Dictionary = contest_state.build_run_context(contest.id, map_id)
	if not context.is_empty():
		if SFLog.LOGGING_ENABLED:
			print("TP RUN", context)

func _open_leaderboard(map_id: String) -> void:
	if contest == null:
		return
	var panel := preload("res://scenes/ui/MapLeaderboardPanel.tscn").instantiate()
	panel.contest_id = contest.id
	panel.map_id = map_id
	panel.closed.connect(func(): panel.queue_free())
	add_child(panel)

func _on_back_pressed() -> void:
	closed.emit()

func _cap_text(cap: int) -> String:
	if cap < 0:
		return "Unlimited buffs"
	if cap == 1:
		return "1 buff/map"
	return "%d buffs/map" % cap

func _format_remaining(end_ts: int) -> String:
	if end_ts <= 0:
		return "No end"
	var now: int = int(Time.get_unix_time_from_system())
	var remaining: int = int(max(0, end_ts - now))
	var hours: int = remaining / 3600
	var mins: int = (remaining % 3600) / 60
	return "Remaining %02dh%02dm" % [hours, mins]
