extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("swarmfront/vs/backend_url", "")
	var handshake: Node = get_root().get_node_or_null("/root/VsHandshake")
	if handshake != null and handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	var scene: PackedScene = load("res://scenes/ops/ops_console.tscn") as PackedScene
	if scene == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: ops console scene missing")
		quit(1)
		return
	var console: Control = scene.instantiate() as Control
	if console == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: ops console instantiate failed")
		quit(1)
		return
	get_root().add_child(console)
	await process_frame
	if console.has_method("refresh"):
		console.call("refresh")
	await process_frame
	var setup_select: OptionButton = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestSetupSelect") as OptionButton
	var map_count: OptionButton = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMapCount") as OptionButton
	var ante: SpinBox = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestAnte") as SpinBox
	var prize_pool: SpinBox = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPrizePool") as SpinBox
	var winner_count: OptionButton = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestWinnerCount") as OptionButton
	var payout_rows: VBoxContainer = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPayoutRows") as VBoxContainer
	var payout_summary: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPayoutSummary") as Label
	var rewards_json: TextEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestRewardsJson") as TextEdit
	var map_pool: ItemList = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMapPool") as ItemList
	var contest_list: ItemList = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestList") as ItemList
	var approval_summary: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalSummary") as Label
	var approval_rows: VBoxContainer = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalRows") as VBoxContainer
	var approver_input: LineEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApproverInput") as LineEdit
	var approve_button: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovePayouts") as Button
	var refresh_reports: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestRefreshPayoutReports") as Button
	var build_report: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestBuildPayoutReport") as Button
	var approval_backend_status: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalBackendStatus") as Label
	var payout_report_contest_filter: LineEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportContestFilter") as LineEdit
	var payout_report_account_filter: LineEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportAccountFilter") as LineEdit
	var payout_report_refresh: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportRefresh") as Button
	var payout_report_export: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportExport") as Button
	var payout_report_summary: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportSummary") as Label
	var payout_report_rows: VBoxContainer = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportRows") as VBoxContainer
	var payout_report_status: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportStatus") as Label
	var payout_proof_generate: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutProofButtons/PayoutProofGenerate") as Button
	var payout_proof_copy: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutProofButtons/PayoutProofCopy") as Button
	var payout_proof_export: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutProofButtons/PayoutProofExport") as Button
	var payout_proof_summary: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutProofSummary") as Label
	var payout_proof_text: TextEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutProofText") as TextEdit
	if map_count == null or map_count.item_count < 2:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: map count selector missing")
		quit(1)
		return
	if setup_select == null or setup_select.item_count <= 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: contest setup selector missing")
		quit(1)
		return
	if int(map_count.get_item_metadata(0)) != 3 or int(map_count.get_item_metadata(1)) != 5:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: map count selector metadata wrong")
		quit(1)
		return
	if prize_pool == null or rewards_json == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout fields missing")
		quit(1)
		return
	if ante == null or ante.visible:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: free setup should hide payment controls")
		quit(1)
		return
	var money_weekly_five_index: int = -1
	var money_gauntlet_sng_index: int = -1
	var free_seasonal_race_index: int = -1
	var money_miss_sng_index: int = -1
	var money_weekly_miss_index: int = -1
	var money_weekly_stage_100_index: int = -1
	var money_weekly_race_100_index: int = -1
	var money_weekly_gauntlet_100_index: int = -1
	for i in range(setup_select.item_count):
		var setup_meta: Variant = setup_select.get_item_metadata(i)
		if typeof(setup_meta) == TYPE_DICTIONARY and str((setup_meta as Dictionary).get("scope", "")) == "WEEKLY" and int((setup_meta as Dictionary).get("price", 0)) == 5:
			money_weekly_five_index = i
		if typeof(setup_meta) == TYPE_DICTIONARY and str((setup_meta as Dictionary).get("schedule_kind", "")) == "SIT_AND_GO" and str((setup_meta as Dictionary).get("family", "")) == "GAUNTLET" and int((setup_meta as Dictionary).get("price", 0)) == 5:
			money_gauntlet_sng_index = i
		if typeof(setup_meta) == TYPE_DICTIONARY and str((setup_meta as Dictionary).get("schedule_kind", "")) == "SIT_AND_GO" and str((setup_meta as Dictionary).get("family", "")) == "MISS_N_OUT" and int((setup_meta as Dictionary).get("price", 0)) == 15:
			money_miss_sng_index = i
		if typeof(setup_meta) == TYPE_DICTIONARY and str((setup_meta as Dictionary).get("scope", "")) == "WEEKLY" and str((setup_meta as Dictionary).get("family", "")) == "MISS_N_OUT" and str((setup_meta as Dictionary).get("pool_type", "")) == "MONEY":
			money_weekly_miss_index = i
		if typeof(setup_meta) == TYPE_DICTIONARY and str((setup_meta as Dictionary).get("scope", "")) == "WEEKLY" and int((setup_meta as Dictionary).get("price", 0)) == 100 and str((setup_meta as Dictionary).get("family", "")) == "STAGE_RACE":
			money_weekly_stage_100_index = i
		if typeof(setup_meta) == TYPE_DICTIONARY and str((setup_meta as Dictionary).get("scope", "")) == "WEEKLY" and int((setup_meta as Dictionary).get("price", 0)) == 100 and str((setup_meta as Dictionary).get("family", "")) == "RACE":
			money_weekly_race_100_index = i
		if typeof(setup_meta) == TYPE_DICTIONARY and str((setup_meta as Dictionary).get("scope", "")) == "WEEKLY" and int((setup_meta as Dictionary).get("price", 0)) == 100 and str((setup_meta as Dictionary).get("family", "")) == "GAUNTLET":
			money_weekly_gauntlet_100_index = i
		if typeof(setup_meta) == TYPE_DICTIONARY and str((setup_meta as Dictionary).get("scope", "")) == "SEASONAL" and str((setup_meta as Dictionary).get("family", "")) == "RACE" and str((setup_meta as Dictionary).get("pool_type", "")) == "FREE":
			free_seasonal_race_index = i
	if money_weekly_five_index < 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: money weekly five setup option missing")
		quit(1)
		return
	if money_gauntlet_sng_index < 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: money gauntlet sit-and-go setup option missing")
		quit(1)
		return
	if money_miss_sng_index < 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: money miss n out $15 sit-and-go setup option missing")
		quit(1)
		return
	if money_weekly_miss_index >= 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: paid miss n out should not be scheduled weekly")
		quit(1)
		return
	if money_weekly_stage_100_index >= 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: stage race should not expose $100 scheduled setup yet")
		quit(1)
		return
	if money_weekly_race_100_index < 0 or money_weekly_gauntlet_100_index < 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: race/gauntlet scheduled $100 setup option missing")
		quit(1)
		return
	if free_seasonal_race_index < 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: free seasonal race setup option missing")
		quit(1)
		return
	setup_select.select(money_weekly_five_index)
	setup_select.item_selected.emit(money_weekly_five_index)
	await process_frame
	if not ante.visible or int(ante.value) != 5:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: money setup should show payment controls and set ante")
		quit(1)
		return
	if winner_count == null or winner_count.item_count < 7 or payout_rows == null or payout_summary == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout schedule controls missing")
		quit(1)
		return
	var top_five_index: int = -1
	for i in range(winner_count.item_count):
		if int(winner_count.get_item_metadata(i)) == 5:
			top_five_index = i
			break
	if top_five_index < 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: top five payout option missing")
		quit(1)
		return
	winner_count.select(top_five_index)
	winner_count.item_selected.emit(top_five_index)
	await process_frame
	if payout_rows.get_child_count() != 5:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout table did not rebuild for top five")
		quit(1)
		return
	var first_percent: SpinBox = payout_rows.get_node_or_null("PayoutRow1/PayoutPercent1") as SpinBox
	if first_percent == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: first payout percent missing")
		quit(1)
		return
	first_percent.value = 40
	first_percent.value_changed.emit(first_percent.value)
	await process_frame
	if not rewards_json.text.contains("\"placement\": 1") or not rewards_json.text.contains("\"payout_bps\": 4000"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout row did not serialize to JSON")
		quit(1)
		return
	if approval_summary == null or approval_rows == null or approver_input == null or approve_button == null or refresh_reports == null or build_report == null or approval_backend_status == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: approval report controls missing")
		quit(1)
		return
	if payout_report_contest_filter == null or payout_report_account_filter == null or payout_report_refresh == null or payout_report_export == null or payout_report_summary == null or payout_report_rows == null or payout_report_status == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout ledger report controls missing")
		quit(1)
		return
	if payout_proof_generate == null or payout_proof_copy == null or payout_proof_export == null or payout_proof_summary == null or payout_proof_text == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout proof controls missing")
		quit(1)
		return
	if approval_summary.visible:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: approval report should start hidden")
		quit(1)
		return
	var approval_requests: Array[Dictionary] = []
	console.contest_payout_approval_requested.connect(func(report: Dictionary, approver_id: String) -> void:
		approval_requests.append({
			"report_id": str(report.get("report_id", "")),
			"approver_id": approver_id
		})
	)
	console.call("show_payout_approval_report", {
		"ok": true,
		"type": "async_contest_payout_approval_report",
		"approval_status": "pending_approval",
		"report_id": "APR-smoke-001",
		"contest_id": "WEEKLY_USD_5_2026-W26_RACE",
		"contest_family": "RACE",
		"players_count": 100,
		"entries_count": 100,
		"paid_entries_count": 100,
		"total_take_cents": 50000,
		"house_rake_cents": 5000,
		"player_pool_cents": 45000,
		"payout_count": 2,
		"result_source": "backend_result_ledger",
		"qualified_results_count": 3,
		"planned_payouts": [
			{"placement": 1, "player_id": "p1", "payout_bps": 6000, "amount_cents": 27000},
			{"placement": 2, "player_id": "p2", "payout_bps": 4000, "amount_cents": 18000}
		],
		"leaderboard_rows": [
			{"rank": 1, "player_id": "p1", "aggregate_ms": 185000, "completed_maps": 3},
			{"rank": 2, "player_id": "p2", "aggregate_ms": 191250, "completed_maps": 3},
			{"rank": 3, "player_id": "p3", "aggregate_ms": 203000, "completed_maps": 3}
		]
	})
	await process_frame
	if not approval_summary.visible or not approval_summary.text.contains("Total $500.00") or not approval_summary.text.contains("Player pool $450.00") or not approval_summary.text.contains("Backend results") or not approval_summary.text.contains("Qualified results 3") or not approval_summary.text.contains("Review OK"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: approval summary did not render money totals")
		quit(1)
		return
	if approval_rows.get_child_count() != 9:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: approval rows did not render planned payouts and backend leaderboard")
		quit(1)
		return
	if approve_button.disabled:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: approval button should be enabled for pending report")
		quit(1)
		return
	approver_input.text = "ops_admin"
	approve_button.pressed.emit()
	await process_frame
	if approval_requests.is_empty() or str(approval_requests[0].get("report_id", "")) != "APR-smoke-001" or str(approval_requests[0].get("approver_id", "")) != "ops_admin":
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: approval button did not emit approval request")
		quit(1)
		return
	if not approval_backend_status.text.contains("Backend not configured"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: approval backend status did not report offline intent path")
		quit(1)
		return
	console.call("show_payout_approval_report", {
		"ok": true,
		"type": "async_contest_payout_approval_report",
		"approval_status": "pending_approval",
		"report_id": "APR-smoke-bad-source",
		"contest_id": "WEEKLY_USD_5_2026-W26_RACE",
		"contest_family": "RACE",
		"players_count": 10,
		"entries_count": 10,
		"paid_entries_count": 10,
		"total_take_cents": 5000,
		"house_rake_cents": 500,
		"player_pool_cents": 4500,
		"payout_count": 1,
		"result_source": "local_runtime",
		"qualified_results_count": 1,
		"planned_payouts": [
			{"placement": 1, "player_id": "p1", "payout_bps": 10000, "amount_cents": 4500}
		],
		"leaderboard_rows": [
			{"rank": 1, "player_id": "p1", "aggregate_ms": 185000, "completed_maps": 3}
		]
	})
	await process_frame
	if not approve_button.disabled or not approval_summary.text.contains("Review Blocked"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: invalid race approval report should be blocked")
		quit(1)
		return
	approve_button.pressed.emit()
	await process_frame
	if not approval_backend_status.text.contains("must use backend result ledger"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: invalid race approval did not explain backend source blocker")
		quit(1)
		return
	payout_report_contest_filter.text = "WEEKLY_USD_5_2026-W26"
	payout_report_account_filter.text = "p1"
	payout_report_refresh.pressed.emit()
	await process_frame
	if not payout_report_status.text.contains("backend unavailable"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout summary offline status missing")
		quit(1)
		return
	console.call("show_payout_summary", {
		"ok": true,
		"type": "money_payout_summary",
		"paid_out_cents": 45000,
		"house_rake_cents": 5000,
		"gross_closed_cents": 50000,
		"payout_transaction_count": 2,
		"contest_count": 1,
		"pending_approval_reports": 0,
		"contests": [
			{
				"contest_id": "WEEKLY_USD_5_2026-W26",
				"paid_out_cents": 45000,
				"house_rake_cents": 5000,
				"total_take_cents": 50000,
				"payout_count": 2,
				"last_paid_utc": "2026-06-23T20:00:00Z",
				"transaction_ids": ["ASYNC-000000001", "ASYNC-000000002"]
			}
		]
	})
	await process_frame
	if not payout_report_summary.text.contains("Paid $450.00") or not payout_report_summary.text.contains("Gross $500.00"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout summary totals did not render")
		quit(1)
		return
	if payout_report_rows.get_child_count() < 2:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout summary rows did not render")
		quit(1)
		return
	var proof: Dictionary = console.call("build_payout_proof_from_backend", "WEEKLY_USD_5_2026-W26", {
		"ok": true,
		"reports": [
			{
				"ok": true,
				"report_id": "APR-smoke-001",
				"approval_status": "approved",
				"approved_by": "ops_admin",
				"approved_utc": "2026-06-23T20:05:00Z",
				"generated_utc": "2026-06-23T20:00:00Z",
				"updated_utc": "2026-06-23T20:05:00Z",
				"total_take_cents": 50000,
				"house_rake_cents": 5000,
				"player_pool_cents": 45000,
				"payout_total_cents": 45000
			}
		]
	}, {
		"ok": true,
		"transactions": [
			{"transaction_id": "ASYNC-000000010", "transaction_type": "async_winner_payout", "account_id": "p1", "placement": 1, "amount_cents": 27000, "approval_id": "APR-smoke-001", "created_utc": "2026-06-23T20:05:01Z"},
			{"transaction_id": "ASYNC-000000011", "transaction_type": "async_winner_payout", "account_id": "p2", "placement": 2, "amount_cents": 18000, "approval_id": "APR-smoke-001", "created_utc": "2026-06-23T20:05:02Z"},
			{"transaction_id": "ASYNC-000000012", "transaction_type": "async_house_rake", "account_id": "HOUSE", "amount_cents": 5000, "approval_id": "APR-smoke-001", "created_utc": "2026-06-23T20:05:03Z"}
		]
	}, {
		"ok": true,
		"paid_out_cents": 45000,
		"house_rake_cents": 5000,
		"gross_closed_cents": 50000,
		"payout_transaction_count": 2,
		"contests": []
	}) as Dictionary
	console.call("show_payout_proof", proof)
	await process_frame
	if not payout_proof_summary.text.contains("APR-smoke-001") or not payout_proof_summary.text.contains("Paid $450.00"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout proof summary did not render")
		quit(1)
		return
	if not payout_proof_text.text.contains("SWARMFRONT MONEY PAYOUT PROOF") or not payout_proof_text.text.contains("ASYNC-000000010") or not payout_proof_text.text.contains("RAKE TRANSACTIONS"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout proof text did not render transaction proof")
		quit(1)
		return
	var export_result: Dictionary = console.call("export_current_payout_summary_csv", "user://ops_payout_summary_smoke.csv") as Dictionary
	if not bool(export_result.get("ok", false)) or not FileAccess.file_exists(str(export_result.get("path", ""))):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout summary export failed %s" % str(export_result))
		quit(1)
		return
	var proof_export: Dictionary = console.call("export_current_payout_proof", "user://ops_payout_proof_smoke.txt") as Dictionary
	if not bool(proof_export.get("ok", false)) or not FileAccess.file_exists(str(proof_export.get("path", ""))):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout proof export failed %s" % str(proof_export))
		quit(1)
		return
	if map_pool == null or map_pool.item_count <= 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: map pool did not load")
		quit(1)
		return
	if contest_list == null or contest_list.item_count <= 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: contests did not load")
		quit(1)
		return
	console.queue_free()
	await process_frame
	print("OPS_CONSOLE_DASHBOARD_SMOKE: PASS")
	quit(0)
