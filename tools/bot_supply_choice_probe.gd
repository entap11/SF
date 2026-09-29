# Offline threshold audit. Counterfactual supply is never applied.
extends "res://scripts/bot/human_bot_policy.gd"
var counts: Dictionary = {}
var witnesses: Array[Dictionary] = []
func choose(obs: Dictionary, memory: Dictionary, profile: Dictionary, now_ms: int) -> Dictionary:
	var before := memory.duplicate(true)
	var action := super.choose(obs, memory, profile, now_ms)
	_count("decisions")
	var ordinary := _develop_supply(obs, profile, _threats(obs), now_ms)
	var lower := profile.duplicate(true)
	lower["min_feed_power"] = 10
	var supply := _develop_supply(obs, lower, _threats(obs), now_ms)
	if not supply.is_empty() and supply != ordinary:
		var kind := "waiting" if action.is_empty() else str(action.get("intent", ""))
		_count("changed_supply_" + kind)
		if ordinary.is_empty():
			_count("new_supply_" + kind)
		if witnesses.size() < 100:
			witnesses.append({"now_ms": now_ms, "observation": obs.duplicate(true),
				"memory": before, "profile": profile.duplicate(true), "action": action.duplicate(true),
				"ordinary": ordinary, "lower_threshold_supply": supply})
	return action
func _count(key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1
