# NOTE: Add per-player selection for left/right mouse and discrete input logs.
# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name InputSystem
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")

const DOUBLE_TAP_MS := 250
const DOUBLE_TAP_DIST_PX := 12.0
const CLICK_DBL_MS := 250
const CLICK_DBL_DIST_PX := 14.0
const LANE_PICK_RADIUS := 22.0
const BARRACKS_PICK_RADIUS_PX := 48.0
const TOWER_PICK_RADIUS_PX := 40.0
const STRUCTURE_PICK_BIAS := 0.95
const LONG_PRESS_MS := 400
const LONG_PRESS_MOVE_PX := 12.0
const ENABLE_ROUTE_LANE_FLASH := true
const ROUTE_LANE_FLASH_MS := 250

var selection: SelectionState = null
var _last_tap_time_ms: int = 0
var _last_tap_pos: Vector2 = Vector2.ZERO
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
var _hover_hive_id: int = -1
var _selected_hive_id: int = -1 # P1 selection mirror
var _selected_by_player: Dictionary = {1: -1, 2: -1}
var _enemy_first_by_player: Dictionary = {1: -1, 2: -1}
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

func setup(selection_state: SelectionState) -> void:
	if selection_state != null:
		selection = selection_state
	else:
		selection = SelectionState.new()
	_selected_by_player[1] = selection.selected_hive_id if selection != null else -1
	_selected_by_player[2] = -1
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
	pass

func _clear_interaction_state() -> void:
	_press_active = false
	_press_consumed = false
	_press_candidate_barracks_id = -1
	_press_hive_id = -1
	_press_lane_id = -1
	_press_player_id = -1
	_press_prev_selected_id = -1
	_press_prev_selected_lane_id = -1
	_dragging = false
	_drag_src_id = -1
	if _long_press_timer != null:
		_long_press_timer = null
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
			else:
				# Quick buff test hotkey: P1 slot 2 (default: Faster Production).
				arena_api.try_activate_buff_slot(1, 1)
				arena_api.dbg("SF: buff hotkey B -> P1 slot 2")
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
		if event.keycode == KEY_Z:
			arena_api.try_activate_buff_slot(arena_api.get_active_player_id(), 0)
		if event.keycode == KEY_X:
			arena_api.try_activate_buff_slot(arena_api.get_active_player_id(), 1)
		if event.keycode == KEY_C:
			arena_api.try_activate_buff_slot(arena_api.get_active_player_id(), 2)
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
	if event_type != "motion" and not (button_index == MOUSE_BUTTON_LEFT or button_index == MOUSE_BUTTON_RIGHT):
		return
	var actor_id: int = _player_id_from_button(button_index, arena_api)
	SFLog.log_once("input_path_pointer", "INPUT_PATH: handle_pointer_event", SFLog.Level.INFO)
	var local_pos: Vector2 = ev.get("local_pos", Vector2.ZERO)
	var world_pos: Vector2 = ev.get("world_pos", local_pos)
	var screen_pos: Vector2 = ev.get("screen_pos", Vector2.ZERO)
	var map_local: Vector2 = local_pos
	if event_type == "motion":
		if _press_active and _press_candidate_barracks_id != -1:
			_press_last_world = world_pos
			var move_dist: float = map_local.distance_to(_press_start_pos)
			if move_dist > LONG_PRESS_MOVE_PX:
				_press_candidate_barracks_id = -1
		return
	if event_type == "press":
		_press_active = true
		_press_consumed = false
		_press_start_ms = Time.get_ticks_msec()
		_press_started_ms = _press_start_ms
		_press_start_pos = map_local
		_press_start_world = world_pos
		_press_last_world = world_pos
		_press_start_screen = screen_pos
		_press_candidate_barracks_id = _pick_barracks_id_at(map_local)
		if _press_candidate_barracks_id != -1:
			_start_long_press_timer(actor_id, arena_api)
			return
		return
	if event_type != "release":
		return
	_press_active = false
	_press_last_world = world_pos
	if _press_consumed:
		_press_consumed = false
		_press_candidate_barracks_id = -1
		return
	_press_candidate_barracks_id = -1
	map_local = arena_api.world_to_map_local(world_pos)
	var pick: Dictionary = _pick_target(world_pos, map_local, arena_api)
	var pick_type: String = str(pick.get("type", ""))
	var pick_id: int = int(pick.get("id", -1))
	var pick_dist: float = float(pick.get("dist", INF))
	if pick_type == "" or pick_id <= 0:
		var hinted_hive_id: int = int(ev.get("hive_id", -1))
		if hinted_hive_id <= 0:
			hinted_hive_id = int(arena_api.hive_id_at_point(map_local))
		if hinted_hive_id > 0:
			pick_type = "hive"
			pick_id = hinted_hive_id
			var nearest_hint: Dictionary = arena_api.get_nearest_hive_local(map_local)
			pick_dist = float(nearest_hint.get("dist", 0.0))
	var hid: int = pick_id if pick_type == "hive" else -1
	var barracks_id: int = pick_id if pick_type == "barracks" else -1
	var tower_id: int = pick_id if pick_type == "tower" else -1
	SFLog.warn("INPUT_RELEASE_PICK", {
		"phase": int(OpsState.match_phase),
		"inputs_locked": inputs_locked,
		"ops_locked": bool(OpsState.input_locked),
		"ops_reason": str(OpsState.input_locked_reason),
		"actor_id": actor_id,
		"pick_type": pick_type,
		"pick_id": pick_id,
		"hid": hid,
		"local_pos": map_local,
		"world_pos": world_pos
	})
	var nearest := arena_api.get_nearest_hive_local(map_local)
	var now_ms: int = Time.get_ticks_msec()
	var dt_ms: int = now_ms - _last_click_ms
	var dist: float = world_pos.distance_to(_last_click_world)
	var is_dbl: bool = dt_ms <= CLICK_DBL_MS and dist <= CLICK_DBL_DIST_PX
	if pick_type == "barracks" or pick_type == "tower":
		SFLog.info("PICK_HIT", {
			"world": world_pos,
			"type": pick_type,
			"id": pick_id,
			"dist": pick_dist
		})
	if selected_barracks_id != -1 and event_type == "release" and route_edit_mode:
		if button_index == MOUSE_BUTTON_RIGHT:
			_clear_barracks_route(arena_api)
			_last_click_ms = now_ms
			_last_click_world = world_pos
			return
		if hid > 0:
			_barracks_selector_toggle_hive(hid, actor_id, arena_api)
		else:
			_end_barracks_selector(arena_api)
		_last_click_ms = now_ms
		_last_click_world = world_pos
		return
	SFLog.info("CLICK_PICK_DEBUG", {
		"screen": screen_pos,
		"world": world_pos,
		"map_local": map_local,
		"hid": hid,
		"pick_type": pick_type,
		"pick_id": pick_id,
		"pick_dist": pick_dist,
		"tower_id": tower_id,
		"nearest_id": int(nearest.get("id", -1)),
		"nearest_dist": float(nearest.get("dist", -1.0)),
		"nearest_center": nearest.get("center", Vector2.INF),
		"radius": arena_api.get_hive_radius_px()
	})
	SFLog.info("INPUT_CLICK", {
		"player_id": actor_id,
		"hid": hid,
		"pick_type": pick_type,
		"pick_id": pick_id,
		"world": world_pos
	})
	SFLog.info("CLICK_DBL_CHECK", {
		"is_dbl": is_dbl,
		"dt_ms": dt_ms,
		"dist": dist,
		"hid": hid,
		"world": world_pos
	})
	if is_dbl:
		if barracks_id != -1 and selected_barracks_id == -1:
			SFLog.info("BARRACKS_DBL_SELECT", {
				"bid": barracks_id,
				"player_id": actor_id,
				"world": world_pos
			})
			_start_barracks_selector(barracks_id, actor_id, arena_api)
			_last_click_ms = now_ms
			_last_click_world = world_pos
			return
		var hit: Dictionary = _pick_lane_hit(world_pos, arena_api)
		if bool(hit.get("hit", false)):
			var lane_id: int = int(hit.get("lane_id", -1))
			var lane: LaneData = arena_api.find_lane_by_id(lane_id)
			if lane != null:
				var a: HiveData = arena_api.find_hive_by_id(lane.a_id)
				var b: HiveData = arena_api.find_hive_by_id(lane.b_id)
				if a != null and b != null:
					var src_id: int = -1
					var dst_id: int = -1
					var src_is_a: bool = false
					if lane.send_a and int(a.owner_id) == actor_id:
						src_id = int(a.id)
						dst_id = int(b.id)
						src_is_a = true
					elif lane.send_b and int(b.owner_id) == actor_id:
						src_id = int(b.id)
						dst_id = int(a.id)
						src_is_a = false
					if src_id > 0 and dst_id > 0:
						var a_pos: Vector2 = arena_api.cell_center(a.grid_pos)
						var b_pos: Vector2 = arena_api.cell_center(b.grid_pos)
						var src_pos: Vector2 = a_pos if src_is_a else b_pos
						var dst_pos: Vector2 = b_pos if src_is_a else a_pos
						var tap_is_src_half: bool = world_pos.distance_to(src_pos) <= world_pos.distance_to(dst_pos)
						if tap_is_src_half:
							if arena_api.intent_is_on(src_id, dst_id):
								SFLog.info("LANE_DBL_RETRACT", {"lane_id": lane_id, "src": src_id, "dst": dst_id})
								SFLog.info("LANE_RETRACT_INTENT", {"lane_id": lane_id, "src": src_id, "dst": dst_id, "player_id": actor_id})
								arena_api.retract_lane(src_id, dst_id, actor_id)
								_last_click_ms = now_ms
								_last_click_world = world_pos
								return
						elif arena_api.intent_is_on(src_id, dst_id):
							SFLog.info("LANE_DBL_SWARM", {"lane_id": lane_id, "src": src_id, "dst": dst_id})
							_issue_swarm_intent(src_id, dst_id, actor_id)
							_last_click_ms = now_ms
							_last_click_world = world_pos
							return
		_last_click_ms = now_ms
		_last_click_world = world_pos
		return
	_last_click_ms = now_ms
	_last_click_world = world_pos
	if barracks_id != -1:
		if selected_barracks_id == -1:
			route_edit_mode = false
			SFLog.info("BARRACKS_CLICK_SELECT", {"bid": barracks_id, "player": actor_id})
			_start_barracks_selector(barracks_id, actor_id, arena_api)
			return
		if selected_barracks_id == barracks_id:
			_toggle_route_edit(barracks_id)
			return
		_end_barracks_selector(arena_api)
		route_edit_mode = false
		SFLog.info("BARRACKS_CLICK_SELECT", {"bid": barracks_id, "player": actor_id})
		_start_barracks_selector(barracks_id, actor_id, arena_api)
		return
	if hid <= 0:
		_handle_click_ground(-1, local_pos, arena_api, actor_id)
		return
	var active_pid := actor_id
	var owner_id := int(arena_api.get_hive_owner_id(hid))
	var selectable := owner_id == active_pid or _is_dev_mouse_override()
	var selected_id := _get_selected_for_player(actor_id)
	var enemy_first_id: int = _get_enemy_first_for_player(actor_id)
	var clicked_owned: bool = owner_id == active_pid
	var clicked_ally: bool = _are_allied_seats(active_pid, owner_id)
	if enemy_first_id > 0:
		var friendly_id := -1
		var has_lane := false
		var action := "noop"
		if clicked_owned:
			friendly_id = hid
			has_lane = arena_api.is_outgoing_lane_active(hid, enemy_first_id)
			if has_lane:
				action = "retract"
				arena_api.retract_lane(hid, enemy_first_id, actor_id)
			_set_selected_for_player(arena_api, actor_id, hid)
			if actor_id == 1:
				selection.selected_cell = arena_api.cell_from_point(local_pos)
		else:
			_clear_enemy_first_visual(arena_api, actor_id)
		SFLog.info("ENEMY_FIRST_RESOLVE", {
			"enemy_id": enemy_first_id,
			"friendly_id": friendly_id,
			"has_lane": has_lane,
			"action": action
		})
		_clear_enemy_first_for_player(actor_id)
		clear_tap_state()
		return
	if owner_id > 0 and not clicked_ally and (selected_id <= 0 or selected_id == hid):
		_set_enemy_first_for_player(actor_id, hid)
		SFLog.info("ENEMY_FIRST_ARM", {"enemy_id": hid})
		_clear_selected_for_player(arena_api, actor_id)
		_set_enemy_first_visual(arena_api, hid, actor_id)
		clear_tap_state()
		return
	if selected_id <= 0:
		if selectable:
			_set_selected_for_player(arena_api, actor_id, hid)
		else:
			SFLog.warn("INPUT_HIVE_NOT_SELECTABLE", {
				"actor_id": actor_id,
				"hive_id": hid,
				"owner_id": owner_id
			})
		return
	if hid == selected_id:
		return
	# --- FORCE intent kind from ownership ---
	var src_owner := int(arena_api.get_hive_owner_id(selected_id))
	var dst_owner := int(arena_api.get_hive_owner_id(hid))
	var same_team: bool = _are_allied_seats(src_owner, dst_owner)

	SFLog.info("OWNERSHIP_CHECK", {
		"src": selected_id,
		"dst": hid,
		"src_owner": src_owner,
		"dst_owner": dst_owner,
		"same_team": same_team
	})

	var validation := _validate_target(selected_id, hid, arena_api)
	if not bool(validation.get("ok", false)):
		SFLog.info("INVALID_TARGET", {
			"src": selected_id,
			"dst": hid,
			"reason": str(validation.get("reason", "")),
			"src_owner": int(validation.get("src_owner", -1)),
			"dst_owner": int(validation.get("dst_owner", -1)),
			"has_lane": bool(validation.get("has_lane", false))
		})
		_clear_selected_for_player(arena_api, actor_id)
		return
	_apply_hive_to_hive_action(selected_id, hid, actor_id, actor_id, arena_api)
	_clear_selected_for_player(arena_api, actor_id)
	return

func handle_press(local_pos: Vector2, dev_pid: int, arena_api: ArenaAPI, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	if selection == null or arena_api == null:
		return
	var hive_id: int = _hover_hive_id
	var lane: LaneData = arena_api.pick_lane(local_pos)
	var lane_id: int = lane.id if lane != null else -1
	_handle_press(local_pos, hive_id, lane_id, dev_pid, arena_api, button_index)

func handle_release(local_pos: Vector2, dev_pid: int, arena_api: ArenaAPI) -> void:
	if selection == null or arena_api == null:
		return
	var hive_id: int = _hover_hive_id
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

func clear_selection() -> void:
	if selection == null:
		return
	selection.clear_selection()
	_selected_hive_id = -1
	_selected_by_player[1] = -1
	selected_src_id = -1
	_enemy_first_by_player[1] = -1
	enemy_first_id = -1

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
	if dev_pid != -1:
		return dev_pid
	if _is_dev_mouse_override():
		if button_index == MOUSE_BUTTON_LEFT:
			return 1
		if button_index == MOUSE_BUTTON_RIGHT:
			return 2
	if arena_api != null:
		var active_pid: int = int(arena_api.get_active_player_id())
		if active_pid >= 1 and active_pid <= 4:
			return active_pid
	return 1

func _get_selected_for_player(player_id: int) -> int:
	return int(_selected_by_player.get(player_id, -1))

func _set_selected_for_player(arena_api: ArenaAPI, player_id: int, hive_id: int) -> void:
	_selected_by_player[player_id] = hive_id
	if player_id == 1:
		_set_selected(arena_api, hive_id)

func _clear_selected_for_player(arena_api: ArenaAPI, player_id: int) -> void:
	var had_selection := int(_selected_by_player.get(player_id, -1)) > 0
	_selected_by_player[player_id] = -1
	if player_id == 1:
		_clear_selected(arena_api)
		return
	if had_selection:
		SFLog.info("INPUT_DESELECT", {"player_id": player_id})

func _get_enemy_first_for_player(player_id: int) -> int:
	return int(_enemy_first_by_player.get(player_id, -1))

func _set_enemy_first_for_player(player_id: int, hive_id: int) -> void:
	_enemy_first_by_player[player_id] = hive_id
	if player_id == 1:
		enemy_first_id = hive_id

func _clear_enemy_first_for_player(player_id: int) -> void:
	_enemy_first_by_player[player_id] = -1
	if player_id == 1:
		enemy_first_id = -1

func _set_enemy_first_visual(arena_api: ArenaAPI, hive_id: int, player_id: int) -> void:
	if player_id != 1:
		return
	if selection != null:
		selection.selected_hive_id = -1
		selection.selected_lane_id = -1
	var hr := _get_hive_renderer(arena_api)
	if hr != null and hr.has_method("set_selected_hive"):
		hr.call("set_selected_hive", hive_id, _owner_color(player_id))

func _clear_enemy_first_visual(arena_api: ArenaAPI, player_id: int) -> void:
	if player_id != 1:
		return
	_clear_selected(arena_api)

func _owner_color(owner_id: int) -> Color:
	match owner_id:
		1:
			return Color(1.0, 0.8235, 0.0, 1.0)
		2:
			return Color(1.0, 0.0, 0.0, 1.0)
		3:
			return Color8(34, 85, 34)
		4:
			return Color(0.0, 0.35, 1.0, 1.0)
		_:
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
	var changed := hive_id != _selected_hive_id
	_selected_hive_id = hive_id
	_selected_by_player[1] = hive_id
	selected_src_id = hive_id
	if selection != null:
		selection.selected_hive_id = hive_id
		selection.selected_lane_id = -1
	var hr := _get_hive_renderer(arena_api)
	var owner_id := 0
	if hive_id > 0:
		owner_id = arena_api.get_hive_owner_id(hive_id)
		if hr != null and hr.has_method("set_selected_hive"):
			hr.call("set_selected_hive", hive_id, _owner_color(owner_id))
		if changed:
			SFLog.info("SELECT", {"src": hive_id})
		return
	_clear_selected(arena_api)

func _clear_selected(arena_api: ArenaAPI) -> void:
	var had_selection := _selected_hive_id > 0
	_selected_hive_id = -1
	_selected_by_player[1] = -1
	selected_src_id = -1
	if selection != null:
		selection.selected_hive_id = -1
		selection.selected_lane_id = -1
	var hr := _get_hive_renderer(arena_api)
	if hr != null:
		if hr.has_method("clear_selected_hive"):
			hr.call("clear_selected_hive")
		elif hr.has_method("set_selected_hive"):
			hr.call("set_selected_hive", -1, _owner_color(0))
	if had_selection:
		SFLog.info("INPUT_DESELECT", {"player_id": 1})
		SFLog.info("DESELECT", {})

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

func _get_viewport_from_arena(arena_api: ArenaAPI) -> Viewport:
	if arena_api == null:
		return null
	var arena: Node = arena_api._arena
	if arena == null:
		return null
	return arena.get_viewport()

func _get_screen_pos_from_event(event: InputEvent, arena_api: ArenaAPI) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	var viewport := _get_viewport_from_arena(arena_api)
	if viewport != null:
		return viewport.get_mouse_position()
	return Vector2.ZERO

func _get_world_pos_from_event(event: InputEvent, arena_api: ArenaAPI) -> Vector2:
	var screen_pos := _get_screen_pos_from_event(event, arena_api)
	var viewport := _get_viewport_from_arena(arena_api)
	if viewport != null:
		var inv := viewport.get_canvas_transform().affine_inverse()
		return inv * screen_pos
	if arena_api != null and arena_api._arena is Node2D:
		return (arena_api._arena as Node2D).get_global_mouse_position()
	return screen_pos

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
	return OS.is_debug_build() or Engine.is_editor_hint()

func _dev_mouse_pid_from_button(button_index: int) -> int:
	if not _is_dev_mouse_override():
		return -1
	# Dev convenience mapping:
	# Left mouse = P1
	# Right mouse = P2
	if button_index == MOUSE_BUTTON_LEFT:
		return 1
	if button_index == MOUSE_BUTTON_RIGHT:
		return 2
	return -1

func _handle_press(local_pos: Vector2, hive_id: int, lane_id: int, dev_pid: int, arena_api: ArenaAPI, button_index: int) -> void:
	if _handling_click:
		if SFLog.LOGGING_ENABLED:
			print("HIVE: re-entrant click blocked")
		return
	_handling_click = true
	if not (button_index == MOUSE_BUTTON_LEFT or button_index == MOUSE_BUTTON_RIGHT):
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
	var arena: Node = arena_api._arena if arena_api != null else null
	if arena != null:
		arena._handle_tap(hive_id, -1)
	else:
		if SFLog.LOGGING_ENABLED:
			print("HIVE: arena is NULL at click time")
	var now_ms: int = Time.get_ticks_msec()
	var is_double: bool = (now_ms - _last_tap_time_ms) <= DOUBLE_TAP_MS and _last_tap_pos.distance_to(local_pos) <= DOUBLE_TAP_DIST_PX
	_last_tap_time_ms = now_ms
	_last_tap_pos = local_pos
	var world_pos: Vector2 = _map_local_to_world(local_pos, arena_api)
	var player_id: int = actor_id
	if hive_id > 0:
		var hive_owner := -1
		var friendly := false
		var hive: HiveData = arena_api.find_hive_by_id(hive_id)
		if hive != null:
			hive_owner = int(hive.owner_id)
			friendly = hive_owner == player_id
		SFLog.info("HIVE_CLICK_DEBUG", {
			"hive_id": hive_id,
			"hive_owner_id": hive_owner,
			"player_id": player_id,
			"dev_pid": dev_pid,
			"active_pid": arena_api.get_active_player_id(),
			"friendly": friendly
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
	if is_double:
		if _handle_lane_double_tap(local_pos, actor_id, player_id, arena_api):
			_handling_click = false
			return
	if hive_id > 0:
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
		selection.last_vibe_target_id = -1
		selection.drag_dev_pid = actor_id
		if actor_id == 1 and friendly:
			selection.selected_hive_id = hive_id
			selection.selected_lane_id = -1
			selection.selected_cell = arena_api.cell_from_point(local_pos)
	else:
		selection.drag_active = false
		selection.drag_moved = false
		selection.drag_start_hive_id = -1
		selection.drag_start_owner_id = -1
		selection.drag_hover_hive_id = -1
		selection.last_vibe_target_id = -1
		selection.drag_dev_pid = actor_id
	_handling_click = false
	arena_api.mark_render_dirty("input_press")

func _handle_release(local_pos: Vector2, _hive_id: int, lane_id: int, dev_pid: int, arena_api: ArenaAPI, _button_index: int) -> void:
	if not _press_active:
		return
	_press_active = false
	_press_last_world = _map_local_to_world(local_pos, arena_api)
	_press_candidate_barracks_id = -1
	if _press_consumed:
		_press_consumed = false
		reset_drag()
		arena_api.mark_render_dirty("input_release")
		return
	selection.drag_current_pos = local_pos
	var player_id: int = _press_player_id
	if player_id <= 0:
		player_id = dev_pid if dev_pid != -1 else arena_api.get_active_player_id()
	var end_id: int = arena_api.pick_hive_id_local(local_pos)
	if selection.drag_active and selection.drag_moved and selection.drag_start_hive_id > 0:
		var start_id: int = selection.drag_start_hive_id
		if end_id > 0 and end_id != start_id:
			_apply_hive_to_hive_action(start_id, end_id, player_id, player_id, arena_api)
		reset_drag()
		arena_api.mark_render_dirty("input_release")
		return
	if _press_hive_id > 0:
		_handle_click_hive(_press_prev_selected_id, _press_hive_id, player_id, player_id, arena_api, local_pos)
	else:
		_handle_click_ground(_press_lane_id, local_pos, arena_api, player_id)
	reset_drag()
	arena_api.mark_render_dirty("input_release")

func _handle_drag(local_pos: Vector2, _hive_id: int, _lane_id: int, arena_api: ArenaAPI) -> void:
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
	arena_api.mark_render_dirty("input_drag")
	if not selection.drag_moved:
		return
	var hover_id: int = arena_api.pick_hive_id_local(local_pos)
	if hover_id > 0 and hover_id != selection.drag_start_hive_id:
		if arena_api.lane_exists_between(selection.drag_start_hive_id, hover_id):
			if hover_id != selection.last_vibe_target_id:
				Input.vibrate_handheld(30)
				selection.last_vibe_target_id = hover_id
			selection.drag_hover_hive_id = hover_id
			return
	selection.drag_hover_hive_id = -1
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
	var hive: HiveData = arena_api.find_hive_by_id(clicked_id)
	if hive == null:
		clear_tap_state()
		return
	var world_pos := _map_local_to_world(local_pos, arena_api)
	SFLog.info("INPUT_CLICK", {"player_id": player_id, "hid": clicked_id, "world": world_pos})
	var enemy_first_id: int = _get_enemy_first_for_player(player_id)
	var clicked_owned: bool = hive.owner_id == player_id
	var clicked_ally: bool = _are_allied_seats(player_id, hive.owner_id)
	if enemy_first_id > 0:
		var friendly_id := -1
		var has_lane := false
		var action := "noop"
		if clicked_owned:
			friendly_id = clicked_id
			has_lane = arena_api.is_outgoing_lane_active(clicked_id, enemy_first_id)
			if has_lane:
				action = "retract"
				arena_api.retract_lane(clicked_id, enemy_first_id, player_id)
			_set_selected_for_player(arena_api, player_id, clicked_id)
			if player_id == 1:
				selection.selected_cell = arena_api.cell_from_point(local_pos)
		else:
			_clear_enemy_first_visual(arena_api, player_id)
		SFLog.info("ENEMY_FIRST_RESOLVE", {
			"enemy_id": enemy_first_id,
			"friendly_id": friendly_id,
			"has_lane": has_lane,
			"action": action
		})
		_clear_enemy_first_for_player(player_id)
		clear_tap_state()
		return
	if int(hive.owner_id) > 0 and not clicked_ally and (prev_selected_id <= 0 or prev_selected_id == clicked_id):
		_set_enemy_first_for_player(player_id, clicked_id)
		SFLog.info("ENEMY_FIRST_ARM", {"enemy_id": clicked_id})
		_clear_selected_for_player(arena_api, player_id)
		_set_enemy_first_visual(arena_api, clicked_id, player_id)
		clear_tap_state()
		return
	if prev_selected_id != -1 and prev_selected_id != clicked_id:
		_apply_hive_to_hive_action(prev_selected_id, clicked_id, player_id, dev_pid, arena_api)
	if clicked_owned:
		_set_selected_for_player(arena_api, player_id, clicked_id)
		if player_id == 1:
			selection.selected_cell = arena_api.cell_from_point(local_pos)
	clear_tap_state()

func _handle_click_ground(lane_id: int, local_pos: Vector2, arena_api: ArenaAPI, player_id: int) -> void:
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
	if player_id != 1:
		_clear_selected_for_player(arena_api, player_id)
		clear_tap_state()
		return
	if lane_id != -1:
		var lane: LaneData = arena_api.find_lane_by_id(lane_id)
		if lane != null:
			_clear_selected_for_player(arena_api, player_id)
			selection.selected_lane_id = lane.id
			selection.selected_cell = arena_api.cell_from_point(local_pos)
			arena_api.dbg("SF: Lane selected id=%d a=%d b=%d dir=%d" % [lane.id, lane.a_id, lane.b_id, lane.dir])
			return
	_clear_selected_for_player(arena_api, player_id)
	selection.selected_lane_id = -1
	selection.selected_cell = arena_api.cell_from_point(local_pos)
	arena_api.dbg("SF: Cell selected %d,%d" % [selection.selected_cell.x, selection.selected_cell.y])
	clear_tap_state()

func _apply_hive_to_hive_action(from_id: int, to_id: int, player_id: int, dev_pid: int, arena_api: ArenaAPI) -> void:
	if from_id <= 0 or to_id <= 0 or from_id == to_id:
		return
	var from_hive: HiveData = arena_api.find_hive_by_id(from_id)
	var to_hive: HiveData = arena_api.find_hive_by_id(to_id)
	if from_hive == null or to_hive == null:
		return
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
			_issue_swarm_intent(from_id, to_id, player_id)
		else:
			_issue_intent(from_id, to_id, player_id, dev_pid, arena_api)
		return
	if not from_owned and to_owned:
		if arena_api.intent_is_on(to_id, from_id):
			arena_api.retract_lane(to_id, from_id, player_id)

func _issue_intent(from_id: int, to_id: int, player_id: int, dev_pid: int, arena_api: ArenaAPI) -> void:
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
		return
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

func _issue_swarm_intent(from_id: int, to_id: int, player_id: int) -> bool:
	var result := OpsState.apply_lane_intent(from_id, to_id, "swarm")
	var ok := bool(result.get("ok", false))
	if ok:
		SFLog.info("INPUT_INTENT", {"player_id": player_id, "src": from_id, "dst": to_id, "intent": "swarm"})
		SFLog.info("LANE_SWARM_INTENT", {"src": from_id, "dst": to_id, "player_id": player_id})
	return ok

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
	var src_id: int = -1
	var dst_id: int = -1
	var src_is_a: bool = false
	if lane.send_a and int(a.owner_id) == player_id:
		src_id = int(a.id)
		dst_id = int(b.id)
		src_is_a = true
	elif lane.send_b and int(b.owner_id) == player_id:
		src_id = int(b.id)
		dst_id = int(a.id)
		src_is_a = false
	if src_id <= 0 or dst_id <= 0:
		return false
	var a_pos: Vector2 = arena_api.cell_center(a.grid_pos)
	var b_pos: Vector2 = arena_api.cell_center(b.grid_pos)
	var src_pos: Vector2 = a_pos if src_is_a else b_pos
	var dst_pos: Vector2 = b_pos if src_is_a else a_pos
	var tap_is_src_half: bool = world_pos.distance_to(src_pos) <= world_pos.distance_to(dst_pos)
	if tap_is_src_half:
		if arena_api.intent_is_on(src_id, dst_id):
			SFLog.info("LANE_DBL_RETRACT", {"lane_id": lane_id, "src": src_id, "dst": dst_id})
			SFLog.info("LANE_RETRACT_INTENT", {"lane_id": lane_id, "src": src_id, "dst": dst_id, "player_id": player_id})
			arena_api.retract_lane(src_id, dst_id, player_id)
			return true
		return false
	if arena_api.intent_is_on(src_id, dst_id):
		SFLog.info("LANE_DBL_SWARM", {"lane_id": lane_id, "src": src_id, "dst": dst_id})
		return _issue_swarm_intent(src_id, dst_id, player_id)
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
