extends Control
class_name TimePuzzleLobby

const UITypography := preload("res://scripts/ui/ui_typography.gd")

signal closed

const SCOPES := ["WEEKLY", "MONTHLY", "YEARLY"]
const FALLBACK_STAGE_RACE_MAP_COUNT: int = 5
const FALLBACK_STAGE_RACE_WINDOW_SEC: int = 30 * 60
const FALLBACK_STAGE_RACE_START_PLAYERS: int = 5

@onready var root_panel: Panel = $Panel
@onready var root_vbox: VBoxContainer = $Panel/VBox
@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var back_button: Button = $Panel/VBox/Header/Back
@onready var scope_box: HBoxContainer = $Panel/VBox/ScopeTabs
@onready var contest_list: VBoxContainer = $Panel/VBox/ContestList
@onready var contest_state := get_node_or_null("/root/ContestState")

var _scope_buttons: Dictionary = {}
var _current_scope := "WEEKLY"
var _font_regular: Font = null
var _font_semibold: Font = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_fonts()
	_apply_layout()
	_apply_static_style()
	_build_scope_tabs()
	_set_scope(_current_scope)
	back_button.pressed.connect(_on_back_pressed)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_layout):
		get_viewport().size_changed.connect(_apply_layout)

func set_scope(scope: String) -> void:
	if SCOPES.has(scope):
		_set_scope(scope)

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
	_style_panel(root_panel, Color(0.03, 0.035, 0.045, 0.96), Color(0.74, 0.58, 0.22, 0.65), 0.0)
	if root_vbox != null:
		root_vbox.add_theme_constant_override("separation", 20)
	if title_label != null:
		title_label.text = "STAGE RACE TOURNAMENTS"
		_apply_font(title_label, _font_semibold, 32)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if back_button != null:
		back_button.text = "BACK TO MENU"
		back_button.custom_minimum_size = Vector2(210.0, 58.0)
		_style_button(back_button, Color(0.12, 0.13, 0.16), Color(0.48, 0.50, 0.60), Color(0.92, 0.92, 0.92))
		_apply_font(back_button, _font_semibold, 17)
	if scope_box != null:
		scope_box.add_theme_constant_override("separation", 12)
	if contest_list != null:
		contest_list.add_theme_constant_override("separation", 14)

func _build_scope_tabs() -> void:
	for child in scope_box.get_children():
		child.queue_free()
	_scope_buttons.clear()
	for scope in SCOPES:
		var button := Button.new()
		button.text = scope.capitalize()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(170.0, 58.0)
		_apply_font(button, _font_semibold, 18)
		_style_button(button, Color(0.10, 0.11, 0.14), Color(0.44, 0.46, 0.56), Color(0.92, 0.92, 0.92))
		button.pressed.connect(func(): _set_scope(scope))
		scope_box.add_child(button)
		_scope_buttons[scope] = button

func _set_scope(scope: String) -> void:
	_current_scope = scope
	for key in _scope_buttons.keys():
		var button: Button = _scope_buttons[key]
		button.button_pressed = key == scope
		_style_scope_button(button, key == scope)
	_refresh_contests()

func _refresh_contests() -> void:
	for child in contest_list.get_children():
		child.queue_free()
	if contest_state == null:
		_add_empty_state("Tournament data is unavailable.", true)
		return
	var contests: Array[ContestDef] = contest_state.get_contests_by_scope(_current_scope)
	if contests.is_empty():
		_add_empty_state("No %s Stage Race contest is posted yet." % _current_scope.capitalize(), true)
		return
	for contest in contests:
		var button := Button.new()
		button.text = _format_contest_tile(contest)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, 118.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_font(button, _font_regular, 19)
		_style_button(button, Color(0.08, 0.09, 0.12), Color(0.54, 0.45, 0.23), Color(0.95, 0.93, 0.86))
		button.pressed.connect(func(): _open_contest(contest.id))
		contest_list.add_child(button)

func _format_contest_tile(contest: ContestDef) -> String:
	var entered := false
	if contest_state != null:
		entered = contest_state.is_entered(contest.id)
	var entry_text := "Entered" if entered else "Not entered"
	var cap_text := _cap_text(contest.buff_cap_per_map)
	var remaining := _format_remaining(contest.end_ts)
	var stage_label: String = "5-Map Stage Race"
	var contest_label: String = contest.name.replace("Time Puzzle", "Stage Race")
	return "%s\n%s | %s | %s | %s" % [
		contest_label,
		entry_text,
		stage_label,
		cap_text,
		remaining
	]

func _add_empty_state(message: String, allow_fallback_start: bool) -> void:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0.0, 300.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_panel(card, Color(0.075, 0.08, 0.105, 0.96), Color(0.40, 0.42, 0.52, 0.78), 8.0)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24.0
	box.offset_top = 24.0
	box.offset_right = -24.0
	box.offset_bottom = -24.0
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)
	var heading := Label.new()
	heading.text = "%s STAGE RACE" % _current_scope
	_apply_font(heading, _font_semibold, 26)
	box.add_child(heading)
	var body := Label.new()
	body.text = "%s\nYou can still start a free Stage Race run now." % message
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(body, _font_regular, 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	if allow_fallback_start:
		var start_button := Button.new()
		start_button.text = "START FREE STAGE RACE"
		start_button.custom_minimum_size = Vector2(0.0, 68.0)
		_apply_font(start_button, _font_semibold, 22)
		_style_button(start_button, Color(0.18, 0.15, 0.07), Color(0.86, 0.68, 0.22), Color(1.0, 0.92, 0.58))
		start_button.pressed.connect(_open_fallback_stage_race_lobby)
		box.add_child(start_button)
	contest_list.add_child(card)

func _open_contest(contest_id: String) -> void:
	var panel := preload("res://scenes/ui/ContestHub.tscn").instantiate()
	panel.contest_id = contest_id
	panel.closed.connect(func():
		panel.queue_free()
		visible = true
		_refresh_contests()
	)
	add_child(panel)
	visible = false

func _open_fallback_stage_race_lobby() -> void:
	var vs_lobby_scene: PackedScene = load("res://scenes/ui/VsLobby.tscn") as PackedScene
	if vs_lobby_scene == null:
		return
	var vs_lobby := vs_lobby_scene.instantiate()
	vs_lobby.configure("STAGE_RACE", FALLBACK_STAGE_RACE_MAP_COUNT, 0, true, {
		"start_players": FALLBACK_STAGE_RACE_START_PLAYERS,
		"window_sec": FALLBACK_STAGE_RACE_WINDOW_SEC
	})
	vs_lobby.closed.connect(func():
		vs_lobby.queue_free()
		visible = true
	)
	add_child(vs_lobby)
	visible = false

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

func _on_back_pressed() -> void:
	closed.emit()

func _apply_font(control: Control, font: Font, size: int) -> void:
	if control == null:
		return
	if font != null:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", size)

func _style_scope_button(button: Button, active: bool) -> void:
	if button == null:
		return
	if active:
		_style_button(button, Color(0.20, 0.16, 0.07), Color(0.88, 0.68, 0.20), Color(1.0, 0.92, 0.58))
	else:
		_style_button(button, Color(0.10, 0.11, 0.14), Color(0.44, 0.46, 0.56), Color(0.92, 0.92, 0.92))

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
