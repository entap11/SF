extends Node

# Layout-only adapter over the existing inventory, cart and equip controls.
const Copy := preload("res://scripts/ui/buff_ui_copy.gd")
const Catalog := preload("res://scripts/state/buff_catalog.gd")
const TIER_COLORS: Dictionary = {"classic": Color(0.73, 0.54, 1.0), "premium": Color(1.0, 0.40, 0.43), "elite": Color(1.0, 0.81, 0.31)}
var _menu: Control
var _section: String = "loadout"
var _tier: String = "classic"
var _sections: HBoxContainer
var _tiers: HBoxContainer
var _summary: Label

static func install(menu: Control) -> void:
	var adapter: Node = menu.get_node_or_null("BuffMenuPresentation")
	if adapter == null:
		adapter = load("res://scripts/ui/buff_menu_presentation.gd").new()
		adapter.name = "BuffMenuPresentation"
		menu.add_child(adapter)
		adapter.call("setup", menu)
	adapter.call("refresh")

func setup(menu: Control) -> void:
	_menu = menu
	var body: VBoxContainer = menu.get("buffs_body_vbox")
	_sections = HBoxContainer.new()
	_sections.name = "BuffSectionTabs"
	_sections.add_theme_constant_override("separation", 16)
	body.add_child(_sections)
	body.move_child(_sections, 1)
	for section in ["loadout", "store"]:
		var button := _button("Loadout & owned" if section == "loadout" else "Buff store")
		_sections.add_child(button)
		button.pressed.connect(func() -> void:
			_section = section
			refresh())
	_tiers = HBoxContainer.new()
	_tiers.name = "BuffTierTabs"
	_tiers.add_theme_constant_override("separation", 12)
	var library: VBoxContainer = menu.get("buffs_library_vbox")
	library.add_child(_tiers)
	library.move_child(_tiers, 2)
	for tier in ["classic", "premium", "elite"]:
		var button := _button(tier.capitalize())
		button.add_theme_color_override("font_color", TIER_COLORS[tier])
		button.add_theme_color_override("font_pressed_color", TIER_COLORS[tier])
		_tiers.add_child(button)
		button.pressed.connect(func() -> void:
			_tier = tier
			var selected: Dictionary = Catalog.get_buff(str(_menu.get("_buff_selected_id")))
			if str(_menu.get("_buff_selected_origin")) == "library" and not selected.is_empty():
				_menu.call("_set_selected_buff", "buff_%s_%s" % [str(selected.get("canonical_id", "")).to_lower(), tier], "library", -1)
			refresh())
	_summary = Label.new()
	_summary.name = "BuffExplanation"
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.y = 200.0
	_summary.add_theme_font_size_override("font_size", 36)
	_summary.add_theme_color_override("font_color", Color(0.83, 0.9, 0.96))
	body.add_child(_summary)
	body.move_child(_summary, 2)

func refresh() -> void:
	if not is_instance_valid(_menu):
		return
	var store: bool = _section == "store"
	(_menu.get("buffs_library_panel") as Control).visible = store
	(_menu.get("buffs_loadout_panel") as Control).visible = not store
	(_menu.get("_buff_cart_root") as Control).visible = store
	for i in range(2):
		(_sections.get_child(i) as Button).button_pressed = i == (1 if store else 0)
	for i in range(3):
		var tier: String = ["classic", "premium", "elite"][i]
		(_tiers.get_child(i) as Button).button_pressed = _tier == tier
		var grid: Control = (_menu.get("_buff_library_tier_grids") as Dictionary)[tier]
		var panel: Control = grid.get_parent().get_parent().get_parent()
		panel.visible = tier == _tier
		var header: Label = (_menu.get("_buff_library_tier_headers") as Dictionary)[tier]
		header.visible = false
	var title: Label = _menu.get_node("DashPanel/DashBuffsPanel/BuffsVBox/BuffsTitle")
	title.add_theme_font_size_override("font_size", 60)
	var sub: Label = _menu.get_node("DashPanel/DashBuffsPanel/BuffsVBox/BuffsSub")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 36)
	var close: Button = _menu.get("dash_buffs_close")
	close.text = "Back"
	close.icon = null
	close.material = null
	close.set_meta("sf_close_skin", false)
	close.flat = false
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.12, 0.14, 0.19)
	back_style.border_color = Color(0.73, 0.68, 0.47)
	back_style.set_border_width_all(2)
	back_style.set_corner_radius_all(12)
	for state in ["normal", "hover", "pressed", "focus"]:
		close.add_theme_stylebox_override(state, back_style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		close.add_theme_color_override(state, Color(0.98, 0.96, 0.88))
	close.custom_minimum_size = Vector2(0, 120)
	close.add_theme_font_size_override("font_size", 44)
	for control: Control in [_menu.get("buffs_mode_vs_button"), _menu.get("buffs_mode_async_button")]:
		control.custom_minimum_size.y = 100
		control.add_theme_font_size_override("font_size", 40)
	for control: Control in (_menu.get("_buff_category_buttons") as Dictionary).values():
		control.custom_minimum_size.y = 90
		control.add_theme_font_size_override("font_size", 36)
	var top: Control = _menu.get("_buff_loadout_top_panel")
	top.custom_minimum_size.y = 420
	top.size_flags_vertical = Control.SIZE_FILL
	for button: Button in _menu.get("buffs_slot_buttons"):
		_style_item(button, 112)
	for button: Button in _menu.get("_buff_owned_buttons"):
		_style_item(button, 112)
	for button: Button in _menu.get("_buff_library_runtime_buttons"):
		_style_item(button, 148)
	var selected: Dictionary = Catalog.get_buff(str(_menu.get("_buff_selected_id")))
	_summary.text = "%s · %s\n%s" % [str(selected.get("name", "")), Copy.timing(selected), Copy.description(selected)] if not selected.is_empty() else "Choose a buff to see its effect, target and duration."
	_summary.visible = true
	var footer: Label = _menu.get("buffs_footer_label")
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_font_size_override("font_size", 30)
	for property in ["buffs_loadout_header", "buffs_library_header", "_buff_owned_header_label"]:
		var label: Label = _menu.get(property)
		label.add_theme_font_size_override("font_size", 36)

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 100)
	button.add_theme_font_size_override("font_size", 40)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.10, 0.14)
	normal.border_color = Color(0.32, 0.37, 0.47)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	var selected := normal.duplicate() as StyleBoxFlat
	selected.bg_color = Color(0.18, 0.15, 0.10)
	selected.border_color = Color(0.93, 0.76, 0.36)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", selected)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("focus", selected)
	return button

func _style_item(button: Button, height: float) -> void:
	button.custom_minimum_size.y = height
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 38)
	button.add_theme_constant_override("icon_max_width", 92)
	button.add_theme_constant_override("h_separation", 18)
