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
const WallRenderer := preload("res://scripts/renderers/wall_renderer.gd")
const GridSpec := preload("res://scripts/maps/grid_spec.gd")
const SimTuning := preload("res://scripts/sim/sim_tuning.gd")
const SimEvents := preload("res://scripts/sim/sim_events.gd")
const VfxManager := preload("res://scripts/vfx/vfx_manager.gd")
const MatchRecordsStore := preload("res://scripts/state/match_records_store.gd")
const MatchTelemetryModelScript := preload("res://scripts/state/match_telemetry_model.gd")
const MatchTelemetryCollectorScript := preload("res://scripts/state/match_telemetry_collector.gd")
const MatchAnalyzerScript := preload("res://scripts/state/match_analyzer.gd")
const ArenaControlsHintController := preload("res://scripts/arena_helpers/controls_hint_controller.gd")
const ArenaTutorialSection1Controller := preload("res://scripts/arena_helpers/tutorial_section1_controller.gd")
const ArenaTutorialSection2Controller := preload("res://scripts/arena_helpers/tutorial_section2_controller.gd")
const ArenaTutorialSection3Controller := preload("res://scripts/arena_helpers/tutorial_section3_controller.gd")
const ArenaWorldViewportCache := preload("res://scripts/arena_helpers/world_viewport_cache.gd")
const ArenaStageRuntimeFlow := preload("res://scripts/arena_helpers/stage_runtime_flow.gd")
const ArenaPrematchTeamUiFormatter := preload("res://scripts/arena_helpers/prematch_team_ui_formatter.gd")
const ArenaInputBridgeUtils := preload("res://scripts/arena_helpers/input_bridge_utils.gd")
const ArenaFloorInfluenceSystem := preload("res://scripts/fx/arena_floor_influence_system.gd")

const GRID_W := 8
const GRID_H := 12
const CELL_SIZE := 64
const GRID_DEBUG := false
const RENDER_DEBUG := false
const LANE_ESTABLISH_MS := 2400.0
const UNIT_TRAVEL_MS := 4800.0
const SPAWN_BASE_MS := 1200.0
const SPAWN_PER_POWER_MS := 2.0
const SPAWN_MIN_MS := 250.0
const FIRST_UNIT_OFFSET_MS := 2.0
const SPIKE_PX := 48.0
const LANE_EDGE_T := 0.18
const DEBUG_COLLISION_ONLY := true
const DASH_GAP_PX := 6.0
const BASE_MS := 1000.0
const PER_POWER_MS := 2.0
const START_POWER := 10
const BONUS_10_MS := 2.0
const BONUS_25_MS := 2.0
const IDLE_GROWTH_MS := 1500.0
const CAPTURE_SHOCK_MS := 3000.0
const SWARM_SHOCK_MS := 3000.0
const DRAG_DEADZONE_PX := 8.0
const MAX_OUT_LANES := 2
const DOT_RADIUS := 3.0
const HIVE_DIAMETER_PX := 36.0
const HIVE_RADIUS_PX := HIVE_DIAMETER_PX * 0.5
const HIVE_PICK_PADDING_PX := 12.0
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
const DEBRIS_LIFE := 4.0
const DEBRIS_DRIFT := 30.0
const DEBRIS_DAMP := 0.90
const DEBRIS_MAX_PER_LANE := 8
const DEBRIS_GLOBAL_CAP := 800
const DEV_STATE_CHECKS := true
const PRESSURE_DECAY_PER_SEC := 1.0
const BLOCK_RADIUS_PX := CELL_SIZE * 0.25
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
const SHELL_POWER_BAR_PATH: String = SHELL_TOP_BUFFER_PATH + "/PowerBarAnchor/PowerBar"
const SHELL_OUTCOME_OVERLAY_PATH: String = SHELL_HUD_ROOT_PATH + "/OutcomeOverlay"
const SHELL_WIN_OVERLAY_PATH: String = SHELL_HUD_ROOT_PATH + "/WinOverlay"
const SHELL_SCENE_PATH: String = "res://scenes/Shell.tscn"
const VS_MODE_STAGE_RACE: String = "STAGE_RACE"
const TREE_META_VS_MODE: String = "vs_mode"
const TREE_META_VS_STAGE_MAP_PATHS: String = "vs_stage_map_paths"
const TREE_META_VS_STAGE_CURRENT_INDEX: String = "vs_stage_current_index"
const TREE_META_VS_STAGE_ROUND_RESULTS: String = "vs_stage_round_results"
const COUNTDOWN_DEBUG_SCRIPT: Script = preload("res://scripts/ui/prematch_countdown_view.gd")
const PREMATCH_RECORDS_WIDTH_PX: float = 520.0
const PREMATCH_RECORDS_HEIGHT_PX: float = 168.0
const PREMATCH_RECORDS_TOP_GAP_PX: float = 24.0
const PREMATCH_RECORDS_FONT_SIZE: int = 17

var state: GameState
var sel: SelectionState
var api: ArenaAPI
var input_system: InputSystem
var debug_system: DebugSystem
var audio_system: AudioSystem
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
@onready var floor_renderer: FloorRenderer = $MapRoot/FloorRenderer
@onready var lane_renderer = $MapRoot/LaneRenderer
@onready var tower_renderer_node = $MapRoot/TowerRenderer
@onready var hive_renderer: HiveRenderer = $MapRoot/HiveRenderer
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
var _cam_probe_accum: float = 0.0
var _world_viewport_cache: ArenaWorldViewportCache = ArenaWorldViewportCache.new()
var _stage_runtime_flow: ArenaStageRuntimeFlow = ArenaStageRuntimeFlow.new()
var _prematch_team_ui_formatter: ArenaPrematchTeamUiFormatter = ArenaPrematchTeamUiFormatter.new()
var _input_bridge_utils: ArenaInputBridgeUtils = ArenaInputBridgeUtils.new()
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
var _controls_hint_controller: ArenaControlsHintController = ArenaControlsHintController.new()
var _tutorial_section1_controller: ArenaTutorialSection1Controller = ArenaTutorialSection1Controller.new()
var _tutorial_section2_controller: ArenaTutorialSection2Controller = ArenaTutorialSection2Controller.new()
var _tutorial_section3_controller: ArenaTutorialSection3Controller = ArenaTutorialSection3Controller.new()
var _prematch_remaining_ms_f: float = 0.0
var _prematch_last_sec: int = -1
var _prematch_records_faded: bool = false
var _prematch_countdown_faded: bool = false
var _power_bar_reveal_started: bool = false
var _prematch_ui_bind_logged: bool = false
var _prematch_ui_state_logged: bool = false
var _postmatch_ui_missing_logged: bool = false
var _match_started: bool = false
var _match_records: MatchRecordsStore = MatchRecordsStore.new()
var _match_record_committed: bool = false
var _legacy_tick_fenced_logged: bool = false
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
@export var cam_fit_node_pad_px: float = 80.0
@export var cam_fit_reserved_top_px: float = 140.0
@export var cam_fit_reserved_bottom_px: float = 140.0
@export var cam_fit_height_world_pad_px: float = 0.0 # extra world padding when FIT_HEIGHT is active
@export var cam_fit_height_y_scale: float = 0.82 # < 1.0 shortens visible map height without changing width
@export var cam_fit_bias_y_px: float = -40.0 # negative = push camera up, positive = push down
@export var cam_fit_bias_x_px: float = 16.0 # positive = push board right, negative = push left
@export var cam_fit_mode: int = FIT_HEIGHT # 0=contain(min), 1=fit_width, 2=fit_height
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
var _post_match_analysis_summary: Dictionary = {}
var _post_match_telemetry_path: String = ""
var _telemetry_active: bool = false
var _map_build_version: int = 0
var _map_built_version: int = -1
var _map_bounds_size: Vector2 = Vector2.ZERO
var _map_bounds_missing_logged: bool = false
var _fit_serial := 0
var _fit_applied_serial := -1
var _dev_tick_log_ms: int = 0
var _dev_sim_dbg_us: int = 0
var _last_spawnfail_ms: int = 0
var _last_export_log_ms: int = 0
@export var debug_export_rm_log := false
@export var debug_export_rm_log_interval_ms := 1000
var _last_export_rm_log_ms := 0
@export var debug_swarms := false
var _last_render_serial: int = -1
var _last_rm_ms: int = 0
const RM_REFRESH_HZ := 10.0
const POWERBAR_LOG_THROTTLE_MS: int = 250
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
var _hb_phys: int = 0
var _hb_max_phys_ms: float = 0.0
var _hb_sum_phys_ms: float = 0.0
var _vs_pvp_runtime: Node = null
var floor_influence_system: ArenaFloorInfluenceSystem = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	SFLog.allow_tag("ARENA_FRAME_HEARTBEAT")
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
	self.scale = Vector2.ONE
	SFLog.info("POWER_BAR_REF", {"exists": power_bar != null, "path": power_bar.get_path() if power_bar != null else "<null>"})
	if power_bar == null:
		power_bar = _resolve_power_bar_node()
	if power_bar == null:
		SFLog.error("POWER_BAR_BIND_FAIL", {"path": SHELL_POWER_BAR_PATH})
	else:
		SFLog.info("POWER_BAR_BOUND", {"path": power_bar.get_path(), "inside_tree": power_bar.is_inside_tree()})
	var dmr := get_node_or_null("/root/DevMapRunner")
	if dmr:
		for c in dmr.get_children():
			if c.name == "Arena":
				continue
			if c.name == "DevMapLoader":
				continue
			if c is CanvasItem:
				(c as CanvasItem).visible = false
				SFLog.trace("HIDING", {"path": c.get_path(), "type": c.get_class()})
	RenderingServer.set_default_clear_color(Color(0.168627, 0.168627, 0.168627, 1))
	SFLog.trace("ARENA PATH", {"path": get_path()})
	SFLog.trace("ARENA COUNT", {"count": get_tree().get_nodes_in_group("Arena").size()})
	SFLog.trace("\n=== ROOT CHILDREN ===")
	for c in get_tree().root.get_children():
		SFLog.trace(" - ", {"path": c.get_path(), "type": c.get_class()})
	clear_map_render()
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
	_apply_canon_camera_fit("ready")
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
	_apply_autostart()
	_ensure_timer_hud()
	_start_match_flow()
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
	_log_fit_state("ready")
	mark_render_dirty("ready")
	_dump_map_like_nodes("after_clear_ready")
	_debug_scan_names()
	_dump_map_renderers("boot")
	_dump_viewports_and_textures()
	_dump_tree_with_scripts("/root/DevMapRunner")
	# (moved to top of _ready())
	_list_canvasitems_with_scripts("/root/DevMapRunner/Arena")

func _start_match_flow() -> void:
	SFLog.info("PREMATCH_BEGIN", {})
	_force_unpause_sanity()
	_ensure_prematch_ui()
	if _controls_hint_controller != null:
		_controls_hint_controller.ensure_overlay(Callable(self, "_resolve_hud_root"), Callable(self, "_force_fullscreen_anchors"))
	_begin_prematch()
	var tutorial_active: bool = false
	if _tutorial_section1_controller != null:
		tutorial_active = _tutorial_section1_controller.start_if_needed(
			Callable(self, "_resolve_hud_root"),
			Callable(self, "_force_fullscreen_anchors"),
			_resolve_local_owner_id(),
			state
		)
	if not tutorial_active and _tutorial_section2_controller != null:
		tutorial_active = _tutorial_section2_controller.start_if_needed(
			Callable(self, "_resolve_hud_root"),
			Callable(self, "_force_fullscreen_anchors"),
			_resolve_local_owner_id(),
			state
		)
	if not tutorial_active and _tutorial_section3_controller != null:
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
	elif _controls_hint_controller != null:
		_controls_hint_controller.maybe_show_once(Callable(self, "_resolve_hud_root"), Callable(self, "_force_fullscreen_anchors"))

func _apply_tutorial_low_pressure_scenario() -> void:
	if OpsState == null or not OpsState.has_method("set_bot_profile"):
		return
	var local_owner_id: int = _resolve_local_owner_id()
	for seat in [1, 2, 3, 4]:
		var seat_id: int = int(seat)
		if seat_id == local_owner_id:
			continue
		OpsState.call("set_bot_profile", seat_id, {
			"enabled": false,
			"opening_delay_ms": 999999,
			"aggression": 0.0
		})
	SFLog.info("TUTORIAL_LOW_PRESSURE_SCENARIO", {"local_owner_id": local_owner_id})

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
				"outcome_path": str(outcome_overlay.get_path()),
				"win_path": str(win_overlay.get_path())
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
	panel.offset_left = -200.0
	panel.offset_top = -240.0
	panel.offset_right = 200.0
	panel.offset_bottom = 240.0
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
	_match_started = false
	var prematch_dur_ms: int = OpsState.prematch_duration_ms
	if prematch_dur_ms <= 0:
		prematch_dur_ms = OpsState.PREMATCH_DURATION_MS
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
	_prematch_last_sec = -1
	_prematch_records_faded = false
	_prematch_countdown_faded = false
	_power_bar_reveal_started = false
	_show_prematch_ui()
	if sim_runner != null:
		sim_runner.set_running(false, "prematch_hold")
	SFLog.info("PREMATCH_START", {
		"duration_s": int(round(float(OpsState.prematch_duration_ms) / 1000.0))
	})

func _configure_vs_pvp_runtime() -> void:
	_vs_pvp_runtime = get_node_or_null("/root/VsPvpRuntime")
	if _vs_pvp_runtime == null or not _vs_pvp_runtime.has_method("configure_from_tree"):
		return
	var tree: SceneTree = get_tree()
	var roster: Array = OpsState.match_roster if OpsState != null else []
	_vs_pvp_runtime.call("configure_from_tree", tree, roster)
	if _vs_pvp_runtime.has_method("is_active") and bool(_vs_pvp_runtime.call("is_active")):
		var local_seat: int = 1
		if _vs_pvp_runtime.has_method("get_local_seat"):
			local_seat = clampi(int(_vs_pvp_runtime.call("get_local_seat")), 1, 4)
		active_player_id = local_seat

func _pump_vs_pvp_runtime(delta: float) -> void:
	if _vs_pvp_runtime == null or not _vs_pvp_runtime.has_method("is_active"):
		return
	if not bool(_vs_pvp_runtime.call("is_active")):
		return
	if _vs_pvp_runtime.has_method("tick"):
		_vs_pvp_runtime.call("tick", delta)
	if not _vs_pvp_runtime.has_method("consume_remote_commands"):
		return
	var commands_any: Variant = _vs_pvp_runtime.call("consume_remote_commands")
	if typeof(commands_any) != TYPE_ARRAY:
		return
	_apply_remote_pvp_commands(commands_any as Array)

func _apply_remote_pvp_commands(commands: Array) -> void:
	if commands == null or commands.is_empty():
		return
	var st: GameState = OpsState.get_state() if OpsState != null else null
	if st == null:
		return
	var remote_seat: int = 2
	if _vs_pvp_runtime != null and _vs_pvp_runtime.has_method("get_remote_seat"):
		remote_seat = clampi(int(_vs_pvp_runtime.call("get_remote_seat")), 1, 4)
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
				if src_owner != remote_seat or sent_owner != src_owner:
					continue
				OpsState.with_remote_replication_apply(func() -> void:
					OpsState.apply_lane_intent(src, dst, intent)
				)
				mark_render_dirty("remote_lane_intent")
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
				if owner_id != remote_seat or actual_owner != remote_seat:
					continue
				OpsState.with_remote_replication_apply(func() -> void:
					OpsState.retract_lane(from_id, to_id, owner_id)
				)
				mark_render_dirty("remote_lane_retract")
			"barracks_route":
				var barracks_id: int = int(cmd.get("barracks_id", -1))
				var route_any: Variant = cmd.get("route_hive_ids", [])
				var route: Array = route_any as Array if typeof(route_any) == TYPE_ARRAY else []
				var owner_for_route: int = int(cmd.get("owner_id", -1))
				if barracks_id <= 0:
					continue
				if owner_for_route <= 0:
					owner_for_route = remote_seat
				if owner_for_route != remote_seat:
					continue
				OpsState.with_remote_replication_apply(func() -> void:
					OpsState.request_barracks_route(barracks_id, route, owner_for_route)
				)
				mark_render_dirty("remote_barracks_route")
			_:
				continue

func _ensure_prematch_ui() -> void:
	if _prematch_overlay != null and is_instance_valid(_prematch_overlay):
		return
	var ui_root: Node = get_node_or_null(SHELL_HUD_ROOT_PATH)
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
	var overlay := ui_root.get_node_or_null("PreMatchOverlay") as Control
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
		countdown.anchor_left = 0.5
		countdown.anchor_right = 0.5
		countdown.anchor_top = 0.0
		countdown.anchor_bottom = 0.0
		countdown.offset_left = -40.0
		countdown.offset_right = 40.0
		countdown.offset_top = 20.0
		countdown.offset_bottom = 60.0
		countdown.add_theme_font_size_override("font_size", 64)
		_prematch_overlay.add_child(countdown)
	_prematch_countdown_label = countdown
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
	_prematch_records_panel = records
	_prematch_record_p1 = p1
	_prematch_record_p2 = p2
	_prematch_record_p3 = p3
	_prematch_record_p4 = p4
	_prematch_record_h2h = h2h
	_prematch_record_teams = teams
	_prematch_record_team_arrows = team_arrows
	if not _prematch_ui_bind_logged:
		_prematch_ui_bind_logged = true
		SFLog.info("PREMATCH_UI_BIND", {
			"overlay_path": str(_prematch_overlay.get_path()),
			"countdown_path": str(_prematch_countdown_label.get_path()) if _prematch_countdown_label != null else "<null>",
			"records_path": str(_prematch_records_panel.get_path()) if _prematch_records_panel != null else "<null>",
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

func _layout_prematch_records_panel(records: Control) -> void:
	if records == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var vr: Rect2 = vp.get_visible_rect()
	var top_inset: float = _ui_top_inset_px()
	var panel_top: float = top_inset + PREMATCH_RECORDS_TOP_GAP_PX
	records.position = Vector2((vr.size.x - PREMATCH_RECORDS_WIDTH_PX) * 0.5, panel_top)
	records.size = Vector2(PREMATCH_RECORDS_WIDTH_PX, PREMATCH_RECORDS_HEIGHT_PX)

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
				"path": _prematch_countdown_label.get_path(),
				"type": _prematch_countdown_label.get_class()
			})
		_prematch_countdown_label.modulate = Color(1, 1, 1, 1)
	_refresh_prematch_records()
	if _prematch_records_panel != null:
		_layout_prematch_records_panel(_prematch_records_panel)
		_prematch_records_panel.visible = true
		_prematch_records_panel.modulate = Color(1, 1, 1, 1)
		SFLog.warn("PREMATCH_UI_VIS", {
			"records_path": str(_prematch_records_panel.get_path()),
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
			"overlay_path": str(_prematch_overlay.get_path()),
			"overlay_visible": _prematch_overlay.visible,
			"overlay_z": _prematch_overlay.z_index
		}, "", 250)
	SFLog.info("PREMATCH_UI_INIT", {
		"overlay_ok": _prematch_overlay != null,
		"countdown_ok": _prematch_countdown_label != null,
		"records_ok": _prematch_records_panel != null
	})

func _refresh_prematch_records() -> void:
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

func _get_team_banner_line() -> String:
	var local_seat: int = _resolve_local_owner_id()
	return _prematch_team_ui_formatter.format_team_banner_line(
		_record_active_seats(),
		Callable(self, "_resolve_team_for_seat"),
		local_seat
	)

func _get_team_arrow_line() -> String:
	return _prematch_team_ui_formatter.format_team_arrow_line(
		_record_active_seats(),
		Callable(self, "_resolve_team_for_seat")
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

func _get_player_record_line(player_slot: int) -> String:
	var entry: Dictionary = _get_roster_entry_for_slot(player_slot)
	var uid: String = str(entry.get("uid", ""))
	var is_cpu: bool = bool(entry.get("is_cpu", false))
	var handle: String = _display_name_for_seat(player_slot, uid, is_cpu)
	var record_key: String = _record_key_for_roster_entry(entry)
	var record: Dictionary = _match_records.get_record(record_key)
	var wins: int = int(record.get("wins", 0))
	var losses: int = int(record.get("losses", 0))
	var uid_label: String = uid
	if uid_label.is_empty():
		if is_cpu:
			uid_label = "cpu"
		else:
			uid_label = "unassigned"
	SFLog.info("PREMATCH_NAME_RESOLVE", {
		"seat": player_slot,
		"uid": uid,
		"handle": handle
	})
	return "P%d [%s] %s  W-L %d-%d" % [player_slot, uid_label, handle, wins, losses]

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
	var sec_left: int = 0
	if _prematch_remaining_ms_f > 0.0:
		sec_left = int(ceil(_prematch_remaining_ms_f / 1000.0))
	if sec_left != _prematch_last_sec:
		_prematch_last_sec = sec_left
		SFLog.info("PREMATCH_TICK", {
			"ms": OpsState.prematch_remaining_ms,
			"sec": int(ceil(float(OpsState.prematch_remaining_ms) / 1000.0))
		})
	if _prematch_remaining_ms_f <= 0.0 and not _prematch_countdown_faded:
		_prematch_countdown_faded = true
		if not _prematch_records_faded:
			_prematch_records_faded = true
			_fade_prematch_records()
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
	_start_match_sim("prematch_complete")
	SFLog.warn("INPUT_UNLOCKED", {"reason": "prematch_complete"})

func _begin_power_bar_reveal() -> void:
	# UI observes OpsState; no sim-driven UI mutations.
	return

func _prewarm_render_assets() -> void:
	if _render_assets_prewarmed:
		return
	_render_assets_prewarmed = true
	if unit_renderer != null and unit_renderer.has_method("prewarm_pool"):
		unit_renderer.call("prewarm_pool")
	if vfx_manager != null and vfx_manager.has_method("prewarm"):
		vfx_manager.call("prewarm")

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
	if floor_influence_system != null:
		floor_influence_system.notify_match_started()
	SFLog.info("MATCH_STARTED", {"iid": iid, "reason": reason})

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
	_match_telemetry_collector.call(
		"begin_match",
		match_id,
		season_id,
		map_id,
		match_type,
		player_ids,
		start_utc_ms
	)
	var active_any: Variant = false
	if _match_telemetry_collector.has_method("is_active"):
		active_any = _match_telemetry_collector.call("is_active")
	_telemetry_active = bool(active_any)
	if unit_system != null and unit_system.has_method("set_match_telemetry_collector"):
		unit_system.call("set_match_telemetry_collector", _match_telemetry_collector)
	SFLog.info("TELEMETRY_BEGIN", {
		"match_id": match_id,
		"season_id": season_id,
		"map_id": map_id,
		"match_type": match_type,
		"players": player_ids,
		"reason": reason
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
	if _match_telemetry_collector.has_method("save_to_user"):
		save_result_any = _match_telemetry_collector.call("save_to_user", telemetry_model)
	var save_result: Dictionary = save_result_any as Dictionary if typeof(save_result_any) == TYPE_DICTIONARY else {}
	if bool(save_result.get("ok", false)):
		_post_match_telemetry_path = str(save_result.get("path", ""))
	else:
		_post_match_telemetry_path = ""
		SFLog.warn("TELEMETRY_SAVE_FAILED", save_result)
	_telemetry_active = false
	SFLog.info("TELEMETRY_FINALIZE", {
		"winner_id": winner_id_in,
		"summary_insights": int(_post_match_analysis_summary.get("insights", []).size()),
		"save_path": _post_match_telemetry_path
	})

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
	var swarm_pass_state: Node = get_node_or_null("/root/SwarmPassState")
	if swarm_pass_state != null and swarm_pass_state.has_method("get_snapshot"):
		var swarm_snapshot_any: Variant = swarm_pass_state.call("get_snapshot")
		if typeof(swarm_snapshot_any) == TYPE_DICTIONARY:
			var swarm_snapshot: Dictionary = swarm_snapshot_any as Dictionary
			var season_from_swarm: String = str(swarm_snapshot.get("season_id", "")).strip_edges()
			if season_from_swarm != "":
				return season_from_swarm
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
	if _is_stage_race_runtime_mode():
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
	if unit_system != null and sim_events != null and unit_system.has_method("set_sim_events"):
		unit_system.set_sim_events(sim_events)
	if unit_system != null and unit_system.has_method("set_match_telemetry_collector"):
		unit_system.call("set_match_telemetry_collector", _match_telemetry_collector)
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
	if unit_system != null and unit_system.has_method("set_match_telemetry_collector"):
		unit_system.call("set_match_telemetry_collector", _match_telemetry_collector)

func _ensure_sim_events() -> void:
	if sim_events != null and is_instance_valid(sim_events):
		return
	var existing := get_node_or_null("SimEvents")
	if existing is SimEvents:
		sim_events = existing as SimEvents
		return
	sim_events = SimEvents.new()
	sim_events.name = "SimEvents"
	add_child(sim_events)

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
		if TRACE_ARENA_PRINTS:
			print("UNIT_PARENT:", unit_renderer.get_path())

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
				"target_parent": str(pools_parent.get_path()),
				"node_path": str(vfx_manager.get_path())
			})
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
		print("VFX_PARENT:", vfx_manager.get_path())
	if vfx_manager != null and vfx_manager.get_parent() != pools_root:
		vfx_manager.reparent(pools_root)
		SFLog.allow_tag("VFX_REPARENT")
		SFLog.warn("VFX_REPARENT", {
			"target_parent": str(pools_root.get_path()),
			"node_path": str(vfx_manager.get_path())
		})
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
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null and profile_manager.has_method("is_floor_graphics_enabled"):
		return bool(profile_manager.call("is_floor_graphics_enabled"))
	return enable_floor_influence_runtime

func set_gpu_vfx_enabled(enabled: bool) -> void:
	_ensure_vfx_manager()
	if vfx_manager != null and vfx_manager.has_method("set_gpu_vfx_enabled"):
		vfx_manager.call("set_gpu_vfx_enabled", enabled)

func set_floor_graphics_enabled(enabled: bool) -> void:
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
	if floor_influence_system != null:
		floor_influence_system.notify_match_ended()
	if input_system != null:
		input_system.set_inputs_locked(true, "match_end")
	game_over = true
	winner_id = winner_id_in
	end_reason = reason
	_commit_match_records(winner_id_in)
	_finalize_match_telemetry_session(winner_id_in)
	SFLog.info("MATCH_END_HANDLE", {"winner_id": winner_id_in})
	call_deferred("_match_end_deferred", winner_id_in, reason)

func _match_end_deferred(winner_id_in: int, reason: String) -> void:
	if _controls_hint_controller != null:
		_controls_hint_controller.hide(false)
	if _tutorial_section1_controller != null:
		_tutorial_section1_controller.on_match_ended()
	if _tutorial_section2_controller != null:
		_tutorial_section2_controller.on_match_ended()
	if _tutorial_section3_controller != null:
		_tutorial_section3_controller.on_match_ended()
	if _is_stage_race_runtime_mode():
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
		outcome_overlay.show_outcome(winner_id_in, reason, active_player_id, record_text, h2h_text)
		if outcome_overlay.has_method("set_post_match_summary"):
			outcome_overlay.call("set_post_match_summary", _post_match_analysis_summary, winner_id_in, active_player_id)
	else:
		SFLog.warn("POSTMATCH_UI_MISSING", {"kind": "outcome_overlay"})
	if sim_runner != null:
		sim_runner.log_pause_snapshot("arena_show_outcome")
	mark_render_dirty("match_end")

func _on_post_match_action(action: String) -> void:
	if action == "rematch_vote" and not _is_stage_race_runtime_mode():
		var voter_id: int = active_player_id
		if voter_id != 1 and voter_id != 2:
			voter_id = 1
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
		"next_round":
			_post_match_action_taken = true
			_advance_stage_race_round()
		"finish_run":
			_post_match_action_taken = true
			_clear_stage_runtime_meta()
			_return_to_main_menu()
		"rematch":
			_post_match_action_taken = true
			_handle_rematch()
		"main_menu":
			_post_match_action_taken = true
			if _is_stage_race_runtime_mode():
				_clear_stage_runtime_meta()
			_return_to_main_menu()
		_:
			return

func _is_stage_race_runtime_mode() -> bool:
	return _stage_runtime_flow.is_stage_race_runtime_mode(get_tree(), TREE_META_VS_MODE, VS_MODE_STAGE_RACE)

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
	var local_owner_id: int = _resolve_local_owner_id()
	if local_owner_id <= 0:
		local_owner_id = clampi(active_player_id, 1, 4)
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
	return {
		"round_number": round_index + 1,
		"total_rounds": total_rounds,
		"winner_id": winner_id_in,
		"reason": reason,
		"local_owner_id": local_owner_id,
		"round_time_ms": elapsed_ms,
		"local_owned_hives": local_owned_hives,
		"opponent_owned_hives": opponent_owned_hives,
		"current_rank": int(rank_snapshot.get("rank", 0)),
		"local_round_wins": int(rank_snapshot.get("local_wins", 0)),
		"opponent_round_wins": int(rank_snapshot.get("opponent_wins", 0)),
		"cumulative_time_ms": maxi(0, int(rank_snapshot.get("local_elapsed_ms", elapsed_ms))),
		"next_round_available": round_index + 1 < total_rounds
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
	var next_round_available: bool = bool(summary.get("next_round_available", false))
	var next_action: String = "next_round" if next_round_available else "finish_run"
	var next_label: String = "Next Round" if next_round_available else "Finish Run"
	var status_text: String = "Cumulative rank is provisional. Ready for next round?" if next_round_available else "Cumulative rank is provisional. Run complete."
	var payload: Dictionary = summary.duplicate(true)
	payload["next_action"] = next_action
	payload["next_label"] = next_label
	payload["exit_label"] = "Back to Lobby"
	payload["status_text"] = status_text
	payload["next_round_available"] = true
	payload["next_button_enabled"] = true
	outcome_overlay.show_stage_round_outcome(payload)

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
		TREE_META_VS_STAGE_ROUND_RESULTS
	]
	for key in keys:
		if tree.has_meta(key):
			tree.remove_meta(key)

func _handle_rematch() -> void:
	if current_map_data.is_empty():
		if SFLog.LOGGING_ENABLED:
			push_error("ARENA: rematch failed (no map data)")
		return
	SFLog.info("MATCH_RESET", {"map": current_map_name})
	if outcome_overlay != null:
		outcome_overlay.hide_overlay()
	_reset_sim_state()
	MapApplier.apply_map(self, current_map_data.duplicate(true))

func _return_to_main_menu() -> void:
	if outcome_overlay != null:
		outcome_overlay.hide_overlay()
	if sim_runner != null:
		sim_runner.log_pause_snapshot("arena_return_to_main_menu")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

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
			hive_list.append({
				"id": int(key),
				"pos": node.position
			})
	if hive_list.is_empty() and state != null:
		for hive in state.hives:
			hive_list.append({
				"id": int(hive.id),
				"pos": cell_center(hive.grid_pos)
			})
	if hive_list.is_empty():
		return
	lane_system.set_blockers_from_hives(hive_list, BLOCK_RADIUS_PX)

func get_game_state() -> GameState:
	return state

func _on_ops_state_changed(new_state: GameState) -> void:
	state = new_state
	if state == null:
		return
	# MapApplier swaps in a fresh authoritative state without calling Arena._reset_sim_state().
	# Clear post-match latches here so stage-race rounds can always advance.
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		if FIT_DEBUG:
			var viewport_size: Vector2 = get_viewport().get_visible_rect().size
			var window_size: Vector2i = DisplayServer.window_get_size()
			dbg("FIT: wm_size_changed viewport=%s window=%s" % [viewport_size, window_size])

func _on_viewport_size_changed() -> void:
	_resize_world_viewport()
	fitcam_once()
	_center_match_timer()
	if _prematch_records_panel != null and _prematch_records_panel.visible:
		_layout_prematch_records_panel(_prematch_records_panel)
	_snap_power_bar_to_map_top("viewport_resize")

func _resize_world_viewport() -> void:
	var tree: SceneTree = get_tree()
	var wvc: Control = _world_viewport_cache.resolve_container(tree) if _world_viewport_cache != null else null
	var sv: SubViewport = _world_viewport_cache.resolve_subviewport(tree) if _world_viewport_cache != null else null
	if wvc == null or sv == null:
		return
	var overscan_x: float = 80.0
	var overscan_y: float = 120.0
	var old_size: Vector2i = sv.size
	var target: Vector2 = wvc.size + Vector2(overscan_x * 2.0, overscan_y * 2.0)
	var new_w: int = max(1, int(target.x))
	var new_h: int = max(1, int(target.y))
	var new_size: Vector2i = Vector2i(new_w, new_h)
	sv.size = new_size
	SFLog.info("WVP_RESIZE", {
		"wvc_path": str(wvc.get_path()),
		"container_size": wvc.size,
		"sv_old": old_size,
		"sv_new": sv.size,
		"overscan": [overscan_x, overscan_y]
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
	grid_spec.configure(grid_w_in, grid_h_in, cell_px, origin)
	_sync_playfield_outline()
	grid_w = grid_spec.grid_w
	grid_h = grid_spec.grid_h
	if floor_influence_system == null:
		_ensure_floor_influence_system()
	if floor_renderer != null:
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
		var grid_pos: Vector2i = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
		var owner_id: int = int(hive_data.get("owner_id", 0))
		var power: int = START_POWER
		var kind: String = str(hive_data.get("kind", "Hive"))
		var radius_px: float = float(hive_data.get("radius_px", hive_data.get("radius", 0.0)))
		if radius_px <= 0.0:
			radius_px = MapSchema.hive_radius_px_for_kind(kind, _cell_px())
		var hive := HiveData.new(int(hive_data["id"]), grid_pos, owner_id, power, kind, radius_px)
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
	_apply_autostart()
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
	_fit_serial += 1
	_fit_applied_serial = -1

func on_map_built() -> void:
	if _map_built_version == _map_build_version:
		return
	_map_built_version = _map_build_version
	_rebuild_map_markers()
	_normalize_map_root()
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
	_snap_power_bar_to_map_top("map_built")

func fitcam_once() -> void:
	if _map_built_version < 0:
		return
	if _fit_applied_serial == _fit_serial:
		return
	_fit_applied_serial = _fit_serial
	_apply_canon_camera_fit("fitcam_once")
	_snap_power_bar_to_map_top("fitcam_once")

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
	# autostart == true
	sim_runner.set_running(true, "arena_apply_autostart_true")

func start_sim() -> void:
	if sim_runner == null:
		return
	autostart = true
	sim_runner.start_sim()
	sim_runner.log_pause_snapshot("arena_start_sim")

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_maybe_debug_camera_probe(delta)
	_tick_arena_heartbeat(delta)
	_tick_arena_runtime(delta)

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
	_update_prematch_flow(delta)
	if OpsState.match_phase == OpsState.MatchPhase.PREMATCH \
	and int(OpsState.prematch_remaining_ms) <= 0 \
	and bool(OpsState.input_locked):
		SFLog.warn("PREMATCH_WATCHDOG_FINISH", {
			"remaining_ms": int(OpsState.prematch_remaining_ms),
			"input_locked": bool(OpsState.input_locked)
		})
		_finish_prematch()
	if input_system != null:
		input_system.tick(delta, api)
		_sync_inputs_locked_from_state()
	_pump_vs_pvp_runtime(delta)
	_update_timer_ui()
	if tie_toast != null and tie_toast_ms > 0.0:
		tie_toast_ms = max(0.0, tie_toast_ms - delta * 1000.0)
		if tie_toast_ms <= 0.0:
			tie_toast.visible = false
	_update_win_overlay()
	_update_selection_hud()
	_update_buff_ui()
	if _tutorial_section1_controller != null and state != null:
		_tutorial_section1_controller.tick(state, _resolve_local_owner_id())
	if _tutorial_section2_controller != null and state != null:
		_tutorial_section2_controller.tick(state, _resolve_local_owner_id())
	if _tutorial_section3_controller != null and state != null:
		_tutorial_section3_controller.tick(state, _resolve_local_owner_id())

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
	var phys_ticks: int = _hb_phys
	var avg_phys_ms: float = 0.0
	if phys_ticks > 0:
		avg_phys_ms = _hb_sum_phys_ms / float(phys_ticks)
	SFLog.info("ARENA_FRAME_HEARTBEAT", {
		"frames": frames,
		"fps": snapped(fps_est, 0.1),
		"max_frame_ms": snapped(_hb_max_frame_ms, 0.1),
		"avg_frame_ms": snapped(avg_frame_ms, 0.1),
		"physics_ticks": phys_ticks,
		"max_physics_ms": snapped(_hb_max_phys_ms, 0.1),
		"avg_physics_ms": snapped(avg_phys_ms, 0.1)
	})
	_hb_last_ms = now_ms
	_hb_frames = 0
	_hb_max_frame_ms = 0.0
	_hb_sum_frame_ms = 0.0
	_hb_phys = 0
	_hb_max_phys_ms = 0.0
	_hb_sum_phys_ms = 0.0

func _update_power_bar(delta: float) -> void:
	# UI observes OpsState; no sim-driven UI mutations.
	return

func _maybe_log_frame_hitch(delta: float) -> void:
	if not DBG_HITCH:
		return
	var dt_ms: float = delta * 1000.0
	if dt_ms > HITCH_MS:
		print("HITCH dt_ms=", snappedf(dt_ms, 0.1))

func dbg_mark_event(label: String) -> void:
	_dbg_last_event = label
	_dbg_last_event_ms = Time.get_ticks_msec()
	SFLog.mark_event(label)

func _snap_power_bar_to_map_top(reason: String = "") -> void:
	return # PowerBar is HUD/buffer-placed; do not snap to play surface.

func _sync_inputs_locked_from_state() -> void:
	if input_system == null:
		return
	var should_lock := bool(OpsState.input_locked)
	if should_lock == _inputs_locked_from_state:
		return
	_inputs_locked_from_state = should_lock
	var reason := OpsState.input_locked_reason if should_lock else ""
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
		SFLog.trace(" - ", {"path": c.get_path(), "current": c.is_current(), "enabled": c.enabled})

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
			"path": n.get_path(),
			"type": n.get_class(),
			"parent": n.get_parent().get_path()
		})

func _dump_map_renderers(tag: String) -> void:
	SFLog.trace("\n=== RENDERER DUMP ===", {"tag": tag})
	var root := get_tree().root
	var arenas := root.find_children("Arena", "Node", true, false)
	SFLog.trace("Arenas", {"count": arenas.size()})
	for a in arenas:
		SFLog.trace(" - ", {"path": a.get_path()})
	var map_roots := root.find_children("MapRoot", "Node", true, false)
	SFLog.trace("MapRoots", {"count": map_roots.size()})
	for m in map_roots:
		SFLog.trace(" - ", {"path": m.get_path()})
	var hrs := root.find_children("HiveRenderer", "Node", true, false)
	SFLog.trace("HiveRenderers", {"count": hrs.size()})
	for h in hrs:
		SFLog.trace(" - ", {
			"path": h.get_path(),
			"vis": (h.visible if h is CanvasItem else "n/a"),
			"children": h.get_child_count()
		})
	var lrs := root.find_children("LaneRenderer", "Node", true, false)
	SFLog.trace("LaneRenderers", {"count": lrs.size()})
	for l in lrs:
		SFLog.trace(" - ", {
			"path": l.get_path(),
			"vis": (l.visible if l is CanvasItem else "n/a"),
			"children": l.get_child_count()
		})

func _dump_tree_with_scripts(path: String) -> void:
	var root := get_node_or_null(path)
	if root == null:
		SFLog.trace("DUMP: node not found", {"path": path})
		return
	SFLog.trace("\n=== TREE DUMP ===", {"path": root.get_path()})
	_dump_node(root, 0)

func _dump_node(n: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var s := ""
	if n.get_script() != null:
		s = " script=" + str(n.get_script().resource_path)
	SFLog.trace(indent + "- ", {"path": n.get_path(), "type": n.get_class(), "script": s})
	for c in n.get_children():
		_dump_node(c, depth + 1)

func _list_canvasitems_with_scripts(path: String) -> void:
	var root := get_node_or_null(path)
	if root == null:
		SFLog.trace("SCAN: node not found", {"path": path})
		return
	SFLog.trace("\n=== CANVASITEM SCAN ===", {"path": root.get_path()})
	var items := root.find_children("", "CanvasItem", true, false)
	for it in items:
		var ci := it as CanvasItem
		var sp := ""
		if it.get_script() != null:
			sp = str(it.get_script().resource_path)
		if sp != "":
			SFLog.trace(" - ", {"path": it.get_path(), "type": it.get_class(), "vis": ci.visible, "script": sp})

func _dump_viewports_and_textures() -> void:
	SFLog.trace("\n=== VIEWPORT/TEXTURE DUMP ===")
	var root := get_tree().root
	var svcs := root.find_children("", "SubViewportContainer", true, false)
	SFLog.trace("SubViewportContainers", {"count": svcs.size()})
	for c in svcs:
		SFLog.trace(" - ", {"path": c.get_path()})
	var svs := root.find_children("", "SubViewport", true, false)
	SFLog.trace("SubViewports", {"count": svs.size()})
	for v in svs:
		SFLog.trace(" - ", {
			"path": v.get_path(),
			"update": v.render_target_update_mode,
			"clear": v.render_target_clear_mode
		})
	var trs := root.find_children("", "TextureRect", true, false)
	SFLog.trace("TextureRects", {"count": trs.size()})
	for t in trs:
		var tex: Texture2D = t.texture
		SFLog.trace(" - ", {"path": t.get_path(), "tex": (tex.resource_path if tex else "null")})

func _kill_foreign_renderers(keep_arena: Node) -> void:
	var keep_prefix := str(keep_arena.get_path())
	for n in get_tree().root.find_children("HiveRenderer", "Node", true, false):
		var p := str(n.get_path())
		if not p.begins_with(keep_prefix):
			SFLog.trace("KILL HiveRenderer", {"path": p})
			if n is CanvasItem:
				n.visible = false
			n.queue_free()
	for n in get_tree().root.find_children("LaneRenderer", "Node", true, false):
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
		SFLog.trace("FOUND", {"path": str(n.get_path()), "type": n.get_class()})

func _scan(n: Node, out: Array[Node]) -> void:
	var cname := n.get_class()
	if cname.find("Hive") != -1 or cname.find("Lane") != -1 or str(n.name).find("Hive") != -1 or str(n.name).find("Lane") != -1:
		out.append(n)
	for c in n.get_children():
		_scan(c, out)

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

func _compute_fit_zoom_for_mode(viewport_size: Vector2, margin: float, fit_mode: int) -> float:
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
func cam_fit_height_to_bounds(camera_node: Camera2D, bounds_world: Rect2, top_px: float, bottom_px: float, pad_world: float = 0.0) -> Dictionary:
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
	var y_scale: float = clampf(cam_fit_height_y_scale, 0.75, 1.25)
	var z_y: float = clampf(z * y_scale, 0.02, 50.0)
	var center: Vector2 = padded_bounds.position + padded_bounds.size * 0.5
	if z_y > 0.0:
		# Keep world centered in the remaining playable strip when top/bottom reserves differ.
		center.y -= ((top_px - bottom_px) * 0.5) / z_y
	if z > 0.0:
		# Positive X bias nudges the visible board to the right (camera moves left).
		center.x -= cam_fit_bias_x_px / z
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

func _collect_fit_node_positions_world() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if state != null and state.hives != null:
		for hive_any in state.hives:
			if hive_any is HiveData:
				var hive: HiveData = hive_any as HiveData
				out.append(_cell_center(hive.grid_pos))
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

func _apply_canon_camera_fit(tag: String) -> void:
	_fit_camera_to_viewport(tag)

func _fit_camera_to_viewport(tag: String = "fitcam") -> void:
	var cam: Camera2D = camera if camera != null else $Camera2D
	if cam == null:
		return
	var arena_rect: Rect2 = _arena_rect()
	var arena_size: Vector2 = arena_rect.size
	var grid_w_local: int = grid_w
	var grid_h_local: int = grid_h
	var cell_px: float = CELL_SIZE
	if grid_spec != null:
		grid_w_local = grid_spec.grid_w
		grid_h_local = grid_spec.grid_h
		cell_px = grid_spec.cell_size
	var world_px: Vector2 = Vector2(float(grid_w_local) * cell_px, float(grid_h_local) * cell_px)
	var map_bounds: Rect2 = _map_world_bounds()
	var root_bounds_local: Rect2 = _compute_map_root_bounds()
	var root_bounds: Rect2 = root_bounds_local
	if map_root != null:
		root_bounds.position += map_root.position
	var vp: Viewport = cam.get_viewport()
	if vp == null:
		return
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
	if world_container != null:
		var container_size: Vector2 = world_container.size
		if container_size.x > 0.0 and container_size.y > 0.0:
			visible_vp_size = container_size
	if arena_size.x <= 0.0 or arena_size.y <= 0.0:
		return
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	if visible_vp_size.x <= 0.0 or visible_vp_size.y <= 0.0:
		return
	var ui_insets: Dictionary = _ui_vertical_insets_px()
	var top_ui_inset_px: float = float(ui_insets.get("top", 0.0))
	var bottom_ui_inset_px: float = float(ui_insets.get("bottom", 0.0))
	var safe_cam_vp_size: Vector2 = visible_vp_size - Vector2(0.0, top_ui_inset_px + bottom_ui_inset_px)
	safe_cam_vp_size.x = maxf(1.0, safe_cam_vp_size.x)
	safe_cam_vp_size.y = maxf(1.0, safe_cam_vp_size.y)
	var fit_top_px: float = top_ui_inset_px
	var fit_bottom_px: float = bottom_ui_inset_px
	if cam_fit_reserved_top_px > 0.0:
		fit_top_px = cam_fit_reserved_top_px
	if cam_fit_reserved_bottom_px > 0.0:
		fit_bottom_px = cam_fit_reserved_bottom_px
	if cam_fit_mode == FIT_HEIGHT:
		var bounds_for_height: Rect2 = map_bounds
		if bounds_for_height.size.x <= 1.0 or bounds_for_height.size.y <= 1.0:
			bounds_for_height = arena_rect
		if use_node_bounds_camfit:
			var node_positions_h: Array[Vector2] = _collect_fit_node_positions_world()
			var node_bounds: Rect2 = _bounds_from_positions_world(node_positions_h)
			if node_bounds.size.x > 1.0 and node_bounds.size.y > 1.0:
				bounds_for_height = node_bounds
		var hfit: Dictionary = cam_fit_height_to_bounds(
			cam,
			bounds_for_height,
			fit_top_px,
			fit_bottom_px,
			maxf(0.0, cam_fit_pad_px) + maxf(0.0, cam_fit_height_world_pad_px)
		)
		if bool(hfit.get("ok", false)):
			var z_h: float = float(hfit.get("z", 1.0))
			var zoom_target_h: Vector2 = hfit.get("zoom", Vector2.ONE) as Vector2
			SFLog.throttle("camfit_applied", 1.0, "CAMFIT applied", SFLog.Level.TRACE)
			call_deferred("_sf_camfit_late_probe", cam, zoom_target_h)
			SFLog.info("CAMFIT", {
				"tag": tag,
				"cam_path": str(cam.get_path()),
				"cam_vp_size": cam_vp_size,
				"visible_vp_size": visible_vp_size,
				"safe_cam_vp_size": safe_cam_vp_size,
				"top_ui_inset_px": top_ui_inset_px,
				"bottom_ui_inset_px": bottom_ui_inset_px,
				"fit_top_px": fit_top_px,
				"fit_bottom_px": fit_bottom_px,
				"root_vp_size": root_vp_size,
				"arena_size": arena_size,
				"mode": "fit_height_bounds",
				"bounds_size": (hfit.get("bounds", Rect2()) as Rect2).size,
				"usable_h": float(hfit.get("usable_h", 0.0)),
				"z": z_h,
				"cam_zoom_now": cam.zoom
			})
			return
	var pad: float = maxf(0.0, cam_fit_pad_px)
	var vp_fit: Vector2 = Vector2(
		maxf(1.0, safe_cam_vp_size.x - (pad * 2.0)),
		maxf(1.0, safe_cam_vp_size.y - (pad * 2.0))
	)
	var fit_scalar: float = _compute_fit_zoom_for_mode(safe_cam_vp_size, cam_fit_margin, cam_fit_mode)
	var zoom_scalar: float = fit_scalar
	var fit_strategy: String = "grid"
	var z_min: float = 0.00001
	var z_clamped: bool = false
	var center: Vector2 = Vector2.ZERO
	if grid_spec != null:
		center = grid_spec.origin + (world_px * 0.5)
	else:
		center = arena_rect.get_center()
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
	if zoom_scalar > 0.0:
		# Positive X bias nudges the visible board to the right (camera moves left).
		center.x -= cam_fit_bias_x_px / zoom_scalar
	cam.make_current()
	cam.global_position = center
	cam.zoom = zoom_target
	if abs(cam.zoom.x - zoom_target.x) > 0.0001:
		push_error("CAMFIT: zoom not applied")
	cam.force_update_scroll()
	SFLog.throttle("camfit_applied", 1.0, "CAMFIT applied", SFLog.Level.TRACE)
	if TRACE_ARENA_PRINTS:
		print("CAMFIT_CAM_ID:", " path=", cam.get_path(), " rid=", cam.get_instance_id(), " current=", cam.is_current())
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
		"cam_path": str(cam.get_path()),
		"cam_vp_size": cam_vp_size,
		"visible_vp_size": visible_vp_size,
		"safe_cam_vp_size": safe_cam_vp_size,
		"top_ui_inset_px": top_ui_inset_px,
		"bottom_ui_inset_px": bottom_ui_inset_px,
		"root_vp_size": root_vp_size,
		"arena_size": arena_size,
		"mode": fit_strategy,
		"nodes_mode": str(node_fit_info.get("mode", "")),
		"nodes_bounds_size": node_fit_info.get("bounds_size", Vector2.ZERO),
		"nodes_usable_vp_size": node_fit_info.get("usable", Vector2.ZERO),
		"z": zoom_scalar,
		"cam_zoom_now": cam.zoom
	})

func _sf_camfit_late_probe(cam: Camera2D, expected: Vector2) -> void:
	if cam == null:
		return
	var changed: bool = cam.zoom != expected
	if TRACE_ARENA_PRINTS:
		print("CAMFIT_LATE: expected_zoom=", expected, " actual_zoom=", cam.zoom, " changed=", changed)
	if changed:
		push_warning("CAMFIT_LATE: zoom changed cam=%s" % str(cam.get_path()))

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
	var cell_px: float = float(_cell_px())
	if state != null:
		for hive in state.hives:
			var h: HiveData = hive
			var radius_px: float = float(h.radius_px)
			if radius_px <= 0.0:
				radius_px = MapSchema.hive_radius_px_for_kind(String(h.kind), cell_px)
			var pos: Vector2 = Vector2(
				float(h.grid_pos.x) * cell_px + cell_px * 0.5,
				float(h.grid_pos.y) * cell_px + cell_px * 0.5
			)
			var hd: Dictionary = {
				"id": int(h.id),
				"grid_pos": Vector2i(h.grid_pos),
				"x": int(h.grid_pos.x),
				"y": int(h.grid_pos.y),
				"pos": pos,
				"radius_px": radius_px,
				"owner_id": int(h.owner_id),
				"pwr": int(h.power),
				"kind": String(h.kind)
			}
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
		out_towers.append({
			"id": tower_id,
			"grid_pos": gp,
			"pos_px": pos_px,
			"owner_id": int(td.get("owner_id", 0)),
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
		out_barracks.append({
			"id": barracks_id,
			"grid_pos": gp_b,
			"world_pos": pos_px,
			"pos_px": pos_px,
			"owner_id": int(bd.get("owner_id", 0)),
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
			out[int(hive.id)] = cell_center(hive.grid_pos)
	return out

func _grid_coord_to_world(coord: Vector2) -> Vector2:
	if grid_spec != null:
		var cs: float = float(grid_spec.cell_size)
		return grid_spec.origin + (coord + Vector2(0.5, 0.5)) * cs
	var cell_px: float = _cell_px()
	return (coord + Vector2(0.5, 0.5)) * cell_px + map_offset

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
			"wall_renderer_path": str(wall_renderer.get_path()),
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
		"wall_renderer_path": str(wall_renderer.get_path()),
		"wall_renderer_pos": wall_renderer.position,
		"wall_renderer_visible": wall_renderer.visible,
		"wall_renderer_z": wall_renderer.z_index,
		"map_root_pos": map_root.position if map_root != null else null
	}, "", 5000)
	wall_renderer.set_wall_pairs(pairs, hive_pos_by_id)

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
	if not buffs_enabled:
		return
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
		return _build_loadout_entries(profile_ids)
	var candidate_pool: Array[String] = _supported_runtime_classic_buff_ids(profile_ids)
	if candidate_pool.size() < BuffState.LOADOUT_SIZE:
		candidate_pool = _supported_runtime_classic_buff_ids([])
	var seeded_ids: Array[String] = _pick_seeded_unique_ids(candidate_pool, resolved_pid, BuffState.LOADOUT_SIZE)
	if seeded_ids.size() < BuffState.LOADOUT_SIZE:
		seeded_ids = profile_ids
	return _build_loadout_entries(seeded_ids)

func _resolve_profile_loadout_ids() -> Array[String]:
	var ids: Array[String] = []
	if ProfileManager != null and ProfileManager.has_method("get_buff_loadout_ids"):
		var profile_ids: Variant = ProfileManager.call("get_buff_loadout_ids")
		if typeof(profile_ids) == TYPE_ARRAY:
			for buff_id_v in profile_ids as Array:
				var buff_id: String = str(buff_id_v).strip_edges()
				if buff_id == "":
					continue
				if BuffCatalog.get_buff(buff_id).is_empty():
					continue
				ids.append(buff_id)
	if ids.size() != 3:
		ids = debug_buff_loadout
	if ids.size() != 3:
		ids = [
			"buff_swarm_speed_classic",
			"buff_hive_faster_production_classic",
			"buff_tower_fire_rate_classic"
		]
	return ids

func _build_loadout_entries(ids: Array[String]) -> Array:
	var out: Array = []
	var count: int = mini(ids.size(), BuffState.LOADOUT_SIZE)
	for i in range(count):
		out.append({"id": ids[i], "tier": "classic"})
	return out

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
	if not buffs_enabled:
		return
	if buff_states.is_empty():
		_init_buff_states()
	for buff_state in buff_states.values():
		buff_state.reset_for_match()
	_reset_buff_runtime()

func _update_buff_states() -> void:
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
		"buffs_enabled": bool(buffs_enabled),
		"active_player_id": int(active_player_id),
		"overtime_active": bool(overtime_active),
		"sim_time_ms": now_ms,
		"players": {}
	}
	if not buffs_enabled:
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
		var remaining_ms: int = 0
		if active:
			remaining_ms = max(0, ends_ms - now_ms)
		slots_out.append({
			"index": i,
			"id": buff_id,
			"name": str(buff_def.get("name", buff_id)),
			"tier": tier,
			"category": str(buff_def.get("category", "unknown")),
			"locked": i >= int(buff_state.slots_active),
			"active": active,
			"consumed": consumed,
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
	var result: Dictionary = {
		"ok": false,
		"pid": pid,
		"slot_index": slot_index,
		"reason": "",
		"target": _buff_target_context_from_world(world_pos)
	}
	if not buffs_enabled:
		result["reason"] = "buffs_disabled"
		return result
	if buff_states.is_empty():
		_init_buff_states()
	var buff_state: BuffState = buff_states.get(pid)
	if buff_state == null:
		result["reason"] = "missing_player_state"
		return result
	if slot_index < 0 or slot_index >= buff_state.slots.size():
		result["reason"] = "slot_out_of_range"
		return result
	if not buff_state.can_activate_slot(slot_index):
		result["reason"] = "slot_blocked"
		return result
	_try_activate_buff_slot(pid, slot_index)
	var slot: Dictionary = buff_state.slots[slot_index]
	result["ok"] = bool(slot.get("active", false))
	if not bool(result["ok"]):
		result["reason"] = "activation_failed"
		return result
	result["buff_id"] = str(slot.get("id", ""))
	result["ends_ms"] = int(slot.get("ends_ms", 0))
	_record_match_telemetry_buff_activation(
		int(result.get("pid", pid)),
		str(result.get("buff_id", "")),
		result.get("target", {}),
		int(_authoritative_sim_time_us() / 1000)
	)
	return result

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
	if not buffs_enabled:
		return
	if buff_states.is_empty():
		_init_buff_states()
	var buff_state: BuffState = buff_states.get(pid)
	if buff_state == null:
		return
	var now_ms: int = int(_authoritative_sim_time_us() / 1000)
	if not buff_state.activate_slot(slot_index, now_ms):
		SFLog.info("BUFF_ACTIVATE_BLOCKED", {
			"pid": pid,
			"slot_index": slot_index,
			"slots_active": int(buff_state.slots_active),
			"is_active": bool(buff_state.is_slot_active(slot_index)),
			"is_consumed": bool(buff_state.is_slot_consumed(slot_index))
		})
		return
	var slot: Dictionary = buff_state.slots[slot_index]
	SFLog.info("BUFF_ACTIVATED", {
		"pid": pid,
		"slot_index": slot_index,
		"buff_id": str(slot.get("id", "")),
		"ends_ms": int(slot.get("ends_ms", 0))
	})
	SFLog.warn("BUFF_FIRED", {
		"pid": pid,
		"slot_index": slot_index,
		"buff_id": str(slot.get("id", "")),
		"ends_ms": int(slot.get("ends_ms", 0))
	})
	_sync_buff_effects(now_ms)
	_update_buff_ui()
	mark_render_dirty("buff_activate")

func _reset_sim_state() -> void:
	units.clear()
	swarm_packets.clear()
	debris.clear()
	unit_id_counter = 1
	swarm_id_counter = 1
	debris_id_counter = 1
	tick_accum = 0.0
	events.clear()
	sim_time_us = 0
	winner_id = -1
	end_reason = ""
	game_over = false
	_match_end_handled = false
	_match_record_committed = false
	_post_match_action_taken = false
	_post_match_render_frozen = false
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
	_prematch_ui_state_logged = false
	_match_started = false
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
	return _input_bridge_utils.dev_mouse_pid(event)

func _mouse_world_pos() -> Vector2:
	return _screen_to_world(get_viewport().get_mouse_position())

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp: Viewport = get_viewport()
	return _input_bridge_utils.screen_to_world(vp, get_global_mouse_position(), screen_pos)

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if input_system == null or api == null:
		return
	if _controls_hint_controller != null and _controls_hint_controller.consume_dismiss_input(event, get_viewport()):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			var wp: Vector2 = _screen_to_world(mb.position)
			var lp: Vector2 = map_root.to_local(wp)
			_send_pointer_event(mb.pressed, mb.button_index, lp, false, wp, mb.position)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var wp: Vector2 = _screen_to_world(mm.position)
		var lp: Vector2 = map_root.to_local(wp)
		_send_pointer_event(false, 0, lp, true, wp, mm.position)
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var wp: Vector2 = _screen_to_world(st.position)
		var lp: Vector2 = map_root.to_local(wp)
		_send_pointer_event(st.pressed, MOUSE_BUTTON_LEFT, lp, false, wp, st.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		var wp: Vector2 = _screen_to_world(sd.position)
		var lp: Vector2 = map_root.to_local(wp)
		_send_pointer_event(false, 0, lp, true, wp, sd.position)
		return
	input_system.handle_input(event, api)

func _pointer_local_from_screen(screen_pos: Vector2) -> Vector2:
	return _input_bridge_utils.pointer_local_from_screen(
		get_viewport(),
		map_root,
		get_global_mouse_position(),
		screen_pos
	)

func _send_pointer_event(pressed: bool, button_index: int, local_pos: Vector2, is_motion: bool = false, world_pos: Vector2 = Vector2.ZERO, screen_pos: Vector2 = Vector2.ZERO) -> void:
	var hive_id: int = api.hive_id_at_point(local_pos)
	var lane_hit: LaneData = api.pick_lane(local_pos)
	var lane_id: int = lane_hit.id if lane_hit != null else -1
	var ev_type: String = "motion" if is_motion else ("press" if pressed else "release")
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
		"hive_id": hive_id,
		"lane_id": lane_id
	}
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
		var is_primary_click := (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT)
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
	return float(radius_v) if radius_v != null else cell * 0.28

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
		var gx: int = int(hd.get("x", 0))
		var gy: int = int(hd.get("y", 0))
		if hd.has("grid_pos") and typeof(hd["grid_pos"]) == TYPE_ARRAY:
			var gp: Array = hd["grid_pos"] as Array
			if gp.size() >= 2:
				gx = int(gp[0])
				gy = int(gp[1])
		var hp: Vector2 = _cell_center(Vector2i(gx, gy))
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
	if found_index == -1 and out_count >= MAX_OUT_LANES:
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
				"map_root": str(map_root.get_path()) if map_root != null else "<null>",
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
				"map_root": str(map_root.get_path()),
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
		cell.x * cell_px + cell_px * 0.5,
		cell.y * cell_px + cell_px * 0.5
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
		1:
			return Color(0.95, 0.85, 0.2)
		2:
			return Color(0.9, 0.2, 0.2)
		3:
			return Color8(34, 85, 34)
		4:
			return Color(0.2, 0.5, 0.95)
		_:
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
			if not spawn_ids.is_empty() and not spawn_ids.has(a.id):
				stats["skip_other"] = int(stats["skip_other"]) + 1
			else:
				var spawned_a := _spawn_lane_units(lane, a, b, dt_ms, true, stats)
				stats["did_spawn"] = int(stats["did_spawn"]) + spawned_a
		if lane.send_b:
			if not spawn_ids.is_empty() and not spawn_ids.has(b.id):
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
	if from_hive.shock_ms > 0.0:
		if from_is_a:
			lane.spawn_accum_a_ms = 0.0
		else:
			lane.spawn_accum_b_ms = 0.0
		_maybe_log_spawnfail(from_hive, "shock")
		stats["skip_other"] = int(stats["skip_other"]) + 1
		return 0
	var lane_len_dbg: float = _lane_length_px(from_hive, to_hive)
	var stream_dbg: float = lane.a_stream_len if from_is_a else lane.b_stream_len
	if not _lane_ready_for_send(lane, from_hive.id):
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
	while accum >= interval_ms and spawned < MAX_SPAWNS_PER_TICK:
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
			swarm_packets.remove_at(i)
			continue
		var from_center: Vector2 = _cell_center(from_hive.grid_pos)
		var to_center: Vector2 = _cell_center(to_hive.grid_pos)
		var from_pos: Vector2 = _edge_point_toward(from_center, to_center)
		var to_pos: Vector2 = _edge_point_toward(to_center, from_center)

		var lane_len: float = from_pos.distance_to(to_pos)
		if lane_len <= 0.0:
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
			"timer_label_path": str(timer_label.get_path()) if timer_label != null else "<null>"
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
		timer_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
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
			"path": str(timer_label.get_path()),
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
		"path": str(node.get_path()),
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
			"path": str(timer_label.get_path()) if timer_label != null else "<null>",
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

func _dump_timer_parent_chain(node: Node) -> Array:
	var out: Array = []
	var n: Node = node
	while n != null:
		if n is CanvasItem:
			var ci := n as CanvasItem
			out.append({
				"path": str(ci.get_path()),
				"visible": ci.visible,
				"modulate_a": ci.modulate.a,
				"self_modulate_a": ci.self_modulate.a
			})
		else:
			out.append({"path": str(n.get_path()), "type": n.get_class()})
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
	var prev_owner: int = hive.owner_id
	var friendly_arrival: bool = _are_allied_owners(prev_owner, unit_owner)
	var pass_owner: int = unit_owner if unit_owner > 0 else prev_owner
	if friendly_arrival and prev_owner > 0:
		pass_owner = prev_owner
	if friendly_arrival:
		if hive.power < 50:
			hive.power += 1
		elif hive.shock_ms <= 0.0:
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
	var bonus: float = 0.0
	if power >= 10:
		bonus += BONUS_10_MS
	if power >= 25:
		bonus += BONUS_25_MS
	var value: float = BASE_MS - ((power - 1) * PER_POWER_MS) - bonus
	return maxf(200.0, value)

func _spawn_interval_ms_for_power(power: int) -> int:
	var p := maxi(1, power)
	return maxi(50, 1000 - (p - 1) * 2)

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
	if input_system == null or api == null:
		return
	input_system.handle_press(local_pos, dev_pid, api, button_index)

func _handle_press_impl(local_pos: Vector2, dev_pid: int = -1, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	if input_system == null or api == null:
		return
	input_system.handle_press(local_pos, dev_pid, api, button_index)

func _handle_release(local_pos: Vector2, dev_pid: int = -1) -> void:
	if input_system == null or api == null:
		return
	input_system.handle_release(local_pos, dev_pid, api)

func _handle_drag(local_pos: Vector2) -> void:
	if input_system == null or api == null:
		return
	input_system.handle_drag(local_pos, api)

func _handle_tap(hive_id: int, dev_pid: int = -1) -> void:
	SFLog.trace("HIVE_TAPPED", {"hive_id": hive_id})
	if input_system == null or api == null:
		return
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
		if not skip_budget and state != null:
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
		if state != null:
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
	var a: HiveData = _find_hive_by_id(a_id)
	var b: HiveData = _find_hive_by_id(b_id)
	if a == null or b == null:
		los_cache[key] = false
		return false
	var a_pos: Vector2 = _cell_center(a.grid_pos)
	var b_pos: Vector2 = _cell_center(b.grid_pos)
	var min_x: float = min(a_pos.x, b_pos.x) - BLOCK_RADIUS_PX
	var max_x: float = max(a_pos.x, b_pos.x) + BLOCK_RADIUS_PX
	var min_y: float = min(a_pos.y, b_pos.y) - BLOCK_RADIUS_PX
	var max_y: float = max(a_pos.y, b_pos.y) + BLOCK_RADIUS_PX
	for hive in state.hives:
		if hive.id == a_id or hive.id == b_id:
			continue
		var center: Vector2 = _cell_center(hive.grid_pos)
		if center.x < min_x or center.x > max_x or center.y < min_y or center.y > max_y:
			continue
		var dist: float = _distance_point_to_segment(center, a_pos, b_pos)
		if dist <= BLOCK_RADIUS_PX:
			if LOS_DEBUG:
				dbg("SF: LOS blocked %d->%d by hive %d" % [a_id, b_id, hive.id])
			los_cache[key] = false
			return false
	los_cache[key] = true
	return true

func _hive_id_at_point(local_pos: Vector2) -> int:
	if state == null:
		return -1
	if state.hives == null:
		return -1
	var best_id := -1
	var best_dist := INF
	for hive in state.hives:
		var center := _cell_center(hive.grid_pos)
		var dist := center.distance_squared_to(local_pos)
		var hive_radius: float = float(hive.radius_px)
		if hive_radius <= 0.0:
			hive_radius = HIVE_RADIUS_PX
		var hit_radius: float = maxf(HIVE_HIT_RADIUS_PX, hive_radius + HIVE_PICK_PADDING_PX)
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
