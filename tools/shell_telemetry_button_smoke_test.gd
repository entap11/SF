extends SceneTree

func _initialize() -> void:
	var scene := load("res://scenes/Shell.tscn") as PackedScene
	if scene == null:
		_fail("failed to load Shell.tscn")
		return
	var shell: Node = scene.instantiate()
	root.add_child(shell)
	await process_frame
	await process_frame
	var button: Button = shell.get_node_or_null("MenuRoot/MenuPanel/VBox/ButtonsRow/TelemetryButton") as Button
	if button == null:
		_fail("telemetry button missing")
		return
	if button.text.strip_edges().to_upper() != "TELEMETRY":
		_fail("telemetry button label wrong: %s" % button.text)
		return
	if not shell.has_method("_open_telemetry_dashboard"):
		_fail("shell telemetry open method missing")
		return
	shell.call("_open_telemetry_dashboard")
	await process_frame
	var panel: Control = shell.get_node_or_null("MenuRoot/TelemetryDashboardPanel") as Control
	if panel == null:
		_fail("telemetry dashboard panel did not open")
		return
	if not panel.has_method("get_dashboard_snapshot"):
		_fail("telemetry dashboard panel missing snapshot method")
		return
	shell.queue_free()
	print("SHELL_TELEMETRY_BUTTON_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("SHELL_TELEMETRY_BUTTON_SMOKE: %s" % message)
	quit(1)
