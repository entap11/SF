extends SceneTree

const CONFIG_PATH := "user://ops_config_fetch_success.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_write_config(CONFIG_PATH, "remote-success", {"enable_paid_entries": true, "enable_rank_backend": true})
	ProjectSettings.set_setting("swarmfront/ops_config/remote_url", CONFIG_PATH)
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null:
		return _fail("OpsConfig autoload missing")
	var debug: Dictionary = ops_config.call("reload") as Dictionary
	if str(debug.get("config_source", "")) != "remote_fresh":
		return _fail("expected remote_fresh, got %s" % str(debug))
	if str(debug.get("config_version", "")) != "remote-success":
		return _fail("remote version not applied")
	if not bool(ops_config.call("paid_entries_enabled")):
		return _fail("remote flag not applied")
	print("OPS_CONFIG_FETCH_SUCCESS_SMOKE: PASS")
	quit(0)

func _write_config(path: String, version: String, flags: Dictionary) -> void:
	var config: Dictionary = {
		"schema_version": 1,
		"config_version": version,
		"feature_flags": flags
	}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(config, "\t"))
	file.close()

func _fail(message: String) -> void:
	push_error("OPS_CONFIG_FETCH_SUCCESS_SMOKE: %s" % message)
	quit(1)
