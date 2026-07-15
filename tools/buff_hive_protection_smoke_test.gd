extends SceneTree

const BuffSystem := preload("res://scripts/sim/authoritative_buff_system.gd")

var _failed: bool = false

func _init() -> void:
	_test_single_and_global_shields()
	_test_single_and_global_shock_immunity()
	if _failed:
		quit(1)
		return
	print("BUFF_HIVE_PROTECTION_SMOKE: PASS")
	quit(0)

func _test_single_and_global_shields() -> void:
	var state := _state()
	var units := UnitSystem.new()
	units.bind_state(state)
	var activated: Dictionary = BuffSystem.activate(state, _command("shield-single", "buff_hive_shield_single_classic", "hive", 1))
	_expect(bool(activated.get("ok", false)), "single Hive Shield activates")
	var hive: HiveData = state.find_hive_by_id(1)
	var before_power: int = int(hive.power)
	units._apply_unit_arrival(_arrival(2, 1, 7))
	_expect(int(hive.owner_id) == 1 and int(hive.power) == before_power, "shield consumes enemy landing units with zero damage or capture")
	units._apply_unit_arrival(_arrival(1, 1, 2))
	_expect(int(hive.power) == before_power + 2, "shield does not block friendly feeding")

	var global_state := _state()
	var global_units := UnitSystem.new()
	global_units.bind_state(global_state)
	var global_result: Dictionary = BuffSystem.activate(global_state, _command("shield-global", "buff_hive_shield_global_classic", "global", "global"))
	_expect(bool(global_result.get("ok", false)), "global Hive Shield activates")
	var protected_hive: HiveData = global_state.find_hive_by_id(1)
	var protected_power: int = int(protected_hive.power)
	global_units._apply_unit_arrival(_arrival(2, 1, 20))
	_expect(int(protected_hive.power) == protected_power, "activation-time owned hive is globally shielded")
	var newly_captured: HiveData = global_state.find_hive_by_id(3)
	newly_captured.owner_id = 1
	newly_captured.power = 10
	global_units._apply_unit_arrival(_arrival(2, 3, 3))
	_expect(int(newly_captured.power) == 7, "new capture does not inherit an existing global shield")
	protected_hive.owner_id = 2
	_expect(not BuffSystem.hive_is_shielded(global_state, 1, 1), "ownership loss removes global shield protection immediately")
	global_state.tick = 1
	BuffSystem.tick(global_state)
	var global_effect: Dictionary = BuffSystem.active_effect(global_state, 1, "HIVE_SHIELD_GLOBAL")
	_expect(not (global_effect.get("scoped_hive_ids", []) as Array).has(1), "lost hive is pruned from the authoritative global scope")

func _test_single_and_global_shock_immunity() -> void:
	var baseline := _state()
	var baseline_swarm := SwarmSystem.new()
	baseline_swarm.bind_state(baseline)
	baseline_swarm._spawn_swarm(1, 2)
	_expect(int(baseline.hive_spawn_block_until_us.get(1, 0)) > 0, "ordinary swarm launch applies source spawn shock")

	var single_state := _state()
	var single_swarm := SwarmSystem.new()
	single_swarm.bind_state(single_state)
	var single: Dictionary = BuffSystem.activate(single_state, _command("shock-single", "buff_shock_immunity_classic", "hive", 1))
	_expect(bool(single.get("ok", false)), "single Shock Immunity activates")
	var before_power: int = int((single_state.find_hive_by_id(1) as HiveData).power)
	single_swarm._spawn_swarm(1, 2)
	_expect(not single_state.hive_spawn_block_until_us.has(1), "immune source receives no swarm-launch spawn penalty")
	_expect(single_state.swarm_packets.size() == 1 and int((single_state.find_hive_by_id(1) as HiveData).power) < before_power, "immunity changes only shock; swarm launch and power spend still occur")

	var global_state := _state()
	var global_swarm := SwarmSystem.new()
	global_swarm.bind_state(global_state)
	var global: Dictionary = BuffSystem.activate(global_state, _command("shock-global", "buff_global_shock_immunity_classic", "global", "global"))
	_expect(bool(global.get("ok", false)), "global Shock Immunity activates")
	global_swarm._spawn_swarm(1, 2)
	_expect(not global_state.hive_spawn_block_until_us.has(1), "snapshotted source receives global shock immunity")
	(global_state.find_hive_by_id(3) as HiveData).owner_id = 1
	_expect(not BuffSystem.hive_is_shock_immune(global_state, 1, 3), "new capture does not inherit existing global shock immunity")

func _state() -> GameState:
	var state := GameState.new()
	state.init_demo_map()
	state.rebuild_indexes()
	return state

func _arrival(owner_id: int, to_id: int, amount: int) -> Dictionary:
	return {
		"owner_id": owner_id,
		"from_id": 4,
		"to_id": to_id,
		"amount": amount,
		"ordinary_count": amount,
		"enhanced_full_count": 0,
		"enhanced_spent_count": 0,
		"skip_pressure": true,
		"arrive_source": "unit_system"
	}

func _command(id: String, buff_id: String, target_type: String, target_id: Variant) -> Dictionary:
	return {
		"match_id": "hive-protection",
		"activation_id": id,
		"command_id": id,
		"owner_id": 1,
		"buff_id": buff_id,
		"tier": "classic",
		"target_type": target_type,
		"target_id": target_id
	}

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_HIVE_PROTECTION_SMOKE: %s" % label)
