extends SceneTree

const PolicyScript := preload("res://scripts/bot/baseline_bot_policy.gd")
const OpsStateScript := preload("res://scripts/ops/ops_state.gd")

var _failed := false
var _checks := 0

func _init() -> void:
	await process_frame
	var ops := OpsStateScript.new()
	var policy := PolicyScript.new()
	for style in ["raider", "greedy"]:
		var profile: Dictionary = ops.call("_build_bot_profile_for_seat", 1, style, "medium")
		profile["team_by_seat"] = {1: 1, 2: 2, 3: 1, 4: 4}
		var reserve := int(profile["min_attack_power"])
		var now_ms := int(profile["opening_delay_ms"])
		var state := _board(reserve, 0)
		_check(state.can_connect(1, 2), "%s fixture has a legal neutral route" % style)
		var choice: Dictionary = policy.choose_intent(state, 1, profile, now_ms)
		_check(choice.get("intent") == "attack" and choice.get("dst") == 2,
			"%s should expand at its base reserve on a large board" % style)
		_check(policy.choose_intent(_board(reserve - 1, 0), 1, profile, now_ms).is_empty(),
			"%s still preserves its base reserve" % style)
		_check(policy.choose_intent(_board(reserve, 2), 1, profile, now_ms).is_empty(),
			"%s still waits for the larger reserve against an enemy" % style)
		var enemy_reserve := reserve + int(profile["complex_min_attack_power_bonus"])
		_check(not policy.choose_intent(_board(enemy_reserve, 2), 1, profile, now_ms).is_empty(),
			"%s can attack an enemy once its existing reserve is ready" % style)
		_check(policy.choose_intent(_board(reserve, 3), 1, profile, now_ms).is_empty(),
			"%s must not treat a teammate as a neutral or lower its feed reserve" % style)
		profile["blocked_wall_pairs"] = [[1, 2]]
		_check(policy.choose_intent(state, 1, profile, now_ms).is_empty(),
			"%s must still reject a blocked neutral route" % style)
		profile.erase("blocked_wall_pairs")
		# Turning off the new profile option reproduces the former opening wait.
		profile["neutral_uses_base_attack_power"] = false
		_check(policy.choose_intent(state, 1, profile, now_ms).is_empty(),
			"%s control reproduces the large-board opening delay" % style)
		var compact := _board(reserve, 0, 4)
		var old_compact: Dictionary = policy.choose_intent(compact, 1, profile, now_ms)
		profile["neutral_uses_base_attack_power"] = true
		_check(policy.choose_intent(compact, 1, profile, now_ms) == old_compact,
			"%s compact-board opening stays identical" % style)
	for style in ["balancer", "turtle", "raider", "greedy", "swarm_lord"]:
		for tier in ["easy", "medium", "hard"]:
			var profile: Dictionary = ops.call("_build_bot_profile_for_seat", 1, style, tier)
			var expected: bool = tier == "medium" and style in ["raider", "greedy"]
			_check(bool(profile.get("neutral_uses_base_attack_power", false)) == expected,
				"neutral expansion option is scoped correctly for %s/%s" % [style, tier])
	ops.free()
	if _failed:
		quit(1)
		return
	print("BOT_NEUTRAL_EXPANSION_SMOKE: PASS checks=%d" % _checks)
	quit(0)

# Only the home-to-target edge is offered. Remote hives reproduce the sixteen-hive
# board context without introducing alternative orders into the threshold test.
func _board(power: int, target_owner: int, size: int = 16) -> GameState:
	var hives: Array = [
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "kind": "Hive", "power": power},
		{"id": 2, "x": 4, "y": 0, "owner_id": target_owner, "kind": "Hive", "power": 5}
	]
	for id in range(3, size + 1):
		hives.append({"id": id, "x": 20 + id * 4, "y": 20,
			"owner_id": 2 if id == 3 else 0, "kind": "Hive", "power": 5})
	var state := GameState.new()
	state.load_from_map_dict({"hives": hives, "lane_candidates": [{"a_id": 1, "b_id": 2}]})
	return state

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failed = true
		push_error("BOT_NEUTRAL_EXPANSION_SMOKE: " + label)
