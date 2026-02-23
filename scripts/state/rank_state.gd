extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")
const RankConfigScript = preload("res://scripts/state/rank_config.gd")
const RankModelsScript = preload("res://scripts/state/rank_models.gd")
const RankWaxCalculatorScript = preload("res://scripts/state/rank_wax_calculator.gd")
const RankDecaySystemScript = preload("res://scripts/state/rank_decay_system.gd")
const RankPercentileCalculatorScript = preload("res://scripts/state/rank_percentile_calculator.gd")
const RankPromotionResolverScript = preload("res://scripts/state/rank_promotion_resolver.gd")
const RankLeaderboardManagerScript = preload("res://scripts/state/rank_leaderboard_manager.gd")
const RankMatchmakerScript = preload("res://scripts/state/rank_matchmaker.gd")

signal rank_state_changed(snapshot: Dictionary)
signal rank_event(event: Dictionary)

const CONFIG_PATH: String = "res://data/rank/rank_config.tres"
const SAVE_PATH: String = "user://rank_state.json"
const DAY_SECONDS: int = 86400

var _config: RankConfigScript = null
var _wax_calculator: RankWaxCalculatorScript = RankWaxCalculatorScript.new()
var _decay_system: RankDecaySystemScript = RankDecaySystemScript.new()
var _percentile_calculator: RankPercentileCalculatorScript = RankPercentileCalculatorScript.new()
var _promotion_resolver: RankPromotionResolverScript = RankPromotionResolverScript.new()
var _leaderboard_manager: RankLeaderboardManagerScript = RankLeaderboardManagerScript.new()
var _matchmaker: RankMatchmakerScript = RankMatchmakerScript.new()

var _players_by_id: Dictionary = {}
var _sorted_player_ids: Array[String] = []
var _local_player_id: String = ""

func _ready() -> void:
	SFLog.allow_tag("RANK_STATE")
	SFLog.allow_tag("RANK_EVENT")
	_load_config()
	_load_state()
	_bootstrap_local_player()
	_recompute_rankings(false)
	_save_state()
	_emit_changed()

func intent_register_player(
		player_id: String,
		display_name: String,
		region: String = "",
		friends: Array = []
	) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return {"ok": false, "reason": "missing_player_id"}
	var existing: Dictionary = _players_by_id.get(clean_id, {}) as Dictionary
	var now_unix: int = _now_unix()
	if existing.is_empty():
		var friend_ids: Array[String] = RankModelsScript.sanitize_friends(friends)
		var initial_wax: float = maxf(_config.wax_floor, _config.base_gain)
		var record: Dictionary = RankModelsScript.new_player_record(
			clean_id,
			display_name,
			_region_or_default(region),
			initial_wax,
			now_unix,
			friend_ids
		)
		_players_by_id[clean_id] = record
	else:
		existing["display_name"] = _display_name_or_default(display_name, clean_id)
		existing["region"] = _region_or_default(region)
		existing["friends"] = RankModelsScript.sanitize_friends(friends)
		_players_by_id[clean_id] = _normalize_player_record(clean_id, existing)
	_recompute_rankings(true)
	_save_state()
	_emit_changed()
	return {"ok": true, "player": get_player_snapshot(clean_id)}

func intent_set_player_friends(player_id: String, friends: Array) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return {"ok": false, "reason": "missing_player_id"}
	var record: Dictionary = _players_by_id.get(clean_id, {}) as Dictionary
	if record.is_empty():
		return {"ok": false, "reason": "player_not_found"}
	record["friends"] = RankModelsScript.sanitize_friends(friends)
	_players_by_id[clean_id] = _normalize_player_record(clean_id, record)
	_save_state()
	_emit_changed()
	return {"ok": true}

func intent_set_player_region(player_id: String, region: String) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return {"ok": false, "reason": "missing_player_id"}
	var record: Dictionary = _players_by_id.get(clean_id, {}) as Dictionary
	if record.is_empty():
		return {"ok": false, "reason": "player_not_found"}
	record["region"] = _region_or_default(region)
	_players_by_id[clean_id] = _normalize_player_record(clean_id, record)
	_save_state()
	_emit_changed()
	return {"ok": true}

func intent_record_match_result(
		player_id: String,
		opponent_id: String,
		did_player_win: bool,
		mode_name: String,
		metadata: Dictionary = {}
	) -> Dictionary:
	var p1: String = player_id.strip_edges()
	var p2: String = opponent_id.strip_edges()
	if p1 == "" or p2 == "":
		return {"ok": false, "reason": "missing_player_ids"}
	if p1 == p2:
		return {"ok": false, "reason": "same_player_ids"}
	_ensure_player_exists(p1)
	_ensure_player_exists(p2)

	var now_unix: int = _now_unix()
	_apply_decay_all(now_unix)

	var player_record: Dictionary = _players_by_id.get(p1, {}) as Dictionary
	var opponent_record: Dictionary = _players_by_id.get(p2, {}) as Dictionary
	var player_wax_before: float = float(player_record.get("wax_score", 0.0))
	var opponent_wax_before: float = float(opponent_record.get("wax_score", 0.0))

	var mode_key: String = mode_name.strip_edges().to_upper()
	if mode_key == "":
		mode_key = "STANDARD"

	var player_gain: float = _wax_calculator.compute_gain(player_wax_before, opponent_wax_before, mode_key)
	var opponent_gain: float = _wax_calculator.compute_gain(opponent_wax_before, player_wax_before, mode_key)
	var player_loss: float = _wax_calculator.compute_loss(player_wax_before, opponent_wax_before, mode_key)
	var opponent_loss: float = _wax_calculator.compute_loss(opponent_wax_before, player_wax_before, mode_key)

	if did_player_win:
		player_record["wax_score"] = player_wax_before + player_gain
		opponent_record["wax_score"] = maxf(_config.wax_floor, opponent_wax_before - opponent_loss)
	else:
		player_record["wax_score"] = maxf(_config.wax_floor, player_wax_before - player_loss)
		opponent_record["wax_score"] = opponent_wax_before + opponent_gain

	var decay_day: int = int(floor(float(now_unix) / float(DAY_SECONDS)))
	player_record["last_active_unix"] = now_unix
	opponent_record["last_active_unix"] = now_unix
	player_record["last_decay_day"] = decay_day
	opponent_record["last_decay_day"] = decay_day

	_players_by_id[p1] = _normalize_player_record(p1, player_record)
	_players_by_id[p2] = _normalize_player_record(p2, opponent_record)
	_recompute_rankings(true)
	_save_state()

	var payload: Dictionary = {
		"type": "wax_match_resolved",
		"mode": mode_key,
		"winner": p1 if did_player_win else p2,
		"loser": p2 if did_player_win else p1,
		"player_id": p1,
		"opponent_id": p2,
		"player_wax_before": player_wax_before,
		"player_wax_after": float((_players_by_id.get(p1, {}) as Dictionary).get("wax_score", player_wax_before)),
		"opponent_wax_before": opponent_wax_before,
		"opponent_wax_after": float((_players_by_id.get(p2, {}) as Dictionary).get("wax_score", opponent_wax_before)),
		"metadata": metadata
	}
	rank_event.emit(payload)
	SFLog.info("RANK_EVENT", payload)
	_emit_changed()
	return {
		"ok": true,
		"player": get_player_snapshot(p1),
		"opponent": get_player_snapshot(p2)
	}

func intent_apply_decay_tick() -> Dictionary:
	var now_unix: int = _now_unix()
	var applied: int = _apply_decay_all(now_unix)
	if applied > 0:
		_recompute_rankings(true)
		_save_state()
		_emit_changed()
	return {"ok": true, "players_decayed": applied}

func intent_debug_set_player_wax(player_id: String, wax_score: float) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return {"ok": false, "reason": "missing_player_id"}
	_ensure_player_exists(clean_id)
	var record: Dictionary = _players_by_id.get(clean_id, {}) as Dictionary
	record["wax_score"] = maxf(_config.wax_floor, wax_score)
	_players_by_id[clean_id] = _normalize_player_record(clean_id, record)
	_recompute_rankings(true)
	_save_state()
	_emit_changed()
	return {"ok": true, "player": get_player_snapshot(clean_id)}

func intent_debug_set_last_active(player_id: String, last_active_unix: int) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return {"ok": false, "reason": "missing_player_id"}
	_ensure_player_exists(clean_id)
	var record: Dictionary = _players_by_id.get(clean_id, {}) as Dictionary
	record["last_active_unix"] = maxi(0, last_active_unix)
	record["last_decay_day"] = -1
	_players_by_id[clean_id] = _normalize_player_record(clean_id, record)
	_save_state()
	_emit_changed()
	return {"ok": true}

func get_player_snapshot(player_id: String) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	var record: Dictionary = _players_by_id.get(clean_id, {}) as Dictionary
	if record.is_empty():
		return {}
	return {
		"player_id": clean_id,
		"display_name": str(record.get("display_name", clean_id)),
		"region": str(record.get("region", "GLOBAL")),
		"wax_score": float(record.get("wax_score", 0.0)),
		"last_active_unix": int(record.get("last_active_unix", 0)),
		"rank_position": int(record.get("rank_position", 0)),
		"percentile": float(record.get("percentile", 0.0)),
		"tier_id": str(record.get("tier_id", "DRONE")),
		"color_id": str(record.get("color_id", "GREEN")),
		"apex_active": bool(record.get("apex_active", false)),
		"promotion_history": _safe_dictionary(record.get("promotion_history", {}))
	}

func get_local_rank_view(filter_name: String = "GLOBAL", limit: int = 25) -> Dictionary:
	var requester_id: String = _resolve_local_player_id()
	var board: Dictionary = _leaderboard_manager.build_view(
		_players_by_id,
		_sorted_player_ids,
		requester_id,
		filter_name,
		limit,
		_config
	)
	board["local_player_id"] = requester_id
	board["player"] = get_player_snapshot(requester_id)
	return board

func get_leaderboard_snapshot(requester_id: String, filter_name: String = "GLOBAL", limit: int = 25) -> Dictionary:
	return _leaderboard_manager.build_view(
		_players_by_id,
		_sorted_player_ids,
		requester_id,
		filter_name,
		limit,
		_config
	)

func find_match_candidates(requester_id: String, queue_entries: Array) -> Array[Dictionary]:
	return _matchmaker.find_candidates(_players_by_id, requester_id, queue_entries, _config)

func get_snapshot() -> Dictionary:
	return {
		"local_player_id": _resolve_local_player_id(),
		"player_count": _players_by_id.size(),
		"top_players": _top_rows(10),
		"config_enabled": _config.enabled
	}

func _emit_changed() -> void:
	rank_state_changed.emit(get_snapshot())

func _load_config() -> void:
	var loaded_any: Variant = load(CONFIG_PATH)
	if loaded_any is RankConfigScript:
		_config = loaded_any as RankConfigScript
	else:
		_config = RankConfigScript.new()
	_wax_calculator.configure(_config)
	_decay_system.configure(_config)

func _load_state() -> void:
	_players_by_id.clear()
	_sorted_player_ids.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed_any: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed_any) != TYPE_DICTIONARY:
		return
	var parsed: Dictionary = parsed_any as Dictionary
	_local_player_id = str(parsed.get("local_player_id", ""))
	var players_raw_any: Variant = parsed.get("players_by_id", {})
	if typeof(players_raw_any) != TYPE_DICTIONARY:
		return
	var players_raw: Dictionary = players_raw_any as Dictionary
	for player_id_any in players_raw.keys():
		var player_id: String = str(player_id_any)
		var record_any: Variant = players_raw.get(player_id_any, {})
		if typeof(record_any) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = record_any as Dictionary
		_players_by_id[player_id] = _normalize_player_record(player_id, record)

func _save_state() -> void:
	var payload: Dictionary = {
		"local_player_id": _resolve_local_player_id(),
		"players_by_id": _players_by_id
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _bootstrap_local_player() -> void:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null:
		if profile_manager.has_method("ensure_loaded"):
			profile_manager.call("ensure_loaded")
		if profile_manager.has_method("get_user_id"):
			_local_player_id = str(profile_manager.call("get_user_id"))
	if _local_player_id.strip_edges() == "":
		_local_player_id = "local_player"
	var display_name: String = _local_player_id
	if profile_manager != null and profile_manager.has_method("get_display_name"):
		display_name = str(profile_manager.call("get_display_name"))
	_ensure_player_exists(_local_player_id, display_name)

func _ensure_player_exists(player_id: String, display_name: String = "") -> void:
	if _players_by_id.has(player_id):
		return
	var now_unix: int = _now_unix()
	var record: Dictionary = RankModelsScript.new_player_record(
		player_id,
		_display_name_or_default(display_name, player_id),
		_config.default_region,
		maxf(_config.wax_floor, _config.base_gain),
		now_unix,
		[]
	)
	_players_by_id[player_id] = record

func _apply_decay_all(now_unix: int) -> int:
	var applied_count: int = 0
	for player_id_any in _players_by_id.keys():
		var player_id: String = str(player_id_any)
		var record: Dictionary = _players_by_id.get(player_id, {}) as Dictionary
		var decay: Dictionary = _decay_system.apply_decay(record, now_unix)
		if bool(decay.get("applied", false)):
			applied_count += 1
		_players_by_id[player_id] = _normalize_player_record(player_id, record)
	return applied_count

func _recompute_rankings(emit_events: bool) -> void:
	var now_unix: int = _now_unix()
	_apply_decay_all(now_unix)
	_sorted_player_ids = _percentile_calculator.sort_player_ids_desc(_players_by_id)
	var percentile_map: Dictionary = _percentile_calculator.build_percentile_map(_sorted_player_ids)
	for player_id in _sorted_player_ids:
		var record: Dictionary = _players_by_id.get(player_id, {}) as Dictionary
		var rank_data: Dictionary = percentile_map.get(player_id, {}) as Dictionary
		var rank_position: int = int(rank_data.get("rank_position", 0))
		var percentile: float = float(rank_data.get("percentile", 0.0))
		record["rank_position"] = rank_position
		record["percentile"] = percentile
		var resolved: Dictionary = _promotion_resolver.resolve_player(
			record,
			percentile,
			rank_position,
			_sorted_player_ids.size(),
			_config
		)
		var old_tier: String = str(record.get("tier_id", "DRONE"))
		var old_color: String = str(record.get("color_id", "GREEN"))
		record["tier_id"] = str(resolved.get("tier_id", old_tier))
		record["color_id"] = str(resolved.get("color_id", old_color))
		record["promotion_history"] = _safe_dictionary(resolved.get("promotion_history", {}))
		record["apex_active"] = bool(resolved.get("apex_active", false))
		_players_by_id[player_id] = _normalize_player_record(player_id, record)

		if not emit_events:
			continue
		if bool(resolved.get("tier_promoted", false)):
			var first_time: bool = bool(resolved.get("first_time_tier_promotion", false))
			if first_time or not _config.ceremony_first_time_only:
				var tier_event: Dictionary = {
					"type": "tier_promotion",
					"player_id": player_id,
					"tier_id": str(record.get("tier_id", "DRONE")),
					"first_time": first_time,
					"ceremony": first_time
				}
				rank_event.emit(tier_event)
				SFLog.info("RANK_EVENT", tier_event)
		if bool(resolved.get("color_promoted", false)) and not bool(resolved.get("tier_promoted", false)):
			var color_event: Dictionary = {
				"type": "color_promotion",
				"player_id": player_id,
				"tier_id": str(record.get("tier_id", "DRONE")),
				"color_id": str(record.get("color_id", "GREEN"))
			}
			rank_event.emit(color_event)
			SFLog.info("RANK_EVENT", color_event)

func _normalize_player_record(player_id: String, raw_record: Dictionary) -> Dictionary:
	var record: Dictionary = raw_record.duplicate(true)
	record["player_id"] = player_id
	record["display_name"] = _display_name_or_default(str(record.get("display_name", "")), player_id)
	record["region"] = _region_or_default(str(record.get("region", "")))
	record["wax_score"] = maxf(_config.wax_floor, float(record.get("wax_score", _config.base_gain)))
	record["last_active_unix"] = int(record.get("last_active_unix", _now_unix()))
	record["last_decay_day"] = int(record.get("last_decay_day", -1))
	record["tier_id"] = str(record.get("tier_id", "DRONE")).strip_edges().to_upper()
	record["color_id"] = str(record.get("color_id", "GREEN")).strip_edges().to_upper()
	record["rank_position"] = int(record.get("rank_position", 0))
	record["percentile"] = clampf(float(record.get("percentile", 0.0)), 0.0, 1.0)
	record["promotion_history"] = _normalize_history(_safe_dictionary(record.get("promotion_history", {})), str(record.get("tier_id", "DRONE")))
	var friends_any: Variant = record.get("friends", [])
	var friends_array: Array = []
	if typeof(friends_any) == TYPE_ARRAY:
		friends_array = friends_any as Array
	record["friends"] = RankModelsScript.sanitize_friends(friends_array)
	record["apex_active"] = bool(record.get("apex_active", false))
	return record

func _normalize_history(raw: Dictionary, current_tier: String) -> Dictionary:
	var out: Dictionary = {}
	for key_any in raw.keys():
		var key: String = str(key_any).strip_edges().to_upper()
		if key == "":
			continue
		if bool(raw.get(key_any, false)):
			out[key] = true
	if current_tier.strip_edges() != "":
		out[current_tier.strip_edges().to_upper()] = true
	return out

func _top_rows(limit: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i in range(mini(_sorted_player_ids.size(), maxi(1, limit))):
		var player_id: String = _sorted_player_ids[i]
		var record: Dictionary = _players_by_id.get(player_id, {}) as Dictionary
		rows.append({
			"rank": int(record.get("rank_position", i + 1)),
			"player_id": player_id,
			"display_name": str(record.get("display_name", player_id)),
			"wax_score": float(record.get("wax_score", 0.0)),
			"tier_id": str(record.get("tier_id", "DRONE")),
			"color_id": str(record.get("color_id", "GREEN")),
			"percentile": float(record.get("percentile", 0.0))
		})
	return rows

func _resolve_local_player_id() -> String:
	if _local_player_id.strip_edges() != "":
		return _local_player_id
	if _players_by_id.has("local_player"):
		_local_player_id = "local_player"
		return _local_player_id
	for key_any in _players_by_id.keys():
		_local_player_id = str(key_any)
		return _local_player_id
	_local_player_id = "local_player"
	return _local_player_id

func _display_name_or_default(display_name: String, fallback_id: String) -> String:
	var clean: String = display_name.strip_edges()
	if clean == "":
		return fallback_id
	return clean

func _region_or_default(region: String) -> String:
	var clean: String = region.strip_edges().to_upper()
	if clean == "":
		return _config.default_region.strip_edges().to_upper()
	return clean

func _safe_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}

func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
