class_name PublicContestDashPanel
extends Control

signal closed
signal play_requested(definition: Dictionary, attempt: Dictionary)

const Journey = preload("res://scripts/ui/menu_journey_frame.gd")
var _journey: PanelContainer

const YELLOW := Color("#f5c842")
const MUTED := Color("#a9a9a9")

var _scope: String = "WEEKLY"
var _family: String = "TIME_PUZZLE"
var _map_count: int = 3
var _definition: Dictionary = {}
var _title: Label
var _status: Label
var _board: RichTextLabel
var _play: Button
var _scope_buttons: Dictionary = {}
var _mode_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func configure(scope: String = "WEEKLY", family: String = "TIME_PUZZLE", map_count: int = 0) -> void:
	_scope = _normalize_scope(scope)
	var requested_family: String = family.to_upper()
	_family = requested_family if requested_family in ["TIME_PUZZLE", "GAUNTLET", "ASYNC_MAP_SET"] else "TIME_PUZZLE"
	if map_count in [3, 5]:
		_map_count = map_count
	if is_node_ready():
		_refresh()

func _build_ui() -> void:
	_journey = Journey.new()
	add_child(_journey)
	_title = Label.new()
	_title.text = "FREE ROLL CONTESTS"
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(func(): closed.emit())
	_play = Button.new()
	_play.text = "PLAY"
	_play.disabled = true
	_play.pressed.connect(_enter_and_play)
	_journey.configure(_title, back, _play)
	var scopes := GridContainer.new()
	scopes.columns = 2
	scopes.add_theme_constant_override("h_separation", 16)
	scopes.add_theme_constant_override("v_separation", 16)
	_journey.body.add_child(scopes)
	for scope in ["WEEKLY", "MONTHLY", "SEASONAL", "ROLLING_COHORT"]:
		var button := Button.new()
		button.text = "ROLLING CONTESTS" if scope == "ROLLING_COHORT" else scope
		Journey.action(button)
		button.toggle_mode = true
		button.pressed.connect(_select_scope.bind(scope))
		scopes.add_child(button)
		_scope_buttons[scope] = button
	var modes := GridContainer.new()
	modes.columns = 2
	modes.add_theme_constant_override("h_separation", 16)
	modes.add_theme_constant_override("v_separation", 16)
	_journey.body.add_child(modes)
	for mode in [{"label": "TIME PUZZLE\n3 MAPS", "family": "TIME_PUZZLE", "count": 3},
		{"label": "TIME PUZZLE\n5 MAPS", "family": "TIME_PUZZLE", "count": 5},
		{"label": "GAUNTLET", "family": "GAUNTLET", "count": 18},
		{"label": "STAGE RACE\n3 MAPS", "family": "ASYNC_MAP_SET", "count": 3},
		{"label": "STAGE RACE\n5 MAPS", "family": "ASYNC_MAP_SET", "count": 5}]:
		var button := Button.new()
		button.text = str(mode.label)
		Journey.action(button)
		button.toggle_mode = true
		button.pressed.connect(_select_mode.bind(str(mode.family), int(mode.count)))
		modes.add_child(button)
		_mode_buttons["%s:%d" % [mode.family, mode.count]] = button
	_status = Label.new()
	Journey.label(_status)
	_journey.footer.add_child(_status)
	_journey.footer.move_child(_status, 0)
	_board = RichTextLabel.new()
	_board.bbcode_enabled = true
	_board.fit_content = true
	_board.scroll_active = false
	_board.custom_minimum_size.y = 300
	_board.add_theme_font_override("normal_font", Journey.Typography.regular_font())
	_board.add_theme_font_size_override("normal_font_size", 36)
	_board.add_theme_font_size_override("bold_font_size", 36)
	_journey.body.add_child(_board)
	var refresh := Button.new()
	refresh.text = "REFRESH BOARD"
	Journey.action(refresh)
	refresh.pressed.connect(_refresh)
	_journey.footer.add_child(refresh)
	_journey.footer.move_child(refresh, 1)
	_refresh()

func _select_scope(scope: String) -> void:
	_scope = _normalize_scope(scope)
	if _family == "GAUNTLET" and _scope != "WEEKLY":
		_family = "TIME_PUZZLE"
	_refresh()

func _select_mode(family: String, map_count: int) -> void:
	_family = family
	_map_count = map_count
	if _family == "GAUNTLET":
		_scope = "WEEKLY"
	elif _family == "ASYNC_MAP_SET":
		_scope = "ROLLING_COHORT"
	_refresh()

func _refresh() -> void:
	_update_button_states()
	_status.text = "Loading contests…"
	_play.disabled = true
	_board.text = ""
	var state: Node = get_node_or_null("/root/PublicContestState")
	if state == null:
		_status.text = "Contests are unavailable. Try again later."
		return
	var response: Dictionary = state.call("refresh", "", _scope, 0) as Dictionary
	if not bool(response.get("ok", false)):
		_definition = {}
		_status.text = "Could not load contests. Check your connection, then tap Refresh Board."
		return
	_definition = state.call("find_contest", _family, _scope, _map_count) as Dictionary
	if _definition.is_empty():
		_status.text = "%s is not posted for this period." % _mode_label()
		_board.text = "[color=#a9a9a9]No contest is open for this selection. Try another period or mode.[/color]"
		return
	var validation: Dictionary = _definition.get("client_content_validation", {}) as Dictionary
	if not bool(validation.get("ok", false)):
		_status.text = "This contest’s content could not be verified. Check for a game update and try again."
		return
	_status.text = "%s • closes %s" % [_mode_label(), str(_definition.get("ends_at", ""))]
	_play.disabled = false
	var board_response: Dictionary = state.call("leaderboard", str(_definition.get("contest_id", "")), 25) as Dictionary
	_render_board(board_response)

func _render_board(response: Dictionary) -> void:
	if not bool(response.get("ok", false)) or str(response.get("source", "")) != "SERVER_PUBLIC_CONTEST_STORE":
		_board.text = "[color=#a9a9a9]Leaderboard unavailable.[/color]"
		return
	var lines: Array[String] = ["[color=#f5c842][b]TOP RESULTS[/b][/color]"]
	var rows: Array = response.get("rows", []) as Array
	if rows.is_empty():
		lines.append("[color=#a9a9a9]No qualified runs yet. Be the first.[/color]")
	for value in rows:
		var row: Dictionary = value as Dictionary
		var result: Dictionary = row.get("result", {}) as Dictionary
		var score: String
		if _family == "GAUNTLET":
			score = "%d stars • %d stages • %d ticks" % [int(result.get("stars", 0)),
				int(result.get("completed_stage_count", 0)), int(result.get("elapsed_ticks", 0))]
		else:
			score = _format_ticks(int(result.get("aggregate_elapsed_ticks", 0)))
		lines.append("%2d.  [b]%s[/b]   %s" % [int(row.get("competitive_place", 0)),
			str(row.get("display_name", "Player")), score])
	_board.text = "\n\n".join(lines)

func _enter_and_play() -> void:
	_play.disabled = true
	var state: Node = get_node_or_null("/root/PublicContestState")
	var response: Dictionary = state.call("enter", _definition) as Dictionary if state != null else {"ok": false, "err": "state service missing"}
	if not bool(response.get("ok", false)):
		_status.text = "Could not enter contest: %s" % str(response.get("err", "entry failed"))
		_play.disabled = false
		return
	var attempt: Dictionary = response.get("attempt", {}) as Dictionary
	emit_signal("play_requested", _definition.duplicate(true), attempt.duplicate(true))

func _update_button_states() -> void:
	for key in _scope_buttons:
		_style_selection(_scope_buttons[key], str(key) == _scope)
	for key in _mode_buttons:
		var selected: bool = str(key) == "%s:%d" % [_family, 18 if _family == "GAUNTLET" else _map_count]
		_style_selection(_mode_buttons[key], selected)

func _mode_label() -> String:
	if _family == "GAUNTLET":
		return "Weekly Gauntlet"
	if _family == "ASYNC_MAP_SET":
		return "Rolling %d-map async cohort" % _map_count
	return "%s %d-map Time Puzzle" % [_scope.capitalize(), _map_count]

func _format_ticks(ticks: int) -> String:
	var total_ms: int = maxi(0, ticks) * 100
	return "%02d:%02d.%03d" % [total_ms / 60000, (total_ms % 60000) / 1000, total_ms % 1000]

func _normalize_scope(value: String) -> String:
	var result: String = value.strip_edges().to_upper()
	if result in ["YEARLY", "SEASON"]:
		return "SEASONAL"
	return result if result in ["WEEKLY", "MONTHLY", "SEASONAL", "ROLLING_COHORT"] else "WEEKLY"

func _style_selection(button: Button, selected: bool) -> void:
	button.disabled = selected
	button.set_pressed_no_signal(selected)
	button.add_theme_stylebox_override("disabled", Journey.Style.surface(Color("352b19"), Journey.Style.GOLD))
	button.add_theme_color_override("font_disabled_color", Color("fff0b8"))
