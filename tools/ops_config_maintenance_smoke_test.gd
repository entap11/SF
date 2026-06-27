extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null:
		return _fail("OpsConfig autoload missing")
	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "maintenance-smoke",
		"maintenance": {
			"enabled": true,
			"title": "Maintenance",
			"body": "Smoke",
			"severity": "maintenance",
			"start_utc": "2020-01-01T00:00:00Z",
			"end_utc": "2099-01-01T00:00:00Z"
		}
	})
	if not bool(ops_config.call("is_maintenance_mode")):
		return _fail("maintenance should be active inside valid window")
	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "maintenance-off-smoke",
		"maintenance": {"enabled": false}
	})
	if bool(ops_config.call("is_maintenance_mode")):
		return _fail("maintenance should fail closed when disabled")
	print("OPS_CONFIG_MAINTENANCE_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("OPS_CONFIG_MAINTENANCE_SMOKE: %s" % message)
	quit(1)
