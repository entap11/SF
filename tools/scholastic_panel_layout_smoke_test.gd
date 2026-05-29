extends SceneTree

const PANEL_SCENE_PATH: String = "res://scenes/ui/ScholasticPanel.tscn"

var _failed: bool = false

func _init() -> void:
	await process_frame
	await _run_viewport(Vector2i(390, 844), "phone")
	await _run_viewport(Vector2i(1024, 768), "tablet")
	await _run_viewport(Vector2i(1440, 900), "desktop")
	if _failed:
		quit(1)
		return
	print("SCHOLASTIC_PANEL_LAYOUT_SMOKE: PASS")
	quit(0)

func _run_viewport(viewport_size: Vector2i, label: String) -> void:
	var scene: PackedScene = load(PANEL_SCENE_PATH) as PackedScene
	_expect(scene != null, "%s scene loads" % label)
	if _failed:
		return
	var host := Control.new()
	host.name = "%sHost" % label.capitalize()
	host.position = Vector2.ZERO
	host.size = Vector2(viewport_size)
	host.custom_minimum_size = Vector2(viewport_size)
	root.add_child(host)
	var panel: Control = scene.instantiate() as Control
	_expect(panel != null, "%s scene instantiates as Control" % label)
	if _failed:
		return
	host.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	await process_frame
	await process_frame
	_expect(panel.size.x >= float(viewport_size.x) - 2.0, "%s panel width fills viewport" % label, panel.size)
	_expect(panel.size.y >= float(viewport_size.y) - 2.0, "%s panel height fills viewport" % label, panel.size)
	_check_required_controls(panel, label)
	_check_rows_readable(panel, label)
	_check_buttons_readable(panel, label)
	await _check_age_mode_buttons(panel, label, 16, ["AgeButton", "SFAButton", "RecruitingButton", "CloseButton"])
	await _check_age_mode_buttons(panel, label, 19, ["AgeButton", "SFUButton", "RecruitingButton", "CloseButton"])
	host.queue_free()
	await process_frame

func _check_required_controls(panel: Control, label: String) -> void:
	for path in [
		"Root/VBox/Title",
		"Root/VBox/Status",
		"Root/VBox/FormGrid/AgeSpin",
		"Root/VBox/FormGrid/SchoolNameInput",
		"Root/VBox/FormGrid/SchoolCityInput",
		"Root/VBox/FormGrid/SchoolStateInput",
		"Root/VBox/FormGrid/ProgramNameInput",
		"Root/VBox/FormGrid/ProgramCityInput",
		"Root/VBox/FormGrid/ProgramStateInput",
		"Root/VBox/ButtonRow/AgeButton",
		"Root/VBox/ButtonRow/SFAButton",
		"Root/VBox/ButtonRow/SFUButton",
		"Root/VBox/ButtonRow/CloseButton",
		"Root/VBox/SummaryScroll"
	]:
		_expect(panel.get_node_or_null(path) != null, "%s required control exists: %s" % [label, path])

func _check_rows_readable(panel: Control, label: String) -> void:
	var row_controls: Array[Control] = []
	for path in [
		"Root/VBox/FormGrid/AgeSpin",
		"Root/VBox/FormGrid/SchoolNameInput",
		"Root/VBox/FormGrid/SchoolCityInput",
		"Root/VBox/FormGrid/SchoolStateInput",
		"Root/VBox/FormGrid/SchoolYearInput",
		"Root/VBox/FormGrid/FreshmanYearInput",
		"Root/VBox/FormGrid/ProgramNameInput",
		"Root/VBox/FormGrid/ProgramCityInput",
		"Root/VBox/FormGrid/ProgramStateInput"
	]:
		var control: Control = panel.get_node_or_null(path) as Control
		if control != null and control.visible:
			row_controls.append(control)
	for control in row_controls:
		var rect: Rect2 = control.get_global_rect()
		_expect(rect.size.x >= 210.0, "%s input width is readable: %s" % [label, control.name], rect)
		_expect(rect.size.y >= 30.0, "%s input height is tappable: %s" % [label, control.name], rect)

func _check_buttons_readable(panel: Control, label: String) -> void:
	var previous_rect: Rect2 = Rect2()
	var has_previous: bool = false
	for path in [
		"Root/VBox/ButtonRow/AgeButton",
		"Root/VBox/ButtonRow/SFAButton",
		"Root/VBox/ButtonRow/SFUButton",
		"Root/VBox/ButtonRow/RecruitingButton",
		"Root/VBox/ButtonRow/CloseButton"
	]:
		var button: Button = panel.get_node_or_null(path) as Button
		if button == null or not button.visible:
			continue
		var rect: Rect2 = button.get_global_rect()
		_expect(rect.size.x >= 96.0, "%s button width is readable: %s" % [label, button.name], rect)
		_expect(rect.size.y >= 36.0, "%s button height is tappable: %s" % [label, button.name], rect)
		if has_previous:
			_expect(not previous_rect.grow(-1.0).intersects(rect.grow(-1.0)), "%s buttons do not overlap: %s" % [label, button.name], {"previous": previous_rect, "current": rect})
		previous_rect = rect
		has_previous = true

func _check_age_mode_buttons(panel: Control, label: String, age_years: int, visible_button_names: Array[String]) -> void:
	if panel.has_method("_sync_button_visibility"):
		panel.call("_sync_button_visibility", age_years)
	await process_frame
	for button_name in ["AgeButton", "SFAButton", "SFUButton", "RecruitingButton", "CloseButton"]:
		var button: Button = panel.get_node_or_null("Root/VBox/ButtonRow/%s" % button_name) as Button
		if button == null:
			continue
		_expect(button.visible == visible_button_names.has(button_name), "%s age %d button visibility: %s" % [label, age_years, button_name], {"visible": button.visible})
	_check_buttons_readable(panel, "%s age %d" % [label, age_years])

func _expect(condition: bool, message: String, details: Variant = null) -> void:
	if condition:
		return
	_failed = true
	if details == null:
		push_error("SCHOLASTIC_PANEL_LAYOUT_SMOKE: %s" % message)
	else:
		push_error("SCHOLASTIC_PANEL_LAYOUT_SMOKE: %s :: %s" % [message, str(details)])
