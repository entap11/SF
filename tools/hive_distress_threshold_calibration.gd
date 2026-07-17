extends SceneTree

var _failed: bool = false
var _next_unit_id: int = 100

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var results: Array[Dictionary] = []
	results.append(await _run_flow("light", 0.55, false))
	results.append(await _run_flow("moderate", 0.30, false))
	results.append(await _run_flow("heavy", 0.14, false))
	results.append(await _run_flow("intermittent_recovery", 0.32, true))

	for result in results:
		var warning_ms: int = int(result.get("critical_to_capture_ms", 0))
		_expect(warning_ms > 0, "%s flow must provide measurable warning time" % str(result.get("flow", "")))
		_expect(int(result.get("critical_power", -1)) == 4, "%s flow must enter critical eruption below power 5" % str(result.get("flow", "")))

	if _failed:
		quit(1)
		return
	print("HIVE_DISTRESS_THRESHOLD_CALIBRATION: PASS ", results)
	quit(0)

func _run_flow(flow_name: String, impact_interval_sec: float, intermittent_recovery: bool) -> Dictionary:
	var state := GameState.new()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 9, "Hive"),
		HiveData.new(2, Vector2i(5, 0), 2, 50, "Hive")
	]
	state.lanes = [
		LaneData.new(1, 1, 2, 1, false, true, 0.0, 0.0, 0.0, 0.0, 1.0, 0.5, false, false, 0, 0.0, 0.0, false, false, 1)
	]
	state.rebuild_indexes()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	unit_system.units = [_future_hostile_unit()]
	var target: HiveData = state.find_hive_by_id(1)
	var started_ms: int = Time.get_ticks_msec()
	var critical_at_ms: int = -1
	var critical_power: int = -1
	var recovered_once: bool = false
	var hit_count: int = 0

	while target != null and int(target.owner_id) == 1:
		await create_timer(impact_interval_sec).timeout
		_apply_arrival(unit_system, 2, 1, 1)
		hit_count += 1
		var now_ms: int = Time.get_ticks_msec()
		if int(target.owner_id) == 1 and int(target.power) < 5 and critical_at_ms < 0:
			critical_at_ms = now_ms
			critical_power = int(target.power)
		if (
			intermittent_recovery
			and not recovered_once
			and int(target.owner_id) == 1
			and int(target.power) == 4
		):
			recovered_once = true
			_apply_arrival(unit_system, 1, 1, 2)
			await create_timer(0.70).timeout

	var captured_ms: int = Time.get_ticks_msec()
	var result := {
		"flow": flow_name,
		"impact_interval_ms": int(round(impact_interval_sec * 1000.0)),
		"hit_count": hit_count,
		"critical_power": critical_power,
		"critical_to_capture_ms": maxi(0, captured_ms - critical_at_ms),
		"total_fixture_ms": captured_ms - started_ms,
		"recovery_injected": recovered_once
	}
	print("HIVE_DISTRESS_THRESHOLD_FLOW ", result)
	state.unit_system = null
	unit_system.state = null
	unit_system.units.clear()
	return result

func _future_hostile_unit() -> Dictionary:
	return {
		"id": 1,
		"owner_id": 2,
		"combat_allegiance_id": 2,
		"from_id": 2,
		"to_id": 1,
		"a_id": 1,
		"b_id": 2,
		"lane_id": 1,
		"lane_generation": 1,
		"dir": -1,
		"t": 0.5,
		"amount": 1,
		"from_pos": Vector2(320.0, 0.0),
		"to_pos": Vector2.ZERO,
		"pos": Vector2(160.0, 0.0)
	}

func _apply_arrival(unit_system: UnitSystem, owner_id: int, to_id: int, amount: int) -> void:
	_next_unit_id += 1
	var unit := {
		"id": _next_unit_id,
		"owner_id": owner_id,
		"combat_allegiance_id": owner_id,
		"from_id": 2 if owner_id == 2 else 1,
		"to_id": to_id,
		"a_id": 1,
		"b_id": 2,
		"lane_id": 1,
		"lane_generation": 1,
		"dir": -1,
		"t": 0.0,
		"amount": amount,
		"impact_strength_override": amount,
		"skip_pressure": true,
		"arrive_source": "threshold_fixture",
		"from_pos": Vector2(320.0, 0.0),
		"to_pos": Vector2.ZERO,
		"pos": Vector2.ZERO
	}
	unit_system.call("_apply_unit_arrival", unit)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("HIVE_DISTRESS_THRESHOLD_CALIBRATION: %s" % message)
