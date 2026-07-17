class_name MatchTelemetryModel
extends RefCounted

const SCHEMA_VERSION: int = 8
const SELF_SCRIPT_PATH: String = "res://scripts/state/match_telemetry_model.gd"

const MATCH_TYPE_VS: int = 0
const MATCH_TYPE_ASYNC: int = 1
const MATCH_TYPE_BOT: int = 2

const EVENT_PRODUCTION: int = 1
const EVENT_COLLISION: int = 2
const EVENT_HIVE_DAMAGE: int = 3
const EVENT_BUFF_ACTIVATION: int = 4
const EVENT_ACTION: int = 5
const EVENT_ARRIVAL: int = 6
const EVENT_TOWER_KILL: int = 7
const EVENT_UNIT_DEATH: int = 8
const EVENT_INTENT: int = 9

var schema_version: int = SCHEMA_VERSION
var metadata: Dictionary = {}
var events: Array[Dictionary] = []
var metrics: Dictionary = {}
var analysis_summary: Dictionary = {}
var totals: Dictionary = {}
var replay: Dictionary = {}
var video_replay: Dictionary = {}
var runtime_perf: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	schema_version = SCHEMA_VERSION
	metadata = _default_metadata()
	events.clear()
	metrics = _default_metrics()
	analysis_summary = _default_analysis_summary()
	totals = _default_totals()
	replay = _default_replay()
	video_replay = _default_video_replay()
	runtime_perf = _default_runtime_perf()

func to_dict() -> Dictionary:
	return {
		"schema_version": int(schema_version),
		"metadata": metadata.duplicate(true),
		"events": _duplicate_event_array(events),
		"metrics": metrics.duplicate(true),
		"analysis_summary": analysis_summary.duplicate(true),
		"totals": totals.duplicate(true),
		"replay": replay.duplicate(true),
		"video_replay": video_replay.duplicate(true),
		"runtime_perf": runtime_perf.duplicate(true)
	}

static func from_dict(payload: Dictionary) -> Variant:
	var normalized: Dictionary = migrate_payload(payload)
	var self_script: Script = load(SELF_SCRIPT_PATH)
	if self_script == null:
		return null
	var model: Variant = self_script.new()
	if model == null:
		return null
	model.schema_version = int(normalized.get("schema_version", SCHEMA_VERSION))
	model.metadata = _normalize_dictionary(normalized.get("metadata", {}), _default_metadata())
	model.events = _normalize_event_array(normalized.get("events", []))
	model.metrics = _normalize_dictionary(normalized.get("metrics", {}), _default_metrics())
	model.analysis_summary = _normalize_dictionary(normalized.get("analysis_summary", {}), _default_analysis_summary())
	model.totals = _normalize_dictionary(normalized.get("totals", {}), _default_totals())
	model.replay = _normalize_dictionary(normalized.get("replay", {}), _default_replay())
	model.video_replay = _normalize_dictionary(normalized.get("video_replay", {}), _default_video_replay())
	model.runtime_perf = _normalize_dictionary(normalized.get("runtime_perf", {}), _default_runtime_perf())
	return model

static func migrate_payload(payload: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if payload != null:
		out = payload.duplicate(true)
	var version: int = int(out.get("schema_version", 0))
	if version <= 0:
		version = 1
	out["schema_version"] = maxi(version, SCHEMA_VERSION)
	if not out.has("metadata") or typeof(out.get("metadata", null)) != TYPE_DICTIONARY:
		out["metadata"] = _default_metadata()
	else:
		out["metadata"] = _merge_defaults(out.get("metadata", {}), _default_metadata())
	if not out.has("events") or typeof(out.get("events", null)) != TYPE_ARRAY:
		out["events"] = []
	if not out.has("metrics") or typeof(out.get("metrics", null)) != TYPE_DICTIONARY:
		out["metrics"] = _default_metrics()
	else:
		out["metrics"] = _merge_defaults(out.get("metrics", {}), _default_metrics())
	if not out.has("analysis_summary") or typeof(out.get("analysis_summary", null)) != TYPE_DICTIONARY:
		out["analysis_summary"] = _default_analysis_summary()
	else:
		out["analysis_summary"] = _merge_defaults(out.get("analysis_summary", {}), _default_analysis_summary())
	if not out.has("totals") or typeof(out.get("totals", null)) != TYPE_DICTIONARY:
		out["totals"] = _default_totals()
	else:
		out["totals"] = _merge_defaults(out.get("totals", {}), _default_totals())
	if not out.has("replay") or typeof(out.get("replay", null)) != TYPE_DICTIONARY:
		out["replay"] = _default_replay()
	else:
		out["replay"] = _merge_defaults(out.get("replay", {}), _default_replay())
	if not out.has("video_replay") or typeof(out.get("video_replay", null)) != TYPE_DICTIONARY:
		out["video_replay"] = _default_video_replay()
	else:
		out["video_replay"] = _merge_defaults(out.get("video_replay", {}), _default_video_replay())
	if not out.has("runtime_perf") or typeof(out.get("runtime_perf", null)) != TYPE_DICTIONARY:
		out["runtime_perf"] = _default_runtime_perf()
	else:
		out["runtime_perf"] = _merge_defaults(out.get("runtime_perf", {}), _default_runtime_perf())
	return out

static func _default_metadata() -> Dictionary:
	return {
		"match_id": "",
		"season_id": "",
		"map_id": "",
		"match_type": MATCH_TYPE_VS,
		"start_utc_ms": 0,
		"end_utc_ms": 0,
		"winner_player_id": 0,
		"duration_s": 0.0,
		"vs_mode": "",
		"start_reason": "",
		"local_player_id": "",
		"opponent_player_ids": [],
		"players": [],
		"rank_transport_mode": "",
		"rank_authoritative_online": false
	}

static func _default_metrics() -> Dictionary:
	return {
		"players": [],
		"player_index": {},
		"won_match_by_player": [],
		"lost_match_by_player": [],
		"total_units_produced_by_player": [],
		"units_sent_by_player": [],
		"barracks_units_produced_by_player": [],
		"total_swarms_sent_by_player": [],
		"hives_captured_by_player": [],
		"units_first_landed_by_player": [],
		"meaningful_actions_by_player": [],
		"meaningful_actions_per_min_by_player": [],
		"lane_reversals_by_player": [],
		"units_arrived_friendly_hive_by_player": [],
		"units_arrived_enemy_hive_by_player": [],
		"units_arrived_npc_hive_by_player": [],
		"units_arrived_hostile_hive_by_player": [],
		"production_idle_time_s_by_player": [],
		"average_production_rate_by_player": [],
		"average_unit_production_interval_s_by_player": [],
		"total_swarm_collisions": 0,
		"total_units_lost_by_player": [],
		"units_wasted_in_collisions_by_player": [],
		"tower_units_killed_by_player": [],
		"hive_damage_dealt_by_player": [],
		"hive_damage_taken_by_player": [],
		"lane_control_time_s_by_player": [],
		"tower_control_time_s_by_player": [],
		"barracks_control_time_s_by_player": [],
		"active_lane_slots_time_s_by_player": [],
		"lane_budget_slots_time_s_by_player": [],
		"lane_budget_utilization_pct_by_player": [],
		"lane_waste_pct_by_player": [],
		"fully_utilized_lane_time_s_by_player": [],
		"underutilized_lane_time_s_by_player": [],
		"board_control_area_by_player": [],
		"average_board_control_share_by_player": [],
		"board_control_peak_share_by_player": [],
		"production_ratio_vs_top_opponent_by_player": [],
		"barracks_production_ratio_vs_top_opponent_by_player": [],
		"tower_kills_ratio_vs_top_opponent_by_player": [],
		"enemy_hive_landings_ratio_vs_top_opponent_by_player": [],
		"hostile_hive_landings_ratio_vs_top_opponent_by_player": [],
		"tower_control_time_ratio_vs_top_opponent_by_player": [],
		"barracks_control_time_ratio_vs_top_opponent_by_player": [],
		"active_lane_slots_time_ratio_vs_top_opponent_by_player": [],
		"lane_budget_utilization_ratio_vs_top_opponent_by_player": [],
		"fully_utilized_lane_time_ratio_vs_top_opponent_by_player": [],
		"underutilized_lane_time_ratio_vs_top_opponent_by_player": [],
		"reaction_time_s_by_player": [],
		"reaction_time_samples_by_player": [],
		"early_meaningful_actions_per_min_by_player": [],
		"early_open_budget_utilization_pct_by_player": [],
		"early_board_control_share_by_player": [],
		"early_game_activity_score_by_player": [],
		"overcommit_events_by_player": [],
		"intent_total_by_player": [],
		"intent_success_by_player": [],
		"intent_fail_by_player": [],
		"intent_budget_fail_by_player": [],
		"intent_no_lane_fail_by_player": [],
		"style_features_by_player": [],
		"bot_profile_knobs_by_player": [],
		"swing_moment_ms": 0
	}

static func _default_analysis_summary() -> Dictionary:
	return {
		"focus_player_id": 0,
		"insights": [],
		"key_stats": []
	}

static func _default_totals() -> Dictionary:
	return {
		"event_count": 0,
		"player_ids": [],
		"unit_spawn_by_player": {},
		"hive_captures_by_player": {},
		"unit_first_land_by_player": {},
		"unit_land_friendly_by_player": {},
		"unit_land_enemy_by_player": {},
		"unit_land_npc_by_player": {},
		"tower_kills_by_player": {},
		"unit_deaths_by_victim_player": {},
		"unit_deaths_by_killer_player": {},
		"intent_total_by_player": {},
		"intent_fail_by_player": {}
	}

static func _default_replay() -> Dictionary:
	return {
		"schema_version": 1,
		"sample_ms": 500,
		"duration_ms": 0,
		"map": {},
		"frames": []
	}

static func _default_video_replay() -> Dictionary:
	return {
		"schema_version": 1,
		"render_mode": "actual_arena_scene",
		"deterministic": true,
		"map_path": "",
		"map_data": {},
		"input_events": [],
		"player_loadouts": {},
		"cosmetics": {},
		"clip_windows": [],
		"cta": {
			"text_overlay": "Tap the link to play Swarmfront",
			"link_url": "",
			"safe_area": "bottom"
		},
		"export": {
			"width": 1080,
			"height": 1920,
			"fps": 30,
			"format": "mp4"
		}
	}

static func _default_runtime_perf() -> Dictionary:
	return {
		"schema_version": 1,
		"sample_ms": 1000,
		"samples": [],
		"summary": {}
	}

static func _duplicate_event_array(source: Array[Dictionary]) -> Array:
	var out: Array = []
	for event in source:
		out.append(event.duplicate(true))
	return out

static func _normalize_event_array(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for event_any in raw as Array:
		if typeof(event_any) != TYPE_DICTIONARY:
			continue
		out.append((event_any as Dictionary).duplicate(true))
	return out

static func _normalize_dictionary(raw: Variant, fallback: Dictionary) -> Dictionary:
	if typeof(raw) == TYPE_DICTIONARY:
		return _merge_defaults(raw as Dictionary, fallback)
	return fallback.duplicate(true)

static func _merge_defaults(raw: Dictionary, defaults: Dictionary) -> Dictionary:
	var merged: Dictionary = defaults.duplicate(true)
	for key_any in raw.keys():
		merged[key_any] = raw.get(key_any)
	return merged
