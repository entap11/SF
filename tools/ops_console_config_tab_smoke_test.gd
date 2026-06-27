extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_meta("ops_console_config_tab_only", true)
	var scene: PackedScene = load("res://scenes/ops/ops_console.tscn") as PackedScene
	if scene == null:
		return _fail("ops console scene missing")
	var console: Control = scene.instantiate() as Control
	if console == null:
		return _fail("ops console instantiate failed")
	root.add_child(console)
	await process_frame
	var status: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/OpsConfig/OpsConfigVBox/OpsConfigStatus") as Label
	var payload: TextEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/OpsConfig/OpsConfigVBox/OpsConfigPayload") as TextEdit
	var reload_button: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/OpsConfig/OpsConfigVBox/OpsConfigButtons/OpsConfigReload") as Button
	var copy_button: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/OpsConfig/OpsConfigVBox/OpsConfigButtons/OpsConfigCopy") as Button
	if status == null or payload == null or reload_button == null or copy_button == null:
		return _fail("ops config tab controls missing")
	if not status.text.contains("source=") or not status.text.contains("version=") or not status.text.contains("valid=true"):
		return _fail("ops config status summary incomplete: %s" % status.text)
	if not payload.text.contains("\"fail_closed_policy\"") or not payload.text.contains("\"config_source\""):
		return _fail("ops config payload missing provenance or fail-closed policy")
	reload_button.pressed.emit()
	await process_frame
	if DisplayServer.get_name() != "headless":
		copy_button.pressed.emit()
		await process_frame
		if not DisplayServer.clipboard_get().contains("\"active_config\""):
			return _fail("copy snapshot did not write payload to clipboard")
	root.remove_meta("ops_console_config_tab_only")
	print("OPS_CONSOLE_CONFIG_TAB_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	root.remove_meta("ops_console_config_tab_only")
	push_error("OPS_CONSOLE_CONFIG_TAB_SMOKE: %s" % message)
	quit(1)
