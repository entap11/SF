extends SceneTree

const BotActionScript := preload("res://scripts/bot/bot_action.gd")
const BotCommandGatewayScript := preload("res://scripts/bot/bot_command_gateway.gd")
const BotCounterRngScript := preload("res://scripts/bot/bot_counter_rng.gd")
const BotDecisionScript := preload("res://scripts/bot/bot_decision.gd")
const BotObservationBuilderScript := preload("res://scripts/bot/bot_observation_builder.gd")
const BotRunnerScript := preload("res://scripts/bot/bot_runner.gd")
const BotSystemScript := preload("res://scripts/systems/bot_system.gd")
const DeterministicVariantScript := preload("res://scripts/util/deterministic_variant.gd")
const OpsStateScript := preload("res://scripts/ops/ops_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	await process_frame
	_test_decision_contract()
	_test_action_and_gateway_contract()
	_test_deterministic_hash_contract()
	_test_counter_rng_contract()
	_test_runtime_snapshot_contract()
	_test_hidden_information_contract()
	_test_bot_system_loads_shared_runner()
	if not _failures.is_empty():
		for failure in _failures:
			push_error("BOT_RUNTIME_CONTRACT_SMOKE: %s" % failure)
		quit(1)
		return
	print("BOT_RUNTIME_CONTRACT_SMOKE: PASS")
	quit(0)


func _test_decision_contract() -> void:
	var act: Dictionary = BotDecisionScript.act({"kind": "sample"})
	var defer: Dictionary = BotDecisionScript.defer({"reason": "sample"})
	_assert_eq(str(act.get("outcome", "")), BotDecisionScript.ACT, "action decision must return ACT")
	_assert_eq(str(defer.get("outcome", "")), BotDecisionScript.DEFER, "empty decision must return DEFER")
	_assert_true(BotDecisionScript.is_act(act), "ACT helper must recognize action decisions")
	_assert_true(not BotDecisionScript.is_act(defer), "DEFER must not be executable")


func _test_action_and_gateway_contract() -> void:
	var action: Dictionary = BotActionScript.from_policy_intent(
		{"src": 10, "dst": 20, "intent": "attack"},
		2,
		7,
		99,
		"baseline_v2"
	)
	_assert_eq(str(action.get("kind", "")), BotActionScript.OPEN_ROUTE, "policy attack must become an open-route action")
	var gateway := BotCommandGatewayScript.new()
	var payload: Dictionary = gateway.canonical_payload(action)
	_assert_eq(str(payload.get("kind", "")), "lane_intent", "gateway must publish the existing lane-intent command")
	_assert_eq(int(payload.get("sender_seat", 0)), 2, "gateway must preserve acting seat")
	var retract: Dictionary = BotActionScript.retract(2, 10, 20, 8, 100, "adaptive_v3.0")
	var retract_payload: Dictionary = gateway.canonical_payload(retract)
	_assert_eq(str(retract_payload.get("kind", "")), "lane_retract", "gateway must publish the existing lane-retract command")


func _test_deterministic_hash_contract() -> void:
	var left := {"b": [2, 3], "a": {"y": true, "x": 1}}
	var right := {"a": {"x": 1, "y": true}, "b": [2, 3]}
	_assert_eq(
		DeterministicVariantScript.hash_variant(left),
		DeterministicVariantScript.hash_variant(right),
		"variant hash must ignore dictionary insertion order"
	)


func _test_counter_rng_contract() -> void:
	var first: int = BotCounterRngScript.sample_u32(17, "adaptive_v3.0", "profile", 2, 9, "target")
	var repeated: int = BotCounterRngScript.sample_u32(17, "adaptive_v3.0", "profile", 2, 9, "target")
	BotCounterRngScript.sample_u32(17, "adaptive_v3.0", "profile", 2, 9, "unrelated")
	var after_unrelated: int = BotCounterRngScript.sample_u32(17, "adaptive_v3.0", "profile", 2, 9, "target")
	_assert_eq(first, repeated, "counter RNG must reproduce the same keyed choice")
	_assert_eq(first, after_unrelated, "unrelated RNG purposes must not shift later choices")


func _test_runtime_snapshot_contract() -> void:
	var ops_state := OpsStateScript.new()
	var runtime := {
		"schema_version": 1,
		"by_seat": {
			2: {
				"schema_version": 1,
				"seat": 2,
				"decision_sequence": 4,
				"next_think_ms": 2500
			}
		}
	}
	_assert_true(ops_state.store_bot_runtime_from_runner(runtime), "OpsState must accept the runner-owned runtime schema")
	var stored: Dictionary = ops_state.get_bot_runtime_snapshot()
	_assert_eq(int((stored.get("by_seat", {}) as Dictionary).size()), 1, "OpsState must preserve cognition by seat")
	_assert_true(not str(stored.get("runtime_hash", "")).is_empty(), "cognition snapshot must carry a deterministic hash")
	var runner := BotRunnerScript.new()
	_assert_true(runner.import_runtime_state(stored), "runner must restore the authority snapshot")
	_assert_eq(
		str(runner.export_runtime_state().get("runtime_hash", "")),
		str(stored.get("runtime_hash", "")),
		"restored cognition must retain its hash"
	)
	var corrupt: Dictionary = stored.duplicate(true)
	corrupt["runtime_hash"] = "corrupt"
	_assert_true(not runner.import_runtime_state(corrupt), "runner must reject cognition with a mismatched hash")
	ops_state.free()


func _test_hidden_information_contract() -> void:
	var left := _visibility_fixture_state(12)
	var right := _visibility_fixture_state(47)
	var ops_state := OpsStateScript.new()
	ops_state.set_victory_mode("ctf", {
		"hidden_flag": true,
		"hide_opponent_power": true
	})
	var builder := BotObservationBuilderScript.new()
	var left_observation: Dictionary = builder.build(left, 1, ops_state)
	var right_observation: Dictionary = builder.build(right, 1, ops_state)
	_assert_eq(
		DeterministicVariantScript.hash_variant(left_observation),
		DeterministicVariantScript.hash_variant(right_observation),
		"changing only hidden opponent power must not change observation"
	)
	ops_state.free()


func _visibility_fixture_state(enemy_power: int) -> GameState:
	var state := GameState.new()
	state.load_from_map_dict({
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "kind": "Hive", "power": 20},
			{"id": 2, "x": 1, "y": 0, "owner_id": 2, "kind": "Hive", "power": enemy_power}
		],
		"lane_candidates": [{"a_id": 1, "b_id": 2}]
	})
	return state


func _test_bot_system_loads_shared_runner() -> void:
	var bot_system := BotSystemScript.new()
	var runner_any: Variant = bot_system.get("runner")
	_assert_true(
		runner_any is Object and (runner_any as Object).get_script() == BotRunnerScript,
		"production BotSystem must delegate to BotRunner"
	)
	bot_system.free()


func _assert_true(value: bool, label: String) -> void:
	if not value:
		_failures.append(label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_failures.append("%s (expected %s, got %s)" % [label, str(expected), str(actual)])
