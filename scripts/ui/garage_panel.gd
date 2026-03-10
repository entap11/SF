extends Control
class_name GaragePanel

const CosmeticThemeDB := preload("res://scripts/cosmetics/cosmetic_theme_db.gd")

const FONT_REGULAR_PATH := "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const CATEGORY_ORDER: Array[String] = ["units", "hives", "lanes", "power_bars", "floors", "vfx"]
const PREVIEW_BADGE_TEXT: String = "GARAGE HERO"
const BUFF_MODE_VS: String = "vs"
const BUFF_MODE_ASYNC: String = "async"

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

func _ready() -> void:
	_load_fonts()
	_build_catalog()
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
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		_font_regular = load(FONT_REGULAR_PATH) as Font
	if ResourceLoader.exists(FONT_SEMIBOLD_PATH):
		_font_semibold = load(FONT_SEMIBOLD_PATH) as Font

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
					"preview_path": "res://assets/sprites/sf_skin_v1/unit_rendered_alpha.png"
				},
				{
					"id": "unit_broadcast_elite",
					"title": "Broadcast Elite",
					"meta": "Scaffold | Art hook parked",
					"desc": "Parked slot for premium unit cosmetics once variant art and runtime swaps are wired.",
					"preview_path": "res://assets/sprites/sf_skin_v1/unit_final.png",
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
					"preview_path": "res://assets/sprites/sf_skin_v1/hive_large_final.png"
				},
				{
					"id": "hive_obsidian",
					"title": "Obsidian Hive",
					"meta": "Store unlock | Entitlement-backed",
					"desc": "Uses the existing store entitlement hook so the garage can reflect locked versus owned state.",
					"preview_path": "res://assets/sprites/sf_skin_v1/hive_large_final.png",
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
					"preview_path": "res://assets/sprites/sf_skin_v1/arena_floor.PNG"
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
					"preview_path": "res://assets/sprites/sf_skin_v1/tower_activated.PNG",
					"scaffold_only": true
				}
			]
		}
	}

func _style_static_ui() -> void:
	title_label.text = "GARAGE"
	sub_label.text = "Cosmetic home base inside the dash drawer. Power bars are live; the rest are scaffolded with owned or locked state."
	category_header_label.text = "SURFACES"
	preview_badge_label.text = PREVIEW_BADGE_TEXT
	inventory_header_label.text = "LOADOUT SHELF"
	_apply_font(title_label, _font_semibold, 24)
	_apply_font(sub_label, _font_regular, 13)
	_apply_font(loadout_summary_label, _font_regular, 12)
	_apply_font(category_header_label, _font_semibold, 14)
	_apply_font(category_sub_label, _font_regular, 12)
	_apply_font(selected_title_label, _font_semibold, 20)
	_apply_font(selected_meta_label, _font_regular, 12)
	_apply_font(preview_badge_label, _font_semibold, 11)
	_apply_font(selected_desc_label, _font_regular, 12)
	_apply_font(selection_status_label, _font_regular, 12)
	_apply_font(inventory_header_label, _font_semibold, 14)
	_apply_font(inventory_pvp_tab, _font_semibold, 11)
	_apply_font(inventory_time_puzzle_tab, _font_semibold, 11)
	_apply_font(inventory_note_label, _font_regular, 12)
	_apply_font(equip_button, _font_semibold, 13)
	_style_button(equip_button, Color(0.34, 0.23, 0.09, 0.98), Color(0.95, 0.73, 0.25, 0.85), Color(0.99, 0.96, 0.86, 1.0))
	_style_panel($VBox/Body/CategoryPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))
	_style_panel($VBox/Body/PreviewPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))
	_style_panel($VBox/Body/PreviewPanel/PreviewVBox/PreviewFrame, Color(0.06, 0.07, 0.10, 0.96), Color(0.52, 0.56, 0.66, 0.45))
	_style_panel($VBox/Body/InventoryPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	loadout_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
		button.text = str(category.get("title", category_id)).to_upper()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.pressed.connect(func() -> void:
			_selected_category = category_id
			_status_flash_message = ""
			_sync_selected_item_to_profile()
			_refresh_category_copy()
			_refresh_category_buttons()
			_refresh_inventory()
			_refresh_preview()
		)
		category_list.add_child(button)
		_category_buttons[category_id] = button
		_apply_font(button, _font_semibold, 12)

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

func _refresh_inventory() -> void:
	for child in inventory_list.get_children():
		child.queue_free()
	var category: Dictionary = _catalog.get(_selected_category, {}) as Dictionary
	var items: Array = category.get("items", []) as Array
	for item_any in items:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any as Dictionary
		var state: Dictionary = _item_state(item)
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = str(item.get("id", "")) == _selected_item_id
		button.custom_minimum_size = Vector2(0.0, 74.0)
		button.text = "%s\n%s" % [_inventory_title(item, state), str(item.get("meta", ""))]
		button.pressed.connect(func() -> void:
			_selected_item_id = str(item.get("id", ""))
			_status_flash_message = ""
			_refresh_inventory()
			_refresh_preview()
		)
		inventory_list.add_child(button)
		_apply_font(button, _font_semibold, 12)
		if bool(state.get("equipped", false)):
			_style_button(button, Color(0.18, 0.15, 0.08, 0.98), Color(0.95, 0.77, 0.33, 0.92), Color(1.0, 0.97, 0.88, 1.0))
		elif bool(state.get("owned", false)):
			_style_button(button, Color(0.11, 0.12, 0.15, 0.96), Color(0.46, 0.50, 0.60, 0.80), Color(0.90, 0.94, 0.98, 1.0))
		else:
			_style_button(button, Color(0.10, 0.10, 0.12, 0.96), Color(0.35, 0.28, 0.28, 0.72), Color(0.70, 0.72, 0.76, 1.0))
	inventory_note_label.text = "%s\n%s" % [_inventory_note_for_category(), _buff_loadout_note()]

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
		var item_id: String = _profile_selection_for_category(category_id)
		var item: Dictionary = _item_by_id(category_id, item_id)
		if item.is_empty():
			continue
		parts.append("%s: %s" % [str(_catalog_title(category_id)), str(item.get("title", item_id))])
	loadout_summary_label.text = "Live loadout snapshot: %s" % "  |  ".join(parts)

func _update_equip_button(state: Dictionary) -> void:
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
	if ProfileManager.has_method("get_garage_selection"):
		return str(ProfileManager.call("get_garage_selection", category_id))
	return ""

func _item_state(item: Dictionary) -> Dictionary:
	var owned: bool = not bool(item.get("scaffold_only", false))
	var entitlement: String = str(item.get("entitlement", ""))
	if entitlement != "" and ProfileManager != null and ProfileManager.has_method("has_store_entitlement"):
		owned = bool(ProfileManager.call("has_store_entitlement", entitlement))
	var equipped: bool = str(item.get("id", "")) == _profile_selection_for_category(_selected_category)
	return {
		"owned": owned,
		"equipped": equipped,
		"scaffold_only": bool(item.get("scaffold_only", false))
	}

func _inventory_title(item: Dictionary, state: Dictionary) -> String:
	var prefix: String = "OWNED"
	if bool(state.get("equipped", false)):
		prefix = "EQUIPPED"
	elif bool(state.get("scaffold_only", false)):
		prefix = "PARKED"
	elif not bool(state.get("owned", false)):
		prefix = "LOCKED"
	return "%s  %s" % [prefix, str(item.get("title", "Cosmetic"))]

func _selection_status_copy(item: Dictionary, state: Dictionary) -> String:
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
		_:
			return "Garage scaffold: choose, inspect, and park future runtime hooks in one place."

func _refresh_buff_mode_tabs() -> void:
	if inventory_pvp_tab == null or inventory_time_puzzle_tab == null:
		return
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

func _catalog_title(category_id: String) -> String:
	var category: Dictionary = _catalog.get(category_id, {}) as Dictionary
	return str(category.get("title", category_id)).capitalize()

func _apply_preview_item(item: Dictionary) -> void:
	preview_texture.material = null
	if _selected_category == "power_bars":
		var theme_id: String = str(item.get("powerbar_theme", CosmeticThemeDB.THEME_BASE))
		var texture: Texture2D = CosmeticThemeDB.get_powerbar_texture(theme_id, 4)
		preview_texture.texture = texture
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
		preview_texture.texture = _load_texture(preview_path)
	turntable_slider.value = 0.0
	_preview_dragging = false
	_on_turntable_value_changed(turntable_slider.value)
	_update_preview_pivot()

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	var resource: Variant = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null

func _on_turntable_value_changed(value: float) -> void:
	preview_texture.rotation_degrees = value

func _on_preview_frame_gui_input(event: InputEvent) -> void:
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

func _on_equip_pressed() -> void:
	var item: Dictionary = _selected_item()
	if item.is_empty():
		return
	var state: Dictionary = _item_state(item)
	if not bool(state.get("owned", false)) or bool(state.get("scaffold_only", false)):
		return
	var item_id: String = str(item.get("id", ""))
	var changed: bool = false
	if _selected_category == "power_bars":
		if ProfileManager != null and ProfileManager.has_method("set_powerbar_theme"):
			changed = bool(ProfileManager.call("set_powerbar_theme", item_id))
	else:
		if ProfileManager != null and ProfileManager.has_method("set_garage_selection"):
			changed = bool(ProfileManager.call("set_garage_selection", _selected_category, item_id))
	if changed:
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

func _apply_font(control: Control, font: Font, size: int) -> void:
	if control == null:
		return
	if font != null:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", maxi(1, size))

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
