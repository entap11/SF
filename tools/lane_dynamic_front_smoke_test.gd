extends SceneTree

const GameStateScript := preload("res://scripts/state/game_state.gd")
const HiveDataScript := preload("res://scripts/data/hive_data.gd")
const LaneDataScript := preload("res://scripts/data/lane_data.gd")
const LaneSystemScript := preload("res://scripts/sim/lane_system.gd")
const UnitSystemScript := preload("res://scripts/systems/unit_system.gd")

var _failed: bool = false

func _initialize() -> void:
	await process_frame
	_test_contested_front_stays_static_midpoint()
	_test_static_front_ignores_hive_buffer_clamp()
	_test_unit_collision_keeps_static_visual_front()
	if _failed:
		quit(1)
		return
	print("LANE_STATIC_FRONT_SMOKE: PASS")
	quit(0)

func _test_contested_front_stays_static_midpoint() -> void:
	var lane: LaneData = _make_lane(12.0, 4.0)
	var lane_system: LaneSystem = _make_lane_system(lane)
	_set_ops_running()
	_set_front(lane.id, 0.5)
	lane.last_impact_f = 0.65
	lane_system.tick_lane_fronts(1.0)
	_assert_near(_front(lane.id), 0.5, 0.001, "contested front should stay at static midpoint")

	lane.a_pressure = 4.0
	lane.b_pressure = 12.0
	_set_front(lane.id, 0.5)
	lane.last_impact_f = 0.35
	lane_system.tick_lane_fronts(1.0)
	_assert_near(_front(lane.id), 0.5, 0.001, "opposite pressure should not move static front")

	lane.a_pressure = 5.0
	lane.b_pressure = 5.0
	_set_front(lane.id, 0.35)
	lane.last_impact_f = 0.35
	lane_system.tick_lane_fronts(1.0)
	_assert_near(_front(lane.id), 0.5, 0.001, "static front should restore midpoint if old state drifted")
	lane_system.free()

func _test_static_front_ignores_hive_buffer_clamp() -> void:
	var lane: LaneData = _make_lane(100.0, 1.0)
	var lane_system: LaneSystem = _make_lane_system(lane)
	_set_ops_running()
	_set_front(lane.id, 0.5)
	lane.last_impact_f = 0.95
	lane_system.tick_lane_fronts(1.0)
	_assert_near(_front(lane.id), 0.5, 0.001, "static front should ignore dynamic buffer target")
	lane_system.free()

func _test_unit_collision_keeps_static_visual_front() -> void:
	var lane: LaneData = _make_lane(1.0, 1.0)
	var state: GameState = _make_state(lane)
	var unit_system = UnitSystemScript.new()
	unit_system.bind_state(state)
	unit_system.call("_record_lane_visual_impact", lane.id, 0.68)
	_assert_near(lane.last_impact_f, 0.5, 0.001, "unit impact should not move static lane visual impact")
	_assert_near(_front(lane.id), 0.5, 0.001, "unit impact should keep visible front static")
	var lane_system: LaneSystem = _make_lane_system(lane)
	_set_ops_running()
	lane_system.tick_lane_fronts(1.0)
	_assert_near(_front(lane.id), 0.5, 0.001, "contested front should remain static between collisions")
	lane_system.free()

func _make_lane(a_pressure: float, b_pressure: float) -> LaneData:
	return LaneDataScript.new(1, 1, 2, 1, true, true, a_pressure, b_pressure, 0.0, 0.0, 1.0, 0.5)

func _make_lane_system(lane: LaneData) -> LaneSystem:
	var lane_system: LaneSystem = LaneSystemScript.new()
	lane_system.bind_state(_make_state(lane))
	return lane_system

func _make_state(lane: LaneData) -> GameState:
	var state: GameState = GameStateScript.new()
	state.hives.append(HiveDataScript.new(1, Vector2i(0, 0), 1, 10))
	state.hives.append(HiveDataScript.new(2, Vector2i(4, 0), 2, 10))
	state.lanes.append(lane)
	return state

func _set_ops_running() -> void:
	var ops_state: Node = root.get_node_or_null("/root/OpsState")
	if ops_state != null:
		ops_state.set("match_phase", 1)

func _set_front(lane_id: int, value: float) -> void:
	var ops_state: Node = root.get_node_or_null("/root/OpsState")
	if ops_state == null:
		return
	var front_by_lane: Dictionary = ops_state.get("lane_front_by_lane_id") as Dictionary
	front_by_lane[lane_id] = value

func _front(lane_id: int) -> float:
	var ops_state: Node = root.get_node_or_null("/root/OpsState")
	if ops_state == null:
		return -1.0
	var front_by_lane: Dictionary = ops_state.get("lane_front_by_lane_id") as Dictionary
	return float(front_by_lane.get(lane_id, -1.0))

func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) <= tolerance:
		return
	_failed = true
	push_error("LANE_STATIC_FRONT_SMOKE: %s expected %.3f got %.3f" % [message, expected, actual])
