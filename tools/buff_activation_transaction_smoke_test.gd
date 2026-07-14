extends SceneTree

const TransactionScript = preload("res://scripts/state/buff_activation_transaction.gd")

var _failed: bool = false

func _init() -> void:
	var tx := TransactionScript.new()
	var request: Dictionary = _request("activation-a", "inventory:buff-a", 1)
	var invalid_release: Dictionary = tx.reserve_validated(
		_request("activation-invalid", "inventory:buff-a", 1),
		{"ok": false, "reason": "target_ineligible"},
		1
	)
	_expect(not bool(invalid_release.get("ok", false)) and tx.unresolved_transactions().is_empty(), "invalid release reserves and consumes nothing")
	var reserved: Dictionary = tx.reserve_validated(request, {"ok": true}, 1)
	_expect(bool(reserved.get("ok", false)) and str(reserved.get("reservation_state", "")) == "reserved", "valid release reserves once")
	var duplicate_reserve: Dictionary = tx.reserve(request, 1)
	_expect(bool(duplicate_reserve.get("duplicate", false)), "duplicate release returns original reservation")
	var rapid_second: Dictionary = tx.reserve(_request("activation-b", "inventory:buff-a", 1), 1)
	_expect(not bool(rapid_second.get("ok", false)) and str(rapid_second.get("reason", "")) == "insufficient_charges", "two rapid activations cannot reserve final quantity twice")

	_expect(bool(tx.mark_submitted("match-a", 1, "activation-a").get("ok", false)), "reservation submits")
	_expect(bool(tx.mark_canonically_scheduled("match-a", 1, "activation-a", "command:1", 50).get("ok", false)), "submission receives canonical schedule")
	var execute: Dictionary = tx.resolve_canonical_outcome("match-a", 1, "activation-a", true, "activated", "command:1", 50)
	_expect(str(execute.get("action", "")) == "commit", "successful execution requests commit")
	var committed: Dictionary = tx.mark_committed("match-a", 1, "activation-a")
	_expect(str(committed.get("reservation_state", "")) == "committed", "successful execution commits")
	var duplicate_execute: Dictionary = tx.resolve_canonical_outcome("match-a", 1, "activation-a", true, "activated", "command:1", 50)
	_expect(bool(duplicate_execute.get("duplicate", false)) and bool(duplicate_execute.get("committed", false)), "duplicate canonical execution cannot commit twice")

	var stale_request: Dictionary = _request("activation-stale", "inventory:buff-a", 1)
	_expect(bool(tx.reserve(stale_request, 1).get("ok", false)), "released capacity can reserve again")
	tx.mark_submitted("match-a", 1, "activation-stale")
	tx.mark_canonically_scheduled("match-a", 1, "activation-stale", "command:2", 60)
	var stale: Dictionary = tx.resolve_canonical_outcome("match-a", 1, "activation-stale", false, "target_stale", "command:2", 60)
	_expect(str(stale.get("reservation_state", "")) == "released" and str(stale.get("final_status", "")) == "deterministic_no_op", "stale target releases reservation")

	var rejected_request: Dictionary = _request("activation-rejected", "inventory:buff-a", 1)
	tx.reserve(rejected_request, 1)
	var rejected: Dictionary = tx.reject_submission("match-a", 1, "activation-rejected", "transport_rejected")
	_expect(str(rejected.get("reservation_state", "")) == "released", "transport rejection releases reservation")

	var pending_request: Dictionary = _request("activation-pending", "inventory:buff-a", 1)
	tx.reserve(pending_request, 1)
	tx.mark_submitted("match-a", 1, "activation-pending")
	var exported: Dictionary = tx.export_state()
	var restored := TransactionScript.new()
	restored.import_state(exported)
	var pending: Dictionary = restored.get_transaction("match-a", 1, "activation-pending")
	_expect(str(pending.get("reservation_state", "")) == "submitted", "submitted command survives runtime-state restore")
	var reconciled: Dictionary = restored.reconcile_outcome({
		"match_id": "match-a",
		"owner_id": 1,
		"activation_id": "activation-pending",
		"status": "executed",
		"reason": "activated",
		"canonical_command_id": "command:3",
		"execution_tick": 70
	})
	_expect(str(reconciled.get("action", "")) == "commit", "replay reconciles executed activation")
	restored.mark_committed("match-a", 1, "activation-pending")
	var replay_rejected_request: Dictionary = _request("activation-replay-rejected", "inventory:buff-a", 1)
	restored.reserve(replay_rejected_request, 1)
	restored.mark_submitted("match-a", 1, "activation-replay-rejected")
	var replay_rejected: Dictionary = restored.reconcile_outcome({
		"match_id": "match-a",
		"owner_id": 1,
		"activation_id": "activation-replay-rejected",
		"status": "rejected",
		"reason": "canonical_rejection"
	})
	_expect(str(replay_rejected.get("reservation_state", "")) == "released", "replay reconciles rejected activation and releases")

	var async_one: Dictionary = _request("async-one", "async:item:one", 1)
	async_one["source_kind"] = "async"
	var async_two: Dictionary = _request("async-two", "async:item:two", 2)
	async_two["source_kind"] = "async"
	_expect(bool(restored.reserve(async_one, 1).get("ok", false)), "Async use one is a valid distinct reservation")
	_expect(bool(restored.reserve(async_two, 1).get("ok", false)), "Async use two is a valid distinct reservation")
	var async_three: Dictionary = _request("async-three", "async:item:three", 3)
	async_three["source_kind"] = "async"
	_expect(str(restored.reserve(async_three, 1).get("reason", "")) == "invalid_source_use_ordinal", "Async use three is rejected")
	var vs_two: Dictionary = _request("vs-two", "vs:item:two", 2)
	_expect(str(restored.reserve(vs_two, 1).get("reason", "")) == "invalid_source_use_ordinal", "VS permits exactly use one")

	var terminate_request: Dictionary = _request("activation-terminate", "inventory:buff-a", 1)
	restored.reserve(terminate_request, 1)
	var terminated: Array[Dictionary] = restored.terminate_match("match-a")
	_expect(not terminated.is_empty(), "match termination releases unresolved reservations")
	_expect((restored.performance_snapshot().get("per_frame_processing", true)) == false, "transaction processing has no per-frame scan")
	_expect(int(restored.performance_snapshot().get("max_terminal_history", 0)) == 256, "terminal allocation is bounded")

	if _failed:
		quit(1)
		return
	print("BUFF_ACTIVATION_TRANSACTION_SMOKE: PASS")
	quit(0)

func _request(activation_id: String, charge_key: String, ordinal: int) -> Dictionary:
	return {
		"match_id": "match-a",
		"owner_id": 1,
		"activation_id": activation_id,
		"buff_id": "buff_unit_speed_classic",
		"tier": "classic",
		"source_kind": "vs",
		"source_use_ordinal": ordinal,
		"inventory_revision": "revision-a",
		"charge_key": charge_key,
		"slot_index": 0,
		"target_type": "hive",
		"target_id": 1
	}

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_ACTIVATION_TRANSACTION_SMOKE: %s" % label)
