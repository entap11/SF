extends Control
class_name DashBuffsHero

const BuffCatalog := preload("res://scripts/state/buff_catalog.gd")

const FONT_REGULAR_PATH := "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const BUFF_MODE_VS: String = "vs"
const BUFF_MODE_ASYNC: String = "async"

@onready var title_label: Label = $VBox/Header/Title
@onready var sub_label: Label = $VBox/Header/Sub
@onready var pvp_tab: Button = $VBox/ModeTabs/PvpTab
@onready var time_puzzle_tab: Button = $VBox/ModeTabs/TimePuzzleTab
@onready var snapshot_title: Label = $VBox/Body/TopRow/SnapshotPanel/SnapshotVBox/SnapshotHeader
@onready var snapshot_sub: Label = $VBox/Body/TopRow/SnapshotPanel/SnapshotVBox/SnapshotSub
@onready var slots_list: VBoxContainer = $VBox/Body/TopRow/SnapshotPanel/SnapshotVBox/SlotsList
@onready var library_title: Label = $VBox/Body/TopRow/LibraryPanel/LibraryVBox/LibraryHeader
@onready var library_sub: Label = $VBox/Body/TopRow/LibraryPanel/LibraryVBox/LibrarySub
@onready var category_list: VBoxContainer = $VBox/Body/TopRow/LibraryPanel/LibraryVBox/CategoryList
@onready var footer_label: Label = $VBox/Body/FooterPanel/FooterVBox/FooterText

var _font_regular: Font = null
var _font_semibold: Font = null
var _active_mode: String = BUFF_MODE_VS

func _ready() -> void:
	_load_fonts()
	_style_ui()
	pvp_tab.pressed.connect(func() -> void:
		_set_mode(BUFF_MODE_VS)
	)
	time_puzzle_tab.pressed.connect(func() -> void:
		_set_mode(BUFF_MODE_ASYNC)
	)
	refresh_view()

func refresh_view() -> void:
	_refresh_mode_tabs()
	_refresh_snapshot()
	_refresh_library()
	_refresh_footer()

func _load_fonts() -> void:
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		_font_regular = load(FONT_REGULAR_PATH) as Font
	if ResourceLoader.exists(FONT_SEMIBOLD_PATH):
		_font_semibold = load(FONT_SEMIBOLD_PATH) as Font

func _style_ui() -> void:
	title_label.text = "BUFFS"
	sub_label.text = "Mode-aware loadout control for competitive PvP and Time Puzzle routes."
	snapshot_title.text = "LOADOUT SNAPSHOT"
	library_title.text = "BUFF LIBRARY"
	_apply_font(title_label, _font_semibold, 24)
	_apply_font(sub_label, _font_regular, 13)
	_apply_font(snapshot_title, _font_semibold, 14)
	_apply_font(snapshot_sub, _font_regular, 12)
	_apply_font(library_title, _font_semibold, 14)
	_apply_font(library_sub, _font_regular, 12)
	_apply_font(footer_label, _font_regular, 12)
	_apply_font(pvp_tab, _font_semibold, 11)
	_apply_font(time_puzzle_tab, _font_semibold, 11)
	_style_panel($VBox/Body/TopRow/SnapshotPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))
	_style_panel($VBox/Body/TopRow/LibraryPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))
	_style_panel($VBox/Body/FooterPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))

func _set_mode(mode: String) -> void:
	var next_mode: String = BUFF_MODE_ASYNC if mode == BUFF_MODE_ASYNC else BUFF_MODE_VS
	if next_mode == _active_mode:
		return
	_active_mode = next_mode
	refresh_view()

func _refresh_mode_tabs() -> void:
	var pvp_selected: bool = _active_mode == BUFF_MODE_VS
	pvp_tab.button_pressed = pvp_selected
	time_puzzle_tab.button_pressed = not pvp_selected
	if pvp_selected:
		_style_button(pvp_tab, Color(0.19, 0.14, 0.08, 0.98), Color(0.93, 0.74, 0.31, 0.90), Color(0.99, 0.96, 0.88, 1.0))
		_style_button(time_puzzle_tab, Color(0.10, 0.11, 0.15, 0.96), Color(0.40, 0.43, 0.52, 0.78), Color(0.90, 0.93, 0.98, 1.0))
	else:
		_style_button(pvp_tab, Color(0.10, 0.11, 0.15, 0.96), Color(0.40, 0.43, 0.52, 0.78), Color(0.90, 0.93, 0.98, 1.0))
		_style_button(time_puzzle_tab, Color(0.19, 0.14, 0.08, 0.98), Color(0.93, 0.74, 0.31, 0.90), Color(0.99, 0.96, 0.88, 1.0))

func _refresh_snapshot() -> void:
	for child in slots_list.get_children():
		child.queue_free()
	var mode_name: String = "PvP" if _active_mode == BUFF_MODE_VS else "Time Puzzles"
	snapshot_sub.text = "%s loadout uses the profile-backed mode-specific buff shelf." % mode_name
	var loadout: Array[String] = _mode_loadout()
	if loadout.is_empty():
		var empty := Label.new()
		empty.text = "No buffs equipped yet."
		_apply_font(empty, _font_regular, 12)
		slots_list.add_child(empty)
		return
	for idx in range(loadout.size()):
		var buff_id: String = loadout[idx]
		var buff: Dictionary = BuffCatalog.get_buff(buff_id)
		var row := Label.new()
		row.text = "Slot %d  %s" % [idx + 1, str(buff.get("name", buff_id))]
		_apply_font(row, _font_semibold, 12)
		slots_list.add_child(row)

func _refresh_library() -> void:
	for child in category_list.get_children():
		child.queue_free()
	var owned_ids: Array[String] = _mode_owned_ids()
	var owned_count: int = owned_ids.size()
	var unique_by_category: Dictionary = {}
	for buff_id in owned_ids:
		var buff: Dictionary = BuffCatalog.get_buff(buff_id)
		var category: String = str(buff.get("category", "unknown")).strip_edges()
		if not unique_by_category.has(category):
			unique_by_category[category] = 0
		unique_by_category[category] = int(unique_by_category.get(category, 0)) + 1
	library_sub.text = "%d owned buffs in this mode. Category spread below." % owned_count
	var categories: Array = unique_by_category.keys()
	categories.sort()
	if categories.is_empty():
		var empty := Label.new()
		empty.text = "No owned buffs yet."
		_apply_font(empty, _font_regular, 12)
		category_list.add_child(empty)
		return
	for category_any in categories:
		var category: String = str(category_any)
		var row := Label.new()
		row.text = "%s  |  %d owned" % [category.capitalize(), int(unique_by_category.get(category, 0))]
		_apply_font(row, _font_regular, 12)
		category_list.add_child(row)

func _refresh_footer() -> void:
	var mode_name: String = "PvP" if _active_mode == BUFF_MODE_VS else "Time Puzzle"
	footer_label.text = "%s loadout is the active dash context. Full drag/drop editing can stay in the dedicated Buffs flow until we consolidate surfaces." % mode_name

func _mode_loadout() -> Array[String]:
	var out: Array[String] = []
	if ProfileManager != null and ProfileManager.has_method("get_buff_loadout_ids_for_mode"):
		var loadout_any: Variant = ProfileManager.call("get_buff_loadout_ids_for_mode", _active_mode)
		if typeof(loadout_any) == TYPE_ARRAY:
			for buff_id_any in loadout_any as Array:
				var buff_id: String = str(buff_id_any).strip_edges()
				if buff_id != "":
					out.append(buff_id)
	return out

func _mode_owned_ids() -> Array[String]:
	var out: Array[String] = []
	if ProfileManager != null and ProfileManager.has_method("get_owned_buff_ids_for_mode"):
		var owned_any: Variant = ProfileManager.call("get_owned_buff_ids_for_mode", _active_mode)
		if typeof(owned_any) == TYPE_ARRAY:
			for buff_id_any in owned_any as Array:
				var buff_id: String = str(buff_id_any).strip_edges()
				if buff_id != "":
					out.append(buff_id)
	return out

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
	normal.content_margin_top = 9
	normal.content_margin_right = 12
	normal.content_margin_bottom = 9
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
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
