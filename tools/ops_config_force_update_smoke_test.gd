extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null:
		return _fail("OpsConfig autoload missing")
	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "force-update-smoke",
		"min_supported_build": 999999,
		"force_update": true
	})
	if not bool(ops_config.call("is_force_update_required", 1)):
		return _fail("force update should activate for old build")
	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "force-update-invalid-smoke",
		"min_supported_build": 999999,
		"force_update": false
	})
	if bool(ops_config.call("is_force_update_required", 1)):
		return _fail("force update should require valid true flag")
	print("OPS_CONFIG_FORCE_UPDATE_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("OPS_CONFIG_FORCE_UPDATE_SMOKE: %s" % message)
	quit(1)
