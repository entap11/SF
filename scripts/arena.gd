@tool
# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
extends Node2D

const ARENA_MARKER := "ARENA_MARKER_2026-01-14_A"

const SFLog := preload("res://scripts/util/sf_log.gd")
const MapSchema := preload("res://scripts/maps/map_schema.gd")
const MapApplier := preload("res://scripts/maps/map_applier.gd")
const MapRegistry := preload("res://scripts/maps/map_registry.gd")
const WallRenderer := preload("res://scripts/renderers/wall_renderer.gd")
const GridSpec := preload("res://scripts/maps/grid_spec.gd")
const SimTuning := preload("res://scripts/sim/sim_tuning.gd")
const HiveGeometry := preload("res://scripts/sim/hive_geometry.gd")
const SimEvents := preload("res://scripts/sim/sim_events.gd")
const VfxManager := preload("res://scripts/vfx/vfx_manager.gd")
const MatchRecordsStore := preload("res://scripts/state/match_records_store.gd")
const MatchTelemetryModelScript := preload("res://scripts/state/match_telemetry_model.gd")
const MatchTelemetryCollectorScript := preload("res://scripts/state/match_telemetry_collector.gd")
const MatchAnalyzerScript := preload("res://scripts/state/match_analyzer.gd")
const PlayerTelemetryProfileStoreScript := preload("res://scripts/state/player_telemetry_profile_store.gd")
const JukeboxLeaderboardStoreScript := preload("res://scripts/state/jukebox_leaderboard_store.gd")
const CrucibleRulesetPolicyScript := preload("res://scripts/state/crucible_ruleset_policy.gd")
const ProgressiveConfigScript := preload("res://scripts/state/progressive_config.gd")
const ProgressiveRunStoreScript := preload("res://scripts/state/progressive_run_store.gd")
const ProgressiveStarDecayHudScript := preload("res://scripts/ui/progressive_star_decay_hud.gd")
const AsyncRecordEligibilityPolicy := preload("res://scripts/state/async_record_eligibility_policy.gd")
const BuffTargetResolverScript := preload("res://scripts/state/buff_target_resolver.gd")
const BuffActivationTransactionScript := preload("res://scripts/state/buff_activation_transaction.gd")
const TeamVisuals = preload("res://scripts/renderers/team_visuals.gd")
const ArenaControlsHintController := preload("res://scripts/arena_helpers/controls_hint_controller.gd")
const ArenaTutorialControlsController := preload("res://scripts/arena_helpers/tutorial_controls_controller.gd")
const ArenaTutorialSection1Controller := preload("res://scripts/arena_helpers/tutorial_section1_controller.gd")
const ArenaTutorialSection2Controller := preload("res://scripts/arena_helpers/tutorial_section2_controller.gd")
const ArenaTutorialSection3Controller := preload("res://scripts/arena_helpers/tutorial_section3_controller.gd")
const ArenaWorldViewportCache := preload("res://scripts/arena_helpers/world_viewport_cache.gd")
const ArenaStageRuntimeFlow := preload("res://scripts/arena_helpers/stage_runtime_flow.gd")
const ArenaPrematchTeamUiFormatter := preload("res://scripts/arena_helpers/prematch_team_ui_formatter.gd")
const ArenaInputBridgeUtils := preload("res://scripts/arena_helpers/input_bridge_utils.gd")
const ArenaFloorInfluenceSystem := preload("res://scripts/fx/arena_floor_influence_system.gd")
const ArenaPolishLayerScript: Script = preload("res://scripts/renderers/arena_polish_layer.gd")
const PvpDebugOverlayScript: Script = preload("res://scripts/ui/pvp_debug_overlay.gd")
const AdSurfaceScript: Script = preload("res://scripts/ui/ad_surface.gd")
const FORCE_DISABLE_FLOOR_INFLUENCE: bool = true

const GRID_W := 18
const GRID_H := 28
const CELL_SIZE := 64
const GRID_DEBUG := false
const RENDER_DEBUG := false
const LANE_ESTABLISH_MS := 2400.0
const UNIT_TRAVEL_MS := 4800.0
const ENABLE_DYNAMIC_LANE_FRONTS := false
const STATIC_LANE_FRONT_T := 0.5
const SPAWN_BASE_MS := SimTuning.BASE_SPAWN_MS
const SPAWN_PER_POWER_MS := SimTuning.PER_POWER_MS
const SPAWN_MIN_MS := SimTuning.MIN_SPAWN_MS
const FIRST_UNIT_OFFSET_MS := 2.0
const SPIKE_PX := 48.0
const LANE_EDGE_T := 0.18
const DEBUG_COLLISION_ONLY := true
const DASH_GAP_PX := 6.0
const BASE_MS := SimTuning.BASE_SPAWN_MS
const PER_POWER_MS := SimTuning.PER_POWER_MS
const START_POWER := 10
const IDLE_GROWTH_MS := 1500.0
const CAPTURE_SHOCK_MS := 3000.0
const SWARM_SHOCK_MS := 3000.0
const DRAG_DEADZONE_PX := 8.0
const MAX_OUT_LANES := 2
const DOT_RADIUS := 3.0
const HIVE_DIAMETER_PX := HiveGeometry.BASE_DIAMETER_PX
const HIVE_RADIUS_PX := HIVE_DIAMETER_PX * 0.5
const HIVE_PICK_PADDING_PX := 0.0
const HIVE_HIT_RADIUS_PX := HIVE_RADIUS_PX + HIVE_PICK_PADDING_PX
const LANE_HIT_DIST_PX := 24.0
const LANE_PICK_DIST_PX := 12.0
const TICK_DT := 0.1
const TICK_MS := 100.0
const TICK_DEBUG := false
const MAX_FRAME_DT := 0.25
const MAX_STEPS_PER_FRAME := 8
const MAX_ACCUM_DT := 1.0
const MAX_SPAWNS_PER_TICK := 5
const ENABLE_MAX_SPAWNS_PER_TICK := false
const ENABLE_LANE_ESTABLISH_SPAWN_GATE := false
const ENABLE_SPAWN_SOURCE_FILTER := false
const ENABLE_HIVE_SPAWN_SHOCK_BLOCK := false
const ENABLE_PASS_THROUGH_POWER_GATE := true
const ENABLE_PASS_THROUGH_SHOCK_GATE := false
const ENABLE_OUTGOING_LANE_BUDGET := true
const DEBRIS_LIFE := 4.0
const DEBRIS_DRIFT := 30.0
const DEBRIS_DAMP := 0.90
const DEBRIS_MAX_PER_LANE := 8
const DEBRIS_GLOBAL_CAP := 800
const DEV_STATE_CHECKS := true
const PRESSURE_DECAY_PER_SEC := 1.0
const LOS_DEBUG := false
const TIE_WINDOW_US := 0
const TIE_BUCKET_US := 100
const TIE_CACHE_EXPIRE_US := 2_000_000
const TIE_SFX_COOLDOWN_US := 500_000
const COIN_SFX_SEC := 0.08
const COIN_SFX_FREQ := 880.0
const CONTEST_WINDOW_US := 2_000_000
const CONTEST_LOG_INTERVAL_US := 1_000_000
const SWARM_MERGE_WINDOW_US := 200_000
const BARRACKS_MIN_REQ := 3
const BARRACKS_MAX_REQ := 6
const STRUCTURE_CANDIDATE_MAX := 12
const OVERTIME_START_MS := 60000.0
const POST_MATCH_SETTLE_SEC := 3.0
const POST_MATCH_EXTRAP_SEC := 3.0
const BUFF_MIN_MULT := 0.1
const BUFF_LANE_SLOW_PCT_DEFAULT := 0.25
const HITCH_MS_THRESHOLD: float = 50.0
const HITCH_COOLDOWN_MS: int = 250
const DBG_HITCH: bool = false
const HITCH_MS: float = 25.0
const SHELL_HUD_LAYER_PATH: String = "/root/Shell/HUDCanvasLayer"
const SHELL_HUD_ROOT_PATH: String = SHELL_HUD_LAYER_PATH + "/HUDRoot"
const SHELL_TOP_BUFFER_PATH: String = SHELL_HUD_LAYER_PATH + "/HUDRoot/BufferBackdropLayer/BufferRoot/TopBufferBackground"
const SHELL_BOTTOM_BUFFER_PATH: String = SHELL_HUD_LAYER_PATH + "/HUDRoot/BufferBackdropLayer/BufferRoot/BottomBufferBackground"
const SHELL_PLAYER_BUFF_STRIP_PATH: String = SHELL_BOTTOM_BUFFER_PATH + "/BuffSlotsStrip"
const SHELL_OPPONENT_BUFF_STRIP_PATH: String = SHELL_BOTTOM_BUFFER_PATH + "/OpponentBuffStrip"
const SHELL_OPPONENT_BUFF_STRIP_B_PATH: String = SHELL_BOTTOM_BUFFER_PATH + "/OpponentBuffStripB"
const SHELL_ALLY_BUFF_STRIP_PATH: String = SHELL_BOTTOM_BUFFER_PATH + "/AllyBuffStrip"
const SHELL_SIDE_UI_INSET_PX: float = 48.0
const SHELL_BOTTOM_UI_GAP_PX: float = 4.0
const SHELL_CAMFIT_BIAS_Y_PX: float = 30.0
const SHELL_POWER_BAR_PATH: String = SHELL_TOP_BUFFER_PATH + "/PowerBarAnchor/PowerBar"
const SHELL_OUTCOME_OVERLAY_PATH: String = SHELL_HUD_ROOT_PATH + "/OutcomeOverlay"
const SHELL_WIN_OVERLAY_PATH: String = SHELL_HUD_ROOT_PATH + "/WinOverlay"
const SHELL_SCENE_PATH: String = "res://scenes/Shell.tscn"
const CTF_MOVE_BUTTON_NAME: StringName = &"CaptureFlagMoveButton"
const CTF_MOVE_BUTTON_FONT_PATH: String = "res://assets/fonts/free_roll_display_v2_font.tres"
const CTF_MOVE_BUTTON_FALLBACK_FONT_PATH: String = "res://assets/fonts/brand/Iceland/Iceland-Regular.ttf"
const VS_MODE_STAGE_RACE: String = "STAGE_RACE"
const VS_MODE_PROGRESSIVE: String = "PROGRESSIVE"
const VS_MODE_CAPTURE_FLAG: String = "CAPTURE_FLAG"
const VS_MODE_HIDDEN_CAPTURE_FLAG: String = "HIDDEN_CAPTURE_FLAG"
const VS_MODE_ASYNC_SINGLE_MAP_TIMED: String = "ASYNC_SINGLE_MAP_TIMED"
const CTF_PLAYER_SELECT_PCT_DEFAULT: int = 35
const CTF_SELECTION_GRACE_MS: int = 5000
const TREE_META_VS_MODE: String = "vs_mode"
const TREE_META_VS_STAGE_MAP_PATHS: String = "vs_stage_map_paths"
const TREE_META_VS_STAGE_CURRENT_INDEX: String = "vs_stage_current_index"
const TREE_META_CONTEST_RESULT_SIGNATURE: String = "contest_result_commit_signature"
const TREE_META_VS_STAGE_RUN_ID: String = "vs_stage_run_id"
const TREE_META_ASYNC_BUFF_CONTEST_STATE: String = "async_buff_contest_state"
const TREE_META_BUFF_ACTIVATION_RUNTIME_STATE: String = "buff_activation_runtime_state"
const TREE_META_PENDING_STAGE_LEADERBOARD: String = "pending_stage_leaderboard_open"
const TREE_META_PENDING_STAGE_LEADERBOARD_CONTEXT: String = "pending_stage_leaderboard_context"
const TREE_META_VS_WINDOW_DEADLINE_UNIX: String = "vs_window_deadline_unix"
const TREE_META_CONTEST_ID: String = "contest_id"
const TREE_META_HIVE_TOURNAMENT_DEADLINE_UNIX: String = "hive_tournament_deadline_unix"
const MAP_RECORD_MODE_ID: String = "ASYNC_SINGLE_MAP_TIMED"
const JUKEBOX_META_ENABLED: String = "jukebox_board_enabled"
const JUKEBOX_META_MAP_PATH: String = "jukebox_map_path"
const JUKEBOX_META_MAP_ID: String = "jukebox_map_id"
const JUKEBOX_META_PERIOD: String = "jukebox_board_period"
const JUKEBOX_META_LOCAL_OWNER_ID: String = "jukebox_local_owner_id"
const JUKEBOX_META_RESULT_SIGNATURE: String = "jukebox_result_commit_signature"
const JUKEBOX_META_EASY_BOT: String = "jukebox_easy_bot"
const JUKEBOX_META_HIGHLIGHT_PLAYER_ID: String = "jukebox_highlight_player_id"
const TREE_META_REOPEN_JUKEBOX_ON_READY: String = "reopen_jukebox_on_ready"
const TREE_META_REOPEN_JUKEBOX_STATE: String = "reopen_jukebox_state"
const TREE_META_TUTORIAL_ACTIVE: String = "tutorial_launch_active"
const TREE_META_TUTORIAL_SECTION: String = "tutorial_launch_section"
const TUTORIAL_CONTROLS_ID: String = "controls_v1"
const TUTORIAL_SECTION1_ID: String = "section1"
const TUTORIAL_SECTION2_ID: String = "section2"
const TUTORIAL_SECTION3_ID: String = "section3"
const TREE_META_VS_CPU_STYLE: String = "vs_cpu_style"
const TREE_META_VS_CPU_TIER: String = "vs_cpu_tier"
const TREE_META_VS_STAGE_ROUND_RESULTS: String = "vs_stage_round_results"
const COUNTDOWN_DEBUG_SCRIPT: Script = preload("res://scripts/ui/prematch_countdown_view.gd")
const TOUCH_MOUSE_SUPPRESS_MS: int = 120
const PREMATCH_RECORDS_WIDTH_PX: float = 520.0
const PREMATCH_RECORDS_HEIGHT_PX: float = 168.0
const PREMATCH_RECORDS_TOP_GAP_PX: float = 24.0
const PREMATCH_RECORDS_FONT_SIZE: int = 17
const ASYNC_PREMATCH_CARD_WIDTH_PX: float = 640.0
const ASYNC_PREMATCH_CARD_HEIGHT_PX: float = 208.0
const PREMATCH_AD_SIZE: Vector2 = Vector2(468.0, 60.0)
const IN_GAME_AD_SIZE: Vector2 = Vector2(320.0, 50.0)
const IN_GAME_AD_TOP_MARGIN_PX: float = 8.0
const IN_GAME_AD_MIN_WIDTH_PX: float = 280.0
const IN_GAME_AD_HUD_Z_INDEX: int = 3200
const POWER_BAR_ARENA_TOP_GAP_PX: float = -8.0
const PREMATCH_UI_CROSSFADE_MS: int = 350
const PREMATCH_ORIENTATION_DURATION_MS: int = 10000
const PREMATCH_IDENTITY_CARD_SHOW_MS: int = 5000
const PREMATCH_IDENTITY_CARD_FADE_SEC: float = 0.25
const PREMATCH_HIVE_FOCUS_START_MS: int = 5250
const PREMATCH_HIVE_PULSE_SEC: float = 0.42
const PREMATCH_COUNTDOWN_RETURN_MS: int = 3000
const PREMATCH_HIVE_FOCUS_ZOOM_MULT: float = 1.45
const PREMATCH_TEAM_BUFFER_ALPHA: float = 0.22
const MM_BACKGROUND_ART_TEXTURE: Texture2D = preload("res://assets/sprites/sf_skin_v1/mm_back_art.png")
const MM_BACKGROUND_Y_SHIFT: float = 36.0
const MM_BACKGROUND_X_SCALE: float = 0.88
const MM_BACKGROUND_EXTRA_SIDE_PX: float = 90.0
const MM_BACKGROUND_STRETCH_MODE: int = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
const MAP_MM_BACKGROUND_NODE_NAME: StringName = &"MMBackgroundArt"
const PREMATCH_COUNTDOWN_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/game_prematch_countdown.ogg"
const TOWER_SHOT_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/game_tower_shot.ogg"
const SWARM_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/game_swarm.ogg"
const LOSE_HIVE_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/game_lose_hive.ogg"
const WIN_HIVE_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/win_hive.ogg"
const WIN_HIVE_SOUND_START_SEC: float = 0.246
const WIN_HIVE_SOUND_END_SEC: float = 0.925
const HIVE_SWITCH_SFX_LIMIT_COUNT: int = 3
const HIVE_SWITCH_SFX_LIMIT_WINDOW_MS: int = 7000
const WIN_SONG_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/win_song.mp3"
const LOSE_SONG_PATHS: Array[String] = [
	"res://assets/sprites/sf_skin_v1/sf_sounds/lose_song.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/lose_song2.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/lose_song3.ogg"
]
const POST_MATCH_SONG_FADE_OUT_SEC: float = 4.0
const POST_MATCH_AUDIO_FADE_OUT_DB: float = -60.0
const LIFECYCLE_CONTEST_EXPIRED_REASON: String = "contest_expired"

var state: GameState
var sel: SelectionState
var api: ArenaAPI
var input_system: InputSystem
var debug_system: DebugSystem
var audio_system: AudioSystem
var _prematch_countdown_sfx_player: AudioStreamPlayer = null
var _tower_shot_sfx_counts: Dictionary = {}
var _tower_shot_sfx_stream: AudioStream = null
var _swarm_sfx_stream: AudioStream = null
var _swarm_sfx_players_by_id: Dictionary = {}
var _lose_hive_sfx_stream: AudioStream = null
var _win_hive_sfx_stream: AudioStream = null
var _hive_switch_sfx_played_ms: Array[int] = []
var _post_match_song_player: AudioStreamPlayer = null
var _post_match_song_fade_tween: Tween = null
var _post_match_loss_song_index: int = 0
var lane_system: LaneSystem
var unit_system: UnitSystem = null
var tower_system: TowerSystem = null
var barracks_system: BarracksSystem = null
var tower_renderer: TowerRenderer = null
var wall_renderer: WallRenderer = null
var swarm_system: SwarmSystem = null
var sim_runner: SimRunner
var sim_events: SimEvents = null
var vfx_manager: VfxManager = null
var events: Array[Dictionary] = []
var grid_w: int = GRID_W
var grid_h: int = GRID_H
var grid_spec: GridSpec = null
var _playfield_outline: PlayfieldOutline = null
var render_version: int = 0
var _render_dirty: bool = true
var _render_model: Dictionary = {}
var model: Dictionary = {}
var _tick_render_dirty := false
var _drag_from_id: String = ""
var _drag_from_wp: Vector2 = Vector2.ZERO
var _drag_active: bool = false
var active_orders_by_attacker: Dictionary = {}
var _last_tower_export_log_ms: int = 0
var _last_barracks_export_log_ms: int = 0
var _last_render_hive_nodes_sig: int = -1
var _last_render_hives_version: int = -1
@onready var map_root: Node2D = $MapRoot
@onready var map_hex_background: Control = get_node_or_null("MapHexBackgroundLayer/HexSeamBackground") as Control
@onready var floor_renderer: FloorRenderer = $MapRoot/FloorRenderer
@onready var arena_polish_layer: Node2D = get_node_or_null("MapRoot/ArenaPolishLayer") as Node2D
@onready var lane_renderer = $MapRoot/LaneRenderer
@onready var tower_renderer_node = $MapRoot/TowerRenderer
@onready var hive_renderer: HiveRenderer = $MapRoot/HiveRenderer
@onready var buff_hive_targeting_controller: Node2D = $MapRoot/BuffHiveTargetPresentation
@onready var buff_lane_global_targeting_controller: Node2D = $MapRoot/BuffLaneGlobalTargetPresentation
@onready var unit_renderer: Node2D = _resolve_unit_renderer()
@onready var control_bar: ControlBar = get_node_or_null("../UI/ControlBar") as ControlBar
@onready var timer_label: Label = get_node_or_null("../UI/TimerLabel") as Label
@onready var top_buffer_background: TextureRect = _resolve_top_buffer_background()
@onready var power_bar: PowerBar = _resolve_power_bar_node()
@onready var buffs_label: Label = get_node_or_null("../UI/BuffsLabel") as Label
@onready var outcome_overlay: OutcomeOverlay = get_node_or_null("../UI/OutcomeOverlay") as OutcomeOverlay
@onready var win_overlay: WinOverlay = get_node_or_null("../UI/WinOverlay") as WinOverlay
@export var selection_hud_path: NodePath = NodePath("../UI/SelectionHud")
@onready var selection_hud: SelectionHud = get_node_or_null(selection_hud_path) as SelectionHud
@onready var tie_toast: Label = get_node_or_null("../UI/TieToast") as Label
@onready var coin_player: AudioStreamPlayer = $CoinFlipPlayer
@onready var camera: Camera2D = $Camera2D
const FIT_DEBUG := true
const FIT_CONTAIN := 0
const FIT_WIDTH := 1
const FIT_HEIGHT := 2
const PLAYFIELD_OUTLINE_Z_INDEX: int = 4095
const TRACE_ARENA_PRINTS: bool = false
const CAMERA_FIT_APPLY_DEBUG: bool = true
const SAFE_PAD_PX: float = 20.0
const SAFE_HIVE_PAD_PX: float = 40.0
const DBG_TREE_DUMP: bool = false
const WIN_OVERLAY_MS := 2500
const TIMER_REVEAL_MS := 59000
var _autostart_shadow := false
var _sim_running_shadow := false
var _win_overlay_until_ms: int = 0
var _win_overlay_match_end_ms: int = 0
var _inputs_locked_from_state: bool = false
var _timer_layer: CanvasLayer = null
var _timer_root: Control = null
var _timer_last_seconds: int = -1
var _timer_ui_logged: bool = false
var _timer_debug_mode: bool = true
var _timer_branch_logged: bool = false
var _timer_label_bind_logged: bool = false
var _timer_ready_logged: bool = false
var _progressive_counter_root: Control = null
var _progressive_counter_label: Label = null
var _progressive_star_decay_hud: Control = null
var _cam_probe_accum: float = 0.0
var _world_viewport_cache: ArenaWorldViewportCache = ArenaWorldViewportCache.new()
var _stage_runtime_flow: ArenaStageRuntimeFlow = ArenaStageRuntimeFlow.new()
var _jukebox_leaderboard_store: RefCounted = JukeboxLeaderboardStoreScript.new()
var _progressive_run_store: RefCounted = ProgressiveRunStoreScript.new()
var _prematch_team_ui_formatter: ArenaPrematchTeamUiFormatter = ArenaPrematchTeamUiFormatter.new()
var _input_bridge_utils: ArenaInputBridgeUtils = ArenaInputBridgeUtils.new()
var _camera_fit_viewport_override_px: Vector2 = Vector2.ZERO
var _prematch_overlay: Control = null
var _prematch_countdown_label: Label = null
var _prematch_records_panel: Control = null
var _prematch_record_p1: Label = null
var _prematch_record_p2: Label = null
var _prematch_record_p3: Label = null
var _prematch_record_p4: Label = null
var _prematch_record_h2h: Label = null
var _prematch_record_teams: Label = null
var _prematch_record_team_arrows: Label = null
var _prematch_ctf_panel: Panel = null
var _prematch_ctf_title: Label = null
var _prematch_ctf_body: Label = null
var _prematch_ad_surface: Control = null
var _in_game_ad_surface: Control = null
var _ctf_move_button: Button = null
var _controls_hint_controller: ArenaControlsHintController = ArenaControlsHintController.new()
var _tutorial_controls_controller: ArenaTutorialControlsController = ArenaTutorialControlsController.new()
var _tutorial_section1_controller: ArenaTutorialSection1Controller = ArenaTutorialSection1Controller.new()
var _tutorial_section2_controller: ArenaTutorialSection2Controller = ArenaTutorialSection2Controller.new()
var _tutorial_section3_controller: ArenaTutorialSection3Controller = ArenaTutorialSection3Controller.new()
var _prematch_remaining_ms_f: float = 0.0
var _prematch_last_sec: int = -1
var _prematch_records_faded: bool = false
var _prematch_countdown_faded: bool = false
var _power_bar_reveal_started: bool = false
var _prematch_final_fit_requested: bool = false
var _prematch_identity_card: Control = null
var _prematch_identity_card_faded: bool = false
var _prematch_hive_focus_started: bool = false
var _prematch_countdown_return_started: bool = false
var _prematch_camera_tween: Tween = null
var _prematch_pulse_root: Node2D = null
var _prematch_gameplay_camera_position: Vector2 = Vector2.ZERO
var _prematch_gameplay_camera_zoom: Vector2 = Vector2.ONE
var _prematch_ui_bind_logged: bool = false
var _prematch_ui_state_logged: bool = false
var _postmatch_ui_missing_logged: bool = false
var _match_started: bool = false
var _ctf_click_consumed: bool = false
var _ctf_move_armed: bool = false
var _match_records: MatchRecordsStore = MatchRecordsStore.new()
var _match_record_committed: bool = false
var _legacy_tick_fenced_logged: bool = false
var _map_mm_background_art: TextureRect = null
@export var autostart: bool = false:
	set(value):
		_set_autostart(value)
	get:
		return _get_autostart()
@export var buffs_enabled := true
@export var debug_cam_probe: bool = true
@export var cam_fit_margin: float = 1.0 # < 1.0 zooms in, > 1.0 zooms out
@export var cam_fit_pad_px: float = 0.0 # additional world padding in pixels
@export var use_node_bounds_camfit: bool = false
@export var cam_fit_nodes_mode: String = "cover" # "cover" fills width first, "contain" shows all
@export var cam_fit_node_pad_px: float = 48.0
@export var cam_fit_reserved_top_px: float = 140.0
@export var cam_fit_reserved_bottom_px: float = 160.0
@export var cam_fit_height_world_pad_px: float = 0.0 # extra world padding when FIT_HEIGHT is active
@export var cam_fit_height_y_scale: float = 0.95 # lower than 1.0 shows a bit more vertical world (shorter board on screen)
@export var cam_fit_bias_y_px: float = -24.0 # positive shifts board down on screen in FIT_HEIGHT
@export var cam_fit_bias_x_px: float = 0.0 # positive = push board right, negative = push left
@export var cam_fit_bias_x_px_wide_map: float = 0.0 # default X-bias for wide maps
@export var cam_fit_wide_map_min_grid_w: int = 12
@export var cam_fit_mode: int = FIT_HEIGHT # 0=contain(min), 1=fit_width, 2=fit_height
@export var cam_fit_lock_map_edges_to_container: bool = true
@export var floor_side_visual_projection_px: float = 96.0 # visual-only side floor/camera padding; does not expand active grid
@export var grid_coord_render_offset: float = 0.0 # 0.0 = authored coords map directly to world; 0.5 = cell-center indexing
@export var overtime_start_ms: float = OVERTIME_START_MS
@export var draw_arena_rect_debug := false
@export var draw_world_bounds_debug: bool = false
@export var show_floor_influence_debug: bool = false
@export var enable_floor_influence_runtime: bool = false
@export var use_dev_safe_centering := false
@export var FITCAM_POLICY := FIT_WIDTH
@export var debug_buff_loadout: Array[String] = [
	"buff_swarm_speed_classic",
	"buff_hive_faster_production_classic",
	"buff_tower_fire_rate_classic"
]
@export var sim_running: bool = false:
	set(value):
		_set_sim_running(value)
	get:
		return _get_sim_running()
var tick_accum := 0.0
var unit_id_counter := 1
var units: Array = []
var debris_id_counter := 1
var debris: Array = []
var debris_enabled := true
var swarm_id_counter := 1
var swarm_packets: Array = []
var active_player_id := 1
var hurry_mode := false
var audio_hurry_pitch := 1.0
var winner_id := -1
var end_reason := ""
var game_over := false
var _match_end_handled := false
var _post_match_action_taken := false
var _post_match_render_frozen := false
var towers: Array = []
var barracks: Array = []
var current_map_path := ""
var current_map_name := ""
var los_cache: Dictionary = {}
var sim_time_us: int = 0
var match_seed: int = 1
# Gameplay RNG boundary: gameplay logic must not call global rand* functions.
var game_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tie_history: Dictionary = {}
var tie_cache: Dictionary = {}
var tie_toast_ms: float = 0.0
var contest_last_log_us: Dictionary = {}
var arrival_history: Dictionary = {}
var units_landed: Dictionary = {}
var tutorial_arrivals_by_hive_owner: Dictionary = {}
var capture_count: int = 0
var error_count: int = 0
var tower_control_ms: Dictionary = {}
var barracks_control_ms: Dictionary = {}
var overtime_active := false
var barracks_select_id: int = -1
var barracks_select_pid: int = -1
var barracks_select_targets: Array = []
var barracks_select_changed := false
var map_offset := Vector2.ZERO
var hive_lane_order: Dictionary = {}
var hive_power_prev: Dictionary = {}
var buff_states: Dictionary = {}
var buff_active_slots: Dictionary = {}
var buff_instances: Dictionary = {}
var buff_mods: Dictionary = {}
var _buff_target_resolver: RefCounted = BuffTargetResolverScript.new()
var _buff_activation_transactions: RefCounted = BuffActivationTransactionScript.new()
var _buff_canonical_outcomes: Dictionary = {}
var _buff_activation_counter: int = 0
const RUNTIME_SUPPORTED_BUFF_EFFECT_TYPES: Dictionary = {
	"swarm_speed_pct": true,
	"hive_production_time_pct": true,
	"tower_fire_rate_pct": true,
	"lane_slow_pct": true,
	"lane_insight": true
}
var current_map_data: Dictionary = {}
var _match_telemetry_collector: Variant = MatchTelemetryCollectorScript.new()
var _match_analyzer: Variant = MatchAnalyzerScript.new()
var _player_telemetry_profiles: Variant = PlayerTelemetryProfileStoreScript.new()
var _post_match_analysis_summary: Dictionary = {}
var _post_match_telemetry_path: String = ""
var _telemetry_active: bool = false
var _last_screen_pointer_ms: int = -1000000
var _map_build_version: int = 0
var _map_built_version: int = -1
var _map_bounds_size: Vector2 = Vector2.ZERO
var _map_bounds_missing_logged: bool = false
var _fit_serial := 0
var _fit_applied_serial := -1
var _camera_fit_signature_last: String = ""
var _camera_fit_request_serial: int = 0
var _camera_transition_lock_active: bool = false
var _camera_transition_lock_frames: int = 0
var _camera_transition_lock_pos: Vector2 = Vector2.ZERO
var _camera_transition_lock_zoom: Vector2 = Vector2.ONE
var _dev_tick_log_ms: int = 0
var _dev_sim_dbg_us: int = 0
var _last_spawnfail_ms: int = 0

func _allow_camfit_log_tags() -> void:
	for tag in [
		"CAMFIT_DEFER_REQUEST",
		"CAMFIT_DEFER_DROP",
		"CAMFIT_DEFER_APPLY",
		"CAMFIT_ABORT",
		"CAMFIT_APPLY_SKIP",
		"CAMFIT_APPLY",
		"CAMFIT_TRANSITION_LOCK_ARMED",
		"CAMFIT_TRANSITION_DRIFT"
	]:
		SFLog.allow_tag(tag)
var _last_export_log_ms: int = 0
@export var debug_export_rm_log := false
@export var debug_export_rm_log_interval_ms := 1000
var _last_export_rm_log_ms := 0
@export var debug_swarms := false
@export var show_runtime_telemetry_overlay: bool = false
var _last_render_serial: int = -1
var _last_rm_ms: int = 0
const RM_REFRESH_HZ := 10.0
const POWERBAR_LOG_THROTTLE_MS: int = 250
const SPECTATOR_SNAPSHOT_INTERVAL_SEC: float = 1.0
var _pb_last_ratio: float = -1.0
var _pb_last_log_ms: int = 0
var _dbg_last_event: String = ""
var _dbg_last_event_ms: int = 0
var _dbg_last_hitch_ms: int = 0
var _render_assets_prewarmed: bool = false
var _hb_last_ms: int = 0
var _hb_frames: int = 0
var _hb_max_frame_ms: float = 0.0
var _hb_sum_frame_ms: float = 0.0
var _hb_max_process_ms: float = 0.0
var _hb_sum_process_ms: float = 0.0
var _hb_max_engine_process_ms: float = 0.0
var _hb_phys: int = 0
var _hb_max_phys_ms: float = 0.0
var _hb_sum_phys_ms: float = 0.0
var _runtime_telemetry_overlay: PanelContainer = null
var _runtime_telemetry_label: Label = null
var _runtime_telemetry_last_update_ms: int = 0
var _vs_pvp_runtime: Node = null
var _spectator_snapshot_accum: float = 0.0
var floor_influence_system: ArenaFloorInfluenceSystem = null
var _jukebox_back_button: Button = null
var _pvp_debug_overlay: Control = null
var _money_payment_layer: CanvasLayer = null
var _money_payment_modal: Panel = null
var _money_payment_body_label: Label = null
var _money_payment_status_label: Label = null
var _money_payment_context: Dictionary = {}
var _app_lifecycle: Node = null
var _lifecycle_local_pause_active: bool = false
var _lifecycle_local_pause_sim_was_running: bool = false
var _lifecycle_local_pause_reason: String = ""

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_restore_buff_activation_runtime_state()
	_allow_camfit_log_tags()
	SFLog.allow_tag("ARENA_FRAME_HEARTBEAT")
	SFLog.allow_tag("RUNTIME_TELEMETRY")
	SFLog.allow_tag("SIM_PIPELINE_ACTIVE")
	SFLog.allow_tag("LEGACY_SIM_PATH_BLOCKED")
	SFLog.allow_tag("MAP_APPLY_ONE_WAY_DOOR")
	SFLog.allow_tag("OPSSTATE_MUTATION_FENCE")
	SFLog.allow_tag("GAMESTATE_MUTATION_FENCE")
	SFLog.allow_tag("MAP_APPLIER_RUNTIME_ROSTER_WRITE")
	SFLog.allow_tag("HIVE_NODES_SET_SKIPPED")
	SFLog.allow_tag("BUFF_FIRED")
	set_physics_process(true)
	set_process_unhandled_input(false)
	SFLog.info("ARENA_SCRIPT", {"path": get_script().resource_path})
	SFLog.info("ARENA_READY", {"process": is_processing()})
	add_to_group("Arena")
	_configure_map_hex_background()
	self.scale = Vector2.ONE
	SFLog.info("POWER_BAR_REF", {"exists": power_bar != null, "path": _node_path_for_log(power_bar)})
	if power_bar == null:
		power_bar = _resolve_power_bar_node()
	if power_bar == null:
		SFLog.error("POWER_BAR_BIND_FAIL", {"path": SHELL_POWER_BAR_PATH})
	else:
		SFLog.info("POWER_BAR_BOUND", {"path": _node_path_for_log(power_bar), "inside_tree": power_bar.is_inside_tree()})
	var dmr := get_node_or_null("/root/DevMapRunner")
	if dmr:
		for c in dmr.get_children():
			if c.name == "Arena":
				continue
			if c.name == "DevMapLoader":
				continue
			if c is CanvasItem:
				(c as CanvasItem).visible = false
				SFLog.trace("HIDING", {"path": _node_path_for_log(c), "type": c.get_class()})
	RenderingServer.set_default_clear_color(Color(0.168627, 0.168627, 0.168627, 1))
	SFLog.trace("ARENA PATH", {"path": _node_path_for_log(self)})
	SFLog.trace("ARENA COUNT", {"count": get_tree().get_nodes_in_group("Arena").size()})
	SFLog.trace("\n=== ROOT CHILDREN ===")
	for c in get_tree().root.get_children():
		SFLog.trace(" - ", {"path": _node_path_for_log(c), "type": c.get_class()})
	clear_map_render()
	_setup_buff_hive_targeting_presentation()
	_setup_buff_lane_global_targeting_presentation()
	_ensure_arena_polish_layer()
	_apply_arena_polish_runtime_settings()
	$MapRoot/HiveRenderer.visible = true
	$MapRoot/LaneRenderer.visible = true
	_ensure_wall_renderer()
	$Camera2D.make_current()
	SFLog.trace("CANON GRID", {
		"grid_w": GRID_W,
		"grid_h": GRID_H,
		"world_px": Vector2(GRID_W * CELL_SIZE, GRID_H * CELL_SIZE)
	})
	SFLog.trace("CURRENT CAMERA", {"camera": get_viewport().get_camera_2d()})
	await get_tree().process_frame
	var cam := $Camera2D
	var vcam := get_viewport().get_camera_2d()
	SFLog.trace("ARENA CAM", {"arena_cam": cam, "viewport_cam": vcam})
	assert(vcam == cam)
	state = OpsState.get_state()
	if not OpsState.state_changed.is_connected(_on_ops_state_changed):
		OpsState.state_changed.connect(_on_ops_state_changed)
	if not OpsState.ops_state_changed.is_connected(_on_ops_state_changed_iid):
		OpsState.ops_state_changed.connect(_on_ops_state_changed_iid)
	_ensure_post_match_ui()
	if outcome_overlay != null and not outcome_overlay.post_match_action.is_connected(_on_post_match_action):
		outcome_overlay.post_match_action.connect(_on_post_match_action)
	sel = SelectionState.new()
	_init_systems()
	_bind_app_lifecycle()
	_ensure_jukebox_back_button()
	_prewarm_render_assets()
	SFLog.info("SIM_PIPELINE_ACTIVE", {
		"pipeline": "SimRunner",
		"legacy_arena_tick_fenced": true
	})
	if api != null:
		api.bind_state(state)
	if sim_runner != null and state != null:
		sim_runner.autostart_on_bind = false
		sim_runner.bind_state(state)
	los_cache.clear()
	_init_buff_states()
	_reset_match_stats()
	_reset_buff_states()
	if state != null:
		lane_renderer.setup(state, sel, self)
		SFLog.trace("HIVE_RENDERER_REF", {"ref": hive_renderer})
		hive_renderer.setup(state, sel, self)
		_inject_renderer_references()
		_sync_lane_system_blockers()
		_init_barracks()
		if state.hives != null:
			set_process_unhandled_input(true)
	# Match startup must flow through prematch/bootstrap so roster and bot state exist
	# before the simulation is allowed to run.
	_ensure_timer_hud()
	_ensure_progressive_counter_hud()
	call_deferred("_ensure_in_game_ad_surface")
	call_deferred("_ensure_runtime_telemetry_overlay")
	call_deferred("_ensure_pvp_debug_overlay")
	_configure_grid_spec(grid_w, grid_h)
	_map_bounds_size = Vector2.ZERO
	var arena_scale: Vector2 = global_transform.get_scale()
	dbg("ARENA: global_scale=%s" % [arena_scale])
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	call_deferred("_resize_world_viewport")
	call_deferred("_debug_camera", "ready")
	call_deferred("_debug_scan_cameras")
	call_deferred("_debug_canvas_space")
	call_deferred("_start_match_flow_deferred")
	_log_fit_state("ready")
	mark_render_dirty("ready")
	_dump_map_like_nodes("after_clear_ready")
	_debug_scan_names()
	_dump_map_renderers("boot")
	_dump_viewports_and_textures()
	_dump_tree_with_scripts("/root/DevMapRunner")
	# (moved to top of _ready())
	_list_canvasitems_with_scripts("/root/DevMapRunner/Arena")

func _configure_map_hex_background() -> void:
	_ensure_map_mm_background_art()
	if map_hex_background == null:
		return
	if map_hex_background.has_method("apply_preset"):
		map_hex_background.call("apply_preset", StringName("dash"))

func _ensure_arena_polish_layer() -> Node2D:
	if arena_polish_layer != null and is_instance_valid(arena_polish_layer):
		arena_polish_layer.call("apply_runtime_settings")
		return arena_polish_layer
	if map_root == null:
		return null
	var existing: Node = map_root.get_node_or_null("ArenaPolishLayer")
	if existing is Node2D and existing.get_script() == ArenaPolishLayerScript:
		arena_polish_layer = existing as Node2D
	else:
		arena_polish_layer = ArenaPolishLayerScript.new() as Node2D
		arena_polish_layer.name = "ArenaPolishLayer"
		map_root.add_child(arena_polish_layer)
	arena_polish_layer.call("apply_runtime_settings")
	return arena_polish_layer

func _apply_arena_polish_runtime_settings() -> void:
	var layer: Node2D = _ensure_arena_polish_layer()
	if layer == null:
		return
	layer.call("apply_runtime_settings")
	if tower_renderer_node != null and tower_renderer_node.has_method("apply_visual_settings"):
		tower_renderer_node.call("apply_visual_settings")

func apply_arena_visual_comparison_mode(mode: String) -> void:
	ArenaPolishLayerScript.call("apply_comparison_mode", mode)
	_apply_arena_polish_runtime_settings()

func arena_visual_comparison_modes() -> PackedStringArray:
	return ArenaPolishLayerScript.call("comparison_modes") as PackedStringArray

func _ensure_map_mm_background_art() -> void:
	var map_background_layer: CanvasLayer = get_node_or_null("MapHexBackgroundLayer") as CanvasLayer
	if map_background_layer == null:
		return
	var background_art: TextureRect = map_background_layer.get_node_or_null(String(MAP_MM_BACKGROUND_NODE_NAME)) as TextureRect
	if background_art == null:
		background_art = TextureRect.new()
		background_art.name = String(MAP_MM_BACKGROUND_NODE_NAME)
		background_art.layout_mode = 1
		background_art.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_background_layer.add_child(background_art)
		map_background_layer.move_child(background_art, 0)
	_map_mm_background_art = background_art
	_apply_map_mm_background_art_layout()

func _apply_map_mm_background_art_layout() -> void:
	if _map_mm_background_art == null:
		return
	_map_mm_background_art.texture = MM_BACKGROUND_ART_TEXTURE
	_map_mm_background_art.stretch_mode = MM_BACKGROUND_STRETCH_MODE
	_map_mm_background_art.offset_left = 0.0
	_map_mm_background_art.offset_right = 0.0
	_map_mm_background_art.offset_top = MM_BACKGROUND_Y_SHIFT
	_map_mm_background_art.offset_bottom = MM_BACKGROUND_Y_SHIFT
	_map_mm_background_art.pivot_offset = _map_mm_background_art.size * 0.5
	var base_width_px: float = maxf(1.0, _map_mm_background_art.size.x)
	if base_width_px <= 1.0 and get_viewport() != null:
		base_width_px = maxf(1.0, get_viewport().get_visible_rect().size.x)
	var width_scale_extra: float = 1.0 + ((MM_BACKGROUND_EXTRA_SIDE_PX * 2.0) / base_width_px)
	_map_mm_background_art.scale = Vector2(MM_BACKGROUND_X_SCALE * width_scale_extra, 1.0)

func _start_match_flow() -> void:
	SFLog.info("PREMATCH_BEGIN", {})
	_force_unpause_sanity()
	_ensure_prematch_ui()
	if _controls_hint_controller != null:
		_controls_hint_controller.ensure_overlay(Callable(self, "_resolve_hud_root"), Callable(self, "_force_fullscreen_anchors"))
	var tutorial_launch_active: bool = _is_tutorial_launch_active()
	var tutorial_section: String = _tutorial_launch_section()
	var controls_tutorial_launch: bool = tutorial_launch_active and tutorial_section == TUTORIAL_CONTROLS_ID
	_begin_prematch()
	if controls_tutorial_launch:
		_finish_prematch()
		SFLog.info("TUTORIAL_CONTROLS_PREMATCH_BYPASS", {
			"phase": int(OpsState.match_phase),
			"input_locked": bool(OpsState.input_locked)
		})
	var tutorial_active: bool = false
	if tutorial_launch_active and tutorial_section == TUTORIAL_CONTROLS_ID and _tutorial_controls_controller != null:
		tutorial_active = _tutorial_controls_controller.start_if_needed(
			Callable(self, "_resolve_hud_root"),
			Callable(self, "_force_fullscreen_anchors"),
			_resolve_local_owner_id(),
			state,
			Callable(self, "_tutorial_hive_screen_pos"),
			Callable(self, "_pause_tutorial_message_sim"),
			Callable(self, "_resume_tutorial_message_sim"),
			Callable(self, "_tutorial_arrival_count")
		)
	if tutorial_launch_active and tutorial_section == TUTORIAL_SECTION1_ID and _tutorial_section1_controller != null:
		tutorial_active = _tutorial_section1_controller.start_if_needed(
			Callable(self, "_resolve_hud_root"),
			Callable(self, "_force_fullscreen_anchors"),
			_resolve_local_owner_id(),
			state,
			Callable(self, "_pause_tutorial_message_sim"),
			Callable(self, "_resume_tutorial_message_sim"),
			Callable(self, "_tutorial_hive_screen_pos"),
			Callable(self, "_tutorial_buff_screen_pos"),
			Callable(self, "get_buff_ui_snapshot")
		)
	if tutorial_launch_active and not tutorial_active and tutorial_section == TUTORIAL_SECTION2_ID and _tutorial_section2_controller != null:
		tutorial_active = _tutorial_section2_controller.start_if_needed(
			Callable(self, "_resolve_hud_root"),
			Callable(self, "_force_fullscreen_anchors"),
			_resolve_local_owner_id(),
			state
		)
	if tutorial_launch_active and not tutorial_active and tutorial_section == TUTORIAL_SECTION3_ID and _tutorial_section3_controller != null:
		tutorial_active = _tutorial_section3_controller.start_if_needed(
			Callable(self, "_resolve_hud_root"),
			Callable(self, "_force_fullscreen_anchors"),
			_resolve_local_owner_id(),
			state
		)
	if tutorial_active:
		_apply_tutorial_low_pressure_scenario()
		if _controls_hint_controller != null:
			_controls_hint_controller.hide(false)
	elif _is_jukebox_easy_bot_mode():
		_apply_jukebox_easy_bot_profile()
	elif _has_vs_cpu_bot_override():
		_apply_vs_cpu_bot_override()
	elif _controls_hint_controller != null:
		_controls_hint_controller.maybe_show_once(Callable(self, "_resolve_hud_root"), Callable(self, "_force_fullscreen_anchors"))

func _is_tutorial_launch_active() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	return bool(tree.get_meta(TREE_META_TUTORIAL_ACTIVE, false))

func _tutorial_launch_section() -> String:
	var tree: SceneTree = get_tree()
	if tree == null:
		return ""
	return str(tree.get_meta(TREE_META_TUTORIAL_SECTION, "")).strip_edges()

func tutorial_controls_smoke_snapshot() -> Dictionary:
	if _tutorial_controls_controller == null:
		return {"active": false, "current_step": "", "anchors": {}, "contracts": []}
	return _tutorial_controls_controller.smoke_snapshot()

func tutorial_controls_smoke_should_allow_pointer_event(ev: Dictionary) -> bool:
	if _tutorial_controls_controller == null:
		return true
	return _tutorial_controls_controller.should_allow_pointer_event(ev, state)

func _tutorial_arrival_count(hive_id: int, owner_id: int) -> int:
	if unit_system != null and unit_system.has_method("get_arrival_count"):
		return int(unit_system.call("get_arrival_count", hive_id, owner_id))
	return int(tutorial_arrivals_by_hive_owner.get("%d:%d" % [hive_id, owner_id], 0))

func restart_match_flow_for_shell_launch() -> void:
	_start_match_flow()

func _start_match_flow_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_start_match_flow()

func _apply_tutorial_low_pressure_scenario() -> void:
	if OpsState == null or not OpsState.has_method("set_bot_profile"):
		return
	var local_owner_id: int = _resolve_local_owner_id()
	var team_by_seat: Dictionary = {}
	if OpsState.has_method("get_team_by_seat_snapshot"):
		var team_snapshot_any: Variant = OpsState.call("get_team_by_seat_snapshot")
		if typeof(team_snapshot_any) == TYPE_DICTIONARY:
			team_by_seat = (team_snapshot_any as Dictionary).duplicate(true)
	var local_team_id: int = int(team_by_seat.get(local_owner_id, local_owner_id))
	var controls_tutorial: bool = _tutorial_launch_section() == TUTORIAL_CONTROLS_ID
	for seat in [1, 2, 3, 4]:
		var seat_id: int = int(seat)
		if seat_id == local_owner_id:
			continue
		var seat_team_id: int = int(team_by_seat.get(seat_id, seat_id))
		var is_ally: bool = seat_team_id == local_team_id
		if is_ally:
			OpsState.call("set_bot_profile", seat_id, {
				"enabled": false,
				"opening_delay_ms": 999999,
				"aggression": 0.0
			})
			continue
		if controls_tutorial:
			OpsState.call("set_bot_profile", seat_id, {
				"enabled": false,
				"opening_delay_ms": 999999,
				"aggression": 0.0
			})
			continue
		OpsState.call("set_bot_profile", seat_id, {
			"enabled": true,
			"style": "turtle",
			"persona": "turtle",
			"tier": "easy",
			"opening_delay_ms": 7000,
			"think_interval_ms": 3200,
			"think_jitter_ms": 900,
			"post_intent_delay_ms": 1400,
			"global_intent_cooldown_ms": 2800,
			"pair_intent_cooldown_ms": 3600,
			"min_attack_power": 14,
			"min_feed_power": 16,
			"min_swarm_power": 99,
			"allow_swarm": false,
			"aggression": 0.28,
			"feed_bias": 0.36,
			"randomness": 0.14
		})
	SFLog.info("TUTORIAL_LOW_PRESSURE_SCENARIO", {
		"local_owner_id": local_owner_id,
		"local_team_id": local_team_id,
		"enemy_profile": "disabled/controller_driven" if controls_tutorial else "turtle/easy"
	})

func _is_jukebox_easy_bot_mode() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	return bool(tree.get_meta(JUKEBOX_META_EASY_BOT, false))

func _is_jukebox_run() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	return bool(tree.get_meta(JUKEBOX_META_ENABLED, false))

func _ensure_jukebox_back_button() -> void:
	if _jukebox_back_button != null and is_instance_valid(_jukebox_back_button):
		_jukebox_back_button.visible = _is_jukebox_run()
		return
	var bottom_buffer: Control = get_node_or_null(SHELL_BOTTOM_BUFFER_PATH) as Control
	if bottom_buffer == null:
		return
	var button: Button = bottom_buffer.get_node_or_null("JukeboxBackButton") as Button
	if button == null:
		button = Button.new()
		button.name = "JukeboxBackButton"
		button.text = "BACK TO JUKEBOX"
		button.custom_minimum_size = Vector2(196.0, 44.0)
		button.anchor_left = 0.5
		button.anchor_top = 1.0
		button.anchor_right = 0.5
		button.anchor_bottom = 1.0
		button.offset_left = -98.0
		button.offset_top = -58.0
		button.offset_right = 98.0
		button.offset_bottom = -14.0
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.z_as_relative = false
		button.z_index = 3002
		bottom_buffer.add_child(button)
	if not button.pressed.is_connected(_on_jukebox_back_pressed):
		button.pressed.connect(_on_jukebox_back_pressed)
	button.visible = _is_jukebox_run()
	_jukebox_back_button = button

func _capture_jukebox_restore_state() -> Dictionary:
	var tree: SceneTree = get_tree()
	if tree == null:
		return {}
	var map_path: String = str(tree.get_meta(JUKEBOX_META_MAP_PATH, "")).strip_edges()
	var period: String = str(tree.get_meta(JUKEBOX_META_PERIOD, "WEEKLY")).strip_edges().to_upper()
	var cpu_style: String = str(tree.get_meta(TREE_META_VS_CPU_STYLE, "")).strip_edges().to_lower()
	var cpu_tier: String = str(tree.get_meta(TREE_META_VS_CPU_TIER, "")).strip_edges().to_lower()
	return {
		"selected_map_path": map_path,
		"selected_period": period,
		"cpu_style": cpu_style,
		"cpu_tier": cpu_tier,
		"highlight_player_id": str(tree.get_meta(JUKEBOX_META_HIGHLIGHT_PLAYER_ID, "")).strip_edges()
	}

func _on_jukebox_back_pressed() -> void:
	_return_to_jukebox()

func _return_to_jukebox() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if outcome_overlay != null:
		outcome_overlay.hide_overlay()
	if sim_runner != null:
		sim_runner.log_pause_snapshot("arena_return_to_jukebox")
	tree.set_meta(TREE_META_REOPEN_JUKEBOX_ON_READY, true)
	tree.set_meta(TREE_META_REOPEN_JUKEBOX_STATE, _capture_jukebox_restore_state())
	var current_scene: Node = tree.current_scene
	if current_scene != null and current_scene.has_method("_open_main_menu"):
		await _fade_out_post_match_song_blocking()
		current_scene.call("_open_main_menu")
		return
	await _fade_out_post_match_song_blocking()
	tree.change_scene_to_file("res://scenes/MainMenu.tscn")

func _has_vs_cpu_bot_override() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	return tree.has_meta(TREE_META_VS_CPU_STYLE) or tree.has_meta(TREE_META_VS_CPU_TIER)

func _apply_vs_cpu_bot_override() -> void:
	if OpsState == null or not OpsState.has_method("set_bot_profile"):
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var style: String = str(tree.get_meta(TREE_META_VS_CPU_STYLE, "")).strip_edges().to_lower()
	var tier: String = str(tree.get_meta(TREE_META_VS_CPU_TIER, "")).strip_edges().to_lower()
	if style.is_empty() and tier.is_empty():
		return
	var local_owner_id: int = _resolve_local_owner_id()
	var patch: Dictionary = {}
	if not style.is_empty():
		patch["style"] = style
	if not tier.is_empty():
		patch["tier"] = tier
	for seat in [1, 2, 3, 4]:
		var seat_id: int = int(seat)
		if seat_id == local_owner_id:
			continue
		OpsState.call("set_bot_profile", seat_id, patch)
	SFLog.info("ASYNC_CPU_BOT_OVERRIDE", {
		"local_owner_id": local_owner_id,
		"style": style,
		"tier": tier
	})

func _apply_jukebox_easy_bot_profile() -> void:
	if OpsState == null or not OpsState.has_method("set_bot_profile"):
		return
	var local_owner_id: int = _resolve_local_owner_id()
	for seat in [1, 2, 3, 4]:
		var seat_id: int = int(seat)
		if seat_id == local_owner_id:
			continue
		OpsState.call("set_bot_profile", seat_id, {
			"style": "balancer",
			"persona": "balancer",
			"tier": "medium",
			"think_interval_ms": 2300,
			"think_jitter_ms": 220,
			"post_intent_delay_ms": 935,
			"opening_delay_ms": 3825,
			"opening_stagger_ms": 360,
			"aggression": 0.47,
			"feed_bias": 0.32,
			"min_attack_power": 12,
			"min_feed_power": 14,
			"min_swarm_power": 21,
			"allow_swarm": true,
			"max_actions_per_tick": 1,
			"prefer_neutral_bonus": 0.50,
			"randomness": 0.12,
			"retry_block_ms": 1350,
			"no_lane_retry_ms": 4250,
			"pair_intent_cooldown_ms": 2250,
			"global_intent_cooldown_ms": 1900,
			"swarm_cooldown_ms": 2525,
			"swarm_global_cooldown_ms": 5150,
			"swarm_frequency": 0.18,
			"guard_ally_power_threshold": 12,
			"guard_feed_score_margin": 8.0
		})
	SFLog.info("JUKEBOX_FIXED_BOT_PROFILE", {
		"local_owner_id": local_owner_id,
		"style": "balancer",
		"tier": "medium"
	})

func _resolve_top_hud_root() -> Node:
	var top_hud_root: Node = get_node_or_null(SHELL_HUD_LAYER_PATH + "/TopHudRoot")
	if top_hud_root != null:
		return top_hud_root
	return get_node_or_null(SHELL_HUD_LAYER_PATH)

func _resolve_power_bar_node() -> PowerBar:
	var pb: PowerBar = get_node_or_null(SHELL_POWER_BAR_PATH) as PowerBar
	if pb != null:
		return pb
	return null

func _resolve_hud_root() -> Control:
	var hud_root: Control = get_node_or_null(SHELL_HUD_ROOT_PATH) as Control
	if hud_root != null:
		return hud_root
	var hud_layer: CanvasLayer = get_node_or_null(SHELL_HUD_LAYER_PATH) as CanvasLayer
	if hud_layer != null:
		var from_layer: Control = hud_layer.get_node_or_null("HUDRoot") as Control
		if from_layer != null:
			return from_layer
	var scene: Node = get_tree().current_scene
	if scene != null:
		var found: Node = scene.find_child("HUDRoot", true, false)
		if found is Control:
			return found as Control
	var legacy_ui: Control = get_node_or_null("../UI") as Control
	return legacy_ui

func _ensure_post_match_ui() -> void:
	outcome_overlay = _resolve_or_create_outcome_overlay()
	win_overlay = _resolve_or_create_win_overlay()
	if outcome_overlay != null and not outcome_overlay.post_match_action.is_connected(_on_post_match_action):
		outcome_overlay.post_match_action.connect(_on_post_match_action)
	var ui_ready: bool = outcome_overlay != null and win_overlay != null
	if ui_ready:
		if _postmatch_ui_missing_logged:
			SFLog.warn("POSTMATCH_UI_RECOVERED", {
				"outcome_path": _node_path_for_log(outcome_overlay),
				"win_path": _node_path_for_log(win_overlay)
			})
		_postmatch_ui_missing_logged = false
		return
	if not _postmatch_ui_missing_logged:
		_postmatch_ui_missing_logged = true
		SFLog.warn("POSTMATCH_UI_MISSING", {
			"outcome_found": outcome_overlay != null,
			"win_found": win_overlay != null
		})

func _resolve_or_create_outcome_overlay() -> OutcomeOverlay:
	var existing: OutcomeOverlay = get_node_or_null(SHELL_OUTCOME_OVERLAY_PATH) as OutcomeOverlay
	if existing != null:
		return existing
	var scene: Node = get_tree().current_scene
	if scene != null:
		var found: Node = scene.find_child("OutcomeOverlay", true, false)
		if found is OutcomeOverlay:
			return found as OutcomeOverlay
	var hud_root: Control = _resolve_hud_root()
	if hud_root == null:
		return null
	var created: OutcomeOverlay = _build_outcome_overlay()
	hud_root.add_child(created)
	return created

func _resolve_or_create_win_overlay() -> WinOverlay:
	var existing: WinOverlay = get_node_or_null(SHELL_WIN_OVERLAY_PATH) as WinOverlay
	if existing != null:
		return existing
	var scene: Node = get_tree().current_scene
	if scene != null:
		var found: Node = scene.find_child("WinOverlay", true, false)
		if found is WinOverlay:
			return found as WinOverlay
	var hud_root: Control = _resolve_hud_root()
	if hud_root == null:
		return null
	var created: WinOverlay = _build_win_overlay()
	hud_root.add_child(created)
	return created

func _build_outcome_overlay() -> OutcomeOverlay:
	var overlay: OutcomeOverlay = OutcomeOverlay.new()
	overlay.name = "OutcomeOverlay"
	overlay.visible = false
	overlay.layout_mode = 3
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.grow_horizontal = 2
	overlay.grow_vertical = 2

	var panel: Panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -240.0
	panel.offset_top = -320.0
	panel.offset_right = 240.0
	panel.offset_bottom = 320.0
	overlay.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 12.0
	vbox.offset_top = 12.0
	vbox.offset_right = -12.0
	vbox.offset_bottom = -12.0
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "P1 WINS"
	vbox.add_child(title)

	var result: Label = Label.new()
	result.name = "Result"
	result.text = "VICTORY"
	vbox.add_child(result)

	var reason: Label = Label.new()
	reason.name = "Reason"
	reason.text = "Reason: Elimination"
	vbox.add_child(reason)

	var record: Label = Label.new()
	record.name = "Record"
	record.text = "Record: 0-0"
	vbox.add_child(record)

	var h2h: Label = Label.new()
	h2h.name = "H2H"
	h2h.text = "H2H: 0-0"
	vbox.add_child(h2h)

	var stats_header: Label = Label.new()
	stats_header.name = "StatsHeader"
	stats_header.text = "Match Stats"
	vbox.add_child(stats_header)

	var stat_max: Label = Label.new()
	stat_max.name = "StatMaxHivePower"
	stat_max.text = "Max Total Hive Power: 0"
	vbox.add_child(stat_max)

	var stat_killed: Label = Label.new()
	stat_killed.name = "StatUnitsKilled"
	stat_killed.text = "Units Killed: 0"
	vbox.add_child(stat_killed)

	var stat_landed: Label = Label.new()
	stat_landed.name = "StatUnitsLanded"
	stat_landed.text = "Units Landed: 0"
	vbox.add_child(stat_landed)

	var countdown: Label = Label.new()
	countdown.name = "Countdown"
	countdown.text = "Rematch expires in 0:10"
	vbox.add_child(countdown)

	var status: Label = Label.new()
	status.name = "Status"
	status.text = "You: NOT READY | Opponent: WAITING"
	vbox.add_child(status)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Buttons"
	vbox.add_child(buttons)

	var rematch: Button = Button.new()
	rematch.name = "Rematch"
	rematch.text = "Restart"
	buttons.add_child(rematch)

	var exit: Button = Button.new()
	exit.name = "Exit"
	exit.text = "Return to Menu"
	buttons.add_child(exit)

	return overlay

func _build_win_overlay() -> WinOverlay:
	var overlay: WinOverlay = WinOverlay.new()
	overlay.name = "WinOverlay"
	overlay.visible = false
	overlay.layout_mode = 3
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.grow_horizontal = 2
	overlay.grow_vertical = 2

	var panel: Panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.1
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.1
	panel.offset_left = -160.0
	panel.offset_top = -30.0
	panel.offset_right = 160.0
	panel.offset_bottom = 30.0
	overlay.add_child(panel)

	var title: Label = Label.new()
	title.name = "Title"
	title.anchor_right = 1.0
	title.anchor_bottom = 1.0
	title.offset_left = 8.0
	title.offset_top = 4.0
	title.offset_right = -8.0
	title.offset_bottom = -18.0
	title.text = "PLAYER 1 WINS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var sub: Label = Label.new()
	sub.name = "Sub"
	sub.anchor_right = 1.0
	sub.anchor_bottom = 1.0
	sub.offset_left = 8.0
	sub.offset_top = 18.0
	sub.offset_right = -8.0
	sub.offset_bottom = -4.0
	sub.text = "Reason: conquest"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sub)

	return overlay

func _resolve_top_buffer_background() -> TextureRect:
	var top_hud_root: Node = _resolve_top_hud_root()
	if top_hud_root != null:
		var top_buffer: TextureRect = top_hud_root.get_node_or_null("TopBufferBackground") as TextureRect
		if top_buffer != null:
			return top_buffer
	var backdrop_buffer: TextureRect = get_node_or_null(SHELL_TOP_BUFFER_PATH) as TextureRect
	if backdrop_buffer != null:
		return backdrop_buffer
	return get_node_or_null(SHELL_HUD_LAYER_PATH + "/TopBufferBackground") as TextureRect

func _resolve_bottom_buffer_background() -> TextureRect:
	var backdrop_buffer: TextureRect = get_node_or_null(SHELL_BOTTOM_BUFFER_PATH) as TextureRect
	if backdrop_buffer != null:
		return backdrop_buffer
	return get_node_or_null(SHELL_HUD_LAYER_PATH + "/BottomBufferBackground") as TextureRect

func _ui_top_inset_px() -> float:
	var top_buffer: Control = _resolve_top_buffer_background() as Control
	if top_buffer == null:
		top_buffer = get_node_or_null(SHELL_TOP_BUFFER_PATH) as Control
	if top_buffer == null:
		top_buffer = get_node_or_null(SHELL_HUD_LAYER_PATH + "/TopHudRoot/TopBufferBackground") as Control
	if top_buffer == null:
		return 0.0
	return maxf(0.0, float(top_buffer.get_global_rect().size.y))

func _ui_vertical_insets_px() -> Dictionary:
	var tree: SceneTree = get_tree()
	var world_container: Control = _world_viewport_cache.resolve_container(tree) if _world_viewport_cache != null else null
	if get_node_or_null(SHELL_HUD_ROOT_PATH) != null:
		return {"top": 0.0, "bottom": 0.0}
	if world_container == null:
		return {"top": _ui_top_inset_px(), "bottom": 0.0}
	var container_rect: Rect2 = world_container.get_global_rect()
	if container_rect.size.y <= 0.0:
		return {"top": 0.0, "bottom": 0.0}
	var top_inset: float = 0.0
	var bottom_inset: float = 0.0
	var overlays: Array[Control] = []
	var top_buffer: Control = _resolve_top_buffer_background() as Control
	var bottom_buffer: Control = get_node_or_null(SHELL_BOTTOM_BUFFER_PATH) as Control
	if top_buffer != null:
		overlays.append(top_buffer)
	if bottom_buffer != null:
		overlays.append(bottom_buffer)
	var container_top: float = container_rect.position.y
	var container_bottom: float = container_top + container_rect.size.y
	for overlay in overlays:
		if overlay == null or not overlay.visible:
			continue
		var overlay_rect: Rect2 = overlay.get_global_rect()
		if not overlay_rect.intersects(container_rect):
			continue
		var overlap: Rect2 = overlay_rect.intersection(container_rect)
		if overlap.size.y <= 0.0:
			continue
		var overlap_top: float = overlap.position.y
		var overlap_bottom: float = overlap.position.y + overlap.size.y
		if overlap_top <= container_top + 1.0:
			top_inset = maxf(top_inset, overlap_bottom - container_top)
		if overlap_bottom >= container_bottom - 1.0:
			bottom_inset = maxf(bottom_inset, container_bottom - overlap_top)
	var max_inset: float = maxf(0.0, container_rect.size.y - 1.0)
	top_inset = clampf(top_inset, 0.0, max_inset)
	bottom_inset = clampf(bottom_inset, 0.0, max_inset)
	return {
		"top": top_inset,
		"bottom": bottom_inset
	}

func _shell_bottom_ui_inset_px(world_container: Control) -> float:
	if world_container == null:
		return 0.0
	var container_rect: Rect2 = world_container.get_global_rect()
	if container_rect.size.y <= 0.0:
		return 0.0
	var container_bottom: float = container_rect.position.y + container_rect.size.y
	var bottom_inset: float = 0.0
	for path in [
		SHELL_PLAYER_BUFF_STRIP_PATH,
		SHELL_OPPONENT_BUFF_STRIP_PATH,
		SHELL_OPPONENT_BUFF_STRIP_B_PATH,
		SHELL_ALLY_BUFF_STRIP_PATH
	]:
		var overlay: Control = get_node_or_null(path) as Control
		if overlay == null or not overlay.visible:
			continue
		var overlay_rect: Rect2 = overlay.get_global_rect()
		if not overlay_rect.intersects(container_rect):
			continue
		var overlap: Rect2 = overlay_rect.intersection(container_rect)
		if overlap.size.y <= 0.0:
			continue
		var overlap_top: float = overlap.position.y
		bottom_inset = maxf(bottom_inset, container_bottom - overlap_top + SHELL_BOTTOM_UI_GAP_PX)
	var max_inset: float = maxf(0.0, container_rect.size.y - 1.0)
	return clampf(bottom_inset, 0.0, max_inset)

func _is_dev_or_editor_context() -> bool:
	if Engine.is_editor_hint():
		return true
	return get_node_or_null("/root/DevMapRunner") != null

func _audit_ops_write(target: String, context: String) -> void:
	if OpsState == null:
		return
	if OpsState.has_method("audit_mutation"):
		OpsState.audit_mutation(context, target, get_script().resource_path)

func _audit_state_write(target: String, context: String) -> void:
	if state == null:
		return
	if state.has_method("audit_mutation"):
		state.audit_mutation(context, target, get_script().resource_path)

func _force_unpause_sanity() -> void:
	var tree := get_tree()
	var paused := false
	if tree != null:
		paused = tree.paused
		tree.paused = false
	Engine.time_scale = 1.0
	var scene_name := ""
	if tree != null and tree.current_scene != null:
		scene_name = str(tree.current_scene.name)
	SFLog.info("MATCH_FLOW_ENTER", {
		"paused": paused,
		"time_scale": float(Engine.time_scale),
		"scene": scene_name
	})

func _begin_prematch() -> void:
	if OpsState.match_phase == OpsState.MatchPhase.ENDING or OpsState.match_phase == OpsState.MatchPhase.ENDED:
		return
	_ensure_match_roster()
	_configure_vs_pvp_runtime()
	_configure_special_victory_mode()
	_match_started = false
	var prematch_dur_ms: int = OpsState.prematch_duration_ms
	if prematch_dur_ms <= 0:
		prematch_dur_ms = OpsState.PREMATCH_DURATION_MS
	if _should_show_prematch_identity_flow():
		prematch_dur_ms = maxi(prematch_dur_ms, PREMATCH_ORIENTATION_DURATION_MS)
	if _capture_flag_selection_pending_for_local():
		prematch_dur_ms += CTF_SELECTION_GRACE_MS
	_prematch_remaining_ms_f = float(prematch_dur_ms)
	OpsState.sim_mutate("Arena._begin_prematch", func() -> void:
		_audit_ops_write("match_phase", "Arena._begin_prematch")
		OpsState.match_phase = OpsState.MatchPhase.PREMATCH
		_audit_ops_write("input_locked", "Arena._begin_prematch")
		OpsState.input_locked = true
		_audit_ops_write("input_locked_reason", "Arena._begin_prematch")
		OpsState.input_locked_reason = "prematch"
		_audit_ops_write("prematch_duration_ms", "Arena._begin_prematch")
		OpsState.prematch_duration_ms = prematch_dur_ms
		OpsState.set_prematch_remaining_ms(int(ceil(_prematch_remaining_ms_f)), "Arena._begin_prematch")
	)
	SFLog.info("PREMATCH_BEGIN", {
		"phase": int(OpsState.match_phase),
		"ms": int(OpsState.prematch_remaining_ms)
	})
	_play_prematch_countdown_sfx()
	_prematch_last_sec = -1
	_prematch_records_faded = false
	_prematch_countdown_faded = false
	_prematch_final_fit_requested = false
	_prematch_identity_card_faded = false
	_prematch_hive_focus_started = false
	_prematch_countdown_return_started = false
	_power_bar_reveal_started = false
	_clear_prematch_pulses()
	_apply_team_orientation_buffers()
	_show_prematch_ui()
	if sim_runner != null:
		sim_runner.set_running(false, "prematch_hold")
	SFLog.info("PREMATCH_START", {
		"duration_s": int(round(float(OpsState.prematch_duration_ms) / 1000.0))
	})

func _play_prematch_countdown_sfx() -> void:
	if not _is_game_sfx_enabled():
		return
	var stream: AudioStream = load(PREMATCH_COUNTDOWN_SOUND_PATH) as AudioStream
	if stream == null:
		if SFLog.LOGGING_ENABLED:
			push_warning("PREMATCH_COUNTDOWN_SOUND_MISSING: " + PREMATCH_COUNTDOWN_SOUND_PATH)
		return
	if _prematch_countdown_sfx_player == null or not is_instance_valid(_prematch_countdown_sfx_player):
		_prematch_countdown_sfx_player = AudioStreamPlayer.new()
		_prematch_countdown_sfx_player.name = "PrematchCountdownSfxPlayer"
		add_child(_prematch_countdown_sfx_player)
	_prematch_countdown_sfx_player.stop()
	_prematch_countdown_sfx_player.stream = stream
	_prematch_countdown_sfx_player.play()

func _is_game_sfx_enabled() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return true
	var profile_manager: Node = tree.root.get_node_or_null("/root/ProfileManager")
	if profile_manager != null and profile_manager.has_method("is_sfx_enabled"):
		return bool(profile_manager.call("is_sfx_enabled"))
	return true

func _on_tower_fire_for_sfx(tower_id: int, _owner_id: int, _tier: int, _tower_pos: Vector2, _target_unit_id: int, _target_pos: Vector2) -> void:
	if tower_id <= 0:
		return
	var shot_count: int = int(_tower_shot_sfx_counts.get(tower_id, 0)) + 1
	_tower_shot_sfx_counts[tower_id] = shot_count
	if shot_count != 1 and (shot_count - 1) % 5 != 0:
		return
	_play_tower_shot_sfx()

func _play_tower_shot_sfx() -> void:
	if not _is_game_sfx_enabled():
		return
	if _tower_shot_sfx_stream == null:
		_tower_shot_sfx_stream = load(TOWER_SHOT_SOUND_PATH) as AudioStream
	if _tower_shot_sfx_stream == null:
		if SFLog.LOGGING_ENABLED:
			push_warning("TOWER_SHOT_SOUND_MISSING: " + TOWER_SHOT_SOUND_PATH)
		return
	var player := AudioStreamPlayer.new()
	player.name = "TowerShotSfxPlayer"
	player.stream = _tower_shot_sfx_stream
	player.finished.connect(Callable(player, "queue_free"))
	add_child(player)
	player.play()

func _on_swarm_spawned_for_sfx(swarm_id: int, _owner_id: int, _from_id: int, _to_id: int, _lane_id: int, _world_pos: Vector2) -> void:
	_play_swarm_sfx(swarm_id)

func _on_swarm_landed_for_sfx(swarm_id: int, _owner_id: int, _from_id: int, _to_id: int, _lane_id: int, _world_pos: Vector2) -> void:
	_stop_swarm_sfx(swarm_id)

func _play_swarm_sfx(swarm_id: int = -1) -> void:
	if not _is_game_sfx_enabled():
		return
	if _swarm_sfx_stream == null:
		_swarm_sfx_stream = load(SWARM_SOUND_PATH) as AudioStream
	if _swarm_sfx_stream == null:
		if SFLog.LOGGING_ENABLED:
			push_warning("SWARM_SOUND_MISSING: " + SWARM_SOUND_PATH)
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "SwarmSfxPlayer_%d" % swarm_id
	player.stream = _swarm_sfx_stream
	if swarm_id > 0:
		_stop_swarm_sfx(swarm_id)
		_swarm_sfx_players_by_id[swarm_id] = player
	player.finished.connect(func() -> void:
		if swarm_id > 0:
			var current: AudioStreamPlayer = _swarm_sfx_players_by_id.get(swarm_id, null) as AudioStreamPlayer
			if current == player:
				_swarm_sfx_players_by_id.erase(swarm_id)
		if is_instance_valid(player):
			player.queue_free()
	)
	add_child(player)
	player.play()

func _stop_swarm_sfx(swarm_id: int) -> void:
	if swarm_id <= 0:
		return
	var player: AudioStreamPlayer = _swarm_sfx_players_by_id.get(swarm_id, null) as AudioStreamPlayer
	_swarm_sfx_players_by_id.erase(swarm_id)
	if player == null or not is_instance_valid(player):
		return
	player.stop()
	player.queue_free()

func _stop_all_swarm_sfx() -> void:
	for swarm_id_any in _swarm_sfx_players_by_id.keys():
		_stop_swarm_sfx(int(swarm_id_any))
	_swarm_sfx_players_by_id.clear()

func _on_hive_owner_changed_for_sfx(_hive_id: int, prev_owner: int, next_owner: int, _world_pos: Vector2) -> void:
	var local_owner_id: int = _resolve_local_owner_id()
	if local_owner_id <= 0:
		return
	if prev_owner == local_owner_id and next_owner != local_owner_id:
		if not _can_play_hive_switch_sfx():
			return
		_play_lose_hive_sfx()
	elif next_owner == local_owner_id and prev_owner > 0 and prev_owner != local_owner_id:
		if not _can_play_hive_switch_sfx():
			return
		_play_win_hive_sfx()

func _can_play_hive_switch_sfx() -> bool:
	var now_ms: int = Time.get_ticks_msec()
	var cutoff_ms: int = now_ms - HIVE_SWITCH_SFX_LIMIT_WINDOW_MS
	for i in range(_hive_switch_sfx_played_ms.size() - 1, -1, -1):
		if int(_hive_switch_sfx_played_ms[i]) < cutoff_ms:
			_hive_switch_sfx_played_ms.remove_at(i)
	if _hive_switch_sfx_played_ms.size() >= HIVE_SWITCH_SFX_LIMIT_COUNT:
		return false
	_hive_switch_sfx_played_ms.append(now_ms)
	return true

func _play_lose_hive_sfx() -> void:
	if not _is_game_sfx_enabled():
		return
	if _lose_hive_sfx_stream == null:
		_lose_hive_sfx_stream = load(LOSE_HIVE_SOUND_PATH) as AudioStream
	if _lose_hive_sfx_stream == null:
		if SFLog.LOGGING_ENABLED:
			push_warning("LOSE_HIVE_SOUND_MISSING: " + LOSE_HIVE_SOUND_PATH)
		return
	var player := AudioStreamPlayer.new()
	player.name = "LoseHiveSfxPlayer"
	player.stream = _lose_hive_sfx_stream
	player.finished.connect(Callable(player, "queue_free"))
	add_child(player)
	player.play()

func _play_win_hive_sfx() -> void:
	if not _is_game_sfx_enabled():
		return
	if _win_hive_sfx_stream == null:
		_win_hive_sfx_stream = load(WIN_HIVE_SOUND_PATH) as AudioStream
	if _win_hive_sfx_stream == null:
		if SFLog.LOGGING_ENABLED:
			push_warning("WIN_HIVE_SOUND_MISSING: " + WIN_HIVE_SOUND_PATH)
		return
	var player := AudioStreamPlayer.new()
	player.name = "WinHiveSfxPlayer"
	player.stream = _win_hive_sfx_stream
	player.finished.connect(Callable(player, "queue_free"))
	add_child(player)
	var clip_duration: float = maxf(0.0, WIN_HIVE_SOUND_END_SEC - WIN_HIVE_SOUND_START_SEC)
	player.play(WIN_HIVE_SOUND_START_SEC)
	if clip_duration > 0.0:
		var timer: SceneTreeTimer = get_tree().create_timer(clip_duration)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(player):
				player.stop()
				player.queue_free()
		)

func _play_post_match_song(winner_id_in: int) -> void:
	if not _is_game_sfx_enabled():
		return
	var local_owner_id: int = _resolve_local_owner_id()
	if local_owner_id <= 0 or winner_id_in <= 0:
		return
	var song_path: String = WIN_SONG_PATH if winner_id_in == local_owner_id else _next_loss_song_path()
	var stream: AudioStream = load(song_path) as AudioStream
	if stream == null:
		if SFLog.LOGGING_ENABLED:
			push_warning("POST_MATCH_SONG_MISSING: " + song_path)
		return
	if _post_match_song_player == null or not is_instance_valid(_post_match_song_player):
		_post_match_song_player = AudioStreamPlayer.new()
		_post_match_song_player.name = "PostMatchSongPlayer"
		add_child(_post_match_song_player)
	_cancel_post_match_song_fade()
	_post_match_song_player.stop()
	_post_match_song_player.stream = stream
	_post_match_song_player.volume_db = 0.0
	_post_match_song_player.play()

func _next_loss_song_path() -> String:
	if LOSE_SONG_PATHS.is_empty():
		return ""
	var idx: int = _post_match_loss_song_index % LOSE_SONG_PATHS.size()
	_post_match_loss_song_index += 1
	return LOSE_SONG_PATHS[idx]

func _stop_post_match_song(fade_out: bool = true) -> void:
	if _post_match_song_player != null and is_instance_valid(_post_match_song_player):
		if fade_out:
			_cancel_post_match_song_fade()
			_post_match_song_fade_tween = _fade_out_audio_player(_post_match_song_player, POST_MATCH_SONG_FADE_OUT_SEC, false)
		else:
			_cancel_post_match_song_fade()
			_post_match_song_player.stop()
			_post_match_song_player.volume_db = 0.0

func _cancel_post_match_song_fade() -> void:
	if _post_match_song_fade_tween != null and is_instance_valid(_post_match_song_fade_tween):
		_post_match_song_fade_tween.kill()
	_post_match_song_fade_tween = null

func _fade_out_post_match_song_blocking() -> void:
	if _post_match_song_player == null or not is_instance_valid(_post_match_song_player):
		return
	if not _post_match_song_player.playing:
		return
	_cancel_post_match_song_fade()
	_post_match_song_fade_tween = _fade_out_audio_player(_post_match_song_player, POST_MATCH_SONG_FADE_OUT_SEC, false)
	if _post_match_song_fade_tween != null and is_instance_valid(_post_match_song_fade_tween):
		await _post_match_song_fade_tween.finished

func _fade_out_audio_player(player: AudioStreamPlayer, fade_sec: float, free_after: bool) -> Tween:
	if player == null or not is_instance_valid(player):
		return null
	if not player.playing:
		if free_after and is_instance_valid(player):
			player.queue_free()
		return null
	var fade_duration: float = maxf(0.0, fade_sec)
	if fade_duration <= 0.0:
		player.stop()
		player.volume_db = 0.0
		if free_after and is_instance_valid(player):
			player.queue_free()
		return null
	var tween: Tween = player.create_tween()
	tween.tween_property(player, "volume_db", POST_MATCH_AUDIO_FADE_OUT_DB, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if not is_instance_valid(player):
			return
		player.stop()
		player.volume_db = 0.0
		if free_after:
			player.queue_free()
	)
	return tween

func _configure_vs_pvp_runtime() -> void:
	_vs_pvp_runtime = get_node_or_null("/root/VsPvpRuntime")
	if _vs_pvp_runtime == null or not _vs_pvp_runtime.has_method("configure_from_tree"):
		return
	var tree: SceneTree = get_tree()
	var roster: Array = OpsState.match_roster if OpsState != null else []
	_vs_pvp_runtime.call("configure_from_tree", tree, roster)
	var publish_result_cb: Callable = Callable(self, "_on_vs_command_publish_result")
	if _vs_pvp_runtime.has_signal("command_publish_result") and not _vs_pvp_runtime.is_connected("command_publish_result", publish_result_cb):
		_vs_pvp_runtime.connect("command_publish_result", publish_result_cb)
	_sync_active_player_from_vs_runtime()

func _sync_active_player_from_vs_runtime() -> void:
	if _vs_pvp_runtime == null:
		return
	if _vs_pvp_runtime.has_method("is_active") and bool(_vs_pvp_runtime.call("is_active")):
		var local_seat: int = 1
		if _vs_pvp_runtime.has_method("get_local_seat"):
			local_seat = clampi(int(_vs_pvp_runtime.call("get_local_seat")), 1, 4)
		if active_player_id != local_seat:
			active_player_id = local_seat
			SFLog.info("PVP_ACTIVE_PLAYER_SYNC", {"local_seat": local_seat})

func _bind_app_lifecycle() -> void:
	_app_lifecycle = get_node_or_null("/root/AppLifecycle")
	if _app_lifecycle == null:
		return
	var background_callable := Callable(self, "_on_app_backgrounded")
	if _app_lifecycle.has_signal("app_backgrounded") and not _app_lifecycle.is_connected("app_backgrounded", background_callable):
		_app_lifecycle.connect("app_backgrounded", background_callable)
	var foreground_callable := Callable(self, "_on_app_foregrounded")
	if _app_lifecycle.has_signal("app_foregrounded") and not _app_lifecycle.is_connected("app_foregrounded", foreground_callable):
		_app_lifecycle.connect("app_foregrounded", foreground_callable)

func _on_app_backgrounded(reason: String, paused_at_msec: int, _paused_at_unix: int) -> void:
	if not _should_local_lifecycle_pause_match():
		SFLog.info("APP_LIFECYCLE_LOCAL_PAUSE_SKIPPED", {
			"reason": reason,
			"pvp_active": _is_pvp_runtime_active(),
			"match_started": _match_started,
			"phase": int(OpsState.match_phase) if OpsState != null else -1
		})
		return
	_lifecycle_local_pause_active = true
	_lifecycle_local_pause_sim_was_running = bool(sim_runner.running)
	_lifecycle_local_pause_reason = reason
	if OpsState != null and OpsState.has_method("pause_match_clock"):
		OpsState.call("pause_match_clock", "app_background:%s" % reason, paused_at_msec)
	if sim_runner != null and sim_runner.running:
		sim_runner.set_running(false, "app_background")
		sim_runner.log_pause_snapshot("app_background")
	SFLog.info("APP_LIFECYCLE_LOCAL_PAUSE", {
		"reason": reason,
		"paused_at_msec": paused_at_msec,
		"sim_was_running": _lifecycle_local_pause_sim_was_running,
		"mode": _current_vs_mode()
	})

func _on_app_foregrounded(reason: String, _elapsed_msec: int, _resumed_at_unix: int) -> void:
	if not _lifecycle_local_pause_active:
		return
	var resume_allowed := _can_resume_after_lifecycle_pause()
	var expiry_snapshot: Dictionary = _async_submission_expiry_snapshot()
	if bool(expiry_snapshot.get("expired", false)):
		_expire_local_async_submission(expiry_snapshot, reason)
		_clear_lifecycle_local_pause_state()
		return
	if OpsState != null and OpsState.has_method("resume_match_clock"):
		OpsState.call("resume_match_clock", "app_foreground:%s" % reason, Time.get_ticks_msec())
	if resume_allowed and _lifecycle_local_pause_sim_was_running and sim_runner != null and not sim_runner.running:
		sim_runner.set_running(true, "app_foreground")
		sim_runner.log_pause_snapshot("app_foreground")
	SFLog.info("APP_LIFECYCLE_LOCAL_RESUME", {
		"reason": reason,
		"pause_reason": _lifecycle_local_pause_reason,
		"resume_allowed": resume_allowed,
		"sim_was_running": _lifecycle_local_pause_sim_was_running,
		"mode": _current_vs_mode()
	})
	_clear_lifecycle_local_pause_state()

func _clear_lifecycle_local_pause_state() -> void:
	_lifecycle_local_pause_active = false
	_lifecycle_local_pause_sim_was_running = false
	_lifecycle_local_pause_reason = ""

func _should_local_lifecycle_pause_match() -> bool:
	if OpsState == null or sim_runner == null:
		return false
	if _is_pvp_runtime_active():
		return false
	if not _match_started:
		return false
	if not bool(sim_runner.running):
		return false
	if OpsState.match_phase != OpsState.MatchPhase.RUNNING:
		return false
	if OpsState.is_ending_or_ended():
		return false
	return true

func _can_resume_after_lifecycle_pause() -> bool:
	if OpsState == null or sim_runner == null:
		return false
	if _is_pvp_runtime_active():
		return false
	if not _match_started:
		return false
	if OpsState.match_phase != OpsState.MatchPhase.RUNNING:
		return false
	if OpsState.is_ending_or_ended():
		return false
	return true

func _is_pvp_runtime_active() -> bool:
	return _vs_pvp_runtime != null and _vs_pvp_runtime.has_method("is_active") and bool(_vs_pvp_runtime.call("is_active"))

func _async_submission_expiry_snapshot(now_unix: int = -1) -> Dictionary:
	var tree: SceneTree = get_tree()
	if tree == null:
		return {"expired": false, "reason": "no_tree"}
	var mode: String = _current_vs_mode()
	var has_hive_tournament_runtime: bool = not str(tree.get_meta("hive_tournament_round_id", "")).strip_edges().is_empty()
	if not _is_async_runtime_mode(mode) and not has_hive_tournament_runtime:
		return {"expired": false, "reason": "not_async_runtime", "mode": mode}
	var resolved_now_unix: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var deadlines: Array[Dictionary] = []
	_append_submission_deadline(deadlines, "vs_window", int(tree.get_meta(TREE_META_VS_WINDOW_DEADLINE_UNIX, 0)))
	_append_submission_deadline(deadlines, "hive_tournament", int(tree.get_meta(TREE_META_HIVE_TOURNAMENT_DEADLINE_UNIX, 0)))
	var contest_id: String = str(tree.get_meta(TREE_META_CONTEST_ID, "")).strip_edges()
	if not contest_id.is_empty():
		var contest_state: Node = get_node_or_null("/root/ContestState")
		if contest_state != null and contest_state.has_method("get_contest"):
			var contest: Variant = contest_state.call("get_contest", contest_id)
			_append_submission_deadline(deadlines, "contest_end", int(_variant_dict_or_object_get(contest, "end_ts", 0)))
	if deadlines.is_empty():
		return {
			"expired": false,
			"reason": "no_deadline",
			"mode": mode,
			"contest_id": contest_id
		}
	deadlines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("deadline_unix", 0)) < int(b.get("deadline_unix", 0))
	)
	var selected: Dictionary = deadlines[0]
	var deadline_unix: int = int(selected.get("deadline_unix", 0))
	return {
		"expired": resolved_now_unix >= deadline_unix,
		"reason": "expired" if resolved_now_unix >= deadline_unix else "open",
		"source": str(selected.get("source", "")),
		"deadline_unix": deadline_unix,
		"now_unix": resolved_now_unix,
		"mode": mode,
		"contest_id": contest_id
	}

func _append_submission_deadline(deadlines: Array[Dictionary], source: String, deadline_unix: int) -> void:
	if deadline_unix <= 0:
		return
	deadlines.append({
		"source": source,
		"deadline_unix": deadline_unix
	})

func _expire_local_async_submission(expiry_snapshot: Dictionary, foreground_reason: String) -> void:
	if sim_runner != null and sim_runner.running:
		sim_runner.set_running(false, "app_foreground_contest_expired")
	if OpsState != null and OpsState.has_method("begin_match_end") and int(OpsState.match_phase) == int(OpsState.MatchPhase.RUNNING):
		OpsState.call("begin_match_end", 0, LIFECYCLE_CONTEST_EXPIRED_REASON, 0)
		if OpsState.has_method("finalize_match_end"):
			OpsState.call("finalize_match_end")
	SFLog.warn("APP_LIFECYCLE_ASYNC_SUBMISSION_EXPIRED", {
		"foreground_reason": foreground_reason,
		"pause_reason": _lifecycle_local_pause_reason,
		"expiry": expiry_snapshot
	})
	if sim_runner != null:
		sim_runner.log_pause_snapshot("app_foreground_contest_expired")
	if not _match_end_handled:
		_on_match_ended(0, LIFECYCLE_CONTEST_EXPIRED_REASON)

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

func _configure_special_victory_mode() -> void:
	if OpsState == null or not OpsState.has_method("set_victory_mode"):
		return
	var tree: SceneTree = get_tree()
	var vs_mode: String = ""
	if tree != null and tree.has_meta(TREE_META_VS_MODE):
		vs_mode = str(tree.get_meta(TREE_META_VS_MODE, "")).strip_edges().to_upper()
	var is_capture_flag: bool = _is_capture_flag_vs_mode(vs_mode)
	if not is_capture_flag:
		OpsState.sim_mutate("Arena._configure_special_victory_mode", func() -> void:
			OpsState.call("set_victory_mode", "conquest", {})
		)
		return
	var hidden_ctf: bool = vs_mode == VS_MODE_HIDDEN_CAPTURE_FLAG
	var options: Dictionary = {
		"hidden_flag": hidden_ctf,
		"fog_of_war_enabled": _tree_meta_bool("ctf_fog_of_war_enabled", false),
		"flag_move_count_max": maxi(0, int(_tree_meta_value("ctf_flag_move_count_max", 0))),
		"flag_move_reveals": true if hidden_ctf else _tree_meta_bool("ctf_flag_move_reveals", true),
		"flag_move_production_lock_sec": maxf(0.0, float(_tree_meta_value("ctf_flag_move_production_lock_sec", 0.0))),
		"flag_selection_mode": "player_select" if hidden_ctf else str(_tree_meta_value("ctf_flag_selection_mode", "weighted")).strip_edges().to_lower(),
		"flag_selection_player_select_pct": 100 if hidden_ctf else clampi(int(_tree_meta_value("ctf_player_select_pct", CTF_PLAYER_SELECT_PCT_DEFAULT)), 0, 100),
		"flag_selection_random_mirrored": _tree_meta_bool("ctf_randomize_flag_hive", true),
		"flag_selection_owner_id": _resolve_local_owner_id(),
		"flag_hives": {} if hidden_ctf else _tree_meta_value("ctf_flag_hives", current_map_data.get("ctf_flag_hives", {})),
		"map_data": current_map_data.duplicate(true)
	}
	if tree != null and tree.has_meta("ctf_hidden_flag"):
		options["hidden_flag"] = _tree_meta_bool("ctf_hidden_flag", bool(options.get("hidden_flag", false)))
	OpsState.sim_mutate("Arena._configure_special_victory_mode", func() -> void:
		OpsState.call("configure_capture_flag_mode", options)
	)

func _is_capture_flag_vs_mode(mode: String) -> bool:
	var clean_mode: String = mode.strip_edges().to_upper()
	return clean_mode == VS_MODE_CAPTURE_FLAG or clean_mode == VS_MODE_HIDDEN_CAPTURE_FLAG

func _tree_meta_value(key: String, fallback: Variant = null) -> Variant:
	var tree: SceneTree = get_tree()
	if tree == null or not tree.has_meta(key):
		return fallback
	return tree.get_meta(key, fallback)

func _tree_meta_bool(key: String, fallback: bool) -> bool:
	return bool(_tree_meta_value(key, fallback))

func _pump_vs_pvp_runtime(delta: float) -> void:
	if _vs_pvp_runtime == null or not _vs_pvp_runtime.has_method("is_active"):
		return
	if not bool(_vs_pvp_runtime.call("is_active")):
		return
	_sync_active_player_from_vs_runtime()
	if _vs_pvp_runtime.has_method("tick"):
		_vs_pvp_runtime.call("tick", delta)
	if _handle_vs_recovery_state():
		return
	if not _vs_pvp_runtime.has_method("consume_remote_commands"):
		return
	var st: GameState = OpsState.get_state() if OpsState != null else null
	var target_tick: int = int(st.tick) + 1 if st != null else -1
	var commands_any: Variant = _vs_pvp_runtime.call("consume_remote_commands", target_tick)
	if typeof(commands_any) != TYPE_ARRAY:
		return
	_apply_remote_pvp_commands(commands_any as Array)

func _maybe_publish_spectator_snapshot(delta: float) -> void:
	if _vs_pvp_runtime == null or not _vs_pvp_runtime.has_method("is_active"):
		_spectator_snapshot_accum = 0.0
		return
	if not bool(_vs_pvp_runtime.call("is_active")):
		_spectator_snapshot_accum = 0.0
		return
	if not _vs_pvp_runtime.has_method("publish_spectator_snapshot_async"):
		return
	if _vs_pvp_runtime.has_method("get_role") and str(_vs_pvp_runtime.call("get_role")).strip_edges().to_lower() != "host":
		return
	if OpsState == null or OpsState.match_phase != OpsState.MatchPhase.RUNNING:
		return
	if _match_telemetry_collector == null or not _match_telemetry_collector.has_method("build_live_replay_snapshot"):
		return
	var st: GameState = OpsState.get_state()
	if st == null:
		return
	_spectator_snapshot_accum += maxf(0.0, delta)
	if _spectator_snapshot_accum < SPECTATOR_SNAPSHOT_INTERVAL_SEC:
		return
	_spectator_snapshot_accum = 0.0
	var snapshot: Dictionary = _match_telemetry_collector.call("build_live_replay_snapshot", Time.get_ticks_msec(), st) as Dictionary
	if snapshot.is_empty():
		return
	_vs_pvp_runtime.call("publish_spectator_snapshot_async", snapshot)

func _handle_vs_recovery_state() -> bool:
	if _vs_pvp_runtime == null:
		return false
	var recovery_state: String = "running"
	if _vs_pvp_runtime.has_method("get_recovery_state"):
		recovery_state = str(_vs_pvp_runtime.call("get_recovery_state"))
	var peer_blocked: bool = false
	if _vs_pvp_runtime.has_method("is_peer_desync_or_lagging"):
		peer_blocked = bool(_vs_pvp_runtime.call("is_peer_desync_or_lagging"))
	if recovery_state == "running" and not peer_blocked:
		return false
	var reason: String = "peer_desync_or_lagging"
	if _vs_pvp_runtime.has_method("get_peer_desync_or_lagging_reason"):
		reason = str(_vs_pvp_runtime.call("get_peer_desync_or_lagging_reason"))
	if sim_runner != null and bool(sim_runner.running):
		sim_runner.set_running(false, reason)
		sim_runner.log_pause_snapshot(reason)
	if recovery_state == "desync_recovery":
		_show_capture_flag_toast("Connection unstable. Resyncing match...", 1800.0)
		_attempt_vs_desync_recovery()
		return true
	if recovery_state == "desync_ended":
		_show_capture_flag_toast("Connection unstable. Match ended.", 2200.0)
		if OpsState != null and OpsState.has_method("begin_match_end") and int(OpsState.match_phase) == int(OpsState.MatchPhase.RUNNING):
			OpsState.call("begin_match_end", 0, "desync_failure", 0)
		return true
	if peer_blocked:
		_show_capture_flag_toast("Connection unstable. Waiting for opponent...", 1400.0)
		return true
	return false

func _attempt_vs_desync_recovery() -> void:
	if _vs_pvp_runtime == null or not _vs_pvp_runtime.has_method("build_desync_recovery_plan"):
		return
	var plan_any: Variant = _vs_pvp_runtime.call("build_desync_recovery_plan")
	if typeof(plan_any) != TYPE_DICTIONARY:
		return
	var plan: Dictionary = plan_any as Dictionary
	if not bool(plan.get("ok", false)):
		if _vs_pvp_runtime.has_method("mark_desync_unrecoverable"):
			_vs_pvp_runtime.call("mark_desync_unrecoverable", str(plan.get("reason", "recovery_plan_failed")), plan)
		return
	var snapshot_any: Variant = plan.get("snapshot", {})
	if typeof(snapshot_any) != TYPE_DICTIONARY:
		if _vs_pvp_runtime.has_method("mark_desync_unrecoverable"):
			_vs_pvp_runtime.call("mark_desync_unrecoverable", "snapshot_missing", plan)
		return
	if OpsState == null or not OpsState.has_method("restore_authority_snapshot"):
		if _vs_pvp_runtime.has_method("mark_desync_unrecoverable"):
			_vs_pvp_runtime.call("mark_desync_unrecoverable", "restore_api_missing", plan)
		return
	var restored: bool = bool(OpsState.call("restore_authority_snapshot", snapshot_any as Dictionary))
	if not restored:
		if _vs_pvp_runtime.has_method("mark_desync_unrecoverable"):
			_vs_pvp_runtime.call("mark_desync_unrecoverable", "snapshot_restore_failed", plan)
		return
	var commands_any: Variant = plan.get("commands", [])
	var commands: Array = commands_any as Array if typeof(commands_any) == TYPE_ARRAY else []
	_apply_remote_pvp_commands(commands)
	var recovered_hash: String = ""
	if OpsState.has_method("get_contract_state_hash"):
		recovered_hash = str(OpsState.call("get_contract_state_hash"))
	var recovered_tick: int = -1
	if OpsState.has_method("get_state"):
		var recovered_state: GameState = OpsState.call("get_state") as GameState
		if recovered_state != null:
			recovered_tick = int(recovered_state.tick)
	if _vs_pvp_runtime.has_method("complete_desync_recovery"):
		var result_any: Variant = _vs_pvp_runtime.call("complete_desync_recovery", recovered_tick, recovered_hash, commands.size())
		if typeof(result_any) == TYPE_DICTIONARY:
			var result: Dictionary = result_any as Dictionary
			if bool(result.get("recovered", false)):
				if sim_runner != null:
					sim_runner.set_running(true, "desync_recovery_success")
				mark_render_dirty("vs_desync_recovered")
			elif bool(result.get("ended", false)) and OpsState != null and OpsState.has_method("begin_match_end") and int(OpsState.match_phase) == int(OpsState.MatchPhase.RUNNING):
				OpsState.call("begin_match_end", 0, "desync_failure", 0)

func _apply_remote_pvp_commands(commands: Array) -> void:
	if commands == null or commands.is_empty():
		return
	var st: GameState = OpsState.get_state() if OpsState != null else null
	if st == null:
		return
	var remote_seat: int = 2
	if _vs_pvp_runtime != null and _vs_pvp_runtime.has_method("get_remote_seat"):
		remote_seat = clampi(int(_vs_pvp_runtime.call("get_remote_seat")), 1, 4)
	var local_seat: int = 1
	if _vs_pvp_runtime != null and _vs_pvp_runtime.has_method("get_local_seat"):
		local_seat = clampi(int(_vs_pvp_runtime.call("get_local_seat")), 1, 4)
	for cmd_any in commands:
		if typeof(cmd_any) != TYPE_DICTIONARY:
			continue
		var cmd: Dictionary = cmd_any as Dictionary
		var kind: String = str(cmd.get("kind", "")).strip_edges().to_lower()
		match kind:
			"lane_intent":
				var src: int = int(cmd.get("src", -1))
				var dst: int = int(cmd.get("dst", -1))
				var intent: String = str(cmd.get("intent", "")).strip_edges().to_lower()
				if src <= 0 or dst <= 0:
					continue
				if intent != "attack" and intent != "feed" and intent != "swarm" and intent != "none":
					continue
				var src_hive: HiveData = st.find_hive_by_id(src)
				if src_hive == null:
					continue
				var src_owner: int = int(src_hive.owner_id)
				var sent_owner: int = int(cmd.get("src_owner", src_owner))
				var sender_seat: int = int(cmd.get("sender_seat", sent_owner))
				if not (sender_seat == local_seat or sender_seat == remote_seat):
					continue
				if src_owner != sender_seat or sent_owner != src_owner:
					_record_vs_stale_ownership_reject(cmd, "lane_intent", "source_owner_mismatch", src, sender_seat, src_owner)
					continue
				OpsState.with_remote_replication_apply(func() -> void:
					OpsState.apply_lane_intent(src, dst, intent)
				)
				mark_render_dirty("vs_scheduled_lane_intent")
			"lane_retract":
				var from_id: int = int(cmd.get("from_id", -1))
				var to_id: int = int(cmd.get("to_id", -1))
				var owner_id: int = int(cmd.get("owner_id", -1))
				if from_id <= 0 or to_id <= 0:
					continue
				var from_hive: HiveData = st.find_hive_by_id(from_id)
				if from_hive == null:
					continue
				var actual_owner: int = int(from_hive.owner_id)
				if owner_id <= 0:
					owner_id = actual_owner
				var sender_seat: int = int(cmd.get("sender_seat", owner_id))
				if not (sender_seat == local_seat or sender_seat == remote_seat):
					continue
				if owner_id != sender_seat or actual_owner != sender_seat:
					_record_vs_stale_ownership_reject(cmd, "lane_retract", "source_owner_mismatch", from_id, sender_seat, actual_owner)
					continue
				OpsState.with_remote_replication_apply(func() -> void:
					OpsState.retract_lane(from_id, to_id, owner_id)
				)
				mark_render_dirty("vs_scheduled_lane_retract")
			"barracks_route":
				var barracks_id: int = int(cmd.get("barracks_id", -1))
				var route_any: Variant = cmd.get("route_hive_ids", [])
				var route: Array = route_any as Array if typeof(route_any) == TYPE_ARRAY else []
				var owner_for_route: int = int(cmd.get("owner_id", -1))
				if barracks_id <= 0:
					continue
				if owner_for_route <= 0:
					owner_for_route = remote_seat
				var sender_seat: int = int(cmd.get("sender_seat", owner_for_route))
				if not (sender_seat == local_seat or sender_seat == remote_seat):
					continue
				if owner_for_route != sender_seat:
					_record_vs_stale_ownership_reject(cmd, "barracks_route", "owner_mismatch", barracks_id, sender_seat, owner_for_route)
					continue
				OpsState.with_remote_replication_apply(func() -> void:
					OpsState.request_barracks_route(barracks_id, route, owner_for_route)
				)
				mark_render_dirty("vs_scheduled_barracks_route")
			"buff_activate":
				_execute_canonical_buff_activation(cmd)
			_:
				continue

func _record_vs_stale_ownership_reject(command: Dictionary, kind: String, reason: String, source_id: int, expected_owner: int, actual_owner: int) -> void:
	if _vs_pvp_runtime == null or not _vs_pvp_runtime.has_method("record_stale_ownership_reject"):
		return
	var st: GameState = OpsState.get_state() if OpsState != null else null
	_vs_pvp_runtime.call("record_stale_ownership_reject", {
		"kind": kind,
		"reason": reason,
		"issued_tick": int(command.get("issued_tick", -1)),
		"execute_tick": int(command.get("execute_tick", -1)),
		"arrival_tick": int(st.tick) if st != null else -1,
		"apply_tick": int(st.tick) + 1 if st != null else -1,
		"source_id": int(source_id),
		"expected_owner": int(expected_owner),
		"actual_owner": int(actual_owner),
		"command_id": str(command.get("command_id", "")),
		"command_seq": int(command.get("command_seq", -1)),
		"sender_seat": int(command.get("sender_seat", 0)),
		"sender_uid": str(command.get("sender_uid", ""))
	})

func _ensure_prematch_ui() -> void:
	var ui_root: Node = null
	var overlay: Control = _prematch_overlay if _prematch_overlay != null and is_instance_valid(_prematch_overlay) else null
	if overlay != null:
		ui_root = overlay.get_parent()
	if ui_root == null:
		ui_root = get_node_or_null(SHELL_HUD_ROOT_PATH)
	if ui_root == null:
		var hud_layer: CanvasLayer = get_node_or_null(SHELL_HUD_LAYER_PATH) as CanvasLayer
		if hud_layer == null:
			hud_layer = _ensure_timer_layer()
		if hud_layer != null:
			ui_root = hud_layer.get_node_or_null("HUDRoot")
			if ui_root == null:
				ui_root = hud_layer
	if ui_root == null:
		ui_root = get_node_or_null("../UI")
	if ui_root == null:
		return
	if overlay == null:
		overlay = ui_root.get_node_or_null("PreMatchOverlay") as Control
	if overlay == null:
		var scene: Node = get_tree().current_scene
		if scene != null:
			var found: Node = scene.find_child("PreMatchOverlay", true, false)
			if found is Control:
				overlay = found as Control
	if overlay == null:
		overlay = Control.new()
		overlay.name = "PreMatchOverlay"
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_root.add_child(overlay)
	elif overlay.get_parent() != ui_root:
		overlay.reparent(ui_root)
	_prematch_overlay = overlay
	_force_fullscreen_anchors(_prematch_overlay)
	_prematch_overlay.z_as_relative = false
	_prematch_overlay.z_index = 950
	_prematch_overlay.modulate = Color(1, 1, 1, 1)
	_prematch_overlay.self_modulate = Color(1, 1, 1, 1)
	var countdown := _prematch_overlay.get_node_or_null("CountdownLabel") as Label
	if countdown == null:
		countdown = Label.new()
		countdown.name = "CountdownLabel"
		countdown.set_script(COUNTDOWN_DEBUG_SCRIPT)
		countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		countdown.anchor_left = 0.0
		countdown.anchor_right = 1.0
		countdown.anchor_top = 0.0
		countdown.anchor_bottom = 1.0
		_prematch_overlay.add_child(countdown)
	_prematch_countdown_label = countdown
	_style_prematch_countdown_label()
	var records := _prematch_overlay.get_node_or_null("RecordsPanel") as Control
	if records == null:
		records = Control.new()
		records.name = "RecordsPanel"
		_prematch_overlay.add_child(records)
	records.mouse_filter = Control.MOUSE_FILTER_IGNORE
	records.anchor_left = 0.0
	records.anchor_right = 0.0
	records.anchor_top = 0.0
	records.anchor_bottom = 0.0
	records.z_as_relative = false
	records.z_index = 1000
	_layout_prematch_records_panel(records)

	var records_bg := records.get_node_or_null("RecordsBg") as Panel
	if records_bg == null:
		records_bg = Panel.new()
		records_bg.name = "RecordsBg"
		records.add_child(records_bg)
	records_bg.anchor_left = 0.0
	records_bg.anchor_right = 1.0
	records_bg.anchor_top = 0.0
	records_bg.anchor_bottom = 1.0
	records_bg.offset_left = 0.0
	records_bg.offset_top = 0.0
	records_bg.offset_right = 0.0
	records_bg.offset_bottom = 0.0
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.04, 0.08, 0.58)
	panel_style.border_color = Color(0.62, 0.70, 0.82, 0.92)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	records_bg.add_theme_stylebox_override("panel", panel_style)

	var records_vbox := records_bg.get_node_or_null("RecordsVBox") as VBoxContainer
	if records_vbox == null:
		var legacy_vbox := records.get_node_or_null("RecordsVBox") as VBoxContainer
		if legacy_vbox != null:
			legacy_vbox.reparent(records_bg)
			records_vbox = legacy_vbox
		else:
			records_vbox = VBoxContainer.new()
			records_vbox.name = "RecordsVBox"
			records_bg.add_child(records_vbox)
	records_vbox.anchor_left = 0.0
	records_vbox.anchor_right = 1.0
	records_vbox.anchor_top = 0.0
	records_vbox.anchor_bottom = 1.0
	records_vbox.offset_left = 10.0
	records_vbox.offset_top = 8.0
	records_vbox.offset_right = -10.0
	records_vbox.offset_bottom = -8.0
	records_vbox.add_theme_constant_override("separation", 2)
	var p1: Label = _ensure_prematch_record_label(records_vbox, "RecordP1")
	var p2: Label = _ensure_prematch_record_label(records_vbox, "RecordP2")
	var p3: Label = _ensure_prematch_record_label(records_vbox, "RecordP3")
	var p4: Label = _ensure_prematch_record_label(records_vbox, "RecordP4")
	var h2h: Label = _ensure_prematch_record_label(records_vbox, "RecordH2H")
	var teams: Label = _ensure_prematch_record_label(records_vbox, "RecordTeams")
	var team_arrows: Label = _ensure_prematch_record_label(records_vbox, "RecordTeamArrows")
	records_vbox.move_child(teams, 0)
	records_vbox.move_child(team_arrows, 1)
	_style_prematch_record_label(p1)
	_style_prematch_record_label(p2)
	_style_prematch_record_label(p3)
	_style_prematch_record_label(p4)
	_style_prematch_record_label(h2h)
	_style_prematch_team_label(teams)
	_style_prematch_team_arrow_label(team_arrows)
	var ctf_panel := _prematch_overlay.get_node_or_null("CaptureFlagPanel") as Panel
	if ctf_panel == null:
		ctf_panel = Panel.new()
		ctf_panel.name = "CaptureFlagPanel"
		_prematch_overlay.add_child(ctf_panel)
	ctf_panel.visible = false
	ctf_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctf_panel.z_as_relative = false
	ctf_panel.z_index = 1001
	var ctf_panel_style: StyleBoxFlat = StyleBoxFlat.new()
	ctf_panel_style.bg_color = Color(0.03, 0.05, 0.08, 0.84)
	ctf_panel_style.border_color = Color(0.90, 0.76, 0.24, 0.88)
	ctf_panel_style.border_width_left = 1
	ctf_panel_style.border_width_top = 1
	ctf_panel_style.border_width_right = 1
	ctf_panel_style.border_width_bottom = 1
	ctf_panel_style.corner_radius_top_left = 10
	ctf_panel_style.corner_radius_top_right = 10
	ctf_panel_style.corner_radius_bottom_left = 10
	ctf_panel_style.corner_radius_bottom_right = 10
	ctf_panel.add_theme_stylebox_override("panel", ctf_panel_style)
	var ctf_vbox := ctf_panel.get_node_or_null("VBox") as VBoxContainer
	if ctf_vbox == null:
		ctf_vbox = VBoxContainer.new()
		ctf_vbox.name = "VBox"
		ctf_panel.add_child(ctf_vbox)
	ctf_vbox.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	ctf_vbox.offset_left = 12.0
	ctf_vbox.offset_top = 10.0
	ctf_vbox.offset_right = -12.0
	ctf_vbox.offset_bottom = -10.0
	ctf_vbox.add_theme_constant_override("separation", 6)
	var ctf_title := ctf_vbox.get_node_or_null("Title") as Label
	if ctf_title == null:
		ctf_title = Label.new()
		ctf_title.name = "Title"
		ctf_vbox.add_child(ctf_title)
	var ctf_body := ctf_vbox.get_node_or_null("Body") as Label
	if ctf_body == null:
		ctf_body = Label.new()
		ctf_body.name = "Body"
		ctf_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ctf_vbox.add_child(ctf_body)
	ctf_title.add_theme_font_size_override("font_size", 21)
	ctf_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.38, 1.0))
	ctf_body.add_theme_font_size_override("font_size", 16)
	ctf_body.add_theme_color_override("font_color", Color(0.94, 0.96, 0.99, 1.0))
	_layout_capture_flag_instruction_panel(ctf_panel)
	_ensure_prematch_ad_surface()
	_prematch_records_panel = records
	_prematch_record_p1 = p1
	_prematch_record_p2 = p2
	_prematch_record_p3 = p3
	_prematch_record_p4 = p4
	_prematch_record_h2h = h2h
	_prematch_record_teams = teams
	_prematch_record_team_arrows = team_arrows
	_prematch_ctf_panel = ctf_panel
	_prematch_ctf_title = ctf_title
	_prematch_ctf_body = ctf_body
	_ensure_prematch_identity_card()
	if not _prematch_ui_bind_logged:
		_prematch_ui_bind_logged = true
		SFLog.info("PREMATCH_UI_BIND", {
			"overlay_path": _node_path_for_log(_prematch_overlay),
			"countdown_path": _node_path_for_log(_prematch_countdown_label),
			"records_path": _node_path_for_log(_prematch_records_panel),
			"inside_tree": _prematch_overlay.is_inside_tree()
		})
	_ensure_prematch_on_top()
	if not _prematch_ui_state_logged:
		_prematch_ui_state_logged = true
		_log_prematch_ui_state()

func _ensure_prematch_on_top() -> void:
	if _prematch_overlay == null:
		return
	var preferred_parent: Node = get_node_or_null(SHELL_HUD_ROOT_PATH)
	if preferred_parent == null:
		var hud: CanvasLayer = get_node_or_null(SHELL_HUD_LAYER_PATH) as CanvasLayer
		if hud == null:
			hud = _ensure_timer_layer()
		if hud != null:
			var hud_root: Node = hud.get_node_or_null("HUDRoot")
			if hud_root != null:
				preferred_parent = hud_root
			else:
				preferred_parent = hud
	if preferred_parent != null and _prematch_overlay.get_parent() != preferred_parent:
		_prematch_overlay.reparent(preferred_parent)
		_force_fullscreen_anchors(_prematch_overlay)
	if preferred_parent != null:
		preferred_parent.move_child(_prematch_overlay, preferred_parent.get_child_count() - 1)
	_prematch_overlay.z_as_relative = false
	_prematch_overlay.z_index = 2000
	_prematch_overlay.top_level = false

func _style_prematch_countdown_label() -> void:
	if _prematch_countdown_label == null:
		return
	_prematch_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prematch_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prematch_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prematch_countdown_label.anchor_left = 0.0
	_prematch_countdown_label.anchor_top = 0.0
	_prematch_countdown_label.anchor_right = 1.0
	_prematch_countdown_label.anchor_bottom = 1.0
	_prematch_countdown_label.offset_left = 0.0
	_prematch_countdown_label.offset_top = 0.0
	_prematch_countdown_label.offset_right = 0.0
	_prematch_countdown_label.offset_bottom = 0.0
	_prematch_countdown_label.z_as_relative = false
	_prematch_countdown_label.z_index = 2200
	_prematch_countdown_label.add_theme_color_override("font_color", _local_countdown_color())
	_prematch_countdown_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_prematch_countdown_label.add_theme_constant_override("outline_size", 10)
	_prematch_countdown_label.add_theme_font_size_override("font_size", 220)

func _local_countdown_color() -> Color:
	var seat: int = clampi(active_player_id, 1, 4)
	var color: Color = _prematch_identity_card_color_for_seat(seat)
	color.a = 1.0
	return color

func _ensure_prematch_identity_card() -> void:
	if _prematch_overlay == null:
		return
	var card: Panel = _prematch_overlay.get_node_or_null("IdentityCard") as Panel
	if card == null:
		card = Panel.new()
		card.name = "IdentityCard"
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.z_as_relative = false
		card.z_index = 1002
		_prematch_overlay.add_child(card)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.035, 0.84)
	style.border_color = Color(0.94, 0.88, 0.62, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	card.clip_contents = true
	_prematch_identity_card = card

	var top_wash: ColorRect = _ensure_identity_color_rect(card, "P1Wash")
	top_wash.color = Color(1.0, 0.78, 0.12, 0.14)
	var bottom_wash: ColorRect = _ensure_identity_color_rect(card, "P2Wash")
	bottom_wash.color = Color(1.0, 0.12, 0.10, 0.14)
	var divider: ColorRect = _ensure_identity_color_rect(card, "DiagonalDivider")
	divider.color = Color(1.0, 0.94, 0.78, 0.86)
	var quadrant_v: ColorRect = _ensure_identity_color_rect(card, "QuadrantDividerV")
	quadrant_v.color = Color(1.0, 0.94, 0.78, 0.62)
	var quadrant_h: ColorRect = _ensure_identity_color_rect(card, "QuadrantDividerH")
	quadrant_h.color = Color(1.0, 0.94, 0.78, 0.62)
	var team_vs_streak: ColorRect = _ensure_identity_color_rect(card, "TeamVsStreak")
	team_vs_streak.color = Color(0.0, 0.0, 0.0, 0.82)
	var p1_streak: ColorRect = _ensure_identity_color_rect(card, "P1Accent")
	p1_streak.color = Color(1.0, 0.78, 0.08, 0.95)
	var p2_streak: ColorRect = _ensure_identity_color_rect(card, "P2Accent")
	p2_streak.color = Color(1.0, 0.16, 0.12, 0.95)
	var p3_color: Color = TeamVisuals.owner_color(3)
	var p4_color: Color = TeamVisuals.owner_color(4)
	var p3_wash: ColorRect = _ensure_identity_color_rect(card, "P3Wash")
	p3_wash.color = Color(p3_color.r, p3_color.g, p3_color.b, 0.14)
	var p3_streak: ColorRect = _ensure_identity_color_rect(card, "P3Accent")
	p3_streak.color = Color(p3_color.r, p3_color.g, p3_color.b, 0.95)
	var p4_wash: ColorRect = _ensure_identity_color_rect(card, "P4Wash")
	p4_wash.color = Color(p4_color.r, p4_color.g, p4_color.b, 0.14)
	var p4_streak: ColorRect = _ensure_identity_color_rect(card, "P4Accent")
	p4_streak.color = Color(p4_color.r, p4_color.g, p4_color.b, 0.95)

	var p1_label: Label = _ensure_identity_label(card, "P1Label")
	var p1_name: Label = _ensure_identity_label(card, "P1Name")
	var p2_label: Label = _ensure_identity_label(card, "P2Label")
	var p2_name: Label = _ensure_identity_label(card, "P2Name")
	var p3_label: Label = _ensure_identity_label(card, "P3Label")
	var p3_name: Label = _ensure_identity_label(card, "P3Name")
	var p4_label: Label = _ensure_identity_label(card, "P4Label")
	var p4_name: Label = _ensure_identity_label(card, "P4Name")
	var vs_label: Label = _ensure_identity_label(card, "TeamVsLabel")
	_style_identity_small_label(p1_label)
	_style_identity_small_label(p2_label)
	_style_identity_small_label(p3_label)
	_style_identity_small_label(p4_label)
	_style_identity_name_label(p1_name, HORIZONTAL_ALIGNMENT_LEFT)
	_style_identity_name_label(p2_name, HORIZONTAL_ALIGNMENT_RIGHT)
	_style_identity_name_label(p3_name, HORIZONTAL_ALIGNMENT_LEFT)
	_style_identity_name_label(p4_name, HORIZONTAL_ALIGNMENT_LEFT)
	_style_identity_vs_label(vs_label)
	_layout_prematch_identity_card()

func _ensure_identity_color_rect(parent: Control, node_name: String) -> ColorRect:
	var rect: ColorRect = parent.get_node_or_null(node_name) as ColorRect
	if rect == null:
		rect = ColorRect.new()
		rect.name = node_name
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(rect)
	return rect

func _ensure_identity_label(parent: Control, node_name: String) -> Label:
	var label: Label = parent.get_node_or_null(node_name) as Label
	if label == null:
		label = Label.new()
		label.name = node_name
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		parent.add_child(label)
	return label

func _style_identity_small_label(label: Label) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 2)

func _style_identity_name_label(label: Label, align: HorizontalAlignment) -> void:
	if label == null:
		return
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 3)

func _style_identity_vs_label(label: Label) -> void:
	if label == null:
		return
	label.text = "VS."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 3)

func _layout_prematch_identity_card() -> void:
	if _prematch_identity_card == null:
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var top_inset: float = _ui_top_inset_px()
	var card_width: float = clampf(viewport_rect.size.x * 0.76, 360.0, 760.0)
	var team_2v2: bool = _prematch_identity_uses_team_2v2()
	var quadrant_4p: bool = _prematch_identity_uses_quadrant_4p()
	var stacked_3p: bool = _prematch_identity_uses_stacked_3p()
	var card_height: float = clampf(viewport_rect.size.y * (0.24 if (quadrant_4p or team_2v2) else (0.22 if stacked_3p else 0.18)), 280.0 if (quadrant_4p or team_2v2) else (250.0 if stacked_3p else 210.0), 380.0 if (quadrant_4p or team_2v2) else (360.0 if stacked_3p else 300.0))
	var card_top: float = top_inset + maxf(24.0, viewport_rect.size.y * 0.08)
	_prematch_identity_card.position = Vector2((viewport_rect.size.x - card_width) * 0.5, card_top)
	_prematch_identity_card.size = Vector2(card_width, card_height)
	if team_2v2:
		_layout_prematch_identity_card_2v2(card_width, card_height)
		return
	if quadrant_4p:
		_layout_prematch_identity_card_4p(card_width, card_height)
		return
	if stacked_3p:
		_layout_prematch_identity_card_3p(card_width, card_height)
		return

	var p1_wash: ColorRect = _prematch_identity_card.get_node_or_null("P1Wash") as ColorRect
	var p2_wash: ColorRect = _prematch_identity_card.get_node_or_null("P2Wash") as ColorRect
	var p3_wash: ColorRect = _prematch_identity_card.get_node_or_null("P3Wash") as ColorRect
	var p4_wash: ColorRect = _prematch_identity_card.get_node_or_null("P4Wash") as ColorRect
	var divider: ColorRect = _prematch_identity_card.get_node_or_null("DiagonalDivider") as ColorRect
	var quadrant_v: ColorRect = _prematch_identity_card.get_node_or_null("QuadrantDividerV") as ColorRect
	var quadrant_h: ColorRect = _prematch_identity_card.get_node_or_null("QuadrantDividerH") as ColorRect
	_set_team_vs_visible(false)
	var p1_accent: ColorRect = _prematch_identity_card.get_node_or_null("P1Accent") as ColorRect
	var p2_accent: ColorRect = _prematch_identity_card.get_node_or_null("P2Accent") as ColorRect
	var p3_accent: ColorRect = _prematch_identity_card.get_node_or_null("P3Accent") as ColorRect
	var p4_accent: ColorRect = _prematch_identity_card.get_node_or_null("P4Accent") as ColorRect
	_set_identity_player_visible(3, false)
	_set_identity_player_visible(4, false)
	if quadrant_v != null:
		quadrant_v.visible = false
	if quadrant_h != null:
		quadrant_h.visible = false
	if p3_wash != null:
		p3_wash.visible = false
	if p3_accent != null:
		p3_accent.visible = false
	if p4_wash != null:
		p4_wash.visible = false
	if p4_accent != null:
		p4_accent.visible = false
	if p1_wash != null:
		p1_wash.visible = true
		p1_wash.position = Vector2.ZERO
		p1_wash.size = Vector2(card_width, card_height * 0.55)
	if p2_wash != null:
		p2_wash.visible = true
		p2_wash.position = Vector2(0.0, card_height * 0.45)
		p2_wash.size = Vector2(card_width, card_height * 0.55)
	if divider != null:
		divider.visible = true
		var diagonal_len: float = sqrt(card_width * card_width + card_height * card_height)
		divider.size = Vector2(diagonal_len, 3.0)
		divider.position = Vector2((card_width - diagonal_len) * 0.5, card_height * 0.5)
		divider.pivot_offset = Vector2(diagonal_len * 0.5, 1.5)
		divider.rotation = -atan2(card_height, card_width)
	if p1_accent != null:
		p1_accent.position = Vector2(24.0, 28.0)
		p1_accent.size = Vector2(card_width * 0.42, 5.0)
	if p2_accent != null:
		p2_accent.position = Vector2(card_width * 0.58, card_height - 34.0)
		p2_accent.size = Vector2(card_width * 0.36, 5.0)
	var p1_label: Label = _prematch_identity_card.get_node_or_null("P1Label") as Label
	var p1_name: Label = _prematch_identity_card.get_node_or_null("P1Name") as Label
	var p2_label: Label = _prematch_identity_card.get_node_or_null("P2Label") as Label
	var p2_name: Label = _prematch_identity_card.get_node_or_null("P2Name") as Label
	if p1_label != null:
		p1_label.visible = true
		p1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		p1_label.position = Vector2(28.0, 38.0)
		p1_label.size = Vector2(card_width * 0.48, 28.0)
	if p1_name != null:
		p1_name.visible = true
		p1_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		p1_name.position = Vector2(28.0, 66.0)
		p1_name.size = Vector2(card_width * 0.56, 54.0)
	if p2_label != null:
		p2_label.visible = true
		p2_label.position = Vector2(card_width * 0.48, card_height - 110.0)
		p2_label.size = Vector2(card_width * 0.48 - 28.0, 28.0)
		p2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if p2_name != null:
		p2_name.visible = true
		p2_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p2_name.position = Vector2(card_width * 0.38, card_height - 82.0)
		p2_name.size = Vector2(card_width * 0.58, 54.0)

func _layout_prematch_identity_card_3p(card_width: float, card_height: float) -> void:
	var divider: ColorRect = _prematch_identity_card.get_node_or_null("DiagonalDivider") as ColorRect
	var quadrant_v: ColorRect = _prematch_identity_card.get_node_or_null("QuadrantDividerV") as ColorRect
	var quadrant_h: ColorRect = _prematch_identity_card.get_node_or_null("QuadrantDividerH") as ColorRect
	_set_team_vs_visible(false)
	if divider != null:
		divider.visible = false
	if quadrant_v != null:
		quadrant_v.visible = false
	if quadrant_h != null:
		quadrant_h.visible = false
	_set_identity_player_visible(4, false)
	var p4_wash: ColorRect = _prematch_identity_card.get_node_or_null("P4Wash") as ColorRect
	var p4_accent: ColorRect = _prematch_identity_card.get_node_or_null("P4Accent") as ColorRect
	if p4_wash != null:
		p4_wash.visible = false
	if p4_accent != null:
		p4_accent.visible = false
	var row_height: float = card_height / 3.0
	for seat in range(1, 4):
		_set_identity_player_visible(seat, true)
		var wash: ColorRect = _prematch_identity_card.get_node_or_null("P%dWash" % seat) as ColorRect
		var accent: ColorRect = _prematch_identity_card.get_node_or_null("P%dAccent" % seat) as ColorRect
		var label: Label = _prematch_identity_card.get_node_or_null("P%dLabel" % seat) as Label
		var name_label: Label = _prematch_identity_card.get_node_or_null("P%dName" % seat) as Label
		var row_top: float = row_height * float(seat - 1)
		if wash != null:
			wash.visible = true
			wash.position = Vector2(0.0, row_top)
			wash.size = Vector2(card_width, row_height)
		if accent != null:
			accent.visible = true
			accent.position = Vector2(24.0, row_top + 16.0)
			accent.size = Vector2(card_width * 0.38, 5.0)
		if label != null:
			label.visible = true
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.position = Vector2(28.0, row_top + 25.0)
			label.size = Vector2(card_width * 0.32, 24.0)
		if name_label != null:
			name_label.visible = true
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			name_label.position = Vector2(card_width * 0.34, row_top + 22.0)
			name_label.size = Vector2(card_width * 0.58, row_height - 28.0)

func _layout_prematch_identity_card_2v2(card_width: float, card_height: float) -> void:
	var diagonal: ColorRect = _prematch_identity_card.get_node_or_null("DiagonalDivider") as ColorRect
	var quadrant_v: ColorRect = _prematch_identity_card.get_node_or_null("QuadrantDividerV") as ColorRect
	var quadrant_h: ColorRect = _prematch_identity_card.get_node_or_null("QuadrantDividerH") as ColorRect
	if diagonal != null:
		diagonal.visible = false
	if quadrant_v != null:
		quadrant_v.visible = true
		quadrant_v.position = Vector2((card_width - 3.0) * 0.5, 0.0)
		quadrant_v.size = Vector2(3.0, card_height)
		quadrant_v.rotation = 0.0
	if quadrant_h != null:
		quadrant_h.visible = true
		quadrant_h.position = Vector2(0.0, (card_height - 3.0) * 0.5)
		quadrant_h.size = Vector2(card_width, 3.0)
		quadrant_h.rotation = 0.0
	_set_team_vs_visible(true)
	var left_size: Vector2 = Vector2(card_width * 0.5, card_height * 0.5)
	var right_size: Vector2 = Vector2(card_width * 0.5, card_height * 0.5)
	for seat in range(1, 5):
		_set_identity_player_visible(seat, true)
		var quadrant_pos: Vector2 = Vector2.ZERO
		var quadrant_size: Vector2 = left_size
		if seat == 2:
			quadrant_pos = Vector2(0.0, left_size.y)
		elif seat == 3:
			quadrant_pos = Vector2(card_width * 0.5, 0.0)
			quadrant_size = right_size
		elif seat == 4:
			quadrant_pos = Vector2(card_width * 0.5, right_size.y)
			quadrant_size = right_size
		var wash: ColorRect = _prematch_identity_card.get_node_or_null("P%dWash" % seat) as ColorRect
		var accent: ColorRect = _prematch_identity_card.get_node_or_null("P%dAccent" % seat) as ColorRect
		var label: Label = _prematch_identity_card.get_node_or_null("P%dLabel" % seat) as Label
		var name_label: Label = _prematch_identity_card.get_node_or_null("P%dName" % seat) as Label
		if wash != null:
			wash.visible = true
			wash.position = quadrant_pos
			wash.size = quadrant_size
		if accent != null:
			accent.visible = true
			accent.position = quadrant_pos + Vector2(22.0, 20.0)
			accent.size = Vector2(quadrant_size.x * 0.58, 5.0)
		if label != null:
			label.visible = true
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.position = quadrant_pos + Vector2(24.0, 34.0)
			label.size = Vector2(quadrant_size.x - 48.0, 24.0)
		if name_label != null:
			name_label.visible = true
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			name_label.position = quadrant_pos + Vector2(24.0, 62.0)
			name_label.size = Vector2(quadrant_size.x - 48.0, quadrant_size.y - 74.0)
	var streak: ColorRect = _prematch_identity_card.get_node_or_null("TeamVsStreak") as ColorRect
	if streak != null:
		var left_width: float = card_width * 0.5
		var diagonal_len: float = sqrt(left_width * left_width + card_height * card_height)
		streak.size = Vector2(diagonal_len, 46.0)
		streak.position = Vector2((left_width - diagonal_len) * 0.5, (card_height - 46.0) * 0.5)
		streak.pivot_offset = Vector2(diagonal_len * 0.5, 23.0)
		streak.rotation = -atan2(card_height, left_width)
	var vs_label: Label = _prematch_identity_card.get_node_or_null("TeamVsLabel") as Label
	if vs_label != null:
		vs_label.position = Vector2((card_width * 0.25) - 54.0, (card_height * 0.5) - 28.0)
		vs_label.size = Vector2(108.0, 56.0)

func _layout_prematch_identity_card_4p(card_width: float, card_height: float) -> void:
	var diagonal: ColorRect = _prematch_identity_card.get_node_or_null("DiagonalDivider") as ColorRect
	var quadrant_v: ColorRect = _prematch_identity_card.get_node_or_null("QuadrantDividerV") as ColorRect
	var quadrant_h: ColorRect = _prematch_identity_card.get_node_or_null("QuadrantDividerH") as ColorRect
	_set_team_vs_visible(false)
	if diagonal != null:
		diagonal.visible = false
	if quadrant_v != null:
		quadrant_v.visible = true
		quadrant_v.position = Vector2((card_width - 3.0) * 0.5, 0.0)
		quadrant_v.size = Vector2(3.0, card_height)
		quadrant_v.rotation = 0.0
	if quadrant_h != null:
		quadrant_h.visible = true
		quadrant_h.position = Vector2(0.0, (card_height - 3.0) * 0.5)
		quadrant_h.size = Vector2(card_width, 3.0)
		quadrant_h.rotation = 0.0
	var quadrant_size: Vector2 = Vector2(card_width * 0.5, card_height * 0.5)
	for seat in range(1, 5):
		_set_identity_player_visible(seat, true)
		var col: int = (seat - 1) % 2
		var row: int = int((seat - 1) / 2)
		var quadrant_pos: Vector2 = Vector2(float(col) * quadrant_size.x, float(row) * quadrant_size.y)
		var wash: ColorRect = _prematch_identity_card.get_node_or_null("P%dWash" % seat) as ColorRect
		var accent: ColorRect = _prematch_identity_card.get_node_or_null("P%dAccent" % seat) as ColorRect
		var label: Label = _prematch_identity_card.get_node_or_null("P%dLabel" % seat) as Label
		var name_label: Label = _prematch_identity_card.get_node_or_null("P%dName" % seat) as Label
		if wash != null:
			wash.visible = true
			wash.position = quadrant_pos
			wash.size = quadrant_size
		if accent != null:
			accent.visible = true
			accent.position = quadrant_pos + Vector2(22.0, 20.0)
			accent.size = Vector2(quadrant_size.x * 0.58, 5.0)
		if label != null:
			label.visible = true
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.position = quadrant_pos + Vector2(24.0, 34.0)
			label.size = Vector2(quadrant_size.x - 48.0, 24.0)
		if name_label != null:
			name_label.visible = true
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			name_label.position = quadrant_pos + Vector2(24.0, 62.0)
			name_label.size = Vector2(quadrant_size.x - 48.0, quadrant_size.y - 74.0)

func _set_identity_player_visible(seat: int, visible: bool) -> void:
	var label: Label = _prematch_identity_card.get_node_or_null("P%dLabel" % seat) as Label
	var name_label: Label = _prematch_identity_card.get_node_or_null("P%dName" % seat) as Label
	if label != null:
		label.visible = visible
	if name_label != null:
		name_label.visible = visible

func _set_team_vs_visible(visible: bool) -> void:
	var streak: ColorRect = _prematch_identity_card.get_node_or_null("TeamVsStreak") as ColorRect
	var label: Label = _prematch_identity_card.get_node_or_null("TeamVsLabel") as Label
	if streak != null:
		streak.visible = visible
	if label != null:
		label.visible = visible

func _show_prematch_identity_card() -> void:
	_ensure_prematch_identity_card()
	if _prematch_identity_card == null:
		return
	if not _should_show_prematch_identity_flow():
		_prematch_identity_card.visible = false
		return
	_refresh_prematch_identity_card()
	_layout_prematch_identity_card()
	_prematch_identity_card.visible = true
	_prematch_identity_card.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _refresh_prematch_identity_card() -> void:
	if _prematch_identity_card == null:
		return
	var p1_data: Dictionary = _prematch_identity_player_data(1, "Swarm Father")
	var p2_data: Dictionary = _prematch_identity_player_data(2, "Mrs. SwarmDaddy")
	var p3_data: Dictionary = _prematch_identity_player_data(3, "Player 3")
	var p4_data: Dictionary = _prematch_identity_player_data(4, "Player 4")
	var p1_label: Label = _prematch_identity_card.get_node_or_null("P1Label") as Label
	var p1_name: Label = _prematch_identity_card.get_node_or_null("P1Name") as Label
	var p2_label: Label = _prematch_identity_card.get_node_or_null("P2Label") as Label
	var p2_name: Label = _prematch_identity_card.get_node_or_null("P2Name") as Label
	var p3_label: Label = _prematch_identity_card.get_node_or_null("P3Label") as Label
	var p3_name: Label = _prematch_identity_card.get_node_or_null("P3Name") as Label
	var p4_label: Label = _prematch_identity_card.get_node_or_null("P4Label") as Label
	var p4_name: Label = _prematch_identity_card.get_node_or_null("P4Name") as Label
	var p1_accent: ColorRect = _prematch_identity_card.get_node_or_null("P1Accent") as ColorRect
	var p2_accent: ColorRect = _prematch_identity_card.get_node_or_null("P2Accent") as ColorRect
	var p3_accent: ColorRect = _prematch_identity_card.get_node_or_null("P3Accent") as ColorRect
	var p4_accent: ColorRect = _prematch_identity_card.get_node_or_null("P4Accent") as ColorRect
	var p1_wash: ColorRect = _prematch_identity_card.get_node_or_null("P1Wash") as ColorRect
	var p2_wash: ColorRect = _prematch_identity_card.get_node_or_null("P2Wash") as ColorRect
	var p3_wash: ColorRect = _prematch_identity_card.get_node_or_null("P3Wash") as ColorRect
	var p4_wash: ColorRect = _prematch_identity_card.get_node_or_null("P4Wash") as ColorRect
	var p1_color: Color = p1_data.get("color", TeamVisuals.owner_color(1)) as Color
	var p2_color: Color = p2_data.get("color", TeamVisuals.owner_color(2)) as Color
	var p3_color: Color = p3_data.get("color", TeamVisuals.owner_color(3)) as Color
	var p4_color: Color = p4_data.get("color", TeamVisuals.owner_color(4)) as Color
	if p1_label != null:
		p1_label.text = "PLAYER 1"
	if p1_name != null:
		p1_name.text = str(p1_data.get("name", "Swarm Father"))
	if p2_label != null:
		p2_label.text = "PLAYER 2"
	if p2_name != null:
		p2_name.text = str(p2_data.get("name", "Mrs. SwarmDaddy"))
	if p3_label != null:
		p3_label.text = "PLAYER 3"
	if p3_name != null:
		p3_name.text = str(p3_data.get("name", "Player 3"))
	if p4_label != null:
		p4_label.text = "PLAYER 4"
	if p4_name != null:
		p4_name.text = str(p4_data.get("name", "Player 4"))
	if p1_accent != null:
		p1_accent.color = Color(p1_color.r, p1_color.g, p1_color.b, 0.96)
	if p2_accent != null:
		p2_accent.color = Color(p2_color.r, p2_color.g, p2_color.b, 0.96)
	if p3_accent != null:
		p3_accent.color = Color(p3_color.r, p3_color.g, p3_color.b, 0.96)
	if p4_accent != null:
		p4_accent.color = Color(p4_color.r, p4_color.g, p4_color.b, 0.96)
	if p1_wash != null:
		p1_wash.color = Color(p1_color.r, p1_color.g, p1_color.b, 0.16)
	if p2_wash != null:
		p2_wash.color = Color(p2_color.r, p2_color.g, p2_color.b, 0.16)
	if p3_wash != null:
		p3_wash.color = Color(p3_color.r, p3_color.g, p3_color.b, 0.16)
	if p4_wash != null:
		p4_wash.color = Color(p4_color.r, p4_color.g, p4_color.b, 0.16)

func _prematch_identity_player_data(seat: int, fallback_name: String) -> Dictionary:
	var entry: Dictionary = _get_roster_entry_for_slot(seat)
	var uid: String = str(entry.get("uid", "")).strip_edges()
	var is_cpu: bool = bool(entry.get("is_cpu", false))
	var name: String = _display_name_for_seat(seat, uid, is_cpu)
	if name.strip_edges().is_empty() or name == "Player %d" % seat:
		name = fallback_name
	var team_color: Color = _prematch_identity_card_color_for_seat(seat)
	return {
		"seat": seat,
		"name": name,
		"color": team_color
	}

func _prematch_identity_card_color_for_seat(seat: int) -> Color:
	match _current_vs_mode():
		"2V2", "3P FFA", "4P FFA":
			return TeamVisuals.owner_color(seat)
	return _team_color_for_seat(seat)

func _team_color_for_seat(seat: int) -> Color:
	match _current_vs_mode():
		"3P FFA", "4P FFA":
			return TeamVisuals.owner_color(seat)
	var team_id: int = _resolve_team_for_seat(seat)
	if team_id <= 0:
		team_id = seat
	return TeamVisuals.owner_color(team_id)

func _prematch_identity_uses_stacked_3p() -> bool:
	if _current_vs_mode() == "3P FFA":
		return true
	return _record_active_seats().size() == 3

func _prematch_identity_uses_team_2v2() -> bool:
	return _current_vs_mode() == "2V2"

func _prematch_identity_uses_quadrant_4p() -> bool:
	if _prematch_identity_uses_team_2v2():
		return false
	if _current_vs_mode() == "4P FFA":
		return true
	if OpsState != null and OpsState.has_method("get_team_mode_override"):
		return _record_active_seats().size() == 4 and str(OpsState.call("get_team_mode_override")).strip_edges().to_lower() == "ffa"
	return false

func _prematch_identity_card_show_ms() -> int:
	return PREMATCH_IDENTITY_CARD_SHOW_MS

func _prematch_hive_focus_start_ms() -> int:
	return PREMATCH_HIVE_FOCUS_START_MS

func _prematch_hive_pulse_sec() -> float:
	return PREMATCH_HIVE_PULSE_SEC

func _fade_prematch_identity_card() -> void:
	if _prematch_identity_card == null or _prematch_identity_card_faded:
		return
	_prematch_identity_card_faded = true
	var tween: Tween = create_tween()
	tween.tween_property(_prematch_identity_card, "modulate:a", 0.0, PREMATCH_IDENTITY_CARD_FADE_SEC)
	tween.finished.connect(func() -> void:
		if _prematch_identity_card != null:
			_prematch_identity_card.visible = false
	)

func _apply_team_orientation_buffers() -> void:
	var local_owner_id: int = _resolve_local_owner_id()
	var local_color: Color = _team_color_for_seat(local_owner_id)
	var top_buffer: Control = _resolve_top_buffer_background() as Control
	var bottom_buffer: Control = _resolve_bottom_buffer_background() as Control
	_clear_team_buffer_color(top_buffer, "OpponentTeamColorWash")
	_clear_team_buffer_color(bottom_buffer, "OpponentTeamColorWash")
	_apply_team_buffer_color(top_buffer, local_color, "LocalTeamColorWash")
	_apply_team_buffer_color(bottom_buffer, local_color, "LocalTeamColorWash")

func _resolve_primary_opponent_owner_id(local_owner_id: int) -> int:
	var active_seats: Array[int] = _record_active_seats()
	for seat in active_seats:
		if seat == local_owner_id:
			continue
		if not _are_allied_owners(local_owner_id, seat):
			return seat
	if local_owner_id != 2:
		return 2
	return 1

func _clear_team_buffer_color(buffer: Control, node_name: String) -> void:
	if buffer == null:
		return
	var wash_node: Node = buffer.get_node_or_null(node_name)
	if wash_node != null:
		buffer.remove_child(wash_node)
		wash_node.queue_free()

func _apply_team_buffer_color(buffer: Control, color: Color, node_name: String) -> void:
	if buffer == null:
		return
	buffer.clip_contents = true
	var wash: TextureRect = buffer.get_node_or_null(node_name) as TextureRect
	if wash == null:
		var stale_wash: Node = buffer.get_node_or_null(node_name)
		if stale_wash != null:
			buffer.remove_child(stale_wash)
			stale_wash.queue_free()
		wash = TextureRect.new()
		wash.name = node_name
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buffer.add_child(wash)
	wash.texture = (buffer as TextureRect).texture if buffer is TextureRect else null
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = (buffer as TextureRect).stretch_mode if buffer is TextureRect else TextureRect.STRETCH_SCALE
	wash.texture_repeat = (buffer as TextureRect).texture_repeat if buffer is TextureRect else CanvasItem.TEXTURE_REPEAT_DISABLED
	wash.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	wash.offset_left = 0.0
	wash.offset_top = 0.0
	wash.offset_right = 0.0
	wash.offset_bottom = 0.0
	wash.modulate = Color(color.r, color.g, color.b, PREMATCH_TEAM_BUFFER_ALPHA)
	wash.self_modulate = Color.WHITE
	wash.visible = true
	buffer.move_child(wash, 0)

func _resolve_local_starting_hive_ids() -> Array[int]:
	var ids: Array[int] = []
	var local_owner_id: int = _resolve_local_owner_id()
	return _resolve_starting_hive_ids_for_owner(local_owner_id)

func _resolve_starting_hive_ids_for_owner(owner_id: int) -> Array[int]:
	var ids: Array[int] = []
	if state == null or state.hives == null:
		return ids
	for hive_any in state.hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null:
			continue
		if int(hive.owner_id) == int(owner_id):
			ids.append(int(hive.id))
	ids.sort()
	return ids

func _resolve_prematch_focus_hive_ids() -> Array[int]:
	if not _prematch_identity_uses_quadrant_4p():
		return _resolve_local_starting_hive_ids()
	var ids: Array[int] = []
	var active_seats: Array[int] = _record_active_seats()
	active_seats.sort()
	for seat in active_seats:
		var seat_ids: Array[int] = _resolve_starting_hive_ids_for_owner(seat)
		for hive_id in seat_ids:
			ids.append(hive_id)
	return ids

func _start_prematch_hive_focus_sequence() -> void:
	if _prematch_hive_focus_started:
		return
	_prematch_hive_focus_started = true
	var cam: Camera2D = camera if camera != null else $Camera2D
	if cam != null:
		_prematch_gameplay_camera_position = cam.global_position
		_prematch_gameplay_camera_zoom = cam.zoom
	var hive_ids: Array[int] = _resolve_prematch_focus_hive_ids()
	if hive_ids.is_empty():
		return
	call_deferred("_run_prematch_hive_focus_sequence", hive_ids)

func _run_prematch_hive_focus_sequence(hive_ids: Array[int]) -> void:
	for hive_id in hive_ids:
		if _prematch_countdown_return_started:
			return
		if OpsState == null or OpsState.match_phase != OpsState.MatchPhase.PREMATCH:
			return
		_pulse_prematch_hive(hive_id)
		await get_tree().create_timer(_prematch_hive_pulse_sec()).timeout

func _focus_camera_on_hive(hive_id: int) -> void:
	if state == null:
		return
	var cam: Camera2D = camera if camera != null else $Camera2D
	if cam == null:
		return
	var hive_pos: Vector2 = state.hive_world_pos_by_id(hive_id)
	if hive_pos == Vector2.ZERO:
		return
	if _prematch_camera_tween != null and _prematch_camera_tween.is_valid():
		_prematch_camera_tween.kill()
	var base_zoom: Vector2 = _prematch_gameplay_camera_zoom
	if base_zoom.x <= 0.0 or base_zoom.y <= 0.0:
		base_zoom = cam.zoom
	if base_zoom.x <= 0.0 or base_zoom.y <= 0.0:
		base_zoom = Vector2.ONE
	var focus_zoom: Vector2 = base_zoom * PREMATCH_HIVE_FOCUS_ZOOM_MULT
	_prematch_camera_tween = create_tween()
	_prematch_camera_tween.set_parallel(true)
	_prematch_camera_tween.tween_property(cam, "global_position", hive_pos, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prematch_camera_tween.tween_property(cam, "zoom", focus_zoom, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _pulse_prematch_hive(hive_id: int) -> void:
	if state == null:
		return
	var pulse_root: Node2D = _ensure_prematch_pulse_root()
	if pulse_root == null:
		return
	var hive_pos: Vector2 = state.hive_world_pos_by_id(hive_id)
	if hive_pos == Vector2.ZERO:
		return
	var owner_id: int = _owner_id_for_hive_id(hive_id)
	if owner_id <= 0:
		owner_id = _resolve_local_owner_id()
	var color: Color = TeamVisuals.owner_color(owner_id)
	var ring: Line2D = Line2D.new()
	ring.name = "PrematchHivePulse_%d" % hive_id
	ring.width = 5.0
	ring.default_color = Color(color.r, color.g, color.b, 0.95)
	ring.closed = true
	ring.z_as_relative = false
	ring.z_index = PLAYFIELD_OUTLINE_Z_INDEX
	ring.points = _circle_points(44.0, 36)
	pulse_root.add_child(ring)
	ring.global_position = hive_pos
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	var pulse_sec: float = _prematch_hive_pulse_sec()
	tween.tween_property(ring, "scale", Vector2(1.8, 1.8), pulse_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, pulse_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if ring != null and is_instance_valid(ring):
			ring.queue_free()
	)

func _owner_id_for_hive_id(hive_id: int) -> int:
	if state == null:
		return 0
	var hive: HiveData = state.find_hive_by_id(hive_id)
	if hive == null:
		return 0
	return int(hive.owner_id)

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var count: int = maxi(8, segments)
	for i in range(count):
		var angle: float = (TAU * float(i)) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _ensure_prematch_pulse_root() -> Node2D:
	if _prematch_pulse_root != null and is_instance_valid(_prematch_pulse_root):
		return _prematch_pulse_root
	var pools_root: Node2D = get_node_or_null("PoolsRoot") as Node2D
	if pools_root == null:
		pools_root = Node2D.new()
		pools_root.name = "PoolsRoot"
		add_child(pools_root)
	var existing: Node2D = pools_root.get_node_or_null("PrematchPulseRoot") as Node2D
	if existing == null:
		existing = Node2D.new()
		existing.name = "PrematchPulseRoot"
		existing.z_as_relative = false
		existing.z_index = PLAYFIELD_OUTLINE_Z_INDEX
		pools_root.add_child(existing)
	_prematch_pulse_root = existing
	return _prematch_pulse_root

func _clear_prematch_pulses() -> void:
	if _prematch_camera_tween != null and _prematch_camera_tween.is_valid():
		_prematch_camera_tween.kill()
	_prematch_camera_tween = null
	if _prematch_pulse_root == null or not is_instance_valid(_prematch_pulse_root):
		return
	for child in _prematch_pulse_root.get_children():
		child.queue_free()

func _return_camera_to_gameplay_view() -> void:
	if _prematch_countdown_return_started:
		return
	_prematch_countdown_return_started = true
	if _prematch_camera_tween != null and _prematch_camera_tween.is_valid():
		_prematch_camera_tween.kill()
	_prematch_camera_tween = null
	_fit_camera_to_viewport("prematch_countdown_return")

func _layout_prematch_records_panel(records: Control) -> void:
	if records == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var vr: Rect2 = vp.get_visible_rect()
	var top_inset: float = _ui_top_inset_px()
	var panel_size: Vector2 = _prematch_records_panel_size()
	var panel_top: float = top_inset + PREMATCH_RECORDS_TOP_GAP_PX
	records.position = Vector2((vr.size.x - panel_size.x) * 0.5, panel_top)
	records.size = panel_size

func _layout_capture_flag_instruction_panel(panel: Control = null) -> void:
	var target: Control = panel if panel != null else _prematch_ctf_panel
	if target == null:
		return
	var vr := get_viewport().get_visible_rect()
	var top_inset: float = _ui_top_inset_px()
	var width: float = 540.0
	var height: float = 146.0
	var panel_top: float = top_inset + PREMATCH_RECORDS_TOP_GAP_PX + _prematch_records_panel_size().y + 16.0
	target.position = Vector2((vr.size.x - width) * 0.5, panel_top)
	target.size = Vector2(width, height)

func _ensure_prematch_ad_surface() -> void:
	if _prematch_overlay == null:
		return
	if _prematch_ad_surface == null or not is_instance_valid(_prematch_ad_surface):
		var existing: Node = _prematch_overlay.get_node_or_null("PrematchHandshakeAdSurface")
		if existing is Control:
			_prematch_ad_surface = existing as Control
		else:
			var created_any: Variant = AdSurfaceScript.new()
			if not (created_any is Control):
				return
			_prematch_ad_surface = created_any as Control
			_prematch_ad_surface.name = "PrematchHandshakeAdSurface"
			_prematch_overlay.add_child(_prematch_ad_surface)
	if _prematch_ad_surface.has_method("configure"):
		_prematch_ad_surface.call("configure", "prematch_handshake", "handshake", PREMATCH_AD_SIZE, false)
	_prematch_ad_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prematch_ad_surface.z_as_relative = false
	_prematch_ad_surface.z_index = 1003
	_layout_prematch_ad_surface()

func _layout_prematch_ad_surface() -> void:
	if _prematch_ad_surface == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var vr: Rect2 = vp.get_visible_rect()
	var top_inset: float = _ui_top_inset_px()
	var ad_size: Vector2 = Vector2(
		minf(PREMATCH_AD_SIZE.x, maxf(300.0, vr.size.x - 32.0)),
		PREMATCH_AD_SIZE.y
	)
	var records_bottom: float = top_inset + PREMATCH_RECORDS_TOP_GAP_PX + _prematch_records_panel_size().y
	var ctf_bottom: float = records_bottom
	if _prematch_ctf_panel != null and _prematch_ctf_panel.visible:
		ctf_bottom = maxf(ctf_bottom, _prematch_ctf_panel.position.y + _prematch_ctf_panel.size.y)
	_prematch_ad_surface.position = Vector2((vr.size.x - ad_size.x) * 0.5, ctf_bottom + 14.0)
	_prematch_ad_surface.size = ad_size

func _ensure_in_game_ad_surface() -> void:
	var hud_root: Control = _resolve_hud_root()
	if hud_root == null:
		return
	if _in_game_ad_surface == null or not is_instance_valid(_in_game_ad_surface):
		var existing: Node = hud_root.get_node_or_null("InGameHudAdSurface")
		if existing is Control:
			_in_game_ad_surface = existing as Control
		else:
			var created_any: Variant = AdSurfaceScript.new()
			if not (created_any is Control):
				return
			_in_game_ad_surface = created_any as Control
			_in_game_ad_surface.name = "InGameHudAdSurface"
			hud_root.add_child(_in_game_ad_surface)
	if _in_game_ad_surface.has_method("configure"):
		_in_game_ad_surface.call("configure", "in_game_hud", "in_game", IN_GAME_AD_SIZE, false)
	_in_game_ad_surface.z_as_relative = false
	_in_game_ad_surface.z_index = IN_GAME_AD_HUD_Z_INDEX
	_layout_in_game_ad_surface()
	_snap_power_bar_to_map_top("in_game_ad_surface_ready")

func _layout_in_game_ad_surface() -> void:
	if _in_game_ad_surface == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var vr: Rect2 = vp.get_visible_rect()
	var ad_size: Vector2 = Vector2(
		minf(IN_GAME_AD_SIZE.x, maxf(IN_GAME_AD_MIN_WIDTH_PX, vr.size.x - 32.0)),
		IN_GAME_AD_SIZE.y
	)
	_in_game_ad_surface.position = Vector2((vr.size.x - ad_size.x) * 0.5, IN_GAME_AD_TOP_MARGIN_PX)
	_in_game_ad_surface.size = ad_size

func _prematch_records_panel_size() -> Vector2:
	if _uses_async_prematch_card():
		return Vector2(ASYNC_PREMATCH_CARD_WIDTH_PX, ASYNC_PREMATCH_CARD_HEIGHT_PX)
	return Vector2(PREMATCH_RECORDS_WIDTH_PX, PREMATCH_RECORDS_HEIGHT_PX)

func _load_ctf_move_button_font() -> Font:
	if ResourceLoader.exists(CTF_MOVE_BUTTON_FONT_PATH):
		var atlas_font: Resource = load(CTF_MOVE_BUTTON_FONT_PATH)
		if atlas_font is Font:
			return atlas_font as Font
	if ResourceLoader.exists(CTF_MOVE_BUTTON_FALLBACK_FONT_PATH):
		var fallback_font: Resource = load(CTF_MOVE_BUTTON_FALLBACK_FONT_PATH)
		if fallback_font is Font:
			return fallback_font as Font
	return UITypography.fallback_font()

func _ensure_capture_flag_move_button() -> Button:
	if _ctf_move_button != null and is_instance_valid(_ctf_move_button):
		return _ctf_move_button
	var top_buffer: Control = _resolve_top_buffer_background() as Control
	if top_buffer == null:
		return null
	var existing: Button = top_buffer.get_node_or_null(String(CTF_MOVE_BUTTON_NAME)) as Button
	if existing != null:
		_ctf_move_button = existing
	else:
		var button := Button.new()
		button.name = String(CTF_MOVE_BUTTON_NAME)
		button.visible = false
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.anchor_left = 0.5
		button.anchor_right = 0.5
		button.anchor_top = 0.0
		button.anchor_bottom = 0.0
		button.offset_left = -116.0
		button.offset_right = 116.0
		button.offset_top = 148.0
		button.offset_bottom = 190.0
		button.custom_minimum_size = Vector2(232.0, 42.0)
		button.add_theme_font_size_override("font_size", 20)
		var button_font: Font = _load_ctf_move_button_font()
		if button_font != null:
			button.add_theme_font_override("font", button_font)
		button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.74, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.86, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.86, 1.0))
		button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		button.add_theme_constant_override("outline_size", 2)
		top_buffer.add_child(button)
		_ctf_move_button = button
	if not _ctf_move_button.pressed.is_connected(_on_capture_flag_move_button_pressed):
		_ctf_move_button.pressed.connect(_on_capture_flag_move_button_pressed)
	_layout_capture_flag_move_button()
	return _ctf_move_button

func _layout_capture_flag_move_button() -> void:
	var button: Button = _ensure_capture_flag_move_button()
	var top_buffer: Control = _resolve_top_buffer_background() as Control
	if button == null or top_buffer == null:
		return
	var width: float = 232.0
	var height: float = 42.0
	var target_top: float = 148.0
	if power_bar != null and is_instance_valid(power_bar) and power_bar.is_inside_tree():
		var power_rect: Rect2 = power_bar.get_global_rect()
		var top_rect: Rect2 = top_buffer.get_global_rect()
		target_top = (power_rect.position.y + power_rect.size.y + 8.0) - top_rect.position.y
	var max_top: float = maxf(92.0, top_buffer.size.y - height - 10.0)
	target_top = clampf(target_top, 92.0, max_top)
	button.offset_left = -width * 0.5
	button.offset_right = width * 0.5
	button.offset_top = target_top
	button.offset_bottom = target_top + height

func _apply_capture_flag_move_button_style(button: Button, armed: bool) -> void:
	if button == null:
		return
	var idle_fill: Color = Color(0.05, 0.08, 0.12, 0.9)
	var idle_border: Color = Color(0.93, 0.78, 0.28, 0.92)
	var armed_fill: Color = Color(0.16, 0.08, 0.08, 0.94)
	var armed_border: Color = Color(1.0, 0.42, 0.22, 0.98)
	var fill: Color = armed_fill if armed else idle_fill
	var border: Color = armed_border if armed else idle_border
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = border
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_left = 16
	normal.corner_radius_bottom_right = 16
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	normal.shadow_size = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.08)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", normal)

func _set_capture_flag_move_armed(armed: bool) -> void:
	if _ctf_move_armed == armed:
		_refresh_capture_flag_move_button()
		return
	_ctf_move_armed = armed
	mark_render_dirty("ctf_flag_move_arm")
	_push_render_model()
	_refresh_capture_flag_move_button()

func _refresh_capture_flag_move_button() -> void:
	var button: Button = _ensure_capture_flag_move_button()
	if button == null or OpsState == null:
		return
	_layout_capture_flag_move_button()
	var local_owner_id: int = _resolve_local_owner_id()
	var flag_state: Dictionary = {}
	if OpsState.has_method("get_capture_flag_for_owner"):
		flag_state = OpsState.call("get_capture_flag_for_owner", local_owner_id) as Dictionary
	var show_button: bool = (
		OpsState.has_method("is_capture_flag_mode")
		and bool(OpsState.call("is_capture_flag_mode"))
		and _hidden_capture_flag_enabled()
		and int(OpsState.match_phase) == int(OpsState.MatchPhase.RUNNING)
		and not flag_state.is_empty()
		and int(flag_state.get("moves_remaining", 0)) > 0
	)
	if not show_button and _ctf_move_armed:
		_ctf_move_armed = false
		mark_render_dirty("ctf_flag_move_arm_hide")
		_push_render_model()
	button.visible = show_button
	button.disabled = not show_button
	if not show_button:
		return
	button.text = "CANCEL MOVE" if _ctf_move_armed else "MOVE FLAG"
	button.tooltip_text = "Choose a new owned hive for your flag. Moving reveals it."
	_apply_capture_flag_move_button_style(button, _ctf_move_armed)

func _on_capture_flag_move_button_pressed() -> void:
	if OpsState == null or not OpsState.has_method("is_capture_flag_mode"):
		return
	if not bool(OpsState.call("is_capture_flag_mode")):
		return
	if not _hidden_capture_flag_enabled():
		return
	if int(OpsState.match_phase) != int(OpsState.MatchPhase.RUNNING):
		return
	var local_owner_id: int = _resolve_local_owner_id()
	var flag_state: Dictionary = {}
	if OpsState.has_method("get_capture_flag_for_owner"):
		flag_state = OpsState.call("get_capture_flag_for_owner", local_owner_id) as Dictionary
	if flag_state.is_empty():
		return
	if int(flag_state.get("moves_remaining", 0)) <= 0:
		_show_capture_flag_toast("NO FLAG MOVES LEFT", 1000.0)
		_refresh_capture_flag_move_button()
		return
	if _ctf_move_armed:
		_set_capture_flag_move_armed(false)
		_show_capture_flag_toast("FLAG MOVE CANCELED", 900.0)
		return
	_clear_selection()
	_set_capture_flag_move_armed(true)
	_show_capture_flag_toast("SELECT A NEW OWNED HIVE", 1300.0)

func _ensure_prematch_record_label(vbox: VBoxContainer, name: String) -> Label:
	if vbox == null:
		return null
	var label := vbox.get_node_or_null(name) as Label
	if label == null:
		label = Label.new()
		label.name = name
		vbox.add_child(label)
	return label

func _style_prematch_record_label(label: Label) -> void:
	if label == null:
		return
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", PREMATCH_RECORDS_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.97, 0.99, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 2)

func _style_prematch_team_label(label: Label) -> void:
	if label == null:
		return
	_style_prematch_record_label(label)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.66, 1.0))

func _style_prematch_team_arrow_label(label: Label) -> void:
	if label == null:
		return
	_style_prematch_record_label(label)
	label.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 0.92))
	label.add_theme_font_size_override("font_size", PREMATCH_RECORDS_FONT_SIZE + 1)

func _log_prematch_ui_state() -> void:
	var overlay_dict := {}
	if _prematch_overlay != null:
		overlay_dict = {
			"visible": _prematch_overlay.visible,
			"modulate_a": _prematch_overlay.modulate.a,
			"self_modulate_a": _prematch_overlay.self_modulate.a,
			"global_position": _prematch_overlay.global_position,
			"size": _prematch_overlay.size
		}
	var countdown_dict := {}
	if _prematch_countdown_label != null:
		countdown_dict = {
			"visible": _prematch_countdown_label.visible,
			"modulate_a": _prematch_countdown_label.modulate.a,
			"self_modulate_a": _prematch_countdown_label.self_modulate.a,
			"global_position": _prematch_countdown_label.global_position,
			"size": _prematch_countdown_label.size
		}
	var records_dict := {}
	if _prematch_records_panel != null:
		records_dict = {
			"visible": _prematch_records_panel.visible,
			"modulate_a": _prematch_records_panel.modulate.a,
			"self_modulate_a": _prematch_records_panel.self_modulate.a,
			"global_position": _prematch_records_panel.global_position,
			"size": _prematch_records_panel.size
		}
	SFLog.info("PREMATCH_UI_STATE", {
		"overlay": overlay_dict,
		"countdown": countdown_dict,
		"records": records_dict
	})

func _center_match_timer() -> void:
	var mt := get_node_or_null(SHELL_HUD_LAYER_PATH + "/MatchTimer")
	if mt == null:
		return
	if not (mt is Control):
		return
	var c := mt as Control
	c.set_anchors_preset(Control.PRESET_CENTER, true)
	c.position = Vector2.ZERO
	c.pivot_offset = c.size * 0.5
	var lbl := c.get_node_or_null("MatchTimerLabel")
	if lbl != null and lbl is Label:
		var label := lbl as Label
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _show_prematch_ui() -> void:
	if _prematch_overlay == null:
		return
	SFLog.allow_tag("PREMATCH_UI_VIS")
	_ensure_prematch_on_top()
	_prematch_overlay.visible = true
	if _prematch_countdown_label != null:
		var start_sec := int(ceil(float(OpsState.prematch_duration_ms) / 1000.0))
		_prematch_countdown_label.text = str(start_sec)
		if Engine.is_editor_hint() == false:
			SFLog.info("CLOCK_NODE_PATH", {
				"path": _node_path_for_log(_prematch_countdown_label),
				"type": _prematch_countdown_label.get_class()
			})
		_prematch_countdown_label.modulate = Color(1, 1, 1, 1)
		_prematch_countdown_label.add_theme_color_override("font_color", _local_countdown_color())
		_prematch_countdown_label.visible = true
	_show_prematch_identity_card()
	_refresh_prematch_records()
	_refresh_capture_flag_prematch_prompt()
	if _prematch_records_panel != null:
		_layout_prematch_records_panel(_prematch_records_panel)
		_prematch_records_panel.visible = true
		_prematch_records_panel.modulate = Color(1, 1, 1, 1)
		SFLog.warn("PREMATCH_UI_VIS", {
			"records_path": _node_path_for_log(_prematch_records_panel),
			"records_visible": _prematch_records_panel.visible,
			"records_pos": _prematch_records_panel.global_position,
			"records_size": _prematch_records_panel.size,
			"records_z": _prematch_records_panel.z_index,
			"record_p1": _prematch_record_p1.text if _prematch_record_p1 != null else "<null>",
			"record_p2": _prematch_record_p2.text if _prematch_record_p2 != null else "<null>",
			"record_p3": _prematch_record_p3.text if _prematch_record_p3 != null else "<null>",
			"record_p4": _prematch_record_p4.text if _prematch_record_p4 != null else "<null>",
			"record_h2h": _prematch_record_h2h.text if _prematch_record_h2h != null else "<null>",
			"record_teams": _prematch_record_teams.text if _prematch_record_teams != null else "<null>",
			"record_team_links": _prematch_record_team_arrows.text if _prematch_record_team_arrows != null else "<null>",
			"overlay_path": _node_path_for_log(_prematch_overlay),
			"overlay_visible": _prematch_overlay.visible,
			"overlay_z": _prematch_overlay.z_index
		}, "", 250)
	SFLog.info("PREMATCH_UI_INIT", {
		"overlay_ok": _prematch_overlay != null,
		"countdown_ok": _prematch_countdown_label != null,
		"records_ok": _prematch_records_panel != null
	})

func _refresh_prematch_records() -> void:
	_reset_prematch_record_styles()
	if _uses_async_prematch_card():
		_refresh_async_prematch_card()
		return
	if _prematch_record_teams != null:
		_prematch_record_teams.text = _get_team_banner_line()
	if _prematch_record_team_arrows != null:
		_prematch_record_team_arrows.text = _get_team_arrow_line()
	if _prematch_record_p1 != null:
		_prematch_record_p1.text = _get_player_record_line(1)
	if _prematch_record_p2 != null:
		_prematch_record_p2.text = _get_player_record_line(2)
	if _prematch_record_p3 != null:
		_prematch_record_p3.text = _get_player_record_line(3)
	if _prematch_record_p4 != null:
		_prematch_record_p4.text = _get_player_record_line(4)
	if _prematch_record_h2h != null:
		_prematch_record_h2h.text = _get_h2h_record_line()

func _reset_prematch_record_styles() -> void:
	_style_prematch_team_label(_prematch_record_teams)
	_style_prematch_team_arrow_label(_prematch_record_team_arrows)
	for label in [_prematch_record_p1, _prematch_record_p2, _prematch_record_p3, _prematch_record_p4, _prematch_record_h2h]:
		if label is Label:
			_style_prematch_record_label(label as Label)
	if _prematch_record_teams != null:
		_prematch_record_teams.visible = true
	if _prematch_record_team_arrows != null:
		_prematch_record_team_arrows.visible = true
	for label in [_prematch_record_p1, _prematch_record_p2, _prematch_record_p3, _prematch_record_p4, _prematch_record_h2h]:
		if label is Label:
			(label as Label).visible = true

func _refresh_async_prematch_card() -> void:
	var sec_left: int = maxi(0, int(ceil(_prematch_remaining_ms_f / 1000.0)))
	var detail_lines: Array[String] = _async_prematch_detail_lines()
	if _prematch_record_teams != null:
		_prematch_record_teams.add_theme_font_size_override("font_size", 28)
		_prematch_record_teams.text = _async_prematch_mode_banner()
	if _prematch_record_team_arrows != null:
		_prematch_record_team_arrows.add_theme_font_size_override("font_size", 20)
		_prematch_record_team_arrows.text = _async_prematch_round_line()
	if _prematch_record_p1 != null:
		_prematch_record_p1.add_theme_font_size_override("font_size", 18)
		_prematch_record_p1.text = detail_lines[0] if detail_lines.size() > 0 else ""
	if _prematch_record_p2 != null:
		_prematch_record_p2.add_theme_font_size_override("font_size", 18)
		_prematch_record_p2.text = detail_lines[1] if detail_lines.size() > 1 else ""
	if _prematch_record_p3 != null:
		_prematch_record_p3.add_theme_font_size_override("font_size", 18)
		_prematch_record_p3.text = detail_lines[2] if detail_lines.size() > 2 else ""
	if _prematch_record_p4 != null:
		_prematch_record_p4.add_theme_font_size_override("font_size", 18)
		_prematch_record_p4.text = detail_lines[3] if detail_lines.size() > 3 else ""
	if _prematch_record_h2h != null:
		_prematch_record_h2h.add_theme_font_size_override("font_size", 24)
		_prematch_record_h2h.add_theme_color_override("font_color", Color(1.0, 0.93, 0.66, 1.0))
		_prematch_record_h2h.text = "Starts in %d" % sec_left

func _async_prematch_detail_lines() -> Array[String]:
	var stage_count: int = maxi(1, _get_stage_map_paths_runtime().size())
	match _current_vs_mode():
		"1V1":
			return [
				"Map: %s" % _async_prematch_map_title(),
				"Head-to-head control. Opening input unlocks after the countdown.",
				_async_prematch_bot_line(),
				_async_prematch_track_line()
			]
		"2V2":
			return [
				"Map: %s" % _async_prematch_map_title(),
				_get_team_banner_line(),
				_async_prematch_bot_line(),
				_async_prematch_track_line()
			]
		"3P FFA", "4P FFA":
			return [
				"Map: %s" % _async_prematch_map_title(),
				"Free-for-all control. Every active seat plays for itself.",
				_async_prematch_bot_line(),
				_async_prematch_track_line()
			]
		VS_MODE_ASYNC_SINGLE_MAP_TIMED:
			return [
				"Map: %s" % _async_prematch_map_title(),
				"One map, one clock. Push a clean run from the opening tap.",
				"Best finish time wins. %s" % _async_prematch_bot_line(),
				_async_prematch_track_line()
			]
		"TIMED_RACE":
			return [
				"Map: %s" % _async_prematch_map_title(),
				"Multiple maps in sequence. The run stays live between stages.",
				"Fastest total clear wins. %s" % _async_prematch_bot_line(),
				_async_prematch_track_line()
			]
		"MISS_N_OUT":
			return [
				"Map: %s" % _async_prematch_map_title(),
				"Clear each stage in order. One failed map ends the full run.",
				"Survive the set, then sort by time. %s" % _async_prematch_bot_line(),
				_async_prematch_track_line()
			]
		_:
			return [
				"Map: %s" % _async_prematch_map_title(),
				"%d stages back to back. Clear this map, then roll into the next one." % stage_count,
				"Fastest total run wins. %s" % _async_prematch_bot_line(),
				_async_prematch_track_line()
			]

func _get_team_banner_line() -> String:
	var local_seat: int = _resolve_local_owner_id()
	return _prematch_team_ui_formatter.format_team_banner_line(
		_record_active_seats(),
		Callable(self, "_resolve_team_for_seat"),
		local_seat,
		Callable(self, "_display_name_for_team_seat")
	)

func _get_team_arrow_line() -> String:
	return _prematch_team_ui_formatter.format_team_arrow_line(
		_record_active_seats(),
		Callable(self, "_resolve_team_for_seat"),
		Callable(self, "_display_name_for_team_seat")
	)

func _format_team_seats_text(seats: Array) -> String:
	return _prematch_team_ui_formatter.format_team_seats_text(seats)

func _resolve_team_for_seat(seat: int) -> int:
	var team_id: int = seat
	if OpsState != null and OpsState.has_method("get_team_for_seat"):
		team_id = int(OpsState.call("get_team_for_seat", seat))
	if team_id <= 0:
		team_id = seat
	return team_id

func _display_name_for_team_seat(seat: int) -> String:
	var entry: Dictionary = _get_roster_entry_for_slot(seat)
	var uid: String = str(entry.get("uid", "")).strip_edges()
	var is_cpu: bool = bool(entry.get("is_cpu", false))
	return _display_name_for_seat(seat, uid, is_cpu)

func _get_player_record_line(player_slot: int) -> String:
	var entry: Dictionary = _get_roster_entry_for_slot(player_slot)
	var uid: String = str(entry.get("uid", ""))
	var is_cpu: bool = bool(entry.get("is_cpu", false))
	var handle: String = _display_name_for_seat(player_slot, uid, is_cpu)
	var record_key: String = _record_key_for_roster_entry(entry)
	var record: Dictionary = _match_records.get_record(record_key)
	var wins: int = int(record.get("wins", 0))
	var losses: int = int(record.get("losses", 0))
	SFLog.info("PREMATCH_NAME_RESOLVE", {
		"seat": player_slot,
		"uid": uid,
		"handle": handle
	})
	return "%s  W-L %d-%d" % [handle, wins, losses]

func _get_h2h_record_line() -> String:
	var p1_entry: Dictionary = _get_roster_entry_for_slot(1)
	var p2_entry: Dictionary = _get_roster_entry_for_slot(2)
	var p1_uid: String = str(p1_entry.get("uid", ""))
	var p2_uid: String = str(p2_entry.get("uid", ""))
	var p1_cpu: bool = bool(p1_entry.get("is_cpu", false))
	var p2_cpu: bool = bool(p2_entry.get("is_cpu", false))
	var p1_name: String = _display_name_for_seat(1, p1_uid, p1_cpu)
	var p2_name: String = _display_name_for_seat(2, p2_uid, p2_cpu)
	var p1_key: String = _record_key_for_roster_entry(p1_entry)
	var p2_key: String = _record_key_for_roster_entry(p2_entry)
	var h2h: Dictionary = _match_records.get_h2h(p1_key, p2_key)
	var p1_wins: int = int(h2h.get("a_wins", 0))
	var p2_wins: int = int(h2h.get("b_wins", 0))
	return "H2H: %s vs %s (%d-%d)" % [p1_name, p2_name, p1_wins, p2_wins]

func _current_vs_mode() -> String:
	var tree: SceneTree = get_tree()
	if tree == null or not tree.has_meta(TREE_META_VS_MODE):
		return ""
	return str(tree.get_meta(TREE_META_VS_MODE, "")).strip_edges().to_upper()

func _is_crucible_match() -> bool:
	return CrucibleRulesetPolicyScript.is_crucible_tree(get_tree())

func _is_async_runtime_mode(mode_id: String = "") -> bool:
	var mode: String = mode_id.strip_edges().to_upper()
	if mode.is_empty():
		mode = _current_vs_mode()
	match mode:
		VS_MODE_STAGE_RACE, "TIMED_RACE", "MISS_N_OUT", VS_MODE_ASYNC_SINGLE_MAP_TIMED:
			return true
		_:
			return false

func _is_async_stage_continuation() -> bool:
	if not _is_async_runtime_mode():
		return false
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var stage_index: int = maxi(0, int(tree.get_meta(TREE_META_VS_STAGE_CURRENT_INDEX, 0)))
	return stage_index > 0

func _should_show_prematch_identity_flow() -> bool:
	return not _is_async_stage_continuation()

func _uses_async_prematch_card() -> bool:
	match _current_vs_mode():
		"1V1", "2V2", "3P FFA", "4P FFA", VS_MODE_STAGE_RACE, "TIMED_RACE", "MISS_N_OUT", VS_MODE_ASYNC_SINGLE_MAP_TIMED:
			return true
		_:
			return false

func _async_prematch_mode_banner() -> String:
	match _current_vs_mode():
		"1V1":
			return "1V1 DUEL"
		"2V2":
			return "2V2"
		"3P FFA":
			return "3P FFA"
		"4P FFA":
			return "4P FFA"
		VS_MODE_ASYNC_SINGLE_MAP_TIMED:
			return "MAP RUN"
		"TIMED_RACE":
			return "TIMED RACE"
		"MISS_N_OUT":
			return "MISS N OUT"
		_:
			return "STAGE RACE"

func _async_prematch_round_line() -> String:
	match _current_vs_mode():
		"1V1", "2V2", "3P FFA", "4P FFA":
			return "Sync start"
	if _current_vs_mode() == VS_MODE_ASYNC_SINGLE_MAP_TIMED:
		return "Single map run"
	var stage_maps: Array[String] = _get_stage_map_paths_runtime()
	if stage_maps.is_empty():
		return "Async run"
	var tree: SceneTree = get_tree()
	var round_index: int = 0
	if tree != null:
		round_index = clampi(int(tree.get_meta(TREE_META_VS_STAGE_CURRENT_INDEX, 0)), 0, maxi(stage_maps.size() - 1, 0))
	match _current_vs_mode():
		"TIMED_RACE":
			return "Map %d of %d" % [round_index + 1, stage_maps.size()]
		"MISS_N_OUT":
			return "Round %d of %d" % [round_index + 1, stage_maps.size()]
		_:
			return "Stage %d of %d" % [round_index + 1, stage_maps.size()]

func _async_prematch_map_title() -> String:
	var map_id: String = str(current_map_data.get("id", "")).strip_edges()
	if not map_id.is_empty():
		return MapRegistry.public_map_display_name_for_id(map_id)
	var stage_maps: Array[String] = _get_stage_map_paths_runtime()
	if not stage_maps.is_empty():
		var tree: SceneTree = get_tree()
		var round_index: int = 0
		if tree != null:
			round_index = clampi(int(tree.get_meta(TREE_META_VS_STAGE_CURRENT_INDEX, 0)), 0, maxi(stage_maps.size() - 1, 0))
		return MapRegistry.public_map_display_name_for_path(stage_maps[round_index])
	return "Unknown Map"

func _async_prematch_bot_line() -> String:
	if OpsState != null and OpsState.has_method("get_bot_profile"):
		for seat in range(1, 5):
			var entry: Dictionary = _get_roster_entry_for_slot(seat)
			if entry.is_empty() or not bool(entry.get("is_cpu", false)):
				continue
			var profile: Dictionary = OpsState.call("get_bot_profile", seat) as Dictionary
			var style: String = _humanize_runtime_token(str(profile.get("style", profile.get("persona", ""))))
			var tier: String = _humanize_runtime_token(str(profile.get("tier", "")))
			if style.is_empty() and tier.is_empty() and _is_jukebox_easy_bot_mode():
				return "CPU: Balancer / Jukebox"
			if tier.is_empty():
				tier = "Medium"
			if style.is_empty():
				style = "Balancer"
			return "CPU: %s / %s" % [style, tier]
	var tree: SceneTree = get_tree()
	if tree != null:
		var style_id: String = _humanize_runtime_token(str(tree.get_meta(TREE_META_VS_CPU_STYLE, "")))
		var tier_id: String = _humanize_runtime_token(str(tree.get_meta(TREE_META_VS_CPU_TIER, "")))
		if not style_id.is_empty() or not tier_id.is_empty():
			return "CPU: %s / %s" % [style_id if not style_id.is_empty() else "Balancer", tier_id if not tier_id.is_empty() else "Medium"]
	if _is_jukebox_easy_bot_mode():
		return "CPU: Balancer / Jukebox"
	return "CPU: Field Opponent"

func _async_prematch_rule_line() -> String:
	match _current_vs_mode():
		VS_MODE_ASYNC_SINGLE_MAP_TIMED:
			return "Rule: set your best map time."
		"TIMED_RACE":
			return "Rule: finish first across the run."
		"MISS_N_OUT":
			return "Rule: one miss ends the run."
		_:
			return "Rule: win fast, total time matters."

func _async_prematch_track_line() -> String:
	var tree: SceneTree = get_tree()
	if tree != null and bool(tree.get_meta("vs_free_roll", false)):
		return "Track: Free Play"
	return "Track: Ladder"

func _humanize_runtime_token(value: String) -> String:
	var clean: String = value.strip_edges().replace("res://", "").replace(".json", "")
	if clean.is_empty():
		return ""
	var parts: PackedStringArray = clean.replace("__", "_").split("_", false)
	var words: Array[String] = []
	for part_any in parts:
		var part: String = str(part_any).strip_edges()
		if part.is_empty():
			continue
		if part.length() == 1:
			words.append(part.to_upper())
			continue
		words.append(part.substr(0, 1).to_upper() + part.substr(1).to_lower())
	return " ".join(words)

func _record_key_for_roster_entry(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var uid: String = str(entry.get("uid", "")).strip_edges()
	if not uid.is_empty():
		return uid
	if bool(entry.get("is_cpu", false)):
		return "cpu"
	return ""

func _record_key_for_seat(seat: int) -> String:
	return _record_key_for_roster_entry(_get_roster_entry_for_slot(seat))

func _record_active_seats() -> Array[int]:
	var seats: Array[int] = []
	for seat in range(1, 5):
		var entry: Dictionary = _get_roster_entry_for_slot(seat)
		if entry.is_empty():
			continue
		if bool(entry.get("active", seat <= 2)):
			seats.append(seat)
	return seats

func _commit_match_records(winner_slot: int) -> void:
	if _match_record_committed:
		return
	if winner_slot <= 0:
		return
	var winner_key: String = _record_key_for_seat(winner_slot)
	var loser_keys: Array[String] = []
	var loser_seen: Dictionary = {}
	var active_seats: Array[int] = _record_active_seats()
	for seat in active_seats:
		if seat == winner_slot:
			continue
		var key: String = _record_key_for_seat(seat)
		if key.is_empty() or loser_seen.has(key):
			continue
		loser_seen[key] = true
		loser_keys.append(key)
	var p1_key: String = _record_key_for_seat(1)
	var p2_key: String = _record_key_for_seat(2)
	_match_records.record_match(winner_key, loser_keys, p1_key, p2_key)
	_match_record_committed = true
	_refresh_prematch_records()
	SFLog.info("MATCH_RECORDS_COMMIT", {
		"winner_slot": winner_slot,
		"winner_key": winner_key,
		"loser_keys": loser_keys,
		"h2h_p1": p1_key,
		"h2h_p2": p2_key
	})

func _ensure_match_roster() -> void:
	var roster: Array = OpsState.match_roster
	if (roster == null or roster.is_empty()) and get_tree() != null:
		roster = _match_roster_from_vs_tree_meta(get_tree())
	var local_uid: String = ProfileManager.get_user_id()
	var active_seats_lookup: Dictionary = _active_seat_lookup_from_state()
	var had_roster: bool = roster != null and roster.size() > 0
	var updated: bool = false
	if roster == null:
		roster = []
	var seat_map: Dictionary = {}
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var seat: int = int(entry.get("seat", 0))
		if seat <= 0:
			continue
		seat_map[seat] = entry
	var desired_local_seat: int = -1
	for seat_any in seat_map.keys():
		var seat_entry_any: Variant = seat_map.get(seat_any, {})
		if typeof(seat_entry_any) != TYPE_DICTIONARY:
			continue
		var seat_entry: Dictionary = seat_entry_any as Dictionary
		if not bool(seat_entry.get("is_local", false)):
			continue
		var seat_id: int = int(seat_entry.get("seat", int(seat_any)))
		if seat_id >= 1 and seat_id <= 4:
			desired_local_seat = seat_id
			break
	if desired_local_seat == -1 and not local_uid.is_empty():
		for seat_any in seat_map.keys():
			var uid_entry_any: Variant = seat_map.get(seat_any, {})
			if typeof(uid_entry_any) != TYPE_DICTIONARY:
				continue
			var uid_entry: Dictionary = uid_entry_any as Dictionary
			var seat_uid: String = str(uid_entry.get("uid", "")).strip_edges()
			if seat_uid != local_uid:
				continue
			var uid_seat: int = int(uid_entry.get("seat", int(seat_any)))
			if uid_seat >= 1 and uid_seat <= 4:
				desired_local_seat = uid_seat
				break
	if desired_local_seat == -1:
		desired_local_seat = 1
	for seat in range(1, 5):
		var entry: Dictionary = {}
		if seat_map.has(seat) and typeof(seat_map.get(seat)) == TYPE_DICTIONARY:
			entry = seat_map.get(seat) as Dictionary
		if entry.is_empty():
			var active: bool = bool(active_seats_lookup.get(seat, seat <= 2))
			var is_cpu: bool = seat != desired_local_seat and active
			entry = {
				"seat": seat,
				"uid": "",
				"is_local": seat == desired_local_seat,
				"is_cpu": is_cpu,
				"active": active
			}
			updated = true
		else:
			if not entry.has("active"):
				entry["active"] = bool(active_seats_lookup.get(seat, seat <= 2))
				updated = true
			if not entry.has("is_cpu"):
				var default_cpu: bool = seat != desired_local_seat and bool(entry.get("active", false))
				entry["is_cpu"] = default_cpu
				updated = true
			if seat != desired_local_seat:
				var seat_active: bool = bool(entry.get("active", false))
				var seat_uid: String = str(entry.get("uid", "")).strip_edges()
				if seat_active and seat_uid == "" and not bool(entry.get("is_cpu", false)):
					entry["is_cpu"] = true
					updated = true
				if not seat_active and bool(entry.get("is_cpu", false)) and seat_uid != "":
					entry["is_cpu"] = false
					updated = true
		var should_be_local: bool = seat == desired_local_seat
		if bool(entry.get("is_local", false)) != should_be_local:
			entry["is_local"] = should_be_local
			updated = true
		if should_be_local and not local_uid.is_empty():
			var prev_uid: String = str(entry.get("uid", ""))
			if prev_uid != local_uid:
				entry["uid"] = local_uid
				entry["is_local"] = true
				entry["is_cpu"] = false
				entry["active"] = true
				updated = true
		seat_map[seat] = entry
	var next_roster: Array = []
	for seat in range(1, 5):
		next_roster.append(seat_map.get(seat, {"seat": seat, "uid": "", "is_local": seat == desired_local_seat, "is_cpu": seat != desired_local_seat}))
	if updated or not had_roster:
		OpsState.sim_mutate("Arena._ensure_match_roster", func() -> void:
			_audit_ops_write("match_roster", "Arena._ensure_match_roster")
			OpsState.match_roster = next_roster
		)
		SFLog.info("MATCH_ROSTER", {
			"local_uid": local_uid,
			"p1_uid": str((next_roster[0] as Dictionary).get("uid", "")),
			"p2_uid": str((next_roster[1] as Dictionary).get("uid", "")),
			"p3_uid": str((next_roster[2] as Dictionary).get("uid", "")),
			"p4_uid": str((next_roster[3] as Dictionary).get("uid", ""))
		})
	else:
		OpsState.sim_mutate("Arena._ensure_match_roster", func() -> void:
			_audit_ops_write("match_roster", "Arena._ensure_match_roster")
			OpsState.match_roster = next_roster
		)

func _match_roster_from_vs_tree_meta(tree: SceneTree) -> Array:
	if tree == null:
		return []
	var session_id: String = str(tree.get_meta("vs_handshake_session_id", "")).strip_edges()
	if session_id.is_empty():
		return []
	if not _vs_tree_meta_is_two_player_session(tree):
		return []
	var local_any: Variant = tree.get_meta("vs_local_profile", {})
	var remote_any: Variant = tree.get_meta("vs_remote_profile", {})
	if typeof(local_any) != TYPE_DICTIONARY or typeof(remote_any) != TYPE_DICTIONARY:
		return []
	var local_profile: Dictionary = local_any as Dictionary
	var remote_profile: Dictionary = remote_any as Dictionary
	var local_uid: String = str(local_profile.get("uid", "")).strip_edges()
	var remote_uid: String = str(remote_profile.get("uid", "")).strip_edges()
	if local_uid.is_empty() or remote_uid.is_empty():
		return []
	var role: String = str(tree.get_meta("vs_handshake_role", "host")).strip_edges().to_lower()
	var local_seat: int = 2 if role == "guest" else 1
	var remote_seat: int = 1 if local_seat == 2 else 2
	var seats: Dictionary = {}
	seats[local_seat] = {
		"seat": local_seat,
		"uid": local_uid,
		"display_name": str(local_profile.get("display_name", local_profile.get("name", "Player %d" % local_seat))).strip_edges(),
		"is_local": true,
		"is_cpu": false,
		"active": true,
		"team_id": local_seat
	}
	seats[remote_seat] = {
		"seat": remote_seat,
		"uid": remote_uid,
		"display_name": str(remote_profile.get("display_name", remote_profile.get("name", "Player %d" % remote_seat))).strip_edges(),
		"is_local": false,
		"is_cpu": bool(remote_profile.get("is_cpu", false)),
		"active": true,
		"team_id": remote_seat
	}
	var out: Array = []
	for seat in range(1, 5):
		if seats.has(seat):
			out.append(seats.get(seat))
		else:
			out.append({
				"seat": seat,
				"uid": "",
				"display_name": "",
				"is_local": false,
				"is_cpu": false,
				"active": false,
				"team_id": seat
			})
	return out

func _vs_tree_meta_is_two_player_session(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var required_players: int = int(tree.get_meta("vs_required_players", 2))
	if required_players > 2:
		return false
	var mode: String = str(tree.get_meta("vs_mode", "")).strip_edges().to_upper()
	if mode == "2V2" or mode == "3P FFA" or mode == "3P_FFA" or mode == "4P FFA" or mode == "4P_FFA":
		return false
	return true

func _active_seat_lookup_from_state() -> Dictionary:
	var active_lookup: Dictionary = {}
	if state != null:
		for hive_any in state.hives:
			var hive: HiveData = hive_any as HiveData
			if hive == null:
				continue
			var owner_id: int = int(hive.owner_id)
			if owner_id < 1 or owner_id > 4:
				continue
			active_lookup[owner_id] = true
	if active_lookup.is_empty():
		active_lookup[1] = true
		active_lookup[2] = true
	return active_lookup

func _get_roster_entry_for_slot(player_slot: int) -> Dictionary:
	var roster: Array = OpsState.match_roster if OpsState != null else []
	if roster == null or roster.is_empty():
		return {}
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		if int(entry.get("seat", -1)) != player_slot:
			continue
		return entry
	return {}

func _display_name_for_seat(seat: int, uid: String, is_cpu: bool) -> String:
	var entry: Dictionary = _get_roster_entry_for_slot(seat)
	var roster_name: String = str(entry.get("display_name", "")).strip_edges()
	if not roster_name.is_empty():
		return roster_name
	if not uid.is_empty():
		var handle: String = ProfileManager.get_handle(uid)
		if not handle.is_empty():
			return handle
	if is_cpu:
		return "CPU"
	return "Player %d" % seat

func _update_prematch_flow(delta: float) -> void:
	if OpsState.match_phase != OpsState.MatchPhase.PREMATCH:
		return
	_prematch_remaining_ms_f = max(0.0, _prematch_remaining_ms_f - delta * 1000.0)
	OpsState.sim_mutate("Arena._update_prematch_flow", func() -> void:
		OpsState.set_prematch_remaining_ms(int(ceil(_prematch_remaining_ms_f)), "Arena._update_prematch_flow")
	)
	if _capture_flag_selection_pending_for_local() and _prematch_remaining_ms_f <= 0.0:
		var timeout_result: Dictionary = OpsState.call("auto_complete_capture_flag_selection", _resolve_local_owner_id()) as Dictionary
		if bool(timeout_result.get("ok", false)):
			mark_render_dirty("ctf_flag_select_timeout")
			_show_capture_flag_toast("FLAG HIVE AUTO-ASSIGNED", 1450.0)
		else:
			SFLog.warn("CAPTURE_FLAG_SELECTION_TIMEOUT_FAILED", timeout_result)
	var sec_left: int = 0
	if _prematch_remaining_ms_f > 0.0:
		sec_left = int(ceil(_prematch_remaining_ms_f / 1000.0))
	if _prematch_countdown_label != null:
		_prematch_countdown_label.text = str(sec_left)
		_prematch_countdown_label.add_theme_color_override("font_color", _local_countdown_color())
		_prematch_countdown_label.visible = true
	var elapsed_ms: float = float(OpsState.prematch_duration_ms) - _prematch_remaining_ms_f
	if _should_show_prematch_identity_flow():
		if elapsed_ms >= float(_prematch_identity_card_show_ms()) and not _prematch_identity_card_faded:
			_fade_prematch_identity_card()
		if elapsed_ms >= float(_prematch_hive_focus_start_ms()) and not _prematch_hive_focus_started:
			_start_prematch_hive_focus_sequence()
	if _prematch_remaining_ms_f <= float(PREMATCH_COUNTDOWN_RETURN_MS) and not _prematch_countdown_return_started:
		_return_camera_to_gameplay_view()
	_refresh_capture_flag_prematch_prompt()
	if _uses_async_prematch_card():
		_refresh_prematch_records()
	if sec_left != _prematch_last_sec:
		_prematch_last_sec = sec_left
		SFLog.info("PREMATCH_TICK", {
			"ms": OpsState.prematch_remaining_ms,
			"sec": int(ceil(float(OpsState.prematch_remaining_ms) / 1000.0))
		})
	if _prematch_remaining_ms_f <= float(PREMATCH_UI_CROSSFADE_MS) and not _prematch_records_faded:
		_prematch_records_faded = true
		_fade_prematch_records()
	# Apply one final fit during prematch so RUNNING does not need a visible camera correction.
	if _prematch_remaining_ms_f <= float(PREMATCH_UI_CROSSFADE_MS) and not _prematch_final_fit_requested:
		_prematch_final_fit_requested = true
	if _prematch_remaining_ms_f <= 0.0 and not _prematch_countdown_faded:
		_prematch_countdown_faded = true
		_fade_prematch_countdown()

func _fade_prematch_records() -> void:
	if _prematch_records_panel == null:
		return
	SFLog.info("PREMATCH_RECORDS_FADE", {})
	var tween := create_tween()
	tween.tween_property(_prematch_records_panel, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func() -> void:
		if _prematch_records_panel != null:
			_prematch_records_panel.visible = false
	)

func _fade_prematch_countdown() -> void:
	if _prematch_countdown_label == null:
		_finish_prematch()
		return
	SFLog.info("PREMATCH_COUNTDOWN_FADE", {})
	var tween := create_tween()
	tween.tween_property(_prematch_countdown_label, "modulate:a", 0.0, 0.25)
	tween.finished.connect(_finish_prematch)

func _finish_prematch() -> void:
	if _capture_flag_selection_pending_for_local():
		var timeout_result: Dictionary = OpsState.call("auto_complete_capture_flag_selection", _resolve_local_owner_id()) as Dictionary
		if bool(timeout_result.get("ok", false)):
			mark_render_dirty("ctf_flag_select_timeout_finish")
		else:
			_refresh_capture_flag_prematch_prompt()
			return
	OpsState.sim_mutate("Arena._finish_prematch", func() -> void:
		OpsState.set_prematch_remaining_ms(0, "Arena._finish_prematch")
		_audit_ops_write("match_phase", "Arena._finish_prematch")
		OpsState.match_phase = OpsState.MatchPhase.RUNNING
		_audit_ops_write("input_locked", "Arena._finish_prematch")
		OpsState.input_locked = false
		_audit_ops_write("input_locked_reason", "Arena._finish_prematch")
		OpsState.input_locked_reason = ""
	)
	if _prematch_overlay != null:
		_prematch_overlay.visible = false
	if _prematch_identity_card != null:
		_prematch_identity_card.visible = false
	_clear_prematch_pulses()
	_arm_camera_transition_lock("prematch_to_running")
	_start_match_sim("prematch_complete")
	SFLog.warn("INPUT_UNLOCKED", {"reason": "prematch_complete"})

func _begin_power_bar_reveal() -> void:
	# UI observes OpsState; no sim-driven UI mutations.
	return

func _prewarm_render_assets() -> void:
	if _render_assets_prewarmed:
		return
	_render_assets_prewarmed = true
	var prewarm_t0_us: int = Time.get_ticks_usec()
	if unit_renderer != null and unit_renderer.has_method("prewarm_pool"):
		unit_renderer.call("prewarm_pool")
	if vfx_manager != null and vfx_manager.has_method("prewarm"):
		vfx_manager.call("prewarm")
	var duration_ms: float = float(Time.get_ticks_usec() - prewarm_t0_us) / 1000.0
	_publish_pool_runtime_telemetry({"match_prewarm_duration_ms": snappedf(duration_ms, 0.01)})

func _publish_pool_runtime_telemetry(extra: Dictionary = {}) -> void:
	if OpsState == null or not OpsState.has_method("update_runtime_telemetry"):
		return
	var patch: Dictionary = _pool_runtime_telemetry_snapshot()
	for key_any in extra.keys():
		patch[key_any] = extra.get(key_any)
	OpsState.call("update_runtime_telemetry", patch)

func _pool_runtime_telemetry_snapshot() -> Dictionary:
	var totals: Dictionary = {
		"pool_hits": 0,
		"pool_misses": 0,
		"pool_expansions": 0,
		"runtime_instantiates_avoided": 0,
		"active_pooled_objects": 0,
		"available_pooled_objects": 0,
		"total_pooled_objects": 0,
		"peak_pooled_objects": 0,
		"match_prewarm_duration_ms": 0.0
	}
	for source_any in [unit_renderer, vfx_manager]:
		var source: Object = source_any as Object
		if source == null or not source.has_method("get_pool_telemetry_snapshot"):
			continue
		var snapshot_any: Variant = source.call("get_pool_telemetry_snapshot")
		if typeof(snapshot_any) != TYPE_DICTIONARY:
			continue
		var snapshot: Dictionary = snapshot_any as Dictionary
		for key in [
			"pool_hits",
			"pool_misses",
			"pool_expansions",
			"runtime_instantiates_avoided",
			"active_pooled_objects",
			"available_pooled_objects",
			"total_pooled_objects",
			"peak_pooled_objects"
		]:
			totals[key] = int(totals.get(key, 0)) + int(snapshot.get(key, 0))
		totals["match_prewarm_duration_ms"] = maxf(
			float(totals.get("match_prewarm_duration_ms", 0.0)),
			float(snapshot.get("match_prewarm_duration_ms", 0.0))
		)
	return totals

func _start_match_sim(reason: String) -> void:
	if _match_started:
		return
	_match_started = true
	_post_match_analysis_summary.clear()
	_post_match_telemetry_path = ""
	_begin_match_telemetry_session(reason)
	_prewarm_render_assets()
	var iid := 0
	if sim_runner != null:
		iid = int(sim_runner.bound_iid)
		sim_runner.set_running(true, reason)
		sim_runner.log_pause_snapshot("arena_match_start")
	if _tutorial_section1_controller != null:
		_tutorial_section1_controller.apply_reading_pause()
	if floor_influence_system != null:
		floor_influence_system.notify_match_started()
	SFLog.info("MATCH_STARTED", {"iid": iid, "reason": reason})

func _pause_tutorial_message_sim() -> void:
	if sim_runner == null:
		return
	if sim_runner.running:
		sim_runner.set_running(false, "tutorial_message_pause")
		sim_runner.log_pause_snapshot("tutorial_message_pause")

func _resume_tutorial_message_sim() -> void:
	if sim_runner == null or OpsState == null:
		return
	if not _match_started:
		return
	if OpsState.match_phase != OpsState.MatchPhase.RUNNING or bool(OpsState.input_locked) or OpsState.is_ending_or_ended():
		return
	if not sim_runner.running:
		sim_runner.set_running(true, "tutorial_message_resume")
		sim_runner.log_pause_snapshot("tutorial_message_resume")

func _tutorial_hive_screen_pos(hive_id: int) -> Vector2:
	if state == null or hive_id <= 0:
		return Vector2(-9999.0, -9999.0)
	var hive: HiveData = state.find_hive_by_id(hive_id)
	if hive == null:
		return Vector2(-9999.0, -9999.0)
	var local_pos: Vector2 = _cell_center(hive.grid_pos)
	var world_pos: Vector2 = local_pos
	if map_root != null:
		world_pos = map_root.to_global(local_pos)
	var vp: Viewport = get_viewport()
	if vp == null:
		return world_pos
	return vp.get_canvas_transform() * world_pos

func _tutorial_buff_screen_pos() -> Vector2:
	var buff_strip: Control = get_node_or_null(SHELL_PLAYER_BUFF_STRIP_PATH) as Control
	if buff_strip == null:
		return Vector2(-9999.0, -9999.0)
	var slot_index: int = _tutorial_first_ready_buff_slot_index()
	var slot: Control = buff_strip.get_node_or_null("Center/SlotsRow/BuffSlot%d" % (slot_index + 1)) as Control
	if slot == null:
		return Vector2(-9999.0, -9999.0)
	var rect: Rect2 = slot.get_global_rect()
	return rect.position + (rect.size * 0.5)

func _tutorial_first_ready_buff_slot_index() -> int:
	var snapshot: Dictionary = get_buff_ui_snapshot()
	var players_v: Variant = snapshot.get("players", {})
	if typeof(players_v) != TYPE_DICTIONARY:
		return 0
	var players: Dictionary = players_v as Dictionary
	var player_v: Variant = players.get(_resolve_local_owner_id(), {})
	if typeof(player_v) != TYPE_DICTIONARY:
		player_v = players.get(str(_resolve_local_owner_id()), {})
	if typeof(player_v) != TYPE_DICTIONARY:
		return 0
	var slots_v: Variant = (player_v as Dictionary).get("slots", [])
	if typeof(slots_v) != TYPE_ARRAY:
		return 0
	for slot_any in slots_v as Array:
		if typeof(slot_any) != TYPE_DICTIONARY:
			continue
		var slot_data: Dictionary = slot_any as Dictionary
		if bool(slot_data.get("locked", true)):
			continue
		if bool(slot_data.get("active", false)) or bool(slot_data.get("consumed", false)):
			continue
		return clampi(int(slot_data.get("index", 0)), 0, 2)
	return 0

func _begin_match_telemetry_session(reason: String) -> void:
	_telemetry_active = false
	_post_match_analysis_summary.clear()
	_post_match_telemetry_path = ""
	if state == null:
		return
	if _match_telemetry_collector == null:
		_match_telemetry_collector = MatchTelemetryCollectorScript.new()
	if _match_telemetry_collector != null and _match_telemetry_collector.has_method("reset"):
		_match_telemetry_collector.call("reset")
	if _match_telemetry_collector == null or not _match_telemetry_collector.has_method("begin_match"):
		return
	if OpsState != null and OpsState.has_method("set_match_telemetry_collector"):
		OpsState.call("set_match_telemetry_collector", _match_telemetry_collector)
	var player_ids: Array[int] = _record_active_seats()
	if player_ids.is_empty():
		var owners_seen: Dictionary = {}
		for hive_any in state.hives:
			if not (hive_any is HiveData):
				continue
			var owner_id: int = int((hive_any as HiveData).owner_id)
			if owner_id <= 0:
				continue
			owners_seen[owner_id] = true
		for owner_key in owners_seen.keys():
			var owner_id_any: int = int(owner_key)
			if owner_id_any <= 0:
				continue
			player_ids.append(owner_id_any)
		player_ids.sort()
	if player_ids.is_empty():
		player_ids = [1, 2]
	var match_id: String = _resolve_telemetry_match_id(reason)
	var season_id: String = _resolve_telemetry_season_id()
	var map_id: String = _resolve_telemetry_map_id()
	var match_type: int = _resolve_telemetry_match_type()
	var start_utc_ms: int = _telemetry_utc_ms_now()
	var metadata_overrides: Dictionary = _resolve_telemetry_metadata_overrides(player_ids, match_type, reason)
	_match_telemetry_collector.call(
		"begin_match",
		match_id,
		season_id,
		map_id,
		match_type,
		player_ids,
		start_utc_ms,
		metadata_overrides
	)
	var active_any: Variant = false
	if _match_telemetry_collector.has_method("is_active"):
		active_any = _match_telemetry_collector.call("is_active")
	_telemetry_active = bool(active_any)
	if _telemetry_active:
		_record_match_start_analytics(match_id, season_id, map_id, match_type, start_utc_ms, metadata_overrides)
	if unit_system != null and unit_system.has_method("set_match_telemetry_collector"):
		unit_system.call("set_match_telemetry_collector", _match_telemetry_collector)
	if OpsState != null and OpsState.has_method("set_match_telemetry_collector"):
		OpsState.call("set_match_telemetry_collector", _match_telemetry_collector)
	SFLog.info("TELEMETRY_BEGIN", {
		"match_id": match_id,
		"season_id": season_id,
		"map_id": map_id,
		"match_type": match_type,
		"players": player_ids,
		"reason": reason,
		"config_version": str(metadata_overrides.get("config_version", "")),
		"config_hash": str(metadata_overrides.get("config_hash", "")),
		"config_source": str(metadata_overrides.get("config_source", ""))
	})

func _finalize_match_telemetry_session(winner_id_in: int) -> void:
	if not _telemetry_active:
		return
	if _match_telemetry_collector == null:
		_telemetry_active = false
		return
	var end_utc_ms: int = _telemetry_utc_ms_now()
	if not _match_telemetry_collector.has_method("finalize_match"):
		_telemetry_active = false
		return
	var telemetry_model: Variant = _match_telemetry_collector.call("finalize_match", winner_id_in, end_utc_ms)
	var summary_any: Variant = {}
	if _match_analyzer != null and _match_analyzer.has_method("analyze"):
		summary_any = _match_analyzer.call("analyze", telemetry_model, clampi(active_player_id, 1, 4))
	var summary: Dictionary = summary_any as Dictionary if typeof(summary_any) == TYPE_DICTIONARY else {}
	_post_match_analysis_summary = summary.duplicate(true)
	if _match_telemetry_collector.has_method("attach_analysis_summary"):
		_match_telemetry_collector.call("attach_analysis_summary", summary)
	var save_result_any: Variant = {}
	if _match_telemetry_collector.has_method("save_to_user_async"):
		save_result_any = _match_telemetry_collector.call("save_to_user_async", telemetry_model)
	elif _match_telemetry_collector.has_method("save_to_user"):
		save_result_any = _match_telemetry_collector.call("save_to_user", telemetry_model)
	var save_result: Dictionary = save_result_any as Dictionary if typeof(save_result_any) == TYPE_DICTIONARY else {}
	if bool(save_result.get("ok", false)) or bool(save_result.get("pending", false)):
		_post_match_telemetry_path = str(save_result.get("path", ""))
	else:
		_post_match_telemetry_path = ""
		SFLog.warn("TELEMETRY_SAVE_FAILED", save_result)
	var profile_result: Dictionary = {}
	if _player_telemetry_profiles != null and _player_telemetry_profiles.has_method("update_from_match"):
		var profile_result_any: Variant = _player_telemetry_profiles.call("update_from_match", telemetry_model)
		profile_result = profile_result_any as Dictionary if typeof(profile_result_any) == TYPE_DICTIONARY else {}
		if not bool(profile_result.get("ok", false)):
			SFLog.warn("PLAYER_TELEMETRY_PROFILE_UPDATE_FAILED", profile_result)
	_record_match_end_summary_analytics(telemetry_model, winner_id_in)
	_telemetry_active = false
	SFLog.info("TELEMETRY_FINALIZE", {
		"winner_id": winner_id_in,
		"summary_insights": int(_post_match_analysis_summary.get("insights", []).size()),
		"save_path": _post_match_telemetry_path,
		"profile_updated_player_ids": profile_result.get("updated_player_ids", [])
	})

func _poll_match_telemetry_async_save() -> void:
	if _match_telemetry_collector == null or not _match_telemetry_collector.has_method("poll_async_save"):
		return
	var result_any: Variant = _match_telemetry_collector.call("poll_async_save")
	if typeof(result_any) != TYPE_DICTIONARY:
		return
	var result: Dictionary = result_any as Dictionary
	if result.is_empty():
		return
	if bool(result.get("ok", false)):
		_post_match_telemetry_path = str(result.get("path", _post_match_telemetry_path))
		if OpsState != null and OpsState.has_method("update_runtime_telemetry"):
			OpsState.call("update_runtime_telemetry", {
				"post_match_save_duration_ms": snappedf(float(result.get("duration_ms", 0.0)), 0.01)
			})
		SFLog.info("TELEMETRY_ASYNC_SAVE_DONE", {"save_path": _post_match_telemetry_path})
	else:
		SFLog.warn("TELEMETRY_SAVE_FAILED", result)

func _telemetry_utc_ms_now() -> int:
	return int(round(Time.get_unix_time_from_system() * 1000.0))

func _resolve_telemetry_match_id(reason: String) -> String:
	var utc_ms: int = _telemetry_utc_ms_now()
	var map_id: String = _resolve_telemetry_map_id()
	var match_type: int = _resolve_telemetry_match_type()
	var reason_tag: String = reason.strip_edges().to_lower()
	if reason_tag == "":
		reason_tag = "start"
	var seed_tag: int = int(abs(match_seed)) % 1000000
	return "m_%d_%s_t%d_s%d_%s" % [utc_ms, map_id, match_type, seed_tag, reason_tag]

func _resolve_telemetry_season_id() -> String:
	var battle_pass_state: Node = get_node_or_null("/root/BattlePassState")
	if battle_pass_state != null and battle_pass_state.has_method("get_snapshot"):
		var snapshot_any: Variant = battle_pass_state.call("get_snapshot")
		if typeof(snapshot_any) == TYPE_DICTIONARY:
			var snapshot: Dictionary = snapshot_any as Dictionary
			var season_from_bp: String = str(snapshot.get("season_id", "")).strip_edges()
			if season_from_bp != "":
				return season_from_bp
	return "local_beta"

func _resolve_telemetry_map_id() -> String:
	var map_id: String = current_map_name.strip_edges()
	if map_id == "" and current_map_path != "":
		map_id = current_map_path.get_file()
	map_id = map_id.get_basename().strip_edges()
	if map_id == "":
		map_id = "unknown_map"
	return map_id

func _resolve_telemetry_match_type() -> int:
	if _is_async_stage_run_runtime_mode():
		return int(MatchTelemetryModelScript.MATCH_TYPE_ASYNC)
	if _vs_pvp_runtime != null and _vs_pvp_runtime.has_method("is_active"):
		if bool(_vs_pvp_runtime.call("is_active")):
			return int(MatchTelemetryModelScript.MATCH_TYPE_VS)
	var roster: Array = OpsState.match_roster if OpsState != null else []
	var active_count: int = 0
	var human_count: int = 0
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		if not bool(entry.get("active", true)):
			continue
		active_count += 1
		if not bool(entry.get("is_cpu", false)):
			human_count += 1
	if human_count >= 2:
		return int(MatchTelemetryModelScript.MATCH_TYPE_VS)
	if active_count >= 2:
		return int(MatchTelemetryModelScript.MATCH_TYPE_BOT)
	return int(MatchTelemetryModelScript.MATCH_TYPE_ASYNC)

func _resolve_telemetry_metadata_overrides(player_ids: Array[int], _match_type: int, reason: String) -> Dictionary:
	var players: Array[Dictionary] = _resolve_telemetry_player_snapshots(player_ids)
	var local_player_id: String = ""
	var opponent_player_ids: Array[String] = []
	for player in players:
		if bool(player.get("is_local", false)):
			local_player_id = str(player.get("player_id", "")).strip_edges()
			continue
		var opponent_player_id: String = str(player.get("player_id", "")).strip_edges()
		if opponent_player_id.is_empty():
			continue
		opponent_player_ids.append(opponent_player_id)
	var rank_state: Node = get_node_or_null("/root/RankState")
	var rank_transport_mode: String = ""
	var rank_authoritative_online: bool = false
	if rank_state != null:
		if rank_state.has_method("get_transport_mode"):
			rank_transport_mode = str(rank_state.call("get_transport_mode")).strip_edges()
		if rank_state.has_method("is_authoritative_transport_online"):
			rank_authoritative_online = bool(rank_state.call("is_authoritative_transport_online"))
	var tree: SceneTree = get_tree()
	var config_snapshot: Dictionary = {}
	if tree != null:
		var config_any: Variant = tree.get_meta("vs_config_snapshot", {})
		if typeof(config_any) == TYPE_DICTIONARY:
			config_snapshot = (config_any as Dictionary).duplicate(true)
	return {
		"vs_mode": _current_vs_mode(),
		"start_reason": reason.strip_edges(),
		"map_path": current_map_path,
		"map_data": current_map_data.duplicate(true),
		"local_player_id": local_player_id,
		"opponent_player_ids": opponent_player_ids,
		"players": players,
		"player_loadouts": _resolve_telemetry_player_loadouts(player_ids),
		"cosmetics": _resolve_telemetry_cosmetics(),
		"rank_transport_mode": rank_transport_mode,
		"rank_authoritative_online": rank_authoritative_online,
		"config_version": str(config_snapshot.get("config_version", "")),
		"config_hash": str(config_snapshot.get("config_hash", "")),
		"config_source": str(config_snapshot.get("config_source", "")),
		"config_snapshot": config_snapshot
	}

func _resolve_telemetry_player_loadouts(player_ids: Array[int]) -> Dictionary:
	var out: Dictionary = {}
	for player_id in player_ids:
		out[str(player_id)] = {
			"buffs": _default_buff_loadout(player_id)
		}
	return out

func _resolve_telemetry_cosmetics() -> Dictionary:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager == null:
		return {}
	var out: Dictionary = {}
	if profile_manager.has_method("get_garage_selections"):
		var selections_any: Variant = profile_manager.call("get_garage_selections")
		if typeof(selections_any) == TYPE_DICTIONARY:
			out["garage_selections"] = (selections_any as Dictionary).duplicate(true)
	if profile_manager.has_method("get_powerbar_theme"):
		out["powerbar_theme"] = str(profile_manager.call("get_powerbar_theme"))
	return out

func _resolve_telemetry_player_snapshots(player_ids: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var local_profile: Dictionary = _telemetry_tree_profile("vs_local_profile")
	var remote_profile: Dictionary = _telemetry_tree_profile("vs_remote_profile")
	for seat in player_ids:
		var entry: Dictionary = _get_roster_entry_for_slot(seat)
		var is_local: bool = bool(entry.get("is_local", false))
		var is_cpu: bool = bool(entry.get("is_cpu", false))
		var player_id: String = str(entry.get("uid", "")).strip_edges()
		var display_name: String = str(entry.get("display_name", "")).strip_edges()
		var profile_hint: Dictionary = local_profile if is_local else remote_profile
		if player_id.is_empty():
			player_id = _telemetry_profile_player_id(profile_hint)
		if display_name.is_empty():
			display_name = _telemetry_profile_display_name(profile_hint)
		if display_name.is_empty():
			display_name = _display_name_for_seat(seat, player_id, is_cpu)
		var snapshot: Dictionary = {
			"seat": seat,
			"player_id": player_id,
			"display_name": display_name,
			"is_local": is_local,
			"is_cpu": is_cpu,
			"active": bool(entry.get("active", true))
		}
		if is_cpu and OpsState != null and OpsState.has_method("get_bot_profile"):
			var bot_profile_any: Variant = OpsState.call("get_bot_profile", seat)
			if typeof(bot_profile_any) == TYPE_DICTIONARY:
				var bot_profile: Dictionary = bot_profile_any as Dictionary
				snapshot["bot_style"] = str(bot_profile.get("style", bot_profile.get("persona", ""))).strip_edges()
				snapshot["bot_tier"] = str(bot_profile.get("tier", "")).strip_edges()
		var rank_snapshot: Dictionary = _telemetry_rank_snapshot_for_player_id(player_id)
		if not rank_snapshot.is_empty():
			snapshot["rank_position"] = int(rank_snapshot.get("rank_position", 0))
			snapshot["tier_id"] = str(rank_snapshot.get("tier_id", "")).strip_edges()
			snapshot["percentile"] = float(rank_snapshot.get("percentile", 0.0))
			snapshot["wax_score"] = float(rank_snapshot.get("wax_score", 0.0))
			snapshot["rank_region"] = str(rank_snapshot.get("region", "")).strip_edges()
			snapshot["rank_snapshot_source"] = "rank_state"
		out.append(snapshot)
	return out

func _telemetry_rank_snapshot_for_player_id(player_id: String) -> Dictionary:
	var clean_player_id: String = player_id.strip_edges()
	if clean_player_id.is_empty():
		return {}
	var rank_state: Node = get_node_or_null("/root/RankState")
	if rank_state == null or not rank_state.has_method("get_player_snapshot"):
		return {}
	var snapshot_any: Variant = rank_state.call("get_player_snapshot", clean_player_id)
	if typeof(snapshot_any) != TYPE_DICTIONARY:
		return {}
	return (snapshot_any as Dictionary).duplicate(true)

func _telemetry_tree_profile(meta_key: String) -> Dictionary:
	var tree: SceneTree = get_tree()
	if tree == null or not tree.has_meta(meta_key):
		return {}
	var profile_any: Variant = tree.get_meta(meta_key, {})
	if typeof(profile_any) != TYPE_DICTIONARY:
		return {}
	return (profile_any as Dictionary).duplicate(true)

func _telemetry_profile_player_id(profile: Dictionary) -> String:
	if profile.is_empty():
		return ""
	var player_id: String = str(profile.get("uid", profile.get("player_id", ""))).strip_edges()
	if not player_id.is_empty():
		return player_id
	return ""

func _telemetry_profile_display_name(profile: Dictionary) -> String:
	if profile.is_empty():
		return ""
	var display_name: String = str(profile.get("display_name", profile.get("name", profile.get("handle", "")))).strip_edges()
	if not display_name.is_empty():
		return display_name
	return ""

func _bind_powerbar_signals() -> void:
	# UI observes OpsState; no sim-driven UI mutations.
	return

func _on_ops_state_changed_for_powerbar(_payload: Variant = null) -> void:
	# UI observes OpsState; no sim-driven UI mutations.
	return

func _get_power_bar() -> Node:
	if power_bar != null:
		return power_bar
	power_bar = _resolve_power_bar_node()
	return power_bar

func _compute_team_power_totals(state_ref: Object) -> Dictionary:
	var totals: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
	var ignored: int = 0
	if state_ref == null:
		return {"totals": totals, "ignored": ignored}
	var hives: Array = []
	if state_ref is GameState:
		hives = (state_ref as GameState).hives
	elif state_ref.has_method("get_hives"):
		var hives_any: Variant = state_ref.call("get_hives")
		if typeof(hives_any) == TYPE_ARRAY:
			hives = hives_any as Array
	elif state_ref.has_method("get"):
		var maybe_hives: Variant = state_ref.call("get", "hives")
		if typeof(maybe_hives) == TYPE_ARRAY:
			hives = maybe_hives as Array
	for hive_any in hives:
		if hive_any == null:
			continue
		var owner_id: int = 0
		var power: int = 0
		if hive_any is HiveData:
			var hive_data: HiveData = hive_any as HiveData
			owner_id = int(hive_data.owner_id)
			power = int(hive_data.power)
		elif typeof(hive_any) == TYPE_DICTIONARY:
			var hive_dict: Dictionary = hive_any as Dictionary
			owner_id = int(hive_dict.get("owner_id", 0))
			power = int(hive_dict.get("power", 0))
		elif typeof(hive_any) == TYPE_OBJECT and hive_any != null and hive_any.has_method("get"):
			owner_id = int(hive_any.get("owner_id"))
			power = int(hive_any.get("power"))
		if owner_id < 1 or owner_id > 4:
			ignored += 1
			continue
		totals[owner_id] = int(totals.get(owner_id, 0)) + power
	return {"totals": totals, "ignored": ignored}

func _resolve_local_owner_id() -> int:
	var roster: Array = OpsState.match_roster
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		if bool(entry.get("is_local", false)):
			var seat: int = int(entry.get("seat", 1))
			if seat >= 1 and seat <= 4:
				return seat
	return 1

func _capture_flag_selection_pending_for_local() -> bool:
	if OpsState == null or not OpsState.has_method("is_capture_flag_selection_pending"):
		return false
	return bool(OpsState.call("is_capture_flag_selection_pending", _resolve_local_owner_id()))

func _hidden_capture_flag_enabled() -> bool:
	if OpsState == null or not OpsState.has_method("get_victory_rules"):
		return false
	var rules_any: Variant = OpsState.call("get_victory_rules")
	if typeof(rules_any) != TYPE_DICTIONARY:
		return false
	var rules: Dictionary = rules_any as Dictionary
	return bool(rules.get("hidden_flag", false))

func _refresh_capture_flag_prematch_prompt() -> void:
	if _prematch_ctf_panel == null or _prematch_ctf_title == null or _prematch_ctf_body == null:
		return
	var ctf_enabled: bool = OpsState != null and OpsState.has_method("is_capture_flag_mode") and bool(OpsState.call("is_capture_flag_mode"))
	if not ctf_enabled or OpsState.match_phase != OpsState.MatchPhase.PREMATCH:
		_prematch_ctf_panel.visible = false
		_layout_prematch_ad_surface()
		return
	_layout_capture_flag_instruction_panel(_prematch_ctf_panel)
	_prematch_ctf_panel.visible = true
	_layout_prematch_ad_surface()
	var sec_left: int = maxi(0, int(ceil(_prematch_remaining_ms_f / 1000.0)))
	var hidden_mode: bool = _hidden_capture_flag_enabled()
	if _capture_flag_selection_pending_for_local():
		_prematch_ctf_title.text = "SELECT YOUR FLAG HIVE"
		if hidden_mode:
			_prematch_ctf_body.text = "Tap one of your own hives to hide your flag.\nIf you do not choose in %ds, the game will assign balanced fallback hives without mirroring.\nLater: tap MOVE FLAG under the power bar, then click a new owned hive. Moving reveals it." % sec_left
		else:
			_prematch_ctf_body.text = "Tap one of your own hives to lock your flag.\nIf you do not choose in %ds, the game will assign a mirrored fallback pair.\nBoth sides will know the flag locations in this mode." % sec_left
	else:
		_prematch_ctf_title.text = "FLAG HIVE LOCKED"
		if hidden_mode:
			_prematch_ctf_body.text = "Protect the hive marked FLAG.\nDuring the match: tap MOVE FLAG under the power bar, then click a new owned hive.\nMoving reveals it."
		else:
			_prematch_ctf_body.text = "Protect the hive marked FLAG.\nThis is standard CTF, so flag movement is disabled."

func _show_capture_flag_toast(message: String, duration_ms: float = 1400.0) -> void:
	if tie_toast == null:
		return
	tie_toast.text = message
	tie_toast.visible = true
	tie_toast_ms = maxf(0.0, duration_ms)

func _clear_capture_flag_move_arm() -> void:
	_set_capture_flag_move_armed(false)

func _try_handle_capture_flag_press(local_pos: Vector2, button_index: int) -> bool:
	if api == null or state == null or OpsState == null:
		return false
	if not OpsState.has_method("is_capture_flag_mode") or not bool(OpsState.call("is_capture_flag_mode")):
		return false
	if button_index != MOUSE_BUTTON_LEFT:
		return false
	var local_owner_id: int = _resolve_local_owner_id()
	var hive_id: int = api.pick_hive_id_local(local_pos)
	if int(OpsState.match_phase) == int(OpsState.MatchPhase.PREMATCH):
		if not _capture_flag_selection_pending_for_local():
			return false
		if hive_id <= 0:
			_show_capture_flag_toast("SELECT ONE OF YOUR HIVES", 1000.0)
			return true
		var hive_pre: HiveData = state.find_hive_by_id(hive_id)
		if hive_pre == null or int(hive_pre.owner_id) != local_owner_id:
			_show_capture_flag_toast("SELECT ONE OF YOUR HIVES", 1000.0)
			return true
		var select_result: Dictionary = OpsState.call("request_capture_flag_selection", local_owner_id, hive_id) as Dictionary
		if bool(select_result.get("ok", false)):
			_refresh_capture_flag_prematch_prompt()
			_show_capture_flag_toast("FLAG HIVE LOCKED", 1100.0)
			mark_render_dirty("ctf_flag_select")
		else:
			_show_capture_flag_toast("FLAG SELECT FAILED", 1000.0)
		return true
	if int(OpsState.match_phase) != int(OpsState.MatchPhase.RUNNING):
		return false
	var flag_state: Dictionary = OpsState.call("get_capture_flag_for_owner", local_owner_id) as Dictionary
	if flag_state.is_empty():
		return false
	if not _hidden_capture_flag_enabled():
		_clear_capture_flag_move_arm()
		return false
	var current_flag_hive_id: int = int(flag_state.get("hive_id", 0))
	var moves_remaining: int = int(flag_state.get("moves_remaining", 0))
	if _ctf_move_armed:
		if hive_id <= 0:
			_show_capture_flag_toast("SELECT A NEW OWNED HIVE", 900.0)
			return true
		var move_target: HiveData = state.find_hive_by_id(hive_id)
		if move_target == null or int(move_target.owner_id) != local_owner_id:
			_show_capture_flag_toast("MOVE TO YOUR OWN HIVE", 1000.0)
			return true
		if int(move_target.id) == current_flag_hive_id:
			_show_capture_flag_toast("SELECT A DIFFERENT OWNED HIVE", 1000.0)
			return true
		var move_result: Dictionary = OpsState.call("request_capture_flag_move", local_owner_id, int(move_target.id)) as Dictionary
		_set_capture_flag_move_armed(false)
		if bool(move_result.get("ok", false)):
			_clear_selection()
			mark_render_dirty("ctf_flag_move")
			_push_render_model()
			_show_capture_flag_toast("FLAG MOVED AND REVEALED", 1500.0)
		else:
			_show_capture_flag_toast("FLAG MOVE FAILED", 1000.0)
		return true
	if moves_remaining <= 0:
		_clear_capture_flag_move_arm()
		return false
	return false

func _update_power_bar_from_state(reason: String) -> void:
	# UI observes OpsState; no sim-driven UI mutations.
	return

func _init_systems() -> void:
	api = ArenaAPI.new(self)
	input_system = _create_system("res://scripts/systems/input_system.gd", "input") as InputSystem
	if input_system != null:
		input_system.setup(sel)
	tower_renderer = tower_renderer_node as TowerRenderer
	_ensure_sim_events()
	_ensure_vfx_manager()
	_ensure_unit_renderer()
	enable_floor_influence_runtime = _floor_graphics_pref_enabled()
	_ensure_floor_influence_system()
	_ensure_sim_runner()
	if sim_runner != null:
		lane_system = sim_runner.get_lane_system()
		tower_system = sim_runner.get_tower_system()
		swarm_system = sim_runner.swarm_system
		barracks_system = sim_runner.get_barracks_system()
	if lane_system != null:
		if not lane_system.lane_created.is_connected(_on_lane_system_changed):
			lane_system.lane_created.connect(_on_lane_system_changed)
		if not lane_system.lane_updated.is_connected(_on_lane_system_changed):
			lane_system.lane_updated.connect(_on_lane_system_changed)
		if not lane_system.lane_removed.is_connected(_on_lane_system_removed):
			lane_system.lane_removed.connect(_on_lane_system_removed)
	if input_system != null:
		input_system.set_lane_system(lane_system)
	if tower_system != null:
		tower_system.set_buff_mod_provider(Callable(self, "_buff_mod"))
		if sim_events != null and tower_system.has_method("set_sim_events"):
			tower_system.set_sim_events(sim_events)
	if swarm_system != null and sim_events != null and swarm_system.has_method("set_sim_events"):
		swarm_system.set_sim_events(sim_events)
	if unit_system != null and sim_events != null and unit_system.has_method("set_sim_events"):
		unit_system.set_sim_events(sim_events)
	if unit_renderer != null and sim_events != null and unit_renderer.has_method("set_sim_events"):
		unit_renderer.call("set_sim_events", sim_events)
	if unit_system != null and unit_system.has_method("set_match_telemetry_collector"):
		unit_system.call("set_match_telemetry_collector", _match_telemetry_collector)
	if OpsState != null and OpsState.has_method("set_match_telemetry_collector"):
		OpsState.call("set_match_telemetry_collector", _match_telemetry_collector)
	if barracks_system != null:
		if not barracks_system.barracks_activated.is_connected(_on_barracks_activated):
			barracks_system.barracks_activated.connect(_on_barracks_activated)
	debug_system = _create_system("res://scripts/systems/debug_system.gd", "debug") as DebugSystem
	audio_system = _create_system("res://scripts/systems/audio_system.gd", "audio") as AudioSystem
	if audio_system != null:
		audio_system.setup(coin_player)

func _ensure_sim_runner() -> void:
	if sim_runner == null or not is_instance_valid(sim_runner):
		var existing := get_node_or_null("SimRunner")
		if existing != null and existing is SimRunner:
			sim_runner = existing
		else:
			sim_runner = SimRunner.new()
			sim_runner.name = "SimRunner"
			add_child(sim_runner)
	sim_runner.set_process(true)
	sim_runner.autostart = _autostart_shadow
	if not sim_runner.sim_ticked.is_connected(_on_sim_ticked):
		sim_runner.sim_ticked.connect(_on_sim_ticked)
	if not sim_runner.match_ended.is_connected(_on_match_ended):
		sim_runner.match_ended.connect(_on_match_ended)
	if not sim_runner.post_match_action.is_connected(_on_post_match_action):
		sim_runner.post_match_action.connect(_on_post_match_action)
	unit_system = sim_runner.unit_system if sim_runner != null else null
	swarm_system = sim_runner.swarm_system if sim_runner != null else null
	if swarm_system != null and sim_events != null and swarm_system.has_method("set_sim_events"):
		swarm_system.set_sim_events(sim_events)
	if unit_system != null and unit_system.has_method("set_match_telemetry_collector"):
		unit_system.call("set_match_telemetry_collector", _match_telemetry_collector)
	if OpsState != null and OpsState.has_method("set_match_telemetry_collector"):
		OpsState.call("set_match_telemetry_collector", _match_telemetry_collector)

func _ensure_sim_events() -> void:
	if sim_events != null and is_instance_valid(sim_events):
		_wire_tower_shot_sfx()
		_wire_swarm_sfx()
		_wire_hive_owner_sfx()
		return
	var existing := get_node_or_null("SimEvents")
	if existing is SimEvents:
		sim_events = existing as SimEvents
		_wire_tower_shot_sfx()
		_wire_swarm_sfx()
		_wire_hive_owner_sfx()
		return
	sim_events = SimEvents.new()
	sim_events.name = "SimEvents"
	add_child(sim_events)
	_wire_tower_shot_sfx()
	_wire_swarm_sfx()
	_wire_hive_owner_sfx()

func _wire_tower_shot_sfx() -> void:
	if sim_events == null or not is_instance_valid(sim_events):
		return
	var cb := Callable(self, "_on_tower_fire_for_sfx")
	if not sim_events.is_connected("tower_fire", cb):
		sim_events.connect("tower_fire", cb)

func _wire_swarm_sfx() -> void:
	if sim_events == null or not is_instance_valid(sim_events):
		return
	var spawned_cb: Callable = Callable(self, "_on_swarm_spawned_for_sfx")
	if not sim_events.is_connected("swarm_spawned", spawned_cb):
		sim_events.connect("swarm_spawned", spawned_cb)
	var landed_cb: Callable = Callable(self, "_on_swarm_landed_for_sfx")
	if sim_events.has_signal("swarm_landed") and not sim_events.is_connected("swarm_landed", landed_cb):
		sim_events.connect("swarm_landed", landed_cb)

func _wire_hive_owner_sfx() -> void:
	if sim_events == null or not is_instance_valid(sim_events):
		return
	var cb := Callable(self, "_on_hive_owner_changed_for_sfx")
	if not sim_events.is_connected("hive_owner_changed", cb):
		sim_events.connect("hive_owner_changed", cb)

func _ensure_pools_root() -> Node:
	var pools_root: Node = get_node_or_null("PoolsRoot")
	if pools_root == null:
		var new_pools: Node2D = Node2D.new()
		new_pools.name = "PoolsRoot"
		new_pools.position = Vector2.ZERO
		add_child(new_pools)
		pools_root = new_pools
	return pools_root

func _ensure_floor_influence_system() -> void:
	if not enable_floor_influence_runtime:
		if floor_influence_system != null and is_instance_valid(floor_influence_system):
			floor_influence_system.queue_free()
			floor_influence_system = null
		if floor_renderer != null:
			var base_floor: Sprite2D = floor_renderer.get_base_floor_sprite()
			var overlay_floor: Sprite2D = floor_renderer.get_overlay_floor_sprite()
			if base_floor != null and is_instance_valid(base_floor):
				base_floor.material = null
			if overlay_floor != null and is_instance_valid(overlay_floor):
				overlay_floor.material = null
		return
	if floor_renderer == null:
		return
	var pools_root: Node = _ensure_pools_root()
	if pools_root == null:
		return
	if floor_influence_system == null or not is_instance_valid(floor_influence_system):
		var existing: Node = pools_root.get_node_or_null("ArenaFloorInfluenceSystem")
		if existing is ArenaFloorInfluenceSystem:
			floor_influence_system = existing as ArenaFloorInfluenceSystem
		else:
			floor_influence_system = ArenaFloorInfluenceSystem.new()
			floor_influence_system.name = "ArenaFloorInfluenceSystem"
			pools_root.add_child(floor_influence_system)
	if floor_influence_system != null:
		floor_influence_system.setup(map_root, pools_root, floor_renderer)
		floor_influence_system.set_debug_enabled(show_floor_influence_debug)

func set_floor_influence_debug(enabled: bool) -> void:
	show_floor_influence_debug = enabled
	if floor_influence_system != null:
		floor_influence_system.set_debug_enabled(enabled)

func _resolve_unit_renderer() -> Node2D:
	var pools_node: Node = get_node_or_null("PoolsRoot/UnitRenderer")
	if pools_node is Node2D:
		return pools_node as Node2D
	var map_node: Node = get_node_or_null("MapRoot/UnitRenderer")
	if map_node is Node2D:
		return map_node as Node2D
	return null

func _ensure_unit_renderer() -> void:
	var pools_root: Node = _ensure_pools_root()
	var existing: Node = pools_root.get_node_or_null("UnitRenderer")
	if existing is Node2D:
		unit_renderer = existing as Node2D
	else:
		var map_existing: Node = null
		if map_root != null:
			map_existing = map_root.get_node_or_null("UnitRenderer")
		if map_existing is Node2D:
			unit_renderer = map_existing as Node2D
			if unit_renderer.get_parent() != pools_root:
				unit_renderer.reparent(pools_root)
			unit_renderer.name = "UnitRenderer"
		else:
			unit_renderer = null
	if unit_renderer != null:
		if sim_events != null and unit_renderer.has_method("set_sim_events"):
			unit_renderer.call("set_sim_events", sim_events)
		if TRACE_ARENA_PRINTS:
			print("UNIT_PARENT:", _node_path_for_log(unit_renderer))

func _ensure_wall_renderer() -> void:
	if wall_renderer != null and is_instance_valid(wall_renderer):
		return
	var existing: WallRenderer = get_node_or_null("WallRenderer") as WallRenderer
	if existing != null:
		wall_renderer = existing
		return
	wall_renderer = WallRenderer.new()
	wall_renderer.name = "WallRenderer"
	wall_renderer.z_index = -4
	call_deferred("add_child", wall_renderer)

func _ensure_vfx_manager() -> void:
	if vfx_manager != null and is_instance_valid(vfx_manager):
		var pools_parent: Node = _ensure_pools_root()
		if pools_parent != null and vfx_manager.get_parent() != pools_parent:
			vfx_manager.reparent(pools_parent)
			SFLog.allow_tag("VFX_REPARENT")
			SFLog.warn("VFX_REPARENT", {
				"target_parent": _node_path_for_log(pools_parent),
				"node_path": _node_path_for_log(vfx_manager)
			})
		_configure_vfx_manager()
		return
	var pools_root: Node = _ensure_pools_root()

	var existing: Node = pools_root.get_node_or_null("VfxManager")
	if existing is VfxManager:
		vfx_manager = existing as VfxManager
	else:
		var map_existing: Node = null
		if map_root != null:
			map_existing = map_root.get_node_or_null("VfxManager")
		if map_existing is VfxManager:
			vfx_manager = map_existing as VfxManager
			if vfx_manager.get_parent() != pools_root:
				vfx_manager.reparent(pools_root)
		else:
			vfx_manager = VfxManager.new()
			vfx_manager.name = "VfxManager"
			pools_root.add_child(vfx_manager)
	if TRACE_ARENA_PRINTS:
		print("VFX_PARENT:", _node_path_for_log(vfx_manager))
	if vfx_manager != null and vfx_manager.get_parent() != pools_root:
		vfx_manager.reparent(pools_root)
		SFLog.allow_tag("VFX_REPARENT")
		SFLog.warn("VFX_REPARENT", {
			"target_parent": _node_path_for_log(pools_root),
			"node_path": _node_path_for_log(vfx_manager)
		})

func _record_match_end_summary_analytics(telemetry_model: Variant, winner_id_in: int) -> void:
	var analytics: Node = get_node_or_null("/root/AnalyticsClient")
	if analytics == null or not analytics.has_method("record_match_end_summary"):
		return
	var payload: Dictionary = {}
	if telemetry_model != null and telemetry_model.has_method("to_dict"):
		var payload_any: Variant = telemetry_model.call("to_dict")
		if typeof(payload_any) == TYPE_DICTIONARY:
			payload = payload_any as Dictionary
	if payload.is_empty():
		return
	var metadata: Dictionary = payload.get("metadata", {}) as Dictionary
	var match_type: int = int(metadata.get("match_type", 0))
	var props: Dictionary = {
		"match_id": str(metadata.get("match_id", "match_%d" % Time.get_ticks_msec())),
		"season_id": str(metadata.get("season_id", "dev")),
		"map_id": str(metadata.get("map_id", "unknown")),
		"match_type": _telemetry_match_type_label(match_type),
		"duration_ms": int(round(float(metadata.get("duration_s", 0.0)) * 1000.0)),
		"winner": str(winner_id_in),
		"vs_mode": str(metadata.get("vs_mode", "")),
		"config_version": str(metadata.get("config_version", "")),
		"config_hash": str(metadata.get("config_hash", "")),
		"config_source": str(metadata.get("config_source", ""))
	}
	analytics.call("record_match_end_summary", props)
	_configure_vfx_manager()

func _record_match_start_analytics(
		match_id: String,
		season_id: String,
		map_id: String,
		match_type: int,
		start_utc_ms: int,
		metadata: Dictionary
	) -> void:
	var analytics: Node = get_node_or_null("/root/AnalyticsClient")
	if analytics == null or not analytics.has_method("record_match_start"):
		return
	var props: Dictionary = {
		"match_id": match_id,
		"season_id": season_id,
		"map_id": map_id,
		"match_type": _telemetry_match_type_label(match_type),
		"start_utc_ms": start_utc_ms,
		"vs_mode": str(metadata.get("vs_mode", "")),
		"config_version": str(metadata.get("config_version", "")),
		"config_hash": str(metadata.get("config_hash", "")),
		"config_source": str(metadata.get("config_source", ""))
	}
	analytics.call("record_match_start", props)

func _telemetry_match_type_label(match_type: int) -> String:
	if match_type == int(MatchTelemetryModelScript.MATCH_TYPE_VS):
		return "VS"
	if match_type == int(MatchTelemetryModelScript.MATCH_TYPE_ASYNC):
		return "ASYNC"
	return "BOT"

func _configure_vfx_manager() -> void:
	if vfx_manager == null or not is_instance_valid(vfx_manager):
		return
	if sim_events != null and vfx_manager.has_method("set_sim_events"):
		vfx_manager.set_sim_events(sim_events)
	if vfx_manager != null and vfx_manager.has_method("set_gpu_vfx_enabled"):
		vfx_manager.call("set_gpu_vfx_enabled", _gpu_vfx_pref_enabled())
	if vfx_manager != null and vfx_manager.has_method("prewarm"):
		vfx_manager.prewarm()

func _gpu_vfx_pref_enabled() -> bool:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null and profile_manager.has_method("is_gpu_vfx_enabled"):
		return bool(profile_manager.call("is_gpu_vfx_enabled"))
	return true

func _floor_graphics_pref_enabled() -> bool:
	if FORCE_DISABLE_FLOOR_INFLUENCE:
		return false
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null and profile_manager.has_method("is_floor_graphics_enabled"):
		return bool(profile_manager.call("is_floor_graphics_enabled"))
	return enable_floor_influence_runtime

func set_gpu_vfx_enabled(enabled: bool) -> void:
	_ensure_vfx_manager()
	if vfx_manager != null and vfx_manager.has_method("set_gpu_vfx_enabled"):
		vfx_manager.call("set_gpu_vfx_enabled", enabled)

func set_floor_graphics_enabled(enabled: bool) -> void:
	if FORCE_DISABLE_FLOOR_INFLUENCE:
		enable_floor_influence_runtime = false
	else:
		enable_floor_influence_runtime = enabled
	_ensure_floor_influence_system()

func _on_sim_ticked() -> void:
	var phase: int = int(OpsState.match_phase)
	var post_match_phase: bool = phase == int(OpsState.MatchPhase.ENDING) or phase == int(OpsState.MatchPhase.ENDED)
	if post_match_phase:
		if _post_match_render_frozen:
			return
		_update_buff_states()
		mark_render_dirty("sim_tick_post_match_final")
		_push_render_model()
		var unit_r: Node = unit_renderer
		if unit_r == null:
			unit_r = _resolve_unit_renderer()
			if unit_r is Node2D:
				unit_renderer = unit_r as Node2D
		if unit_r != null and unit_r.has_method("begin_post_match_settle"):
			unit_r.call("begin_post_match_settle", POST_MATCH_SETTLE_SEC, POST_MATCH_EXTRAP_SEC)
		_post_match_render_frozen = true
		return
	var was_post_match_frozen: bool = _post_match_render_frozen
	_post_match_render_frozen = false
	if was_post_match_frozen:
		_end_post_match_settle_if_supported()
	_update_buff_states()
	if _telemetry_active and _match_telemetry_collector != null and state != null and _match_telemetry_collector.has_method("sample_state"):
		_match_telemetry_collector.call("sample_state", int(_authoritative_sim_time_us() / 1000), TICK_DT, state)
	if _telemetry_active and _match_telemetry_collector != null and _match_telemetry_collector.has_method("sample_runtime_perf"):
		var runtime_snapshot: Dictionary = OpsState.call("get_runtime_telemetry_snapshot") if OpsState != null and OpsState.has_method("get_runtime_telemetry_snapshot") else {}
		var authority_counts: Dictionary = _authoritative_runtime_counts_snapshot()
		for key_any in authority_counts.keys():
			runtime_snapshot[key_any] = authority_counts.get(key_any)
		_match_telemetry_collector.call("sample_runtime_perf", int(_authoritative_sim_time_us() / 1000), runtime_snapshot)
	if _vs_pvp_runtime != null and _vs_pvp_runtime.has_method("record_local_state_hash") and OpsState != null and state != null:
		var state_hash: String = ""
		if OpsState.has_method("get_contract_state_hash"):
			state_hash = str(OpsState.call("get_contract_state_hash"))
		if not state_hash.is_empty():
			var authority_snapshot: Dictionary = {}
			if OpsState.has_method("get_authority_snapshot"):
				var snapshot_any: Variant = OpsState.call("get_authority_snapshot")
				if typeof(snapshot_any) == TYPE_DICTIONARY:
					authority_snapshot = snapshot_any as Dictionary
			_vs_pvp_runtime.call("record_local_state_hash", int(state.tick), state_hash, authority_snapshot)
	mark_render_dirty("sim_tick")
	# SimRunner already ticks at fixed cadence; pushing every sim tick avoids
	# time-gate jitter (99ms/101ms skip pattern) that reads as sawtooth motion.
	_push_render_model()

func _end_post_match_settle_if_supported() -> void:
	var unit_r: Node = unit_renderer
	if unit_r == null:
		unit_r = _resolve_unit_renderer()
		if unit_r is Node2D:
			unit_renderer = unit_r as Node2D
	if unit_r != null and unit_r.has_method("end_post_match_settle"):
		unit_r.call("end_post_match_settle")

func _maybe_push_render_model() -> void:
	var st: GameState = OpsState.get_state()
	if st == null:
		return
	var serial: int = int(OpsState._state_serial)
	var now_ms: int = Time.get_ticks_msec()
	if serial != _last_render_serial:
		_last_render_serial = serial
		_last_rm_ms = now_ms
		_push_render_model()
		return
	var refresh_ms: int = int(1000.0 / RM_REFRESH_HZ)
	if now_ms - _last_rm_ms < refresh_ms:
		return
	_last_rm_ms = now_ms
	_push_render_model()

func _on_match_ended(winner_id_in: int, reason: String) -> void:
	if _match_end_handled:
		SFLog.info("MATCH_END_DUPLICATE_SKIP", {"winner_id": winner_id_in})
		return
	_match_end_handled = true
	var shell: Node = get_node_or_null("/root/Shell")
	if shell != null and shell.has_method("cancel_buff_pointer_session"):
		shell.call("cancel_buff_pointer_session", "match_ended:%s" % reason)
	_buff_activation_transactions.terminate_match(_buff_match_id(), "match_ended:%s" % reason)
	_persist_buff_activation_runtime_state()
	if floor_influence_system != null:
		floor_influence_system.notify_match_ended()
	if input_system != null:
		input_system.set_inputs_locked(true, "match_end")
	game_over = true
	winner_id = winner_id_in
	end_reason = reason
	_commit_match_records(winner_id_in)
	_finalize_match_telemetry_session(winner_id_in)
	_maybe_record_jukebox_result(winner_id_in, reason)
	if _should_play_post_match_song(winner_id_in):
		_play_post_match_song(winner_id_in)
	_maybe_award_tutorial_controls_followup_win(winner_id_in, reason)
	_maybe_record_stage_race_contest_result(winner_id_in, reason)
	_maybe_settle_vs_money_match(winner_id_in, reason)
	_maybe_settle_crucible_match(winner_id_in, reason)
	SFLog.info("MATCH_END_HANDLE", {"winner_id": winner_id_in})
	call_deferred("_match_end_deferred", winner_id_in, reason)

func _maybe_award_tutorial_controls_followup_win(winner_id_in: int, reason: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or not bool(tree.get_meta("tutorial_controls_followup_match", false)):
		return
	var local_owner_id: int = _resolve_local_owner_id()
	if winner_id_in <= 0 or winner_id_in != local_owner_id:
		SFLog.info("TUTORIAL_CONTROLS_FOLLOWUP_REWARD_SKIPPED", {
			"winner_id": winner_id_in,
			"local_owner_id": local_owner_id,
			"reason": reason
		})
		return
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager == null:
		return
	if profile_manager.has_method("grant_achievement"):
		profile_manager.call("grant_achievement", "ACH_FIRST_WIN")
	if profile_manager.has_method("mark_tutorial_controls_completed"):
		profile_manager.call("mark_tutorial_controls_completed")
	var bonus_claimed: bool = false
	if profile_manager.has_method("has_tutorial_controls_followup_bonus_claimed"):
		bonus_claimed = bool(profile_manager.call("has_tutorial_controls_followup_bonus_claimed"))
	if bonus_claimed:
		return
	var honey_state: Node = get_node_or_null("/root/HoneyProgressionState")
	if honey_state == null or not honey_state.has_method("intent_grant_player_honey"):
		return
	var result_any: Variant = honey_state.call("intent_grant_player_honey", 25, "tutorial_controls_completion_bonus", {
		"event_id": "tutorial_controls_completion_bonus_v1",
		"winner_id": winner_id_in,
		"reason": reason,
		"map_id": _resolve_telemetry_map_id()
	})
	var result: Dictionary = result_any as Dictionary if typeof(result_any) == TYPE_DICTIONARY else {}
	if not bool(result.get("ok", false)):
		return
	if profile_manager.has_method("mark_tutorial_controls_followup_bonus_claimed"):
		profile_manager.call("mark_tutorial_controls_followup_bonus_claimed")
	tree.set_meta("honey_latest_award", {
		"type": "honey_awarded",
		"source": "tutorial_controls_completion_bonus",
		"event_id": "tutorial_controls_completion_bonus_v1",
		"honey_centi_awarded": 2500,
		"whole_honey_granted": 25,
		"profile_honey_balance": int(result.get("profile_honey_balance", 0)),
		"metadata": {
			"winner_id": winner_id_in,
			"reason": reason,
			"map_id": _resolve_telemetry_map_id()
		}
	})
	tree.set_meta("honey_latest_awarded_centi", 2500)
	SFLog.info("TUTORIAL_CONTROLS_FOLLOWUP_REWARD_GRANTED", {
		"winner_id": winner_id_in,
		"honey": 25,
		"achievement_id": "ACH_FIRST_WIN"
	})

func _maybe_settle_vs_money_match(winner_id_in: int, reason: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if not bool(tree.get_meta("vs_paid_entry", false)):
		return
	var session_id: String = str(tree.get_meta("vs_handshake_session_id", "")).strip_edges()
	if session_id.is_empty():
		return
	if str(tree.get_meta("vs_money_ledger_status", "")).strip_edges().to_lower() in ["settled", "refunded"]:
		return
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null or not handshake.has_method("settle_money_match"):
		SFLog.warn("VS_MONEY_SETTLEMENT_MISSING", {"session_id": session_id})
		return
	var result: Dictionary = handshake.call("settle_money_match", session_id, winner_id_in, reason) as Dictionary
	tree.set_meta("vs_money_settlement_result", result.duplicate(true))
	if bool(result.get("ok", false)):
		var ledger_status: String = str((result.get("session", {}) as Dictionary).get("context", {}).get("ledger_status", "")).strip_edges()
		if ledger_status.is_empty():
			ledger_status = "settled" if str(result.get("type", "")) == "match_settled" else "refunded"
		tree.set_meta("vs_money_ledger_status", ledger_status)
		tree.set_meta("vs_money_transaction_ids", (result.get("transaction_ids", []) as Array).duplicate(true))
		SFLog.info("VS_MONEY_SETTLED", {
			"session_id": session_id,
			"winner_id": winner_id_in,
			"ledger_status": ledger_status,
			"winner_payout_cents": int(result.get("winner_payout_cents", 0)),
			"house_rake_cents": int(result.get("house_rake_cents", 0))
		})
		return
	SFLog.warn("VS_MONEY_SETTLEMENT_FAILED", {
		"session_id": session_id,
		"winner_id": winner_id_in,
		"err": str(result.get("err", result.get("code", "unknown")))
	})

func _maybe_settle_crucible_match(winner_id_in: int, reason: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if not CrucibleRulesetPolicyScript.is_crucible_tree(tree):
		return
	var match_id: String = str(tree.get_meta("crucible_match_id", "")).strip_edges()
	if match_id.is_empty():
		SFLog.warn("CRUCIBLE_SETTLEMENT_MISSING_MATCH", {"winner_id": winner_id_in, "reason": reason})
		return
	var current_status: String = str(tree.get_meta("crucible_settlement_status", "")).strip_edges().to_lower()
	if current_status in ["settled", "refunded", "no_contest"]:
		return
	var crucible_state: Node = get_node_or_null("/root/CrucibleState")
	if crucible_state == null or not crucible_state.has_method("intent_settle_match"):
		SFLog.warn("CRUCIBLE_SETTLEMENT_STATE_MISSING", {"match_id": match_id})
		return
	var winner_player_id: String = _crucible_player_id_for_winner_seat(winner_id_in)
	var metadata: Dictionary = {
		"source": "arena_match_end",
		"authoritative": true,
		"winner_seat": winner_id_in,
		"reason": reason,
		"ops_winner_id": int(OpsState.winner_id) if OpsState != null else winner_id_in,
		"ops_match_end_reason": str(OpsState.match_end_reason) if OpsState != null else reason,
		"ops_outcome_tick": int(OpsState.outcome_tick) if OpsState != null else -1,
		"session_id": str(tree.get_meta("vs_handshake_session_id", "")).strip_edges()
	}
	var result: Dictionary = crucible_state.call(
		"intent_settle_match",
		match_id,
		winner_player_id,
		CrucibleRulesetPolicyScript.RESULT_SOURCE_AUTHORITATIVE_SIM,
		reason,
		metadata
	) as Dictionary
	tree.set_meta("crucible_settlement_result", result.duplicate(true))
	if bool(result.get("ok", false)):
		var settlement: Dictionary = result.get("settlement", {}) as Dictionary
		var status: String = str(settlement.get("settlement_status", "")).strip_edges()
		if status.is_empty():
			status = "SETTLED" if not winner_player_id.is_empty() else "NO_CONTEST"
		tree.set_meta("crucible_settlement_status", status)
		if crucible_state.has_method("get_balance_millis"):
			var player_a_id: String = str(tree.get_meta("crucible_player_a_id", "")).strip_edges()
			var player_b_id: String = str(tree.get_meta("crucible_player_b_id", "")).strip_edges()
			var player_a_finish: int = int(crucible_state.call("get_balance_millis", player_a_id)) if not player_a_id.is_empty() else 0
			var player_b_finish: int = int(crucible_state.call("get_balance_millis", player_b_id)) if not player_b_id.is_empty() else 0
			tree.set_meta("crucible_player_a_balance_finish_millis", player_a_finish)
			tree.set_meta("crucible_player_b_balance_finish_millis", player_b_finish)
			var local_profile: Dictionary = tree.get_meta("vs_local_profile", {}) as Dictionary
			var remote_profile: Dictionary = tree.get_meta("vs_remote_profile", {}) as Dictionary
			var local_id: String = str(local_profile.get("uid", "")).strip_edges()
			var remote_id: String = str(remote_profile.get("uid", "")).strip_edges()
			var local_finish: int = 0
			var remote_finish: int = 0
			if local_id == player_a_id:
				local_finish = player_a_finish
				remote_finish = player_b_finish
			elif local_id == player_b_id:
				local_finish = player_b_finish
				remote_finish = player_a_finish
			elif not local_id.is_empty():
				local_finish = int(crucible_state.call("get_balance_millis", local_id))
			if remote_finish <= 0 and not remote_id.is_empty():
				remote_finish = int(crucible_state.call("get_balance_millis", remote_id))
			tree.set_meta("crucible_local_balance_finish_millis", local_finish)
			tree.set_meta("crucible_remote_balance_finish_millis", remote_finish)
			if tree.has_meta("crucible_local_balance_start_millis"):
				tree.set_meta("crucible_balance_delta_millis", local_finish - int(tree.get_meta("crucible_local_balance_start_millis", local_finish)))
		SFLog.info("CRUCIBLE_MATCH_SETTLED", {
			"match_id": match_id,
			"winner_seat": winner_id_in,
			"winner_id": winner_player_id,
			"settlement_status": status,
			"winner_payout": int(settlement.get("winner_payout", 0)),
			"burn": int(settlement.get("burn", 0))
		})
		return
	SFLog.warn("CRUCIBLE_SETTLEMENT_FAILED", {
		"match_id": match_id,
		"winner_seat": winner_id_in,
		"winner_id": winner_player_id,
		"err": str(result.get("err", result.get("code", "unknown")))
	})

func _crucible_player_id_for_winner_seat(winner_seat: int) -> String:
	if winner_seat <= 0:
		return ""
	var tree: SceneTree = get_tree()
	if tree == null:
		return ""
	var seat_a: int = int(tree.get_meta("crucible_player_a_seat", 1))
	var seat_b: int = int(tree.get_meta("crucible_player_b_seat", 2))
	if winner_seat == seat_a:
		return str(tree.get_meta("crucible_player_a_id", "")).strip_edges()
	if winner_seat == seat_b:
		return str(tree.get_meta("crucible_player_b_id", "")).strip_edges()
	return ""

func _should_play_post_match_song(_winner_id_in: int) -> bool:
	if not _is_progressive_runtime_mode():
		return true
	var tree: SceneTree = get_tree()
	if tree == null:
		return true
	return int(tree.get_meta("progressive_stage_index", 0)) <= 0

func _match_end_deferred(winner_id_in: int, reason: String) -> void:
	if _controls_hint_controller != null:
		_controls_hint_controller.hide(false)
	var tutorial_section1_ended: bool = _tutorial_section1_controller != null and _tutorial_section1_controller.is_active()
	var tutorial_controls_ended: bool = _tutorial_controls_controller != null and _tutorial_controls_controller.is_active() and winner_id_in == _resolve_local_owner_id()
	if _tutorial_controls_controller != null:
		_tutorial_controls_controller.on_match_ended()
	if _tutorial_section1_controller != null:
		_tutorial_section1_controller.on_match_ended()
	if _tutorial_section2_controller != null:
		_tutorial_section2_controller.on_match_ended()
	if _tutorial_section3_controller != null:
		_tutorial_section3_controller.on_match_ended()
	if _is_progressive_runtime_mode():
		if outcome_overlay != null and outcome_overlay.has_method("clear_post_match_summary"):
			outcome_overlay.call("clear_post_match_summary")
		_show_progressive_stage_overlay(winner_id_in, reason)
		if sim_runner != null:
			sim_runner.log_pause_snapshot("arena_show_progressive_stage_outcome")
		mark_render_dirty("match_end_progressive_stage")
		return
	if _is_async_stage_run_runtime_mode():
		if outcome_overlay != null and outcome_overlay.has_method("clear_post_match_summary"):
			outcome_overlay.call("clear_post_match_summary")
		_show_stage_race_round_overlay(winner_id_in, reason)
		if sim_runner != null:
			sim_runner.log_pause_snapshot("arena_show_stage_round_outcome")
		mark_render_dirty("match_end_stage_round")
		return
	if outcome_overlay == null:
		_ensure_post_match_ui()
	if outcome_overlay != null:
		var record_slot: int = clampi(active_player_id, 1, 4)
		var record_text: String = _get_player_record_line(record_slot)
		var h2h_text: String = _get_h2h_record_line()
		if tutorial_controls_ended and outcome_overlay.has_method("show_tutorial_controls_complete"):
			outcome_overlay.call("show_tutorial_controls_complete", winner_id_in, reason, active_player_id)
		elif tutorial_section1_ended and outcome_overlay.has_method("show_tutorial_complete"):
			outcome_overlay.call("show_tutorial_complete", winner_id_in, reason, active_player_id)
		else:
			outcome_overlay.show_outcome(winner_id_in, reason, active_player_id, record_text, h2h_text)
		if not tutorial_section1_ended and not tutorial_controls_ended and outcome_overlay.has_method("set_post_match_summary"):
			outcome_overlay.call("set_post_match_summary", _post_match_analysis_summary, winner_id_in, active_player_id)
	else:
		SFLog.warn("POSTMATCH_UI_MISSING", {"kind": "outcome_overlay"})
	if sim_runner != null:
		sim_runner.log_pause_snapshot("arena_show_outcome")
	mark_render_dirty("match_end")

func _maybe_record_jukebox_result(winner_id_in: int, reason: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if not AsyncRecordEligibilityPolicy.is_balancer_medium_record_eligible(tree):
		return
	var local_owner_id: int = clampi(int(tree.get_meta(JUKEBOX_META_LOCAL_OWNER_ID, 1)), 1, 4)
	if winner_id_in <= 0 or winner_id_in != local_owner_id:
		return
	var elapsed_ms: int = maxi(0, int(OpsState.match_elapsed_ms))
	if elapsed_ms <= 0:
		return
	var map_id: String = _resolve_jukebox_map_id(tree)
	if map_id.is_empty():
		return
	var identity: Dictionary = _resolve_jukebox_local_identity(tree)
	var player_id: String = str(identity.get("player_id", "")).strip_edges()
	if player_id.is_empty():
		return
	var result_signature: String = "%s|%s|%d|%d|%s" % [map_id, player_id, elapsed_ms, winner_id_in, reason.strip_edges()]
	if str(tree.get_meta(JUKEBOX_META_RESULT_SIGNATURE, "")).strip_edges() == result_signature:
		return
	var result: Dictionary = _jukebox_leaderboard_store.record_run_all_periods(
		map_id,
		MAP_RECORD_MODE_ID,
		{
			"player_id": player_id,
			"handle": str(identity.get("handle", "You")).strip_edges(),
			"best_time_ms": elapsed_ms,
			"updated_at": int(Time.get_unix_time_from_system()),
			"source": "jukebox_run"
		}
	)
	if bool(result.get("ok", false)):
		tree.set_meta(JUKEBOX_META_RESULT_SIGNATURE, result_signature)
		var board: Dictionary = _jukebox_leaderboard_store.get_board_snapshot(map_id, MAP_RECORD_MODE_ID, _resolve_jukebox_period(tree), player_id, str(identity.get("handle", "You")).strip_edges(), 10)
		var your_rank: int = int(board.get("your_rank", 0))
		if your_rank > 0 and your_rank <= 10:
			tree.set_meta(JUKEBOX_META_HIGHLIGHT_PLAYER_ID, player_id)
		elif tree.has_meta(JUKEBOX_META_HIGHLIGHT_PLAYER_ID):
			tree.remove_meta(JUKEBOX_META_HIGHLIGHT_PLAYER_ID)
		SFLog.info("JUKEBOX_RESULT_RECORDED", {
			"map_id": map_id,
			"mode_id": MAP_RECORD_MODE_ID,
			"source_mode": str(tree.get_meta(TREE_META_VS_MODE, "")).strip_edges().to_upper(),
			"period": _resolve_jukebox_period(tree),
			"periods_updated": result.get("periods_updated", []),
			"player_id": player_id,
			"winner_id": winner_id_in,
			"reason": reason,
			"elapsed_ms": elapsed_ms,
			"updated": bool(result.get("updated", false))
		})

func _resolve_jukebox_map_id(tree: SceneTree) -> String:
	var map_id: String = str(tree.get_meta(JUKEBOX_META_MAP_ID, "")).strip_edges()
	if not map_id.is_empty():
		return map_id
	var map_path: String = str(tree.get_meta(JUKEBOX_META_MAP_PATH, "")).strip_edges()
	if map_path.is_empty():
		var stage_maps_any: Variant = tree.get_meta(TREE_META_VS_STAGE_MAP_PATHS, [])
		if typeof(stage_maps_any) == TYPE_ARRAY:
			var stage_maps: Array = stage_maps_any as Array
			var stage_index: int = clampi(int(tree.get_meta(TREE_META_VS_STAGE_CURRENT_INDEX, 0)), 0, maxi(stage_maps.size() - 1, 0))
			if stage_index >= 0 and stage_index < stage_maps.size():
				map_path = str(stage_maps[stage_index]).strip_edges()
	if map_path.is_empty():
		return ""
	return MapRegistry.map_id_from_path(map_path)

func _resolve_jukebox_period(tree: SceneTree) -> String:
	var period: String = str(tree.get_meta(JUKEBOX_META_PERIOD, "WEEKLY")).strip_edges().to_upper()
	return period if not period.is_empty() else "WEEKLY"

func _resolve_jukebox_local_identity(tree: SceneTree) -> Dictionary:
	var player_id: String = ""
	var handle: String = ""
	var local_profile_any: Variant = tree.get_meta("vs_local_profile", {})
	if typeof(local_profile_any) == TYPE_DICTIONARY:
		var local_profile: Dictionary = local_profile_any as Dictionary
		player_id = str(local_profile.get("uid", local_profile.get("player_id", ""))).strip_edges()
		handle = str(local_profile.get("display_name", local_profile.get("name", local_profile.get("handle", "")))).strip_edges()
	if player_id.is_empty() and ProfileManager != null and ProfileManager.has_method("get_user_id"):
		player_id = str(ProfileManager.get_user_id()).strip_edges()
	if handle.is_empty() and ProfileManager != null and ProfileManager.has_method("get_display_name"):
		handle = str(ProfileManager.get_display_name()).strip_edges()
	if handle.is_empty():
		handle = "You"
	return {
		"player_id": player_id,
		"handle": handle
	}

func _maybe_record_stage_race_contest_result(winner_id_in: int, reason: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or not _is_stage_race_runtime_mode():
		return
	if not AsyncRecordEligibilityPolicy.is_balancer_medium_record_eligible(tree):
		return
	var contest_id: String = str(tree.get_meta("contest_id", "")).strip_edges()
	if contest_id.is_empty():
		return
	var local_owner_id: int = _resolve_local_owner_id()
	if local_owner_id <= 0:
		local_owner_id = clampi(active_player_id, 1, 4)
	if winner_id_in <= 0 or winner_id_in != local_owner_id:
		return
	var elapsed_ms: int = maxi(0, int(OpsState.match_elapsed_ms))
	if elapsed_ms <= 0:
		return
	var map_id: String = _resolve_stage_race_contest_map_id(tree)
	if map_id.is_empty():
		return
	var identity: Dictionary = _resolve_jukebox_local_identity(tree)
	var player_id: String = str(identity.get("player_id", "")).strip_edges()
	if player_id.is_empty():
		return
	var result_signature: String = "%s|%s|%s|%d|%d|%s" % [contest_id, map_id, player_id, elapsed_ms, winner_id_in, reason.strip_edges()]
	if str(tree.get_meta(TREE_META_CONTEST_RESULT_SIGNATURE, "")).strip_edges() == result_signature:
		return
	var contest_state: Node = get_node_or_null("/root/ContestState")
	if contest_state == null or not contest_state.has_method("record_stage_race_map_result"):
		return
	var result: Dictionary = contest_state.call("record_stage_race_map_result", contest_id, map_id, {
		"player_id": player_id,
		"player_name": str(identity.get("handle", "You")).strip_edges(),
		"best_time_ms": elapsed_ms,
		"updated_at": int(Time.get_unix_time_from_system()),
		"source": "stage_race_runtime",
		"run_id": _stage_race_run_id(tree, player_id),
		"stage_index": maxi(0, int(tree.get_meta(TREE_META_VS_STAGE_CURRENT_INDEX, 0))),
		"winner_id": winner_id_in,
		"reason": reason
	}) as Dictionary
	if bool(result.get("ok", false)):
		tree.set_meta(TREE_META_CONTEST_RESULT_SIGNATURE, result_signature)
		SFLog.info("CONTEST_RESULT_RECORDED", {
			"contest_id": contest_id,
			"map_id": map_id,
			"player_id": player_id,
			"winner_id": winner_id_in,
			"reason": reason,
			"elapsed_ms": elapsed_ms,
			"run_id": str(result.get("run_id", "")),
			"updated": bool(result.get("updated", false))
		})
	else:
		SFLog.warn("CONTEST_RESULT_RECORD_FAILED", result)

func _resolve_stage_race_contest_map_id(tree: SceneTree) -> String:
	var stage_index: int = maxi(0, int(tree.get_meta(TREE_META_VS_STAGE_CURRENT_INDEX, 0)))
	var map_ids_any: Variant = tree.get_meta("map_ids", PackedStringArray())
	if typeof(map_ids_any) == TYPE_PACKED_STRING_ARRAY:
		var packed_ids: PackedStringArray = map_ids_any
		if stage_index >= 0 and stage_index < packed_ids.size():
			var packed_map_id: String = str(packed_ids[stage_index]).strip_edges()
			if not packed_map_id.is_empty():
				return packed_map_id
	elif typeof(map_ids_any) == TYPE_ARRAY:
		var ids: Array = map_ids_any as Array
		if stage_index >= 0 and stage_index < ids.size():
			var array_map_id: String = str(ids[stage_index]).strip_edges()
			if not array_map_id.is_empty():
				return array_map_id
	var stage_maps: Array[String] = _get_stage_map_paths_runtime()
	if stage_maps.is_empty():
		return ""
	var clamped_index: int = clampi(stage_index, 0, maxi(stage_maps.size() - 1, 0))
	var map_path: String = str(stage_maps[clamped_index]).strip_edges()
	if map_path.is_empty():
		return ""
	return MapRegistry.map_id_from_path(map_path)

func _on_post_match_action(action: String) -> void:
	if action == "rematch_vote" and not _is_async_stage_run_runtime_mode() and not _is_progressive_runtime_mode():
		var voter_id: int = active_player_id
		if voter_id != 1 and voter_id != 2:
			voter_id = 1
		if _paid_vs_rematch_funding_blocked(voter_id):
			return
		var accepted: bool = OpsState.request_rematch(voter_id)
		SFLog.info("REMATCH_VOTE_INTENT", {
			"voter_id": voter_id,
			"accepted": accepted,
			"p1": OpsState.rematch_votes.has(1),
			"p2": OpsState.rematch_votes.has(2)
		})
		return
	if _post_match_action_taken:
		return
	SFLog.info("POST_MATCH_ACTION", {"action": action})
	match action:
		"tutorial_controls_followup":
			_post_match_action_taken = true
			_launch_tutorial_controls_followup_match()
		"next_round":
			_post_match_action_taken = true
			if _is_progressive_runtime_mode():
				_advance_progressive_stage()
			else:
				await _advance_stage_race_round()
		"finish_run":
			_post_match_action_taken = true
			if _is_progressive_runtime_mode():
				_clear_progressive_runtime_meta()
			else:
				if _is_stage_race_runtime_mode():
					_prepare_stage_race_finish_leaderboard_request()
				_clear_stage_runtime_meta()
			_return_to_main_menu()
		"rematch":
			_post_match_action_taken = true
			_handle_rematch()
		"main_menu":
			_post_match_action_taken = true
			if _is_async_stage_run_runtime_mode():
				_clear_stage_runtime_meta()
			if _is_progressive_runtime_mode():
				_clear_progressive_runtime_meta()
			_return_to_main_menu()
		_:
			return

func _launch_tutorial_controls_followup_match() -> void:
	if outcome_overlay != null:
		outcome_overlay.hide_overlay()
	var shell: Node = get_node_or_null("/root/Shell")
	if shell != null and shell.has_method("launch_tutorial_controls_followup_bot"):
		shell.call_deferred("launch_tutorial_controls_followup_bot")
		return
	SFLog.warn("TUTORIAL_CONTROLS_FOLLOWUP_LAUNCH_MISSING_SHELL", {})
	_return_to_main_menu()

func _is_stage_race_runtime_mode() -> bool:
	return _stage_runtime_flow.is_stage_race_runtime_mode(get_tree(), TREE_META_VS_MODE, VS_MODE_STAGE_RACE)

func _is_async_stage_run_runtime_mode() -> bool:
	match _current_vs_mode():
		VS_MODE_STAGE_RACE, "TIMED_RACE", "MISS_N_OUT":
			return true
		_:
			return false

func _is_progressive_runtime_mode() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	return str(tree.get_meta(TREE_META_VS_MODE, "")).strip_edges().to_upper() == VS_MODE_PROGRESSIVE or str(tree.get_meta("progressive_run_id", "")).strip_edges() != ""

func _get_stage_map_paths_runtime() -> Array[String]:
	return _stage_runtime_flow.get_stage_map_paths_runtime(get_tree(), TREE_META_VS_STAGE_MAP_PATHS)

func _get_stage_round_results_runtime() -> Array:
	return _stage_runtime_flow.get_stage_round_results_runtime(get_tree(), TREE_META_VS_STAGE_ROUND_RESULTS)

func _set_stage_round_results_runtime(results: Array) -> void:
	_stage_runtime_flow.set_stage_round_results_runtime(get_tree(), TREE_META_VS_STAGE_ROUND_RESULTS, results)

func _upsert_stage_round_result(results: Array, round_index: int, result: Dictionary) -> Array:
	return _stage_runtime_flow.upsert_stage_round_result(results, round_index, result)

func _owned_hive_counts_by_owner() -> Dictionary:
	return _stage_runtime_flow.owned_hive_counts_by_owner(state)

func _resolve_stage_opponent_owner_id(owned_by_owner: Dictionary, local_owner_id: int, winner_id_in: int) -> int:
	return _stage_runtime_flow.resolve_stage_opponent_owner_id(owned_by_owner, local_owner_id, winner_id_in)

func _stage_rank_snapshot(results: Array, local_owner_id: int) -> Dictionary:
	return _stage_runtime_flow.stage_rank_snapshot(results, local_owner_id)

func _build_stage_round_summary(winner_id_in: int, reason: String) -> Dictionary:
	var tree: SceneTree = get_tree()
	if tree == null:
		return {}
	var stage_maps: Array[String] = _get_stage_map_paths_runtime()
	if stage_maps.is_empty():
		return {}
	var total_rounds: int = stage_maps.size()
	var raw_round_index: int = int(tree.get_meta(TREE_META_VS_STAGE_CURRENT_INDEX, 0))
	var round_index: int = clampi(raw_round_index, 0, total_rounds - 1)
	var mode_id: String = _current_vs_mode()
	var local_owner_id: int = _resolve_local_owner_id()
	if local_owner_id <= 0:
		local_owner_id = clampi(active_player_id, 1, 4)
	var local_won_round: bool = winner_id_in > 0 and winner_id_in == local_owner_id
	var owned_by_owner: Dictionary = _owned_hive_counts_by_owner()
	var local_owned_hives: int = int(owned_by_owner.get(local_owner_id, 0))
	var opponent_owner_id: int = _resolve_stage_opponent_owner_id(owned_by_owner, local_owner_id, winner_id_in)
	var opponent_owned_hives: int = int(owned_by_owner.get(opponent_owner_id, 0))
	var elapsed_ms: int = maxi(0, int(OpsState.match_elapsed_ms))
	var round_result: Dictionary = {
		"round_index": round_index,
		"round_number": round_index + 1,
		"map_path": stage_maps[round_index],
		"winner_id": winner_id_in,
		"reason": reason,
		"elapsed_ms": elapsed_ms,
		"local_owner_id": local_owner_id,
		"opponent_owner_id": opponent_owner_id,
		"local_owned_hives": local_owned_hives,
		"opponent_owned_hives": opponent_owned_hives,
		"recorded_ms": Time.get_ticks_msec()
	}
	var results: Array = _get_stage_round_results_runtime()
	results = _upsert_stage_round_result(results, round_index, round_result)
	_set_stage_round_results_runtime(results)
	var rank_snapshot: Dictionary = _stage_rank_snapshot(results, local_owner_id)
	var next_round_available: bool = round_index + 1 < total_rounds
	if mode_id == "TIMED_RACE" or mode_id == "MISS_N_OUT":
		next_round_available = next_round_available and local_won_round
	if mode_id == "MISS_N_OUT" and not local_won_round:
		tree.set_meta("miss_n_out_eliminated", true)
		tree.set_meta("miss_n_out_notice", "Eliminated in round %d. You can keep playing for practice or return to lobby." % (round_index + 1))
	if mode_id == "TIMED_RACE" and not next_round_available:
		_maybe_record_timed_race_contest_result(results, winner_id_in, reason)
	elif mode_id == "MISS_N_OUT" and not next_round_available:
		_maybe_record_miss_n_out_contest_result(results, winner_id_in, reason)
	var wager_cents: int = maxi(0, int(tree.get_meta("vs_wager_cents", maxi(0, int(tree.get_meta("vs_price_usd", 0))) * 100)))
	var settlement: Dictionary = {}
	var settlement_any: Variant = tree.get_meta("vs_money_settlement_result", {})
	if typeof(settlement_any) == TYPE_DICTIONARY:
		settlement = settlement_any as Dictionary
	var balance_start_cents: int = maxi(0, int(tree.get_meta("async_money_balance_start_cents", 0)))
	var balance_after_entry_cents: int = maxi(0, int(tree.get_meta("async_money_balance_after_entry_cents", 0)))
	var winner_payout_cents: int = maxi(0, int(settlement.get("winner_payout_cents", 0)))
	var balance_finish_cents: int = maxi(0, int(tree.get_meta("async_money_balance_finish_cents", balance_after_entry_cents + winner_payout_cents)))
	if bool(tree.get_meta("vs_paid_entry", false)):
		SFLog.info("ASYNC_MONEY_STAGE_BALANCE_FINISH", {
			"contest_id": str(tree.get_meta("async_money_contest_id", tree.get_meta("contest_id", ""))),
			"entry_id": str(tree.get_meta("async_money_entry_id", "")),
			"balance_start_cents": balance_start_cents,
			"balance_after_entry_cents": balance_after_entry_cents,
			"balance_finish_cents": balance_finish_cents,
			"winner_payout_cents": winner_payout_cents
		})
	return {
		"mode_id": mode_id,
		"round_number": round_index + 1,
		"total_rounds": total_rounds,
		"winner_id": winner_id_in,
		"reason": reason,
		"local_owner_id": local_owner_id,
		"local_player_id": local_owner_id,
		"round_time_ms": elapsed_ms,
		"local_owned_hives": local_owned_hives,
		"opponent_owned_hives": opponent_owned_hives,
		"current_rank": int(rank_snapshot.get("rank", 0)),
		"local_round_wins": int(rank_snapshot.get("local_wins", 0)),
		"opponent_round_wins": int(rank_snapshot.get("opponent_wins", 0)),
		"cumulative_time_ms": maxi(0, int(rank_snapshot.get("local_elapsed_ms", elapsed_ms))),
		"next_round_available": next_round_available,
		"paid_entry": bool(tree.get_meta("vs_paid_entry", false)),
		"free_roll": bool(tree.get_meta("vs_free_roll", false)),
		"wager_cents": wager_cents,
		"async_money_entry_id": str(tree.get_meta("async_money_entry_id", "")),
		"async_money_contest_id": str(tree.get_meta("async_money_contest_id", tree.get_meta("contest_id", ""))),
		"async_money_ledger_status": str(tree.get_meta("async_money_ledger_status", "")),
		"async_money_pot_cents": maxi(0, int(tree.get_meta("async_money_pot_cents", wager_cents))),
		"async_money_escrow_cents": maxi(0, int(tree.get_meta("async_money_escrow_cents", wager_cents))),
		"async_money_ledger_source": str(tree.get_meta("async_money_ledger_source", "")),
		"async_money_balance_start_cents": balance_start_cents,
		"async_money_balance_after_entry_cents": balance_after_entry_cents,
		"async_money_balance_finish_cents": balance_finish_cents,
		"winner_payout_cents": winner_payout_cents
	}

func _show_stage_race_round_overlay(winner_id_in: int, reason: String) -> void:
	if outcome_overlay == null:
		_ensure_post_match_ui()
	if outcome_overlay == null:
		SFLog.warn("POSTMATCH_UI_MISSING", {"kind": "outcome_overlay_stage"})
		return
	var summary: Dictionary = _build_stage_round_summary(winner_id_in, reason)
	if summary.is_empty():
		var record_slot: int = clampi(active_player_id, 1, 4)
		var record_text: String = _get_player_record_line(record_slot)
		var h2h_text: String = _get_h2h_record_line()
		outcome_overlay.show_outcome(winner_id_in, reason, active_player_id, record_text, h2h_text)
		return
	var submission_expired: bool = reason == LIFECYCLE_CONTEST_EXPIRED_REASON
	var next_round_available: bool = bool(summary.get("next_round_available", false)) and not submission_expired
	var next_action: String = "next_round" if next_round_available else "finish_run"
	var next_label: String = "Next Round" if next_round_available else "Finish Run"
	var status_text: String = "Submission window expired. This run cannot submit." if submission_expired else "Cumulative rank is provisional. Ready for next round?" if next_round_available else "Cumulative rank is provisional. Run complete."
	var payload: Dictionary = summary.duplicate(true)
	payload["next_action"] = next_action
	payload["next_label"] = next_label
	payload["exit_label"] = "Back to Lobby"
	payload["status_text"] = status_text
	payload["next_round_available"] = next_round_available
	payload["next_button_enabled"] = true
	outcome_overlay.show_stage_round_outcome(payload)

func _build_progressive_stage_summary(winner_id_in: int, reason: String) -> Dictionary:
	var tree: SceneTree = get_tree()
	if tree == null:
		return {}
	var run_id: String = str(tree.get_meta("progressive_run_id", tree.get_meta(TREE_META_VS_STAGE_RUN_ID, ""))).strip_edges()
	if run_id.is_empty():
		return {}
	var plan: Array = _progressive_stage_plan(tree)
	var stage_count: int = maxi(1, plan.size())
	var stage_index: int = clampi(int(tree.get_meta("progressive_stage_index", tree.get_meta(TREE_META_VS_STAGE_CURRENT_INDEX, 0))), 0, stage_count - 1)
	var stage: Dictionary = _progressive_stage_at(tree, stage_index)
	var thresholds: Dictionary = tree.get_meta("progressive_thresholds_ms", stage.get("thresholds_ms", {})) as Dictionary
	var local_owner_id: int = _resolve_local_owner_id()
	if local_owner_id <= 0:
		local_owner_id = clampi(active_player_id, 1, 4)
	var elapsed_ms: int = maxi(0, int(OpsState.match_elapsed_ms))
	var won: bool = winner_id_in > 0 and winner_id_in == local_owner_id
	var stars: int = ProgressiveConfigScript.stars_for_elapsed(elapsed_ms, thresholds, won, reason)
	var result: Dictionary = _progressive_run_store.record_stage_result(run_id, {
		"stage_index": stage_index,
		"map_path": str(stage.get("map_path", "")),
		"map_id": str(stage.get("map_id", "")),
		"elapsed_ms": elapsed_ms,
		"winner_id": winner_id_in,
		"reason": reason,
		"passed": won and stars > 0,
		"stars": stars,
		"thresholds_ms": thresholds.duplicate(true)
	})
	var updated_run: Dictionary = {}
	if bool(result.get("ok", false)):
		updated_run = result.get("run", {}) as Dictionary
		tree.set_meta("progressive_total_stars", int(updated_run.get("total_stars", int(tree.get_meta("progressive_total_stars", 0)))))
		tree.set_meta("progressive_max_stars", int(updated_run.get("max_stars", int(tree.get_meta("progressive_max_stars", stage_count * ProgressiveConfigScript.STAR_MAX)))))
		SFLog.info("PROGRESSIVE_STAGE_RECORDED", {
			"run_id": run_id,
			"stage_index": stage_index,
			"elapsed_ms": elapsed_ms,
			"stars": stars,
			"status": str(updated_run.get("status", "")),
			"next_stage_index": int(updated_run.get("stage_index", stage_index))
		})
	else:
		SFLog.warn("PROGRESSIVE_STAGE_RECORD_FAILED", {
			"run_id": run_id,
			"stage_index": stage_index,
			"error": str(result.get("error", "unknown"))
		})
	_update_progressive_counter_ui()
	var total_stars: int = int(tree.get_meta("progressive_total_stars", stars))
	var max_stars: int = int(tree.get_meta("progressive_max_stars", stage_count * ProgressiveConfigScript.STAR_MAX))
	var next_available: bool = won and stars > 0 and stage_index + 1 < stage_count
	if not next_available:
		_maybe_record_gauntlet_contest_result(updated_run, {
			"run_id": run_id,
			"stage_count": stage_count,
			"total_stars": total_stars,
			"max_stars": max_stars,
			"terminal_stage_index": stage_index,
			"winner_id": winner_id_in,
			"reason": reason
		})
	return {
		"mode_id": VS_MODE_PROGRESSIVE,
		"stage_index": stage_index,
		"stage_number": stage_index + 1,
		"stage_count": stage_count,
		"winner_id": winner_id_in,
		"reason": reason,
		"local_player_id": local_owner_id,
		"elapsed_ms": elapsed_ms,
		"thresholds_ms": thresholds,
		"stars": stars,
		"total_stars": total_stars,
		"max_stars": max_stars,
		"next_round_available": next_available,
		"next_button_enabled": next_available,
		"next_action": "next_round" if next_available else "finish_run",
		"next_label": "Next Stage" if next_available else "Finish Run",
		"exit_label": "Main Menu",
		"status_text": "Run stars: %d / %d. Ready for the next stage?" % [total_stars, max_stars] if next_available else "Run ended with %d / %d stars." % [total_stars, max_stars]
	}

func _maybe_record_gauntlet_contest_result(run: Dictionary, fallback: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var contest_id: String = str(tree.get_meta("contest_id", "")).strip_edges()
	if contest_id.is_empty():
		contest_id = str(tree.get_meta("async_money_contest_id", "")).strip_edges()
	if contest_id.is_empty():
		return
	var run_data: Dictionary = run
	if run_data.is_empty():
		run_data = _progressive_run_store.load_current_run()
	if run_data.is_empty():
		run_data = fallback.duplicate(true)
	var identity: Dictionary = _resolve_jukebox_local_identity(tree)
	var player_id: String = str(identity.get("player_id", "")).strip_edges()
	if player_id.is_empty():
		return
	var run_id: String = str(run_data.get("run_id", fallback.get("run_id", tree.get_meta("progressive_run_id", "")))).strip_edges()
	if run_id.is_empty():
		return
	var stage_results: Array = run_data.get("stage_results", []) as Array
	var total_stars: int = int(run_data.get("total_stars", fallback.get("total_stars", tree.get_meta("progressive_total_stars", 0))))
	var max_stars: int = int(run_data.get("max_stars", fallback.get("max_stars", tree.get_meta("progressive_max_stars", 0))))
	var completed_stages: int = _progressive_completed_stage_count(stage_results)
	var total_elapsed_ms: int = _progressive_total_elapsed_ms(stage_results)
	var result_signature: String = "gauntlet|%s|%s|%s|%d|%d|%d" % [contest_id, player_id, run_id, total_stars, completed_stages, total_elapsed_ms]
	if str(tree.get_meta(TREE_META_CONTEST_RESULT_SIGNATURE, "")).strip_edges() == result_signature:
		return
	var contest_state: Node = get_node_or_null("/root/ContestState")
	if contest_state == null or not contest_state.has_method("record_gauntlet_run_result"):
		return
	var record: Dictionary = contest_state.call("record_gauntlet_run_result", contest_id, {
		"player_id": player_id,
		"player_name": str(identity.get("handle", "You")).strip_edges(),
		"run_id": run_id,
		"total_stars": total_stars,
		"max_stars": max_stars,
		"completed_stages": completed_stages,
		"stage_count": int(run_data.get("stage_count", fallback.get("stage_count", completed_stages))),
		"elapsed_ms": total_elapsed_ms,
		"status": str(run_data.get("status", "")),
		"stage_results": stage_results.duplicate(true),
		"updated_at": int(Time.get_unix_time_from_system()),
		"source": "gauntlet_runtime"
	}) as Dictionary
	if bool(record.get("ok", false)):
		tree.set_meta(TREE_META_CONTEST_RESULT_SIGNATURE, result_signature)
		SFLog.info("GAUNTLET_CONTEST_RESULT_RECORDED", {
			"contest_id": contest_id,
			"player_id": player_id,
			"run_id": run_id,
			"rank": int(record.get("rank", 0)),
			"total_stars": total_stars,
			"completed_stages": completed_stages
		})
	else:
		SFLog.warn("GAUNTLET_CONTEST_RESULT_RECORD_FAILED", record)

func _maybe_record_timed_race_contest_result(results: Array, winner_id_in: int, reason: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or _current_vs_mode() != "TIMED_RACE":
		return
	var contest_id: String = _runtime_contest_id(tree)
	if contest_id.is_empty():
		return
	var identity: Dictionary = _resolve_jukebox_local_identity(tree)
	var player_id: String = str(identity.get("player_id", "")).strip_edges()
	if player_id.is_empty():
		return
	var local_owner_id: int = _resolve_local_owner_id()
	if local_owner_id <= 0:
		local_owner_id = clampi(active_player_id, 1, 4)
	var stage_maps: Array[String] = _get_stage_map_paths_runtime()
	var map_count: int = maxi(1, stage_maps.size())
	var ordered_results: Array[Dictionary] = _ordered_stage_results(results)
	var map_times: Array[int] = []
	var completed_maps: int = 0
	var failed_elapsed_ms: int = 0
	for row in ordered_results:
		var elapsed_ms: int = maxi(0, int(row.get("elapsed_ms", 0)))
		var row_winner: int = int(row.get("winner_id", 0))
		if row_winner == local_owner_id:
			map_times.append(elapsed_ms)
			completed_maps += 1
			continue
		failed_elapsed_ms = elapsed_ms
		break
	var run_id: String = _stage_race_run_id(tree, player_id)
	var result_signature: String = "timed_race|%s|%s|%s|%d|%s|%d" % [contest_id, player_id, run_id, completed_maps, ",".join(_int_values_as_strings(map_times)), failed_elapsed_ms]
	if str(tree.get_meta(TREE_META_CONTEST_RESULT_SIGNATURE, "")).strip_edges() == result_signature:
		return
	var contest_state: Node = get_node_or_null("/root/ContestState")
	if contest_state == null or not contest_state.has_method("record_timed_race_result"):
		return
	var record: Dictionary = contest_state.call("record_timed_race_result", contest_id, {
		"player_id": player_id,
		"player_name": str(identity.get("handle", "You")).strip_edges(),
		"run_id": run_id,
		"map_count": map_count,
		"completed_maps": completed_maps,
		"map_times_ms": map_times.duplicate(),
		"failed_map_elapsed_ms": failed_elapsed_ms,
		"status": "complete" if completed_maps >= map_count else "incomplete",
		"winner_id": winner_id_in,
		"reason": reason,
		"updated_at": int(Time.get_unix_time_from_system()),
		"source": "timed_race_runtime"
	}) as Dictionary
	if bool(record.get("ok", false)):
		var backend_result: Dictionary = _submit_async_contest_result_backend(contest_id, "RACE", player_id, {
			"player_id": player_id,
			"player_name": str(identity.get("handle", "You")).strip_edges(),
			"run_id": run_id,
			"map_count": map_count,
			"required_maps": map_count,
			"completed_maps": completed_maps,
			"map_times_ms": map_times.duplicate(),
			"failed_map_elapsed_ms": failed_elapsed_ms,
			"status": "complete" if completed_maps >= map_count else "incomplete",
			"winner_id": winner_id_in,
			"reason": reason,
			"source": "timed_race_runtime"
		}, "submit_result:%s" % result_signature)
		tree.set_meta(TREE_META_CONTEST_RESULT_SIGNATURE, result_signature)
		SFLog.info("TIMED_RACE_CONTEST_RESULT_RECORDED", {
			"contest_id": contest_id,
			"player_id": player_id,
			"run_id": run_id,
			"rank": int(record.get("rank", 0)),
			"completed_maps": completed_maps,
			"map_count": map_count,
			"backend_submitted": bool(backend_result.get("ok", false)),
			"backend_err": str(backend_result.get("err", backend_result.get("code", "")))
		})
	else:
		SFLog.warn("TIMED_RACE_CONTEST_RESULT_RECORD_FAILED", record)

func _maybe_record_miss_n_out_contest_result(results: Array, winner_id_in: int, reason: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or _current_vs_mode() != "MISS_N_OUT":
		return
	var contest_id: String = _runtime_contest_id(tree)
	if contest_id.is_empty():
		return
	var identity: Dictionary = _resolve_jukebox_local_identity(tree)
	var player_id: String = str(identity.get("player_id", "")).strip_edges()
	if player_id.is_empty():
		return
	var local_owner_id: int = _resolve_local_owner_id()
	if local_owner_id <= 0:
		local_owner_id = clampi(active_player_id, 1, 4)
	var stage_maps: Array[String] = _get_stage_map_paths_runtime()
	var player_count: int = maxi(2, stage_maps.size() + 1)
	var ordered_results: Array[Dictionary] = _ordered_stage_results(results)
	var eliminated_round: int = 0
	var terminal_time_ms: int = 0
	for row in ordered_results:
		var round_number: int = maxi(1, int(row.get("round_number", int(row.get("round_index", 0)) + 1)))
		var elapsed_ms: int = maxi(0, int(row.get("elapsed_ms", 0)))
		terminal_time_ms = elapsed_ms
		if int(row.get("winner_id", 0)) != local_owner_id:
			eliminated_round = round_number
			break
	var won_run: bool = eliminated_round <= 0 and winner_id_in == local_owner_id and ordered_results.size() >= stage_maps.size()
	var placement: int = 1 if won_run else maxi(2, player_count - maxi(0, eliminated_round - 1))
	var run_id: String = _stage_race_run_id(tree, player_id)
	var result_signature: String = "miss_n_out|%s|%s|%s|%d|%d|%d" % [contest_id, player_id, run_id, placement, eliminated_round, terminal_time_ms]
	if str(tree.get_meta(TREE_META_CONTEST_RESULT_SIGNATURE, "")).strip_edges() == result_signature:
		return
	var contest_state: Node = get_node_or_null("/root/ContestState")
	if contest_state == null or not contest_state.has_method("record_miss_n_out_result"):
		return
	var record: Dictionary = contest_state.call("record_miss_n_out_result", contest_id, {
		"leaderboard": [{
			"player_id": player_id,
			"player_name": str(identity.get("handle", "You")).strip_edges(),
			"placement": placement,
			"is_winner": won_run,
			"eliminated": not won_run,
			"eliminated_round": eliminated_round,
			"time_ms": terminal_time_ms,
			"reason": reason
		}],
		"player_count": player_count,
		"updated_at": int(Time.get_unix_time_from_system()),
		"source": "miss_n_out_runtime"
	}) as Dictionary
	if bool(record.get("ok", false)):
		var submit_row: Dictionary = {
			"player_id": player_id,
			"player_name": str(identity.get("handle", "You")).strip_edges(),
			"placement": placement,
			"is_winner": won_run,
			"eliminated": not won_run,
			"eliminated_round": eliminated_round,
			"time_ms": terminal_time_ms,
			"reason": reason,
			"source": "miss_n_out_runtime"
		}
		var backend_result: Dictionary = _submit_async_contest_result_backend(contest_id, "MISS_N_OUT", player_id, submit_row, "submit_result:%s" % result_signature)
		tree.set_meta(TREE_META_CONTEST_RESULT_SIGNATURE, result_signature)
		tree.set_meta("miss_n_out_result", {
			"leaderboard": [submit_row]
		})
		SFLog.info("MISS_N_OUT_CONTEST_RESULT_RECORDED", {
			"contest_id": contest_id,
			"player_id": player_id,
			"run_id": run_id,
			"winner": won_run,
			"placement": placement,
			"eliminated_round": eliminated_round,
			"backend_submitted": bool(backend_result.get("ok", false)),
			"backend_err": str(backend_result.get("err", backend_result.get("code", "")))
		})
	else:
		SFLog.warn("MISS_N_OUT_CONTEST_RESULT_RECORD_FAILED", record)

func _submit_async_contest_result_backend(contest_id: String, contest_family: String, player_id: String, result: Dictionary, idempotency_key: String) -> Dictionary:
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null or not handshake.has_method("submit_async_contest_result"):
		return {"ok": false, "handled": false, "err": "transport_not_configured"}
	return handshake.call("submit_async_contest_result", contest_id, contest_family, player_id, result, idempotency_key) as Dictionary

func _runtime_contest_id(tree: SceneTree) -> String:
	if tree == null:
		return ""
	var contest_id: String = str(tree.get_meta("contest_id", "")).strip_edges()
	if contest_id.is_empty():
		contest_id = str(tree.get_meta("async_money_contest_id", "")).strip_edges()
	return contest_id

func _ordered_stage_results(results: Array) -> Array[Dictionary]:
	var ordered: Array[Dictionary] = []
	for result_any in results:
		if typeof(result_any) != TYPE_DICTIONARY:
			continue
		ordered.append((result_any as Dictionary).duplicate(true))
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_index: int = int(a.get("round_index", 0))
		var b_index: int = int(b.get("round_index", 0))
		if a_index != b_index:
			return a_index < b_index
		return int(a.get("recorded_ms", 0)) < int(b.get("recorded_ms", 0))
	)
	return ordered

func _int_values_as_strings(values: Array[int]) -> Array[String]:
	var out: Array[String] = []
	for value in values:
		out.append(str(int(value)))
	return out

func _progressive_completed_stage_count(stage_results: Array) -> int:
	var completed: int = 0
	for result_any in stage_results:
		if typeof(result_any) != TYPE_DICTIONARY:
			continue
		completed += 1
	return completed

func _progressive_total_elapsed_ms(stage_results: Array) -> int:
	var total: int = 0
	for result_any in stage_results:
		if typeof(result_any) != TYPE_DICTIONARY:
			continue
		total += maxi(0, int((result_any as Dictionary).get("elapsed_ms", 0)))
	return total

func _show_progressive_stage_overlay(winner_id_in: int, reason: String) -> void:
	var summary: Dictionary = _build_progressive_stage_summary(winner_id_in, reason)
	if bool(summary.get("next_round_available", false)):
		_post_match_action_taken = true
		SFLog.info("PROGRESSIVE_AUTO_ADVANCE", {
			"stage_index": int(summary.get("stage_index", -1)),
			"next_stage_index": int(summary.get("stage_index", -1)) + 1,
			"stars": int(summary.get("stars", 0)),
			"total_stars": int(summary.get("total_stars", 0))
		})
		call_deferred("_auto_advance_progressive_stage")
		return
	if outcome_overlay == null:
		_ensure_post_match_ui()
	if outcome_overlay == null:
		SFLog.warn("POSTMATCH_UI_MISSING", {"kind": "outcome_overlay_progressive"})
		return
	if summary.is_empty():
		var record_slot: int = clampi(active_player_id, 1, 4)
		outcome_overlay.show_outcome(winner_id_in, reason, active_player_id, _get_player_record_line(record_slot), _get_h2h_record_line())
		return
	outcome_overlay.show_stage_round_outcome(summary)

func _auto_advance_progressive_stage() -> void:
	_advance_progressive_stage()

func _progressive_stage_plan(tree: SceneTree) -> Array:
	if tree == null:
		return []
	var plan_any: Variant = tree.get_meta("progressive_stage_plan", [])
	if typeof(plan_any) == TYPE_ARRAY:
		return plan_any as Array
	var run: Dictionary = _progressive_run_store.load_current_run()
	var run_plan_any: Variant = run.get("stage_plan", [])
	if typeof(run_plan_any) == TYPE_ARRAY:
		return run_plan_any as Array
	return []

func _progressive_stage_count(tree: SceneTree) -> int:
	return maxi(1, _progressive_stage_plan(tree).size())

func _progressive_stage_at(tree: SceneTree, index: int) -> Dictionary:
	var plan: Array = _progressive_stage_plan(tree)
	if not plan.is_empty():
		var clamped: int = clampi(index, 0, plan.size() - 1)
		var stage_any: Variant = plan[clamped]
		if typeof(stage_any) == TYPE_DICTIONARY:
			return (stage_any as Dictionary).duplicate(true)
	return {
		"stage_index": index,
		"stage_number": index + 1,
		"map_path": _progressive_current_stage_map_path(tree),
		"thresholds_ms": tree.get_meta("progressive_thresholds_ms", {}) if tree != null else {}
	}

func _progressive_current_stage_map_path(tree: SceneTree) -> String:
	if tree == null:
		return ""
	var paths_any: Variant = tree.get_meta(TREE_META_VS_STAGE_MAP_PATHS, [])
	if typeof(paths_any) != TYPE_ARRAY:
		return ""
	var paths: Array = paths_any as Array
	if paths.is_empty():
		return ""
	var index: int = clampi(int(tree.get_meta(TREE_META_VS_STAGE_CURRENT_INDEX, 0)), 0, paths.size() - 1)
	return str(paths[index]).strip_edges()

func _advance_progressive_stage() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var run: Dictionary = _progressive_run_store.load_current_run()
	if run.is_empty():
		_clear_progressive_runtime_meta()
		_return_to_main_menu()
		return
	var stage: Dictionary = _progressive_run_store.current_stage(run)
	if stage.is_empty() or str(run.get("status", "")).strip_edges() != ProgressiveRunStoreScript.STATUS_ACTIVE:
		_clear_progressive_runtime_meta()
		_return_to_main_menu()
		return
	var map_path: String = str(stage.get("map_path", "")).strip_edges()
	if map_path.is_empty():
		_clear_progressive_runtime_meta()
		_return_to_main_menu()
		return
	_apply_progressive_stage_tree_meta(run, stage)
	SFLog.info("PROGRESSIVE_ADVANCE_ATTEMPT", {
		"run_id": str(run.get("run_id", "")),
		"stage_index": int(run.get("stage_index", -1)),
		"stage_number": int(stage.get("stage_number", int(run.get("stage_index", 0)) + 1)),
		"map_path": map_path,
		"bot_style": str(stage.get("bot_style", "")),
		"bot_tier": str(stage.get("bot_tier", ""))
	})
	if outcome_overlay != null:
		outcome_overlay.hide_overlay()
	_stop_post_match_song(false)
	var shell: Node = get_node_or_null("/root/Shell")
	if shell != null and shell.has_method("_apply_map_then_start"):
		SFLog.info("PROGRESSIVE_ADVANCE_SHELL_APPLY", {"map_path": map_path})
		shell.call_deferred("_apply_map_then_start", map_path)
		return
	var gamebot: Node = get_node_or_null("/root/Gamebot")
	if gamebot != null:
		if gamebot.has_method("set_vs"):
			gamebot.call("set_vs", map_path)
		else:
			gamebot.set("next_map_id", map_path)
	tree.set_meta("start_game", true)
	SFLog.info("PROGRESSIVE_ADVANCE_SCENE_FALLBACK", {"map_path": map_path})
	tree.change_scene_to_file(SHELL_SCENE_PATH)

func _apply_progressive_stage_tree_meta(run: Dictionary, stage: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var map_path: String = str(stage.get("map_path", "")).strip_edges()
	var stage_index: int = int(stage.get("stage_index", int(run.get("stage_index", 0))))
	var bot_style: String = str(stage.get("bot_style", "balancer")).strip_edges().to_lower()
	var bot_tier: String = str(stage.get("bot_tier", ProgressiveConfigScript.BOT_TIER_EASY)).strip_edges().to_lower()
	var map_ids := PackedStringArray()
	var map_id: String = str(stage.get("map_id", MapRegistry.map_id_from_path(map_path))).strip_edges()
	if not map_id.is_empty():
		map_ids.append(map_id)
	tree.set_meta("start_game", true)
	tree.set_meta(TREE_META_VS_MODE, VS_MODE_PROGRESSIVE)
	tree.set_meta(TREE_META_VS_STAGE_MAP_PATHS, [map_path])
	tree.set_meta(TREE_META_VS_STAGE_CURRENT_INDEX, stage_index)
	tree.set_meta(TREE_META_VS_STAGE_RUN_ID, str(run.get("run_id", "")))
	tree.set_meta("map_ids", map_ids)
	tree.set_meta(TREE_META_VS_CPU_STYLE, bot_style)
	tree.set_meta(TREE_META_VS_CPU_TIER, bot_tier)
	tree.set_meta("progressive_run_id", str(run.get("run_id", "")))
	tree.set_meta("progressive_stage_plan", (run.get("stage_plan", []) as Array).duplicate(true))
	tree.set_meta("progressive_stage_index", stage_index)
	tree.set_meta("progressive_stage_number", int(stage.get("stage_number", stage_index + 1)))
	tree.set_meta("progressive_thresholds_ms", (stage.get("thresholds_ms", {}) as Dictionary).duplicate(true))
	tree.set_meta("progressive_conquerable_hive_count", int(stage.get("conquerable_hive_count", 1)))
	tree.set_meta("progressive_npc_power_bonus", int(stage.get("npc_power_bonus", 0)))
	tree.set_meta("progressive_bot_start_power_bonus", int(stage.get("bot_start_power_bonus", 0)))
	tree.set_meta("progressive_player_start_power_delta", int(stage.get("player_start_power_delta", 0)))
	tree.set_meta("progressive_bot_attack_grace_ms", ProgressiveConfigScript.BOT_ATTACK_GRACE_MS)
	tree.set_meta("progressive_human_owner_id", ProgressiveConfigScript.HUMAN_OWNER_ID)
	tree.set_meta("progressive_bot_attack_grace_broken", false)
	tree.set_meta("progressive_total_stars", int(run.get("total_stars", 0)))
	tree.set_meta("progressive_max_stars", int(run.get("max_stars", 0)))
	_update_progressive_counter_ui()

func _advance_stage_race_round() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var stage_maps: Array[String] = _get_stage_map_paths_runtime()
	if stage_maps.is_empty():
		_return_to_main_menu()
		return
	var current_index: int = int(tree.get_meta(TREE_META_VS_STAGE_CURRENT_INDEX, 0))
	var next_index: int = current_index + 1
	if next_index < 0 or next_index >= stage_maps.size():
		_clear_stage_runtime_meta()
		_return_to_main_menu()
		return
	var next_map_path: String = str(stage_maps[next_index]).strip_edges()
	if next_map_path.is_empty():
		_clear_stage_runtime_meta()
		_return_to_main_menu()
		return
	tree.set_meta(TREE_META_VS_STAGE_CURRENT_INDEX, next_index)
	if outcome_overlay != null:
		outcome_overlay.hide_overlay()
	await _fade_out_post_match_song_blocking()
	var shell: Node = get_node_or_null("/root/Shell")
	if shell != null and shell.has_method("_apply_map_then_start"):
		shell.call("_apply_map_then_start", next_map_path)
		return
	var gamebot: Node = get_node_or_null("/root/Gamebot")
	if gamebot != null:
		if gamebot.has_method("set_vs"):
			gamebot.call("set_vs", next_map_path)
		else:
			gamebot.set("next_map_id", next_map_path)
	var ops_state: Node = get_node_or_null("/root/OpsState")
	if ops_state != null and ops_state.has_method("set_team_mode_override"):
		ops_state.call("set_team_mode_override", "ffa")
	tree.set_meta("start_game", true)
	tree.change_scene_to_file(SHELL_SCENE_PATH)

func _clear_stage_runtime_meta() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var keys: Array[String] = [
		TREE_META_VS_MODE,
		TREE_META_VS_STAGE_MAP_PATHS,
		TREE_META_VS_STAGE_CURRENT_INDEX,
		TREE_META_VS_STAGE_ROUND_RESULTS,
		TREE_META_VS_STAGE_RUN_ID,
		TREE_META_ASYNC_BUFF_CONTEST_STATE,
		TREE_META_BUFF_ACTIVATION_RUNTIME_STATE,
		TREE_META_CONTEST_RESULT_SIGNATURE,
		"miss_n_out_local_player_id",
		"miss_n_out_eliminated",
		"miss_n_out_notice",
		"miss_n_out_result"
	]
	for key in keys:
		if tree.has_meta(key):
			tree.remove_meta(key)

func _clear_progressive_runtime_meta() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var keys: Array[String] = [
		TREE_META_VS_MODE,
		TREE_META_VS_STAGE_MAP_PATHS,
		TREE_META_VS_STAGE_CURRENT_INDEX,
		TREE_META_VS_STAGE_ROUND_RESULTS,
		TREE_META_VS_STAGE_RUN_ID,
		TREE_META_VS_CPU_STYLE,
		TREE_META_VS_CPU_TIER,
		TREE_META_CONTEST_RESULT_SIGNATURE,
		"map_ids",
		"progressive_run_id",
		"progressive_stage_plan",
		"progressive_stage_index",
		"progressive_stage_number",
		"progressive_thresholds_ms",
		"progressive_conquerable_hive_count",
		"progressive_npc_power_bonus",
		"progressive_bot_start_power_bonus",
		"progressive_player_start_power_delta",
		"progressive_bot_attack_grace_ms",
		"progressive_human_owner_id",
		"progressive_bot_attack_grace_broken",
		"progressive_total_stars",
		"progressive_max_stars"
	]
	for key in keys:
		if tree.has_meta(key):
			tree.remove_meta(key)
	_update_progressive_counter_ui()

func _handle_rematch() -> void:
	if current_map_data.is_empty():
		if SFLog.LOGGING_ENABLED:
			push_error("ARENA: rematch failed (no map data)")
		return
	if not _prepare_paid_vs_rematch_if_needed():
		_post_match_action_taken = false
		return
	SFLog.info("MATCH_RESET", {"map": current_map_name})
	if outcome_overlay != null:
		outcome_overlay.hide_overlay()
	_reset_sim_state()
	MapApplier.apply_map(self, current_map_data.duplicate(true))

func _paid_vs_rematch_funding_blocked(owner_id: int) -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or not bool(tree.get_meta("vs_paid_entry", false)):
		return false
	var session_id: String = str(tree.get_meta("vs_handshake_session_id", "")).strip_edges()
	if session_id.is_empty():
		return false
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null or not handshake.has_method("get_money_rematch_funding_status"):
		return false
	var funding: Dictionary = handshake.call("get_money_rematch_funding_status", session_id, owner_id) as Dictionary
	if not bool(funding.get("ok", false)):
		SFLog.warn("VS_MONEY_REMATCH_FUNDING_CHECK_FAILED", funding)
		return false
	if not bool(funding.get("payment_required", false)):
		return false
	_show_money_payment_required_prompt(funding)
	SFLog.info("VS_MONEY_REMATCH_FUNDS_REQUIRED", {
		"session_id": session_id,
		"owner_id": owner_id,
		"balance_cents": int(funding.get("balance_cents", 0)),
		"wager_cents": int(funding.get("wager_cents", 0)),
		"missing_cents": int(funding.get("missing_cents", 0))
	})
	return true

func _prepare_paid_vs_rematch_if_needed() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or not bool(tree.get_meta("vs_paid_entry", false)):
		return true
	var session_id: String = str(tree.get_meta("vs_handshake_session_id", "")).strip_edges()
	if session_id.is_empty():
		return true
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null or not handshake.has_method("prepare_money_rematch"):
		SFLog.warn("VS_MONEY_REMATCH_PREPARE_MISSING", {"session_id": session_id})
		return false
	var result: Dictionary = handshake.call("prepare_money_rematch", session_id) as Dictionary
	if not bool(result.get("ok", false)):
		SFLog.warn("VS_MONEY_REMATCH_PREPARE_FAILED", result)
		if str(result.get("code", result.get("err", ""))) == "insufficient_funds":
			var player_id: String = str(result.get("player_id", "")).strip_edges()
			var balance_cents: int = int(result.get("balance_cents", 0))
			var required_cents: int = int(result.get("required_cents", tree.get_meta("vs_wager_cents", 0)))
			_show_money_payment_required_prompt({
				"ok": true,
				"payment_required": true,
				"player_uid": player_id,
				"balance_cents": balance_cents,
				"wager_cents": required_cents,
				"missing_cents": maxi(0, required_cents - balance_cents),
				"session_id": session_id
			})
		return false
	var rematch_session: Dictionary = result.get("session", {}) as Dictionary
	var rematch_context: Dictionary = rematch_session.get("context", {}) as Dictionary
	var rematch_session_id: String = str(result.get("session_id", rematch_session.get("id", ""))).strip_edges()
	if rematch_session_id.is_empty():
		return false
	tree.set_meta("vs_handshake_session_id", rematch_session_id)
	tree.set_meta("vs_money_ledger_status", str(rematch_context.get("ledger_status", "escrowed")))
	tree.set_meta("vs_money_settlement_result", {})
	tree.set_meta("vs_money_transaction_ids", [])
	tree.set_meta("vs_wager_cents", int(rematch_context.get("wager_cents", tree.get_meta("vs_wager_cents", 0))))
	tree.set_meta("vs_price_usd", int(rematch_context.get("price_usd", tree.get_meta("vs_price_usd", 0))))
	SFLog.info("VS_MONEY_REMATCH_ESCROWED", {
		"parent_session_id": session_id,
		"rematch_session_id": rematch_session_id,
		"wager_cents": int(rematch_context.get("wager_cents", 0)),
		"pot_cents": int(rematch_context.get("pot_cents", 0))
	})
	return true

func _show_money_payment_required_prompt(funding: Dictionary) -> void:
	_money_payment_context = funding.duplicate(true)
	_ensure_money_payment_modal()
	if _money_payment_modal == null:
		return
	var wager_cents: int = int(funding.get("wager_cents", 0))
	var balance_cents: int = int(funding.get("balance_cents", 0))
	var missing_cents: int = int(funding.get("missing_cents", maxi(0, wager_cents - balance_cents)))
	if _money_payment_body_label != null:
		_money_payment_body_label.text = "Rematch entry: %s\nCash balance: %s\nAdd at least %s to play again." % [
			_money_cents_text(wager_cents),
			_money_cents_text(balance_cents),
			_money_cents_text(missing_cents)
		]
	if _money_payment_status_label != null:
		_money_payment_status_label.text = "Not enough cash for this rematch."
	_money_payment_layer.visible = true
	_money_payment_modal.visible = true

func _ensure_money_payment_modal() -> void:
	if _money_payment_modal != null and is_instance_valid(_money_payment_modal):
		return
	_money_payment_layer = CanvasLayer.new()
	_money_payment_layer.name = "MoneyPaymentLayer"
	_money_payment_layer.layer = 1200
	_money_payment_layer.visible = false
	add_child(_money_payment_layer)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.68)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	_money_payment_layer.add_child(backdrop)
	var modal: Panel = Panel.new()
	modal.name = "MoneyPaymentModal"
	modal.anchor_left = 0.5
	modal.anchor_top = 0.5
	modal.anchor_right = 0.5
	modal.anchor_bottom = 0.5
	modal.offset_left = -190.0
	modal.offset_top = -126.0
	modal.offset_right = 190.0
	modal.offset_bottom = 126.0
	modal.custom_minimum_size = Vector2(380.0, 252.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.10, 0.98)
	style.border_color = Color(1.0, 0.84, 0.36, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_top = 18.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 18.0
	modal.add_theme_stylebox_override("panel", style)
	_money_payment_layer.add_child(modal)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 18.0
	vbox.offset_top = 18.0
	vbox.offset_right = -18.0
	vbox.offset_bottom = -18.0
	vbox.add_theme_constant_override("separation", 10)
	modal.add_child(vbox)
	var title: Label = Label.new()
	title.text = "ADD CASH?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62, 1.0))
	vbox.add_child(title)
	_money_payment_body_label = Label.new()
	_money_payment_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_money_payment_body_label.add_theme_font_size_override("font_size", 16)
	_money_payment_body_label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.96, 1.0))
	vbox.add_child(_money_payment_body_label)
	_money_payment_status_label = Label.new()
	_money_payment_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_payment_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_money_payment_status_label.add_theme_font_size_override("font_size", 14)
	_money_payment_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.58, 1.0))
	vbox.add_child(_money_payment_status_label)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_END
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)
	var cancel_button: Button = Button.new()
	cancel_button.text = "NOT NOW"
	cancel_button.custom_minimum_size = Vector2(0.0, 48.0)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(_on_money_payment_cancel_pressed)
	buttons.add_child(cancel_button)
	var add_button: Button = Button.new()
	add_button.text = "ADD CASH"
	add_button.custom_minimum_size = Vector2(0.0, 48.0)
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button.pressed.connect(_on_money_payment_add_pressed)
	buttons.add_child(add_button)
	_money_payment_modal = modal

func _on_money_payment_cancel_pressed() -> void:
	if _money_payment_layer != null:
		_money_payment_layer.visible = false

func _on_money_payment_add_pressed() -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.set_meta("money_payment_window_requested", true)
		tree.set_meta("money_payment_window_context", _money_payment_context.duplicate(true))
	if _money_payment_status_label != null:
		_money_payment_status_label.text = "Payment provider window requested."

func _money_cents_text(amount_cents: int) -> String:
	var safe_amount: int = maxi(0, amount_cents)
	return "$%d.%02d" % [safe_amount / 100, safe_amount % 100]

func _return_to_main_menu() -> void:
	if outcome_overlay != null:
		outcome_overlay.hide_overlay()
	if sim_runner != null:
		sim_runner.log_pause_snapshot("arena_return_to_main_menu")
	var tree: SceneTree = get_tree()
	if tree != null and tree.has_meta(TREE_META_ASYNC_BUFF_CONTEST_STATE):
		tree.remove_meta(TREE_META_ASYNC_BUFF_CONTEST_STATE)
	await _fade_out_post_match_song_blocking()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _stage_race_run_id(tree: SceneTree, player_id: String) -> String:
	if tree == null:
		return ""
	var existing: String = str(tree.get_meta(TREE_META_VS_STAGE_RUN_ID, "")).strip_edges()
	if not existing.is_empty():
		return existing
	var clean_player_id: String = player_id.strip_edges()
	if clean_player_id.is_empty():
		clean_player_id = "local"
	var generated: String = "%s_%d_%d" % [clean_player_id.sha256_text().substr(0, 10), Time.get_unix_time_from_system(), Time.get_ticks_msec()]
	tree.set_meta(TREE_META_VS_STAGE_RUN_ID, generated)
	return generated

func _prepare_stage_race_finish_leaderboard_request() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or not _is_stage_race_runtime_mode():
		return
	var contest_id: String = str(tree.get_meta("contest_id", "")).strip_edges()
	if contest_id.is_empty():
		return
	var identity: Dictionary = _resolve_jukebox_local_identity(tree)
	var player_id: String = str(identity.get("player_id", "")).strip_edges()
	var stage_maps: Array[String] = _get_stage_map_paths_runtime()
	var map_count: int = maxi(1, stage_maps.size())
	var scope: String = str(tree.get_meta("contest_scope", "WEEKLY")).strip_edges().to_upper()
	if scope.is_empty():
		scope = "WEEKLY"
	tree.set_meta(TREE_META_PENDING_STAGE_LEADERBOARD, true)
	tree.set_meta(TREE_META_PENDING_STAGE_LEADERBOARD_CONTEXT, {
		"contest_id": contest_id,
		"scope": scope,
		"map_count": map_count,
		"paid": not bool(tree.get_meta("vs_free_roll", false)),
		"denomination": maxi(0, int(tree.get_meta("vs_price_usd", 0))),
		"player_id": player_id,
		"run_id": _stage_race_run_id(tree, player_id),
		"wager_cents": maxi(0, int(tree.get_meta("vs_wager_cents", maxi(0, int(tree.get_meta("vs_price_usd", 0))) * 100))),
		"async_money_entry_id": str(tree.get_meta("async_money_entry_id", "")),
		"async_money_ledger_status": str(tree.get_meta("async_money_ledger_status", "")),
		"async_money_pot_cents": maxi(0, int(tree.get_meta("async_money_pot_cents", 0))),
		"async_money_escrow_cents": maxi(0, int(tree.get_meta("async_money_escrow_cents", 0))),
		"async_money_ledger_source": str(tree.get_meta("async_money_ledger_source", "")),
		"async_money_balance_start_cents": maxi(0, int(tree.get_meta("async_money_balance_start_cents", 0))),
		"async_money_balance_after_entry_cents": maxi(0, int(tree.get_meta("async_money_balance_after_entry_cents", 0))),
		"async_money_balance_finish_cents": maxi(0, int(tree.get_meta("async_money_balance_finish_cents", tree.get_meta("async_money_balance_after_entry_cents", 0))))
	})

func _on_barracks_activated(_barracks_id: int, _owner_id: int) -> void:
	_play_barracks_activate_sfx()

func _on_lane_system_changed(lane: Dictionary) -> void:
	dbg_mark_event("lane_build")
	mark_render_dirty("lane_system")

	if lane_renderer != null:
		var lane_id: int = int(lane.get("lane_id", -1))
		if lane_id != -1:
			lane_renderer.mark_lane_changed(lane_id)
		else:
			lane_renderer.queue_redraw()

	_push_render_model()


func _on_lane_system_removed(lane_id: int) -> void:
	dbg_mark_event("lane_build")
	mark_render_dirty("lane_system_removed")

	if lane_renderer != null:
		lane_renderer.mark_lane_changed(lane_id)

	_push_render_model()


func _inject_renderer_references() -> void:
	if unit_renderer == null:
		return
	if lane_renderer == null:
		return
	if unit_renderer.has_method("setup_renderer_refs"):
		unit_renderer.call("setup_renderer_refs", lane_renderer)

func _hive_render_grid_pos(hive: HiveData) -> Vector2:
	if hive == null:
		return Vector2.ZERO
	var render_gp: Vector2 = hive.render_grid_pos
	if not is_finite(render_gp.x) or not is_finite(render_gp.y):
		render_gp = Vector2(float(hive.grid_pos.x), float(hive.grid_pos.y))
	return render_gp

func _hive_lane_occlusion_radius_px(radius_px: float = HIVE_RADIUS_PX, power: int = 0) -> float:
	return HiveGeometry.hive_visual_footprint_radius_px(maxf(1.0, radius_px), power)

func _sync_lane_system_blockers() -> void:
	if lane_system == null:
		return
	var hive_list: Array = []
	if hive_renderer != null:
		var nodes := hive_renderer.get_hive_nodes_by_id()
		for key in nodes.keys():
			var node := nodes.get(key) as Node2D
			if node == null:
				continue
			var radius_px: float = HIVE_RADIUS_PX
			if node.has_method("get"):
				var radius_v: Variant = node.get("radius_px")
				if radius_v != null:
					radius_px = float(radius_v)
			var power_px: int = 0
			if node.has_method("get"):
				var power_v: Variant = node.get("power")
				if power_v != null:
					power_px = int(power_v)
			hive_list.append({
				"id": int(key),
				"pos": node.position,
				"radius_px": _hive_lane_occlusion_radius_px(radius_px, power_px)
			})
	if hive_list.is_empty() and state != null:
		for hive in state.hives:
			var render_gp: Vector2 = _hive_render_grid_pos(hive)
			var radius_px: float = float(hive.radius_px)
			if radius_px <= 0.0:
				radius_px = HIVE_RADIUS_PX
			hive_list.append({
				"id": int(hive.id),
				"pos": _grid_coord_to_world(render_gp),
				"radius_px": _hive_lane_occlusion_radius_px(radius_px, int(hive.power))
			})
	if hive_list.is_empty():
		return
	lane_system.set_blockers_from_hives(hive_list, _hive_lane_occlusion_radius_px(HIVE_RADIUS_PX))

func get_game_state() -> GameState:
	return state

func _on_ops_state_changed(new_state: GameState) -> void:
	state = new_state
	if state == null:
		return
	# MapApplier swaps in a fresh authoritative state without calling Arena._reset_sim_state().
	# Clear post-match latches here so stage-race rounds can always advance.
	_clear_unit_visuals_for_state_swap()
	_stop_all_swarm_sfx()
	_match_end_handled = false
	_match_record_committed = false
	_post_match_action_taken = false
	_post_match_render_frozen = false
	_end_post_match_settle_if_supported()
	game_over = false
	winner_id = -1
	end_reason = ""
	_telemetry_active = false
	_post_match_analysis_summary.clear()
	_post_match_telemetry_path = ""
	if _match_telemetry_collector != null and _match_telemetry_collector.has_method("reset"):
		_match_telemetry_collector.call("reset")
	if OpsState != null and OpsState.has_method("set_match_telemetry_collector"):
		OpsState.call("set_match_telemetry_collector", _match_telemetry_collector)
	if outcome_overlay != null and outcome_overlay.has_method("clear_post_match_summary"):
		outcome_overlay.call("clear_post_match_summary")
	if api != null:
		api.bind_state(state)
	_ensure_sim_runner()
	if sim_runner != null:
		sim_runner.bind_state(state)
		if sim_runner.bound_iid != int(state.get_instance_id()):
			SFLog.error("SIM_BIND_MISMATCH", {
				"arena_iid": int(state.get_instance_id()),
				"sim_iid": int(sim_runner.bound_iid)
			})
	if lane_system != null and lane_system.state != state:
		lane_system.bind_state(state)
	if lane_renderer != null:
		lane_renderer.setup(state, sel, self)
	if hive_renderer != null:
		hive_renderer.setup(state, sel, self)
	_inject_renderer_references()
	_sync_lane_system_blockers()
	mark_render_dirty("ops_state_changed")
	if state.hives != null:
		set_process_unhandled_input(true)

func _clear_unit_visuals_for_state_swap() -> void:
	var unit_r: Node = unit_renderer
	if unit_r == null:
		unit_r = _resolve_unit_renderer()
		if unit_r is Node2D:
			unit_renderer = unit_r as Node2D
	if unit_r != null and unit_r.has_method("clear_all"):
		unit_r.call("clear_all")

func _on_ops_state_changed_iid(_payload: Variant = null) -> void:
	call_deferred("_start_sim_after_state_change")

func _start_sim_after_state_change() -> void:
	if sim_runner == null:
		SFLog.info("SIM_START_DEFERRED_FAIL", {"reason": "sim_runner_null"})
		return
	if OpsState.match_phase == OpsState.MatchPhase.PREMATCH:
		# A map swap creates a fresh OpsState in PREMATCH. Re-seed prematch gates so
		# stale round state does not block the next round from starting.
		_begin_prematch()
		SFLog.info("SIM_START_DEFERRED_SKIP", {"reason": "prematch_hold"})
		return
	SFLog.info("ARENA_START_SIM_AFTER_STATE", {"iid": int(sim_runner.bound_iid)})
	_start_match_sim("arena_after_ops_state_changed")

func _create_system(script_path: String, label: String) -> RefCounted:
	var script := load(script_path)
	if script == null:
		if SFLog.LOGGING_ENABLED:
			push_error("ARENA: failed to load %s system (%s)" % [label, script_path])
		return null
	if script is Script and not script.can_instantiate():
		if SFLog.LOGGING_ENABLED:
			push_error("ARENA: %s system script cannot instantiate (%s)" % [label, script_path])
		return null
	var instance = script.new()
	if instance == null:
		if SFLog.LOGGING_ENABLED:
			push_error("ARENA: failed to init %s system (%s)" % [label, script_path])
		return null
	return instance

func _exit_tree() -> void:
	clear_buff_hive_targeting(-1, "arena_scene_exit")
	clear_buff_lane_global_targeting(-1, "arena_scene_exit")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		if FIT_DEBUG:
			var viewport_size: Vector2 = get_viewport().get_visible_rect().size
			var window_size: Vector2i = DisplayServer.window_get_size()
			dbg("FIT: wm_size_changed viewport=%s window=%s" % [viewport_size, window_size])

func _on_viewport_size_changed() -> void:
	_camera_transition_lock_active = false
	_camera_transition_lock_frames = 0
	_apply_map_mm_background_art_layout()
	_resize_world_viewport()
	_center_match_timer()
	if _prematch_records_panel != null and _prematch_records_panel.visible:
		_layout_prematch_records_panel(_prematch_records_panel)
	if _prematch_ad_surface != null:
		_layout_prematch_ad_surface()
	if _in_game_ad_surface != null:
		_layout_in_game_ad_surface()
	if _prematch_identity_card != null and _prematch_identity_card.visible:
		_layout_prematch_identity_card()
	_snap_power_bar_to_map_top("viewport_resize")

func _resize_world_viewport() -> void:
	var tree: SceneTree = get_tree()
	var wvc: Control = _world_viewport_cache.resolve_container(tree) if _world_viewport_cache != null else null
	var sv: SubViewport = _world_viewport_cache.resolve_subviewport(tree) if _world_viewport_cache != null else null
	if wvc == null or sv == null:
		return
	var old_size: Vector2i = sv.size
	var target: Vector2 = wvc.size
	var new_w: int = max(1, int(target.x))
	var new_h: int = max(1, int(target.y))
	var new_size: Vector2i = Vector2i(new_w, new_h)
	SFLog.info("WVP_RESIZE", {
		"wvc_path": _node_path_for_log(wvc),
		"container_size": wvc.size,
		"sv_old": old_size,
		"sv_new": new_size
	})

func _ensure_playfield_outline() -> PlayfieldOutline:
	if is_instance_valid(_playfield_outline):
		_playfield_outline.enabled = false
		_playfield_outline.show_center_crosshair = false
		return _playfield_outline
	var map_root_node: Node = get_node_or_null("MapRoot")
	if map_root_node == null:
		return null
	var existing: Node = map_root_node.get_node_or_null("PlayfieldOutline")
	if existing != null and existing is PlayfieldOutline:
		_playfield_outline = existing as PlayfieldOutline
		_playfield_outline.enabled = false
		_playfield_outline.show_center_crosshair = false
		return _playfield_outline
	var po: PlayfieldOutline = PlayfieldOutline.new()
	po.name = "PlayfieldOutline"
	po.z_index = PLAYFIELD_OUTLINE_Z_INDEX
	po.z_as_relative = false
	po.enabled = false
	po.show_center_crosshair = false
	map_root_node.add_child(po)
	_playfield_outline = po
	return po

func _sync_playfield_outline() -> void:
	var po: PlayfieldOutline = _ensure_playfield_outline()
	if po == null:
		return
	po.set_playfield_rect_world(_arena_rect())

func _configure_grid_spec(grid_w_in: int, grid_h_in: int) -> void:
	var cell_px := _cell_px()
	var origin := map_offset
	if grid_spec == null:
		grid_spec = GridSpec.new()
	grid_spec.configure(grid_w_in, grid_h_in, cell_px, origin, grid_coord_render_offset)
	_sync_playfield_outline()
	grid_w = grid_spec.grid_w
	grid_h = grid_spec.grid_h
	if floor_influence_system == null:
		_ensure_floor_influence_system()
	if floor_renderer != null:
		floor_renderer.margin_px = maxf(0.0, floor_side_visual_projection_px)
		floor_renderer.configure(grid_w, grid_h, cell_px, origin)
	if floor_influence_system != null and floor_renderer != null:
		floor_influence_system.configure_floor_bounds(floor_renderer.get_floor_bounds_rect())

func _log_map_spec(map_data: Dictionary) -> void:
	if not GRID_DEBUG or grid_spec == null:
		return
	var schema_id := str(map_data.get("_schema", ""))
	var rect := Rect2(
		grid_spec.origin,
		Vector2(grid_spec.grid_w * grid_spec.cell_size, grid_spec.grid_h * grid_spec.cell_size)
	)
	SFLog.trace("ARENA: map schema=%s grid=%dx%d rect=%s" % [
		schema_id,
		grid_spec.grid_w,
		grid_spec.grid_h,
		str(rect)
	])

func _apply_neutral_towers(map_data: Dictionary) -> void:
	if state == null:
		return
	_audit_state_write("towers", "Arena._apply_neutral_towers")
	state.towers = []
	var towers_v: Variant = map_data.get("towers", [])
	if typeof(towers_v) != TYPE_ARRAY:
		SFLog.info("NEUTRAL_TOWERS_APPLIED", {"count": 0, "sample": null})
		return
	var out: Array = []
	for tower_any in towers_v as Array:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = tower_any as Dictionary
		var tower_id: int = int(td.get("id", -1))
		if tower_id <= 0:
			continue
		var gp: Vector2i = Vector2i.ZERO
		var gp_v: Variant = td.get("grid_pos", null)
		if gp_v is Vector2i:
			gp = gp_v as Vector2i
		elif gp_v is Array:
			var gp_arr: Array = gp_v as Array
			if gp_arr.size() >= 2:
				gp = Vector2i(int(gp_arr[0]), int(gp_arr[1]))
		else:
			var x: int = int(td.get("x", 0))
			var y: int = int(td.get("y", 0))
			gp = Vector2i(x, y)
		var req_ids: Array = []
		var req_v: Variant = td.get("required_hive_ids", [])
		if typeof(req_v) == TYPE_ARRAY:
			for req_any in req_v as Array:
				req_ids.append(int(req_any))
		var control_ids: Array = []
		var control_v: Variant = td.get("control_hive_ids", [])
		if typeof(control_v) == TYPE_ARRAY:
			for control_any in control_v as Array:
				control_ids.append(int(control_any))
		out.append({
			"id": tower_id,
			"grid_pos": gp,
			"required_hive_ids": req_ids,
			"control_hive_ids": control_ids,
			"owner_id": int(td.get("owner_id", 0))
		})
	_audit_state_write("towers", "Arena._apply_neutral_towers")
	state.towers = out
	var sample: Variant = out[0] if out.size() > 0 else null
	SFLog.info("NEUTRAL_TOWERS_APPLIED", {"count": out.size(), "sample": sample})
	if out.size() > 0:
		var first: Dictionary = out[0] as Dictionary
		var first_gp_v: Variant = first.get("grid_pos", Vector2i.ZERO)
		var first_gp: Vector2i = Vector2i.ZERO
		if first_gp_v is Vector2i:
			first_gp = first_gp_v as Vector2i
		var px_pos: Vector2 = _cell_center(first_gp)
		SFLog.info("TOWER_FIRST_POS", {"grid_pos": first_gp, "pos_px": px_pos})

func load_from_map(map_data: Dictionary) -> void:
	_cancel_shell_buff_pointer_session("map_reload")
	clear_buff_hive_targeting(-1, "map_reload")
	clear_buff_lane_global_targeting(-1, "map_reload")
	if not _is_dev_or_editor_context():
		SFLog.warn("MAP_APPLY_ONE_WAY_DOOR", {
			"entrypoint": "Arena.load_from_map",
			"authoritative_runtime_entrypoint": "MapApplier.apply_map"
		})
		MapApplier.apply_map(self, map_data.duplicate(true))
		return
	los_cache.clear()
	state.hives.clear()
	state.lanes.clear()
	state.lane_sim_by_key.clear()
	# Units are owned by UnitSystem; don't clear/publish from Arena.
	# UnitSystem will reset its own units and keep state.units_by_lane["_all"] accurate.
	# state.units_by_lane.clear()
	hive_lane_order.clear()
	hive_power_prev.clear()
	active_orders_by_attacker.clear()
	grid_w = max(1, int(map_data.get("grid_w", GRID_W)))
	grid_h = max(1, int(map_data.get("grid_h", GRID_H)))
	current_map_data = map_data.duplicate(true)
	var hives_data: Array = map_data.get("hives", [])
	for hive_data in hives_data:
		var pos_arr: Array = hive_data.get("grid_pos", [0, 0])
		var gx_f: float = float(pos_arr[0])
		var gy_f: float = float(pos_arr[1])
		var grid_pos: Vector2i = Vector2i(int(floor(gx_f)), int(floor(gy_f)))
		var owner_id: int = int(hive_data.get("owner_id", 0))
		var power: int = START_POWER
		var kind: String = str(hive_data.get("kind", "Hive"))
		var radius_px: float = float(hive_data.get("radius_px", hive_data.get("radius", 0.0)))
		if radius_px <= 0.0:
			radius_px = MapSchema.hive_radius_px_for_kind(kind, _cell_px())
		var hive := HiveData.new(
			int(hive_data["id"]),
			grid_pos,
			owner_id,
			power,
			kind,
			radius_px,
			Vector2(gx_f, gy_f)
		)
		state.hives.append(hive)
		hive_lane_order[hive.id] = []
		hive_power_prev[hive.id] = hive.power
	# Design rule: maps do not author active lanes.
	# Live lanes are created at runtime from intents and occlusion checks.
	state.lanes.clear()
	_audit_state_write("map_lanes", "Arena.load_from_map")
	state.map_lanes = []
	if lane_system != null and lane_system.state != state:
		lane_system.bind_state(state)
	SFLog.info("STATE_IID_AFTER_APPLY", {"iid": int(state.get_instance_id())})
	var structure_sets: Array = []
	var structure_positions: Array = []
	towers = []
	if tower_system != null:
		tower_system.init_from_map(map_data)
		towers = tower_system.towers
		structure_sets = tower_system.get_structure_sets().duplicate()
		structure_positions = tower_system.get_structure_positions().duplicate()
	_apply_neutral_towers(map_data)
	barracks = []
	for b in map_data.get("barracks", []):
		var b_pos: Array = b.get("grid_pos", [0, 0])
		var b_grid_pos := Vector2i(int(b_pos[0]), int(b_pos[1]))
		var required: Array = b.get("required_hive_ids", [])
		var computed: Array = _structure_required_hives_for(
			b_grid_pos,
			required,
			structure_sets,
			structure_positions
		)
		structure_sets.append(computed)
		if computed.size() >= BARRACKS_MIN_REQ:
			structure_positions.append(_structure_center_for_required(computed, _cell_center(b_grid_pos)))
		barracks.append({
			"id": int(b["id"]),
			"grid_pos": b_grid_pos,
			"required_hive_ids": computed,
			"control_hive_ids": computed.duplicate(),
			"route_targets": [],
			"route_hive_ids": [],
			"route_mode": "round_robin",
			"route_cursor": 0,
			"active": false,
			"owner_id": 0,
			"tier": 1,
			"spawn_accum_ms": 0.0,
			"rr_index": 0,
			"preferred_targets": []
		})
	if state != null:
		_audit_state_write("barracks", "Arena.load_from_map")
		state.barracks = barracks
	_center_map_offset(map_data)
	_configure_grid_spec(grid_w, grid_h)
	var cam_zoom := camera.zoom if camera != null else Vector2.ONE
	SFLog.trace("ARENA: map_loaded hives=%d lanes=%d grid=%dx%d rect=%s cam_zoom=%s" % [
		state.hives.size(),
		state.lanes.size(),
		grid_w,
		grid_h,
		str(_arena_rect()),
		str(cam_zoom)
	])
	current_map_path = str(map_data.get("__path", ""))
	if current_map_path != "":
		current_map_name = current_map_path.get_file()
	_log_map_spec(map_data)
	_reset_sim_state()
	# Fresh map loads must re-enter prematch/bootstrap instead of eagerly starting sim.
	_map_build_version += 1
	on_map_built()
	_render_dirty = true
	_push_render_model()
	_sync_playfield_outline()

func apply_loaded_map(map: Dictionary) -> void:
	if not _is_dev_or_editor_context():
		SFLog.warn("MAP_APPLY_ONE_WAY_DOOR", {
			"entrypoint": "Arena.apply_loaded_map",
			"authoritative_runtime_entrypoint": "MapApplier.apply_map"
		})
		MapApplier.apply_map(self, map.duplicate(true))
		return
	if map.is_empty():
		if SFLog.LOGGING_ENABLED:
			push_error("ARENA: apply_loaded_map failed (empty map)")
		return
	_reset_sim_state()
	if get_node_or_null("/root/DevMapRunner") != null:
		var spawns_v: Variant = map.get("spawns", [])
		if typeof(spawns_v) == TYPE_ARRAY and (spawns_v as Array).is_empty():
			var dev_spawns: Array = []
			var hives_v: Variant = map.get("hives", [])
			if typeof(hives_v) == TYPE_ARRAY:
				for hive_v in hives_v as Array:
					if typeof(hive_v) != TYPE_DICTIONARY:
						continue
					var hd: Dictionary = hive_v as Dictionary
					var owner_id: int = int(hd.get("owner_id", 0))
					if owner_id <= 0:
						continue
					dev_spawns.append({
						"hive_id": hd.get("id", 0),
						"rate": 1.0,
						"owner_id": owner_id
					})
			map["spawns"] = dev_spawns
			SFLog.trace("DEV_FALLBACK: seeded spawns=%d" % dev_spawns.size())
	state = OpsState.require_state()
	if lane_system != null and lane_system.state != state:
		lane_system.bind_state(state)
	if lane_renderer != null:
		lane_renderer.setup(state, sel, self)
	if hive_renderer != null:
		hive_renderer.setup(state, sel, self)
	_inject_renderer_references()
	hive_lane_order.clear()
	hive_power_prev.clear()
	grid_w = max(1, int(map.get("grid_w", GRID_W)))
	grid_h = max(1, int(map.get("grid_h", GRID_H)))
	current_map_data = map.duplicate(true)
	_configure_grid_spec(grid_w, grid_h)
	towers = []
	if tower_system != null:
		tower_system.init_from_map(map)
		towers = tower_system.towers
	_apply_neutral_towers(map)
	_sync_lane_system_blockers()
	mark_render_dirty("apply_loaded_map")
	model = export_render_model()
	_push_render_model()
	_sync_playfield_outline()
	SFLog.trace("POST-LOAD: candidates=%d actives=%d" % [
		(state.lane_candidates as Array).size(),
		(state.lanes as Array).size()
	])
	SFLog.trace("SIM: running=%s autostart=%s" % [sim_running, autostart])

func reset_match() -> void:
	if current_map_data.is_empty():
		if SFLog.LOGGING_ENABLED:
			push_error("ARENA: reset_match failed (no map data)")
		return
	load_from_map(current_map_data.duplicate(true))

func notify_map_built() -> void:
	_cancel_shell_buff_pointer_session("map_rebuilt")
	clear_buff_hive_targeting(-1, "map_rebuilt")
	clear_buff_lane_global_targeting(-1, "map_rebuilt")
	_fit_serial += 1
	_fit_applied_serial = -1
	_camera_fit_signature_last = ""

func on_map_built() -> void:
	if _map_built_version == _map_build_version:
		return
	_cancel_shell_buff_pointer_session("map_rebuilt")
	_map_built_version = _map_build_version
	_rebuild_map_markers()
	_normalize_map_root()
	_apply_arena_polish_runtime_settings()
	if lane_renderer != null:
		lane_renderer.setup(state, sel, self)
	if hive_renderer != null:
		SFLog.trace("HIVE_RENDERER_REF", {"ref": hive_renderer})
		hive_renderer.setup(state, sel, self)
	_inject_renderer_references()
	_sync_lane_system_blockers()
	mark_render_dirty("map_built")
	_debug_map_bounds("map_built")
	_debug_camera("map_built")

func _cancel_shell_buff_pointer_session(reason: String) -> void:
	var shell: Node = get_node_or_null("/root/Shell")
	if shell != null and shell.has_method("cancel_buff_pointer_session"):
		shell.call("cancel_buff_pointer_session", reason)

func fitcam_once() -> void:
	apply_camera_fit_next_frame("fitcam_once")

func _fitcam_verify_next_frame() -> void:
	var cam := $Camera2D
	SFLog.trace("FITCAM_VERIFY", {
		"zoom_now": cam.zoom,
		"pos_now": cam.global_position,
		"is_current": (get_viewport().get_camera_2d() == cam)
	})

func _find_overlay_controls() -> Array[Control]:
	var overlays: Array[Control] = []
	var root := get_tree().root
	if root == null:
		return overlays
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is Control):
			continue
		var control := node as Control
		if not control.visible:
			continue
		if control.is_in_group("dev_overlay") or control is DevMapPicker or control.name.find("DevMapLoader") != -1:
			overlays.append(control)
	return overlays

func _compute_safe_rect(viewport_size: Vector2) -> Dictionary:
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var safe_rect: Rect2 = Rect2(Vector2.ZERO, viewport_size)
	var overlays_info: Array = []
	var viewport_center: Vector2 = viewport_size * 0.5
	var overlays := _find_overlay_controls()
	for control in overlays:
		var rect_pos: Vector2 = control.global_position
		var rect_size: Vector2 = control.size
		var rect := Rect2(rect_pos, rect_size)
		overlays_info.append({
			"name": control.name,
			"rect": rect
		})
		if not rect.intersects(viewport_rect):
			continue
		var rect_center: Vector2 = rect_pos + rect_size * 0.5
		if rect_pos.x <= 0.0 or rect_center.x < viewport_center.x:
			safe_rect.position.x = max(safe_rect.position.x, rect.position.x + rect.size.x)
		if rect_pos.y <= 0.0 or rect_center.y < viewport_center.y:
			safe_rect.position.y = max(safe_rect.position.y, rect.position.y + rect.size.y)
	safe_rect.size.x = max(1.0, viewport_size.x - safe_rect.position.x)
	safe_rect.size.y = max(1.0, viewport_size.y - safe_rect.position.y)
	return {
		"safe_rect": safe_rect,
		"overlays": overlays_info
	}

func _get_autostart() -> bool:
	if sim_runner != null:
		return bool(sim_runner.autostart)
	return _autostart_shadow

func _set_autostart(value: bool) -> void:
	_autostart_shadow = value
	if sim_runner != null:
		sim_runner.autostart = value

func _get_sim_running() -> bool:
	if sim_runner != null:
		return bool(sim_runner.running)
	return _sim_running_shadow

func get_hive_count() -> int:
	var st: GameState = OpsState.get_state() if OpsState != null else null
	if st != null and st.hives != null:
		return int(st.hives.size())
	return 0

func _set_sim_running(value: bool) -> void:
	_sim_running_shadow = value
	if sim_runner != null:
		sim_runner.set_running(value)
		sim_runner.log_pause_snapshot("arena_set_sim_running")

func _apply_autostart() -> void:
	if sim_runner == null:
		return
	# IMPORTANT:
	# Do NOT force stop here. Stopping is a user action (pause button) or mode decision elsewhere.
	# Autostart should only START when enabled, otherwise leave running state unchanged.
	if not autostart:
		SFLog.info("SIM_AUTOSTART_SKIP", {"autostart": autostart})
		return
	if not _can_apply_autostart_now():
		SFLog.info("SIM_AUTOSTART_DEFER", {
			"phase": int(OpsState.match_phase) if OpsState != null else -1,
			"input_locked": bool(OpsState.input_locked) if OpsState != null else false,
			"match_started": _match_started
		})
		return
	# autostart == true
	sim_runner.set_running(true, "arena_apply_autostart_true")

func _can_apply_autostart_now() -> bool:
	if sim_runner == null or state == null or OpsState == null:
		return false
	if _match_started:
		return true
	return OpsState.match_phase == OpsState.MatchPhase.RUNNING and not bool(OpsState.input_locked)

func start_sim() -> void:
	if sim_runner == null:
		return
	autostart = true
	sim_runner.start_sim()
	sim_runner.log_pause_snapshot("arena_start_sim")

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var process_t0_us: int = Time.get_ticks_usec()
	_maybe_debug_camera_probe(delta)
	_hb_record_frame(delta)
	_maybe_log_frame_hitch(delta)
	_tick_arena_runtime(delta)
	_poll_match_telemetry_async_save()
	_hb_record_process_cost(process_t0_us)
	_hb_maybe_flush()

func _maybe_debug_camera_probe(delta: float) -> void:
	if not debug_cam_probe:
		return
	_cam_probe_accum += delta
	if _cam_probe_accum < 0.5:
		return
	_cam_probe_accum = 0.0
	var tree: SceneTree = get_tree()
	var sv: SubViewport = _world_viewport_cache.resolve_subviewport(tree) if _world_viewport_cache != null else null
	var cam: Camera2D = null
	if sv != null:
		cam = sv.get_camera_2d()
	SFLog.info("CAM_PROBE", {
		"sv_found": sv != null,
		"sv_size": sv.size if sv != null else Vector2.ZERO,
		"cam_found": cam != null,
		"cam_zoom": cam.zoom if cam != null else Vector2.ZERO
	})

func _tick_arena_heartbeat(delta: float) -> void:
	_hb_record_frame(delta)
	_hb_maybe_flush()
	_maybe_log_frame_hitch(delta)

func _tick_arena_runtime(delta: float) -> void:
	_enforce_camera_transition_lock()
	_update_prematch_flow(delta)
	if OpsState.match_phase == OpsState.MatchPhase.PREMATCH \
	and int(OpsState.prematch_remaining_ms) <= 0 \
	and _prematch_countdown_faded \
	and (_prematch_countdown_label == null or _prematch_countdown_label.modulate.a <= 0.01) \
	and bool(OpsState.input_locked):
		SFLog.warn("PREMATCH_WATCHDOG_FINISH", {
			"remaining_ms": int(OpsState.prematch_remaining_ms),
			"input_locked": bool(OpsState.input_locked),
			"countdown_alpha": _prematch_countdown_label.modulate.a if _prematch_countdown_label != null else -1.0
		})
		_finish_prematch()
	if input_system != null:
		input_system.tick(delta, api)
		_sync_inputs_locked_from_state()
	_pump_vs_pvp_runtime(delta)
	_maybe_publish_spectator_snapshot(delta)
	_update_timer_ui()
	_update_progressive_counter_ui()
	if tie_toast != null and tie_toast_ms > 0.0:
		tie_toast_ms = max(0.0, tie_toast_ms - delta * 1000.0)
		if tie_toast_ms <= 0.0:
			tie_toast.visible = false
	_update_win_overlay()
	_update_selection_hud()
	_update_buff_ui()
	if wall_renderer != null and is_instance_valid(wall_renderer):
		wall_renderer.tick_visuals(delta)
	_refresh_capture_flag_move_button()
	if _tutorial_controls_controller != null and state != null:
		_tutorial_controls_controller.tick(state, _resolve_local_owner_id())
	if _tutorial_section1_controller != null and state != null:
		_tutorial_section1_controller.tick(state, _resolve_local_owner_id())
	if _tutorial_section2_controller != null and state != null:
		_tutorial_section2_controller.tick(state, _resolve_local_owner_id())
	if _tutorial_section3_controller != null and state != null:
		_tutorial_section3_controller.tick(state, _resolve_local_owner_id())
	_update_runtime_telemetry_overlay()

func _arm_camera_transition_lock(reason: String) -> void:
	var cam: Camera2D = camera if camera != null else $Camera2D
	if cam == null:
		return
	_camera_transition_lock_pos = cam.global_position
	_camera_transition_lock_zoom = cam.zoom
	_camera_transition_lock_frames = 8
	_camera_transition_lock_active = true
	SFLog.warn("CAMFIT_TRANSITION_LOCK_ARMED", {
		"reason": reason,
		"pos": _camera_transition_lock_pos,
		"zoom": _camera_transition_lock_zoom,
		"frames": _camera_transition_lock_frames
	})

func _enforce_camera_transition_lock() -> void:
	if not _camera_transition_lock_active:
		return
	if _camera_transition_lock_frames <= 0:
		_camera_transition_lock_active = false
		return
	if OpsState == null or int(OpsState.match_phase) != int(OpsState.MatchPhase.RUNNING):
		return
	var cam: Camera2D = camera if camera != null else $Camera2D
	if cam == null:
		_camera_transition_lock_active = false
		_camera_transition_lock_frames = 0
		return
	var pos_delta: float = cam.global_position.distance_to(_camera_transition_lock_pos)
	var zoom_delta: float = (cam.zoom - _camera_transition_lock_zoom).length()
	if pos_delta > 0.1 or zoom_delta > 0.0001:
		SFLog.warn("CAMFIT_TRANSITION_DRIFT", {
			"phase": int(OpsState.match_phase),
			"prematch_ms": int(OpsState.prematch_remaining_ms),
			"pos_delta": pos_delta,
			"zoom_delta": zoom_delta,
			"from_pos": cam.global_position,
			"from_zoom": cam.zoom,
			"to_pos": _camera_transition_lock_pos,
			"to_zoom": _camera_transition_lock_zoom,
			"frames_left": _camera_transition_lock_frames
		})
	cam.global_position = _camera_transition_lock_pos
	cam.zoom = _camera_transition_lock_zoom
	cam.force_update_scroll()
	_camera_transition_lock_frames -= 1
	if _camera_transition_lock_frames <= 0:
		_camera_transition_lock_active = false

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_hb_record_physics(delta)

func _hb_record_frame(delta: float) -> void:
	var frame_ms: float = delta * 1000.0
	_hb_frames += 1
	_hb_sum_frame_ms += frame_ms
	if frame_ms > _hb_max_frame_ms:
		_hb_max_frame_ms = frame_ms

func _hb_record_process_cost(process_t0_us: int) -> void:
	var process_ms: float = float(Time.get_ticks_usec() - process_t0_us) / 1000.0
	_hb_sum_process_ms += process_ms
	if process_ms > _hb_max_process_ms:
		_hb_max_process_ms = process_ms
	var engine_process_ms: float = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	if engine_process_ms > _hb_max_engine_process_ms:
		_hb_max_engine_process_ms = engine_process_ms

func _hb_record_physics(delta: float) -> void:
	var phys_ms: float = delta * 1000.0
	_hb_phys += 1
	_hb_sum_phys_ms += phys_ms
	if phys_ms > _hb_max_phys_ms:
		_hb_max_phys_ms = phys_ms

func _hb_maybe_flush() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if _hb_last_ms <= 0:
		_hb_last_ms = now_ms
		return
	var window_ms: int = now_ms - _hb_last_ms
	if window_ms < 1000:
		return
	var frames: int = _hb_frames
	var avg_frame_ms: float = 0.0
	var fps_est: float = 0.0
	if frames > 0:
		avg_frame_ms = _hb_sum_frame_ms / float(frames)
		fps_est = (float(frames) * 1000.0) / float(window_ms)
	var avg_process_ms: float = 0.0
	if frames > 0:
		avg_process_ms = _hb_sum_process_ms / float(frames)
	var phys_ticks: int = _hb_phys
	var avg_phys_ms: float = 0.0
	if phys_ticks > 0:
		avg_phys_ms = _hb_sum_phys_ms / float(phys_ticks)
	if _should_emit_live_pvp_heartbeat_logs():
		SFLog.info("ARENA_FRAME_HEARTBEAT", {
			"frames": frames,
			"fps": snapped(fps_est, 0.1),
			"max_frame_ms": snapped(_hb_max_frame_ms, 0.1),
			"avg_frame_ms": snapped(avg_frame_ms, 0.1),
			"max_process_ms": snapped(_hb_max_process_ms, 0.1),
			"avg_process_ms": snapped(avg_process_ms, 0.1),
			"max_engine_process_ms": snapped(_hb_max_engine_process_ms, 0.1),
			"physics_ticks": phys_ticks,
			"max_physics_ms": snapped(_hb_max_phys_ms, 0.1),
			"avg_physics_ms": snapped(avg_phys_ms, 0.1)
		})
	_publish_frame_runtime_telemetry(frames, fps_est, avg_frame_ms, avg_process_ms, phys_ticks, avg_phys_ms, window_ms)
	_hb_last_ms = now_ms
	_hb_frames = 0
	_hb_max_frame_ms = 0.0
	_hb_sum_frame_ms = 0.0
	_hb_max_process_ms = 0.0
	_hb_sum_process_ms = 0.0
	_hb_max_engine_process_ms = 0.0
	_hb_phys = 0
	_hb_max_phys_ms = 0.0
	_hb_sum_phys_ms = 0.0

func _should_emit_live_pvp_heartbeat_logs() -> bool:
	return not _is_pvp_runtime_active() or SFLog.LOGGING_ENABLED

func _publish_frame_runtime_telemetry(
	frames: int,
	fps_est: float,
	avg_frame_ms: float,
	avg_process_ms: float,
	phys_ticks: int,
	avg_phys_ms: float,
	window_ms: int
) -> void:
	if OpsState == null or not OpsState.has_method("update_runtime_telemetry"):
		return
	var phys_fps: float = 0.0
	if window_ms > 0:
		phys_fps = (float(phys_ticks) * 1000.0) / float(window_ms)
	var patch: Dictionary = {
		"local_fps": snappedf(fps_est, 0.1),
		"local_frame_ms_avg": snappedf(avg_frame_ms, 0.1),
		"local_frame_ms_max": snappedf(_hb_max_frame_ms, 0.1),
		"local_process_ms_avg": snappedf(avg_process_ms, 0.1),
		"local_process_ms_max": snappedf(_hb_max_process_ms, 0.1),
		"local_physics_fps": snappedf(phys_fps, 0.1),
		"local_physics_fixed_hz": float(Engine.physics_ticks_per_second),
		"local_physics_ms_avg": snappedf(avg_phys_ms, 0.1),
		"local_physics_ms_max": snappedf(_hb_max_phys_ms, 0.1),
		"local_frame_count_window": frames
	}
	var pool_patch: Dictionary = _pool_runtime_telemetry_snapshot()
	for key_any in pool_patch.keys():
		patch[key_any] = pool_patch.get(key_any)
	var authority_counts: Dictionary = _authoritative_runtime_counts_snapshot()
	for key_any in authority_counts.keys():
		patch[key_any] = authority_counts.get(key_any)
	OpsState.call("update_runtime_telemetry", patch)

func _authoritative_runtime_counts_snapshot() -> Dictionary:
	var st: GameState = state
	if st == null and OpsState != null and OpsState.has_method("get_state"):
		st = OpsState.call("get_state") as GameState
	if st == null:
		return {
			"active_unit_count": 0,
			"active_lane_count": 0,
			"active_send_lane_count": 0,
			"active_swarm_count": 0,
			"units_by_owner": {},
			"units_by_lane_count": {}
		}
	var active_lane_count: int = 0
	var active_send_lane_count: int = 0
	for lane_any in st.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		active_lane_count += 1
		if bool(lane.send_a) or bool(lane.send_b):
			active_send_lane_count += 1
	var units_any: Variant = []
	var unit_system_obj: Object = st.unit_system
	if unit_system_obj != null:
		units_any = unit_system_obj.get("units")
	elif st.units_by_lane.has("_all"):
		units_any = st.units_by_lane.get("_all")
	var active_unit_count: int = 0
	var units_by_owner: Dictionary = {}
	var units_by_lane_count: Dictionary = {}
	if typeof(units_any) == TYPE_ARRAY:
		for unit_any in units_any as Array:
			if typeof(unit_any) != TYPE_DICTIONARY:
				continue
			var unit: Dictionary = unit_any as Dictionary
			active_unit_count += 1
			var owner_key: String = str(int(unit.get("owner_id", 0)))
			units_by_owner[owner_key] = int(units_by_owner.get(owner_key, 0)) + 1
			var lane_key: String = str(int(unit.get("lane_id", -1)))
			units_by_lane_count[lane_key] = int(units_by_lane_count.get(lane_key, 0)) + 1
	return {
		"active_unit_count": active_unit_count,
		"active_lane_count": active_lane_count,
		"active_send_lane_count": active_send_lane_count,
		"active_swarm_count": st.swarm_packets.size(),
		"units_by_owner": units_by_owner,
		"units_by_lane_count": units_by_lane_count
	}

func _runtime_telemetry_overlay_enabled() -> bool:
	if not show_runtime_telemetry_overlay:
		return false
	if OS.is_debug_build() or get_node_or_null("/root/DevMapRunner") != null:
		return true
	return OS.get_environment("SF_RUNTIME_TELEMETRY_OVERLAY").strip_edges() == "1"

func _ensure_runtime_telemetry_overlay() -> void:
	if not _runtime_telemetry_overlay_enabled():
		if _runtime_telemetry_overlay != null and is_instance_valid(_runtime_telemetry_overlay):
			_runtime_telemetry_overlay.visible = false
		return
	if _runtime_telemetry_overlay != null and is_instance_valid(_runtime_telemetry_overlay):
		_runtime_telemetry_overlay.visible = true
		return
	var parent: Control = _resolve_hud_root()
	if parent == null:
		return
	var panel := PanelContainer.new()
	panel.name = "RuntimeTelemetryOverlay"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(390, 0)
	panel.z_index = 1000
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.64)
	style.border_color = Color(1.0, 1.0, 1.0, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var label := Label.new()
	label.name = "Metrics"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	margin.add_child(label)
	_runtime_telemetry_overlay = panel
	_runtime_telemetry_label = label
	_position_runtime_telemetry_overlay()
	_update_runtime_telemetry_overlay(true)

func _position_runtime_telemetry_overlay() -> void:
	if _runtime_telemetry_overlay == null or not is_instance_valid(_runtime_telemetry_overlay):
		return
	var top_px: float = _ui_top_inset_px()
	_runtime_telemetry_overlay.position = Vector2(12.0, top_px + 12.0)

func _ensure_pvp_debug_overlay() -> void:
	if _pvp_debug_overlay != null and is_instance_valid(_pvp_debug_overlay):
		return
	var parent: Node = _resolve_pvp_debug_overlay_parent()
	if parent == null:
		return
	var existing: Control = parent.get_node_or_null("PvpDebugOverlay") as Control
	if existing != null:
		_pvp_debug_overlay = existing
		return
	var overlay_any: Variant = PvpDebugOverlayScript.new()
	if not (overlay_any is Control):
		return
	var overlay: Control = overlay_any as Control
	overlay.name = "PvpDebugOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.z_as_relative = false
	overlay.z_index = 4095
	parent.add_child(overlay)
	_pvp_debug_overlay = overlay

func _resolve_pvp_debug_overlay_parent() -> Node:
	var hud_root: Control = _resolve_hud_root()
	if hud_root != null:
		return hud_root
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var current_scene: Node = tree.current_scene
	if current_scene != null:
		var scene_hud: CanvasLayer = current_scene.get_node_or_null("HUDCanvasLayer") as CanvasLayer
		if scene_hud != null:
			return scene_hud
		var scene_ui: CanvasLayer = current_scene.get_node_or_null("UI") as CanvasLayer
		if scene_ui != null:
			return scene_ui
	var root: Window = tree.root
	if root == null:
		return null
	var root_hud: CanvasLayer = root.get_node_or_null("HUDCanvasLayer") as CanvasLayer
	if root_hud != null:
		return root_hud
	return null

func _update_runtime_telemetry_overlay(force: bool = false) -> void:
	if not _runtime_telemetry_overlay_enabled():
		return
	if _runtime_telemetry_overlay == null or not is_instance_valid(_runtime_telemetry_overlay) or _runtime_telemetry_label == null:
		_ensure_runtime_telemetry_overlay()
		return
	var now_ms: int = Time.get_ticks_msec()
	if not force and now_ms - _runtime_telemetry_last_update_ms < 250:
		return
	_runtime_telemetry_last_update_ms = now_ms
	_position_runtime_telemetry_overlay()
	var snapshot: Dictionary = OpsState.call("get_runtime_telemetry_snapshot") if OpsState != null and OpsState.has_method("get_runtime_telemetry_snapshot") else {}
	_runtime_telemetry_label.text = _runtime_telemetry_text(snapshot)
	_runtime_telemetry_overlay.visible = true

func _runtime_telemetry_text(snapshot: Dictionary) -> String:
	var waiting: bool = bool(snapshot.get("waiting_for_remote", false))
	var wait_reason: String = str(snapshot.get("waiting_for_remote_reason", ""))
	if wait_reason.is_empty():
		wait_reason = "none"
	var contract_reason: String = str(snapshot.get("contract_last_violation_reason", ""))
	if contract_reason.is_empty():
		contract_reason = "none"
	return "\n".join([
		"RUNTIME TELEMETRY",
		"FPS %.1f | frame %.1f/%.1f ms" % [
			float(snapshot.get("local_fps", 0.0)),
			float(snapshot.get("local_frame_ms_avg", 0.0)),
			float(snapshot.get("local_frame_ms_max", 0.0))
		],
		"Physics %.1f fps | fixed %.1f Hz" % [
			float(snapshot.get("local_physics_fps", 0.0)),
			float(snapshot.get("local_physics_fixed_hz", 0.0))
		],
		"Sim %s %.1f/%.1f Hz | %.2f/%.2f ms | scale %.3f" % [
			"RUN" if bool(snapshot.get("sim_running", false)) else "STOP",
			float(snapshot.get("local_sim_tick_rate_hz", 0.0)),
			float(snapshot.get("local_sim_fixed_hz", 0.0)),
			float(snapshot.get("sim_ms", 0.0)),
			float(snapshot.get("sim_ms_max", snapshot.get("sim_ms", 0.0))),
			float(snapshot.get("sim_time_scale", 1.0))
		],
		"Accum sim delta %.1f ms" % float(snapshot.get("accumulated_sim_delta_ms", 0.0)),
		"Units %d | lanes %d/%d | swarms %d" % [
			int(snapshot.get("active_unit_count", 0)),
			int(snapshot.get("active_send_lane_count", 0)),
			int(snapshot.get("active_lane_count", 0)),
			int(snapshot.get("active_swarm_count", 0))
		],
		"Server tick %.1f Hz | frame %.1f ms" % [
			float(snapshot.get("server_tick_rate_hz", 0.0)),
			float(snapshot.get("server_frametime_ms", 0.0))
		],
		"Snapshots %.1f/s | RTT %.1f ms" % [
			float(snapshot.get("snapshot_receive_rate_hz", 0.0)),
			float(snapshot.get("ping_rtt_ema_ms", snapshot.get("ping_rtt_ms", 0.0)))
		],
		"Packets tx %d | rx %d | drop %d" % [
			int(snapshot.get("packet_tx", 0)),
			int(snapshot.get("packet_rx", 0)),
			int(snapshot.get("packet_dropped", 0))
		],
		"Publish %s q%d | telemetry write %.1f/%.1f ms" % [
			"IN-FLIGHT" if bool(snapshot.get("publish_in_flight", false)) else "idle",
			int(snapshot.get("publish_queue_size", 0)),
			float(snapshot.get("telemetry_write_ms", 0.0)),
			float(snapshot.get("telemetry_write_ms_max", 0.0))
		],
		"Contract lead %d | min %d | pending %d" % [
			int(snapshot.get("contract_command_lead_ticks", -1)),
			int(snapshot.get("contract_min_command_lead_ticks", -1)),
			int(snapshot.get("contract_pending_commands", 0))
		],
		"Contract missed %d | hash %d | violations %d (%s)" % [
			int(snapshot.get("contract_missed_scheduled_commands", 0)),
			int(snapshot.get("contract_state_hash_mismatches", 0)),
			int(snapshot.get("contract_violation_count", 0)),
			contract_reason
		],
		"Waiting remote: %s (%s)" % ["YES" if waiting else "NO", wait_reason]
	])

func _update_power_bar(delta: float) -> void:
	# UI observes OpsState; no sim-driven UI mutations.
	return

func _maybe_log_frame_hitch(delta: float) -> void:
	if not DBG_HITCH:
		return
	var dt_ms: float = delta * 1000.0
	if SFLog.LOGGING_ENABLED and dt_ms > HITCH_MS:
		print("HITCH dt_ms=", snappedf(dt_ms, 0.1))

func dbg_mark_event(label: String) -> void:
	_dbg_last_event = label
	_dbg_last_event_ms = Time.get_ticks_msec()
	SFLog.mark_event(label)

func _snap_power_bar_to_map_top(reason: String = "") -> void:
	if power_bar == null or not is_instance_valid(power_bar):
		power_bar = _resolve_power_bar_node()
	if power_bar == null or not power_bar.is_inside_tree():
		return
	var anchor: Control = power_bar.get_parent() as Control
	if anchor == null or not anchor.is_inside_tree():
		return
	var arena_top_y: float = _arena_playfield_top_screen_y()
	if not is_finite(arena_top_y):
		return
	var target_top_y: float = arena_top_y + POWER_BAR_ARENA_TOP_GAP_PX
	var power_rect: Rect2 = power_bar.get_global_rect()
	var delta_y: float = target_top_y - power_rect.position.y
	if absf(delta_y) <= 0.5:
		return
	anchor.offset_top += delta_y
	anchor.offset_bottom += delta_y
	_layout_capture_flag_move_button()
	SFLog.throttled_info("POWER_BAR_ARENA_TOP_SNAP", {
		"reason": reason,
		"arena_top_y": arena_top_y,
		"target_top_y": target_top_y,
		"delta_y": delta_y
	}, 1000)

func _arena_playfield_top_screen_y() -> float:
	var playfield_rect: Rect2 = _resolve_playfield_rect_px()
	if playfield_rect.size.y > 1.0:
		return playfield_rect.position.y
	var bounds_world: Rect2 = _resolve_camera_fit_bounds_world()
	if bounds_world.size.x <= 1.0 or bounds_world.size.y <= 1.0:
		bounds_world = _arena_rect()
	if bounds_world.size.x <= 1.0 or bounds_world.size.y <= 1.0:
		return INF
	var vp: Viewport = get_viewport()
	if vp == null:
		return INF
	var canvas_xform: Transform2D = vp.get_canvas_transform()
	var top_left: Vector2 = canvas_xform * bounds_world.position
	var top_right: Vector2 = canvas_xform * (bounds_world.position + Vector2(bounds_world.size.x, 0.0))
	var top_y: float = minf(top_left.y, top_right.y)
	var tree: SceneTree = get_tree()
	var world_container: Control = _world_viewport_cache.resolve_container(tree) if _world_viewport_cache != null else null
	if world_container != null and world_container.is_inside_tree():
		top_y += world_container.get_global_rect().position.y
	return top_y

func _sync_inputs_locked_from_state() -> void:
	if input_system == null:
		return
	var should_lock: bool = bool(OpsState.input_locked)
	var actual_lock: bool = bool(input_system.get("inputs_locked"))
	if should_lock == _inputs_locked_from_state and actual_lock == should_lock:
		return
	_inputs_locked_from_state = should_lock
	var reason: String = OpsState.input_locked_reason if should_lock else ""
	input_system.set_inputs_locked(should_lock, reason)

func dbg(msg: String) -> void:
	if debug_system != null:
		debug_system.dbg(msg)
		return
	var t_sec := float(Time.get_ticks_msec()) / 1000.0
	SFLog.debug("%8.3f | %s" % [t_sec, msg])

func _note_render_dirty() -> void:
	_tick_render_dirty = true
	_render_dirty = true

func mark_render_dirty(reason: String = "") -> void:
	render_version += 1
	_render_dirty = true
	if RENDER_DEBUG:
		if reason == "":
			SFLog.debug("RENDER: dirty v=%d" % [render_version])
		else:
			SFLog.debug("RENDER: dirty %s v=%d" % [reason, render_version])
	if draw_arena_rect_debug:
		queue_redraw()

func _debug_camera(tag: String) -> void:
	if debug_system == null:
		return
	var v := get_viewport()
	if v == null:
		return
	var active := v.get_camera_2d()
	var ours: Camera2D = camera if camera != null else $Camera2D
	if ours == null:
		return
	debug_system.debug_camera(
		tag,
		active,
		ours,
		v.get_visible_rect().size,
		ours.global_position,
		ours.zoom
	)

func _update_win_overlay() -> void:
	if win_overlay == null:
		_ensure_post_match_ui()
	if win_overlay == null:
		return
	if OpsState.match_over:
		var end_ms := int(OpsState.match_end_ms)
		if end_ms <= 0:
			end_ms = Time.get_ticks_msec()
		if end_ms != _win_overlay_match_end_ms:
			_win_overlay_match_end_ms = end_ms
			_win_overlay_until_ms = end_ms + WIN_OVERLAY_MS
			win_overlay.show_win(int(OpsState.winner_id), str(OpsState.end_reason))
			SFLog.info("OVERLAY_SHOWN", {
				"type": "win_banner",
				"winner_id": int(OpsState.winner_id),
				"reason": str(OpsState.end_reason)
			})
		if _win_overlay_until_ms > 0 and Time.get_ticks_msec() >= _win_overlay_until_ms:
			win_overlay.hide_overlay()
		return
	if _win_overlay_match_end_ms != 0:
		_win_overlay_match_end_ms = 0
		_win_overlay_until_ms = 0
	if win_overlay.visible:
		win_overlay.hide_overlay()

func cam_set(tag: String, pos: Vector2, zoom: Vector2) -> void:
	var cam := $Camera2D
	cam.make_current()
	cam.global_position = pos
	SFLog.trace("CAM_SET", {"tag": tag, "pos": pos, "zoom": zoom})

func _debug_scan_cameras() -> void:
	await get_tree().process_frame
	var cams: Array = []
	_scan_cameras(get_tree().root, cams)
	SFLog.trace("CAMERA2D COUNT", {"count": cams.size()})
	for c in cams:
		SFLog.trace(" - ", {"path": _node_path_for_log(c), "current": c.is_current(), "enabled": c.enabled})

func _scan_cameras(node: Node, out: Array) -> void:
	if node is Camera2D:
		out.append(node)
	for ch in node.get_children():
		_scan_cameras(ch, out)

func _dump_map_like_nodes(tag: String) -> void:
	SFLog.trace("\n=== DUMP ===", {"tag": tag})
	if DBG_TREE_DUMP:
		print_tree_pretty()
	var suspects: Array[Node] = []
	_scan(get_tree().current_scene, suspects)
	for n in suspects:
		SFLog.trace("SUSPECT", {
			"path": _node_path_for_log(n),
			"type": n.get_class(),
			"parent": _node_path_for_log(n.get_parent())
		})

func _dump_map_renderers(tag: String) -> void:
	SFLog.trace("\n=== RENDERER DUMP ===", {"tag": tag})
	var root := get_tree().root
	var arenas := root.find_children("Arena", "Node", true, false)
	SFLog.trace("Arenas", {"count": arenas.size()})
	for a in arenas:
		SFLog.trace(" - ", {"path": _node_path_for_log(a)})
	var map_roots := root.find_children("MapRoot", "Node", true, false)
	SFLog.trace("MapRoots", {"count": map_roots.size()})
	for m in map_roots:
		SFLog.trace(" - ", {"path": _node_path_for_log(m)})
	var hrs := root.find_children("HiveRenderer", "Node", true, false)
	SFLog.trace("HiveRenderers", {"count": hrs.size()})
	for h in hrs:
		SFLog.trace(" - ", {
			"path": _node_path_for_log(h),
			"vis": (h.visible if h is CanvasItem else "n/a"),
			"children": h.get_child_count()
		})
	var lrs := root.find_children("LaneRenderer", "Node", true, false)
	SFLog.trace("LaneRenderers", {"count": lrs.size()})
	for l in lrs:
		SFLog.trace(" - ", {
			"path": _node_path_for_log(l),
			"vis": (l.visible if l is CanvasItem else "n/a"),
			"children": l.get_child_count()
		})

func _dump_tree_with_scripts(path: String) -> void:
	var root := get_node_or_null(path)
	if root == null:
		SFLog.trace("DUMP: node not found", {"path": path})
		return
	SFLog.trace("\n=== TREE DUMP ===", {"path": _node_path_for_log(root)})
	_dump_node(root, 0)

func _dump_node(n: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var s := ""
	if n.get_script() != null:
		s = " script=" + str(n.get_script().resource_path)
	SFLog.trace(indent + "- ", {"path": _node_path_for_log(n), "type": n.get_class(), "script": s})
	for c in n.get_children():
		_dump_node(c, depth + 1)

func _list_canvasitems_with_scripts(path: String) -> void:
	var root := get_node_or_null(path)
	if root == null:
		SFLog.trace("SCAN: node not found", {"path": path})
		return
	SFLog.trace("\n=== CANVASITEM SCAN ===", {"path": _node_path_for_log(root)})
	var items := root.find_children("", "CanvasItem", true, false)
	for it in items:
		var ci := it as CanvasItem
		var sp := ""
		if it.get_script() != null:
			sp = str(it.get_script().resource_path)
		if sp != "":
			SFLog.trace(" - ", {"path": _node_path_for_log(it), "type": it.get_class(), "vis": ci.visible, "script": sp})

func _dump_viewports_and_textures() -> void:
	SFLog.trace("\n=== VIEWPORT/TEXTURE DUMP ===")
	var root := get_tree().root
	var svcs := root.find_children("", "SubViewportContainer", true, false)
	SFLog.trace("SubViewportContainers", {"count": svcs.size()})
	for c in svcs:
		SFLog.trace(" - ", {"path": _node_path_for_log(c)})
	var svs := root.find_children("", "SubViewport", true, false)
	SFLog.trace("SubViewports", {"count": svs.size()})
	for v in svs:
		SFLog.trace(" - ", {
			"path": _node_path_for_log(v),
			"update": v.render_target_update_mode,
			"clear": v.render_target_clear_mode
		})
	var trs := root.find_children("", "TextureRect", true, false)
	SFLog.trace("TextureRects", {"count": trs.size()})
	for t in trs:
		var tex: Texture2D = t.texture
		SFLog.trace(" - ", {"path": _node_path_for_log(t), "tex": (tex.resource_path if tex else "null")})

func _kill_foreign_renderers(keep_arena: Node) -> void:
	if keep_arena == null or not keep_arena.is_inside_tree():
		return
	var keep_prefix := str(keep_arena.get_path())
	for n in get_tree().root.find_children("HiveRenderer", "Node", true, false):
		if n == null or not n.is_inside_tree():
			continue
		var p := str(n.get_path())
		if not p.begins_with(keep_prefix):
			SFLog.trace("KILL HiveRenderer", {"path": p})
			if n is CanvasItem:
				n.visible = false
			n.queue_free()
	for n in get_tree().root.find_children("LaneRenderer", "Node", true, false):
		if n == null or not n.is_inside_tree():
			continue
		var p := str(n.get_path())
		if not p.begins_with(keep_prefix):
			SFLog.trace("KILL LaneRenderer", {"path": p})
			if n is CanvasItem:
				n.visible = false
			n.queue_free()

func _debug_scan_names() -> void:
	var out: Array[Node] = []
	var root := get_tree().root
	_scan(root, out)
	for n in out:
		SFLog.trace("FOUND", {"path": _node_path_for_log(n), "type": n.get_class()})

func _scan(n: Node, out: Array[Node]) -> void:
	if n == null:
		return
	var cname := n.get_class()
	if cname.find("Hive") != -1 or cname.find("Lane") != -1 or str(n.name).find("Hive") != -1 or str(n.name).find("Lane") != -1:
		out.append(n)
	for c in n.get_children():
		var child: Node = c as Node
		if child != null:
			_scan(child, out)

func clear_map() -> void:
	var hr := $MapRoot/HiveRenderer
	var lr := $MapRoot/LaneRenderer
	for c in hr.get_children():
		c.queue_free()
	for c in lr.get_children():
		c.queue_free()
	SFLog.trace("MAP CLEAR", {"hive": hr.get_child_count(), "lane": lr.get_child_count()})

func clear_map_render() -> void:
	var hr := $MapRoot/HiveRenderer
	var lr := $MapRoot/LaneRenderer
	var ur: Node2D = unit_renderer
	if ur == null:
		ur = _resolve_unit_renderer()
		unit_renderer = ur
	for c in hr.get_children():
		c.queue_free()
	for c in lr.get_children():
		c.queue_free()
	if hr.has_method("clear_all"):
		hr.call("clear_all")
	if lr.has_method("clear_all"):
		lr.call("clear_all")
	if ur != null and ur.has_method("clear_all"):
		ur.call("clear_all")
	SFLog.trace("CLEAR_MAP_RENDER", {
		"hr": hr.get_child_count(),
		"lr": lr.get_child_count(),
		"ur": ur.get_child_count() if ur != null else -1
	})

func set_model(m: Dictionary) -> void:
	model = m
	if floor_influence_system == null:
		_ensure_floor_influence_system()
	if floor_influence_system != null and floor_renderer != null:
		floor_influence_system.configure_floor_bounds(floor_renderer.get_floor_bounds_rect())

func world_center() -> Vector2:
	return _canon_world_px() * 0.5

func _canon_world_px() -> Vector2:
	return Vector2(GRID_W * CELL_SIZE, GRID_H * CELL_SIZE)

func _compute_fit_zoom(viewport_size: Vector2, margin: float) -> float:
	var world_px: Vector2 = _canon_world_px()
	if grid_spec != null:
		world_px = Vector2(
			grid_spec.grid_w * grid_spec.cell_size,
			grid_spec.grid_h * grid_spec.cell_size
		)
	if world_px.x <= 0.0 or world_px.y <= 0.0:
		return 1.0
	var pad: float = maxf(0.0, cam_fit_pad_px)
	var effective_vp: Vector2 = viewport_size - Vector2(pad * 2.0, pad * 2.0)
	effective_vp.x = maxf(1.0, effective_vp.x)
	effective_vp.y = maxf(1.0, effective_vp.y)
	var sx: float = effective_vp.x / world_px.x
	var sy: float = effective_vp.y / world_px.y
	var fit: float = min(sx, sy)
	return fit * clampf(margin, 0.5, 2.0)

func _compute_fit_zoom_for_mode(viewport_size: Vector2, margin: float, fit_mode: int, world_bounds: Rect2 = Rect2()) -> float:
	var world_px: Vector2 = world_bounds.size
	if world_px.x <= 0.0 or world_px.y <= 0.0:
		world_px = _canon_world_px()
	if (world_px.x <= 0.0 or world_px.y <= 0.0) and grid_spec != null:
		world_px = Vector2(
			grid_spec.grid_w * grid_spec.cell_size,
			grid_spec.grid_h * grid_spec.cell_size
		)
	if world_px.x <= 0.0 or world_px.y <= 0.0:
		return 1.0
	var pad: float = maxf(0.0, cam_fit_pad_px)
	var effective_vp: Vector2 = viewport_size - Vector2(pad * 2.0, pad * 2.0)
	effective_vp.x = maxf(1.0, effective_vp.x)
	effective_vp.y = maxf(1.0, effective_vp.y)
	var sx: float = effective_vp.x / world_px.x
	var sy: float = effective_vp.y / world_px.y
	var base: float = min(sx, sy)
	match fit_mode:
		FIT_WIDTH:
			base = sx
		FIT_HEIGHT:
			base = sy
		_:
			base = min(sx, sy)
	return base * clampf(margin, 0.5, 2.0)

func _visible_camera_viewport_size(camera_node: Camera2D) -> Vector2:
	if camera_node == null:
		return Vector2.ZERO
	if _camera_fit_viewport_override_px.x > 1.0 and _camera_fit_viewport_override_px.y > 1.0:
		return _camera_fit_viewport_override_px
	var out: Vector2 = Vector2.ZERO
	var vp: Viewport = camera_node.get_viewport()
	if vp != null:
		out = vp.get_visible_rect().size
	var tree: SceneTree = get_tree()
	var world_container: Control = _world_viewport_cache.resolve_container(tree) if _world_viewport_cache != null else null
	if world_container != null and world_container.size.x > 0.0 and world_container.size.y > 0.0:
		out = world_container.size
	return out

func _bounds_from_positions_world(node_positions: Array[Vector2]) -> Rect2:
	if node_positions.is_empty():
		return Rect2()
	var minv: Vector2 = node_positions[0]
	var maxv: Vector2 = node_positions[0]
	for p in node_positions:
		minv.x = minf(minv.x, p.x)
		minv.y = minf(minv.y, p.y)
		maxv.x = maxf(maxv.x, p.x)
		maxv.y = maxf(maxv.y, p.y)
	return Rect2(minv, maxv - minv)

# mode: FIT_HEIGHT (fill top/bottom playable strip exactly, no geometric stretch)
func cam_fit_height_to_bounds(
	camera_node: Camera2D,
	bounds_world: Rect2,
	top_px: float,
	bottom_px: float,
	pad_world: float = 0.0,
	bias_x_px: float = 0.0,
	bias_y_px: float = 0.0
) -> Dictionary:
	if camera_node == null:
		return {"ok": false, "reason": "camera_null"}
	var bw: float = maxf(1.0, bounds_world.size.x)
	var bh: float = maxf(1.0, bounds_world.size.y)
	var padded_bounds: Rect2 = bounds_world.grow(maxf(0.0, pad_world))
	bw = maxf(1.0, padded_bounds.size.x)
	bh = maxf(1.0, padded_bounds.size.y)
	var vp: Vector2 = _visible_camera_viewport_size(camera_node)
	if vp.x <= 0.0 or vp.y <= 0.0:
		return {"ok": false, "reason": "viewport_invalid", "vp": vp}
	var usable_h: float = maxf(1.0, vp.y - top_px - bottom_px)
	# Godot Camera2D zoom: larger zoom shows less world (zooms in).
	# To fit world height into usable screen height we scale by usable/world.
	var z: float = usable_h / bh
	# Guard against horizontal clipping: in FIT_HEIGHT, never zoom in beyond full-width fit.
	var z_width_max: float = vp.x / bw
	if z > z_width_max:
		z = z_width_max
	z = clampf(z, 0.02, 50.0)
	var y_scale: float = 1.0 if cam_fit_lock_map_edges_to_container else clampf(cam_fit_height_y_scale, 0.75, 1.25)
	var z_y: float = clampf(z * y_scale, 0.02, 50.0)
	var center: Vector2 = padded_bounds.position + padded_bounds.size * 0.5
	if z_y > 0.0:
		# Keep world centered in the remaining playable strip when top/bottom reserves differ.
		center.y -= ((top_px - bottom_px) * 0.5) / z_y
	if z_y > 0.0:
		center.y += bias_y_px / z_y
	camera_node.make_current()
	camera_node.zoom = Vector2(z, z_y)
	camera_node.global_position = center
	camera_node.force_update_scroll()
	return {
		"ok": true,
		"center": center,
		"zoom": Vector2(z, z_y),
		"z": z,
		"z_y": z_y,
		"y_scale": y_scale,
		"bounds": padded_bounds,
		"usable_h": usable_h,
		"vp": vp
	}

func _resolved_cam_fit_bias_x_px(grid_w_local: int) -> float:
	if current_map_data.has("cam_fit_bias_x_px"):
		return float(current_map_data.get("cam_fit_bias_x_px", cam_fit_bias_x_px))
	if grid_w_local >= maxi(1, cam_fit_wide_map_min_grid_w):
		return cam_fit_bias_x_px_wide_map
	return cam_fit_bias_x_px

func _collect_fit_node_positions_world_from_render_tree() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var renderer_paths: Array[String] = [
		"MapRoot/HiveRenderer",
		"MapRoot/TowerRenderer",
		"MapRoot/BarracksRenderer"
	]
	for path in renderer_paths:
		var renderer_node: Node = get_node_or_null(path)
		if renderer_node == null:
			continue
		for child_any in renderer_node.get_children():
			if not (child_any is Node2D):
				continue
			var n2: Node2D = child_any as Node2D
			if n2 == null:
				continue
			if n2.name == "SelectionRing":
				continue
			if n2 is CanvasItem and not (n2 as CanvasItem).visible:
				continue
			out.append(n2.global_position)
	return out

func _collect_fit_node_positions_world() -> Array[Vector2]:
	var rendered_positions: Array[Vector2] = _collect_fit_node_positions_world_from_render_tree()
	if not rendered_positions.is_empty():
		return rendered_positions
	var out: Array[Vector2] = []
	if state != null and state.hives != null:
		for hive_any in state.hives:
			if hive_any is HiveData:
				var hive: HiveData = hive_any as HiveData
				var render_gp: Vector2 = hive.render_grid_pos
				if not is_finite(render_gp.x) or not is_finite(render_gp.y):
					render_gp = Vector2(float(hive.grid_pos.x), float(hive.grid_pos.y))
				out.append(_grid_coord_to_world(render_gp))
	if towers != null:
		for tower_any in towers:
			if typeof(tower_any) != TYPE_DICTIONARY:
				continue
			var td: Dictionary = tower_any as Dictionary
			var gp_t: Variant = td.get("grid_pos", null)
			if gp_t is Vector2i:
				out.append(_cell_center(gp_t as Vector2i))
			elif gp_t is Array:
				var arr_t: Array = gp_t as Array
				if arr_t.size() >= 2:
					out.append(_cell_center(Vector2i(int(arr_t[0]), int(arr_t[1]))))
	if barracks != null:
		for barracks_any in barracks:
			if typeof(barracks_any) != TYPE_DICTIONARY:
				continue
			var bd: Dictionary = barracks_any as Dictionary
			var gp_b: Variant = bd.get("grid_pos", null)
			if gp_b is Vector2i:
				out.append(_cell_center(gp_b as Vector2i))
			elif gp_b is Array:
				var arr_b: Array = gp_b as Array
				if arr_b.size() >= 2:
					out.append(_cell_center(Vector2i(int(arr_b[0]), int(arr_b[1]))))
	return out

func _compute_nodes_fit(
	node_positions: Array[Vector2],
	viewport_size: Vector2,
	reserved_top_px: float,
	reserved_bottom_px: float
) -> Dictionary:
	if node_positions.is_empty():
		return {"ok": false}
	var minv: Vector2 = node_positions[0]
	var maxv: Vector2 = node_positions[0]
	for p in node_positions:
		minv.x = minf(minv.x, p.x)
		minv.y = minf(minv.y, p.y)
		maxv.x = maxf(maxv.x, p.x)
		maxv.y = maxf(maxv.y, p.y)
	var node_pad: float = maxf(0.0, cam_fit_node_pad_px)
	minv -= Vector2(node_pad, node_pad)
	maxv += Vector2(node_pad, node_pad)
	var bounds_size: Vector2 = maxv - minv
	bounds_size.x = maxf(bounds_size.x, 1.0)
	bounds_size.y = maxf(bounds_size.y, 1.0)
	var center: Vector2 = (minv + maxv) * 0.5
	var reserved_top: float = maxf(0.0, reserved_top_px + maxf(0.0, cam_fit_reserved_top_px))
	var reserved_bottom: float = maxf(0.0, reserved_bottom_px + maxf(0.0, cam_fit_reserved_bottom_px))
	var usable: Vector2 = Vector2(
		maxf(1.0, viewport_size.x),
		maxf(1.0, viewport_size.y - reserved_top - reserved_bottom)
	)
	var sx: float = bounds_size.x / usable.x
	var sy: float = bounds_size.y / usable.y
	var mode: String = cam_fit_nodes_mode.strip_edges().to_lower()
	var s: float = maxf(sx, sy) if mode == "contain" else minf(sx, sy)
	s = maxf(s, 0.001)
	# When top/bottom reserved space is asymmetric, bias center into the usable area.
	center.y += ((reserved_top - reserved_bottom) * 0.5) / s
	return {
		"ok": true,
		"center": center,
		"zoom_scalar": s,
		"zoom": Vector2(s, s),
		"bounds_size": bounds_size,
		"usable": usable,
		"mode": mode
	}

func _resolve_playfield_rect_px() -> Rect2:
	var tree: SceneTree = get_tree()
	var world_container: Control = _world_viewport_cache.resolve_container(tree) if _world_viewport_cache != null else null
	if world_container != null:
		var container_rect: Rect2 = world_container.get_global_rect()
		if container_rect.size.x > 1.0 and container_rect.size.y > 1.0:
			return container_rect
	var vp: Viewport = get_viewport()
	if vp != null:
		var vp_size: Vector2 = vp.get_visible_rect().size
		if vp_size.x > 1.0 and vp_size.y > 1.0:
			return Rect2(Vector2.ZERO, vp_size)
	return Rect2()

func _resolve_camera_fit_bounds_world() -> Rect2:
	return _resolve_camera_fit_bounds_world_with_source().get("bounds", Rect2()) as Rect2

func _with_side_visual_projection(bounds: Rect2) -> Rect2:
	var side_px: float = maxf(0.0, floor_side_visual_projection_px)
	if side_px <= 0.0 or bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		return bounds
	return Rect2(
		bounds.position - Vector2(side_px, 0.0),
		bounds.size + Vector2(side_px * 2.0, 0.0)
	)

func _resolve_camera_fit_bounds_world_with_source() -> Dictionary:
	if use_node_bounds_camfit:
		var node_positions: Array[Vector2] = _collect_fit_node_positions_world()
		var node_bounds: Rect2 = _bounds_from_positions_world(node_positions)
		if node_bounds.size.x > 1.0 and node_bounds.size.y > 1.0:
			return {"bounds": _with_side_visual_projection(node_bounds), "source": "nodes_visual_side_projection"}
	var map_bounds: Rect2 = _map_world_bounds()
	if map_bounds.size.x > 1.0 and map_bounds.size.y > 1.0:
		return {"bounds": _with_side_visual_projection(map_bounds), "source": "map_visual_side_projection"}
	if floor_renderer != null and floor_renderer.has_method("get_floor_bounds_rect"):
		var floor_bounds_any: Variant = floor_renderer.call("get_floor_bounds_rect")
		if floor_bounds_any is Rect2:
			var floor_bounds: Rect2 = floor_bounds_any as Rect2
			if floor_bounds.size.x > 1.0 and floor_bounds.size.y > 1.0:
				return {"bounds": _with_side_visual_projection(floor_bounds), "source": "floor_visual_side_projection"}
	return {"bounds": _with_side_visual_projection(_arena_rect()), "source": "arena_visual_side_projection"}

func _camera_fit_signature(
	playfield_rect_px: Rect2,
	bounds_world: Rect2,
	top_ui_inset_px: float = 0.0,
	bottom_ui_inset_px: float = 0.0
) -> String:
	return "%.3f,%.3f,%.3f,%.3f|%.3f,%.3f,%.3f,%.3f|%.3f,%.3f|%d,%d,%.3f,%.3f,%.3f,%.3f" % [
		playfield_rect_px.position.x,
		playfield_rect_px.position.y,
		playfield_rect_px.size.x,
		playfield_rect_px.size.y,
		bounds_world.position.x,
		bounds_world.position.y,
		bounds_world.size.x,
		bounds_world.size.y,
		top_ui_inset_px,
		bottom_ui_inset_px,
		cam_fit_mode,
		1 if cam_fit_lock_map_edges_to_container else 0,
		cam_fit_margin,
		cam_fit_pad_px,
		cam_fit_reserved_top_px,
		cam_fit_reserved_bottom_px
	]

func _camera_fit_reason_allowed(reason: String) -> bool:
	match reason:
		"shell_present", "shell_map_apply", "main_map_build", "dev_map_loader_load", "map_builder_node_build", "fitcam_once":
			return true
		_:
			return false

func apply_camera_fit_next_frame(reason: String = "") -> void:
	if not _camera_fit_reason_allowed(reason):
		return
	_allow_camfit_log_tags()
	_camera_fit_request_serial += 1
	SFLog.warn("CAMFIT_DEFER_REQUEST", {
		"reason": reason,
		"request_serial": _camera_fit_request_serial
	})
	call_deferred("_apply_camera_fit_deferred", reason, _camera_fit_request_serial)

func _apply_camera_fit_deferred(reason: String, request_serial: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if request_serial != _camera_fit_request_serial:
		SFLog.warn("CAMFIT_DEFER_DROP", {
			"reason": reason,
			"request_serial": request_serial,
			"latest_serial": _camera_fit_request_serial
		})
		return
	SFLog.warn("CAMFIT_DEFER_APPLY", {
		"reason": reason,
		"request_serial": request_serial
	})
	apply_camera_fit(reason)

func apply_camera_fit(reason: String = "") -> bool:
	if not _camera_fit_reason_allowed(reason):
		return false
	_allow_camfit_log_tags()
	var cam: Camera2D = camera if camera != null else $Camera2D
	if cam == null:
		SFLog.warn("CAMFIT_ABORT", {
			"reason": reason,
			"abort": "camera_null"
		})
		return false
	if state == null or state.hives == null or state.hives.is_empty():
		SFLog.warn("CAMFIT_ABORT", {
			"reason": reason,
			"abort": "state_or_hives_empty",
			"state_null": state == null,
			"hives_null": state == null or state.hives == null,
			"hive_count": 0 if state == null or state.hives == null else state.hives.size()
		})
		return false
	var playfield_rect_px: Rect2 = _resolve_playfield_rect_px()
	var bounds_info: Dictionary = _resolve_camera_fit_bounds_world_with_source()
	var bounds_world: Rect2 = bounds_info.get("bounds", Rect2()) as Rect2
	var bounds_source: String = str(bounds_info.get("source", "unknown"))
	if playfield_rect_px.size.x <= 1.0 or playfield_rect_px.size.y <= 1.0:
		SFLog.warn("CAMFIT_ABORT", {
			"reason": reason,
			"abort": "playfield_rect_invalid",
			"playfield_rect_px": playfield_rect_px
		})
		return false
	if bounds_world.size.x <= 1.0 or bounds_world.size.y <= 1.0:
		SFLog.warn("CAMFIT_ABORT", {
			"reason": reason,
			"abort": "bounds_invalid",
			"bounds_world": bounds_world,
			"bounds_source": bounds_source
		})
		return false
	var ui_insets: Dictionary = _ui_vertical_insets_px()
	var top_ui_inset_px: float = float(ui_insets.get("top", 0.0))
	var bottom_ui_inset_px: float = float(ui_insets.get("bottom", 0.0))
	var sig: String = _camera_fit_signature(playfield_rect_px, bounds_world, top_ui_inset_px, bottom_ui_inset_px)
	if sig == _camera_fit_signature_last:
		if CAMERA_FIT_APPLY_DEBUG:
			SFLog.warn("CAMFIT_APPLY_SKIP", {
				"reason": reason,
				"playfield_rect_px": playfield_rect_px,
				"bounds_world": bounds_world,
				"bounds_source": bounds_source,
				"map_root_pos": map_root.position if map_root != null else Vector2.ZERO,
				"top_ui_inset_px": top_ui_inset_px,
				"bottom_ui_inset_px": bottom_ui_inset_px,
				"camera_pos": cam.global_position,
				"camera_zoom": cam.zoom,
				"signature": sig
			})
		return false
	var before_pos: Vector2 = cam.global_position
	var before_zoom: Vector2 = cam.zoom
	var applied: bool = _fit_camera_to_viewport(reason, bounds_world, playfield_rect_px)
	if not applied:
		SFLog.warn("CAMFIT_ABORT", {
			"reason": reason,
			"abort": "fit_camera_to_viewport_false",
			"bounds_world": bounds_world,
			"bounds_source": bounds_source,
			"playfield_rect_px": playfield_rect_px
		})
		return false
	_camera_fit_signature_last = sig
	_snap_power_bar_to_map_top("camera_fit_%s" % reason)
	if CAMERA_FIT_APPLY_DEBUG:
		SFLog.warn("CAMFIT_APPLY", {
			"reason": reason,
			"playfield_rect_px": playfield_rect_px,
			"bounds_world": bounds_world,
			"bounds_source": bounds_source,
			"map_root_pos": map_root.position if map_root != null else Vector2.ZERO,
			"top_ui_inset_px": top_ui_inset_px,
			"bottom_ui_inset_px": bottom_ui_inset_px,
			"camera_pos": cam.global_position,
			"camera_zoom": cam.zoom,
			"delta_px": cam.global_position.distance_to(before_pos),
			"delta_zoom": (cam.zoom - before_zoom).length(),
			"signature": sig
		})
	return true

func _apply_canon_camera_fit(tag: String) -> void:
	apply_camera_fit(tag)

func _fit_camera_to_viewport(tag: String = "fitcam", forced_bounds_world: Rect2 = Rect2(), forced_playfield_rect_px: Rect2 = Rect2()) -> bool:
	var cam: Camera2D = camera if camera != null else $Camera2D
	if cam == null:
		return false
	var arena_rect: Rect2 = _arena_rect()
	var arena_size: Vector2 = arena_rect.size
	var grid_w_local: int = grid_w
	var grid_h_local: int = grid_h
	var cell_px: float = CELL_SIZE
	if grid_spec != null:
		grid_w_local = grid_spec.grid_w
		grid_h_local = grid_spec.grid_h
		cell_px = grid_spec.cell_size
	var map_bounds: Rect2 = forced_bounds_world
	if map_bounds.size.x <= 1.0 or map_bounds.size.y <= 1.0:
		map_bounds = _resolve_camera_fit_bounds_world_with_source().get("bounds", Rect2()) as Rect2
	var world_px: Vector2 = map_bounds.size if map_bounds.size.x > 1.0 and map_bounds.size.y > 1.0 else Vector2(float(grid_w_local) * cell_px, float(grid_h_local) * cell_px)
	var vp: Viewport = cam.get_viewport()
	if vp == null:
		return false
	var vp_size: Vector2 = vp.get_visible_rect().size
	var cam_vp: Viewport = cam.get_viewport()
	var cam_vp_size: Vector2 = Vector2.ZERO
	if cam_vp != null:
		cam_vp_size = cam_vp.get_visible_rect().size
	var root_vp: Viewport = get_viewport()
	var root_vp_size: Vector2 = Vector2.ZERO
	if root_vp != null:
		root_vp_size = root_vp.get_visible_rect().size
	var tree: SceneTree = get_tree()
	var world_container: Control = _world_viewport_cache.resolve_container(tree) if _world_viewport_cache != null else null
	var visible_vp_size: Vector2 = cam_vp_size
	if forced_playfield_rect_px.size.x > 1.0 and forced_playfield_rect_px.size.y > 1.0:
		visible_vp_size = forced_playfield_rect_px.size
	elif world_container != null:
		var container_size: Vector2 = world_container.size
		if container_size.x > 0.0 and container_size.y > 0.0:
			visible_vp_size = container_size
	if arena_size.x <= 0.0 or arena_size.y <= 0.0:
		return false
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return false
	if visible_vp_size.x <= 0.0 or visible_vp_size.y <= 0.0:
		return false
	var ui_insets: Dictionary = _ui_vertical_insets_px()
	var top_ui_inset_px: float = float(ui_insets.get("top", 0.0))
	var bottom_ui_inset_px: float = float(ui_insets.get("bottom", 0.0))
	var safe_cam_vp_size: Vector2 = visible_vp_size - Vector2(0.0, top_ui_inset_px + bottom_ui_inset_px)
	safe_cam_vp_size.x = maxf(1.0, safe_cam_vp_size.x)
	safe_cam_vp_size.y = maxf(1.0, safe_cam_vp_size.y)
	var fit_top_px: float = top_ui_inset_px
	var fit_bottom_px: float = bottom_ui_inset_px
	var fit_bias_x_px: float = 0.0 if cam_fit_lock_map_edges_to_container else _resolved_cam_fit_bias_x_px(grid_w_local)
	if not cam_fit_lock_map_edges_to_container and cam_fit_reserved_top_px > 0.0:
		fit_top_px = cam_fit_reserved_top_px
	if not cam_fit_lock_map_edges_to_container and cam_fit_reserved_bottom_px > 0.0:
		fit_bottom_px = cam_fit_reserved_bottom_px
	if cam_fit_mode == FIT_HEIGHT:
		_camera_fit_viewport_override_px = visible_vp_size
		var bounds_for_height: Rect2 = map_bounds
		if bounds_for_height.size.x <= 1.0 or bounds_for_height.size.y <= 1.0:
			bounds_for_height = arena_rect
		if use_node_bounds_camfit and not cam_fit_lock_map_edges_to_container:
			var node_positions_h: Array[Vector2] = _collect_fit_node_positions_world()
			var node_bounds: Rect2 = _bounds_from_positions_world(node_positions_h)
			if node_bounds.size.x > 1.0 and node_bounds.size.y > 1.0:
				bounds_for_height = node_bounds
		var fit_bias_y_px: float = 0.0 if cam_fit_lock_map_edges_to_container else cam_fit_bias_y_px
		var fit_height_pad_world: float = 0.0 if cam_fit_lock_map_edges_to_container else maxf(0.0, cam_fit_pad_px) + maxf(0.0, cam_fit_height_world_pad_px)
		var hfit: Dictionary = cam_fit_height_to_bounds(
			cam,
			bounds_for_height,
			fit_top_px,
			fit_bottom_px,
			fit_height_pad_world,
			fit_bias_x_px,
			fit_bias_y_px
		)
		_camera_fit_viewport_override_px = Vector2.ZERO
		if bool(hfit.get("ok", false)):
			var z_h: float = float(hfit.get("z", 1.0))
			var zoom_target_h: Vector2 = hfit.get("zoom", Vector2.ONE) as Vector2
			SFLog.throttle("camfit_applied", 1.0, "CAMFIT applied", SFLog.Level.TRACE)
			call_deferred("_sf_camfit_late_probe", cam, zoom_target_h)
			SFLog.info("CAMFIT", {
				"tag": tag,
				"cam_path": _node_path_for_log(cam),
				"cam_vp_size": cam_vp_size,
				"visible_vp_size": visible_vp_size,
				"safe_cam_vp_size": safe_cam_vp_size,
				"top_ui_inset_px": top_ui_inset_px,
				"bottom_ui_inset_px": bottom_ui_inset_px,
				"fit_top_px": fit_top_px,
				"fit_bottom_px": fit_bottom_px,
				"fit_bias_x_px": fit_bias_x_px,
				"root_vp_size": root_vp_size,
				"arena_size": arena_size,
				"mode": "fit_height_bounds",
				"bounds_size": (hfit.get("bounds", Rect2()) as Rect2).size,
				"usable_h": float(hfit.get("usable_h", 0.0)),
				"z": z_h,
				"cam_zoom_now": cam.zoom
			})
			return true
	var pad: float = maxf(0.0, cam_fit_pad_px)
	var vp_fit: Vector2 = Vector2(
		maxf(1.0, safe_cam_vp_size.x - (pad * 2.0)),
		maxf(1.0, safe_cam_vp_size.y - (pad * 2.0))
	)
	var fit_scalar: float = _compute_fit_zoom_for_mode(safe_cam_vp_size, cam_fit_margin, cam_fit_mode, map_bounds)
	var zoom_scalar: float = fit_scalar
	var fit_strategy: String = "grid"
	var z_min: float = 0.00001
	var z_clamped: bool = false
	var center: Vector2 = Vector2.ZERO
	center = map_bounds.get_center() if map_bounds.size.x > 1.0 and map_bounds.size.y > 1.0 else arena_rect.get_center()
	var node_fit_info: Dictionary = {"ok": false}
	if use_node_bounds_camfit:
		var node_positions: Array[Vector2] = _collect_fit_node_positions_world()
		node_fit_info = _compute_nodes_fit(node_positions, visible_vp_size, top_ui_inset_px, bottom_ui_inset_px)
		if bool(node_fit_info.get("ok", false)):
			fit_strategy = "nodes"
			zoom_scalar = float(node_fit_info.get("zoom_scalar", zoom_scalar))
			center = node_fit_info.get("center", center) as Vector2
	if zoom_scalar <= z_min:
		zoom_scalar = z_min
		z_clamped = true
	var zoom_target: Vector2 = Vector2(zoom_scalar, zoom_scalar)
	if TRACE_ARENA_PRINTS:
		print(
			"CAMFIT_GRID:",
			" tag=",
			tag,
			" vp=",
			cam_vp_size,
			" vp_fit=",
			vp_fit,
			" grid=",
			str(grid_w_local) + "x" + str(grid_h_local),
			" cell=",
			cell_px,
			" world_px=",
			world_px,
			" pad_px=",
			pad,
			" margin=",
				cam_fit_margin
		)
		print(
			"CAMFIT_ZOOM:",
			" fit=",
			fit_scalar,
			" zoom_scalar=",
			zoom_scalar,
			" zoom_target=",
			zoom_target,
			" clamped=",
			z_clamped
		)
	if zoom_scalar > 0.0 and fit_strategy != "nodes":
		# Bias toward the center of the actually visible window between top and bottom overlays.
		center.y -= ((top_ui_inset_px - bottom_ui_inset_px) * 0.5) / zoom_scalar
	cam.make_current()
	cam.global_position = center
	cam.zoom = zoom_target
	if SFLog.LOGGING_ENABLED and abs(cam.zoom.x - zoom_target.x) > 0.0001:
		push_error("CAMFIT: zoom not applied")
	cam.force_update_scroll()
	SFLog.throttle("camfit_applied", 1.0, "CAMFIT applied", SFLog.Level.TRACE)
	if TRACE_ARENA_PRINTS:
		print("CAMFIT_CAM_ID:", " path=", _node_path_for_log(cam), " rid=", cam.get_instance_id(), " current=", cam.is_current())
	call_deferred("_sf_camfit_late_probe", cam, zoom_target)
	if TRACE_ARENA_PRINTS:
		print(
			"CAMFIT_APPLIED:",
			" pos=",
			cam.global_position,
			" zoom=",
			cam.zoom
		)
	SFLog.info("CAMFIT", {
		"tag": tag,
		"cam_path": _node_path_for_log(cam),
		"cam_vp_size": cam_vp_size,
		"visible_vp_size": visible_vp_size,
		"safe_cam_vp_size": safe_cam_vp_size,
		"top_ui_inset_px": top_ui_inset_px,
		"bottom_ui_inset_px": bottom_ui_inset_px,
		"fit_bias_x_px": fit_bias_x_px,
		"root_vp_size": root_vp_size,
		"arena_size": arena_size,
		"mode": fit_strategy,
		"nodes_mode": str(node_fit_info.get("mode", "")),
		"nodes_bounds_size": node_fit_info.get("bounds_size", Vector2.ZERO),
		"nodes_usable_vp_size": node_fit_info.get("usable", Vector2.ZERO),
		"z": zoom_scalar,
		"cam_zoom_now": cam.zoom
	})
	return true

func _sf_camfit_late_probe(cam: Camera2D, expected: Vector2) -> void:
	if cam == null:
		return
	var changed: bool = cam.zoom != expected
	if TRACE_ARENA_PRINTS:
		print("CAMFIT_LATE: expected_zoom=", expected, " actual_zoom=", cam.zoom, " changed=", changed)
	if changed:
		if SFLog.LOGGING_ENABLED:
			push_warning("CAMFIT_LATE: zoom changed cam=%s" % _node_path_for_log(cam))

func _node_path_for_log(node: Node) -> String:
	if node == null:
		return "<null>"
	if not node.is_inside_tree():
		return "<detached:%s>" % str(node.name)
	return str(node.get_path())

func _nearest_canvas_layer(n: Node) -> CanvasLayer:
	var p := n.get_parent()
	while p != null:
		if p is CanvasLayer:
			return p
		p = p.get_parent()
	return null

func _debug_canvas_space() -> void:
	await get_tree().process_frame
	var lr := $MapRoot/LaneRenderer
	var hr := $MapRoot/HiveRenderer
	var lr_cl := _nearest_canvas_layer(lr)
	var hr_cl := _nearest_canvas_layer(hr)
	SFLog.trace("LaneRenderer under CanvasLayer?", {
		"under": lr_cl != null,
		"layer": lr_cl.layer if lr_cl else -999
	})
	SFLog.trace("HiveRenderer under CanvasLayer?", {
		"under": hr_cl != null,
		"layer": hr_cl.layer if hr_cl else -999
	})

func _log_fit_state(tag: String) -> void:
	if debug_system == null:
		return
	var arena_rect: Rect2 = _arena_rect()
	var arena_center: Vector2 = arena_rect.get_center()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var safe_rect := Rect2(Vector2.ZERO, viewport_size)
	var overlays_count := 0
	if use_dev_safe_centering:
		var safe_info: Dictionary = _compute_safe_rect(viewport_size)
		safe_rect = safe_info["safe_rect"]
		overlays_count = safe_info["overlays"].size()
	debug_system.log_fit_state(
		tag,
		self,
		map_root,
		hive_renderer,
		camera,
		arena_rect,
		arena_center,
		viewport_size,
		safe_rect,
		overlays_count,
		map_offset
	)

func _log_lane_establish(lane_key: String, owner_id: int, event: String, t: float = -1.0, extra: String = "") -> void:
	var msg := "LANE_EST_%s lane=%s owner=%d" % [event, lane_key, owner_id]
	if t >= 0.0:
		msg += " t=%.3f" % t
	if extra != "":
		msg += " " + extra
	if event == "ADVANCE":
		SFLog.trace(msg)
	else:
		SFLog.info(msg)

func _tick(dt: float) -> void:
	if not _legacy_tick_fenced_logged:
		_legacy_tick_fenced_logged = true
		SFLog.error("LEGACY_SIM_PATH_BLOCKED", {
			"path": "Arena._tick",
			"active_pipeline": "SimRunner"
		})
	assert(false, "Arena._tick is fenced. SimRunner is authoritative.")
	return
	events.clear()
	_tick_render_dirty = false
	sim_time_us += int(round(dt * 1000000.0))
	_update_hive_shock(dt)
	_update_lanes(dt)
	_update_lane_sim(dt)
	_update_idle_growth(dt)
	_spawn_units(dt)
	_update_units(dt)
	_update_swarms(dt)
	_update_contest_logs()
	_normalize_friendly_intents()
	_update_barracks(dt)
	_update_debris(dt)
	_update_lane_slots()
	_update_buff_states()
	_update_match_state(dt)
	_validate_state()
	_dispatch_events()
	if get_node_or_null("/root/DevMapRunner") != null:
		if sim_time_us - _dev_sim_dbg_us >= 1_000_000:
			_dev_sim_dbg_us = sim_time_us
			var p0: int = -1
			var lane_count: int = -1
			if state != null:
				lane_count = state.lanes.size()
				if state.hives.size() > 0:
					var h0: HiveData = state.hives[0]
					p0 = int(h0.power)
			SFLog.trace("SIMDBG:tick", {"lanes": lane_count, "p0": p0, "units": units.size()})
	if _tick_render_dirty:
		mark_render_dirty("tick")
		_push_render_model()

func export_render_model() -> Dictionary:
	if Engine.is_editor_hint():
		return {}
	if state == null:
		return {}
	var ops := OpsState
	var prev_render_export: bool = bool(ops._in_render_export)
	ops._in_render_export = true
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_export_log_ms > 1000:
		_last_export_log_ms = now_ms
		SFLog.error("EXPORT_RENDER_MODEL_VERSION", {"marker": "2026-01-14-A", "line": 0})
	assert(state is GameState)
	if not _render_dirty and not _render_model.is_empty():
		ops._in_render_export = prev_render_export
		return _render_model
	var out_hives: Array[Dictionary] = []
	var out_hives_by_id: Dictionary = {}
	var capture_flag_view: Dictionary = {"enabled": false}
	var capture_flag_by_hive_id: Dictionary = {}
	var cell_px: float = float(_cell_px())
	var local_owner_id: int = _resolve_local_owner_id()
	var local_flag_hive_id: int = 0
	if OpsState != null and OpsState.has_method("build_capture_flag_view"):
		capture_flag_view = OpsState.call("build_capture_flag_view", local_owner_id) as Dictionary
		var flags: Array = capture_flag_view.get("flags", []) as Array
		for flag_any in flags:
			if typeof(flag_any) != TYPE_DICTIONARY:
				continue
			var flag_entry: Dictionary = flag_any as Dictionary
			if not bool(flag_entry.get("visible_to_viewer", false)):
				continue
			var hive_id: int = int(flag_entry.get("hive_id", 0))
			if hive_id <= 0:
				continue
			capture_flag_by_hive_id[hive_id] = {
				"owner_id": int(flag_entry.get("owner_id", 0)),
				"hidden": bool(flag_entry.get("hidden", false)),
				"visible_to_viewer": bool(flag_entry.get("visible_to_viewer", false))
			}
	if _ctf_move_armed and OpsState != null and OpsState.has_method("get_capture_flag_for_owner"):
		var local_flag_state: Dictionary = OpsState.call("get_capture_flag_for_owner", local_owner_id) as Dictionary
		local_flag_hive_id = int(local_flag_state.get("hive_id", 0))
	if state != null:
		for hive in state.hives:
			var h: HiveData = hive
			var radius_px: float = float(h.radius_px)
			if radius_px <= 0.0:
				radius_px = MapSchema.hive_radius_px_for_kind(String(h.kind), cell_px)
			var render_gp: Vector2 = h.render_grid_pos
			if not is_finite(render_gp.x) or not is_finite(render_gp.y):
				render_gp = Vector2(float(h.grid_pos.x), float(h.grid_pos.y))
			var pos: Vector2 = Vector2(
				(render_gp.x + grid_coord_render_offset) * cell_px,
				(render_gp.y + grid_coord_render_offset) * cell_px
			)
			var hd: Dictionary = {
				"id": int(h.id),
				"grid_pos": [render_gp.x, render_gp.y],
				"x": render_gp.x,
				"y": render_gp.y,
				"grid_cell": Vector2i(h.grid_pos),
				"pos": pos,
				"radius_px": radius_px,
				"owner_id": int(h.owner_id),
				"pwr": int(h.power),
				"lane_budget_used": int(state.outgoing_active_count(int(h.id))),
				"lane_budget_max": int(state.lanes_allowed_for_power(int(h.power))),
				"kind": String(h.kind)
			}
			var swarm_cooldown_remaining_ms: int = int(OpsState.get_swarm_cooldown_remaining_ms(int(h.id))) if OpsState != null and OpsState.has_method("get_swarm_cooldown_remaining_ms") else 0
			if swarm_cooldown_remaining_ms > 0:
				hd["swarm_cooldown_remaining_ms"] = swarm_cooldown_remaining_ms
				hd["swarm_cooldown_total_ms"] = int(OpsState.get_swarm_cooldown_total_ms()) if OpsState != null and OpsState.has_method("get_swarm_cooldown_total_ms") else 5000
			if capture_flag_by_hive_id.has(int(h.id)):
				var flag_view: Dictionary = capture_flag_by_hive_id[int(h.id)] as Dictionary
				hd["is_capture_flag"] = true
				hd["capture_flag_owner_id"] = int(flag_view.get("owner_id", 0))
				hd["capture_flag_hidden"] = bool(flag_view.get("hidden", false))
			if _ctf_move_armed and int(h.owner_id) == local_owner_id and int(h.id) != local_flag_hive_id:
				hd["capture_flag_move_target"] = true
			out_hives.append(hd)
			out_hives_by_id[int(h.id)] = hd
	var out_lanes: Array[Dictionary] = []
	var front_by_lane_id: Dictionary = OpsState.lane_front_by_lane_id
	if state != null:
		for lane_any in state.lanes:
			if lane_any is LaneData:
				var l: LaneData = lane_any
				var lane_id: int = int(l.id)
				out_lanes.append({
					"lane_id": lane_id,
					"a_id": int(l.a_id),
					"b_id": int(l.b_id),
					"send_a": bool(l.send_a),
					"send_b": bool(l.send_b),
					"intent": "",
					"pressure": 0,
					"front_t": float(front_by_lane_id.get(lane_id, 0.5))
				})
			elif lane_any is Dictionary:
				var d: Dictionary = lane_any as Dictionary
				var a_id: int = int(d.get("a_id", d.get("from", 0)))
				var b_id: int = int(d.get("b_id", d.get("to", 0)))
				var lane_id: int = int(d.get("lane_id", d.get("id", -1)))
				out_lanes.append({
					"lane_id": lane_id,
					"a_id": a_id,
					"b_id": b_id,
					"send_a": bool(d.get("send_a", false)),
					"send_b": bool(d.get("send_b", false)),
					"intent": str(d.get("intent", "")),
					"pressure": int(d.get("pressure", 0)),
					"front_t": float(front_by_lane_id.get(lane_id, 0.5))
				})
	var out_runtime_lanes: Array[Dictionary] = out_lanes
	var out_lane_candidates: Array[Dictionary] = []
	if state != null:
		for cand_v in state.lane_candidates:
			if typeof(cand_v) != TYPE_DICTIONARY:
				continue
			var cand: Dictionary = cand_v as Dictionary
			out_lane_candidates.append(cand)
	var out_lane_sim: Array[Dictionary] = []
	if state != null:
		for key in state.lane_sim_by_key.keys():
			var lane_state: Dictionary = state.lane_sim_by_key.get(key, {})
			if lane_state.is_empty():
				continue
			var a_id: int = int(lane_state.get("a_id", 0))
			var b_id: int = int(lane_state.get("b_id", 0))
			if a_id <= 0 or b_id <= 0:
				continue
			if _lane_index_between(a_id, b_id) == -1:
				continue
			var side_out: Array[Dictionary] = []
			var side_by_owner: Dictionary = lane_state.get("side", {})
			var establish_t_by_owner: Dictionary = lane_state.get("establish_t_by_owner", {})
			var establishing_by_owner: Dictionary = lane_state.get("establishing_by_owner", {})
			var established_by_owner: Dictionary = lane_state.get("established_by_owner", {})
			for owner_key in side_by_owner.keys():
				var side: Dictionary = side_by_owner[owner_key]
				var owner_id := int(side.get("owner_id", 0))
				side_out.append({
					"owner_id": owner_id,
					"dir": int(side.get("dir", 0)),
					"establishing": bool(establishing_by_owner.get(owner_id, false)),
					"est_progress": float(establish_t_by_owner.get(owner_id, 0.0)),
					"established": bool(established_by_owner.get(owner_id, false))
				})
			out_lane_sim.append({
				"lane_key": str(lane_state.get("lane_key", key)),
				"a_id": a_id,
				"b_id": b_id,
				"front_t": float(lane_state.get("front_t", 0.5)),
				"side": side_out
			})
	var out_units: Array[Dictionary] = []
	var units_src: Array = []
	if unit_system != null:
		var units_v: Variant = unit_system.export_units_render()
		if typeof(units_v) == TYPE_ARRAY:
			units_src = units_v as Array
	elif state != null:
		var units_v: Variant = state.units_by_lane.get("_all", [])
		if typeof(units_v) == TYPE_ARRAY:
			units_src = units_v as Array
	for unit in units_src:
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var ud: Dictionary = unit as Dictionary
		var entry := {
			"id": int(ud.get("id", -1)),
			"from": int(ud.get("from_id", 0)),
			"to": int(ud.get("to_id", 0)),
			"lane_id": int(ud.get("lane_id", 0)),
			"t": clampf(float(ud.get("t", 0.0)), 0.0, 1.0),
			"lane_key": str(ud.get("lane_key", "")),
			"a_id": int(ud.get("a_id", ud.get("from_id", 0))),
			"b_id": int(ud.get("b_id", ud.get("to_id", 0))),
			"owner_id": int(ud.get("owner_id", 0))
		}
		var from_pos_v: Variant = ud.get("from_pos")
		if typeof(from_pos_v) == TYPE_VECTOR2:
			entry["from_pos"] = from_pos_v
		var to_pos_v: Variant = ud.get("to_pos")
		if typeof(to_pos_v) == TYPE_VECTOR2:
			entry["to_pos"] = to_pos_v
		var pos_v: Variant = ud.get("pos")
		if typeof(pos_v) == TYPE_VECTOR2:
			entry["pos"] = pos_v
		out_units.append(entry)
	var out_towers: Array[Dictionary] = []
	var towers_src: Array = state.towers if state != null else []
	for tower_any in towers_src:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = tower_any as Dictionary
		var tower_id: int = int(td.get("node_id", td.get("id", -1)))
		if tower_id <= 0:
			continue
		var gp_v: Variant = td.get("grid_pos", Vector2i.ZERO)
		var gp: Vector2i = Vector2i.ZERO
		if gp_v is Vector2i:
			gp = gp_v as Vector2i
		elif gp_v is Array:
			var gp_arr: Array = gp_v as Array
			if gp_arr.size() >= 2:
				gp = Vector2i(int(gp_arr[0]), int(gp_arr[1]))
		var pos_px: Vector2 = _cell_center(gp)
		var control_ids: Array = []
		var control_v: Variant = td.get("control_hive_ids", td.get("required_hive_ids", []))
		if typeof(control_v) == TYPE_ARRAY:
			for hive_id_v in control_v as Array:
				control_ids.append(int(hive_id_v))
		var authored_pos_px: Vector2 = pos_px
		pos_px = _structure_control_centroid_pos(control_ids, authored_pos_px, out_hives_by_id)
		out_towers.append({
			"id": tower_id,
			"grid_pos": gp,
			"world_pos": pos_px,
			"pos_px": pos_px,
			"authored_pos_px": authored_pos_px,
			"owner_id": int(td.get("owner_id", 0)),
			"active": bool(td.get("active", false)),
			"is_controlled": bool(td.get("is_controlled", false)),
			"tier": int(td.get("tier", 1)),
			"control_hive_ids": control_ids
		})
	SFLog.log_on_change_payload("RENDER_MODEL_TOWERS", out_towers.size(), {"count": out_towers.size()})
	if towers_src.size() > 0 and out_towers.is_empty():
		SFLog.error("TOWER_EXPORT_MISSING", {"source_count": towers_src.size()})
	var out_barracks: Array[Dictionary] = []
	var barracks_src: Array = state.barracks if state != null else []
	for barracks_any in barracks_src:
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var bd: Dictionary = barracks_any as Dictionary
		var barracks_id: int = int(bd.get("id", -1))
		if barracks_id <= 0:
			continue
		var gp_b_v: Variant = bd.get("grid_pos", Vector2i.ZERO)
		var gp_b: Vector2i = Vector2i.ZERO
		if gp_b_v is Vector2i:
			gp_b = gp_b_v as Vector2i
		elif gp_b_v is Array:
			var gp_b_arr: Array = gp_b_v as Array
			if gp_b_arr.size() >= 2:
				gp_b = Vector2i(int(gp_b_arr[0]), int(gp_b_arr[1]))
		var pos_px: Vector2 = _cell_center(gp_b)
		var control_ids: Array = []
		var control_v: Variant = bd.get("control_hive_ids", bd.get("required_hive_ids", []))
		if typeof(control_v) == TYPE_ARRAY:
			for control_any in control_v as Array:
				control_ids.append(int(control_any))
		var req_ids: Array = []
		var req_v: Variant = bd.get("required_hive_ids", [])
		if typeof(req_v) == TYPE_ARRAY:
			for req_any in req_v as Array:
				req_ids.append(int(req_any))
		var authored_pos_px: Vector2 = pos_px
		pos_px = _structure_control_centroid_pos(control_ids, authored_pos_px, out_hives_by_id)
		out_barracks.append({
			"id": barracks_id,
			"grid_pos": gp_b,
			"world_pos": pos_px,
			"pos_px": pos_px,
			"authored_pos_px": authored_pos_px,
			"owner_id": int(bd.get("owner_id", 0)),
			"active": bool(bd.get("active", false)),
			"is_controlled": bool(bd.get("is_controlled", false)),
			"tier": int(bd.get("tier", 1)),
			"control_hive_ids": control_ids,
			"required_hive_ids": req_ids
		})
	SFLog.log_on_change_payload("RENDER_MODEL_BARRACKS", out_barracks.size(), {"count": out_barracks.size()})
	if barracks_src.size() > 0 and out_barracks.is_empty():
		SFLog.error("BARRACKS_EXPORT_MISSING", {"source_count": barracks_src.size()})
	var out_swarms: Array[Dictionary] = []
	if sim_runner != null and sim_runner.swarm_system != null:
		var swarms_v: Variant = sim_runner.swarm_system.swarm_packets
		if typeof(swarms_v) == TYPE_ARRAY:
			for swarm_any in swarms_v as Array:
				if typeof(swarm_any) != TYPE_DICTIONARY:
					continue
				var sd: Dictionary = swarm_any as Dictionary
				var swarm_id: int = int(sd.get("id", -1))
				var lane_id: int = int(sd.get("lane_id", -1))
				if swarm_id <= 0 or lane_id <= 0:
					continue
				var dir: int = int(sd.get("dir", 0))
				var t_raw: float = clampf(float(sd.get("t", 0.0)), 0.0, 1.0)
				var side: String = "A" if dir >= 0 else "B"
				var t_out: float = t_raw if dir >= 0 else (1.0 - t_raw)
				out_swarms.append({
					"swarm_id": swarm_id,
					"lane_id": lane_id,
					"owner_id": int(sd.get("owner_id", 0)),
					"side": side,
					"t": t_out,
					"count": int(sd.get("count", 0)),
					"src": int(sd.get("from_id", 0)),
					"dst": int(sd.get("to_id", 0))
				})
	if debug_export_rm_log:
		var now_msec := Time.get_ticks_msec()
		if now_msec - _last_export_rm_log_ms >= debug_export_rm_log_interval_ms:
			_last_export_rm_log_ms = now_msec
			SFLog.trace("EXPORT_RM_STATE", {"state": state, "type": typeof(state)})
	var sim_time_s: float = 0.0
	if unit_system != null:
		sim_time_s = float(unit_system.sim_time_us) / 1000000.0
	var clock_payload: Dictionary = {}
	if state != null:
		var duration_ms := int(OpsState.match_duration_ms)
		var elapsed_ms := int(OpsState.match_elapsed_ms)
		var remaining_ms := maxi(0, duration_ms - elapsed_ms)
		var over := OpsState.has_outcome()
		var winner_id := int(OpsState.winner_id)
		var reason := str(OpsState.match_end_reason) if over else ""
		clock_payload = {
			"elapsed_ms": elapsed_ms,
			"duration_ms": duration_ms,
			"remaining_ms": remaining_ms,
			"over": over,
			"winner_id": winner_id,
			"reason": reason
		}
	_render_model = {
		"hives": out_hives,
		"hives_by_id": out_hives_by_id,
		"lanes": out_lanes,
		"runtime_lanes": out_runtime_lanes,
		"lane_candidates": out_lane_candidates,
		"lane_sim": out_lane_sim,
		"units": out_units,
		"swarms": out_swarms,
		"towers": out_towers,
		"barracks": out_barracks,
		"cell_size": int(CELL_SIZE),
		"sim_running": bool(sim_runner != null and sim_runner.running),
		"clock": clock_payload,
		"outcome": int(OpsState.outcome) if state != null else int(GameState.GameOutcome.NONE),
		"outcome_reason": str(OpsState.outcome_reason) if state != null else "",
		"outcome_tick": int(OpsState.outcome_tick) if state != null else -1,
		"winner_id": int(OpsState.winner_id) if state != null else 0,
		"victory_mode": str(OpsState.get_victory_mode()) if state != null and OpsState != null and OpsState.has_method("get_victory_mode") else "conquest",
		"capture_flag": capture_flag_view,
		"match_time_remaining_sec": float(OpsState.match_time_remaining_sec) if state != null else 0.0,
		"match_clock_running": bool(OpsState.match_clock_running) if state != null else false,
		"selected_lane_id": int(sel.selected_lane_id) if sel != null else -1,
		"barracks_select_id": int(barracks_select_id),
		"barracks_select_pid": int(barracks_select_pid),
		"barracks_select_targets": barracks_select_targets.duplicate(),
		"render_version": render_version,
		"sim_time_s": sim_time_s,
		"units_set_version": int(state.units_set_version) if state != null else 0,
		"hives_set_version": int(state.hives_set_version) if state != null else 0,
		"iid": int(state.get_instance_id()) if state != null else -1

	}
	for d in out_lanes:
		if int(d.get("lane_id", -1)) == 6:
			var lane_id: int = int(d.get("lane_id", -1))
			var front_t: Variant = front_by_lane_id.get(lane_id, null)
			SFLog.log_once("RM_LANE6", "RM_LANE6", SFLog.Level.INFO, {
				"rm": d,
				"front_t_state": front_t
			})
			break
	_render_dirty = false
	ops._in_render_export = prev_render_export
	return _render_model

func _compute_hive_nodes_sig_for_render(hive_nodes_by_id: Dictionary) -> int:
	var sig: int = hive_nodes_by_id.size()
	var sum_ids: int = 0
	var sum_nodes: int = 0
	var xor_mix: int = 0
	for key_any in hive_nodes_by_id.keys():
		var hive_id: int = int(key_any)
		var node_any: Variant = hive_nodes_by_id.get(key_any, null)
		var node_iid: int = 0
		if node_any is Object:
			var node_obj: Object = node_any as Object
			node_iid = int(node_obj.get_instance_id())
		sum_ids = (sum_ids + hive_id) & 0x7fffffff
		sum_nodes = (sum_nodes + node_iid) & 0x7fffffff
		xor_mix = xor_mix ^ int((hive_id * 1315423911) ^ node_iid)
	sig = (sig * 31 + sum_ids) & 0x7fffffff
	sig = (sig * 31 + sum_nodes) & 0x7fffffff
	sig = (sig * 31 + xor_mix) & 0x7fffffff
	return sig

func _maybe_push_hive_nodes_to_renderers(lane_r: Node, unit_r: Node, hive_nodes_by_id: Dictionary, hives_version: int) -> void:
	var sig: int = _compute_hive_nodes_sig_for_render(hive_nodes_by_id)
	var force_push: bool = false
	if hives_version != _last_render_hives_version:
		_last_render_hives_version = hives_version
		force_push = true
	if not force_push and sig == _last_render_hive_nodes_sig:
		SFLog.info("HIVE_NODES_SET_SKIPPED", {
			"renderer": "arena",
			"reason": "sig_unchanged",
			"count": hive_nodes_by_id.size()
		}, "", 1000)
		return
	_last_render_hive_nodes_sig = sig
	if lane_r != null and lane_r.has_method("set_hive_nodes"):
		lane_r.call("set_hive_nodes", hive_nodes_by_id)
	if unit_r != null and unit_r.has_method("set_hive_nodes"):
		unit_r.call("set_hive_nodes", hive_nodes_by_id)

func _build_hive_pos_by_id(hive_nodes_by_id: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if wall_renderer == null:
		return out
	if not hive_nodes_by_id.is_empty():
		for key_any in hive_nodes_by_id.keys():
			var hive_id: int = int(key_any)
			var node_any: Variant = hive_nodes_by_id.get(key_any, null)
			if node_any is Node2D:
				var node: Node2D = node_any as Node2D
				out[hive_id] = wall_renderer.to_local(node.global_position)
	if out.is_empty() and state != null:
		for hive in state.hives:
			if hive == null:
				continue
			var render_gp: Vector2 = hive.render_grid_pos
			if not is_finite(render_gp.x) or not is_finite(render_gp.y):
				render_gp = Vector2(float(hive.grid_pos.x), float(hive.grid_pos.y))
			out[int(hive.id)] = _grid_coord_to_world(render_gp)
	return out

func _grid_coord_to_world(coord: Vector2) -> Vector2:
	var center_offset: float = grid_coord_render_offset
	if grid_spec != null:
		var cs: float = float(grid_spec.cell_size)
		return grid_spec.origin + (coord + Vector2(center_offset, center_offset)) * cs
	var cell_px: float = _cell_px()
	return (coord + Vector2(center_offset, center_offset)) * cell_px + map_offset

func _wall_entry_to_grid_segment(w: Dictionary) -> Dictionary:
	if w.has("x1") and w.has("y1") and w.has("x2") and w.has("y2"):
		return {
			"a": Vector2(float(w.get("x1", 0.0)), float(w.get("y1", 0.0))),
			"b": Vector2(float(w.get("x2", 0.0)), float(w.get("y2", 0.0)))
		}
	var dir: String = str(w.get("dir", "")).to_lower()
	var x: float = float(w.get("x", -999.0))
	var y: float = float(w.get("y", -999.0))
	if x < -100.0 or y < -100.0:
		return {}
	if dir == "v" or dir == "vertical":
		var xline: float = x - 0.5
		return {
			"a": Vector2(xline, y - 0.5),
			"b": Vector2(xline, y + 0.5)
		}
	if dir == "h" or dir == "horizontal":
		var yline: float = y - 0.5
		return {
			"a": Vector2(x - 0.5, yline),
			"b": Vector2(x + 0.5, yline)
		}
	return {}

func _build_wall_segments_local() -> Array:
	var out: Array = []
	if wall_renderer == null or state == null:
		return out
	var walls_v: Variant = state.get("walls")
	if typeof(walls_v) != TYPE_ARRAY:
		return out
	var walls: Array = walls_v as Array
	for w_any in walls:
		if typeof(w_any) != TYPE_DICTIONARY:
			continue
		var w: Dictionary = w_any as Dictionary
		var seg_grid: Dictionary = _wall_entry_to_grid_segment(w)
		if seg_grid.is_empty():
			continue
		var a_any: Variant = seg_grid.get("a", null)
		var b_any: Variant = seg_grid.get("b", null)
		if not (a_any is Vector2 and b_any is Vector2):
			continue
		var a_map_local: Vector2 = _grid_coord_to_world(a_any as Vector2)
		var b_map_local: Vector2 = _grid_coord_to_world(b_any as Vector2)
		var a_world: Vector2 = a_map_local
		var b_world: Vector2 = b_map_local
		if map_root != null:
			a_world = map_root.to_global(a_map_local)
			b_world = map_root.to_global(b_map_local)
		out.append({
			"a": wall_renderer.to_local(a_world),
			"b": wall_renderer.to_local(b_world)
		})
	return out

func _sync_wall_renderer(hive_nodes_by_id: Dictionary) -> void:
	_ensure_wall_renderer()
	if wall_renderer == null:
		return
	var segments: Array = _build_wall_segments_local()
	if not segments.is_empty():
		var sample_seg: Dictionary = segments[0] as Dictionary if typeof(segments[0]) == TYPE_DICTIONARY else {}
		SFLog.warn("WALL_VIS_SYNC", {
			"mode": "segments",
			"segments": segments.size(),
			"sample_a": sample_seg.get("a", null),
			"sample_b": sample_seg.get("b", null),
			"wall_renderer_path": _node_path_for_log(wall_renderer),
			"wall_renderer_pos": wall_renderer.position,
			"wall_renderer_visible": wall_renderer.visible,
			"wall_renderer_z": wall_renderer.z_index,
			"map_root_pos": map_root.position if map_root != null else null
		}, "", 5000)
		wall_renderer.set_wall_segments(segments)
		return
	var pairs: Array = []
	if OpsState != null and OpsState.has_method("get_blocked_wall_pairs"):
		var any_pairs: Variant = OpsState.call("get_blocked_wall_pairs")
		if typeof(any_pairs) == TYPE_ARRAY:
			pairs = any_pairs as Array
	var hive_pos_by_id: Dictionary = _build_hive_pos_by_id(hive_nodes_by_id)
	SFLog.warn("WALL_VIS_SYNC", {
		"mode": "pairs",
		"pairs": pairs.size(),
		"hive_pos_count": hive_pos_by_id.size(),
		"wall_renderer_path": _node_path_for_log(wall_renderer),
		"wall_renderer_pos": wall_renderer.position,
		"wall_renderer_visible": wall_renderer.visible,
		"wall_renderer_z": wall_renderer.z_index,
		"map_root_pos": map_root.position if map_root != null else null
	}, "", 5000)
	wall_renderer.set_wall_pairs(pairs, hive_pos_by_id)

func notify_wall_blocked_attempt(src_hive_id: int, dst_hive_id: int, intent: String = "attack") -> void:
	if wall_renderer == null or not is_instance_valid(wall_renderer):
		return
	if state == null:
		return
	var src_hive: HiveData = state.find_hive_by_id(src_hive_id)
	var dst_hive: HiveData = state.find_hive_by_id(dst_hive_id)
	if src_hive == null or dst_hive == null:
		return
	var src_pos: Vector2 = _grid_coord_to_world(src_hive.render_grid_pos if is_finite(src_hive.render_grid_pos.x) and is_finite(src_hive.render_grid_pos.y) else Vector2(float(src_hive.grid_pos.x), float(src_hive.grid_pos.y)))
	var dst_pos: Vector2 = _grid_coord_to_world(dst_hive.render_grid_pos if is_finite(dst_hive.render_grid_pos.x) and is_finite(dst_hive.render_grid_pos.y) else Vector2(float(dst_hive.grid_pos.x), float(dst_hive.grid_pos.y)))
	if map_root != null:
		src_pos = map_root.to_global(src_pos)
		dst_pos = map_root.to_global(dst_pos)
	wall_renderer.notify_blocked_attempt_path(wall_renderer.to_local(src_pos), wall_renderer.to_local(dst_pos), intent)

func _push_render_model() -> void:
	var rm: Dictionary = export_render_model()
	if rm.is_empty():
		return
	var lane_r: Node = get_node_or_null("MapRoot/LaneRenderer")
	var hive_r: Node = get_node_or_null("MapRoot/HiveRenderer")
	var unit_r: Node = unit_renderer
	if unit_r == null:
		unit_r = _resolve_unit_renderer()
		if unit_r is Node2D:
			unit_renderer = unit_r as Node2D
	var tower_r: Node = get_node_or_null("MapRoot/TowerRenderer")
	var tower_glow_r: Node = get_node_or_null("MapRoot/TowerGroundGlowRenderer")
	var barracks_r: Node = get_node_or_null("MapRoot/BarracksRenderer")
	var barracks_glow_r: Node = get_node_or_null("MapRoot/BarracksGroundGlowRenderer")
	var hives_version_render: int = int(rm.get("hives_set_version", -1))
	var hive_nodes_by_id: Dictionary = {}
	if hive_r != null and hive_r.has_method("get_hive_nodes_by_id"):
		var hive_nodes_any: Variant = hive_r.call("get_hive_nodes_by_id")
		if typeof(hive_nodes_any) == TYPE_DICTIONARY:
			hive_nodes_by_id = hive_nodes_any as Dictionary
	_sync_wall_renderer(hive_nodes_by_id)
	if hive_r != null:
		if hive_r.has_method("set_model"):
			hive_r.call("set_model", rm)
		else:
			hive_r.set("model", rm)
		hive_r.queue_redraw()
	if lane_r != null:
		if lane_r.has_method("set_model"):
			lane_r.call("set_model", rm)
		else:
			lane_r.set("model", rm)
		lane_r.queue_redraw()
	if unit_r != null:
		if unit_r.has_method("set_model"):
			unit_r.call("set_model", rm)
		else:
			unit_r.set("model", rm)
		var phase_now: int = int(OpsState.match_phase)
		var post_match_phase: bool = phase_now == int(OpsState.MatchPhase.ENDING) or phase_now == int(OpsState.MatchPhase.ENDED)
		var freeze_unit_bind: bool = post_match_phase and _post_match_render_frozen
		var hives_v: Variant = rm.get("hives", [])
		var hives_arr: Array = hives_v as Array if typeof(hives_v) == TYPE_ARRAY else []
		var units_v: Variant = rm.get("units", [])
		var units_arr: Array = units_v as Array if typeof(units_v) == TYPE_ARRAY else []
		var hives_version: int = hives_version_render
		var units_version: int = int(rm.get("units_set_version", -1))
		var sim_time_us_out: int = int(round(float(rm.get("sim_time_s", 0.0)) * 1000000.0))
		if unit_r.has_method("bind_hives"):
			unit_r.call("bind_hives", hives_arr, hives_version)
		if unit_r.has_method("bind_units") and not freeze_unit_bind:
			unit_r.call("bind_units", units_arr, units_version, sim_time_us_out)
		if bool(unit_r.get("debug_draw_units")):
			unit_r.queue_redraw()
	if not hive_nodes_by_id.is_empty() and (lane_r != null or unit_r != null):
		_maybe_push_hive_nodes_to_renderers(lane_r, unit_r, hive_nodes_by_id, hives_version_render)
	if tower_r != null:
		if tower_r.has_method("set_model"):
			tower_r.call("set_model", rm)
		else:
			tower_r.set("model", rm)
		var source_count: int = state.towers.size() if state != null else 0
		if source_count > 0:
			var towers_v: Variant = rm.get("towers", [])
			var towers_arr: Array = towers_v as Array if typeof(towers_v) == TYPE_ARRAY else []
			if towers_arr.is_empty():
				SFLog.error("TOWER_RENDERER_MISSING", {
					"arena_towers": source_count,
					"render_towers": towers_arr.size()
				})
		tower_r.queue_redraw()
	if tower_glow_r != null:
		if tower_glow_r.has_method("set_model"):
			tower_glow_r.call("set_model", rm)
		else:
			tower_glow_r.set("model", rm)
		tower_glow_r.queue_redraw()
	if barracks_glow_r != null:
		if barracks_glow_r.has_method("set_model"):
			barracks_glow_r.call("set_model", rm)
		else:
			barracks_glow_r.set("model", rm)
		barracks_glow_r.queue_redraw()
	if barracks_r != null:
		if barracks_r.has_method("set_model"):
			barracks_r.call("set_model", rm)
		else:
			barracks_r.set("model", rm)
		var source_barracks: int = state.barracks.size() if state != null else 0
		if source_barracks > 0:
			var barracks_v: Variant = rm.get("barracks", [])
			var barracks_arr: Array = barracks_v as Array if typeof(barracks_v) == TYPE_ARRAY else []
			if barracks_arr.is_empty():
				SFLog.error("BARRACKS_RENDERER_MISSING", {
					"arena_barracks": source_barracks,
					"render_barracks": barracks_arr.size()
				})
		barracks_r.queue_redraw()
	if floor_influence_system != null:
		floor_influence_system.apply_render_model(rm)

func _structure_control_centroid_pos(control_ids: Array, fallback_pos: Vector2, hives_by_id: Dictionary) -> Vector2:
	if control_ids.is_empty():
		return fallback_pos
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for hive_id_v in control_ids:
		var hive_id: int = int(hive_id_v)
		var hive_any: Variant = hives_by_id.get(hive_id, {})
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var pos_v: Variant = hive.get("pos", hive.get("world_pos", null))
		if not (pos_v is Vector2):
			continue
		var hive_pos: Vector2 = pos_v as Vector2
		sum += hive_pos
		count += 1
	if count <= 0:
		return fallback_pos
	return sum / float(count)

func _queue_event(event: Dictionary) -> void:
	events.append(event)

func _dispatch_events() -> void:
	if events.is_empty():
		return
	if audio_system != null:
		audio_system.handle_events(events, sim_time_us)
	if debug_system != null:
		debug_system.handle_events(events, api)
	events.clear()

func _update_hive_shock(dt: float) -> void:
	var dt_ms := dt * 1000.0
	for hive in state.hives:
		if hive.shock_ms > 0.0:
			hive.shock_ms = max(0.0, hive.shock_ms - dt_ms)

func _init_buff_states() -> void:
	if not buff_states.is_empty():
		return
	if _is_crucible_match():
		_reset_buff_runtime()
		return
	if not buffs_enabled:
		return
	if _is_async_runtime_mode():
		_ensure_async_buff_contest_state()
	for pid in [1, 2, 3, 4]:
		var buff_state: BuffState = BuffState.new()
		var result: Dictionary = buff_state.configure_loadout(_default_buff_loadout(pid))
		if not bool(result.get("ok", false)):
			if SFLog.LOGGING_ENABLED:
				push_error("ARENA: buff loadout invalid for P%d: %s" % [pid, result.get("error", "unknown")])
		buff_states[pid] = buff_state

func _default_buff_loadout(pid: int = -1) -> Array:
	var profile_ids: Array[String] = _resolve_profile_loadout_ids()
	var resolved_pid: int = pid
	if resolved_pid <= 0:
		resolved_pid = int(active_player_id)
	if resolved_pid == int(active_player_id):
		return _build_loadout_entries(profile_ids, _is_async_runtime_mode())
	var candidate_pool: Array[String] = _supported_runtime_classic_buff_ids(profile_ids)
	if candidate_pool.size() < BuffState.LOADOUT_SIZE:
		candidate_pool = _supported_runtime_classic_buff_ids([])
	var seeded_ids: Array[String] = _pick_seeded_unique_ids(candidate_pool, resolved_pid, BuffState.LOADOUT_SIZE)
	if seeded_ids.size() < BuffState.LOADOUT_SIZE:
		seeded_ids = profile_ids
	return _build_loadout_entries(seeded_ids, false)

func _resolve_profile_loadout_ids() -> Array[String]:
	var ids: Array[String] = []
	var profile_ids: Variant = []
	if _is_async_runtime_mode():
		var contest_state: Dictionary = _ensure_async_buff_contest_state()
		profile_ids = contest_state.get("loadout", [])
	elif ProfileManager != null and ProfileManager.has_method("get_buff_loadout_ids_for_mode"):
		profile_ids = ProfileManager.call("get_buff_loadout_ids_for_mode", "vs")
	elif ProfileManager != null and ProfileManager.has_method("get_buff_loadout_ids"):
		profile_ids = ProfileManager.call("get_buff_loadout_ids")
	if typeof(profile_ids) == TYPE_ARRAY:
		for buff_id_v in profile_ids as Array:
			var buff_id: String = str(buff_id_v).strip_edges()
			if buff_id == "":
				continue
			if BuffCatalog.get_buff(buff_id).is_empty():
				continue
			if _is_async_runtime_mode() and _async_buff_uses_remaining(buff_id) <= 0:
				continue
			ids.append(buff_id)
	return ids

func _build_loadout_entries(ids: Array[String], use_async_contest_charges: bool = false) -> Array:
	var out: Array = []
	var count: int = mini(ids.size(), BuffState.LOADOUT_SIZE)
	for i in range(count):
		var buff: Dictionary = BuffCatalog.get_buff(ids[i])
		if buff.is_empty():
			continue
		out.append({
			"id": ids[i],
			"tier": str(buff.get("tier", "classic")),
			"uses": _async_buff_uses_remaining(ids[i]) if use_async_contest_charges else 1,
			"uses_total": 2 if use_async_contest_charges else 1
		})
	return out

func _ensure_async_buff_contest_state() -> Dictionary:
	var tree: SceneTree = get_tree()
	if tree == null or not _is_async_runtime_mode():
		return {}
	var existing_any: Variant = tree.get_meta(TREE_META_ASYNC_BUFF_CONTEST_STATE, {})
	if typeof(existing_any) == TYPE_DICTIONARY and not (existing_any as Dictionary).is_empty():
		return (existing_any as Dictionary).duplicate(true)
	var loadout: Array[String] = []
	if ProfileManager != null and ProfileManager.has_method("get_buff_loadout_ids_for_mode"):
		loadout = _string_ids(ProfileManager.call("get_buff_loadout_ids_for_mode", "async"))
	elif ProfileManager != null and ProfileManager.has_method("get_buff_loadout_ids"):
		loadout = _string_ids(ProfileManager.call("get_buff_loadout_ids"))
	var charges: Dictionary = {}
	for buff_id in loadout:
		if buff_id == "" or BuffCatalog.get_buff(buff_id).is_empty() or charges.has(buff_id):
			continue
		charges[buff_id] = {"remaining": 2, "inventory_consumed": false}
	var state_out: Dictionary = {
		"loadout": loadout.duplicate(),
		"charges": charges,
		"uses_per_item": 2
	}
	tree.set_meta(TREE_META_ASYNC_BUFF_CONTEST_STATE, state_out)
	return state_out.duplicate(true)

func _string_ids(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for value_any in raw as Array:
		out.append(str(value_any).strip_edges())
	return out

func _async_buff_uses_remaining(buff_id: String) -> int:
	if not _is_async_runtime_mode():
		return 1
	var state_now: Dictionary = _ensure_async_buff_contest_state()
	var charges_any: Variant = state_now.get("charges", {})
	if typeof(charges_any) != TYPE_DICTIONARY:
		return 0
	var entry_any: Variant = (charges_any as Dictionary).get(buff_id, {})
	if typeof(entry_any) != TYPE_DICTIONARY:
		return 0
	return maxi(0, int((entry_any as Dictionary).get("remaining", 0)))

func preview_buff_targets(pid: int, slot_index: int) -> Dictionary:
	var owner_id: int = int(active_player_id)
	if pid != owner_id:
		return {"ok": false, "status": "rejected", "reason": "owner_mismatch", "owner_id": owner_id}
	if buff_states.is_empty():
		_init_buff_states()
	var buff_state: BuffState = buff_states.get(owner_id)
	if buff_state == null or slot_index < 0 or slot_index >= buff_state.slots.size():
		return {"ok": false, "status": "rejected", "reason": "slot_out_of_range"}
	var slot: Dictionary = buff_state.slots[slot_index] as Dictionary
	return _buff_target_resolver.get_preview_eligible_targets(
		_buff_authoritative_game_state(),
		owner_id,
		str(slot.get("inventory_id", slot.get("id", "")))
	)


func _setup_buff_hive_targeting_presentation() -> void:
	if buff_hive_targeting_controller == null:
		return
	buff_hive_targeting_controller.call("setup", self, hive_renderer)
	var selection_cb := Callable(self, "_on_buff_hive_target_selection_changed")
	if not buff_hive_targeting_controller.is_connected("selection_changed", selection_cb):
		buff_hive_targeting_controller.connect("selection_changed", selection_cb)


func update_buff_hive_targeting(
	pointer_session_id: int,
	preview: Dictionary,
	selected_hive_id: int,
	root_screen_pos: Vector2
) -> Dictionary:
	if buff_hive_targeting_controller == null:
		return {"ok": false, "reason": "hive_targeting_controller_missing"}
	if not bool(preview.get("ok", false)) or str(preview.get("target_type", "")) != BuffDefinitions.TARGET_HIVE:
		clear_buff_hive_targeting(pointer_session_id, "not_hive_targeting")
		return {"ok": false, "reason": "not_hive_targeting"}
	var eligible: Array = preview.get("eligible_target_ids", []) as Array
	var updated: bool = bool(buff_hive_targeting_controller.call(
		"begin_or_update",
		pointer_session_id,
		eligible,
		selected_hive_id,
		root_screen_pos
	))
	var snapshot: Dictionary = buff_hive_targeting_controller.call("get_snapshot") as Dictionary
	snapshot["ok"] = updated
	if not updated:
		snapshot["reason"] = "pointer_session_mismatch"
	return snapshot


func clear_buff_hive_targeting(pointer_session_id: int = -1, reason: String = "cleared") -> bool:
	if buff_hive_targeting_controller == null:
		return false
	return bool(buff_hive_targeting_controller.call("clear", pointer_session_id, true, reason))


func get_buff_hive_targeting_snapshot() -> Dictionary:
	if buff_hive_targeting_controller == null:
		return {"active": false}
	return buff_hive_targeting_controller.call("get_snapshot") as Dictionary


func _setup_buff_lane_global_targeting_presentation() -> void:
	if buff_lane_global_targeting_controller == null:
		return
	buff_lane_global_targeting_controller.call("setup", self, lane_renderer)
	var selection_cb := Callable(self, "_on_buff_lane_global_target_selection_changed")
	if not buff_lane_global_targeting_controller.is_connected("selection_changed", selection_cb):
		buff_lane_global_targeting_controller.connect("selection_changed", selection_cb)


func update_buff_lane_global_targeting(
	pointer_session_id: int,
	preview: Dictionary,
	selected_target_type: String,
	selected_target_id: Variant,
	root_screen_pos: Vector2
) -> Dictionary:
	if buff_lane_global_targeting_controller == null:
		return {"ok": false, "reason": "lane_global_targeting_controller_missing"}
	var target_type: String = str(preview.get("target_type", ""))
	if not bool(preview.get("ok", false)) or (target_type != BuffDefinitions.TARGET_LANE and target_type != "global"):
		clear_buff_lane_global_targeting(pointer_session_id, "not_lane_or_global_targeting")
		return {"ok": false, "reason": "not_lane_or_global_targeting"}
	var updated: bool = bool(buff_lane_global_targeting_controller.call(
		"begin_or_update",
		pointer_session_id,
		preview,
		selected_target_type,
		selected_target_id,
		root_screen_pos
	))
	var snapshot: Dictionary = buff_lane_global_targeting_controller.call("get_snapshot") as Dictionary
	snapshot["ok"] = updated
	if not updated:
		snapshot["reason"] = "pointer_session_mismatch"
	return snapshot


func clear_buff_lane_global_targeting(pointer_session_id: int = -1, reason: String = "cleared") -> bool:
	if buff_lane_global_targeting_controller == null:
		return false
	return bool(buff_lane_global_targeting_controller.call("clear", pointer_session_id, true, reason))


func get_buff_lane_global_targeting_snapshot() -> Dictionary:
	if buff_lane_global_targeting_controller == null:
		return {"active": false}
	return buff_lane_global_targeting_controller.call("get_snapshot") as Dictionary


func notify_buff_lane_render_nodes_changed() -> void:
	if buff_lane_global_targeting_controller != null:
		buff_lane_global_targeting_controller.call("notify_render_nodes_changed")


func _on_buff_lane_global_target_selection_changed(
	pointer_session_id: int,
	target_type: String,
	target_id: Variant,
	reason: String
) -> void:
	var shell: Node = get_node_or_null("/root/Shell")
	if shell == null or not shell.has_method("update_buff_pointer_selected_target"):
		return
	shell.call("update_buff_pointer_selected_target", pointer_session_id, target_type, target_id, reason)


func get_buff_targeting_transform_signature() -> String:
	var subviewport: SubViewport = get_viewport() as SubViewport
	var container: SubViewportContainer = subviewport.get_parent() as SubViewportContainer if subviewport != null else null
	if subviewport == null or container == null or map_root == null:
		return "invalid"
	var container_transform: Transform2D = container.get_global_transform_with_canvas()
	var canvas_transform: Transform2D = subviewport.get_canvas_transform()
	var map_transform: Transform2D = map_root.global_transform
	return "%s|%s|%s|%s|%s" % [
		str(container_transform),
		str(container.size),
		str(subviewport.size),
		str(canvas_transform),
		str(map_transform)
	]


func get_buff_global_targeting_query(root_screen_pos: Vector2) -> Dictionary:
	var conversion: Dictionary = root_screen_to_buff_arena_local(root_screen_pos)
	if not bool(conversion.get("ok", false)):
		return {"valid": false, "reason": str(conversion.get("reason", "invalid_conversion"))}
	var playfield_rect: Rect2 = _resolve_playfield_rect_px()
	var exclusion_rects: Array[Rect2] = _buff_global_exclusion_rects()
	if not buff_global_position_valid_for_rects(root_screen_pos, playfield_rect, exclusion_rects, true):
		return {"valid": false, "reason": "excluded_or_outside_playfield"}
	var inset_rect: Rect2 = playfield_rect.grow(-1.0)
	if inset_rect.size.x <= 1.0 or inset_rect.size.y <= 1.0:
		return {"valid": false, "reason": "playfield_rect_invalid"}
	var root_points := PackedVector2Array([
		inset_rect.position,
		Vector2(inset_rect.end.x, inset_rect.position.y),
		inset_rect.end,
		Vector2(inset_rect.position.x, inset_rect.end.y)
	])
	var arena_points := PackedVector2Array()
	for point in root_points:
		var point_conversion: Dictionary = root_screen_to_buff_arena_local(point)
		if not bool(point_conversion.get("ok", false)):
			return {"valid": false, "reason": "boundary_conversion_failed"}
		arena_points.append(point_conversion.get("arena_local_pos", Vector2.ZERO) as Vector2)
	return {
		"valid": true,
		"reason": "",
		"boundary_arena_local_points": arena_points,
		"playfield_root_rect": playfield_rect
	}


static func buff_global_position_valid_for_rects(
	root_screen_pos: Vector2,
	playfield_rect: Rect2,
	exclusion_rects: Array[Rect2],
	conversion_ok: bool
) -> bool:
	if not conversion_ok or playfield_rect.size.x <= 1.0 or playfield_rect.size.y <= 1.0:
		return false
	if not playfield_rect.has_point(root_screen_pos):
		return false
	for exclusion_rect in exclusion_rects:
		if exclusion_rect.size.x > 0.0 and exclusion_rect.size.y > 0.0 and exclusion_rect.has_point(root_screen_pos):
			return false
	return true


func _buff_global_exclusion_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var direct_paths: Array[String] = [
		"/root/Shell/MenuRoot",
		"/root/Shell/ArenaRoot/BackOverlay",
		SHELL_PLAYER_BUFF_STRIP_PATH,
		SHELL_OPPONENT_BUFF_STRIP_PATH,
		SHELL_OPPONENT_BUFF_STRIP_B_PATH,
		SHELL_ALLY_BUFF_STRIP_PATH,
		SHELL_HUD_ROOT_PATH + "/PreMatchOverlay",
		SHELL_OUTCOME_OVERLAY_PATH,
		SHELL_WIN_OVERLAY_PATH
	]
	for path in direct_paths:
		var control: Control = get_node_or_null(path) as Control
		_buff_append_visible_control_rect(rects, control)
	var main_ui: Node = get_node_or_null("../UI")
	if main_ui != null:
		for child in main_ui.get_children():
			_buff_collect_blocking_control_rects(child, rects)
	var hud_root: Node = get_node_or_null(SHELL_HUD_ROOT_PATH)
	if hud_root != null:
		for child in hud_root.get_children():
			if child.name == "BufferBackdropLayer" or child.name == "BuffDragOverlay":
				continue
			_buff_collect_blocking_control_rects(child, rects)
	return rects


func _buff_collect_blocking_control_rects(node: Node, rects: Array[Rect2]) -> void:
	if node == null or not is_instance_valid(node):
		return
	var control: Control = node as Control
	if control != null and control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_buff_append_visible_control_rect(rects, control)
		return
	for child in node.get_children():
		_buff_collect_blocking_control_rects(child, rects)


func _buff_append_visible_control_rect(rects: Array[Rect2], control: Control) -> void:
	if control == null or not control.is_visible_in_tree():
		return
	var rect: Rect2 = control.get_global_rect()
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		rects.append(rect)


func buff_arena_local_to_root_screen(arena_local_pos: Vector2) -> Dictionary:
	var subviewport: SubViewport = get_viewport() as SubViewport
	var container: SubViewportContainer = subviewport.get_parent() as SubViewportContainer if subviewport != null else null
	return _input_bridge_utils.arena_local_to_root_screen(
		arena_local_pos,
		container,
		subviewport,
		map_root
	)


func buff_arena_local_to_world(arena_local_pos: Vector2) -> Vector2:
	return map_root.to_global(arena_local_pos) if map_root != null else arena_local_pos


func _on_buff_hive_target_selection_changed(pointer_session_id: int, hive_id: int, reason: String) -> void:
	var shell: Node = get_node_or_null("/root/Shell")
	if shell == null or not shell.has_method("update_buff_pointer_selected_target"):
		return
	shell.call(
		"update_buff_pointer_selected_target",
		pointer_session_id,
		BuffDefinitions.TARGET_HIVE if hive_id > 0 else "",
		hive_id if hive_id > 0 else null,
		reason
	)


func get_buff_activation_source_snapshot(pid: int, slot_index: int) -> Dictionary:
	var owner_id: int = int(active_player_id)
	if pid != owner_id:
		return {"ok": false, "reason": "owner_mismatch", "owner_id": owner_id}
	if buff_states.is_empty():
		_init_buff_states()
	var buff_state: BuffState = buff_states.get(owner_id)
	if buff_state == null or slot_index < 0 or slot_index >= buff_state.slots.size():
		return {"ok": false, "reason": "slot_out_of_range"}
	if not buff_state.can_activate_slot(slot_index):
		return {"ok": false, "reason": "slot_blocked"}
	var slot: Dictionary = buff_state.slots[slot_index] as Dictionary
	var inventory_buff_id: String = str(slot.get("inventory_id", slot.get("id", ""))).strip_edges()
	var source: Dictionary = _buff_source_descriptor(owner_id, inventory_buff_id)
	if not bool(source.get("ok", false)):
		return source
	return {
		"ok": true,
		"owner_id": owner_id,
		"slot_index": slot_index,
		"inventory_revision": _buff_inventory_revision(),
		"slot": {
			"id": str(slot.get("id", "")),
			"inventory_id": inventory_buff_id,
			"tier": str(slot.get("tier", "classic")),
			"active": bool(slot.get("active", false)),
			"consumed": bool(slot.get("consumed", false)),
			"uses_remaining": int(slot.get("uses_remaining", 0)),
			"uses_total": int(slot.get("uses_total", 1))
		},
		"source_kind": str(source.get("source_kind", "")),
		"source_use_ordinal": int(source.get("source_use_ordinal", 0)),
		"charge_key": str(source.get("charge_key", "")),
		"quantity": int(source.get("capacity", 0))
	}


func root_screen_to_buff_arena_local(root_screen_pos: Vector2) -> Dictionary:
	var subviewport: SubViewport = get_viewport() as SubViewport
	var container: SubViewportContainer = subviewport.get_parent() as SubViewportContainer if subviewport != null else null
	return _input_bridge_utils.root_screen_to_arena_local(
		root_screen_pos,
		container,
		subviewport,
		map_root,
		true
	)


func resolve_buff_release_candidate(pid: int, slot_index: int, arena_local_pos: Vector2) -> Dictionary:
	var preview: Dictionary = preview_buff_targets(pid, slot_index)
	if not bool(preview.get("ok", false)):
		return preview
	var target_type: String = str(preview.get("target_type", "global"))
	var target_id: Variant = "global"
	if target_type != "global":
		var world_pos: Vector2 = map_root.to_global(arena_local_pos) if map_root != null else arena_local_pos
		var context: Dictionary = _buff_target_context_from_world(world_pos)
		if target_type == BuffDefinitions.TARGET_HIVE:
			target_id = int(context.get("hive_id", -1))
		elif target_type == BuffDefinitions.TARGET_LANE:
			target_id = int(context.get("lane_id", -1))
		else:
			return {"ok": false, "reason": "unsupported_target_type"}
		var eligible: Array = preview.get("eligible_target_ids", []) as Array
		if not eligible.has(target_id):
			return {"ok": false, "reason": "release_target_ineligible"}
	return {
		"ok": true,
		"target_type": target_type,
		"target_id": target_id
	}

func submit_buff_activation(
	pid: int,
	slot_index: int,
	target_type: String,
	target_id: Variant,
	activation_id: String = ""
) -> Dictionary:
	if not buffs_enabled or _is_crucible_match():
		return {"ok": false, "status": "rejected", "reason": "buffs_disabled"}
	var owner_id: int = int(active_player_id)
	if pid != owner_id:
		return {"ok": false, "status": "rejected", "reason": "owner_mismatch", "owner_id": owner_id}
	var clean_activation_id: String = activation_id.strip_edges()
	if not clean_activation_id.is_empty():
		var existing: Dictionary = _buff_activation_transactions.get_transaction(_buff_match_id(), owner_id, clean_activation_id)
		if bool(existing.get("ok", false)):
			existing["duplicate"] = true
			return existing
	if buff_states.is_empty():
		_init_buff_states()
	var buff_state: BuffState = buff_states.get(owner_id)
	if buff_state == null:
		return {"ok": false, "status": "rejected", "reason": "missing_player_state"}
	if slot_index < 0 or slot_index >= buff_state.slots.size():
		return {"ok": false, "status": "rejected", "reason": "slot_out_of_range"}
	if not buff_state.can_activate_slot(slot_index):
		return {"ok": false, "status": "rejected", "reason": "slot_blocked"}
	var slot: Dictionary = buff_state.slots[slot_index] as Dictionary
	var inventory_buff_id: String = str(slot.get("inventory_id", slot.get("id", ""))).strip_edges()
	var target_result: Dictionary = _buff_target_resolver.validate_canonical_target(
		_buff_authoritative_game_state(), owner_id, inventory_buff_id, target_type, target_id
	)
	if not bool(target_result.get("ok", false)):
		return target_result
	if clean_activation_id.is_empty():
		clean_activation_id = _next_buff_activation_id(owner_id)
	var source: Dictionary = _buff_source_descriptor(owner_id, inventory_buff_id)
	if not bool(source.get("ok", false)):
		return source
	# One equipped slot represents one reservable contest use even when the
	# fungible inventory owns several copies of the same buff.
	source["capacity"] = mini(1, int(source.get("capacity", 0)))
	var request: Dictionary = {
		"match_id": _buff_match_id(),
		"owner_id": owner_id,
		"activation_id": clean_activation_id,
		"slot_index": slot_index,
		"buff_id": inventory_buff_id,
		"canonical_buff_id": str(target_result.get("canonical_buff_id", slot.get("id", ""))),
		"tier": str(slot.get("tier", target_result.get("tier", "classic"))),
		"target_type": str(target_result.get("target_type", target_type)),
		"target_id": target_result.get("target_id", target_id),
		"target_payload": _buff_target_resolver.canonical_target_payload(
			str(target_result.get("target_type", target_type)), target_result.get("target_id", target_id)
		),
		"source_kind": str(source.get("source_kind", "vs")),
		"source_use_ordinal": int(source.get("source_use_ordinal", 1)),
		"charge_key": str(source.get("charge_key", "")),
		"inventory_revision": _buff_inventory_revision()
	}
	var reserved: Dictionary = _buff_activation_transactions.reserve_validated(request, target_result, int(source.get("capacity", 0)))
	if not bool(reserved.get("ok", false)) or bool(reserved.get("duplicate", false)):
		return reserved
	_buff_activation_transactions.mark_submitted(_buff_match_id(), owner_id, clean_activation_id)
	_persist_buff_activation_runtime_state()
	if _is_pvp_runtime_active():
		var accepted: bool = _vs_pvp_runtime.has_method("record_local_buff_activation") and bool(
			_vs_pvp_runtime.call("record_local_buff_activation", reserved)
		)
		if not accepted:
			var rejected: Dictionary = _buff_activation_transactions.reject_submission(
				_buff_match_id(), owner_id, clean_activation_id, "publish_rejected"
			)
			_persist_buff_activation_runtime_state()
			return rejected
		return _buff_activation_transactions.get_transaction(_buff_match_id(), owner_id, clean_activation_id)
	var local_command: Dictionary = _canonical_buff_command_from_reservation(reserved)
	_buff_activation_transactions.mark_canonically_scheduled(
		_buff_match_id(), owner_id, clean_activation_id, str(local_command.get("command_id", "")), int(local_command.get("execute_tick", -1))
	)
	return _execute_canonical_buff_activation(local_command)

func _buff_source_descriptor(pid: int, buff_id: String) -> Dictionary:
	if pid != int(active_player_id):
		return {
			"ok": true,
			"source_kind": "async" if _is_async_runtime_mode() else "vs",
			"source_use_ordinal": 1,
			"charge_key": "bot:%s:%d:%s" % [_buff_match_id(), pid, buff_id],
			"capacity": 1
		}
	if _is_async_runtime_mode():
		var state_now: Dictionary = _ensure_async_buff_contest_state()
		var charges: Dictionary = state_now.get("charges", {}) as Dictionary
		var entry: Dictionary = charges.get(buff_id, {}) as Dictionary
		var remaining: int = maxi(0, int(entry.get("remaining", 0)))
		var consumed: bool = bool(entry.get("inventory_consumed", false))
		if remaining <= 0:
			return {"ok": false, "status": "rejected", "reason": "no_contest_uses"}
		if consumed:
			if remaining != 1:
				return {"ok": false, "status": "rejected", "reason": "invalid_async_charge_state"}
			return {
				"ok": true,
				"source_kind": "async",
				"source_use_ordinal": 2,
				"charge_key": "async:%s:%d:%s:2" % [_buff_match_id(), pid, buff_id],
				"capacity": 1
			}
		if remaining != 2:
			return {"ok": false, "status": "rejected", "reason": "invalid_async_charge_state"}
	var quantity: int = _buff_inventory_quantity(buff_id)
	return {
		"ok": quantity > 0,
		"status": "available" if quantity > 0 else "rejected",
		"reason": "" if quantity > 0 else "insufficient_charges",
		"source_kind": "async" if _is_async_runtime_mode() else "vs",
		"source_use_ordinal": 1,
		"charge_key": "inventory:%d:%s" % [pid, buff_id],
		"capacity": quantity
	}

func _canonical_buff_command_from_reservation(reservation: Dictionary) -> Dictionary:
	var tick: int = int((_buff_authoritative_game_state() as Object).get("tick")) if _buff_authoritative_game_state() != null else 0
	return {
		"kind": "buff_activate",
		"command_id": "local:%s" % str(reservation.get("activation_id", "")),
		"activation_id": str(reservation.get("activation_id", "")),
		"owner_id": int(reservation.get("owner_id", 0)),
		"sender_seat": int(reservation.get("owner_id", 0)),
		"buff_id": str(reservation.get("buff_id", "")),
		"tier": str(reservation.get("tier", "classic")),
		"target_type": str(reservation.get("target_type", "global")),
		"target_id": reservation.get("target_id", "global"),
		"source_kind": str(reservation.get("source_kind", "vs")),
		"source_use_ordinal": int(reservation.get("source_use_ordinal", 1)),
		"execute_tick": tick
	}

func _on_vs_command_publish_result(payload: Dictionary) -> void:
	if str(payload.get("kind", "")).strip_edges().to_lower() != "buff_activate":
		return
	var activation_id: String = str(payload.get("activation_id", ""))
	var owner_id: int = int(payload.get("owner_id", 0))
	if bool(payload.get("ok", false)):
		var command: Dictionary = payload.get("canonical_command", {}) as Dictionary
		_buff_activation_transactions.mark_canonically_scheduled(
			_buff_match_id(), owner_id, activation_id,
			str(command.get("command_id", "")), int(command.get("execute_tick", -1))
		)
	else:
		_buff_activation_transactions.reject_submission(
			_buff_match_id(), owner_id, activation_id, str(payload.get("reason", "publish_rejected"))
		)
	_persist_buff_activation_runtime_state()

func _execute_canonical_buff_activation(command: Dictionary) -> Dictionary:
	var owner_id: int = int(command.get("owner_id", 0))
	var activation_id: String = str(command.get("activation_id", "")).strip_edges()
	var outcome_key: String = "%s|%d|%s" % [_buff_match_id(), owner_id, activation_id]
	if _buff_canonical_outcomes.has(outcome_key):
		var duplicate: Dictionary = (_buff_canonical_outcomes.get(outcome_key, {}) as Dictionary).duplicate(true)
		duplicate["duplicate"] = true
		return duplicate
	var target_result: Dictionary = _buff_target_resolver.validate_canonical_target(
		_buff_authoritative_game_state(), owner_id, str(command.get("buff_id", "")),
		str(command.get("target_type", "")), command.get("target_id", null)
	)
	if not bool(target_result.get("ok", false)):
		return _finalize_buff_canonical_no_op(command, str(target_result.get("reason", "target_stale")), outcome_key)
	var local_transaction: Dictionary = _buff_activation_transactions.get_transaction(_buff_match_id(), owner_id, activation_id)
	var is_local_transaction: bool = bool(local_transaction.get("ok", false))
	if buff_states.is_empty():
		_init_buff_states()
	var buff_state: BuffState = buff_states.get(owner_id)
	if buff_state == null:
		return _finalize_buff_canonical_no_op(command, "missing_player_state", outcome_key)
	var target_payload: Dictionary = _buff_target_resolver.canonical_target_payload(
		str(command.get("target_type", "global")), command.get("target_id", "global")
	)
	target_payload["owner_id"] = owner_id
	var now_ms: int = int(_authoritative_sim_time_us() / 1000)
	var activation_result: Dictionary = buff_state.intent_activate_buff(
		owner_id, str(command.get("buff_id", "")), str(command.get("tier", "classic")), target_payload, now_ms, -1
	)
	if not bool(activation_result.get("ok", false)):
		return _finalize_buff_canonical_no_op(command, str(activation_result.get("reason", activation_result.get("code", "activation_rejected"))), outcome_key)
	if is_local_transaction:
		var slot_commit: Dictionary = buff_state.commit_slot_use(int(local_transaction.get("slot_index", -1)), now_ms)
		if not bool(slot_commit.get("ok", false)):
			SFLog.error("BUFF_SLOT_USE_COMMIT_FAILED", {"transaction": local_transaction, "result": slot_commit})
	var outcome: Dictionary = {
		"ok": true,
		"status": "executed",
		"reason": "activated",
		"match_id": _buff_match_id(),
		"owner_id": owner_id,
		"activation_id": activation_id,
		"canonical_command_id": str(command.get("command_id", "")),
		"execution_tick": int(command.get("execute_tick", -1)),
		"buff_id": str(command.get("buff_id", "")),
		"target_type": str(command.get("target_type", "")),
		"target_id": command.get("target_id", null)
	}
	if is_local_transaction:
		_buff_activation_transactions.resolve_canonical_outcome(
			_buff_match_id(), owner_id, activation_id, true, "activated",
			str(command.get("command_id", "")), int(command.get("execute_tick", -1))
		)
		var charge_result: Dictionary = _commit_reserved_buff_charge(local_transaction)
		if not bool(charge_result.get("ok", false)):
			SFLog.error("BUFF_RESERVED_COMMIT_FAILED", {"transaction": local_transaction, "result": charge_result})
		else:
			_buff_activation_transactions.mark_committed(_buff_match_id(), owner_id, activation_id)
	_buff_canonical_outcomes[outcome_key] = outcome.duplicate(true)
	_record_match_telemetry_buff_activation(owner_id, str(command.get("buff_id", "")), target_payload, now_ms)
	_sync_buff_effects(now_ms)
	_update_buff_ui()
	mark_render_dirty("buff_activate_canonical")
	_persist_buff_activation_runtime_state()
	return outcome

func _finalize_buff_canonical_no_op(command: Dictionary, reason: String, outcome_key: String) -> Dictionary:
	var outcome: Dictionary = {
		"ok": false,
		"status": "deterministic_no_op",
		"reason": reason,
		"match_id": _buff_match_id(),
		"owner_id": int(command.get("owner_id", 0)),
		"activation_id": str(command.get("activation_id", "")),
		"canonical_command_id": str(command.get("command_id", "")),
		"execution_tick": int(command.get("execute_tick", -1))
	}
	var transaction: Dictionary = _buff_activation_transactions.get_transaction(
		_buff_match_id(), int(command.get("owner_id", 0)), str(command.get("activation_id", ""))
	)
	if bool(transaction.get("ok", false)):
		_buff_activation_transactions.resolve_canonical_outcome(
			_buff_match_id(), int(command.get("owner_id", 0)), str(command.get("activation_id", "")),
			false, reason, str(command.get("command_id", "")), int(command.get("execute_tick", -1))
		)
	_buff_canonical_outcomes[outcome_key] = outcome.duplicate(true)
	_persist_buff_activation_runtime_state()
	return outcome

func _can_commit_reserved_buff_charge(transaction: Dictionary) -> bool:
	if int(transaction.get("owner_id", 0)) != int(active_player_id):
		return true
	var buff_id: String = str(transaction.get("buff_id", ""))
	var source_kind: String = str(transaction.get("source_kind", ""))
	var ordinal: int = int(transaction.get("source_use_ordinal", 1))
	if source_kind == "vs":
		return ordinal == 1 and _buff_inventory_quantity(buff_id) > 0
	var state_now: Dictionary = _ensure_async_buff_contest_state()
	var entry: Dictionary = (state_now.get("charges", {}) as Dictionary).get(buff_id, {}) as Dictionary
	var remaining: int = int(entry.get("remaining", 0))
	var consumed: bool = bool(entry.get("inventory_consumed", false))
	if ordinal == 1:
		return remaining == 2 and not consumed and _buff_inventory_quantity(buff_id) > 0
	return ordinal == 2 and remaining == 1 and consumed

func _commit_reserved_buff_charge(transaction: Dictionary) -> Dictionary:
	if not _can_commit_reserved_buff_charge(transaction):
		return {"ok": false, "reason": "reservation_source_changed"}
	return _commit_runtime_buff_charge(int(transaction.get("owner_id", 0)), str(transaction.get("buff_id", "")))

func _buff_inventory_quantity(buff_id: String) -> int:
	if ProfileManager == null or not ProfileManager.has_method("get_owned_buff_quantity"):
		return 0
	return maxi(0, int(ProfileManager.call("get_owned_buff_quantity", buff_id, "vs")))

func _buff_inventory_revision() -> String:
	if ProfileManager != null and ProfileManager.has_method("get_buff_inventory_revision"):
		return str(ProfileManager.call("get_buff_inventory_revision"))
	return ""

func _buff_authoritative_game_state() -> Object:
	if OpsState != null and OpsState.has_method("get_state"):
		var state_any: Variant = OpsState.call("get_state")
		if state_any is Object:
			return state_any as Object
	return state

func _buff_match_id() -> String:
	var tree: SceneTree = get_tree()
	if tree == null:
		return "local_match"
	for key in ["vs_handshake_session_id", TREE_META_CONTEST_ID, TREE_META_VS_STAGE_RUN_ID, "progressive_run_id"]:
		var value: String = str(tree.get_meta(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return "local:%s:%d" % [current_map_path, match_seed]

func _next_buff_activation_id(pid: int) -> String:
	_buff_activation_counter += 1
	return "%s:%d:%d:%d" % [_buff_match_id(), pid, Time.get_ticks_msec(), _buff_activation_counter]

func _persist_buff_activation_runtime_state() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.set_meta(TREE_META_BUFF_ACTIVATION_RUNTIME_STATE, {
		"transactions": _buff_activation_transactions.export_state(),
		"canonical_outcomes": _buff_canonical_outcomes.duplicate(true),
		"activation_counter": _buff_activation_counter
	})

func _restore_buff_activation_runtime_state() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var raw_any: Variant = tree.get_meta(TREE_META_BUFF_ACTIVATION_RUNTIME_STATE, {})
	if typeof(raw_any) != TYPE_DICTIONARY:
		return
	var raw: Dictionary = raw_any as Dictionary
	var transactions_any: Variant = raw.get("transactions", {})
	if typeof(transactions_any) == TYPE_DICTIONARY:
		_buff_activation_transactions.import_state(transactions_any as Dictionary)
	var outcomes_any: Variant = raw.get("canonical_outcomes", {})
	if typeof(outcomes_any) == TYPE_DICTIONARY:
		_buff_canonical_outcomes = (outcomes_any as Dictionary).duplicate(true)
	_buff_activation_counter = maxi(0, int(raw.get("activation_counter", 0)))

func _runtime_buff_charge_available(pid: int, buff_id: String) -> bool:
	if pid != int(active_player_id):
		return true
	if _is_async_runtime_mode():
		var state_now: Dictionary = _ensure_async_buff_contest_state()
		var charges: Dictionary = state_now.get("charges", {}) as Dictionary
		var entry: Dictionary = charges.get(buff_id, {}) as Dictionary
		if maxi(0, int(entry.get("remaining", 0))) <= 0:
			return false
		if bool(entry.get("inventory_consumed", false)):
			return true
	return ProfileManager != null and ProfileManager.has_method("owns_buff") and bool(ProfileManager.call("owns_buff", buff_id, "async", 1))

func _commit_runtime_buff_charge(pid: int, buff_id: String) -> Dictionary:
	if pid != int(active_player_id):
		return {"ok": true, "remaining": 0, "bot": true}
	if not _is_async_runtime_mode():
		if ProfileManager == null or not ProfileManager.has_method("consume_buff"):
			return {"ok": false, "reason": "inventory_authority_missing"}
		return ProfileManager.call("consume_buff", buff_id, 1, "vs_buff_activation") as Dictionary
	var tree: SceneTree = get_tree()
	if tree == null:
		return {"ok": false, "reason": "missing_tree"}
	var state_now: Dictionary = _ensure_async_buff_contest_state()
	var charges: Dictionary = state_now.get("charges", {}) as Dictionary
	var entry: Dictionary = charges.get(buff_id, {}) as Dictionary
	var remaining: int = maxi(0, int(entry.get("remaining", 0)))
	if remaining <= 0:
		return {"ok": false, "reason": "no_contest_uses"}
	if not bool(entry.get("inventory_consumed", false)):
		if ProfileManager == null or not ProfileManager.has_method("consume_buff"):
			return {"ok": false, "reason": "inventory_authority_missing"}
		var consume_result: Dictionary = ProfileManager.call("consume_buff", buff_id, 1, "async_buff_first_activation") as Dictionary
		if not bool(consume_result.get("ok", false)):
			return consume_result
		entry["inventory_consumed"] = true
	remaining -= 1
	entry["remaining"] = remaining
	charges[buff_id] = entry
	state_now["charges"] = charges
	tree.set_meta(TREE_META_ASYNC_BUFF_CONTEST_STATE, state_now)
	return {"ok": true, "buff_id": buff_id, "remaining": remaining, "uses_total": 2}

func _supported_runtime_classic_buff_ids(excluded_ids: Array[String]) -> Array[String]:
	var excluded_lookup: Dictionary = {}
	for buff_id in excluded_ids:
		excluded_lookup[str(buff_id)] = true
	var out: Array[String] = []
	var all_buffs: Array = BuffCatalog.list_all()
	for buff_v in all_buffs:
		if typeof(buff_v) != TYPE_DICTIONARY:
			continue
		var buff: Dictionary = buff_v as Dictionary
		var buff_id: String = str(buff.get("id", "")).strip_edges()
		if buff_id == "":
			continue
		if excluded_lookup.has(buff_id):
			continue
		var tier: String = str(buff.get("tier", "classic")).to_lower()
		if tier != "classic":
			continue
		var effects_any: Variant = buff.get("effects", [])
		if typeof(effects_any) != TYPE_ARRAY:
			continue
		if not _buff_effects_supported_for_runtime(effects_any as Array):
			continue
		if out.has(buff_id):
			continue
		out.append(buff_id)
	out.sort()
	return out

func _buff_effects_supported_for_runtime(effects: Array) -> bool:
	if effects.is_empty():
		return false
	var has_supported: bool = false
	for effect_v in effects:
		if typeof(effect_v) != TYPE_DICTIONARY:
			return false
		var effect: Dictionary = effect_v as Dictionary
		var effect_type: String = str(effect.get("type", "")).strip_edges()
		if effect_type == "":
			return false
		if not bool(RUNTIME_SUPPORTED_BUFF_EFFECT_TYPES.get(effect_type, false)):
			return false
		has_supported = true
	return has_supported

func _pick_seeded_unique_ids(pool: Array[String], pid: int, needed: int) -> Array[String]:
	var out: Array[String] = []
	if pool.is_empty() or needed <= 0:
		return out
	var start_idx: int = 0
	if pool.size() > 0:
		start_idx = int(abs(match_seed) + (pid * 97)) % pool.size()
	var cursor: int = start_idx
	var attempts: int = 0
	var max_attempts: int = maxi(pool.size() * 3, needed * 3)
	while out.size() < needed and attempts < max_attempts:
		var candidate: String = pool[cursor % pool.size()]
		if not out.has(candidate):
			out.append(candidate)
		cursor += 1
		attempts += 1
	return out

func _reset_buff_states() -> void:
	if _is_crucible_match():
		_reset_buff_runtime()
		return
	if not buffs_enabled:
		return
	if buff_states.is_empty():
		_init_buff_states()
	for buff_state in buff_states.values():
		buff_state.reset_for_match()
	_reset_buff_runtime()

func _update_buff_states() -> void:
	if _is_crucible_match():
		_reset_buff_runtime()
		return
	if not buffs_enabled:
		return
	if buff_states.is_empty():
		return
	var now_ms: int = int(_authoritative_sim_time_us() / 1000)
	for buff_state in buff_states.values():
		buff_state.update(now_ms)
	_sync_buff_effects(now_ms)

func _enter_overtime() -> void:
	overtime_active = true
	hurry_mode = true
	audio_hurry_pitch = 1.15
	if floor_influence_system != null:
		floor_influence_system.notify_overtime_started()
	if buffs_enabled:
		for buff_state in buff_states.values():
			buff_state.unlock_third_slot()
			buff_state.enable_tap_to_top()
	dbg("SF: OVERTIME start (clock visible, slot3 unlocked, tap-to-top enabled)")
	SFLog.info("OVERTIME: start")

func _reset_match_stats() -> void:
	units_landed = {1: 0, 2: 0, 3: 0, 4: 0}
	tutorial_arrivals_by_hive_owner.clear()
	tower_control_ms = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0}
	if tower_system != null:
		tower_system.reset_control_ms()
	barracks_control_ms = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0}
	capture_count = 0
	error_count = 0

func _reset_buff_runtime() -> void:
	buff_active_slots.clear()
	buff_instances.clear()
	buff_mods.clear()
	for pid in [1, 2, 3, 4]:
		buff_active_slots[pid] = {}
		buff_instances[pid] = {}
		buff_mods[pid] = {
			"unit_speed_pct": 0.0,
			"hive_prod_time_pct": 0.0,
			"tower_fire_rate_pct": 0.0,
			"lane_slow_pct": 0.0,
			"lane_insight": 0
		}

func _authoritative_sim_time_us() -> int:
	if unit_system != null:
		return int(unit_system.sim_time_us)
	return int(sim_time_us)

func _sync_buff_effects(now_ms: int) -> void:
	for pid_v in buff_states.keys():
		var pid: int = int(pid_v)
		var buff_state: BuffState = buff_states[pid]
		var slot_map: Dictionary = buff_active_slots.get(pid, {})
		for slot_index in range(buff_state.slots.size()):
			var slot: Dictionary = buff_state.slots[slot_index]
			var is_active: bool = bool(slot.get("active", false))
			if is_active:
				if not slot_map.has(slot_index):
					var buff_id: String = str(slot.get("id", ""))
					if buff_id != "":
						_apply_buff(pid, buff_id, now_ms)
						slot_map[slot_index] = buff_id
			else:
				if slot_map.has(slot_index):
					var ended_id: String = str(slot_map[slot_index])
					if ended_id != "":
						_remove_buff(pid, ended_id)
					slot_map.erase(slot_index)
		buff_active_slots[pid] = slot_map

func _apply_buff(pid: int, buff_id: String, now_ms: int) -> void:
	if _is_crucible_match():
		return
	var buff: Dictionary = BuffCatalog.get_buff(buff_id)
	if buff.is_empty():
		return
	var stacking: String = str(buff.get("stacking", BuffCatalog.stacking_default()))
	var instances: Dictionary = buff_instances.get(pid, {})
	var entry: Dictionary = instances.get(buff_id, {})
	if stacking == "additive":
		_apply_buff_effects(pid, buff.get("effects", []), 1.0)
		entry["count"] = int(entry.get("count", 0)) + 1
		entry["stacking"] = stacking
		entry["effects"] = buff.get("effects", [])
		instances[buff_id] = entry
		buff_instances[pid] = instances
		return
	if entry.is_empty():
		_apply_buff_effects(pid, buff.get("effects", []), 1.0)
	entry["count"] = int(entry.get("count", 0)) + 1
	entry["stacking"] = stacking
	entry["effects"] = buff.get("effects", [])
	instances[buff_id] = entry
	buff_instances[pid] = instances

func _remove_buff(pid: int, buff_id: String) -> void:
	var instances: Dictionary = buff_instances.get(pid, {})
	if not instances.has(buff_id):
		return
	var entry: Dictionary = instances[buff_id]
	var stacking: String = str(entry.get("stacking", "refresh"))
	if stacking == "additive":
		_apply_buff_effects(pid, entry.get("effects", []), -1.0)
		entry["count"] = int(entry.get("count", 0)) - 1
		if int(entry.get("count", 0)) <= 0:
			instances.erase(buff_id)
		else:
			instances[buff_id] = entry
		buff_instances[pid] = instances
		return
	entry["count"] = int(entry.get("count", 0)) - 1
	if int(entry.get("count", 0)) <= 0:
		_apply_buff_effects(pid, entry.get("effects", []), -1.0)
		instances.erase(buff_id)
	else:
		instances[buff_id] = entry
	buff_instances[pid] = instances

func _apply_buff_effects(pid: int, effects: Array, sign: float) -> void:
	if _is_crucible_match():
		return
	if effects.is_empty():
		return
	if not buff_mods.has(pid):
		return
	var mods: Dictionary = buff_mods[pid]
	for effect_v in effects:
		if typeof(effect_v) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_v
		var t: String = str(effect.get("type", ""))
		match t:
			"swarm_speed_pct":
				mods["unit_speed_pct"] = float(mods.get("unit_speed_pct", 0.0)) + float(effect.get("value", 0.0)) * sign
			"hive_production_time_pct":
				mods["hive_prod_time_pct"] = float(mods.get("hive_prod_time_pct", 0.0)) + float(effect.get("value", 0.0)) * sign
			"tower_fire_rate_pct":
				mods["tower_fire_rate_pct"] = float(mods.get("tower_fire_rate_pct", 0.0)) + float(effect.get("value", 0.0)) * sign
			"lane_slow_pct":
				mods["lane_slow_pct"] = float(mods.get("lane_slow_pct", 0.0)) + float(effect.get("value", BUFF_LANE_SLOW_PCT_DEFAULT)) * sign
			"lane_insight":
				mods["lane_insight"] = int(mods.get("lane_insight", 0)) + int(sign)
	buff_mods[pid] = mods

func _buff_mod(pid: int, key: String) -> float:
	if not buff_mods.has(pid):
		return 0.0
	return float(buff_mods[pid].get(key, 0.0))

func _buff_flag(pid: int, key: String) -> bool:
	if not buff_mods.has(pid):
		return false
	return int(buff_mods[pid].get(key, 0)) > 0

func _lane_insight_active(pid: int) -> bool:
	return _buff_flag(pid, "lane_insight")

func get_buff_ui_snapshot() -> Dictionary:
	var now_ms: int = int(_authoritative_sim_time_us() / 1000)
	var snapshot: Dictionary = {
		"buffs_enabled": bool(buffs_enabled) and not _is_crucible_match(),
		"active_player_id": int(active_player_id),
		"inventory_revision": _buff_inventory_revision(),
		"overtime_active": bool(overtime_active),
		"sim_time_ms": now_ms,
		"players": {}
	}
	if not buffs_enabled or _is_crucible_match():
		return snapshot
	if buff_states.is_empty():
		_init_buff_states()
	var players: Dictionary = {}
	for pid in [1, 2, 3, 4]:
		var buff_state: BuffState = buff_states.get(pid)
		if buff_state == null:
			continue
		players[pid] = _buff_ui_player_snapshot(pid, buff_state, now_ms)
	snapshot["players"] = players
	return snapshot

func _buff_ui_player_snapshot(pid: int, buff_state: BuffState, now_ms: int) -> Dictionary:
	var slots_out: Array = []
	for i in range(buff_state.slots.size()):
		var slot: Dictionary = buff_state.slots[i]
		var buff_id: String = str(slot.get("id", ""))
		var buff_def: Dictionary = BuffCatalog.get_buff(buff_id)
		var tier: String = str(slot.get("tier", buff_def.get("tier", "classic")))
		var ends_ms: int = int(slot.get("ends_ms", 0))
		var active: bool = bool(slot.get("active", false))
		var consumed: bool = bool(slot.get("consumed", false))
		var uses_remaining: int = maxi(0, int(slot.get("uses_remaining", 0)))
		var uses_total: int = maxi(1, int(slot.get("uses_total", 1)))
		var remaining_ms: int = 0
		if active:
			remaining_ms = max(0, ends_ms - now_ms)
		slots_out.append({
			"index": i,
			"id": buff_id,
			"inventory_id": str(slot.get("inventory_id", buff_id)),
			"name": str(buff_def.get("name", buff_id)),
			"tier": tier,
			"category": str(buff_def.get("category", "unknown")),
			"icon_path": str(buff_def.get("icon_path", "")),
			"locked": i >= int(buff_state.slots_active),
			"active": active,
			"consumed": consumed,
			"uses_remaining": uses_remaining,
			"uses_total": uses_total,
			"one_use_spent": uses_total == 2 and uses_remaining == 1,
			"ends_ms": ends_ms,
			"remaining_ms": remaining_ms
		})
	return {
		"pid": pid,
		"slots_active": int(buff_state.slots_active),
		"tap_to_top_enabled": bool(buff_state.tap_to_top_enabled),
		"slots": slots_out
	}

func request_buff_drop(pid: int, slot_index: int, world_pos: Vector2) -> Dictionary:
	# Compatibility-only wrapper. Production PlayerBuffStrip release uses the
	# stable-ID resolve_buff_release_candidate -> submit_buff_activation path.
	var arena_local_pos: Vector2 = map_root.to_local(world_pos) if map_root != null else world_pos
	var candidate: Dictionary = resolve_buff_release_candidate(pid, slot_index, arena_local_pos)
	if not bool(candidate.get("ok", false)):
		return candidate
	return submit_buff_activation(
		pid,
		slot_index,
		str(candidate.get("target_type", "global")),
		candidate.get("target_id", "global")
	)

func _record_match_telemetry_buff_activation(
	pid: int,
	buff_id: String,
	target_ctx_any: Variant,
	now_ms: int
) -> void:
	if not _telemetry_active:
		return
	if _match_telemetry_collector == null:
		return
	if not _match_telemetry_collector.has_method("record_buff_activation"):
		return
	var safe_pid: int = maxi(0, pid)
	if safe_pid <= 0:
		return
	var clean_buff_id: String = buff_id.strip_edges()
	if clean_buff_id == "":
		return
	var target_ctx: Dictionary = {}
	if typeof(target_ctx_any) == TYPE_DICTIONARY:
		target_ctx = (target_ctx_any as Dictionary).duplicate(true)
	var buff_def: Dictionary = BuffCatalog.get_buff(clean_buff_id)
	var canonical_id: String = str(buff_def.get("canonical_id", clean_buff_id)).strip_edges()
	if canonical_id == "":
		canonical_id = clean_buff_id
	var scope: String = _telemetry_scope_from_buff(canonical_id, buff_def)
	var target_id: Variant = _telemetry_target_id_for_scope(scope, target_ctx)
	_match_telemetry_collector.call(
		"record_buff_activation",
		maxi(0, now_ms),
		safe_pid,
		canonical_id,
		scope,
		target_id
	)

func _telemetry_scope_from_buff(canonical_buff_id: String, buff_def: Dictionary) -> String:
	var canonical_id: String = canonical_buff_id.strip_edges().to_upper()
	var category: String = str(buff_def.get("category", "")).strip_edges().to_lower()
	var target_type: String = str(buff_def.get("target_type", "")).strip_edges().to_lower()
	if target_type == BuffDefinitions.TARGET_HIVE:
		return "HIVE"
	if target_type == BuffDefinitions.TARGET_LANE:
		return "LANE"
	if category == BuffDefinitions.CATEGORY_UNIT:
		return "UNIT"
	if category == BuffDefinitions.CATEGORY_LANE:
		return "LANE"
	if category == BuffDefinitions.CATEGORY_HIVE:
		if canonical_id == BuffDefinitions.HIVE_GLOBAL_PRODUCTION_BOOST or canonical_id == BuffDefinitions.HIVE_SHIELD_GLOBAL:
			return "GLOBAL"
		return "HIVE"
	return "GLOBAL"

func _telemetry_target_id_for_scope(scope: String, target_ctx: Dictionary) -> Variant:
	var scope_key: String = scope.strip_edges().to_upper()
	if scope_key == "HIVE" or scope_key == "UNIT":
		var hive_id: int = int(target_ctx.get("hive_id", -1))
		if hive_id > 0:
			return hive_id
	if scope_key == "LANE":
		var lane_id: int = int(target_ctx.get("lane_id", -1))
		if lane_id > 0:
			return lane_id
	return ""

func _buff_target_context_from_world(world_pos: Vector2) -> Dictionary:
	var local_pos: Vector2 = world_pos
	if map_root != null:
		local_pos = map_root.to_local(world_pos)
	var hive_id: int = _hive_id_at_point(local_pos)
	var lane_hit: Dictionary = _pick_lane_hit(local_pos)
	var lane_id: int = int(lane_hit.get("lane_id", -1))
	var barracks_id: int = _barracks_id_at_point(local_pos)
	var kind: String = "world"
	if hive_id > 0:
		kind = "hive"
	elif barracks_id > 0:
		kind = "barracks"
	elif bool(lane_hit.get("ok", false)):
		kind = "lane"
	return {
		"kind": kind,
		"world_pos": world_pos,
		"local_pos": local_pos,
		"grid_pos": _cell_from_point(local_pos),
		"hive_id": hive_id,
		"lane_id": lane_id,
		"lane_t": float(lane_hit.get("t", 0.0)),
		"barracks_id": barracks_id,
		"tower_id": -1
	}


func _try_activate_buff_slot(pid: int, slot_index: int) -> void:
	# Compatibility endpoint for ArenaApi. Slot-only activation cannot provide a
	# stable target and must never bypass the production release pipeline.
	SFLog.info("BUFF_STABLE_TARGET_REQUIRED", {
		"pid": pid,
		"slot_index": slot_index,
		"reason": "slot_only_activation_disabled"
	})

func _reset_sim_state() -> void:
	units.clear()
	swarm_packets.clear()
	_stop_all_swarm_sfx()
	debris.clear()
	unit_id_counter = 1
	swarm_id_counter = 1
	debris_id_counter = 1
	tick_accum = 0.0
	events.clear()
	_tower_shot_sfx_counts.clear()
	_hive_switch_sfx_played_ms.clear()
	sim_time_us = 0
	winner_id = -1
	end_reason = ""
	game_over = false
	_match_end_handled = false
	_match_record_committed = false
	_post_match_action_taken = false
	_post_match_render_frozen = false
	_stop_post_match_song()
	_end_post_match_settle_if_supported()
	hurry_mode = false
	audio_hurry_pitch = 1.0
	overtime_active = false
	sim_running = false
	match_seed = _compute_match_seed()
	_seed_game_rng()
	tie_history.clear()
	tie_cache.clear()
	if audio_system != null:
		audio_system.reset()
	contest_last_log_us.clear()
	arrival_history.clear()
	_reset_match_stats()
	_reset_buff_states()
	barracks_select_id = -1
	barracks_select_pid = -1
	barracks_select_targets.clear()
	barracks_select_changed = false
	_clear_selection()
	_clear_tap_state()
	_reset_drag()
	if outcome_overlay != null:
		outcome_overlay.visible = false
		if outcome_overlay.has_method("clear_post_match_summary"):
			outcome_overlay.call("clear_post_match_summary")
	if timer_label != null:
		timer_label.visible = false
	_timer_last_seconds = -1
	_timer_ui_logged = false
	_timer_branch_logged = false
	_timer_label_bind_logged = false
	_prematch_remaining_ms_f = 0.0
	_prematch_last_sec = -1
	_prematch_records_faded = false
	_prematch_countdown_faded = false
	_prematch_final_fit_requested = false
	_prematch_identity_card_faded = false
	_prematch_hive_focus_started = false
	_prematch_countdown_return_started = false
	_prematch_ui_state_logged = false
	_clear_prematch_pulses()
	_match_started = false
	_ctf_click_consumed = false
	_ctf_move_armed = false
	_telemetry_active = false
	_post_match_analysis_summary.clear()
	_post_match_telemetry_path = ""
	if _match_telemetry_collector != null and _match_telemetry_collector.has_method("reset"):
		_match_telemetry_collector.call("reset")
	if _prematch_overlay != null:
		_prematch_overlay.visible = false
	if selection_hud != null:
		selection_hud.clear()
	if buffs_label != null:
		buffs_label.visible = false
	if tie_toast != null:
		tie_toast.visible = false
	tie_toast_ms = 0.0
	_refresh_capture_flag_move_button()

func _seed_game_rng() -> void:
	if DEV_STATE_CHECKS:
		assert(game_rng != null, "Gameplay logic must not call global rand* functions.")
	game_rng.seed = match_seed

func _init_towers() -> void:
	var structure_sets: Array = []
	var structure_positions: Array = []
	var t1_required: Array = _structure_required_hives_for(
		Vector2i(5, 2),
		[1, 2, 3],
		structure_sets,
		structure_positions
	)
	structure_sets.append(t1_required)
	if t1_required.size() >= BARRACKS_MIN_REQ:
		structure_positions.append(_structure_center_for_required(t1_required, _cell_center(Vector2i(5, 2))))
	var t2_required: Array = _structure_required_hives_for(
		Vector2i(9, 4),
		[4, 5, 6],
		structure_sets,
		structure_positions
	)
	structure_sets.append(t2_required)
	if t2_required.size() >= BARRACKS_MIN_REQ:
		structure_positions.append(_structure_center_for_required(t2_required, _cell_center(Vector2i(9, 4))))
	towers = [
		{
			"id": 1,
			"node_id": 1,
			"grid_pos": Vector2i(5, 2),
			"required_hive_ids": t1_required,
			"active": false,
			"owner_id": 0,
			"tier": 1,
			"shot_accum_ms": 0.0
		},
		{
			"id": 2,
			"node_id": 2,
			"grid_pos": Vector2i(9, 4),
			"required_hive_ids": t2_required,
			"active": false,
			"owner_id": 0,
			"tier": 1,
			"shot_accum_ms": 0.0
		}
	]
	if state != null:
		state.structure_by_node_id.clear()
		state.structure_owner_by_node_id.clear()
		for tower in towers:
			var node_id: int = int(tower.get("node_id", tower.get("id", -1)))
			if node_id != -1:
				state.structure_by_node_id[node_id] = "tower"
				state.structure_owner_by_node_id[node_id] = int(tower.get("owner_id", 0))

func _init_barracks() -> void:
	var structure_sets: Array = []
	var structure_positions: Array = []
	for tower in towers:
		var tower_required: Array = tower.get("required_hive_ids", [])
		structure_sets.append(tower_required)
		var tower_grid_pos: Vector2i = tower.get("grid_pos", Vector2i.ZERO)
		if tower_required.size() >= BARRACKS_MIN_REQ:
			structure_positions.append(_structure_center_for_required(tower_required, _cell_center(tower_grid_pos)))
	var b1_required: Array = _structure_required_hives_for(
		Vector2i(2, 1),
		[1, 2, 3],
		structure_sets,
		structure_positions
	)
	structure_sets.append(b1_required)
	if b1_required.size() >= BARRACKS_MIN_REQ:
		structure_positions.append(_structure_center_for_required(b1_required, _cell_center(Vector2i(2, 1))))
	barracks = [
		{
			"id": 1,
			"grid_pos": Vector2i(2, 1),
			"required_hive_ids": b1_required,
			"control_hive_ids": b1_required.duplicate(),
			"route_targets": [],
			"route_hive_ids": [],
			"route_mode": "round_robin",
			"route_cursor": 0,
			"active": false,
			"owner_id": 0,
			"tier": 1,
			"spawn_accum_ms": 0.0,
			"rr_index": 0,
			"preferred_targets": []
		}
	]

func _is_dev_mouse_override() -> bool:
	return _input_bridge_utils.is_dev_mouse_override()

func _dev_mouse_pid(event: InputEventMouseButton) -> int:
	if _input_bridge_utils.is_dev_mouse_override() and event.button_index == MOUSE_BUTTON_LEFT:
		if active_player_id >= 1 and active_player_id <= 4:
			return active_player_id
	return _input_bridge_utils.dev_mouse_pid(event)

func _mouse_world_pos() -> Vector2:
	return _screen_to_world(get_viewport().get_mouse_position())

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp: Viewport = get_viewport()
	return _input_bridge_utils.screen_to_world(vp, get_global_mouse_position(), screen_pos)

func _unhandled_input(event: InputEvent) -> void:
	var buff_pointer: Dictionary = _buff_pointer_identity_for_event(event)
	if not buff_pointer.is_empty() and _shell_suppresses_buff_pointer_event(
		str(buff_pointer.get("pointer_kind", "")),
		int(buff_pointer.get("pointer_id", -1)),
		str(buff_pointer.get("phase", ""))
	):
		var event_viewport: Viewport = get_viewport()
		if event_viewport != null:
			event_viewport.set_input_as_handled()
		return
	if state == null:
		return
	if input_system == null or api == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	if _controls_hint_controller != null and _controls_hint_controller.consume_dismiss_input(event, get_viewport()):
		return
	if event is InputEventMouseButton:
		if OS.has_feature("mobile") and (now_ms - _last_screen_pointer_ms) <= TOUCH_MOUSE_SUPPRESS_MS:
			get_viewport().set_input_as_handled()
			return
		var mb := event as InputEventMouseButton
		if _input_bridge_utils.is_player_pointer_button(mb.button_index):
			var wp: Vector2 = _screen_to_world(mb.position)
			var lp: Vector2 = map_root.to_local(wp)
			_send_pointer_event(mb.pressed, mb.button_index, lp, false, wp, mb.position)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		if OS.has_feature("mobile") and (now_ms - _last_screen_pointer_ms) <= TOUCH_MOUSE_SUPPRESS_MS:
			get_viewport().set_input_as_handled()
			return
		var mm := event as InputEventMouseMotion
		var wp: Vector2 = _screen_to_world(mm.position)
		var lp: Vector2 = map_root.to_local(wp)
		_send_pointer_event(false, 0, lp, true, wp, mm.position)
		return
	if event is InputEventScreenTouch:
		_last_screen_pointer_ms = now_ms
		var st := event as InputEventScreenTouch
		var wp: Vector2 = _screen_to_world(st.position)
		var lp: Vector2 = map_root.to_local(wp)
		_send_pointer_event(st.pressed, MOUSE_BUTTON_LEFT, lp, false, wp, st.position, true, int(st.index))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		_last_screen_pointer_ms = now_ms
		var sd := event as InputEventScreenDrag
		var wp: Vector2 = _screen_to_world(sd.position)
		var lp: Vector2 = map_root.to_local(wp)
		_send_pointer_event(false, 0, lp, true, wp, sd.position, true, int(sd.index))
		return
	input_system.handle_input(event, api)


func _buff_pointer_identity_for_event(event: InputEvent) -> Dictionary:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		return {
			"pointer_kind": "touch",
			"pointer_id": int(touch.index),
			"phase": "press" if touch.pressed else "release"
		}
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		return {"pointer_kind": "touch", "pointer_id": int(drag.index), "phase": "move"}
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return {}
		return {"pointer_kind": "mouse", "pointer_id": 0, "phase": "press" if button.pressed else "release"}
	if event is InputEventMouseMotion:
		return {"pointer_kind": "mouse", "pointer_id": 0, "phase": "move"}
	return {}


func _shell_suppresses_buff_pointer_event(pointer_kind: String, pointer_id: int, phase: String) -> bool:
	var shell: Node = get_node_or_null("/root/Shell")
	if shell == null or not shell.has_method("should_suppress_buff_pointer_event"):
		return false
	return bool(shell.call("should_suppress_buff_pointer_event", pointer_kind, pointer_id, phase))

func _pointer_local_from_screen(screen_pos: Vector2) -> Vector2:
	return _input_bridge_utils.pointer_local_from_screen(
		get_viewport(),
		map_root,
		get_global_mouse_position(),
		screen_pos
	)

func _send_pointer_event(pressed: bool, button_index: int, local_pos: Vector2, is_motion: bool = false, world_pos: Vector2 = Vector2.ZERO, screen_pos: Vector2 = Vector2.ZERO, is_touch: bool = false, touch_index: int = -1) -> void:
	var hive_id: int = api.pick_hive_id(world_pos)
	if hive_id <= 0:
		hive_id = api.hive_id_at_point(local_pos)
	var lane_hit: LaneData = api.pick_lane(local_pos)
	var lane_id: int = lane_hit.id if lane_hit != null else -1
	var ev_type: String = "motion" if is_motion else ("press" if pressed else "release")
	if ev_type == "press":
		if _try_handle_capture_flag_press(local_pos, button_index):
			_ctf_click_consumed = true
			return
	elif ev_type == "release":
		if _ctf_click_consumed:
			_ctf_click_consumed = false
			return
		if _ctf_move_armed:
			return
	elif ev_type == "motion" and _ctf_move_armed:
		return
	if not is_motion:
		SFLog.allow_tag("INPUT_POINTER_EVENT")
		SFLog.warn("INPUT_POINTER_EVENT", {
			"type": ev_type,
			"button": button_index,
			"hive_id": hive_id,
			"lane_id": lane_id,
			"local_pos": local_pos,
			"world_pos": world_pos
		}, "", 0)
	var ev: Dictionary = {
		"type": ev_type,
		"button": button_index,
		"local_pos": local_pos,
		"world_pos": world_pos,
		"screen_pos": screen_pos,
		"is_touch": is_touch,
		"touch_index": touch_index,
		"hive_id": hive_id,
		"lane_id": lane_id
	}
	if _tutorial_launch_section() == TUTORIAL_CONTROLS_ID and _tutorial_controls_controller != null:
		if not _tutorial_controls_controller.should_allow_pointer_event(ev, state):
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			return
	input_system.handle_pointer_event(ev, api)

func _on_map_left_click(lp: Vector2, event: InputEventMouseButton) -> void:
	if has_method("_handle_left_click_local"):
		call("_handle_left_click_local", lp)
		return
	_handle_press(lp, _dev_mouse_pid(event), MOUSE_BUTTON_LEFT)

func _on_map_right_click(lp: Vector2, event: InputEventMouseButton) -> void:
	if has_method("_handle_right_click_local"):
		call("_handle_right_click_local", lp)
		return
	_handle_press(lp, _dev_mouse_pid(event), MOUSE_BUTTON_RIGHT)

func _on_map_left_release(lp: Vector2, event: InputEventMouseButton) -> void:
	_handle_release(lp, _dev_mouse_pid(event))

func _on_map_right_release(lp: Vector2, event: InputEventMouseButton) -> void:
	_handle_release(lp, _dev_mouse_pid(event))

func _handle_model_drag(event: InputEvent) -> bool:
	if model.is_empty():
		return false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var is_primary_click := _input_bridge_utils.is_player_pointer_button(mb.button_index)
		if not is_primary_click:
			return false
		var wp: Vector2 = _screen_to_world(mb.position)
		var lp: Vector2 = map_root.to_local(wp)
		if mb.pressed:
			var from_id: String = _find_hive_at_local(lp)
			if not from_id.is_empty():
				_drag_from_id = from_id
				_drag_from_wp = lp
				_drag_active = false
				SFLog.trace("DRAG: down", {"from_id": from_id, "lp": lp})
				get_viewport().set_input_as_handled()
				return true
		elif not _drag_from_id.is_empty():
			var to_id: String = _find_hive_at_local(lp)
			SFLog.trace("DRAG: up", {"to_id": to_id, "lp": lp, "active": _drag_active})
			if not to_id.is_empty() and to_id != _drag_from_id:
				_toggle_lane(_drag_from_id, to_id)
			_drag_from_id = ""
			_drag_active = false
			get_viewport().set_input_as_handled()
			return true
	elif event is InputEventMouseMotion and not _drag_from_id.is_empty():
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var wp: Vector2 = _screen_to_world(mm.position)
		var lp: Vector2 = map_root.to_local(wp)
		if not _drag_active and lp.distance_to(_drag_from_wp) >= DRAG_DEADZONE_PX:
			_drag_active = true
		get_viewport().set_input_as_handled()
		return true
	return false

func _cell_size_for_model() -> float:
	var cell_v: Variant = (self as Node).get("CELL_SIZE")
	return float(cell_v) if cell_v != null else 64.0

func _hive_radius_px_for_model(cell: float) -> float:
	var radius_v: Variant = (self as Node).get("HIVE_RADIUS_PX")
	return float(radius_v) if radius_v != null else cell * 0.42

func _find_hive_at_local(lp: Vector2) -> String:
	var cell: float = _cell_size_for_model()
	var radius: float = _hive_radius_px_for_model(cell)
	var hives: Array = model.get("hives", []) as Array
	for hive in hives:
		if typeof(hive) != TYPE_DICTIONARY:
			continue
		var hd: Dictionary = hive as Dictionary
		var id: String = str(hd.get("id", ""))
		if id.is_empty():
			continue
		var gx: float = float(hd.get("x", 0.0))
		var gy: float = float(hd.get("y", 0.0))
		if hd.has("grid_pos") and typeof(hd["grid_pos"]) == TYPE_ARRAY:
			var gp: Array = hd["grid_pos"] as Array
			if gp.size() >= 2:
				gx = float(gp[0])
				gy = float(gp[1])
		var hp: Vector2
		if grid_spec != null:
			hp = grid_spec.origin + Vector2((gx + grid_coord_render_offset) * grid_spec.cell_size, (gy + grid_coord_render_offset) * grid_spec.cell_size)
		else:
			hp = Vector2((gx + grid_coord_render_offset) * cell, (gy + grid_coord_render_offset) * cell)
		if hp.distance_to(lp) <= radius:
			return id
	return ""

func _toggle_lane(from_id: String, to_id: String) -> void:
	var lanes: Array = model.get("lanes", []) as Array
	var lanes_before: int = lanes.size()
	var found_index: int = -1
	var out_count: int = 0
	var from_id_int: int = 0
	var to_id_int: int = 0
	if str(from_id).is_valid_int():
		from_id_int = int(from_id)
	if str(to_id).is_valid_int():
		to_id_int = int(to_id)
	for i in range(lanes.size()):
		var l: Variant = lanes[i]
		if typeof(l) != TYPE_DICTIONARY:
			continue
		var ld: Dictionary = l as Dictionary
		if str(ld.get("from", "")) == from_id:
			out_count += 1
		if str(ld.get("from", "")) == from_id and str(ld.get("to", "")) == to_id:
			found_index = i
			break
	if ENABLE_OUTGOING_LANE_BUDGET and found_index == -1 and out_count >= MAX_OUT_LANES:
		SFLog.trace("LANE: blocked (cap)", {"from": from_id, "cap": MAX_OUT_LANES})
		return
	if found_index >= 0:
		SFLog.trace("LANE: exists", {"from": from_id, "to": to_id})
	else:
		var nd: Dictionary = {"from": from_id, "to": to_id}
		lanes.append(nd)
		SFLog.trace("LANE: added", {"from": from_id, "to": to_id})
	model["lanes"] = lanes
	render_version += 1
	_render_dirty = true
	if state != null:
		var prev_send: Dictionary = {}
		for prev_lane in state.lanes:
			var key_prev: String = "%d:%d" % [prev_lane.a_id, prev_lane.b_id]
			prev_send[key_prev] = {
				"send_a": prev_lane.send_a,
				"send_b": prev_lane.send_b
			}
		var new_state_lanes: Array[LaneData] = []
		var lane_id := 1
		for lane_v in lanes:
			if typeof(lane_v) != TYPE_DICTIONARY:
				continue
			var ld: Dictionary = lane_v as Dictionary
			var a_v: Variant = ld.get("from", ld.get("a_id", 0))
			var b_v: Variant = ld.get("to", ld.get("b_id", 0))
			var a_id: int = 0
			var b_id: int = 0
			if a_v is int:
				a_id = int(a_v)
			else:
				var a_str: String = str(a_v)
				if a_str.is_valid_int():
					a_id = int(a_str)
			if b_v is int:
				b_id = int(b_v)
			else:
				var b_str: String = str(b_v)
				if b_str.is_valid_int():
					b_id = int(b_str)
			if a_id <= 0 or b_id <= 0 or a_id == b_id:
				continue
			var lane_data := LaneData.new(lane_id, a_id, b_id, 1, false, false)
			var key_now: String = "%d:%d" % [a_id, b_id]
			if prev_send.has(key_now):
				var prev: Dictionary = prev_send[key_now]
				lane_data.send_a = bool(prev.get("send_a", false))
				lane_data.send_b = bool(prev.get("send_b", false))
			if a_id == from_id_int and b_id == to_id_int:
				lane_data.send_a = true
				SFLog.trace("LANE_SEND", {
					"a_id": a_id,
					"b_id": b_id,
					"send_a": lane_data.send_a,
					"send_b": lane_data.send_b,
					"drag_from": from_id,
					"drag_to": to_id
				})
			elif a_id == to_id_int and b_id == from_id_int:
				lane_data.send_b = true
				SFLog.trace("LANE_SEND", {
					"a_id": a_id,
					"b_id": b_id,
					"send_a": lane_data.send_a,
					"send_b": lane_data.send_b,
					"drag_from": from_id,
					"drag_to": to_id
				})
			new_state_lanes.append(lane_data)
			lane_id += 1
		state.lanes = new_state_lanes
		state.rebuild_indexes()
		SFLog.trace("LANEDBG: state.lanes", {"count": state.lanes.size()})
		if not state.lanes.is_empty():
			SFLog.trace("LANEDBG:last", {"lane": state.lanes[state.lanes.size() - 1]})
		var outgoing: Array = state.outgoing_by_hive.get(from_id_int, []) as Array
		SFLog.trace("LANEADJ: rebuilt outgoing", {
			"hive_id": from_id_int,
			"count": outgoing.size(),
			"total_lanes": state.lanes.size()
		})
	var lanes_after: int = lanes.size()
	SFLog.trace("DRAG: from", {
		"from_id": from_id,
		"to_id": to_id,
		"lanes_before": lanes_before,
		"lanes_after": lanes_after
	})
	_push_render_model()

func _find_hive_at_cell(cell: Vector2i) -> HiveData:
	return state.find_hive_at_cell(cell)

func _find_hive_by_id(hive_id: int) -> HiveData:
	return state.find_hive_by_id(hive_id)

func _pick_lane(local_pos: Vector2) -> LaneData:
	var best_lane: LaneData = null
	var best_dist: float = INF
	for lane in state.lanes:
		var a: HiveData = _find_hive_by_id(lane.a_id)
		var b: HiveData = _find_hive_by_id(lane.b_id)
		if a == null or b == null:
			continue
		var a_pos: Vector2 = _cell_center(a.grid_pos)
		var b_pos: Vector2 = _cell_center(b.grid_pos)
		var dist: float = _distance_point_to_segment(local_pos, a_pos, b_pos)
		if dist <= LANE_HIT_DIST_PX and dist < best_dist:
			best_dist = dist
			best_lane = lane
	return best_lane

func _pick_lane_hit(local_pos: Vector2) -> Dictionary:
	var best_lane_id: int = -1
	var best_t: float = 0.0
	var best_dist: float = INF
	for lane in state.lanes:
		var a: HiveData = _find_hive_by_id(lane.a_id)
		var b: HiveData = _find_hive_by_id(lane.b_id)
		if a == null or b == null:
			continue
		var a_pos: Vector2 = _cell_center(a.grid_pos)
		var b_pos: Vector2 = _cell_center(b.grid_pos)
		var hit: Dictionary = _project_point_to_segment(local_pos, a_pos, b_pos)
		var dist: float = float(hit.get("dist", INF))
		if dist <= LANE_PICK_DIST_PX and dist < best_dist:
			best_dist = dist
			best_lane_id = int(lane.id)
			best_t = float(hit.get("t", 0.0))
	return {
		"ok": best_lane_id != -1,
		"lane_id": best_lane_id,
		"t": best_t,
		"dist": best_dist
	}

func pick_lane_world(world_pos: Vector2) -> Dictionary:
	var local_pos: Vector2 = world_pos
	if map_root != null:
		local_pos = map_root.to_local(world_pos)
	var hit: Dictionary = _pick_lane_hit(local_pos)
	if bool(hit.get("ok", false)):
		SFLog.info("LANE_PICK_HIT", {
			"lane_id": int(hit.get("lane_id", -1)),
			"t": float(hit.get("t", 0.0)),
			"dist": float(hit.get("dist", 0.0))
		})
	else:
		SFLog.info("LANE_PICK_MISS", {"nearest_dist": float(hit.get("dist", INF))})
	return hit

func _distance_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	if ab.length_squared() == 0.0:
		return p.distance_to(a)
	var t: float = (p - a).dot(ab) / ab.length_squared()
	t = clamp(t, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_to(proj)

func _project_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> Dictionary:
	var ab: Vector2 = b - a
	if ab.length_squared() == 0.0:
		return {"t": 0.0, "dist": p.distance_to(a)}
	var t: float = (p - a).dot(ab) / ab.length_squared()
	t = clampf(t, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return {"t": t, "dist": p.distance_to(proj)}

func _cell_px() -> float:
	if hive_renderer != null:
		return float(hive_renderer.cell_px)
	if grid_spec != null:
		return float(grid_spec.cell_size)
	return CELL_SIZE

func get_grid_coord_render_offset() -> float:
	return grid_coord_render_offset

func _arena_rect() -> Rect2:
	if grid_spec != null:
		return Rect2(
			grid_spec.origin,
			Vector2(grid_spec.grid_w * grid_spec.cell_size, grid_spec.grid_h * grid_spec.cell_size)
		)
	var cell_px := _cell_px()
	return Rect2(Vector2.ZERO, Vector2(grid_w * cell_px, grid_h * cell_px))

func _clear_map_markers() -> void:
	for child in map_root.get_children():
		if child.get_meta("map_marker", false):
			map_root.remove_child(child)
			child.queue_free()

func _add_map_marker(pos: Vector2) -> void:
	var marker := Node2D.new()
	marker.position = pos
	marker.visible = false
	marker.set_meta("map_marker", true)
	map_root.call_deferred("add_child", marker)

func _rebuild_map_markers() -> void:
	_clear_map_markers()
	var arena_rect := _arena_rect()
	_add_map_marker(Vector2(0.0, 0.0))
	_add_map_marker(Vector2(arena_rect.size.x, 0.0))
	_add_map_marker(Vector2(0.0, arena_rect.size.y))
	_add_map_marker(Vector2(arena_rect.size.x, arena_rect.size.y))
	for hive in state.hives:
		_add_map_marker(_cell_center(hive.grid_pos))
	for tower_data in towers:
		var grid_pos: Vector2i = tower_data.get("grid_pos", Vector2i.ZERO)
		_add_map_marker(_cell_center(grid_pos))
	for barracks_data in barracks:
		var grid_pos: Vector2i = barracks_data.get("grid_pos", Vector2i.ZERO)
		_add_map_marker(_cell_center(grid_pos))

func _compute_map_root_bounds() -> Rect2:
	var r := Rect2()
	var first := true
	for child in map_root.get_children():
		if child is Node2D:
			var p := (child as Node2D).position
			if first:
				r.position = p
				r.size = Vector2.ZERO
				first = false
			else:
				r = r.expand(p)
	if first:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return r

func _normalize_map_root() -> Rect2:
	map_root.position = Vector2.ZERO
	var bounds: Rect2 = _compute_map_root_bounds()
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		_map_bounds_size = Vector2.ZERO
		if not _map_bounds_missing_logged:
			_map_bounds_missing_logged = true
			SFLog.info("CAMFIT_NO_WORLD_BOUNDS", {
				"reason": "normalize_map_root_empty",
				"map_root": _node_path_for_log(map_root),
				"child_count": map_root.get_child_count() if map_root != null else 0
			})
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	map_root.position -= bounds.position
	_map_bounds_size = bounds.size
	return Rect2(Vector2.ZERO, _map_bounds_size)

func _map_world_bounds() -> Rect2:
	if grid_spec != null:
		return Rect2(
			grid_spec.origin,
			Vector2(grid_spec.grid_w * grid_spec.cell_size, grid_spec.grid_h * grid_spec.cell_size)
		)
	if map_root == null:
		if not _map_bounds_missing_logged:
			_map_bounds_missing_logged = true
			SFLog.info("CAMFIT_NO_WORLD_BOUNDS", {
				"reason": "map_root_null",
				"map_root": "<null>"
			})
		return Rect2()
	var local_bounds: Rect2 = _compute_map_root_bounds()
	if local_bounds.size.x <= 1.0 or local_bounds.size.y <= 1.0:
		if not _map_bounds_missing_logged:
			_map_bounds_missing_logged = true
			SFLog.info("CAMFIT_NO_WORLD_BOUNDS", {
				"reason": "map_root_bounds_empty",
				"map_root": _node_path_for_log(map_root),
				"child_count": map_root.get_child_count()
			})
		return Rect2()
	local_bounds.position += map_root.position
	return local_bounds

func _debug_map_bounds(tag: String) -> void:
	if debug_system == null:
		return
	var bounds: Rect2 = _map_world_bounds()
	var cam_pos := camera.global_position if camera != null else Vector2.ZERO
	var cam_zoom := camera.zoom if camera != null else Vector2.ONE
	debug_system.debug_map_bounds(tag, bounds, cam_pos, cam_zoom)

func _center_map_offset(_map_data: Dictionary) -> void:
	map_offset = Vector2.ZERO

func cell_center(grid_pos: Vector2i) -> Vector2:
	return _cell_center(grid_pos)

func _cell_center(cell: Vector2i) -> Vector2:
	if grid_spec != null:
		return grid_spec.grid_to_world(cell)
	var cell_px := _cell_px()
	return Vector2(
		(float(cell.x) + grid_coord_render_offset) * cell_px,
		(float(cell.y) + grid_coord_render_offset) * cell_px
	) + map_offset

func _cell_rect(cell: Vector2i) -> Rect2:
	if grid_spec != null:
		var cs: float = float(grid_spec.cell_size)
		var size: Vector2 = Vector2(cs, cs)
		var origin: Vector2 = grid_spec.origin
		var pos: Vector2 = origin + Vector2(float(cell.x), float(cell.y)) * cs
		return Rect2(pos, size)
	var cell_px := _cell_px()
	return Rect2(
		Vector2(cell.x, cell.y) * cell_px + map_offset,
		Vector2(cell_px, cell_px)
	)

func _to_map_local(local_pos: Vector2) -> Vector2:
	return local_pos - map_root.position

func _draw() -> void:
	if not draw_arena_rect_debug and not draw_world_bounds_debug:
		return
	if draw_arena_rect_debug:
		draw_rect(_arena_rect(), Color(0.95, 0.65, 0.2, 0.9), false, 2.0)
		var bounds := _compute_map_root_bounds()
		if bounds.size.x > 1.0 and bounds.size.y > 1.0:
			bounds.position += map_root.position
			draw_rect(bounds, Color(0.2, 0.8, 0.9, 0.9), false, 2.0)
	if draw_world_bounds_debug:
		var world_bounds: Rect2 = _map_world_bounds()
		if world_bounds.size.x > 1.0 and world_bounds.size.y > 1.0:
			draw_rect(world_bounds, Color(1, 0.6, 0, 0.9), false, 3.0)
			draw_line(
				world_bounds.position,
				world_bounds.position + Vector2(80, 0),
				Color(1, 0.6, 0, 0.9),
				4.0
			)

func _owner_color(owner_id: int) -> Color:
	match owner_id:
		0:
			return Color(0.6, 0.6, 0.6)
		_:
			if owner_id >= 1 and owner_id <= 4:
				return TeamVisuals.owner_color(owner_id)
			return Color(0.8, 0.8, 0.8)

func _owner_label(owner_id: int) -> String:
	match owner_id:
		0:
			return "Neutral"
		1:
			return "P1(Yellow)"
		2:
			return "P2(Red)"
		3:
			return "P3(Green)"
		4:
			return "P4(Blue)"
		_:
			return "P%d" % owner_id

func _update_lanes(delta: float) -> void:
	for i in range(state.lanes.size()):
		var lane: Variant = state.lanes[i]
		var was_active: bool = false
		if lane is LaneData:
			var ld := lane as LaneData
			was_active = (
				ld.send_a or ld.send_b or ld.retract_a or ld.retract_b
				or ld.establish_a or ld.establish_b
				or ld.a_stream_len > 0.0 or ld.b_stream_len > 0.0
			)
			var a: HiveData = _find_hive_by_id(ld.a_id)
			var b: HiveData = _find_hive_by_id(ld.b_id)
			if a == null or b == null:
				continue
			var flow_a: bool = ld.send_a and a.owner_id != 0
			var flow_b: bool = ld.send_b and b.owner_id != 0
			var lane_len: float = _lane_length_px(a, b)
			var rate_a: float = _send_rate(a, flow_a)
			var rate_b: float = _send_rate(b, flow_b)
			var decay: float = maxf(0.0, 1.0 - PRESSURE_DECAY_PER_SEC * delta)
			ld.a_pressure *= decay
			ld.b_pressure *= decay
			if rate_a > 0.0:
				ld.a_pressure += rate_a * delta
				ld.a_stream_len = min(lane_len, ld.a_stream_len + _base_unit_speed_px() * delta)
			if rate_b > 0.0:
				ld.b_pressure += rate_b * delta
				ld.b_stream_len = min(lane_len, ld.b_stream_len + _base_unit_speed_px() * delta)
			if ld.retract_a:
				ld.a_stream_len = max(0.0, ld.a_stream_len - _base_unit_speed_px() * delta)
				if ld.a_stream_len <= 0.0:
					ld.retract_a = false
			if ld.retract_b:
				ld.b_stream_len = max(0.0, ld.b_stream_len - _base_unit_speed_px() * delta)
				if ld.b_stream_len <= 0.0:
					ld.retract_b = false
			if ld.establish_a and ld.a_stream_len >= lane_len:
				ld.establish_a = false
			if ld.establish_b and ld.b_stream_len >= lane_len:
				ld.establish_b = false
			var is_active := (
				ld.send_a or ld.send_b or ld.retract_a or ld.retract_b
				or ld.establish_a or ld.establish_b
				or ld.a_stream_len > 0.0 or ld.b_stream_len > 0.0
			)
			if was_active or is_active:
				_note_render_dirty()
		elif lane is Dictionary:
			var d := lane as Dictionary
			var send_a := bool(d.get("send_a", false))
			var send_b := bool(d.get("send_b", false))
			var retract_a := bool(d.get("retract_a", false))
			var retract_b := bool(d.get("retract_b", false))
			var establish_a := bool(d.get("establish_a", false))
			var establish_b := bool(d.get("establish_b", false))
			var a_stream_len := float(d.get("a_stream_len", 0.0))
			var b_stream_len := float(d.get("b_stream_len", 0.0))
			var a_pressure := float(d.get("a_pressure", 0.0))
			var b_pressure := float(d.get("b_pressure", 0.0))
			was_active = (
				send_a or send_b or retract_a or retract_b
				or establish_a or establish_b
				or a_stream_len > 0.0 or b_stream_len > 0.0
			)
			var a_id := int(d.get("a_id", -1))
			var b_id := int(d.get("b_id", -1))
			var a: HiveData = _find_hive_by_id(a_id)
			var b: HiveData = _find_hive_by_id(b_id)
			if a == null or b == null:
				continue
			var flow_a: bool = send_a and a.owner_id != 0
			var flow_b: bool = send_b and b.owner_id != 0
			var lane_len: float = _lane_length_px(a, b)
			var rate_a: float = _send_rate(a, flow_a)
			var rate_b: float = _send_rate(b, flow_b)
			var decay: float = maxf(0.0, 1.0 - PRESSURE_DECAY_PER_SEC * delta)
			a_pressure *= decay
			b_pressure *= decay
			if rate_a > 0.0:
				a_pressure += rate_a * delta
				a_stream_len = min(lane_len, a_stream_len + _base_unit_speed_px() * delta)
			if rate_b > 0.0:
				b_pressure += rate_b * delta
				b_stream_len = min(lane_len, b_stream_len + _base_unit_speed_px() * delta)
			if retract_a:
				a_stream_len = max(0.0, a_stream_len - _base_unit_speed_px() * delta)
				if a_stream_len <= 0.0:
					retract_a = false
			if retract_b:
				b_stream_len = max(0.0, b_stream_len - _base_unit_speed_px() * delta)
				if b_stream_len <= 0.0:
					retract_b = false
			if establish_a and a_stream_len >= lane_len:
				establish_a = false
			if establish_b and b_stream_len >= lane_len:
				establish_b = false
			d["a_pressure"] = a_pressure
			d["b_pressure"] = b_pressure
			d["a_stream_len"] = a_stream_len
			d["b_stream_len"] = b_stream_len
			d["retract_a"] = retract_a
			d["retract_b"] = retract_b
			d["establish_a"] = establish_a
			d["establish_b"] = establish_b
			var is_active := (
				send_a or send_b or retract_a or retract_b
				or establish_a or establish_b
				or a_stream_len > 0.0 or b_stream_len > 0.0
			)
			if was_active or is_active:
				_note_render_dirty()
		else:
			continue

func _update_lane_sim(dt: float) -> void:
	if state == null:
		return
	if state.lane_sim_by_key.is_empty():
		return
	var any_dirty := false
	for key in state.lane_sim_by_key.keys():
		var lane_state: Dictionary = state.lane_sim_by_key.get(key, {})
		if lane_state.is_empty():
			continue
		if not lane_state.has("establish_t_by_owner"):
			lane_state["establish_t_by_owner"] = {}
		if not lane_state.has("establishing_by_owner"):
			lane_state["establishing_by_owner"] = {}
		if not lane_state.has("established_by_owner"):
			lane_state["established_by_owner"] = {}
		if not lane_state.has("spawn_timer_ms_by_owner"):
			lane_state["spawn_timer_ms_by_owner"] = {}
		var a_id: int = int(lane_state.get("a_id", 0))
		var b_id: int = int(lane_state.get("b_id", 0))
		if a_id <= 0 or b_id <= 0:
			continue
		var a: HiveData = _find_hive_by_id(a_id)
		var b: HiveData = _find_hive_by_id(b_id)
		if a == null or b == null:
			continue
		var length_px: float = _lane_length_px(a, b)
		lane_state["length_px"] = length_px
		if length_px <= 0.0:
			continue
		var lane_dirty := false
		var side_by_owner: Dictionary = lane_state.get("side", {})
		var establish_t_by_owner: Dictionary = lane_state.get("establish_t_by_owner", {})
		var establishing_by_owner: Dictionary = lane_state.get("establishing_by_owner", {})
		var established_by_owner: Dictionary = lane_state.get("established_by_owner", {})
		var spawn_timer_ms_by_owner: Dictionary = lane_state.get("spawn_timer_ms_by_owner", {})
		var establish_last_by_owner: Dictionary = lane_state.get("establish_last_by_owner", {})
		for owner_key in side_by_owner.keys():
			var side: Dictionary = side_by_owner[owner_key]
			var owner_id := int(side.get("owner_id", 0))
			var just_established := false
			var establishing := bool(establishing_by_owner.get(owner_id, false))
			var established := bool(established_by_owner.get(owner_id, false))
			var progress := float(establish_t_by_owner.get(owner_id, 0.0))
			var last_progress := float(establish_last_by_owner.get(owner_id, progress))
			var lane_key_str := str(lane_state.get("lane_key", key))
			if last_progress > 0.0 and progress < last_progress:
				var msg := "ESTABLISH_RESET lane=%s owner=%d progress=%.3f prev=%.3f" % [
					lane_key_str,
					owner_id,
					progress,
					last_progress
				]
				SFLog.throttle("est_reset:%s:%d" % [lane_key_str, owner_id], 0.25, msg, SFLog.Level.INFO)
			if establishing and not established:
				var est_speed := float(side.get("est_speed", 0.0))
				if est_speed <= 0.0:
					est_speed = length_px / (LANE_ESTABLISH_MS / 1000.0)
				progress += (est_speed * dt) / length_px
				if progress >= 1.0:
					progress = 1.0
					establishing = false
					established = true
					if not bool(side.get("first_unit_sent", false)):
						spawn_timer_ms_by_owner[owner_id] = float(side.get("first_unit_delay_ms", FIRST_UNIT_OFFSET_MS))
					just_established = true
					var msg := "ESTABLISH_COMPLETE lane=%s owner=%d progress=%.3f" % [
						lane_key_str,
						owner_id,
						progress
					]
					SFLog.throttle("est_complete:%s:%d" % [lane_key_str, owner_id], 0.25, msg, SFLog.Level.INFO)
					lane_dirty = true
				establish_t_by_owner[owner_id] = progress
				establishing_by_owner[owner_id] = establishing
				established_by_owner[owner_id] = established
			if not is_equal_approx(last_progress, progress):
				lane_dirty = true
			var attacker_id: int = int(side.get("attacker_id", -1))
			var attacker: HiveData = _find_hive_by_id(attacker_id)
			var power: int = attacker.power if attacker != null else 1
			var spawn_interval_ms := _spawn_interval_ms_for_power(power)
			if not established:
				pass
			else:
				var spawn_timer_ms := float(spawn_timer_ms_by_owner.get(owner_id, 0.0))
				if just_established:
					spawn_timer_ms = float(spawn_timer_ms_by_owner.get(owner_id, FIRST_UNIT_OFFSET_MS))
				var timer_ms := spawn_timer_ms
				var prev_timer_ms := timer_ms
				if not just_established:
					timer_ms -= dt * 1000.0
				var spawned := false
				while timer_ms <= 0.0:
					_spawn_first_unit_for_side(lane_state, side)
					if not bool(side.get("first_unit_sent", false)):
						side["first_unit_sent"] = true
						_clear_active_order_for_side(lane_state, side)
						var msg := "FIRST_UNIT lane=%s owner=%d" % [
							str(lane_state.get("lane_key", key)),
							int(side.get("owner_id", 0))
						]
						SFLog.throttle("first_unit:%s:%d" % [lane_key_str, owner_id], 0.25, msg, SFLog.Level.INFO)
					timer_ms += spawn_interval_ms
					spawned = true
				spawn_timer_ms_by_owner[owner_id] = timer_ms
				if spawned or not is_equal_approx(prev_timer_ms, timer_ms):
					lane_dirty = true
			side_by_owner[owner_key] = side
			establish_last_by_owner[owner_id] = progress
		lane_state["side"] = side_by_owner
		lane_state["establish_t_by_owner"] = establish_t_by_owner
		lane_state["establishing_by_owner"] = establishing_by_owner
		lane_state["established_by_owner"] = established_by_owner
		lane_state["spawn_timer_ms_by_owner"] = spawn_timer_ms_by_owner
		lane_state["establish_last_by_owner"] = establish_last_by_owner
		state.lane_sim_by_key[key] = lane_state
		if lane_dirty:
			any_dirty = true
	if any_dirty:
		_note_render_dirty()

func _spawn_units(dt: float) -> void:
	if state == null:
		return
	var dt_ms: float = dt * 1000.0
	var spawns: Array = state.spawns
	var stats: Dictionary = {
		"skip_no_lane": 0,
		"skip_bad_hive": 0,
		"skip_rate": 0,
		"skip_other": 0,
		"did_spawn": 0
	}
	var outgoing_by_hive: Dictionary = {}
	var outgoing_v = state.get("outgoing_by_hive")
	if typeof(outgoing_v) == TYPE_DICTIONARY:
		outgoing_by_hive = outgoing_v as Dictionary
	var spawn_ids: Dictionary = {}
	for spawn_v in spawns:
		if typeof(spawn_v) != TYPE_DICTIONARY:
			continue
		var sd: Dictionary = spawn_v as Dictionary
		var hive_id_v: Variant = sd.get("hive_id", sd.get("id", 0))
		var hive_id: int = 0
		if hive_id_v is int:
			hive_id = int(hive_id_v)
		else:
			var id_str: String = str(hive_id_v)
			if id_str.is_valid_int():
				hive_id = int(id_str)
		if hive_id > 0:
			spawn_ids[hive_id] = true
	for hive_id in spawn_ids.keys():
		var outgoing_v2: Variant = outgoing_by_hive.get(hive_id, [])
		if typeof(outgoing_v2) != TYPE_ARRAY or (outgoing_v2 as Array).is_empty():
			stats["skip_no_lane"] = int(stats["skip_no_lane"]) + 1
	for lane in state.lanes:
		var a: HiveData = _find_hive_by_id(lane.a_id)
		var b: HiveData = _find_hive_by_id(lane.b_id)
		if a == null or b == null:
			stats["skip_bad_hive"] = int(stats["skip_bad_hive"]) + 1
			continue
		if not lane.send_a and not lane.send_b:
			if a.id == 1:
				_maybe_log_spawnfail(a, "send_off")
			elif b.id == 1:
				_maybe_log_spawnfail(b, "send_off")
			stats["skip_other"] = int(stats["skip_other"]) + 1
			continue
		if lane.send_a:
			if ENABLE_SPAWN_SOURCE_FILTER and not spawn_ids.is_empty() and not spawn_ids.has(a.id):
				stats["skip_other"] = int(stats["skip_other"]) + 1
			else:
				var spawned_a := _spawn_lane_units(lane, a, b, dt_ms, true, stats)
				stats["did_spawn"] = int(stats["did_spawn"]) + spawned_a
		if lane.send_b:
			if ENABLE_SPAWN_SOURCE_FILTER and not spawn_ids.is_empty() and not spawn_ids.has(b.id):
				stats["skip_other"] = int(stats["skip_other"]) + 1
			else:
				var spawned_b := _spawn_lane_units(lane, b, a, dt_ms, false, stats)
				stats["did_spawn"] = int(stats["did_spawn"]) + spawned_b
	var spawnwhy_msg := "SPAWNWHY: did=%d bad_hive=%d no_lane=%d rate=%d other=%d lanes=%d units=%d" % [
		int(stats["did_spawn"]),
		int(stats["skip_bad_hive"]),
		int(stats["skip_no_lane"]),
		int(stats["skip_rate"]),
		int(stats["skip_other"]),
		state.lanes.size(),
		units.size()
	]
	SFLog.throttle("spawnwhy", 1.0, spawnwhy_msg, SFLog.Level.TRACE)

func _spawn_lane_units(lane: LaneData, from_hive: HiveData, to_hive: HiveData, dt_ms: float, from_is_a: bool, stats: Dictionary) -> int:
	if from_hive.owner_id == 0:
		_maybe_log_spawnfail(from_hive, "owner_zero")
		stats["skip_other"] = int(stats["skip_other"]) + 1
		return 0
	if ENABLE_HIVE_SPAWN_SHOCK_BLOCK and from_hive.shock_ms > 0.0:
		if from_is_a:
			lane.spawn_accum_a_ms = 0.0
		else:
			lane.spawn_accum_b_ms = 0.0
		_maybe_log_spawnfail(from_hive, "shock")
		stats["skip_other"] = int(stats["skip_other"]) + 1
		return 0
	var lane_len_dbg: float = _lane_length_px(from_hive, to_hive)
	var stream_dbg: float = lane.a_stream_len if from_is_a else lane.b_stream_len
	if ENABLE_LANE_ESTABLISH_SPAWN_GATE and not _lane_ready_for_send(lane, from_hive.id):
		_maybe_log_spawnfail(from_hive, "lane_ready", "lane_len=%.1f stream=%.1f" % [
			lane_len_dbg,
			stream_dbg
		])
		stats["skip_other"] = int(stats["skip_other"]) + 1
		return 0
	var interval_ms: float = _hive_spawn_interval_ms(from_hive)
	var accum: float = lane.spawn_accum_a_ms if from_is_a else lane.spawn_accum_b_ms
	accum += dt_ms
	var spawned := 0
	while accum >= interval_ms and (not ENABLE_MAX_SPAWNS_PER_TICK or spawned < MAX_SPAWNS_PER_TICK):
		_spawn_unit(from_hive.id, to_hive.id, from_hive.owner_id, lane.id, true)
		accum -= interval_ms
		spawned += 1
	if from_is_a:
		lane.spawn_accum_a_ms = accum
	else:
		lane.spawn_accum_b_ms = accum
	if spawned == 0:
		stats["skip_rate"] = int(stats["skip_rate"]) + 1
		var now_ms: int = int(sim_time_us / 1000)
		var last_ms: int = now_ms - int(accum)
		_maybe_log_spawnfail(from_hive, "rate_gate",
			"now=%d last=%d dt=%d need=%.1f" % [now_ms, last_ms, int(accum), interval_ms])
	return spawned

func _maybe_log_spawnfail(hive: HiveData, reason: String, detail: String = "") -> void:
	if hive == null or hive.id != 1:
		return
	var now_ms: int = int(sim_time_us / 1000)
	if now_ms - _last_spawnfail_ms < 1000:
		return
	_last_spawnfail_ms = now_ms
	var outgoing_count: int = 0
	if state != null:
		var out_v: Variant = state.outgoing_by_hive.get(hive.id, [])
		if typeof(out_v) == TYPE_ARRAY:
			outgoing_count = (out_v as Array).size()
	SFLog.trace("SPAWNFAIL", {
		"hive_id": hive.id,
		"reason": reason,
		"power": hive.power,
		"out": outgoing_count,
		"lanes": state.lanes.size() if state != null else -1,
		"units": units.size(),
		"detail": detail,
		"ms": now_ms
	})

func _lane_endpoints_for_key(lane_key: String) -> Array:
	if state == null or lane_key.is_empty():
		return []
	var lane_state: Dictionary = state.lane_sim_by_key.get(lane_key, {})
	if not lane_state.is_empty():
		var a_id: int = int(lane_state.get("a_id", 0))
		var b_id: int = int(lane_state.get("b_id", 0))
		if a_id > 0 and b_id > 0:
			return [a_id, b_id]
	for lane in state.lanes:
		var l: LaneData = lane
		if state.lane_key(l.a_id, l.b_id) == lane_key:
			return [l.a_id, l.b_id]
	return []

func _lane_endpoints_for_unit(unit: Dictionary) -> Array:
	if state == null:
		return []
	var lane_id: int = int(unit.get("lane_id", -1))
	if lane_id != -1:
		var lane: LaneData = _find_lane_by_id(lane_id)
		if lane != null:
			return [lane.a_id, lane.b_id]
	var lane_key: String = str(unit.get("lane_key", ""))
	if lane_key.is_empty():
		return []
	return _lane_endpoints_for_key(lane_key)

func _ensure_unit_lane_fields(unit: Dictionary) -> Dictionary:
	var endpoints := _lane_endpoints_for_unit(unit)
	if endpoints.size() == 2:
		var a_id: int = int(endpoints[0])
		var b_id: int = int(endpoints[1])
		unit["a_id"] = a_id
		unit["b_id"] = b_id
		unit["lane_key"] = state.lane_key(a_id, b_id)
		var from_id: int = int(unit.get("from_id", -1))
		if from_id == a_id:
			unit["dir"] = 1
			unit["spawn_end"] = "A"
		elif from_id == b_id:
			unit["dir"] = -1
			unit["spawn_end"] = "B"
		var dir_i := int(unit.get("dir", 0))
		var t_val := clampf(float(unit.get("t", 0.0)), 0.0, 1.0)
		if dir_i < 0:
			unit["lane_t"] = clampf(1.0 - t_val, 0.0, 1.0)
		else:
			unit["lane_t"] = t_val
	return unit

func _unit_lane_t(unit: Dictionary) -> float:
	if unit.has("lane_t"):
		return clampf(float(unit.get("lane_t", 0.0)), 0.0, 1.0)
	var dir := int(unit.get("dir", 0))
	var t := clampf(float(unit.get("t", 0.0)), 0.0, 1.0)
	if dir < 0:
		return 1.0 - t
	return t

func _lane_spike_t(lane_len_px: float) -> float:
	if lane_len_px <= 0.0:
		return 0.0
	return SPIKE_PX / lane_len_px

func _kill_unit(index: int, unit: Dictionary, reason: String, remove_indices: Array[int], remove_set: Dictionary) -> void:
	if remove_set.has(index):
		return
	unit["dead"] = true
	unit["alive"] = false
	units[index] = unit
	SFLog.info("KILL idx=%d id=%d lane=%s owner=%d reason=%s" % [
		index,
		int(unit.get("id", -1)),
		str(unit.get("lane_key", "")),
		int(unit.get("owner_id", 0)),
		reason
	])
	remove_set[index] = true
	remove_indices.append(index)
	SFLog.info("UNIT_DIE: id=%d lane=%s owner=%d reason=%s" % [
		int(unit.get("id", -1)),
		str(unit.get("lane_key", "")),
		int(unit.get("owner_id", 0)),
		reason
	])

func _resolve_lane_unit_interactions(remove_indices: Array[int], remove_set: Dictionary) -> void:
	if state == null:
		return
	var units_by_lane: Dictionary = {}
	for i in range(units.size()):
		if remove_set.has(i):
			continue
		var unit: Dictionary = units[i]
		if bool(unit.get("dead", false)) or not bool(unit.get("alive", true)):
			continue
		if bool(unit.get("recall", false)):
			continue
		unit = _ensure_unit_lane_fields(unit)
		var lane_key := str(unit.get("lane_key", ""))
		if lane_key.is_empty():
			continue
		var lane_t := clampf(_unit_lane_t(unit), 0.0, 1.0)
		unit["lane_t"] = lane_t
		units[i] = unit
		if not units_by_lane.has(lane_key):
			units_by_lane[lane_key] = {}
		var owner_id := int(unit.get("owner_id", 0))
		if not (units_by_lane[lane_key] as Dictionary).has(owner_id):
			(units_by_lane[lane_key] as Dictionary)[owner_id] = []
		((units_by_lane[lane_key] as Dictionary)[owner_id] as Array).append({
			"idx": i,
			"t": lane_t,
			"owner_id": owner_id,
			"dir": int(unit.get("dir", 0))
		})
	# Do NOT publish units_by_lane here.
	# UnitSystem owns state.units_by_lane publishing (state.units_by_lane["_all"]).
	# state.units_by_lane = units_by_lane

	for lane_key in units_by_lane.keys():
		var endpoints := _lane_endpoints_for_key(str(lane_key))
		if endpoints.size() != 2:
			continue
		var a_hive: HiveData = _find_hive_by_id(int(endpoints[0]))
		var b_hive: HiveData = _find_hive_by_id(int(endpoints[1]))
		if a_hive == null or b_hive == null:
			continue
		var lane_len := _lane_length_px(a_hive, b_hive)
		if not state.lane_sim_by_key.has(str(lane_key)):
			state.ensure_lane_state(int(endpoints[0]), int(endpoints[1]), lane_len)
		var spike_t := _lane_spike_t(lane_len)
		var a_node_id: int = int(endpoints[0])
		var b_node_id: int = int(endpoints[1])
		var a_has_tower: bool = state != null and str(state.structure_by_node_id.get(a_node_id, "")) == "tower"
		var b_has_tower: bool = state != null and str(state.structure_by_node_id.get(b_node_id, "")) == "tower"
		var a_tower_owner: int = int(state.structure_owner_by_node_id.get(a_node_id, 0)) if state != null else 0
		var b_tower_owner: int = int(state.structure_owner_by_node_id.get(b_node_id, 0)) if state != null else 0

		var by_owner: Dictionary = units_by_lane[lane_key]
		for side_owner_id in by_owner.keys():
			var entries: Array = by_owner[side_owner_id]
			for entry in entries:
				var idx: int = int(entry.get("idx", -1))
				if idx == -1 or remove_set.has(idx):
					continue
				var unit: Dictionary = units[idx]
				if bool(unit.get("dead", false)) or not bool(unit.get("alive", true)):
					continue
				var unit_lane_key := str(unit.get("lane_key", ""))
				if unit_lane_key != str(lane_key):
					SFLog.info("LANE_LEAK unit_id=%d unit_lane=%s processing_lane=%s" % [
						int(unit.get("id", -1)),
						unit_lane_key,
						str(lane_key)
					])
					continue
				var lane_t := clampf(float(unit.get("lane_t", entry.get("t", 0.0))), 0.0, 1.0)
				# Edge zones for future feed/decay hooks (stub only).
				var _edge_zone := lane_t <= LANE_EDGE_T or lane_t >= 1.0 - LANE_EDGE_T
				var owner_id := int(unit.get("owner_id", 0))
				if not DEBUG_COLLISION_ONLY:
					if a_has_tower and not _are_allied_owners(owner_id, a_tower_owner) and lane_t <= spike_t:
						SFLog.info("UNIT_DIE spike lane=%s owner=%d t=%.3f" % [
							str(lane_key),
							owner_id,
							lane_t
						])
						record_lane_collision(str(lane_key), lane_t)
						_kill_unit(idx, unit, "spike_a", remove_indices, remove_set)
					elif b_has_tower and not _are_allied_owners(owner_id, b_tower_owner) and lane_t >= 1.0 - spike_t:
						SFLog.info("UNIT_DIE spike lane=%s owner=%d t=%.3f" % [
							str(lane_key),
							owner_id,
							lane_t
						])
						record_lane_collision(str(lane_key), lane_t)
						_kill_unit(idx, unit, "spike_b", remove_indices, remove_set)

		var forward: Array = []
		var backward: Array = []
		for owner_id in by_owner.keys():
			var entries: Array = by_owner[owner_id]
			for entry in entries:
				var idx: int = int(entry.get("idx", -1))
				if idx == -1 or remove_set.has(idx):
					continue
				var unit: Dictionary = units[idx]
				if bool(unit.get("dead", false)) or not bool(unit.get("alive", true)):
					continue
				var unit_lane_key := str(unit.get("lane_key", ""))
				if unit_lane_key != str(lane_key):
					SFLog.info("LANE_LEAK unit_id=%d unit_lane=%s processing_lane=%s" % [
						int(unit.get("id", -1)),
						unit_lane_key,
						str(lane_key)
					])
					continue
				entry["t"] = clampf(float(unit.get("lane_t", 0.0)), 0.0, 1.0)
				var dir_i := int(unit.get("dir", int(entry.get("dir", 0))))
				entry["dir"] = dir_i
				if dir_i > 0:
					forward.append(entry)
				elif dir_i < 0:
					backward.append(entry)
		forward.sort_custom(Callable(self, "_sort_lane_t_desc"))
		backward.sort_custom(Callable(self, "_sort_lane_t_asc"))

		while not forward.is_empty() and not backward.is_empty():
			var a_entry: Dictionary = forward[0] as Dictionary
			var b_entry: Dictionary = backward[0] as Dictionary
			var a_idx: int = int(a_entry.get("idx", -1))
			var b_idx: int = int(b_entry.get("idx", -1))
			if a_idx == -1 or b_idx == -1:
				break
			if remove_set.has(a_idx) or remove_set.has(b_idx):
				forward.pop_front()
				backward.pop_front()
				continue
			var a_unit: Dictionary = units[a_idx]
			var b_unit: Dictionary = units[b_idx]
			if bool(a_unit.get("dead", false)) or bool(b_unit.get("dead", false)):
				forward.pop_front()
				backward.pop_front()
				continue
			var a_t := clampf(float(a_unit.get("lane_t", 0.0)), 0.0, 1.0)
			var b_t := clampf(float(b_unit.get("lane_t", 0.0)), 0.0, 1.0)
			var a_dir: int = int(a_unit.get("dir", 0))
			var b_dir: int = int(b_unit.get("dir", 0))
			var a_spawn_end := str(a_unit.get("spawn_end", "?"))
			var b_spawn_end := str(b_unit.get("spawn_end", "?"))
			var a_entry_dir: int = int(a_entry.get("dir", 0))
			var b_entry_dir: int = int(b_entry.get("dir", 0))
			var a_entry_t: float = float(a_entry.get("t", -1.0))
			var b_entry_t: float = float(b_entry.get("t", -1.0))
			var owner_match := _are_allied_owners(
			int(a_unit.get("owner_id", 0)),
			int(b_unit.get("owner_id", 0))
			)
			var a_from_id: int = int(a_unit.get("from_id", -1))
			var b_from_id: int = int(b_unit.get("from_id", -1))
			var a_from_valid := a_from_id == a_node_id or a_from_id == b_node_id
			var b_from_valid := b_from_id == a_node_id or b_from_id == b_node_id
			var dir_invalid := a_dir == 0 or b_dir == 0
			var from_invalid := not a_from_valid or not b_from_valid
			if owner_match or dir_invalid or from_invalid:
				var msg := "PAIR_DEBUG lane=%s f_idx=%d f_id=%d f_owner=%d f_dir=%d f_spawn=%s f_t=%.3f f_entry_dir=%d f_entry_t=%.3f | b_idx=%d b_id=%d b_owner=%d b_dir=%d b_spawn=%s b_t=%.3f b_entry_dir=%d b_entry_t=%.3f" % [
					str(lane_key),
					a_idx,
					int(a_unit.get("id", -1)),
					int(a_unit.get("owner_id", 0)),
					a_dir,
					a_spawn_end,
					a_t,
					a_entry_dir,
					a_entry_t,
					b_idx,
					int(b_unit.get("id", -1)),
					int(b_unit.get("owner_id", 0)),
					b_dir,
					b_spawn_end,
					b_t,
					b_entry_dir,
					b_entry_t
				]
				SFLog.throttle("pair_debug:%s" % str(lane_key), 0.25, msg, SFLog.Level.INFO)
				if owner_match:
					SFLog.throttle("bad_pair:%s" % str(lane_key), 0.25,
						"BAD_PAIR lane=%s f_id=%d b_id=%d owner=%d" % [
							str(lane_key),
							int(a_unit.get("id", -1)),
							int(b_unit.get("id", -1)),
							int(a_unit.get("owner_id", 0))
						],
						SFLog.Level.INFO
					)
				if owner_match:
					var a_progress: float = a_t
					var b_progress: float = 1.0 - b_t
					if a_progress <= b_progress:
						forward.pop_front()
					else:
						backward.pop_front()
					continue
				if a_t >= b_t:
					dbg_mark_event("unit_collision")
					var a_id: int = int(a_unit.get("id", -1))
					var b_id: int = int(b_unit.get("id", -1))
					var a_dead := bool(a_unit.get("dead", false))
					var b_dead := bool(b_unit.get("dead", false))
					SFLog.info("COLLISION_PAIR lane=%s a_idx=%d a_id=%d a_dead=%s a_owner=%d a_t=%.3f b_idx=%d b_id=%d b_dead=%s b_owner=%d b_t=%.3f" % [
						str(lane_key),
						a_idx,
						a_id,
						str(a_dead),
						int(a_unit.get("owner_id", 0)),
						a_t,
						b_idx,
						b_id,
						str(b_dead),
						int(b_unit.get("owner_id", 0)),
						b_t
					])
					var t_collision: float = clampf((a_t + b_t) * 0.5, 0.0, 1.0)
					SFLog.info("COLLISION: lane=%s t=%.3f" % [str(lane_key), t_collision])
					record_lane_collision(str(lane_key), t_collision)
					_kill_unit(a_idx, a_unit, "collision", remove_indices, remove_set)
					_kill_unit(b_idx, b_unit, "collision", remove_indices, remove_set)
					var a_dead_post := false
					var b_dead_post := false
					if a_idx >= 0 and a_idx < units.size():
						var a_unit_post: Dictionary = units[a_idx]
						a_dead_post = bool(a_unit_post.get("dead", false))
						a_id = int(a_unit_post.get("id", a_id))
					if b_idx >= 0 and b_idx < units.size():
						var b_unit_post: Dictionary = units[b_idx]
						b_dead_post = bool(b_unit_post.get("dead", false))
						b_id = int(b_unit_post.get("id", b_id))
					SFLog.info("POST_KILL lane=%s a_id=%d a_dead=%s b_id=%d b_dead=%s" % [
						str(lane_key),
						a_id,
						str(a_dead_post),
						b_id,
						str(b_dead_post)
					])
					forward.pop_front()
					backward.pop_front()
				else:
					SFLog.info("NO_COLLISION lane=%s f_t=%.3f b_t=%.3f" % [
						str(lane_key),
						a_t,
						b_t
					])
					break

func _sort_lane_t_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("t", 0.0)) > float(b.get("t", 0.0))

func _sort_lane_t_asc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("t", 0.0)) < float(b.get("t", 0.0))

func _update_units(dt: float) -> void:
	if not units.is_empty():
		_note_render_dirty()
	var preflag_groups: Dictionary = {}
	var arrival_groups: Dictionary = {}
	var remove_indices: Array[int] = []
	for i in range(units.size() - 1, -1, -1):
		var unit: Dictionary = units[i]
		if bool(unit.get("dead", false)) or not bool(unit.get("alive", true)):
			remove_indices.append(i)
			continue
		var is_recall: bool = bool(unit.get("recall", false))
		var from_hive: HiveData = null
		var start_pos: Vector2
		var end_pos: Vector2
		if unit.has("from_pos"):
			start_pos = unit["from_pos"]
		else:
			from_hive = _find_hive_by_id(int(unit["from_id"]))
			if from_hive == null:
				remove_indices.append(i)
				continue
		var to_hive: HiveData = _find_hive_by_id(int(unit["to_id"]))
		if to_hive == null:
			remove_indices.append(i)
			continue
		var to_center: Vector2 = _cell_center(to_hive.grid_pos)
		if unit.has("from_pos"):
			end_pos = _edge_point_toward(to_center, start_pos)
		else:
			var from_center: Vector2 = _cell_center(from_hive.grid_pos)
			start_pos = _edge_point_toward(from_center, to_center)
			end_pos = _edge_point_toward(to_center, from_center)
		var lane: LaneData = null
		if int(unit["lane_id"]) != -1:
			lane = _find_lane_by_id(int(unit["lane_id"]))
			if lane == null:
				remove_indices.append(i)
				continue
		var lane_len: float = start_pos.distance_to(end_pos)
		if lane_len <= 0.0:
			remove_indices.append(i)
			continue
		var speed_t := 1.0 / (UNIT_TRAVEL_MS / 1000.0)
		unit["speed_t"] = speed_t
		var delta_t: float = speed_t * dt
		var dir_i: int = int(unit.get("dir", 0))
		if dir_i == 0:
			dir_i = 1
		if is_recall:
			unit["t"] = clampf(float(unit["t"]) - delta_t, 0.0, 1.0)
			var recall_t := float(unit["t"])
			if dir_i < 0:
				unit["lane_t"] = clampf(1.0 - recall_t, 0.0, 1.0)
			else:
				unit["lane_t"] = clampf(recall_t, 0.0, 1.0)
			if float(unit["t"]) <= 0.0:
				_refund_recalled_unit(unit)
				remove_indices.append(i)
				continue
			unit = _ensure_unit_lane_fields(unit)
			units[i] = unit
			continue
		var lane_t: float = clampf(float(unit.get("lane_t", _unit_lane_t(unit))), 0.0, 1.0)
		lane_t += delta_t * float(dir_i)
		lane_t = clampf(lane_t, 0.0, 1.0)
		unit["lane_t"] = lane_t
		if dir_i < 0:
			unit["t"] = clampf(1.0 - lane_t, 0.0, 1.0)
		else:
			unit["t"] = clampf(lane_t, 0.0, 1.0)
		if not DEBUG_COLLISION_ONLY:
			if (dir_i > 0 and lane_t >= 1.0) or (dir_i < 0 and lane_t <= 0.0):
				unit["arrival_us"] = sim_time_us
		if not unit.has("arrival_us"):
			unit["arrival_us"] = _estimate_arrival_us(unit, start_pos, unit.has("from_pos"))
		var arrival_us: int = int(unit["arrival_us"])
		var bucket_us: int = int(floor(float(arrival_us) / float(TIE_BUCKET_US))) * TIE_BUCKET_US
		var group_key: String = "%d:%d" % [to_hive.id, bucket_us]
		if not DEBUG_COLLISION_ONLY:
			if not preflag_groups.has(group_key):
				preflag_groups[group_key] = []
			preflag_groups[group_key].append(i)
			if arrival_us <= sim_time_us:
				if not arrival_groups.has(group_key):
					arrival_groups[group_key] = []
				arrival_groups[group_key].append(i)
		unit = _ensure_unit_lane_fields(unit)
		units[i] = unit
	var remove_set: Dictionary = {}
	for idx in remove_indices:
		remove_set[int(idx)] = true
	if not DEBUG_COLLISION_ONLY:
		if remove_set.size() > 0:
			_filter_group_indices(preflag_groups, remove_set)
			_filter_group_indices(arrival_groups, remove_set)
		_preflag_ties(preflag_groups)
		_resolve_arrivals(arrival_groups, remove_indices, remove_set)
		for idx in remove_indices:
			remove_set[int(idx)] = true
	_resolve_lane_unit_interactions(remove_indices, remove_set)
	_finalize_unit_removals(remove_indices)

func _update_swarms(dt: float) -> void:
	if not swarm_packets.is_empty():
		_note_render_dirty()
	var dt_ms: float = dt * 1000.0
	for i in range(swarm_packets.size() - 1, -1, -1):
		var packet: Dictionary = swarm_packets[i]
		if packet["armed_ms"] > 0.0:
			packet["armed_ms"] = max(0.0, packet["armed_ms"] - dt_ms)
			swarm_packets[i] = packet
			continue
		var from_hive: HiveData = _find_hive_by_id(int(packet["from_id"]))
		var to_hive: HiveData = _find_hive_by_id(int(packet["to_id"]))
		if from_hive == null or to_hive == null:
			_stop_swarm_sfx(int(packet.get("id", -1)))
			swarm_packets.remove_at(i)
			continue
		var from_center: Vector2 = _cell_center(from_hive.grid_pos)
		var to_center: Vector2 = _cell_center(to_hive.grid_pos)
		var from_pos: Vector2 = _edge_point_toward(from_center, to_center)
		var to_pos: Vector2 = _edge_point_toward(to_center, from_center)

		var lane_len: float = from_pos.distance_to(to_pos)
		if lane_len <= 0.0:
			_stop_swarm_sfx(int(packet.get("id", -1)))
			swarm_packets.remove_at(i)
			continue
		var prev_t: float = packet["t"]
		var owner_id: int = int(packet.get("owner_id", 0))
		var lane_id: int = int(packet.get("lane_id", -1))
		var speed: float = _unit_speed_px(owner_id, lane_id) * float(packet["speed_mult"])
		packet["t"] += (speed * dt) / lane_len
		packet["payload"] += _scoop_units(packet, prev_t)
		if packet["t"] >= 1.0:
			if _are_allied_owners(to_hive.owner_id, owner_id) and to_hive.power >= 50 and to_hive.shock_ms <= 0.0:
				if _pass_through_swarm(packet, to_hive):
					_stop_swarm_sfx(int(packet.get("id", -1)))
					swarm_packets.remove_at(i)
					continue
			if debug_swarms:
				SFLog.info("SWARM_APPLY", {
					"from_id": int(packet.get("from_id", -1)),
					"to_id": int(packet.get("to_id", -1)),
					"lane_id": int(packet.get("lane_id", -1)),
					"owner_id": owner_id,
					"payload": int(packet.get("payload", 0)),
					"is_passthrough": bool(packet.get("is_passthrough", false))
				})
			for _j in range(int(packet["payload"])):
				_apply_unit_arrival(owner_id, to_hive, int(packet.get("from_id", -1)), int(packet.get("lane_id", -1)), "other")
			dbg("SF: swarm arrive %d payload=%d" % [to_hive.id, packet["payload"]])
			_stop_swarm_sfx(int(packet.get("id", -1)))
			swarm_packets.remove_at(i)
		else:
			swarm_packets[i] = packet

func _preflag_ties(groups: Dictionary) -> void:
	var keys: Array = groups.keys()
	keys.sort_custom(Callable(self, "_arrival_key_less"))
	for key in keys:
		var indices: Array = groups[key]
		if indices.size() < 2:
			continue
		var split: Array = key.split(":")
		if split.size() != 2:
			continue
		var hive_id: int = int(split[0])
		var bucket_us: int = int(split[1])
		var counts: Dictionary = {}
		var min_us: int = 2147483647
		var max_us: int = 0
		for idx in indices:
			var idx_i: int = int(idx)
			if idx_i < 0 or idx_i >= units.size():
				continue
			var unit: Dictionary = units[idx_i]
			if bool(unit.get("dead", false)) or not bool(unit.get("alive", true)):
				continue
			var from_id: int = int(unit.get("from_id", -1))
			var to_id: int = int(unit.get("to_id", -1))
			if from_id <= 0 or to_id != hive_id:
				continue
			var expected_lane_key := ""
			if state != null:
				expected_lane_key = state.lane_key(from_id, to_id)
			var unit_lane_key := str(unit.get("lane_key", ""))
			if not expected_lane_key.is_empty() and not unit_lane_key.is_empty() and unit_lane_key != expected_lane_key:
				continue
			var owner_id: int = int(unit["owner_id"])
			counts[owner_id] = int(counts.get(owner_id, 0)) + 1
			var arrival_us: int = int(unit.get("arrival_us", sim_time_us))
			if arrival_us < min_us:
				min_us = arrival_us
			if arrival_us > max_us:
				max_us = arrival_us
		if counts.size() != 2:
			continue
		if max_us - min_us > TIE_WINDOW_US:
			continue
		var pids: Array = counts.keys()
		var p1: int = int(pids[0])
		var p2: int = int(pids[1])
		if int(counts[p1]) != int(counts[p2]):
			continue
		_get_or_create_tie_winner(hive_id, p1, p2, bucket_us)

func _resolve_arrivals(groups: Dictionary, remove_indices: Array[int], remove_set: Dictionary) -> void:
	var keys: Array = groups.keys()
	keys.sort_custom(Callable(self, "_arrival_key_less"))
	for key in keys:
		var indices: Array = groups[key]
		if indices.is_empty():
			continue
		var split: Array = key.split(":")
		if split.size() != 2:
			continue
		var hive_id: int = int(split[0])
		var bucket_us: int = int(split[1])
		var to_hive: HiveData = _find_hive_by_id(hive_id)
		if to_hive == null:
			for idx in indices:
				var idx_i: int = int(idx)
				if remove_set.has(idx_i):
					continue
				remove_set[idx_i] = true
				remove_indices.append(idx_i)
			continue
		var counts: Dictionary = {}
		var min_us: int = 2147483647
		var max_us: int = 0
		for idx in indices:
			var idx_i: int = int(idx)
			if idx_i < 0 or idx_i >= units.size():
				continue
			if remove_set.has(idx_i):
				continue
			var unit: Dictionary = units[idx_i]
			if bool(unit.get("dead", false)) or not bool(unit.get("alive", true)):
				remove_set[idx_i] = true
				remove_indices.append(idx_i)
				continue
			var from_id: int = int(unit.get("from_id", -1))
			var to_id: int = int(unit.get("to_id", -1))
			if from_id <= 0 or to_id != hive_id:
				remove_set[idx_i] = true
				remove_indices.append(idx_i)
				continue
			var expected_lane_key := ""
			if state != null:
				expected_lane_key = state.lane_key(from_id, to_id)
			var unit_lane_key := str(unit.get("lane_key", ""))
			if not expected_lane_key.is_empty() and not unit_lane_key.is_empty() and unit_lane_key != expected_lane_key:
				remove_set[idx_i] = true
				remove_indices.append(idx_i)
				continue
			var owner_id: int = int(unit["owner_id"])
			counts[owner_id] = int(counts.get(owner_id, 0)) + 1
			var arrival_us: int = int(unit.get("arrival_us", sim_time_us))
			if arrival_us < min_us:
				min_us = arrival_us
			if arrival_us > max_us:
				max_us = arrival_us
		var is_tie: bool = false
		var p1: int = -1
		var p2: int = -1
		if counts.size() == 2 and (max_us - min_us) <= TIE_WINDOW_US:
			var pids: Array = counts.keys()
			p1 = int(pids[0])
			p2 = int(pids[1])
			if int(counts[p1]) == int(counts[p2]):
				is_tie = true
		if is_tie:
			var winner: int = _get_or_create_tie_winner(hive_id, p1, p2, bucket_us)
			for idx in indices:
				var idx_i: int = int(idx)
				if idx_i < 0 or idx_i >= units.size():
					continue
				if remove_set.has(idx_i):
					continue
				var unit: Dictionary = units[idx_i]
				if bool(unit.get("dead", false)) or not bool(unit.get("alive", true)):
					remove_set[idx_i] = true
					remove_indices.append(idx_i)
					continue
				var from_id: int = int(unit.get("from_id", -1))
				var to_id: int = int(unit.get("to_id", -1))
				if from_id <= 0 or to_id != hive_id:
					remove_set[idx_i] = true
					remove_indices.append(idx_i)
					continue
				var expected_lane_key := ""
				if state != null:
					expected_lane_key = state.lane_key(from_id, to_id)
				var unit_lane_key := str(unit.get("lane_key", ""))
				if not expected_lane_key.is_empty() and not unit_lane_key.is_empty() and unit_lane_key != expected_lane_key:
					remove_set[idx_i] = true
					remove_indices.append(idx_i)
					continue
				var attacker_id: int = int(unit["owner_id"])
				_record_arrival_for_contest(to_hive.id, attacker_id)
				if attacker_id == winner:
					var before_owner: int = to_hive.owner_id
					var before_power: int = to_hive.power
					_apply_unit_arrival(attacker_id, to_hive, int(unit.get("from_id", -1)), int(unit.get("lane_id", -1)), "edge_hit")
					var after_owner: int = to_hive.owner_id
					var after_power: int = to_hive.power
					var interval_ms: float = _hive_spawn_interval_ms(to_hive)
					var attacker_label: String = _owner_label(attacker_id)
					var before_label: String = _owner_label(before_owner)
					var after_label: String = _owner_label(after_owner)
					dbg("SF: arrive unit %d at hive %d attacker=%s dst_owner %s->%s pwr %d->%d interval_ms=%.1f" % [
						unit["id"],
						to_hive.id,
						attacker_label,
						before_label,
						after_label,
						before_power,
						after_power,
						interval_ms
					])
				_kill_unit(idx_i, unit, "edge_hit", remove_indices, remove_set)
			_show_tie_toast(winner)
			_queue_event({"type": "coin_flip", "hive_id": hive_id})
			dbg("SF: TIE hive=%d p=%d vs %d bucket=%d winner=%d" % [hive_id, p1, p2, bucket_us, winner])
		else:
			indices.sort_custom(Callable(self, "_sort_arrival_indices"))
			for idx in indices:
				var idx_i: int = int(idx)
				if idx_i < 0 or idx_i >= units.size():
					continue
				if remove_set.has(idx_i):
					continue
				var unit: Dictionary = units[idx_i]
				if bool(unit.get("dead", false)) or not bool(unit.get("alive", true)):
					remove_set[idx_i] = true
					remove_indices.append(idx_i)
					continue
				var from_id: int = int(unit.get("from_id", -1))
				var to_id: int = int(unit.get("to_id", -1))
				if from_id <= 0 or to_id != hive_id:
					remove_set[idx_i] = true
					remove_indices.append(idx_i)
					continue
				var expected_lane_key := ""
				if state != null:
					expected_lane_key = state.lane_key(from_id, to_id)
				var unit_lane_key := str(unit.get("lane_key", ""))
				if not expected_lane_key.is_empty() and not unit_lane_key.is_empty() and unit_lane_key != expected_lane_key:
					remove_set[idx_i] = true
					remove_indices.append(idx_i)
					continue
				var attacker_id: int = int(unit["owner_id"])
				_record_arrival_for_contest(to_hive.id, attacker_id)
				var before_owner: int = to_hive.owner_id
				var before_power: int = to_hive.power
				_apply_unit_arrival(attacker_id, to_hive, int(unit.get("from_id", -1)), int(unit.get("lane_id", -1)), "edge_hit")
				var after_owner: int = to_hive.owner_id
				var after_power: int = to_hive.power
				var interval_ms: float = _hive_spawn_interval_ms(to_hive)
				var attacker_label: String = _owner_label(attacker_id)
				var before_label: String = _owner_label(before_owner)
				var after_label: String = _owner_label(after_owner)
				dbg("SF: arrive unit %d at hive %d attacker=%s dst_owner %s->%s pwr %d->%d interval_ms=%.1f" % [
					unit["id"],
					to_hive.id,
					attacker_label,
					before_label,
					after_label,
					before_power,
					after_power,
					interval_ms
				])
				_kill_unit(idx_i, unit, "edge_hit", remove_indices, remove_set)

func _finalize_unit_removals(remove_indices: Array[int]) -> void:
	if not remove_indices.is_empty():
		dbg_mark_event("unit_prune")
	remove_indices.sort()
	var last_removed := -1
	for i in range(remove_indices.size() - 1, -1, -1):
		var idx: int = int(remove_indices[i])
		if idx == last_removed:
			continue
		last_removed = idx
		if idx >= 0 and idx < units.size():
			units.remove_at(idx)

func _record_arrival_for_contest(hive_id: int, attacker_id: int) -> void:
	var entries: Array = arrival_history.get(hive_id, [])
	entries.append({"t_us": sim_time_us, "pid": attacker_id})
	_prune_arrival_entries(entries, sim_time_us - CONTEST_WINDOW_US)
	arrival_history[hive_id] = entries

func _prune_arrival_entries(entries: Array, cutoff_us: int) -> void:
	while entries.size() > 0 and int(entries[0]["t_us"]) < cutoff_us:
		entries.remove_at(0)

func _arrival_counts_last_window(hive_id: int, now_us: int) -> Dictionary:
	var entries: Array = arrival_history.get(hive_id, [])
	_prune_arrival_entries(entries, now_us - CONTEST_WINDOW_US)
	arrival_history[hive_id] = entries
	var counts: Dictionary = {}
	for entry in entries:
		var pid: int = int(entry["pid"])
		counts[pid] = int(counts.get(pid, 0)) + 1
	return counts

func _incoming_enemy_streams_count(hive_id: int, owner_id: int) -> int:
	if owner_id == 0:
		return 0
	var count := 0
	for lane in state.lanes:
		if lane.send_a and lane.b_id == hive_id:
			var a: HiveData = _find_hive_by_id(lane.a_id)
			if a != null and a.owner_id != 0 and not _are_allied_owners(a.owner_id, owner_id):
				count += 1
		if lane.send_b and lane.a_id == hive_id:
			var b: HiveData = _find_hive_by_id(lane.b_id)
			if b != null and b.owner_id != 0 and not _are_allied_owners(b.owner_id, owner_id):
				count += 1
	return count

func _update_contest_logs() -> void:
	for hive in state.hives:
		var counts: Dictionary = _arrival_counts_last_window(hive.id, sim_time_us)
		var contested: bool = _incoming_enemy_streams_count(hive.id, hive.owner_id) >= 2 or counts.size() >= 2
		if not contested:
			continue
		var last_log: int = int(contest_last_log_us.get(hive.id, -CONTEST_LOG_INTERVAL_US))
		if sim_time_us - last_log < CONTEST_LOG_INTERVAL_US:
			continue
		contest_last_log_us[hive.id] = sim_time_us
		var interval_ms: float = _hive_spawn_interval_ms(hive)
		var pids: Array = counts.keys()
		pids.sort()
		var parts: Array[String] = []
		for pid in pids:
			parts.append("%s=%d" % [_owner_label(int(pid)), counts[pid]])
		var arrivals_text := "none" if parts.is_empty() else " ".join(parts)
		var owner_label: String = _owner_label(hive.owner_id)
		dbg("SF: contest hive %d owner=%s pwr=%d interval_ms=%.1f last2s arrivals: %s" % [
			hive.id,
			owner_label,
			hive.power,
			interval_ms,
			arrivals_text
		])

func _filter_group_indices(groups: Dictionary, remove_set: Dictionary) -> void:
	for key in groups.keys():
		var indices: Array = groups[key]
		if indices.is_empty():
			continue
		var filtered: Array = []
		for idx in indices:
			if not remove_set.has(int(idx)):
				filtered.append(idx)
		if filtered.is_empty():
			groups.erase(key)
		else:
			groups[key] = filtered

func _refund_recalled_unit(unit: Dictionary) -> void:
	var from_id: int = int(unit.get("from_id", -1))
	if from_id == -1:
		return
	var hive: HiveData = _find_hive_by_id(from_id)
	if hive == null:
		return
	var before_power: int = hive.power
	hive.power = min(50, hive.power + 1)
	if hive.power > before_power:
		_note_render_dirty()
		return

func record_lane_collision(lane_key: String, collision: Variant) -> void:
	if state == null:
		return
	var lane_state: Dictionary = state.lane_sim_by_key.get(lane_key, {})
	if lane_state.is_empty():
		return
	var a_id: int = int(lane_state.get("a_id", 0))
	var b_id: int = int(lane_state.get("b_id", 0))
	if a_id <= 0 or b_id <= 0:
		return
	var t := 0.5
	if typeof(collision) == TYPE_VECTOR2:
		var a_hive: HiveData = _find_hive_by_id(a_id)
		var b_hive: HiveData = _find_hive_by_id(b_id)
		if a_hive == null or b_hive == null:
			return
		var a_pos := _cell_center(a_hive.grid_pos)
		var b_pos := _cell_center(b_hive.grid_pos)
		var ab := b_pos - a_pos
		var len_sq := ab.length_squared()
		if len_sq <= 0.0001:
			return
		t = clamp((collision - a_pos).dot(ab) / len_sq, 0.0, 1.0)
	else:
		t = clamp(float(collision), 0.0, 1.0)
	if not ENABLE_DYNAMIC_LANE_FRONTS:
		t = STATIC_LANE_FRONT_T
	lane_state["last_collision_t"] = t
	lane_state["front_t"] = t
	state.lane_sim_by_key[lane_key] = lane_state
	SFLog.info("FRONT_UPDATE: lane=%s t=%.3f" % [lane_key, t])
	_note_render_dirty()

func _collect_lane_collisions(remove_indices: Array[int], remove_set: Dictionary) -> void:
	for lane in state.lanes:
		var a_hive: HiveData = _find_hive_by_id(lane.a_id)
		var b_hive: HiveData = _find_hive_by_id(lane.b_id)
		if a_hive == null or b_hive == null:
			continue
		if a_hive.owner_id == 0 or b_hive.owner_id == 0:
			continue
		if _are_allied_owners(a_hive.owner_id, b_hive.owner_id):
			continue
		var lane_key := state.lane_key(lane.a_id, lane.b_id)
		var a_pos := _cell_center(a_hive.grid_pos)
		var b_pos := _cell_center(b_hive.grid_pos)
		var a_units: Array = []
		var b_units: Array = []
		for i in range(units.size()):
			if remove_set.has(i):
				continue
			var unit: Dictionary = units[i]
			if bool(unit.get("recall", false)):
				continue
			if int(unit.get("lane_id", -1)) != lane.id:
				continue
			var t_val: float = float(unit.get("t", 0.0))
			if t_val <= 0.0 or t_val >= 1.0:
				continue
			var from_id: int = int(unit.get("from_id", -1))
			if from_id == lane.a_id:
				a_units.append({"idx": i, "pos": t_val})
			elif from_id == lane.b_id:
				b_units.append({"idx": i, "pos": 1.0 - t_val})
		if a_units.is_empty() or b_units.is_empty():
			continue
		a_units.sort_custom(Callable(self, "_sort_collision_desc"))
		b_units.sort_custom(Callable(self, "_sort_collision_asc"))
		var ai := 0
		var bi := 0
		while ai < a_units.size() and bi < b_units.size():
			var a_entry: Dictionary = a_units[ai]
			var b_entry: Dictionary = b_units[bi]
			if float(a_entry["pos"]) >= float(b_entry["pos"]):
				dbg_mark_event("unit_collision")
				var a_idx: int = int(a_entry["idx"])
				var b_idx: int = int(b_entry["idx"])
				if not remove_set.has(a_idx):
					remove_indices.append(a_idx)
					remove_set[a_idx] = true
				if not remove_set.has(b_idx):
					remove_indices.append(b_idx)
					remove_set[b_idx] = true
				var impact_f: float = clamp((float(a_entry["pos"]) + float(b_entry["pos"])) * 0.5, 0.0, 1.0)
				if not ENABLE_DYNAMIC_LANE_FRONTS:
					impact_f = STATIC_LANE_FRONT_T
				lane.last_impact_f = impact_f
				record_lane_collision(lane_key, a_pos.lerp(b_pos, impact_f))
				_spawn_debris_for_lane(lane, 0, impact_f)
				ai += 1
				bi += 1
			else:
				break

func _sort_collision_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a["pos"]) > float(b["pos"])

func _sort_collision_asc(a: Dictionary, b: Dictionary) -> bool:
	return float(a["pos"]) < float(b["pos"])

func _sort_arrival_indices(a: int, b: int) -> bool:
	var ua: Dictionary = units[a]
	var ub: Dictionary = units[b]
	return int(ua.get("arrival_us", 0)) < int(ub.get("arrival_us", 0))

func _arrival_key_less(a: String, b: String) -> bool:
	var a_split: Array = a.split(":")
	var b_split: Array = b.split(":")
	if a_split.size() != 2 or b_split.size() != 2:
		return a < b
	var a_hive: int = int(a_split[0])
	var b_hive: int = int(b_split[0])
	var a_bucket: int = int(a_split[1])
	var b_bucket: int = int(b_split[1])
	if a_bucket == b_bucket:
		return a_hive < b_hive
	return a_bucket < b_bucket

func _make_pair_key(hive_id: int, p1: int, p2: int) -> String:
	var low: int = min(p1, p2)
	var high: int = max(p1, p2)
	return "h%d:%d-%d" % [hive_id, low, high]

func _seeded_coin_flip(seed: int, hive_id: int, bucket_us: int, p_low: int, p_high: int) -> int:
	var x: int = seed
	x ^= hive_id * 73856093
	x ^= bucket_us * 19349663
	x ^= p_low * 83492791
	x ^= p_high * 15485863
	if x < 0:
		x = -x
	if (x & 1) == 0:
		return p_low
	return p_high

func _resolve_tie_winner(hive_id: int, bucket_us: int, p1: int, p2: int) -> int:
	var low: int = min(p1, p2)
	var high: int = max(p1, p2)
	var pair_key: String = _make_pair_key(hive_id, low, high)
	if not tie_history.has(pair_key):
		var first: int = _seeded_coin_flip(match_seed, hive_id, bucket_us, low, high)
		tie_history[pair_key] = {"count": 1, "first_winner": first}
		return first
	var entry: Dictionary = tie_history[pair_key]
	var count: int = int(entry["count"]) + 1
	var first_winner: int = int(entry["first_winner"])
	entry["count"] = count
	tie_history[pair_key] = entry
	if (count % 2) == 1:
		return first_winner
	return low if first_winner == high else high

func _get_or_create_tie_winner(hive_id: int, p1: int, p2: int, bucket_us: int) -> int:
	var pair_key: String = _make_pair_key(hive_id, p1, p2)
	var cache_key: String = "%s:%d" % [pair_key, bucket_us]
	if tie_cache.has(cache_key):
		var cached: Dictionary = tie_cache[cache_key]
		if sim_time_us <= int(cached["expires_us"]):
			return int(cached["winner"])
	var winner: int = _resolve_tie_winner(hive_id, bucket_us, p1, p2)
	tie_cache[cache_key] = {"winner": winner, "expires_us": bucket_us + TIE_CACHE_EXPIRE_US}
	return winner

func _show_tie_toast(winner_id: int) -> void:
	if tie_toast == null:
		return
	tie_toast.text = "TIE — coin flip (P%d wins)" % winner_id
	tie_toast.visible = true
	tie_toast_ms = 1200.0

func _play_coin_flip_sfx(hive_id: int) -> void:
	if audio_system == null:
		return
	audio_system._play_coin_flip_sfx(hive_id, sim_time_us)

func _scoop_units(packet: Dictionary, prev_t: float) -> int:
	if unit_system != null:
		return unit_system.scoop_units_for_swarm(
			int(packet.get("from_id", -1)),
			int(packet.get("to_id", -1)),
			int(packet.get("owner_id", 0)),
			int(packet.get("lane_id", -1)),
			prev_t,
			float(packet.get("t", 0.0)),
			int(packet.get("dir", 0))
		)
	var scooped: int = 0
	for i in range(units.size() - 1, -1, -1):
		var unit: Dictionary = units[i]
		if unit["owner_id"] != packet["owner_id"]:
			continue
		if unit["lane_id"] != packet["lane_id"]:
			continue
		if unit["from_id"] != packet["from_id"] or unit["to_id"] != packet["to_id"]:
			continue
		if unit["t"] >= prev_t and unit["t"] <= packet["t"]:
			units.remove_at(i)
			scooped += 1
	return scooped

func _update_debris(dt: float) -> void:
	if debris.is_empty():
		return
	_note_render_dirty()
	for i in range(debris.size() - 1, -1, -1):
		var d: Dictionary = debris[i]
		d["pos"] += d["vel"] * dt
		d["vel"] *= DEBRIS_DAMP
		d["life"] -= dt
		if d["life"] <= 0.0:
			debris.remove_at(i)
		else:
			debris[i] = d

func _update_match_state(dt: float) -> void:
	if game_over:
		return
	_update_control_bar()
	var remaining_ms := _get_match_remaining_ms()
	if OpsState.in_overtime and not overtime_active:
		_enter_overtime()
	if state == null:
		var alive_players: Array = _alive_players()
		if alive_players.size() == 1:
			_end_game(alive_players[0], "Elimination")
			return
		if remaining_ms <= 0:
			var winner: int = _resolve_timeout_winner()
			_end_game(winner, "Timeout")

func _validate_state() -> void:
	if not OS.is_debug_build() or not DEV_STATE_CHECKS:
		return
	var errors: Array[String] = []
	var hive_ids: Dictionary = {}
	for lane in state.lanes:
		var a: HiveData = _find_hive_by_id(lane.a_id)
		var b: HiveData = _find_hive_by_id(lane.b_id)
		if a == null or b == null:
			errors.append("Lane %d missing hive" % lane.id)
			continue
		if _are_allied_owners(a.owner_id, b.owner_id) and lane.send_a and lane.send_b:
			errors.append("Lane %d friendly both intents" % lane.id)
	for hive in state.hives:
		if hive_ids.has(hive.id):
			errors.append("Hive id duplicate: %d" % hive.id)
		else:
			hive_ids[hive.id] = true
		if hive.power < 1 or hive.power > 50:
			errors.append("Hive %d power out of range: %d" % [hive.id, hive.power])
	if errors.is_empty():
		return
	error_count += errors.size()
	sim_running = false
	dbg("SF: STATE INVALID")
	for msg in errors:
		dbg("SF: STATE ERR %s" % msg)

func _update_control_bar() -> void:
	if control_bar == null:
		return
	var totals: Dictionary = _player_power_totals()
	control_bar.set_powers(totals[1], totals[2], totals[3], totals[4])

func _update_selection_hud() -> void:
	if selection_hud == null:
		return
	if sel == null:
		selection_hud.visible = false
		return
	var sel_ref = state.selection if state != null else null
	var selected_hive_id := int(sel_ref.selected_hive_id) if sel_ref != null else -1
	var selected_lane_id := int(sel_ref.selected_lane_id) if sel_ref != null else -1
	if selected_hive_id != -1:
		var hive: HiveData = _find_hive_by_id(selected_hive_id)
		if hive != null:
			var outgoing_count: int = _active_outgoing_intent_count(hive.id)
			selection_hud.show_hive(hive, outgoing_count)
			return
	if selected_lane_id != -1:
		var lane: LaneData = _find_lane_by_id(selected_lane_id)
		if lane != null:
			var a: HiveData = _find_hive_by_id(lane.a_id)
			var b: HiveData = _find_hive_by_id(lane.b_id)
			var mode: String = "unknown"
			if a != null and b != null:
				mode = _lane_mode(a, b)
			var impact_f: float = -1.0
			if mode == "opposing":
				impact_f = lane.last_impact_f
			selection_hud.show_lane(lane, mode, impact_f)
			return
	selection_hud.visible = false

func _update_buff_ui() -> void:
	if buffs_label == null:
		return
	if not buffs_enabled or buff_states.is_empty():
		buffs_label.visible = false
		return
	var buff_state: BuffState = buff_states.get(active_player_id)
	if buff_state == null:
		buffs_label.visible = false
		return
	var now_ms: int = int(_authoritative_sim_time_us() / 1000)
	var lines: Array[String] = []
	for i in range(buff_state.slots.size()):
		var slot: Dictionary = buff_state.slots[i]
		if not bool(slot.get("active", false)):
			continue
		var buff_id: String = str(slot.get("id", ""))
		var buff_def: Dictionary = BuffCatalog.get_buff(buff_id)
		var name: String = str(buff_def.get("name", buff_id))
		var ends_ms: int = int(slot.get("ends_ms", 0))
		var remaining_ms: int = max(0, ends_ms - now_ms)
		lines.append("%d) %s %.1fs" % [i + 1, name, remaining_ms / 1000.0])
	if lines.is_empty():
		buffs_label.text = "BUFFS: none"
	else:
		buffs_label.text = "BUFFS:\\n" + "\\n".join(lines)
	buffs_label.visible = true

func _update_timer_ui() -> void:
	_ensure_timer_hud()
	if _timer_root == null or timer_label == null:
		return
	var should_show := OpsState.timer_visible_started
	_timer_root.visible = should_show
	timer_label.visible = should_show
	if OpsState.timer_visible_started and not _timer_branch_logged:
		_timer_branch_logged = true
		SFLog.info("TIMER_BRANCH", {
			"ops_iid": int(OpsState.get_instance_id()),
			"timer_visible_started": OpsState.timer_visible_started,
			"in_overtime": OpsState.in_overtime,
			"timer_label_null": timer_label == null
		})
	if OpsState.timer_visible_started and not _timer_ui_logged:
		SFLog.info("TIMER_ARENA_SEES_VISIBLE", {
			"ops_iid": int(OpsState.get_instance_id()),
			"timer_visible_started": OpsState.timer_visible_started,
			"match_clock_started": OpsState.match_clock_started,
			"in_overtime": OpsState.in_overtime,
			"remaining_ms": int(_get_match_remaining_ms()),
			"timer_label_ok": timer_label != null,
			"timer_label_path": _node_path_for_log(timer_label)
		})
	if OpsState.timer_visible_started:
		_update_timer_label()

func _ensure_timer_hud() -> void:
	if _timer_root != null and is_instance_valid(_timer_root) and timer_label != null and is_instance_valid(timer_label):
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	_timer_layer = _ensure_timer_layer()
	var existing := _timer_layer.get_node_or_null("MatchTimer")
	if existing == null:
		existing = _timer_layer.find_child("MatchTimer", true, false)
	if existing != null and existing is Control:
		_timer_root = existing as Control
	else:
		var root_control := Control.new()
		root_control.name = "MatchTimer"
		root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_timer_layer.add_child(root_control)
		_timer_root = root_control
	_ensure_timer_layer(_timer_root)
	_force_fullscreen_anchors(_timer_root)
	if timer_label == null or not is_instance_valid(timer_label):
		var existing_label := _timer_root.get_node_or_null("MatchTimerLabel")
		if existing_label == null:
			existing_label = _timer_root.find_child("MatchTimerLabel", true, false)
		if existing_label != null and existing_label is Label:
			timer_label = existing_label as Label
	if timer_label == null or not is_instance_valid(timer_label) or timer_label.get_parent() != _timer_root:
		var label := Label.new()
		label.name = "MatchTimerLabel"
		label.text = ""
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.anchor_left = 0.0
		label.anchor_right = 0.0
		label.anchor_top = 0.0
		label.anchor_bottom = 0.0
		label.offset_left = 10.0
		label.offset_top = 10.0
		label.offset_right = 1010.0
		label.offset_bottom = 310.0
		label.visible = false
		label.z_as_relative = false
		label.z_index = 900
		_timer_root.add_child(label)
		timer_label = label
	var debug_bg := _timer_root.get_node_or_null("MatchTimerDebugBg")
	if debug_bg != null:
		debug_bg.visible = false
	timer_label.visible = false
	timer_label.modulate = Color(1, 1, 1, 1)
	timer_label.self_modulate = Color(1, 1, 1, 1)
	if not _timer_ready_logged:
		_timer_ready_logged = true
		SFLog.info("UI_TIMER_READY", {
			"node": _timer_node_info(timer_label),
			"root": _timer_node_info(_timer_root)
		})
	if not _timer_label_bind_logged:
		_timer_label_bind_logged = true
		var font_before: int = _control_font_size(timer_label)
		timer_label.add_theme_color_override("font_color", _local_countdown_color())
		timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		timer_label.add_theme_constant_override("outline_size", 4)
		timer_label.add_theme_font_size_override("font_size", 200)
		var font_after: int = _control_font_size(timer_label)
		SFLog.info("UI_TIMER_BIND", {
			"node": _timer_node_info(timer_label),
			"font_before": font_before,
			"font_after": font_after
		})
		SFLog.info("TIMER_LABEL_BIND", {
			"path": _node_path_for_log(timer_label),
			"inside_tree": timer_label.is_inside_tree(),
			"visible": timer_label.visible,
			"z_index": timer_label.z_index,
			"global_position": timer_label.global_position,
			"anchors": {
				"anchor_left": timer_label.anchor_left,
				"anchor_top": timer_label.anchor_top,
				"anchor_right": timer_label.anchor_right,
				"anchor_bottom": timer_label.anchor_bottom
			},
			"offsets": {
				"offset_left": timer_label.offset_left,
				"offset_top": timer_label.offset_top,
				"offset_right": timer_label.offset_right,
				"offset_bottom": timer_label.offset_bottom
			}
		})
	_center_match_timer()

func _ensure_timer_layer(match_timer: Control = null) -> CanvasLayer:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	var root := tree.root
	var hud: CanvasLayer = null
	var current_scene: Node = tree.current_scene
	if current_scene != null:
		hud = current_scene.get_node_or_null("HUDCanvasLayer") as CanvasLayer
		if hud == null:
			hud = current_scene.get_node_or_null("UI") as CanvasLayer
	if hud == null:
		hud = root.get_node_or_null("HUDCanvasLayer") as CanvasLayer
	if hud == null:
		hud = CanvasLayer.new()
		hud.name = "HUDCanvasLayer"
		hud.layer = 50
		root.add_child(hud)
	if match_timer != null and match_timer.get_parent() != hud:
		match_timer.reparent(hud)
	return hud

func _force_fullscreen_anchors(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0

func _control_font_size(control: Control) -> int:
	if control == null:
		return -1
	if control.has_theme_font_size_override("font_size") or control.has_theme_font_size("font_size"):
		return int(control.get_theme_font_size("font_size"))
	return -1

func _timer_node_info(node: CanvasItem) -> Dictionary:
	if node == null:
		return {
			"path": "<null>",
			"class": "<null>",
			"inside_tree": false,
			"visible_in_tree": false,
			"modulate": Color(0, 0, 0, 0),
			"self_modulate": Color(0, 0, 0, 0),
			"scale": Vector2.ZERO,
			"size": Vector2.ZERO,
			"font_size": -1
		}
	var size: Vector2 = Vector2.ZERO
	var font_size: int = -1
	if node is Control:
		var control: Control = node as Control
		size = control.size
		font_size = _control_font_size(control)
	return {
		"path": _node_path_for_log(node),
		"class": node.get_class(),
		"inside_tree": node.is_inside_tree(),
		"visible_in_tree": node.is_visible_in_tree(),
		"modulate": node.modulate,
		"self_modulate": node.self_modulate,
		"scale": node.scale,
		"size": size,
		"font_size": font_size
	}

func _get_match_remaining_ms() -> int:
	if OpsState.match_clock_started:
		return int(OpsState.match_remaining_ms)
	return int(OpsState.match_duration_ms)

func _update_timer_label() -> void:
	if timer_label == null:
		return
	if OpsState.timer_visible_started and not _timer_ui_logged:
		_timer_ui_logged = true
		var anchors := {
			"anchor_left": timer_label.anchor_left,
			"anchor_top": timer_label.anchor_top,
			"anchor_right": timer_label.anchor_right,
			"anchor_bottom": timer_label.anchor_bottom
		}
		var offsets := {
			"offset_left": timer_label.offset_left,
			"offset_top": timer_label.offset_top,
			"offset_right": timer_label.offset_right,
			"offset_bottom": timer_label.offset_bottom
		}
		SFLog.info("TIMER_UI_STATE", {
			"label_null": timer_label == null,
			"path": _node_path_for_log(timer_label),
			"inside_tree": timer_label.is_inside_tree() if timer_label != null else false,
			"visible": timer_label.visible if timer_label != null else false,
			"modulate_a": timer_label.modulate.a if timer_label != null else -1.0,
			"self_modulate_a": timer_label.self_modulate.a if timer_label != null else -1.0,
			"global_position": timer_label.global_position if timer_label != null else Vector2.ZERO,
			"size": timer_label.size if timer_label != null else Vector2.ZERO,
			"anchors": anchors,
			"offsets": offsets,
			"parent_chain": _dump_timer_parent_chain(timer_label)
		})
	timer_label.modulate = Color(1, 1, 1, 1)
	timer_label.self_modulate = Color(1, 1, 1, 1)
	timer_label.add_theme_color_override("font_color", _local_countdown_color())
	timer_label.visible = true
	var remaining_ms := int(OpsState.match_remaining_ms)
	if remaining_ms < 0:
		remaining_ms = 0
	var total_sec: int = int(ceil(float(remaining_ms) / 1000.0))
	var minutes: int = int(total_sec / 60.0)
	var seconds: int = total_sec % 60
	if total_sec != _timer_last_seconds:
		_timer_last_seconds = total_sec
		SFLog.info("UI_TIMER_TICK", {
			"node": _timer_node_info(timer_label),
			"remaining_ms": remaining_ms,
			"seconds": total_sec
		})
		SFLog.info("TIMER_TICK", {"remaining_ms": remaining_ms})
	var next_text: String = "%d:%02d" % [minutes, seconds]
	if timer_label.text != next_text:
		timer_label.text = next_text
		SFLog.info("UI_TIMER_TEXT_SET", {
			"node": _timer_node_info(timer_label),
			"text": next_text
		})

func _ensure_progressive_counter_hud() -> void:
	if _progressive_counter_root != null and is_instance_valid(_progressive_counter_root) and _progressive_counter_label != null and is_instance_valid(_progressive_counter_label) and _progressive_star_decay_hud != null and is_instance_valid(_progressive_star_decay_hud):
		return
	var layer: CanvasLayer = _ensure_timer_layer()
	if layer == null:
		return
	var existing: Control = layer.get_node_or_null("ProgressiveCounter") as Control
	if existing != null:
		_progressive_counter_root = existing
	else:
		var root_control := Control.new()
		root_control.name = "ProgressiveCounter"
		root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(root_control)
		_progressive_counter_root = root_control
	_force_fullscreen_anchors(_progressive_counter_root)
	var label: Label = _progressive_counter_root.get_node_or_null("ProgressiveStarsLabel") as Label
	if label == null:
		label = Label.new()
		label.name = "ProgressiveStarsLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.anchor_left = 1.0
		label.anchor_right = 1.0
		label.anchor_top = 0.0
		label.anchor_bottom = 0.0
		label.offset_left = -430.0
		label.offset_top = 18.0
		label.offset_right = -28.0
		label.offset_bottom = 82.0
		label.z_as_relative = false
		label.z_index = 910
		label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_font_size_override("font_size", 30)
		_progressive_counter_root.add_child(label)
	_progressive_counter_label = label
	var star_hud: Control = _progressive_counter_root.get_node_or_null("ProgressiveStarDecayHud") as Control
	if star_hud == null:
		star_hud = ProgressiveStarDecayHudScript.new()
		star_hud.name = "ProgressiveStarDecayHud"
		star_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star_hud.anchor_left = 1.0
		star_hud.anchor_right = 1.0
		star_hud.anchor_top = 0.0
		star_hud.anchor_bottom = 0.0
		star_hud.offset_left = -410.0
		star_hud.offset_top = 74.0
		star_hud.offset_right = -36.0
		star_hud.offset_bottom = 136.0
		star_hud.z_as_relative = false
		star_hud.z_index = 909
		_progressive_counter_root.add_child(star_hud)
	_progressive_star_decay_hud = star_hud
	_progressive_counter_root.visible = false
	_progressive_counter_label.visible = false
	_progressive_star_decay_hud.visible = false

func _update_progressive_counter_ui() -> void:
	_ensure_progressive_counter_hud()
	if _progressive_counter_root == null or _progressive_counter_label == null or _progressive_star_decay_hud == null:
		return
	var visible_now: bool = _is_progressive_runtime_mode()
	_progressive_counter_root.visible = visible_now
	_progressive_counter_label.visible = visible_now
	_progressive_star_decay_hud.visible = visible_now
	if not visible_now:
		return
	var tree: SceneTree = get_tree()
	var total_stars: int = maxi(0, int(tree.get_meta("progressive_total_stars", 0))) if tree != null else 0
	var max_stars: int = maxi(total_stars, int(tree.get_meta("progressive_max_stars", 0))) if tree != null else total_stars
	var stage_number: int = maxi(1, int(tree.get_meta("progressive_stage_number", int(tree.get_meta(TREE_META_VS_STAGE_CURRENT_INDEX, 0)) + 1))) if tree != null else 1
	var stage_count: int = _progressive_stage_count(tree)
	var text: String = "STARS %d / %d   STAGE %d / %d" % [total_stars, max_stars, stage_number, maxi(stage_number, stage_count)]
	if _progressive_counter_label.text != text:
		_progressive_counter_label.text = text
	var thresholds: Dictionary = {}
	if tree != null:
		var thresholds_any: Variant = tree.get_meta("progressive_thresholds_ms", {})
		if typeof(thresholds_any) == TYPE_DICTIONARY:
			thresholds = thresholds_any as Dictionary
	var elapsed_ms: int = maxi(0, int(OpsState.match_elapsed_ms))
	if _progressive_star_decay_hud.has_method("configure"):
		_progressive_star_decay_hud.call("configure", thresholds, elapsed_ms)

func _dump_timer_parent_chain(node: Node) -> Array:
	var out: Array = []
	var n: Node = node
	while n != null:
		if n is CanvasItem:
			var ci := n as CanvasItem
			out.append({
				"path": _node_path_for_log(ci),
				"visible": ci.visible,
				"modulate_a": ci.modulate.a,
				"self_modulate_a": ci.self_modulate.a
			})
		else:
			out.append({"path": _node_path_for_log(n), "type": n.get_class()})
		n = n.get_parent()
	return out

func _player_hive_counts() -> Dictionary:
	var counts: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
	for hive in state.hives:
		if hive.owner_id >= 1 and hive.owner_id <= 4:
			counts[hive.owner_id] += 1
	return counts

func _player_power_totals() -> Dictionary:
	var totals: Dictionary = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0}
	for hive in state.hives:
		if hive.owner_id >= 1 and hive.owner_id <= 4:
			totals[hive.owner_id] += hive.power
	return totals

func _alive_players() -> Array:
	var alive: Array[int] = []
	var counts: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
	for hive in state.hives:
		if hive.owner_id >= 1 and hive.owner_id <= 4:
			counts[hive.owner_id] += 1
	for pid in counts.keys():
		if counts[pid] > 0:
			alive.append(pid)
	return alive

func _resolve_timeout_winner() -> int:
	var totals: Dictionary = _player_power_totals()
	var counts: Dictionary = _player_hive_counts()
	var landed: Dictionary = units_landed
	var tower_ms: Dictionary = tower_control_ms
	if tower_system != null:
		tower_ms = tower_system.tower_control_ms
	var barracks_ms: Dictionary = barracks_control_ms
	var best_ids: Array = _max_keys(totals)
	if best_ids.size() == 1:
		return best_ids[0]
	best_ids = _max_keys_for_ids(counts, best_ids)
	if best_ids.size() == 1:
		return best_ids[0]
	best_ids = _max_keys_for_ids(landed, best_ids)
	if best_ids.size() == 1:
		return best_ids[0]
	best_ids = _max_keys_for_ids(tower_ms, best_ids)
	if best_ids.size() == 1:
		return best_ids[0]
	best_ids = _max_keys_for_ids(barracks_ms, best_ids)
	if best_ids.size() == 1:
		return best_ids[0]
	return _coin_flip_ids(best_ids)

func _max_keys(values: Dictionary) -> Array:
	var best: Array = []
	var best_val: float = -INF
	for k in values.keys():
		var v: float = float(values[k])
		if v > best_val:
			best_val = v
			best = [k]
		elif v == best_val:
			best.append(k)
	return best

func _max_keys_for_ids(values: Dictionary, ids: Array) -> Array:
	var best: Array = []
	var best_val: float = -INF
	for k in ids:
		var v: float = float(values[k])
		if v > best_val:
			best_val = v
			best = [k]
		elif v == best_val:
			best.append(k)
	return best

func _coin_flip_ids(ids: Array) -> int:
	if ids.is_empty():
		return 1
	var ordered: Array = ids.duplicate()
	ordered.sort()
	var idx: int = int(abs(match_seed)) % ordered.size()
	return int(ordered[idx])

func _end_game(winner: int, reason: String) -> void:
	if game_over:
		return
	if _is_progressive_runtime_mode():
		game_over = true
		winner_id = winner
		end_reason = reason
		sim_running = false
		_on_match_ended(winner, reason)
		if sim_runner != null:
			sim_runner.log_pause_snapshot("arena_end_game_progressive")
		return
	game_over = true
	winner_id = winner
	end_reason = reason
	_commit_match_records(winner)
	sim_running = false
	dbg("SF: WINNER pid=%d" % winner_id)
	var winner_label := "none"
	if winner_id == 0:
		winner_label = "npc"
	elif winner_id > 0:
		winner_label = "p%d" % winner_id
	var duration_s: float = float(sim_time_us) / 1000000.0
	SFLog.info("MATCH_END_SUMMARY: winner=%s duration_s=%.2f captures=%d ot=%s errors=%d" % [
		winner_label,
		duration_s,
		capture_count,
		str(overtime_active),
		error_count
	])
	if outcome_overlay != null:
		var record_slot: int = clampi(active_player_id, 1, 4)
		var record_text: String = _get_player_record_line(record_slot)
		var h2h_text: String = _get_h2h_record_line()
		outcome_overlay.show_outcome(winner_id, reason, active_player_id, record_text, h2h_text)
	if sim_runner != null:
		sim_runner.log_pause_snapshot("arena_end_game")

func _update_towers(dt: float) -> void:
	dbg_mark_event("tower_eval")
	var dt_ms: float = dt * 1000.0
	for tower in towers:
		var prev_owner_id: int = int(tower.get("owner_id", 0))
		var tower_id: int = int(tower.get("id", -1))
		if int(tower.get("required_hive_ids", []).size()) < BARRACKS_MIN_REQ:
			tower["active"] = false
			tower["owner_id"] = 0
			tower["tier"] = 1
			tower["shot_accum_ms"] = 0.0
			_notify_floor_structure_owner_changed("tower", tower_id, prev_owner_id, 0)
			if state != null:
				var node_id: int = int(tower.get("node_id", tower.get("id", -1)))
				if node_id != -1:
					state.structure_owner_by_node_id[node_id] = 0
			continue
		var owner_id: int = 0
		var min_tier: int = 4
		var active: bool = true
		for hive_id_v in tower["required_hive_ids"]:
			var hive_id: int = int(hive_id_v)
			var hive: HiveData = _find_hive_by_id(hive_id)
			if hive == null or hive.owner_id == 0:
				active = false
				break
			if owner_id == 0:
				owner_id = hive.owner_id
			elif hive.owner_id != owner_id:
				active = false
				break
			min_tier = min(min_tier, _hive_tier(hive.power))
		if not active:
			tower["active"] = false
			tower["owner_id"] = 0
			tower["tier"] = 1
			tower["shot_accum_ms"] = 0.0
			_notify_floor_structure_owner_changed("tower", tower_id, prev_owner_id, 0)
			if state != null:
				var node_id: int = int(tower.get("node_id", tower.get("id", -1)))
				if node_id != -1:
					state.structure_owner_by_node_id[node_id] = 0
			continue
		tower["active"] = true
		tower["owner_id"] = owner_id
		tower["tier"] = min_tier
		_notify_floor_structure_owner_changed("tower", tower_id, prev_owner_id, owner_id)
		if state != null:
			var node_id: int = int(tower.get("node_id", tower.get("id", -1)))
			if node_id != -1:
				state.structure_owner_by_node_id[node_id] = owner_id
		if owner_id > 0:
			tower_control_ms[owner_id] = float(tower_control_ms.get(owner_id, 0.0)) + dt_ms
		tower["shot_accum_ms"] += dt_ms
		var interval_ms: float = _tower_interval_ms_for(owner_id, int(tower["tier"]))
		while tower["shot_accum_ms"] >= interval_ms:
			if _tower_shoot(tower):
				tower["shot_accum_ms"] -= interval_ms
			else:
				tower["shot_accum_ms"] = 0.0
				break

func _hive_tier(power: int) -> int:
	if power >= 50:
		return 4
	if power >= 25:
		return 3
	if power >= 10:
		return 2
	return 1

func _tower_interval_ms(tier: int) -> float:
	match tier:
		1:
			return 3000.0
		2:
			return 2500.0
		3:
			return 2000.0
		4:
			return 1500.0
	return 3000.0

func _tower_interval_ms_for(owner_id: int, tier: int) -> float:
	var base: float = _tower_interval_ms(tier)
	if owner_id <= 0:
		return base
	var pct: float = _buff_mod(owner_id, "tower_fire_rate_pct")
	var rate_mult: float = maxf(BUFF_MIN_MULT, 1.0 + pct)
	return maxf(80.0, base / rate_mult)

func _tower_range_px(tier: int) -> float:
	var small_range_px: float = 192.0
	var medium_range_px: float = 256.0
	var large_range_px: float = 320.0
	if tier <= 1:
		return small_range_px
	if tier == 2:
		return medium_range_px
	return large_range_px

func _tower_shoot(tower: Dictionary) -> bool:
	if not tower["active"]:
		return false
	var tower_pos: Vector2 = _tower_center_pos(tower)
	var range_px: float = _tower_range_px(int(tower["tier"]))
	var range_sq: float = range_px * range_px
	var best_idx: int = -1
	var best_dist: float = INF
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		if unit["owner_id"] == tower["owner_id"]:
			continue
		var pos: Vector2 = _unit_position(unit)
		var dist: float = tower_pos.distance_squared_to(pos)
		if dist <= range_sq and dist < best_dist:
			best_dist = dist
			best_idx = i
	if best_idx == -1:
		return false
	var victim: Dictionary = units[best_idx]
	units.remove_at(best_idx)
	dbg("SF: tower %d shot unit %d" % [tower["id"], victim["id"]])
	return true

func _update_barracks(dt: float) -> void:
	var dt_ms: float = dt * 1000.0
	for b in barracks:
		var prev_owner_id: int = int(b.get("owner_id", 0))
		var barracks_id: int = int(b.get("id", -1))
		var prev_active: bool = bool(b.get("active", false))
		var prev_tier: int = int(b.get("tier", 1))
		if int(b.get("required_hive_ids", []).size()) < BARRACKS_MIN_REQ:
			b["active"] = false
			b["owner_id"] = 0
			b["tier"] = 1
			b["spawn_accum_ms"] = 0.0
			_notify_floor_structure_owner_changed("barracks", barracks_id, prev_owner_id, 0)
			continue
		var owner_id: int = 0
		var min_tier: int = 4
		var active: bool = true
		for hive_id_v in b["required_hive_ids"]:
			var hive_id: int = int(hive_id_v)
			var hive: HiveData = _find_hive_by_id(hive_id)
			if hive == null or hive.owner_id == 0:
				active = false
				break
			if owner_id == 0:
				owner_id = hive.owner_id
			elif hive.owner_id != owner_id:
				active = false
				break
			min_tier = min(min_tier, _hive_tier(hive.power))
		if not active:
			b["active"] = false
			b["owner_id"] = 0
			b["tier"] = 1
			b["spawn_accum_ms"] = 0.0
			_notify_floor_structure_owner_changed("barracks", barracks_id, prev_owner_id, 0)
			continue
		b["active"] = true
		b["owner_id"] = owner_id
		b["tier"] = min_tier
		_notify_floor_structure_owner_changed("barracks", barracks_id, prev_owner_id, owner_id)
		if owner_id > 0:
			barracks_control_ms[owner_id] = float(barracks_control_ms.get(owner_id, 0.0)) + dt_ms
		if min_tier != prev_tier:
			dbg("SF: barracks %d tier %d->%d" % [b["id"], prev_tier, min_tier])
		if not prev_active:
			_queue_event({"type": "barracks_active", "barracks_id": int(b["id"]), "owner_id": owner_id})
			dbg("SF: barracks %d active owner=P%d" % [b["id"], owner_id])
		b["spawn_accum_ms"] += dt_ms
		var interval_ms: float = _barracks_interval_ms(int(b["tier"]))
		if b["spawn_accum_ms"] >= interval_ms:
			var targets: Array = _barracks_targets(b)
			if targets.is_empty():
				b["spawn_accum_ms"] = 0.0
				continue
			var cursor: int = int(b.get("route_cursor", b.get("rr_index", 0)))
			if cursor < 0:
				cursor = 0
			var idx: int = cursor % targets.size()
			var target_id: int = int(targets[idx])
			b["route_cursor"] = cursor + 1
			b["rr_index"] = int(b.get("route_cursor", 0))
			var from_pos: Vector2 = _barracks_center_pos(b)
			_spawn_unit(-b["id"], target_id, owner_id, -1, false, from_pos, true)
			dbg("SF: barracks %d spawn to hive %d" % [b["id"], target_id])
			b["spawn_accum_ms"] = 0.0

func _barracks_interval_ms(tier: int) -> float:
	match tier:
		1:
			return 3000.0
		2:
			return 2500.0
		3:
			return 2000.0
		4:
			return 1500.0
	return 3000.0

func _barracks_targets(barracks_data: Dictionary) -> Array:
	var allowed: Array = []
	var allowed_lookup: Dictionary = {}
	var control_v: Variant = barracks_data.get("control_hive_ids", [])
	if typeof(control_v) == TYPE_ARRAY:
		for hive_id_v in control_v as Array:
			var hive_id: int = int(hive_id_v)
			if hive_id <= 0 or allowed_lookup.has(hive_id):
				continue
			var hive: HiveData = _find_hive_by_id(hive_id)
			if hive != null and hive.owner_id == barracks_data["owner_id"]:
				allowed_lookup[hive_id] = true
				allowed.append(hive_id)
	if allowed.is_empty():
		var required_v: Variant = barracks_data.get("required_hive_ids", [])
		if typeof(required_v) == TYPE_ARRAY:
			for hive_id_v in required_v as Array:
				var hive_id: int = int(hive_id_v)
				if hive_id <= 0 or allowed_lookup.has(hive_id):
					continue
				var hive: HiveData = _find_hive_by_id(hive_id)
				if hive != null and hive.owner_id == barracks_data["owner_id"]:
					allowed_lookup[hive_id] = true
					allowed.append(hive_id)
	if allowed.is_empty():
		return []
	allowed.sort()
	var route_v: Variant = barracks_data.get("route_targets", [])
	if typeof(route_v) != TYPE_ARRAY or (route_v as Array).is_empty():
		route_v = barracks_data.get("route_hive_ids", [])
	if typeof(route_v) != TYPE_ARRAY or (route_v as Array).is_empty():
		route_v = barracks_data.get("preferred_targets", [])
	var route: Array = []
	if typeof(route_v) == TYPE_ARRAY:
		var seen: Dictionary = {}
		for target_id_v in route_v as Array:
			var target_id: int = int(target_id_v)
			if allowed_lookup.has(target_id) and not seen.has(target_id):
				seen[target_id] = true
				route.append(target_id)
	if route.is_empty():
		return allowed
	return route

func _barracks_required_hives_for(pos: Vector2i, required: Array) -> Array:
	return _structure_required_hives_for(pos, required, [], [])

func _structure_required_hives_for(pos: Vector2i, required: Array, existing_sets: Array, structure_positions: Array) -> Array:
	var valid: Array = []
	var seen: Dictionary = {}
	for hive_id_v in required:
		var hive_id: int = int(hive_id_v)
		if seen.has(hive_id):
			continue
		var hive: HiveData = _find_hive_by_id(hive_id)
		if hive == null:
			continue
		seen[hive_id] = true
		valid.append(hive_id)
	var self_center: Vector2 = _cell_center(pos)
	if valid.size() >= BARRACKS_MIN_REQ and valid.size() <= BARRACKS_MAX_REQ:
		if _structure_selection_ok(valid, existing_sets, structure_positions, self_center):
			return valid
	var preferred_size: int = valid.size()
	return _structure_pick_required_hives(pos, existing_sets, structure_positions, preferred_size)

func _structure_pick_required_hives(pos: Vector2i, existing_sets: Array, structure_positions: Array, preferred_size: int) -> Array:
	var entries: Array = []
	for hive in state.hives:
		var d: Vector2i = hive.grid_pos - pos
		var d2: int = d.x * d.x + d.y * d.y
		entries.append({"id": hive.id, "d2": d2})
	entries.sort_custom(Callable(self, "_barracks_entry_less"))
	if entries.is_empty():
		return []
	var candidate_count: int = min(entries.size(), STRUCTURE_CANDIDATE_MAX)
	var candidates: Array = []
	for i in range(candidate_count):
		candidates.append(entries[i])
	var min_req: int = min(BARRACKS_MIN_REQ, candidate_count)
	var max_req: int = min(BARRACKS_MAX_REQ, candidate_count)
	if max_req < min_req:
		min_req = candidate_count
		max_req = candidate_count
	var preferred: int = preferred_size
	if preferred < min_req or preferred > max_req:
		preferred = max_req
	var sizes: Array = [preferred]
	for size in range(min_req, max_req + 1):
		if size == preferred:
			continue
		sizes.append(size)
	var best_state_global: Dictionary = {"penalty": 1_000_000, "score": 1_000_000_000, "set": []}
	for size in sizes:
		var best_state: Dictionary = {"penalty": 1_000_000, "score": 1_000_000_000, "set": []}
		_structure_search_best(candidates, size, 0, [], 0, existing_sets, structure_positions, _cell_center(pos), best_state)
		if best_state["penalty"] == 0:
			return best_state["set"]
		if best_state["penalty"] < int(best_state_global["penalty"]) or (best_state["penalty"] == int(best_state_global["penalty"]) and best_state["score"] < int(best_state_global["score"])):
			best_state_global = best_state
	return []

func _structure_search_best(entries: Array, size: int, start_idx: int, current: Array, sum_d2: int, existing_sets: Array, structure_positions: Array, self_center: Vector2, best_state: Dictionary) -> void:
	if current.size() == size:
		var penalty: int = _structure_selection_penalty(current, existing_sets, structure_positions, self_center)
		if penalty < int(best_state["penalty"]) or (penalty == int(best_state["penalty"]) and sum_d2 < int(best_state["score"])):
			best_state["penalty"] = penalty
			best_state["score"] = sum_d2
			best_state["set"] = current.duplicate()
		return
	if start_idx >= entries.size():
		return
	if current.size() + (entries.size() - start_idx) < size:
		return
	for i in range(start_idx, entries.size()):
		var entry: Dictionary = entries[i]
		current.append(int(entry["id"]))
		_structure_search_best(entries, size, i + 1, current, sum_d2 + int(entry["d2"]), existing_sets, structure_positions, self_center, best_state)
		current.pop_back()

func _structure_selection_ok(candidate: Array, existing_sets: Array, structure_positions: Array, self_center: Vector2) -> bool:
	return _structure_selection_penalty(candidate, existing_sets, structure_positions, self_center) == 0

func _structure_selection_penalty(candidate: Array, existing_sets: Array, structure_positions: Array, self_center: Vector2) -> int:
	var candidate_set: Dictionary = {}
	for hive_id_v in candidate:
		candidate_set[int(hive_id_v)] = true
	var penalty: int = 0
	for other in existing_sets:
		var other_arr: Array = other
		if other_arr.is_empty():
			continue
		var overlap: int = 0
		for hive_id_v in other_arr:
			if candidate_set.has(int(hive_id_v)):
				overlap += 1
		var limit: int = int(float(min(candidate.size(), other_arr.size())) * 2.0 / 3.0)
		if overlap > limit:
			penalty += overlap - limit
	var hull_violations: int = _structure_hull_violation_count(candidate, structure_positions)
	if hull_violations > 0:
		penalty += hull_violations * 1000
	var candidate_center: Vector2 = _structure_center_for_required(candidate, self_center)
	if _structure_point_inside_existing_hulls(candidate_center, existing_sets):
		penalty += 1000
	return penalty

func _structure_center_for_required(required: Array, fallback_center: Vector2) -> Vector2:
	if required.is_empty():
		return fallback_center
	var sum := Vector2.ZERO
	var count := 0
	for hive_id_v in required:
		var hive: HiveData = _find_hive_by_id(int(hive_id_v))
		if hive == null:
			continue
		sum += _cell_center(hive.grid_pos)
		count += 1
	if count == 0:
		return fallback_center
	return sum / float(count)

func _structure_point_inside_existing_hulls(point: Vector2, existing_sets: Array) -> bool:
	for other in existing_sets:
		var other_arr: Array = other
		if other_arr.size() < 3:
			continue
		var points: Array = []
		for hive_id_v in other_arr:
			var hive: HiveData = _find_hive_by_id(int(hive_id_v))
			if hive != null:
				points.append(_cell_center(hive.grid_pos))
		if points.size() < 3:
			continue
		var hull: Array = _convex_hull(points)
		if hull.size() < 3:
			continue
		if _point_in_convex_polygon(point, hull):
			return true
	return false

func _structure_hull_violation_count(candidate: Array, structure_positions: Array) -> int:
	if candidate.size() < 3:
		return 0
	var points: Array = []
	for hive_id_v in candidate:
		var hive: HiveData = _find_hive_by_id(int(hive_id_v))
		if hive != null:
			points.append(_cell_center(hive.grid_pos))
	if points.size() < 3:
		return 0
	var hull: Array = _convex_hull(points)
	if hull.size() < 3:
		return 0
	var violations: int = 0
	for pos_v in structure_positions:
		var point: Vector2 = pos_v
		if _point_in_convex_polygon(point, hull):
			violations += 1
	return violations

func _convex_hull(points: Array) -> Array:
	var pts: Array = points.duplicate()
	pts.sort_custom(Callable(self, "_point_less"))
	if pts.size() <= 2:
		return pts
	var lower: Array = []
	for p in pts:
		while lower.size() >= 2 and _cross(lower[lower.size() - 2], lower[lower.size() - 1], p) <= 0.0:
			lower.pop_back()
		lower.append(p)
	var upper: Array = []
	for i in range(pts.size() - 1, -1, -1):
		var p: Vector2 = pts[i]
		while upper.size() >= 2 and _cross(upper[upper.size() - 2], upper[upper.size() - 1], p) <= 0.0:
			upper.pop_back()
		upper.append(p)
	lower.pop_back()
	upper.pop_back()
	return lower + upper

func _point_less(a: Vector2, b: Vector2) -> bool:
	if a.x == b.x:
		return a.y < b.y
	return a.x < b.x

func _cross(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b - a).cross(c - a)

func _point_in_convex_polygon(p: Vector2, poly: Array) -> bool:
	if poly.size() < 3:
		return false
	var sign_val: float = 0.0
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var cross_val: float = _cross(a, b, p)
		if abs(cross_val) < 0.001:
			continue
		if sign_val == 0.0:
			sign_val = sign(cross_val)
		elif sign_val * cross_val < 0.0:
			return false
	return true

func _barracks_entry_less(a: Dictionary, b: Dictionary) -> bool:
	var ad2: int = int(a["d2"])
	var bd2: int = int(b["d2"])
	if ad2 == bd2:
		return int(a["id"]) < int(b["id"])
	return ad2 < bd2

func _barracks_center_pos(barracks_data: Dictionary) -> Vector2:
	var required: Array = barracks_data.get("required_hive_ids", [])
	if required.is_empty():
		return _cell_center(barracks_data["grid_pos"])
	var sum := Vector2.ZERO
	var count := 0
	for hive_id_v in required:
		var hive: HiveData = _find_hive_by_id(int(hive_id_v))
		if hive == null:
			continue
		sum += _cell_center(hive.grid_pos)
		count += 1
	if count == 0:
		return _cell_center(barracks_data["grid_pos"])
	return sum / float(count)

func _tower_center_pos(tower_data: Dictionary) -> Vector2:
	var required: Array = tower_data.get("required_hive_ids", [])
	if required.is_empty():
		return _cell_center(tower_data["grid_pos"])
	var sum := Vector2.ZERO
	var count := 0
	for hive_id_v in required:
		var hive: HiveData = _find_hive_by_id(int(hive_id_v))
		if hive == null:
			continue
		sum += _cell_center(hive.grid_pos)
		count += 1
	if count == 0:
		return _cell_center(tower_data["grid_pos"])
	return sum / float(count)

func _play_barracks_activate_sfx() -> void:
	if audio_system == null:
		return
	audio_system._play_barracks_activate_sfx()

func _barracks_id_at_point(local_pos: Vector2) -> int:
	for b in barracks:
		var center: Vector2 = _barracks_center_pos(b)
		var size: float = CELL_SIZE * 0.28
		var rect: Rect2 = Rect2(center.x - size * 0.5, center.y - size * 0.5, size, size)
		if rect.has_point(local_pos):
			return int(b["id"])
	return -1

func _toggle_barracks_selector(barracks_id: int, dev_pid: int = -1) -> bool:
	if input_system == null or api == null:
		return false
	return input_system._toggle_barracks_selector(barracks_id, dev_pid, api)

func _start_barracks_selector(barracks_id: int, dev_pid: int = -1) -> bool:
	if input_system == null or api == null:
		return false
	return input_system._start_barracks_selector(barracks_id, dev_pid, api)

func _end_barracks_selector() -> void:
	if input_system == null or api == null:
		return
	input_system._end_barracks_selector(api)

func _barracks_selector_toggle_hive(hive_id: int, dev_pid: int = -1) -> bool:
	if input_system == null or api == null:
		return false
	return input_system._barracks_selector_toggle_hive(hive_id, dev_pid, api)

func _barracks_by_id(barracks_id: int) -> Dictionary:
	for b in barracks:
		if int(b.get("id", -1)) == barracks_id:
			return b
	return {}

func _edge_point_toward(center: Vector2, toward: Vector2) -> Vector2:
	var dir: Vector2 = toward - center
	if dir.length_squared() == 0.0:
		return center
	return center + dir.normalized() * HIVE_RADIUS_PX

func _unit_position(unit: Dictionary) -> Vector2:
	if unit.has("from_pos"):
		var to_hive: HiveData = _find_hive_by_id(int(unit["to_id"]))
		if to_hive == null:
			return Vector2.ZERO
		var to_center: Vector2 = _cell_center(to_hive.grid_pos)
		var end_pos: Vector2 = _edge_point_toward(to_center, unit["from_pos"])
		return unit["from_pos"].lerp(end_pos, float(unit["t"]))
	var from_hive: HiveData = _find_hive_by_id(int(unit["from_id"]))
	var to_hive: HiveData = _find_hive_by_id(int(unit["to_id"]))
	if from_hive == null or to_hive == null:
		return Vector2.ZERO
	var from_center: Vector2 = _cell_center(from_hive.grid_pos)
	var to_center: Vector2 = _cell_center(to_hive.grid_pos)
	var start_pos: Vector2 = _edge_point_toward(from_center, to_center)
	var end_pos: Vector2 = _edge_point_toward(to_center, from_center)
	return start_pos.lerp(end_pos, float(unit["t"]))

func _packet_position(packet: Dictionary) -> Vector2:
	var from_hive: HiveData = _find_hive_by_id(int(packet["from_id"]))
	var to_hive: HiveData = _find_hive_by_id(int(packet["to_id"]))
	if from_hive == null or to_hive == null:
		return Vector2.ZERO
	var from_center: Vector2 = _cell_center(from_hive.grid_pos)
	var to_center: Vector2 = _cell_center(to_hive.grid_pos)
	var start_pos: Vector2 = _edge_point_toward(from_center, to_center)
	var end_pos: Vector2 = _edge_point_toward(to_center, from_center)
	return start_pos.lerp(end_pos, float(packet["t"]))

func _spawn_debris_for_lane(lane: LaneData, owner_id: int, impact_f: float = -1.0) -> void:
	dbg_mark_event("vfx_spawn")
	if not debris_enabled:
		return
	if debris.size() >= DEBRIS_GLOBAL_CAP:
		debris.pop_front()
	var a: HiveData = _find_hive_by_id(lane.a_id)
	var b: HiveData = _find_hive_by_id(lane.b_id)
	if a == null or b == null:
		return
	var a_pos: Vector2 = _cell_center(a.grid_pos)
	var b_pos: Vector2 = _cell_center(b.grid_pos)
	var impact := impact_f
	if impact < 0.0:
		impact = lane.last_impact_f
	impact = clamp(impact, 0.0, 1.0)
	var impact_pos: Vector2 = a_pos.lerp(b_pos, impact)
	var nearby: int = _count_debris_near(lane.id, impact_pos, 22.0)
	if nearby >= DEBRIS_MAX_PER_LANE:
		return
	var dir: Vector2 = (b_pos - a_pos).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var dir_sign: float = 1.0 if (debris_id_counter % 2 == 0) else -1.0
	var extra_offset: float = min(20.0, float(nearby) * 0.6)
	# Cosmetic-only randomness; debris has no gameplay impact.
	var offset: float = randf_range(6.0, 14.0) + extra_offset
	var pos: Vector2 = impact_pos + perp * dir_sign * offset
	var vel: Vector2 = perp * dir_sign * randf_range(10.0, DEBRIS_DRIFT) + dir * randf_range(-8.0, 8.0)
	var radius: float = 2.0 + float(debris_id_counter % 3)
	var d: Dictionary = {
		"id": debris_id_counter,
		"pos": pos,
		"vel": vel,
		"life": DEBRIS_LIFE,
		"owner_id": owner_id,
		"radius": radius,
		"lane_id": lane.id
	}
	debris_id_counter += 1
	debris.append(d)
	_note_render_dirty()

func _count_debris_near(lane_id: int, pos: Vector2, radius: float) -> int:
	var count: int = 0
	var r2: float = radius * radius
	for d in debris:
		if d["lane_id"] != lane_id:
			continue
		if d["pos"].distance_squared_to(pos) <= r2:
			count += 1
	return count

func _spawn_unit(from_id: int, to_id: int, owner_id: int, lane_id: int, print_spawn: bool, from_pos: Vector2 = Vector2.ZERO, use_from_pos: bool = false) -> void:
	var unit := {
		"id": unit_id_counter,
		"owner_id": owner_id,
		"lane_id": lane_id,
		"from_id": from_id,
		"to_id": to_id,
		"t": 0.0,
		"alive": true
	}
	if use_from_pos:
		unit["from_pos"] = from_pos
	if lane_id != -1 and state != null:
		var lane: LaneData = _find_lane_by_id(lane_id)
		if lane != null:
			var a_id: int = lane.a_id
			var b_id: int = lane.b_id
			unit["lane_key"] = state.lane_key(a_id, b_id)
			unit["a_id"] = a_id
			unit["b_id"] = b_id
			if from_id == a_id:
				unit["dir"] = 1
				unit["spawn_end"] = "A"
				unit["lane_t"] = 0.0
			elif from_id == b_id:
				unit["dir"] = -1
				unit["spawn_end"] = "B"
				unit["lane_t"] = 1.0
			else:
				SFLog.info("SPAWN_INVALID lane=%s owner=%d from=%d to=%d a=%d b=%d" % [
					str(unit.get("lane_key", "")),
					owner_id,
					from_id,
					to_id,
					a_id,
					b_id
				])
				return
			unit["speed_t"] = 1.0 / (UNIT_TRAVEL_MS / 1000.0)
	var arrival_us: int = _estimate_arrival_us(unit, from_pos, use_from_pos)
	unit["arrival_us"] = arrival_us
	# Units are owned by UnitSystem now; Arena must not append/spawn.
	if unit_system != null:
		dbg_mark_event("unit_create")
		unit_system.spawn_unit(unit)
	else:
		SFLog.warn("SPAWN_BLOCKED_NO_UNITSYSTEM", {"lane": str(unit.get("lane_key", ""))})
	if print_spawn:
		var src_power := -1
		var interval_ms := -1.0
		var from_hive: HiveData = _find_hive_by_id(from_id)
		if from_hive != null:
			src_power = from_hive.power
			interval_ms = _hive_spawn_interval_ms(from_hive)
		var power_text := "NA" if src_power < 0 else str(src_power)
		var interval_text := "NA" if interval_ms < 0.0 else "%.1f" % interval_ms
		var owner_label: String = str(_owner_label(owner_id))
		dbg("SF: spawn unit %d %d->%d owner=%s pwr=%s interval_ms=%s" % [
			unit["id"],
			from_id,
			to_id,
			owner_label,
			power_text,
			interval_text
		])

func _estimate_arrival_us(unit: Dictionary, from_pos: Vector2, use_from_pos: bool) -> int:
	var t: float = clamp(float(unit.get("t", 0.0)), 0.0, 1.0)
	var remaining_ms: float = 0.0
	remaining_ms = (1.0 - t) * UNIT_TRAVEL_MS
	return sim_time_us + int(round(remaining_ms * 1000.0))

func _get_outgoing_intents(hive_id: int, require_ready: bool = false) -> Array:
	var outgoing: Array = []
	for lane in state.lanes:
		if lane.a_id == hive_id and lane.send_a:
			if require_ready and not _lane_ready_for_send(lane, hive_id):
				continue
			outgoing.append({"target_id": lane.b_id, "lane_id": lane.id})
		elif lane.b_id == hive_id and lane.send_b:
			if require_ready and not _lane_ready_for_send(lane, hive_id):
				continue
			outgoing.append({"target_id": lane.a_id, "lane_id": lane.id})
	return outgoing

func _lane_ready_for_send(lane: LaneData, from_id: int) -> bool:
	var a: HiveData = _find_hive_by_id(lane.a_id)
	var b: HiveData = _find_hive_by_id(lane.b_id)
	if a == null or b == null:
		return false
	var lane_len: float = _lane_length_px(a, b)
	if lane_len <= 0.0:
		return false
	if from_id == lane.a_id:
		return lane.a_stream_len >= lane_len
	if from_id == lane.b_id:
		return lane.b_stream_len >= lane_len
	return false

func _find_lane_by_id(lane_id: int) -> LaneData:
	for lane in state.lanes:
		if lane.id == lane_id:
			return lane
	return null

func _apply_unit_arrival(unit_owner: int, hive: HiveData, from_id: int = -1, lane_id: int = -1, reason: String = "other") -> void:
	_note_render_dirty()
	if unit_owner >= 1 and unit_owner <= 4:
		units_landed[unit_owner] = int(units_landed.get(unit_owner, 0)) + 1
		var tutorial_arrival_key: String = "%d:%d" % [int(hive.id), unit_owner]
		tutorial_arrivals_by_hive_owner[tutorial_arrival_key] = int(tutorial_arrivals_by_hive_owner.get(tutorial_arrival_key, 0)) + 1
	var prev_owner: int = hive.owner_id
	var friendly_arrival: bool = _are_allied_owners(prev_owner, unit_owner)
	var pass_owner: int = unit_owner if unit_owner > 0 else prev_owner
	if friendly_arrival and prev_owner > 0:
		pass_owner = prev_owner
	if friendly_arrival:
		var prev_power: int = int(hive.power)
		if hive.shock_ms <= 0.0 and hive.power < 50:
			hive.power += 1
		if hive.shock_ms <= 0.0 and (not ENABLE_PASS_THROUGH_POWER_GATE or prev_power >= 50) and reason != "recall":
			_pass_through(hive, pass_owner)
		return
	if hive.power > 1:
		hive.power -= 1
		return
	hive.owner_id = unit_owner
	_notify_floor_structure_owner_changed("hive", int(hive.id), prev_owner, unit_owner)
	dbg_mark_event("tower_eval")
	capture_count += 1
	hive.power = 1
	hive.shock_ms = CAPTURE_SHOCK_MS
	hive.spawn_accum_ms = 0.0
	hive.idle_accum_ms = 0.0
	if from_id != -1:
		var lane: LaneData = null
		if lane_id != -1:
			lane = _find_lane_by_id(lane_id)
		else:
			var lane_index: int = _lane_index_between(from_id, hive.id)
			if lane_index != -1:
				lane = state.lanes[lane_index]
		if lane != null:
			if lane.a_id == from_id and lane.b_id == hive.id:
				lane.dir = 1
				if lane.send_b and lane.send_a:
					lane.send_b = false
					lane.establish_b = false
			elif lane.b_id == from_id and lane.a_id == hive.id:
				lane.dir = -1
				if lane.send_a and lane.send_b:
					lane.send_a = false
					lane.establish_a = false

func _notify_floor_structure_owner_changed(structure_type: String, structure_id: int, prev_owner: int, next_owner: int) -> void:
	if floor_influence_system == null:
		return
	if structure_id <= 0:
		return
	if prev_owner == next_owner:
		return
	floor_influence_system.notify_ownership_changed(structure_type, structure_id, prev_owner, next_owner)

func _update_idle_growth(dt: float) -> void:
	var dt_ms := dt * 1000.0
	for hive in state.hives:
		var prev_power := hive.power
		if hive.owner_id == 0:
			hive.idle_accum_ms = 0.0
			continue
		if hive.shock_ms > 0.0:
			hive.idle_accum_ms = 0.0
			continue
		if _has_incoming_enemy_intent(hive.id, hive.owner_id):
			hive.idle_accum_ms = 0.0
			continue
		if _active_outgoing_intent_count(hive.id) == 0:
			hive.idle_accum_ms += dt_ms
			while hive.idle_accum_ms >= IDLE_GROWTH_MS:
				if hive.power < 50:
					hive.power += 1
				hive.idle_accum_ms -= IDLE_GROWTH_MS
		else:
			hive.idle_accum_ms = 0.0
		if hive.power != prev_power:
			_note_render_dirty()

func _pass_through(hive: HiveData, owner_id: int) -> void:
	var targets := _get_pass_targets(hive)
	if targets.is_empty():
		return
	var idx: int = hive.pass_rr_index % targets.size()
	var lane_id: int = int(targets[idx]["lane_id"])
	var target_id: int = int(targets[idx]["target_id"])
	hive.pass_rr_index += 1
	var use_preferred := hive.pass_preferred_targets.size() > 0
	if use_preferred:
		dbg("SF: pass-through preferred %d -> %d" % [hive.id, target_id])
	else:
		dbg("SF: pass-through %d forwarded to %d" % [hive.id, target_id])
	_spawn_unit(hive.id, target_id, owner_id, lane_id, false)

func _get_pass_targets(hive: HiveData) -> Array:
	var outgoing := _get_outgoing_intents(hive.id)
	if outgoing.is_empty():
		return outgoing
	if hive.pass_preferred_targets.is_empty():
		return outgoing
	var preferred: Array = []
	for target_id in hive.pass_preferred_targets:
		for entry in outgoing:
			if entry["target_id"] == target_id:
				preferred.append(entry)
				break
	if preferred.is_empty():
		return outgoing
	return preferred

func _active_outgoing_intent_count(hive_id: int) -> int:
	var count := 0
	for lane in state.lanes:
		if lane.a_id == hive_id and lane.send_a:
			count += 1
		elif lane.b_id == hive_id and lane.send_b:
			count += 1
	return count

func _has_incoming_enemy_intent(hive_id: int, owner_id: int) -> bool:
	if owner_id == 0:
		return false
	for lane in state.lanes:
		if lane.send_a and lane.b_id == hive_id:
			var a: HiveData = _find_hive_by_id(lane.a_id)
			if a != null and a.owner_id != 0 and not _are_allied_owners(a.owner_id, owner_id):
				return true
		if lane.send_b and lane.a_id == hive_id:
			var b: HiveData = _find_hive_by_id(lane.b_id)
			if b != null and b.owner_id != 0 and not _are_allied_owners(b.owner_id, owner_id):
				return true
	return false

func _lane_mode(a: HiveData, b: HiveData) -> String:
	if a.owner_id == 0 or b.owner_id == 0:
		return "neutral"
	if _are_allied_owners(a.owner_id, b.owner_id):
		return "friendly"
	return "opposing"

func _are_allied_owners(owner_a: int, owner_b: int) -> bool:
	var a_id: int = int(owner_a)
	var b_id: int = int(owner_b)
	if a_id <= 0 or b_id <= 0:
		return false
	if OpsState != null and OpsState.has_method("are_allies"):
		return bool(OpsState.call("are_allies", a_id, b_id))
	return a_id == b_id

func _max_out_lanes(power: int) -> int:
	if power >= 25:
		return 3
	if power >= 10:
		return 2
	return 1

func _hive_slot_count(power: int) -> int:
	if power >= 25:
		return 3
	if power >= 10:
		return 2
	return 1

func _hive_lane_order_for(hive_id: int) -> Array:
	var order: Array = hive_lane_order.get(hive_id, [])
	if order.is_empty():
		return []
	var filtered: Array = []
	for target_id_v in order:
		var target_id := int(target_id_v)
		if _intent_is_on(hive_id, target_id):
			filtered.append(target_id)
	if filtered.size() != order.size():
		hive_lane_order[hive_id] = filtered
	return filtered

func _hive_slot_has_intent(hive_id: int, slot_index: int) -> bool:
	if slot_index <= 0:
		return false
	var order := _hive_lane_order_for(hive_id)
	return slot_index <= order.size()

func _track_hive_lane_intent(from_id: int, to_id: int, enable: bool) -> void:
	var from_hive: HiveData = _find_hive_by_id(from_id)
	if from_hive == null:
		return
	var order: Array = hive_lane_order.get(from_id, [])
	if enable:
		for entry in order:
			if int(entry) == to_id:
				hive_lane_order[from_id] = order
				return
		order.append(to_id)
	else:
		for i in range(order.size() - 1, -1, -1):
			if int(order[i]) == to_id:
				order.remove_at(i)
				break
	hive_lane_order[from_id] = order

func _update_lane_slots() -> void:
	for hive in state.hives:
		var prev_power := int(hive_power_prev.get(hive.id, hive.power))
		if prev_power >= 25 and hive.power <= 24:
			var order := _hive_lane_order_for(hive.id)
			if order.size() >= 3:
				var target_id := int(order[order.size() - 1])
				_retract_lane(hive.id, target_id, hive.owner_id)
		hive_power_prev[hive.id] = hive.power

func _send_rate(hive: HiveData, is_sending: bool) -> float:
	if not is_sending:
		return 0.0
	if hive.owner_id == 0:
		return 0.0
	var interval_ms := _hive_spawn_interval_ms(hive)
	var interval_sec := interval_ms / 1000.0
	if interval_sec <= 0.0:
		return 0.0
	return 1.0 / interval_sec

func _interval_ms(power: int) -> float:
	var value: float = BASE_MS - ((power - 1) * PER_POWER_MS)
	return maxf(SPAWN_MIN_MS, value)

func _spawn_interval_ms_for_power(power: int) -> int:
	var p := maxi(1, power)
	return maxi(int(SPAWN_MIN_MS), int(SPAWN_BASE_MS) - (p - 1) * int(SPAWN_PER_POWER_MS))

func _hive_spawn_interval_ms(hive: HiveData) -> float:
	var base: float = _interval_ms(hive.power)
	var pct: float = _buff_mod(hive.owner_id, "hive_prod_time_pct")
	var mult: float = maxf(BUFF_MIN_MULT, 1.0 + pct)
	return maxf(80.0, base * mult)

func _unit_speed_px(owner_id: int, lane_id: int) -> float:
	var speed: float = _base_unit_speed_px()
	var speed_pct: float = _buff_mod(owner_id, "unit_speed_pct")
	speed *= maxf(BUFF_MIN_MULT, 1.0 + speed_pct)
	var slow_pct: float = _lane_slow_pct_for_unit(owner_id, lane_id)
	if slow_pct > 0.0:
		speed *= maxf(BUFF_MIN_MULT, 1.0 - slow_pct)
	return speed

func _base_unit_speed_px() -> float:
	return float(SimTuning.UNIT_SPEED_PX_PER_SEC)

func _lane_slow_pct_for_unit(owner_id: int, lane_id: int) -> float:
	if lane_id <= 0:
		return 0.0
	var lane: LaneData = _find_lane_by_id(lane_id)
	if lane == null:
		return 0.0
	var max_slow: float = 0.0
	for pid_v in buff_mods.keys():
		var pid: int = int(pid_v)
		if pid == owner_id:
			continue
		var slow_pct: float = _buff_mod(pid, "lane_slow_pct")
		if slow_pct <= 0.0:
			continue
		if _lane_has_player_send(lane, pid):
			max_slow = maxf(max_slow, slow_pct)
	return max_slow

func _lane_has_player_send(lane: LaneData, pid: int) -> bool:
	var a: HiveData = _find_hive_by_id(lane.a_id)
	if a != null and a.owner_id == pid and lane.send_a:
		return true
	var b: HiveData = _find_hive_by_id(lane.b_id)
	if b != null and b.owner_id == pid and lane.send_b:
		return true
	return false

func _compute_match_seed() -> int:
	var source: String = current_map_name
	if source == "":
		source = current_map_path
	if source == "":
		source = "default"
	return _hash_string(source)

func _hash_string(value: String) -> int:
	var h: int = 0
	for i in range(value.length()):
		h = int((h * 31 + value.unicode_at(i)) & 0x7fffffff)
	return h

func _lane_length_px(a: HiveData, b: HiveData) -> float:
	return _cell_center(a.grid_pos).distance_to(_cell_center(b.grid_pos))

func _handle_press(local_pos: Vector2, dev_pid: int = -1, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	if _try_handle_capture_flag_press(local_pos, button_index):
		_ctf_click_consumed = true
		return
	if input_system == null or api == null:
		return
	input_system.handle_press(local_pos, dev_pid, api, button_index)

func _handle_press_impl(local_pos: Vector2, dev_pid: int = -1, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	if input_system == null or api == null:
		return
	input_system.handle_press(local_pos, dev_pid, api, button_index)

func _handle_release(local_pos: Vector2, dev_pid: int = -1) -> void:
	if _ctf_click_consumed:
		_ctf_click_consumed = false
		return
	if _ctf_move_armed:
		return
	if input_system == null or api == null:
		return
	input_system.handle_release(local_pos, dev_pid, api)

func _handle_drag(local_pos: Vector2) -> void:
	if _ctf_move_armed:
		return
	if input_system == null or api == null:
		return
	input_system.handle_drag(local_pos, api)

func _handle_tap(hive_id: int, dev_pid: int = -1) -> void:
	SFLog.trace("HIVE_TAPPED", {"hive_id": hive_id})
	if _ctf_move_armed:
		return
	if input_system == null or api == null:
		return
	if _tutorial_launch_section() == TUTORIAL_CONTROLS_ID and _tutorial_controls_controller != null and state != null:
		_tutorial_controls_controller.on_hive_clicked(hive_id, state, _resolve_local_owner_id())
	if _tutorial_launch_section() == TUTORIAL_SECTION1_ID and _tutorial_section1_controller != null and state != null:
		_tutorial_section1_controller.on_hive_clicked(hive_id, state, _resolve_local_owner_id())
	input_system.handle_tap(hive_id, dev_pid, api)

func _handle_lane_double_tap(local_pos: Vector2, dev_pid: int = -1, pid: int = -1) -> bool:
	if input_system == null or api == null:
		return false
	return input_system.handle_lane_double_tap(local_pos, dev_pid, pid, api)

func _try_swarm(from_id: int, to_id: int, pid: int = -1) -> bool:
	if state == null:
		return false
	var from_hive: HiveData = _find_hive_by_id(from_id)
	var to_hive: HiveData = _find_hive_by_id(to_id)
	if from_hive == null or to_hive == null:
		return false
	var owner_id := int(from_hive.owner_id)
	if owner_id <= 0:
		return false
	if pid != -1 and owner_id != pid:
		return false
	if not _intent_is_on(from_id, to_id):
		return false
	var lane_index := _lane_index_between(from_id, to_id)
	if lane_index == -1:
		return false
	var lane: LaneData = state.lanes[lane_index]
	if not _lane_ready_for_send(lane, from_id):
		return false
	var payload: int = _consume_passthrough_payload(from_id, owner_id)
	var packet := {
		"id": swarm_id_counter,
		"owner_id": owner_id,
		"from_id": from_id,
		"to_id": to_id,
		"lane_id": int(lane.id),
		"payload": payload,
		"t": 0.0,
		"armed_ms": 0.0,
		"speed_mult": 3.0,
		"created_us": sim_time_us,
		"is_passthrough": false
	}
	swarm_id_counter += 1
	swarm_packets.append(packet)
	_play_swarm_sfx(int(packet.get("id", -1)))
	_note_render_dirty()
	if debug_swarms:
		SFLog.info("SWARM_CREATE", {
			"from_id": from_id,
			"to_id": to_id,
			"lane_id": int(lane.id),
			"owner_id": owner_id,
			"payload": payload
		})
	return true

func _project_t_on_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	if ab.length_squared() == 0.0:
		return 0.0
	var t: float = (p - a).dot(ab) / ab.length_squared()
	return clamp(t, 0.0, 1.0)

func _consume_passthrough_payload(from_id: int, owner_id: int) -> int:
	var total := 0
	for i in range(swarm_packets.size() - 1, -1, -1):
		var packet: Dictionary = swarm_packets[i]
		if not packet.get("is_passthrough", false):
			continue
		if int(packet.get("from_id", -1)) != from_id:
			continue
		if int(packet.get("owner_id", -1)) != owner_id:
			continue
		var created_us: int = int(packet.get("created_us", sim_time_us))
		if abs(sim_time_us - created_us) <= SWARM_MERGE_WINDOW_US:
			total += int(packet.get("payload", 0))
			_stop_swarm_sfx(int(packet.get("id", -1)))
			swarm_packets.remove_at(i)
	return total

func _merge_passthrough_into_swarm(from_id: int, owner_id: int, payload: int) -> bool:
	var best_index := -1
	var best_created := -1
	for i in range(swarm_packets.size()):
		var packet: Dictionary = swarm_packets[i]
		if packet.get("is_passthrough", false):
			continue
		if int(packet.get("from_id", -1)) != from_id:
			continue
		if int(packet.get("owner_id", -1)) != owner_id:
			continue
		var created_us: int = int(packet.get("created_us", sim_time_us))
		if abs(sim_time_us - created_us) <= SWARM_MERGE_WINDOW_US and created_us > best_created:
			best_created = created_us
			best_index = i
	if best_index == -1:
		return false
	var target: Dictionary = swarm_packets[best_index]
	target["payload"] = int(target.get("payload", 0)) + payload
	swarm_packets[best_index] = target
	if debug_swarms:
		SFLog.info("SWARM_MERGE", {
			"from_id": from_id,
			"owner_id": owner_id,
			"payload": payload,
			"target_id": int(target.get("id", -1))
		})
	return true

func _pass_through_swarm(packet: Dictionary, hive: HiveData) -> bool:
	var targets := _get_pass_targets(hive)
	if targets.is_empty():
		return false
	var idx: int = hive.pass_rr_index % targets.size()
	var lane_id: int = int(targets[idx]["lane_id"])
	var target_id: int = int(targets[idx]["target_id"])
	hive.pass_rr_index += 1
	var payload: int = int(packet.get("payload", 0))
	var owner_id: int = int(packet.get("owner_id", 0))
	if _merge_passthrough_into_swarm(hive.id, owner_id, payload):
		dbg("SF: swarm merge %d->%d payload=%d" % [hive.id, target_id, payload])
		return true
	var new_packet := {
		"id": swarm_id_counter,
		"owner_id": owner_id,
		"from_id": hive.id,
		"to_id": target_id,
		"lane_id": lane_id,
		"payload": payload,
		"t": 0.0,
		"armed_ms": 0.0,
		"speed_mult": float(packet.get("speed_mult", 3.0)),
		"created_us": sim_time_us,
		"is_passthrough": true
	}
	swarm_id_counter += 1
	swarm_packets.append(new_packet)
	_play_swarm_sfx(int(new_packet.get("id", -1)))
	dbg("SF: swarm pass-through %d->%d payload=%d" % [hive.id, target_id, payload])
	return true

func _apply_intent_pair(start_id: int, end_id: int) -> void:
	OpsState.apply_intent_pair(start_id, end_id)

func request_intent_toggle(src_id: int, dst_id: int) -> bool:
	var st: GameState = OpsState.get_state()
	if st == null:
		return false
	var src: HiveData = st.find_hive_by_id(src_id)
	var dst: HiveData = st.find_hive_by_id(dst_id)
	if src != null and dst != null and src.owner_id != 0 and _are_allied_owners(src.owner_id, dst.owner_id):
		return OpsState.request_intent_feed(src_id, dst_id)
	return OpsState.request_intent_attack(src_id, dst_id)

func _apply_dev_intent(from_id: int, to_id: int, dev_pid: int) -> void:
	if OpsState.apply_dev_intent(from_id, to_id, dev_pid):
		if _is_dev_mouse_override():
			dbg("SF: DEV order P%d %d->%d" % [dev_pid, from_id, to_id])

func _issue_attack_order(attacker_id: int, target_id: int) -> void:
	if state == null:
		return
	var attacker: HiveData = _find_hive_by_id(attacker_id)
	if attacker == null:
		return
	var owner_id: int = attacker.owner_id
	if owner_id <= 0:
		return
	var lane_index := _lane_index_between(attacker_id, target_id)
	if lane_index == -1:
		if not _establish_lane_between(attacker_id, target_id):
			return
		lane_index = _lane_index_between(attacker_id, target_id)
	if lane_index == -1:
		return
	var lane: LaneData = state.lanes[lane_index]
	var key := state.lane_key(lane.a_id, lane.b_id)
	var existing_order: Dictionary = active_orders_by_attacker.get(attacker_id, {})
	if not existing_order.is_empty():
		var existing_key := str(existing_order.get("lane_key", ""))
		if existing_key == key:
			return
		return
	var lane_state: Dictionary = state.lane_sim_by_key.get(key, {})
	if not lane_state.is_empty():
		var establishing_by_owner: Dictionary = lane_state.get("establishing_by_owner", {})
		var established_by_owner: Dictionary = lane_state.get("established_by_owner", {})
		if bool(establishing_by_owner.get(owner_id, false)) or bool(established_by_owner.get(owner_id, false)):
			return
		var side_by_owner: Dictionary = lane_state.get("side", {})
		if side_by_owner.has(owner_id):
			return
	var a: HiveData = _find_hive_by_id(lane.a_id)
	var b: HiveData = _find_hive_by_id(lane.b_id)
	if a == null or b == null:
		return
	var length_px := _lane_length_px(a, b)
	var est_speed_px := length_px / (LANE_ESTABLISH_MS / 1000.0)
	lane.send_a = false
	lane.send_b = false
	lane.establish_a = false
	lane.establish_b = false
	state.issue_attack_order(
		attacker_id,
		target_id,
		owner_id,
		lane.a_id,
		lane.b_id,
		length_px,
		est_speed_px,
		FIRST_UNIT_OFFSET_MS
	)
	active_orders_by_attacker[attacker_id] = {
		"target_id": target_id,
		"lane_key": key,
		"issued_at_ms": Time.get_ticks_msec()
	}

func _spawn_first_unit_for_side(lane_state: Dictionary, side: Dictionary) -> void:
	var owner_id: int = int(side.get("owner_id", 0))
	var attacker_id: int = int(side.get("attacker_id", -1))
	var target_id: int = int(side.get("target_id", -1))
	if owner_id <= 0 or attacker_id <= 0 or target_id <= 0:
		return
	var a_id: int = int(lane_state.get("a_id", 0))
	var b_id: int = int(lane_state.get("b_id", 0))
	if a_id <= 0 or b_id <= 0:
		return
	var lane_index := _lane_index_between(a_id, b_id)
	if lane_index == -1:
		return
	var lane: LaneData = state.lanes[lane_index]
	_spawn_unit(attacker_id, target_id, owner_id, lane.id, true)

func _clear_active_order_for_side(lane_state: Dictionary, side: Dictionary) -> void:
	var attacker_id: int = int(side.get("attacker_id", -1))
	if attacker_id == -1:
		return
	var lane_key: String = str(lane_state.get("lane_key", ""))
	if lane_key.is_empty():
		return
	var existing_order: Dictionary = active_orders_by_attacker.get(attacker_id, {})
	if existing_order.is_empty():
		return
	if str(existing_order.get("lane_key", "")) == lane_key:
		active_orders_by_attacker.erase(attacker_id)

func _establish_lane_between(a_id: int, b_id: int) -> bool:
	var lane_index: int = _ensure_lane_between(a_id, b_id, true)
	return lane_index != -1

func _set_intent(from_id: int, to_id: int, enable: bool, skip_budget: bool = false) -> void:
	var lane_index: int = _lane_index_between(from_id, to_id)
	if lane_index == -1:
		return
	var was_on: bool = _intent_is_on(from_id, to_id)
	var lane: LaneData = state.lanes[lane_index]
	var a_id: int = lane.a_id
	var b_id: int = lane.b_id
	var a: HiveData = _find_hive_by_id(a_id)
	var b: HiveData = _find_hive_by_id(b_id)
	var was_send_a: bool = lane.send_a
	var was_send_b: bool = lane.send_b
	if enable:
		var from_hive: HiveData = _find_hive_by_id(from_id)
		if from_hive == null or from_hive.owner_id == 0:
			dbg("SF: Intent blocked (NPC origin)")
			return
		if _intent_is_on(from_id, to_id):
			return
		if ENABLE_OUTGOING_LANE_BUDGET and not skip_budget and state != null:
			var budget := state.lanes_allowed_for_power(int(from_hive.power))
			var active := state.count_active_outgoing(from_id)
			if active >= budget:
				SFLog.info("LANE_BUDGET_BLOCK", {
					"src": from_id,
					"dst": to_id,
					"power": int(from_hive.power),
					"active": active,
					"budget": budget
				})
				return
	var mode: String = _lane_mode(a, b)
	if from_id == a_id and to_id == b_id:
		lane.send_a = enable
		if enable:
			lane.dir = 1
			lane.retract_a = false
			if not was_send_a:
				lane.establish_a = true
				lane.a_stream_len = 0.0
		else:
			lane.establish_a = false
		if mode == "friendly" and enable:
			lane.send_b = false
			lane.dir = 1
			lane.establish_b = false
	elif from_id == b_id and to_id == a_id:
		lane.send_b = enable
		if enable:
			lane.dir = -1
			lane.retract_b = false
			if not was_send_b:
				lane.establish_b = true
				lane.b_stream_len = 0.0
		else:
			lane.establish_b = false
		if mode == "friendly" and enable:
			lane.send_a = false
			lane.dir = -1
			lane.establish_a = false
	var is_on: bool = _intent_is_on(from_id, to_id)
	if was_on != is_on:
		_track_hive_lane_intent(from_id, to_id, is_on)

func _retract_lane(from_id: int, to_id: int, owner_id: int) -> void:
	OpsState.retract_lane(from_id, to_id, owner_id)

func _force_friendly_direction(lane: LaneData, from_id: int, to_id: int) -> void:
	var was_send_a: bool = lane.send_a
	var was_send_b: bool = lane.send_b
	if from_id == lane.a_id and to_id == lane.b_id:
		lane.send_a = true
		lane.send_b = false
		lane.dir = 1
		lane.retract_a = false
		if not was_send_a:
			lane.establish_a = true
			lane.a_stream_len = 0.0
		lane.establish_b = false
	elif from_id == lane.b_id and to_id == lane.a_id:
		lane.send_b = true
		lane.send_a = false
		lane.dir = -1
		lane.retract_b = false
		if not was_send_b:
			lane.establish_b = true
			lane.b_stream_len = 0.0
		lane.establish_a = false
	_track_hive_lane_intent(from_id, to_id, true)
	_track_hive_lane_intent(to_id, from_id, false)

func _set_intent_dev(from_id: int, to_id: int, enable: bool) -> void:
	var lane_index: int = _lane_index_between(from_id, to_id)
	if lane_index == -1:
		return
	var was_on: bool = _intent_is_on(from_id, to_id)
	var lane: LaneData = state.lanes[lane_index]
	var a: HiveData = _find_hive_by_id(lane.a_id)
	var b: HiveData = _find_hive_by_id(lane.b_id)
	if enable and a != null and b != null and _lane_mode(a, b) == "friendly":
		if _are_allied_owners(a.owner_id, b.owner_id):
			_force_friendly_direction(lane, from_id, to_id)
			return
	var was_send_a: bool = lane.send_a
	var was_send_b: bool = lane.send_b
	if enable:
		var from_hive: HiveData = _find_hive_by_id(from_id)
		if from_hive == null or from_hive.owner_id == 0:
			return
		if _intent_is_on(from_id, to_id):
			return
		if ENABLE_OUTGOING_LANE_BUDGET and state != null:
			var budget := state.lanes_allowed_for_power(int(from_hive.power))
			var active := state.count_active_outgoing(from_id)
			if active >= budget:
				SFLog.info("LANE_BUDGET_BLOCK", {
					"src": from_id,
					"dst": to_id,
					"power": int(from_hive.power),
					"active": active,
					"budget": budget
				})
				return
	if from_id == lane.a_id and to_id == lane.b_id:
		lane.send_a = enable
		if enable:
			lane.dir = 1
			lane.retract_a = false
			if not was_send_a:
				lane.establish_a = true
				lane.a_stream_len = 0.0
		else:
			lane.establish_a = false
	elif from_id == lane.b_id and to_id == lane.a_id:
		lane.send_b = enable
		if enable:
			lane.dir = -1
			lane.retract_b = false
			if not was_send_b:
				lane.establish_b = true
				lane.b_stream_len = 0.0
		else:
			lane.establish_b = false
	var is_on: bool = _intent_is_on(from_id, to_id)
	if was_on != is_on:
		_track_hive_lane_intent(from_id, to_id, is_on)

func _normalize_friendly_intents() -> void:
	for lane in state.lanes:
		var a: HiveData = _find_hive_by_id(lane.a_id)
		var b: HiveData = _find_hive_by_id(lane.b_id)
		if a == null or b == null:
			continue
		if a.owner_id == 0 or b.owner_id == 0:
			continue
		if not _are_allied_owners(a.owner_id, b.owner_id):
			continue
		if lane.send_a and lane.send_b:
			if lane.dir == -1:
				lane.send_a = false
				lane.establish_a = false
			else:
				lane.send_b = false
				lane.establish_b = false

func _intent_is_on(from_id: int, to_id: int) -> bool:
	var lane_index := _lane_index_between(from_id, to_id)
	if lane_index == -1:
		return false
	var lane: LaneData = state.lanes[lane_index]
	if from_id == lane.a_id and to_id == lane.b_id:
		return lane.send_a
	if from_id == lane.b_id and to_id == lane.a_id:
		return lane.send_b
	return false

func _lane_exists_between(a_id: int, b_id: int) -> bool:
	if state == null:
		return false
	return state.lane_exists_between(a_id, b_id)

func _lane_index_between(a_id: int, b_id: int) -> int:
	return state.lane_index_between(a_id, b_id)

func _ensure_lane_between(a_id: int, b_id: int, create_if_missing: bool) -> int:
	var lane_index: int = _lane_index_between(a_id, b_id)
	if lane_index != -1:
		return lane_index
	if not create_if_missing:
		return -1
	if not _is_los_clear(a_id, b_id):
		return -1
	dbg_mark_event("lane_build")
	var new_id: int = _next_lane_id()
	state.lanes.append(LaneData.new(new_id, a_id, b_id, 1, false, false))
	return state.lanes.size() - 1

func _next_lane_id() -> int:
	var max_id: int = 0
	for lane in state.lanes:
		if lane.id > max_id:
			max_id = lane.id
	return max_id + 1

func _los_cache_key(a_id: int, b_id: int) -> String:
	var min_id: int = min(a_id, b_id)
	var max_id: int = max(a_id, b_id)
	return "%d-%d" % [min_id, max_id]

func _is_los_clear(a_id: int, b_id: int) -> bool:
	var key: String = _los_cache_key(a_id, b_id)
	if los_cache.has(key):
		return bool(los_cache[key])
	if state == null:
		los_cache[key] = false
		return false
	# Keep Arena's legacy lane-build path aligned with the authoritative
	# occlusion logic used by input validation and OpsState runtime lanes.
	var can_connect: bool = state.can_connect(a_id, b_id)
	los_cache[key] = can_connect
	return can_connect

func _hive_id_at_point(local_pos: Vector2) -> int:
	if state == null:
		return -1
	if state.hives == null:
		return -1
	var best_id := -1
	var best_dist := INF
	var nodes: Dictionary = {}
	if hive_renderer != null and hive_renderer.has_method("get_hive_nodes_by_id"):
		nodes = hive_renderer.get_hive_nodes_by_id()
	for hive in state.hives:
		var render_gp: Vector2 = hive.render_grid_pos
		if not is_finite(render_gp.x) or not is_finite(render_gp.y):
			render_gp = Vector2(float(hive.grid_pos.x), float(hive.grid_pos.y))
		var center := _grid_coord_to_world(render_gp)
		var node: Node = nodes.get(int(hive.id), null) as Node
		if node is Node2D:
			center = (node as Node2D).position
		var dist := center.distance_squared_to(local_pos)
		var hive_radius: float = float(hive.radius_px)
		if hive_radius <= 0.0:
			hive_radius = HIVE_RADIUS_PX
		var hit_radius: float = HiveGeometry.hive_input_pick_radius_px(hive_radius, int(hive.power))
		if node != null and node.has_method("get_pick_radius_px"):
			hit_radius = float(node.call("get_pick_radius_px"))
		if dist <= hit_radius * hit_radius and dist < best_dist:
			best_dist = dist
			best_id = hive.id
	return best_id

func _cell_from_point(local_pos: Vector2) -> Vector2i:
	if grid_spec != null:
		return grid_spec.world_to_grid(local_pos)
	var adjusted := local_pos - map_offset
	var cell_px := _cell_px()
	var cx := int(adjusted.x / cell_px)
	var cy := int(adjusted.y / cell_px)
	cx = max(0, min(grid_w - 1, cx))
	cy = max(0, min(grid_h - 1, cy))
	return Vector2i(cx, cy)

func _clear_tap_state() -> void:
	if input_system != null:
		input_system.clear_tap_state()
	elif sel != null:
		sel.clear_tap_state()

func _clear_selection() -> void:
	if input_system != null:
		input_system.clear_selection()
	elif sel != null:
		sel.clear_selection()

func _reset_drag() -> void:
	if input_system != null:
		input_system.reset_drag()
	elif sel != null:
		sel.reset_drag()

func _has_prop(obj: Object, prop_name: String) -> bool:
	for p in obj.get_property_list():
		if String(p.name) == prop_name:
			return true
	return false
