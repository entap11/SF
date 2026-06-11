extends SceneTree

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const IRON_CROSS_MAP := "res://maps/_future/iron_cross/MAP_iron_cross__SBASE__4p.json"

func _init() -> void:
	await process_frame
	_test_iron_cross_lane_pressure_can_exceed_former_budget()
	print("IRON_CROSS_UNIT_BUDGET_SMOKE: PASS")
	quit(0)

func _test_iron_cross_lane_pressure_can_exceed_former_budget() -> void:
	var loaded: Dictionary = MAP_LOADER.load_map(IRON_CROSS_MAP)
	_assert_true(bool(loaded.get("ok", false)), "Iron Cross map should load")
	var state := GameState.new()
	state.load_from_map_dict((loaded.get("data", {}) as Dictionary).duplicate(true))
	state.lanes.clear()
	var lane_id: int = 1
	for candidate_any in state.lane_candidates:
		if typeof(candidate_any) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_any as Dictionary
		var a_id: int = int(candidate.get("a_id", candidate.get("from", candidate.get("src", 0))))
		var b_id: int = int(candidate.get("b_id", candidate.get("to", candidate.get("dst", 0))))
		if a_id <= 0 or b_id <= 0:
			continue
		state.lanes.append(LaneData.new(lane_id, a_id, b_id, 1, true, true))
		lane_id += 1
	state.rebuild_indexes()
	_assert_true(not state.lanes.is_empty(), "Iron Cross should have generated lane candidates")
	var lane: LaneData = state.lanes[0] as LaneData
	lane.send_a = true
	lane.send_b = false
	var former_lane_cap: float = state.call("_lane_hard_cap_units", 99999.0)
	lane.a_pressure = former_lane_cap

	for hive_any in state.hives:
		var hive: HiveData = hive_any as HiveData
		hive.owner_id = 1
		hive.power = 50

	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	unit_system.use_lane_system_spawns = true

	state.tick_lane_flow(5000.0)
	var units: Array = unit_system.export_units_render()
	_assert_true(not units.is_empty(), "Iron Cross should spawn above the former lane pressure budget")
	_assert_true(float(lane.a_pressure) > former_lane_cap, "Iron Cross lane pressure should exceed the former hard cap")

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("IRON_CROSS_UNIT_BUDGET_SMOKE: %s" % label)
	quit(1)
