extends SceneTree

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const OPS_STATE_SCRIPT := preload("res://scripts/ops/ops_state.gd")
const SWARM_SYSTEM_SCRIPT := preload("res://scripts/systems/swarm_system.gd")
const DELTA_MAP_PATH := "res://maps/delta/MAP_delta__SBASE__3p.json"

var _failed: bool = false
var _created_ops_node: Node = null

func _init() -> void:
	await process_frame
	_test_capture_carries_surplus_power()
	_test_recent_landed_swarm_chains_above_start_cap()
	_test_delta_h3_to_h9_attack_route()
	_cleanup()
	if _failed:
		quit(1)
		return
	print("SWARM_CAPTURE_AND_DELTA_LANE_SMOKE: PASS")
	quit(0)

func _test_capture_carries_surplus_power() -> void:
	var state := GameState.new()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 10, "Hive"),
		HiveData.new(2, Vector2i(5, 0), 2, 1, "Hive")
	]
	state.lanes = [
		LaneData.new(1, 1, 2, 1, true, false)
	]
	state.rebuild_indexes()

	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	unit_system._apply_unit_arrival({
		"from_id": 1,
		"to_id": 2,
		"owner_id": 1,
		"amount": 5,
		"lane_id": 1,
		"a_id": 1,
		"b_id": 2,
		"dir": 1,
		"skip_pressure": true,
		"arrive_source": "swarm_system"
	})

	var captured: HiveData = state.find_hive_by_id(2)
	_assert_true(captured != null, "captured hive should exist")
	_assert_eq(int(captured.owner_id), 1, "surplus capture should change owner")
	_assert_eq(int(captured.power), 4, "surplus capture should keep remaining swarm power")

func _test_recent_landed_swarm_chains_above_start_cap() -> void:
	var state := GameState.new()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 40, "Hive"),
		HiveData.new(2, Vector2i(5, 0), 2, 1, "Hive"),
		HiveData.new(3, Vector2i(10, 0), 2, 10, "Hive")
	]
	state.lanes = [
		LaneData.new(1, 1, 2, 1, true, false),
		LaneData.new(2, 2, 3, 1, true, false)
	]
	state.rebuild_indexes()

	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	var swarm_system: SwarmSystem = SWARM_SYSTEM_SCRIPT.new()
	swarm_system.bind_state(state)
	swarm_system._apply_swarm_arrival({
		"id": 99,
		"from_id": 1,
		"to_id": 2,
		"owner_id": 1,
		"count": 20,
		"lane_id": 1,
		"a_id": 1,
		"b_id": 2,
		"dir": 1,
		"pos": state.hive_world_pos_by_id(2)
	}, unit_system)

	var captured: HiveData = state.find_hive_by_id(2)
	_assert_true(captured != null, "chain captured hive should exist")
	_assert_eq(int(captured.owner_id), 1, "chain setup should capture relay hive")
	_assert_true(int(captured.power) > 5, "chain setup should leave relay hive above normal swarm cap")
	var relay_lane_index: int = state.lane_index_between(2, 3)
	_assert_true(relay_lane_index != -1, "chain relay lane should exist")
	if relay_lane_index != -1:
		var relay_lane: LaneData = state.lanes[relay_lane_index] as LaneData
		relay_lane.send_a = true
		_assert_true(relay_lane != null and bool(relay_lane.send_a), "chain relay lane should send from captured hive")
	state.swarm_requests.append({"src": 2, "dst": 3})
	swarm_system._consume_swarm_requests()
	_assert_eq(state.swarm_requests.size(), 0, "chain swarm request should be consumed")
	_assert_eq(swarm_system.swarm_packets.size(), 1, "chain should spawn one outgoing swarm")
	if swarm_system.swarm_packets.is_empty():
		return
	var packet: Dictionary = swarm_system.swarm_packets[0] as Dictionary
	_assert_true(int(packet.get("count", 0)) > 5, "chain swarm should exceed normal start cap")
	_assert_eq(int(packet.get("from_id", -1)), 2, "chain swarm should launch from relay hive")
	_assert_eq(int(packet.get("to_id", -1)), 3, "chain swarm should launch to next hive")

func _test_delta_h3_to_h9_attack_route() -> void:
	var loaded: Dictionary = MAP_LOADER.load_map(DELTA_MAP_PATH)
	_assert_true(bool(loaded.get("ok", false)), "Delta map should load")
	var map_data: Dictionary = loaded.get("data", {}) as Dictionary
	var state := GameState.new()
	state.load_from_map_dict(map_data.duplicate(true))
	_assert_true(state.find_hive_by_id(3) != null, "Delta H3 should exist")
	_assert_true(state.find_hive_by_id(9) != null, "Delta H9 should exist")
	_assert_true(state.can_connect(3, 9), "Delta H3 to H9 should be a legal line-of-sight route")

	var ops_node: Node = _ops_state_node()
	ops_node.call("reset_state_from_map", map_data.duplicate(true))
	var ops_state: GameState = ops_node.call("get_state") as GameState
	_assert_true(ops_state != null, "OpsState should reset from Delta map")
	var h3: HiveData = ops_state.find_hive_by_id(3)
	var h9: HiveData = ops_state.find_hive_by_id(9)
	_assert_true(h3 != null and h9 != null, "OpsState Delta H3/H9 should exist")
	h3.owner_id = 1
	h3.power = 10
	h9.owner_id = 2
	h9.power = 5
	ops_node.set("match_phase", 1)
	ops_node.set("input_locked", false)
	ops_node.set("input_locked_reason", "")
	var result: Dictionary = ops_node.call("apply_lane_intent", 3, 9, "attack") as Dictionary
	_assert_true(bool(result.get("ok", false)), "OpsState should accept Delta H3 to H9 attack: %s" % str(result))

func _ops_state_node() -> Node:
	var existing: Node = get_root().get_node_or_null("OpsState")
	if existing != null:
		return existing
	var node: Node = OPS_STATE_SCRIPT.new()
	node.name = "OpsState"
	get_root().add_child(node)
	_created_ops_node = node
	return node

func _cleanup() -> void:
	if _created_ops_node != null and is_instance_valid(_created_ops_node):
		_created_ops_node.queue_free()
		_created_ops_node = null

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
	push_error("SWARM_CAPTURE_AND_DELTA_LANE_SMOKE: %s" % message)
