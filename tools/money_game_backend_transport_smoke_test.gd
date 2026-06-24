extends SceneTree

const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const DEFAULT_BACKEND_URL: String = "http://127.0.0.1:8791/v1"

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var backend_url: String = OS.get_environment("SF_VS_BACKEND_URL").strip_edges()
	if backend_url.is_empty():
		backend_url = DEFAULT_BACKEND_URL
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, backend_url)
	var handshake: Node = get_root().get_node_or_null("/root/VsHandshake")
	if handshake == null:
		_fail("VsHandshake autoload missing")
		return
	if handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	if handshake.has_method("clear"):
		handshake.call("clear")
	_assert_eq(str(handshake.call("get_transport_mode")), "http", "backend smoke requires HTTP transport")
	var probe: Dictionary = handshake.call("list_async_contest_results", {"contest_id": "__backend_transport_probe__"}) as Dictionary
	if _is_transport_unavailable(probe):
		print("MONEY_GAME_BACKEND_TRANSPORT_SMOKE: SKIP backend unavailable %s" % str(probe))
		quit(0)
		return
	_assert_ok(probe, "backend result endpoint probe")
	if _failed:
		return

	await _test_async_entry_uses_backend_ledger(handshake)
	if _failed:
		return
	_test_async_result_ledger_closeout(handshake)
	if _failed:
		return
	_test_scheduled_money_closeout_lifecycle(handshake)
	if _failed:
		return
	_test_scheduled_gauntlet_money_closeout_lifecycle(handshake)
	if _failed:
		return
	_test_scheduled_money_closeout_soak(handshake)
	if _failed:
		return
	_test_paid_vs_settles_on_backend(handshake)
	if _failed:
		return

	print("MONEY_GAME_BACKEND_TRANSPORT_SMOKE: PASS")
	quit(0)

func _test_async_entry_uses_backend_ledger(handshake: Node) -> void:
	var stamp: int = Time.get_ticks_msec()
	var scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		_fail("failed to load MainMenu.tscn")
		return
	var menu: Node = scene.instantiate()
	menu.set("_dev_bypass_cash_balance", false)
	menu.set("_wallet_profile", {"balance_usd": 10})
	get_root().add_child(menu)
	await process_frame
	await process_frame
	var map_ids: PackedStringArray = PackedStringArray(["MAP_nomansland__545__v01_top2_sides__1p"])
	menu.call("_open_async_vs_lobby", "STAGE_RACE", 1, false, 5, {
		"contest_id": "BACKEND_SMOKE_ASYNC_%d" % stamp,
		"contest_scope": "WEEKLY",
		"map_ids": map_ids
	})
	await process_frame
	await process_frame
	_assert_eq(int((menu.get("_wallet_profile") as Dictionary).get("balance_usd", -1)), 5, "backend async entry debits preview wallet")
	var local_snapshot: Dictionary = menu.call("debug_get_async_money_ledger_snapshot") as Dictionary
	var local_entries: Dictionary = local_snapshot.get("entries", {}) as Dictionary
	_assert_eq(local_entries.size(), 0, "backend async escrow should not write local async ledger")
	var lobby: Node = menu.get("_vs_lobby") as Node
	if lobby == null:
		_fail("VS lobby did not open after backend async escrow")
		return
	var context: Dictionary = lobby.call("_handshake_context") as Dictionary
	_assert_eq(str(context.get("async_money_ledger_source", "")), "backend", "async lobby context uses backend ledger")
	_assert_eq(str(context.get("async_money_ledger_status", "")), "escrowed", "async lobby context carries backend escrow status")
	_assert_eq(int(context.get("async_money_pot_cents", 0)), 500, "backend async pot contains wager")
	var entry_id: String = str(context.get("async_money_entry_id", "")).strip_edges()
	if entry_id.is_empty():
		_fail("backend async escrow did not return entry id")
		return
	var refund: Dictionary = handshake.call("refund_async_entry", entry_id, "backend_smoke_cleanup", "refund:%s:backend_smoke_cleanup" % entry_id) as Dictionary
	_assert_ok(refund, "refund backend async entry")
	menu.queue_free()

func _test_paid_vs_settles_on_backend(handshake: Node) -> void:
	var stamp: int = Time.get_ticks_msec()
	var host_uid: String = "backend_paid_host_%d" % stamp
	var guest_uid: String = "backend_paid_guest_%d" % stamp
	var invite: Dictionary = handshake.call(
		"create_invite",
		{"uid": host_uid, "display_name": "Backend Paid Host", "balance_cents": 1000},
		{"mode": "PVP_BACKEND_SMOKE", "map_count": 1, "price_usd": 1, "wager_cents": 100, "free_roll": false, "paid_entry": true}
	) as Dictionary
	_assert_ok(invite, "create backend paid invite")
	var join_result: Dictionary = handshake.call(
		"join_invite",
		str(invite.get("invite_code", "")),
		{"uid": guest_uid, "display_name": "Backend Paid Guest", "balance_cents": 1000}
	) as Dictionary
	_assert_ok(join_result, "join backend paid invite")
	var session: Dictionary = join_result.get("session", {}) as Dictionary
	var context: Dictionary = session.get("context", {}) as Dictionary
	var session_id: String = str(join_result.get("session_id", ""))
	_assert_eq(str(session.get("status", "")), "started", "backend paid session starts after escrow")
	_assert_eq(str(context.get("ledger_status", "")), "escrowed", "backend paid session context is escrowed")
	_assert_eq(int(context.get("pot_cents", 0)), 200, "backend paid session pot contains both wagers")
	var settle_result: Dictionary = handshake.call("settle_money_match", session_id, 1, "backend_smoke_host_win") as Dictionary
	_assert_ok(settle_result, "settle backend paid VS")
	_assert_eq(str(settle_result.get("type", "")), "match_settled", "backend paid settlement type")
	_assert_eq(str(settle_result.get("winner_uid", "")), host_uid, "backend paid settlement maps owner 1 to host uid")
	_assert_eq(int(settle_result.get("winner_payout_cents", 0)), 180, "backend paid settlement pays winner")
	_assert_eq(int(settle_result.get("house_rake_cents", 0)), 20, "backend paid settlement pays house rake")
	var settled_session: Dictionary = handshake.call("get_session", session_id) as Dictionary
	var settled_context: Dictionary = settled_session.get("context", {}) as Dictionary
	_assert_eq(str(settled_context.get("ledger_status", "")), "settled", "backend session context marks ledger settled")

func _test_async_result_ledger_closeout(handshake: Node) -> void:
	var stamp: int = Time.get_ticks_msec()
	var race_contest_id: String = "BACKEND_SMOKE_RACE_%d" % stamp
	var race_players: Array[String] = ["race_backend_p1_%d" % stamp, "race_backend_p2_%d" % stamp, "race_backend_p3_%d" % stamp]
	for i in range(race_players.size()):
		var player_id: String = race_players[i]
		var open_result: Dictionary = handshake.call(
			"open_async_entry_escrow",
			"entry:%s:%s" % [race_contest_id, player_id],
			race_contest_id,
			player_id,
			500,
			"open:%s:%s" % [race_contest_id, player_id],
			5000
		) as Dictionary
		_assert_ok(open_result, "open race backend result escrow %d" % i)
	var race_rows: Array[Dictionary] = [
		{"player_id": race_players[0], "map_times_ms": [64000, 61000, 63000], "completed_maps": 3, "required_maps": 3},
		{"player_id": race_players[1], "map_times_ms": [59000, 60000, 60500], "completed_maps": 3, "required_maps": 3},
		{"player_id": race_players[2], "map_times_ms": [70000, 68000, 67000], "completed_maps": 3, "required_maps": 3}
	]
	for row in race_rows:
		var submit_result: Dictionary = handshake.call(
			"submit_async_contest_result",
			race_contest_id,
			"RACE",
			str(row.get("player_id", "")),
			row,
			"submit:%s:%s" % [race_contest_id, str(row.get("player_id", ""))]
		) as Dictionary
		_assert_ok(submit_result, "submit race backend result")
	var listed: Dictionary = handshake.call("list_async_contest_results", {"contest_id": race_contest_id, "contest_family": "RACE"}) as Dictionary
	_assert_ok(listed, "list race backend results")
	var listed_results: Array = listed.get("results", []) as Array
	if listed_results.size() < 3:
		_fail("race backend result count expected 3 got %d" % listed_results.size())
		return
	_assert_eq(listed_results.size(), 3, "race backend result count")
	_assert_eq(str((listed_results[0] as Dictionary).get("player_id", "")), race_players[1], "race backend results rank fastest first")
	var race_report: Dictionary = handshake.call(
		"preview_async_contest_result_payout_report",
		race_contest_id,
		"RACE",
		[
			{"placement": 1, "payout_bps": 7000},
			{"placement": 2, "payout_bps": 3000}
		],
		1000,
		{"map_count": 3, "required_maps": 3}
	) as Dictionary
	_assert_ok(race_report, "preview race backend result payout report")
	var race_payouts: Array = race_report.get("planned_payouts", []) as Array
	if race_payouts.is_empty():
		_fail("race report planned payouts missing")
		return
	_assert_eq(str(race_report.get("result_source", "")), "backend_result_ledger", "race report source")
	_assert_eq(str((race_payouts[0] as Dictionary).get("player_id", "")), race_players[1], "race report pays fastest player first")

	var miss_contest_id: String = "BACKEND_SMOKE_MISS_%d" % stamp
	var miss_players: Array[String] = ["miss_backend_p1_%d" % stamp, "miss_backend_p2_%d" % stamp, "miss_backend_p3_%d" % stamp]
	for i in range(miss_players.size()):
		var player_id: String = miss_players[i]
		var open_result: Dictionary = handshake.call(
			"open_async_entry_escrow",
			"entry:%s:%s" % [miss_contest_id, player_id],
			miss_contest_id,
			player_id,
			500,
			"open:%s:%s" % [miss_contest_id, player_id],
			5000
		) as Dictionary
		_assert_ok(open_result, "open miss backend result escrow %d" % i)
	var miss_rows: Array[Dictionary] = [
		{"player_id": miss_players[0], "placement": 2, "eliminated_round": 4, "time_ms": 130000},
		{"player_id": miss_players[1], "placement": 1, "eliminated_round": 5, "time_ms": 145000},
		{"player_id": miss_players[2], "placement": 3, "eliminated_round": 3, "time_ms": 99000}
	]
	for row in miss_rows:
		var submit_result: Dictionary = handshake.call(
			"submit_async_contest_result",
			miss_contest_id,
			"MISS_N_OUT",
			str(row.get("player_id", "")),
			row,
			"submit:%s:%s" % [miss_contest_id, str(row.get("player_id", ""))]
		) as Dictionary
		_assert_ok(submit_result, "submit miss backend result")
	var miss_report: Dictionary = handshake.call(
		"preview_async_contest_result_payout_report",
		miss_contest_id,
		"MISS_N_OUT",
		[{"placement": 1, "payout_bps": 10000}],
		1000,
		{}
	) as Dictionary
	_assert_ok(miss_report, "preview miss backend result payout report")
	var miss_payouts: Array = miss_report.get("planned_payouts", []) as Array
	if miss_payouts.is_empty():
		_fail("miss report planned payouts missing")
		return
	_assert_eq(str(miss_report.get("result_source", "")), "backend_result_ledger", "miss report source")
	_assert_eq(str((miss_payouts[0] as Dictionary).get("player_id", "")), miss_players[1], "miss report pays first place")

func _test_scheduled_money_closeout_lifecycle(handshake: Node) -> void:
	var contest_state: Node = get_root().get_node_or_null("/root/ContestState")
	if contest_state == null:
		_fail("ContestState autoload missing")
		return
	var stamp: int = Time.get_ticks_msec()
	var contest_id: String = "WEEKLY_USD_100_2026-W26_RACE_CLOSE_%d" % stamp
	var contest: ContestDef = ContestDef.new()
	contest.id = contest_id
	contest.scope = "WEEKLY"
	contest.currency = "USD"
	contest.price = 100
	contest.pool_type = "MONEY"
	contest.contest_family = "RACE"
	contest.schedule_kind = "SCHEDULED"
	contest.status = "OPEN"
	contest.published = true
	contest.start_ts = 1
	contest.end_ts = 2
	contest.map_ids = PackedStringArray(["MAP_nomansland__545__v01_top2_sides__1p", "MAP_nomansland__545__v17_four_corners_only__1p", "MAP_nomansland__444__v01_pinched_spine__1p"])
	contest.set_cash_payout_schedule([
		{"placement": 1, "payout_bps": 7000},
		{"placement": 2, "payout_bps": 3000}
	])
	contest.normalize_definition()
	var cancelled_contest_id: String = "WEEKLY_USD_100_2026-W26_RACE_CANCEL_%d" % stamp
	var cancelled_contest: ContestDef = ContestDef.new()
	cancelled_contest.id = cancelled_contest_id
	cancelled_contest.scope = "WEEKLY"
	cancelled_contest.currency = "USD"
	cancelled_contest.price = 100
	cancelled_contest.pool_type = "MONEY"
	cancelled_contest.contest_family = "RACE"
	cancelled_contest.schedule_kind = "SCHEDULED"
	cancelled_contest.status = "VOID"
	cancelled_contest.published = true
	cancelled_contest.start_ts = 1
	cancelled_contest.end_ts = 2
	cancelled_contest.set_cash_payout_schedule([{"placement": 1, "payout_bps": 10000}])
	cancelled_contest.normalize_definition()
	var contests: Dictionary = contest_state.get("contests") as Dictionary
	contests[contest_id] = contest
	contests[cancelled_contest_id] = cancelled_contest
	contest_state.set("contests", contests)
	var players: Array[String] = ["close_p1_%d" % stamp, "close_p2_%d" % stamp, "close_p3_%d" % stamp]
	for i in range(players.size()):
		var player_id: String = players[i]
		var open_result: Dictionary = handshake.call(
			"open_async_entry_escrow",
			"entry:%s:%s" % [contest_id, player_id],
			contest_id,
			player_id,
			10000,
			"open:%s:%s" % [contest_id, player_id],
			50000
		) as Dictionary
		_assert_ok(open_result, "open scheduled closeout escrow %d" % i)
	var rows: Array[Dictionary] = [
		{"player_id": players[0], "map_times_ms": [65000, 64000, 63000], "completed_maps": 3, "required_maps": 3},
		{"player_id": players[1], "map_times_ms": [58000, 59000, 60000], "completed_maps": 3, "required_maps": 3},
		{"player_id": players[2], "map_times_ms": [68000, 66000, 65000], "completed_maps": 3, "required_maps": 3}
	]
	for row in rows:
		var submit_result: Dictionary = handshake.call(
			"submit_async_contest_result",
			contest_id,
			"RACE",
			str(row.get("player_id", "")),
			row,
			"submit:%s:%s" % [contest_id, str(row.get("player_id", ""))]
		) as Dictionary
		_assert_ok(submit_result, "submit scheduled closeout race result")
	var sweep: Dictionary = contest_state.call("process_scheduled_money_contest_closeouts", 3) as Dictionary
	_assert_ok(sweep, "scheduled closeout sweep")
	_assert_eq(int(sweep.get("checked_count", 0)), 1, "scheduled closeout checked contest count")
	_assert_eq(int(sweep.get("queued_count", 0)), 1, "scheduled closeout queues report")
	_assert_eq(str(contest.status), "PAYOUT_PENDING", "scheduled closeout marks contest payout pending")
	var queued_reports: Array = sweep.get("queued_reports", []) as Array
	if queued_reports.is_empty():
		_fail("scheduled closeout queued report missing")
		return
	var report_id: String = str((queued_reports[0] as Dictionary).get("report_id", ""))
	if report_id.is_empty():
		_fail("scheduled closeout report id missing")
		return
	var listed: Dictionary = handshake.call("list_async_contest_payout_reports", {"contest_id": contest_id, "limit": 1}) as Dictionary
	_assert_ok(listed, "list scheduled closeout report")
	var reports: Array = listed.get("reports", []) as Array
	if reports.is_empty():
		_fail("scheduled closeout report not found on backend")
		return
	_assert_eq(str((reports[0] as Dictionary).get("report_id", "")), report_id, "scheduled closeout report id")
	_assert_eq(str((reports[0] as Dictionary).get("result_source", "")), "backend_result_ledger", "scheduled closeout uses backend result ledger")
	var report: Dictionary = reports[0] as Dictionary
	_assert_eq(int(report.get("total_take_cents", 0)), 30000, "scheduled closeout total take")
	_assert_eq(int(report.get("house_rake_cents", 0)), 3000, "scheduled closeout rake")
	_assert_eq(int(report.get("player_pool_cents", 0)), 27000, "scheduled closeout player pool")
	var planned_payouts: Array = report.get("planned_payouts", []) as Array
	_assert_eq(planned_payouts.size(), 2, "scheduled closeout planned payout count")
	_assert_eq(str((planned_payouts[0] as Dictionary).get("player_id", "")), players[1], "scheduled closeout winner")
	_assert_eq(int((planned_payouts[0] as Dictionary).get("amount_cents", 0)), 18900, "scheduled closeout first payout amount")
	_assert_eq(int((planned_payouts[1] as Dictionary).get("amount_cents", 0)), 8100, "scheduled closeout second payout amount")
	var second_sweep: Dictionary = contest_state.call("process_scheduled_money_contest_closeouts", 4) as Dictionary
	_assert_ok(second_sweep, "scheduled closeout second sweep")
	_assert_eq(int(second_sweep.get("queued_count", 0)), 0, "scheduled closeout does not duplicate report")
	_assert_eq(int(second_sweep.get("skipped_count", 0)), 1, "scheduled closeout skips existing report")
	var approve: Dictionary = handshake.call(
		"approve_async_contest_payout_report",
		report,
		"ops_smoke",
		"approve:%s:ops_smoke" % report_id
	) as Dictionary
	_assert_ok(approve, "approve scheduled closeout report")
	_assert_eq(str(approve.get("approval_status", "")), "approved", "scheduled closeout approval status")
	_assert_eq(int(approve.get("payout_total_cents", 0)), 27000, "scheduled closeout approved payout total")
	_assert_eq(int(approve.get("house_rake_cents", 0)), 3000, "scheduled closeout approved rake")
	var status_mark: Dictionary = contest_state.call("mark_money_contest_payout_approved", contest_id, approve.get("approval_report", {}) as Dictionary) as Dictionary
	_assert_ok(status_mark, "mark scheduled closeout approved")
	_assert_eq(str(contest.status), "PAYOUT_APPROVED", "scheduled closeout marks contest payout approved")
	var duplicate_approve: Dictionary = handshake.call(
		"approve_async_contest_payout_report",
		approve.get("approval_report", report) as Dictionary,
		"ops_smoke_duplicate",
		"approve:%s:ops_smoke_duplicate" % report_id
	) as Dictionary
	_assert_eq(bool(duplicate_approve.get("ok", false)), false, "duplicate scheduled closeout approval should fail")
	_assert_eq(str(duplicate_approve.get("err", duplicate_approve.get("code", ""))), "approval_report_already_approved", "duplicate scheduled closeout approval error")
	var payout_txs_result: Dictionary = handshake.call("get_money_transactions", {
		"contest_id": contest_id,
		"transaction_type": "async_winner_payout",
		"sort_desc": false
	}) as Dictionary
	_assert_ok(payout_txs_result, "fetch scheduled closeout payout transactions")
	var payout_txs: Array = payout_txs_result.get("transactions", []) as Array
	_assert_eq(payout_txs.size(), 2, "scheduled closeout payout transaction count")
	_assert_eq(str((payout_txs[0] as Dictionary).get("account_id", "")), players[1], "scheduled closeout first payout account")
	_assert_eq(int((payout_txs[0] as Dictionary).get("amount_cents", 0)), 18900, "scheduled closeout first payout ledger amount")
	_assert_eq(str((payout_txs[0] as Dictionary).get("approval_id", "")), report_id, "scheduled closeout payout approval id")
	_assert_eq(str((payout_txs[1] as Dictionary).get("account_id", "")), players[0], "scheduled closeout second payout account")
	_assert_eq(int((payout_txs[1] as Dictionary).get("amount_cents", 0)), 8100, "scheduled closeout second payout ledger amount")
	var rake_txs_result: Dictionary = handshake.call("get_money_transactions", {
		"contest_id": contest_id,
		"transaction_type": "async_house_rake"
	}) as Dictionary
	_assert_ok(rake_txs_result, "fetch scheduled closeout rake transaction")
	var rake_txs: Array = rake_txs_result.get("transactions", []) as Array
	_assert_eq(rake_txs.size(), 1, "scheduled closeout rake transaction count")
	_assert_eq(int((rake_txs[0] as Dictionary).get("amount_cents", 0)), 3000, "scheduled closeout rake ledger amount")
	_assert_eq(str((rake_txs[0] as Dictionary).get("approval_id", "")), report_id, "scheduled closeout rake approval id")
	var summary: Dictionary = handshake.call("get_money_payout_summary", {
		"contest_id": contest_id,
		"limit": 1
	}) as Dictionary
	_assert_ok(summary, "scheduled closeout payout summary")
	_assert_eq(int(summary.get("paid_out_cents", 0)), 27000, "scheduled closeout summary paid out")
	_assert_eq(int(summary.get("house_rake_cents", 0)), 3000, "scheduled closeout summary rake")
	_assert_eq(int(summary.get("gross_closed_cents", 0)), 30000, "scheduled closeout summary gross")
	_assert_eq(int(summary.get("payout_transaction_count", 0)), 2, "scheduled closeout summary payout tx count")
	_assert_eq(int(summary.get("rake_transaction_count", 0)), 1, "scheduled closeout summary rake tx count")
	var summary_contests: Array = summary.get("contests", []) as Array
	_assert_eq(summary_contests.size(), 1, "scheduled closeout summary contest count")
	_assert_eq(str((summary_contests[0] as Dictionary).get("contest_id", "")), contest_id, "scheduled closeout summary contest id")
	_assert_eq(int((summary_contests[0] as Dictionary).get("paid_out_cents", 0)), 27000, "scheduled closeout contest summary paid out")
	_assert_eq(int((summary_contests[0] as Dictionary).get("house_rake_cents", 0)), 3000, "scheduled closeout contest summary rake")
	var summary_transaction_ids: Array = (summary_contests[0] as Dictionary).get("transaction_ids", []) as Array
	_assert_eq(summary_transaction_ids.size(), 3, "scheduled closeout summary transaction id count")
	var approval_key_txs_result: Dictionary = handshake.call("get_money_transactions", {
		"contest_id": contest_id,
		"idempotency_key": "approve:%s:ops_smoke" % report_id
	}) as Dictionary
	_assert_ok(approval_key_txs_result, "fetch scheduled closeout approval-key transactions")
	_assert_eq((approval_key_txs_result.get("transactions", []) as Array).size(), 3, "scheduled closeout approval-key transaction count")
	var winner_account_txs_result: Dictionary = handshake.call("get_money_transactions", {
		"contest_id": contest_id,
		"account_id": players[1],
		"transaction_type": "async_winner_payout"
	}) as Dictionary
	_assert_ok(winner_account_txs_result, "fetch scheduled closeout winner account transactions")
	_assert_eq((winner_account_txs_result.get("transactions", []) as Array).size(), 1, "scheduled closeout winner account transaction count")

func _test_scheduled_gauntlet_money_closeout_lifecycle(handshake: Node) -> void:
	var contest_state: Node = get_root().get_node_or_null("/root/ContestState")
	if contest_state == null:
		_fail("ContestState autoload missing")
		return
	if contest_state.has_method("debug_set_runtime_leaderboard_save_path"):
		contest_state.call("debug_set_runtime_leaderboard_save_path", "user://backend_gauntlet_money_closeout_smoke.json")
	if contest_state.has_method("debug_reset_runtime_leaderboards"):
		contest_state.call("debug_reset_runtime_leaderboards")
	var stamp: int = Time.get_ticks_msec()
	var contest_id: String = "WEEKLY_USD_15_2026-W26_GAUNTLET_CLOSE_%d" % stamp
	var contest: ContestDef = ContestDef.new()
	contest.id = contest_id
	contest.scope = "WEEKLY"
	contest.currency = "USD"
	contest.price = 15
	contest.pool_type = "MONEY"
	contest.contest_family = "GAUNTLET"
	contest.schedule_kind = "SCHEDULED"
	contest.status = "OPEN"
	contest.published = true
	contest.start_ts = 1
	contest.end_ts = 2
	contest.set_cash_payout_schedule([
		{"placement": 1, "payout_bps": 7000},
		{"placement": 2, "payout_bps": 3000}
	])
	contest.normalize_definition()
	contest_state.set("contests", {contest_id: contest})
	var players: Array[String] = ["gauntlet_p1_%d" % stamp, "gauntlet_p2_%d" % stamp, "gauntlet_p3_%d" % stamp]
	var gauntlet_rows: Array[Dictionary] = [
		{"player_id": players[0], "player_name": "Gauntlet A", "run_id": "run_%s" % players[0], "total_stars": 18, "max_stars": 72, "completed_stages": 6, "stage_count": 24, "elapsed_ms": 360000, "status": "complete"},
		{"player_id": players[1], "player_name": "Gauntlet B", "run_id": "run_%s" % players[1], "total_stars": 21, "max_stars": 72, "completed_stages": 7, "stage_count": 24, "elapsed_ms": 390000, "status": "complete"},
		{"player_id": players[2], "player_name": "Gauntlet C", "run_id": "run_%s" % players[2], "total_stars": 21, "max_stars": 72, "completed_stages": 6, "stage_count": 24, "elapsed_ms": 350000, "status": "complete"}
	]
	for row in gauntlet_rows:
		var record_result: Dictionary = contest_state.call("record_gauntlet_run_result", contest_id, row) as Dictionary
		_assert_ok(record_result, "record scheduled gauntlet result")
	for i in range(players.size()):
		var player_id: String = players[i]
		var open_result: Dictionary = handshake.call(
			"open_async_entry_escrow",
			"entry:%s:%s" % [contest_id, player_id],
			contest_id,
			player_id,
			1500,
			"open:%s:%s" % [contest_id, player_id],
			10000
		) as Dictionary
		_assert_ok(open_result, "open scheduled gauntlet escrow %d" % i)
	var sweep: Dictionary = contest_state.call("process_scheduled_money_contest_closeouts", 3) as Dictionary
	_assert_ok(sweep, "scheduled gauntlet closeout sweep")
	_assert_eq(int(sweep.get("checked_count", 0)), 1, "scheduled gauntlet checked contest count")
	_assert_eq(int(sweep.get("queued_count", 0)), 1, "scheduled gauntlet queues report")
	_assert_eq(str(contest.status), "PAYOUT_PENDING", "scheduled gauntlet marks contest payout pending")
	var queued_reports: Array = sweep.get("queued_reports", []) as Array
	if queued_reports.is_empty():
		_fail("scheduled gauntlet queued report missing")
		return
	var report_id: String = str((queued_reports[0] as Dictionary).get("report_id", ""))
	var listed: Dictionary = handshake.call("list_async_contest_payout_reports", {"contest_id": contest_id, "limit": 1}) as Dictionary
	_assert_ok(listed, "list scheduled gauntlet closeout report")
	var reports: Array = listed.get("reports", []) as Array
	if reports.is_empty():
		_fail("scheduled gauntlet closeout report not found on backend")
		return
	var report: Dictionary = reports[0] as Dictionary
	_assert_eq(str(report.get("report_id", "")), report_id, "scheduled gauntlet report id")
	_assert_eq(int(report.get("total_take_cents", 0)), 4500, "scheduled gauntlet total take")
	_assert_eq(int(report.get("house_rake_cents", 0)), 450, "scheduled gauntlet rake")
	_assert_eq(int(report.get("player_pool_cents", 0)), 4050, "scheduled gauntlet player pool")
	var planned_payouts: Array = report.get("planned_payouts", []) as Array
	_assert_eq(planned_payouts.size(), 2, "scheduled gauntlet planned payout count")
	_assert_eq(str((planned_payouts[0] as Dictionary).get("player_id", "")), players[1], "scheduled gauntlet first payout player")
	_assert_eq(str((planned_payouts[1] as Dictionary).get("player_id", "")), players[2], "scheduled gauntlet second payout player")
	_assert_eq(int((planned_payouts[0] as Dictionary).get("amount_cents", 0)), 2835, "scheduled gauntlet first payout amount")
	_assert_eq(int((planned_payouts[1] as Dictionary).get("amount_cents", 0)), 1215, "scheduled gauntlet second payout amount")
	var approve_key: String = "approve:%s:gauntlet_ops_smoke" % report_id
	var approve: Dictionary = handshake.call(
		"approve_async_contest_payout_report",
		report,
		"gauntlet_ops_smoke",
		approve_key
	) as Dictionary
	_assert_ok(approve, "approve scheduled gauntlet closeout report")
	_assert_eq(int(approve.get("payout_total_cents", 0)), 4050, "scheduled gauntlet approved payout total")
	_assert_eq(int(approve.get("house_rake_cents", 0)), 450, "scheduled gauntlet approved rake")
	var status_mark: Dictionary = contest_state.call("mark_money_contest_payout_approved", contest_id, approve.get("approval_report", {}) as Dictionary) as Dictionary
	_assert_ok(status_mark, "mark scheduled gauntlet approved")
	_assert_eq(str(contest.status), "PAYOUT_APPROVED", "scheduled gauntlet marks contest payout approved")
	var duplicate_approve: Dictionary = handshake.call(
		"approve_async_contest_payout_report",
		approve.get("approval_report", report) as Dictionary,
		"gauntlet_ops_duplicate",
		"approve:%s:gauntlet_ops_duplicate" % report_id
	) as Dictionary
	_assert_eq(bool(duplicate_approve.get("ok", false)), false, "duplicate scheduled gauntlet approval should fail")
	_assert_eq(str(duplicate_approve.get("err", duplicate_approve.get("code", ""))), "approval_report_already_approved", "duplicate scheduled gauntlet approval error")
	var all_txs_result: Dictionary = handshake.call("get_money_transactions", {
		"contest_id": contest_id,
		"sort_desc": false
	}) as Dictionary
	_assert_ok(all_txs_result, "fetch scheduled gauntlet all transactions")
	var all_txs: Array = all_txs_result.get("transactions", []) as Array
	_assert_eq(all_txs.size(), 6, "scheduled gauntlet all transaction count")
	_assert_transactions_sorted_by_seq(all_txs, "scheduled gauntlet all transactions sorted")
	var approval_txs_result: Dictionary = handshake.call("get_money_transactions", {
		"contest_id": contest_id,
		"idempotency_key": approve_key
	}) as Dictionary
	_assert_ok(approval_txs_result, "fetch scheduled gauntlet approval transactions")
	_assert_eq((approval_txs_result.get("transactions", []) as Array).size(), 3, "scheduled gauntlet approval transaction count")
	var summary: Dictionary = handshake.call("get_money_payout_summary", {
		"contest_id": contest_id,
		"limit": 1
	}) as Dictionary
	_assert_ok(summary, "scheduled gauntlet payout summary")
	_assert_eq(int(summary.get("paid_out_cents", 0)), 4050, "scheduled gauntlet summary paid out")
	_assert_eq(int(summary.get("house_rake_cents", 0)), 450, "scheduled gauntlet summary rake")
	_assert_eq(int(summary.get("gross_closed_cents", 0)), 4500, "scheduled gauntlet summary gross")
	_assert_eq(int(summary.get("payout_transaction_count", 0)), 2, "scheduled gauntlet summary payout tx count")
	_assert_eq(int(summary.get("rake_transaction_count", 0)), 1, "scheduled gauntlet summary rake tx count")

func _test_scheduled_money_closeout_soak(handshake: Node) -> void:
	var contest_state: Node = get_root().get_node_or_null("/root/ContestState")
	if contest_state == null:
		_fail("ContestState autoload missing")
		return
	var stamp: int = Time.get_ticks_msec()
	for cycle in range(3):
		var contest_id: String = "WEEKLY_USD_15_2026-W26_RACE_SOAK_%d_%d" % [stamp, cycle]
		var contest: ContestDef = ContestDef.new()
		contest.id = contest_id
		contest.scope = "WEEKLY"
		contest.currency = "USD"
		contest.price = 15
		contest.pool_type = "MONEY"
		contest.contest_family = "RACE"
		contest.schedule_kind = "SCHEDULED"
		contest.status = "OPEN"
		contest.published = true
		contest.start_ts = 1
		contest.end_ts = 2
		contest.map_ids = PackedStringArray(["MAP_nomansland__545__v01_top2_sides__1p", "MAP_nomansland__545__v17_four_corners_only__1p", "MAP_nomansland__444__v01_pinched_spine__1p"])
		contest.set_cash_payout_schedule([
			{"placement": 1, "payout_bps": 6000},
			{"placement": 2, "payout_bps": 4000}
		])
		contest.normalize_definition()
		contest_state.set("contests", {contest_id: contest})
		var players: Array[String] = ["soak_p1_%d_%d" % [stamp, cycle], "soak_p2_%d_%d" % [stamp, cycle], "soak_p3_%d_%d" % [stamp, cycle]]
		for i in range(players.size()):
			var player_id: String = players[i]
			var open_result: Dictionary = handshake.call(
				"open_async_entry_escrow",
				"entry:%s:%s" % [contest_id, player_id],
				contest_id,
				player_id,
				1500,
				"open:%s:%s" % [contest_id, player_id],
				10000
			) as Dictionary
			_assert_ok(open_result, "open scheduled soak escrow %d:%d" % [cycle, i])
		var rows: Array[Dictionary] = [
			{"player_id": players[0], "map_times_ms": [65000 + cycle, 64000 + cycle, 63000 + cycle], "completed_maps": 3, "required_maps": 3},
			{"player_id": players[1], "map_times_ms": [58000 + cycle, 59000 + cycle, 60000 + cycle], "completed_maps": 3, "required_maps": 3},
			{"player_id": players[2], "map_times_ms": [68000 + cycle, 66000 + cycle, 65000 + cycle], "completed_maps": 3, "required_maps": 3}
		]
		for row in rows:
			var submit_result: Dictionary = handshake.call(
				"submit_async_contest_result",
				contest_id,
				"RACE",
				str(row.get("player_id", "")),
				row,
				"submit:%s:%s" % [contest_id, str(row.get("player_id", ""))]
			) as Dictionary
			_assert_ok(submit_result, "submit scheduled soak race result %d" % cycle)
		var sweep: Dictionary = contest_state.call("process_scheduled_money_contest_closeouts", 3 + cycle) as Dictionary
		_assert_ok(sweep, "scheduled soak closeout sweep %d" % cycle)
		_assert_eq(int(sweep.get("queued_count", 0)), 1, "scheduled soak queues one report %d" % cycle)
		_assert_eq(str(contest.status), "PAYOUT_PENDING", "scheduled soak marks pending %d" % cycle)
		var queued_reports: Array = sweep.get("queued_reports", []) as Array
		if queued_reports.is_empty():
			_fail("scheduled soak queued report missing %d" % cycle)
			return
		var report_id: String = str((queued_reports[0] as Dictionary).get("report_id", ""))
		var listed: Dictionary = handshake.call("list_async_contest_payout_reports", {"contest_id": contest_id, "limit": 1}) as Dictionary
		_assert_ok(listed, "list scheduled soak report %d" % cycle)
		var reports: Array = listed.get("reports", []) as Array
		if reports.is_empty():
			_fail("scheduled soak report not found %d" % cycle)
			return
		var report: Dictionary = reports[0] as Dictionary
		_assert_eq(str(report.get("report_id", "")), report_id, "scheduled soak report id %d" % cycle)
		_assert_eq(str(report.get("result_source", "")), "backend_result_ledger", "scheduled soak report source %d" % cycle)
		_assert_eq(int(report.get("total_take_cents", 0)), 4500, "scheduled soak total take %d" % cycle)
		_assert_eq(int(report.get("house_rake_cents", 0)), 450, "scheduled soak rake %d" % cycle)
		_assert_eq(int(report.get("player_pool_cents", 0)), 4050, "scheduled soak player pool %d" % cycle)
		var approve_key: String = "approve:%s:soak_%d" % [report_id, cycle]
		var approve: Dictionary = handshake.call(
			"approve_async_contest_payout_report",
			report,
			"ops_soak",
			approve_key
		) as Dictionary
		_assert_ok(approve, "approve scheduled soak report %d" % cycle)
		_assert_eq(int(approve.get("payout_total_cents", 0)), 4050, "scheduled soak payout total %d" % cycle)
		var mark: Dictionary = contest_state.call("mark_money_contest_payout_approved", contest_id, approve.get("approval_report", {}) as Dictionary) as Dictionary
		_assert_ok(mark, "mark scheduled soak approved %d" % cycle)
		_assert_eq(str(contest.status), "PAYOUT_APPROVED", "scheduled soak marks approved %d" % cycle)
		var all_txs_result: Dictionary = handshake.call("get_money_transactions", {
			"contest_id": contest_id,
			"sort_desc": false
		}) as Dictionary
		_assert_ok(all_txs_result, "fetch scheduled soak all transactions %d" % cycle)
		var all_txs: Array = all_txs_result.get("transactions", []) as Array
		_assert_eq(all_txs.size(), 6, "scheduled soak transaction count %d" % cycle)
		_assert_transactions_sorted_by_seq(all_txs, "scheduled soak transactions sorted %d" % cycle)
		var summary: Dictionary = handshake.call("get_money_payout_summary", {
			"contest_id": contest_id,
			"limit": 1
		}) as Dictionary
		_assert_ok(summary, "scheduled soak payout summary %d" % cycle)
		_assert_eq(int(summary.get("paid_out_cents", 0)), 4050, "scheduled soak summary paid out %d" % cycle)
		_assert_eq(int(summary.get("house_rake_cents", 0)), 450, "scheduled soak summary rake %d" % cycle)
		_assert_eq(int(summary.get("gross_closed_cents", 0)), 4500, "scheduled soak summary gross %d" % cycle)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	_fail("%s failed: %s" % [label, str(result)])

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %s got %s" % [label, str(expected), str(actual)])

func _assert_transactions_sorted_by_seq(transactions: Array, label: String) -> void:
	var last_seq: int = -1
	for tx_any in transactions:
		if typeof(tx_any) != TYPE_DICTIONARY:
			_fail("%s contained non-dictionary transaction" % label)
			return
		var tx: Dictionary = tx_any as Dictionary
		var seq: int = int(tx.get("transaction_seq", -1))
		if seq < last_seq:
			_fail("%s expected ascending transaction_seq, got %d after %d" % [label, seq, last_seq])
			return
		last_seq = seq

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("MONEY_GAME_BACKEND_TRANSPORT_SMOKE: %s" % message)
	quit(1)

func _is_transport_unavailable(result: Dictionary) -> bool:
	return bool(result.get("transport_error", false)) or str(result.get("err", "")) == "transport_not_configured" or str(result.get("err", "")) == "connect_timeout"
