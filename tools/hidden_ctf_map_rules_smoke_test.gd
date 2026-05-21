extends SceneTree

const HANDSHAKE_SCRIPT := preload("res://scripts/state/vs_handshake_state.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MapModeRules := preload("res://scripts/maps/map_mode_rules.gd")
const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const HIDDEN_CTF_MAP_PATH: String = "res://maps/_future/nomansland/MAP_nomansland__545__v13_top3_each__1p.json"
const SHARED_NON_3P_MAP_PATH: String = HIDDEN_CTF_MAP_PATH
const THREE_PLAYER_MAP_PATH: String = "res://maps/delta/MAP_delta__SBASE__3p.json"

func _init() -> void:
	await process_frame
	OS.set_environment("SF_VS_BACKEND_URL", "")
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
	var failed: bool = false
	failed = _test_map_mode_eligibility() or failed
	failed = _test_hidden_ctf_split_removes_npc_hives() or failed
	failed = await _test_handshake_selects_hidden_ctf_split_map() or failed
	if failed:
		quit(1)
		return
	print("HIDDEN_CTF_MAP_RULES_SMOKE: PASS")
	quit(0)

func _test_map_mode_eligibility() -> bool:
	var shared_loaded: Dictionary = MAP_LOADER.load_map(SHARED_NON_3P_MAP_PATH)
	if not bool(shared_loaded.get("ok", false)):
		return _fail("shared non-3P map failed to load")
	var shared_data: Dictionary = shared_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA", "CAPTURE_FLAG"]:
		var shared_summary: Dictionary = MapModeRules.map_supports_game_mode(shared_data, mode_id)
		if not bool(shared_summary.get("ok", false)):
			return _fail("shared non-3P map rejected for %s: %s" % [mode_id, str(shared_summary)])
	var shared_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(shared_data, "3P FFA")
	if bool(shared_3p_summary.get("ok", false)):
		return _fail("shared non-3P map must not be accepted for 3P FFA")

	var delta_loaded: Dictionary = MAP_LOADER.load_map(THREE_PLAYER_MAP_PATH)
	if not bool(delta_loaded.get("ok", false)):
		return _fail("3P map failed to load")
	var delta_data: Dictionary = delta_loaded.get("data", {}) as Dictionary
	var delta_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(delta_data, "3P FFA")
	if not bool(delta_3p_summary.get("ok", false)):
		return _fail("3P map rejected for 3P FFA: %s" % str(delta_3p_summary))
	for mode_id in ["1V1", "2V2", "4P FFA", "CAPTURE_FLAG", "HIDDEN_CAPTURE_FLAG"]:
		var delta_summary: Dictionary = MapModeRules.map_supports_game_mode(delta_data, mode_id)
		if bool(delta_summary.get("ok", false)):
			return _fail("3P map must not be accepted for %s" % mode_id)
	return false

func _test_hidden_ctf_split_removes_npc_hives() -> bool:
	var loaded: Dictionary = MAP_LOADER.load_map(HIDDEN_CTF_MAP_PATH)
	if not bool(loaded.get("ok", false)):
		return _fail("hidden CTF test map failed to load")
	var data: Dictionary = loaded.get("data", {}) as Dictionary
	var summary: Dictionary = MapModeRules.hidden_capture_flag_split_summary(data)
	if not bool(summary.get("ok", false)):
		return _fail("hidden CTF split summary rejected map: %s" % str(summary))
	for pattern in MapModeRules.HIDDEN_CTF_ALLOTMENT_PATTERNS:
		var split: Dictionary = MapModeRules.apply_hidden_capture_flag_owner_split(data, {
			"pattern": pattern,
			"seed": 12345
		})
		var split_result: bool = _assert_even_no_npc_split(split, pattern)
		if split_result:
			return true
	var deterministic_a: Dictionary = MapModeRules.apply_hidden_capture_flag_owner_split(data, {
		"pattern": "shuffle",
		"seed": 77
	})
	var deterministic_b: Dictionary = MapModeRules.apply_hidden_capture_flag_owner_split(data, {
		"pattern": "shuffle",
		"seed": 77
	})
	if _owner_signature(deterministic_a) != _owner_signature(deterministic_b):
		return _fail("seeded shuffle should be deterministic")
	return false

func _assert_even_no_npc_split(split: Dictionary, label: String) -> bool:
	var hives: Array = split.get("hives", []) as Array
	var counts: Dictionary = {}
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var owner_id: int = int((hive_any as Dictionary).get("owner_id", 0))
		counts[owner_id] = int(counts.get(owner_id, 0)) + 1
		if owner_id != 1 and owner_id != 2:
			return _fail("hidden CTF %s split left neutral/NPC hive: %s" % [label, str(hive_any)])
	if int(counts.get(1, 0)) != int(counts.get(2, 0)):
		return _fail("hidden CTF %s split is not even: %s" % [label, str(counts)])
	return false

func _owner_signature(map_data: Dictionary) -> String:
	var hives: Array = map_data.get("hives", []) as Array
	var parts: Array[String] = []
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		parts.append("%s:%d" % [str(hive.get("id", "")), int(hive.get("owner_id", 0))])
	return "|".join(parts)

func _test_handshake_selects_hidden_ctf_split_map() -> bool:
	var handshake: Node = HANDSHAKE_SCRIPT.new()
	root.add_child(handshake)
	await process_frame
	var result: Dictionary = handshake.call("create_invite", {
		"uid": "hidden_ctf_smoke_host",
		"display_name": "Host"
	}, {
		"mode": "HIDDEN_CAPTURE_FLAG",
		"map_count": 1,
		"price_usd": 0,
		"free_roll": true
	}) as Dictionary
	if not bool(result.get("ok", false)):
		return _fail("create_invite failed: %s" % str(result))
	var session: Dictionary = result.get("session", {}) as Dictionary
	var context: Dictionary = session.get("context", {}) as Dictionary
	var paths: Array = context.get("stage_map_paths", []) as Array
	if paths.is_empty():
		return _fail("hidden CTF handshake did not select a stage map")
	var selected: String = str(paths[0])
	var loaded: Dictionary = MAP_LOADER.load_map(selected)
	if not bool(loaded.get("ok", false)):
		return _fail("hidden CTF selected map failed to load: %s" % selected)
	var summary: Dictionary = MapModeRules.hidden_capture_flag_split_summary(loaded.get("data", {}) as Dictionary)
	if not bool(summary.get("ok", false)):
		return _fail("hidden CTF selected invalid split map: %s %s" % [selected, str(summary)])
	handshake.queue_free()
	return false

func _fail(message: String) -> bool:
	push_error("HIDDEN_CTF_MAP_RULES_SMOKE: %s" % message)
	return true
