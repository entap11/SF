class_name BotDecision
extends RefCounted

const ACT: String = "act"
const DEFER: String = "defer"


static func act(action: Dictionary, trace: Dictionary = {}) -> Dictionary:
	return {
		"outcome": ACT,
		"action": action.duplicate(true),
		"trace": trace.duplicate(true)
	}


static func defer(trace: Dictionary = {}) -> Dictionary:
	return {
		"outcome": DEFER,
		"action": {},
		"trace": trace.duplicate(true)
	}


static func is_act(decision: Dictionary) -> bool:
	return str(decision.get("outcome", "")) == ACT

