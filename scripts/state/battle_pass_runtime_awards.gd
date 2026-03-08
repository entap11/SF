extends Node

signal runtime_battle_pass_award(event: Dictionary)

const SFLog = preload("res://scripts/util/sf_log.gd")

@export var battle_pass_state_path: NodePath = NodePath("/root/BattlePassState")
@export var profile_manager_path: NodePath = NodePath("/root/ProfileManager")
@export var contest_state_path: NodePath = NodePath("/root/ContestState")

func _ready() -> void:
	SFLog.allow_tag("BATTLE_PASS_RUNTIME_AWARD")
	_connect_tree_signals()
	_scan_for_sim_runner()
	call_deferred("_sync_tree_contest_reward")

func sync_contest_nectar_rewards(contest_id: String, contest_scope: String = "", map_count: int = 5) -> Dictionary:
	var battle_pass_state: Node = _battle_pass_state()
	var contest_state: Node = _contest_state()
	var profile_manager: Node = _profile_manager()
	if battle_pass_state == null or contest_state == null or profile_manager == null:
		return {"ok": false, "reason": "missing_dependency"}
	if not battle_pass_state.has_method("intent_record_contest_result"):
		return {"ok": false, "reason": "battle_pass_state_missing_intent"}
	if not contest_state.has_method("build_stage_race_overall_leaderboard"):
		return {"ok": false, "reason": "contest_state_missing_leaderboard"}
	var clean_contest_id: String = contest_id.strip_edges()
	if clean_contest_id.is_empty():
		return {"ok": false, "reason": "missing_contest_id"}
	var scope: String = contest_scope.strip_edges().to_upper()
	if scope.is_empty() and contest_state.has_method("parse_contest_id"):
		var parsed_scope: Dictionary = contest_state.call("parse_contest_id", clean_contest_id) as Dictionary
		scope = str(parsed_scope.get("scope", "")).strip_edges().to_upper()
	if not contest_period_is_closed(clean_contest_id, scope):
		return {"ok": true, "awarded": false, "reason": "contest_period_open"}
	var player_id: String = str(profile_manager.call("get_user_id")).strip_edges()
	if player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var rows: Array = contest_state.call("build_stage_race_overall_leaderboard", clean_contest_id, maxi(1, map_count), 25) as Array
	var placement: int = 0
	for row_any in rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("player_id", "")).strip_edges() != player_id:
			continue
		placement = maxi(0, int(row.get("rank", 0)))
		break
	if placement <= 0 or placement > 3:
		return {"ok": true, "awarded": false, "placement": placement}
	var result: Dictionary = battle_pass_state.call(
		"intent_record_contest_result",
		scope,
		placement,
		{
			"event_id": "contest_nectar:%s:%s" % [clean_contest_id, player_id],
			"contest_id": clean_contest_id
		}
	) as Dictionary
	if bool(result.get("ok", false)):
		var event: Dictionary = {
			"type": "contest_nectar_awarded",
			"contest_id": clean_contest_id,
			"contest_scope": scope,
			"placement": placement,
			"player_id": player_id,
			"xp_awarded": int(result.get("xp_awarded", 0))
		}
		runtime_battle_pass_award.emit(event)
		SFLog.info("BATTLE_PASS_RUNTIME_AWARD", event)
	return result

func contest_period_is_closed(contest_id: String, contest_scope: String = "") -> bool:
	var rank_runtime: Node = get_node_or_null("/root/RankRuntimeAwards")
	if rank_runtime != null and rank_runtime.has_method("contest_period_is_closed"):
		return bool(rank_runtime.call("contest_period_is_closed", contest_id, contest_scope))
	return true

func _connect_tree_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var node_added_cb: Callable = Callable(self, "_on_tree_node_added")
	if not tree.node_added.is_connected(node_added_cb):
		tree.node_added.connect(node_added_cb)

func _scan_for_sim_runner() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var root: Node = tree.get_root()
	if root == null:
		return
	var runner: Node = root.find_child("SimRunner", true, false)
	if runner != null:
		_connect_sim_runner(runner)

func _on_tree_node_added(node: Node) -> void:
	if node == null:
		return
	if node.name != "SimRunner" and not node.has_signal("match_ended"):
		return
	_connect_sim_runner(node)

func _connect_sim_runner(node: Node) -> void:
	if node == null or not node.has_signal("match_ended"):
		return
	var callback: Callable = Callable(self, "_on_runtime_match_ended")
	if not node.is_connected("match_ended", callback):
		node.connect("match_ended", callback)

func _on_runtime_match_ended(winner_id: int, reason: String) -> void:
	var tree: SceneTree = get_tree()
	var battle_pass_state: Node = _battle_pass_state()
	if tree == null or battle_pass_state == null or not tree.has_meta("vs_mode"):
		return
	var mode_id: String = str(tree.get_meta("vs_mode", "")).strip_edges()
	if mode_id.is_empty():
		return
	if bool(tree.get_meta("vs_sync_start", false)):
		_award_pvp_match_result(tree, battle_pass_state, winner_id, reason)
		return
		
	var normalized_async: String = _normalize_async_mode(mode_id)
	if normalized_async.is_empty():
		call_deferred("_sync_tree_contest_reward")
		return
	if normalized_async == "STAGE_RACE" and not _is_final_stage_round(tree):
		return
	var async_result: Dictionary = battle_pass_state.call(
		"intent_record_async_completion",
		normalized_async,
		_resolve_async_map_count(tree),
		not bool(tree.get_meta("vs_free_roll", false)),
		{
			"event_id": _runtime_event_id(tree, normalized_async, reason),
			"contest_id": str(tree.get_meta("contest_id", "")).strip_edges(),
			"contest_scope": str(tree.get_meta("contest_scope", "")).strip_edges().to_upper()
		}
	) as Dictionary
	if bool(async_result.get("ok", false)):
		var async_event: Dictionary = {
			"type": "async_nectar_awarded",
			"mode_id": normalized_async,
			"map_count": _resolve_async_map_count(tree),
			"xp_awarded": int(async_result.get("xp_awarded", 0))
		}
		runtime_battle_pass_award.emit(async_event)
		SFLog.info("BATTLE_PASS_RUNTIME_AWARD", async_event)
	call_deferred("_sync_tree_contest_reward")

func _award_pvp_match_result(tree: SceneTree, battle_pass_state: Node, winner_id: int, reason: String) -> void:
	if not battle_pass_state.has_method("intent_record_pvp_completion"):
		return
	var profile_manager: Node = _profile_manager()
	if profile_manager == null or not profile_manager.has_method("get_user_id"):
		return
	var player_id: String = str(profile_manager.call("get_user_id")).strip_edges()
	if player_id.is_empty():
		return
	var local_owner_id: int = _resolve_local_pvp_owner_id(tree, player_id)
	if local_owner_id <= 0:
		return
	var free_roll: bool = bool(tree.get_meta("vs_free_roll", false))
	var money_tier: int = 0 if free_roll else _money_tier_from_entry_usd(maxi(0, int(tree.get_meta("vs_price_usd", 0))))
	var result: Dictionary = battle_pass_state.call(
		"intent_record_pvp_completion",
		str(tree.get_meta("vs_mode", "1V1")).strip_edges(),
		not free_roll,
		money_tier,
		winner_id > 0 and winner_id == local_owner_id,
		{
			"event_id": _runtime_event_id(tree, str(tree.get_meta("vs_mode", "1V1")), reason),
			"winner_id": winner_id,
			"reason": reason
		}
	) as Dictionary
	if bool(result.get("ok", false)):
		var event: Dictionary = {
			"type": "pvp_nectar_awarded",
			"mode_id": str(tree.get_meta("vs_mode", "1V1")).strip_edges().to_upper(),
			"money_tier": money_tier,
			"did_win": winner_id > 0 and winner_id == local_owner_id,
			"xp_awarded": int(result.get("xp_awarded", 0))
		}
		runtime_battle_pass_award.emit(event)
		SFLog.info("BATTLE_PASS_RUNTIME_AWARD", event)

func _sync_tree_contest_reward() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var contest_id: String = str(tree.get_meta("contest_id", "")).strip_edges()
	if contest_id.is_empty():
		return
	var contest_scope: String = str(tree.get_meta("contest_scope", "")).strip_edges().to_upper()
	var map_count: int = _resolve_async_map_count(tree)
	sync_contest_nectar_rewards(contest_id, contest_scope, map_count)

func _runtime_event_id(tree: SceneTree, mode_id: String, reason: String) -> String:
	var nonce_key: String = "bp_runtime_nonce"
	var nonce_scene_key: String = "bp_runtime_nonce_scene_id"
	var nonce: String = str(tree.get_meta(nonce_key, "")).strip_edges()
	var scene_id: int = 0
	if tree.current_scene != null:
		scene_id = int(tree.current_scene.get_instance_id())
	var nonce_scene_id: int = int(tree.get_meta(nonce_scene_key, -1))
	if nonce.is_empty() or nonce_scene_id != scene_id:
		nonce = "bp_%d_%d" % [int(round(Time.get_unix_time_from_system() * 1000.0)), scene_id]
		tree.set_meta(nonce_key, nonce)
		tree.set_meta(nonce_scene_key, scene_id)
	var round_index: int = maxi(0, int(tree.get_meta("vs_stage_current_index", 0)))
	return "%s:%s:%s:%d" % [nonce, mode_id.strip_edges().to_upper(), reason.strip_edges().to_lower(), round_index]

func _resolve_local_pvp_owner_id(tree: SceneTree, local_player_id: String) -> int:
	var runtime: Node = get_node_or_null("/root/VsPvpRuntime")
	if runtime != null and runtime.has_method("is_active") and bool(runtime.call("is_active")):
		if runtime.has_method("get_local_seat"):
			return clampi(int(runtime.call("get_local_seat")), 1, 4)
	var roster_any: Variant = tree.get_meta("vs_assigned_players", [])
	if typeof(roster_any) == TYPE_ARRAY:
		for entry_any in roster_any as Array:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			if str(entry.get("uid", "")).strip_edges() != local_player_id:
				continue
			return clampi(int(entry.get("seat", 0)), 1, 4)
	var role: String = str(tree.get_meta("vs_handshake_role", "host")).strip_edges().to_lower()
	return 2 if role == "guest" else 1

func _resolve_async_map_count(tree: SceneTree) -> int:
	var stage_paths_any: Variant = tree.get_meta("vs_stage_map_paths", [])
	if typeof(stage_paths_any) == TYPE_ARRAY:
		var stage_paths: Array = stage_paths_any as Array
		if not stage_paths.is_empty():
			return maxi(1, stage_paths.size())
	var map_ids_any: Variant = tree.get_meta("map_ids", [])
	if typeof(map_ids_any) == TYPE_ARRAY:
		var map_ids: Array = map_ids_any as Array
		if not map_ids.is_empty():
			return maxi(1, map_ids.size())
	return 1

func _is_final_stage_round(tree: SceneTree) -> bool:
	var stage_paths_any: Variant = tree.get_meta("vs_stage_map_paths", [])
	if typeof(stage_paths_any) != TYPE_ARRAY:
		return true
	var stage_paths: Array = stage_paths_any as Array
	if stage_paths.size() <= 1:
		return true
	var current_index: int = clampi(int(tree.get_meta("vs_stage_current_index", 0)), 0, stage_paths.size() - 1)
	return current_index + 1 >= stage_paths.size()

func _money_tier_from_entry_usd(entry_usd: int) -> int:
	var safe_usd: int = maxi(0, entry_usd)
	if safe_usd <= 3:
		return 1
	if safe_usd <= 10:
		return 2
	return 3

func _normalize_async_mode(mode_id: String) -> String:
	var clean: String = mode_id.strip_edges().to_upper()
	match clean:
		"STAGE_RACE", "TIMED_RACE", "MISS_N_OUT":
			return clean
		_:
			return ""

func _battle_pass_state() -> Node:
	return get_node_or_null(battle_pass_state_path)

func _profile_manager() -> Node:
	return get_node_or_null(profile_manager_path)

func _contest_state() -> Node:
	return get_node_or_null(contest_state_path)
