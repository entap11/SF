extends SceneTree

const Observation := preload("res://scripts/bot/bot_observation.gd")
const HumanPolicy := preload("res://scripts/bot/human_bot_policy.gd")
const FrozenV2 := preload("res://tools/fixtures/bot/human_balancer_v2.gd")
const Command := preload("res://scripts/bot/bot_command.gd")
const Baseline := preload("res://scripts/bot/baseline_bot_policy.gd")
const Random := preload("res://scripts/bot/bot_random.gd")
const Collector := preload("res://scripts/state/match_telemetry_collector.gd")
const Model := preload("res://scripts/state/match_telemetry_model.gd")
const SimEvents := preload("res://scripts/sim/sim_events.gd")

var _ops: Node
var _bot_script: Script
var _runner_script: Script
var _failed := false
var _checks := 0

func _initialize() -> void:
	set_meta("sf_perf_harness_active", true)
	await process_frame
	_ops = root.get_node("OpsState")
	_bot_script = load("res://scripts/systems/bot_system.gd")
	_runner_script = load("res://scripts/systems/sim_runner.gd")
	_test_observation_boundary()
	_test_incoming_changes_choice()
	_test_stall_and_recovery()
	_test_defense_and_resume()
	_test_supply_sequence()
	_test_attention_moves_between_commitments()
	_test_uncontested_expansion_releases_attention()
	_test_bounded_attention_capacity()
	_test_supported_defense_does_not_panic()
	_test_donor_preserves_lane_capacity()
	_test_backline_development()
	_test_spare_capacity_supports_active_front()
	_test_supported_frontier_can_expand()
	_test_counterpressure_and_concentration()
	_test_fragile_counterattack_waits()
	_test_pilot_scope()
	_test_blocked_candidate()
	_test_timing_and_stale_actor()
	_test_snapshot_continuation()
	_test_reaction_attribution()
	await _test_structures_in_canonical_runner()
	await _test_real_simulation()
	await _test_canonical_timeout()
	if not _failed:
		print("BOT_RUNTIME_SMOKE: PASS checks=%d" % _checks)
	quit(1 if _failed else 0)

func _map() -> Dictionary:
	return {"bot_seed": 731, "hives": [
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 30, "kind": "Hive"},
		{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 8, "kind": "Hive"},
		{"id": 3, "x": 0, "y": 2, "owner_id": 1, "power": 25, "kind": "Hive"},
		{"id": 4, "x": 2, "y": 2, "owner_id": 0, "power": 5, "kind": "Hive"}],
		"lane_candidates": [{"a_id": 1, "b_id": 2}, {"a_id": 1, "b_id": 3}, {"a_id": 1, "b_id": 4}, {"a_id": 3, "b_id": 4}, {"a_id": 2, "b_id": 4}]}

func _reset(data: Dictionary = {}) -> GameState:
	var fixture := _map() if data.is_empty() else data.duplicate(true)
	# Space the policy fixtures beyond hive bodies so the intended routes are legal.
	for row in fixture["hives"]:
		row["x"] = int(row.get("x", 0)) * 4
		row["y"] = int(row.get("y", 0)) * 4
	var state: GameState = _ops.call("reset_state_from_map", fixture)
	_ops.set("match_roster", [{"seat": 1, "is_cpu": true, "active": true}, {"seat": 2, "is_cpu": false, "active": true}])
	_ops.call("set_team_mode_override", "1p")
	_ops.set("match_phase", 1)
	_ops.set("input_locked", false)
	_ops.set("match_clock_paused", false)
	_ops.call("set_bot_profile", 1, {"style": "balancer", "tier": "medium", "human_behavior_enabled": true, "opening_delay_ms": 0, "opening_stagger_ms": 0,
		"human_timing": {"notice_delay_ms": 400, "notice_jitter_ms": 0, "motor_delay_ms": 200, "motor_jitter_ms": 0, "think_interval_ms": 1100, "think_jitter_ms": 0}})
	return state

func _view(state: GameState, at_ms: int = 0) -> Dictionary:
	return Observation.capture(state, 1, {1: 1, 2: 2, 3: 3, 4: 4}, at_ms)

func _test_observation_boundary() -> void:
	var state := _reset()
	state.units_by_lane["_all"] = [{"from_id": 2, "to_id": 1, "owner_id": 2, "t": 0.2, "dir": -1, "amount": 3}]
	state.swarm_packets = [{"from_id": 2, "to_id": 1, "owner_id": 2, "t": 0.8, "dir": 1, "count": 5}]
	var view := _view(state)
	state.find_hive_by_id(2).power = 40
	state.units_by_lane["_all"][0]["amount"] = 30
	_expect(int(view["hives"]["2"]["power"]) == 8, "observation keeps the previously seen power")
	_expect(view["incoming"].size() == 2 and int(view["incoming"][0]["amount"]) == 3, "visible lane forces and swarms are copied with direction")
	_expect(view.keys().size() == 8 and not view.has("capture_flag_state") and not view.has("swarm_requests"), "observation exposes only its declared public facts")
	_expect(Random.sample(731, 1, 1, "motor") != Random.sample(732, 1, 1, "motor"), "match seed varies the deterministic timing stream")

func _test_incoming_changes_choice() -> void:
	var state := _reset({"hives": [
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 20},
		{"id": 2, "x": 2, "y": 0, "owner_id": 2, "power": 8},
		{"id": 3, "x": 0, "y": 2, "owner_id": 2, "power": 10}],
		"lane_candidates": [{"a_id": 1, "b_id": 2}, {"a_id": 1, "b_id": 3}]})
	var policy := HumanPolicy.new()
	var before := policy.choose(_view(state), {}, {}, 0)
	state.units_by_lane["_all"] = [{"from_id": 3, "to_id": 2, "owner_id": 2, "t": 0.8, "dir": 1, "amount": 25}]
	var after := policy.choose(_view(state), {}, {}, 0)
	_expect(int(before.get("dst", -1)) == 2 and int(after.get("dst", -1)) == 3, "visible reinforcements prevent attacking the deceptively weak target")

func _test_stall_and_recovery() -> void:
	var state := _reset()
	var opened: Dictionary = Command.apply(_ops, 1, {"src": 1, "dst": 2, "intent": "attack"})
	_expect(bool(opened.get("ok", false)), "fixture opens a legal lane through OpsState: %s" % opened)
	var memory := {"plan": {"goal": "pressure", "source": 1, "target": 2, "progress_ms": 0, "best_power": 8, "review_ms": 6000}}
	var policy := HumanPolicy.new()
	var decision := policy.choose(_view(state, 9000), memory, {}, 9000)
	_expect(str(decision.get("intent", "")) == "retract", "a stalled commitment produces a withdrawal")
	_expect(bool(Command.apply(_ops, 1, decision).get("ok", false)), "withdrawal uses the legal simulation command")
	var followup := policy.choose(_view(state, 10000), memory, {}, 10000)
	_expect(int(followup.get("dst", -1)) != 2 and memory.get("avoided_until", {}).has("2"), "recovery avoids immediately retrying the same failed target")

func _test_defense_and_resume() -> void:
	var state := _reset()
	state.find_hive_by_id(3).power = 4
	state.units_by_lane["_all"] = [{"from_id": 2, "to_id": 3, "owner_id": 2, "t": 0.8, "dir": 1, "amount": 14}]
	var memory := {"plan": {"goal": "pressure", "source": 1, "target": 2, "progress_ms": 0, "best_power": 8, "review_ms": 6000}}
	var policy := HumanPolicy.new()
	var defense := policy.choose(_view(state), memory, {}, 1000)
	_expect(str(defense.get("goal", "")) == "defend" and int(defense.get("dst", 0)) == 3, "incoming troops interrupt focus to reinforce the threatened hive")
	_expect(int(memory.get("suspended_plan", {}).get("target", 0)) == 2, "an interruption saves the previous plan")
	var waiting := policy.choose(_view(state), memory, {"blocked_intents_until_ms": {"1|3|feed": 5000}}, 1500)
	_expect(waiting.is_empty() and str(memory.get("plan", {}).get("goal", "")) == "defend", "a cooldown does not falsely resolve an active defense")
	state.units_by_lane["_all"] = []
	state.find_hive_by_id(3).power = 25
	var resumed := policy.choose(_view(state), memory, {}, 2000)
	_expect(int(resumed.get("dst", 0)) == 2, "the bot resumes its previous target when defense stabilizes: %s memory=%s" % [resumed, memory])
	# A saved target may have changed ownership while attention was elsewhere.
	memory = {"plan": {"goal": "defend", "source": 1, "target": 3}, "suspended_plan": {"goal": "pressure", "source": 1, "target": 2}}
	state.find_hive_by_id(2).owner_id = 1
	var stale := policy.choose(_view(state), memory, {}, 3000)
	_expect(int(stale.get("dst", 0)) != 2, "a captured target invalidates the suspended attack")

func _test_supply_sequence() -> void:
	var state := _reset()
	state.find_hive_by_id(1).power = 12
	state.find_hive_by_id(2).power = 10
	var memory := {"plan": {"goal": "pressure", "source": 1, "target": 2, "progress_ms": 0, "best_power": 10, "review_ms": 6000}}
	var policy := HumanPolicy.new()
	var supply := policy.choose(_view(state), memory, {}, 1000)
	_expect(str(supply.get("goal", "")) == "supply" and int(supply.get("src", 0)) == 3 and int(supply.get("dst", 0)) == 1, "an evenly matched attack first asks a reserve hive for supply")
	_expect(bool(Command.apply(_ops, 1, supply).get("ok", false)), "the supply route is legal")
	memory["plan"]["supply_ordered"] = true
	var attack := policy.choose(_view(state), memory, {}, 2000)
	_expect(str(attack.get("intent", "")) == "attack" and int(attack.get("src", 0)) == 1 and int(attack.get("dst", 0)) == 2, "the supply sequence continues with its planned attack")

func _test_pilot_scope() -> void:
	var state := _reset()
	var trace: Array[Dictionary] = []
	var bot := _new_bot(state, trace)
	var profile: Dictionary = _ops.call("get_bot_profile", 1)
	_expect(bool(bot.call("_human_enabled", profile)), "medium Balancer enables the pilot in two-seat conquest")
	profile["human_behavior_enabled"] = false
	_expect(not bool(bot.call("_human_enabled", profile)), "the experimental pilot requires an explicit opt-in")
	profile["human_behavior_enabled"] = true
	_ops.set("victory_mode", "capture_flag")
	_expect(not bool(bot.call("_human_enabled", profile)), "flag mode retains the baseline policy")
	_ops.set("victory_mode", "conquest")
	_ops.get("match_roster").append({"seat": 3, "active": true, "is_cpu": true})
	_expect(not bool(bot.call("_human_enabled", profile)), "multiseat matches retain the baseline policy")
	bot.free()

func _test_attention_moves_between_commitments() -> void:
	var state := _reset()
	_expect(bool(Command.apply(_ops, 1, {"src": 1, "dst": 2, "intent": "attack"}).get("ok", false)), "attention fixture opens its first commitment")
	var memory := {"plan": {"goal": "pressure", "source": 1, "target": 2, "progress_ms": 5000, "best_power": 8, "review_ms": 6000}}
	var policy := HumanPolicy.new()
	var choice := policy.choose(_view(state, 6500), memory, {"allow_swarm": false}, 6500)
	_expect(int(choice.get("dst", 0)) == 4 and memory.get("watching", []).size() == 1, "attention can open another front while a remembered order continues")
	# Revisit the remembered commitment after it stops making progress.
	memory["plan"] = {}
	var reviewed := policy.choose(_view(state, 14000), memory, {"allow_swarm": false}, 14000)
	_expect(str(reviewed.get("intent", "")) == "retract" and int(reviewed.get("dst", 0)) == 2, "a remembered front is still reviewed and withdrawn when stalled")

func _test_uncontested_expansion_releases_attention() -> void:
	var state := _reset({"hives": [
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 10},
		{"id": 2, "x": 2, "y": 0, "owner_id": 0, "power": 5},
		{"id": 3, "x": 0, "y": 2, "owner_id": 0, "power": 5},
		{"id": 4, "x": 6, "y": 4, "owner_id": 2, "power": 10}],
		"lane_candidates": [{"a_id": 1, "b_id": 2}, {"a_id": 1, "b_id": 3}, {"a_id": 4, "b_id": 2}]})
	_expect(bool(Command.apply(_ops, 1, {"src": 1, "dst": 2, "intent": "attack"}).get("ok", false)), "expansion fixture opens its first neutral route")
	var original := {"plan": {"goal": "expand", "source": 1, "target": 2, "progress_ms": 0, "best_power": 5, "review_ms": 6000}}
	var profile: Dictionary = _ops.call("get_bot_profile", 1)
	var policy := HumanPolicy.new()
	var view := _view(state, 2000)
	var before := view.duplicate(true)
	var memory := original.duplicate(true)
	var choice := policy.choose(view, memory, profile, 2000)
	_expect(choice.get("intent") == "attack" and int(choice.get("dst", 0)) == 3,
		"an uncontested expansion lets the next ordinary decision use the spare neutral route")
	_expect(memory.get("watching", []).size() == 1 and int(memory.get("plan", {}).get("target", 0)) == 3,
		"the first expansion stays watched while attention moves to the second")
	_expect(view == before and state.is_outgoing_lane_active(1, 2) and not state.is_outgoing_lane_active(1, 3),
		"planning leaves the observation and authoritative routes unchanged")
	var control := profile.duplicate(true)
	control["human_review_uncontested_expansion"] = false
	_expect(policy.choose(view, original.duplicate(true), control, 2000).is_empty(),
		"the control reproduces the six-second expansion wait")
	profile["blocked_intents_until_ms"] = {"1|3|attack": 5000}
	var blocked_choice := policy.choose(view, original.duplicate(true), profile, 2000)
	_expect(not (blocked_choice.get("intent") == "attack" and int(blocked_choice.get("dst", 0)) == 3),
		"early attention release still respects command cooldowns")
	profile.erase("blocked_intents_until_ms")
	# A visible convoy still contests the neutral after its source stops sending.
	state.units_by_lane["_all"] = [{"from_id": 4, "to_id": 2, "owner_id": 2, "t": 0.8, "amount": 5}]
	_expect(policy.choose(_view(state, 2000), original.duplicate(true), profile, 2000).is_empty(),
		"a visible rival convoy keeps the current expansion in focus")
	state.units_by_lane["_all"] = []
	_expect(bool(Command.apply(_ops, 2, {"src": 4, "dst": 2, "intent": "attack"}).get("ok", false)), "expansion fixture opens rival pressure")
	_expect(policy.choose(_view(state, 2000), original.duplicate(true), profile, 2000).is_empty(),
		"a competing enemy route keeps the current expansion in focus")

func _test_bounded_attention_capacity() -> void:
	var state := _reset({"hives": [
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 35},
		{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 50},
		{"id": 3, "x": 0, "y": 4, "owner_id": 2, "power": 50},
		{"id": 4, "x": -4, "y": 0, "owner_id": 2, "power": 50},
		{"id": 5, "x": 8, "y": 8, "owner_id": 1, "power": 10},
		{"id": 6, "x": 12, "y": 8, "owner_id": 0, "power": 5},
		{"id": 7, "x": 8, "y": 12, "owner_id": 0, "power": 5}],
		"lane_candidates": [{"a_id": 1, "b_id": 2}, {"a_id": 1, "b_id": 3}, {"a_id": 1, "b_id": 4}, {"a_id": 5, "b_id": 6}, {"a_id": 5, "b_id": 7}]})
	for target in [2, 3, 4]:
		_expect(bool(Command.apply(_ops, 1, {"src": 1, "dst": target, "intent": "attack"}).get("ok", false)), "attention fixture opens an existing commitment")
	var primary := {"goal": "pressure", "source": 1, "target": 2, "progress_ms": 6000, "best_power": 50, "review_ms": 6000}
	var original := {"plan": primary.duplicate(true), "watching": []}
	for target in [3, 4]:
		var watched := primary.duplicate(true)
		watched["target"] = target
		original["watching"].append(watched)
	var profile: Dictionary = _ops.call("get_bot_profile", 1)
	profile["human_watch_limit"] = 3
	var control := profile.duplicate(true)
	control["human_watch_limit"] = 2
	var policy := HumanPolicy.new()
	var observation := _view(state, 7000)
	var before := observation.duplicate(true)
	_expect(policy.choose(observation, original.duplicate(true), control, 7000).is_empty(), "two watched commitments reproduce the blocked expansion")
	var memory := original.duplicate(true)
	var choice := policy.choose(observation, memory, profile, 7000)
	_expect(choice.get("intent") == "attack" and int(choice.get("src", 0)) == 5 and int(choice.get("dst", 0)) == 6,
		"one additional watched commitment lets an idle hive expand after the review interval")
	_expect(memory.get("watching", []).size() == 3 and int(memory.get("plan", {}).get("target", 0)) == 6,
		"the previous commitments stay remembered alongside the new current plan")
	_expect(int(memory.get("watch_cursor", 0)) == 1, "a decision still reviews only one watched commitment")
	_expect(observation == before and not state.is_outgoing_lane_active(5, 6), "attention planning leaves observation and authoritative routes unchanged")
	_expect(bool(Command.apply(_ops, 1, choice).get("ok", false)), "the additional expansion uses the authoritative command path")
	_expect(policy.choose(_view(state, 8000), memory, profile, 8000).is_empty() and memory.get("watching", []).size() == 3,
		"three watched plans plus the current plan still block a fifth commitment")
	var bounded := memory.duplicate(true)
	profile["human_watch_limit"] = 999
	_expect(policy.choose(_view(state, 8000), bounded, profile, 8000).is_empty() and bounded.get("watching", []).size() == 3,
		"an excessive profile value cannot remove the attention bound")
	profile["human_watch_limit"] = 3
	# An emergency must still interrupt even when every attention slot is full.
	state.units_by_lane["_all"] = [{"from_id": 2, "to_id": 5, "owner_id": 2, "t": 0.8, "amount": 25}]
	_expect(policy.choose(_view(state, 9000), memory, profile, 9000).get("intent") == "retract",
		"full attention does not prevent withdrawal from an exposed source")

func _test_blocked_candidate() -> void:
	var state := _reset()
	var profile := {"team_by_seat": {1: 1, 2: 2}, "randomness": 0.0, "aggression": 1.0, "feed_bias": 0.0,
		"blocked_intents_until_ms": {"1|4|attack": 5000, "3|4|attack": 5000, "1|3|feed": 5000, "3|1|feed": 5000}}
	var choice := Baseline.new().choose_intent(state, 1, profile, 100)
	_expect(int(choice.get("src", 0)) == 1 and int(choice.get("dst", 0)) == 2, "baseline selects a legal alternative before cooldown filtering: %s" % choice)

func _test_supported_defense_does_not_panic() -> void:
	var state := _reset()
	state.find_hive_by_id(3).power = 8
	Command.apply(_ops, 1, {"src": 1, "dst": 3, "intent": "feed"})
	Command.apply(_ops, 2, {"src": 2, "dst": 3, "intent": "attack"})
	var view := _view(state)
	var policy := HumanPolicy.new()
	_expect(float(policy._threats(view).get("3", 0.0)) == 0.0, "a matched supply stream offsets ongoing hostile production")
	var memory := {"plan": {"goal": "defend", "source": 1, "target": 3}}
	var choice := policy.choose(view, memory, {}, 2000)
	_expect(str(choice.get("goal", "")) != "defend", "stable supported defense releases attention for another task")

func _test_donor_preserves_lane_capacity() -> void:
	var state := _reset()
	state.find_hive_by_id(1).power = 27
	state.find_hive_by_id(3).power = 3
	Command.apply(_ops, 1, {"src": 1, "dst": 3, "intent": "feed"})
	state.units_by_lane["_all"] = [{"from_id": 2, "to_id": 3, "owner_id": 2, "t": 0.9, "amount": 12}]
	var policy := HumanPolicy.new()
	var decision := policy._best_defense(_view(state), policy._threats(_view(state)), {}, 1000)
	_expect(decision.is_empty(), "defensive swarms preserve a donor's 25-power lane threshold")
	state.find_hive_by_id(1).power = 35
	decision = policy._best_defense(_view(state), policy._threats(_view(state)), {}, 1000)
	_expect(str(decision.get("intent", "")) == "swarm", "a donor with enough reserve can still send an urgent defensive swarm")

func _test_backline_development() -> void:
	var state := _reset({"hives": [
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50},
		{"id": 2, "x": 6, "y": 0, "owner_id": 2, "power": 50},
		{"id": 3, "x": 3, "y": 0, "owner_id": 1, "power": 15}]})
	Command.apply(_ops, 1, {"src": 3, "dst": 2, "intent": "attack"})
	var memory := {"plan": {"goal": "pressure", "source": 3, "target": 2, "progress_ms": 0, "best_power": 50, "review_ms": 6000}}
	var policy := HumanPolicy.new()
	var choice := policy.choose(_view(state), memory, {}, 1000)
	_expect(str(choice.get("goal", "")) == "develop" and int(choice.get("src", 0)) == 1 and int(choice.get("dst", 0)) == 3, "an idle backline supplies the ongoing frontline attack")
	_expect(int(memory["plan"]["target"]) == 2, "routine supply preserves the attack plan")
	Command.apply(_ops, 1, choice)
	var second := policy._develop_supply(_view(state), {}, {}, 3000)
	_expect(second.is_empty(), "development does not create a reciprocal feeding loop")

func _test_spare_capacity_supports_active_front() -> void:
	var state := _reset({"hives": [
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 35},
		{"id": 2, "x": -3, "y": 0, "owner_id": 1, "power": 45},
		{"id": 3, "x": 3, "y": 0, "owner_id": 1, "power": 15},
		{"id": 4, "x": 6, "y": 0, "owner_id": 2, "power": 50}]})
	_expect(bool(Command.apply(_ops, 1, {"src": 1, "dst": 2, "intent": "feed"}).get("ok", false)), "reserve fixture already supplies another hive")
	_expect(bool(Command.apply(_ops, 1, {"src": 3, "dst": 4, "intent": "attack"}).get("ok", false)), "reserve fixture has an active unsupported front")
	var memory := {"plan": {"goal": "pressure", "source": 3, "target": 4, "progress_ms": 0, "best_power": 50, "review_ms": 6000}}
	var view := _view(state, 1000)
	var before := JSON.stringify(view)
	_expect(FrozenV2.new().choose(view, memory.duplicate(true), {}, 1000).is_empty(), "frozen v2 reproduces the unsupported-front hesitation")
	var policy := HumanPolicy.new()
	var choice := policy.choose(view, memory, {}, 1000)
	_expect(str(choice.get("goal", "")) == "develop" and int(choice.get("src", 0)) == 1 and int(choice.get("dst", 0)) == 3, "a reserve with spare capacity reinforces an active front")
	_expect(JSON.stringify(view) == before and not state.is_outgoing_lane_active(1, 3), "planning support leaves observation and gameplay unchanged")
	_expect(int(memory["plan"]["target"]) == 4 and int(memory["plan"]["review_ms"]) == 6000, "routine support retains the current focus and review deadline")
	# The spare route is not a mandate to fill every lane: it needs an active front.
	Command.apply(_ops, 1, {"src": 3, "dst": 4, "intent": "retract"})
	_expect(policy._develop_supply(_view(state), {}, {}, 1000).is_empty(), "a busy reserve does not add routine supply to an inactive front")
	Command.apply(_ops, 1, {"src": 3, "dst": 4, "intent": "attack"})
	_expect(policy._develop_supply(_view(state), {}, {"1": 8.0}, 1000).is_empty(), "a threatened reserve keeps its spare capacity")
	_expect(policy._develop_supply(_view(state), {"blocked_intents_until_ms": {"1|3|feed": 2000}}, {}, 1000).is_empty(), "spare supply respects known command cooldowns")
	state.find_hive_by_id(1).power = 9
	_expect(policy._develop_supply(_view(state), {}, {}, 1000).is_empty(), "a depleted reserve cannot use nonexistent lane capacity")
	state.find_hive_by_id(1).power = 35
	_expect(bool(Command.apply(_ops, 1, choice).get("ok", false)), "spare supply executes through the authoritative command path")
	_expect(state.is_outgoing_lane_active(1, 2) and state.is_outgoing_lane_active(1, 3) and state.is_outgoing_lane_active(3, 4), "reinforcement preserves the existing supply and attack routes")
	_expect(policy._develop_supply(_view(state), {}, {}, 3000).is_empty(), "the next review does not duplicate supply or circulate it back")

func _test_supported_frontier_can_expand() -> void:
	var state := _reset({"hives": [
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 30},
		{"id": 2, "x": 8, "y": 0, "owner_id": 2, "power": 50},
		{"id": 3, "x": 3, "y": 0, "owner_id": 1, "power": 4},
		{"id": 4, "x": 5, "y": 0, "owner_id": 0, "power": 5}]})
	Command.apply(_ops, 1, {"src": 1, "dst": 3, "intent": "feed"})
	var choice := HumanPolicy.new().choose(_view(state), {}, {}, 1000)
	_expect(int(choice.get("src", 0)) == 3 and int(choice.get("dst", 0)) == 4 and str(choice.get("intent", "")) == "attack", "a supplied low-power frontier can open a nearby neutral route")

func _test_counterpressure_and_concentration() -> void:
	var state := _reset()
	Command.apply(_ops, 1, {"src": 1, "dst": 2, "intent": "attack"})
	Command.apply(_ops, 2, {"src": 2, "dst": 1, "intent": "attack"})
	var memory := {"plan": {"goal": "pressure", "source": 1, "target": 2, "progress_ms": 0, "best_power": 8, "review_ms": 6000}}
	var choice := HumanPolicy.new().choose(_view(state), memory, {"allow_swarm": false}, 9000)
	_expect(str(choice.get("intent", "")) != "retract", "a matched counterstream is not withdrawn merely because enemy power holds steady")
	state.find_hive_by_id(2).power = 25
	# Give the second attacker enough reserve to open directly, without first
	# asking for supply (which is covered separately by the supply-sequence test).
	state.find_hive_by_id(3).power = 35
	state.find_hive_by_id(4).owner_id = 1
	memory = {"watching": [{"goal": "pressure", "source": 1, "target": 2, "progress_ms": 0, "best_power": 25}]}
	choice = HumanPolicy.new().choose(_view(state), memory, {"allow_swarm": false}, 1000)
	_expect(str(choice.get("intent", "")) == "attack" and int(choice.get("dst", 0)) == 2 and int(choice.get("src", 0)) != 1, "another source can concentrate pressure on a remembered enemy target")

func _test_fragile_counterattack_waits() -> void:
	var state := _reset({"hives": [
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 1},
		{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 30}]})
	Command.apply(_ops, 2, {"src": 2, "dst": 1, "intent": "attack"})
	var policy := HumanPolicy.new()
	var choice := policy.choose(_view(state), {}, {}, 1000)
	_expect(choice.is_empty(), "a precarious contested capture waits instead of preparing a futile delayed counterattack")
	state.find_hive_by_id(1).power = 4
	choice = policy.choose(_view(state), {}, {}, 2000)
	_expect(str(choice.get("intent", "")) == "attack" and int(choice.get("dst", 0)) == 2, "a small reserve permits a counterattack despite the enemy's higher power")

func _new_bot(state: GameState, trace: Array[Dictionary]) -> Node:
	var bot: Node = _bot_script.new()
	root.add_child(bot)
	bot.call("bind_state", state)
	bot.connect("decision_event", func(event: Dictionary) -> void: trace.append(event.duplicate(true)))
	return bot

func _at(bot: Node, state: GameState, at_ms: int) -> void:
	state._sim_time_us = at_ms * 1000
	state.tick = int(at_ms / 100)
	bot.call("tick", 0.1)

func _test_timing_and_stale_actor() -> void:
	var state := _reset()
	var trace: Array[Dictionary] = []
	var bot := _new_bot(state, trace)
	_at(bot, state, 0)
	_expect(_events(trace, "observed").size() == 1 and _events(trace, "scheduled").is_empty(), "first glance never executes an immediate action")
	_at(bot, state, 300)
	_expect(_events(trace, "scheduled").is_empty(), "notice delay is a real gate")
	_at(bot, state, 400)
	var scheduled := _events(trace, "scheduled")
	_expect(scheduled.size() == 1 and _events(trace, "applied").is_empty(), "a noticed opportunity still waits for motor delay")
	if not scheduled.is_empty():
		state.find_hive_by_id(int(scheduled[0]["src"])).owner_id = 2
	_at(bot, state, 600)
	_expect(_events(trace, "applied").is_empty() and _events(trace, "rejected").size() == 1, "ownership is rechecked when a delayed action executes")
	var runtime_before := JSON.stringify(_ops.get("bot_runtime_by_seat"))
	_ops.set("match_clock_paused", true)
	_at(bot, state, 50000)
	_expect(JSON.stringify(_ops.get("bot_runtime_by_seat")) == runtime_before, "paused matches cannot advance bot cognition")
	bot.free()

func _test_snapshot_continuation() -> void:
	var state := _reset()
	var trace: Array[Dictionary] = []
	var bot := _new_bot(state, trace)
	_at(bot, state, 0)
	_at(bot, state, 400)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(_ops.call("get_authority_snapshot")))
	trace.clear()
	_at(bot, state, 600)
	var expected := JSON.stringify(trace)
	var expected_hash: String = _ops.call("get_contract_state_hash")
	bot.free()
	_expect(bool(_ops.call("restore_authority_snapshot", snapshot)), "serialized authority snapshot restores")
	trace.clear()
	bot = _new_bot(_ops.get("state"), trace)
	_at(bot, _ops.get("state"), 600)
	_expect(JSON.stringify(trace) == expected, "a restored pending bot command emits the same trace without rescheduling")
	_expect(str(_ops.call("get_contract_state_hash")) == expected_hash, "restored command yields the same gameplay state")
	bot.free()

func _events(trace: Array[Dictionary], kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event in trace:
		if str(event.get("event", "")) == kind:
			out.append(event)
	return out

func _test_reaction_attribution() -> void:
	var collector := Collector.new()
	var players: Array[int] = [1, 2]
	collector.begin_match("bot_reactions", "test", "fixture", Model.MATCH_TYPE_BOT, players, 0, {})
	collector.record_action_event(1000, 2, "lane_open_attack", {"src": 2, "dst": 1, "dst_owner": 1})
	collector.record_action_event(1100, 1, "lane_open_attack", {"src": 8, "dst": 9, "dst_owner": 0})
	collector.record_action_event(2400, 1, "lane_open_feed", {"src": 3, "dst": 1, "dst_owner": 1})
	collector.record_action_event(5000, 2, "lane_open_attack", {"src": 2, "dst": 3, "dst_owner": 1})
	collector.record_action_event(19500, 2, "lane_open_attack", {"src": 2, "dst": 4, "dst_owner": 1})
	var payload: Dictionary = collector.finalize_match(0, 20000).to_dict()
	var reaction: Dictionary = payload["metrics"]["reaction_observations"]
	_expect(is_equal_approx(float(reaction["median_by_player"][1]), 1.4), "unrelated actions are excluded from threat-response latency")
	_expect(int(reaction["samples_by_player"][1]) == 1, "only relevant responses count")
	_expect(int(reaction["unanswered_by_player"][1]) == 1, "unanswered threats remain represented")
	_expect(int(reaction["censored_by_player"][1]) == 1, "a match ending before the response window is reported separately")
	collector.begin_match("bot_team_reactions", "test", "fixture", Model.MATCH_TYPE_BOT, players, 0, {"players": [{"seat": 1, "team_id": 1}, {"seat": 2, "team_id": 1}]})
	collector.record_action_event(1000, 2, "swarm_send", {"src": 2, "dst": 1, "dst_owner": 1})
	payload = collector.finalize_match(0, 20000).to_dict()
	reaction = payload["metrics"]["reaction_observations"]
	_expect(int(reaction["unanswered_by_player"][1]) == 0, "teammate swarms are not classified as hostile threats")

func _test_structures_in_canonical_runner() -> void:
	var data := _map()
	data["hives"].append({"id": 5, "x": 2, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"})
	for row in data["hives"]:
		if int(row["owner_id"]) == 1:
			row["power"] = 50
	data["towers"] = [{"id": 10, "x": 2, "y": 2, "control_hive_ids": [1, 3, 5], "required_hive_ids": [1, 3, 5]}]
	data["barracks"] = [{"id": 20, "x": 2, "y": 2, "control_hive_ids": [1, 3, 5], "required_hive_ids": [1, 3, 5]}]
	var state := _reset(data)
	_ops.call("set_bot_profile", 1, {"enabled": false})
	var runner: Node = _runner_script.new()
	runner.set("autostart_on_bind", false)
	runner.set("scene_structure_binding_enabled", false)
	root.add_child(runner)
	runner.set_process(false)
	runner.call("bind_state", state)
	runner.call("enable_deterministic_clock", 0)
	for tick_index in range(100):
		runner.call("step_canonical")
	var tower_control: Dictionary = runner.get("tower_system").get("tower_control_ms")
	var barracks_control: Dictionary = runner.get("barracks_system").get("barracks_control_ms")
	_expect(int(state.towers[0].get("owner_id", 0)) == 1 and float(tower_control.get(1, 0.0)) > 0.0, "canonical structure control and tower systems advance")
	_expect(float(barracks_control.get(1, 0.0)) > 0.0 and runner.get("unit_system").get("units").size() > 0, "canonical barracks produce actual units")
	var events := SimEvents.new()
	var combat := {"fires": 0, "hits": 0}
	events.connect("tower_fire", func(_tower: int, _owner: int, _tier: int, _origin: Vector2, _unit: int, _target: Vector2) -> void: combat["fires"] += 1)
	events.connect("tower_hit", func(_tower: int, _owner: int, _tier: int, _origin: Vector2, _unit: int, _target: Vector2) -> void: combat["hits"] += 1)
	runner.get("tower_system").call("set_sim_events", events)
	runner.get("unit_system").call("set_sim_events", events)
	_expect(bool(Command.apply(_ops, 2, {"src": 2, "dst": 3, "intent": "attack"}).get("ok", false)), "tower fixture opens a real hostile lane")
	for tick_index in range(200):
		runner.call("step_canonical")
	_expect(int(combat["fires"]) > 0 and int(combat["hits"]) > 0, "canonical tower fire resolves real projectile hits on moving enemies: %s" % combat)
	state.unit_system = null
	runner.free()
	events.free()
	await process_frame

func _run_canonical(yield_every: int) -> Dictionary:
	var state := _reset()
	# Keep both sides alive long enough to exercise movement and bot memory.
	state.find_hive_by_id(2).power = 50
	var runner: Node = _runner_script.new()
	runner.set("autostart_on_bind", false)
	runner.set("scene_structure_binding_enabled", false)
	root.add_child(runner)
	runner.set_process(false)
	runner.call("bind_state", state)
	runner.call("enable_deterministic_clock", 0)
	var trace: Array[Dictionary] = []
	var bot: Node = runner.get("bot_system")
	bot.connect("decision_event", func(event: Dictionary) -> void: trace.append(event.duplicate(true)))
	var swarm_ok := Command.apply(_ops, 1, {"src": 1, "dst": 2, "intent": "attack"})
	_expect(bool(swarm_ok.get("ok", false)), "canonical fixture opens an attack")
	swarm_ok = Command.apply(_ops, 1, {"src": 1, "dst": 2, "intent": "swarm"})
	_expect(bool(swarm_ok.get("ok", false)), "canonical fixture queues a swarm")
	var max_packets := 0
	var max_units := 0
	var initial_power := int(state.find_hive_by_id(1).power)
	var drained := false
	for tick_index in range(300):
		if int(_ops.get("match_phase")) != 1:
			break
		runner.call("step_canonical")
		max_packets = maxi(max_packets, state.swarm_packets.size())
		max_units = maxi(max_units, int(runner.get("unit_system").get("units").size()))
		if tick_index == 0:
			drained = int(state.find_hive_by_id(1).power) < initial_power
		if yield_every > 0 and tick_index % yield_every == 0:
			await process_frame
	var result := {"trace": trace, "hash": _ops.call("get_contract_state_hash"), "runtime": JSON.stringify(_ops.get("bot_runtime_by_seat")), "packets": max_packets, "units": max_units, "drained": drained}
	state.unit_system = null
	runner.free()
	await process_frame
	return result

func _test_real_simulation() -> void:
	var fast: Dictionary = await _run_canonical(0)
	var interleaved: Dictionary = await _run_canonical(7)
	_expect(int(fast["packets"]) > 0 and bool(fast["drained"]), "production SwarmSystem creates packets and consumes hive power")
	_expect(int(fast["units"]) > 0, "production UnitSystem emits and moves real units")
	_expect(_events(fast["trace"], "applied").size() > 0, "production BotSystem acts in the canonical runner")
	_expect(JSON.stringify(fast["trace"]) == JSON.stringify(interleaved["trace"]), "same seed produces the same bot trace across frame cadence")
	_expect(fast["hash"] == interleaved["hash"] and fast["runtime"] == interleaved["runtime"], "same seed and commands reproduce gameplay and bot memory")

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failed = true
		push_error("BOT_RUNTIME_SMOKE: " + message)

func _test_canonical_timeout() -> void:
	var state := _reset({"hives": [{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50}, {"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 50}]})
	_ops.call("set_bot_profile", 1, {"enabled": false})
	var runner: Node = _runner_script.new()
	runner.set("autostart_on_bind", false)
	runner.set("scene_structure_binding_enabled", false)
	root.add_child(runner)
	runner.set_process(false)
	runner.call("bind_state", state)
	runner.call("enable_deterministic_clock", 0)
	for tick_index in range(3700):
		if int(_ops.get("match_phase")) != 1:
			break
		runner.call("step_canonical")
	_expect(int(_ops.get("match_phase")) != 1 and str(_ops.get("match_end_reason")) == "time", "canonical timeout ends a full regulation/overtime match")
	_expect(int(_ops.get("match_elapsed_ms")) == int(_ops.get("match_duration_ms")), "wall-clock deadline cannot end a canonical match early")
	_expect(int(_ops.get("match_duration_ms")) == 360000, "tied standard match retains its production overtime rule")
	state.unit_system = null
	runner.free()
	await process_frame
