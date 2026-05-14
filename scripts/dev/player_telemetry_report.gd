extends SceneTree

const MATCHES_DIR: String = "user://matches"
const PROFILE_PATH: String = "user://player_telemetry_profiles_v1.json"
const STYLE_KEYS: Array[String] = [
	"aggression",
	"defense_bias",
	"expansion_bias",
	"risk_tolerance",
	"swarm_preference",
	"lane_efficiency"
]

func _initialize() -> void:
	var matches: Array[Dictionary] = _load_match_payloads()
	var profile_store: Dictionary = _load_json_dict(PROFILE_PATH)
	var report: Dictionary = _build_report(matches, profile_store, _has_arg("--include-smoke"))
	_print_report(report)
	if _has_arg("--json"):
		print(JSON.stringify(report, "\t"))
	quit(0)

func _build_report(matches: Array[Dictionary], profile_store: Dictionary, include_smoke: bool = false) -> Dictionary:
	var profile_players: Dictionary = _dict(profile_store.get("players", {}))
	if not include_smoke:
		profile_players = _filtered_profiles(profile_players)
	var modes: Dictionary = {}
	var player_ids: Dictionary = {}
	var human_player_ids: Dictionary = {}
	var cpu_player_ids: Dictionary = {}
	var schema_counts: Dictionary = {}
	var schema5_matches: int = 0
	var style_ready_matches: int = 0
	var missing_style_matches: int = 0
	var considered_matches: int = 0
	var recent_match_rows: Array[Dictionary] = []
	for payload in matches:
		if not include_smoke and _is_smoke_match(payload):
			continue
		considered_matches += 1
		var schema_version: int = int(payload.get("schema_version", 0))
		schema_counts[str(schema_version)] = int(schema_counts.get(str(schema_version), 0)) + 1
		if schema_version >= 5:
			schema5_matches += 1
		var metadata: Dictionary = _dict(payload.get("metadata", {}))
		var metrics: Dictionary = _dict(payload.get("metrics", {}))
		var mode: String = str(metadata.get("vs_mode", "")).strip_edges()
		if mode.is_empty():
			mode = "UNKNOWN"
		modes[mode] = int(modes.get(mode, 0)) + 1
		var players: Array = _array(metadata.get("players", []))
		for player_any in players:
			var player: Dictionary = _dict(player_any)
			var player_id: String = str(player.get("player_id", "")).strip_edges()
			if player_id.is_empty():
				player_id = "seat_%d" % int(player.get("seat", 0))
			if player_id.is_empty() or player_id == "seat_0":
				continue
			player_ids[player_id] = true
			if bool(player.get("is_cpu", false)):
				cpu_player_ids[player_id] = true
			else:
				human_player_ids[player_id] = true
		var style_rows: Array = _array(metrics.get("style_features_by_player", []))
		if style_rows.is_empty():
			missing_style_matches += 1
		else:
			style_ready_matches += 1
		recent_match_rows.append(_match_row(payload))
	recent_match_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("end_utc_ms", 0)) > int(b.get("end_utc_ms", 0))
	)
	while recent_match_rows.size() > 8:
		recent_match_rows.pop_back()
	return {
		"matches_found": considered_matches,
		"schema_counts": schema_counts,
		"schema5_matches": schema5_matches,
		"style_ready_matches": style_ready_matches,
		"missing_style_matches": missing_style_matches,
		"modes": modes,
		"player_ids": _sorted_keys(player_ids),
		"human_player_ids": _sorted_keys(human_player_ids),
		"cpu_player_ids": _sorted_keys(cpu_player_ids),
		"distinct_human_profiles": profile_players.size(),
		"profiles": _profile_rows(profile_players),
		"recent_matches": recent_match_rows,
		"profile_path": PROFILE_PATH,
		"matches_dir": MATCHES_DIR,
		"include_smoke": include_smoke
	}

func _match_row(payload: Dictionary) -> Dictionary:
	var metadata: Dictionary = _dict(payload.get("metadata", {}))
	var metrics: Dictionary = _dict(payload.get("metrics", {}))
	return {
		"match_id": str(metadata.get("match_id", "")),
		"map_id": str(metadata.get("map_id", "")),
		"vs_mode": str(metadata.get("vs_mode", "")),
		"schema_version": int(payload.get("schema_version", 0)),
		"end_utc_ms": int(metadata.get("end_utc_ms", 0)),
		"duration_s": float(metadata.get("duration_s", 0.0)),
		"players": _array(metrics.get("players", [])).size(),
		"style_ready": not _array(metrics.get("style_features_by_player", [])).is_empty()
	}

func _profile_rows(players_by_id: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for player_id_any in players_by_id.keys():
		var player_id: String = str(player_id_any)
		var profile: Dictionary = _dict(players_by_id.get(player_id, {}))
		var style: Dictionary = _dict(profile.get("rolling_style_features", {}))
		var knobs: Dictionary = _dict(profile.get("bot_profile_knobs", {}))
		var modes: Dictionary = _dict(profile.get("modes", {}))
		rows.append({
			"player_id": player_id,
			"display_name": str(profile.get("display_name", "")),
			"match_count": int(profile.get("match_count", 0)),
			"last_match_id": str(profile.get("last_match_id", "")),
			"last_seen_utc_ms": int(profile.get("last_seen_utc_ms", 0)),
			"modes": modes,
			"reaction_delay_s": float(knobs.get("reaction_delay_s", 0.0)),
			"aggression": float(style.get("aggression", 0.0)),
			"defense_bias": float(style.get("defense_bias", 0.0)),
			"expansion_bias": float(style.get("expansion_bias", 0.0)),
			"risk_tolerance": float(style.get("risk_tolerance", 0.0)),
			"swarm_preference": float(style.get("swarm_preference", 0.0)),
			"lane_efficiency": float(style.get("lane_efficiency", 0.0))
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var seen_a: int = int(a.get("last_seen_utc_ms", 0))
		var seen_b: int = int(b.get("last_seen_utc_ms", 0))
		if seen_a != seen_b:
			return seen_a > seen_b
		return str(a.get("player_id", "")) < str(b.get("player_id", ""))
	)
	return rows

func _print_report(report: Dictionary) -> void:
	print("PLAYER_TELEMETRY_REPORT")
	print("matches_found=%d schema5=%d style_ready=%d missing_style=%d" % [
		int(report.get("matches_found", 0)),
		int(report.get("schema5_matches", 0)),
		int(report.get("style_ready_matches", 0)),
		int(report.get("missing_style_matches", 0))
	])
	print("modes=%s" % _format_dict(report.get("modes", {})))
	print("human_player_ids=%s" % str(report.get("human_player_ids", [])))
	print("cpu_player_ids=%s" % str(report.get("cpu_player_ids", [])))
	var profiles: Array = _array(report.get("profiles", []))
	print("distinct_human_profiles=%d" % profiles.size())
	for profile_any in profiles:
		var profile: Dictionary = _dict(profile_any)
		print("PROFILE id=%s name=%s matches=%d modes=%s reaction_delay=%.2f aggression=%.2f defense=%.2f expansion=%.2f risk=%.2f swarm=%.2f lane_eff=%.2f" % [
			str(profile.get("player_id", "")),
			str(profile.get("display_name", "")),
			int(profile.get("match_count", 0)),
			_format_dict(profile.get("modes", {})),
			float(profile.get("reaction_delay_s", 0.0)),
			float(profile.get("aggression", 0.0)),
			float(profile.get("defense_bias", 0.0)),
			float(profile.get("expansion_bias", 0.0)),
			float(profile.get("risk_tolerance", 0.0)),
			float(profile.get("swarm_preference", 0.0)),
			float(profile.get("lane_efficiency", 0.0))
		])
	var recent_matches: Array = _array(report.get("recent_matches", []))
	for row_any in recent_matches:
		var row: Dictionary = _dict(row_any)
		print("MATCH id=%s mode=%s map=%s schema=%d players=%d style_ready=%s duration=%.1f" % [
			str(row.get("match_id", "")),
			str(row.get("vs_mode", "")),
			str(row.get("map_id", "")),
			int(row.get("schema_version", 0)),
			int(row.get("players", 0)),
			str(bool(row.get("style_ready", false))),
			float(row.get("duration_s", 0.0))
		])

func _load_match_payloads() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(MATCHES_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".json"):
			continue
		var payload: Dictionary = _load_json_dict("%s/%s" % [MATCHES_DIR, file_name])
		if payload.is_empty():
			continue
		out.append(payload)
	dir.list_dir_end()
	return out

func _filtered_profiles(players_by_id: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for player_id_any in players_by_id.keys():
		var player_id: String = str(player_id_any)
		if _is_smoke_player_id(player_id):
			continue
		out[player_id] = players_by_id.get(player_id_any)
	return out

func _is_smoke_match(payload: Dictionary) -> bool:
	var metadata: Dictionary = _dict(payload.get("metadata", {}))
	var match_id: String = str(metadata.get("match_id", "")).strip_edges().to_lower()
	if match_id.begins_with("smoke") or match_id.begins_with("report_smoke"):
		return true
	var players: Array = _array(metadata.get("players", []))
	for player_any in players:
		var player: Dictionary = _dict(player_any)
		if _is_smoke_player_id(str(player.get("player_id", ""))):
			return true
	return false

func _is_smoke_player_id(player_id: String) -> bool:
	var clean_id: String = player_id.strip_edges().to_lower()
	return clean_id.begins_with("u_smoke_") or clean_id.begins_with("u_report_smoke_")

func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

func _format_dict(raw: Variant) -> String:
	var data: Dictionary = _dict(raw)
	if data.is_empty():
		return "{}"
	var parts: Array[String] = []
	var keys: Array = data.keys()
	keys.sort()
	for key_any in keys:
		parts.append("%s:%s" % [str(key_any), str(data.get(key_any))])
	return "{%s}" % ", ".join(parts)

func _sorted_keys(data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key_any in data.keys():
		out.append(str(key_any))
	out.sort()
	return out

func _dict(raw: Variant) -> Dictionary:
	return raw as Dictionary if typeof(raw) == TYPE_DICTIONARY else {}

func _array(raw: Variant) -> Array:
	return raw as Array if typeof(raw) == TYPE_ARRAY else []

func _has_arg(flag: String) -> bool:
	for arg in OS.get_cmdline_args():
		if str(arg) == flag:
			return true
	return false
