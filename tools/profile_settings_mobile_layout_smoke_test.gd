extends SceneTree

const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const SCREEN_TITLE_FONT_SIZE := 56
const SUBTITLE_FONT_SIZE := 34
const BODY_FONT_SIZE := 32
const COMPACT_FONT_SIZE := 30
const MIN_CONTROL_HEIGHT := 64.0
const MIN_TOGGLE_CONTROL_HEIGHT := 88.0
const MIN_TOGGLE_CONTROL_WIDTH := 184.0
const MIN_TOGGLE_TRACK_WIDTH := 112.0
const MIN_TOGGLE_TRACK_HEIGHT := 56.0
const PERSISTENT_ACTION_HEIGHT := 88.0

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
	var done_button := menu.get_node_or_null("DashPanel/DashSettingsPanel/SettingsVBox/SettingsClose") as Button
	var settings_workspace := menu.get_node_or_null("DashPanel/DashSettingsPanel") as Panel
	var category_tabs := panel.get_node_or_null("SettingsCategoryTabs") as HBoxContainer
	_expect(scroll != null, "settings panel should use a scroll container")
	_expect(root_vbox != null, "settings form should be inside scroll container")
	_expect(category_tabs != null and category_tabs.get_child_count() == 4, "settings should expose four peer category tabs")
	_expect(title != null and title.get_theme_font_size("font_size") >= SCREEN_TITLE_FONT_SIZE, "settings title should use the 56-unit screen-title token")
	_expect(subtitle != null and subtitle.get_theme_font_size("font_size") >= SUBTITLE_FONT_SIZE, "settings subtitle should use the 34-unit subtitle token")
	_expect(done_button != null and done_button.text == "DONE", "immediate settings should close with DONE")
	if done_button != null:
		_expect(done_button.custom_minimum_size.y >= PERSISTENT_ACTION_HEIGHT, "DONE should meet the persistent-action touch floor")
		_expect(done_button.get_theme_font_size("font_size") >= SUBTITLE_FONT_SIZE, "DONE label should use readable button type")
	_expect(panel.find_child("PowerBarThemeRow", true, false) == null, "PowerBar theme row should not be in settings")
	_expect(panel.find_child("PowerBarThemeOption", true, false) == null, "PowerBar theme selector should not be in settings")
	if root_vbox != null:
		var account_tab := category_tabs.get_node_or_null("AccountTab") as Button if category_tabs != null else null
		var audio_tab := category_tabs.get_node_or_null("AudioTab") as Button if category_tabs != null else null
		var support_tab := category_tabs.get_node_or_null("SupportTab") as Button if category_tabs != null else null
		_expect(account_tab != null and account_tab.button_pressed, "Account should be the initial selected category")
		for tab_any in category_tabs.get_children() if category_tabs != null else []:
			var tab := tab_any as Button
			if tab != null:
				_expect(tab.custom_minimum_size.y >= MIN_CONTROL_HEIGHT, "%s tab should meet touch floor" % tab.text)
				_expect(tab.get_theme_font_size("font_size") >= COMPACT_FONT_SIZE, "%s tab should use compact-button type" % tab.text)
		_expect(root_vbox.get_node("ProfileRow").visible, "Account content should be visible initially")
		_expect(not root_vbox.get_node("AudioSection").visible, "Audio content should use progressive disclosure")
		_expect(not root_vbox.get_node("AdminSection").visible, "developer administration must not appear in player settings")
		_expect_readable_line_edit(root_vbox, "ProfileRow/DisplayNameInput", "handle input")
		_expect_readable_button(root_vbox, "ProfileRow/ApplyDisplayNameButton", "change Call Sign button")
		_expect_readable_button(root_vbox, "UserIdSection/UserIdCurrentRow/CopyUserIdButton", "copy user ID button")
		if audio_tab != null:
			audio_tab.pressed.emit()
			await process_frame
			_expect(root_vbox.get_node("AudioSection").visible, "Audio tab should reveal audio settings")
			_expect(not root_vbox.get_node("ProfileRow").visible, "Audio tab should hide account settings")
			for toggle_data in [
				["AudioSection/MasterAudioRow/MasterAudioToggle", "master audio toggle"],
				["AudioSection/SfxRow/SfxToggle", "SFX toggle"],
				["AudioSection/HapticsRow/HapticsToggle", "haptics toggle"]
			]:
				_expect_readable_toggle(root_vbox, str(toggle_data[0]), str(toggle_data[1]))
		var graphics_tab := category_tabs.get_node_or_null("GraphicsTab") as Button if category_tabs != null else null
		if graphics_tab != null:
			graphics_tab.pressed.emit()
			await process_frame
			_expect_readable_toggle(root_vbox, "VideoSection/GpuVfxRow/GpuVfxToggle", "GPU VFX toggle")
			_expect_readable_option(root_vbox, "PerformanceSection/PerformanceModeRow/PerformanceModeOption", "performance option")
			_expect_readable_toggle(root_vbox, "PerformanceSection/FloorGraphicsRow/FloorGraphicsToggle", "floor graphics toggle")
		if support_tab != null:
			support_tab.pressed.emit()
			await process_frame
		_expect_readable_button(root_vbox, "CommunitySafetySection/CommunitySafetyRow/CommunitySafetyButton", "community safety button")
		var safety_button := root_vbox.get_node_or_null("CommunitySafetySection/CommunitySafetyRow/CommunitySafetyButton") as Button
		if safety_button != null:
			safety_button.pressed.emit()
			await process_frame
			var dialog := panel.get_node_or_null("CommunitySafetyDialog") as AcceptDialog
			_expect(dialog != null and dialog.visible, "community safety button should open safety dialog")
			if dialog != null:
				dialog.hide()
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	menu.call("_unhandled_input", cancel_event)
	await process_frame
	_expect(settings_workspace != null and not settings_workspace.visible, "system Back should close Settings")
	if settings_tab != null:
		settings_tab.pressed.emit()
		await process_frame
		var reopened_account_tab := category_tabs.get_node_or_null("AccountTab") as Button if category_tabs != null else null
		_expect(reopened_account_tab != null and reopened_account_tab.button_pressed, "Settings should reopen on Account")
	var settings_source: String = FileAccess.get_file_as_string("res://scripts/ui/profile_settings_panel.gd")
	_expect(not settings_source.contains("display_name_input.focus_exited.connect"), "Call Sign changes must not commit on focus loss")
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
	_expect(control.custom_minimum_size.y >= MIN_TOGGLE_CONTROL_HEIGHT, "%s should meet the 88-unit toggle height: %.1f" % [label, control.custom_minimum_size.y])
	_expect(control.custom_minimum_size.x >= MIN_TOGGLE_CONTROL_WIDTH, "%s should reserve the toggle width: %.1f" % [label, control.custom_minimum_size.x])
	var checked_icon: Texture2D = control.get_theme_icon("checked")
	var unchecked_icon: Texture2D = control.get_theme_icon("unchecked")
	var checked_disabled_icon: Texture2D = control.get_theme_icon("checked_disabled")
	var unchecked_disabled_icon: Texture2D = control.get_theme_icon("unchecked_disabled")
	_expect(checked_icon != null and checked_icon.get_width() >= MIN_TOGGLE_TRACK_WIDTH and checked_icon.get_height() >= MIN_TOGGLE_TRACK_HEIGHT, "%s checked track should be at least 112x56" % label)
	_expect(unchecked_icon != null and unchecked_icon.get_width() >= MIN_TOGGLE_TRACK_WIDTH and unchecked_icon.get_height() >= MIN_TOGGLE_TRACK_HEIGHT, "%s unchecked track should be at least 112x56" % label)
	_expect(checked_disabled_icon != null and checked_disabled_icon.get_width() >= MIN_TOGGLE_TRACK_WIDTH and checked_disabled_icon.get_height() >= MIN_TOGGLE_TRACK_HEIGHT, "%s checked-disabled track should preserve visible size" % label)
	_expect(unchecked_disabled_icon != null and unchecked_disabled_icon.get_width() >= MIN_TOGGLE_TRACK_WIDTH and unchecked_disabled_icon.get_height() >= MIN_TOGGLE_TRACK_HEIGHT, "%s unchecked-disabled track should preserve visible size" % label)
	_expect(checked_icon != unchecked_icon, "%s should communicate state with distinct thumb positions" % label)

func _expect_readable_option(root_vbox: VBoxContainer, path: String, label: String) -> void:
	var control := root_vbox.get_node_or_null(path) as OptionButton
	_expect(control != null, "%s should exist" % label)
	if control == null:
		return
	_expect_readable_control(control, label)

func _expect_readable_control(control: Control, label: String) -> void:
	var min_height := control.custom_minimum_size.y
	var font_size := control.get_theme_font_size("font_size")
	_expect(min_height >= MIN_CONTROL_HEIGHT, "%s should meet 64-unit touch floor: %.1f" % [label, min_height])
	_expect(font_size >= BODY_FONT_SIZE, "%s should use 32+ unit readable type: %d" % [label, font_size])

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PROFILE_SETTINGS_MOBILE_LAYOUT_SMOKE: %s" % message)
