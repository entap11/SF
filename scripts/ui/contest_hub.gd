extends Control
class_name ContestHub
const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")
const UITypography := preload("res://scripts/ui/ui_typography.gd")
const AsyncContestConfigStoreScript := preload("res://scripts/state/async_contest_config_store.gd")
const STAGE_RACE_START_PLAYERS := 5
const STAGE_RACE_SUPPORTED_MAP_COUNTS: Array[int] = [3, 5]

signal closed

@export var contest_id: String = ""
@export var stage_race_map_count: int = 0

@onready var root_panel: Panel = $Panel
@onready var root_vbox: VBoxContainer = $Panel/VBox
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
var _font_regular: Font = null
var _font_semibold: Font = null
var _async_contest_config_store: RefCounted = AsyncContestConfigStoreScript.new()

func configure_stage_race_map_count(map_count: int) -> void:
	stage_race_map_count = map_count
	if is_node_ready():
		_update_stage_race_play_state()
		_refresh_stage_race_summary()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_fonts()
	_apply_layout()
	_apply_static_style()
	enter_button.pressed.connect(_on_enter_pressed)
	back_button.pressed.connect(_on_back_pressed)
	stage_race_play_button.pressed.connect(_on_stage_race_play_pressed)
	stage_race_board_button.pressed.connect(_on_stage_race_board_pressed)
	_load_contest()
	_refresh()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_layout):
		get_viewport().size_changed.connect(_apply_layout)

func _load_fonts() -> void:
	_font_regular = UITypography.regular_font()
	_font_semibold = UITypography.semibold_font()

func _apply_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	if root_panel != null:
		root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		root_panel.offset_left = 0.0
		root_panel.offset_top = 0.0
		root_panel.offset_right = 0.0
		root_panel.offset_bottom = 0.0
	if root_vbox != null:
		root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		var viewport_h: float = get_viewport_rect().size.y
		root_vbox.offset_left = 28.0
		root_vbox.offset_top = maxf(76.0, viewport_h * 0.075)
		root_vbox.offset_right = -28.0
		root_vbox.offset_bottom = -32.0

func _apply_static_style() -> void:
	_style_panel(root_panel, Color(0.03, 0.035, 0.045, 0.97), Color(0.74, 0.58, 0.22, 0.65), 0.0)
	if root_vbox != null:
		root_vbox.add_theme_constant_override("separation", 18)
	for label in [name_label, time_label, cap_label, stage_race_summary_label]:
		if label != null:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(name_label, _font_semibold, 30)
	_apply_font(time_label, _font_regular, 18)
	_apply_font(cap_label, _font_regular, 18)
	_apply_font(stage_race_summary_label, _font_semibold, 22)
	stage_race_summary_label.custom_minimum_size = Vector2(0.0, 58.0)
	if name_label != null:
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for button in [enter_button, back_button, stage_race_play_button, stage_race_board_button]:
		if button != null:
			button.custom_minimum_size = Vector2(190.0, 58.0)
			_apply_font(button, _font_semibold, 17)
	_style_button(enter_button, Color(0.18, 0.15, 0.07), Color(0.86, 0.68, 0.22), Color(1.0, 0.92, 0.58))
	_style_button(back_button, Color(0.12, 0.13, 0.16), Color(0.48, 0.50, 0.60), Color(0.92, 0.92, 0.92))
	_style_button(stage_race_play_button, Color(0.18, 0.15, 0.07), Color(0.86, 0.68, 0.22), Color(1.0, 0.92, 0.58))
	_style_button(stage_race_board_button, Color(0.10, 0.11, 0.14), Color(0.44, 0.46, 0.56), Color(0.92, 0.92, 0.92))
	if back_button != null:
		back_button.text = "BACK"
	if stage_race_play_button != null:
		stage_race_play_button.text = "START STAGE RACE"
	if stage_race_board_button != null:
		stage_race_board_button.text = "OVERALL BOARD"
	if stage_race_leaders_box != null:
		stage_race_leaders_box.add_theme_constant_override("separation", 8)
	if map_list != null:
		map_list.add_theme_constant_override("separation", 10)

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
		stage_race_play_button.disabled = true
		return
	name_label.text = contest.name.replace("Time Puzzle", "Stage Race")
	time_label.text = _format_remaining(contest.end_ts)
	cap_label.text = _cap_text(contest.buff_cap_per_map)
	if contest_state != null:
		var preview: Dictionary = contest_state.preview_entry_requirements(contest.id) as Dictionary if contest_state.has_method("preview_entry_requirements") else {}
		var entered: bool = contest_state.is_entered(contest.id)
		enter_button.visible = not entered
		if bool(preview.get("requires_access_ticket", false)):
			enter_button.text = "Enter (%d Ticket%s)" % [
				int(preview.get("access_ticket_cost", 0)),
				"" if int(preview.get("access_ticket_cost", 0)) == 1 else "s"
			]
		else:
			enter_button.text = "Enter"
	else:
		enter_button.visible = false
	_update_stage_race_play_state()
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
		row.add_theme_constant_override("separation", 10)
		var map_button := Button.new()
		map_button.text = MAP_REGISTRY.public_map_display_name_for_id(map_id)
		map_button.custom_minimum_size = Vector2(260.0, 52.0)
		_apply_font(map_button, _font_regular, 17)
		_style_button(map_button, Color(0.08, 0.09, 0.12), Color(0.40, 0.42, 0.52), Color(0.92, 0.92, 0.92))
		map_button.pressed.connect(func(): _open_leaderboard(map_id))
		var score_label := Label.new()
		var best_score := 0
		if contest_state != null:
			best_score = contest_state.get_best_score(contest.id, map_id)
		score_label.text = "Best: %s" % _format_time_ms(best_score)
		score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_apply_font(score_label, _font_regular, 17)
		var play_button := Button.new()
		play_button.text = "Practice Map"
		play_button.custom_minimum_size = Vector2(180.0, 52.0)
		_apply_font(play_button, _font_regular, 16)
		_style_button(play_button, Color(0.10, 0.11, 0.14), Color(0.44, 0.46, 0.56), Color(0.92, 0.92, 0.92))
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
	if contest_state.has_method("intent_enter_contest"):
		contest_state.call("intent_enter_contest", contest.id, {"source": "contest_hub"})
	else:
		contest_state.enter_contest(contest.id)
	_refresh()

func _update_stage_race_play_state() -> void:
	if stage_race_play_button == null:
		return
	var entered: bool = false
	if contest != null and contest_state != null:
		entered = contest_state.is_entered(contest.id)
	stage_race_play_button.disabled = contest == null
	var map_count: int = _stage_race_map_count()
	stage_race_play_button.text = "START %d MAPS" % map_count if entered else "ENTER & START %d MAPS" % map_count
	if stage_race_board_button != null:
		stage_race_board_button.text = "%d MAP BOARD" % map_count

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
	if contest_state.has_method("preview_entry_requirements"):
		var preview: Dictionary = contest_state.call("preview_entry_requirements", contest.id) as Dictionary
		if not bool(preview.get("already_entered", false)):
			_on_enter_pressed()
			var refreshed_preview: Dictionary = contest_state.call("preview_entry_requirements", contest.id) as Dictionary
			if not bool(refreshed_preview.get("already_entered", false)):
				stage_race_summary_label.text = "Entry is required before this Stage Race can start."
				_update_stage_race_play_state()
				return
	if not contest_state.has_method("build_stage_race_plan"):
		stage_race_summary_label.text = "Stage Race planner unavailable."
		return
	var map_count: int = _stage_race_map_count()
	var plan: Dictionary = contest_state.call("build_stage_race_plan", contest.id, map_count) as Dictionary
	if not bool(plan.get("ok", false)):
		stage_race_summary_label.text = "Stage Race unavailable for this contest."
		return
	var vs_lobby_scene: PackedScene = load("res://scenes/ui/VsLobby.tscn") as PackedScene
	if vs_lobby_scene == null:
		stage_race_summary_label.text = "Stage Race lobby unavailable."
		return
	var vs_lobby := vs_lobby_scene.instantiate()
	var options: Dictionary = {
		"start_players": STAGE_RACE_START_PLAYERS,
		"window_sec": int(round(float(int(plan.get("time_limit_ms", 0))) / 1000.0)),
		"contest_id": contest.id,
		"contest_scope": contest.scope,
		"map_ids": plan.get("map_ids", PackedStringArray())
	}
	var dash_options: Dictionary = _async_contest_config_store.launch_options(str(contest.scope), map_count)
	for key in dash_options.keys():
		options[key] = dash_options[key]
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
	panel.map_ids = _stage_race_map_ids()
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
		_apply_font(label, _font_regular, 17)
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
	if STAGE_RACE_SUPPORTED_MAP_COUNTS.has(stage_race_map_count) and contest.map_ids.size() >= stage_race_map_count:
		return stage_race_map_count
	if contest.map_ids.size() >= 5:
		return 5
	if contest.map_ids.size() >= 3:
		return 3
	return maxi(1, contest.map_ids.size())

func _stage_race_map_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if contest == null:
		return out
	var count: int = mini(_stage_race_map_count(), contest.map_ids.size())
	for i in range(count):
		out.append(contest.map_ids[i])
	return out

func _format_time_ms(value: int) -> String:
	var ms: int = maxi(0, value)
	var minutes: int = ms / 60000
	var seconds: int = (ms % 60000) / 1000
	var millis: int = ms % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, millis]

func _apply_font(control: Control, font: Font, size: int) -> void:
	if control == null:
		return
	if font != null:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", size)

func _style_button(button: Button, bg: Color, border: Color, font_color: Color) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.08)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.10)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.08))
	button.add_theme_color_override("font_pressed_color", font_color.darkened(0.10))

func _style_panel(panel: Panel, bg: Color, border: Color, radius: float) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(radius))
	panel.add_theme_stylebox_override("panel", style)
