extends SceneTree

var _failed: bool = false

func _init() -> void:
	await process_frame
	_test_equal_simultaneous_neutral_attack_churns_control()
	_test_repeated_equal_neutral_attack_stays_low_power()
	_test_equal_lane_flow_neutral_attack_stays_low_power()
	_test_single_neutral_attack_still_captures()
	if _failed:
		quit(1)
		return
	print("NEUTRAL_HIVE_CONTEST_SMOKE: PASS")
	quit(0)

func _test_equal_simultaneous_neutral_attack_churns_control() -> void:
	var state := _make_state(1)
	var unit_system := _bind_units(state)
	unit_system.units = [
		_arrived_unit(101, 1, 2, 1, 1, 1),
		_arrived_unit(201, 3, 2, 2, 2, 1)
	]
	unit_system.call("_process_arrivals")
	var neutral: HiveData = state.find_hive_by_id(2)
	_assert_eq(int(neutral.owner_id), 2, "equal simultaneous neutral contest should resolve every arrival in order")
	_assert_eq(int(neutral.power), 1, "equal simultaneous neutral contest should leave only capture power")
	_assert_eq(unit_system.units.size(), 0, "arrived contest units should be consumed")
	var blocks: Dictionary = unit_system.get("_contested_capture_block_until_us_by_hive") as Dictionary
	_assert_true(blocks.has(2), "same-frame contested neutral capture should be spawn-blocked")

func _test_repeated_equal_neutral_attack_stays_low_power() -> void:
	var state := _make_state(1)
	var unit_system := _bind_units(state)
	for step in range(6):
		unit_system.units = [
			_arrived_unit(100 + step, 1, 2, 1, 1, 1),
			_arrived_unit(200 + step, 3, 2, 2, 2, 1)
		]
		unit_system.call("_process_arrivals")
	var neutral: HiveData = state.find_hive_by_id(2)
	_assert_true(int(neutral.owner_id) == 1 or int(neutral.owner_id) == 2, "repeated equal neutral contest may be temporarily owned")
	_assert_eq(int(neutral.power), 1, "repeated equal neutral contest should stay at capture power")

func _test_equal_lane_flow_neutral_attack_stays_low_power() -> void:
	var state := _make_state(5)
	var lane_a: LaneData = state.lanes[0] as LaneData
	var lane_b: LaneData = state.lanes[1] as LaneData
	lane_a.send_a = true
	lane_b.send_a = true
	var unit_system := _bind_units(state)
	unit_system.use_lane_system_spawns = true
	for _step in range(300):
		state.tick_lane_flow(100.0, true)
		unit_system.tick(0.1)
	var neutral: HiveData = state.find_hive_by_id(2)
	_assert_true(int(neutral.owner_id) == 1 or int(neutral.owner_id) == 2, "30s equal level-10 lane flow may have temporary owner")
	_assert_true(int(neutral.power) <= 2, "30s equal level-10 lane flow should not let temporary owner build useful power")

func _test_single_neutral_attack_still_captures() -> void:
	var state := _make_state(1)
	var unit_system := _bind_units(state)
	unit_system.units = [
		_arrived_unit(101, 1, 2, 1, 1, 1)
	]
	unit_system.call("_process_arrivals")
	var neutral: HiveData = state.find_hive_by_id(2)
	_assert_eq(int(neutral.owner_id), 1, "single-owner neutral attack should still capture")
	_assert_eq(int(neutral.power), 1, "single-owner neutral capture should start at capture power")

func _make_state(neutral_power: int) -> GameState:
	var state := GameState.new()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 10, "Hive"),
		HiveData.new(2, Vector2i(5, 0), 0, neutral_power, "Hive"),
		HiveData.new(3, Vector2i(10, 0), 2, 10, "Hive")
	]
	state.lanes = [
		LaneData.new(1, 1, 2, 1, false, false),
		LaneData.new(2, 3, 2, 1, false, false)
	]
	state.rebuild_indexes()
	return state

func _bind_units(state: GameState) -> UnitSystem:
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	return unit_system

func _arrived_unit(unit_id: int, from_id: int, to_id: int, owner_id: int, lane_id: int, amount: int) -> Dictionary:
	return {
		"id": unit_id,
		"from_id": from_id,
		"to_id": to_id,
		"owner_id": owner_id,
		"amount": amount,
		"lane_id": lane_id,
		"a_id": from_id,
		"b_id": to_id,
		"dir": 1,
		"t": 1.0,
		"skip_pressure": true
	}

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	_fail("%s (expected %d, got %d)" % [label, expected, actual])

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_fail(label)

func _fail(message: String) -> void:
	_failed = true
	push_error("NEUTRAL_HIVE_CONTEST_SMOKE: %s" % message)
