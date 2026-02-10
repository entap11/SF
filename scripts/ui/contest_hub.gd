extends Control
class_name ContestHub
const SFLog := preload("res://scripts/util/sf_log.gd")
const STAGE_RACE_START_PLAYERS := 5

signal closed

@export var contest_id: String = ""

@onready var name_label: Label = $Panel/VBox/Header/Name
@onready var time_label: Label = $Panel/VBox/Header/Time
@onready var cap_label: Label = $Panel/VBox/Header/Cap
@onready var enter_button: Button = $Panel/VBox/Header/Enter
@onready var back_button: Button = $Panel/VBox/Header/Back
@onready var stage_race_summary_label: Label = $Panel/VBox/StageRaceSummary
@onready var stage_race_play_button: Button = $Panel/VBox/StageRaceActions/StageRacePlay
@onready var stage_race_board_button: Button = $Panel/VBox/StageRaceActions/StageRaceBoard
@onready var stage_race_leaders_box: VBoxContainer = $Panel/VBox/StageRaceLeaders
@onready var map_list: VBoxContainer = $Panel/VBox/MapsList
@onready var contest_state := get_node_or_null("/root/ContestState")

var contest: ContestDef

func _ready() -> void:
	enter_button.pressed.connect(_on_enter_pressed)
	back_button.pressed.connect(_on_back_pressed)
	stage_race_play_button.pressed.connect(_on_stage_race_play_pressed)
	stage_race_board_button.pressed.connect(_on_stage_race_board_pressed)
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
	_refresh_stage_race_summary()
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
		score_label.text = "Best: %s" % _format_time_ms(best_score)
		score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var play_button := Button.new()
		play_button.text = "Practice Map"
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

func _on_stage_race_play_pressed() -> void:
	if contest == null or contest_state == null:
		return
	if not contest_state.has_method("build_stage_race_plan"):
		stage_race_summary_label.text = "Stage Race planner unavailable."
		return
	var map_count: int = _stage_race_map_count()
	var plan: Dictionary = contest_state.call("build_stage_race_plan", contest.id, map_count) as Dictionary
	if not bool(plan.get("ok", false)):
		stage_race_summary_label.text = "Stage Race unavailable for this contest."
		return
	var vs_lobby := preload("res://scenes/ui/VsLobby.tscn").instantiate()
	var options: Dictionary = {
		"start_players": STAGE_RACE_START_PLAYERS,
		"window_sec": int(round(float(int(plan.get("time_limit_ms", 0))) / 1000.0)),
		"contest_id": contest.id,
		"contest_scope": contest.scope,
		"map_ids": plan.get("map_ids", PackedStringArray())
	}
	vs_lobby.configure("STAGE_RACE", map_count, contest.price, false, options)
	vs_lobby.closed.connect(func():
		vs_lobby.queue_free()
		visible = true
	)
	add_child(vs_lobby)
	visible = false

func _on_stage_race_board_pressed() -> void:
	if contest == null:
		return
	var panel := preload("res://scenes/ui/StageRaceLeaderboardPanel.tscn").instantiate()
	panel.contest_id = contest.id
	panel.map_ids = contest.map_ids
	panel.closed.connect(func():
		panel.queue_free()
	)
	add_child(panel)

func _refresh_stage_race_summary() -> void:
	if stage_race_summary_label == null or stage_race_leaders_box == null:
		return
	for child in stage_race_leaders_box.get_children():
		child.queue_free()
	if contest == null or contest_state == null:
		stage_race_summary_label.text = "Overall lead: --"
		return
	var map_count: int = _stage_race_map_count()
	var rows: Array = []
	if contest_state.has_method("build_stage_race_overall_leaderboard"):
		rows = contest_state.call("build_stage_race_overall_leaderboard", contest.id, map_count, 5) as Array
	if rows.is_empty():
		stage_race_summary_label.text = "Overall lead: no runs yet."
		return
	var lead: Dictionary = rows[0] as Dictionary
	var required_maps: int = int(lead.get("required_maps", map_count))
	var lead_name: String = str(lead.get("player_name", "Player"))
	var lead_time: int = int(lead.get("aggregate_time_ms", 0))
	var lead_completed: int = int(lead.get("completed_maps", 0))
	stage_race_summary_label.text = "Overall lead (%d maps): %s  %s" % [required_maps, lead_name, _format_time_ms(lead_time)]
	if lead_completed < required_maps:
		stage_race_summary_label.text += "  [%d/%d complete]" % [lead_completed, required_maps]
	for row_v in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v as Dictionary
		var label := Label.new()
		var rank: int = int(row.get("rank", 0))
		var name: String = str(row.get("player_name", "Player"))
		var completed: int = int(row.get("completed_maps", 0))
		var required: int = int(row.get("required_maps", map_count))
		var agg: int = int(row.get("aggregate_time_ms", 0))
		label.text = "%d) %s  %s  [%d/%d]" % [rank, name, _format_time_ms(agg), completed, required]
		stage_race_leaders_box.add_child(label)

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

func _stage_race_map_count() -> int:
	if contest == null:
		return 0
	return maxi(1, contest.map_ids.size())

func _format_time_ms(value: int) -> String:
	var ms: int = maxi(0, value)
	var minutes: int = ms / 60000
	var seconds: int = (ms % 60000) / 1000
	var millis: int = ms % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, millis]
