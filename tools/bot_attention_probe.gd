# Offline diagnostic wrapper. Only the first parent call controls the match.
extends "res://scripts/bot/human_bot_policy.gd"

var counts: Dictionary = {}
var witnesses: Array[Dictionary] = []
var seen: Dictionary = {}

func choose(obs: Dictionary, memory: Dictionary, profile: Dictionary, now_ms: int) -> Dictionary:
	var before := memory.duplicate(true)
	var action := super.choose(obs, memory, profile, now_ms)
	_count("decisions")
	if not action.is_empty():
		_count("orders")
		return action
	_count("waits")
	var plan: Dictionary = memory.get("plan", {})
	var cause := "no_candidate"
	if not plan.is_empty() and not _active_route(obs, int(plan["source"]), int(plan["target"])).is_empty():
		var routine := bool(profile.get("human_review_uncontested_expansion", false)) and _uncontested_expansion(obs, plan, _threats(obs))
		if now_ms < int(plan.get("review_ms", 0)) and not routine:
			cause = "review_interval"
		elif memory.get("watching", []).size() >= 2:
			cause = "attention_full"
	elif not memory.get("watching", []).is_empty():
		cause = "remembered_targets"
	_count(cause)
	var relaxed := before.duplicate(true)
	relaxed["plan"] = {}
	relaxed["watching"] = []
	relaxed["suspended_plan"] = {}
	var alternative := super.choose(obs, relaxed, profile, now_ms)
	if not alternative.is_empty():
		_count(cause + "_with_alternative")
		var key := "%s:%s:%s:%s:%s" % [cause, plan.get("source", -1), plan.get("target", -1), alternative.get("src", -1), alternative.get("dst", -1)]
		if not seen.has(key) and witnesses.size() < 50:
			seen[key] = true
			witnesses.append({"now_ms": now_ms, "cause": cause, "observation": obs.duplicate(true),
				"memory": before, "profile": profile.duplicate(true), "alternative": alternative})
	return action

func _count(key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1
