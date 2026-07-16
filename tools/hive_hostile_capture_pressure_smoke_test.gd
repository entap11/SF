extends SceneTree

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := GameState.new()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 6, "Hive"),
		HiveData.new(2, Vector2i(4, 0), 2, 20, "Hive"),
		HiveData.new(3, Vector2i(8, 0), 0, 8, "npc_hive")
	]
	state.lanes = [
		LaneData.new(1, 1, 2, 1, false, true, 0.0, 0.0, 0.0, 0.0, 1.0, 0.5, false, false, 0, 0.0, 0.0, false, false, 7),
		LaneData.new(2, 2, 3, 1, true, false, 0.0, 0.0, 0.0, 0.0, 1.0, 0.5, false, false, 0, 0.0, 0.0, false, false, 9)
	]
	state.rebuild_indexes()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)

	# An active send with no committed unit is deliberately insufficient.
	_expect(_projection(unit_system).is_empty(), "empty active lane flow must not create pressure")

	unit_system.units = [_unit(10, 2, 1, 2, 1, 7, 0.5)]
	_expect(bool(_projection(unit_system).get(1, false)), "live hostile unit with a valid route must create pressure")

	unit_system.units = [_unit(19, 2, 2, 1, 1, 7, 0.5)]
	_expect(_projection(unit_system).is_empty(), "redirected unit whose current destination is allied must not create pressure")

	unit_system.units = [_unit(11, 1, 1, 2, 1, 7, 0.5)]
	_expect(_projection(unit_system).is_empty(), "allied unit must not create pressure")

	unit_system.units = [_unit(12, 2, 1, 2, 1, 7, 0.5, 0)]
	_expect(_projection(unit_system).is_empty(), "zero-force unit must not create pressure")

	unit_system.units = [_unit(13, 2, 1, 999, 1, 7, 0.5)]
	_expect(_projection(unit_system).is_empty(), "unit on a removed or invalid lane must not create pressure")

	unit_system.units = [_unit(14, 2, 1, 2, 1, 6, 0.5)]
	_expect(_projection(unit_system).is_empty(), "stale lane generation must not create pressure")

	unit_system.units = [_unit(15, 2, 1, 2, 1, 7, 0.0)]
	_expect(_projection(unit_system).is_empty(), "already-arrived unit outside resolution must not create pressure")

	var recalled: Dictionary = _unit(16, 1, 1, 2, 1, 7, 0.5)
	recalled["returning"] = true
	recalled["arrive_source"] = "recall"
	unit_system.units = [recalled]
	_expect(_projection(unit_system).is_empty(), "recalled allied unit must not create pressure")

	unit_system.units = [_unit(17, 2, 3, 2, 2, 9, 0.5)]
	_expect(_projection(unit_system).is_empty(), "neutral target must not receive player-hive capture pressure")

	unit_system.units = []
	unit_system.set("_current_arrivals_by_hive", {
		1: [_unit(18, 2, 1, 2, 1, 7, 1.0)]
	})
	_expect(bool(_projection(unit_system).get(1, false)), "hostile unit resolving an impact must create pressure")
	unit_system.set("_current_arrivals_by_hive", {})

	var many_units: Array = []
	for i in range(400):
		many_units.append(_unit(1000 + i, 2, 1, 2, 1, 7, 0.25 + (float(i % 50) * 0.01)))
	unit_system.units = many_units
	var before_units: Array = unit_system.units.duplicate(true)
	var before_owner: int = int((state.hives[0] as HiveData).owner_id)
	var before_power: int = int((state.hives[0] as HiveData).power)
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	var previous_ops_state: Variant = ops_state.get("state") if ops_state != null else null
	if ops_state != null:
		ops_state.set("state", state)
	var authority_before: Dictionary = ops_state.call("get_authority_snapshot") as Dictionary if ops_state != null else {}
	var contract_hash_before: String = str(ops_state.call("get_contract_state_hash")) if ops_state != null else ""
	var large_projection: Dictionary = _projection(unit_system)
	var authority_after: Dictionary = ops_state.call("get_authority_snapshot") as Dictionary if ops_state != null else {}
	var contract_hash_after: String = str(ops_state.call("get_contract_state_hash")) if ops_state != null else ""
	if ops_state != null:
		ops_state.set("state", previous_ops_state)
	var profile: Dictionary = unit_system.get_hive_hostile_capture_pressure_profile()
	_expect(bool(large_projection.get(1, false)), "large fixture must retain the correct threatened hive")
	_expect(int(profile.get("unit_count", 0)) == 400, "projection must scan the bounded large fixture once")
	_expect(int(profile.get("lane_count", 0)) == 2, "projection must build one bounded lane lookup")
	_expect(unit_system.units == before_units, "projection must not mutate authoritative units")
	_expect(
		int((state.hives[0] as HiveData).owner_id) == before_owner
		and int((state.hives[0] as HiveData).power) == before_power,
		"projection must not mutate hive ownership or power"
	)
	_expect(authority_after == authority_before, "projection must not change the authority snapshot or network payload")
	_expect(contract_hash_after == contract_hash_before, "projection must not change the deterministic contract hash")

	if _failed:
		state.unit_system = null
		unit_system.state = null
		unit_system.units.clear()
		quit(1)
		return
	print("HIVE_HOSTILE_CAPTURE_PRESSURE_SMOKE: PASS profile=", profile)
	state.unit_system = null
	unit_system.state = null
	unit_system.units.clear()
	quit(0)

func _projection(unit_system: UnitSystem) -> Dictionary:
	return unit_system.build_hive_hostile_capture_pressure_projection()

func _unit(
	id: int,
	owner_id: int,
	to_id: int,
	from_id: int,
	lane_id: int,
	lane_generation: int,
	t: float,
	amount: int = 1
) -> Dictionary:
	return {
		"id": id,
		"owner_id": owner_id,
		"combat_allegiance_id": owner_id,
		"from_id": from_id,
		"to_id": to_id,
		"a_id": 1 if lane_id == 1 else 2,
		"b_id": 2 if lane_id == 1 else 3,
		"lane_id": lane_id,
		"lane_generation": lane_generation,
		"dir": -1 if from_id == 2 and to_id == 1 else 1,
		"t": t,
		"amount": amount,
		"from_pos": Vector2.ZERO,
		"to_pos": Vector2(100.0, 0.0),
		"pos": Vector2(100.0 * t, 0.0)
	}

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("HIVE_HOSTILE_CAPTURE_PRESSURE_SMOKE: %s" % message)
