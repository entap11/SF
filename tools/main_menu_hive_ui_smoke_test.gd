extends SceneTree

func _init() -> void:
	await process_frame
	var scene := load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_HIVE_UI_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	if menu.get_node_or_null("DashPanel/DashHivePanel") == null:
		push_error("MAIN_MENU_HIVE_UI_SMOKE: DashHivePanel missing")
		quit(1)
		return
	if menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow/HiveAbout") == null:
		push_error("MAIN_MENU_HIVE_UI_SMOKE: HiveAbout action missing")
		quit(1)
		return
	if menu.has_method("_ensure_hive_dropdown"):
		menu.call("_ensure_hive_dropdown")
	if menu.has_method("_rebuild_hive_dropdown_options"):
		menu.call("_rebuild_hive_dropdown_options", false)
	var dropdown_body: VBoxContainer = menu.get_node_or_null("HiveDropdown/HiveDropdownVBox") as VBoxContainer
	if dropdown_body == null:
		push_error("MAIN_MENU_HIVE_UI_SMOKE: Hive dropdown body missing")
		quit(1)
		return
	var dropdown_panel: Panel = menu.get_node_or_null("HiveDropdown") as Panel
	if dropdown_panel == null or dropdown_panel.offset_right - dropdown_panel.offset_left < 700.0:
		push_error("MAIN_MENU_HIVE_UI_SMOKE: Hive dropdown is too narrow for readable mobile type")
		quit(1)
		return
	var dropdown_buttons: Array[String] = []
	for child in dropdown_body.get_children():
		var button: Button = child as Button
		if button != null:
			dropdown_buttons.append(button.text)
			if button.custom_minimum_size.y < 64.0 or button.get_theme_font_size("font_size") < 32:
				push_error("MAIN_MENU_HIVE_UI_SMOKE: Hive dropdown action is not mobile-readable: %s" % button.text)
				quit(1)
				return
	for required in ["CREATE A HIVE", "BROWSE HIVES", "MY INVITES", "HIVE RANKINGS"]:
		if not dropdown_buttons.has(required):
			push_error("MAIN_MENU_HIVE_UI_SMOKE: Hive dropdown missing %s" % required)
			quit(1)
			return
	for member_only in ["APPLICATIONS", "MEMBER ACTIONS", "HIVE CHAT"]:
		if dropdown_buttons.has(member_only):
			push_error("MAIN_MENU_HIVE_UI_SMOKE: Hive dropdown leaked member action %s" % member_only)
			quit(1)
			return
	if menu.has_method("_ensure_hive_dashboard_menu_row"):
		menu.call("_ensure_hive_dashboard_menu_row")
	var hive_menu_row: HBoxContainer = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveDashboardMenuRow") as HBoxContainer
	if hive_menu_row == null:
		push_error("MAIN_MENU_HIVE_UI_SMOKE: Hive dashboard menu row missing")
		quit(1)
		return
	var dashboard_buttons: Array[String] = []
	for child in hive_menu_row.get_children():
		var button: Button = child as Button
		if button != null:
			dashboard_buttons.append(button.text)
	for required in ["APPLICATIONS", "MEMBER ACTIONS", "HIVE CHAT", "HIVE RANKINGS"]:
		if not dashboard_buttons.has(required):
			push_error("MAIN_MENU_HIVE_UI_SMOKE: Hive dashboard menu missing %s" % required)
			quit(1)
			return
	var settings_tab: Button = menu.get_node_or_null("DashPanel/DashRoot/DashTabs/SettingsTab") as Button
	if settings_tab == null:
		push_error("MAIN_MENU_HIVE_UI_SMOKE: SettingsTab missing from dash tabs")
		quit(1)
		return
	settings_tab.pressed.emit()
	await process_frame
	var settings_panel: Control = menu.get_node_or_null("DashPanel/DashSettingsPanel") as Control
	if settings_panel == null or not settings_panel.visible:
		push_error("MAIN_MENU_HIVE_UI_SMOKE: SettingsTab did not open DashSettingsPanel")
		quit(1)
		return
	if menu.has_method("_play_mm_boot_sound"):
		menu.call("_play_mm_boot_sound")
		await process_frame
		if menu.get_node_or_null("MMBootSoundPlayer") != null:
			push_error("MAIN_MENU_HIVE_UI_SMOKE: mm_ambient boot player should be disabled")
			quit(1)
			return
	print("MAIN_MENU_HIVE_UI_SMOKE: PASS")
	quit(0)
