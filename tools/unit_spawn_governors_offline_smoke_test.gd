extends SceneTree

func _init() -> void:
	await process_frame
	_test_lane_flow_allows_spawn_above_former_hard_cap()
	_test_unit_system_allows_spawn_above_former_hard_cap()
	_test_pass_through_governors_offline()
	_test_active_unit_cap_blocks_until_unit_frees()
	_test_lane_flow_waits_for_unit_capacity()
	_test_friendly_arrivals_absorb_below_max_power()
	_test_friendly_arrival_that_maxes_hive_does_not_pass_through()
	_test_shocked_hive_absorbs_friendly_arrivals_without_power()
	_test_outgoing_lane_budget_restored()
	print("UNIT_SPAWN_GOVERNORS_OFFLINE_SMOKE: PASS")
	quit(0)

func _test_lane_flow_allows_spawn_above_former_hard_cap() -> void:
	var state := _state_with_hostile_lane_conditions()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	unit_system.use_lane_system_spawns = true
	state.tick_lane_flow(5000.0)
	var units: Array = unit_system.export_units_render()
	_assert_true(not units.is_empty(), "lane-flow spawn should continue above the former lane pressure hard cap")
	_assert_true(float((state.lanes[0] as LaneData).a_pressure) > 999.0, "lane-flow pressure should be allowed above the former hard cap")

func _test_unit_system_allows_spawn_above_former_hard_cap() -> void:
	var state := _state_with_hostile_lane_conditions()
	state.spawns = [{"hive_id": 99}]
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	unit_system.use_lane_system_spawns = false
	unit_system.tick(1.5)
	var units: Array = unit_system.export_units_render()
	_assert_true(not units.is_empty(), "unit-system spawn should continue above the former lane pressure hard cap")
	_assert_true(float((state.lanes[0] as LaneData).a_pressure) > 999.0, "unit-system pressure should be allowed above the former hard cap")

func _test_pass_through_governors_offline() -> void:
	var state := GameState.new()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	for i in range(300):
		unit_system.units.append({"id": i + 1})
	var multiplier: float = float(unit_system.call("_pass_through_emit_rate_multiplier"))
	_assert_true(is_equal_approx(multiplier, 1.0), "pass-through rate multiplier should not throttle under heavy visible-unit load")

func _test_active_unit_cap_blocks_until_unit_frees() -> void:
	var state := GameState.new()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	for i in range(200):
		unit_system.units.append({"id": i + 1, "owner_id": 1, "amount": 1})
	for i in range(200):
		unit_system.units.append({"id": 201 + i, "owner_id": 2, "amount": 1})
	var spawned_at_cap: bool = unit_system.spawn_unit({"owner_id": 2, "amount": 1})
	_assert_true(not spawned_at_cap, "active unit cap should reject unit 401")
	_assert_true(unit_system.units.size() == 400, "active unit cap should hold at 400 without recycling")
	_assert_true(_unit_count_for_owner(unit_system, 1) == 200, "active unit cap should not remove owner 1 units")
	_assert_true(_unit_count_for_owner(unit_system, 2) == 200, "active unit cap should not remove owner 2 units")
	var removed: bool = bool(unit_system.call("_remove_unit", 1, "test_capacity_free"))
	_assert_true(removed, "test should remove one unit to free capacity")
	var spawned_after_free: bool = unit_system.spawn_unit({"owner_id": 2, "amount": 1})
	_assert_true(spawned_after_free, "spawn should resume after a unit leaves the active game")
	_assert_true(unit_system.units.size() == 400, "active unit cap should refill the freed slot only")
	_assert_true(_unit_count_for_owner(unit_system, 1) == 199, "only the explicitly removed owner 1 unit should be gone")
	_assert_true(_unit_count_for_owner(unit_system, 2) == 201, "owner 2 should receive the newly available slot")

func _test_lane_flow_waits_for_unit_capacity() -> void:
	var state := _state_with_hostile_lane_conditions(0.0)
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	unit_system.use_lane_system_spawns = true
	for i in range(400):
		unit_system.units.append({"id": i + 1, "owner_id": 1 if i < 200 else 2, "amount": 1})
	state.tick_lane_flow(5000.0)
	_assert_true(unit_system.units.size() == 400, "lane-flow should not spawn while active unit cap is full")
	_assert_true(is_equal_approx(float((state.lanes[0] as LaneData).a_pressure), 0.0), "lane-flow should not add phantom pressure while unit cap is full")
	var removed: bool = bool(unit_system.call("_remove_unit", 1, "test_capacity_free"))
	_assert_true(removed, "test should free one active unit for lane-flow")
	state.tick_lane_flow(1.0)
	_assert_true(unit_system.units.size() == 400, "lane-flow should use exactly one newly freed unit slot")
	_assert_true(float((state.lanes[0] as LaneData).a_pressure) > 0.0, "lane-flow should resume once unit capacity is available")

func _test_friendly_arrivals_absorb_below_max_power() -> void:
	var state := GameState.new()
	state.hives = [
		HiveData.new(5, Vector2i(0, 0), 1, 50, "Hive"),
		HiveData.new(6, Vector2i(5, 0), 1, 1, "Hive"),
		HiveData.new(7, Vector2i(10, 0), 0, 1, "Hive")
	]
	state.lanes = [
		LaneData.new(1, 6, 7, 1, true, false)
	]
	state.rebuild_indexes()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	for i in range(3):
		unit_system.call("_apply_unit_arrival", {
			"id": i + 1,
			"from_id": 5,
			"to_id": 6,
			"owner_id": 1,
			"amount": 1,
			"lane_id": 99,
			"a_id": 5,
			"b_id": 6,
			"dir": 1,
			"skip_pressure": true
		})
	unit_system.tick(0.1)
	var forwarded := 0
	for unit_any in unit_system.export_units_render():
		var unit: Dictionary = unit_any as Dictionary
		if int(unit.get("from_id", -1)) == 6 and int(unit.get("to_id", -1)) == 7 and str(unit.get("arrive_source", "")) == "pass_through":
			forwarded += 1
	_assert_true(forwarded == 0, "friendly arrivals should not pass through below max power")
	_assert_true(int((state.hives[1] as HiveData).power) == 4, "friendly arrivals below max should charge the hive")

func _test_friendly_arrival_that_maxes_hive_does_not_pass_through() -> void:
	var state := GameState.new()
	state.hives = [
		HiveData.new(5, Vector2i(0, 0), 1, 50, "Hive"),
		HiveData.new(6, Vector2i(5, 0), 1, 49, "Hive"),
		HiveData.new(7, Vector2i(10, 0), 0, 1, "Hive")
	]
	state.lanes = [
		LaneData.new(1, 6, 7, 1, true, false)
	]
	state.rebuild_indexes()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	unit_system.call("_apply_unit_arrival", {
		"id": 100,
		"from_id": 5,
		"to_id": 6,
		"owner_id": 1,
		"amount": 1,
		"lane_id": 99,
		"a_id": 5,
		"b_id": 6,
		"dir": 1,
		"skip_pressure": true
	})
	unit_system.tick(0.1)
	var forwarded := 0
	for unit_any in unit_system.export_units_render():
		var unit: Dictionary = unit_any as Dictionary
		if int(unit.get("from_id", -1)) == 6 and int(unit.get("to_id", -1)) == 7 and str(unit.get("arrive_source", "")) == "pass_through":
			forwarded += 1
	_assert_true(forwarded == 0, "friendly arrival that maxes a hive should still be absorbed")
	_assert_true(int((state.hives[1] as HiveData).power) == 50, "friendly arrival should fill the hive to max")

func _test_shocked_hive_absorbs_friendly_arrivals_without_power() -> void:
	var state := GameState.new()
	var shocked_hive := HiveData.new(6, Vector2i(5, 0), 1, 3, "Hive")
	shocked_hive.shock_ms = 1200.0
	state.hives = [
		HiveData.new(5, Vector2i(0, 0), 1, 50, "Hive"),
		shocked_hive,
		HiveData.new(7, Vector2i(10, 0), 0, 1, "Hive")
	]
	state.lanes = [
		LaneData.new(1, 6, 7, 1, true, false)
	]
	state.rebuild_indexes()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	for i in range(3):
		unit_system.call("_apply_unit_arrival", {
			"id": 200 + i,
			"from_id": 5,
			"to_id": 6,
			"owner_id": 1,
			"amount": 1,
			"lane_id": 99,
			"a_id": 5,
			"b_id": 6,
			"dir": 1,
			"skip_pressure": true
		})
	unit_system.tick(0.1)
	var forwarded := 0
	for unit_any in unit_system.export_units_render():
		var unit: Dictionary = unit_any as Dictionary
		if int(unit.get("from_id", -1)) == 6 and int(unit.get("to_id", -1)) == 7 and str(unit.get("arrive_source", "")) == "pass_through":
			forwarded += 1
	_assert_true(forwarded == 0, "friendly arrivals into a shocked hive should not pass through")
	_assert_true(int(shocked_hive.power) == 3, "friendly arrivals into a shocked hive should not increase power")

func _test_outgoing_lane_budget_restored() -> void:
	var state := GameState.new()
	_assert_true(int(state.lanes_allowed_for_power(1)) == 1, "small hives should have one outgoing lane")
	_assert_true(int(state.lanes_allowed_for_power(9)) == 1, "power 9 hives should have one outgoing lane")
	_assert_true(int(state.lanes_allowed_for_power(10)) == 2, "power 10 hives should have two outgoing lanes")
	_assert_true(int(state.lanes_allowed_for_power(24)) == 2, "power 24 hives should have two outgoing lanes")
	_assert_true(int(state.lanes_allowed_for_power(25)) == 3, "power 25 hives should have three outgoing lanes")
	_assert_true(int(state.lanes_allowed_for_power(50)) == 3, "max hives should have three outgoing lanes")

func _state_with_hostile_lane_conditions(starting_pressure: float = 999.0) -> GameState:
	var state := GameState.new()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 50, "Hive"),
		HiveData.new(2, Vector2i(10, 0), 2, 50, "Hive")
	]
	state.lanes = [
		LaneData.new(1, 1, 2, 1, true, false, starting_pressure, 0.0, 0.0, 0.0, 0.0, 0.5, true, false)
	]
	state.rebuild_indexes()
	return state

func _unit_count_for_owner(unit_system: UnitSystem, owner_id: int) -> int:
	var count: int = 0
	for unit_any in unit_system.units:
		var unit: Dictionary = unit_any as Dictionary
		if int(unit.get("owner_id", 0)) == owner_id:
			count += 1
	return count

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("UNIT_SPAWN_GOVERNORS_OFFLINE_SMOKE: %s" % label)
	quit(1)
