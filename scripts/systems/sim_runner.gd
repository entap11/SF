# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name SimRunner
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const BotSystemScript := preload("res://scripts/systems/bot_system.gd")

signal sim_ticked
signal match_ended(winner_id: int, reason: String)
signal post_match_action(action: String)

const MAX_FRAME_DT := 0.25
const TICK_DT := 0.1
const HITCH_MULT: float = 2.0
const HITCH_PAD_MS: int = 25
const MAX_STEPS_PER_FRAME := 8
const STATS_INTERVAL_MS := 200
const TIMEOUT_CONTESTABLE_KIND := {
	"hive": true,
	"mediumhive": true,
	"largehive": true
}
const OT_CHECK_SEC := 5
const OT_EXTENSION_MS := 60000
const OT_DELTA_THRESHOLD := 0.05
const TIMER_REVEAL_MS := 59000

var state_ref: GameState = null
var bound_iid: int = 0
var running := false
var autostart := false
@export var autostart_on_bind: bool = true
@export var debug_sim_tick_log: bool = false
@export var debug_simrunner_alive: bool = false

var lane_system: LaneSystem = null
var unit_system: UnitSystem = null
var edge_cache_system: EdgeCacheSystem = null
var structure_control_system: StructureControlSystem = null
var tower_system: TowerSystem = null
var swarm_system: SwarmSystem = null
var barracks_system: BarracksSystem = null
var win_system: WinSystem = null
var bot_system: Node = null

var _tick_accum := 0.0
var _pending_start := false
var _match_end_emitted := false
var _post_action_emitted := ""
var _last_stats_ms: int = 0
var _last_phase_log_ms: int = 0
var _match_over := false
var _end_sequence_started := false
var _end_sequence_winner_id := 0
var _had_player_control_during_match: bool = false
var _had_multiple_teams_during_match: bool = false
var _last_pause_snapshot_sig: String = ""
var _last_pause_snapshot: Dictionary = {}
var _bound_tower_nodes: Array = []
var _bind_structures_scheduled: bool = false
var _last_tick_us: int = 0
var _hb_last_ms: int = 0
var _hb_max_tick_ms: float = 0.0
var _hb_ticks: int = 0
var _last_win_tick_warn_ms: int = 0
var _last_win_tick_sig: String = ""

func _ready() -> void:
	set_process(true)
	set_physics_process(true)
	set_process_unhandled_input(true)
	SFLog.allow_tag("SIM_HITCH")
	SFLog.allow_tag("SIM_HEARTBEAT")
	SFLog.allow_tag("EDGE_CACHE_REBUILT")
	SFLog.allow_tag("UNIT_LANE_CAP_BLOCK")
	SFLog.allow_tag("LANE_CAP_BLOCK")
	SFLog.allow_tag("WIN_FALLBACK_LIVE_SINGLE_ALIVE")
	SFLog.allow_tag("WIN_FALLBACK_LIVE_NO_PLAYER_HIVES")
	SFLog.allow_tag("WIN_FALLBACK_DIRECT_SINGLE_ALIVE")
	SFLog.allow_tag("WIN_FALLBACK_DIRECT_NO_PLAYER_HIVES")
	SFLog.allow_tag("WIN_TICK_SNAPSHOT")
	SFLog.allow_tag("WIN_DECLARED")
	SFLog.allow_tag("MATCH_ENDED_EMIT")
	SFLog.allow_tag("BOT_INTENT")
	if debug_sim_tick_log:
		SFLog.allow_tag("SIM_TICK")
		SFLog.allow_tag("SIM_TICK_COST")
		SFLog.allow_tag("SIM_TICK_PHASE")
		SFLog.allow_tag("UNIT_ARRIVED")
	_ensure_systems()
	_schedule_bind_structures("ready")
	# Arena binds the authoritative OpsState-owned GameState via bind_state().

func _ensure_systems() -> void:
	if lane_system == null:
		lane_system = LaneSystem.new()
		add_child(lane_system)
	if unit_system == null:
		unit_system = UnitSystem.new()
	if edge_cache_system == null:
		edge_cache_system = EdgeCacheSystem.new()
		add_child(edge_cache_system)
	if structure_control_system == null:
		structure_control_system = StructureControlSystem.new()
		add_child(structure_control_system)
	if tower_system == null:
		tower_system = TowerSystem.new()
		add_child(tower_system)
	if swarm_system == null:
		swarm_system = SwarmSystem.new()
	if barracks_system == null:
		barracks_system = BarracksSystem.new()
		add_child(barracks_system)
	if win_system == null:
		win_system = WinSystem.new()
		win_system.debug_log = debug_sim_tick_log
		add_child(win_system)
	elif win_system != null:
		win_system.debug_log = debug_sim_tick_log
	if bot_system == null:
		bot_system = BotSystemScript.new()
		add_child(bot_system)

func _caller_hint() -> String:
	var stack: Array = get_stack()
	for i in range(2, stack.size()):
		var frame: Dictionary = stack[i]
		var src: String = str(frame.get("source", ""))
		if src == "":
			continue
		if not src.ends_with("sim_runner.gd"):
			var func_name: String = str(frame.get("function", ""))
			var line: int = int(frame.get("line", 0))
			return "%s:%s:%d" % [src, func_name, line]
	return ""

func _log_run_state_change(reason: String, prev_running: bool, next_running: bool) -> void:
	var tree_paused := false
	var scene_name := ""
	var tree := get_tree()
	if tree != null:
		tree_paused = bool(tree.paused)
		var current_scene := tree.current_scene
		if current_scene != null:
			scene_name = str(current_scene.name)
	var caller := _caller_hint()
	SFLog.info("SIM_RUN_STATE", {
		"reason": reason,
		"caller": caller,
		"running_before": prev_running,
		"running_after": next_running,
		"paused_before": not prev_running,
		"paused_after": not next_running,
		"tree_paused": tree_paused,
		"process_mode": int(process_mode),
		"scene": scene_name
	})
	log_pause_snapshot("sim_run_state_change")

func _set_running(value: bool, reason: String) -> void:
	if running == value:
		return
	var prev_running: bool = running
	running = value
	if not running:
		_last_tick_us = 0
	_hb_last_ms = 0
	_hb_max_tick_ms = 0.0
	_hb_ticks = 0
	_last_win_tick_warn_ms = 0
	_last_win_tick_sig = ""
	_log_run_state_change(reason, prev_running, running)
	_sync_match_clock_pause()

func _sync_match_clock_pause() -> void:
	if state_ref == null:
		return
	if not bool(OpsState.match_clock_started):
		return
	if not OpsState.is_running():
		return
	OpsState.match_clock_running = running
	SFLog.info("CLOCK_PAUSE", {"paused": not running})

func get_lane_system() -> LaneSystem:
	_ensure_systems()
	return lane_system

func get_unit_system() -> UnitSystem:
	_ensure_systems()
	return unit_system

func get_tower_system() -> TowerSystem:
	_ensure_systems()
	return tower_system

func get_structure_control_system() -> StructureControlSystem:
	_ensure_systems()
	return structure_control_system

func get_barracks_system() -> BarracksSystem:
	_ensure_systems()
	return barracks_system

func set_running(value: bool, reason: String = "set_running") -> void:
	if value:
		_pending_start = true
		_start_if_ready(reason)
		return
	_set_running(false, reason)
	_pending_start = false

func start_sim() -> void:
	_pending_start = true
	_tick_accum = 0.0
	_set_running(true, "start_sim")
	SFLog.info("SIM_START_MANUAL", {"iid": int(bound_iid)})
	_start_if_ready()

func start() -> void:
	_pending_start = true
	_tick_accum = 0.0
	if state_ref == null:
		_set_running(false, "start_no_state")
		return
	_set_running(true, "start")
	SFLog.info("SIM_START", {"iid": int(bound_iid), "autostart": true})
	_start_if_ready()

func _on_state_changed(new_state: GameState) -> void:
	if new_state == null:
		return
	var iid: int = int(_state_iid(new_state))
	if iid == bound_iid:
		return
	state_ref = new_state
	bound_iid = iid
	_match_end_emitted = false
	_post_action_emitted = ""
	_last_stats_ms = 0
	_tick_accum = 0.0
	_match_over = false
	_end_sequence_started = false
	_end_sequence_winner_id = 0
	_had_player_control_during_match = false
	_had_multiple_teams_during_match = false
	_set_running(false, "state_changed")
	_pending_start = autostart_on_bind
	if lane_system != null and lane_system.state != state_ref:
		lane_system.bind_state(state_ref)
	if unit_system != null:
		unit_system.bind_state(state_ref)
		unit_system.use_lane_system_spawns = true
		unit_system.win_system = win_system
	if structure_control_system != null:
		structure_control_system.bind_state(state_ref)
	if tower_system != null:
		tower_system.bind_state(state_ref)
		call_deferred("_bind_world_towers_deferred", bound_iid)
		_schedule_bind_structures("state_changed")
	if swarm_system != null:
		swarm_system.bind_state(state_ref)
	if barracks_system != null:
		barracks_system.bind_state(state_ref)
		if tower_system != null:
			barracks_system.set_structure_selector(tower_system)
	if win_system != null:
		win_system.bind_state(state_ref, OpsState)
		win_system.debug_log = debug_sim_tick_log
	if bot_system != null and bot_system.has_method("bind_state"):
		bot_system.call("bind_state", state_ref)
	if edge_cache_system != null:
		edge_cache_system.rebuild_edge_cache(OpsState)
	SFLog.info("SIM_BIND_STATE", {"iid": bound_iid})
	if autostart_on_bind:
		_start_if_ready("bind_state_autostart")

func _schedule_bind_structures(reason: String) -> void:
	if _bind_structures_scheduled:
		return
	_bind_structures_scheduled = true
	call_deferred("_bind_structures", reason, 1)

func _bind_structures(reason: String, attempt: int) -> void:
	_bind_structures_scheduled = false
	var result: Dictionary = _find_tower_nodes()
	var towers: Array = result.get("nodes", [])
	_bound_tower_nodes = towers
	var sample_paths: Array = []
	var limit: int = mini(3, towers.size())
	for i in range(limit):
		var node: Node = towers[i] as Node
		if node != null:
			sample_paths.append(str(node.get_path()))
	var state_towers: int = state_ref.towers.size() if state_ref != null else 0
	SFLog.info("TOWER_BIND_STATE", {
		"iid": bound_iid,
		"reason": reason,
		"attempt": attempt,
		"towers_count": towers.size(),
		"state_towers": state_towers,
		"group_count": int(result.get("group_count", 0)),
		"fallback_used": bool(result.get("fallback_used", false)),
		"map_root": str(result.get("map_root_path", "")),
		"sample_paths": sample_paths
	})
	if towers.is_empty():
		if attempt < 2:
			call_deferred("_bind_structures_retry", reason, attempt + 1)
		else:
			SFLog.warn("TOWER_BIND_EMPTY", {
				"iid": bound_iid,
				"reason": reason,
				"attempt": attempt,
				"state_towers": state_towers
			})

func _bind_structures_retry(reason: String, attempt: int) -> void:
	await get_tree().process_frame
	_bind_structures(reason, attempt)

func _find_tower_nodes() -> Dictionary:
	var group_nodes: Array = []
	if get_tree() != null:
		group_nodes = get_tree().get_nodes_in_group("sf_tower")
	var group_count: int = group_nodes.size()
	var towers: Array = []
	var fallback_used: bool = false
	var map_root_path: String = ""
	if group_count > 0:
		towers = group_nodes
	else:
		fallback_used = true
		var map_root: Node = _find_map_root()
		if map_root != null:
			map_root_path = str(map_root.get_path())
			var candidates: Array = map_root.find_children("*", "", true, false)
			for n_any in candidates:
				var n: Node = n_any as Node
				if n != null and (n.is_in_group("sf_tower") or n.is_in_group("map_tower")):
					towers.append(n)
	return {
		"nodes": towers,
		"group_count": group_count,
		"fallback_used": fallback_used,
		"map_root_path": map_root_path
	}

func _find_map_root() -> Node:
	var n: Node = get_parent()
	while n != null:
		var map_root: Node = n.get_node_or_null("MapRoot")
		if map_root != null:
			return map_root
		n = n.get_parent()
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null:
		return scene.find_child("MapRoot", true, false)
	return null

func bind_state(new_state: GameState) -> void:
	_on_state_changed(new_state)

func _bind_world_towers_deferred(expected_iid: int) -> void:
	SFLog.info("TOWER_WORLD_BIND_DEFERRED_START", {"iid": int(bound_iid)})
	await get_tree().process_frame
	await get_tree().process_frame
	if expected_iid != bound_iid:
		return
	if tower_system == null:
		return
	var group_nodes: Array = get_tree().get_nodes_in_group("sf_tower")
	var tower_nodes: Array[Node2D] = []
	for n in group_nodes:
		var n2d: Node2D = n as Node2D
		if n2d != null:
			tower_nodes.append(n2d)
	tower_system.bind_world_towers(tower_nodes)
	SFLog.info("TOWER_WORLD_BIND", {
		"iid": int(bound_iid),
		"found": tower_nodes.size()
	})

func _start_if_ready(reason: String = "start_if_ready") -> void:
	SFLog.info("SIM_START_CHECK", {
		"iid": int(bound_iid),
		"running": running,
		"pending": _pending_start,
		"has_state": state_ref != null,
		"has_lane_system": lane_system != null,
		"has_unit_system": unit_system != null
	})
	if state_ref == null:
		return
	if running:
		_pending_start = false
		return
	SFLog.info("SIM_SYSTEMS", {
		"tower": tower_system != null,
		"unit": unit_system != null,
		"lane": lane_system != null,
		"swarm": swarm_system != null,
		"barracks": barracks_system != null,
		"structure_control": structure_control_system != null,
		"win": win_system != null
	})
	_set_running(true, reason)
	_pending_start = false
	_tick_accum = 0.0
	var mode := "dev" if get_node_or_null("/root/DevMapRunner") != null else "match"
	SFLog.info("SIM_START", {"iid": bound_iid, "mode": mode, "autostart": autostart})

func _process(delta: float) -> void:
	var is_paused := not running
	if debug_simrunner_alive and Engine.get_frames_drawn() % 120 == 0:
		SFLog.info("SIMRUNNER_ALIVE", {"running": running, "paused": is_paused})
	var sim_delta := minf(delta, MAX_FRAME_DT)
	if state_ref == null or is_paused:
		return
	_tick_accum += sim_delta
	var steps := 0
	while _tick_accum >= TICK_DT and steps < MAX_STEPS_PER_FRAME:
		_tick(TICK_DT)
		_tick_accum -= TICK_DT
		steps += 1
	if steps > 0:
		emit_signal("sim_ticked")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		SFLog.info("SIM_START_HOTKEY", {})
		start_sim()

func _tick(dt: float) -> void:
	if state_ref == null:
		return
	var tick_t0_us: int = Time.get_ticks_usec()
	_log_sim_tick()
	var now_ms: int = Time.get_ticks_msec()
	var phase: int = OpsState.match_phase
	if phase == OpsState.MatchPhase.ENDED:
		OpsState.enforce_post_match_authority("SimRunner._tick:ENDED")
		_log_match_phase(now_ms)
		_log_tick_phase()
		_tick_post_match_ghost(dt, true)
		OpsState.expire_rematch_if_needed()
		_emit_match_end_if_needed()
		_emit_post_match_action_if_needed()
		_finalize_tick_profile(tick_t0_us)
		return
	if phase == OpsState.MatchPhase.ENDING:
		OpsState.enforce_post_match_authority("SimRunner._tick:ENDING")
		_log_match_phase(now_ms)
		_log_tick_phase()
		_tick_post_match_ghost(dt, true)
		if now_ms >= int(OpsState.end_screen_ready_ms):
			SFLog.info("MATCH_END_FINALIZE", {
				"winner": int(OpsState.winner_id),
				"reason": str(OpsState.match_end_reason),
				"phase": int(OpsState.match_phase)
			})
			OpsState.finalize_match_end()
		if OpsState.match_phase == OpsState.MatchPhase.ENDED:
			_emit_match_end_if_needed()
			_emit_post_match_action_if_needed()
		_finalize_tick_profile(tick_t0_us)
		return
	_tick_systems(dt)
	_update_match_stats(now_ms)
	_check_match_win(now_ms)
	_finalize_tick_profile(tick_t0_us)

func _tick_systems(dt: float) -> void:
	var dt_ms: int = int(round(dt * 1000.0))
	_timed_phase("ops_events", func() -> void:
		OpsState.tick_match_clock(state_ref, dt_ms)
		state_ref.tick_unintended_power(float(dt_ms))
	)
	_timed_phase("bot_system", func() -> void:
		if bot_system != null and bot_system.has_method("tick"):
			bot_system.call("tick", dt)
	)
	_timed_phase("lane_flow", func() -> void:
		state_ref.tick_lane_flow(dt * 1000.0)
		if lane_system != null:
			lane_system.tick_lane_fronts(dt)
	)
	_timed_phase("edge_cache", func() -> void:
		if edge_cache_system != null:
			edge_cache_system.rebuild_edge_cache(OpsState)
	)
	_timed_phase("unit_system", func() -> void:
		if swarm_system != null:
			swarm_system.tick(dt, unit_system)
		if unit_system != null:
			unit_system.tick(dt)
			unit_system.tick_render_units(dt)
	)
	_timed_phase("tower_system", func() -> void:
		if structure_control_system != null:
			structure_control_system.tick(dt)
		if tower_system != null:
			tower_system.tick(dt, unit_system)
	)
	_timed_phase("barracks_system", func() -> void:
		if barracks_system != null:
			barracks_system.tick(dt)
	)

func _log_sim_tick() -> void:
	var now_us: int = Time.get_ticks_usec()
	if _last_tick_us != 0:
		var dt_us: int = now_us - _last_tick_us
		var expected_us: int = int(round(TICK_DT * 1000000.0))
		var hitch_us: int = int(float(expected_us) * HITCH_MULT) + (HITCH_PAD_MS * 1000)
		if dt_us >= hitch_us:
			SFLog.warn("SIM_HITCH", {
				"dt_ms": int(dt_us / 1000),
				"dt_us": dt_us,
				"expected_ms": int(expected_us / 1000),
				"frame": Engine.get_process_frames(),
				"physics": Engine.get_physics_frames()
			})
	_last_tick_us = now_us
	if debug_sim_tick_log:
		SFLog.info("SIM_TICK", {
			"frame": Engine.get_process_frames(),
			"physics": Engine.get_physics_frames()
		})

func _finalize_tick_profile(tick_t0_us: int) -> void:
	var tick_ms: float = float(Time.get_ticks_usec() - tick_t0_us) / 1000.0
	if debug_sim_tick_log and tick_ms >= 5.0:
		SFLog.warn("SIM_TICK_COST", {"dt_ms": snapped(tick_ms, 0.1)})
	var now_ms: int = Time.get_ticks_msec()
	if _hb_last_ms == 0:
		_hb_last_ms = now_ms
	_hb_ticks += 1
	if tick_ms > _hb_max_tick_ms:
		_hb_max_tick_ms = tick_ms
	if now_ms - _hb_last_ms >= 1000:
		SFLog.info("SIM_HEARTBEAT", {
			"ticks": _hb_ticks,
			"max_tick_ms": snapped(_hb_max_tick_ms, 0.1)
		})
		_hb_last_ms = now_ms
		_hb_max_tick_ms = 0.0
		_hb_ticks = 0

func _timed_phase(label: String, f: Callable) -> void:
	var t0: int = Time.get_ticks_usec()
	f.call()
	var dt_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	if debug_sim_tick_log and dt_ms >= 3.0:
		SFLog.warn("SIM_TICK_PHASE", {"phase": label, "dt_ms": snapped(dt_ms, 0.1)})

func _tick_units_only(dt: float) -> void:
	if unit_system != null:
		unit_system.tick(dt)
		unit_system.tick_render_units(dt)

func _tick_post_match_ghost(dt: float, update_stats: bool) -> void:
	if state_ref == null:
		return
	var dt_ms: int = int(round(dt * 1000.0))
	_timed_phase("ghost_ops_events", func() -> void:
		# Keep passive hive growth alive post-match while input remains locked.
		state_ref.tick_unintended_power(float(dt_ms))
	)
	_timed_phase("ghost_lane_flow", func() -> void:
		state_ref.tick_lane_flow(dt * 1000.0)
	)
	_timed_phase("ghost_unit_system", func() -> void:
		if swarm_system != null:
			swarm_system.tick(dt, unit_system)
		if unit_system != null:
			unit_system.tick(dt)
			unit_system.tick_render_units(dt)
	)
	if update_stats:
		_update_match_stats(Time.get_ticks_msec())

func _log_tick_phase() -> void:
	return

func _update_match_stats(now_ms: int) -> void:
	if now_ms - _last_stats_ms < STATS_INTERVAL_MS:
		return
	_last_stats_ms = now_ms
	if state_ref == null:
		return
	var totals_by_team: Dictionary = {}
	var totals_by_seat: Dictionary = {}
	for h in state_ref.hives:
		if h == null:
			continue
		var owner_id: int = int(h.owner_id)
		if owner_id <= 0:
			continue
		totals_by_seat[owner_id] = int(totals_by_seat.get(owner_id, 0)) + int(h.power)
		var team_id: int = _team_for_owner(owner_id)
		if team_id <= 0:
			continue
		totals_by_team[team_id] = int(totals_by_team.get(team_id, 0)) + int(h.power)
	for team_id_any in totals_by_team.keys():
		var team_id: int = int(team_id_any)
		OpsState.update_team_max_power(team_id, int(totals_by_team.get(team_id, 0)))
	var active_seats: Array = []
	var roster: Array = OpsState.match_roster
	if roster != null:
		for entry_any in roster:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			var seat: int = int(entry.get("seat", 0))
			if seat <= 0 or seat > 4:
				continue
			var active: bool = false
			if entry.has("active"):
				active = bool(entry.get("active", false))
			else:
				var uid: String = str(entry.get("uid", ""))
				var is_cpu: bool = bool(entry.get("is_cpu", false))
				active = not uid.is_empty() or is_cpu
			if active and not active_seats.has(seat):
				active_seats.append(seat)
	if active_seats.is_empty():
		active_seats = [1, 2]
	active_seats.sort()
	var visible_seats: int = clamp(active_seats.size(), 2, 4)
	var hud: Dictionary = {
		1: {"power": int(totals_by_seat.get(1, 0))},
		2: {"power": int(totals_by_seat.get(2, 0))},
		3: {"power": int(totals_by_seat.get(3, 0))},
		4: {"power": int(totals_by_seat.get(4, 0))},
		"visible_seats": visible_seats,
		"active_seats": active_seats
	}
	OpsState.update_hud_snapshot(hud)
	SFLog.log_once("M4_STATS_ACTIVE", "M4_MATCH_STATS_ACTIVE", SFLog.Level.INFO)

func _check_match_win(now_ms: int) -> void:
	if state_ref == null or win_system == null:
		return
	if OpsState.match_phase != OpsState.MatchPhase.RUNNING:
		return
	if _match_over:
		return
	var remaining_ms := _get_match_remaining_ms()
	if OpsState.match_clock_started and not OpsState.timer_visible_started and remaining_ms <= TIMER_REVEAL_MS:
		OpsState.timer_visible_started = true
		SFLog.info("TIMER_VISIBLE", {
			"remaining_ms": remaining_ms,
			"ops_iid": int(OpsState.get_instance_id())
		})
	if OpsState.match_clock_started and not OpsState.ot_checked and remaining_ms <= OT_CHECK_SEC * 1000 and remaining_ms > 0:
		var snapshot: Dictionary = _build_timeout_snapshot()
		var owned: Dictionary = snapshot.get("owned_by_team", {})
		var contestable_total: int = int(snapshot.get("contestable_total", 0))
		var top_counts: Array = _top_two_counts(owned)
		var owned1: int = int(top_counts[0])
		var owned2: int = int(top_counts[1])
		var denom: float = float(max(contestable_total, 1))
		var delta: float = absf(float(owned1 - owned2)) / denom
		if delta <= OT_DELTA_THRESHOLD and not OpsState.in_overtime:
			_trigger_overtime(snapshot, remaining_ms, delta)
		else:
			SFLog.info("OT_NO_TRIGGER", {
				"remaining_ms_at_trigger": remaining_ms,
				"delta": delta
			})
		OpsState.ot_checked = true
	var deadline_elapsed: bool = bool(OpsState.match_clock_started) and int(OpsState.match_deadline_ms) > 0 and now_ms >= int(OpsState.match_deadline_ms)
	if OpsState.match_clock_started and (remaining_ms <= 0 or deadline_elapsed):
		SFLog.info("MATCH_TIMER_EXPIRED", {
			"remaining_ms": remaining_ms,
			"deadline_elapsed": deadline_elapsed,
			"deadline_ms": int(OpsState.match_deadline_ms),
			"now_ms": now_ms
		})
		var snapshot: Dictionary = _build_timeout_snapshot()
		var owned: Dictionary = snapshot.get("owned_by_team", {})
		var contestable_total: int = int(snapshot.get("contestable_total", 0))
		var winner_id: int = _resolve_time_winner(owned)
		var owned1: int = int(owned.get(1, 0))
		var owned2: int = int(owned.get(2, 0))
		_declare_time_win(winner_id, owned1, owned2, contestable_total)
		return
	var live_snapshot: Dictionary = _build_timeout_snapshot()
	var live_owned: Dictionary = Dictionary(live_snapshot.get("owned_by_team", {}))
	var live_alive_teams: Array = _alive_teams_from_owned_counts(live_owned)
	var direct_snapshot: Dictionary = _build_direct_live_snapshot()
	var direct_owned: Dictionary = Dictionary(direct_snapshot.get("owned_by_team", {}))
	var direct_alive_teams: Array = _alive_teams_from_owned_counts(direct_owned)
	if direct_alive_teams.size() >= 2:
		_had_multiple_teams_during_match = true
	if not direct_alive_teams.is_empty():
		_had_player_control_during_match = true
	_log_win_tick_snapshot(now_ms, live_snapshot, direct_snapshot)
	var result: Variant = win_system.tick(state_ref, now_ms)
	if result != null:
		var winner_id := int(result.get("winner_id", 0))
		if winner_id > 0:
			var reason := str(result.get("reason", "conquest"))
			_declare_conquest_win(winner_id, reason)
			return
	var contestable_total_live: int = int(live_snapshot.get("contestable_total", 0))
	if _had_multiple_teams_during_match and contestable_total_live > 0 and live_alive_teams.size() == 1:
		var fallback_winner: int = int(live_alive_teams[0])
		SFLog.warn("WIN_FALLBACK_LIVE_SINGLE_ALIVE", {
			"winner_id": fallback_winner,
			"contestable_total": contestable_total_live,
			"owned_by_team": live_owned
		})
		_declare_conquest_win(fallback_winner, "conquest")
		return
	if _had_multiple_teams_during_match and contestable_total_live > 0 and live_alive_teams.is_empty() and _had_player_control_during_match:
		SFLog.warn("WIN_FALLBACK_LIVE_NO_PLAYER_HIVES", {
			"contestable_total": contestable_total_live,
			"owned_by_team": live_owned
		})
		_declare_conquest_draw("domination_draw")
		return
	if _had_multiple_teams_during_match and direct_alive_teams.size() == 1:
		var direct_winner: int = int(direct_alive_teams[0])
		SFLog.warn("WIN_FALLBACK_DIRECT_SINGLE_ALIVE", {
			"winner_id": direct_winner,
			"owned_by_team": direct_owned
		})
		_declare_conquest_win(direct_winner, "conquest")
		return
	if _had_multiple_teams_during_match and direct_alive_teams.is_empty() and _had_player_control_during_match:
		SFLog.warn("WIN_FALLBACK_DIRECT_NO_PLAYER_HIVES", {
			"owned_by_team": direct_owned
		})
		_declare_conquest_draw("domination_draw")
		return

func _declare_conquest_win(winner_id: int, reason: String) -> void:
	if winner_id <= 0:
		return
	var remaining_ms := int(OpsState.match_duration_ms - OpsState.match_elapsed_ms)
	if remaining_ms < 0:
		remaining_ms = 0
	SFLog.warn("WIN_DECLARED", {
		"winner_id": winner_id,
		"reason": reason,
		"iid": int(state_ref.get_instance_id()),
		"time_remaining_ms": remaining_ms
	})
	log_pause_snapshot("win_declared")
	_match_over = true
	SFLog.info("WINNER_CONFIRMED", {"winner_id": winner_id, "reason": reason})
	OpsState.begin_match_end(winner_id, reason, OpsState.ending_linger_ms)
	_start_end_sequence(winner_id)

func _declare_conquest_draw(reason: String) -> void:
	var remaining_ms := int(OpsState.match_duration_ms - OpsState.match_elapsed_ms)
	if remaining_ms < 0:
		remaining_ms = 0
	SFLog.warn("WIN_DECLARED", {
		"winner_id": 0,
		"reason": reason,
		"iid": int(state_ref.get_instance_id()),
		"time_remaining_ms": remaining_ms
	})
	log_pause_snapshot("win_declared_draw")
	_match_over = true
	SFLog.info("WINNER_CONFIRMED", {"winner_id": 0, "reason": reason})
	OpsState.begin_match_end(0, reason, OpsState.ending_linger_ms)
	_start_end_sequence(0)

func _alive_teams_from_owned_counts(owned_by_team: Dictionary) -> Array:
	var alive: Array = []
	var team_ids: Array = owned_by_team.keys()
	team_ids.sort()
	for team_any in team_ids:
		var team_id: int = int(team_any)
		if int(owned_by_team.get(team_id, 0)) <= 0:
			continue
		if not alive.has(team_id):
			alive.append(team_id)
	return alive

func _get_match_remaining_ms() -> int:
	if OpsState.match_clock_started:
		var remaining_ms := int(OpsState.match_remaining_ms)
		if remaining_ms > 0:
			return remaining_ms
		remaining_ms = int(OpsState.match_duration_ms - OpsState.match_elapsed_ms)
		if remaining_ms < 0:
			remaining_ms = 0
		return remaining_ms
	return int(OpsState.match_duration_ms)

func _build_timeout_snapshot() -> Dictionary:
	var contestable_total := 0
	var owned_by_team: Dictionary = _empty_team_owned_counts()
	var hives: Array = []
	var hives_by_id: Dictionary = state_ref.hive_by_id if state_ref != null else {}
	if hives_by_id.size() > 0:
		hives = hives_by_id.values()
	else:
		hives = state_ref.hives
	for h in hives:
		if h == null:
			continue
		var kind_norm := _normalized_hive_kind(_hive_kind(h))
		if not TIMEOUT_CONTESTABLE_KIND.has(kind_norm):
			continue
		if _is_npc_hive(h, kind_norm):
			continue
		contestable_total += 1
		var owner_id: int = _hive_owner_id(h)
		if owner_id <= 0:
			continue
		var team_id: int = _team_for_owner(owner_id)
		if team_id <= 0:
			continue
		owned_by_team[team_id] = int(owned_by_team.get(team_id, 0)) + 1
	return {
		"contestable_total": contestable_total,
		"owned_by_team": owned_by_team
	}

func _trigger_overtime(snapshot: Dictionary, remaining_ms: int, delta: float) -> void:
	var owned: Dictionary = Dictionary(snapshot.get("owned_by_team", {}))
	var contestable_total: int = int(snapshot.get("contestable_total", 0))
	var top_counts: Array = _top_two_counts(owned)
	var owned1: int = int(top_counts[0])
	var owned2: int = int(top_counts[1])
	OpsState.in_overtime = true
	OpsState.ot_checked = true
	OpsState.match_duration_ms += OT_EXTENSION_MS
	var now_ms := Time.get_ticks_msec()
	if OpsState.match_deadline_ms > 0:
		OpsState.match_deadline_ms += OT_EXTENSION_MS
	else:
		OpsState.match_deadline_ms = now_ms + max(0, OpsState.match_duration_ms - OpsState.match_elapsed_ms)
	OpsState.match_time_remaining_ms = max(0, OpsState.match_deadline_ms - now_ms)
	OpsState.match_time_remaining_sec = float(OpsState.match_time_remaining_ms) / 1000.0
	OpsState.match_remaining_ms = OpsState.match_time_remaining_ms
	SFLog.info("OT_TRIGGER", {
		"remaining_ms_at_trigger": remaining_ms,
		"delta": delta,
		"extend_ms": OT_EXTENSION_MS,
		"new_remaining_ms": OpsState.match_time_remaining_ms,
		"owned1": owned1,
		"owned2": owned2,
		"contestable_total": contestable_total
	})

func _declare_time_win(winner_id: int, owned1: int, owned2: int, contestable_total: int) -> void:
	SFLog.warn("WIN_DECLARED", {
		"winner_id": winner_id,
		"reason": "time",
		"owned1": owned1,
		"owned2": owned2,
		"contestable_total": contestable_total
	})
	log_pause_snapshot("win_declared_time")
	_match_over = true
	SFLog.info("WINNER_CONFIRMED", {"winner_id": winner_id, "reason": "time"})
	OpsState.begin_match_end(winner_id, "time", OpsState.ending_linger_ms)
	_start_end_sequence(winner_id)

func _resolve_time_winner(owned_by_team: Dictionary) -> int:
	var best_id := 0
	var best_count := -1
	var tie := false
	var team_ids: Array = owned_by_team.keys()
	team_ids.sort()
	for team_any in team_ids:
		var team_id: int = int(team_any)
		var count := int(owned_by_team.get(team_id, 0))
		if count > best_count:
			best_count = count
			best_id = team_id
			tie = false
		elif count == best_count:
			tie = true
	return 0 if tie else best_id

func _top_two_counts(owned_by_team: Dictionary) -> Array:
	var counts := []
	for team_any in owned_by_team.keys():
		var team_id: int = int(team_any)
		counts.append(int(owned_by_team.get(team_id, 0)))
	counts.sort()
	counts.reverse()
	var first: int = (counts[0] if counts.size() > 0 else 0)
	var second: int = (counts[1] if counts.size() > 1 else 0)
	return [first, second]

func _seeded_timeout_coin_flip() -> int:
	var seed := int(state_ref.get_instance_id()) if state_ref != null else 0
	if seed == 0:
		seed = int(OpsState.match_duration_ms)
	return 1 if int(abs(seed)) % 2 == 0 else 2

func _hive_kind(hv: Variant) -> String:
	if typeof(hv) == TYPE_DICTIONARY:
		var hd: Dictionary = hv
		return str(hd.get("kind", ""))
	return str(hv.kind)

func _hive_owner_id(hv: Variant) -> int:
	if typeof(hv) == TYPE_DICTIONARY:
		var hd: Dictionary = hv
		return int(hd.get("owner_id", 0))
	return int(hv.owner_id)

func _normalized_hive_kind(kind: String) -> String:
	var key := kind.strip_edges().to_lower()
	key = key.replace("_", "")
	if key == "playerhive":
		return "hive"
	return key

func _is_npc_hive(hv: Variant, kind_norm: String) -> bool:
	if kind_norm == "npc" or kind_norm == "npchive":
		return true
	if typeof(hv) == TYPE_DICTIONARY:
		var hd: Dictionary = hv
		if bool(hd.get("is_npc", false)):
			return true
		var owner_str := str(hd.get("owner", "")).strip_edges().to_lower()
		if owner_str == "npc":
			return true
	return false

func _start_end_sequence(winner_id: int) -> void:
	if _end_sequence_started:
		return
	_end_sequence_started = true
	_end_sequence_winner_id = winner_id
	# Deterministic path: ENDING->ENDED transition is finalized in _tick().
	SFLog.info("MATCH_END_SEQUENCE_START", {
		"winner": winner_id,
		"phase": int(OpsState.match_phase),
		"linger_ms": int(OpsState.ending_linger_ms)
	})

func _log_match_phase(now_ms: int) -> void:
	const PHASE_LOG_INTERVAL_MS := 500
	if now_ms - _last_phase_log_ms < PHASE_LOG_INTERVAL_MS:
		return
	_last_phase_log_ms = now_ms
	var dt_ms := 0
	if OpsState.ending_started_ms > 0:
		dt_ms = now_ms - int(OpsState.ending_started_ms)
	SFLog.info("MATCH_PHASE", {
		"phase": int(OpsState.match_phase),
		"winner": int(OpsState.winner_id),
		"t": dt_ms
	})

func _state_iid(st: GameState) -> int:
	return int(st.get_instance_id())

func _emit_match_end_if_needed() -> void:
	if state_ref == null:
		return
	if _match_end_emitted:
		return
	if OpsState.match_phase != OpsState.MatchPhase.ENDED:
		return
	_match_end_emitted = true
	var winner_id := int(OpsState.winner_id)
	var reason := str(OpsState.match_end_reason)
	SFLog.info("SIM_MATCH_ENDED", {
		"winner_id": winner_id,
		"reason": reason,
		"iid": int(state_ref.get_instance_id())
	})
	SFLog.warn("MATCH_ENDED_EMIT", {"winner_id": winner_id, "reason": reason})
	emit_signal("match_ended", winner_id, reason)

func _build_direct_live_snapshot() -> Dictionary:
	var owned_by_team: Dictionary = _empty_team_owned_counts()
	var hives: Array = []
	var hives_by_id: Dictionary = state_ref.hive_by_id if state_ref != null else {}
	if hives_by_id.size() > 0:
		hives = hives_by_id.values()
	else:
		hives = state_ref.hives
	for h in hives:
		if h == null:
			continue
		var owner_id: int = _hive_owner_id(h)
		if owner_id <= 0:
			continue
		var team_id: int = _team_for_owner(owner_id)
		if team_id <= 0:
			continue
		owned_by_team[team_id] = int(owned_by_team.get(team_id, 0)) + 1
	return {"owned_by_team": owned_by_team}

func _team_for_owner(owner_id: int) -> int:
	var seat_id: int = int(owner_id)
	if seat_id < 1 or seat_id > 4:
		return 0
	var team_id: int = seat_id
	if OpsState.has_method("get_team_for_seat"):
		team_id = int(OpsState.call("get_team_for_seat", seat_id))
	if team_id <= 0:
		return seat_id
	return team_id

func _all_team_ids_from_roster() -> Array:
	var team_ids: Array = []
	var roster: Array = OpsState.match_roster
	if roster != null:
		for entry_any in roster:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			var seat_id: int = int(entry.get("seat", 0))
			if seat_id < 1 or seat_id > 4:
				continue
			var active: bool = bool(entry.get("active", true))
			if not active:
				continue
			var team_id: int = _team_for_owner(seat_id)
			if team_id <= 0 or team_ids.has(team_id):
				continue
			team_ids.append(team_id)
	if team_ids.is_empty():
		team_ids = [1, 2]
	team_ids.sort()
	return team_ids

func _empty_team_owned_counts() -> Dictionary:
	var owned_by_team: Dictionary = {}
	for team_any in _all_team_ids_from_roster():
		var team_id: int = int(team_any)
		owned_by_team[team_id] = 0
	return owned_by_team

func _log_win_tick_snapshot(now_ms: int, live_snapshot: Dictionary, direct_snapshot: Dictionary) -> void:
	const WIN_TICK_LOG_INTERVAL_MS := 750
	var live_owned: Dictionary = Dictionary(live_snapshot.get("owned_by_team", {}))
	var direct_owned: Dictionary = Dictionary(direct_snapshot.get("owned_by_team", {}))
	var live_alive: Array = _alive_teams_from_owned_counts(live_owned)
	var direct_alive: Array = _alive_teams_from_owned_counts(direct_owned)
	var sig: String = "%s|%s|%d|%d" % [
		str(live_owned),
		str(direct_owned),
		live_alive.size(),
		direct_alive.size()
	]
	if sig == _last_win_tick_sig and now_ms - _last_win_tick_warn_ms < WIN_TICK_LOG_INTERVAL_MS:
		return
	_last_win_tick_sig = sig
	_last_win_tick_warn_ms = now_ms
	SFLog.warn("WIN_TICK_SNAPSHOT", {
		"phase": int(OpsState.match_phase),
		"live_owned": live_owned,
		"live_alive": live_alive,
		"direct_owned": direct_owned,
		"direct_alive": direct_alive,
		"had_multiple": _had_multiple_teams_during_match
	})

func _emit_post_match_action_if_needed() -> void:
	var action := str(OpsState.post_end_action)
	if action == "" or action == _post_action_emitted:
		return
	_post_action_emitted = action
	SFLog.info("POST_MATCH_ACTION", {"action": action, "iid": int(state_ref.get_instance_id())})
	emit_signal("post_match_action", action)

func log_pause_snapshot(reason: String = "") -> void:
	var tree := get_tree()
	var tree_paused := false
	var scene_name := ""
	if tree != null:
		tree_paused = bool(tree.paused)
		var current_scene := tree.current_scene
		if current_scene != null:
			scene_name = str(current_scene.name)
	var snapshot := {
		"tree_paused": tree_paused,
		"time_scale": float(Engine.time_scale),
		"sim_running": bool(running),
		"sim_paused": not bool(running),
		"process_mode": int(process_mode),
		"scene": scene_name,
		"node": str(get_path())
	}
	var caller := _caller_hint()
	if not _last_pause_snapshot.is_empty():
		if bool(_last_pause_snapshot.get("tree_paused", false)) != tree_paused:
			SFLog.info("PAUSE_WRITE", {
				"from": bool(_last_pause_snapshot.get("tree_paused", false)),
				"to": tree_paused,
				"source": caller,
				"reason": reason
			})
		if float(_last_pause_snapshot.get("time_scale", 1.0)) != float(Engine.time_scale):
			SFLog.info("TIME_SCALE_WRITE", {
				"from": float(_last_pause_snapshot.get("time_scale", 1.0)),
				"to": float(Engine.time_scale),
				"source": caller,
				"reason": reason
			})
		if int(_last_pause_snapshot.get("process_mode", -1)) != int(process_mode):
			SFLog.info("PROCESS_MODE_WRITE", {
				"from": int(_last_pause_snapshot.get("process_mode", -1)),
				"to": int(process_mode),
				"source": caller,
				"reason": reason
			})
	var sig := "%s|%s|%s|%s|%s|%s" % [
		int(tree_paused),
		str(Engine.time_scale),
		int(running),
		int(process_mode),
		scene_name,
		str(get_path())
	]
	if sig == _last_pause_snapshot_sig:
		return
	_last_pause_snapshot_sig = sig
	_last_pause_snapshot = snapshot.duplicate(true)
	if reason != "":
		snapshot["reason"] = reason
	if caller != "":
		snapshot["source"] = caller
	SFLog.info("PAUSE_SNAPSHOT", snapshot)
