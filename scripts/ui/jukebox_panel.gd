extends Panel
class_name JukeboxPanel

const JukeboxStateScript := preload("res://scripts/state/jukebox_state.gd")
const UITypography := preload("res://scripts/ui/ui_typography.gd")
const CHEVRON_TEXTURE_PATH := "res://assets/sprites/sf_skin_v1/up_down_chevron.png"
const SIDE_CHEVRON_TEXTURE_PATH := "res://assets/sprites/sf_skin_v1/Left_right_chevrons.png"
const PLAY_TEXTURE_PATH := "res://assets/sprites/sf_skin_v1/play.png"
const SWARMFRONT_TITLE_SHADER_PATH := "res://ui/main_menu/swarmfront_title_forged.gdshader"
const PAGE_SIZE: int = 7
const MAP_WINDOW_SIZE: int = 5
const SELECTOR_META_FONT_SIZE: int = 18
const SELECTOR_TAB_FONT_SIZE: int = 16
const SELECTOR_CARD_FONT_SIZE: int = 24
const LEADERBOARD_HEADER_FONT_SIZE: int = 22
const LEADERBOARD_ROW_FONT_SIZE: int = 24
const LEADERBOARD_BADGE_FONT_SIZE: int = 22
const BASE_CONTENT_MARGIN_TOP: float = 18.0
const CATEGORY_TAB_MIN_WIDTH: float = 72.0
const CATEGORY_TAB_MAX_WIDTH: float = 132.0
const PERIOD_TAB_MIN_WIDTH: float = 78.0
const PERIOD_TAB_MAX_WIDTH: float = 110.0
const MAP_CARD_MIN_WIDTH: float = 92.0
const MAP_CARD_MAX_WIDTH: float = 300.0
const PLAY_BUTTON_MIN_WIDTH: float = 260.0
const PLAY_BUTTON_MAX_WIDTH: float = 620.0
const SELECTOR_NAV_MIN_WIDTH: float = 56.0
const SELECTOR_NAV_MAX_WIDTH: float = 92.0
const TOUCH_LAYOUT_MAX_WIDTH: float = 1100.0
const TOUCH_LAYOUT_FONT_SCALE: float = 1.16

signal closed
signal play_requested(map_path: String, cpu_style: String, cpu_tier: String)

const TOP_LIMIT: int = 50

@onready var brand_banner_label: Label = get_node_or_null("VBox/BrandBanner") as Label
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
@onready var play_button: Button = $VBox/SelectorPanel/SelectorVBox/PlayButton
@onready var play_sprite: TextureRect = $VBox/SelectorPanel/SelectorVBox/PlayButton/PlaySprite
@onready var scout_button: Button = $VBox/HeroPanel/HeroVBox/HeroActions/ScoutButton
@onready var close_button: Button = $VBox/HeroPanel/HeroVBox/HeroActions/CloseButton
@onready var cpu_panel: Panel = $VBox/CpuPanel
@onready var period_tabs: HBoxContainer = $VBox/LeaderboardPanel/LeaderboardVBox/PeriodTabs
@onready var leaderboard_list: VBoxContainer = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardScroll/LeaderboardList
@onready var leaderboard_nav: HBoxContainer = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav
@onready var leaderboard_up_button: Button = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav/LeaderboardUp
@onready var leaderboard_page_label: Label = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav/LeaderboardPage
@onready var leaderboard_down_button: Button = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav/LeaderboardDown
@onready var your_best_label: Label = $VBox/LeaderboardPanel/LeaderboardVBox/YourBest
@onready var badge_note_label: Label = $VBox/LeaderboardPanel/LeaderboardVBox/BadgeNote
@onready var footer_close_button: Button = $VBox/FooterCloseButton
@onready var root_vbox: VBoxContainer = $VBox

var _font_regular: Font = null
var _font_semibold: Font = null
var _swarmfront_title_shader: Shader = null
var _chevron_texture: Texture2D = null
var _side_chevron_texture: Texture2D = null
var _play_texture: Texture2D = null
var _jukebox_state = JukeboxStateScript.new()
var _category_labels: Array[String] = ["ALL"]
var _selected_category: String = "ALL"
var _selected_period: String = "WEEKLY"
var _selected_map_path: String = ""
var _map_offset: int = 0
var _leaderboard_offset: int = 0

func _ready() -> void:
	visible = false
	resized.connect(_on_panel_resized)
	_wrap_category_tabs_for_scroll()
	_load_fonts()
	title_label.text = "MAP JUKEBOX"
	sub_label.text = "BROWSE MAPS  CHASE RECORDS"
	scout_button.text = "SCOUT TOP RUN PREMIUM SOON"
	_style_controls()
	play_button.pressed.connect(_on_play_pressed)
	scout_button.pressed.connect(_on_scout_pressed)
	close_button.pressed.connect(func() -> void: closed.emit())
	footer_close_button.pressed.connect(func() -> void: closed.emit())
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

func _on_panel_resized() -> void:
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	_refresh_selector_nav_widths()
	_refresh_category_tab_widths()
	_refresh_period_tab_widths()
	_refresh_play_button_width()
	_refresh_map_card_widths()

func _wrap_category_tabs_for_scroll() -> void:
	if category_tabs == null or category_tabs.get_parent() == null:
		return
	if category_tabs.get_parent() is ScrollContainer:
		return
	var parent: Node = category_tabs.get_parent()
	var insert_index: int = category_tabs.get_index()
	parent.remove_child(category_tabs)
	var scroll := ScrollContainer.new()
	scroll.name = "CategoryTabsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 48.0)
	parent.add_child(scroll)
	parent.move_child(scroll, insert_index)
	scroll.add_child(category_tabs)
	category_tabs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

func capture_runtime_state() -> Dictionary:
	return {
		"selected_category": _selected_category,
		"selected_period": _selected_period,
		"selected_map_path": _selected_map_path,
		"map_offset": _map_offset,
		"leaderboard_offset": _leaderboard_offset
	}

func restore_runtime_state(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var target_map_path: String = str(snapshot.get("selected_map_path", "")).strip_edges()
	var target_category: String = str(snapshot.get("selected_category", "")).strip_edges().to_upper()
	if not target_map_path.is_empty():
		var resolved_category: String = _find_category_for_map_path(target_map_path)
		if not resolved_category.is_empty():
			target_category = resolved_category
	if not target_category.is_empty() and _category_labels.has(target_category):
		_selected_category = target_category
	var target_period: String = str(snapshot.get("selected_period", "")).strip_edges().to_upper()
	if not target_period.is_empty() and _jukebox_state.PERIOD_LABELS.has(target_period):
		_selected_period = target_period
	var category_entries: Array[Dictionary] = _visible_map_entries()
	var max_offset: int = maxi(0, category_entries.size() - MAP_WINDOW_SIZE)
	_map_offset = clampi(int(snapshot.get("map_offset", _map_offset)), 0, max_offset)
	_leaderboard_offset = maxi(0, int(snapshot.get("leaderboard_offset", 0)))
	_refresh_category_tab_state()
	_refresh_period_tab_state()
	_refresh_map_list()
	if not target_map_path.is_empty():
		_selected_map_path = target_map_path
	_select_first_visible_map()

func _find_category_for_map_path(map_path: String) -> String:
	if map_path.is_empty():
		return ""
	for category_any in _category_labels:
		var category: String = str(category_any)
		var entries: Array[Dictionary] = _jukebox_state.catalog(category)
		for entry in entries:
			if str(entry.get("path", "")) == map_path:
				return category
	return ""

func _load_fonts() -> void:
	_font_regular = UITypography.regular_font()
	_font_semibold = UITypography.semibold_font()
	if ResourceLoader.exists(CHEVRON_TEXTURE_PATH):
		_chevron_texture = load(CHEVRON_TEXTURE_PATH) as Texture2D
	if ResourceLoader.exists(SIDE_CHEVRON_TEXTURE_PATH):
		_side_chevron_texture = load(SIDE_CHEVRON_TEXTURE_PATH) as Texture2D
	if ResourceLoader.exists(PLAY_TEXTURE_PATH):
		_play_texture = load(PLAY_TEXTURE_PATH) as Texture2D

func _ensure_swarmfront_banner() -> void:
	if root_vbox == null:
		return
	if brand_banner_label != null and is_instance_valid(brand_banner_label):
		return
	var existing: Label = root_vbox.get_node_or_null("BrandBanner") as Label
	if existing != null:
		brand_banner_label = existing
		return
	var label := Label.new()
	label.name = "BrandBanner"
	label.custom_minimum_size = Vector2(0.0, 88.0)
	label.text = "SWARMFRONT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root_vbox.add_child(label)
	root_vbox.move_child(label, 0)
	brand_banner_label = label

func _style_controls() -> void:
	_ensure_swarmfront_banner()
	_apply_swarmfront_banner_style()
	_apply_font(title_label, _font_semibold, _scaled_touch_font_size(24))
	_apply_font(sub_label, _font_regular, _scaled_touch_font_size(16))
	_apply_font(map_count_label, _font_regular, _scaled_touch_font_size(SELECTOR_META_FONT_SIZE))
	_apply_font(map_hint_label, _font_regular, _scaled_touch_font_size(SELECTOR_META_FONT_SIZE - 1))
	_apply_font(hero_preview_badge, _font_semibold, _scaled_touch_font_size(11))
	_apply_font(selected_title_label, _font_semibold, _scaled_touch_font_size(24))
	_apply_font(selected_meta_label, _font_semibold, _scaled_touch_font_size(16))
	_apply_font(selected_desc_label, _font_regular, _scaled_touch_font_size(14))
	if cpu_panel != null:
		cpu_panel.visible = false
		cpu_panel.custom_minimum_size = Vector2.ZERO
	_apply_font(leaderboard_page_label, _font_semibold, _scaled_touch_font_size(22))
	_apply_font(your_best_label, _font_semibold, _scaled_touch_font_size(24))
	_apply_font(map_best_label, _font_regular, _scaled_touch_font_size(12))
	_apply_font(badge_note_label, _font_regular, _scaled_touch_font_size(18))
	_apply_font(play_button, _font_semibold, _scaled_touch_font_size(13))
	_style_button(play_button)
	_style_play_button()
	if scout_button != null:
		scout_button.visible = false
	if close_button != null:
		_apply_font(close_button, _font_semibold, _scaled_touch_font_size(12))
		_style_button(close_button)
		close_button.custom_minimum_size = Vector2(176.0, 46.0) if _uses_touch_layout() else Vector2(150.0, 38.0)
	if footer_close_button != null:
		_apply_font(footer_close_button, _font_semibold, _scaled_touch_font_size(14))
		_style_button(footer_close_button)
		footer_close_button.custom_minimum_size = Vector2(276.0, 62.0) if _uses_touch_layout() else Vector2(240.0, 52.0)
	for button in [map_left_button, map_right_button]:
		_apply_font(button, _font_semibold, _scaled_touch_font_size(11))
		_style_button(button)
		_style_selector_nav_button(button)
	for button in [leaderboard_up_button, leaderboard_down_button]:
		_apply_font(button, _font_semibold, _scaled_touch_font_size(11))
		_style_button(button)
		_style_nav_button(button)
	scout_button.disabled = true
	badge_note_label.text = "Top 5 badge ownership is live-scarcity: lose the spot, lose the badge."
	hero_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_apply_nav_icons()
	_apply_selector_nav_icons()

func _swarmfront_title_shader_resource() -> Shader:
	if _swarmfront_title_shader == null and ResourceLoader.exists(SWARMFRONT_TITLE_SHADER_PATH):
		_swarmfront_title_shader = load(SWARMFRONT_TITLE_SHADER_PATH) as Shader
	return _swarmfront_title_shader

func _apply_swarmfront_banner_style() -> void:
	if brand_banner_label == null:
		return
	brand_banner_label.text = "SWARMFRONT"
	brand_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not UITypography.apply_free_roll_atlas_font(brand_banner_label, 34):
		_apply_font(brand_banner_label, _font_semibold, _scaled_touch_font_size(38))
	brand_banner_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	brand_banner_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	brand_banner_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	brand_banner_label.add_theme_constant_override("outline_size", 0)
	brand_banner_label.add_theme_constant_override("shadow_offset_x", 0)
	brand_banner_label.add_theme_constant_override("shadow_offset_y", 0)
	var shader: Shader = _swarmfront_title_shader_resource()
	if shader == null:
		return
	var mat: ShaderMaterial = brand_banner_label.material as ShaderMaterial
	if mat == null or mat.shader == null or mat.shader != shader:
		mat = ShaderMaterial.new()
		mat.shader = shader
	else:
		mat = mat.duplicate() as ShaderMaterial
	brand_banner_label.material = mat
	mat.set_shader_parameter("backlight_color", Color(1.0, 0.831, 0.0, 1.0))
	mat.set_shader_parameter("halo_core_strength", 1.15)
	mat.set_shader_parameter("halo_outer_strength", 0.58)
	mat.set_shader_parameter("wall_spill_strength", 0.22)
	mat.set_shader_parameter("bevel_strength", 0.24)

func set_top_safe_inset(inset_px: float) -> void:
	set_content_top_offset(inset_px)

func set_content_top_offset(top_px: float) -> void:
	if root_vbox == null:
		return
	root_vbox.offset_top = BASE_CONTENT_MARGIN_TOP + maxf(0.0, top_px)

func _build_category_tabs() -> void:
	for child in category_tabs.get_children():
		child.queue_free()
	for label in _category_labels:
		var category_label: String = str(label)
		var button := Button.new()
		button.text = category_label
		button.toggle_mode = true
		button.button_pressed = category_label == _selected_category
		button.custom_minimum_size = Vector2(_category_tab_width(), 44.0)
		button.pressed.connect(Callable(self, "_on_category_tab_pressed").bind(category_label))
		category_tabs.add_child(button)
		_apply_font(button, _font_semibold, _scaled_touch_font_size(SELECTOR_TAB_FONT_SIZE))
		_style_button(button)
	_refresh_category_tab_widths()

func _on_category_tab_pressed(category_label: String) -> void:
	_selected_category = category_label
	_map_offset = 0
	_refresh_category_tab_state()
	_refresh_map_list()
	_select_first_visible_map()

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
		var period_label: String = str(label)
		var button := Button.new()
		button.text = period_label
		button.toggle_mode = true
		button.button_pressed = period_label == _selected_period
		button.custom_minimum_size = Vector2(_period_tab_width(), 34.0)
		button.pressed.connect(Callable(self, "_on_period_tab_pressed").bind(period_label))
		period_tabs.add_child(button)
		_apply_font(button, _font_semibold, _scaled_touch_font_size(12))
		_style_button(button)
	_refresh_period_tab_widths()

func _on_period_tab_pressed(period_label: String) -> void:
	_selected_period = period_label
	_leaderboard_offset = 0
	_refresh_period_tab_state()
	_refresh_leaderboard()

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
	_apply_font(map_count_label, _font_regular, _scaled_touch_font_size(SELECTOR_META_FONT_SIZE))
	var max_offset: int = maxi(0, visible_entries.size() - MAP_WINDOW_SIZE)
	_map_offset = clampi(_map_offset, 0, max_offset)
	var end_index: int = mini(_map_offset + MAP_WINDOW_SIZE, visible_entries.size())
	var top_card_width: float = _top_map_card_width()
	var bottom_card_width: float = _bottom_map_card_width()
	var card_font_size: int = _map_card_font_size(top_card_width)
	for entry_index in range(_map_offset, end_index):
		var entry: Dictionary = visible_entries[entry_index]
		var map_path: String = str(entry.get("path", ""))
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.toggle_mode = true
		row.button_pressed = map_path == _selected_map_path
		row.text = _map_card_text(entry)
		row.tooltip_text = str(entry.get("title", ""))
		row.custom_minimum_size = Vector2(
			top_card_width if (entry_index - _map_offset) < 3 else bottom_card_width,
			136.0 if _uses_touch_layout() else 116.0
		)
		row.pressed.connect(Callable(self, "_select_map").bind(map_path))
		if (entry_index - _map_offset) < 3:
			map_top_row.add_child(row)
		else:
			map_bottom_cards.add_child(row)
		_apply_font(row, _font_semibold, _scaled_touch_font_size(card_font_size))
		_style_button(row)
	_refresh_map_nav(visible_entries.size())

func _visible_map_entries() -> Array[Dictionary]:
	return _jukebox_state.catalog(_selected_category)

func _select_first_visible_map() -> void:
	var visible_entries: Array[Dictionary] = _visible_map_entries()
	if visible_entries.is_empty():
		_selected_map_path = ""
		_map_offset = 0
		selected_title_label.text = "NO MAPS"
		_apply_font(selected_title_label, _font_semibold, _scaled_touch_font_size(20))
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
	selected_title_label.text = _stylized_display_text(str(selected.get("title", "Map")))
	_apply_font(selected_title_label, _font_semibold, _scaled_touch_font_size(24))
	selected_meta_label.text = ""
	_apply_font(selected_meta_label, _font_semibold, _scaled_touch_font_size(16))
	selected_desc_label.text = ""
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
	header.custom_minimum_size = Vector2(0.0, 50.0 if _uses_touch_layout() else 42.0)
	var head_rank := Label.new()
	head_rank.text = "RANK"
	head_rank.custom_minimum_size = Vector2(88.0, 0.0)
	header.add_child(head_rank)
	_apply_font(head_rank, _font_semibold, _scaled_touch_font_size(LEADERBOARD_HEADER_FONT_SIZE))
	var head_handle := Label.new()
	head_handle.text = "HANDLE"
	head_handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(head_handle)
	_apply_font(head_handle, _font_semibold, _scaled_touch_font_size(LEADERBOARD_HEADER_FONT_SIZE))
	var head_badge := Label.new()
	head_badge.text = "BADGE"
	head_badge.custom_minimum_size = Vector2(132.0, 0.0)
	head_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(head_badge)
	_apply_font(head_badge, _font_semibold, _scaled_touch_font_size(LEADERBOARD_HEADER_FONT_SIZE))
	var head_time := Label.new()
	head_time.text = "TIME"
	head_time.custom_minimum_size = Vector2(220.0, 0.0)
	head_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(head_time)
	_apply_font(head_time, _font_semibold, _scaled_touch_font_size(LEADERBOARD_HEADER_FONT_SIZE))
	leaderboard_list.add_child(header)
	var entries: Array = board.get("entries", []) as Array
	var total_entries: int = entries.size()
	var max_offset: int = maxi(0, total_entries - PAGE_SIZE)
	_leaderboard_offset = clampi(_leaderboard_offset, 0, max_offset)
	if total_entries <= 0:
		var empty := Label.new()
		empty.text = "No recorded runs for this map yet."
		empty.custom_minimum_size = Vector2(0.0, 68.0 if _uses_touch_layout() else 58.0)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		leaderboard_list.add_child(empty)
		_apply_font(empty, _font_regular, _scaled_touch_font_size(LEADERBOARD_ROW_FONT_SIZE))
		_refresh_leaderboard_nav(0)
		your_best_label.text = "Your best: --"
		_refresh_map_best()
		return
	var end_index: int = mini(_leaderboard_offset + PAGE_SIZE, total_entries)
	for entry_index in range(_leaderboard_offset, end_index):
		var entry_any: Variant = entries[entry_index]
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		row.custom_minimum_size = Vector2(0.0, 54.0 if _uses_touch_layout() else 44.0)
		var rank_label := Label.new()
		rank_label.text = "%02d" % int(entry.get("rank", 0))
		rank_label.custom_minimum_size = Vector2(88.0, 0.0)
		row.add_child(rank_label)
		_apply_font(rank_label, _font_semibold, _scaled_touch_font_size(LEADERBOARD_ROW_FONT_SIZE))
		var handle_label := Label.new()
		handle_label.text = str(entry.get("handle", "--"))
		handle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(handle_label)
		_apply_font(handle_label, _font_regular, _scaled_touch_font_size(LEADERBOARD_ROW_FONT_SIZE))
		var badge_label := Label.new()
		badge_label.text = str(entry.get("badge", ""))
		badge_label.custom_minimum_size = Vector2(132.0, 0.0)
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(badge_label)
		_apply_font(badge_label, _font_regular, _scaled_touch_font_size(LEADERBOARD_BADGE_FONT_SIZE))
		var time_label := Label.new()
		time_label.text = _format_time_ms(int(entry.get("time_ms", 0)))
		time_label.custom_minimum_size = Vector2(220.0, 0.0)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(time_label)
		_apply_font(time_label, _font_semibold, _scaled_touch_font_size(LEADERBOARD_ROW_FONT_SIZE))
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
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null:
		if profile_manager.has_method("get_user_id"):
			player_id = str(profile_manager.call("get_user_id")).strip_edges()
		if profile_manager.has_method("get_display_name"):
			player_handle = str(profile_manager.call("get_display_name")).strip_edges()
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
		_apply_font(hero_preview_badge, _font_semibold, _scaled_touch_font_size(11))
		return
	hero_preview.texture = null
	hero_preview_badge.text = "PREVIEW COMING SOON"
	_apply_font(hero_preview_badge, _font_semibold, _scaled_touch_font_size(11))

func _refresh_map_nav(total_entries: int) -> void:
	var safe_total: int = maxi(0, total_entries)
	var start_index: int = 0
	var end_index: int = 0
	if safe_total > 0:
		start_index = _map_offset + 1
		end_index = mini(_map_offset + MAP_WINDOW_SIZE, safe_total)
	map_hint_label.text = "%d-%d / %d" % [start_index, end_index, safe_total]
	var has_multiple_pages: bool = safe_total > MAP_WINDOW_SIZE
	map_left_button.disabled = not has_multiple_pages
	map_right_button.disabled = not has_multiple_pages

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
	var total_entries: int = _visible_map_entries().size()
	var last_offset: int = _last_map_page_offset(total_entries)
	if total_entries <= MAP_WINDOW_SIZE:
		_map_offset = 0
	elif _map_offset <= 0:
		_map_offset = last_offset
	else:
		_map_offset = maxi(0, _map_offset - MAP_WINDOW_SIZE)
	_refresh_map_list()

func _on_map_right_pressed() -> void:
	var total_entries: int = _visible_map_entries().size()
	var last_offset: int = _last_map_page_offset(total_entries)
	if total_entries <= MAP_WINDOW_SIZE:
		_map_offset = 0
	elif _map_offset >= last_offset:
		_map_offset = 0
	else:
		_map_offset += MAP_WINDOW_SIZE
	_refresh_map_list()

func _last_map_page_offset(total_entries: int) -> int:
	return maxi(0, total_entries - MAP_WINDOW_SIZE)

func _on_play_pressed() -> void:
	if _selected_map_path.is_empty():
		return
	play_requested.emit(_selected_map_path, "", "")

func _stylized_display_text(text: String) -> String:
	var display_text: String = text.strip_edges().to_upper().replace("_", " ")
	while display_text.contains("  "):
		display_text = display_text.replace("  ", " ")
	if display_text.is_empty():
		return text.to_upper()
	return display_text

func _map_card_text(entry: Dictionary) -> String:
	return _stylized_display_text(str(entry.get("title", "")))

func _humanize_token(value: String) -> String:
	var clean: String = value.strip_edges().replace("_", " ")
	if clean.is_empty():
		return ""
	var parts: PackedStringArray = clean.split(" ", false)
	var words: Array[String] = []
	for part_any in parts:
		var part: String = str(part_any).strip_edges()
		if part.is_empty():
			continue
		words.append(part.substr(0, 1).to_upper() + part.substr(1).to_lower())
	return " ".join(words)

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
	UITypography.apply_font(control, font, size)

func _uses_touch_layout() -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	return viewport_size.y > viewport_size.x or viewport_size.x <= TOUCH_LAYOUT_MAX_WIDTH

func _scaled_touch_font_size(size_value: int) -> int:
	if not _uses_touch_layout():
		return size_value
	return maxi(1, int(round(float(size_value) * TOUCH_LAYOUT_FONT_SCALE)))

func _style_nav_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(88.0, 60.0) if _uses_touch_layout() else Vector2(76.0, 52.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)

func _style_selector_nav_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(_selector_nav_width(), 106.0 if _uses_touch_layout() else 92.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)

func _style_play_button() -> void:
	if play_button == null:
		return
	play_button.custom_minimum_size = Vector2(_play_button_width(), 166.0 if _uses_touch_layout() else 150.0)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.text = ""
	play_button.tooltip_text = "Play selected map"
	play_button.flat = true
	play_button.icon = null
	if play_sprite != null:
		if play_sprite.texture == null and _play_texture != null:
			play_sprite.texture = _play_texture
		play_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		play_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

func _content_width() -> float:
	var width: float = size.x
	if root_vbox != null and root_vbox.size.x > 0.0:
		width = root_vbox.size.x
	if width <= 0.0:
		var viewport: Viewport = get_viewport()
		if viewport != null:
			width = viewport.get_visible_rect().size.x
	return maxf(1.0, width - 56.0)

func _category_tab_width() -> float:
	var count: int = maxi(1, _category_labels.size())
	var separation: float = 8.0
	var available: float = _content_width() - separation * float(maxi(0, count - 1))
	return clampf(floor(available / float(count)), CATEGORY_TAB_MIN_WIDTH, CATEGORY_TAB_MAX_WIDTH)

func _period_tab_width() -> float:
	var count: int = maxi(1, _jukebox_state.PERIOD_LABELS.size())
	var separation: float = 8.0
	var available: float = _content_width() - separation * float(maxi(0, count - 1))
	return clampf(floor(available / float(count)), PERIOD_TAB_MIN_WIDTH, PERIOD_TAB_MAX_WIDTH)

func _top_map_card_width() -> float:
	var available: float = _content_width()
	var separation: float = 10.0
	return clampf(floor((available - separation * 2.0) / 3.0), MAP_CARD_MIN_WIDTH, MAP_CARD_MAX_WIDTH)

func _bottom_map_card_width() -> float:
	var available: float = _content_width()
	var nav_width: float = _selector_nav_width() * 2.0
	var row_separation: float = 20.0
	var card_separation: float = 10.0
	return clampf(floor((available - nav_width - row_separation - card_separation) / 2.0), MAP_CARD_MIN_WIDTH, MAP_CARD_MAX_WIDTH)

func _selector_nav_width() -> float:
	var available: float = _content_width()
	return clampf(floor(available * 0.14), SELECTOR_NAV_MIN_WIDTH, SELECTOR_NAV_MAX_WIDTH)

func _play_button_width() -> float:
	return clampf(_content_width(), PLAY_BUTTON_MIN_WIDTH, PLAY_BUTTON_MAX_WIDTH)

func _map_card_font_size(card_width: float) -> int:
	if card_width < 120.0:
		return 14
	if card_width < 170.0:
		return 16
	if card_width < 230.0:
		return 20
	return SELECTOR_CARD_FONT_SIZE

func _refresh_category_tab_widths() -> void:
	if category_tabs == null:
		return
	var width: float = _category_tab_width()
	for child in category_tabs.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.x = width

func _refresh_period_tab_widths() -> void:
	if period_tabs == null:
		return
	var width: float = _period_tab_width()
	for child in period_tabs.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.x = width

func _refresh_play_button_width() -> void:
	if play_button != null:
		play_button.custom_minimum_size.x = _play_button_width()

func _refresh_selector_nav_widths() -> void:
	var width: float = _selector_nav_width()
	for button in [map_left_button, map_right_button]:
		if button != null:
			button.custom_minimum_size.x = width

func _refresh_map_card_widths() -> void:
	var top_width: float = _top_map_card_width()
	var bottom_width: float = _bottom_map_card_width()
	var font_size: int = _map_card_font_size(top_width)
	for child in map_top_row.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.x = top_width
			(child as Control).custom_minimum_size.y = 136.0 if _uses_touch_layout() else 116.0
			_apply_font(child as Control, _font_semibold, _scaled_touch_font_size(font_size))
	for child in map_bottom_cards.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.x = bottom_width
			(child as Control).custom_minimum_size.y = 136.0 if _uses_touch_layout() else 116.0
			_apply_font(child as Control, _font_semibold, _scaled_touch_font_size(_map_card_font_size(bottom_width)))

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
