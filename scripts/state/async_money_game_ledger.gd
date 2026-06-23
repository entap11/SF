class_name AsyncMoneyGameLedger
extends RefCounted

const STATUS_ESCROWED: String = "escrowed"
const STATUS_SETTLED: String = "settled"
const STATUS_REFUNDED: String = "refunded"
const HOUSE_ACCOUNT_ID: String = "house"
const DEFAULT_HOUSE_RAKE_BPS: int = 1000
const BASIS_POINTS_DENOMINATOR: int = 10000

var _entries_by_id: Dictionary = {}
var _contest_pots: Dictionary = {}
var _operation_results_by_key: Dictionary = {}
var _transactions: Array[Dictionary] = []
var _next_transaction_seq: int = 1
var _house_rake_bps: int = DEFAULT_HOUSE_RAKE_BPS

func configure_house_rake_bps(rake_bps: int) -> void:
	_house_rake_bps = clampi(rake_bps, 0, BASIS_POINTS_DENOMINATOR)

func get_entry_snapshot(entry_id: String) -> Dictionary:
	var clean_entry_id: String = entry_id.strip_edges()
	var entry_any: Variant = _entries_by_id.get(clean_entry_id, {})
	if typeof(entry_any) != TYPE_DICTIONARY:
		return {}
	return (entry_any as Dictionary).duplicate(true)

func get_contest_snapshot(contest_id: String) -> Dictionary:
	var clean_contest_id: String = contest_id.strip_edges()
	var contest_any: Variant = _contest_pots.get(clean_contest_id, {})
	if typeof(contest_any) != TYPE_DICTIONARY:
		return {}
	return (contest_any as Dictionary).duplicate(true)

func get_snapshot() -> Dictionary:
	return {
		"house_rake_bps": _house_rake_bps,
		"entries": _entries_by_id.duplicate(true),
		"contest_pots": _contest_pots.duplicate(true),
		"transactions": _transactions.duplicate(true)
	}

func get_transaction_ledger(filters: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var limit: int = maxi(0, int(filters.get("limit", 0)))
	for transaction in _transactions:
		if not _transaction_matches_filters(transaction, filters):
			continue
		out.append(transaction.duplicate(true))
	if bool(filters.get("sort_desc", false)):
		out.reverse()
	if limit > 0 and out.size() > limit:
		out = out.slice(0, limit)
	return out

func get_transaction(transaction_id: String) -> Dictionary:
	var clean_transaction_id: String = transaction_id.strip_edges()
	if clean_transaction_id.is_empty():
		return {}
	for transaction in _transactions:
		if str(transaction.get("transaction_id", "")) == clean_transaction_id:
			return transaction.duplicate(true)
	return {}

func intent_open_entry_escrow(entry_id: String, contest_id: String, player_id: String, wager_cents: int, idempotency_key: String) -> Dictionary:
	var clean_key: String = idempotency_key.strip_edges()
	if clean_key.is_empty():
		return _error("missing_idempotency_key", "Idempotency key is required.")
	var cached: Dictionary = _cached_operation_result(clean_key)
	if not cached.is_empty():
		return cached
	var clean_entry_id: String = entry_id.strip_edges()
	var clean_contest_id: String = contest_id.strip_edges()
	var clean_player_id: String = player_id.strip_edges()
	if clean_entry_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_entry_id", "Entry id is required."))
	if clean_contest_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_contest_id", "Contest id is required."))
	if clean_player_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_player_id", "Player id is required."))
	if wager_cents <= 0:
		return _store_operation_result(clean_key, _error("invalid_wager", "Wager must be positive integer cents."))
	if _entries_by_id.has(clean_entry_id):
		return _store_operation_result(clean_key, _error("entry_already_exists", "Async money entry already has escrow."))
	var escrow_transaction: Dictionary = _append_transaction("async_entry_escrow_debit", clean_player_id, "debit", wager_cents, -1, {
		"entry_id": clean_entry_id,
		"contest_id": clean_contest_id,
		"player_id": clean_player_id,
		"idempotency_key": clean_key,
		"memo": "Async money entry escrow debit"
	})
	var entry: Dictionary = {
		"entry_id": clean_entry_id,
		"contest_id": clean_contest_id,
		"player_id": clean_player_id,
		"status": STATUS_ESCROWED,
		"wager_cents": wager_cents,
		"escrow_cents": wager_cents,
		"open_idempotency_key": clean_key,
		"escrow_transaction_id": str(escrow_transaction.get("transaction_id", ""))
	}
	_entries_by_id[clean_entry_id] = entry
	var pot: Dictionary = (_contest_pots.get(clean_contest_id, {}) as Dictionary).duplicate(true)
	if pot.is_empty():
		pot = {
			"contest_id": clean_contest_id,
			"status": STATUS_ESCROWED,
			"entry_ids": [],
			"player_ids": [],
			"wager_cents": wager_cents,
			"pot_cents": 0,
			"escrow_cents": 0,
			"winner_id": "",
			"winner_payout_cents": 0,
			"house_rake_cents": 0
		}
	var entry_ids: Array = pot.get("entry_ids", []) as Array
	var player_ids: Array = pot.get("player_ids", []) as Array
	entry_ids.append(clean_entry_id)
	if not player_ids.has(clean_player_id):
		player_ids.append(clean_player_id)
	pot["entry_ids"] = entry_ids
	pot["player_ids"] = player_ids
	pot["wager_cents"] = wager_cents
	pot["pot_cents"] = int(pot.get("pot_cents", 0)) + wager_cents
	pot["escrow_cents"] = int(pot.get("escrow_cents", 0)) + wager_cents
	_contest_pots[clean_contest_id] = pot
	return _store_operation_result(clean_key, {
		"ok": true,
		"type": "async_entry_escrowed",
		"entry_id": clean_entry_id,
		"contest_id": clean_contest_id,
		"player_id": clean_player_id,
		"status": STATUS_ESCROWED,
		"wager_cents": wager_cents,
		"pot_cents": int(pot.get("pot_cents", wager_cents)),
		"escrow_cents": int(pot.get("escrow_cents", wager_cents)),
		"transaction_ids": [str(escrow_transaction.get("transaction_id", ""))]
	})

func intent_settle_contest(contest_id: String, winner_id: String, idempotency_key: String) -> Dictionary:
	var clean_key: String = idempotency_key.strip_edges()
	if clean_key.is_empty():
		return _error("missing_idempotency_key", "Idempotency key is required.")
	var cached: Dictionary = _cached_operation_result(clean_key)
	if not cached.is_empty():
		return cached
	var clean_contest_id: String = contest_id.strip_edges()
	var clean_winner_id: String = winner_id.strip_edges()
	if clean_contest_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_contest_id", "Contest id is required."))
	if clean_winner_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_winner_id", "Winner id is required."))
	if not _contest_pots.has(clean_contest_id):
		return _store_operation_result(clean_key, _error("contest_not_found", "Contest escrow was not found."))
	var pot: Dictionary = (_contest_pots.get(clean_contest_id, {}) as Dictionary).duplicate(true)
	if str(pot.get("status", "")) != STATUS_ESCROWED:
		return _store_operation_result(clean_key, _error("contest_already_closed", "Only escrowed contests can be settled."))
	var player_ids: Array = pot.get("player_ids", []) as Array
	if not player_ids.has(clean_winner_id):
		return _store_operation_result(clean_key, _error("winner_not_in_contest", "Winner must be entered in contest."))
	var escrow_cents: int = maxi(0, int(pot.get("escrow_cents", 0)))
	if escrow_cents <= 0:
		return _store_operation_result(clean_key, _error("empty_escrow", "Escrow is empty."))
	var house_rake_cents: int = int((escrow_cents * _house_rake_bps) / BASIS_POINTS_DENOMINATOR)
	var winner_payout_cents: int = escrow_cents - house_rake_cents
	var payout_transaction: Dictionary = _append_transaction("async_winner_payout", clean_winner_id, "credit", winner_payout_cents, -1, {
		"contest_id": clean_contest_id,
		"player_id": clean_winner_id,
		"winner_id": clean_winner_id,
		"idempotency_key": clean_key,
		"memo": "Async money contest winner payout"
	})
	var rake_transaction: Dictionary = _append_transaction("async_house_rake", HOUSE_ACCOUNT_ID, "credit", house_rake_cents, -1, {
		"contest_id": clean_contest_id,
		"winner_id": clean_winner_id,
		"house_account_id": HOUSE_ACCOUNT_ID,
		"idempotency_key": clean_key,
		"memo": "Async money contest house rake"
	})
	pot["status"] = STATUS_SETTLED
	pot["winner_id"] = clean_winner_id
	pot["winner_payout_cents"] = winner_payout_cents
	pot["house_rake_cents"] = house_rake_cents
	pot["escrow_cents"] = 0
	pot["settle_idempotency_key"] = clean_key
	pot["settle_transaction_ids"] = [str(payout_transaction.get("transaction_id", "")), str(rake_transaction.get("transaction_id", ""))]
	_contest_pots[clean_contest_id] = pot
	for entry_id_any in pot.get("entry_ids", []) as Array:
		var entry_id: String = str(entry_id_any)
		var entry: Dictionary = (_entries_by_id.get(entry_id, {}) as Dictionary).duplicate(true)
		if entry.is_empty():
			continue
		entry["status"] = STATUS_SETTLED
		entry["escrow_cents"] = 0
		_entries_by_id[entry_id] = entry
	return _store_operation_result(clean_key, {
		"ok": true,
		"type": "async_contest_settled",
		"contest_id": clean_contest_id,
		"status": STATUS_SETTLED,
		"winner_id": clean_winner_id,
		"winner_payout_cents": winner_payout_cents,
		"house_rake_cents": house_rake_cents,
		"pot_cents": int(pot.get("pot_cents", escrow_cents)),
		"transaction_ids": pot.get("settle_transaction_ids", [])
	})

func intent_refund_entry(entry_id: String, reason: String, idempotency_key: String) -> Dictionary:
	var clean_key: String = idempotency_key.strip_edges()
	if clean_key.is_empty():
		return _error("missing_idempotency_key", "Idempotency key is required.")
	var cached: Dictionary = _cached_operation_result(clean_key)
	if not cached.is_empty():
		return cached
	var clean_entry_id: String = entry_id.strip_edges()
	if clean_entry_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_entry_id", "Entry id is required."))
	if not _entries_by_id.has(clean_entry_id):
		return _store_operation_result(clean_key, _error("entry_not_found", "Async money entry was not found."))
	var entry: Dictionary = (_entries_by_id.get(clean_entry_id, {}) as Dictionary).duplicate(true)
	if str(entry.get("status", "")) != STATUS_ESCROWED:
		return _store_operation_result(clean_key, _error("entry_already_closed", "Only escrowed entries can be refunded."))
	var refund_cents: int = maxi(0, int(entry.get("escrow_cents", 0)))
	var contest_id: String = str(entry.get("contest_id", ""))
	var player_id: String = str(entry.get("player_id", ""))
	var refund_transaction: Dictionary = _append_transaction("async_entry_refund_credit", player_id, "credit", refund_cents, -1, {
		"entry_id": clean_entry_id,
		"contest_id": contest_id,
		"player_id": player_id,
		"idempotency_key": clean_key,
		"memo": "Async money entry escrow refund"
	})
	entry["status"] = STATUS_REFUNDED
	entry["escrow_cents"] = 0
	entry["refund_reason"] = reason.strip_edges()
	entry["refund_idempotency_key"] = clean_key
	entry["refund_transaction_id"] = str(refund_transaction.get("transaction_id", ""))
	_entries_by_id[clean_entry_id] = entry
	var pot: Dictionary = (_contest_pots.get(contest_id, {}) as Dictionary).duplicate(true)
	if not pot.is_empty():
		pot["escrow_cents"] = maxi(0, int(pot.get("escrow_cents", 0)) - refund_cents)
		_contest_pots[contest_id] = pot
	return _store_operation_result(clean_key, {
		"ok": true,
		"type": "async_entry_refunded",
		"entry_id": clean_entry_id,
		"contest_id": contest_id,
		"status": STATUS_REFUNDED,
		"refunded_cents": refund_cents,
		"refund_reason": str(entry.get("refund_reason", "")),
		"transaction_ids": [str(refund_transaction.get("transaction_id", ""))]
	})

func _cached_operation_result(idempotency_key: String) -> Dictionary:
	if idempotency_key.is_empty():
		return {}
	var cached_any: Variant = _operation_results_by_key.get(idempotency_key, {})
	if typeof(cached_any) != TYPE_DICTIONARY:
		return {}
	return (cached_any as Dictionary).duplicate(true)

func _store_operation_result(idempotency_key: String, result: Dictionary) -> Dictionary:
	var out: Dictionary = result.duplicate(true)
	if not idempotency_key.is_empty():
		out["idempotency_key"] = idempotency_key
		_operation_results_by_key[idempotency_key] = out.duplicate(true)
	return out

func _append_transaction(transaction_type: String, account_id: String, direction: String, amount_cents: int, balance_after_cents: int, context: Dictionary) -> Dictionary:
	var transaction_seq: int = _next_transaction_seq
	_next_transaction_seq += 1
	var now_unix: int = int(Time.get_unix_time_from_system())
	var transaction: Dictionary = {
		"transaction_id": "ASYNC-%09d" % transaction_seq,
		"transaction_seq": transaction_seq,
		"created_unix": now_unix,
		"created_utc": _utc_stamp(now_unix),
		"ledger": "async_money_game",
		"transaction_type": transaction_type,
		"status": "posted",
		"account_id": account_id.strip_edges(),
		"direction": direction,
		"amount_cents": maxi(0, amount_cents),
		"balance_after_cents": balance_after_cents
	}
	for key_any in context.keys():
		var key: String = str(key_any)
		transaction[key] = context.get(key_any)
	_transactions.append(transaction)
	return transaction.duplicate(true)

func _transaction_matches_filters(transaction: Dictionary, filters: Dictionary) -> bool:
	for key in ["account_id", "contest_id", "entry_id", "player_id", "winner_id", "transaction_type", "direction", "status", "ledger", "idempotency_key"]:
		if filters.has(key) and str(transaction.get(key, "")) != str(filters.get(key, "")):
			return false
	if filters.has("from_unix") and int(transaction.get("created_unix", 0)) < int(filters.get("from_unix", 0)):
		return false
	if filters.has("to_unix") and int(transaction.get("created_unix", 0)) > int(filters.get("to_unix", 0)):
		return false
	return true

func _utc_stamp(unix_time: int) -> String:
	var stamp: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		int(stamp.get("year", 1970)),
		int(stamp.get("month", 1)),
		int(stamp.get("day", 1)),
		int(stamp.get("hour", 0)),
		int(stamp.get("minute", 0)),
		int(stamp.get("second", 0))
	]

func _error(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"message": message
	}
