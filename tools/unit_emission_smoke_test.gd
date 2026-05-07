extends SceneTree

func _init() -> void:
	await process_frame
	_test_lane_flow_emits_units()
	print("UNIT_EMISSION_SMOKE: PASS")
	quit(0)

func _test_lane_flow_emits_units() -> void:
	var state := GameState.new()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 50, "Hive"),
		HiveData.new(2, Vector2i(5, 0), 2, 50, "Hive")
	]
	state.lanes = [
		LaneData.new(1, 1, 2, 1, true, false)
	]
	state.rebuild_indexes()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	unit_system.use_lane_system_spawns = true
	state.tick_lane_flow(1600.0)
	var units: Array = unit_system.export_units_render()
	_assert_true(not units.is_empty(), "lane flow should enqueue renderable units")
	var unit: Dictionary = units[0] as Dictionary
	_assert_eq(int(unit.get("lane_id", 0)), 1, "emitted unit should retain lane id")
	_assert_eq(int(unit.get("owner_id", 0)), 1, "emitted unit should retain source owner")
	_assert_true(unit.get("pos", null) is Vector2, "emitted unit should have a render position")

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	_fail("%s (expected %d, got %d)" % [label, expected, actual])

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_fail(label)

func _fail(message: String) -> void:
	push_error("UNIT_EMISSION_SMOKE: %s" % message)
	quit(1)
