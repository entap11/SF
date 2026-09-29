# Diagnostic witnesses only. The unchanged parent policy controls the match.
extends "res://scripts/bot/human_bot_policy.gd"

var witnesses: Array[Dictionary] = []
var decisions := 0

func choose(obs: Dictionary, memory: Dictionary, profile: Dictionary, now_ms: int) -> Dictionary:
	var before := memory.duplicate(true)
	var view := obs.duplicate(true)
	var action := super.choose(obs, memory, profile, now_ms)
	decisions += 1
	if now_ms <= 90000:
		witnesses.append({"now_ms": now_ms, "observation": view, "memory": before,
			"profile": profile.duplicate(true), "action": action.duplicate(true)})
	return action
