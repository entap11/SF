extends SceneTree

const BotActionScript := preload("res://scripts/bot/bot_action.gd")
const BotCommandGatewayScript := preload("res://scripts/bot/bot_command_gateway.gd")
const BotEventDetectorScript := preload("res://scripts/bot/bot_event_detector.gd")
const BotObservationBuilderScript := preload("res://scripts/bot/bot_observation_builder.gd")
const BotRunnerScript := preload("res://scripts/bot/bot_runner.gd")
const BotSystemScript := preload("res://scripts/systems/bot_system.gd")
const DeterministicVariantScript := preload("res://scripts/util/deterministic_variant.gd")
const MapLoaderScript := preload("res://scripts/maps/map_loader.gd")
const OpsStateScript := preload("res://scripts/ops/ops_state.gd")

const FIXED_STEP_MS: int = 100
const FINAL_TICK: int = 14
const LOSS_EVENT_TICK: int = 3
const EXPECTED_REACTION_DELAY_MS: int = 400
const DEFAULT_MAX_OBSERVATION_AVG_US: float = 500.0
const DEFAULT_MAX_OBSERVATION_CALL_US: int = 5000

var _failures: Array[String] = []
var _metrics: Dictionary = {}


func _init() -> void:
	await process_frame
	_test_source_authority_contract()
	_test_repeat_seed_and_collection_determinism()
	_test_render_cadence_independence()
	_test_production_runner_parity()
	_test_snapshot_continuation()
	_test_hidden_information_isolation()
	_test_illegal_action_rejection()
	_test_runtime_bounds()
	_test_shadow_rollout_configuration()
	_test_shadow_mode_is_non_authoritative()
	_test_observation_performance_ceiling()
	if not _failures.is_empty():
		for failure in _failures:
			push_error("BOT_V3_CERTIFICATION: %s" % failure)
		print("BOT_V3_CERTIFICATION: FAIL failures=%d metrics=%s" % [
			_failures.size(),
			JSON.stringify(_metrics)
		])
		quit(1)
		return
	print("BOT_V3_CERTIFICATION: PASS metrics=%s" % JSON.stringify(_metrics))
	quit(0)


func _test_source_authority_contract() -> void:
	var dir := DirAccess.open("res://scripts/bot")
	_assert_true(dir != null, "bot source directory must be readable")
	if dir == null:
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if not dir.current_is_dir() and name.ends_with(".gd"):
			files.append(name)
	dir.list_dir_end()
	files.sort()
	var forbidden_nondeterminism := ["Time.get_ticks", "randf(", "randi(", "randomize("]
	var forbidden_mutations := [
		".owner_id =", ".power =", ".send_a =", ".send_b =",
		"state.hives =", "state.lanes =", "state.units ="
	]
	for name in files:
		var path := "res://scripts/bot/%s" % name
		var file := FileAccess.open(path, FileAccess.READ)
		_assert_true(file != null, "bot source must open: %s" % name)
		if file == null:
			continue
		var source: String = file.get_as_text()
		file.close()
		for token in forbidden_nondeterminism:
			_assert_true(source.find(token) == -1, "%s must not use nondeterministic token %s" % [name, token])
		for token in forbidden_mutations:
			_assert_true(source.find(token) == -1, "%s must not directly mutate gameplay via %s" % [name, token])
		if name != "bot_command_gateway.gd":
			_assert_true(source.find("apply_lane_intent") == -1, "%s must not bypass BotCommandGateway" % name)
			_assert_true(source.find("retract_lane") == -1, "%s must not bypass BotCommandGateway" % name)


func _test_repeat_seed_and_collection_determinism() -> void:
	for seed in [17, 7331, 99173]:
		var first: Dictionary = _run_timeline(seed, 16667, false, false)
		var repeated: Dictionary = _run_timeline(seed, 16667, false, false)
		_assert_eq(first.get("actions", []), repeated.get("actions", []), "seed %d must repeat its action stream" % seed)
		_assert_eq(first.get("state_hash", ""), repeated.get("state_hash", ""), "seed %d must repeat final gameplay hash" % seed)
		_assert_eq(first.get("runtime_hash", ""), repeated.get("runtime_hash", ""), "seed %d must repeat final cognition hash" % seed)
	var ordered: Dictionary = _run_timeline(7331, 16667, false, false)
	var reordered: Dictionary = _run_timeline(7331, 16667, false, true)
	_assert_eq(ordered.get("actions", []), reordered.get("actions", []), "equivalent collection ordering must not alter commands")
	_assert_eq(ordered.get("state_hash", ""), reordered.get("state_hash", ""), "equivalent collection ordering must not alter gameplay")


func _test_render_cadence_independence() -> void:
	var at_60: Dictionary = _run_timeline(7331, 16667, false, false)
	var at_30: Dictionary = _run_timeline(7331, 33333, false, false)
	var headless: Dictionary = _run_timeline(7331, 100000, false, false)
	_assert_eq(at_60.get("actions", []), at_30.get("actions", []), "30 FPS and 60 FPS pumps must emit identical commands")
	_assert_eq(at_60.get("actions", []), headless.get("actions", []), "headless and rendered pumps must emit identical commands")
	_assert_eq(at_60.get("state_hash", ""), at_30.get("state_hash", ""), "30 FPS and 60 FPS pumps must finish identically")
	_assert_eq(at_60.get("state_hash", ""), headless.get("state_hash", ""), "headless pump must finish identically")
	var actions: Array = at_60.get("actions", []) as Array
	var retract_tick: int = _action_tick(actions, "retract_route")
	var reallocate_tick: int = _action_tick(actions, "open_route")
	_assert_true(retract_tick >= LOSS_EVENT_TICK + int(ceil(float(EXPECTED_REACTION_DELAY_MS) / FIXED_STEP_MS)), "retract must respect the configured reaction delay")
	_assert_true(reallocate_tick > retract_tick, "reallocation must occur after retract")


func _test_production_runner_parity() -> void:
	var direct: Dictionary = _run_timeline(7331, 16667, false, false)
	var production: Dictionary = _run_timeline(7331, 16667, true, false)
	_assert_eq(direct.get("actions", []), production.get("actions", []), "BotSystem and direct BotRunner must emit identical streams")
	_assert_eq(direct.get("state_hash", ""), production.get("state_hash", ""), "BotSystem and BotRunner must finish identically")


func _test_snapshot_continuation() -> void:
	var fixture: Dictionary = _new_fixture(7331, false, "adaptive_v3.0")
	var state: GameState = fixture.get("state") as GameState
	var ops: Node = fixture.get("ops") as Node
	var runner := BotRunnerScript.new()
	runner.bind_state(state, ops)
	var uninterrupted_suffix: Array[Dictionary] = []
	var snapshot: Dictionary = {}
	for tick in range(FINAL_TICK + 1):
		_prepare_fixture_tick(state, tick)
		var outcomes: Array[Dictionary] = runner.step()
		if tick == 5:
			snapshot = ops.call("get_authority_snapshot") as Dictionary
		if tick > 5:
			_append_actions(uninterrupted_suffix, outcomes, tick)
	var uninterrupted_state_hash: String = str(ops.call("get_contract_state_hash"))
	var uninterrupted_runtime_hash: String = str(runner.export_runtime_state().get("runtime_hash", ""))

	var restored_ops := OpsStateScript.new()
	root.add_child(restored_ops)
	_assert_true(restored_ops.restore_authority_snapshot(snapshot), "tick-K authority snapshot must restore")
	restored_ops.input_locked = false
	var restored_state: GameState = restored_ops.state
	var restored_runner := BotRunnerScript.new()
	restored_runner.bind_state(restored_state, restored_ops)
	var restored_suffix: Array[Dictionary] = []
	for tick in range(6, FINAL_TICK + 1):
		_prepare_fixture_tick(restored_state, tick, false)
		_append_actions(restored_suffix, restored_runner.step(), tick)
	_assert_eq(uninterrupted_suffix, restored_suffix, "snapshot continuation must reproduce remaining commands")
	_assert_eq(uninterrupted_state_hash, str(restored_ops.get_contract_state_hash()), "snapshot continuation must reproduce gameplay hash")
	_assert_eq(uninterrupted_runtime_hash, str(restored_runner.export_runtime_state().get("runtime_hash", "")), "snapshot continuation must reproduce cognition hash")
	restored_ops.free()
	ops.free()


func _test_hidden_information_isolation() -> void:
	var left := _visibility_state(12)
	var right := _visibility_state(47)
	var ops := OpsStateScript.new()
	root.add_child(ops)
	ops.set_victory_mode("ctf", {"hidden_flag": true, "hide_opponent_power": true})
	ops.match_roster = [
		{"seat": 1, "team_id": 1, "active": true},
		{"seat": 2, "team_id": 2, "active": true}
	]
	var builder := BotObservationBuilderScript.new()
	var left_observation: Dictionary = builder.build(left, 1, ops)
	var right_observation: Dictionary = builder.build(right, 1, ops)
	_assert_eq(
		DeterministicVariantScript.hash_variant(left_observation),
		DeterministicVariantScript.hash_variant(right_observation),
		"hidden opponent-only changes must not alter legal observation"
	)
	ops.free()


func _test_illegal_action_rejection() -> void:
	var fixture: Dictionary = _new_fixture(7331, false, "adaptive_v3.0")
	var state: GameState = fixture.get("state") as GameState
	var ops: Node = fixture.get("ops") as Node
	var gateway := BotCommandGatewayScript.new()
	gateway.bind(state, ops)
	var illegal: Dictionary = BotActionScript.retract(1, 1, 2, 1, 0, "adaptive_v3.0")
	var result: Dictionary = gateway.execute(illegal)
	_assert_true(not bool(result.get("ok", false)), "wrong-seat retract must be rejected")
	_assert_eq(str(result.get("reason", "")), "ownership", "illegal retract must report ownership")
	_assert_true(state.is_outgoing_lane_active(1, 2), "rejected action must not mutate its lane")
	ops.free()


func _test_runtime_bounds() -> void:
	var runner := BotRunnerScript.new()
	var runtime: Dictionary = {"reaction_queue": []}
	var events: Array[Dictionary] = []
	for event_id in range(1, 101):
		events.append({
			"event_id": event_id,
			"kind": BotEventDetectorScript.ROUTE_BECAME_LOSING,
			"observed_time_ms": 0
		})
	runner.call("_enqueue_reactions", runtime, {
		"seat": 2,
		"policy": "adaptive_v3.0",
		"tier": "medium",
		"adaptive_reaction_delay_ms": 400,
		"adaptive_reaction_jitter_ms": 0
	}, events)
	_assert_eq((runtime.get("reaction_queue", []) as Array).size(), 64, "reaction queue must be bounded")
	var cooldowns: Dictionary = {}
	for index in range(300):
		cooldowns["cooldown_%03d" % index] = index
	var bounded: Dictionary = runner.call("_bounded_cooldowns", cooldowns) as Dictionary
	_assert_eq(bounded.size(), 192, "failed-intent memory must be bounded")


func _test_shadow_rollout_configuration() -> void:
	_assert_true(
		bool(ProjectSettings.get_setting("swarmfront/bots/adaptive_shadow_enabled", false)),
		"normal Arena matches must have adaptive shadow collection enabled"
	)


func _test_shadow_mode_is_non_authoritative() -> void:
	var fixture: Dictionary = _new_fixture(7331, false, "baseline_v2")
	var state: GameState = fixture.get("state") as GameState
	var ops: Node = fixture.get("ops") as Node
	ops.call("set_bot_adaptive_shadow_enabled", true)
	ops.set("_bot_telemetry_store", null)
	ops.call("record_bot_shadow_session", "match_start", {"human_seat": 1})
	var system: Node = BotSystemScript.new()
	root.add_child(system)
	system.call("bind_state", state, ops)
	for tick in range(9):
		_prepare_fixture_tick(state, tick)
		system.call("tick", 0.1)
	var before_actual_only: int = (ops.call("get_bot_shadow_events_snapshot") as Array).size()
	var no_shadow: Array[Dictionary] = []
	var actual_only: Array[Dictionary] = [{"outcome": "act", "seat": 2}]
	ops.call("record_bot_shadow_outcomes", no_shadow, actual_only)
	_assert_eq(
		(ops.call("get_bot_shadow_events_snapshot") as Array).size(),
		before_actual_only + 1,
		"shadow evidence must retain authoritative-only decisions"
	)
	ops.call("record_bot_shadow_session", "match_end", {"human_seat": 1, "winner_id": 1})
	_assert_true(state.is_outgoing_lane_active(1, 2), "shadow retract must not mutate authoritative gameplay")
	var events: Array[Dictionary] = ops.call("get_bot_shadow_events_snapshot") as Array[Dictionary]
	var found_shadow_retract: bool = false
	var found_match_start: bool = false
	var found_match_end: bool = false
	for event in events:
		_assert_eq(int(event.get("schema_version", 0)), 2, "shadow evidence must use the correlated schema")
		_assert_true(not str(event.get("match_id", "")).is_empty(), "shadow evidence must carry the intent telemetry match id")
		found_match_start = found_match_start or str(event.get("event_type", "")) == "match_start"
		found_match_end = found_match_end or str(event.get("event_type", "")) == "match_end"
		for outcome_any in event.get("shadow_outcomes", []) as Array:
			var outcome: Dictionary = outcome_any as Dictionary
			var action: Dictionary = outcome.get("action", {}) as Dictionary
			var result: Dictionary = outcome.get("result", {}) as Dictionary
			if str(action.get("kind", "")) == "retract_route" and bool(result.get("shadow_only", false)):
				found_shadow_retract = true
	_assert_true(found_match_start, "shadow evidence must bracket each normal match with match_start")
	_assert_true(found_match_end, "shadow evidence must bracket each normal match with match_end")
	_assert_true(found_shadow_retract, "shadow mode must record the adaptive retract it would have made")
	var authority_runtime: Dictionary = ops.call("get_bot_runtime_snapshot") as Dictionary
	var seat_runtime: Dictionary = (authority_runtime.get("by_seat", {}) as Dictionary).get(2, {}) as Dictionary
	_assert_eq(str(seat_runtime.get("policy_version", "")), "baseline_v2", "shadow cognition must not replace authoritative cognition")
	system.free()
	ops.free()


func _test_observation_performance_ceiling() -> void:
	var loaded: Dictionary = MapLoaderScript.load_map("res://maps/_future/centerstrike/MAP_centerstrike__CS2__4p.json")
	_assert_true(bool(loaded.get("ok", false)), "performance fixture map must load")
	if not bool(loaded.get("ok", false)):
		return
	var state := GameState.new()
	state.load_from_map_dict(loaded.get("data", {}) as Dictionary)
	var ops := OpsStateScript.new()
	root.add_child(ops)
	ops.state = state
	var builder := BotObservationBuilderScript.new()
	var detector := BotEventDetectorScript.new()
	var profile := {"adaptive_losing_pressure_margin_milli": 2000, "adaptive_losing_power_margin": 6}
	var iterations: int = 300
	var total_us: int = 0
	var max_call_us: int = 0
	var previous: Dictionary = {}
	for index in range(iterations):
		var started_us: int = Time.get_ticks_usec()
		var observation: Dictionary = builder.build(state, 1, ops)
		detector.detect(previous, observation, profile, 1)
		var elapsed_us: int = maxi(0, Time.get_ticks_usec() - started_us)
		total_us += elapsed_us
		max_call_us = maxi(max_call_us, elapsed_us)
		previous = observation
	var average_us: float = float(total_us) / float(iterations)
	var average_ceiling: float = _float_env("SF_BOT_V3_MAX_OBSERVE_AVG_US", DEFAULT_MAX_OBSERVATION_AVG_US)
	var call_ceiling: int = int(_float_env("SF_BOT_V3_MAX_OBSERVE_CALL_US", DEFAULT_MAX_OBSERVATION_CALL_US))
	_metrics["observation_iterations"] = iterations
	_metrics["observation_average_us"] = snappedf(average_us, 0.01)
	_metrics["observation_max_call_us"] = max_call_us
	_metrics["observation_average_ceiling_us"] = average_ceiling
	_metrics["observation_call_ceiling_us"] = call_ceiling
	_assert_true(average_us <= average_ceiling, "observation average %.2f us exceeds %.2f us ceiling" % [average_us, average_ceiling])
	_assert_true(max_call_us <= call_ceiling, "observation max %d us exceeds %d us ceiling" % [max_call_us, call_ceiling])
	ops.free()


func _run_timeline(seed: int, render_frame_us: int, use_bot_system: bool, reverse_collections: bool) -> Dictionary:
	var fixture: Dictionary = _new_fixture(seed, reverse_collections, "adaptive_v3.0")
	var state: GameState = fixture.get("state") as GameState
	var ops: Node = fixture.get("ops") as Node
	var runner: RefCounted = null
	var system: Node = null
	if use_bot_system:
		system = BotSystemScript.new()
		root.add_child(system)
		system.call("bind_state", state, ops)
	else:
		runner = BotRunnerScript.new()
		runner.call("bind_state", state, ops)
	var actions: Array[Dictionary] = []
	var accumulator_us: int = 0
	var sim_tick: int = 0
	while sim_tick <= FINAL_TICK:
		accumulator_us += render_frame_us
		while accumulator_us >= FIXED_STEP_MS * 1000 and sim_tick <= FINAL_TICK:
			_prepare_fixture_tick(state, sim_tick)
			var outcomes: Array[Dictionary] = []
			if use_bot_system:
				system.call("tick", 0.1)
				outcomes = system.call("get_last_outcomes") as Array[Dictionary]
			else:
				outcomes = runner.call("step") as Array[Dictionary]
			_append_actions(actions, outcomes, sim_tick)
			sim_tick += 1
			accumulator_us -= FIXED_STEP_MS * 1000
	var runtime: Dictionary = system.call("export_runtime_state") as Dictionary if use_bot_system else runner.call("export_runtime_state") as Dictionary
	var result := {
		"actions": actions,
		"state_hash": str(ops.call("get_contract_state_hash")),
		"runtime_hash": str(runtime.get("runtime_hash", ""))
	}
	if system != null:
		system.free()
	ops.free()
	return result


func _new_fixture(seed: int, reverse_collections: bool, policy_version: String) -> Dictionary:
	var state := GameState.new()
	var hives: Array = [
		{"id": 1, "x": 0, "y": 0, "owner_id": 2, "kind": "Hive", "power": 9},
		{"id": 2, "x": 2, "y": 0, "owner_id": 1, "kind": "Hive", "power": 20},
		{"id": 3, "x": 0, "y": 2, "owner_id": 0, "kind": "Hive", "power": 1}
	]
	var candidates: Array = [{"a_id": 1, "b_id": 2}, {"a_id": 1, "b_id": 3}]
	if reverse_collections:
		hives.reverse()
		candidates.reverse()
	state.load_from_map_dict({"hives": hives, "lane_candidates": candidates})
	state.lanes.append(LaneData.new(1, 1, 2, 0, true, false, 1.0, 0.0))
	state.rebuild_indexes()
	var ops := OpsStateScript.new()
	root.add_child(ops)
	ops.state = state
	ops.current_map_id = "bot_v3_certification"
	ops.match_phase = 1
	ops.input_locked = false
	ops.match_roster = [
		{"seat": 1, "team_id": 1, "is_cpu": false, "active": true},
		{"seat": 2, "team_id": 2, "is_cpu": true, "active": true}
	]
	ops.set_bot_match_seed(seed)
	ops.set_bot_profile(2, {
		"policy": policy_version,
		"style": "balancer",
		"tier": "medium",
		"opening_delay_ms": 0,
		"opening_stagger_ms": 0,
		"think_interval_ms": 100,
		"think_jitter_ms": 0,
		"global_intent_cooldown_ms": 0,
		"post_intent_delay_ms": 0,
		"allow_swarm": false,
		"min_attack_power": 8,
		"adaptive_reaction_delay_ms": EXPECTED_REACTION_DELAY_MS,
		"adaptive_reaction_jitter_ms": 0,
		"adaptive_reallocation_delay_ms": 250,
		"adaptive_losing_pressure_margin_milli": 2000,
		"adaptive_losing_power_margin": 6
	})
	return {"state": state, "ops": ops}


func _prepare_fixture_tick(state: GameState, tick: int, inject_loss: bool = true) -> void:
	state.tick = tick
	state.set("_sim_time_us", tick * FIXED_STEP_MS * 1000)
	if not inject_loss or tick < LOSS_EVENT_TICK:
		return
	var lane: LaneData = state.lanes[0] as LaneData
	if lane != null and state.is_outgoing_lane_active(1, 2):
		lane.send_b = true
		lane.a_pressure = 1.0
		lane.b_pressure = 6.0


func _append_actions(target: Array[Dictionary], outcomes: Array[Dictionary], tick: int) -> void:
	for outcome in outcomes:
		if str(outcome.get("outcome", "")) != "act":
			continue
		var result: Dictionary = outcome.get("result", {}) as Dictionary
		if not bool(result.get("ok", false)):
			continue
		var action: Dictionary = outcome.get("action", {}) as Dictionary
		target.append({
			"tick": tick,
			"kind": str(action.get("kind", "")),
			"src_id": int(action.get("src_id", -1)),
			"dst_id": int(action.get("dst_id", -1)),
			"fingerprint": str(result.get("action_fingerprint", ""))
		})


func _action_tick(actions: Array, kind: String) -> int:
	for action_any in actions:
		var action: Dictionary = action_any as Dictionary
		if str(action.get("kind", "")) == kind:
			return int(action.get("tick", -1))
	return -1


func _visibility_state(enemy_power: int) -> GameState:
	var state := GameState.new()
	state.load_from_map_dict({
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "kind": "Hive", "power": 20},
			{"id": 2, "x": 1, "y": 0, "owner_id": 2, "kind": "Hive", "power": enemy_power}
		],
		"lane_candidates": [{"a_id": 1, "b_id": 2}]
	})
	return state


func _float_env(name: String, fallback: float) -> float:
	var raw: String = OS.get_environment(name).strip_edges()
	if raw.is_empty() or not raw.is_valid_float():
		return fallback
	return maxf(0.0, float(raw))


func _assert_true(value: bool, label: String) -> void:
	if not value:
		_failures.append(label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_failures.append("%s (expected %s, got %s)" % [label, str(expected), str(actual)])
