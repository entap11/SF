extends SceneTree

const MoneyGameLedgerScript := preload("res://scripts/state/money_game_ledger.gd")
const HOUSE_ACCOUNT_ID: String = "house"

func _init() -> void:
	var ledger = MoneyGameLedgerScript.new()
	ledger.configure_house_rake_bps(1000)

	_assert_ok(ledger.set_balance_cents("p1", 1000), "seed p1")
	_assert_ok(ledger.set_balance_cents("p2", 1000), "seed p2")
	_assert_ok(ledger.set_balance_cents(HOUSE_ACCOUNT_ID, 0), "seed house")

	var missing_key: Dictionary = ledger.intent_open_escrow("session_missing_key", ["p1", "p2"], 100, "")
	_assert_code(missing_key, "missing_idempotency_key", "mutating actions require idempotency keys")
	_assert_eq(ledger.get_balance_cents("p1"), 1000, "missing key does not debit p1")
	_assert_eq(ledger.get_balance_cents("p2"), 1000, "missing key does not debit p2")

	var open_result: Dictionary = ledger.intent_open_escrow("session_001", ["p1", "p2"], 100, "open:session_001")
	_assert_ok(open_result, "open escrow")
	_assert_eq(int(open_result.get("pot_cents", 0)), 200, "pot should equal both wagers")
	_assert_eq(ledger.get_balance_cents("p1"), 900, "p1 debited into escrow")
	_assert_eq(ledger.get_balance_cents("p2"), 900, "p2 debited into escrow")
	_assert_eq(ledger.get_balance_cents(HOUSE_ACCOUNT_ID), 0, "house not paid before settlement")
	var open_transactions: Array[Dictionary] = ledger.get_transaction_ledger({"session_id": "session_001"})
	_assert_eq(open_transactions.size(), 2, "opening escrow writes one debit per player")
	_assert_eq(str(open_transactions[0].get("transaction_id", "")), "SYNC-000000001", "first transaction id is stable")
	_assert_eq(str(open_transactions[0].get("transaction_type", "")), "escrow_debit", "open transaction is escrow debit")
	_assert_eq(str(open_transactions[0].get("created_utc", "")).is_empty(), false, "open transaction has UTC stamp")
	_assert_eq(int(open_transactions[0].get("amount_cents", 0)), 100, "open transaction amount is wager")

	var duplicate_open: Dictionary = ledger.intent_open_escrow("session_001", ["p1", "p2"], 100, "open:session_001")
	_assert_ok(duplicate_open, "duplicate open returns cached result")
	_assert_eq(ledger.get_balance_cents("p1"), 900, "duplicate open does not debit p1 twice")
	_assert_eq(ledger.get_balance_cents("p2"), 900, "duplicate open does not debit p2 twice")
	_assert_eq(ledger.get_transaction_ledger({"session_id": "session_001"}).size(), 2, "duplicate open does not add transactions")

	var settle_result: Dictionary = ledger.intent_settle_match("session_001", "p1", "settle:session_001:p1")
	_assert_ok(settle_result, "settle p1 win")
	_assert_eq(int(settle_result.get("winner_payout_cents", 0)), 180, "winner receives 90 percent of pot")
	_assert_eq(int(settle_result.get("house_rake_cents", 0)), 20, "house receives 10 percent of pot")
	_assert_eq(ledger.get_balance_cents("p1"), 1080, "p1 receives payout after initial debit")
	_assert_eq(ledger.get_balance_cents("p2"), 900, "p2 receives no payout")
	_assert_eq(ledger.get_balance_cents(HOUSE_ACCOUNT_ID), 20, "house rake credited")
	var payout_transactions: Array[Dictionary] = ledger.get_transaction_ledger({"session_id": "session_001", "transaction_type": "winner_payout"})
	_assert_eq(payout_transactions.size(), 1, "settlement writes winner payout transaction")
	_assert_eq(str(payout_transactions[0].get("account_id", "")), "p1", "winner payout transaction account")
	_assert_eq(int(payout_transactions[0].get("amount_cents", 0)), 180, "winner payout transaction amount")
	_assert_eq(str(payout_transactions[0].get("idempotency_key", "")), "settle:session_001:p1", "winner payout keeps idempotency key")
	var rake_transactions: Array[Dictionary] = ledger.get_transaction_ledger({"account_id": HOUSE_ACCOUNT_ID, "transaction_type": "house_rake"})
	_assert_eq(rake_transactions.size(), 1, "settlement writes house rake transaction")
	_assert_eq(int(rake_transactions[0].get("amount_cents", 0)), 20, "house rake transaction amount")
	var latest_session_transaction: Array[Dictionary] = ledger.get_transaction_ledger({"session_id": "session_001", "sort_desc": true, "limit": 1})
	_assert_eq(latest_session_transaction.size(), 1, "latest transaction filter returns one row")
	_assert_eq(str(latest_session_transaction[0].get("transaction_id", "")), "SYNC-000000004", "latest transaction filter returns newest row")
	var payout_lookup: Dictionary = ledger.get_transaction(str(payout_transactions[0].get("transaction_id", "")))
	_assert_eq(str(payout_lookup.get("transaction_type", "")), "winner_payout", "transaction lookup returns payout")
	var settled_transaction_count: int = ledger.get_transaction_ledger({"session_id": "session_001"}).size()

	var duplicate_settle: Dictionary = ledger.intent_settle_match("session_001", "p1", "settle:session_001:p1")
	_assert_ok(duplicate_settle, "duplicate settlement returns cached result")
	_assert_eq(ledger.get_balance_cents("p1"), 1080, "duplicate settlement does not pay p1 twice")
	_assert_eq(ledger.get_balance_cents(HOUSE_ACCOUNT_ID), 20, "duplicate settlement does not pay house twice")
	_assert_eq(ledger.get_transaction_ledger({"session_id": "session_001"}).size(), settled_transaction_count, "duplicate settlement does not add transactions")

	var second_settle: Dictionary = ledger.intent_settle_match("session_001", "p2", "settle:session_001:p2")
	_assert_code(second_settle, "match_already_closed", "new settlement key after close is rejected")
	_assert_eq(ledger.get_balance_cents("p2"), 900, "rejected second settlement does not pay p2")

	_assert_ok(ledger.set_balance_cents("p3", 500), "seed p3")
	_assert_ok(ledger.set_balance_cents("p4", 500), "seed p4")
	var open_refund: Dictionary = ledger.intent_open_escrow("session_refund", ["p3", "p4"], 250, "open:session_refund")
	_assert_ok(open_refund, "open refundable escrow")
	_assert_eq(ledger.get_balance_cents("p3"), 250, "p3 debited before refund")
	_assert_eq(ledger.get_balance_cents("p4"), 250, "p4 debited before refund")

	var refund_result: Dictionary = ledger.intent_refund_match("session_refund", "failed_start", "refund:session_refund")
	_assert_ok(refund_result, "refund failed start")
	_assert_eq(ledger.get_balance_cents("p3"), 500, "refund restores p3")
	_assert_eq(ledger.get_balance_cents("p4"), 500, "refund restores p4")
	_assert_eq(ledger.get_balance_cents(HOUSE_ACCOUNT_ID), 20, "refund does not affect prior house rake")
	var refund_transactions: Array[Dictionary] = ledger.get_transaction_ledger({"session_id": "session_refund", "transaction_type": "refund_credit"})
	_assert_eq(refund_transactions.size(), 2, "refund writes one credit per player")
	_assert_eq(int(refund_transactions[0].get("amount_cents", 0)), 250, "refund transaction amount")
	var refund_transaction_count: int = ledger.get_transaction_ledger({"session_id": "session_refund"}).size()

	var duplicate_refund: Dictionary = ledger.intent_refund_match("session_refund", "failed_start", "refund:session_refund")
	_assert_ok(duplicate_refund, "duplicate refund returns cached result")
	_assert_eq(ledger.get_balance_cents("p3"), 500, "duplicate refund does not credit p3 twice")
	_assert_eq(ledger.get_balance_cents("p4"), 500, "duplicate refund does not credit p4 twice")
	_assert_eq(ledger.get_transaction_ledger({"session_id": "session_refund"}).size(), refund_transaction_count, "duplicate refund does not add transactions")

	var insufficient: Dictionary = ledger.intent_open_escrow("session_insufficient", ["p3", "p4"], 600, "open:session_insufficient")
	_assert_code(insufficient, "insufficient_funds", "insufficient funds are rejected before debit")
	_assert_eq(ledger.get_balance_cents("p3"), 500, "failed open does not debit p3")
	_assert_eq(ledger.get_balance_cents("p4"), 500, "failed open does not debit p4")

	print("MONEY_GAME_LEDGER_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	_fail("%s failed: %s" % [label, str(result)])

func _assert_code(result: Dictionary, code: String, label: String) -> void:
	if bool(result.get("ok", false)):
		_fail("%s expected code %s but got ok" % [label, code])
		return
	if str(result.get("code", "")) != code:
		_fail("%s expected code %s but got %s" % [label, code, str(result.get("code", ""))])

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %s got %s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	push_error("MONEY_GAME_LEDGER_SMOKE: %s" % message)
	quit(1)
