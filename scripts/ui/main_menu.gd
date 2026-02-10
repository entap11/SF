extends Control

const SFLog = preload("res://scripts/util/sf_log.gd")
const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")

const FONT_REGULAR_PATH := "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const DASH_TAB_KEY_RIGHT := "ui.mm.dash.right"
const DASH_TAB_KEY_LEFT := "ui.mm.dash.left"

@onready var hive_button: HexButton = $TopBar/HiveButton
@onready var dash_tab: HexButton = $DashTab
@onready var dash_panel: Panel = $DashPanel
@onready var dash_match_panel: Panel = $DashPanel/DashRoot/MatchHistoryPanel
@onready var dash_badges_panel: Panel = $DashPanel/DashRoot/BadgesPanel
@onready var dash_hex_buffs: HexButton = $DashPanel/DashHexes/DashBuffs
@onready var dash_hex_store: HexButton = $DashPanel/DashHexes/DashStore
@onready var dash_hex_hive: HexButton = $DashPanel/DashHexes/DashHive
@onready var dash_stats_panel: Panel = $DashPanel/DashStatsPanel
@onready var dash_analysis_panel: Panel = $DashPanel/DashAnalysisPanel
@onready var dash_replay_panel: Panel = $DashPanel/DashReplayPanel
@onready var dash_buffs_panel: Panel = $DashPanel/DashBuffsPanel
@onready var dash_hive_panel: Panel = $DashPanel/DashHivePanel
@onready var dash_store_panel: Panel = $DashPanel/DashStorePanel
@onready var dash_settings_panel: Panel = $DashPanel/DashSettingsPanel
@onready var dash_badges_panel_full: Panel = $DashPanel/DashBadgesPanel
@onready var store_landing_panel: Panel = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreLanding
@onready var store_category_grid: GridContainer = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreLanding/StoreLandingVBox/StoreCategoryGrid
@onready var store_category_view: Panel = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView
@onready var store_category_header: Label = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryHeader
@onready var store_category_sub: Label = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategorySub
@onready var store_category_list: VBoxContainer = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryList
@onready var store_category_prefs_panel: Panel = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryPrefs
@onready var store_prefs_label: Label = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryPrefs/StoreCategoryPrefsVBox/StorePrefsLabel
@onready var store_prefs_toggle: CheckButton = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryPrefs/StoreCategoryPrefsVBox/StorePrefsToggle
@onready var store_category_back: Button = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryBack
@onready var async_panel: Panel = $AsyncPanel
@onready var async_subtitle_label: Label = $AsyncPanel/AsyncVBox/AsyncSub
@onready var async_top_row: HBoxContainer = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow
@onready var async_bottom_row: HBoxContainer = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow
@onready var async_results_panel: Panel = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel
@onready var async_results_header: Label = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsHeader
@onready var async_results_sub: Label = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsSub
@onready var async_results_list: VBoxContainer = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsList
@onready var async_results_action: Button = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsAction
@onready var async_rules_panel: Panel = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel
@onready var async_rules_header: Label = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncRulesHeader
@onready var async_rules_line1: Label = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncRulesLine1
@onready var async_rules_line2: Label = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncRulesLine2
@onready var async_free_list: VBoxContainer = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList
@onready var async_rules_action: Button = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncRulesAction
@onready var async_footer_label: Label = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncFooter
@onready var dash_stats_sub: Label = $DashPanel/DashStatsPanel/StatsVBox/StatsSub
@onready var dash_analysis_sub: Label = $DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisSub
@onready var dash_replay_sub: Label = $DashPanel/DashReplayPanel/ReplayVBox/ReplaySub
@onready var dash_stats_close: Button = $DashPanel/DashStatsPanel/StatsVBox/StatsClose
@onready var dash_analysis_close: Button = $DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisClose
@onready var dash_replay_close: Button = $DashPanel/DashReplayPanel/ReplayVBox/ReplayClose
@onready var dash_buffs_close: Button = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsClose
@onready var dash_hive_close: Button = $DashPanel/DashHivePanel/HiveVBox/HiveClose
@onready var dash_store_close: Button = $DashPanel/DashStorePanel/StoreVBox/StoreClose
@onready var dash_settings_close: Button = $DashPanel/DashSettingsPanel/SettingsVBox/SettingsClose
@onready var dash_badges_close: Button = $DashPanel/DashBadgesPanel/BadgesCollectionVBox/BadgesClose
@onready var async_close: Button = $AsyncPanel/AsyncVBox/AsyncClose
@onready var stats_tier_free: Button = $DashPanel/DashStatsPanel/StatsVBox/StatsTierTabs/StatsTierFree
@onready var stats_tier_bp: Button = $DashPanel/DashStatsPanel/StatsVBox/StatsTierTabs/StatsTierBP
@onready var stats_tier_elite: Button = $DashPanel/DashStatsPanel/StatsVBox/StatsTierTabs/StatsTierElite
@onready var stats_rows: Array = [
	$DashPanel/DashStatsPanel/StatsVBox/StatsBody/StatsBodyVBox/StatsRow1,
	$DashPanel/DashStatsPanel/StatsVBox/StatsBody/StatsBodyVBox/StatsRow2,
	$DashPanel/DashStatsPanel/StatsVBox/StatsBody/StatsBodyVBox/StatsRow3,
	$DashPanel/DashStatsPanel/StatsVBox/StatsBody/StatsBodyVBox/StatsRow4,
	$DashPanel/DashStatsPanel/StatsVBox/StatsBody/StatsBodyVBox/StatsRow5
]
@onready var analysis_lines: Array = [
	$DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisBody/AnalysisBodyVBox/AnalysisLine1,
	$DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisBody/AnalysisBodyVBox/AnalysisLine2,
	$DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisBody/AnalysisBodyVBox/AnalysisLine3,
	$DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisBody/AnalysisBodyVBox/AnalysisLine4,
	$DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisBody/AnalysisBodyVBox/AnalysisLine5
]
@onready var replay_controls_buttons: Array = [
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayControlsPanel/ReplayControlsVBox/ReplayControlsButtons/ReplayPlay,
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayControlsPanel/ReplayControlsVBox/ReplayControlsButtons/ReplayPause,
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayControlsPanel/ReplayControlsVBox/ReplayControlsButtons/ReplayStep,
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayControlsPanel/ReplayControlsVBox/ReplayControlsButtons/ReplaySpeed
]
@onready var replay_info_lines: Array = [
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayInfoPanel/ReplayInfoVBox/ReplayInfoLine1,
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayInfoPanel/ReplayInfoVBox/ReplayInfoLine2,
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayInfoPanel/ReplayInfoVBox/ReplayInfoLine3
]
@onready var replay_timeline_times: Array = [
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox/ReplayTimelineRow1/ReplayTimelineTime,
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox/ReplayTimelineRow2/ReplayTimelineTime,
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox/ReplayTimelineRow3/ReplayTimelineTime,
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox/ReplayTimelineRow4/ReplayTimelineTime
]
@onready var replay_timeline_events: Array = [
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox/ReplayTimelineRow1/ReplayTimelineEvent,
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox/ReplayTimelineRow2/ReplayTimelineEvent,
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox/ReplayTimelineRow3/ReplayTimelineEvent,
	$DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox/ReplayTimelineRow4/ReplayTimelineEvent
]
@onready var buffs_slot_buttons: Array = [
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel/BuffsLoadoutVBox/BuffsSlotsRow/BuffSlot1,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel/BuffsLoadoutVBox/BuffsSlotsRow/BuffSlot2,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel/BuffsLoadoutVBox/BuffsSlotsRow/BuffSlot3,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel/BuffsLoadoutVBox/BuffsSlotsRow/BuffSlot4
]
@onready var buffs_top_row: HBoxContainer = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow
@onready var buffs_loadout_panel: Panel = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel
@onready var buffs_library_panel: Panel = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel
@onready var buffs_detail_panel: Panel = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel
@onready var buffs_loadout_vbox: VBoxContainer = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel/BuffsLoadoutVBox
@onready var buffs_slots_row: VBoxContainer = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel/BuffsLoadoutVBox/BuffsSlotsRow
@onready var buffs_library_vbox: VBoxContainer = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox
@onready var buffs_library_header: Label = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryHeader
@onready var buffs_footer_label: Label = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsFooter
@onready var buffs_library_buttons: Array = [
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem1,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem2,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem3,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem4,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem5,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem6
]
@onready var buffs_detail_name_label: Label = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailName
@onready var buffs_detail_desc_label: Label = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailDesc
@onready var buffs_detail_meta_label: Label = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailMeta
@onready var buffs_detail_buttons: Array = [
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailButtons/BuffEquip,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailButtons/BuffRemove
]
@onready var hive_action_buttons: Array = [
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow/HiveChat,
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow/HiveLadder,
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow/HiveQuests
]
var _store_category_buttons: Array = []
var _store_sku_buttons: Array = []
var _time_puzzle_lobby: TimePuzzleLobby = null
var _play_mode_select: Control = null
var _vs_lobby: Control = null
@onready var async_action_buttons: Array = [
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncQueuePanel/AsyncQueueVBox/AsyncQueueAction,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncLeaderboardPanel/AsyncLeaderboardVBox/AsyncLeaderboardAction,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncSeasonPanel/AsyncSeasonVBox/AsyncSeasonAction,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsAction,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncRulesAction
]
@onready var async_ladder_buttons: Array = [
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsList/AsyncLadderMissNOut,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsList/AsyncLadderRace3,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsList/AsyncLadderRace5,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsList/AsyncLadderStage3,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsList/AsyncLadderStage5
]
@onready var async_free_buttons: Array = [
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList/AsyncFreeMissNOut,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList/AsyncFreeRace3,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList/AsyncFreeRace5,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList/AsyncFreeStage3,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList/AsyncFreeStage5
]
@onready var async_vbox: VBoxContainer = $AsyncPanel/AsyncVBox
@onready var async_weekly_panel: Panel = $AsyncPanel/AsyncWeeklyPanel
@onready var async_monthly_panel: Panel = $AsyncPanel/AsyncMonthlyPanel
@onready var async_yearly_panel: Panel = $AsyncPanel/AsyncYearlyPanel
@onready var async_weekly_buyin_buttons: Array = [
	$AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyList/WeeklyBuyin1,
	$AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyList/WeeklyBuyin2,
	$AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyList/WeeklyBuyin3,
	$AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyList/WeeklyBuyin4,
	$AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyList/WeeklyBuyin5
]
@onready var async_monthly_buyin_buttons: Array = [
	$AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyList/MonthlyBuyin1,
	$AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyList/MonthlyBuyin2,
	$AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyList/MonthlyBuyin3,
	$AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyList/MonthlyBuyin4,
	$AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyList/MonthlyBuyin5
]
@onready var async_yearly_buyin_buttons: Array = [
	$AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyList/YearlyBuyin1,
	$AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyList/YearlyBuyin2,
	$AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyList/YearlyBuyin3,
	$AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyList/YearlyBuyin4,
	$AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyList/YearlyBuyin5
]
@onready var async_weekly_rules: Label = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyRules
@onready var async_monthly_rules: Label = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyRules
@onready var async_yearly_rules: Label = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyRules
@onready var async_weekly_assigned_map: Label = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyAssignedMap
@onready var async_monthly_assigned_map: Label = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyAssignedMap
@onready var async_yearly_assigned_map: Label = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyAssignedMap
@onready var async_weekly_play: Button = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyPlay
@onready var async_monthly_play: Button = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyPlay
@onready var async_yearly_play: Button = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyPlay
@onready var async_weekly_back: Button = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBack
@onready var async_monthly_back: Button = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBack
@onready var async_yearly_back: Button = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBack
@onready var play_button: Button = $BottomBar/MenuButtons/PlayButton
@onready var status_label: Label = $BottomBar/StatusLabel
@onready var onboarding_overlay: Control = $ProfileFirstRunOverlay
@onready var onboarding_panel: OnboardingPanel = $ProfileFirstRunOverlay/OverlayCenter/OverlayPanel/OverlayVBox/OnboardingPanel

var _font_regular: Font
var _font_semibold: Font
var _dash_open := false
var _dash_hidden_x := 0.0
var _dash_tab_closed_left := 0.0
var _dash_tab_closed_right := 0.0
var _dash_tab_open_left := 0.0
var _dash_tab_open_right := 0.0
var _dash_tween: Tween
var _player_profile := {
	"tier_text": "Tier: Bronze",
	"honey": 12480
}
var _stats_tier := "FREE"
var _current_match_index := 0
var _store_owned_entitlements := {
	"zero_ads": false
}
var _prefer_zero_ads := false
var _async_buyins := {
	"weekly": 1,
	"monthly": 1,
	"yearly": 1
}
var _async_confirm_pending := {
	"weekly": false,
	"monthly": false,
	"yearly": false
}
var _async_confirm_deadline := {
	"weekly": 0,
	"monthly": 0,
	"yearly": 0
}
var _async_map_index := 0
var _async_assigned_map := {
	"weekly": "",
	"monthly": "",
	"yearly": ""
}
var _async_paid_entry_usd: int = 1
var _async_track_mode: String = "select"

const ASYNC_BUYINS := [1, 5, 10, 20]
const ASYNC_MAPS := ["Map A", "Map B", "Map C", "Map D", "Map E"]
const ASYNC_CONFIRM_WINDOW_MS := 900
const ASYNC_TRACK_SELECT := "select"
const ASYNC_TRACK_PAID := "paid"
const ASYNC_TRACK_FREE := "free"
const ASYNC_STAGE_AND_MISS_WINDOW_SEC := 30 * 60
const ASYNC_WINDOW_START_PLAYERS := 5
const ASYNC_TIMED_RACE_SYNC_JOIN_SEC := 30
const BUFF_LOADOUT_SIZE: int = 3
const BUFF_DRAG_MIN_PX: float = 16.0
const BUFF_LIBRARY_TIERS: Array[String] = ["classic", "premium", "elite"]

var _buff_library_all: Array[Dictionary] = []
var _buff_library_selected_ids: Dictionary = {}
var _buff_owned_ids: Array[String] = []
var _buff_loadout_ids: Array[String] = []
var _buff_selected_id: String = ""
var _buff_selected_origin: String = ""
var _buff_selected_slot_index: int = -1
var _buff_owned_panel: Panel = null
var _buff_loadout_top_panel: Panel = null
var _buff_owned_header_label: Label = null
var _buff_owned_empty_label: Label = null
var _buff_owned_flow: VBoxContainer = null
var _buff_owned_buttons: Array[Button] = []
var _buff_library_scroll: ScrollContainer = null
var _buff_library_tier_root: VBoxContainer = null
var _buff_library_tier_grids: Dictionary = {}
var _buff_library_tier_headers: Dictionary = {}
var _buff_library_runtime_buttons: Array[Button] = []
var _buff_drag_state: Dictionary = {}

const DEFAULT_STATS_TIERS := {
	"FREE": [
		"Win/Loss: W",
		"Duration: 3:12",
		"Units Spawned: 120",
		"Units Arrived: 102",
		"Hives Captured: 2"
	],
	"BP": [
		"UA-O / UA-F: 48 / 54",
		"Units Lost: 61",
		"Waste Rate: 15%",
		"Routing Efficiency: 0.85",
		"Net Hive Count: +1"
	],
	"ELITE": [
		"Power Share Early/Mid/Late: 0.42/0.58/0.63",
		"APOT: 0.54",
		"Peak Units In Flight: 18",
		"Pressure Diff: +7",
		"Pressure Conversion: 0.38"
	]
}
const MATCH_HISTORY := [
	{
		"title": "Win — Hive Rush",
		"result": "W",
		"eff": "HE 74",
		"mode": "4P Rumble",
		"map": "Map A",
		"duration": "3:12",
		"stats_tiers": DEFAULT_STATS_TIERS,
		"analysis": [
			"00:42 Lane 2->6 established; early pressure wins tempo.",
			"01:18 First capture flips Hive 6; no counter-lane formed.",
			"01:57 Barracks chain completes; output spikes.",
			"02:34 Yellow locks mid; red rotations come late.",
			"02:51 Final swing converts Hive 3; match ends."
		],
		"timeline": [
			{"t": "00:42", "event": "Lane established 2->6"},
			{"t": "01:18", "event": "Hive 6 captured"},
			{"t": "01:57", "event": "Barracks activated"},
			{"t": "02:51", "event": "Final swing on Hive 3"}
		]
	},
	{
		"title": "Loss — Tower Line",
		"result": "L",
		"eff": "HE 61",
		"mode": "4P Rumble",
		"map": "Map B",
		"duration": "4:08",
		"stats_tiers": DEFAULT_STATS_TIERS,
		"analysis": [
			"00:58 Tower chain completes; enemy fire rate spikes.",
			"01:32 Left lane stalls; feeds without breakthrough.",
			"02:11 Red captures Hive 4; pressure flips mid.",
			"03:02 Barracks delayed; output never catches up.",
			"03:49 Final push collapses; loss confirmed."
		],
		"timeline": [
			{"t": "00:58", "event": "Tower chain completes"},
			{"t": "02:11", "event": "Hive 4 captured"},
			{"t": "03:02", "event": "Barracks delayed"},
			{"t": "03:49", "event": "Final push collapsed"}
		]
	},
	{
		"title": "Win — Split Push",
		"result": "W",
		"eff": "HE 83",
		"mode": "4P Rumble",
		"map": "Map A",
		"duration": "3:34",
		"stats_tiers": DEFAULT_STATS_TIERS,
		"analysis": [
			"00:35 Dual lanes online; pressure splits defenders.",
			"01:09 Enemy hive flips twice; tempo remains yellow.",
			"01:44 Barracks online; feeds stabilize both fronts.",
			"02:28 Pass-through chain accelerates mid collapse.",
			"03:12 Capture of Hive 2 seals win."
		],
		"timeline": [
			{"t": "00:35", "event": "Dual lanes online"},
			{"t": "01:09", "event": "Hive flips twice"},
			{"t": "01:44", "event": "Barracks online"},
			{"t": "03:12", "event": "Hive 2 captured"}
		]
	},
	{
		"title": "Win — Honey Trap",
		"result": "W",
		"eff": "HE 70",
		"mode": "4P Rumble",
		"map": "Map C",
		"duration": "2:55",
		"stats_tiers": DEFAULT_STATS_TIERS,
		"analysis": [
			"00:22 Early bait draws units into tower range.",
			"00:56 Enemy loses pressure; lane swings back.",
			"01:20 Neutral hive flips; mid control gained.",
			"02:01 Swarm chain denies recovery.",
			"02:42 Clean finish; win locked."
		],
		"timeline": [
			{"t": "00:22", "event": "Tower bait set"},
			{"t": "00:56", "event": "Lane swings back"},
			{"t": "01:20", "event": "Neutral flips"},
			{"t": "02:42", "event": "Finish locked"}
		]
	},
	{
		"title": "Loss — Barracks Hold",
		"result": "L",
		"eff": "HE 55",
		"mode": "4P Rumble",
		"map": "Map B",
		"duration": "4:22",
		"stats_tiers": DEFAULT_STATS_TIERS,
		"analysis": [
			"01:10 Enemy barracks holds; pressure never breaks.",
			"01:46 Overfeed on Hive 1 reduces flexibility.",
			"02:30 Lane reversal too late; mid collapses.",
			"03:19 Towers online for enemy; no answer.",
			"04:05 Last hive swings; loss confirmed."
		],
		"timeline": [
			{"t": "01:10", "event": "Enemy barracks holds"},
			{"t": "02:30", "event": "Lane reversal late"},
			{"t": "03:19", "event": "Enemy towers online"},
			{"t": "04:05", "event": "Last hive swings"}
		]
	}
]
const STORE_CATEGORIES := [
	{"id": "Buffs", "title": "Buffs", "desc": "Match, info, and identity buffs."},
	{"id": "Analysis", "title": "Analysis", "desc": "Forensic replay and AI commentary."},
	{"id": "StatsMemory", "title": "Stats & Memory", "desc": "Extended history and reports."},
	{"id": "TimePuzzles", "title": "Time Puzzles", "desc": "Async thinking economy."},
	{"id": "Passes", "title": "Passes", "desc": "Access and depth unlocks."},
	{"id": "Cosmetics", "title": "Cosmetics", "desc": "Skins, themes, frames."}
]
const STORE_SKUS := [
	{
		"id": "buff_match_tempo",
		"category": "Buffs",
		"subcategory": "Match Buffs",
		"title": "Tempo Kit",
		"description": "Minor send interval tuning for a match.",
		"price_honey": 250,
		"entitlements": []
	},
	{
		"id": "buff_signal_clarity",
		"category": "Buffs",
		"subcategory": "Information Buffs",
		"title": "Signal Cleanser",
		"description": "Cleaner alerts and lane signal.",
		"price_honey": 180,
		"entitlements": []
	},
	{
		"id": "analysis_forensic_replay",
		"category": "Analysis",
		"subcategory": "Replay",
		"title": "Forensic Replay",
		"description": "Unlock full replay scrubbing.",
		"price_honey": 600,
		"entitlements": ["analysis_forensic"]
	},
	{
		"id": "analysis_ai_commentary",
		"category": "Analysis",
		"subcategory": "AI",
		"title": "AI Commentary",
		"description": "Cold, factual commentary.",
		"price_honey": 500,
		"entitlements": ["analysis_ai"]
	},
	{
		"id": "stats_archive",
		"category": "StatsMemory",
		"subcategory": "History",
		"title": "Extended History",
		"description": "Keep match history beyond rolling window.",
		"price_honey": 400,
		"entitlements": ["stats_archive"]
	},
	{
		"id": "stats_filters",
		"category": "StatsMemory",
		"subcategory": "Filters",
		"title": "Advanced Filters",
		"description": "Filter by mode, season, and team.",
		"price_honey": 300,
		"entitlements": ["stats_filters"]
	},
	{
		"id": "puzzle_entry",
		"category": "TimePuzzles",
		"subcategory": "Entry",
		"title": "Contest Entry",
		"description": "Enter the weekly puzzle.",
		"price_honey": 120,
		"entitlements": []
	},
	{
		"id": "puzzle_hints",
		"category": "TimePuzzles",
		"subcategory": "Hints",
		"title": "Hint Pack",
		"description": "Additional hint attempts.",
		"price_honey": 90,
		"entitlements": []
	},
	{
		"id": "pass_analysis",
		"category": "Passes",
		"subcategory": "Pass",
		"title": "Analysis Pass",
		"description": "Unlimited analysis depth.",
		"price_real": "$4.99",
		"entitlements": ["pass_analysis"]
	},
	{
		"id": "pass_archivist",
		"category": "Passes",
		"subcategory": "Pass",
		"title": "Archivist Pass",
		"description": "Unlimited stat history and reports.",
		"price_real": "$4.99",
		"entitlements": ["pass_archivist"]
	},
	{
		"id": "pass_puzzle",
		"category": "Passes",
		"subcategory": "Pass",
		"title": "Puzzle Pass",
		"description": "Puzzle access with reduced friction.",
		"price_real": "$2.99",
		"entitlements": ["pass_puzzle"]
	},
	{
		"id": "pass_zero_ads",
		"category": "Passes",
		"subcategory": "Pass",
		"title": "Zero Ads Pass",
		"description": "Removes all advertisements from Swarmfront.",
		"price_real": "$3.99",
		"entitlements": ["zero_ads"]
	},
	{
		"id": "bundle_analyst",
		"category": "Analysis",
		"subcategory": "Bundle",
		"title": "The Analyst",
		"description": "Replay + AI + key moments + comparison.",
		"price_real": "$6.99",
		"entitlements": ["analysis_forensic", "analysis_ai"],
		"is_bundle": true
	},
	{
		"id": "bundle_archivist",
		"category": "StatsMemory",
		"subcategory": "Bundle",
		"title": "The Archivist",
		"description": "History + filters + seasonal reports.",
		"price_real": "$5.99",
		"entitlements": ["stats_archive", "stats_filters"],
		"is_bundle": true
	},
	{
		"id": "cosmetic_skin_a",
		"category": "Cosmetics",
		"subcategory": "Skins",
		"title": "Hive Skin A",
		"description": "Clean metallic hive skin.",
		"price_honey": 350,
		"entitlements": ["cosmetic_skin_a"]
	},
	{
		"id": "cosmetic_frame_hex",
		"category": "Cosmetics",
		"subcategory": "Frames",
		"title": "Hex Frame",
		"description": "Badge frame, cosmetic only.",
		"price_honey": 220,
		"entitlements": ["cosmetic_frame_hex"]
	}
]

func _ready() -> void:
	_load_fonts()
	_style_labels()
	_style_buttons()
	_style_panels()
	_wire_buttons()
	_set_hex_buttons()
	_load_match_history()
	_build_store_landing()
	_init_buffs_ui()
	call_deferred("_init_dash_state")
	_apply_player_profile(_player_profile)
	status_label.text = "Ready"
	_bind_onboarding_gate()

func _input(event: InputEvent) -> void:
	if _buff_drag_state.is_empty():
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_buff_drag(motion.position)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_update_buff_drag(mb.position)
		if not mb.pressed:
			_finish_buff_drag(mb.position)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_update_buff_drag(drag.position)
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		_update_buff_drag(touch.position)
		if not touch.pressed:
			_finish_buff_drag(touch.position)

func _bind_onboarding_gate() -> void:
	ProfileManager.ensure_loaded()
	if not ProfileManager.is_onboarding_complete():
		onboarding_overlay.visible = true
		if onboarding_panel != null:
			if not onboarding_panel.onboarding_done.is_connected(_on_onboarding_done):
				onboarding_panel.onboarding_done.connect(_on_onboarding_done)
	else:
		onboarding_overlay.visible = false

func _on_onboarding_done() -> void:
	onboarding_overlay.visible = false

func _load_fonts() -> void:
	_font_regular = load(FONT_REGULAR_PATH)
	_font_semibold = load(FONT_SEMIBOLD_PATH)

func _style_labels() -> void:
	_apply_font($TopBar/RankLabel, _font_regular, 16)
	_apply_font($TopBar/HoneyLabel, _font_regular, 16)
	_apply_font($DashPanel/DashTopBar/DashRankLabel, _font_regular, 16)
	_apply_font($DashPanel/DashTopBar/DashHoneyLabel, _font_regular, 16)
	_apply_font($HeroPanel/HeroVBox/HeroTitle, _font_semibold, 20)
	_apply_font($HeroPanel/HeroVBox/HeroSub, _font_regular, 14)
	_apply_font($DashPanel/DashRoot/MatchHistoryPanel/MatchCenter/MatchVBox/MatchHeader, _font_semibold, 18)
	_apply_font($DashPanel/DashRoot/BadgesPanel/BadgesVBox/BadgesHeader, _font_semibold, 18)
	for i in range(1, 6):
		var row_path := "DashPanel/DashRoot/MatchHistoryPanel/MatchCenter/MatchVBox/MatchList/MatchRow%d" % i
		_apply_font(get_node("%s/MatchTitle" % row_path), _font_regular, 15)
		_apply_font(get_node("%s/MatchResult" % row_path), _font_semibold, 14)
		_apply_font(get_node("%s/MatchEff" % row_path), _font_regular, 14)
	_apply_font($DashPanel/DashStatsPanel/StatsVBox/StatsTitle, _font_semibold, 20)
	_apply_font($DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisTitle, _font_semibold, 20)
	_apply_font($DashPanel/DashReplayPanel/ReplayVBox/ReplayTitle, _font_semibold, 20)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsTitle, _font_semibold, 20)
	_apply_font($DashPanel/DashBadgesPanel/BadgesCollectionVBox/BadgesTitle, _font_semibold, 20)
	_apply_font($DashPanel/DashStatsPanel/StatsVBox/StatsSub, _font_regular, 14)
	_apply_font($DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisSub, _font_regular, 14)
	_apply_font($DashPanel/DashReplayPanel/ReplayVBox/ReplaySub, _font_regular, 14)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsSub, _font_regular, 14)
	_apply_font($DashPanel/DashBadgesPanel/BadgesCollectionVBox/BadgesSub, _font_regular, 14)
	_apply_font($DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisBody/AnalysisBodyVBox/AnalysisBodyHeader, _font_semibold, 14)
	for i in range(1, 6):
		var analysis_line := "DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisBody/AnalysisBodyVBox/AnalysisLine%d" % i
		_apply_font(get_node(analysis_line), _font_regular, 14)
	_apply_font($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayControlsPanel/ReplayControlsVBox/ReplayControlsHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayInfoPanel/ReplayInfoVBox/ReplayInfoHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox/ReplayTimelineHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayNote, _font_regular, 12)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel/BuffsLoadoutVBox/BuffsLoadoutHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailName, _font_semibold, 14)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailDesc, _font_regular, 13)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailMeta, _font_regular, 12)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsFooter, _font_regular, 12)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveTitle, _font_semibold, 20)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveSub, _font_regular, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveOverviewHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveActivityPanel/HiveActivityVBox/HiveActivityHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveFooter, _font_regular, 12)
	_apply_font($DashPanel/DashStorePanel/StoreVBox/StoreTitle, _font_semibold, 20)
	_apply_font($DashPanel/DashStorePanel/StoreVBox/StoreSub, _font_regular, 14)
	_apply_font($DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreLanding/StoreLandingVBox/StoreLandingHeader, _font_semibold, 14)
	_apply_font(store_category_header, _font_semibold, 16)
	_apply_font(store_category_sub, _font_regular, 13)
	_apply_font(store_prefs_label, _font_regular, 13)
	_apply_font(store_category_back, _font_regular, 12)
	_apply_font(store_prefs_toggle, _font_regular, 12)
	_apply_font($AsyncPanel/AsyncVBox/AsyncTitle, _font_semibold, 20)
	_apply_font($AsyncPanel/AsyncVBox/AsyncSub, _font_regular, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncQueuePanel/AsyncQueueVBox/AsyncQueueHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncLeaderboardPanel/AsyncLeaderboardVBox/AsyncLeaderboardHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncSeasonPanel/AsyncSeasonVBox/AsyncSeasonHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsSub, _font_regular, 13)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncRulesHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncFooter, _font_regular, 12)
	_apply_font($AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyTitle, _font_semibold, 20)
	_apply_font($AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklySub, _font_regular, 14)
	_apply_font($AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyListHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyTitle, _font_semibold, 20)
	_apply_font($AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlySub, _font_regular, 14)
	_apply_font($AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyListHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyTitle, _font_semibold, 20)
	_apply_font($AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlySub, _font_regular, 14)
	_apply_font($AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyListHeader, _font_semibold, 14)
	for label_path in [
		"AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncQueuePanel/AsyncQueueVBox/AsyncQueueDesc",
		"AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncLeaderboardPanel/AsyncLeaderboardVBox/AsyncLeaderboardLine1",
		"AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncLeaderboardPanel/AsyncLeaderboardVBox/AsyncLeaderboardLine2",
		"AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncLeaderboardPanel/AsyncLeaderboardVBox/AsyncLeaderboardLine3",
		"AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncSeasonPanel/AsyncSeasonVBox/AsyncSeasonLine1",
		"AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncSeasonPanel/AsyncSeasonVBox/AsyncSeasonLine2",
		"AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncSeasonPanel/AsyncSeasonVBox/AsyncSeasonLine3",
		"AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncRulesLine1",
		"AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncRulesLine2",
		"AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyRules",
		"AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyMapPool",
		"AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyAssignedMap",
		"AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyRules",
		"AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyMapPool",
		"AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyAssignedMap",
		"AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyRules",
		"AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyMapPool",
		"AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyAssignedMap"
	]:
		_apply_font(get_node(label_path), _font_regular, 13)
	for label_path in [
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanName",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanTag",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanLeague",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanMembers",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember1",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember2",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember3",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember4",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveActivityPanel/HiveActivityVBox/HiveActivity1",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveActivityPanel/HiveActivityVBox/HiveActivity2",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveActivityPanel/HiveActivityVBox/HiveActivity3"
	]:
		_apply_font(get_node(label_path), _font_regular, 13)
	for label in replay_info_lines:
		_apply_font(label, _font_regular, 13)
	for label in replay_timeline_times:
		_apply_font(label, _font_semibold, 12)
	for label in replay_timeline_events:
		_apply_font(label, _font_regular, 12)
	for button in buffs_slot_buttons:
		_apply_font(button, _font_regular, 12)
	for button in buffs_library_buttons:
		_apply_font(button, _font_regular, 12)
	for button in buffs_detail_buttons:
		_apply_font(button, _font_regular, 12)
	for button in hive_action_buttons:
		_apply_font(button, _font_regular, 12)
	for button in async_action_buttons:
		_apply_font(button, _font_regular, 12)
	for button in async_ladder_buttons:
		_apply_font(button, _font_regular, 12)
	for button in async_free_buttons:
		_apply_font(button, _font_regular, 12)
	for button in async_weekly_buyin_buttons:
		_apply_font(button, _font_regular, 12)
	for button in async_monthly_buyin_buttons:
		_apply_font(button, _font_regular, 12)
	for button in async_yearly_buyin_buttons:
		_apply_font(button, _font_regular, 12)
	for button in [async_weekly_play, async_monthly_play, async_yearly_play]:
		_apply_font(button, _font_semibold, 14)
	for button in [async_weekly_back, async_monthly_back, async_yearly_back]:
		_apply_font(button, _font_regular, 12)
	var analysis_vbox: VBoxContainer = $DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisBody/AnalysisBodyVBox
	analysis_vbox.add_theme_constant_override("separation", 8)
	var buffs_body_vbox: VBoxContainer = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox
	buffs_body_vbox.add_theme_constant_override("separation", 12)
	var hive_body_vbox: VBoxContainer = $DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox
	hive_body_vbox.add_theme_constant_override("separation", 12)
	var store_body_vbox: VBoxContainer = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox
	store_body_vbox.add_theme_constant_override("separation", 12)
	store_category_grid.add_theme_constant_override("h_separation", 12)
	store_category_grid.add_theme_constant_override("v_separation", 12)
	store_category_list.add_theme_constant_override("separation", 8)
	var async_body_vbox: VBoxContainer = $AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox
	async_body_vbox.add_theme_constant_override("separation", 12)
	$AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox.add_theme_constant_override("separation", 8)
	$AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox.add_theme_constant_override("separation", 8)
	$AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox.add_theme_constant_override("separation", 8)
	_apply_font(stats_tier_free, _font_semibold, 12)
	_apply_font(stats_tier_bp, _font_semibold, 12)
	_apply_font(stats_tier_elite, _font_semibold, 12)
	for row in stats_rows:
		_apply_font(row, _font_regular, 14)
	_apply_font(status_label, _font_regular, 14)

func _style_buttons() -> void:
	_apply_font(play_button, _font_semibold, 20)
	_style_button(play_button, Color(0.85, 0.64, 0.16), Color(1.0, 0.9, 0.5), Color(0.1, 0.08, 0.02))
	for button in [
		$BottomBar/MenuButtons/LeftButtons/AsyncButton,
		$BottomBar/MenuButtons/LeftButtons/BuffsButton,
		$BottomBar/MenuButtons/LeftButtons/StoreButton,
		$BottomBar/MenuButtons/RightButtons/ClanButton,
		$BottomBar/MenuButtons/RightButtons/SettingsButton
	]:
		_apply_font(button, _font_regular, 14)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.35, 0.38, 0.45), Color(0.9, 0.9, 0.9))
	for button in replay_controls_buttons:
		_apply_font(button, _font_regular, 12)
		_style_button(button, Color(0.1, 0.11, 0.14), Color(0.4, 0.42, 0.5), Color(0.92, 0.92, 0.92))
	for button in buffs_slot_buttons:
		_style_button(button, Color(0.1, 0.11, 0.14), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
	for button in buffs_library_buttons:
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
	for button in buffs_detail_buttons:
		_style_button(button, Color(0.16, 0.14, 0.1), Color(0.75, 0.65, 0.35), Color(0.98, 0.94, 0.8))
	for button in hive_action_buttons:
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
	for button in async_action_buttons:
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
	for button in async_ladder_buttons:
		_style_button(button, Color(0.1, 0.11, 0.14), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
	for button in async_free_buttons:
		_style_button(button, Color(0.1, 0.11, 0.14), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
	for button in async_weekly_buyin_buttons:
		_style_button(button, Color(0.1, 0.11, 0.14), Color(0.4, 0.42, 0.5), Color(0.92, 0.92, 0.92))
	for button in async_monthly_buyin_buttons:
		_style_button(button, Color(0.1, 0.11, 0.14), Color(0.4, 0.42, 0.5), Color(0.92, 0.92, 0.92))
	for button in async_yearly_buyin_buttons:
		_style_button(button, Color(0.1, 0.11, 0.14), Color(0.4, 0.42, 0.5), Color(0.92, 0.92, 0.92))
	for button in [async_weekly_play, async_monthly_play, async_yearly_play]:
		_style_button(button, Color(0.16, 0.14, 0.1), Color(0.75, 0.65, 0.35), Color(0.98, 0.94, 0.8))
	for button in [async_weekly_back, async_monthly_back, async_yearly_back]:
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	_style_button(store_category_back, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	_style_button(store_prefs_toggle, Color(0.1, 0.11, 0.14), Color(0.4, 0.42, 0.5), Color(0.92, 0.92, 0.92))
	_style_dash_buttons()

func _style_panels() -> void:
	_style_panel($HeroPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.8))
	_style_panel(dash_panel, Color(0.08, 0.09, 0.12, 0.95), Color(0.55, 0.56, 0.62, 0.8))
	_style_panel(dash_match_panel, Color(0.07, 0.08, 0.1, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel(dash_badges_panel, Color(0.07, 0.08, 0.1, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	for panel in [dash_stats_panel, dash_analysis_panel, dash_replay_panel, dash_buffs_panel, dash_badges_panel_full, dash_settings_panel]:
		_style_panel(panel, Color(0.06, 0.07, 0.1, 0.98), Color(0.45, 0.48, 0.58, 0.8))
	_style_panel($DashPanel/DashStatsPanel/StatsVBox/StatsBody, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisBody, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayControlsPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayInfoPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashHivePanel/HiveVBox/HiveBody, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveActivityPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashStorePanel/StoreVBox/StoreBody, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel(store_landing_panel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel(store_category_view, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel(store_category_prefs_panel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($AsyncPanel/AsyncVBox/AsyncBody, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncQueuePanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncLeaderboardPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncSeasonPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel(async_weekly_panel, Color(0.06, 0.07, 0.1, 0.98), Color(0.45, 0.48, 0.58, 0.8))
	_style_panel(async_monthly_panel, Color(0.06, 0.07, 0.1, 0.98), Color(0.45, 0.48, 0.58, 0.8))
	_style_panel(async_yearly_panel, Color(0.06, 0.07, 0.1, 0.98), Color(0.45, 0.48, 0.58, 0.8))
	_style_panel($AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))

func _wire_buttons() -> void:
	play_button.pressed.connect(_on_play_pressed)
	$BottomBar/MenuButtons/LeftButtons/AsyncButton.pressed.connect(_open_async_panel)
	$BottomBar/MenuButtons/LeftButtons/BuffsButton.pressed.connect(func(): _open_dash_panel_from_menu(dash_buffs_panel))
	$BottomBar/MenuButtons/LeftButtons/StoreButton.pressed.connect(func(): _open_dash_panel_from_menu(dash_store_panel))
	$BottomBar/MenuButtons/RightButtons/ClanButton.pressed.connect(func(): _open_dash_panel_from_menu(dash_hive_panel))
	$BottomBar/MenuButtons/RightButtons/SettingsButton.pressed.connect(func(): _open_dash_panel_from_menu(dash_settings_panel))
	hive_button.pressed.connect(func(): _open_dash_panel_from_menu(dash_hive_panel))
	dash_tab.pressed.connect(_toggle_dash)
	dash_hex_buffs.pressed.connect(func(): _open_dash_panel(dash_buffs_panel))
	dash_hex_store.pressed.connect(func(): _open_dash_panel(dash_store_panel))
	dash_hex_hive.pressed.connect(func(): _open_dash_panel(dash_hive_panel))
	_wire_match_rows()
	_wire_badges()
	dash_stats_close.pressed.connect(func(): _close_dash_panel(dash_stats_panel))
	dash_analysis_close.pressed.connect(func(): _close_dash_panel(dash_analysis_panel))
	dash_replay_close.pressed.connect(func(): _close_dash_panel(dash_replay_panel))
	dash_buffs_close.pressed.connect(func(): _close_dash_panel(dash_buffs_panel))
	dash_hive_close.pressed.connect(func(): _close_dash_panel(dash_hive_panel))
	dash_store_close.pressed.connect(func(): _close_dash_panel(dash_store_panel))
	dash_settings_close.pressed.connect(func(): _close_dash_panel(dash_settings_panel))
	dash_badges_close.pressed.connect(func(): _close_dash_panel(dash_badges_panel_full))
	async_close.pressed.connect(_close_async_panel)
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncQueuePanel/AsyncQueueVBox/AsyncQueueAction.pressed.connect(_open_async_weekly)
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncLeaderboardPanel/AsyncLeaderboardVBox/AsyncLeaderboardAction.pressed.connect(_open_async_monthly)
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncSeasonPanel/AsyncSeasonVBox/AsyncSeasonAction.pressed.connect(_open_async_yearly)
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsAction.pressed.connect(_on_async_results_action_pressed)
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncRulesAction.pressed.connect(_on_async_rules_action_pressed)
	for idx in range(ASYNC_BUYINS.size()):
		var amount: int = ASYNC_BUYINS[idx]
		async_weekly_buyin_buttons[idx].pressed.connect(func(): _set_async_buyin("weekly", amount))
		async_monthly_buyin_buttons[idx].pressed.connect(func(): _set_async_buyin("monthly", amount))
		async_yearly_buyin_buttons[idx].pressed.connect(func(): _set_async_buyin("yearly", amount))
	var ladder_labels: PackedStringArray = PackedStringArray([
		"Ladder: Miss n Outs ($1/$5/$10/$20)",
		"Ladder: Timed Race (3-map sync start)",
		"Ladder: Timed Race (5-map sync start)",
		"Ladder: 3 Map Stage Race",
		"Ladder: 5 Map Stage Race"
	])
	var ladder_count: int = int(min(async_ladder_buttons.size(), ladder_labels.size()))
	for i in range(ladder_count):
		var ladder_button: Button = async_ladder_buttons[i] as Button
		if ladder_button != null:
			ladder_button.text = ladder_labels[i]
		if i == 0:
			async_ladder_buttons[i].pressed.connect(func(): _on_async_miss_n_out_selected(false))
			continue
		if i == 1:
			async_ladder_buttons[i].pressed.connect(func(): _on_async_timed_race_selected(3, false))
			continue
		if i == 2:
			async_ladder_buttons[i].pressed.connect(func(): _on_async_timed_race_selected(5, false))
			continue
		if i == 3:
			async_ladder_buttons[i].pressed.connect(func(): _on_async_stage_race_selected(3, false))
			continue
		if i == 4:
			async_ladder_buttons[i].pressed.connect(func(): _on_async_stage_race_selected(5, false))
			continue
		var label: String = ladder_labels[i]
		async_ladder_buttons[i].pressed.connect(func(): _stub_action(label))
	var free_labels: PackedStringArray = PackedStringArray([
		"Free Play: Miss n Outs",
		"Free Play: Timed Race (3-map sync start)",
		"Free Play: Timed Race (5-map sync start)",
		"Free Play: 3 Map Stage Race",
		"Free Play: 5 Map Stage Race"
	])
	var free_count: int = int(min(async_free_buttons.size(), free_labels.size()))
	for i in range(free_count):
		var free_button: Button = async_free_buttons[i] as Button
		if free_button != null:
			free_button.text = free_labels[i]
		if i == 0:
			async_free_buttons[i].pressed.connect(func(): _on_async_miss_n_out_selected(true))
			continue
		if i == 1:
			async_free_buttons[i].pressed.connect(func(): _on_async_timed_race_selected(3, true))
			continue
		if i == 2:
			async_free_buttons[i].pressed.connect(func(): _on_async_timed_race_selected(5, true))
			continue
		if i == 3:
			async_free_buttons[i].pressed.connect(func(): _on_async_stage_race_selected(3, true))
			continue
		if i == 4:
			async_free_buttons[i].pressed.connect(func(): _on_async_stage_race_selected(5, true))
			continue
		var label: String = free_labels[i]
		async_free_buttons[i].pressed.connect(func(): _stub_action(label))
	async_weekly_play.pressed.connect(func(): _on_async_play_pressed("weekly"))
	async_monthly_play.pressed.connect(func(): _on_async_play_pressed("monthly"))
	async_yearly_play.pressed.connect(func(): _on_async_play_pressed("yearly"))
	async_weekly_back.pressed.connect(_open_async_main)
	async_monthly_back.pressed.connect(_open_async_main)
	async_yearly_back.pressed.connect(_open_async_main)
	store_category_back.pressed.connect(_show_store_landing)
	store_prefs_toggle.toggled.connect(_on_store_prefs_toggled)
	stats_tier_free.pressed.connect(func(): _set_stats_tier("FREE"))
	stats_tier_bp.pressed.connect(func(): _set_stats_tier("BP"))
	stats_tier_elite.pressed.connect(func(): _set_stats_tier("ELITE"))
	_wire_buffs_buttons()

func _set_hex_buttons() -> void:
	hive_button.text = "HIVE"
	hive_button.font = _font_semibold
	hive_button.font_size = 16
	hive_button.fill_color = Color(0.16, 0.14, 0.12)
	hive_button.border_color = Color(0.95, 0.75, 0.25)
	hive_button.text_color = Color(0.98, 0.92, 0.72)
	dash_tab.text = "DASH"
	dash_tab.font = _font_semibold
	dash_tab.font_size = 14
	dash_tab.fill_color = Color(0.18, 0.19, 0.22)
	dash_tab.border_color = Color(0.55, 0.56, 0.62)
	dash_tab.text_color = Color(0.85, 0.86, 0.9)
	dash_tab.cut_side = HexButton.CUT_LEFT
	dash_tab.sprite_key = DASH_TAB_KEY_RIGHT
	dash_tab.queue_redraw()
	dash_hex_buffs.text = "BUFFS"
	dash_hex_buffs.font = _font_semibold
	dash_hex_buffs.font_size = 14
	dash_hex_buffs.fill_color = Color(0.16, 0.16, 0.2)
	dash_hex_buffs.border_color = Color(0.7, 0.72, 0.8)
	dash_hex_buffs.text_color = Color(0.92, 0.94, 0.98)
	dash_hex_store.text = "STORE"
	dash_hex_store.font = _font_semibold
	dash_hex_store.font_size = 14
	dash_hex_store.fill_color = Color(0.16, 0.16, 0.2)
	dash_hex_store.border_color = Color(0.7, 0.72, 0.8)
	dash_hex_store.text_color = Color(0.92, 0.94, 0.98)
	dash_hex_hive.text = "HIVE"
	dash_hex_hive.font = _font_semibold
	dash_hex_hive.font_size = 14
	dash_hex_hive.fill_color = Color(0.16, 0.16, 0.2)
	dash_hex_hive.border_color = Color(0.7, 0.72, 0.8)
	dash_hex_hive.text_color = Color(0.92, 0.94, 0.98)

func _apply_font(node: Control, font: Font, size: int) -> void:
	if node == null or font == null:
		return
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)

func _apply_player_profile(profile: Dictionary) -> void:
	var tier_text := str(profile.get("tier_text", "Tier: Bronze"))
	var honey_value := int(profile.get("honey", 0))
	var honey_text := "Honey: %s" % _format_number(honey_value)
	$TopBar/RankLabel.text = tier_text
	$TopBar/HoneyLabel.text = honey_text
	$DashPanel/DashTopBar/DashRankLabel.text = tier_text
	$DashPanel/DashTopBar/DashHoneyLabel.text = honey_text

func _format_number(value: int) -> String:
	var negative := value < 0
	var digits := str(abs(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3, 3) + out
		digits = digits.substr(0, digits.length() - 3)
	out = digits + out
	if negative:
		out = "-" + out
	return out

func _style_button(button: Button, bg: Color, border: Color, text_color: Color) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.border_width_bottom = 2
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.08)
	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)

func _style_panel(panel: Panel, bg: Color, border: Color) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	panel.add_theme_stylebox_override("panel", style)

func _style_dash_buttons() -> void:
	for i in range(1, 6):
		var row_path := "DashPanel/DashRoot/MatchHistoryPanel/MatchCenter/MatchVBox/MatchList/MatchRow%d" % i
		for button_name in ["MatchStats", "MatchAnalytics", "MatchReplay"]:
			var button: Button = get_node("%s/%s" % [row_path, button_name])
			_apply_font(button, _font_regular, 12)
			_style_button(button, Color(0.1, 0.11, 0.14), Color(0.4, 0.42, 0.5), Color(0.92, 0.92, 0.92))
	for badge_name in ["BadgeButton1", "BadgeButton2", "BadgeButton3", "BadgeButton4"]:
		var badge_button: Button = get_node("DashPanel/DashRoot/BadgesPanel/BadgesVBox/BadgesRow/%s" % badge_name)
		_apply_font(badge_button, _font_semibold, 14)
		_style_button(badge_button, Color(0.16, 0.14, 0.1), Color(0.75, 0.65, 0.35), Color(0.98, 0.94, 0.8))
	for button in [dash_stats_close, dash_analysis_close, dash_replay_close, dash_buffs_close, dash_hive_close, dash_store_close, dash_settings_close, dash_badges_close, async_close]:
		_apply_font(button, _font_regular, 14)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	_set_stats_tier(_stats_tier)

func _wire_match_rows() -> void:
	for i in range(1, 6):
		var row_path := "DashPanel/DashRoot/MatchHistoryPanel/MatchCenter/MatchVBox/MatchList/MatchRow%d" % i
		var stats: Button = get_node("%s/MatchStats" % row_path)
		var analytics: Button = get_node("%s/MatchAnalytics" % row_path)
		var replay: Button = get_node("%s/MatchReplay" % row_path)
		var match_index := i - 1
		stats.pressed.connect(func(): _open_match_stats(match_index))
		analytics.pressed.connect(func(): _open_match_analysis(match_index))
		replay.pressed.connect(func(): _open_match_replay(match_index))

func _wire_badges() -> void:
	for badge_name in ["BadgeButton1", "BadgeButton2", "BadgeButton3", "BadgeButton4"]:
		var badge_button: Button = get_node("DashPanel/DashRoot/BadgesPanel/BadgesVBox/BadgesRow/%s" % badge_name)
		badge_button.pressed.connect(func(): _open_dash_panel(dash_badges_panel_full))

func _wire_buffs_buttons() -> void:
	for idx in range(buffs_slot_buttons.size()):
		var slot_button: Button = buffs_slot_buttons[idx] as Button
		if slot_button == null:
			continue
		var press_cb: Callable = Callable(self, "_on_buff_loadout_pressed").bind(idx)
		if not slot_button.pressed.is_connected(press_cb):
			slot_button.pressed.connect(press_cb)
		var input_cb: Callable = Callable(self, "_on_buff_loadout_gui_input").bind(idx)
		if not slot_button.gui_input.is_connected(input_cb):
			slot_button.gui_input.connect(input_cb)
	if buffs_detail_buttons.size() >= 2:
		var equip_button: Button = buffs_detail_buttons[0] as Button
		var remove_button: Button = buffs_detail_buttons[1] as Button
		if equip_button != null and not equip_button.pressed.is_connected(_on_buff_equip_pressed):
			equip_button.pressed.connect(_on_buff_equip_pressed)
		if remove_button != null and not remove_button.pressed.is_connected(_on_buff_remove_pressed):
			remove_button.pressed.connect(_on_buff_remove_pressed)

func _apply_buffs_panel_layout() -> void:
	_ensure_buffs_loadout_top_panel()
	if buffs_top_row != null:
		buffs_top_row.add_theme_constant_override("separation", 10)
	if buffs_loadout_panel != null:
		buffs_loadout_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buffs_loadout_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		buffs_loadout_panel.size_flags_stretch_ratio = 1.0
	if buffs_loadout_vbox != null:
		buffs_loadout_vbox.add_theme_constant_override("separation", 10)
	if buffs_slots_row != null:
		buffs_slots_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		buffs_slots_row.size_flags_stretch_ratio = 1.0
	if buffs_library_panel != null:
		buffs_library_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buffs_library_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		buffs_library_panel.size_flags_stretch_ratio = 1.35
	if buffs_library_vbox != null:
		buffs_library_vbox.add_theme_constant_override("separation", 8)
	if buffs_detail_panel != null:
		buffs_detail_panel.visible = false

func _ensure_buffs_loadout_top_panel() -> void:
	if _buff_loadout_top_panel != null and is_instance_valid(_buff_loadout_top_panel):
		return
	if buffs_loadout_vbox == null:
		return
	var existing: Panel = buffs_loadout_vbox.get_node_or_null("LoadoutTopPanel") as Panel
	if existing != null:
		_buff_loadout_top_panel = existing
		return
	var header: Label = buffs_loadout_vbox.get_node_or_null("BuffsLoadoutHeader") as Label
	if header == null or buffs_slots_row == null:
		return
	if header.get_parent() != buffs_loadout_vbox or buffs_slots_row.get_parent() != buffs_loadout_vbox:
		return
	var panel: Panel = Panel.new()
	panel.name = "LoadoutTopPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.1
	panel.custom_minimum_size = Vector2(0, 154)
	buffs_loadout_vbox.add_child(panel)
	buffs_loadout_vbox.move_child(panel, 0)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.name = "LoadoutTopVBox"
	inner.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	inner.offset_left = 8.0
	inner.offset_top = 8.0
	inner.offset_right = -8.0
	inner.offset_bottom = -8.0
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)
	buffs_loadout_vbox.remove_child(header)
	buffs_loadout_vbox.remove_child(buffs_slots_row)
	inner.add_child(header)
	inner.add_child(buffs_slots_row)
	_style_panel(panel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_buff_loadout_top_panel = panel

func _init_buffs_ui() -> void:
	ProfileManager.ensure_loaded()
	_buff_library_all.clear()
	var library_any: Variant = BuffCatalog.list_all()
	if typeof(library_any) == TYPE_ARRAY:
		for buff_v in library_any as Array:
			if typeof(buff_v) != TYPE_DICTIONARY:
				continue
			_buff_library_all.append(buff_v as Dictionary)
	_buff_library_all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", a.get("id", ""))) < str(b.get("name", b.get("id", "")))
	)
	_apply_buffs_panel_layout()
	_ensure_buffs_owned_panel()
	_ensure_buffs_library_nav()
	_load_buff_profile_state()
	_refresh_buffs_library_buttons()
	_refresh_buffs_owned_ui()
	_refresh_buffs_loadout_ui()
	if buffs_footer_label != null:
		buffs_footer_label.text = "Store -> Owned -> Loadout. Multi-select in Library, then drag to Owned."
	if not _buff_loadout_ids.is_empty():
		_set_selected_buff(_buff_loadout_ids[0], "loadout", 0)
	else:
		_update_buff_details()

func _ensure_buffs_owned_panel() -> void:
	if _buff_owned_panel != null and is_instance_valid(_buff_owned_panel):
		return
	if buffs_loadout_vbox == null:
		return
	var panel: Panel = Panel.new()
	panel.name = "BuffsOwnedPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 2.9
	panel.custom_minimum_size = Vector2(0, 0)
	buffs_loadout_vbox.add_child(panel)
	var owned_vbox: VBoxContainer = VBoxContainer.new()
	owned_vbox.name = "OwnedVBox"
	owned_vbox.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	owned_vbox.offset_left = 8.0
	owned_vbox.offset_top = 8.0
	owned_vbox.offset_right = -8.0
	owned_vbox.offset_bottom = -8.0
	owned_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(owned_vbox)
	var header: Label = Label.new()
	header.name = "OwnedHeader"
	header.text = "OWNED"
	owned_vbox.add_child(header)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "OwnedScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	owned_vbox.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "OwnedList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var empty_label: Label = Label.new()
	empty_label.name = "OwnedEmpty"
	empty_label.text = "Drag selected buffs from Library to add ownership."
	list.add_child(empty_label)
	_buff_owned_panel = panel
	_buff_owned_header_label = header
	_buff_owned_empty_label = empty_label
	_buff_owned_flow = list
	_style_panel(panel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_apply_font(header, _font_semibold, 13)
	_apply_font(empty_label, _font_regular, 12)

func _ensure_buffs_library_nav() -> void:
	if buffs_library_vbox == null:
		return
	var legacy_list: Control = buffs_library_vbox.get_node_or_null("BuffsLibraryList") as Control
	if legacy_list != null:
		legacy_list.visible = false
	for button_any in buffs_library_buttons:
		var old_button: Button = button_any as Button
		if old_button == null:
			continue
		old_button.visible = false
	if _buff_library_tier_root != null and is_instance_valid(_buff_library_tier_root):
		return
	var tier_root: VBoxContainer = VBoxContainer.new()
	tier_root.name = "BuffLibraryTierRoot"
	tier_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tier_root.add_theme_constant_override("separation", 8)
	buffs_library_vbox.add_child(tier_root)
	_buff_library_scroll = null
	_buff_library_tier_root = tier_root
	_buff_library_tier_grids.clear()
	_buff_library_tier_headers.clear()
	for tier_id in BUFF_LIBRARY_TIERS:
		var panel: Panel = Panel.new()
		panel.name = "Tier_%s" % tier_id
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 1.0
		tier_root.add_child(panel)
		_style_panel(panel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
		var tier_vbox: VBoxContainer = VBoxContainer.new()
		tier_vbox.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		tier_vbox.offset_left = 8.0
		tier_vbox.offset_top = 8.0
		tier_vbox.offset_right = -8.0
		tier_vbox.offset_bottom = -8.0
		tier_vbox.add_theme_constant_override("separation", 6)
		panel.add_child(tier_vbox)
		var header: Label = Label.new()
		header.text = tier_id.to_upper()
		tier_vbox.add_child(header)
		_apply_font(header, _font_semibold, 12)
		var tier_scroll: ScrollContainer = ScrollContainer.new()
		tier_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tier_vbox.add_child(tier_scroll)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		tier_scroll.add_child(grid)
		_buff_library_tier_grids[tier_id] = grid
		_buff_library_tier_headers[tier_id] = header

func _load_buff_profile_state() -> void:
	var owned_any: Variant = ProfileManager.call("get_owned_buff_ids") if ProfileManager.has_method("get_owned_buff_ids") else []
	_buff_owned_ids.clear()
	if typeof(owned_any) == TYPE_ARRAY:
		for buff_id_v in owned_any as Array:
			var buff_id: String = str(buff_id_v).strip_edges()
			if buff_id == "" or BuffCatalog.get_buff(buff_id).is_empty():
				continue
			if _buff_owned_ids.has(buff_id):
				continue
			_buff_owned_ids.append(buff_id)
	var loadout_any: Variant = ProfileManager.call("get_buff_loadout_ids") if ProfileManager.has_method("get_buff_loadout_ids") else []
	_buff_loadout_ids.clear()
	if typeof(loadout_any) == TYPE_ARRAY:
		for buff_id_v in loadout_any as Array:
			var buff_id: String = str(buff_id_v).strip_edges()
			if buff_id == "" or BuffCatalog.get_buff(buff_id).is_empty():
				continue
			if _buff_loadout_ids.has(buff_id):
				continue
			_buff_loadout_ids.append(buff_id)
	while _buff_loadout_ids.size() < BUFF_LOADOUT_SIZE:
		var fallback: String = _fallback_buff_for_index(_buff_loadout_ids.size())
		if fallback == "" or _buff_loadout_ids.has(fallback):
			break
		_buff_loadout_ids.append(fallback)
	for buff_id in _buff_loadout_ids:
		if buff_id == "" or _buff_owned_ids.has(buff_id):
			continue
		_buff_owned_ids.append(buff_id)
	_persist_buff_profile_state()

func _persist_buff_profile_state() -> void:
	if ProfileManager.has_method("set_owned_buff_ids"):
		ProfileManager.call("set_owned_buff_ids", _buff_owned_ids)
	if ProfileManager.has_method("set_buff_loadout_ids"):
		ProfileManager.call("set_buff_loadout_ids", _buff_loadout_ids)

func _fallback_buff_for_index(idx: int) -> String:
	var defaults: Array[String] = [
		"buff_swarm_speed_classic",
		"buff_hive_faster_production_classic",
		"buff_tower_fire_rate_classic"
	]
	if idx >= 0 and idx < defaults.size():
		return defaults[idx]
	if not _buff_library_all.is_empty():
		return str(_buff_library_all[0].get("id", ""))
	return ""

func _refresh_buffs_library_buttons() -> void:
	for button in _buff_library_runtime_buttons:
		if button != null and is_instance_valid(button):
			button.queue_free()
	_buff_library_runtime_buttons.clear()
	var counts: Dictionary = {"classic": 0, "premium": 0, "elite": 0}
	for buff in _buff_library_all:
		var tier_id: String = str(buff.get("tier", "classic")).to_lower()
		if not _buff_library_tier_grids.has(tier_id):
			continue
		counts[tier_id] = int(counts.get(tier_id, 0)) + 1
		var buff_id: String = str(buff.get("id", ""))
		var selected: bool = bool(_buff_library_selected_ids.get(buff_id, false))
		var selected_mark: String = "[x] " if selected else "[ ] "
		var button: Button = Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 26.0)
		button.clip_text = true
		button.text = "%s%s" % [selected_mark, str(buff.get("name", buff_id))]
		_apply_font(button, _font_regular, 11)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
		var press_cb: Callable = Callable(self, "_on_buff_library_pressed_by_id").bind(buff_id)
		if not button.pressed.is_connected(press_cb):
			button.pressed.connect(press_cb)
		var input_cb: Callable = Callable(self, "_on_buff_library_gui_input_by_id").bind(buff_id)
		if not button.gui_input.is_connected(input_cb):
			button.gui_input.connect(input_cb)
		var grid: GridContainer = _buff_library_tier_grids[tier_id] as GridContainer
		grid.add_child(button)
		_buff_library_runtime_buttons.append(button)
	for tier_id in BUFF_LIBRARY_TIERS:
		var header: Label = _buff_library_tier_headers[tier_id] as Label
		if header != null:
			header.text = "%s (%d)" % [tier_id.to_upper(), int(counts.get(tier_id, 0))]
	if buffs_library_header != null:
		buffs_library_header.text = "BUFF STORE (%d)" % _buff_library_all.size()

func _refresh_buffs_owned_ui() -> void:
	if _buff_owned_flow == null:
		return
	for button in _buff_owned_buttons:
		if button != null and is_instance_valid(button):
			button.queue_free()
	_buff_owned_buttons.clear()
	if _buff_owned_empty_label != null:
		_buff_owned_empty_label.visible = _buff_owned_ids.is_empty()
	if _buff_owned_ids.is_empty():
		return
	for buff_id in _buff_owned_ids:
		var buff: Dictionary = BuffCatalog.get_buff(buff_id)
		if buff.is_empty():
			continue
		var button: Button = Button.new()
		button.text = str(buff.get("name", buff_id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 28.0)
		button.clip_text = true
		_style_button(button, Color(0.10, 0.11, 0.14), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
		_apply_font(button, _font_regular, 11)
		var selected: bool = _buff_selected_origin == "owned" and _buff_selected_id == buff_id
		if selected:
			button.text = "> " + button.text
		var press_cb: Callable = Callable(self, "_on_buff_owned_pressed").bind(buff_id)
		if not button.pressed.is_connected(press_cb):
			button.pressed.connect(press_cb)
		var input_cb: Callable = Callable(self, "_on_buff_owned_gui_input").bind(buff_id)
		if not button.gui_input.is_connected(input_cb):
			button.gui_input.connect(input_cb)
		_buff_owned_flow.add_child(button)
		_buff_owned_buttons.append(button)
	if _buff_owned_header_label != null:
		_buff_owned_header_label.text = "OWNED (%d)" % _buff_owned_ids.size()

func _refresh_buffs_loadout_ui() -> void:
	for idx in range(buffs_slot_buttons.size()):
		var button: Button = buffs_slot_buttons[idx] as Button
		if button == null:
			continue
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 28.0)
		button.clip_text = true
		if idx >= BUFF_LOADOUT_SIZE:
			button.visible = false
			continue
		button.visible = true
		button.disabled = false
		var buff_id: String = _buff_loadout_ids[idx] if idx < _buff_loadout_ids.size() else ""
		var buff: Dictionary = BuffCatalog.get_buff(buff_id)
		var label: String = "Slot %d" % (idx + 1)
		if not buff.is_empty():
			label = "%d: %s" % [idx + 1, str(buff.get("name", buff_id))]
		if _buff_selected_origin == "loadout" and _buff_selected_slot_index == idx:
			label = "> " + label
		button.text = label

func _set_selected_buff(buff_id: String, origin: String, slot_index: int = -1) -> void:
	_buff_selected_id = buff_id
	_buff_selected_origin = origin
	_buff_selected_slot_index = slot_index
	_update_buff_details()
	_refresh_buffs_loadout_ui()
	_refresh_buffs_owned_ui()

func _update_buff_details() -> void:
	var buff: Dictionary = BuffCatalog.get_buff(_buff_selected_id)
	if buff.is_empty():
		if buffs_detail_name_label != null:
			buffs_detail_name_label.text = "Select a buff"
		if buffs_detail_desc_label != null:
			buffs_detail_desc_label.text = "Library is the store. Select one or many, then drag into Owned."
		if buffs_detail_meta_label != null:
			buffs_detail_meta_label.text = "Drag Owned into Loadout slots to equip."
		return
	if buffs_detail_name_label != null:
		buffs_detail_name_label.text = str(buff.get("name", _buff_selected_id))
	if buffs_detail_desc_label != null:
		buffs_detail_desc_label.text = _buff_description(buff)
	if buffs_detail_meta_label != null:
		var tier: String = str(buff.get("tier", "classic")).to_upper()
		var category: String = str(buff.get("category", "unknown"))
		var origin_tag: String = _buff_selected_origin.to_upper()
		buffs_detail_meta_label.text = "Tier: %s | Category: %s | Source: %s" % [tier, category, origin_tag]

func _buff_description(buff: Dictionary) -> String:
	var effects_any: Variant = buff.get("effects", [])
	if typeof(effects_any) != TYPE_ARRAY:
		return "No details yet."
	var effect_lines: Array[String] = []
	for effect_v in effects_any as Array:
		if typeof(effect_v) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_v as Dictionary
		var effect_type: String = str(effect.get("type", "effect"))
		var value: Variant = effect.get("value", "")
		effect_lines.append("%s=%s" % [effect_type, str(value)])
	if effect_lines.is_empty():
		return "No details yet."
	return ", ".join(effect_lines)

func _on_buff_library_pressed(index: int) -> void:
	# Legacy static-list path; tiered buttons use _on_buff_library_pressed_by_id.
	if index < 0:
		return

func _on_buff_library_gui_input(event: InputEvent, index: int) -> void:
	# Legacy static-list path; tiered buttons use _on_buff_library_gui_input_by_id.
	if event == null or index < 0:
		return

func _on_buff_library_pressed_by_id(buff_id: String) -> void:
	var selected: bool = bool(_buff_library_selected_ids.get(buff_id, false))
	_buff_library_selected_ids[buff_id] = not selected
	_set_selected_buff(buff_id, "library", -1)
	_refresh_buffs_library_buttons()

func _on_buff_library_gui_input_by_id(event: InputEvent, buff_id: String) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var payload: Array[String] = [buff_id]
			if bool(_buff_library_selected_ids.get(buff_id, false)):
				payload = _selected_library_ids()
			_begin_buff_drag("library", payload, mb.position, -1)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			var payload: Array[String] = [buff_id]
			if bool(_buff_library_selected_ids.get(buff_id, false)):
				payload = _selected_library_ids()
			_begin_buff_drag("library", payload, st.position, -1)

func _selected_library_ids() -> Array[String]:
	var out: Array[String] = []
	for buff_id_any in _buff_library_selected_ids.keys():
		var buff_id: String = str(buff_id_any)
		if not bool(_buff_library_selected_ids.get(buff_id, false)):
			continue
		out.append(buff_id)
	out.sort()
	return out

func _on_buff_owned_pressed(buff_id: String) -> void:
	_set_selected_buff(buff_id, "owned", -1)

func _on_buff_owned_gui_input(event: InputEvent, buff_id: String) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_begin_buff_drag("owned", [buff_id], mb.position, -1)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_begin_buff_drag("owned", [buff_id], st.position, -1)

func _on_buff_loadout_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= BUFF_LOADOUT_SIZE:
		return
	if slot_index >= _buff_loadout_ids.size():
		return
	_set_selected_buff(_buff_loadout_ids[slot_index], "loadout", slot_index)

func _on_buff_loadout_gui_input(event: InputEvent, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= BUFF_LOADOUT_SIZE:
		return
	if slot_index >= _buff_loadout_ids.size():
		return
	var buff_id: String = _buff_loadout_ids[slot_index]
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_begin_buff_drag("loadout", [buff_id], mb.position, slot_index)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_begin_buff_drag("loadout", [buff_id], st.position, slot_index)

func _begin_buff_drag(source: String, payload: Array[String], start_screen: Vector2, slot_index: int) -> void:
	if payload.is_empty():
		return
	_buff_drag_state = {
		"active": false,
		"source": source,
		"start_screen": start_screen,
		"payload": payload.duplicate(),
		"slot_index": slot_index
	}
	status_label.text = "Hold and drag to drop buff(s)."

func _update_buff_drag(screen_pos: Vector2) -> void:
	if _buff_drag_state.is_empty():
		return
	var active: bool = bool(_buff_drag_state.get("active", false))
	if active:
		return
	var start: Vector2 = _buff_drag_state.get("start_screen", screen_pos)
	if start.distance_to(screen_pos) < BUFF_DRAG_MIN_PX:
		return
	_buff_drag_state["active"] = true
	var payload: Array = _buff_drag_state.get("payload", [])
	var source: String = str(_buff_drag_state.get("source", ""))
	if source == "library":
		status_label.text = "Drop on OWNED to add %d buff(s)." % payload.size()
	elif source == "owned":
		status_label.text = "Drop on a LOADOUT slot to equip."
	elif source == "loadout":
		status_label.text = "Drop on another LOADOUT slot to swap."

func _finish_buff_drag(screen_pos: Vector2) -> void:
	if _buff_drag_state.is_empty():
		return
	var was_active: bool = bool(_buff_drag_state.get("active", false))
	var source: String = str(_buff_drag_state.get("source", ""))
	var payload: Array = _buff_drag_state.get("payload", [])
	var slot_index: int = int(_buff_drag_state.get("slot_index", -1))
	_buff_drag_state.clear()
	if not was_active:
		return
	var payload_ids: Array[String] = []
	for buff_id_v in payload:
		var buff_id: String = str(buff_id_v).strip_edges()
		if buff_id == "" or payload_ids.has(buff_id):
			continue
		payload_ids.append(buff_id)
	if payload_ids.is_empty():
		return
	if source == "library":
		if _control_contains_screen(_buff_owned_panel, screen_pos):
			_drop_library_to_owned(payload_ids)
			return
	elif source == "owned":
		var target_slot: int = _slot_index_at_screen(screen_pos)
		if target_slot >= 0:
			_drop_owned_to_loadout(payload_ids[0], target_slot)
			return
	elif source == "loadout":
		var target_slot: int = _slot_index_at_screen(screen_pos)
		if target_slot >= 0 and slot_index >= 0 and slot_index < BUFF_LOADOUT_SIZE:
			_swap_loadout_slots(slot_index, target_slot)
			return
	status_label.text = "Drop cancelled."

func _drop_library_to_owned(ids: Array[String]) -> void:
	var added: int = 0
	for buff_id in ids:
		if BuffCatalog.get_buff(buff_id).is_empty():
			continue
		if _buff_owned_ids.has(buff_id):
			continue
		_buff_owned_ids.append(buff_id)
		added += 1
	_persist_buff_profile_state()
	_refresh_buffs_owned_ui()
	if added > 0:
		status_label.text = "Added %d buff(s) to Owned." % added
	else:
		status_label.text = "All selected buffs already owned."

func _drop_owned_to_loadout(buff_id: String, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= BUFF_LOADOUT_SIZE:
		return
	if not _buff_owned_ids.has(buff_id):
		status_label.text = "You must own a buff before equipping."
		return
	while _buff_loadout_ids.size() < BUFF_LOADOUT_SIZE:
		_buff_loadout_ids.append(_fallback_buff_for_index(_buff_loadout_ids.size()))
	var existing_slot: int = _buff_loadout_ids.find(buff_id)
	if existing_slot == slot_index:
		status_label.text = "Already equipped to slot %d." % (slot_index + 1)
		return
	if existing_slot >= 0 and existing_slot < BUFF_LOADOUT_SIZE:
		var displaced: String = _buff_loadout_ids[slot_index]
		_buff_loadout_ids[existing_slot] = displaced
	_buff_loadout_ids[slot_index] = buff_id
	_persist_buff_profile_state()
	_set_selected_buff(buff_id, "loadout", slot_index)
	status_label.text = "Equipped to slot %d." % (slot_index + 1)

func _swap_loadout_slots(a: int, b: int) -> void:
	if a == b:
		return
	if a < 0 or a >= BUFF_LOADOUT_SIZE or b < 0 or b >= BUFF_LOADOUT_SIZE:
		return
	while _buff_loadout_ids.size() < BUFF_LOADOUT_SIZE:
		_buff_loadout_ids.append(_fallback_buff_for_index(_buff_loadout_ids.size()))
	var tmp: String = _buff_loadout_ids[a]
	_buff_loadout_ids[a] = _buff_loadout_ids[b]
	_buff_loadout_ids[b] = tmp
	_persist_buff_profile_state()
	_refresh_buffs_loadout_ui()
	status_label.text = "Loadout slots swapped."

func _slot_index_at_screen(screen_pos: Vector2) -> int:
	for idx in range(BUFF_LOADOUT_SIZE):
		var button: Button = buffs_slot_buttons[idx] as Button
		if _control_contains_screen(button, screen_pos):
			return idx
	return -1

func _control_contains_screen(control: Control, screen_pos: Vector2) -> bool:
	if control == null:
		return false
	return control.get_global_rect().has_point(screen_pos)

func _on_buff_equip_pressed() -> void:
	if _buff_selected_id == "":
		return
	if _buff_selected_origin == "library":
		_drop_library_to_owned([_buff_selected_id])
		return
	if _buff_selected_origin == "owned":
		_drop_owned_to_loadout(_buff_selected_id, 0)
		return

func _on_buff_remove_pressed() -> void:
	if _buff_selected_id == "":
		return
	if _buff_selected_origin == "library":
		if _buff_library_selected_ids.has(_buff_selected_id):
			_buff_library_selected_ids.erase(_buff_selected_id)
			_refresh_buffs_library_buttons()
			status_label.text = "Unselected from batch."
		return
	if _buff_selected_origin == "owned":
		if _buff_loadout_ids.has(_buff_selected_id):
			status_label.text = "Cannot remove: buff is equipped in loadout."
			return
		if _buff_owned_ids.has(_buff_selected_id):
			_buff_owned_ids.erase(_buff_selected_id)
			_persist_buff_profile_state()
			_refresh_buffs_owned_ui()
			_set_selected_buff("", "", -1)
			status_label.text = "Removed from Owned."
		return
	if _buff_selected_origin == "loadout":
		var slot_idx: int = _buff_selected_slot_index
		if slot_idx < 0 or slot_idx >= BUFF_LOADOUT_SIZE:
			return
		var replacement: String = _first_owned_not_in_loadout(slot_idx)
		if replacement == "":
			status_label.text = "No replacement buff available."
			return
		_buff_loadout_ids[slot_idx] = replacement
		_persist_buff_profile_state()
		_set_selected_buff(replacement, "loadout", slot_idx)
		status_label.text = "Loadout slot %d replaced." % (slot_idx + 1)

func _first_owned_not_in_loadout(exclude_slot: int) -> String:
	for buff_id in _buff_owned_ids:
		var used_elsewhere: bool = false
		for idx in range(mini(_buff_loadout_ids.size(), BUFF_LOADOUT_SIZE)):
			if idx == exclude_slot:
				continue
			if _buff_loadout_ids[idx] == buff_id:
				used_elsewhere = true
				break
		if not used_elsewhere:
			return buff_id
	return ""

func _on_buff_library_prev_pressed() -> void:
	_refresh_buffs_library_buttons()

func _on_buff_library_next_pressed() -> void:
	_refresh_buffs_library_buttons()

func _build_store_landing() -> void:
	_clear_store_buttons()
	for category in STORE_CATEGORIES:
		var button := Button.new()
		button.text = category.get("title", "Category")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var category_id := str(category.get("id", ""))
		button.pressed.connect(func(): _open_store_category(category_id))
		store_category_grid.add_child(button)
		_apply_font(button, _font_semibold, 14)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
		_store_category_buttons.append(button)
	_show_store_landing()

func _open_store_category(category_id: String) -> void:
	var category := _get_store_category(category_id)
	store_category_header.text = category.get("title", "Category")
	store_category_sub.text = category.get("desc", "Browse items.")
	_populate_store_category(category_id)
	_update_store_prefs_visibility(category_id)
	store_landing_panel.visible = false
	store_category_view.visible = true

func _show_store_landing() -> void:
	store_category_view.visible = false
	store_category_prefs_panel.visible = false
	store_landing_panel.visible = true

func _populate_store_category(category_id: String) -> void:
	for child in store_category_list.get_children():
		child.queue_free()
	_store_sku_buttons.clear()
	for sku: Dictionary in STORE_SKUS:
		if str(sku.get("category", "")) != category_id:
			continue
		var button := Button.new()
		button.text = _format_store_sku_label(sku)
		button.tooltip_text = str(sku.get("description", ""))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): _on_store_sku_pressed(sku))
		store_category_list.add_child(button)
		_apply_font(button, _font_regular, 13)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
		_store_sku_buttons.append(button)
	if store_category_list.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "No items yet."
		_apply_font(empty_label, _font_regular, 12)
		store_category_list.add_child(empty_label)

func _format_store_sku_label(sku: Dictionary) -> String:
	var title := str(sku.get("title", "Item"))
	var price := _format_store_price(sku)
	if sku.get("is_bundle", false):
		title = "Bundle: %s" % title
	if price.is_empty():
		return title
	return "%s — %s" % [title, price]

func _format_store_price(sku: Dictionary) -> String:
	if sku.has("price_honey"):
		return "Honey %s" % str(sku.get("price_honey", 0))
	if sku.has("price_real"):
		return str(sku.get("price_real", ""))
	return ""

func _get_store_category(category_id: String) -> Dictionary:
	for category in STORE_CATEGORIES:
		if str(category.get("id", "")) == category_id:
			return category
	return {}

func _update_store_prefs_visibility(category_id: String) -> void:
	var show_prefs := category_id == "Passes" and _has_entitlement("zero_ads")
	store_category_prefs_panel.visible = show_prefs
	if show_prefs:
		store_prefs_toggle.button_pressed = _prefer_zero_ads
		store_prefs_toggle.text = "ON" if _prefer_zero_ads else "OFF"

func _on_store_prefs_toggled(enabled: bool) -> void:
	_prefer_zero_ads = enabled
	store_prefs_toggle.text = "ON" if _prefer_zero_ads else "OFF"

func _has_entitlement(flag: String) -> bool:
	return bool(_store_owned_entitlements.get(flag, false))

func _on_store_sku_pressed(sku: Dictionary) -> void:
	var title := str(sku.get("title", "Item"))
	status_label.text = "Store: %s" % title

func _clear_store_buttons() -> void:
	for child in store_category_grid.get_children():
		child.queue_free()
	_store_category_buttons.clear()
	for child in store_category_list.get_children():
		child.queue_free()
	_store_sku_buttons.clear()

func _load_match_history() -> void:
	for i in range(1, 6):
		var row_path := "DashPanel/DashRoot/MatchHistoryPanel/MatchCenter/MatchVBox/MatchList/MatchRow%d" % i
		var match_data := _get_match_data(i - 1)
		get_node("%s/MatchTitle" % row_path).text = match_data.get("title", "Match")
		get_node("%s/MatchResult" % row_path).text = match_data.get("result", "-")
		get_node("%s/MatchEff" % row_path).text = match_data.get("eff", "HE --")
	_current_match_index = 0
	var first_match := _get_match_data(_current_match_index)
	dash_stats_sub.text = "Match: %s" % first_match.get("title", "Match")
	dash_analysis_sub.text = "AI analysis with timestamps — %s" % first_match.get("title", "Match")
	dash_replay_sub.text = "Replay breakdown — %s" % first_match.get("title", "Match")
	_set_stats_tier(_stats_tier)
	_apply_analysis_lines(first_match)
	_apply_replay_data(first_match)

func _get_match_data(index: int) -> Dictionary:
	if MATCH_HISTORY.is_empty():
		return {}
	if index < 0 or index >= MATCH_HISTORY.size():
		return MATCH_HISTORY[0]
	return MATCH_HISTORY[index]

func _get_match_stats_tiers() -> Dictionary:
	var match_data := _get_match_data(_current_match_index)
	var tiers: Dictionary = match_data.get("stats_tiers", {})
	if tiers.is_empty():
		return DEFAULT_STATS_TIERS
	return tiers

func _apply_analysis_lines(match_data: Dictionary) -> void:
	var lines: Array = match_data.get("analysis", [])
	for i in range(analysis_lines.size()):
		var label: Label = analysis_lines[i]
		if i < lines.size():
			label.text = lines[i]
		else:
			label.text = ""

func _apply_replay_data(match_data: Dictionary) -> void:
	var mode: String = str(match_data.get("mode", "4P Rumble"))
	var map_name: String = str(match_data.get("map", "Map A"))
	var duration: String = str(match_data.get("duration", "3:12"))
	replay_info_lines[0].text = "Mode: %s" % mode
	replay_info_lines[1].text = "Map: %s" % map_name
	replay_info_lines[2].text = "Duration: %s" % duration
	var timeline: Array = match_data.get("timeline", [])
	for i in range(replay_timeline_times.size()):
		var time_label: Label = replay_timeline_times[i]
		var event_label: Label = replay_timeline_events[i]
		if i < timeline.size():
			var entry: Dictionary = timeline[i]
			time_label.text = entry.get("t", "--:--")
			event_label.text = entry.get("event", "Event")
		else:
			time_label.text = ""
			event_label.text = ""

func _open_match_stats(match_index: int) -> void:
	_current_match_index = match_index
	var match_data := _get_match_data(match_index)
	dash_stats_sub.text = "Match: %s" % match_data.get("title", "Match")
	_set_stats_tier("FREE")
	_open_dash_panel(dash_stats_panel)

func _open_match_analysis(match_index: int) -> void:
	_current_match_index = match_index
	var match_data := _get_match_data(match_index)
	dash_analysis_sub.text = "AI analysis with timestamps — %s" % match_data.get("title", "Match")
	_apply_analysis_lines(match_data)
	_open_dash_panel(dash_analysis_panel)

func _open_match_replay(match_index: int) -> void:
	_current_match_index = match_index
	var match_data := _get_match_data(match_index)
	dash_replay_sub.text = "Replay breakdown — %s" % match_data.get("title", "Match")
	_apply_replay_data(match_data)
	_open_dash_panel(dash_replay_panel)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/VSMenu.tscn")


func _open_play_mode_select() -> void:
	if _play_mode_select == null:
		_play_mode_select = preload("res://scenes/ui/PlayModeSelect.tscn").instantiate()
		_play_mode_select.closed.connect(func():
			_play_mode_select.queue_free()
			_play_mode_select = null
		)
		add_child(_play_mode_select)
	_play_mode_select.visible = true

func _toggle_dash() -> void:
	if _dash_tween != null and _dash_tween.is_running():
		_dash_tween.kill()
	var target_x := 0.0 if not _dash_open else _dash_hidden_x
	var target_tab_left := _dash_tab_open_left if not _dash_open else _dash_tab_closed_left
	var target_tab_right := _dash_tab_open_right if not _dash_open else _dash_tab_closed_right
	dash_tab.cut_side = HexButton.CUT_RIGHT if not _dash_open else HexButton.CUT_LEFT
	dash_tab.sprite_key = DASH_TAB_KEY_LEFT if not _dash_open else DASH_TAB_KEY_RIGHT
	dash_tab.queue_redraw()
	dash_panel.visible = true
	_dash_tween = create_tween()
	_dash_tween.tween_property(dash_panel, "offset_left", target_x, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_dash_tween.parallel().tween_property(dash_panel, "offset_right", target_x, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_dash_tween.parallel().tween_property(dash_tab, "offset_left", target_tab_left, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_dash_tween.parallel().tween_property(dash_tab, "offset_right", target_tab_right, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _dash_open:
		_dash_tween.tween_callback(func(): dash_panel.visible = false)
	_dash_open = not _dash_open

func _stub_action(label: String) -> void:
	status_label.text = "%s (stub)" % label

func _dash_stub_action(label: String) -> void:
	if dash_panel.visible:
		if SFLog.LOGGING_ENABLED:
			print("DASH: %s" % label)
	else:
		_stub_action(label)

func _open_dash_panel(panel: Panel) -> void:
	if panel == null:
		return
	if async_panel != null:
		async_panel.visible = false
	if panel == dash_store_panel:
		_show_store_landing()
	_hide_dash_panels()
	panel.visible = true

func _open_dash_panel_from_menu(panel: Panel) -> void:
	_open_dash_panel(panel)
	if not _dash_open:
		_toggle_dash()

func _close_dash_panel(panel: Panel) -> void:
	if panel == null:
		return
	panel.visible = false

func _hide_dash_panels() -> void:
	for panel in [dash_stats_panel, dash_analysis_panel, dash_replay_panel, dash_buffs_panel, dash_hive_panel, dash_store_panel, dash_settings_panel, dash_badges_panel_full]:
		panel.visible = false

func _open_async_panel() -> void:
	if async_panel == null:
		return
	if _dash_open:
		_toggle_dash()
	async_panel.visible = true
	_open_async_main()

func _close_async_panel() -> void:
	if async_panel == null:
		return
	async_panel.visible = false

func _open_async_main() -> void:
	if async_vbox != null:
		async_vbox.visible = true
	_hide_async_subpanels()
	_show_async_track_select()

func _on_async_results_action_pressed() -> void:
	if _async_track_mode == ASYNC_TRACK_PAID:
		_open_async_main()
		return
	_open_async_paid_menu()

func _on_async_rules_action_pressed() -> void:
	if _async_track_mode == ASYNC_TRACK_FREE:
		_open_async_main()
		return
	_open_async_free_menu()

func _show_async_track_select() -> void:
	_async_track_mode = ASYNC_TRACK_SELECT
	if async_subtitle_label != null:
		async_subtitle_label.text = "Choose your track first."
	if async_top_row != null:
		async_top_row.visible = false
	if async_bottom_row != null:
		async_bottom_row.visible = true
	if async_results_panel != null:
		async_results_panel.visible = true
	if async_rules_panel != null:
		async_rules_panel.visible = true
	if async_results_header != null:
		async_results_header.text = "PLAY FOR $"
	if async_results_sub != null:
		async_results_sub.text = "Entry-fee contests and ladders."
	if async_results_list != null:
		async_results_list.visible = false
	if async_results_action != null:
		async_results_action.text = "OPEN $"
	if async_rules_header != null:
		async_rules_header.text = "FREEPLAY"
	if async_rules_line1 != null:
		async_rules_line1.text = "Choose a mode."
	if async_rules_line2 != null:
		async_rules_line2.text = "No entry cost."
	if async_free_list != null:
		async_free_list.visible = false
	if async_rules_action != null:
		async_rules_action.text = "OPEN FREEPLAY"
	if async_footer_label != null:
		async_footer_label.text = "Pick $ or Freeplay, then choose a format."

func _open_async_paid_menu() -> void:
	_async_track_mode = ASYNC_TRACK_PAID
	if async_subtitle_label != null:
		async_subtitle_label.text = "Cash track: choose weekly, monthly, yearly, or ladder."
	if async_top_row != null:
		async_top_row.visible = true
	if async_bottom_row != null:
		async_bottom_row.visible = true
	if async_results_panel != null:
		async_results_panel.visible = true
	if async_rules_panel != null:
		async_rules_panel.visible = false
	if async_results_header != null:
		async_results_header.text = "LADDER"
	if async_results_sub != null:
		async_results_sub.text = "Competitive async ladders."
	if async_results_list != null:
		async_results_list.visible = true
	if async_results_action != null:
		async_results_action.text = "BACK"
	if async_footer_label != null:
		async_footer_label.text = "Cash contests now. Payout logic comes later."

func _open_async_free_menu() -> void:
	_async_track_mode = ASYNC_TRACK_FREE
	if async_subtitle_label != null:
		async_subtitle_label.text = "Freeplay track: pick a mode below."
	if async_top_row != null:
		async_top_row.visible = false
	if async_bottom_row != null:
		async_bottom_row.visible = true
	if async_results_panel != null:
		async_results_panel.visible = false
	if async_rules_panel != null:
		async_rules_panel.visible = true
	if async_rules_header != null:
		async_rules_header.text = "FREEPLAY MODES"
	if async_rules_line1 != null:
		async_rules_line1.text = "Practice and no-stakes async runs."
	if async_rules_line2 != null:
		async_rules_line2.text = "Pick a mode below."
	if async_free_list != null:
		async_free_list.visible = true
	if async_rules_action != null:
		async_rules_action.text = "BACK"
	if async_footer_label != null:
		async_footer_label.text = "Freeplay has no buy-in."

func _hide_async_subpanels() -> void:
	for panel in [async_weekly_panel, async_monthly_panel, async_yearly_panel]:
		if panel != null:
			panel.visible = false

func _open_async_weekly() -> void:
	_open_stage_race_tournament_lobby("WEEKLY")

func _open_async_monthly() -> void:
	_open_stage_race_tournament_lobby("MONTHLY")

func _open_async_yearly() -> void:
	_open_stage_race_tournament_lobby("YEARLY")

func _open_stage_race_tournament_lobby(scope: String) -> void:
	if _time_puzzle_lobby == null:
		_time_puzzle_lobby = preload("res://scenes/ui/TimePuzzleLobby.tscn").instantiate()
		_time_puzzle_lobby.closed.connect(func():
			_time_puzzle_lobby.queue_free()
			_time_puzzle_lobby = null
			if async_panel != null:
				async_panel.visible = true
		)
		add_child(_time_puzzle_lobby)
	_time_puzzle_lobby.set_scope(scope)
	_time_puzzle_lobby.visible = true
	if status_label != null:
		status_label.text = "%s Stage Race tournaments." % scope.capitalize()
	if async_panel != null:
		async_panel.visible = false

func _open_async_subpanel(mode: String, panel: Panel) -> void:
	if panel == null:
		return
	if async_vbox != null:
		async_vbox.visible = false
	_hide_async_subpanels()
	panel.visible = true
	_sync_async_mode_ui(mode)

func _sync_async_mode_ui(mode: String) -> void:
	_sync_async_buyin_buttons(mode)
	_update_async_rules(mode)
	_update_async_assigned_map(mode)
	_set_async_play_label(mode, false)

func _set_async_buyin(mode: String, amount: int) -> void:
	_async_buyins[mode] = amount
	_async_paid_entry_usd = amount
	_reset_async_confirm(mode)
	_sync_async_buyin_buttons(mode)
	_update_async_rules(mode)

func _sync_async_buyin_buttons(mode: String) -> void:
	var buttons := _get_async_buyin_buttons(mode)
	var selected := int(_async_buyins.get(mode, ASYNC_BUYINS[0]))
	for button_v in buttons:
		var any_button: Button = button_v as Button
		if any_button != null:
			any_button.visible = false
	for i in range(ASYNC_BUYINS.size()):
		var amount: int = ASYNC_BUYINS[i]
		if i >= buttons.size():
			break
		var button: Button = buttons[i] as Button
		if button == null:
			continue
		var prefix := "* " if amount == selected else ""
		button.text = "%s$%d Entry" % [prefix, amount]
		button.visible = true

func _update_async_rules(mode: String) -> void:
	var label: Label = _get_async_rules_label(mode)
	if label == null:
		return
	var amount := int(_async_buyins.get(mode, ASYNC_BUYINS[0]))
	if amount >= 50:
		label.text = "Buff cap: Unlimited."
	else:
		label.text = "Buff cap: 3."

func _update_async_assigned_map(mode: String) -> void:
	var label: Label = _get_async_assigned_label(mode)
	if label == null:
		return
	var map_name := str(_async_assigned_map.get(mode, ""))
	if map_name.is_empty():
		label.text = "Assigned Map: --"
	else:
		label.text = "Assigned Map: %s" % map_name

func _reset_async_confirm(mode: String) -> void:
	_async_confirm_pending[mode] = false
	_async_confirm_deadline[mode] = 0
	_set_async_play_label(mode, false)

func _set_async_play_label(mode: String, pending: bool) -> void:
	var button := _get_async_play_button(mode)
	if button == null:
		return
	button.text = "TAP AGAIN TO CONFIRM" if pending else "PLAY"

func _on_async_play_pressed(mode: String) -> void:
	var now := Time.get_ticks_msec()
	if _async_confirm_pending.get(mode, false) and now > int(_async_confirm_deadline.get(mode, 0)):
		_reset_async_confirm(mode)
	if not _async_confirm_pending.get(mode, false):
		_async_confirm_pending[mode] = true
		_async_confirm_deadline[mode] = now + ASYNC_CONFIRM_WINDOW_MS
		_set_async_play_label(mode, true)
		return
	_async_confirm_pending[mode] = false
	_set_async_play_label(mode, false)
	_assign_async_map(mode)
	var amount := int(_async_buyins.get(mode, ASYNC_BUYINS[0]))
	_stub_action("%s entry $%d confirmed" % [mode.capitalize(), amount])

func _on_async_miss_n_out_selected(free_play: bool) -> void:
	var contest_state: Node = get_node_or_null("/root/ContestState")
	var track_label: String = "Free Play" if free_play else "Ladder"
	var entry_usd: int = 0 if free_play else _current_async_paid_entry_usd()
	var lobby_options: Dictionary = {
		"start_players": ASYNC_WINDOW_START_PLAYERS,
		"window_sec": ASYNC_STAGE_AND_MISS_WINDOW_SEC
	}
	if contest_state == null:
		status_label.text = "%s Miss-N-Out (fallback lobby config)" % track_label
		_open_async_vs_lobby("MISS_N_OUT", 4, free_play, entry_usd, lobby_options)
		return
	if not contest_state.has_method("get_contest_by_scope") or not contest_state.has_method("build_miss_n_out_plan"):
		status_label.text = "%s Miss-N-Out (fallback lobby config)" % track_label
		_open_async_vs_lobby("MISS_N_OUT", 4, free_play, entry_usd, lobby_options)
		return
	var contest: Variant = contest_state.call("get_contest_by_scope", "WEEKLY")
	if contest == null:
		status_label.text = "%s Miss-N-Out (no weekly contest, fallback lobby config)" % track_label
		_open_async_vs_lobby("MISS_N_OUT", 4, free_play, entry_usd, lobby_options)
		return
	var contest_id: String = str(contest.get("id"))
	var plan: Dictionary = contest_state.call("build_miss_n_out_plan", contest_id, 5) as Dictionary
	if not bool(plan.get("ok", false)):
		status_label.text = "%s Miss-N-Out (plan unavailable, fallback lobby config)" % track_label
		_open_async_vs_lobby("MISS_N_OUT", 4, free_play, entry_usd, lobby_options)
		return
	var map_ids: PackedStringArray = plan.get("map_ids", PackedStringArray()) as PackedStringArray
	var map_labels: Array[String] = []
	for map_id_v in map_ids:
		map_labels.append(str(map_id_v))
	var map_count: int = int(plan.get("map_count", 0))
	var window_sec: int = _resolve_plan_time_window_sec(plan, ASYNC_STAGE_AND_MISS_WINDOW_SEC)
	lobby_options["window_sec"] = window_sec
	status_label.text = "%s Miss-N-Out (%d maps, %d min window): %s | Eliminated players can continue for practice or return to lobby." % [track_label, map_count, int(window_sec / 60), ", ".join(map_labels)]
	_open_async_vs_lobby("MISS_N_OUT", map_count, free_play, entry_usd, lobby_options)

func _on_async_stage_race_selected(map_count: int, free_play: bool) -> void:
	var contest_state: Node = get_node_or_null("/root/ContestState")
	var track_label: String = "Free Play" if free_play else "Ladder"
	var entry_usd: int = 0 if free_play else _current_async_paid_entry_usd()
	var lobby_options: Dictionary = {
		"start_players": ASYNC_WINDOW_START_PLAYERS,
		"window_sec": ASYNC_STAGE_AND_MISS_WINDOW_SEC
	}
	if contest_state == null:
		status_label.text = "%s Stage Race (%d maps, fallback lobby config)." % [track_label, map_count]
		_open_async_vs_lobby("STAGE_RACE", map_count, free_play, entry_usd, lobby_options)
		return
	if not contest_state.has_method("get_contest_by_scope") or not contest_state.has_method("build_stage_race_plan"):
		status_label.text = "%s Stage Race (%d maps, fallback lobby config)." % [track_label, map_count]
		_open_async_vs_lobby("STAGE_RACE", map_count, free_play, entry_usd, lobby_options)
		return
	var contest: Variant = contest_state.call("get_contest_by_scope", "WEEKLY")
	if contest == null:
		status_label.text = "%s Stage Race (%d maps, no weekly contest, fallback lobby config)." % [track_label, map_count]
		_open_async_vs_lobby("STAGE_RACE", map_count, free_play, entry_usd, lobby_options)
		return
	var contest_id: String = str(contest.get("id"))
	var plan: Dictionary = contest_state.call("build_stage_race_plan", contest_id, map_count) as Dictionary
	if not bool(plan.get("ok", false)):
		status_label.text = "%s Stage Race (%d maps, plan unavailable, fallback lobby config)." % [track_label, map_count]
		_open_async_vs_lobby("STAGE_RACE", map_count, free_play, entry_usd, lobby_options)
		return
	var map_ids: PackedStringArray = plan.get("map_ids", PackedStringArray()) as PackedStringArray
	var map_labels: Array[String] = []
	for map_id_v in map_ids:
		map_labels.append(str(map_id_v))
	var window_sec: int = _resolve_plan_time_window_sec(plan, ASYNC_STAGE_AND_MISS_WINDOW_SEC)
	lobby_options["window_sec"] = window_sec
	status_label.text = "%s Stage Race (%d maps, %d min window): %s" % [track_label, map_count, int(window_sec / 60), ", ".join(map_labels)]
	_open_async_vs_lobby("STAGE_RACE", map_count, free_play, entry_usd, lobby_options)

func _on_async_timed_race_selected(map_count: int, free_play: bool) -> void:
	var contest_state: Node = get_node_or_null("/root/ContestState")
	var track_label: String = "Free Play" if free_play else "Ladder"
	var entry_usd: int = 0 if free_play else _current_async_paid_entry_usd()
	var lobby_options: Dictionary = {
		"start_players": ASYNC_WINDOW_START_PLAYERS,
		"sync_join_sec": ASYNC_TIMED_RACE_SYNC_JOIN_SEC
	}
	if contest_state == null:
		status_label.text = "%s Timed Race (%d maps, fallback lobby config)." % [track_label, map_count]
		_open_async_vs_lobby("TIMED_RACE", map_count, free_play, entry_usd, lobby_options)
		return
	if not contest_state.has_method("get_contest_by_scope") or not contest_state.has_method("build_timed_race_plan"):
		status_label.text = "%s Timed Race (%d maps, fallback lobby config)." % [track_label, map_count]
		_open_async_vs_lobby("TIMED_RACE", map_count, free_play, entry_usd, lobby_options)
		return
	var contest: Variant = contest_state.call("get_contest_by_scope", "WEEKLY")
	if contest == null:
		status_label.text = "%s Timed Race (%d maps, no weekly contest, fallback lobby config)." % [track_label, map_count]
		_open_async_vs_lobby("TIMED_RACE", map_count, free_play, entry_usd, lobby_options)
		return
	var contest_id: String = str(contest.get("id"))
	var plan: Dictionary = contest_state.call("build_timed_race_plan", contest_id, map_count) as Dictionary
	if not bool(plan.get("ok", false)):
		status_label.text = "%s Timed Race (%d maps, plan unavailable, fallback lobby config)." % [track_label, map_count]
		_open_async_vs_lobby("TIMED_RACE", map_count, free_play, entry_usd, lobby_options)
		return
	var map_ids: PackedStringArray = plan.get("map_ids", PackedStringArray()) as PackedStringArray
	var map_labels: Array[String] = []
	for map_id_v in map_ids:
		map_labels.append(str(map_id_v))
	lobby_options["sync_join_sec"] = maxi(1, int(plan.get("start_countdown_sec", ASYNC_TIMED_RACE_SYNC_JOIN_SEC)))
	status_label.text = "%s Timed Race (%d maps, sync start after %ds): %s" % [track_label, map_count, int(lobby_options.get("sync_join_sec", ASYNC_TIMED_RACE_SYNC_JOIN_SEC)), ", ".join(map_labels)]
	_open_async_vs_lobby("TIMED_RACE", map_count, free_play, entry_usd, lobby_options)

func _current_async_paid_entry_usd() -> int:
	if ASYNC_BUYINS.has(_async_paid_entry_usd):
		return _async_paid_entry_usd
	return ASYNC_BUYINS[0]

func _open_async_vs_lobby(mode_id: String, map_count: int, free_play: bool, entry_usd: int, options: Dictionary = {}) -> void:
	if _vs_lobby == null:
		_vs_lobby = preload("res://scenes/ui/VsLobby.tscn").instantiate()
		_vs_lobby.closed.connect(func():
			_vs_lobby.queue_free()
			_vs_lobby = null
			if async_panel != null:
				async_panel.visible = true
		)
		add_child(_vs_lobby)
	if _vs_lobby.has_method("configure"):
		_vs_lobby.call("configure", mode_id, map_count, entry_usd, free_play, options)
	_vs_lobby.visible = true
	if async_panel != null:
		async_panel.visible = false

func _resolve_plan_time_window_sec(plan: Dictionary, fallback_sec: int) -> int:
	var ms: int = int(plan.get("time_limit_ms", fallback_sec * 1000))
	var seconds: int = int(round(float(ms) / 1000.0))
	return maxi(1, seconds)

func _assign_async_map(mode: String) -> void:
	if ASYNC_MAPS.is_empty():
		return
	var map_name: String = ASYNC_MAPS[_async_map_index % ASYNC_MAPS.size()]
	_async_map_index += 1
	_async_assigned_map[mode] = map_name
	_update_async_assigned_map(mode)

func _get_async_buyin_buttons(mode: String) -> Array:
	match mode:
		"weekly":
			return async_weekly_buyin_buttons
		"monthly":
			return async_monthly_buyin_buttons
		"yearly":
			return async_yearly_buyin_buttons
		_:
			return async_weekly_buyin_buttons

func _get_async_rules_label(mode: String) -> Label:
	match mode:
		"weekly":
			return async_weekly_rules
		"monthly":
			return async_monthly_rules
		"yearly":
			return async_yearly_rules
		_:
			return async_weekly_rules

func _get_async_assigned_label(mode: String) -> Label:
	match mode:
		"weekly":
			return async_weekly_assigned_map
		"monthly":
			return async_monthly_assigned_map
		"yearly":
			return async_yearly_assigned_map
		_:
			return async_weekly_assigned_map

func _get_async_play_button(mode: String) -> Button:
	match mode:
		"weekly":
			return async_weekly_play
		"monthly":
			return async_monthly_play
		"yearly":
			return async_yearly_play
		_:
			return async_weekly_play

func _set_stats_tier(tier: String) -> void:
	var tiers := _get_match_stats_tiers()
	if not tiers.has(tier):
		return
	_stats_tier = tier
	var rows: Array = tiers[tier]
	for i in range(stats_rows.size()):
		var label: Label = stats_rows[i]
		if i < rows.size():
			label.text = rows[i]
		else:
			label.text = ""
	var active := Color(0.75, 0.6, 0.2)
	var inactive := Color(0.18, 0.2, 0.26)
	_style_button(stats_tier_free, active, Color(0.95, 0.85, 0.55), Color(0.1, 0.08, 0.02))
	_style_button(stats_tier_bp, inactive, Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
	_style_button(stats_tier_elite, inactive, Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
	if tier == "BP":
		_style_button(stats_tier_free, inactive, Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
		_style_button(stats_tier_bp, active, Color(0.95, 0.85, 0.55), Color(0.1, 0.08, 0.02))
	elif tier == "ELITE":
		_style_button(stats_tier_free, inactive, Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
		_style_button(stats_tier_elite, active, Color(0.95, 0.85, 0.55), Color(0.1, 0.08, 0.02))

func _init_dash_state() -> void:
	var view_w := get_viewport_rect().size.x
	_dash_hidden_x = view_w
	_dash_tab_closed_left = dash_tab.offset_left
	_dash_tab_closed_right = dash_tab.offset_right
	var tab_width := _dash_tab_closed_right - _dash_tab_closed_left
	_dash_tab_open_left = -view_w
	_dash_tab_open_right = _dash_tab_open_left + tab_width
	dash_tab.cut_side = HexButton.CUT_LEFT
	dash_tab.queue_redraw()
	_set_dash_offsets(_dash_hidden_x)
	dash_panel.visible = false

func _set_dash_offsets(x_shift: float) -> void:
	dash_panel.offset_left = x_shift
	dash_panel.offset_right = x_shift
