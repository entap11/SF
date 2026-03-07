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
const RankTransportHttpScript = preload("res://scripts/state/rank_transport_http.gd")

signal rank_state_changed(snapshot: Dictionary)
signal rank_event(event: Dictionary)
signal tier_changed(tier_index: int, tier_rank: int)

const CONFIG_PATH: String = "res://data/rank/rank_config.tres"
const SAVE_PATH_DEFAULT: String = "user://rank_state.json"
const ENV_BACKEND_URL: String = "SF_RANK_BACKEND_URL"
const ENV_BACKEND_TOKEN: String = "SF_RANK_BACKEND_TOKEN"
const SETTINGS_BACKEND_URL: String = "swarmfront/rank/backend_url"
const SETTINGS_BACKEND_TOKEN: String = "swarmfront/rank/backend_token"
const SETTINGS_BACKEND_TIMEOUT_SEC: String = "swarmfront/rank/backend_timeout_sec"
const DEFAULT_BACKEND_TIMEOUT_SEC: float = 2.0
const SMOKE_FIXTURE_PREFIX: String = "p"
const SMOKE_FIXTURE_ID_LEN: int = 4
const SMOKE_FIXTURE_MIN_BULK_COUNT: int = 50
const SMOKE_FIXTURE_SENTINEL_FIRST: String = "p001"
const SMOKE_FIXTURE_SENTINEL_LAST: String = "p101"
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
var _last_tier_badge: Dictionary = {}
var _transport_http = null
var _transport_mode: String = "local"
var _transport_error_logged: bool = false
var save_path: String = SAVE_PATH_DEFAULT

func _ready() -> void:
	SFLog.allow_tag("RANK_STATE")
	SFLog.allow_tag("RANK_EVENT")
	_load_config()
	_load_state()
	_bootstrap_local_player()
	_configure_transport()
	if not _refresh_from_backend_internal(false):
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
	var payload: Dictionary = {
		"player_id": clean_id,
		"display_name": display_name,
		"region": region,
		"friends": friends
	}
	var transport_result := _handle_transport_write("register_player", payload)
	if bool(transport_result.get("handled", false)):
		return transport_result.get("result", {}) as Dictionary
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
	var payload: Dictionary = {
		"player_id": clean_id,
		"friends": friends
	}
	var transport_result := _handle_transport_write("set_player_friends", payload)
	if bool(transport_result.get("handled", false)):
		return transport_result.get("result", {}) as Dictionary
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
	var payload: Dictionary = {
		"player_id": clean_id,
		"region": region
	}
	var transport_result := _handle_transport_write("set_player_region", payload)
	if bool(transport_result.get("handled", false)):
		return transport_result.get("result", {}) as Dictionary
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
	var payload: Dictionary = {
		"player_id": p1,
		"opponent_id": p2,
		"did_player_win": did_player_win,
		"mode_name": mode_name,
		"metadata": metadata
	}
	var transport_result := _handle_transport_write("record_match_result", payload)
	if bool(transport_result.get("handled", false)):
		return transport_result.get("result", {}) as Dictionary
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

	var event_payload: Dictionary = {
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
	rank_event.emit(event_payload)
	SFLog.info("RANK_EVENT", event_payload)
	_emit_changed()
	return {
		"ok": true,
		"player": get_player_snapshot(p1),
		"opponent": get_player_snapshot(p2)
	}

func intent_apply_decay_tick() -> Dictionary:
	var transport_result := _handle_transport_write("apply_decay_tick", {})
	if bool(transport_result.get("handled", false)):
		return transport_result.get("result", {}) as Dictionary
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
	var payload: Dictionary = {
		"player_id": clean_id,
		"wax_score": wax_score
	}
	var transport_result := _handle_transport_write("debug_set_player_wax", payload)
	if bool(transport_result.get("handled", false)):
		return transport_result.get("result", {}) as Dictionary
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
	var payload: Dictionary = {
		"player_id": clean_id,
		"last_active_unix": last_active_unix
	}
	var transport_result := _handle_transport_write("debug_set_last_active", payload)
	if bool(transport_result.get("handled", false)):
		return transport_result.get("result", {}) as Dictionary
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
	var transport := _call_transport("get_player_snapshot", {"player_id": clean_id})
	if bool(transport.get("handled", false)):
		var remote_result: Dictionary = transport.get("result", {}) as Dictionary
		if bool(remote_result.get("ok", false)):
			var remote_player: Variant = remote_result.get("player", null)
			if typeof(remote_player) == TYPE_DICTIONARY:
				_upsert_remote_player(remote_player)
				return (remote_player as Dictionary).duplicate(true)
			if remote_result.has("player_id"):
				_upsert_remote_player(remote_result)
				return remote_result.duplicate(true)
	return _get_player_snapshot_local(clean_id)

func _get_player_snapshot_local(player_id: String) -> Dictionary:
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
	var transport := _call_transport("get_local_rank_view", {
		"filter_name": filter_name,
		"limit": limit,
		"requester_id": requester_id
	})
	if bool(transport.get("handled", false)):
		var remote_result: Dictionary = transport.get("result", {}) as Dictionary
		if bool(remote_result.get("ok", false)):
			if _cache_remote_write_result(remote_result):
				_save_state()
			var remote_board: Variant = remote_result.get("board", null)
			if typeof(remote_board) == TYPE_DICTIONARY:
				return (remote_board as Dictionary).duplicate(true)
			if remote_result.has("rows"):
				return remote_result.duplicate(true)
	var board: Dictionary = _leaderboard_manager.build_view(
		_players_by_id,
		_sorted_player_ids,
		requester_id,
		filter_name,
		limit,
		_config
	)
	board["local_player_id"] = requester_id
	board["player"] = _get_player_snapshot_local(requester_id)
	return board

func get_leaderboard_snapshot(requester_id: String, filter_name: String = "GLOBAL", limit: int = 25) -> Dictionary:
	var transport := _call_transport("get_leaderboard_snapshot", {
		"requester_id": requester_id,
		"filter_name": filter_name,
		"limit": limit
	})
	if bool(transport.get("handled", false)):
		var remote_result: Dictionary = transport.get("result", {}) as Dictionary
		if bool(remote_result.get("ok", false)):
			if _cache_remote_write_result(remote_result):
				_save_state()
			var remote_board: Variant = remote_result.get("board", null)
			if typeof(remote_board) == TYPE_DICTIONARY:
				return (remote_board as Dictionary).duplicate(true)
			if remote_result.has("rows"):
				return remote_result.duplicate(true)
	return _leaderboard_manager.build_view(
		_players_by_id,
		_sorted_player_ids,
		requester_id,
		filter_name,
		limit,
		_config
)

func find_match_candidates(requester_id: String, queue_entries: Array) -> Array[Dictionary]:
	var transport := _call_transport("find_match_candidates", {
		"requester_id": requester_id,
		"queue_entries": queue_entries
	})
	if bool(transport.get("handled", false)):
		var remote_result: Dictionary = transport.get("result", {}) as Dictionary
		if bool(remote_result.get("ok", false)):
			var rows_any: Variant = remote_result.get("rows", [])
			if typeof(rows_any) == TYPE_ARRAY:
				var rows_out: Array[Dictionary] = []
				for row_any in rows_any as Array:
					if typeof(row_any) != TYPE_DICTIONARY:
						continue
					rows_out.append((row_any as Dictionary).duplicate(true))
				return rows_out
	return _matchmaker.find_candidates(_players_by_id, requester_id, queue_entries, _config)

func get_snapshot() -> Dictionary:
	return {
		"local_player_id": _resolve_local_player_id(),
		"player_count": _players_by_id.size(),
		"top_players": _top_rows(10),
		"config_enabled": _config.enabled,
		"transport_mode": _transport_mode,
		"authoritative_online": is_authoritative_transport_online()
	}

func get_local_tier_badge() -> Dictionary:
	var player_id: String = _resolve_local_player_id()
	var record: Dictionary = _players_by_id.get(player_id, {}) as Dictionary
	if record.is_empty():
		return {
			"tier_index": 0,
			"tier_rank": 0,
			"tier_id": "DRONE"
		}
	var tier_id: String = str(record.get("tier_id", "DRONE")).strip_edges().to_upper()
	var tier_index_zero: int = _config.tier_index(tier_id)
	var tier_index_one: int = tier_index_zero + 1 if tier_index_zero >= 0 else 0
	var tier_rank: int = _compute_tier_rank_for_player(player_id, tier_id)
	return {
		"tier_index": tier_index_one,
		"tier_rank": tier_rank,
		"tier_id": tier_id
	}

func _emit_changed() -> void:
	rank_state_changed.emit(get_snapshot())
	var badge: Dictionary = get_local_tier_badge()
	if badge != _last_tier_badge:
		_last_tier_badge = badge.duplicate(true)
		tier_changed.emit(int(badge.get("tier_index", 0)), int(badge.get("tier_rank", 0)))

func get_transport_mode() -> String:
	return _transport_mode

func is_authoritative_transport_online() -> bool:
	return _transport_mode == "http" and _transport_http != null and _transport_http.configured()

func refresh_from_backend() -> Dictionary:
	var ok: bool = _refresh_from_backend_internal(true)
	return {
		"ok": ok,
		"transport_mode": _transport_mode,
		"player_count": _players_by_id.size()
	}

func _configure_transport() -> void:
	var backend_url: String = _configured_backend_url()
	if backend_url.is_empty():
		_transport_http = null
		_transport_mode = "local"
		return
	_transport_http = RankTransportHttpScript.new()
	_transport_http.configure(
		backend_url,
		_configured_backend_timeout_sec(),
		_configured_backend_token()
	)
	_transport_mode = "http"
	SFLog.allow_tag("RANK_TRANSPORT_CONFIG")
	SFLog.info("RANK_TRANSPORT_CONFIG", {"mode": _transport_mode, "url": backend_url})

func _configured_backend_url() -> String:
	var env_url: String = OS.get_environment(ENV_BACKEND_URL).strip_edges()
	if not env_url.is_empty():
		return env_url
	if ProjectSettings.has_setting(SETTINGS_BACKEND_URL):
		return str(ProjectSettings.get_setting(SETTINGS_BACKEND_URL, "")).strip_edges()
	return ""

func _configured_backend_token() -> String:
	var env_token: String = OS.get_environment(ENV_BACKEND_TOKEN).strip_edges()
	if not env_token.is_empty():
		return env_token
	if ProjectSettings.has_setting(SETTINGS_BACKEND_TOKEN):
		return str(ProjectSettings.get_setting(SETTINGS_BACKEND_TOKEN, "")).strip_edges()
	return ""

func _configured_backend_timeout_sec() -> float:
	if ProjectSettings.has_setting(SETTINGS_BACKEND_TIMEOUT_SEC):
		return maxf(0.1, float(ProjectSettings.get_setting(SETTINGS_BACKEND_TIMEOUT_SEC, DEFAULT_BACKEND_TIMEOUT_SEC)))
	return DEFAULT_BACKEND_TIMEOUT_SEC

func _call_transport(action: String, payload: Dictionary) -> Dictionary:
	if _transport_http == null or not _transport_http.configured():
		return {"handled": false}
	var result: Dictionary = _transport_http.call_action(action, payload)
	if bool(result.get("ok", false)):
		_transport_error_logged = false
		return {"handled": true, "result": result}
	if bool(result.get("transport_error", false)):
		if not _transport_error_logged:
			_transport_error_logged = true
			SFLog.allow_tag("RANK_TRANSPORT_FALLBACK")
			SFLog.warn("RANK_TRANSPORT_FALLBACK", {
				"action": action,
				"err": str(result.get("err", "transport_error")),
				"mode": _transport_mode
			}, "", 3000)
		return {"handled": false}
	return {"handled": true, "result": result}

func _handle_transport_write(action: String, payload: Dictionary) -> Dictionary:
	var transport := _call_transport(action, payload)
	if bool(transport.get("handled", false)):
		var remote_result: Dictionary = transport.get("result", {}) as Dictionary
		if bool(remote_result.get("ok", false)) and _cache_remote_write_result(remote_result):
			_save_state()
			_emit_changed()
		return {"handled": true, "result": remote_result}
	if is_authoritative_transport_online():
		return {
			"handled": true,
			"result": {
				"ok": false,
				"reason": "rank_backend_unavailable",
				"transport_error": true,
				"action": action
			}
		}
	return {"handled": false}

func _refresh_from_backend_internal(emit_changed: bool) -> bool:
	var transport := _call_transport("get_snapshot", {"local_player_id": _resolve_local_player_id()})
	if not bool(transport.get("handled", false)):
		return false
	var result: Dictionary = transport.get("result", {}) as Dictionary
	if not bool(result.get("ok", false)):
		return false
	var changed: bool = _apply_remote_state_payload(result)
	if changed:
		_save_state()
		if emit_changed:
			_emit_changed()
	return changed

func _apply_remote_state_payload(payload: Dictionary) -> bool:
	var state_any: Variant = payload.get("state", null)
	if typeof(state_any) != TYPE_DICTIONARY:
		state_any = payload.get("snapshot", null)
	if typeof(state_any) != TYPE_DICTIONARY and payload.has("players_by_id"):
		state_any = payload
	if typeof(state_any) != TYPE_DICTIONARY:
		return false
	var state: Dictionary = state_any as Dictionary
	var players_any: Variant = state.get("players_by_id", null)
	if typeof(players_any) != TYPE_DICTIONARY:
		return false
	var players_raw: Dictionary = players_any as Dictionary
	_players_by_id.clear()
	for player_id_any in players_raw.keys():
		var player_id: String = str(player_id_any)
		var record_any: Variant = players_raw.get(player_id_any, {})
		if typeof(record_any) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = record_any as Dictionary
		_players_by_id[player_id] = _normalize_player_record(player_id, record)
	var remote_local_id: String = str(state.get("local_player_id", _local_player_id)).strip_edges()
	if not remote_local_id.is_empty():
		_local_player_id = remote_local_id
	_prune_smoke_fixture_players_if_present()
	_sorted_player_ids = _percentile_calculator.sort_player_ids_desc(_players_by_id)
	return true

func _cache_remote_write_result(result: Dictionary) -> bool:
	if _apply_remote_state_payload(result):
		return true
	var changed: bool = false
	changed = _upsert_remote_player(result.get("player", null)) or changed
	changed = _upsert_remote_player(result.get("opponent", null)) or changed
	if changed:
		_sorted_player_ids = _percentile_calculator.sort_player_ids_desc(_players_by_id)
	return changed

func _upsert_remote_player(player_any: Variant) -> bool:
	if typeof(player_any) != TYPE_DICTIONARY:
		return false
	var player: Dictionary = player_any as Dictionary
	var player_id: String = str(player.get("player_id", "")).strip_edges()
	if player_id.is_empty():
		return false
	var existing: Dictionary = _players_by_id.get(player_id, {}) as Dictionary
	var merged: Dictionary = existing.duplicate(true)
	merged["display_name"] = str(player.get("display_name", merged.get("display_name", player_id)))
	merged["region"] = str(player.get("region", merged.get("region", _config.default_region)))
	merged["wax_score"] = float(player.get("wax_score", merged.get("wax_score", _config.base_gain)))
	merged["last_active_unix"] = int(player.get("last_active_unix", merged.get("last_active_unix", _now_unix())))
	merged["last_decay_day"] = int(merged.get("last_decay_day", -1))
	merged["tier_id"] = str(player.get("tier_id", merged.get("tier_id", "DRONE")))
	merged["color_id"] = str(player.get("color_id", merged.get("color_id", "GREEN")))
	merged["rank_position"] = int(player.get("rank_position", merged.get("rank_position", 0)))
	merged["percentile"] = float(player.get("percentile", merged.get("percentile", 0.0)))
	merged["promotion_history"] = _safe_dictionary(player.get("promotion_history", merged.get("promotion_history", {})))
	var friends_any: Variant = merged.get("friends", [])
	var friends_array: Array = []
	if typeof(friends_any) == TYPE_ARRAY:
		friends_array = friends_any as Array
	merged["friends"] = RankModelsScript.sanitize_friends(friends_array)
	merged["apex_active"] = bool(player.get("apex_active", merged.get("apex_active", false)))
	_players_by_id[player_id] = _normalize_player_record(player_id, merged)
	return true

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
	var resolved_save_path: String = _resolved_save_path()
	if not FileAccess.file_exists(resolved_save_path):
		return
	var file: FileAccess = FileAccess.open(resolved_save_path, FileAccess.READ)
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
	_prune_smoke_fixture_players_if_present()

func _save_state() -> void:
	var payload: Dictionary = {
		"local_player_id": _resolve_local_player_id(),
		"players_by_id": _players_by_id
	}
	var file: FileAccess = FileAccess.open(_resolved_save_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _resolved_save_path() -> String:
	var clean: String = save_path.strip_edges()
	if clean == "":
		return SAVE_PATH_DEFAULT
	return clean

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

func _compute_tier_rank_for_player(player_id: String, tier_id: String) -> int:
	if player_id.strip_edges() == "" or tier_id.strip_edges() == "":
		return 0
	var rank_in_tier: int = 0
	for sorted_id in _sorted_player_ids:
		var row_record: Dictionary = _players_by_id.get(sorted_id, {}) as Dictionary
		if row_record.is_empty():
			continue
		if str(row_record.get("tier_id", "")).strip_edges().to_upper() != tier_id:
			continue
		rank_in_tier += 1
		if sorted_id == player_id:
			return rank_in_tier
	return 0

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

func _prune_smoke_fixture_players_if_present() -> void:
	if _players_by_id.is_empty():
		return
	var fixture_ids: Array[String] = []
	for player_id_any in _players_by_id.keys():
		var player_id: String = str(player_id_any)
		var record: Dictionary = _players_by_id.get(player_id, {}) as Dictionary
		if _is_smoke_fixture_player(player_id, record):
			fixture_ids.append(player_id)
	if fixture_ids.size() < SMOKE_FIXTURE_MIN_BULK_COUNT:
		return
	if not fixture_ids.has(SMOKE_FIXTURE_SENTINEL_FIRST) or not fixture_ids.has(SMOKE_FIXTURE_SENTINEL_LAST):
		return
	var local_record: Dictionary = _players_by_id.get(_local_player_id, {}) as Dictionary
	if _is_smoke_fixture_player(_local_player_id, local_record):
		return
	for fixture_id in fixture_ids:
		_players_by_id.erase(fixture_id)
	SFLog.info("RANK_STATE", {
		"fixture_cleanup": true,
		"removed_players": fixture_ids.size()
	})

func _is_smoke_fixture_player(player_id: String, record: Dictionary) -> bool:
	if record.is_empty():
		return false
	if player_id.length() != SMOKE_FIXTURE_ID_LEN:
		return false
	if not player_id.begins_with(SMOKE_FIXTURE_PREFIX):
		return false
	var suffix: String = player_id.substr(1, 3)
	if not suffix.is_valid_int():
		return false
	var expected_name: String = "Player %s" % suffix
	return str(record.get("display_name", "")).strip_edges() == expected_name

func _safe_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}

func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
