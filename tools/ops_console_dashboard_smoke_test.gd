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
	var crucible_state: Node = get_root().get_node_or_null("/root/CrucibleState")
	var original_crucible_config: Dictionary = crucible_state.call("get_config_snapshot") as Dictionary if crucible_state != null and crucible_state.has_method("get_config_snapshot") else {}
	var crucible_queue_enabled: CheckButton = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleQueueEnabled") as CheckButton
	var crucible_wagering_enabled: CheckButton = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleWageringEnabled") as CheckButton
	var crucible_capacity_enabled: CheckButton = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleCapacityCapEnabled") as CheckButton
	var crucible_stake_bps: SpinBox = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleStakeBps") as SpinBox
	var crucible_burn_bps: SpinBox = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleBurnBps") as SpinBox
	var crucible_minimum_stake: SpinBox = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleMinimumStake") as SpinBox
	var crucible_capacity_max: SpinBox = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleCapacityMax") as SpinBox
	var crucible_reserved_slots: SpinBox = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleReservedSlots") as SpinBox
	var crucible_preview_player: LineEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CruciblePreviewRow/CruciblePreviewPlayer") as LineEdit
	var crucible_preview_balance: SpinBox = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CruciblePreviewRow/CruciblePreviewBalance") as SpinBox
	var crucible_preview_active_count: SpinBox = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CruciblePreviewRow/CruciblePreviewActiveCount") as SpinBox
	var crucible_preview_button: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CruciblePreviewRow/CruciblePreviewButton") as Button
	var crucible_save: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleButtons/CrucibleSave") as Button
	var crucible_status: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleStatus") as Label
	var crucible_preview_status: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CruciblePreviewStatus") as Label
	var crucible_ledger_refresh: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerControls/CrucibleLedgerRefresh") as Button
	var crucible_ledger_filter: LineEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerControls/CrucibleLedgerFilter") as LineEdit
	var crucible_ledger_export: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerControls/CrucibleLedgerExport") as Button
	var crucible_review_match: LineEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerControls/CrucibleReviewMatch") as LineEdit
	var crucible_review_resolve: Button = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerControls/CrucibleReviewResolve") as Button
	var crucible_ledger_summary: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerSummary") as Label
	var crucible_collusion_summary: Label = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleCollusionSummary") as Label
	var crucible_audit_rows: VBoxContainer = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleAuditRows") as VBoxContainer
	var crucible_ledger_rows: VBoxContainer = console.get_node_or_null("RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerRows") as VBoxContainer
	if crucible_state == null or crucible_queue_enabled == null or crucible_wagering_enabled == null or crucible_capacity_enabled == null or crucible_stake_bps == null or crucible_burn_bps == null or crucible_minimum_stake == null or crucible_capacity_max == null or crucible_reserved_slots == null or crucible_preview_player == null or crucible_preview_balance == null or crucible_preview_active_count == null or crucible_preview_button == null or crucible_save == null or crucible_status == null or crucible_preview_status == null or crucible_ledger_refresh == null or crucible_ledger_filter == null or crucible_ledger_export == null or crucible_review_match == null or crucible_review_resolve == null or crucible_ledger_summary == null or crucible_collusion_summary == null or crucible_audit_rows == null or crucible_ledger_rows == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible controls missing")
		quit(1)
		return
	crucible_queue_enabled.button_pressed = true
	crucible_wagering_enabled.button_pressed = true
	crucible_capacity_enabled.button_pressed = true
	crucible_stake_bps.value = 750
	crucible_burn_bps.value = 1250
	crucible_minimum_stake.value = 1000
	crucible_capacity_max.value = 1
	crucible_reserved_slots.value = 0
	crucible_save.pressed.emit()
	await process_frame
	var updated_crucible_config: Dictionary = crucible_state.call("get_config_snapshot") as Dictionary
	if int(updated_crucible_config.get("stake_bps", 0)) != 750 or int(updated_crucible_config.get("burn_bps", 0)) != 1250:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible save did not update stake/burn config")
		quit(1)
		return
	if not crucible_status.text.contains("Saved Crucible config"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible save status missing")
		quit(1)
		return
	crucible_preview_player.text = "ops_crucible_preview"
	crucible_preview_balance.value = 5000
	crucible_preview_active_count.value = 0
	crucible_preview_button.pressed.emit()
	await process_frame
	if not crucible_preview_status.text.contains("Entry allowed"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible allowed preview missing")
		quit(1)
		return
	crucible_preview_balance.value = 0
	crucible_preview_active_count.value = 0
	crucible_preview_button.pressed.emit()
	await process_frame
	if not crucible_preview_status.text.contains("no Wax"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible no-Wax preview missing")
		quit(1)
		return
	crucible_preview_balance.value = 5000
	crucible_preview_active_count.value = 1
	crucible_preview_button.pressed.emit()
	await process_frame
	if not crucible_preview_status.text.contains("capacity full"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible capacity preview missing")
		quit(1)
		return
	crucible_queue_enabled.button_pressed = false
	crucible_save.pressed.emit()
	await process_frame
	crucible_preview_active_count.value = 0
	crucible_preview_button.pressed.emit()
	await process_frame
	if not crucible_preview_status.text.contains("queue disabled"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible queue-disabled preview missing")
		quit(1)
		return
	if crucible_state.has_method("apply_remote_config_snapshot"):
		crucible_state.call("apply_remote_config_snapshot", {
			"enabled": true,
			"queue_enabled": true,
			"wagering_enabled": true,
			"settlement_enabled": true,
			"server_authoritative_settlement_required": false,
			"local_dev_settlement_enabled": true,
			"stake_bps": 750,
			"burn_bps": 1250,
			"minimum_stake_millis": 1000
		})
	crucible_state.call("intent_set_balance_millis", "ops_ledger_a", 20000)
	crucible_state.call("intent_set_balance_millis", "ops_ledger_b", 20000)
	var ledger_open_result: Dictionary = crucible_state.call("intent_open_escrow", "ops_ledger_match", "ops_ledger_a", "ops_ledger_b", {
		"anti_collusion_signals": {
			"repeated_same_opponent": true,
			"unusual_win_trading": true,
			"same_device_cluster": true,
			"same_ip_pattern": true,
			"suspicious_forfeit": true,
			"high_stakes_repeated_transfer": true
		}
	}) as Dictionary
	if not bool(ledger_open_result.get("ok", false)):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible ledger escrow failed %s" % str(ledger_open_result))
		quit(1)
		return
	var ledger_settle_result: Dictionary = crucible_state.call("intent_settle_match", "ops_ledger_match", "ops_ledger_a", "AUTHORITATIVE_SIM", "ops_smoke", {}) as Dictionary
	if not bool(ledger_settle_result.get("ok", false)):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible ledger settlement failed %s" % str(ledger_settle_result))
		quit(1)
		return
	var ledger_settlement: Dictionary = ledger_settle_result.get("settlement", {}) as Dictionary
	if str(ledger_settlement.get("settlement_status", "")) != "HELD_REVIEW":
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible risk settlement was not held")
		quit(1)
		return
	crucible_state.call("record_anti_collusion_observation", "ops_ledger_match", "ops_ledger_a", "ops_ledger_b", {
		"repeated_same_opponent": true,
		"unusual_win_trading": true,
		"same_device_cluster": true,
		"same_ip_pattern": true,
		"suspicious_forfeit": true,
		"high_stakes_repeated_transfer": true
	})
	crucible_ledger_refresh.pressed.emit()
	await process_frame
	if not crucible_ledger_summary.text.contains("Escrows") or not crucible_ledger_summary.text.contains("Settlements") or not crucible_ledger_summary.text.contains("Held"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible ledger summary missing")
		quit(1)
		return
	if crucible_audit_rows.get_child_count() < 2 or crucible_ledger_rows.get_child_count() < 2:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible ledger rows missing")
		quit(1)
		return
	if not crucible_collusion_summary.text.contains("flags") or not crucible_collusion_summary.text.contains("win trading") or not crucible_collusion_summary.text.contains("same IP"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible anti-collusion summary missing")
		quit(1)
		return
	crucible_ledger_filter.text = "ops_ledger_a"
	crucible_ledger_filter.text_changed.emit(crucible_ledger_filter.text)
	await process_frame
	if not crucible_ledger_summary.text.contains("1/"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible ledger filter did not narrow rows")
		quit(1)
		return
	crucible_ledger_export.pressed.emit()
	await process_frame
	if not crucible_status.text.contains("Exported Crucible ledger"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible ledger export missing")
		quit(1)
		return
	crucible_review_match.text = "ops_ledger_match"
	crucible_review_resolve.pressed.emit()
	await process_frame
	if not crucible_status.text.contains("Resolved Crucible review"):
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: Crucible review resolve missing")
		quit(1)
		return
	if not original_crucible_config.is_empty() and crucible_state.has_method("intent_update_config"):
		crucible_state.call("intent_update_config", original_crucible_config, "ops_console_smoke_restore")
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
