extends SceneTree

const ContestStateScript := preload("res://scripts/state/contest_state.gd")
const AsyncMoneyGameLedgerScript := preload("res://scripts/state/async_money_game_ledger.gd")
const SAVE_PATH: String = "user://gauntlet_money_closeout_ledger_smoke.json"
const CONTEST_ID: String = "WEEKLY_USD_15_2026-W26_GAUNTLET"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var contest_state: Node = ContestStateScript.new()
	contest_state.name = "ContestState"
	get_root().add_child(contest_state)
	await process_frame
	contest_state.call("debug_set_runtime_leaderboard_save_path", SAVE_PATH)
	contest_state.call("debug_reset_runtime_leaderboards")
	var contest: ContestDef = _gauntlet_money_contest()
	contest_state.set("contests", {CONTEST_ID: contest})
	_record_gauntlet(contest_state, "p1", "Ada", "run_p1", 18, 6, 360000)
	_record_gauntlet(contest_state, "p2", "Bo", "run_p2", 21, 7, 390000)
	_record_gauntlet(contest_state, "p3", "Cy", "run_p3", 21, 6, 350000)
	var leaderboard: Array[Dictionary] = contest_state.call("build_gauntlet_leaderboard", CONTEST_ID, 3) as Array[Dictionary]
	if leaderboard.size() != 3:
		_fail("expected 3 gauntlet leaderboard rows")
		return
	_assert_eq(str(leaderboard[0].get("player_id", "")), "p2", "stars then completed stages should rank p2 first")
	_assert_eq(str(leaderboard[1].get("player_id", "")), "p3", "p3 should rank second")
	var closeout: Dictionary = contest_state.call("build_money_contest_closeout_request", CONTEST_ID, 0) as Dictionary
	_assert_ok(closeout, "gauntlet closeout")
	_assert_eq(str(closeout.get("contest_family", "")), "GAUNTLET", "closeout family")
	var payouts: Array = closeout.get("payouts", []) as Array
	if payouts.size() != 2:
		_fail("expected two payout rows")
		return
	_assert_eq(str((payouts[0] as Dictionary).get("player_id", "")), "p2", "first payout player")
	_assert_eq(str((payouts[1] as Dictionary).get("player_id", "")), "p3", "second payout player")
	var ledger := AsyncMoneyGameLedgerScript.new()
	for player_id in ["p1", "p2", "p3"]:
		_assert_ok(ledger.intent_open_entry_escrow(
			"entry_%s" % player_id,
			CONTEST_ID,
			player_id,
			1500,
			"open:%s" % player_id
		), "open escrow %s" % player_id)
	var report: Dictionary = ledger.preview_contest_payout_approval_report(CONTEST_ID, payouts, int(closeout.get("house_rake_bps", 1000)))
	_assert_ok(report, "preview payout report")
	_assert_eq(int(report.get("total_take_cents", 0)), 4500, "total take")
	_assert_eq(int(report.get("house_rake_cents", 0)), 450, "house rake")
	_assert_eq(int(report.get("player_pool_cents", 0)), 4050, "player pool")
	var approve: Dictionary = ledger.intent_approve_contest_payout_report(report, "ops_admin", "approve:%s" % CONTEST_ID)
	_assert_ok(approve, "approve payout report")
	var payout_txs: Array[Dictionary] = ledger.get_transaction_ledger({"contest_id": CONTEST_ID, "transaction_type": "async_winner_payout"})
	var rake_txs: Array[Dictionary] = ledger.get_transaction_ledger({"contest_id": CONTEST_ID, "transaction_type": "async_house_rake"})
	_assert_eq(payout_txs.size(), 2, "transparency ledger payout transaction count")
	_assert_eq(rake_txs.size(), 1, "transparency ledger rake transaction count")
	_assert_eq(str(payout_txs[0].get("approval_id", "")), str(report.get("report_id", "")), "payout transaction approval id")
	contest_state.queue_free()
	await process_frame
	print("GAUNTLET_MONEY_CLOSEOUT_LEDGER_SMOKE: PASS")
	quit(0)

func _gauntlet_money_contest() -> ContestDef:
	var contest: ContestDef = ContestDef.new()
	contest.id = CONTEST_ID
	contest.scope = "WEEKLY"
	contest.currency = "USD"
	contest.price = 15
	contest.pool_type = "MONEY"
	contest.contest_family = "GAUNTLET"
	contest.schedule_kind = "SCHEDULED"
	contest.published = true
	contest.status = "OPEN"
	contest.set_cash_payout_schedule([
		{"placement": 1, "payout_bps": 7000},
		{"placement": 2, "payout_bps": 3000}
	])
	contest.normalize_definition()
	return contest

func _record_gauntlet(contest_state: Node, player_id: String, player_name: String, run_id: String, stars: int, completed: int, elapsed_ms: int) -> void:
	var result: Dictionary = contest_state.call("record_gauntlet_run_result", CONTEST_ID, {
		"player_id": player_id,
		"player_name": player_name,
		"run_id": run_id,
		"total_stars": stars,
		"max_stars": 72,
		"completed_stages": completed,
		"stage_count": 24,
		"elapsed_ms": elapsed_ms,
		"status": "complete",
		"source": "smoke"
	}) as Dictionary
	_assert_ok(result, "record gauntlet %s" % player_id)

func _assert_ok(result: Dictionary, label: String) -> void:
	if not bool(result.get("ok", false)):
		_fail("%s failed: %s" % [label, JSON.stringify(result)])

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s got %s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	push_error("GAUNTLET_MONEY_CLOSEOUT_LEDGER_SMOKE: %s" % message)
	quit(1)
