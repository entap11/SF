extends SceneTree

const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const EXPECTED_FONT_SIZE := 48
const EXPECTED_CONTROL_HEIGHT := 132.0
const EXPECTED_TOGGLE_HEIGHT := 120.0
const EXPECTED_FORM_HEIGHT := 2280.0

var _failed: bool = false

func _init() -> void:
	await process_frame
	var scene := load(MAIN_MENU_SCENE_PATH) as PackedScene
	_expect(scene != null, "main menu scene should load")
	if _failed:
		quit(1)
		return
	var menu := scene.instantiate() as Control
	_expect(menu != null, "main menu should instantiate")
	if _failed:
		quit(1)
		return
	get_root().add_child(menu)
	await process_frame
	var settings_tab := menu.get_node_or_null("DashPanel/DashRoot/DashTabs/SettingsTab") as Button
	_expect(settings_tab != null, "settings tab should exist")
	if settings_tab != null:
		settings_tab.pressed.emit()
	await process_frame
	await process_frame

	var panel := menu.get_node_or_null("DashPanel/DashSettingsPanel/SettingsVBox/SettingsBody/ProfilePanel") as Control
	_expect(panel != null, "profile settings panel should exist")
	if panel == null:
		quit(1)
		return
	var scroll := panel.get_node_or_null("SettingsScroll") as ScrollContainer
	var root_vbox := panel.get_node_or_null("SettingsScroll/VBox") as VBoxContainer
	_expect(scroll != null, "settings panel should use a scroll container")
	_expect(root_vbox != null, "settings form should be inside scroll container")
	_expect(panel.custom_minimum_size.y >= EXPECTED_FORM_HEIGHT, "settings panel minimum height should be scaled")
	_expect(root_vbox != null and root_vbox.custom_minimum_size.y >= EXPECTED_FORM_HEIGHT, "settings form minimum height should be scaled")
	_expect(panel.find_child("PowerBarThemeRow", true, false) == null, "PowerBar theme row should not be in settings")
	_expect(panel.find_child("PowerBarThemeOption", true, false) == null, "PowerBar theme selector should not be in settings")
	if root_vbox != null:
		_expect_large_line_edit(root_vbox, "ProfileRow/DisplayNameInput", "handle input")
		_expect_large_button(root_vbox, "UserIdSection/UserIdCurrentRow/CopyUserIdButton", "copy user ID button")
		_expect_large_toggle(root_vbox, "VideoSection/GpuVfxRow/GpuVfxToggle", "GPU VFX toggle")
		_expect_large_option(root_vbox, "PerformanceSection/PerformanceModeRow/PerformanceModeOption", "performance option")
	if not _failed:
		print("PROFILE_SETTINGS_MOBILE_LAYOUT_SMOKE: PASS")
	quit(1 if _failed else 0)

func _expect_large_line_edit(root_vbox: VBoxContainer, path: String, label: String) -> void:
	var control := root_vbox.get_node_or_null(path) as LineEdit
	_expect(control != null, "%s should exist" % label)
	if control == null:
		return
	_expect(control.custom_minimum_size.y >= EXPECTED_CONTROL_HEIGHT, "%s should have mobile-sized height" % label)
	_expect(control.get_theme_font_size("font_size") >= EXPECTED_FONT_SIZE, "%s should have mobile-sized text" % label)

func _expect_large_button(root_vbox: VBoxContainer, path: String, label: String) -> void:
	var control := root_vbox.get_node_or_null(path) as Button
	_expect(control != null, "%s should exist" % label)
	if control == null:
		return
	_expect(control.custom_minimum_size.y >= EXPECTED_CONTROL_HEIGHT, "%s should have mobile-sized height" % label)
	_expect(control.get_theme_font_size("font_size") >= EXPECTED_FONT_SIZE, "%s should have mobile-sized text" % label)

func _expect_large_toggle(root_vbox: VBoxContainer, path: String, label: String) -> void:
	var control := root_vbox.get_node_or_null(path) as CheckButton
	_expect(control != null, "%s should exist" % label)
	if control == null:
		return
	_expect(control.custom_minimum_size.y >= EXPECTED_TOGGLE_HEIGHT, "%s should have mobile-sized height" % label)
	_expect(control.get_theme_font_size("font_size") >= EXPECTED_FONT_SIZE, "%s should have mobile-sized text" % label)

func _expect_large_option(root_vbox: VBoxContainer, path: String, label: String) -> void:
	var control := root_vbox.get_node_or_null(path) as OptionButton
	_expect(control != null, "%s should exist" % label)
	if control == null:
		return
	_expect(control.custom_minimum_size.y >= EXPECTED_CONTROL_HEIGHT, "%s should have mobile-sized height" % label)
	_expect(control.get_theme_font_size("font_size") >= EXPECTED_FONT_SIZE, "%s should have mobile-sized text" % label)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PROFILE_SETTINGS_MOBILE_LAYOUT_SMOKE: %s" % message)
