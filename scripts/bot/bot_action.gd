class_name BotAction
extends RefCounted

const DETERMINISTIC_VARIANT := preload("res://scripts/util/deterministic_variant.gd")

const OPEN_ROUTE: String = "open_route"
const SWARM: String = "swarm"
const RETRACT_ROUTE: String = "retract_route"

const ATTACK: String = "attack"
const FEED: String = "feed"


static func from_policy_intent(
	decision: Dictionary,
	seat: int,
	decision_id: int,
	decision_tick: int,
	policy_version: String
) -> Dictionary:
	var src_id: int = int(decision.get("src", -1))
	var dst_id: int = int(decision.get("dst", -1))
	var intent: String = str(decision.get("intent", "")).strip_edges().to_lower()
	if src_id <= 0 or dst_id <= 0:
		return {}
	var kind: String = ""
	var route_intent: String = ""
	match intent:
		ATTACK, FEED:
			kind = OPEN_ROUTE
			route_intent = intent
		"swarm":
			kind = SWARM
			route_intent = "swarm"
		_:
			return {}
	return {
		"schema_version": 1,
		"kind": kind,
		"route_intent": route_intent,
		"seat": seat,
		"src_id": src_id,
		"dst_id": dst_id,
		"lane_id": int(decision.get("lane_id", -1)),
		"decision_id": decision_id,
		"decision_tick": decision_tick,
		"execute_tick": decision_tick,
		"policy_version": policy_version,
		"plan_id": str(decision.get("plan_id", "")),
		"trigger_code": str(decision.get("trigger_code", "periodic_baseline"))
	}


static func retract(
	seat: int,
	src_id: int,
	dst_id: int,
	decision_id: int,
	decision_tick: int,
	policy_version: String,
	plan_id: String = "",
	trigger_code: String = "route_losing"
) -> Dictionary:
	if seat <= 0 or src_id <= 0 or dst_id <= 0:
		return {}
	return {
		"schema_version": 1,
		"kind": RETRACT_ROUTE,
		"route_intent": "",
		"seat": seat,
		"src_id": src_id,
		"dst_id": dst_id,
		"lane_id": -1,
		"decision_id": decision_id,
		"decision_tick": decision_tick,
		"execute_tick": decision_tick,
		"policy_version": policy_version,
		"plan_id": plan_id,
		"trigger_code": trigger_code
	}


static func fingerprint(action: Dictionary) -> String:
	return DETERMINISTIC_VARIANT.hash_variant(fingerprint_payload(action))


static func fingerprint_payload(action: Dictionary) -> Dictionary:
	return {
		"schema_version": int(action.get("schema_version", 0)),
		"policy_version": str(action.get("policy_version", "")),
		"seat": int(action.get("seat", 0)),
		"decision_id": int(action.get("decision_id", 0)),
		"decision_tick": int(action.get("decision_tick", -1)),
		"execute_tick": int(action.get("execute_tick", -1)),
		"kind": str(action.get("kind", "")),
		"route_intent": str(action.get("route_intent", "")),
		"src_id": int(action.get("src_id", -1)),
		"dst_id": int(action.get("dst_id", -1)),
		"lane_id": int(action.get("lane_id", -1))
	}

