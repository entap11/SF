extends SceneTree

const ContestStateScript := preload("res://scripts/state/contest_state.gd")
const AsyncMoneyGameLedgerScript := preload("res://scripts/state/async_money_game_ledger.gd")
const SAVE_PATH: String = "user://race_miss_money_closeout_ledger_smoke.json"
const RACE_CONTEST_ID: String = "WEEKLY_USD_100_2026-W26_RACE"
const MISS_CONTEST_ID: String = "EVENT_USD_15_2026-W26_MISS_N_OUT"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var contest_state: Node = ContestStateScript.new()
	contest_state.name = "ContestState"
	get_root().add_child(contest_state)
	await process_frame
	contest_state.call("debug_set_runtime_leaderboard_save_path", SAVE_PATH)
	contest_state.call("debug_reset_runtime_leaderboards")
	contest_state.set("contests", {
		RACE_CONTEST_ID: _race_money_contest(),
		MISS_CONTEST_ID: _miss_n_out_money_contest()
	})
	_run_race_closeout_smoke(contest_state)
	_run_miss_n_out_closeout_smoke(contest_state)
	contest_state.queue_free()
	await process_frame
	print("RACE_MISS_MONEY_CLOSEOUT_LEDGER_SMOKE: PASS")
	quit(0)

func _run_race_closeout_smoke(contest_state: Node) -> void:
	_record_race(contest_state, "race_p1", "Ada", "race_run_p1", [61000, 63000, 64000])
	_record_race(contest_state, "race_p2", "Bo", "race_run_p2", [59000, 60000, 61000])
	_record_race(contest_state, "race_p3", "Cy", "race_run_p3", [62000, 62000, 62000])
	_record_race(contest_state, "race_p4", "Dee", "race_run_p4", [58000, 59000])
	var leaderboard: Array[Dictionary] = contest_state.call("build_timed_race_leaderboard", RACE_CONTEST_ID, 4) as Array[Dictionary]
	_assert_eq(leaderboard.size(), 4, "race leaderboard count")
	_assert_eq(str(leaderboard[0].get("player_id", "")), "race_p2", "race first place")
	_assert_eq(str(leaderboard[1].get("player_id", "")), "race_p3", "race second place")
	var closeout: Dictionary = contest_state.call("build_money_contest_closeout_request", RACE_CONTEST_ID, 3) as Dictionary
	_assert_ok(closeout, "race closeout")
	_assert_eq(str(closeout.get("contest_family", "")), "RACE", "race closeout family")
	var payouts: Array = closeout.get("payouts", []) as Array
	_assert_eq(payouts.size(), 2, "race payout count")
	_assert_eq(str((payouts[0] as Dictionary).get("player_id", "")), "race_p2", "race first payout player")
	_assert_eq(str((payouts[1] as Dictionary).get("player_id", "")), "race_p3", "race second payout player")
	var ledger := AsyncMoneyGameLedgerScript.new()
	for player_id in ["race_p1", "race_p2", "race_p3", "race_p4"]:
		_assert_ok(ledger.intent_open_entry_escrow(
			"entry_%s" % player_id,
			RACE_CONTEST_ID,
			player_id,
			10000,
			"open:%s" % player_id
		), "open race escrow %s" % player_id)
	var report: Dictionary = ledger.preview_contest_payout_approval_report(RACE_CONTEST_ID, payouts, int(closeout.get("house_rake_bps", 1000)))
	_assert_ok(report, "race payout report")
	_assert_eq(int(report.get("total_take_cents", 0)), 40000, "race total take")
	_assert_eq(int(report.get("house_rake_cents", 0)), 4000, "race house rake")
	_assert_eq(int(report.get("player_pool_cents", 0)), 36000, "race player pool")
	var approve: Dictionary = ledger.intent_approve_contest_payout_report(report, "ops_admin", "approve:%s" % RACE_CONTEST_ID)
	_assert_ok(approve, "race payout approval")
	var payout_txs: Array[Dictionary] = ledger.get_transaction_ledger({"contest_id": RACE_CONTEST_ID, "transaction_type": "async_winner_payout"})
	var rake_txs: Array[Dictionary] = ledger.get_transaction_ledger({"contest_id": RACE_CONTEST_ID, "transaction_type": "async_house_rake"})
	_assert_eq(payout_txs.size(), 2, "race transparency payout transaction count")
	_assert_eq(rake_txs.size(), 1, "race transparency rake transaction count")
	_assert_eq(str(payout_txs[0].get("approval_id", "")), str(report.get("report_id", "")), "race payout approval id")

func _run_miss_n_out_closeout_smoke(contest_state: Node) -> void:
	var result: Dictionary = contest_state.call("evaluate_miss_n_out", [
		{"player_id": "miss_p1", "player_name": "Ada", "map_times_ms": [10000, 10000, 10000]},
		{"player_id": "miss_p2", "player_name": "Bo", "map_times_ms": [9000, 9000, 9000]},
		{"player_id": "miss_p3", "player_name": "Cy", "map_times_ms": [12000, 12000, 12000]},
		{"player_id": "miss_p4", "player_name": "Dee", "map_times_ms": [11000, 11000, 11000]}
	], 4, []) as Dictionary
	_assert_ok(result, "evaluate miss n out")
	result["source"] = "smoke"
	_assert_ok(contest_state.call("record_miss_n_out_result", MISS_CONTEST_ID, result) as Dictionary, "record miss n out result")
	var leaderboard: Array[Dictionary] = contest_state.call("build_miss_n_out_leaderboard", MISS_CONTEST_ID, 4) as Array[Dictionary]
	_assert_eq(leaderboard.size(), 4, "miss n out leaderboard count")
	_assert_eq(str(leaderboard[0].get("player_id", "")), "miss_p2", "miss n out winner")
	var closeout: Dictionary = contest_state.call("build_money_contest_closeout_request", MISS_CONTEST_ID, 0) as Dictionary
	_assert_ok(closeout, "miss n out closeout")
	_assert_eq(str(closeout.get("contest_family", "")), "MISS_N_OUT", "miss n out closeout family")
	var payouts: Array = closeout.get("payouts", []) as Array
	_assert_eq(payouts.size(), 1, "miss n out payout count")
	_assert_eq(str((payouts[0] as Dictionary).get("player_id", "")), "miss_p2", "miss n out payout player")
	_assert_eq(int((payouts[0] as Dictionary).get("payout_bps", 0)), 10000, "miss n out default sit-and-go payout bps")
	var ledger := AsyncMoneyGameLedgerScript.new()
	for player_id in ["miss_p1", "miss_p2", "miss_p3", "miss_p4"]:
		_assert_ok(ledger.intent_open_entry_escrow(
			"entry_%s" % player_id,
			MISS_CONTEST_ID,
			player_id,
			1500,
			"open:%s" % player_id
		), "open miss n out escrow %s" % player_id)
	var report: Dictionary = ledger.preview_contest_payout_approval_report(MISS_CONTEST_ID, payouts, int(closeout.get("house_rake_bps", 1000)))
	_assert_ok(report, "miss n out payout report")
	_assert_eq(int(report.get("total_take_cents", 0)), 6000, "miss n out total take")
	_assert_eq(int(report.get("house_rake_cents", 0)), 600, "miss n out house rake")
	_assert_eq(int(report.get("player_pool_cents", 0)), 5400, "miss n out player pool")
	var approve: Dictionary = ledger.intent_approve_contest_payout_report(report, "ops_admin", "approve:%s" % MISS_CONTEST_ID)
	_assert_ok(approve, "miss n out payout approval")
	var payout_txs: Array[Dictionary] = ledger.get_transaction_ledger({"contest_id": MISS_CONTEST_ID, "transaction_type": "async_winner_payout"})
	var rake_txs: Array[Dictionary] = ledger.get_transaction_ledger({"contest_id": MISS_CONTEST_ID, "transaction_type": "async_house_rake"})
	_assert_eq(payout_txs.size(), 1, "miss n out transparency payout transaction count")
	_assert_eq(rake_txs.size(), 1, "miss n out transparency rake transaction count")
	_assert_eq(str(payout_txs[0].get("approval_id", "")), str(report.get("report_id", "")), "miss n out payout approval id")

func _race_money_contest() -> ContestDef:
	var contest: ContestDef = ContestDef.new()
	contest.id = RACE_CONTEST_ID
	contest.scope = "WEEKLY"
	contest.currency = "USD"
	contest.price = 100
	contest.pool_type = "MONEY"
	contest.contest_family = "RACE"
	contest.schedule_kind = "SCHEDULED"
	contest.published = true
	contest.status = "OPEN"
	contest.set_cash_payout_schedule([
		{"placement": 1, "payout_bps": 6000},
		{"placement": 2, "payout_bps": 4000}
	])
	contest.normalize_definition()
	return contest

func _miss_n_out_money_contest() -> ContestDef:
	var contest: ContestDef = ContestDef.new()
	contest.id = MISS_CONTEST_ID
	contest.scope = "EVENT"
	contest.currency = "USD"
	contest.price = 15
	contest.pool_type = "MONEY"
	contest.contest_family = "MISS_N_OUT"
	contest.schedule_kind = "SIT_AND_GO"
	contest.published = true
	contest.status = "OPEN"
	contest.normalize_definition()
	return contest

func _record_race(contest_state: Node, player_id: String, player_name: String, run_id: String, times: Array[int]) -> void:
	var result: Dictionary = contest_state.call("record_timed_race_result", RACE_CONTEST_ID, {
		"player_id": player_id,
		"player_name": player_name,
		"run_id": run_id,
		"map_count": 3,
		"completed_maps": times.size(),
		"map_times_ms": times,
		"status": "complete" if times.size() >= 3 else "incomplete",
		"source": "smoke"
	}) as Dictionary
	_assert_ok(result, "record race %s" % player_id)

func _assert_ok(result: Dictionary, label: String) -> void:
	if not bool(result.get("ok", false)):
		_fail("%s failed: %s" % [label, JSON.stringify(result)])

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s got %s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	push_error("RACE_MISS_MONEY_CLOSEOUT_LEDGER_SMOKE: %s" % message)
	quit(1)
