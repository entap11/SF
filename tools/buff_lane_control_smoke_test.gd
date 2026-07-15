extends SceneTree

const BuffSystem := preload("res://scripts/sim/authoritative_buff_system.gd")
const SimTuningRef := preload("res://scripts/sim/sim_tuning.gd")

var _failed: bool = false

func _init() -> void:
	_test_freeze_movement_combat_and_swarm_exclusion()
	_test_treacherous_existing_and_new_units()
	if _failed:
		quit(1)
		return
	print("BUFF_LANE_CONTROL_SMOKE: PASS")
	quit(0)

func _test_freeze_movement_combat_and_swarm_exclusion() -> void:
	var state := _state()
	var units := UnitSystem.new()
	units.bind_state(state)
	units.spawn_unit(_unit(state, 1, 1, 2, 1, 0.2))
	units.spawn_unit(_unit(state, 1, 2, 1, 2, 0.8))
	var freeze: Dictionary = BuffSystem.activate(state, _command("freeze", "buff_freeze_lane_classic", 1))
	_expect(bool(freeze.get("ok", false)), "Freeze Lane activates on any active lane")
	var own_before: float = float((units.units[0] as Dictionary).get("t", 0.0))
	var enemy_before: float = float((units.units[1] as Dictionary).get("t", 0.0))
	units._update_units(0.1)
	_expect(float((units.units[0] as Dictionary).get("t", 0.0)) > own_before, "activating-player ordinary unit continues advancing")
	_expect(is_equal_approx(float((units.units[1] as Dictionary).get("t", 0.0)), enemy_before), "existing enemy ordinary unit spends no movement while frozen")
	units.spawn_unit(_unit(state, 1, 2, 1, 2, 0.7))
	var entering_before: float = float((units.units[2] as Dictionary).get("t", 0.0))
	units._update_units(0.1)
	_expect(is_equal_approx(float((units.units[2] as Dictionary).get("t", 0.0)), entering_before), "enemy unit entering during active window is also frozen")
	var effect: Dictionary = BuffSystem.active_effect(state, 1, "FREEZE_LANE")
	state.tick = int(effect.get("expires_tick", 50))
	BuffSystem.tick(state)
	var resume_before: float = float((units.units[1] as Dictionary).get("t", 0.0))
	units._update_units(0.1)
	var resume_after: float = float((units.units[1] as Dictionary).get("t", 0.0))
	_expect(resume_after < resume_before, "expiration resumes enemy movement")
	_expect(resume_before - resume_after < 0.25, "expiration applies only the current tick movement budget with no accumulated jump")

	var combat_state := _state()
	var combat_units := UnitSystem.new()
	combat_units.bind_state(combat_state)
	combat_units.spawn_unit(_unit(combat_state, 1, 1, 2, 1, 0.5))
	combat_units.spawn_unit(_unit(combat_state, 1, 2, 1, 2, 0.5))
	BuffSystem.activate(combat_state, _command("freeze-fight", "buff_freeze_lane_classic", 1))
	combat_units.resolve_lane_interactions(combat_state, 0)
	_expect(combat_units.units.is_empty(), "frozen enemy ordinary unit still participates in lane combat")

	var swarm_state := _state()
	var swarm_units := UnitSystem.new()
	swarm_units.bind_state(swarm_state)
	var swarm := SwarmSystem.new()
	swarm.bind_state(swarm_state)
	BuffSystem.activate(swarm_state, _command("freeze-swarm", "buff_freeze_lane_classic", 1))
	swarm._spawn_swarm(1, 2)
	var swarm_before: float = float((swarm_state.swarm_packets[0] as Dictionary).get("t", 0.0))
	swarm._update_swarms(0.1, swarm_units)
	_expect(float((swarm_state.swarm_packets[0] as Dictionary).get("t", 0.0)) > swarm_before, "manual swarm movement is unaffected by Freeze Lane")

func _test_treacherous_existing_and_new_units() -> void:
	var state := _state()
	(state.find_hive_by_id(2) as HiveData).owner_id = 2
	var units := UnitSystem.new()
	units.bind_state(state)
	units.spawn_unit(_unit(state, 1, 2, 1, 2, 0.8))
	units.spawn_unit(_unit(state, 1, 1, 2, 1, 0.2))
	var treacherous: Dictionary = BuffSystem.activate(state, _command("treacherous", "buff_treacherous_lane_classic", 1))
	_expect(bool(treacherous.get("ok", false)), "Treacherous Lane activates on any active lane")
	var existing_enemy: Dictionary = units.units[0] as Dictionary
	var own_unit: Dictionary = units.units[1] as Dictionary
	_expect(bool(existing_enemy.get("treacherous_committed", false)) and int(existing_enemy.get("treacherous_origin_hive_id", -1)) == 2, "existing enemy immediately commits to its producing hive identity")
	_expect(int(existing_enemy.get("dir", 0)) == 1 and int(existing_enemy.get("to_id", -1)) == 2, "existing enemy immediately U-turns toward its origin")
	_expect(not bool(own_unit.get("treacherous_committed", false)) and int(own_unit.get("dir", 0)) == 1, "activating-player unit remains unaffected")

	units.spawn_unit(_unit(state, 1, 2, 1, 2, 0.9))
	var new_index: int = units.units.size() - 1
	var new_enemy: Dictionary = units.units[new_index] as Dictionary
	_expect(bool(new_enemy.get("treacherous_pending", false)) and not bool(new_enemy.get("treacherous_committed", false)), "new enemy production is stamped with pending betrayal")
	var lane_len: float = units._unit_lane_len(new_enemy)
	var start_t: float = float(new_enemy.get("t", 0.0))
	var ten_px_dt: float = 10.0 / float(SimTuningRef.UNIT_SPEED_PX_PER_SEC)
	units._update_units(ten_px_dt)
	new_enemy = units.units[new_index] as Dictionary
	_expect(bool(new_enemy.get("treacherous_pending", false)) and is_equal_approx(float(new_enemy.get("treacherous_clearance_remaining_px", 0.0)), 5.0), "new enemy travels the first ten simulation pixels before turning")
	units._update_units(ten_px_dt)
	new_enemy = units.units[new_index] as Dictionary
	var traveled_px: float = absf(float(new_enemy.get("t", 0.0)) - start_t) * lane_len
	_expect(bool(new_enemy.get("treacherous_committed", false)) and int(new_enemy.get("dir", 0)) == 1, "new enemy U-turns after its clearance distance")
	_expect(is_equal_approx(traveled_px, 15.0), "turn point is exactly fifteen simulation-space pixels from source")

	var effect: Dictionary = BuffSystem.active_effect(state, 1, "TREACHEROUS_LANE")
	state.tick = int(effect.get("expires_tick", 50))
	BuffSystem.tick(state)
	var committed_before: float = float(new_enemy.get("t", 0.0))
	units._update_units(ten_px_dt)
	new_enemy = units.units[new_index] as Dictionary
	_expect(bool(new_enemy.get("treacherous_committed", false)) and float(new_enemy.get("t", 0.0)) > committed_before, "turned unit remains committed and moves home after effect expiration")
	units.spawn_unit(_unit(state, 1, 2, 1, 2, 0.9))
	var post_expiry: Dictionary = units.units[units.units.size() - 1] as Dictionary
	_expect(not bool(post_expiry.get("treacherous_pending", false)) and int(post_expiry.get("dir", 0)) == -1, "enemy production after expiration behaves normally")

	var origin: HiveData = state.find_hive_by_id(2)
	origin.owner_id = 2
	origin.power = 10
	var arrival: Dictionary = existing_enemy.duplicate(true)
	arrival["amount"] = 3
	arrival["ordinary_count"] = 3
	arrival["skip_pressure"] = true
	units._apply_unit_arrival(arrival)
	_expect(int(origin.owner_id) == 2 and int(origin.power) == 7, "betrayed units damage their own origin instead of reinforcing it")

func _state() -> GameState:
	var state := GameState.new()
	state.init_demo_map()
	state.rebuild_indexes()
	return state

func _unit(state: GameState, lane_id: int, from_id: int, to_id: int, owner_id: int, t: float) -> Dictionary:
	var lane: LaneData = state.find_lane_by_id(lane_id)
	return {
		"lane_id": lane_id,
		"a_id": int(lane.a_id),
		"b_id": int(lane.b_id),
		"from_id": from_id,
		"to_id": to_id,
		"owner_id": owner_id,
		"amount": 1,
		"dir": 1 if from_id == int(lane.a_id) else -1,
		"t": t,
		"arrive_source": "lane"
	}

func _command(id: String, buff_id: String, lane_id: int) -> Dictionary:
	return {
		"match_id": "lane-control",
		"activation_id": id,
		"command_id": id,
		"owner_id": 1,
		"buff_id": buff_id,
		"tier": "classic",
		"target_type": "lane",
		"target_id": lane_id
	}

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_LANE_CONTROL_SMOKE: %s" % label)
