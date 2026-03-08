extends Node

signal runtime_rank_award(event: Dictionary)

const SFLog = preload("res://scripts/util/sf_log.gd")

@export var rank_state_path: NodePath = NodePath("/root/RankState")
@export var profile_manager_path: NodePath = NodePath("/root/ProfileManager")
@export var contest_state_path: NodePath = NodePath("/root/ContestState")

func _ready() -> void:
	SFLog.allow_tag("RANK_RUNTIME_AWARD")
	_connect_tree_signals()
	_scan_for_sim_runner()
	call_deferred("_sync_tree_contest_reward")

func sync_contest_rank_rewards(contest_id: String, contest_scope: String = "", map_count: int = 5) -> Dictionary:
	var rank_state: Node = _rank_state()
	var contest_state: Node = _contest_state()
	var profile_manager: Node = _profile_manager()
	if rank_state == null or contest_state == null or profile_manager == null:
		return {"ok": false, "reason": "missing_dependency"}
	if not rank_state.has_method("intent_record_contest_result"):
		return {"ok": false, "reason": "rank_state_missing_intent"}
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
	var result: Dictionary = rank_state.call(
		"intent_record_contest_result",
		player_id,
		scope,
		placement,
		{
			"event_id": "contest_rank:%s:%s" % [clean_contest_id, player_id],
			"contest_id": clean_contest_id
		}
	) as Dictionary
	if bool(result.get("ok", false)) and bool(result.get("awarded", false)):
		var event: Dictionary = {
			"type": "contest_rank_awarded",
			"contest_id": clean_contest_id,
			"contest_scope": scope,
			"placement": placement,
			"player_id": player_id
		}
		runtime_rank_award.emit(event)
		SFLog.info("RANK_RUNTIME_AWARD", event)
	return result

func contest_period_is_closed(contest_id: String, contest_scope: String = "") -> bool:
	var clean_contest_id: String = contest_id.strip_edges()
	if clean_contest_id.is_empty():
		return false
	var scope: String = contest_scope.strip_edges().to_upper()
	var time_slice: String = ""
	var contest_state: Node = _contest_state()
	if contest_state != null and contest_state.has_method("parse_contest_id"):
		var parsed: Dictionary = contest_state.call("parse_contest_id", clean_contest_id) as Dictionary
		if scope.is_empty():
			scope = str(parsed.get("scope", "")).strip_edges().to_upper()
		time_slice = str(parsed.get("time", "")).strip_edges()
	if time_slice.is_empty():
		var parts: PackedStringArray = clean_contest_id.split("_")
		if parts.size() >= 4:
			time_slice = str(parts[3]).strip_edges()
	if scope == "" or time_slice == "":
		return true
	var now_local: Dictionary = Time.get_datetime_dict_from_system()
	match scope:
		"WEEKLY":
			var weekly: Dictionary = _parse_week_slice(time_slice)
			if weekly.is_empty():
				return false
			var current_iso: Dictionary = _iso_week_components(
				int(now_local.get("year", 1970)),
				int(now_local.get("month", 1)),
				int(now_local.get("day", 1))
			)
			var contest_year: int = int(weekly.get("year", 0))
			var contest_week: int = int(weekly.get("week", 0))
			var current_year: int = int(current_iso.get("year", 0))
			var current_week: int = int(current_iso.get("week", 0))
			return contest_year < current_year or (contest_year == current_year and contest_week < current_week)
		"MONTHLY":
			var monthly: Dictionary = _parse_month_slice(time_slice)
			if monthly.is_empty():
				return false
			var contest_month_year: int = int(monthly.get("year", 0))
			var contest_month: int = int(monthly.get("month", 0))
			var now_year: int = int(now_local.get("year", 1970))
			var now_month: int = int(now_local.get("month", 1))
			return contest_month_year < now_year or (contest_month_year == now_year and contest_month < now_month)
		"DAILY":
			var daily: Dictionary = _parse_day_slice(time_slice)
			if daily.is_empty():
				return false
			var contest_day_key: int = _ymd_key(int(daily.get("year", 0)), int(daily.get("month", 0)), int(daily.get("day", 0)))
			var now_day_key: int = _ymd_key(int(now_local.get("year", 1970)), int(now_local.get("month", 1)), int(now_local.get("day", 1)))
			return contest_day_key < now_day_key
		"YEARLY":
			var contest_year_only: int = int(time_slice)
			if contest_year_only <= 0:
				return false
			return contest_year_only < int(now_local.get("year", 1970))
		_:
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
	var rank_state: Node = _rank_state()
	if tree == null or rank_state == null or not tree.has_meta("vs_mode"):
		return
	var mode_id: String = str(tree.get_meta("vs_mode", "")).strip_edges()
	if mode_id.is_empty():
		return
	if bool(tree.get_meta("vs_sync_start", false)):
		_award_pvp_match_result(tree, rank_state, winner_id, reason)
		return
	call_deferred("_sync_tree_contest_reward")

func _award_pvp_match_result(tree: SceneTree, rank_state: Node, winner_id: int, reason: String) -> void:
	if not rank_state.has_method("intent_record_match_result"):
		return
	var profile_manager: Node = _profile_manager()
	if profile_manager == null or not profile_manager.has_method("get_user_id"):
		return
	var player_id: String = str(profile_manager.call("get_user_id")).strip_edges()
	var opponent_id: String = _resolve_remote_player_id(tree, player_id)
	if player_id.is_empty() or opponent_id.is_empty():
		return
	var local_owner_id: int = _resolve_local_pvp_owner_id(tree, player_id)
	if local_owner_id <= 0:
		return
	var free_roll: bool = bool(tree.get_meta("vs_free_roll", false))
	var mode_name: String = "STANDARD" if free_roll else "MONEY_MATCH"
	var money_tier: int = 0 if free_roll else _money_tier_from_entry_usd(maxi(0, int(tree.get_meta("vs_price_usd", 0))))
	var result: Dictionary = rank_state.call(
		"intent_record_match_result",
		player_id,
		opponent_id,
		winner_id > 0 and winner_id == local_owner_id,
		mode_name,
		{
			"event_id": _runtime_event_id(tree, mode_name, reason),
			"winner_id": winner_id,
			"reason": reason
		},
		money_tier
	) as Dictionary
	if bool(result.get("ok", false)):
		var event: Dictionary = {
			"type": "pvp_rank_awarded",
			"player_id": player_id,
			"opponent_id": opponent_id,
			"mode_name": mode_name,
			"money_tier": money_tier,
			"did_player_win": winner_id > 0 and winner_id == local_owner_id
		}
		runtime_rank_award.emit(event)
		SFLog.info("RANK_RUNTIME_AWARD", event)

func _sync_tree_contest_reward() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var contest_id: String = str(tree.get_meta("contest_id", "")).strip_edges()
	if contest_id.is_empty():
		return
	var contest_scope: String = str(tree.get_meta("contest_scope", "")).strip_edges().to_upper()
	var map_count: int = _resolve_async_map_count(tree)
	sync_contest_rank_rewards(contest_id, contest_scope, map_count)

func _resolve_remote_player_id(tree: SceneTree, local_player_id: String) -> String:
	var roster_any: Variant = tree.get_meta("vs_assigned_players", [])
	if typeof(roster_any) == TYPE_ARRAY:
		for entry_any in roster_any as Array:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			var uid: String = str(entry.get("uid", "")).strip_edges()
			if uid.is_empty() or uid == local_player_id:
				continue
			return uid
	var remote_profile_any: Variant = tree.get_meta("vs_remote_profile", {})
	if typeof(remote_profile_any) == TYPE_DICTIONARY:
		return str((remote_profile_any as Dictionary).get("uid", "")).strip_edges()
	return ""

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

func _money_tier_from_entry_usd(entry_usd: int) -> int:
	var safe_usd: int = maxi(0, entry_usd)
	if safe_usd <= 3:
		return 1
	if safe_usd <= 10:
		return 2
	return 3

func _runtime_event_id(tree: SceneTree, mode_name: String, reason: String) -> String:
	var nonce_key: String = "rank_runtime_nonce"
	var nonce_scene_key: String = "rank_runtime_nonce_scene_id"
	var nonce: String = str(tree.get_meta(nonce_key, "")).strip_edges()
	var scene_id: int = 0
	if tree.current_scene != null:
		scene_id = int(tree.current_scene.get_instance_id())
	var nonce_scene_id: int = int(tree.get_meta(nonce_scene_key, -1))
	if nonce.is_empty() or nonce_scene_id != scene_id:
		nonce = "rw_%d_%d" % [int(round(Time.get_unix_time_from_system() * 1000.0)), scene_id]
		tree.set_meta(nonce_key, nonce)
		tree.set_meta(nonce_scene_key, scene_id)
	return "%s:%s:%s" % [nonce, mode_name.strip_edges().to_upper(), reason.strip_edges().to_lower()]

func _rank_state() -> Node:
	return get_node_or_null(rank_state_path)

func _profile_manager() -> Node:
	return get_node_or_null(profile_manager_path)

func _contest_state() -> Node:
	return get_node_or_null(contest_state_path)

func _parse_week_slice(time_slice: String) -> Dictionary:
	var clean: String = time_slice.strip_edges().to_upper()
	var parts: PackedStringArray = clean.split("-W")
	if parts.size() != 2:
		return {}
	var year: int = int(parts[0])
	var week: int = int(parts[1])
	if year <= 0 or week <= 0:
		return {}
	return {"year": year, "week": week}

func _parse_month_slice(time_slice: String) -> Dictionary:
	var clean: String = time_slice.strip_edges()
	var parts: PackedStringArray = clean.split("-")
	if parts.size() != 2:
		return {}
	var year: int = int(parts[0])
	var month: int = int(parts[1])
	if year <= 0 or month < 1 or month > 12:
		return {}
	return {"year": year, "month": month}

func _parse_day_slice(time_slice: String) -> Dictionary:
	var clean: String = time_slice.strip_edges()
	var parts: PackedStringArray = clean.split("-")
	if parts.size() != 3:
		return {}
	var year: int = int(parts[0])
	var month: int = int(parts[1])
	var day: int = int(parts[2])
	if year <= 0 or month < 1 or month > 12 or day < 1 or day > 31:
		return {}
	return {"year": year, "month": month, "day": day}

func _iso_week_components(year: int, month: int, day: int) -> Dictionary:
	var safe_year: int = maxi(1, year)
	var safe_month: int = clampi(month, 1, 12)
	var safe_day: int = clampi(day, 1, 31)
	var day_of_year: int = _day_of_year(safe_year, safe_month, safe_day)
	var iso_weekday: int = _iso_weekday(safe_year, safe_month, safe_day)
	var week: int = int(floor(float(day_of_year - iso_weekday + 10) / 7.0))
	var iso_year: int = safe_year
	if week < 1:
		iso_year = safe_year - 1
		week = _iso_weeks_in_year(iso_year)
	elif week > _iso_weeks_in_year(safe_year):
		iso_year = safe_year + 1
		week = 1
	return {"year": iso_year, "week": week}

func _iso_weeks_in_year(year: int) -> int:
	var jan1_iso_weekday: int = _iso_weekday(year, 1, 1)
	if jan1_iso_weekday == 4:
		return 53
	if jan1_iso_weekday == 3 and _is_leap_year(year):
		return 53
	return 52

func _day_of_year(year: int, month: int, day: int) -> int:
	var total: int = day
	for m in range(1, month):
		total += _days_in_month(year, m)
	return total

func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap_year(year) else 28
		_:
			return 30

func _is_leap_year(year: int) -> bool:
	if year % 400 == 0:
		return true
	if year % 100 == 0:
		return false
	return year % 4 == 0

func _iso_weekday(year: int, month: int, day: int) -> int:
	var t: Array[int] = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
	var adjusted_year: int = year
	if month < 3:
		adjusted_year -= 1
	var sunday_zero: int = (adjusted_year + int(floor(adjusted_year / 4.0)) - int(floor(adjusted_year / 100.0)) + int(floor(adjusted_year / 400.0)) + t[month - 1] + day) % 7
	return ((sunday_zero + 6) % 7) + 1

func _ymd_key(year: int, month: int, day: int) -> int:
	return (year * 10000) + (month * 100) + day
