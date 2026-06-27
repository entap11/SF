extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ops_config_cache_v1.json"))
	ProjectSettings.set_setting("swarmfront/ops_config/remote_url", "user://missing_ops_config.json")
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null:
		return _fail("OpsConfig autoload missing")
	var debug: Dictionary = ops_config.call("reload") as Dictionary
	if str(debug.get("config_source", "")) != "fetch_failed_fallback":
		return _fail("expected fetch_failed_fallback, got %s" % str(debug))
	if bool(ops_config.call("paid_entries_enabled")):
		return _fail("paid entries must fail closed")
	if bool(ops_config.call("honey_rewards_enabled")):
		return _fail("honey rewards must fail closed")
	if bool(ops_config.call("observer_mode_enabled")):
		return _fail("observer mode must fail closed")
	if bool(ops_config.call("rank_backend_enabled")):
		return _fail("rank backend must fail closed")
	if bool(ops_config.call("external_ads_enabled")):
		return _fail("external ads must fail closed")
	if not bool(ops_config.call("house_ads_enabled")):
		return _fail("house ads should remain allowed")
	print("OPS_CONFIG_FETCH_FAIL_FALLBACK_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("OPS_CONFIG_FETCH_FAIL_FALLBACK_SMOKE: %s" % message)
	quit(1)
