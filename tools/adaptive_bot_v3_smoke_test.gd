extends SceneTree

const BotRunnerScript := preload("res://scripts/bot/bot_runner.gd")
const OpsStateScript := preload("res://scripts/ops/ops_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	await process_frame
	_test_adaptive_policy_keeps_explicit_baseline_fallback()
	_test_losing_route_is_cut_then_capacity_is_reallocated()
	if not _failures.is_empty():
		for failure in _failures:
			push_error("ADAPTIVE_BOT_V3_SMOKE: %s" % failure)
		quit(1)
		return
	print("ADAPTIVE_BOT_V3_SMOKE: PASS")
	quit(0)


func _test_adaptive_policy_keeps_explicit_baseline_fallback() -> void:
	var state := GameState.new()
	state.load_from_map_dict({
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 2, "kind": "Hive", "power": 20},
			{"id": 2, "x": 1, "y": 0, "owner_id": 0, "kind": "Hive", "power": 4}
		],
		"lane_candidates": [{"a_id": 1, "b_id": 2}]
	})
	var ops_state := OpsStateScript.new()
	root.add_child(ops_state)
	ops_state.state = state
	ops_state.match_phase = 1
	ops_state.input_locked = false
	ops_state.match_roster = [{"seat": 2, "team_id": 2, "is_cpu": true, "active": true}]
	ops_state.set_bot_profile(2, {
		"policy": "adaptive_v3.0",
		"style": "balancer",
		"tier": "medium",
		"opening_delay_ms": 0,
		"opening_stagger_ms": 0,
		"think_interval_ms": 100,
		"think_jitter_ms": 0
	})
	var runner := BotRunnerScript.new()
	runner.bind_state(state, ops_state)
	runner.step()
	var outcome: Array[Dictionary] = runner.step()
	_assert_eq(_first_action_kind(outcome), "open_route", "adaptive v3.0 must retain an explicit proactive fallback")
	if not outcome.is_empty():
		var trace: Dictionary = (outcome[0] as Dictionary).get("trace", {}) as Dictionary
		_assert_eq(str(trace.get("fallback", "")), "baseline_v2", "fallback use must be explicit in diagnostics")
	ops_state.queue_free()


func _test_losing_route_is_cut_then_capacity_is_reallocated() -> void:
	var state := GameState.new()
	state.load_from_map_dict({
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 2, "kind": "Hive", "power": 18},
			{"id": 2, "x": 2, "y": 0, "owner_id": 1, "kind": "Hive", "power": 34},
			{"id": 3, "x": 0, "y": 2, "owner_id": 0, "kind": "Hive", "power": 4}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2},
			{"a_id": 1, "b_id": 3}
		]
	})
	var losing_lane := LaneData.new(1, 1, 2, 0, true, true, 1.0, 6.0)
	state.lanes.append(losing_lane)
	state.rebuild_indexes()

	var ops_state := OpsStateScript.new()
	root.add_child(ops_state)
	ops_state.state = state
	ops_state.match_phase = 1
	ops_state.input_locked = false
	ops_state.match_roster = [
		{"seat": 1, "team_id": 1, "is_cpu": false, "active": true},
		{"seat": 2, "team_id": 2, "is_cpu": true, "active": true}
	]
	ops_state.set_bot_match_seed(7331)
	ops_state.set_bot_profile(2, {
		"policy": "adaptive_v3.0",
		"style": "balancer",
		"tier": "medium",
		"opening_delay_ms": 0,
		"opening_stagger_ms": 0,
		"think_interval_ms": 100,
		"think_jitter_ms": 0,
		"adaptive_reaction_delay_ms": 400,
		"adaptive_reaction_jitter_ms": 0,
		"adaptive_reallocation_delay_ms": 250,
		"adaptive_losing_pressure_margin_milli": 2000
	})
	var runner := BotRunnerScript.new()
	runner.bind_state(state, ops_state)

	# First call creates the frozen runtime. Second call legally observes the loss.
	runner.step()
	var observed: Array[Dictionary] = runner.step()
	_assert_eq(str((observed[0] as Dictionary).get("outcome", "")), "defer", "loss observation must wait for human reaction time")
	_assert_true(bool(losing_lane.send_a), "bot must not retract at perception time")

	_set_sim_time(state, 399, 24)
	runner.step()
	_assert_true(bool(losing_lane.send_a), "bot must still be committed before reaction matures")
	var pending_snapshot: Dictionary = ops_state.get_authority_snapshot()

	_set_sim_time(state, 400, 25)
	var cut: Array[Dictionary] = runner.step()
	_assert_true(not bool(losing_lane.send_a), "mature losing-route reaction must retract through OpsState")
	_assert_eq(_first_action_kind(cut), "retract_route", "mature reaction must emit RETRACT_ROUTE")
	var cut_fingerprint: String = _first_action_fingerprint(cut)

	var restored_ops := OpsStateScript.new()
	root.add_child(restored_ops)
	_assert_true(restored_ops.restore_authority_snapshot(pending_snapshot), "authority snapshot must restore pending cognition")
	var restored_state: GameState = restored_ops.state
	var restored_runner := BotRunnerScript.new()
	restored_runner.bind_state(restored_state, restored_ops)
	_set_sim_time(restored_state, 400, 25)
	var restored_cut: Array[Dictionary] = restored_runner.step()
	_assert_eq(_first_action_kind(restored_cut), "retract_route", "restored reaction queue must finish the same cut")
	_assert_eq(
		_first_action_fingerprint(restored_cut),
		cut_fingerprint,
		"snapshot continuation must reproduce the same action fingerprint"
	)
	restored_ops.queue_free()

	_set_sim_time(state, 650, 40)
	var reallocated: Array[Dictionary] = runner.step()
	_assert_eq(_first_action_kind(reallocated), "open_route", "freed capacity must be reused with OPEN_ROUTE")
	_assert_true(state.is_outgoing_lane_active(1, 3), "reallocation must choose the alternate legal target")
	_assert_true(not state.is_outgoing_lane_active(1, 2), "reallocation must not immediately reopen the losing route")

	var runtime: Dictionary = runner.export_runtime_state()
	var seat_runtime: Dictionary = (runtime.get("by_seat", {}) as Dictionary).get(2, {}) as Dictionary
	_assert_true((seat_runtime.get("reaction_queue", []) as Array).is_empty(), "consumed reactions must leave the serialized queue")
	_assert_true(not bool(seat_runtime.get("reallocation_pending", true)), "successful reallocation must complete the tactical transition")
	ops_state.queue_free()


func _set_sim_time(state: GameState, milliseconds: int, tick: int) -> void:
	state.set("_sim_time_us", milliseconds * 1000)
	state.tick = tick


func _first_action_kind(outcomes: Array[Dictionary]) -> String:
	for outcome in outcomes:
		if str(outcome.get("outcome", "")) != "act":
			continue
		return str((outcome.get("action", {}) as Dictionary).get("kind", ""))
	return ""


func _first_action_fingerprint(outcomes: Array[Dictionary]) -> String:
	for outcome in outcomes:
		if str(outcome.get("outcome", "")) != "act":
			continue
		return str((outcome.get("result", {}) as Dictionary).get("action_fingerprint", ""))
	return ""


func _assert_true(value: bool, label: String) -> void:
	if not value:
		_failures.append(label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_failures.append("%s (expected %s, got %s)" % [label, str(expected), str(actual)])
