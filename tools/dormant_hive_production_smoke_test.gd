extends SceneTree

var _failed: bool = false

func _init() -> void:
	var state := GameState.new()
	state.init_core_defaults()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 1, "Hive"),
		HiveData.new(2, Vector2i(3, 0), 1, 5, "Hive"),
		HiveData.new(3, Vector2i(6, 0), 2, 50, "Hive")
	]
	state.lanes = [{
		"a_id": 2,
		"b_id": 3,
		"send_a": true,
		"send_b": false
	}]
	state.rebuild_indexes()

	_assert_float_eq(
		float(state.PASSIVE_MS_PER_POWER),
		float(SimTuning.BASE_SPAWN_MS) * 2.0,
		"dormant production should run at half the fixed level-one rate"
	)

	# Hive 1 begins dormant; hive 2 is active and must not share its clock.
	state._tick_dormant_hive_production(2000.0)
	_assert_eq(int(state.hives[0].power), 1, "dormant hive should not produce before its own full cycle")
	_assert_eq(int(state.hives[1].power), 5, "active hive should not accumulate dormant power")

	# Hive 2 becomes dormant two seconds after hive 1. Their credits must land
	# on separate clocks rather than the old match-wide three-second pulse.
	(state.lanes[0] as Dictionary)["send_a"] = false
	state._tick_dormant_hive_production(1000.0)
	_assert_eq(int(state.hives[0].power), 2, "first dormant hive should complete its own production cycle")
	_assert_eq(int(state.hives[1].power), 5, "newly dormant hive should begin a fresh production cycle")
	_assert_eq(int(state.hives[2].power), 50, "max-level dormant hive should consume production without exceeding max power")
	_assert_float_eq(float(state.hives[2].idle_accum_ms), 0.0, "max-level dormant hive should still complete its fixed production cycle")
	state._tick_dormant_hive_production(2000.0)
	_assert_eq(int(state.hives[0].power), 2, "first hive should retain its independent phase")
	_assert_eq(int(state.hives[1].power), 6, "second hive should complete its later production cycle")

	# Activating an outgoing lane consumes the partial dormant cycle. Returning
	# to dormancy must never inherit a nearly-complete shared/global pulse.
	(state.lanes[0] as Dictionary)["a_id"] = 1
	(state.lanes[0] as Dictionary)["send_a"] = true
	state._tick_dormant_hive_production(100.0)
	(state.lanes[0] as Dictionary)["send_a"] = false
	state._tick_dormant_hive_production(1000.0)
	_assert_eq(int(state.hives[0].power), 2, "reactivated hive should restart dormant production from zero")

	_assert_float_eq(float(state.hives[0].idle_accum_ms), 1000.0, "dormant hive should retain only its own elapsed production time")

	var ops_script: Script = load("res://scripts/ops/ops_state.gd") as Script
	var ops: Node = ops_script.new() as Node if ops_script != null else null
	_assert_true(ops != null, "OpsState should instantiate for authority snapshot coverage")
	if ops != null:
		ops.set("state", state)
		state.hives[0].idle_accum_ms = 1250.0
		var expected_hash: String = str(ops.call("get_contract_state_hash"))
		var authority_snapshot: Dictionary = ops.call("get_authority_snapshot") as Dictionary
		state.hives[0].idle_accum_ms = 0.0
		_assert_true(str(ops.call("get_contract_state_hash")) != expected_hash, "per-hive dormant clocks should participate in the authority hash")
		_assert_true(bool(ops.call("restore_authority_snapshot", authority_snapshot)), "authority snapshot should restore per-hive dormant clocks")
		var restored_state: GameState = ops.get("state") as GameState
		_assert_float_eq(float(restored_state.hives[0].idle_accum_ms), 1250.0, "authority restore should preserve each dormant hive's production phase")
		_assert_true(str(ops.call("get_contract_state_hash")) == expected_hash, "restored dormant clocks should recover the exact authority hash")
		ops.free()

	if _failed:
		quit(1)
		return
	print("DORMANT_HIVE_PRODUCTION_SMOKE: PASS")
	quit(0)

func _assert_eq(actual: int, expected: int, message: String) -> void:
	if actual == expected:
		return
	_failed = true
	push_error("%s expected=%d actual=%d" % [message, expected, actual])

func _assert_float_eq(actual: float, expected: float, message: String) -> void:
	if is_equal_approx(actual, expected):
		return
	_failed = true
	push_error("%s expected=%s actual=%s" % [message, str(expected), str(actual)])

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error(message)
