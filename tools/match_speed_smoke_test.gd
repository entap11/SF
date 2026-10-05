extends SceneTree

const BuffSystem := preload("res://scripts/sim/authoritative_buff_system.gd")
var failures := 0
var ops: Node

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("MATCH_SPEED_SMOKE: " + message)

func _run() -> void:
	ops = root.get_node("OpsState")
	check(not str(ops.call("get_pvp_debug_state_hash")).is_empty(), "debug hash must work before a map exists")
	check(is_equal_approx(SimTuning.UNIT_SPEED_PX_PER_SEC, 194.04 * 1.15), "base speed must increase exactly 15 percent")
	var base := _measure("base", false, 2)
	var fast := _measure("fast", false, 2)
	var buffed := _measure("fast", true, 2)
	var fast_one_step := _measure("fast", false, 1)
	check(is_equal_approx(base.unit_distance, 223.146 * 0.2), "base ordinary unit must move the expected distance")
	check(is_equal_approx(fast.unit_distance, base.unit_distance * 1.5), "fast ordinary units must move 50 percent farther")
	check(is_equal_approx(fast.swarm_distance, base.swarm_distance * 1.5), "fast swarms must move 50 percent farther")
	check(is_equal_approx(fast.swarm_distance, fast.unit_distance * 2.0), "swarm-to-unit speed ratio must remain two")
	check(is_equal_approx(buffed.unit_distance, fast.unit_distance * 1.25), "existing speed buff must multiply fast mode")
	check(is_equal_approx(fast_one_step.unit_distance, fast.unit_distance), "movement must depend on simulation elapsed time, not step count")
	check(is_equal_approx(fast_one_step.swarm_distance, fast.swarm_distance), "swarm movement must depend on simulation elapsed time")
	_test_authority()
	print("MATCH_SPEED_SMOKE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _map() -> Dictionary:
	return {"map_id": "match_speed_smoke", "hives": [
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
		{"id": 2, "x": 30, "y": 0, "owner_id": 2, "power": 50, "kind": "Hive"}
	], "lane_candidates": [{"a_id": 1, "b_id": 2}]}

func _measure(mode: String, buffed: bool, steps: int) -> Dictionary:
	var state: GameState = ops.call("reset_state_from_map", _map())
	check(ops.call("configure_match_speed", mode).ok, "prematch setup must accept " + mode)
	state.lanes = [LaneData.new(1, 1, 2, 1, true, false)]
	state.rebuild_indexes()
	var units := UnitSystem.new()
	units.bind_state(state)
	var swarms := SwarmSystem.new()
	swarms.bind_state(state)
	swarms._spawn_swarm(1, 2)
	check(swarms.swarm_packets.size() == 1, "swarm fixture must spawn")
	var swarm_start: Vector2 = swarms.swarm_packets[0].pos
	if buffed:
		var result := BuffSystem.activate(state, {"match_id": "speed", "activation_id": "speed-buff", "command_id": "speed-buff", "owner_id": 1,
			"buff_id": "buff_unit_speed_classic", "tier": "classic", "target_type": "hive", "target_id": 1})
		check(result.ok, "speed buff fixture must activate")
	check(units.spawn_unit({"lane_id": 1, "a_id": 1, "b_id": 2, "from_id": 1, "to_id": 2,
		"owner_id": 1, "amount": 1, "dir": 1, "t": 0.0, "arrive_source": "lane"}), "unit fixture must spawn")
	var unit_start: Vector2 = units.units[0].pos
	for index in range(steps):
		units._update_units(0.2 / float(steps))
		swarms._update_swarms(0.2 / float(steps), null)
	var result := {"unit_distance": unit_start.distance_to(units.units[0].pos),
		"swarm_distance": swarm_start.distance_to(swarms.swarm_packets[0].pos)}
	units.state = null
	state.unit_system = null
	swarms.state = null
	return result

func _test_authority() -> void:
	var state: GameState = ops.call("reset_state_from_map", _map())
	check(state.match_speed_mode == "base", "new matches must reset to base")
	var base_hash: String = ops.call("get_contract_state_hash")
	var base_debug_hash: String = ops.call("get_pvp_debug_state_hash")
	var duration: int = ops.match_duration_ms
	var time_scale: float = Engine.time_scale
	check(not ops.call("configure_match_speed", "turbo").ok, "unknown modes must reject")
	check(ops.call("get_contract_state_hash") == base_hash, "invalid selection must not mutate state")
	check(ops.call("configure_match_speed", "fast").ok, "fast must configure before match start")
	check(ops.match_duration_ms == duration and Engine.time_scale == time_scale, "movement mode must not alter match duration or engine clock")
	var fast_hash: String = ops.call("get_contract_state_hash")
	check(fast_hash != base_hash, "speed mode must participate in synchronization hash")
	check(ops.call("get_pvp_debug_state_hash") != base_debug_hash, "debug synchronization hash must also include speed mode")
	var snapshot: Dictionary = ops.call("get_authority_snapshot")
	check(snapshot.state.match_speed_mode == "fast", "snapshot must retain fast mode")
	check(ops.call("configure_match_speed", "base").ok, "prematch can return to base")
	check(ops.call("restore_authority_snapshot", snapshot, false), "snapshot restore must succeed")
	check(state.match_speed_mode == "fast" and ops.call("get_contract_state_hash") == fast_hash, "restore must recover exact speed and hash")
	var invalid := snapshot.duplicate(true)
	invalid.state.match_speed_mode = "turbo"
	check(not ops.call("restore_authority_snapshot", invalid, false), "snapshot with unknown speed must reject")
	check(ops.call("get_contract_state_hash") == fast_hash, "rejected snapshot must not mutate authority")
	var legacy := snapshot.duplicate(true)
	legacy.state.erase("match_speed_mode")
	check(ops.call("restore_authority_snapshot", legacy, false), "old snapshot without speed must restore")
	check(state.match_speed_mode == "base", "old snapshots must default to base")
	ops.match_phase = ops.MatchPhase.RUNNING
	check(not ops.call("configure_match_speed", "fast").ok, "running matches must reject local speed changes")
	ops.match_phase = ops.MatchPhase.PREMATCH
	state.tick = 10
	check(not ops.call("configure_match_speed", "fast").ok, "resumed matches in countdown must reject speed changes")
	state = ops.call("reset_state_from_map", _map())
	check(state.match_speed_mode == "base", "next game must not inherit the previous selection")
