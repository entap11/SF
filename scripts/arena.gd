@tool
# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
extends Node2D

const ARENA_MARKER = "ARENA_MARKER_2026-01-14_A"

const SFLog = preload("res://scripts/util/sf_log.gd")
const MapSchema = preload("res://scripts/maps/map_schema.gd")
const GridSpec = preload("res://scripts/maps/grid_spec.gd")
const TeamPalette = preload("res://scripts/util/team_palette.gd")

const GRID_W = MapSchema.CANON_GRID_W
const GRID_H = MapSchema.CANON_GRID_H
const CELL_SIZE = 64
const GRID_DEBUG = false
const RENDER_DEBUG = false
const UNIT_SPEED_PX = 160.0
const LANE_ESTABLISH_MS = 2400.0
const UNIT_TRAVEL_MS = 4800.0
const SPAWN_BASE_MS = 1200.0
const SPAWN_PER_POWER_MS = 2.0
const SPAWN_MIN_MS = 250.0
const FIRST_UNIT_OFFSET_MS = 2.0
const SPIKE_PX = 48.0
const LANE_EDGE_T = 0.18
const DEBUG_COLLISION_ONLY = true
const DASH_GAP_PX = 6.0
const BASE_MS = 1000.0
const PER_POWER_MS = 2.0
const START_POWER = 10
const BONUS_10_MS = 2.0
const BONUS_25_MS = 2.0
const IDLE_GROWTH_MS = 1500.0
const CAPTURE_SHOCK_MS = 3000.0
const SWARM_SHOCK_MS = 3000.0
const DRAG_DEADZONE_PX = 8.0
const MAX_OUT_LANES = 2
const DOT_RADIUS = 3.0
const HIVE_RADIUS_PX = CELL_SIZE * 0.56
const HIVE_HIT_RADIUS_PX = 64.0
const LANE_HIT_DIST_PX = 24.0
const TICK_DT = 0.1
const TICK_MS = 100.0
const TICK_DEBUG = false
const MAX_FRAME_DT = 0.25
const MAX_STEPS_PER_FRAME = 8
const MAX_ACCUM_DT = 1.0
const MAX_SPAWNS_PER_TICK = 5
const DEBRIS_LIFE = 4.0
const DEBRIS_DRIFT = 30.0
const DEBRIS_DAMP = 0.90
const DEBRIS_MAX_PER_LANE = 8
const DEBRIS_GLOBAL_CAP = 800
const DEV_STATE_CHECKS = true
const PRESSURE_DECAY_PER_SEC = 1.0
const BLOCK_RADIUS_PX = CELL_SIZE * 0.25
const LOS_DEBUG = false
const TIE_WINDOW_US = 0
const TIE_BUCKET_US = 100
const TIE_CACHE_EXPIRE_US = 2_000_000
const TIE_SFX_COOLDOWN_US = 500_000
const COIN_SFX_SEC = 0.08
const COIN_SFX_FREQ = 880.0
const CONTEST_WINDOW_US = 2_000_000
const CONTEST_LOG_INTERVAL_US = 1_000_000
const SWARM_MERGE_WINDOW_US = 200_000
const BARRACKS_MIN_REQ = 3
const BARRACKS_MAX_REQ = 6
const STRUCTURE_CANDIDATE_MAX = 12
const MATCH_LENGTH_MS = 300000.0
const OVERTIME_START_MS = 60000.0
const BUFF_MIN_MULT = 0.1
const BUFF_LANE_SLOW_PCT_DEFAULT = 0.25

var state: GameState
var sel: SelectionState
var api: ArenaAPI
var input_system: InputSystem
var debug_system: DebugSystem
var audio_system: AudioSystem
var lane_system: LaneSystem
var sim_runner: SimRunner
var events: Array[Dictionary] = []
var grid_w: int = GRID_W
var grid_h: int = GRID_H
var grid_spec: GridSpec = null
var render_version: int = 0
var _render_dirty: bool = true
var _render_model: Dictionary = {}
var model: Dictionary = {}
var _tick_render_dirty = false
var _drag_from_id: String = ""
var _drag_from_wp: Vector2 = Vector2.ZERO
var _drag_active: bool = false
var active_orders_by_attacker: Dictionary = {}
@onready var map_root: Node2D = $MapRoot
@onready var floor_renderer: FloorRenderer = $MapRoot/FloorRenderer
@onready var lane_renderer = $MapRoot/LaneRenderer
@onready var hive_renderer: HiveRenderer = $MapRoot/HiveRenderer
@onready var unit_renderer: Node2D = $MapRoot/UnitRenderer
@onready var control_bar: ControlBar = get_node_or_null("../UI/ControlBar") as ControlBar
@onready var timer_label: Label = get_node_or_null("../UI/TimerLabel") as Label
@onready var buffs_label: Label = get_node_or_null("../UI/BuffsLabel") as Label
@onready var outcome_overlay: OutcomeOverlay = get_node_or_null("../UI/OutcomeOverlay") as OutcomeOverlay
@onready var selection_hud: SelectionHud = get_node_or_null("../UI/SelectionHud") as SelectionHud
@onready var tie_toast: Label = get_node_or_null("../UI/TieToast") as Label
@onready var coin_player: AudioStreamPlayer = $CoinFlipPlayer
@onready var camera: Camera2D = $Camera2D
var _prematch_countdown_layer: CanvasLayer = null
var _prematch_countdown_label: Label = null
var _prematch_countdown_timer: Timer = null
var _prematch_countdown_active = false
var _prematch_countdown_seconds = 0
var _prematch_countdown_remaining = 0
var _prematch_countdown_hide_id = 0
var _prematch_request_pending = false
var _prematch_request_seconds = 0
var _prematch_request_reason = ""
var _ops_state_signals_connected = false
const FIT_MARGIN_X = 0.96
const FIT_MARGIN_Y = 0.90
const FIT_DEBUG = true
const FIT_WIDTH = 0
const FIT_HEIGHT = 1
var _autostart_shadow = false
var _sim_running_shadow = false
var _last_render_model_log_ms: int = 0
@export var autostart: bool = false:
	set(value):
		_set_autostart(value)
	get:
		return _get_autostart()
@export var buffs_enabled = true
@export var match_length_ms: float = MATCH_LENGTH_MS
@export var overtime_start_ms: float = OVERTIME_START_MS
@export var draw_arena_rect_debug = false
@export var use_dev_safe_centering = false
@export var FITCAM_POLICY = FIT_WIDTH
@export var debug_render_model_log = false
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
var tick_accum = 0.0
var unit_id_counter = 1
var units: Array = []
var debris_id_counter = 1
var debris: Array = []
var debris_enabled = true
var swarm_id_counter = 1
var swarm_packets: Array = []
var active_player_id = 1
var match_ms_remaining: float = MATCH_LENGTH_MS
var hurry_mode = false
var audio_hurry_pitch = 1.0
var winner_id = -1
var end_reason = ""
var game_over = false
var towers: Array = []
var barracks: Array = []
var current_map_path = ""
var current_map_name = ""
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
var overtime_active = false
var barracks_select_id: int = -1
var barracks_select_pid: int = -1
var barracks_select_targets: Array = []
var barracks_select_changed = false
var map_offset = Vector2.ZERO
var hive_lane_order: Dictionary = {}
var hive_power_prev: Dictionary = {}
var buff_states: Dictionary = {}
var buff_active_slots: Dictionary = {}
var buff_instances: Dictionary = {}
var buff_mods: Dictionary = {}
var current_map_data: Dictionary = {}
var _map_build_version: int = 0
var _map_built_version: int = -1
var _map_bounds_size: Vector2 = Vector2.ZERO
var _fit_serial = 0
var _fit_applied_serial = -1
var _dev_tick_log_ms: int = 0
var _dev_sim_dbg_us: int = 0
var _last_spawnfail_ms: int = 0
var _last_scale: Vector2 = Vector2.ZERO

func _ready() -> void:
	SFLog.info("ARENA_SCRIPT", {"path": get_script().resource_path})
	SFLog.info("ARENA_READY", {"process": is_processing()})
	SFLog.debug_log(1, ARENA_MARKER)
	SFLog.debug_log(1, "ARENA_PATH=" + str(get_script().resource_path))
	add_to_group("Arena")
	self.scale = Vector2.ONE
	_last_scale = scale
	var dmr = get_node_or_null("/root/DevMapRunner")
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
	$Camera2D.make_current()
	assert(GRID_W == MapSchema.CANON_GRID_W)
	assert(GRID_H == MapSchema.CANON_GRID_H)
	SFLog.trace("CANON GRID", {
		"grid_w": GRID_W,
		"grid_h": GRID_H,
		"world_px": Vector2(GRID_W * CELL_SIZE, GRID_H * CELL_SIZE)
	})
	SFLog.trace("CURRENT CAMERA", {"camera": get_viewport().get_camera_2d()})
	await get_tree().process_frame
	_apply_canon_camera_fit("ready")
	var cam = $Camera2D
	var vcam = get_viewport().get_camera_2d()
	SFLog.trace("ARENA CAM", {"arena_cam": cam, "viewport_cam": vcam})
	assert(vcam == cam)
	state = OpsState.get_state()
	_connect_ops_state_signals()
	sel = SelectionState.new()
	_init_systems()
	los_cache.clear()
	_init_buff_states()
	_reset_match_stats()
	_reset_buff_states()
	if state != null:
		lane_renderer.setup(state, sel, self)
		SFLog.debug_log(2, "HIVE: renderer_ref=" + str(hive_renderer))
		hive_renderer.setup(state, sel, self)
		_sync_lane_system_blockers()
		_init_towers()
		_init_barracks()
	_apply_autostart()
	_configure_grid_spec(grid_w, grid_h)
	_map_bounds_size = _arena_rect().size
	var arena_scale: Vector2 = global_transform.get_scale()
	dbg("ARENA: global_scale=%s" % [arena_scale])
	var viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
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

func _enter_tree() -> void:
	_connect_ops_state_signals()

func _connect_ops_state_signals() -> void:
	if _ops_state_signals_connected:
		return
	_ops_state_signals_connected = true
	if not OpsState.state_changed.is_connected(_on_ops_state_changed):
		OpsState.state_changed.connect(_on_ops_state_changed)
	if not OpsState.ops_state_changed.is_connected(_on_ops_state_changed_iid):
		OpsState.ops_state_changed.connect(_on_ops_state_changed_iid)
	SFLog.info("ARENA_CONNECTED_STATE_SIGNALS", {})
	var current_state = OpsState.get_state()
	if current_state != null:
		_on_ops_state_changed(current_state)

func _init_systems() -> void:
	api = ArenaAPI.new(self)
	input_system = _create_system("res://scripts/systems/input_system.gd", "input") as InputSystem
	if input_system != null:
		input_system.setup(sel)
		# If state already exists by the time input is created, bind it now.
		if state != null and input_system.has_method("bind_state"):
			input_system.call("bind_state", state)
	_ensure_sim_runner()
	if sim_runner != null:
		lane_system = sim_runner.get_lane_system()
	if lane_system != null:
		if not lane_system.lane_created.is_connected(_on_lane_system_changed):
			lane_system.lane_created.connect(_on_lane_system_changed)
		if not lane_system.lane_updated.is_connected(_on_lane_system_changed):
			lane_system.lane_updated.connect(_on_lane_system_changed)
		if not lane_system.lane_removed.is_connected(_on_lane_system_removed):
			lane_system.lane_removed.connect(_on_lane_system_removed)
	if input_system != null:
		input_system.set_lane_system(lane_system)
	debug_system = _create_system("res://scripts/systems/debug_system.gd", "debug") as DebugSystem
	audio_system = _create_system("res://scripts/systems/audio_system.gd", "audio") as AudioSystem
	if audio_system != null:
		audio_system.setup(coin_player)

func _ensure_sim_runner() -> void:
	if sim_runner != null and is_instance_valid(sim_runner):
		return
	var existing = get_node_or_null("SimRunner")
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
	if not sim_runner.sim_bound.is_connected(_on_sim_bound):
		sim_runner.sim_bound.connect(_on_sim_bound)

func _on_sim_ticked() -> void:
	mark_render_dirty("sim_tick")
	_push_render_model()

func _on_sim_bound(_iid: int) -> void:
	if _prematch_request_pending:
		_request_prematch_if_possible()

func _on_lane_system_changed(lane: Dictionary) -> void:
	mark_render_dirty("lane_system")

	if lane_renderer != null:
		var lane_id: int = int(lane.get("lane_id", -1))
		if lane_id != -1:
			lane_renderer.mark_lane_changed(lane_id)
		else:
			lane_renderer.queue_redraw()

	_push_render_model()


func _on_lane_system_removed(lane_id: int) -> void:
	mark_render_dirty("lane_system_removed")

	if lane_renderer != null:
		lane_renderer.mark_lane_changed(lane_id)

	_push_render_model()


func _sync_lane_system_blockers() -> void:
	if lane_system == null:
		return
	var hive_list: Array = []
	if hive_renderer != null:
		var nodes = hive_renderer.get_hive_nodes_by_id()
		for key in nodes.keys():
			var node = nodes.get(key) as Node2D
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
	return OpsState.require_state()

func _on_ops_state_changed(new_state: GameState) -> void:
	state = new_state
	if state == null:
		return
	# Ensure input always points at the current authoritative GameState.
	if input_system != null and input_system.has_method("bind_state"):
		input_system.call("bind_state", state)
	_ensure_sim_runner()
	if sim_runner != null:
		sim_runner.bind_state(state)
		SFLog.info("ARENA_ON_STATE_CHANGED_BIND", {"iid": int(sim_runner.bound_iid)})
	if lane_system != null and lane_system.state != state:
		lane_system.bind_state(state)
	if lane_renderer != null:
		lane_renderer.setup(state, sel, self)
	if hive_renderer != null:
		hive_renderer.setup(state, sel, self)
	_sync_lane_system_blockers()
	mark_render_dirty("ops_state_changed")

func _on_ops_state_changed_iid(_payload = {}) -> void:
	# Fallback: some boot paths fire ops_state_changed (iid) before state_changed (GameState).
	# Bind sim_runner to the authoritative state if not already bound.
	_ensure_sim_runner()
	if sim_runner != null and not sim_runner.has_bound_state():
		var ops_state = OpsState.get_state()
		if ops_state != null:
			sim_runner.bind_state(ops_state)
			SFLog.info("ARENA_BOUND_SIM", {"iid": int(sim_runner.bound_iid)})
			# Bind input here too (iid path can fire before state_changed).
			if input_system != null and input_system.has_method("bind_state"):
				input_system.call("bind_state", ops_state)
		else:
			SFLog.warn("ARENA_BOUND_SIM_NO_STATE", {})
	call_deferred("_start_sim_after_state_change")

func _start_sim_after_state_change() -> void:
	if sim_runner == null:
		SFLog.info("SIM_START_DEFERRED_FAIL", {"reason": "sim_runner_null"})
		return
	SFLog.info("ARENA_START_SIM_AFTER_STATE", {"iid": int(sim_runner.bound_iid)})
	sim_runner.set_running(true, "arena_after_ops_state_changed")

func _create_system(script_path: String, label: String) -> RefCounted:
	var script = load(script_path)
	if script == null:
		push_error("ARENA: failed to load %s system (%s)" % [label, script_path])
		return null
	if script is Script and not script.can_instantiate():
		push_error("ARENA: %s system script cannot instantiate (%s)" % [label, script_path])
		return null
	var instance = script.new()
	if instance == null:
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
	fitcam_once()

func _configure_grid_spec(grid_w_in: int, grid_h_in: int) -> void:
	var cell_px = _cell_px()
	var origin = map_offset
	if grid_spec == null:
		grid_spec = GridSpec.new()
	grid_spec.configure(grid_w_in, grid_h_in, cell_px, origin)
	grid_w = grid_spec.grid_w
	grid_h = grid_spec.grid_h
	if floor_renderer != null:
		floor_renderer.configure(grid_w, grid_h, cell_px)
	# Refit after cell/grid changes so the arena stays centered.
	call_deferred("_apply_canon_camera_fit", "grid_spec")

func _log_map_spec(map_data: Dictionary) -> void:
	if not GRID_DEBUG or grid_spec == null:
		return
	var schema_id = str(map_data.get("_schema", ""))
	SFLog.trace("ARENA: map schema=%s grid=%dx%d rect=%s" % [
		schema_id,
		grid_spec.grid_w,
		grid_spec.grid_h,
		str(grid_spec.board_world_rect)
	])

func load_from_map(map_data: Dictionary) -> void:
	los_cache.clear()
	state.hives.clear()
	state.lanes.clear()
	state.lane_sim_by_key.clear()
	state.units_by_lane.clear()
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
		var hive = HiveData.new(int(hive_data["id"]), grid_pos, owner_id, power, kind, radius_px)
		state.hives.append(hive)
		hive_lane_order[hive.id] = []
		hive_power_prev[hive.id] = hive.power
	var lane_id: int = 1
	for lane_data in map_data.get("lanes", []):
		var a_id: int = int(lane_data["a_id"])
		var b_id: int = int(lane_data["b_id"])
		state.lanes.append(LaneData.new(lane_id, a_id, b_id, 1, false, false))
		lane_id += 1
	state.map_lanes = []
	for lane in state.lanes:
		state.map_lanes.append({
			"lane_id": int(lane.id),
			"a_id": int(lane.a_id),
			"b_id": int(lane.b_id)
		})
	if lane_system != null and lane_system.state != state:
		lane_system.bind_state(state)
	SFLog.info("STATE_IID_AFTER_APPLY", {"iid": int(state.get_instance_id())})
	var structure_sets: Array = []
	var structure_positions: Array = []
	towers = []
	if state != null:
		state.structure_by_node_id.clear()
		state.tower_owner_by_node_id.clear()
	for t in map_data.get("towers", []):
		if state != null:
			var tower_node_id: int = int(t.get("node_id", t.get("id", -1)))
			if tower_node_id != -1:
				state.structure_by_node_id[tower_node_id] = "tower"
				state.tower_owner_by_node_id[tower_node_id] = int(t.get("owner_id", 0))
		var t_pos: Array = t.get("grid_pos", [0, 0])
		var t_grid_pos = Vector2i(int(t_pos[0]), int(t_pos[1]))
		var t_required: Array = t.get("required_hive_ids", [])
		var t_computed: Array = _structure_required_hives_for(
			t_grid_pos,
			t_required,
			structure_sets,
			structure_positions
		)
		structure_sets.append(t_computed)
		if t_computed.size() >= BARRACKS_MIN_REQ:
			structure_positions.append(_structure_center_for_required(t_computed, _cell_center(t_grid_pos)))
		towers.append({
			"id": int(t["id"]),
			"node_id": int(t.get("node_id", t.get("id", -1))),
			"grid_pos": t_grid_pos,
			"required_hive_ids": t_computed,
			"active": false,
			"owner_id": 0,
			"tier": 1,
			"shot_accum_ms": 0.0
		})
	barracks = []
	for b in map_data.get("barracks", []):
		var b_pos: Array = b.get("grid_pos", [0, 0])
		var b_grid_pos = Vector2i(int(b_pos[0]), int(b_pos[1]))
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
			"active": false,
			"owner_id": 0,
			"tier": 1,
			"spawn_accum_ms": 0.0,
			"rr_index": 0,
			"preferred_targets": []
		})
	_center_map_offset(map_data)
	_configure_grid_spec(grid_w, grid_h)
	var cam_zoom = camera.zoom if camera != null else Vector2.ONE
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

func apply_loaded_map(map: Dictionary) -> void:
	if map.is_empty():
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
	hive_lane_order.clear()
	hive_power_prev.clear()
	grid_w = max(1, int(map.get("grid_w", GRID_W)))
	grid_h = max(1, int(map.get("grid_h", GRID_H)))
	current_map_data = map.duplicate(true)
	_configure_grid_spec(grid_w, grid_h)
	_sync_lane_system_blockers()
	mark_render_dirty("apply_loaded_map")
	model = export_render_model()
	_push_render_model()
	SFLog.trace("POST-LOAD: candidates=%d actives=%d" % [
		(state.lane_candidates as Array).size(),
		(state.lanes as Array).size()
	])
	SFLog.trace("SIM: running=%s autostart=%s" % [sim_running, autostart])

func reset_match() -> void:
	if current_map_data.is_empty():
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
		SFLog.debug_log(2, "HIVE: renderer_ref=" + str(hive_renderer))
		hive_renderer.setup(state, sel, self)
	_sync_lane_system_blockers()
	mark_render_dirty("map_built")
	_debug_map_bounds("map_built")
	_debug_camera("map_built")

func fitcam_once() -> void:
	if _map_built_version < 0:
		return
	if _fit_applied_serial == _fit_serial:
		return
	_fit_applied_serial = _fit_serial
	_apply_canon_camera_fit("fitcam_once")

func _fitcam_verify_next_frame() -> void:
	var cam = $Camera2D
	SFLog.trace("FITCAM_VERIFY", {
		"zoom_now": cam.zoom,
		"pos_now": cam.global_position,
		"is_current": (get_viewport().get_camera_2d() == cam)
	})

func _find_overlay_controls() -> Array[Control]:
	var overlays: Array[Control] = []
	var root = get_tree().root
	if root == null:
		return overlays
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is Control):
			continue
		var control = node as Control
		if not control.visible:
			continue
		if control.is_in_group("dev_overlay") or control is DevMapPicker or control.name.find("DevMapLoader") != -1:
			overlays.append(control)
	return overlays

func _compute_safe_rect(viewport_size: Vector2) -> Dictionary:
	var viewport_rect = Rect2(Vector2.ZERO, viewport_size)
	var safe_rect: Rect2 = Rect2(Vector2.ZERO, viewport_size)
	var overlays_info: Array = []
	var viewport_center: Vector2 = viewport_size * 0.5
	var overlays = _find_overlay_controls()
	for control in overlays:
		var rect_pos: Vector2 = control.global_position
		var rect_size: Vector2 = control.size
		var rect = Rect2(rect_pos, rect_size)
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

func _set_sim_running(value: bool) -> void:
	_sim_running_shadow = value
	if sim_runner != null:
		sim_runner.set_running(value)

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

func _ensure_prematch_countdown_ui() -> void:
	if _prematch_countdown_layer != null and is_instance_valid(_prematch_countdown_layer):
		return
	_prematch_countdown_layer = CanvasLayer.new()
	_prematch_countdown_layer.name = "PrematchCountdown"
	_prematch_countdown_layer.layer = 10
	var root = Control.new()
	root.name = "CountdownRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prematch_countdown_label = Label.new()
	_prematch_countdown_label.name = "CountdownLabel"
	_prematch_countdown_label.visible = false
	_prematch_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prematch_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prematch_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prematch_countdown_label.add_theme_font_size_override("font_size", 96)
	_prematch_countdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_prematch_countdown_label)
	_prematch_countdown_layer.add_child(root)
	add_child(_prematch_countdown_layer)
	_prematch_countdown_timer = Timer.new()
	_prematch_countdown_timer.name = "PrematchCountdownTimer"
	_prematch_countdown_timer.one_shot = false
	_prematch_countdown_timer.wait_time = 1.0
	add_child(_prematch_countdown_timer)
	if not _prematch_countdown_timer.timeout.is_connected(_on_prematch_countdown_tick):
		_prematch_countdown_timer.timeout.connect(_on_prematch_countdown_tick)

func _request_prematch_if_possible() -> void:
	if sim_runner == null:
		return
	if not sim_runner.has_bound_state():
		_prematch_request_pending = true
		return
	if _prematch_request_pending:
		sim_runner.request_prematch(_prematch_request_seconds, _prematch_request_reason)
		_prematch_request_pending = false

func _start_sim_after_countdown() -> void:
	if sim_runner == null:
		return
	if not sim_runner.has_bound_state():
		await sim_runner.sim_bound
	if sim_runner == null or not is_instance_valid(sim_runner):
		return
	if not sim_runner.has_bound_state():
		SFLog.info("COUNTDOWN_START_SIM", {
			"iid": int(sim_runner.bound_iid),
			"has_state": false
		})
		return
	SFLog.info("COUNTDOWN_START_SIM", {
		"iid": int(sim_runner.bound_iid),
		"has_state": true
	})
	SFLog.info("ARENA_START_SIM", {"iid": int(sim_runner.bound_iid)})
	sim_runner.set_running(true, "prematch_countdown_complete")

func start_prematch_countdown(seconds: int = 3, reason: String = "prematch_countdown") -> void:
	_ensure_sim_runner()
	_ensure_prematch_countdown_ui()
	if seconds < 0:
		seconds = 0
	_prematch_countdown_seconds = seconds
	_prematch_countdown_remaining = seconds
	_prematch_countdown_active = true
	_prematch_countdown_hide_id += 1
	_prematch_request_pending = true
	_prematch_request_seconds = seconds
	_prematch_request_reason = reason
	SFLog.info("COUNTDOWN_BEGIN", {"seconds": seconds, "reason": reason})
	_set_prematch_countdown_label("%d" % _prematch_countdown_remaining)
	SFLog.info("COUNTDOWN_TICK", {"remaining": _prematch_countdown_remaining})
	_request_prematch_if_possible()
	if _prematch_countdown_timer != null:
		_prematch_countdown_timer.stop()
	if seconds <= 0:
		_finish_prematch_countdown()
		return
	if _prematch_countdown_timer != null:
		_prematch_countdown_timer.start(1.0)

func _on_prematch_countdown_tick() -> void:
	if not _prematch_countdown_active:
		if _prematch_countdown_timer != null:
			_prematch_countdown_timer.stop()
		return
	_prematch_countdown_remaining -= 1
	if _prematch_countdown_remaining <= 0:
		_finish_prematch_countdown()
		return
	_set_prematch_countdown_label("%d" % _prematch_countdown_remaining)
	SFLog.info("COUNTDOWN_TICK", {"remaining": _prematch_countdown_remaining})

func _finish_prematch_countdown() -> void:
	if not _prematch_countdown_active:
		return
	_prematch_countdown_active = false
	if _prematch_countdown_timer != null:
		_prematch_countdown_timer.stop()
	_set_prematch_countdown_label("GO")
	SFLog.info("COUNTDOWN_END", {"seconds": _prematch_countdown_seconds})
	_schedule_prematch_countdown_hide()
	_start_sim_after_countdown()

func _schedule_prematch_countdown_hide() -> void:
	var hide_id = _prematch_countdown_hide_id + 1
	_prematch_countdown_hide_id = hide_id
	var tree = get_tree()
	if tree == null:
		_set_prematch_countdown_label("")
		return
	var timer = tree.create_timer(0.75, true, false, true)
	timer.timeout.connect(func() -> void:
		if hide_id != _prematch_countdown_hide_id:
			return
		_set_prematch_countdown_label("")
	)

func _set_prematch_countdown_label(text: String) -> void:
	if _prematch_countdown_label == null:
		return
	_prematch_countdown_label.text = text
	_prematch_countdown_label.visible = text != ""

func start_sim() -> void:
	if sim_runner == null:
		return
	autostart = true
	sim_runner.start_sim()

func _process(delta: float) -> void:
	if input_system != null:
		input_system.tick(delta, api)
	if tie_toast != null and tie_toast_ms > 0.0:
		tie_toast_ms = max(0.0, tie_toast_ms - delta * 1000.0)
		if tie_toast_ms <= 0.0:
			tie_toast.visible = false
	_update_selection_hud()
	_update_buff_ui()
	_update_ops_timer_label()

func dbg(msg: String) -> void:
	if debug_system != null:
		debug_system.dbg(msg)
		return
	var t_sec = float(Time.get_ticks_msec()) / 1000.0
	SFLog.debug("%8.3f | %s" % [t_sec, msg])

func log_scale_if_changed(reason: String) -> void:
	if scale == _last_scale:
		return
	SFLog.debug_log(1, "%s scale changed (%s): %s -> %s" % [name, reason, str(_last_scale), str(scale)])
	_last_scale = scale

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
	var v = get_viewport()
	if v == null:
		return
	var active = v.get_camera_2d()
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

func cam_set(tag: String, pos: Vector2, zoom: Vector2) -> void:
	var cam = $Camera2D
	cam.make_current()
	cam.global_position = pos
	cam.zoom = zoom
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
	var root = get_tree().root
	var arenas = root.find_children("Arena", "Node", true, false)
	SFLog.trace("Arenas", {"count": arenas.size()})
	for a in arenas:
		SFLog.trace(" - ", {"path": a.get_path()})
	var map_roots = root.find_children("MapRoot", "Node", true, false)
	SFLog.trace("MapRoots", {"count": map_roots.size()})
	for m in map_roots:
		SFLog.trace(" - ", {"path": m.get_path()})
	var hrs = root.find_children("HiveRenderer", "Node", true, false)
	SFLog.trace("HiveRenderers", {"count": hrs.size()})
	for h in hrs:
		SFLog.trace(" - ", {
			"path": h.get_path(),
			"vis": (h.visible if h is CanvasItem else "n/a"),
			"children": h.get_child_count()
		})
	var lrs = root.find_children("LaneRenderer", "Node", true, false)
	SFLog.trace("LaneRenderers", {"count": lrs.size()})
	for l in lrs:
		SFLog.trace(" - ", {
			"path": l.get_path(),
			"vis": (l.visible if l is CanvasItem else "n/a"),
			"children": l.get_child_count()
		})

func _dump_tree_with_scripts(path: String) -> void:
	var root = get_node_or_null(path)
	if root == null:
		SFLog.trace("DUMP: node not found", {"path": path})
		return
	SFLog.trace("\n=== TREE DUMP ===", {"path": root.get_path()})
	_dump_node(root, 0)

func _dump_node(n: Node, depth: int) -> void:
	var indent = "  ".repeat(depth)
	var s = ""
	if n.get_script() != null:
		s = " script=" + str(n.get_script().resource_path)
	SFLog.trace(indent + "- ", {"path": n.get_path(), "type": n.get_class(), "script": s})
	for c in n.get_children():
		_dump_node(c, depth + 1)

func _list_canvasitems_with_scripts(path: String) -> void:
	var root = get_node_or_null(path)
	if root == null:
		SFLog.trace("SCAN: node not found", {"path": path})
		return
	SFLog.trace("\n=== CANVASITEM SCAN ===", {"path": root.get_path()})
	var items = root.find_children("", "CanvasItem", true, false)
	for it in items:
		var ci = it as CanvasItem
		var sp = ""
		if it.get_script() != null:
			sp = str(it.get_script().resource_path)
		if sp != "":
			SFLog.trace(" - ", {"path": it.get_path(), "type": it.get_class(), "vis": ci.visible, "script": sp})

func _dump_viewports_and_textures() -> void:
	SFLog.trace("\n=== VIEWPORT/TEXTURE DUMP ===")
	var root = get_tree().root
	var svcs = root.find_children("", "SubViewportContainer", true, false)
	SFLog.trace("SubViewportContainers", {"count": svcs.size()})
	for c in svcs:
		SFLog.trace(" - ", {"path": c.get_path()})
	var svs = root.find_children("", "SubViewport", true, false)
	SFLog.trace("SubViewports", {"count": svs.size()})
	for v in svs:
		SFLog.trace(" - ", {
			"path": v.get_path(),
			"update": v.render_target_update_mode,
			"clear": v.render_target_clear_mode
		})
	var trs = root.find_children("", "TextureRect", true, false)
	SFLog.trace("TextureRects", {"count": trs.size()})
	for t in trs:
		var tex: Texture2D = t.texture
		SFLog.trace(" - ", {"path": t.get_path(), "tex": (tex.resource_path if tex else "null")})

func _kill_foreign_renderers(keep_arena: Node) -> void:
	var keep_prefix = str(keep_arena.get_path())
	for n in get_tree().root.find_children("HiveRenderer", "Node", true, false):
		var p = str(n.get_path())
		if not p.begins_with(keep_prefix):
			SFLog.trace("KILL HiveRenderer", {"path": p})
			if n is CanvasItem:
				n.visible = false
			n.queue_free()
	for n in get_tree().root.find_children("LaneRenderer", "Node", true, false):
		var p = str(n.get_path())
		if not p.begins_with(keep_prefix):
			SFLog.trace("KILL LaneRenderer", {"path": p})
			if n is CanvasItem:
				n.visible = false
			n.queue_free()

func _debug_scan_names() -> void:
	var out: Array[Node] = []
	var root = get_tree().root
	_scan(root, out)
	for n in out:
		SFLog.trace("FOUND", {"path": str(n.get_path()), "type": n.get_class()})

func _scan(n: Node, out: Array[Node]) -> void:
	var cname = n.get_class()
	if cname.find("Hive") != -1 or cname.find("Lane") != -1 or str(n.name).find("Hive") != -1 or str(n.name).find("Lane") != -1:
		out.append(n)
	for c in n.get_children():
		_scan(c, out)

func clear_map() -> void:
	var hr = $MapRoot/HiveRenderer
	var lr = $MapRoot/LaneRenderer
	for c in hr.get_children():
		c.queue_free()
	for c in lr.get_children():
		c.queue_free()
	SFLog.trace("MAP CLEAR", {"hive": hr.get_child_count(), "lane": lr.get_child_count()})

func clear_map_render() -> void:
	var hr = $MapRoot/HiveRenderer
	var lr = $MapRoot/LaneRenderer
	var ur = $MapRoot/UnitRenderer
	for c in hr.get_children():
		c.queue_free()
	for c in lr.get_children():
		c.queue_free()
	for c in ur.get_children():
		c.queue_free()
	if hr.has_method("clear_all"):
		hr.call("clear_all")
	if lr.has_method("clear_all"):
		lr.call("clear_all")
	if ur.has_method("clear_all"):
		ur.call("clear_all")
	SFLog.trace("CLEAR_MAP_RENDER", {
		"hr": hr.get_child_count(),
		"lr": lr.get_child_count(),
		"ur": ur.get_child_count()
	})

func set_model(m: Dictionary) -> void:
	model = m

func world_center() -> Vector2:
	return _canon_world_px() * 0.5

func _canon_world_px() -> Vector2:
	return Vector2(GRID_W * CELL_SIZE, GRID_H * CELL_SIZE)

func _compute_fit_zoom(viewport_size: Vector2, margin_x: float, margin_y: float, world_px: Vector2) -> float:
	if world_px.x <= 0.0 or world_px.y <= 0.0:
		return 1.0
	var fit_x: float = (viewport_size.x / world_px.x) * margin_x
	var fit_y: float = (viewport_size.y / world_px.y) * margin_y
	return min(fit_x, fit_y)

func _apply_canon_camera_fit(tag: String) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var arena_rect = _arena_rect()
	var raw_arena_rect = arena_rect
	if RenderProjection.enabled:
		arena_rect = RenderProjection.project_rect(arena_rect)
	var world_px: Vector2 = arena_rect.size
	var center: Vector2 = arena_rect.position + arena_rect.size * 0.5
	var zoom_factor: float = _compute_fit_zoom(vp, FIT_MARGIN_X, FIT_MARGIN_Y, world_px)
	# Project convention: Camera2D.zoom uses the fit scale directly (not inverse).
	var zoom_vec: Vector2 = Vector2(zoom_factor, zoom_factor)
	cam_set(tag, center, zoom_vec)
	SFLog.log_once(
		"FITCANON_DEBUG_" + tag,
		"FITCANON_DEBUG",
		SFLog.Level.INFO,
		{
			"tag": tag,
			"viewport": vp,
			"raw_arena_rect": raw_arena_rect,
			"proj_enabled": RenderProjection.enabled,
			"arena_rect_used": arena_rect,
			"center": center,
			"zoom": zoom_vec
		}
	)
	SFLog.trace("FITCANON", {
		"grid_w": MapSchema.CANON_GRID_W,
		"grid_h": MapSchema.CANON_GRID_H,
		"world_px": world_px,
		"viewport": vp,
		"center": center,
		"zoom": zoom_vec
	})

func _nearest_canvas_layer(n: Node) -> CanvasLayer:
	var p = n.get_parent()
	while p != null:
		if p is CanvasLayer:
			return p
		p = p.get_parent()
	return null

func _debug_canvas_space() -> void:
	await get_tree().process_frame
	var lr = $MapRoot/LaneRenderer
	var hr = $MapRoot/HiveRenderer
	var lr_cl = _nearest_canvas_layer(lr)
	var hr_cl = _nearest_canvas_layer(hr)
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
	var safe_rect = Rect2(Vector2.ZERO, viewport_size)
	var overlays_count = 0
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
	var msg = "LANE_EST_%s lane=%s owner=%d" % [event, lane_key, owner_id]
	if t >= 0.0:
		msg += " t=%.3f" % t
	if extra != "":
		msg += " " + extra
	if event == "ADVANCE":
		SFLog.trace(msg)
	else:
		SFLog.info(msg)

func _tick(dt: float) -> void:
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
	_update_towers(dt)
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

func _state_iid(state) -> int:
	if state == null:
		return 0
	if typeof(state) == TYPE_DICTIONARY:
		return int(state.get("iid", state.get("id", 0)))
	if state.has_method("get"):
		var v = state.get("iid")
		if v != null:
			return int(v)
		v = state.get("id")
		if v != null:
			return int(v)
	return 0

func export_render_model() -> Dictionary:
	SFLog.error("EXPORT_RENDER_MODEL_VERSION", {"marker": "2026-01-14-A", "line": 0})
	assert(state is GameState)
	if not _render_dirty and not _render_model.is_empty():
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
	if state != null:
		for lane_any in state.lanes:
			if lane_any is LaneData:
				var l: LaneData = lane_any
				out_lanes.append({
					"lane_id": int(l.id),
					"a_id": int(l.a_id),
					"b_id": int(l.b_id),
					"send_a": bool(l.send_a),
					"send_b": bool(l.send_b),
					"intent": "",
					"pressure": 0
				})
			elif lane_any is Dictionary:
				var d: Dictionary = lane_any as Dictionary
				out_lanes.append({
					"lane_id": int(d.get("lane_id", d.get("id", -1))),
					"a_id": int(d.get("a_id", d.get("from", 0))),
					"b_id": int(d.get("b_id", d.get("to", 0))),
					"send_a": bool(d.get("send_a", false)),
					"send_b": bool(d.get("send_b", false)),
					"intent": str(d.get("intent", "")),
					"pressure": int(d.get("pressure", 0))
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
				var owner_id = int(side.get("owner_id", 0))
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
	if state != null:
		var units_v: Variant = state.units_by_lane.get("_all", [])
		if typeof(units_v) == TYPE_ARRAY:
			for unit in units_v as Array:
				if typeof(unit) != TYPE_DICTIONARY:
					continue
				var ud: Dictionary = unit as Dictionary
				var entry = {
					"id": int(ud.get("id", -1)),
					"from": int(ud.get("from_id", 0)),
					"to": int(ud.get("to_id", 0)),
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
	if debug_render_model_log:
		var now_ms = Time.get_ticks_msec()
		if now_ms - _last_render_model_log_ms >= 1000:
			_last_render_model_log_ms = now_ms
			SFLog.info("EXPORT_RM", {"state": state, "type": typeof(state)})
	_render_model = {
		"hives": out_hives,
		"hives_by_id": out_hives_by_id,
		"lanes": out_lanes,
		"runtime_lanes": out_runtime_lanes,
		"lane_candidates": out_lane_candidates,
		"lane_sim": out_lane_sim,
		"units": out_units,
		"cell_size": int(CELL_SIZE),
		"selected_lane_id": int(sel.selected_lane_id) if sel != null else -1,
		"render_version": render_version,
		"iid": _state_iid(state)
	}
	_render_dirty = false
	return _render_model

func _push_render_model() -> void:
	var rm: Dictionary = export_render_model()
	if rm.is_empty():
		return
	var lane_r: Node = get_node_or_null("MapRoot/LaneRenderer")
	var hive_r: Node = get_node_or_null("MapRoot/HiveRenderer")
	var unit_r: Node = get_node_or_null("MapRoot/UnitRenderer")
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
		if hive_r != null and lane_r.has_method("set_hive_nodes") and hive_r.has_method("get_hive_nodes_by_id"):
			lane_r.call("set_hive_nodes", hive_r.call("get_hive_nodes_by_id"))
		lane_r.queue_redraw()
	if unit_r != null:
		if unit_r.has_method("set_model"):
			unit_r.call("set_model", rm)
		else:
			unit_r.set("model", rm)
		if hive_r != null and unit_r.has_method("set_hive_nodes") and hive_r.has_method("get_hive_nodes_by_id"):
			unit_r.call("set_hive_nodes", hive_r.call("get_hive_nodes_by_id"))
		unit_r.queue_redraw()

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
	var dt_ms = dt * 1000.0
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
		var result: Dictionary = buff_state.configure_loadout(_default_buff_loadout())
		if not bool(result.get("ok", false)):
			push_error("ARENA: buff loadout invalid for P%d: %s" % [pid, result.get("error", "unknown")])
		buff_states[pid] = buff_state

func _default_buff_loadout() -> Array:
	var ids: Array[String] = debug_buff_loadout
	if ids.size() != 3:
		ids = [
			"buff_swarm_speed_classic",
			"buff_hive_faster_production_classic",
			"buff_tower_fire_rate_classic"
		]
	return [
		{"id": ids[0], "tier": "classic"},
		{"id": ids[1], "tier": "classic"},
		{"id": ids[2], "tier": "classic"}
	]

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
	var now_ms: int = int(sim_time_us / 1000)
	for buff_state in buff_states.values():
		buff_state.update(now_ms)
	_sync_buff_effects(now_ms)

func _enter_overtime() -> void:
	overtime_active = true
	hurry_mode = true
	audio_hurry_pitch = 1.15
	if buffs_enabled:
		for buff_state in buff_states.values():
			buff_state.unlock_third_slot()
			buff_state.enable_tap_to_top()
	dbg("SF: OVERTIME start (clock visible, slot3 unlocked, tap-to-top enabled)")
	SFLog.info("OVERTIME: start")

func _reset_match_stats() -> void:
	units_landed = {1: 0, 2: 0, 3: 0, 4: 0}
	tower_control_ms = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0}
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

func _try_activate_buff_slot(pid: int, slot_index: int) -> void:
	OpsState.try_activate_buff_slot(pid, slot_index)
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
	match_ms_remaining = match_length_ms
	winner_id = -1
	end_reason = ""
	game_over = false
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
	if timer_label != null:
		timer_label.visible = false
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
		state.tower_owner_by_node_id.clear()
		for tower in towers:
			var node_id: int = int(tower.get("node_id", tower.get("id", -1)))
			if node_id != -1:
				state.structure_by_node_id[node_id] = "tower"
				state.tower_owner_by_node_id[node_id] = int(tower.get("owner_id", 0))

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
			"active": false,
			"owner_id": 0,
			"tier": 1,
			"spawn_accum_ms": 0.0,
			"rr_index": 0,
			"preferred_targets": []
		}
	]

func _is_dev_mouse_override() -> bool:
	return OS.is_debug_build() or Engine.is_editor_hint()

func _dev_mouse_pid(event: InputEventMouseButton) -> int:
	if not _is_dev_mouse_override():
		return -1
	if event.button_index == MOUSE_BUTTON_LEFT:
		return 1
	if event.button_index == MOUSE_BUTTON_RIGHT:
		return 3
	return -1

func _mouse_world_pos() -> Vector2:
	return _screen_to_world(get_viewport().get_mouse_position())

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var cam = get_viewport().get_camera_2d()
	if cam:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		var screen_center: Vector2 = vp_size * 0.5
		var world_center: Vector2 = cam.get_screen_center_position()
		return world_center + (screen_pos - screen_center) / cam.zoom
	return get_global_mouse_position()

func _unhandled_input(event: InputEvent) -> void:
	if input_system == null or api == null:
		return
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			var wp: Vector2 = map_root.get_global_mouse_position()
			var lp: Vector2 = map_root.to_local(wp)
			_send_pointer_event(mb.pressed, mb.button_index, lp, false, wp, mb.position)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		var mm = event as InputEventMouseMotion
		var wp: Vector2 = map_root.get_global_mouse_position()
		var lp: Vector2 = map_root.to_local(wp)
		_send_pointer_event(false, 0, lp, true, wp, mm.position)
		return
	if event is InputEventScreenTouch:
		var st = event as InputEventScreenTouch
		var wp: Vector2 = map_root.get_global_mouse_position()
		var lp: Vector2 = map_root.to_local(wp)
		_send_pointer_event(st.pressed, MOUSE_BUTTON_LEFT, lp, false, wp, st.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		var sd = event as InputEventScreenDrag
		var wp: Vector2 = map_root.get_global_mouse_position()
		var lp: Vector2 = map_root.to_local(wp)
		_send_pointer_event(false, 0, lp, true, wp, sd.position)
		return
	input_system.handle_input(event, api)

func _pointer_local_from_screen(screen_pos: Vector2) -> Vector2:
	var wp: Vector2 = _screen_to_world(screen_pos)
	return map_root.to_local(wp)

func _send_pointer_event(pressed: bool, button_index: int, local_pos: Vector2, is_motion: bool = false, world_pos: Vector2 = Vector2.ZERO, screen_pos: Vector2 = Vector2.ZERO) -> void:
	var hive_id: int = api.hive_id_at_point(local_pos)
	var lane_hit: LaneData = api.pick_lane(local_pos)
	var lane_id: int = lane_hit.id if lane_hit != null else -1
	var ev_type: String = "motion" if is_motion else ("press" if pressed else "release")
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
		var is_primary_click = (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT)
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
	if hive_renderer != null and hive_renderer.has_method("get_hive_nodes_by_id"):
		var nodes_by_id: Dictionary = hive_renderer.call("get_hive_nodes_by_id")
		for hid in nodes_by_id.keys():
			var node = nodes_by_id[hid] as Node2D
			if node == null:
				continue
			var center = node.position
			if node.has_method("get_base_anchor_local"):
				center = node.position + node.call("get_base_anchor_local")
			var radius = float(node.call("get_base_radius_px")) if node.has_method("get_base_radius_px") else 0.0
			if radius <= 0.0:
				radius = _hive_radius_px_for_model(_cell_size_for_model())
			if center.distance_to(lp) <= radius:
				return str(hid)
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
		var lane_id = 1
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
			var lane_data = LaneData.new(lane_id, a_id, b_id, 1, false, false)
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
	var result = {
		"ok": false,
		"lane_id": -1,
		"a_id": -1,
		"b_id": -1,
		"t": 0.0,
		"dist": -1.0
	}
	if state == null:
		return result
	var best_lane: LaneData = null
	var best_dist: float = INF
	var best_t: float = 0.0
	for lane in state.lanes:
		if lane == null:
			continue
		var a: HiveData = _find_hive_by_id(lane.a_id)
		var b: HiveData = _find_hive_by_id(lane.b_id)
		if a == null or b == null:
			continue
		var a_pos: Vector2 = _cell_center(a.grid_pos)
		var b_pos: Vector2 = _cell_center(b.grid_pos)
		var ab: Vector2 = b_pos - a_pos
		var t: float = 0.0
		var dist: float = 0.0
		var ab_len_sq = ab.length_squared()
		if ab_len_sq <= 0.0:
			dist = local_pos.distance_to(a_pos)
		else:
			t = clamp((local_pos - a_pos).dot(ab) / ab_len_sq, 0.0, 1.0)
			var proj = a_pos + ab * t
			dist = local_pos.distance_to(proj)
		if dist <= LANE_HIT_DIST_PX and dist < best_dist:
			best_dist = dist
			best_lane = lane
			best_t = t
	if best_lane == null:
		return result
	return {
		"ok": true,
		"lane_id": int(best_lane.id),
		"a_id": int(best_lane.a_id),
		"b_id": int(best_lane.b_id),
		"t": float(best_t),
		"dist": float(best_dist)
	}

func _distance_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	if ab.length_squared() == 0.0:
		return p.distance_to(a)
	var t: float = (p - a).dot(ab) / ab.length_squared()
	t = clamp(t, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_to(proj)

func _cell_px() -> float:
	if hive_renderer != null:
		return float(hive_renderer.cell_px)
	if grid_spec != null:
		return grid_spec.cell_size
	return CELL_SIZE

func _arena_rect() -> Rect2:
	var cell_px = _cell_px()
	if grid_spec != null:
		return Rect2(grid_spec.origin, Vector2(grid_spec.grid_w * cell_px, grid_spec.grid_h * cell_px))
	return Rect2(Vector2.ZERO, Vector2(grid_w * cell_px, grid_h * cell_px))

func _clear_map_markers() -> void:
	for child in map_root.get_children():
		if child.get_meta("map_marker", false):
			map_root.remove_child(child)
			child.queue_free()

func _add_map_marker(pos: Vector2) -> void:
	var marker = Node2D.new()
	marker.position = pos
	marker.visible = false
	marker.set_meta("map_marker", true)
	map_root.add_child(marker)

func _rebuild_map_markers() -> void:
	_clear_map_markers()
	var arena_rect = _arena_rect()
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
	var r = Rect2()
	var first = true
	for child in map_root.get_children():
		if child is Node2D:
			var p = (child as Node2D).position
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
	var bounds = _compute_map_root_bounds()
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		_map_bounds_size = _arena_rect().size
		return Rect2(Vector2.ZERO, _map_bounds_size)
	map_root.position -= bounds.position
	_map_bounds_size = bounds.size
	return Rect2(Vector2.ZERO, _map_bounds_size)

func _debug_map_bounds(tag: String) -> void:
	if debug_system == null:
		return
	var bounds = _compute_map_root_bounds()
	var cam_pos = camera.global_position if camera != null else Vector2.ZERO
	var cam_zoom = camera.zoom if camera != null else Vector2.ONE
	debug_system.debug_map_bounds(tag, bounds, cam_pos, cam_zoom)

func _center_map_offset(_map_data: Dictionary) -> void:
	map_offset = Vector2.ZERO

func cell_center(grid_pos: Vector2i) -> Vector2:
	return _cell_center(grid_pos)

func _cell_center(cell: Vector2i) -> Vector2:
	if grid_spec != null:
		return grid_spec.grid_to_world(cell)
	var cell_px = _cell_px()
	return Vector2(
		cell.x * cell_px + cell_px * 0.5,
		cell.y * cell_px + cell_px * 0.5
	) + map_offset

func _cell_rect(cell: Vector2i) -> Rect2:
	if grid_spec != null:
		var size = Vector2(grid_spec.cell_size, grid_spec.cell_size)
		var pos = grid_spec.origin + Vector2(cell.x, cell.y) * grid_spec.cell_size
		return Rect2(pos, size)
	var cell_px = _cell_px()
	return Rect2(
		Vector2(cell.x, cell.y) * cell_px + map_offset,
		Vector2(cell_px, cell_px)
	)

func _to_map_local(local_pos: Vector2) -> Vector2:
	return local_pos - map_root.position

func _draw() -> void:
	if not draw_arena_rect_debug:
		return
	var arena_rect = _arena_rect()
	if RenderProjection.enabled:
		arena_rect = RenderProjection.project_rect(arena_rect)
	draw_rect(arena_rect, Color(0.95, 0.65, 0.2, 0.9), false, 2.0)
	var bounds = _compute_map_root_bounds()
	if bounds.size.x > 1.0 and bounds.size.y > 1.0:
		bounds.position += map_root.position
		if RenderProjection.enabled:
			bounds = RenderProjection.project_rect(bounds)
		draw_rect(bounds, Color(0.2, 0.8, 0.9, 0.9), false, 2.0)

func _owner_color(owner_id: int) -> Color:
	return TeamPalette.color_for_owner(owner_id)

func _owner_label(owner_id: int) -> String:
	match owner_id:
		0:
			return "Neutral"
		1:
			return "P1 (Yellow)"
		2:
			return "P2 (Green)"
		3:
			return "P3 (Red)"
		4:
			return "P4 (Blue)"
		_:
			return "P%d" % owner_id

func _update_lanes(delta: float) -> void:
	for i in range(state.lanes.size()):
		var lane: Variant = state.lanes[i]
		var was_active: bool = false
		if lane is LaneData:
			var ld = lane as LaneData
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
				ld.a_stream_len = min(lane_len, ld.a_stream_len + UNIT_SPEED_PX * delta)
			if rate_b > 0.0:
				ld.b_pressure += rate_b * delta
				ld.b_stream_len = min(lane_len, ld.b_stream_len + UNIT_SPEED_PX * delta)
			if ld.retract_a:
				ld.a_stream_len = max(0.0, ld.a_stream_len - UNIT_SPEED_PX * delta)
				if ld.a_stream_len <= 0.0:
					ld.retract_a = false
			if ld.retract_b:
				ld.b_stream_len = max(0.0, ld.b_stream_len - UNIT_SPEED_PX * delta)
				if ld.b_stream_len <= 0.0:
					ld.retract_b = false
			if ld.establish_a and ld.a_stream_len >= lane_len:
				ld.establish_a = false
			if ld.establish_b and ld.b_stream_len >= lane_len:
				ld.establish_b = false
			var is_active = (
				ld.send_a or ld.send_b or ld.retract_a or ld.retract_b
				or ld.establish_a or ld.establish_b
				or ld.a_stream_len > 0.0 or ld.b_stream_len > 0.0
			)
			if was_active or is_active:
				_note_render_dirty()
		elif lane is Dictionary:
			var d = lane as Dictionary
			var send_a = bool(d.get("send_a", false))
			var send_b = bool(d.get("send_b", false))
			var retract_a = bool(d.get("retract_a", false))
			var retract_b = bool(d.get("retract_b", false))
			var establish_a = bool(d.get("establish_a", false))
			var establish_b = bool(d.get("establish_b", false))
			var a_stream_len = float(d.get("a_stream_len", 0.0))
			var b_stream_len = float(d.get("b_stream_len", 0.0))
			var a_pressure = float(d.get("a_pressure", 0.0))
			var b_pressure = float(d.get("b_pressure", 0.0))
			was_active = (
				send_a or send_b or retract_a or retract_b
				or establish_a or establish_b
				or a_stream_len > 0.0 or b_stream_len > 0.0
			)
			var a_id = int(d.get("a_id", -1))
			var b_id = int(d.get("b_id", -1))
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
				a_stream_len = min(lane_len, a_stream_len + UNIT_SPEED_PX * delta)
			if rate_b > 0.0:
				b_pressure += rate_b * delta
				b_stream_len = min(lane_len, b_stream_len + UNIT_SPEED_PX * delta)
			if retract_a:
				a_stream_len = max(0.0, a_stream_len - UNIT_SPEED_PX * delta)
				if a_stream_len <= 0.0:
					retract_a = false
			if retract_b:
				b_stream_len = max(0.0, b_stream_len - UNIT_SPEED_PX * delta)
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
			var is_active = (
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
	var any_dirty = false
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
		var lane_dirty = false
		var side_by_owner: Dictionary = lane_state.get("side", {})
		var establish_t_by_owner: Dictionary = lane_state.get("establish_t_by_owner", {})
		var establishing_by_owner: Dictionary = lane_state.get("establishing_by_owner", {})
		var established_by_owner: Dictionary = lane_state.get("established_by_owner", {})
		var spawn_timer_ms_by_owner: Dictionary = lane_state.get("spawn_timer_ms_by_owner", {})
		var establish_last_by_owner: Dictionary = lane_state.get("establish_last_by_owner", {})
		for owner_key in side_by_owner.keys():
			var side: Dictionary = side_by_owner[owner_key]
			var owner_id = int(side.get("owner_id", 0))
			var just_established = false
			var establishing = bool(establishing_by_owner.get(owner_id, false))
			var established = bool(established_by_owner.get(owner_id, false))
			var progress = float(establish_t_by_owner.get(owner_id, 0.0))
			var last_progress = float(establish_last_by_owner.get(owner_id, progress))
			var lane_key_str = str(lane_state.get("lane_key", key))
			if last_progress > 0.0 and progress < last_progress:
				var msg = "ESTABLISH_RESET lane=%s owner=%d progress=%.3f prev=%.3f" % [
					lane_key_str,
					owner_id,
					progress,
					last_progress
				]
				SFLog.throttle("est_reset:%s:%d" % [lane_key_str, owner_id], 0.25, msg, SFLog.Level.INFO)
			if establishing and not established:
				var est_speed = float(side.get("est_speed", 0.0))
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
					var msg = "ESTABLISH_COMPLETE lane=%s owner=%d progress=%.3f" % [
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
			var spawn_interval_ms = _spawn_interval_ms_for_power(power)
			if not established:
				pass
			else:
				var spawn_timer_ms = float(spawn_timer_ms_by_owner.get(owner_id, 0.0))
				if just_established:
					spawn_timer_ms = float(spawn_timer_ms_by_owner.get(owner_id, FIRST_UNIT_OFFSET_MS))
				var timer_ms = spawn_timer_ms
				var prev_timer_ms = timer_ms
				if not just_established:
					timer_ms -= dt * 1000.0
				var spawned = false
				while timer_ms <= 0.0:
					_spawn_first_unit_for_side(lane_state, side)
					if not bool(side.get("first_unit_sent", false)):
						side["first_unit_sent"] = true
						_clear_active_order_for_side(lane_state, side)
						var msg = "FIRST_UNIT lane=%s owner=%d" % [
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
				var spawned_a = _spawn_lane_units(lane, a, b, dt_ms, true, stats)
				stats["did_spawn"] = int(stats["did_spawn"]) + spawned_a
		if lane.send_b:
			if not spawn_ids.is_empty() and not spawn_ids.has(b.id):
				stats["skip_other"] = int(stats["skip_other"]) + 1
			else:
				var spawned_b = _spawn_lane_units(lane, b, a, dt_ms, false, stats)
				stats["did_spawn"] = int(stats["did_spawn"]) + spawned_b
	var spawnwhy_msg = "SPAWNWHY: did=%d bad_hive=%d no_lane=%d rate=%d other=%d lanes=%d units=%d" % [
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
	var spawned = 0
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
	var endpoints = _lane_endpoints_for_unit(unit)
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
		var dir_i = int(unit.get("dir", 0))
		var t_val = clampf(float(unit.get("t", 0.0)), 0.0, 1.0)
		if dir_i < 0:
			unit["lane_t"] = clampf(1.0 - t_val, 0.0, 1.0)
		else:
			unit["lane_t"] = t_val
	return unit

func _unit_lane_t(unit: Dictionary) -> float:
	if unit.has("lane_t"):
		return clampf(float(unit.get("lane_t", 0.0)), 0.0, 1.0)
	var dir = int(unit.get("dir", 0))
	var t = clampf(float(unit.get("t", 0.0)), 0.0, 1.0)
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
		var lane_key = str(unit.get("lane_key", ""))
		if lane_key.is_empty():
			continue
		var lane_t = clampf(_unit_lane_t(unit), 0.0, 1.0)
		unit["lane_t"] = lane_t
		units[i] = unit
		if not units_by_lane.has(lane_key):
			units_by_lane[lane_key] = {}
		var owner_id = int(unit.get("owner_id", 0))
		if not (units_by_lane[lane_key] as Dictionary).has(owner_id):
			(units_by_lane[lane_key] as Dictionary)[owner_id] = []
		((units_by_lane[lane_key] as Dictionary)[owner_id] as Array).append({
			"idx": i,
			"t": lane_t,
			"owner_id": owner_id,
			"dir": int(unit.get("dir", 0))
		})
	state.units_by_lane = units_by_lane

	for lane_key in units_by_lane.keys():
		var endpoints = _lane_endpoints_for_key(str(lane_key))
		if endpoints.size() != 2:
			continue
		var a_hive: HiveData = _find_hive_by_id(int(endpoints[0]))
		var b_hive: HiveData = _find_hive_by_id(int(endpoints[1]))
		if a_hive == null or b_hive == null:
			continue
		var lane_len = _lane_length_px(a_hive, b_hive)
		if not state.lane_sim_by_key.has(str(lane_key)):
			state.ensure_lane_state(int(endpoints[0]), int(endpoints[1]), lane_len)
		var spike_t = _lane_spike_t(lane_len)
		var a_node_id: int = int(endpoints[0])
		var b_node_id: int = int(endpoints[1])
		var a_has_tower: bool = state != null and str(state.structure_by_node_id.get(a_node_id, "")) == "tower"
		var b_has_tower: bool = state != null and str(state.structure_by_node_id.get(b_node_id, "")) == "tower"
		var a_tower_owner: int = int(state.tower_owner_by_node_id.get(a_node_id, 0)) if state != null else 0
		var b_tower_owner: int = int(state.tower_owner_by_node_id.get(b_node_id, 0)) if state != null else 0

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
				var unit_lane_key = str(unit.get("lane_key", ""))
				if unit_lane_key != str(lane_key):
					SFLog.info("LANE_LEAK unit_id=%d unit_lane=%s processing_lane=%s" % [
						int(unit.get("id", -1)),
						unit_lane_key,
						str(lane_key)
					])
					continue
				var lane_t = clampf(float(unit.get("lane_t", entry.get("t", 0.0))), 0.0, 1.0)
				# Edge zones for future feed/decay hooks (stub only).
				var _edge_zone = lane_t <= LANE_EDGE_T or lane_t >= 1.0 - LANE_EDGE_T
				var owner_id = int(unit.get("owner_id", 0))
				if not DEBUG_COLLISION_ONLY:
					if a_has_tower and owner_id != a_tower_owner and lane_t <= spike_t:
						SFLog.info("UNIT_DIE spike lane=%s owner=%d t=%.3f" % [
							str(lane_key),
							owner_id,
							lane_t
						])
						record_lane_collision(str(lane_key), lane_t)
						_kill_unit(idx, unit, "spike_a", remove_indices, remove_set)
					elif b_has_tower and owner_id != b_tower_owner and lane_t >= 1.0 - spike_t:
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
				var unit_lane_key = str(unit.get("lane_key", ""))
				if unit_lane_key != str(lane_key):
					SFLog.info("LANE_LEAK unit_id=%d unit_lane=%s processing_lane=%s" % [
						int(unit.get("id", -1)),
						unit_lane_key,
						str(lane_key)
					])
					continue
				entry["t"] = clampf(float(unit.get("lane_t", 0.0)), 0.0, 1.0)
				var dir_i = int(unit.get("dir", int(entry.get("dir", 0))))
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
			var a_t = clampf(float(a_unit.get("lane_t", 0.0)), 0.0, 1.0)
			var b_t = clampf(float(b_unit.get("lane_t", 0.0)), 0.0, 1.0)
			var a_dir: int = int(a_unit.get("dir", 0))
			var b_dir: int = int(b_unit.get("dir", 0))
			var a_spawn_end = str(a_unit.get("spawn_end", "?"))
			var b_spawn_end = str(b_unit.get("spawn_end", "?"))
			var a_entry_dir: int = int(a_entry.get("dir", 0))
			var b_entry_dir: int = int(b_entry.get("dir", 0))
			var a_entry_t: float = float(a_entry.get("t", -1.0))
			var b_entry_t: float = float(b_entry.get("t", -1.0))
			var owner_match = int(a_unit.get("owner_id", 0)) == int(b_unit.get("owner_id", 0))
			var a_from_id: int = int(a_unit.get("from_id", -1))
			var b_from_id: int = int(b_unit.get("from_id", -1))
			var a_from_valid = a_from_id == a_node_id or a_from_id == b_node_id
			var b_from_valid = b_from_id == a_node_id or b_from_id == b_node_id
			var dir_invalid = a_dir == 0 or b_dir == 0
			var from_invalid = not a_from_valid or not b_from_valid
			if owner_match or dir_invalid or from_invalid:
				var msg = "PAIR_DEBUG lane=%s f_idx=%d f_id=%d f_owner=%d f_dir=%d f_spawn=%s f_t=%.3f f_entry_dir=%d f_entry_t=%.3f | b_idx=%d b_id=%d b_owner=%d b_dir=%d b_spawn=%s b_t=%.3f b_entry_dir=%d b_entry_t=%.3f" % [
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
				var a_id: int = int(a_unit.get("id", -1))
				var b_id: int = int(b_unit.get("id", -1))
				var a_dead = bool(a_unit.get("dead", false))
				var b_dead = bool(b_unit.get("dead", false))
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
				var a_dead_post = false
				var b_dead_post = false
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
		var speed_t = 1.0 / (UNIT_TRAVEL_MS / 1000.0)
		unit["speed_t"] = speed_t
		var delta_t: float = speed_t * dt
		var dir_i: int = int(unit.get("dir", 0))
		if dir_i == 0:
			dir_i = 1
		if is_recall:
			unit["t"] = clampf(float(unit["t"]) - delta_t, 0.0, 1.0)
			var recall_t = float(unit["t"])
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
			if to_hive.owner_id == owner_id and to_hive.power >= 50 and to_hive.shock_ms <= 0.0:
				if _pass_through_swarm(packet, to_hive):
					swarm_packets.remove_at(i)
					continue
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
			var expected_lane_key = ""
			if state != null:
				expected_lane_key = state.lane_key(from_id, to_id)
			var unit_lane_key = str(unit.get("lane_key", ""))
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
			var expected_lane_key = ""
			if state != null:
				expected_lane_key = state.lane_key(from_id, to_id)
			var unit_lane_key = str(unit.get("lane_key", ""))
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
				var expected_lane_key = ""
				if state != null:
					expected_lane_key = state.lane_key(from_id, to_id)
				var unit_lane_key = str(unit.get("lane_key", ""))
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
				var expected_lane_key = ""
				if state != null:
					expected_lane_key = state.lane_key(from_id, to_id)
				var unit_lane_key = str(unit.get("lane_key", ""))
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
	remove_indices.sort()
	var last_removed = -1
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
	var count = 0
	for lane in state.lanes:
		if lane.send_a and lane.b_id == hive_id:
			var a: HiveData = _find_hive_by_id(lane.a_id)
			if a != null and a.owner_id != 0 and a.owner_id != owner_id:
				count += 1
		if lane.send_b and lane.a_id == hive_id:
			var b: HiveData = _find_hive_by_id(lane.b_id)
			if b != null and b.owner_id != 0 and b.owner_id != owner_id:
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
		var arrivals_text = "none" if parts.is_empty() else " ".join(parts)
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
	var t = 0.5
	if typeof(collision) == TYPE_VECTOR2:
		var a_hive: HiveData = _find_hive_by_id(a_id)
		var b_hive: HiveData = _find_hive_by_id(b_id)
		if a_hive == null or b_hive == null:
			return
		var a_pos = _cell_center(a_hive.grid_pos)
		var b_pos = _cell_center(b_hive.grid_pos)
		var ab = b_pos - a_pos
		var len_sq = ab.length_squared()
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
		if a_hive.owner_id == b_hive.owner_id:
			continue
		var lane_key = state.lane_key(lane.a_id, lane.b_id)
		var a_pos = _cell_center(a_hive.grid_pos)
		var b_pos = _cell_center(b_hive.grid_pos)
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
		var ai = 0
		var bi = 0
		while ai < a_units.size() and bi < b_units.size():
			var a_entry: Dictionary = a_units[ai]
			var b_entry: Dictionary = b_units[bi]
			if float(a_entry["pos"]) >= float(b_entry["pos"]):
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
	var alive_players: Array = _alive_players()
	if alive_players.size() == 1:
		_end_game(alive_players[0], "Elimination")
		return
	if sim_running:
		match_ms_remaining = max(0.0, match_ms_remaining - dt * 1000.0)
	if match_ms_remaining <= overtime_start_ms:
		if not overtime_active:
			_enter_overtime()
		_update_timer_label()
	else:
		if timer_label != null:
			timer_label.visible = false
	if match_ms_remaining <= 0.0:
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
		if a.owner_id == b.owner_id and a.owner_id != 0 and lane.send_a and lane.send_b:
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
	if sel.selected_hive_id != -1:
		var hive: HiveData = _find_hive_by_id(sel.selected_hive_id)
		if hive != null:
			var outgoing_count: int = _active_outgoing_intent_count(hive.id)
			selection_hud.show_hive(hive, outgoing_count)
			return
	if sel.selected_lane_id != -1:
		var lane: LaneData = _find_lane_by_id(sel.selected_lane_id)
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
	selection_hud.clear()

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
	var now_ms: int = int(sim_time_us / 1000)
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

func _update_timer_label() -> void:
	if timer_label == null:
		return
	timer_label.visible = true
	var total_sec: int = int(ceil(match_ms_remaining / 1000.0))
	var minutes: int = int(total_sec / 60.0)
	var seconds: int = total_sec % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

func _update_ops_timer_label() -> void:
	if timer_label == null:
		return
	var phase = OpsState.match_phase
	if phase == OpsState.MatchPhase.PREMATCH:
		var prematch_ms: int = int(OpsState.prematch_remaining_ms)
		if prematch_ms < 0:
			prematch_ms = 0
		var total_sec: int = int(ceil(float(prematch_ms) / 1000.0))
		var minutes: int = int(total_sec / 60.0)
		var seconds: int = total_sec % 60
		timer_label.visible = true
		timer_label.text = "%d:%02d" % [minutes, seconds]
		return
	if phase == OpsState.MatchPhase.RUNNING:
		if not OpsState.timer_visible_started:
			timer_label.visible = false
			return
		var match_ms: int = int(OpsState.match_remaining_ms)
		if match_ms < 0:
			match_ms = 0
		var total_sec: int = int(ceil(float(match_ms) / 1000.0))
		var minutes: int = int(total_sec / 60.0)
		var seconds: int = total_sec % 60
		timer_label.visible = true
		timer_label.text = "%d:%02d" % [minutes, seconds]
		return
	timer_label.visible = false

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
	sim_running = false
	dbg("SF: WINNER pid=%d" % winner_id)
	var winner_label = "none"
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
		outcome_overlay.show_outcome(winner_id, reason, active_player_id)

func _update_towers(dt: float) -> void:
	var dt_ms: float = dt * 1000.0
	for tower in towers:
		if int(tower.get("required_hive_ids", []).size()) < BARRACKS_MIN_REQ:
			tower["active"] = false
			tower["owner_id"] = 0
			tower["tier"] = 1
			tower["shot_accum_ms"] = 0.0
			if state != null:
				var node_id: int = int(tower.get("node_id", tower.get("id", -1)))
				if node_id != -1:
					state.tower_owner_by_node_id[node_id] = 0
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
			if state != null:
				var node_id: int = int(tower.get("node_id", tower.get("id", -1)))
				if node_id != -1:
					state.tower_owner_by_node_id[node_id] = 0
			continue
		tower["active"] = true
		tower["owner_id"] = owner_id
		tower["tier"] = min_tier
		if state != null:
			var node_id: int = int(tower.get("node_id", tower.get("id", -1)))
			if node_id != -1:
				state.tower_owner_by_node_id[node_id] = owner_id
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
	var base = 160.0
	if tier == 1:
		return base
	if tier == 2:
		return base * 1.2
	if tier == 3:
		return base * 1.2 * 1.15
	if tier == 4:
		return base * 1.2 * 1.15 * 1.10
	return base

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
		var prev_active: bool = bool(b.get("active", false))
		var prev_tier: int = int(b.get("tier", 1))
		if int(b.get("required_hive_ids", []).size()) < BARRACKS_MIN_REQ:
			b["active"] = false
			b["owner_id"] = 0
			b["tier"] = 1
			b["spawn_accum_ms"] = 0.0
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
			continue
		b["active"] = true
		b["owner_id"] = owner_id
		b["tier"] = min_tier
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
			var idx: int = int(b["rr_index"]) % targets.size()
			var target_id: int = int(targets[idx])
			b["rr_index"] += 1
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
	var chain: Array = []
	for hive_id_v in barracks_data["required_hive_ids"]:
		var hive_id: int = int(hive_id_v)
		var hive: HiveData = _find_hive_by_id(hive_id)
		if hive != null and hive.owner_id == barracks_data["owner_id"]:
			chain.append(hive_id)
	if chain.is_empty():
		return chain
	var preferred: Array = []
	if barracks_data["preferred_targets"].size() > 0:
		for target_id_v in barracks_data["preferred_targets"]:
			var target_id: int = int(target_id_v)
			if chain.has(target_id):
				preferred.append(target_id)
	if preferred.is_empty():
		return chain
	return preferred

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
	var sum = Vector2.ZERO
	var count = 0
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
	var sum = Vector2.ZERO
	var count = 0
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
	var sum = Vector2.ZERO
	var count = 0
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
	var impact = impact_f
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
	var unit = {
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
	unit_id_counter += 1
	units.append(unit)
	_note_render_dirty()
	SFLog.info("SPAWN_DEBUG lane=%s unit_id=%d owner=%d from=%d to=%d a=%d b=%d dir=%d t0=%.3f spawn_end=%s" % [
		str(unit.get("lane_key", "")),
		int(unit.get("id", -1)),
		int(unit.get("owner_id", 0)),
		int(unit.get("from_id", -1)),
		int(unit.get("to_id", -1)),
		int(unit.get("a_id", -1)),
		int(unit.get("b_id", -1)),
		int(unit.get("dir", 0)),
		clampf(float(unit.get("lane_t", 0.0)), 0.0, 1.0),
		str(unit.get("spawn_end", "?"))
	])
	SFLog.info("UNIT_SPAWN: id=%d lane=%s owner=%d" % [
		int(unit.get("id", -1)),
		str(unit.get("lane_key", "")),
		int(unit.get("owner_id", 0))
	])
	if print_spawn:
		var src_power = -1
		var interval_ms = -1.0
		var from_hive: HiveData = _find_hive_by_id(from_id)
		if from_hive != null:
			src_power = from_hive.power
			interval_ms = _hive_spawn_interval_ms(from_hive)
		var power_text = "NA" if src_power < 0 else str(src_power)
		var interval_text = "NA" if interval_ms < 0.0 else "%.1f" % interval_ms
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
	if hive.owner_id == unit_owner:
		if hive.power < 50:
			hive.power += 1
		elif hive.shock_ms <= 0.0:
			_pass_through(hive, unit_owner)
		return
	if hive.power > 1:
		hive.power -= 1
		return
	hive.owner_id = unit_owner
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

func _update_idle_growth(dt: float) -> void:
	var dt_ms = dt * 1000.0
	for hive in state.hives:
		var prev_power = hive.power
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
	var targets = _get_pass_targets(hive)
	if targets.is_empty():
		return
	var idx: int = hive.pass_rr_index % targets.size()
	var lane_id: int = int(targets[idx]["lane_id"])
	var target_id: int = int(targets[idx]["target_id"])
	hive.pass_rr_index += 1
	var use_preferred = hive.pass_preferred_targets.size() > 0
	if use_preferred:
		dbg("SF: pass-through preferred %d -> %d" % [hive.id, target_id])
	else:
		dbg("SF: pass-through %d forwarded to %d" % [hive.id, target_id])
	_spawn_unit(hive.id, target_id, owner_id, lane_id, false)

func _get_pass_targets(hive: HiveData) -> Array:
	var outgoing = _get_outgoing_intents(hive.id)
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
	var count = 0
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
			if a != null and a.owner_id != 0 and a.owner_id != owner_id:
				return true
		if lane.send_b and lane.a_id == hive_id:
			var b: HiveData = _find_hive_by_id(lane.b_id)
			if b != null and b.owner_id != 0 and b.owner_id != owner_id:
				return true
	return false

func _lane_mode(a: HiveData, b: HiveData) -> String:
	if a.owner_id == 0 or b.owner_id == 0:
		return "neutral"
	if a.owner_id == b.owner_id:
		return "friendly"
	return "opposing"

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
		var target_id = int(target_id_v)
		if _intent_is_on(hive_id, target_id):
			filtered.append(target_id)
	if filtered.size() != order.size():
		hive_lane_order[hive_id] = filtered
	return filtered

func _hive_slot_has_intent(hive_id: int, slot_index: int) -> bool:
	if slot_index <= 0:
		return false
	var order = _hive_lane_order_for(hive_id)
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
		var prev_power = int(hive_power_prev.get(hive.id, hive.power))
		if prev_power >= 25 and hive.power <= 24:
			var order = _hive_lane_order_for(hive.id)
			if order.size() >= 3:
				var target_id = int(order[order.size() - 1])
				_retract_lane(hive.id, target_id, hive.owner_id)
		hive_power_prev[hive.id] = hive.power

func _send_rate(hive: HiveData, is_sending: bool) -> float:
	if not is_sending:
		return 0.0
	if hive.owner_id == 0:
		return 0.0
	var interval_ms = _hive_spawn_interval_ms(hive)
	var interval_sec = interval_ms / 1000.0
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

func _spawn_interval_ms_for_power(power: int) -> float:
	var p: int = max(1, power)
	var value = SPAWN_BASE_MS - (SPAWN_PER_POWER_MS * float(p - 1))
	return maxf(SPAWN_MIN_MS, value)

func _hive_spawn_interval_ms(hive: HiveData) -> float:
	var base: float = _interval_ms(hive.power)
	var pct: float = _buff_mod(hive.owner_id, "hive_prod_time_pct")
	var mult: float = maxf(BUFF_MIN_MULT, 1.0 + pct)
	return maxf(80.0, base * mult)

func _unit_speed_px(owner_id: int, lane_id: int) -> float:
	var speed: float = UNIT_SPEED_PX
	var speed_pct: float = _buff_mod(owner_id, "unit_speed_pct")
	speed *= maxf(BUFF_MIN_MULT, 1.0 + speed_pct)
	var slow_pct: float = _lane_slow_pct_for_unit(owner_id, lane_id)
	if slow_pct > 0.0:
		speed *= maxf(BUFF_MIN_MULT, 1.0 - slow_pct)
	return speed

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
	SFLog.debug_log(2, "HIVE: emitting tapped for hive_id=" + str(hive_id))
	if input_system == null or api == null:
		return
	input_system.handle_tap(hive_id, dev_pid, api)

func _handle_lane_double_tap(local_pos: Vector2, dev_pid: int = -1, pid: int = -1) -> bool:
	if input_system == null or api == null:
		return false
	return input_system.handle_lane_double_tap(local_pos, dev_pid, pid, api)

func _try_swarm(from_id: int, to_id: int, pid: int = -1) -> bool:
	return OpsState.try_swarm(from_id, to_id, pid)

func _project_t_on_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	if ab.length_squared() == 0.0:
		return 0.0
	var t: float = (p - a).dot(ab) / ab.length_squared()
	return clamp(t, 0.0, 1.0)

func _consume_passthrough_payload(from_id: int, owner_id: int) -> int:
	var total = 0
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
	var best_index = -1
	var best_created = -1
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
	return true

func _pass_through_swarm(packet: Dictionary, hive: HiveData) -> bool:
	var targets = _get_pass_targets(hive)
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
	var new_packet = {
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
	if src != null and dst != null and src.owner_id != 0 and src.owner_id == dst.owner_id:
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
	var lane_index = _lane_index_between(attacker_id, target_id)
	if lane_index == -1:
		if not _establish_lane_between(attacker_id, target_id):
			return
		lane_index = _lane_index_between(attacker_id, target_id)
	if lane_index == -1:
		return
	var lane: LaneData = state.lanes[lane_index]
	var key = state.lane_key(lane.a_id, lane.b_id)
	var existing_order: Dictionary = active_orders_by_attacker.get(attacker_id, {})
	if not existing_order.is_empty():
		var existing_key = str(existing_order.get("lane_key", ""))
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
	var length_px = _lane_length_px(a, b)
	var est_speed_px = length_px / (LANE_ESTABLISH_MS / 1000.0)
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
	var lane_index = _lane_index_between(a_id, b_id)
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
			var budget = state.lanes_allowed_for_power(int(from_hive.power))
			var active = state.count_active_outgoing(from_id)
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
		if a.owner_id != 0 and a.owner_id == b.owner_id:
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
			var budget = state.lanes_allowed_for_power(int(from_hive.power))
			var active = state.count_active_outgoing(from_id)
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
		if a.owner_id != b.owner_id:
			continue
		if lane.send_a and lane.send_b:
			if lane.dir == -1:
				lane.send_a = false
				lane.establish_a = false
			else:
				lane.send_b = false
				lane.establish_b = false

func _intent_is_on(from_id: int, to_id: int) -> bool:
	var lane_index = _lane_index_between(from_id, to_id)
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
	var best_id = -1
	var best_dist = HIVE_HIT_RADIUS_PX * HIVE_HIT_RADIUS_PX
	for hive in state.hives:
		var center = _cell_center(hive.grid_pos)
		var dist = center.distance_squared_to(local_pos)
		if dist <= best_dist:
			best_dist = dist
			best_id = hive.id
	return best_id

func _cell_from_point(local_pos: Vector2) -> Vector2i:
	if grid_spec != null:
		return grid_spec.world_to_grid(local_pos)
	var adjusted = local_pos - map_offset
	var cell_px = _cell_px()
	var cx = int(adjusted.x / cell_px)
	var cy = int(adjusted.y / cell_px)
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
