class_name PublicContestDashPanel
extends Control

signal closed
signal play_requested(definition: Dictionary, attempt: Dictionary)

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
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.93)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 610)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#090909")
	panel_style.border_color = YELLOW
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	_title = Label.new()
	_title.text = "PUBLIC CONTESTS"
	_title.add_theme_color_override("font_color", YELLOW)
	_title.add_theme_font_size_override("font_size", 28)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(func(): emit_signal("closed"))
	header.add_child(close)
	var scopes := HBoxContainer.new()
	root.add_child(scopes)
	for scope in ["WEEKLY", "MONTHLY", "SEASONAL", "ROLLING_COHORT"]:
		var button := Button.new()
		button.text = scope
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_scope.bind(scope))
		scopes.add_child(button)
		_scope_buttons[scope] = button
	var modes := HBoxContainer.new()
	root.add_child(modes)
	for mode in [{"label": "3 MAP", "family": "TIME_PUZZLE", "count": 3},
		{"label": "5 MAP", "family": "TIME_PUZZLE", "count": 5},
		{"label": "GAUNTLET", "family": "GAUNTLET", "count": 18},
		{"label": "ASYNC 3", "family": "ASYNC_MAP_SET", "count": 3},
		{"label": "ASYNC 5", "family": "ASYNC_MAP_SET", "count": 5}]:
		var button := Button.new()
		button.text = str(mode.label)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_mode.bind(str(mode.family), int(mode.count)))
		modes.add_child(button)
		_mode_buttons["%s:%d" % [mode.family, mode.count]] = button
	_status = Label.new()
	_status.text = "Loading authoritative contest board..."
	_status.add_theme_color_override("font_color", MUTED)
	root.add_child(_status)
	_board = RichTextLabel.new()
	_board.bbcode_enabled = true
	_board.fit_content = false
	_board.scroll_active = true
	_board.custom_minimum_size = Vector2(0, 370)
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_board)
	var footer := HBoxContainer.new()
	root.add_child(footer)
	var refresh := Button.new()
	refresh.text = "REFRESH BOARD"
	refresh.pressed.connect(_refresh)
	footer.add_child(refresh)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_play = Button.new()
	_play.text = "PLAY"
	_play.disabled = true
	_play.pressed.connect(_enter_and_play)
	footer.add_child(_play)
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
	_status.text = "Loading authoritative contest board..."
	_play.disabled = true
	_board.text = ""
	var state: Node = get_node_or_null("/root/PublicContestState")
	if state == null:
		_status.text = "Public contests unavailable: state service missing"
		return
	var response: Dictionary = state.call("refresh", "", _scope, 0) as Dictionary
	if not bool(response.get("ok", false)):
		_definition = {}
		_status.text = "Public contests unavailable: %s" % str(response.get("err", "service unavailable"))
		return
	_definition = state.call("find_contest", _family, _scope, _map_count) as Dictionary
	if _definition.is_empty():
		_status.text = "%s is not posted for this period." % _mode_label()
		_board.text = "[color=#a9a9a9]No server contest is open. Local fixture results are intentionally not shown.[/color]"
		return
	var validation: Dictionary = _definition.get("client_content_validation", {}) as Dictionary
	if not bool(validation.get("ok", false)):
		_status.text = "Content verification failed: %s" % str(validation.get("err", "hash mismatch"))
		return
	_status.text = "%s • closes %s • authoritative server board" % [_mode_label(), str(_definition.get("ends_at", ""))]
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
		_status.text = "Could not issue contest attempt: %s" % str(response.get("err", "entry failed"))
		_play.disabled = false
		return
	var attempt: Dictionary = response.get("attempt", {}) as Dictionary
	emit_signal("play_requested", _definition.duplicate(true), attempt.duplicate(true))

func _update_button_states() -> void:
	for key in _scope_buttons:
		(_scope_buttons[key] as Button).disabled = str(key) == _scope
	for key in _mode_buttons:
		var selected: bool = str(key) == "%s:%d" % [_family, _map_count]
		(_mode_buttons[key] as Button).disabled = selected

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
