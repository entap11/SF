extends Panel
class_name JukeboxPanel

const JukeboxStateScript := preload("res://scripts/state/jukebox_state.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MapSchematicPreviewScript := preload("res://scripts/ui/map_schematic_preview.gd")
const UITypography := preload("res://scripts/ui/ui_typography.gd")
const HexSeamBackgroundScript := preload("res://ui/backgrounds/HexSeamBackground.gd")
const CHEVRON_TEXTURE_PATH := "res://assets/sprites/sf_skin_v1/up_down_chevron.png"
const SIDE_CHEVRON_TEXTURE_PATH := "res://assets/sprites/sf_skin_v1/Left_right_chevrons.png"
const PLAY_TEXTURE_PATH := "res://assets/sprites/sf_skin_v1/play.png"
const MAIN_MENU_TEXTURE_PATH := "res://assets/sprites/sf_skin_v1/Back.png"
const BRAND_BANNER_TEXTURE_PATH := "res://assets/sprites/sf_skin_v1/signage_banner_reflect_red.tres"
const SWARMFRONT_TITLE_SHADER_PATH := "res://ui/main_menu/swarmfront_title_forged.gdshader"
const PAGE_SIZE: int = 3
const LEADERBOARD_LANDSCAPE_PAGE_SIZE: int = 5
const MAP_WINDOW_SIZE: int = 6
const SELECTOR_META_FONT_SIZE: int = 22
const SELECTOR_TAB_FONT_SIZE: int = 20
const SELECTOR_CARD_FONT_SIZE: int = 28
const LEADERBOARD_HEADER_FONT_SIZE: int = 22
const LEADERBOARD_ROW_FONT_SIZE: int = 24
const LEADERBOARD_FONT_SCALE: float = 2.0
const BASE_CONTENT_MARGIN_TOP: float = 18.0
const CATEGORY_TAB_MIN_WIDTH: float = 86.0
const CATEGORY_TAB_MAX_WIDTH: float = 158.0
const PERIOD_TAB_MIN_WIDTH: float = 94.0
const PERIOD_TAB_MAX_WIDTH: float = 132.0
const MAP_CARD_MIN_WIDTH: float = 180.0
const MAP_CARD_MAX_WIDTH: float = 520.0
const PLAY_BUTTON_MIN_WIDTH: float = 260.0
const PLAY_BUTTON_MAX_WIDTH: float = 380.0
const PLAY_BUTTON_SIDE_MIN_WIDTH: float = 150.0
const PLAY_BUTTON_HEIGHT: float = 126.0
const SELECTOR_NAV_MIN_WIDTH: float = 67.0
const SELECTOR_NAV_MAX_WIDTH: float = 110.0
const TOUCH_LAYOUT_MAX_WIDTH: float = 1100.0
const TOUCH_LAYOUT_FONT_SCALE: float = 1.35
const SELECTOR_PANEL_MIN_HEIGHT: float = 300.0
const HERO_PANEL_MIN_HEIGHT: float = 390.0
const LEADERBOARD_PANEL_MIN_HEIGHT: float = 160.0
const PREVIEW_HEIGHT_RATIO: float = 0.29
const PREVIEW_MIN_HEIGHT: float = 260.0
const PREVIEW_MAX_HEIGHT: float = 620.0
const SELECTED_CARD_HORIZONTAL_PAD: float = 24.0
const SELECTED_CARD_MIN_WIDTH: float = 360.0
const SELECTED_CARD_MAX_WIDTH: float = 560.0
const SELECTED_CARD_SIDE_MAX_WIDTH: float = 980.0
const SELECTED_CARD_SIDE_BREAKPOINT: float = 360.0
const SELECTED_CARD_COLUMN_GAP: float = 10.0
const LEADERBOARD_SIDE_MIN_WIDTH: float = 140.0
const LEADERBOARD_SIDE_MAX_WIDTH: float = 560.0
const LEADERBOARD_STACK_MAX_WIDTH: float = 470.0
const BRAND_BANNER_TOUCH_HEIGHT: float = 144.0
const BRAND_BANNER_DESKTOP_HEIGHT: float = 116.0
const BRAND_BANNER_NARROW_OVERHANG: float = 1.34

signal closed
signal play_requested(map_path: String, cpu_style: String, cpu_tier: String)

const TOP_LIMIT: int = 50

@onready var brand_banner_label: Label = get_node_or_null("VBox/BrandBanner") as Label
@onready var selector_panel: Panel = $VBox/SelectorPanel
@onready var hero_panel: Panel = $VBox/HeroPanel
@onready var title_label: Label = $VBox/SelectorPanel/SelectorVBox/Header/Title
@onready var sub_label: Label = $VBox/SelectorPanel/SelectorVBox/Header/Sub
@onready var category_tabs: HBoxContainer = $VBox/SelectorPanel/SelectorVBox/CategoryTabs
@onready var map_list: VBoxContainer = $VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapList
@onready var map_left_button: Button = $VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapBottomRow/MapLeft
@onready var map_right_button: Button = $VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapBottomRow/MapRight
@onready var map_left_sprite: TextureRect = $VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapBottomRow/MapLeft/ChevronSprite
@onready var map_right_sprite: TextureRect = $VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapBottomRow/MapRight/ChevronSprite
@onready var map_count_label: Label = $VBox/SelectorPanel/SelectorVBox/SelectorMetaRow/MapCount
@onready var map_hint_label: Label = $VBox/SelectorPanel/SelectorVBox/SelectorMetaRow/MapHint
@onready var hero_preview: TextureRect = $VBox/HeroPanel/HeroVBox/HeroPreviewPanel/HeroPreview
@onready var hero_preview_panel: Panel = $VBox/HeroPanel/HeroVBox/HeroPreviewPanel
@onready var hero_preview_badge: Label = $VBox/HeroPanel/HeroVBox/HeroPreviewPanel/HeroPreviewBadge
@onready var selected_title_label: Label = $VBox/HeroPanel/HeroVBox/SelectedTitle
@onready var selected_meta_label: Label = $VBox/HeroPanel/HeroVBox/SelectedMeta
@onready var selected_desc_label: Label = $VBox/HeroPanel/HeroVBox/SelectedDesc
@onready var play_button: Button = $VBox/HeroPanel/HeroVBox/PlayButton
@onready var play_sprite: TextureRect = $VBox/HeroPanel/HeroVBox/PlayButton/PlaySprite
@onready var scout_button: Button = $VBox/HeroPanel/HeroVBox/HeroActions/ScoutButton
@onready var close_button: Button = $VBox/HeroPanel/HeroVBox/HeroActions/CloseButton
@onready var cpu_panel: Panel = $VBox/CpuPanel
@onready var leaderboard_panel: Panel = $VBox/LeaderboardPanel
@onready var leaderboard_vbox: VBoxContainer = $VBox/LeaderboardPanel/LeaderboardVBox
@onready var period_tabs: HBoxContainer = $VBox/LeaderboardPanel/LeaderboardVBox/PeriodTabs
@onready var leaderboard_list: VBoxContainer = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardScroll/LeaderboardList
@onready var leaderboard_nav: HBoxContainer = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav
@onready var leaderboard_up_button: Button = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav/LeaderboardUp
@onready var leaderboard_page_label: Label = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav/LeaderboardPage
@onready var leaderboard_down_button: Button = $VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav/LeaderboardDown
@onready var your_best_label: Label = $VBox/LeaderboardPanel/LeaderboardVBox/YourBestLift/YourBest
@onready var footer_close_button: Button = $VBox/FooterCloseButton
@onready var footer_close_sprite: TextureRect = $VBox/FooterCloseButton/MainMenuSprite
@onready var root_vbox: VBoxContainer = $VBox

var _font_regular: Font = null
var _font_semibold: Font = null
var _swarmfront_title_shader: Shader = null
var _chevron_texture: Texture2D = null
var _side_chevron_texture: Texture2D = null
var _play_texture: Texture2D = null
var _main_menu_texture: Texture2D = null
var _brand_banner_texture: Texture2D = null
var _brand_banner_image: TextureRect = null
var _jukebox_state = JukeboxStateScript.new()
var _category_labels: Array[String] = ["ALL"]
var _selected_category: String = "ALL"
var _selected_period: String = "WEEKLY"
var _selected_map_path: String = ""
var _map_offset: int = 0
var _leaderboard_offset: int = 0
var _map_schematic_preview: Control = null
var _highlight_player_id: String = ""
var _highlight_until_msec: int = 0
var _page_background: Control = null
var _selected_preview_aspect: float = 1.0
var _selected_preview_is_schematic: bool = true
var _hero_middle_row: HBoxContainer = null
var _preview_column: VBoxContainer = null

func _ready() -> void:
	visible = false
	resized.connect(_on_panel_resized)
	_wrap_category_tabs_for_scroll()
	_load_fonts()
	title_label.text = "MAP JUKEBOX"
	sub_label.text = "BROWSE MAPS  CHASE RECORDS"
	scout_button.text = "SCOUT TOP RUN PREMIUM SOON"
	_style_controls()
	_apply_responsive_layout()
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
	_sync_content_layout()
	_sync_selector_hierarchy()
	_sync_selected_card_layout()
	_refresh_primary_heights()
	_refresh_brand_scale()
	_refresh_selector_nav_widths()
	_refresh_category_tab_widths()
	_refresh_period_tab_widths()
	_refresh_hero_preview_size()
	_refresh_play_button_width()
	_refresh_selected_card_size()
	_refresh_map_card_widths()

func _sync_content_layout() -> void:
	if root_vbox == null or selector_panel == null or hero_panel == null:
		return
	if hero_panel.get_parent() != root_vbox:
		_reparent_keep_owner(hero_panel, root_vbox)
	if leaderboard_panel != null and leaderboard_panel.get_parent() != root_vbox:
		_reparent_keep_owner(leaderboard_panel, root_vbox)
	root_vbox.move_child(hero_panel, 1)
	if leaderboard_panel != null:
		root_vbox.move_child(leaderboard_panel, 2)
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hero_panel.custom_minimum_size = Vector2(maxf(hero_panel.custom_minimum_size.x, SELECTED_CARD_MIN_WIDTH), HERO_PANEL_MIN_HEIGHT)
	var hero_vbox: VBoxContainer = hero_panel.get_node_or_null("HeroVBox") as VBoxContainer
	if hero_vbox != null:
		hero_vbox.add_theme_constant_override("separation", 5)

func _sync_selected_card_layout() -> void:
	var hero_vbox: VBoxContainer = null
	if hero_panel != null:
		hero_vbox = hero_panel.get_node_or_null("HeroVBox") as VBoxContainer
	if hero_vbox == null or leaderboard_panel == null:
		return
	_ensure_selected_card_containers(hero_vbox)
	var use_side_layout: bool = _uses_side_leaderboard_layout()
	leaderboard_panel.visible = true
	if leaderboard_panel.get_parent() != root_vbox:
		_reparent_keep_owner(leaderboard_panel, root_vbox)
	root_vbox.move_child(leaderboard_panel, mini(hero_panel.get_index() + 1, root_vbox.get_child_count() - 1))
	leaderboard_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leaderboard_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	leaderboard_panel.custom_minimum_size = Vector2(0.0, _leaderboard_panel_height())
	if use_side_layout:
		_hero_middle_row.visible = true
		if _hero_middle_row.get_parent() != hero_vbox:
			_reparent_keep_owner(_hero_middle_row, hero_vbox)
		hero_vbox.move_child(_hero_middle_row, mini(selected_meta_label.get_index() + 1, hero_vbox.get_child_count() - 1))
		if _preview_column.get_parent() != _hero_middle_row:
			_reparent_keep_owner(_preview_column, _hero_middle_row)
		if selector_panel.get_parent() != _hero_middle_row:
			_reparent_keep_owner(selector_panel, _hero_middle_row)
		_hero_middle_row.move_child(_preview_column, 0)
		_hero_middle_row.move_child(selector_panel, 1)
		_hero_middle_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		_hero_middle_row.add_theme_constant_override("separation", int(SELECTED_CARD_COLUMN_GAP))
		_hero_middle_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_preview_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		selector_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		selector_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		selector_panel.custom_minimum_size = Vector2(_selector_side_panel_width(), _selector_panel_height())
		hero_preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		play_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		_hero_middle_row.visible = false
		if _preview_column.get_parent() != hero_vbox:
			_reparent_keep_owner(_preview_column, hero_vbox)
		if selector_panel.get_parent() != hero_vbox:
			_reparent_keep_owner(selector_panel, hero_vbox)
		hero_vbox.move_child(_preview_column, mini(selected_meta_label.get_index() + 1, hero_vbox.get_child_count() - 1))
		hero_vbox.move_child(selector_panel, mini(_preview_column.get_index() + 1, hero_vbox.get_child_count() - 1))
		_preview_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		selector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		selector_panel.custom_minimum_size = Vector2(0.0, _selector_panel_height())
		hero_preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_refresh_leaderboard_compact_controls()

func _ensure_selected_card_containers(hero_vbox: VBoxContainer) -> void:
	if _preview_column == null or not is_instance_valid(_preview_column):
		_preview_column = hero_vbox.get_node_or_null("PreviewColumn") as VBoxContainer
		if _preview_column == null:
			_preview_column = VBoxContainer.new()
			_preview_column.name = "PreviewColumn"
			_preview_column.alignment = BoxContainer.ALIGNMENT_CENTER
			_preview_column.add_theme_constant_override("separation", 5)
			_preview_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_preview_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			hero_vbox.add_child(_preview_column)
	if _hero_middle_row == null or not is_instance_valid(_hero_middle_row):
		_hero_middle_row = hero_vbox.get_node_or_null("SelectedMiddleRow") as HBoxContainer
		if _hero_middle_row == null:
			_hero_middle_row = HBoxContainer.new()
			_hero_middle_row.name = "SelectedMiddleRow"
			_hero_middle_row.alignment = BoxContainer.ALIGNMENT_BEGIN
			_hero_middle_row.add_theme_constant_override("separation", int(SELECTED_CARD_COLUMN_GAP))
			_hero_middle_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_hero_middle_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			hero_vbox.add_child(_hero_middle_row)
	if hero_preview_panel.get_parent() != _preview_column:
		_reparent_keep_owner(hero_preview_panel, _preview_column)
	if play_button.get_parent() != _preview_column:
		_reparent_keep_owner(play_button, _preview_column)
	_preview_column.move_child(hero_preview_panel, 0)
	_preview_column.move_child(play_button, 1)

func _sync_selector_hierarchy() -> void:
	if selector_panel == null or category_tabs == null:
		return
	var selector_vbox: VBoxContainer = selector_panel.get_node_or_null("SelectorVBox") as VBoxContainer
	if selector_vbox == null:
		return
	var header: Control = selector_vbox.get_node_or_null("Header") as Control
	if header != null:
		header.visible = false
		header.custom_minimum_size = Vector2.ZERO
	var map_rows: Control = selector_vbox.get_node_or_null("MapSelectorRows") as Control
	var category_host: Control = category_tabs.get_parent() as Control
	var meta_row: Control = selector_vbox.get_node_or_null("SelectorMetaRow") as Control
	if map_rows != null:
		selector_vbox.move_child(map_rows, 0)
	if category_host != null and category_host.get_parent() == selector_vbox:
		selector_vbox.move_child(category_host, 1)
		category_host.custom_minimum_size = Vector2(0.0, 58.0)
	if meta_row != null:
		selector_vbox.move_child(meta_row, 2)
		meta_row.custom_minimum_size = Vector2(0.0, 34.0)

func _refresh_primary_heights() -> void:
	var layout_height: float = _layout_height()
	var preview_height: float = _target_preview_height()
	var selected_height: float = preview_height + PLAY_BUTTON_HEIGHT + (144.0 if _uses_touch_layout() else 116.0)
	if not _uses_side_leaderboard_layout():
		selected_height += _selector_panel_height() + 12.0
	if hero_panel != null:
		hero_panel.custom_minimum_size = Vector2(maxf(hero_panel.custom_minimum_size.x, SELECTED_CARD_MIN_WIDTH), maxf(HERO_PANEL_MIN_HEIGHT, selected_height))
	if selector_panel != null:
		var selector_width: float = _selector_side_panel_width() if _uses_side_leaderboard_layout() else 0.0
		selector_panel.custom_minimum_size = Vector2(selector_width, _selector_panel_height())
	if leaderboard_panel != null:
		leaderboard_panel.custom_minimum_size = Vector2(0.0, _leaderboard_panel_height())

func _refresh_brand_scale() -> void:
	var height: float = BRAND_BANNER_TOUCH_HEIGHT if _uses_touch_layout() else BRAND_BANNER_DESKTOP_HEIGHT
	if _brand_banner_image != null and is_instance_valid(_brand_banner_image):
		_brand_banner_image.custom_minimum_size = Vector2(_brand_banner_width(height), height)
		_brand_banner_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if brand_banner_label != null:
		brand_banner_label.custom_minimum_size = Vector2(0.0, height)

func _reparent_keep_owner(child: Node, new_parent: Node) -> void:
	if child == null or new_parent == null or child.get_parent() == new_parent:
		return
	var old_parent: Node = child.get_parent()
	if old_parent != null:
		old_parent.remove_child(child)
	new_parent.add_child(child)

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
	_highlight_player_id = str(snapshot.get("highlight_player_id", "")).strip_edges()
	_highlight_until_msec = Time.get_ticks_msec() + 8000 if not _highlight_player_id.is_empty() else 0
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
	if ResourceLoader.exists(MAIN_MENU_TEXTURE_PATH):
		_main_menu_texture = load(MAIN_MENU_TEXTURE_PATH) as Texture2D
	if ResourceLoader.exists(BRAND_BANNER_TEXTURE_PATH):
		_brand_banner_texture = load(BRAND_BANNER_TEXTURE_PATH) as Texture2D

func _ensure_swarmfront_banner() -> void:
	if root_vbox == null:
		return
	if _brand_banner_image != null and is_instance_valid(_brand_banner_image):
		return
	var existing: Label = root_vbox.get_node_or_null("BrandBanner") as Label
	if existing != null:
		brand_banner_label = existing
	if brand_banner_label == null:
		var label := Label.new()
		label.name = "BrandBanner"
		label.custom_minimum_size = Vector2(0.0, 88.0)
		label.text = "SWARMFRONT"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		root_vbox.add_child(label)
		root_vbox.move_child(label, 0)
		brand_banner_label = label
	if _brand_banner_texture == null:
		return
	var image := TextureRect.new()
	image.name = "BrandBannerArt"
	image.texture = _brand_banner_texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.custom_minimum_size = Vector2(_brand_banner_width(BRAND_BANNER_TOUCH_HEIGHT), BRAND_BANNER_TOUCH_HEIGHT)
	root_vbox.add_child(image)
	root_vbox.move_child(image, 0)
	_brand_banner_image = image
	if brand_banner_label != null:
		brand_banner_label.visible = false
		brand_banner_label.custom_minimum_size = Vector2.ZERO

func _style_controls() -> void:
	_ensure_page_background()
	_style_panel_surfaces()
	_ensure_swarmfront_banner()
	_apply_swarmfront_banner_style()
	if selector_panel != null:
		selector_panel.custom_minimum_size = Vector2(0.0, SELECTOR_PANEL_MIN_HEIGHT)
	if hero_panel != null:
		hero_panel.custom_minimum_size = Vector2(0.0, HERO_PANEL_MIN_HEIGHT)
	if leaderboard_panel != null:
		leaderboard_panel.custom_minimum_size = Vector2(0.0, LEADERBOARD_PANEL_MIN_HEIGHT)
	_apply_font(title_label, _font_semibold, _scaled_touch_font_size(24))
	_apply_font(sub_label, _font_regular, _scaled_touch_font_size(16))
	_apply_font(map_count_label, _font_regular, _scaled_touch_font_size(SELECTOR_META_FONT_SIZE))
	_apply_font(map_hint_label, _font_regular, _scaled_touch_font_size(SELECTOR_META_FONT_SIZE - 1))
	_apply_font(hero_preview_badge, _font_semibold, _scaled_touch_font_size(16))
	_apply_font(selected_title_label, _font_semibold, _scaled_touch_font_size(46))
	_apply_font(selected_meta_label, _font_semibold, _scaled_touch_font_size(24))
	_apply_font(selected_desc_label, _font_regular, _scaled_touch_font_size(20))
	if selected_desc_label != null:
		selected_desc_label.visible = false
		selected_desc_label.custom_minimum_size = Vector2.ZERO
	if cpu_panel != null:
		cpu_panel.visible = false
		cpu_panel.custom_minimum_size = Vector2.ZERO
	_apply_font(leaderboard_page_label, _font_semibold, _scaled_touch_font_size(22))
	_apply_font(your_best_label, _font_semibold, _scaled_touch_font_size(26))
	_apply_font(play_button, _font_semibold, _scaled_touch_font_size(38))
	_style_button(play_button)
	_style_play_button()
	_ensure_map_schematic_preview()
	if scout_button != null:
		scout_button.visible = false
	if close_button != null:
		close_button.visible = false
	var hero_actions: Control = null
	if close_button != null:
		hero_actions = close_button.get_parent() as Control
	if hero_actions != null:
		hero_actions.visible = false
		hero_actions.custom_minimum_size = Vector2.ZERO
	if footer_close_button != null:
		if footer_close_button.get_parent() != self:
			_reparent_keep_owner(footer_close_button, self)
		footer_close_button.visible = true
		footer_close_button.text = "BACK TO MAIN MENU"
		footer_close_button.tooltip_text = "Return to Main Menu"
		footer_close_button.custom_minimum_size = Vector2(640.0, 100.0)
		footer_close_button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		footer_close_button.offset_left = 132.0
		footer_close_button.offset_top = -120.0
		footer_close_button.offset_right = -132.0
		footer_close_button.offset_bottom = -20.0
		footer_close_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_apply_font(footer_close_button, _font_semibold, _scaled_touch_font_size(28))
		_style_footer_back_button(footer_close_button)
		footer_close_button.z_index = 20
	if root_vbox != null:
		root_vbox.offset_bottom = -156.0
	var footer_spacer: Control = get_node_or_null("VBox/FooterSafeSpacer") as Control
	if footer_spacer != null:
		footer_spacer.visible = false
		footer_spacer.custom_minimum_size = Vector2.ZERO
		footer_spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for button in [map_left_button, map_right_button]:
		_apply_font(button, _font_semibold, _scaled_touch_font_size(11))
		_style_button(button)
		_style_selector_nav_button(button)
	for button in [leaderboard_up_button, leaderboard_down_button]:
		_apply_font(button, _font_semibold, _scaled_touch_font_size(11))
		_style_button(button)
		_style_nav_button(button)
	scout_button.disabled = true
	hero_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_refresh_hero_preview_size()
	_apply_nav_icons()
	_apply_selector_nav_icons()

func _ensure_page_background() -> void:
	if _page_background != null and is_instance_valid(_page_background):
		return
	var existing: Control = get_node_or_null("JukeboxHexBackground") as Control
	if existing != null:
		_page_background = existing
		return
	var background: Control = HexSeamBackgroundScript.new() as Control
	background.name = "JukeboxHexBackground"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.offset_left = 0.0
	background.offset_top = 0.0
	background.offset_right = 0.0
	background.offset_bottom = 0.0
	if background.has_method("apply_preset"):
		background.call("apply_preset", StringName("dash"))
	add_child(background)
	move_child(background, 0)
	_page_background = background

func _style_panel_surfaces() -> void:
	_add_panel_style(self, Color(0.025, 0.028, 0.034, 0.12), Color(1.0, 0.78, 0.08, 0.04), 0, 0)
	_add_panel_style(selector_panel, Color(0.055, 0.060, 0.072, 0.30), Color(1.0, 0.80, 0.12, 0.08), 8, 1)
	_add_panel_style(hero_panel, Color(0.048, 0.052, 0.064, 0.48), Color(1.0, 0.80, 0.12, 0.16), 8, 1)
	_add_panel_style(leaderboard_panel, Color(0.048, 0.052, 0.064, 0.24), Color(1.0, 0.80, 0.12, 0.06), 8, 1)
	if hero_preview_panel != null:
		_add_panel_style(hero_preview_panel, Color(0.010, 0.011, 0.014, 0.62), Color(1.0, 0.78, 0.08, 0.22), 8, 1)

func _add_panel_style(panel: Control, bg_color: Color, border_color: Color, corner_radius: int = 0, border_width: int = 0) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	panel.add_theme_stylebox_override("panel", style)

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
	if not UITypography.apply_free_roll_atlas_font(brand_banner_label, 27):
		_apply_font(brand_banner_label, _font_semibold, _scaled_touch_font_size(30))
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
		button.custom_minimum_size = Vector2(_category_tab_width(), 58.0)
		button.pressed.connect(Callable(self, "_on_category_tab_pressed").bind(category_label))
		category_tabs.add_child(button)
		_apply_font(button, _font_semibold, _scaled_touch_font_size(SELECTOR_TAB_FONT_SIZE))
		_style_button(button)
		button.modulate = Color(1.0, 1.0, 1.0, 0.86 if button.button_pressed else 0.68)
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
		button.modulate = Color(1.0, 1.0, 1.0, 0.86 if button.button_pressed else 0.68)

func _build_period_tabs() -> void:
	for child in period_tabs.get_children():
		child.queue_free()
	for label in _jukebox_state.PERIOD_LABELS:
		var period_label: String = str(label)
		var button := Button.new()
		button.text = period_label
		button.set_meta("period_label", period_label)
		button.toggle_mode = true
		button.button_pressed = period_label == _selected_period
		button.custom_minimum_size = Vector2(_period_tab_width(), 44.0)
		button.pressed.connect(Callable(self, "_on_period_tab_pressed").bind(period_label))
		period_tabs.add_child(button)
		_apply_font(button, _font_semibold, _scaled_touch_font_size(12))
		_style_button(button)
		button.modulate = Color(1.0, 1.0, 1.0, 0.78 if button.button_pressed else 0.58)
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
		var period_label: String = str(button.get_meta("period_label", button.text))
		button.button_pressed = period_label == _selected_period
		button.modulate = Color(1.0, 1.0, 1.0, 0.78 if button.button_pressed else 0.58)

func _refresh_map_list() -> void:
	for child in map_list.get_children():
		child.queue_free()
	var visible_entries: Array[Dictionary] = _visible_map_entries()
	if _selected_map_path.is_empty() and not visible_entries.is_empty():
		_selected_map_path = str(visible_entries[0].get("path", "")).strip_edges()
	if not _selected_map_path.is_empty() and _entry_by_path(_selected_map_path).is_empty() and not visible_entries.is_empty():
		_selected_map_path = str(visible_entries[0].get("path", "")).strip_edges()
	if play_button != null:
		_set_play_button_disabled(_selected_map_path.is_empty())
	map_count_label.text = "%d maps in %s" % [visible_entries.size(), _selected_category]
	_apply_font(map_count_label, _font_regular, _scaled_touch_font_size(SELECTOR_META_FONT_SIZE))
	var max_offset: int = maxi(0, visible_entries.size() - MAP_WINDOW_SIZE)
	_map_offset = clampi(_map_offset, 0, max_offset)
	var end_index: int = mini(_map_offset + MAP_WINDOW_SIZE, visible_entries.size())
	var card_width: float = _map_card_width()
	var card_font_size: int = _map_card_font_size(card_width)
	for entry_index in range(_map_offset, end_index):
		var entry: Dictionary = visible_entries[entry_index]
		var map_path: String = str(entry.get("path", ""))
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.toggle_mode = true
		row.button_pressed = map_path == _selected_map_path
		row.text = _map_card_text(entry)
		row.tooltip_text = str(entry.get("title", ""))
		row.modulate = Color(1.0, 1.0, 1.0, 1.0 if row.button_pressed else 0.84)
		row.custom_minimum_size = Vector2(
			card_width,
			66.0 if _uses_touch_layout() else 52.0
		)
		row.pressed.connect(Callable(self, "_select_map").bind(map_path))
		map_list.add_child(row)
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
		if play_button != null:
			_set_play_button_disabled(true)
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
	_apply_font(selected_title_label, _font_semibold, _scaled_touch_font_size(46))
	selected_meta_label.text = _selected_map_meta_text(selected)
	_apply_font(selected_meta_label, _font_semibold, _scaled_touch_font_size(24))
	selected_desc_label.text = ""
	_refresh_hero_preview(selected)
	_set_play_button_disabled(_selected_map_path.is_empty())
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
		return
	var board: Dictionary = _jukebox_state.board_snapshot(_selected_map_path, _selected_period, TOP_LIMIT)
	var page_size: int = _leaderboard_page_size()
	var micro_side: bool = _uses_micro_side_leaderboard()
	var row_separation: int = 6 if _uses_side_leaderboard_layout() else 12
	var rank_width: float = 70.0 if _uses_side_leaderboard_layout() else 58.0
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", row_separation)
	header.custom_minimum_size = Vector2(0.0, _leaderboard_header_height())
	var head_rank := Label.new()
	head_rank.text = "RANK"
	head_rank.custom_minimum_size = Vector2(rank_width, 0.0)
	header.add_child(head_rank)
	_apply_font(head_rank, _font_semibold, _leaderboard_font_size(LEADERBOARD_HEADER_FONT_SIZE))
	var head_handle := Label.new()
	head_handle.text = "HANDLE"
	head_handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(head_handle)
	_apply_font(head_handle, _font_semibold, _leaderboard_font_size(LEADERBOARD_HEADER_FONT_SIZE))
	if not micro_side:
		var head_time := Label.new()
		head_time.text = "TIME"
		head_time.custom_minimum_size = Vector2(132.0 if _uses_side_leaderboard_layout() else 128.0, 0.0)
		head_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(head_time)
		_apply_font(head_time, _font_semibold, _leaderboard_font_size(LEADERBOARD_HEADER_FONT_SIZE))
	leaderboard_list.add_child(header)
	var entries: Array = board.get("entries", []) as Array
	var total_entries: int = entries.size()
	var max_offset: int = maxi(0, total_entries - page_size)
	if not _highlight_player_id.is_empty() and Time.get_ticks_msec() <= _highlight_until_msec:
		for highlight_index in range(entries.size()):
			var highlight_entry_any: Variant = entries[highlight_index]
			if typeof(highlight_entry_any) != TYPE_DICTIONARY:
				continue
			var highlight_entry: Dictionary = highlight_entry_any as Dictionary
			if str(highlight_entry.get("player_id", "")).strip_edges() == _highlight_player_id:
				if highlight_index < _leaderboard_offset or highlight_index >= _leaderboard_offset + page_size:
					_leaderboard_offset = clampi(highlight_index, 0, max_offset)
				break
	_leaderboard_offset = clampi(_leaderboard_offset, 0, max_offset)
	for slot_index in range(page_size):
		var entry_index: int = _leaderboard_offset + slot_index
		var entry: Dictionary = {}
		var has_entry: bool = false
		if entry_index < total_entries:
			var entry_any: Variant = entries[entry_index]
			if typeof(entry_any) == TYPE_DICTIONARY:
				entry = entry_any as Dictionary
				has_entry = true
		var row := HBoxContainer.new()
		row.set_meta("leaderboard_placeholder", not has_entry)
		row.set_meta("leaderboard_slot_rank", entry_index + 1)
		row.add_theme_constant_override("separation", row_separation)
		row.custom_minimum_size = Vector2(0.0, _leaderboard_row_height())
		var rank_label := Label.new()
		rank_label.text = "%d." % int(entry.get("rank", entry_index + 1))
		rank_label.custom_minimum_size = Vector2(rank_width, 0.0)
		row.add_child(rank_label)
		_apply_font(rank_label, _font_semibold, _leaderboard_font_size(LEADERBOARD_ROW_FONT_SIZE))
		var handle_label := Label.new()
		handle_label.text = str(entry.get("handle", "")) if has_entry else ""
		handle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		handle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(handle_label)
		_apply_font(handle_label, _font_regular, _leaderboard_font_size(LEADERBOARD_ROW_FONT_SIZE))
		if not micro_side:
			var time_label := Label.new()
			var entry_time_ms: int = int(entry.get("time_ms", 0)) if has_entry else 0
			time_label.text = _format_time_ms(entry_time_ms) if entry_time_ms > 0 else ""
			time_label.custom_minimum_size = Vector2(132.0 if _uses_side_leaderboard_layout() else 128.0, 0.0)
			time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(time_label)
			_apply_font(time_label, _font_semibold, _leaderboard_font_size(LEADERBOARD_ROW_FONT_SIZE))
		leaderboard_list.add_child(row)
		if has_entry and str(entry.get("player_id", "")).strip_edges() == _highlight_player_id and Time.get_ticks_msec() <= _highlight_until_msec:
			_pulse_leaderboard_row(row)
	_refresh_leaderboard_nav(total_entries)
	var your_best_ms: int = int(board.get("your_best_ms", 0))
	var your_rank: int = int(board.get("your_rank", 0))
	if your_rank <= 0 or your_best_ms <= 0:
		your_best_label.text = "Your best: --"
	else:
		your_best_label.text = "Your best: #%d  %s" % [your_rank, _format_time_ms(your_best_ms)]

func _pulse_leaderboard_row(row: Control) -> void:
	if row == null:
		return
	row.modulate = Color(1.0, 0.86, 0.26, 1.0)
	var tween := create_tween()
	tween.set_loops(8)
	tween.tween_property(row, "modulate", Color(1.0, 0.96, 0.62, 1.0), 0.35)
	tween.tween_property(row, "modulate", Color(1.0, 0.68, 0.18, 1.0), 0.35)
	tween.finished.connect(func() -> void:
		if is_instance_valid(row):
			row.modulate = Color.WHITE
	)

func _ensure_map_schematic_preview() -> void:
	if hero_preview_panel == null:
		return
	if _map_schematic_preview != null and is_instance_valid(_map_schematic_preview):
		return
	var existing: Control = hero_preview_panel.get_node_or_null("MapSchematicPreview") as Control
	if existing != null:
		_map_schematic_preview = existing
		return
	var preview: Control = MapSchematicPreviewScript.new() as Control
	preview.name = "MapSchematicPreview"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.clip_contents = true
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 12.0
	preview.offset_top = 12.0
	preview.offset_right = -12.0
	preview.offset_bottom = -12.0
	preview.visible = false
	hero_preview_panel.add_child(preview)
	if hero_preview != null:
		hero_preview_panel.move_child(preview, hero_preview.get_index() + 1)
	_map_schematic_preview = preview

func _apply_map_schematic_preview(map_path: String) -> bool:
	if _map_schematic_preview == null or map_path.strip_edges().is_empty():
		return false
	var loaded: Dictionary = MAP_LOADER.load_map(map_path)
	if not bool(loaded.get("ok", false)):
		if _map_schematic_preview.has_method("clear_map_data"):
			_map_schematic_preview.call("clear_map_data")
		return false
	var data: Dictionary = loaded.get("data", {}) as Dictionary
	if data.is_empty():
		return false
	_selected_preview_aspect = _grid_aspect_from_map_data(data)
	_selected_preview_is_schematic = true
	if _map_schematic_preview.has_method("set_map_data"):
		_map_schematic_preview.call("set_map_data", data)
	return true

func _refresh_hero_preview(selected: Dictionary) -> void:
	_ensure_map_schematic_preview()
	var map_path: String = str(selected.get("path", "")).strip_edges()
	if _apply_map_schematic_preview(map_path):
		if hero_preview != null:
			hero_preview.visible = false
			hero_preview.texture = null
		if _map_schematic_preview != null:
			_map_schematic_preview.visible = true
		hero_preview_badge.text = "MAP SCHEMATIC"
		_apply_font(hero_preview_badge, _font_semibold, _scaled_touch_font_size(11))
		_refresh_hero_preview_size()
		return
	var preview_path: String = str(selected.get("preview_path", "")).strip_edges()
	if not preview_path.is_empty() and ResourceLoader.exists(preview_path):
		if _map_schematic_preview != null:
			_map_schematic_preview.visible = false
		hero_preview.visible = true
		var texture: Texture2D = load(preview_path) as Texture2D
		hero_preview.texture = texture
		_selected_preview_is_schematic = false
		_selected_preview_aspect = _texture_aspect(texture)
		hero_preview_badge.text = "MAP PREVIEW"
		_apply_font(hero_preview_badge, _font_semibold, _scaled_touch_font_size(11))
		_refresh_hero_preview_size()
		return
	if _map_schematic_preview != null:
		_map_schematic_preview.visible = false
	hero_preview.texture = null
	hero_preview.visible = true
	_selected_preview_is_schematic = false
	_selected_preview_aspect = 1.25
	hero_preview_badge.text = "PREVIEW COMING SOON"
	_apply_font(hero_preview_badge, _font_semibold, _scaled_touch_font_size(11))
	_refresh_hero_preview_size()

func _grid_aspect_from_map_data(map_data: Dictionary) -> float:
	var grid_w: float = float(map_data.get("grid_w", map_data.get("width", 18)))
	var grid_h: float = float(map_data.get("grid_h", map_data.get("height", 28)))
	return maxf(1.0, grid_w) / maxf(1.0, grid_h)

func _texture_aspect(texture: Texture2D) -> float:
	if texture == null or texture.get_height() <= 0:
		return 1.25
	return maxf(1.0, float(texture.get_width())) / maxf(1.0, float(texture.get_height()))

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
	var page_size: int = _leaderboard_page_size()
	var start_index: int = 0
	var end_index: int = 0
	if safe_total > 0:
		start_index = _leaderboard_offset + 1
		end_index = mini(_leaderboard_offset + page_size, safe_total)
	leaderboard_nav.visible = safe_total > page_size
	leaderboard_page_label.text = "%d-%d / %d" % [start_index, end_index, safe_total]
	leaderboard_up_button.disabled = _leaderboard_offset <= 0
	leaderboard_down_button.disabled = (_leaderboard_offset + page_size) >= safe_total

func _on_leaderboard_up_pressed() -> void:
	_leaderboard_offset = maxi(0, _leaderboard_offset - _leaderboard_page_size())
	_refresh_leaderboard()

func _on_leaderboard_down_pressed() -> void:
	_leaderboard_offset += _leaderboard_page_size()
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

func _selected_map_meta_text(entry: Dictionary) -> String:
	var parts: Array[String] = []
	var family: String = str(entry.get("display_family", entry.get("map_family", ""))).strip_edges()
	if not family.is_empty():
		parts.append(_humanize_token(family).to_upper())
	var buckets_v: Variant = entry.get("player_buckets", [])
	if typeof(buckets_v) == TYPE_ARRAY:
		var buckets: Array = buckets_v as Array
		if not buckets.is_empty():
			var bucket_parts: Array[String] = []
			for bucket_any in buckets:
				var bucket: String = str(bucket_any).strip_edges()
				if not bucket.is_empty():
					bucket_parts.append(bucket)
			if not bucket_parts.is_empty():
				parts.append(" / ".join(bucket_parts))
	var bot_count: int = int(entry.get("async_bot_count", 0))
	if bot_count > 0:
		parts.append("%d CPU" % bot_count)
	return "  |  ".join(parts)

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
	var layout_size: Vector2 = size
	if layout_size.x <= 1.0 or layout_size.y <= 1.0:
		layout_size = get_viewport_rect().size
	if layout_size.x <= 0.0 or layout_size.y <= 0.0:
		return false
	return layout_size.y > layout_size.x or layout_size.x <= TOUCH_LAYOUT_MAX_WIDTH

func _uses_side_leaderboard_layout() -> bool:
	return _content_width() >= SELECTED_CARD_SIDE_BREAKPOINT

func _leaderboard_uses_full_width_layout() -> bool:
	return leaderboard_panel != null and leaderboard_panel.get_parent() == root_vbox

func _scaled_touch_font_size(size_value: int) -> int:
	if not _uses_touch_layout():
		return size_value
	return maxi(1, int(round(float(size_value) * TOUCH_LAYOUT_FONT_SCALE)))

func _leaderboard_font_size(size_value: int) -> int:
	if _uses_side_leaderboard_layout():
		return maxi(1, int(round(float(size_value) * LEADERBOARD_FONT_SCALE)))
	return _scaled_touch_font_size(maxi(1, int(round(float(size_value) * LEADERBOARD_FONT_SCALE))))

func _leaderboard_header_height() -> float:
	return 64.0 if _uses_side_leaderboard_layout() else (72.0 if _uses_touch_layout() else 56.0)

func _leaderboard_row_height() -> float:
	return 76.0 if _uses_side_leaderboard_layout() else (82.0 if _uses_touch_layout() else 62.0)

func _leaderboard_empty_height() -> float:
	return 76.0 if _uses_side_leaderboard_layout() else (74.0 if _uses_touch_layout() else 58.0)

func _leaderboard_period_tab_height() -> float:
	return 58.0 if _uses_side_leaderboard_layout() else 52.0

func _leaderboard_page_size() -> int:
	return LEADERBOARD_LANDSCAPE_PAGE_SIZE if _leaderboard_uses_full_width_layout() else PAGE_SIZE

func _uses_micro_side_leaderboard() -> bool:
	return not _leaderboard_uses_full_width_layout() and _uses_side_leaderboard_layout() and _leaderboard_panel_width() < 420.0

func _style_nav_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(90.0, 58.0) if _uses_touch_layout() else Vector2(76.0, 48.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)

func _style_selector_nav_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(_selector_nav_width(), 58.0 if _uses_touch_layout() else 48.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)

func _style_play_button() -> void:
	if play_button == null:
		return
	play_button.custom_minimum_size = Vector2(_play_button_width(), PLAY_BUTTON_HEIGHT)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.text = "PLAY"
	play_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_button.tooltip_text = "Play selected map"
	play_button.flat = true
	play_button.icon = null
	play_button.modulate = Color.WHITE
	play_button.self_modulate = Color.WHITE
	_hide_sprite_button_text(play_button)
	_apply_sprite_button_styleboxes(play_button)
	if play_sprite != null:
		if play_sprite.texture == null and _play_texture != null:
			play_sprite.texture = _play_texture
		_prepare_sprite_button(play_button, play_sprite)

func _hide_sprite_button_text(button: Button) -> void:
	var transparent := Color(1.0, 1.0, 1.0, 0.0)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_outline_color"]:
		button.add_theme_color_override(color_name, transparent)
	button.add_theme_constant_override("outline_size", 0)

func _apply_sprite_button_styleboxes(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(style_name, empty)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color(1.0, 0.82, 0.24, 0.92)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(10)
	button.add_theme_stylebox_override("focus", focus)

func _prepare_sprite_button(button: Button, sprite: TextureRect) -> void:
	if button == null or sprite == null:
		return
	sprite.visible = true
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.offset_left = 0.0
	sprite.offset_top = 0.0
	sprite.offset_right = 0.0
	sprite.offset_bottom = 0.0
	if not button.has_meta("sprite_state_wired"):
		var refresh := Callable(self, "_refresh_sprite_button_state").bind(button, sprite)
		button.mouse_entered.connect(refresh)
		button.mouse_exited.connect(refresh)
		button.focus_entered.connect(refresh)
		button.focus_exited.connect(refresh)
		button.button_down.connect(refresh)
		button.button_up.connect(refresh)
		button.set_meta("sprite_state_wired", true)
	_refresh_sprite_button_state(button, sprite)

func _refresh_sprite_button_state(button: Button, sprite: TextureRect) -> void:
	if button == null or sprite == null:
		return
	if button.disabled:
		sprite.self_modulate = Color(0.44, 0.44, 0.44, 0.72)
	elif button.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]:
		sprite.self_modulate = Color(0.78, 0.72, 0.56, 1.0)
	elif button.is_hovered() or button.has_focus():
		sprite.self_modulate = Color.WHITE
	else:
		sprite.self_modulate = Color(0.92, 0.92, 0.92, 1.0)

func _set_play_button_disabled(is_disabled: bool) -> void:
	if play_button == null:
		return
	play_button.disabled = is_disabled
	_refresh_sprite_button_state(play_button, play_sprite)

func _content_width() -> float:
	var width: float = size.x
	if width <= 1.0 and root_vbox != null and root_vbox.size.x > 0.0:
		width = root_vbox.size.x
	if width <= 0.0:
		var viewport: Viewport = get_viewport()
		if viewport != null:
			width = viewport.get_visible_rect().size.x
	return maxf(1.0, width - 56.0)

func _brand_banner_width(height: float) -> float:
	if _brand_banner_texture == null:
		return 0.0
	var texture_size: Vector2 = _brand_banner_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return 0.0
	var aspect_width: float = height * (texture_size.x / texture_size.y)
	var content_width: float = _content_width()
	var narrow_width: float = content_width * BRAND_BANNER_NARROW_OVERHANG
	return floor(minf(aspect_width, maxf(content_width, narrow_width)))

func _layout_height() -> float:
	var height: float = size.y
	if height <= 1.0 and root_vbox != null and root_vbox.size.y > 1.0:
		height = root_vbox.size.y
	if height <= 1.0:
		var viewport: Viewport = get_viewport()
		if viewport != null:
			height = viewport.get_visible_rect().size.y
	return maxf(1.0, height)

func _control_content_width(control: Control, fallback: float) -> float:
	var width: float = fallback
	if control != null and control.size.x > 1.0:
		width = control.size.x
	return maxf(1.0, width - 32.0)

func _selector_content_width() -> float:
	if _hero_middle_row != null and selector_panel != null and selector_panel.get_parent() == _hero_middle_row:
		return maxf(1.0, _selector_side_panel_width() - 32.0)
	return _control_content_width(selector_panel, _content_width())

func _hero_content_width() -> float:
	return _control_content_width(hero_panel, _content_width())

func _leaderboard_content_width() -> float:
	return _control_content_width(leaderboard_panel, _leaderboard_panel_width())

func _category_tab_width() -> float:
	var count: int = maxi(1, _category_labels.size())
	var separation: float = 8.0
	var available: float = _selector_content_width() - separation * float(maxi(0, count - 1))
	return clampf(floor(available / float(count)), CATEGORY_TAB_MIN_WIDTH, CATEGORY_TAB_MAX_WIDTH)

func _period_tab_width() -> float:
	var count: int = maxi(1, _jukebox_state.PERIOD_LABELS.size())
	var separation: float = 8.0
	var available: float = _leaderboard_content_width() - separation * float(maxi(0, count - 1))
	if _uses_side_leaderboard_layout() and not _leaderboard_uses_full_width_layout():
		return clampf(floor(available / float(count)), 24.0, 92.0)
	return clampf(floor(available / float(count)), PERIOD_TAB_MIN_WIDTH, PERIOD_TAB_MAX_WIDTH)

func _period_tab_display_text(period_label: String) -> String:
	if not _uses_side_leaderboard_layout() or _leaderboard_uses_full_width_layout():
		return period_label
	match period_label:
		"WEEKLY":
			return "W"
		"MONTHLY":
			return "M"
		"SEASON":
			return "S"
		"ALL TIME":
			return "A"
	return period_label.substr(0, 1)

func _map_card_width() -> float:
	var raw_width: float = floor(_selector_content_width())
	var responsive_min: float = minf(MAP_CARD_MIN_WIDTH, raw_width)
	return clampf(raw_width, responsive_min, MAP_CARD_MAX_WIDTH)

func _selector_nav_width() -> float:
	var available: float = _selector_content_width()
	return clampf(floor(available * 0.14), SELECTOR_NAV_MIN_WIDTH, SELECTOR_NAV_MAX_WIDTH)

func _play_button_width() -> float:
	var preview_width: float = hero_preview_panel.custom_minimum_size.x if hero_preview_panel != null else 0.0
	if _uses_side_leaderboard_layout():
		return clampf(maxf(preview_width, PLAY_BUTTON_SIDE_MIN_WIDTH), PLAY_BUTTON_SIDE_MIN_WIDTH, PLAY_BUTTON_MAX_WIDTH)
	var target_width: float = maxf(preview_width, 320.0)
	return clampf(target_width, PLAY_BUTTON_MIN_WIDTH, PLAY_BUTTON_MAX_WIDTH)

func _selector_panel_height() -> float:
	return 700.0 if _uses_touch_layout() else 430.0

func _selector_side_panel_width() -> float:
	var content_width: float = _content_width()
	var preview_width: float = hero_preview_panel.custom_minimum_size.x if hero_preview_panel != null else 0.0
	var fallback_preview_width: float = floor(content_width * 0.42)
	var resolved_preview_width: float = preview_width if preview_width > 1.0 else fallback_preview_width
	var target_width: float = content_width - resolved_preview_width - SELECTED_CARD_COLUMN_GAP - SELECTED_CARD_HORIZONTAL_PAD
	return clampf(floor(target_width), LEADERBOARD_SIDE_MIN_WIDTH, minf(LEADERBOARD_SIDE_MAX_WIDTH, content_width))

func _leaderboard_panel_width() -> float:
	var content_width: float = _content_width()
	if _leaderboard_uses_full_width_layout():
		return content_width
	if _uses_side_leaderboard_layout():
		return _selector_side_panel_width()
	return clampf(floor(content_width - SELECTED_CARD_HORIZONTAL_PAD), SELECTED_CARD_MIN_WIDTH, minf(LEADERBOARD_STACK_MAX_WIDTH, content_width))

func _leaderboard_panel_height() -> float:
	if _leaderboard_uses_full_width_layout():
		return _selector_panel_height()
	var target_height: float = clampf(_layout_height() * 0.16, 170.0, 320.0)
	if _uses_side_leaderboard_layout():
		var preview_height: float = hero_preview_panel.custom_minimum_size.y if hero_preview_panel != null else _target_preview_height()
		return maxf(LEADERBOARD_PANEL_MIN_HEIGHT, preview_height)
	return maxf(LEADERBOARD_PANEL_MIN_HEIGHT, target_height)

func _selected_card_width() -> float:
	var preview_width: float = hero_preview_panel.custom_minimum_size.x if hero_preview_panel != null else 0.0
	var play_width: float = _play_button_width()
	var title_width: float = selected_title_label.get_combined_minimum_size().x if selected_title_label != null else 0.0
	var meta_width: float = selected_meta_label.get_combined_minimum_size().x if selected_meta_label != null else 0.0
	var leaderboard_width: float = _leaderboard_panel_width() if leaderboard_panel != null else 0.0
	var content_limit: float = maxf(SELECTED_CARD_MIN_WIDTH, _content_width())
	var width: float = 0.0
	if _uses_side_leaderboard_layout():
		var preview_column_width: float = maxf(preview_width, play_width)
		width = maxf(preview_column_width + SELECTED_CARD_COLUMN_GAP + leaderboard_width, maxf(title_width, meta_width)) + SELECTED_CARD_HORIZONTAL_PAD
		return clampf(width, SELECTED_CARD_MIN_WIDTH, minf(SELECTED_CARD_SIDE_MAX_WIDTH, content_limit))
	width = maxf(maxf(maxf(preview_width, play_width), leaderboard_width), maxf(title_width, meta_width)) + SELECTED_CARD_HORIZONTAL_PAD
	return clampf(width, SELECTED_CARD_MIN_WIDTH, minf(SELECTED_CARD_MAX_WIDTH, content_limit))

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
			if child is Button:
				var button := child as Button
				button.text = _period_tab_display_text(str(button.get_meta("period_label", button.text)))
			(child as Control).custom_minimum_size.x = width
			(child as Control).custom_minimum_size.y = _leaderboard_period_tab_height()

func _refresh_play_button_width() -> void:
	if play_button != null:
		play_button.custom_minimum_size = Vector2(_play_button_width(), PLAY_BUTTON_HEIGHT)
		play_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if _uses_side_leaderboard_layout() else Control.SIZE_SHRINK_CENTER

func _refresh_leaderboard_compact_controls() -> void:
	_refresh_period_tab_widths()
	if period_tabs != null:
		for child in period_tabs.get_children():
			if child is Button:
				_apply_font(child as Button, _font_semibold, _leaderboard_font_size(12))
	if leaderboard_up_button != null:
		leaderboard_up_button.custom_minimum_size = Vector2(76.0, 58.0) if _uses_side_leaderboard_layout() else (Vector2(90.0, 58.0) if _uses_touch_layout() else Vector2(76.0, 48.0))
	if leaderboard_down_button != null:
		leaderboard_down_button.custom_minimum_size = Vector2(76.0, 58.0) if _uses_side_leaderboard_layout() else (Vector2(90.0, 58.0) if _uses_touch_layout() else Vector2(76.0, 48.0))
	if leaderboard_page_label != null:
		_apply_font(leaderboard_page_label, _font_semibold, _leaderboard_font_size(22))
	if your_best_label != null:
		_apply_font(your_best_label, _font_semibold, _leaderboard_font_size(26))

func _refresh_selected_card_size() -> void:
	if hero_panel == null:
		return
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hero_panel.custom_minimum_size.x = 0.0

func _refresh_hero_preview_size() -> void:
	if hero_preview_panel == null:
		return
	var target_height: float = _target_preview_height()
	var card_width_limit: float = SELECTED_CARD_MAX_WIDTH - SELECTED_CARD_HORIZONTAL_PAD
	var content_width_limit: float = _content_width() - SELECTED_CARD_HORIZONTAL_PAD - 36.0
	if _uses_side_leaderboard_layout():
		var paired_width_limit: float = floor((_content_width() - SELECTED_CARD_HORIZONTAL_PAD - SELECTED_CARD_COLUMN_GAP) * 0.5)
		card_width_limit = minf(SELECTED_CARD_SIDE_MAX_WIDTH - SELECTED_CARD_HORIZONTAL_PAD, paired_width_limit)
		content_width_limit = paired_width_limit
	var max_width: float = maxf(120.0, minf(content_width_limit, card_width_limit))
	var aspect: float = clampf(_selected_preview_aspect, 0.35, 2.25)
	var preview_height: float = target_height
	var preview_width: float = preview_height * aspect
	if _uses_side_leaderboard_layout():
		var side_height_cap: float = clampf(_layout_height() * 0.42, PREVIEW_MIN_HEIGHT, PREVIEW_MAX_HEIGHT)
		preview_width = max_width
		preview_height = preview_width / aspect
		if preview_height > side_height_cap:
			preview_height = side_height_cap
			preview_width = preview_height * aspect
	elif preview_width > max_width:
		preview_width = max_width
		preview_height = preview_width / aspect
	preview_width = floor(maxf(96.0, preview_width))
	preview_height = floor(maxf(120.0, preview_height))
	hero_preview_panel.custom_minimum_size = Vector2(preview_width, preview_height)
	hero_preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if _uses_side_leaderboard_layout() else Control.SIZE_SHRINK_CENTER
	hero_preview_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if hero_panel != null:
		hero_panel.custom_minimum_size.y = maxf(hero_panel.custom_minimum_size.y, preview_height + PLAY_BUTTON_HEIGHT + 132.0)
	_refresh_play_button_width()
	if leaderboard_panel != null:
		leaderboard_panel.custom_minimum_size = Vector2(0.0 if _leaderboard_uses_full_width_layout() else _leaderboard_panel_width(), _leaderboard_panel_height())
	_refresh_selected_card_size()

func _target_preview_height() -> float:
	return clampf(_layout_height() * PREVIEW_HEIGHT_RATIO, PREVIEW_MIN_HEIGHT, PREVIEW_MAX_HEIGHT)

func _refresh_selector_nav_widths() -> void:
	var width: float = _selector_nav_width()
	for button in [map_left_button, map_right_button]:
		if button != null:
			button.custom_minimum_size.x = width

func _refresh_map_card_widths() -> void:
	var width: float = _map_card_width()
	var font_size: int = _map_card_font_size(width)
	for child in map_list.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.x = width
			(child as Control).custom_minimum_size.y = 66.0 if _uses_touch_layout() else 52.0
			_apply_font(child as Control, _font_semibold, _scaled_touch_font_size(font_size))

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
	map_left_button.icon = null
	map_right_button.icon = null
	map_left_button.text = ""
	map_right_button.text = ""
	map_left_sprite.texture = _side_chevron_atlas(false)
	map_right_sprite.texture = _side_chevron_atlas(true)

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

func _style_footer_back_button(button: Button) -> void:
	if button == null:
		return
	_style_button(button)
	button.flat = true
	_hide_sprite_button_text(button)
	_apply_sprite_button_styleboxes(button)
	if footer_close_sprite != null:
		if footer_close_sprite.texture == null and _main_menu_texture != null:
			footer_close_sprite.texture = _main_menu_texture
		_prepare_sprite_button(button, footer_close_sprite)
