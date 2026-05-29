extends SceneTree

const MatchSetupRandomizer := preload("res://scripts/state/match_setup_randomizer.gd")

const VS_LOBBY_SCENE_PATH: String = "res://scenes/ui/VsLobby.tscn"
const MAP_PATH: String = "res://maps/_future/nomansland/MAP_nomansland__545__v01_top2_sides__1p.json"

var _failed: bool = false

func _initialize() -> void:
	await _run()
	quit(1 if _failed else 0)

func _run() -> void:
	_clear_route_meta()
	var scene: PackedScene = load(VS_LOBBY_SCENE_PATH) as PackedScene
	_expect(scene != null, "VsLobby scene should load")
	if _failed:
		return
	var lobby: Control = scene.instantiate() as Control
	_expect(lobby != null, "VsLobby should instantiate")
	if _failed:
		return
	root.add_child(lobby)
	await process_frame
	var randomizer_payload: Dictionary = {
		"version": 1,
		"hit": true,
		"categories": {
			MatchSetupRandomizer.CATEGORY_HIVE_START_POWER: 15
		},
		"description": "Randomized: hive start 15."
	}
	lobby.call("configure", "1V1", 1, 0, true, {
		"human_pvp": true,
		"stage_map_paths": [MAP_PATH],
		MatchSetupRandomizer.CONTEXT_KEY: randomizer_payload
	})
	lobby.call("_start_local_standard_bot_match", {
		"uid": "standard_bot_route_smoke",
		"display_name": "Route Bot",
		"is_cpu": true,
		"style": "turtle",
		"tier": "medium"
	})
	var prepared: bool = bool(lobby.call("_prepare_bot_fill_jukebox_metadata", MAP_PATH))
	_expect(prepared, "bot fill should prepare jukebox metadata")
	_expect(str(get_meta("vs_mode", "")) == "ASYNC_SINGLE_MAP_TIMED", "bot fill should route as jukebox/single-map timed")
	_expect(bool(get_meta("vs_free_roll", false)), "bot fill should stay free roll")
	_expect(not bool(get_meta("vs_sync_start", true)), "bot fill should use Shell async-style startup")
	_expect(bool(get_meta("jukebox_board_enabled", false)), "bot fill should enable jukebox runtime")
	_expect(str(get_meta("jukebox_map_path", "")) == MAP_PATH, "bot fill should preserve selected map")
	_expect(str(get_meta("vs_cpu_style", "")) == "turtle", "bot fill should preserve CPU style")
	_expect(str(get_meta("vs_cpu_tier", "")) == "medium", "bot fill should preserve CPU tier")
	var remote_v: Variant = get_meta("vs_remote_profile", {})
	_expect(typeof(remote_v) == TYPE_DICTIONARY, "remote profile should be dictionary")
	if typeof(remote_v) == TYPE_DICTIONARY:
		var remote: Dictionary = remote_v as Dictionary
		_expect(bool(remote.get("is_cpu", false)), "remote profile should be CPU")
		_expect(str(remote.get("display_name", "")) == "Route Bot", "remote profile should preserve bot name")
	var randomizer_v: Variant = get_meta(MatchSetupRandomizer.TREE_META_KEY, {})
	_expect(typeof(randomizer_v) == TYPE_DICTIONARY, "bot fill should carry match randomizer metadata")
	if typeof(randomizer_v) == TYPE_DICTIONARY:
		_expect(bool((randomizer_v as Dictionary).get("hit", false)), "bot fill randomizer should preserve payload")
	if not _failed:
		print("VS_BOT_FILL_JUKEBOX_ROUTE_SMOKE: PASS")

func _clear_route_meta() -> void:
	for key in [
		"start_game",
		"vs_mode",
		"vs_price_usd",
		"vs_free_roll",
		"vs_assigned_players",
		"vs_open_slots",
		"vs_required_players",
		"vs_sync_start",
		"vs_stage_map_paths",
		"vs_stage_current_index",
		"vs_stage_round_results",
		"vs_handshake_session_id",
		"vs_handshake_role",
		"vs_handshake_invite_code",
		"vs_local_profile",
		"vs_remote_profile",
		"vs_cpu_style",
		"vs_cpu_tier",
		MatchSetupRandomizer.TREE_META_KEY,
		MatchSetupRandomizer.CONTEXT_KEY,
		"jukebox_board_enabled",
		"jukebox_map_path",
		"jukebox_map_id",
		"jukebox_board_period",
		"jukebox_local_owner_id"
	]:
		if has_meta(key):
			remove_meta(key)

func _expect(condition: bool, message: String, details: Variant = null) -> void:
	if condition:
		return
	_failed = true
	if details == null:
		push_error("VS_BOT_FILL_JUKEBOX_ROUTE_SMOKE: %s" % message)
	else:
		push_error("VS_BOT_FILL_JUKEBOX_ROUTE_SMOKE: %s :: %s" % [message, str(details)])
