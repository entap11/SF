class_name BotCommandGateway
extends RefCounted

const BotActionScript := preload("res://scripts/bot/bot_action.gd")

var _ops_state: Object = null
var _state: GameState = null


func bind(state_ref: GameState, ops_state_ref: Object) -> void:
	_state = state_ref
	_ops_state = ops_state_ref


func execute(action: Dictionary) -> Dictionary:
	var payload: Dictionary = canonical_payload(action)
	var result: Dictionary = {
		"ok": false,
		"reason": "unsupported_action",
		"canonical_payload": payload,
		"action_fingerprint": BotActionScript.fingerprint(action)
	}
	if _state == null or _ops_state == null:
		result["reason"] = "state_missing"
		return result
	var kind: String = str(action.get("kind", ""))
	match kind:
		BotActionScript.OPEN_ROUTE, BotActionScript.SWARM:
			var intent_result_any: Variant = _ops_state.call(
				"apply_lane_intent",
				int(action.get("src_id", -1)),
				int(action.get("dst_id", -1)),
				str(action.get("route_intent", ""))
			)
			if typeof(intent_result_any) == TYPE_DICTIONARY:
				var intent_result: Dictionary = intent_result_any as Dictionary
				for key_any in intent_result.keys():
					result[key_any] = intent_result.get(key_any)
		BotActionScript.RETRACT_ROUTE:
			return _execute_retract(action, result)
	return result


func canonical_payload(action: Dictionary) -> Dictionary:
	var kind: String = str(action.get("kind", ""))
	var seat: int = int(action.get("seat", 0))
	var execute_tick: int = int(action.get("execute_tick", -1))
	match kind:
		BotActionScript.OPEN_ROUTE, BotActionScript.SWARM:
			return {
				"kind": "lane_intent",
				"src": int(action.get("src_id", -1)),
				"dst": int(action.get("dst_id", -1)),
				"intent": str(action.get("route_intent", "")),
				"src_owner": seat,
				"sender_seat": seat,
				"issued_tick": int(action.get("decision_tick", -1)),
				"execute_tick": execute_tick
			}
		BotActionScript.RETRACT_ROUTE:
			return {
				"kind": "lane_retract",
				"from_id": int(action.get("src_id", -1)),
				"to_id": int(action.get("dst_id", -1)),
				"owner_id": seat,
				"sender_seat": seat,
				"issued_tick": int(action.get("decision_tick", -1)),
				"execute_tick": execute_tick
			}
	return {}


func _execute_retract(action: Dictionary, result: Dictionary) -> Dictionary:
	var seat: int = int(action.get("seat", 0))
	var src_id: int = int(action.get("src_id", -1))
	var dst_id: int = int(action.get("dst_id", -1))
	var src: HiveData = _state.find_hive_by_id(src_id)
	if src == null:
		result["reason"] = "missing_hive"
		return result
	if int(src.owner_id) != seat:
		result["reason"] = "ownership"
		return result
	if not _state.is_outgoing_lane_active(src_id, dst_id):
		result["reason"] = "stale_precondition"
		return result
	_ops_state.call("retract_lane", src_id, dst_id, seat)
	result["ok"] = true
	result["reason"] = ""
	return result

