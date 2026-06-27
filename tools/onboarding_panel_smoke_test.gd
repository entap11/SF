extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/ui/onboarding/onboarding_panel.tscn") as PackedScene
	if scene == null:
		push_error("ONBOARDING_PANEL_SMOKE: scene missing")
		quit(1)
		return
	var panel: Control = scene.instantiate() as Control
	if panel == null:
		push_error("ONBOARDING_PANEL_SMOKE: instantiate failed")
		quit(1)
		return
	get_root().add_child(panel)
	await process_frame
	var input: LineEdit = panel.get_node_or_null("VBox/DisplayNameInput") as LineEdit
	if input == null:
		_fail("call sign input missing")
		return
	var title_label: Label = panel.get_node_or_null("VBox/TitleLabel") as Label
	var display_label: Label = panel.get_node_or_null("VBox/DisplayNameLabel") as Label
	if title_label == null or not title_label.text.contains("Call Sign"):
		_fail("title should use Call Sign copy")
		return
	if display_label == null or display_label.text != "Call Sign":
		_fail("display name label should read Call Sign")
		return
	if input.placeholder_text != "Call Sign":
		_fail("display name placeholder should read Call Sign")
		return
	if input.text.strip_edges().is_empty():
		_fail("call sign input should be prefilled")
		return
	var profile_manager: Node = get_root().get_node_or_null("ProfileManager")
	if profile_manager == null or not profile_manager.has_method("validate_handle_policy"):
		_fail("ProfileManager handle policy missing")
		return
	var policy: Dictionary = profile_manager.call("validate_handle_policy", input.text) as Dictionary
	if not bool(policy.get("ok", false)):
		_fail("prefilled handle violates policy: %s" % str(policy))
		return
	if panel.get_node_or_null("VBox/UidRow") != null:
		_fail("user id row should not be visible on first-run onboarding")
		return
	var age_input: LineEdit = panel.get_node_or_null("VBox/AgeSpin") as LineEdit
	if age_input == null:
		_fail("age input should be visible on first-run onboarding")
		return
	if not age_input.text.strip_edges().is_empty():
		_fail("age input should start blank")
		return
	if not age_input.virtual_keyboard_enabled or age_input.virtual_keyboard_type != LineEdit.KEYBOARD_TYPE_NUMBER:
		_fail("age input should request the numeric virtual keyboard")
		return
	print("ONBOARDING_PANEL_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("ONBOARDING_PANEL_SMOKE: %s" % message)
	quit(1)
