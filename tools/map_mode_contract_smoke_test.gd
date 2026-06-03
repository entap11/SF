extends SceneTree

const HANDSHAKE_SCRIPT := preload("res://scripts/state/vs_handshake_state.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")
const MapModeRules := preload("res://scripts/maps/map_mode_rules.gd")
const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"

const SHARED_NON_3P_MAP_PATH: String = "res://maps/_future/nomansland/MAP_nomansland__545__v01_top2_sides__1p.json"
const THREE_PLAYER_MAP_PATH: String = "res://maps/delta/MAP_delta__SBASE__3p.json"
const TRITIP_THREE_PLAYER_MAP_PATH: String = "res://maps/_future/tritip/MAP_tritip__SBASE__3p.json"
const RACE_ONE_V_ONE_MAP_PATH: String = "res://maps/_future/race/MAP_race__SBASE__1p.json"
const ONE_V_ONE_ONLY_MAP_PATH: String = "res://maps/_future/corkscrew/MAP_corkscrew__SBASE__1p.json"
const KNIFE_FIGHT_ONE_V_ONE_MAP_PATH: String = "res://maps/_future/knifefight/MAP_knifefight__SBASE__1p.json"
const KNIFE_FIGHT_TWO_ONE_V_ONE_MAP_PATH: String = "res://maps/_future/knifefight/MAP_knifefight__KF2__1p.json"
const KNIFE_FIGHT_TWO_CLOSE_MAP_PATH: String = "res://maps/_future/knifefight/MAP_knifefight__KF2_CLOSE__4p.json"
const KNIFE_FIGHT_THREE_ONE_V_ONE_MAP_PATH: String = "res://maps/_future/knifefight/MAP_knifefight__KF3__1p.json"
const KNIFE_FIGHT_THREE_CLOSE_MAP_PATH: String = "res://maps/_future/knifefight/MAP_knifefight__KF3_CLOSE__4p.json"
const KNIFE_FIGHT_FOUR_ONE_V_ONE_MAP_PATH: String = "res://maps/_future/knifefight/MAP_knifefight__KF4_WALLS__1p.json"
const FOUR_PLAYER_ONLY_MAP_PATH: String = "res://maps/_future/laneclimb/MAP_laneclimb__SBASE__4p.json"
const QUAD_FIGHT_SHARED_MAP_PATH: String = "res://maps/_future/quadfight/MAP_quadfight__SBASE__4p.json"
const CLOSE_QUARTERS_SHARED_MAP_PATH: String = "res://maps/_future/closequarters/MAP_closequarters__SBASE__4p.json"
const CLOSE_QUARTERS_TWO_SHARED_MAP_PATH: String = "res://maps/_future/closequarters/MAP_closequarters__CQ2__4p.json"
const CLOSE_QUARTERS_THREE_SHARED_MAP_PATH: String = "res://maps/_future/closequarters/MAP_closequarters__CQ3__4p.json"
const CORRIDORS_SHARED_MAP_PATH: String = "res://maps/_future/corridors/MAP_corridors__SBASE__4p.json"
const CENTERSTRIKE_SHARED_MAP_PATH: String = "res://maps/_future/centerstrike/MAP_centerstrike__SBASE__4p.json"
const CENTERSTRIKE_TWO_SHARED_MAP_PATH: String = "res://maps/_future/centerstrike/MAP_centerstrike__CS2__4p.json"
const CENTERSTRIKE_THREE_SHARED_MAP_PATH: String = "res://maps/_future/centerstrike/MAP_centerstrike__CS3__4p.json"
const RINK_RAT_SHARED_MAP_PATH: String = "res://maps/_future/rink_rat/MAP_rink_rat__SBASE__4p.json"
const RINK_RAT_LEFT_RIGHT_SHARED_MAP_PATH: String = "res://maps/_future/rink_rat/MAP_rink_rat__LR__4p.json"
const IRON_CROSS_SHARED_MAP_PATH: String = "res://maps/_future/iron_cross/MAP_iron_cross__SBASE__4p.json"
const SWIRLY_SHARED_MAP_PATH: String = "res://maps/_future/swirly/MAP_swirly__SBASE__4p.json"

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

	var one_v_one_loaded: Dictionary = MAP_LOADER.load_map(ONE_V_ONE_ONLY_MAP_PATH)
	if not bool(one_v_one_loaded.get("ok", false)):
		return _fail("1v1-only map failed to load: %s" % str(one_v_one_loaded))
	var one_v_one_data: Dictionary = one_v_one_loaded.get("data", {}) as Dictionary
	var one_v_one_summary: Dictionary = MapModeRules.map_supports_game_mode(one_v_one_data, "1V1")
	if not bool(one_v_one_summary.get("ok", false)):
		return _fail("1v1-only map rejected for 1V1: %s" % str(one_v_one_summary))
	for mode_id in ["2V2", "4P FFA", "3P FFA"]:
		var restricted_summary: Dictionary = MapModeRules.map_supports_game_mode(one_v_one_data, mode_id)
		if bool(restricted_summary.get("ok", false)):
			return _fail("1v1-only map must not support %s" % mode_id)

	var race_loaded: Dictionary = MAP_LOADER.load_map(RACE_ONE_V_ONE_MAP_PATH)
	if not bool(race_loaded.get("ok", false)):
		return _fail("Race failed to load: %s" % str(race_loaded))
	var race_data: Dictionary = race_loaded.get("data", {}) as Dictionary
	var race_summary: Dictionary = MapModeRules.map_supports_game_mode(race_data, "1V1")
	if not bool(race_summary.get("ok", false)):
		return _fail("Race rejected for 1V1: %s" % str(race_summary))
	for mode_id in ["2V2", "4P FFA", "3P FFA"]:
		var race_restricted_summary: Dictionary = MapModeRules.map_supports_game_mode(race_data, mode_id)
		if bool(race_restricted_summary.get("ok", false)):
			return _fail("Race must not support %s" % mode_id)

	var knife_fight_loaded: Dictionary = MAP_LOADER.load_map(KNIFE_FIGHT_ONE_V_ONE_MAP_PATH)
	if not bool(knife_fight_loaded.get("ok", false)):
		return _fail("Knife Fight 1 failed to load: %s" % str(knife_fight_loaded))
	var knife_fight_data: Dictionary = knife_fight_loaded.get("data", {}) as Dictionary
	var knife_fight_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_data, "1V1")
	if not bool(knife_fight_summary.get("ok", false)):
		return _fail("Knife Fight 1 rejected for 1V1: %s" % str(knife_fight_summary))
	for mode_id in ["2V2", "4P FFA", "3P FFA"]:
		var knife_restricted_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_data, mode_id)
		if bool(knife_restricted_summary.get("ok", false)):
			return _fail("Knife Fight 1 must not support %s" % mode_id)

	var knife_fight_two_loaded: Dictionary = MAP_LOADER.load_map(KNIFE_FIGHT_TWO_ONE_V_ONE_MAP_PATH)
	if not bool(knife_fight_two_loaded.get("ok", false)):
		return _fail("Knife Fight 2 failed to load: %s" % str(knife_fight_two_loaded))
	var knife_fight_two_data: Dictionary = knife_fight_two_loaded.get("data", {}) as Dictionary
	var knife_fight_two_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_two_data, "1V1")
	if not bool(knife_fight_two_summary.get("ok", false)):
		return _fail("Knife Fight 2 rejected for 1V1: %s" % str(knife_fight_two_summary))
	for mode_id in ["2V2", "4P FFA", "3P FFA"]:
		var knife_two_restricted_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_two_data, mode_id)
		if bool(knife_two_restricted_summary.get("ok", false)):
			return _fail("Knife Fight 2 must not support %s" % mode_id)

	var knife_fight_two_close_loaded: Dictionary = MAP_LOADER.load_map(KNIFE_FIGHT_TWO_CLOSE_MAP_PATH)
	if not bool(knife_fight_two_close_loaded.get("ok", false)):
		return _fail("Knife Fight 2 Close failed to load: %s" % str(knife_fight_two_close_loaded))
	var knife_fight_two_close_data: Dictionary = knife_fight_two_close_loaded.get("data", {}) as Dictionary
	for mode_id in ["2V2", "4P FFA"]:
		var knife_close_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_two_close_data, mode_id)
		if not bool(knife_close_summary.get("ok", false)):
			return _fail("Knife Fight 2 Close rejected for %s: %s" % [mode_id, str(knife_close_summary)])
	for mode_id in ["1V1", "3P FFA"]:
		var knife_close_restricted_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_two_close_data, mode_id)
		if bool(knife_close_restricted_summary.get("ok", false)):
			return _fail("Knife Fight 2 Close must not support %s" % mode_id)

	var knife_fight_three_loaded: Dictionary = MAP_LOADER.load_map(KNIFE_FIGHT_THREE_ONE_V_ONE_MAP_PATH)
	if not bool(knife_fight_three_loaded.get("ok", false)):
		return _fail("Knife Fight 3 failed to load: %s" % str(knife_fight_three_loaded))
	var knife_fight_three_data: Dictionary = knife_fight_three_loaded.get("data", {}) as Dictionary
	var knife_fight_three_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_three_data, "1V1")
	if not bool(knife_fight_three_summary.get("ok", false)):
		return _fail("Knife Fight 3 rejected for 1V1: %s" % str(knife_fight_three_summary))
	for mode_id in ["2V2", "4P FFA", "3P FFA"]:
		var knife_three_restricted_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_three_data, mode_id)
		if bool(knife_three_restricted_summary.get("ok", false)):
			return _fail("Knife Fight 3 must not support %s" % mode_id)

	var knife_fight_three_close_loaded: Dictionary = MAP_LOADER.load_map(KNIFE_FIGHT_THREE_CLOSE_MAP_PATH)
	if not bool(knife_fight_three_close_loaded.get("ok", false)):
		return _fail("Knife Fight 3 Close failed to load: %s" % str(knife_fight_three_close_loaded))
	var knife_fight_three_close_data: Dictionary = knife_fight_three_close_loaded.get("data", {}) as Dictionary
	for mode_id in ["2V2", "4P FFA"]:
		var knife_three_close_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_three_close_data, mode_id)
		if not bool(knife_three_close_summary.get("ok", false)):
			return _fail("Knife Fight 3 Close rejected for %s: %s" % [mode_id, str(knife_three_close_summary)])
	for mode_id in ["1V1", "3P FFA"]:
		var knife_three_close_restricted_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_three_close_data, mode_id)
		if bool(knife_three_close_restricted_summary.get("ok", false)):
			return _fail("Knife Fight 3 Close must not support %s" % mode_id)

	var knife_fight_four_loaded: Dictionary = MAP_LOADER.load_map(KNIFE_FIGHT_FOUR_ONE_V_ONE_MAP_PATH)
	if not bool(knife_fight_four_loaded.get("ok", false)):
		return _fail("Knife Fight 4 failed to load: %s" % str(knife_fight_four_loaded))
	var knife_fight_four_data: Dictionary = knife_fight_four_loaded.get("data", {}) as Dictionary
	var knife_fight_four_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_four_data, "1V1")
	if not bool(knife_fight_four_summary.get("ok", false)):
		return _fail("Knife Fight 4 rejected for 1V1: %s" % str(knife_fight_four_summary))
	for mode_id in ["2V2", "4P FFA", "3P FFA"]:
		var knife_four_restricted_summary: Dictionary = MapModeRules.map_supports_game_mode(knife_fight_four_data, mode_id)
		if bool(knife_four_restricted_summary.get("ok", false)):
			return _fail("Knife Fight 4 must not support %s" % mode_id)

	var four_player_loaded: Dictionary = MAP_LOADER.load_map(FOUR_PLAYER_ONLY_MAP_PATH)
	if not bool(four_player_loaded.get("ok", false)):
		return _fail("4P-only map failed to load: %s" % str(four_player_loaded))
	var four_player_data: Dictionary = four_player_loaded.get("data", {}) as Dictionary
	var four_player_summary: Dictionary = MapModeRules.map_supports_game_mode(four_player_data, "4P FFA")
	if not bool(four_player_summary.get("ok", false)):
		return _fail("4P-only map rejected for 4P FFA: %s" % str(four_player_summary))
	for mode_id in ["1V1", "2V2", "3P FFA"]:
		var four_restricted_summary: Dictionary = MapModeRules.map_supports_game_mode(four_player_data, mode_id)
		if bool(four_restricted_summary.get("ok", false)):
			return _fail("4P-only map must not support %s" % mode_id)

	var quad_fight_loaded: Dictionary = MAP_LOADER.load_map(QUAD_FIGHT_SHARED_MAP_PATH)
	if not bool(quad_fight_loaded.get("ok", false)):
		return _fail("Quad Fight failed to load: %s" % str(quad_fight_loaded))
	var quad_fight_data: Dictionary = quad_fight_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var quad_summary: Dictionary = MapModeRules.map_supports_game_mode(quad_fight_data, mode_id)
		if not bool(quad_summary.get("ok", false)):
			return _fail("Quad Fight rejected for %s: %s" % [mode_id, str(quad_summary)])
	var quad_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(quad_fight_data, "3P FFA")
	if bool(quad_3p_summary.get("ok", false)):
		return _fail("Quad Fight must not support 3P FFA")

	var close_quarters_loaded: Dictionary = MAP_LOADER.load_map(CLOSE_QUARTERS_SHARED_MAP_PATH)
	if not bool(close_quarters_loaded.get("ok", false)):
		return _fail("Close Quarters failed to load: %s" % str(close_quarters_loaded))
	var close_quarters_data: Dictionary = close_quarters_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var close_quarters_summary: Dictionary = MapModeRules.map_supports_game_mode(close_quarters_data, mode_id)
		if not bool(close_quarters_summary.get("ok", false)):
			return _fail("Close Quarters rejected for %s: %s" % [mode_id, str(close_quarters_summary)])
	var close_quarters_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(close_quarters_data, "3P FFA")
	if bool(close_quarters_3p_summary.get("ok", false)):
		return _fail("Close Quarters must not support 3P FFA")

	var close_quarters_two_loaded: Dictionary = MAP_LOADER.load_map(CLOSE_QUARTERS_TWO_SHARED_MAP_PATH)
	if not bool(close_quarters_two_loaded.get("ok", false)):
		return _fail("Close Quarters 2 failed to load: %s" % str(close_quarters_two_loaded))
	var close_quarters_two_data: Dictionary = close_quarters_two_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var close_quarters_two_summary: Dictionary = MapModeRules.map_supports_game_mode(close_quarters_two_data, mode_id)
		if not bool(close_quarters_two_summary.get("ok", false)):
			return _fail("Close Quarters 2 rejected for %s: %s" % [mode_id, str(close_quarters_two_summary)])
	var close_quarters_two_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(close_quarters_two_data, "3P FFA")
	if bool(close_quarters_two_3p_summary.get("ok", false)):
		return _fail("Close Quarters 2 must not support 3P FFA")

	var close_quarters_three_loaded: Dictionary = MAP_LOADER.load_map(CLOSE_QUARTERS_THREE_SHARED_MAP_PATH)
	if not bool(close_quarters_three_loaded.get("ok", false)):
		return _fail("Close Quarters 3 failed to load: %s" % str(close_quarters_three_loaded))
	var close_quarters_three_data: Dictionary = close_quarters_three_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var close_quarters_three_summary: Dictionary = MapModeRules.map_supports_game_mode(close_quarters_three_data, mode_id)
		if not bool(close_quarters_three_summary.get("ok", false)):
			return _fail("Close Quarters 3 rejected for %s: %s" % [mode_id, str(close_quarters_three_summary)])
	var close_quarters_three_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(close_quarters_three_data, "3P FFA")
	if bool(close_quarters_three_3p_summary.get("ok", false)):
		return _fail("Close Quarters 3 must not support 3P FFA")

	var corridors_loaded: Dictionary = MAP_LOADER.load_map(CORRIDORS_SHARED_MAP_PATH)
	if not bool(corridors_loaded.get("ok", false)):
		return _fail("Corridors failed to load: %s" % str(corridors_loaded))
	var corridors_data: Dictionary = corridors_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var corridors_summary: Dictionary = MapModeRules.map_supports_game_mode(corridors_data, mode_id)
		if not bool(corridors_summary.get("ok", false)):
			return _fail("Corridors rejected for %s: %s" % [mode_id, str(corridors_summary)])
	var corridors_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(corridors_data, "3P FFA")
	if bool(corridors_3p_summary.get("ok", false)):
		return _fail("Corridors must not support 3P FFA")

	var centerstrike_loaded: Dictionary = MAP_LOADER.load_map(CENTERSTRIKE_SHARED_MAP_PATH)
	if not bool(centerstrike_loaded.get("ok", false)):
		return _fail("Centerstrike failed to load: %s" % str(centerstrike_loaded))
	var centerstrike_data: Dictionary = centerstrike_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var centerstrike_summary: Dictionary = MapModeRules.map_supports_game_mode(centerstrike_data, mode_id)
		if not bool(centerstrike_summary.get("ok", false)):
			return _fail("Centerstrike rejected for %s: %s" % [mode_id, str(centerstrike_summary)])
	var centerstrike_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(centerstrike_data, "3P FFA")
	if bool(centerstrike_3p_summary.get("ok", false)):
		return _fail("Centerstrike must not support 3P FFA")

	var centerstrike_two_loaded: Dictionary = MAP_LOADER.load_map(CENTERSTRIKE_TWO_SHARED_MAP_PATH)
	if not bool(centerstrike_two_loaded.get("ok", false)):
		return _fail("Centerstrike 2 failed to load: %s" % str(centerstrike_two_loaded))
	var centerstrike_two_data: Dictionary = centerstrike_two_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var centerstrike_two_summary: Dictionary = MapModeRules.map_supports_game_mode(centerstrike_two_data, mode_id)
		if not bool(centerstrike_two_summary.get("ok", false)):
			return _fail("Centerstrike 2 rejected for %s: %s" % [mode_id, str(centerstrike_two_summary)])
	var centerstrike_two_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(centerstrike_two_data, "3P FFA")
	if bool(centerstrike_two_3p_summary.get("ok", false)):
		return _fail("Centerstrike 2 must not support 3P FFA")

	var centerstrike_three_loaded: Dictionary = MAP_LOADER.load_map(CENTERSTRIKE_THREE_SHARED_MAP_PATH)
	if not bool(centerstrike_three_loaded.get("ok", false)):
		return _fail("Centerstrike 3 failed to load: %s" % str(centerstrike_three_loaded))
	var centerstrike_three_data: Dictionary = centerstrike_three_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var centerstrike_three_summary: Dictionary = MapModeRules.map_supports_game_mode(centerstrike_three_data, mode_id)
		if not bool(centerstrike_three_summary.get("ok", false)):
			return _fail("Centerstrike 3 rejected for %s: %s" % [mode_id, str(centerstrike_three_summary)])
	var centerstrike_three_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(centerstrike_three_data, "3P FFA")
	if bool(centerstrike_three_3p_summary.get("ok", false)):
		return _fail("Centerstrike 3 must not support 3P FFA")

	var rink_rat_loaded: Dictionary = MAP_LOADER.load_map(RINK_RAT_SHARED_MAP_PATH)
	if not bool(rink_rat_loaded.get("ok", false)):
		return _fail("Rink Rat failed to load: %s" % str(rink_rat_loaded))
	var rink_rat_data: Dictionary = rink_rat_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var rink_rat_summary: Dictionary = MapModeRules.map_supports_game_mode(rink_rat_data, mode_id)
		if not bool(rink_rat_summary.get("ok", false)):
			return _fail("Rink Rat rejected for %s: %s" % [mode_id, str(rink_rat_summary)])
	var rink_rat_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(rink_rat_data, "3P FFA")
	if bool(rink_rat_3p_summary.get("ok", false)):
		return _fail("Rink Rat must not support 3P FFA")

	var rink_rat_lr_loaded: Dictionary = MAP_LOADER.load_map(RINK_RAT_LEFT_RIGHT_SHARED_MAP_PATH)
	if not bool(rink_rat_lr_loaded.get("ok", false)):
		return _fail("Rink Rat LR failed to load: %s" % str(rink_rat_lr_loaded))
	var rink_rat_lr_data: Dictionary = rink_rat_lr_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var rink_rat_lr_summary: Dictionary = MapModeRules.map_supports_game_mode(rink_rat_lr_data, mode_id)
		if not bool(rink_rat_lr_summary.get("ok", false)):
			return _fail("Rink Rat LR rejected for %s: %s" % [mode_id, str(rink_rat_lr_summary)])
	var rink_rat_lr_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(rink_rat_lr_data, "3P FFA")
	if bool(rink_rat_lr_3p_summary.get("ok", false)):
		return _fail("Rink Rat LR must not support 3P FFA")

	var iron_cross_loaded: Dictionary = MAP_LOADER.load_map(IRON_CROSS_SHARED_MAP_PATH)
	if not bool(iron_cross_loaded.get("ok", false)):
		return _fail("Iron Cross failed to load: %s" % str(iron_cross_loaded))
	var iron_cross_data: Dictionary = iron_cross_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var iron_cross_summary: Dictionary = MapModeRules.map_supports_game_mode(iron_cross_data, mode_id)
		if not bool(iron_cross_summary.get("ok", false)):
			return _fail("Iron Cross rejected for %s: %s" % [mode_id, str(iron_cross_summary)])
	var iron_cross_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(iron_cross_data, "3P FFA")
	if bool(iron_cross_3p_summary.get("ok", false)):
		return _fail("Iron Cross must not support 3P FFA")

	var swirly_loaded: Dictionary = MAP_LOADER.load_map(SWIRLY_SHARED_MAP_PATH)
	if not bool(swirly_loaded.get("ok", false)):
		return _fail("Swirly failed to load: %s" % str(swirly_loaded))
	var swirly_data: Dictionary = swirly_loaded.get("data", {}) as Dictionary
	for mode_id in ["1V1", "2V2", "4P FFA"]:
		var swirly_summary: Dictionary = MapModeRules.map_supports_game_mode(swirly_data, mode_id)
		if not bool(swirly_summary.get("ok", false)):
			return _fail("Swirly rejected for %s: %s" % [mode_id, str(swirly_summary)])
	var swirly_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(swirly_data, "3P FFA")
	if bool(swirly_3p_summary.get("ok", false)):
		return _fail("Swirly must not support 3P FFA")

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

	var tritip_loaded: Dictionary = MAP_LOADER.load_map(TRITIP_THREE_PLAYER_MAP_PATH)
	if not bool(tritip_loaded.get("ok", false)):
		return _fail("Tri Tip 3P map failed to load: %s" % str(tritip_loaded))
	var tritip_data: Dictionary = tritip_loaded.get("data", {}) as Dictionary
	var tritip_3p_summary: Dictionary = MapModeRules.map_supports_game_mode(tritip_data, "3P FFA")
	if not bool(tritip_3p_summary.get("ok", false)):
		return _fail("Tri Tip 3P map rejected for 3P FFA: %s" % str(tritip_3p_summary))
	for mode_id in ["1V1", "2V2", "4P FFA", "CAPTURE_FLAG", "HIDDEN_CAPTURE_FLAG"]:
		var tritip_summary: Dictionary = MapModeRules.map_supports_game_mode(tritip_data, mode_id)
		if bool(tritip_summary.get("ok", false)):
			return _fail("Tri Tip 3P map must not support %s" % mode_id)
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
