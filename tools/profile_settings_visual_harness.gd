extends Control

const MAIN_MENU_SCENE := preload("res://scenes/MainMenu.tscn")
const OUTPUT_DIR: String = "/tmp"

func _ready() -> void:
	get_viewport().size = Vector2i(720, 1280)
	var menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	for _frame in range(6):
		await get_tree().process_frame
	var settings_tab: Button = menu.get_node_or_null("DashPanel/DashRoot/DashTabs/SettingsTab") as Button
	if settings_tab == null:
		_fail("SettingsTab missing")
		return
	settings_tab.pressed.emit()
	for _frame in range(8):
		await get_tree().process_frame
	var panel: Control = menu.get_node_or_null("DashPanel/DashSettingsPanel") as Control
	if panel == null or not panel.visible:
		_fail("Dash Settings did not open")
		return
	var profile_panel: Control = panel.get_node_or_null("SettingsVBox/SettingsBody/ProfilePanel") as Control
	var category_tabs: HBoxContainer = profile_panel.get_node_or_null("SettingsCategoryTabs") as HBoxContainer if profile_panel != null else null
	if category_tabs == null:
		_fail("settings category tabs missing")
		return
	var category_name: String = OS.get_environment("SF_SETTINGS_CATEGORY").strip_edges().capitalize()
	if not category_name in ["Account", "Audio", "Graphics", "Support"]:
		category_name = "Account"
	var category_button: Button = category_tabs.get_node_or_null("%sTab" % category_name) as Button
	if category_button == null:
		_fail("%s tab missing" % category_name)
		return
	if category_name != "Account":
		category_button.pressed.emit()
	for _frame in range(8):
		await get_tree().process_frame
	var output_path: String = "%s/swarmfront_profile_settings_%s.png" % [OUTPUT_DIR, category_name.to_lower()]
	if not await _capture(output_path):
		return
	print("PROFILE_SETTINGS_VISUAL: %s" % output_path)
	get_tree().quit(0)

func _capture(output_path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		_fail("failed to save screenshot (%d)" % save_error)
		return false
	return true

func _fail(message: String) -> void:
	push_error("PROFILE_SETTINGS_VISUAL: %s" % message)
	get_tree().quit(1)
