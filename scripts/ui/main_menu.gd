extends Control

const SFLog = preload("res://scripts/util/sf_log.gd")
const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")
const MAP_LOADER = preload("res://scripts/maps/map_loader.gd")
const MAP_REGISTRY = preload("res://scripts/maps/map_registry.gd")
const MAP_MODE_RULES = preload("res://scripts/maps/map_mode_rules.gd")
const SWARM_PASS_PANEL_SCENE_PATH: String = "res://scenes/ui/SwarmPassPanel.tscn"
const BATTLE_PASS_PANEL_SCENE_PATH: String = "res://scenes/ui/BattlePassPanel.tscn"
const RANK_PANEL_SCENE_PATH: String = "res://scenes/ui/RankPanel.tscn"
const JUKEBOX_PANEL_SCENE_PATH: String = "res://scenes/ui/JukeboxPanel.tscn"
const GARAGE_PANEL_SCENE_PATH: String = "res://scenes/ui/GaragePanel.tscn"
const SCHOLASTIC_PANEL_SCENE_PATH: String = "res://scenes/ui/ScholasticPanel.tscn"
const FREE_ROLL_GAME_HUB_SCENE_PATH: String = "res://scenes/ui/FreeRollGameHub.tscn"
const DASH_BUFFS_HERO_SCENE_PATH: String = "res://scenes/ui/DashBuffsHero.tscn"
const DASH_ACHIEVEMENTS_HERO_SCENE_PATH: String = "res://scenes/ui/DashAchievementsHero.tscn"
const HEX_SEAM_BACKGROUND_SCENE_PATH: String = "res://ui/backgrounds/HexSeamBackground.tscn"
const UITypography := preload("res://scripts/ui/ui_typography.gd")
const MatchTelemetryModelScript = preload("res://scripts/state/match_telemetry_model.gd")
const MatchAnalyzerScript = preload("res://scripts/state/match_analyzer.gd")
const MatchReplayMapViewScript = preload("res://scripts/ui/match_replay_map_view.gd")
const AsyncContestConfigStoreScript := preload("res://scripts/state/async_contest_config_store.gd")
const AsyncContestDashPanelScript := preload("res://scripts/ui/async_contest_dash_panel.gd")
const MATCH_BACKGROUND_INLAY_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/match_background_inlay.png"
const HONEY_WIDGET_SCENE_PATH: String = "res://ui/hud/honey/honey_widget.tscn"
const TIER_WIDGET_SCENE_PATH: String = "res://ui/hud/tier/tier_widget.tscn"
const HONEY_TEXT_SHADER_PATH: String = "res://ui/hud/honey/honey_text_honeycomb.gdshader"
const SWARMFRONT_TITLE_SHADER_PATH: String = "res://ui/main_menu/swarmfront_title_forged.gdshader"
const TOP_CHROME_SAFE_FALLBACK_PX: float = 72.0
const TOP_CHROME_SAFE_MAX_PX: float = 96.0
const TOP_BAR_BASE_HEIGHT_PX: float = 90.0
const DASH_TOP_BAR_BASE_HEIGHT_PX: float = 64.0
const DASH_ROOT_BASE_TOP_PX: float = 72.0
const MAIN_USABLE_TOP_GAP_PX: float = 12.0
const MAIN_MENU_SURFACE_SIDE_MARGIN_PX: float = 24.0
const MAIN_MENU_SURFACE_BOTTOM_MARGIN_PX: float = 24.0
const HONEY_FONT_COLOR: Color = Color(0.97, 0.73, 0.19, 1.0)
const HONEY_OUTLINE_COLOR: Color = Color(0.20, 0.09, 0.01, 0.98)
const HONEY_SHADOW_COLOR: Color = Color(0.10, 0.04, 0.01, 0.88)
const HONEY_WIDGET_PANEL_WIDTH: float = 300.0
const HONEY_WIDGET_PANEL_HEIGHT: float = 200.0
const HONEY_WIDGET_RIGHT_MARGIN: float = 22.0
const HONEY_WIDGET_TOP_OFFSET: float = 10.0
const TIER_WIDGET_LEFT_MARGIN: float = 8.0
const TIER_WIDGET_TOP_OFFSET: float = 10.0
const TIER_WIDGET_PANEL_WIDTH: float = 272.0
const TIER_WIDGET_PANEL_HEIGHT: float = 200.0
const MM_BACKGROUND_Y_SHIFT: float = -680.0
const MM_BACKGROUND_X_SCALE: float = 0.88
const MM_BACKGROUND_EXTRA_SIDE_PX: float = 90.0
const MM_BACKGROUND_STRETCH_MODE: int = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
const MM_PLATFORM_DIMMER_ALPHA: float = 0.19
const MM_HERO_PANEL_ANCHOR_LEFT: float = 0.14
const MM_HERO_PANEL_ANCHOR_RIGHT: float = 0.86
const MM_HERO_PANEL_ANCHOR_TOP: float = 0.30
const MM_HERO_PANEL_ANCHOR_BOTTOM: float = 0.66
const MATCH_REPLAY_SAVE_DIR: String = "user://matches"
const MM_BOOT_SOUND_ENABLED: bool = false
const MM_BOOT_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/mm_ambient.wav"
const MM_BASE_DROP_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/mm_base_drop.mp3"
const STORE_PURCHASE_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/store_purchase.wav"
const MATCHMAKER_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/matchmaker.wav"
const JUKEBOX_PLAY_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/jukebox_play.wav"
const BUFF_EQUIP_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/buff_equip.wav"

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
const UI_SURFACE_RANK_CONTEXT := "rank_context"
const UI_SURFACE_HIVE_DROPDOWN := "hive_dropdown"
const TREE_META_PENDING_STAGE_LEADERBOARD: String = "pending_stage_leaderboard_open"
const TREE_META_PENDING_STAGE_LEADERBOARD_CONTEXT: String = "pending_stage_leaderboard_context"
const DASH_HERO_TAB_GARAGE := "garage"
const DASH_HERO_TAB_BUFFS := "buffs"
const DASH_HERO_TAB_ACHIEVEMENTS := "achievements"
const DASH_HERO_TAB_FRIENDS := "friends"
const SCHOLASTIC_SFU_MAX_AGE: int = 24
const SCHOLASTIC_CTA_COOLDOWN_SEC: int = 5 * 60
const DASH_HEX_BUFFS_KEY := "ui.mm.buffs.normal"
const DASH_HEX_STORE_KEY := "ui.mm.store.normal"
const DASH_HEX_HIVE_KEY := "ui.mm.hive.normal"
const DASH_HEX_JUKEBOX_KEY := "ui.mm.jukebox.normal"
const DASH_HEX_BASE_SIZE: Vector2 = Vector2(90.0, 64.0)
const DASH_HEX_SIZE_SCALE: float = 1.38
const DASH_HEX_CONTAINER_RIGHT_MARGIN: float = 8.0
const DASH_HEX_CONTAINER_EXTRA_WIDTH: float = 16.0
const DASH_TAB_CLOSED_EDGE_SHIFT: float = 0.0
const HIVE_VIEW_MEMBER := "member"
const HIVE_VIEW_CANDIDATE := "candidate"

@onready var top_bar: Control = $TopBar
@onready var hive_button: HexButton = $TopBar/HiveButton
@onready var brand_title_label: Label = $TopBar/BrandTitle
@onready var welcome_handle_label: Label = $TopBar/WelcomeHandleLabel
@onready var dash_tab: HexButton = $DashTab
@onready var dash_panel: Panel = $DashPanel
@onready var dash_main_background: Control = $DashPanel/HexSeamBackground
@onready var dash_top_bar: Control = $DashPanel/DashTopBar
@onready var dash_root: VBoxContainer = $DashPanel/DashRoot
@onready var dash_handle_label: Label = $DashPanel/DashRoot/DashHandleLabel
@onready var dash_tabs: HBoxContainer = $DashPanel/DashRoot/DashTabs
@onready var dash_garage_tab: Button = $DashPanel/DashRoot/DashTabs/GarageTab
@onready var dash_buffs_tab: Button = $DashPanel/DashRoot/DashTabs/BuffsTab
@onready var dash_achievements_tab: Button = $DashPanel/DashRoot/DashTabs/AchievementsTab
@onready var dash_settings_tab: Button = $DashPanel/DashRoot/DashTabs/SettingsTab
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
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow/HivePostMessage,
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow/HivePinNotice,
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow/HiveChat,
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow/HiveLadder,
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow/HiveQuests,
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow/HiveAbout
]
var _store_category_buttons: Array = []
var _store_sku_buttons: Array = []
var _time_puzzle_lobby: TimePuzzleLobby = null
var _time_puzzle_return_async_panel: bool = false
var _play_mode_select: Control = null
var _vs_lobby: Control = null
var _vs_lobby_return_async_panel: bool = false
var _entry_route_modal: Panel = null
var _async_stage_section: Panel = null
var _swarm_pass_panel: Control = null
var _battle_pass_panel: Control = null
var _rank_panel: Control = null
var _rank_context_panel: Panel = null
var _jukebox_panel: Panel = null
var _dash_hex_jukebox: HexButton = null
var _async_contest_dash_panel: Panel = null
var _dash_hex_async_contest: HexButton = null
var _async_contest_config_store: RefCounted = AsyncContestConfigStoreScript.new()
var _mm_boot_sound_player: AudioStreamPlayer = null
var _mm_boot_sound_started: bool = false
var _menu_sfx_player: AudioStreamPlayer = null
const TREE_META_REOPEN_JUKEBOX_ON_READY: String = "reopen_jukebox_on_ready"
const TREE_META_REOPEN_JUKEBOX_STATE: String = "reopen_jukebox_state"
var _dash_garage_panel: Control = null
var _dash_buffs_hero: Control = null
var _dash_achievements_hero: Control = null
var _dash_friends_panel: Control = null
var _dash_friends_tab: Button = null
var _dash_scholastic_panel: Panel = null
var _dash_scholastic_tab: Button = null
var _scholastic_cta_dialog: ConfirmationDialog = null
var _scholastic_cta_timer: Timer = null
var _scholastic_last_cta_unix: int = 0
var _friends_list_vbox: VBoxContainer = null
var _friends_empty_label: Label = null
var _friend_presence_timer: Timer = null
var _pending_friend_invite: Dictionary = {}
var _dash_active_tab: String = DASH_HERO_TAB_GARAGE
var _honey_widget: Control = null
var _tier_widget: Control = null
var _game_hub_live_refresh_pending: bool = false
var _free_roll_press_block_until_msec: int = 0
var _latest_replay_data: Dictionary = {}
var _last_replay_data: Dictionary = {}
var _last_replay_cursor_index: int = 0
var _last_replay_speed_index: int = 0
var _last_replay_is_playing: bool = false
var _last_replay_playback_serial: int = 0
var _home_replay_panel: Panel = null
var _home_replay_progress: ProgressBar = null
var _home_replay_time_label: Label = null
var _home_replay_rows: Array = []
var _home_replay_buttons: Array = []
var _home_replay_map_view: Control = null
var _dash_replay_map_view: Control = null
var _packed_scene_cache: Dictionary = {}
var _match_background_inlay_texture: Texture2D = null
var _honey_text_shader: Shader = null
var _swarmfront_title_shader: Shader = null
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
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsList/AsyncLadderStage5,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsList/AsyncLadderCaptureFlag
]
@onready var async_free_buttons: Array = [
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList/AsyncFreeMissNOut,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList/AsyncFreeRace3,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList/AsyncFreeRace5,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList/AsyncFreeStage3,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList/AsyncFreeStage5,
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncFreeList/AsyncFreeCaptureFlag
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
@onready var menu_jukebox_button: Button = $BottomBar/MenuButtons/RightButtons/JukeboxButton
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
var _main_art_shroud_active: bool = true
var _store_direct_mode: bool = false
var _settings_direct_mode: bool = false
var _buffs_direct_mode: bool = false
var _hive_direct_mode: bool = false
var _jukebox_direct_mode: bool = false
var _replay_direct_mode: bool = false
var _hive_panel_tween: Tween = null
var _player_profile := {
	"tier_text": "Tier: Bronze",
	"honey": 12480
}
var _wallet_profile := {
	"balance_usd": 0
}
var _dev_bypass_cash_balance := true
const HIVE_PANEL_PROFILE_DEFAULT := {
	"view_mode": HIVE_VIEW_MEMBER,
	"name": "Swarmfront Prime",
	"tier": "Bronze",
	"member_role": "Member",
	"member_rank_within_hive": 7,
	"office_title": "Quartermaster",
	"ecosystem_rank": 148,
	"member_since_text": "Member for 26d",
	"hive_honey": 12480,
	"hive_honey_total": 982400,
	"honey_score": 12480,
	"wax_score": 940,
	"season_name": "Season 01: Founding Swarm",
	"season_reset_text": "Resets in 12d 04h",
	"members": [
		"Mason | Queen | H19,200",
		"Sable | Soldier | H12,400",
		"Nora | Soldier | H9,880",
		"... +8 more members"
	],
	"messages": [
		"Leader: Tournament check-in closes in 2d.",
		"Soldiers: Tournament routing at 9pm.",
		"Welcome WaspRider to the hive.",
		"Pending invites: 2 | Governance inbox: 1"
	],
	"achievements": [
		"Hive Lift-Off",
		"Season Relay I",
		"Wax Guard II",
		"Founded Jan 15 | Avg service 26d"
	],
	"member_records": [],
	"browse_hives": [],
	"selected_hive": {},
	"selected_hive_id": "",
		"visible_invites": [],
		"pending_applications": [],
		"tournament_entries": {},
		"tournament_dashboard": {},
		"tournament_status_line": "",
		"local_rank_position": 0,
		"local_tier_id": "DRONE",
		"local_wax_score": 0.0,
	"local_display_name": "Player",
	"local_honey": 0
}
var _hive_panel_profile := HIVE_PANEL_PROFILE_DEFAULT.duplicate(true)
var _hive_candidate_selected_hive_id: String = ""
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
var _tournament_track_mode: String = "free"
var _tournament_browser_root: VBoxContainer = null
var _tournament_free_tab: Button = null
var _tournament_money_tab: Button = null
var _tournament_list: VBoxContainer = null
var _joined_tournaments: Dictionary = {}
var _money_games_selected_division: String = "division_i"
var _money_games_selected_tier: int = 1

const ASYNC_BUYINS := [1, 2, 3, 5, 10]
const MONEY_DENOMINATIONS := [1, 2, 3, 5, 10, 20, 50]
const ASYNC_MAPS := ["Map A", "Map B", "Map C", "Map D", "Map E"]
const ASYNC_CONFIRM_WINDOW_MS := 900
const ASYNC_TRACK_SELECT := "select"
const ASYNC_TRACK_PAID := "paid"
const ASYNC_TRACK_FREE := "free"
const TOURNAMENT_TRACK_FREE := "free"
const TOURNAMENT_TRACK_MONEY := "money"
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
const BUFF_UI_TITLE_FONT_SIZE: int = 25
const BUFF_UI_BODY_FONT_SIZE: int = 18
const BUFF_UI_HEADER_FONT_SIZE: int = 17
const BUFF_UI_BUTTON_FONT_SIZE: int = 15
const BUFF_UI_SMALL_FONT_SIZE: int = 14
const BUFF_UI_MODE_BUTTON_HEIGHT: float = 48.0
const BUFF_UI_SLOT_BUTTON_HEIGHT: float = 38.0
const BUFF_UI_LIBRARY_BUTTON_HEIGHT: float = 38.0
const BUFF_UI_LOADOUT_TOP_HEIGHT: float = 194.0
const BUFF_UI_CART_HEIGHT: float = 232.0
const BUFF_UI_CART_PANEL_HEIGHT: float = 188.0
const USD_SKIN_DIR_PATH: String = "res://assets/sprites/sf_skin_v1"
const USD_SKIN_FALLBACK_PATH: String = "res://assets/sprites/sf_skin_v1/$.png"
const CANCEL_SKIN_PATH: String = "res://assets/sprites/sf_skin_v1/cancel.png"
const CLOSE_SKIN_PATH: String = "res://assets/sprites/sf_skin_v1/Close.png"
const STORE_CATEGORY_SKIN_BY_ID: Dictionary = {
	"BUNDLES": "res://assets/sprites/sf_skin_v1/Bundles.png",
	"BATTLEPASS": "res://assets/sprites/sf_skin_v1/battle_pass.png",
	"BUFFS": "res://assets/sprites/sf_skin_v1/Buffs_1.png",
	"GAMEPLAYANALYSIS": "res://assets/sprites/sf_skin_v1/game_analytics.png",
	"SKINS": "res://assets/sprites/sf_skin_v1/skins_alpha.png",
	"MERCH": "res://assets/sprites/sf_skin_v1/merchii.png"
}
const HUMAN_MODE_SKIN_BY_MODE: Dictionary = {
	"1V1": "res://assets/sprites/sf_skin_v1/1v1.png",
	"CTF": "res://assets/sprites/sf_skin_v1/capture_the_flag.png",
	"HIDDEN CTF": "res://assets/sprites/sf_skin_v1/hidden_flag.png",
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
	"CAPTURE FLAG": "res://assets/sprites/sf_skin_v1/capture_the_flag.png",
	"HIDDEN FLAG": "res://assets/sprites/sf_skin_v1/hidden_flag.png",
	"STAGE RACE": "res://assets/sprites/sf_skin_v1/Stage_Race.png",
	"RACE": "res://assets/sprites/sf_skin_v1/Race.png",
	"MISS N OUT": "res://assets/sprites/sf_skin_v1/Miss_n_Out.png"
}
const HIDDEN_CTF_MAP_IDS: Array[String] = [
	"res://maps/_future/nomansland/MAP_nomansland__545__v13_top3_each__1p.json"
]
const DIRECT_CTF_MAP_IDS: Array[String] = [
	"res://maps/_future/nomansland/MAP_nomansland__545__v01_top2_sides__1p.json"
]
const BOTTOM_NAV_BUTTON_SCALE: float = 3.2175
const BOTTOM_NAV_HEIGHT_SCALE: float = 1.2
const BOTTOM_NAV_BASE_BUTTON_SIZE: Vector2 = Vector2(38.0, 56.0)
const BOTTOM_NAV_CENTER_STRETCH_RATIO: float = 1.2
const BOTTOM_NAV_OUTER_PADDING: float = 8.0
const BOTTOM_NAV_GROUP_SEPARATION: int = 6
const BOTTOM_NAV_BUTTON_SEPARATION: int = 4
const HIVE_DROPDOWN_WIDTH: float = 420.0
const HIVE_DROPDOWN_HEIGHT: float = 292.0
const HIVE_DROPDOWN_TOP_GAP: float = 8.0
const HIVE_PULLDOWN_DURATION: float = 0.24
const GAME_MENU_BUTTON_SCALE: float = 1.2
const HIVE_CREATE_DIALOG_WIDTH: int = 760
const HIVE_CREATE_DIALOG_HEIGHT: int = 360
const HIVE_CREATE_DIALOG_MOBILE_MARGIN: int = 42
const HIVE_TEXT_DIALOG_WIDTH: int = 800
const HIVE_ABOUT_DIALOG_HEIGHT: int = 560
const HIVE_DIALOG_BELOW_BANNER_TOP_RATIO: float = 0.23
const HIVE_DIALOG_BELOW_BANNER_MIN_TOP: int = 360
const GAME_HUB_OVERLAY_TARGET_WIDTH: float = 1176.0
const GAME_HUB_OVERLAY_FREE_TARGET_HEIGHT: float = 1512.0
const GAME_HUB_OVERLAY_PAID_TARGET_HEIGHT: float = 1248.0
const GAME_HUB_OVERLAY_VIEWPORT_MARGIN_X: float = 24.0
const GAME_HUB_OVERLAY_VIEWPORT_MARGIN_Y: float = 24.0
const GAME_HUB_OVERLAY_FREE_MIN_HEIGHT: float = 700.0
const GAME_HUB_OVERLAY_PAID_MIN_HEIGHT: float = 760.0
const GAME_HUB_OVERLAY_EXTRA_BOTTOM_PX: float = 50.0
const GAME_HUB_OVERLAY_EXTRA_TOP_PX: float = 30.0
const GAME_HUB_OVERLAY_FREE_SHIFT_DOWN_PX: float = 36.0
const GAME_HUB_HUMAN_BUTTON_SIZE: Vector2 = Vector2(206.0, 86.0)
const GAME_HUB_HUMAN_ICON_MAX_WIDTH: int = 199
const GAME_HUB_CYCLE_BUTTON_SIZE: Vector2 = Vector2(343.0, 130.0)
const GAME_HUB_CYCLE_ICON_MAX_WIDTH: int = 326
const GAME_HUB_ASYNC_MODE_BUTTON_SIZE: Vector2 = Vector2(283.0, 98.0)
const GAME_HUB_ASYNC_MODE_ICON_MAX_WIDTH: int = 269
const GAME_HUB_CANCEL_BUTTON_SIZE: Vector2 = Vector2(283.0, 98.0)
const GAME_HUB_FREE_TOP_ROW_SCALE: float = 1.75
const GAME_HUB_FREE_LOWER_ROWS_SCALE: float = 1.35
const GAME_HUB_CONTENT_SHIFT_X: float = -20.0
const GAME_HUB_FREE_CENTER_BIAS_X: float = 0.0
const GAME_HUB_FREE_CENTER_TRACK_RIGHT_INSET: float = 84.0
const GAME_HUB_FREE_BUTTON_TRACK_RIGHT_INSET: float = 96.0
const GAME_HUB_FREE_LAYOUT_VERSION: int = 9
const GAME_HUB_CONTENT_TOP_PADDING_PX: float = 24.0
const GAME_HUB_FREE_CONTENT_TOP_PADDING_PX: float = 42.0
const GAME_HUB_FREE_BODY_SEPARATION: int = 14
const GAME_HUB_FREE_CLUSTER_SPACING: int = 10
const GAME_HUB_FREE_TRIPLE_ROW_SCALE: float = 0.88
const GAME_HUB_FREE_TRIPLE_ROW_SEPARATION: int = 4
const GAME_HUB_FREE_TRIPLE_ROW_SHIFT_X: float = 56.0
const GAME_HUB_FREE_SECTION_SPACER_PX: float = 14.0
const GAME_HUB_FREE_MAP_GROUP_SPACER_PX: float = 12.0
const GAME_HUB_FREE_BOTTOM_SPACER_PX: float = 20.0
const GAME_HUB_TOUCH_LAYOUT_MAX_WIDTH: float = 1100.0
const GAME_HUB_TOUCH_PAID_TOP_ROW_SCALE: float = 1.46
const GAME_HUB_TOUCH_PAID_LOWER_ROWS_SCALE: float = 1.34
const GAME_HUB_TOUCH_PAID_CLUSTER_SPACING: int = 14
const GAME_HUB_MONEY_TOP_ROW_SCALE: float = 1.48
const GAME_HUB_MONEY_LOWER_ROWS_SCALE: float = 1.24
const GAME_HUB_MONEY_BODY_SEPARATION: int = 12
const GAME_HUB_MONEY_CLUSTER_SPACING: int = 14
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
const FREE_ROLL_SCENE_CANVAS_WIDTH: float = 864.0
const FREE_ROLL_SCENE_CANVAS_HEIGHT: float = 2320.0
const FREE_ROLL_HUMAN_BUTTON_SIZE: Vector2 = Vector2(360.0, 150.0)
const FREE_ROLL_CYCLE_BUTTON_SIZE: Vector2 = Vector2(360.0, 142.0)
const FREE_ROLL_ROUTE_BUTTON_SIZE: Vector2 = Vector2(360.0, 138.0)
const FREE_ROLL_CANCEL_BUTTON_SIZE: Vector2 = Vector2(320.0, 116.0)
const FREE_ROLL_PRESS_CANCEL_DRAG_PX: float = 16.0
const FREE_ROLL_PRESS_CANCEL_HOLD_MS: int = 260
const FREE_ROLL_PRESS_RELEASE_BLOCK_MS: int = 180
const STORE_WINDOW_SCALE_X: float = 0.74
const STORE_WINDOW_SCALE_Y: float = 0.62
const STORE_WINDOW_INSET_BOTTOM: float = 14.0
const STORE_WINDOW_SHIFT_DOWN_PX: float = 84.0
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
const STORE_HEADER_TOP_INSET: float = -104.0
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
const MONEY_DIVISION_TAB_SIZE: Vector2 = Vector2(223.0, 82.0)
const MONEY_ENTRY_TIER_BUTTON_SIZE: Vector2 = Vector2(128.0, 56.0)
const MONEY_DIVISION_LABEL_SIZE: int = 16
const MONEY_DIVISION_LOCKED_LABEL_SIZE: int = 13
const MONEY_ENTRY_LABEL_SIZE: int = 17
const MONEY_ENTRY_TIER_LABEL_SIZE: int = 16
const MONEY_ARENA_LABEL_SIZE: int = 17
const MONEY_ENTRY_FEE_LABEL_SIZE: int = 15
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
var _hive_create_dialog: ConfirmationDialog = null
var _hive_create_name_input: LineEdit = null
var _hive_create_done_button: Button = null
var _hive_invite_dialog: ConfirmationDialog = null
var _hive_invite_list: ItemList = null
var _hive_invite_meta_label: Label = null
var _hive_invite_bundle_select: OptionButton = null
var _hive_invite_sort_mode: String = "rank"
var _hive_pending_dialog: AcceptDialog = null
var _hive_pending_list: ItemList = null
var _hive_pending_meta_label: Label = null
var _hive_leave_dialog: ConfirmationDialog = null
var _hive_leave_desc_label: Label = null
var _hive_browse_dialog: ConfirmationDialog = null
var _hive_browse_list: ItemList = null
var _hive_browse_meta_label: Label = null
var _hive_my_invites_dialog: AcceptDialog = null
var _hive_my_invites_list: ItemList = null
var _hive_my_invites_meta_label: Label = null
var _hive_applications_dialog: AcceptDialog = null
var _hive_applications_list: ItemList = null
var _hive_applications_meta_label: Label = null
var _hive_member_actions_dialog: AcceptDialog = null
var _hive_member_actions_list: ItemList = null
var _hive_member_actions_meta_label: Label = null
var _hive_member_actions_detail_label: Label = null
var _hive_member_actions_promote_button: Button = null
var _hive_member_actions_vote_promote_button: Button = null
var _hive_member_actions_discipline_button: Button = null
var _hive_member_actions_leadership_vote_button: Button = null
var _hive_member_actions_remove_button: Button = null
var _hive_remove_member_dialog: ConfirmationDialog = null
var _hive_remove_member_desc_label: Label = null
var _hive_remove_member_target: Dictionary = {}
var _hive_post_dialog: ConfirmationDialog = null
var _hive_post_input: TextEdit = null
var _hive_pin_dialog: ConfirmationDialog = null
var _hive_pin_input: TextEdit = null
var _hive_about_dialog: ConfirmationDialog = null
var _hive_about_input: TextEdit = null
var _hive_about_done_button: Button = null
var _hive_about_desc_label: Label = null
var _hive_rankings_dialog: AcceptDialog = null
var _hive_rankings_list: ItemList = null
var _hive_rankings_meta_label: Label = null
var _hive_tournaments_dialog: AcceptDialog = null
var _hive_tournaments_list: ItemList = null
var _hive_tournaments_meta_label: Label = null
var _hive_tournaments_detail_label: Label = null
var _hive_tournaments_enter_button: Button = null
var _hive_tournaments_launch_button: Button = null
var _announced_hive_tournament_round_id: String = ""
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
		"description": "Premium rewards, +20% nectar, and one extra side-quest path.",
		"price_real": "$9.99",
		"entitlements": ["battle_pass_premium"]
	},
	{
		"id": "battle_pass_elite",
		"category": "BattlePass",
		"subcategory": "Season",
		"title": "Elite Track",
		"description": "Premium rewards, +30% nectar, two extra side-quest paths, and elite prestige access.",
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
	set_process(true)
	_load_fonts()
	_apply_background_art_direction()
	_ensure_tier_widget()
	_ensure_honey_widget()
	_style_labels()
	_ensure_friends_tab()
	_ensure_scholastic_dash_surface()
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
	if not get_viewport().size_changed.is_connected(_apply_top_safe_area_layout):
		get_viewport().size_changed.connect(_apply_top_safe_area_layout)
	_set_hex_buttons()
	_apply_top_safe_area_layout()
	_ensure_home_replay_player()
	_build_store_landing()
	_init_buffs_ui()
	_apply_surface_hex_background_presets()
	call_deferred("_prime_store_free_roll_skin")
	_load_profile_commerce_state()
	_bind_profile_honey_signal()
	_bind_profile_dash_signals()
	_bind_scholastic_dashboard_state()
	_apply_performance_pref_from_profile()
	call_deferred("_init_dash_state")
	call_deferred("_finish_noncritical_menu_boot")
	call_deferred("_apply_pending_jukebox_reopen_request")
	call_deferred("_apply_pending_stage_leaderboard_request")
	_apply_player_profile(_player_profile)
	_refresh_profile_handle_labels()
	status_label.text = "Ready"
	_bind_onboarding_gate()
	if HiveClanState != null and HiveClanState.has_signal("hive_clan_state_changed"):
		if not HiveClanState.hive_clan_state_changed.is_connected(_on_hive_clan_state_changed):
			HiveClanState.hive_clan_state_changed.connect(_on_hive_clan_state_changed)
	_sync_hive_panel_profile_from_hive_state()
	_start_friend_presence_poll()
	_start_scholastic_cta_timer()
	call_deferred("_sync_main_art_shroud")
	call_deferred("_play_mm_boot_sound")
	call_deferred("_auto_start_home_replay")

func _finish_noncritical_menu_boot() -> void:
	_ensure_dash_replay_map_view()
	_load_match_history()
	_refresh_home_replay_hint()
	_configure_dash_account_surfaces()
	_refresh_scholastic_dash_visibility()
	_maybe_show_sfa_join_cta(true)

func _load_packed_scene(path: String) -> PackedScene:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		return null
	if _packed_scene_cache.has(clean_path):
		return _packed_scene_cache[clean_path] as PackedScene
	var loaded: Resource = load(clean_path)
	var scene: PackedScene = loaded as PackedScene
	if scene != null:
		_packed_scene_cache[clean_path] = scene
	return scene

func _match_background_inlay() -> Texture2D:
	if _match_background_inlay_texture != null:
		return _match_background_inlay_texture
	var loaded: Resource = load(MATCH_BACKGROUND_INLAY_TEXTURE_PATH)
	_match_background_inlay_texture = loaded as Texture2D
	return _match_background_inlay_texture

func _load_shader(path: String) -> Shader:
	var loaded: Resource = load(path)
	return loaded as Shader

func _honey_text_shader_resource() -> Shader:
	if _honey_text_shader == null:
		_honey_text_shader = _load_shader(HONEY_TEXT_SHADER_PATH)
	return _honey_text_shader

func _swarmfront_title_shader_resource() -> Shader:
	if _swarmfront_title_shader == null:
		_swarmfront_title_shader = _load_shader(SWARMFRONT_TITLE_SHADER_PATH)
	return _swarmfront_title_shader

func _play_mm_boot_sound() -> void:
	if not MM_BOOT_SOUND_ENABLED:
		return
	if _mm_boot_sound_started:
		return
	if not _is_menu_sfx_enabled():
		return
	var stream: AudioStream = load(MM_BOOT_SOUND_PATH) as AudioStream
	if stream == null:
		push_warning("MM_BOOT_SOUND_MISSING: " + MM_BOOT_SOUND_PATH)
		return
	if _mm_boot_sound_player == null:
		_mm_boot_sound_player = AudioStreamPlayer.new()
		_mm_boot_sound_player.name = "MMBootSoundPlayer"
		add_child(_mm_boot_sound_player)
	_mm_boot_sound_player.stream = stream
	_mm_boot_sound_started = true
	_mm_boot_sound_player.play()

func _play_menu_sfx(sound_path: String, persist_on_scene_change: bool = false) -> void:
	if not _is_menu_sfx_enabled():
		return
	var clean_path: String = sound_path.strip_edges()
	if clean_path.is_empty():
		return
	var stream: AudioStream = load(clean_path) as AudioStream
	if stream == null:
		push_warning("MENU_SFX_MISSING: " + clean_path)
		return
	if persist_on_scene_change:
		var tree: SceneTree = get_tree()
		if tree == null or tree.root == null:
			return
		var transient_player := AudioStreamPlayer.new()
		transient_player.name = "MenuTransientSfxPlayer"
		transient_player.stream = stream
		transient_player.finished.connect(Callable(transient_player, "queue_free"))
		tree.root.add_child(transient_player)
		transient_player.play()
		return
	if _menu_sfx_player == null or not is_instance_valid(_menu_sfx_player):
		_menu_sfx_player = AudioStreamPlayer.new()
		_menu_sfx_player.name = "MenuSfxPlayer"
		add_child(_menu_sfx_player)
	_menu_sfx_player.stop()
	_menu_sfx_player.stream = stream
	_menu_sfx_player.play()

func _play_store_purchase_sfx() -> void:
	_play_menu_sfx(STORE_PURCHASE_SOUND_PATH)

func _play_mm_base_drop_sfx() -> void:
	_play_menu_sfx(MM_BASE_DROP_SOUND_PATH)

func _play_matchmaker_sfx() -> void:
	_play_menu_sfx(MATCHMAKER_SOUND_PATH, true)

func _play_jukebox_play_sfx() -> void:
	_play_menu_sfx(JUKEBOX_PLAY_SOUND_PATH, true)

func _play_buff_equip_sfx() -> void:
	_play_menu_sfx(BUFF_EQUIP_SOUND_PATH)

func _is_menu_boot_sfx_enabled() -> bool:
	return _is_menu_sfx_enabled()

func _is_menu_sfx_enabled() -> bool:
	if ProfileManager == null:
		return true
	if ProfileManager.has_method("is_audio_enabled") and not bool(ProfileManager.call("is_audio_enabled")):
		return false
	if ProfileManager.has_method("is_sfx_enabled") and not bool(ProfileManager.call("is_sfx_enabled")):
		return false
	return true

func _apply_pending_jukebox_reopen_request() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var should_reopen: bool = bool(tree.get_meta(TREE_META_REOPEN_JUKEBOX_ON_READY, false))
	var restore_state: Dictionary = {}
	var restore_any: Variant = tree.get_meta(TREE_META_REOPEN_JUKEBOX_STATE, {})
	if typeof(restore_any) == TYPE_DICTIONARY:
		restore_state = restore_any as Dictionary
	if tree.has_meta(TREE_META_REOPEN_JUKEBOX_ON_READY):
		tree.remove_meta(TREE_META_REOPEN_JUKEBOX_ON_READY)
	if tree.has_meta(TREE_META_REOPEN_JUKEBOX_STATE):
		tree.remove_meta(TREE_META_REOPEN_JUKEBOX_STATE)
	if not should_reopen:
		return
	_open_jukebox_panel()
	if _jukebox_panel != null and _jukebox_panel.has_method("restore_runtime_state"):
		_jukebox_panel.call("restore_runtime_state", restore_state)

func _apply_pending_stage_leaderboard_request() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var should_open: bool = bool(tree.get_meta(TREE_META_PENDING_STAGE_LEADERBOARD, false))
	var context: Dictionary = {}
	var context_any: Variant = tree.get_meta(TREE_META_PENDING_STAGE_LEADERBOARD_CONTEXT, {})
	if typeof(context_any) == TYPE_DICTIONARY:
		context = context_any as Dictionary
	if tree.has_meta(TREE_META_PENDING_STAGE_LEADERBOARD):
		tree.remove_meta(TREE_META_PENDING_STAGE_LEADERBOARD)
	if tree.has_meta(TREE_META_PENDING_STAGE_LEADERBOARD_CONTEXT):
		tree.remove_meta(TREE_META_PENDING_STAGE_LEADERBOARD_CONTEXT)
	if not should_open:
		return
	var map_count: int = maxi(1, int(context.get("map_count", 5)))
	var scope: String = str(context.get("scope", "WEEKLY")).strip_edges().to_upper()
	if scope.is_empty():
		scope = "WEEKLY"
	var paid: bool = bool(context.get("paid", false))
	var denomination: int = maxi(0, int(context.get("denomination", 0)))
	var player_id: String = str(context.get("player_id", "")).strip_edges()
	var run_id: String = str(context.get("run_id", "")).strip_edges()
	_open_async_stage_contest_leaderboard(map_count, scope, paid, denomination, player_id, run_id)
	if status_label != null:
		status_label.text = "%s Stage Race leaderboard opened." % scope.capitalize()

func _process(_delta: float) -> void:
	_sync_main_art_shroud()
	_refresh_open_free_roll_game_hub_if_stale()
	_refresh_profile_handle_labels()

func _sync_main_art_shroud() -> void:
	var should_shroud: bool = _has_open_main_menu_surface()
	if should_shroud == _main_art_shroud_active:
		return
	_main_art_shroud_active = should_shroud
	if main_hex_background != null:
		main_hex_background.visible = should_shroud
	if platform_dimmer != null:
		platform_dimmer.visible = should_shroud

func _has_open_main_menu_surface() -> bool:
	if onboarding_overlay != null and onboarding_overlay.visible:
		return true
	if dash_panel != null and dash_panel.visible:
		return true
	if async_panel != null and async_panel.visible:
		return true
	if _entry_route_modal != null and is_instance_valid(_entry_route_modal):
		return true
	if _hive_dropdown_open:
		return true
	if _play_mode_select != null and is_instance_valid(_play_mode_select) and _play_mode_select.visible:
		return true
	if _vs_lobby != null and is_instance_valid(_vs_lobby) and _vs_lobby.visible:
		return true
	if _time_puzzle_lobby != null and is_instance_valid(_time_puzzle_lobby) and _time_puzzle_lobby.visible:
		return true
	if _swarm_pass_panel != null and is_instance_valid(_swarm_pass_panel) and _swarm_pass_panel.visible:
		return true
	if _battle_pass_panel != null and is_instance_valid(_battle_pass_panel) and _battle_pass_panel.visible:
		return true
	if _rank_panel != null and is_instance_valid(_rank_panel) and _rank_panel.visible:
		return true
	if _rank_context_panel != null and is_instance_valid(_rank_context_panel) and _rank_context_panel.visible:
		return true
	return false

func _refresh_open_free_roll_game_hub_if_stale() -> void:
	if _game_hub_live_refresh_pending:
		return
	if _entry_route_modal == null or not is_instance_valid(_entry_route_modal):
		return
	var title_label: Label = _entry_route_modal.get_node_or_null("EntryScroll/EntryBody/EntryTitle") as Label
	if title_label == null:
		return
	if title_label.text.strip_edges().to_upper() != "FREE ROLL":
		return
	var current_version: int = int(_entry_route_modal.get_meta("sf_free_layout_version", -1))
	if current_version == GAME_HUB_FREE_LAYOUT_VERSION:
		return
	_game_hub_live_refresh_pending = true
	call_deferred("_rebuild_open_free_roll_game_hub")

func _rebuild_open_free_roll_game_hub() -> void:
	_game_hub_live_refresh_pending = false
	if _entry_route_modal == null or not is_instance_valid(_entry_route_modal):
		return
	var title_label: Label = _entry_route_modal.get_node_or_null("EntryScroll/EntryBody/EntryTitle") as Label
	if title_label == null:
		return
	if title_label.text.strip_edges().to_upper() != "FREE ROLL":
		return
	_close_entry_route_modal()
	_open_game_hub(false, 0)

func _input(event: InputEvent) -> void:
	_refresh_open_free_roll_game_hub_if_stale()
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
	var shift_down: float = minf(
		STORE_WINDOW_SHIFT_DOWN_PX,
		maxf(0.0, (panel_size.y - target_size.y) * 0.5 - STORE_WINDOW_INSET_BOTTOM)
	)
	dash_store_panel.offset_left = -target_size.x * 0.5
	dash_store_panel.offset_top = -target_size.y * 0.5 + shift_down
	dash_store_panel.offset_right = target_size.x * 0.5
	dash_store_panel.offset_bottom = target_size.y * 0.5 + shift_down
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
		var background_node: Node = _load_packed_scene(HEX_SEAM_BACKGROUND_SCENE_PATH).instantiate()
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
		window_ref.content_scale_factor = clampf(scale_factor, 0.7, 1.1)

func _on_onboarding_done() -> void:
	onboarding_overlay.visible = false
	_refresh_scholastic_dash_visibility()
	_maybe_show_sfa_join_cta(true)

func _load_fonts() -> void:
	_font_regular = UITypography.regular_font()
	_font_semibold = UITypography.semibold_font()
	_font_free_roll_atlas = UITypography.free_roll_font()

func _style_labels() -> void:
	_apply_display_label($TopBar/RankLabel, 16, _font_regular, 16)
	if _tier_widget != null and _tier_widget.has_method("apply_label_fonts"):
		_tier_widget.call("apply_label_fonts", _font_semibold, _scaled_ui_font_size(8))
	_apply_display_label($TopBar/HoneyLabel, 16, _font_regular, 16)
	_apply_honey_label_shader($TopBar/HoneyLabel)
	if _honey_widget != null and _honey_widget.has_method("apply_label_font"):
		_honey_widget.call("apply_label_font", _font_regular, _scaled_ui_font_size(17))
	_apply_display_label($DashPanel/DashTopBar/DashRankLabel, 16, _font_regular, 16)
	_apply_display_label($DashPanel/DashTopBar/DashHoneyLabel, 17, _font_regular, 17)
	_apply_honey_label_shader($DashPanel/DashTopBar/DashHoneyLabel)
	if brand_title_label != null:
		if not _apply_free_roll_atlas_font(brand_title_label, 21):
			_apply_font(brand_title_label, _font_semibold, 24)
		_apply_swarmfront_title_shader(brand_title_label)
		_suppress_legacy_brand_banner()
	if welcome_handle_label != null:
		_apply_font(welcome_handle_label, _font_semibold, 16)
		welcome_handle_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
		welcome_handle_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
		welcome_handle_label.add_theme_constant_override("shadow_offset_x", 0)
		welcome_handle_label.add_theme_constant_override("shadow_offset_y", 2)
	if dash_handle_label != null:
		_apply_font(dash_handle_label, _font_semibold, 18)
		dash_handle_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
		dash_handle_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
		dash_handle_label.add_theme_constant_override("shadow_offset_x", 0)
		dash_handle_label.add_theme_constant_override("shadow_offset_y", 2)
	_apply_display_label($HeroPanel/HeroVBox/HeroTitle, 22, _font_semibold, 24)
	_apply_font($HeroPanel/HeroVBox/HeroSub, _font_regular, 16)
	_apply_display_label($DashPanel/DashRoot/MatchHistoryPanel/MatchCenter/MatchVBox/MatchHeader, 16, _font_semibold, 18)
	_apply_display_label($DashPanel/DashRoot/BadgesPanel/BadgesVBox/BadgesHeader, 16, _font_semibold, 18)
	for i in range(1, 6):
		var row_path := "DashPanel/DashRoot/MatchHistoryPanel/MatchCenter/MatchVBox/MatchList/MatchRow%d" % i
		_apply_font(get_node("%s/MatchTitle" % row_path), _font_regular, 15)
		_apply_font(get_node("%s/MatchResult" % row_path), _font_semibold, 14)
		_apply_font(get_node("%s/MatchEff" % row_path), _font_regular, 14)
	_apply_display_label($DashPanel/DashStatsPanel/StatsVBox/StatsTitle, 18, _font_semibold, 20)
	_apply_display_label($DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisTitle, 18, _font_semibold, 20)
	_apply_display_label($DashPanel/DashReplayPanel/ReplayVBox/ReplayTitle, 18, _font_semibold, 20)
	_apply_display_label($DashPanel/DashBuffsPanel/BuffsVBox/BuffsTitle, 22, _font_semibold, BUFF_UI_TITLE_FONT_SIZE)
	_apply_display_label($DashPanel/DashBadgesPanel/BadgesCollectionVBox/BadgesTitle, 18, _font_semibold, 20)
	_apply_font($DashPanel/DashStatsPanel/StatsVBox/StatsSub, _font_regular, 14)
	_apply_font($DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisSub, _font_regular, 14)
	_apply_font($DashPanel/DashReplayPanel/ReplayVBox/ReplaySub, _font_regular, 14)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsSub, _font_regular, BUFF_UI_BODY_FONT_SIZE)
	_apply_font($DashPanel/DashBadgesPanel/BadgesCollectionVBox/BadgesSub, _font_regular, 14)
	_apply_font($DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisBody/AnalysisBodyVBox/AnalysisBodyHeader, _font_semibold, 14)
	for i in range(1, 6):
		var analysis_line := "DashPanel/DashAnalysisPanel/AnalysisVBox/AnalysisBody/AnalysisBodyVBox/AnalysisLine%d" % i
		_apply_font(get_node(analysis_line), _font_regular, 14)
	_apply_font($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayControlsPanel/ReplayControlsVBox/ReplayControlsHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTopRow/ReplayInfoPanel/ReplayInfoVBox/ReplayInfoHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox/ReplayTimelineHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayNote, _font_regular, 12)
	_apply_display_label($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel/BuffsLoadoutVBox/BuffsLoadoutHeader, 15, _font_semibold, BUFF_UI_HEADER_FONT_SIZE)
	_apply_display_label($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryHeader, 15, _font_semibold, BUFF_UI_HEADER_FONT_SIZE)
	_apply_display_label($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailHeader, 15, _font_semibold, BUFF_UI_HEADER_FONT_SIZE)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailName, _font_semibold, BUFF_UI_HEADER_FONT_SIZE)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailDesc, _font_regular, BUFF_UI_BUTTON_FONT_SIZE)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsDetailPanel/BuffsDetailVBox/BuffsDetailMeta, _font_regular, BUFF_UI_SMALL_FONT_SIZE)
	_apply_font($DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsFooter, _font_regular, BUFF_UI_BODY_FONT_SIZE)
	_apply_display_label(buffs_mode_vs_button, 15, _font_semibold, BUFF_UI_BUTTON_FONT_SIZE)
	_apply_display_label(buffs_mode_async_button, 15, _font_semibold, BUFF_UI_BUTTON_FONT_SIZE)
	_apply_display_label($DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveTitle, 18, _font_semibold, 20)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveSub, _font_regular, 13)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveMetricsRow/HiveHoneyLabel, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveMetricsRow/HiveTotalHoneyLabel, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveOverviewHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivityHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsHeader, _font_semibold, 14)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HivePinnedNotice, _font_regular, 12)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm1, _font_regular, 13)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm2, _font_regular, 13)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm3, _font_regular, 13)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm4, _font_regular, 13)
	_apply_font($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveFooter, _font_regular, 12)
	_apply_display_label($DashPanel/DashStorePanel/StoreVBox/StoreTitle, 18, _font_semibold, 20)
	_apply_font($DashPanel/DashStorePanel/StoreVBox/StoreSub, _font_regular, 14)
	_apply_display_label($DashPanel/DashSettingsPanel/SettingsVBox/SettingsTitle, 60, _font_semibold, 72)
	_apply_font($DashPanel/DashSettingsPanel/SettingsVBox/SettingsSub, _font_regular, 48)
	_apply_font($DashPanel/DashStorePanel/StoreVBox/StoreBody/StoreBodyVBox/StoreLanding/StoreLandingVBox/StoreLandingHeader, _font_semibold, 14)
	_apply_font(store_category_header, _font_semibold, 16)
	_apply_font(store_category_sub, _font_regular, 13)
	_apply_font(store_prefs_label, _font_regular, 13)
	_apply_font(store_category_back, _font_regular, 12)
	_apply_font(store_prefs_toggle, _font_regular, 12)
	_apply_display_label($AsyncPanel/AsyncVBox/AsyncTitle, 18, _font_semibold, 20)
	_apply_font($AsyncPanel/AsyncVBox/AsyncSub, _font_regular, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncQueuePanel/AsyncQueueVBox/AsyncQueueHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncLeaderboardPanel/AsyncLeaderboardVBox/AsyncLeaderboardHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncTopRow/AsyncSeasonPanel/AsyncSeasonVBox/AsyncSeasonHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsSub, _font_regular, 13)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncRulesHeader, _font_semibold, 14)
	_apply_font($AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncFooter, _font_regular, 12)
	_apply_display_label($AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyTitle, 18, _font_semibold, 20)
	_apply_font($AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklySub, _font_regular, 14)
	_apply_font($AsyncPanel/AsyncWeeklyPanel/WeeklyVBox/WeeklyBody/WeeklyBodyVBox/WeeklyListHeader, _font_semibold, 14)
	_apply_display_label($AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyTitle, 18, _font_semibold, 20)
	_apply_font($AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlySub, _font_regular, 14)
	_apply_font($AsyncPanel/AsyncMonthlyPanel/MonthlyVBox/MonthlyBody/MonthlyBodyVBox/MonthlyListHeader, _font_semibold, 14)
	_apply_display_label($AsyncPanel/AsyncYearlyPanel/YearlyVBox/YearlyTitle, 18, _font_semibold, 20)
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
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember5",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember6",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember7",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember8",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity1",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity2",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity3",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity4",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm1",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm2",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm3",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm4"
	]:
		_apply_font(get_node(label_path), _font_regular, 13)
	for label in replay_info_lines:
		_apply_font(label, _font_regular, 13)
	for label in replay_timeline_times:
		_apply_font(label, _font_semibold, 12)
	for label in replay_timeline_events:
		_apply_font(label, _font_regular, 12)
	for button in buffs_slot_buttons:
		_apply_font(button, _font_regular, BUFF_UI_BUTTON_FONT_SIZE)
	for button in buffs_library_buttons:
		_apply_font(button, _font_regular, BUFF_UI_BUTTON_FONT_SIZE)
	for button in buffs_detail_buttons:
		_apply_display_label(button, 14, _font_regular, BUFF_UI_BUTTON_FONT_SIZE)
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
		buffs_body_vbox.add_theme_constant_override("separation", 14)
	var hive_body_vbox: VBoxContainer = $DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox
	hive_body_vbox.add_theme_constant_override("separation", 16)
	var hive_vbox: VBoxContainer = $DashPanel/DashHivePanel/HiveVBox
	hive_vbox.add_theme_constant_override("separation", 14)
	var hive_header_vbox: VBoxContainer = $DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox
	hive_header_vbox.add_theme_constant_override("separation", 6)
	var hive_metrics_row: HBoxContainer = $DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveMetricsRow
	hive_metrics_row.add_theme_constant_override("separation", 12)
	var hive_top_row: HBoxContainer = $DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow
	hive_top_row.add_theme_constant_override("separation", 14)
	var hive_roster_list: VBoxContainer = $DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList
	hive_roster_list.add_theme_constant_override("separation", 6)
	var hive_comms_list: VBoxContainer = $DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList
	hive_comms_list.add_theme_constant_override("separation", 8)
	for label in [
		$DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveSub,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanName,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanTag,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanLeague,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanMembers,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity1,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity2,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity3,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HivePinnedNotice,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm1,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm2,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm3,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm4
	]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(0.0, 42.0)
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
		menu_battle_pass_button,
		menu_jukebox_button
	]:
		_apply_font(button, _font_regular, 14)
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.35, 0.38, 0.45), Color(0.9, 0.9, 0.9))
	_apply_free_roll_atlas_font(menu_free_roll_button, 14)
	if menu_unused_button != null:
		menu_unused_button.visible = true
		menu_unused_button.text = "TOURNAMENTS"
		_apply_font(menu_unused_button, _font_regular, 14)
		_style_button(menu_unused_button, Color(0.12, 0.13, 0.16), Color(0.78, 0.62, 0.24), Color(0.96, 0.92, 0.80))
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
	_style_dash_top_tabs()

func _style_dash_top_tabs() -> void:
	_ensure_friends_tab()
	if dash_tabs != null:
		dash_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
		dash_tabs.add_theme_constant_override("separation", 12)
	for button in [dash_garage_tab, dash_buffs_tab, dash_achievements_tab, _dash_scholastic_tab, dash_settings_tab, _dash_friends_tab]:
		if button == null:
			continue
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size = Vector2(180.0, 44.0)
		_apply_font(button, _font_semibold, 12)
	_refresh_dash_top_tabs()

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
	_style_panel($DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel, Color(0.08, 0.09, 0.12, 0.94), Color(0.42, 0.44, 0.52, 0.72))
	_style_panel($DashPanel/DashHivePanel/HiveVBox/HiveBody, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
	_style_panel($DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel, Color(0.08, 0.09, 0.12, 0.9), Color(0.35, 0.36, 0.44, 0.6))
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
	menu_jukebox_button.pressed.connect(_open_jukebox_from_menu_button)
	if menu_unused_button != null:
		menu_unused_button.pressed.connect(_open_tournament_panel)
	hive_button.pressed.connect(_toggle_hive_dropdown)
	dash_tab.pressed.connect(_toggle_dash)
	dash_garage_tab.pressed.connect(func() -> void:
		_set_dash_top_tab(DASH_HERO_TAB_GARAGE)
	)
	dash_buffs_tab.pressed.connect(func() -> void:
		_set_dash_top_tab(DASH_HERO_TAB_BUFFS)
	)
	dash_achievements_tab.pressed.connect(func() -> void:
		_set_dash_top_tab(DASH_HERO_TAB_ACHIEVEMENTS)
	)
	dash_settings_tab.pressed.connect(func() -> void:
		_open_dash_panel(dash_settings_panel)
	)
	dash_hex_buffs.pressed.connect(func(): _open_dash_panel(dash_buffs_panel))
	dash_hex_store.pressed.connect(func(): _open_dash_panel(dash_store_panel))
	dash_hex_hive.pressed.connect(func(): _open_dash_panel(dash_hive_panel))
	if hero_panel != null:
		hero_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		hero_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hero_panel.tooltip_text = "Play or pause last match replay"
		if not hero_panel.gui_input.is_connected(_on_last_match_replay_hero_gui_input):
			hero_panel.gui_input.connect(_on_last_match_replay_hero_gui_input)
	for idx in range(replay_controls_buttons.size()):
		var replay_button: Button = replay_controls_buttons[idx] as Button
		if replay_button == null:
			continue
		var replay_control_cb: Callable = Callable(self, "_on_replay_control_pressed").bind(idx)
		if not replay_button.pressed.is_connected(replay_control_cb):
			replay_button.pressed.connect(replay_control_cb)
	_wire_match_rows()
	_wire_badges()
	dash_stats_close.pressed.connect(func(): _close_dash_panel(dash_stats_panel))
	dash_analysis_close.pressed.connect(func(): _close_dash_panel(dash_analysis_panel))
	dash_replay_close.pressed.connect(func(): _close_dash_panel(dash_replay_panel))
	dash_buffs_close.pressed.connect(_on_dash_buffs_close_pressed)
	dash_hive_close.pressed.connect(_on_dash_hive_close_pressed)
	for idx in range(hive_action_buttons.size()):
		var hive_button: Button = hive_action_buttons[idx] as Button
		if hive_button == null:
			continue
		hive_button.pressed.connect(_on_hive_action_pressed.bind(idx))
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
		"Ladder: 5 Map Stage Race",
		"Ladder: Capture the Flag"
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
		if i == 5:
			async_ladder_buttons[i].pressed.connect(func(): _on_async_capture_flag_selected(false))
			continue
		var label: String = ladder_labels[i]
		async_ladder_buttons[i].pressed.connect(func(): _stub_action(label))
	var free_labels: PackedStringArray = PackedStringArray([
		"Free Play: Miss n Outs",
		"Free Play: Timed Race (3-map sync start)",
		"Free Play: Timed Race (5-map sync start)",
		"Free Play: 3 Map Stage Race",
		"Free Play: 5 Map Stage Race",
		"Free Play: Capture the Flag"
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
		if i == 5:
			async_free_buttons[i].pressed.connect(func(): _on_async_capture_flag_selected(true))
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
		dash_hexes.visible = false
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
	if _dash_hex_jukebox != null:
		_dash_hex_jukebox.text = "JUKE"
		_dash_hex_jukebox.font = _font_semibold
		_dash_hex_jukebox.font_size = _scaled_ui_font_size(14)
		_dash_hex_jukebox.fill_color = Color(0.16, 0.16, 0.2)
		_dash_hex_jukebox.border_color = Color(0.7, 0.72, 0.8)
		_dash_hex_jukebox.text_color = Color(0.92, 0.94, 0.98)
		_dash_hex_jukebox.sprite_key = DASH_HEX_JUKEBOX_KEY
		_dash_hex_jukebox.custom_minimum_size = dash_hex_size
		_apply_black_key_to_hex_button(_dash_hex_jukebox)
		_dash_hex_jukebox.queue_redraw()
	if _dash_hex_async_contest != null:
		_dash_hex_async_contest.text = "ASYNC"
		_dash_hex_async_contest.font = _font_semibold
		_dash_hex_async_contest.font_size = _scaled_ui_font_size(13)
		_dash_hex_async_contest.fill_color = Color(0.16, 0.16, 0.2)
		_dash_hex_async_contest.border_color = Color(0.7, 0.72, 0.8)
		_dash_hex_async_contest.text_color = Color(0.92, 0.94, 0.98)
		_dash_hex_async_contest.sprite_key = DASH_HEX_JUKEBOX_KEY
		_dash_hex_async_contest.custom_minimum_size = dash_hex_size
		_apply_black_key_to_hex_button(_dash_hex_async_contest)
		_dash_hex_async_contest.queue_redraw()

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
	var top_offset: float = top_bar.offset_top if top_bar != null else 0.0
	return maxf(_main_usable_top_px(), top_offset + hive_button.offset_bottom + HIVE_DROPDOWN_TOP_GAP)

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

	_rebuild_hive_dropdown_options(false)

func _add_hive_dropdown_label(body: VBoxContainer, text: String, font_size: int, centered: bool = true) -> Label:
	var title: Label = Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	body.add_child(title)
	_apply_font(title, _font_semibold if font_size >= 16 else _font_regular, font_size)
	return title

func _add_hive_dropdown_button(body: VBoxContainer, text: String, action: String, primary: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 32.0)
	button.pressed.connect(func(): _on_hive_dropdown_action(action))
	body.add_child(button)
	_apply_font(button, _font_regular, 13)
	if primary:
		_style_button(button, Color(0.15, 0.11, 0.05), Color(0.84, 0.66, 0.24), Color(0.98, 0.93, 0.80))
	else:
		_style_button(button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	return button

func _rebuild_hive_dropdown_options(is_member: bool = false) -> void:
	if _hive_dropdown_panel == null:
		return
	var body: VBoxContainer = _hive_dropdown_panel.get_node_or_null("HiveDropdownVBox") as VBoxContainer
	if body == null:
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_add_hive_dropdown_label(body, "HIVE MENU", 16)
	if is_member:
		_add_hive_dropdown_label(body, "Opening your hive dashboard.", 12)
		_add_hive_dropdown_button(body, "OPEN HIVE DASHBOARD", "dashboard", true)
	else:
		_add_hive_dropdown_label(body, "Join a hive or start your own.", 12)
		_add_hive_dropdown_button(body, "CREATE A HIVE", "create", true)
		_add_hive_dropdown_button(body, "BROWSE HIVES", "browse")
		_add_hive_dropdown_button(body, "MY INVITES", "my_invites")
		_add_hive_dropdown_button(body, "HIVE RANKINGS", "ladder")
	var close_button: Button = Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0.0, 30.0)
	close_button.pressed.connect(func(): _set_hive_dropdown_open(false))
	body.add_child(close_button)
	_apply_font(close_button, _font_regular, 12)
	_style_button(close_button, Color(0.14, 0.12, 0.08), Color(0.72, 0.6, 0.28), Color(0.96, 0.92, 0.8))

func _on_hive_dropdown_action(action: String) -> void:
	_set_hive_dropdown_open(false)
	match action:
		"create":
			_open_hive_create_dialog()
		"browse":
			_open_hive_browse_dialog()
		"my_invites":
			_open_hive_my_invites_dialog()
		"applications":
			_open_hive_applications_dialog()
		"member_actions":
			_open_hive_member_actions_dialog()
		"dashboard":
			_open_dash_panel_from_menu(dash_hive_panel)
		"chat":
			_open_hive_comms_access()
		"ladder":
			_open_hive_rankings_dialog()
		_:
			pass

func _ensure_hive_dashboard_menu_row() -> HBoxContainer:
	var header_vbox: VBoxContainer = $DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox
	var existing: HBoxContainer = header_vbox.get_node_or_null("HiveDashboardMenuRow") as HBoxContainer
	if existing != null:
		return existing
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "HiveDashboardMenuRow"
	row.layout_mode = 2
	row.add_theme_constant_override("separation", 8)
	header_vbox.add_child(row)
	_add_hive_dashboard_menu_button(row, "Applications", "applications")
	_add_hive_dashboard_menu_button(row, "Member Actions", "member_actions")
	_add_hive_dashboard_menu_button(row, "Hive Chat", "chat")
	_add_hive_dashboard_menu_button(row, "Hive Rankings", "ladder")
	return row

func _add_hive_dashboard_menu_button(row: HBoxContainer, text: String, action: String) -> Button:
	var button: Button = Button.new()
	button.name = "%sButton" % text.replace(" ", "")
	button.text = text.to_upper()
	button.layout_mode = 2
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 34.0)
	button.set_meta("hive_dashboard_action", action)
	button.pressed.connect(func(): _on_hive_dashboard_menu_action(action))
	row.add_child(button)
	_apply_font(button, _font_regular, 12)
	_style_button(button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	return button

func _refresh_hive_dashboard_menu_row(member_view: bool) -> void:
	var row: HBoxContainer = _ensure_hive_dashboard_menu_row()
	row.visible = member_view
	if not member_view:
		return
	var role_key: String = _current_hive_role_key()
	var is_officer: bool = role_key == "queen" or role_key == "soldier"
	for child in row.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var action: String = str(button.get_meta("hive_dashboard_action", ""))
		button.visible = action != "applications" or is_officer
		button.disabled = false

func _on_hive_dashboard_menu_action(action: String) -> void:
	match action:
		"applications":
			_open_hive_applications_dialog()
		"member_actions":
			_open_hive_member_actions_dialog()
		"chat":
			_open_hive_comms_access()
		"ladder":
			_open_hive_rankings_dialog()
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
		_rebuild_hive_dropdown_options(_player_has_hive_membership())
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
	if _player_has_hive_membership():
		_hide_hive_dropdown_immediate()
		_sync_hive_panel_profile_from_hive_state()
		_open_hive_panel()
		return
	_play_mm_base_drop_sfx()
	_set_hive_dropdown_open(not _hive_dropdown_open)

func _hide_hive_dropdown_immediate() -> void:
	if _hive_dropdown_tween != null and _hive_dropdown_tween.is_running():
		_hive_dropdown_tween.kill()
	if _hive_dropdown_panel != null:
		_hive_dropdown_set_top(_hive_dropdown_closed_top())
		_hive_dropdown_panel.visible = false
	_hive_dropdown_open = false

func _close_hive_dialogs_to_main_menu() -> void:
	for dialog in [
		_hive_create_dialog,
		_hive_invite_dialog,
		_hive_pending_dialog,
		_hive_leave_dialog,
		_hive_browse_dialog,
		_hive_my_invites_dialog,
		_hive_applications_dialog,
		_hive_member_actions_dialog,
			_hive_remove_member_dialog,
			_hive_post_dialog,
			_hive_pin_dialog,
			_hive_about_dialog,
			_hive_rankings_dialog,
			_hive_tournaments_dialog
		]:
		if dialog != null and is_instance_valid(dialog):
			dialog.hide()
	_hive_remove_member_target = {}
	_on_dash_hive_close_pressed()

func _on_hive_dialog_custom_action(action: StringName) -> void:
	if String(action) != "main_menu":
		return
	_close_hive_dialogs_to_main_menu()

func _wire_hive_dialog_main_menu(dialog: AcceptDialog) -> void:
	if dialog == null:
		return
	var main_menu_button: Button = dialog.add_button("MAIN MENU", false, "main_menu")
	main_menu_button.custom_minimum_size = Vector2(178.0, 62.0)
	_apply_font(main_menu_button, _font_regular, 16)
	_style_button(main_menu_button, Color(0.12, 0.13, 0.16), Color(0.48, 0.50, 0.58), Color(0.96, 0.96, 0.96))
	if not dialog.custom_action.is_connected(_on_hive_dialog_custom_action):
		dialog.custom_action.connect(_on_hive_dialog_custom_action)

func _ensure_hive_create_dialog() -> void:
	if _hive_create_dialog != null and is_instance_valid(_hive_create_dialog):
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.name = "HiveCreateDialog"
	dialog.title = "Create Hive"
	dialog.exclusive = true
	dialog.min_size = Vector2i(HIVE_CREATE_DIALOG_WIDTH, HIVE_CREATE_DIALOG_HEIGHT)
	_style_hive_create_dialog(dialog)
	add_child(dialog)
	_hive_create_dialog = dialog

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "HiveCreateVBox"
	body.custom_minimum_size = Vector2(680.0, 198.0)
	body.add_theme_constant_override("separation", 18)
	dialog.add_child(body)

	var desc: Label = Label.new()
	desc.text = "Name your hive. You can only create a limited number of hives per time window."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(desc)
	_apply_font(desc, _font_regular, 21)
	desc.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.95))

	var input_row: HBoxContainer = HBoxContainer.new()
	input_row.name = "HiveCreateInputRow"
	input_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_theme_constant_override("separation", 10)
	body.add_child(input_row)

	var name_input: LineEdit = LineEdit.new()
	name_input.placeholder_text = "Enter hive name"
	name_input.max_length = 24
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.custom_minimum_size = Vector2(0.0, 76.0)
	name_input.virtual_keyboard_enabled = true
	input_row.add_child(name_input)
	_apply_font(name_input, _font_regular, 27)
	_style_hive_line_edit(name_input)
	_hive_create_name_input = name_input

	var done_button: Button = Button.new()
	done_button.name = "HiveCreateDoneButton"
	done_button.text = "DONE"
	done_button.custom_minimum_size = Vector2(160.0, 76.0)
	input_row.add_child(done_button)
	_apply_font(done_button, _font_semibold, 17)
	_style_button(done_button, Color(0.12, 0.13, 0.16), Color(0.64, 0.66, 0.76), Color(0.96, 0.96, 0.96))
	_hive_create_done_button = done_button

	dialog.get_ok_button().text = "CREATE"
	dialog.get_ok_button().custom_minimum_size = Vector2(190.0, 64.0)
	_apply_font(dialog.get_ok_button(), _font_semibold, 17)
	_style_button(dialog.get_ok_button(), Color(0.15, 0.11, 0.05), Color(0.84, 0.66, 0.24), Color(0.98, 0.93, 0.80))
	_wire_hive_dialog_main_menu(dialog)
	if dialog.get_cancel_button() != null:
		dialog.get_cancel_button().text = "CLOSE"
		dialog.get_cancel_button().custom_minimum_size = Vector2(178.0, 64.0)
		_apply_font(dialog.get_cancel_button(), _font_regular, 17)
		_style_button(dialog.get_cancel_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	if not dialog.confirmed.is_connected(_submit_hive_create):
		dialog.confirmed.connect(_submit_hive_create)
	if not name_input.text_submitted.is_connected(_on_hive_create_name_submitted):
		name_input.text_submitted.connect(_on_hive_create_name_submitted)
	if not done_button.pressed.is_connected(_on_hive_create_done_pressed):
		done_button.pressed.connect(_on_hive_create_done_pressed)

func _style_hive_create_dialog(dialog: AcceptDialog) -> void:
	if dialog == null:
		return
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.048, 0.060, 0.98)
	panel_style.border_color = Color(0.92, 0.74, 0.26, 0.70)
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 28
	panel_style.content_margin_bottom = 24
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.add_theme_color_override("title_color", Color(0.98, 0.93, 0.80, 1.0))
	if _font_semibold != null:
		dialog.add_theme_font_override("title_font", _font_semibold)
	dialog.add_theme_font_size_override("title_font_size", 20)

func _style_hive_line_edit(input: LineEdit) -> void:
	if input == null:
		return
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.11, 0.14, 0.96)
	normal.border_color = Color(0.72, 0.74, 0.84, 0.88)
	normal.border_width_bottom = 2
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	input.add_theme_stylebox_override("normal", normal)
	input.add_theme_stylebox_override("focus", normal.duplicate())
	input.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96, 1.0))
	input.add_theme_color_override("font_placeholder_color", Color(0.72, 0.74, 0.80, 0.70))

func _style_hive_text_edit(input: TextEdit) -> void:
	if input == null:
		return
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.11, 0.14, 0.96)
	normal.border_color = Color(0.72, 0.74, 0.84, 0.88)
	normal.border_width_bottom = 2
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 16
	normal.content_margin_bottom = 16
	var focus: StyleBoxFlat = normal.duplicate()
	focus.border_color = Color(0.92, 0.74, 0.26, 0.90)
	input.add_theme_stylebox_override("normal", normal)
	input.add_theme_stylebox_override("focus", focus)
	input.add_theme_stylebox_override("read_only", normal.duplicate())
	input.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96, 1.0))
	input.add_theme_color_override("font_readonly_color", Color(0.78, 0.80, 0.86, 0.76))

func _hive_create_popup_size() -> Vector2i:
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: int = mini(HIVE_CREATE_DIALOG_WIDTH, maxi(360, int(viewport_size.x) - HIVE_CREATE_DIALOG_MOBILE_MARGIN * 2))
	var height: int = HIVE_CREATE_DIALOG_HEIGHT
	return Vector2i(width, height)

func _hive_about_popup_size() -> Vector2i:
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: int = mini(HIVE_TEXT_DIALOG_WIDTH, maxi(380, int(viewport_size.x) - HIVE_CREATE_DIALOG_MOBILE_MARGIN * 2))
	return Vector2i(width, HIVE_ABOUT_DIALOG_HEIGHT)

func _popup_hive_dialog_below_banner(dialog: Window, popup_size: Vector2i) -> void:
	if dialog == null:
		return
	dialog.popup_centered(popup_size)
	call_deferred("_place_hive_dialog_below_banner", dialog, popup_size)

func _place_hive_dialog_below_banner(dialog: Window, popup_size: Vector2i) -> void:
	if dialog == null or not is_instance_valid(dialog) or not dialog.visible:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var actual_size: Vector2i = dialog.size
	if actual_size.x <= 0 or actual_size.y <= 0:
		actual_size = popup_size
	var x: int = maxi(0, int((viewport_size.x - float(actual_size.x)) * 0.5))
	var desired_y: int = maxi(HIVE_DIALOG_BELOW_BANNER_MIN_TOP, int(viewport_size.y * HIVE_DIALOG_BELOW_BANNER_TOP_RATIO))
	var max_y: int = maxi(0, int(viewport_size.y) - actual_size.y - 24)
	dialog.position = Vector2i(x, mini(desired_y, max_y))

func _open_hive_create_dialog() -> void:
	_ensure_hive_create_dialog()
	if _hive_create_dialog == null:
		return
	if HiveClanState != null and HiveClanState.has_method("get_player_membership"):
		var membership: Dictionary = HiveClanState.call("get_player_membership") as Dictionary
		if not membership.is_empty():
			status_label.text = "Already in hive: %s." % str(membership.get("hive_name", ""))
			_open_dash_panel_from_menu(dash_hive_panel)
			return
	if _hive_create_name_input != null:
		_hive_create_name_input.text = ""
	_popup_hive_dialog_below_banner(_hive_create_dialog, _hive_create_popup_size())
	call_deferred("_focus_hive_create_name_input")

func _focus_hive_create_name_input() -> void:
	if _hive_create_dialog == null or not is_instance_valid(_hive_create_dialog):
		return
	if not _hive_create_dialog.visible:
		return
	if _hive_create_name_input == null:
		return
	_hive_create_name_input.grab_focus()

func _on_hive_create_done_pressed() -> void:
	if _hive_create_name_input != null:
		_hive_create_name_input.release_focus()
	DisplayServer.virtual_keyboard_hide()

func _on_hive_create_name_submitted(_text: String) -> void:
	DisplayServer.virtual_keyboard_hide()
	_submit_hive_create()

func _submit_hive_create() -> void:
	if HiveClanState == null or not HiveClanState.has_method("intent_create_hive"):
		status_label.text = "Hive system unavailable."
		return
	var hive_name: String = ""
	if _hive_create_name_input != null:
		hive_name = _hive_create_name_input.text.strip_edges()
	var result: Dictionary = HiveClanState.call("intent_create_hive", hive_name) as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"player_already_in_hive":
				var membership: Dictionary = result.get("membership", {}) as Dictionary
				status_label.text = "Already in hive: %s." % str(membership.get("hive_name", ""))
				_open_dash_panel_from_menu(dash_hive_panel)
			"hive_create_limit_reached":
				status_label.text = "Hive creation limit reached for now."
			"invalid_hive_name":
				status_label.text = "Enter a valid hive name."
			_:
				status_label.text = "Could not create hive."
		return
	_sync_hive_panel_profile_from_hive_state()
	if _hive_create_dialog != null:
		_hive_create_dialog.hide()
	if _hive_create_name_input != null:
		_hive_create_name_input.text = ""
	var hive: Dictionary = result.get("hive", {}) as Dictionary
	status_label.text = "Hive created: %s." % str(hive.get("name", ""))
	_open_dash_panel_from_menu(dash_hive_panel)

func _ensure_hive_invite_dialog() -> void:
	if _hive_invite_dialog != null and is_instance_valid(_hive_invite_dialog):
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "HiveInviteDialog"
	dialog.title = "Invite Player"
	dialog.exclusive = true
	dialog.min_size = Vector2i(520, 420)
	add_child(dialog)
	_hive_invite_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HiveInviteVBox"
	body.custom_minimum_size = Vector2(460.0, 320.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var desc := Label.new()
	desc.text = "Select a player who is not currently in a hive. Recent-opponent invites will plug into this same flow once the match UI passes the player id."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(desc)
	_apply_font(desc, _font_regular, 12)

	var meta := Label.new()
	meta.text = "Loading players..."
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(meta)
	_apply_font(meta, _font_regular, 11)
	_hive_invite_meta_label = meta

	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 8)
	body.add_child(sort_row)
	var sort_rank_button := Button.new()
	sort_rank_button.text = "SORT RANK"
	sort_rank_button.pressed.connect(func() -> void:
		_hive_invite_sort_mode = "rank"
		_refresh_hive_invite_dialog()
	)
	sort_row.add_child(sort_rank_button)
	_apply_font(sort_rank_button, _font_regular, 11)
	_style_button(sort_rank_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	var sort_honey_button := Button.new()
	sort_honey_button.text = "SORT HONEY"
	sort_honey_button.pressed.connect(func() -> void:
		_hive_invite_sort_mode = "honey"
		_refresh_hive_invite_dialog()
	)
	sort_row.add_child(sort_honey_button)
	_apply_font(sort_honey_button, _font_regular, 11)
	_style_button(sort_honey_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	var sort_tier_button := Button.new()
	sort_tier_button.text = "SORT TIER"
	sort_tier_button.pressed.connect(func() -> void:
		_hive_invite_sort_mode = "tier"
		_refresh_hive_invite_dialog()
	)
	sort_row.add_child(sort_tier_button)
	_apply_font(sort_tier_button, _font_regular, 11)
	_style_button(sort_tier_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))

	var bundle_select := OptionButton.new()
	bundle_select.custom_minimum_size = Vector2(460.0, 34.0)
	body.add_child(bundle_select)
	_apply_font(bundle_select, _font_regular, 12)
	_hive_invite_bundle_select = bundle_select

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(460.0, 190.0)
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	body.add_child(list)
	_apply_font(list, _font_regular, 12)
	_hive_invite_list = list

	dialog.get_ok_button().text = "SEND INVITE"
	_apply_font(dialog.get_ok_button(), _font_semibold, 12)
	_style_button(dialog.get_ok_button(), Color(0.15, 0.11, 0.05), Color(0.84, 0.66, 0.24), Color(0.98, 0.93, 0.80))
	_wire_hive_dialog_main_menu(dialog)
	if dialog.get_cancel_button() != null:
		dialog.get_cancel_button().text = "CLOSE"
		_apply_font(dialog.get_cancel_button(), _font_regular, 12)
		_style_button(dialog.get_cancel_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	if not dialog.confirmed.is_connected(_submit_hive_invite):
		dialog.confirmed.connect(_submit_hive_invite)

func _refresh_hive_invite_dialog() -> void:
	if _hive_invite_list == null or _hive_invite_meta_label == null:
		return
	_hive_invite_list.clear()
	_refresh_hive_invite_bundle_select()
	var hive_id: String = _current_hive_id()
	if hive_id.is_empty():
		_hive_invite_meta_label.text = "Join or create a hive first."
		return
	if HiveClanState == null or not HiveClanState.has_method("get_players_without_hive"):
		_hive_invite_meta_label.text = "Hive discovery unavailable."
		return
	var players: Array = HiveClanState.call("get_players_without_hive", 50) as Array
	players = _sort_hive_invite_players(players, _hive_invite_sort_mode)
	_hive_invite_meta_label.text = "Free agents available: %d | Sorted by %s" % [players.size(), _hive_invite_sort_mode]
	for player_any in players:
		if typeof(player_any) != TYPE_DICTIONARY:
			continue
		var player: Dictionary = player_any as Dictionary
		var label: String = "%s | #%d | %s | Honey %s" % [
			str(player.get("display_name", "Player")),
			int(player.get("rank_global", 0)),
			str(player.get("tier_id", "DRONE")),
			_format_number(int(round(float(player.get("wax_score", 0.0)))))
		]
		_hive_invite_list.add_item(label)
		var idx: int = _hive_invite_list.get_item_count() - 1
		_hive_invite_list.set_item_metadata(idx, player.duplicate(true))
	if players.is_empty():
		_hive_invite_meta_label.text = "No available players outside a hive right now."

func _refresh_hive_invite_bundle_select() -> void:
	if _hive_invite_bundle_select == null:
		return
	var selected_id: int = _hive_invite_bundle_select.get_selected_id()
	_hive_invite_bundle_select.clear()
	_hive_invite_bundle_select.add_item("No honey offer", 0)
	var bundles: Array = HiveClanState.call("get_invite_offer_bundles") as Array if HiveClanState != null and HiveClanState.has_method("get_invite_offer_bundles") else []
	var next_id: int = 1
	for bundle_any in bundles:
		if typeof(bundle_any) != TYPE_DICTIONARY:
			continue
		var bundle: Dictionary = bundle_any as Dictionary
		_hive_invite_bundle_select.add_item("%s | Honey %s" % [
			str(bundle.get("title", "Honey Gift")),
			_format_number(int(bundle.get("honey_cost", 0)))
		], next_id)
		_hive_invite_bundle_select.set_item_metadata(_hive_invite_bundle_select.item_count - 1, bundle.duplicate(true))
		next_id += 1
	if selected_id > 0:
		for idx in range(_hive_invite_bundle_select.item_count):
			if _hive_invite_bundle_select.get_item_id(idx) == selected_id:
				_hive_invite_bundle_select.select(idx)
				return
	_hive_invite_bundle_select.select(0)

func _sort_hive_invite_players(players: Array, sort_mode: String) -> Array:
	var out: Array = []
	for player_any in players:
		if typeof(player_any) == TYPE_DICTIONARY:
			out.append((player_any as Dictionary).duplicate(true))
	out.sort_custom(func(a_any: Variant, b_any: Variant) -> bool:
		var a: Dictionary = a_any as Dictionary
		var b: Dictionary = b_any as Dictionary
		match sort_mode.strip_edges().to_lower():
			"honey":
				var honey_a: float = float(a.get("wax_score", 0.0))
				var honey_b: float = float(b.get("wax_score", 0.0))
				if absf(honey_a - honey_b) > 0.001:
					return honey_a > honey_b
			"tier":
				var tier_a: String = str(a.get("tier_id", "DRONE"))
				var tier_b: String = str(b.get("tier_id", "DRONE"))
				if tier_a != tier_b:
					return tier_a < tier_b
			_:
				var rank_a: int = int(a.get("rank_global", 0))
				var rank_b: int = int(b.get("rank_global", 0))
				if rank_a > 0 and rank_b > 0 and rank_a != rank_b:
					return rank_a < rank_b
				if rank_a > 0 and rank_b <= 0:
					return true
				if rank_b > 0 and rank_a <= 0:
					return false
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)
	return out

func _open_hive_invite_dialog() -> void:
	_ensure_hive_invite_dialog()
	_refresh_hive_invite_dialog()
	if _hive_invite_dialog == null:
		return
	_hive_invite_dialog.popup_centered()

func _submit_hive_invite() -> void:
	if _hive_invite_list == null:
		return
	var selected: PackedInt32Array = _hive_invite_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Select a player to invite."
		return
	if HiveClanState == null or not HiveClanState.has_method("intent_invite_player"):
		status_label.text = "Hive invite system unavailable."
		return
	var metadata: Variant = _hive_invite_list.get_item_metadata(selected[0])
	if typeof(metadata) != TYPE_DICTIONARY:
		status_label.text = "Selected player is invalid."
		return
	var player: Dictionary = metadata as Dictionary
	var hive_id: String = _current_hive_id()
	if hive_id.is_empty():
		status_label.text = "No active hive found."
		return
	var offer_bundle_id: String = _selected_hive_invite_offer_bundle_id()
	var result: Dictionary = HiveClanState.call(
		"intent_invite_player",
		hive_id,
		str(player.get("player_id", "")),
		str(player.get("display_name", "")),
		"member",
		"",
		offer_bundle_id
	) as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"invite_already_pending":
				status_label.text = "Invite already pending."
			"application_already_pending":
				status_label.text = "Player already applied to this hive."
			"target_already_in_hive":
				status_label.text = "Player already joined a hive."
			"hive_member_limit_reached":
				status_label.text = "Hive member limit reached."
			"forbidden":
				status_label.text = "Only queen or soldiers can send invites."
			_:
				status_label.text = "Could not send invite."
		_refresh_hive_invite_dialog()
		return
	var invite: Dictionary = result.get("invite", {}) as Dictionary
	var offer: Dictionary = invite.get("offer_bundle", {}) as Dictionary
	status_label.text = "Invite sent to %s. Expires in 48h." % str(invite.get("target_display_name", "player"))
	if not offer.is_empty():
		status_label.text += " Offer: %s." % str(offer.get("title", "Honey Gift"))
	if _hive_invite_dialog != null:
		_hive_invite_dialog.hide()
	_refresh_hive_pending_dialog()

func _selected_hive_invite_offer_bundle_id() -> String:
	if _hive_invite_bundle_select == null:
		return ""
	var selected_idx: int = _hive_invite_bundle_select.selected
	if selected_idx < 0:
		return ""
	var metadata: Variant = _hive_invite_bundle_select.get_item_metadata(selected_idx)
	if typeof(metadata) != TYPE_DICTIONARY:
		return ""
	var bundle: Dictionary = metadata as Dictionary
	return str(bundle.get("bundle_id", "")).strip_edges()

func _submit_hive_remove_queen_vote() -> void:
	if HiveClanState == null or not HiveClanState.has_method("intent_vote_remove_queen"):
		status_label.text = "Queen removal vote unavailable."
		return
	var hive_id: String = _current_hive_id()
	if hive_id.is_empty():
		status_label.text = "No active hive found."
		return
	var result: Dictionary = HiveClanState.call("intent_vote_remove_queen", hive_id, "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"forbidden":
				status_label.text = "Only soldiers can initiate queen removal."
			"queen_not_found":
				status_label.text = "No queen found for this hive."
			_:
				status_label.text = "Could not cast remove queen vote."
		return
	if bool(result.get("queen_removed", false)):
		status_label.text = "Queen removed. Senior soldier promoted automatically."
	else:
		var vote: Dictionary = result.get("vote", {}) as Dictionary
		status_label.text = "Remove queen vote cast (%d/%d). Expires in %s." % [
			int((vote.get("voter_ids", []) as Array).size()),
			int(vote.get("votes_needed", 3)),
			_format_time_remaining(int(vote.get("expires_at_unix", 0)))
		]
	_sync_hive_panel_profile_from_hive_state()

func _submit_hive_soldier_application() -> void:
	if HiveClanState == null or not HiveClanState.has_method("intent_apply_for_soldier"):
		status_label.text = "Soldier application unavailable."
		return
	var hive_id: String = _current_hive_id()
	if hive_id.is_empty():
		status_label.text = "Join a hive first."
		return
	var result: Dictionary = HiveClanState.call("intent_apply_for_soldier", hive_id, "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"already_leadership":
				status_label.text = "You are already in leadership."
			"soldier_limit_reached":
				status_label.text = "All soldier posts are filled."
			_:
				status_label.text = "Could not apply for soldier."
		return
	var vote: Dictionary = result.get("vote", {}) as Dictionary
	status_label.text = "Soldier application submitted. Leadership vote expires in %s." % _format_time_remaining(int(vote.get("expires_at_unix", 0)))
	_sync_hive_panel_profile_from_hive_state()

func _ensure_hive_rankings_dialog() -> void:
	if _hive_rankings_dialog != null and is_instance_valid(_hive_rankings_dialog):
		return
	var dialog := AcceptDialog.new()
	dialog.name = "HiveRankingsDialog"
	dialog.title = "Hive Rankings"
	dialog.exclusive = true
	dialog.min_size = Vector2i(640, 440)
	add_child(dialog)
	_hive_rankings_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HiveRankingsVBox"
	body.custom_minimum_size = Vector2(580.0, 340.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var meta := Label.new()
	meta.text = "Ranking hives by member strength, tournament wins, titles, and seasonal finish."
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(meta)
	_apply_font(meta, _font_regular, 12)
	_hive_rankings_meta_label = meta

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(580.0, 270.0)
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	body.add_child(list)
	_apply_font(list, _font_regular, 12)
	_hive_rankings_list = list

	_wire_hive_dialog_main_menu(dialog)
	dialog.get_ok_button().text = "CLOSE"
	_apply_font(dialog.get_ok_button(), _font_regular, 12)
	_style_button(dialog.get_ok_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))

func _refresh_hive_rankings_dialog() -> void:
	if _hive_rankings_list == null or _hive_rankings_meta_label == null:
		return
	_hive_rankings_list.clear()
	if HiveClanState == null or not HiveClanState.has_method("get_browseable_hives"):
		_hive_rankings_meta_label.text = "Hive rankings unavailable."
		return
	var membership: Dictionary = _current_hive_membership()
	var current_hive_id: String = str(membership.get("hive_id", ""))
	var hives: Array = HiveClanState.call("get_browseable_hives") as Array
	var rank_position: int = 1
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var marker: String = "  YOU" if str(hive.get("hive_id", "")) == current_hive_id else ""
		var rank_breakdown: Dictionary = hive.get("rank_breakdown", {}) as Dictionary
		var label: String = "#%d | %s | %d/%d | Rank %s | T %d | Titles %d%s" % [
			rank_position,
			str(hive.get("name", "Hive")),
			int(hive.get("member_count", 0)),
			int(hive.get("member_limit", 14)),
			_format_number(int(hive.get("rank_points", 0))),
			int(hive.get("tournament_wins", 0)),
			int(hive.get("hive_championships", 0)),
			marker
		]
		var multiplier: float = float(rank_breakdown.get("multiplier", 1.0))
		if multiplier > 1.001:
			label += " | x%0.2f" % multiplier
		_hive_rankings_list.add_item(label)
		var idx: int = _hive_rankings_list.get_item_count() - 1
		_hive_rankings_list.set_item_metadata(idx, hive.duplicate(true))
		rank_position += 1
	if _hive_rankings_list.item_count > 0:
		_hive_rankings_meta_label.text = "Ranking hives by member rank totals multiplied by permanent trophy bonuses. Current hive marked when applicable."
	else:
		_hive_rankings_meta_label.text = "No hives ranked yet."

func _open_hive_rankings_dialog() -> void:
	_ensure_hive_rankings_dialog()
	_refresh_hive_rankings_dialog()
	if _hive_rankings_dialog == null:
		return
	_hive_rankings_dialog.popup_centered()

func _ensure_hive_tournaments_dialog() -> void:
	if _hive_tournaments_dialog != null and is_instance_valid(_hive_tournaments_dialog):
		return
	var dialog := AcceptDialog.new()
	dialog.name = "HiveTournamentsDialog"
	dialog.title = "Hive Tournaments"
	dialog.exclusive = true
	dialog.min_size = Vector2i(720, 620)
	add_child(dialog)
	_hive_tournaments_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HiveTournamentsVBox"
	body.custom_minimum_size = Vector2(660.0, 500.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var meta := Label.new()
	meta.text = "Hive tournaments cost hive honey to enter."
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(meta)
	_apply_font(meta, _font_regular, 12)
	_hive_tournaments_meta_label = meta

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(660.0, 220.0)
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	body.add_child(list)
	_apply_font(list, _font_regular, 12)
	if not list.item_selected.is_connected(_on_hive_tournaments_item_selected):
		list.item_selected.connect(_on_hive_tournaments_item_selected)
	_hive_tournaments_list = list

	var detail := Label.new()
	detail.name = "HiveTournamentDetail"
	detail.custom_minimum_size = Vector2(660.0, 190.0)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail.text = "Select a tournament to view bracket status."
	body.add_child(detail)
	_apply_font(detail, _font_regular, 12)
	_hive_tournaments_detail_label = detail

	var enter_button: Button = dialog.add_button("ENTER", false, "enter")
	_apply_font(enter_button, _font_semibold, 12)
	_style_button(enter_button, Color(0.15, 0.11, 0.05), Color(0.84, 0.66, 0.24), Color(0.98, 0.93, 0.80))
	_hive_tournaments_enter_button = enter_button
	var launch_button: Button = dialog.add_button("START RUN", false, "launch")
	_apply_font(launch_button, _font_semibold, 12)
	_style_button(launch_button, Color(0.08, 0.16, 0.12), Color(0.36, 0.76, 0.54), Color(0.94, 0.99, 0.96))
	_hive_tournaments_launch_button = launch_button
	_wire_hive_dialog_main_menu(dialog)
	dialog.get_ok_button().text = "CLOSE"
	_apply_font(dialog.get_ok_button(), _font_regular, 12)
	_style_button(dialog.get_ok_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	if not dialog.custom_action.is_connected(_on_hive_tournaments_action):
		dialog.custom_action.connect(_on_hive_tournaments_action)

func _refresh_hive_tournaments_dialog() -> void:
	if _hive_tournaments_list == null or _hive_tournaments_meta_label == null:
		return
	_hive_tournaments_list.clear()
	var hive_honey: int = int(_hive_panel_profile.get("honey_score", 0))
	var tournament_entries: Dictionary = _hive_panel_profile.get("tournament_entries", {}) as Dictionary
	var hive_id: String = _current_hive_id()
	var local_assignment: Dictionary = _local_hive_tournament_assignment()
	var entries: Array = HiveClanState.call("get_hive_tournament_entries") as Array if HiveClanState != null and HiveClanState.has_method("get_hive_tournament_entries") else []
	var role_key: String = _current_hive_role_key()
	if not local_assignment.is_empty():
		_hive_tournaments_meta_label.text = "Tournament run assigned. Submit by %s before entering any other queue." % _format_calendar_date(int(local_assignment.get("deadline_unix", 0)))
	elif role_key == "queen":
		_hive_tournaments_meta_label.text = "Available hive honey: %s | Queen entry controls are active." % _format_number(hive_honey)
	else:
		_hive_tournaments_meta_label.text = "Available hive honey: %s | View tournament status here. Queens enter; assigned players launch." % _format_number(hive_honey)
	for entry_any in entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var tournament_id: String = str(entry.get("tournament_id", ""))
		var active_entry: Dictionary = tournament_entries.get(tournament_id, {}) as Dictionary
		var dashboard: Dictionary = HiveClanState.call("get_hive_tournament_dashboard", hive_id, tournament_id, "") as Dictionary if HiveClanState != null and HiveClanState.has_method("get_hive_tournament_dashboard") and not hive_id.is_empty() else {}
		var cost: int = int(entry.get("honey_cost", 0))
		var queue_status: String = str(active_entry.get("queue_status", ""))
		var local_for_entry: bool = str(local_assignment.get("tournament_id", "")) == tournament_id
		var state_text: String = ""
		if local_for_entry:
			state_text = "Your Run"
		elif not dashboard.is_empty() and str(dashboard.get("queue_status", "")) == "active":
			var dashboard_round_number: int = maxi(1, int(dashboard.get("current_round_number", 1)))
			var dashboard_rounds_total: int = maxi(1, int(dashboard.get("rounds_total", 1)))
			var opponent_hive_name: String = str(dashboard.get("opponent_hive_name", "")).strip_edges()
			if opponent_hive_name != "":
				state_text = "R%d/%d vs %s" % [dashboard_round_number, dashboard_rounds_total, opponent_hive_name]
			else:
				state_text = "Round %d/%d" % [dashboard_round_number, dashboard_rounds_total]
		elif queue_status == "active":
			state_text = "In Progress"
		elif queue_status == "queued":
			if not dashboard.is_empty():
				state_text = "Queued %d/%d" % [
					maxi(1, int(dashboard.get("queue_position", 1))),
					maxi(1, int(dashboard.get("queue_size", 1)))
				]
			else:
				state_text = "Awaiting Opponent"
		elif queue_status == "resolved" or queue_status == "forfeit":
			state_text = "Resolved"
		else:
			state_text = "Ready" if hive_honey >= cost else "Need %s more" % _format_number(cost - hive_honey)
		var label: String = "%s | Honey %s | %s" % [
			str(entry.get("title", "Hive Tournament")),
			_format_number(cost),
			state_text
		]
		_hive_tournaments_list.add_item(label)
		var idx: int = _hive_tournaments_list.get_item_count() - 1
		var entry_with_state: Dictionary = entry.duplicate(true)
		if not active_entry.is_empty():
			entry_with_state["active_entry"] = active_entry.duplicate(true)
		if not dashboard.is_empty():
			entry_with_state["dashboard"] = dashboard.duplicate(true)
		if local_for_entry:
			entry_with_state["local_assignment"] = local_assignment.duplicate(true)
		_hive_tournaments_list.set_item_metadata(idx, entry_with_state)
		if local_for_entry:
			_hive_tournaments_list.select(idx)
	if _hive_tournaments_list.get_item_count() > 0 and _hive_tournaments_list.get_selected_items().is_empty():
		_hive_tournaments_list.select(0)
	if entries.is_empty():
		_hive_tournaments_meta_label.text = "No hive tournaments configured yet."
	_sync_hive_tournaments_dialog_selection()

func _open_hive_tournaments_dialog() -> void:
	if _current_hive_id().is_empty():
		status_label.text = "Join a hive to view tournaments."
		return
	_ensure_hive_tournaments_dialog()
	_refresh_hive_tournaments_dialog()
	if _hive_tournaments_dialog == null:
		return
	_hive_tournaments_dialog.popup_centered()

func _on_hive_tournaments_action(action: StringName) -> void:
	if _hive_tournaments_list == null:
		return
	var selected: PackedInt32Array = _hive_tournaments_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Select a tournament first."
		return
	var metadata: Variant = _hive_tournaments_list.get_item_metadata(selected[0])
	if typeof(metadata) != TYPE_DICTIONARY:
		status_label.text = "Selected tournament is invalid."
		return
	var entry: Dictionary = metadata as Dictionary
	if String(action) == "launch":
		var assignment: Dictionary = entry.get("local_assignment", {}) as Dictionary
		if assignment.is_empty():
			status_label.text = "No active tournament run is assigned."
			return
		if _launch_local_hive_tournament_run(assignment):
			if _hive_tournaments_dialog != null:
				_hive_tournaments_dialog.hide()
		else:
			status_label.text = "Tournament launch failed."
		return
	if String(action) != "enter":
		return
	if not (entry.get("active_entry", {}) as Dictionary).is_empty():
		status_label.text = "%s is already entered." % str(entry.get("title", "Hive Tournament"))
		return
	if HiveClanState == null or not HiveClanState.has_method("intent_enter_hive_tournament"):
		status_label.text = "Hive tournament entry unavailable."
		return
	var hive_id: String = _current_hive_id()
	if hive_id.is_empty():
		status_label.text = "No active hive found."
		return
	var result: Dictionary = HiveClanState.call("intent_enter_hive_tournament", hive_id, str(entry.get("tournament_id", "")), "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"forbidden":
				status_label.text = "Only the queen can enter hive tournaments."
			"tournament_not_found":
				status_label.text = "Selected tournament is invalid."
			"tournament_already_entered":
				status_label.text = "%s is already entered." % str(entry.get("title", "Hive Tournament"))
			"insufficient_hive_honey":
				status_label.text = "Not enough hive honey for %s." % str(entry.get("title", "Hive Tournament"))
			"insufficient_hive_members":
				status_label.text = "Hive tournaments require 7 members."
			"active_round_in_progress":
				status_label.text = "Finish the current hive tournament round before entering another."
			_:
				status_label.text = "Could not enter hive tournament."
		_refresh_hive_tournaments_dialog()
		return
	var entered: Dictionary = result.get("entry", {}) as Dictionary
	var queue_status: String = str(entered.get("queue_status", "queued"))
	status_label.text = "Entered %s for %s hive honey. %s" % [
		str(entered.get("title", entry.get("title", "Hive Tournament"))),
		_format_number(int(entered.get("honey_cost", entry.get("honey_cost", 0)))),
		"Round started." if queue_status == "active" else "Waiting for an opponent."
	]
	_sync_hive_panel_profile_from_hive_state()
	_refresh_hive_tournaments_dialog()

func _on_hive_tournaments_item_selected(_index: int) -> void:
	_sync_hive_tournaments_dialog_selection()

func _sync_hive_tournaments_dialog_selection() -> void:
	_update_hive_tournaments_dialog_buttons()
	_refresh_hive_tournaments_detail()

func _update_hive_tournaments_dialog_buttons() -> void:
	var selected_entry: Dictionary = {}
	if _hive_tournaments_list != null:
		var selected: PackedInt32Array = _hive_tournaments_list.get_selected_items()
		if not selected.is_empty():
			var metadata: Variant = _hive_tournaments_list.get_item_metadata(selected[0])
			if typeof(metadata) == TYPE_DICTIONARY:
				selected_entry = metadata as Dictionary
	var active_entry: Dictionary = selected_entry.get("active_entry", {}) as Dictionary
	var local_assignment: Dictionary = selected_entry.get("local_assignment", {}) as Dictionary
	var hive_honey: int = int(_hive_panel_profile.get("honey_score", 0))
	var honey_cost: int = int(selected_entry.get("honey_cost", 0))
	var can_enter: bool = not selected_entry.is_empty()
	can_enter = can_enter and _current_hive_role_key() == "queen"
	can_enter = can_enter and active_entry.is_empty()
	can_enter = can_enter and honey_cost > 0 and hive_honey >= honey_cost
	if _hive_tournaments_enter_button != null:
		_hive_tournaments_enter_button.disabled = not can_enter
	if _hive_tournaments_launch_button != null:
		_hive_tournaments_launch_button.disabled = local_assignment.is_empty()
		_hive_tournaments_launch_button.visible = not local_assignment.is_empty()

func _refresh_hive_tournaments_detail() -> void:
	if _hive_tournaments_detail_label == null:
		return
	var selected_entry: Dictionary = {}
	if _hive_tournaments_list != null:
		var selected: PackedInt32Array = _hive_tournaments_list.get_selected_items()
		if not selected.is_empty():
			var metadata: Variant = _hive_tournaments_list.get_item_metadata(selected[0])
			if typeof(metadata) == TYPE_DICTIONARY:
				selected_entry = metadata as Dictionary
	if selected_entry.is_empty():
		_hive_tournaments_detail_label.text = "Select a tournament to view bracket status."
		return
	var dashboard: Dictionary = selected_entry.get("dashboard", {}) as Dictionary
	_hive_tournaments_detail_label.text = _build_hive_tournament_dashboard_text(dashboard, selected_entry)

func _build_hive_tournament_dashboard_text(dashboard: Dictionary, entry: Dictionary) -> String:
	var title: String = str(entry.get("title", dashboard.get("title", "Hive Tournament"))).strip_edges()
	var lines: Array[String] = []
	lines.append(title)
	var queue_status: String = str(dashboard.get("queue_status", entry.get("queue_status", ""))).strip_edges().to_lower()
	var rounds_total: int = maxi(1, int(dashboard.get("rounds_total", entry.get("rounds_total", 1))))
	var current_round_number: int = maxi(0, int(dashboard.get("current_round_number", entry.get("current_round_number", 0))))
	var field_size: int = maxi(2, int(dashboard.get("field_size", entry.get("field_size", 2))))
	if queue_status == "active":
		var opponent_hive_name: String = str(dashboard.get("opponent_hive_name", "")).strip_edges()
		var roster_size: int = maxi(1, int(dashboard.get("roster_size", 7)))
		lines.append("Bracket round %d/%d | Field %d" % [maxi(1, current_round_number), rounds_total, field_size])
		if opponent_hive_name != "":
			lines.append("Opponent hive: %s" % opponent_hive_name)
		lines.append("Finished: %d/%d | Opponent finished: %d/%d" % [
			int(dashboard.get("hive_completed_count", 0)),
			roster_size,
			int(dashboard.get("opponent_completed_count", 0)),
			roster_size
		])
		var replace_deadline_unix: int = int(dashboard.get("replace_deadline_unix", 0))
		var deadline_unix: int = int(dashboard.get("deadline_unix", 0))
		if replace_deadline_unix > int(Time.get_unix_time_from_system()):
			lines.append("Replacement check-in window: %s" % _format_time_remaining(replace_deadline_unix))
		if deadline_unix > 0:
			lines.append("Submission deadline: %s" % _format_time_remaining(deadline_unix))
		var slot_matchups_any: Variant = dashboard.get("slot_matchups", [])
		if typeof(slot_matchups_any) == TYPE_ARRAY and not (slot_matchups_any as Array).is_empty():
			lines.append("")
			lines.append("Slot matchups")
			for matchup_any in slot_matchups_any as Array:
				if typeof(matchup_any) != TYPE_DICTIONARY:
					continue
				var matchup: Dictionary = matchup_any as Dictionary
				lines.append("%d. %s [%s] vs %s [%s]" % [
					int(matchup.get("slot_number", 0)),
					_format_hive_tournament_slot_name(str(matchup.get("display_name", "")), bool(matchup.get("is_local_player", false))),
					_format_hive_tournament_slot_status(
						str(matchup.get("status", "")),
						int(matchup.get("checked_in_at_unix", 0)),
						int(matchup.get("submitted_at_unix", 0))
					),
					str(matchup.get("opponent_display_name", "TBD")).strip_edges(),
					_format_hive_tournament_slot_status(
						str(matchup.get("opponent_status", "")),
						0,
						int(matchup.get("opponent_submitted_at_unix", 0))
					)
				])
	elif queue_status == "queued":
		lines.append("Queued for %d-hive bracket" % field_size)
		lines.append("Queue position: %d of %d" % [
			maxi(1, int(dashboard.get("queue_position", 1))),
			maxi(1, int(dashboard.get("queue_size", 1)))
		])
		var queued_at_unix: int = int(dashboard.get("queued_at_unix", 0))
		if queued_at_unix > 0:
			lines.append("Queued %s" % _format_hive_feed_age(queued_at_unix))
	elif queue_status == "resolved" or queue_status == "forfeit":
		var last_result: Dictionary = dashboard.get("last_result", {}) as Dictionary
		var winner_hive_id: String = str(last_result.get("winner_hive_id", "")).strip_edges()
		var current_hive_id: String = _current_hive_id()
		if winner_hive_id == current_hive_id:
			lines.append("Latest result: Won")
		elif winner_hive_id != "":
			lines.append("Latest result: Lost")
		else:
			lines.append("Latest result: Resolved")
		var resolution_reason: String = str(last_result.get("resolution_reason", "")).strip_edges().replace("_", " ")
		if resolution_reason != "":
			lines.append("Resolution: %s" % resolution_reason.capitalize())
	else:
		lines.append("Field %d | Bracket round %d/%d" % [field_size, maxi(1, current_round_number), rounds_total])
		lines.append("Awaiting next round to be generated.")
	var detail: String = str(entry.get("detail", dashboard.get("detail", ""))).strip_edges()
	if detail != "":
		lines.append("")
		lines.append(detail)
	return "\n".join(lines)

func _format_hive_tournament_slot_name(display_name: String, is_local_player: bool) -> String:
	var clean_name: String = display_name.strip_edges()
	if clean_name == "":
		clean_name = "TBD"
	return "%s (YOU)" % clean_name if is_local_player else clean_name

func _format_hive_tournament_slot_status(status: String, checked_in_at_unix: int = 0, submitted_at_unix: int = 0) -> String:
	var clean_status: String = status.strip_edges().to_lower()
	match clean_status:
		"submitted":
			return "Done"
		"assigned":
			return "Checked In" if checked_in_at_unix > 0 or submitted_at_unix > 0 else "Pending Login"
		_:
			return clean_status.capitalize() if clean_status != "" else "Pending"

func _build_hive_tournament_status_line(dashboard: Dictionary) -> String:
	if dashboard.is_empty():
		return ""
	var queue_status: String = str(dashboard.get("queue_status", "")).strip_edges().to_lower()
	var title: String = str(dashboard.get("title", "Hive Tournament")).strip_edges()
	match queue_status:
		"active":
			var opponent_hive_name: String = str(dashboard.get("opponent_hive_name", "")).strip_edges()
			var round_number: int = maxi(1, int(dashboard.get("current_round_number", 1)))
			var rounds_total: int = maxi(1, int(dashboard.get("rounds_total", 1)))
			var roster_size: int = maxi(1, int(dashboard.get("roster_size", 7)))
			var headline: String = "%s R%d/%d" % [title, round_number, rounds_total]
			if opponent_hive_name != "":
				headline += " vs %s" % opponent_hive_name
			headline += " | %d/%d in" % [
				int(dashboard.get("hive_completed_count", 0)),
				roster_size
			]
			var deadline_unix: int = int(dashboard.get("deadline_unix", 0))
			if deadline_unix > int(Time.get_unix_time_from_system()):
				headline += " | %s left" % _format_time_remaining(deadline_unix)
			return headline
		"queued":
			return "%s queued | %d-hive bracket | Queue %d/%d" % [
				title,
				maxi(2, int(dashboard.get("field_size", 2))),
				maxi(1, int(dashboard.get("queue_position", 1))),
				maxi(1, int(dashboard.get("queue_size", 1)))
			]
		"resolved", "forfeit":
			var last_result: Dictionary = dashboard.get("last_result", {}) as Dictionary
			var winner_hive_id: String = str(last_result.get("winner_hive_id", "")).strip_edges()
			var current_hive_id: String = _current_hive_id()
			if winner_hive_id == current_hive_id:
				return "%s complete | Won bracket" % title
			elif winner_hive_id != "":
				return "%s complete | Bracket ended" % title
			return "%s complete" % title
		_:
			return ""

func _local_hive_tournament_assignment() -> Dictionary:
	if HiveClanState == null or not HiveClanState.has_method("get_player_active_tournament_assignment"):
		return {}
	return HiveClanState.call("get_player_active_tournament_assignment") as Dictionary

func _launch_local_hive_tournament_run(assignment: Dictionary = {}) -> bool:
	var active_assignment: Dictionary = assignment.duplicate(true)
	if active_assignment.is_empty():
		active_assignment = _local_hive_tournament_assignment()
	if active_assignment.is_empty():
		return false
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var map_paths_any: Variant = active_assignment.get("map_paths", [])
	if typeof(map_paths_any) != TYPE_ARRAY:
		return false
	var map_paths: Array = map_paths_any as Array
	if map_paths.is_empty():
		return false
	var local_uid: String = ProfileManager.get_user_id() if ProfileManager != null else "local"
	var local_name: String = ProfileManager.get_display_name() if ProfileManager != null else "You"
	if local_name.strip_edges().is_empty():
		local_name = "You"
	_clear_direct_match_launch_tree_metas()
	tree.set_meta("start_game", true)
	tree.set_meta("vs_mode", "STAGE_RACE")
	tree.set_meta("vs_price_usd", 0)
	tree.set_meta("vs_free_roll", true)
	tree.set_meta("vs_assigned_players", [local_name])
	tree.set_meta("vs_open_slots", 0)
	tree.set_meta("vs_required_players", 1)
	tree.set_meta("vs_sync_start", false)
	tree.set_meta("vs_sync_join_sec", 0)
	tree.set_meta("vs_window_sec", 0)
	tree.set_meta("vs_window_started_unix", 0)
	tree.set_meta("vs_window_deadline_unix", 0)
	tree.set_meta("vs_stage_map_paths", map_paths.duplicate(true))
	tree.set_meta("vs_stage_current_index", 0)
	tree.set_meta("vs_stage_round_results", [])
	tree.set_meta("vs_handshake_session_id", "")
	tree.set_meta("vs_handshake_role", "host")
	tree.set_meta("vs_handshake_invite_code", "")
	tree.set_meta("vs_local_profile", {
		"uid": local_uid,
		"display_name": local_name
	})
	tree.set_meta("hive_tournament_round_id", str(active_assignment.get("round_id", "")))
	tree.set_meta("hive_tournament_tournament_id", str(active_assignment.get("tournament_id", "")))
	tree.set_meta("hive_tournament_hive_id", str(active_assignment.get("hive_id", "")))
	tree.set_meta("hive_tournament_player_id", local_uid)
	tree.set_meta("hive_tournament_slot_index", int(active_assignment.get("slot_index", 0)))
	tree.set_meta("hive_tournament_opponent_hive_id", str(active_assignment.get("opponent_hive_id", "")))
	tree.set_meta("hive_tournament_opponent_player_id", str(active_assignment.get("opponent_player_id", "")))
	tree.set_meta("hive_tournament_submission_recorded", false)
	if OpsState != null and OpsState.has_method("set_team_mode_override"):
		OpsState.call("set_team_mode_override", "ffa")
	var err: Error = tree.change_scene_to_file(SHELL_SCENE_PATH)
	if err != OK:
		return false
	status_label.text = "%s tournament run starting..." % str(active_assignment.get("title", "Hive Tournament"))
	return true

func _clear_direct_match_launch_tree_metas() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var clear_keys: Array[String] = [
		"open_map_picker_on_ready",
		"vs_mode",
		"vs_price_usd",
		"vs_free_roll",
		"vs_assigned_players",
		"vs_open_slots",
		"vs_required_players",
		"vs_sync_start",
		"vs_sync_join_sec",
		"vs_window_sec",
		"vs_window_started_unix",
		"vs_window_deadline_unix",
		"vs_stage_map_paths",
		"vs_stage_current_index",
		"vs_stage_round_results",
		"vs_handshake_session_id",
		"vs_handshake_role",
		"vs_handshake_invite_code",
		"vs_local_profile",
		"vs_remote_profile",
		"vs_cpu_style",
		"vs_cpu_tier",
		"ctf_flag_selection_mode",
		"ctf_player_select_pct",
		"ctf_randomize_flag_hive",
		"ctf_hidden_flag",
		"ctf_flag_move_count_max",
		"ctf_flag_move_reveals",
		"jukebox_board_enabled",
		"jukebox_map_path",
		"jukebox_map_id",
		"jukebox_board_period",
		"jukebox_local_owner_id",
		"jukebox_result_commit_signature",
		"jukebox_easy_bot",
		"hive_tournament_round_id",
		"hive_tournament_tournament_id",
		"hive_tournament_hive_id",
		"hive_tournament_player_id",
		"hive_tournament_slot_index",
		"hive_tournament_opponent_hive_id",
		"hive_tournament_opponent_player_id",
		"hive_tournament_submission_recorded"
	]
	for key_any in clear_keys:
		var key: String = str(key_any)
		if tree.has_meta(key):
			tree.remove_meta(key)

func _block_for_active_hive_tournament(queue_label: String) -> bool:
	var assignment: Dictionary = _local_hive_tournament_assignment()
	if assignment.is_empty():
		if queue_label.is_empty():
			_announced_hive_tournament_round_id = ""
		return false
	var round_id: String = str(assignment.get("round_id", ""))
	if queue_label.is_empty():
		if _announced_hive_tournament_round_id != round_id:
			_announced_hive_tournament_round_id = round_id
			status_label.text = "Hive tournament run assigned. Finish it before entering other queues."
		return true
	status_label.text = "Finish your hive tournament run before entering %s." % queue_label
	if _hive_tournaments_dialog != null and not _hive_tournaments_dialog.visible:
		_open_hive_tournaments_dialog()
	return true

func _ensure_hive_pending_dialog() -> void:
	if _hive_pending_dialog != null and is_instance_valid(_hive_pending_dialog):
		return
	var dialog := AcceptDialog.new()
	dialog.name = "HivePendingDialog"
	dialog.title = "Pending Hive Invites"
	dialog.exclusive = true
	dialog.min_size = Vector2i(560, 420)
	add_child(dialog)
	_hive_pending_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HivePendingVBox"
	body.custom_minimum_size = Vector2(500.0, 320.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var meta := Label.new()
	meta.text = "Loading pending invites..."
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(meta)
	_apply_font(meta, _font_regular, 12)
	_hive_pending_meta_label = meta

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(500.0, 250.0)
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	body.add_child(list)
	_apply_font(list, _font_regular, 12)
	_hive_pending_list = list

	_wire_hive_dialog_main_menu(dialog)
	dialog.get_ok_button().text = "CLOSE"
	_apply_font(dialog.get_ok_button(), _font_regular, 12)
	_style_button(dialog.get_ok_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))

func _refresh_hive_pending_dialog() -> void:
	if _hive_pending_list == null or _hive_pending_meta_label == null:
		return
	_hive_pending_list.clear()
	var hive_id: String = _current_hive_id()
	if hive_id.is_empty():
		_hive_pending_meta_label.text = "No active hive found."
		return
	if HiveClanState == null or not HiveClanState.has_method("get_hive_invites"):
		_hive_pending_meta_label.text = "Pending invites unavailable."
		return
	var invites: Array = HiveClanState.call("get_hive_invites", hive_id, "pending") as Array
	_hive_pending_meta_label.text = "Pending invites: %d" % invites.size()
	for invite_any in invites:
		if typeof(invite_any) != TYPE_DICTIONARY:
			continue
		var invite: Dictionary = invite_any as Dictionary
		var expires_at_unix: int = int(invite.get("expires_at_unix", 0))
		var hours_left: int = maxi(0, int(ceil(float(expires_at_unix - Time.get_unix_time_from_system()) / 3600.0)))
		var label: String = "%s | invited by %s | expires in %dh" % [
			str(invite.get("target_display_name", "Player")),
			str(invite.get("created_by_display_name", "Leader")),
			hours_left
		]
		var offer: Dictionary = invite.get("offer_bundle", {}) as Dictionary
		if not offer.is_empty():
			label += " | %s" % str(offer.get("title", "Honey Gift"))
		_hive_pending_list.add_item(label)
		var idx: int = _hive_pending_list.get_item_count() - 1
		_hive_pending_list.set_item_metadata(idx, invite.duplicate(true))
	if invites.is_empty():
		_hive_pending_meta_label.text = "No pending invites right now."

func _open_hive_pending_dialog() -> void:
	_ensure_hive_pending_dialog()
	_refresh_hive_pending_dialog()
	if _hive_pending_dialog == null:
		return
	_hive_pending_dialog.popup_centered()

func _ensure_hive_leave_dialog() -> void:
	if _hive_leave_dialog != null and is_instance_valid(_hive_leave_dialog):
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "HiveLeaveDialog"
	dialog.title = "Leave Hive"
	dialog.exclusive = true
	dialog.min_size = Vector2i(500, 220)
	add_child(dialog)
	_hive_leave_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HiveLeaveVBox"
	body.custom_minimum_size = Vector2(420.0, 120.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var desc := Label.new()
	desc.text = "Leaving your hive starts a 24 hour timer. You can join a different hive after it elapses, but you cannot rejoin this same hive for 7 days."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(desc)
	_apply_font(desc, _font_regular, 12)
	_hive_leave_desc_label = desc

	dialog.get_ok_button().text = "START 24H LEAVE"
	_apply_font(dialog.get_ok_button(), _font_semibold, 12)
	_style_button(dialog.get_ok_button(), Color(0.18, 0.08, 0.08), Color(0.82, 0.34, 0.28), Color(0.98, 0.92, 0.90))
	_wire_hive_dialog_main_menu(dialog)
	if dialog.get_cancel_button() != null:
		dialog.get_cancel_button().text = "CLOSE"
		_apply_font(dialog.get_cancel_button(), _font_regular, 12)
		_style_button(dialog.get_cancel_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	if not dialog.confirmed.is_connected(_submit_hive_leave):
		dialog.confirmed.connect(_submit_hive_leave)

func _open_hive_leave_dialog() -> void:
	var membership: Dictionary = _current_hive_membership()
	if membership.is_empty():
		status_label.text = "Join a hive first."
		return
	var leave_request: Dictionary = membership.get("leave_request", {}) as Dictionary
	if not leave_request.is_empty():
		status_label.text = "Leave already pending. Unlocks in %s." % _format_time_remaining(int(leave_request.get("effective_at_unix", 0)))
		return
	_ensure_hive_leave_dialog()
	if _hive_leave_desc_label != null:
		_hive_leave_desc_label.text = "Leave %s? This starts a 24 hour timer. After it completes, you can join a different hive, but this same hive is locked for 7 days." % str(membership.get("hive_name", "your hive"))
	if _hive_leave_dialog != null:
		_hive_leave_dialog.popup_centered()

func _submit_hive_leave() -> void:
	if HiveClanState == null or not HiveClanState.has_method("intent_request_leave_hive"):
		status_label.text = "Hive leave system unavailable."
		return
	var result: Dictionary = HiveClanState.call("intent_request_leave_hive") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"leave_already_pending":
				var leave_request: Dictionary = result.get("leave_request", {}) as Dictionary
				status_label.text = "Leave already pending. Unlocks in %s." % _format_time_remaining(int(leave_request.get("effective_at_unix", 0)))
			"player_not_in_hive":
				status_label.text = "You are not currently in a hive."
			_:
				status_label.text = "Could not start hive leave."
		return
	var leave_request: Dictionary = result.get("leave_request", {}) as Dictionary
	status_label.text = "Leave started. You can join another hive in %s." % _format_time_remaining(int(leave_request.get("effective_at_unix", 0)))
	if _hive_leave_dialog != null:
		_hive_leave_dialog.hide()

func _ensure_hive_remove_member_dialog() -> void:
	if _hive_remove_member_dialog != null and is_instance_valid(_hive_remove_member_dialog):
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "HiveRemoveMemberDialog"
	dialog.title = "Remove Player"
	dialog.exclusive = true
	dialog.min_size = Vector2i(520, 220)
	add_child(dialog)
	_hive_remove_member_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HiveRemoveMemberVBox"
	body.custom_minimum_size = Vector2(440.0, 120.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var desc := Label.new()
	desc.text = "Removing a member immediately ejects them from the hive and blocks rejoining this same hive for 7 days."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(desc)
	_apply_font(desc, _font_regular, 12)
	_hive_remove_member_desc_label = desc

	dialog.get_ok_button().text = "REMOVE MEMBER"
	_apply_font(dialog.get_ok_button(), _font_semibold, 12)
	_style_button(dialog.get_ok_button(), Color(0.18, 0.08, 0.08), Color(0.82, 0.34, 0.28), Color(0.98, 0.92, 0.90))
	_wire_hive_dialog_main_menu(dialog)
	if dialog.get_cancel_button() != null:
		dialog.get_cancel_button().text = "CLOSE"
		_apply_font(dialog.get_cancel_button(), _font_regular, 12)
		_style_button(dialog.get_cancel_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	if not dialog.confirmed.is_connected(_submit_hive_remove_member):
		dialog.confirmed.connect(_submit_hive_remove_member)

func _ensure_hive_post_dialog() -> void:
	if _hive_post_dialog != null and is_instance_valid(_hive_post_dialog):
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "HivePostDialog"
	dialog.title = "Post To Hive"
	dialog.exclusive = true
	dialog.min_size = Vector2i(560, 300)
	add_child(dialog)
	_hive_post_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HivePostVBox"
	body.custom_minimum_size = Vector2(480.0, 180.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var desc := Label.new()
	desc.text = "Post a hive-only message. Members and invited players can post here."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(desc)
	_apply_font(desc, _font_regular, 12)

	var input := TextEdit.new()
	input.custom_minimum_size = Vector2(480.0, 120.0)
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.add_child(input)
	_apply_font(input, _font_regular, 13)
	_hive_post_input = input

	dialog.get_ok_button().text = "POST"
	_apply_font(dialog.get_ok_button(), _font_semibold, 12)
	_style_button(dialog.get_ok_button(), Color(0.15, 0.11, 0.05), Color(0.84, 0.66, 0.24), Color(0.98, 0.93, 0.80))
	_wire_hive_dialog_main_menu(dialog)
	if dialog.get_cancel_button() != null:
		dialog.get_cancel_button().text = "CLOSE"
		_apply_font(dialog.get_cancel_button(), _font_regular, 12)
		_style_button(dialog.get_cancel_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	if not dialog.confirmed.is_connected(_submit_hive_post):
		dialog.confirmed.connect(_submit_hive_post)

func _open_hive_post_dialog() -> void:
	if not bool(_hive_panel_profile.get("can_post_hive_comms", false)):
		status_label.text = "Hive posting is not available."
		return
	_ensure_hive_post_dialog()
	if _hive_post_input != null:
		_hive_post_input.text = ""
	if _hive_post_dialog != null:
		_hive_post_dialog.popup_centered()
	if _hive_post_input != null:
		_hive_post_input.grab_focus()

func _submit_hive_post() -> void:
	if HiveClanState == null or not HiveClanState.has_method("intent_post_hive_message"):
		status_label.text = "Hive posting unavailable."
		return
	var hive_id: String = str(_hive_panel_profile.get("hive_id", ""))
	var message_text: String = ""
	if _hive_post_input != null:
		message_text = _hive_post_input.text
	var result: Dictionary = HiveClanState.call("intent_post_hive_message", hive_id, message_text, "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"invalid_message":
				status_label.text = "Enter a hive message first."
			"forbidden":
				status_label.text = "You do not have hive comms access."
			_:
				status_label.text = "Could not post hive message."
		return
	status_label.text = "Posted to hive comms."
	if _hive_post_dialog != null:
		_hive_post_dialog.hide()
	if _hive_post_input != null:
		_hive_post_input.text = ""

func _ensure_hive_pin_dialog() -> void:
	if _hive_pin_dialog != null and is_instance_valid(_hive_pin_dialog):
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "HivePinDialog"
	dialog.title = "Pin Hive Notice"
	dialog.exclusive = true
	dialog.min_size = Vector2i(560, 320)
	add_child(dialog)
	_hive_pin_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HivePinVBox"
	body.custom_minimum_size = Vector2(480.0, 200.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var desc := Label.new()
	desc.text = "Set the pinned notice shown at the top of hive comms. Leave it blank to clear."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(desc)
	_apply_font(desc, _font_regular, 12)

	var input := TextEdit.new()
	input.custom_minimum_size = Vector2(480.0, 130.0)
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.add_child(input)
	_apply_font(input, _font_regular, 13)
	_hive_pin_input = input

	dialog.get_ok_button().text = "SAVE NOTICE"
	_apply_font(dialog.get_ok_button(), _font_semibold, 12)
	_style_button(dialog.get_ok_button(), Color(0.15, 0.11, 0.05), Color(0.84, 0.66, 0.24), Color(0.98, 0.93, 0.80))
	_wire_hive_dialog_main_menu(dialog)
	if dialog.get_cancel_button() != null:
		dialog.get_cancel_button().text = "CLOSE"
		_apply_font(dialog.get_cancel_button(), _font_regular, 12)
		_style_button(dialog.get_cancel_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	if not dialog.confirmed.is_connected(_submit_hive_pin_notice):
		dialog.confirmed.connect(_submit_hive_pin_notice)

func _open_hive_pin_dialog() -> void:
	if not bool(_hive_panel_profile.get("can_pin_hive_notice", false)):
		status_label.text = "Only hive leadership can pin a notice."
		return
	_ensure_hive_pin_dialog()
	if _hive_pin_input != null:
		_hive_pin_input.text = str(_hive_panel_profile.get("pinned_notice_message", ""))
	if _hive_pin_dialog != null:
		_hive_pin_dialog.popup_centered()
	if _hive_pin_input != null:
		_hive_pin_input.grab_focus()

func _submit_hive_pin_notice() -> void:
	if HiveClanState == null or not HiveClanState.has_method("intent_set_pinned_notice"):
		status_label.text = "Pinned notice unavailable."
		return
	var hive_id: String = str(_hive_panel_profile.get("hive_id", ""))
	var notice_text: String = ""
	if _hive_pin_input != null:
		notice_text = _hive_pin_input.text
	var result: Dictionary = HiveClanState.call("intent_set_pinned_notice", hive_id, notice_text, "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"forbidden":
				status_label.text = "Only the queen or soldiers can pin a notice."
			_:
				status_label.text = "Could not update pinned notice."
		return
	status_label.text = "Pinned notice updated." if not bool(result.get("cleared", false)) else "Pinned notice cleared."
	if _hive_pin_dialog != null:
		_hive_pin_dialog.hide()

func _ensure_hive_about_dialog() -> void:
	if _hive_about_dialog != null and is_instance_valid(_hive_about_dialog):
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.name = "HiveAboutDialog"
	dialog.title = "About Our Hive"
	dialog.exclusive = true
	dialog.min_size = Vector2i(HIVE_TEXT_DIALOG_WIDTH, HIVE_ABOUT_DIALOG_HEIGHT)
	_style_hive_create_dialog(dialog)
	add_child(dialog)
	_hive_about_dialog = dialog

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "HiveAboutVBox"
	body.custom_minimum_size = Vector2(720.0, 420.0)
	body.add_theme_constant_override("separation", 18)
	dialog.add_child(body)

	var desc: Label = Label.new()
	desc.text = "Write the public recruiting message shown when players preview this hive. 300 character limit. Editable once every 24 hours."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(desc)
	_apply_font(desc, _font_regular, 22)
	desc.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.95))
	_hive_about_desc_label = desc

	var input: TextEdit = TextEdit.new()
	input.custom_minimum_size = Vector2(0.0, 270.0)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.add_child(input)
	_apply_font(input, _font_regular, 24)
	_style_hive_text_edit(input)
	_hive_about_input = input

	var done_row: HBoxContainer = HBoxContainer.new()
	done_row.name = "HiveAboutDoneRow"
	done_row.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(done_row)
	var done_button: Button = Button.new()
	done_button.name = "HiveAboutDoneButton"
	done_button.text = "DONE"
	done_button.custom_minimum_size = Vector2(172.0, 64.0)
	done_row.add_child(done_button)
	_apply_font(done_button, _font_semibold, 17)
	_style_button(done_button, Color(0.12, 0.13, 0.16), Color(0.64, 0.66, 0.76), Color(0.96, 0.96, 0.96))
	_hive_about_done_button = done_button

	dialog.get_ok_button().text = "SAVE ABOUT"
	dialog.get_ok_button().custom_minimum_size = Vector2(230.0, 64.0)
	_apply_font(dialog.get_ok_button(), _font_semibold, 17)
	_style_button(dialog.get_ok_button(), Color(0.15, 0.11, 0.05), Color(0.84, 0.66, 0.24), Color(0.98, 0.93, 0.80))
	_wire_hive_dialog_main_menu(dialog)
	if dialog.get_cancel_button() != null:
		dialog.get_cancel_button().text = "CLOSE"
		dialog.get_cancel_button().custom_minimum_size = Vector2(178.0, 64.0)
		_apply_font(dialog.get_cancel_button(), _font_regular, 17)
		_style_button(dialog.get_cancel_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	if not dialog.confirmed.is_connected(_submit_hive_about_message):
		dialog.confirmed.connect(_submit_hive_about_message)
	if not done_button.pressed.is_connected(_on_hive_about_done_pressed):
		done_button.pressed.connect(_on_hive_about_done_pressed)

func _open_hive_about_dialog() -> void:
	if _current_hive_role_key() != "queen":
		status_label.text = "Only the queen can edit the public hive profile."
		return
	_ensure_hive_about_dialog()
	var about_profile: Dictionary = _hive_panel_profile.get("about_profile", {}) as Dictionary
	var message: String = str(about_profile.get("message", "")).strip_edges()
	var next_edit_at_unix: int = int(about_profile.get("next_edit_at_unix", 0))
	var now_unix: int = int(Time.get_unix_time_from_system())
	var locked: bool = message != "" and next_edit_at_unix > now_unix
	if _hive_about_input != null:
		_hive_about_input.text = message
		_hive_about_input.editable = not locked
	if _hive_about_desc_label != null:
		if locked:
			_hive_about_desc_label.text = "Public recruiting message. Next edit opens in %s. 300 character limit." % _format_time_remaining(next_edit_at_unix)
		else:
			_hive_about_desc_label.text = "Write the public recruiting message shown when players preview this hive. 300 character limit. Editable once every 24 hours."
	if _hive_about_dialog != null:
		_hive_about_dialog.get_ok_button().disabled = locked
		_popup_hive_dialog_below_banner(_hive_about_dialog, _hive_about_popup_size())
	if _hive_about_input != null and not locked:
		call_deferred("_focus_hive_about_input")

func _focus_hive_about_input() -> void:
	if _hive_about_dialog == null or not is_instance_valid(_hive_about_dialog):
		return
	if not _hive_about_dialog.visible:
		return
	if _hive_about_input == null:
		return
	_hive_about_input.grab_focus()

func _on_hive_about_done_pressed() -> void:
	if _hive_about_input != null:
		_hive_about_input.release_focus()
	DisplayServer.virtual_keyboard_hide()

func _submit_hive_about_message() -> void:
	if HiveClanState == null or not HiveClanState.has_method("intent_set_hive_about"):
		status_label.text = "Hive profile editor unavailable."
		return
	var hive_id: String = str(_hive_panel_profile.get("hive_id", ""))
	var about_text: String = ""
	if _hive_about_input != null:
		about_text = _hive_about_input.text
	if about_text.length() > 300:
		about_text = about_text.substr(0, 300)
	DisplayServer.virtual_keyboard_hide()
	var result: Dictionary = HiveClanState.call("intent_set_hive_about", hive_id, about_text, "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"forbidden":
				status_label.text = "Only the queen can edit the public hive profile."
			"update_cooldown":
				status_label.text = "About Our Hive can be updated again in %s." % _format_time_remaining(int(result.get("next_edit_at_unix", 0)))
			_:
				status_label.text = "Could not update About Our Hive."
		return
	if bool(result.get("unchanged", false)):
		status_label.text = "About Our Hive is already up to date."
	elif bool(result.get("cleared", false)):
		status_label.text = "About Our Hive cleared."
	else:
		status_label.text = "About Our Hive published."
	if _hive_about_dialog != null:
		_hive_about_dialog.hide()
	_sync_hive_panel_profile_from_hive_state()

func _open_hive_remove_member_dialog(context: Dictionary) -> void:
	_ensure_hive_remove_member_dialog()
	_hive_remove_member_target = context.duplicate(true)
	if _hive_remove_member_desc_label != null:
		_hive_remove_member_desc_label.text = "Remove %s from the hive? This takes effect immediately. They can join another hive right away, but cannot rejoin this same hive for 7 days." % str(context.get("target_name", "this member"))
	if _hive_remove_member_dialog != null:
		_hive_remove_member_dialog.popup_centered()

func _submit_hive_remove_member() -> void:
	var context: Dictionary = _hive_remove_member_target.duplicate(true)
	if context.is_empty():
		status_label.text = "No member selected for removal."
		return
	if HiveClanState == null or not HiveClanState.has_method("intent_remove_member"):
		status_label.text = "Member removal unavailable."
		return
	var hive_id: String = _current_hive_id()
	var result: Dictionary = HiveClanState.call("intent_remove_member", hive_id, str(context.get("target_player_id", "")), "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"forbidden":
				status_label.text = "Only the queen can remove a regular member."
			"target_not_removable_member":
				status_label.text = "Leadership must be handled through governance votes."
			_:
				status_label.text = "Could not remove player."
		_refresh_hive_member_actions_dialog()
		return
	status_label.text = "%s removed from the hive. Same-hive rejoin locked for 7d." % str(context.get("target_name", "Member"))
	_hive_remove_member_target = {}
	if _hive_remove_member_dialog != null:
		_hive_remove_member_dialog.hide()
	_refresh_hive_member_actions_dialog()

func _ensure_hive_browse_dialog() -> void:
	if _hive_browse_dialog != null and is_instance_valid(_hive_browse_dialog):
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "HiveBrowseDialog"
	dialog.title = "Browse Hives"
	dialog.exclusive = true
	dialog.min_size = Vector2i(560, 460)
	add_child(dialog)
	_hive_browse_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HiveBrowseVBox"
	body.custom_minimum_size = Vector2(500.0, 340.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var meta := Label.new()
	meta.text = "Browse active hives and apply to join."
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(meta)
	_apply_font(meta, _font_regular, 12)
	_hive_browse_meta_label = meta

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(500.0, 270.0)
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	body.add_child(list)
	_apply_font(list, _font_regular, 12)
	_hive_browse_list = list

	dialog.get_ok_button().text = "APPLY"
	_apply_font(dialog.get_ok_button(), _font_semibold, 12)
	_style_button(dialog.get_ok_button(), Color(0.15, 0.11, 0.05), Color(0.84, 0.66, 0.24), Color(0.98, 0.93, 0.80))
	_wire_hive_dialog_main_menu(dialog)
	if dialog.get_cancel_button() != null:
		dialog.get_cancel_button().text = "CLOSE"
		_apply_font(dialog.get_cancel_button(), _font_regular, 12)
		_style_button(dialog.get_cancel_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	if not dialog.confirmed.is_connected(_submit_hive_application):
		dialog.confirmed.connect(_submit_hive_application)

func _refresh_hive_browse_dialog() -> void:
	if _hive_browse_list == null or _hive_browse_meta_label == null:
		return
	_hive_browse_list.clear()
	if HiveClanState == null or not HiveClanState.has_method("get_browseable_hives"):
		_hive_browse_meta_label.text = "Hive browsing unavailable."
		return
	var membership: Dictionary = _current_hive_membership()
	if not membership.is_empty():
		_hive_browse_meta_label.text = "Leave your current hive before applying elsewhere."
	else:
		_hive_browse_meta_label.text = "Browse active hives and apply to join."
	var hives: Array = HiveClanState.call("get_browseable_hives") as Array
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var state_text: String = "Apply"
		if not bool(hive.get("pending_invite", {}).is_empty()):
			state_text = "Invite pending"
		elif not bool(hive.get("pending_application", {}).is_empty()):
			state_text = "Application pending"
		elif int(hive.get("blocked_until_unix", 0)) > int(Time.get_unix_time_from_system()):
			state_text = "Rejoin locked"
		elif not bool(hive.get("can_apply", false)):
			state_text = "Unavailable"
		elif not bool(hive.get("expired_invite", {}).is_empty()):
			state_text = "Expired invite -> apply"
		var label: String = "%s | %d/%d | Rank Pts %s | %s" % [
			str(hive.get("name", "Hive")),
			int(hive.get("member_count", 0)),
			int(hive.get("member_limit", 14)),
			_format_number(int(hive.get("rank_points", 0))),
			state_text
		]
		_hive_browse_list.add_item(label)
		var idx: int = _hive_browse_list.get_item_count() - 1
		_hive_browse_list.set_item_metadata(idx, hive.duplicate(true))

func _open_hive_browse_dialog() -> void:
	_ensure_hive_browse_dialog()
	_refresh_hive_browse_dialog()
	if _hive_browse_dialog == null:
		return
	_hive_browse_dialog.popup_centered()

func _open_hive_comms_access() -> void:
	if HiveClanState == null or not HiveClanState.has_method("get_hive_comms_access_for_player"):
		status_label.text = "Hive comms unavailable."
		return
	var access_list: Array = HiveClanState.call("get_hive_comms_access_for_player") as Array
	if access_list.is_empty():
		status_label.text = "No hive comms access yet."
		return
	_sync_hive_panel_profile_from_hive_state()
	_open_dash_panel_from_menu(dash_hive_panel)

func _submit_hive_application() -> void:
	if _hive_browse_list == null:
		return
	var selected: PackedInt32Array = _hive_browse_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Select a hive to apply to."
		return
	if HiveClanState == null or not HiveClanState.has_method("intent_apply_to_hive"):
		status_label.text = "Hive application system unavailable."
		return
	var metadata: Variant = _hive_browse_list.get_item_metadata(selected[0])
	if typeof(metadata) != TYPE_DICTIONARY:
		status_label.text = "Selected hive is invalid."
		return
	var hive: Dictionary = metadata as Dictionary
	if not bool(hive.get("can_apply", false)):
		status_label.text = "You cannot apply to that hive right now."
		return
	var result: Dictionary = HiveClanState.call("intent_apply_to_hive", str(hive.get("hive_id", "")), "", "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"player_already_in_hive":
				status_label.text = "Leave your current hive before applying."
			"application_already_pending":
				status_label.text = "Application already pending."
			"invite_already_pending":
				status_label.text = "You already have an invite from that hive."
			"rejoin_cooldown_active":
				status_label.text = "You cannot rejoin that hive yet."
			"hive_member_limit_reached":
				status_label.text = "That hive is full."
			_:
				status_label.text = "Could not submit hive application."
		_refresh_hive_browse_dialog()
		return
	status_label.text = "Application sent to %s." % str(hive.get("name", "that hive"))
	if _hive_browse_dialog != null:
		_hive_browse_dialog.hide()

func _ensure_hive_my_invites_dialog() -> void:
	if _hive_my_invites_dialog != null and is_instance_valid(_hive_my_invites_dialog):
		return
	var dialog := AcceptDialog.new()
	dialog.name = "HiveMyInvitesDialog"
	dialog.title = "My Hive Invites"
	dialog.exclusive = true
	dialog.min_size = Vector2i(620, 480)
	add_child(dialog)
	_hive_my_invites_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HiveMyInvitesVBox"
	body.custom_minimum_size = Vector2(560.0, 360.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var meta := Label.new()
	meta.text = "Review active invites, expired invites, and re-apply paths."
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(meta)
	_apply_font(meta, _font_regular, 12)
	_hive_my_invites_meta_label = meta

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(560.0, 290.0)
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	body.add_child(list)
	_apply_font(list, _font_regular, 12)
	_hive_my_invites_list = list

	var accept_button: Button = dialog.add_button("ACCEPT", false, "accept")
	_apply_font(accept_button, _font_semibold, 12)
	_style_button(accept_button, Color(0.15, 0.11, 0.05), Color(0.84, 0.66, 0.24), Color(0.98, 0.93, 0.80))
	var decline_button: Button = dialog.add_button("DECLINE", false, "decline")
	_apply_font(decline_button, _font_regular, 12)
	_style_button(decline_button, Color(0.18, 0.08, 0.08), Color(0.82, 0.34, 0.28), Color(0.98, 0.92, 0.90))
	var apply_button: Button = dialog.add_button("APPLY", false, "apply")
	_apply_font(apply_button, _font_regular, 12)
	_style_button(apply_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	_wire_hive_dialog_main_menu(dialog)
	dialog.get_ok_button().text = "CLOSE"
	_apply_font(dialog.get_ok_button(), _font_regular, 12)
	_style_button(dialog.get_ok_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	if not dialog.custom_action.is_connected(_on_hive_my_invites_action):
		dialog.custom_action.connect(_on_hive_my_invites_action)

func _refresh_hive_my_invites_dialog() -> void:
	if _hive_my_invites_list == null or _hive_my_invites_meta_label == null:
		return
	_hive_my_invites_list.clear()
	if HiveClanState == null or not HiveClanState.has_method("get_visible_invites_for_player"):
		_hive_my_invites_meta_label.text = "Hive invites unavailable."
		return
	var invites: Array = HiveClanState.call("get_visible_invites_for_player") as Array
	_hive_my_invites_meta_label.text = "Invites linked to your player: %d" % invites.size()
	for invite_any in invites:
		if typeof(invite_any) != TYPE_DICTIONARY:
			continue
		var invite: Dictionary = invite_any as Dictionary
		var status_text: String = str(invite.get("status", "pending")).capitalize()
		if str(invite.get("status", "")) == "pending":
			var hours_left: int = maxi(0, int(ceil(float(int(invite.get("expires_at_unix", 0)) - Time.get_unix_time_from_system()) / 3600.0)))
			status_text = "Pending • %dh left" % hours_left
		elif bool(invite.get("can_apply", false)):
			status_text = "Expired • Apply available"
		var label: String = "%s | invited by %s | %s" % [
			str(invite.get("hive_name", "Hive")),
			str(invite.get("created_by_display_name", "Leader")),
			status_text
		]
		var offer: Dictionary = invite.get("offer_bundle", {}) as Dictionary
		if not offer.is_empty():
			label += " | %s" % str(offer.get("title", "Honey Gift"))
		_hive_my_invites_list.add_item(label)
		var idx: int = _hive_my_invites_list.get_item_count() - 1
		_hive_my_invites_list.set_item_metadata(idx, invite.duplicate(true))
	if invites.is_empty():
		_hive_my_invites_meta_label.text = "No hive invites yet."

func _open_hive_my_invites_dialog() -> void:
	_ensure_hive_my_invites_dialog()
	_refresh_hive_my_invites_dialog()
	if _hive_my_invites_dialog == null:
		return
	_hive_my_invites_dialog.popup_centered()

func _on_hive_my_invites_action(action: StringName) -> void:
	if _hive_my_invites_list == null:
		return
	var selected: PackedInt32Array = _hive_my_invites_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Select an invite first."
		return
	var metadata: Variant = _hive_my_invites_list.get_item_metadata(selected[0])
	if typeof(metadata) != TYPE_DICTIONARY:
		status_label.text = "Selected invite is invalid."
		return
	var invite: Dictionary = metadata as Dictionary
	if HiveClanState == null:
		status_label.text = "Hive system unavailable."
		return
	match String(action):
		"accept":
			if not HiveClanState.has_method("intent_accept_invite"):
				status_label.text = "Invite accept unavailable."
				return
			var accept_result: Dictionary = HiveClanState.call("intent_accept_invite", str(invite.get("invite_id", "")), "", "") as Dictionary
			if not bool(accept_result.get("ok", false)):
				var accept_reason: String = str(accept_result.get("reason", "unknown"))
				match accept_reason:
					"player_already_in_hive":
						status_label.text = "Leave your current hive first."
					"rejoin_cooldown_active":
						status_label.text = "You cannot rejoin that hive yet."
					"hive_member_limit_reached":
						status_label.text = "That hive is full."
					"invite_not_pending":
						status_label.text = "That invite is no longer active."
					_:
						status_label.text = "Could not accept invite."
				_refresh_hive_my_invites_dialog()
				return
			status_label.text = "Joined %s." % str(invite.get("hive_name", "the hive"))
			if _hive_my_invites_dialog != null:
				_hive_my_invites_dialog.hide()
			_open_dash_panel_from_menu(dash_hive_panel)
		"decline":
			if not HiveClanState.has_method("intent_decline_invite"):
				status_label.text = "Invite decline unavailable."
				return
			var decline_result: Dictionary = HiveClanState.call("intent_decline_invite", str(invite.get("invite_id", "")), "") as Dictionary
			if not bool(decline_result.get("ok", false)):
				status_label.text = "Could not decline invite."
				_refresh_hive_my_invites_dialog()
				return
			status_label.text = "Invite declined."
			_refresh_hive_my_invites_dialog()
		"apply":
			if not bool(invite.get("can_apply", false)):
				status_label.text = "That invite cannot be converted into an application right now."
				return
			if not HiveClanState.has_method("intent_apply_to_hive"):
				status_label.text = "Hive application system unavailable."
				return
			var apply_result: Dictionary = HiveClanState.call("intent_apply_to_hive", str(invite.get("hive_id", "")), "", "") as Dictionary
			if not bool(apply_result.get("ok", false)):
				status_label.text = "Could not apply to that hive."
				_refresh_hive_my_invites_dialog()
				return
			status_label.text = "Application sent to %s." % str(invite.get("hive_name", "that hive"))
			_refresh_hive_my_invites_dialog()
		_:
			pass

func _ensure_hive_applications_dialog() -> void:
	if _hive_applications_dialog != null and is_instance_valid(_hive_applications_dialog):
		return
	var dialog := AcceptDialog.new()
	dialog.name = "HiveApplicationsDialog"
	dialog.title = "Hive Applications"
	dialog.exclusive = true
	dialog.min_size = Vector2i(620, 460)
	add_child(dialog)
	_hive_applications_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HiveApplicationsVBox"
	body.custom_minimum_size = Vector2(560.0, 340.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var meta := Label.new()
	meta.text = "Review incoming applications to your hive."
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(meta)
	_apply_font(meta, _font_regular, 12)
	_hive_applications_meta_label = meta

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(560.0, 270.0)
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	body.add_child(list)
	_apply_font(list, _font_regular, 12)
	_hive_applications_list = list

	var approve_button: Button = dialog.add_button("APPROVE", false, "approve")
	_apply_font(approve_button, _font_semibold, 12)
	_style_button(approve_button, Color(0.15, 0.11, 0.05), Color(0.84, 0.66, 0.24), Color(0.98, 0.93, 0.80))
	var decline_button: Button = dialog.add_button("DECLINE", false, "decline")
	_apply_font(decline_button, _font_regular, 12)
	_style_button(decline_button, Color(0.18, 0.08, 0.08), Color(0.82, 0.34, 0.28), Color(0.98, 0.92, 0.90))
	_wire_hive_dialog_main_menu(dialog)
	dialog.get_ok_button().text = "CLOSE"
	_apply_font(dialog.get_ok_button(), _font_regular, 12)
	_style_button(dialog.get_ok_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	if not dialog.custom_action.is_connected(_on_hive_applications_action):
		dialog.custom_action.connect(_on_hive_applications_action)

func _refresh_hive_applications_dialog() -> void:
	if _hive_applications_list == null or _hive_applications_meta_label == null:
		return
	_hive_applications_list.clear()
	if HiveClanState == null or not HiveClanState.has_method("get_received_applications_for_player"):
		_hive_applications_meta_label.text = "Hive application review unavailable."
		return
	var applications: Array = HiveClanState.call("get_received_applications_for_player") as Array
	_hive_applications_meta_label.text = "Applications awaiting review: %d" % applications.size()
	for application_any in applications:
		if typeof(application_any) != TYPE_DICTIONARY:
			continue
		var application: Dictionary = application_any as Dictionary
		var age_hours: int = maxi(0, int(ceil(float(Time.get_unix_time_from_system() - int(application.get("created_at_unix", 0))) / 3600.0)))
		var label: String = "%s | %s | submitted %dh ago" % [
			str(application.get("player_display_name", "Player")),
			str(application.get("hive_name", "Hive")),
			age_hours
		]
		_hive_applications_list.add_item(label)
		var idx: int = _hive_applications_list.get_item_count() - 1
		_hive_applications_list.set_item_metadata(idx, application.duplicate(true))
	if applications.is_empty():
		_hive_applications_meta_label.text = "No pending applications right now."

func _open_hive_applications_dialog() -> void:
	_ensure_hive_applications_dialog()
	_refresh_hive_applications_dialog()
	if _hive_applications_dialog == null:
		return
	_hive_applications_dialog.popup_centered()

func _on_hive_applications_action(action: StringName) -> void:
	if _hive_applications_list == null:
		return
	var selected: PackedInt32Array = _hive_applications_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Select an application first."
		return
	var metadata: Variant = _hive_applications_list.get_item_metadata(selected[0])
	if typeof(metadata) != TYPE_DICTIONARY:
		status_label.text = "Selected application is invalid."
		return
	if HiveClanState == null or not HiveClanState.has_method("intent_review_application"):
		status_label.text = "Hive application review unavailable."
		return
	var application: Dictionary = metadata as Dictionary
	var approve: bool = String(action) == "approve"
	var result: Dictionary = HiveClanState.call("intent_review_application", str(application.get("application_id", "")), approve, "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"forbidden":
				status_label.text = "Only queen or soldiers can review applications."
			"hive_member_limit_reached":
				status_label.text = "Hive member limit reached."
			"player_already_in_hive":
				status_label.text = "Applicant already joined a hive."
			_:
				status_label.text = "Could not review application."
		_refresh_hive_applications_dialog()
		return
	status_label.text = "%s %s." % [
		str(application.get("player_display_name", "Applicant")),
		"approved" if approve else "declined"
	]
	_refresh_hive_applications_dialog()

func _ensure_hive_member_actions_dialog() -> void:
	if _hive_member_actions_dialog != null and is_instance_valid(_hive_member_actions_dialog):
		return
	var dialog := AcceptDialog.new()
	dialog.name = "HiveMemberActionsDialog"
	dialog.title = "Member Actions"
	dialog.exclusive = true
	dialog.min_size = Vector2i(720, 520)
	add_child(dialog)
	_hive_member_actions_dialog = dialog

	var body := VBoxContainer.new()
	body.name = "HiveMemberActionsVBox"
	body.custom_minimum_size = Vector2(640.0, 380.0)
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)

	var meta := Label.new()
	meta.text = "Select a hive member to manage."
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(meta)
	_apply_font(meta, _font_regular, 12)
	_hive_member_actions_meta_label = meta

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(640.0, 240.0)
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	body.add_child(list)
	_apply_font(list, _font_regular, 12)
	_hive_member_actions_list = list
	if not list.item_selected.is_connected(_on_hive_member_actions_selection_changed):
		list.item_selected.connect(_on_hive_member_actions_selection_changed)

	var detail := Label.new()
	detail.text = "Choose a player to see available governance actions."
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(detail)
	_apply_font(detail, _font_regular, 11)
	_hive_member_actions_detail_label = detail

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	body.add_child(action_row)

	var promote_button := Button.new()
	promote_button.text = "PROMOTE SOLDIER"
	promote_button.disabled = true
	promote_button.pressed.connect(_on_hive_member_actions_promote_direct_pressed)
	action_row.add_child(promote_button)
	_apply_font(promote_button, _font_semibold, 12)
	_style_button(promote_button, Color(0.15, 0.11, 0.05), Color(0.84, 0.66, 0.24), Color(0.98, 0.93, 0.80))
	_hive_member_actions_promote_button = promote_button

	var vote_promote_button := Button.new()
	vote_promote_button.text = "VOTE PROMOTE"
	vote_promote_button.disabled = true
	vote_promote_button.pressed.connect(_on_hive_member_actions_vote_promote_pressed)
	action_row.add_child(vote_promote_button)
	_apply_font(vote_promote_button, _font_regular, 12)
	_style_button(vote_promote_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	_hive_member_actions_vote_promote_button = vote_promote_button

	var discipline_button := Button.new()
	discipline_button.text = "DISCIPLINE VOTE"
	discipline_button.disabled = true
	discipline_button.pressed.connect(_on_hive_member_actions_discipline_pressed)
	action_row.add_child(discipline_button)
	_apply_font(discipline_button, _font_regular, 12)
	_style_button(discipline_button, Color(0.18, 0.08, 0.08), Color(0.82, 0.34, 0.28), Color(0.98, 0.92, 0.90))
	_hive_member_actions_discipline_button = discipline_button

	var leadership_button := Button.new()
	leadership_button.text = "HIVE VOTE REMOVE"
	leadership_button.disabled = true
	leadership_button.pressed.connect(_on_hive_member_actions_leadership_vote_pressed)
	action_row.add_child(leadership_button)
	_apply_font(leadership_button, _font_regular, 12)
	_style_button(leadership_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	_hive_member_actions_leadership_vote_button = leadership_button

	var remove_button := Button.new()
	remove_button.text = "REMOVE PLAYER"
	remove_button.disabled = true
	remove_button.pressed.connect(_on_hive_member_actions_remove_member_pressed)
	action_row.add_child(remove_button)
	_apply_font(remove_button, _font_regular, 12)
	_style_button(remove_button, Color(0.18, 0.08, 0.08), Color(0.82, 0.34, 0.28), Color(0.98, 0.92, 0.90))
	_hive_member_actions_remove_button = remove_button

	_wire_hive_dialog_main_menu(dialog)
	dialog.get_ok_button().text = "CLOSE"
	_apply_font(dialog.get_ok_button(), _font_regular, 12)
	_style_button(dialog.get_ok_button(), Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))

func _open_hive_member_actions_dialog() -> void:
	var membership: Dictionary = _current_hive_membership()
	if membership.is_empty():
		status_label.text = "Join a hive first."
		return
	_ensure_hive_member_actions_dialog()
	_refresh_hive_member_actions_dialog()
	if _hive_member_actions_dialog == null:
		return
	_hive_member_actions_dialog.popup_centered()

func _open_hive_member_actions_dialog_for_player(player_id: String) -> void:
	var target_player_id: String = str(player_id).strip_edges()
	if target_player_id == "":
		return
	_open_hive_member_actions_dialog()
	if _hive_member_actions_list == null:
		return
	for idx in range(_hive_member_actions_list.item_count):
		var metadata: Variant = _hive_member_actions_list.get_item_metadata(idx)
		if typeof(metadata) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = metadata as Dictionary
		if str(member.get("player_id", "")) != target_player_id:
			continue
		_hive_member_actions_list.select(idx)
		_refresh_hive_member_action_buttons()
		return

func _hive_roster_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for path in [
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember1",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember2",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember3",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember4",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember5",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember6",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember7",
		"DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterList/HiveMember8"
	]:
		var button: Button = get_node_or_null(path) as Button
		if button != null:
			out.append(button)
	return out

func _ensure_hive_roster_button_bindings() -> void:
	var buttons: Array[Button] = _hive_roster_buttons()
	for idx in range(buttons.size()):
		var button: Button = buttons[idx]
		if button == null:
			continue
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 50.0)
		_style_button(button, Color(0.09, 0.10, 0.13, 0.18), Color(0.28, 0.31, 0.38, 0.28), Color(0.93, 0.94, 0.97, 1.0))
		var callable := Callable(self, "_on_hive_roster_row_pressed").bind(idx)
		if not button.pressed.is_connected(callable):
			button.pressed.connect(callable)

func _on_hive_roster_row_pressed(index: int) -> void:
	var buttons: Array[Button] = _hive_roster_buttons()
	if index < 0 or index >= buttons.size():
		return
	var button: Button = buttons[index]
	if button == null:
		return
	if _hive_panel_view_mode() == HIVE_VIEW_CANDIDATE:
		var preview_hive: Dictionary = button.get_meta("browse_hive", {}) as Dictionary
		if preview_hive.is_empty():
			return
		_hive_candidate_selected_hive_id = str(preview_hive.get("hive_id", ""))
		_sync_hive_panel_profile_from_hive_state()
		return
	if bool(button.get_meta("open_member_actions", false)):
		_open_hive_member_actions_dialog()
		return
	var member_record: Dictionary = button.get_meta("member_record", {}) as Dictionary
	if member_record.is_empty():
		return
	_open_hive_member_actions_dialog_for_player(str(member_record.get("player_id", "")))

func _refresh_hive_member_actions_dialog() -> void:
	if _hive_member_actions_list == null or _hive_member_actions_meta_label == null:
		return
	_hive_member_actions_list.clear()
	var membership: Dictionary = _current_hive_membership()
	if membership.is_empty():
		_hive_member_actions_meta_label.text = "Join a hive first."
		_refresh_hive_member_action_buttons()
		return
	if HiveClanState == null or not HiveClanState.has_method("get_hive_snapshot"):
		_hive_member_actions_meta_label.text = "Hive member actions unavailable."
		_refresh_hive_member_action_buttons()
		return
	var hive: Dictionary = HiveClanState.call("get_hive_snapshot", str(membership.get("hive_id", ""))) as Dictionary
	var members_any: Variant = hive.get("members", [])
	var local_role: String = _role_label(str(membership.get("role", "member")))
	var pending_governance_count: int = 0
	if HiveClanState.has_method("get_pending_governance_actions_for_player"):
		var pending_governance: Array = HiveClanState.call("get_pending_governance_actions_for_player") as Array
		pending_governance_count = pending_governance.size()
	var count: int = 0
	if typeof(members_any) == TYPE_ARRAY:
		for member_any in members_any as Array:
			if typeof(member_any) != TYPE_DICTIONARY:
				continue
			var member: Dictionary = member_any as Dictionary
			var rank_position: int = int(member.get("rank_position", 0))
			var rank_text: String = "#%d" % rank_position if rank_position > 0 else "Unranked"
			var label: String = "%s | %s | %s | H%s" % [
				str(member.get("display_name", "Player")),
				_role_label(str(member.get("role", "member"))),
				rank_text,
				_format_number(int(member.get("honey_contributed", 0)))
			]
			_hive_member_actions_list.add_item(label)
			var idx: int = _hive_member_actions_list.get_item_count() - 1
			_hive_member_actions_list.set_item_metadata(idx, member.duplicate(true))
			count += 1
	_hive_member_actions_meta_label.text = "Hive members: %d | Your role: %s | Pending votes: %d" % [count, local_role, pending_governance_count]
	if count > 0:
		_hive_member_actions_list.select(0)
	_refresh_hive_member_action_buttons()

func _on_hive_member_actions_selection_changed(_index: int) -> void:
	_refresh_hive_member_action_buttons()

func _refresh_hive_member_action_buttons() -> void:
	if _hive_member_actions_detail_label == null:
		return
	var context: Dictionary = _current_hive_member_action_context()
	_hive_member_actions_detail_label.text = str(context.get("detail_text", "Choose a player to see available governance actions."))
	if _hive_member_actions_promote_button != null:
		_hive_member_actions_promote_button.text = "PROMOTE SOLDIER"
		_hive_member_actions_promote_button.disabled = not bool(context.get("can_direct_promote", false))
	if _hive_member_actions_vote_promote_button != null:
		_hive_member_actions_vote_promote_button.text = "VOTE PROMOTE"
		_hive_member_actions_vote_promote_button.disabled = not bool(context.get("can_vote_promote", false))
	if _hive_member_actions_discipline_button != null:
		_hive_member_actions_discipline_button.text = str(context.get("discipline_label", "DISCIPLINE VOTE"))
		_hive_member_actions_discipline_button.disabled = not bool(context.get("can_discipline", false))
	if _hive_member_actions_leadership_vote_button != null:
		_hive_member_actions_leadership_vote_button.text = "HIVE VOTE REMOVE"
		_hive_member_actions_leadership_vote_button.disabled = not bool(context.get("can_leadership_remove", false))
	if _hive_member_actions_remove_button != null:
		_hive_member_actions_remove_button.text = "REMOVE PLAYER"
		_hive_member_actions_remove_button.disabled = not bool(context.get("can_remove_member", false))

func _current_hive_member_action_context() -> Dictionary:
	if _hive_member_actions_list == null:
		return {"detail_text": "Choose a player to see available governance actions."}
	var selected: PackedInt32Array = _hive_member_actions_list.get_selected_items()
	if selected.is_empty():
		return {"detail_text": "Choose a player to see available governance actions."}
	var metadata: Variant = _hive_member_actions_list.get_item_metadata(selected[0])
	if typeof(metadata) != TYPE_DICTIONARY:
		return {"detail_text": "Selected member is invalid."}
	var member: Dictionary = metadata as Dictionary
	var membership: Dictionary = _current_hive_membership()
	if membership.is_empty():
		return {"detail_text": "Join a hive first."}
	if HiveClanState == null or not HiveClanState.has_method("get_hive_snapshot"):
		return {"detail_text": "Hive authority unavailable."}
	var hive: Dictionary = HiveClanState.call("get_hive_snapshot", str(membership.get("hive_id", ""))) as Dictionary
	var local_player_id: String = str(membership.get("player_id", ""))
	var local_role: String = str(membership.get("role", "member")).strip_edges().to_lower()
	var target_player_id: String = str(member.get("player_id", ""))
	var target_role: String = str(member.get("role", "member")).strip_edges().to_lower()
	var target_name: String = str(member.get("display_name", "Player"))
	var rank_position: int = int(member.get("rank_position", 0))
	var rank_text: String = "#%d" % rank_position if rank_position > 0 else "Unranked"
	var last_seen_text: String = _format_hive_membership_age(int(member.get("last_seen_at_unix", int(member.get("joined_at_unix", 0)))))
	var detail_lines: Array[String] = [
		"%s | %s | %s | H%s" % [
			target_name,
			_role_label(target_role),
			rank_text,
			_format_number(int(member.get("honey_contributed", 0)))
		],
		"Joined %s" % _format_hive_membership_age(int(member.get("joined_at_unix", 0))),
		"Last seen %s" % last_seen_text
	]
	var target_is_self: bool = target_player_id == local_player_id
	var can_direct_promote: bool = local_role == "queen" and target_role == "member" and not target_is_self
	var can_vote_promote: bool = target_role == "member" and not target_is_self
	var can_discipline: bool = false
	var discipline_label: String = "DISCIPLINE VOTE"
	if target_role == "queen":
		can_discipline = local_role == "soldier" and not target_is_self
		discipline_label = "VOTE REMOVE QUEEN"
	elif target_role == "soldier":
		can_discipline = (local_role == "queen" or local_role == "soldier") and not target_is_self
		discipline_label = "VOTE DEMOTE SOLDIER"
	var can_leadership_remove: bool = (target_role == "queen" or target_role == "soldier") and not target_is_self and int(hive.get("member_count", 0)) >= 10
	var can_remove_member: bool = local_role == "queen" and target_role == "member" and not target_is_self
	var promotion_votes: Dictionary = _find_hive_vote_snapshot(hive.get("soldier_promotion_votes", []), target_player_id) if target_role == "member" else {}
	if not promotion_votes.is_empty():
		detail_lines.append("Promotion votes: %d/%d" % [int((promotion_votes.get("voter_ids", []) as Array).size()), int(promotion_votes.get("votes_needed", 0))])
	var leadership_votes: Dictionary = _find_hive_vote_snapshot(hive.get("leadership_removal_votes", []), target_player_id) if target_role == "queen" or target_role == "soldier" else {}
	if not leadership_votes.is_empty():
		detail_lines.append("Hive removal votes: %d/%d" % [int((leadership_votes.get("voter_ids", []) as Array).size()), int(leadership_votes.get("votes_needed", 0))])
	if target_role == "queen":
		var queen_vote: Dictionary = hive.get("queen_removal_vote", {}) as Dictionary
		if str(queen_vote.get("queen_player_id", "")) == target_player_id:
			detail_lines.append("Soldier queen-removal votes: %d/%d" % [int((queen_vote.get("voter_ids", []) as Array).size()), int(queen_vote.get("votes_needed", 0))])
	elif target_role == "soldier":
		var demotion_vote: Dictionary = _find_hive_vote_snapshot(hive.get("soldier_demotion_votes", []), target_player_id)
		if not demotion_vote.is_empty():
			detail_lines.append("Queen+soldier demotion votes: %d/2" % int((demotion_vote.get("voter_ids", []) as Array).size()))
	return {
		"target_player_id": target_player_id,
		"target_name": target_name,
		"target_role": target_role,
		"can_direct_promote": can_direct_promote,
		"can_vote_promote": can_vote_promote,
		"can_discipline": can_discipline,
		"discipline_label": discipline_label,
		"can_leadership_remove": can_leadership_remove,
		"can_remove_member": can_remove_member,
		"detail_text": "\n".join(detail_lines)
	}

func _find_hive_vote_snapshot(votes_any: Variant, target_player_id: String) -> Dictionary:
	if typeof(votes_any) != TYPE_ARRAY:
		return {}
	for vote_any in votes_any as Array:
		if typeof(vote_any) != TYPE_DICTIONARY:
			continue
		var vote: Dictionary = vote_any as Dictionary
		if str(vote.get("target_player_id", "")) == target_player_id:
			return vote
	return {}

func _on_hive_member_actions_promote_direct_pressed() -> void:
	var context: Dictionary = _current_hive_member_action_context()
	if not bool(context.get("can_direct_promote", false)):
		status_label.text = "Direct promotion is not available for this selection."
		return
	if HiveClanState == null or not HiveClanState.has_method("intent_set_soldier"):
		status_label.text = "Hive member actions unavailable."
		return
	var hive_id: String = _current_hive_id()
	var result: Dictionary = HiveClanState.call("intent_set_soldier", hive_id, str(context.get("target_player_id", "")), true, "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"forbidden":
				status_label.text = "Only the queen can directly promote soldiers."
			"soldier_limit_reached":
				status_label.text = "Soldier slots are full."
			_:
				status_label.text = "Could not promote member."
		_refresh_hive_member_actions_dialog()
		return
	status_label.text = "%s promoted to Soldier." % str(context.get("target_name", "Member"))
	_refresh_hive_member_actions_dialog()

func _on_hive_member_actions_vote_promote_pressed() -> void:
	var context: Dictionary = _current_hive_member_action_context()
	if not bool(context.get("can_vote_promote", false)):
		status_label.text = "Promotion vote is not available for this selection."
		return
	if HiveClanState == null or not HiveClanState.has_method("intent_vote_promote_soldier"):
		status_label.text = "Hive promotion voting unavailable."
		return
	var hive_id: String = _current_hive_id()
	var result: Dictionary = HiveClanState.call("intent_vote_promote_soldier", hive_id, str(context.get("target_player_id", "")), "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"soldier_limit_reached":
				status_label.text = "Soldier slots are full."
			"target_already_leadership":
				status_label.text = "Player is already in leadership."
			_:
				status_label.text = "Could not cast promotion vote."
		_refresh_hive_member_actions_dialog()
		return
	if bool(result.get("promoted", false)):
		status_label.text = "%s promoted to Soldier." % str(context.get("target_name", "Member"))
	else:
		var vote: Dictionary = result.get("vote", {}) as Dictionary
		status_label.text = "Promotion vote cast for %s (%d/%d)." % [
			str(context.get("target_name", "Member")),
			int((vote.get("voter_ids", []) as Array).size()),
			int(vote.get("votes_needed", 0))
		]
	_refresh_hive_member_actions_dialog()

func _on_hive_member_actions_discipline_pressed() -> void:
	var context: Dictionary = _current_hive_member_action_context()
	if not bool(context.get("can_discipline", false)):
		status_label.text = "Discipline vote is not available for this selection."
		return
	if HiveClanState == null:
		status_label.text = "Hive discipline voting unavailable."
		return
	var hive_id: String = _current_hive_id()
	var target_role: String = str(context.get("target_role", ""))
	if target_role == "queen":
		if not HiveClanState.has_method("intent_vote_remove_queen"):
			status_label.text = "Queen removal voting unavailable."
			return
		var queen_result: Dictionary = HiveClanState.call("intent_vote_remove_queen", hive_id, "") as Dictionary
		if not bool(queen_result.get("ok", false)):
			status_label.text = "Could not cast queen-removal vote."
			_refresh_hive_member_actions_dialog()
			return
		if bool(queen_result.get("queen_removed", false)):
			status_label.text = "Queen removed by soldier vote."
		else:
			var queen_vote: Dictionary = queen_result.get("vote", {}) as Dictionary
			status_label.text = "Queen-removal vote cast (%d/%d)." % [
				int((queen_vote.get("voter_ids", []) as Array).size()),
				int(queen_vote.get("votes_needed", 0))
			]
		_refresh_hive_member_actions_dialog()
		return
	if not HiveClanState.has_method("intent_vote_demote_soldier"):
		status_label.text = "Soldier demotion voting unavailable."
		return
	var result: Dictionary = HiveClanState.call("intent_vote_demote_soldier", hive_id, str(context.get("target_player_id", "")), "") as Dictionary
	if not bool(result.get("ok", false)):
		status_label.text = "Could not cast soldier demotion vote."
		_refresh_hive_member_actions_dialog()
		return
	if bool(result.get("demoted", false)):
		status_label.text = "%s demoted to Member." % str(context.get("target_name", "Soldier"))
	else:
		var vote: Dictionary = result.get("vote", {}) as Dictionary
		status_label.text = "Demotion vote cast for %s (%d/2)." % [
			str(context.get("target_name", "Soldier")),
			int((vote.get("voter_ids", []) as Array).size())
		]
	_refresh_hive_member_actions_dialog()

func _on_hive_member_actions_leadership_vote_pressed() -> void:
	var context: Dictionary = _current_hive_member_action_context()
	if not bool(context.get("can_leadership_remove", false)):
		status_label.text = "Hive leadership vote is not available for this selection."
		return
	if HiveClanState == null or not HiveClanState.has_method("intent_vote_remove_leadership"):
		status_label.text = "Hive-wide leadership vote unavailable."
		return
	var hive_id: String = _current_hive_id()
	var result: Dictionary = HiveClanState.call("intent_vote_remove_leadership", hive_id, str(context.get("target_player_id", "")), "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"not_enough_members_for_leadership_vote":
				status_label.text = "Need at least 10 hive members for a hive-wide leadership vote."
			_:
				status_label.text = "Could not cast hive-wide leadership vote."
		_refresh_hive_member_actions_dialog()
		return
	if bool(result.get("removed", false)):
		status_label.text = "%s removed from leadership." % str(context.get("target_name", "Leader"))
	else:
		var vote: Dictionary = result.get("vote", {}) as Dictionary
		status_label.text = "Hive-wide removal vote cast for %s (%d/%d)." % [
			str(context.get("target_name", "Leader")),
			int((vote.get("voter_ids", []) as Array).size()),
			int(vote.get("votes_needed", 0))
		]
	_refresh_hive_member_actions_dialog()

func _on_hive_member_actions_remove_member_pressed() -> void:
	var context: Dictionary = _current_hive_member_action_context()
	if not bool(context.get("can_remove_member", false)):
		status_label.text = "Remove player is not available for this selection."
		return
	_open_hive_remove_member_dialog(context)

func _check_hive_governance_inbox() -> void:
	if HiveClanState == null or not HiveClanState.has_method("get_pending_governance_actions_for_player"):
		return
	var pending_actions: Array = HiveClanState.call("get_pending_governance_actions_for_player") as Array
	if pending_actions.is_empty():
		return
	status_label.text = "Hive governance vote pending. Resolve it before continuing."
	_open_dash_panel_from_menu(dash_hive_panel)
	if _hive_member_actions_dialog == null or not _hive_member_actions_dialog.visible:
		_open_hive_member_actions_dialog()

func _on_hive_clan_state_changed(_snapshot: Dictionary) -> void:
	_sync_hive_panel_profile_from_hive_state()
	_refresh_hive_panel_action_state()
	_refresh_hive_invite_dialog()
	_refresh_hive_pending_dialog()
	_refresh_hive_browse_dialog()
	_refresh_hive_my_invites_dialog()
	_refresh_hive_applications_dialog()
	_refresh_hive_member_actions_dialog()
	_refresh_hive_rankings_dialog()
	_refresh_hive_tournaments_dialog()
	_check_hive_governance_inbox()
	_block_for_active_hive_tournament("")

func _sync_hive_panel_profile_from_hive_state() -> void:
	_hive_panel_profile = HIVE_PANEL_PROFILE_DEFAULT.duplicate(true)

	var local_player_id: String = ""
	var local_display_name: String = "Player"
	if ProfileManager != null and ProfileManager.has_method("get_user_id"):
		local_player_id = str(ProfileManager.call("get_user_id"))
	if ProfileManager != null and ProfileManager.has_method("get_display_name"):
		local_display_name = str(ProfileManager.call("get_display_name"))

	var local_rank_snapshot: Dictionary = {}
	if RankState != null and RankState.has_method("get_player_snapshot") and not local_player_id.is_empty():
		local_rank_snapshot = RankState.call("get_player_snapshot", local_player_id) as Dictionary
	_hive_panel_profile["local_display_name"] = local_display_name
	_hive_panel_profile["local_honey"] = int(_player_profile.get("honey", 0))
	_hive_panel_profile["local_rank_position"] = int(local_rank_snapshot.get("rank_position", 0))
	_hive_panel_profile["local_tier_id"] = str(local_rank_snapshot.get("tier_id", "DRONE"))
	_hive_panel_profile["local_wax_score"] = float(local_rank_snapshot.get("wax_score", 0.0))

	if HiveClanState == null:
		_refresh_hive_panel()
		return
	if not HiveClanState.has_method("get_player_membership") or not HiveClanState.has_method("get_hive_snapshot"):
		_refresh_hive_panel()
		return

	var membership: Dictionary = HiveClanState.call("get_player_membership") as Dictionary
	var visible_invites: Array = HiveClanState.call("get_visible_invites_for_player") as Array if HiveClanState.has_method("get_visible_invites_for_player") else []
	var pending_applications: Array = HiveClanState.call("get_applications_for_player") as Array if HiveClanState.has_method("get_applications_for_player") else []
	var browse_hives: Array = HiveClanState.call("get_browseable_hives") as Array if HiveClanState.has_method("get_browseable_hives") else []

	if membership.is_empty():
		var sorted_browse_hives: Array = _sort_hive_browser_candidates(browse_hives, float(_hive_panel_profile.get("local_wax_score", 0.0)))
		var selected_hive_id: String = _resolve_hive_browser_selection(sorted_browse_hives)
		var selected_hive: Dictionary = _find_hive_in_list(sorted_browse_hives, selected_hive_id)
		if selected_hive.is_empty() and not sorted_browse_hives.is_empty():
			selected_hive = sorted_browse_hives[0] as Dictionary
			selected_hive_id = str(selected_hive.get("hive_id", ""))
		_hive_candidate_selected_hive_id = selected_hive_id
		_hive_panel_profile["view_mode"] = HIVE_VIEW_CANDIDATE
		_hive_panel_profile["name"] = "Hive Finder"
		_hive_panel_profile["member_role"] = "Free Agent"
		_hive_panel_profile["office_title"] = "No Hive"
		_hive_panel_profile["member_since_text"] = "Browse hives matched near your current rank band."
		_hive_panel_profile["visible_invites"] = visible_invites.duplicate(true)
		_hive_panel_profile["visible_invite_count"] = visible_invites.size()
		_hive_panel_profile["pending_applications"] = pending_applications.duplicate(true)
		_hive_panel_profile["browse_hives"] = sorted_browse_hives.duplicate(true)
		_hive_panel_profile["selected_hive"] = selected_hive.duplicate(true)
		_hive_panel_profile["selected_hive_id"] = selected_hive_id
		_hive_panel_profile["pending_invite_count"] = 0
		_hive_panel_profile["received_application_count"] = 0
		_refresh_hive_panel()
		return

	var hive_id: String = str(membership.get("hive_id", ""))
	if hive_id.is_empty():
		_refresh_hive_panel()
		return
	var hive: Dictionary = HiveClanState.call("get_hive_snapshot", hive_id) as Dictionary
	if hive.is_empty():
		_refresh_hive_panel()
		return

	var members_any: Variant = hive.get("members", [])
	var member_lines: Array[String] = []
	var joined_at_unix: int = 0
	var local_rank: int = 1
	var member_idx: int = 0
	var pending_governance_count: int = 0
	var can_spend_hive_honey: bool = bool(membership.get("can_spend_hive_honey", false))
	if HiveClanState.has_method("get_pending_governance_actions_for_player"):
		var pending_governance: Array = HiveClanState.call("get_pending_governance_actions_for_player") as Array
		pending_governance_count = pending_governance.size()
	if typeof(members_any) == TYPE_ARRAY:
		for member_any in members_any as Array:
			if typeof(member_any) != TYPE_DICTIONARY:
				continue
			var member: Dictionary = member_any as Dictionary
			var rank_position: int = int(member.get("rank_position", 0))
			var rank_text: String = "#%d" % rank_position if rank_position > 0 else "Unranked"
			var last_seen_compact: String = _format_hive_presence_compact(int(member.get("last_seen_at_unix", int(member.get("joined_at_unix", 0)))))
			member_lines.append("%s  %s  %s  H%s  %s" % [
				rank_text,
				str(member.get("display_name", "Player")),
				_role_label(str(member.get("role", "member"))).to_upper(),
				_format_number(int(member.get("honey_contributed", 0))),
				last_seen_compact
			])
			member_idx += 1
			if str(member.get("player_id", "")) == local_player_id:
				joined_at_unix = int(member.get("joined_at_unix", 0))
				local_rank = member_idx
	var office_title: String = _role_label(str(membership.get("role", "member")))
	_hive_panel_profile["view_mode"] = HIVE_VIEW_MEMBER
	_hive_panel_profile["name"] = str(hive.get("name", "My Hive"))
	_hive_panel_profile["member_role"] = office_title
	_hive_panel_profile["office_title"] = office_title
	_hive_panel_profile["member_rank_within_hive"] = local_rank
	_hive_panel_profile["member_since_text"] = _format_hive_membership_age(joined_at_unix)
	_hive_panel_profile["ecosystem_rank"] = maxi(1, int(hive.get("rank_points", 1)))
	_hive_panel_profile["hive_honey"] = int(membership.get("honey_contributed", 0))
	_hive_panel_profile["hive_honey_total"] = int(hive.get("total_honey_contributed", 0))
	_hive_panel_profile["honey_score"] = int(hive.get("hive_honey_strength", 0))
	_hive_panel_profile["members"] = member_lines
	_hive_panel_profile["member_records"] = members_any if typeof(members_any) == TYPE_ARRAY else []
	_hive_panel_profile["hive_id"] = hive_id
	_hive_panel_profile["leave_request"] = membership.get("leave_request", {})
	_hive_panel_profile["invite_only"] = false
	_hive_panel_profile["pending_governance_count"] = pending_governance_count
	_hive_panel_profile["can_spend_hive_honey"] = can_spend_hive_honey
	_hive_panel_profile["rank_breakdown"] = hive.get("rank_breakdown", {})
	var role_key: String = str(membership.get("role", "member")).strip_edges().to_lower()
	var can_manage_invites: bool = role_key == "queen" or role_key == "soldier"
	var can_pin_hive_notice: bool = role_key == "queen" or role_key == "soldier"
	var pending_count: int = 0
	var received_application_count: int = 0
	if HiveClanState.has_method("get_hive_invites"):
		var pending_invites: Array = HiveClanState.call("get_hive_invites", hive_id, "pending") as Array
		pending_count = pending_invites.size()
	if HiveClanState.has_method("get_received_applications_for_player"):
		var received_applications: Array = HiveClanState.call("get_received_applications_for_player") as Array
		received_application_count = received_applications.size()
	_hive_panel_profile["can_manage_invites"] = can_manage_invites
	_hive_panel_profile["can_post_hive_comms"] = true
	_hive_panel_profile["can_pin_hive_notice"] = can_pin_hive_notice
	_hive_panel_profile["pending_invite_count"] = pending_count
	_hive_panel_profile["received_application_count"] = received_application_count
	_hive_panel_profile["visible_invite_count"] = visible_invites.size()
	_hive_panel_profile["tournament_entries"] = (hive.get("tournament_entries", {}) as Dictionary).duplicate(true)
	var tournament_dashboard: Dictionary = HiveClanState.call("get_hive_tournament_dashboard", hive_id, "", local_player_id) as Dictionary if HiveClanState.has_method("get_hive_tournament_dashboard") else {}
	_hive_panel_profile["tournament_dashboard"] = tournament_dashboard.duplicate(true)
	_hive_panel_profile["tournament_status_line"] = _build_hive_tournament_status_line(tournament_dashboard)
	var pinned_notice: Dictionary = hive.get("pinned_notice", {}) as Dictionary
	_hive_panel_profile["pinned_notice_message"] = str(pinned_notice.get("message", "")).strip_edges()
	if pinned_notice.is_empty():
		_hive_panel_profile["pinned_notice_meta"] = ""
	else:
		_hive_panel_profile["pinned_notice_meta"] = "Updated %s" % _format_hive_feed_age(int(pinned_notice.get("updated_at_unix", 0)))
	var about_profile: Dictionary = hive.get("about_profile", {}) as Dictionary
	_hive_panel_profile["about_profile"] = about_profile.duplicate(true)
	_hive_panel_profile["about_message"] = str(about_profile.get("message", "")).strip_edges()
	_hive_panel_profile["about_next_edit_at_unix"] = int(about_profile.get("next_edit_at_unix", 0))
	var comms_lines: Array[String] = []
	var comm_records: Array[Dictionary] = []
	var feed_entries_any: Variant = hive.get("feed_entries", [])
	if typeof(feed_entries_any) == TYPE_ARRAY:
		for feed_any in feed_entries_any as Array:
			if typeof(feed_any) != TYPE_DICTIONARY:
				continue
			var feed: Dictionary = feed_any as Dictionary
			var message: String = str(feed.get("message", "")).strip_edges()
			if message == "":
				continue
			comm_records.append(feed.duplicate(true))
	if comm_records.is_empty():
		comms_lines.append("Pending invites: %d | Applications: %d" % [pending_count, received_application_count])
		comms_lines.append("Governance inbox: %d pending vote(s)" % pending_governance_count)
		comms_lines.append("Hive-only coordination and moderation stay scoped here.")
		comms_lines.append("Pinned notices and recent hive posts appear here.")
	_hive_panel_profile["messages"] = comms_lines
	_hive_panel_profile["message_records"] = comm_records
	var created_at_unix: int = int(hive.get("created_at_unix", 0))
	var seasonal_best_finish: int = int(hive.get("seasonal_best_finish", 0))
	var best_finish_text: String = "#%d" % seasonal_best_finish if seasonal_best_finish > 0 else "Unplaced"
	var earned_milestones_any: Variant = hive.get("honey_earned_milestones", [])
	var spent_milestones_any: Variant = hive.get("honey_spent_milestones", [])
	var earned_milestones: Array[String] = []
	var spent_milestones: Array[String] = []
	if typeof(earned_milestones_any) == TYPE_ARRAY:
		for entry_any in earned_milestones_any as Array:
			var entry: String = str(entry_any).strip_edges()
			if entry != "":
				earned_milestones.append(entry)
	if typeof(spent_milestones_any) == TYPE_ARRAY:
		for entry_any in spent_milestones_any as Array:
			var entry: String = str(entry_any).strip_edges()
			if entry != "":
				spent_milestones.append(entry)
	var achievement_lines: Array[String] = []
	var trophy_records_any: Variant = hive.get("trophy_records", [])
	if typeof(trophy_records_any) == TYPE_ARRAY:
		for trophy_any in trophy_records_any as Array:
			if typeof(trophy_any) != TYPE_DICTIONARY:
				continue
			var trophy: Dictionary = trophy_any as Dictionary
			var title: String = str(trophy.get("title", "")).strip_edges()
			var detail: String = str(trophy.get("detail", "")).strip_edges()
			if title == "" and detail == "":
				continue
			if detail == "":
				achievement_lines.append(title)
			elif title == "":
				achievement_lines.append(detail)
			else:
				achievement_lines.append("%s | %s" % [title, detail])
	var rank_breakdown: Dictionary = hive.get("rank_breakdown", {}) as Dictionary
	achievement_lines.append("Hive rank %s = Members %s x %0.2f (%d award%s, +%s)" % [
		_format_number(int(rank_breakdown.get("total", 0))),
		_format_number(int(rank_breakdown.get("members", 0))),
		float(rank_breakdown.get("multiplier", 1.0)),
		int(rank_breakdown.get("awards", 0)),
		"" if int(rank_breakdown.get("awards", 0)) == 1 else "s",
		_format_number(int(rank_breakdown.get("permanent_bonus", 0)))
	])
	if achievement_lines.is_empty():
		achievement_lines = [
			"Founded %s | Avg service %dd" % [_format_calendar_date(created_at_unix), int(hive.get("avg_member_service_days", 0))],
			"Tournament wins %d | Hive titles %d" % [int(hive.get("tournament_wins", 0)), int(hive.get("hive_championships", 0))],
			"Best season finish: %s" % best_finish_text,
			"No honey milestones unlocked yet" if earned_milestones.is_empty() and spent_milestones.is_empty() else "Milestones active"
		]
	_hive_panel_profile["achievements"] = achievement_lines
	_refresh_hive_panel()

func _hive_panel_view_mode() -> String:
	return str(_hive_panel_profile.get("view_mode", HIVE_VIEW_MEMBER)).strip_edges().to_lower()

func _find_hive_in_list(hives: Array, hive_id: String) -> Dictionary:
	var clean_id: String = hive_id.strip_edges()
	if clean_id == "":
		return {}
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		if str(hive.get("hive_id", "")) == clean_id:
			return hive
	return {}

func _resolve_hive_browser_selection(hives: Array) -> String:
	if not _hive_candidate_selected_hive_id.is_empty():
		var existing: Dictionary = _find_hive_in_list(hives, _hive_candidate_selected_hive_id)
		if not existing.is_empty():
			return _hive_candidate_selected_hive_id
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var pending_invite: Dictionary = hive.get("pending_invite", {}) as Dictionary
		if not pending_invite.is_empty():
			return str(hive.get("hive_id", ""))
	if hives.is_empty():
		return ""
	var first_hive_any: Variant = hives[0]
	return str((first_hive_any as Dictionary).get("hive_id", "")) if typeof(first_hive_any) == TYPE_DICTIONARY else ""

func _sort_hive_browser_candidates(hives: Array, local_wax_score: float) -> Array:
	var out: Array = []
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		out.append((hive_any as Dictionary).duplicate(true))
	out.sort_custom(func(a_any: Variant, b_any: Variant) -> bool:
		var a: Dictionary = a_any as Dictionary
		var b: Dictionary = b_any as Dictionary
		var invite_a: bool = not (a.get("pending_invite", {}) as Dictionary).is_empty()
		var invite_b: bool = not (b.get("pending_invite", {}) as Dictionary).is_empty()
		if invite_a != invite_b:
			return invite_a
		var can_apply_a: bool = bool(a.get("can_apply", false))
		var can_apply_b: bool = bool(b.get("can_apply", false))
		if can_apply_a != can_apply_b:
			return can_apply_a
		var avg_a: float = _average_hive_member_wax(a)
		var avg_b: float = _average_hive_member_wax(b)
		var delta_a: float = absf(avg_a - local_wax_score)
		var delta_b: float = absf(avg_b - local_wax_score)
		if absf(delta_a - delta_b) > 0.001:
			return delta_a < delta_b
		var rank_a: int = int(a.get("rank_points", 0))
		var rank_b: int = int(b.get("rank_points", 0))
		if rank_a != rank_b:
			return rank_a > rank_b
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return out

func _average_hive_member_wax(hive: Dictionary) -> float:
	var members_any: Variant = hive.get("members", [])
	if typeof(members_any) != TYPE_ARRAY:
		return 0.0
	var total: float = 0.0
	var count: int = 0
	for member_any in members_any as Array:
		if typeof(member_any) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_any as Dictionary
		total += float(member.get("wax_score", 0.0))
		count += 1
	if count <= 0:
		return 0.0
	return total / float(count)

func _recent_hive_member_count(hive: Dictionary, lookback_sec: int = 7 * 24 * 60 * 60) -> int:
	var members_any: Variant = hive.get("members", [])
	if typeof(members_any) != TYPE_ARRAY:
		return 0
	var now_unix: int = int(Time.get_unix_time_from_system())
	var count: int = 0
	for member_any in members_any as Array:
		if typeof(member_any) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_any as Dictionary
		var last_seen_at_unix: int = int(member.get("last_seen_at_unix", int(member.get("joined_at_unix", 0))))
		if last_seen_at_unix > 0 and now_unix - last_seen_at_unix <= lookback_sec:
			count += 1
	return count

func _current_hive_id() -> String:
	if HiveClanState == null or not HiveClanState.has_method("get_player_membership"):
		return ""
	var membership: Dictionary = HiveClanState.call("get_player_membership") as Dictionary
	return str(membership.get("hive_id", ""))

func _current_hive_membership() -> Dictionary:
	if HiveClanState == null or not HiveClanState.has_method("get_player_membership"):
		return {}
	return HiveClanState.call("get_player_membership") as Dictionary

func _player_has_hive_membership() -> bool:
	var membership: Dictionary = _current_hive_membership()
	return not str(membership.get("hive_id", "")).strip_edges().is_empty()

func _current_hive_role_key() -> String:
	var membership: Dictionary = _current_hive_membership()
	return str(membership.get("role", "member")).strip_edges().to_lower()

func _on_hive_action_pressed(slot: int) -> void:
	if _hive_panel_view_mode() == HIVE_VIEW_CANDIDATE:
		_on_hive_candidate_action_pressed(slot)
		return
	var role_key: String = _current_hive_role_key()
	if role_key == "queen":
		match slot:
			0:
				_open_hive_post_dialog()
			1:
				_open_hive_pin_dialog()
			2:
				_open_hive_invite_dialog()
			3:
				_open_hive_member_actions_dialog()
			4:
				_open_hive_about_dialog()
			5:
				_open_hive_tournaments_dialog()
			_:
				pass
		return
	if role_key == "soldier":
		match slot:
			0:
				_open_hive_post_dialog()
			1:
				_open_hive_invite_dialog()
			2:
				_open_hive_member_actions_dialog()
			3:
				_submit_hive_remove_queen_vote()
			4:
				_open_hive_leave_dialog()
			_:
				pass
		return
	match slot:
		0:
			_open_hive_post_dialog()
		1:
			_submit_hive_soldier_application()
		2:
			_open_hive_member_actions_dialog()
		3:
			_open_hive_my_invites_dialog()
		4:
			_open_hive_leave_dialog()
		_:
			pass

func _on_hive_candidate_action_pressed(slot: int) -> void:
	var selected_hive: Dictionary = _hive_panel_profile.get("selected_hive", {}) as Dictionary
	match slot:
		0:
			if selected_hive.is_empty():
				status_label.text = "No hive selected yet."
				return
			var pending_invite: Dictionary = selected_hive.get("pending_invite", {}) as Dictionary
			if not pending_invite.is_empty():
				_open_hive_my_invites_dialog()
				return
			_submit_hive_application_from_preview(selected_hive)
		1:
			_open_hive_my_invites_dialog()
		2:
			_open_hive_create_dialog()
		3:
			_open_hive_browse_dialog()
		4:
			status_label.text = "Leadership messaging lands in the next hive pass."
		_:
			pass

func _submit_hive_application_from_preview(hive: Dictionary) -> void:
	if hive.is_empty():
		status_label.text = "Choose a hive first."
		return
	if HiveClanState == null or not HiveClanState.has_method("intent_apply_to_hive"):
		status_label.text = "Hive application system unavailable."
		return
	var pending_application: Dictionary = hive.get("pending_application", {}) as Dictionary
	if not pending_application.is_empty():
		status_label.text = "Application already pending for %s." % str(hive.get("name", "that hive"))
		return
	if not bool(hive.get("can_apply", false)):
		var blocked_until_unix: int = int(hive.get("blocked_until_unix", 0))
		if blocked_until_unix > int(Time.get_unix_time_from_system()):
			status_label.text = "That hive is rejoin-locked for %s." % _format_time_remaining(blocked_until_unix)
		else:
			status_label.text = "You cannot apply to that hive right now."
		return
	var result: Dictionary = HiveClanState.call("intent_apply_to_hive", str(hive.get("hive_id", "")), "", "") as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		match reason:
			"player_already_in_hive":
				status_label.text = "Leave your current hive before applying."
			"application_already_pending":
				status_label.text = "Application already pending."
			"invite_already_pending":
				status_label.text = "You already have an invite from that hive."
			"rejoin_cooldown_active":
				status_label.text = "You cannot rejoin that hive yet."
			"hive_member_limit_reached":
				status_label.text = "That hive is full."
			_:
				status_label.text = "Could not submit hive application."
		_sync_hive_panel_profile_from_hive_state()
		return
	status_label.text = "Application sent to %s." % str(hive.get("name", "that hive"))
	_sync_hive_panel_profile_from_hive_state()

func _refresh_hive_panel_action_state() -> void:
	if hive_action_buttons.is_empty():
		return
	if _hive_panel_view_mode() == HIVE_VIEW_CANDIDATE:
		var selected_hive: Dictionary = _hive_panel_profile.get("selected_hive", {}) as Dictionary
		var visible_invite_count: int = maxi(0, int(_hive_panel_profile.get("visible_invite_count", 0)))
		for idx in range(hive_action_buttons.size()):
			var button: Button = hive_action_buttons[idx] as Button
			if button == null:
				continue
			button.visible = idx < 5
			match idx:
				0:
					if selected_hive.is_empty():
						button.text = "SELECT A HIVE"
						button.disabled = true
					elif not (selected_hive.get("pending_invite", {}) as Dictionary).is_empty():
						button.text = "OPEN INVITE"
						button.disabled = false
					elif not (selected_hive.get("pending_application", {}) as Dictionary).is_empty():
						button.text = "APPLIED"
						button.disabled = true
					elif bool(selected_hive.get("can_apply", false)):
						button.text = "APPLY NOW"
						button.disabled = false
					else:
						button.text = "APPLY LOCKED"
						button.disabled = true
				1:
					button.text = "MY INVITES (%d)" % visible_invite_count
					button.disabled = false
				2:
					button.text = "CREATE HIVE"
					button.disabled = false
				3:
					button.text = "ALL HIVES"
					button.disabled = false
				4:
					button.text = "MESSAGE LEADS"
					button.disabled = true
		return
	var can_manage_invites: bool = bool(_hive_panel_profile.get("can_manage_invites", false))
	var can_post_hive_comms: bool = bool(_hive_panel_profile.get("can_post_hive_comms", false))
	var can_pin_hive_notice: bool = bool(_hive_panel_profile.get("can_pin_hive_notice", false))
	var pending_invite_count: int = maxi(0, int(_hive_panel_profile.get("pending_invite_count", 0)))
	var received_application_count: int = maxi(0, int(_hive_panel_profile.get("received_application_count", 0)))
	var leave_request: Dictionary = _hive_panel_profile.get("leave_request", {}) as Dictionary
	var invite_only: bool = bool(_hive_panel_profile.get("invite_only", false))
	var role_key: String = _current_hive_role_key()
	for action_button_any in hive_action_buttons:
		var action_button: Button = action_button_any as Button
		if action_button != null:
			action_button.visible = true
	if role_key == "queen":
		if hive_action_buttons.size() >= 1:
			var queen_post_button: Button = hive_action_buttons[0] as Button
			if queen_post_button != null:
				queen_post_button.text = "POST"
				queen_post_button.disabled = not can_post_hive_comms
		if hive_action_buttons.size() >= 2:
			var queen_pin_button: Button = hive_action_buttons[1] as Button
			if queen_pin_button != null:
				queen_pin_button.text = "PIN NOTICE"
				queen_pin_button.disabled = not can_pin_hive_notice
		if hive_action_buttons.size() >= 3:
			var queen_invite_button: Button = hive_action_buttons[2] as Button
			if queen_invite_button != null:
				queen_invite_button.text = "INVITE PLAYER"
				queen_invite_button.disabled = not can_manage_invites
		if hive_action_buttons.size() >= 4:
			var queen_members_button: Button = hive_action_buttons[3] as Button
			if queen_members_button != null:
				queen_members_button.text = "MEMBERS (%d)" % received_application_count
				queen_members_button.disabled = false
			if hive_action_buttons.size() >= 5:
				var queen_about_button: Button = hive_action_buttons[4] as Button
				if queen_about_button != null:
					queen_about_button.text = "ABOUT HIVE"
					queen_about_button.disabled = false
			if hive_action_buttons.size() >= 6:
				var queen_tournaments_button: Button = hive_action_buttons[5] as Button
				if queen_tournaments_button != null:
					queen_tournaments_button.text = "TOURNAMENTS"
					queen_tournaments_button.disabled = false
		return
	if role_key == "soldier":
		if hive_action_buttons.size() >= 1:
			var soldier_post_button: Button = hive_action_buttons[0] as Button
			if soldier_post_button != null:
				soldier_post_button.text = "POST"
				soldier_post_button.disabled = not can_post_hive_comms
		if hive_action_buttons.size() >= 2:
			var soldier_invite_button: Button = hive_action_buttons[1] as Button
			if soldier_invite_button != null:
				soldier_invite_button.text = "INVITE PLAYER"
				soldier_invite_button.disabled = not can_manage_invites
		if hive_action_buttons.size() >= 3:
			var soldier_members_button: Button = hive_action_buttons[2] as Button
			if soldier_members_button != null:
				soldier_members_button.text = "MEMBERS"
				soldier_members_button.disabled = false
			if hive_action_buttons.size() >= 4:
				var remove_queen_button: Button = hive_action_buttons[3] as Button
				if remove_queen_button != null:
					remove_queen_button.text = "REMOVE QUEEN"
					remove_queen_button.disabled = false
			if hive_action_buttons.size() >= 5:
				var soldier_leave_button: Button = hive_action_buttons[4] as Button
				if soldier_leave_button != null:
					if leave_request.is_empty():
						soldier_leave_button.text = "LEAVE HIVE"
						soldier_leave_button.disabled = false
					else:
						soldier_leave_button.text = "LEAVING (%s)" % _format_time_remaining(int(leave_request.get("effective_at_unix", 0)))
						soldier_leave_button.disabled = true
			if hive_action_buttons.size() >= 6:
				var soldier_extra_button: Button = hive_action_buttons[5] as Button
				if soldier_extra_button != null:
					soldier_extra_button.visible = false
			return
	if hive_action_buttons.size() >= 1:
		var post_button: Button = hive_action_buttons[0] as Button
		if post_button != null:
			post_button.text = "POST"
			post_button.disabled = not can_post_hive_comms
	if hive_action_buttons.size() >= 2:
		var pin_button: Button = hive_action_buttons[1] as Button
		if pin_button != null:
			pin_button.text = "APPLY SOLDIER"
			pin_button.disabled = invite_only
	if hive_action_buttons.size() >= 3:
		var invite_button: Button = hive_action_buttons[2] as Button
		if invite_button != null:
			invite_button.text = "MEMBERS"
			invite_button.disabled = invite_only
	if hive_action_buttons.size() >= 4:
		var pending_button: Button = hive_action_buttons[3] as Button
		if pending_button != null:
			pending_button.text = "MY INVITES"
			pending_button.disabled = false
	if hive_action_buttons.size() >= 5:
		var leave_button: Button = hive_action_buttons[4] as Button
		if leave_button != null:
			if invite_only:
				leave_button.text = "INVITED ACCESS"
				leave_button.disabled = true
			elif leave_request.is_empty():
				leave_button.text = "LEAVE HIVE"
				leave_button.disabled = false
			else:
				leave_button.text = "LEAVING (%s)" % _format_time_remaining(int(leave_request.get("effective_at_unix", 0)))
				leave_button.disabled = true
	if hive_action_buttons.size() >= 6:
		var extra_button: Button = hive_action_buttons[5] as Button
		if extra_button != null:
			extra_button.visible = false

func _role_label(role: String) -> String:
	match role.strip_edges().to_lower():
		"queen":
			return "Queen"
		"soldier":
			return "Soldier"
		_:
			return "Member"

func _format_hive_membership_age(joined_at_unix: int) -> String:
	var safe_joined_at: int = maxi(0, joined_at_unix)
	if safe_joined_at <= 0:
		return "Member since today"
	var elapsed_sec: int = maxi(0, int(Time.get_unix_time_from_system()) - safe_joined_at)
	var days: int = int(elapsed_sec / 86400)
	if days >= 1:
		return "Member for %dd" % days
	var hours: int = int(elapsed_sec / 3600)
	if hours >= 1:
		return "Member for %dh" % hours
	var minutes: int = int(elapsed_sec / 60)
	if minutes >= 1:
		return "Member for %dm" % minutes
	return "Member since now"

func _format_time_remaining(target_unix: int) -> String:
	var remaining_sec: int = maxi(0, target_unix - int(Time.get_unix_time_from_system()))
	var days: int = int(remaining_sec / 86400)
	if days >= 1:
		var hours_remainder: int = int((remaining_sec % 86400) / 3600)
		return "%dd %dh" % [days, hours_remainder]
	var hours: int = int(remaining_sec / 3600)
	if hours >= 1:
		var minutes_remainder: int = int((remaining_sec % 3600) / 60)
		return "%dh %dm" % [hours, minutes_remainder]
	var minutes: int = maxi(1, int(ceil(float(remaining_sec) / 60.0)))
	return "%dm" % minutes

func _format_hive_presence_compact(last_seen_unix: int) -> String:
	var safe_last_seen: int = maxi(0, last_seen_unix)
	if safe_last_seen <= 0:
		return "seen: ?"
	var elapsed_sec: int = maxi(0, int(Time.get_unix_time_from_system()) - safe_last_seen)
	var days: int = int(elapsed_sec / 86400)
	if days >= 1:
		return "seen %dd" % days
	var hours: int = int(elapsed_sec / 3600)
	if hours >= 1:
		return "seen %dh" % hours
	var minutes: int = int(elapsed_sec / 60)
	if minutes >= 1:
		return "seen %dm" % minutes
	return "seen now"

func _format_hive_join_compact(joined_at_unix: int) -> String:
	var safe_joined_at: int = maxi(0, joined_at_unix)
	if safe_joined_at <= 0:
		return "joined ?"
	var elapsed_sec: int = maxi(0, int(Time.get_unix_time_from_system()) - safe_joined_at)
	var days: int = int(elapsed_sec / 86400)
	if days >= 1:
		return "joined %dd" % days
	var hours: int = int(elapsed_sec / 3600)
	if hours >= 1:
		return "joined %dh" % hours
	var minutes: int = int(elapsed_sec / 60)
	if minutes >= 1:
		return "joined %dm" % minutes
	return "joined now"

func _format_hive_feed_age(created_at_unix: int) -> String:
	var safe_created_at: int = maxi(0, created_at_unix)
	if safe_created_at <= 0:
		return "now"
	var elapsed_sec: int = maxi(0, int(Time.get_unix_time_from_system()) - safe_created_at)
	var days: int = int(elapsed_sec / 86400)
	if days >= 7:
		return _format_calendar_date(safe_created_at)
	if days >= 1:
		return "%dd ago" % days
	var hours: int = int(elapsed_sec / 3600)
	if hours >= 1:
		return "%dh ago" % hours
	var minutes: int = int(elapsed_sec / 60)
	if minutes >= 1:
		return "%dm ago" % minutes
	return "now"

func _hive_feed_type_label(feed_type: String) -> String:
	match feed_type.strip_edges().to_lower():
		"hive_created":
			return "FOUNDING"
		"hive_invite_created", "hive_invite_accepted", "hive_invite_declined":
			return "INVITE"
		"hive_application_created", "hive_application_accepted", "hive_application_declined":
			return "APPLICATION"
		"hive_role_changed", "hive_soldier_promoted", "hive_soldier_demoted":
			return "ROLE"
		"hive_queen_removed", "hive_queen_removal_vote_cast", "hive_leadership_removed_by_hive_vote", "hive_leadership_removal_vote_cast":
			return "GOVERNANCE"
		"hive_leave_requested", "hive_leave_cancelled", "hive_leave_finalized", "hive_member_removed":
			return "ROSTER"
		"hive_honey_recorded", "hive_tournament_entered":
			return "HONEY"
		"hive_tournament_round_started", "hive_tournament_run_submitted", "hive_tournament_round_resolved", "hive_tournament_bracket_won":
			return "TOURNAMENT"
		_:
			return "HIVE"

func _build_hive_feed_row_text(feed: Dictionary) -> String:
	var message: String = str(feed.get("message", "")).strip_edges()
	if message == "":
		return ""
	var header: String = "[%s]  %s" % [
		_hive_feed_type_label(str(feed.get("type", "system"))),
		_format_hive_feed_age(int(feed.get("created_at_unix", 0)))
	]
	return "%s\n%s" % [header, message]

func _build_hive_roster_button_text(member: Dictionary, is_local: bool) -> String:
	var name: String = str(member.get("display_name", "Player"))
	var role_key: String = str(member.get("role", "member")).strip_edges().to_lower()
	var role_text: String = _role_label(role_key).to_upper()
	var rank_position: int = int(member.get("rank_position", 0))
	var rank_text: String = "RANK #%d" % rank_position if rank_position > 0 else "RANK --"
	var honey_text: String = "HONEY %s" % _format_number(int(member.get("honey_contributed", 0)))
	var role_badge: String = "[%s]" % role_text
	if role_key == "queen":
		role_badge = "[QUEEN]"
	elif role_key == "soldier":
		role_badge = "[SOLDIER]"
	var primary: String = "%s  %s  %s" % [role_badge, name, rank_text]
	if is_local:
		primary += "  [YOU]"
	var secondary: String = "%s  |  %s  |  %s" % [
		honey_text,
		_format_hive_join_compact(int(member.get("joined_at_unix", 0))),
		_format_hive_presence_compact(int(member.get("last_seen_at_unix", int(member.get("joined_at_unix", 0)))))
	]
	return "%s\n%s" % [primary, secondary]

func _build_hive_roster_button_tooltip(member: Dictionary) -> String:
	var rank_position: int = int(member.get("rank_position", 0))
	var rank_text: String = "#%d" % rank_position if rank_position > 0 else "Unranked"
	return "%s\nRole: %s\nGlobal rank: %s\nHoney contributed: %s\n%s\nLast seen %s" % [
		str(member.get("display_name", "Player")),
		_role_label(str(member.get("role", "member"))),
		rank_text,
		_format_number(int(member.get("honey_contributed", 0))),
		_format_hive_membership_age(int(member.get("joined_at_unix", 0))),
		_format_hive_presence_compact(int(member.get("last_seen_at_unix", int(member.get("joined_at_unix", 0)))))
	]

func _apply_hive_roster_button_style(button: Button, role: String, is_local: bool) -> void:
	if button == null:
		return
	var bg: Color
	var border: Color
	var text_color: Color
	match role.strip_edges().to_lower():
		"queen":
			bg = Color(0.19, 0.15, 0.06, 0.52)
			border = Color(0.94, 0.76, 0.30, 0.78)
			text_color = Color(0.99, 0.96, 0.87, 1.0)
		"soldier":
			bg = Color(0.11, 0.13, 0.18, 0.42)
			border = Color(0.60, 0.68, 0.90, 0.60)
			text_color = Color(0.92, 0.94, 0.99, 1.0)
		_:
			bg = Color(0.09, 0.10, 0.13, 0.28)
			border = Color(0.34, 0.38, 0.46, 0.34)
			text_color = Color(0.92, 0.94, 0.97, 1.0)
	if is_local:
		bg = bg.lerp(Color(0.16, 0.18, 0.24, 0.50), 0.45)
		border = border.lerp(Color(0.86, 0.90, 0.98, 0.80), 0.50)
	_style_button(button, bg, border, text_color)

func _format_calendar_date(unix_time: int) -> String:
	if unix_time <= 0:
		return "today"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	var month_names: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var month_index: int = clampi(int(dt.get("month", 1)) - 1, 0, month_names.size() - 1)
	return "%s %d, %d" % [month_names[month_index], int(dt.get("day", 1)), int(dt.get("year", 1970))]

func _scaled_ui_font_size(size: int) -> int:
	return maxi(1, int(round(float(size) * UI_TEXT_SCALE)))

func _apply_font(node: Control, font: Font, size: int) -> void:
	UITypography.apply_font(node, font, size, UI_TEXT_SCALE)

func _apply_display_label(node: Control, atlas_size: int, fallback_font: Font, fallback_size: int) -> void:
	UITypography.apply_display_label(node, atlas_size, fallback_font, fallback_size, UI_TEXT_SCALE)

func _apply_free_roll_atlas_font(node: Control, size: int) -> bool:
	return UITypography.apply_free_roll_atlas_font(node, size, UI_TEXT_SCALE)

func _apply_honey_label_shader(label: Label) -> void:
	var shader: Shader = _honey_text_shader_resource()
	if label == null or shader == null:
		return
	var mat: ShaderMaterial = label.material as ShaderMaterial
	if mat == null or mat.shader == null or mat.shader != shader:
		mat = ShaderMaterial.new()
		mat.shader = shader
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
	var shader: Shader = _swarmfront_title_shader_resource()
	if label == null or shader == null:
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
	if mat == null or mat.shader == null or mat.shader != shader:
		mat = ShaderMaterial.new()
		mat.shader = shader
	else:
		mat = mat.duplicate() as ShaderMaterial
	label.material = mat
	mat.set_shader_parameter("backlight_color", Color(1.0, 0.831, 0.0, 1.0))
	mat.set_shader_parameter("halo_core_strength", 1.28)
	mat.set_shader_parameter("halo_outer_strength", 0.86)
	mat.set_shader_parameter("halo_core_radius_px", 4.4)
	mat.set_shader_parameter("halo_outer_radius_px", 15.0)
	mat.set_shader_parameter("wall_spill_strength", 0.36)
	mat.set_shader_parameter("wall_spill_shift_px", 9.0)
	mat.set_shader_parameter("bevel_strength", 0.24)

func _suppress_legacy_brand_banner() -> void:
	var existing_banner: Node = get_node_or_null("BrandBanner")
	if existing_banner != null:
		existing_banner.queue_free()
	if brand_title_label != null:
		brand_title_label.visible = false

func _top_safe_area_inset_px() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var inset: float = 0.0
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	if safe_rect.position.y > 0:
		var window_size: Vector2i = DisplayServer.window_get_size()
		var scale_y: float = 1.0
		if window_size.y > 0:
			scale_y = viewport_size.y / float(window_size.y)
		inset = float(safe_rect.position.y) * scale_y
	if inset <= 0.0 and OS.get_name() == "iOS":
		inset = TOP_CHROME_SAFE_FALLBACK_PX
	return clampf(ceilf(inset), 0.0, TOP_CHROME_SAFE_MAX_PX)

func _visible_control_bottom_px(control: Control) -> float:
	if control == null or not is_instance_valid(control) or not control.visible:
		return 0.0
	var rect: Rect2 = control.get_global_rect()
	return rect.position.y + rect.size.y

func _main_top_chrome_bottom_px() -> float:
	var inset: float = _top_safe_area_inset_px()
	var bottom: float = inset
	if top_bar != null:
		bottom = maxf(bottom, top_bar.offset_top + TOP_BAR_BASE_HEIGHT_PX)
	for control in [_tier_widget, _honey_widget, hive_button, brand_title_label]:
		if control is Control:
			bottom = maxf(bottom, _visible_control_bottom_px(control as Control))
	return ceilf(bottom)

func _main_usable_top_px() -> float:
	return ceilf(_main_top_chrome_bottom_px() + MAIN_USABLE_TOP_GAP_PX)

func _apply_top_safe_area_layout() -> void:
	var inset: float = _top_safe_area_inset_px()
	if top_bar != null:
		top_bar.offset_top = inset
		top_bar.offset_bottom = inset + TOP_BAR_BASE_HEIGHT_PX
	if dash_top_bar != null:
		dash_top_bar.offset_top = inset
		dash_top_bar.offset_bottom = inset + DASH_TOP_BAR_BASE_HEIGHT_PX
	var usable_top: float = _main_usable_top_px()
	if dash_root != null:
		dash_root.offset_top = usable_top
	_apply_main_menu_surface_top(async_vbox, usable_top)
	for panel in [async_weekly_panel, async_monthly_panel, async_yearly_panel]:
		_apply_main_menu_surface_panel(panel as Control, usable_top)
	_apply_hero_panel_usable_top(usable_top)
	if _jukebox_panel != null:
		if _jukebox_panel.has_method("set_content_top_offset"):
			_jukebox_panel.call("set_content_top_offset", usable_top)
		elif _jukebox_panel.has_method("set_top_safe_inset"):
			_jukebox_panel.call("set_top_safe_inset", usable_top)

func _apply_main_menu_surface_top(control: Control, usable_top: float) -> void:
	if control == null:
		return
	control.offset_top = usable_top

func _apply_main_menu_surface_panel(control: Control, usable_top: float) -> void:
	if control == null:
		return
	control.offset_left = MAIN_MENU_SURFACE_SIDE_MARGIN_PX
	control.offset_top = usable_top
	control.offset_right = -MAIN_MENU_SURFACE_SIDE_MARGIN_PX
	control.offset_bottom = -MAIN_MENU_SURFACE_BOTTOM_MARGIN_PX

func _apply_hero_panel_usable_top(usable_top: float) -> void:
	if hero_panel == null:
		return
	var viewport_height: float = get_viewport_rect().size.y
	var anchored_top: float = viewport_height * hero_panel.anchor_top
	hero_panel.offset_top = maxf(0.0, usable_top - anchored_top)

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
	_refresh_profile_handle_labels()
	_refresh_dash_account_snapshot()

func _current_profile_handle() -> String:
	if ProfileManager != null and ProfileManager.has_method("get_display_name"):
		var handle: String = str(ProfileManager.call("get_display_name")).strip_edges()
		if not handle.is_empty():
			return handle
	return "Player"

func _refresh_profile_handle_labels() -> void:
	var handle: String = _current_profile_handle()
	if welcome_handle_label != null:
		var welcome_text: String = "Welcome %s" % handle
		if welcome_handle_label.text != welcome_text:
			welcome_handle_label.text = welcome_text
	if dash_handle_label != null and dash_handle_label.text != handle:
		dash_handle_label.text = handle

func _ensure_honey_widget() -> void:
	if _honey_widget != null:
		return
	var top_bar: Control = $TopBar
	var legacy_honey_label: Label = $TopBar/HoneyLabel
	if top_bar == null or legacy_honey_label == null:
		return
	var widget_any: Variant = _load_packed_scene(HONEY_WIDGET_SCENE_PATH).instantiate()
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
	var widget_any: Variant = _load_packed_scene(TIER_WIDGET_SCENE_PATH).instantiate()
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
	widget_control.mouse_filter = Control.MOUSE_FILTER_STOP
	top_bar.add_child(widget_control)
	top_bar.move_child(widget_control, legacy_rank_label.get_index() + 1)
	legacy_rank_label.visible = false
	_tier_widget = widget_control
	if _tier_widget.has_signal("tier_pressed"):
		var tier_pressed_cb: Callable = Callable(self, "_on_tier_widget_tier_pressed")
		if not _tier_widget.is_connected("tier_pressed", tier_pressed_cb):
			_tier_widget.connect("tier_pressed", tier_pressed_cb)
	if _tier_widget.has_signal("rank_pressed"):
		var rank_pressed_cb: Callable = Callable(self, "_on_tier_widget_rank_pressed")
		if not _tier_widget.is_connected("rank_pressed", rank_pressed_cb):
			_tier_widget.connect("rank_pressed", rank_pressed_cb)

func _bind_profile_honey_signal() -> void:
	if ProfileManager == null:
		return
	if not ProfileManager.has_signal("honey_balance_changed"):
		return
	var callback: Callable = Callable(self, "_on_profile_honey_balance_changed")
	if not ProfileManager.is_connected("honey_balance_changed", callback):
		ProfileManager.connect("honey_balance_changed", callback)

func _bind_profile_dash_signals() -> void:
	if ProfileManager == null:
		return
	if ProfileManager.has_signal("garage_selection_changed"):
		var garage_callback: Callable = Callable(self, "_on_profile_garage_selection_changed")
		if not ProfileManager.is_connected("garage_selection_changed", garage_callback):
			ProfileManager.connect("garage_selection_changed", garage_callback)
	if ProfileManager.has_signal("achievement_granted"):
		var achievement_callback: Callable = Callable(self, "_on_profile_achievement_granted")
		if not ProfileManager.is_connected("achievement_granted", achievement_callback):
			ProfileManager.connect("achievement_granted", achievement_callback)

func _on_profile_honey_balance_changed(new_value: int, _delta: int, _reason: String) -> void:
	var safe_value: int = maxi(0, new_value)
	if safe_value == _current_honey_balance():
		return
	_player_profile["honey"] = safe_value
	_apply_player_profile(_player_profile)

func _on_profile_garage_selection_changed(_category_id: String, _item_id: String) -> void:
	_refresh_dash_active_hero()

func _on_profile_achievement_granted(_achievement_id: String) -> void:
	_refresh_dash_achievement_preview()
	_refresh_dash_account_snapshot()
	_refresh_dash_active_hero()

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
	_refresh_dash_hero_views()

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
	_ensure_dash_tab_heroes()
	_set_dash_top_tab(_dash_active_tab, true)
	_apply_buffs_mode_copy()
	$DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveSub.text = "Membership, trophy case, and hive-only comms."
	_refresh_hive_panel()
	_refresh_hive_panel_action_state()
	_ensure_async_contest_dash_panel()
	$DashPanel/DashBadgesPanel/BadgesCollectionVBox/BadgesTitle.text = "ACHIEVEMENTS"
	$DashPanel/DashBadgesPanel/BadgesCollectionVBox/BadgesSub.text = "Progress meters are placeholder for live achievement hooks."
	_refresh_dash_achievement_preview()
	_refresh_dash_account_snapshot()

func _ensure_dash_tab_heroes() -> void:
	if dash_match_panel == null:
		return
	var match_center: Control = dash_match_panel.get_node_or_null("MatchCenter") as Control
	if match_center != null:
		match_center.visible = false
	if dash_badges_panel != null:
		dash_badges_panel.visible = false
		dash_badges_panel.size_flags_stretch_ratio = 0.0
	dash_match_panel.size_flags_stretch_ratio = 1.0
	if _dash_garage_panel == null:
		_dash_garage_panel = _instantiate_dash_hero(_load_packed_scene(GARAGE_PANEL_SCENE_PATH), "GarageHero")
	if _dash_buffs_hero == null:
		_dash_buffs_hero = _instantiate_dash_hero(_load_packed_scene(DASH_BUFFS_HERO_SCENE_PATH), "BuffsHero")
	if _dash_achievements_hero == null:
		_dash_achievements_hero = _instantiate_dash_hero(_load_packed_scene(DASH_ACHIEVEMENTS_HERO_SCENE_PATH), "AchievementsHero")
	if _dash_friends_panel == null:
		_dash_friends_panel = _build_friends_panel()
	_refresh_dash_hero_views()

func _instantiate_dash_hero(scene: PackedScene, node_name: String) -> Control:
	if dash_match_panel == null or scene == null:
		return null
	var hero_any: Node = scene.instantiate()
	if not (hero_any is Control):
		return null
	var hero: Control = hero_any as Control
	hero.name = node_name
	hero.anchor_left = 0.0
	hero.anchor_top = 0.0
	hero.anchor_right = 1.0
	hero.anchor_bottom = 1.0
	hero.offset_left = 0.0
	hero.offset_top = 0.0
	hero.offset_right = 0.0
	hero.offset_bottom = 0.0
	hero.visible = false
	dash_match_panel.add_child(hero)
	return hero

func _ensure_friends_tab() -> void:
	if dash_tabs == null:
		return
	if _dash_friends_tab != null and is_instance_valid(_dash_friends_tab):
		return
	var button := Button.new()
	button.name = "FriendsTab"
	button.text = "FRIENDS"
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(180.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void:
		_set_dash_top_tab(DASH_HERO_TAB_FRIENDS)
	)
	dash_tabs.add_child(button)
	_dash_friends_tab = button

func _ensure_scholastic_dash_surface() -> void:
	if dash_panel == null or dash_tabs == null:
		return
	if _dash_scholastic_tab == null or not is_instance_valid(_dash_scholastic_tab):
		var button := Button.new()
		button.name = "ScholasticTab"
		button.text = "SFA / SFU"
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(180.0, 44.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.visible = false
		button.pressed.connect(func() -> void:
			if _dash_scholastic_panel != null:
				_open_dash_panel(_dash_scholastic_panel)
		)
		var settings_index: int = dash_settings_tab.get_index() if dash_settings_tab != null else dash_tabs.get_child_count()
		dash_tabs.add_child(button)
		dash_tabs.move_child(button, settings_index)
		_dash_scholastic_tab = button
	if _dash_scholastic_panel == null or not is_instance_valid(_dash_scholastic_panel):
		var scene: PackedScene = _load_packed_scene(SCHOLASTIC_PANEL_SCENE_PATH)
		if scene == null:
			return
		var panel_any: Node = scene.instantiate()
		if not (panel_any is Panel):
			return
		var panel: Panel = panel_any as Panel
		panel.name = "DashScholasticPanel"
		panel.anchor_left = 0.0
		panel.anchor_top = 0.0
		panel.anchor_right = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left = 0.0
		panel.offset_top = 0.0
		panel.offset_right = 0.0
		panel.offset_bottom = 0.0
		panel.visible = false
		dash_panel.add_child(panel)
		if panel.has_signal("close_requested"):
			panel.connect("close_requested", func() -> void:
				_close_dash_panel(panel)
			)
		if panel.has_signal("scholastic_intent_submitted"):
			panel.connect("scholastic_intent_submitted", Callable(self, "_on_scholastic_intent_submitted"))
		_style_panel(panel, Color(0.06, 0.07, 0.1, 0.98), Color(0.45, 0.48, 0.58, 0.8))
		_dash_scholastic_panel = panel

func _bind_scholastic_dashboard_state() -> void:
	var state_node: Node = _scholastic_state()
	if state_node == null or not state_node.has_signal("scholastic_state_changed"):
		_refresh_scholastic_dash_visibility()
		return
	var callback: Callable = Callable(self, "_on_scholastic_state_changed")
	if not state_node.is_connected("scholastic_state_changed", callback):
		state_node.connect("scholastic_state_changed", callback)
	_refresh_scholastic_dash_visibility()

func _on_scholastic_state_changed(_snapshot: Dictionary) -> void:
	_refresh_scholastic_dash_visibility()
	_maybe_show_sfa_join_cta(false)

func _refresh_scholastic_dash_visibility() -> void:
	_ensure_scholastic_dash_surface()
	var visible_for_age: bool = _is_scholastic_dash_age_eligible()
	if _dash_scholastic_tab != null:
		_dash_scholastic_tab.visible = visible_for_age
	if not visible_for_age and _dash_scholastic_panel != null and _dash_scholastic_panel.visible:
		_close_dash_panel(_dash_scholastic_panel)
	_refresh_dash_top_tabs()

func _is_scholastic_dash_age_eligible() -> bool:
	var profile: Dictionary = _current_scholastic_profile()
	if profile.is_empty():
		return false
	var age_years: int = int(profile.get("age_years", -1))
	if age_years >= 0 and age_years < 18:
		return true
	if age_years >= 18 and age_years <= SCHOLASTIC_SFU_MAX_AGE:
		return true
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	var sfu: Dictionary = profile.get("sfu", {}) as Dictionary
	return bool(sfa.get("is_user", false)) or str(sfu.get("sfu_status", "")).strip_edges().to_upper() == "ACTIVE"

func _start_scholastic_cta_timer() -> void:
	if _scholastic_cta_timer != null and is_instance_valid(_scholastic_cta_timer):
		return
	_scholastic_cta_timer = Timer.new()
	_scholastic_cta_timer.name = "ScholasticCtaTimer"
	_scholastic_cta_timer.wait_time = float(SCHOLASTIC_CTA_COOLDOWN_SEC)
	_scholastic_cta_timer.one_shot = false
	_scholastic_cta_timer.timeout.connect(func() -> void:
		_maybe_show_sfa_join_cta(false)
	)
	add_child(_scholastic_cta_timer)
	_scholastic_cta_timer.start()

func _maybe_show_sfa_join_cta(is_boot: bool) -> void:
	if not _should_show_sfa_join_cta():
		return
	var now_unix: int = int(Time.get_unix_time_from_system())
	if not is_boot and now_unix - _scholastic_last_cta_unix < SCHOLASTIC_CTA_COOLDOWN_SEC:
		return
	if _scholastic_cta_dialog != null and is_instance_valid(_scholastic_cta_dialog) and _scholastic_cta_dialog.visible:
		return
	_scholastic_last_cta_unix = now_unix
	_show_sfa_join_cta_dialog()

func _should_show_sfa_join_cta() -> bool:
	var profile: Dictionary = _current_scholastic_profile()
	if profile.is_empty():
		return false
	var age_years: int = int(profile.get("age_years", -1))
	if age_years < 0 or age_years >= 18:
		return false
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	return bool(sfa.get("is_candidate", false)) and not bool(sfa.get("is_user", false))

func _show_sfa_join_cta_dialog() -> void:
	if _scholastic_cta_dialog != null and is_instance_valid(_scholastic_cta_dialog):
		_scholastic_cta_dialog.queue_free()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Join SFA"
	dialog.dialog_text = "Add your high school, city, and state to join your SFA school hive."
	dialog.exclusive = false
	add_child(dialog)
	dialog.get_ok_button().text = "Join SFA"
	dialog.get_cancel_button().text = "Later"
	dialog.confirmed.connect(func() -> void:
		_open_scholastic_dash_from_cta()
	)
	dialog.canceled.connect(func() -> void:
		_scholastic_last_cta_unix = int(Time.get_unix_time_from_system())
	)
	_scholastic_cta_dialog = dialog
	dialog.popup_centered(Vector2i(520, 260))

func _open_scholastic_dash_from_cta() -> void:
	_ensure_scholastic_dash_surface()
	_refresh_scholastic_dash_visibility()
	if _dash_scholastic_panel != null:
		_open_dash_panel(_dash_scholastic_panel)

func _current_scholastic_profile() -> Dictionary:
	var state_node: Node = _scholastic_state()
	if state_node == null or not state_node.has_method("get_player_profile_snapshot"):
		return {}
	return state_node.call("get_player_profile_snapshot", _local_user_id()) as Dictionary

func _scholastic_state() -> Node:
	return get_node_or_null("/root/ScholasticState")

func _on_scholastic_intent_submitted(_intent_name: String, _payload: Dictionary) -> void:
	call_deferred("_refresh_scholastic_dash_visibility")

func _build_friends_panel() -> Control:
	if dash_match_panel == null:
		return null
	var panel := Panel.new()
	panel.name = "FriendsPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.visible = false
	_style_panel(panel, Color(0.07, 0.08, 0.1, 0.92), Color(0.35, 0.36, 0.44, 0.6))
	dash_match_panel.add_child(panel)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	root.offset_left = 24.0
	root.offset_top = 24.0
	root.offset_right = -24.0
	root.offset_bottom = -24.0
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	var title := Label.new()
	title.text = "FRIENDS"
	root.add_child(title)
	_apply_font(title, _font_semibold, 18)

	_friends_empty_label = Label.new()
	_friends_empty_label.text = "No online friends found."
	_friends_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_friends_empty_label)
	_apply_font(_friends_empty_label, _font_regular, 13)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_friends_list_vbox = VBoxContainer.new()
	_friends_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friends_list_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_friends_list_vbox)
	_refresh_friends_panel()
	return panel

func _refresh_friends_panel() -> void:
	if _friends_list_vbox == null:
		return
	for child in _friends_list_vbox.get_children():
		child.queue_free()
	var friends: Array = _online_friends()
	if _friends_empty_label != null:
		_friends_empty_label.visible = friends.is_empty()
	for friend_any in friends:
		if typeof(friend_any) != TYPE_DICTIONARY:
			continue
		var friend: Dictionary = friend_any as Dictionary
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)
		_friends_list_vbox.add_child(row)

		var label := Label.new()
		label.text = str(friend.get("display_name", friend.get("uid", "Friend")))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_apply_font(label, _font_regular, 15)

		var invite_button := Button.new()
		invite_button.text = "INVITE"
		invite_button.custom_minimum_size = Vector2(150.0, 44.0)
		row.add_child(invite_button)
		_apply_font(invite_button, _font_semibold, 13)
		_style_button(invite_button, Color(0.16, 0.14, 0.1), Color(0.75, 0.65, 0.35), Color(0.98, 0.94, 0.8))
		invite_button.pressed.connect(func() -> void:
			_invite_online_friend(friend)
		)

func _online_friends() -> Array:
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null or not handshake.has_method("list_online_friends"):
		return []
	var friend_ids: Array = _local_friend_ids()
	if friend_ids.is_empty():
		return []
	var result: Dictionary = handshake.call("list_online_friends", _local_user_id(), friend_ids) as Dictionary
	if not bool(result.get("ok", false)):
		return []
	var online_any: Variant = result.get("online", [])
	if typeof(online_any) == TYPE_ARRAY:
		return online_any as Array
	return []

func _local_friend_ids() -> Array:
	var rank_state: Node = get_node_or_null("/root/RankState")
	if rank_state == null or not rank_state.has_method("get_player_snapshot"):
		return []
	var player: Dictionary = rank_state.call("get_player_snapshot", _local_user_id()) as Dictionary
	var friends_any: Variant = player.get("friends", [])
	if typeof(friends_any) != TYPE_ARRAY:
		return []
	var out: Array = []
	for friend_any in friends_any as Array:
		var friend_id: String = str(friend_any).strip_edges()
		if friend_id.is_empty() or friend_id == _local_user_id() or out.has(friend_id):
			continue
		out.append(friend_id)
	return out

func _local_user_id() -> String:
	return ProfileManager.get_user_id() if ProfileManager != null else "local"

func _local_display_name() -> String:
	var display_name: String = ProfileManager.get_display_name() if ProfileManager != null else "You"
	return display_name if not display_name.strip_edges().is_empty() else "You"

func _local_vs_profile() -> Dictionary:
	return {
		"uid": _local_user_id(),
		"display_name": _local_display_name()
	}

func _default_friend_vs_options() -> Dictionary:
	return {
		"human_pvp": true
	}

func _invite_online_friend(friend: Dictionary) -> void:
	var friend_uid: String = str(friend.get("uid", "")).strip_edges()
	if friend_uid.is_empty():
		status_label.text = "Friend unavailable."
		return
	_close_top_level_windows(UI_SURFACE_VS_LOBBY)
	if _vs_lobby == null:
		_vs_lobby = preload("res://scenes/ui/VsLobby.tscn").instantiate()
		_vs_lobby.closed.connect(func():
			_vs_lobby.queue_free()
			_vs_lobby = null
		)
		add_child(_vs_lobby)
	if _vs_lobby.has_method("configure"):
		_vs_lobby.call("configure", "1V1", 1, 0, true, _default_friend_vs_options())
	_vs_lobby.visible = true
	if _vs_lobby.has_method("begin_friend_invite"):
		_vs_lobby.call("begin_friend_invite", friend_uid, str(friend.get("display_name", "Friend")))
	status_label.text = "Friend invite sent."

func _start_friend_presence_poll() -> void:
	if _friend_presence_timer != null and is_instance_valid(_friend_presence_timer):
		return
	_friend_presence_timer = Timer.new()
	_friend_presence_timer.name = "FriendPresenceTimer"
	_friend_presence_timer.wait_time = 3.0
	_friend_presence_timer.one_shot = false
	_friend_presence_timer.timeout.connect(_poll_friend_presence)
	add_child(_friend_presence_timer)
	_friend_presence_timer.start()
	call_deferred("_poll_friend_presence")

func _poll_friend_presence() -> void:
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null:
		return
	if handshake.has_method("heartbeat"):
		handshake.call("heartbeat", _local_vs_profile())
	if _dash_active_tab == DASH_HERO_TAB_FRIENDS and _dash_friends_panel != null and _dash_friends_panel.visible:
		_refresh_friends_panel()
	if handshake.has_method("poll_friend_invites"):
		var result: Dictionary = handshake.call("poll_friend_invites", _local_user_id()) as Dictionary
		if not bool(result.get("ok", false)):
			return
		var invites_any: Variant = result.get("invites", [])
		if typeof(invites_any) != TYPE_ARRAY:
			return
		for invite_any in invites_any as Array:
			if typeof(invite_any) != TYPE_DICTIONARY:
				continue
			var invite: Dictionary = invite_any as Dictionary
			if _pending_friend_invite.is_empty():
				_show_friend_invite_dialog(invite)
			return

func _show_friend_invite_dialog(invite: Dictionary) -> void:
	_pending_friend_invite = invite.duplicate(true)
	var dialog := ConfirmationDialog.new()
	dialog.title = "Game Invite"
	dialog.dialog_text = "%s invited you to a match." % str(invite.get("from_name", "A friend"))
	dialog.exclusive = false
	add_child(dialog)
	dialog.get_ok_button().text = "Accept"
	dialog.get_cancel_button().text = "Reject"
	dialog.confirmed.connect(func() -> void:
		_respond_to_pending_friend_invite(true)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		_respond_to_pending_friend_invite(false)
		dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(520, 260))

func _respond_to_pending_friend_invite(accept: bool) -> void:
	if _pending_friend_invite.is_empty():
		return
	var invite: Dictionary = _pending_friend_invite.duplicate(true)
	_pending_friend_invite = {}
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null or not handshake.has_method("respond_friend_invite"):
		return
	var result: Dictionary = handshake.call("respond_friend_invite", str(invite.get("id", "")), _local_vs_profile(), accept) as Dictionary
	if not accept:
		status_label.text = "Invite declined."
		return
	if not bool(result.get("ok", false)):
		status_label.text = "Invite accept failed."
		return
	_open_vs_lobby_from_friend_response(result)

func _open_vs_lobby_from_friend_response(result: Dictionary) -> void:
	_close_top_level_windows(UI_SURFACE_VS_LOBBY)
	if _vs_lobby == null:
		_vs_lobby = preload("res://scenes/ui/VsLobby.tscn").instantiate()
		_vs_lobby.closed.connect(func():
			_vs_lobby.queue_free()
			_vs_lobby = null
		)
		add_child(_vs_lobby)
	var session: Dictionary = result.get("session", {}) as Dictionary
	if _vs_lobby.has_method("configure_existing_session"):
		_vs_lobby.call("configure_existing_session", str(result.get("session_id", "")), "guest", session, "")
	_vs_lobby.visible = true
	status_label.text = "Friend match accepted."

func _set_dash_top_tab(tab_id: String, force_refresh: bool = false) -> void:
	var normalized_tab: String = tab_id.strip_edges().to_lower()
	if normalized_tab != DASH_HERO_TAB_BUFFS and normalized_tab != DASH_HERO_TAB_ACHIEVEMENTS and normalized_tab != DASH_HERO_TAB_FRIENDS:
		normalized_tab = DASH_HERO_TAB_GARAGE
	if not force_refresh and normalized_tab == _dash_active_tab:
		return
	if not force_refresh:
		_play_mm_base_drop_sfx()
	_dash_active_tab = normalized_tab
	_ensure_dash_tab_heroes()
	_refresh_dash_top_tabs()
	_refresh_dash_active_hero()

func _refresh_dash_top_tabs() -> void:
	var active_garage: bool = _dash_active_tab == DASH_HERO_TAB_GARAGE
	var active_buffs: bool = _dash_active_tab == DASH_HERO_TAB_BUFFS
	var active_achievements: bool = _dash_active_tab == DASH_HERO_TAB_ACHIEVEMENTS
	var active_friends: bool = _dash_active_tab == DASH_HERO_TAB_FRIENDS
	if dash_garage_tab != null:
		dash_garage_tab.button_pressed = active_garage
		_apply_dash_top_tab_style(dash_garage_tab, active_garage)
	if dash_buffs_tab != null:
		dash_buffs_tab.button_pressed = active_buffs
		_apply_dash_top_tab_style(dash_buffs_tab, active_buffs)
	if dash_achievements_tab != null:
		dash_achievements_tab.button_pressed = active_achievements
		_apply_dash_top_tab_style(dash_achievements_tab, active_achievements)
	if _dash_friends_tab != null:
		_dash_friends_tab.button_pressed = active_friends
		_apply_dash_top_tab_style(_dash_friends_tab, active_friends)
	if _dash_scholastic_tab != null:
		var active_scholastic: bool = _dash_scholastic_panel != null and _dash_scholastic_panel.visible
		_dash_scholastic_tab.button_pressed = active_scholastic
		_apply_dash_top_tab_style(_dash_scholastic_tab, active_scholastic)
	if dash_settings_tab != null:
		var active_settings: bool = dash_settings_panel != null and dash_settings_panel.visible
		dash_settings_tab.button_pressed = active_settings
		_apply_dash_top_tab_style(dash_settings_tab, active_settings)

func _apply_dash_top_tab_style(button: Button, selected: bool) -> void:
	if button == null:
		return
	if selected:
		_style_button(button, Color(0.19, 0.14, 0.08, 0.98), Color(0.93, 0.74, 0.31, 0.90), Color(0.99, 0.96, 0.88, 1.0))
	else:
		_style_button(button, Color(0.10, 0.11, 0.15, 0.96), Color(0.40, 0.43, 0.52, 0.78), Color(0.90, 0.93, 0.98, 1.0))

func _refresh_dash_active_hero() -> void:
	_ensure_dash_tab_heroes()
	var target: Control = _dash_garage_panel
	if _dash_active_tab == DASH_HERO_TAB_BUFFS:
		target = _dash_buffs_hero
	elif _dash_active_tab == DASH_HERO_TAB_ACHIEVEMENTS:
		target = _dash_achievements_hero
	elif _dash_active_tab == DASH_HERO_TAB_FRIENDS:
		target = _dash_friends_panel
	for hero in [_dash_garage_panel, _dash_buffs_hero, _dash_achievements_hero, _dash_friends_panel]:
		if hero == null:
			continue
		hero.visible = hero == target
	if target != null and target.has_method("refresh_view"):
		target.call("refresh_view")
	if target == _dash_friends_panel:
		_refresh_friends_panel()

func _refresh_dash_hero_views() -> void:
	for hero in [_dash_garage_panel, _dash_buffs_hero, _dash_achievements_hero, _dash_friends_panel]:
		if hero != null and hero.has_method("refresh_view"):
			hero.call("refresh_view")

func _refresh_hive_panel() -> void:
	if not is_inside_tree():
		return
	_ensure_hive_roster_button_bindings()
	if _hive_panel_view_mode() == HIVE_VIEW_CANDIDATE:
		_refresh_hive_candidate_panel()
		return
	var hive_name: String = str(_hive_panel_profile.get("name", "TBD Hive"))
	var hive_tier: String = str(_hive_panel_profile.get("tier", "TBD"))
	var member_role: String = str(_hive_panel_profile.get("member_role", "Member"))
	var member_rank_within_hive: int = maxi(1, int(_hive_panel_profile.get("member_rank_within_hive", 1)))
	var office_title: String = str(_hive_panel_profile.get("office_title", "None"))
	var ecosystem_rank: int = maxi(1, int(_hive_panel_profile.get("ecosystem_rank", 1)))
	var member_since_text: String = str(_hive_panel_profile.get("member_since_text", "Member since today"))
	var hive_honey: int = maxi(0, int(_hive_panel_profile.get("hive_honey", 0)))
	var hive_honey_total: int = maxi(0, int(_hive_panel_profile.get("hive_honey_total", 0)))
	var pending_governance_count: int = maxi(0, int(_hive_panel_profile.get("pending_governance_count", 0)))
	var can_spend_hive_honey: bool = bool(_hive_panel_profile.get("can_spend_hive_honey", false))
	var pinned_notice_message: String = str(_hive_panel_profile.get("pinned_notice_message", "")).strip_edges()
	var pinned_notice_meta: String = str(_hive_panel_profile.get("pinned_notice_meta", "")).strip_edges()
	var season_name: String = str(_hive_panel_profile.get("season_name", "Season TBD"))
	var season_reset_text: String = str(_hive_panel_profile.get("season_reset_text", "Reset timer TBD"))
	var leave_request: Dictionary = _hive_panel_profile.get("leave_request", {}) as Dictionary
	var invite_only: bool = bool(_hive_panel_profile.get("invite_only", false))
	var tournament_status_line: String = str(_hive_panel_profile.get("tournament_status_line", "")).strip_edges()
	var messages_any: Variant = _hive_panel_profile.get("messages", [])
	var message_records_any: Variant = _hive_panel_profile.get("message_records", [])
	var achievements_any: Variant = _hive_panel_profile.get("achievements", [])
	var achievements: Array[String] = []
	var messages: Array[String] = []
	var message_records: Array = message_records_any if typeof(message_records_any) == TYPE_ARRAY else []
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
	var hive_title_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveTitle
	var hive_sub_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveSub
	var hive_honey_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveMetricsRow/HiveHoneyLabel
	var hive_total_honey_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveMetricsRow/HiveTotalHoneyLabel
	var hive_pinned_notice_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HivePinnedNotice
	hive_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hive_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hive_honey_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hive_total_honey_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hive_title_label.text = hive_name.to_upper()
	hive_sub_label.text = "%s | %s | Hive Rank #%d" % [member_role, member_since_text, member_rank_within_hive]
	if not leave_request.is_empty():
		hive_sub_label.text += " | Leaving in %s" % _format_time_remaining(int(leave_request.get("effective_at_unix", 0)))
	hive_honey_label.text = "HIVE HONEY: %s" % _format_number(hive_honey)
	hive_total_honey_label.text = "TOTAL HIVE HONEY: %s" % _format_number(hive_honey_total)
	_refresh_hive_dashboard_menu_row(true)
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveOverviewHeader.text = "MY MEMBERSHIP"
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanName.text = "Leadership: %s" % office_title
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanTag.text = "Time in hive: %s" % member_since_text
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanLeague.text = "Roster rank: #%d" % member_rank_within_hive if not invite_only else "Hive status: Invite access"
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanMembers.text = "Tier %s | Rank pts %s | Spend %s | Votes %d" % [hive_tier, _format_number(ecosystem_rank), "Yes" if can_spend_hive_honey else "No", pending_governance_count]
	var roster_buttons: Array[Button] = _hive_roster_buttons()
	var member_records_any: Variant = _hive_panel_profile.get("member_records", [])
	var member_records: Array = member_records_any if typeof(member_records_any) == TYPE_ARRAY else []
	var visible_member_slots: int = maxi(0, roster_buttons.size() - 1)
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterHeader.text = "HIVE MEMBERS %d/14" % member_records.size()
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivityHeader.text = "TROPHY CASE"
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsHeader.text = "HIVE COMMS"
	if pinned_notice_message == "":
		hive_pinned_notice_label.text = "PINNED NOTICE\nNo pinned notice."
	else:
		hive_pinned_notice_label.text = "PINNED NOTICE\n%s" % pinned_notice_message
		if pinned_notice_meta != "":
			hive_pinned_notice_label.text += "\n%s" % pinned_notice_meta
	var local_player_id: String = ""
	if ProfileManager != null and ProfileManager.has_method("get_user_id"):
		local_player_id = str(ProfileManager.call("get_user_id"))
	var activity_labels: Array[Label] = [
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity1,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity2,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity3,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity4
	]
	var comm_labels: Array[Label] = [
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm1,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm2,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm3,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm4
	]
	for i in range(roster_buttons.size()):
		var roster_button: Button = roster_buttons[i]
		if roster_button == null:
			continue
		roster_button.set_meta("member_record", {})
		roster_button.set_meta("open_member_actions", false)
		roster_button.tooltip_text = ""
		if i < visible_member_slots and i < member_records.size() and typeof(member_records[i]) == TYPE_DICTIONARY:
			var member_record: Dictionary = (member_records[i] as Dictionary).duplicate(true)
			roster_button.text = _build_hive_roster_button_text(member_record, str(member_record.get("player_id", "")) == local_player_id)
			roster_button.disabled = false
			roster_button.tooltip_text = _build_hive_roster_button_tooltip(member_record)
			roster_button.set_meta("member_record", member_record)
			_apply_hive_roster_button_style(roster_button, str(member_record.get("role", "member")), str(member_record.get("player_id", "")) == local_player_id)
		elif i == visible_member_slots and member_records.size() > visible_member_slots:
			roster_button.text = "+%d more members\nOpen full member actions list" % (member_records.size() - visible_member_slots)
			roster_button.disabled = false
			roster_button.set_meta("open_member_actions", true)
			roster_button.tooltip_text = "Open the full hive member actions list."
			_style_button(roster_button, Color(0.08, 0.09, 0.12, 0.24), Color(0.32, 0.36, 0.44, 0.34), Color(0.90, 0.93, 0.98, 1.0))
		elif i == 0:
			roster_button.text = "No hive members yet"
			roster_button.disabled = true
			_style_button(roster_button, Color(0.09, 0.10, 0.13, 0.14), Color(0.24, 0.26, 0.32, 0.18), Color(0.70, 0.73, 0.78, 1.0))
		else:
			roster_button.text = ""
			roster_button.disabled = true
			_style_button(roster_button, Color(0.09, 0.10, 0.13, 0.14), Color(0.24, 0.26, 0.32, 0.18), Color(0.70, 0.73, 0.78, 1.0))
	for i in range(activity_labels.size()):
		if i < achievements.size():
			activity_labels[i].text = achievements[i]
		else:
			activity_labels[i].text = "No trophy case item yet"
	for i in range(comm_labels.size()):
		if i < message_records.size() and typeof(message_records[i]) == TYPE_DICTIONARY:
			comm_labels[i].text = _build_hive_feed_row_text(message_records[i] as Dictionary)
		elif i < messages.size():
			comm_labels[i].text = messages[i]
		else:
			comm_labels[i].text = "No hive comms yet"
	if invite_only:
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveFooter.text = "%s | Invite access active for hive comms." % season_reset_text
	elif leave_request.is_empty():
		if tournament_status_line != "":
			$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveFooter.text = "%s | %s" % [tournament_status_line, season_reset_text]
		else:
			$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveFooter.text = "%s | Hive-only comms stay inside the hive." % season_reset_text
	else:
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveFooter.text = "Leave pending: joins unlock in %s | Same hive locked for 7d after exit." % _format_time_remaining(int(leave_request.get("effective_at_unix", 0)))
	_refresh_hive_panel_action_state()

func _refresh_hive_candidate_panel() -> void:
	var local_honey: int = maxi(0, int(_hive_panel_profile.get("local_honey", int(_player_profile.get("honey", 0)))))
	var local_wax_score: float = float(_hive_panel_profile.get("local_wax_score", 0.0))
	var local_rank_position: int = int(_hive_panel_profile.get("local_rank_position", 0))
	var local_tier_id: String = str(_hive_panel_profile.get("local_tier_id", "DRONE"))
	var selected_hive: Dictionary = _hive_panel_profile.get("selected_hive", {}) as Dictionary
	var browse_hives_any: Variant = _hive_panel_profile.get("browse_hives", [])
	var browse_hives: Array = browse_hives_any if typeof(browse_hives_any) == TYPE_ARRAY else []
	var visible_invites_any: Variant = _hive_panel_profile.get("visible_invites", [])
	var visible_invites: Array = visible_invites_any if typeof(visible_invites_any) == TYPE_ARRAY else []
	var pending_applications_any: Variant = _hive_panel_profile.get("pending_applications", [])
	var pending_applications: Array = pending_applications_any if typeof(pending_applications_any) == TYPE_ARRAY else []
	var hive_title_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveTitle
	var hive_sub_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveSub
	var hive_honey_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveMetricsRow/HiveHoneyLabel
	var hive_total_honey_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveMetricsRow/HiveTotalHoneyLabel
	var hive_pinned_notice_label: Label = $DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HivePinnedNotice
	var activity_labels: Array[Label] = [
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity1,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity2,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity3,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity4
	]
	var comm_labels: Array[Label] = [
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm1,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm2,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm3,
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsList/HiveComm4
	]
	hive_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hive_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hive_honey_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hive_total_honey_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hive_title_label.text = "HIVE FINDER"
	hive_sub_label.text = "No hive yet | Tier %s | %s" % [
		local_tier_id,
		("Global rank #%d" % local_rank_position) if local_rank_position > 0 else "Unranked"
	]
	hive_honey_label.text = "YOUR HONEY: %s" % _format_number(local_honey)
	hive_total_honey_label.text = "YOUR WAX: %s" % _format_number(int(round(local_wax_score)))
	_refresh_hive_dashboard_menu_row(false)
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveOverviewHeader.text = "SELECTED HIVE"
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveRosterHeader.text = "RECOMMENDED HIVES %d" % browse_hives.size()
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivityHeader.text = "HIVE ACCOMPLISHMENTS"
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsHeader.text = "RECRUITMENT + COMMS"

	if selected_hive.is_empty():
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanName.text = "No hive selected yet."
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanTag.text = "Browse current hives or create your own."
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanLeague.text = "Invites: %d | Applications: %d" % [visible_invites.size(), pending_applications.size()]
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanMembers.text = "Browse a hive to inspect its roster, accomplishments, and current feed."
		hive_pinned_notice_label.text = "HIVE PREVIEW\nPick a hive to inspect its activity, accomplishments, and recruitment posture."
		for label in activity_labels:
			label.text = "No hive selected."
		for label in comm_labels:
			label.text = "Browse hives to preview their feed."
		$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveFooter.text = "You are currently unaffiliated. Create a hive or apply to one that matches your rank."
		_refresh_hive_candidate_roster_buttons(browse_hives, "")
		_refresh_hive_panel_action_state()
		return

	var selected_hive_name: String = str(selected_hive.get("name", "Hive"))
	var members_any: Variant = selected_hive.get("members", [])
	var members: Array = members_any if typeof(members_any) == TYPE_ARRAY else []
	var queen_name: String = "Unknown"
	for member_any in members:
		if typeof(member_any) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_any as Dictionary
		if str(member.get("role", "")).strip_edges().to_lower() == "queen":
			queen_name = str(member.get("display_name", "Unknown"))
			break
	var avg_wax_score: float = _average_hive_member_wax(selected_hive)
	var active_member_count: int = _recent_hive_member_count(selected_hive)
	var pending_invite: Dictionary = selected_hive.get("pending_invite", {}) as Dictionary
	var pending_application: Dictionary = selected_hive.get("pending_application", {}) as Dictionary
	var about_profile: Dictionary = selected_hive.get("about_profile", {}) as Dictionary
	var about_message: String = str(about_profile.get("message", "")).strip_edges()
	var preview_summary: String = ""
	if not pending_invite.is_empty():
		preview_summary = "Invite active. You already have a route into this hive."
	elif not pending_application.is_empty():
		preview_summary = "Application pending. Leadership has your request."
	elif bool(selected_hive.get("can_apply", false)):
		preview_summary = "Open to applications. Current profile fits this hive's band."
	else:
		preview_summary = "Recruitment is temporarily locked for this profile."
	var overview_detail: String = "Avg wax %s | Rank pts %s | Active 7d %d/%d" % [
		_format_number(int(round(avg_wax_score))),
		_format_number(int(selected_hive.get("rank_points", 0))),
		active_member_count,
		int(selected_hive.get("member_count", 0))
	]
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanName.text = "%s" % selected_hive_name
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanTag.text = "Queen: %s | Members %d/%d" % [
		queen_name,
		int(selected_hive.get("member_count", 0)),
		int(selected_hive.get("member_limit", 14))
	]
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanLeague.text = overview_detail
	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveClanMembers.text = preview_summary

	var achievement_lines: Array[String] = []
	var trophy_records_any: Variant = selected_hive.get("trophy_records", [])
	if typeof(trophy_records_any) == TYPE_ARRAY:
		for trophy_any in trophy_records_any as Array:
			if typeof(trophy_any) != TYPE_DICTIONARY:
				continue
			var trophy: Dictionary = trophy_any as Dictionary
			var title: String = str(trophy.get("title", "")).strip_edges()
			var detail: String = str(trophy.get("detail", "")).strip_edges()
			if title == "" and detail == "":
				continue
			achievement_lines.append(title if detail == "" else "%s | %s" % [title, detail])
	var selected_rank_breakdown: Dictionary = selected_hive.get("rank_breakdown", {}) as Dictionary
	achievement_lines.append("Hive rank %s = Members %s x %0.2f" % [
		_format_number(int(selected_rank_breakdown.get("total", 0))),
		_format_number(int(selected_rank_breakdown.get("members", 0))),
		float(selected_rank_breakdown.get("multiplier", 1.0))
	])
	if achievement_lines.is_empty():
		achievement_lines = [
			"Founded %s" % _format_calendar_date(int(selected_hive.get("created_at_unix", 0))),
			"Tournament wins %d | Titles %d" % [int(selected_hive.get("tournament_wins", 0)), int(selected_hive.get("hive_championships", 0))],
			"Best season finish %s" % ("#%d" % int(selected_hive.get("seasonal_best_finish", 0)) if int(selected_hive.get("seasonal_best_finish", 0)) > 0 else "Unplaced"),
			"Avg service %dd" % int(selected_hive.get("avg_member_service_days", 0))
		]
	for i in range(activity_labels.size()):
		activity_labels[i].text = achievement_lines[i] if i < achievement_lines.size() else "No accomplishment logged yet."

	var recruitment_note: String = "ABOUT\n%s" % preview_summary
	if about_message != "":
		recruitment_note += "\n%s" % about_message
	else:
		recruitment_note += "\nLeadership is recruiting players near %s wax with %d open seat(s)." % [
			_format_number(int(round(avg_wax_score))),
			maxi(0, int(selected_hive.get("member_limit", 14)) - int(selected_hive.get("member_count", 0)))
		]
	hive_pinned_notice_label.text = recruitment_note

	var feed_lines: Array[String] = []
	var feed_entries_any: Variant = selected_hive.get("feed_entries", [])
	if typeof(feed_entries_any) == TYPE_ARRAY:
		for feed_any in feed_entries_any as Array:
			if typeof(feed_any) != TYPE_DICTIONARY:
				continue
			feed_lines.append(_build_hive_feed_row_text(feed_any as Dictionary))
	if feed_lines.is_empty():
		feed_lines = [
			"Activity: %d members active in the last 7 days." % active_member_count,
			"Requirements: stay active, contribute honey, respond to leadership calls.",
			"Leadership contact opens here in the next hive pass.",
			"Use APPLY NOW or OPEN INVITE to move forward."
		]
	else:
		feed_lines.insert(0, "Requirements: stay active, contribute honey, respond to leadership calls.")
	for i in range(comm_labels.size()):
		comm_labels[i].text = feed_lines[i] if i < feed_lines.size() and str(feed_lines[i]).strip_edges() != "" else "No recruitment note yet."

	$DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveFooter.text = "Selected hive: %s | Invites %d | Pending apps %d" % [
		selected_hive_name,
		visible_invites.size(),
		pending_applications.size()
	]
	_refresh_hive_candidate_roster_buttons(browse_hives, str(selected_hive.get("hive_id", "")))
	_refresh_hive_panel_action_state()

func _refresh_hive_candidate_roster_buttons(hives: Array, selected_hive_id: String) -> void:
	var roster_buttons: Array[Button] = _hive_roster_buttons()
	for i in range(roster_buttons.size()):
		var button: Button = roster_buttons[i]
		if button == null:
			continue
		button.set_meta("member_record", {})
		button.set_meta("open_member_actions", false)
		button.set_meta("browse_hive", {})
		button.tooltip_text = ""
		if i < hives.size() and typeof(hives[i]) == TYPE_DICTIONARY:
			var hive: Dictionary = (hives[i] as Dictionary).duplicate(true)
			var avg_wax_score: int = int(round(_average_hive_member_wax(hive)))
			var status_text: String = "Open"
			if not (hive.get("pending_invite", {}) as Dictionary).is_empty():
				status_text = "Invite"
			elif not (hive.get("pending_application", {}) as Dictionary).is_empty():
				status_text = "Applied"
			elif not bool(hive.get("can_apply", false)):
				status_text = "Locked"
			button.text = "%s\n%d/%d | avg wax %s | %s" % [
				str(hive.get("name", "Hive")),
				int(hive.get("member_count", 0)),
				int(hive.get("member_limit", 14)),
				_format_number(avg_wax_score),
				status_text
			]
			button.disabled = false
			button.set_meta("browse_hive", hive)
			button.tooltip_text = "Preview %s" % str(hive.get("name", "Hive"))
			var selected: bool = str(hive.get("hive_id", "")) == selected_hive_id
			if selected:
				_style_button(button, Color(0.19, 0.14, 0.08, 0.98), Color(0.93, 0.74, 0.31, 0.90), Color(0.99, 0.96, 0.88, 1.0))
			else:
				_style_button(button, Color(0.09, 0.10, 0.13, 0.18), Color(0.28, 0.31, 0.38, 0.28), Color(0.93, 0.94, 0.97, 1.0))
		elif i == 0 and hives.is_empty():
			button.text = "No browseable hives yet"
			button.disabled = true
			_style_button(button, Color(0.09, 0.10, 0.13, 0.14), Color(0.24, 0.26, 0.32, 0.18), Color(0.70, 0.73, 0.78, 1.0))
		else:
			button.text = ""
			button.disabled = true
			_style_button(button, Color(0.09, 0.10, 0.13, 0.14), Color(0.24, 0.26, 0.32, 0.18), Color(0.70, 0.73, 0.78, 1.0))

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
		menu_battle_pass_button,
		menu_jukebox_button
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
			skin_tex.visible = true
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
	menu_right_buttons_row.size_flags_stretch_ratio = 3.0
	var side_buttons: Array[Button] = [
		menu_store_button,
		menu_buffs_button,
		menu_free_roll_button,
		menu_battle_pass_button,
		menu_jukebox_button
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

func _apply_human_mode_skin_to_button(button: Button, mode_id: String, paid: bool, denomination: int, preserve_layout: bool = false) -> void:
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
	if not preserve_layout:
		button.custom_minimum_size = Vector2(144.0, 64.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)
	if preserve_layout:
		_set_layout_driven_icon_width(button, GAME_HUB_HUMAN_ICON_MAX_WIDTH)
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

func _apply_async_cycle_skin_to_button(button: Button, label: String, paid: bool, denomination: int, preserve_layout: bool = false) -> void:
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
	if not preserve_layout:
		button.custom_minimum_size = Vector2(256.0, 96.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)
	if preserve_layout:
		_set_layout_driven_icon_width(button, GAME_HUB_CYCLE_ICON_MAX_WIDTH)
	else:
		button.set("icon_max_width", 240)
	button.add_theme_constant_override("h_separation", 0)
	_style_usd_sprite_button(button, true)

func _apply_async_mode_skin_to_button(button: Button, label: String, paid: bool, denomination: int, preserve_layout: bool = false) -> void:
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
	if not preserve_layout:
		button.custom_minimum_size = Vector2(352.0, 112.0)
	button.set("expand_icon", true)
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)
	if preserve_layout:
		_set_layout_driven_icon_width(button, GAME_HUB_ASYNC_MODE_ICON_MAX_WIDTH)
	else:
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
		var close_font_size: int = 14
		if button == dash_settings_close:
			button.set_meta("sf_close_skin", false)
			button.custom_minimum_size = Vector2(360.0, 132.0)
			close_font_size = 48
		if button == dash_store_close:
			button.set_meta("sf_close_skin_min_w", STORE_CLOSE_SKIN_MIN_WIDTH)
			button.set_meta("sf_close_skin_min_h", STORE_CLOSE_SKIN_MIN_HEIGHT)
		_apply_font(button, _font_regular, close_font_size)
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
	var buffs_vbox: VBoxContainer = $DashPanel/DashBuffsPanel/BuffsVBox
	if buffs_vbox != null:
		buffs_vbox.add_theme_constant_override("separation", 14)
	var body_inner: VBoxContainer = $DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox
	if body_inner != null:
		body_inner.offset_left = 18.0
		body_inner.offset_top = 18.0
		body_inner.offset_right = -18.0
		body_inner.offset_bottom = -18.0
	if buffs_top_row != null:
		buffs_top_row.add_theme_constant_override("separation", 12)
	if buffs_mode_tabs != null:
		buffs_mode_tabs.add_theme_constant_override("separation", 10)
	for mode_button in [buffs_mode_vs_button, buffs_mode_async_button]:
		if mode_button != null:
			mode_button.custom_minimum_size = Vector2(0.0, BUFF_UI_MODE_BUTTON_HEIGHT)
	if buffs_loadout_panel != null:
		buffs_loadout_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buffs_loadout_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		buffs_loadout_panel.size_flags_stretch_ratio = 0.95
	if buffs_loadout_vbox != null:
		buffs_loadout_vbox.offset_left = 14.0
		buffs_loadout_vbox.offset_top = 14.0
		buffs_loadout_vbox.offset_right = -14.0
		buffs_loadout_vbox.offset_bottom = -14.0
		buffs_loadout_vbox.add_theme_constant_override("separation", 12)
	if buffs_slots_row != null:
		buffs_slots_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		buffs_slots_row.size_flags_stretch_ratio = 1.0
		buffs_slots_row.add_theme_constant_override("separation", 8)
	if buffs_library_panel != null:
		buffs_library_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buffs_library_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		buffs_library_panel.size_flags_stretch_ratio = 1.55
	if buffs_library_vbox != null:
		buffs_library_vbox.offset_left = 14.0
		buffs_library_vbox.offset_top = 14.0
		buffs_library_vbox.offset_right = -14.0
		buffs_library_vbox.offset_bottom = -14.0
		buffs_library_vbox.add_theme_constant_override("separation", 10)
	if buffs_detail_panel != null:
		buffs_detail_panel.visible = false

func _ensure_buffs_loadout_top_panel() -> void:
	if _buff_loadout_top_panel != null and is_instance_valid(_buff_loadout_top_panel):
		_buff_loadout_top_panel.custom_minimum_size = Vector2(0.0, BUFF_UI_LOADOUT_TOP_HEIGHT)
		return
	if buffs_loadout_vbox == null:
		return
	var existing: Panel = buffs_loadout_vbox.get_node_or_null("LoadoutTopPanel") as Panel
	if existing != null:
		existing.custom_minimum_size = Vector2(0.0, BUFF_UI_LOADOUT_TOP_HEIGHT)
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
	panel.custom_minimum_size = Vector2(0.0, BUFF_UI_LOADOUT_TOP_HEIGHT)
	buffs_loadout_vbox.add_child(panel)
	buffs_loadout_vbox.move_child(panel, 0)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.name = "LoadoutTopVBox"
	inner.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	inner.offset_left = 10.0
	inner.offset_top = 10.0
	inner.offset_right = -10.0
	inner.offset_bottom = -10.0
	inner.add_theme_constant_override("separation", 8)
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
	owned_vbox.offset_left = 10.0
	owned_vbox.offset_top = 10.0
	owned_vbox.offset_right = -10.0
	owned_vbox.offset_bottom = -10.0
	owned_vbox.add_theme_constant_override("separation", 8)
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
	list.add_theme_constant_override("separation", 6)
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
	_apply_font(header, _font_semibold, BUFF_UI_HEADER_FONT_SIZE)
	_apply_font(empty_label, _font_regular, BUFF_UI_BUTTON_FONT_SIZE)

func _ensure_buffs_cart_ui() -> void:
	if _buff_cart_root != null and is_instance_valid(_buff_cart_root):
		_buff_cart_root.custom_minimum_size = Vector2(0.0, BUFF_UI_CART_HEIGHT)
		if _buff_cart_panel != null and is_instance_valid(_buff_cart_panel):
			_buff_cart_panel.custom_minimum_size = Vector2(0.0, BUFF_UI_CART_PANEL_HEIGHT)
		if _buff_cart_buy_button != null and is_instance_valid(_buff_cart_buy_button):
			_buff_cart_buy_button.custom_minimum_size = Vector2(132.0, 40.0)
			_apply_font(_buff_cart_buy_button, _font_semibold, BUFF_UI_BUTTON_FONT_SIZE)
		if _buff_cart_clear_button != null and is_instance_valid(_buff_cart_clear_button):
			_buff_cart_clear_button.custom_minimum_size = Vector2(118.0, 40.0)
			_apply_font(_buff_cart_clear_button, _font_regular, BUFF_UI_BUTTON_FONT_SIZE)
		_refresh_buffs_cart_ui()
		return
	if buffs_body_vbox == null:
		return
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "BuffCartRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0.0, BUFF_UI_CART_HEIGHT)
	root.add_theme_constant_override("separation", 8)
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
	_apply_font(hint_label, _font_regular, BUFF_UI_SMALL_FONT_SIZE)

	var panel: Panel = Panel.new()
	panel.name = "BuffCartPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0.0, BUFF_UI_CART_PANEL_HEIGHT)
	root.add_child(panel)
	_style_panel(panel, Color(0.08, 0.09, 0.12, 0.92), Color(0.45, 0.48, 0.6, 0.8))

	var panel_vbox: VBoxContainer = VBoxContainer.new()
	panel_vbox.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	panel_vbox.offset_left = 12.0
	panel_vbox.offset_top = 12.0
	panel_vbox.offset_right = -12.0
	panel_vbox.offset_bottom = -12.0
	panel_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(panel_vbox)

	var header: Label = Label.new()
	header.text = "RUNNING TALLY"
	panel_vbox.add_child(header)
	_apply_font(header, _font_semibold, BUFF_UI_HEADER_FONT_SIZE)

	var rows_scroll: ScrollContainer = ScrollContainer.new()
	rows_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_vbox.add_child(rows_scroll)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "BuffCartRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	rows_scroll.add_child(rows)

	var subtotal_row: HBoxContainer = HBoxContainer.new()
	subtotal_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtotal_row.alignment = BoxContainer.ALIGNMENT_END
	subtotal_row.add_theme_constant_override("separation", 10)
	panel_vbox.add_child(subtotal_row)

	var subtotal: Label = Label.new()
	subtotal.name = "BuffCartSubtotal"
	subtotal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtotal.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtotal_row.add_child(subtotal)
	_apply_font(subtotal, _font_semibold, BUFF_UI_BUTTON_FONT_SIZE)

	var clear_button: Button = Button.new()
	clear_button.text = "CLEAR"
	clear_button.custom_minimum_size = Vector2(118.0, 40.0)
	clear_button.pressed.connect(_on_buff_cart_clear_pressed)
	subtotal_row.add_child(clear_button)
	_apply_font(clear_button, _font_regular, BUFF_UI_BUTTON_FONT_SIZE)
	_style_button(clear_button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))

	var buy_button: Button = Button.new()
	buy_button.text = "BUY"
	buy_button.custom_minimum_size = Vector2(132.0, 40.0)
	buy_button.pressed.connect(_on_buff_cart_buy_pressed)
	subtotal_row.add_child(buy_button)
	_apply_font(buy_button, _font_semibold, BUFF_UI_BUTTON_FONT_SIZE)
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
		row.add_theme_constant_override("separation", 8)
		_buff_cart_rows.add_child(row)

		var name_label: Label = Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = _buff_cart_display_name(buff, buff_id)
		name_label.clip_text = true
		row.add_child(name_label)
		_apply_font(name_label, _font_regular, BUFF_UI_SMALL_FONT_SIZE)

		var qty_spin: SpinBox = SpinBox.new()
		qty_spin.custom_minimum_size = Vector2(90.0, 36.0)
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
		_apply_font(qty_spin, _font_regular, BUFF_UI_SMALL_FONT_SIZE)

		var line_label: Label = Label.new()
		line_label.custom_minimum_size = Vector2(104.0, 0.0)
		line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line_label.text = "$%.2f" % line_total
		row.add_child(line_label)
		_apply_font(line_label, _font_regular, BUFF_UI_SMALL_FONT_SIZE)

		var remove_button: Button = Button.new()
		remove_button.text = "X"
		remove_button.custom_minimum_size = Vector2(44.0, 36.0)
		var remove_cb: Callable = Callable(self, "_on_buff_cart_remove_pressed").bind(buff_id)
		remove_button.pressed.connect(remove_cb)
		row.add_child(remove_button)
		_apply_font(remove_button, _font_semibold, BUFF_UI_SMALL_FONT_SIZE)
		_style_button(remove_button, Color(0.12, 0.13, 0.16), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))

	if buff_keys.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "Cart empty. Drag buffs from Store into this cart area."
		_buff_cart_rows.add_child(empty_label)
		_apply_font(empty_label, _font_regular, BUFF_UI_SMALL_FONT_SIZE)
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
	row.add_theme_constant_override("separation", 8)
	buffs_library_vbox.add_child(row)
	if buffs_library_header != null:
		buffs_library_vbox.move_child(row, buffs_library_header.get_index() + 1)
	_buff_category_tabs_row = row
	_buff_category_buttons.clear()
	for filter_id in _buff_filter_order():
		var button: Button = Button.new()
		button.text = _buff_filter_label(filter_id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44)
		_apply_display_label(button, 14, _font_semibold, BUFF_UI_BUTTON_FONT_SIZE)
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
	tier_root.add_theme_constant_override("separation", 10)
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
		tier_vbox.offset_left = 10.0
		tier_vbox.offset_top = 10.0
		tier_vbox.offset_right = -10.0
		tier_vbox.offset_bottom = -10.0
		tier_vbox.add_theme_constant_override("separation", 8)
		panel.add_child(tier_vbox)
		var header: Label = Label.new()
		header.text = tier_id.to_upper()
		tier_vbox.add_child(header)
		_apply_display_label(header, 14, _font_semibold, BUFF_UI_HEADER_FONT_SIZE)
		var tier_scroll: ScrollContainer = ScrollContainer.new()
		tier_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tier_vbox.add_child(tier_scroll)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 1
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
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
	_refresh_dash_active_hero()

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
	_play_store_purchase_sfx()
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
		button.custom_minimum_size = Vector2(0.0, BUFF_UI_LIBRARY_BUTTON_HEIGHT)
		button.clip_text = true
		button.text = "%s%s%s - $%.2f" % [selected_mark, str(buff.get("name", buff_id)), ownership_tag, price_usd]
		_apply_font(button, _font_regular, BUFF_UI_BUTTON_FONT_SIZE)
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
			header.text = tier_id.to_upper()
			_apply_display_label(header, 14, _font_semibold, BUFF_UI_HEADER_FONT_SIZE)
	if buffs_library_header != null:
		buffs_library_header.text = "BUFF STORE %s %s" % [_buff_active_mode.to_upper(), _buff_filter_label(_buff_category_filter)]
		_apply_display_label(buffs_library_header, 15, _font_semibold, BUFF_UI_HEADER_FONT_SIZE)

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
		button.custom_minimum_size = Vector2(0.0, BUFF_UI_SLOT_BUTTON_HEIGHT)
		button.clip_text = true
		_style_button(button, Color(0.10, 0.11, 0.14), Color(0.45, 0.48, 0.6), Color(0.92, 0.92, 0.92))
		_apply_font(button, _font_regular, BUFF_UI_BUTTON_FONT_SIZE)
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
		_buff_owned_header_label.text = "OWNED"
		_apply_display_label(_buff_owned_header_label, 15, _font_semibold, BUFF_UI_HEADER_FONT_SIZE)

func _refresh_buffs_loadout_ui() -> void:
	for idx in range(buffs_slot_buttons.size()):
		var button: Button = buffs_slot_buttons[idx] as Button
		if button == null:
			continue
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, BUFF_UI_SLOT_BUTTON_HEIGHT)
		_apply_font(button, _font_regular, BUFF_UI_BUTTON_FONT_SIZE)
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
		_play_buff_equip_sfx()
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
	_play_buff_equip_sfx()
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
	_play_buff_equip_sfx()
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

func _on_last_match_replay_hero_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _last_replay_is_playing:
				_on_replay_control_pressed(1)
			else:
				_on_replay_control_pressed(0)
			accept_event()

func _ensure_home_replay_player() -> void:
	if hero_vbox == null:
		return
	if _home_replay_panel != null and is_instance_valid(_home_replay_panel):
		return
	_home_replay_panel = Panel.new()
	_home_replay_panel.name = "HomeReplayPlayer"
	_home_replay_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_replay_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home_replay_panel.custom_minimum_size = Vector2(0.0, 210.0)
	hero_vbox.add_child(_home_replay_panel)
	_style_panel(_home_replay_panel, Color(0.06, 0.07, 0.09, 0.78), Color(0.54, 0.50, 0.34, 0.72))

	var vbox := VBoxContainer.new()
	vbox.name = "ReplayVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	vbox.offset_left = 16.0
	vbox.offset_top = 12.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -12.0
	vbox.add_theme_constant_override("separation", 8)
	_home_replay_panel.add_child(vbox)

	_home_replay_map_view = MatchReplayMapViewScript.new()
	_home_replay_map_view.name = "ReplayMapView"
	_home_replay_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_replay_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home_replay_map_view.custom_minimum_size = Vector2(0.0, 180.0)
	vbox.add_child(_home_replay_map_view)

	_home_replay_progress = ProgressBar.new()
	_home_replay_progress.name = "ReplayProgress"
	_home_replay_progress.min_value = 0.0
	_home_replay_progress.max_value = 1.0
	_home_replay_progress.value = 0.0
	_home_replay_progress.show_percentage = false
	_home_replay_progress.custom_minimum_size = Vector2(0.0, 18.0)
	vbox.add_child(_home_replay_progress)

	_home_replay_time_label = Label.new()
	_home_replay_time_label.name = "ReplayTime"
	_home_replay_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_replay_time_label.text = "--:--"
	vbox.add_child(_home_replay_time_label)
	_apply_font(_home_replay_time_label, _font_semibold, 16)
	_home_replay_time_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 1.0))

	_home_replay_rows.clear()
	for i in range(4):
		var row := HBoxContainer.new()
		row.name = "ReplayEvent%d" % (i + 1)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.visible = false
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)
		var time_label := Label.new()
		time_label.custom_minimum_size = Vector2(66.0, 0.0)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(time_label)
		_apply_font(time_label, _font_semibold, 14)
		var event_label := Label.new()
		event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(event_label)
		_apply_font(event_label, _font_regular, 14)
		_home_replay_rows.append({"row": row, "time": time_label, "event": event_label})

	var controls := HBoxContainer.new()
	controls.name = "ReplayControls"
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	vbox.add_child(controls)
	var labels: Array[String] = ["Play", "Pause", "Step", "Speed"]
	_home_replay_buttons.clear()
	for idx in range(labels.size()):
		var button := Button.new()
		button.text = labels[idx]
		button.custom_minimum_size = Vector2(92.0, 38.0)
		controls.add_child(button)
		_apply_font(button, _font_semibold, 13)
		_style_button(button, Color(0.10, 0.11, 0.14), Color(0.45, 0.43, 0.30), Color(0.95, 0.92, 0.80))
		button.pressed.connect(Callable(self, "_on_replay_control_pressed").bind(idx))
		_home_replay_buttons.append(button)

func _ensure_dash_replay_map_view() -> void:
	var timeline_vbox := get_node_or_null("DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox") as VBoxContainer
	if timeline_vbox == null:
		return
	if _dash_replay_map_view != null and is_instance_valid(_dash_replay_map_view):
		return
	_dash_replay_map_view = MatchReplayMapViewScript.new()
	_dash_replay_map_view.name = "ReplayMapView"
	_dash_replay_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dash_replay_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dash_replay_map_view.custom_minimum_size = Vector2(0.0, 360.0)
	timeline_vbox.add_child(_dash_replay_map_view)
	timeline_vbox.move_child(_dash_replay_map_view, 1)
	var header := get_node_or_null("DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayTimelinePanel/ReplayTimelineVBox/ReplayTimelineHeader") as Label
	if header != null:
		header.text = "MATCH MAP"
	for label_any in replay_timeline_times:
		if label_any is Label and (label_any as Label).get_parent() is Control:
			((label_any as Label).get_parent() as Control).visible = false
	var note := get_node_or_null("DashPanel/DashReplayPanel/ReplayVBox/ReplayBody/ReplayBodyVBox/ReplayNote") as Label
	if note != null:
		note.text = "Saved visual replay frames from the most recent match."

func _auto_start_home_replay() -> void:
	if not is_inside_tree():
		return
	if onboarding_overlay != null and onboarding_overlay.visible:
		return
	if _last_replay_data.is_empty():
		return
	if not bool(_last_replay_data.get("is_saved_telemetry", true)):
		return
	_start_replay_playback("Playing latest saved match replay.")

func _open_latest_match_replay(auto_play: bool = false) -> void:
	_refresh_latest_match_replay_cache()
	_replay_direct_mode = false
	if _latest_replay_data.is_empty():
		var empty_data: Dictionary = _empty_saved_replay_data()
		_last_replay_data = empty_data.duplicate(true)
		dash_replay_sub.text = "No saved match replay yet"
		_apply_replay_data(empty_data)
		status_label.text = "Play a match to create the first replay."
		return
	_current_match_index = 0
	dash_replay_sub.text = "Replay - %s" % str(_latest_replay_data.get("title", "Last Match"))
	_apply_replay_data(_latest_replay_data)
	if auto_play:
		_start_replay_playback("Playing latest saved match replay.")
	else:
		status_label.text = "Loaded latest saved match replay."

func _refresh_home_replay_hint() -> void:
	if _latest_replay_data.is_empty():
		_refresh_latest_match_replay_cache()
	if hero_title_label != null:
		hero_title_label.text = "Last Match Replay"
	if hero_sub_label == null:
		return
	if _latest_replay_data.is_empty():
		hero_sub_label.text = "Play a match to save a replay here"
		return
	var map_name: String = str(_latest_replay_data.get("map", "Unknown Map"))
	var duration: String = str(_latest_replay_data.get("duration", "--:--"))
	var result: String = str(_latest_replay_data.get("result", "-"))
	hero_sub_label.text = "%s | %s | %s" % [result, map_name, duration]

func _refresh_latest_match_replay_cache() -> bool:
	_latest_replay_data = _load_latest_saved_match_replay_data()
	return not _latest_replay_data.is_empty()

func _load_latest_saved_match_replay_data() -> Dictionary:
	var latest_path: String = _latest_saved_match_replay_path()
	if latest_path.is_empty():
		return {}
	var payload: Dictionary = _load_match_replay_payload(latest_path)
	if payload.is_empty():
		return {}
	return _build_replay_data_from_telemetry_payload(payload, latest_path)

func _latest_saved_match_replay_path() -> String:
	var dir: DirAccess = DirAccess.open(MATCH_REPLAY_SAVE_DIR)
	if dir == null:
		return ""
	var latest_path: String = ""
	var latest_mtime: int = -1
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if not file_name.to_lower().ends_with(".json"):
			continue
		var path: String = "%s/%s" % [MATCH_REPLAY_SAVE_DIR, file_name]
		var modified_time: int = int(FileAccess.get_modified_time(path))
		if latest_path.is_empty() or modified_time > latest_mtime:
			latest_path = path
			latest_mtime = modified_time
	dir.list_dir_end()
	return latest_path

func _load_match_replay_payload(path: String) -> Dictionary:
	if path.strip_edges().is_empty() or not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser: JSON = JSON.new()
	var err: int = parser.parse(file.get_as_text())
	if err != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data as Dictionary

func _build_replay_data_from_telemetry_payload(payload: Dictionary, source_path: String) -> Dictionary:
	var model: Variant = MatchTelemetryModelScript.from_dict(payload)
	if model == null:
		return {}
	var metadata: Dictionary = _telemetry_object_dictionary(model, "metadata")
	var metrics: Dictionary = _telemetry_object_dictionary(model, "metrics")
	var analysis_summary: Dictionary = _telemetry_object_dictionary(model, "analysis_summary")
	var visual_replay: Dictionary = _telemetry_object_dictionary(model, "replay")
	var events: Array = _telemetry_object_events(model)
	var focus_player_id: int = _telemetry_focus_player_id(metadata, metrics)
	if analysis_summary.is_empty():
		var analyzer: Variant = MatchAnalyzerScript.new()
		if analyzer != null and analyzer.has_method("analyze"):
			var summary_any: Variant = analyzer.call("analyze", model, focus_player_id)
			if typeof(summary_any) == TYPE_DICTIONARY:
				analysis_summary = summary_any as Dictionary
	var result: String = _telemetry_result_label(metadata, focus_player_id)
	var title: String = _telemetry_title(metadata, result)
	return {
		"title": title,
		"result": result,
		"eff": _telemetry_efficiency_label(analysis_summary, metrics),
		"mode": _telemetry_mode_label(metadata),
		"map": _present_replay_token(str(metadata.get("map_id", "Unknown Map"))),
		"duration": _format_replay_duration(float(metadata.get("duration_s", 0.0))),
		"timeline": _telemetry_timeline(events, metadata, visual_replay),
		"visual_replay": visual_replay,
		"analysis": _telemetry_analysis_lines(analysis_summary),
		"source_path": source_path,
		"is_saved_telemetry": true
	}

func _telemetry_object_dictionary(model: Variant, field_name: String) -> Dictionary:
	if not (model is Object):
		return {}
	var value_any: Variant = (model as Object).get(field_name)
	if typeof(value_any) != TYPE_DICTIONARY:
		return {}
	return (value_any as Dictionary).duplicate(true)

func _telemetry_object_events(model: Variant) -> Array:
	var out: Array = []
	if not (model is Object):
		return out
	var events_any: Variant = (model as Object).get("events")
	if typeof(events_any) != TYPE_ARRAY:
		return out
	for event_any in events_any as Array:
		if typeof(event_any) == TYPE_DICTIONARY:
			out.append((event_any as Dictionary).duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("t", 0)) < int(b.get("t", 0))
	)
	return out

func _telemetry_focus_player_id(metadata: Dictionary, metrics: Dictionary) -> int:
	var players_any: Variant = metadata.get("players", [])
	if typeof(players_any) == TYPE_ARRAY:
		for player_any in players_any as Array:
			if typeof(player_any) != TYPE_DICTIONARY:
				continue
			var player: Dictionary = player_any as Dictionary
			if bool(player.get("is_local", false)):
				return int(player.get("seat", 0))
	var metric_players_any: Variant = metrics.get("players", [])
	if typeof(metric_players_any) == TYPE_ARRAY and not (metric_players_any as Array).is_empty():
		return int((metric_players_any as Array)[0])
	return 1

func _telemetry_result_label(metadata: Dictionary, focus_player_id: int) -> String:
	var winner_player_id: int = int(metadata.get("winner_player_id", 0))
	if winner_player_id <= 0:
		return "-"
	return "W" if winner_player_id == focus_player_id else "L"

func _telemetry_title(metadata: Dictionary, result: String) -> String:
	var result_word: String = "Replay"
	if result == "W":
		result_word = "Win"
	elif result == "L":
		result_word = "Loss"
	return "%s - %s" % [result_word, _present_replay_token(str(metadata.get("map_id", "Last Match")))]

func _telemetry_efficiency_label(analysis_summary: Dictionary, metrics: Dictionary) -> String:
	var key_stats_any: Variant = analysis_summary.get("key_stats", [])
	if typeof(key_stats_any) == TYPE_ARRAY:
		for stat_any in key_stats_any as Array:
			if typeof(stat_any) != TYPE_DICTIONARY:
				continue
			var stat: Dictionary = stat_any as Dictionary
			if str(stat.get("label", "")) == "Meaningful APM":
				return "APM %s" % str(stat.get("value", "--"))
	var swing_ms: int = int(metrics.get("swing_moment_ms", 0))
	if swing_ms > 0:
		return "Swing %s" % _format_replay_time(swing_ms)
	return "HE --"

func _telemetry_mode_label(metadata: Dictionary) -> String:
	var vs_mode: String = str(metadata.get("vs_mode", "")).strip_edges()
	if vs_mode != "":
		return _present_replay_token(vs_mode)
	var match_type: int = int(metadata.get("match_type", 0))
	if match_type == int(MatchTelemetryModelScript.MATCH_TYPE_ASYNC):
		return "Async"
	if match_type == int(MatchTelemetryModelScript.MATCH_TYPE_BOT):
		return "Bot Match"
	return "VS"

func _telemetry_timeline(events: Array, metadata: Dictionary, visual_replay: Dictionary = {}) -> Array:
	var timeline: Array = [{"t_ms": 0, "t": "00:00", "event": "Match started", "frame_index": 0}]
	for event_any in events:
		if typeof(event_any) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_any as Dictionary
		var label: String = _telemetry_event_label(event)
		if label.is_empty():
			continue
		var t_ms: int = maxi(0, int(event.get("t", 0)))
		timeline.append({
			"t_ms": t_ms,
			"t": _format_replay_time(t_ms),
			"event": label,
			"frame_index": _frame_index_for_replay_time(visual_replay, t_ms)
		})
	timeline.append_array(_telemetry_replay_control_flow_events(visual_replay))
	timeline.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var at: int = int(a.get("t_ms", 0))
		var bt: int = int(b.get("t_ms", 0))
		if at == bt:
			return str(a.get("event", "")) < str(b.get("event", ""))
		return at < bt
	)
	timeline = _dedupe_replay_timeline(timeline)
	var duration_s: float = float(metadata.get("duration_s", 0.0))
	var winner_player_id: int = int(metadata.get("winner_player_id", 0))
	if duration_s > 0.0:
		var finish_event: String = "Match ended"
		if winner_player_id > 0:
			finish_event = "Player %d won" % winner_player_id
		var finish_ms: int = int(round(duration_s * 1000.0))
		timeline.append({
			"t_ms": finish_ms,
			"t": _format_replay_duration(duration_s),
			"event": finish_event,
			"frame_index": _frame_index_for_replay_time(visual_replay, finish_ms)
		})
	if timeline.size() > 28:
		timeline = _thin_replay_timeline(timeline, 28)
	return timeline

func _telemetry_event_label(event: Dictionary) -> String:
	var event_type: int = int(event.get("e", -1))
	if event_type == int(MatchTelemetryModelScript.EVENT_INTENT):
		return ""
	if event_type == int(MatchTelemetryModelScript.EVENT_COLLISION):
		return ""
	if event_type == int(MatchTelemetryModelScript.EVENT_BUFF_ACTIVATION):
		return ""
	if event_type == int(MatchTelemetryModelScript.EVENT_ARRIVAL):
		var before_owner: int = int(event.get("bo", 0))
		var after_owner: int = int(event.get("ao", before_owner))
		if after_owner > 0 and after_owner != before_owner:
			var verb := "claimed" if before_owner <= 0 else "took"
			return "P%d %s H%d" % [after_owner, verb, int(event.get("h", 0))]
		return ""
	if event_type == int(MatchTelemetryModelScript.EVENT_ACTION):
		var kind: String = str(event.get("k", "")).strip_edges()
		if kind.begins_with("lane_open_"):
			return "P%d opened %s H%d -> H%d" % [
				int(event.get("p", 0)),
				_present_replay_token(kind.trim_prefix("lane_open_")),
				int(event.get("src", 0)),
				int(event.get("dst", 0))
			]
		if kind == "lane_reverse":
			return "P%d reversed H%d -> H%d" % [
				int(event.get("p", 0)),
				int(event.get("src", 0)),
				int(event.get("dst", 0))
			]
		return ""
	if event_type == int(MatchTelemetryModelScript.EVENT_TOWER_KILL):
		return ""
	return ""

func _telemetry_replay_control_flow_events(visual_replay: Dictionary) -> Array:
	var out: Array = []
	var frames_any: Variant = visual_replay.get("frames", [])
	if typeof(frames_any) != TYPE_ARRAY:
		return out
	var peak_by_player: Dictionary = {}
	for frame_index in range((frames_any as Array).size()):
		var frame_any: Variant = (frames_any as Array)[frame_index]
		if typeof(frame_any) != TYPE_DICTIONARY:
			continue
		var frame: Dictionary = frame_any as Dictionary
		var counts: Dictionary = _replay_hive_counts_by_owner(frame)
		for player_any in counts.keys():
			var player_id: int = int(player_any)
			if player_id <= 0:
				continue
			var count: int = int(counts.get(player_any, 0))
			var previous_peak: int = int(peak_by_player.get(player_id, count))
			if not peak_by_player.has(player_id):
				peak_by_player[player_id] = count
				continue
			if count > previous_peak:
				peak_by_player[player_id] = count
				var t_ms: int = maxi(0, int(frame.get("t", 0)))
				out.append({
					"t_ms": t_ms,
					"t": _format_replay_time(t_ms),
					"event": "P%d reached %d hives" % [player_id, count],
					"frame_index": frame_index,
					"priority": 1
				})
	return out

func _replay_hive_counts_by_owner(frame: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	var hives_any: Variant = frame.get("h", [])
	if typeof(hives_any) != TYPE_ARRAY:
		return counts
	for hive_any in hives_any as Array:
		if typeof(hive_any) != TYPE_ARRAY:
			continue
		var row: Array = hive_any as Array
		if row.size() < 2:
			continue
		var owner_id: int = int(row[1])
		if owner_id <= 0:
			continue
		counts[owner_id] = int(counts.get(owner_id, 0)) + 1
	return counts

func _dedupe_replay_timeline(timeline: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for entry_any in timeline:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var key := "%d|%s" % [int(entry.get("t_ms", 0)), str(entry.get("event", ""))]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(entry)
	return out

func _thin_replay_timeline(timeline: Array, max_count: int) -> Array:
	if timeline.size() <= max_count:
		return timeline
	var head: Dictionary = timeline.front() as Dictionary
	var tail: Dictionary = timeline.back() as Dictionary
	var middle: Array = timeline.slice(1, timeline.size() - 1)
	var step: float = float(middle.size()) / float(maxi(1, max_count - 2))
	var thinned: Array = [head]
	var cursor := 0.0
	while thinned.size() < max_count - 1 and int(round(cursor)) < middle.size():
		thinned.append(middle[int(round(cursor))])
		cursor += step
	thinned.append(tail)
	return _dedupe_replay_timeline(thinned)

func _frame_index_for_replay_time(visual_replay: Dictionary, t_ms: int) -> int:
	var frames_any: Variant = visual_replay.get("frames", [])
	if typeof(frames_any) != TYPE_ARRAY:
		return 0
	var frames: Array = frames_any as Array
	if frames.is_empty():
		return 0
	var best_index := 0
	var best_delta := 2147483647
	for i in range(frames.size()):
		var frame_any: Variant = frames[i]
		if typeof(frame_any) != TYPE_DICTIONARY:
			continue
		var delta: int = absi(int((frame_any as Dictionary).get("t", 0)) - t_ms)
		if delta < best_delta:
			best_delta = delta
			best_index = i
	return best_index

func _telemetry_analysis_lines(analysis_summary: Dictionary) -> Array:
	var out: Array = []
	var insights_any: Variant = analysis_summary.get("insights", [])
	if typeof(insights_any) == TYPE_ARRAY:
		for insight_any in insights_any as Array:
			var insight: String = str(insight_any).strip_edges()
			if insight == "":
				continue
			out.append(insight)
			if out.size() >= 5:
				break
	return out

func _empty_saved_replay_data() -> Dictionary:
	return {
		"title": "No Saved Match",
		"result": "-",
		"eff": "HE --",
		"mode": "--",
		"map": "--",
		"duration": "--:--",
		"timeline": [
			{"t": "--:--", "event": "No saved replay found"}
		],
		"visual_replay": {},
		"analysis": [],
		"is_saved_telemetry": false
	}

func _present_replay_token(value: String) -> String:
	var clean: String = value.get_file().get_basename().replace("_", " ").replace("-", " ").strip_edges()
	if clean.is_empty():
		return "Unknown"
	return clean.capitalize()

func _format_replay_duration(duration_s: float) -> String:
	return _format_replay_time(int(round(maxf(0.0, duration_s) * 1000.0)))

func _format_replay_time(time_ms: int) -> String:
	var total_s: int = int(round(float(maxi(0, time_ms)) / 1000.0))
	var minutes: int = int(total_s / 60)
	var seconds: int = total_s % 60
	return "%02d:%02d" % [minutes, seconds]

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
		_play_store_purchase_sfx()
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
		_play_store_purchase_sfx()
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
	_refresh_latest_match_replay_cache()
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
	dash_replay_sub.text = "Replay — %s" % first_match.get("title", "Match")
	_set_stats_tier(_stats_tier)
	_apply_analysis_lines(first_match)
	_apply_replay_data(first_match)

func _get_match_data(index: int) -> Dictionary:
	if index == 0:
		if not _latest_replay_data.is_empty():
			return _latest_replay_data
		return _empty_saved_replay_data()
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
	_last_replay_data = match_data.duplicate(true)
	_last_replay_cursor_index = 0
	_last_replay_is_playing = false
	_last_replay_playback_serial += 1
	_apply_visual_replay_to_views()
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
	_update_replay_controls_state()
	_update_replay_playback_view()
	_update_home_replay_from_data()

func _apply_visual_replay_to_views() -> void:
	var replay_data: Dictionary = _visual_replay_data()
	if _home_replay_map_view != null and _home_replay_map_view.has_method("set_replay_data"):
		_home_replay_map_view.call("set_replay_data", replay_data)
	if _dash_replay_map_view != null and _dash_replay_map_view.has_method("set_replay_data"):
		_dash_replay_map_view.call("set_replay_data", replay_data)

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
	_replay_direct_mode = false
	if match_index == 0:
		_refresh_latest_match_replay_cache()
	_current_match_index = match_index
	var match_data := _get_match_data(match_index)
	dash_replay_sub.text = "Replay — %s" % match_data.get("title", "Match")
	_apply_replay_data(match_data)
	_open_dash_panel(dash_replay_panel)

func _on_replay_control_pressed(control_index: int) -> void:
	var timeline: Array = _last_replay_data.get("timeline", [])
	if _last_replay_data.is_empty() or (timeline.is_empty() and _replay_sequence_count() <= 0):
		status_label.text = "No replay loaded."
		return
	match control_index:
		0:
			_start_replay_playback("Replay playing from %s." % _replay_cursor_time())
		1:
			_stop_replay_playback()
			status_label.text = "Replay paused at %s." % _replay_cursor_time()
		2:
			_stop_replay_playback()
			_step_replay_cursor(1)
			status_label.text = "Replay stepped to %s." % _replay_cursor_time()
		3:
			_last_replay_speed_index = (_last_replay_speed_index + 1) % 3
			var speed_labels: Array[String] = ["1x", "2x", "4x"]
			status_label.text = "Replay speed %s." % speed_labels[_last_replay_speed_index]
			if _last_replay_is_playing:
				_last_replay_playback_serial += 1
				_schedule_replay_tick()
		_:
			pass

func _start_replay_playback(status_text: String) -> void:
	var timeline: Array = _last_replay_data.get("timeline", [])
	if _last_replay_data.is_empty() or (timeline.is_empty() and _replay_sequence_count() <= 0):
		status_label.text = "No replay loaded."
		return
	_last_replay_is_playing = true
	_last_replay_playback_serial += 1
	_update_replay_playback_view()
	status_label.text = status_text
	_schedule_replay_tick()

func _stop_replay_playback() -> void:
	_last_replay_is_playing = false
	_last_replay_playback_serial += 1
	_update_replay_playback_view()

func _step_replay_cursor(delta: int) -> void:
	var count: int = _replay_sequence_count()
	if count <= 0:
		_last_replay_cursor_index = 0
		_update_replay_playback_view()
		return
	_last_replay_cursor_index = clampi(_last_replay_cursor_index + delta, 0, count - 1)
	_update_replay_playback_view()

func _schedule_replay_tick() -> void:
	if not _last_replay_is_playing:
		return
	var serial: int = _last_replay_playback_serial
	var delay_sec: float = _replay_tick_delay_sec()
	get_tree().create_timer(delay_sec).timeout.connect(func() -> void:
		_advance_replay_tick(serial)
	)

func _advance_replay_tick(serial: int) -> void:
	if serial != _last_replay_playback_serial or not _last_replay_is_playing:
		return
	var count: int = _replay_sequence_count()
	if count <= 0:
		_stop_replay_playback()
		status_label.text = "Replay ended."
		return
	if _last_replay_cursor_index >= count - 1:
		_last_replay_is_playing = false
		_last_replay_playback_serial += 1
		_update_replay_playback_view()
		status_label.text = "Replay ended at %s." % _replay_cursor_time()
		return
	_step_replay_cursor(1)
	status_label.text = "Replay playing from %s." % _replay_cursor_time()
	_schedule_replay_tick()

func _replay_tick_delay_sec() -> float:
	match _last_replay_speed_index:
		1:
			return 0.42
		2:
			return 0.22
		_:
			return 0.72

func _update_replay_playback_view() -> void:
	var frame_index: int = _visual_frame_index_for_cursor()
	if _home_replay_map_view != null and _home_replay_map_view.has_method("set_frame_index"):
		_home_replay_map_view.call("set_frame_index", frame_index)
	if _dash_replay_map_view != null and _dash_replay_map_view.has_method("set_frame_index"):
		_dash_replay_map_view.call("set_frame_index", frame_index)
	for i in range(replay_timeline_times.size()):
		var is_cursor: bool = i == _last_replay_cursor_index
		var alpha: float = 1.0 if is_cursor else 0.72
		var color: Color = Color(1.0, 0.84, 0.24, 1.0) if is_cursor else Color(0.86, 0.90, 0.95, alpha)
		if i < replay_timeline_times.size() and replay_timeline_times[i] is Label:
			(replay_timeline_times[i] as Label).modulate = color
		if i < replay_timeline_events.size() and replay_timeline_events[i] is Label:
			(replay_timeline_events[i] as Label).modulate = color
	_update_home_replay_playback_view()

func _update_home_replay_from_data() -> void:
	if _home_replay_panel == null:
		return
	if _home_replay_time_label != null:
		_home_replay_time_label.text = _replay_cursor_time()
	_update_home_replay_playback_view()

func _update_home_replay_playback_view() -> void:
	var timeline: Array = _last_replay_data.get("timeline", [])
	var row_count: int = _home_replay_rows.size()
	var max_start: int = maxi(0, timeline.size() - row_count)
	var visible_start: int = clampi(_last_replay_cursor_index - 1, 0, max_start)
	if _home_replay_progress != null:
		var count: int = _replay_sequence_count()
		if count <= 1:
			_home_replay_progress.value = 0.0
		else:
			_home_replay_progress.value = float(_last_replay_cursor_index) / float(count - 1)
	if _home_replay_time_label != null:
		_home_replay_time_label.text = _replay_cursor_time()
	for i in range(row_count):
		var row_data: Dictionary = _home_replay_rows[i] as Dictionary
		var row: Control = row_data.get("row", null) as Control
		var time_label: Label = row_data.get("time", null) as Label
		var event_label: Label = row_data.get("event", null) as Label
		var event_index: int = visible_start + i
		if event_index < timeline.size() and typeof(timeline[event_index]) == TYPE_DICTIONARY:
			var entry: Dictionary = timeline[event_index] as Dictionary
			if time_label != null:
				time_label.text = str(entry.get("t", "--:--"))
			if event_label != null:
				event_label.text = str(entry.get("event", "Event"))
		else:
			if time_label != null:
				time_label.text = ""
			if event_label != null:
				event_label.text = ""
		var is_cursor: bool = event_index == _last_replay_cursor_index
		var color: Color = Color(1.0, 0.86, 0.32, 1.0) if is_cursor else Color(0.82, 0.88, 0.94, 0.76)
		if row != null:
			row.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_cursor else Color(1.0, 1.0, 1.0, 0.82)
		if time_label != null:
			time_label.add_theme_color_override("font_color", color)
		if event_label != null:
			event_label.add_theme_color_override("font_color", color)

func _replay_cursor_time() -> String:
	var visual_time_ms: int = _visual_replay_time_for_cursor()
	if visual_time_ms >= 0:
		return _format_replay_time(visual_time_ms)
	var timeline: Array = _last_replay_data.get("timeline", [])
	if timeline.is_empty():
		return "--:--"
	_last_replay_cursor_index = clampi(_last_replay_cursor_index, 0, timeline.size() - 1)
	var entry_any: Variant = timeline[_last_replay_cursor_index]
	if typeof(entry_any) != TYPE_DICTIONARY:
		return "--:--"
	return str((entry_any as Dictionary).get("t", "--:--"))

func _visual_replay_data() -> Dictionary:
	var replay_any: Variant = _last_replay_data.get("visual_replay", {})
	if typeof(replay_any) != TYPE_DICTIONARY:
		return {}
	return replay_any as Dictionary

func _visual_replay_frames() -> Array:
	var replay_data: Dictionary = _visual_replay_data()
	var frames_any: Variant = replay_data.get("frames", [])
	if typeof(frames_any) != TYPE_ARRAY:
		return []
	return frames_any as Array

func _replay_sequence_count() -> int:
	var timeline: Array = _last_replay_data.get("timeline", [])
	if not timeline.is_empty():
		return timeline.size()
	return _visual_replay_frames().size()

func _visual_frame_index_for_cursor() -> int:
	var frames: Array = _visual_replay_frames()
	if frames.is_empty():
		return 0
	var timeline: Array = _last_replay_data.get("timeline", [])
	if not timeline.is_empty():
		var entry_any: Variant = timeline[clampi(_last_replay_cursor_index, 0, timeline.size() - 1)]
		if typeof(entry_any) == TYPE_DICTIONARY:
			var entry: Dictionary = entry_any as Dictionary
			if entry.has("frame_index"):
				return clampi(int(entry.get("frame_index", 0)), 0, frames.size() - 1)
			if entry.has("t_ms"):
				return _frame_index_for_replay_time(_visual_replay_data(), int(entry.get("t_ms", 0)))
	return clampi(_last_replay_cursor_index, 0, frames.size() - 1)

func _visual_replay_time_for_cursor() -> int:
	var timeline: Array = _last_replay_data.get("timeline", [])
	if not timeline.is_empty():
		var entry_any: Variant = timeline[clampi(_last_replay_cursor_index, 0, timeline.size() - 1)]
		if typeof(entry_any) == TYPE_DICTIONARY and (entry_any as Dictionary).has("t_ms"):
			return int((entry_any as Dictionary).get("t_ms", -1))
	var frames: Array = _visual_replay_frames()
	if frames.is_empty():
		return -1
	var frame: Variant = frames[clampi(_last_replay_cursor_index, 0, frames.size() - 1)]
	if typeof(frame) != TYPE_DICTIONARY:
		return -1
	return int((frame as Dictionary).get("t", -1))

func _update_replay_controls_state() -> void:
	var has_replay: bool = bool(_last_replay_data.get("is_saved_telemetry", true))
	for button_any in replay_controls_buttons:
		if button_any is Button:
			(button_any as Button).disabled = not has_replay
	for button_any in _home_replay_buttons:
		if button_any is Button:
			(button_any as Button).disabled = not has_replay

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/VSMenu.tscn")

func _open_buffs_store() -> void:
	_play_mm_base_drop_sfx()
	_close_top_level_windows()
	_open_buffs_panel()
	status_label.text = "Buff store opened."

func _open_free_roll_split() -> void:
	_play_mm_base_drop_sfx()
	_close_top_level_windows()
	_open_game_hub(false, 0)

func _open_cash_split() -> void:
	_play_mm_base_drop_sfx()
	_close_top_level_windows()
	if _dev_bypass_cash_balance:
		_open_game_hub(true, _default_money_denomination())
		return
	if _wallet_balance_usd() <= 0:
		_open_insufficient_balance_modal()
		return
	_open_game_hub(true, _default_money_denomination())

func _on_battle_pass_pressed() -> void:
	_play_mm_base_drop_sfx()
	_close_top_level_windows()
	_open_battle_pass_panel()
	status_label.text = "Battle Pass opened."

func _open_tournaments_from_menu_button() -> void:
	_open_stage_race_tournament_lobby("WEEKLY")

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
	var panel_instance_any: Variant = _load_packed_scene(SWARM_PASS_PANEL_SCENE_PATH).instantiate()
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
	var panel_instance_any: Variant = _load_packed_scene(BATTLE_PASS_PANEL_SCENE_PATH).instantiate()
	if panel_instance_any is Control:
		_battle_pass_panel = panel_instance_any as Control
		add_child(_battle_pass_panel)
		_battle_pass_panel.visible = false
		if _battle_pass_panel.has_signal("close_requested"):
			_battle_pass_panel.connect("close_requested", Callable(self, "_close_battle_pass_panel"))
		if _battle_pass_panel.has_signal("store_requested"):
			_battle_pass_panel.connect("store_requested", Callable(self, "_on_battle_pass_store_requested"))

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

func _on_battle_pass_store_requested() -> void:
	_close_battle_pass_panel()
	_open_storefront_panel()

func _ensure_rank_panel() -> void:
	if _rank_panel != null and is_instance_valid(_rank_panel):
		return
	var panel_instance_any: Variant = _load_packed_scene(RANK_PANEL_SCENE_PATH).instantiate()
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

func _on_tier_widget_rank_pressed() -> void:
	_open_rank_neighbors_popup()

func _on_tier_widget_tier_pressed() -> void:
	_open_tier_roster_popup()

func _ensure_rank_context_panel() -> void:
	if _rank_context_panel != null and is_instance_valid(_rank_context_panel):
		return
	var panel_size: Vector2 = _resolve_entry_overlay_size(Vector2(760.0, 780.0))
	var panel := Panel.new()
	panel.name = "RankContextPanel"
	panel.layout_mode = 0
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_bottom = panel_size.y * 0.5
	panel.clip_contents = true
	panel.z_index = 210
	panel.visible = false
	add_child(panel)
	_rank_context_panel = panel
	_style_panel(panel, Color(0.05, 0.06, 0.09, 0.985), Color(0.95, 0.77, 0.28, 0.76))
	_build_entry_overlay_background_layers(panel, panel_size)

	var root := MarginContainer.new()
	root.name = "Root"
	root.layout_mode = 1
	root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	root.offset_left = 22.0
	root.offset_top = 18.0
	root.offset_right = -22.0
	root.offset_bottom = -18.0
	panel.add_child(root)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.name = "TitleBox"
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 4)
	header.add_child(title_box)

	var title := Label.new()
	title.name = "Title"
	title.text = "RANK CONTEXT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_box.add_child(title)
	_apply_font(title, _font_semibold, 18)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Context ladder"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(subtitle)
	_apply_font(subtitle, _font_regular, 12)
	subtitle.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92, 0.74))

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(120.0, 44.0)
	close_button.pressed.connect(_close_rank_context_panel)
	header.add_child(close_button)
	_apply_font(close_button, _font_semibold, 12)
	_style_button(close_button, Color(0.13, 0.14, 0.18, 0.96), Color(0.56, 0.47, 0.23, 0.88), Color(0.98, 0.96, 0.91, 1.0))

	var summary := Label.new()
	summary.name = "Summary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(summary)
	_apply_font(summary, _font_regular, 13)
	summary.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86, 0.96))

	var content := RichTextLabel.new()
	content.name = "Content"
	content.bbcode_enabled = true
	content.fit_content = false
	content.scroll_active = true
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.selection_enabled = false
	content.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	vbox.add_child(content)
	_apply_font(content, _font_regular, 13)

	var footer := Label.new()
	footer.name = "Footer"
	footer.text = "Click Rank for your nearby ladder. Click Tier for everyone in your current tier."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(footer)
	_apply_font(footer, _font_regular, 11)
	footer.add_theme_color_override("font_color", Color(0.80, 0.83, 0.88, 0.62))

func _open_rank_neighbors_popup() -> void:
	var view: Dictionary = _global_rank_view()
	var rows_any: Variant = view.get("rows", [])
	if typeof(rows_any) != TYPE_ARRAY:
		_present_rank_context(
			"RANK NEIGHBORHOOD",
			"Global ladder context is unavailable right now.",
			"RankState did not return a usable leaderboard snapshot.",
			"[color=#f2c96a]No leaderboard rows available.[/color]"
		)
		return
	var rows: Array = rows_any as Array
	var local_player_id: String = str(view.get("local_player_id", "")).strip_edges()
	var local_context: Dictionary = view.get("local_context", {}) as Dictionary
	var local_index: int = -1
	for i in range(rows.size()):
		var row: Dictionary = rows[i] as Dictionary
		if str(row.get("player_id", "")).strip_edges() == local_player_id:
			local_index = i
			break
	if local_index < 0 and not rows.is_empty():
		local_index = 0
	var start_index: int = maxi(0, local_index - 10)
	var end_index: int = mini(rows.size(), local_index + 11)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[color=#f2c96a]GLOBAL   PLAYER   WAX   TIER[/color]")
	var focus_line: int = -1
	for i in range(start_index, end_index):
		var row: Dictionary = rows[i] as Dictionary
		var is_local: bool = i == local_index
		if is_local:
			focus_line = lines.size()
		lines.append(_rank_context_line(row, is_local))
	var tier_name: String = _rank_context_tier_name(str(local_context.get("tier_id", "DRONE")))
	var gap_to_next: float = float(local_context.get("wax_gap_to_next_player", 0.0))
	var rank_position: int = int(local_context.get("rank_position", 0))
	var summary: String = "You are #%d overall in %s with %s wax." % [
		rank_position,
		tier_name,
		_format_wax_value(float(local_context.get("wax_score", 0.0)))
	]
	if gap_to_next > 0.0:
		summary += " %.1f wax to the next player ahead." % gap_to_next
	else:
		summary += " You currently hold the top spot in this snapshot."
	_present_rank_context(
		"RANK NEIGHBORHOOD",
		"Ten places ahead and ten behind, centered on your current global rank.",
		summary,
		"\n".join(lines),
		focus_line
	)

func _open_tier_roster_popup() -> void:
	var view: Dictionary = _global_rank_view()
	var rows_any: Variant = view.get("rows", [])
	var local_context: Dictionary = view.get("local_context", {}) as Dictionary
	if typeof(rows_any) != TYPE_ARRAY:
		_present_rank_context(
			"TIER ROSTER",
			"Tier roster is unavailable right now.",
			"RankState did not return a usable leaderboard snapshot.",
			"[color=#f2c96a]No leaderboard rows available.[/color]"
		)
		return
	var rows: Array = rows_any as Array
	var local_player_id: String = str(view.get("local_player_id", "")).strip_edges()
	var local_tier_id: String = str(local_context.get("tier_id", "DRONE")).strip_edges().to_upper()
	var badge: Dictionary = _local_tier_badge()
	var tier_rows: Array[Dictionary] = []
	var local_tier_index: int = -1
	for row_any in rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("tier_id", "")).strip_edges().to_upper() != local_tier_id:
			continue
		if str(row.get("player_id", "")).strip_edges() == local_player_id:
			local_tier_index = tier_rows.size()
		tier_rows.append(row)
	var tier_name: String = _rank_context_tier_name(local_tier_id)
	var tier_index: int = int(badge.get("tier_index", 0))
	var tier_rank: int = int(badge.get("tier_rank", maxi(1, local_tier_index + 1)))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[color=#f2c96a]TIER   GLOBAL   PLAYER   WAX[/color]")
	var focus_line: int = -1
	for i in range(tier_rows.size()):
		var row: Dictionary = tier_rows[i]
		var is_local: bool = i == local_tier_index
		if is_local:
			focus_line = lines.size()
		lines.append(_tier_context_line(row, i + 1, is_local))
	var summary: String = "Tier %d: %s. You are #%d in-tier out of %d players, sitting #%d globally." % [
		tier_index,
		tier_name,
		tier_rank,
		tier_rows.size(),
		int(local_context.get("rank_position", 0))
	]
	_present_rank_context(
		"TIER %d · %s" % [tier_index, tier_name.to_upper()],
		"Scrollable roster for everyone currently sharing your tier. Your row is highlighted.",
		summary,
		"\n".join(lines),
		focus_line
	)

func _present_rank_context(title_text: String, subtitle_text: String, summary_text: String, body_bbcode: String, focus_line: int = -1) -> void:
	_ensure_rank_context_panel()
	if _rank_context_panel == null:
		return
	_close_top_level_windows(UI_SURFACE_RANK_CONTEXT)
	var title: Label = _rank_context_panel.get_node_or_null("Root/VBox/Header/TitleBox/Title") as Label
	var subtitle: Label = _rank_context_panel.get_node_or_null("Root/VBox/Header/TitleBox/Subtitle") as Label
	var summary: Label = _rank_context_panel.get_node_or_null("Root/VBox/Summary") as Label
	var content: RichTextLabel = _rank_context_panel.get_node_or_null("Root/VBox/Content") as RichTextLabel
	if title != null:
		title.text = title_text
	if subtitle != null:
		subtitle.text = subtitle_text
	if summary != null:
		summary.text = summary_text
	if content != null:
		content.clear()
		content.text = ""
		content.append_text(body_bbcode)
		content.scroll_to_line(0)
		if focus_line >= 0:
			content.call_deferred("scroll_to_line", focus_line)
	_rank_context_panel.visible = true
	_rank_context_panel.move_to_front()

func _close_rank_context_panel() -> void:
	if _rank_context_panel == null:
		return
	_rank_context_panel.visible = false

func _global_rank_view() -> Dictionary:
	var rank_state: Node = get_node_or_null("/root/RankState")
	if rank_state == null or not rank_state.has_method("get_local_rank_view"):
		return {}
	var view_any: Variant = rank_state.call("get_local_rank_view", "GLOBAL", 100000)
	if typeof(view_any) != TYPE_DICTIONARY:
		return {}
	return (view_any as Dictionary).duplicate(true)

func _local_tier_badge() -> Dictionary:
	var rank_state: Node = get_node_or_null("/root/RankState")
	if rank_state == null or not rank_state.has_method("get_local_tier_badge"):
		return {}
	var badge_any: Variant = rank_state.call("get_local_tier_badge")
	if typeof(badge_any) != TYPE_DICTIONARY:
		return {}
	return (badge_any as Dictionary).duplicate(true)

func _rank_context_line(row: Dictionary, highlight: bool) -> String:
	var text: String = "#%d  %s  %s wax  %s" % [
		int(row.get("rank_global", row.get("rank_position", 0))),
		_bbcode_escape(str(row.get("display_name", "Player"))),
		_format_wax_value(float(row.get("wax_score", 0.0))),
		_bbcode_escape(_rank_context_tier_name(str(row.get("tier_id", "DRONE"))).to_upper())
	]
	return _rank_context_markup(text, highlight)

func _tier_context_line(row: Dictionary, tier_rank: int, highlight: bool) -> String:
	var text: String = "T#%d  G#%d  %s  %s wax" % [
		tier_rank,
		int(row.get("rank_global", row.get("rank_position", 0))),
		_bbcode_escape(str(row.get("display_name", "Player"))),
		_format_wax_value(float(row.get("wax_score", 0.0)))
	]
	return _rank_context_markup(text, highlight)

func _rank_context_markup(text: String, highlight: bool) -> String:
	if highlight:
		return "[bgcolor=#4a320d][color=#ffe38a]%s  [YOU][/color][/bgcolor]" % text
	return "[color=#e9ebef]%s[/color]" % text

func _rank_context_tier_name(tier_id: String) -> String:
	var raw: String = tier_id.strip_edges().to_lower()
	if raw.is_empty():
		return "Drone"
	var words: PackedStringArray = raw.replace("_", " ").split(" ", false)
	var titled: PackedStringArray = PackedStringArray()
	for word in words:
		if word.is_empty():
			continue
		titled.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(titled)

func _format_wax_value(value: float) -> String:
	return "%.1f" % value

func _bbcode_escape(text: String) -> String:
	return text.replace("[", "\\[").replace("]", "\\]")

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
	if not paid:
		_open_free_roll_game_hub(selected_denom)
		return
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
	var title_center_track_right_inset_px: float = GAME_HUB_FREE_CENTER_TRACK_RIGHT_INSET if not paid else 0.0
	_apply_game_hub_panel_fx(panel)
	_apply_game_hub_title_treatment(panel, title, title_center_track_right_inset_px)
	var body: VBoxContainer = _entry_overlay_body(panel)
	if body == null:
		return
	var top_row_scale: float = 1.0
	var lower_rows_scale: float = 1.0
	var centered_content_bias_x: float = 0.0
	var section_label_rebound_x: float = 0.0
	var button_track_right_inset_px: float = 0.0
	var content_top_padding_px: float = GAME_HUB_CONTENT_TOP_PADDING_PX
	var body_separation: int = 8
	var cluster_spacing: int = 6
	var touch_layout: bool = _use_game_hub_touch_layout()
	if paid:
		if touch_layout:
			top_row_scale = GAME_HUB_TOUCH_PAID_TOP_ROW_SCALE
			lower_rows_scale = GAME_HUB_TOUCH_PAID_LOWER_ROWS_SCALE
			body_separation = 14
			cluster_spacing = GAME_HUB_TOUCH_PAID_CLUSTER_SPACING
		else:
			top_row_scale = GAME_HUB_MONEY_TOP_ROW_SCALE
			lower_rows_scale = GAME_HUB_MONEY_LOWER_ROWS_SCALE
			body_separation = GAME_HUB_MONEY_BODY_SEPARATION
			cluster_spacing = GAME_HUB_MONEY_CLUSTER_SPACING
	body.offset_top += extra_top + content_top_padding_px
	body.offset_left += GAME_HUB_CONTENT_SHIFT_X + centered_content_bias_x
	body.offset_right += GAME_HUB_CONTENT_SHIFT_X + centered_content_bias_x
	body.add_theme_constant_override("separation", body_separation)
	if paid:
		_build_money_games_division_layer(body, panel, broadcast_free_roll)
	_add_game_hub_block_label(body, "MATCH TYPE", broadcast_free_roll, section_label_rebound_x)
	var match_type_block := VBoxContainer.new()
	match_type_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_type_block.add_theme_constant_override("separation", cluster_spacing)
	body.add_child(match_type_block)
	_add_game_hub_section_header(match_type_block, "HUMAN MATCHES", "Live competitive matches", broadcast_free_roll, section_label_rebound_x)
	var human_row_host: Control = _make_game_hub_center_track(match_type_block, button_track_right_inset_px)
	var human_row_wrap := HBoxContainer.new()
	human_row_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_row_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	human_row_host.add_child(human_row_wrap)
	var human_row := GridContainer.new()
	human_row.columns = 2 if paid and touch_layout else 3
	human_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	human_row.add_theme_constant_override("h_separation", cluster_spacing)
	human_row.add_theme_constant_override("v_separation", cluster_spacing)
	human_row_wrap.add_child(human_row)
	for mode_id in ["1V1", "CTF", "HIDDEN CTF", "2V2", "3P FFA", "4P FFA"]:
		var chosen_mode: String = mode_id
		var button := Button.new()
		button.custom_minimum_size = GAME_HUB_HUMAN_BUTTON_SIZE
		if paid:
			button.pressed.connect(func(): _on_human_mode_selected(chosen_mode, true, _money_games_selected_tier))
		else:
			button.pressed.connect(func(): _on_human_mode_selected(chosen_mode, false, selected_denom))
		human_row.add_child(button)
		_apply_human_mode_skin_to_button(button, chosen_mode, paid, selected_denom)
		_tune_game_hub_human_button(button, top_row_scale)
		_configure_game_hub_option_button(button, broadcast_free_roll)
	if not paid:
		_add_game_hub_spacer(match_type_block, GAME_HUB_FREE_SECTION_SPACER_PX)
	_add_game_hub_section_header(match_type_block, "TIME PUZZLES", "Race against time & ranking", broadcast_free_roll, section_label_rebound_x)
	var cycle_row_host: Control = _make_game_hub_center_track(match_type_block, button_track_right_inset_px)
	var cycle_row_wrap := HBoxContainer.new()
	cycle_row_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cycle_row_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	cycle_row_host.add_child(cycle_row_wrap)
	var cycle_row := GridContainer.new()
	cycle_row.columns = 2 if paid and touch_layout else 3
	cycle_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cycle_row_separation: int = cluster_spacing
	var cycle_button_scale: float = lower_rows_scale
	if not paid:
		cycle_row_separation = GAME_HUB_FREE_TRIPLE_ROW_SEPARATION
		cycle_button_scale *= GAME_HUB_FREE_TRIPLE_ROW_SCALE
	cycle_row.add_theme_constant_override("h_separation", cycle_row_separation)
	cycle_row.add_theme_constant_override("v_separation", cluster_spacing)
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
		_tune_game_hub_cycle_button(button, cycle_button_scale)
		_configure_game_hub_option_button(button, broadcast_free_roll)
	if not paid:
		_add_game_hub_spacer(body, GAME_HUB_FREE_SECTION_SPACER_PX)
	_add_game_hub_block_divider(body, broadcast_free_roll)
	_add_game_hub_spacer(body, GAME_HUB_BLOCK_SPACING_PX if paid else GAME_HUB_BLOCK_SPACING_FREE_PX)
	_add_game_hub_block_label(body, "MAP CONFIG", broadcast_free_roll, section_label_rebound_x)
	var map_block := VBoxContainer.new()
	map_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_block.add_theme_constant_override("separation", cluster_spacing)
	body.add_child(map_block)
	var one_map_items := [
		{"label": "CAPTURE FLAG", "id": "CAPTURE_FLAG"},
		{"label": "HIDDEN FLAG", "id": "HIDDEN_CAPTURE_FLAG"}
	]
	_add_game_hub_map_group(map_block, "1 MAP", one_map_items, paid, selected_denom, not paid, broadcast_free_roll, lower_rows_scale, section_label_rebound_x, button_track_right_inset_px)
	if not paid:
		_add_game_hub_spacer(map_block, GAME_HUB_FREE_MAP_GROUP_SPACER_PX)
	var three_map_items := [
		{"label": "STAGE RACE", "id": "STAGE_RACE_3"},
		{"label": "RACE", "id": "TIMED_RACE_3"},
		{"label": "MISS N OUT", "id": "MISS_N_OUT_3"}
	]
	_add_game_hub_map_group(map_block, "3 MAP", three_map_items, paid, selected_denom, not paid, broadcast_free_roll, lower_rows_scale, section_label_rebound_x, button_track_right_inset_px)
	if not paid:
		_add_game_hub_spacer(map_block, GAME_HUB_FREE_MAP_GROUP_SPACER_PX)
	var five_map_items := [
		{"label": "STAGE RACE", "id": "STAGE_RACE_5"},
		{"label": "RACE", "id": "TIMED_RACE_5"},
		{"label": "MISS N OUT", "id": "MISS_N_OUT_5"}
	]
	_add_game_hub_map_group(map_block, "5 MAP", five_map_items, paid, selected_denom, not paid, broadcast_free_roll, lower_rows_scale, section_label_rebound_x, button_track_right_inset_px)
	if not paid:
		_add_game_hub_spacer(body, GAME_HUB_FREE_BOTTOM_SPACER_PX)
	var cancel_row_host: Control = _make_game_hub_center_track(body, button_track_right_inset_px)
	var cancel_row := HBoxContainer.new()
	cancel_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cancel_row_host.add_child(cancel_row)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.pressed.connect(_close_entry_route_modal)
	cancel_row.add_child(cancel)
	_style_game_hub_cancel_button(cancel, lower_rows_scale)
	_configure_game_hub_option_button(cancel, broadcast_free_roll)
	_enable_touch_drag_scroll(panel.get_node_or_null("EntryScroll") as ScrollContainer)
	_entry_route_modal = panel

func _open_free_roll_game_hub(selected_denom: int = 0) -> void:
	var panel_any: Node = _load_packed_scene(FREE_ROLL_GAME_HUB_SCENE_PATH).instantiate()
	var panel: Panel = panel_any as Panel
	if panel == null:
		return
	var overlay_size: Vector2 = _resolve_game_hub_overlay_size(false)
	panel = _configure_entry_overlay_panel(panel, "FREE ROLL", "Select mode and route.", overlay_size, true)
	if panel == null:
		return
	_center_free_roll_scene_panel(panel, overlay_size)
	_shift_free_roll_overlay_down(panel)
	panel.set_meta("sf_scene_owned_layout", true)
	_apply_game_hub_panel_fx(panel)
	_apply_game_hub_title_treatment(panel, "FREE ROLL", GAME_HUB_FREE_CENTER_TRACK_RIGHT_INSET)
	panel.set_meta("sf_free_layout_version", GAME_HUB_FREE_LAYOUT_VERSION)
	_configure_free_roll_game_hub_scene(panel, selected_denom)
	_enable_touch_drag_scroll(panel.get_node_or_null("EntryScroll") as ScrollContainer)
	_entry_route_modal = panel

func _shift_free_roll_overlay_down(panel: Panel) -> void:
	if panel == null:
		return
	var viewport_height: float = get_viewport_rect().size.y
	var current_bottom: float = (viewport_height * 0.5) + panel.offset_bottom
	var remaining_down_space: float = maxf(0.0, viewport_height - current_bottom - 8.0)
	var shift_y: float = minf(GAME_HUB_OVERLAY_FREE_SHIFT_DOWN_PX, remaining_down_space)
	panel.offset_top += shift_y
	panel.offset_bottom += shift_y

func _center_free_roll_scene_panel(panel: Panel, overlay_size: Vector2) -> void:
	if panel == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var current_size: Vector2 = panel.size
	if current_size.x <= 1.0:
		current_size.x = panel.offset_right - panel.offset_left
	if current_size.y <= 1.0:
		current_size.y = panel.offset_bottom - panel.offset_top
	var centered_size := Vector2(
		minf(overlay_size.x, maxf(360.0, viewport_size.x - (GAME_HUB_OVERLAY_VIEWPORT_MARGIN_X * 2.0))),
		minf(maxf(overlay_size.y, current_size.y), maxf(360.0, viewport_size.y - (GAME_HUB_OVERLAY_VIEWPORT_MARGIN_Y * 2.0)))
	)
	panel.layout_mode = 0
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -centered_size.x * 0.5
	panel.offset_right = centered_size.x * 0.5
	panel.offset_top = -centered_size.y * 0.5
	panel.offset_bottom = centered_size.y * 0.5

func _configure_free_roll_game_hub_scene(panel: Panel, selected_denom: int) -> void:
	if panel == null:
		return
	_apply_free_roll_scene_layout(panel)
	_install_free_roll_scroll_guard(panel)
	_style_free_roll_game_hub_scene(panel)
	var broadcast_free_roll: bool = true
	var human_defs: Array[Dictionary] = [
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/Human1v1Button"), "mode": "1V1"},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/HumanCtfButton"), "mode": "CTF"},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/HumanHiddenCtfButton"), "mode": "HIDDEN CTF"},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/Human2v2Button"), "mode": "2V2"},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/Human3pFfaButton"), "mode": "3P FFA"},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/Human4pFfaButton"), "mode": "4P FFA"}
	]
	for def in human_defs:
		var button: Button = panel.get_node_or_null(def.get("path", NodePath(""))) as Button
		var mode_id: String = str(def.get("mode", ""))
		if button == null or mode_id.is_empty():
			continue
		_connect_free_roll_guarded_press(button, Callable(self, "_on_human_mode_selected").bind(mode_id, false, selected_denom))
		_apply_human_mode_skin_to_button(button, mode_id, false, selected_denom, true)
		_configure_game_hub_option_button(button, broadcast_free_roll)
	var cycle_defs: Array[Dictionary] = [
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/WeeklyButton"), "label": "WEEKLY", "mode": "WEEKLY"},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/MonthlyButton"), "label": "MONTHLY", "mode": "MONTHLY"},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/SeasonButton"), "label": "SEASON", "mode": "YEARLY"}
	]
	for def in cycle_defs:
		var button: Button = panel.get_node_or_null(def.get("path", NodePath(""))) as Button
		var label: String = str(def.get("label", ""))
		var mode_id: String = str(def.get("mode", ""))
		if button == null or mode_id.is_empty():
			continue
		_connect_free_roll_guarded_press(button, Callable(self, "_on_async_mode_selected").bind(mode_id, false, 0))
		_apply_async_cycle_skin_to_button(button, label, false, selected_denom, true)
		_configure_game_hub_option_button(button, broadcast_free_roll)
	var map_defs: Array[Dictionary] = [
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/CaptureFlagButton"), "label": "CAPTURE FLAG", "mode": "CAPTURE_FLAG", "scale": GAME_HUB_FREE_LOWER_ROWS_SCALE},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/HiddenFlagButton"), "label": "HIDDEN FLAG", "mode": "HIDDEN_CAPTURE_FLAG", "scale": GAME_HUB_FREE_LOWER_ROWS_SCALE},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/StageRace3Button"), "label": "STAGE RACE", "mode": "STAGE_RACE_3", "scale": GAME_HUB_FREE_LOWER_ROWS_SCALE * GAME_HUB_FREE_TRIPLE_ROW_SCALE},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/TimedRace3Button"), "label": "RACE", "mode": "TIMED_RACE_3", "scale": GAME_HUB_FREE_LOWER_ROWS_SCALE * GAME_HUB_FREE_TRIPLE_ROW_SCALE},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/MissNOut3Button"), "label": "MISS N OUT", "mode": "MISS_N_OUT_3", "scale": GAME_HUB_FREE_LOWER_ROWS_SCALE * GAME_HUB_FREE_TRIPLE_ROW_SCALE},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/StageRace5Button"), "label": "STAGE RACE", "mode": "STAGE_RACE_5", "scale": GAME_HUB_FREE_LOWER_ROWS_SCALE * GAME_HUB_FREE_TRIPLE_ROW_SCALE},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/TimedRace5Button"), "label": "RACE", "mode": "TIMED_RACE_5", "scale": GAME_HUB_FREE_LOWER_ROWS_SCALE * GAME_HUB_FREE_TRIPLE_ROW_SCALE},
		{"path": NodePath("EntryScroll/EntryBody/EntryCanvas/MissNOut5Button"), "label": "MISS N OUT", "mode": "MISS_N_OUT_5", "scale": GAME_HUB_FREE_LOWER_ROWS_SCALE * GAME_HUB_FREE_TRIPLE_ROW_SCALE}
	]
	for def in map_defs:
		var button: Button = panel.get_node_or_null(def.get("path", NodePath(""))) as Button
		var label: String = str(def.get("label", ""))
		var mode_id: String = str(def.get("mode", ""))
		if button == null or mode_id.is_empty():
			continue
		_connect_free_roll_guarded_press(button, Callable(self, "_on_async_mode_selected").bind(mode_id, false, 0))
		_apply_async_mode_skin_to_button(button, label, false, selected_denom, true)
		_configure_game_hub_option_button(button, broadcast_free_roll)
	var cancel: Button = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/CancelButton") as Button
	if cancel != null:
		_connect_free_roll_guarded_press(cancel, Callable(self, "_close_entry_route_modal"))
		_style_game_hub_cancel_button(cancel, GAME_HUB_FREE_LOWER_ROWS_SCALE, true)
		_configure_game_hub_option_button(cancel, broadcast_free_roll)

func _apply_free_roll_scene_layout(panel: Panel) -> void:
	if panel == null:
		return
	var body: VBoxContainer = panel.get_node_or_null("EntryScroll/EntryBody") as VBoxContainer
	if body != null:
		body.custom_minimum_size = Vector2(FREE_ROLL_SCENE_CANVAS_WIDTH, 0.0)
		body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_theme_constant_override("separation", 14)
	var canvas: Control = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas") as Control
	if canvas == null:
		return
	canvas.custom_minimum_size = Vector2(FREE_ROLL_SCENE_CANVAS_WIDTH, FREE_ROLL_SCENE_CANVAS_HEIGHT)
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_free_roll_label_rect(panel, "EntryScroll/EntryBody/EntryCanvas/MatchTypeLabel", 18.0, 28.0)
	_set_free_roll_label_rect(panel, "EntryScroll/EntryBody/EntryCanvas/HumanMatchesHeading", 58.0, 34.0)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/Human1v1Button", 54.0, 110.0, FREE_ROLL_HUMAN_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/HumanCtfButton", 450.0, 110.0, FREE_ROLL_HUMAN_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/HumanHiddenCtfButton", 54.0, 286.0, FREE_ROLL_HUMAN_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/Human2v2Button", 450.0, 286.0, FREE_ROLL_HUMAN_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/Human3pFfaButton", 54.0, 462.0, FREE_ROLL_HUMAN_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/Human4pFfaButton", 450.0, 462.0, FREE_ROLL_HUMAN_BUTTON_SIZE)
	_set_free_roll_label_rect(panel, "EntryScroll/EntryBody/EntryCanvas/TimePuzzlesHeading", 672.0, 34.0)
	_set_free_roll_label_rect(panel, "EntryScroll/EntryBody/EntryCanvas/TimePuzzlesSubtext", 708.0, 30.0)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/WeeklyButton", 54.0, 770.0, FREE_ROLL_CYCLE_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/MonthlyButton", 450.0, 770.0, FREE_ROLL_CYCLE_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/SeasonButton", 252.0, 938.0, FREE_ROLL_CYCLE_BUTTON_SIZE)
	var divider: ColorRect = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/MapConfigDivider") as ColorRect
	if divider != null:
		_set_free_roll_control_rect(divider, 54.0, 1120.0, FREE_ROLL_SCENE_CANVAS_WIDTH - 108.0, 1.0)
	_set_free_roll_label_rect(panel, "EntryScroll/EntryBody/EntryCanvas/MapConfigLabel", 1144.0, 28.0)
	_set_free_roll_label_rect(panel, "EntryScroll/EntryBody/EntryCanvas/OneMapHeading", 1188.0, 30.0)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/CaptureFlagButton", 54.0, 1230.0, FREE_ROLL_ROUTE_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/HiddenFlagButton", 450.0, 1230.0, FREE_ROLL_ROUTE_BUTTON_SIZE)
	_set_free_roll_label_rect(panel, "EntryScroll/EntryBody/EntryCanvas/ThreeMapHeading", 1396.0, 30.0)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/StageRace3Button", 54.0, 1438.0, FREE_ROLL_ROUTE_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/TimedRace3Button", 450.0, 1438.0, FREE_ROLL_ROUTE_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/MissNOut3Button", 252.0, 1600.0, FREE_ROLL_ROUTE_BUTTON_SIZE)
	_set_free_roll_label_rect(panel, "EntryScroll/EntryBody/EntryCanvas/FiveMapHeading", 1778.0, 30.0)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/StageRace5Button", 54.0, 1820.0, FREE_ROLL_ROUTE_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/TimedRace5Button", 450.0, 1820.0, FREE_ROLL_ROUTE_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/MissNOut5Button", 252.0, 1982.0, FREE_ROLL_ROUTE_BUTTON_SIZE)
	_set_free_roll_button_rect(panel, "EntryScroll/EntryBody/EntryCanvas/CancelButton", 272.0, 2160.0, FREE_ROLL_CANCEL_BUTTON_SIZE)

func _set_free_roll_label_rect(panel: Panel, path: String, y: float, height: float) -> void:
	var label: Label = panel.get_node_or_null(path) as Label
	if label == null:
		return
	_set_free_roll_control_rect(label, 0.0, y, FREE_ROLL_SCENE_CANVAS_WIDTH, height)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _set_free_roll_button_rect(panel: Panel, path: String, x: float, y: float, size: Vector2) -> void:
	var button: Button = panel.get_node_or_null(path) as Button
	if button == null:
		return
	button.scale = Vector2.ONE
	button.custom_minimum_size = size
	_set_free_roll_control_rect(button, x, y, size.x, size.y)

func _set_free_roll_control_rect(control: Control, x: float, y: float, width: float, height: float) -> void:
	if control == null:
		return
	control.layout_mode = 0
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = x
	control.offset_top = y
	control.offset_right = x + width
	control.offset_bottom = y + height

func _install_free_roll_scroll_guard(panel: Panel) -> void:
	if panel == null:
		return
	var scroll: ScrollContainer = panel.get_node_or_null("EntryScroll") as ScrollContainer
	if scroll == null or scroll.has_meta("sf_free_roll_scroll_guard"):
		return
	scroll.set_meta("sf_free_roll_scroll_guard", true)
	scroll.gui_input.connect(_on_free_roll_scroll_gui_input)

func _connect_free_roll_guarded_press(button: Button, action: Callable) -> void:
	if button == null:
		return
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	if not button.has_meta("sf_free_roll_press_guard"):
		button.set_meta("sf_free_roll_press_guard", true)
		button.gui_input.connect(Callable(self, "_on_free_roll_button_gui_input").bind(button))
		button.button_down.connect(Callable(self, "_on_free_roll_button_down").bind(button))
		button.button_up.connect(Callable(self, "_on_free_roll_button_up").bind(button))
	button.pressed.connect(func() -> void:
		if _consume_free_roll_button_press(button):
			action.call()
	)

func _on_free_roll_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_block_free_roll_press_release()
	elif event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_block_free_roll_press_release()

func _on_free_roll_button_down(button: Button) -> void:
	if button == null:
		return
	button.set_meta("sf_free_roll_press_started_msec", Time.get_ticks_msec())
	button.set_meta("sf_free_roll_press_start_pos", button.get_local_mouse_position())
	button.set_meta("sf_free_roll_press_cancelled", false)

func _on_free_roll_button_up(button: Button) -> void:
	_finalize_free_roll_button_press(button)

func _on_free_roll_button_gui_input(event: InputEvent, button: Button) -> void:
	if button == null:
		return
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_update_free_roll_button_drag_guard(button, mouse_motion.position)
	elif event is InputEventScreenDrag:
		var screen_drag := event as InputEventScreenDrag
		_update_free_roll_button_drag_guard(button, screen_drag.position)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_finalize_free_roll_button_press(button)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			_finalize_free_roll_button_press(button)

func _update_free_roll_button_drag_guard(button: Button, position: Vector2) -> void:
	var start_any: Variant = button.get_meta("sf_free_roll_press_start_pos", position)
	var start_pos: Vector2 = start_any if typeof(start_any) == TYPE_VECTOR2 else position
	if start_pos.distance_to(position) < FREE_ROLL_PRESS_CANCEL_DRAG_PX:
		return
	button.set_meta("sf_free_roll_press_cancelled", true)
	_block_free_roll_press_release()

func _finalize_free_roll_button_press(button: Button) -> void:
	if button == null:
		return
	var started_msec: int = int(button.get_meta("sf_free_roll_press_started_msec", Time.get_ticks_msec()))
	if Time.get_ticks_msec() - started_msec >= FREE_ROLL_PRESS_CANCEL_HOLD_MS:
		button.set_meta("sf_free_roll_press_cancelled", true)
		_block_free_roll_press_release()

func _block_free_roll_press_release() -> void:
	_free_roll_press_block_until_msec = Time.get_ticks_msec() + FREE_ROLL_PRESS_RELEASE_BLOCK_MS

func _consume_free_roll_button_press(button: Button) -> bool:
	if button == null:
		return false
	var now: int = Time.get_ticks_msec()
	var cancelled: bool = bool(button.get_meta("sf_free_roll_press_cancelled", false))
	var started_msec: int = int(button.get_meta("sf_free_roll_press_started_msec", now))
	if now - started_msec >= FREE_ROLL_PRESS_CANCEL_HOLD_MS:
		cancelled = true
	if now < _free_roll_press_block_until_msec:
		cancelled = true
	button.set_meta("sf_free_roll_press_cancelled", false)
	return not cancelled

func _style_free_roll_game_hub_scene(panel: Panel) -> void:
	if panel == null:
		return
	_layout_free_roll_game_hub_scene(panel)
	var block_labels: Array[String] = [
		"EntryScroll/EntryBody/EntryCanvas/MatchTypeLabel",
		"EntryScroll/EntryBody/EntryCanvas/MapConfigLabel"
	]
	for path in block_labels:
		var label: Label = panel.get_node_or_null(path) as Label
		if label == null:
			continue
		label.add_theme_color_override("font_color", GAME_HUB_BLOCK_LABEL_COLOR)
		label.add_theme_constant_override("outline_size", 0)
		_apply_font(label, _font_semibold, 13)
	var section_heading_paths: Array[String] = [
		"EntryScroll/EntryBody/EntryCanvas/HumanMatchesHeading",
		"EntryScroll/EntryBody/EntryCanvas/TimePuzzlesHeading",
		"EntryScroll/EntryBody/EntryCanvas/OneMapHeading",
		"EntryScroll/EntryBody/EntryCanvas/ThreeMapHeading",
		"EntryScroll/EntryBody/EntryCanvas/FiveMapHeading"
	]
	for path in section_heading_paths:
		var label: Label = panel.get_node_or_null(path) as Label
		if label == null:
			continue
		label.add_theme_color_override("font_color", GAME_HUB_SECTION_HEADER_COLOR)
		label.add_theme_constant_override("outline_size", 0)
		_apply_font(label, _font_semibold, 16)
	var subtext_paths: Array[String] = [
		"EntryScroll/EntryBody/EntryCanvas/HumanMatchesSubtext",
		"EntryScroll/EntryBody/EntryCanvas/TimePuzzlesSubtext"
	]
	for path in subtext_paths:
		var label: Label = panel.get_node_or_null(path) as Label
		if label == null:
			continue
		label.add_theme_color_override("font_color", GAME_HUB_SECTION_SUBTEXT_COLOR)
		label.add_theme_constant_override("outline_size", 0)
		_apply_font(label, _font_regular, 13)
	var divider: ColorRect = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/MapConfigDivider") as ColorRect
	if divider != null:
		divider.color = GAME_HUB_DIVIDER_COLOR

func _layout_free_roll_game_hub_scene(panel: Panel) -> void:
	var body: VBoxContainer = panel.get_node_or_null("EntryScroll/EntryBody") as VBoxContainer
	var canvas: Control = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas") as Control
	if body == null or canvas == null:
		return
	var panel_width: float = maxf(1.0, panel.offset_right - panel.offset_left)
	var content_width: float = clampf(panel_width - 32.0, 320.0, GAME_HUB_OVERLAY_TARGET_WIDTH)
	body.custom_minimum_size = Vector2(content_width, 0.0)
	body.add_theme_constant_override("separation", 12)
	canvas.custom_minimum_size = Vector2(content_width, 1340.0)

	var margin_x: float = 28.0
	var y: float = 22.0
	_place_free_roll_label(panel, "EntryScroll/EntryBody/EntryCanvas/MatchTypeLabel", margin_x, y, content_width - (margin_x * 2.0), 26.0, HORIZONTAL_ALIGNMENT_CENTER)
	y += 42.0
	_place_free_roll_label(panel, "EntryScroll/EntryBody/EntryCanvas/HumanMatchesHeading", margin_x, y, content_width - (margin_x * 2.0), 28.0, HORIZONTAL_ALIGNMENT_CENTER)
	y += 40.0

	var human_paths: Array[String] = [
		"EntryScroll/EntryBody/EntryCanvas/Human1v1Button",
		"EntryScroll/EntryBody/EntryCanvas/HumanCtfButton",
		"EntryScroll/EntryBody/EntryCanvas/HumanHiddenCtfButton",
		"EntryScroll/EntryBody/EntryCanvas/Human2v2Button",
		"EntryScroll/EntryBody/EntryCanvas/Human3pFfaButton",
		"EntryScroll/EntryBody/EntryCanvas/Human4pFfaButton"
	]
	var human_cols: int = 2 if content_width >= 700.0 else 1
	var human_gap: float = 30.0 if human_cols == 2 else 0.0
	var human_size := Vector2(
		floor((content_width - (margin_x * 2.0) - (human_gap * float(human_cols - 1))) / float(human_cols)),
		round(178.0 * GAME_MENU_BUTTON_SCALE)
	)
	if human_cols == 1:
		human_size.x = minf(520.0 * GAME_MENU_BUTTON_SCALE, content_width - (margin_x * 2.0))
	else:
		human_size.x = clampf(human_size.x, 390.0 * GAME_MENU_BUTTON_SCALE, 450.0 * GAME_MENU_BUTTON_SCALE)
	y = _place_free_roll_button_grid(panel, human_paths, margin_x, y, content_width, human_cols, human_size, human_gap, 26.0)

	y += 34.0
	_place_free_roll_label(panel, "EntryScroll/EntryBody/EntryCanvas/TimePuzzlesHeading", margin_x, y, content_width - (margin_x * 2.0), 28.0, HORIZONTAL_ALIGNMENT_CENTER)
	y += 32.0
	_place_free_roll_label(panel, "EntryScroll/EntryBody/EntryCanvas/TimePuzzlesSubtext", margin_x, y, content_width - (margin_x * 2.0), 24.0, HORIZONTAL_ALIGNMENT_CENTER)
	y += 44.0
	var cycle_paths: Array[String] = [
		"EntryScroll/EntryBody/EntryCanvas/WeeklyButton",
		"EntryScroll/EntryBody/EntryCanvas/MonthlyButton",
		"EntryScroll/EntryBody/EntryCanvas/SeasonButton"
	]
	var cycle_cols: int = 2 if content_width >= 760.0 else 1
	var cycle_gap: float = 30.0 if cycle_cols == 2 else 0.0
	var cycle_size := Vector2(
		420.0 * GAME_MENU_BUTTON_SCALE if cycle_cols == 2 else minf(520.0 * GAME_MENU_BUTTON_SCALE, content_width - (margin_x * 2.0)),
		round((156.0 if cycle_cols == 2 else 168.0) * GAME_MENU_BUTTON_SCALE)
	)
	y = _place_free_roll_button_grid(panel, cycle_paths, margin_x, y, content_width, cycle_cols, cycle_size, cycle_gap, 24.0)

	y += 34.0
	var divider: ColorRect = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/MapConfigDivider") as ColorRect
	if divider != null:
		divider.offset_left = margin_x
		divider.offset_top = y
		divider.offset_right = content_width - margin_x
		divider.offset_bottom = y + 2.0
	y += 26.0
	_place_free_roll_label(panel, "EntryScroll/EntryBody/EntryCanvas/MapConfigLabel", margin_x, y, content_width - (margin_x * 2.0), 26.0, HORIZONTAL_ALIGNMENT_CENTER)
	y += 44.0

	_place_free_roll_label(panel, "EntryScroll/EntryBody/EntryCanvas/OneMapHeading", margin_x, y, 140.0, 26.0, HORIZONTAL_ALIGNMENT_LEFT)
	y += 34.0
	var one_map_paths: Array[String] = [
		"EntryScroll/EntryBody/EntryCanvas/CaptureFlagButton",
		"EntryScroll/EntryBody/EntryCanvas/HiddenFlagButton"
	]
	var one_map_cols: int = 2 if content_width >= 760.0 else 1
	var one_map_size := Vector2(
		420.0 * GAME_MENU_BUTTON_SCALE if one_map_cols == 2 else minf(520.0 * GAME_MENU_BUTTON_SCALE, content_width - (margin_x * 2.0)),
		round(150.0 * GAME_MENU_BUTTON_SCALE)
	)
	y = _place_free_roll_button_grid(panel, one_map_paths, margin_x, y, content_width, one_map_cols, one_map_size, 34.0, 22.0)

	y += 28.0
	_place_free_roll_label(panel, "EntryScroll/EntryBody/EntryCanvas/ThreeMapHeading", margin_x, y, 140.0, 26.0, HORIZONTAL_ALIGNMENT_LEFT)
	y += 34.0
	var three_map_paths: Array[String] = [
		"EntryScroll/EntryBody/EntryCanvas/StageRace3Button",
		"EntryScroll/EntryBody/EntryCanvas/TimedRace3Button",
		"EntryScroll/EntryBody/EntryCanvas/MissNOut3Button"
	]
	var map_cols: int = 2 if content_width >= 760.0 else 1
	var map_gap: float = 30.0 if map_cols == 2 else 0.0
	var map_size := Vector2(
		floor((content_width - (margin_x * 2.0) - (map_gap * float(map_cols - 1))) / float(map_cols)),
		round(144.0 * GAME_MENU_BUTTON_SCALE)
	)
	if map_cols == 1:
		map_size.x = minf(520.0 * GAME_MENU_BUTTON_SCALE, content_width - (margin_x * 2.0))
	else:
		map_size.x = clampf(map_size.x, 390.0 * GAME_MENU_BUTTON_SCALE, 440.0 * GAME_MENU_BUTTON_SCALE)
	y = _place_free_roll_button_grid(panel, three_map_paths, margin_x, y, content_width, map_cols, map_size, map_gap, 22.0)

	y += 28.0
	_place_free_roll_label(panel, "EntryScroll/EntryBody/EntryCanvas/FiveMapHeading", margin_x, y, 140.0, 26.0, HORIZONTAL_ALIGNMENT_LEFT)
	y += 34.0
	var five_map_paths: Array[String] = [
		"EntryScroll/EntryBody/EntryCanvas/StageRace5Button",
		"EntryScroll/EntryBody/EntryCanvas/TimedRace5Button",
		"EntryScroll/EntryBody/EntryCanvas/MissNOut5Button"
	]
	y = _place_free_roll_button_grid(panel, five_map_paths, margin_x, y, content_width, map_cols, map_size, map_gap, 22.0)

	y += 64.0
	var cancel_size := Vector2(minf(440.0 * GAME_MENU_BUTTON_SCALE, content_width - (margin_x * 2.0)), round(146.0 * GAME_MENU_BUTTON_SCALE))
	y = _place_free_roll_button_grid(panel, ["EntryScroll/EntryBody/EntryCanvas/CancelButton"], margin_x, y, content_width, 1, cancel_size, 0.0, 0.0)
	canvas.custom_minimum_size = Vector2(content_width, y + 150.0)

func _place_free_roll_label(panel: Panel, path: String, x: float, y: float, w: float, h: float, alignment: HorizontalAlignment) -> void:
	var label: Label = panel.get_node_or_null(path) as Label
	if label == null:
		return
	label.layout_mode = 0
	label.offset_left = x
	label.offset_top = y
	label.offset_right = x + w
	label.offset_bottom = y + h
	label.horizontal_alignment = alignment

func _place_free_roll_button_grid(
		panel: Panel,
		paths: Array[String],
		margin_x: float,
		start_y: float,
		content_width: float,
		columns: int,
		button_size: Vector2,
		gap_x: float,
		gap_y: float
	) -> float:
	var resolved_columns: int = maxi(1, columns)
	var y: float = start_y
	for i in range(paths.size()):
		var path: String = paths[i]
		var button: Button = panel.get_node_or_null(path) as Button
		if button == null:
			continue
		var col: int = i % resolved_columns
		var row: int = int(floor(float(i) / float(resolved_columns)))
		var remaining: int = paths.size() - (row * resolved_columns)
		var row_items: int = mini(resolved_columns, maxi(1, remaining))
		var row_width: float = (button_size.x * float(row_items)) + (gap_x * float(row_items - 1))
		var row_left: float = floor((content_width - row_width) * 0.5)
		row_left = maxf(margin_x, row_left)
		var x: float = row_left + (float(col) * (button_size.x + gap_x))
		y = start_y + (float(row) * (button_size.y + gap_y))
		_place_free_roll_button(button, x, y, button_size)
	var rows: int = int(ceil(float(paths.size()) / float(resolved_columns)))
	return start_y + (float(maxi(0, rows)) * button_size.y) + (float(maxi(0, rows - 1)) * gap_y)

func _place_free_roll_button(button: Button, x: float, y: float, size: Vector2) -> void:
	button.layout_mode = 0
	button.scale = Vector2.ONE
	button.custom_minimum_size = size
	button.offset_left = x
	button.offset_top = y
	button.offset_right = x + size.x
	button.offset_bottom = y + size.y

func _scaled_game_hub_size(base_size: Vector2, size_scale: float) -> Vector2:
	var scale: float = maxf(0.1, size_scale)
	return Vector2(round(base_size.x * scale), round(base_size.y * scale))

func _scaled_game_hub_icon_width(base_width: int, size_scale: float) -> int:
	var scale: float = maxf(0.1, size_scale)
	return maxi(1, int(round(float(base_width) * scale)))

func _button_authored_width(button: Button) -> float:
	if button == null:
		return 0.0
	var width: float = maxf(button.custom_minimum_size.x, button.size.x)
	if button.layout_mode == 0:
		width = maxf(width, button.offset_right - button.offset_left)
	return width

func _set_layout_driven_icon_width(button: Button, fallback_width: int, width_ratio: float = 0.96) -> void:
	if button == null:
		return
	var authored_width: float = _button_authored_width(button)
	if authored_width <= 1.0:
		button.set("icon_max_width", fallback_width)
		return
	var resolved_ratio: float = clampf(width_ratio, 0.1, 1.0)
	button.set("icon_max_width", maxi(1, int(round(authored_width * resolved_ratio))))

func _game_hub_base_scale(button: Button) -> Vector2:
	if button == null:
		return Vector2.ONE
	var base_any: Variant = button.get_meta("sf_game_hub_base_scale", Vector2.ONE)
	if typeof(base_any) == TYPE_VECTOR2:
		return base_any as Vector2
	return Vector2.ONE

func _game_hub_scaled_target(button: Button, multiplier: float) -> Vector2:
	var base_scale: Vector2 = _game_hub_base_scale(button)
	return Vector2(base_scale.x * multiplier, base_scale.y * multiplier)

func _compact_game_hub_async_mode_button(button: Button, size_scale: float = 1.0) -> void:
	if button == null:
		return
	button.custom_minimum_size = _scaled_game_hub_size(GAME_HUB_ASYNC_MODE_BUTTON_SIZE, size_scale)
	button.set("icon_max_width", _scaled_game_hub_icon_width(GAME_HUB_ASYNC_MODE_ICON_MAX_WIDTH, size_scale))

func _tune_game_hub_human_button(button: Button, size_scale: float = 1.0) -> void:
	if button == null:
		return
	button.custom_minimum_size = _scaled_game_hub_size(GAME_HUB_HUMAN_BUTTON_SIZE, size_scale)
	button.set("icon_max_width", _scaled_game_hub_icon_width(GAME_HUB_HUMAN_ICON_MAX_WIDTH, size_scale))

func _tune_game_hub_cycle_button(button: Button, size_scale: float = 1.0) -> void:
	if button == null:
		return
	button.custom_minimum_size = _scaled_game_hub_size(GAME_HUB_CYCLE_BUTTON_SIZE, size_scale)
	button.set("icon_max_width", _scaled_game_hub_icon_width(GAME_HUB_CYCLE_ICON_MAX_WIDTH, size_scale))

func _apply_game_hub_center_track_shift(track: MarginContainer, shift_x_px: float) -> void:
	if track == null:
		return
	track.add_theme_constant_override("margin_left", int(round(-shift_x_px)))
	track.add_theme_constant_override("margin_right", int(round(shift_x_px)))

func _make_game_hub_center_track(parent: Control, right_inset_px: float = 0.0) -> Control:
	if parent == null or is_zero_approx(right_inset_px):
		return parent
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_game_hub_center_track_shift(margin, right_inset_px)
	parent.add_child(margin)
	return margin

func _make_game_hub_label_container(parent: Control, rebound_x: float = 0.0) -> Control:
	if parent == null or is_zero_approx(rebound_x):
		return parent
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if rebound_x > 0.0:
		margin.add_theme_constant_override("margin_left", int(round(rebound_x)))
	elif rebound_x < 0.0:
		margin.add_theme_constant_override("margin_right", int(round(-rebound_x)))
	parent.add_child(margin)
	return margin

func _add_game_hub_block_label(parent: VBoxContainer, text_value: String, subdued: bool = false, rebound_x: float = 0.0) -> void:
	if parent == null:
		return
	var container: Control = _make_game_hub_label_container(parent, rebound_x)
	var label := Label.new()
	label.text = text_value.strip_edges().to_upper()
	var label_color: Color = GAME_HUB_BLOCK_LABEL_COLOR
	if subdued:
		label_color = Color(label_color.r, label_color.g, label_color.b, 0.46)
	label.add_theme_color_override("font_color", label_color)
	label.add_theme_constant_override("outline_size", 0)
	if subdued:
		label.add_theme_constant_override("font_spacing", 1)
	container.add_child(label)
	_apply_font(label, _font_regular if subdued else _font_semibold, 11)

func _add_game_hub_section_header(parent: VBoxContainer, heading: String, subtext: String = "", subdued: bool = false, rebound_x: float = 0.0) -> void:
	if parent == null:
		return
	var container: Control = _make_game_hub_label_container(parent, rebound_x)
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 0)
	container.add_child(section)
	var heading_label := Label.new()
	heading_label.text = heading.strip_edges().to_upper()
	var heading_color: Color = GAME_HUB_SECTION_HEADER_COLOR
	if subdued:
		heading_color = Color(heading_color.r, heading_color.g, heading_color.b, 0.49)
	heading_label.add_theme_color_override("font_color", heading_color)
	heading_label.add_theme_constant_override("outline_size", 0)
	if subdued:
		heading_label.add_theme_constant_override("font_spacing", 1)
	section.add_child(heading_label)
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
	section.add_child(subtext_label)
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
	tabs_row.add_theme_constant_override("separation", 12)
	body.add_child(tabs_row)
	_add_game_hub_spacer(body, 8.0)
	var entry_label := Label.new()
	entry_label.text = "ENTRY TIER"
	entry_label.add_theme_color_override("font_color", MONEY_ENTRY_LABEL_COLOR)
	body.add_child(entry_label)
	_apply_font(entry_label, _font_semibold, MONEY_ENTRY_LABEL_SIZE)
	var tier_row := HBoxContainer.new()
	tier_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 14)
	body.add_child(tier_row)
	_add_game_hub_spacer(body, 8.0)
	var division_arena_label := Label.new()
	division_arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	division_arena_label.add_theme_color_override("font_color", GAME_HUB_SECTION_HEADER_COLOR)
	body.add_child(division_arena_label)
	_apply_font(division_arena_label, _font_semibold, MONEY_ARENA_LABEL_SIZE)
	var entry_fee_label := Label.new()
	entry_fee_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_fee_label.add_theme_color_override("font_color", MONEY_ENTRY_LABEL_COLOR)
	body.add_child(entry_fee_label)
	_apply_font(entry_fee_label, _font_regular, MONEY_ENTRY_FEE_LABEL_SIZE)
	_add_game_hub_spacer(body, 12.0)
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
				_apply_font(button, _font_semibold, MONEY_ENTRY_TIER_LABEL_SIZE)
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
		free_layout: bool = false,
		broadcast_free_roll: bool = false,
		size_scale: float = 1.0,
		rebound_x: float = 0.0,
		center_track_right_inset_px: float = 0.0
	) -> void:
	if parent == null:
		return
	_add_game_hub_section_header(parent, heading, "", broadcast_free_roll, rebound_x)
	var row_host: Control = _make_game_hub_center_track(parent, center_track_right_inset_px)
	var row_wrap := HBoxContainer.new()
	row_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	row_host.add_child(row_wrap)
	var row := GridContainer.new()
	row.columns = 2 if paid and _use_game_hub_touch_layout() else 3
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row_separation: int = 6
	var row_button_scale: float = size_scale
	if paid and _use_game_hub_touch_layout():
		row_separation = GAME_HUB_TOUCH_PAID_CLUSTER_SPACING
	if free_layout:
		row_separation = 10
		if items.size() >= 3:
			row_separation = GAME_HUB_FREE_TRIPLE_ROW_SEPARATION
			row_button_scale *= GAME_HUB_FREE_TRIPLE_ROW_SCALE
	row.add_theme_constant_override("h_separation", row_separation)
	row.add_theme_constant_override("v_separation", row_separation)
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
		_compact_game_hub_async_mode_button(button, row_button_scale)
		_configure_game_hub_option_button(button, broadcast_free_roll)

func _style_game_hub_cancel_button(button: Button, size_scale: float = 1.0, preserve_layout: bool = false) -> void:
	if button == null:
		return
	var scaled_size: Vector2 = _scaled_game_hub_size(GAME_HUB_CANCEL_BUTTON_SIZE, size_scale)
	button.set_meta("sf_cancel_skin", true)
	button.set_meta("sf_close_skin", false)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not preserve_layout:
		button.custom_minimum_size = scaled_size
	button.set_meta("sf_cancel_skin_min_w", scaled_size.x)
	button.set_meta("sf_cancel_skin_min_h", scaled_size.y)
	_apply_font(button, _font_regular, 12)
	_style_button(button, Color(0.15, 0.16, 0.19, 0.72), Color(0.28, 0.30, 0.34, 0.26), Color(0.74, 0.77, 0.82))
	if not preserve_layout:
		button.custom_minimum_size = scaled_size
	if preserve_layout:
		_set_layout_driven_icon_width(button, GAME_HUB_ASYNC_MODE_ICON_MAX_WIDTH)
	else:
		button.set("icon_max_width", _scaled_game_hub_icon_width(GAME_HUB_ASYNC_MODE_ICON_MAX_WIDTH, size_scale))

func _configure_game_hub_option_button(button: Button, broadcast_mode: bool = false) -> void:
	if button == null:
		return
	if button.has_meta("sf_game_hub_motion"):
		return
	button.set_meta("sf_game_hub_motion", true)
	button.set_meta("sf_game_hub_base_modulate", button.modulate)
	button.set_meta("sf_game_hub_base_scale", button.scale)
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
		var target_scale := _game_hub_scaled_target(button, 1.024) if hovered else _game_hub_base_scale(button)
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
		button.scale = _game_hub_scaled_target(button, 0.986) if pressed else _game_hub_base_scale(button)
		return
	if edge == null or shell_tone == null or inner_glow == null:
		return
	if not is_instance_valid(edge) or not is_instance_valid(shell_tone) or not is_instance_valid(inner_glow):
		return
	var hovered_any: Variant = button.get_meta("sf_game_hub_hovered", false)
	var hovered: bool = bool(hovered_any)
	var target_scale: Vector2 = _game_hub_base_scale(button)
	var target_shell_alpha: float = 0.0
	var target_glow_alpha: float = 0.0
	var target_edge_alpha: float = 0.0
	if pressed:
		target_scale = _game_hub_scaled_target(button, 1.012)
		target_shell_alpha = 0.0
		target_glow_alpha = 0.13
		target_edge_alpha = 0.0
	elif hovered:
		target_scale = _game_hub_scaled_target(button, 1.024)
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

func _apply_game_hub_title_treatment(panel: Panel, title: String, center_track_right_inset_px: float = 0.0) -> void:
	if panel == null:
		return
	if title.strip_edges().to_upper() != "FREE ROLL":
		return
	var title_label: Label = panel.get_node_or_null("EntryScroll/EntryBody/EntryTitle") as Label
	if title_label == null:
		return
	var subtitle_label: Label = panel.get_node_or_null("EntryScroll/EntryBody/EntrySubtitle") as Label
	var body: VBoxContainer = panel.get_node_or_null("EntryScroll/EntryBody") as VBoxContainer
	var scene_owned_layout: bool = bool(panel.get_meta("sf_scene_owned_layout", false))
	if body != null and center_track_right_inset_px > 0.0 and not scene_owned_layout:
		var header_track: MarginContainer = body.get_node_or_null("FreeRollHeaderTrack") as MarginContainer
		var header_box: VBoxContainer = null
		if header_track == null:
			header_track = MarginContainer.new()
			header_track.name = "FreeRollHeaderTrack"
			header_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_apply_game_hub_center_track_shift(header_track, center_track_right_inset_px)
			header_box = VBoxContainer.new()
			header_box.name = "FreeRollHeaderVBox"
			header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header_box.add_theme_constant_override("separation", 0)
			if title_label.get_parent() != null:
				title_label.get_parent().remove_child(title_label)
			if subtitle_label != null and subtitle_label.get_parent() != null:
				subtitle_label.get_parent().remove_child(subtitle_label)
			body.add_child(header_track)
			body.move_child(header_track, 0)
			header_track.add_child(header_box)
			header_box.add_child(title_label)
			if subtitle_label != null:
				header_box.add_child(subtitle_label)
		else:
			header_box = header_track.get_node_or_null("FreeRollHeaderVBox") as VBoxContainer
			if header_box != null:
				_apply_game_hub_center_track_shift(header_track, center_track_right_inset_px)
	if not _apply_free_roll_atlas_font(title_label, 22):
		_apply_font(title_label, _font_semibold, 20)
	title_label.add_theme_color_override("font_color", Color(0.995, 0.997, 1.0, 1.0))
	title_label.add_theme_constant_override("outline_size", 1)
	title_label.add_theme_color_override("font_outline_color", Color(GAME_HUB_TITLE_OUTLINE_COLOR.r, GAME_HUB_TITLE_OUTLINE_COLOR.g, GAME_HUB_TITLE_OUTLINE_COLOR.b, 0.08))
	title_label.add_theme_constant_override("font_spacing", 1)
	_apply_free_roll_title_micro_gradient(title_label)
	if subtitle_label != null:
		_apply_font(subtitle_label, _font_regular, 13)
		subtitle_label.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94, 0.88))
	if body != null and not scene_owned_layout:
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
	var max_height: float = maxf(240.0, viewport_size.y - (GAME_HUB_OVERLAY_VIEWPORT_MARGIN_Y * 2.0))
	var resolved_min_height: float = minf(min_height, max_height)
	return Vector2(
		minf(GAME_HUB_OVERLAY_TARGET_WIDTH, max_width),
		clampf(target_height, resolved_min_height, max_height)
	)

func _use_game_hub_touch_layout() -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	return viewport_size.y > viewport_size.x or viewport_size.x <= GAME_HUB_TOUCH_LAYOUT_MAX_WIDTH

func _enable_touch_drag_scroll(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_bind_touch_drag_scroll_to_control(scroll, scroll)

func _bind_touch_drag_scroll_to_control(control: Control, scroll: ScrollContainer) -> void:
	if control == null or scroll == null:
		return
	if not control.has_meta("sf_touch_drag_scroll_bound"):
		control.set_meta("sf_touch_drag_scroll_bound", true)
		var callback := Callable(self, "_on_touch_drag_scroll_gui_input").bind(scroll)
		if not control.gui_input.is_connected(callback):
			control.gui_input.connect(callback)
	for child in control.get_children():
		if child is Control:
			_bind_touch_drag_scroll_to_control(child as Control, scroll)

func _on_touch_drag_scroll_gui_input(event: InputEvent, scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	var delta_y: float = 0.0
	if event is InputEventScreenDrag:
		delta_y = (event as InputEventScreenDrag).relative.y
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		delta_y = (event as InputEventMouseMotion).relative.y
	if is_zero_approx(delta_y):
		return
	scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - int(round(delta_y)))
	scroll.accept_event()

func _on_human_mode_selected(mode_id: String, paid: bool, denomination: int) -> void:
	if _block_for_active_hive_tournament("human matches"):
		return
	if paid and not _require_balance_for_entry(maxi(1, denomination)):
		return
	if _is_direct_pvp_human_mode(mode_id):
		_close_entry_route_modal()
		get_tree().set_meta("requested_human_mode", mode_id)
		var pvp_entry_usd: int = maxi(0, denomination)
		if paid:
			pvp_entry_usd = maxi(1, pvp_entry_usd)
		else:
			pvp_entry_usd = 0
		_open_human_pvp_lobby(mode_id, not paid, pvp_entry_usd)
		if paid:
			status_label.text = "Human %s selected at $%d. PvP lobby opened." % [mode_id, pvp_entry_usd]
		else:
			status_label.text = "Human %s free roll selected. PvP lobby opened." % mode_id
		return
	if mode_id == "CTF":
		var entry_usd: int = maxi(0, denomination)
		if not paid:
			entry_usd = 0
		if _launch_direct_capture_flag("CAPTURE_FLAG", not paid, entry_usd):
			_close_entry_route_modal()
		return
	if mode_id == "HIDDEN CTF":
		var hidden_entry_usd: int = maxi(0, denomination)
		if not paid:
			hidden_entry_usd = 0
		if _launch_direct_capture_flag("HIDDEN_CAPTURE_FLAG", not paid, hidden_entry_usd):
			_close_entry_route_modal()
		return
	_close_entry_route_modal()
	get_tree().set_meta("requested_human_mode", mode_id)
	var lane := "paid" if paid else "free"
	status_label.text = "Human %s (%s) selected. Queue wiring is next." % [mode_id, lane]

func _is_direct_pvp_human_mode(mode_id: String) -> bool:
	var clean_mode: String = mode_id.strip_edges().to_upper()
	return clean_mode == "1V1" or clean_mode == "2V2" or clean_mode == "3P FFA" or clean_mode == "4P FFA"

func _open_human_pvp_lobby(mode_id: String, free_play: bool, entry_usd: int) -> void:
	var lobby_options: Dictionary = _human_pvp_lobby_options(mode_id)
	_open_async_vs_lobby(mode_id, 1, free_play, maxi(0, entry_usd), lobby_options)

func _human_pvp_lobby_options(mode_id: String) -> Dictionary:
	var lobby_options: Dictionary = {
		"human_pvp": true,
		"start_players": 2,
		"pregame_setup": "session_seeded"
	}
	var team_override: String = _human_pvp_team_mode_override(mode_id)
	if not team_override.is_empty():
		lobby_options["team_mode_override"] = team_override
	return lobby_options

func _human_pvp_map_ids(mode_id: String) -> PackedStringArray:
	var random_ids: PackedStringArray = _free_roll_random_map_ids(mode_id, 1)
	if not random_ids.is_empty():
		return random_ids
	var fallback: PackedStringArray = PackedStringArray()
	match mode_id.strip_edges().to_upper():
		"3P FFA":
			fallback.append("MAP_delta__SBASE__3p")
		_:
			fallback.append("MAP_nomansland__545__v01_top2_sides__1p")
	return fallback

func _human_pvp_team_mode_override(mode_id: String) -> String:
	match mode_id.strip_edges().to_upper():
		"2V2":
			return "2v2"
		"3P FFA", "4P FFA":
			return "ffa"
		_:
			return ""

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

func _on_async_cycle_selected(scope: String, paid: bool, denomination: int) -> void:
	var clean_scope: String = scope.strip_edges().to_upper()
	if clean_scope.is_empty():
		clean_scope = "WEEKLY"
	_apply_async_entry_amount(paid, denomination)
	_close_entry_route_modal()
	_open_stage_race_tournament_lobby(clean_scope, paid, denomination)

func _on_async_mode_selected(mode_id: String, paid: bool, denomination: int) -> void:
	if _block_for_active_hive_tournament("async matches"):
		return
	if paid and not _require_balance_for_entry(maxi(1, denomination)):
		return
	if mode_id == "CAPTURE_FLAG":
		_apply_async_entry_amount(paid, denomination)
		if _on_async_capture_flag_selected(not paid):
			_close_entry_route_modal()
		return
	if mode_id == "HIDDEN_CAPTURE_FLAG":
		_apply_async_entry_amount(paid, denomination)
		if _on_async_hidden_capture_flag_selected(not paid):
			_close_entry_route_modal()
		return
	_close_entry_route_modal()
	_apply_async_entry_amount(paid, denomination)
	match mode_id:
		"WEEKLY":
			_on_async_cycle_selected("WEEKLY", paid, denomination)
		"MONTHLY":
			_on_async_cycle_selected("MONTHLY", paid, denomination)
		"YEARLY":
			_on_async_cycle_selected("YEARLY", paid, denomination)
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
	if _block_for_active_hive_tournament("human matches"):
		return
	_open_vs_mode_select_panel(free_roll)
	if free_roll:
		status_label.text = "Human free-play selector opened."
	else:
		status_label.text = "Human paid-match selector opened."

func _open_async_entry_selector(free_roll: bool) -> void:
	if _block_for_active_hive_tournament("async matches"):
		return
	_close_entry_route_modal()
	_open_async_panel()
	if free_roll:
		_open_async_free_menu()
		status_label.text = "Async free-play selector opened."
	else:
		_open_async_paid_menu()
		status_label.text = "Async paid-contest selector opened."

func _open_vs_mode_select_panel(free_roll: bool, preset_mode: String = "") -> void:
	_close_top_level_windows(UI_SURFACE_PLAY_MODE)
	var panel := preload("res://scenes/ui/VsModeSelect.tscn").instantiate()
	if panel.has_method("configure_entry"):
		panel.call("configure_entry", free_roll)
	if not preset_mode.is_empty() and panel.has_method("configure_preset_mode"):
		panel.call("configure_preset_mode", preset_mode)
	panel.closed.connect(func(): panel.queue_free())
	add_child(panel)

func _resolve_entry_overlay_size(size: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var max_size := Vector2(
		maxf(320.0, viewport_size.x - 64.0),
		maxf(240.0, viewport_size.y - 64.0)
	)
	return Vector2(
		minf(size.x, max_size.x),
		minf(size.y, max_size.y)
	)

func _configure_entry_overlay_panel(panel: Panel, title: String, subtitle: String, size: Vector2 = Vector2(480, 220), preserve_scene_layout: bool = false) -> Panel:
	if panel == null:
		return null
	_close_entry_route_modal()
	var resolved_size: Vector2 = _resolve_entry_overlay_size(size)
	panel.name = "EntryRouteModal"
	panel.clip_contents = true
	panel.layout_mode = 0
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

	var scroll: ScrollContainer = panel.get_node_or_null("EntryScroll") as ScrollContainer
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "EntryScroll"
		panel.add_child(scroll)
	if not preserve_scene_layout:
		scroll.layout_mode = 1
		scroll.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		scroll.offset_left = 0.0
		scroll.offset_top = 0.0
		scroll.offset_right = 0.0
		scroll.offset_bottom = 0.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var body: VBoxContainer = _entry_overlay_body(panel)
	if body == null:
		body = VBoxContainer.new()
		body.name = "EntryBody"
		scroll.add_child(body)
	if not preserve_scene_layout:
		body.layout_mode = 0
		body.anchor_right = 1.0
		body.offset_left = 16.0
		body.offset_top = 16.0
		body.offset_right = -16.0
		body.custom_minimum_size = Vector2(maxf(resolved_size.x - 32.0, 280.0), 0.0)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 10)

	var title_label: Label = panel.get_node_or_null("EntryScroll/EntryBody/EntryTitle") as Label
	if title_label == null:
		title_label = Label.new()
		title_label.name = "EntryTitle"
		body.add_child(title_label)
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var subtitle_label: Label = panel.get_node_or_null("EntryScroll/EntryBody/EntrySubtitle") as Label
	if subtitle_label == null:
		subtitle_label = Label.new()
		subtitle_label.name = "EntrySubtitle"
		body.add_child(subtitle_label)
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if panel.get_parent() != self:
		add_child(panel)
	_style_panel(panel, Color(0.06, 0.07, 0.1, 0.98), Color(0.45, 0.48, 0.58, 0.8))
	_apply_font(title_label, _font_semibold, 18)
	_apply_font(subtitle_label, _font_regular, 13)
	return panel

func _build_entry_overlay(title: String, subtitle: String, size: Vector2 = Vector2(480, 220)) -> Panel:
	var panel := Panel.new()
	return _configure_entry_overlay_panel(panel, title, subtitle, size)

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

	var popup_bg_node: Node = _load_packed_scene(HEX_SEAM_BACKGROUND_SCENE_PATH).instantiate()
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
	if _match_background_inlay() == null:
		return null
	var source_size: Vector2 = _match_background_inlay().get_size()
	if source_size.x <= 1.0 or source_size.y <= 1.0:
		return _match_background_inlay()
	# Broadcast inlay is authored in landscape; force rotated source for portrait-first game UI.
	var rotated: Texture2D = _get_entry_overlay_rotated_inlay_texture()
	if rotated == null:
		return _get_entry_overlay_cropped_inlay_texture(_match_background_inlay(), false)
	return _get_entry_overlay_cropped_inlay_texture(rotated, true)

func _get_entry_overlay_rotated_inlay_texture() -> Texture2D:
	if _entry_overlay_inlay_rotated_texture != null:
		return _entry_overlay_inlay_rotated_texture
	if _match_background_inlay() == null:
		return null
	var base_image: Image = _match_background_inlay().get_image()
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

func _open_async_stage_contest_leaderboard(map_count: int, scope: String = "WEEKLY", paid: bool = false, denomination: int = 0, highlight_player_id: String = "", highlight_run_id: String = "") -> void:
	_close_top_level_windows(UI_SURFACE_ENTRY)
	var resolved_map_count: int = 5
	if map_count == 3:
		resolved_map_count = 3
	var clean_scope: String = scope.strip_edges().to_upper()
	if clean_scope.is_empty():
		clean_scope = "WEEKLY"
	var contest_data: Dictionary = _resolve_async_stage_contest_data(resolved_map_count, clean_scope, paid, denomination)
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
		var row_highlighted: bool = _stage_leaderboard_row_matches_highlight(entry, highlight_player_id, highlight_run_id)
		if row_highlighted:
			row_box.set_meta("stage_leaderboard_highlighted", true)
			row_box.modulate = Color(1.0, 0.90, 0.48, 1.0)
		var handle_label: Label = Label.new()
		handle_label.text = "%d. %s" % [i + 1, str(entry.get("handle", "--"))]
		handle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_child(handle_label)
		_apply_font(handle_label, _font_regular, 12)
		if row_highlighted:
			handle_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.55, 1.0))
		var total_label: Label = Label.new()
		total_label.text = str(entry.get("total_time", "--:--.---"))
		total_label.custom_minimum_size = Vector2(240.0, 0.0)
		total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row_box.add_child(total_label)
		_apply_font(total_label, _font_regular, 12)
		if row_highlighted:
			total_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.55, 1.0))
		var left_label: Label = Label.new()
		left_label.text = str(entry.get("time_left", "--"))
		left_label.custom_minimum_size = Vector2(220.0, 0.0)
		left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row_box.add_child(left_label)
		_apply_font(left_label, _font_regular, 12)
		if row_highlighted:
			left_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.55, 1.0))
			_pulse_stage_leaderboard_row(row_box)
	if rows.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No stage race submissions yet."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(empty_label)
		_apply_font(empty_label, _font_regular, 12)

	var play_button: Button = Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(0.0, 56.0)
	if paid:
		play_button.pressed.connect(func():
			_close_entry_route_modal()
			_open_stage_race_tournament_lobby(clean_scope, paid, denomination)
		)
	else:
		play_button.pressed.connect(func():
			_close_entry_route_modal()
			_start_free_stage_race_contest(clean_scope, resolved_map_count)
		)
	body.add_child(play_button)
	_apply_font(play_button, _font_semibold, 15)
	_style_button(play_button, Color(0.20, 0.15, 0.03), Color(0.95, 0.67, 0.05), Color(1.0, 0.90, 0.52))

	var close_button: Button = Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0.0, 40.0)
	close_button.pressed.connect(_close_entry_route_modal)
	body.add_child(close_button)
	_apply_font(close_button, _font_regular, 13)
	_style_button(close_button, Color(0.12, 0.13, 0.16), Color(0.4, 0.42, 0.5), Color(0.9, 0.9, 0.9))
	_entry_route_modal = panel

func _stage_leaderboard_row_matches_highlight(entry: Dictionary, highlight_player_id: String, highlight_run_id: String) -> bool:
	if entry.is_empty():
		return false
	var clean_run_id: String = highlight_run_id.strip_edges()
	if not clean_run_id.is_empty():
		return str(entry.get("run_id", "")).strip_edges() == clean_run_id
	var clean_player_id: String = highlight_player_id.strip_edges()
	if clean_player_id.is_empty():
		return false
	return str(entry.get("player_id", "")).strip_edges() == clean_player_id

func _pulse_stage_leaderboard_row(row: Control) -> void:
	if row == null:
		return
	var tween: Tween = create_tween()
	tween.set_loops(6)
	tween.tween_property(row, "modulate", Color(1.0, 0.72, 0.18, 1.0), 0.32)
	tween.tween_property(row, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.32)

func _resolve_async_stage_contest_data(map_count: int, scope: String = "WEEKLY", paid: bool = false, denomination: int = 0) -> Dictionary:
	var output: Dictionary = {
		"contest_id": "",
		"contest_name": "Stage Contest",
		"time_left": "--",
		"rows": []
	}
	var contest_state: Node = get_node_or_null("/root/ContestState")
	if contest_state == null:
		return output
	var contest_obj: Variant = _select_async_stage_contest_for_leaderboard(contest_state, scope, paid, denomination)
	if contest_obj == null:
		return output
	var contest_id: String = str(_variant_dict_or_object_get(contest_obj, "id", ""))
	if contest_id.is_empty():
		return output
	output["contest_id"] = contest_id
	var contest_price: int = maxi(0, int(_variant_dict_or_object_get(contest_obj, "price", 0)))
	if contest_price == 0:
		output["contest_name"] = "%s Stage Race - Free Roll" % str(_variant_dict_or_object_get(contest_obj, "scope", scope)).strip_edges().to_upper()
	else:
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
			"player_id": str(row.get("player_id", "")).strip_edges(),
			"run_id": str(row.get("run_id", "")).strip_edges(),
			"handle": handle,
			"total_time": _format_async_stage_total_time_ms(int(row.get("aggregate_time_ms", 0))),
			"time_left": str(output.get("time_left", "--"))
		})
	output["rows"] = rows_out
	return output

func _select_async_stage_contest_for_leaderboard(contest_state: Node, scope: String = "WEEKLY", paid: bool = false, denomination: int = 0) -> Variant:
	var selected: Variant = null
	var clean_scope: String = scope.strip_edges().to_upper()
	if clean_scope.is_empty():
		clean_scope = "WEEKLY"
	var target_entry_usd: int = maxi(1, denomination) if paid else 0
	var best_distance: int = 2147483647
	var best_price: int = 2147483647
	if not paid:
		var free_contest: Variant = _select_free_stage_race_contest_for_scope(contest_state, clean_scope)
		if free_contest != null:
			return free_contest
	if contest_state.has_method("get_contests_by_scope"):
		var contests_any: Variant = contest_state.call("get_contests_by_scope", clean_scope)
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
				if paid:
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
		var fallback_any: Variant = contest_state.call("get_contest_by_scope", clean_scope)
		if fallback_any != null:
			return fallback_any
	return null

func _select_free_stage_race_contest_for_scope(contest_state: Node, scope: String) -> Variant:
	var contests_any: Variant = contest_state.get("contests")
	if typeof(contests_any) != TYPE_DICTIONARY:
		return null
	var clean_scope: String = scope.strip_edges().to_upper()
	var selected: Variant = null
	for contest_any in (contests_any as Dictionary).values():
		if contest_any == null:
			continue
		if str(_variant_dict_or_object_get(contest_any, "scope", "")).strip_edges().to_upper() != clean_scope:
			continue
		if not bool(_variant_dict_or_object_get(contest_any, "published", false)):
			continue
		if maxi(0, int(_variant_dict_or_object_get(contest_any, "price", -1))) != 0:
			continue
		var map_ids_any: Variant = _variant_dict_or_object_get(contest_any, "map_ids", PackedStringArray())
		var map_count: int = 0
		if typeof(map_ids_any) == TYPE_PACKED_STRING_ARRAY:
			map_count = (map_ids_any as PackedStringArray).size()
		elif typeof(map_ids_any) == TYPE_ARRAY:
			map_count = (map_ids_any as Array).size()
		if map_count < 5:
			continue
		if selected == null or str(_variant_dict_or_object_get(contest_any, "id", "")) < str(_variant_dict_or_object_get(selected, "id", "")):
			selected = contest_any
	return selected

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
	if _entry_route_modal != null and is_instance_valid(_entry_route_modal):
		_entry_route_modal.queue_free()
	else:
		var orphaned_modal: Node = get_node_or_null("EntryRouteModal")
		if orphaned_modal != null:
			orphaned_modal.queue_free()
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
	_vs_lobby_return_async_panel = false

func _close_time_puzzle_lobby() -> void:
	if _time_puzzle_lobby == null:
		return
	if is_instance_valid(_time_puzzle_lobby):
		_time_puzzle_lobby.queue_free()
	_time_puzzle_lobby = null
	_time_puzzle_return_async_panel = false

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
		_jukebox_direct_mode = false
		_replay_direct_mode = false
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
	if except_surface != UI_SURFACE_RANK_CONTEXT and _rank_context_panel != null:
		_rank_context_panel.visible = false

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
		dash_hexes.visible = false
	dash_tab.visible = visible

func _set_dash_hidden_state() -> void:
	_set_dash_chrome_visible(true)
	_set_dash_offsets(_dash_hidden_x)
	dash_panel.visible = false
	_dash_open = false
	_replay_direct_mode = false

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
	_play_mm_base_drop_sfx()
	if _hive_direct_mode:
		_close_hive_panel()
		return
	_sync_hive_panel_profile_from_hive_state()
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
	_apply_buffs_panel_layout()
	_ensure_buffs_cart_ui()
	_sync_buff_mode_tabs()
	_sync_buff_category_tabs()
	_refresh_buffs_loadout_ui()
	_refresh_buffs_owned_ui()
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
	_play_mm_base_drop_sfx()
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
	_play_mm_base_drop_sfx()
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
	_play_mm_base_drop_sfx()
	if _hive_dropdown_open:
		_hide_hive_dropdown_immediate()
	if _replay_direct_mode:
		_close_direct_replay_panel()
		return
	if _jukebox_direct_mode:
		_close_jukebox_panel()
		return
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
	if panel == _jukebox_panel:
		_open_jukebox_panel()
		return
	_play_mm_base_drop_sfx()
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
	if panel == dash_settings_panel:
		_refresh_dash_top_tabs()
	if panel == _dash_scholastic_panel:
		_refresh_dash_top_tabs()

func _open_dash_panel_from_menu(panel: Panel) -> void:
	_open_dash_panel(panel)
	if not _dash_open:
		_toggle_dash()

func _close_dash_panel(panel: Panel) -> void:
	if panel == null:
		return
	if panel == dash_replay_panel and _replay_direct_mode:
		_close_direct_replay_panel()
		return
	if panel == _jukebox_panel and _jukebox_direct_mode:
		_close_jukebox_panel()
		return
	if panel == dash_store_panel:
		_set_dash_panel_store_passthrough(false)
	panel.visible = false
	if panel == dash_settings_panel:
		_refresh_dash_top_tabs()
	if panel == _dash_scholastic_panel:
		_refresh_dash_top_tabs()

func _close_direct_replay_panel() -> void:
	_stop_replay_playback()
	_replay_direct_mode = false
	if dash_replay_panel != null:
		dash_replay_panel.visible = false
	_hide_dash_panels()
	_set_dash_hidden_state()

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
	for panel in [dash_stats_panel, dash_analysis_panel, dash_replay_panel, dash_buffs_panel, dash_hive_panel, dash_store_panel, dash_settings_panel, dash_badges_panel_full, _jukebox_panel, _async_contest_dash_panel, _dash_friends_panel, _dash_scholastic_panel]:
		if panel == null:
			continue
		panel.visible = false
	_refresh_dash_top_tabs()

func _ensure_jukebox_panel() -> void:
	if dash_panel == null:
		return
	if _jukebox_panel == null and _load_packed_scene(JUKEBOX_PANEL_SCENE_PATH) != null:
		var panel_any: Node = _load_packed_scene(JUKEBOX_PANEL_SCENE_PATH).instantiate()
		if panel_any is Panel:
			_jukebox_panel = panel_any as Panel
			_jukebox_panel.name = "DashJukeboxPanel"
			_jukebox_panel.anchor_left = 0.0
			_jukebox_panel.anchor_top = 0.0
			_jukebox_panel.anchor_right = 1.0
			_jukebox_panel.anchor_bottom = 1.0
			_jukebox_panel.offset_left = 0.0
			_jukebox_panel.offset_top = 0.0
			_jukebox_panel.offset_right = 0.0
			_jukebox_panel.offset_bottom = 0.0
			_jukebox_panel.visible = false
			dash_panel.add_child(_jukebox_panel)
			if _jukebox_panel.has_method("set_content_top_offset"):
				_jukebox_panel.call("set_content_top_offset", _main_usable_top_px())
			elif _jukebox_panel.has_method("set_top_safe_inset"):
				_jukebox_panel.call("set_top_safe_inset", _main_usable_top_px())
			if _jukebox_panel.has_signal("closed"):
				_jukebox_panel.connect("closed", func() -> void:
					_close_jukebox_panel()
				)
			if _jukebox_panel.has_signal("play_requested"):
				_jukebox_panel.connect("play_requested", Callable(self, "_on_jukebox_play_requested"))
	if dash_hexes == null:
		return
	if _dash_hex_jukebox == null:
		_dash_hex_jukebox = HexButton.new()
		_dash_hex_jukebox.name = "DashJukebox"
		dash_hexes.add_child(_dash_hex_jukebox)
		_dash_hex_jukebox.pressed.connect(func() -> void:
			_open_jukebox_panel()
		)
		_set_hex_buttons()

func _ensure_async_contest_dash_panel() -> void:
	if dash_panel == null:
		return
	if _async_contest_dash_panel == null:
		var panel_any: Node = AsyncContestDashPanelScript.new()
		if panel_any is Panel:
			_async_contest_dash_panel = panel_any as Panel
			_async_contest_dash_panel.name = "DashAsyncContestPanel"
			_async_contest_dash_panel.anchor_left = 0.0
			_async_contest_dash_panel.anchor_top = 0.0
			_async_contest_dash_panel.anchor_right = 1.0
			_async_contest_dash_panel.anchor_bottom = 1.0
			_async_contest_dash_panel.offset_left = 0.0
			_async_contest_dash_panel.offset_top = 0.0
			_async_contest_dash_panel.offset_right = 0.0
			_async_contest_dash_panel.offset_bottom = 0.0
			_async_contest_dash_panel.visible = false
			dash_panel.add_child(_async_contest_dash_panel)
			if _async_contest_dash_panel.has_method("set_content_top_offset"):
				_async_contest_dash_panel.call("set_content_top_offset", _main_usable_top_px())
			if _async_contest_dash_panel.has_signal("close_requested"):
				_async_contest_dash_panel.connect("close_requested", func() -> void:
					_close_async_contest_dash_panel()
				)
			if _async_contest_dash_panel.has_signal("config_saved"):
				_async_contest_dash_panel.connect("config_saved", Callable(self, "_on_async_contest_dash_config_saved"))
	if dash_hexes == null:
		return
	if _dash_hex_async_contest == null:
		_dash_hex_async_contest = HexButton.new()
		_dash_hex_async_contest.name = "DashAsyncContest"
		dash_hexes.add_child(_dash_hex_async_contest)
		_dash_hex_async_contest.pressed.connect(func() -> void:
			_open_async_contest_dash_panel()
		)
		_set_hex_buttons()

func _open_jukebox_panel() -> void:
	if _jukebox_panel == null:
		_ensure_jukebox_panel()
	if _jukebox_panel == null:
		return
	_play_mm_base_drop_sfx()
	_close_top_level_windows(UI_SURFACE_DASH)
	_jukebox_direct_mode = true
	_hide_dash_panels()
	_set_dash_chrome_visible(false)
	_set_dash_panel_store_passthrough(false)
	_set_dash_offsets(0.0)
	dash_panel.visible = true
	_jukebox_panel.visible = true
	_dash_open = true

func _close_jukebox_panel() -> void:
	_jukebox_direct_mode = false
	if _jukebox_panel != null:
		_jukebox_panel.visible = false
	_set_dash_hidden_state()

func _open_async_contest_dash_panel() -> void:
	if _async_contest_dash_panel == null:
		_ensure_async_contest_dash_panel()
	if _async_contest_dash_panel == null:
		return
	_play_mm_base_drop_sfx()
	_close_top_level_windows(UI_SURFACE_DASH)
	_hide_dash_panels()
	_set_dash_chrome_visible(false)
	_set_dash_panel_store_passthrough(false)
	_set_dash_offsets(0.0)
	dash_panel.visible = true
	_async_contest_dash_panel.visible = true
	_dash_open = true

func _close_async_contest_dash_panel() -> void:
	if _async_contest_dash_panel != null:
		_async_contest_dash_panel.visible = false
	_set_dash_hidden_state()

func _on_async_contest_dash_config_saved(config: Dictionary) -> void:
	if status_label != null:
		status_label.text = "%s %d-map async contest saved." % [str(config.get("scope", "Weekly")).capitalize(), int(config.get("map_count", 3))]

func _on_jukebox_play_requested(map_path: String, cpu_style: String = "", cpu_tier: String = "") -> void:
	if map_path.strip_edges().is_empty():
		status_label.text = "No map selected."
		return
	_play_jukebox_play_sfx()
	if _launch_jukebox_map(map_path, cpu_style, cpu_tier):
		status_label.text = "Jukebox map starting..."
	else:
		status_label.text = "Jukebox launch failed."

func _open_jukebox_from_menu_button() -> void:
	if _jukebox_panel == null:
		_ensure_jukebox_panel()
		if _jukebox_panel == null:
			status_label.text = "Jukebox unavailable."
			return
	_open_jukebox_panel()
	status_label.text = "Jukebox opened."

func _launch_jukebox_map(map_path: String, cpu_style: String = "", cpu_tier: String = "") -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var local_uid: String = ProfileManager.get_user_id() if ProfileManager != null else "local"
	var local_name: String = ProfileManager.get_display_name() if ProfileManager != null else "You"
	var map_id: String = MAP_REGISTRY.map_id_from_path(map_path)
	var clean_cpu_style: String = cpu_style.strip_edges().to_lower()
	var clean_cpu_tier: String = cpu_tier.strip_edges().to_lower()
	if clean_cpu_style.is_empty():
		clean_cpu_style = "balancer"
	if clean_cpu_tier.is_empty():
		clean_cpu_tier = "medium"
	var clear_keys: Array[String] = [
		"open_map_picker_on_ready",
		"vs_mode",
		"vs_price_usd",
		"vs_free_roll",
		"vs_assigned_players",
		"vs_open_slots",
		"vs_required_players",
		"vs_sync_start",
		"vs_sync_join_sec",
		"vs_window_sec",
		"vs_window_started_unix",
		"vs_window_deadline_unix",
		"vs_stage_map_paths",
		"vs_stage_current_index",
		"vs_stage_round_results",
		"vs_handshake_session_id",
		"vs_handshake_role",
		"vs_handshake_invite_code",
		"vs_local_profile",
		"vs_remote_profile",
		"vs_cpu_style",
		"vs_cpu_tier",
		"ctf_flag_selection_mode",
		"ctf_player_select_pct",
		"ctf_randomize_flag_hive",
		"ctf_hidden_flag",
		"ctf_flag_move_count_max",
		"ctf_flag_move_reveals",
		"jukebox_board_enabled",
		"jukebox_map_path",
		"jukebox_map_id",
		"jukebox_board_period",
		"jukebox_local_owner_id",
		"jukebox_result_commit_signature",
		"jukebox_highlight_player_id",
		"jukebox_easy_bot"
	]
	for key_any in clear_keys:
		var key: String = str(key_any)
		if tree.has_meta(key):
			tree.remove_meta(key)
	tree.set_meta("start_game", true)
	tree.set_meta("vs_mode", "ASYNC_SINGLE_MAP_TIMED")
	tree.set_meta("vs_price_usd", 0)
	tree.set_meta("vs_free_roll", true)
	tree.set_meta("vs_sync_start", false)
	tree.set_meta("vs_stage_map_paths", [map_path])
	tree.set_meta("vs_stage_current_index", 0)
	tree.set_meta("vs_stage_round_results", [])
	tree.set_meta("vs_local_profile", {
		"uid": local_uid,
		"name": local_name
	})
	tree.set_meta("vs_cpu_style", clean_cpu_style)
	tree.set_meta("vs_cpu_tier", clean_cpu_tier)
	tree.set_meta("jukebox_board_enabled", true)
	tree.set_meta("jukebox_map_path", map_path)
	tree.set_meta("jukebox_map_id", map_id)
	tree.set_meta("jukebox_board_period", "WEEKLY")
	tree.set_meta("jukebox_local_owner_id", 1)
	if OpsState != null and OpsState.has_method("set_team_mode_override"):
		OpsState.call("set_team_mode_override", "")
	var err: Error = tree.change_scene_to_file(SHELL_SCENE_PATH)
	if err != OK:
		return false
	return true

func _async_contest_scope_key(scope: String) -> String:
	return AsyncContestConfigStoreScript.normalize_scope(scope)

func _async_contest_dash_applies_to_mode(mode_id: String) -> bool:
	var clean_mode: String = mode_id.strip_edges().to_upper()
	return clean_mode == "STAGE_RACE" or clean_mode == "TIMED_RACE" or clean_mode == "MISS_N_OUT"

func _merge_async_contest_dash_options(options: Dictionary, scope: String, map_count: int) -> Dictionary:
	var merged: Dictionary = options.duplicate(true)
	if _async_contest_config_store == null:
		return merged
	var launch_options: Dictionary = _async_contest_config_store.launch_options(_async_contest_scope_key(scope), map_count)
	for key in launch_options.keys():
		merged[key] = launch_options[key]
	return merged

func _options_with_async_contest_dash_config(mode_id: String, map_count: int, options: Dictionary) -> Dictionary:
	if not _async_contest_dash_applies_to_mode(mode_id):
		return options
	var scope: String = str(options.get("contest_scope", options.get("async_contest_scope", "WEEKLY")))
	return _merge_async_contest_dash_options(options, scope, map_count)

func _open_tournament_panel() -> void:
	if async_panel == null:
		return
	_close_top_level_windows(UI_SURFACE_ASYNC)
	async_panel.visible = true
	_show_tournament_browser()
	if status_label != null:
		status_label.text = "Tournament lobby opened."

func _show_tournament_browser() -> void:
	_ensure_tournament_browser_ui()
	if _tournament_browser_root == null:
		return
	if async_vbox != null:
		async_vbox.visible = true
	if async_weekly_panel != null:
		async_weekly_panel.visible = false
	if async_monthly_panel != null:
		async_monthly_panel.visible = false
	if async_yearly_panel != null:
		async_yearly_panel.visible = false
	if async_top_row != null:
		async_top_row.visible = false
	if async_bottom_row != null:
		async_bottom_row.visible = false
	if async_footer_label != null:
		async_footer_label.visible = false
	var title_label := get_node_or_null("AsyncPanel/AsyncVBox/AsyncTitle") as Label
	if title_label != null:
		title_label.text = "TOURNAMENTS"
	if async_subtitle_label != null:
		async_subtitle_label.text = "Browse scheduled Domination, CTF, and Hidden CTF events."
	if _tournament_browser_root != null:
		_tournament_browser_root.visible = true
	_refresh_tournament_browser()

func _ensure_tournament_browser_ui() -> void:
	if _tournament_browser_root != null and is_instance_valid(_tournament_browser_root):
		return
	var body := get_node_or_null("AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox") as VBoxContainer
	if body == null:
		return
	_tournament_browser_root = VBoxContainer.new()
	_tournament_browser_root.name = "TournamentBrowser"
	_tournament_browser_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tournament_browser_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tournament_browser_root.add_theme_constant_override("separation", 14)
	body.add_child(_tournament_browser_root)

	var tab_row := HBoxContainer.new()
	tab_row.name = "TournamentTabs"
	tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_theme_constant_override("separation", 12)
	_tournament_browser_root.add_child(tab_row)

	_tournament_free_tab = Button.new()
	_tournament_free_tab.name = "TournamentFreeTab"
	_tournament_free_tab.text = "FREE PLAY"
	_tournament_free_tab.toggle_mode = true
	_tournament_free_tab.custom_minimum_size = Vector2(0.0, 64.0)
	_tournament_free_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tournament_free_tab.pressed.connect(func() -> void:
		_set_tournament_track(TOURNAMENT_TRACK_FREE)
	)
	tab_row.add_child(_tournament_free_tab)

	_tournament_money_tab = Button.new()
	_tournament_money_tab.name = "TournamentMoneyTab"
	_tournament_money_tab.text = "$ ENTRIES"
	_tournament_money_tab.toggle_mode = true
	_tournament_money_tab.custom_minimum_size = Vector2(0.0, 64.0)
	_tournament_money_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tournament_money_tab.pressed.connect(func() -> void:
		_set_tournament_track(TOURNAMENT_TRACK_MONEY)
	)
	tab_row.add_child(_tournament_money_tab)

	var scroll := ScrollContainer.new()
	scroll.name = "TournamentScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tournament_browser_root.add_child(scroll)
	_tournament_list = VBoxContainer.new()
	_tournament_list.name = "TournamentList"
	_tournament_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tournament_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_tournament_list)

	var footer := Label.new()
	footer.name = "TournamentFooter"
	footer.text = "Rows auto-start when full or at their posted time."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88, 0.68))
	_apply_font(footer, _font_regular, 14)
	_tournament_browser_root.add_child(footer)
	_enable_touch_drag_scroll(scroll)

func _set_tournament_track(track: String) -> void:
	_tournament_track_mode = track if track == TOURNAMENT_TRACK_MONEY else TOURNAMENT_TRACK_FREE
	_refresh_tournament_browser()

func _refresh_tournament_browser() -> void:
	if _tournament_list == null:
		return
	if _tournament_free_tab != null:
		_tournament_free_tab.button_pressed = _tournament_track_mode == TOURNAMENT_TRACK_FREE
		_style_tournament_tab(_tournament_free_tab, _tournament_track_mode == TOURNAMENT_TRACK_FREE)
	if _tournament_money_tab != null:
		_tournament_money_tab.button_pressed = _tournament_track_mode == TOURNAMENT_TRACK_MONEY
		_style_tournament_tab(_tournament_money_tab, _tournament_track_mode == TOURNAMENT_TRACK_MONEY)
	for child in _tournament_list.get_children():
		child.queue_free()
	for tournament_any in _tournament_defs():
		var tournament: Dictionary = tournament_any as Dictionary
		if str(tournament.get("track", TOURNAMENT_TRACK_FREE)) != _tournament_track_mode:
			continue
		_tournament_list.add_child(_build_tournament_row(tournament))

func _tournament_defs() -> Array[Dictionary]:
	return [
		{
			"id": "free_domination_weekend",
			"track": TOURNAMENT_TRACK_FREE,
			"name": "Weekend Domination",
			"type": "DOMINATION",
			"shape": "1v1",
			"joined": 18,
			"capacity": 32,
			"start": "Full or 7:00 PM",
			"stakes": "Free entry",
			"rules": "Delta + No Man's Land pool | no buffs",
			"entry_usd": 0
		},
		{
			"id": "free_ctf_lunch",
			"track": TOURNAMENT_TRACK_FREE,
			"name": "CTF Lunch Bracket",
			"type": "CTF",
			"shape": "1v1",
			"joined": 11,
			"capacity": 24,
			"start": "Full or 12:30 PM",
			"stakes": "Free entry",
			"rules": "Shared public map pool | buffs capped 1",
			"entry_usd": 0
		},
		{
			"id": "free_hidden_flag_open",
			"track": TOURNAMENT_TRACK_FREE,
			"name": "Hidden Flag Open",
			"type": "HIDDEN CTF",
			"shape": "1v1",
			"joined": 6,
			"capacity": 16,
			"start": "Full or 8:30 PM",
			"stakes": "Free entry",
			"rules": "Even-hive maps only | hidden flag",
			"entry_usd": 0
		},
		{
			"id": "money_domination_five",
			"track": TOURNAMENT_TRACK_MONEY,
			"name": "Friday Domination $5",
			"type": "DOMINATION",
			"shape": "1v1",
			"joined": 21,
			"capacity": 32,
			"start": "Full or 8:00 PM",
			"stakes": "$5 entry | est. pool $120",
			"rules": "No buffs | top 4 paid",
			"entry_usd": 5
		},
		{
			"id": "money_ctf_ten",
			"track": TOURNAMENT_TRACK_MONEY,
			"name": "Prime CTF $10",
			"type": "CTF",
			"shape": "1v1",
			"joined": 9,
			"capacity": 16,
			"start": "Full or 9:00 PM",
			"stakes": "$10 entry | est. pool $128",
			"rules": "Direct flag mode | top 2 paid",
			"entry_usd": 10
		},
		{
			"id": "money_hidden_flag_three",
			"track": TOURNAMENT_TRACK_MONEY,
			"name": "Hidden Flag $3",
			"type": "HIDDEN CTF",
			"shape": "1v1",
			"joined": 12,
			"capacity": 24,
			"start": "Full or 10:00 PM",
			"stakes": "$3 entry | est. pool $54",
			"rules": "Even-hive maps only | top 3 paid",
			"entry_usd": 3
		}
	]

func _build_tournament_row(tournament: Dictionary) -> Panel:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0.0, 118.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_panel(row, Color(0.075, 0.082, 0.108, 0.94), Color(0.42, 0.43, 0.50, 0.68))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	row.add_child(margin)

	var line := HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 16)
	margin.add_child(line)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	line.add_child(info)

	var top := Label.new()
	top.text = "%s    %s    %d/%d players" % [
		str(tournament.get("name", "Tournament")),
		str(tournament.get("type", "MODE")),
		int(tournament.get("joined", 0)),
		int(tournament.get("capacity", 0))
	]
	top.clip_text = true
	_apply_font(top, _font_semibold, 19)
	top.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88, 1.0))
	info.add_child(top)

	var middle := Label.new()
	middle.text = "Starts %s | %s" % [str(tournament.get("start", "when full")), str(tournament.get("shape", "1v1"))]
	middle.clip_text = true
	_apply_font(middle, _font_regular, 16)
	middle.add_theme_color_override("font_color", Color(0.84, 0.87, 0.92, 0.86))
	info.add_child(middle)

	var bottom := Label.new()
	bottom.text = "%s | %s" % [str(tournament.get("stakes", "Free entry")), str(tournament.get("rules", ""))]
	bottom.clip_text = true
	_apply_font(bottom, _font_regular, 15)
	bottom.add_theme_color_override("font_color", Color(0.78, 0.80, 0.86, 0.74))
	info.add_child(bottom)

	var join_button := Button.new()
	var tournament_id := str(tournament.get("id", ""))
	var joined := bool(_joined_tournaments.get(tournament_id, false))
	var full := int(tournament.get("joined", 0)) >= int(tournament.get("capacity", 1))
	join_button.custom_minimum_size = Vector2(164.0, 84.0)
	join_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if joined:
		join_button.text = "ENTERED"
		join_button.disabled = true
	elif full:
		join_button.text = "FULL"
		join_button.disabled = true
	else:
		var entry_usd := int(tournament.get("entry_usd", 0))
		join_button.text = "JOIN $%d" % entry_usd
		if entry_usd <= 0:
			join_button.text = "JOIN"
		join_button.pressed.connect(func() -> void:
			_on_tournament_join_pressed(tournament)
		)
	_apply_font(join_button, _font_semibold, 20)
	_style_button(join_button, Color(0.18, 0.15, 0.08), Color(0.88, 0.68, 0.20), Color(1.0, 0.92, 0.58))
	line.add_child(join_button)
	return row

func _style_tournament_tab(button: Button, active: bool) -> void:
	if button == null:
		return
	_apply_font(button, _font_semibold, 20)
	if active:
		_style_button(button, Color(0.22, 0.18, 0.08), Color(0.90, 0.70, 0.22), Color(1.0, 0.92, 0.58))
	else:
		_style_button(button, Color(0.10, 0.11, 0.14), Color(0.42, 0.44, 0.52), Color(0.86, 0.88, 0.92))

func _on_tournament_join_pressed(tournament: Dictionary) -> void:
	var tournament_id := str(tournament.get("id", ""))
	if tournament_id.is_empty():
		return
	var entry_usd := int(tournament.get("entry_usd", 0))
	if entry_usd > 0:
		var charge := _charge_paid_entry_usd(entry_usd, "tournament_entry")
		if not bool(charge.get("ok", false)):
			return
	_joined_tournaments[tournament_id] = true
	var type_label := str(tournament.get("type", "tournament"))
	if status_label != null:
		status_label.text = "Joined %s. Waiting for tournament start." % type_label
	_refresh_tournament_browser()

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
	if _tournament_browser_root != null:
		_tournament_browser_root.visible = false
	if async_footer_label != null:
		async_footer_label.visible = true
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

func _resolve_stage_race_contest_launch_data(scope: String, requested_map_count: int = 5, paid: bool = false, denomination: int = 0) -> Dictionary:
	var clean_scope: String = scope.strip_edges().to_upper()
	if clean_scope.is_empty():
		clean_scope = "WEEKLY"
	var output: Dictionary = {
		"ok": false,
		"scope": clean_scope,
		"contest_id": "",
		"contest": null,
		"plan": {},
		"map_ids": PackedStringArray(),
		"map_count": maxi(1, requested_map_count),
		"window_sec": ASYNC_STAGE_AND_MISS_WINDOW_SEC,
		"error": "%s Stage Race contest unavailable." % clean_scope.capitalize()
	}
	var contest_state: Node = get_node_or_null("/root/ContestState")
	if contest_state == null or not contest_state.has_method("build_stage_race_plan"):
		return output
	var contest: Variant = _select_async_stage_contest_for_leaderboard(contest_state, clean_scope, paid, denomination)
	if contest == null:
		output["error"] = "No %s Stage Race contest is posted yet." % clean_scope.capitalize()
		return output
	var contest_id: String = str(contest.get("id")).strip_edges()
	if contest_id.is_empty():
		return output
	var map_count: int = maxi(1, requested_map_count)
	var plan: Dictionary = contest_state.call("build_stage_race_plan", contest_id, map_count) as Dictionary
	if not bool(plan.get("ok", false)):
		return output
	var map_ids: PackedStringArray = plan.get("map_ids", PackedStringArray()) as PackedStringArray
	if map_ids.is_empty():
		output["error"] = "%s Stage Race contest has no maps." % clean_scope.capitalize()
		return output
	output["ok"] = true
	output["contest_id"] = contest_id
	output["contest"] = contest
	output["plan"] = plan
	output["map_ids"] = map_ids
	output["map_count"] = maxi(1, int(plan.get("map_count", map_ids.size())))
	output["window_sec"] = _resolve_plan_time_window_sec(plan, ASYNC_STAGE_AND_MISS_WINDOW_SEC)
	output["error"] = ""
	return output

func _open_stage_race_contest_choice(scope: String, paid: bool, denomination: int) -> void:
	var clean_scope: String = scope.strip_edges().to_upper()
	if clean_scope.is_empty():
		clean_scope = "WEEKLY"
	var launch_data: Dictionary = _resolve_stage_race_contest_launch_data(clean_scope, 5, paid, denomination)
	if not bool(launch_data.get("ok", false)):
		status_label.text = str(launch_data.get("error", "%s Stage Race contest unavailable." % clean_scope.capitalize()))
		return
	var resolved_map_count: int = int(launch_data.get("map_count", 5))
	var title: String = "%s STAGE RACE" % clean_scope.capitalize().to_upper()
	var entry_text: String = "$%d ENTRY" % maxi(1, denomination) if paid else "FREE ROLL"
	var subtitle: String = "%s | %d MAPS" % [entry_text, resolved_map_count]
	var panel: Panel = _build_entry_overlay(title, subtitle, Vector2(720.0, 360.0))
	var body: VBoxContainer = _entry_overlay_body(panel)
	if body == null:
		return
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 14)
	body.add_child(button_row)

	var play_button: Button = Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(260.0, 72.0)
	if paid:
		play_button.pressed.connect(func():
			_close_entry_route_modal()
			_open_stage_race_tournament_lobby(clean_scope, paid, denomination)
		)
	else:
		play_button.pressed.connect(func():
			_close_entry_route_modal()
			_start_free_stage_race_contest(clean_scope, resolved_map_count)
		)
	button_row.add_child(play_button)

	var leaderboard_button: Button = Button.new()
	leaderboard_button.text = "LEADERBOARD"
	leaderboard_button.custom_minimum_size = Vector2(260.0, 72.0)
	leaderboard_button.pressed.connect(func():
		_close_entry_route_modal()
		_open_stage_race_contest_leaderboard(clean_scope, resolved_map_count, paid, denomination)
	)
	button_row.add_child(leaderboard_button)

	var close_button: Button = Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0.0, 52.0)
	close_button.pressed.connect(_close_entry_route_modal)
	body.add_child(close_button)
	_style_entry_overlay_buttons([play_button, leaderboard_button, close_button])
	_apply_font(play_button, _font_semibold, 16)
	_apply_font(leaderboard_button, _font_semibold, 16)
	_style_game_hub_cancel_button(close_button)
	_entry_route_modal = panel
	status_label.text = "%s Stage Race selected." % clean_scope.capitalize()

func _open_stage_race_contest_leaderboard(scope: String, requested_map_count: int = 5, paid: bool = false, denomination: int = 0) -> void:
	var launch_data: Dictionary = _resolve_stage_race_contest_launch_data(scope, requested_map_count, paid, denomination)
	if not bool(launch_data.get("ok", false)):
		status_label.text = str(launch_data.get("error", "Stage Race leaderboard unavailable."))
		return
	_open_async_stage_contest_leaderboard(int(launch_data.get("map_count", requested_map_count)), str(launch_data.get("scope", scope)), paid, denomination)
	status_label.text = "%s Stage Race leaderboard opened." % str(launch_data.get("scope", scope)).capitalize()

func _start_free_stage_race_contest(scope: String, requested_map_count: int = 5) -> void:
	if _block_for_active_hive_tournament("async matches"):
		return
	var launch_data: Dictionary = _resolve_stage_race_contest_launch_data(scope, requested_map_count, false, 0)
	if not bool(launch_data.get("ok", false)):
		status_label.text = str(launch_data.get("error", "Stage Race contest unavailable."))
		return
	var clean_scope: String = str(launch_data.get("scope", scope)).strip_edges().to_upper()
	var resolved_map_count: int = int(launch_data.get("map_count", requested_map_count))
	var map_ids: PackedStringArray = launch_data.get("map_ids", PackedStringArray()) as PackedStringArray
	var lobby_options: Dictionary = {
		"start_players": ASYNC_WINDOW_START_PLAYERS,
		"window_sec": int(launch_data.get("window_sec", ASYNC_STAGE_AND_MISS_WINDOW_SEC)),
		"contest_id": str(launch_data.get("contest_id", "")),
		"contest_scope": clean_scope,
		"map_ids": map_ids
	}
	status_label.text = "%s Stage Race contest starting..." % clean_scope.capitalize()
	if not _launch_async_vs_match_direct("STAGE_RACE", resolved_map_count, true, 0, lobby_options):
		_open_async_vs_lobby("STAGE_RACE", resolved_map_count, true, 0, lobby_options)

func _open_stage_race_tournament_lobby(scope: String, paid: bool = true, denomination: int = 0) -> void:
	var return_async_panel: bool = async_panel != null and async_panel.visible
	_close_top_level_windows(UI_SURFACE_TIME_PUZZLE)
	_time_puzzle_return_async_panel = return_async_panel
	if _time_puzzle_lobby == null:
		_time_puzzle_lobby = preload("res://scenes/ui/TimePuzzleLobby.tscn").instantiate()
		_time_puzzle_lobby.closed.connect(func():
			_time_puzzle_lobby.queue_free()
			_time_puzzle_lobby = null
			if async_panel != null and _time_puzzle_return_async_panel:
				async_panel.visible = true
				_time_puzzle_return_async_panel = false
		)
		_time_puzzle_lobby.free_stage_race_play_requested.connect(_on_time_puzzle_free_stage_race_play_requested)
		_time_puzzle_lobby.stage_race_leaderboard_requested.connect(_on_time_puzzle_stage_race_leaderboard_requested)
		add_child(_time_puzzle_lobby)
	_time_puzzle_lobby.configure_entry(not paid, denomination)
	_time_puzzle_lobby.set_scope(scope)
	_time_puzzle_lobby.visible = true
	if status_label != null:
		status_label.text = "%s Stage Race tournaments." % scope.capitalize()
	if async_panel != null:
		async_panel.visible = false

func _on_time_puzzle_free_stage_race_play_requested(scope: String, map_count: int) -> void:
	if _time_puzzle_lobby != null:
		_time_puzzle_lobby.visible = false
	_start_free_stage_race_contest(scope, map_count)

func _on_time_puzzle_stage_race_leaderboard_requested(scope: String, paid: bool, denomination: int, map_count: int) -> void:
	_open_stage_race_contest_leaderboard(scope, map_count, paid, denomination)

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
	if _block_for_active_hive_tournament("async matches"):
		return
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
	if free_play:
		var free_map_ids: PackedStringArray = _free_roll_random_map_ids("MISS_N_OUT", map_count_requested)
		if free_map_ids.is_empty():
			status_label.text = "No Free Roll maps available for Miss-N-Out."
			return
		var free_map_labels: Array[String] = []
		for free_map_id in free_map_ids:
			free_map_labels.append(MAP_REGISTRY.public_map_display_name_for_id(free_map_id))
		lobby_options["map_ids"] = free_map_ids
		status_label.text = "%s Miss-N-Out (%d maps, randomized): %s" % [track_label, free_map_ids.size(), ", ".join(free_map_labels)]
		_open_async_vs_lobby("MISS_N_OUT", free_map_ids.size(), free_play, entry_usd, lobby_options)
		return
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
		map_labels.append(MAP_REGISTRY.public_map_display_name_for_id(str(map_id_v)))
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

func _on_async_capture_flag_selected(free_play: bool) -> bool:
	if _block_for_active_hive_tournament("async matches"):
		return false
	var track_label: String = "Free Play" if free_play else "Ladder"
	var entry_usd: int = 0 if free_play else _current_async_paid_entry_usd()
	if not free_play:
		var charge: Dictionary = _charge_paid_entry_usd(entry_usd, "async_capture_flag")
		if not bool(charge.get("ok", false)):
			return false
	if not _launch_direct_capture_flag("CAPTURE_FLAG", free_play, entry_usd):
		return false
	status_label.text = "%s Capture the Flag starting..." % track_label
	return true

func _on_async_hidden_capture_flag_selected(free_play: bool) -> bool:
	if _block_for_active_hive_tournament("async matches"):
		return false
	var track_label: String = "Free Play" if free_play else "Ladder"
	var entry_usd: int = 0 if free_play else _current_async_paid_entry_usd()
	if not free_play:
		var charge: Dictionary = _charge_paid_entry_usd(entry_usd, "async_hidden_capture_flag")
		if not bool(charge.get("ok", false)):
			return false
	if not _launch_direct_capture_flag("HIDDEN_CAPTURE_FLAG", free_play, entry_usd):
		return false
	status_label.text = "%s Hidden Flag starting..." % track_label
	return true

func _hidden_capture_flag_lobby_options(force_async_window: bool) -> Dictionary:
	var options: Dictionary = {
		"ctf_flag_selection_mode": "player_select",
		"ctf_player_select_pct": 100,
		"ctf_flag_move_count_max": 1,
		"ctf_flag_move_reveals": true,
		"map_ids": HIDDEN_CTF_MAP_IDS
	}
	if force_async_window:
		options["start_players"] = ASYNC_WINDOW_START_PLAYERS
		options["window_sec"] = ASYNC_STAGE_AND_MISS_WINDOW_SEC
		options["force_async_window"] = true
	return options

func _launch_direct_capture_flag(mode_id: String, free_roll: bool, entry_usd: int) -> bool:
	var map_path: String = _resolve_direct_capture_flag_map_path(mode_id, free_roll)
	if map_path.is_empty():
		status_label.text = "No valid CTF map found."
		SFLog.warn("DIRECT_CTF_MAP_RESOLVE_FAILED", {
			"mode": mode_id,
			"candidates": HIDDEN_CTF_MAP_IDS if mode_id == "HIDDEN_CAPTURE_FLAG" else DIRECT_CTF_MAP_IDS
		})
		return false
	var tree: SceneTree = get_tree()
	if tree == null:
		status_label.text = "Could not start CTF."
		return false
	var local_uid: String = ProfileManager.get_user_id() if ProfileManager != null else "local"
	var local_name: String = ProfileManager.get_display_name() if ProfileManager != null else "You"
	if local_name.strip_edges().is_empty():
		local_name = "You"
	var hidden_mode: bool = mode_id == "HIDDEN_CAPTURE_FLAG"
	tree.set_meta("start_game", true)
	tree.set_meta("vs_mode", mode_id)
	tree.set_meta("vs_price_usd", maxi(0, entry_usd))
	tree.set_meta("vs_free_roll", free_roll)
	tree.set_meta("vs_assigned_players", [local_name, "CPU"])
	tree.set_meta("vs_open_slots", 0)
	tree.set_meta("vs_required_players", 2)
	tree.set_meta("vs_sync_start", true)
	tree.set_meta("vs_sync_join_sec", 0)
	tree.set_meta("vs_window_sec", 0)
	tree.set_meta("vs_window_started_unix", 0)
	tree.set_meta("vs_window_deadline_unix", 0)
	tree.set_meta("vs_stage_map_paths", [map_path])
	tree.set_meta("vs_stage_current_index", 0)
	tree.set_meta("vs_stage_round_results", [])
	tree.set_meta("vs_handshake_session_id", "")
	tree.set_meta("vs_handshake_role", "host")
	tree.set_meta("vs_handshake_invite_code", "")
	tree.set_meta("vs_local_profile", {
		"uid": local_uid,
		"display_name": local_name
	})
	tree.set_meta("vs_remote_profile", {
		"uid": "bot_ctf_direct",
		"display_name": "CPU",
		"is_cpu": true
	})
	tree.set_meta("ctf_flag_selection_mode", "player_select" if hidden_mode else "weighted")
	tree.set_meta("ctf_player_select_pct", 100 if hidden_mode else 35)
	tree.set_meta("ctf_randomize_flag_hive", true)
	tree.set_meta("ctf_hidden_flag", hidden_mode)
	tree.set_meta("ctf_flag_move_count_max", 1 if hidden_mode else 0)
	tree.set_meta("ctf_flag_move_reveals", true)
	if hidden_mode:
		tree.set_meta("hidden_ctf_allotment_pattern", "roll")
		tree.set_meta("hidden_ctf_allotment_seed", maxi(1, Time.get_ticks_msec()))
	if OpsState != null and OpsState.has_method("set_team_mode_override"):
		OpsState.call("set_team_mode_override", "ffa")
	SFLog.info("DIRECT_CTF_LAUNCH", {
		"mode": mode_id,
		"map_path": map_path,
		"free_roll": free_roll,
		"entry_usd": int(entry_usd)
	})
	_play_matchmaker_sfx()
	var err: Error = tree.change_scene_to_file(SHELL_SCENE_PATH)
	if err != OK:
		status_label.text = "CTF launch failed."
		SFLog.warn("DIRECT_CTF_LAUNCH_FAILED", {"mode": mode_id, "error_code": int(err), "map_path": map_path})
		return false
	status_label.text = "%s starting..." % ("Hidden CTF" if hidden_mode else "Capture the Flag")
	return true

func _resolve_direct_capture_flag_map_path(mode_id: String, free_roll: bool = false) -> String:
	if free_roll:
		var random_paths: Array[String] = _free_roll_random_map_paths(mode_id, 1)
		if not random_paths.is_empty():
			return random_paths[0]
	var map_ids: Array[String] = HIDDEN_CTF_MAP_IDS if mode_id == "HIDDEN_CAPTURE_FLAG" else DIRECT_CTF_MAP_IDS
	for map_id in map_ids:
		var map_path: String = MAP_LOADER._resolve_map_path(map_id)
		if map_path.is_empty():
			continue
		if not FileAccess.file_exists(map_path):
			continue
		if _free_roll_requires_hidden_ctf_split(mode_id) and not _map_supports_hidden_ctf_split(map_path):
			continue
		return map_path
	return ""

func _free_roll_random_map_ids(mode_id: String, map_count: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for path in _free_roll_random_map_paths(mode_id, map_count):
		var map_id: String = MAP_REGISTRY.map_id_from_path(path)
		if not map_id.is_empty():
			out.append(map_id)
	return out

func _free_roll_random_map_paths(mode_id: String, map_count: int) -> Array[String]:
	var requested_count: int = maxi(1, map_count)
	var pool: Array[String] = _free_roll_candidate_map_paths(mode_id)
	var picked: Array[String] = []
	if pool.is_empty():
		return picked
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while picked.size() < requested_count and not pool.is_empty():
		var idx: int = rng.randi_range(0, pool.size() - 1)
		picked.append(str(pool[idx]))
		pool.remove_at(idx)
	return picked

func _free_roll_candidate_map_paths(mode_id: String) -> Array[String]:
	var out: Array[String] = []
	for path_any in MAP_LOADER.list_maps():
		var path: String = str(path_any).strip_edges()
		if path.is_empty():
			continue
		if not _free_roll_map_path_supports_mode(path, mode_id):
			continue
		out.append(path)
	return out

func _free_roll_map_path_supports_mode(path: String, mode_id: String) -> bool:
	var loaded: Dictionary = MAP_LOADER.load_map(path)
	if not bool(loaded.get("ok", false)):
		return false
	var model: Dictionary = loaded.get("data", {}) as Dictionary
	var summary: Dictionary = MAP_MODE_RULES.map_supports_game_mode(model, mode_id)
	return bool(summary.get("ok", false))

func _free_roll_requires_hidden_ctf_split(mode_id: String) -> bool:
	return mode_id.strip_edges().to_upper() == "HIDDEN_CAPTURE_FLAG"

func _map_supports_hidden_ctf_split(path: String) -> bool:
	var loaded: Dictionary = MAP_LOADER.load_map(path)
	if not bool(loaded.get("ok", false)):
		return false
	var model: Dictionary = loaded.get("data", {}) as Dictionary
	var summary: Dictionary = MAP_MODE_RULES.hidden_capture_flag_split_summary(model)
	return bool(summary.get("ok", false))

func _on_async_stage_race_selected(map_count: int, free_play: bool) -> void:
	if _block_for_active_hive_tournament("async matches"):
		return
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
	if free_play:
		var free_map_ids: PackedStringArray = _free_roll_random_map_ids("STAGE_RACE", map_count)
		if free_map_ids.is_empty():
			status_label.text = "No Free Roll maps available for Stage Race."
			return
		var free_map_labels: Array[String] = []
		for free_map_id in free_map_ids:
			free_map_labels.append(MAP_REGISTRY.public_map_display_name_for_id(free_map_id))
		lobby_options["map_ids"] = free_map_ids
		status_label.text = "%s Stage Race (%d maps, randomized): %s" % [track_label, free_map_ids.size(), ", ".join(free_map_labels)]
		_open_async_vs_lobby("STAGE_RACE", free_map_ids.size(), free_play, entry_usd, lobby_options)
		return
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
		map_labels.append(MAP_REGISTRY.public_map_display_name_for_id(str(map_id_v)))
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
	if _block_for_active_hive_tournament("async matches"):
		return
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
	if free_play:
		var free_map_ids: PackedStringArray = _free_roll_random_map_ids("TIMED_RACE", map_count)
		if free_map_ids.is_empty():
			status_label.text = "No Free Roll maps available for Race."
			return
		var free_map_labels: Array[String] = []
		for free_map_id in free_map_ids:
			free_map_labels.append(MAP_REGISTRY.public_map_display_name_for_id(free_map_id))
		lobby_options["map_ids"] = free_map_ids
		status_label.text = "%s Timed Race (%d maps, randomized): %s" % [track_label, free_map_ids.size(), ", ".join(free_map_labels)]
		_open_async_vs_lobby("TIMED_RACE", free_map_ids.size(), free_play, entry_usd, lobby_options)
		return
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
		map_labels.append(MAP_REGISTRY.public_map_display_name_for_id(str(map_id_v)))
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
	var configured_options: Dictionary = _options_with_async_contest_dash_config(mode_id, map_count, options)
	var return_async_panel: bool = async_panel != null and async_panel.visible
	_play_matchmaker_sfx()
	_close_top_level_windows(UI_SURFACE_VS_LOBBY)
	_vs_lobby_return_async_panel = return_async_panel
	if _vs_lobby == null:
		_vs_lobby = preload("res://scenes/ui/VsLobby.tscn").instantiate()
		_vs_lobby.closed.connect(func():
			_vs_lobby.queue_free()
			_vs_lobby = null
			if async_panel != null and _vs_lobby_return_async_panel:
				async_panel.visible = true
			_vs_lobby_return_async_panel = false
		)
		add_child(_vs_lobby)
	if _vs_lobby.has_method("configure"):
		_vs_lobby.call("configure", mode_id, map_count, entry_usd, free_play, configured_options)
	_vs_lobby.visible = true
	if async_panel != null:
		async_panel.visible = false

func _launch_async_vs_match_direct(mode_id: String, map_count: int, free_play: bool, entry_usd: int, options: Dictionary = {}) -> bool:
	var configured_options: Dictionary = _options_with_async_contest_dash_config(mode_id, map_count, options)
	var scene: PackedScene = preload("res://scenes/ui/VsLobby.tscn")
	if scene == null:
		return false
	_play_matchmaker_sfx()
	_close_top_level_windows(UI_SURFACE_VS_LOBBY)
	var lobby: Control = scene.instantiate() as Control
	if lobby == null:
		return false
	lobby.visible = false
	lobby.closed.connect(func():
		if is_instance_valid(lobby) and not lobby.is_queued_for_deletion():
			lobby.queue_free()
	)
	add_child(lobby)
	if not lobby.has_method("configure") or not lobby.has_method("_join_async_contest") or not lobby.has_method("_start_match"):
		lobby.queue_free()
		return false
	lobby.call("configure", mode_id, map_count, entry_usd, free_play, configured_options)
	lobby.call("_join_async_contest", false)
	lobby.call("_start_match", true)
	var tree: SceneTree = get_tree()
	if tree != null and not tree.has_meta("start_game"):
		var hidden_status: Label = lobby.get_node_or_null("Panel/VBox/Status") as Label
		if hidden_status != null and not hidden_status.text.strip_edges().is_empty():
			status_label.text = hidden_status.text
		lobby.queue_free()
		return false
	return true

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
	_jukebox_direct_mode = false
	_replay_direct_mode = false
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
