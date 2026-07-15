class_name BuffActivationPresentationReceipts
extends RefCounted

const Config := preload("res://scripts/renderers/buff_targeting_presentation_config.gd")

var _receipts: Dictionary = {}
var _handled: Dictionary = {}
var _sequence: int = 0


func register_submission(
	match_id: String,
	owner_id: int,
	activation_id: String,
	target_type: String,
	target_id: Variant,
	presentation_epoch: String,
	submitted_at_msec: int = -1
) -> Dictionary:
	var clean_match: String = match_id.strip_edges()
	var clean_activation: String = activation_id.strip_edges()
	var clean_epoch: String = presentation_epoch.strip_edges()
	var clean_type: String = target_type.strip_edges()
	if clean_match.is_empty() or owner_id <= 0 or clean_activation.is_empty() \
	or clean_epoch.is_empty() or not _valid_target(clean_type, target_id):
		return {"ok": false, "reason": "invalid_presentation_receipt"}
	var now_msec: int = _monotonic_msec() if submitted_at_msec < 0 else submitted_at_msec
	_expire_receipts(now_msec)
	var key: String = _key(clean_match, owner_id, clean_activation, clean_epoch)
	if _handled.has(key):
		return {"ok": false, "reason": "outcome_already_handled"}
	if _receipts.has(key):
		return {"ok": true, "duplicate": true, "receipt": (_receipts[key] as Dictionary).duplicate(true)}
	_sequence += 1
	var receipt: Dictionary = {
		"match_id": clean_match,
		"owner_id": owner_id,
		"activation_id": clean_activation,
		"target_type": clean_type,
		"target_id": target_id,
		"presentation_epoch": clean_epoch,
		"submitted_at_msec": now_msec,
		"sequence": _sequence
	}
	_receipts[key] = receipt
	_enforce_receipt_bound(now_msec)
	return {"ok": true, "duplicate": false, "receipt": receipt.duplicate(true)}


func consume_canonical_outcome(
	outcome: Dictionary,
	presentation_epoch: String,
	now_msec: int = -1
) -> Dictionary:
	var age_now: int = _monotonic_msec() if now_msec < 0 else now_msec
	_expire_receipts(age_now)
	var match_id: String = str(outcome.get("match_id", "")).strip_edges()
	var owner_id: int = int(outcome.get("owner_id", 0))
	var activation_id: String = str(outcome.get("activation_id", "")).strip_edges()
	var clean_epoch: String = presentation_epoch.strip_edges()
	if match_id.is_empty() or owner_id <= 0 or activation_id.is_empty() or clean_epoch.is_empty():
		return {"feedback": false, "reason": "outcome_identity_incomplete"}
	var key: String = _key(match_id, owner_id, activation_id, clean_epoch)
	if _handled.has(key):
		var handled: Dictionary = _handled[key] as Dictionary
		return {"feedback": false, "reason": str(handled.get("reason", "outcome_already_handled")), "duplicate": true}
	var receipt_any: Variant = _receipts.get(key, null)
	if typeof(receipt_any) != TYPE_DICTIONARY:
		return {"feedback": false, "reason": "matching_receipt_missing"}
	var receipt: Dictionary = receipt_any as Dictionary
	if str(receipt.get("match_id", "")) != match_id \
	or int(receipt.get("owner_id", 0)) != owner_id \
	or str(receipt.get("activation_id", "")) != activation_id \
	or str(receipt.get("presentation_epoch", "")) != clean_epoch:
		return {"feedback": false, "reason": "presentation_identity_mismatch"}
	var receipt_age: int = maxi(0, age_now - int(receipt.get("submitted_at_msec", age_now)))
	if receipt_age > Config.ACTIVATION_RECEIPT_TIMEOUT_MSEC:
		_receipts.erase(key)
		_record_handled(key, "receipt_expired", age_now)
		return {"feedback": false, "reason": "receipt_expired", "receipt_age_msec": receipt_age}
	var receipt_type: String = str(receipt.get("target_type", ""))
	var outcome_type: String = str(outcome.get("target_type", receipt_type))
	var receipt_target: Variant = receipt.get("target_id", null)
	var outcome_target: Variant = outcome.get("target_id", receipt_target)
	if outcome_type != receipt_type or outcome_target != receipt_target:
		_receipts.erase(key)
		_record_handled(key, "canonical_target_mismatch", age_now)
		return {"feedback": false, "reason": "canonical_target_mismatch"}
	_receipts.erase(key)
	var success: bool = str(outcome.get("status", "")) == "executed" \
		and str(outcome.get("reason", "")) == "activated"
	_record_handled(key, "feedback_started" if success else "canonical_outcome_not_executed", age_now)
	return {
		"feedback": success,
		"reason": "feedback_started" if success else "canonical_outcome_not_executed",
		"receipt": receipt.duplicate(true),
		"receipt_age_msec": receipt_age
	}


func expire(now_msec: int = -1) -> void:
	_expire_receipts(_monotonic_msec() if now_msec < 0 else now_msec)


func clear() -> void:
	_receipts.clear()
	_handled.clear()


func snapshot() -> Dictionary:
	var handled_reason_counts: Dictionary = {}
	for handled_any: Variant in _handled.values():
		var handled: Dictionary = handled_any as Dictionary
		var reason: String = str(handled.get("reason", "unknown"))
		handled_reason_counts[reason] = int(handled_reason_counts.get(reason, 0)) + 1
	return {
		"live_receipt_count": _receipts.size(),
		"handled_outcome_count": _handled.size(),
		"handled_reason_counts": handled_reason_counts,
		"receipt_timeout_msec": Config.ACTIVATION_RECEIPT_TIMEOUT_MSEC,
		"max_live_receipt_count": Config.MAX_LIVE_ACTIVATION_RECEIPTS,
		"max_handled_outcome_count": Config.MAX_HANDLED_OUTCOMES,
		"eviction_rule": "oldest_submission_then_sequence",
		"late_outcome_behavior": "gameplay_result_stands_without_flash"
	}


func _expire_receipts(now_msec: int) -> void:
	var expired_keys: Array[String] = []
	for key_any: Variant in _receipts.keys():
		var key: String = str(key_any)
		var receipt: Dictionary = _receipts[key] as Dictionary
		if now_msec - int(receipt.get("submitted_at_msec", now_msec)) > Config.ACTIVATION_RECEIPT_TIMEOUT_MSEC:
			expired_keys.append(key)
	for key: String in expired_keys:
		_receipts.erase(key)
		_record_handled(key, "receipt_expired", now_msec)


func _enforce_receipt_bound(now_msec: int) -> void:
	while _receipts.size() > Config.MAX_LIVE_ACTIVATION_RECEIPTS:
		var oldest_key: String = _oldest_dictionary_key(_receipts, "submitted_at_msec")
		if oldest_key.is_empty():
			break
		_receipts.erase(oldest_key)
		_record_handled(oldest_key, "receipt_capacity_evicted", now_msec)


func _record_handled(key: String, reason: String, now_msec: int) -> void:
	_sequence += 1
	_handled[key] = {"reason": reason, "handled_at_msec": now_msec, "sequence": _sequence}
	while _handled.size() > Config.MAX_HANDLED_OUTCOMES:
		var oldest_key: String = _oldest_dictionary_key(_handled, "handled_at_msec")
		if oldest_key.is_empty():
			break
		_handled.erase(oldest_key)


func _oldest_dictionary_key(entries: Dictionary, time_field: String) -> String:
	var best_key: String = ""
	var best_time: int = 9223372036854775807
	var best_sequence: int = 9223372036854775807
	for key_any: Variant in entries.keys():
		var key: String = str(key_any)
		var entry: Dictionary = entries[key] as Dictionary
		var entry_time: int = int(entry.get(time_field, 0))
		var entry_sequence: int = int(entry.get("sequence", 0))
		if entry_time < best_time or (entry_time == best_time and entry_sequence < best_sequence):
			best_key = key
			best_time = entry_time
			best_sequence = entry_sequence
	return best_key


func _valid_target(target_type: String, target_id: Variant) -> bool:
	if target_type == "global":
		return str(target_id) == "global"
	if target_type == "hive" or target_type == "lane":
		return target_id != null and int(target_id) > 0
	return false


func _key(match_id: String, owner_id: int, activation_id: String, epoch: String) -> String:
	return "%s|%d|%s|%s" % [match_id, owner_id, activation_id, epoch]


func _monotonic_msec() -> int:
	return Time.get_ticks_msec()
