extends Control
class_name GaragePanel

const CosmeticThemeDB := preload("res://scripts/cosmetics/cosmetic_theme_db.gd")
const UITypography := preload("res://scripts/ui/ui_typography.gd")
const CATEGORY_ORDER: Array[String] = ["units", "hives", "lanes", "power_bars", "floors", "vfx", "social"]
const PREVIEW_BADGE_TEXT: String = "GARAGE HERO"
const BUFF_MODE_VS: String = "vs"
const BUFF_MODE_ASYNC: String = "async"
const UNIT_PREVIEW_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/mvp_unit2.png"
const PREVIEW_3D_YAW_RANGE_DEG: float = 68.0
const PREVIEW_3D_SLICE_COUNT: int = 13
const PREVIEW_3D_DEPTH: float = 0.38

@onready var title_label: Label = $VBox/Body/CategoryPanel/CategoryVBox/Header/TitleBlock/Title
@onready var sub_label: Label = $VBox/Body/CategoryPanel/CategoryVBox/Header/TitleBlock/Sub
@onready var loadout_summary_label: Label = $VBox/Body/CategoryPanel/CategoryVBox/Header/LoadoutSummary
@onready var category_header_label: Label = $VBox/Body/CategoryPanel/CategoryVBox/CategoryHeader
@onready var category_sub_label: Label = $VBox/Body/CategoryPanel/CategoryVBox/CategorySub
@onready var category_list: Container = $VBox/Body/CategoryPanel/CategoryVBox/CategoryList
@onready var selected_title_label: Label = $VBox/Body/PreviewPanel/PreviewVBox/SelectedTitle
@onready var selected_meta_label: Label = $VBox/Body/PreviewPanel/PreviewVBox/SelectedMeta
@onready var preview_frame: Control = $VBox/Body/PreviewPanel/PreviewVBox/PreviewFrame
@onready var preview_texture: TextureRect = $VBox/Body/PreviewPanel/PreviewVBox/PreviewFrame/PreviewTexture
@onready var preview_badge_label: Label = $VBox/Body/PreviewPanel/PreviewVBox/PreviewFrame/PreviewBadge
@onready var turntable_row: HBoxContainer = $VBox/Body/PreviewPanel/PreviewVBox/TurntableRow
@onready var turntable_label: Label = $VBox/Body/PreviewPanel/PreviewVBox/TurntableRow/TurntableLabel
@onready var turntable_slider: HSlider = $VBox/Body/PreviewPanel/PreviewVBox/TurntableRow/TurntableSlider
@onready var selected_desc_label: Label = $VBox/Body/PreviewPanel/PreviewVBox/SelectedDesc
@onready var selection_status_label: Label = $VBox/Body/PreviewPanel/PreviewVBox/SelectionStatus
@onready var inventory_header_label: Label = $VBox/Body/InventoryPanel/InventoryVBox/InventoryHeaderRow/InventoryHeader
@onready var inventory_pvp_tab: Button = $VBox/Body/InventoryPanel/InventoryVBox/InventoryHeaderRow/ModeTabs/PvpTab
@onready var inventory_time_puzzle_tab: Button = $VBox/Body/InventoryPanel/InventoryVBox/InventoryHeaderRow/ModeTabs/TimePuzzleTab
@onready var inventory_list: VBoxContainer = $VBox/Body/InventoryPanel/InventoryVBox/InventoryScroll/InventoryList
@onready var inventory_note_label: Label = $VBox/Body/InventoryPanel/InventoryVBox/InventoryNote
@onready var equip_button: Button = $VBox/Body/InventoryPanel/InventoryVBox/InventoryActions/EquipButton

var _font_regular: Font = null
var _font_semibold: Font = null
var _catalog: Dictionary = {}
var _category_buttons: Dictionary = {}
var _selected_category: String = "units"
var _selected_item_id: String = ""
var _status_flash_message: String = ""
var _buff_context_mode: String = BUFF_MODE_VS
var _preview_dragging: bool = false
var _preview_3d_container: SubViewportContainer = null
var _preview_3d_viewport: SubViewport = null
var _preview_3d_root: Node3D = null
var _preview_3d_model: Node3D = null
var _preview_3d_slices: Array[MeshInstance3D] = []
var _preview_3d_materials: Array[StandardMaterial3D] = []
var _preview_3d_enabled: bool = false
var _category_option_scroll: ScrollContainer = null
var _category_option_grid: GridContainer = null

func _ready() -> void:
	_load_fonts()
	_build_catalog()
	_ensure_preview_3d()
	_style_static_ui()
	_build_category_buttons()
	preview_frame.gui_input.connect(_on_preview_frame_gui_input)
	if not preview_texture.resized.is_connected(_update_preview_pivot):
		preview_texture.resized.connect(_update_preview_pivot)
	turntable_slider.value_changed.connect(_on_turntable_value_changed)
	equip_button.pressed.connect(_on_equip_pressed)
	inventory_pvp_tab.pressed.connect(func() -> void:
		_set_buff_context_mode(BUFF_MODE_VS)
	)
	inventory_time_puzzle_tab.pressed.connect(func() -> void:
		_set_buff_context_mode(BUFF_MODE_ASYNC)
	)
	_bind_profile_signals()
	refresh_view()

func refresh_view() -> void:
	_build_catalog()
	if not _catalog.has(_selected_category):
		_selected_category = CATEGORY_ORDER[0]
	_sync_selected_item_to_profile()
	_refresh_category_copy()
	_refresh_category_buttons()
	_refresh_inventory()
	_refresh_preview()
	_refresh_loadout_summary()
	_refresh_buff_mode_tabs()

func _load_fonts() -> void:
	_font_regular = UITypography.regular_font()
	_font_semibold = UITypography.semibold_font()

func _bind_profile_signals() -> void:
	if ProfileManager == null:
		return
	if ProfileManager.has_method("ensure_loaded"):
		ProfileManager.call("ensure_loaded")
	if ProfileManager.has_signal("powerbar_theme_changed"):
		var theme_callback: Callable = Callable(self, "_on_profile_powerbar_theme_changed")
		if not ProfileManager.is_connected("powerbar_theme_changed", theme_callback):
			ProfileManager.connect("powerbar_theme_changed", theme_callback)
	if ProfileManager.has_signal("garage_selection_changed"):
		var garage_callback: Callable = Callable(self, "_on_profile_garage_selection_changed")
		if not ProfileManager.is_connected("garage_selection_changed", garage_callback):
			ProfileManager.connect("garage_selection_changed", garage_callback)
	if ProfileManager.has_signal("social_destination_changed"):
		var social_callback: Callable = Callable(self, "_on_profile_social_destination_changed")
		if not ProfileManager.is_connected("social_destination_changed", social_callback):
			ProfileManager.connect("social_destination_changed", social_callback)

func _build_catalog() -> void:
	_catalog = {
		"units": {
			"title": "UNITS",
			"subtitle": "Surface the unit shell players identify with first.",
			"items": [
				{
					"id": "unit_field_issue",
					"title": "Field Issue",
					"meta": "Owned | Starter silhouette",
					"desc": "Baseline unit shell. Clean read, safe contrast, ready for live equip flow.",
					"preview_path": UNIT_PREVIEW_TEXTURE_PATH,
					"preview_3d": true
				},
				{
					"id": "unit_broadcast_elite",
					"title": "Broadcast Elite",
					"meta": "Scaffold | Art hook parked",
					"desc": "Parked slot for premium unit cosmetics once variant art and runtime swaps are wired.",
					"preview_path": UNIT_PREVIEW_TEXTURE_PATH,
					"preview_3d": true,
					"scaffold_only": true
				}
			]
		},
		"hives": {
			"title": "HIVES",
			"subtitle": "Hive identity should read as ownership, status, and faction tone.",
			"items": [
				{
					"id": "hive_classic",
					"title": "Classic Hive",
					"meta": "Owned | Default production shell",
					"desc": "Default hive silhouette used as the baseline garage selection.",
					"preview_path": "res://assets/sprites/sf_skin_v1/hive_large_final.png",
					"preview_3d": true
				},
				{
					"id": "hive_obsidian",
					"title": "Obsidian Hive",
					"meta": "Store unlock | Entitlement-backed",
					"desc": "Uses the existing store entitlement hook so the garage can reflect locked versus owned state.",
					"preview_path": "res://assets/sprites/sf_skin_v1/hive_large_final.png",
					"preview_3d": true,
					"entitlement": "skin_hive_obsidian"
				}
			]
		},
		"lanes": {
			"title": "LANES",
			"subtitle": "Lane skins need to stay readable while still carrying status and expression.",
			"items": [
				{
					"id": "lane_classic",
					"title": "Classic Lane",
					"meta": "Owned | Match-safe default",
					"desc": "Default lane presentation with the safest readability profile.",
					"preview_path": "res://assets/sprites/sf_skin_v1/lane_final_fixed.png"
				},
				{
					"id": "lane_goldpulse",
					"title": "Gold Pulse",
					"meta": "Store unlock | Entitlement-backed",
					"desc": "Hooks into the existing lane entitlement so the garage can represent cosmetic ownership cleanly.",
					"preview_path": "res://assets/sprites/sf_skin_v1/lane_final.png",
					"entitlement": "skin_lane_goldpulse"
				}
			]
		},
		"power_bars": {
			"title": "POWER BARS",
			"subtitle": "This shelf is live now: selecting a theme updates the in-match power bar.",
			"items": [
				{
					"id": CosmeticThemeDB.THEME_BASE,
					"title": "Base Frame",
					"meta": "Owned | Live equip",
					"desc": "Default power bar frame with no animated shader.",
					"powerbar_theme": CosmeticThemeDB.THEME_BASE
				},
				{
					"id": CosmeticThemeDB.THEME_UPGRADED,
					"title": "Upgraded Static",
					"meta": "Owned | Live equip",
					"desc": "Higher-value frame art without animation.",
					"powerbar_theme": CosmeticThemeDB.THEME_UPGRADED
				},
				{
					"id": CosmeticThemeDB.THEME_UPGRADED_DYNAMIC,
					"title": "Dynamic Surge",
					"meta": "Owned | Live equip",
					"desc": "Animated shader-backed frame for the garage and live HUD.",
					"powerbar_theme": CosmeticThemeDB.THEME_UPGRADED_DYNAMIC
				},
				{
					"id": CosmeticThemeDB.THEME_UPGRADED_BOIL,
					"title": "Boil Frame",
					"meta": "Owned | Live equip",
					"desc": "More aggressive animated frame variant using the existing boil shader.",
					"powerbar_theme": CosmeticThemeDB.THEME_UPGRADED_BOIL
				}
			]
		},
		"floors": {
			"title": "FLOORS",
			"subtitle": "Floor skins should change atmosphere without killing board readability.",
			"items": [
				{
					"id": "floor_standard",
					"title": "Standard Floor",
					"meta": "Owned | Current board baseline",
					"desc": "The current arena floor shell used as the default garage floor selection.",
					"preview_path": "res://assets/sprites/sf_skin_v1/arena_floor_obsideon_purple.png"
				},
				{
					"id": "floor_circuit_forge",
					"title": "Circuit Forge",
					"meta": "Store unlock | Entitlement-backed",
					"desc": "Hooks into the existing background entitlement so floor ownership has a real gate.",
					"preview_path": "res://assets/sprites/sf_skin_v1/mm_back_art.png",
					"entitlement": "skin_bg_circuit_forge"
				}
			]
		},
		"vfx": {
			"title": "VFX",
			"subtitle": "High-value finishers and feedback skins park here until runtime swaps are promoted.",
			"items": [
				{
					"id": "vfx_ion_pop",
					"title": "Ion Pop",
					"meta": "Owned | Default finisher",
					"desc": "Default effect slot for impact and finish feedback once garage loadout hooks expand.",
					"preview_path": "res://assets/sprites/sf_skin_v1/selector_rings_mvp.png"
				},
				{
					"id": "vfx_breach_flash",
					"title": "Breach Flash",
					"meta": "Scaffold | Runtime hook parked",
					"desc": "Reserved premium slot for VFX-driven expression after cosmetic event routing lands.",
					"preview_path": "res://assets/sprites/sf_skin_v1/buffs/tower_activated.PNG",
					"scaffold_only": true
				}
			]
		},
		"social": {
			"title": "SOCIAL",
			"subtitle": "Choose where your eligible match videos can post. Official featured matches are handled separately.",
			"items": [
				{
					"id": "discord",
					"title": "Discord",
					"meta": "Default off | Player opt-in",
					"desc": "Allow eligible gameplay videos to post to your connected Discord destination.",
					"preview_path": "res://assets/sprites/sf_skin_v1/Replay.png",
					"social_destination": true
				},
				{
					"id": "hive_feed",
					"title": "Hive Feed",
					"meta": "Default off | Hive opt-in",
					"desc": "Allow eligible match videos to route to your hive feed or hive-owned destination when configured.",
					"preview_path": "res://assets/sprites/sf_skin_v1/Hive.png",
					"social_destination": true
				},
				{
					"id": "slack",
					"title": "Slack",
					"meta": "Default off | Connector pending",
					"desc": "Keep this preference ready for workspace auth and delivery jobs.",
					"preview_path": "res://assets/sprites/sf_skin_v1/Analyticsii.png",
					"social_destination": true,
					"scaffold_only": true
				},
				{
					"id": "instagram",
					"title": "Instagram",
					"meta": "Default off | Connector pending",
					"desc": "Keep this preference ready for generated gameplay clips once platform upload is live.",
					"preview_path": "res://assets/sprites/sf_skin_v1/season.png",
					"social_destination": true,
					"scaffold_only": true
				},
				{
					"id": "tiktok",
					"title": "TikTok",
					"meta": "Default off | Connector pending",
					"desc": "Keep this preference ready for short gameplay clips once platform upload is live.",
					"preview_path": "res://assets/sprites/sf_skin_v1/play.png",
					"social_destination": true,
					"scaffold_only": true
				}
			]
		}
	}

func _style_static_ui() -> void:
	title_label.text = "GARAGE"
	sub_label.text = "Cosmetic home base inside the dash drawer. Power bars are live; the rest are scaffolded with owned or locked state."
	category_header_label.text = "CATEGORIES"
	preview_badge_label.text = PREVIEW_BADGE_TEXT
	inventory_header_label.text = "LOADOUT SHELF"
	_ensure_category_option_shelf()
	sub_label.visible = false
	loadout_summary_label.visible = false
	category_sub_label.visible = false
	selected_desc_label.visible = false
	selected_desc_label.custom_minimum_size = Vector2.ZERO
	inventory_note_label.visible = false
	inventory_note_label.custom_minimum_size = Vector2.ZERO
	$VBox/Body/CategoryPanel.custom_minimum_size = Vector2(0.0, 470.0)
	$VBox/Body/CategoryPanel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	$VBox/Body/InventoryPanel.custom_minimum_size = Vector2(0.0, 230.0)
	_apply_token(title_label, _font_semibold, "screen_title")
	_apply_token(sub_label, _font_regular, "panel_subtitle")
	_apply_token(loadout_summary_label, _font_regular, "meta")
	_apply_token(category_header_label, _font_semibold, "section_title")
	_apply_token(category_sub_label, _font_regular, "body")
	_apply_token(selected_title_label, _font_semibold, "panel_title")
	_apply_token(selected_meta_label, _font_regular, "meta")
	_apply_token(preview_badge_label, _font_semibold, "meta")
	_apply_token(turntable_label, _font_regular, "meta")
	_apply_token(selected_desc_label, _font_regular, "body")
	_apply_token(selection_status_label, _font_regular, "body")
	_apply_token(inventory_header_label, _font_semibold, "section_title")
	_apply_button_token(inventory_pvp_tab, _font_semibold, "compact_button")
	_apply_button_token(inventory_time_puzzle_tab, _font_semibold, "compact_button")
	_apply_token(inventory_note_label, _font_regular, "meta")
	_apply_button_token(equip_button, _font_semibold, "button")
	_style_button(equip_button, Color(0.34, 0.23, 0.09, 0.98), Color(0.95, 0.73, 0.25, 0.85), Color(0.99, 0.96, 0.86, 1.0))
	_style_panel($VBox/Body/CategoryPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))
	_style_panel($VBox/Body/PreviewPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))
	_style_panel($VBox/Body/PreviewPanel/PreviewVBox/PreviewFrame, Color(0.06, 0.07, 0.10, 0.96), Color(0.52, 0.56, 0.66, 0.45))
	_style_panel($VBox/Body/InventoryPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	turntable_slider.min_value = -PREVIEW_3D_YAW_RANGE_DEG
	turntable_slider.max_value = PREVIEW_3D_YAW_RANGE_DEG
	loadout_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	category_list.columns = 3
	category_list.add_theme_constant_override("h_separation", 8)
	category_list.add_theme_constant_override("v_separation", 8)
	_refresh_buff_mode_tabs()

func _build_category_buttons() -> void:
	for child in category_list.get_children():
		child.queue_free()
	_category_buttons.clear()
	for category_id in CATEGORY_ORDER:
		var category: Dictionary = _catalog.get(category_id, {}) as Dictionary
		if category.is_empty():
			continue
		var button := Button.new()
		button.text = _category_tab_label(category_id, category)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0.0, UITypography.PORTRAIT_TOUCH_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_selected_category = category_id
			_status_flash_message = ""
			_sync_selected_item_to_profile()
			_refresh_category_copy()
			_refresh_category_buttons()
			_refresh_buff_mode_tabs()
			_refresh_inventory()
			_refresh_preview()
		)
		category_list.add_child(button)
		_category_buttons[category_id] = button
		_apply_button_token(button, _font_semibold, "compact_button")

func _refresh_category_copy() -> void:
	var category: Dictionary = _catalog.get(_selected_category, {}) as Dictionary
	category_sub_label.text = str(category.get("subtitle", ""))

func _refresh_category_buttons() -> void:
	for category_id in _category_buttons.keys():
		var button: Button = _category_buttons[category_id] as Button
		if button == null:
			continue
		var selected: bool = category_id == _selected_category
		button.button_pressed = selected
		if selected:
			_style_button(button, Color(0.19, 0.14, 0.08, 0.98), Color(0.93, 0.74, 0.31, 0.90), Color(0.99, 0.96, 0.88, 1.0))
		else:
			_style_button(button, Color(0.10, 0.11, 0.15, 0.96), Color(0.40, 0.43, 0.52, 0.78), Color(0.90, 0.93, 0.98, 1.0))

func _category_tab_label(category_id: String, category: Dictionary) -> String:
	if category_id == "power_bars":
		return "POWER"
	return str(category.get("title", category_id)).to_upper()

func _refresh_inventory() -> void:
	_ensure_category_option_shelf()
	if _category_option_grid != null:
		for child in _category_option_grid.get_children():
			child.queue_free()
	for child in inventory_list.get_children():
		child.queue_free()
	var category: Dictionary = _catalog.get(_selected_category, {}) as Dictionary
	var items: Array = category.get("items", []) as Array
	for item_any in items:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any as Dictionary
		var state: Dictionary = _item_state(item)
		if _category_option_grid != null:
			_category_option_grid.add_child(_make_inventory_button(item, state, true))
		inventory_list.add_child(_make_inventory_button(item, state, false))
	inventory_note_label.text = "%s\n%s" % [_inventory_note_for_category(), _buff_loadout_note()]

func _ensure_category_option_shelf() -> void:
	if _category_option_grid != null:
		return
	var category_vbox: VBoxContainer = $VBox/Body/CategoryPanel/CategoryVBox
	_category_option_scroll = ScrollContainer.new()
	_category_option_scroll.name = "CategoryOptionScroll"
	_category_option_scroll.custom_minimum_size = Vector2(0.0, 118.0)
	_category_option_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_category_option_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_category_option_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	category_vbox.add_child(_category_option_scroll)
	category_vbox.move_child(_category_option_scroll, category_list.get_index() + 1)

	_category_option_grid = GridContainer.new()
	_category_option_grid.name = "CategoryOptionGrid"
	_category_option_grid.columns = 2
	_category_option_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_option_grid.add_theme_constant_override("h_separation", 8)
	_category_option_grid.add_theme_constant_override("v_separation", 8)
	_category_option_scroll.add_child(_category_option_grid)

func _make_inventory_button(item: Dictionary, state: Dictionary, compact: bool) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.button_pressed = str(item.get("id", "")) == _selected_item_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 78.0 if compact else 96.0)
	if compact:
		button.text = "%s\n%s" % [str(item.get("title", "Cosmetic")), _compact_item_badge(state)]
	else:
		button.text = "%s\n%s" % [_inventory_title(item, state), str(item.get("meta", ""))]
	button.pressed.connect(func() -> void:
		_selected_item_id = str(item.get("id", ""))
		_status_flash_message = ""
		_refresh_inventory()
		_refresh_preview()
	)
	_apply_button_token(button, _font_semibold, "meta", button.custom_minimum_size.y)
	if bool(state.get("equipped", false)):
		_style_button(button, Color(0.18, 0.15, 0.08, 0.98), Color(0.95, 0.77, 0.33, 0.92), Color(1.0, 0.97, 0.88, 1.0))
	elif bool(state.get("owned", false)):
		_style_button(button, Color(0.11, 0.12, 0.15, 0.96), Color(0.46, 0.50, 0.60, 0.80), Color(0.90, 0.94, 0.98, 1.0))
	else:
		_style_button(button, Color(0.10, 0.10, 0.12, 0.96), Color(0.35, 0.28, 0.28, 0.72), Color(0.70, 0.72, 0.76, 1.0))
	return button

func _compact_item_badge(state: Dictionary) -> String:
	if _selected_category == "social":
		return "ON" if bool(state.get("equipped", false)) else "OFF"
	if bool(state.get("equipped", false)):
		return "EQUIPPED"
	if bool(state.get("scaffold_only", false)):
		return "PARKED"
	if bool(state.get("owned", false)):
		return "AVAILABLE"
	return "LOCKED"

func _refresh_preview() -> void:
	var item: Dictionary = _selected_item()
	if item.is_empty():
		selected_title_label.text = "No cosmetic"
		selected_meta_label.text = ""
		selected_desc_label.text = ""
		selection_status_label.text = ""
		preview_texture.texture = null
		preview_texture.material = null
		equip_button.disabled = true
		return
	var state: Dictionary = _item_state(item)
	selected_title_label.text = str(item.get("title", "Cosmetic"))
	selected_meta_label.text = "%s  |  %s" % [str(_catalog_title(_selected_category)), str(item.get("meta", ""))]
	selected_desc_label.text = str(item.get("desc", ""))
	_apply_preview_item(item)
	if _status_flash_message != "":
		selection_status_label.text = _status_flash_message
	else:
		selection_status_label.text = _selection_status_copy(item, state)
	_update_equip_button(state)
	_refresh_loadout_summary()

func _refresh_loadout_summary() -> void:
	var parts: Array[String] = []
	for category_id in CATEGORY_ORDER:
		if category_id == "social":
			continue
		var item_id: String = _profile_selection_for_category(category_id)
		var item: Dictionary = _item_by_id(category_id, item_id)
		if item.is_empty():
			continue
		parts.append("%s: %s" % [str(_catalog_title(category_id)), str(item.get("title", item_id))])
	loadout_summary_label.text = "Live loadout snapshot: %s\nSocial routing: %s" % ["  |  ".join(parts), _social_summary()]

func _update_equip_button(state: Dictionary) -> void:
	if _selected_category == "social":
		equip_button.text = "TURN OFF" if bool(state.get("equipped", false)) else "TURN ON"
		equip_button.disabled = false
		return
	if bool(state.get("equipped", false)):
		equip_button.text = "EQUIPPED"
		equip_button.disabled = true
		return
	if not bool(state.get("owned", false)):
		equip_button.text = "LOCKED"
		equip_button.disabled = true
		return
	if bool(state.get("scaffold_only", false)):
		equip_button.text = "PARKED"
		equip_button.disabled = true
		return
	equip_button.text = "EQUIP"
	equip_button.disabled = false

func _sync_selected_item_to_profile() -> void:
	var desired_id: String = _profile_selection_for_category(_selected_category)
	var items: Array = (_catalog.get(_selected_category, {}) as Dictionary).get("items", []) as Array
	for item_any in items:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any as Dictionary
		if str(item.get("id", "")) == desired_id:
			_selected_item_id = desired_id
			return
	if not items.is_empty() and typeof(items[0]) == TYPE_DICTIONARY:
		_selected_item_id = str((items[0] as Dictionary).get("id", ""))
	else:
		_selected_item_id = ""

func _selected_item() -> Dictionary:
	return _item_by_id(_selected_category, _selected_item_id)

func _item_by_id(category_id: String, item_id: String) -> Dictionary:
	var category: Dictionary = _catalog.get(category_id, {}) as Dictionary
	var items: Array = category.get("items", []) as Array
	for item_any in items:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any as Dictionary
		if str(item.get("id", "")) == item_id:
			return item
	return {}

func _profile_selection_for_category(category_id: String) -> String:
	if ProfileManager == null:
		return ""
	if ProfileManager.has_method("ensure_loaded"):
		ProfileManager.call("ensure_loaded")
	if category_id == "power_bars":
		if ProfileManager.has_method("get_powerbar_theme"):
			return str(ProfileManager.call("get_powerbar_theme"))
		return CosmeticThemeDB.THEME_BASE
	if category_id == "social":
		return "discord"
	if ProfileManager.has_method("get_garage_selection"):
		return str(ProfileManager.call("get_garage_selection", category_id))
	return ""

func _item_state(item: Dictionary) -> Dictionary:
	var owned: bool = not bool(item.get("scaffold_only", false))
	var entitlement: String = str(item.get("entitlement", ""))
	if entitlement != "" and ProfileManager != null and ProfileManager.has_method("has_store_entitlement"):
		owned = bool(ProfileManager.call("has_store_entitlement", entitlement))
	var equipped: bool = str(item.get("id", "")) == _profile_selection_for_category(_selected_category)
	if _selected_category == "social":
		equipped = _social_destination_enabled(str(item.get("id", "")))
	return {
		"owned": owned,
		"equipped": equipped,
		"scaffold_only": bool(item.get("scaffold_only", false))
	}

func _inventory_title(item: Dictionary, state: Dictionary) -> String:
	var prefix: String = "OWNED"
	if _selected_category == "social":
		prefix = "ON" if bool(state.get("equipped", false)) else "OFF"
	elif bool(state.get("equipped", false)):
		prefix = "EQUIPPED"
	elif bool(state.get("scaffold_only", false)):
		prefix = "PARKED"
	elif not bool(state.get("owned", false)):
		prefix = "LOCKED"
	return "%s  %s" % [prefix, str(item.get("title", "Cosmetic"))]

func _selection_status_copy(item: Dictionary, state: Dictionary) -> String:
	if _selected_category == "social":
		var suffix: String = " Delivery is parked until platform auth and video upload jobs are live." if bool(state.get("scaffold_only", false)) else ""
		if bool(state.get("equipped", false)):
			return "%s is enabled for player-triggered eligible gameplay videos.%s" % [str(item.get("title", "This destination")), suffix]
		return "%s is off. Default social posting remains player opt-in.%s" % [str(item.get("title", "This destination")), suffix]
	if bool(state.get("equipped", false)):
		return "%s is active in your current loadout." % str(item.get("title", "This cosmetic"))
	if bool(state.get("scaffold_only", false)):
		return "%s is parked until its runtime cosmetic swap is promoted." % str(item.get("title", "This cosmetic"))
	if not bool(state.get("owned", false)):
		return "%s is locked behind an existing store entitlement." % str(item.get("title", "This cosmetic"))
	if _selected_category == "power_bars":
		return "This shelf is live: equipping here updates the in-match power bar."
	return "Selection persists now; runtime cosmetic application lands in follow-up hooks."

func _inventory_note_for_category() -> String:
	match _selected_category:
		"power_bars":
			return "Live surface: theme selection is profile-backed and already drives the match HUD."
		"hives", "lanes", "floors":
			return "Ownership state is real where store entitlements already exist."
		"social":
			return "Player destinations default off. Featured match videos may also post to official Swarmfront channels."
		_:
			return "Garage scaffold: choose, inspect, and park future runtime hooks in one place."

func _refresh_buff_mode_tabs() -> void:
	if inventory_pvp_tab == null or inventory_time_puzzle_tab == null:
		return
	var tabs_parent: Control = inventory_pvp_tab.get_parent() as Control
	if tabs_parent != null:
		tabs_parent.visible = _selected_category != "social"
	var pvp_selected: bool = _buff_context_mode == BUFF_MODE_VS
	inventory_pvp_tab.button_pressed = pvp_selected
	inventory_time_puzzle_tab.button_pressed = not pvp_selected
	if pvp_selected:
		_style_button(inventory_pvp_tab, Color(0.19, 0.14, 0.08, 0.98), Color(0.93, 0.74, 0.31, 0.90), Color(0.99, 0.96, 0.88, 1.0))
		_style_button(inventory_time_puzzle_tab, Color(0.10, 0.11, 0.15, 0.96), Color(0.40, 0.43, 0.52, 0.78), Color(0.90, 0.93, 0.98, 1.0))
	else:
		_style_button(inventory_pvp_tab, Color(0.10, 0.11, 0.15, 0.96), Color(0.40, 0.43, 0.52, 0.78), Color(0.90, 0.93, 0.98, 1.0))
		_style_button(inventory_time_puzzle_tab, Color(0.19, 0.14, 0.08, 0.98), Color(0.93, 0.74, 0.31, 0.90), Color(0.99, 0.96, 0.88, 1.0))

func _set_buff_context_mode(mode: String) -> void:
	var next_mode: String = BUFF_MODE_ASYNC if mode == BUFF_MODE_ASYNC else BUFF_MODE_VS
	if next_mode == _buff_context_mode:
		return
	_buff_context_mode = next_mode
	_refresh_buff_mode_tabs()
	_refresh_inventory()

func _buff_loadout_note() -> String:
	if _selected_category == "social":
		return "Manual post-match sharing should stay short-lived; official featured-match capture is separate from player opt-ins."
	var mode_name: String = "PvP" if _buff_context_mode == BUFF_MODE_VS else "Time Puzzles"
	var loadout: Array[String] = []
	if ProfileManager != null and ProfileManager.has_method("get_buff_loadout_ids_for_mode"):
		var loadout_any: Variant = ProfileManager.call("get_buff_loadout_ids_for_mode", _buff_context_mode)
		if typeof(loadout_any) == TYPE_ARRAY:
			for buff_id_any in loadout_any as Array:
				var buff_id: String = str(buff_id_any).strip_edges()
				if buff_id != "":
					loadout.append(buff_id)
	if loadout.is_empty():
		return "%s buffs: no equipped buffs yet." % mode_name
	var buff_names: Array[String] = []
	for buff_id in loadout:
		var buff: Dictionary = BuffCatalog.get_buff(buff_id)
		var buff_name: String = str(buff.get("name", buff_id)).strip_edges()
		if buff_name == "":
			buff_name = buff_id
		buff_names.append(buff_name)
	return "%s buffs: %s" % [mode_name, " / ".join(buff_names)]

func _social_destination_enabled(destination_id: String) -> bool:
	if ProfileManager == null or not ProfileManager.has_method("is_social_destination_enabled"):
		return false
	return bool(ProfileManager.call("is_social_destination_enabled", destination_id))

func _social_summary() -> String:
	if ProfileManager == null or not ProfileManager.has_method("get_social_destinations"):
		return "off"
	var destinations_any: Variant = ProfileManager.call("get_social_destinations")
	if typeof(destinations_any) != TYPE_DICTIONARY:
		return "off"
	var labels: Array[String] = []
	for item_any in ((_catalog.get("social", {}) as Dictionary).get("items", []) as Array):
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any as Dictionary
		var item_id: String = str(item.get("id", ""))
		if bool((destinations_any as Dictionary).get(item_id, false)):
			labels.append(str(item.get("title", item_id)))
	if labels.is_empty():
		return "off"
	return "on for %s" % ", ".join(labels)

func _catalog_title(category_id: String) -> String:
	var category: Dictionary = _catalog.get(category_id, {}) as Dictionary
	return str(category.get("title", category_id)).capitalize()

func _apply_preview_item(item: Dictionary) -> void:
	preview_texture.material = null
	_preview_3d_enabled = false
	_set_preview_3d_visible(false)
	var supports_3d_preview: bool = _selected_category == "units" or _selected_category == "hives"
	_set_turntable_enabled(supports_3d_preview)
	if _selected_category == "power_bars":
		var theme_id: String = str(item.get("powerbar_theme", CosmeticThemeDB.THEME_BASE))
		var texture: Texture2D = CosmeticThemeDB.get_powerbar_texture(theme_id, 4)
		preview_texture.texture = texture
		preview_texture.visible = true
		var shader: Shader = CosmeticThemeDB.get_powerbar_shader(theme_id)
		if shader != null:
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("fill_ratio", 0.62)
			material.set_shader_parameter("fill_velocity", 0.28)
			material.set_shader_parameter("share_p1", 0.62)
			material.set_shader_parameter("share_p2", 0.24)
			material.set_shader_parameter("share_p3", 0.10)
			material.set_shader_parameter("share_p4", 0.04)
			material.set_shader_parameter("color_p1", Color(0.96, 0.74, 0.28, 1.0))
			material.set_shader_parameter("color_p2", Color(0.53, 0.82, 1.0, 1.0))
			material.set_shader_parameter("color_p3", Color(0.92, 0.40, 0.48, 1.0))
			material.set_shader_parameter("color_p4", Color(0.69, 0.91, 0.38, 1.0))
			preview_texture.material = material
	else:
		var preview_path: String = str(item.get("preview_path", ""))
		var texture: Texture2D = _load_texture(preview_path)
		if supports_3d_preview and bool(item.get("preview_3d", false)) and texture != null:
			_apply_preview_3d_texture(texture)
		else:
			preview_texture.visible = true
			preview_texture.texture = texture
	turntable_slider.value = 0.0
	_preview_dragging = false
	_on_turntable_value_changed(turntable_slider.value)
	_update_preview_pivot()

func _set_turntable_enabled(enabled: bool) -> void:
	if turntable_row != null:
		turntable_row.visible = enabled
	if turntable_slider != null:
		turntable_slider.editable = enabled
		turntable_slider.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	var resource: Variant = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null

func _on_turntable_value_changed(value: float) -> void:
	if _preview_3d_enabled:
		_update_preview_3d_yaw(value)
		return
	preview_texture.rotation_degrees = 0.0

func _on_preview_frame_gui_input(event: InputEvent) -> void:
	if not _preview_3d_enabled:
		_preview_dragging = false
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		_preview_dragging = mouse_button.pressed
		return
	if event is InputEventScreenTouch:
		var screen_touch: InputEventScreenTouch = event as InputEventScreenTouch
		_preview_dragging = screen_touch.pressed
		return
	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _preview_dragging:
			_apply_preview_drag_delta(mouse_motion.relative.x)
		return
	if event is InputEventScreenDrag:
		var screen_drag: InputEventScreenDrag = event as InputEventScreenDrag
		_apply_preview_drag_delta(screen_drag.relative.x)

func _apply_preview_drag_delta(delta_x: float) -> void:
	if turntable_slider == null:
		return
	var next_value: float = clampf(turntable_slider.value + (delta_x * 0.18), turntable_slider.min_value, turntable_slider.max_value)
	turntable_slider.value = next_value

func _update_preview_pivot() -> void:
	preview_texture.pivot_offset = preview_texture.size * 0.5

func _ensure_preview_3d() -> void:
	if preview_frame == null or _preview_3d_container != null:
		return
	if DisplayServer.get_name() == "headless":
		return
	_preview_3d_container = SubViewportContainer.new()
	_preview_3d_container.name = "Preview3D"
	_preview_3d_container.visible = false
	_preview_3d_container.stretch = true
	_preview_3d_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_3d_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_3d_container.offset_left = 10.0
	_preview_3d_container.offset_top = 10.0
	_preview_3d_container.offset_right = -10.0
	_preview_3d_container.offset_bottom = -10.0
	preview_frame.add_child(_preview_3d_container)
	preview_frame.move_child(_preview_3d_container, preview_texture.get_index())

	_preview_3d_viewport = SubViewport.new()
	_preview_3d_viewport.name = "PreviewViewport"
	_preview_3d_viewport.transparent_bg = true
	_preview_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_3d_viewport.size = Vector2i(512, 512)
	_preview_3d_container.add_child(_preview_3d_viewport)

	_preview_3d_root = Node3D.new()
	_preview_3d_root.name = "PreviewWorld"
	_preview_3d_viewport.add_child(_preview_3d_root)

	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(0.0, 0.0, 3.2)
	camera.fov = 34.0
	camera.near = 0.05
	camera.far = 16.0
	camera.current = true
	_preview_3d_root.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_energy = 1.45
	key_light.rotation_degrees = Vector3(-34.0, -38.0, 0.0)
	_preview_3d_root.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "FillLight"
	fill_light.position = Vector3(-1.4, 0.9, 1.8)
	fill_light.light_energy = 0.72
	fill_light.omni_range = 4.0
	_preview_3d_root.add_child(fill_light)

	_preview_3d_model = Node3D.new()
	_preview_3d_model.name = "UnitModel"
	_preview_3d_model.rotation_degrees = Vector3(-7.0, 0.0, 0.0)
	_preview_3d_root.add_child(_preview_3d_model)

	_preview_3d_slices.clear()
	_preview_3d_materials.clear()
	for i in range(PREVIEW_3D_SLICE_COUNT):
		var slice := MeshInstance3D.new()
		slice.name = "UnitSlice%02d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(1.55, 1.55)
		slice.mesh = quad
		var depth_t: float = 0.0
		if PREVIEW_3D_SLICE_COUNT > 1:
			depth_t = float(i) / float(PREVIEW_3D_SLICE_COUNT - 1)
		slice.position.z = lerpf(-PREVIEW_3D_DEPTH * 0.5, PREVIEW_3D_DEPTH * 0.5, depth_t)
		var material := _make_preview_3d_slice_material(i, depth_t)
		slice.material_override = material
		_preview_3d_model.add_child(slice)
		_preview_3d_slices.append(slice)
		_preview_3d_materials.append(material)

func _apply_preview_3d_texture(texture: Texture2D) -> void:
	_ensure_preview_3d()
	if _preview_3d_materials.is_empty():
		preview_texture.visible = true
		preview_texture.texture = texture
		return
	preview_texture.visible = false
	preview_texture.texture = null
	preview_texture.rotation_degrees = 0.0
	_preview_3d_enabled = true
	_set_preview_3d_visible(true)
	for material in _preview_3d_materials:
		material.albedo_texture = texture
	var tex_size: Vector2 = texture.get_size()
	var aspect: float = tex_size.x / maxf(1.0, tex_size.y)
	for slice in _preview_3d_slices:
		var quad := slice.mesh as QuadMesh
		if quad != null:
			var base_height: float = 1.62
			quad.size = Vector2(base_height * aspect, base_height)
	_update_preview_3d_yaw(turntable_slider.value if turntable_slider != null else 0.0)

func _make_preview_3d_slice_material(index: int, depth_t: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.78
	var face_distance: float = abs(depth_t - 0.5) * 2.0
	var shade: float = lerpf(0.34, 0.74, face_distance)
	if index == PREVIEW_3D_SLICE_COUNT - 1:
		material.albedo_color = Color.WHITE
	elif index == 0:
		material.albedo_color = Color(0.24, 0.22, 0.19, 1.0)
	else:
		material.albedo_color = Color(shade, shade * 0.92, shade * 0.72, 1.0)
	return material

func _set_preview_3d_visible(visible: bool) -> void:
	if _preview_3d_container != null:
		_preview_3d_container.visible = visible

func _update_preview_3d_yaw(value: float) -> void:
	if _preview_3d_model == null:
		return
	var yaw: float = clampf(value, -PREVIEW_3D_YAW_RANGE_DEG, PREVIEW_3D_YAW_RANGE_DEG)
	_preview_3d_model.rotation_degrees = Vector3(-7.0, yaw, 0.0)

func _on_equip_pressed() -> void:
	var item: Dictionary = _selected_item()
	if item.is_empty():
		return
	var state: Dictionary = _item_state(item)
	if _selected_category != "social" and (not bool(state.get("owned", false)) or bool(state.get("scaffold_only", false))):
		return
	var item_id: String = str(item.get("id", ""))
	var changed: bool = false
	if _selected_category == "social":
		if ProfileManager != null and ProfileManager.has_method("set_social_destination_enabled"):
			var next_enabled: bool = not _social_destination_enabled(item_id)
			changed = bool(ProfileManager.call("set_social_destination_enabled", item_id, next_enabled))
			_status_flash_message = "%s %s." % [str(item.get("title", "Destination")), "enabled" if next_enabled else "disabled"]
	elif _selected_category == "power_bars":
		if ProfileManager != null and ProfileManager.has_method("set_powerbar_theme"):
			changed = bool(ProfileManager.call("set_powerbar_theme", item_id))
	else:
		if ProfileManager != null and ProfileManager.has_method("set_garage_selection"):
			changed = bool(ProfileManager.call("set_garage_selection", _selected_category, item_id))
	if _selected_category == "social":
		pass
	elif changed:
		_status_flash_message = "%s equipped." % str(item.get("title", "Cosmetic"))
	else:
		_status_flash_message = "%s already active." % str(item.get("title", "Cosmetic"))
	refresh_view()

func _on_profile_powerbar_theme_changed(_theme_id: String) -> void:
	if _selected_category == "power_bars":
		_status_flash_message = ""
	refresh_view()

func _on_profile_garage_selection_changed(_category_id: String, _item_id: String) -> void:
	_status_flash_message = ""
	refresh_view()

func _on_profile_social_destination_changed(_destination_id: String, _enabled: bool) -> void:
	if _selected_category != "social":
		_status_flash_message = ""
	refresh_view()

func _apply_font(control: Control, font: Font, size: int) -> void:
	UITypography.apply_font(control, font, size, UITypography.PORTRAIT_CANVAS_SCALE)

func _apply_token(control: Control, font: Font, token: String) -> void:
	UITypography.apply_token(control, font, token, UITypography.PORTRAIT_CANVAS_SCALE)

func _apply_button_token(button: BaseButton, font: Font, token: String, minimum_height: float = UITypography.PORTRAIT_TOUCH_HEIGHT) -> void:
	UITypography.apply_button_token(button, font, token, UITypography.PORTRAIT_CANVAS_SCALE, minimum_height)

func _style_button(button: Button, fill: Color, border: Color, text_color: Color) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.content_margin_left = 12
	normal.content_margin_top = 10
	normal.content_margin_right = 12
	normal.content_margin_bottom = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.08)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.lightened(0.14)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)

func _style_panel(panel: Control, fill: Color, border: Color) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", style)
