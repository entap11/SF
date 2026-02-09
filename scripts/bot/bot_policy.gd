# Authoritative bot policy interface (read-only over GameState/OpsState).
class_name BotPolicy
extends RefCounted

func choose_intent(state_ref: GameState, seat: int, profile: Dictionary, now_ms: int) -> Dictionary:
	# Return shape:
	# {"src": int, "dst": int, "intent": String, "score": float, "policy": String}
	return {}
