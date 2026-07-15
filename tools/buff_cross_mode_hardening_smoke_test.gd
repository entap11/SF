extends SceneTree

const OpsStateScript := preload("res://scripts/ops/ops_state.gd")
const TransactionScript := preload("res://scripts/state/buff_activation_transaction.gd")
const BuffSystem := preload("res://scripts/sim/authoritative_buff_system.gd")

var _failed: bool = false

func _init() -> void:
	await process_frame
	var runtime: Node = get_root().get_node_or_null("/root/VsPvpRuntime")
	_expect(runtime != null, "VsPvpRuntime autoload is available")
	if runtime != null:
		_test_host_guest_command_bridge_and_restore(runtime)
	_test_fixed_tick_and_render_rate_determinism()
	_test_target_loss_matrix_and_lane_reconstruction()
	_test_bounded_histories_and_async_uses()
	_test_source_fences()
	if _failed:
		quit(1)
		return
	print("BUFF_CROSS_MODE_HARDENING_SMOKE: PASS")
	quit(0)

func _test_host_guest_command_bridge_and_restore(runtime: Node) -> void:
	var host: Node = _ops_fixture()
	var guest: Node = _ops_fixture()
	var local: Node = _ops_fixture()
	var command: Dictionary = _canonical_command("bridge-speed", "buff_unit_speed_classic", "hive", 1, 10)
	runtime.call("clear")
	_expect(bool(runtime.call("_validate_contract_command", command, "host-smoke")), "host accepts stable canonical buff command")
	_expect(bool(runtime.call("_validate_contract_command", command, "guest-smoke")), "guest accepts the same canonical buff command")
	runtime.call("_queue_scheduled_command", command)
	runtime.call("_queue_scheduled_command", command.duplicate(true))
	var host_due: Array = runtime.call("consume_remote_commands", 10) as Array
	runtime.call("clear")
	runtime.call("_queue_scheduled_command", command)
	var guest_due: Array = runtime.call("consume_remote_commands", 10) as Array
	_expect(host_due.size() == 1 and guest_due.size() == 1, "host and guest each execute a duplicated transport message exactly once")
	var host_result: Dictionary = host.call("apply_authoritative_buff_command", host_due[0]) as Dictionary
	var guest_result: Dictionary = guest.call("apply_authoritative_buff_command", guest_due[0]) as Dictionary
	var local_result: Dictionary = local.call("apply_authoritative_buff_command", command) as Dictionary
	_expect(host_result == guest_result and host_result == local_result and bool(host_result.get("ok", false)), "local, PvP host, and PvP guest produce one canonical outcome")
	_expect(str(host.call("get_contract_state_hash")) == str(guest.call("get_contract_state_hash")) and str(host.call("get_contract_state_hash")) == str(local.call("get_contract_state_hash")), "local, host, and guest hashes agree after execution")
	runtime.call("_queue_scheduled_command", command.duplicate(true))
	_expect((runtime.call("consume_remote_commands", 10) as Array).is_empty(), "replay/reconnect delivery stays deduplicated")
	var duplicate: Dictionary = host.call("apply_authoritative_buff_command", command) as Dictionary
	_expect(bool(duplicate.get("duplicate", false)) and str(host.call("get_contract_state_hash")) == str(guest.call("get_contract_state_hash")), "authoritative duplicate activation is idempotent")

	var snapshot: Dictionary = host.call("get_authority_snapshot") as Dictionary
	var guest_state: GameState = guest.get("state") as GameState
	guest_state.buff_effects_by_activation_id.clear()
	_expect(str(host.call("get_contract_state_hash")) != str(guest.call("get_contract_state_hash")), "active effect participates in cross-peer hash")
	_expect(bool(guest.call("restore_authority_snapshot", snapshot)), "guest imports host authority snapshot")
	_expect(str(host.call("get_contract_state_hash")) == str(guest.call("get_contract_state_hash")), "snapshot/import restores exact host hash")
	runtime.call("clear")
	host.free()
	guest.free()
	local.free()

func _test_fixed_tick_and_render_rate_determinism() -> void:
	var state_a := _state()
	var state_b := _state()
	var units_a := UnitSystem.new()
	var units_b := UnitSystem.new()
	units_a.bind_state(state_a)
	units_b.bind_state(state_b)
	var command: Dictionary = _command("rate-speed", "buff_unit_speed_classic", "hive", 1)
	BuffSystem.activate(state_a, command)
	BuffSystem.activate(state_b, command)
	units_a.spawn_unit(_unit(state_a, 1, 1, 2, 1, 0.0))
	units_b.spawn_unit(_unit(state_b, 1, 1, 2, 1, 0.0))
	units_a._update_units(0.1)
	units_b._update_units(0.05)
	units_b._update_units(0.05)
	_expect(is_equal_approx(float((units_a.units[0] as Dictionary).get("t", 0.0)), float((units_b.units[0] as Dictionary).get("t", 0.0))), "equivalent fixed simulation time is independent of render slicing")
	var effect_a: Dictionary = BuffSystem.active_effect(state_a, 1, "UNIT_SPEED")
	var expires: int = int(effect_a.get("expires_tick", 50))
	state_a.tick = expires - 1
	_expect(BuffSystem.tick(state_a).is_empty(), "effect remains active on the tick immediately before expiry")
	state_a.tick = expires
	_expect(BuffSystem.tick(state_a).size() == 1 and BuffSystem.active_effect(state_a, 1, "UNIT_SPEED").is_empty(), "effect expires exactly on its fixed-tick boundary")

func _test_target_loss_matrix_and_lane_reconstruction() -> void:
	var hive_targets: Array[String] = [
		"buff_unit_speed_classic",
		"buff_single_production_boost_classic",
		"buff_hive_shield_single_classic",
		"buff_shock_immunity_classic"
	]
	for index in range(hive_targets.size()):
		var state := _state()
		var result: Dictionary = BuffSystem.activate(state, _command("hive-loss-%d" % index, hive_targets[index], "hive", 1))
		_expect(bool(result.get("ok", false)), "%s target-loss fixture activates" % hive_targets[index])
		(state.find_hive_by_id(1) as HiveData).owner_id = 2
		state.tick = 1
		var events: Array[Dictionary] = BuffSystem.tick(state)
		_expect(events.size() == 1 and str(events[0].get("reason", "")) == "target_owner_lost", "%s terminates immediately on ownership loss" % hive_targets[index])

	var super_state := _state()
	BuffSystem.activate(super_state, _command("super-loss", "buff_supercharge_queue_classic", "lane", 1))
	(super_state.find_hive_by_id(1) as HiveData).owner_id = 2
	super_state.tick = 1
	var super_events: Array[Dictionary] = BuffSystem.tick(super_state)
	_expect(super_events.size() == 1 and str(super_events[0].get("reason", "")) == "source_hive_lost", "Supercharge source loss terminates and forfeits")

	for lane_buff in ["buff_freeze_lane_classic", "buff_treacherous_lane_classic"]:
		var lane_state := _state()
		var lane: LaneData = lane_state.find_lane_by_id(1)
		BuffSystem.activate(lane_state, _command("lane-loss-%s" % lane_buff, lane_buff, "lane", 1))
		lane.send_a = false
		lane.send_b = false
		lane.establish_a = false
		lane.establish_b = false
		lane_state.tick = 1
		var events: Array[Dictionary] = BuffSystem.tick(lane_state)
		_expect(events.size() == 1 and str(events[0].get("reason", "")) == "target_lane_lost", "%s terminates safely when lane is removed" % lane_buff)

	var rebuild_state := _state()
	(rebuild_state.find_hive_by_id(2) as HiveData).owner_id = 2
	var rebuild_units := UnitSystem.new()
	rebuild_units.bind_state(rebuild_state)
	rebuild_units.spawn_unit(_unit(rebuild_state, 1, 2, 1, 2, 0.8))
	BuffSystem.activate(rebuild_state, _command("rebuild-treach", "buff_treacherous_lane_classic", "lane", 1))
	var committed_before: Dictionary = (rebuild_units.units[0] as Dictionary).duplicate(true)
	rebuild_state.lanes.clear()
	rebuild_state.tick = 1
	BuffSystem.tick(rebuild_state)
	_expect(rebuild_units.units.size() == 1 and bool((rebuild_units.units[0] as Dictionary).get("treacherous_committed", false)), "lane removal preserves committed betrayal unit exactly once")
	rebuild_state.lanes.append(LaneData.new(1, 1, 2, 1, true, true))
	rebuild_state.rebuild_indexes()
	var t_before: float = float((rebuild_units.units[0] as Dictionary).get("t", 0.0))
	rebuild_units._update_units(0.1)
	var rebuilt: Dictionary = rebuild_units.units[0] as Dictionary
	_expect(rebuild_units.units.size() == 1 and int(rebuilt.get("treacherous_origin_hive_id", -1)) == int(committed_before.get("treacherous_origin_hive_id", -1)) and float(rebuilt.get("t", 0.0)) > t_before, "lane reconstruction neither loses nor duplicates betrayal state")

func _test_bounded_histories_and_async_uses() -> void:
	var queue_state := _state()
	var queue_units := UnitSystem.new()
	queue_units.bind_state(queue_state)
	BuffSystem.activate(queue_state, _command("bounded-queue", "buff_supercharge_queue_classic", "lane", 1))
	queue_units.spawn_unit(_unit(queue_state, 1, 1, 2, 1, 0.0, 1000))
	var queue_effect: Dictionary = BuffSystem.active_effect(queue_state, 1, "SUPERCHARGE_QUEUE")
	_expect(int(queue_effect.get("queued_units", 0)) == BuffSystem.MAX_SUPERCHARGE_QUEUE_UNITS, "Supercharge queue has an explicit deterministic safety bound")

	var history_state := _state()
	for index in range(BuffSystem.MAX_OUTCOME_HISTORY):
		BuffSystem.activate(history_state, _command("history-%d" % index, "buff_swarm_damage_classic", "global", "global"))
	var overflow: Dictionary = BuffSystem.activate(history_state, _command("history-overflow", "buff_swarm_damage_classic", "global", "global"))
	_expect(history_state.buff_outcomes_by_activation_id.size() == BuffSystem.MAX_OUTCOME_HISTORY and str(overflow.get("reason", "")) == "activation_history_full", "handled activation history is bounded without evicting duplicate identities")

	var tx: RefCounted = TransactionScript.new()
	var async_one: Dictionary = _reservation("async-one", 1)
	var async_two: Dictionary = _reservation("async-two", 2)
	var async_three: Dictionary = _reservation("async-three", 3)
	_expect(bool(tx.call("reserve", async_one, 1).get("ok", false)), "Async first use reserves")
	tx.call("release", "hardening", 1, "async-one", "fixture")
	_expect(bool(tx.call("reserve", async_two, 1).get("ok", false)), "Async second use reserves")
	_expect(str(tx.call("reserve", async_three, 1).get("reason", "")) == "invalid_source_use_ordinal", "Async third use is rejected")

func _test_source_fences() -> void:
	var ui_source: String = FileAccess.get_file_as_string("res://scripts/ui/ui_buff_bar.gd")
	var activation_source: String = FileAccess.get_file_as_string("res://scripts/state/buff_activation_system.gd")
	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	_expect(not ui_source.contains("release_supercharge"), "UI exposes no manual Supercharge release path")
	_expect(activation_source.contains("automatic_release_only"), "legacy release adapter is fenced as an automatic-release no-op")
	_expect(arena_source.contains("MAX_BUFF_CANONICAL_OUTCOMES") and arena_source.contains("_remember_buff_canonical_outcome"), "Arena canonical outcome bridge is explicitly bounded")
	_expect(shell_source.contains("const MATCH_BUFF_TARGETING_ENABLED: bool = false"), "production targeting gate remains exactly false")

func _ops_fixture() -> Node:
	var ops: Node = OpsStateScript.new()
	var state := _state()
	var units := UnitSystem.new()
	units.bind_state(state)
	ops.set("state", state)
	ops.set("current_map_id", "buff-hardening")
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

func _canonical_command(id: String, buff_id: String, target_type: String, target_id: Variant, tick: int) -> Dictionary:
	var command: Dictionary = _command(id, buff_id, target_type, target_id)
	command.merge({
		"contract_version": 1,
		"client_command_id": "client:%s" % id,
		"command_seq": 1,
		"issued_ms": 1,
		"issued_tick": tick - 3,
		"local_issued_tick": tick - 3,
		"issued_sim_us": (tick - 3) * 100000,
		"requested_execute_tick": tick,
		"canonical_execute_tick": tick,
		"execute_tick": tick,
		"sender_seat": 1,
		"sender_uid": "hardening-host"
	}, true)
	return command

func _reservation(id: String, ordinal: int) -> Dictionary:
	return {
		"match_id": "hardening",
		"owner_id": 1,
		"activation_id": id,
		"buff_id": "buff_unit_speed_classic",
		"source_kind": "async",
		"source_use_ordinal": ordinal,
		"charge_key": "async:%d" % ordinal
	}

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_CROSS_MODE_HARDENING_SMOKE: %s" % label)
