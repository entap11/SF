extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/ui/SupportDiagnosticsPanel.tscn") as PackedScene
	if scene == null:
		return _fail("support diagnostics scene missing")
	var panel: Control = scene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	var payload: Dictionary = panel.call("build_diagnostics_payload") as Dictionary
	if not payload.has("entap_id") or not payload.has("call_sign"):
		return _fail("payload missing public account fields")
	var ops_config: Dictionary = payload.get("ops_config", {}) as Dictionary
	if str(ops_config.get("config_source", "")).is_empty():
		return _fail("payload missing config provenance")
	var analytics_health: Dictionary = payload.get("analytics_health", {}) as Dictionary
	if str(analytics_health.get("status", "")).is_empty():
		return _fail("payload missing analytics health")
	var text: String = JSON.stringify(payload)
	if text.contains("\"user_id\"") or text.contains("\"player_id\""):
		return _fail("payload should not expose raw user/player id by default")
	print("SUPPORT_DIAGNOSTICS_PAYLOAD_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("SUPPORT_DIAGNOSTICS_PAYLOAD_SMOKE: %s" % message)
	quit(1)
