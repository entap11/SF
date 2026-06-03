extends SceneTree

const HANDSHAKE_SCRIPT := preload("res://scripts/state/vs_handshake_state.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MapModeRules := preload("res://scripts/maps/map_mode_rules.gd")
const MatchSetupRandomizer := preload("res://scripts/state/match_setup_randomizer.gd")
const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"

func _init() -> void:
	await process_frame
	OS.set_environment("SF_VS_BACKEND_URL", "")
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
	var failed: bool = false
	failed = await _test_handshake_selects_eligible_map() or failed
	failed = _test_randomizer_applies_power_overrides() or failed
	if failed:
		quit(1)
		return
	print("MATCH_SETUP_RANDOMIZER_SMOKE: PASS")
	quit(0)

func _test_handshake_selects_eligible_map() -> bool:
	var handshake: Node = HANDSHAKE_SCRIPT.new()
	root.add_child(handshake)
	await process_frame
	var result: Dictionary = handshake.call("create_invite", {
		"uid": "randomizer_smoke_host",
		"display_name": "Host"
	}, {
		"mode": "2V2",
		"map_count": 1,
		"price_usd": 0,
		"free_roll": true
	}) as Dictionary
	if not bool(result.get("ok", false)):
		return _fail("create_invite failed: %s" % str(result))
	var session: Dictionary = result.get("session", {}) as Dictionary
	var context: Dictionary = session.get("context", {}) as Dictionary
	var paths_v: Variant = context.get("stage_map_paths", [])
	if typeof(paths_v) != TYPE_ARRAY or (paths_v as Array).is_empty():
		return _fail("handshake did not select stage_map_paths")
	var path: String = str((paths_v as Array)[0])
	var loaded: Dictionary = MAP_LOADER.load_map(path)
	if not bool(loaded.get("ok", false)):
		return _fail("selected map did not load: %s" % path)
	var data: Dictionary = loaded.get("data", {}) as Dictionary
	var eligibility: Dictionary = MapModeRules.map_supports_game_mode(data, "2V2")
	if not bool(eligibility.get("ok", false)):
		return _fail("selected map is not eligible for 2V2: %s %s" % [path, str(eligibility)])
	var slots: Array = data.get("structure_slots", []) as Array
	if slots.is_empty():
		return _fail("selected map has no structure_slots: %s" % path)
	var randomizer_v: Variant = context.get(MatchSetupRandomizer.CONTEXT_KEY, {})
	if typeof(randomizer_v) != TYPE_DICTIONARY:
		return _fail("handshake did not attach match randomizer payload")
	handshake.queue_free()
	return false

func _test_randomizer_applies_power_overrides() -> bool:
	var map_data: Dictionary = {
		"hives": [
			{"id": 1, "owner_id": 1, "power": 10},
			{"id": 2, "owner_id": 2, "power": 10},
			{"id": 3, "owner_id": 0, "power": 5}
		],
		"towers": [{"id": 1, "power": 0}],
		"barracks": [{"id": 1, "power": 0}],
		"structure_slots": [
			{"id": "slot_a", "grid_pos": [5, 13], "allowed": ["tower", "barracks"]}
		]
	}
	var payload: Dictionary = {
		"version": 1,
		"hit": true,
		"categories": {
			MatchSetupRandomizer.CATEGORY_HIVE_START_POWER: 15,
			MatchSetupRandomizer.CATEGORY_BARRACKS_POWER: 20,
			MatchSetupRandomizer.CATEGORY_NPC_HIVE_POWER: 25
		},
		"structures": {"kind": "barracks", "slot_policy": "all_slots"}
	}
	var applied: Dictionary = MatchSetupRandomizer.apply_to_map_data(map_data, payload)
	var hives: Array = applied.get("hives", []) as Array
	if int((hives[0] as Dictionary).get("owner_id", 0)) != 1 or int((hives[1] as Dictionary).get("owner_id", 0)) != 2:
		return _fail("randomizer should not change player hive ownership")
	if int((hives[0] as Dictionary).get("power", 0)) != 15:
		return _fail("player hive power override failed")
	if int((hives[1] as Dictionary).get("power", 0)) != 15:
		return _fail("second player hive power override failed")
	if int((hives[2] as Dictionary).get("power", 0)) != 25:
		return _fail("NPC hive power override failed")
	var towers: Array = applied.get("towers", []) as Array
	var barracks: Array = applied.get("barracks", []) as Array
	if not towers.is_empty():
		return _fail("structure slot kind should have replaced towers with barracks")
	if barracks.size() != 1:
		return _fail("structure slot population failed")
	if int((barracks[0] as Dictionary).get("power", 0)) != 20:
		return _fail("barracks power override failed")
	return false

func _fail(message: String) -> bool:
	push_error("MATCH_SETUP_RANDOMIZER_SMOKE: %s" % message)
	return true
