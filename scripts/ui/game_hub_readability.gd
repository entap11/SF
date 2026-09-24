extends MarginContainer
## Reflows existing route controls. Launch, eligibility and fee callbacks stay with MainMenu.

const Style = preload("res://scripts/ui/menu_surface_style.gd")
const Typography = preload("res://scripts/ui/ui_typography.gd")
const Cluster = preload("res://scripts/ui/menu_option_cluster.gd")
const HexSurface = preload("res://scripts/ui/menu_hex_surface.gd")
const FREE_GROUPS := [
	[
		["Human1v1Button", "1V1", "Head-to-head match"],
		["Human2v2Button", "2V2", "Team match"],
		["Human3pFfaButton", "3-PLAYER FFA", "Free-for-all"],
		["Human4pFfaButton", "4-PLAYER FFA", "Free-for-all"],
		["CrucibleButton", "CRUCIBLE", "Open the Crucible"],
		["HumanCtfButton", "CAPTURE THE FLAG", "Live match"],
		["HumanHiddenCtfButton", "HIDDEN CAPTURE THE FLAG", "Live match"]
	],
	[
		["WeeklyButton", "WEEKLY", "Scheduled contests"],
		["MonthlyButton", "MONTHLY", "Scheduled contests"],
		["SeasonButton", "SEASON", "Scheduled contests"],
		["ProgressiveButton", "GAUNTLET", "Explore Gauntlet contests"],
		["StageRace3Button", "STAGE RACE · 3 MAPS", "Rolling contest"],
		["StageRace5Button", "STAGE RACE · 5 MAPS", "Rolling contest"]
	],
	[
		["CaptureFlagButton", "CAPTURE THE FLAG", "Bot practice · 1 map"],
		["HiddenFlagButton", "HIDDEN CAPTURE THE FLAG", "Bot practice · 1 map"],
		["TimedRace3Button", "RACE · 3 MAPS", "Play against bots"],
		["MissNOut3Button", "MISS N OUT · 3 MAPS", "Play against bots"],
		["TimedRace5Button", "RACE · 5 MAPS", "Play against bots"],
		["MissNOut5Button", "MISS N OUT · 5 MAPS", "Play against bots"]
	]
]
const HUMAN_TITLES := {"1V1": "1V1", "CTF": "CAPTURE THE FLAG", "HIDDEN CTF": "HIDDEN CAPTURE THE FLAG", "2V2": "2V2", "3P FFA": "3-PLAYER FFA", "4P FFA": "4-PLAYER FFA"}

var _menu: Control
var _panel: Panel
var _paid := false
var _pages: Array[VBoxContainer] = []
var _tabs: Array[Button] = []
var _scroll: ScrollContainer
var _money_tabs: HBoxContainer
var _tier_row: HBoxContainer
var _fee: Label
var _routes: Array[Button] = []
var _back: Button
var _status: Label
var _clusters: Array[Container] = []

func configure(menu: Control, panel: Panel, paid: bool) -> void:
	_menu = menu
	_panel = panel
	_paid = paid
	name = "ReadableHub"
	var existing_buttons: Array[Button] = []
	_collect_buttons(panel, existing_buttons)
	for child in panel.get_children():
		if child is CanvasItem and child != self:
			child.hide()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Style.surface(Color("0e1015"), Color("0e1015"), 0))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 12)
	add_child(frame)
	_label(frame, "MONEY GAMES" if paid else "FREE ROLL", 64)
	_label(frame, "Choose your entry, then your game." if paid else "Choose how you want to play.", 36, Style.MUTED)
	if paid:
		_adopt_money_controls(frame, panel)
	var tabs := HBoxContainer.new()
	tabs.name = "Categories"
	tabs.add_theme_constant_override("separation", 12)
	frame.add_child(tabs)
	_scroll = ScrollContainer.new()
	_scroll.name = "ModesScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	frame.add_child(_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)
	var names: Array = ["LIVE MATCHES", "CONTESTS"] if paid else ["LIVE MATCHES", "CONTESTS", "BOT MODES"]
	for index in range(names.size()):
		var tab := Button.new()
		tab.text = names[index]
		tab.name = "Category%d" % index
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.toggle_mode = true
		Style.action(tab)
		tab.custom_minimum_size.y = 132
		tabs.add_child(tab)
		_tabs.append(tab)
		tab.pressed.connect(_select_category.bind(index))
		var page := VBoxContainer.new()
		page.name = "LiveMatches" if index == 0 else ("Contests" if index == 1 else "BotModes")
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 12)
		content.add_child(page)
		_pages.append(page)
	if paid:
		_adopt_paid_routes(existing_buttons)
	else:
		for index in range(FREE_GROUPS.size()):
			var groups: Array = [[5, "MATCHES"], [2, "FLAG MATCHES"]] if index == 0 else ([[4, "SCHEDULED"], [2, "STAGE RACE"]] if index == 1 else [[2, "FLAGS"], [2, "3 MAPS"], [2, "5 MAPS"]])
			var offset := 0
			for group in groups:
				var cluster := _new_cluster(_pages[index], group[1])
				for entry in FREE_GROUPS[index].slice(offset, offset + int(group[0])):
					var button := panel.get_node("EntryScroll/EntryBody/EntryCanvas/" + entry[0]) as Button
					_adopt_route(cluster, button, entry[1], entry[2])
				offset += int(group[0])
	_status = _label(frame, "", 34)
	_status.hide()
	_back = Button.new()
	_back.name = "BackToMainMenu"
	_back.text = "BACK TO MAIN MENU"
	Style.action(_back)
	_back.custom_minimum_size.y = 144
	_back.add_theme_font_size_override("font_size", 40)
	frame.add_child(_back)
	_back.pressed.connect(Callable(_menu, "_close_entry_route_modal"))
	_menu.call("_enable_touch_drag_scroll", _scroll)
	_scroll.gui_input.connect(Callable(_menu, "_on_free_roll_scroll_gui_input"))
	resized.connect(_layout)
	_select_category(0)
	refresh_money()
	_layout()

func _label(parent: Node, value: String, font_size: int, color: Color = Style.TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", Typography.regular_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _collect_buttons(node: Node, result: Array[Button]) -> void:
	if node is Button:
		result.append(node)
	for child in node.get_children():
		_collect_buttons(child, result)

func _adopt_route(parent: Container, button: Button, title: String, detail: String) -> void:
	button.reparent(parent)
	# These controls previously belonged to another scroll. Rebind only its drag handler.
	for connection in button.get_signal_connection_list("gui_input"):
		var callback: Callable = connection.callable
		if callback.get_method() == "_on_touch_drag_scroll_gui_input":
			button.gui_input.disconnect(callback)
	if button.has_meta("sf_touch_drag_scroll_bound"):
		button.remove_meta("sf_touch_drag_scroll_bound")
	if not button.has_meta("sf_free_roll_press_guard"):
		for connection in button.get_signal_connection_list("pressed"):
			var action: Callable = connection.callable
			button.pressed.disconnect(action)
			_menu.call("_connect_free_roll_guarded_press", button, action)
	button.set_meta("sf_readable_menu", true)
	button.set_meta("sf_readable_title", title)
	button.set_meta("sf_readable_detail", detail)
	_style_route(button, detail)
	_routes.append(button)
	button.show()

func _style_route(button: Button, detail: String) -> void:
	_clear_art(button)
	Style.action(button)
	button.text = str(button.get_meta("sf_readable_title")) + "\n" + detail
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 44)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	button.custom_minimum_size = Vector2(0, 188)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not button.has_node("HexSurface"):
		var hex := HexSurface.new()
		hex.name = "HexSurface"
		button.add_child(hex)
		var margin := MarginContainer.new()
		margin.name = "ReadableCopy"
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + side, 38)
		for side in ["top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 12)
		button.add_child(margin)
		var copy := VBoxContainer.new()
		copy.name = "Copy"
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		copy.add_theme_constant_override("separation", 8)
		margin.add_child(copy)
		for entry in [["Title", 44], ["Detail", 32]]:
			var label := _label(copy, "", entry[1], Style.TEXT if entry[0] == "Title" else Style.MUTED)
			label.name = entry[0]
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(button.get_node("ReadableCopy/Copy/Title") as Label).text = str(button.get_meta("sf_readable_title"))
	(button.get_node("ReadableCopy/Copy/Detail") as Label).text = detail
	button.get_node("HexSurface").queue_redraw()

func _clear_art(button: Button) -> void:
	button.icon = null
	button.material = null
	button.modulate = Color.WHITE
	button.scale = Vector2.ONE
	button.set_meta("sf_readable_menu", true)
	button.set_meta("sf_game_hub_base_modulate", Color.WHITE)
	button.set_meta("sf_game_hub_base_scale", Vector2.ONE)
	for child in button.get_children():
		if child is CanvasItem and child.name not in ["HexSurface", "ReadableCopy"]:
			child.hide()

func _new_cluster(parent: Container, title: String) -> Container:
	_label(parent, title, 34, Style.MUTED)
	var cluster := Cluster.new()
	parent.add_child(cluster)
	_clusters.append(cluster)
	return cluster

func set_cluster_arrangement(value: String) -> void:
	for cluster in _clusters:
		cluster.set("arrangement", value)

func sync_status(value: String) -> void:
	if _status != null and _status.text != value:
		_status.text = value
		_status.visible = not value.is_empty() and value != "Ready"

func _adopt_paid_routes(buttons: Array[Button]) -> void:
	var scope_groups: Dictionary = {}
	var matches := _new_cluster(_pages[0], "MATCHES")
	var flags := _new_cluster(_pages[0], "FLAG MATCHES")
	for button in buttons:
		if button.has_meta("sf_money_paid_route"):
			var mode := str(button.get_meta("sf_money_route_label", ""))
			_adopt_route(flags if mode in ["CTF", "HIDDEN CTF"] else matches, button, str(HUMAN_TITLES.get(mode, mode)), "")
		elif button.has_meta("sf_paid_contest_family"):
			var scope := str(button.get_meta("sf_paid_contest_scope"))
			if not scope_groups.has(scope):
				scope_groups[scope] = _new_cluster(_pages[1], "SIT & GO" if scope == "EVENT" else str(_menu.call("_scope_display_label", scope)).to_upper())
			_adopt_route(scope_groups[scope], button, str(button.get_meta("sf_paid_contest_family_label")).to_upper(), "")

func _adopt_money_controls(parent: Container, panel: Panel) -> void:
	var body := panel.get_node("EntryScroll/EntryBody")
	_money_tabs = body.get_node("MoneyDivisions")
	_tier_row = body.get_node("MoneyEntryTiers")
	_fee = body.get_node("MoneyEntryFee")
	for control in [_money_tabs, _tier_row, _fee]:
		control.reparent(parent)
		control.show()
	_tier_row.child_entered_tree.connect(func(_child: Node) -> void: call_deferred("refresh_money"))
	_fee.add_theme_font_size_override("font_size", 34)
	_fee.add_theme_color_override("font_color", Style.TEXT)
	_fee.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fee.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func refresh_money() -> void:
	if not _paid or _money_tabs == null:
		return
	for button: Button in _money_tabs.get_children():
		_clear_art(button)
		Style.action(button)
		button.custom_minimum_size = Vector2(0, 112)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 32)
		var id := str(button.get_meta("sf_money_division_id", ""))
		var active := id == str(_menu.get("_money_games_selected_division"))
		button.toggle_mode = true
		button.set_pressed_no_signal(active)
		button.text = ("SELECTED\n" if active else "") + id.replace("_", " ").to_upper()
		if button.disabled:
			button.text = "CLASSIFIED\nLocked"
	for button: Button in _tier_row.get_children():
		if button.is_queued_for_deletion():
			continue
		_clear_art(button)
		Style.action(button)
		var amount := int(button.get_meta("sf_money_entry_tier_usd", 0))
		var active := amount == int(_menu.get("_money_games_selected_tier"))
		button.text = "$%d%s" % [amount, " · Selected" if active else ""]
		if bool(button.get_meta("sf_money_unaffordable", false)):
			button.text += "\nAdd funds"
		button.custom_minimum_size = Vector2(0, 112)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 40)
		button.toggle_mode = true
		button.set_pressed_no_signal(active)
	for button in _routes:
		var amount := int(button.get_meta("sf_money_entry_usd", button.get_meta("sf_paid_contest_denomination", 0)))
		var affordable: bool = _menu.call("_can_afford_money_entry", amount)
		_style_route(button, "Entry $%d%s" % [amount, " · Add funds required" if not affordable else ""])

func _select_category(index: int) -> void:
	for i in range(_pages.size()):
		_pages[i].visible = i == index
		_tabs[i].set_pressed_no_signal(i == index)
	_scroll.scroll_vertical = 0

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_menu.call("_close_entry_route_modal")
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree() and is_instance_valid(_menu):
		_menu.call("_close_entry_route_modal")

func _layout() -> void:
	var top := 0.0
	var bottom := 0.0
	if OS.has_feature("android") or OS.has_feature("ios"):
		var window_size := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var factor := size.y / maxf(1.0, window_size.y)
		top = maxf(0, safe.position.y * factor)
		bottom = maxf(0, (window_size.y - safe.end.y) * factor)
	add_theme_constant_override("margin_left", 28)
	add_theme_constant_override("margin_right", 28)
	add_theme_constant_override("margin_top", 32 + int(top))
	add_theme_constant_override("margin_bottom", 24 + int(bottom))
