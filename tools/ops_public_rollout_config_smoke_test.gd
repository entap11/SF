extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null:
		return _fail("OpsConfig autoload missing")
	var defaults: Dictionary = _load_json("res://data/ops/ops_config_defaults.json")
	var default_flags: Dictionary = defaults.get("feature_flags", {}) as Dictionary
	for flag_name in [
		"enable_public_1v1", "enable_public_crucible", "enable_public_3p_ffa", "enable_public_2v2",
		"enable_public_4p_ffa", "enable_public_ctf", "enable_public_hctf", "enable_public_time_puzzles",
		"enable_public_gauntlet", "enable_public_async_3map", "enable_public_async_5map",
		"enable_rank_mutations", "enable_crucible_wax_settlement", "enable_contest_rewards",
		"enable_bot_fallback", "enable_public_leaderboards"
	]:
		if bool(default_flags.get(flag_name, true)):
			return _fail("bundled rollout flag was not false: %s" % flag_name)

	var open_config: Dictionary = {
		"schema_version": 1,
		"config_version": "rollout-smoke-open",
		"min_supported_build": 0,
		"expires_utc": "2099-01-01T00:00:00Z",
		"feature_flags": {
			"enable_public_1v1": true,
			"enable_public_crucible": true,
			"enable_crucible_wax_settlement": true,
			"enable_public_time_puzzles": true,
			"enable_public_leaderboards": true
		}
	}
	ops_config.call("force_config_for_smoke", open_config, "remote_fresh")
	if not bool(ops_config.call("public_mode_enabled", "1V1")):
		return _fail("fresh eligible 1V1 flag was not effective")
	if not bool(ops_config.call("public_mode_enabled", "CRUCIBLE")):
		return _fail("Crucible did not require and accept both rollout gates")
	if not bool(ops_config.call("public_flag_enabled", "enable_public_time_puzzles")):
		return _fail("contest family flag was not effective")
	if bool(ops_config.call("public_flag_enabled", "enable_public_3p_ffa")):
		return _fail("omitted rollout flag did not remain false")

	var old_client_config: Dictionary = open_config.duplicate(true)
	old_client_config["config_version"] = "rollout-smoke-min-client"
	old_client_config["min_supported_build"] = 999999999
	ops_config.call("force_config_for_smoke", old_client_config, "remote_fresh")
	if bool(ops_config.call("public_mode_enabled", "1V1")):
		return _fail("minimum client build did not fail closed")
	if str(ops_config.call("public_rollout_blocker")) != "minimum_client_build_required":
		return _fail("minimum build blocker was not support-visible")

	var expired: Dictionary = open_config.duplicate(true)
	expired["config_version"] = "rollout-smoke-expired-cache"
	expired["expires_utc"] = "2020-01-01T00:00:00Z"
	ops_config.call("force_config_for_smoke", expired, "remote_cached")
	if bool(ops_config.call("public_mode_enabled", "1V1")):
		return _fail("expired cached config re-enabled a public mode")
	var debug: Dictionary = ops_config.call("get_debug_snapshot") as Dictionary
	if str(debug.get("public_rollout_blocker", "")) != "config_expired" \
			or typeof(debug.get("effective_public_flags", {})) != TYPE_DICTIONARY:
		return _fail("support snapshot omitted effective config/blocker: %s" % str(debug))
	print("OPS_PUBLIC_ROLLOUT_CONFIG_SMOKE: PASS")
	quit(0)

func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}

func _fail(message: String) -> void:
	push_error("OPS_PUBLIC_ROLLOUT_CONFIG_SMOKE: %s" % message)
	quit(1)
