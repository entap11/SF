extends SceneTree

const BuffSystem := preload("res://scripts/sim/authoritative_buff_system.gd")

var _failed: bool = false

func _init() -> void:
	_test_production_scopes_and_progress()
	_test_supercharge_queue_and_release()
	_test_supercharge_source_loss()
	if _failed:
		quit(1)
		return
	print("BUFF_PRODUCTION_SUPERCHARGE_SMOKE: PASS")
	quit(0)

func _test_production_scopes_and_progress() -> void:
	var single_state := _state()
	var single: Dictionary = BuffSystem.activate(single_state, _command("single", "buff_single_production_boost_classic", "hive", 1))
	_expect(bool(single.get("ok", false)), "single-hive production boost activates")
	_expect(BuffSystem.production_time_permille(single_state, 1, 1) == 700, "selected hive receives exact 30 percent production-time reduction")
	_expect(BuffSystem.production_time_permille(single_state, 1, 2) == 1000, "unselected hive remains at baseline")

	var lane: LaneData = single_state.find_lane_by_id(1)
	var hive: HiveData = single_state.find_hive_by_id(1)
	var base_interval: float = float(single_state._spawn_ms_for_hive(int(hive.power)))
	lane.spawn_accum_a_ms = base_interval * 0.4
	single_state.buff_production_interval_ms_by_lane_side["lane:1:a"] = base_interval
	var boosted_interval: float = single_state._effective_spawn_ms(lane, true, hive)
	_expect(is_equal_approx(lane.spawn_accum_a_ms / boosted_interval, 0.4), "boost activation preserves accumulated production fraction")
	single_state.buff_effects_by_activation_id.clear()
	var restored_interval: float = single_state._effective_spawn_ms(lane, true, hive)
	_expect(is_equal_approx(lane.spawn_accum_a_ms / restored_interval, 0.4), "boost expiration preserves accumulated production fraction")

	var global_state := _state()
	var global: Dictionary = BuffSystem.activate(global_state, _command("global", "buff_global_production_boost_classic", "global", "global"))
	_expect(bool(global.get("ok", false)), "global production boost activates")
	_expect(BuffSystem.production_time_permille(global_state, 1, 1) == 700 and BuffSystem.production_time_permille(global_state, 1, 2) == 700, "global boost applies to the activation-time owned-hive snapshot")
	(global_state.find_hive_by_id(3) as HiveData).owner_id = 1
	_expect(BuffSystem.production_time_permille(global_state, 1, 3) == 1000, "new capture does not inherit an existing global boost")
	(global_state.find_hive_by_id(1) as HiveData).owner_id = 2
	_expect(BuffSystem.production_time_permille(global_state, 1, 1) == 1000, "lost snapshotted hive immediately loses the boost")

func _test_supercharge_queue_and_release() -> void:
	var state := _state()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	var activated: Dictionary = BuffSystem.activate(state, _command("super", "buff_supercharge_queue_classic", "lane", 1))
	_expect(bool(activated.get("ok", false)), "Supercharge activates on an eligible lane")
	_expect(unit_system.spawn_unit(_unit(1, 1, 2, 1)), "first matching ordinary unit spawns")
	_expect(unit_system.spawn_unit(_unit(1, 1, 2, 1)), "second matching ordinary unit spawns")
	_expect(unit_system.spawn_unit(_unit(2, 2, 3, 2)), "unrelated ordinary unit spawns")
	var effect: Dictionary = BuffSystem.active_effect(state, 1, "SUPERCHARGE_QUEUE")
	_expect(int(effect.get("queued_units", -1)) == 2, "only exact lane/source/destination production is queued")
	state.tick = int(effect.get("expires_tick", 50))
	var events: Array[Dictionary] = BuffSystem.tick(state)
	_expect(events.size() == 1 and str(events[0].get("event", "")) == "supercharge_released", "Supercharge automatically releases on its fixed expiry tick")
	_expect(int(events[0].get("queued_units", -1)) == 2 and int(events[0].get("released_units", -1)) == 2, "release count exactly matches queued production")
	var train: Array[Dictionary] = []
	for unit_any in unit_system.units:
		var unit: Dictionary = unit_any as Dictionary
		if str(unit.get("arrive_source", "")) == "supercharge_release":
			train.append(unit)
	train.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("supercharge_train_index", 0)) < int(b.get("supercharge_train_index", 0)))
	_expect(train.size() == 2, "release creates an exact deterministic train")
	if train.size() == 2:
		_expect(int(train[0].get("supercharge_train_index", -1)) == 0 and int(train[1].get("supercharge_train_index", -1)) == 1, "train indices are stable")
		_expect(float(train[0].get("t", 0.0)) > float(train[1].get("t", 0.0)), "train spacing has a deterministic lead-to-tail order")
	_expect(BuffSystem.active_effect(state, 1, "SUPERCHARGE_QUEUE").is_empty(), "released effect is removed from authoritative state")

func _test_supercharge_source_loss() -> void:
	var state := _state()
	var unit_system := UnitSystem.new()
	unit_system.bind_state(state)
	var activated: Dictionary = BuffSystem.activate(state, _command("lost", "buff_supercharge_queue_classic", "lane", 1))
	_expect(bool(activated.get("ok", false)), "source-loss Supercharge fixture activates")
	unit_system.spawn_unit(_unit(1, 1, 2, 1))
	(state.find_hive_by_id(1) as HiveData).owner_id = 2
	state.tick = 1
	var events: Array[Dictionary] = BuffSystem.tick(state)
	_expect(events.size() == 1 and str(events[0].get("reason", "")) == "source_hive_lost", "source loss immediately cancels Supercharge")
	var released: int = 0
	for unit_any in unit_system.units:
		if str((unit_any as Dictionary).get("arrive_source", "")) == "supercharge_release":
			released += 1
	_expect(released == 0, "source loss forfeits the queue without release")

func _state() -> GameState:
	var state := GameState.new()
	state.init_demo_map()
	state.rebuild_indexes()
	return state

func _unit(lane_id: int, from_id: int, to_id: int, owner_id: int) -> Dictionary:
	var lane: LaneData = _state_lane_cache(lane_id)
	return {
		"lane_id": lane_id,
		"a_id": int(lane.a_id),
		"b_id": int(lane.b_id),
		"from_id": from_id,
		"to_id": to_id,
		"owner_id": owner_id,
		"amount": 1,
		"dir": 1 if from_id == int(lane.a_id) else -1,
		"arrive_source": "lane"
	}

func _state_lane_cache(lane_id: int) -> LaneData:
	# Demo-map lane identity is stable; a tiny local state keeps the fixture explicit.
	var fixture := _state()
	return fixture.find_lane_by_id(lane_id)

func _command(id: String, buff_id: String, target_type: String, target_id: Variant) -> Dictionary:
	return {
		"match_id": "production-supercharge",
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
	push_error("BUFF_PRODUCTION_SUPERCHARGE_SMOKE: %s" % label)
