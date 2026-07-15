extends SceneTree

const BuffSystem := preload("res://scripts/sim/authoritative_buff_system.gd")
const ProductionEvents := preload("res://scripts/sim/production_event_system.gd")
const OpsStateScript := preload("res://scripts/ops/ops_state.gd")

var _failed: bool = false

func _init() -> void:
	_test_production_event_contract_and_baseline_hash()
	_test_behavior_compatible_merging()
	_test_treacherous_combat_allegiance()
	_test_supercharge_stamped_cohorts_and_restore()
	_test_lane_generation_and_phase_boundaries()
	if _failed:
		quit(1)
		return
	print("BUFF_CONTRACT_HARDENING_SMOKE: PASS")
	quit(0)

func _test_production_event_contract_and_baseline_hash() -> void:
	var state := _state()
	var units := UnitSystem.new()
	units.bind_state(state)
	var normal: Dictionary = _unit(state, 1, 1, 2, 1, 0.0)
	normal["production_event_id"] = "explicit-normal"
	_expect(units.spawn_unit(normal), "normal production commits through event spine")
	var produced: Dictionary = units.units[0] as Dictionary
	_expect(str(produced.get("production_event_id", "")) == "explicit-normal" and int(produced.get("ordinary_count", 0)) == 1, "event provenance is attached without changing the ordinary gameplay stamp")
	_expect(not units.spawn_unit(normal.duplicate(true)), "reprocessing one explicit event cannot create or queue a duplicate unit")

	var ops: Node = OpsStateScript.new()
	ops.set("state", state)
	ops.set("current_map_id", "production-baseline")
	var with_provenance: String = str(ops.call("get_contract_state_hash"))
	produced.erase("production_event_id")
	units.units[0] = produced
	var without_provenance: String = str(ops.call("get_contract_state_hash"))
	_expect(with_provenance == without_provenance, "diagnostic production identity does not fragment the gameplay hash")

	var audit_state := _state()
	var lane: LaneData = audit_state.find_lane_by_id(1)
	var cases: Array[Dictionary] = [
		{"source": "lane", "unit": {"from_id": 1, "lane_id": 1, "lane_generation": lane.generation}, "producer": "hive", "reason": "normal_production"},
		{"source": "barracks", "unit": {"from_id": -7, "lane_id": -1}, "producer": "barracks", "reason": "normal_production"},
		{"source": "lane", "unit": {"from_id": -7, "lane_id": -1}, "producer": "barracks", "reason": "normal_production"},
		{"source": "pass_through", "unit": {"from_id": 1, "lane_id": 1, "lane_generation": lane.generation}, "producer": "hive", "reason": "pass_through"},
		{"source": "supercharge_release", "unit": {"from_id": 1, "lane_id": 1, "lane_generation": lane.generation}, "producer": "hive", "reason": "supercharge_release"},
		{"source": "unknown_script", "unit": {"from_id": 0, "lane_id": 0}, "producer": "system", "reason": "scripted"}
	]
	for case in cases:
		var event: Dictionary = ProductionEvents.prepare(audit_state, case.get("unit", {}) as Dictionary, str(case.get("source", "")))
		_expect(str(event.get("producer_kind", "")) == str(case.get("producer", "")) and str(event.get("spawn_reason", "")) == str(case.get("reason", "")), "%s production source is exhaustively classified" % str(case.get("source", "")))
	ops.free()

func _test_behavior_compatible_merging() -> void:
	var state := _state()
	var units := UnitSystem.new()
	units.bind_state(state)
	var first: Dictionary = _unit(state, 1, 1, 2, 1, 0.5)
	first["production_event_id"] = "different-tick-a"
	var second: Dictionary = _unit(state, 1, 2, 1, 1, 0.5)
	second["production_event_id"] = "different-tick-b"
	units.spawn_unit(first)
	units.spawn_unit(second)
	units.resolve_lane_interactions(state, 0)
	_expect(units.units.size() == 1 and int((units.units[0] as Dictionary).get("amount", 0)) == 2, "compatible normal units merge despite distinct production provenance")

	var fast: Dictionary = {"owner_id": 1, "combat_allegiance_id": 1, "allegiance_mode": "normal", "speed_permille": 1250, "amount": 1}
	var slow: Dictionary = {"owner_id": 1, "combat_allegiance_id": 1, "allegiance_mode": "normal", "speed_permille": 1000, "amount": 1}
	_expect(not units._units_can_merge(fast, slow), "different stamped speeds cannot merge")
	var ordinary: Dictionary = {"amount": 1, "ordinary_count": 1, "enhanced_full_count": 0, "enhanced_spent_count": 0, "speed_permille": 1000}
	var enhanced: Dictionary = {"amount": 1, "ordinary_count": 0, "enhanced_full_count": 1, "enhanced_spent_count": 0, "speed_permille": 1000}
	var combined: Dictionary = units._merge_combat_cohorts(ordinary, enhanced)
	_expect(int(combined.get("ordinary_count", 0)) == 1 and int(combined.get("enhanced_full_count", 0)) == 1, "impact subcohorts aggregate without flattening their future strength")

func _test_treacherous_combat_allegiance() -> void:
	var state := _state()
	(state.find_hive_by_id(2) as HiveData).owner_id = 2
	var units := UnitSystem.new()
	units.bind_state(state)
	units.spawn_unit(_unit(state, 1, 2, 1, 2, 0.5))
	var activated: Dictionary = BuffSystem.activate(state, _command("allegiance", "buff_treacherous_lane_classic", "lane", 1))
	_expect(bool(activated.get("ok", false)), "Treacherous allegiance fixture activates")
	var betrayed: Dictionary = units.units[0] as Dictionary
	_expect(int(betrayed.get("owner_id", 0)) == 2 and int(betrayed.get("original_owner_id", 0)) == 2, "betrayal never changes canonical or original ownership")
	_expect(int(betrayed.get("combat_allegiance_id", 0)) == 1 and str(betrayed.get("allegiance_mode", "")) == "betrayed", "betrayal changes only combat allegiance")
	var activating_normal: Dictionary = {"owner_id": 1, "combat_allegiance_id": 1, "allegiance_mode": "normal", "speed_permille": 1000}
	_expect(not units._units_can_merge(betrayed, activating_normal), "betrayed unit cannot merge with an ordinary activating-player unit")
	_expect(units._unit_kill_credit_owner(betrayed) == 0, "betrayed unit cannot earn kill credit for either player")
	_expect(units._recall_units_for_lane(1, 2, 2) == 0, "canonical owner cannot recall a betrayed unit")
	_expect(units.redirect_units_for_lane_direction(1, 1, 2, 2) == 0, "canonical owner cannot redirect a betrayed unit")
	_expect(units.scoop_units_for_swarm(2, 1, 2, 1, 0.0, 1.0) == 0 and units.units.size() == 1, "canonical owner cannot scoop a betrayed unit into a manual swarm")

	var original_force: Dictionary = _unit(state, 1, 2, 1, 2, float(betrayed.get("t", 0.5)))
	original_force["arrive_source"] = "supercharge_release"
	original_force["combat_allegiance_id"] = 2
	original_force["original_owner_id"] = 2
	original_force["allegiance_mode"] = "normal"
	units.spawn_unit(original_force)
	units.resolve_lane_interactions(state, 0)
	_expect(units.units.is_empty(), "betrayed unit fights its original owner's force using combat allegiance")

	var origin: HiveData = state.find_hive_by_id(2)
	origin.owner_id = 1
	origin.power = 2
	var arrival: Dictionary = betrayed.duplicate(true)
	arrival["amount"] = 5
	arrival["ordinary_count"] = 5
	arrival["skip_pressure"] = true
	units._apply_unit_arrival(arrival)
	_expect(int(origin.owner_id) == 1 and int(origin.power) == 1, "betrayed arrival damages but can never capture or reinforce its stored origin")
	_expect(units.get_arrival_count(2, 2) == 0, "betrayed arrival cannot earn landed-unit economic credit")

func _test_supercharge_stamped_cohorts_and_restore() -> void:
	var ops: Node = _ops_fixture()
	var state: GameState = ops.get("state") as GameState
	var units: UnitSystem = state.unit_system
	var activation: Dictionary = ops.call("apply_authoritative_buff_command", _command("stamped-super", "buff_supercharge_queue_classic", "lane", 1)) as Dictionary
	_expect(bool(activation.get("ok", false)), "stamped Supercharge fixture activates")
	var lane: LaneData = state.find_lane_by_id(1)
	var fast_enhanced: Dictionary = _unit(state, 1, 1, 2, 1, 0.0, 3)
	fast_enhanced.merge({"speed_permille": 1250, "ordinary_count": 0, "enhanced_full_count": 3, "enhanced_spent_count": 0}, true)
	var event_a: Dictionary = ProductionEvents.prepare(state, fast_enhanced, "lane")
	var first_commit: Dictionary = ProductionEvents.commit(state, event_a, fast_enhanced)
	var duplicate_commit: Dictionary = ProductionEvents.commit(state, event_a, fast_enhanced)
	_expect(bool(first_commit.get("ok", false)) and bool(duplicate_commit.get("duplicate", false)), "one unit_count-three event commits exactly once")
	var baseline: Dictionary = _unit(state, 1, 1, 2, 1, 0.0, 2)
	baseline.merge({"speed_permille": 1000, "ordinary_count": 2, "enhanced_full_count": 0, "enhanced_spent_count": 0}, true)
	ProductionEvents.commit(state, ProductionEvents.prepare(state, baseline, "lane"), baseline)
	var effect: Dictionary = BuffSystem.active_effect(state, 1, "SUPERCHARGE_QUEUE")
	_expect(int(effect.get("queued_units", 0)) == 5 and (effect.get("queued_cohorts", []) as Array).size() == 2, "mixed stamped events preserve ordered queue runs")

	var expected_hash: String = str(ops.call("get_contract_state_hash"))
	var snapshot: Dictionary = ops.call("get_authority_snapshot") as Dictionary
	state.buff_effects_by_activation_id.clear()
	_expect(bool(ops.call("restore_authority_snapshot", snapshot)) and str(ops.call("get_contract_state_hash")) == expected_hash, "mixed stamped queue survives snapshot/restore and hash")
	state = ops.get("state") as GameState
	units = state.unit_system
	effect = BuffSystem.active_effect(state, 1, "SUPERCHARGE_QUEUE")
	state.tick = int(effect.get("expires_tick", 50))
	var release: Array[Dictionary] = BuffSystem.tick(state)
	_expect(release.size() == 1 and int(release[0].get("released_units", 0)) == 5, "restored stamped queue releases its entire train")
	var train: Array[Dictionary] = []
	for unit_any in units.units:
		var unit: Dictionary = unit_any as Dictionary
		if str(unit.get("arrive_source", "")) == "supercharge_release":
			train.append(unit)
	train.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("supercharge_train_index", 0)) < int(b.get("supercharge_train_index", 0)))
	_expect(train.size() == 5, "stamped release creates five deterministic bonus units")
	if train.size() == 5:
		_expect(int(train[0].get("speed_permille", 0)) == 1250 and int(train[0].get("enhanced_full_count", 0)) == 1 and int(train[2].get("enhanced_full_count", 0)) == 1, "first run inherits enhanced fast stamp")
		_expect(int(train[3].get("speed_permille", 0)) == 1000 and int(train[3].get("ordinary_count", 0)) == 1, "second run inherits baseline ordinary stamp")
	ops.free()

func _test_lane_generation_and_phase_boundaries() -> void:
	var state := _state()
	var old_lane: LaneData = state.find_lane_by_id(1)
	var old_generation: int = int(old_lane.generation)
	BuffSystem.activate(state, _command("generation-freeze", "buff_freeze_lane_classic", "lane", 1))
	state.lanes.erase(old_lane)
	state.lanes.append(LaneData.new(1, 1, 2, 1, true, false))
	state.rebuild_indexes()
	var new_lane: LaneData = state.find_lane_by_id(1)
	_expect(int(new_lane.generation) != old_generation, "reconstructed lane receives a new simulation generation")
	state.tick = 1
	var reconstruction_events: Array[Dictionary] = BuffSystem.tick(state)
	_expect(reconstruction_events.size() == 1 and str(reconstruction_events[0].get("reason", "")) == "target_lane_reconstructed", "old lane-targeted effect cannot attach to reconstruction with reused numeric ID")

	var expiry_state := _state()
	var expiry_units := UnitSystem.new()
	expiry_units.bind_state(expiry_state)
	BuffSystem.activate(expiry_state, _command("expiry-super", "buff_supercharge_queue_classic", "lane", 1))
	var expiry_effect: Dictionary = BuffSystem.active_effect(expiry_state, 1, "SUPERCHARGE_QUEUE")
	expiry_state.tick = int(expiry_effect.get("expires_tick", 50)) - 1
	var before_end: Dictionary = _unit(expiry_state, 1, 1, 2, 1, 0.0)
	expiry_units.spawn_unit(before_end)
	_expect(int(BuffSystem.active_effect(expiry_state, 1, "SUPERCHARGE_QUEUE").get("queued_units", 0)) == 1, "production before end tick qualifies")
	var end_events: Array[Dictionary] = BuffSystem.tick(expiry_state, int(expiry_effect.get("expires_tick", 50)))
	_expect(end_events.size() == 1 and str(end_events[0].get("event", "")) == "supercharge_released", "expiration phase releases before end-tick production")
	expiry_state.tick = int(expiry_effect.get("expires_tick", 50))
	expiry_units.spawn_unit(_unit(expiry_state, 1, 1, 2, 1, 0.0))
	_expect(BuffSystem.active_effect(expiry_state, 1, "SUPERCHARGE_QUEUE").is_empty(), "production on end tick cannot refill expired effect")

	var loss_state := _state()
	var loss_units := UnitSystem.new()
	loss_units.bind_state(loss_state)
	BuffSystem.activate(loss_state, _command("loss-at-expiry", "buff_supercharge_queue_classic", "lane", 1))
	loss_units.spawn_unit(_unit(loss_state, 1, 1, 2, 1, 0.0))
	var loss_effect: Dictionary = BuffSystem.active_effect(loss_state, 1, "SUPERCHARGE_QUEUE")
	(loss_state.find_hive_by_id(1) as HiveData).owner_id = 2
	var loss_events: Array[Dictionary] = BuffSystem.tick(loss_state, int(loss_effect.get("expires_tick", 50)))
	_expect(loss_events.size() == 1 and str(loss_events[0].get("reason", "")) == "source_hive_lost" and str(loss_events[0].get("event", "")) == "buff_expired", "target loss precedes expiration release on the same boundary")

func _ops_fixture() -> Node:
	var ops: Node = OpsStateScript.new()
	var state := _state()
	var units := UnitSystem.new()
	units.bind_state(state)
	ops.set("state", state)
	ops.set("current_map_id", "buff-contract-hardening")
	return ops

func _state() -> GameState:
	var state := GameState.new()
	state.init_demo_map()
	state.rebuild_indexes()
	return state

func _unit(state: GameState, lane_id: int, from_id: int, to_id: int, owner_id: int, t: float, amount: int = 1) -> Dictionary:
	var lane: LaneData = state.find_lane_by_id(lane_id)
	return {
		"lane_id": lane_id,
		"lane_generation": int(lane.generation),
		"a_id": int(lane.a_id),
		"b_id": int(lane.b_id),
		"from_id": from_id,
		"to_id": to_id,
		"owner_id": owner_id,
		"amount": amount,
		"dir": 1 if from_id == int(lane.a_id) else -1,
		"t": t,
		"arrive_source": "lane"
	}

func _command(id: String, buff_id: String, target_type: String, target_id: Variant) -> Dictionary:
	return {
		"kind": "buff_activate",
		"match_id": "buff-hardening",
		"command_id": "command:%s" % id,
		"activation_id": id,
		"owner_id": 1,
		"buff_id": buff_id,
		"tier": "classic",
		"target_type": target_type,
		"target_id": target_id,
		"source_kind": "vs",
		"source_use_ordinal": 1,
		"source_slot_index": 0
	}

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_CONTRACT_HARDENING_SMOKE: %s" % label)
