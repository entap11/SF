class_name MoneyGameLedger
extends RefCounted

const STATUS_ESCROWED: String = "escrowed"
const STATUS_SETTLED: String = "settled"
const STATUS_REFUNDED: String = "refunded"
const HOUSE_ACCOUNT_ID: String = "house"
const DEFAULT_HOUSE_RAKE_BPS: int = 1000
const BASIS_POINTS_DENOMINATOR: int = 10000

var _balances_cents: Dictionary = {}
var _matches_by_session_id: Dictionary = {}
var _operation_results_by_key: Dictionary = {}
var _transactions: Array[Dictionary] = []
var _next_transaction_seq: int = 1
var _house_rake_bps: int = DEFAULT_HOUSE_RAKE_BPS

func configure_house_rake_bps(rake_bps: int) -> void:
	_house_rake_bps = clampi(rake_bps, 0, BASIS_POINTS_DENOMINATOR)

func set_balance_cents(account_id: String, amount_cents: int) -> Dictionary:
	var clean_id: String = account_id.strip_edges()
	if clean_id.is_empty():
		return _error("missing_account_id", "Account id is required.")
	_balances_cents[clean_id] = maxi(0, amount_cents)
	return {"ok": true, "account_id": clean_id, "balance_cents": int(_balances_cents.get(clean_id, 0))}

func get_balance_cents(account_id: String) -> int:
	return int(_balances_cents.get(account_id.strip_edges(), 0))

func get_match_snapshot(session_id: String) -> Dictionary:
	var clean_session_id: String = session_id.strip_edges()
	var match_any: Variant = _matches_by_session_id.get(clean_session_id, {})
	if typeof(match_any) != TYPE_DICTIONARY:
		return {}
	return (match_any as Dictionary).duplicate(true)

func get_snapshot() -> Dictionary:
	return {
		"house_rake_bps": _house_rake_bps,
		"balances_cents": _balances_cents.duplicate(true),
		"matches": _matches_by_session_id.duplicate(true),
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

func intent_open_escrow(session_id: String, player_ids: Array, wager_cents: int, idempotency_key: String) -> Dictionary:
	var clean_key: String = idempotency_key.strip_edges()
	if clean_key.is_empty():
		return _error("missing_idempotency_key", "Idempotency key is required.")
	var cached: Dictionary = _cached_operation_result(clean_key)
	if not cached.is_empty():
		return cached
	var clean_session_id: String = session_id.strip_edges()
	if clean_session_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_session_id", "Session id is required."))
	if wager_cents <= 0:
		return _store_operation_result(clean_key, _error("invalid_wager", "Wager must be positive integer cents."))
	var clean_players: Array[String] = _normalize_player_ids(player_ids)
	if clean_players.size() < 2:
		return _store_operation_result(clean_key, _error("not_enough_players", "At least two players are required."))
	if _has_duplicate_player(clean_players):
		return _store_operation_result(clean_key, _error("duplicate_player", "Players in a money match must be unique."))
	if _matches_by_session_id.has(clean_session_id):
		return _store_operation_result(clean_key, _error("match_already_exists", "Money match already has a ledger record."))
	for player_id in clean_players:
		if get_balance_cents(player_id) < wager_cents:
			return _store_operation_result(clean_key, {
				"ok": false,
				"code": "insufficient_funds",
				"message": "Player has insufficient funds.",
				"player_id": player_id,
				"balance_cents": get_balance_cents(player_id),
				"required_cents": wager_cents
			})
	for player_id in clean_players:
		_balances_cents[player_id] = get_balance_cents(player_id) - wager_cents
	var transaction_ids: Array[String] = []
	for player_id in clean_players:
		var transaction: Dictionary = _append_transaction("escrow_debit", player_id, "debit", wager_cents, get_balance_cents(player_id), {
			"session_id": clean_session_id,
			"player_id": player_id,
			"idempotency_key": clean_key,
			"memo": "Money game escrow debit"
		})
		transaction_ids.append(str(transaction.get("transaction_id", "")))
	var pot_cents: int = wager_cents * clean_players.size()
	var record: Dictionary = {
		"session_id": clean_session_id,
		"status": STATUS_ESCROWED,
		"player_ids": clean_players.duplicate(),
		"wager_cents": wager_cents,
		"pot_cents": pot_cents,
		"escrow_cents": pot_cents,
		"escrow_transaction_ids": transaction_ids.duplicate(),
		"winner_id": "",
		"winner_payout_cents": 0,
		"house_rake_cents": 0,
		"open_idempotency_key": clean_key
	}
	_matches_by_session_id[clean_session_id] = record
	return _store_operation_result(clean_key, {
		"ok": true,
		"type": "escrow_opened",
		"session_id": clean_session_id,
		"status": STATUS_ESCROWED,
		"player_ids": clean_players.duplicate(),
		"wager_cents": wager_cents,
		"pot_cents": pot_cents,
		"escrow_cents": pot_cents,
		"transaction_ids": transaction_ids.duplicate(),
		"balances_cents": _balances_for(clean_players)
	})

func intent_settle_match(session_id: String, winner_id: String, idempotency_key: String) -> Dictionary:
	var clean_key: String = idempotency_key.strip_edges()
	if clean_key.is_empty():
		return _error("missing_idempotency_key", "Idempotency key is required.")
	var cached: Dictionary = _cached_operation_result(clean_key)
	if not cached.is_empty():
		return cached
	var clean_session_id: String = session_id.strip_edges()
	var clean_winner_id: String = winner_id.strip_edges()
	if clean_session_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_session_id", "Session id is required."))
	if clean_winner_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_winner_id", "Winner id is required."))
	if not _matches_by_session_id.has(clean_session_id):
		return _store_operation_result(clean_key, _error("match_not_found", "Money match ledger record was not found."))
	var record: Dictionary = (_matches_by_session_id.get(clean_session_id, {}) as Dictionary).duplicate(true)
	var status: String = str(record.get("status", ""))
	if status != STATUS_ESCROWED:
		return _store_operation_result(clean_key, {
			"ok": false,
			"code": "match_already_closed",
			"message": "Only escrowed matches can be settled.",
			"session_id": clean_session_id,
			"status": status
		})
	var player_ids: Array = record.get("player_ids", []) as Array
	if not player_ids.has(clean_winner_id):
		return _store_operation_result(clean_key, _error("winner_not_in_match", "Winner must be a player in the match."))
	var escrow_cents: int = maxi(0, int(record.get("escrow_cents", 0)))
	if escrow_cents <= 0:
		return _store_operation_result(clean_key, _error("empty_escrow", "Escrow is empty."))
	var house_rake_cents: int = int((escrow_cents * _house_rake_bps) / BASIS_POINTS_DENOMINATOR)
	var winner_payout_cents: int = escrow_cents - house_rake_cents
	_balances_cents[clean_winner_id] = get_balance_cents(clean_winner_id) + winner_payout_cents
	_balances_cents[HOUSE_ACCOUNT_ID] = get_balance_cents(HOUSE_ACCOUNT_ID) + house_rake_cents
	var payout_transaction: Dictionary = _append_transaction("winner_payout", clean_winner_id, "credit", winner_payout_cents, get_balance_cents(clean_winner_id), {
		"session_id": clean_session_id,
		"player_id": clean_winner_id,
		"winner_id": clean_winner_id,
		"idempotency_key": clean_key,
		"memo": "Money game winner payout"
	})
	var rake_transaction: Dictionary = _append_transaction("house_rake", HOUSE_ACCOUNT_ID, "credit", house_rake_cents, get_balance_cents(HOUSE_ACCOUNT_ID), {
		"session_id": clean_session_id,
		"winner_id": clean_winner_id,
		"house_account_id": HOUSE_ACCOUNT_ID,
		"idempotency_key": clean_key,
		"memo": "Money game house rake"
	})
	record["status"] = STATUS_SETTLED
	record["winner_id"] = clean_winner_id
	record["winner_payout_cents"] = winner_payout_cents
	record["house_rake_cents"] = house_rake_cents
	record["escrow_cents"] = 0
	record["settle_idempotency_key"] = clean_key
	record["settle_transaction_ids"] = [str(payout_transaction.get("transaction_id", "")), str(rake_transaction.get("transaction_id", ""))]
	_matches_by_session_id[clean_session_id] = record
	return _store_operation_result(clean_key, {
		"ok": true,
		"type": "match_settled",
		"session_id": clean_session_id,
		"status": STATUS_SETTLED,
		"winner_id": clean_winner_id,
		"winner_payout_cents": winner_payout_cents,
		"house_rake_cents": house_rake_cents,
		"pot_cents": int(record.get("pot_cents", escrow_cents)),
		"transaction_ids": record.get("settle_transaction_ids", []),
		"balances_cents": _balances_for(player_ids + [HOUSE_ACCOUNT_ID])
	})

func intent_refund_match(session_id: String, reason: String, idempotency_key: String) -> Dictionary:
	var clean_key: String = idempotency_key.strip_edges()
	if clean_key.is_empty():
		return _error("missing_idempotency_key", "Idempotency key is required.")
	var cached: Dictionary = _cached_operation_result(clean_key)
	if not cached.is_empty():
		return cached
	var clean_session_id: String = session_id.strip_edges()
	if clean_session_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_session_id", "Session id is required."))
	if not _matches_by_session_id.has(clean_session_id):
		return _store_operation_result(clean_key, _error("match_not_found", "Money match ledger record was not found."))
	var record: Dictionary = (_matches_by_session_id.get(clean_session_id, {}) as Dictionary).duplicate(true)
	var status: String = str(record.get("status", ""))
	if status != STATUS_ESCROWED:
		return _store_operation_result(clean_key, {
			"ok": false,
			"code": "match_already_closed",
			"message": "Only escrowed matches can be refunded.",
			"session_id": clean_session_id,
			"status": status
		})
	var player_ids: Array = record.get("player_ids", []) as Array
	var wager_cents: int = maxi(0, int(record.get("wager_cents", 0)))
	var transaction_ids: Array[String] = []
	for player_any in player_ids:
		var player_id: String = str(player_any).strip_edges()
		if player_id.is_empty():
			continue
		_balances_cents[player_id] = get_balance_cents(player_id) + wager_cents
		var transaction: Dictionary = _append_transaction("refund_credit", player_id, "credit", wager_cents, get_balance_cents(player_id), {
			"session_id": clean_session_id,
			"player_id": player_id,
			"idempotency_key": clean_key,
			"memo": "Money game escrow refund"
		})
		transaction_ids.append(str(transaction.get("transaction_id", "")))
	record["status"] = STATUS_REFUNDED
	record["escrow_cents"] = 0
	record["refund_reason"] = reason.strip_edges()
	record["refund_idempotency_key"] = clean_key
	record["refund_transaction_ids"] = transaction_ids.duplicate()
	_matches_by_session_id[clean_session_id] = record
	return _store_operation_result(clean_key, {
		"ok": true,
		"type": "match_refunded",
		"session_id": clean_session_id,
		"status": STATUS_REFUNDED,
		"refund_reason": str(record.get("refund_reason", "")),
		"refunded_cents_per_player": wager_cents,
		"transaction_ids": transaction_ids.duplicate(),
		"balances_cents": _balances_for(player_ids)
	})

func _normalize_player_ids(player_ids: Array) -> Array[String]:
	var out: Array[String] = []
	for player_any in player_ids:
		var player_id: String = str(player_any).strip_edges()
		if player_id.is_empty():
			continue
		out.append(player_id)
	return out

func _has_duplicate_player(player_ids: Array[String]) -> bool:
	var seen: Dictionary = {}
	for player_id in player_ids:
		if seen.has(player_id):
			return true
		seen[player_id] = true
	return false

func _balances_for(account_ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for account_any in account_ids:
		var account_id: String = str(account_any).strip_edges()
		if account_id.is_empty():
			continue
		out[account_id] = get_balance_cents(account_id)
	return out

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
		"transaction_id": "SYNC-%09d" % transaction_seq,
		"transaction_seq": transaction_seq,
		"created_unix": now_unix,
		"created_utc": _utc_stamp(now_unix),
		"ledger": "sync_money_game",
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
	for key in ["account_id", "session_id", "player_id", "winner_id", "transaction_type", "direction", "status", "ledger", "idempotency_key"]:
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
