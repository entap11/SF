class_name BuffActivationTransaction
extends RefCounted

const STATE_RESERVED: String = "reserved"
const STATE_SUBMITTED: String = "submitted"
const STATE_CANONICALLY_SCHEDULED: String = "canonically_scheduled"
const STATE_EXECUTED: String = "executed"
const STATE_COMMITTED: String = "committed"
const STATE_RELEASED: String = "released"

const MAX_TERMINAL_HISTORY: int = 256

var _transactions: Dictionary = {}
var _terminal_order: Array[String] = []

func reserve_validated(request: Dictionary, target_validation: Dictionary, source_capacity: int) -> Dictionary:
	if not bool(target_validation.get("ok", false)):
		return {
			"ok": false,
			"status": "rejected",
			"reason": str(target_validation.get("reason", "invalid_target")),
			"activation_id": str(request.get("activation_id", ""))
		}
	return reserve(request, source_capacity)

func reserve(request: Dictionary, source_capacity: int) -> Dictionary:
	var normalized: Dictionary = _normalize_request(request)
	if not bool(normalized.get("ok", false)):
		return normalized
	var key: String = str(normalized.get("scope_key", ""))
	if _transactions.has(key):
		return _duplicate_result(_transactions.get(key, {}) as Dictionary)
	var capacity: int = maxi(0, source_capacity)
	var charge_key: String = str(normalized.get("charge_key", ""))
	var active_reservations: int = _active_reservation_count(charge_key)
	if capacity - active_reservations <= 0:
		return {
			"ok": false,
			"status": "rejected",
			"reason": "insufficient_charges",
			"activation_id": str(normalized.get("activation_id", "")),
			"charge_key": charge_key,
			"source_capacity": capacity,
			"active_reservations": active_reservations
		}
	var record: Dictionary = normalized.duplicate(true)
	record.erase("ok")
	record["reservation_id"] = _reservation_id(record)
	record["reservation_state"] = STATE_RESERVED
	record["final_status"] = ""
	record["final_reason"] = ""
	record["canonical_command_id"] = ""
	record["execution_tick"] = -1
	record["created_ms"] = Time.get_ticks_msec()
	record["updated_ms"] = int(record.get("created_ms", 0))
	record["committed"] = false
	record["released"] = false
	_transactions[key] = record
	return _result(record)

func mark_submitted(match_id: String, owner_id: int, activation_id: String) -> Dictionary:
	return _transition(match_id, owner_id, activation_id, [STATE_RESERVED], STATE_SUBMITTED, "submitted")

func mark_canonically_scheduled(
	match_id: String,
	owner_id: int,
	activation_id: String,
	canonical_command_id: String,
	execution_tick: int
) -> Dictionary:
	var found: Dictionary = _find_record(match_id, owner_id, activation_id)
	if not bool(found.get("ok", false)):
		return found
	var record: Dictionary = found.get("record", {}) as Dictionary
	if _is_terminal(record):
		return _duplicate_result(record)
	var current: String = str(record.get("reservation_state", ""))
	if current != STATE_RESERVED and current != STATE_SUBMITTED and current != STATE_CANONICALLY_SCHEDULED:
		return _invalid_transition(record, STATE_CANONICALLY_SCHEDULED)
	record["reservation_state"] = STATE_CANONICALLY_SCHEDULED
	record["canonical_command_id"] = canonical_command_id.strip_edges()
	record["execution_tick"] = execution_tick
	record["updated_ms"] = Time.get_ticks_msec()
	_store_record(record)
	return _result(record)

func resolve_canonical_outcome(
	match_id: String,
	owner_id: int,
	activation_id: String,
	activated: bool,
	reason: String,
	canonical_command_id: String,
	execution_tick: int
) -> Dictionary:
	var found: Dictionary = _find_record(match_id, owner_id, activation_id)
	if not bool(found.get("ok", false)):
		return found
	var record: Dictionary = found.get("record", {}) as Dictionary
	if _is_terminal(record) or str(record.get("reservation_state", "")) == STATE_EXECUTED:
		return _duplicate_result(record)
	record["canonical_command_id"] = canonical_command_id.strip_edges()
	record["execution_tick"] = execution_tick
	record["updated_ms"] = Time.get_ticks_msec()
	if activated:
		record["reservation_state"] = STATE_EXECUTED
		record["final_status"] = "executed"
		record["final_reason"] = "activated"
		_store_record(record)
		var execute_result: Dictionary = _result(record)
		execute_result["action"] = "commit"
		return execute_result
	return _release_record(record, "deterministic_no_op", reason if reason != "" else "target_stale")

func mark_committed(match_id: String, owner_id: int, activation_id: String) -> Dictionary:
	var found: Dictionary = _find_record(match_id, owner_id, activation_id)
	if not bool(found.get("ok", false)):
		return found
	var record: Dictionary = found.get("record", {}) as Dictionary
	if str(record.get("reservation_state", "")) == STATE_COMMITTED:
		return _duplicate_result(record)
	if str(record.get("reservation_state", "")) != STATE_EXECUTED:
		return _invalid_transition(record, STATE_COMMITTED)
	record["reservation_state"] = STATE_COMMITTED
	record["committed"] = true
	record["final_status"] = "executed"
	record["final_reason"] = "activated"
	record["updated_ms"] = Time.get_ticks_msec()
	_store_terminal(record)
	return _result(record)

func reject_submission(match_id: String, owner_id: int, activation_id: String, reason: String) -> Dictionary:
	var found: Dictionary = _find_record(match_id, owner_id, activation_id)
	if not bool(found.get("ok", false)):
		return found
	var record: Dictionary = found.get("record", {}) as Dictionary
	if _is_terminal(record):
		return _duplicate_result(record)
	return _release_record(record, "submission_rejected", reason if reason != "" else "submission_rejected")

func release(match_id: String, owner_id: int, activation_id: String, reason: String) -> Dictionary:
	var found: Dictionary = _find_record(match_id, owner_id, activation_id)
	if not bool(found.get("ok", false)):
		return found
	var record: Dictionary = found.get("record", {}) as Dictionary
	if _is_terminal(record):
		return _duplicate_result(record)
	return _release_record(record, "cancelled", reason if reason != "" else "cancelled")

func terminate_match(match_id: String, reason: String = "match_ended") -> Array[Dictionary]:
	var released: Array[Dictionary] = []
	for key_any in _transactions.keys():
		var record: Dictionary = _transactions.get(key_any, {}) as Dictionary
		if str(record.get("match_id", "")) != match_id or _is_terminal(record):
			continue
		released.append(_release_record(record, "match_terminated", reason))
	return released

func reconcile_outcome(outcome: Dictionary) -> Dictionary:
	var match_id: String = str(outcome.get("match_id", ""))
	var owner_id: int = int(outcome.get("owner_id", 0))
	var activation_id: String = str(outcome.get("activation_id", ""))
	var status: String = str(outcome.get("status", "")).strip_edges().to_lower()
	if status == "executed":
		return resolve_canonical_outcome(
			match_id,
			owner_id,
			activation_id,
			true,
			str(outcome.get("reason", "activated")),
			str(outcome.get("canonical_command_id", "")),
			int(outcome.get("execution_tick", -1))
		)
	return resolve_canonical_outcome(
		match_id,
		owner_id,
		activation_id,
		false,
		str(outcome.get("reason", "canonical_rejection")),
		str(outcome.get("canonical_command_id", "")),
		int(outcome.get("execution_tick", -1))
	)

func get_transaction(match_id: String, owner_id: int, activation_id: String) -> Dictionary:
	var found: Dictionary = _find_record(match_id, owner_id, activation_id)
	return _result(found.get("record", {}) as Dictionary) if bool(found.get("ok", false)) else found

func unresolved_transactions(match_id: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for record_any in _transactions.values():
		var record: Dictionary = record_any as Dictionary
		if _is_terminal(record):
			continue
		if match_id != "" and str(record.get("match_id", "")) != match_id:
			continue
		out.append(_result(record))
	return out

func export_state() -> Dictionary:
	return {
		"transactions": _transactions.duplicate(true),
		"terminal_order": _terminal_order.duplicate()
	}

func import_state(raw: Dictionary) -> void:
	_transactions.clear()
	_terminal_order.clear()
	var transactions_any: Variant = raw.get("transactions", {})
	if typeof(transactions_any) == TYPE_DICTIONARY:
		for key_any in (transactions_any as Dictionary).keys():
			var record_any: Variant = (transactions_any as Dictionary).get(key_any, {})
			if typeof(record_any) != TYPE_DICTIONARY:
				continue
			var record: Dictionary = (record_any as Dictionary).duplicate(true)
			var scope_key: String = str(record.get("scope_key", key_any))
			if scope_key != "":
				_transactions[scope_key] = record
	var order_any: Variant = raw.get("terminal_order", [])
	if typeof(order_any) == TYPE_ARRAY:
		for key_any in order_any as Array:
			var key: String = str(key_any)
			if _transactions.has(key) and _is_terminal(_transactions.get(key, {}) as Dictionary):
				_terminal_order.append(key)
	_prune_terminal_history()

func performance_snapshot() -> Dictionary:
	return {
		"transaction_count": _transactions.size(),
		"unresolved_count": unresolved_transactions().size(),
		"terminal_count": _terminal_order.size(),
		"max_terminal_history": MAX_TERMINAL_HISTORY,
		"per_frame_processing": false
	}

func _normalize_request(request: Dictionary) -> Dictionary:
	var match_id: String = str(request.get("match_id", "")).strip_edges()
	var owner_id: int = int(request.get("owner_id", 0))
	var activation_id: String = str(request.get("activation_id", "")).strip_edges()
	var buff_id: String = str(request.get("buff_id", "")).strip_edges()
	var charge_key: String = str(request.get("charge_key", "")).strip_edges()
	if match_id == "" or owner_id <= 0 or activation_id == "" or buff_id == "" or charge_key == "":
		return {"ok": false, "status": "rejected", "reason": "invalid_reservation_request"}
	var out: Dictionary = request.duplicate(true)
	out["ok"] = true
	out["match_id"] = match_id
	out["owner_id"] = owner_id
	out["activation_id"] = activation_id
	out["buff_id"] = buff_id
	out["charge_key"] = charge_key
	out["scope_key"] = _scope_key(match_id, owner_id, activation_id)
	var source_kind: String = str(request.get("source_kind", "inventory")).strip_edges().to_lower()
	var source_use_ordinal: int = int(request.get("source_use_ordinal", 1))
	if source_kind != "inventory" and source_kind != "vs" and source_kind != "async":
		return {"ok": false, "status": "rejected", "reason": "invalid_source_kind"}
	if ((source_kind == "inventory" or source_kind == "vs") and source_use_ordinal != 1) or (source_kind == "async" and (source_use_ordinal < 1 or source_use_ordinal > 2)):
		return {"ok": false, "status": "rejected", "reason": "invalid_source_use_ordinal"}
	out["source_kind"] = source_kind
	out["source_use_ordinal"] = source_use_ordinal
	return out

func _transition(
	match_id: String,
	owner_id: int,
	activation_id: String,
	allowed_states: Array[String],
	next_state: String,
	status: String
) -> Dictionary:
	var found: Dictionary = _find_record(match_id, owner_id, activation_id)
	if not bool(found.get("ok", false)):
		return found
	var record: Dictionary = found.get("record", {}) as Dictionary
	if _is_terminal(record):
		return _duplicate_result(record)
	if not allowed_states.has(str(record.get("reservation_state", ""))):
		return _invalid_transition(record, next_state)
	record["reservation_state"] = next_state
	record["final_status"] = status
	record["updated_ms"] = Time.get_ticks_msec()
	_store_record(record)
	return _result(record)

func _release_record(record: Dictionary, status: String, reason: String) -> Dictionary:
	record["reservation_state"] = STATE_RELEASED
	record["released"] = true
	record["final_status"] = status
	record["final_reason"] = reason
	record["updated_ms"] = Time.get_ticks_msec()
	_store_terminal(record)
	var out: Dictionary = _result(record)
	out["action"] = "release"
	return out

func _active_reservation_count(charge_key: String) -> int:
	var count: int = 0
	for record_any in _transactions.values():
		var record: Dictionary = record_any as Dictionary
		if str(record.get("charge_key", "")) != charge_key or _is_terminal(record):
			continue
		count += 1
	return count

func _find_record(match_id: String, owner_id: int, activation_id: String) -> Dictionary:
	var key: String = _scope_key(match_id, owner_id, activation_id)
	if not _transactions.has(key):
		return {
			"ok": false,
			"status": "rejected",
			"reason": "activation_not_found",
			"activation_id": activation_id
		}
	return {"ok": true, "record": (_transactions.get(key, {}) as Dictionary).duplicate(true)}

func _store_record(record: Dictionary) -> void:
	_transactions[str(record.get("scope_key", ""))] = record.duplicate(true)

func _store_terminal(record: Dictionary) -> void:
	_store_record(record)
	var key: String = str(record.get("scope_key", ""))
	if not _terminal_order.has(key):
		_terminal_order.append(key)
	_prune_terminal_history()

func _prune_terminal_history() -> void:
	while _terminal_order.size() > MAX_TERMINAL_HISTORY:
		var oldest_key: String = _terminal_order.pop_front()
		if _transactions.has(oldest_key) and _is_terminal(_transactions.get(oldest_key, {}) as Dictionary):
			_transactions.erase(oldest_key)

func _is_terminal(record: Dictionary) -> bool:
	var state: String = str(record.get("reservation_state", ""))
	return state == STATE_COMMITTED or state == STATE_RELEASED

func _invalid_transition(record: Dictionary, requested_state: String) -> Dictionary:
	var out: Dictionary = _result(record)
	out["ok"] = false
	out["status"] = "rejected"
	out["reason"] = "invalid_transition"
	out["requested_state"] = requested_state
	return out

func _duplicate_result(record: Dictionary) -> Dictionary:
	var out: Dictionary = _result(record)
	out["duplicate"] = true
	out["reason"] = "duplicate" if str(record.get("final_reason", "")) == "" else str(record.get("final_reason", ""))
	return out

func _result(record: Dictionary) -> Dictionary:
	var out: Dictionary = record.duplicate(true)
	out["ok"] = not record.is_empty()
	var final_status: String = str(record.get("final_status", ""))
	out["status"] = final_status if not final_status.is_empty() else str(record.get("reservation_state", ""))
	out["reason"] = str(record.get("final_reason", ""))
	return out

func _scope_key(match_id: String, owner_id: int, activation_id: String) -> String:
	return "%s|%d|%s" % [match_id.strip_edges(), owner_id, activation_id.strip_edges()]

func _reservation_id(record: Dictionary) -> String:
	return "%s|%s" % [str(record.get("scope_key", "")), str(record.get("charge_key", ""))]
