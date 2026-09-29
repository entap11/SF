extends RefCounted

# A gameplay-only projection. Never serialize arbitrary profile/config dictionaries.
const EVENT_KEYS := "t e p k src dst intent ok reason goal score observed_ms decided_ms execute_ms sim_ms tick lane_id policy style tier seed cooldown_ms sloppy id scope target impact_hd impact_ul"
const PROFILE_KEYS := "seat style tier policy aggression think_interval_ms think_jitter_ms opening_delay_ms notice_delay_ms motor_delay_ms global_intent_cooldown_ms human_behavior_enabled"
const PLAYER_KEYS := "seat is_cpu is_local bot_style bot_tier"
const METRIC_KEYS := "players won_match_by_player total_units_produced_by_player total_units_lost_by_player total_swarms_sent_by_player meaningful_actions_by_player hive_damage_dealt_by_player hives_captured_by_player lane_budget_utilization_pct_by_player production_idle_time_s_by_player"
const MAX_EVENTS := 20000
const MAX_FRAMES := 3600

static func select_scalars(source: Dictionary, keys: String) -> Dictionary:
	var out: Dictionary = {}
	for key in keys.split(" "):
		var value: Variant = source.get(key)
		if value is bool or value is int or value is float or value is String:
			out[key] = value
	return out

static func project(payload: Dictionary, context: Dictionary) -> Dictionary:
	var metadata: Dictionary = payload.get("metadata", {})
	var result: Dictionary = context.duplicate(true)
	result["schema_version"] = 1
	result["metadata"] = select_scalars(metadata, "map_id map_path match_type start_utc_ms config_version config_hash")
	result.metadata.merge(context.get("metadata", {}), true)
	result["players"] = []
	for player in metadata.get("players", []):
		result.players.append(select_scalars(player, PLAYER_KEYS))
	result["metrics"] = {}
	for key in METRIC_KEYS.split(" "):
		var metric: Variant = payload.get("metrics", {}).get(key)
		if metric is Array:
			result.metrics[key] = metric.duplicate()
	result["profiles"] = []
	var events: Array = []
	for event in payload.get("events", []):
		if int(event.get("e", 0)) not in [4, 5, 9]:
			continue
		if str(event.get("k", "")) == "bot_started":
			result.profiles.append(select_scalars(event.get("profile", {}), PROFILE_KEYS))
		var row := select_scalars(event, EVENT_KEYS)
		var plan: Dictionary = event.get("plan", {})
		for key in ["goal", "source", "target"]:
			if plan.has(key):
				row["plan_" + key] = plan[key]
		events.append(row)
	result["dropped_events"] = maxi(0, events.size() - MAX_EVENTS)
	result["events"] = events if events.size() <= MAX_EVENTS else events.slice(0, MAX_EVENTS / 2) + events.slice(-MAX_EVENTS / 2)
	var replay: Dictionary = payload.get("replay", {})
	var frames: Array = replay.get("frames", [])
	var stride := maxi(1, ceili(float(frames.size()) / MAX_FRAMES))
	result["frame_stride"] = stride
	result["frames"] = []
	for index in range(0, frames.size(), stride):
		result.frames.append(_frame(frames[index]))
	if not frames.is_empty() and (frames.size() - 1) % stride != 0:
		result.frames.append(_frame(frames[-1]))
	return result

static func _frame(frame: Dictionary) -> Dictionary:
	# Hive/lane samples describe strategy; this is not a deterministic video replay.
	return {"t": frame.get("t", 0), "h": frame.get("h", []).duplicate(true), "l": frame.get("l", []).duplicate(true)}

static func write_atomic(payload: Dictionary, path: String) -> Dictionary:
	var raw := JSON.stringify(payload).to_utf8_buffer()
	if raw.size() > 8 * 1024 * 1024:
		return {"ok": false, "error": "capture_too_large"}
	var packed := raw.compress(FileAccess.COMPRESSION_GZIP)
	if packed.size() > 2 * 1024 * 1024:
		return {"ok": false, "error": "capture_too_large"}
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return {"ok": false, "error": "capture_directory_failed"}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "capture_write_failed"}
	file.store_buffer(packed)
	file.flush()
	err = file.get_error()
	file.close()
	if err == OK:
		err = DirAccess.rename_absolute(path + ".tmp", path)
	return {"ok": err == OK, "error": "" if err == OK else "capture_commit_failed", "path": path}

static func read_record(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2 * 1024 * 1024:
		return {}
	var raw := file.get_buffer(file.get_length()).decompress_dynamic(8 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}

static func acknowledge(path: String, response: Dictionary, sent_hash: String) -> bool:
	if response.get("ok") != true or str(response.get("sha256", "")) != sent_hash:
		return false
	if str(response.get("capture_id", "")) != path.get_file().trim_suffix(".json.gz"):
		return false
	if FileAccess.get_sha256(path) != sent_hash:
		return false
	return DirAccess.remove_absolute(path) == OK
