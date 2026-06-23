extends SceneTree

const AsyncMoneyGameLedgerScript := preload("res://scripts/state/async_money_game_ledger.gd")

var _failed: bool = false

func _init() -> void:
	var ledger = AsyncMoneyGameLedgerScript.new()
	ledger.configure_house_rake_bps(1000)

	var missing_key: Dictionary = ledger.intent_open_entry_escrow("entry_missing_key", "contest_1", "p1", 500, "")
	_assert_code(missing_key, "missing_idempotency_key", "mutating actions require idempotency keys")

	var open_p1: Dictionary = ledger.intent_open_entry_escrow("entry_1", "contest_1", "p1", 500, "open:entry_1")
	_assert_ok(open_p1, "open p1 async escrow")
	_assert_eq(int(open_p1.get("pot_cents", 0)), 500, "first entry builds contest pot")
	var p1_transactions: Array[Dictionary] = ledger.get_transaction_ledger({"entry_id": "entry_1"})
	_assert_eq(p1_transactions.size(), 1, "async open writes entry debit")
	_assert_eq(str(p1_transactions[0].get("transaction_id", "")), "ASYNC-000000001", "first async transaction id is stable")
	_assert_eq(str(p1_transactions[0].get("transaction_type", "")), "async_entry_escrow_debit", "async open transaction type")
	_assert_eq(str(p1_transactions[0].get("created_utc", "")).is_empty(), false, "async open transaction has UTC stamp")

	var duplicate_open: Dictionary = ledger.intent_open_entry_escrow("entry_1", "contest_1", "p1", 500, "open:entry_1")
	_assert_ok(duplicate_open, "duplicate open returns cached result")
	_assert_eq(int(duplicate_open.get("pot_cents", 0)), 500, "duplicate open does not grow pot")
	_assert_eq(ledger.get_transaction_ledger({"entry_id": "entry_1"}).size(), 1, "duplicate async open does not add transactions")

	var open_p2: Dictionary = ledger.intent_open_entry_escrow("entry_2", "contest_1", "p2", 500, "open:entry_2")
	_assert_ok(open_p2, "open p2 async escrow")
	_assert_eq(int(open_p2.get("pot_cents", 0)), 1000, "second entry grows contest pot")

	var contest_snapshot: Dictionary = ledger.get_contest_snapshot("contest_1")
	_assert_eq(str(contest_snapshot.get("status", "")), "escrowed", "contest pot is escrowed")
	_assert_eq(int(contest_snapshot.get("escrow_cents", 0)), 1000, "contest escrow tracks both entries")

	var settle: Dictionary = ledger.intent_settle_contest("contest_1", "p2", "settle:contest_1:p2")
	_assert_ok(settle, "settle async contest")
	_assert_eq(int(settle.get("winner_payout_cents", 0)), 900, "winner receives 90 percent")
	_assert_eq(int(settle.get("house_rake_cents", 0)), 100, "house receives 10 percent")
	var payout_transactions: Array[Dictionary] = ledger.get_transaction_ledger({"contest_id": "contest_1", "transaction_type": "async_winner_payout"})
	_assert_eq(payout_transactions.size(), 1, "async settlement writes winner payout transaction")
	_assert_eq(str(payout_transactions[0].get("account_id", "")), "p2", "async payout account")
	_assert_eq(int(payout_transactions[0].get("amount_cents", 0)), 900, "async payout amount")
	_assert_eq(str(payout_transactions[0].get("idempotency_key", "")), "settle:contest_1:p2", "async payout keeps idempotency key")
	var rake_transactions: Array[Dictionary] = ledger.get_transaction_ledger({"contest_id": "contest_1", "transaction_type": "async_house_rake"})
	_assert_eq(rake_transactions.size(), 1, "async settlement writes house rake transaction")
	_assert_eq(int(rake_transactions[0].get("amount_cents", 0)), 100, "async house rake amount")
	var latest_contest_transaction: Array[Dictionary] = ledger.get_transaction_ledger({"contest_id": "contest_1", "sort_desc": true, "limit": 1})
	_assert_eq(latest_contest_transaction.size(), 1, "latest async transaction filter returns one row")
	_assert_eq(str(latest_contest_transaction[0].get("transaction_id", "")), "ASYNC-000000004", "latest async transaction filter returns newest row")
	var async_settled_transaction_count: int = ledger.get_transaction_ledger({"contest_id": "contest_1"}).size()

	var duplicate_settle: Dictionary = ledger.intent_settle_contest("contest_1", "p2", "settle:contest_1:p2")
	_assert_ok(duplicate_settle, "duplicate settle returns cached result")
	_assert_eq(ledger.get_transaction_ledger({"contest_id": "contest_1"}).size(), async_settled_transaction_count, "duplicate async settle does not add transactions")

	_assert_ok(ledger.intent_open_entry_escrow("unbalanced_entry_1", "contest_unbalanced", "unbalanced_p1", 500, "open:unbalanced_entry_1"), "open first unbalanced contest entry")
	_assert_ok(ledger.intent_open_entry_escrow("unbalanced_entry_2", "contest_unbalanced", "unbalanced_p2", 500, "open:unbalanced_entry_2"), "open second unbalanced contest entry")
	var unbalanced_settle: Dictionary = ledger.intent_settle_contest_payouts("contest_unbalanced", [
		{"placement": 1, "player_id": "unbalanced_p1", "amount_cents": 500}
	], 100, "settle:contest_unbalanced:bad")
	_assert_code(unbalanced_settle, "settlement_not_balanced", "payouts plus rake must equal escrow")
	var unbalanced_percent_settle: Dictionary = ledger.intent_settle_contest_payout_percentages("contest_unbalanced", [
		{"placement": 1, "player_id": "unbalanced_p1", "payout_bps": 5000}
	], 1000, "settle:contest_unbalanced:bad_percent")
	_assert_code(unbalanced_percent_settle, "settlement_percentages_not_balanced", "payout percentages plus rake must equal 100 percent")

	for i in range(100):
		var player_id: String = "pool_p%d" % (i + 1)
		var entry_id: String = "pool_entry_%d" % (i + 1)
		var open_pool: Dictionary = ledger.intent_open_entry_escrow(entry_id, "contest_pool_100", player_id, 500, "open:%s" % entry_id)
		_assert_ok(open_pool, "open 100-player payout pool entry")
	var scheduled_payouts: Array[Dictionary] = [
		{"placement": 1, "player_id": "pool_p1", "payout_bps": 4000},
		{"placement": 2, "player_id": "pool_p2", "payout_bps": 2000},
		{"placement": 3, "player_id": "pool_p3", "payout_bps": 1500},
		{"placement": 4, "player_id": "pool_p4", "payout_bps": 1000},
		{"placement": 5, "player_id": "pool_p5", "payout_bps": 500}
	]
	var approval_report: Dictionary = ledger.preview_contest_payout_approval_report("contest_pool_100", scheduled_payouts, 1000)
	_assert_ok(approval_report, "build 100-player payout approval report")
	_assert_eq(str(approval_report.get("approval_status", "")), "pending_approval", "approval report should be pending")
	_assert_eq(int(approval_report.get("players_count", 0)), 100, "approval report counts unique players")
	_assert_eq(int(approval_report.get("entries_count", 0)), 100, "approval report counts entries")
	_assert_eq(int(approval_report.get("total_take_cents", 0)), 50000, "approval report total take")
	_assert_eq(int(approval_report.get("house_rake_cents", 0)), 5000, "approval report house rake")
	_assert_eq(int(approval_report.get("player_pool_cents", 0)), 45000, "approval report player pool")
	var pending_reports: Array[Dictionary] = ledger.get_payout_approval_reports({"status": "pending_approval", "contest_id": "contest_pool_100"})
	_assert_eq(pending_reports.size(), 1, "preview queues pending approval report")
	_assert_eq(str(pending_reports[0].get("report_id", "")), str(approval_report.get("report_id", "")), "queued approval report id")
	var pool_settle: Dictionary = ledger.intent_approve_contest_payout_report(approval_report, "ops_admin", "settle:contest_pool_100:top5")
	_assert_ok(pool_settle, "settle 100-player top-five payout schedule")
	_assert_eq(str(pool_settle.get("approval_status", "")), "approved", "approval should be recorded on settlement result")
	_assert_eq(int(pool_settle.get("pot_cents", 0)), 50000, "100-player pot is 500 dollars")
	_assert_eq(int(pool_settle.get("house_rake_cents", 0)), 5000, "house receives 10 percent of 100-player pool")
	_assert_eq(int(pool_settle.get("payout_total_cents", 0)), 45000, "top-five payouts split distributable pool")
	_assert_eq(int(pool_settle.get("payout_count", 0)), 5, "settlement records five paid winners")
	var pool_payout_transactions: Array[Dictionary] = ledger.get_transaction_ledger({"contest_id": "contest_pool_100", "transaction_type": "async_winner_payout"})
	_assert_eq(pool_payout_transactions.size(), 5, "multi-winner settlement writes one payout row per winner")
	_assert_eq(int(pool_payout_transactions[0].get("placement", 0)), 1, "first payout ledger row keeps placement")
	_assert_eq(int(pool_payout_transactions[0].get("payout_bps", 0)), 4000, "first payout ledger row keeps percentage")
	_assert_eq(str(pool_payout_transactions[0].get("approval_id", "")), str(approval_report.get("report_id", "")), "payout row keeps approval id")
	var pool_rake_transactions: Array[Dictionary] = ledger.get_transaction_ledger({"contest_id": "contest_pool_100", "transaction_type": "async_house_rake"})
	_assert_eq(pool_rake_transactions.size(), 1, "multi-winner settlement writes one house rake row")
	_assert_eq(str(pool_rake_transactions[0].get("approved_by", "")), "ops_admin", "rake row keeps approver")
	_assert_eq(ledger.get_payout_approval_reports({"status": "pending_approval", "contest_id": "contest_pool_100"}).size(), 0, "approved report leaves pending queue")
	_assert_eq(ledger.get_payout_approval_reports({"status": "approved", "contest_id": "contest_pool_100"}).size(), 1, "approved report remains auditable")

	var refund_after_settle: Dictionary = ledger.intent_refund_entry("entry_1", "late_refund", "refund:entry_1")
	_assert_code(refund_after_settle, "entry_already_closed", "settled entry cannot refund")

	var open_refund: Dictionary = ledger.intent_open_entry_escrow("entry_refund", "contest_refund", "p3", 250, "open:entry_refund")
	_assert_ok(open_refund, "open refundable entry")
	var refund: Dictionary = ledger.intent_refund_entry("entry_refund", "failed_start", "refund:entry_refund")
	_assert_ok(refund, "refund async entry")
	_assert_eq(int(refund.get("refunded_cents", 0)), 250, "refund returns entry escrow")
	var refund_transactions: Array[Dictionary] = ledger.get_transaction_ledger({"entry_id": "entry_refund", "transaction_type": "async_entry_refund_credit"})
	_assert_eq(refund_transactions.size(), 1, "async refund writes credit transaction")
	_assert_eq(int(refund_transactions[0].get("amount_cents", 0)), 250, "async refund transaction amount")
	var async_refund_transaction_count: int = ledger.get_transaction_ledger({"entry_id": "entry_refund"}).size()
	var duplicate_refund: Dictionary = ledger.intent_refund_entry("entry_refund", "failed_start", "refund:entry_refund")
	_assert_ok(duplicate_refund, "duplicate refund returns cached result")
	_assert_eq(ledger.get_transaction_ledger({"entry_id": "entry_refund"}).size(), async_refund_transaction_count, "duplicate async refund does not add transactions")

	if _failed:
		return
	print("ASYNC_MONEY_GAME_LEDGER_SMOKE: PASS")
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
	_failed = true
	push_error("ASYNC_MONEY_GAME_LEDGER_SMOKE: %s" % message)
	quit(1)
