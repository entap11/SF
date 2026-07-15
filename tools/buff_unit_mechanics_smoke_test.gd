extends SceneTree

const BuffSystem := preload("res://scripts/sim/authoritative_buff_system.gd")

var _failed: bool = false

func _init() -> void:
	_test_swarm_damage()
	_test_hive_impact_cohorts()
	_test_speed_stamp()
	if _failed:
		quit(1)
		return
	print("BUFF_UNIT_MECHANICS_SMOKE: PASS")
	quit(0)

func _test_swarm_damage() -> void:
	var state := _state()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	var swarm_system := SwarmSystem.new()
	swarm_system.bind_state(state)
	var activated: Dictionary = BuffSystem.activate(state, _command("swarm", "buff_swarm_damage_classic", "global", "global"))
	_expect(bool(activated.get("ok", false)), "Swarm Damage activates")
	var target: HiveData = state.find_hive_by_id(4)
	target.power = 30
	swarm_system._apply_swarm_arrival({
		"id": 1,
		"from_id": 1,
		"to_id": 4,
		"owner_id": 1,
		"count": 10,
		"damage_multiplier": BuffSystem.manual_swarm_damage_multiplier(state, 1),
		"lane_id": 4,
		"a_id": 1,
		"b_id": 4,
		"dir": 1
	}, unit_system)
	_expect(int(target.power) == 10, "manual swarm strength ten deals exactly twenty hive damage")

func _test_hive_impact_cohorts() -> void:
	var state := _state()
	var activated: Dictionary = BuffSystem.activate(state, _command("impact", "buff_hive_impact_damage_classic", "global", "global"))
	_expect(bool(activated.get("ok", false)), "Hive Impact activates")
	var stamped: Dictionary = BuffSystem.stamp_ordinary_unit(state, {"owner_id": 1, "from_id": 1, "amount": 1})
	_expect(int(stamped.get("enhanced_full_count", 0)) == 1, "new ordinary unit is stamped as an untouched enhanced cohort")
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	var untouched: Dictionary = unit_system._apply_cohort_damage(stamped.duplicate(true), 0)
	var after_one: Dictionary = unit_system._apply_cohort_damage(stamped.duplicate(true), 1)
	var after_two: Dictionary = unit_system._apply_cohort_damage(stamped.duplicate(true), 2)
	_expect(_impact_strength(untouched) == 2, "untouched enhanced unit retains two hive impact")
	_expect(_impact_strength(after_one) == 1 and int(after_one.get("amount", 0)) == 1, "one enemy dies and enhanced unit survives with one strength")
	_expect(_impact_strength(after_two) == 0 and int(after_two.get("amount", 0)) == 0, "second enemy encounter cancels the enhanced unit")
	var target: HiveData = state.find_hive_by_id(4)
	target.power = 5
	unit_system._apply_unit_arrival({
		"owner_id": 1,
		"from_id": 1,
		"to_id": 4,
		"lane_id": 4,
		"a_id": 1,
		"b_id": 4,
		"dir": 1,
		"amount": 1,
		"ordinary_count": 0,
		"enhanced_full_count": 1,
		"enhanced_spent_count": 0
	})
	_expect(int(target.power) == 3, "direct untouched enhanced arrival applies two hive damage")

func _test_speed_stamp() -> void:
	var state := _state()
	var before: Dictionary = BuffSystem.stamp_ordinary_unit(state, {"owner_id": 1, "from_id": 1, "amount": 1})
	var activated: Dictionary = BuffSystem.activate(state, _command("speed", "buff_unit_speed_classic", "hive", 1))
	_expect(bool(activated.get("ok", false)), "Unit Speed activates on an owned hive")
	var selected: Dictionary = BuffSystem.stamp_ordinary_unit(state, {"owner_id": 1, "from_id": 1, "amount": 1})
	var other: Dictionary = BuffSystem.stamp_ordinary_unit(state, {"owner_id": 1, "from_id": 3, "amount": 1})
	_expect(int(before.get("speed_permille", 0)) == 1000, "existing unit does not acquire Unit Speed")
	_expect(int(selected.get("speed_permille", 0)) == 1250, "new unit from selected hive receives exact 1.25 speed stamp")
	_expect(int(other.get("speed_permille", 0)) == 1000, "new unit from another hive remains normal speed")

func _state() -> GameState:
	var state := GameState.new()
	state.init_demo_map()
	state.rebuild_indexes()
	return state

func _command(id: String, buff_id: String, target_type: String, target_id: Variant) -> Dictionary:
	return {
		"match_id": "unit-mechanics",
		"activation_id": id,
		"command_id": id,
		"owner_id": 1,
		"buff_id": buff_id,
		"tier": "classic",
		"target_type": target_type,
		"target_id": target_id
	}

func _impact_strength(unit: Dictionary) -> int:
	return int(unit.get("ordinary_count", 0)) + int(unit.get("enhanced_full_count", 0)) * 2 + int(unit.get("enhanced_spent_count", 0))

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_UNIT_MECHANICS_SMOKE: %s" % label)
