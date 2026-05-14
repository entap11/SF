class_name PlayerTelemetryProfileStore
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")

const PROFILE_PATH: String = "user://player_telemetry_profiles_v1.json"
const STORE_VERSION: int = 1
const MAX_RECENT_MATCHES: int = 50

var _loaded: bool = false
var _store: Dictionary = {}

func update_from_match(model: Variant) -> Dictionary:
	_ensure_loaded()
	var payload: Dictionary = _model_to_payload(model)
	if payload.is_empty():
		return {"ok": false, "error": "empty_match"}
	var metadata: Dictionary = _dict(payload.get("metadata", {}))
	var metrics: Dictionary = _dict(payload.get("metrics", {}))
	var players: Array = _array(metrics.get("players", []))
	var player_index: Dictionary = _dict(metrics.get("player_index", {}))
	var snapshots_by_seat: Dictionary = _snapshots_by_seat(_array(metadata.get("players", [])))
	var updated_ids: Array[String] = []
	for seat_any in players:
		var seat: int = int(seat_any)
		var snapshot: Dictionary = _dict(snapshots_by_seat.get(seat, {}))
		if bool(snapshot.get("is_cpu", false)):
			continue
		var player_id: String = str(snapshot.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			player_id = "seat_%d" % seat
		var index: int = int(player_index.get(str(seat), -1))
		if index < 0:
			continue
		_update_player_profile(player_id, seat, index, metadata, metrics, snapshot)
		updated_ids.append(player_id)
	_save_store()
	return {"ok": true, "updated_player_ids": updated_ids, "path": PROFILE_PATH}

func get_profile(player_id: String) -> Dictionary:
	_ensure_loaded()
	var clean_id: String = player_id.strip_edges()
	if clean_id.is_empty():
		return {}
	var players: Dictionary = _dict(_store.get("players", {}))
	return _dict(players.get(clean_id, {})).duplicate(true)

func get_store_snapshot() -> Dictionary:
	_ensure_loaded()
	return _store.duplicate(true)

func _ensure_loaded() -> void:
	if _loaded:
		return
	_store = _load_store()
	_loaded = true

func _load_store() -> Dictionary:
	var defaults: Dictionary = {
		"version": STORE_VERSION,
		"updated_utc_ms": 0,
		"players": {}
	}
	if not FileAccess.file_exists(PROFILE_PATH):
		return defaults
	var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return defaults
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return defaults
	var loaded: Dictionary = parsed as Dictionary
	if not loaded.has("version"):
		loaded["version"] = STORE_VERSION
	if not loaded.has("updated_utc_ms"):
		loaded["updated_utc_ms"] = 0
	if not loaded.has("players") or typeof(loaded.get("players")) != TYPE_DICTIONARY:
		loaded["players"] = {}
	return loaded

func _save_store() -> void:
	_store["version"] = STORE_VERSION
	_store["updated_utc_ms"] = _utc_ms_now()
	var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		SFLog.warn("PLAYER_TELEMETRY_PROFILE_SAVE_FAILED", {"path": PROFILE_PATH})
		return
	file.store_string(JSON.stringify(_store, "\t"))
	file.close()

func _update_player_profile(
	player_id: String,
	seat: int,
	index: int,
	metadata: Dictionary,
	metrics: Dictionary,
	snapshot: Dictionary
) -> void:
	var players_by_id: Dictionary = _dict(_store.get("players", {}))
	var profile: Dictionary = _dict(players_by_id.get(player_id, {}))
	if profile.is_empty():
		profile = _new_profile(player_id)
	var recent: Array = _array(profile.get("recent_matches", []))
	var entry: Dictionary = _match_entry_for_player(seat, index, metadata, metrics, snapshot)
	recent.append(entry)
	while recent.size() > MAX_RECENT_MATCHES:
		recent.pop_front()
	profile["player_id"] = player_id
	profile["display_name"] = str(snapshot.get("display_name", profile.get("display_name", ""))).strip_edges()
	profile["match_count"] = int(profile.get("match_count", 0)) + 1
	profile["last_match_id"] = str(metadata.get("match_id", ""))
	profile["last_seen_utc_ms"] = int(metadata.get("end_utc_ms", _utc_ms_now()))
	profile["recent_matches"] = recent
	profile["rolling_style_features"] = _average_dicts_from_entries(recent, "style_features")
	profile["bot_profile_knobs"] = _average_dicts_from_entries(recent, "bot_profile_knobs")
	profile["modes"] = _recompute_mode_summaries(recent)
	players_by_id[player_id] = profile
	_store["players"] = players_by_id

func _new_profile(player_id: String) -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": "",
		"match_count": 0,
		"last_match_id": "",
		"last_seen_utc_ms": 0,
		"rolling_style_features": {},
		"bot_profile_knobs": {},
		"modes": {},
		"recent_matches": []
	}

func _match_entry_for_player(seat: int, index: int, metadata: Dictionary, metrics: Dictionary, snapshot: Dictionary) -> Dictionary:
	return {
		"match_id": str(metadata.get("match_id", "")),
		"map_id": str(metadata.get("map_id", "")),
		"vs_mode": str(metadata.get("vs_mode", "")),
		"match_type": int(metadata.get("match_type", 0)),
		"season_id": str(metadata.get("season_id", "")),
		"seat": seat,
		"ended_utc_ms": int(metadata.get("end_utc_ms", 0)),
		"duration_s": float(metadata.get("duration_s", 0.0)),
		"won": _int_array_value(metrics, "won_match_by_player", index) > 0,
		"style_features": _dict_array_value(metrics, "style_features_by_player", index),
		"bot_profile_knobs": _dict_array_value(metrics, "bot_profile_knobs_by_player", index),
		"reaction_time_s": _float_array_value(metrics, "reaction_time_s_by_player", index),
		"reaction_samples": _int_array_value(metrics, "reaction_time_samples_by_player", index),
		"meaningful_apm": _float_array_value(metrics, "meaningful_actions_per_min_by_player", index),
		"intent_total": _int_array_value(metrics, "intent_total_by_player", index),
		"intent_fail": _int_array_value(metrics, "intent_fail_by_player", index),
		"display_name": str(snapshot.get("display_name", ""))
	}

func _average_dicts_from_entries(entries: Array, key: String) -> Dictionary:
	var totals: Dictionary = {}
	var counts: Dictionary = {}
	for entry_any in entries:
		var entry: Dictionary = _dict(entry_any)
		var values: Dictionary = _dict(entry.get(key, {}))
		for value_key_any in values.keys():
			var value_key: String = str(value_key_any)
			totals[value_key] = float(totals.get(value_key, 0.0)) + float(values.get(value_key_any, 0.0))
			counts[value_key] = int(counts.get(value_key, 0)) + 1
	var out: Dictionary = {}
	for value_key_any in totals.keys():
		var value_key: String = str(value_key_any)
		var count: int = maxi(1, int(counts.get(value_key, 1)))
		out[value_key] = float(totals.get(value_key, 0.0)) / float(count)
	return out

func _recompute_mode_summaries(entries: Array) -> Dictionary:
	var by_mode: Dictionary = {}
	for entry_any in entries:
		var entry: Dictionary = _dict(entry_any)
		var mode: String = str(entry.get("vs_mode", "")).strip_edges()
		if mode.is_empty():
			mode = "UNKNOWN"
		var mode_summary: Dictionary = _dict(by_mode.get(mode, {"matches": 0, "wins": 0}))
		mode_summary["matches"] = int(mode_summary.get("matches", 0)) + 1
		if bool(entry.get("won", false)):
			mode_summary["wins"] = int(mode_summary.get("wins", 0)) + 1
		by_mode[mode] = mode_summary
	for mode_key_any in by_mode.keys():
		var mode_key: String = str(mode_key_any)
		var mode_summary: Dictionary = _dict(by_mode.get(mode_key, {}))
		var matches: int = maxi(1, int(mode_summary.get("matches", 0)))
		mode_summary["win_rate"] = float(mode_summary.get("wins", 0)) / float(matches)
		by_mode[mode_key] = mode_summary
	return by_mode

func _snapshots_by_seat(raw_snapshots: Array) -> Dictionary:
	var out: Dictionary = {}
	for snapshot_any in raw_snapshots:
		var snapshot: Dictionary = _dict(snapshot_any)
		var seat: int = int(snapshot.get("seat", 0))
		if seat <= 0:
			continue
		out[seat] = snapshot
	return out

func _model_to_payload(model: Variant) -> Dictionary:
	if model == null:
		return {}
	if typeof(model) == TYPE_DICTIONARY:
		return (model as Dictionary).duplicate(true)
	if model.has_method("to_dict"):
		var payload_any: Variant = model.call("to_dict")
		if typeof(payload_any) == TYPE_DICTIONARY:
			return payload_any as Dictionary
	return {}

func _dict(raw: Variant) -> Dictionary:
	return raw as Dictionary if typeof(raw) == TYPE_DICTIONARY else {}

func _array(raw: Variant) -> Array:
	return raw as Array if typeof(raw) == TYPE_ARRAY else []

func _dict_array_value(metrics: Dictionary, key: String, index: int) -> Dictionary:
	var values: Array = _array(metrics.get(key, []))
	if index < 0 or index >= values.size():
		return {}
	return _dict(values[index]).duplicate(true)

func _float_array_value(metrics: Dictionary, key: String, index: int) -> float:
	var values: Array = _array(metrics.get(key, []))
	if index < 0 or index >= values.size():
		return 0.0
	return float(values[index])

func _int_array_value(metrics: Dictionary, key: String, index: int) -> int:
	return int(round(_float_array_value(metrics, key, index)))

func _utc_ms_now() -> int:
	return int(round(Time.get_unix_time_from_system() * 1000.0))
