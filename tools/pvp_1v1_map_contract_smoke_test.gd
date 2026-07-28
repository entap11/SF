extends SceneTree

const MAP_REGISTRY = preload("res://scripts/maps/map_registry.gd")
const MAP_LOADER = preload("res://scripts/maps/map_loader.gd")
const MAP_MODE_RULES = preload("res://scripts/maps/map_mode_rules.gd")
const VS_HANDSHAKE_STATE = preload("res://scripts/state/vs_handshake_state.gd")

const VS_LOBBY_SCENE: String = "res://scenes/ui/VsLobby.tscn"
const ONE_PLAYER_MAP: String = "res://maps/_future/quadfight/MAP_quadfight__SBASE__1p.json"
const TWO_PLAYER_MAP: String = "res://maps/_future/quadfight/MAP_quadfight__SBASE__2p.json"
const FOUR_PLAYER_MAP: String = "res://maps/_future/quadfight/MAP_quadfight__SBASE__4p.json"
const CLOSE_QUARTERS_ONE_PLAYER_MAP: String = "res://maps/_future/closequarters/MAP_closequarters__SBASE__1p.json"
const CLOSE_QUARTERS_TWO_PLAYER_MAP: String = "res://maps/_future/closequarters/MAP_closequarters__SBASE__2p.json"
const CLOSE_QUARTERS_FOUR_PLAYER_MAP: String = "res://maps/_future/closequarters/MAP_closequarters__SBASE__4p.json"

func _init() -> void:
	await process_frame
	var failures: Array[String] = []
	if not MAP_REGISTRY.is_one_player_map_path(ONE_PLAYER_MAP):
		failures.append("expected 1p helper to accept %s" % ONE_PLAYER_MAP)
	if MAP_REGISTRY.is_one_player_map_path(FOUR_PLAYER_MAP):
		failures.append("expected 1p helper to reject %s" % FOUR_PLAYER_MAP)
	if MAP_REGISTRY.player_variant_for_path(TWO_PLAYER_MAP) != "2p":
		failures.append("expected 2p helper to identify %s" % TWO_PLAYER_MAP)
	if MAP_REGISTRY.player_variant_sibling_path(CLOSE_QUARTERS_FOUR_PLAYER_MAP, "1p") != CLOSE_QUARTERS_ONE_PLAYER_MAP:
		failures.append("closequarters1 did not resolve its 1p sibling")
	if MAP_REGISTRY.player_variant_sibling_path(CLOSE_QUARTERS_FOUR_PLAYER_MAP, "2p") != CLOSE_QUARTERS_TWO_PLAYER_MAP:
		failures.append("closequarters1 did not resolve its 2p sibling")
	if MAP_REGISTRY.player_variant_sibling_path(CLOSE_QUARTERS_FOUR_PLAYER_MAP, "4p") != CLOSE_QUARTERS_FOUR_PLAYER_MAP:
		failures.append("closequarters1 did not retain its 4p source variant")
	for closequarters_path in [
		CLOSE_QUARTERS_ONE_PLAYER_MAP,
		CLOSE_QUARTERS_TWO_PLAYER_MAP,
		CLOSE_QUARTERS_FOUR_PLAYER_MAP
	]:
		if MAP_REGISTRY.public_map_display_name_for_path(closequarters_path) != "closequarters1":
			failures.append("closequarters1 public name did not survive variant resolution: %s" % closequarters_path)
	var closequarters_two_player_loaded: Dictionary = MAP_LOADER.load_map(CLOSE_QUARTERS_TWO_PLAYER_MAP)
	if not bool(closequarters_two_player_loaded.get("ok", false)):
		failures.append("closequarters1 2p sibling failed to load")
	else:
		var closequarters_two_v_two_summary: Dictionary = MAP_MODE_RULES.map_supports_game_mode(
			closequarters_two_player_loaded.get("data", {}) as Dictionary,
			"2V2"
		)
		if not bool(closequarters_two_v_two_summary.get("ok", false)):
			failures.append("closequarters1 2p sibling failed the 2V2 contract: %s" % str(closequarters_two_v_two_summary))
		var closequarters_owner_summary: Dictionary = MAP_MODE_RULES.map_matches_active_owner_contract(
			closequarters_two_player_loaded.get("data", {}) as Dictionary,
			"2V2"
		)
		if not bool(closequarters_owner_summary.get("ok", false)):
			failures.append("closequarters1 2p sibling failed the 2V2 owner contract: %s" % str(closequarters_owner_summary))

	var scene: PackedScene = load(VS_LOBBY_SCENE) as PackedScene
	if scene == null:
		failures.append("VsLobby scene failed to load")
		_finish(failures)
		return
	var lobby: Control = scene.instantiate() as Control
	if lobby == null:
		failures.append("VsLobby scene did not instantiate as Control")
		_finish(failures)
		return
	root.add_child(lobby)
	await process_frame

	var one_player_validation: Dictionary = lobby.call("_stage_map_path_supports_mode", ONE_PLAYER_MAP, "1V1") as Dictionary
	if not bool(one_player_validation.get("ok", false)):
		failures.append("1v1 should accept 1p map: %s" % str(one_player_validation))
	var four_player_validation: Dictionary = lobby.call("_stage_map_path_supports_mode", FOUR_PLAYER_MAP, "1V1") as Dictionary
	if bool(four_player_validation.get("ok", false)):
		failures.append("1v1 should reject 4p map: %s" % str(four_player_validation))
	elif str(four_player_validation.get("reason", "")) != "requires_1p_map_path":
		failures.append("1v1 4p rejection used wrong reason: %s" % str(four_player_validation))
	var two_v_two_validation: Dictionary = lobby.call("_stage_map_path_supports_mode", TWO_PLAYER_MAP, "2V2") as Dictionary
	if not bool(two_v_two_validation.get("ok", false)):
		failures.append("2v2 should accept 2p map: %s" % str(two_v_two_validation))
	var two_v_two_four_player_validation: Dictionary = lobby.call("_stage_map_path_supports_mode", FOUR_PLAYER_MAP, "2V2") as Dictionary
	if bool(two_v_two_four_player_validation.get("ok", false)):
		failures.append("2v2 should reject 4p map: %s" % str(two_v_two_four_player_validation))
	var four_player_ffa_validation: Dictionary = lobby.call("_stage_map_path_supports_mode", FOUR_PLAYER_MAP, "4P FFA") as Dictionary
	if not bool(four_player_ffa_validation.get("ok", false)):
		failures.append("4P FFA should accept 4p map: %s" % str(four_player_ffa_validation))

	_assert_candidates(lobby, "1V1", "1p", failures)
	_assert_candidates(lobby, "2V2", "2p", failures)
	_assert_candidates(lobby, "4P FFA", "4p", failures)
	_assert_handshake_candidates("1V1", "1p", failures)
	_assert_handshake_candidates("2V2", "2p", failures)

	lobby.queue_free()
	await process_frame
	_finish(failures)

func _assert_candidates(lobby: Control, mode_id: String, expected_variant: String, failures: Array[String]) -> void:
	var candidates: Array = lobby.call("_candidate_stage_map_paths_for_mode", mode_id) as Array
	if candidates.is_empty():
		failures.append("%s candidate list was empty" % mode_id)
	for candidate_any in candidates:
		var candidate: String = str(candidate_any)
		var variant: String = MAP_REGISTRY.player_variant_for_path(candidate)
		if variant != expected_variant:
			failures.append("%s candidate list included %s path: %s" % [mode_id, variant, candidate])
			break
		var loaded: Dictionary = MAP_LOADER.load_map(candidate)
		if not bool(loaded.get("ok", false)):
			failures.append("%s candidate failed load: %s" % [mode_id, candidate])
			break
		var owner_summary: Dictionary = MAP_MODE_RULES.map_matches_active_owner_contract(loaded.get("data", {}) as Dictionary, mode_id)
		if not bool(owner_summary.get("ok", false)):
			failures.append("%s candidate failed owner contract: %s -> %s" % [mode_id, candidate, str(owner_summary)])
			break

func _assert_handshake_candidates(mode_id: String, expected_variant: String, failures: Array[String]) -> void:
	var handshake: Node = VS_HANDSHAKE_STATE.new()
	var candidates: Array = handshake.call("_candidate_stage_map_paths_for_mode", mode_id) as Array
	handshake.queue_free()
	if candidates.is_empty():
		failures.append("%s handshake candidate list was empty" % mode_id)
	for candidate_any in candidates:
		var candidate: String = str(candidate_any)
		var variant: String = MAP_REGISTRY.player_variant_for_path(candidate)
		if variant != expected_variant:
			failures.append("%s handshake candidate list included %s path: %s" % [mode_id, variant, candidate])
			break
		var loaded: Dictionary = MAP_LOADER.load_map(candidate)
		if not bool(loaded.get("ok", false)):
			failures.append("%s handshake candidate failed load: %s" % [mode_id, candidate])
			break
		var owner_summary: Dictionary = MAP_MODE_RULES.map_matches_active_owner_contract(loaded.get("data", {}) as Dictionary, mode_id)
		if not bool(owner_summary.get("ok", false)):
			failures.append("%s handshake candidate failed owner contract: %s -> %s" % [mode_id, candidate, str(owner_summary)])
			break

func _finish(failures: Array[String]) -> void:
	if not failures.is_empty():
		for failure in failures:
			push_error("PVP_1V1_MAP_CONTRACT_SMOKE: %s" % failure)
		push_error("PVP_1V1_MAP_CONTRACT_SMOKE: %d failure(s)" % failures.size())
		quit(1)
		return
	print("PVP_1V1_MAP_CONTRACT_SMOKE: PASS")
	quit(0)
