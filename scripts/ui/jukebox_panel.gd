extends Panel
class_name JukeboxPanel

const JukeboxStateScript := preload("res://scripts/state/jukebox_state.gd")
const FONT_REGULAR_PATH := "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"

signal closed
signal play_requested(map_path: String)

const TOP_LIMIT: int = 50

@onready var title_label: Label = $VBox/Header/Title
@onready var sub_label: Label = $VBox/Header/Sub
@onready var category_tabs: HBoxContainer = $VBox/CategoryTabs
@onready var map_list: VBoxContainer = $VBox/Body/MapListPanel/MapListVBox/MapScroll/MapList
@onready var map_count_label: Label = $VBox/Body/MapListPanel/MapListVBox/MapCount
@onready var selected_title_label: Label = $VBox/Body/DetailPanel/DetailVBox/SelectedTitle
@onready var selected_meta_label: Label = $VBox/Body/DetailPanel/DetailVBox/SelectedMeta
@onready var selected_desc_label: Label = $VBox/Body/DetailPanel/DetailVBox/SelectedDesc
@onready var period_tabs: HBoxContainer = $VBox/Body/DetailPanel/DetailVBox/PeriodTabs
@onready var leaderboard_list: VBoxContainer = $VBox/Body/DetailPanel/DetailVBox/LeaderboardPanel/LeaderboardVBox/LeaderboardScroll/LeaderboardList
@onready var your_best_label: Label = $VBox/Body/DetailPanel/DetailVBox/LeaderboardPanel/LeaderboardVBox/YourBest
@onready var badge_note_label: Label = $VBox/Body/DetailPanel/DetailVBox/LeaderboardPanel/LeaderboardVBox/BadgeNote
@onready var play_button: Button = $VBox/Footer/PlayButton
@onready var scout_button: Button = $VBox/Footer/ScoutButton
@onready var close_button: Button = $VBox/Footer/CloseButton

var _font_regular: Font = null
var _font_semibold: Font = null
var _jukebox_state = JukeboxStateScript.new()
var _category_labels: Array[String] = ["ALL"]
var _selected_category: String = "ALL"
var _selected_period: String = "WEEKLY"
var _selected_map_path: String = ""

func _ready() -> void:
	visible = false
	_load_fonts()
	_style_controls()
	title_label.text = "MAP JUKEBOX"
	sub_label.text = "Pick a map, inspect the board, then jump straight into a run."
	play_button.pressed.connect(_on_play_pressed)
	scout_button.pressed.connect(_on_scout_pressed)
	close_button.pressed.connect(func() -> void: closed.emit())
	_jukebox_state.refresh()
	_category_labels = _jukebox_state.categories()
	_build_category_tabs()
	_build_period_tabs()
	_refresh_map_list()
	_select_first_visible_map()

func _load_fonts() -> void:
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		_font_regular = load(FONT_REGULAR_PATH) as Font
	if ResourceLoader.exists(FONT_SEMIBOLD_PATH):
		_font_semibold = load(FONT_SEMIBOLD_PATH) as Font

func _style_controls() -> void:
	_apply_font(title_label, _font_semibold, 24)
	_apply_font(sub_label, _font_regular, 13)
	_apply_font(map_count_label, _font_regular, 12)
	_apply_font(selected_title_label, _font_semibold, 20)
	_apply_font(selected_meta_label, _font_regular, 13)
	_apply_font(selected_desc_label, _font_regular, 12)
	_apply_font(your_best_label, _font_semibold, 13)
	_apply_font(badge_note_label, _font_regular, 11)
	for button in [play_button, scout_button, close_button]:
		_apply_font(button, _font_semibold, 13)
		_style_button(button)
	scout_button.disabled = true
	scout_button.text = "SCOUT TOP RUN (PREMIUM SOON)"
	badge_note_label.text = "Top 5 badge ownership is live-scarcity: lose the spot, lose the badge."

func _build_category_tabs() -> void:
	for child in category_tabs.get_children():
		child.queue_free()
	for label in _category_labels:
		var button := Button.new()
		button.text = label
		button.toggle_mode = true
		button.button_pressed = label == _selected_category
		button.custom_minimum_size = Vector2(100.0, 36.0)
		button.pressed.connect(func() -> void:
			_selected_category = label
			_refresh_category_tab_state()
			_refresh_map_list()
			_select_first_visible_map()
		)
		category_tabs.add_child(button)
		_apply_font(button, _font_semibold, 12)
		_style_button(button)

func _refresh_category_tab_state() -> void:
	for child in category_tabs.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		button.button_pressed = button.text == _selected_category

func _build_period_tabs() -> void:
	for child in period_tabs.get_children():
		child.queue_free()
	for label in _jukebox_state.PERIOD_LABELS:
		var button := Button.new()
		button.text = label
		button.toggle_mode = true
		button.button_pressed = label == _selected_period
		button.custom_minimum_size = Vector2(110.0, 34.0)
		button.pressed.connect(func() -> void:
			_selected_period = label
			_refresh_period_tab_state()
			_refresh_leaderboard()
		)
		period_tabs.add_child(button)
		_apply_font(button, _font_semibold, 12)
		_style_button(button)

func _refresh_period_tab_state() -> void:
	for child in period_tabs.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		button.button_pressed = button.text == _selected_period

func _refresh_map_list() -> void:
	for child in map_list.get_children():
		child.queue_free()
	var visible_entries: Array[Dictionary] = _visible_map_entries()
	map_count_label.text = "%d maps in %s" % [visible_entries.size(), _selected_category]
	for entry in visible_entries:
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s  |  %s" % [str(entry.get("title", "")), str(entry.get("hero_title", ""))]
		row.tooltip_text = "%s\n%s" % [str(entry.get("meta", "")), str(entry.get("desc", ""))]
		row.custom_minimum_size = Vector2(0.0, 56.0)
		row.pressed.connect(func() -> void:
			_select_map(str(entry.get("path", "")))
		)
		map_list.add_child(row)
		_apply_font(row, _font_regular, 12)
		_style_button(row)

func _visible_map_entries() -> Array[Dictionary]:
	return _jukebox_state.catalog(_selected_category)

func _select_first_visible_map() -> void:
	var visible_entries: Array[Dictionary] = _visible_map_entries()
	if visible_entries.is_empty():
		_selected_map_path = ""
		selected_title_label.text = "No maps"
		selected_meta_label.text = ""
		selected_desc_label.text = "No map entries are available in this category."
		_refresh_leaderboard()
		return
	_select_map(str(visible_entries[0].get("path", "")))

func _select_map(map_path: String) -> void:
	_selected_map_path = map_path
	var selected: Dictionary = _entry_by_path(map_path)
	selected_title_label.text = str(selected.get("title", "Map"))
	selected_meta_label.text = "%s  |  %s" % [
		str(selected.get("hero_title", "")),
		str(selected.get("meta", ""))
	]
	selected_desc_label.text = str(selected.get("desc", ""))
	play_button.disabled = _selected_map_path.is_empty()
	_refresh_leaderboard()

func _entry_by_path(map_path: String) -> Dictionary:
	return _jukebox_state.entry_for_path(map_path)

func _refresh_leaderboard() -> void:
	for child in leaderboard_list.get_children():
		child.queue_free()
	if _selected_map_path.is_empty():
		your_best_label.text = "Your best: --"
		return
	var selected: Dictionary = _entry_by_path(_selected_map_path)
	var board: Dictionary = _jukebox_state.board_snapshot(_selected_map_path, _selected_period, TOP_LIMIT)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var head_rank := Label.new()
	head_rank.text = "RANK"
	head_rank.custom_minimum_size = Vector2(44.0, 0.0)
	header.add_child(head_rank)
	_apply_font(head_rank, _font_semibold, 11)
	var head_handle := Label.new()
	head_handle.text = "HANDLE"
	head_handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(head_handle)
	_apply_font(head_handle, _font_semibold, 11)
	var head_badge := Label.new()
	head_badge.text = "BADGE"
	head_badge.custom_minimum_size = Vector2(70.0, 0.0)
	head_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(head_badge)
	_apply_font(head_badge, _font_semibold, 11)
	var head_time := Label.new()
	head_time.text = "TIME"
	head_time.custom_minimum_size = Vector2(120.0, 0.0)
	head_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(head_time)
	_apply_font(head_time, _font_semibold, 11)
	leaderboard_list.add_child(header)
	var entries: Array = board.get("entries", []) as Array
	for entry_any in entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var rank_label := Label.new()
		rank_label.text = "%02d" % int(entry.get("rank", 0))
		rank_label.custom_minimum_size = Vector2(44.0, 0.0)
		row.add_child(rank_label)
		_apply_font(rank_label, _font_semibold, 12)
		var handle_label := Label.new()
		handle_label.text = str(entry.get("handle", "--"))
		handle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(handle_label)
		_apply_font(handle_label, _font_regular, 12)
		var badge_label := Label.new()
		badge_label.text = str(entry.get("badge", ""))
		badge_label.custom_minimum_size = Vector2(70.0, 0.0)
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(badge_label)
		_apply_font(badge_label, _font_regular, 11)
		var time_label := Label.new()
		time_label.text = _format_time_ms(int(entry.get("time_ms", 0)))
		time_label.custom_minimum_size = Vector2(120.0, 0.0)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(time_label)
		_apply_font(time_label, _font_semibold, 12)
		leaderboard_list.add_child(row)
	var your_best_ms: int = int(board.get("your_best_ms", 0))
	var your_rank: int = int(board.get("your_rank", 0))
	your_best_label.text = "Your best: #%d  %s" % [your_rank, _format_time_ms(your_best_ms)]

func _on_play_pressed() -> void:
	if _selected_map_path.is_empty():
		return
	play_requested.emit(_selected_map_path)

func _on_scout_pressed() -> void:
	# Intentionally parked until replay + analytics tier logic is live.
	pass

func _format_time_ms(value: int) -> String:
	var ms: int = maxi(0, value)
	var minutes: int = ms / 60000
	var seconds: int = (ms % 60000) / 1000
	var millis: int = ms % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, millis]

func _apply_font(control: Control, font: Font, size: int) -> void:
	if control == null or font == null:
		return
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", size)

func _style_button(button: Button) -> void:
	if button == null:
		return
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
