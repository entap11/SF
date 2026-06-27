extends Control

signal contest_payout_approval_requested(report: Dictionary, approver_id: String)

const VsSpectatorRuntimeScript := preload("res://scripts/state/vs_spectator_runtime.gd")
const MatchReplayMapViewScript := preload("res://scripts/ui/match_replay_map_view.gd")
const DEFAULT_MONEY_DENOMINATIONS: Array[int] = [1, 2, 3, 5, 10, 15, 20, 50, 100]
const DEFAULT_HOUSE_RAKE_BPS: int = 1000
const BASIS_POINTS_DENOMINATOR: int = 10000
const PAYOUT_REPORT_EXPORT_PATH: String = "user://ops_payout_summary_export.csv"
const PAYOUT_PROOF_EXPORT_PATH: String = "user://ops_payout_proof.txt"
const CONTEST_SCHEDULED_SCOPES: Array[String] = ["WEEKLY", "MONTHLY", "SEASONAL"]
const CONTEST_GAME_FAMILIES: Array[Dictionary] = [
	{"label": "Stage race", "family": "STAGE_RACE", "mode": "STAGE_RACE", "map_count": 5, "min_players": 5, "max_players": 10},
	{"label": "Miss n out", "family": "MISS_N_OUT", "mode": "MISS_N_OUT", "map_count": 3, "min_players": 4, "max_players": 8},
	{"label": "Race", "family": "RACE", "mode": "RACE", "map_count": 3, "min_players": 5, "max_players": 10},
	{"label": "Gauntlet", "family": "GAUNTLET", "mode": "GAUNTLET", "map_count": 5, "min_players": 10, "max_players": 10}
]
const MONEY_SCHEDULED_CONTEST_FAMILIES: Array[String] = ["STAGE_RACE", "RACE", "GAUNTLET"]
const HIGH_STAKES_SCHEDULED_FAMILIES: Array[String] = ["RACE", "GAUNTLET"]
const SIT_AND_GO_CONTEST_FAMILIES: Array[String] = ["MISS_N_OUT", "GAUNTLET"]
const CRUCIBLE_LEDGER_EXPORT_PATH: String = "user://ops_crucible_ledger_export.csv"

@onready var contest_list: ItemList = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestList
@onready var contest_setup_select: OptionButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestSetupSelect
@onready var contest_id: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestId
@onready var contest_name: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestName
@onready var contest_mode: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMode
@onready var contest_start: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestStart
@onready var contest_end: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestEnd
@onready var contest_entry_type_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestEntryTypeLabel
@onready var contest_entry_type: OptionButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestEntryType
@onready var contest_ante_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestAnteLabel
@onready var contest_ante: SpinBox = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestAnte
@onready var contest_map_count: OptionButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMapCount
@onready var contest_prize_pool_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPrizePoolLabel
@onready var contest_prize_pool: SpinBox = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPrizePool
@onready var contest_winner_count_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestWinnerCountLabel
@onready var contest_winner_count: OptionButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestWinnerCount
@onready var contest_payout_rows: VBoxContainer = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPayoutRows
@onready var contest_payout_summary: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPayoutSummary
@onready var contest_rewards_json_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestRewardsJsonLabel
@onready var contest_rewards_json: TextEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestRewardsJson
@onready var contest_map_pool: ItemList = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMapPool
@onready var contest_published: CheckButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPublished
@onready var contest_new: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestButtons/ContestNew
@onready var contest_save: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestButtons/ContestSave
@onready var contest_delete: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestButtons/ContestDelete
@onready var contest_status: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestStatus
@onready var contest_approval_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalLabel
@onready var contest_refresh_payout_reports: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestRefreshPayoutReports
@onready var contest_build_payout_report: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestBuildPayoutReport
@onready var contest_approval_summary: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalSummary
@onready var contest_approval_rows: VBoxContainer = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalRows
@onready var contest_approver_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApproverLabel
@onready var contest_approver_input: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApproverInput
@onready var contest_approve_payouts: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovePayouts
@onready var contest_approval_backend_status: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalBackendStatus
@onready var payout_report_contest_filter: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportContestFilter
@onready var payout_report_account_filter: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportAccountFilter
@onready var payout_report_refresh: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportRefresh
@onready var payout_report_export: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportExport
@onready var payout_report_summary: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportSummary
@onready var payout_report_rows: VBoxContainer = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportRows
@onready var payout_report_status: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportStatus
@onready var payout_proof_generate: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutProofButtons/PayoutProofGenerate
@onready var payout_proof_copy: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutProofButtons/PayoutProofCopy
@onready var payout_proof_export: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutProofButtons/PayoutProofExport
@onready var payout_proof_summary: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutProofSummary
@onready var payout_proof_text: TextEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutProofText
@onready var tabs: TabContainer = $RootPanel/RootVBox/Tabs

@onready var crucible_enabled: CheckButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleEnabled
@onready var crucible_queue_enabled: CheckButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleQueueEnabled
@onready var crucible_wagering_enabled: CheckButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleWageringEnabled
@onready var crucible_ads_enabled: CheckButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleAdsEnabled
@onready var crucible_capacity_cap_enabled: CheckButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleCapacityCapEnabled
@onready var crucible_settlement_enabled: CheckButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleSettlementEnabled
@onready var crucible_earn_buttons_enabled: CheckButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleEarnButtonsEnabled
@onready var crucible_server_settlement_required: CheckButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleServerSettlementRequired
@onready var crucible_local_dev_settlement_enabled: CheckButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleLocalDevSettlementEnabled
@onready var crucible_launch_grant_enabled: CheckButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleSwitches/CrucibleLaunchGrantEnabled
@onready var crucible_config_version: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleConfigVersion
@onready var crucible_stake_bps: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleStakeBps
@onready var crucible_burn_bps: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleBurnBps
@onready var crucible_minimum_stake: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleMinimumStake
@onready var crucible_capacity_max: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleCapacityMax
@onready var crucible_reserved_slots: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleReservedSlots
@onready var crucible_starting_wax: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleStartingWax
@onready var crucible_launch_grant_millis: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleLaunchGrantMillis
@onready var crucible_standard_win_earn: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleStandardWinEarn
@onready var crucible_standard_loss_earn: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleStandardLossEarn
@onready var crucible_tournament_earn: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleTournamentEarn
@onready var crucible_challenge_earn: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleChallengeEarn
@onready var crucible_event_earn: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleNumericGrid/CrucibleEventEarn
@onready var crucible_rounding_mode: OptionButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleRoundingRow/CrucibleRoundingMode
@onready var crucible_preview_player: LineEdit = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CruciblePreviewRow/CruciblePreviewPlayer
@onready var crucible_preview_balance: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CruciblePreviewRow/CruciblePreviewBalance
@onready var crucible_preview_active_count: SpinBox = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CruciblePreviewRow/CruciblePreviewActiveCount
@onready var crucible_preview_button: Button = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CruciblePreviewRow/CruciblePreviewButton
@onready var crucible_refresh: Button = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleButtons/CrucibleRefresh
@onready var crucible_save: Button = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleButtons/CrucibleSave
@onready var crucible_status: Label = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleStatus
@onready var crucible_preview_status: Label = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CruciblePreviewStatus
@onready var crucible_ledger_refresh: Button = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerControls/CrucibleLedgerRefresh
@onready var crucible_ledger_filter: LineEdit = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerControls/CrucibleLedgerFilter
@onready var crucible_ledger_export: Button = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerControls/CrucibleLedgerExport
@onready var crucible_review_match: LineEdit = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerControls/CrucibleReviewMatch
@onready var crucible_review_action: OptionButton = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerControls/CrucibleReviewAction
@onready var crucible_review_resolve: Button = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerControls/CrucibleReviewResolve
@onready var crucible_ledger_summary: Label = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerSummary
@onready var crucible_collusion_summary: Label = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleCollusionSummary
@onready var crucible_audit_rows: VBoxContainer = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleAuditRows
@onready var crucible_ledger_rows: VBoxContainer = $RootPanel/RootVBox/Tabs/Crucible/CrucibleScroll/CrucibleForm/CrucibleLedgerRows

@onready var map_list: ItemList = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapList
@onready var map_id: Label = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapId
@onready var map_name: Label = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapName
@onready var map_scene_path: Label = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapScenePath
@onready var map_preview: TextureRect = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapPreview
@onready var map_preview_path: Label = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapPreviewPath
@onready var map_in_pool: CheckButton = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapInPool
@onready var map_load_test: Button = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapLoadTest
@onready var map_status: Label = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapStatus
@onready var contest_state: Node = get_node_or_null("/root/ContestState")

var _current_contest_id: String = ""
var _current_map_id: String = ""
var _current_payout_approval_report: Dictionary = {}
var _current_payout_summary: Dictionary = {}
var _current_payout_proof: Dictionary = {}
var _spectator_runtime: Node = null
var _spectator_session_id: LineEdit = null
var _spectator_uid: LineEdit = null
var _spectator_delay: SpinBox = null
var _spectator_live: CheckButton = null
var _spectator_status: Label = null
var _spectator_events: TextEdit = null
var _spectator_map_view: Control = null
var _spectator_join_button: Button = null
var _spectator_poll_button: Button = null
var _spectator_leave_button: Button = null
var _ops_config_status: Label = null
var _ops_config_payload: TextEdit = null
var _ops_config_reload_button: Button = null
var _ops_config_copy_button: Button = null
var _current_crucible_ledger_snapshot: Dictionary = {}
var _current_crucible_filtered_ledger_entries: Array[Dictionary] = []
var _current_crucible_filtered_audit_records: Array[Dictionary] = []

func _ready() -> void:
	if _ops_config_tab_only_smoke():
		_ensure_ops_config_tab()
		return
	if _spectator_tab_only_smoke():
		_ensure_spectator_tab()
		return
	contest_entry_type.clear()
	contest_entry_type.add_item("WEEKLY")
	contest_entry_type.add_item("MONTHLY")
	contest_entry_type.add_item("SEASONAL")
	contest_entry_type.add_item("DAILY")
	contest_entry_type.add_item("EVENT")
	_configure_contest_setup_selector()
	contest_map_count.clear()
	contest_map_count.add_item("3 maps")
	contest_map_count.set_item_metadata(0, 3)
	contest_map_count.add_item("5 maps")
	contest_map_count.set_item_metadata(1, 5)
	contest_map_count.select(1)
	_configure_winner_count_selector()
	contest_setup_select.item_selected.connect(_on_contest_setup_selected)
	contest_map_pool.select_mode = ItemList.SELECT_MULTI
	contest_list.item_selected.connect(_on_contest_selected)
	contest_new.pressed.connect(_on_contest_new)
	contest_save.pressed.connect(_on_contest_save)
	contest_delete.pressed.connect(_on_contest_delete)
	contest_refresh_payout_reports.pressed.connect(_on_refresh_payout_reports_pressed)
	contest_build_payout_report.pressed.connect(_on_build_payout_report_pressed)
	contest_approve_payouts.pressed.connect(_on_approve_payouts_pressed)
	payout_report_refresh.pressed.connect(_on_refresh_payout_summary_pressed)
	payout_report_export.pressed.connect(_on_export_payout_summary_pressed)
	payout_proof_generate.pressed.connect(_on_generate_payout_proof_pressed)
	payout_proof_copy.pressed.connect(_on_copy_payout_proof_pressed)
	payout_proof_export.pressed.connect(_on_export_payout_proof_pressed)
	crucible_refresh.pressed.connect(_on_crucible_refresh_pressed)
	crucible_save.pressed.connect(_on_crucible_save_pressed)
	crucible_preview_button.pressed.connect(_on_crucible_preview_pressed)
	crucible_ledger_refresh.pressed.connect(_on_crucible_ledger_refresh_pressed)
	crucible_ledger_filter.text_changed.connect(_on_crucible_ledger_filter_changed)
	crucible_ledger_export.pressed.connect(_on_crucible_ledger_export_pressed)
	crucible_review_resolve.pressed.connect(_on_crucible_review_resolve_pressed)
	map_list.item_selected.connect(_on_map_selected)
	map_in_pool.toggled.connect(_on_map_in_pool_toggled)
	map_load_test.pressed.connect(_on_map_load_test)
	map_preview.expand = true
	map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_status.text = ""
	contest_status.text = ""
	contest_approval_backend_status.text = ""
	payout_report_status.text = ""
	_rebuild_payout_rows(1)
	_refresh_payment_controls()
	clear_payout_approval_report()
	clear_payout_summary()
	clear_payout_proof()
	_ensure_ops_config_tab()
	_ensure_spectator_tab()
	_configure_crucible_rounding_selector()
	_configure_crucible_review_selector()
	refresh_crucible_config()
	refresh_crucible_ledger()

func _ensure_ops_config_tab() -> void:
	if tabs == null:
		return
	var existing: Control = tabs.get_node_or_null("OpsConfig") as Control
	if existing != null:
		_render_ops_config_status()
		return
	var tab: MarginContainer = MarginContainer.new()
	tab.name = "OpsConfig"
	tab.add_theme_constant_override("margin_left", 12)
	tab.add_theme_constant_override("margin_top", 12)
	tab.add_theme_constant_override("margin_right", 12)
	tab.add_theme_constant_override("margin_bottom", 12)
	tabs.add_child(tab)
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "OpsConfigVBox"
	root.add_theme_constant_override("separation", 8)
	tab.add_child(root)
	var title: Label = Label.new()
	title.text = "Beta Ops Config"
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)
	_ops_config_status = Label.new()
	_ops_config_status.name = "OpsConfigStatus"
	_ops_config_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_ops_config_status)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "OpsConfigButtons"
	buttons.add_theme_constant_override("separation", 8)
	_ops_config_reload_button = Button.new()
	_ops_config_reload_button.name = "OpsConfigReload"
	_ops_config_reload_button.text = "Reload"
	_ops_config_reload_button.pressed.connect(_on_ops_config_reload_pressed)
	buttons.add_child(_ops_config_reload_button)
	_ops_config_copy_button = Button.new()
	_ops_config_copy_button.name = "OpsConfigCopy"
	_ops_config_copy_button.text = "Copy Snapshot"
	_ops_config_copy_button.pressed.connect(_on_ops_config_copy_pressed)
	buttons.add_child(_ops_config_copy_button)
	root.add_child(buttons)
	_ops_config_payload = TextEdit.new()
	_ops_config_payload.name = "OpsConfigPayload"
	_ops_config_payload.custom_minimum_size = Vector2(640.0, 420.0)
	_ops_config_payload.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ops_config_payload.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ops_config_payload.editable = false
	root.add_child(_ops_config_payload)
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_signal("config_changed"):
		var callback: Callable = Callable(self, "_on_ops_config_changed")
		if not ops_config.is_connected("config_changed", callback):
			ops_config.connect("config_changed", callback)
	_render_ops_config_status()

func _ops_config_tab_only_smoke() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("ops_console_config_tab_only", false))

func _on_ops_config_reload_pressed() -> void:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("reload"):
		ops_config.call("reload")
	_render_ops_config_status()

func _on_ops_config_copy_pressed() -> void:
	DisplayServer.clipboard_set(JSON.stringify(_build_ops_config_payload(), "\t"))
	if _ops_config_status != null:
		_ops_config_status.text = "%s\nCopied ops config snapshot." % _ops_config_summary_text()

func _on_ops_config_changed(_snapshot: Dictionary) -> void:
	_render_ops_config_status()

func _render_ops_config_status() -> void:
	var payload: Dictionary = _build_ops_config_payload()
	if _ops_config_status != null:
		_ops_config_status.text = _ops_config_summary_text(payload)
	if _ops_config_payload != null:
		_ops_config_payload.text = JSON.stringify(payload, "\t")

func _build_ops_config_payload() -> Dictionary:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config == null:
		return {
			"ok": false,
			"reason": "ops_config_autoload_missing"
		}
	var config: Dictionary = ops_config.call("get_config_snapshot") as Dictionary if ops_config.has_method("get_config_snapshot") else {}
	var debug: Dictionary = ops_config.call("get_debug_snapshot") as Dictionary if ops_config.has_method("get_debug_snapshot") else {}
	var validation: Dictionary = ops_config.call("validate_config_payload", config) as Dictionary if ops_config.has_method("validate_config_payload") else {"ok": false, "errors": ["validator_missing"]}
	var fail_closed: Dictionary = ops_config.call("get_fail_closed_policy") as Dictionary if ops_config.has_method("get_fail_closed_policy") else {}
	return {
		"ok": bool(validation.get("ok", false)),
		"debug": debug,
		"validation": validation,
		"fail_closed_policy": fail_closed,
		"active_config": config
	}

func _ops_config_summary_text(payload: Dictionary = {}) -> String:
	var resolved: Dictionary = payload if not payload.is_empty() else _build_ops_config_payload()
	var debug: Dictionary = resolved.get("debug", {}) as Dictionary
	var validation: Dictionary = resolved.get("validation", {}) as Dictionary
	return "source=%s | version=%s | hash=%s | valid=%s | errors=%d | warnings=%d" % [
		str(debug.get("config_source", "")),
		str(debug.get("config_version", "")),
		str(debug.get("config_hash", "")).substr(0, 12),
		str(validation.get("ok", false)),
		(validation.get("errors", []) as Array).size(),
		(validation.get("warnings", []) as Array).size()
	]

func _ensure_spectator_tab() -> void:
	if tabs == null:
		return
	var existing: Control = tabs.get_node_or_null("Spectate") as Control
	if existing != null:
		return
	var tab: MarginContainer = MarginContainer.new()
	tab.name = "Spectate"
	tab.add_theme_constant_override("margin_left", 12)
	tab.add_theme_constant_override("margin_top", 12)
	tab.add_theme_constant_override("margin_right", 12)
	tab.add_theme_constant_override("margin_bottom", 12)
	tabs.add_child(tab)
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "SpectateVBox"
	root.add_theme_constant_override("separation", 8)
	tab.add_child(root)
	var title: Label = Label.new()
	title.text = "Admin Spectate"
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)
	_spectator_status = Label.new()
	_spectator_status.name = "SpectatorStatus"
	_spectator_status.text = "Read-only spectator transport. No player controls."
	_spectator_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_spectator_status)
	_spectator_session_id = _ops_line_edit("SpectatorSessionId", "Session ID")
	root.add_child(_labeled_control("Session ID", _spectator_session_id))
	_spectator_uid = _ops_line_edit("SpectatorUid", "ops_spectator")
	_spectator_uid.text = "ops_spectator"
	root.add_child(_labeled_control("Spectator UID", _spectator_uid))
	var options_row: HBoxContainer = HBoxContainer.new()
	options_row.name = "SpectatorOptions"
	options_row.add_theme_constant_override("separation", 8)
	_spectator_delay = SpinBox.new()
	_spectator_delay.name = "SpectatorDelay"
	_spectator_delay.min_value = 10
	_spectator_delay.max_value = 30
	_spectator_delay.step = 1
	_spectator_delay.value = 20
	options_row.add_child(_labeled_control("Delay sec", _spectator_delay))
	_spectator_live = CheckButton.new()
	_spectator_live.name = "SpectatorLiveAdmin"
	_spectator_live.text = "Live admin"
	options_row.add_child(_spectator_live)
	root.add_child(options_row)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "SpectatorButtons"
	buttons.add_theme_constant_override("separation", 8)
	_spectator_join_button = Button.new()
	_spectator_join_button.name = "SpectatorJoin"
	_spectator_join_button.text = "Create Grant + Join"
	_spectator_join_button.pressed.connect(_on_spectator_join_pressed)
	buttons.add_child(_spectator_join_button)
	_spectator_poll_button = Button.new()
	_spectator_poll_button.name = "SpectatorPoll"
	_spectator_poll_button.text = "Poll"
	_spectator_poll_button.pressed.connect(_on_spectator_poll_pressed)
	buttons.add_child(_spectator_poll_button)
	_spectator_leave_button = Button.new()
	_spectator_leave_button.name = "SpectatorLeave"
	_spectator_leave_button.text = "Leave"
	_spectator_leave_button.pressed.connect(_on_spectator_leave_pressed)
	buttons.add_child(_spectator_leave_button)
	root.add_child(buttons)
	_spectator_map_view = MatchReplayMapViewScript.new()
	_spectator_map_view.name = "SpectatorMapView"
	_spectator_map_view.custom_minimum_size = Vector2(560.0, 300.0)
	_spectator_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spectator_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_spectator_map_view)
	_spectator_events = TextEdit.new()
	_spectator_events.name = "SpectatorEvents"
	_spectator_events.custom_minimum_size = Vector2(560.0, 220.0)
	_spectator_events.editable = false
	root.add_child(_spectator_events)
	_spectator_runtime = VsSpectatorRuntimeScript.new()
	_spectator_runtime.name = "SpectatorRuntime"
	add_child(_spectator_runtime)
	_sync_spectator_gate()

func _spectator_tab_only_smoke() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("ops_console_spectator_tab_only", false))

func _ops_line_edit(node_name: String, placeholder: String) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.name = node_name
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return edit

func _labeled_control(label_text: String, control: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = label_text
	row.add_theme_constant_override("separation", 8)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120.0, 0.0)
	row.add_child(label)
	row.add_child(control)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row

func _on_spectator_join_pressed() -> void:
	if not _observer_mode_enabled():
		_set_spectator_status("Observer mode disabled by beta config.")
		return
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null or not handshake.has_method("create_spectator_grant"):
		_set_spectator_status("Spectator backend unavailable.")
		return
	var session_id: String = _spectator_session_id.text.strip_edges() if _spectator_session_id != null else ""
	if session_id.is_empty():
		_set_spectator_status("Enter a session id.")
		return
	var spectator_uid: String = _spectator_uid.text.strip_edges() if _spectator_uid != null else "ops_spectator"
	if spectator_uid.is_empty():
		spectator_uid = "ops_spectator"
	var live: bool = _spectator_live != null and _spectator_live.button_pressed
	var delay_sec: int = 0 if live else int(_spectator_delay.value if _spectator_delay != null else 20)
	var role: String = "admin_spectate" if live else "invited_spectator"
	var grant_result: Dictionary = handshake.call("create_spectator_grant", session_id, role, spectator_uid, "Ops Spectator", delay_sec) as Dictionary
	if not bool(grant_result.get("ok", false)):
		_set_spectator_status("Grant failed: %s" % str(grant_result.get("err", "unknown")))
		return
	var grant: Dictionary = grant_result.get("grant", {}) as Dictionary
	var token: String = str(grant.get("token", "")).strip_edges()
	if token.is_empty():
		_set_spectator_status("Grant did not return a token.")
		return
	if _spectator_runtime == null:
		_set_spectator_status("Spectator runtime missing.")
		return
	_spectator_runtime.call("configure", session_id, token, spectator_uid, "Ops Spectator", handshake)
	var join_result: Dictionary = _spectator_runtime.call("join") as Dictionary
	if not bool(join_result.get("ok", false)):
		_set_spectator_status("Join failed: %s" % str(join_result.get("err", "unknown")))
		return
	_set_spectator_status(_spectator_summary())

func _on_spectator_poll_pressed() -> void:
	if _spectator_runtime == null:
		_set_spectator_status("Spectator runtime missing.")
		return
	var poll_result: Dictionary = _spectator_runtime.call("poll_once") as Dictionary
	if not bool(poll_result.get("ok", false)):
		_set_spectator_status("Poll failed: %s" % str(poll_result.get("err", "unknown")))
		return
	var snapshot_result: Dictionary = _spectator_runtime.call("poll_snapshots_once") as Dictionary
	if not bool(snapshot_result.get("ok", false)):
		_set_spectator_status("Visual poll failed: %s" % str(snapshot_result.get("err", "unknown")))
		return
	_set_spectator_status(_spectator_summary())
	_render_spectator_events()
	_render_spectator_visual()

func _on_spectator_leave_pressed() -> void:
	if _spectator_runtime != null:
		_spectator_runtime.call("leave")
	_set_spectator_status("Spectator disconnected.")
	if _spectator_events != null:
		_spectator_events.text = ""
	if _spectator_map_view != null and _spectator_map_view.has_method("set_replay_data"):
		_spectator_map_view.call("set_replay_data", {})

func _set_spectator_status(text: String) -> void:
	if _spectator_status != null:
		_spectator_status.text = text

func _sync_spectator_gate() -> void:
	var enabled: bool = _observer_mode_enabled()
	if not enabled:
		_set_spectator_status("Observer mode disabled by beta config.")
	for button in [_spectator_join_button, _spectator_poll_button, _spectator_leave_button]:
		if button != null:
			button.disabled = not enabled

func _observer_mode_enabled() -> bool:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("observer_mode_enabled"):
		return bool(ops_config.call("observer_mode_enabled"))
	return false

func _spectator_summary() -> String:
	if _spectator_runtime == null:
		return "Spectator runtime missing."
	var snap: Dictionary = _spectator_runtime.call("get_debug_snapshot") as Dictionary
	var mode: String = "LIVE ADMIN" if bool(snap.get("live", false)) else "Delayed %ds" % int(snap.get("delay_sec", 0))
	return "SPECTATING %s | %s | events=%d | visuals=%d | polls=%d" % [
		str(snap.get("session_id", "")),
		mode,
		int(snap.get("event_count", 0)),
		int(snap.get("snapshot_count", 0)),
		int(snap.get("poll_count", 0))
	]

func _render_spectator_events() -> void:
	if _spectator_runtime == null or _spectator_events == null:
		return
	var events: Array = _spectator_runtime.call("get_event_buffer") as Array
	var lines: PackedStringArray = PackedStringArray()
	for event_any in events:
		if typeof(event_any) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_any as Dictionary
		var command: Dictionary = event.get("command", {}) as Dictionary
		lines.append("#%d %s %s" % [
			int(event.get("seq", 0)),
			str(event.get("uid", "")),
			str(command.get("kind", command.get("type", "event")))
		])
	_spectator_events.text = "\n".join(lines)

func _render_spectator_visual() -> void:
	if _spectator_runtime == null or _spectator_map_view == null:
		return
	var latest_event: Dictionary = _spectator_runtime.call("get_latest_snapshot") as Dictionary
	var payload_any: Variant = latest_event.get("snapshot", {})
	if typeof(payload_any) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = payload_any as Dictionary
	var replay_any: Variant = payload.get("replay", payload.get("visual_replay", {}))
	if typeof(replay_any) != TYPE_DICTIONARY:
		return
	var replay: Dictionary = replay_any as Dictionary
	if _spectator_map_view.has_method("set_replay_data"):
		_spectator_map_view.call("set_replay_data", replay)
	var frame_index: int = int(payload.get("frame_index", -1))
	if frame_index < 0 and _spectator_map_view.has_method("frame_count"):
		frame_index = int(_spectator_map_view.call("frame_count")) - 1
	if _spectator_map_view.has_method("set_frame_index"):
		_spectator_map_view.call("set_frame_index", maxi(0, frame_index))

func refresh() -> void:
	_load_contests()
	_load_maps()
	request_scheduled_money_closeout_sweep()
	refresh_crucible_config()
	refresh_crucible_ledger()

func _load_contests() -> void:
	contest_list.clear()
	OpsState.load_contests()
	var ids: PackedStringArray = OpsState.get_contest_ids()
	if ids.is_empty():
		contest_list.add_item("No contests yet")
		contest_list.set_item_selectable(0, false)
		_clear_contest_form()
		return
	for id in ids:
		var contest: ContestDef = OpsState.contests.get(id)
		var label: String = id
		if contest != null and contest.published:
			label = "%s (published)" % id
		var idx: int = contest_list.add_item(label)
		contest_list.set_item_metadata(idx, id)
	_clear_contest_form()

func _load_maps() -> void:
	map_list.clear()
	OpsState.load_maps()
	var ids: PackedStringArray = OpsState.get_map_ids()
	contest_map_pool.clear()
	if ids.is_empty():
		map_list.add_item("No maps found")
		map_list.set_item_selectable(0, false)
		contest_map_pool.add_item("No maps found")
		contest_map_pool.set_item_selectable(0, false)
		_clear_map_form()
		return
	for id in ids:
		var map_def: MapDef = OpsState.maps.get(id)
		var label: String = id
		if map_def != null and not map_def.display_name.is_empty():
			label = "%s (%s)" % [id, map_def.display_name]
		var idx: int = map_list.add_item(label)
		map_list.set_item_metadata(idx, id)
		var pool_idx: int = contest_map_pool.add_item(id)
		contest_map_pool.set_item_metadata(pool_idx, id)
	_clear_map_form()

func _on_contest_selected(index: int) -> void:
	var contest_id_meta: Variant = contest_list.get_item_metadata(index)
	if contest_id_meta == null:
		return
	var contest_id_str: String = str(contest_id_meta)
	var contest: ContestDef = OpsState.contests.get(contest_id_str)
	if contest == null:
		return
	_current_contest_id = contest.id
	contest_id.text = contest.id
	contest_name.text = contest.name
	contest_mode.text = contest.mode
	contest_start.text = str(contest.start_ts)
	contest_end.text = str(contest.end_ts)
	_set_scope_selection(contest.scope)
	contest_ante.value = contest.price
	_set_contest_setup_selection(contest.scope, contest.currency, contest.price, contest.contest_family, contest.schedule_kind)
	_set_map_count_selection(contest.map_ids.size())
	contest_prize_pool.value = float(maxi(0, contest.prize_pool_cents)) / 100.0
	var cash_schedule: Array[Dictionary] = contest.get_cash_payout_schedule() if contest.has_method("get_cash_payout_schedule") else contest.prize_rewards
	_set_winner_count_selection(maxi(1, _infer_winner_count(cash_schedule)))
	_rebuild_payout_rows(_selected_winner_count(), cash_schedule)
	contest_published.button_pressed = contest.published
	_set_contest_map_pool_selection(contest.map_ids)
	_refresh_payment_controls()
	contest_status.text = "Loaded %s" % contest.id

func _set_contest_map_pool_selection(map_ids: PackedStringArray) -> void:
	contest_map_pool.deselect_all()
	for i in range(contest_map_pool.item_count):
		var map_id: String = str(contest_map_pool.get_item_metadata(i))
		if map_ids.has(map_id):
			contest_map_pool.select(i, true)

func _on_contest_new() -> void:
	_current_contest_id = ""
	_clear_contest_form()
	contest_status.text = "New contest"

func _on_contest_save() -> void:
	var contest: ContestDef = ContestDef.new()
	contest.id = contest_id.text.strip_edges()
	var parts: Dictionary = _parse_contest_id(contest.id)
	if parts.is_empty():
		contest_status.text = "Invalid contest ID format"
		return
	var selected_scope: String = _selected_scope()
	var selected_price: int = maxi(0, int(contest_ante.value))
	parts["scope"] = selected_scope
	parts["price"] = selected_price
	parts["currency"] = "FREE" if selected_price <= 0 else str(parts.get("currency", "USD")).strip_edges().to_upper()
	var normalized_id: String = _build_contest_id(parts)
	if not normalized_id.is_empty():
		contest.id = normalized_id
	contest.name = contest_name.text.strip_edges()
	contest.mode = contest_mode.text.strip_edges()
	contest.scope = selected_scope
	contest.currency = str(parts.get("currency", contest.currency))
	contest.price = selected_price
	var selected_setup: Dictionary = _selected_contest_setup_metadata()
	contest.pool_type = str(selected_setup.get("pool_type", "MONEY" if selected_price > 0 else "FREE")).strip_edges().to_upper()
	contest.contest_family = str(selected_setup.get("family", contest.contest_family)).strip_edges().to_upper()
	contest.schedule_kind = str(selected_setup.get("schedule_kind", contest.schedule_kind)).strip_edges().to_upper()
	contest.min_players = maxi(0, int(selected_setup.get("min_players", contest.min_players)))
	contest.max_players = maxi(contest.min_players, int(selected_setup.get("max_players", contest.max_players)))
	contest.time_slice = str(parts.get("time", contest.time_slice))
	contest.status = "OPEN"
	contest.start_ts = int(contest_start.text)
	contest.end_ts = int(contest_end.text)
	contest.published = contest_published.button_pressed
	var selected_maps: PackedStringArray = _collect_selected_map_pool()
	var target_map_count: int = _selected_map_count()
	if selected_maps.size() < target_map_count:
		contest_status.text = "Select at least %d maps for this contest" % target_map_count
		return
	contest.map_ids = _trim_map_ids_to_count(selected_maps, target_map_count)
	contest.house_rake_bps = DEFAULT_HOUSE_RAKE_BPS
	if contest.has_method("normalize_definition"):
		contest.normalize_definition()
	if selected_price > 0:
		contest.prize_pool_cents = int(round(float(contest_prize_pool.value) * 100.0))
		contest.set_cash_payout_schedule(_collect_payout_schedule_from_rows())
		var payout_bps: int = contest.get_cash_payout_total_bps()
		if payout_bps != BASIS_POINTS_DENOMINATOR:
			contest_status.text = "Money payout percentages must equal 100% of the post-rake player pool."
			return
	else:
		contest.prize_pool_cents = 0
		contest.prize_rewards = []
	if contest.id.is_empty():
		contest_status.text = "Contest ID required"
		return
	OpsState.save_contest(contest)
	_current_contest_id = contest.id
	contest_status.text = "Saved %s" % contest.id
	contest_id.text = contest.id
	_load_contests()

func _on_contest_delete() -> void:
	if _current_contest_id.is_empty():
		contest_status.text = "Select a contest first"
		return
	OpsState.delete_contest(_current_contest_id)
	contest_status.text = "Deleted %s" % _current_contest_id
	_current_contest_id = ""
	clear_payout_approval_report()
	_load_contests()

func _collect_selected_map_pool() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for idx in contest_map_pool.get_selected_items():
		var map_id: String = str(contest_map_pool.get_item_metadata(idx))
		if not map_id.is_empty():
			ids.append(map_id)
	return ids

func _clear_contest_form() -> void:
	contest_id.text = ""
	contest_name.text = ""
	contest_mode.text = "TIME_PUZZLE"
	contest_start.text = "0"
	contest_end.text = "0"
	contest_entry_type.select(0)
	contest_ante.value = 0
	_set_contest_setup_selection("WEEKLY", "FREE", 0)
	_apply_contest_setup_id("WEEKLY", "FREE", 0)
	contest_map_count.select(1)
	contest_prize_pool.value = 0
	_set_winner_count_selection(1)
	_rebuild_payout_rows(1)
	contest_published.button_pressed = false
	contest_map_pool.deselect_all()
	_refresh_payment_controls()
	clear_payout_approval_report()

func show_payout_approval_report(report: Dictionary) -> void:
	_current_payout_approval_report = report.duplicate(true)
	_refresh_payout_approval_report()

func clear_payout_approval_report() -> void:
	_current_payout_approval_report.clear()
	_refresh_payout_approval_report()

func get_current_payout_approval_report() -> Dictionary:
	return _current_payout_approval_report.duplicate(true)

func get_current_payout_summary() -> Dictionary:
	return _current_payout_summary.duplicate(true)

func request_pending_payout_reports(filters: Dictionary = {}) -> Dictionary:
	request_scheduled_money_closeout_sweep()
	var backend: Node = get_node_or_null("/root/VsHandshake")
	if backend == null or not backend.has_method("list_async_contest_payout_reports"):
		_set_approval_backend_status("Payout backend unavailable.")
		return {"ok": false, "err": "backend_unavailable"}
	var clean_filters: Dictionary = filters.duplicate(true)
	if not clean_filters.has("status") and not clean_filters.has("approval_status"):
		clean_filters["status"] = "pending_approval"
	if not clean_filters.has("sort_desc"):
		clean_filters["sort_desc"] = true
	if not clean_filters.has("limit"):
		clean_filters["limit"] = 1
	var result: Dictionary = backend.call("list_async_contest_payout_reports", clean_filters) as Dictionary
	if not bool(result.get("ok", false)):
		_set_approval_backend_status("Payout report fetch failed: %s" % _result_error(result))
		return result
	var reports: Array = result.get("reports", []) as Array
	if reports.is_empty():
		clear_payout_approval_report()
		_set_approval_backend_status("No pending payout reports.")
		return result
	var report_any: Variant = reports[0]
	if typeof(report_any) != TYPE_DICTIONARY:
		clear_payout_approval_report()
		_set_approval_backend_status("Payout report fetch returned invalid data.")
		return {"ok": false, "err": "invalid_report_payload"}
	show_payout_approval_report(report_any as Dictionary)
	_set_approval_backend_status("Loaded pending payout report %s." % str((report_any as Dictionary).get("report_id", "")))
	return result

func request_scheduled_money_closeout_sweep() -> Dictionary:
	if contest_state == null or not contest_state.has_method("process_scheduled_money_contest_closeouts"):
		return {"ok": false, "err": "contest_state_unavailable"}
	var result: Dictionary = contest_state.call("process_scheduled_money_contest_closeouts") as Dictionary
	if bool(result.get("ok", false)):
		var queued_count: int = maxi(0, int(result.get("queued_count", 0)))
		var skipped_count: int = maxi(0, int(result.get("skipped_count", 0)))
		var failed_count: int = maxi(0, int(result.get("failed_count", 0)))
		if queued_count > 0:
			_set_approval_backend_status("Queued %d closed contest payout report(s)." % queued_count)
		elif failed_count > 0 and skipped_count <= 0:
			_set_approval_backend_status("Closed contest sweep found %d issue(s)." % failed_count)
		return result
	_set_approval_backend_status("Closed contest sweep failed: %s" % _result_error(result))
	return result

func request_selected_contest_payout_report() -> Dictionary:
	var selected_id: String = _current_contest_id.strip_edges()
	if selected_id.is_empty():
		selected_id = contest_id.text.strip_edges() if contest_id != null else ""
	if selected_id.is_empty():
		contest_status.text = "Select a money contest first."
		_set_approval_backend_status(contest_status.text)
		return {"ok": false, "err": "missing_contest_id"}
	if contest_state == null or not contest_state.has_method("request_money_contest_payout_approval"):
		contest_status.text = "Contest state payout approval unavailable."
		_set_approval_backend_status(contest_status.text)
		return {"ok": false, "err": "contest_state_unavailable"}
	var result: Dictionary = contest_state.call("request_money_contest_payout_approval", selected_id, _selected_map_count()) as Dictionary
	if bool(result.get("ok", false)):
		show_payout_approval_report(result)
		var source_label: String = _approval_report_source_label(result)
		contest_status.text = "Built payout report for %s." % selected_id
		_set_approval_backend_status("Built %s report %s." % [source_label, str(result.get("report_id", ""))])
		return result
	var reason: String = _result_error(result)
	if reason == "transport_not_configured" or reason == "backend_unavailable":
		contest_status.text = "Backend unavailable; payout report was not queued."
	else:
		contest_status.text = "Payout report failed: %s" % reason
	_set_approval_backend_status(contest_status.text)
	return result

func request_payout_summary(filters: Dictionary = {}) -> Dictionary:
	var backend: Node = get_node_or_null("/root/VsHandshake")
	if backend == null or not backend.has_method("get_money_payout_summary"):
		_set_payout_report_status("Payout summary backend unavailable.")
		return {"ok": false, "err": "backend_unavailable"}
	var clean_filters: Dictionary = filters.duplicate(true)
	if not clean_filters.has("limit"):
		clean_filters["limit"] = 25
	var result: Dictionary = backend.call("get_money_payout_summary", clean_filters) as Dictionary
	if not bool(result.get("ok", false)):
		if str(result.get("err", result.get("code", ""))).strip_edges() == "transport_not_configured":
			_set_payout_report_status("Payout summary backend unavailable.")
			return result
		_set_payout_report_status("Payout summary fetch failed: %s" % _result_error(result))
		return result
	show_payout_summary(result)
	_set_payout_report_status("Payout report refreshed.")
	return result

func show_payout_summary(summary: Dictionary) -> void:
	_current_payout_summary = summary.duplicate(true)
	_refresh_payout_summary_report()

func clear_payout_summary() -> void:
	_current_payout_summary.clear()
	_refresh_payout_summary_report()

func show_payout_proof(proof: Dictionary) -> void:
	_current_payout_proof = proof.duplicate(true)
	_refresh_payout_proof()

func clear_payout_proof() -> void:
	_current_payout_proof.clear()
	_refresh_payout_proof()

func get_current_payout_proof() -> Dictionary:
	return _current_payout_proof.duplicate(true)

func request_payout_proof(contest_id_filter: String = "") -> Dictionary:
	var target_contest_id: String = contest_id_filter.strip_edges()
	if target_contest_id.is_empty():
		target_contest_id = _selected_proof_contest_id()
	if target_contest_id.is_empty():
		_set_payout_report_status("Payout proof requires a contest id.")
		return {"ok": false, "err": "missing_contest_id"}
	var backend: Node = get_node_or_null("/root/VsHandshake")
	if backend == null or not backend.has_method("get_money_transactions") or not backend.has_method("list_async_contest_payout_reports") or not backend.has_method("get_money_payout_summary"):
		_set_payout_report_status("Payout proof backend unavailable.")
		return {"ok": false, "err": "backend_unavailable"}
	var reports_result: Dictionary = backend.call("list_async_contest_payout_reports", {
		"contest_id": target_contest_id,
		"limit": 1,
		"sort_desc": true
	}) as Dictionary
	if not bool(reports_result.get("ok", false)):
		_set_payout_report_status("Payout proof report fetch failed: %s" % _result_error(reports_result))
		return reports_result
	var transactions_result: Dictionary = backend.call("get_money_transactions", {
		"contest_id": target_contest_id,
		"sort_desc": false
	}) as Dictionary
	if not bool(transactions_result.get("ok", false)):
		_set_payout_report_status("Payout proof transaction fetch failed: %s" % _result_error(transactions_result))
		return transactions_result
	var summary_result: Dictionary = backend.call("get_money_payout_summary", {
		"contest_id": target_contest_id,
		"limit": 1
	}) as Dictionary
	if not bool(summary_result.get("ok", false)):
		_set_payout_report_status("Payout proof summary fetch failed: %s" % _result_error(summary_result))
		return summary_result
	var proof: Dictionary = build_payout_proof_from_backend(target_contest_id, reports_result, transactions_result, summary_result)
	show_payout_proof(proof)
	_set_payout_report_status("Payout proof loaded for %s." % target_contest_id)
	return proof

func build_payout_proof_from_backend(contest_id_value: String, reports_result: Dictionary, transactions_result: Dictionary, summary_result: Dictionary) -> Dictionary:
	var reports: Array = reports_result.get("reports", []) as Array
	var report: Dictionary = {}
	if not reports.is_empty() and typeof(reports[0]) == TYPE_DICTIONARY:
		report = (reports[0] as Dictionary).duplicate(true)
	var transactions: Array = transactions_result.get("transactions", []) as Array
	var payout_transactions: Array[Dictionary] = []
	var rake_transactions: Array[Dictionary] = []
	for tx_any in transactions:
		if typeof(tx_any) != TYPE_DICTIONARY:
			continue
		var tx: Dictionary = (tx_any as Dictionary).duplicate(true)
		var tx_type: String = str(tx.get("transaction_type", "")).strip_edges()
		if tx_type == "async_winner_payout" or tx_type == "winner_payout":
			payout_transactions.append(tx)
		elif tx_type == "async_house_rake" or tx_type == "house_rake":
			rake_transactions.append(tx)
	var proof: Dictionary = {
		"ok": true,
		"type": "money_payout_proof",
		"contest_id": contest_id_value,
		"approval_report": report,
		"summary": summary_result.duplicate(true),
		"payout_transactions": payout_transactions,
		"rake_transactions": rake_transactions,
		"transaction_count": payout_transactions.size() + rake_transactions.size()
	}
	proof["proof_text"] = _compose_payout_proof_text(proof)
	return proof

func _selected_proof_contest_id() -> String:
	var filter_id: String = payout_report_contest_filter.text.strip_edges() if payout_report_contest_filter != null else ""
	if not filter_id.is_empty():
		return filter_id
	if not _current_contest_id.strip_edges().is_empty():
		return _current_contest_id.strip_edges()
	return contest_id.text.strip_edges() if contest_id != null else ""

func _refresh_payout_proof() -> void:
	var has_proof: bool = bool(_current_payout_proof.get("ok", false))
	if payout_proof_text != null:
		payout_proof_text.text = str(_current_payout_proof.get("proof_text", "")) if has_proof else ""
	if payout_proof_summary == null:
		return
	if not has_proof:
		payout_proof_summary.text = "No payout proof loaded."
		return
	var report: Dictionary = _current_payout_proof.get("approval_report", {}) as Dictionary
	var summary: Dictionary = _current_payout_proof.get("summary", {}) as Dictionary
	payout_proof_summary.text = "Proof %s | Approval %s | %s | Paid %s | Rake %s | Transactions %d" % [
		str(_current_payout_proof.get("contest_id", "")),
		str(report.get("report_id", report.get("approval_id", ""))),
		str(report.get("approval_status", "")),
		_format_cents(maxi(0, int(summary.get("paid_out_cents", report.get("payout_total_cents", 0))))),
		_format_cents(maxi(0, int(summary.get("house_rake_cents", report.get("house_rake_cents", 0))))),
		maxi(0, int(_current_payout_proof.get("transaction_count", 0)))
	]

func _compose_payout_proof_text(proof: Dictionary) -> String:
	var report: Dictionary = proof.get("approval_report", {}) as Dictionary
	var summary: Dictionary = proof.get("summary", {}) as Dictionary
	var payout_transactions: Array = proof.get("payout_transactions", []) as Array
	var rake_transactions: Array = proof.get("rake_transactions", []) as Array
	var lines: PackedStringArray = PackedStringArray()
	lines.append("SWARMFRONT MONEY PAYOUT PROOF")
	lines.append("Contest: %s" % str(proof.get("contest_id", "")))
	lines.append("Approval ID: %s" % str(report.get("report_id", report.get("approval_id", ""))))
	lines.append("Approval status: %s" % str(report.get("approval_status", "")))
	lines.append("Approved by: %s" % str(report.get("approved_by", "")))
	lines.append("Approved UTC: %s" % str(report.get("approved_utc", "")))
	lines.append("Generated UTC: %s" % str(report.get("generated_utc", "")))
	lines.append("Updated UTC: %s" % str(report.get("updated_utc", "")))
	lines.append("Total take: %s" % _format_cents(maxi(0, int(report.get("total_take_cents", summary.get("gross_closed_cents", 0))))))
	lines.append("House rake: %s" % _format_cents(maxi(0, int(report.get("house_rake_cents", summary.get("house_rake_cents", 0))))))
	lines.append("Player pool: %s" % _format_cents(maxi(0, int(report.get("player_pool_cents", summary.get("paid_out_cents", 0))))))
	lines.append("Payout total: %s" % _format_cents(maxi(0, int(report.get("payout_total_cents", summary.get("paid_out_cents", 0))))))
	lines.append("")
	lines.append("PAYOUT TRANSACTIONS")
	if payout_transactions.is_empty():
		lines.append("No payout transactions found.")
	for tx_any in payout_transactions:
		if typeof(tx_any) != TYPE_DICTIONARY:
			continue
		var tx: Dictionary = tx_any as Dictionary
		lines.append("%s | %s | placement %d | %s | approval %s | %s" % [
			str(tx.get("transaction_id", "")),
			str(tx.get("account_id", tx.get("player_id", ""))),
			maxi(0, int(tx.get("placement", 0))),
			_format_cents(maxi(0, int(tx.get("amount_cents", 0)))),
			str(tx.get("approval_id", "")),
			str(tx.get("created_utc", ""))
		])
	lines.append("")
	lines.append("RAKE TRANSACTIONS")
	if rake_transactions.is_empty():
		lines.append("No rake transactions found.")
	for tx_any in rake_transactions:
		if typeof(tx_any) != TYPE_DICTIONARY:
			continue
		var tx: Dictionary = tx_any as Dictionary
		lines.append("%s | %s | %s | approval %s | %s" % [
			str(tx.get("transaction_id", "")),
			str(tx.get("account_id", "")),
			_format_cents(maxi(0, int(tx.get("amount_cents", 0)))),
			str(tx.get("approval_id", "")),
			str(tx.get("created_utc", ""))
		])
	return "\n".join(lines)

func _refresh_payout_summary_report() -> void:
	if payout_report_rows != null:
		for child in payout_report_rows.get_children():
			child.queue_free()
	var has_summary: bool = bool(_current_payout_summary.get("ok", false))
	if payout_report_summary != null:
		if has_summary:
			payout_report_summary.text = "Paid %s | Rake %s | Gross %s | Payout tx %d | Contests %d | Pending approvals %d" % [
				_format_cents(maxi(0, int(_current_payout_summary.get("paid_out_cents", 0)))),
				_format_cents(maxi(0, int(_current_payout_summary.get("house_rake_cents", 0)))),
				_format_cents(maxi(0, int(_current_payout_summary.get("gross_closed_cents", 0)))),
				maxi(0, int(_current_payout_summary.get("payout_transaction_count", 0))),
				maxi(0, int(_current_payout_summary.get("contest_count", 0))),
				maxi(0, int(_current_payout_summary.get("pending_approval_reports", 0)))
			]
		else:
			payout_report_summary.text = "No payout summary loaded."
	if not has_summary or payout_report_rows == null:
		return
	var contests: Array = _current_payout_summary.get("contests", []) as Array
	if contests.is_empty():
		var empty: Label = Label.new()
		empty.text = "No posted contest payouts match the current filters."
		payout_report_rows.add_child(empty)
		return
	payout_report_rows.add_child(_build_payout_summary_header_row())
	for contest_any in contests:
		if typeof(contest_any) != TYPE_DICTIONARY:
			continue
		payout_report_rows.add_child(_build_payout_summary_contest_row(contest_any as Dictionary))

func _build_payout_summary_header_row() -> Control:
	return _build_payout_summary_row({
		"contest_id": "Contest",
		"paid_out_label": "Paid out",
		"house_rake_label": "Rake",
		"total_take_label": "Gross",
		"payout_count_label": "Winners",
		"last_paid_utc": "Last paid"
	}, true)

func _build_payout_summary_contest_row(contest: Dictionary) -> Control:
	return _build_payout_summary_row({
		"contest_id": str(contest.get("contest_id", "")),
		"paid_out_label": _format_cents(maxi(0, int(contest.get("paid_out_cents", 0)))),
		"house_rake_label": _format_cents(maxi(0, int(contest.get("house_rake_cents", 0)))),
		"total_take_label": _format_cents(maxi(0, int(contest.get("total_take_cents", 0)))),
		"payout_count_label": str(maxi(0, int(contest.get("payout_count", 0)))),
		"last_paid_utc": str(contest.get("last_paid_utc", ""))
	}, false)

func _build_payout_summary_row(data: Dictionary, header: bool) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var contest_label: Label = _payout_summary_cell(str(data.get("contest_id", "")), 220.0, HORIZONTAL_ALIGNMENT_LEFT, header)
	contest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(contest_label)
	row.add_child(_payout_summary_cell(str(data.get("paid_out_label", "")), 90.0, HORIZONTAL_ALIGNMENT_RIGHT, header))
	row.add_child(_payout_summary_cell(str(data.get("house_rake_label", "")), 90.0, HORIZONTAL_ALIGNMENT_RIGHT, header))
	row.add_child(_payout_summary_cell(str(data.get("total_take_label", "")), 90.0, HORIZONTAL_ALIGNMENT_RIGHT, header))
	row.add_child(_payout_summary_cell(str(data.get("payout_count_label", "")), 70.0, HORIZONTAL_ALIGNMENT_RIGHT, header))
	row.add_child(_payout_summary_cell(str(data.get("last_paid_utc", "")), 150.0, HORIZONTAL_ALIGNMENT_RIGHT, header))
	return row

func _payout_summary_cell(text: String, width: float, align: HorizontalAlignment, header: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0.0)
	label.horizontal_alignment = align
	label.clip_text = true
	if header:
		label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.36, 1.0))
	return label

func _on_refresh_payout_summary_pressed() -> void:
	request_payout_summary(_collect_payout_summary_filters())

func _on_export_payout_summary_pressed() -> void:
	var result: Dictionary = export_current_payout_summary_csv()
	if bool(result.get("ok", false)):
		_set_payout_report_status("Exported payout report: %s" % str(result.get("path", "")))
	else:
		_set_payout_report_status("Payout report export failed: %s" % _result_error(result))

func _on_generate_payout_proof_pressed() -> void:
	request_payout_proof()

func _on_copy_payout_proof_pressed() -> void:
	var result: Dictionary = copy_current_payout_proof()
	if bool(result.get("ok", false)):
		_set_payout_report_status("Copied payout proof.")
	else:
		_set_payout_report_status("Payout proof copy failed: %s" % _result_error(result))

func _on_export_payout_proof_pressed() -> void:
	var result: Dictionary = export_current_payout_proof()
	if bool(result.get("ok", false)):
		_set_payout_report_status("Exported payout proof: %s" % str(result.get("path", "")))
	else:
		_set_payout_report_status("Payout proof export failed: %s" % _result_error(result))

func _collect_payout_summary_filters() -> Dictionary:
	var filters: Dictionary = {"limit": 25}
	var contest_filter: String = payout_report_contest_filter.text.strip_edges() if payout_report_contest_filter != null else ""
	var account_filter: String = payout_report_account_filter.text.strip_edges() if payout_report_account_filter != null else ""
	if not contest_filter.is_empty():
		filters["contest_id"] = contest_filter
	if not account_filter.is_empty():
		filters["account_id"] = account_filter
	return filters

func export_current_payout_summary_csv(path: String = PAYOUT_REPORT_EXPORT_PATH) -> Dictionary:
	if not bool(_current_payout_summary.get("ok", false)):
		return {"ok": false, "err": "missing_payout_summary"}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "err": "export_open_failed", "path": path}
	file.store_line("contest_id,paid_out_cents,house_rake_cents,total_take_cents,payout_count,last_paid_utc,transaction_ids")
	var contests: Array = _current_payout_summary.get("contests", []) as Array
	for contest_any in contests:
		if typeof(contest_any) != TYPE_DICTIONARY:
			continue
		var contest: Dictionary = contest_any as Dictionary
		var cells: PackedStringArray = PackedStringArray([
			_csv_cell(str(contest.get("contest_id", ""))),
			str(maxi(0, int(contest.get("paid_out_cents", 0)))),
			str(maxi(0, int(contest.get("house_rake_cents", 0)))),
			str(maxi(0, int(contest.get("total_take_cents", 0)))),
			str(maxi(0, int(contest.get("payout_count", 0)))),
			_csv_cell(str(contest.get("last_paid_utc", ""))),
			_csv_cell(JSON.stringify(contest.get("transaction_ids", [])))
		])
		file.store_line(",".join(cells))
	file.close()
	return {"ok": true, "path": ProjectSettings.globalize_path(path)}

func copy_current_payout_proof() -> Dictionary:
	if not bool(_current_payout_proof.get("ok", false)):
		return {"ok": false, "err": "missing_payout_proof"}
	var proof_text: String = str(_current_payout_proof.get("proof_text", ""))
	if proof_text.strip_edges().is_empty():
		return {"ok": false, "err": "empty_payout_proof"}
	DisplayServer.clipboard_set(proof_text)
	return {"ok": true, "bytes": proof_text.to_utf8_buffer().size()}

func export_current_payout_proof(path: String = PAYOUT_PROOF_EXPORT_PATH) -> Dictionary:
	if not bool(_current_payout_proof.get("ok", false)):
		return {"ok": false, "err": "missing_payout_proof"}
	var proof_text: String = str(_current_payout_proof.get("proof_text", ""))
	if proof_text.strip_edges().is_empty():
		return {"ok": false, "err": "empty_payout_proof"}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "err": "export_open_failed", "path": path}
	file.store_string(proof_text)
	file.close()
	return {"ok": true, "path": ProjectSettings.globalize_path(path)}

func _refresh_payout_approval_report() -> void:
	var has_report: bool = bool(_current_payout_approval_report.get("ok", false))
	for node in [contest_approval_summary, contest_approval_rows, contest_approver_label, contest_approver_input, contest_approve_payouts]:
		if node == null:
			continue
		node.visible = has_report
	if contest_approval_label != null:
		contest_approval_label.visible = has_report
	if contest_approval_rows != null:
		for child in contest_approval_rows.get_children():
			child.queue_free()
	if not has_report:
		if contest_approval_summary != null:
			contest_approval_summary.text = ""
		if contest_approve_payouts != null:
			contest_approve_payouts.disabled = true
		return
	var approval_status: String = str(_current_payout_approval_report.get("approval_status", "pending_approval"))
	var players_count: int = maxi(0, int(_current_payout_approval_report.get("players_count", 0)))
	var entries_count: int = maxi(0, int(_current_payout_approval_report.get("entries_count", 0)))
	var paid_entries_count: int = maxi(0, int(_current_payout_approval_report.get("paid_entries_count", entries_count)))
	var total_take_cents: int = maxi(0, int(_current_payout_approval_report.get("total_take_cents", 0)))
	var house_rake_cents: int = maxi(0, int(_current_payout_approval_report.get("house_rake_cents", 0)))
	var player_pool_cents: int = maxi(0, int(_current_payout_approval_report.get("player_pool_cents", 0)))
	var payout_count: int = maxi(0, int(_current_payout_approval_report.get("payout_count", 0)))
	var qualified_results_count: int = maxi(0, int(_current_payout_approval_report.get("qualified_results_count", 0)))
	var source_label: String = _approval_report_source_label(_current_payout_approval_report)
	var review: Dictionary = _review_payout_approval_report(_current_payout_approval_report)
	if contest_approval_summary != null:
		var summary_parts: PackedStringArray = PackedStringArray([
			"Report %s" % str(_current_payout_approval_report.get("report_id", "")),
			approval_status,
			"Source %s" % source_label,
			"Players %d" % players_count,
			"Entries %d" % entries_count,
			"Paid entries %d" % paid_entries_count,
			"Total %s" % _format_cents(total_take_cents),
			"Rake %s" % _format_cents(house_rake_cents),
			"Player pool %s" % _format_cents(player_pool_cents),
			"Planned payouts %d" % payout_count
		])
		if qualified_results_count > 0:
			summary_parts.append("Qualified results %d" % qualified_results_count)
		summary_parts.append("Review %s" % ("OK" if bool(review.get("ok", false)) else "Blocked"))
		contest_approval_summary.text = " | ".join(summary_parts)
	if not bool(review.get("ok", false)):
		contest_approval_rows.add_child(_build_approval_section_label("Review blockers"))
		var issues: Array = review.get("issues", []) as Array
		for issue_any in issues:
			contest_approval_rows.add_child(_build_approval_review_row(str(issue_any)))
	else:
		var warnings: Array = review.get("warnings", []) as Array
		if not warnings.is_empty():
			contest_approval_rows.add_child(_build_approval_section_label("Review notes"))
			for warning_any in warnings:
				contest_approval_rows.add_child(_build_approval_review_row(str(warning_any)))
	var planned_payouts: Array = _current_payout_approval_report.get("planned_payouts", []) as Array
	if not planned_payouts.is_empty():
		contest_approval_rows.add_child(_build_approval_section_label("Planned payouts"))
		contest_approval_rows.add_child(_build_approval_payout_header_row())
	for payout_any in planned_payouts:
		if typeof(payout_any) != TYPE_DICTIONARY:
			continue
		var payout: Dictionary = payout_any as Dictionary
		contest_approval_rows.add_child(_build_approval_payout_row(payout))
	var leaderboard_rows: Array = _current_payout_approval_report.get("leaderboard_rows", []) as Array
	if not leaderboard_rows.is_empty():
		contest_approval_rows.add_child(_build_approval_section_label("Qualified leaderboard"))
		contest_approval_rows.add_child(_build_approval_leaderboard_header_row())
	for row_any in leaderboard_rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		contest_approval_rows.add_child(_build_approval_leaderboard_row(row_any as Dictionary))
	if contest_approve_payouts != null:
		contest_approve_payouts.disabled = approval_status != "pending_approval" or not bool(review.get("ok", false))

func _review_payout_approval_report(report: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var warnings: Array[String] = []
	var planned_payouts: Array = report.get("planned_payouts", []) as Array
	if planned_payouts.is_empty():
		issues.append("No planned payout rows.")
	for payout_any in planned_payouts:
		if typeof(payout_any) != TYPE_DICTIONARY:
			issues.append("Invalid payout row payload.")
			continue
		var payout: Dictionary = payout_any as Dictionary
		var placement: int = maxi(0, int(payout.get("placement", 0)))
		if placement <= 0:
			issues.append("Payout row is missing placement.")
		if str(payout.get("player_id", "")).strip_edges().is_empty():
			issues.append("Payout row #%d is missing player id." % placement)
		if maxi(0, int(payout.get("payout_bps", 0))) <= 0:
			issues.append("Payout row #%d is missing payout percentage." % placement)
		if maxi(0, int(payout.get("amount_cents", 0))) <= 0:
			issues.append("Payout row #%d is missing payout amount." % placement)
	var family: String = _approval_report_family(report)
	var source: String = str(report.get("result_source", report.get("closeout_source", ""))).strip_edges()
	var leaderboard_rows: Array = report.get("leaderboard_rows", []) as Array
	var qualified_results_count: int = maxi(0, int(report.get("qualified_results_count", leaderboard_rows.size())))
	if _approval_report_requires_backend_results(report):
		if source != "backend_result_ledger":
			issues.append("%s money closeouts must use backend result ledger source." % family)
		if leaderboard_rows.is_empty():
			issues.append("%s money closeout is missing backend leaderboard rows." % family)
		if qualified_results_count < planned_payouts.size():
			issues.append("Qualified result count is below planned payout count.")
	elif source.is_empty():
		warnings.append("Report source is not set.")
	var payout_total_bps: int = maxi(0, int(report.get("payout_total_bps", 0)))
	if payout_total_bps > 0 and payout_total_bps != BASIS_POINTS_DENOMINATOR:
		issues.append("Payout percentages do not equal 100% of post-rake pool.")
	return {
		"ok": issues.is_empty(),
		"issues": issues,
		"warnings": warnings,
		"contest_family": family
	}

func _approval_report_requires_backend_results(report: Dictionary) -> bool:
	var family: String = _approval_report_family(report)
	return family == "RACE" or family == "MISS_N_OUT"

func _approval_report_family(report: Dictionary) -> String:
	var family: String = str(report.get("contest_family", "")).strip_edges().to_upper()
	if family == "MISS_N_OUT" or family == "RACE":
		return family
	var contest_id_value: String = str(report.get("contest_id", "")).strip_edges().to_upper()
	if contest_id_value.ends_with("_RACE") or contest_id_value.contains("_RACE_"):
		return "RACE"
	if contest_id_value.ends_with("_MISS_N_OUT") or contest_id_value.contains("_MISS_N_OUT_"):
		return "MISS_N_OUT"
	return family

func _approval_report_source_label(report: Dictionary) -> String:
	var source: String = str(report.get("result_source", report.get("closeout_source", "ledger"))).strip_edges()
	if source == "backend_result_ledger":
		return "Backend results"
	if source == "ledger":
		return "Payout ledger"
	return source.replace("_", " ").capitalize()

func _build_approval_section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.36, 1.0))
	return label

func _build_approval_review_row(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _build_approval_payout_header_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_approval_header_cell("Place", 64.0, HORIZONTAL_ALIGNMENT_LEFT))
	var player: Label = _approval_header_cell("Player", 120.0, HORIZONTAL_ALIGNMENT_LEFT)
	player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(player)
	row.add_child(_approval_header_cell("Percent", 90.0, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(_approval_header_cell("Amount", 100.0, HORIZONTAL_ALIGNMENT_LEFT))
	return row

func _build_approval_leaderboard_header_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_approval_header_cell("Rank", 64.0, HORIZONTAL_ALIGNMENT_LEFT))
	var player: Label = _approval_header_cell("Player", 120.0, HORIZONTAL_ALIGNMENT_LEFT)
	player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(player)
	row.add_child(_approval_header_cell("Result", 260.0, HORIZONTAL_ALIGNMENT_RIGHT))
	return row

func _approval_header_cell(text: String, width: float, align: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0.0)
	label.horizontal_alignment = align
	label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.36, 1.0))
	return label

func _build_approval_leaderboard_row(row_data: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rank: int = maxi(1, int(row_data.get("rank", row_data.get("placement", 0))))
	var rank_label: Label = Label.new()
	rank_label.custom_minimum_size = Vector2(64.0, 0.0)
	rank_label.text = "#%d" % rank
	row.add_child(rank_label)
	var player_label: Label = Label.new()
	player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_label.clip_text = true
	player_label.text = str(row_data.get("player_id", ""))
	row.add_child(player_label)
	var metric_label: Label = Label.new()
	metric_label.custom_minimum_size = Vector2(260.0, 0.0)
	metric_label.text = _approval_leaderboard_metric_label(row_data)
	metric_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metric_label.clip_text = true
	row.add_child(metric_label)
	return row

func _approval_leaderboard_metric_label(row_data: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if row_data.has("aggregate_ms"):
		parts.append("Total %s" % _format_elapsed_ms(maxi(0, int(row_data.get("aggregate_ms", 0)))))
	if row_data.has("completed_maps"):
		parts.append("Maps %d" % maxi(0, int(row_data.get("completed_maps", 0))))
	if row_data.has("placement"):
		parts.append("Place %d" % maxi(1, int(row_data.get("placement", 0))))
	if row_data.has("eliminated_round"):
		parts.append("Round %d" % maxi(0, int(row_data.get("eliminated_round", 0))))
	if row_data.has("time_ms"):
		parts.append("Time %s" % _format_elapsed_ms(maxi(0, int(row_data.get("time_ms", 0)))))
	if row_data.has("score"):
		parts.append("Score %d" % int(row_data.get("score", 0)))
	if parts.is_empty():
		return str(row_data.get("result_status", "submitted"))
	return " | ".join(parts)

func _format_elapsed_ms(ms: int) -> String:
	var safe_ms: int = maxi(0, ms)
	var minutes: int = safe_ms / 60000
	var seconds: int = (safe_ms % 60000) / 1000
	var millis: int = safe_ms % 1000
	if minutes > 0:
		return "%d:%02d.%03d" % [minutes, seconds, millis]
	return "%d.%03ds" % [seconds, millis]

func _build_approval_payout_row(payout: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var placement_label: Label = Label.new()
	placement_label.custom_minimum_size = Vector2(64.0, 0.0)
	placement_label.text = "#%d" % maxi(1, int(payout.get("placement", 0)))
	row.add_child(placement_label)
	var player_label: Label = Label.new()
	player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_label.text = str(payout.get("player_id", ""))
	row.add_child(player_label)
	var percent_label: Label = Label.new()
	percent_label.custom_minimum_size = Vector2(90.0, 0.0)
	percent_label.text = "%.1f%%" % (float(maxi(0, int(payout.get("payout_bps", 0)))) / 100.0)
	row.add_child(percent_label)
	var amount_label: Label = Label.new()
	amount_label.custom_minimum_size = Vector2(100.0, 0.0)
	amount_label.text = _format_cents(maxi(0, int(payout.get("amount_cents", 0))))
	row.add_child(amount_label)
	return row

func _on_approve_payouts_pressed() -> void:
	if _current_payout_approval_report.is_empty():
		contest_status.text = "No payout approval report loaded."
		return
	var review: Dictionary = _review_payout_approval_report(_current_payout_approval_report)
	if not bool(review.get("ok", false)):
		var issues: Array = review.get("issues", []) as Array
		contest_status.text = "Payout approval blocked: %s" % (str(issues[0]) if not issues.is_empty() else "review_failed")
		_set_approval_backend_status(contest_status.text)
		_refresh_payout_approval_report()
		return
	var approver_id: String = contest_approver_input.text.strip_edges()
	if approver_id.is_empty():
		contest_status.text = "Approver required."
		return
	contest_payout_approval_requested.emit(_current_payout_approval_report.duplicate(true), approver_id)
	var result: Dictionary = _approve_payout_report_backend(_current_payout_approval_report.duplicate(true), approver_id)
	if bool(result.get("ok", false)):
		var approved_report_any: Variant = result.get("approval_report", {})
		if typeof(approved_report_any) == TYPE_DICTIONARY:
			show_payout_approval_report(approved_report_any as Dictionary)
			_mark_current_contest_payout_approved(approved_report_any as Dictionary)
		else:
			_current_payout_approval_report["approval_status"] = "approved"
			_refresh_payout_approval_report()
			_mark_current_contest_payout_approved(_current_payout_approval_report)
		contest_status.text = "Payout approval posted for %s." % str(_current_payout_approval_report.get("report_id", ""))
		_set_approval_backend_status("Approval posted. Transactions: %s" % str(result.get("transaction_ids", [])))
		return
	if str(result.get("err", "")) == "backend_unavailable" or str(result.get("err", "")) == "transport_not_configured":
		contest_status.text = "Payout approval requested for %s." % str(_current_payout_approval_report.get("report_id", ""))
		_set_approval_backend_status("Backend not configured; approval intent emitted only.")
		return
	contest_status.text = "Payout approval failed: %s" % _result_error(result)
	_set_approval_backend_status(contest_status.text)

func _on_refresh_payout_reports_pressed() -> void:
	request_pending_payout_reports()

func _on_build_payout_report_pressed() -> void:
	request_selected_contest_payout_report()

func _approve_payout_report_backend(report: Dictionary, approver_id: String) -> Dictionary:
	var backend: Node = get_node_or_null("/root/VsHandshake")
	if backend == null or not backend.has_method("approve_async_contest_payout_report"):
		return {"ok": false, "err": "backend_unavailable"}
	var report_id: String = str(report.get("report_id", "")).strip_edges()
	var key: String = "approve:%s:%s" % [report_id, approver_id]
	return backend.call("approve_async_contest_payout_report", report, approver_id, key) as Dictionary

func _mark_current_contest_payout_approved(report: Dictionary) -> void:
	if contest_state == null or not contest_state.has_method("mark_money_contest_payout_approved"):
		return
	var approved_contest_id: String = str(report.get("contest_id", _current_contest_id)).strip_edges()
	if approved_contest_id.is_empty():
		return
	contest_state.call("mark_money_contest_payout_approved", approved_contest_id, report)

func _set_approval_backend_status(text: String) -> void:
	if contest_approval_backend_status != null:
		contest_approval_backend_status.text = text

func _set_payout_report_status(text: String) -> void:
	if payout_report_status != null:
		payout_report_status.text = text

func _csv_cell(value: String) -> String:
	var escaped: String = value.replace("\"", "\"\"")
	if escaped.contains(",") or escaped.contains("\"") or escaped.contains("\n"):
		return "\"%s\"" % escaped
	return escaped

func _result_error(result: Dictionary) -> String:
	var err: String = str(result.get("err", result.get("code", ""))).strip_edges()
	if err.is_empty():
		err = str(result.get("message", "unknown_error")).strip_edges()
	return err if not err.is_empty() else "unknown_error"

func _format_cents(amount_cents: int) -> String:
	var safe_cents: int = maxi(0, amount_cents)
	return "$%.2f" % (float(safe_cents) / 100.0)

func refresh_crucible_config() -> Dictionary:
	var state: Node = get_node_or_null("/root/CrucibleState")
	if state == null or not state.has_method("get_config_snapshot"):
		_set_crucible_status("CrucibleState unavailable.")
		return {"ok": false, "err": "crucible_state_unavailable"}
	var snapshot: Dictionary = state.call("get_config_snapshot") as Dictionary
	_apply_crucible_config_to_form(snapshot)
	_set_crucible_status("Loaded Crucible config v%d (%s)." % [
		maxi(1, int(snapshot.get("config_version", 1))),
		str(snapshot.get("config_hash", "")).substr(0, 8)
	])
	return {"ok": true, "config": snapshot}

func _configure_crucible_rounding_selector() -> void:
	if crucible_rounding_mode == null:
		return
	crucible_rounding_mode.clear()
	for mode in ["FLOOR", "NEAREST", "CEIL"]:
		var idx: int = crucible_rounding_mode.item_count
		crucible_rounding_mode.add_item(mode.capitalize())
		crucible_rounding_mode.set_item_metadata(idx, mode)
	crucible_rounding_mode.select(0)

func _configure_crucible_review_selector() -> void:
	if crucible_review_action == null:
		return
	crucible_review_action.clear()
	crucible_review_action.add_item("Refund")
	crucible_review_action.set_item_metadata(0, "refund")
	crucible_review_action.add_item("Approve")
	crucible_review_action.set_item_metadata(1, "approve")
	crucible_review_action.select(0)

func _apply_crucible_config_to_form(config: Dictionary) -> void:
	crucible_enabled.button_pressed = bool(config.get("enabled", true))
	crucible_queue_enabled.button_pressed = bool(config.get("queue_enabled", true))
	crucible_wagering_enabled.button_pressed = bool(config.get("wagering_enabled", true))
	crucible_ads_enabled.button_pressed = bool(config.get("ads_enabled", true))
	crucible_capacity_cap_enabled.button_pressed = bool(config.get("capacity_cap_enabled", true))
	crucible_settlement_enabled.button_pressed = bool(config.get("settlement_enabled", true))
	crucible_earn_buttons_enabled.button_pressed = bool(config.get("earn_path_buttons_enabled", true))
	crucible_server_settlement_required.button_pressed = bool(config.get("server_authoritative_settlement_required", false))
	crucible_local_dev_settlement_enabled.button_pressed = bool(config.get("local_dev_settlement_enabled", true))
	crucible_launch_grant_enabled.button_pressed = bool(config.get("launch_grant_enabled", false))
	crucible_config_version.value = maxi(1, int(config.get("config_version", 1)))
	crucible_stake_bps.value = clampi(int(config.get("stake_bps", 500)), 0, BASIS_POINTS_DENOMINATOR)
	crucible_burn_bps.value = clampi(int(config.get("burn_bps", 1000)), 0, BASIS_POINTS_DENOMINATOR)
	crucible_minimum_stake.value = maxi(1, int(config.get("minimum_stake_millis", 1000)))
	crucible_capacity_max.value = maxi(0, int(config.get("capacity_max", 100)))
	crucible_reserved_slots.value = maxi(0, int(config.get("reserved_slots", 0)))
	crucible_starting_wax.value = maxi(0, int(config.get("starting_crucible_wax_millis", 0)))
	crucible_launch_grant_millis.value = maxi(0, int(config.get("launch_grant_millis", 0)))
	crucible_standard_win_earn.value = maxi(0, int(config.get("standard_pvp_win_earn_millis", 250)))
	crucible_standard_loss_earn.value = maxi(0, int(config.get("standard_pvp_loss_earn_millis", 100)))
	crucible_tournament_earn.value = maxi(0, int(config.get("tournament_placement_earn_millis", 1000)))
	crucible_challenge_earn.value = maxi(0, int(config.get("challenge_earn_millis", 500)))
	crucible_event_earn.value = maxi(0, int(config.get("event_earn_millis", 500)))
	_set_crucible_rounding_mode(str(config.get("rounding_mode", "FLOOR")))

func _collect_crucible_config_patch() -> Dictionary:
	return {
		"enabled": crucible_enabled.button_pressed,
		"queue_enabled": crucible_queue_enabled.button_pressed,
		"wagering_enabled": crucible_wagering_enabled.button_pressed,
		"ads_enabled": crucible_ads_enabled.button_pressed,
		"capacity_cap_enabled": crucible_capacity_cap_enabled.button_pressed,
		"settlement_enabled": crucible_settlement_enabled.button_pressed,
		"earn_path_buttons_enabled": crucible_earn_buttons_enabled.button_pressed,
		"server_authoritative_settlement_required": crucible_server_settlement_required.button_pressed,
		"local_dev_settlement_enabled": crucible_local_dev_settlement_enabled.button_pressed,
		"launch_grant_enabled": crucible_launch_grant_enabled.button_pressed,
		"config_version": maxi(1, int(crucible_config_version.value)),
		"stake_bps": clampi(int(crucible_stake_bps.value), 0, BASIS_POINTS_DENOMINATOR),
		"burn_bps": clampi(int(crucible_burn_bps.value), 0, BASIS_POINTS_DENOMINATOR),
		"minimum_stake_millis": maxi(1, int(crucible_minimum_stake.value)),
		"capacity_max": maxi(0, int(crucible_capacity_max.value)),
		"reserved_slots": maxi(0, int(crucible_reserved_slots.value)),
		"starting_crucible_wax_millis": maxi(0, int(crucible_starting_wax.value)),
		"launch_grant_millis": maxi(0, int(crucible_launch_grant_millis.value)),
		"standard_pvp_win_earn_millis": maxi(0, int(crucible_standard_win_earn.value)),
		"standard_pvp_loss_earn_millis": maxi(0, int(crucible_standard_loss_earn.value)),
		"tournament_placement_earn_millis": maxi(0, int(crucible_tournament_earn.value)),
		"challenge_earn_millis": maxi(0, int(crucible_challenge_earn.value)),
		"event_earn_millis": maxi(0, int(crucible_event_earn.value)),
		"rounding_mode": _selected_crucible_rounding_mode()
	}

func _on_crucible_refresh_pressed() -> void:
	refresh_crucible_config()

func _on_crucible_save_pressed() -> void:
	var state: Node = get_node_or_null("/root/CrucibleState")
	if state == null or not state.has_method("intent_update_config"):
		_set_crucible_status("CrucibleState unavailable.")
		return
	var patch: Dictionary = _collect_crucible_config_patch()
	var result: Dictionary = state.call("intent_update_config", patch, "ops_console") as Dictionary
	if bool(result.get("ok", false)):
		var config: Dictionary = result.get("config", patch) as Dictionary
		_apply_crucible_config_to_form(config)
		_set_crucible_status("Saved Crucible config v%d (%s)." % [
			maxi(1, int(config.get("config_version", patch.get("config_version", 1)))),
			str(config.get("config_hash", "")).substr(0, 8)
		])
		return
	_set_crucible_status("Crucible config save failed: %s" % _result_error(result))

func _on_crucible_preview_pressed() -> void:
	var state: Node = get_node_or_null("/root/CrucibleState")
	if state == null or not state.has_method("preview_entry_status"):
		_set_crucible_preview_status("CrucibleState unavailable.")
		return
	var player_id: String = crucible_preview_player.text.strip_edges()
	if player_id.is_empty():
		_set_crucible_preview_status("Player id required.")
		return
	if state.has_method("intent_set_balance_millis"):
		state.call("intent_set_balance_millis", player_id, maxi(0, int(crucible_preview_balance.value)))
	var active_count: int = maxi(0, int(crucible_preview_active_count.value))
	var result: Dictionary = state.call("preview_entry_status", player_id, active_count, false) as Dictionary
	if bool(result.get("ok", false)):
		_set_crucible_preview_status("Entry allowed | balance %d | active %d." % [
			maxi(0, int(result.get("balance_millis", int(crucible_preview_balance.value)))),
			active_count
		])
		return
	var code: String = str(result.get("code", result.get("err", ""))).strip_edges()
	if code == "capacity":
		_set_crucible_preview_status("Entry blocked: capacity full.")
	elif code == "no_wax":
		_set_crucible_preview_status("Entry blocked: no Wax.")
	elif code == "queue_disabled":
		_set_crucible_preview_status("Entry blocked: queue disabled.")
	else:
		_set_crucible_preview_status("Entry blocked: %s" % _result_error(result))
	refresh_crucible_ledger()

func refresh_crucible_ledger() -> Dictionary:
	var state: Node = get_node_or_null("/root/CrucibleState")
	if state == null or not state.has_method("get_snapshot"):
		_set_crucible_ledger_summary("CrucibleState unavailable.")
		_clear_children(crucible_audit_rows)
		_clear_children(crucible_ledger_rows)
		return {"ok": false, "err": "crucible_state_unavailable"}
	var snapshot: Dictionary = state.call("get_snapshot") as Dictionary
	_render_crucible_ledger_snapshot(snapshot)
	return {"ok": true, "snapshot": snapshot}

func _on_crucible_ledger_refresh_pressed() -> void:
	refresh_crucible_ledger()

func _on_crucible_ledger_filter_changed(_new_text: String) -> void:
	if not _current_crucible_ledger_snapshot.is_empty():
		_render_crucible_ledger_snapshot(_current_crucible_ledger_snapshot)

func _on_crucible_ledger_export_pressed() -> void:
	var result: Dictionary = export_current_crucible_ledger_csv()
	if bool(result.get("ok", false)):
		_set_crucible_status("Exported Crucible ledger: %s." % str(result.get("path", "")))
		return
	_set_crucible_status("Crucible ledger export failed: %s" % _result_error(result))

func _on_crucible_review_resolve_pressed() -> void:
	var state: Node = get_node_or_null("/root/CrucibleState")
	if state == null or not state.has_method("intent_resolve_review"):
		_set_crucible_status("Crucible review resolver unavailable.")
		return
	var match_id: String = crucible_review_match.text.strip_edges() if crucible_review_match != null else ""
	if match_id.is_empty():
		_set_crucible_status("Held match id required.")
		return
	var action: String = _selected_crucible_review_action()
	var result: Dictionary = state.call("intent_resolve_review", match_id, action, "ops_console", {}) as Dictionary
	if bool(result.get("ok", false)):
		_set_crucible_status("Resolved Crucible review %s with %s." % [match_id, action])
		refresh_crucible_ledger()
		return
	_set_crucible_status("Crucible review failed: %s" % _result_error(result))

func _render_crucible_ledger_snapshot(snapshot: Dictionary) -> void:
	_current_crucible_ledger_snapshot = snapshot.duplicate(true)
	var escrows: Dictionary = snapshot.get("escrows_by_id", {}) as Dictionary
	var settlements: Dictionary = snapshot.get("settlements_by_match_id", {}) as Dictionary
	var review_records: Dictionary = snapshot.get("review_records_by_match_id", {}) as Dictionary
	var ledger_entries: Array = snapshot.get("ledger_entries", []) as Array
	var audit_records: Array = snapshot.get("audit_records", []) as Array
	var anti_collusion_observations: Array = snapshot.get("anti_collusion_observations", []) as Array
	var filtered_ledger: Array[Dictionary] = _filter_dictionaries(ledger_entries, _crucible_filter_text())
	var filtered_audit: Array[Dictionary] = _filter_dictionaries(audit_records, _crucible_filter_text())
	_current_crucible_filtered_ledger_entries = filtered_ledger.duplicate(true)
	_current_crucible_filtered_audit_records = filtered_audit.duplicate(true)
	var burn_total: int = 0
	var payout_total: int = 0
	var refund_total: int = 0
	for entry_any in ledger_entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		match str(entry.get("entry_type", "")):
			"BURN":
				burn_total += absi(int(entry.get("amount_millis", 0)))
			"WINNER_PAYOUT":
				payout_total += maxi(0, int(entry.get("amount_millis", 0)))
			"ESCROW_REFUND":
				refund_total += maxi(0, int(entry.get("amount_millis", 0)))
	_set_crucible_ledger_summary("Escrows %d | Settlements %d | Held %d | Ledger entries %d/%d | Audit records %d/%d | Burn %d | Payout %d | Refund %d" % [
		escrows.size(),
		settlements.size(),
		review_records.size(),
		filtered_ledger.size(),
		ledger_entries.size(),
		filtered_audit.size(),
		audit_records.size(),
		burn_total,
		payout_total,
		refund_total
	])
	_set_crucible_collusion_summary(_build_crucible_collusion_summary(anti_collusion_observations, audit_records))
	_clear_children(crucible_audit_rows)
	_clear_children(crucible_ledger_rows)
	if crucible_audit_rows != null:
		crucible_audit_rows.add_child(_crucible_section_label("Recent audit"))
		for record in _tail_dictionaries(filtered_audit, 8):
			crucible_audit_rows.add_child(_build_crucible_audit_row(record))
	if crucible_ledger_rows != null:
		crucible_ledger_rows.add_child(_crucible_section_label("Recent ledger"))
		for entry in _tail_dictionaries(filtered_ledger, 10):
			crucible_ledger_rows.add_child(_build_crucible_ledger_row(entry))

func export_current_crucible_ledger_csv(path: String = CRUCIBLE_LEDGER_EXPORT_PATH) -> Dictionary:
	if _current_crucible_ledger_snapshot.is_empty():
		return {"ok": false, "err": "no_crucible_ledger_snapshot"}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "err": "export_open_failed", "path": path}
	file.store_line("kind,match_id,player_id,status,type,amount_millis,result_source,winner_id,loser_id,created_at,id")
	for entry in _current_crucible_filtered_ledger_entries:
		file.store_line(",".join([
			_csv_cell("ledger"),
			_csv_cell(str(entry.get("match_id", ""))),
			_csv_cell(str(entry.get("player_id", ""))),
			_csv_cell(""),
			_csv_cell(str(entry.get("entry_type", ""))),
			_csv_cell(str(int(entry.get("amount_millis", 0)))),
			_csv_cell(""),
			_csv_cell(""),
			_csv_cell(""),
			_csv_cell(str(entry.get("created_at", ""))),
			_csv_cell(str(entry.get("transaction_id", entry.get("entry_id", ""))))
		]))
	for record in _current_crucible_filtered_audit_records:
		file.store_line(",".join([
			_csv_cell("audit"),
			_csv_cell(str(record.get("match_id", ""))),
			_csv_cell(""),
			_csv_cell(str(record.get("settlement_status", record.get("type", "")))),
			_csv_cell(str(record.get("review_status", ""))),
			_csv_cell(""),
			_csv_cell(str(record.get("result_source", ""))),
			_csv_cell(str(record.get("winner_id", ""))),
			_csv_cell(str(record.get("loser_id", ""))),
			_csv_cell(str(record.get("created_at", ""))),
			_csv_cell(str(record.get("settlement_id", "")))
		]))
	file.close()
	return {"ok": true, "path": ProjectSettings.globalize_path(path)}

func _build_crucible_audit_row(record: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	row.add_child(_crucible_cell(str(record.get("settlement_status", record.get("type", ""))), 120.0))
	row.add_child(_crucible_cell(str(record.get("match_id", "")), 180.0))
	row.add_child(_crucible_cell("winner %s" % str(record.get("winner_id", "")), 140.0))
	row.add_child(_crucible_cell("burn %d" % maxi(0, int(record.get("burn", 0))), 90.0))
	row.add_child(_crucible_cell(str(record.get("result_source", "")), 150.0))
	return row

func _build_crucible_ledger_row(entry: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	row.add_child(_crucible_cell(str(entry.get("entry_type", "")), 130.0))
	row.add_child(_crucible_cell(str(entry.get("match_id", "")), 180.0))
	row.add_child(_crucible_cell(str(entry.get("player_id", "")), 150.0))
	row.add_child(_crucible_cell(str(int(entry.get("amount_millis", 0))), 100.0))
	row.add_child(_crucible_cell(str(entry.get("transaction_id", entry.get("entry_id", ""))), 180.0))
	return row

func _build_crucible_collusion_summary(observations: Array, audit_records: Array) -> String:
	var repeated: int = 0
	var win_trading: int = 0
	var same_device: int = 0
	var same_ip: int = 0
	var suspicious_forfeits: int = 0
	var high_stakes: int = 0
	var pair_counts: Dictionary = {}
	for observation_any in observations:
		if typeof(observation_any) != TYPE_DICTIONARY:
			continue
		var observation: Dictionary = observation_any as Dictionary
		if bool(observation.get("repeated_same_opponent", false)):
			repeated += 1
		if bool(observation.get("unusual_win_trading", false)):
			win_trading += 1
		if bool(observation.get("same_device_cluster", false)):
			same_device += 1
		if bool(observation.get("same_ip_pattern", false)):
			same_ip += 1
		if bool(observation.get("suspicious_forfeit", false)):
			suspicious_forfeits += 1
		if bool(observation.get("high_stakes_repeated_transfer", false)) or int(observation.get("stake_each", 0)) >= 10000:
			high_stakes += 1
		var a: String = str(observation.get("player_a_id", "")).strip_edges()
		var b: String = str(observation.get("player_b_id", "")).strip_edges()
		if not a.is_empty() and not b.is_empty():
			var pair: Array[String] = [a, b]
			pair.sort()
			var pair_key: String = "%s|%s" % [pair[0], pair[1]]
			pair_counts[pair_key] = int(pair_counts.get(pair_key, 0)) + 1
	for count_any in pair_counts.values():
		if int(count_any) > 1:
			repeated += int(count_any) - 1
	for record_any in audit_records:
		if typeof(record_any) != TYPE_DICTIONARY:
			continue
		var reason: String = str((record_any as Dictionary).get("reason", "")).strip_edges().to_lower()
		if reason in ["voluntary_quit", "forfeit", "disconnect_after_start"]:
			suspicious_forfeits += 1
	var total_flags: int = repeated + win_trading + same_device + same_ip + suspicious_forfeits + high_stakes
	return "Anti-collusion: observations %d | flags %d | repeated opponents %d | win trading %d | same device %d | same IP %d | suspicious forfeits %d | high stakes %d" % [
		observations.size(),
		total_flags,
		repeated,
		win_trading,
		same_device,
		same_ip,
		suspicious_forfeits,
		high_stakes
	]

func _crucible_section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.36, 1.0))
	return label

func _crucible_cell(text: String, width: float) -> Label:
	var label: Label = Label.new()
	label.custom_minimum_size = Vector2(width, 0.0)
	label.clip_text = true
	label.text = text
	return label

func _tail_dictionaries(rows: Array, limit: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start: int = maxi(0, rows.size() - maxi(1, limit))
	for i in range(start, rows.size()):
		var row_any: Variant = rows[i]
		if typeof(row_any) == TYPE_DICTIONARY:
			out.append((row_any as Dictionary).duplicate(true))
	return out

func _filter_dictionaries(rows: Array, filter_text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row_any in rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = (row_any as Dictionary).duplicate(true)
		if filter_text.is_empty() or _dictionary_matches_filter(row, filter_text):
			out.append(row)
	return out

func _dictionary_matches_filter(row: Dictionary, filter_text: String) -> bool:
	var needle: String = filter_text.strip_edges().to_lower()
	if needle.is_empty():
		return true
	for value in row.values():
		if str(value).to_lower().contains(needle):
			return true
	return false

func _crucible_filter_text() -> String:
	return crucible_ledger_filter.text.strip_edges().to_lower() if crucible_ledger_filter != null else ""

func _selected_crucible_review_action() -> String:
	if crucible_review_action == null:
		return "refund"
	var idx: int = crucible_review_action.selected
	if idx < 0:
		return "refund"
	var metadata: Variant = crucible_review_action.get_item_metadata(idx)
	return str(metadata).strip_edges().to_lower() if metadata != null else "refund"

func _clear_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()

func _selected_crucible_rounding_mode() -> String:
	if crucible_rounding_mode == null or crucible_rounding_mode.item_count <= 0:
		return "FLOOR"
	var selected: int = crucible_rounding_mode.selected
	if selected < 0 or selected >= crucible_rounding_mode.item_count:
		return "FLOOR"
	return str(crucible_rounding_mode.get_item_metadata(selected)).strip_edges().to_upper()

func _set_crucible_rounding_mode(mode: String) -> void:
	var target: String = mode.strip_edges().to_upper()
	for i in range(crucible_rounding_mode.item_count):
		if str(crucible_rounding_mode.get_item_metadata(i)).strip_edges().to_upper() == target:
			crucible_rounding_mode.select(i)
			return
	crucible_rounding_mode.select(0)

func _set_crucible_status(text: String) -> void:
	if crucible_status != null:
		crucible_status.text = text

func _set_crucible_preview_status(text: String) -> void:
	if crucible_preview_status != null:
		crucible_preview_status.text = text

func _set_crucible_ledger_summary(text: String) -> void:
	if crucible_ledger_summary != null:
		crucible_ledger_summary.text = text

func _set_crucible_collusion_summary(text: String) -> void:
	if crucible_collusion_summary != null:
		crucible_collusion_summary.text = text

func _on_map_selected(index: int) -> void:
	var map_id_meta: Variant = map_list.get_item_metadata(index)
	if map_id_meta == null:
		return
	var map_id_str: String = str(map_id_meta)
	var map_def: MapDef = OpsState.maps.get(map_id_str)
	if map_def == null:
		return
	_current_map_id = map_def.id
	map_id.text = map_def.id
	map_name.text = map_def.display_name
	map_scene_path.text = map_def.map_scene_path
	map_preview_path.text = map_def.preview_path
	map_in_pool.button_pressed = map_def.in_pool
	if not map_def.preview_path.is_empty() and ResourceLoader.exists(map_def.preview_path):
		map_preview.texture = load(map_def.preview_path)
	else:
		map_preview.texture = null
	map_status.text = "Loaded %s" % map_def.id

func _on_map_in_pool_toggled(pressed: bool) -> void:
	if _current_map_id.is_empty():
		return
	var map_def: MapDef = OpsState.maps.get(_current_map_id)
	if map_def == null:
		return
	map_def.in_pool = pressed
	OpsState.save_map(map_def)
	map_status.text = "Saved %s" % map_def.id

func _on_map_load_test() -> void:
	if _current_map_id.is_empty():
		map_status.text = "Select a map first"
		return
	OpsState.request_map_test(_current_map_id)
	map_status.text = "Load requested: %s" % _current_map_id

func _clear_map_form() -> void:
	_current_map_id = ""
	map_id.text = ""
	map_name.text = ""
	map_scene_path.text = ""
	map_preview_path.text = ""
	map_in_pool.button_pressed = false
	map_preview.texture = null

func _set_scope_selection(scope: String) -> void:
	var scope_upper: String = scope.to_upper()
	for i in range(contest_entry_type.item_count):
		if contest_entry_type.get_item_text(i) == scope_upper:
			contest_entry_type.select(i)
			return
	contest_entry_type.select(0)

func _selected_scope() -> String:
	if contest_entry_type == null or contest_entry_type.item_count <= 0:
		return "WEEKLY"
	var selected: int = contest_entry_type.selected
	if selected < 0 or selected >= contest_entry_type.item_count:
		return "WEEKLY"
	return contest_entry_type.get_item_text(selected).strip_edges().to_upper()

func _set_map_count_selection(count: int) -> void:
	var target: int = 3 if count <= 3 else 5
	for i in range(contest_map_count.item_count):
		if int(contest_map_count.get_item_metadata(i)) == target:
			contest_map_count.select(i)
			return
	contest_map_count.select(1)

func _selected_map_count() -> int:
	if contest_map_count == null or contest_map_count.item_count <= 0:
		return 5
	var selected: int = contest_map_count.selected
	if selected < 0 or selected >= contest_map_count.item_count:
		return 5
	return clampi(int(contest_map_count.get_item_metadata(selected)), 3, 5)

func _trim_map_ids_to_count(map_ids: PackedStringArray, count: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var target: int = _nearest_supported_map_count(count)
	for map_id_any in map_ids:
		if out.size() >= target:
			break
		var map_id: String = str(map_id_any).strip_edges()
		if map_id.is_empty():
			continue
		out.append(map_id)
	return out

func _nearest_supported_map_count(count: int) -> int:
	return 3 if count <= 3 else 5

func _configure_contest_setup_selector() -> void:
	contest_setup_select.clear()
	for scope in CONTEST_SCHEDULED_SCOPES:
		for family in CONTEST_GAME_FAMILIES:
			_add_contest_setup_option(
				"Free %s %s" % [_scope_label(scope), str(family.get("label", ""))],
				scope,
				"FREE",
				0,
				family,
				"SCHEDULED"
			)
	for scope in CONTEST_SCHEDULED_SCOPES:
		for family in CONTEST_GAME_FAMILIES:
			var family_id: String = str(family.get("family", "")).strip_edges().to_upper()
			if not MONEY_SCHEDULED_CONTEST_FAMILIES.has(family_id):
				continue
			for denomination in _money_denominations_for_family(family_id, "SCHEDULED"):
				_add_contest_setup_option(
					"Money %s %s $%d" % [_scope_label(scope), str(family.get("label", "")), denomination],
					scope,
					"USD",
					denomination,
					family,
					"SCHEDULED"
				)
	for family_id in SIT_AND_GO_CONTEST_FAMILIES:
		var sit_family: Dictionary = _family_metadata(family_id)
		_add_contest_setup_option("Free %s sit-and-go" % str(sit_family.get("label", "")).to_lower(), "EVENT", "FREE", 0, sit_family, "SIT_AND_GO")
		for denomination in _money_denominations_for_family(family_id, "SIT_AND_GO"):
			_add_contest_setup_option("Money %s sit-and-go $%d" % [str(sit_family.get("label", "")).to_lower(), denomination], "EVENT", "USD", denomination, sit_family, "SIT_AND_GO")
	contest_setup_select.select(0)

func _add_contest_setup_option(label: String, scope: String, currency: String, price: int, family: Dictionary = {}, schedule_kind: String = "SCHEDULED") -> void:
	var family_id: String = str(family.get("family", "STAGE_RACE")).strip_edges().to_upper()
	var mode_id: String = str(family.get("mode", family_id)).strip_edges().to_upper()
	var pool_type: String = "MONEY" if price > 0 else "FREE"
	var idx: int = contest_setup_select.item_count
	contest_setup_select.add_item(label)
	contest_setup_select.set_item_metadata(idx, {
		"scope": scope.strip_edges().to_upper(),
		"currency": currency.strip_edges().to_upper(),
		"price": maxi(0, price),
		"pool_type": pool_type,
		"family": family_id,
		"mode": mode_id,
		"schedule_kind": schedule_kind.strip_edges().to_upper(),
		"map_count": maxi(3, int(family.get("map_count", 5))),
		"min_players": maxi(0, int(family.get("min_players", 0))),
		"max_players": maxi(0, int(family.get("max_players", 0)))
	})

func _family_metadata(family_id: String) -> Dictionary:
	var clean: String = family_id.strip_edges().to_upper()
	for family in CONTEST_GAME_FAMILIES:
		if str(family.get("family", "")).strip_edges().to_upper() == clean:
			return family.duplicate(true)
	return CONTEST_GAME_FAMILIES[0].duplicate(true)

func _scope_label(scope: String) -> String:
	return scope.strip_edges().to_lower().capitalize()

func _money_denominations() -> Array[int]:
	var found: Dictionary = {}
	if OpsState != null:
		OpsState.load_contests()
		for contest_any in OpsState.contests.values():
			var contest: ContestDef = contest_any as ContestDef
			if contest == null:
				continue
			if str(contest.currency).strip_edges().to_upper() == "USD" and int(contest.price) > 0:
				found[int(contest.price)] = true
	for denom in DEFAULT_MONEY_DENOMINATIONS:
		found[denom] = true
	var out: Array[int] = []
	for denom_any in found.keys():
		out.append(maxi(0, int(denom_any)))
	out.sort()
	return out

func _money_denominations_for_family(family_id: String, schedule_kind: String) -> Array[int]:
	var clean_family: String = family_id.strip_edges().to_upper()
	var clean_schedule: String = schedule_kind.strip_edges().to_upper()
	var out: Array[int] = []
	for denom in _money_denominations():
		if denom == 100 and not (clean_schedule == "SCHEDULED" and HIGH_STAKES_SCHEDULED_FAMILIES.has(clean_family)):
			continue
		out.append(denom)
	return out

func _on_contest_setup_selected(index: int) -> void:
	if index < 0 or index >= contest_setup_select.item_count:
		return
	var metadata_any: Variant = contest_setup_select.get_item_metadata(index)
	if typeof(metadata_any) != TYPE_DICTIONARY:
		return
	var metadata: Dictionary = metadata_any as Dictionary
	var scope: String = str(metadata.get("scope", "WEEKLY")).strip_edges().to_upper()
	var currency: String = str(metadata.get("currency", "FREE")).strip_edges().to_upper()
	var price: int = maxi(0, int(metadata.get("price", 0)))
	_set_scope_selection(scope)
	contest_mode.text = str(metadata.get("mode", contest_mode.text)).strip_edges().to_upper()
	_set_map_count_selection(maxi(3, int(metadata.get("map_count", _selected_map_count()))))
	contest_ante.value = price
	_apply_contest_setup_id(scope, currency, price, str(metadata.get("family", "")).strip_edges().to_upper())
	_refresh_payment_controls()
	_sync_rewards_json_from_payout_rows()

func _selected_contest_setup_metadata() -> Dictionary:
	if contest_setup_select == null or contest_setup_select.item_count <= 0:
		return {}
	var selected: int = contest_setup_select.selected
	if selected < 0 or selected >= contest_setup_select.item_count:
		return {}
	var metadata_any: Variant = contest_setup_select.get_item_metadata(selected)
	if typeof(metadata_any) != TYPE_DICTIONARY:
		return {}
	return (metadata_any as Dictionary).duplicate(true)

func _apply_contest_setup_id(scope: String, currency: String, price: int, family: String = "") -> void:
	var parts: Dictionary = _parse_contest_id(contest_id.text.strip_edges())
	var time_slice: String = str(parts.get("time", "")).strip_edges()
	var suffix: String = family.strip_edges().to_upper()
	if suffix.is_empty():
		suffix = str(parts.get("suffix", "")).strip_edges()
	if suffix == "STAGE_RACE":
		suffix = ""
	if time_slice.is_empty():
		time_slice = _default_time_slice(scope)
	var next_id: String = _build_contest_id({
		"scope": scope,
		"currency": currency,
		"price": price,
		"time": time_slice,
		"suffix": suffix
	})
	if not next_id.is_empty():
		contest_id.text = next_id

func _set_contest_setup_selection(scope: String, currency: String, price: int, family: String = "", schedule_kind: String = "") -> void:
	var clean_scope: String = scope.strip_edges().to_upper()
	var clean_currency: String = currency.strip_edges().to_upper()
	var clean_price: int = maxi(0, price)
	var clean_family: String = family.strip_edges().to_upper()
	var clean_schedule_kind: String = schedule_kind.strip_edges().to_upper()
	for i in range(contest_setup_select.item_count):
		var metadata_any: Variant = contest_setup_select.get_item_metadata(i)
		if typeof(metadata_any) != TYPE_DICTIONARY:
			continue
		var metadata: Dictionary = metadata_any as Dictionary
		if str(metadata.get("scope", "")) != clean_scope or str(metadata.get("currency", "")) != clean_currency or int(metadata.get("price", -1)) != clean_price:
			continue
		if not clean_family.is_empty() and str(metadata.get("family", "")) != clean_family:
			continue
		if not clean_schedule_kind.is_empty() and str(metadata.get("schedule_kind", "")) != clean_schedule_kind:
			continue
		contest_setup_select.select(i)
		return

func _default_time_slice(scope: String) -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var year: int = int(now.get("year", 2026))
	var month: int = int(now.get("month", 1))
	var day: int = int(now.get("day", 1))
	var clean_scope: String = scope.strip_edges().to_upper()
	if clean_scope == "MONTHLY":
		return "%04d-%02d" % [year, month]
	if clean_scope == "SEASONAL" or clean_scope == "YEARLY":
		return "%04d" % year
	var rough_week: int = clampi(int(ceil(float(((month - 1) * 31) + day) / 7.0)), 1, 53)
	return "%04d-W%02d" % [year, rough_week]

func _refresh_payment_controls() -> void:
	var paid: bool = int(contest_ante.value) > 0
	for node in [contest_ante_label, contest_ante, contest_prize_pool_label, contest_prize_pool, contest_winner_count_label, contest_winner_count, contest_payout_rows, contest_payout_summary, contest_rewards_json_label, contest_rewards_json]:
		if node == null:
			continue
		node.visible = paid
	contest_entry_type_label.visible = false
	contest_entry_type.visible = false

func _configure_winner_count_selector() -> void:
	contest_winner_count.clear()
	for count in [1, 2, 3, 4, 5, 10, 20]:
		var idx: int = contest_winner_count.item_count
		contest_winner_count.add_item("Top %d" % count)
		contest_winner_count.set_item_metadata(idx, count)
	contest_winner_count.select(0)
	contest_winner_count.item_selected.connect(_on_winner_count_selected)

func _on_winner_count_selected(index: int) -> void:
	var count: int = 1
	if index >= 0 and index < contest_winner_count.item_count:
		count = maxi(1, int(contest_winner_count.get_item_metadata(index)))
	_rebuild_payout_rows(count, _collect_payout_schedule_from_rows())

func _selected_winner_count() -> int:
	if contest_winner_count == null or contest_winner_count.item_count <= 0:
		return 1
	var selected: int = contest_winner_count.selected
	if selected < 0 or selected >= contest_winner_count.item_count:
		return 1
	return maxi(1, int(contest_winner_count.get_item_metadata(selected)))

func _set_winner_count_selection(count: int) -> void:
	var target: int = clampi(count, 1, 20)
	for i in range(contest_winner_count.item_count):
		if int(contest_winner_count.get_item_metadata(i)) >= target:
			contest_winner_count.select(i)
			return
	contest_winner_count.select(contest_winner_count.item_count - 1)

func _infer_winner_count(schedule: Array[Dictionary]) -> int:
	var max_placement: int = 1
	for payout in schedule:
		max_placement = maxi(max_placement, int(payout.get("placement", 0)))
	return max_placement

func _rebuild_payout_rows(winner_count: int, schedule: Array[Dictionary] = []) -> void:
	if contest_payout_rows == null:
		return
	var bps_by_placement: Dictionary = {}
	for payout in schedule:
		bps_by_placement[maxi(1, int(payout.get("placement", 0)))] = clampi(int(payout.get("payout_bps", 0)), 0, BASIS_POINTS_DENOMINATOR)
	for child in contest_payout_rows.get_children():
		child.queue_free()
	var safe_count: int = clampi(winner_count, 1, 20)
	for placement in range(1, safe_count + 1):
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "PayoutRow%d" % placement
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label: Label = Label.new()
		label.text = "#%d payout %%" % placement
		label.custom_minimum_size = Vector2(120.0, 0.0)
		row.add_child(label)
		var amount: SpinBox = SpinBox.new()
		amount.name = "PayoutPercent%d" % placement
		amount.min_value = 0
		amount.max_value = 100
		amount.step = 0.1
		amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amount.value = float(clampi(int(bps_by_placement.get(placement, 0)), 0, BASIS_POINTS_DENOMINATOR)) / 100.0
		amount.set_meta("placement", placement)
		amount.value_changed.connect(func(_value: float) -> void:
			_sync_rewards_json_from_payout_rows()
		)
		row.add_child(amount)
		contest_payout_rows.add_child(row)
	_sync_rewards_json_from_payout_rows()

func _collect_payout_schedule_from_rows() -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	if contest_payout_rows == null:
		return schedule
	for child in contest_payout_rows.get_children():
		var row: Control = child as Control
		if row == null:
			continue
		for grandchild in row.get_children():
			var amount: SpinBox = grandchild as SpinBox
			if amount == null:
				continue
			var placement: int = maxi(1, int(amount.get_meta("placement", schedule.size() + 1)))
			schedule.append({
				"placement": placement,
				"reward_type": "cash",
				"payout_bps": clampi(int(round(float(amount.value) * 100.0)), 0, BASIS_POINTS_DENOMINATOR)
			})
	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("placement", 0)) < int(b.get("placement", 0))
	)
	return schedule

func _sync_rewards_json_from_payout_rows() -> void:
	var schedule: Array[Dictionary] = _collect_payout_schedule_from_rows()
	if contest_rewards_json != null:
		contest_rewards_json.text = JSON.stringify(schedule, "\t")
	if contest_payout_summary != null:
		var total_bps: int = 0
		for payout in schedule:
			total_bps += clampi(int(payout.get("payout_bps", 0)), 0, BASIS_POINTS_DENOMINATOR)
		var rake_bps: int = DEFAULT_HOUSE_RAKE_BPS if int(contest_ante.value) > 0 else 0
		var remaining_bps: int = BASIS_POINTS_DENOMINATOR - total_bps
		contest_payout_summary.text = "Payout total: %.1f%% of post-rake pool across %d winners | House %.1f%% of gross | Unallocated %.1f%%" % [
			float(total_bps) / 100.0,
			schedule.size(),
			float(rake_bps) / 100.0,
			float(remaining_bps) / 100.0
		]

func _parse_prize_rewards_json() -> Dictionary:
	var raw: String = contest_rewards_json.text.strip_edges()
	if raw.is_empty():
		return {"ok": true, "rewards": []}
	var json: JSON = JSON.new()
	var err: Error = json.parse(raw)
	if err != OK:
		return {"ok": false, "error": "Payout JSON error on line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	if typeof(json.data) != TYPE_ARRAY:
		return {"ok": false, "error": "Payout JSON must be an array"}
	var rewards: Array[Dictionary] = []
	for reward_any in json.data as Array:
		if typeof(reward_any) != TYPE_DICTIONARY:
			return {"ok": false, "error": "Each payout entry must be an object"}
		rewards.append((reward_any as Dictionary).duplicate(true))
	return {"ok": true, "rewards": rewards}

func _parse_contest_id(contest_id_str: String) -> Dictionary:
	if contest_state != null:
		return contest_state.parse_contest_id(contest_id_str)
	return {}

func _build_contest_id(parts: Dictionary) -> String:
	if contest_state != null and contest_state.has_method("build_contest_id"):
		return str(contest_state.call("build_contest_id", parts))
	return _normalize_contest_id(contest_id.text)

func _normalize_contest_id(contest_id_str: String) -> String:
	if contest_state != null:
		return contest_state.normalize_contest_id(contest_id_str)
	return contest_id_str
