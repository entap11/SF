extends SceneTree

const BuffSystem := preload("res://scripts/sim/authoritative_buff_system.gd")
const BuffDefinitions := preload("res://scripts/state/buff_definitions.gd")

var _failed: bool = false

func _init() -> void:
	var state := GameState.new()
	state.init_demo_map()
	var speed_command: Dictionary = _command("speed-1", "buff_unit_speed_classic", "hive", 1)
	var speed: Dictionary = BuffSystem.activate(state, speed_command)
	_expect(bool(speed.get("ok", false)), "owned hive activation executes")
	_expect(state.buff_effects_by_activation_id.size() == 1, "accepted activation creates one authoritative effect")
	_expect(int((speed.get("effect", {}) as Dictionary).get("expires_tick", -1)) == 50, "duration is encoded in fixed ticks")
	var duplicate: Dictionary = BuffSystem.activate(state, speed_command)
	_expect(bool(duplicate.get("duplicate", false)), "duplicate activation id returns its canonical outcome")
	_expect(state.buff_effects_by_activation_id.size() == 1, "duplicate activation creates no second effect")

	(state.find_hive_by_id(1) as HiveData).owner_id = 2
	state.tick = 1
	var loss_events: Array[Dictionary] = BuffSystem.tick(state)
	_expect(loss_events.size() == 1 and str(loss_events[0].get("reason", "")) == "target_owner_lost", "ownership loss immediately expires a target-bound effect")

	state.reset_map_only()
	state.init_demo_map()
	var global_command: Dictionary = _command("global-1", "buff_global_production_boost_classic", "global", "global")
	var global_result: Dictionary = BuffSystem.activate(state, global_command)
	_expect(bool(global_result.get("ok", false)), "global activation executes")
	_expect(((global_result.get("effect", {}) as Dictionary).get("scoped_hive_ids", []) as Array) == [1, 2], "global effect snapshots currently owned hives")

	state.reset_map_only()
	state.init_demo_map()
	var supercharge: Dictionary = BuffSystem.activate(state, _command("super-1", "buff_supercharge_queue_elite", "lane", 1))
	_expect(bool(supercharge.get("ok", false)), "Supercharge accepts an active lane with one owned producing source")
	var super_effect: Dictionary = supercharge.get("effect", {}) as Dictionary
	var super_target: Dictionary = super_effect.get("target", {}) as Dictionary
	_expect(int(super_target.get("source_hive_id", -1)) == 1 and int(super_target.get("destination_hive_id", -1)) == 2, "Supercharge captures stable source and destination identities")
	_expect(int(super_effect.get("expires_tick", -1)) == 90, "elite Supercharge expires after ninety fixed ticks")
	var snap: Dictionary = BuffSystem.snapshot(state)
	_expect((snap.get("effects", []) as Array).size() == 1, "authoritative snapshot exposes active effects")
	state.tick = 89
	_expect(BuffSystem.tick(state).is_empty(), "effect remains active immediately before expiry tick")
	state.tick = 90
	var expiry: Array[Dictionary] = BuffSystem.tick(state)
	_expect(expiry.size() == 1 and str(expiry[0].get("reason", "")) == "timer_expired", "effect expires exactly on its fixed tick boundary")

	await process_frame
	var ops: Node = get_root().get_node_or_null("OpsState")
	_expect(ops != null, "OpsState autoload is available")
	if ops != null:
		ops.call("reset_state_from_map", {
			"map_id": "buff_snapshot_smoke",
			"hives": [
				{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 20, "kind": "Hive"},
				{"id": 2, "x": 5, "y": 0, "owner_id": 2, "power": 20, "kind": "Hive"}
			],
			"lane_candidates": [{"a_id": 1, "b_id": 2}]
		})
		var ops_command: Dictionary = _command("snapshot-1", "buff_unit_speed_classic", "hive", 1)
		var ops_result: Dictionary = ops.call("apply_authoritative_buff_command", ops_command) as Dictionary
		_expect(bool(ops_result.get("ok", false)), "OpsState owns canonical activation mutation: %s" % str(ops_result))
		var expected_hash: String = str(ops.call("get_contract_state_hash"))
		var authority_snapshot: Dictionary = ops.call("get_authority_snapshot") as Dictionary
		var ops_state: GameState = ops.call("get_state") as GameState
		ops_state.buff_effects_by_activation_id.clear()
		_expect(str(ops.call("get_contract_state_hash")) != expected_hash, "active effects participate in the gameplay hash")
		_expect(bool(ops.call("restore_authority_snapshot", authority_snapshot)), "authority snapshot restores buff state")
		_expect(str(ops.call("get_contract_state_hash")) == expected_hash, "snapshot restore recovers the exact buff hash")
		var restored_duplicate: Dictionary = ops.call("apply_authoritative_buff_command", ops_command) as Dictionary
		_expect(bool(restored_duplicate.get("duplicate", false)), "restored handled activation remains idempotent: %s" % str(restored_duplicate))

	if _failed:
		quit(1)
		return
	print("AUTHORITATIVE_BUFF_STATE_SMOKE: PASS")
	quit(0)

func _command(activation_id: String, buff_id: String, target_type: String, target_id: Variant) -> Dictionary:
	return {
		"kind": "buff_activate",
		"match_id": "smoke-match",
		"command_id": "smoke:%s" % activation_id,
		"activation_id": activation_id,
		"owner_id": 1,
		"buff_id": buff_id,
		"tier": "elite" if buff_id.ends_with("_elite") else "classic",
		"target_type": target_type,
		"target_id": target_id,
		"source_slot_index": 0
	}

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("AUTHORITATIVE_BUFF_STATE_SMOKE: %s" % label)
