extends SceneTree

const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const MIN_READABLE_FONT_SIZE := 14
const MAX_READABLE_FONT_SIZE := 28
const MIN_CONTROL_HEIGHT := 40.0
const MAX_CONTROL_HEIGHT := 72.0
const EXPECTED_FORM_HEIGHT := 760.0

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
	var title := menu.get_node_or_null("DashPanel/DashSettingsPanel/SettingsVBox/SettingsTitle") as Label
	var subtitle := menu.get_node_or_null("DashPanel/DashSettingsPanel/SettingsVBox/SettingsSub") as Label
	_expect(scroll != null, "settings panel should use a scroll container")
	_expect(root_vbox != null, "settings form should be inside scroll container")
	_expect(panel.custom_minimum_size.y >= EXPECTED_FORM_HEIGHT, "settings panel should keep a scrollable form height")
	_expect(root_vbox != null and root_vbox.custom_minimum_size.y >= EXPECTED_FORM_HEIGHT, "settings form should keep a scrollable form height")
	_expect_readable_label(title, "settings title")
	_expect_readable_label(subtitle, "settings subtitle")
	_expect(panel.find_child("PowerBarThemeRow", true, false) == null, "PowerBar theme row should not be in settings")
	_expect(panel.find_child("PowerBarThemeOption", true, false) == null, "PowerBar theme selector should not be in settings")
	if root_vbox != null:
		_expect_readable_line_edit(root_vbox, "ProfileRow/DisplayNameInput", "handle input")
		_expect_readable_button(root_vbox, "UserIdSection/UserIdCurrentRow/CopyUserIdButton", "copy user ID button")
		_expect_readable_toggle(root_vbox, "VideoSection/GpuVfxRow/GpuVfxToggle", "GPU VFX toggle")
		_expect_readable_option(root_vbox, "PerformanceSection/PerformanceModeRow/PerformanceModeOption", "performance option")
		_expect_readable_button(root_vbox, "CommunitySafetySection/CommunitySafetyRow/CommunitySafetyButton", "community safety button")
		var safety_button := root_vbox.get_node_or_null("CommunitySafetySection/CommunitySafetyRow/CommunitySafetyButton") as Button
		if safety_button != null:
			safety_button.pressed.emit()
			await process_frame
			var dialog := panel.get_node_or_null("CommunitySafetyDialog") as AcceptDialog
			_expect(dialog != null and dialog.visible, "community safety button should open safety dialog")
	if not _failed:
		print("PROFILE_SETTINGS_MOBILE_LAYOUT_SMOKE: PASS")
	quit(1 if _failed else 0)

func _expect_readable_line_edit(root_vbox: VBoxContainer, path: String, label: String) -> void:
	var control := root_vbox.get_node_or_null(path) as LineEdit
	_expect(control != null, "%s should exist" % label)
	if control == null:
		return
	_expect_readable_control(control, label)

func _expect_readable_button(root_vbox: VBoxContainer, path: String, label: String) -> void:
	var control := root_vbox.get_node_or_null(path) as Button
	_expect(control != null, "%s should exist" % label)
	if control == null:
		return
	_expect_readable_control(control, label)

func _expect_readable_toggle(root_vbox: VBoxContainer, path: String, label: String) -> void:
	var control := root_vbox.get_node_or_null(path) as CheckButton
	_expect(control != null, "%s should exist" % label)
	if control == null:
		return
	_expect_readable_control(control, label)

func _expect_readable_option(root_vbox: VBoxContainer, path: String, label: String) -> void:
	var control := root_vbox.get_node_or_null(path) as OptionButton
	_expect(control != null, "%s should exist" % label)
	if control == null:
		return
	_expect_readable_control(control, label)

func _expect_readable_label(control: Label, label: String) -> void:
	_expect(control != null, "%s should exist" % label)
	if control == null:
		return
	var font_size := control.get_theme_font_size("font_size")
	_expect(font_size >= MIN_READABLE_FONT_SIZE and font_size <= MAX_READABLE_FONT_SIZE, "%s font should be readable and bounded: %d" % [label, font_size])

func _expect_readable_control(control: Control, label: String) -> void:
	var min_height := control.custom_minimum_size.y
	var font_size := control.get_theme_font_size("font_size")
	_expect(min_height >= MIN_CONTROL_HEIGHT and min_height <= MAX_CONTROL_HEIGHT, "%s height should be readable and bounded: %.1f" % [label, min_height])
	_expect(font_size >= MIN_READABLE_FONT_SIZE and font_size <= MAX_READABLE_FONT_SIZE, "%s font should be readable and bounded: %d" % [label, font_size])

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PROFILE_SETTINGS_MOBILE_LAYOUT_SMOKE: %s" % message)
