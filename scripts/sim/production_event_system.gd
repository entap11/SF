# Transient authoritative production-event spine. Events are committed once in
# deterministic simulation order, consumed synchronously, and never retained as
# historical gameplay state.
class_name ProductionEventSystem
extends RefCounted

const AuthoritativeBuffSystem := preload("res://scripts/sim/authoritative_buff_system.gd")

const PRODUCER_HIVE: String = "hive"
const PRODUCER_BARRACKS: String = "barracks"
const PRODUCER_SYSTEM: String = "system"

const REASON_NORMAL_PRODUCTION: String = "normal_production"
const REASON_SUPERCHARGE_RELEASE: String = "supercharge_release"
const REASON_PASS_THROUGH: String = "pass_through"
const REASON_SCRIPTED: String = "scripted"

static func prepare(state: GameState, unit: Dictionary, source: String = "") -> Dictionary:
	if state == null:
		return {"ok": false, "reason": "missing_game_state"}
	_begin_tick(state)
	var classification: Dictionary = _classify(unit, source)
	var event_id: String = str(unit.get("production_event_id", "")).strip_edges()
	if not event_id.is_empty() and state.production_event_receipts_this_tick.has(event_id):
		return {"ok": false, "duplicate": true, "reason": "production_event_already_committed", "production_event_id": event_id}
	var producer_key: String = "%s:%d" % [str(classification.get("producer_kind", PRODUCER_SYSTEM)), int(classification.get("producer_id", 0))]
	var ordinal: int = int(state.production_event_local_ordinal_by_producer.get(producer_key, 0)) + 1
	state.production_event_local_ordinal_by_producer[producer_key] = ordinal
	if event_id.is_empty():
		event_id = "%d:%s:%d:%d" % [int(state.tick), str(classification.get("producer_kind", PRODUCER_SYSTEM)), int(classification.get("producer_id", 0)), ordinal]
	var event: Dictionary = {
		"ok": true,
		"production_event_id": event_id,
		"simulation_tick": int(state.tick),
		"producer_local_spawn_ordinal": ordinal,
		"producer_kind": str(classification.get("producer_kind", PRODUCER_SYSTEM)),
		"producer_id": int(classification.get("producer_id", 0)),
		"spawn_reason": str(classification.get("spawn_reason", REASON_SCRIPTED)),
		"source_hive_id": int(classification.get("source_hive_id", -1)),
		"directed_lane_id": int(unit.get("lane_id", -1)),
		"lane_generation": int(unit.get("lane_generation", 0)),
		"owner_id": int(unit.get("owner_id", 0)),
		"unit_count": maxi(1, int(unit.get("amount", 1)))
	}
	return event

static func commit(state: GameState, event: Dictionary, unit: Dictionary) -> Dictionary:
	if state == null or not bool(event.get("ok", false)):
		return {"ok": false, "reason": str(event.get("reason", "invalid_production_event"))}
	_begin_tick(state)
	var event_id: String = str(event.get("production_event_id", "")).strip_edges()
	if event_id.is_empty():
		return {"ok": false, "reason": "missing_production_event_id"}
	if state.production_event_receipts_this_tick.has(event_id):
		return {"ok": false, "duplicate": true, "reason": "production_event_already_committed", "production_event_id": event_id}
	state.production_event_receipts_this_tick[event_id] = true
	unit["production_event_id"] = event_id
	AuthoritativeBuffSystem.notify_production_event(state, event, unit)
	return {"ok": true, "production_event_id": event_id, "event": event.duplicate(true)}

static func _begin_tick(state: GameState) -> void:
	if int(state.production_event_receipt_tick) == int(state.tick):
		return
	state.production_event_receipt_tick = int(state.tick)
	state.production_event_local_ordinal_by_producer.clear()
	state.production_event_receipts_this_tick.clear()

static func _classify(unit: Dictionary, source: String) -> Dictionary:
	var clean_source: String = source.strip_edges().to_lower()
	if clean_source.is_empty():
		clean_source = str(unit.get("arrive_source", "lane")).strip_edges().to_lower()
	var from_id: int = int(unit.get("from_id", -1))
	var lane_id: int = int(unit.get("lane_id", -1))
	# Legacy barracks cohorts used the lane source label but carry a negative
	# producer/lane identity. Classify the authoritative producer first.
	if (from_id < 0 or lane_id < 0) and clean_source in ["lane", "lane_system"]:
		return {"producer_kind": PRODUCER_BARRACKS, "producer_id": absi(from_id), "source_hive_id": -1, "spawn_reason": REASON_NORMAL_PRODUCTION}
	match clean_source:
		"supercharge_release":
			return {"producer_kind": PRODUCER_HIVE, "producer_id": from_id, "source_hive_id": from_id, "spawn_reason": REASON_SUPERCHARGE_RELEASE}
		"pass_through":
			return {"producer_kind": PRODUCER_HIVE, "producer_id": from_id, "source_hive_id": from_id, "spawn_reason": REASON_PASS_THROUGH}
		"barracks":
			return {"producer_kind": PRODUCER_BARRACKS, "producer_id": absi(from_id), "source_hive_id": -1, "spawn_reason": REASON_NORMAL_PRODUCTION}
		"lane", "lane_system":
			return {"producer_kind": PRODUCER_HIVE, "producer_id": from_id, "source_hive_id": from_id, "spawn_reason": REASON_NORMAL_PRODUCTION}
	if from_id < 0 or lane_id < 0:
		return {"producer_kind": PRODUCER_BARRACKS, "producer_id": absi(from_id), "source_hive_id": -1, "spawn_reason": REASON_NORMAL_PRODUCTION}
	return {"producer_kind": PRODUCER_SYSTEM, "producer_id": 0, "source_hive_id": -1, "spawn_reason": REASON_SCRIPTED}
