extends Control

const SFLog = preload("res://scripts/util/sf_log.gd")
const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")
const SWARM_PASS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/SwarmPassPanel.tscn")
const BATTLE_PASS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/BattlePassPanel.tscn")
const RANK_PANEL_SCENE: PackedScene = preload("res://scenes/ui/RankPanel.tscn")
const HEX_SEAM_BACKGROUND_SCENE: PackedScene = preload("res://ui/backgrounds/HexSeamBackground.tscn")
const MATCH_BACKGROUND_INLAY_TEXTURE: Texture2D = preload("res://assets/sprites/sf_skin_v1/match_background_inlay.png")
const HONEY_WIDGET_SCENE: PackedScene = preload("res://ui/hud/honey/honey_widget.tscn")
const TIER_WIDGET_SCENE: PackedScene = preload("res://ui/hud/tier/tier_widget.tscn")
const HONEY_TEXT_SHADER: Shader = preload("res://ui/hud/honey/honey_text_honeycomb.gdshader")
const SWARMFRONT_TITLE_SHADER: Shader = preload("res://ui/main_menu/swarmfront_title_forged.gdshader")
const HONEY_FONT_COLOR: Color = Color(0.97, 0.73, 0.19, 1.0)
const HONEY_OUTLINE_COLOR: Color = Color(0.20, 0.09, 0.01, 0.98)
const HONEY_SHADOW_COLOR: Color = Color(0.10, 0.04, 0.01, 0.88)
const HONEY_WIDGET_PANEL_WIDTH: float = 300.0
const HONEY_WIDGET_PANEL_HEIGHT: float = 200.0
const HONEY_WIDGET_RIGHT_MARGIN: float = 22.0
const HONEY_WIDGET_TOP_OFFSET: float = 10.0
const TIER_WIDGET_LEFT_MARGIN: float = 8.0
const TIER_WIDGET_TOP_OFFSET: float = 8.0
const TIER_WIDGET_PANEL_WIDTH: float = 166.0
const TIER_WIDGET_PANEL_HEIGHT: float = 58.0
const MM_BACKGROUND_Y_SHIFT: float = 36.0
const MM_BACKGROUND_X_SCALE: float = 0.88
const MM_BACKGROUND_EXTRA_SIDE_PX: float = 90.0
const MM_BACKGROUND_STRETCH_MODE: int = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
const MM_PLATFORM_DIMMER_ALPHA: float = 0.19
const MM_HERO_PANEL_ANCHOR_LEFT: float = 0.14
const MM_HERO_PANEL_ANCHOR_RIGHT: float = 0.86
const MM_HERO_PANEL_ANCHOR_TOP: float = 0.30
const MM_HERO_PANEL_ANCHOR_BOTTOM: float = 0.66

const FONT_REGULAR_PATH := "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const FONT_FREE_ROLL_ATLAS_PATH := "res://assets/fonts/atlas_free_roll_font.tres"
const FONT_FREE_ROLL_SUPPORTED := " ABCDEFGHIJKLMNOPQRSTUVWXYZ01235789"
const SHELL_SCENE_PATH: String = "res://scenes/Shell.tscn"
const HIVE_TAB_KEY := "ui.mm.hive.normal"
const HIVE_BUTTON_SCALE: float = 1.5
const HIVE_BUTTON_BASE_WIDTH: float = 140.0
const HIVE_BUTTON_BASE_HEIGHT: float = 70.0
const HIVE_BUTTON_CENTER_Y: float = 45.0
const DASH_TAB_KEY_RIGHT := "ui.mm.dash.left"
const DASH_TAB_KEY_LEFT := "ui.mm.dash.right"
const UI_SURFACE_DASH := "dash"
const UI_SURFACE_ASYNC := "async"
const UI_SURFACE_ENTRY := "entry"
const UI_SURFACE_PLAY_MODE := "play_mode"
const UI_SURFACE_VS_LOBBY := "vs_lobby"
const UI_SURFACE_TIME_PUZZLE := "time_puzzle"
const UI_SURFACE_SWARM_PASS := "swarm_pass"
const UI_SURFACE_BATTLE_PASS := "battle_pass"
const UI_SURFACE_RANK := "rank"
const UI_SURFACE_HIVE_DROPDOWN := "hive_dropdown"
const DASH_HEX_BUFFS_KEY := "ui.mm.buffs.normal"
const DASH_HEX_STORE_KEY := "ui.mm.store.normal"
const DASH_HEX_HIVE_KEY := "ui.mm.hive.normal"
const DASH_HEX_BASE_SIZE: Vector2 = Vector2(90.0, 64.0)
const DASH_HEX_SIZE_SCALE: float = 1.38
const DASH_HEX_CONTAINER_RIGHT_MARGIN: float = 8.0
const DASH_HEX_CONTAINER_EXTRA_WIDTH: float = 16.0
const DASH_TAB_CLOSED_EDGE_SHIFT: float = 0.0

@onready var hive_button: HexButton = $TopBar/HiveButton
@onready var brand_title_label: Label = $TopBar/BrandTitle
@onready var dash_tab: HexButton = $DashTab
@onready var dash_panel: Panel = $DashPanel
@onready var dash_main_background: Control = $DashPanel/HexSeamBackground
@onready var dash_top_bar: Control = $DashPanel/DashTopBar
@onready var dash_root: VBoxContainer = $DashPanel/DashRoot
@onready var dash_hexes: VBoxContainer = $DashPanel/DashHexes
@onready var dash_match_panel: Panel = $DashPanel/DashRoot/MatchHistoryPanel
@onready var dash_badges_panel: Panel = $DashPanel/DashRoot/BadgesPanel
@onready var dash_hex_buffs: HexButton = $DashPanel/DashHexes/DashBuffs
@onready var dash_hex_store: HexButton = $DashPanel/DashHexes/DashStore
@onready var dash_hex_hive: HexButton = $DashPanel/DashHexes/DashHive
@onready var dash_stats_panel: Panel = $DashPanel/DashStatsPanel
@onready var dash_analysis_panel: Panel = $DashPanel/DashAnalysisPanel
@onready var dash_replay_panel: Panel = $DashPanel/DashReplayPanel
@onready var dash_buffs_panel: Panel = $DashPanel/DashBuffsPanel
@onready var dash_buffs_background: Control = $DashPanel/DashBuffsPanel/HexSeamBackground
@onready var dash_hive_panel: Panel = $DashPanel/DashHivePanel
@onready var dash_store_panel: Panel = $DashPanel/DashStorePanel
@onready var dash_hive_background: Control = $DashPanel/DashHivePanel/HexSeamBackground
@onready var dash_store_background: Control = $DashPanel/DashStorePanel/HexSeamBackground
@onready var dash_settings_panel: Panel = $DashPanel/DashSettingsPanel
@onready var dash_badges_panel_full: Panel = $DashPanel/DashBadgesPanel
@onready var store_landing_panel: Panel = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreLanding
@onready var store_category_grid: GridContainer = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreLanding/StoreLandingVBox/StoreCategoryGrid
@onready var store_category_view: Panel = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView
@onready var store_vbox: VBoxContainer = $DashPanel/DashStorePanel/StoreVBox
@onready var store_title_label: Label = $DashPanel/DashStorePanel/StoreVBox/StoreTitle
@onready var store_sub_label: Label = $DashPanel/DashStorePanel/StoreVBox/StoreSub
@onready var store_landing_header_label: Label = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreLanding/StoreLandingVBox/StoreLandingHeader
@onready var store_category_header: Label = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryHeader
@onready var store_category_sub: Label = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategorySub
@onready var store_category_list: VBoxContainer = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryList
@onready var store_category_prefs_panel: Panel = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryPrefs
@onready var store_prefs_label: Label = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryPrefs/StoreCategoryPrefsVBox/StorePrefsLabel
@onready var store_prefs_toggle: CheckButton = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryPrefs/StoreCategoryPrefsVBox/StorePrefsToggle
@onready var store_category_back: Button = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreCategoryView/StoreCategoryVBox/StoreCategoryBack
@onready var store_body_panel: Panel = $DashPanel/DashStorePanel/StoreVBox/StoreBody
@onready var async_panel: Panel = $AsyncPanel
@onready var main_hex_background: Control = $MainHexSeamBackground
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
@onready var buffs_body_vbox: VBoxContainer = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox
@onready var buffs_body_panel: Panel = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody
@onready var buffs_mode_tabs: HBoxContainer = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsModeTabs
@onready var buffs_mode_vs_button: Button = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsModeTabs/BuffsModeVS
@onready var buffs_mode_async_button: Button = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsModeTabs/BuffsModeAsync
@onready var buffs_loadout_panel: Panel = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel
@onready var buffs_library_panel: Panel = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel
@onready var buffs_detail_panel: Panel = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel
@onready var buffs_loadout_vbox: VBoxContainer = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel/BuffsLoadoutVBox
@onready var buffs_loadout_header: Label = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel/BuffsLoadoutVBox/BuffsLoadoutHeader
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
var _entry_route_modal: Panel = null
var _async_stage_section: Panel = null
var _swarm_pass_panel: Control = null
var _battle_pass_panel: Control = null
var _rank_panel: Control = null
var _honey_widget: Control = null
var _tier_widget: Control = null
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
@onready var async_weekly_body_vbox: VBoxContainer = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox
@onready var async_monthly_body_vbox: VBoxContainer = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox
@onready var async_yearly_body_vbox: VBoxContainer = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox
@onready var async_weekly_list_header: Label = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyListHeader
@onready var async_monthly_list_header: Label = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyListHeader
@onready var async_yearly_list_header: Label = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyListHeader
@onready var async_weekly_list: VBoxContainer = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyList
@onready var async_monthly_list: VBoxContainer = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyList
@onready var async_yearly_list: VBoxContainer = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyList
@onready var async_weekly_rules: Label = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyRules
@onready var async_monthly_rules: Label = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyRules
@onready var async_yearly_rules: Label = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyRules
@onready var async_weekly_map_pool: Label = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyMapPool
@onready var async_monthly_map_pool: Label = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyMapPool
@onready var async_yearly_map_pool: Label = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyMapPool
@onready var async_weekly_assigned_map: Label = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyAssignedMap
@onready var async_monthly_assigned_map: Label = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyAssignedMap
@onready var async_yearly_assigned_map: Label = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyAssignedMap
@onready var async_weekly_play: Button = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyPlay
@onready var async_monthly_play: Button = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyPlay
@onready var async_yearly_play: Button = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBody/YearlyBodyVBox/YearlyPlay
@onready var async_weekly_back: Button = $AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBack
@onready var async_monthly_back: Button = $AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBack
@onready var async_yearly_back: Button = $AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyBack
@onready var menu_store_button: Button = $BottomBar/MenuButtons/LeftButtons/AsyncButton
@onready var menu_buffs_button: Button = $BottomBar/MenuButtons/LeftButtons/BuffsButton
@onready var menu_free_roll_button: Button = $BottomBar/MenuButtons/LeftButtons/StoreButton
@onready var menu_cash_button: Button = $BottomBar/MenuButtons/PlayButton
@onready var menu_battle_pass_button: Button = $BottomBar/MenuButtons/RightButtons/ClanButton
@onready var menu_unused_button: Button = $BottomBar/MenuButtons/RightButtons/SettingsButton
@onready var status_label: Label = $BottomBar/StatusLabel
@onready var bottom_bar: Control = $BottomBar
@onready var menu_buttons_row: HBoxContainer = $BottomBar/MenuButtons
@onready var menu_left_buttons_row: HBoxContainer = $BottomBar/MenuButtons/LeftButtons
@onready var menu_right_buttons_row: HBoxContainer = $BottomBar/MenuButtons/RightButtons
@onready var underlayment_tex: TextureRect = $Underlayment
@onready var platform_dimmer: ColorRect = $PlatformDimmer
@onready var hero_panel: Panel = $HeroPanel
@onready var hero_vbox: VBoxContainer = $HeroPanel/HeroVBox
@onready var hero_title_label: Label = $HeroPanel/HeroVBox/HeroTitle
@onready var hero_sub_label: Label = $HeroPanel/HeroVBox/HeroSub
@onready var onboarding_overlay: Control = $ProfileFirstRunOverlay
@onready var onboarding_panel: OnboardingPanel = $ProfileFirstRunOverlay/OverlayCenter/OverlayPanel/OverlayVBox/OnboardingPanel

var _font_regular: Font
var _font_semibold: Font
var _font_free_roll_atlas: Font
var _dash_open := false
var _dash_hidden_x := 0.0
var _dash_tab_closed_left := 0.0
var _dash_tab_closed_right := 0.0
var _dash_tab_open_left := 0.0
var _dash_tab_open_right := 0.0
var _dash_tween: Tween
var _store_direct_mode: bool = false
var _settings_direct_mode: bool = false
var _buffs_direct_mode: bool = false
var _hive_direct_mode: bool = false
var _hive_panel_tween: Tween = null
var _player_profile := {
	"tier_text": "Tier: Bronze",
	"honey": 12480
}
var _wallet_profile := {
	"balance_usd": 0
}
var _dev_bypass_cash_balance := true
var _hive_panel_profile := {
	"name": "Swarmfront Prime",
	"tier": "Bronze",
	"member_role": "Member",
	"member_rank_within_hive": 7,
	"office_title": "Quartermaster",
	"ecosystem_rank": 148,
	"hive_honey": 12480,
	"hive_honey_total": 982400,
	"honey_score": 12480,
	"wax_score": 940,
	"season_name": "Season 01: Founding Swarm",
	"season_reset_text": "Resets in 12d 04h",
	"messages": [
		"Leader: Push Hive Quests before reset.",
		"Officer: Ladder sync tonight at 9pm.",
		"New member approved: WaspRider."
	],
	"achievements": [
		"Keystone Circuit I",
		"Season Relay I",
		"Wax Guard II",
		"Hive Lift-Off",
		"Lane Integrity II",
		"Twin Tower Break",
		"Barracks Lockdown"
	]
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
var _money_games_selected_division: String = "division_i"
var _money_games_selected_tier: int = 1

const ASYNC_BUYINS := [1, 2, 3, 5, 10]
const MONEY_DENOMINATIONS := [1, 2, 3, 5, 10, 20, 50]
const ASYNC_MAPS := ["Map A", "Map B", "Map C", "Map D", "Map E"]
const ASYNC_CONFIRM_WINDOW_MS := 900
const ASYNC_TRACK_SELECT := "select"
const ASYNC_TRACK_PAID := "paid"
const ASYNC_TRACK_FREE := "free"
const ASYNC_STAGE_AND_MISS_WINDOW_SEC := 30 * 60
const ASYNC_WINDOW_START_PLAYERS := 5
const ASYNC_TIMED_RACE_SYNC_JOIN_SEC := 30
const BUFF_MODE_VS: String = "vs"
const BUFF_MODE_ASYNC: String = "async"
const BUFF_FILTER_HIVE: String = "hive"
const BUFF_FILTER_UNIT: String = "unit"
const BUFF_FILTER_LANE: String = "lane"
const BUFF_FILTER_ACROSS: String = "across"
const LOCAL_REAL_PURCHASES_ENABLED: bool = true
const BUFF_LOADOUT_SIZE: int = 3
const BUFF_DRAG_MIN_PX: float = 16.0
const BUFF_LIBRARY_TIERS: Array[String] = ["classic", "premium", "elite"]
const BUFF_PRICE_USD_BY_TIER: Dictionary = {
	"classic": 0.20,
	"premium": 0.35,
	"elite": 0.50
}
const USD_SKIN_DIR_PATH: String = "res://assets/sprites/sf_skin_v1"
const USD_SKIN_FALLBACK_PATH: String = "res://assets/sprites/sf_skin_v1/$.png"
const CANCEL_SKIN_PATH: String = "res://assets/sprites/sf_skin_v1/cancel.png"
const CLOSE_SKIN_PATH: String = "res://assets/sprites/sf_skin_v1/Close.png"
const STORE_CATEGORY_SKIN_BY_ID: Dictionary = {
	"BUNDLES": "res://assets/sprites/sf_skin_v1/Bundles.png",
	"BATTLEPASS": "res://assets/sprites/sf_skin_v1/battle_pass.png",
	"BUFFS": "res://assets/sprites/sf_skin_v1/Buffs_1.png",
	"GAMEPLAYANALYSIS": "res://assets/sprites/sf_skin_v1/Analyticsii.png",
	"SKINS": "res://assets/sprites/sf_skin_v1/skins_alpha.png",
	"MERCH": "res://assets/sprites/sf_skin_v1/merch.png"
}
const HUMAN_MODE_SKIN_BY_MODE: Dictionary = {
	"1V1": "res://assets/sprites/sf_skin_v1/1v1.png",
	"2V2": "res://assets/sprites/sf_skin_v1/2v2.png",
	"3P FFA": "res://assets/sprites/sf_skin_v1/3_player.png",
	"4P FFA": "res://assets/sprites/sf_skin_v1/4p_ffa.png"
}
const ASYNC_CYCLE_SKIN_BY_LABEL: Dictionary = {
	"WEEKLY": "res://assets/sprites/sf_skin_v1/weekly_color.png",
	"MONTHLY": "res://assets/sprites/sf_skin_v1/monthly.png",
	"SEASON": "res://assets/sprites/sf_skin_v1/season.png"
}
const ASYNC_MODE_SKIN_BY_LABEL: Dictionary = {
	"STAGE RACE": "res://assets/sprites/sf_skin_v1/Stage_Race.png",
	"RACE": "res://assets/sprites/sf_skin_v1/Race.png",
	"MISS N OUT": "res://assets/sprites/sf_skin_v1/Miss_n_Out.png"
}
const BOTTOM_NAV_BUTTON_SCALE: float = 2.925
const BOTTOM_NAV_HEIGHT_SCALE: float = 1.2
const BOTTOM_NAV_BASE_BUTTON_SIZE: Vector2 = Vector2(38.0, 56.0)
const BOTTOM_NAV_CENTER_STRETCH_RATIO: float = 1.2
const BOTTOM_NAV_OUTER_PADDING: float = 8.0
const BOTTOM_NAV_GROUP_SEPARATION: int = 6
const BOTTOM_NAV_BUTTON_SEPARATION: int = 4
const HIVE_DROPDOWN_WIDTH: float = 420.0
const HIVE_DROPDOWN_HEIGHT: float = 248.0
const HIVE_DROPDOWN_TOP_GAP: float = 8.0
const HIVE_PULLDOWN_DURATION: float = 0.24
const GAME_HUB_OVERLAY_TARGET_WIDTH: float = 980.0
const GAME_HUB_OVERLAY_FREE_TARGET_HEIGHT: float = 860.0
const GAME_HUB_OVERLAY_PAID_TARGET_HEIGHT: float = 1040.0
const GAME_HUB_OVERLAY_VIEWPORT_MARGIN_X: float = 24.0
const GAME_HUB_OVERLAY_VIEWPORT_MARGIN_Y: float = 24.0
const GAME_HUB_OVERLAY_FREE_MIN_HEIGHT: float = 700.0
const GAME_HUB_OVERLAY_PAID_MIN_HEIGHT: float = 760.0
const GAME_HUB_OVERLAY_EXTRA_BOTTOM_PX: float = 50.0
const GAME_HUB_OVERLAY_EXTRA_TOP_PX: float = 30.0
const GAME_HUB_HUMAN_BUTTON_SIZE: Vector2 = Vector2(172.0, 72.0)
const GAME_HUB_HUMAN_ICON_MAX_WIDTH: int = 166
const GAME_HUB_CYCLE_BUTTON_SIZE: Vector2 = Vector2(286.0, 108.0)
const GAME_HUB_CYCLE_ICON_MAX_WIDTH: int = 272
const GAME_HUB_ASYNC_MODE_BUTTON_SIZE: Vector2 = Vector2(236.0, 82.0)
const GAME_HUB_ASYNC_MODE_ICON_MAX_WIDTH: int = 224
const GAME_HUB_CANCEL_BUTTON_SIZE: Vector2 = Vector2(236.0, 82.0)
const GAME_HUB_CONTENT_SHIFT_X: float = -20.0
const GAME_HUB_CONTENT_TOP_PADDING_PX: float = 24.0
const GAME_HUB_SECTION_HEADER_COLOR: Color = Color8(201, 204, 214, 255)
const GAME_HUB_SECTION_SUBTEXT_COLOR: Color = Color(0.86, 0.88, 0.92, 0.60)
const GAME_HUB_BLOCK_LABEL_COLOR: Color = Color(0.82, 0.85, 0.90, 0.78)
const GAME_HUB_DIVIDER_COLOR: Color = Color(0.95, 0.77, 0.28, 0.30)
const GAME_HUB_BLOCK_SPACING_PX: float = 14.0
const GAME_HUB_BLOCK_SPACING_FREE_PX: float = 15.0
const GAME_HUB_TITLE_OUTLINE_COLOR: Color = Color(1.0, 0.87, 0.56, 0.18)
const GAME_HUB_HOVER_EDGE_COLOR: Color = Color(0.95, 0.80, 0.34, 0.72)
const GAME_HUB_HOVER_BRIGHTNESS: float = 1.10
const GAME_HUB_SWEEP_DURATION_SEC: float = 0.8
const STORE_WINDOW_SCALE_X: float = 0.74
const STORE_WINDOW_SCALE_Y: float = 0.62
const STORE_WINDOW_INSET_BOTTOM: float = 14.0
const STORE_CLOSE_SKIN_MIN_WIDTH: float = 280.0
const STORE_CLOSE_SKIN_MIN_HEIGHT: float = 104.0
const DASH_PANEL_BG_COLOR: Color = Color(0.08, 0.09, 0.12, 0.95)
const DASH_PANEL_BORDER_COLOR: Color = Color(0.55, 0.56, 0.62, 0.8)
const STORE_PANEL_BG_COLOR: Color = Color(0.04, 0.04, 0.05, 0.24)
const STORE_PANEL_BORDER_COLOR: Color = Color(0.62, 0.50, 0.22, 0.0)
const STORE_LANDING_BG_COLOR: Color = Color(0.02, 0.02, 0.03, 0.58)
const STORE_LANDING_BORDER_COLOR: Color = Color(0.95, 0.77, 0.28, 0.0)
const STORE_CATEGORY_VIEW_BG_COLOR: Color = Color(0.02, 0.02, 0.03, 0.52)
const STORE_CATEGORY_VIEW_BORDER_COLOR: Color = Color(0.95, 0.77, 0.28, 0.0)
const STORE_FRAME_SHIFT_X_PX: float = 0.0
const STORE_FRAME_SHIFT_Y_PX: float = 0.0
const STORE_BACKGROUND_STRETCH_X_PX: float = 50.0
const STORE_BACKGROUND_STRETCH_Y_PX: float = 0.0
const STORE_INLAY_STRETCH_X_PX: float = 0.0
const STORE_INLAY_STRETCH_Y_PX: float = 0.0
const STORE_INLAY_TEXTURE_PAN_X_PX: float = 0.0
const STORE_INLAY_TEXTURE_PAN_Y_PX: float = 0.0
const STORE_HEADER_TOP_INSET: float = -116.0
const STORE_HEADER_BOTTOM_INSET: float = 24.0
const STORE_VBOX_SPACING: int = 10
const STORE_CATEGORY_GRID_COLUMNS: int = 2
const STORE_CATEGORY_BUTTON_MIN_SIZE: Vector2 = Vector2(330.0, 144.0)
const STORE_CATEGORY_ICON_MAX_WIDTH: int = 312
const ENTRY_OVERLAY_INLAY_MARGIN_X_LANDSCAPE_RATIO: float = 0.070
const ENTRY_OVERLAY_INLAY_MARGIN_Y_LANDSCAPE_RATIO: float = 0.145
const ENTRY_OVERLAY_INLAY_MARGIN_X_PORTRAIT_RATIO: float = 0.145
const ENTRY_OVERLAY_INLAY_MARGIN_Y_PORTRAIT_RATIO: float = 0.070
const ENTRY_OVERLAY_INLAY_CROP_X_LANDSCAPE_RATIO: float = 0.040
const ENTRY_OVERLAY_INLAY_CROP_Y_LANDSCAPE_RATIO: float = 0.090
const ENTRY_OVERLAY_INLAY_CROP_X_PORTRAIT_RATIO: float = 0.120
const ENTRY_OVERLAY_INLAY_CROP_Y_PORTRAIT_RATIO: float = 0.040
const ENTRY_OVERLAY_INLAY_OVERSCAN_X_RATIO: float = 0.1023
const ENTRY_OVERLAY_INLAY_OVERSCAN_Y_RATIO: float = 0.12
const ENTRY_OVERLAY_INLAY_SHIFT_X_RATIO: float = -0.0545
const ENTRY_OVERLAY_INLAY_SHIFT_Y_RATIO: float = 0.0
const ENTRY_OVERLAY_INLAY_SHIFT_X_PX: float = -20.0
const ENTRY_OVERLAY_INLAY_SHIFT_Y_PX: float = 90.0
const ENTRY_OVERLAY_MIDFIELD_ALPHA: float = 0.34
const ENTRY_OVERLAY_NOISE_ALPHA: float = 0.03
const MONEY_DIVISION_I: String = "division_i"
const MONEY_DIVISION_II: String = "division_ii"
const MONEY_DIVISION_III: String = "division_iii"
const MONEY_DIVISION_CLASSIFIED: String = "classified"
const MONEY_DIVISION_TAB_IDS: Array[String] = [
	MONEY_DIVISION_I,
	MONEY_DIVISION_II,
	MONEY_DIVISION_III,
	MONEY_DIVISION_CLASSIFIED
]
const MONEY_DIVISION_LABELS: Dictionary = {
	MONEY_DIVISION_I: "DIVISION I",
	MONEY_DIVISION_II: "DIVISION II",
	MONEY_DIVISION_III: "DIVISION III",
	MONEY_DIVISION_CLASSIFIED: "CLASSIFIED"
}
const MONEY_DIVISION_TIERS: Dictionary = {
	MONEY_DIVISION_I: [1, 2, 3],
	MONEY_DIVISION_II: [5, 10],
	MONEY_DIVISION_III: [20, 50]
}
const MONEY_TAB_INACTIVE_BG: Color = Color(0.10, 0.11, 0.14, 0.92)
const MONEY_TAB_INACTIVE_EDGE: Color = Color(0.92, 0.76, 0.30, 0.30)
const MONEY_TAB_ACTIVE_TEXT: Color = Color(0.97, 0.97, 0.95, 1.0)
const MONEY_TAB_INACTIVE_TEXT: Color = Color(0.80, 0.83, 0.88, 0.96)
const MONEY_TAB_LOCKED_TEXT: Color = Color(0.58, 0.60, 0.64, 0.90)
const MONEY_TAB_LOCKED_SUBTEXT: String = "Access Restricted"
const MONEY_ENTRY_LABEL_COLOR: Color = Color(0.83, 0.86, 0.90, 0.82)
const MONEY_ENTRY_ACTIVE_EDGE: Color = Color(0.96, 0.80, 0.34, 0.72)
const MONEY_ENTRY_ACTIVE_BG: Color = Color(0.18, 0.15, 0.10, 0.95)
const MONEY_ENTRY_INACTIVE_BG: Color = Color(0.11, 0.12, 0.16, 0.90)
const MONEY_ENTRY_INACTIVE_EDGE: Color = Color(0.44, 0.46, 0.53, 0.52)
const MONEY_DIVISION_TAB_SIZE: Vector2 = Vector2(186.0, 62.0)
const MONEY_ENTRY_TIER_BUTTON_SIZE: Vector2 = Vector2(96.0, 38.0)
const MONEY_DIVISION_LABEL_SIZE: int = 13
const MONEY_DIVISION_LOCKED_LABEL_SIZE: int = 11
const UI_TEXT_SCALE: float = 2.0

var _buff_library_all: Array[Dictionary] = []
var _buff_library_selected_ids: Dictionary = {}
var _buff_owned_ids: Array[String] = []
var _buff_loadout_ids: Array[String] = []
var _buff_active_mode: String = BUFF_MODE_VS
var _buff_mode_initialized: bool = false
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
var _buff_category_filter: String = BUFF_FILTER_HIVE
var _buff_category_tabs_row: HBoxContainer = null
var _buff_category_buttons: Dictionary = {}
var _buff_cart_root: VBoxContainer = null
var _buff_cart_line: ColorRect = null
var _buff_cart_panel: Panel = null
var _buff_cart_rows: VBoxContainer = null
var _buff_cart_empty_label: Label = null
var _buff_cart_subtotal_label: Label = null
var _buff_cart_buy_button: Button = null
var _buff_cart_clear_button: Button = null
var _buff_cart_counts: Dictionary = {}
var _buff_drag_state: Dictionary = {}
var _usd_skin_cache: Dictionary = {}
var _cancel_skin_cache: Texture2D = null
var _cancel_skin_loaded: bool = false
var _close_skin_cache: Texture2D = null
var _close_skin_loaded: bool = false
var _async_cycle_skin_cache: Dictionary = {}
var _human_mode_skin_cache: Dictionary = {}
var _async_mode_skin_cache: Dictionary = {}
var _store_category_skin_cache: Dictionary = {}
var _bottom_nav_skin_material: ShaderMaterial = null
var _store_category_skin_material: ShaderMaterial = null
var _hive_dropdown_panel: Panel = null
var _hive_dropdown_tween: Tween = null
var _hive_dropdown_open: bool = false
var _entry_overlay_inlay_rotated_texture: Texture2D = null
var _entry_overlay_inlay_cropped_texture: Texture2D = null
var _entry_overlay_inlay_rotated_cropped_texture: Texture2D = null
var _entry_overlay_noise_texture: Texture2D = null

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
const DASH_ACHIEVEMENT_STUBS := [
	{"name": "First Swarm", "progress": 2, "goal": 5},
	{"name": "Lane Planner", "progress": 1, "goal": 5},
	{"name": "Tower Breaker", "progress": 3, "goal": 5},
	{"name": "Hive Keeper", "progress": 0, "goal": 5}
]
const STORE_CATEGORIES := [
	{"id": "Bundles", "title": "Bundles", "desc": "High-value packs across systems."},
	{"id": "BattlePass", "title": "Battle Pass", "desc": "Seasonal progression tracks and upgrades."},
	{"id": "Buffs", "title": "Buffs", "desc": "Match-impact kits and utility."},
	{"id": "Skins", "title": "Skins", "desc": "Hives, lanes, and background art."},
	{"id": "Merch", "title": "Merch", "desc": "Physical and collectible Swarmfront gear."},
	{"id": "GameplayAnalysis", "title": "Game Play Analysis", "desc": "Replay forensics, AI notes, and coaching."}
]
const STORE_SKUS := [
	{
		"id": "bundle_founders_pack",
		"category": "Bundles",
		"subcategory": "Starter",
		"title": "Founder's Pack",
		"description": "Starter economy pack with early progression boosts.",
		"price_real": "$4.99",
		"entitlements": [],
		"is_bundle": true
	},
	{
		"id": "bundle_competitor_pack",
		"category": "Bundles",
		"subcategory": "Competitive",
		"title": "Competitor Pack",
		"description": "Buff unlocks and analysis access for ranked prep.",
		"price_real": "$9.99",
		"entitlements": ["analysis_forensic", "analysis_ai"],
		"is_bundle": true
	},
	{
		"id": "bundle_zero_ads",
		"category": "Bundles",
		"subcategory": "QoL",
		"title": "Zero Ads",
		"description": "Removes all advertisements from Swarmfront.",
		"price_real": "$3.99",
		"entitlements": ["zero_ads"]
	},
	{
		"id": "battle_pass_premium",
		"category": "BattlePass",
		"subcategory": "Season",
		"title": "Premium Track",
		"description": "Unlocks premium seasonal rewards.",
		"price_real": "$9.99",
		"entitlements": ["battle_pass_premium"]
	},
	{
		"id": "battle_pass_elite",
		"category": "BattlePass",
		"subcategory": "Season",
		"title": "Elite Track",
		"description": "Premium track plus tier skips and elite cosmetics.",
		"price_real": "$19.99",
		"entitlements": ["battle_pass_elite"]
	},
	{
		"id": "buff_match_tempo",
		"category": "Buffs",
		"subcategory": "Match Buffs",
		"title": "Tempo Kit",
		"description": "Minor send interval tuning for a match.",
		"price_real": "$0.20",
		"entitlements": []
	},
	{
		"id": "buff_signal_clarity",
		"category": "Buffs",
		"subcategory": "Information Buffs",
		"title": "Signal Cleanser",
		"description": "Cleaner alerts and lane signal.",
		"price_real": "$0.20",
		"entitlements": []
	},
	{
		"id": "skin_hive_obsidian",
		"category": "Skins",
		"subcategory": "Hives",
		"title": "Obsidian Hive Skin",
		"description": "Dark metallic hive visual set.",
		"price_honey": 350,
		"entitlements": ["skin_hive_obsidian"]
	},
	{
		"id": "skin_lane_goldpulse",
		"category": "Skins",
		"subcategory": "Lanes",
		"title": "Gold Pulse Lanes",
		"description": "High-contrast lane visuals for readability.",
		"price_honey": 300,
		"entitlements": ["skin_lane_goldpulse"]
	},
	{
		"id": "skin_bg_circuit_forge",
		"category": "Skins",
		"subcategory": "Background Art",
		"title": "Circuit Forge Background",
		"description": "Alternate board underlayment art.",
		"price_honey": 280,
		"entitlements": ["skin_bg_circuit_forge"]
	},
	{
		"id": "merch_founder_tee",
		"category": "Merch",
		"subcategory": "Apparel",
		"title": "Founder Tee",
		"description": "Official Swarmfront launch shirt.",
		"price_real": "$24.99",
		"entitlements": []
	},
	{
		"id": "merch_hex_mousepad",
		"category": "Merch",
		"subcategory": "Desk",
		"title": "Hex Mousepad",
		"description": "Large desk mat with Swarmfront map lines.",
		"price_real": "$19.99",
		"entitlements": []
	},
	{
		"id": "analysis_forensic_replay",
		"category": "GameplayAnalysis",
		"subcategory": "Replay",
		"title": "Forensic Replay",
		"description": "Unlock full replay scrubbing and event markers.",
		"price_honey": 600,
		"entitlements": ["analysis_forensic"]
	},
	{
		"id": "analysis_ai_commentary",
		"category": "GameplayAnalysis",
		"subcategory": "AI",
		"title": "AI Commentary",
		"description": "Cold, factual lane-by-lane commentary.",
		"price_honey": 500,
		"entitlements": ["analysis_ai"]
	},
	{
		"id": "analysis_coach_pack",
		"category": "GameplayAnalysis",
		"subcategory": "Coaching",
		"title": "Coach Pack",
		"description": "Post-match coaching notes and tactical prompts.",
		"price_real": "$5.99",
		"entitlements": ["analysis_coach"]
	}
]

func _ready() -> void:
	_load_fonts()
	_apply_background_art_direction()
	_ensure_tier_widget()
	_ensure_honey_widget()
	_style_labels()
	_style_buttons()
	_apply_bottom_nav_sprite_presentation()
	_apply_bottom_nav_layout()
	_style_panels()
	_start_entry_hub_skin_prewarm()
	_ensure_async_stage_contest_section()
	_wire_buttons()
	if not get_viewport().size_changed.is_connected(_apply_bottom_nav_layout):
		get_viewport().size_changed.connect(_apply_bottom_nav_layout)
	if not get_viewport().size_changed.is_connected(_apply_background_art_direction):
		get_viewport().size_changed.connect(_apply_background_art_direction)
	_set_hex_buttons()
	_load_match_history()
	_build_store_landing()
	_init_buffs_ui()
	_apply_surface_hex_background_presets()
	call_deferred("_prime_store_free_roll_skin")
	_configure_dash_account_surfaces()
	_ensure_swarm_pass_panel()
	_load_profile_commerce_state()
	_bind_profile_honey_signal()
	_apply_performance_pref_from_profile()
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

func _apply_surface_hex_background_presets() -> void:
	_apply_hex_background_preset(main_hex_background, StringName("dash"))
	_apply_hex_background_preset(dash_buffs_background, StringName("dash"))
	_apply_hex_background_preset(dash_store_background, StringName("store"))
	_apply_hex_background_preset(dash_hive_background, StringName("hive"))
	_ensure_embedded_hex_background(store_landing_panel, StringName("store"))
	_ensure_embedded_hex_background(store_category_view, StringName("store"))
	_ensure_embedded_hex_background(buffs_body_panel, StringName("dash"))
	_ensure_embedded_hex_background(buffs_loadout_panel, StringName("dash"))
	_ensure_embedded_hex_background(buffs_library_panel, StringName("dash"))
	_ensure_embedded_hex_background(buffs_detail_panel, StringName("dash"))


func _prime_store_free_roll_skin() -> void:
	_apply_store_window_scale()
	_ensure_store_free_roll_skin()


func _ensure_store_free_roll_skin() -> void:
	if dash_store_panel == null:
		return
	var resolved_size: Vector2 = dash_store_panel.size
	if resolved_size.x <= 1.0 or resolved_size.y <= 1.0:
		resolved_size = dash_store_panel.get_rect().size
	if resolved_size.x <= 1.0 or resolved_size.y <= 1.0:
		var viewport_size: Vector2 = get_viewport_rect().size
		resolved_size = Vector2(maxf(420.0, viewport_size.x * 0.86), maxf(320.0, viewport_size.y * 0.74))
	for node_name in [
		"Background_Base",
		"Background_Noise",
		"Frame_Inlay",
		"Midfield_Hex_Dark",
		"GameHubMatteOverlay",
		"GameHubCenterTension",
		"GameHubDirectionalShade"
	]:
		var existing: Node = dash_store_panel.get_node_or_null(node_name)
		if existing != null:
			existing.free()
	_build_entry_overlay_background_layers(dash_store_panel, resolved_size, false)
	_apply_game_hub_panel_fx(dash_store_panel)
	_apply_store_background_layer_shift(
		dash_store_panel,
		STORE_FRAME_SHIFT_X_PX,
		STORE_FRAME_SHIFT_Y_PX,
		STORE_BACKGROUND_STRETCH_X_PX,
		STORE_BACKGROUND_STRETCH_Y_PX
	)
	var store_inlay: NinePatchRect = dash_store_panel.get_node_or_null("Frame_Inlay") as NinePatchRect
	if store_inlay != null:
		_apply_store_inlay_stretch(store_inlay, STORE_INLAY_STRETCH_X_PX, STORE_INLAY_STRETCH_Y_PX)
		_apply_store_inlay_texture_pan(store_inlay, STORE_INLAY_TEXTURE_PAN_X_PX, STORE_INLAY_TEXTURE_PAN_Y_PX)
	if dash_store_background != null:
		dash_store_background.visible = false
	if store_landing_panel != null:
		var landing_hex: CanvasItem = store_landing_panel.get_node_or_null("HexSeamBackground") as CanvasItem
		if landing_hex != null:
			landing_hex.visible = false
	if store_category_view != null:
		var category_hex: CanvasItem = store_category_view.get_node_or_null("HexSeamBackground") as CanvasItem
		if category_hex != null:
			category_hex.visible = false

func _apply_store_background_layer_shift(
		panel: Panel,
		shift_x: float,
		shift_y: float,
		stretch_x: float = 0.0,
		stretch_y: float = 0.0
	) -> void:
	if panel == null:
		return
	for node_name in [
		"Background_Base",
		"Background_Noise",
		"Frame_Inlay",
		"Midfield_Hex_Dark",
		"GameHubMatteOverlay",
		"GameHubCenterTension",
		"GameHubDirectionalShade"
	]:
		var node_any: Variant = panel.get_node_or_null(node_name)
		if node_any is Control:
			var layer: Control = node_any as Control
			layer.offset_left -= stretch_x
			layer.offset_right += stretch_x
			layer.offset_top -= stretch_y
			layer.offset_bottom += stretch_y
			layer.offset_left += shift_x
			layer.offset_right += shift_x
			layer.offset_top += shift_y
			layer.offset_bottom += shift_y

func _apply_store_inlay_texture_pan(inlay: NinePatchRect, pan_x: float, pan_y: float) -> void:
	if inlay == null:
		return
	var atlas: AtlasTexture = inlay.texture as AtlasTexture
	if atlas == null:
		return
	var shifted: AtlasTexture = atlas.duplicate() as AtlasTexture
	if shifted == null:
		return
	var region: Rect2 = shifted.region
	var atlas_tex: Texture2D = shifted.atlas
	if atlas_tex != null:
		var atlas_size: Vector2 = atlas_tex.get_size()
		var max_x: float = maxf(0.0, atlas_size.x - region.size.x)
		var max_y: float = maxf(0.0, atlas_size.y - region.size.y)
		region.position.x = clampf(region.position.x + pan_x, 0.0, max_x)
		region.position.y = clampf(region.position.y + pan_y, 0.0, max_y)
	else:
		region.position += Vector2(pan_x, pan_y)
	shifted.region = region
	inlay.texture = shifted

func _apply_store_inlay_stretch(inlay: NinePatchRect, stretch_x: float, stretch_y: float) -> void:
	if inlay == null:
		return
	inlay.offset_left -= stretch_x
	inlay.offset_right += stretch_x
	inlay.offset_top -= stretch_y
	inlay.offset_bottom += stretch_y


func _apply_store_window_scale() -> void:
	if dash_store_panel == null or store_vbox == null:
		return
	var panel_size: Vector2 = get_viewport_rect().size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = dash_store_panel.size
	var target_size := Vector2(
		clampf(panel_size.x * STORE_WINDOW_SCALE_X, 520.0, maxf(520.0, panel_size.x - 24.0)),
		clampf(panel_size.y * STORE_WINDOW_SCALE_Y, 420.0, maxf(420.0, panel_size.y - 24.0))
	)
	dash_store_panel.layout_mode = 0
	dash_store_panel.anchor_left = 0.5
	dash_store_panel.anchor_top = 0.5
	dash_store_panel.anchor_right = 0.5
	dash_store_panel.anchor_bottom = 0.5
	dash_store_panel.offset_left = -target_size.x * 0.5
	dash_store_panel.offset_top = -target_size.y * 0.5
	dash_store_panel.offset_right = target_size.x * 0.5
	dash_store_panel.offset_bottom = target_size.y * 0.5
	store_vbox.layout_mode = 1
	store_vbox.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	store_vbox.offset_left = 24.0
	store_vbox.offset_top = STORE_HEADER_TOP_INSET
	store_vbox.offset_right = -24.0
	store_vbox.offset_bottom = -STORE_HEADER_BOTTOM_INSET
	store_vbox.add_theme_constant_override("separation", STORE_VBOX_SPACING)
	if store_title_label != null:
		store_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		store_title_label.custom_minimum_size = Vector2(0.0, 42.0)
		store_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		store_title_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	if store_sub_label != null:
		store_sub_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		store_sub_label.custom_minimum_size = Vector2(0.0, 32.0)
		store_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		store_sub_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if store_landing_header_label != null:
		store_landing_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		store_landing_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _apply_hex_background_preset(target: Node, preset_name: StringName) -> void:
	if target == null:
		return
	if target.has_method("apply_preset"):
		target.call("apply_preset", preset_name)


func _ensure_embedded_hex_background(host_panel: Control, preset_name: StringName) -> void:
	if host_panel == null:
		return
	var background: Control = null
	if host_panel.has_node("HexSeamBackground"):
		background = host_panel.get_node("HexSeamBackground") as Control
	else:
		var background_node: Node = HEX_SEAM_BACKGROUND_SCENE.instantiate()
		background = background_node as Control
		if background != null:
			background.name = "HexSeamBackground"
			background.layout_mode = 1
			background.set_anchors_preset(Control.PRESET_FULL_RECT, true)
			background.mouse_filter = Control.MOUSE_FILTER_IGNORE
			host_panel.add_child(background)
			host_panel.move_child(background, 0)
	_apply_hex_background_preset(background, preset_name)


func _start_entry_hub_skin_prewarm() -> void:
	call_deferred("_prewarm_entry_hub_skin_cache")


func _prewarm_entry_hub_skin_cache() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var human_modes: PackedStringArray = PackedStringArray(["1V1", "2V2", "3P FFA", "4P FFA"])
	for mode_id in human_modes:
		_human_mode_skin_for_mode(mode_id)
		await tree.process_frame
	var cycle_labels: PackedStringArray = PackedStringArray(["WEEKLY", "MONTHLY", "SEASON"])
	for label in cycle_labels:
		_async_cycle_skin_for_label(label)
		await tree.process_frame
	var async_labels: PackedStringArray = PackedStringArray(["STAGE RACE", "RACE", "MISS N OUT"])
	for label in async_labels:
		_async_mode_skin_for_label(label)
		await tree.process_frame

func _bind_onboarding_gate() -> void:
	ProfileManager.ensure_loaded()
	if not ProfileManager.is_onboarding_complete():
		onboarding_overlay.visible = true
		if onboarding_panel != null:
			if not onboarding_panel.onboarding_done.is_connected(_on_onboarding_done):
				onboarding_panel.onboarding_done.connect(_on_onboarding_done)
	else:
		onboarding_overlay.visible = false

func _apply_performance_pref_from_profile() -> void:
	if not ProfileManager.has_method("get_content_scale_factor"):
		return
	var scale_factor: float = float(ProfileManager.call("get_content_scale_factor"))
	var window_ref: Window = get_window()
	if window_ref != null:
		window_ref.content_scale_factor = clampf(scale_factor, 0.7, 1.0)

func _on_onboarding_done() -> void:
	onboarding_overlay.visible = false

func _load_fonts() -> void:
	_font_regular = load(FONT_REGULAR_PATH)
	_font_semibold = load(FONT_SEMIBOLD_PATH)
	_font_free_roll_atlas = load(FONT_FREE_ROLL_ATLAS_PATH)

func _style_labels() -> void:
	_apply_font($TopBar/RankLabel, _font_regular, 16)
	if _tier_widget != null and _tier_widget.has_method("apply_label_fonts"):
		_tier_widget.call("apply_label_fonts", _font_semibold, 8)
	_apply_font($TopBar/HoneyLabel, _font_regular, 16)
	_apply_honey_label_shader($TopBar/HoneyLabel)
	if _honey_widget != null and _honey_widget.has_method("apply_label_font"):
		_honey_widget.call("apply_label_font", _font_regular, _scaled_ui_font_size(17))
	_apply_font($DashPanel/DashTopBar/DashRankLabel, _font_regular, 16)
	_apply_font($DashPanel/DashTopBar/DashHoneyLabel, _font_regular, 17)
	_apply_honey_label_shader($DashPanel/DashTopBar/DashHoneyLabel)
	if brand_title_label != null:
		if not _apply_free_roll_atlas_font(brand_title_label, 17):
			_apply_font(brand_title_label, _font_semibold, 19)
		_apply_swarmfront_title_shader(brand_title_label)
	_apply_font($HeroPanel/HeroVBox/HeroTitle, _font_semibold, 24)
	_apply_font($HeroPanel/HeroVBox/HeroSub, _font_regular, 16)
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
	_apply_font(buffs_mode_vs_button, _font_semibold, 12)
	_apply_font(buffs_mode_async_button, _font_semibold, 12)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveTitle, _font_semibold, 20)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveSub, _font_regular, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveOverviewHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveActivityPanel/HiveActivityVBox/HiveActivityHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveFooter, _font_regular, 12)
	_apply_font($DashPanel/DashStorePanel/StoreVBox/StoreTitle, _font_semibold, 20)
	_apply_font($DashPanel/DashStorePanel/StoreVBox/StoreSub, _font_regular, 14)
	_apply_font($DashPanel/DashSettingsPanel/SettingsVBox/SettingsTitle, _font_semibold, 24)
	_apply_font($DashPanel/DashSettingsPanel/SettingsVBox/SettingsSub, _font_regular, 16)
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
	if buffs_body_vbox != null:
		buffs_body_vbox.add_theme_constant_override("separation", 12)
	var hive_body_vbox: VBoxContainer = $DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox
	hive_body_vbox.add_theme_constant_override("separation", 12)
	var store_body_vbox: VBoxContainer = $DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox
	store_body_vbox.add_theme_constant_override("separation", 12)
	var settings_vbox: VBoxContainer = $DashPanel/DashSettingsPanel/SettingsVBox
	settings_vbox.add_theme_constant_override("separation", 16)
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

func _apply_background_art_direction() -> void:
	if underlayment_tex != null:
		underlayment_tex.stretch_mode = MM_BACKGROUND_STRETCH_MODE
		underlayment_tex.offset_left = 0.0
		underlayment_tex.offset_right = 0.0
		underlayment_tex.offset_top = MM_BACKGROUND_Y_SHIFT
		underlayment_tex.offset_bottom = MM_BACKGROUND_Y_SHIFT
		underlayment_tex.pivot_offset = underlayment_tex.size * 0.5
		var base_width_px: float = maxf(1.0, underlayment_tex.size.x)
		if base_width_px <= 1.0 and get_viewport() != null:
			base_width_px = maxf(1.0, get_viewport().get_visible_rect().size.x)
		var width_scale_extra: float = 1.0 + ((MM_BACKGROUND_EXTRA_SIDE_PX * 2.0) / base_width_px)
		underlayment_tex.scale = Vector2(MM_BACKGROUND_X_SCALE * width_scale_extra, 1.0)
	if platform_dimmer != null:
		var dimmer_color: Color = platform_dimmer.color
		dimmer_color.a = MM_PLATFORM_DIMMER_ALPHA
		platform_dimmer.color = dimmer_color
	if hero_panel != null:
		hero_panel.anchor_left = MM_HERO_PANEL_ANCHOR_LEFT
		hero_panel.anchor_right = MM_HERO_PANEL_ANCHOR_RIGHT
		hero_panel.anchor_top = MM_HERO_PANEL_ANCHOR_TOP
		hero_panel.anchor_bottom = MM_HERO_PANEL_ANCHOR_BOTTOM
		hero_panel.offset_left = 0.0
		hero_panel.offset_top = 0.0
		hero_panel.offset_right = 0.0
		hero_panel.offset_bottom = 0.0
	if hero_vbox != null:
		hero_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hero_vbox.add_theme_constant_override("separation", 8)
	if hero_title_label != null:
		hero_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if hero_sub_label != null:
		hero_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero_sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _style_buttons() -> void:
	_apply_font(menu_cash_button, _font_semibold, 20)
	_style_button(menu_cash_button, Color(0.85, 0.64, 0.16), Color(1.0, 0.9, 0.5), Color(0.1, 0.08, 0.02))
	for button in [
		menu_store_button,
		menu_buffs_button,
		menu_free_roll_button,
		menu_battle_pass_button
	]:
		_apply_font(button, _font_regular, 14)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.35, 0.38, 0.45), Color(0.9, 0.9, 0.9))
	_apply_free_roll_atlas_font(menu_free_roll_button, 14)
	if menu_unused_button != null:
		menu_unused_button.visible = true
		menu_unused_button.text = "Settings"
		_apply_font(menu_unused_button, _font_regular, 14)
		_style_button(menu_unused_button, Color(0.12, 0.13, 0.16), Color(0.35, 0.38, 0.45), Color(0.9, 0.9, 0.9))
	for button in replay_controls_buttons:
		_apply_font(button, _font_regular, 12)
		_style_button(button, Color(0.1, 0.11, 0.14), Color(0.4, 0.42, 0.5), Color(0.92, 0.92, 0.92))
	for button in buffs_slot_buttons:
		_style_button(button, Color(0.1, 0.11, 0.14), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
	for button in buffs_library_buttons:
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
	for button in buffs_detail_buttons:
		_style_button(button, Color(0.16, 0.14, 0.1), Color(0.75, 0.65, 0.35), Color(0.98, 0.94, 0.8))
	_style_button(buffs_mode_vs_button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
	_style_button(buffs_mode_async_button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
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
	_sync_buff_mode_tabs()
	_style_dash_buttons()

func _style_panels() -> void:
	_style_panel($HeroPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.8))
	_style_panel(dash_panel, DASH_PANEL_BG_COLOR, DASH_PANEL_BORDER_COLOR)
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
	_style_panel($DashPanel/DashStorePanel/StoreVBox/StoreBody, STORE_PANEL_BG_COLOR, STORE_PANEL_BORDER_COLOR)
	_style_panel(store_landing_panel, STORE_LANDING_BG_COLOR, STORE_LANDING_BORDER_COLOR)
	_style_panel(store_category_view, STORE_CATEGORY_VIEW_BG_COLOR, STORE_CATEGORY_VIEW_BORDER_COLOR)
	_style_panel(store_category_prefs_panel, STORE_PANEL_BG_COLOR, STORE_PANEL_BORDER_COLOR)
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
	menu_store_button.pressed.connect(_open_storefront_panel)
	menu_buffs_button.pressed.connect(_open_buffs_store)
	menu_free_roll_button.pressed.connect(_open_free_roll_split)
	menu_cash_button.pressed.connect(_open_cash_split)
	menu_battle_pass_button.pressed.connect(_on_battle_pass_pressed)
	if menu_unused_button != null:
		menu_unused_button.pressed.connect(_on_settings_pressed)
	hive_button.pressed.connect(_open_hive_panel)
	dash_tab.pressed.connect(_toggle_dash)
	dash_hex_buffs.pressed.connect(func(): _open_dash_panel(dash_buffs_panel))
	dash_hex_store.pressed.connect(func(): _open_dash_panel(dash_store_panel))
	dash_hex_hive.pressed.connect(func(): _open_dash_panel(dash_hive_panel))
	_wire_match_rows()
	_wire_badges()
	dash_stats_close.pressed.connect(func(): _close_dash_panel(dash_stats_panel))
	dash_analysis_close.pressed.connect(func(): _close_dash_panel(dash_analysis_panel))
	dash_replay_close.pressed.connect(func(): _close_dash_panel(dash_replay_panel))
	dash_buffs_close.pressed.connect(_on_dash_buffs_close_pressed)
	dash_hive_close.pressed.connect(_on_dash_hive_close_pressed)
	dash_store_close.pressed.connect(_on_dash_store_close_pressed)
	dash_settings_close.pressed.connect(_on_dash_settings_close_pressed)
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
		"Ladder: Miss n Outs ($1/$2/$3/$5/$10)",
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
	buffs_mode_vs_button.pressed.connect(func(): _set_buff_mode(BUFF_MODE_VS))
	buffs_mode_async_button.pressed.connect(func(): _set_buff_mode(BUFF_MODE_ASYNC))
	_wire_buffs_buttons()

func _set_hex_buttons() -> void:
	hive_button.text = "HIVE"
	hive_button.font = _font_semibold
	hive_button.font_size = _scaled_ui_font_size(16)
	hive_button.fill_color = Color(0.16, 0.14, 0.12)
	hive_button.border_color = Color(0.95, 0.75, 0.25)
	hive_button.text_color = Color(0.98, 0.92, 0.72)
	var hive_width: float = HIVE_BUTTON_BASE_WIDTH * HIVE_BUTTON_SCALE
	var hive_height: float = HIVE_BUTTON_BASE_HEIGHT * HIVE_BUTTON_SCALE
	hive_button.offset_left = -hive_width * 0.5
	hive_button.offset_right = hive_width * 0.5
	hive_button.offset_top = HIVE_BUTTON_CENTER_Y - (hive_height * 0.5)
	hive_button.offset_bottom = hive_button.offset_top + hive_height
	hive_button.sprite_key = HIVE_TAB_KEY
	_apply_black_key_to_hex_button(hive_button)
	hive_button.queue_redraw()
	dash_tab.text = "DASH"
	dash_tab.font = _font_semibold
	dash_tab.font_size = _scaled_ui_font_size(14)
	dash_tab.fill_color = Color(0.18, 0.19, 0.22)
	dash_tab.border_color = Color(0.55, 0.56, 0.62)
	dash_tab.text_color = Color(0.85, 0.86, 0.9)
	dash_tab.cut_side = HexButton.CUT_LEFT
	dash_tab.sprite_key = DASH_TAB_KEY_RIGHT
	dash_tab.queue_redraw()
	dash_hex_buffs.text = "BUFFS"
	dash_hex_buffs.font = _font_semibold
	dash_hex_buffs.font_size = _scaled_ui_font_size(14)
	dash_hex_buffs.fill_color = Color(0.16, 0.16, 0.2)
	dash_hex_buffs.border_color = Color(0.7, 0.72, 0.8)
	dash_hex_buffs.text_color = Color(0.92, 0.94, 0.98)
	dash_hex_buffs.sprite_key = DASH_HEX_BUFFS_KEY
	var dash_hex_size: Vector2 = DASH_HEX_BASE_SIZE * DASH_HEX_SIZE_SCALE
	if dash_hexes != null:
		dash_hexes.offset_right = -DASH_HEX_CONTAINER_RIGHT_MARGIN
		dash_hexes.offset_left = dash_hexes.offset_right - dash_hex_size.x - DASH_HEX_CONTAINER_EXTRA_WIDTH
	dash_hex_buffs.custom_minimum_size = dash_hex_size
	_apply_black_key_to_hex_button(dash_hex_buffs)
	dash_hex_buffs.queue_redraw()
	dash_hex_store.text = "STORE"
	dash_hex_store.font = _font_semibold
	dash_hex_store.font_size = _scaled_ui_font_size(14)
	dash_hex_store.fill_color = Color(0.16, 0.16, 0.2)
	dash_hex_store.border_color = Color(0.7, 0.72, 0.8)
	dash_hex_store.text_color = Color(0.92, 0.94, 0.98)
	dash_hex_store.sprite_key = DASH_HEX_STORE_KEY
	dash_hex_store.custom_minimum_size = dash_hex_size
	_apply_black_key_to_hex_button(dash_hex_store)
	dash_hex_store.queue_redraw()
	dash_hex_hive.text = "HIVE"
	dash_hex_hive.font = _font_semibold
	dash_hex_hive.font_size = _scaled_ui_font_size(14)
	dash_hex_hive.fill_color = Color(0.16, 0.16, 0.2)
	dash_hex_hive.border_color = Color(0.7, 0.72, 0.8)
	dash_hex_hive.text_color = Color(0.92, 0.94, 0.98)
	dash_hex_hive.sprite_key = DASH_HEX_HIVE_KEY
	dash_hex_hive.custom_minimum_size = dash_hex_size
	_apply_black_key_to_hex_button(dash_hex_hive)
	dash_hex_hive.queue_redraw()

func _apply_black_key_to_hex_button(button: HexButton) -> void:
	if button == null:
		return
	if not button.has_node("SkinTex"):
		return
	var skin_tex: TextureRect = button.get_node("SkinTex") as TextureRect
	if skin_tex == null:
		return
	skin_tex.material = _bottom_nav_skin_shader_material()

func _hive_dropdown_open_top() -> float:
	return hive_button.offset_bottom + HIVE_DROPDOWN_TOP_GAP

func _hive_dropdown_closed_top() -> float:
	return -HIVE_DROPDOWN_HEIGHT - 12.0

func _hive_dropdown_set_top(top: float) -> void:
	if _hive_dropdown_panel == null:
		return
	_hive_dropdown_panel.offset_top = top
	_hive_dropdown_panel.offset_bottom = top + HIVE_DROPDOWN_HEIGHT

func _ensure_hive_dropdown() -> void:
	if _hive_dropdown_panel != null and is_instance_valid(_hive_dropdown_panel):
		return
	var panel: Panel = Panel.new()
	panel.name = "HiveDropdown"
	panel.layout_mode = 0
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -HIVE_DROPDOWN_WIDTH * 0.5
	panel.offset_right = HIVE_DROPDOWN_WIDTH * 0.5
	panel.z_index = 160
	panel.visible = false
	_hive_dropdown_panel = panel
	_hive_dropdown_set_top(_hive_dropdown_closed_top())
	add_child(panel)
	_style_panel(panel, Color(0.06, 0.07, 0.1, 0.98), Color(0.95, 0.75, 0.25, 0.75))

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "HiveDropdownVBox"
	body.layout_mode = 1
	body.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	body.offset_left = 14.0
	body.offset_top = 14.0
	body.offset_right = -14.0
	body.offset_bottom = -14.0
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)

	var title: Label = Label.new()
	title.text = "HIVE MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)
	_apply_font(title, _font_semibold, 16)

	var sub: Label = Label.new()
	sub.text = "Top pull-down. No side dash required."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(sub)
	_apply_font(sub, _font_regular, 12)

	var open_hive_button: Button = Button.new()
	open_hive_button.text = "OPEN HIVE DASHBOARD"
	open_hive_button.pressed.connect(func(): _on_hive_dropdown_action("dashboard"))
	body.add_child(open_hive_button)
	_apply_font(open_hive_button, _font_regular, 13)
	_style_button(open_hive_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))

	var chat_button: Button = Button.new()
	chat_button.text = "HIVE CHAT"
	chat_button.pressed.connect(func(): _on_hive_dropdown_action("chat"))
	body.add_child(chat_button)
	_apply_font(chat_button, _font_regular, 13)
	_style_button(chat_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))

	var ladder_button: Button = Button.new()
	ladder_button.text = "HIVE LADDER"
	ladder_button.pressed.connect(func(): _on_hive_dropdown_action("ladder"))
	body.add_child(ladder_button)
	_apply_font(ladder_button, _font_regular, 13)
	_style_button(ladder_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))

	var quests_button: Button = Button.new()
	quests_button.text = "HIVE QUESTS"
	quests_button.pressed.connect(func(): _on_hive_dropdown_action("quests"))
	body.add_child(quests_button)
	_apply_font(quests_button, _font_regular, 13)
	_style_button(quests_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))

	var close_button: Button = Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(func(): _set_hive_dropdown_open(false))
	body.add_child(close_button)
	_apply_font(close_button, _font_regular, 12)
	_style_button(close_button, Color(0.14, 0.12, 0.08), Color(0.72, 0.6, 0.28), Color(0.96, 0.92, 0.8))

func _on_hive_dropdown_action(action: String) -> void:
	_set_hive_dropdown_open(false)
	match action:
		"dashboard":
			_open_dash_panel_from_menu(dash_hive_panel)
		"chat":
			_stub_action("Hive Chat")
		"ladder":
			_stub_action("Hive Ladder")
		"quests":
			_stub_action("Hive Quests")
		_:
			pass

func _set_hive_dropdown_open(open: bool) -> void:
	_ensure_hive_dropdown()
	if _hive_dropdown_panel == null:
		return
	if _hive_dropdown_tween != null and _hive_dropdown_tween.is_running():
		_hive_dropdown_tween.kill()
	var target_top: float = _hive_dropdown_open_top() if open else _hive_dropdown_closed_top()
	if open:
		_close_top_level_windows(UI_SURFACE_HIVE_DROPDOWN)
		_hive_dropdown_panel.visible = true
	_hive_dropdown_tween = create_tween()
	_hive_dropdown_tween.tween_property(_hive_dropdown_panel, "offset_top", target_top, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hive_dropdown_tween.parallel().tween_property(_hive_dropdown_panel, "offset_bottom", target_top + HIVE_DROPDOWN_HEIGHT, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not open:
		_hive_dropdown_tween.tween_callback(func():
			if _hive_dropdown_panel != null:
				_hive_dropdown_panel.visible = false
		)
	_hive_dropdown_open = open

func _toggle_hive_dropdown() -> void:
	_set_hive_dropdown_open(not _hive_dropdown_open)

func _hide_hive_dropdown_immediate() -> void:
	if _hive_dropdown_tween != null and _hive_dropdown_tween.is_running():
		_hive_dropdown_tween.kill()
	if _hive_dropdown_panel != null:
		_hive_dropdown_set_top(_hive_dropdown_closed_top())
		_hive_dropdown_panel.visible = false
	_hive_dropdown_open = false

func _scaled_ui_font_size(size: int) -> int:
	return maxi(1, int(round(float(size) * UI_TEXT_SCALE)))

func _apply_font(node: Control, font: Font, size: int) -> void:
	if node == null or font == null:
		return
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", _scaled_ui_font_size(size))

func _text_uses_free_roll_charset(text: String) -> bool:
	var source := text.to_upper()
	for i in source.length():
		var ch := source.substr(i, 1)
		if FONT_FREE_ROLL_SUPPORTED.find(ch) == -1:
			return false
	return true

func _apply_free_roll_atlas_font(node: Control, size: int) -> bool:
	if node == null or _font_free_roll_atlas == null:
		return false
	var raw_text := ""
	if node is Label:
		raw_text = (node as Label).text
	elif node is BaseButton:
		raw_text = (node as BaseButton).text
	if raw_text == "":
		return false
	var upper_text := raw_text.to_upper()
	if not _text_uses_free_roll_charset(upper_text):
		return false
	if node is Label:
		(node as Label).text = upper_text
	elif node is BaseButton:
		(node as BaseButton).text = upper_text
	node.add_theme_font_override("font", _font_free_roll_atlas)
	node.add_theme_font_size_override("font_size", _scaled_ui_font_size(size))
	return true

func _apply_honey_label_shader(label: Label) -> void:
	if label == null or HONEY_TEXT_SHADER == null:
		return
	var mat: ShaderMaterial = label.material as ShaderMaterial
	if mat == null or mat.shader == null or mat.shader.resource_path != HONEY_TEXT_SHADER.resource_path:
		mat = ShaderMaterial.new()
		mat.shader = HONEY_TEXT_SHADER
	else:
		mat = mat.duplicate() as ShaderMaterial
	label.material = mat
	label.add_theme_color_override("font_color", HONEY_FONT_COLOR)
	label.add_theme_color_override("font_outline_color", HONEY_OUTLINE_COLOR)
	label.add_theme_color_override("font_shadow_color", HONEY_SHADOW_COLOR)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

func _apply_swarmfront_title_shader(label: Label) -> void:
	if label == null or SWARMFRONT_TITLE_SHADER == null:
		return
	label.text = "SWARMFRONT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	var mat: ShaderMaterial = label.material as ShaderMaterial
	if mat == null or mat.shader == null or mat.shader.resource_path != SWARMFRONT_TITLE_SHADER.resource_path:
		mat = ShaderMaterial.new()
		mat.shader = SWARMFRONT_TITLE_SHADER
	else:
		mat = mat.duplicate() as ShaderMaterial
	label.material = mat
	mat.set_shader_parameter("backlight_color", Color(1.0, 0.831, 0.0, 1.0))
	mat.set_shader_parameter("halo_core_strength", 1.15)
	mat.set_shader_parameter("halo_outer_strength", 0.58)
	mat.set_shader_parameter("wall_spill_strength", 0.22)
	mat.set_shader_parameter("bevel_strength", 0.24)

func _apply_player_profile(profile: Dictionary) -> void:
	var tier_text := str(profile.get("tier_text", "Tier: Bronze"))
	var honey_value := int(profile.get("honey", 0))
	var honey_text := "Honey: %s" % _format_number(honey_value)
	$TopBar/RankLabel.text = tier_text
	$TopBar/HoneyLabel.text = honey_text
	if _honey_widget != null and _honey_widget.has_method("set_honey_value"):
		_honey_widget.call("set_honey_value", honey_value, "main_menu_profile_apply", false)
	$DashPanel/DashTopBar/DashRankLabel.text = tier_text
	$DashPanel/DashTopBar/DashHoneyLabel.text = honey_text
	_refresh_dash_account_snapshot()

func _ensure_honey_widget() -> void:
	if _honey_widget != null:
		return
	var top_bar: Control = $TopBar
	var legacy_honey_label: Label = $TopBar/HoneyLabel
	if top_bar == null or legacy_honey_label == null:
		return
	var widget_any: Variant = HONEY_WIDGET_SCENE.instantiate()
	var widget_control: Control = widget_any as Control
	if widget_control == null:
		return
	widget_control.name = "HoneyWidget"
	widget_control.layout_mode = 0
	widget_control.anchor_left = 1.0
	widget_control.anchor_top = 0.0
	widget_control.anchor_right = 1.0
	widget_control.anchor_bottom = 0.0
	widget_control.offset_left = -HONEY_WIDGET_RIGHT_MARGIN - HONEY_WIDGET_PANEL_WIDTH
	widget_control.offset_top = HONEY_WIDGET_TOP_OFFSET
	widget_control.offset_right = -HONEY_WIDGET_RIGHT_MARGIN
	widget_control.offset_bottom = HONEY_WIDGET_TOP_OFFSET + HONEY_WIDGET_PANEL_HEIGHT
	widget_control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	widget_control.grow_vertical = Control.GROW_DIRECTION_END
	widget_control.custom_minimum_size = Vector2(HONEY_WIDGET_PANEL_WIDTH, HONEY_WIDGET_PANEL_HEIGHT)
	widget_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(widget_control)
	top_bar.move_child(widget_control, legacy_honey_label.get_index() + 1)
	legacy_honey_label.visible = false
	_honey_widget = widget_control
	if _honey_widget.has_method("set_honey_value"):
		_honey_widget.call("set_honey_value", _current_honey_balance(), "main_menu_boot", false)

func _ensure_tier_widget() -> void:
	if _tier_widget != null:
		return
	var top_bar: Control = $TopBar
	var legacy_rank_label: Label = $TopBar/RankLabel
	if top_bar == null or legacy_rank_label == null:
		return
	var widget_any: Variant = TIER_WIDGET_SCENE.instantiate()
	var widget_control: Control = widget_any as Control
	if widget_control == null:
		return
	widget_control.name = "TierWidget"
	widget_control.layout_mode = 0
	widget_control.anchor_left = 0.0
	widget_control.anchor_top = 0.0
	widget_control.anchor_right = 0.0
	widget_control.anchor_bottom = 0.0
	widget_control.offset_left = TIER_WIDGET_LEFT_MARGIN
	widget_control.offset_top = TIER_WIDGET_TOP_OFFSET
	widget_control.offset_right = TIER_WIDGET_LEFT_MARGIN + TIER_WIDGET_PANEL_WIDTH
	widget_control.offset_bottom = TIER_WIDGET_TOP_OFFSET + TIER_WIDGET_PANEL_HEIGHT
	widget_control.grow_horizontal = Control.GROW_DIRECTION_END
	widget_control.grow_vertical = Control.GROW_DIRECTION_END
	widget_control.custom_minimum_size = Vector2(TIER_WIDGET_PANEL_WIDTH, TIER_WIDGET_PANEL_HEIGHT)
	widget_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(widget_control)
	top_bar.move_child(widget_control, legacy_rank_label.get_index() + 1)
	legacy_rank_label.visible = false
	_tier_widget = widget_control

func _bind_profile_honey_signal() -> void:
	if ProfileManager == null:
		return
	if not ProfileManager.has_signal("honey_balance_changed"):
		return
	var callback: Callable = Callable(self, "_on_profile_honey_balance_changed")
	if not ProfileManager.is_connected("honey_balance_changed", callback):
		ProfileManager.connect("honey_balance_changed", callback)

func _on_profile_honey_balance_changed(new_value: int, _delta: int, _reason: String) -> void:
	var safe_value: int = maxi(0, new_value)
	if safe_value == _current_honey_balance():
		return
	_player_profile["honey"] = safe_value
	_apply_player_profile(_player_profile)

func _load_profile_commerce_state() -> void:
	ProfileManager.ensure_loaded()
	if ProfileManager.has_method("get_honey_balance"):
		var balance: int = int(ProfileManager.call("get_honey_balance"))
		_player_profile["honey"] = maxi(0, balance)
	if ProfileManager.has_method("get_store_entitlements"):
		var entitlements_any: Variant = ProfileManager.call("get_store_entitlements")
		if typeof(entitlements_any) == TYPE_DICTIONARY:
			_store_owned_entitlements = (entitlements_any as Dictionary).duplicate(true)

func _current_honey_balance() -> int:
	return maxi(0, int(_player_profile.get("honey", 0)))

func _set_honey_balance_local(balance: int) -> void:
	_player_profile["honey"] = maxi(0, balance)
	_apply_player_profile(_player_profile)

func _sync_entitlements_from_profile() -> void:
	if ProfileManager.has_method("get_store_entitlements"):
		var entitlements_any: Variant = ProfileManager.call("get_store_entitlements")
		if typeof(entitlements_any) == TYPE_DICTIONARY:
			_store_owned_entitlements = (entitlements_any as Dictionary).duplicate(true)

func _spend_honey(amount: int, reason: String) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "reason": "invalid_amount", "honey_balance": _current_honey_balance()}
	if ProfileManager.has_method("spend_honey"):
		var result_any: Variant = ProfileManager.call("spend_honey", amount, reason)
		if typeof(result_any) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "bad_profile_response", "honey_balance": _current_honey_balance()}
		var result: Dictionary = result_any as Dictionary
		if bool(result.get("ok", false)):
			_set_honey_balance_local(int(result.get("honey_balance", _current_honey_balance())))
		return result
	if _current_honey_balance() < amount:
		return {"ok": false, "reason": "insufficient_honey", "honey_balance": _current_honey_balance()}
	_set_honey_balance_local(_current_honey_balance() - amount)
	return {"ok": true, "honey_balance": _current_honey_balance()}

func _grant_entitlements(flags: Array[String], reason: String) -> Dictionary:
	if flags.is_empty():
		return {"ok": true, "granted": PackedStringArray(), "store_entitlements": _store_owned_entitlements.duplicate(true)}
	if ProfileManager.has_method("grant_store_entitlements"):
		var grant_any: Variant = ProfileManager.call("grant_store_entitlements", flags, reason)
		if typeof(grant_any) == TYPE_DICTIONARY:
			_sync_entitlements_from_profile()
			var grant_result: Dictionary = grant_any as Dictionary
			grant_result["store_entitlements"] = _store_owned_entitlements.duplicate(true)
			return grant_result
	for flag in flags:
		if flag.strip_edges() == "":
			continue
		_store_owned_entitlements[flag] = true
	return {"ok": true, "granted": flags.duplicate(), "store_entitlements": _store_owned_entitlements.duplicate(true)}

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

func _configure_dash_account_surfaces() -> void:
	$DashPanel/DashRoot/MatchHistoryPanel/MatchCenter/MatchVBox/MatchHeader.text = "ACCOUNT SNAPSHOT"
	$DashPanel/DashRoot/BadgesPanel/BadgesVBox/BadgesHeader.text = "ACHIEVEMENTS"
	_apply_buffs_mode_copy()
	$DashPanel/DashHivePanel/HiveVBox/HiveSub.text = "Hive profile + hive-earned achievements."
	_refresh_hive_panel()
	var action_texts: Array[String] = ["HIVE CHAT (SOON)", "HIVE LADDER (SOON)", "HIVE QUESTS (SOON)"]
	for idx in range(hive_action_buttons.size()):
		var button: Button = hive_action_buttons[idx] as Button
		if button == null:
			continue
		button.disabled = true
		if idx >= 0 and idx < action_texts.size():
			button.text = action_texts[idx]
	$DashPanel/DashBadgesPanel/BadgesCollectionVBox/BadgesTitle.text = "ACHIEVEMENTS"
	$DashPanel/DashBadgesPanel/BadgesCollectionVBox/BadgesSub.text = "Progress meters are placeholder for live achievement hooks."
	_refresh_dash_achievement_preview()
	_refresh_dash_account_snapshot()

func _refresh_hive_panel() -> void:
	if not is_inside_tree():
		return
	var hive_name: String = str(_hive_panel_profile.get("name", "TBD Hive"))
	var hive_tier: String = str(_hive_panel_profile.get("tier", "TBD"))
	var member_role: String = str(_hive_panel_profile.get("member_role", "Member"))
	var member_rank_within_hive: int = maxi(1, int(_hive_panel_profile.get("member_rank_within_hive", 1)))
	var office_title: String = str(_hive_panel_profile.get("office_title", "None"))
	var ecosystem_rank: int = maxi(1, int(_hive_panel_profile.get("ecosystem_rank", 1)))
	var hive_honey: int = maxi(0, int(_hive_panel_profile.get("hive_honey", 0)))
	var hive_honey_total: int = maxi(0, int(_hive_panel_profile.get("hive_honey_total", 0)))
	var season_name: String = str(_hive_panel_profile.get("season_name", "Season TBD"))
	var season_reset_text: String = str(_hive_panel_profile.get("season_reset_text", "Reset timer TBD"))
	var messages_any: Variant = _hive_panel_profile.get("messages", [])
	var achievements_any: Variant = _hive_panel_profile.get("achievements", [])
	var achievements: Array[String] = []
	var messages: Array[String] = []
	if typeof(messages_any) == TYPE_ARRAY:
		for msg_v in messages_any as Array:
			var msg: String = str(msg_v).strip_edges()
			if msg != "":
				messages.append(msg)
	if typeof(achievements_any) == TYPE_ARRAY:
		for ach_v in achievements_any as Array:
			var ach: String = str(ach_v).strip_edges()
			if ach != "":
				achievements.append(ach)
	var hive_title_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveTitle
	var hive_sub_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveSub
	hive_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hive_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hive_title_label.text = "HIVE HONEY: %s" % _format_number(hive_honey)
	hive_sub_label.text = "TOTAL HIVE HONEY: %s" % _format_number(hive_honey_total)
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveOverviewHeader.text = "HIVE PROFILE"
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanName.text = "Hive: %s" % hive_name
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanTag.text = "My Hive Rank: #%d | Office: %s" % [member_rank_within_hive, office_title]
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanLeague.text = "Ecosystem Rank: #%d" % ecosystem_rank
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanMembers.text = "Tier: %s | Role: %s | %s" % [hive_tier, member_role, season_name]
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterHeader.text = "MESSAGES"
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveActivityPanel/HiveActivityVBox/HiveActivityHeader.text = "HIVE ACHIEVEMENTS"
	var roster_labels: Array[Label] = [
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember1,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember2,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember3,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember4
	]
	var activity_labels: Array[Label] = [
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveActivityPanel/HiveActivityVBox/HiveActivity1,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveActivityPanel/HiveActivityVBox/HiveActivity2,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveActivityPanel/HiveActivityVBox/HiveActivity3
	]
	for i in range(roster_labels.size()):
		if i < messages.size():
			roster_labels[i].text = messages[i]
		else:
			roster_labels[i].text = "No hive message"
	for i in range(activity_labels.size()):
		if i < achievements.size():
			activity_labels[i].text = achievements[i]
		else:
			activity_labels[i].text = "No hive achievement"
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveFooter.text = "Hive panel: profile + messages + achievements. %s." % season_reset_text

func _refresh_dash_achievement_preview() -> void:
	var active_count := 0
	for achievement_any in DASH_ACHIEVEMENT_STUBS:
		var achievement: Dictionary = achievement_any as Dictionary
		if int(achievement.get("progress", 0)) > 0:
			active_count += 1
	$DashPanel/DashRoot/BadgesPanel/BadgesVBox/BadgesHeader.text = "ACHIEVEMENTS (%d/%d ACTIVE)" % [active_count, DASH_ACHIEVEMENT_STUBS.size()]
	for i in range(4):
		var button: Button = get_node_or_null("DashPanel/DashRoot/BadgesPanel/BadgesVBox/BadgesRow/BadgeButton%d" % (i + 1)) as Button
		if button == null:
			continue
		if i >= DASH_ACHIEVEMENT_STUBS.size():
			button.text = "COMING SOON [-----]"
			continue
		var achievement: Dictionary = DASH_ACHIEVEMENT_STUBS[i]
		var name := str(achievement.get("name", "Achievement"))
		var progress := int(achievement.get("progress", 0))
		var goal := maxi(1, int(achievement.get("goal", 1)))
		button.text = "%s %s" % [name, _achievement_meter(progress, goal)]

func _achievement_meter(progress: int, goal: int) -> String:
	var safe_goal := maxi(1, goal)
	var clamped_progress := clampi(progress, 0, safe_goal)
	var fill_slots := clampi(int(round((float(clamped_progress) / float(safe_goal)) * 5.0)), 0, 5)
	return "[%s%s] %d/%d" % ["#".repeat(fill_slots), "-".repeat(5 - fill_slots), clamped_progress, safe_goal]

func _refresh_dash_account_snapshot() -> void:
	if not is_inside_tree():
		return
	var tier_text := str(_player_profile.get("tier_text", "Tier: Bronze"))
	var honey_value := int(_player_profile.get("honey", 0))
	var owned_count := _buff_owned_ids.size()
	var equipped_count := 0
	for buff_id in _buff_loadout_ids:
		if str(buff_id).strip_edges() != "":
			equipped_count += 1
	var active_achievements := 0
	for achievement_any in DASH_ACHIEVEMENT_STUBS:
		var achievement: Dictionary = achievement_any as Dictionary
		if int(achievement.get("progress", 0)) > 0:
			active_achievements += 1
	var hive_name := str(_hive_panel_profile.get("name", "TBD Hive"))
	var hive_tier := str(_hive_panel_profile.get("tier", "TBD"))
	var hive_achievements_count := 0
	var hive_achievements_any: Variant = _hive_panel_profile.get("achievements", [])
	if typeof(hive_achievements_any) == TYPE_ARRAY:
		hive_achievements_count = (hive_achievements_any as Array).size()
	var rows: Array[Dictionary] = [
		{
			"title": "Hive Membership",
			"result": "%s | Tier %s" % [hive_name, hive_tier],
			"eff": "Hive achievements: %d" % hive_achievements_count
		},
		{
			"title": "Rank / Tier",
			"result": tier_text,
			"eff": "Dynamic profile hook enabled"
		},
		{
			"title": "Buff Inventory",
			"result": "Owned (%s): %d" % [_buff_active_mode.to_upper(), owned_count],
			"eff": "Equipped: %d/%d" % [equipped_count, BUFF_LOADOUT_SIZE]
		},
		{
			"title": "Achievements",
			"result": "Active: %d/%d" % [active_achievements, DASH_ACHIEVEMENT_STUBS.size()],
			"eff": "Progress meters drive Honey Score"
		},
		{
			"title": "Honey Score",
			"result": "Honey: %s" % _format_number(honey_value),
			"eff": "Updates after completed games"
		}
	]
	for i in range(rows.size()):
		_set_dash_account_row(i + 1, rows[i])

func _set_dash_account_row(row_index: int, row: Dictionary) -> void:
	var row_path := "DashPanel/DashRoot/MatchHistoryPanel/MatchCenter/MatchVBox/MatchList/MatchRow%d" % row_index
	var title_label: Label = get_node_or_null("%s/MatchTitle" % row_path) as Label
	var result_label: Label = get_node_or_null("%s/MatchResult" % row_path) as Label
	var meta_label: Label = get_node_or_null("%s/MatchEff" % row_path) as Label
	if title_label != null:
		title_label.text = str(row.get("title", ""))
	if result_label != null:
		result_label.text = str(row.get("result", ""))
	if meta_label != null:
		meta_label.text = str(row.get("eff", ""))
	for button_name in ["MatchStats", "MatchAnalytics", "MatchReplay"]:
		var action_button: Button = get_node_or_null("%s/%s" % [row_path, button_name]) as Button
		if action_button != null:
			action_button.visible = false

func _bottom_nav_buttons() -> Array[Button]:
	var buttons: Array[Button] = [
		menu_store_button,
		menu_buffs_button,
		menu_free_roll_button,
		menu_cash_button,
		menu_battle_pass_button
	]
	if menu_unused_button != null:
		buttons.append(menu_unused_button)
	return buttons

func _bottom_nav_skin_shader_material() -> ShaderMaterial:
	if _bottom_nav_skin_material != null:
		return _bottom_nav_skin_material
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float black_cutoff : hint_range(0.0, 0.25) = 0.06;
uniform float feather : hint_range(0.0, 0.2) = 0.045;
uniform float sat_limit : hint_range(0.0, 0.3) = 0.12;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float max_v = max(tex.r, max(tex.g, tex.b));
	float min_v = min(tex.r, min(tex.g, tex.b));
	float sat = max_v - min_v;
	float dark_key = 1.0 - smoothstep(black_cutoff, black_cutoff + feather, max_v);
	float neutral_key = 1.0 - smoothstep(0.02, sat_limit, sat);
	float cut = clamp(dark_key * neutral_key, 0.0, 1.0);
	COLOR = vec4(tex.rgb, tex.a * (1.0 - cut));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_bottom_nav_skin_material = material
	return _bottom_nav_skin_material

func _store_category_skin_shader_material() -> ShaderMaterial:
	if _store_category_skin_material != null:
		return _store_category_skin_material
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float black_cutoff : hint_range(0.0, 0.3) = 0.08;
uniform float white_cutoff : hint_range(0.7, 1.0) = 0.94;
uniform float feather : hint_range(0.0, 0.2) = 0.06;
uniform float sat_limit : hint_range(0.0, 0.4) = 0.18;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float max_v = max(tex.r, max(tex.g, tex.b));
	float min_v = min(tex.r, min(tex.g, tex.b));
	float sat = max_v - min_v;
	float dark_key = 1.0 - smoothstep(black_cutoff, black_cutoff + feather, max_v);
	float bright_key = smoothstep(white_cutoff - feather, white_cutoff, max_v);
	float neutral_key = 1.0 - smoothstep(0.02, sat_limit, sat);
	float cut = clamp((dark_key + bright_key) * neutral_key, 0.0, 1.0);
	COLOR = vec4(tex.rgb, tex.a * (1.0 - cut));
}
	"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_store_category_skin_material = material
	return _store_category_skin_material

func _style_bottom_nav_sprite_button(button: Button) -> void:
	if button == null:
		return
	var clear_style := StyleBoxEmpty.new()
	button.flat = true
	button.add_theme_stylebox_override("normal", clear_style)
	button.add_theme_stylebox_override("hover", clear_style)
	button.add_theme_stylebox_override("pressed", clear_style)
	button.add_theme_stylebox_override("focus", clear_style)
	button.add_theme_stylebox_override("disabled", clear_style)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 0.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.0))

func _apply_bottom_nav_sprite_presentation() -> void:
	var material: ShaderMaterial = _bottom_nav_skin_shader_material()
	for button in _bottom_nav_buttons():
		if button == null:
			continue
		if (not button.has_node("SkinTex")) and button.has_method("apply_skin"):
			button.call("apply_skin")
		if not button.has_node("SkinTex"):
			continue
		_style_bottom_nav_sprite_button(button)
		var skin_tex: TextureRect = button.get_node("SkinTex") as TextureRect
		if skin_tex != null:
			skin_tex.material = material

func _apply_bottom_nav_layout() -> void:
	if menu_buttons_row == null or menu_left_buttons_row == null or menu_right_buttons_row == null:
		return
	var scale: float = maxf(1.0, BOTTOM_NAV_BUTTON_SCALE)
	var nav_button_w: float = round(BOTTOM_NAV_BASE_BUTTON_SIZE.x * scale)
	var nav_button_h: float = round(BOTTOM_NAV_BASE_BUTTON_SIZE.y * scale * BOTTOM_NAV_HEIGHT_SCALE)
	var side_size: Vector2 = Vector2(
		nav_button_w,
		nav_button_h
	)
	var center_size: Vector2 = Vector2(
		round(nav_button_w * 1.12),
		nav_button_h
	)
	menu_buttons_row.offset_left = BOTTOM_NAV_OUTER_PADDING
	menu_buttons_row.offset_right = -BOTTOM_NAV_OUTER_PADDING
	menu_buttons_row.add_theme_constant_override("separation", BOTTOM_NAV_GROUP_SEPARATION)
	menu_left_buttons_row.add_theme_constant_override("separation", BOTTOM_NAV_BUTTON_SEPARATION)
	menu_right_buttons_row.add_theme_constant_override("separation", BOTTOM_NAV_BUTTON_SEPARATION)
	menu_left_buttons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_right_buttons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_left_buttons_row.size_flags_stretch_ratio = 3.0
	menu_right_buttons_row.size_flags_stretch_ratio = 2.0
	var side_buttons: Array[Button] = [
		menu_store_button,
		menu_buffs_button,
		menu_free_roll_button,
		menu_battle_pass_button
	]
	if menu_unused_button != null and menu_unused_button.visible:
		side_buttons.append(menu_unused_button)
	for button in side_buttons:
		if button == null:
			continue
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = side_size
	menu_cash_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_cash_button.size_flags_stretch_ratio = BOTTOM_NAV_CENTER_STRETCH_RATIO
	menu_cash_button.custom_minimum_size = center_size
	var row_top: float = 14.0
	menu_buttons_row.offset_top = row_top
	menu_buttons_row.offset_bottom = row_top + side_size.y
	var status_top: float = menu_buttons_row.offset_bottom + 6.0
	status_label.offset_top = status_top
	status_label.offset_bottom = status_top + 30.0
	bottom_bar.offset_top = -(status_label.offset_bottom + 8.0)

func _usd_skin_candidates(amount: int) -> PackedStringArray:
	var candidates: PackedStringArray = PackedStringArray()
	if amount > 0:
		candidates.append("%s/$%d.png" % [USD_SKIN_DIR_PATH, amount])
	candidates.append(USD_SKIN_FALLBACK_PATH)
	return candidates

func _usd_skin_for_amount(amount: int) -> Texture2D:
	var cache_key: String = str(amount)
	if _usd_skin_cache.has(cache_key):
		var cached_any: Variant = _usd_skin_cache.get(cache_key)
		if cached_any is Texture2D:
			return cached_any as Texture2D
		return null
	var candidates: PackedStringArray = _usd_skin_candidates(amount)
	for candidate_path in candidates:
		if not ResourceLoader.exists(candidate_path):
			continue
		var loaded_any: Variant = load(candidate_path)
		if loaded_any is Texture2D:
			var raw_tex: Texture2D = loaded_any as Texture2D
			var keyed_tex: Texture2D = _key_black_to_alpha_texture(raw_tex)
			_usd_skin_cache[cache_key] = keyed_tex
			return keyed_tex
	_usd_skin_cache[cache_key] = null
	return null

func _apply_usd_skin_to_button(button: Button, amount: int, label_text: String) -> void:
	if button == null:
		return
	var tex: Texture2D = _usd_skin_for_amount(amount)
	button.tooltip_text = label_text
	button.icon = tex
	if tex == null:
		button.text = label_text
		return
	button.text = ""
	button.custom_minimum_size = Vector2(84, 56)
	# Guarded dynamic sets keep compatibility across minor engine property differences.
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)
	button.add_theme_constant_override("h_separation", 0)

func _style_usd_sprite_button(button: Button, selected: bool) -> void:
	if button == null:
		return
	var clear_style := StyleBoxEmpty.new()
	button.flat = true
	button.add_theme_stylebox_override("normal", clear_style)
	button.add_theme_stylebox_override("hover", clear_style)
	button.add_theme_stylebox_override("pressed", clear_style)
	button.add_theme_stylebox_override("focus", clear_style)
	button.add_theme_stylebox_override("disabled", clear_style)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0))
	if button.disabled:
		button.modulate = Color(0.35, 0.35, 0.35, 0.55)
	elif selected:
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		button.modulate = Color(0.78, 0.78, 0.78, 0.95)

func _cancel_skin_texture() -> Texture2D:
	if _cancel_skin_loaded:
		return _cancel_skin_cache
	_cancel_skin_loaded = true
	if not ResourceLoader.exists(CANCEL_SKIN_PATH):
		return null
	var loaded_any: Variant = load(CANCEL_SKIN_PATH)
	if loaded_any is Texture2D:
		_cancel_skin_cache = _key_black_to_alpha_texture(loaded_any as Texture2D, 512, 256)
	return _cancel_skin_cache

func _close_skin_texture() -> Texture2D:
	if _close_skin_loaded:
		return _close_skin_cache
	_close_skin_loaded = true
	if not ResourceLoader.exists(CLOSE_SKIN_PATH):
		return null
	var loaded_any: Variant = load(CLOSE_SKIN_PATH)
	if loaded_any is Texture2D:
		_close_skin_cache = _key_black_to_alpha_texture(loaded_any as Texture2D, 512, 256)
	return _close_skin_cache

func _apply_close_skin_to_button(button: Button) -> void:
	if button == null:
		return
	var is_close_button: bool = false
	if button.has_meta("sf_close_skin"):
		is_close_button = bool(button.get_meta("sf_close_skin"))
	else:
		var raw_text: String = button.text.strip_edges().to_upper()
		if raw_text.find("CLOSE") >= 0:
			is_close_button = true
			button.set_meta("sf_close_skin", true)
	if not is_close_button:
		return
	var tex: Texture2D = _close_skin_texture()
	if tex == null:
		return
	if button.tooltip_text.is_empty():
		button.tooltip_text = "CLOSE"
	var min_width: float = 330.0
	var min_height: float = 140.0
	if button.has_meta("sf_close_skin_min_w"):
		min_width = maxf(1.0, float(button.get_meta("sf_close_skin_min_w")))
	if button.has_meta("sf_close_skin_min_h"):
		min_height = maxf(1.0, float(button.get_meta("sf_close_skin_min_h")))
	button.icon = tex
	button.text = ""
	button.custom_minimum_size = Vector2(
		maxf(button.custom_minimum_size.x, min_width),
		maxf(button.custom_minimum_size.y, min_height)
	)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)
	button.add_theme_constant_override("h_separation", 0)
	_style_usd_sprite_button(button, true)

func _apply_cancel_skin_to_button(button: Button) -> void:
	if button == null:
		return
	var is_cancel_button: bool = false
	if button.has_meta("sf_cancel_skin"):
		is_cancel_button = bool(button.get_meta("sf_cancel_skin"))
	else:
		var raw_text: String = button.text.strip_edges().to_upper()
		if raw_text.find("CANCEL") >= 0:
			is_cancel_button = true
			button.set_meta("sf_cancel_skin", true)
	if not is_cancel_button:
		return
	var tex: Texture2D = _cancel_skin_texture()
	if tex == null:
		return
	if button.tooltip_text.is_empty():
		button.tooltip_text = "CANCEL"
	var min_width: float = 330.0
	var min_height: float = 140.0
	if button.has_meta("sf_cancel_skin_min_w"):
		min_width = maxf(1.0, float(button.get_meta("sf_cancel_skin_min_w")))
	if button.has_meta("sf_cancel_skin_min_h"):
		min_height = maxf(1.0, float(button.get_meta("sf_cancel_skin_min_h")))
	button.icon = tex
	button.text = ""
	button.custom_minimum_size = Vector2(
		maxf(button.custom_minimum_size.x, min_width),
		maxf(button.custom_minimum_size.y, min_height)
	)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)
	button.add_theme_constant_override("h_separation", 0)
	_style_usd_sprite_button(button, true)

func _key_black_to_alpha_texture(source_tex: Texture2D, max_width: int = 512, max_height: int = 256) -> Texture2D:
	if source_tex == null:
		return null
	var source_image: Image = source_tex.get_image()
	if source_image == null or source_image.is_empty():
		return source_tex
	source_image.convert(Image.FORMAT_RGBA8)
	var width: int = source_image.get_width()
	var height: int = source_image.get_height()
	var can_resize: bool = max_width > 0 and max_height > 0
	if can_resize and (width > max_width or height > max_height):
		var width_scale: float = float(max_width) / float(width)
		var height_scale: float = float(max_height) / float(height)
		var resize_scale: float = minf(width_scale, height_scale)
		var target_w: int = maxi(1, int(round(float(width) * resize_scale)))
		var target_h: int = maxi(1, int(round(float(height) * resize_scale)))
		source_image.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
		width = source_image.get_width()
		height = source_image.get_height()
	for y in range(height):
		for x in range(width):
			var px: Color = source_image.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			var max_v: float = max(px.r, max(px.g, px.b))
			var min_v: float = min(px.r, min(px.g, px.b))
			var sat: float = max_v - min_v
			if max_v <= 0.03:
				px.a = 0.0
			elif max_v < 0.14 and sat < 0.20:
				var t: float = clamp((max_v - 0.03) / 0.11, 0.0, 1.0)
				px.a *= t
			source_image.set_pixel(x, y, px)
	var keyed_tex: ImageTexture = ImageTexture.create_from_image(source_image)
	return keyed_tex

func _is_neutral_background_candidate(px: Color) -> bool:
	if px.a <= 0.0:
		return false
	var max_v: float = max(px.r, max(px.g, px.b))
	var min_v: float = min(px.r, min(px.g, px.b))
	var sat: float = max_v - min_v
	if sat > 0.24:
		return false
	# Store category source art has checker/frame remnants that can be dark, mid-gray, or white.
	return max_v <= 0.68 or max_v >= 0.86

func _queue_neutral_background_pixel(
	image: Image,
	x: int,
	y: int,
	width: int,
	height: int,
	mask: PackedByteArray,
	queue: Array[Vector2i]
) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	var idx: int = (y * width) + x
	if idx < 0 or idx >= mask.size():
		return
	if mask[idx] != 0:
		return
	var px: Color = image.get_pixel(x, y)
	if not _is_neutral_background_candidate(px):
		return
	mask[idx] = 1
	queue.append(Vector2i(x, y))

func _key_neutral_to_alpha_texture(source_tex: Texture2D, max_width: int = 1024, max_height: int = 512, trim_alpha_threshold: float = 0.04) -> Texture2D:
	if source_tex == null:
		return null
	var source_image: Image = source_tex.get_image()
	if source_image == null or source_image.is_empty():
		return source_tex
	source_image.convert(Image.FORMAT_RGBA8)
	var width: int = source_image.get_width()
	var height: int = source_image.get_height()
	if max_width > 0 and max_height > 0 and (width > max_width or height > max_height):
		var width_scale: float = float(max_width) / float(width)
		var height_scale: float = float(max_height) / float(height)
		var resize_scale: float = minf(width_scale, height_scale)
		var target_w: int = maxi(1, int(round(float(width) * resize_scale)))
		var target_h: int = maxi(1, int(round(float(height) * resize_scale)))
		source_image.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
		width = source_image.get_width()
		height = source_image.get_height()
	var background_mask := PackedByteArray()
	background_mask.resize(width * height)
	var flood_queue: Array[Vector2i] = []
	for x in range(width):
		_queue_neutral_background_pixel(source_image, x, 0, width, height, background_mask, flood_queue)
		_queue_neutral_background_pixel(source_image, x, height - 1, width, height, background_mask, flood_queue)
	for y in range(height):
		_queue_neutral_background_pixel(source_image, 0, y, width, height, background_mask, flood_queue)
		_queue_neutral_background_pixel(source_image, width - 1, y, width, height, background_mask, flood_queue)
	var queue_idx: int = 0
	while queue_idx < flood_queue.size():
		var cell: Vector2i = flood_queue[queue_idx]
		queue_idx += 1
		_queue_neutral_background_pixel(source_image, cell.x - 1, cell.y, width, height, background_mask, flood_queue)
		_queue_neutral_background_pixel(source_image, cell.x + 1, cell.y, width, height, background_mask, flood_queue)
		_queue_neutral_background_pixel(source_image, cell.x, cell.y - 1, width, height, background_mask, flood_queue)
		_queue_neutral_background_pixel(source_image, cell.x, cell.y + 1, width, height, background_mask, flood_queue)
	for y in range(height):
		for x in range(width):
			var idx: int = (y * width) + x
			var px: Color = source_image.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			if idx >= 0 and idx < background_mask.size() and background_mask[idx] != 0:
				source_image.set_pixel(x, y, Color(px.r, px.g, px.b, 0.0))
				continue
			var max_v: float = max(px.r, max(px.g, px.b))
			var min_v: float = min(px.r, min(px.g, px.b))
			var sat: float = max_v - min_v
			var dark_key: float = 1.0 - smoothstep(0.04, 0.22, max_v)
			var bright_key: float = smoothstep(0.74, 0.98, max_v)
			var neutral_key: float = 1.0 - smoothstep(0.015, 0.22, sat)
			var cut: float = clamp((dark_key + bright_key) * neutral_key, 0.0, 1.0)
			var out_alpha: float = clamp(px.a * (1.0 - cut), 0.0, 1.0)
			if out_alpha <= trim_alpha_threshold:
				source_image.set_pixel(x, y, Color(px.r, px.g, px.b, 0.0))
				continue
			var fringe: float = clamp((1.0 - out_alpha) * (1.0 - smoothstep(0.02, 0.20, sat)) * smoothstep(0.65, 1.0, max_v), 0.0, 1.0)
			px.r = lerpf(px.r, px.r * 0.30, fringe)
			px.g = lerpf(px.g, px.g * 0.30, fringe)
			px.b = lerpf(px.b, px.b * 0.30, fringe)
			px.a = out_alpha
			source_image.set_pixel(x, y, px)
	var min_x: int = width
	var min_y: int = height
	var max_x: int = -1
	var max_y: int = -1
	for y in range(height):
		for x in range(width):
			if source_image.get_pixel(x, y).a <= trim_alpha_threshold:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x >= min_x and max_y >= min_y:
		var crop_w: int = (max_x - min_x) + 1
		var crop_h: int = (max_y - min_y) + 1
		var cropped: Image = Image.create(crop_w, crop_h, false, Image.FORMAT_RGBA8)
		cropped.blit_rect(source_image, Rect2i(min_x, min_y, crop_w, crop_h), Vector2i.ZERO)
		source_image = cropped
	var keyed_tex: ImageTexture = ImageTexture.create_from_image(source_image)
	return keyed_tex

func _human_mode_skin_for_mode(mode_id: String) -> Texture2D:
	var cache_key: String = mode_id.strip_edges()
	if _human_mode_skin_cache.has(cache_key):
		var cached_any: Variant = _human_mode_skin_cache.get(cache_key)
		if cached_any is Texture2D:
			return cached_any as Texture2D
		return null
	var path: String = str(HUMAN_MODE_SKIN_BY_MODE.get(cache_key, ""))
	if path.is_empty():
		_human_mode_skin_cache[cache_key] = null
		return null
	if not ResourceLoader.exists(path):
		_human_mode_skin_cache[cache_key] = null
		return null
	var loaded_any: Variant = load(path)
	if loaded_any is Texture2D:
		var raw_tex: Texture2D = loaded_any as Texture2D
		var keyed_tex: Texture2D = _key_black_to_alpha_texture(raw_tex)
		_human_mode_skin_cache[cache_key] = keyed_tex
		return keyed_tex
	_human_mode_skin_cache[cache_key] = null
	return null

func _apply_human_mode_skin_to_button(button: Button, mode_id: String, paid: bool, denomination: int) -> void:
	if button == null:
		return
	var label_text: String = "%s  $%d" % [mode_id, denomination] if paid else mode_id
	var tex: Texture2D = _human_mode_skin_for_mode(mode_id)
	button.tooltip_text = label_text
	if tex == null:
		button.text = label_text
		_apply_font(button, _font_regular, 12)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
		return
	button.icon = tex
	button.text = ""
	button.custom_minimum_size = Vector2(144.0, 64.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)
	button.add_theme_constant_override("h_separation", 0)
	_style_usd_sprite_button(button, true)

func _store_category_skin_for_id(category_id: String) -> Texture2D:
	var cache_key: String = category_id.strip_edges().to_upper()
	if _store_category_skin_cache.has(cache_key):
		var cached_any: Variant = _store_category_skin_cache.get(cache_key)
		if cached_any is Texture2D:
			return cached_any as Texture2D
		return null
	var path: String = str(STORE_CATEGORY_SKIN_BY_ID.get(cache_key, ""))
	if path.is_empty():
		_store_category_skin_cache[cache_key] = null
		return null
	if not ResourceLoader.exists(path):
		_store_category_skin_cache[cache_key] = null
		return null
	var loaded_any: Variant = load(path)
	if loaded_any is Texture2D:
		var raw_tex: Texture2D = loaded_any as Texture2D
		var keyed_tex: Texture2D = _key_neutral_to_alpha_texture(raw_tex, 1024, 512, 0.03)
		_store_category_skin_cache[cache_key] = keyed_tex
		return keyed_tex
	_store_category_skin_cache[cache_key] = null
	return null

func _apply_store_category_skin_to_button(button: Button, category_id: String, label_text: String) -> void:
	if button == null:
		return
	var tex: Texture2D = _store_category_skin_for_id(category_id)
	button.tooltip_text = label_text
	if tex == null:
		button.icon = null
		button.material = null
		button.text = label_text
		return
	button.icon = tex
	button.text = ""
	button.material = null
	button.custom_minimum_size = Vector2(
		maxf(button.custom_minimum_size.x, STORE_CATEGORY_BUTTON_MIN_SIZE.x),
		maxf(button.custom_minimum_size.y, STORE_CATEGORY_BUTTON_MIN_SIZE.y)
	)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)
	button.set("icon_max_width", STORE_CATEGORY_ICON_MAX_WIDTH)
	button.add_theme_constant_override("h_separation", 0)
	_style_usd_sprite_button(button, true)

func _async_mode_skin_for_label(label: String) -> Texture2D:
	var cache_key: String = label.strip_edges().to_upper()
	if _async_mode_skin_cache.has(cache_key):
		var cached_any: Variant = _async_mode_skin_cache.get(cache_key)
		if cached_any is Texture2D:
			return cached_any as Texture2D
		return null
	var path: String = str(ASYNC_MODE_SKIN_BY_LABEL.get(cache_key, ""))
	if path.is_empty():
		_async_mode_skin_cache[cache_key] = null
		return null
	if not ResourceLoader.exists(path):
		_async_mode_skin_cache[cache_key] = null
		return null
	var loaded_any: Variant = load(path)
	if loaded_any is Texture2D:
		var raw_tex: Texture2D = loaded_any as Texture2D
		var keyed_tex: Texture2D = _key_black_to_alpha_texture(raw_tex, 512, 256)
		_async_mode_skin_cache[cache_key] = keyed_tex
		return keyed_tex
	_async_mode_skin_cache[cache_key] = null
	return null

func _async_cycle_skin_for_label(label: String) -> Texture2D:
	var cache_key: String = label.strip_edges().to_upper()
	if _async_cycle_skin_cache.has(cache_key):
		var cached_any: Variant = _async_cycle_skin_cache.get(cache_key)
		if cached_any is Texture2D:
			return cached_any as Texture2D
		return null
	var path: String = str(ASYNC_CYCLE_SKIN_BY_LABEL.get(cache_key, ""))
	if path.is_empty():
		_async_cycle_skin_cache[cache_key] = null
		return null
	if not ResourceLoader.exists(path):
		_async_cycle_skin_cache[cache_key] = null
		return null
	var loaded_any: Variant = load(path)
	if loaded_any is Texture2D:
		var raw_tex: Texture2D = loaded_any as Texture2D
		var keyed_tex: Texture2D = _key_black_to_alpha_texture(raw_tex, 512, 256)
		_async_cycle_skin_cache[cache_key] = keyed_tex
		return keyed_tex
	_async_cycle_skin_cache[cache_key] = null
	return null

func _apply_async_cycle_skin_to_button(button: Button, label: String, paid: bool, denomination: int) -> void:
	if button == null:
		return
	var label_text: String = "%s  $%d" % [label, denomination] if paid else label
	var tex: Texture2D = _async_cycle_skin_for_label(label)
	button.tooltip_text = label_text
	if tex == null:
		button.text = label_text
		_apply_font(button, _font_regular, 12)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
		return
	button.icon = tex
	button.text = ""
	button.custom_minimum_size = Vector2(256.0, 96.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)
	button.set("icon_max_width", 240)
	button.add_theme_constant_override("h_separation", 0)
	_style_usd_sprite_button(button, true)

func _apply_async_mode_skin_to_button(button: Button, label: String, paid: bool, denomination: int) -> void:
	if button == null:
		return
	var label_text: String = "%s  $%d" % [label, denomination] if paid else label
	var tex: Texture2D = _async_mode_skin_for_label(label)
	button.tooltip_text = label_text
	if tex == null:
		button.text = label_text
		_apply_font(button, _font_regular, 12)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
		return
	button.icon = tex
	button.text = ""
	button.custom_minimum_size = Vector2(352.0, 112.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)
	button.set("icon_max_width", 336)
	button.add_theme_constant_override("h_separation", 0)
	_style_usd_sprite_button(button, true)

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
	_apply_close_skin_to_button(button)
	_apply_cancel_skin_to_button(button)

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
		if button == dash_settings_close:
			# Settings uses dense form controls; keep close button compact and avoid oversized sprite overlap.
			button.set_meta("sf_close_skin", false)
			button.custom_minimum_size = Vector2(220.0, 56.0)
		if button == dash_store_close:
			button.set_meta("sf_close_skin_min_w", STORE_CLOSE_SKIN_MIN_WIDTH)
			button.set_meta("sf_close_skin_min_h", STORE_CLOSE_SKIN_MIN_HEIGHT)
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
	_ensure_buffs_cart_ui()
	_ensure_buffs_owned_panel()
	_ensure_buffs_library_nav()
	_buff_mode_initialized = false
	_set_buff_mode(_buff_active_mode)

func _sync_buff_mode_tabs() -> void:
	if buffs_mode_vs_button == null or buffs_mode_async_button == null:
		return
	var active_bg: Color = Color(0.95, 0.85, 0.55)
	var active_border: Color = Color(0.1, 0.08, 0.02)
	var inactive_bg: Color = Color(0.12, 0.13, 0.16)
	var inactive_border: Color = Color(0.45, 0.48, 0.6)
	var inactive_text: Color = Color(0.92, 0.92, 0.92)
	if _buff_active_mode == BUFF_MODE_ASYNC:
		_style_button(buffs_mode_vs_button, inactive_bg, inactive_border, inactive_text)
		_style_button(buffs_mode_async_button, active_bg, active_border, Color(0.1, 0.08, 0.02))
	else:
		_style_button(buffs_mode_vs_button, active_bg, active_border, Color(0.1, 0.08, 0.02))
		_style_button(buffs_mode_async_button, inactive_bg, inactive_border, inactive_text)

func _set_buff_mode(mode: String) -> void:
	var normalized_mode: String = BUFF_MODE_ASYNC if mode == BUFF_MODE_ASYNC else BUFF_MODE_VS
	if _buff_mode_initialized and normalized_mode == _buff_active_mode:
		_sync_buff_mode_tabs()
		return
	if _buff_mode_initialized:
		_persist_buff_profile_state()
	_buff_active_mode = normalized_mode
	_load_buff_profile_state()
	_buff_library_selected_ids.clear()
	_buff_selected_id = ""
	_buff_selected_origin = ""
	_buff_selected_slot_index = -1
	_buff_cart_counts.clear()
	_apply_buffs_mode_copy()
	_sync_buff_mode_tabs()
	_sync_buff_category_tabs()
	_refresh_buffs_library_buttons()
	_refresh_buffs_owned_ui()
	_refresh_buffs_loadout_ui()
	_refresh_buffs_cart_ui()
	if not _buff_loadout_ids.is_empty():
		_set_selected_buff(_buff_loadout_ids[0], "loadout", 0)
	else:
		_update_buff_details()
	_buff_mode_initialized = true
	_refresh_dash_account_snapshot()

func _apply_buffs_mode_copy() -> void:
	var sub_label: Label = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsSub
	if _buff_active_mode == BUFF_MODE_ASYNC:
		if sub_label != null:
			sub_label.text = "ASYNC buffs: stronger and longer. Stacks allowed when owned."
		if buffs_footer_label != null:
			buffs_footer_label.text = "Async uses limited-item stacks. Equip repeats only when you own multiple copies."
		if buffs_loadout_header != null:
			buffs_loadout_header.text = "LOADOUT (ASYNC)"
		if _buff_owned_empty_label != null:
			_buff_owned_empty_label.text = "Drag from Library to buy Async copies into Owned."
	else:
		if sub_label != null:
			sub_label.text = "VS buffs: balanced loadout with one copy per buff."
		if buffs_footer_label != null:
			buffs_footer_label.text = "VS loadout enforces one copy per buff for fair match balance."
		if buffs_loadout_header != null:
			buffs_loadout_header.text = "LOADOUT (VS)"
		if _buff_owned_empty_label != null:
			_buff_owned_empty_label.text = "Drag selected buffs from Library to buy ownership."

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
	empty_label.text = "Drag selected buffs from Library to buy ownership."
	list.add_child(empty_label)
	_buff_owned_panel = panel
	_buff_owned_header_label = header
	_buff_owned_empty_label = empty_label
	_buff_owned_flow = list
	_style_panel(panel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_apply_font(header, _font_semibold, 13)
	_apply_font(empty_label, _font_regular, 12)

func _ensure_buffs_cart_ui() -> void:
	if _buff_cart_root != null and is_instance_valid(_buff_cart_root):
		_refresh_buffs_cart_ui()
		return
	if buffs_body_vbox == null:
		return
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "BuffCartRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0.0, 188.0)
	root.add_theme_constant_override("separation", 6)
	buffs_body_vbox.add_child(root)
	var footer: Control = buffs_body_vbox.get_node_or_null("BuffsFooter") as Control
	if footer != null:
		buffs_body_vbox.move_child(root, footer.get_index())

	var line: ColorRect = ColorRect.new()
	line.name = "BuffCartLine"
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.color = Color(0.92, 0.8, 0.38, 0.85)
	root.add_child(line)

	var hint_label: Label = Label.new()
	hint_label.name = "BuffCartHint"
	hint_label.text = "CART: drag store buffs below this line to add them."
	root.add_child(hint_label)
	_apply_font(hint_label, _font_regular, 11)

	var panel: Panel = Panel.new()
	panel.name = "BuffCartPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0.0, 156.0)
	root.add_child(panel)
	_style_panel(panel, Color(0.08, 0.09, 0.12, 0.92), Color(0.45, 0.48, 0.6, 0.8))

	var panel_vbox: VBoxContainer = VBoxContainer.new()
	panel_vbox.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	panel_vbox.offset_left = 10.0
	panel_vbox.offset_top = 10.0
	panel_vbox.offset_right = -10.0
	panel_vbox.offset_bottom = -10.0
	panel_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(panel_vbox)

	var header: Label = Label.new()
	header.text = "RUNNING TALLY"
	panel_vbox.add_child(header)
	_apply_font(header, _font_semibold, 12)

	var rows_scroll: ScrollContainer = ScrollContainer.new()
	rows_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_vbox.add_child(rows_scroll)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "BuffCartRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	rows_scroll.add_child(rows)

	var subtotal_row: HBoxContainer = HBoxContainer.new()
	subtotal_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtotal_row.alignment = BoxContainer.ALIGNMENT_END
	subtotal_row.add_theme_constant_override("separation", 8)
	panel_vbox.add_child(subtotal_row)

	var subtotal: Label = Label.new()
	subtotal.name = "BuffCartSubtotal"
	subtotal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtotal.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtotal_row.add_child(subtotal)
	_apply_font(subtotal, _font_semibold, 12)

	var clear_button: Button = Button.new()
	clear_button.text = "CLEAR"
	clear_button.custom_minimum_size = Vector2(94.0, 30.0)
	clear_button.pressed.connect(_on_buff_cart_clear_pressed)
	subtotal_row.add_child(clear_button)
	_apply_font(clear_button, _font_regular, 12)
	_style_button(clear_button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))

	var buy_button: Button = Button.new()
	buy_button.text = "BUY"
	buy_button.custom_minimum_size = Vector2(106.0, 30.0)
	buy_button.pressed.connect(_on_buff_cart_buy_pressed)
	subtotal_row.add_child(buy_button)
	_apply_font(buy_button, _font_semibold, 12)
	_style_button(buy_button, Color(0.16, 0.14, 0.1), Color(0.75, 0.65, 0.35), Color(0.98, 0.94, 0.8))

	_buff_cart_root = root
	_buff_cart_line = line
	_buff_cart_panel = panel
	_buff_cart_rows = rows
	_buff_cart_subtotal_label = subtotal
	_buff_cart_buy_button = buy_button
	_buff_cart_clear_button = clear_button
	_refresh_buffs_cart_ui()

func _buff_cart_display_name(buff: Dictionary, buff_id: String) -> String:
	var name: String = str(buff.get("name", buff_id))
	var tier: String = str(buff.get("tier", "classic")).to_upper()
	var category: String = str(buff.get("category", "unknown")).to_upper()
	return "%s | %s | %s" % [category, name, tier]

func _buff_cart_max_qty_for_id(buff_id: String) -> int:
	if _buff_mode_allows_duplicates():
		return 99
	if _buff_owned_ids.has(buff_id):
		return 0
	return 1

func _buff_cart_subtotal_usd() -> float:
	var subtotal_usd: float = 0.0
	for buff_id_any in _buff_cart_counts.keys():
		var buff_id: String = str(buff_id_any)
		var qty: int = maxi(0, int(_buff_cart_counts.get(buff_id_any, 0)))
		if qty <= 0:
			continue
		var buff: Dictionary = BuffCatalog.get_buff(buff_id)
		if buff.is_empty():
			continue
		subtotal_usd += _buff_price_usd(buff) * float(qty)
	return subtotal_usd

func _refresh_buffs_cart_ui() -> void:
	if _buff_cart_rows == null:
		return
	for child in _buff_cart_rows.get_children():
		child.queue_free()
	var buff_keys: Array[String] = []
	var normalized_counts: Dictionary = {}
	for buff_id_any in _buff_cart_counts.keys():
		var buff_id: String = str(buff_id_any).strip_edges()
		if buff_id == "":
			continue
		var max_qty: int = _buff_cart_max_qty_for_id(buff_id)
		if max_qty <= 0:
			continue
		var qty: int = maxi(1, int(_buff_cart_counts.get(buff_id_any, 1)))
		if qty > max_qty:
			qty = max_qty
		buff_keys.append(buff_id)
		normalized_counts[buff_id] = qty
	buff_keys.sort_custom(func(a: String, b: String) -> bool:
		var buff_a: Dictionary = BuffCatalog.get_buff(a)
		var buff_b: Dictionary = BuffCatalog.get_buff(b)
		return _buff_cart_display_name(buff_a, a) < _buff_cart_display_name(buff_b, b)
	)
	_buff_cart_counts.clear()
	for buff_id in buff_keys:
		var qty: int = maxi(1, int(normalized_counts.get(buff_id, 1)))
		_buff_cart_counts[buff_id] = qty
	for buff_id in buff_keys:
		var buff: Dictionary = BuffCatalog.get_buff(buff_id)
		if buff.is_empty():
			continue
		var qty: int = maxi(1, int(_buff_cart_counts.get(buff_id, 1)))
		var unit_price: float = _buff_price_usd(buff)
		var line_total: float = unit_price * float(qty)
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)
		_buff_cart_rows.add_child(row)

		var name_label: Label = Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = _buff_cart_display_name(buff, buff_id)
		name_label.clip_text = true
		row.add_child(name_label)
		_apply_font(name_label, _font_regular, 11)

		var qty_spin: SpinBox = SpinBox.new()
		qty_spin.custom_minimum_size = Vector2(72.0, 26.0)
		qty_spin.min_value = 1.0
		qty_spin.max_value = float(_buff_cart_max_qty_for_id(buff_id))
		qty_spin.step = 1.0
		qty_spin.allow_greater = false
		qty_spin.allow_lesser = false
		qty_spin.rounded = true
		qty_spin.value = float(qty)
		if _buff_cart_max_qty_for_id(buff_id) <= 1:
			qty_spin.editable = false
		var qty_cb: Callable = Callable(self, "_on_buff_cart_qty_changed").bind(buff_id)
		qty_spin.value_changed.connect(qty_cb)
		row.add_child(qty_spin)

		var line_label: Label = Label.new()
		line_label.custom_minimum_size = Vector2(84.0, 0.0)
		line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line_label.text = "$%.2f" % line_total
		row.add_child(line_label)
		_apply_font(line_label, _font_regular, 11)

		var remove_button: Button = Button.new()
		remove_button.text = "X"
		remove_button.custom_minimum_size = Vector2(34.0, 26.0)
		var remove_cb: Callable = Callable(self, "_on_buff_cart_remove_pressed").bind(buff_id)
		remove_button.pressed.connect(remove_cb)
		row.add_child(remove_button)
		_apply_font(remove_button, _font_semibold, 11)
		_style_button(remove_button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))

	if buff_keys.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "Cart empty. Drag buffs from Store into this cart area."
		_buff_cart_rows.add_child(empty_label)
		_apply_font(empty_label, _font_regular, 11)
		_buff_cart_empty_label = empty_label
	else:
		_buff_cart_empty_label = null
	if _buff_cart_subtotal_label != null:
		_buff_cart_subtotal_label.text = "Subtotal: $%.2f" % _buff_cart_subtotal_usd()
	if _buff_cart_buy_button != null:
		_buff_cart_buy_button.disabled = buff_keys.is_empty()
	if _buff_cart_clear_button != null:
		_buff_cart_clear_button.disabled = buff_keys.is_empty()

func _add_buffs_to_cart(ids: Array[String]) -> int:
	var added: int = 0
	for buff_id in ids:
		var clean_id: String = str(buff_id).strip_edges()
		if clean_id == "":
			continue
		var buff: Dictionary = BuffCatalog.get_buff(clean_id)
		if buff.is_empty():
			continue
		var max_qty: int = _buff_cart_max_qty_for_id(clean_id)
		if max_qty <= 0:
			continue
		var current_qty: int = int(_buff_cart_counts.get(clean_id, 0))
		if current_qty >= max_qty:
			continue
		_buff_cart_counts[clean_id] = current_qty + 1
		added += 1
	_refresh_buffs_cart_ui()
	return added

func _drop_library_to_cart(ids: Array[String]) -> void:
	var added: int = _add_buffs_to_cart(ids)
	if added <= 0:
		status_label.text = "Cart unchanged (already owned or max quantity reached)."
		return
	status_label.text = "Added %d buff type(s) to cart." % added

func _on_buff_cart_qty_changed(value: float, buff_id: String) -> void:
	var clean_id: String = buff_id.strip_edges()
	if clean_id == "":
		return
	if not _buff_cart_counts.has(clean_id):
		return
	var max_qty: int = _buff_cart_max_qty_for_id(clean_id)
	if max_qty <= 0:
		_buff_cart_counts.erase(clean_id)
		_refresh_buffs_cart_ui()
		return
	var qty: int = clampi(int(round(value)), 1, max_qty)
	_buff_cart_counts[clean_id] = qty
	_refresh_buffs_cart_ui()

func _on_buff_cart_remove_pressed(buff_id: String) -> void:
	var clean_id: String = buff_id.strip_edges()
	if clean_id == "":
		return
	if _buff_cart_counts.has(clean_id):
		_buff_cart_counts.erase(clean_id)
	_refresh_buffs_cart_ui()

func _on_buff_cart_clear_pressed() -> void:
	_buff_cart_counts.clear()
	_refresh_buffs_cart_ui()
	status_label.text = "Buff cart cleared."

func _on_buff_cart_buy_pressed() -> void:
	if _buff_cart_counts.is_empty():
		status_label.text = "Cart is empty."
		return
	var purchase_ids: Array[String] = []
	for buff_id_any in _buff_cart_counts.keys():
		var buff_id: String = str(buff_id_any)
		var qty: int = maxi(0, int(_buff_cart_counts.get(buff_id_any, 0)))
		for i in range(qty):
			purchase_ids.append(buff_id)
	if purchase_ids.is_empty():
		status_label.text = "Cart is empty."
		return
	var purchase: Dictionary = _purchase_library_buffs(purchase_ids)
	if bool(purchase.get("ok", false)):
		var bought_count: int = 0
		var purchased_ids_any: Variant = purchase.get("purchased_ids", [])
		if typeof(purchased_ids_any) == TYPE_ARRAY:
			bought_count = (purchased_ids_any as Array).size()
		var total_cost_usd: float = float(purchase.get("total_cost_usd", 0.0))
		_buff_cart_counts.clear()
		_refresh_buffs_cart_ui()
		status_label.text = "Purchase complete: %d buff(s) for $%.2f." % [bought_count, total_cost_usd]
		return
	var reason: String = str(purchase.get("reason", "purchase_failed"))
	if reason == "iap_not_wired":
		status_label.text = "Buff purchases require payment wiring (IAP disabled)."
		return
	status_label.text = "Purchase failed."

func _buff_filter_order() -> PackedStringArray:
	return PackedStringArray([BUFF_FILTER_HIVE, BUFF_FILTER_UNIT, BUFF_FILTER_LANE, BUFF_FILTER_ACROSS])

func _buff_filter_label(filter_id: String) -> String:
	match filter_id:
		BUFF_FILTER_HIVE:
			return "HIVE"
		BUFF_FILTER_UNIT:
			return "UNIT"
		BUFF_FILTER_LANE:
			return "LANE"
		BUFF_FILTER_ACROSS:
			return "ACROSS"
		_:
			return filter_id.to_upper()

func _normalize_buff_filter(filter_id: String) -> String:
	var cleaned: String = filter_id.strip_edges().to_lower()
	for valid_filter in _buff_filter_order():
		if cleaned == valid_filter:
			return valid_filter
	return BUFF_FILTER_HIVE

func _buff_matches_category_filter(buff: Dictionary) -> bool:
	var filter_id: String = _normalize_buff_filter(_buff_category_filter)
	var category: String = str(buff.get("category", "")).to_lower()
	var target_type: String = str(buff.get("target_type", "none")).to_lower()
	match filter_id:
		BUFF_FILTER_HIVE:
			return category == "hive"
		BUFF_FILTER_UNIT:
			return category == "unit"
		BUFF_FILTER_LANE:
			return category == "lane"
		BUFF_FILTER_ACROSS:
			return target_type == "none"
		_:
			return true

func _set_buff_category_filter(filter_id: String) -> void:
	var normalized_filter: String = _normalize_buff_filter(filter_id)
	if normalized_filter == _buff_category_filter:
		_sync_buff_category_tabs()
		return
	_buff_category_filter = normalized_filter
	_sync_buff_category_tabs()
	_refresh_buffs_library_buttons()
	if _buff_selected_origin == "library":
		var selected_buff: Dictionary = BuffCatalog.get_buff(_buff_selected_id)
		if selected_buff.is_empty() or not _buff_matches_category_filter(selected_buff):
			_set_selected_buff("", "", -1)

func _sync_buff_category_tabs() -> void:
	if _buff_category_buttons.is_empty():
		return
	var active_bg: Color = Color(0.95, 0.85, 0.55)
	var active_border: Color = Color(0.1, 0.08, 0.02)
	var inactive_bg: Color = Color(0.12, 0.13, 0.16)
	var inactive_border: Color = Color(0.45, 0.48, 0.6)
	var inactive_text: Color = Color(0.92, 0.92, 0.92)
	for filter_any in _buff_filter_order():
		var button: Button = _buff_category_buttons.get(filter_any, null) as Button
		if button == null:
			continue
		if filter_any == _buff_category_filter:
			_style_button(button, active_bg, active_border, Color(0.1, 0.08, 0.02))
		else:
			_style_button(button, inactive_bg, inactive_border, inactive_text)

func _ensure_buffs_category_tabs() -> void:
	if buffs_library_vbox == null:
		return
	if _buff_category_tabs_row != null and is_instance_valid(_buff_category_tabs_row):
		_sync_buff_category_tabs()
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "BuffTypeTabs"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)
	buffs_library_vbox.add_child(row)
	if buffs_library_header != null:
		buffs_library_vbox.move_child(row, buffs_library_header.get_index() + 1)
	_buff_category_tabs_row = row
	_buff_category_buttons.clear()
	for filter_id in _buff_filter_order():
		var button: Button = Button.new()
		button.text = _buff_filter_label(filter_id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 34)
		_apply_font(button, _font_semibold, 11)
		var press_cb: Callable = Callable(self, "_set_buff_category_filter").bind(filter_id)
		button.pressed.connect(press_cb)
		row.add_child(button)
		_buff_category_buttons[filter_id] = button
	_sync_buff_category_tabs()

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
	_ensure_buffs_category_tabs()
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
		_ensure_embedded_hex_background(panel, StringName("dash"))
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
	var allow_duplicates: bool = _buff_mode_allows_duplicates()
	var owned_any: Variant = []
	if ProfileManager.has_method("get_owned_buff_ids_for_mode"):
		owned_any = ProfileManager.call("get_owned_buff_ids_for_mode", _buff_active_mode)
	elif ProfileManager.has_method("get_owned_buff_ids"):
		owned_any = ProfileManager.call("get_owned_buff_ids")
	_buff_owned_ids.clear()
	if typeof(owned_any) == TYPE_ARRAY:
		for buff_id_v in owned_any as Array:
			var buff_id: String = str(buff_id_v).strip_edges()
			if buff_id == "":
				continue
			if BuffCatalog.get_buff(buff_id).is_empty():
				continue
			if not allow_duplicates and _buff_owned_ids.has(buff_id):
				continue
			_buff_owned_ids.append(buff_id)
	var loadout_any: Variant = []
	if ProfileManager.has_method("get_buff_loadout_ids_for_mode"):
		loadout_any = ProfileManager.call("get_buff_loadout_ids_for_mode", _buff_active_mode)
	elif ProfileManager.has_method("get_buff_loadout_ids"):
		loadout_any = ProfileManager.call("get_buff_loadout_ids")
	_buff_loadout_ids.clear()
	if typeof(loadout_any) == TYPE_ARRAY:
		for buff_id_v in loadout_any as Array:
			var buff_id: String = str(buff_id_v).strip_edges()
			if buff_id == "":
				continue
			if BuffCatalog.get_buff(buff_id).is_empty():
				continue
			if not allow_duplicates and _buff_loadout_ids.has(buff_id):
				continue
			_buff_loadout_ids.append(buff_id)
	while _buff_loadout_ids.size() < BUFF_LOADOUT_SIZE:
		var fallback: String = _fallback_buff_for_index(_buff_loadout_ids.size())
		if fallback == "":
			break
		if not allow_duplicates and _buff_loadout_ids.has(fallback):
			break
		_buff_loadout_ids.append(fallback)
	for buff_id in _buff_loadout_ids:
		if buff_id == "":
			continue
		if not allow_duplicates and _buff_owned_ids.has(buff_id):
			continue
		if allow_duplicates:
			var need_count: int = _count_buff_in_ids(_buff_loadout_ids, buff_id)
			var have_count: int = _count_buff_in_ids(_buff_owned_ids, buff_id)
			while have_count < need_count:
				_buff_owned_ids.append(buff_id)
				have_count += 1
		else:
			_buff_owned_ids.append(buff_id)
	_persist_buff_profile_state()

func _persist_buff_profile_state() -> void:
	if ProfileManager.has_method("set_owned_buff_ids_for_mode"):
		ProfileManager.call("set_owned_buff_ids_for_mode", _buff_active_mode, _buff_owned_ids)
	elif ProfileManager.has_method("set_owned_buff_ids"):
		ProfileManager.call("set_owned_buff_ids", _buff_owned_ids)
	if ProfileManager.has_method("set_buff_loadout_ids_for_mode"):
		ProfileManager.call("set_buff_loadout_ids_for_mode", _buff_active_mode, _buff_loadout_ids)
	elif ProfileManager.has_method("set_buff_loadout_ids"):
		ProfileManager.call("set_buff_loadout_ids", _buff_loadout_ids)
	_refresh_dash_account_snapshot()

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

func _buff_price_usd(buff: Dictionary) -> float:
	var tier_name: String = str(buff.get("tier", "classic")).to_lower()
	if tier_name != "premium" and tier_name != "elite":
		tier_name = "classic"
	return maxf(0.0, float(BUFF_PRICE_USD_BY_TIER.get(tier_name, 0.20)))

func _buff_mode_allows_duplicates() -> bool:
	return _buff_active_mode == BUFF_MODE_ASYNC

func _count_buff_in_ids(buff_ids: Array[String], buff_id: String) -> int:
	if buff_id == "":
		return 0
	var out: int = 0
	for owned_id in buff_ids:
		if owned_id == buff_id:
			out += 1
	return out

func _purchase_library_buffs(ids: Array[String]) -> Dictionary:
	var purchase_ids: Array[String] = []
	var total_cost_usd: float = 0.0
	var total_cost_cents: int = 0
	var seen_nonstack_batch: Dictionary = {}
	for buff_id in ids:
		var clean_buff_id: String = buff_id.strip_edges()
		if clean_buff_id == "":
			continue
		var buff: Dictionary = BuffCatalog.get_buff(clean_buff_id)
		if buff.is_empty():
			continue
		if not _buff_mode_allows_duplicates():
			if _buff_owned_ids.has(clean_buff_id):
				continue
			if seen_nonstack_batch.has(clean_buff_id):
				continue
			seen_nonstack_batch[clean_buff_id] = true
		purchase_ids.append(clean_buff_id)
		var unit_price_usd: float = _buff_price_usd(buff)
		total_cost_usd += unit_price_usd
		total_cost_cents += int(round(unit_price_usd * 100.0))
	if purchase_ids.is_empty():
		return {"ok": false, "reason": "already_owned_or_invalid", "total_cost_usd": 0.0}
	if not LOCAL_REAL_PURCHASES_ENABLED:
		return {
			"ok": false,
			"reason": "iap_not_wired",
			"total_cost_usd": total_cost_usd
		}
	for buff_id in purchase_ids:
		_buff_owned_ids.append(buff_id)
	_persist_buff_profile_state()
	_refresh_buffs_owned_ui()
	_refresh_buffs_library_buttons()
	_update_buff_details()
	return {
		"ok": true,
		"purchased_ids": purchase_ids.duplicate(),
		"total_cost_usd": total_cost_usd,
		"total_cost_cents": total_cost_cents
	}

func _has_async_copy_available_for_slot(buff_id: String, target_slot: int) -> bool:
	if _buff_active_mode != BUFF_MODE_ASYNC:
		return true
	var owned_count: int = _count_buff_in_ids(_buff_owned_ids, buff_id)
	var equipped_count_excluding_target: int = 0
	for idx in range(mini(_buff_loadout_ids.size(), BUFF_LOADOUT_SIZE)):
		if idx == target_slot:
			continue
		if _buff_loadout_ids[idx] == buff_id:
			equipped_count_excluding_target += 1
	return owned_count > equipped_count_excluding_target

func _refresh_buffs_library_buttons() -> void:
	for button in _buff_library_runtime_buttons:
		if button != null and is_instance_valid(button):
			button.queue_free()
	_buff_library_runtime_buttons.clear()
	var counts: Dictionary = {"classic": 0, "premium": 0, "elite": 0}
	var visible_total: int = 0
	for buff in _buff_library_all:
		if not _buff_matches_category_filter(buff):
			continue
		var tier_id: String = str(buff.get("tier", "classic")).to_lower()
		if not _buff_library_tier_grids.has(tier_id):
			continue
		visible_total += 1
		counts[tier_id] = int(counts.get(tier_id, 0)) + 1
		var buff_id: String = str(buff.get("id", ""))
		var selected: bool = bool(_buff_library_selected_ids.get(buff_id, false))
		var selected_mark: String = "[x] " if selected else "[ ] "
		var price_usd: float = _buff_price_usd(buff)
		var owned_count: int = _count_buff_in_ids(_buff_owned_ids, buff_id)
		var ownership_tag: String = ""
		if _buff_active_mode == BUFF_MODE_ASYNC:
			ownership_tag = " x%d" % owned_count if owned_count > 0 else ""
		elif owned_count > 0:
			ownership_tag = " (OWNED)"
		var button: Button = Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 26.0)
		button.clip_text = true
		button.text = "%s%s%s - $%.2f" % [selected_mark, str(buff.get("name", buff_id)), ownership_tag, price_usd]
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
		buffs_library_header.text = "BUFF STORE (%d) [%s]  TYPE: %s" % [visible_total, _buff_active_mode.to_upper(), _buff_filter_label(_buff_category_filter)]

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
	var ordered_ids: Array[String] = []
	var counts_by_id: Dictionary = {}
	for buff_id in _buff_owned_ids:
		if buff_id == "":
			continue
		if not counts_by_id.has(buff_id):
			counts_by_id[buff_id] = 0
			ordered_ids.append(buff_id)
		counts_by_id[buff_id] = int(counts_by_id.get(buff_id, 0)) + 1
	for buff_id in ordered_ids:
		var buff: Dictionary = BuffCatalog.get_buff(buff_id)
		if buff.is_empty():
			continue
		var owned_count: int = int(counts_by_id.get(buff_id, 0))
		var button: Button = Button.new()
		button.text = str(buff.get("name", buff_id))
		if owned_count > 1:
			button.text = "%s x%d" % [button.text, owned_count]
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
		if _buff_active_mode == BUFF_MODE_ASYNC:
			_buff_owned_header_label.text = "OWNED (%d TYPES / %d TOTAL)" % [ordered_ids.size(), _buff_owned_ids.size()]
		else:
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
		var mode_tag: String = _buff_active_mode.to_upper()
		var price_usd: float = _buff_price_usd(buff)
		if _buff_active_mode == BUFF_MODE_ASYNC:
			var owned_count: int = _count_buff_in_ids(_buff_owned_ids, _buff_selected_id)
			buffs_detail_meta_label.text = "Tier: %s | Category: %s | Source: %s | Mode: %s | Cost: $%.2f | Copies: %d" % [tier, category, origin_tag, mode_tag, price_usd, owned_count]
		else:
			buffs_detail_meta_label.text = "Tier: %s | Category: %s | Source: %s | Mode: %s | Cost: $%.2f" % [tier, category, origin_tag, mode_tag, price_usd]

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
		status_label.text = "Drop into CART (below line) or OWNED to add %d buff(s)." % payload.size()
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
		if _control_contains_screen(_buff_cart_panel, screen_pos):
			_drop_library_to_cart(payload_ids)
			return
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
	var purchase: Dictionary = _purchase_library_buffs(ids)
	if bool(purchase.get("ok", false)):
		var bought_count: int = 0
		var purchased_ids_any: Variant = purchase.get("purchased_ids", [])
		if typeof(purchased_ids_any) == TYPE_ARRAY:
			bought_count = (purchased_ids_any as Array).size()
		var total_cost_usd: float = float(purchase.get("total_cost_usd", 0.0))
		status_label.text = "Purchased %d buff(s) for $%.2f." % [bought_count, total_cost_usd]
		return
	var reason: String = str(purchase.get("reason", "purchase_failed"))
	if reason == "iap_not_wired":
		status_label.text = "Buff purchases require payment wiring (IAP disabled)."
		return
	status_label.text = "All selected buffs already owned."

func _drop_owned_to_loadout(buff_id: String, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= BUFF_LOADOUT_SIZE:
		return
	if not _buff_owned_ids.has(buff_id):
		status_label.text = "You must own a buff before equipping."
		return
	while _buff_loadout_ids.size() < BUFF_LOADOUT_SIZE:
		_buff_loadout_ids.append(_fallback_buff_for_index(_buff_loadout_ids.size()))
	if _buff_mode_allows_duplicates():
		if not _has_async_copy_available_for_slot(buff_id, slot_index):
			status_label.text = "No additional Async copy available for this slot."
			return
		_buff_loadout_ids[slot_index] = buff_id
		_persist_buff_profile_state()
		_set_selected_buff(buff_id, "loadout", slot_index)
		status_label.text = "Equipped to slot %d (Async stack)." % (slot_index + 1)
		return
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
		_drop_library_to_cart([_buff_selected_id])
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
		if _buff_active_mode == BUFF_MODE_ASYNC:
			var owned_count: int = _count_buff_in_ids(_buff_owned_ids, _buff_selected_id)
			var equipped_count: int = _count_buff_in_ids(_buff_loadout_ids, _buff_selected_id)
			if owned_count <= equipped_count:
				status_label.text = "Cannot remove: all copies are equipped in Async loadout."
				return
		elif _buff_loadout_ids.has(_buff_selected_id):
			status_label.text = "Cannot remove: buff is equipped in loadout."
			return
		if _buff_owned_ids.has(_buff_selected_id):
			var remove_index: int = _buff_owned_ids.find(_buff_selected_id)
			if remove_index >= 0:
				_buff_owned_ids.remove_at(remove_index)
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
	var current_buff: String = ""
	if exclude_slot >= 0 and exclude_slot < _buff_loadout_ids.size():
		current_buff = _buff_loadout_ids[exclude_slot]
	if _buff_active_mode == BUFF_MODE_ASYNC:
		for buff_id in _buff_owned_ids:
			if buff_id == "":
				continue
			if buff_id == current_buff:
				continue
			if _has_async_copy_available_for_slot(buff_id, exclude_slot):
				return buff_id
		return ""
	for buff_id in _buff_owned_ids:
		if buff_id == current_buff:
			continue
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
	_store_category_skin_cache.clear()
	_clear_store_buttons()
	store_category_grid.columns = STORE_CATEGORY_GRID_COLUMNS
	for category in STORE_CATEGORIES:
		var button := Button.new()
		var title_text: String = str(category.get("title", "Category"))
		button.text = title_text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var category_id := str(category.get("id", ""))
		var bound_category_id: String = category_id
		button.pressed.connect(func() -> void:
			_on_store_category_button_pressed(bound_category_id)
		)
		store_category_grid.add_child(button)
		_apply_font(button, _font_semibold, 14)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
		_apply_store_category_skin_to_button(button, category_id, title_text)
		_store_category_buttons.append(button)
	_show_store_landing()


func _on_store_category_button_pressed(category_id: String) -> void:
	var resolved_id: String = category_id.strip_edges()
	if resolved_id.is_empty():
		return
	_open_store_category(resolved_id)

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
	if _sku_already_owned(sku):
		title = "%s [OWNED]" % title
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
	var show_prefs := category_id == "Bundles" and _has_entitlement("zero_ads")
	store_category_prefs_panel.visible = show_prefs
	if show_prefs:
		store_prefs_toggle.button_pressed = _prefer_zero_ads
		store_prefs_toggle.text = "ON" if _prefer_zero_ads else "OFF"

func _on_store_prefs_toggled(enabled: bool) -> void:
	_prefer_zero_ads = enabled
	store_prefs_toggle.text = "ON" if _prefer_zero_ads else "OFF"

func _has_entitlement(flag: String) -> bool:
	if ProfileManager.has_method("has_store_entitlement"):
		return bool(ProfileManager.call("has_store_entitlement", flag))
	return bool(_store_owned_entitlements.get(flag, false))

func _sku_entitlements(sku: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var ent_any: Variant = sku.get("entitlements", [])
	if typeof(ent_any) != TYPE_ARRAY:
		return out
	for ent_v in ent_any as Array:
		var ent: String = str(ent_v).strip_edges()
		if ent == "":
			continue
		out.append(ent)
	return out

func _sku_already_owned(sku: Dictionary) -> bool:
	var entitlements: Array[String] = _sku_entitlements(sku)
	if entitlements.is_empty():
		return false
	for ent in entitlements:
		if not _has_entitlement(ent):
			return false
	return true

func _on_store_sku_pressed(sku: Dictionary) -> void:
	var title: String = str(sku.get("title", "Item"))
	var sku_id: String = str(sku.get("id", "")).strip_edges()
	if sku_id == "":
		status_label.text = "Store item is missing sku id."
		return
	if _sku_already_owned(sku):
		status_label.text = "Already owned: %s" % title
		return
	var entitlements: Array[String] = _sku_entitlements(sku)
	if sku.has("price_honey"):
		var price_honey: int = maxi(0, int(sku.get("price_honey", 0)))
		if price_honey <= 0:
			status_label.text = "Invalid honey price for %s." % title
			return
		var spend_result: Dictionary = _spend_honey(price_honey, "store_sku:%s" % sku_id)
		if not bool(spend_result.get("ok", false)):
			status_label.text = "Not enough Honey for %s (H%d needed, H%d available)." % [
				title,
				price_honey,
				int(spend_result.get("honey_balance", _current_honey_balance()))
			]
			return
		var grant_result: Dictionary = _grant_entitlements(entitlements, "store_sku:%s" % sku_id)
		_update_store_prefs_visibility(str(sku.get("category", "")))
		_populate_store_category(str(sku.get("category", "")))
		_refresh_dash_account_snapshot()
		var granted_count: int = 0
		var granted_any: Variant = grant_result.get("granted", [])
		if typeof(granted_any) == TYPE_ARRAY:
			granted_count = (granted_any as Array).size()
		status_label.text = "Purchased %s for H%d. Entitlements +%d. Balance: H%d" % [
			title,
			price_honey,
			granted_count,
			_current_honey_balance()
		]
		return
	if sku.has("price_real"):
		if not LOCAL_REAL_PURCHASES_ENABLED:
			status_label.text = "IAP not wired yet for %s." % title
			return
		var grant_result_local: Dictionary = _grant_entitlements(entitlements, "sim_real_sku:%s" % sku_id)
		_update_store_prefs_visibility(str(sku.get("category", "")))
		_populate_store_category(str(sku.get("category", "")))
		var granted_local_count: int = 0
		var granted_local_any: Variant = grant_result_local.get("granted", [])
		if typeof(granted_local_any) == TYPE_ARRAY:
			granted_local_count = (granted_local_any as Array).size()
		status_label.text = "Simulated purchase: %s (%s). Entitlements +%d." % [
			title,
			str(sku.get("price_real", "")),
			granted_local_count
		]
		return
	status_label.text = "Store item has no recognized price: %s" % title

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

func _open_buffs_store() -> void:
	_close_top_level_windows()
	_open_buffs_panel()
	status_label.text = "Buff store opened."

func _open_free_roll_split() -> void:
	_close_top_level_windows()
	_open_game_hub(false, 0)

func _open_cash_split() -> void:
	_close_top_level_windows()
	if _dev_bypass_cash_balance:
		_open_game_hub(true, _default_money_denomination())
		return
	if _wallet_balance_usd() <= 0:
		_open_insufficient_balance_modal()
		return
	_open_game_hub(true, _default_money_denomination())

func _on_battle_pass_pressed() -> void:
	_close_top_level_windows()
	_open_battle_pass_panel()
	status_label.text = "Battle Pass opened."

func _on_settings_pressed() -> void:
	_close_top_level_windows()
	_open_settings_panel()
	status_label.text = "Settings opened."

func _on_rank_pressed() -> void:
	_open_rank_panel()
	status_label.text = "Rank leaderboard opened."

func _ensure_swarm_pass_panel() -> void:
	if _swarm_pass_panel != null and is_instance_valid(_swarm_pass_panel):
		return
	var panel_instance_any: Variant = SWARM_PASS_PANEL_SCENE.instantiate()
	if panel_instance_any is Control:
		_swarm_pass_panel = panel_instance_any as Control
		add_child(_swarm_pass_panel)
		_swarm_pass_panel.visible = false
		if _swarm_pass_panel.has_signal("close_requested"):
			_swarm_pass_panel.connect("close_requested", Callable(self, "_close_swarm_pass_panel"))

func _open_swarm_pass_panel() -> void:
	_close_top_level_windows(UI_SURFACE_SWARM_PASS)
	_ensure_swarm_pass_panel()
	if _swarm_pass_panel == null:
		return
	_swarm_pass_panel.visible = true
	_swarm_pass_panel.move_to_front()

func _close_swarm_pass_panel() -> void:
	if _swarm_pass_panel == null:
		return
	_swarm_pass_panel.visible = false

func _ensure_battle_pass_panel() -> void:
	if _battle_pass_panel != null and is_instance_valid(_battle_pass_panel):
		return
	var panel_instance_any: Variant = BATTLE_PASS_PANEL_SCENE.instantiate()
	if panel_instance_any is Control:
		_battle_pass_panel = panel_instance_any as Control
		add_child(_battle_pass_panel)
		_battle_pass_panel.visible = false
		if _battle_pass_panel.has_signal("close_requested"):
			_battle_pass_panel.connect("close_requested", Callable(self, "_close_battle_pass_panel"))

func _open_battle_pass_panel() -> void:
	_close_top_level_windows(UI_SURFACE_BATTLE_PASS)
	_ensure_battle_pass_panel()
	if _battle_pass_panel == null:
		return
	_battle_pass_panel.visible = true
	_battle_pass_panel.move_to_front()

func _close_battle_pass_panel() -> void:
	if _battle_pass_panel == null:
		return
	_battle_pass_panel.visible = false

func _ensure_rank_panel() -> void:
	if _rank_panel != null and is_instance_valid(_rank_panel):
		return
	var panel_instance_any: Variant = RANK_PANEL_SCENE.instantiate()
	if panel_instance_any is Control:
		_rank_panel = panel_instance_any as Control
		add_child(_rank_panel)
		_rank_panel.visible = false
		if _rank_panel.has_signal("close_requested"):
			_rank_panel.connect("close_requested", Callable(self, "_close_rank_panel"))

func _open_rank_panel() -> void:
	_close_top_level_windows(UI_SURFACE_RANK)
	_ensure_rank_panel()
	if _rank_panel == null:
		return
	_rank_panel.visible = true
	_rank_panel.move_to_front()

func _close_rank_panel() -> void:
	if _rank_panel == null:
		return
	_rank_panel.visible = false

func _wallet_balance_usd() -> int:
	return int(_wallet_profile.get("balance_usd", 0))

func _default_money_denomination() -> int:
	var balance := _wallet_balance_usd()
	for denom in MONEY_DENOMINATIONS:
		if denom <= balance:
			return denom
	return MONEY_DENOMINATIONS[0]

func _require_balance_for_entry(entry_usd: int) -> bool:
	if _dev_bypass_cash_balance:
		return true
	if entry_usd <= 0:
		return true
	var balance := _wallet_balance_usd()
	if balance >= entry_usd:
		return true
	_open_insufficient_balance_modal("Insufficient balance: $%d available, $%d required." % [balance, entry_usd])
	return false

func _charge_paid_entry_usd(entry_usd: int, reason: String) -> Dictionary:
	var amount: int = maxi(0, entry_usd)
	if amount <= 0:
		return {"ok": true, "charged_usd": 0, "remaining_usd": _wallet_balance_usd(), "bypassed": false, "reason": reason}
	if not _require_balance_for_entry(amount):
		return {"ok": false, "charged_usd": 0, "remaining_usd": _wallet_balance_usd(), "bypassed": false, "reason": reason}
	if _dev_bypass_cash_balance:
		return {"ok": true, "charged_usd": 0, "remaining_usd": _wallet_balance_usd(), "bypassed": true, "reason": reason}
	var balance: int = _wallet_balance_usd()
	var next_balance: int = maxi(0, balance - amount)
	_wallet_profile["balance_usd"] = next_balance
	return {"ok": true, "charged_usd": amount, "remaining_usd": next_balance, "bypassed": false, "reason": reason}

func _open_insufficient_balance_modal(subtitle: String = "Would you like to:") -> void:
	_close_top_level_windows(UI_SURFACE_ENTRY)
	var panel := _build_entry_overlay("INSUFFICIENT BALANCE", subtitle)
	var body: VBoxContainer = _entry_overlay_body(panel)
	if body == null:
		return
	var add_funds := Button.new()
	add_funds.text = "ADD FUNDS"
	add_funds.pressed.connect(func():
		_close_entry_route_modal()
		status_label.text = "Add funds placeholder."
	)
	body.add_child(add_funds)
	var add_card := Button.new()
	add_card.text = "ADD CREDIT/DEBIT CARD"
	add_card.pressed.connect(func():
		_close_entry_route_modal()
		status_label.text = "Card setup placeholder."
	)
	body.add_child(add_card)
	var free_roll := Button.new()
	free_roll.text = "PLAY A FREE ROLL"
	free_roll.pressed.connect(func():
		_close_entry_route_modal()
		_open_game_hub(false, 0)
	)
	body.add_child(free_roll)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.pressed.connect(_close_entry_route_modal)
	body.add_child(cancel)
	_style_entry_overlay_buttons([add_funds, add_card, free_roll, cancel])
	_apply_free_roll_atlas_font(free_roll, 13)
	_style_game_hub_cancel_button(cancel)
	_entry_route_modal = panel

func _open_game_hub(paid: bool, denomination: int) -> void:
	_close_top_level_windows(UI_SURFACE_ENTRY)
	var selected_denom: int = denomination
	if paid and selected_denom <= 0:
		selected_denom = _default_money_denomination()
	var title := "MONEY GAMES" if paid else "FREE ROLL"
	var subtitle := "Select mode and route."
	if paid:
		subtitle = "Select division."
		_money_games_selected_division = _money_division_for_tier(selected_denom)
		_money_games_selected_tier = _money_clamp_tier_for_division(_money_games_selected_division, selected_denom)
	var overlay_size: Vector2 = _resolve_game_hub_overlay_size(paid)
	var panel := _build_entry_overlay(title, subtitle, overlay_size)
	var viewport_height: float = get_viewport_rect().size.y
	var current_top: float = (viewport_height * 0.5) + panel.offset_top
	var remaining_up_space: float = maxf(0.0, current_top - 8.0)
	var extra_top: float = minf(GAME_HUB_OVERLAY_EXTRA_TOP_PX, remaining_up_space)
	panel.offset_top -= extra_top
	var current_bottom: float = (viewport_height * 0.5) + panel.offset_bottom
	var remaining_down_space: float = maxf(0.0, viewport_height - current_bottom - 8.0)
	var extra_bottom: float = minf(GAME_HUB_OVERLAY_EXTRA_BOTTOM_PX, remaining_down_space)
	panel.offset_bottom += extra_bottom
	var broadcast_free_roll: bool = true
	_apply_game_hub_panel_fx(panel)
	_apply_game_hub_title_treatment(panel, title)
	var body: VBoxContainer = _entry_overlay_body(panel)
	if body == null:
		return
	body.offset_top += extra_top + GAME_HUB_CONTENT_TOP_PADDING_PX
	body.offset_left += GAME_HUB_CONTENT_SHIFT_X
	body.offset_right += GAME_HUB_CONTENT_SHIFT_X
	body.add_theme_constant_override("separation", 8 if paid else 7)
	var cluster_spacing: int = 6 if paid else 5
	if paid:
		_build_money_games_division_layer(body, panel, broadcast_free_roll)
	_add_game_hub_block_label(body, "MATCH TYPE", broadcast_free_roll)
	var match_type_block := VBoxContainer.new()
	match_type_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_type_block.add_theme_constant_override("separation", cluster_spacing)
	body.add_child(match_type_block)
	_add_game_hub_section_header(match_type_block, "HUMAN MATCHES", "Live competitive matches", broadcast_free_roll)
	var human_row := HBoxContainer.new()
	human_row.alignment = BoxContainer.ALIGNMENT_CENTER
	human_row.add_theme_constant_override("separation", cluster_spacing)
	match_type_block.add_child(human_row)
	for mode_id in ["1V1", "2V2", "3P FFA", "4P FFA"]:
		var chosen_mode: String = mode_id
		var button := Button.new()
		button.custom_minimum_size = GAME_HUB_HUMAN_BUTTON_SIZE
		if paid:
			button.pressed.connect(func(): _on_human_mode_selected(chosen_mode, true, _money_games_selected_tier))
		else:
			button.pressed.connect(func(): _on_human_mode_selected(chosen_mode, false, selected_denom))
		human_row.add_child(button)
		_apply_human_mode_skin_to_button(button, chosen_mode, paid, selected_denom)
		_tune_game_hub_human_button(button)
		_configure_game_hub_option_button(button, broadcast_free_roll)
	_add_game_hub_section_header(match_type_block, "TIME PUZZLES", "Race against time & ranking", broadcast_free_roll)
	var cycle_row_wrap := HBoxContainer.new()
	cycle_row_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cycle_row_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	match_type_block.add_child(cycle_row_wrap)
	var cycle_row := GridContainer.new()
	cycle_row.columns = 3
	cycle_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cycle_row.add_theme_constant_override("h_separation", 6)
	cycle_row.add_theme_constant_override("v_separation", 6)
	cycle_row_wrap.add_child(cycle_row)
	var cycle_items := [
		{"label": "WEEKLY", "id": "WEEKLY"},
		{"label": "MONTHLY", "id": "MONTHLY"},
		{"label": "SEASON", "id": "YEARLY"}
	]
	for item_any in cycle_items:
		var item: Dictionary = item_any as Dictionary
		var label := str(item.get("label", "ASYNC"))
		var id := str(item.get("id", ""))
		var async_mode_id: String = id
		var button := Button.new()
		button.custom_minimum_size = GAME_HUB_CYCLE_BUTTON_SIZE
		if paid:
			button.pressed.connect(func(): _on_async_mode_selected(async_mode_id, true, _money_games_selected_tier))
		else:
			button.pressed.connect(func(): _on_async_mode_selected(async_mode_id, false, 0))
		cycle_row.add_child(button)
		_apply_async_cycle_skin_to_button(button, label, paid, selected_denom)
		_tune_game_hub_cycle_button(button)
		_configure_game_hub_option_button(button, broadcast_free_roll)
	_add_game_hub_block_divider(body, broadcast_free_roll)
	_add_game_hub_spacer(body, GAME_HUB_BLOCK_SPACING_PX if paid else GAME_HUB_BLOCK_SPACING_FREE_PX)
	_add_game_hub_block_label(body, "MAP CONFIG", broadcast_free_roll)
	var map_block := VBoxContainer.new()
	map_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_block.add_theme_constant_override("separation", cluster_spacing)
	body.add_child(map_block)
	var three_map_items := [
		{"label": "STAGE RACE", "id": "STAGE_RACE_3"},
		{"label": "RACE", "id": "TIMED_RACE_3"},
		{"label": "MISS N OUT", "id": "MISS_N_OUT_3"}
	]
	_add_game_hub_map_group(map_block, "3 MAP", three_map_items, paid, selected_denom, broadcast_free_roll)
	var five_map_items := [
		{"label": "STAGE RACE", "id": "STAGE_RACE_5"},
		{"label": "RACE", "id": "TIMED_RACE_5"},
		{"label": "MISS N OUT", "id": "MISS_N_OUT_5"}
	]
	_add_game_hub_map_group(map_block, "5 MAP", five_map_items, paid, selected_denom, broadcast_free_roll)
	var cancel_row := HBoxContainer.new()
	cancel_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(cancel_row)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.pressed.connect(_close_entry_route_modal)
	cancel_row.add_child(cancel)
	_style_game_hub_cancel_button(cancel)
	_configure_game_hub_option_button(cancel, broadcast_free_roll)
	_entry_route_modal = panel

func _compact_game_hub_async_mode_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = GAME_HUB_ASYNC_MODE_BUTTON_SIZE
	button.set("icon_max_width", GAME_HUB_ASYNC_MODE_ICON_MAX_WIDTH)

func _tune_game_hub_human_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = GAME_HUB_HUMAN_BUTTON_SIZE
	button.set("icon_max_width", GAME_HUB_HUMAN_ICON_MAX_WIDTH)

func _tune_game_hub_cycle_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = GAME_HUB_CYCLE_BUTTON_SIZE
	button.set("icon_max_width", GAME_HUB_CYCLE_ICON_MAX_WIDTH)

func _add_game_hub_block_label(parent: VBoxContainer, text_value: String, subdued: bool = false) -> void:
	if parent == null:
		return
	var label := Label.new()
	label.text = text_value.strip_edges().to_upper()
	var label_color: Color = GAME_HUB_BLOCK_LABEL_COLOR
	if subdued:
		label_color = Color(label_color.r, label_color.g, label_color.b, 0.46)
	label.add_theme_color_override("font_color", label_color)
	label.add_theme_constant_override("outline_size", 0)
	if subdued:
		label.add_theme_constant_override("font_spacing", 1)
	parent.add_child(label)
	_apply_font(label, _font_regular if subdued else _font_semibold, 11)

func _add_game_hub_section_header(parent: VBoxContainer, heading: String, subtext: String = "", subdued: bool = false) -> void:
	if parent == null:
		return
	var heading_label := Label.new()
	heading_label.text = heading.strip_edges().to_upper()
	var heading_color: Color = GAME_HUB_SECTION_HEADER_COLOR
	if subdued:
		heading_color = Color(heading_color.r, heading_color.g, heading_color.b, 0.49)
	heading_label.add_theme_color_override("font_color", heading_color)
	heading_label.add_theme_constant_override("outline_size", 0)
	if subdued:
		heading_label.add_theme_constant_override("font_spacing", 1)
	parent.add_child(heading_label)
	_apply_font(heading_label, _font_regular if subdued else _font_semibold, 13)
	if subtext.is_empty():
		return
	var subtext_label := Label.new()
	subtext_label.text = subtext
	var subtext_color: Color = GAME_HUB_SECTION_SUBTEXT_COLOR
	if subdued:
		subtext_color = Color(subtext_color.r, subtext_color.g, subtext_color.b, 0.66)
	subtext_label.add_theme_color_override("font_color", subtext_color)
	subtext_label.add_theme_constant_override("outline_size", 0)
	parent.add_child(subtext_label)
	_apply_font(subtext_label, _font_regular, 12 if subdued else 11)

func _add_game_hub_block_divider(parent: VBoxContainer, subdued: bool = false) -> void:
	if parent == null:
		return
	var divider := ColorRect.new()
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	var divider_color: Color = GAME_HUB_DIVIDER_COLOR
	if subdued:
		divider_color = Color(divider_color.r, divider_color.g, divider_color.b, 0.20)
	divider.color = divider_color
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(divider)

func _add_game_hub_spacer(parent: VBoxContainer, height_px: float) -> void:
	if parent == null:
		return
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0.0, maxf(0.0, height_px))
	parent.add_child(spacer)

func _build_money_games_division_layer(body: VBoxContainer, panel: Panel, broadcast_mode: bool = true) -> void:
	if body == null:
		return
	var tabs_row := HBoxContainer.new()
	tabs_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_row.add_theme_constant_override("separation", 10)
	body.add_child(tabs_row)
	_add_game_hub_spacer(body, 4.0)
	var entry_label := Label.new()
	entry_label.text = "ENTRY TIER"
	entry_label.add_theme_color_override("font_color", MONEY_ENTRY_LABEL_COLOR)
	body.add_child(entry_label)
	_apply_font(entry_label, _font_semibold, 13)
	var tier_row := HBoxContainer.new()
	tier_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 10)
	body.add_child(tier_row)
	_add_game_hub_spacer(body, 4.0)
	var division_arena_label := Label.new()
	division_arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	division_arena_label.add_theme_color_override("font_color", GAME_HUB_SECTION_HEADER_COLOR)
	body.add_child(division_arena_label)
	_apply_font(division_arena_label, _font_semibold, 14)
	var entry_fee_label := Label.new()
	entry_fee_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_fee_label.add_theme_color_override("font_color", MONEY_ENTRY_LABEL_COLOR)
	body.add_child(entry_fee_label)
	_apply_font(entry_fee_label, _font_regular, 12)
	_add_game_hub_spacer(body, 8.0)
	var tab_buttons: Dictionary = {}
	for division_id in MONEY_DIVISION_TAB_IDS:
		var bound_division_id: String = division_id
		var tab_button := Button.new()
		tab_button.custom_minimum_size = MONEY_DIVISION_TAB_SIZE
		var label_text: String = str(MONEY_DIVISION_LABELS.get(bound_division_id, "DIVISION"))
		if bound_division_id == MONEY_DIVISION_CLASSIFIED:
			tab_button.text = "%s\n%s" % [label_text, MONEY_TAB_LOCKED_SUBTEXT]
			tab_button.disabled = true
			_apply_font(tab_button, _font_regular, MONEY_DIVISION_LOCKED_LABEL_SIZE)
		else:
			tab_button.text = label_text
			_apply_font(tab_button, _font_semibold, MONEY_DIVISION_LABEL_SIZE)
			tab_button.pressed.connect(func() -> void:
				_on_money_games_division_tab_pressed(bound_division_id, tab_buttons, tier_row, division_arena_label, entry_fee_label, panel, broadcast_mode)
			)
			_configure_game_hub_option_button(tab_button, broadcast_mode)
		tabs_row.add_child(tab_button)
		tab_buttons[bound_division_id] = tab_button
	_refresh_money_games_division_ui(tab_buttons, tier_row, division_arena_label, entry_fee_label, panel, false, broadcast_mode)

func _on_money_games_division_tab_pressed(
		division_id: String,
		tab_buttons: Dictionary,
		tier_row: HBoxContainer,
		division_arena_label: Label,
		entry_fee_label: Label,
		panel: Panel,
		broadcast_mode: bool = true
	) -> void:
	var normalized: String = _money_normalize_division_id(division_id)
	if normalized == MONEY_DIVISION_CLASSIFIED:
		return
	if normalized != _money_games_selected_division:
		_money_games_selected_division = normalized
		var tiers: Array = _money_tiers_for_division(_money_games_selected_division)
		if tiers.is_empty():
			_money_games_selected_tier = 1
		else:
			_money_games_selected_tier = int(tiers[0])
	_refresh_money_games_division_ui(tab_buttons, tier_row, division_arena_label, entry_fee_label, panel, true, broadcast_mode)
	var selected_tab: Button = tab_buttons.get(normalized) as Button
	if not broadcast_mode:
		_play_money_division_activation_sweep(selected_tab)

func _refresh_money_games_division_ui(
		tab_buttons: Dictionary,
		tier_row: HBoxContainer,
		division_arena_label: Label,
		entry_fee_label: Label,
		panel: Panel,
		animate_swap: bool,
		broadcast_mode: bool = true
	) -> void:
	_refresh_money_games_division_tabs(tab_buttons)
	_rebuild_money_games_tier_row(tier_row, division_arena_label, entry_fee_label, animate_swap, broadcast_mode)
	_refresh_money_games_context_labels(division_arena_label, entry_fee_label)

func _refresh_money_games_division_tabs(tab_buttons: Dictionary) -> void:
	for division_id in MONEY_DIVISION_TAB_IDS:
		var button: Button = tab_buttons.get(division_id) as Button
		if button == null:
			continue
		if division_id == MONEY_DIVISION_CLASSIFIED:
			_style_money_division_tab(button, "locked", _money_division_profile(_money_games_selected_division))
			continue
		if division_id == _money_games_selected_division:
			_style_money_division_tab(button, "active", _money_division_profile(division_id))
		else:
			_style_money_division_tab(button, "inactive", _money_division_profile(division_id))

func _style_money_division_tab(button: Button, state: String, profile: Dictionary) -> void:
	if button == null:
		return
	var style := StyleBoxFlat.new()
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	match state:
		"active":
			style.bg_color = Color(0.13, 0.12, 0.10, 0.95)
			style.border_color = profile.get("tab_active_edge", Color(0.95, 0.78, 0.34, 0.65))
			style.border_width_bottom = 2
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
			style.shadow_size = 5
			button.add_theme_color_override("font_color", MONEY_TAB_ACTIVE_TEXT)
		"locked":
			style.bg_color = Color(0.08, 0.09, 0.11, 0.92)
			style.border_color = Color(0.30, 0.32, 0.38, 0.42)
			style.shadow_size = 0
			button.add_theme_color_override("font_color", MONEY_TAB_LOCKED_TEXT)
		_:
			style.bg_color = MONEY_TAB_INACTIVE_BG
			style.border_color = MONEY_TAB_INACTIVE_EDGE
			style.shadow_size = 0
			button.add_theme_color_override("font_color", MONEY_TAB_INACTIVE_TEXT)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	if hover != null:
		if state == "inactive":
			hover.bg_color = hover.bg_color.lightened(0.05)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)

func _rebuild_money_games_tier_row(
		tier_row: HBoxContainer,
		division_arena_label: Label,
		entry_fee_label: Label,
		animate_swap: bool,
		broadcast_mode: bool = true
	) -> void:
	if tier_row == null:
		return
	var rebuild_now := func() -> void:
		for child in tier_row.get_children():
			child.queue_free()
		var tiers: Array = _money_tiers_for_division(_money_games_selected_division)
		for tier_any in tiers:
				var tier: int = int(tier_any)
				var bound_tier: int = tier
				var button := Button.new()
				button.custom_minimum_size = MONEY_ENTRY_TIER_BUTTON_SIZE
				button.text = "$%d" % tier
				button.pressed.connect(func() -> void:
					_on_money_games_tier_pressed(bound_tier, tier_row, division_arena_label, entry_fee_label)
				)
				tier_row.add_child(button)
				_apply_font(button, _font_semibold, 12)
				_style_money_entry_tier_button(button, tier == _money_games_selected_tier)
				_configure_game_hub_option_button(button, broadcast_mode)
	if animate_swap and tier_row.is_inside_tree():
		var tween := tier_row.create_tween()
		tween.tween_property(tier_row, "modulate:a", 0.35, 0.10)
		tween.tween_callback(rebuild_now)
		tween.tween_property(tier_row, "modulate:a", 1.0, 0.10)
	else:
		rebuild_now.call()

func _on_money_games_tier_pressed(
		tier: int,
		tier_row: HBoxContainer,
		division_arena_label: Label,
		entry_fee_label: Label
	) -> void:
	if tier <= 0:
		return
	_money_games_selected_tier = _money_clamp_tier_for_division(_money_games_selected_division, tier)
	for child in tier_row.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var active: bool = button.text.strip_edges() == "$%d" % _money_games_selected_tier
		_style_money_entry_tier_button(button, active)
	_refresh_money_games_context_labels(division_arena_label, entry_fee_label)
	if entry_fee_label != null:
		var tween := entry_fee_label.create_tween()
		tween.tween_property(entry_fee_label, "modulate:a", 0.55, 0.08)
		tween.tween_property(entry_fee_label, "modulate:a", 1.0, 0.12)

func _style_money_entry_tier_button(button: Button, active: bool) -> void:
	if button == null:
		return
	var style := StyleBoxFlat.new()
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	if active:
		style.bg_color = MONEY_ENTRY_ACTIVE_BG
		style.border_color = MONEY_ENTRY_ACTIVE_EDGE
		style.border_width_bottom = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		button.add_theme_color_override("font_color", MONEY_TAB_ACTIVE_TEXT)
	else:
		style.bg_color = MONEY_ENTRY_INACTIVE_BG
		style.border_color = MONEY_ENTRY_INACTIVE_EDGE
		button.modulate = Color(0.85, 0.85, 0.85, 0.92)
		button.add_theme_color_override("font_color", MONEY_TAB_INACTIVE_TEXT)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	if hover != null:
		hover.bg_color = hover.bg_color.lightened(0.06)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)

func _refresh_money_games_context_labels(division_arena_label: Label, entry_fee_label: Label) -> void:
	var arena_label: String = _money_division_arena_label(_money_games_selected_division)
	if division_arena_label != null:
		division_arena_label.text = arena_label
	if entry_fee_label != null:
		entry_fee_label.text = "Entry Fee: $%d" % _money_games_selected_tier

func _money_division_arena_label(division_id: String) -> String:
	match _money_normalize_division_id(division_id):
		MONEY_DIVISION_II:
			return "Division II Arena"
		MONEY_DIVISION_III:
			return "Division III Arena"
		_:
			return "Division I Arena"

func _money_tiers_for_division(division_id: String) -> Array:
	var normalized: String = _money_normalize_division_id(division_id)
	var tiers_any: Variant = MONEY_DIVISION_TIERS.get(normalized, [1, 2, 3])
	if typeof(tiers_any) == TYPE_ARRAY:
		return tiers_any as Array
	return [1, 2, 3]

func _money_division_for_tier(tier: int) -> String:
	for division_id in [MONEY_DIVISION_I, MONEY_DIVISION_II, MONEY_DIVISION_III]:
		var tiers: Array = _money_tiers_for_division(division_id)
		for tier_any in tiers:
			if int(tier_any) == tier:
				return division_id
	return MONEY_DIVISION_I

func _money_clamp_tier_for_division(division_id: String, tier: int) -> int:
	var tiers: Array = _money_tiers_for_division(division_id)
	for tier_any in tiers:
		if int(tier_any) == tier:
			return tier
	if tiers.is_empty():
		return 1
	return int(tiers[0])

func _money_normalize_division_id(division_id: String) -> String:
	var normalized: String = division_id.strip_edges().to_lower()
	if normalized == MONEY_DIVISION_II:
		return MONEY_DIVISION_II
	if normalized == MONEY_DIVISION_III:
		return MONEY_DIVISION_III
	if normalized == MONEY_DIVISION_CLASSIFIED:
		return MONEY_DIVISION_CLASSIFIED
	return MONEY_DIVISION_I

func _money_division_profile(division_id: String) -> Dictionary:
	var normalized: String = _money_normalize_division_id(division_id)
	match normalized:
		MONEY_DIVISION_II:
			return {
				"panel_bg": Color(0.057, 0.066, 0.095, 0.98),
				"panel_border": Color(0.80, 0.63, 0.26, 0.76),
				"edge_color": Color(0.97, 0.75, 0.30, 0.44),
				"edge_alpha_lo": 0.74,
				"edge_alpha_hi": 0.90,
				"edge_width": 2,
				"tab_active_edge": Color(0.96, 0.75, 0.30, 0.76)
			}
		MONEY_DIVISION_III:
			return {
				"panel_bg": Color(0.053, 0.063, 0.092, 0.98),
				"panel_border": Color(0.72, 0.52, 0.20, 0.82),
				"edge_color": Color(0.90, 0.66, 0.26, 0.52),
				"edge_alpha_lo": 0.76,
				"edge_alpha_hi": 0.93,
				"edge_width": 3,
				"tab_active_edge": Color(0.90, 0.66, 0.26, 0.80)
			}
		_:
			return {
				"panel_bg": Color(0.06, 0.07, 0.10, 0.98),
				"panel_border": Color(0.74, 0.60, 0.26, 0.72),
				"edge_color": Color(0.95, 0.80, 0.34, 0.40),
				"edge_alpha_lo": 0.72,
				"edge_alpha_hi": 0.88,
				"edge_width": 2,
				"tab_active_edge": Color(0.95, 0.80, 0.34, 0.74)
			}

func _apply_money_games_panel_theme(panel: Panel, division_id: String) -> void:
	if panel == null:
		return
	var profile: Dictionary = _money_division_profile(division_id)
	var panel_bg: Color = profile.get("panel_bg", Color(0.06, 0.07, 0.10, 0.98))
	var panel_border: Color = profile.get("panel_border", Color(0.74, 0.60, 0.26, 0.72))
	_style_panel(panel, panel_bg, panel_border)
	_apply_money_games_active_edge(panel, profile)

func _apply_money_games_active_edge(panel: Panel, profile: Dictionary) -> void:
	if panel == null:
		return
	var edge: Panel = panel.get_node_or_null("MoneyGamesActiveEdge") as Panel
	if edge == null:
		edge = Panel.new()
		edge.name = "MoneyGamesActiveEdge"
		edge.layout_mode = 1
		edge.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(edge)
		panel.move_child(edge, panel.get_child_count() - 1)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.draw_center = false
	var edge_width: int = int(profile.get("edge_width", 2))
	style.border_width_bottom = edge_width
	style.border_width_left = edge_width
	style.border_width_right = edge_width
	style.border_width_top = edge_width
	style.border_color = profile.get("edge_color", Color(0.95, 0.80, 0.34, 0.34))
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	edge.add_theme_stylebox_override("panel", style)
	var alpha_lo: float = float(profile.get("edge_alpha_lo", 0.70))
	var alpha_hi: float = float(profile.get("edge_alpha_hi", 0.86))
	edge.modulate = Color(1.0, 1.0, 1.0, alpha_lo)
	var pulse := panel.create_tween()
	pulse.tween_property(edge, "modulate:a", alpha_hi, 0.20)
	pulse.tween_property(edge, "modulate:a", alpha_lo, 0.22)

func _play_money_division_activation_sweep(button: Button) -> void:
	if button == null:
		return
	var sweep: ColorRect = button.get_node_or_null("MoneyDivisionSweep") as ColorRect
	if sweep == null:
		sweep = ColorRect.new()
		sweep.name = "MoneyDivisionSweep"
		sweep.layout_mode = 0
		sweep.anchor_top = 0.0
		sweep.anchor_bottom = 1.0
		sweep.offset_top = 0.0
		sweep.offset_bottom = 0.0
		sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(sweep)
	var sweep_width: float = maxf(14.0, button.size.x * 0.14)
	sweep.size = Vector2(sweep_width, maxf(1.0, button.size.y))
	sweep.position = Vector2(-sweep_width - 4.0, 0.0)
	sweep.color = Color(1.0, 0.95, 0.80, 0.14)
	var tween := button.create_tween()
	tween.tween_property(sweep, "position:x", button.size.x + sweep_width + 4.0, 0.20)
	tween.parallel().tween_property(sweep, "color:a", 0.0, 0.20)

func _add_game_hub_map_group(
		parent: VBoxContainer,
		heading: String,
		items: Array,
		paid: bool,
		selected_denom: int,
		broadcast_free_roll: bool = false
	) -> void:
	if parent == null:
		return
	_add_game_hub_section_header(parent, heading, "", broadcast_free_roll)
	var row_wrap := HBoxContainer.new()
	row_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row_wrap)
	var row := GridContainer.new()
	row.columns = 3
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row_wrap.add_child(row)
	for item_any in items:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any as Dictionary
		var label: String = str(item.get("label", "ASYNC"))
		var mode_id: String = str(item.get("id", ""))
		if mode_id.is_empty():
			continue
		var chosen_mode_id: String = mode_id
		var button := Button.new()
		button.custom_minimum_size = GAME_HUB_ASYNC_MODE_BUTTON_SIZE
		if paid:
			button.pressed.connect(func(): _on_async_mode_selected(chosen_mode_id, true, _money_games_selected_tier))
		else:
			button.pressed.connect(func(): _on_async_mode_selected(chosen_mode_id, false, 0))
		row.add_child(button)
		_apply_async_mode_skin_to_button(button, label, paid, _money_games_selected_tier if paid else selected_denom)
		_compact_game_hub_async_mode_button(button)
		_configure_game_hub_option_button(button, broadcast_free_roll)

func _style_game_hub_cancel_button(button: Button) -> void:
	if button == null:
		return
	button.set_meta("sf_cancel_skin", true)
	button.set_meta("sf_close_skin", false)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = GAME_HUB_CANCEL_BUTTON_SIZE
	button.set_meta("sf_cancel_skin_min_w", GAME_HUB_CANCEL_BUTTON_SIZE.x)
	button.set_meta("sf_cancel_skin_min_h", GAME_HUB_CANCEL_BUTTON_SIZE.y)
	_apply_font(button, _font_regular, 12)
	_style_button(button, Color(0.15, 0.16, 0.19, 0.72), Color(0.28, 0.30, 0.34, 0.26), Color(0.74, 0.77, 0.82))
	button.custom_minimum_size = GAME_HUB_CANCEL_BUTTON_SIZE
	button.set("icon_max_width", GAME_HUB_ASYNC_MODE_ICON_MAX_WIDTH)

func _configure_game_hub_option_button(button: Button, broadcast_mode: bool = false) -> void:
	if button == null:
		return
	if button.has_meta("sf_game_hub_motion"):
		return
	button.set_meta("sf_game_hub_motion", true)
	button.set_meta("sf_game_hub_base_modulate", button.modulate)
	button.set_meta("sf_game_hub_hovered", false)
	button.set_meta("sf_game_hub_pressed", false)
	button.clip_contents = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var shell_tone := ColorRect.new()
	shell_tone.name = "GameHubShellTone"
	shell_tone.layout_mode = 1
	shell_tone.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	shell_tone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_tone.color = Color(0.0, 0.0, 0.0, 0.0)
	button.add_child(shell_tone)
	var inner_glow: CanvasItem = null
	if broadcast_mode:
		var radial_glow := TextureRect.new()
		radial_glow.name = "GameHubInnerGlow"
		radial_glow.layout_mode = 0
		radial_glow.anchor_left = 0.24
		radial_glow.anchor_right = 0.76
		radial_glow.anchor_top = 0.25
		radial_glow.anchor_bottom = 0.75
		radial_glow.offset_left = 0.0
		radial_glow.offset_right = 0.0
		radial_glow.offset_top = 0.0
		radial_glow.offset_bottom = 0.0
		radial_glow.stretch_mode = TextureRect.STRETCH_SCALE
		radial_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		radial_glow.texture = _build_game_hub_radial_texture(
			PackedColorArray([
				Color(1.0, 1.0, 1.0, 0.70),
				Color(1.0, 1.0, 1.0, 0.0)
			]),
			PackedFloat32Array([0.0, 1.0])
		)
		radial_glow.modulate = Color(1.0, 0.84, 0.44, 0.0)
		button.add_child(radial_glow)
		inner_glow = radial_glow
	else:
		var flat_glow := ColorRect.new()
		flat_glow.name = "GameHubInnerGlow"
		flat_glow.layout_mode = 1
		flat_glow.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		flat_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flat_glow.color = Color(0.95, 0.74, 0.28, 0.0)
		button.add_child(flat_glow)
		inner_glow = flat_glow
	var edge := Panel.new()
	edge.name = "GameHubHoverEdge"
	edge.layout_mode = 1
	edge.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var edge_style := StyleBoxFlat.new()
	edge_style.bg_color = Color(0, 0, 0, 0)
	edge_style.draw_center = false
	edge_style.border_width_bottom = 0 if broadcast_mode else 1
	edge_style.border_width_left = 0 if broadcast_mode else 1
	edge_style.border_width_right = 0 if broadcast_mode else 1
	edge_style.border_width_top = 0 if broadcast_mode else 1
	edge_style.border_color = Color(0.95, 0.80, 0.34, 0.0) if broadcast_mode else GAME_HUB_HOVER_EDGE_COLOR
	edge_style.corner_radius_bottom_left = 6
	edge_style.corner_radius_bottom_right = 6
	edge_style.corner_radius_top_left = 6
	edge_style.corner_radius_top_right = 6
	edge.add_theme_stylebox_override("panel", edge_style)
	button.add_child(edge)
	var sweep: ColorRect = null
	if not broadcast_mode:
		sweep = ColorRect.new()
		sweep.name = "GameHubSweep"
		sweep.layout_mode = 0
		sweep.anchor_top = 0.0
		sweep.anchor_bottom = 1.0
		sweep.offset_top = 0.0
		sweep.offset_bottom = 0.0
		sweep.custom_minimum_size = Vector2(24.0, 0.0)
		sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sweep.color = Color(1.0, 0.97, 0.83, 0.0)
		sweep.position = Vector2(-30.0, 0.0)
		button.add_child(sweep)
	button.mouse_entered.connect(func() -> void:
		_set_game_hub_option_hover_state(button, edge, sweep, shell_tone, inner_glow, true, broadcast_mode)
	)
	button.mouse_exited.connect(func() -> void:
		_set_game_hub_option_hover_state(button, edge, sweep, shell_tone, inner_glow, false, broadcast_mode)
	)
	button.button_down.connect(func() -> void:
		_set_game_hub_option_pressed_state(button, edge, shell_tone, inner_glow, true, broadcast_mode)
	)
	button.button_up.connect(func() -> void:
		_set_game_hub_option_pressed_state(button, edge, shell_tone, inner_glow, false, broadcast_mode)
	)

func _set_game_hub_option_hover_state(
		button: Button,
		edge: Panel,
		sweep: ColorRect,
		shell_tone: CanvasItem,
		inner_glow: CanvasItem,
		hovered: bool,
		broadcast_mode: bool
	) -> void:
	if button == null or edge == null or shell_tone == null or inner_glow == null:
		return
	if not is_instance_valid(button) or not is_instance_valid(edge) or not is_instance_valid(shell_tone) or not is_instance_valid(inner_glow):
		return
	if button.disabled:
		return
	button.set_meta("sf_game_hub_hovered", hovered)
	var base_any: Variant = button.get_meta("sf_game_hub_base_modulate", Color(1, 1, 1, 1))
	var base_modulate: Color = base_any if typeof(base_any) == TYPE_COLOR else Color(1, 1, 1, 1)
	var tween: Tween = null
	if button.is_inside_tree():
		tween = button.create_tween()
	if broadcast_mode:
		var target_scale := Vector2(1.024, 1.024) if hovered else Vector2.ONE
		var target_shell_alpha: float = 0.0
		var target_glow_alpha: float = 0.10 if hovered else 0.0
		var target_edge_alpha: float = 0.0
		if tween == null:
			button.scale = target_scale
			button.modulate = base_modulate
			shell_tone.modulate.a = target_shell_alpha
			inner_glow.modulate.a = target_glow_alpha
			edge.modulate.a = target_edge_alpha
			return
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", target_scale, 0.14)
		tween.parallel().tween_property(button, "modulate", base_modulate, 0.14)
		tween.parallel().tween_property(shell_tone, "modulate:a", target_shell_alpha, 0.14)
		tween.parallel().tween_property(inner_glow, "modulate:a", target_glow_alpha, 0.14)
		tween.parallel().tween_property(edge, "modulate:a", target_edge_alpha, 0.14)
		return
	if tween == null:
		button.modulate = Color(GAME_HUB_HOVER_BRIGHTNESS, GAME_HUB_HOVER_BRIGHTNESS, GAME_HUB_HOVER_BRIGHTNESS, 1.0) if hovered else base_modulate
		edge.modulate.a = 1.0 if hovered else 0.0
		return
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	if hovered:
		tween.tween_property(button, "modulate", Color(GAME_HUB_HOVER_BRIGHTNESS, GAME_HUB_HOVER_BRIGHTNESS, GAME_HUB_HOVER_BRIGHTNESS, 1.0), 0.12)
		tween.parallel().tween_property(edge, "modulate:a", 1.0, 0.12)
		_play_game_hub_option_sweep(button, sweep)
	else:
		tween.tween_property(button, "modulate", base_modulate, 0.18)
		tween.parallel().tween_property(edge, "modulate:a", 0.0, 0.18)

func _set_game_hub_option_pressed_state(
		button: Button,
		edge: Panel,
		shell_tone: CanvasItem,
		inner_glow: CanvasItem,
		pressed: bool,
		broadcast_mode: bool
	) -> void:
	if button == null:
		return
	if not is_instance_valid(button):
		return
	if button.disabled:
		return
	button.set_meta("sf_game_hub_pressed", pressed)
	if not broadcast_mode:
		button.scale = Vector2(0.986, 0.986) if pressed else Vector2.ONE
		return
	if edge == null or shell_tone == null or inner_glow == null:
		return
	if not is_instance_valid(edge) or not is_instance_valid(shell_tone) or not is_instance_valid(inner_glow):
		return
	var hovered_any: Variant = button.get_meta("sf_game_hub_hovered", false)
	var hovered: bool = bool(hovered_any)
	var target_scale: Vector2 = Vector2.ONE
	var target_shell_alpha: float = 0.0
	var target_glow_alpha: float = 0.0
	var target_edge_alpha: float = 0.0
	if pressed:
		target_scale = Vector2(1.012, 1.012)
		target_shell_alpha = 0.0
		target_glow_alpha = 0.13
		target_edge_alpha = 0.0
	elif hovered:
		target_scale = Vector2(1.024, 1.024)
		target_shell_alpha = 0.0
		target_glow_alpha = 0.10
		target_edge_alpha = 0.0
	var tween: Tween = null
	if button.is_inside_tree():
		tween = button.create_tween()
	if tween == null:
		button.scale = target_scale
		shell_tone.modulate.a = target_shell_alpha
		inner_glow.modulate.a = target_glow_alpha
		edge.modulate.a = target_edge_alpha
		return
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.14)
	tween.parallel().tween_property(shell_tone, "modulate:a", target_shell_alpha, 0.14)
	tween.parallel().tween_property(inner_glow, "modulate:a", target_glow_alpha, 0.14)
	tween.parallel().tween_property(edge, "modulate:a", target_edge_alpha, 0.14)

func _play_game_hub_option_sweep(button: Button, sweep: ColorRect) -> void:
	if button == null or sweep == null:
		return
	if not is_instance_valid(button) or not is_instance_valid(sweep):
		return
	var sweep_width: float = maxf(18.0, button.size.x * 0.18)
	sweep.size = Vector2(sweep_width, maxf(1.0, button.size.y))
	sweep.position = Vector2(-sweep_width - 6.0, 0.0)
	sweep.color = Color(1.0, 0.97, 0.83, 0.10)
	var tween: Tween = null
	if button.is_inside_tree():
		tween = button.create_tween()
	if tween == null:
		sweep.position.x = button.size.x + sweep_width + 6.0
		sweep.color.a = 0.0
		return
	tween.tween_property(sweep, "position:x", button.size.x + sweep_width + 6.0, GAME_HUB_SWEEP_DURATION_SEC)
	tween.parallel().tween_property(sweep, "color:a", 0.0, GAME_HUB_SWEEP_DURATION_SEC)

func _apply_game_hub_panel_fx(panel: Panel) -> void:
	if panel == null:
		return
	var matte_overlay := ColorRect.new()
	matte_overlay.name = "GameHubMatteOverlay"
	matte_overlay.layout_mode = 1
	matte_overlay.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	matte_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	matte_overlay.color = Color(0.0, 0.0, 0.0, 0.03)
	panel.add_child(matte_overlay)
	panel.move_child(matte_overlay, 1)
	var center_tension := TextureRect.new()
	center_tension.name = "GameHubCenterTension"
	center_tension.layout_mode = 1
	center_tension.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	center_tension.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_tension.stretch_mode = TextureRect.STRETCH_SCALE
	center_tension.texture = _build_game_hub_radial_texture(
		PackedColorArray([
			Color(1.0, 1.0, 1.0, 1.0),
			Color(1.0, 1.0, 1.0, 0.0)
		]),
		PackedFloat32Array([0.0, 1.0])
	)
	center_tension.modulate = Color(0.96, 0.98, 1.0, 0.028)
	panel.add_child(center_tension)
	panel.move_child(center_tension, 2)
	var directional_shade := TextureRect.new()
	directional_shade.name = "GameHubDirectionalShade"
	directional_shade.layout_mode = 1
	directional_shade.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	directional_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	directional_shade.stretch_mode = TextureRect.STRETCH_SCALE
	directional_shade.texture = _build_game_hub_gradient_texture(
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.00),
			Color(0.0, 0.0, 0.0, 0.07)
		]),
		PackedFloat32Array([0.0, 1.0]),
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0)
	)
	panel.add_child(directional_shade)
	panel.move_child(directional_shade, 3)

func _build_game_hub_gradient_texture(
		colors: PackedColorArray,
		offsets: PackedFloat32Array,
		fill_from: Vector2,
		fill_to: Vector2
	) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = colors
	gradient.offsets = offsets
	var texture := GradientTexture2D.new()
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = fill_from
	texture.fill_to = fill_to
	texture.width = 32
	texture.height = 32
	texture.gradient = gradient
	return texture

func _build_game_hub_radial_texture(colors: PackedColorArray, offsets: PackedFloat32Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = colors
	gradient.offsets = offsets
	var texture := GradientTexture2D.new()
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 48
	texture.height = 48
	texture.gradient = gradient
	return texture

func _apply_game_hub_title_treatment(panel: Panel, title: String) -> void:
	if panel == null:
		return
	if title.strip_edges().to_upper() != "FREE ROLL":
		return
	var title_label: Label = panel.get_node_or_null("EntryScroll/EntryBody/EntryTitle") as Label
	if title_label == null:
		return
	if not _apply_free_roll_atlas_font(title_label, 22):
		_apply_font(title_label, _font_semibold, 20)
	title_label.add_theme_color_override("font_color", Color(0.995, 0.997, 1.0, 1.0))
	title_label.add_theme_constant_override("outline_size", 1)
	title_label.add_theme_color_override("font_outline_color", Color(GAME_HUB_TITLE_OUTLINE_COLOR.r, GAME_HUB_TITLE_OUTLINE_COLOR.g, GAME_HUB_TITLE_OUTLINE_COLOR.b, 0.08))
	title_label.add_theme_constant_override("font_spacing", 1)
	_apply_free_roll_title_micro_gradient(title_label)
	var subtitle_label: Label = panel.get_node_or_null("EntryScroll/EntryBody/EntrySubtitle") as Label
	if subtitle_label != null:
		_apply_font(subtitle_label, _font_regular, 13)
		subtitle_label.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94, 0.88))
	var body: VBoxContainer = panel.get_node_or_null("EntryScroll/EntryBody") as VBoxContainer
	if body != null:
		body.add_theme_constant_override("separation", 8)

func _apply_free_roll_title_micro_gradient(title_label: Label) -> void:
	if title_label == null:
		return
	title_label.clip_contents = true
	var gradient_overlay: TextureRect = title_label.get_node_or_null("FreeRollTitleMicroGradient") as TextureRect
	if gradient_overlay == null:
		gradient_overlay = TextureRect.new()
		gradient_overlay.name = "FreeRollTitleMicroGradient"
		gradient_overlay.layout_mode = 1
		gradient_overlay.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		gradient_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gradient_overlay.stretch_mode = TextureRect.STRETCH_SCALE
		title_label.add_child(gradient_overlay)
	gradient_overlay.texture = _build_game_hub_gradient_texture(
		PackedColorArray([
			Color(1.0, 1.0, 1.0, 0.05),
			Color(1.0, 1.0, 1.0, 0.00)
		]),
		PackedFloat32Array([0.0, 1.0]),
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0)
	)

func _apply_money_games_title_treatment(panel: Panel) -> void:
	if panel == null:
		return
	var title_label: Label = panel.get_node_or_null("EntryScroll/EntryBody/EntryTitle") as Label
	if title_label != null:
		_apply_font(title_label, _font_semibold, 21)
		title_label.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98, 1.0))
		title_label.add_theme_constant_override("outline_size", 2)
		title_label.add_theme_color_override("font_outline_color", Color(1.0, 0.86, 0.52, 0.16))
	var subtitle_label: Label = panel.get_node_or_null("EntryScroll/EntryBody/EntrySubtitle") as Label
	if subtitle_label != null:
		_apply_font(subtitle_label, _font_regular, 14)
		subtitle_label.add_theme_color_override("font_color", Color(0.84, 0.87, 0.92, 0.86))

func _resolve_game_hub_overlay_size(paid: bool) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_height: float = GAME_HUB_OVERLAY_PAID_TARGET_HEIGHT if paid else GAME_HUB_OVERLAY_FREE_TARGET_HEIGHT
	var min_height: float = GAME_HUB_OVERLAY_PAID_MIN_HEIGHT if paid else GAME_HUB_OVERLAY_FREE_MIN_HEIGHT
	var max_width: float = maxf(360.0, viewport_size.x - (GAME_HUB_OVERLAY_VIEWPORT_MARGIN_X * 2.0))
	var max_height: float = maxf(min_height, viewport_size.y - (GAME_HUB_OVERLAY_VIEWPORT_MARGIN_Y * 2.0))
	return Vector2(
		minf(GAME_HUB_OVERLAY_TARGET_WIDTH, max_width),
		clampf(target_height, min_height, max_height)
	)

func _on_human_mode_selected(mode_id: String, paid: bool, denomination: int) -> void:
	if paid and not _require_balance_for_entry(maxi(1, denomination)):
		return
	_close_entry_route_modal()
	get_tree().set_meta("requested_human_mode", mode_id)
	if mode_id == "1V1":
		if paid:
			_open_vs_mode_select_panel(false)
			status_label.text = "Human 1v1 selected at $%d." % denomination
		else:
			if _open_shell_map_picker_from_free_roll():
				status_label.text = "Human 1v1 free roll selected. Map picker opened."
			else:
				_open_vs_mode_select_panel(true)
				status_label.text = "Human 1v1 free roll selected."
		return
	var lane := "paid" if paid else "free"
	status_label.text = "Human %s (%s) selected. Queue wiring is next." % [mode_id, lane]

func _open_shell_map_picker_from_free_roll() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	tree.set_meta("open_map_picker_on_ready", true)
	var err: Error = tree.change_scene_to_file(SHELL_SCENE_PATH)
	if err == OK:
		return true
	if tree.has_meta("open_map_picker_on_ready"):
		tree.remove_meta("open_map_picker_on_ready")
	SFLog.warn("FREE_ROLL_MAP_PICKER_ROUTE_FAILED", {"error_code": int(err)})
	return false

func _on_async_mode_selected(mode_id: String, paid: bool, denomination: int) -> void:
	if paid and not _require_balance_for_entry(maxi(1, denomination)):
		return
	_close_entry_route_modal()
	_apply_async_entry_amount(paid, denomination)
	match mode_id:
		"WEEKLY":
			_open_async_panel()
			if paid:
				_open_async_paid_menu()
			else:
				_open_async_free_menu()
			_open_async_weekly()
		"MONTHLY":
			_open_async_panel()
			if paid:
				_open_async_paid_menu()
			else:
				_open_async_free_menu()
			_open_async_monthly()
		"YEARLY":
			_open_async_panel()
			if paid:
				_open_async_paid_menu()
			else:
				_open_async_free_menu()
			_open_async_yearly()
		"STAGE_RACE":
			_on_async_stage_race_selected(3, not paid)
		"STAGE_RACE_3":
			_on_async_stage_race_selected(3, not paid)
		"STAGE_RACE_5":
			_on_async_stage_race_selected(5, not paid)
		"TIMED_RACE":
			_on_async_timed_race_selected(3, not paid)
		"TIMED_RACE_3":
			_on_async_timed_race_selected(3, not paid)
		"TIMED_RACE_5":
			_on_async_timed_race_selected(5, not paid)
		"MISS_N_OUT":
			_on_async_miss_n_out_selected(not paid)
		"MISS_N_OUT_3":
			_on_async_miss_n_out_selected(not paid, 3)
		"MISS_N_OUT_5":
			_on_async_miss_n_out_selected(not paid, 5)
		_:
			status_label.text = "Async mode unavailable."

func _apply_async_entry_amount(paid: bool, denomination: int) -> void:
	if not paid:
		_async_paid_entry_usd = 0
		return
	var amount := maxi(1, denomination)
	_async_paid_entry_usd = amount
	for key in ["weekly", "monthly", "yearly"]:
		_async_buyins[key] = amount

func _open_human_entry_selector(free_roll: bool) -> void:
	_open_vs_mode_select_panel(free_roll)
	if free_roll:
		status_label.text = "Human free-play selector opened."
	else:
		status_label.text = "Human paid-match selector opened."

func _open_async_entry_selector(free_roll: bool) -> void:
	_close_entry_route_modal()
	_open_async_panel()
	if free_roll:
		_open_async_free_menu()
		status_label.text = "Async free-play selector opened."
	else:
		_open_async_paid_menu()
		status_label.text = "Async paid-contest selector opened."

func _open_vs_mode_select_panel(free_roll: bool) -> void:
	_close_top_level_windows(UI_SURFACE_PLAY_MODE)
	var panel := preload("res://scenes/ui/VsModeSelect.tscn").instantiate()
	if panel.has_method("configure_entry"):
		panel.call("configure_entry", free_roll)
	panel.closed.connect(func(): panel.queue_free())
	add_child(panel)

func _build_entry_overlay(title: String, subtitle: String, size: Vector2 = Vector2(480, 220)) -> Panel:
	_close_entry_route_modal()
	var viewport_size: Vector2 = get_viewport_rect().size
	var max_size := Vector2(
		maxf(320.0, viewport_size.x - 64.0),
		maxf(240.0, viewport_size.y - 64.0)
	)
	var resolved_size := Vector2(
		minf(size.x, max_size.x),
		minf(size.y, max_size.y)
	)
	var panel := Panel.new()
	panel.name = "EntryRouteModal"
	panel.layout_mode = 0
	panel.clip_contents = true
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -resolved_size.x * 0.5
	panel.offset_top = -resolved_size.y * 0.5
	panel.offset_right = resolved_size.x * 0.5
	panel.offset_bottom = resolved_size.y * 0.5
	panel.z_index = 200
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_build_entry_overlay_background_layers(panel, resolved_size)
	var scroll := ScrollContainer.new()
	scroll.name = "EntryScroll"
	scroll.layout_mode = 1
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	scroll.offset_left = 0.0
	scroll.offset_top = 0.0
	scroll.offset_right = 0.0
	scroll.offset_bottom = 0.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.name = "EntryBody"
	vbox.layout_mode = 0
	vbox.anchor_right = 1.0
	vbox.offset_left = 16.0
	vbox.offset_top = 16.0
	vbox.offset_right = -16.0
	vbox.custom_minimum_size = Vector2(maxf(resolved_size.x - 32.0, 280.0), 0.0)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	var title_label := Label.new()
	title_label.name = "EntryTitle"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	var subtitle_label := Label.new()
	subtitle_label.name = "EntrySubtitle"
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle_label)
	add_child(panel)
	_style_panel(panel, Color(0.06, 0.07, 0.1, 0.98), Color(0.45, 0.48, 0.58, 0.8))
	_apply_font(title_label, _font_semibold, 18)
	_apply_font(subtitle_label, _font_regular, 13)
	return panel

func _build_entry_overlay_background_layers(panel: Panel, resolved_size: Vector2, use_default_inlay_shift: bool = true) -> void:
	if panel == null:
		return
	var background_base := TextureRect.new()
	background_base.name = "Background_Base"
	background_base.layout_mode = 1
	background_base.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	background_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_base.stretch_mode = TextureRect.STRETCH_SCALE
	background_base.texture = _build_game_hub_gradient_texture(
		PackedColorArray([
			Color(0.03, 0.035, 0.05, 1.0),
			Color(0.05, 0.04, 0.03, 1.0)
		]),
		PackedFloat32Array([0.0, 1.0]),
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0)
	)
	panel.add_child(background_base)
	panel.move_child(background_base, 0)

	var background_noise := TextureRect.new()
	background_noise.name = "Background_Noise"
	background_noise.layout_mode = 1
	background_noise.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	background_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_noise.stretch_mode = TextureRect.STRETCH_TILE
	background_noise.texture = _get_entry_overlay_noise_texture()
	background_noise.modulate = Color(1.0, 1.0, 1.0, ENTRY_OVERLAY_NOISE_ALPHA)
	panel.add_child(background_noise)
	panel.move_child(background_noise, 1)

	var frame_inlay := NinePatchRect.new()
	frame_inlay.name = "Frame_Inlay"
	frame_inlay.layout_mode = 1
	frame_inlay.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	frame_inlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_inlay.draw_center = true
	frame_inlay.texture = _get_entry_overlay_inlay_texture_for_size(resolved_size)
	var overscan_x: float = resolved_size.x * ENTRY_OVERLAY_INLAY_OVERSCAN_X_RATIO
	var overscan_y: float = resolved_size.y * ENTRY_OVERLAY_INLAY_OVERSCAN_Y_RATIO
	var shift_x: float = 0.0
	var shift_y: float = 0.0
	if use_default_inlay_shift:
		shift_x = (resolved_size.x * ENTRY_OVERLAY_INLAY_SHIFT_X_RATIO) + ENTRY_OVERLAY_INLAY_SHIFT_X_PX
		shift_y = (resolved_size.y * ENTRY_OVERLAY_INLAY_SHIFT_Y_RATIO) + ENTRY_OVERLAY_INLAY_SHIFT_Y_PX
	frame_inlay.offset_left = -overscan_x + shift_x
	frame_inlay.offset_top = -overscan_y + shift_y
	frame_inlay.offset_right = overscan_x + shift_x
	frame_inlay.offset_bottom = overscan_y + shift_y
	_apply_entry_overlay_inlay_patch_margins(frame_inlay)
	panel.add_child(frame_inlay)
	panel.move_child(frame_inlay, 2)

	var popup_bg_node: Node = HEX_SEAM_BACKGROUND_SCENE.instantiate()
	var popup_bg: Control = popup_bg_node as Control
	if popup_bg == null:
		return
	popup_bg.name = "Midfield_Hex_Dark"
	popup_bg.layout_mode = 1
	popup_bg.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	popup_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(popup_bg)
	panel.move_child(popup_bg, 3)
	if popup_bg.has_method("apply_preset"):
		popup_bg.call("apply_preset", StringName("popup"))
	if popup_bg is ColorRect:
		var color_rect: ColorRect = popup_bg as ColorRect
		color_rect.color = Color(1.0, 1.0, 1.0, ENTRY_OVERLAY_MIDFIELD_ALPHA)

func _get_entry_overlay_inlay_texture_for_size(target_size: Vector2) -> Texture2D:
	if MATCH_BACKGROUND_INLAY_TEXTURE == null:
		return null
	var source_size: Vector2 = MATCH_BACKGROUND_INLAY_TEXTURE.get_size()
	if source_size.x <= 1.0 or source_size.y <= 1.0:
		return MATCH_BACKGROUND_INLAY_TEXTURE
	# Broadcast inlay is authored in landscape; force rotated source for portrait-first game UI.
	var rotated: Texture2D = _get_entry_overlay_rotated_inlay_texture()
	if rotated == null:
		return _get_entry_overlay_cropped_inlay_texture(MATCH_BACKGROUND_INLAY_TEXTURE, false)
	return _get_entry_overlay_cropped_inlay_texture(rotated, true)

func _get_entry_overlay_rotated_inlay_texture() -> Texture2D:
	if _entry_overlay_inlay_rotated_texture != null:
		return _entry_overlay_inlay_rotated_texture
	if MATCH_BACKGROUND_INLAY_TEXTURE == null:
		return null
	var base_image: Image = MATCH_BACKGROUND_INLAY_TEXTURE.get_image()
	if base_image == null:
		return null
	var rotated_image: Image = _rotate_image_clockwise(base_image)
	if rotated_image == null:
		return null
	_entry_overlay_inlay_rotated_texture = ImageTexture.create_from_image(rotated_image)
	return _entry_overlay_inlay_rotated_texture

func _get_entry_overlay_cropped_inlay_texture(source_texture: Texture2D, rotated: bool) -> Texture2D:
	if source_texture == null:
		return null
	if rotated:
		if _entry_overlay_inlay_rotated_cropped_texture != null:
			return _entry_overlay_inlay_rotated_cropped_texture
	else:
		if _entry_overlay_inlay_cropped_texture != null:
			return _entry_overlay_inlay_cropped_texture
	var image: Image = source_texture.get_image()
	if image == null:
		return source_texture
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 2 or height <= 2:
		return source_texture
	var portrait: bool = height > width
	var crop_x_ratio: float = ENTRY_OVERLAY_INLAY_CROP_X_PORTRAIT_RATIO if portrait else ENTRY_OVERLAY_INLAY_CROP_X_LANDSCAPE_RATIO
	var crop_y_ratio: float = ENTRY_OVERLAY_INLAY_CROP_Y_PORTRAIT_RATIO if portrait else ENTRY_OVERLAY_INLAY_CROP_Y_LANDSCAPE_RATIO
	var crop_x: int = int(clampi(int(round(float(width) * crop_x_ratio)), 0, maxi(0, (width / 2) - 1)))
	var crop_y: int = int(clampi(int(round(float(height) * crop_y_ratio)), 0, maxi(0, (height / 2) - 1)))
	var region_w: int = width - (crop_x * 2)
	var region_h: int = height - (crop_y * 2)
	if region_w <= 1 or region_h <= 1:
		return source_texture
	var bounds := Rect2i(crop_x, crop_y, region_w, region_h)
	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = Rect2(bounds.position, bounds.size)
	if rotated:
		_entry_overlay_inlay_rotated_cropped_texture = atlas
		return _entry_overlay_inlay_rotated_cropped_texture
	_entry_overlay_inlay_cropped_texture = atlas
	return _entry_overlay_inlay_cropped_texture

func _rotate_image_clockwise(source: Image) -> Image:
	if source == null:
		return null
	var src_w: int = source.get_width()
	var src_h: int = source.get_height()
	if src_w <= 0 or src_h <= 0:
		return null
	var out := Image.create(src_h, src_w, false, source.get_format())
	for y in src_h:
		for x in src_w:
			out.set_pixel(src_h - y - 1, x, source.get_pixel(x, y))
	return out

func _apply_entry_overlay_inlay_patch_margins(frame_inlay: NinePatchRect) -> void:
	if frame_inlay == null:
		return
	var texture: Texture2D = frame_inlay.texture
	if texture == null:
		return
	var texture_size: Vector2 = texture.get_size()
	var portrait: bool = texture_size.y > texture_size.x
	var margin_x_ratio: float = ENTRY_OVERLAY_INLAY_MARGIN_X_PORTRAIT_RATIO if portrait else ENTRY_OVERLAY_INLAY_MARGIN_X_LANDSCAPE_RATIO
	var margin_y_ratio: float = ENTRY_OVERLAY_INLAY_MARGIN_Y_PORTRAIT_RATIO if portrait else ENTRY_OVERLAY_INLAY_MARGIN_Y_LANDSCAPE_RATIO
	var margin_x: int = int(clampi(int(round(texture_size.x * margin_x_ratio)), 48, int(texture_size.x * 0.30)))
	var margin_y: int = int(clampi(int(round(texture_size.y * margin_y_ratio)), 48, int(texture_size.y * 0.30)))
	frame_inlay.patch_margin_left = margin_x
	frame_inlay.patch_margin_right = margin_x
	frame_inlay.patch_margin_top = margin_y
	frame_inlay.patch_margin_bottom = margin_y
	frame_inlay.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	frame_inlay.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH

func _get_entry_overlay_noise_texture() -> Texture2D:
	if _entry_overlay_noise_texture != null:
		return _entry_overlay_noise_texture
	var fast_noise := FastNoiseLite.new()
	fast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fast_noise.frequency = 0.07
	fast_noise.seed = 419
	var noise_texture := NoiseTexture2D.new()
	noise_texture.width = 256
	noise_texture.height = 256
	noise_texture.seamless = true
	noise_texture.noise = fast_noise
	_entry_overlay_noise_texture = noise_texture
	return _entry_overlay_noise_texture

func _entry_overlay_body(panel: Panel) -> VBoxContainer:
	if panel == null:
		return null
	var direct: VBoxContainer = panel.get_node_or_null("EntryBody") as VBoxContainer
	if direct != null:
		return direct
	return panel.get_node_or_null("EntryScroll/EntryBody") as VBoxContainer

func _style_entry_overlay_buttons(buttons: Array) -> void:
	for button_any in buttons:
		var button: Button = button_any as Button
		if button == null:
			continue
		button.set_meta("sf_cancel_skin", false)
		button.set_meta("sf_close_skin", false)
		_apply_font(button, _font_regular, 13)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))

func _ensure_async_stage_contest_section() -> void:
	if async_vbox == null:
		return
	if _async_stage_section != null and is_instance_valid(_async_stage_section):
		return
	var panel: Panel = Panel.new()
	panel.name = "StageContestSection"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0.0, 164.0)
	_style_panel(panel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	vbox.offset_left = 12.0
	vbox.offset_top = 12.0
	vbox.offset_right = -12.0
	vbox.offset_bottom = -12.0
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "STAGE CONTEST LEADERBOARDS"
	vbox.add_child(title)
	_apply_font(title, _font_semibold, 14)

	var sub: Label = Label.new()
	sub.text = "Free-play first: tap 3-map or 5-map to view top 10."
	vbox.add_child(sub)
	_apply_font(sub, _font_regular, 12)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_theme_constant_override("separation", 10)
	vbox.add_child(button_row)

	var three_map_button: Button = Button.new()
	three_map_button.text = "3 MAP STAGE LEADERS"
	three_map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	three_map_button.custom_minimum_size = Vector2(0.0, 40.0)
	three_map_button.pressed.connect(Callable(self, "_open_async_stage_contest_leaderboard").bind(3))
	button_row.add_child(three_map_button)
	_apply_font(three_map_button, _font_semibold, 12)
	_style_button(three_map_button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))

	var five_map_button: Button = Button.new()
	five_map_button.text = "5 MAP STAGE LEADERS"
	five_map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	five_map_button.custom_minimum_size = Vector2(0.0, 40.0)
	five_map_button.pressed.connect(Callable(self, "_open_async_stage_contest_leaderboard").bind(5))
	button_row.add_child(five_map_button)
	_apply_font(five_map_button, _font_semibold, 12)
	_style_button(five_map_button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))

	async_vbox.add_child(panel)
	var close_index: int = async_close.get_index() if async_close != null else -1
	if close_index >= 0:
		async_vbox.move_child(panel, close_index)
	_async_stage_section = panel

func _get_async_stage_leaderboard_rows(map_count: int) -> Array:
	var contest_data: Dictionary = _resolve_async_stage_contest_data(map_count)
	var rows_any: Variant = contest_data.get("rows", [])
	var out: Array = []
	if typeof(rows_any) != TYPE_ARRAY:
		return out
	for row_any in rows_any as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		out.append(row_any)
	return out

func _open_async_stage_contest_leaderboard(map_count: int) -> void:
	_close_top_level_windows(UI_SURFACE_ENTRY)
	var resolved_map_count: int = 5
	if map_count == 3:
		resolved_map_count = 3
	var contest_data: Dictionary = _resolve_async_stage_contest_data(resolved_map_count)
	var contest_name: String = str(contest_data.get("contest_name", "Stage Contest"))
	var contest_time_left: String = str(contest_data.get("time_left", "--"))
	var title: String = "%d MAP STAGE CONTEST LEADERBOARD" % resolved_map_count
	var subtitle: String = "%s | Time Left: %s" % [contest_name, contest_time_left]
	var panel: Panel = _build_entry_overlay(title, subtitle, Vector2(980, 700))
	var body: VBoxContainer = _entry_overlay_body(panel)
	if body == null:
		return
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	body.add_child(header_row)

	var handle_header: Label = Label.new()
	handle_header.text = "HANDLE"
	handle_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(handle_header)
	_apply_font(handle_header, _font_semibold, 13)

	var total_header: Label = Label.new()
	total_header.text = "TOTAL TIME"
	total_header.custom_minimum_size = Vector2(240.0, 0.0)
	total_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(total_header)
	_apply_font(total_header, _font_semibold, 13)

	var left_header: Label = Label.new()
	left_header.text = "TIME LEFT"
	left_header.custom_minimum_size = Vector2(220.0, 0.0)
	left_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(left_header)
	_apply_font(left_header, _font_semibold, 13)

	var rows: Array = []
	var rows_any: Variant = contest_data.get("rows", [])
	if typeof(rows_any) == TYPE_ARRAY:
		rows = rows_any as Array
	for i in range(10):
		var row_box: HBoxContainer = HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 10)
		body.add_child(row_box)
		var entry: Dictionary = {}
		if i < rows.size() and typeof(rows[i]) == TYPE_DICTIONARY:
			entry = rows[i] as Dictionary
		var handle_label: Label = Label.new()
		handle_label.text = "%d. %s" % [i + 1, str(entry.get("handle", "--"))]
		handle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_child(handle_label)
		_apply_font(handle_label, _font_regular, 12)
		var total_label: Label = Label.new()
		total_label.text = str(entry.get("total_time", "--:--.---"))
		total_label.custom_minimum_size = Vector2(240.0, 0.0)
		total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row_box.add_child(total_label)
		_apply_font(total_label, _font_regular, 12)
		var left_label: Label = Label.new()
		left_label.text = str(entry.get("time_left", "--"))
		left_label.custom_minimum_size = Vector2(220.0, 0.0)
		left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row_box.add_child(left_label)
		_apply_font(left_label, _font_regular, 12)
	if rows.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No stage race submissions yet."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(empty_label)
		_apply_font(empty_label, _font_regular, 12)

	var close_button: Button = Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0.0, 40.0)
	close_button.pressed.connect(_close_entry_route_modal)
	body.add_child(close_button)
	_apply_font(close_button, _font_regular, 13)
	_style_button(close_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))

func _resolve_async_stage_contest_data(map_count: int) -> Dictionary:
	var output: Dictionary = {
		"contest_id": "",
		"contest_name": "Stage Contest",
		"time_left": "--",
		"rows": []
	}
	var contest_state: Node = get_node_or_null("/root/ContestState")
	if contest_state == null:
		return output
	var contest_obj: Variant = _select_async_stage_contest_for_leaderboard(contest_state)
	if contest_obj == null:
		return output
	var contest_id: String = str(_variant_dict_or_object_get(contest_obj, "id", ""))
	if contest_id.is_empty():
		return output
	output["contest_id"] = contest_id
	output["contest_name"] = str(_variant_dict_or_object_get(contest_obj, "name", "Stage Contest"))
	output["time_left"] = _format_async_contest_time_left(int(_variant_dict_or_object_get(contest_obj, "end_ts", 0)))
	if not contest_state.has_method("build_stage_race_overall_leaderboard"):
		return output
	var rows_any: Variant = contest_state.call("build_stage_race_overall_leaderboard", contest_id, map_count, 10)
	if typeof(rows_any) != TYPE_ARRAY:
		return output
	var rows_out: Array = []
	for row_any in rows_any as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		var handle: String = str(row.get("player_name", row.get("player_id", "--")))
		rows_out.append({
			"handle": handle,
			"total_time": _format_async_stage_total_time_ms(int(row.get("aggregate_time_ms", 0))),
			"time_left": str(output.get("time_left", "--"))
		})
	output["rows"] = rows_out
	return output

func _select_async_stage_contest_for_leaderboard(contest_state: Node) -> Variant:
	var selected: Variant = null
	var scope: String = "WEEKLY"
	var target_entry_usd: int = _current_async_paid_entry_usd()
	var best_distance: int = 2147483647
	var best_price: int = 2147483647
	if contest_state.has_method("get_contests_by_scope"):
		var contests_any: Variant = contest_state.call("get_contests_by_scope", scope)
		if typeof(contests_any) == TYPE_ARRAY:
			for contest_any in contests_any as Array:
				if contest_any == null:
					continue
				var price_usd: int = maxi(0, int(_variant_dict_or_object_get(contest_any, "price", 0)))
				if selected == null:
					selected = contest_any
					best_price = price_usd
					best_distance = abs(price_usd - target_entry_usd)
					continue
				if _async_track_mode == ASYNC_TRACK_PAID:
					var next_distance: int = abs(price_usd - target_entry_usd)
					if next_distance < best_distance or (next_distance == best_distance and price_usd < best_price):
						selected = contest_any
						best_distance = next_distance
						best_price = price_usd
				elif price_usd < best_price:
					selected = contest_any
					best_price = price_usd
	if selected != null:
		return selected
	if contest_state.has_method("get_contest_by_scope"):
		var fallback_any: Variant = contest_state.call("get_contest_by_scope", scope)
		if fallback_any != null:
			return fallback_any
	return null

func _variant_dict_or_object_get(source: Variant, key: String, default_value: Variant) -> Variant:
	if typeof(source) == TYPE_DICTIONARY:
		var dict: Dictionary = source as Dictionary
		return dict.get(key, default_value)
	if source is Object:
		var obj: Object = source as Object
		var value: Variant = obj.get(key)
		if value == null:
			return default_value
		return value
	return default_value

func _format_async_contest_time_left(end_ts: int) -> String:
	if end_ts <= 0:
		return "--"
	var now_unix: int = int(Time.get_unix_time_from_system())
	var remaining: int = maxi(0, end_ts - now_unix)
	var days: int = remaining / 86400
	var hours: int = (remaining % 86400) / 3600
	var minutes: int = (remaining % 3600) / 60
	if days > 0:
		return "%dd %02dh" % [days, hours]
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	return "%dm" % minutes

func _format_async_stage_total_time_ms(value_ms: int) -> String:
	var clamped: int = maxi(0, value_ms)
	var minutes: int = clamped / 60000
	var seconds: int = (clamped % 60000) / 1000
	var millis: int = clamped % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, millis]

func _close_entry_route_modal() -> void:
	if _entry_route_modal == null:
		return
	if is_instance_valid(_entry_route_modal):
		_entry_route_modal.queue_free()
	_entry_route_modal = null

func _close_play_mode_select() -> void:
	if _play_mode_select == null:
		return
	if is_instance_valid(_play_mode_select):
		_play_mode_select.queue_free()
	_play_mode_select = null

func _close_vs_lobby() -> void:
	if _vs_lobby == null:
		return
	if is_instance_valid(_vs_lobby):
		_vs_lobby.queue_free()
	_vs_lobby = null

func _close_time_puzzle_lobby() -> void:
	if _time_puzzle_lobby == null:
		return
	if is_instance_valid(_time_puzzle_lobby):
		_time_puzzle_lobby.queue_free()
	_time_puzzle_lobby = null

func _close_top_level_windows(except_surface: String = "") -> void:
	if except_surface != UI_SURFACE_ENTRY:
		_close_entry_route_modal()
	if except_surface != UI_SURFACE_HIVE_DROPDOWN and _hive_dropdown_open:
		_hide_hive_dropdown_immediate()
	if except_surface != UI_SURFACE_DASH:
		if _dash_tween != null and _dash_tween.is_running():
			_dash_tween.kill()
		if _hive_panel_tween != null and _hive_panel_tween.is_running():
			_hive_panel_tween.kill()
		_hive_direct_mode = false
		_buffs_direct_mode = false
		_store_direct_mode = false
		_settings_direct_mode = false
		_set_dash_panel_store_passthrough(false)
		_set_hive_panel_vertical_offset(0.0)
		_hide_dash_panels()
		_set_dash_hidden_state()
	if except_surface != UI_SURFACE_ASYNC and async_panel != null:
		async_panel.visible = false
	if except_surface != UI_SURFACE_PLAY_MODE:
		_close_play_mode_select()
	if except_surface != UI_SURFACE_VS_LOBBY:
		_close_vs_lobby()
	if except_surface != UI_SURFACE_TIME_PUZZLE:
		_close_time_puzzle_lobby()
	if except_surface != UI_SURFACE_SWARM_PASS and _swarm_pass_panel != null:
		_swarm_pass_panel.visible = false
	if except_surface != UI_SURFACE_BATTLE_PASS and _battle_pass_panel != null:
		_battle_pass_panel.visible = false
	if except_surface != UI_SURFACE_RANK and _rank_panel != null:
		_rank_panel.visible = false

func _open_play_mode_select() -> void:
	_close_top_level_windows(UI_SURFACE_PLAY_MODE)
	if _play_mode_select == null:
		_play_mode_select = preload("res://scenes/ui/PlayModeSelect.tscn").instantiate()
		_play_mode_select.closed.connect(func():
			_play_mode_select.queue_free()
			_play_mode_select = null
		)
		add_child(_play_mode_select)
	_play_mode_select.visible = true

func _set_dash_chrome_visible(visible: bool) -> void:
	if dash_top_bar != null:
		dash_top_bar.visible = visible
	if dash_root != null:
		dash_root.visible = visible
	if dash_hexes != null:
		dash_hexes.visible = visible
	dash_tab.visible = visible

func _set_dash_hidden_state() -> void:
	_set_dash_chrome_visible(true)
	_set_dash_offsets(_dash_hidden_x)
	dash_panel.visible = false
	_dash_open = false

func _hive_panel_hidden_top() -> float:
	var hidden_height: float = get_viewport_rect().size.y
	if dash_panel != null:
		hidden_height = maxf(hidden_height, dash_panel.size.y)
	return -hidden_height - 24.0

func _set_hive_panel_vertical_offset(offset_y: float) -> void:
	if dash_hive_panel == null:
		return
	dash_hive_panel.offset_top = offset_y
	dash_hive_panel.offset_bottom = offset_y

func _close_hive_panel_immediate() -> void:
	if _hive_panel_tween != null and _hive_panel_tween.is_running():
		_hive_panel_tween.kill()
	_hive_direct_mode = false
	_set_hive_panel_vertical_offset(0.0)
	if dash_hive_panel != null:
		dash_hive_panel.visible = false

func _open_hive_panel() -> void:
	if _hive_direct_mode:
		_close_hive_panel()
		return
	_close_top_level_windows(UI_SURFACE_DASH)
	_hive_direct_mode = true
	_hide_dash_panels()
	_set_dash_chrome_visible(false)
	_set_dash_offsets(0.0)
	_set_hive_panel_vertical_offset(_hive_panel_hidden_top())
	dash_panel.visible = true
	dash_hive_panel.visible = true
	_hive_panel_tween = create_tween()
	_hive_panel_tween.tween_property(dash_hive_panel, "offset_top", 0.0, HIVE_PULLDOWN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hive_panel_tween.parallel().tween_property(dash_hive_panel, "offset_bottom", 0.0, HIVE_PULLDOWN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_dash_open = true

func _close_hive_panel() -> void:
	if not _hive_direct_mode:
		_close_dash_panel(dash_hive_panel)
		return
	if _hive_panel_tween != null and _hive_panel_tween.is_running():
		_hive_panel_tween.kill()
	_hive_direct_mode = false
	var hidden_top: float = _hive_panel_hidden_top()
	_hive_panel_tween = create_tween()
	_hive_panel_tween.tween_property(dash_hive_panel, "offset_top", hidden_top, HIVE_PULLDOWN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hive_panel_tween.parallel().tween_property(dash_hive_panel, "offset_bottom", hidden_top, HIVE_PULLDOWN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hive_panel_tween.tween_callback(func() -> void:
		_close_hive_panel_immediate()
		_set_dash_hidden_state()
	)

func _on_dash_hive_close_pressed() -> void:
	_close_hive_panel()

func _open_buffs_panel() -> void:
	if _buffs_direct_mode:
		return
	_close_top_level_windows(UI_SURFACE_DASH)
	_buffs_direct_mode = true
	_hide_dash_panels()
	_set_dash_chrome_visible(false)
	_set_dash_offsets(0.0)
	dash_panel.visible = true
	dash_buffs_panel.visible = true
	_dash_open = true
	_ensure_buffs_cart_ui()
	_sync_buff_mode_tabs()
	_sync_buff_category_tabs()
	_refresh_buffs_library_buttons()
	_refresh_buffs_cart_ui()

func _close_buffs_panel_immediate() -> void:
	_buffs_direct_mode = false
	dash_buffs_panel.visible = false

func _close_buffs_panel() -> void:
	if not _buffs_direct_mode:
		_close_dash_panel(dash_buffs_panel)
		return
	_close_buffs_panel_immediate()
	_set_dash_hidden_state()

func _on_dash_buffs_close_pressed() -> void:
	_close_buffs_panel()

func _open_storefront_panel() -> void:
	_close_top_level_windows()
	_store_direct_mode = true
	_hide_dash_panels()
	_show_store_landing()
	_set_dash_chrome_visible(false)
	_set_dash_panel_store_passthrough(true)
	_set_dash_offsets(0.0)
	dash_panel.visible = true
	dash_store_panel.visible = true
	_apply_store_window_scale()
	_ensure_store_free_roll_skin()
	_dash_open = true
	status_label.text = "Store opened."

func _close_storefront_panel() -> void:
	_store_direct_mode = false
	dash_store_panel.visible = false
	_set_dash_panel_store_passthrough(false)
	_set_dash_chrome_visible(true)
	_set_dash_offsets(_dash_hidden_x)
	dash_panel.visible = false
	_dash_open = false

func _open_settings_panel() -> void:
	_close_top_level_windows(UI_SURFACE_DASH)
	_settings_direct_mode = true
	_hide_dash_panels()
	_set_dash_chrome_visible(false)
	_set_dash_offsets(0.0)
	dash_panel.visible = true
	dash_settings_panel.visible = true
	_dash_open = true

func _close_settings_panel() -> void:
	_settings_direct_mode = false
	dash_settings_panel.visible = false
	_set_dash_chrome_visible(true)
	_set_dash_offsets(_dash_hidden_x)
	dash_panel.visible = false
	_dash_open = false

func _on_dash_store_close_pressed() -> void:
	if _store_direct_mode:
		_close_storefront_panel()
		return
	_close_dash_panel(dash_store_panel)

func _on_dash_settings_close_pressed() -> void:
	if _settings_direct_mode:
		_close_settings_panel()
		return
	_close_dash_panel(dash_settings_panel)

func _toggle_dash() -> void:
	if _hive_dropdown_open:
		_hide_hive_dropdown_immediate()
	if _buffs_direct_mode:
		_close_buffs_panel_immediate()
		_set_dash_hidden_state()
		return
	if _hive_direct_mode:
		_close_hive_panel_immediate()
		_set_dash_hidden_state()
		return
	if _store_direct_mode:
		_close_storefront_panel()
		return
	if _settings_direct_mode:
		_close_settings_panel()
		return
	if not _dash_open:
		_close_top_level_windows(UI_SURFACE_DASH)
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
	_close_top_level_windows(UI_SURFACE_DASH)
	_set_dash_chrome_visible(true)
	_set_dash_panel_store_passthrough(panel == dash_store_panel)
	if panel == dash_store_panel:
		_apply_store_window_scale()
		_ensure_store_free_roll_skin()
		_show_store_landing()
	_hide_dash_panels()
	dash_panel.visible = true
	_set_dash_offsets(0.0)
	_dash_open = true
	panel.visible = true

func _open_dash_panel_from_menu(panel: Panel) -> void:
	_open_dash_panel(panel)
	if not _dash_open:
		_toggle_dash()

func _close_dash_panel(panel: Panel) -> void:
	if panel == null:
		return
	if panel == dash_store_panel:
		_set_dash_panel_store_passthrough(false)
	panel.visible = false

func _set_dash_panel_store_passthrough(enabled: bool) -> void:
	if dash_panel == null:
		return
	dash_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP
	if dash_store_panel != null:
		dash_store_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if dash_main_background != null:
		dash_main_background.visible = not enabled
	if enabled:
		_style_panel(dash_panel, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0))
	else:
		_style_panel(dash_panel, DASH_PANEL_BG_COLOR, DASH_PANEL_BORDER_COLOR)

func _hide_dash_panels() -> void:
	for panel in [dash_stats_panel, dash_analysis_panel, dash_replay_panel, dash_buffs_panel, dash_hive_panel, dash_store_panel, dash_settings_panel, dash_badges_panel_full]:
		panel.visible = false

func _open_async_panel() -> void:
	if async_panel == null:
		return
	_close_top_level_windows(UI_SURFACE_ASYNC)
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
		async_subtitle_label.text = "Cash track: ladders now. Stage contest boards are listed below."
	if async_top_row != null:
		async_top_row.visible = false
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
		async_subtitle_label.text = "Freeplay track: pick a mode below. Stage contest boards are listed below."
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
	_close_top_level_windows(UI_SURFACE_TIME_PUZZLE)
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
		_apply_usd_skin_to_button(button, amount, "$%d Entry" % amount)
		_style_usd_sprite_button(button, amount == selected)
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
	var amount: int = int(_async_buyins.get(mode, ASYNC_BUYINS[0]))
	var charge: Dictionary = _charge_paid_entry_usd(amount, "async_confirm:%s" % mode)
	if not bool(charge.get("ok", false)):
		return
	if bool(charge.get("bypassed", false)):
		_stub_action("%s entry $%d confirmed (dev bypass)" % [mode.capitalize(), amount])
		return
	_stub_action("%s entry $%d confirmed (charged, balance $%d)" % [mode.capitalize(), amount, int(charge.get("remaining_usd", _wallet_balance_usd()))])

func _on_async_miss_n_out_selected(free_play: bool, requested_map_count: int = 5) -> void:
	var contest_state: Node = get_node_or_null("/root/ContestState")
	var track_label: String = "Free Play" if free_play else "Ladder"
	var map_count_requested: int = maxi(1, requested_map_count)
	var entry_usd: int = 0 if free_play else _current_async_paid_entry_usd()
	if not free_play:
		var charge: Dictionary = _charge_paid_entry_usd(entry_usd, "async_miss_n_out")
		if not bool(charge.get("ok", false)):
			return
	var lobby_options: Dictionary = {
		"start_players": ASYNC_WINDOW_START_PLAYERS,
		"window_sec": ASYNC_STAGE_AND_MISS_WINDOW_SEC
	}
	if contest_state == null:
		status_label.text = "%s Miss-N-Out (%d maps, fallback lobby config)" % [track_label, map_count_requested]
		_open_async_vs_lobby("MISS_N_OUT", map_count_requested, free_play, entry_usd, lobby_options)
		return
	if not contest_state.has_method("get_contest_by_scope") or not contest_state.has_method("build_miss_n_out_plan"):
		status_label.text = "%s Miss-N-Out (%d maps, fallback lobby config)" % [track_label, map_count_requested]
		_open_async_vs_lobby("MISS_N_OUT", map_count_requested, free_play, entry_usd, lobby_options)
		return
	var contest: Variant = contest_state.call("get_contest_by_scope", "WEEKLY")
	if contest == null:
		status_label.text = "%s Miss-N-Out (%d maps, no weekly contest, fallback lobby config)" % [track_label, map_count_requested]
		_open_async_vs_lobby("MISS_N_OUT", map_count_requested, free_play, entry_usd, lobby_options)
		return
	var contest_id: String = str(contest.get("id"))
	var plan: Dictionary = contest_state.call("build_miss_n_out_plan", contest_id, map_count_requested) as Dictionary
	if not bool(plan.get("ok", false)):
		status_label.text = "%s Miss-N-Out (%d maps, plan unavailable, fallback lobby config)" % [track_label, map_count_requested]
		_open_async_vs_lobby("MISS_N_OUT", map_count_requested, free_play, entry_usd, lobby_options)
		return
	var map_ids: PackedStringArray = plan.get("map_ids", PackedStringArray()) as PackedStringArray
	var map_labels: Array[String] = []
	for map_id_v in map_ids:
		map_labels.append(str(map_id_v))
	var resolved_map_count: int = int(plan.get("map_count", map_count_requested))
	var window_sec: int = _resolve_plan_time_window_sec(plan, ASYNC_STAGE_AND_MISS_WINDOW_SEC)
	lobby_options["window_sec"] = window_sec
	lobby_options["contest_id"] = contest_id
	var miss_scope: String = str(contest.get("scope"))
	if miss_scope.is_empty():
		miss_scope = "WEEKLY"
	lobby_options["contest_scope"] = miss_scope
	lobby_options["map_ids"] = map_ids
	status_label.text = "%s Miss-N-Out (%d maps, %d min window): %s | Eliminated players can continue for practice or return to lobby." % [track_label, resolved_map_count, int(window_sec / 60), ", ".join(map_labels)]
	_open_async_vs_lobby("MISS_N_OUT", resolved_map_count, free_play, entry_usd, lobby_options)

func _on_async_stage_race_selected(map_count: int, free_play: bool) -> void:
	var contest_state: Node = get_node_or_null("/root/ContestState")
	var track_label: String = "Free Play" if free_play else "Ladder"
	var entry_usd: int = 0 if free_play else _current_async_paid_entry_usd()
	if not free_play:
		var charge: Dictionary = _charge_paid_entry_usd(entry_usd, "async_stage_race")
		if not bool(charge.get("ok", false)):
			return
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
	lobby_options["contest_id"] = contest_id
	var stage_scope: String = str(contest.get("scope"))
	if stage_scope.is_empty():
		stage_scope = "WEEKLY"
	lobby_options["contest_scope"] = stage_scope
	lobby_options["map_ids"] = map_ids
	status_label.text = "%s Stage Race (%d maps, %d min window): %s" % [track_label, map_count, int(window_sec / 60), ", ".join(map_labels)]
	_open_async_vs_lobby("STAGE_RACE", map_count, free_play, entry_usd, lobby_options)

func _on_async_timed_race_selected(map_count: int, free_play: bool) -> void:
	var contest_state: Node = get_node_or_null("/root/ContestState")
	var track_label: String = "Free Play" if free_play else "Ladder"
	var entry_usd: int = 0 if free_play else _current_async_paid_entry_usd()
	if not free_play:
		var charge: Dictionary = _charge_paid_entry_usd(entry_usd, "async_timed_race")
		if not bool(charge.get("ok", false)):
			return
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
	lobby_options["contest_id"] = contest_id
	var timed_scope: String = str(contest.get("scope"))
	if timed_scope.is_empty():
		timed_scope = "WEEKLY"
	lobby_options["contest_scope"] = timed_scope
	lobby_options["map_ids"] = map_ids
	status_label.text = "%s Timed Race (%d maps, sync start after %ds): %s" % [track_label, map_count, int(lobby_options.get("sync_join_sec", ASYNC_TIMED_RACE_SYNC_JOIN_SEC)), ", ".join(map_labels)]
	_open_async_vs_lobby("TIMED_RACE", map_count, free_play, entry_usd, lobby_options)

func _current_async_paid_entry_usd() -> int:
	return maxi(1, _async_paid_entry_usd)

func _open_async_vs_lobby(mode_id: String, map_count: int, free_play: bool, entry_usd: int, options: Dictionary = {}) -> void:
	_close_top_level_windows(UI_SURFACE_VS_LOBBY)
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
	_set_dash_chrome_visible(true)
	_store_direct_mode = false
	_settings_direct_mode = false
	_buffs_direct_mode = false
	_hive_direct_mode = false
	if _hive_panel_tween != null and _hive_panel_tween.is_running():
		_hive_panel_tween.kill()
	_set_hive_panel_vertical_offset(0.0)
	dash_buffs_panel.visible = false
	dash_hive_panel.visible = false
	_dash_tab_closed_left = dash_tab.offset_left + DASH_TAB_CLOSED_EDGE_SHIFT
	_dash_tab_closed_right = dash_tab.offset_right + DASH_TAB_CLOSED_EDGE_SHIFT
	dash_tab.offset_left = _dash_tab_closed_left
	dash_tab.offset_right = _dash_tab_closed_right
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
