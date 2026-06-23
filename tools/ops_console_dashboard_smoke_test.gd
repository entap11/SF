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
	var approval_backend_status: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalBackendStatus") as Label
	var payout_report_contest_filter: LineEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportContestFilter") as LineEdit
	var payout_report_account_filter: LineEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportAccountFilter") as LineEdit
	var payout_report_refresh: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportRefresh") as Button
	var payout_report_export: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportExport") as Button
	var payout_report_summary: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportSummary") as Label
	var payout_report_rows: VBoxContainer = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportRows") as VBoxContainer
	var payout_report_status: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportStatus") as Label
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
	for i in range(setup_select.item_count):
		var setup_meta: Variant = setup_select.get_item_metadata(i)
		if typeof(setup_meta) == TYPE_DICTIONARY and str((setup_meta as Dictionary).get("scope", "")) == "WEEKLY" and int((setup_meta as Dictionary).get("price", 0)) == 5:
			money_weekly_five_index = i
			break
	if money_weekly_five_index < 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: money weekly five setup option missing")
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
	if approval_summary == null or approval_rows == null or approver_input == null or approve_button == null or refresh_reports == null or approval_backend_status == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: approval report controls missing")
		quit(1)
		return
	if payout_report_contest_filter == null or payout_report_account_filter == null or payout_report_refresh == null or payout_report_export == null or payout_report_summary == null or payout_report_rows == null or payout_report_status == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout ledger report controls missing")
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
		"contest_id": "WEEKLY_USD_5_2026-W26",
		"players_count": 100,
		"entries_count": 100,
		"paid_entries_count": 100,
		"total_take_cents": 50000,
		"house_rake_cents": 5000,
		"player_pool_cents": 45000,
		"payout_count": 2,
		"planned_payouts": [
			{"placement": 1, "player_id": "p1", "payout_bps": 6000, "amount_cents": 30000},
			{"placement": 2, "player_id": "p2", "payout_bps": 3000, "amount_cents": 15000}
		]
	})
	await process_frame
	if not approval_summary.visible or not approval_summary.text.contains("Total $500.00") or not approval_summary.text.contains("Player pool $450.00"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: approval summary did not render money totals")
		quit(1)
		return
	if approval_rows.get_child_count() != 2:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: approval rows did not render planned payouts")
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
	var export_result: Dictionary = console.call("export_current_payout_summary_csv", "user://ops_payout_summary_smoke.csv") as Dictionary
	if not bool(export_result.get("ok", false)) or not FileAccess.file_exists(str(export_result.get("path", ""))):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout summary export failed %s" % str(export_result))
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
