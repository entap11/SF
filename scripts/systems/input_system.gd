# NOTE: Add per-player selection for left/right mouse and discrete input logs.
# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name InputSystem
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")
const InputEventUtils := preload("res://scripts/systems/input_helpers/input_event_utils.gd")
const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")
const TeamVisuals := preload("res://scripts/renderers/team_visuals.gd")

const DOUBLE_TAP_MS := 360
const DOUBLE_TAP_DIST_PX := 22.0
const TOUCH_DOUBLE_TAP_MS := 460
const TOUCH_DOUBLE_TAP_DIST_PX := 34.0
const CLICK_DBL_MS := 300
const CLICK_DBL_DIST_PX := 22.0
const LANE_PICK_RADIUS := 30.0
const BARRACKS_PICK_RADIUS_PX := 48.0
const TOWER_PICK_RADIUS_PX := 40.0
const STRUCTURE_PICK_BIAS := 0.95
const LONG_PRESS_MS := 400
const LONG_PRESS_MOVE_PX := 12.0
const DRAG_HOVER_EXTRA_PX := 36.0
const DEST_HIVE_ASSIST_SCALE := 1.30
const LANE_SOURCE_RETRACT_T := 0.50
const LANE_GRAB_STATE_IDLE := "idle"
const LANE_GRAB_STATE_CANDIDATE := "candidate"
const LANE_GRAB_STATE_ARMED := "armed"
const LANE_GRAB_STATE_THROW_READY := "throw_ready"
const LANE_GRAB_STATE_COMMITTED := "committed"
const LANE_GRAB_STATE_CANCELLED := "cancelled"
const LANE_GRAB_ARM_MS := 160
const LANE_GRAB_THROW_DISTANCE_PX := 44.0
const TUTORIAL_LANE_GRAB_THROW_DISTANCE_PX := 30.0
const ENABLE_ROUTE_LANE_FLASH := true
const ROUTE_LANE_FLASH_MS := 250

var selection: SelectionState = null
var _last_lane_tap_time_ms: int = -999999
var _last_lane_tap_pos: Vector2 = Vector2.ZERO
var _last_lane_tap_id: int = -1
var _last_lane_tap_player_id: int = -1
var _last_click_ms: int = -999999
var _last_click_world: Vector2 = Vector2.ZERO
var _handling_click: bool = false
var _click_log_once: bool = false
var _press_active: bool = false
var _press_consumed: bool = false
var _press_started_ms: int = 0
var _press_start_pos: Vector2 = Vector2.ZERO
var _press_start_ms: int = 0
var _press_start_world: Vector2 = Vector2.ZERO
var _press_start_screen: Vector2 = Vector2.ZERO
var _press_last_world: Vector2 = Vector2.ZERO
var _press_candidate_barracks_id: int = -1
var _press_prev_selected_id: int = -1
var _press_prev_selected_lane_id: int = -1
var _press_hive_id: int = -1
var _press_lane_id: int = -1
var _press_player_id: int = -1
var _press_is_touch: bool = false
var _press_lane_grab_only: bool = false
var _press_lane_double_tap_only: bool = false
var _press_hive_tap_only: bool = false
var _press_hive_source_select_only: bool = false
var _hover_hive_id: int = -1
var _selected_hive_id: int = -1 # P1 selection mirror
var _selected_by_player: Dictionary = {1: -1, 2: -1, 3: -1, 4: -1}
var _enemy_first_by_player: Dictionary = {1: -1, 2: -1, 3: -1, 4: -1}
var _visual_selected_player_id: int = -1
var selected_src_id: int = -1 # Friendly-only selection mirror (P1).
var enemy_first_id: int = -1
var _dragging: bool = false
var _drag_src_id: int = -1
var _last_arena_api: ArenaAPI = null
var lane_system: LaneSystem = null
var selected_barracks_id: int = -1
var selected_barracks_player_id: int = -1
var barracks_route_buffer: Array = []
var _long_press_timer: SceneTreeTimer = null
var _input_lock_logged: bool = false
var inputs_locked: bool = false
var _phase_input_frozen_logged: bool = false
var _phase_input_attempt_logged: bool = false
var selected_structure_type: String = ""
var selected_structure_id: int = -1
var route_edit_mode: bool = false
var _lane_grab_state: String = LANE_GRAB_STATE_IDLE
var _lane_grab_touch_index: int = -1
var _lane_grab_player_id: int = -1
var _lane_grab_lane_id: int = -1
var _lane_grab_side: String = ""
var _lane_grab_src_id: int = -1
var _lane_grab_dst_id: int = -1
var _lane_grab_press_ms: int = 0
var _lane_grab_start_local: Vector2 = Vector2.ZERO
var _lane_grab_current_local: Vector2 = Vector2.ZERO
var _lane_grab_reason: String = ""
var _lane_grab_constrained: bool = false

func setup(selection_state: SelectionState) -> void:
	if selection_state != null:
		selection = selection_state
	else:
		selection = SelectionState.new()
	_ensure_player_selection_slots()
	_selected_by_player[1] = selection.selected_hive_id if selection != null else -1
	selected_src_id = int(_selected_by_player.get(1, -1))

func set_lane_system(ls: LaneSystem) -> void:
	lane_system = ls

func set_inputs_locked(v: bool, reason: String = "match_over") -> void:
	if inputs_locked == v:
		return
	inputs_locked = v
	if inputs_locked:
		_clear_interaction_state()
		SFLog.info("INPUT_LOCKED", {
			"reason": reason,
			"winner_id": int(OpsState.winner_id)
		})
	else:
		_input_lock_logged = false
		_phase_input_frozen_logged = false
		_phase_input_attempt_logged = false

func tick(_dt: float, _arena_api: ArenaAPI) -> void:
	if _arena_api == null:
		return
	if _lane_grab_state == LANE_GRAB_STATE_CANDIDATE:
		if Time.get_ticks_msec() - _lane_grab_press_ms >= LANE_GRAB_ARM_MS:
			_arm_lane_grab(_arena_api)
	elif _lane_grab_state == LANE_GRAB_STATE_ARMED or _lane_grab_state == LANE_GRAB_STATE_THROW_READY:
		_update_lane_grab_motion(_lane_grab_current_local, _arena_api)

func _clear_interaction_state() -> void:
	_press_active = false
	_press_consumed = false
	_press_candidate_barracks_id = -1
	_press_hive_id = -1
	_press_lane_id = -1
	_press_player_id = -1
	_press_is_touch = false
	_press_lane_grab_only = false
	_press_lane_double_tap_only = false
	_press_hive_tap_only = false
	_press_hive_source_select_only = false
	_press_prev_selected_id = -1
	_press_prev_selected_lane_id = -1
	_dragging = false
	_drag_src_id = -1
	_cancel_lane_grab("touch_cancelled", _last_arena_api, true)
	if _long_press_timer != null:
		_long_press_timer = null
	_clear_drag_target_visual(_last_arena_api)
	if selection != null:
		reset_drag()

func handle_input(event: InputEvent, arena_api: ArenaAPI) -> Array:
	var commands: Array = []
	if selection == null or arena_api == null:
		return commands
	SFLog.allow_tag("INPUT_FROZEN_BY_MATCH_PHASE")
	SFLog.allow_tag("INPUT_IGNORED_MATCH_PHASE")
	SFLog.allow_tag("INPUT_IGNORED_LOCKED")
	SFLog.allow_tag("INPUT_RELEASE_PICK")
	SFLog.allow_tag("INPUT_HIVE_NOT_SELECTABLE")
	if OpsState.match_phase != OpsState.MatchPhase.RUNNING:
		if not _phase_input_frozen_logged:
			_phase_input_frozen_logged = true
			SFLog.warn("INPUT_FROZEN_BY_MATCH_PHASE", {"phase": int(OpsState.match_phase)})
		if not _phase_input_attempt_logged:
			_phase_input_attempt_logged = true
			SFLog.warn("INPUT_IGNORED_MATCH_PHASE", {"phase": int(OpsState.match_phase)})
		return commands
	if inputs_locked:
		return commands
	if OpsState.is_ending_or_ended():
		return commands
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if arena_api.get_sim_running():
				arena_api.set_sim_running(false)
				arena_api.dbg("SF: sim_running = false (paused)")
			else:
				arena_api.dbg("SF: sim start blocked (use DevMapLoader)")
		if event.keycode == KEY_B:
			if event.shift_pressed:
				var next_debris: bool = not arena_api.get_debris_enabled()
				arena_api.set_debris_enabled(next_debris)
				arena_api.dbg("SF: debris_enabled = %s" % str(next_debris))
		if event.keycode == KEY_1:
			arena_api.set_active_player_id(1)
			arena_api.dbg("SF: active_player_id = 1")
		if event.keycode == KEY_2:
			arena_api.set_active_player_id(2)
			arena_api.dbg("SF: active_player_id = 2")
		if event.keycode == KEY_3:
			arena_api.set_active_player_id(3)
			arena_api.dbg("SF: active_player_id = 3")
		if event.keycode == KEY_4:
			arena_api.set_active_player_id(4)
			arena_api.dbg("SF: active_player_id = 4")
	return commands

func handle_pointer_event(ev: Dictionary, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	SFLog.allow_tag("INPUT_FROZEN_BY_MATCH_PHASE")
	SFLog.allow_tag("INPUT_IGNORED_MATCH_PHASE")
	SFLog.allow_tag("INPUT_IGNORED_LOCKED")
	SFLog.allow_tag("INPUT_RELEASE_PICK")
	SFLog.allow_tag("INPUT_HIVE_NOT_SELECTABLE")
	if OpsState.match_phase != OpsState.MatchPhase.RUNNING:
		if not _phase_input_frozen_logged:
			_phase_input_frozen_logged = true
			SFLog.warn("INPUT_FROZEN_BY_MATCH_PHASE", {"phase": int(OpsState.match_phase)})
		if not _phase_input_attempt_logged:
			_phase_input_attempt_logged = true
			SFLog.warn("INPUT_IGNORED_MATCH_PHASE", {"phase": int(OpsState.match_phase)})
		return
	if inputs_locked:
		SFLog.warn("INPUT_IGNORED_LOCKED", {"reason": "input_system_lock"})
		return
	if OpsState.is_ending_or_ended():
		SFLog.warn("INPUT_IGNORED_LOCKED", {"reason": "match_ending_or_ended"})
		return
	if OpsState.input_locked:
		if not _input_lock_logged:
			_input_lock_logged = true
			SFLog.warn("INPUT_LOCKED", {
				"reason": OpsState.input_locked_reason if OpsState.input_locked_reason != "" else "match_over",
				"winner_id": int(OpsState.winner_id)
			})
		return
	if _input_lock_logged:
		_input_lock_logged = false
	_last_arena_api = arena_api
	var event_type: String = str(ev.get("type", ""))
	var button_index: int = int(ev.get("button", MOUSE_BUTTON_LEFT))
	if event_type != "motion" and not InputEventUtils.is_player_pointer_button(button_index):
		return
	var is_touch: bool = bool(ev.get("is_touch", false))
	var touch_index: int = int(ev.get("touch_index", -1))
	var dev_pid: int = -1
	if not is_touch and button_index != MOUSE_BUTTON_LEFT:
		dev_pid = _dev_mouse_pid_from_button(button_index)
	if _lane_grab_state != LANE_GRAB_STATE_IDLE and _lane_grab_touch_index >= 0 and is_touch and touch_index != _lane_grab_touch_index:
		return
	var local_pos: Vector2 = ev.get("local_pos", Vector2.ZERO)
	var hive_id: int = int(ev.get("hive_id", -1))
	var lane_id: int = int(ev.get("lane_id", -1))
	var lane_grab_only: bool = bool(ev.get("lane_grab_only", false))
	var lane_double_tap_only: bool = bool(ev.get("lane_double_tap_only", false))
	var hive_tap_only: bool = bool(ev.get("hive_tap_only", false))
	var hive_source_select_only: bool = bool(ev.get("hive_source_select_only", false))
	if event_type == "press" or event_type == "release":
		var actor_id := _player_id_from_button(button_index, arena_api, dev_pid)
		hive_id = -1 if lane_grab_only or lane_double_tap_only else _pick_hive_id_with_destination_assist(local_pos, hive_id, actor_id, arena_api)
	SFLog.log_once("input_path_pointer", "INPUT_PATH: handle_pointer_event", SFLog.Level.INFO)
	match event_type:
		"press":
			_handle_press(local_pos, hive_id, lane_id, dev_pid, arena_api, button_index, is_touch, touch_index, lane_grab_only, lane_double_tap_only, hive_tap_only, hive_source_select_only)
		"motion":
			_handle_drag(local_pos, hive_id, lane_id, arena_api)
		"release":
			_handle_release(local_pos, hive_id, lane_id, dev_pid, arena_api, button_index)
		_:
			return

func handle_press(local_pos: Vector2, dev_pid: int, arena_api: ArenaAPI, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	if selection == null or arena_api == null:
		return
	var actor_id := _player_id_from_button(button_index, arena_api, dev_pid)
	var base_hive_id: int = arena_api.pick_hive_id_local(local_pos)
	if base_hive_id <= 0:
		base_hive_id = _hover_hive_id
	var hive_id: int = _pick_hive_id_with_destination_assist(local_pos, base_hive_id, actor_id, arena_api)
	var lane: LaneData = arena_api.pick_lane(local_pos)
	var lane_id: int = lane.id if lane != null else -1
	_handle_press(local_pos, hive_id, lane_id, dev_pid, arena_api, button_index)

func handle_release(local_pos: Vector2, dev_pid: int, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	var hive_id: int = _pick_hive_id_with_destination_assist(local_pos, _hover_hive_id, dev_pid, arena_api)
	var lane: LaneData = arena_api.pick_lane(local_pos)
	var lane_id: int = lane.id if lane != null else -1
	_handle_release(local_pos, hive_id, lane_id, dev_pid, arena_api, MOUSE_BUTTON_LEFT)

func handle_drag(local_pos: Vector2, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	var hive_id: int = arena_api.hive_id_at_point(local_pos)
	var lane: LaneData = arena_api.pick_lane(local_pos)
	var lane_id: int = lane.id if lane != null else -1
	_handle_drag(local_pos, hive_id, lane_id, arena_api)

func handle_tap(hive_id: int, dev_pid: int, arena_api: ArenaAPI) -> void:
	_handle_tap(hive_id, dev_pid, arena_api)

func handle_lane_double_tap(local_pos: Vector2, dev_pid: int, pid: int, arena_api: ArenaAPI) -> bool:
	return _handle_lane_double_tap(local_pos, dev_pid, pid, arena_api)

func clear_tap_state() -> void:
	if selection == null:
		return
	selection.clear_tap_state()

func _reset_lane_tap_state() -> void:
	_last_lane_tap_time_ms = -999999
	_last_lane_tap_pos = Vector2.ZERO
	_last_lane_tap_id = -1
	_last_lane_tap_player_id = -1

func _record_lane_tap(lane_id: int, local_pos: Vector2, player_id: int) -> void:
	_last_lane_tap_time_ms = Time.get_ticks_msec()
	_last_lane_tap_pos = local_pos
	_last_lane_tap_id = lane_id
	_last_lane_tap_player_id = player_id

func _is_lane_double_tap(lane_id: int, local_pos: Vector2, player_id: int, is_touch: bool = false) -> bool:
	if lane_id <= 0 or lane_id != _last_lane_tap_id:
		return false
	if player_id <= 0 or player_id != _last_lane_tap_player_id:
		return false
	var now_ms: int = Time.get_ticks_msec()
	var max_ms: int = TOUCH_DOUBLE_TAP_MS if is_touch else DOUBLE_TAP_MS
	var max_dist: float = TOUCH_DOUBLE_TAP_DIST_PX if is_touch else DOUBLE_TAP_DIST_PX
	return (now_ms - _last_lane_tap_time_ms) <= max_ms and _last_lane_tap_pos.distance_to(local_pos) <= max_dist

func clear_selection() -> void:
	if selection == null:
		return
	selection.clear_selection()
	if _last_arena_api != null:
		_last_arena_api.clear_selection()
	_selected_hive_id = -1
	for player_id in [1, 2, 3, 4]:
		_selected_by_player[player_id] = -1
	selected_src_id = -1
	for player_id in [1, 2, 3, 4]:
		_enemy_first_by_player[player_id] = -1
	enemy_first_id = -1
	_visual_selected_player_id = -1

func reset_drag() -> void:
	if selection == null:
		return
	selection.reset_drag()

func handle_hive_hovered(hive_id: int, _global_pos: Vector2) -> void:
	_hover_hive_id = hive_id

func handle_hive_unhovered(hive_id: int) -> void:
	if _hover_hive_id == hive_id:
		_hover_hive_id = -1

func _get_active_pid(arena_api: ArenaAPI) -> int:
	if arena_api == null:
		return 1
	if arena_api.has_method("get_active_pid"):
		return int(arena_api.call("get_active_pid"))
	if "active_pid" in arena_api:
		return int(arena_api.active_pid)
	if arena_api.has_method("get_state"):
		var st = arena_api.call("get_state")
		if st is Dictionary and st.has("active_pid"):
			return int(st["active_pid"])
	return 1

func _player_id_from_button(button_index: int, arena_api: ArenaAPI, dev_pid: int = -1) -> int:
	return InputEventUtils.player_id_from_button(button_index, arena_api, dev_pid)

func _ensure_player_selection_slots() -> void:
	for player_id in [1, 2, 3, 4]:
		if not _selected_by_player.has(player_id):
			_selected_by_player[player_id] = -1
		if not _enemy_first_by_player.has(player_id):
			_enemy_first_by_player[player_id] = -1

func _get_selected_for_player(player_id: int) -> int:
	_ensure_player_selection_slots()
	return int(_selected_by_player.get(player_id, -1))

func _set_selected_for_player(arena_api: ArenaAPI, player_id: int, hive_id: int) -> void:
	_ensure_player_selection_slots()
	if player_id < 1 or player_id > 4:
		player_id = _get_active_pid(arena_api)
	var changed: bool = int(_selected_by_player.get(player_id, -1)) != hive_id
	_selected_by_player[player_id] = hive_id
	if player_id == _get_active_pid(arena_api):
		_selected_hive_id = hive_id
		selected_src_id = hive_id
		if selection != null:
			selection.selected_hive_id = hive_id
			selection.selected_lane_id = -1
		if arena_api != null:
			arena_api.set_selected_hive_id(hive_id)
	_set_selected_visual_for_player(arena_api, player_id, hive_id)
	if changed and hive_id > 0:
		SFLog.info("SELECT", {"src": hive_id, "player_id": player_id})

func _clear_selected_for_player(arena_api: ArenaAPI, player_id: int) -> void:
	_ensure_player_selection_slots()
	if player_id < 1 or player_id > 4:
		player_id = _get_active_pid(arena_api)
	var had_selection := int(_selected_by_player.get(player_id, -1)) > 0
	_selected_by_player[player_id] = -1
	if player_id == _get_active_pid(arena_api):
		_selected_hive_id = -1
		selected_src_id = -1
		if selection != null:
			selection.selected_hive_id = -1
			selection.selected_lane_id = -1
		if arena_api != null:
			arena_api.clear_selection()
	if _visual_selected_player_id == player_id:
		_clear_selected_visual(arena_api)
	if had_selection:
		SFLog.info("INPUT_DESELECT", {"player_id": player_id})

func _get_enemy_first_for_player(player_id: int) -> int:
	_ensure_player_selection_slots()
	return int(_enemy_first_by_player.get(player_id, -1))

func _set_enemy_first_for_player(player_id: int, hive_id: int) -> void:
	_ensure_player_selection_slots()
	_enemy_first_by_player[player_id] = hive_id
	if player_id == 1:
		enemy_first_id = hive_id

func _clear_enemy_first_for_player(player_id: int) -> void:
	_ensure_player_selection_slots()
	_enemy_first_by_player[player_id] = -1
	if player_id == 1:
		enemy_first_id = -1

func _set_enemy_first_visual(arena_api: ArenaAPI, hive_id: int, player_id: int) -> void:
	if selection != null:
		selection.selected_hive_id = -1
		selection.selected_lane_id = -1
	_set_selected_visual_for_player(arena_api, player_id, hive_id)

func _clear_enemy_first_visual(arena_api: ArenaAPI, player_id: int) -> void:
	if _visual_selected_player_id == player_id:
		_clear_selected_visual(arena_api)

func _owner_color(owner_id: int) -> Color:
	if owner_id >= 1 and owner_id <= 4:
		return TeamVisuals.owner_color(owner_id)
	return Color(1.0, 1.0, 1.0, 1.0)

func _are_allied_seats(seat_a: int, seat_b: int) -> bool:
	var a_id: int = int(seat_a)
	var b_id: int = int(seat_b)
	if a_id <= 0 or b_id <= 0:
		return false
	if OpsState.has_method("are_allies"):
		return bool(OpsState.call("are_allies", a_id, b_id))
	return a_id == b_id

func _validate_target(src_id: int, dst_id: int, arena_api: ArenaAPI) -> Dictionary:
	_last_arena_api = arena_api
	var src_owner := int(arena_api.get_hive_owner_id(src_id))
	var dst_owner := int(arena_api.get_hive_owner_id(dst_id))
	var src_exists := src_owner != -1
	var dst_exists := dst_owner != -1
	if not src_exists or not dst_exists:
		return {
			"ok": false,
			"reason": "missing_hive",
			"src_owner": src_owner,
			"dst_owner": dst_owner,
			"has_lane": false,
			"lane_id": -1
		}
	var state: GameState = arena_api.get_state()
	var st := state
	SFLog.info("STATE_PTR_CHECK", {
		"iid": (-1 if st == null else int(st.get_instance_id())),
		"hives": (-1 if st == null else st.hives.size())
	})
	var can_connect := false
	if state != null:
		var s := arena_api.get_state()
		if s != null:
			SFLog.info("STATE_IID_INPUT", {"iid": int(s.get_instance_id())})
		can_connect = state.can_connect(src_id, dst_id)
	if not can_connect:
		var state_iid := -1
		if state != null:
			state_iid = int(state.get_instance_id())
		SFLog.info("LOS_LOOKUP", {
			"src": src_id,
			"dst": dst_id,
			"state_iid": state_iid,
			"blocked": true
		})
		return {
			"ok": false,
			"reason": "blocked",
			"src_owner": src_owner,
			"dst_owner": dst_owner,
			"has_lane": false,
			"lane_id": -1
		}
	if state != null:
		var lane_index: int = state.lane_index_between(src_id, dst_id)
		if lane_index == -1 or not state.is_outgoing_lane_active(src_id, dst_id):
			var src_hive: HiveData = state.find_hive_by_id(src_id)
			if src_hive == null:
				return {
					"ok": false,
					"reason": "missing_hive",
					"src_owner": src_owner,
					"dst_owner": dst_owner,
					"has_lane": false,
					"lane_id": -1
				}
			var budget: int = int(state.lanes_allowed_for_power(int(src_hive.power)))
			var active: int = int(state.count_active_outgoing(src_id))
			if active >= budget:
				return {
					"ok": false,
					"reason": "budget",
					"src_owner": src_owner,
					"dst_owner": dst_owner,
					"has_lane": lane_index != -1,
					"lane_id": -1,
					"active": active,
					"budget": budget
				}
	return {
		"ok": true,
		"reason": "",
		"src_owner": src_owner,
		"dst_owner": dst_owner,
		"has_lane": true,
		"lane_id": -1
	}

func _get_hive_owner(hid: int) -> int:
	if _last_arena_api == null:
		return -1
	var state: GameState = _last_arena_api.get_state()
	if state == null:
		return -1
	var hive: HiveData = state.find_hive_by_id(hid)
	if hive == null:
		return -1
	return int(hive.owner_id)

func _get_hive_power(hid: int, arena_api: ArenaAPI) -> int:
	if arena_api == null:
		return 0
	var state: GameState = arena_api.get_state()
	if state != null:
		var hive: HiveData = state.find_hive_by_id(hid)
		if hive != null:
			return int(hive.power)
	var hive_fallback := arena_api.find_hive_by_id(hid)
	if hive_fallback != null:
		return int(hive_fallback.power)
	return 0

func _get_hive_pos_local(hid: int, arena_api: ArenaAPI) -> Vector2:
	if arena_api == null:
		return Vector2.ZERO
	var hr := arena_api.get_hive_renderer()
	if hr != null:
		var node := hr.get_hive_node_by_id(hid)
		if node is Node2D:
			return (node as Node2D).position
	var state: GameState = arena_api.get_state()
	if state != null:
		var hive: HiveData = state.find_hive_by_id(hid)
		if hive != null:
			return arena_api.cell_center(hive.grid_pos)
	return Vector2.ZERO

func _set_selected(arena_api: ArenaAPI, hive_id: int) -> void:
	if hive_id <= 0:
		_clear_selected(arena_api)
		return
	var player_id: int = _get_active_pid(arena_api)
	if arena_api != null:
		var owner_id: int = int(arena_api.get_hive_owner_id(hive_id))
		if owner_id >= 1 and owner_id <= 4:
			player_id = owner_id
	_set_selected_for_player(arena_api, player_id, hive_id)

func _clear_selected(arena_api: ArenaAPI) -> void:
	var player_id: int = _get_active_pid(arena_api)
	_clear_selected_for_player(arena_api, player_id)
	SFLog.info("DESELECT", {"player_id": player_id})

func _set_selected_visual_for_player(arena_api: ArenaAPI, player_id: int, hive_id: int) -> void:
	var hr := _get_hive_renderer(arena_api)
	if hr == null or not hr.has_method("set_selected_hive"):
		return
	_visual_selected_player_id = player_id
	hr.call("set_selected_hive", hive_id, _owner_color(player_id))

func _clear_selected_visual(arena_api: ArenaAPI) -> void:
	var hr := _get_hive_renderer(arena_api)
	if hr != null:
		if hr.has_method("clear_selected_hive"):
			hr.call("clear_selected_hive")
		elif hr.has_method("set_selected_hive"):
			hr.call("set_selected_hive", -1, _owner_color(0))
	_visual_selected_player_id = -1

func _get_hive_renderer(arena_api: ArenaAPI) -> Object:
	if arena_api == null:
		return null
	var arena: Node = arena_api._arena
	if arena == null:
		return null
	var renderer_v: Variant = arena.get("hive_renderer")
	if renderer_v != null:
		return renderer_v
	return arena.get_node_or_null("MapRoot/HiveRenderer")

func _get_barracks_renderer(arena_api: ArenaAPI) -> Object:
	if arena_api == null:
		return null
	var arena: Node = arena_api._arena
	if arena == null:
		return null
	var renderer_v: Variant = arena.get("barracks_renderer")
	if renderer_v != null:
		return renderer_v
	return arena.get_node_or_null("MapRoot/BarracksRenderer")

func _get_lane_renderer(arena_api: ArenaAPI) -> Object:
	if arena_api == null:
		return null
	var arena: Node = arena_api._arena
	if arena == null:
		return null
	var renderer_v: Variant = arena.get("lane_renderer")
	if renderer_v != null:
		return renderer_v
	return arena.get_node_or_null("MapRoot/LaneRenderer")

func _pick_drag_hover_hive_id(local_pos: Vector2, arena_api: ArenaAPI) -> int:
	var direct_id: int = arena_api.pick_hive_id_local(local_pos)
	if direct_id > 0:
		return direct_id
	var assisted_id: int = _pick_assisted_destination_hive_id(local_pos, selection.drag_start_hive_id, arena_api)
	if assisted_id > 0:
		return assisted_id
	var nearest: Dictionary = arena_api.get_nearest_hive_local(local_pos)
	var nearest_id: int = int(nearest.get("id", -1))
	if nearest_id <= 0:
		return -1
	var dist: float = float(nearest.get("dist", INF))
	if dist == INF:
		return -1
	var snap_radius: float = maxf(1.0, arena_api.get_hive_pick_radius_px(nearest_id)) + DRAG_HOVER_EXTRA_PX
	if dist <= snap_radius:
		return nearest_id
	return -1

func _pick_hive_id_with_destination_assist(local_pos: Vector2, base_hive_id: int, player_id: int, arena_api: ArenaAPI, selected_override_id: int = -1) -> int:
	if base_hive_id > 0:
		return base_hive_id
	if arena_api == null:
		return base_hive_id
	var resolved_player_id := player_id
	if resolved_player_id <= 0:
		resolved_player_id = _get_active_pid(arena_api)
	var selected_id := selected_override_id
	if selected_id <= 0:
		selected_id = _get_selected_for_player(resolved_player_id)
	if selected_id <= 0:
		return base_hive_id
	var selected_hive: HiveData = arena_api.find_hive_by_id(selected_id)
	if selected_hive == null or int(selected_hive.owner_id) != resolved_player_id:
		return base_hive_id
	var assisted_id := _pick_assisted_destination_hive_id(local_pos, selected_id, arena_api)
	return assisted_id if assisted_id > 0 else base_hive_id

func _pick_assisted_destination_hive_id(local_pos: Vector2, selected_id: int, arena_api: ArenaAPI) -> int:
	if selected_id <= 0 or arena_api == null:
		return -1
	var st: GameState = arena_api.get_state()
	if st == null or st.hives == null:
		return -1
	var best_id := -1
	var best_dist := INF
	var hr := arena_api.get_hive_renderer()
	for hive in st.hives:
		if hive == null:
			continue
		var hid: int = int(hive.id)
		if hid <= 0 or hid == selected_id:
			continue
		var center := Vector2.INF
		if hr != null and hr.has_method("get_hive_center_local"):
			center = hr.get_hive_center_local(hid)
		if center == Vector2.INF:
			var render_gp: Vector2 = hive.render_grid_pos
			if not is_finite(render_gp.x) or not is_finite(render_gp.y):
				render_gp = Vector2(float(hive.grid_pos.x), float(hive.grid_pos.y))
			center = arena_api.grid_to_world(Vector2i(roundi(render_gp.x), roundi(render_gp.y)))
		var dist: float = center.distance_to(local_pos)
		var radius: float = maxf(1.0, arena_api.get_hive_pick_radius_px(hid)) * DEST_HIVE_ASSIST_SCALE
		if dist <= radius and dist < best_dist:
			best_id = hid
			best_dist = dist
	return best_id

func _queue_lane_preview_redraw(arena_api: ArenaAPI) -> void:
	var lane_renderer: Object = _get_lane_renderer(arena_api)
	if lane_renderer is CanvasItem:
		(lane_renderer as CanvasItem).queue_redraw()

func _set_drag_target_visual(arena_api: ArenaAPI, hive_id: int, valid: bool, reason: String = "") -> void:
	var hr := _get_hive_renderer(arena_api)
	if hr == null:
		return
	if hive_id > 0 and hr.has_method("set_drag_target_hive"):
		hr.call("set_drag_target_hive", hive_id, valid, reason)
	elif hr.has_method("clear_drag_target_hive"):
		hr.call("clear_drag_target_hive")

func _clear_drag_target_visual(arena_api: ArenaAPI) -> void:
	var hr := _get_hive_renderer(arena_api)
	if hr != null and hr.has_method("clear_drag_target_hive"):
		hr.call("clear_drag_target_hive")

func _lane_pick_radius(arena_api: ArenaAPI) -> float:
	var radius := LANE_PICK_RADIUS
	if arena_api == null:
		return radius
	var arena: Node = arena_api._arena
	if arena == null:
		return radius
	var cam: Camera2D = null
	var cam_v: Variant = arena.get("camera")
	if cam_v is Camera2D:
		cam = cam_v as Camera2D
	if cam == null:
		cam = arena.get_node_or_null("Camera2D") as Camera2D
	if cam != null and cam.zoom.x > 0.001:
		radius = radius / cam.zoom.x
	return radius

func _pick_lane_hit(world_pos: Vector2, arena_api: ArenaAPI) -> Dictionary:
	var radius := _lane_pick_radius(arena_api)
	var lr := _get_lane_renderer(arena_api)
	if lr != null and lr.has_method("pick_lane_at_world_pos"):
		var hit: Dictionary = lr.call("pick_lane_at_world_pos", world_pos, radius)
		if bool(hit.get("hit", false)):
			if lr.has_method("debug_pick_dot"):
				lr.call("debug_pick_dot", world_pos, 200)
			SFLog.info("LANE_PICK", {
				"lane_id": int(hit.get("lane_id", -1)),
				"dist": float(hit.get("dist", INF)),
				"t": float(hit.get("t", 0.0)),
				"radius": radius
			})
		return hit
	var fallback: Dictionary = arena_api.pick_lane_world(world_pos)
	var ok := bool(fallback.get("ok", false))
	if ok and lr != null and lr.has_method("debug_pick_dot"):
		lr.call("debug_pick_dot", world_pos, 200)
	if ok:
		SFLog.info("LANE_PICK", {
			"lane_id": int(fallback.get("lane_id", -1)),
			"dist": float(fallback.get("dist", INF)),
			"t": float(fallback.get("t", 0.0)),
			"radius": radius
		})
	return {
		"hit": ok,
		"lane_id": int(fallback.get("lane_id", -1)),
		"t": float(fallback.get("t", 0.0)),
		"dist": float(fallback.get("dist", INF))
	}

func _pick_lane_id_for_click(local_pos: Vector2, fallback_lane_id: int, arena_api: ArenaAPI) -> int:
	var world_pos: Vector2 = _map_local_to_world(local_pos, arena_api)
	var hit: Dictionary = _pick_lane_hit(world_pos, arena_api)
	if bool(hit.get("hit", false)):
		var hit_lane_id: int = int(hit.get("lane_id", -1))
		if hit_lane_id > 0:
			return hit_lane_id
	if fallback_lane_id > 0:
		return fallback_lane_id
	var lane: LaneData = arena_api.pick_lane(local_pos) if arena_api != null else null
	return int(lane.id) if lane != null else -1

func _should_route_hive_click_to_lane(prev_selected_id: int, clicked_id: int, lane_id: int, local_pos: Vector2, player_id: int, arena_api: ArenaAPI) -> bool:
	if clicked_id <= 0 or lane_id <= 0 or arena_api == null:
		return false
	if _is_lane_double_tap(lane_id, local_pos, player_id, _press_is_touch):
		return true
	if _is_lane_source_retract_tap(lane_id, local_pos, player_id, arena_api):
		return true
	if prev_selected_id > 0:
		return false
	var hive: HiveData = arena_api.find_hive_by_id(clicked_id)
	if hive == null:
		return false
	if int(hive.owner_id) != player_id:
		return true
	return _tap_is_outside_hive_core(clicked_id, local_pos, arena_api)

func _tap_is_outside_hive_core(hive_id: int, local_pos: Vector2, arena_api: ArenaAPI) -> bool:
	if arena_api == null:
		return false
	var hive: HiveData = arena_api.find_hive_by_id(hive_id)
	if hive == null:
		return false
	var center: Vector2 = Vector2.INF
	var hr := arena_api.get_hive_renderer()
	if hr != null and hr.has_method("get_hive_center_local"):
		center = hr.get_hive_center_local(hive_id)
	if center == Vector2.INF:
		var render_gp: Vector2 = hive.render_grid_pos
		if not is_finite(render_gp.x) or not is_finite(render_gp.y):
			render_gp = Vector2(float(hive.grid_pos.x), float(hive.grid_pos.y))
		center = arena_api.grid_to_world(Vector2i(roundi(render_gp.x), roundi(render_gp.y)))
	var core_radius: float = arena_api.get_hive_pick_radius_px(hive_id)
	if core_radius <= 0.0:
		core_radius = maxf(1.0, arena_api.get_hive_radius_px())
	return local_pos.distance_to(center) > core_radius

func _get_viewport_from_arena(arena_api: ArenaAPI) -> Viewport:
	return InputEventUtils.get_viewport_from_arena(arena_api)

func _get_screen_pos_from_event(event: InputEvent, arena_api: ArenaAPI) -> Vector2:
	return InputEventUtils.get_screen_pos_from_event(event, arena_api)

func _get_world_pos_from_event(event: InputEvent, arena_api: ArenaAPI) -> Vector2:
	return InputEventUtils.get_world_pos_from_event(event, arena_api)

func _map_local_to_world(local_pos: Vector2, arena_api: ArenaAPI) -> Vector2:
	if arena_api == null:
		return local_pos
	var arena: Node = arena_api._arena
	if arena == null:
		return local_pos
	var map_root_v: Variant = arena.get("map_root")
	if map_root_v is Node2D:
		return (map_root_v as Node2D).to_global(local_pos)
	var map_node := arena.get_node_or_null("MapRoot")
	if map_node is Node2D:
		return (map_node as Node2D).to_global(local_pos)
	return local_pos

func _barracks_grid_pos(barracks_data: Dictionary) -> Vector2i:
	var gp_v: Variant = barracks_data.get("grid_pos", Vector2i.ZERO)
	if gp_v is Vector2i:
		return gp_v as Vector2i
	if gp_v is Array:
		var gp_arr: Array = gp_v as Array
		if gp_arr.size() >= 2:
			return Vector2i(int(gp_arr[0]), int(gp_arr[1]))
	var x: int = int(barracks_data.get("x", 0))
	var y: int = int(barracks_data.get("y", 0))
	return Vector2i(x, y)

func _barracks_world_pos(barracks_data: Dictionary, arena_api: ArenaAPI) -> Vector2:
	var gp: Vector2i = _barracks_grid_pos(barracks_data)
	var grid_spec: Object = arena_api.get_grid_spec() if arena_api != null else null
	if grid_spec != null:
		return grid_spec.grid_to_world(gp)
	return Vector2(
		(float(gp.x) + 0.5) * GameState.DEFAULT_CELL_SIZE,
		(float(gp.y) + 0.5) * GameState.DEFAULT_CELL_SIZE
	)

func _tower_grid_pos(tower_data: Dictionary) -> Vector2i:
	var gp_v: Variant = tower_data.get("grid_pos", Vector2i.ZERO)
	if gp_v is Vector2i:
		return gp_v as Vector2i
	if gp_v is Array:
		var gp_arr: Array = gp_v as Array
		if gp_arr.size() >= 2:
			return Vector2i(int(gp_arr[0]), int(gp_arr[1]))
	var x: int = int(tower_data.get("x", 0))
	var y: int = int(tower_data.get("y", 0))
	return Vector2i(x, y)

func _pick_hive_candidate(world_pos: Vector2, map_local: Vector2, arena_api: ArenaAPI) -> Dictionary:
	if arena_api == null:
		return {}
	var hid := arena_api.pick_hive_id(world_pos)
	if hid <= 0:
		return {}
	var dist := INF
	var center_local := Vector2.INF
	var hr := arena_api.get_hive_renderer()
	if hr != null and hr.has_method("get_hive_center_local"):
		center_local = hr.get_hive_center_local(hid)
	if center_local != Vector2.INF:
		dist = center_local.distance_to(map_local)
	else:
		var nearest := arena_api.get_nearest_hive_local(map_local)
		dist = float(nearest.get("dist", INF))
	if dist == INF:
		dist = 0.0
	return {
		"type": "hive",
		"id": hid,
		"dist": dist
	}

func _pick_barracks_candidate(_world_pos: Vector2, map_local: Vector2, arena_api: ArenaAPI) -> Dictionary:
	if arena_api == null:
		return {}
	var st: GameState = arena_api.get_state()
	if st == null or st.barracks == null:
		return {}
	var grid_spec: Object = arena_api.get_grid_spec()
	var best_id := -1
	var best_dist := INF
	var best_center := Vector2.INF
	for barracks_any in st.barracks:
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = barracks_any as Dictionary
		var barracks_id := int(b.get("id", -1))
		if barracks_id <= 0:
			continue
		var gp := _barracks_grid_pos(b)
		var center_world: Vector2
		if grid_spec != null:
			center_world = grid_spec.grid_to_world(gp)
		else:
			center_world = Vector2(
				(float(gp.x) + 0.5) * GameState.DEFAULT_CELL_SIZE,
				(float(gp.y) + 0.5) * GameState.DEFAULT_CELL_SIZE
			)
		var center_local := arena_api.world_to_map_local(center_world)
		var dist := center_local.distance_to(map_local)
		if dist <= BARRACKS_PICK_RADIUS_PX and dist < best_dist:
			best_id = barracks_id
			best_dist = dist
			best_center = center_local
	if best_id <= 0:
		return {}
	return {
		"type": "barracks",
		"id": best_id,
		"dist": best_dist,
		"center_local": best_center
	}

func _pick_tower_candidate(_world_pos: Vector2, map_local: Vector2, arena_api: ArenaAPI) -> Dictionary:
	if arena_api == null:
		return {}
	var st: GameState = arena_api.get_state()
	if st == null or st.towers == null:
		return {}
	var grid_spec: Object = arena_api.get_grid_spec()
	var best_id := -1
	var best_dist := INF
	var best_center := Vector2.INF
	for tower_any in st.towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var t: Dictionary = tower_any as Dictionary
		var tower_id := int(t.get("id", -1))
		if tower_id <= 0:
			continue
		var gp := _tower_grid_pos(t)
		var center_world: Vector2
		if grid_spec != null:
			center_world = grid_spec.grid_to_world(gp)
		else:
			center_world = Vector2(
				(float(gp.x) + 0.5) * GameState.DEFAULT_CELL_SIZE,
				(float(gp.y) + 0.5) * GameState.DEFAULT_CELL_SIZE
			)
		var center_local := arena_api.world_to_map_local(center_world)
		var dist := center_local.distance_to(map_local)
		if dist <= TOWER_PICK_RADIUS_PX and dist < best_dist:
			best_id = tower_id
			best_dist = dist
			best_center = center_local
	if best_id <= 0:
		return {}
	return {
		"type": "tower",
		"id": best_id,
		"dist": best_dist,
		"center_local": best_center
	}

func _pick_tower_at_local(map_local: Vector2, arena_api: ArenaAPI) -> int:
	var world_pos: Vector2 = _map_local_to_world(map_local, arena_api)
	var hit: Dictionary = _pick_tower_candidate(world_pos, map_local, arena_api)
	return int(hit.get("id", -1))

func _pick_target(world_pos: Vector2, map_local: Vector2, arena_api: ArenaAPI) -> Dictionary:
	var candidates: Array = []
	var hive_c := _pick_hive_candidate(world_pos, map_local, arena_api)
	if int(hive_c.get("id", -1)) > 0:
		candidates.append(hive_c)
	var barracks_c := _pick_barracks_candidate(world_pos, map_local, arena_api)
	if int(barracks_c.get("id", -1)) > 0:
		candidates.append(barracks_c)
	var tower_c := _pick_tower_candidate(world_pos, map_local, arena_api)
	if int(tower_c.get("id", -1)) > 0:
		candidates.append(tower_c)
	var best := {"type": "", "id": -1, "dist": INF, "world": world_pos}
	var best_score := INF
	for c in candidates:
		var dist := float(c.get("dist", INF))
		var ctype := str(c.get("type", ""))
		var score := dist
		if ctype != "hive":
			score *= STRUCTURE_PICK_BIAS
		if score < best_score:
			best = c
			best_score = score
		elif abs(score - best_score) <= 0.01 and ctype != "hive" and str(best.get("type", "")) == "hive":
			best = c
			best_score = score
	if int(best.get("id", -1)) <= 0:
		return {"type": "", "id": -1, "dist": INF, "world": world_pos}
	best["world"] = world_pos
	return best

func _start_lane_grab_candidate(lane_id: int, local_pos: Vector2, player_id: int, touch_index: int, arena_api: ArenaAPI) -> bool:
	if lane_id <= 0 or player_id <= 0 or arena_api == null:
		return false
	var lane: LaneData = arena_api.find_lane_by_id(lane_id)
	if lane == null:
		_log_lane_grab_cancel("lane_removed", lane_id, "", player_id)
		return false
	var side_info: Dictionary = _owned_active_lane_side(lane, player_id, arena_api)
	if side_info.is_empty():
		_log_lane_grab_cancel("enemy_lane", lane_id, "", player_id)
		return false
	_lane_grab_state = LANE_GRAB_STATE_CANDIDATE
	_lane_grab_touch_index = touch_index
	_lane_grab_player_id = player_id
	_lane_grab_lane_id = lane_id
	_lane_grab_side = str(side_info.get("side", ""))
	_lane_grab_src_id = int(side_info.get("src", -1))
	_lane_grab_dst_id = int(side_info.get("dst", -1))
	_lane_grab_press_ms = Time.get_ticks_msec()
	_lane_grab_start_local = local_pos
	_lane_grab_current_local = local_pos
	_lane_grab_reason = ""
	_lane_grab_constrained = false
	SFLog.info("LANE_GRAB_START", {
		"lane_id": lane_id,
		"side": _lane_grab_side,
		"src": _lane_grab_src_id,
		"dst": _lane_grab_dst_id,
		"player_id": player_id
	})
	return true

func _owned_active_lane_side(lane: LaneData, player_id: int, arena_api: ArenaAPI) -> Dictionary:
	if lane == null or player_id <= 0 or arena_api == null:
		return {}
	var a: HiveData = arena_api.find_hive_by_id(int(lane.a_id))
	var b: HiveData = arena_api.find_hive_by_id(int(lane.b_id))
	if a != null and bool(lane.send_a) and int(a.owner_id) == player_id:
		return {"side": "a", "src": int(lane.a_id), "dst": int(lane.b_id)}
	if b != null and bool(lane.send_b) and int(b.owner_id) == player_id:
		return {"side": "b", "src": int(lane.b_id), "dst": int(lane.a_id)}
	return {}

func _arm_lane_grab(arena_api: ArenaAPI) -> void:
	if _lane_grab_state != LANE_GRAB_STATE_CANDIDATE:
		return
	var lane: LaneData = arena_api.find_lane_by_id(_lane_grab_lane_id) if arena_api != null else null
	if lane == null:
		_cancel_lane_grab("lane_removed", arena_api, true)
		return
	var side_info: Dictionary = _owned_active_lane_side(lane, _lane_grab_player_id, arena_api)
	if side_info.is_empty():
		_cancel_lane_grab("enemy_lane", arena_api, true)
		return
	_lane_grab_state = LANE_GRAB_STATE_ARMED
	Input.vibrate_handheld(20)
	SFLog.info("LANE_GRAB_ARMED", {
		"lane_id": _lane_grab_lane_id,
		"side": _lane_grab_side,
		"player_id": _lane_grab_player_id
	})
	var metrics: Dictionary = _lane_grab_metrics(_lane_grab_current_local, arena_api)
	if bool(metrics.get("ok", false)):
		_set_lane_grab_preview(
			arena_api,
			true,
			metrics.get("closest", _lane_grab_current_local) as Vector2,
			_lane_grab_current_local
		)
	else:
		_set_lane_grab_preview(arena_api, false, Vector2.ZERO, Vector2.ZERO)

func _update_lane_grab_motion(local_pos: Vector2, arena_api: ArenaAPI) -> bool:
	if _lane_grab_state == LANE_GRAB_STATE_IDLE:
		return false
	_lane_grab_current_local = local_pos
	if _lane_grab_state == LANE_GRAB_STATE_CANDIDATE:
		if not _lane_grab_constrained and _lane_grab_structure_hit(local_pos, arena_api):
			_cancel_lane_grab("structure_hit", arena_api, true)
			return true
		if Time.get_ticks_msec() - _lane_grab_press_ms >= LANE_GRAB_ARM_MS:
			_arm_lane_grab(arena_api)
		return true
	if not _lane_grab_constrained and _lane_grab_structure_hit(local_pos, arena_api):
		_cancel_lane_grab("structure_hit", arena_api, true)
		return true
	var metrics: Dictionary = _lane_grab_metrics(local_pos, arena_api)
	if not bool(metrics.get("ok", false)):
		_cancel_lane_grab(str(metrics.get("reason", "lane_removed")), arena_api, true)
		return true
	var perp_dist: float = float(metrics.get("perp_dist", 0.0))
	if perp_dist >= _lane_grab_throw_distance_px():
		_lane_grab_state = LANE_GRAB_STATE_THROW_READY
	else:
		_lane_grab_state = LANE_GRAB_STATE_ARMED
	_set_lane_grab_preview(
		arena_api,
		true,
		metrics.get("closest", Vector2.ZERO) as Vector2,
		local_pos
	)
	return true

func _finish_lane_grab_release(local_pos: Vector2, arena_api: ArenaAPI) -> bool:
	if _lane_grab_state != LANE_GRAB_STATE_ARMED and _lane_grab_state != LANE_GRAB_STATE_THROW_READY:
		return false
	_update_lane_grab_motion(local_pos, arena_api)
	if _lane_grab_state == LANE_GRAB_STATE_THROW_READY:
		var lane_id: int = _lane_grab_lane_id
		var side: String = _lane_grab_side
		var src_id: int = _lane_grab_src_id
		var dst_id: int = _lane_grab_dst_id
		var player_id: int = _lane_grab_player_id
		_lane_grab_state = LANE_GRAB_STATE_COMMITTED
		_clear_lane_grab_preview(arena_api)
		_reset_lane_grab_state()
		arena_api.retract_lane(src_id, dst_id, player_id)
		Input.vibrate_handheld(35)
		SFLog.info("LANE_GRAB_RETRACT", {
			"lane_id": lane_id,
			"side": side,
			"src": src_id,
			"dst": dst_id,
			"player_id": player_id
		})
		return true
	var metrics: Dictionary = _lane_grab_metrics(local_pos, arena_api)
	var reason: String = "distance_too_short"
	if bool(metrics.get("ok", false)):
		var parallel_abs: float = float(metrics.get("parallel_abs", 0.0))
		var perp_dist: float = float(metrics.get("perp_dist", 0.0))
		if parallel_abs >= _lane_grab_throw_distance_px() and parallel_abs > perp_dist:
			reason = "drag_along_lane"
	_cancel_lane_grab(reason, arena_api, true)
	return true

func _lane_grab_throw_distance_px() -> float:
	return TUTORIAL_LANE_GRAB_THROW_DISTANCE_PX if _lane_grab_constrained else LANE_GRAB_THROW_DISTANCE_PX

func _lane_grab_structure_hit(local_pos: Vector2, arena_api: ArenaAPI) -> bool:
	if arena_api == null:
		return false
	var world_pos: Vector2 = _map_local_to_world(local_pos, arena_api)
	var target: Dictionary = _pick_target(world_pos, local_pos, arena_api)
	return int(target.get("id", -1)) > 0 and not str(target.get("type", "")).is_empty()

func _lane_grab_metrics(local_pos: Vector2, arena_api: ArenaAPI) -> Dictionary:
	if arena_api == null:
		return {"ok": false, "reason": "lane_removed"}
	var lane: LaneData = arena_api.find_lane_by_id(_lane_grab_lane_id)
	if lane == null:
		return {"ok": false, "reason": "lane_removed"}
	var side_info: Dictionary = _owned_active_lane_side(lane, _lane_grab_player_id, arena_api)
	if side_info.is_empty():
		return {"ok": false, "reason": "enemy_lane"}
	var seg: Dictionary = _lane_grab_segment_local(lane, arena_api)
	if not bool(seg.get("ok", false)):
		return {"ok": false, "reason": "lane_removed"}
	var start_pos: Vector2 = seg.get("start", Vector2.ZERO) as Vector2
	var end_pos: Vector2 = seg.get("end", Vector2.ZERO) as Vector2
	var axis: Vector2 = end_pos - start_pos
	var len_sq: float = axis.length_squared()
	if len_sq <= 0.000001:
		return {"ok": false, "reason": "lane_removed"}
	var t: float = clampf((local_pos - start_pos).dot(axis) / len_sq, 0.0, 1.0)
	var closest: Vector2 = start_pos.lerp(end_pos, t)
	var offset: Vector2 = local_pos - closest
	var lane_dir: Vector2 = axis.normalized()
	var from_start: Vector2 = local_pos - _lane_grab_start_local
	return {
		"ok": true,
		"closest": closest,
		"perp_dist": offset.length(),
		"parallel_abs": abs(from_start.dot(lane_dir))
	}

func _lane_grab_segment_local(lane: LaneData, arena_api: ArenaAPI) -> Dictionary:
	if lane == null or arena_api == null:
		return {"ok": false}
	var a_pos: Vector2 = Vector2.INF
	var b_pos: Vector2 = Vector2.INF
	var lr := _get_lane_renderer(arena_api)
	if lr != null and lr.has_method("get_lane_endpoints_world"):
		var ep: Dictionary = lr.call("get_lane_endpoints_world", int(lane.id), int(lane.a_id), int(lane.b_id))
		if bool(ep.get("ok", false)):
			var a_world_v: Variant = ep.get("start_world", null)
			var b_world_v: Variant = ep.get("end_world", null)
			if a_world_v is Vector2 and b_world_v is Vector2:
				a_pos = arena_api.world_to_map_local(a_world_v as Vector2)
				b_pos = arena_api.world_to_map_local(b_world_v as Vector2)
	if a_pos == Vector2.INF or b_pos == Vector2.INF:
		a_pos = _get_hive_pos_local(int(lane.a_id), arena_api)
		b_pos = _get_hive_pos_local(int(lane.b_id), arena_api)
	if a_pos == Vector2.INF or b_pos == Vector2.INF:
		return {"ok": false}
	var start_pos: Vector2 = a_pos
	var end_pos: Vector2 = b_pos
	if bool(lane.send_a) and bool(lane.send_b):
		var front_t: float = clampf(float(lane.last_impact_f), 0.05, 0.95)
		var front_pos: Vector2 = a_pos.lerp(b_pos, front_t)
		if _lane_grab_side == "a":
			end_pos = front_pos
		elif _lane_grab_side == "b":
			start_pos = front_pos
	elif _lane_grab_side == "b":
		start_pos = b_pos
		end_pos = a_pos
	return {"ok": true, "start": start_pos, "end": end_pos}

func _set_lane_grab_preview(arena_api: ArenaAPI, tension: bool, anchor_local: Vector2, pull_local: Vector2) -> void:
	var lr := _get_lane_renderer(arena_api)
	if lr == null or not lr.has_method("set_lane_grab_preview"):
		return
	var source_world: Vector2 = Vector2.ZERO
	var dest_world: Vector2 = Vector2.ZERO
	var pull_world: Vector2 = _map_local_to_world(pull_local, arena_api) if tension else Vector2.ZERO
	var anchor_world: Vector2 = _map_local_to_world(anchor_local, arena_api) if tension else Vector2.ZERO
	if tension:
		var lane: LaneData = arena_api.find_lane_by_id(_lane_grab_lane_id) if arena_api != null else null
		var seg: Dictionary = _lane_grab_segment_local(lane, arena_api)
		if bool(seg.get("ok", false)):
			source_world = _map_local_to_world(seg.get("start", Vector2.ZERO) as Vector2, arena_api)
			dest_world = _map_local_to_world(seg.get("end", Vector2.ZERO) as Vector2, arena_api)
	lr.call(
		"set_lane_grab_preview",
		_lane_grab_lane_id,
		_lane_grab_side,
		_lane_grab_state,
		source_world,
		dest_world,
		pull_world,
		anchor_world
	)

func _clear_lane_grab_preview(arena_api: ArenaAPI) -> void:
	var lr := _get_lane_renderer(arena_api)
	if lr != null and lr.has_method("clear_lane_grab_preview"):
		lr.call("clear_lane_grab_preview")

func _cancel_lane_grab(reason: String, arena_api: ArenaAPI, consume: bool) -> bool:
	if _lane_grab_state == LANE_GRAB_STATE_IDLE:
		return false
	_lane_grab_state = LANE_GRAB_STATE_CANCELLED
	_lane_grab_reason = reason
	_log_lane_grab_cancel(reason, _lane_grab_lane_id, _lane_grab_side, _lane_grab_player_id)
	_clear_lane_grab_preview(arena_api)
	_reset_lane_grab_state()
	return consume

func _log_lane_grab_cancel(reason: String, lane_id: int, side: String, player_id: int) -> void:
	SFLog.info("LANE_GRAB_CANCEL", {
		"reason": reason,
		"lane_id": lane_id,
		"side": side,
		"player_id": player_id
	})

func _reset_lane_grab_state() -> void:
	_lane_grab_state = LANE_GRAB_STATE_IDLE
	_lane_grab_touch_index = -1
	_lane_grab_player_id = -1
	_lane_grab_lane_id = -1
	_lane_grab_side = ""
	_lane_grab_src_id = -1
	_lane_grab_dst_id = -1
	_lane_grab_press_ms = 0
	_lane_grab_start_local = Vector2.ZERO
	_lane_grab_current_local = Vector2.ZERO
	_lane_grab_reason = ""
	_lane_grab_constrained = false

func _pick_barracks_id_at(pos_map_local: Vector2) -> int:
	var arena_api: ArenaAPI = _last_arena_api
	if arena_api == null:
		return -1
	var st: GameState = arena_api.get_state()
	if st == null or st.barracks == null:
		return -1
	var grid_spec: Object = arena_api.get_grid_spec()
	var best_id := -1
	var best_d := 1e18
	for barracks_any in st.barracks:
		var barracks_id := -1
		var gp := Vector2i.ZERO
		if barracks_any is Dictionary:
			var b: Dictionary = barracks_any as Dictionary
			barracks_id = int(b.get("id", -1))
			gp = _barracks_grid_pos(b)
		elif barracks_any is Object:
			var obj: Object = barracks_any as Object
			barracks_id = int(obj.get("id"))
			var gp_v: Variant = obj.get("grid_pos")
			if gp_v is Vector2i:
				gp = gp_v as Vector2i
			elif gp_v is Array:
				var gp_arr: Array = gp_v as Array
				if gp_arr.size() >= 2:
					gp = Vector2i(int(gp_arr[0]), int(gp_arr[1]))
			else:
				gp = Vector2i(int(obj.get("x")), int(obj.get("y")))
		else:
			continue
		if barracks_id <= 0:
			continue
		var center_world: Vector2
		if grid_spec != null:
			center_world = grid_spec.grid_to_world(gp)
		else:
			center_world = Vector2(
				(float(gp.x) + 0.5) * GameState.DEFAULT_CELL_SIZE,
				(float(gp.y) + 0.5) * GameState.DEFAULT_CELL_SIZE
			)
		var center_local: Vector2 = arena_api.world_to_map_local(center_world)
		var d := center_local.distance_to(pos_map_local)
		if d < best_d:
			best_d = d
			best_id = barracks_id
	if best_id != -1 and best_d <= BARRACKS_PICK_RADIUS_PX:
		SFLog.info("BARRACKS_PICK_HIT", {"bid": best_id, "dist": best_d, "pos": pos_map_local})
		return best_id
	return -1

func _pick_barracks_at_world(world_pos: Vector2, arena_api: ArenaAPI) -> int:
	if arena_api == null:
		return -1
	var st: GameState = arena_api.get_state()
	if st == null or st.barracks == null:
		return -1
	var grid_spec: Object = arena_api.get_grid_spec()
	var best_id: int = -1
	var best_dist_sq: float = INF
	var radius_sq: float = BARRACKS_PICK_RADIUS_PX * BARRACKS_PICK_RADIUS_PX
	for barracks_any in st.barracks:
		var barracks_id := -1
		var gp := Vector2i.ZERO
		if barracks_any is Dictionary:
			var b: Dictionary = barracks_any as Dictionary
			barracks_id = int(b.get("id", -1))
			gp = _barracks_grid_pos(b)
		elif barracks_any is Object:
			var obj: Object = barracks_any as Object
			barracks_id = int(obj.get("id"))
			var gp_v: Variant = obj.get("grid_pos")
			if gp_v is Vector2i:
				gp = gp_v as Vector2i
			elif gp_v is Array:
				var gp_arr: Array = gp_v as Array
				if gp_arr.size() >= 2:
					gp = Vector2i(int(gp_arr[0]), int(gp_arr[1]))
			else:
				gp = Vector2i(int(obj.get("x")), int(obj.get("y")))
		else:
			continue
		if barracks_id <= 0:
			continue
		var center: Vector2
		if grid_spec != null:
			center = grid_spec.grid_to_world(gp)
		else:
			center = Vector2(
				(float(gp.x) + 0.5) * GameState.DEFAULT_CELL_SIZE,
				(float(gp.y) + 0.5) * GameState.DEFAULT_CELL_SIZE
			)
		var dist_sq: float = center.distance_squared_to(world_pos)
		if dist_sq <= radius_sq and dist_sq < best_dist_sq:
			best_id = barracks_id
			best_dist_sq = dist_sq
	if best_id != -1:
		SFLog.info("BARRACKS_PICK_HIT", {
			"bid": best_id,
			"dist": sqrt(best_dist_sq),
			"r": BARRACKS_PICK_RADIUS_PX,
			"world": world_pos
		})
	return best_id

func _barracks_by_id_state(barracks_id: int, arena_api: ArenaAPI) -> Dictionary:
	if arena_api == null:
		return {}
	var st: GameState = arena_api.get_state()
	if st == null:
		return {}
	for barracks_any in st.barracks:
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = barracks_any as Dictionary
		if int(b.get("id", -1)) == barracks_id:
			return b
	return {}

func _barracks_allowed_ids(barracks_data: Dictionary) -> Array:
	var allowed: Array = []
	var seen: Dictionary = {}
	var control_v: Variant = barracks_data.get("control_hive_ids", [])
	if typeof(control_v) == TYPE_ARRAY:
		for hive_id_v in control_v as Array:
			var hive_id: int = int(hive_id_v)
			if hive_id > 0 and not seen.has(hive_id):
				seen[hive_id] = true
				allowed.append(hive_id)
	if allowed.is_empty():
		var required_v: Variant = barracks_data.get("required_hive_ids", [])
		if typeof(required_v) == TYPE_ARRAY:
			for hive_id_v in required_v as Array:
				var hive_id: int = int(hive_id_v)
				if hive_id > 0 and not seen.has(hive_id):
					seen[hive_id] = true
					allowed.append(hive_id)
	allowed.sort()
	return allowed

func _barracks_primary_control_id(barracks_data: Dictionary) -> int:
	var control_v: Variant = barracks_data.get("control_hive_ids", [])
	if typeof(control_v) == TYPE_ARRAY:
		var control_ids: Array = control_v as Array
		if not control_ids.is_empty():
			return int(control_ids[0])
	var required_v: Variant = barracks_data.get("required_hive_ids", [])
	if typeof(required_v) == TYPE_ARRAY:
		var required_ids: Array = required_v as Array
		if not required_ids.is_empty():
			return int(required_ids[0])
	return -1

func _barracks_route_from_state(barracks_data: Dictionary) -> Array:
	var allowed: Array = _barracks_allowed_ids(barracks_data)
	var allowed_lookup: Dictionary = {}
	for hive_id_v in allowed:
		allowed_lookup[int(hive_id_v)] = true
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
			if (allowed_lookup.is_empty() or allowed_lookup.has(target_id)) and not seen.has(target_id):
				seen[target_id] = true
				route.append(target_id)
	return route

func _flash_barracks_route_lane(barracks_id: int, hive_id: int, arena_api: ArenaAPI) -> void:
	if not ENABLE_ROUTE_LANE_FLASH:
		return
	if arena_api == null or barracks_id <= 0 or hive_id <= 0:
		return
	var st: GameState = arena_api.get_state()
	if st == null:
		return
	var b: Dictionary = _barracks_by_id_state(barracks_id, arena_api)
	if b.is_empty():
		return
	var src_id: int = _barracks_primary_control_id(b)
	if src_id <= 0 or src_id == hive_id:
		return
	if not st.lane_exists_between(src_id, hive_id):
		return
	var lane_id := -1
	var lane_index := st.lane_index_between(src_id, hive_id)
	if lane_index != -1 and lane_index < st.lanes.size():
		var lane_any: Variant = st.lanes[lane_index]
		if lane_any is LaneData:
			lane_id = int((lane_any as LaneData).id)
		elif lane_any is Dictionary:
			var d: Dictionary = lane_any as Dictionary
			lane_id = int(d.get("lane_id", d.get("id", -1)))
	if lane_id <= 0:
		return
	var lr := _get_lane_renderer(arena_api)
	if lr != null and lr.has_method("flash_lane"):
		lr.call("flash_lane", lane_id, ROUTE_LANE_FLASH_MS)

func _start_long_press_timer(player_id: int, arena_api: ArenaAPI) -> void:
	if arena_api == null:
		return
	var arena: Node = arena_api._arena
	if arena == null:
		return
	var timer: SceneTreeTimer = arena.get_tree().create_timer(float(LONG_PRESS_MS) / 1000.0)
	_long_press_timer = timer
	timer.timeout.connect(func() -> void:
		if _long_press_timer == timer:
			_long_press_timer = null
		if not _press_active or _press_consumed:
			return
		if _press_candidate_barracks_id == -1:
			return
		var dist_sq: float = _press_last_world.distance_squared_to(_press_start_world)
		var max_sq: float = LONG_PRESS_MOVE_PX * LONG_PRESS_MOVE_PX
		if dist_sq > max_sq:
			return
		SFLog.info("BARRACKS_LONG_PRESS_FIRE", {
			"actor": player_id,
			"bid": _press_candidate_barracks_id
		})
		var owner_id: int = -1
		var b_dict: Dictionary = _barracks_by_id_state(_press_candidate_barracks_id, arena_api)
		if not b_dict.is_empty():
			owner_id = int(b_dict.get("owner_id", -1))
		else:
			var st: GameState = arena_api.get_state()
			if st != null:
				for barracks_any in st.barracks:
					if barracks_any is Object:
						var obj: Object = barracks_any as Object
						if int(obj.get("id")) == _press_candidate_barracks_id:
							var owner_v: Variant = obj.get("owner_id")
							owner_id = int(owner_v) if owner_v != null else -1
							break
		var ok: bool = _select_barracks(_press_candidate_barracks_id, player_id, arena_api)
		if ok:
			_press_consumed = true
			SFLog.info("BARRACKS_SELECTED", {"bid": _press_candidate_barracks_id, "player": player_id})
		else:
			SFLog.info("BARRACKS_SELECT_DENY", {
				"bid": _press_candidate_barracks_id,
				"player": player_id,
				"owner": owner_id
			})
	)

func _select_barracks(barracks_id: int, player_id: int, arena_api: ArenaAPI) -> bool:
	var b: Dictionary = _barracks_by_id_state(barracks_id, arena_api)
	if b.is_empty():
		return false
	var owner_id: int = int(b.get("owner_id", 0))
	if owner_id <= 0 or owner_id != player_id:
		return false
	selected_barracks_id = barracks_id
	selected_barracks_player_id = player_id
	selected_structure_type = "barracks"
	selected_structure_id = barracks_id
	route_edit_mode = false
	barracks_route_buffer = _barracks_route_from_state(b)
	arena_api.set_barracks_select_id(barracks_id)
	arena_api.set_barracks_select_pid(player_id)
	arena_api.set_barracks_select_targets(barracks_route_buffer)
	arena_api.set_barracks_select_changed(false)
	arena_api.mark_render_dirty("barracks_select")
	var br := _get_barracks_renderer(arena_api)
	if br != null and br.has_method("set_selected_barracks"):
		br.call("set_selected_barracks", barracks_id, owner_id)
	var allowed_ids: Array = _barracks_allowed_ids(b)
	SFLog.info("BARRACKS_SELECT_BEGIN", {
		"bid": barracks_id,
		"player_id": player_id,
		"allowed_ids": allowed_ids,
		"initial_targets": barracks_route_buffer
	})
	SFLog.info("BARRACKS_SELECT", {
		"id": barracks_id,
		"owner_id": owner_id,
		"targets": barracks_route_buffer
	})
	SFLog.info("STRUCT_SELECT", {
		"type": "barracks",
		"id": barracks_id
	})
	return true

func _clear_barracks_selection(arena_api: ArenaAPI) -> void:
	selected_barracks_id = -1
	selected_barracks_player_id = -1
	selected_structure_type = ""
	selected_structure_id = -1
	route_edit_mode = false
	barracks_route_buffer.clear()
	if arena_api == null:
		return
	var br := _get_barracks_renderer(arena_api)
	if br != null:
		if br.has_method("clear_selected_barracks"):
			br.call("clear_selected_barracks")
		elif br.has_method("set_selected_barracks"):
			br.call("set_selected_barracks", -1, -1)
	arena_api.set_barracks_select_id(-1)
	arena_api.set_barracks_select_pid(-1)
	arena_api.clear_barracks_select_targets()
	arena_api.set_barracks_select_changed(false)
	arena_api.mark_render_dirty("barracks_select_clear")

func _commit_barracks_route(arena_api: ArenaAPI) -> void:
	if selected_barracks_id == -1:
		return
	var targets: Array = barracks_route_buffer.duplicate()
	var ok := arena_api.request_barracks_route(selected_barracks_id, targets, selected_barracks_player_id)
	SFLog.info("ROUTE_EDIT_APPLY", {
		"bid": selected_barracks_id,
		"ok": ok,
		"order": targets
	})
	SFLog.info("BARRACKS_ROUTE_COMMIT", {"id": selected_barracks_id, "targets": targets})
	SFLog.info("BARRACKS_DESELECT", {"id": selected_barracks_id})
	_clear_barracks_selection(arena_api)

func _add_barracks_route_target(hive_id: int, player_id: int, arena_api: ArenaAPI) -> bool:
	if selected_barracks_id == -1:
		return false
	var b: Dictionary = _barracks_by_id_state(selected_barracks_id, arena_api)
	if b.is_empty():
		return false
	var owner_id: int = int(b.get("owner_id", 0))
	if owner_id <= 0 or owner_id != player_id:
		return false
	var hive: HiveData = arena_api.find_hive_by_id(hive_id)
	if hive == null or hive.owner_id != owner_id:
		return false
	var allowed: Array = _barracks_allowed_ids(b)
	if not allowed.is_empty() and not allowed.has(hive_id):
		return false
	if barracks_route_buffer.has(hive_id):
		barracks_route_buffer.erase(hive_id)
		arena_api.set_barracks_select_targets(barracks_route_buffer)
		arena_api.set_barracks_select_changed(true)
		arena_api.mark_render_dirty("barracks_target_remove")
		SFLog.info("BARRACKS_TARGET_TOGGLE", {
			"bid": selected_barracks_id,
			"hid": hive_id,
			"action": "remove",
			"targets": barracks_route_buffer
		})
		SFLog.info("ROUTE_EDIT_REMOVE", {
			"bid": selected_barracks_id,
			"hid": hive_id,
			"order": barracks_route_buffer
		})
		_apply_barracks_route_update(arena_api)
		_flash_barracks_route_lane(selected_barracks_id, hive_id, arena_api)
		return true
	barracks_route_buffer.append(hive_id)
	arena_api.set_barracks_select_targets(barracks_route_buffer)
	arena_api.set_barracks_select_changed(true)
	arena_api.mark_render_dirty("barracks_target_add")
	SFLog.info("BARRACKS_TARGET_TOGGLE", {
		"bid": selected_barracks_id,
		"hid": hive_id,
		"action": "add",
		"targets": barracks_route_buffer
	})
	SFLog.info("ROUTE_EDIT_ADD", {
		"bid": selected_barracks_id,
		"hid": hive_id,
		"order": barracks_route_buffer
	})
	_apply_barracks_route_update(arena_api)
	_flash_barracks_route_lane(selected_barracks_id, hive_id, arena_api)
	return true

func handle_hive_pressed(hive_id: int, button: int, global_pos: Vector2, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	var local_pos := arena_api.world_to_map_local(global_pos)
	var dev_pid: int = _dev_mouse_pid_from_button(button)
	_handle_press(local_pos, hive_id, -1, dev_pid, arena_api, button)

func handle_hive_released(hive_id: int, button: int, global_pos: Vector2, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	var local_pos := arena_api.world_to_map_local(global_pos)
	var dev_pid: int = _dev_mouse_pid_from_button(button)
	_handle_release(local_pos, hive_id, -1, dev_pid, arena_api, button)

func _handle_hive_clicked(hive_id: int, button: int, global_pos: Vector2, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	handle_hive_pressed(hive_id, button, global_pos, arena_api)

func _handle_hive_released(hive_id: int, button: int, global_pos: Vector2, arena_api: ArenaAPI) -> void:
	handle_hive_released(hive_id, button, global_pos, arena_api)

func _is_dev_mouse_override() -> bool:
	return InputEventUtils.is_dev_mouse_override()

func _dev_mouse_pid_from_button(button_index: int) -> int:
	return InputEventUtils.dev_mouse_pid_from_button(button_index)

func _handle_press(local_pos: Vector2, hive_id: int, lane_id: int, dev_pid: int, arena_api: ArenaAPI, button_index: int, is_touch: bool = false, touch_index: int = -1, lane_grab_only: bool = false, lane_double_tap_only: bool = false, hive_tap_only: bool = false, hive_source_select_only: bool = false) -> void:
	if _handling_click:
		if SFLog.LOGGING_ENABLED:
			print("HIVE: re-entrant click blocked")
		return
	_handling_click = true
	if not InputEventUtils.is_player_pointer_button(button_index):
		reset_drag()
		_handling_click = false
		return
	var actor_id := _player_id_from_button(button_index, arena_api, dev_pid)
	SFLog.log_once("input_path_legacy_press", "INPUT_PATH: _handle_press", SFLog.Level.INFO)
	_press_active = true
	_press_consumed = false
	_press_start_ms = Time.get_ticks_msec()
	_press_started_ms = _press_start_ms
	_press_start_pos = local_pos
	_press_start_world = _map_local_to_world(local_pos, arena_api)
	_press_last_world = _press_start_world
	_press_start_screen = local_pos
	_press_candidate_barracks_id = -1
	_press_prev_selected_id = _get_selected_for_player(actor_id)
	_press_prev_selected_lane_id = selection.selected_lane_id
	_press_hive_id = hive_id
	_press_lane_id = lane_id
	_press_player_id = actor_id
	_press_is_touch = is_touch
	_press_lane_grab_only = lane_grab_only
	_press_lane_double_tap_only = lane_double_tap_only
	_press_hive_tap_only = hive_tap_only
	_press_hive_source_select_only = hive_source_select_only
	if _lane_grab_state != LANE_GRAB_STATE_IDLE:
		_cancel_lane_grab("touch_cancelled", arena_api, true)
	_clear_drag_target_visual(arena_api)
	var arena: Node = arena_api._arena if arena_api != null else null
	if arena != null:
		arena._handle_tap(hive_id, -1)
	else:
		if SFLog.LOGGING_ENABLED:
			print("HIVE: arena is NULL at click time")
	var world_pos: Vector2 = _map_local_to_world(local_pos, arena_api)
	var player_id: int = actor_id
	var hive_owner := -1
	var hive_friendly := false
	if hive_id > 0:
		var hive: HiveData = arena_api.find_hive_by_id(hive_id)
		if hive != null:
			hive_owner = int(hive.owner_id)
			hive_friendly = hive_owner == player_id
		SFLog.info("HIVE_CLICK_DEBUG", {
			"hive_id": hive_id,
			"hive_owner_id": hive_owner,
			"player_id": player_id,
			"dev_pid": dev_pid,
			"active_pid": arena_api.get_active_player_id(),
			"friendly": hive_friendly
		})
	if hive_id <= 0:
		_press_candidate_barracks_id = _pick_barracks_at_world(world_pos, arena_api)
		if _press_candidate_barracks_id != -1 and selected_barracks_id == -1:
			_start_long_press_timer(actor_id, arena_api)
	var barracks_id: int = _press_candidate_barracks_id
	if selected_barracks_id != -1:
		if hive_id > 0:
			_barracks_selector_toggle_hive(hive_id, actor_id, arena_api)
		elif barracks_id == -1:
			_end_barracks_selector(arena_api)
		_press_active = false
		reset_drag()
		_handling_click = false
		return
	if hive_id > 0:
		if lane_id <= 0:
			_reset_lane_tap_state()
		var hive: HiveData = arena_api.find_hive_by_id(hive_id)
		if hive == null:
			reset_drag()
			_handling_click = false
			return
		var friendly: bool = hive.owner_id == actor_id
		selection.drag_active = friendly
		selection.drag_moved = false
		selection.drag_start_hive_id = hive_id if friendly else -1
		selection.drag_start_owner_id = hive.owner_id
		selection.drag_start_pos = local_pos
		selection.drag_current_pos = local_pos
		selection.drag_hover_hive_id = -1
		selection.drag_hover_valid = false
		selection.drag_hover_reason = ""
		selection.last_vibe_target_id = -1
		selection.drag_dev_pid = actor_id
		if friendly:
			_set_selected_for_player(arena_api, actor_id, hive_id)
			selection.selected_cell = arena_api.cell_from_point(local_pos)
	else:
		selection.drag_active = false
		selection.drag_moved = false
		selection.drag_start_hive_id = -1
		selection.drag_start_owner_id = -1
		selection.drag_hover_hive_id = -1
		selection.drag_hover_valid = false
		selection.drag_hover_reason = ""
		selection.last_vibe_target_id = -1
		selection.drag_dev_pid = actor_id
		if _press_candidate_barracks_id == -1 and _pick_tower_at_local(local_pos, arena_api) == -1 and not lane_double_tap_only:
			var candidate_lane_id: int = _pick_lane_id_for_click(local_pos, lane_id, arena_api)
			var lane_grab_started: bool = _start_lane_grab_candidate(candidate_lane_id, local_pos, actor_id, touch_index if is_touch else -1, arena_api)
			if lane_grab_only:
				_reset_lane_tap_state()
				if lane_grab_started:
					_lane_grab_constrained = true
					_arm_lane_grab(arena_api)
	_handling_click = false
	_queue_lane_preview_redraw(arena_api)
	arena_api.mark_render_dirty("input_press")

func _handle_release(local_pos: Vector2, _hive_id: int, lane_id: int, dev_pid: int, arena_api: ArenaAPI, _button_index: int) -> void:
	if not _press_active:
		return
	_press_active = false
	var lane_grab_only: bool = _press_lane_grab_only
	_press_lane_grab_only = false
	var lane_double_tap_only: bool = _press_lane_double_tap_only
	_press_lane_double_tap_only = false
	var hive_tap_only: bool = _press_hive_tap_only
	_press_hive_tap_only = false
	var hive_source_select_only: bool = _press_hive_source_select_only
	_press_hive_source_select_only = false
	_press_last_world = _map_local_to_world(local_pos, arena_api)
	_press_candidate_barracks_id = -1
	if _press_consumed:
		_press_consumed = false
		reset_drag()
		_queue_lane_preview_redraw(arena_api)
		arena_api.mark_render_dirty("input_release")
		return
	selection.drag_current_pos = local_pos
	var player_id: int = _press_player_id
	if player_id <= 0:
		player_id = dev_pid if dev_pid != -1 else arena_api.get_active_player_id()
	var end_base_id: int = arena_api.pick_hive_id_local(local_pos)
	var end_id: int = _pick_hive_id_with_destination_assist(
		local_pos,
		end_base_id,
		player_id,
		arena_api,
		selection.drag_start_hive_id
	)
	var release_lane_id: int = _pick_lane_id_for_click(local_pos, lane_id, arena_api)
	if lane_double_tap_only and _press_lane_id > 0:
		release_lane_id = _press_lane_id
	SFLog.info("INPUT_RELEASE_STATE", {
		"player_id": player_id,
		"press_hive_id": _press_hive_id,
		"press_prev_selected_id": _press_prev_selected_id,
		"drag_start_hive_id": selection.drag_start_hive_id,
		"drag_moved": selection.drag_moved,
		"release_hive_id": end_id,
		"release_lane_id": release_lane_id,
		"is_touch": _press_is_touch
	})
	if _lane_grab_state == LANE_GRAB_STATE_CANDIDATE:
		_cancel_lane_grab("released_before_arm", arena_api, false)
	elif _lane_grab_state == LANE_GRAB_STATE_ARMED or _lane_grab_state == LANE_GRAB_STATE_THROW_READY:
		if _finish_lane_grab_release(local_pos, arena_api):
			_press_consumed = false
			reset_drag()
			_queue_lane_preview_redraw(arena_api)
			arena_api.mark_render_dirty("input_release_lane_grab")
			return
	if lane_grab_only:
		# A lane-only tutorial press cannot fall through into lane tap/double-tap
		# handling. An incomplete pull simply leaves the same action gate active.
		reset_drag()
		_queue_lane_preview_redraw(arena_api)
		arena_api.mark_render_dirty("input_release_lane_grab_only")
		return
	if selection.drag_active and selection.drag_moved and selection.drag_start_hive_id > 0:
		var start_id: int = selection.drag_start_hive_id
		if end_id > 0 and end_id != start_id:
			_apply_hive_to_hive_action(start_id, end_id, player_id, player_id, arena_api)
		_clear_selected_for_player(arena_api, player_id)
		_clear_drag_target_visual(arena_api)
		_reset_lane_tap_state()
		reset_drag()
		_queue_lane_preview_redraw(arena_api)
		arena_api.mark_render_dirty("input_release")
		return
	if _press_hive_id > 0:
		if hive_source_select_only:
			var source_hive: HiveData = arena_api.find_hive_by_id(_press_hive_id)
			if source_hive != null and int(source_hive.owner_id) == player_id:
				_set_selected_for_player(arena_api, player_id, _press_hive_id)
				if player_id == 1:
					selection.selected_cell = arena_api.cell_from_point(local_pos)
			clear_tap_state()
		elif not hive_tap_only and _should_route_hive_click_to_lane(_press_prev_selected_id, _press_hive_id, release_lane_id, local_pos, player_id, arena_api):
			SFLog.info("HIVE_CLICK_LANE_FALLTHROUGH", {
				"hive_id": _press_hive_id,
				"lane_id": release_lane_id,
				"player_id": player_id
			})
			_handle_click_ground(release_lane_id, local_pos, arena_api, player_id, lane_double_tap_only)
		else:
			_handle_click_hive(_press_prev_selected_id, _press_hive_id, player_id, player_id, arena_api, local_pos)
	else:
		_handle_click_ground(release_lane_id, local_pos, arena_api, player_id, lane_double_tap_only)
	_clear_drag_target_visual(arena_api)
	reset_drag()
	_queue_lane_preview_redraw(arena_api)
	arena_api.mark_render_dirty("input_release")

func _handle_drag(local_pos: Vector2, _hive_id: int, _lane_id: int, arena_api: ArenaAPI) -> void:
	if _lane_grab_state != LANE_GRAB_STATE_IDLE:
		if _update_lane_grab_motion(local_pos, arena_api):
			_queue_lane_preview_redraw(arena_api)
			arena_api.mark_render_dirty("lane_grab_drag")
			return
	if _press_active and _press_candidate_barracks_id != -1:
		var world_pos: Vector2 = _map_local_to_world(local_pos, arena_api)
		_press_last_world = world_pos
		var move_dist: float = world_pos.distance_to(_press_start_world)
		if move_dist > LONG_PRESS_MOVE_PX:
			_press_candidate_barracks_id = -1
	if not selection.drag_active:
		return
	selection.drag_current_pos = local_pos
	if selection.drag_current_pos.distance_to(selection.drag_start_pos) >= arena_api.get_drag_deadzone_px():
		selection.drag_moved = true
	_queue_lane_preview_redraw(arena_api)
	arena_api.mark_render_dirty("input_drag")
	if not selection.drag_moved:
		return
	var hover_id: int = _pick_drag_hover_hive_id(local_pos, arena_api)
	if hover_id > 0 and hover_id != selection.drag_start_hive_id:
		selection.drag_hover_hive_id = hover_id
		var validation: Dictionary = _validate_target(selection.drag_start_hive_id, hover_id, arena_api)
		var hover_valid: bool = bool(validation.get("ok", false))
		selection.drag_hover_valid = hover_valid
		selection.drag_hover_reason = str(validation.get("reason", ""))
		_set_drag_target_visual(arena_api, hover_id, hover_valid, selection.drag_hover_reason)
		if hover_valid and arena_api.lane_exists_between(selection.drag_start_hive_id, hover_id):
			if hover_id != selection.last_vibe_target_id:
				Input.vibrate_handheld(30)
				selection.last_vibe_target_id = hover_id
		else:
			selection.last_vibe_target_id = -1
		return
	selection.drag_hover_hive_id = -1
	selection.drag_hover_valid = false
	selection.drag_hover_reason = ""
	_clear_drag_target_visual(arena_api)
	selection.last_vibe_target_id = -1

func _handle_tap(hive_id: int, dev_pid: int, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	if hive_id <= 0:
		clear_tap_state()
		return
	var hive: HiveData = arena_api.find_hive_by_id(hive_id)
	if hive == null:
		clear_tap_state()
		return
	selection.tap_first_id = hive_id
	selection.tap_first_owner_id = hive.owner_id
	selection.tap_dev_pid = dev_pid

func _handle_click_hive(prev_selected_id: int, clicked_id: int, player_id: int, dev_pid: int, arena_api: ArenaAPI, local_pos: Vector2) -> void:
	if selected_barracks_id != -1:
		return
	_reset_lane_tap_state()
	var hive: HiveData = arena_api.find_hive_by_id(clicked_id)
	if hive == null:
		clear_tap_state()
		return
	var world_pos := _map_local_to_world(local_pos, arena_api)
	SFLog.info("INPUT_CLICK", {
		"player_id": player_id,
		"hid": clicked_id,
		"prev_selected_id": prev_selected_id,
		"world": world_pos
	})
	var enemy_first_id: int = _get_enemy_first_for_player(player_id)
	var clicked_owned: bool = hive.owner_id == player_id
	var clicked_ally: bool = _are_allied_seats(player_id, hive.owner_id)
	if enemy_first_id > 0:
		_clear_enemy_first_for_player(player_id)
		_clear_enemy_first_visual(arena_api, player_id)
		SFLog.info("ENEMY_FIRST_CLEAR", {"enemy_id": enemy_first_id, "reason": "enemy_unselectable"})
		clear_tap_state()
	if prev_selected_id != -1 and prev_selected_id != clicked_id:
		_apply_hive_to_hive_action(prev_selected_id, clicked_id, player_id, dev_pid, arena_api)
		_clear_selected_for_player(arena_api, player_id)
		clear_tap_state()
		return
	if prev_selected_id > 0 and prev_selected_id == clicked_id:
		_clear_selected_for_player(arena_api, player_id)
		clear_tap_state()
		return
	if not clicked_owned:
		_clear_selected_for_player(arena_api, player_id)
		clear_tap_state()
		SFLog.info("HIVE_CLICK_UNSELECTABLE", {
			"hive_id": clicked_id,
			"owner_id": int(hive.owner_id),
			"player_id": player_id,
			"ally": clicked_ally
		})
		return
	if clicked_owned:
		_set_selected_for_player(arena_api, player_id, clicked_id)
		if player_id == 1:
			selection.selected_cell = arena_api.cell_from_point(local_pos)
	clear_tap_state()

func _handle_click_ground(lane_id: int, local_pos: Vector2, arena_api: ArenaAPI, player_id: int, lane_double_tap_only: bool = false) -> void:
	if selected_barracks_id != -1:
		var world_pos: Vector2 = _map_local_to_world(local_pos, arena_api)
		var barracks_id: int = _pick_barracks_at_world(world_pos, arena_api)
		if barracks_id == -1:
			_end_barracks_selector(arena_api)
		clear_tap_state()
		return
	if _get_enemy_first_for_player(player_id) > 0:
		_clear_enemy_first_for_player(player_id)
		_clear_enemy_first_visual(arena_api, player_id)
	if lane_id != -1:
		var lane: LaneData = arena_api.find_lane_by_id(lane_id)
		if lane != null:
			if _is_lane_double_tap(lane.id, local_pos, player_id, _press_is_touch):
				_reset_lane_tap_state()
				var handled_double_tap: bool = _handle_lane_swarm_double_tap_by_id(lane.id, player_id, arena_api) if lane_double_tap_only else _handle_lane_double_tap(local_pos, player_id, player_id, arena_api)
				if handled_double_tap:
					_clear_selected_for_player(arena_api, player_id)
					selection.selected_lane_id = -1
					clear_tap_state()
					return
			_record_lane_tap(lane.id, local_pos, player_id)
			_clear_selected_for_player(arena_api, player_id)
			selection.selected_lane_id = -1
			selection.selected_cell = arena_api.cell_from_point(local_pos)
			return
	_reset_lane_tap_state()
	_clear_selected_for_player(arena_api, player_id)
	selection.selected_lane_id = -1
	selection.selected_cell = arena_api.cell_from_point(local_pos)
	arena_api.dbg("SF: Cell selected %d,%d" % [selection.selected_cell.x, selection.selected_cell.y])
	clear_tap_state()

func _handle_lane_swarm_double_tap_by_id(lane_id: int, player_id: int, arena_api: ArenaAPI) -> bool:
	if lane_id <= 0 or player_id <= 0 or arena_api == null:
		return false
	var lane: LaneData = arena_api.find_lane_by_id(lane_id)
	if lane == null:
		return false
	var src_id: int = _owned_active_lane_source(lane, player_id, arena_api)
	if src_id <= 0:
		return false
	var dst_id: int = int(lane.b_id) if src_id == int(lane.a_id) else int(lane.a_id)
	if dst_id <= 0 or not arena_api.intent_is_on(src_id, dst_id):
		return false
	SFLog.info("LANE_DBL_SWARM", {
		"lane_id": lane_id,
		"src": src_id,
		"dst": dst_id,
		"tutorial_target_half": true
	})
	return _issue_swarm_intent(src_id, dst_id, player_id)

func _apply_hive_to_hive_action(from_id: int, to_id: int, player_id: int, dev_pid: int, arena_api: ArenaAPI) -> Dictionary:
	var rejected: Dictionary = {
		"ok": false,
		"src": from_id,
		"dst": to_id,
		"reason": "invalid"
	}
	if from_id <= 0 or to_id <= 0 or from_id == to_id:
		return rejected
	var from_hive: HiveData = arena_api.find_hive_by_id(from_id)
	var to_hive: HiveData = arena_api.find_hive_by_id(to_id)
	if from_hive == null or to_hive == null:
		rejected["reason"] = "missing_hive"
		return rejected
	var from_owned: bool = from_hive.owner_id == player_id
	var to_owned: bool = to_hive.owner_id == player_id
	if from_owned:
		var lane_active: bool = arena_api.is_outgoing_lane_active(from_id, to_id)
		var action := "swarm" if lane_active else "establish"
		SFLog.info("SRC_DST_ACTION", {
			"src": from_id,
			"dst": to_id,
			"lane_active": lane_active,
			"action": action
		})
		if lane_active:
			return _issue_swarm_intent_result(from_id, to_id, player_id)
		return _issue_intent(from_id, to_id, player_id, dev_pid, arena_api)
	if not from_owned and to_owned:
		if arena_api.intent_is_on(to_id, from_id):
			arena_api.retract_lane(to_id, from_id, player_id)
			return {
				"ok": true,
				"src": to_id,
				"dst": from_id,
				"intent": "none",
				"reason": ""
			}
	rejected["reason"] = "ownership"
	return rejected

func _issue_intent(from_id: int, to_id: int, player_id: int, dev_pid: int, arena_api: ArenaAPI) -> Dictionary:
	SFLog.allow_tag("INPUT_INTENT_REJECTED")
	var src_owner := int(arena_api.get_hive_owner_id(from_id))
	var dst_owner := int(arena_api.get_hive_owner_id(to_id))
	var same_team: bool = _are_allied_seats(src_owner, dst_owner)
	if same_team:
		var result := OpsState.apply_lane_intent(from_id, to_id, "feed")
		if bool(result.get("ok", false)):
			SFLog.info("INPUT_INTENT", {"player_id": player_id, "src": from_id, "dst": to_id, "intent": "feed"})
			SFLog.info("INTENT_FEED", {"src": from_id, "dst": to_id})
		else:
			SFLog.warn("INPUT_INTENT_REJECTED", {
				"player_id": player_id,
				"src": from_id,
				"dst": to_id,
				"intent": "feed",
				"reason": str(result.get("reason", "unknown"))
			})
			_maybe_notify_wall_blocked_attempt(from_id, to_id, "feed", arena_api)
		return result
	var result := OpsState.apply_lane_intent(from_id, to_id, "attack")
	if bool(result.get("ok", false)):
		SFLog.info("INPUT_INTENT", {"player_id": player_id, "src": from_id, "dst": to_id, "intent": "attack"})
		SFLog.info("INTENT_ATTACK", {"src": from_id, "dst": to_id})
	else:
		SFLog.warn("INPUT_INTENT_REJECTED", {
			"player_id": player_id,
			"src": from_id,
			"dst": to_id,
			"intent": "attack",
			"reason": str(result.get("reason", "unknown"))
		})
		_maybe_notify_wall_blocked_attempt(from_id, to_id, "attack", arena_api)
	return result

func _issue_swarm_intent_result(from_id: int, to_id: int, player_id: int) -> Dictionary:
	var result := OpsState.apply_lane_intent(from_id, to_id, "swarm")
	var ok := bool(result.get("ok", false))
	if ok:
		SFLog.info("INPUT_INTENT", {"player_id": player_id, "src": from_id, "dst": to_id, "intent": "swarm"})
		SFLog.info("LANE_SWARM_INTENT", {"src": from_id, "dst": to_id, "player_id": player_id})
	else:
		SFLog.warn("INPUT_INTENT_REJECTED", {
			"player_id": player_id,
			"src": from_id,
			"dst": to_id,
			"intent": "swarm",
			"reason": str(result.get("reason", "unknown"))
		})
	return result

func _issue_swarm_intent(from_id: int, to_id: int, player_id: int) -> bool:
	var result := _issue_swarm_intent_result(from_id, to_id, player_id)
	return bool(result.get("ok", false))

func _maybe_notify_wall_blocked_attempt(from_id: int, to_id: int, intent: String, arena_api: ArenaAPI) -> void:
	if arena_api == null:
		return
	if not _is_route_blocked_by_wall(from_id, to_id, arena_api):
		return
	arena_api.notify_wall_blocked_attempt(from_id, to_id, intent)

func _is_route_blocked_by_wall(from_id: int, to_id: int, arena_api: ArenaAPI) -> bool:
	if arena_api == null:
		return false
	var st: GameState = arena_api.get_state()
	if st == null or st.walls == null or st.walls.is_empty():
		return false
	var src_hive: HiveData = arena_api.find_hive_by_id(from_id)
	var dst_hive: HiveData = arena_api.find_hive_by_id(to_id)
	if src_hive == null or dst_hive == null:
		return false
	var wall_segments: Array = MAP_SCHEMA._wall_segments_from_walls(st.walls)
	if wall_segments.is_empty():
		return false
	var a_grid: Vector2 = Vector2(float(src_hive.grid_pos.x), float(src_hive.grid_pos.y))
	var b_grid: Vector2 = Vector2(float(dst_hive.grid_pos.x), float(dst_hive.grid_pos.y))
	return MAP_SCHEMA._segment_intersects_any_wall(a_grid, b_grid, wall_segments)

func _handle_lane_double_tap(local_pos: Vector2, dev_pid: int, pid: int, arena_api: ArenaAPI) -> bool:
	var world_pos: Vector2 = _map_local_to_world(local_pos, arena_api)
	var hit: Dictionary = _pick_lane_hit(world_pos, arena_api)
	if not bool(hit.get("hit", false)):
		SFLog.info("LANE_PICK_MISS", {"world": world_pos})
		return false
	var lane_id: int = int(hit.get("lane_id", -1))
	if lane_id <= 0:
		return false
	SFLog.info("LANE_PICK_HIT", {
		"lane_id": lane_id,
		"t": float(hit.get("t", 0.0)),
		"dist": float(hit.get("dist", 0.0))
	})
	var lane: LaneData = arena_api.find_lane_by_id(lane_id)
	if lane == null:
		return false
	var player_id: int = pid
	if player_id == -1:
		player_id = dev_pid if dev_pid != -1 else arena_api.get_active_player_id()
	var a: HiveData = arena_api.find_hive_by_id(lane.a_id)
	var b: HiveData = arena_api.find_hive_by_id(lane.b_id)
	if a == null or b == null:
		return false
	var tap_t: float = clampf(float(hit.get("t", 0.5)), 0.0, 1.0)
	var src_id: int = -1
	var dst_id: int = -1
	if lane.send_a and int(a.owner_id) == player_id:
		src_id = int(a.id)
		dst_id = int(b.id)
	elif lane.send_b and int(b.owner_id) == player_id:
		src_id = int(b.id)
		dst_id = int(a.id)
	if src_id <= 0 or dst_id <= 0:
		return false
	if arena_api.intent_is_on(src_id, dst_id):
		if _tap_t_is_near_lane_source(lane, src_id, tap_t):
			SFLog.info("LANE_DBL_RETRACT", {"lane_id": lane_id, "src": src_id, "dst": dst_id, "t": tap_t})
			arena_api.retract_lane(src_id, dst_id, player_id)
			return true
		SFLog.info("LANE_DBL_SWARM", {"lane_id": lane_id, "src": src_id, "dst": dst_id, "t": tap_t})
		_issue_swarm_intent(src_id, dst_id, player_id)
		return true
	return false

func _is_lane_source_retract_tap(lane_id: int, local_pos: Vector2, player_id: int, arena_api: ArenaAPI) -> bool:
	if lane_id <= 0 or player_id <= 0 or arena_api == null:
		return false
	var lane: LaneData = arena_api.find_lane_by_id(lane_id)
	if lane == null:
		return false
	var world_pos: Vector2 = _map_local_to_world(local_pos, arena_api)
	var hit: Dictionary = _pick_lane_hit(world_pos, arena_api)
	if not bool(hit.get("hit", false)):
		return false
	if int(hit.get("lane_id", -1)) != lane_id:
		return false
	var tap_t: float = clampf(float(hit.get("t", 0.5)), 0.0, 1.0)
	var src_id: int = _owned_active_lane_source(lane, player_id, arena_api)
	if src_id <= 0:
		return false
	return _tap_t_is_near_lane_source(lane, src_id, tap_t)

func _owned_active_lane_source(lane: LaneData, player_id: int, arena_api: ArenaAPI) -> int:
	if lane == null or player_id <= 0 or arena_api == null:
		return -1
	var a: HiveData = arena_api.find_hive_by_id(lane.a_id)
	var b: HiveData = arena_api.find_hive_by_id(lane.b_id)
	if a != null and lane.send_a and int(a.owner_id) == player_id:
		return int(a.id)
	if b != null and lane.send_b and int(b.owner_id) == player_id:
		return int(b.id)
	return -1

func _tap_t_is_near_lane_source(lane: LaneData, src_id: int, tap_t: float) -> bool:
	if lane == null or src_id <= 0:
		return false
	if src_id == int(lane.a_id):
		return tap_t <= LANE_SOURCE_RETRACT_T
	if src_id == int(lane.b_id):
		return tap_t >= 1.0 - LANE_SOURCE_RETRACT_T
	return false

func _lane_side_for_tap(lane: LaneData, mode: String, tap_f: float) -> String:
	var mid_deadzone: float = 0.02
	if mode == "opposing" and lane.send_a and lane.send_b:
		var impact_f: float = clampf(lane.last_impact_f, 0.0, 1.0)
		if tap_f < impact_f - mid_deadzone:
			return "a"
		if tap_f > impact_f + mid_deadzone:
			return "b"
		return ""
	if tap_f < 0.5 - mid_deadzone:
		return "a"
	if tap_f > 0.5 + mid_deadzone:
		return "b"
	return ""

func _project_t_on_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	if ab.length_squared() == 0.0:
		return 0.0
	var t: float = (p - a).dot(ab) / ab.length_squared()
	return clampf(t, 0.0, 1.0)

func _toggle_barracks_selector(barracks_id: int, dev_pid: int, arena_api: ArenaAPI) -> bool:
	if selected_barracks_id == barracks_id:
		_end_barracks_selector(arena_api)
		return true
	return _start_barracks_selector(barracks_id, dev_pid, arena_api)

func _toggle_route_edit(barracks_id: int) -> void:
	if selected_barracks_id != barracks_id:
		return
	route_edit_mode = not route_edit_mode
	SFLog.info("ROUTE_EDIT_TOGGLE", {
		"id": barracks_id,
		"enabled": route_edit_mode
	})

func _start_barracks_selector(barracks_id: int, dev_pid: int, arena_api: ArenaAPI) -> bool:
	var player_id: int = dev_pid if dev_pid != -1 else arena_api.get_active_player_id()
	if not _select_barracks(barracks_id, player_id, arena_api):
		return false
	arena_api.dbg("SF: barracks %d select ON" % barracks_id)
	return true

func _end_barracks_selector(arena_api: ArenaAPI) -> void:
	if selected_barracks_id == -1:
		return
	var barracks_id: int = selected_barracks_id
	SFLog.info("BARRACKS_SELECT_END", {
		"bid": barracks_id,
		"targets": barracks_route_buffer
	})
	_commit_barracks_route(arena_api)
	arena_api.dbg("SF: barracks %d select OFF" % barracks_id)
	_press_candidate_barracks_id = -1

func _clear_barracks_route(arena_api: ArenaAPI) -> void:
	if selected_barracks_id == -1:
		return
	if barracks_route_buffer.is_empty():
		return
	barracks_route_buffer.clear()
	arena_api.set_barracks_select_targets(barracks_route_buffer)
	arena_api.set_barracks_select_changed(true)
	arena_api.mark_render_dirty("barracks_target_clear")
	SFLog.info("ROUTE_EDIT_CLEAR", {"bid": selected_barracks_id})
	_apply_barracks_route_update(arena_api)

func _apply_barracks_route_update(arena_api: ArenaAPI) -> void:
	if arena_api == null:
		return
	if selected_barracks_id == -1:
		return
	var targets: Array = barracks_route_buffer.duplicate()
	var ok := arena_api.request_barracks_route(selected_barracks_id, targets, selected_barracks_player_id)
	SFLog.info("ROUTE_EDIT_APPLY", {
		"bid": selected_barracks_id,
		"ok": ok,
		"order": targets
	})

func _barracks_selector_toggle_hive(hive_id: int, dev_pid: int, arena_api: ArenaAPI) -> bool:
	var player_id: int = dev_pid if dev_pid != -1 else arena_api.get_active_player_id()
	return _add_barracks_route_target(hive_id, player_id, arena_api)
