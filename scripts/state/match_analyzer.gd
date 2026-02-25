class_name MatchAnalyzer
extends RefCounted

const MatchTelemetryModelScript = preload("res://scripts/state/match_telemetry_model.gd")

const IDLE_GAP_S: float = 2.0
const OVERCOMMIT_WINDOW_S: float = 5.0
const OVERCOMMIT_RATIO: float = 0.70
const SWING_WINDOW_S: float = 10.0

const IDLE_RATIO_THRESHOLD: float = 0.12
const CONTROL_GAP_RATIO: float = 0.20
const MAX_INSIGHTS: int = 5
const MIN_INSIGHTS: int = 3

func analyze(telemetry: Variant, focus_player_id: int) -> Dictionary:
	var metadata: Dictionary = {}
	var metrics: Dictionary = {}
	var events: Array[Dictionary] = []
	if telemetry is Object:
		var telemetry_object: Object = telemetry as Object
		var metadata_any: Variant = telemetry_object.get("metadata")
		var metrics_any: Variant = telemetry_object.get("metrics")
		var events_any: Variant = telemetry_object.get("events")
		if typeof(metadata_any) == TYPE_DICTIONARY:
			metadata = metadata_any as Dictionary
		if typeof(metrics_any) == TYPE_DICTIONARY:
			metrics = metrics_any as Dictionary
		if typeof(events_any) == TYPE_ARRAY:
			for event_any in events_any as Array:
				if typeof(event_any) != TYPE_DICTIONARY:
					continue
				events.append(event_any as Dictionary)
	var players: Array[int] = _metric_players(metrics)
	var focus_player: int = _resolve_focus_player(players, focus_player_id)
	var focus_index: int = players.find(focus_player)

	var duration_s: float = maxf(0.0, float(metadata.get("duration_s", 0.0)))
	var idle_s: float = _metric_value_float(metrics, "production_idle_time_s_by_player", focus_index)
	var overcommit_count: int = _metric_value_int(metrics, "overcommit_events_by_player", focus_index)
	var produced_count: int = _metric_value_int(metrics, "total_units_produced_by_player", focus_index)
	var damage_dealt: int = _metric_value_int(metrics, "hive_damage_dealt_by_player", focus_index)
	var damage_taken: int = _metric_value_int(metrics, "hive_damage_taken_by_player", focus_index)
	var lane_control_s: float = _metric_value_float(metrics, "lane_control_time_s_by_player", focus_index)
	var opponent_index: int = _top_opponent_index(metrics, focus_index)
	var opponent_control_s: float = _metric_value_float(metrics, "lane_control_time_s_by_player", opponent_index)

	var insights: Array[String] = []
	if overcommit_count >= 2:
		insights.append("You overcommitted to one lane multiple times; you gave up pressure elsewhere.")

	var idle_ratio: float = 0.0
	if duration_s > 0.0:
		idle_ratio = idle_s / duration_s
	if idle_ratio > IDLE_RATIO_THRESHOLD:
		insights.append("Your production idle time was high (~%d%%). Keep pressure up by feeding consistently." % int(round(idle_ratio * 100.0)))

	var buff_insight: String = _build_buff_timing_insight(events, focus_player)
	if buff_insight != "":
		insights.append(buff_insight)

	var swing_moment_ms: int = int(metrics.get("swing_moment_ms", 0))
	insights.append("Major swing at %s." % _format_mmss(swing_moment_ms))

	if opponent_index >= 0 and opponent_control_s > 0.0 and lane_control_s < opponent_control_s * (1.0 - CONTROL_GAP_RATIO):
		insights.append("Opponent controlled the map longer; contest towers/barracks earlier.")

	if insights.size() < MIN_INSIGHTS:
		if idle_ratio <= IDLE_RATIO_THRESHOLD:
			insights.append("Production uptime stayed stable; keep converting that tempo into map control.")
		if overcommit_count < 2:
			insights.append("Lane pressure stayed fairly distributed; continue rotating pressure before all-ins.")
		if _build_buff_timing_insight(events, focus_player) == "":
			insights.append("No meaningful buff swing detected; save buffs for committed pushes.")
	while insights.size() > MAX_INSIGHTS:
		insights.pop_back()
	while insights.size() < MIN_INSIGHTS:
		insights.append("Review the %s swing window and test earlier responses." % _format_mmss(swing_moment_ms))

	var key_stats: Array[Dictionary] = []
	key_stats.append({"label": "Duration", "value": _format_duration(duration_s)})
	key_stats.append({"label": "Units Produced", "value": str(produced_count)})
	key_stats.append({"label": "Idle Production", "value": "%d%%" % int(round(idle_ratio * 100.0))})
	key_stats.append({"label": "Hive Damage (Dealt/Taken)", "value": "%d / %d" % [damage_dealt, damage_taken]})
	key_stats.append({"label": "Lane Control Time", "value": "%.1fs" % lane_control_s})
	key_stats.append({"label": "Overcommit Events", "value": str(overcommit_count)})

	return {
		"focus_player_id": focus_player,
		"insights": insights,
		"key_stats": key_stats
	}

func _build_buff_timing_insight(events: Array[Dictionary], focus_player_id: int) -> String:
	var best_positive_delta: int = 0
	var best_positive_buff: String = ""
	var best_positive_t: int = 0
	var low_impact_buff: String = ""
	var low_impact_t: int = 0
	for event in events:
		if int(event.get("e", -1)) != int(MatchTelemetryModelScript.EVENT_BUFF_ACTIVATION):
			continue
		if int(event.get("p", 0)) != focus_player_id:
			continue
		var buff_id: String = str(event.get("id", "buff"))
		var event_t: int = int(event.get("t", 0))
		var impact_hd: int = int(event.get("impact_hd", 0))
		var impact_ul: int = int(event.get("impact_ul", 0))
		if impact_hd > best_positive_delta:
			best_positive_delta = impact_hd
			best_positive_buff = buff_id
			best_positive_t = event_t
		if low_impact_buff == "" and impact_hd <= 0 and impact_ul <= 0:
			low_impact_buff = buff_id
			low_impact_t = event_t
	if best_positive_delta > 0:
		return "Big swing after %s at %s. Good timing." % [_present_buff_id(best_positive_buff), _format_mmss(best_positive_t)]
	if low_impact_buff != "":
		return "Buff %s at %s had low impact; try saving it for a committed push." % [_present_buff_id(low_impact_buff), _format_mmss(low_impact_t)]
	return ""

func _metric_players(metrics: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var raw_players: Variant = metrics.get("players", [])
	if typeof(raw_players) != TYPE_ARRAY:
		return out
	for player_any in raw_players as Array:
		var player_id: int = int(player_any)
		if player_id <= 0:
			continue
		out.append(player_id)
	return out

func _resolve_focus_player(players: Array[int], requested_focus: int) -> int:
	if requested_focus > 0 and players.has(requested_focus):
		return requested_focus
	if not players.is_empty():
		return players[0]
	return maxi(1, requested_focus)

func _metric_value_int(metrics: Dictionary, key: String, index: int) -> int:
	if index < 0:
		return 0
	var raw: Variant = metrics.get(key, [])
	if typeof(raw) != TYPE_ARRAY:
		return 0
	var values: Array = raw as Array
	if index >= values.size():
		return 0
	return int(values[index])

func _metric_value_float(metrics: Dictionary, key: String, index: int) -> float:
	if index < 0:
		return 0.0
	var raw: Variant = metrics.get(key, [])
	if typeof(raw) != TYPE_ARRAY:
		return 0.0
	var values: Array = raw as Array
	if index >= values.size():
		return 0.0
	return float(values[index])

func _top_opponent_index(metrics: Dictionary, focus_index: int) -> int:
	var lane_control_any: Variant = metrics.get("lane_control_time_s_by_player", [])
	if typeof(lane_control_any) != TYPE_ARRAY:
		return -1
	var lane_control: Array = lane_control_any as Array
	var best_index: int = -1
	var best_value: float = -1.0
	for i in range(lane_control.size()):
		if i == focus_index:
			continue
		var value: float = float(lane_control[i])
		if value > best_value:
			best_value = value
			best_index = i
	return best_index

func _format_duration(duration_s: float) -> String:
	var total_seconds: int = maxi(0, int(round(duration_s)))
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _format_mmss(time_ms: int) -> String:
	var clamped_ms: int = maxi(0, time_ms)
	var total_seconds: int = clamped_ms / 1000
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _present_buff_id(buff_id: String) -> String:
	var cleaned: String = buff_id.strip_edges()
	if cleaned.is_empty():
		return "buff"
	return cleaned.replace("_", " ").capitalize()
