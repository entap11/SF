extends SceneTree

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const OPS_STATE_SCRIPT := preload("res://scripts/ops/ops_state.gd")
const SWARM_SYSTEM_SCRIPT := preload("res://scripts/systems/swarm_system.gd")
const DELTA_MAP_PATH := "res://maps/delta/MAP_delta__SBASE__3p.json"

var _failed: bool = false
var _created_ops_node: Node = null

func _init() -> void:
	await process_frame
	_test_friendly_swarm_adds_five_each_relay()
	_test_chain_limits()
	_test_full_and_partial_hive_relay()
	_test_expired_swarm_overflow_train()
	_test_swarm_overflow_capacity_and_routes()
	_test_swarm_overflow_ownership_and_reset()
	_test_swarm_overflow_fights_ordinary_units()
	_test_swarm_overflow_snapshot()
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

func _friendly_chain_fixture(relay_power: int = 10) -> Dictionary:
	var state := GameState.new()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 20, "Hive"),
		HiveData.new(2, Vector2i(5, 0), 1, relay_power, "Hive"),
		HiveData.new(3, Vector2i(10, 0), 1, 10, "Hive"),
		HiveData.new(4, Vector2i(15, 0), 2, 30, "Hive")]
	state.lanes = [LaneData.new(1, 1, 2, 1, true, false), LaneData.new(2, 2, 3, 1, true, false), LaneData.new(3, 3, 4, 1, true, false)]
	state.rebuild_indexes()
	var units := UnitSystem.new()
	units.bind_state(state)
	var swarms := SwarmSystem.new()
	swarms.bind_state(state)
	return {"state": state, "units": units, "swarms": swarms}

func _land_chain_packet(h: Dictionary, count: int = 7) -> void:
	h.swarms._apply_swarm_arrival({"id": 99, "from_id": 1, "to_id": 2,
		"owner_id": 1, "count": count, "lane_id": 1, "a_id": 1, "b_id": 2, "dir": 1}, h.units)

func _test_friendly_swarm_adds_five_each_relay() -> void:
	var h := _friendly_chain_fixture()
	h.swarms._spawn_swarm(1, 2)
	_assert_eq(h.swarms.swarm_packets[0].count, 5, "fresh swarm starts with five")
	h.units.units.append({"lane_id": 1, "owner_id": 1, "from_id": 1, "to_id": 2, "dir": 1, "t": 0.5, "amount": 2})
	h.state.lanes[0].a_pressure = 2
	h.swarms._update_swarms(10.0, h.units)
	_assert_eq(h.state.find_hive_by_id(2).power, 17, "first swarm lands five plus two pickups")
	h.swarms._spawn_swarm(2, 3)
	_assert_eq(h.swarms.swarm_packets[0].count, 12, "relay adds five to the seven arriving bees")
	_assert_eq(h.state.find_hive_by_id(2).power, 5, "relay debits the full outgoing swarm")
	h.units.units.append({"lane_id": 2, "owner_id": 1, "from_id": 2, "to_id": 3, "dir": 1, "t": 0.5, "amount": 3})
	h.state.lanes[1].a_pressure = 3
	h.swarms._update_swarms(10.0, h.units)
	_assert_eq(h.state.find_hive_by_id(3).power, 25, "second leg picks up three more bees")
	h.swarms._spawn_swarm(3, 4)
	_assert_eq(h.swarms.swarm_packets[0].count, 20, "third launch adds another five")
	_assert_eq(h.state.find_hive_by_id(3).power, 5, "third launch conserves power")
	_assert_eq(h.units.units.size(), 0, "picked-up bees must leave unit state")
	h.swarms._spawn_swarm(2, 3)
	_assert_eq(h.swarms.swarm_packets[1].count, 4, "landed swarm can only be chained once and must leave one power")

func _test_chain_limits() -> void:
	for elapsed_us in [1000000, 1000001]:
		var h := _friendly_chain_fixture()
		_land_chain_packet(h)
		h.state._sim_time_us = elapsed_us
		h.swarms._spawn_swarm(2, 3)
		_assert_eq(h.swarms.swarm_packets[0].count, 12 if elapsed_us == 1000000 else 5, "chain follows the existing one-second simulation window")
	var low := _friendly_chain_fixture(2)
	_land_chain_packet(low)
	low.swarms._spawn_swarm(2, 3)
	_assert_eq(low.swarms.swarm_packets[0].count, 8, "relay cannot spend more power than available")
	_assert_eq(low.state.find_hive_by_id(2).power, 1, "low-power relay leaves one bee")
	var changed := _friendly_chain_fixture()
	_land_chain_packet(changed)
	changed.state.find_hive_by_id(2).owner_id = 2
	changed.swarms._spawn_swarm(2, 3)
	_assert_eq(changed.swarms.swarm_packets[0].count, 5, "a new owner cannot use the old owner's chain")

func _overflow_count(h: Dictionary) -> int:
	var count: int = 0
	for batch in h.state.swarm_overflow_batches:
		count += int(batch.count)
	return count

func _step_units(h: Dictionary, steps: int, dt: float = 0.01) -> void:
	for _index in range(steps):
		h.state._sim_time_us += int(round(dt * 1000000.0))
		h.units.tick(dt)

func _test_full_and_partial_hive_relay() -> void:
	for starting_power in [50, 48]:
		var h := _friendly_chain_fixture(starting_power)
		_land_chain_packet(h)
		_assert_eq(h.state.find_hive_by_id(2).power, 50, "arrival respects hive cap")
		_assert_eq(_overflow_count(h), 7 - (50 - starting_power), "unabsorbed bees remain in authoritative state")
		_step_units(h, 100)
		_assert_eq(h.units.units.size(), 0, "overflow remains available through the exact chaining deadline")
		h.swarms._spawn_swarm(2, 3)
		_assert_eq(h.swarms.swarm_packets[0].count, 12, "full or partially full relay carries all seven plus five")
		_assert_eq(h.state.find_hive_by_id(2).power, starting_power - 5, "relay costs exactly five of the hive's own bees")
		_assert_eq(_overflow_count(h), 0, "chained overflow is consumed once")
		_step_units(h, 60)
		_assert_eq(h.units.units.size(), 0, "chained bees must never also pass through")
	# Multiple arrivals at a full hive must not replace each other's payload.
	var multiple := _friendly_chain_fixture(50)
	_land_chain_packet(multiple, 7)
	_land_chain_packet(multiple, 9)
	multiple.swarms._spawn_swarm(2, 3)
	_assert_eq(multiple.swarms.swarm_packets[0].count, 21, "relay carries all eligible full-hive arrivals")
	_assert_eq(multiple.state.find_hive_by_id(2).power, 45, "multiple arrivals still cost only one contribution")

func _test_expired_swarm_overflow_train() -> void:
	var h := _friendly_chain_fixture(50)
	_land_chain_packet(h)
	_step_units(h, 150)
	_assert_eq(h.state.find_hive_by_id(2).power, 50, "missed relay leaves full hive power unchanged")
	_assert_eq(h.units.units.size(), 7, "all seven bees leave as individual ordinary units")
	_assert_eq(_overflow_count(h), 0, "emitted bees leave the overflow reserve")
	_assert_eq(h.swarms.swarm_packets.size(), 0, "missed timing does not automatically launch a swarm")
	var previous: Vector2 = Vector2.INF
	for unit in h.units.units:
		_assert_eq(int(unit.amount), 1, "train bees are individual units")
		_assert_true(str(unit.arrive_source) == "pass_through", "train uses ordinary pass-through combat")
		_assert_true(not unit.has("impact_strength_override"), "train does not retain swarm damage")
		var pos: Vector2 = unit.pos
		if previous != Vector2.INF:
			var spacing: float = previous.distance_to(pos)
			_assert_true(spacing >= 12.0 and spacing < 14.0, "train must be tightly spaced without overlapping")
		previous = pos
	h.swarms._spawn_swarm(2, 3)
	_assert_eq(h.swarms.swarm_packets[0].count, 5, "expired arrival cannot be claimed as a timed relay")

func _test_swarm_overflow_capacity_and_routes() -> void:
	var h := _friendly_chain_fixture(50)
	h.state.lanes[1].send_a = false
	_land_chain_packet(h)
	h.state._sim_time_us = 1100000
	h.units._drain_swarm_overflow()
	_assert_eq(_overflow_count(h), 7, "no outgoing route must retain overflow")
	h.state.lanes[1].send_a = true
	for index in range(UnitSystem.MAX_ACTIVE_UNITS):
		h.units.units.append({"id": 1000 + index})
	h.units._drain_swarm_overflow()
	_assert_eq(_overflow_count(h), 7, "unit cap must retain overflow")
	h.units.units.clear()
	h.units._drain_swarm_overflow()
	_assert_eq(h.units.units.size(), 1, "capacity recovery releases one bee at the hive edge")
	_assert_eq(_overflow_count(h), 6, "only an emitted bee is debited")
	h.units._drain_swarm_overflow()
	_assert_eq(h.units.units.size(), 1, "repeated drain at the same simulation time cannot overlap bees")
	h.state.find_hive_by_id(2).power = 49
	_step_units(h, 10)
	_assert_eq(_overflow_count(h), 6, "overflow waits while hive is below full power")
	h.state.find_hive_by_id(2).power = 50
	_step_units(h, 50)
	_assert_eq(_overflow_count(h), 0, "retained overflow resumes without loss")
	_assert_eq(h.units.units.size(), 7, "capacity and power pauses must not lose or duplicate bees")

func _test_swarm_overflow_ownership_and_reset() -> void:
	var h := _friendly_chain_fixture(50)
	_land_chain_packet(h)
	h.state.find_hive_by_id(2).owner_id = 2
	h.units._drain_swarm_overflow()
	_assert_eq(_overflow_count(h), 0, "capture clears the previous owner's overflow")
	h.state.find_hive_by_id(2).owner_id = 1
	h.swarms._spawn_swarm(2, 3)
	_assert_eq(h.swarms.swarm_packets[0].count, 5, "recapture cannot restore the old owner's reserve")
	var reset := _friendly_chain_fixture(50)
	_land_chain_packet(reset)
	reset.state.reset_map_only()
	_assert_eq(reset.state.swarm_overflow_batches.size(), 0, "map reset clears pending overflow")
	_assert_eq(reset.state.swarm_overflow_next_emit_us_by_hive.size(), 0, "map reset clears emission timing")

func _test_swarm_overflow_fights_ordinary_units() -> void:
	var h := _friendly_chain_fixture(50)
	h.state.find_hive_by_id(3).owner_id = 2
	_land_chain_packet(h, 1)
	_step_units(h, 101)
	_assert_eq(h.units.units.size(), 1, "one expired bee enters the outgoing lane")
	h.units.spawn_unit({"from_id": 3, "to_id": 2, "owner_id": 2, "amount": 1,
		"lane_id": 2, "a_id": 2, "b_id": 3, "dir": -1, "t": 0.01})
	h.units.resolve_lane_interactions(h.state, h.state._sim_time_us)
	_assert_eq(h.units.units.size(), 0, "overflow bee fights an opposing bee instead of bypassing it")

func _test_swarm_overflow_snapshot() -> void:
	var h := _friendly_chain_fixture(50)
	_land_chain_packet(h)
	h.state._sim_time_us = 500000
	h.state.swarm_overflow_next_emit_us_by_hive[2] = 1100000
	var ops := _ops_state_node()
	var previous_state: GameState = ops.get_state()
	ops.set("state", h.state)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(ops.get_authority_snapshot()))
	var before_hash: String = ops.get_contract_state_hash()
	h.state.swarm_overflow_batches.clear()
	h.state.swarm_overflow_next_emit_us_by_hive.clear()
	_assert_true(ops.get_contract_state_hash() != before_hash, "contract hash includes waiting swarm bees and timing")
	_assert_true(ops.restore_authority_snapshot(snapshot), "overflow snapshot should restore")
	_assert_eq(_overflow_count(h), 7, "snapshot preserves every waiting bee")
	_assert_eq(int(h.state.swarm_overflow_next_emit_us_by_hive.get(2, 0)), 1100000, "JSON snapshot restores integer hive keys and emission deadline")
	_assert_true(ops.get_contract_state_hash() == before_hash, "restored pending overflow has the same authoritative hash")
	_step_units(h, 120)
	_assert_eq(h.units.units.size(), 7, "restored reserve emits exactly once")
	_assert_eq(_overflow_count(h), 0, "restored reserve drains completely")
	ops.set("state", previous_state)
