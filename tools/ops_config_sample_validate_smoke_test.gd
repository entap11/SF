extends SceneTree

const SAMPLE_PATH := "res://data/ops/ops_config_remote_sample.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null:
		return _fail("OpsConfig autoload missing")
	var sample: Dictionary = _load_json(SAMPLE_PATH)
	if sample.is_empty():
		return _fail("sample config missing or invalid JSON")
	var validation: Dictionary = ops_config.call("validate_config_payload", sample) as Dictionary
	if not bool(validation.get("ok", false)):
		return _fail("sample config validation failed: %s" % str(validation))
	if str(validation.get("config_version", "")) != "sample-remote-2026-06-26-001":
		return _fail("sample config version mismatch")
	ProjectSettings.set_setting("swarmfront/ops_config/remote_url", SAMPLE_PATH)
	var debug: Dictionary = ops_config.call("reload") as Dictionary
	if str(debug.get("config_source", "")) != "remote_fresh":
		return _fail("sample config did not load as remote_fresh: %s" % str(debug))
	if str(debug.get("config_version", "")) != "sample-remote-2026-06-26-001":
		return _fail("loaded sample version mismatch")
	if bool(ops_config.call("paid_entries_enabled")):
		return _fail("sample config should keep paid entries fail-closed")
	if not bool(ops_config.call("house_ads_enabled")):
		return _fail("sample config should allow house ads")
	print("OPS_CONFIG_SAMPLE_VALIDATE_SMOKE: PASS")
	quit(0)

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}

func _fail(message: String) -> void:
	push_error("OPS_CONFIG_SAMPLE_VALIDATE_SMOKE: %s" % message)
	quit(1)
