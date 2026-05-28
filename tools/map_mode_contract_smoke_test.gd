extends SceneTree

const HANDSHAKE_SCRIPT := preload("res://scripts/state/vs_handshake_state.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")
const MapModeRules := preload("res://scripts/maps/map_mode_rules.gd")
const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"

const SHARED_NON_3P_MAP_PATH: String = "res://maps/_future/nomansland/MAP_nomansland__545__v01_top2_sides__1p.json"
const THREE_PLAYER_MAP_PATH: String = "res://maps/delta/MAP_delta__SBASE__3p.json"

func _init() -> void:
	await process_frame
	OS.set_environment("SF_VS_BACKEND_URL", "")
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
	var failed: bool = false
	failed = _test_map_mode_rules_are_strict() or failed
	failed = await _test_handshake_rejects_explicit_3p_map_for_non_3p_mode() or failed
	failed = await _test_handshake_rejects_explicit_non_3p_map_for_3p_mode() or failed
	if failed:
		quit(1)
		return
	print("MAP_MODE_CONTRACT_SMOKE: PASS")
	quit(0)

func _test_map_mode_rules_are_strict() -> bool:
	var shared_loaded: Dictionary = MAP_LOADER.load_map(SHARED_NON_3P_MAP_PATH)
	if not bool(shared_loaded.get("ok", false)):
		return _fail("shared non-3P map failed to load: %s" % str(shared_loaded))
	var shared_data: Dictionary = shared_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA", "CAPTURE_FLAG"]:
		var shared_summary: Dictionary = MapModeRules.map_supports_game_mode(shared_data, mode_id)
		if not bool(shared_summary.get("ok", false)):
			return _fail("shared non-3P map rejected for %s: %s" % [mode_id, str(shared_summary)])
	var shared_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(shared_data, "3P FFA")
	if bool(shared_3p_summary.get("ok", false)):
		return _fail("shared non-3P map must not support 3P FFA")

	var delta_loaded: Dictionary = MAP_LOADER.load_map(THREE_PLAYER_MAP_PATH)
	if not bool(delta_loaded.get("ok", false)):
		return _fail("Delta 3P map failed to load: %s" % str(delta_loaded))
	var delta_data: Dictionary = delta_loaded.get("data", {}) as Dictionary
	var delta_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(delta_data, "3P FFA")
	if not bool(delta_3p_summary.get("ok", false)):
		return _fail("Delta 3P map rejected for 3P FFA: %s" % str(delta_3p_summary))
	for mode_id in ["1V1", "2V2", "4P FFA", "CAPTURE_FLAG", "HIDDEN_CAPTURE_FLAG"]:
		var delta_summary: Dictionary = MapModeRules.map_supports_game_mode(delta_data, mode_id)
		if bool(delta_summary.get("ok", false)):
			return _fail("Delta 3P map must not support %s" % mode_id)
	return false

func _test_handshake_rejects_explicit_3p_map_for_non_3p_mode() -> bool:
	var context: Dictionary = await _prepared_handshake_context({
		"mode": "1V1",
		"map_count": 1,
		"price_usd": 0,
		"free_roll": true,
		"stage_map_paths": [THREE_PLAYER_MAP_PATH]
	})
	var selected: Array = context.get("stage_map_paths", []) as Array
	if selected.is_empty():
		return _fail("1V1 context did not select a replacement map")
	if selected.has(THREE_PLAYER_MAP_PATH):
		return _fail("1V1 context kept explicit Delta 3P map: %s" % str(selected))
	for path_any in selected:
		var validation: Dictionary = _validate_path_for_mode(str(path_any), "1V1")
		if not bool(validation.get("ok", false)):
			return _fail("1V1 replacement map is invalid: %s" % str(validation))
	return false

func _test_handshake_rejects_explicit_non_3p_map_for_3p_mode() -> bool:
	var context: Dictionary = await _prepared_handshake_context({
		"mode": "3P FFA",
		"map_count": 1,
		"price_usd": 0,
		"free_roll": true,
		"stage_map_paths": [SHARED_NON_3P_MAP_PATH]
	})
	var selected: Array = context.get("stage_map_paths", []) as Array
	if selected.is_empty():
		return _fail("3P context did not select a replacement map")
	if selected.has(SHARED_NON_3P_MAP_PATH):
		return _fail("3P context kept explicit non-3P map: %s" % str(selected))
	for path_any in selected:
		var validation: Dictionary = _validate_path_for_mode(str(path_any), "3P FFA")
		if not bool(validation.get("ok", false)):
			return _fail("3P replacement map is invalid: %s" % str(validation))
	return false

func _prepared_handshake_context(context: Dictionary) -> Dictionary:
	var handshake: Node = HANDSHAKE_SCRIPT.new()
	root.add_child(handshake)
	await process_frame
	var result: Dictionary = handshake.call("create_invite", {
		"uid": "map_mode_contract_host_%d" % Time.get_ticks_usec(),
		"display_name": "Host"
	}, context) as Dictionary
	handshake.queue_free()
	if not bool(result.get("ok", false)):
		return {}
	var session: Dictionary = result.get("session", {}) as Dictionary
	return session.get("context", {}) as Dictionary

func _validate_path_for_mode(path: String, mode_id: String) -> Dictionary:
	var loaded: Dictionary = MAP_LOADER.load_map(path)
	if not bool(loaded.get("ok", false)):
		return {
			"ok": false,
			"reason": str(loaded.get("err", "load_failed")),
			"path": path
		}
	var summary: Dictionary = MapModeRules.map_supports_game_mode(loaded.get("data", {}) as Dictionary, mode_id)
	summary["path"] = path
	summary["map_id"] = MAP_REGISTRY.map_id_from_path(path)
	return summary

func _fail(message: String) -> bool:
	push_error("MAP_MODE_CONTRACT_SMOKE: %s" % message)
	return true
