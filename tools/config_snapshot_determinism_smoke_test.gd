extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null:
		return _fail("OpsConfig autoload missing")
	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "snapshot-a",
		"feature_flags": {"enable_paid_entries": false},
		"match_tuning": {"version": "a", "cooldowns": {"swarm": 5}}
	})
	var snapshot: Dictionary = ops_config.call("build_match_config_snapshot", {"mode": "STAGE_RACE"}) as Dictionary
	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "snapshot-b",
		"feature_flags": {"enable_paid_entries": true},
		"match_tuning": {"version": "b", "cooldowns": {"swarm": 99}}
	})
	if str(snapshot.get("config_version", "")) != "snapshot-a":
		return _fail("snapshot version mutated")
	var tuning: Dictionary = snapshot.get("match_tuning", {}) as Dictionary
	if str(tuning.get("version", "")) != "a":
		return _fail("snapshot tuning mutated")
	var flags: Dictionary = snapshot.get("feature_flags", {}) as Dictionary
	if bool(flags.get("enable_paid_entries", true)):
		return _fail("snapshot flag mutated")
	print("CONFIG_SNAPSHOT_DETERMINISM_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("CONFIG_SNAPSHOT_DETERMINISM_SMOKE: %s" % message)
	quit(1)
