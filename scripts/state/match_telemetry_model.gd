class_name MatchTelemetryModel
extends RefCounted

const SCHEMA_VERSION: int = 1
const SELF_SCRIPT_PATH: String = "res://scripts/state/match_telemetry_model.gd"

const MATCH_TYPE_VS: int = 0
const MATCH_TYPE_ASYNC: int = 1
const MATCH_TYPE_BOT: int = 2

const EVENT_PRODUCTION: int = 1
const EVENT_COLLISION: int = 2
const EVENT_HIVE_DAMAGE: int = 3
const EVENT_BUFF_ACTIVATION: int = 4

var schema_version: int = SCHEMA_VERSION
var metadata: Dictionary = {}
var events: Array[Dictionary] = []
var metrics: Dictionary = {}
var analysis_summary: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	schema_version = SCHEMA_VERSION
	metadata = _default_metadata()
	events.clear()
	metrics = _default_metrics()
	analysis_summary = _default_analysis_summary()

func to_dict() -> Dictionary:
	return {
		"schema_version": int(schema_version),
		"metadata": metadata.duplicate(true),
		"events": _duplicate_event_array(events),
		"metrics": metrics.duplicate(true),
		"analysis_summary": analysis_summary.duplicate(true)
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
	return model

static func migrate_payload(payload: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if payload != null:
		out = payload.duplicate(true)
	var version: int = int(out.get("schema_version", 0))
	if version <= 0:
		version = 1
	out["schema_version"] = version
	if not out.has("metadata") or typeof(out.get("metadata", null)) != TYPE_DICTIONARY:
		out["metadata"] = _default_metadata()
	if not out.has("events") or typeof(out.get("events", null)) != TYPE_ARRAY:
		out["events"] = []
	if not out.has("metrics") or typeof(out.get("metrics", null)) != TYPE_DICTIONARY:
		out["metrics"] = _default_metrics()
	if not out.has("analysis_summary") or typeof(out.get("analysis_summary", null)) != TYPE_DICTIONARY:
		out["analysis_summary"] = _default_analysis_summary()
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
		"duration_s": 0.0
	}

static func _default_metrics() -> Dictionary:
	return {
		"players": [],
		"player_index": {},
		"total_units_produced_by_player": [],
		"production_idle_time_s_by_player": [],
		"average_production_rate_by_player": [],
		"total_swarm_collisions": 0,
		"total_units_lost_by_player": [],
		"hive_damage_dealt_by_player": [],
		"hive_damage_taken_by_player": [],
		"lane_control_time_s_by_player": [],
		"overcommit_events_by_player": [],
		"swing_moment_ms": 0
	}

static func _default_analysis_summary() -> Dictionary:
	return {
		"focus_player_id": 0,
		"insights": [],
		"key_stats": []
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
		return (raw as Dictionary).duplicate(true)
	return fallback.duplicate(true)
