extends Control

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
@onready var buffs_library_buttons: Array = [
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem1,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem2,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem3,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem4,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem5,
	$DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffsLibraryList/BuffItem6
]
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

const ASYNC_BUYINS := [1, 5, 10, 20, 50]
const ASYNC_MAPS := ["Map A", "Map B", "Map C", "Map D", "Map E"]
const ASYNC_CONFIRM_WINDOW_MS := 900

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
	call_deferred("_init_dash_state")
	_apply_player_profile(_player_profile)
	status_label.text = "Ready"

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
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncResultsPanel/AsyncResultsVBox/AsyncResultsAction.pressed.connect(func(): _stub_action("Async Ladder"))
	$AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/AsyncBottomRow/AsyncRulesPanel/AsyncRulesVBox/AsyncRulesAction.pressed.connect(func(): _stub_action("Async Free Play"))
	for idx in range(ASYNC_BUYINS.size()):
		var amount: int = ASYNC_BUYINS[idx]
		async_weekly_buyin_buttons[idx].pressed.connect(func(): _set_async_buyin("weekly", amount))
		async_monthly_buyin_buttons[idx].pressed.connect(func(): _set_async_buyin("monthly", amount))
		async_yearly_buyin_buttons[idx].pressed.connect(func(): _set_async_buyin("yearly", amount))
	var ladder_labels: PackedStringArray = PackedStringArray([
		"Ladder: Miss n Outs ($1/$5/$10/$20)",
		"Ladder: 3 Map Race",
		"Ladder: 5 Map Race",
		"Ladder: 3 Map Stage Race",
		"Ladder: 5 Map Stage Race"
	])
	var ladder_count: int = int(min(async_ladder_buttons.size(), ladder_labels.size()))
	for i in range(ladder_count):
		var label: String = ladder_labels[i]
		async_ladder_buttons[i].pressed.connect(func(): _stub_action(label))
	var free_labels: PackedStringArray = PackedStringArray([
		"Free Play: Miss n Outs",
		"Free Play: 3 Map Race",
		"Free Play: 5 Map Race",
		"Free Play: 3 Map Stage Race",
		"Free Play: 5 Map Stage Race"
	])
	var free_count: int = int(min(async_free_buttons.size(), free_labels.size()))
	for i in range(free_count):
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

func _hide_async_subpanels() -> void:
	for panel in [async_weekly_panel, async_monthly_panel, async_yearly_panel]:
		if panel != null:
			panel.visible = false

func _open_async_weekly() -> void:
	_open_time_puzzle_lobby("WEEKLY")

func _open_async_monthly() -> void:
	_open_time_puzzle_lobby("MONTHLY")

func _open_async_yearly() -> void:
	_open_time_puzzle_lobby("YEARLY")

func _open_time_puzzle_lobby(scope: String) -> void:
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
	_reset_async_confirm(mode)
	_sync_async_buyin_buttons(mode)
	_update_async_rules(mode)

func _sync_async_buyin_buttons(mode: String) -> void:
	var buttons := _get_async_buyin_buttons(mode)
	var selected := int(_async_buyins.get(mode, ASYNC_BUYINS[0]))
	for i in range(ASYNC_BUYINS.size()):
		var amount: int = ASYNC_BUYINS[i]
		var prefix := "* " if amount == selected else ""
		buttons[i].text = "%s$%d Entry" % [prefix, amount]

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
