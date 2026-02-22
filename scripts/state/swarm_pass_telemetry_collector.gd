class_name SwarmPassTelemetryCollector
extends RefCounted

const THRESHOLDS: Array[int] = [60, 75, 90, 100]

var _season_id: String = ""
var _segment_player_ids: Dictionary = {}
var _segment_threshold_hits: Dictionary = {}
var _segment_level_distribution: Dictionary = {}
var _segment_daily_nectar: Dictionary = {}
var _segment_time_to_level: Dictionary = {}
var _player_first_level_ts: Dictionary = {}

func configure_for_season(season_id: String) -> void:
	if _season_id == season_id:
		return
	_season_id = season_id
	_segment_player_ids.clear()
	_segment_threshold_hits.clear()
	_segment_level_distribution.clear()
	_segment_daily_nectar.clear()
	_segment_time_to_level.clear()
	_player_first_level_ts.clear()

func import_data(raw: Dictionary) -> void:
	_season_id = str(raw.get("season_id", ""))
	_segment_player_ids = (raw.get("segment_player_ids", {}) as Dictionary).duplicate(true)
	_segment_threshold_hits = (raw.get("segment_threshold_hits", {}) as Dictionary).duplicate(true)
	_segment_level_distribution = (raw.get("segment_level_distribution", {}) as Dictionary).duplicate(true)
	_segment_daily_nectar = (raw.get("segment_daily_nectar", {}) as Dictionary).duplicate(true)
	_segment_time_to_level = (raw.get("segment_time_to_level", {}) as Dictionary).duplicate(true)
	_player_first_level_ts = (raw.get("player_first_level_ts", {}) as Dictionary).duplicate(true)

func export_data() -> Dictionary:
	return {
		"season_id": _season_id,
		"segment_player_ids": _segment_player_ids,
		"segment_threshold_hits": _segment_threshold_hits,
		"segment_level_distribution": _segment_level_distribution,
		"segment_daily_nectar": _segment_daily_nectar,
		"segment_time_to_level": _segment_time_to_level,
		"player_first_level_ts": _player_first_level_ts
	}

func on_progress(
	player_id: String,
	pass_tier: String,
	level: int,
	season_started_unix: int,
	now_unix: int,
	nectar_amount: int
) -> void:
	var segment: String = pass_tier.to_upper()
	if segment == "":
		segment = "FREE"
	_touch_segment(segment)
	var players: Dictionary = _segment_player_ids.get(segment, {})
	players[player_id] = true
	_segment_player_ids[segment] = players

	var level_dist: Dictionary = _segment_level_distribution.get(segment, {})
	var key: String = str(level)
	level_dist[key] = int(level_dist.get(key, 0)) + 1
	_segment_level_distribution[segment] = level_dist

	var day_key: String = _day_key(now_unix)
	var daily_for_segment: Dictionary = _segment_daily_nectar.get(segment, {})
	daily_for_segment[day_key] = int(daily_for_segment.get(day_key, 0)) + maxi(nectar_amount, 0)
	_segment_daily_nectar[segment] = daily_for_segment

	var first_key: String = "%s:%s" % [segment, player_id]
	if not _player_first_level_ts.has(first_key):
		_player_first_level_ts[first_key] = now_unix
	var first_ts: int = int(_player_first_level_ts.get(first_key, now_unix))
	var elapsed: int = maxi(0, now_unix - max(season_started_unix, first_ts))

	var threshold_hits: Dictionary = _segment_threshold_hits.get(segment, {})
	var time_to_level: Dictionary = _segment_time_to_level.get(segment, {})
	for threshold in THRESHOLDS:
		var threshold_key: String = str(threshold)
		if level < threshold:
			continue
		var unique_hit_key: String = "%s:%s:%s" % [segment, player_id, threshold_key]
		if _player_first_level_ts.has(unique_hit_key):
			continue
		_player_first_level_ts[unique_hit_key] = now_unix
		threshold_hits[threshold_key] = int(threshold_hits.get(threshold_key, 0)) + 1
		var samples: Array = time_to_level.get(threshold_key, []) as Array
		samples.append(elapsed)
		time_to_level[threshold_key] = samples
	_segment_threshold_hits[segment] = threshold_hits
	_segment_time_to_level[segment] = time_to_level

func build_dashboard_snapshot() -> Dictionary:
	var out: Dictionary = {
		"season_id": _season_id,
		"segments": {}
	}
	var segments: Dictionary = out.get("segments", {})
	for segment_any in _segment_player_ids.keys():
		var segment: String = str(segment_any)
		var players: Dictionary = _segment_player_ids.get(segment, {})
		var player_count: int = maxi(1, players.size())
		var thresholds: Dictionary = _segment_threshold_hits.get(segment, {})
		var pct: Dictionary = {}
		for threshold in THRESHOLDS:
			var key: String = str(threshold)
			var reached: int = int(thresholds.get(key, 0))
			pct[key] = float(reached) / float(player_count)
		segments[segment] = {
			"players": players.size(),
			"threshold_reached": thresholds.duplicate(true),
			"threshold_pct": pct,
			"level_distribution": (_segment_level_distribution.get(segment, {}) as Dictionary).duplicate(true),
			"daily_nectar": (_segment_daily_nectar.get(segment, {}) as Dictionary).duplicate(true),
			"time_to_level_sec": _time_to_level_avg_seconds(segment)
		}
	out["segments"] = segments
	return out

func _touch_segment(segment: String) -> void:
	if not _segment_player_ids.has(segment):
		_segment_player_ids[segment] = {}
	if not _segment_threshold_hits.has(segment):
		_segment_threshold_hits[segment] = {}
	if not _segment_level_distribution.has(segment):
		_segment_level_distribution[segment] = {}
	if not _segment_daily_nectar.has(segment):
		_segment_daily_nectar[segment] = {}
	if not _segment_time_to_level.has(segment):
		_segment_time_to_level[segment] = {}

func _day_key(unix_ts: int) -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_ts)
	return "%04d-%02d-%02d" % [int(dt.get("year", 1970)), int(dt.get("month", 1)), int(dt.get("day", 1))]

func _time_to_level_avg_seconds(segment: String) -> Dictionary:
	var out: Dictionary = {}
	var by_threshold: Dictionary = _segment_time_to_level.get(segment, {})
	for threshold_any in by_threshold.keys():
		var threshold_key: String = str(threshold_any)
		var samples: Array = by_threshold.get(threshold_any, []) as Array
		if samples.is_empty():
			continue
		var total: int = 0
		for s_any in samples:
			total += int(s_any)
		out[threshold_key] = float(total) / float(samples.size())
	return out

