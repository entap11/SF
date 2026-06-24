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
var _approval_reports_by_id: Dictionary = {}
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
		"approval_reports": _approval_reports_by_id.duplicate(true),
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

func build_contest_payout_approval_report(contest_id: String, payouts: Array, house_rake_bps: int) -> Dictionary:
	var clean_contest_id: String = contest_id.strip_edges()
	if clean_contest_id.is_empty():
		return _error("missing_contest_id", "Contest id is required.")
	if not _contest_pots.has(clean_contest_id):
		return _error("contest_not_found", "Contest escrow was not found.")
	var pot: Dictionary = (_contest_pots.get(clean_contest_id, {}) as Dictionary).duplicate(true)
	if str(pot.get("status", "")) != STATUS_ESCROWED:
		return _error("contest_already_closed", "Only escrowed contests can be reported.")
	var escrow_cents: int = maxi(0, int(pot.get("escrow_cents", 0)))
	if escrow_cents <= 0:
		return _error("empty_escrow", "Escrow is empty.")
	var normalized_percentages: Array[Dictionary] = _normalize_settlement_payouts(payouts)
	if normalized_percentages.is_empty():
		return _error("missing_payouts", "At least one payout is required.")
	var clean_house_rake_bps: int = DEFAULT_HOUSE_RAKE_BPS
	var payout_total_bps: int = 0
	var seen_players: Dictionary = {}
	var seen_placements: Dictionary = {}
	var player_ids: Array = pot.get("player_ids", []) as Array
	for payout in normalized_percentages:
		var payout_player_id: String = str(payout.get("player_id", "")).strip_edges()
		var placement: int = maxi(1, int(payout.get("placement", 0)))
		var payout_bps: int = clampi(int(payout.get("payout_bps", 0)), 0, BASIS_POINTS_DENOMINATOR)
		if payout_player_id.is_empty():
			return _error("missing_payout_player", "Each payout requires a player id.")
		if not player_ids.has(payout_player_id):
			return _error("payout_player_not_in_contest", "Payout player must be entered in contest.")
		if seen_players.has(payout_player_id):
			return _error("duplicate_payout_player", "Each player can receive one settlement payout.")
		if seen_placements.has(placement):
			return _error("duplicate_payout_placement", "Each placement can receive one settlement payout.")
		if payout_bps <= 0:
			return _error("invalid_payout_percentage", "Payout percentages must be positive basis points.")
		seen_players[payout_player_id] = true
		seen_placements[placement] = true
		payout_total_bps += payout_bps
	var house_rake_cents: int = int((escrow_cents * clean_house_rake_bps) / BASIS_POINTS_DENOMINATOR)
	var player_pool_cents: int = maxi(0, escrow_cents - house_rake_cents)
	if payout_total_bps != BASIS_POINTS_DENOMINATOR:
		return _error("settlement_percentages_not_balanced", "Payout percentages must equal 100 percent of the post-rake player pool.")
	var planned_payouts: Array[Dictionary] = []
	var payout_total_cents: int = 0
	for payout in normalized_percentages:
		var amount_cents: int = int((player_pool_cents * int(payout.get("payout_bps", 0))) / BASIS_POINTS_DENOMINATOR)
		payout_total_cents += amount_cents
		var planned: Dictionary = payout.duplicate(true)
		planned["amount_cents"] = amount_cents
		planned_payouts.append(planned)
	var rounding_remainder_cents: int = player_pool_cents - payout_total_cents
	if rounding_remainder_cents > 0 and not planned_payouts.is_empty():
		planned_payouts[0]["amount_cents"] = int(planned_payouts[0].get("amount_cents", 0)) + rounding_remainder_cents
		payout_total_cents += rounding_remainder_cents
	var entry_counts: Dictionary = _contest_entry_counts(pot)
	var report_id: String = _approval_report_id(clean_contest_id, escrow_cents, clean_house_rake_bps, planned_payouts)
	return {
		"ok": true,
		"type": "async_contest_payout_approval_report",
		"approval_status": "pending_approval",
		"approval_required": true,
		"report_id": report_id,
		"contest_id": clean_contest_id,
		"players_count": player_ids.size(),
		"entries_count": int(entry_counts.get("entries_count", 0)),
		"paid_entries_count": int(entry_counts.get("paid_entries_count", 0)),
		"refunded_entries_count": int(entry_counts.get("refunded_entries_count", 0)),
		"total_take_cents": escrow_cents,
		"pot_cents": int(pot.get("pot_cents", escrow_cents)),
		"escrow_cents": escrow_cents,
		"house_rake_bps": clean_house_rake_bps,
		"house_rake_cents": house_rake_cents,
		"player_pool_cents": player_pool_cents,
		"payout_basis": "post_rake_pool",
		"payout_total_bps": payout_total_bps,
		"payout_total_cents": payout_total_cents,
		"planned_payouts": planned_payouts,
		"payout_count": planned_payouts.size(),
		"rounding_remainder_cents": rounding_remainder_cents
	}

func preview_contest_payout_approval_report(contest_id: String, payouts: Array, house_rake_bps: int) -> Dictionary:
	var report: Dictionary = build_contest_payout_approval_report(contest_id, payouts, house_rake_bps)
	if bool(report.get("ok", false)):
		var now_unix: int = int(Time.get_unix_time_from_system())
		report["generated_unix"] = now_unix
		report["updated_unix"] = now_unix
		_approval_reports_by_id[str(report.get("report_id", ""))] = report.duplicate(true)
	return report

func get_payout_approval_reports(filters: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var limit: int = maxi(0, int(filters.get("limit", 0)))
	for report_any in _approval_reports_by_id.values():
		if typeof(report_any) != TYPE_DICTIONARY:
			continue
		var report: Dictionary = report_any as Dictionary
		if not _approval_report_matches_filters(report, filters):
			continue
		out.append(report.duplicate(true))
	if bool(filters.get("sort_desc", false)):
		out.reverse()
	if limit > 0 and out.size() > limit:
		out = out.slice(0, limit)
	return out

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
			"payout_total_cents": 0,
			"payout_count": 0,
			"payouts": [],
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
	var pot: Dictionary = (_contest_pots.get(clean_contest_id, {}) as Dictionary).duplicate(true)
	if not pot.is_empty():
		var player_ids: Array = pot.get("player_ids", []) as Array
		if not player_ids.has(clean_winner_id):
			return _store_operation_result(clean_key, _error("winner_not_in_contest", "Winner must be entered in contest."))
	var escrow_cents: int = maxi(0, int(pot.get("escrow_cents", 0)))
	var house_rake_cents: int = int((escrow_cents * _house_rake_bps) / BASIS_POINTS_DENOMINATOR)
	var winner_payout_cents: int = escrow_cents - house_rake_cents
	return intent_settle_contest_payouts(clean_contest_id, [{
		"placement": 1,
		"player_id": clean_winner_id,
		"amount_cents": winner_payout_cents
	}], house_rake_cents, idempotency_key)

func intent_settle_contest_payouts(contest_id: String, payouts: Array, house_rake_cents: int, idempotency_key: String) -> Dictionary:
	var clean_key: String = idempotency_key.strip_edges()
	if clean_key.is_empty():
		return _error("missing_idempotency_key", "Idempotency key is required.")
	var cached: Dictionary = _cached_operation_result(clean_key)
	if not cached.is_empty():
		return cached
	var clean_contest_id: String = contest_id.strip_edges()
	if clean_contest_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_contest_id", "Contest id is required."))
	if not _contest_pots.has(clean_contest_id):
		return _store_operation_result(clean_key, _error("contest_not_found", "Contest escrow was not found."))
	var pot: Dictionary = (_contest_pots.get(clean_contest_id, {}) as Dictionary).duplicate(true)
	if str(pot.get("status", "")) != STATUS_ESCROWED:
		return _store_operation_result(clean_key, _error("contest_already_closed", "Only escrowed contests can be settled."))
	var player_ids: Array = pot.get("player_ids", []) as Array
	var escrow_cents: int = maxi(0, int(pot.get("escrow_cents", 0)))
	if escrow_cents <= 0:
		return _store_operation_result(clean_key, _error("empty_escrow", "Escrow is empty."))
	var normalized_payouts: Array[Dictionary] = _normalize_settlement_payouts(payouts)
	if normalized_payouts.is_empty():
		return _store_operation_result(clean_key, _error("missing_payouts", "At least one payout is required."))
	var payout_total_cents: int = 0
	var seen_players: Dictionary = {}
	var seen_placements: Dictionary = {}
	for payout in normalized_payouts:
		var payout_player_id: String = str(payout.get("player_id", "")).strip_edges()
		var placement: int = maxi(1, int(payout.get("placement", 0)))
		var amount_cents: int = maxi(0, int(payout.get("amount_cents", 0)))
		if payout_player_id.is_empty():
			return _store_operation_result(clean_key, _error("missing_payout_player", "Each payout requires a player id."))
		if not player_ids.has(payout_player_id):
			return _store_operation_result(clean_key, _error("payout_player_not_in_contest", "Payout player must be entered in contest."))
		if seen_players.has(payout_player_id):
			return _store_operation_result(clean_key, _error("duplicate_payout_player", "Each player can receive one settlement payout."))
		if seen_placements.has(placement):
			return _store_operation_result(clean_key, _error("duplicate_payout_placement", "Each placement can receive one settlement payout."))
		if amount_cents <= 0:
			return _store_operation_result(clean_key, _error("invalid_payout_amount", "Payout amounts must be positive integer cents."))
		seen_players[payout_player_id] = true
		seen_placements[placement] = true
		payout_total_cents += amount_cents
	var clean_house_rake_cents: int = maxi(0, house_rake_cents)
	if payout_total_cents + clean_house_rake_cents != escrow_cents:
		return _store_operation_result(clean_key, _error("settlement_not_balanced", "Payouts plus house rake must equal escrow."))
	var transaction_ids: Array[String] = []
	for payout in normalized_payouts:
		var payout_player_id: String = str(payout.get("player_id", "")).strip_edges()
		var placement: int = maxi(1, int(payout.get("placement", 0)))
		var amount_cents: int = maxi(0, int(payout.get("amount_cents", 0)))
		var payout_transaction: Dictionary = _append_transaction("async_winner_payout", payout_player_id, "credit", amount_cents, -1, {
			"contest_id": clean_contest_id,
			"player_id": payout_player_id,
			"winner_id": str(normalized_payouts[0].get("player_id", "")),
			"placement": placement,
			"payout_bps": clampi(int(payout.get("payout_bps", 0)), 0, BASIS_POINTS_DENOMINATOR),
			"payout_count": normalized_payouts.size(),
			"approval_id": str(payout.get("approval_id", "")),
			"approved_by": str(payout.get("approved_by", "")),
			"idempotency_key": clean_key,
			"memo": "Async money contest winner payout"
		})
		transaction_ids.append(str(payout_transaction.get("transaction_id", "")))
	var rake_transaction: Dictionary = _append_transaction("async_house_rake", HOUSE_ACCOUNT_ID, "credit", clean_house_rake_cents, -1, {
		"contest_id": clean_contest_id,
		"winner_id": str(normalized_payouts[0].get("player_id", "")),
		"house_account_id": HOUSE_ACCOUNT_ID,
		"approval_id": str(normalized_payouts[0].get("approval_id", "")),
		"approved_by": str(normalized_payouts[0].get("approved_by", "")),
		"idempotency_key": clean_key,
		"memo": "Async money contest house rake"
	})
	transaction_ids.append(str(rake_transaction.get("transaction_id", "")))
	pot["status"] = STATUS_SETTLED
	pot["winner_id"] = str(normalized_payouts[0].get("player_id", ""))
	pot["winner_payout_cents"] = int(normalized_payouts[0].get("amount_cents", 0))
	pot["payout_total_cents"] = payout_total_cents
	pot["payout_count"] = normalized_payouts.size()
	pot["payouts"] = normalized_payouts.duplicate(true)
	pot["house_rake_cents"] = clean_house_rake_cents
	pot["escrow_cents"] = 0
	pot["settle_idempotency_key"] = clean_key
	pot["settle_transaction_ids"] = transaction_ids
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
		"winner_id": str(pot.get("winner_id", "")),
		"winner_payout_cents": int(pot.get("winner_payout_cents", 0)),
		"payout_total_cents": payout_total_cents,
		"payout_count": normalized_payouts.size(),
		"payouts": normalized_payouts.duplicate(true),
		"house_rake_cents": clean_house_rake_cents,
		"pot_cents": int(pot.get("pot_cents", escrow_cents)),
		"transaction_ids": pot.get("settle_transaction_ids", [])
	})

func intent_settle_contest_payout_percentages(contest_id: String, payouts: Array, house_rake_bps: int, idempotency_key: String) -> Dictionary:
	var clean_key: String = idempotency_key.strip_edges()
	if clean_key.is_empty():
		return _error("missing_idempotency_key", "Idempotency key is required.")
	var cached: Dictionary = _cached_operation_result(clean_key)
	if not cached.is_empty():
		return cached
	var report: Dictionary = build_contest_payout_approval_report(contest_id, payouts, house_rake_bps)
	if not bool(report.get("ok", false)):
		return _store_operation_result(clean_key, report)
	return intent_settle_contest_payouts(str(report.get("contest_id", "")), report.get("planned_payouts", []) as Array, int(report.get("house_rake_cents", 0)), clean_key)

func intent_approve_contest_payout_report(report: Dictionary, approver_id: String, idempotency_key: String) -> Dictionary:
	var clean_key: String = idempotency_key.strip_edges()
	if clean_key.is_empty():
		return _error("missing_idempotency_key", "Idempotency key is required.")
	var cached: Dictionary = _cached_operation_result(clean_key)
	if not cached.is_empty():
		return cached
	if report.is_empty() or not bool(report.get("ok", false)):
		return _store_operation_result(clean_key, _error("invalid_approval_report", "A valid payout approval report is required."))
	var clean_approver_id: String = approver_id.strip_edges()
	if clean_approver_id.is_empty():
		return _store_operation_result(clean_key, _error("missing_approver_id", "Approver id is required."))
	var contest_id: String = str(report.get("contest_id", "")).strip_edges()
	var planned_payouts: Array = report.get("planned_payouts", []) as Array
	var approved_payouts: Array[Dictionary] = []
	for payout_any in planned_payouts:
		if typeof(payout_any) != TYPE_DICTIONARY:
			continue
		var payout: Dictionary = (payout_any as Dictionary).duplicate(true)
		payout["approval_id"] = str(report.get("report_id", ""))
		payout["approved_by"] = clean_approver_id
		approved_payouts.append(payout)
	var settle: Dictionary = intent_settle_contest_payouts(contest_id, approved_payouts, int(report.get("house_rake_cents", 0)), clean_key)
	if bool(settle.get("ok", false)):
		var approval_id: String = str(report.get("report_id", ""))
		var approved_report: Dictionary = _approval_reports_by_id.get(approval_id, report.duplicate(true)) as Dictionary
		var now_unix: int = int(Time.get_unix_time_from_system())
		approved_report["approval_status"] = "approved"
		approved_report["approval_id"] = approval_id
		approved_report["approved_by"] = clean_approver_id
		approved_report["approved_unix"] = now_unix
		approved_report["updated_unix"] = now_unix
		approved_report["settlement_transaction_ids"] = settle.get("transaction_ids", [])
		if not approval_id.is_empty():
			_approval_reports_by_id[approval_id] = approved_report.duplicate(true)
		settle["approval_status"] = "approved"
		settle["approval_id"] = approval_id
		settle["approved_by"] = clean_approver_id
		settle["approval_report"] = approved_report.duplicate(true)
	return settle

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

func _normalize_settlement_payouts(payouts: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for i in range(payouts.size()):
		var payout_any: Variant = payouts[i]
		if typeof(payout_any) != TYPE_DICTIONARY:
			continue
		var payout: Dictionary = payout_any as Dictionary
		normalized.append({
			"placement": maxi(1, int(payout.get("placement", i + 1))),
			"player_id": str(payout.get("player_id", "")).strip_edges(),
			"amount_cents": maxi(0, int(payout.get("amount_cents", payout.get("amount", 0)))),
			"payout_bps": clampi(int(payout.get("payout_bps", 0)), 0, BASIS_POINTS_DENOMINATOR),
			"approval_id": str(payout.get("approval_id", "")).strip_edges(),
			"approved_by": str(payout.get("approved_by", "")).strip_edges()
		})
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("placement", 0)) < int(b.get("placement", 0))
	)
	return normalized

func _contest_entry_counts(pot: Dictionary) -> Dictionary:
	var entries_count: int = 0
	var paid_entries_count: int = 0
	var refunded_entries_count: int = 0
	for entry_id_any in pot.get("entry_ids", []) as Array:
		entries_count += 1
		var entry: Dictionary = (_entries_by_id.get(str(entry_id_any), {}) as Dictionary).duplicate(true)
		var status: String = str(entry.get("status", ""))
		if status == STATUS_ESCROWED:
			paid_entries_count += 1
		elif status == STATUS_REFUNDED:
			refunded_entries_count += 1
	return {
		"entries_count": entries_count,
		"paid_entries_count": paid_entries_count,
		"refunded_entries_count": refunded_entries_count
	}

func _approval_report_id(contest_id: String, escrow_cents: int, house_rake_bps: int, planned_payouts: Array[Dictionary]) -> String:
	var payload: String = JSON.stringify({
		"contest_id": contest_id,
		"escrow_cents": escrow_cents,
		"house_rake_bps": house_rake_bps,
		"planned_payouts": planned_payouts
	})
	return "APR-%s-%08x" % [contest_id, abs(hash(payload))]

func _approval_report_matches_filters(report: Dictionary, filters: Dictionary) -> bool:
	for key in ["report_id", "contest_id", "approval_status", "approval_id", "approved_by"]:
		if filters.has(key) and str(report.get(key, "")) != str(filters.get(key, "")):
			return false
	if filters.has("status") and str(report.get("approval_status", "")) != str(filters.get("status", "")):
		return false
	if filters.has("from_unix") and int(report.get("generated_unix", 0)) < int(filters.get("from_unix", 0)):
		return false
	if filters.has("to_unix") and int(report.get("generated_unix", 0)) > int(filters.get("to_unix", 0)):
		return false
	return true

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
