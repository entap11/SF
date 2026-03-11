extends Panel
class_name JukeboxPanel

const JukeboxStateScript := preload("res://scripts/state/jukebox_state.gd")
const FONT_REGULAR_PATH := "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const CHEVRON_TEXTURE_PATH := "res://assets/sprites/sf_skin_v1/up_down_chevron.png"
const SIDE_CHEVRON_TEXTURE_PATH := "res://assets/sprites/sf_skin_v1/Left_right_chevrons.png"
const PAGE_SIZE: int = 7
const MAP_WINDOW_SIZE: int = 5
const SELECTOR_META_FONT_SIZE: int = 18
const SELECTOR_TAB_FONT_SIZE: int = 16
const SELECTOR_CARD_FONT_SIZE: int = 18
const LEADERBOARD_HEADER_FONT_SIZE: int = 22
const LEADERBOARD_ROW_FONT_SIZE: int = 24
const LEADERBOARD_BADGE_FONT_SIZE: int = 22

signal closed
signal play_requested(map_path: String)

const TOP_LIMIT: int = 50

@onready var title_label: Label = $VBox/SelectorPanel/SelectorVBox/Header/Title
@onready var sub_label: Label = $VBox/SelectorPanel/SelectorVBox/Header/Sub
@onready var category_tabs: HBoxContainer = $VBox/SelectorPanel/SelectorVBox/CategoryTabs
@onready var map_top_row: HBoxContainer = $VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapTopRow
@onready var map_bottom_cards: HBoxContainer = $VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapBottomRow/MapBottomCards
@onready var map_left_button: Button = $VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapBottomRow/MapLeft
@onready var map_right_button: Button = $VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapBottomRow/MapRight
@onready var map_count_label: Label = $VBox/SelectorPanel/SelectorVBox/SelectorMetaRow/MapCount
@onready var map_hint_label: Label = $VBox/SelectorPanel/SelectorVBox/SelectorMetaRow/MapHint
@onready var hero_preview: TextureRect = $VBox/HeroPanel/HeroVBox/HeroPreviewPanel/HeroPreview
@onready var hero_preview_badge: Label = $VBox/HeroPanel/HeroVBox/HeroPreviewPanel/HeroPreviewBadge
@onready var selected_title_label: Label = $VBox/HeroPanel/HeroVBox/SelectedTitle
@onready var selected_meta_label: Label = $VBox/HeroPanel/HeroVBox/SelectedMeta
@onready var selected_desc_label: Label = $VBox/HeroPanel/HeroVBox/SelectedDesc
@onready var map_best_label: Label = $VBox/HeroPanel/HeroVBox/MapBest
@onready var play_button: Button = $VBox/HeroPanel/HeroVBox/HeroActions/PlayButton
@onready var scout_button: Button = $VBox/HeroPanel/HeroVBox/HeroActions/ScoutButton
@onready var close_button: Button = $VBox/HeroPanel/HeroVBox/HeroActions/CloseButton
@onready var period_tabs: HBoxContainer = $VBox/LeaderboardPanel/LeaderboardVBox/PeriodTabs
@onready var leaderboard_list: VBoxContainer = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardScroll/LeaderboardList
@onready var leaderboard_nav: HBoxContainer = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav
@onready var leaderboard_up_button: Button = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav/LeaderboardUp
@onready var leaderboard_page_label: Label = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav/LeaderboardPage
@onready var leaderboard_down_button: Button = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav/LeaderboardDown
@onready var your_best_label: Label = $VBox/LeaderboardPanel/LeaderboardVBox/YourBest
@onready var badge_note_label: Label = $VBox/LeaderboardPanel/LeaderboardVBox/BadgeNote

var _font_regular: Font = null
var _font_semibold: Font = null
var _chevron_texture: Texture2D = null
var _side_chevron_texture: Texture2D = null
var _jukebox_state = JukeboxStateScript.new()
var _category_labels: Array[String] = ["ALL"]
var _selected_category: String = "ALL"
var _selected_period: String = "WEEKLY"
var _selected_map_path: String = ""
var _map_offset: int = 0
var _leaderboard_offset: int = 0

func _ready() -> void:
	visible = false
	_load_fonts()
	_style_controls()
	title_label.text = "MAP JUKEBOX"
	sub_label.text = "Browse maps across the top, inspect the hero panel, then chase records below."
	play_button.pressed.connect(_on_play_pressed)
	scout_button.pressed.connect(_on_scout_pressed)
	close_button.pressed.connect(func() -> void: closed.emit())
	map_left_button.pressed.connect(_on_map_left_pressed)
	map_right_button.pressed.connect(_on_map_right_pressed)
	leaderboard_up_button.pressed.connect(_on_leaderboard_up_pressed)
	leaderboard_down_button.pressed.connect(_on_leaderboard_down_pressed)
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
	if ResourceLoader.exists(CHEVRON_TEXTURE_PATH):
		_chevron_texture = load(CHEVRON_TEXTURE_PATH) as Texture2D
	if ResourceLoader.exists(SIDE_CHEVRON_TEXTURE_PATH):
		_side_chevron_texture = load(SIDE_CHEVRON_TEXTURE_PATH) as Texture2D

func _style_controls() -> void:
	_apply_font(title_label, _font_semibold, 24)
	_apply_font(sub_label, _font_regular, 16)
	_apply_font(map_count_label, _font_regular, SELECTOR_META_FONT_SIZE)
	_apply_font(map_hint_label, _font_regular, SELECTOR_META_FONT_SIZE - 1)
	_apply_font(hero_preview_badge, _font_semibold, 11)
	_apply_font(selected_title_label, _font_semibold, 20)
	_apply_font(selected_meta_label, _font_regular, 13)
	_apply_font(selected_desc_label, _font_regular, 12)
	_apply_font(leaderboard_page_label, _font_semibold, 22)
	_apply_font(your_best_label, _font_semibold, 24)
	_apply_font(map_best_label, _font_regular, 12)
	_apply_font(badge_note_label, _font_regular, 18)
	for button in [play_button, scout_button, close_button]:
		_apply_font(button, _font_semibold, 13)
		_style_button(button)
	for button in [map_left_button, map_right_button]:
		_apply_font(button, _font_semibold, 11)
		_style_button(button)
		_style_selector_nav_button(button)
	for button in [leaderboard_up_button, leaderboard_down_button]:
		_apply_font(button, _font_semibold, 11)
		_style_button(button)
		_style_nav_button(button)
	scout_button.disabled = true
	scout_button.text = "SCOUT TOP RUN (PREMIUM SOON)"
	badge_note_label.text = "Top 5 badge ownership is live-scarcity: lose the spot, lose the badge."
	hero_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_apply_nav_icons()
	_apply_selector_nav_icons()

func _build_category_tabs() -> void:
	for child in category_tabs.get_children():
		child.queue_free()
	for label in _category_labels:
		var button := Button.new()
		button.text = label
		button.toggle_mode = true
		button.button_pressed = label == _selected_category
		button.custom_minimum_size = Vector2(132.0, 44.0)
		button.pressed.connect(func() -> void:
			_selected_category = label
			_map_offset = 0
			_refresh_category_tab_state()
			_refresh_map_list()
			_select_first_visible_map()
		)
		category_tabs.add_child(button)
		_apply_font(button, _font_semibold, SELECTOR_TAB_FONT_SIZE)
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
			_leaderboard_offset = 0
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
	for child in map_top_row.get_children():
		child.queue_free()
	for child in map_bottom_cards.get_children():
		child.queue_free()
	var visible_entries: Array[Dictionary] = _visible_map_entries()
	map_count_label.text = "%d maps in %s" % [visible_entries.size(), _selected_category]
	var max_offset: int = maxi(0, visible_entries.size() - MAP_WINDOW_SIZE)
	_map_offset = clampi(_map_offset, 0, max_offset)
	var end_index: int = mini(_map_offset + MAP_WINDOW_SIZE, visible_entries.size())
	for entry_index in range(_map_offset, end_index):
		var entry: Dictionary = visible_entries[entry_index]
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.toggle_mode = true
		row.button_pressed = str(entry.get("path", "")) == _selected_map_path
		row.text = "%s\n%s" % [str(entry.get("title", "")), str(entry.get("hero_title", ""))]
		row.tooltip_text = "%s\n%s" % [str(entry.get("meta", "")), str(entry.get("desc", ""))]
		row.custom_minimum_size = Vector2(300.0, 116.0)
		row.pressed.connect(func() -> void:
			_select_map(str(entry.get("path", "")))
		)
		if (entry_index - _map_offset) < 3:
			map_top_row.add_child(row)
		else:
			map_bottom_cards.add_child(row)
		_apply_font(row, _font_semibold, SELECTOR_CARD_FONT_SIZE)
		_style_button(row)
	_refresh_map_nav(visible_entries.size())

func _visible_map_entries() -> Array[Dictionary]:
	return _jukebox_state.catalog(_selected_category)

func _select_first_visible_map() -> void:
	var visible_entries: Array[Dictionary] = _visible_map_entries()
	if visible_entries.is_empty():
		_selected_map_path = ""
		_map_offset = 0
		selected_title_label.text = "No maps"
		selected_meta_label.text = ""
		selected_desc_label.text = "No map entries are available in this category."
		_refresh_leaderboard()
		return
	if not _selected_map_path.is_empty():
		for index in range(visible_entries.size()):
			var entry: Dictionary = visible_entries[index]
			if str(entry.get("path", "")) == _selected_map_path:
				_map_offset = min(index, maxi(0, visible_entries.size() - MAP_WINDOW_SIZE))
				_refresh_map_list()
				_select_map(_selected_map_path)
				return
	_map_offset = 0
	_select_map(str(visible_entries[0].get("path", "")))

func _select_map(map_path: String) -> void:
	_selected_map_path = map_path
	_leaderboard_offset = 0
	var selected: Dictionary = _entry_by_path(map_path)
	selected_title_label.text = str(selected.get("title", "Map"))
	selected_meta_label.text = "%s  |  %s" % [
		str(selected.get("hero_title", "")),
		str(selected.get("meta", ""))
	]
	selected_desc_label.text = str(selected.get("desc", ""))
	_refresh_hero_preview(selected)
	play_button.disabled = _selected_map_path.is_empty()
	_refresh_map_list()
	_refresh_leaderboard()

func _entry_by_path(map_path: String) -> Dictionary:
	return _jukebox_state.entry_for_path(map_path)

func _refresh_leaderboard() -> void:
	for child in leaderboard_list.get_children():
		child.queue_free()
	if _selected_map_path.is_empty():
		leaderboard_nav.visible = false
		leaderboard_page_label.text = "0-0 / 0"
		your_best_label.text = "Your best: --"
		map_best_label.text = "Map PB: --"
		return
	var board: Dictionary = _jukebox_state.board_snapshot(_selected_map_path, _selected_period, TOP_LIMIT)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	header.custom_minimum_size = Vector2(0.0, 42.0)
	var head_rank := Label.new()
	head_rank.text = "RANK"
	head_rank.custom_minimum_size = Vector2(88.0, 0.0)
	header.add_child(head_rank)
	_apply_font(head_rank, _font_semibold, LEADERBOARD_HEADER_FONT_SIZE)
	var head_handle := Label.new()
	head_handle.text = "HANDLE"
	head_handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(head_handle)
	_apply_font(head_handle, _font_semibold, LEADERBOARD_HEADER_FONT_SIZE)
	var head_badge := Label.new()
	head_badge.text = "BADGE"
	head_badge.custom_minimum_size = Vector2(132.0, 0.0)
	head_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(head_badge)
	_apply_font(head_badge, _font_semibold, LEADERBOARD_HEADER_FONT_SIZE)
	var head_time := Label.new()
	head_time.text = "TIME"
	head_time.custom_minimum_size = Vector2(220.0, 0.0)
	head_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(head_time)
	_apply_font(head_time, _font_semibold, LEADERBOARD_HEADER_FONT_SIZE)
	leaderboard_list.add_child(header)
	var entries: Array = board.get("entries", []) as Array
	var total_entries: int = entries.size()
	var max_offset: int = maxi(0, total_entries - PAGE_SIZE)
	_leaderboard_offset = clampi(_leaderboard_offset, 0, max_offset)
	var end_index: int = mini(_leaderboard_offset + PAGE_SIZE, total_entries)
	for entry_index in range(_leaderboard_offset, end_index):
		var entry_any: Variant = entries[entry_index]
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		row.custom_minimum_size = Vector2(0.0, 44.0)
		var rank_label := Label.new()
		rank_label.text = "%02d" % int(entry.get("rank", 0))
		rank_label.custom_minimum_size = Vector2(88.0, 0.0)
		row.add_child(rank_label)
		_apply_font(rank_label, _font_semibold, LEADERBOARD_ROW_FONT_SIZE)
		var handle_label := Label.new()
		handle_label.text = str(entry.get("handle", "--"))
		handle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(handle_label)
		_apply_font(handle_label, _font_regular, LEADERBOARD_ROW_FONT_SIZE)
		var badge_label := Label.new()
		badge_label.text = str(entry.get("badge", ""))
		badge_label.custom_minimum_size = Vector2(132.0, 0.0)
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(badge_label)
		_apply_font(badge_label, _font_regular, LEADERBOARD_BADGE_FONT_SIZE)
		var time_label := Label.new()
		time_label.text = _format_time_ms(int(entry.get("time_ms", 0)))
		time_label.custom_minimum_size = Vector2(220.0, 0.0)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(time_label)
		_apply_font(time_label, _font_semibold, LEADERBOARD_ROW_FONT_SIZE)
		leaderboard_list.add_child(row)
	_refresh_leaderboard_nav(total_entries)
	var your_best_ms: int = int(board.get("your_best_ms", 0))
	var your_rank: int = int(board.get("your_rank", 0))
	if your_rank <= 0 or your_best_ms <= 0:
		your_best_label.text = "Your best: --"
	else:
		your_best_label.text = "Your best: #%d  %s" % [your_rank, _format_time_ms(your_best_ms)]
	_refresh_map_best()

func _refresh_map_best() -> void:
	if _selected_map_path.is_empty():
		map_best_label.text = "Map PB: --"
		return
	var player_id: String = ""
	var player_handle: String = ""
	if ProfileManager != null:
		if ProfileManager.has_method("get_user_id"):
			player_id = str(ProfileManager.get_user_id()).strip_edges()
		if ProfileManager.has_method("get_display_name"):
			player_handle = str(ProfileManager.get_display_name()).strip_edges()
	var summary: Dictionary = _jukebox_state.player_map_summary(_selected_map_path, player_id, player_handle, "ALL TIME")
	var best_time_ms: int = int(summary.get("best_time_ms", 0))
	var run_count: int = int(summary.get("run_count", 0))
	if best_time_ms <= 0 or run_count <= 0:
		map_best_label.text = "Map PB: --"
		return
	map_best_label.text = "Map PB: %s  |  %d runs" % [_format_time_ms(best_time_ms), run_count]

func _refresh_hero_preview(selected: Dictionary) -> void:
	var preview_path: String = str(selected.get("preview_path", "")).strip_edges()
	if not preview_path.is_empty() and ResourceLoader.exists(preview_path):
		hero_preview.texture = load(preview_path) as Texture2D
		hero_preview_badge.text = "MAP PREVIEW"
		return
	hero_preview.texture = null
	hero_preview_badge.text = "PREVIEW COMING SOON"

func _refresh_map_nav(total_entries: int) -> void:
	var safe_total: int = maxi(0, total_entries)
	var start_index: int = 0
	var end_index: int = 0
	if safe_total > 0:
		start_index = _map_offset + 1
		end_index = mini(_map_offset + MAP_WINDOW_SIZE, safe_total)
	map_hint_label.text = "%d-%d / %d" % [start_index, end_index, safe_total]
	map_left_button.disabled = _map_offset <= 0
	map_right_button.disabled = (_map_offset + MAP_WINDOW_SIZE) >= safe_total

func _refresh_leaderboard_nav(total_entries: int) -> void:
	var safe_total: int = maxi(0, total_entries)
	var start_index: int = 0
	var end_index: int = 0
	if safe_total > 0:
		start_index = _leaderboard_offset + 1
		end_index = mini(_leaderboard_offset + PAGE_SIZE, safe_total)
	leaderboard_nav.visible = safe_total > PAGE_SIZE
	leaderboard_page_label.text = "%d-%d / %d" % [start_index, end_index, safe_total]
	leaderboard_up_button.disabled = _leaderboard_offset <= 0
	leaderboard_down_button.disabled = (_leaderboard_offset + PAGE_SIZE) >= safe_total

func _on_leaderboard_up_pressed() -> void:
	_leaderboard_offset = maxi(0, _leaderboard_offset - PAGE_SIZE)
	_refresh_leaderboard()

func _on_leaderboard_down_pressed() -> void:
	_leaderboard_offset += PAGE_SIZE
	_refresh_leaderboard()

func _on_map_left_pressed() -> void:
	_map_offset = maxi(0, _map_offset - 1)
	_refresh_map_list()

func _on_map_right_pressed() -> void:
	_map_offset += 1
	_refresh_map_list()

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

func _style_nav_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(76.0, 52.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)

func _style_selector_nav_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(92.0, 92.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)

func _apply_nav_icons() -> void:
	if _chevron_texture == null:
		return
	leaderboard_up_button.icon = _chevron_atlas(false)
	leaderboard_down_button.icon = _chevron_atlas(true)
	leaderboard_up_button.text = ""
	leaderboard_down_button.text = ""

func _apply_selector_nav_icons() -> void:
	if _side_chevron_texture == null:
		return
	map_left_button.icon = _side_chevron_atlas(false)
	map_right_button.icon = _side_chevron_atlas(true)
	map_left_button.text = ""
	map_right_button.text = ""

func _chevron_atlas(is_down: bool) -> Texture2D:
	if _chevron_texture == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = _chevron_texture
	var tex_w: int = _chevron_texture.get_width()
	var tex_h: int = _chevron_texture.get_height()
	var half_h: int = tex_h / 2
	atlas.region = Rect2(0, 0 if is_down else half_h, tex_w, half_h)
	return atlas

func _side_chevron_atlas(is_right: bool) -> Texture2D:
	if _side_chevron_texture == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = _side_chevron_texture
	var tex_w: int = _side_chevron_texture.get_width()
	var tex_h: int = _side_chevron_texture.get_height()
	var half_h: int = tex_h / 2
	atlas.region = Rect2(0, half_h if is_right else 0, tex_w, half_h)
	return atlas

func _style_button(button: Button) -> void:
	if button == null:
		return
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
