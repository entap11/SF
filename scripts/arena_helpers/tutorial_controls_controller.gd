class_name ArenaTutorialControlsController
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")

const STATUS_NOT_STARTED: String = "not_started"
const STATUS_IN_PROGRESS: String = "in_progress"
const STATUS_COMPLETED: String = "completed"
const STATUS_SKIPPED: String = "skipped"

const STEP_WELCOME: String = "welcome"
const STEP_SELECT_START_HIVE: String = "select_start_hive"
const STEP_ATTACK_NEUTRAL_HIVE: String = "attack_neutral_hive"
const STEP_WAIT_CAPTURE_NEUTRAL: String = "wait_capture_neutral"
const STEP_FEED_FRIEND: String = "feed_friend"
const STEP_REVERSE_FEED: String = "reverse_feed"
const STEP_CANCEL_LANE_GRAB_THROW: String = "cancel_lane_grab_throw"
const STEP_REMAKE_FRIEND_LANE: String = "remake_friend_lane"
const STEP_ATTACK_ENEMY_HIVE: String = "attack_enemy_hive"
const STEP_CONTEST_ENEMY_LANE: String = "contest_enemy_lane"
const STEP_ATTACK_ENEMY_FROM_START: String = "attack_enemy_from_start"
const STEP_ATTACK_ENEMY_FROM_START_GUIDED: String = "attack_enemy_from_start_guided"
const STEP_TAKE_NEUTRAL_HIVE: String = "take_neutral_hive"
const STEP_ATTACK_ENEMY_FROM_NEUTRAL: String = "attack_enemy_from_neutral"
const STEP_SWARM_INTRO: String = "swarm_intro"
const STEP_SWARM_BY_OVERLAP: String = "swarm_by_overlap"
const STEP_WAIT_OVERLAP_SWARM_HIT: String = "wait_overlap_swarm_hit"
const STEP_SWARM_DOUBLE_TAP: String = "swarm_double_tap"
const STEP_FINISH_FIGHT: String = "finish_fight"
const STEP_COMPLETE: String = "complete"
const REVERSE_PHASE_TAP_DESTINATION: String = "tap_destination"
const REVERSE_PHASE_TAP_SOURCE: String = "tap_source"
const START_ATTACK_PHASE_TAP_SOURCE: String = "tap_source"
const START_ATTACK_PHASE_TAP_TARGET: String = "tap_target"
const REMAKE_PHASE_TAP_SOURCE: String = "tap_source"
const REMAKE_PHASE_TAP_TARGET: String = "tap_target"
const ATTACK_ENEMY_PHASE_TAP_SOURCE: String = "tap_source"
const ATTACK_ENEMY_PHASE_TAP_TARGET: String = "tap_target"
const TAKE_NEUTRAL_PHASE_TAP_SOURCE: String = "tap_source"
const TAKE_NEUTRAL_PHASE_TAP_TARGET: String = "tap_target"
const SWARM_OVERLAP_PHASE_TAP_SOURCE: String = "tap_source"
const SWARM_OVERLAP_PHASE_TAP_TARGET: String = "tap_target"

const ANCHOR_START_HIVE: String = "start_hive"
const ANCHOR_NEUTRAL_HIVE: String = "neutral_hive"
const ANCHOR_FRIEND_HIVE: String = "friend_hive"
const ANCHOR_ENEMY_HIVE: String = "enemy_hive"

const ANCHOR_POSITIONS := {
	ANCHOR_START_HIVE: Vector2i(2, 6),
	ANCHOR_NEUTRAL_HIVE: Vector2i(8, 6),
	ANCHOR_FRIEND_HIVE: Vector2i(2, 17),
	ANCHOR_ENEMY_HIVE: Vector2i(15, 17)
}
const POST_ACTION_DWELL_MS: int = 4500
const SWARM_INTRO_AUTO_ADVANCE_MS: int = 5000
const SWARM_DOUBLE_TAP_SCREEN_PICK_RADIUS_PX: float = 56.0

var _active: bool = false
var _completed_this_match: bool = false
var _current_step: String = STEP_SELECT_START_HIVE
var _local_owner_id: int = 1
var _anchor_ids: Dictionary = {}
var _overlay: Control = null
var _panel: Panel = null
var _title_label: Label = null
var _body_label: Label = null
var _status_label: Label = null
var _skip_button: Button = null
var _source_ring: Panel = null
var _target_ring: Panel = null
var _lane_line: ColorRect = null
var _lane_pull_ghost_shadow: Line2D = null
var _lane_pull_ghost: Line2D = null
var _double_tap_lane_glows: Array = []
var _double_tap_lane_cores: Array = []
var _tap_hand: Control = null
var _last_state: GameState = null
var _signal_bound: bool = false
var _saw_friend_lane_retract: bool = false
var _cancel_lane_gesture_started: bool = false
var _hive_screen_pos_cb: Callable = Callable()
var _pause_sim_cb: Callable = Callable()
var _resume_sim_cb: Callable = Callable()
var _arrival_count_cb: Callable = Callable()
var _blocked_pointer_keys: Dictionary = {}
var _recovery_keys_logged: Dictionary = {}
var _readout_waiting_for_input: bool = false
var _readout_step_id: String = ""
var _delayed_step_id: String = ""
var _delayed_step_at_ms: int = 0
var _feed_friend_arrival_wait_active: bool = false
var _feed_friend_arrival_baseline: int = 0
var _feed_friend_arrival_target: int = 3
var _reverse_feed_phase: String = REVERSE_PHASE_TAP_DESTINATION
var _remake_friend_phase: String = REMAKE_PHASE_TAP_SOURCE
var _attack_enemy_phase: String = ATTACK_ENEMY_PHASE_TAP_SOURCE
var _take_neutral_phase: String = TAKE_NEUTRAL_PHASE_TAP_SOURCE
var _swarm_overlap_phase: String = SWARM_OVERLAP_PHASE_TAP_SOURCE
var _swarm_overlap_source_anchor: String = ""
var _reverse_feed_arrival_wait_active: bool = false
var _reverse_feed_arrival_baseline: int = 0
var _reverse_feed_arrival_target: int = 2
var _attack_drag_pointer_key: String = ""
var _attack_drag_start_local: Vector2 = Vector2.ZERO
var _attack_drag_moved: bool = false
var _contest_cancel_wait_active: bool = false
var _contest_cancel_baseline: int = 0
var _contest_cancel_target: int = 3
var _contest_enemy_opposed: bool = false
var _enemy_opposed_anchors: Dictionary = {}
var _start_attack_prompt_at_ms: int = 0
var _start_attack_timeout_ms: int = 10000
var _start_attack_phase: String = START_ATTACK_PHASE_TAP_SOURCE
var _overlap_swarm_seen: bool = false
var _double_tap_swarm_seen: bool = false
var _swarm_intro_auto_advance_at_ms: int = 0
var _pending_next_step_id: String = ""
var _pending_next_step_at_ms: int = 0

static func step_contracts() -> Array:
	return [
		_contract(STEP_WELCOME, "Welcome to Swarmfront.", "Welcome to the Swarmfront controls tutorial.\n\nTap anywhere on the screen to begin.", "", "", ["tap_anywhere"], "paused", "tutorial_welcome"),
		_contract(STEP_SELECT_START_HIVE, "Tap your hive.", "There are several ways to make a lane. The first way is to tap the hive that I have highlighted for you.", ANCHOR_START_HIVE, "", ["tap"], "paused", "tutorial_select_start"),
		_contract(STEP_FEED_FRIEND, "Tap the destination.", "...and tap the desired destination.", "", ANCHOR_FRIEND_HIVE, ["tap"], "paused", "tutorial_feed_friend"),
		_contract(STEP_REVERSE_FEED, "Reverse the lane.", "To reverse this flow and send units back the other way, simply reverse the steps.\n\nTap the destination hive.", "", ANCHOR_FRIEND_HIVE, ["tap"], "paused", "tutorial_reverse_feed"),
		_contract(STEP_CANCEL_LANE_GRAB_THROW, "Get rid of your lane.", "Now that you can make a lane, let's learn how to get rid of it.\n\nPress the highlighted lane near the source hive, pull it sideways, and release to throw it away. Follow the hand, then do the same gesture yourself.", ANCHOR_FRIEND_HIVE, ANCHOR_START_HIVE, ["lane_grab_throw"], "paused_until_action", "tutorial_lane_cancel"),
		_contract(STEP_REMAKE_FRIEND_LANE, "Remake the lane.", "Great. Remake that lane using either the “tap source — tap destination” method or by dragging from source to destination.", ANCHOR_FRIEND_HIVE, ANCHOR_START_HIVE, ["tap", "drag"], "paused", "tutorial_remake_friend_lane"),
		_contract(STEP_ATTACK_ENEMY_HIVE, "Attack the enemy.", "Next, let's learn how to attack.\n\nYou can do this two ways: the “tap source — tap destination” method you just learned, or you can drag from the source hive and land on the destination hive. Let's try it!", ANCHOR_FRIEND_HIVE, ANCHOR_ENEMY_HIVE, ["tap", "drag"], "paused", "tutorial_attack_enemy"),
		_contract(STEP_CONTEST_ENEMY_LANE, "Watch the lane fight.", "Watch the lane fight.", ANCHOR_FRIEND_HIVE, ANCHOR_ENEMY_HIVE, ["wait"], "normal", "tutorial_enemy_contest_wait"),
		_contract(STEP_ATTACK_ENEMY_FROM_START, "Attack from another hive.", "See how the bees are canceling each other?\n\nThis can go on all day, so you need to attack that hive from somewhere else. Attack from that top-left hive too.", ANCHOR_START_HIVE, ANCHOR_ENEMY_HIVE, ["tap", "drag"], "paused", "tutorial_attack_enemy_from_start"),
		_contract(STEP_ATTACK_ENEMY_FROM_START_GUIDED, "Attack from this hive.", "OK, let's attack from this hive.", ANCHOR_START_HIVE, "", ["tap"], "paused", "tutorial_attack_enemy_from_start_guided"),
		_contract(STEP_TAKE_NEUTRAL_HIVE, "Take the gray hive.", "So, it's time to win this game. Take that small NPC gray hive.", ANCHOR_START_HIVE, ANCHOR_NEUTRAL_HIVE, ["tap", "drag"], "normal", "tutorial_take_neutral"),
		_contract(STEP_ATTACK_ENEMY_FROM_NEUTRAL, "Attack from gray.", "Now, make a lane to attack that enemy hive and I'll show you a trick.", ANCHOR_NEUTRAL_HIVE, ANCHOR_ENEMY_HIVE, ["tap", "drag"], "paused", "tutorial_attack_enemy_from_neutral"),
		_contract(STEP_SWARM_INTRO, "Time to swarm.", "You want to win now? It's time to swarm. There are two ways to swarm and we will try them both.", "", "", ["wait"], "paused", "tutorial_swarm_intro"),
		_contract(STEP_SWARM_BY_OVERLAP, "Create over the lane.", "First, create a lane over the top of an existing lane.\n\nUse any of your three hives: tap your hive, then tap the enemy hive, or drag a lane to it.", "", ANCHOR_ENEMY_HIVE, ["tap", "drag"], "paused", "tutorial_swarm_overlap"),
		_contract(STEP_WAIT_OVERLAP_SWARM_HIT, "Watch the swarm hit.", "Watch the swarm hit.", ANCHOR_NEUTRAL_HIVE, ANCHOR_ENEMY_HIVE, ["wait"], "normal", "tutorial_swarm_overlap_wait"),
		_contract(STEP_SWARM_DOUBLE_TAP, "Double tap to swarm.", "Perfect. Now let's double tap him!\n\nSimply double tap the lane near the enemy hive you want to swarm. Try either the middle or bottom lane this time.", ANCHOR_START_HIVE, ANCHOR_ENEMY_HIVE, ["lane_double_tap"], "paused", "tutorial_swarm_double_tap"),
		_contract(STEP_FINISH_FIGHT, "Finish the fight.", "Finish the fight.", "", "", ["free_play"], "normal", "tutorial_finish_fight"),
		_contract(STEP_COMPLETE, "Tutorial complete.", "Tutorial complete.", "", "", ["none"], "normal", "tutorial_complete")
	]

static func _contract(step_id: String, instruction: String, readout: String, source_anchor: String, target_anchor: String, allowed_inputs: Array, simulation_mode: String, telemetry_label: String) -> Dictionary:
	return {
		"id": step_id,
		"instruction": instruction,
		"readout": readout,
		"source_anchor": source_anchor,
		"target_anchor": target_anchor,
		"allowed_inputs": allowed_inputs.duplicate(),
		"simulation_mode": simulation_mode,
		"telemetry_label": telemetry_label,
		"timeout_hint_sec": 0
	}

func start_if_needed(resolve_hud_root_cb: Callable, force_fullscreen_anchors_cb: Callable, local_owner_id: int, state: GameState, hive_screen_pos_cb: Callable = Callable(), pause_sim_cb: Callable = Callable(), resume_sim_cb: Callable = Callable(), arrival_count_cb: Callable = Callable()) -> bool:
	var profile_manager: Object = _get_profile_manager()
	if profile_manager == null:
		hide(true)
		return false
	var status: String = STATUS_NOT_STARTED
	if profile_manager.has_method("get_tutorial_controls_status"):
		status = _sanitize_status(str(profile_manager.call("get_tutorial_controls_status")))
	if status == STATUS_COMPLETED or status == STATUS_SKIPPED:
		hide(true)
		return false
	if status == STATUS_NOT_STARTED and profile_manager.has_method("begin_tutorial_controls"):
		profile_manager.call("begin_tutorial_controls")
	_local_owner_id = clampi(local_owner_id, 1, 4)
	_anchor_ids = _resolve_anchor_ids(state)
	_hive_screen_pos_cb = hive_screen_pos_cb
	_pause_sim_cb = pause_sim_cb
	_resume_sim_cb = resume_sim_cb
	_arrival_count_cb = arrival_count_cb
	_current_step = STEP_SELECT_START_HIVE
	_completed_this_match = false
	_last_state = state
	_saw_friend_lane_retract = false
	_cancel_lane_gesture_started = false
	_blocked_pointer_keys.clear()
	_recovery_keys_logged.clear()
	_readout_waiting_for_input = false
	_readout_step_id = ""
	_delayed_step_id = ""
	_delayed_step_at_ms = 0
	_feed_friend_arrival_wait_active = false
	_feed_friend_arrival_baseline = 0
	_reverse_feed_phase = REVERSE_PHASE_TAP_DESTINATION
	_remake_friend_phase = REMAKE_PHASE_TAP_SOURCE
	_reverse_feed_arrival_wait_active = false
	_reverse_feed_arrival_baseline = 0
	_contest_cancel_wait_active = false
	_contest_cancel_baseline = 0
	_contest_enemy_opposed = false
	_enemy_opposed_anchors.clear()
	_start_attack_prompt_at_ms = 0
	_start_attack_phase = START_ATTACK_PHASE_TAP_SOURCE
	_overlap_swarm_seen = false
	_double_tap_swarm_seen = false
	_swarm_intro_auto_advance_at_ms = 0
	_pending_next_step_id = ""
	_pending_next_step_at_ms = 0
	_clear_attack_drag_gate()
	_active = true
	_bind_signal_once()
	ensure_overlay(resolve_hud_root_cb, force_fullscreen_anchors_cb)
	_enter_step(STEP_SELECT_START_HIVE)
	_evaluate_current_step(state)
	return true

func ensure_overlay(resolve_hud_root_cb: Callable, force_fullscreen_anchors_cb: Callable) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	if not resolve_hud_root_cb.is_valid():
		return
	var hud_root: Control = resolve_hud_root_cb.call() as Control
	if hud_root == null:
		return
	var overlay: Control = hud_root.get_node_or_null("TutorialControlsOverlay") as Control
	if overlay == null:
		overlay = _build_overlay()
		hud_root.add_child(overlay)
	elif overlay.get_parent() != hud_root:
		overlay.reparent(hud_root)
	if force_fullscreen_anchors_cb.is_valid():
		force_fullscreen_anchors_cb.call(overlay)
	overlay.z_as_relative = false
	overlay.z_index = 2065
	overlay.top_level = false
	_overlay = overlay
	_panel = overlay.get_node_or_null("Panel") as Panel
	_title_label = overlay.get_node_or_null("Panel/VBox/Title") as Label
	_body_label = overlay.get_node_or_null("Panel/VBox/Body") as Label
	_status_label = overlay.get_node_or_null("Panel/VBox/Status") as Label
	_skip_button = overlay.get_node_or_null("Panel/VBox/SkipButton") as Button
	_source_ring = overlay.get_node_or_null("SourceFocusRing") as Panel
	_target_ring = overlay.get_node_or_null("TargetFocusRing") as Panel
	_lane_line = overlay.get_node_or_null("FocusLine") as ColorRect
	_lane_pull_ghost_shadow = overlay.get_node_or_null("LanePullGhostShadow") as Line2D
	_lane_pull_ghost = overlay.get_node_or_null("LanePullGhost") as Line2D
	_double_tap_lane_glows.clear()
	_double_tap_lane_cores.clear()
	for i in range(2):
		var glow_node: ColorRect = overlay.get_node_or_null("DoubleTapLaneGlow%d" % i) as ColorRect
		if glow_node != null:
			_double_tap_lane_glows.append(glow_node)
		var core_node: ColorRect = overlay.get_node_or_null("DoubleTapLaneCore%d" % i) as ColorRect
		if core_node != null:
			_double_tap_lane_cores.append(core_node)
	_tap_hand = overlay.get_node_or_null("TapHand") as Control
	if _skip_button != null and not _skip_button.pressed.is_connected(_on_skip_pressed):
		_skip_button.pressed.connect(_on_skip_pressed)
	_style_overlay_nodes()

func is_active() -> bool:
	return _active

func completed_this_match() -> bool:
	return _completed_this_match

func current_step_id() -> String:
	return _current_step

func get_step_contracts() -> Array:
	return step_contracts()

func get_anchor_ids() -> Dictionary:
	return _anchor_ids.duplicate(true)

func smoke_snapshot() -> Dictionary:
	var body_text: String = _body_label.text if _body_label != null else ""
	var status_text: String = _status_label.text if _status_label != null else ""
	return {
		"active": _active,
		"current_step": _current_step,
		"completed_this_match": _completed_this_match,
		"anchors": _anchor_ids.duplicate(true),
		"contracts": step_contracts(),
		"overlay_visible": _overlay != null and is_instance_valid(_overlay) and _overlay.visible,
		"body_text": body_text,
		"status_text": status_text,
		"feed_friend_arrival_delta": _feed_friend_arrival_delta(),
		"feed_friend_arrival_target": _feed_friend_arrival_target,
		"feed_friend_arrival_wait_active": _feed_friend_arrival_wait_active,
		"reverse_feed_phase": _reverse_feed_phase,
		"remake_friend_phase": _remake_friend_phase,
		"attack_enemy_phase": _attack_enemy_phase,
		"take_neutral_phase": _take_neutral_phase,
		"swarm_overlap_phase": _swarm_overlap_phase,
		"swarm_overlap_source_anchor": _swarm_overlap_source_anchor,
		"swarm_overlap_available_source_ids": _swarm_overlap_source_ids(_last_state),
		"reverse_feed_arrival_delta": _reverse_feed_arrival_delta(),
		"reverse_feed_arrival_target": _reverse_feed_arrival_target,
		"reverse_feed_arrival_wait_active": _reverse_feed_arrival_wait_active,
		"contest_cancel_delta": _contest_cancel_delta(),
		"contest_cancel_target": _contest_cancel_target,
		"contest_cancel_wait_active": _contest_cancel_wait_active,
		"contest_enemy_opposed": _contest_enemy_opposed,
		"enemy_opposed_anchors": _enemy_opposed_anchors.duplicate(true),
		"start_attack_phase": _start_attack_phase,
		"overlap_swarm_seen": _overlap_swarm_seen,
		"double_tap_swarm_seen": _double_tap_swarm_seen,
		"swarm_intro_auto_advance_remaining_ms": _swarm_intro_auto_advance_remaining_ms(),
		"pending_next_step": _pending_next_step_id,
		"pending_next_step_remaining_ms": _pending_next_step_remaining_ms(),
		"source_focus_visible": _source_ring != null and is_instance_valid(_source_ring) and _source_ring.visible,
		"target_focus_visible": _target_ring != null and is_instance_valid(_target_ring) and _target_ring.visible,
		"lane_focus_visible": _lane_line != null and is_instance_valid(_lane_line) and _lane_line.visible,
		"lane_pull_demo_visible": _lane_pull_ghost != null and is_instance_valid(_lane_pull_ghost) and _lane_pull_ghost.visible,
		"cancel_lane_gesture_started": _cancel_lane_gesture_started,
		"double_tap_lane_focus_visible": _double_tap_focus_visible(),
		"tap_hand_visible": _tap_hand != null and is_instance_valid(_tap_hand) and _tap_hand.visible
	}

func should_allow_pointer_event(ev: Dictionary, state: GameState) -> bool:
	if not _active:
		return true
	var event_type: String = str(ev.get("type", ""))
	var pointer_key: String = _pointer_key(ev)
	if event_type == "release":
		if _current_step == STEP_ATTACK_ENEMY_HIVE and _attack_drag_pointer_key == pointer_key:
			return _finish_attack_drag(pointer_key, ev)
		if _blocked_pointer_keys.has(pointer_key):
			_blocked_pointer_keys.erase(pointer_key)
			return false
		return true
	if event_type == "motion":
		if _current_step == STEP_ATTACK_ENEMY_HIVE and _attack_drag_pointer_key == pointer_key:
			_update_attack_drag(ev)
			return true
		return not _blocked_pointer_keys.has(pointer_key)
	if event_type != "press":
		return true
	if not _delayed_step_id.is_empty():
		_blocked_pointer_keys[pointer_key] = true
		_log_input_block("readout_transition", ev)
		return false
	if state == null:
		_blocked_pointer_keys[pointer_key] = true
		_log_input_block("state_missing", ev)
		return false
	if _anchor_ids.is_empty():
		_anchor_ids = _resolve_anchor_ids(state)
	var allowed: Dictionary = _press_allowed_for_step(ev, state)
	if bool(allowed.get("ok", false)):
		if _current_step == STEP_CANCEL_LANE_GRAB_THROW:
			# Route the first accepted press into the lane gesture even when the
			# generous hive hit area overlaps the highlighted lane segment.
			ev["hive_id"] = -1
			ev["lane_grab_only"] = true
			_cancel_lane_gesture_started = true
			_resume_after_readout()
		elif _current_step == STEP_SWARM_DOUBLE_TAP:
			# The red/destination half is a lane-only target. This prevents the
			# enemy hive's generous hit area from stealing either click.
			ev["hive_id"] = -1
			ev["lane_double_tap_only"] = true
		elif _current_step == STEP_ATTACK_ENEMY_HIVE or _current_step == STEP_TAKE_NEUTRAL_HIVE or _current_step == STEP_SWARM_BY_OVERLAP:
			# The existing friendly lane reaches the source hive's hit area. Keep
			# tutorial source/destination taps on hives so the lane cannot steal them.
			ev["hive_tap_only"] = true
			if str(allowed.get("reason", "")).ends_with("source"):
				ev["hive_source_select_only"] = true
				if _current_step == STEP_SWARM_BY_OVERLAP:
					_swarm_overlap_source_anchor = _anchor_name_for_hive_id(int(ev.get("hive_id", -1)))
		if _current_step == STEP_ATTACK_ENEMY_HIVE and str(allowed.get("reason", "")) == "attack_enemy_drag_source":
			_begin_attack_drag(pointer_key, ev)
		if _handle_prompted_tap_press(str(allowed.get("reason", "valid_press")), state):
			_blocked_pointer_keys[pointer_key] = true
			return false
		if not bool(allowed.get("defer_commit", false)):
			_commit_readout_for_step_input(str(allowed.get("reason", "valid_press")))
		if bool(allowed.get("consume", false)):
			_blocked_pointer_keys[pointer_key] = true
			return false
		return true
	_blocked_pointer_keys[pointer_key] = true
	_log_input_block(str(allowed.get("reason", "wrong_target")), ev)
	return false

func on_hive_clicked(hive_id: int, state: GameState, local_owner_id: int) -> void:
	if not _active:
		return
	if _current_step != STEP_SELECT_START_HIVE:
		if _current_step == STEP_FEED_FRIEND:
			_maybe_commit_feed_friend_destination_tap(hive_id, state)
		return
	if state == null or hive_id <= 0:
		return
	_local_owner_id = clampi(local_owner_id, 1, 4)
	_last_state = state
	var start_id: int = _anchor_id(ANCHOR_START_HIVE)
	if hive_id != start_id:
		return
	var hive: HiveData = state.find_hive_by_id(hive_id)
	if hive == null or int(hive.owner_id) != _local_owner_id:
		return
	_force_select_hive(state, hive_id)
	_commit_readout_for_step_input("tap_start_hive", false)
	_advance_to_step(STEP_FEED_FRIEND)
	_evaluate_current_step(state)

func hide(mark_inactive: bool = true) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false
	_hide_focus_visuals()
	if _readout_waiting_for_input:
		_resume_after_readout()
	_readout_waiting_for_input = false
	_readout_step_id = ""
	_delayed_step_id = ""
	_delayed_step_at_ms = 0
	_feed_friend_arrival_wait_active = false
	_feed_friend_arrival_baseline = 0
	_reverse_feed_phase = REVERSE_PHASE_TAP_DESTINATION
	_reverse_feed_arrival_wait_active = false
	_reverse_feed_arrival_baseline = 0
	_contest_cancel_wait_active = false
	_contest_cancel_baseline = 0
	_contest_enemy_opposed = false
	_enemy_opposed_anchors.clear()
	_start_attack_prompt_at_ms = 0
	_start_attack_phase = START_ATTACK_PHASE_TAP_SOURCE
	_overlap_swarm_seen = false
	_double_tap_swarm_seen = false
	_swarm_intro_auto_advance_at_ms = 0
	_pending_next_step_id = ""
	_pending_next_step_at_ms = 0
	_clear_attack_drag_gate()
	if mark_inactive:
		_active = false
		_unbind_signal()

func on_match_ended() -> void:
	if _active and _last_state != null and _is_enemy_hive_captured(_last_state):
		_complete_tutorial()
	elif _active:
		SFLog.info("TUTORIAL_CONTROLS_MATCH_ENDED_UNRESOLVED", {
			"step": _current_step
		})
	hide(true)

func tick(state: GameState, local_owner_id: int) -> void:
	if not _active:
		return
	if state == null:
		return
	_local_owner_id = clampi(local_owner_id, 1, 4)
	if _anchor_ids.is_empty():
		_anchor_ids = _resolve_anchor_ids(state)
	_last_state = state
	_maybe_advance_delayed_step()
	if _readout_waiting_for_input or (_step_uses_direct_action_gate(_current_step) and not _cancel_lane_gesture_started):
		_pause_for_readout()
	_maybe_auto_advance_swarm_intro()
	_evaluate_current_step(state)
	_refresh_overlay_copy()
	_refresh_focus_visuals()

func _on_lane_state_changed(_iid: int, _lane_id: int = -1) -> void:
	if not _active:
		return
	var ops_state: Node = _get_ops_state()
	if ops_state == null or not ops_state.has_method("get_state"):
		return
	var state: GameState = ops_state.call("get_state") as GameState
	if state == null:
		return
	_last_state = state
	_evaluate_current_step(state)

func _evaluate_current_step(state: GameState) -> void:
	if state == null:
		return
	_apply_recovery_guards(state)
	_update_step_edge_memory(state)
	var guard: int = 0
	while guard < 8:
		guard += 1
		var next_step: String = _next_step_for_state(state)
		if next_step.is_empty() or next_step == _current_step:
			_clear_pending_next_step()
			return
		if _pending_next_step_id != "":
			if next_step != _pending_next_step_id:
				_clear_pending_next_step()
				continue
			if Time.get_ticks_msec() < _pending_next_step_at_ms:
				return
			_clear_pending_next_step()
		elif _transition_uses_post_action_dwell(_current_step, next_step):
			_begin_post_action_dwell(next_step)
			return
		_advance_to_step(next_step)
		_update_step_edge_memory(state)

func _next_step_for_state(state: GameState) -> String:
	if _current_step == STEP_WELCOME:
		return ""
	if _is_enemy_hive_captured(state):
		return STEP_COMPLETE
	if _current_step == STEP_SELECT_START_HIVE:
		if _intent_is_on_between(state, ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE):
			return STEP_REVERSE_FEED
		if _selected_hive_is_anchor(state, ANCHOR_START_HIVE):
			return STEP_FEED_FRIEND
		return ""
	if _current_step == STEP_ATTACK_NEUTRAL_HIVE:
		if _anchor_owner_is_local(state, ANCHOR_NEUTRAL_HIVE):
			return STEP_FEED_FRIEND
		if _intent_is_on_between(state, ANCHOR_START_HIVE, ANCHOR_NEUTRAL_HIVE):
			return STEP_WAIT_CAPTURE_NEUTRAL
		return ""
	if _current_step == STEP_WAIT_CAPTURE_NEUTRAL:
		if _anchor_owner_is_local(state, ANCHOR_NEUTRAL_HIVE):
			return STEP_FEED_FRIEND
		return ""
	if _current_step == STEP_FEED_FRIEND:
		if _intent_is_on_between(state, ANCHOR_FRIEND_HIVE, ANCHOR_START_HIVE):
			return STEP_CANCEL_LANE_GRAB_THROW
		if _feed_friend_arrival_wait_active:
			if _feed_friend_arrival_delta() >= _feed_friend_arrival_target:
				return STEP_REVERSE_FEED
			return ""
		if _intent_is_on_between(state, ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE):
			_begin_feed_friend_arrival_wait()
			return ""
		return ""
	if _current_step == STEP_REVERSE_FEED:
		if _saw_friend_lane_retract:
			return STEP_ATTACK_ENEMY_HIVE
		if _reverse_feed_arrival_wait_active:
			if _reverse_feed_arrival_delta() >= _reverse_feed_arrival_target:
				return STEP_CANCEL_LANE_GRAB_THROW
			return ""
		if _intent_is_on_between(state, ANCHOR_FRIEND_HIVE, ANCHOR_START_HIVE):
			_begin_reverse_feed_arrival_wait()
			return ""
		return ""
	if _current_step == STEP_CANCEL_LANE_GRAB_THROW:
		if _lane_pair_inactive(state, ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE):
			return STEP_REMAKE_FRIEND_LANE
		return ""
	if _current_step == STEP_REMAKE_FRIEND_LANE:
		if _intent_is_on_between(state, ANCHOR_FRIEND_HIVE, ANCHOR_START_HIVE):
			return STEP_ATTACK_ENEMY_HIVE
		return ""
	if _current_step == STEP_ATTACK_ENEMY_HIVE:
		if _intent_is_on_between(state, ANCHOR_FRIEND_HIVE, ANCHOR_ENEMY_HIVE):
			return STEP_CONTEST_ENEMY_LANE
		return ""
	if _current_step == STEP_CONTEST_ENEMY_LANE:
		_oppose_enemy_lane_if_needed(state, ANCHOR_FRIEND_HIVE)
		if not _contest_cancel_wait_active:
			_begin_contest_cancel_wait()
		if _contest_cancel_delta() >= _contest_cancel_target:
			return STEP_ATTACK_ENEMY_FROM_START
		return ""
	if _current_step == STEP_ATTACK_ENEMY_FROM_START:
		if _intent_is_on_between(state, ANCHOR_START_HIVE, ANCHOR_ENEMY_HIVE):
			return STEP_TAKE_NEUTRAL_HIVE
		_oppose_enemy_lane_if_needed(state, ANCHOR_FRIEND_HIVE)
		if _start_attack_prompt_at_ms > 0 and Time.get_ticks_msec() - _start_attack_prompt_at_ms >= _start_attack_timeout_ms:
			return STEP_ATTACK_ENEMY_FROM_START_GUIDED
		return ""
	if _current_step == STEP_ATTACK_ENEMY_FROM_START_GUIDED:
		if _intent_is_on_between(state, ANCHOR_START_HIVE, ANCHOR_ENEMY_HIVE):
			return STEP_TAKE_NEUTRAL_HIVE
		_oppose_enemy_lane_if_needed(state, ANCHOR_FRIEND_HIVE)
		return ""
	if _current_step == STEP_TAKE_NEUTRAL_HIVE:
		_oppose_enemy_lane_if_needed(state, ANCHOR_START_HIVE)
		if _anchor_owner_is_local(state, ANCHOR_NEUTRAL_HIVE):
			return STEP_ATTACK_ENEMY_FROM_NEUTRAL
		return ""
	if _current_step == STEP_ATTACK_ENEMY_FROM_NEUTRAL:
		_oppose_enemy_lane_if_needed(state, ANCHOR_START_HIVE)
		if _intent_is_on_between(state, ANCHOR_NEUTRAL_HIVE, ANCHOR_ENEMY_HIVE):
			_oppose_enemy_lane_if_needed(state, ANCHOR_NEUTRAL_HIVE)
			return STEP_SWARM_INTRO
		return ""
	if _current_step == STEP_SWARM_INTRO:
		_oppose_enemy_lane_if_needed(state, ANCHOR_NEUTRAL_HIVE)
		return ""
	if _current_step == STEP_SWARM_BY_OVERLAP:
		_oppose_enemy_lane_if_needed(state, ANCHOR_NEUTRAL_HIVE)
		if _has_swarm_from_any_player_hive_to_enemy(state):
			return STEP_WAIT_OVERLAP_SWARM_HIT
		return ""
	if _current_step == STEP_WAIT_OVERLAP_SWARM_HIT:
		_oppose_enemy_lane_if_needed(state, ANCHOR_NEUTRAL_HIVE)
		if _has_swarm_from_any_player_hive_to_enemy(state):
			_overlap_swarm_seen = true
			return ""
		if _overlap_swarm_seen:
			return STEP_SWARM_DOUBLE_TAP
		return ""
	if _current_step == STEP_SWARM_DOUBLE_TAP:
		if _has_swarm_between(state, ANCHOR_START_HIVE, ANCHOR_ENEMY_HIVE) or _has_swarm_between(state, ANCHOR_FRIEND_HIVE, ANCHOR_ENEMY_HIVE):
			return STEP_FINISH_FIGHT
		return ""
	if _current_step == STEP_FINISH_FIGHT:
		if _is_enemy_hive_captured(state):
			return STEP_COMPLETE
		return ""
	return ""

func _transition_uses_post_action_dwell(from_step: String, to_step: String) -> bool:
	if to_step == STEP_COMPLETE:
		return false
	match from_step:
		STEP_SELECT_START_HIVE:
			return false
		STEP_REVERSE_FEED:
			return to_step == STEP_CANCEL_LANE_GRAB_THROW
		STEP_ATTACK_ENEMY_HIVE:
			return false
		STEP_SWARM_BY_OVERLAP:
			return false
		STEP_SWARM_INTRO:
			return false
		STEP_ATTACK_ENEMY_FROM_START_GUIDED:
			return to_step == STEP_TAKE_NEUTRAL_HIVE
		STEP_FEED_FRIEND, STEP_CANCEL_LANE_GRAB_THROW, STEP_REMAKE_FRIEND_LANE, STEP_CONTEST_ENEMY_LANE, STEP_ATTACK_ENEMY_FROM_START, STEP_TAKE_NEUTRAL_HIVE, STEP_ATTACK_ENEMY_FROM_NEUTRAL, STEP_WAIT_OVERLAP_SWARM_HIT:
			return true
		_:
			return false

func _begin_post_action_dwell(next_step: String) -> void:
	_pending_next_step_id = next_step
	_pending_next_step_at_ms = Time.get_ticks_msec() + POST_ACTION_DWELL_MS
	_readout_waiting_for_input = false
	_readout_step_id = ""
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false
	_hide_focus_visuals()
	_resume_after_readout()
	SFLog.info("TUTORIAL_CONTROLS_DWELL", {
		"step": _current_step,
		"next": next_step,
		"ms": POST_ACTION_DWELL_MS
	})

func _clear_pending_next_step() -> void:
	_pending_next_step_id = ""
	_pending_next_step_at_ms = 0

func _pending_next_step_remaining_ms() -> int:
	if _pending_next_step_id == "":
		return 0
	return maxi(0, _pending_next_step_at_ms - Time.get_ticks_msec())

func _apply_recovery_guards(state: GameState) -> void:
	if state == null:
		return
	if _anchor_ids.is_empty():
		_anchor_ids = _resolve_anchor_ids(state)
	_clear_wrong_selection_for_step(state)
	match _current_step:
		STEP_SWARM_BY_OVERLAP:
			for source_anchor in [ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE, ANCHOR_NEUTRAL_HIVE]:
				if not _intent_is_on_between(state, source_anchor, ANCHOR_ENEMY_HIVE):
					_restore_intent_between(source_anchor, ANCHOR_ENEMY_HIVE, "attack", "missing_overlap_swarm_lane_%s" % source_anchor)
		STEP_SWARM_DOUBLE_TAP:
			if not _intent_is_on_between(state, ANCHOR_START_HIVE, ANCHOR_ENEMY_HIVE):
				_restore_intent_between(ANCHOR_START_HIVE, ANCHOR_ENEMY_HIVE, "attack", "missing_middle_swarm_lane")
			if not _intent_is_on_between(state, ANCHOR_FRIEND_HIVE, ANCHOR_ENEMY_HIVE):
				_restore_intent_between(ANCHOR_FRIEND_HIVE, ANCHOR_ENEMY_HIVE, "attack", "missing_bottom_swarm_lane")
		_:
			pass

func _clear_wrong_selection_for_step(state: GameState) -> void:
	if state == null or state.selection == null:
		return
	var selected_id: int = int(state.selection.selected_hive_id)
	if selected_id <= 0:
		return
	var allowed: Array = []
	match _current_step:
		STEP_SELECT_START_HIVE:
			allowed = [ANCHOR_START_HIVE]
		STEP_ATTACK_NEUTRAL_HIVE:
			allowed = [ANCHOR_START_HIVE, ANCHOR_NEUTRAL_HIVE]
		STEP_FEED_FRIEND:
			allowed = [ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE]
		STEP_REVERSE_FEED:
			allowed = [ANCHOR_FRIEND_HIVE, ANCHOR_START_HIVE]
		STEP_REMAKE_FRIEND_LANE:
			allowed = [ANCHOR_START_HIVE] if _remake_friend_phase == REMAKE_PHASE_TAP_TARGET else [ANCHOR_FRIEND_HIVE]
		STEP_ATTACK_ENEMY_HIVE:
			allowed = [ANCHOR_FRIEND_HIVE, ANCHOR_ENEMY_HIVE]
		STEP_ATTACK_ENEMY_FROM_START, STEP_ATTACK_ENEMY_FROM_START_GUIDED:
			allowed = [ANCHOR_START_HIVE] if _readout_waiting_for_input else [ANCHOR_START_HIVE, ANCHOR_ENEMY_HIVE]
		STEP_TAKE_NEUTRAL_HIVE:
			allowed = [ANCHOR_START_HIVE, ANCHOR_NEUTRAL_HIVE]
		STEP_ATTACK_ENEMY_FROM_NEUTRAL:
			allowed = [ANCHOR_NEUTRAL_HIVE, ANCHOR_ENEMY_HIVE]
		STEP_SWARM_BY_OVERLAP:
			allowed = [ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE, ANCHOR_NEUTRAL_HIVE, ANCHOR_ENEMY_HIVE]
		_:
			return
	for anchor_any in allowed:
		if selected_id == _anchor_id(str(anchor_any)):
			return
	var ops_state: Node = _get_ops_state()
	if ops_state != null and ops_state.has_method("sim_mutate"):
		ops_state.call("sim_mutate", "tutorial_controls_clear_wrong_selection", func() -> void:
			if state.selection != null:
				state.selection.clear_selection()
		)
	else:
		return
	_log_recovery_once("clear_wrong_selection:%s" % _current_step, {
		"reason": "wrong_selection",
		"step": _current_step,
		"selected_hive_id": selected_id
	})

func _restore_intent_between(from_anchor: String, to_anchor: String, intent: String, reason: String) -> void:
	var from_id: int = _anchor_id(from_anchor)
	var to_id: int = _anchor_id(to_anchor)
	if from_id <= 0 or to_id <= 0:
		return
	var ops_state: Node = _get_ops_state()
	if ops_state == null or not ops_state.has_method("apply_lane_intent"):
		return
	var result_any: Variant = ops_state.call("apply_lane_intent", from_id, to_id, intent)
	var result: Dictionary = result_any as Dictionary if typeof(result_any) == TYPE_DICTIONARY else {}
	_log_recovery_once("%s:%d:%d:%s" % [reason, from_id, to_id, intent], {
		"reason": reason,
		"step": _current_step,
		"src": from_id,
		"dst": to_id,
		"intent": intent,
		"ok": bool(result.get("ok", false)),
		"result_reason": str(result.get("reason", ""))
	})

func _log_recovery_once(key: String, payload: Dictionary) -> void:
	if _recovery_keys_logged.has(key):
		return
	_recovery_keys_logged[key] = true
	SFLog.info("TUTORIAL_CONTROLS_RECOVERY", payload)

func _advance_to_step(step_id: String) -> void:
	if step_id.is_empty() or step_id == _current_step:
		return
	var previous_step: String = _current_step
	_clear_pending_next_step()
	_current_step = step_id
	if step_id == STEP_CANCEL_LANE_GRAB_THROW:
		_saw_friend_lane_retract = false
		_cancel_lane_gesture_started = false
	if step_id == STEP_REMAKE_FRIEND_LANE:
		_remake_friend_phase = REMAKE_PHASE_TAP_SOURCE
	if step_id == STEP_ATTACK_ENEMY_HIVE:
		_attack_enemy_phase = ATTACK_ENEMY_PHASE_TAP_SOURCE
		_clear_tutorial_selection("attack_enemy_hive_entry")
	if step_id == STEP_TAKE_NEUTRAL_HIVE:
		_take_neutral_phase = TAKE_NEUTRAL_PHASE_TAP_SOURCE
		_clear_tutorial_selection("take_neutral_hive_entry")
	if step_id == STEP_SWARM_BY_OVERLAP:
		_overlap_swarm_seen = false
		_swarm_overlap_phase = SWARM_OVERLAP_PHASE_TAP_SOURCE
		_swarm_overlap_source_anchor = ""
		_clear_tutorial_selection("swarm_by_overlap_entry")
	if step_id == STEP_SWARM_DOUBLE_TAP:
		_double_tap_swarm_seen = false
	if step_id == STEP_SWARM_INTRO:
		_swarm_intro_auto_advance_at_ms = Time.get_ticks_msec() + SWARM_INTRO_AUTO_ADVANCE_MS
	elif previous_step == STEP_SWARM_INTRO:
		_swarm_intro_auto_advance_at_ms = 0
	if step_id == STEP_CONTEST_ENEMY_LANE:
		_contest_cancel_wait_active = false
		_contest_cancel_baseline = 0
		_contest_enemy_opposed = false
	if step_id == STEP_ATTACK_ENEMY_FROM_START:
		_start_attack_prompt_at_ms = Time.get_ticks_msec()
	if step_id == STEP_ATTACK_ENEMY_FROM_START_GUIDED:
		_start_attack_phase = START_ATTACK_PHASE_TAP_SOURCE
	if step_id != STEP_ATTACK_ENEMY_HIVE:
		_clear_attack_drag_gate()
	if step_id != STEP_FEED_FRIEND:
		_feed_friend_arrival_wait_active = false
	if step_id == STEP_REVERSE_FEED:
		_reverse_feed_phase = REVERSE_PHASE_TAP_DESTINATION
		_reverse_feed_arrival_wait_active = false
		_reverse_feed_arrival_baseline = 0
	elif step_id != STEP_REVERSE_FEED:
		_reverse_feed_arrival_wait_active = false
	SFLog.info("TUTORIAL_CONTROLS_STEP", {
		"from": previous_step,
		"to": step_id
	})
	if step_id == STEP_COMPLETE:
		_complete_tutorial()
		return
	_enter_step(step_id)

func _enter_step(step_id: String) -> void:
	if _step_uses_readout_gate(step_id):
		_readout_waiting_for_input = true
		_readout_step_id = step_id
		_show_overlay()
		_pause_for_readout()
	elif _step_uses_direct_action_gate(step_id):
		# The instruction is already live: the first accepted pointer press must
		# begin the requested action, never dismiss or advance the readout.
		_readout_waiting_for_input = false
		_readout_step_id = ""
		_show_overlay()
		_pause_for_readout()
	elif _step_uses_live_overlay(step_id):
		_readout_waiting_for_input = false
		_readout_step_id = ""
		_show_overlay()
		_resume_after_readout()
	else:
		_readout_waiting_for_input = false
		_readout_step_id = ""
		if _overlay != null and is_instance_valid(_overlay):
			_overlay.visible = false
		_hide_focus_visuals()
		_resume_after_readout()
	_refresh_overlay_copy()
	_refresh_focus_visuals()

func _step_uses_readout_gate(step_id: String) -> bool:
	match step_id:
		STEP_WELCOME, STEP_SELECT_START_HIVE, STEP_ATTACK_NEUTRAL_HIVE, STEP_FEED_FRIEND, STEP_REVERSE_FEED, STEP_REMAKE_FRIEND_LANE, STEP_ATTACK_ENEMY_HIVE, STEP_ATTACK_ENEMY_FROM_START, STEP_ATTACK_ENEMY_FROM_START_GUIDED, STEP_ATTACK_ENEMY_FROM_NEUTRAL, STEP_SWARM_INTRO, STEP_SWARM_BY_OVERLAP, STEP_SWARM_DOUBLE_TAP:
			return true
		_:
			return false

func _step_uses_direct_action_gate(step_id: String) -> bool:
	return step_id == STEP_CANCEL_LANE_GRAB_THROW

func _step_uses_live_overlay(step_id: String) -> bool:
	return step_id == STEP_TAKE_NEUTRAL_HIVE

func _commit_readout_for_step_input(reason: String, resume_after: bool = true) -> void:
	if not _readout_waiting_for_input:
		return
	SFLog.info("TUTORIAL_CONTROLS_READOUT_COMMIT", {
		"step": _current_step,
		"reason": reason
	})
	_readout_waiting_for_input = false
	_readout_step_id = ""
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false
	_hide_focus_visuals()
	if _current_step == STEP_FEED_FRIEND:
		_begin_feed_friend_arrival_wait()
	if _current_step == STEP_REVERSE_FEED:
		_begin_reverse_feed_arrival_wait()
	if resume_after:
		_resume_after_readout()
	if _current_step == STEP_WELCOME:
		_delayed_step_id = STEP_SELECT_START_HIVE
		_delayed_step_at_ms = Time.get_ticks_msec() + 1000

func _maybe_advance_delayed_step() -> void:
	if _delayed_step_id.is_empty():
		return
	if Time.get_ticks_msec() < _delayed_step_at_ms:
		return
	var step_id: String = _delayed_step_id
	_delayed_step_id = ""
	_delayed_step_at_ms = 0
	_advance_to_step(step_id)

func _maybe_auto_advance_swarm_intro() -> void:
	if _current_step != STEP_SWARM_INTRO:
		return
	if _swarm_intro_auto_advance_at_ms <= 0:
		return
	if Time.get_ticks_msec() < _swarm_intro_auto_advance_at_ms:
		return
	_commit_readout_for_step_input("swarm_intro_auto_advance", false)
	_advance_to_step(STEP_SWARM_BY_OVERLAP)

func _swarm_intro_auto_advance_remaining_ms() -> int:
	if _current_step != STEP_SWARM_INTRO or _swarm_intro_auto_advance_at_ms <= 0:
		return 0
	return maxi(0, _swarm_intro_auto_advance_at_ms - Time.get_ticks_msec())

func _pause_for_readout() -> void:
	if _pause_sim_cb.is_valid():
		_pause_sim_cb.call()

func _resume_after_readout() -> void:
	if _resume_sim_cb.is_valid():
		_resume_sim_cb.call()

func _begin_attack_drag(pointer_key: String, ev: Dictionary) -> void:
	_attack_drag_pointer_key = pointer_key
	var local_v: Variant = ev.get("local_pos", Vector2.ZERO)
	_attack_drag_start_local = Vector2.ZERO
	if local_v is Vector2:
		_attack_drag_start_local = local_v as Vector2
	_attack_drag_moved = false

func _update_attack_drag(ev: Dictionary) -> void:
	var local_v: Variant = ev.get("local_pos", Vector2.ZERO)
	if not (local_v is Vector2):
		return
	var local_pos: Vector2 = local_v as Vector2
	if local_pos.distance_to(_attack_drag_start_local) >= 24.0:
		_attack_drag_moved = true

func _finish_attack_drag(pointer_key: String, ev: Dictionary) -> bool:
	var was_active: bool = _attack_drag_pointer_key == pointer_key
	var moved: bool = _attack_drag_moved
	_clear_attack_drag_gate()
	if not was_active:
		return true
	var hive_id: int = int(ev.get("hive_id", -1))
	if moved and hive_id == _anchor_id(ANCHOR_ENEMY_HIVE):
		_commit_readout_for_step_input("attack_enemy_drag")
		return true
	return true

func _clear_attack_drag_gate() -> void:
	_attack_drag_pointer_key = ""
	_attack_drag_start_local = Vector2.ZERO
	_attack_drag_moved = false

func _handle_prompted_tap_press(reason: String, state: GameState) -> bool:
	match _current_step:
		STEP_SELECT_START_HIVE:
			return false
		STEP_FEED_FRIEND:
			var feed_result: Dictionary = _apply_tutorial_lane_intent(ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE, "feed", reason)
			if bool(feed_result.get("ok", false)):
				_commit_readout_for_step_input(reason, false)
				_resume_after_readout()
				if state != null:
					_evaluate_current_step(state)
			return true
		STEP_REVERSE_FEED:
			if _reverse_feed_phase == REVERSE_PHASE_TAP_DESTINATION:
				_advance_reverse_feed_to_source_prompt()
				return true
			var reverse_result: Dictionary = _apply_tutorial_lane_intent(ANCHOR_FRIEND_HIVE, ANCHOR_START_HIVE, "feed", reason)
			if bool(reverse_result.get("ok", false)):
				_commit_readout_for_step_input(reason, false)
				_resume_after_readout()
				if state != null:
					_evaluate_current_step(state)
			return true
		STEP_REMAKE_FRIEND_LANE:
			if _remake_friend_phase == REMAKE_PHASE_TAP_SOURCE:
				_remake_friend_phase = REMAKE_PHASE_TAP_TARGET
				_refresh_overlay_copy()
				_refresh_focus_visuals()
				return false
			var remake_result: Dictionary = _apply_tutorial_lane_intent(ANCHOR_FRIEND_HIVE, ANCHOR_START_HIVE, "feed", reason)
			if bool(remake_result.get("ok", false)):
				_commit_readout_for_step_input(reason, false)
				_resume_after_readout()
				if state != null:
					_evaluate_current_step(state)
			return true
		STEP_ATTACK_ENEMY_HIVE:
			if _attack_enemy_phase == ATTACK_ENEMY_PHASE_TAP_SOURCE:
				_attack_enemy_phase = ATTACK_ENEMY_PHASE_TAP_TARGET
				_refresh_overlay_copy()
				_refresh_focus_visuals()
			# Both phases pass through to InputSystem. The source release selects the
			# hive; the destination release emits the authoritative attack intent.
			# A held source press can instead continue through the existing drag path.
			return false
		STEP_TAKE_NEUTRAL_HIVE:
			if _take_neutral_phase == TAKE_NEUTRAL_PHASE_TAP_SOURCE:
				_take_neutral_phase = TAKE_NEUTRAL_PHASE_TAP_TARGET
				_refresh_overlay_copy()
				_refresh_focus_visuals()
			# InputSystem owns both source selection and the authoritative attack intent.
			return false
		STEP_SWARM_BY_OVERLAP:
			if _swarm_overlap_phase == SWARM_OVERLAP_PHASE_TAP_SOURCE:
				_swarm_overlap_phase = SWARM_OVERLAP_PHASE_TAP_TARGET
				_refresh_overlay_copy()
				_refresh_focus_visuals()
			# InputSystem turns the already-active attack lane into a swarm intent.
			return false
		STEP_ATTACK_ENEMY_FROM_START:
			if _readout_waiting_for_input:
				_commit_readout_for_step_input(reason, true)
			return false
		STEP_ATTACK_ENEMY_FROM_START_GUIDED:
			if _start_attack_phase == START_ATTACK_PHASE_TAP_SOURCE:
				_advance_start_attack_to_target_prompt()
				return true
			var result: Dictionary = _apply_tutorial_lane_intent(ANCHOR_START_HIVE, ANCHOR_ENEMY_HIVE, "attack", reason)
			if bool(result.get("ok", false)):
				_commit_readout_for_step_input(reason, false)
				_resume_after_readout()
				if state != null:
					_evaluate_current_step(state)
			return true
		STEP_ATTACK_ENEMY_FROM_NEUTRAL:
			if _readout_waiting_for_input:
				_commit_readout_for_step_input(reason, true)
			return false
		_:
			return false

func _maybe_commit_feed_friend_destination_tap(hive_id: int, state: GameState) -> void:
	if not _readout_waiting_for_input:
		return
	if state == null or hive_id != _anchor_id(ANCHOR_FRIEND_HIVE):
		return
	var hive: HiveData = state.find_hive_by_id(hive_id)
	if hive == null or int(hive.owner_id) != _local_owner_id:
		return
	_commit_readout_for_step_input("feed_friend")

func _begin_feed_friend_arrival_wait() -> void:
	_feed_friend_arrival_wait_active = true
	_feed_friend_arrival_baseline = _arrival_count_for_anchor(ANCHOR_FRIEND_HIVE, _local_owner_id)

func _feed_friend_arrival_delta() -> int:
	if not _feed_friend_arrival_wait_active:
		return 0
	return maxi(0, _arrival_count_for_anchor(ANCHOR_FRIEND_HIVE, _local_owner_id) - _feed_friend_arrival_baseline)

func _arrival_count_for_anchor(anchor_name: String, owner_id: int) -> int:
	if not _arrival_count_cb.is_valid():
		return 0
	var hive_id: int = _anchor_id(anchor_name)
	if hive_id <= 0:
		return 0
	return int(_arrival_count_cb.call(hive_id, owner_id))

func _advance_reverse_feed_to_source_prompt() -> void:
	_reverse_feed_phase = REVERSE_PHASE_TAP_SOURCE
	_show_overlay()
	_pause_for_readout()
	_refresh_overlay_copy()
	_refresh_focus_visuals()

func _advance_start_attack_to_target_prompt() -> void:
	_start_attack_phase = START_ATTACK_PHASE_TAP_TARGET
	_show_overlay()
	_pause_for_readout()
	_refresh_overlay_copy()
	_refresh_focus_visuals()

func _begin_reverse_feed_arrival_wait() -> void:
	_reverse_feed_arrival_wait_active = true
	_reverse_feed_arrival_baseline = _arrival_count_for_anchor(ANCHOR_START_HIVE, _local_owner_id)

func _reverse_feed_arrival_delta() -> int:
	if not _reverse_feed_arrival_wait_active:
		return 0
	return maxi(0, _arrival_count_for_anchor(ANCHOR_START_HIVE, _local_owner_id) - _reverse_feed_arrival_baseline)

func _begin_contest_cancel_wait() -> void:
	_contest_cancel_wait_active = true
	_contest_cancel_baseline = _local_team_units_killed()

func _contest_cancel_delta() -> int:
	if not _contest_cancel_wait_active:
		return 0
	return maxi(0, _local_team_units_killed() - _contest_cancel_baseline)

func _local_team_units_killed() -> int:
	var ops_state: Node = _get_ops_state()
	if ops_state == null:
		return 0
	var team_id: int = _local_owner_id
	if ops_state.has_method("get_team_for_seat"):
		team_id = int(ops_state.call("get_team_for_seat", _local_owner_id))
	var stats_by_team_v: Variant = ops_state.get("stats_by_team")
	if typeof(stats_by_team_v) != TYPE_DICTIONARY:
		return 0
	var stats_by_team: Dictionary = stats_by_team_v as Dictionary
	var stats_v: Variant = stats_by_team.get(team_id, {})
	if typeof(stats_v) != TYPE_DICTIONARY:
		return 0
	var stats: Dictionary = stats_v as Dictionary
	return int(stats.get("units_killed", 0))

func _oppose_enemy_lane_if_needed(state: GameState, source_anchor: String) -> void:
	if state == null:
		return
	if source_anchor.is_empty():
		return
	if bool(_enemy_opposed_anchors.get(source_anchor, false)):
		return
	if not _intent_is_on_between(state, source_anchor, ANCHOR_ENEMY_HIVE):
		return
	_enemy_opposed_anchors[source_anchor] = true
	if source_anchor == ANCHOR_FRIEND_HIVE:
		_contest_enemy_opposed = true
	var result: Dictionary = _apply_tutorial_lane_intent(ANCHOR_ENEMY_HIVE, source_anchor, "attack", "enemy_contest")
	if not bool(result.get("ok", false)) and not _intent_is_on_between(state, ANCHOR_ENEMY_HIVE, source_anchor):
		_enemy_opposed_anchors[source_anchor] = false
		if source_anchor == ANCHOR_FRIEND_HIVE:
			_contest_enemy_opposed = false

func _apply_tutorial_lane_intent(from_anchor: String, to_anchor: String, intent: String, reason: String) -> Dictionary:
	var from_id: int = _anchor_id(from_anchor)
	var to_id: int = _anchor_id(to_anchor)
	var result: Dictionary = {
		"ok": false,
		"reason": "missing_anchor",
		"src": from_id,
		"dst": to_id,
		"intent": intent
	}
	if from_id <= 0 or to_id <= 0:
		SFLog.info("TUTORIAL_CONTROLS_INPUT_BLOCK", {
			"step": _current_step,
			"reason": "missing_anchor",
			"src": from_id,
			"dst": to_id,
			"intent": intent,
			"prompt_reason": reason
		})
		return result
	var ops_state: Node = _get_ops_state()
	if ops_state == null or not ops_state.has_method("apply_lane_intent"):
		result["reason"] = "ops_state_missing"
		SFLog.info("TUTORIAL_CONTROLS_INPUT_BLOCK", {
			"step": _current_step,
			"reason": "ops_state_missing",
			"src": from_id,
			"dst": to_id,
			"intent": intent,
			"prompt_reason": reason
		})
		return result
	var result_any: Variant = ops_state.call("apply_lane_intent", from_id, to_id, intent)
	if typeof(result_any) == TYPE_DICTIONARY:
		result = result_any as Dictionary
	if not bool(result.get("ok", false)):
		SFLog.info("TUTORIAL_CONTROLS_INPUT_BLOCK", {
			"step": _current_step,
			"reason": str(result.get("reason", "intent_failed")),
			"src": from_id,
			"dst": to_id,
			"intent": intent,
			"prompt_reason": reason
		})
	return result

func _complete_tutorial() -> void:
	_completed_this_match = true
	var profile_manager: Object = _get_profile_manager()
	if profile_manager != null and profile_manager.has_method("mark_tutorial_controls_completed"):
		profile_manager.call("mark_tutorial_controls_completed")
	SFLog.info("TUTORIAL_CONTROLS_COMPLETED", {})
	hide(true)

func _resolve_anchor_ids(state: GameState) -> Dictionary:
	var out: Dictionary = {}
	if state == null:
		return out
	for hive in state.hives:
		if not (hive is HiveData):
			continue
		var hive_data: HiveData = hive as HiveData
		for anchor_name in ANCHOR_POSITIONS.keys():
			var expected_pos: Vector2i = ANCHOR_POSITIONS[anchor_name]
			if hive_data.grid_pos == expected_pos:
				out[anchor_name] = int(hive_data.id)
	return out

func _show_overlay() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	_overlay.visible = true
	var parent_node: Node = _overlay.get_parent()
	if parent_node != null:
		parent_node.move_child(_overlay, parent_node.get_child_count() - 1)

func _refresh_overlay_copy() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var contract: Dictionary = _contract_for_step(_current_step)
	if _title_label != null:
		_title_label.text = "Controls Tutorial"
	if _body_label != null:
		if _readout_waiting_for_input or _step_uses_direct_action_gate(_current_step) or (_current_step == STEP_TAKE_NEUTRAL_HIVE and _take_neutral_phase == TAKE_NEUTRAL_PHASE_TAP_TARGET):
			_body_label.text = _readout_text_for_current_step(contract)
		else:
			_body_label.text = str(contract.get("instruction", ""))
	if _status_label != null:
		_status_label.text = _step_status_text()
	_refresh_focus_visuals()

func _step_status_text() -> String:
	var step_index: int = _step_index(_current_step)
	var total: int = step_contracts().size() - 1
	if _current_step == STEP_WELCOME:
		return "Tap anywhere to begin"
	if _current_step == STEP_COMPLETE:
		return "Complete"
	if step_index <= 0:
		return "%d/%d ready" % [_anchor_ids.size(), ANCHOR_POSITIONS.size()]
	return "Step %d/%d" % [step_index, total]

func _contract_for_step(step_id: String) -> Dictionary:
	for contract_any in step_contracts():
		if typeof(contract_any) != TYPE_DICTIONARY:
			continue
		var contract: Dictionary = contract_any as Dictionary
		if str(contract.get("id", "")) == step_id:
			return contract
	return {}

func _readout_text_for_current_step(contract: Dictionary) -> String:
	if _current_step == STEP_REVERSE_FEED and _reverse_feed_phase == REVERSE_PHASE_TAP_SOURCE:
		return "...and tap the source hive."
	if _current_step == STEP_REMAKE_FRIEND_LANE and _remake_friend_phase == REMAKE_PHASE_TAP_TARGET:
		return "Now tap the destination hive — or keep dragging there and release."
	if _current_step == STEP_ATTACK_ENEMY_HIVE and _attack_enemy_phase == ATTACK_ENEMY_PHASE_TAP_TARGET:
		return "Now tap the red destination hive — or keep dragging there and release."
	if _current_step == STEP_TAKE_NEUTRAL_HIVE and _take_neutral_phase == TAKE_NEUTRAL_PHASE_TAP_TARGET:
		return "Now tap the gray destination hive — or keep dragging there and release."
	if _current_step == STEP_SWARM_BY_OVERLAP and _swarm_overlap_phase == SWARM_OVERLAP_PHASE_TAP_TARGET:
		return "Now tap the red destination hive — or keep dragging there and release to swarm."
	if _current_step == STEP_ATTACK_ENEMY_FROM_START_GUIDED and _start_attack_phase == START_ATTACK_PHASE_TAP_TARGET:
		return "...and tap the red hive."
	return str(contract.get("readout", contract.get("instruction", "")))

func _build_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "TutorialControlsOverlay"
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.layout_mode = 3
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.grow_horizontal = 2
	overlay.grow_vertical = 2

	var panel := Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.0
	panel.offset_left = -360.0
	panel.offset_top = 24.0
	panel.offset_right = 360.0
	panel.offset_bottom = 284.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 28.0
	vbox.offset_top = 28.0
	vbox.offset_right = -28.0
	vbox.offset_bottom = -28.0
	vbox.add_theme_constant_override("separation", 24)
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "Controls Tutorial"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var body := Label.new()
	body.name = "Body"
	body.text = "Tap your starting hive."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)

	var status := Label.new()
	status.name = "Status"
	status.text = ""
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status)

	var skip_button := Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "Skip"
	vbox.add_child(skip_button)

	var focus_line := ColorRect.new()
	focus_line.name = "FocusLine"
	focus_line.visible = false
	focus_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_line.color = Color(1.0, 1.0, 1.0, 0.52)
	focus_line.z_index = 1
	overlay.add_child(focus_line)

	var lane_pull_ghost_shadow := _build_lane_pull_ghost("LanePullGhostShadow", Color(0.02, 0.03, 0.05, 0.50), 18.0, 5)
	overlay.add_child(lane_pull_ghost_shadow)
	var lane_pull_ghost := _build_lane_pull_ghost("LanePullGhost", Color(0.54, 0.88, 1.0, 0.86), 8.0, 6)
	overlay.add_child(lane_pull_ghost)

	for i in range(2):
		var lane_glow := _build_focus_line_rect("DoubleTapLaneGlow%d" % i, Color(1.0, 0.08, 0.05, 0.58), 3)
		overlay.add_child(lane_glow)
		var lane_core := _build_focus_line_rect("DoubleTapLaneCore%d" % i, Color(1.0, 0.96, 0.88, 0.94), 4)
		overlay.add_child(lane_core)

	var source_ring := _build_focus_ring("SourceFocusRing", Color(1.0, 1.0, 1.0, 0.90))
	overlay.add_child(source_ring)
	var target_ring := _build_focus_ring("TargetFocusRing", Color(0.54, 0.88, 1.0, 0.92))
	overlay.add_child(target_ring)

	var tap_hand := _build_tap_hand()
	overlay.add_child(tap_hand)
	return overlay

func _build_focus_line_rect(node_name: String, color: Color, z: int) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.visible = false
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = color
	rect.z_index = z
	return rect

func _build_lane_pull_ghost(node_name: String, color: Color, width_px: float, z: int) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.visible = false
	line.default_color = color
	line.width = width_px
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.z_index = z
	return line

func _build_focus_ring(node_name: String, color: Color) -> Panel:
	var ring := Panel.new()
	ring.name = node_name
	ring.visible = false
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.custom_minimum_size = Vector2(92.0, 92.0)
	ring.z_index = 2
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.03)
	style.border_color = color
	style.set_border_width_all(4)
	style.set_corner_radius_all(46)
	ring.add_theme_stylebox_override("panel", style)
	return ring

func _build_tap_hand() -> Control:
	var hand := Control.new()
	hand.name = "TapHand"
	hand.visible = false
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand.custom_minimum_size = Vector2(112.0, 132.0)
	hand.size = Vector2(112.0, 132.0)
	hand.z_index = 8

	var palm := _build_hand_panel("Palm", Vector2(72.0, 58.0), Vector2(20.0, 18.0), 22)
	hand.add_child(palm)
	var thumb := _build_hand_panel("Thumb", Vector2(34.0, 28.0), Vector2(10.0, 58.0), 14)
	thumb.rotation = -0.45
	hand.add_child(thumb)
	var finger := _build_hand_panel("Finger", Vector2(30.0, 78.0), Vector2(42.0, 48.0), 15)
	hand.add_child(finger)

	var tap_dot := Panel.new()
	tap_dot.name = "TapDot"
	tap_dot.position = Vector2(46.0, 116.0)
	tap_dot.size = Vector2(22.0, 12.0)
	tap_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color(1.0, 1.0, 1.0, 0.68)
	dot_style.border_color = Color(1.0, 0.08, 0.05, 0.82)
	dot_style.set_border_width_all(2)
	dot_style.set_corner_radius_all(8)
	tap_dot.add_theme_stylebox_override("panel", dot_style)
	hand.add_child(tap_dot)
	return hand

func _build_hand_panel(node_name: String, size_px: Vector2, position_px: Vector2, radius: int) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.position = position_px
	panel.size = size_px
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.78, 0.45, 0.96)
	style.border_color = Color(0.12, 0.08, 0.04, 0.94)
	style.set_border_width_all(4)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _style_overlay_nodes() -> void:
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", 54)
	if _body_label != null:
		_body_label.add_theme_font_size_override("font_size", 66)
	if _status_label != null:
		_status_label.add_theme_font_size_override("font_size", 39)
	if _skip_button != null:
		_skip_button.custom_minimum_size = Vector2(384.0, 108.0)
		_skip_button.add_theme_font_size_override("font_size", 42)

func _refresh_focus_visuals() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	if not _hive_screen_pos_cb.is_valid():
		_hide_focus_visuals()
		return
	if _current_step == STEP_FINISH_FIGHT or _current_step == STEP_COMPLETE:
		_hide_focus_visuals()
		return
	var contract: Dictionary = _contract_for_step(_current_step)
	var source_anchor: String = str(contract.get("source_anchor", ""))
	var target_anchor: String = str(contract.get("target_anchor", ""))
	if _current_step == STEP_WAIT_CAPTURE_NEUTRAL:
		source_anchor = ANCHOR_NEUTRAL_HIVE
		target_anchor = ""
	elif _current_step == STEP_REVERSE_FEED:
		if _reverse_feed_phase == REVERSE_PHASE_TAP_SOURCE:
			source_anchor = ""
			target_anchor = ANCHOR_START_HIVE
		else:
			source_anchor = ""
			target_anchor = ANCHOR_FRIEND_HIVE
	elif _current_step == STEP_CANCEL_LANE_GRAB_THROW:
		source_anchor = _cancel_lane_source_anchor(_last_state)
		target_anchor = _cancel_lane_target_anchor(_last_state)
	elif _current_step == STEP_ATTACK_ENEMY_FROM_START_GUIDED:
		if _start_attack_phase == START_ATTACK_PHASE_TAP_TARGET:
			source_anchor = ""
			target_anchor = ANCHOR_ENEMY_HIVE
		else:
			source_anchor = ANCHOR_START_HIVE
			target_anchor = ""
	var source_pos: Vector2 = _screen_pos_for_anchor(source_anchor)
	var target_pos: Vector2 = _screen_pos_for_anchor(target_anchor)
	_position_instruction_panel(source_pos, target_pos)
	if _current_step == STEP_SWARM_DOUBLE_TAP:
		_position_focus_ring(_source_ring, Vector2(-9999.0, -9999.0), 86.0)
		_position_focus_ring(_target_ring, target_pos, 96.0)
		if _lane_line != null:
			_lane_line.visible = false
		_position_double_tap_focus()
		return
	_hide_double_tap_focus()
	_hide_lane_pull_demo()
	if _current_step == STEP_CANCEL_LANE_GRAB_THROW:
		_position_focus_ring(_source_ring, Vector2(-9999.0, -9999.0), 86.0)
		_position_focus_ring(_target_ring, Vector2(-9999.0, -9999.0), 78.0)
		_position_focus_line(source_pos, target_pos, 0.5)
		_position_lane_pull_demo(source_pos, target_pos)
		return
	_position_focus_ring(_source_ring, source_pos, 86.0)
	_position_focus_ring(_target_ring, target_pos, 78.0)
	_position_focus_line(source_pos, target_pos)

func _hide_focus_visuals() -> void:
	if _source_ring != null:
		_source_ring.visible = false
	if _target_ring != null:
		_target_ring.visible = false
	if _lane_line != null:
		_lane_line.visible = false
	_hide_double_tap_focus()
	_hide_lane_pull_demo()

func _screen_pos_for_anchor(anchor_name: String) -> Vector2:
	var hive_id: int = _anchor_id(anchor_name)
	if hive_id <= 0 or not _hive_screen_pos_cb.is_valid():
		return Vector2(-9999.0, -9999.0)
	var pos_v: Variant = _hive_screen_pos_cb.call(hive_id)
	if pos_v is Vector2:
		return pos_v as Vector2
	return Vector2(-9999.0, -9999.0)

func _position_focus_ring(ring: Panel, screen_pos: Vector2, size_px: float) -> void:
	if ring == null:
		return
	if screen_pos.x < -1000.0 or screen_pos.y < -1000.0:
		ring.visible = false
		return
	var half: float = size_px * 0.5
	ring.visible = true
	ring.position = screen_pos - Vector2(half, half)
	ring.size = Vector2(size_px, size_px)

func _position_focus_line(source_pos: Vector2, target_pos: Vector2, length_scalar: float = 1.0) -> void:
	if _lane_line == null:
		return
	if source_pos.x < -1000.0 or target_pos.x < -1000.0:
		_lane_line.visible = false
		return
	var delta: Vector2 = target_pos - source_pos
	var length_px: float = delta.length() * clampf(length_scalar, 0.0, 1.0)
	if length_px <= 1.0:
		_lane_line.visible = false
		return
	_lane_line.visible = true
	_lane_line.position = source_pos
	_lane_line.pivot_offset = Vector2(0.0, 2.0)
	_lane_line.size = Vector2(length_px, 4.0)
	_lane_line.rotation = delta.angle()

func _position_double_tap_focus() -> void:
	var enemy_pos: Vector2 = _screen_pos_for_anchor(ANCHOR_ENEMY_HIVE)
	var start_pos: Vector2 = _screen_pos_for_anchor(ANCHOR_START_HIVE)
	var friend_pos: Vector2 = _screen_pos_for_anchor(ANCHOR_FRIEND_HIVE)
	_position_lane_segment(_double_tap_lane_glows, 0, start_pos, enemy_pos, 0.58, 0.94, 34.0)
	_position_lane_segment(_double_tap_lane_cores, 0, start_pos, enemy_pos, 0.58, 0.94, 9.0)
	_position_lane_segment(_double_tap_lane_glows, 1, friend_pos, enemy_pos, 0.58, 0.94, 34.0)
	_position_lane_segment(_double_tap_lane_cores, 1, friend_pos, enemy_pos, 0.58, 0.94, 9.0)
	_position_tap_hand(friend_pos.lerp(enemy_pos, 0.76))

func _position_lane_segment(nodes: Array, index: int, source_pos: Vector2, target_pos: Vector2, start_t: float, end_t: float, width_px: float) -> void:
	if index < 0 or index >= nodes.size():
		return
	var rect: ColorRect = nodes[index] as ColorRect
	if rect == null:
		return
	if source_pos.x < -1000.0 or target_pos.x < -1000.0:
		rect.visible = false
		return
	var start_pos: Vector2 = source_pos.lerp(target_pos, clampf(start_t, 0.0, 1.0))
	var end_pos: Vector2 = source_pos.lerp(target_pos, clampf(end_t, 0.0, 1.0))
	var delta: Vector2 = end_pos - start_pos
	var length_px: float = delta.length()
	if length_px <= 1.0:
		rect.visible = false
		return
	rect.visible = true
	rect.position = start_pos
	rect.pivot_offset = Vector2(0.0, width_px * 0.5)
	rect.size = Vector2(length_px, width_px)
	rect.rotation = delta.angle()

func _position_tap_hand(tap_pos: Vector2) -> void:
	if _tap_hand == null:
		return
	if tap_pos.x < -1000.0 or tap_pos.y < -1000.0:
		_tap_hand.visible = false
		return
	var phase: float = float(Time.get_ticks_msec() % 800) / 800.0
	var press_offset: float = 18.0 * absf(sin(phase * TAU))
	var hand_size: Vector2 = Vector2(112.0, 132.0)
	_tap_hand.visible = true
	_tap_hand.size = hand_size
	_tap_hand.position = tap_pos - Vector2(56.0, 122.0) + Vector2(0.0, press_offset - 18.0)

func _position_lane_pull_demo(source_pos: Vector2, target_pos: Vector2) -> void:
	if _lane_pull_ghost == null or _lane_pull_ghost_shadow == null or _tap_hand == null:
		return
	if source_pos.x < -1000.0 or target_pos.x < -1000.0:
		_hide_lane_pull_demo()
		return
	var lane_delta: Vector2 = target_pos - source_pos
	if lane_delta.length_squared() <= 1.0:
		_hide_lane_pull_demo()
		return
	var grab_pos: Vector2 = source_pos.lerp(target_pos, 0.32)
	var pull_dir: Vector2 = Vector2(-lane_delta.y, lane_delta.x).normalized()
	var viewport_size: Vector2 = _overlay.size if _overlay != null else Vector2.ZERO
	if _overlay != null and _overlay.get_viewport() != null:
		viewport_size = _overlay.get_viewport().get_visible_rect().size
	var pull_distance: float = clampf(lane_delta.length() * 0.28, 96.0, 180.0)
	var pull_end_a: Vector2 = grab_pos + pull_dir * pull_distance
	var pull_end_b: Vector2 = grab_pos - pull_dir * pull_distance
	var viewport_center: Vector2 = viewport_size * 0.5
	var pull_end: Vector2 = pull_end_a
	if pull_end_b.distance_squared_to(viewport_center) < pull_end_a.distance_squared_to(viewport_center):
		pull_end = pull_end_b

	var phase: float = float(Time.get_ticks_msec() % 2200) / 2200.0
	var pull_t: float = 0.0
	if phase >= 0.18 and phase < 0.66:
		pull_t = smoothstep(0.0, 1.0, (phase - 0.18) / 0.48)
	elif phase >= 0.66 and phase < 0.82:
		pull_t = 1.0
	elif phase >= 0.82:
		pull_t = 1.0 - smoothstep(0.0, 1.0, (phase - 0.82) / 0.18)
	var hand_pos: Vector2 = grab_pos.lerp(pull_end, pull_t)
	var bend_pos: Vector2 = grab_pos.lerp(hand_pos, 0.62)
	var ghost_points := PackedVector2Array([source_pos, grab_pos, bend_pos, hand_pos])
	_lane_pull_ghost_shadow.points = ghost_points
	_lane_pull_ghost.points = ghost_points
	_lane_pull_ghost_shadow.visible = true
	_lane_pull_ghost.visible = true
	_tap_hand.visible = true
	_tap_hand.size = Vector2(112.0, 132.0)
	_tap_hand.position = hand_pos - Vector2(56.0, 122.0)

func _hide_lane_pull_demo() -> void:
	if _lane_pull_ghost_shadow != null:
		_lane_pull_ghost_shadow.visible = false
	if _lane_pull_ghost != null:
		_lane_pull_ghost.visible = false

func _hide_double_tap_focus() -> void:
	for glow_any in _double_tap_lane_glows:
		var glow: ColorRect = glow_any as ColorRect
		if glow != null:
			glow.visible = false
	for core_any in _double_tap_lane_cores:
		var core: ColorRect = core_any as ColorRect
		if core != null:
			core.visible = false
	if _tap_hand != null:
		_tap_hand.visible = false

func _double_tap_focus_visible() -> bool:
	for glow_any in _double_tap_lane_glows:
		var glow: ColorRect = glow_any as ColorRect
		if glow != null and glow.visible:
			return true
	return false

func _position_instruction_panel(source_pos: Vector2, target_pos: Vector2) -> void:
	if _panel == null or _overlay == null or not is_instance_valid(_panel):
		return
	var viewport_size: Vector2 = Vector2.ZERO
	var viewport: Viewport = _overlay.get_viewport()
	if viewport != null:
		viewport_size = viewport.get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = _overlay.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var panel_w: float = clampf(viewport_size.x - 48.0, 720.0, 1040.0)
	var panel_h: float = 660.0 if _readout_waiting_for_input or _step_uses_direct_action_gate(_current_step) else 336.0
	var focus_y: float = source_pos.y
	if target_pos.x > -1000.0:
		focus_y = maxf(focus_y, target_pos.y)
	var use_top: bool = focus_y > viewport_size.y * 0.56
	var y: float = 56.0 if use_top else viewport_size.y - panel_h - 56.0
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -panel_w * 0.5
	_panel.offset_right = panel_w * 0.5
	_panel.offset_top = y
	_panel.offset_bottom = y + panel_h

func _on_skip_pressed() -> void:
	var profile_manager: Object = _get_profile_manager()
	if profile_manager != null and profile_manager.has_method("mark_tutorial_controls_skipped"):
		profile_manager.call("mark_tutorial_controls_skipped")
	hide(true)

func _press_allowed_for_step(ev: Dictionary, state: GameState) -> Dictionary:
	if _current_step == STEP_FINISH_FIGHT or _current_step == STEP_COMPLETE:
		return {"ok": true}
	var hive_id: int = int(ev.get("hive_id", -1))
	var lane_id: int = int(ev.get("lane_id", -1))
	match _current_step:
		STEP_WELCOME:
			return {"ok": true, "reason": "welcome_begin", "consume": true}
		STEP_SELECT_START_HIVE:
			var start_allowed: Dictionary = _allow_hive(hive_id, [ANCHOR_START_HIVE], "tap_start_hive")
			if bool(start_allowed.get("ok", false)):
				start_allowed["defer_commit"] = true
			return start_allowed
		STEP_ATTACK_NEUTRAL_HIVE:
			return _allow_hive(hive_id, [ANCHOR_START_HIVE, ANCHOR_NEUTRAL_HIVE], "attack_neutral")
		STEP_WAIT_CAPTURE_NEUTRAL:
			return {"ok": false, "reason": "wait_for_capture"}
		STEP_FEED_FRIEND:
			return _allow_hive(hive_id, [ANCHOR_FRIEND_HIVE], "feed_friend")
		STEP_REVERSE_FEED:
			if _reverse_feed_phase == REVERSE_PHASE_TAP_SOURCE:
				return _allow_hive(hive_id, [ANCHOR_START_HIVE], "reverse_feed_source")
			return _allow_hive(hive_id, [ANCHOR_FRIEND_HIVE], "reverse_feed_destination")
		STEP_CANCEL_LANE_GRAB_THROW:
			if _lane_id_matches_anchors(state, lane_id, ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE) and _lane_press_is_on_cancel_source_half(ev, state):
				return {"ok": true, "reason": "cancel_lane_source_half", "defer_commit": true}
			return {"ok": false, "reason": "cancel_lane_source_half"}
		STEP_REMAKE_FRIEND_LANE:
			var remake_anchors: Array = [ANCHOR_START_HIVE] if _remake_friend_phase == REMAKE_PHASE_TAP_TARGET or _selected_hive_is_anchor(state, ANCHOR_FRIEND_HIVE) else [ANCHOR_FRIEND_HIVE]
			var remake_allowed: Dictionary = _allow_hive(hive_id, remake_anchors, "remake_friend_lane_bottom_to_top")
			if bool(remake_allowed.get("ok", false)):
				remake_allowed["defer_commit"] = true
			return remake_allowed
		STEP_ATTACK_ENEMY_HIVE:
			var attack_anchors: Array = [ANCHOR_ENEMY_HIVE] if _attack_enemy_phase == ATTACK_ENEMY_PHASE_TAP_TARGET else [ANCHOR_FRIEND_HIVE]
			var attack_reason: String = "attack_enemy_target" if _attack_enemy_phase == ATTACK_ENEMY_PHASE_TAP_TARGET else "attack_enemy_drag_source"
			var attack_source_allowed: Dictionary = _allow_hive(hive_id, attack_anchors, attack_reason)
			if bool(attack_source_allowed.get("ok", false)):
				attack_source_allowed["defer_commit"] = true
			return attack_source_allowed
		STEP_ATTACK_ENEMY_FROM_START:
			var attack_from_start_anchors: Array = [ANCHOR_START_HIVE] if _readout_waiting_for_input else [ANCHOR_START_HIVE, ANCHOR_ENEMY_HIVE]
			var attack_from_start_allowed: Dictionary = _allow_hive(hive_id, attack_from_start_anchors, "attack_enemy_from_start")
			if bool(attack_from_start_allowed.get("ok", false)) and _readout_waiting_for_input:
				attack_from_start_allowed["defer_commit"] = true
			return attack_from_start_allowed
		STEP_ATTACK_ENEMY_FROM_START_GUIDED:
			if _start_attack_phase == START_ATTACK_PHASE_TAP_TARGET:
				return _allow_hive(hive_id, [ANCHOR_ENEMY_HIVE], "attack_enemy_from_start_target")
			var start_attack_allowed: Dictionary = _allow_hive(hive_id, [ANCHOR_START_HIVE], "attack_enemy_from_start_source")
			if bool(start_attack_allowed.get("ok", false)):
				start_attack_allowed["defer_commit"] = true
			return start_attack_allowed
		STEP_TAKE_NEUTRAL_HIVE:
			var take_neutral_anchors: Array = [ANCHOR_NEUTRAL_HIVE] if _take_neutral_phase == TAKE_NEUTRAL_PHASE_TAP_TARGET else [ANCHOR_START_HIVE]
			var take_neutral_reason: String = "take_neutral_target" if _take_neutral_phase == TAKE_NEUTRAL_PHASE_TAP_TARGET else "take_neutral_source"
			var take_neutral_allowed: Dictionary = _allow_hive(hive_id, take_neutral_anchors, take_neutral_reason)
			if bool(take_neutral_allowed.get("ok", false)):
				take_neutral_allowed["defer_commit"] = true
			return take_neutral_allowed
		STEP_ATTACK_ENEMY_FROM_NEUTRAL:
			var neutral_attack_anchors: Array = [ANCHOR_NEUTRAL_HIVE] if _readout_waiting_for_input else [ANCHOR_NEUTRAL_HIVE, ANCHOR_ENEMY_HIVE]
			var neutral_attack_allowed: Dictionary = _allow_hive(hive_id, neutral_attack_anchors, "attack_enemy_from_neutral")
			if bool(neutral_attack_allowed.get("ok", false)):
				neutral_attack_allowed["defer_commit"] = true
			return neutral_attack_allowed
		STEP_SWARM_INTRO:
			return {"ok": false, "reason": "swarm_intro_auto_advance"}
		STEP_SWARM_BY_OVERLAP:
			var overlap_anchors: Array = [ANCHOR_ENEMY_HIVE] if _swarm_overlap_phase == SWARM_OVERLAP_PHASE_TAP_TARGET else _swarm_overlap_source_anchors(state)
			var overlap_reason: String = "swarm_by_overlap_target" if _swarm_overlap_phase == SWARM_OVERLAP_PHASE_TAP_TARGET else "swarm_by_overlap_source"
			var overlap_allowed: Dictionary = _allow_hive(hive_id, overlap_anchors, overlap_reason)
			if bool(overlap_allowed.get("ok", false)):
				overlap_allowed["defer_commit"] = true
			return overlap_allowed
		STEP_SWARM_DOUBLE_TAP:
			var swarm_lane_id: int = _swarm_double_tap_lane_id_for_press(ev, state)
			if swarm_lane_id > 0:
				ev["lane_id"] = swarm_lane_id
				return {"ok": true, "reason": "swarm_double_tap_lane", "defer_commit": true}
			return {"ok": false, "reason": "swarm_double_tap_red_half"}
		_:
			return {"ok": true}

func _allow_hive(hive_id: int, anchors: Array, reason: String) -> Dictionary:
	if hive_id <= 0:
		return {"ok": false, "reason": reason}
	for anchor_any in anchors:
		if hive_id == _anchor_id(str(anchor_any)):
			return {"ok": true, "reason": reason}
	return {"ok": false, "reason": reason}

func _lane_id_matches_anchors(state: GameState, lane_id: int, anchor_a: String, anchor_b: String) -> bool:
	if state == null or lane_id <= 0:
		return false
	var a_id: int = _anchor_id(anchor_a)
	var b_id: int = _anchor_id(anchor_b)
	if a_id <= 0 or b_id <= 0:
		return false
	for lane_any in state.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		if int(lane.id) != lane_id:
			continue
		return (int(lane.a_id) == a_id and int(lane.b_id) == b_id) or (int(lane.a_id) == b_id and int(lane.b_id) == a_id)
	return false

func _swarm_double_tap_lane_id_for_press(ev: Dictionary, state: GameState) -> int:
	if state == null:
		return -1
	var event_lane_id: int = int(ev.get("lane_id", -1))
	var screen_v: Variant = ev.get("screen_pos", Vector2.ZERO)
	var has_screen_pos: bool = screen_v is Vector2 and (screen_v as Vector2).length_squared() > 0.001
	var screen_pos: Vector2 = screen_v as Vector2 if screen_v is Vector2 else Vector2.ZERO
	var best_lane_id: int = -1
	var best_distance: float = INF
	for source_anchor in [ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE]:
		if not _intent_is_on_between(state, source_anchor, ANCHOR_ENEMY_HIVE):
			continue
		var eligible_lane_id: int = _lane_id_between_anchors(state, source_anchor, ANCHOR_ENEMY_HIVE)
		if eligible_lane_id <= 0:
			continue
		if not has_screen_pos:
			if event_lane_id == eligible_lane_id:
				return eligible_lane_id
			continue
		var source_pos: Vector2 = _screen_pos_for_anchor(source_anchor)
		var enemy_pos: Vector2 = _screen_pos_for_anchor(ANCHOR_ENEMY_HIVE)
		if source_pos.x < -1000.0 or enemy_pos.x < -1000.0:
			continue
		var segment: Vector2 = enemy_pos - source_pos
		var length_sq: float = segment.length_squared()
		if length_sq <= 1.0:
			continue
		var t: float = clampf((screen_pos - source_pos).dot(segment) / length_sq, 0.0, 1.0)
		if t < 0.5:
			continue
		var closest: Vector2 = source_pos.lerp(enemy_pos, t)
		var distance: float = screen_pos.distance_to(closest)
		if distance <= SWARM_DOUBLE_TAP_SCREEN_PICK_RADIUS_PX and distance < best_distance:
			best_distance = distance
			best_lane_id = eligible_lane_id
	return best_lane_id

func _lane_id_between_anchors(state: GameState, anchor_a: String, anchor_b: String) -> int:
	if state == null:
		return -1
	var a_id: int = _anchor_id(anchor_a)
	var b_id: int = _anchor_id(anchor_b)
	if a_id <= 0 or b_id <= 0:
		return -1
	for lane_any in state.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		if (int(lane.a_id) == a_id and int(lane.b_id) == b_id) or (int(lane.a_id) == b_id and int(lane.b_id) == a_id):
			return int(lane.id)
	return -1

func _lane_press_is_on_cancel_source_half(ev: Dictionary, state: GameState) -> bool:
	var source_anchor: String = _cancel_lane_source_anchor(state)
	var target_anchor: String = _cancel_lane_target_anchor(state)
	var source_pos: Vector2 = _screen_pos_for_anchor(source_anchor)
	var target_pos: Vector2 = _screen_pos_for_anchor(target_anchor)
	if source_pos.x < -1000.0 or target_pos.x < -1000.0:
		return true
	var screen_v: Variant = ev.get("screen_pos", Vector2.ZERO)
	if not (screen_v is Vector2):
		return true
	var screen_pos: Vector2 = screen_v as Vector2
	if screen_pos.length_squared() <= 0.001:
		return true
	var segment: Vector2 = target_pos - source_pos
	var segment_len_sq: float = segment.length_squared()
	if segment_len_sq <= 1.0:
		return true
	var t: float = clampf((screen_pos - source_pos).dot(segment) / segment_len_sq, 0.0, 1.0)
	return t <= 0.5

func _cancel_lane_source_anchor(state: GameState) -> String:
	if state != null and _intent_is_on_between(state, ANCHOR_FRIEND_HIVE, ANCHOR_START_HIVE):
		return ANCHOR_FRIEND_HIVE
	return ANCHOR_START_HIVE

func _cancel_lane_target_anchor(state: GameState) -> String:
	if _cancel_lane_source_anchor(state) == ANCHOR_FRIEND_HIVE:
		return ANCHOR_START_HIVE
	return ANCHOR_FRIEND_HIVE

func _pointer_key(ev: Dictionary) -> String:
	if bool(ev.get("is_touch", false)):
		return "touch:%d" % int(ev.get("touch_index", -1))
	return "mouse:%d" % int(ev.get("button", 1))

func _log_input_block(reason: String, ev: Dictionary) -> void:
	SFLog.info("TUTORIAL_CONTROLS_INPUT_BLOCK", {
		"step": _current_step,
		"reason": reason,
		"hive_id": int(ev.get("hive_id", -1)),
		"lane_id": int(ev.get("lane_id", -1)),
		"pointer": _pointer_key(ev)
	})

func _anchor_id(anchor_name: String) -> int:
	return int(_anchor_ids.get(anchor_name, -1))

func _anchor_name_for_hive_id(hive_id: int) -> String:
	if hive_id <= 0:
		return ""
	for anchor_name_any in _anchor_ids.keys():
		var anchor_name: String = str(anchor_name_any)
		if _anchor_id(anchor_name) == hive_id:
			return anchor_name
	return ""

func _swarm_overlap_source_anchors(state: GameState) -> Array:
	var out: Array = []
	if state == null:
		return out
	for source_anchor in [ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE, ANCHOR_NEUTRAL_HIVE]:
		if _anchor_owner_is_local(state, source_anchor) and _intent_is_on_between(state, source_anchor, ANCHOR_ENEMY_HIVE):
			out.append(source_anchor)
	return out

func _swarm_overlap_source_ids(state: GameState) -> Array[int]:
	var out: Array[int] = []
	for source_anchor_any in _swarm_overlap_source_anchors(state):
		var hive_id: int = _anchor_id(str(source_anchor_any))
		if hive_id > 0:
			out.append(hive_id)
	return out

func _selected_hive_is_anchor(state: GameState, anchor_name: String) -> bool:
	if state == null or state.selection == null:
		return false
	var selected_id: int = int(state.selection.selected_hive_id)
	if selected_id <= 0:
		return false
	return selected_id == _anchor_id(anchor_name)

func _clear_tutorial_selection(reason: String) -> void:
	if _last_state == null or _last_state.selection == null:
		return
	var ops_state: Node = _get_ops_state()
	if ops_state == null or not ops_state.has_method("sim_mutate"):
		return
	ops_state.call("sim_mutate", "tutorial_controls_clear_selection_%s" % reason, func() -> void:
		if _last_state != null and _last_state.selection != null:
			_last_state.selection.clear_selection()
	)

func _force_select_hive(state: GameState, hive_id: int) -> void:
	if state == null or state.selection == null or hive_id <= 0:
		return
	var ops_state: Node = _get_ops_state()
	if ops_state != null and ops_state.has_method("sim_mutate"):
		ops_state.call("sim_mutate", "tutorial_controls_force_select_hive", func() -> void:
			if state.selection != null:
				state.selection.selected_hive_id = hive_id
				state.selection.selected_lane_id = -1
		)
		return
	state.selection.selected_hive_id = hive_id
	state.selection.selected_lane_id = -1

func _anchor_owner_is_local(state: GameState, anchor_name: String) -> bool:
	var hive: HiveData = _anchor_hive(state, anchor_name)
	return hive != null and int(hive.owner_id) == _local_owner_id

func _is_enemy_hive_captured(state: GameState) -> bool:
	return _anchor_owner_is_local(state, ANCHOR_ENEMY_HIVE)

func _anchor_hive(state: GameState, anchor_name: String) -> HiveData:
	if state == null:
		return null
	var hive_id: int = _anchor_id(anchor_name)
	if hive_id <= 0:
		return null
	return state.find_hive_by_id(hive_id)

func _intent_is_on_between(state: GameState, from_anchor: String, to_anchor: String) -> bool:
	if state == null:
		return false
	var from_id: int = _anchor_id(from_anchor)
	var to_id: int = _anchor_id(to_anchor)
	if from_id <= 0 or to_id <= 0:
		return false
	return state.intent_is_on(from_id, to_id)

func _lane_pair_inactive(state: GameState, anchor_a: String, anchor_b: String) -> bool:
	if state == null:
		return false
	var a_id: int = _anchor_id(anchor_a)
	var b_id: int = _anchor_id(anchor_b)
	if a_id <= 0 or b_id <= 0:
		return false
	return not state.intent_is_on(a_id, b_id) and not state.intent_is_on(b_id, a_id)

func _update_step_edge_memory(state: GameState) -> void:
	if state == null:
		return
	if _current_step == STEP_CANCEL_LANE_GRAB_THROW and _has_retract_between(state, ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE):
		_saw_friend_lane_retract = true
	if _current_step == STEP_SWARM_BY_OVERLAP and _has_swarm_from_any_player_hive_to_enemy(state):
		_overlap_swarm_seen = true
	if _current_step == STEP_SWARM_DOUBLE_TAP and (_has_swarm_between(state, ANCHOR_START_HIVE, ANCHOR_ENEMY_HIVE) or _has_swarm_between(state, ANCHOR_FRIEND_HIVE, ANCHOR_ENEMY_HIVE)):
		_double_tap_swarm_seen = true

func _has_retract_between(state: GameState, anchor_a: String, anchor_b: String) -> bool:
	var a_id: int = _anchor_id(anchor_a)
	var b_id: int = _anchor_id(anchor_b)
	if a_id <= 0 or b_id <= 0:
		return false
	for req_any in state.lane_retract_requests:
		if typeof(req_any) != TYPE_DICTIONARY:
			continue
		var req: Dictionary = req_any as Dictionary
		var from_id: int = int(req.get("from_id", -1))
		var to_id: int = int(req.get("to_id", -1))
		if (from_id == a_id and to_id == b_id) or (from_id == b_id and to_id == a_id):
			return true
	return false

func _has_swarm_between(state: GameState, src_anchor: String, dst_anchor: String) -> bool:
	if state == null:
		return false
	var src_id: int = _anchor_id(src_anchor)
	var dst_id: int = _anchor_id(dst_anchor)
	if src_id <= 0 or dst_id <= 0:
		return false
	for req_any in state.swarm_requests:
		if typeof(req_any) != TYPE_DICTIONARY:
			continue
		var req: Dictionary = req_any as Dictionary
		if _is_local_swarm_between(state, int(req.get("src", -1)), int(req.get("dst", -1)), src_id, dst_id):
			return true
	for packet_any in state.swarm_packets:
		if typeof(packet_any) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = packet_any as Dictionary
		if _is_local_swarm_between(state, int(packet.get("from_id", -1)), int(packet.get("to_id", -1)), src_id, dst_id):
			return true
	return false

func _has_swarm_from_any_player_hive_to_enemy(state: GameState) -> bool:
	for source_anchor in [ANCHOR_START_HIVE, ANCHOR_FRIEND_HIVE, ANCHOR_NEUTRAL_HIVE]:
		if _has_swarm_between(state, source_anchor, ANCHOR_ENEMY_HIVE):
			return true
	return false

func _is_local_swarm_between(state: GameState, actual_src_id: int, actual_dst_id: int, expected_src_id: int, expected_dst_id: int) -> bool:
	if actual_src_id != expected_src_id or actual_dst_id != expected_dst_id:
		return false
	var src_hive: HiveData = state.find_hive_by_id(actual_src_id)
	return src_hive != null and int(src_hive.owner_id) == _local_owner_id

func _step_index(step_id: String) -> int:
	var index: int = 0
	for contract_any in step_contracts():
		index += 1
		if typeof(contract_any) != TYPE_DICTIONARY:
			continue
		var contract: Dictionary = contract_any as Dictionary
		if str(contract.get("id", "")) == step_id:
			return index
	return 0

func _bind_signal_once() -> void:
	if _signal_bound:
		return
	var ops_state: Node = _get_ops_state()
	if ops_state == null:
		return
	var lane_cb := Callable(self, "_on_lane_state_changed")
	if ops_state.has_signal("lane_intent_changed") and not ops_state.is_connected("lane_intent_changed", lane_cb):
		ops_state.connect("lane_intent_changed", lane_cb)
	var lanes_cb := Callable(self, "_on_lane_state_changed")
	if ops_state.has_signal("lanes_changed") and not ops_state.is_connected("lanes_changed", lanes_cb):
		ops_state.connect("lanes_changed", lanes_cb)
	_signal_bound = true

func _unbind_signal() -> void:
	if not _signal_bound:
		return
	var ops_state: Node = _get_ops_state()
	if ops_state == null:
		_signal_bound = false
		return
	var cb := Callable(self, "_on_lane_state_changed")
	if ops_state.has_signal("lane_intent_changed") and ops_state.is_connected("lane_intent_changed", cb):
		ops_state.disconnect("lane_intent_changed", cb)
	if ops_state.has_signal("lanes_changed") and ops_state.is_connected("lanes_changed", cb):
		ops_state.disconnect("lanes_changed", cb)
	_signal_bound = false

func _sanitize_status(status: String) -> String:
	var cleaned: String = status.strip_edges().to_lower()
	if cleaned == STATUS_IN_PROGRESS:
		return STATUS_IN_PROGRESS
	if cleaned == STATUS_COMPLETED:
		return STATUS_COMPLETED
	if cleaned == STATUS_SKIPPED:
		return STATUS_SKIPPED
	return STATUS_NOT_STARTED

func _get_profile_manager() -> Object:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null:
		return null
	if not (loop is SceneTree):
		return null
	var tree: SceneTree = loop as SceneTree
	if tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/ProfileManager")

func _get_ops_state() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null:
		return null
	if not (loop is SceneTree):
		return null
	var tree: SceneTree = loop as SceneTree
	if tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/OpsState")
