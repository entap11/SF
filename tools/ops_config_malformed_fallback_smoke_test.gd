extends SceneTree

const CONFIG_PATH := "user://ops_config_malformed.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ops_config_cache_v1.json"))
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	file.store_string("{not-json")
	file.close()
	ProjectSettings.set_setting("swarmfront/ops_config/remote_url", CONFIG_PATH)
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null:
		return _fail("OpsConfig autoload missing")
	var debug: Dictionary = ops_config.call("reload") as Dictionary
	if str(debug.get("config_source", "")) != "malformed_fallback":
		return _fail("expected malformed_fallback, got %s" % str(debug))
	if bool(ops_config.call("is_force_update_required", 0)):
		return _fail("force update must be false on malformed fallback")
	if bool(ops_config.call("is_maintenance_mode")):
		return _fail("maintenance must be false on malformed fallback")
	print("OPS_CONFIG_MALFORMED_FALLBACK_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("OPS_CONFIG_MALFORMED_FALLBACK_SMOKE: %s" % message)
	quit(1)
