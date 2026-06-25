extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/ui/onboarding/onboarding_panel.tscn") as PackedScene
	if scene == null:
		_fail("failed to load onboarding panel scene")
		return
	var panel: Control = scene.instantiate() as Control
	if panel == null:
		_fail("failed to instantiate onboarding panel")
		return
	root.add_child(panel)
	await process_frame
	var checks: Array[Dictionary] = [
		{"path": "VBox/TitleLabel", "min": 42},
		{"path": "VBox/DisplayNameLabel", "min": 36},
		{"path": "VBox/DisplayNameInput", "min": 42},
		{"path": "VBox/AgeLabel", "min": 36},
		{"path": "VBox/AgeSpin", "min": 42},
		{"path": "VBox/ContinueButton", "min": 36}
	]
	for check in checks:
		var path: String = str(check.get("path", ""))
		var control: Control = panel.get_node_or_null(path) as Control
		if control == null:
			_fail("missing control %s" % path)
			return
		var font_size: int = int(control.get_theme_font_size("font_size"))
		if font_size < int(check.get("min", 0)):
			_fail("%s font too small: %d" % [path, font_size])
			return
	var display_input: Control = panel.get_node_or_null("VBox/DisplayNameInput") as Control
	var continue_button: Control = panel.get_node_or_null("VBox/ContinueButton") as Control
	if display_input == null or display_input.custom_minimum_size.y < 76.0:
		_fail("display name input height too small")
		return
	if continue_button == null or continue_button.custom_minimum_size.y < 76.0:
		_fail("continue button height too small")
		return
	panel.queue_free()
	await process_frame
	print("ONBOARDING_PANEL_READABILITY_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("ONBOARDING_PANEL_READABILITY_SMOKE: %s" % message)
	quit(1)
