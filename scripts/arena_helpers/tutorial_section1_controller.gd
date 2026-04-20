class_name ArenaTutorialSection1Controller
extends RefCounted

const STATUS_NOT_STARTED: String = "not_started"
const STATUS_IN_PROGRESS: String = "in_progress"
const STATUS_COMPLETED: String = "completed"
const STATUS_SKIPPED: String = "skipped"

const STEP_0_INTRO: String = "step_0_intro"
const STEP_1_ATTACK_LANE: String = "step_1_attack_lane"
const STEP_2_RETRACT_LANE: String = "step_2_retract_lane"
const STEP_3_CAPTURE_HIVE: String = "step_3_capture_hive"
const STEP_4_BUFF: String = "step_4_buff"
const STEP_4_SWARM_FINISH: String = "step_4_swarm_finish"
const STEP_COMPLETED: String = "completed"
const STEP_SKIPPED: String = "skipped"
const TYPEWRITER_WORDS_PER_MINUTE: float = 120.0
const TYPEWRITER_CHARS_PER_WORD: float = 5.0
const TYPEWRITER_MIN_DURATION_SEC: float = 0.5
const OBJECTIVE_AUTO_HIDE_READ_SEC: float = 4.0
const SWARM_INTRO_ENEMY_POWER_MAX: int = 5

var _overlay: Control = null
var _title_label: Label = null
var _body_label: Label = null
var _status_label: Label = null
var _continue_button: Button = null
var _skip_button: Button = null
var _arrow_line: Line2D = null
var _arrow_head: Polygon2D = null
var _target_ring: Line2D = null
var _dim_rects: Array = []
var _body_tween: Tween = null

var _active: bool = false
var _current_step: String = STEP_0_INTRO
var _local_owner_id: int = 1
var _last_state: GameState = null
var _baseline_owned_hives: int = 0
var _starting_hive_id: int = -1
var _first_target_hive_id: int = -1
var _swarm_target_hive_id: int = -1
var _swarm_finish_launched: bool = false
var _signal_bound: bool = false
var _auto_hide_generation: int = 0
var _pause_sim_cb: Callable = Callable()
var _resume_sim_cb: Callable = Callable()
var _hive_screen_pos_cb: Callable = Callable()
var _buff_screen_pos_cb: Callable = Callable()
var _buff_snapshot_cb: Callable = Callable()

func ensure_overlay(resolve_hud_root_cb: Callable, force_fullscreen_anchors_cb: Callable) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	if not resolve_hud_root_cb.is_valid():
		return
	var hud_root: Control = resolve_hud_root_cb.call() as Control
	if hud_root == null:
		return
	var overlay: Control = hud_root.get_node_or_null("TutorialSection1Overlay") as Control
	if overlay == null:
		overlay = _build_overlay()
		hud_root.add_child(overlay)
	elif overlay.get_parent() != hud_root:
		overlay.reparent(hud_root)
	if force_fullscreen_anchors_cb.is_valid():
		force_fullscreen_anchors_cb.call(overlay)
	overlay.z_as_relative = false
	overlay.z_index = 2060
	overlay.top_level = false
	_overlay = overlay
	_title_label = overlay.get_node_or_null("Panel/VBox/Title") as Label
	_body_label = overlay.get_node_or_null("Panel/VBox/Body") as Label
	_status_label = overlay.get_node_or_null("Panel/VBox/Status") as Label
	_continue_button = overlay.get_node_or_null("Panel/VBox/Buttons/ContinueButton") as Button
	_skip_button = overlay.get_node_or_null("Panel/VBox/Buttons/SkipButton") as Button
	_arrow_line = overlay.get_node_or_null("ArrowLine") as Line2D
	_arrow_head = overlay.get_node_or_null("ArrowHead") as Polygon2D
	_target_ring = overlay.get_node_or_null("TargetRing") as Line2D
	_dim_rects = [
		overlay.get_node_or_null("DimTop"),
		overlay.get_node_or_null("DimBottom"),
		overlay.get_node_or_null("DimLeft"),
		overlay.get_node_or_null("DimRight")
	]
	if _continue_button != null and not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	if _skip_button != null and not _skip_button.pressed.is_connected(_on_skip_pressed):
		_skip_button.pressed.connect(_on_skip_pressed)
	_style_overlay_nodes()

func start_if_needed(resolve_hud_root_cb: Callable, force_fullscreen_anchors_cb: Callable, local_owner_id: int, state: GameState, pause_sim_cb: Callable = Callable(), resume_sim_cb: Callable = Callable(), hive_screen_pos_cb: Callable = Callable(), buff_screen_pos_cb: Callable = Callable(), buff_snapshot_cb: Callable = Callable()) -> bool:
	var profile_manager: Object = _get_profile_manager()
	if profile_manager == null:
		hide(true)
		return false
	if profile_manager.has_method("is_onboarding_complete") and not bool(profile_manager.call("is_onboarding_complete")):
		hide(true)
		return false
	var status: String = STATUS_NOT_STARTED
	if profile_manager.has_method("get_tutorial_section1_status"):
		status = str(profile_manager.call("get_tutorial_section1_status"))
	status = _sanitize_status(status)
	if status == STATUS_COMPLETED or status == STATUS_SKIPPED:
		hide(true)
		return false
	ensure_overlay(resolve_hud_root_cb, force_fullscreen_anchors_cb)
	if _overlay == null:
		return false
	if status == STATUS_NOT_STARTED and profile_manager.has_method("begin_tutorial_section1"):
		profile_manager.call("begin_tutorial_section1")
	var persisted_step: String = STEP_0_INTRO
	if profile_manager.has_method("get_tutorial_section1_step"):
		persisted_step = str(profile_manager.call("get_tutorial_section1_step"))
	_current_step = _sanitize_step(persisted_step)
	if _current_step == STEP_COMPLETED or _current_step == STEP_SKIPPED:
		_current_step = STEP_0_INTRO
		_persist_step(_current_step)
	_local_owner_id = clampi(local_owner_id, 1, 4)
	_last_state = state
	_baseline_owned_hives = _count_owned_hives(state, _local_owner_id)
	_starting_hive_id = _selected_local_hive_id(state, _local_owner_id)
	_first_target_hive_id = -1
	_swarm_target_hive_id = -1
	_swarm_finish_launched = false
	_pause_sim_cb = pause_sim_cb
	_resume_sim_cb = resume_sim_cb
	_hive_screen_pos_cb = hive_screen_pos_cb
	_buff_screen_pos_cb = buff_screen_pos_cb
	_buff_snapshot_cb = buff_snapshot_cb
	_active = true
	_bind_signal_once()
	_refresh_overlay_copy()
	if _is_match_running():
		_show_overlay()
		_refresh_arrow()
	return true

func is_active() -> bool:
	return _active

func apply_reading_pause() -> void:
	if not _active:
		return
	if _overlay == null or not is_instance_valid(_overlay):
		return
	if not _is_match_running():
		return
	if not _overlay.visible:
		_show_overlay()
		_refresh_overlay_copy()
	_refresh_arrow()
	_pause_for_message()

func on_hive_clicked(hive_id: int, state: GameState, local_owner_id: int) -> void:
	if not _active:
		return
	if _current_step != STEP_0_INTRO:
		return
	if state == null or hive_id <= 0:
		return
	_local_owner_id = clampi(local_owner_id, 1, 4)
	_last_state = state
	var hive: HiveData = state.find_hive_by_id(hive_id)
	if hive == null or int(hive.owner_id) != _local_owner_id:
		return
	_starting_hive_id = hive_id
	_advance_to_step(STEP_1_ATTACK_LANE)

func hide(mark_inactive: bool = true) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false
	_hide_arrow()
	_resume_after_message()
	if mark_inactive:
		_active = false
		_unbind_signal()

func on_match_ended() -> void:
	if _active and _swarm_finish_launched:
		_complete_section()
	hide(true)

func tick(state: GameState, local_owner_id: int) -> void:
	if not _active:
		return
	if state == null:
		return
	_local_owner_id = clampi(local_owner_id, 1, 4)
	_last_state = state
	_refresh_arrow()
	if _current_step == STEP_0_INTRO:
		var selected_id: int = _selected_local_hive_id(state, _local_owner_id)
		if selected_id <= 0:
			return
		_starting_hive_id = selected_id
		_advance_to_step(STEP_1_ATTACK_LANE)
		return
	if _current_step == STEP_2_RETRACT_LANE:
		if _has_enemy_hive_pressure_trigger(state):
			_advance_to_step(STEP_3_CAPTURE_HIVE)
			return
	if _current_step == STEP_3_CAPTURE_HIVE:
		var low_enemy_id: int = _last_enemy_hive_low_power_id(state)
		if low_enemy_id > 0:
			_swarm_target_hive_id = low_enemy_id
			_advance_to_step(STEP_4_BUFF)
			return
	if _current_step == STEP_4_BUFF:
		if _has_local_buff_used():
			_advance_to_step(STEP_4_SWARM_FINISH)
			return
	if _current_step == STEP_4_SWARM_FINISH:
		if _has_local_swarm_request_for_target(state):
			_swarm_finish_launched = true
			hide(false)

func _on_lane_intent_changed(_iid: int, lane_id: int) -> void:
	if not _active:
		return
	var ops_state: Node = _get_ops_state()
	if ops_state == null or not ops_state.has_method("get_state"):
		return
	var state: GameState = ops_state.call("get_state") as GameState
	if state == null:
		return
	_last_state = state
	if _current_step == STEP_1_ATTACK_LANE:
		var src_dst: Dictionary = _resolve_local_attack_lane(state, lane_id)
		if src_dst.is_empty():
			return
		_starting_hive_id = int(src_dst.get("src", _starting_hive_id))
		_first_target_hive_id = int(src_dst.get("dst", -1))
		if _starting_hive_id <= 0 or _first_target_hive_id <= 0:
			return
		_advance_to_step(STEP_2_RETRACT_LANE)
		return
	if _current_step == STEP_2_RETRACT_LANE:
		if _has_enemy_hive_pressure_trigger(state):
			_advance_to_step(STEP_3_CAPTURE_HIVE)
			return
	if _current_step == STEP_4_SWARM_FINISH:
		if _has_local_swarm_request_for_target(state):
			_swarm_finish_launched = true
			hide(false)

func _advance_to_step(step_name: String) -> void:
	_current_step = _sanitize_step(step_name)
	_persist_step(_current_step)
	_show_overlay()
	_refresh_overlay_copy()
	_refresh_arrow()

func _resolve_local_attack_lane(state: GameState, lane_id: int) -> Dictionary:
	if state == null or lane_id <= 0:
		return {}
	var lane_any: Variant = state.find_lane_by_id(lane_id)
	if lane_any == null:
		return {}
	var a_id: int = -1
	var b_id: int = -1
	var send_a: bool = false
	var send_b: bool = false
	if lane_any is LaneData:
		var lane: LaneData = lane_any as LaneData
		a_id = int(lane.a_id)
		b_id = int(lane.b_id)
		send_a = bool(lane.send_a)
		send_b = bool(lane.send_b)
	elif typeof(lane_any) == TYPE_DICTIONARY:
		var lane_dict: Dictionary = lane_any as Dictionary
		a_id = int(lane_dict.get("a_id", -1))
		b_id = int(lane_dict.get("b_id", -1))
		send_a = bool(lane_dict.get("send_a", false))
		send_b = bool(lane_dict.get("send_b", false))
	else:
		return {}
	var a_hive: HiveData = state.find_hive_by_id(a_id)
	var b_hive: HiveData = state.find_hive_by_id(b_id)
	if a_hive == null or b_hive == null:
		return {}
	var a_owner: int = int(a_hive.owner_id)
	var b_owner: int = int(b_hive.owner_id)
	if send_a and a_owner == _local_owner_id and not _are_allies(a_owner, b_owner) and state.intent_is_on(a_id, b_id):
		return {"src": a_id, "dst": b_id}
	if send_b and b_owner == _local_owner_id and not _are_allies(b_owner, a_owner) and state.intent_is_on(b_id, a_id):
		return {"src": b_id, "dst": a_id}
	return {}

func _selected_local_hive_id(state: GameState, owner_id: int) -> int:
	if state == null or state.selection == null:
		return -1
	var selected_id: int = int(state.selection.selected_hive_id)
	if selected_id <= 0:
		return -1
	var hive: HiveData = state.find_hive_by_id(selected_id)
	if hive == null or int(hive.owner_id) != owner_id:
		return -1
	return selected_id

func _has_enemy_hive_pressure_trigger(state: GameState) -> bool:
	if state == null:
		return false
	if _has_active_local_attack_on_enemy(state):
		return true
	return _owns_hive_adjacent_to_enemy(state)

func _has_active_local_attack_on_enemy(state: GameState) -> bool:
	for lane_any in state.lanes:
		if lane_any == null:
			continue
		var lane_id: int = -1
		if lane_any is LaneData:
			lane_id = int((lane_any as LaneData).id)
		elif typeof(lane_any) == TYPE_DICTIONARY:
			lane_id = int((lane_any as Dictionary).get("id", -1))
		var src_dst: Dictionary = _resolve_local_attack_lane(state, lane_id)
		if src_dst.is_empty():
			continue
		var dst_hive: HiveData = state.find_hive_by_id(int(src_dst.get("dst", -1)))
		if dst_hive != null and int(dst_hive.owner_id) > 0 and not _are_allies(_local_owner_id, int(dst_hive.owner_id)):
			return true
	return false

func _owns_hive_adjacent_to_enemy(state: GameState) -> bool:
	for lane_any in state.lanes:
		if lane_any == null:
			continue
		var a_id: int = -1
		var b_id: int = -1
		if lane_any is LaneData:
			var lane: LaneData = lane_any as LaneData
			a_id = int(lane.a_id)
			b_id = int(lane.b_id)
		elif typeof(lane_any) == TYPE_DICTIONARY:
			var lane_dict: Dictionary = lane_any as Dictionary
			a_id = int(lane_dict.get("a_id", -1))
			b_id = int(lane_dict.get("b_id", -1))
		if a_id <= 0 or b_id <= 0:
			continue
		var a_hive: HiveData = state.find_hive_by_id(a_id)
		var b_hive: HiveData = state.find_hive_by_id(b_id)
		if a_hive == null or b_hive == null:
			continue
		var a_owner: int = int(a_hive.owner_id)
		var b_owner: int = int(b_hive.owner_id)
		if a_owner == _local_owner_id and b_owner > 0 and not _are_allies(a_owner, b_owner):
			return true
		if b_owner == _local_owner_id and a_owner > 0 and not _are_allies(b_owner, a_owner):
			return true
	return false

func _last_enemy_hive_low_power_id(state: GameState) -> int:
	if state == null:
		return -1
	var enemy_hives: Array[HiveData] = []
	for hive in state.hives:
		if hive == null:
			continue
		var owner_id: int = int(hive.owner_id)
		if owner_id <= 0:
			continue
		if _are_allies(_local_owner_id, owner_id):
			continue
		enemy_hives.append(hive)
	if enemy_hives.size() != 1:
		return -1
	var last_enemy: HiveData = enemy_hives[0]
	if int(last_enemy.power) > SWARM_INTRO_ENEMY_POWER_MAX:
		return -1
	if not _has_finishing_swarm_source_for_target(state, int(last_enemy.id), int(last_enemy.power)):
		return -1
	return int(last_enemy.id)

func _has_finishing_swarm_source_for_target(state: GameState, target_id: int, target_power: int) -> bool:
	if state == null or target_id <= 0:
		return false
	for lane_any in state.lanes:
		if lane_any == null:
			continue
		var lane_id: int = -1
		if lane_any is LaneData:
			lane_id = int((lane_any as LaneData).id)
		elif typeof(lane_any) == TYPE_DICTIONARY:
			lane_id = int((lane_any as Dictionary).get("id", -1))
		var src_dst: Dictionary = _resolve_local_attack_lane(state, lane_id)
		if src_dst.is_empty():
			continue
		if int(src_dst.get("dst", -1)) != target_id:
			continue
		var src_hive: HiveData = state.find_hive_by_id(int(src_dst.get("src", -1)))
		if src_hive == null:
			continue
		var swarm_start_count: int = clampi(int(src_hive.power) - 1, 1, 5)
		if swarm_start_count >= target_power:
			return true
	return false

func _has_local_swarm_request_for_target(state: GameState) -> bool:
	if state == null:
		return false
	var target_id: int = _swarm_target_hive_id
	if target_id <= 0:
		target_id = _last_enemy_hive_low_power_id(state)
	if target_id <= 0:
		return false
	for req_any in state.swarm_requests:
		if typeof(req_any) != TYPE_DICTIONARY:
			continue
		var req: Dictionary = req_any as Dictionary
		var src_id: int = int(req.get("src", -1))
		var dst_id: int = int(req.get("dst", -1))
		if dst_id != target_id:
			continue
		var src_hive: HiveData = state.find_hive_by_id(src_id)
		var dst_hive: HiveData = state.find_hive_by_id(dst_id)
		if src_hive == null or dst_hive == null:
			continue
		if int(src_hive.owner_id) == _local_owner_id and int(dst_hive.owner_id) > 0 and not _are_allies(_local_owner_id, int(dst_hive.owner_id)):
			return true
	for packet_any in state.swarm_packets:
		if typeof(packet_any) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = packet_any as Dictionary
		if int(packet.get("to_id", -1)) == target_id and int(packet.get("owner_id", -1)) == _local_owner_id:
			return true
	return false

func _has_local_buff_used() -> bool:
	if not _buff_snapshot_cb.is_valid():
		return false
	var snapshot_v: Variant = _buff_snapshot_cb.call()
	if typeof(snapshot_v) != TYPE_DICTIONARY:
		return false
	var snapshot: Dictionary = snapshot_v as Dictionary
	if not bool(snapshot.get("buffs_enabled", false)):
		return false
	var players_v: Variant = snapshot.get("players", {})
	if typeof(players_v) != TYPE_DICTIONARY:
		return false
	var players: Dictionary = players_v as Dictionary
	var player_v: Variant = players.get(_local_owner_id, {})
	if typeof(player_v) != TYPE_DICTIONARY:
		player_v = players.get(str(_local_owner_id), {})
	if typeof(player_v) != TYPE_DICTIONARY:
		return false
	var player_data: Dictionary = player_v as Dictionary
	var slots_v: Variant = player_data.get("slots", [])
	if typeof(slots_v) != TYPE_ARRAY:
		return false
	for slot_any in slots_v as Array:
		if typeof(slot_any) != TYPE_DICTIONARY:
			continue
		var slot: Dictionary = slot_any as Dictionary
		if bool(slot.get("active", false)) or bool(slot.get("consumed", false)):
			return true
	return false

func _count_owned_hives(state: GameState, owner_id: int) -> int:
	if state == null or owner_id <= 0:
		return 0
	var owned: int = 0
	for hive in state.hives:
		if hive == null:
			continue
		if int(hive.owner_id) == owner_id:
			owned += 1
	return owned

func _persist_step(step_name: String) -> void:
	var profile_manager: Object = _get_profile_manager()
	if profile_manager == null:
		return
	if profile_manager.has_method("set_tutorial_section1_step"):
		profile_manager.call("set_tutorial_section1_step", step_name)

func _complete_section() -> void:
	var profile_manager: Object = _get_profile_manager()
	if profile_manager != null and profile_manager.has_method("mark_tutorial_section1_completed"):
		profile_manager.call("mark_tutorial_section1_completed")
	_current_step = STEP_COMPLETED
	hide(true)

func _on_continue_pressed() -> void:
	if not _active:
		return
	if _current_step != STEP_0_INTRO:
		return
	_current_step = STEP_1_ATTACK_LANE
	_persist_step(_current_step)
	_refresh_overlay_copy()

func _on_skip_pressed() -> void:
	if not _active:
		return
	var profile_manager: Object = _get_profile_manager()
	if profile_manager != null and profile_manager.has_method("mark_tutorial_section1_skipped"):
		profile_manager.call("mark_tutorial_section1_skipped")
	_current_step = STEP_SKIPPED
	hide(true)

func _show_overlay() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	_overlay.visible = true
	_pause_for_message()
	var parent_node: Node = _overlay.get_parent()
	if parent_node != null:
		parent_node.move_child(_overlay, parent_node.get_child_count() - 1)
	if _current_step == STEP_0_INTRO and _continue_button != null and _continue_button.visible:
		_continue_button.grab_focus()

func _refresh_overlay_copy() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	if _title_label != null:
		_title_label.text = "Tutorial: Section 1 (Basics)"
	if _status_label != null:
		_status_label.text = _status_text_for_step(_current_step)
	if _body_label != null:
		var duration: float = _set_body_text_typewriter(_body_text_for_step(_current_step))
		if _current_step == STEP_1_ATTACK_LANE or _current_step == STEP_2_RETRACT_LANE or _current_step == STEP_3_CAPTURE_HIVE:
			_queue_overlay_auto_hide(duration + OBJECTIVE_AUTO_HIDE_READ_SEC)
	if _continue_button != null:
		_continue_button.visible = false
		_continue_button.disabled = true
	if _skip_button != null:
		_skip_button.visible = _current_step != STEP_0_INTRO and _current_step != STEP_COMPLETED and _current_step != STEP_SKIPPED and _current_step != STEP_4_SWARM_FINISH
		_skip_button.disabled = _current_step == STEP_4_SWARM_FINISH
	_refresh_arrow()

func _status_text_for_step(step_name: String) -> String:
	match step_name:
		STEP_0_INTRO:
			return "Objective 1/5: Select Your Hive"
		STEP_1_ATTACK_LANE:
			return "Objective 2/5: Attack The NPC Hive"
		STEP_2_RETRACT_LANE:
			return "Objective 3/5: Flip The Hive"
		STEP_3_CAPTURE_HIVE:
			return "Objective 4/5: Break The Standoff"
		STEP_4_BUFF:
			return "Objective 4.5/5: Use A Buff"
		STEP_4_SWARM_FINISH:
			return "Objective 5/5: Use Swarm"
		_:
			return ""

func _body_text_for_step(step_name: String) -> String:
	match step_name:
		STEP_0_INTRO:
			return "Selecting your hive is pretty simple. Tap it. It should glow or have a selector ring around it."
		STEP_1_ATTACK_LANE:
			return "OK, great work. Now it's time to attack.\n\nWith your hive selected, tap the NPC hive right below."
		STEP_2_RETRACT_LANE:
			return "OK great, you are now attacking that NPC hive and will quickly flip it to your side.\n\nOnce you do, you will be able to attack enemies from it, and feed friendly hives.\n\nHives with 9 power or less get one lane. Hives with 10-24 power get two lanes. Hives with 25 power or more get three lanes."
		STEP_3_CAPTURE_HIVE:
			return "OK, you can see that the NPC hive is now yours. Attack as you see fit.\n\nWhen you attack the opponent, they will counterattack and send units your way. Oncoming units cancel each other out.\n\nThat standoff can last indefinitely until you attack from a second hive, grow your hive power so it creates units faster, or both."
		STEP_4_BUFF:
			return "OK, next, you'll want to know how to gain an edge using your buffs.\n\nSee that glowing buff at the bottom of your screen? Tap and drag that buff anywhere on the screen.\n\nIf it's a buff that affects a single hive or lane, drop it on the lane or hive you want to get the advantage. Otherwise, anywhere on the screen is fine."
		STEP_4_SWARM_FINISH:
			return "OK, now there is one more thing you need to know.\n\nIf you want to bypass the units defending a hive, you can, by initiating a swarm.\n\nDouble-tap the lane your hive is using to attack the enemy. See? Slides right by oncoming units, but be careful, because there is a cost to that power."
		_:
			return ""

func _sanitize_status(status: String) -> String:
	var cleaned: String = status.strip_edges().to_lower()
	if cleaned == STATUS_IN_PROGRESS:
		return STATUS_IN_PROGRESS
	if cleaned == STATUS_COMPLETED:
		return STATUS_COMPLETED
	if cleaned == STATUS_SKIPPED:
		return STATUS_SKIPPED
	return STATUS_NOT_STARTED

func _sanitize_step(step_name: String) -> String:
	var cleaned: String = step_name.strip_edges().to_lower()
	if cleaned == STEP_1_ATTACK_LANE:
		return STEP_1_ATTACK_LANE
	if cleaned == STEP_2_RETRACT_LANE:
		return STEP_2_RETRACT_LANE
	if cleaned == STEP_3_CAPTURE_HIVE:
		return STEP_3_CAPTURE_HIVE
	if cleaned == STEP_4_BUFF:
		return STEP_4_BUFF
	if cleaned == STEP_4_SWARM_FINISH:
		return STEP_4_SWARM_FINISH
	if cleaned == STEP_COMPLETED:
		return STEP_COMPLETED
	if cleaned == STEP_SKIPPED:
		return STEP_SKIPPED
	return STEP_0_INTRO

func _bind_signal_once() -> void:
	if _signal_bound:
		return
	var ops_state: Node = _get_ops_state()
	if ops_state == null:
		return
	var cb := Callable(self, "_on_lane_intent_changed")
	if not ops_state.is_connected("lane_intent_changed", cb):
		ops_state.connect("lane_intent_changed", cb)
	_signal_bound = true

func _unbind_signal() -> void:
	if not _signal_bound:
		return
	var ops_state: Node = _get_ops_state()
	var cb := Callable(self, "_on_lane_intent_changed")
	if ops_state != null and ops_state.is_connected("lane_intent_changed", cb):
		ops_state.disconnect("lane_intent_changed", cb)
	_signal_bound = false

func _are_allies(owner_a: int, owner_b: int) -> bool:
	if owner_a <= 0 or owner_b <= 0:
		return false
	var ops_state: Node = _get_ops_state()
	if ops_state != null and ops_state.has_method("are_allies"):
		return bool(ops_state.call("are_allies", owner_a, owner_b))
	return owner_a == owner_b

func _build_overlay() -> Control:
	var overlay: Control = Control.new()
	overlay.name = "TutorialSection1Overlay"
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.layout_mode = 3
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.grow_horizontal = 2
	overlay.grow_vertical = 2

	var panel: Panel = Panel.new()
	panel.name = "Panel"
	panel.z_index = 20
	panel.anchor_left = 0.5
	panel.anchor_top = 0.08
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.08
	panel.offset_left = -420.0
	panel.offset_top = 0.0
	panel.offset_right = 420.0
	panel.offset_bottom = 390.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(panel)

	_dim_rects.clear()
	for dim_name in ["DimTop", "DimBottom", "DimLeft", "DimRight"]:
		var dim_rect: ColorRect = ColorRect.new()
		dim_rect.name = dim_name
		dim_rect.visible = false
		dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim_rect.color = Color(0.0, 0.0, 0.0, 0.58)
		dim_rect.z_index = 2
		overlay.add_child(dim_rect)
		_dim_rects.append(dim_rect)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 16.0
	vbox.offset_top = 16.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -16.0
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Tutorial: Section 1 (Basics)"
	vbox.add_child(title)

	var status_label: Label = Label.new()
	status_label.name = "Status"
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.modulate = Color(1.0, 0.86, 0.52, 1.0)
	vbox.add_child(status_label)

	var body: Label = Label.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.text = ""
	vbox.add_child(body)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	var continue_button: Button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(170, 64)
	buttons.add_child(continue_button)

	var skip_button: Button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "Skip"
	skip_button.custom_minimum_size = Vector2(130, 64)
	buttons.add_child(skip_button)

	var arrow_line: Line2D = Line2D.new()
	arrow_line.name = "ArrowLine"
	arrow_line.visible = false
	arrow_line.width = 8.0
	arrow_line.default_color = Color(1.0, 0.78, 0.12, 0.95)
	arrow_line.z_index = 8
	overlay.add_child(arrow_line)

	var arrow_head: Polygon2D = Polygon2D.new()
	arrow_head.name = "ArrowHead"
	arrow_head.visible = false
	arrow_head.color = Color(1.0, 0.78, 0.12, 0.95)
	arrow_head.z_index = 9
	overlay.add_child(arrow_head)

	var target_ring: Line2D = Line2D.new()
	target_ring.name = "TargetRing"
	target_ring.visible = false
	target_ring.closed = true
	target_ring.width = 5.0
	target_ring.default_color = Color(1.0, 0.9, 0.16, 0.98)
	target_ring.z_index = 10
	overlay.add_child(target_ring)

	return overlay

func _style_overlay_nodes() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var panel: Panel = _overlay.get_node_or_null("Panel") as Panel
	if panel != null:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.025, 0.03, 0.34)
		style.border_color = Color(1.0, 0.78, 0.22, 0.98)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		panel.add_theme_stylebox_override("panel", style)
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", 34)
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72, 1.0))
		_title_label.add_theme_constant_override("outline_size", 3)
		_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	if _status_label != null:
		_status_label.add_theme_font_size_override("font_size", 26)
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.22, 1.0))
		_status_label.add_theme_constant_override("outline_size", 2)
		_status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	if _body_label != null:
		_body_label.add_theme_font_size_override("font_size", 32)
		_body_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		_body_label.add_theme_constant_override("outline_size", 3)
		_body_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	for button in [_continue_button, _skip_button]:
		if button == null:
			continue
		button.add_theme_font_size_override("font_size", 26)

func _set_body_text_typewriter(text: String) -> float:
	if _body_label == null:
		return 0.0
	if _body_tween != null and _body_tween.is_valid():
		_body_tween.kill()
	_body_label.text = text
	_body_label.visible_characters = 0
	var tree := _scene_tree()
	if tree == null:
		_body_label.visible_characters = -1
		return 0.0
	var char_count: int = maxi(1, text.length())
	var chars_per_second: float = (TYPEWRITER_WORDS_PER_MINUTE * TYPEWRITER_CHARS_PER_WORD) / 60.0
	var duration: float = maxf(float(char_count) / chars_per_second, TYPEWRITER_MIN_DURATION_SEC)
	_body_tween = tree.create_tween()
	_body_tween.bind_node(_body_label)
	_body_tween.tween_property(_body_label, "visible_characters", char_count, duration)
	return duration

func _queue_overlay_auto_hide(delay_sec: float) -> void:
	var tree := _scene_tree()
	if tree == null:
		return
	_auto_hide_generation += 1
	var generation: int = _auto_hide_generation
	var timer: SceneTreeTimer = tree.create_timer(maxf(0.1, delay_sec))
	timer.timeout.connect(Callable(self, "_on_auto_hide_timeout").bind(generation))

func _on_auto_hide_timeout(generation: int) -> void:
	if generation != _auto_hide_generation:
		return
	if _current_step != STEP_1_ATTACK_LANE and _current_step != STEP_2_RETRACT_LANE and _current_step != STEP_3_CAPTURE_HIVE:
		return
	hide(false)

func _pause_for_message() -> void:
	if _pause_sim_cb.is_valid():
		_pause_sim_cb.call()

func _resume_after_message() -> void:
	if _resume_sim_cb.is_valid():
		_resume_sim_cb.call()

func _refresh_arrow() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	if not _overlay.visible:
		_hide_arrow()
		return
	if _arrow_line == null or _arrow_head == null:
		return
	var target_v: Variant = _arrow_target_screen_pos()
	if not (target_v is Vector2):
		_hide_arrow()
		return
	var target: Vector2 = target_v as Vector2
	if target.x < -1000.0 or target.y < -1000.0:
		_hide_arrow()
		return
	var viewport_size: Vector2 = _overlay.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		var tree := _scene_tree()
		if tree != null and tree.root != null:
			viewport_size = tree.root.get_visible_rect().size
	var offset: Vector2 = Vector2(170.0, -130.0)
	if target.x > viewport_size.x * 0.5:
		offset.x = -170.0
	if target.y < viewport_size.y * 0.25:
		offset.y = 150.0
	var start: Vector2 = target + offset
	start.x = clampf(start.x, 40.0, maxf(40.0, viewport_size.x - 40.0))
	start.y = clampf(start.y, 40.0, maxf(40.0, viewport_size.y - 40.0))
	_arrow_line.visible = true
	_arrow_line.points = PackedVector2Array([start, target])
	_update_arrow_head(start, target)
	if _target_ring != null:
		var pulse: float = 0.5 + (0.5 * sin(float(Time.get_ticks_msec()) / 180.0))
		_target_ring.visible = true
		_target_ring.width = 5.0 + pulse * 3.0
		_target_ring.default_color = Color(1.0, 0.9, 0.16, 0.72 + pulse * 0.26)
		_target_ring.points = _ring_points(target, 42.0 + pulse * 4.0)
	_update_dim_to_target(target, viewport_size, 62.0)

func _hide_arrow() -> void:
	if _arrow_line != null:
		_arrow_line.visible = false
	if _arrow_head != null:
		_arrow_head.visible = false
	if _target_ring != null:
		_target_ring.visible = false
	_hide_dim()

func _update_dim_to_target(target: Vector2, viewport_size: Vector2, radius: float) -> void:
	if _dim_rects.is_empty():
		return
	var left: float = clampf(target.x - radius, 0.0, viewport_size.x)
	var right: float = clampf(target.x + radius, 0.0, viewport_size.x)
	var top: float = clampf(target.y - radius, 0.0, viewport_size.y)
	var bottom: float = clampf(target.y + radius, 0.0, viewport_size.y)
	_set_dim_rect(0, Rect2(Vector2.ZERO, Vector2(viewport_size.x, top)))
	_set_dim_rect(1, Rect2(Vector2(0.0, bottom), Vector2(viewport_size.x, maxf(0.0, viewport_size.y - bottom))))
	_set_dim_rect(2, Rect2(Vector2(0.0, top), Vector2(left, maxf(0.0, bottom - top))))
	_set_dim_rect(3, Rect2(Vector2(right, top), Vector2(maxf(0.0, viewport_size.x - right), maxf(0.0, bottom - top))))

func _set_dim_rect(index: int, rect: Rect2) -> void:
	if index < 0 or index >= _dim_rects.size():
		return
	var dim_rect: ColorRect = _dim_rects[index] as ColorRect
	if dim_rect == null:
		return
	dim_rect.visible = rect.size.x > 0.0 and rect.size.y > 0.0
	dim_rect.position = rect.position
	dim_rect.size = rect.size

func _hide_dim() -> void:
	for rect_any in _dim_rects:
		var dim_rect: ColorRect = rect_any as ColorRect
		if dim_rect != null:
			dim_rect.visible = false

func _arrow_target_hive_id() -> int:
	if _current_step == STEP_0_INTRO:
		return _first_local_hive_id(_last_state)
	if _current_step == STEP_1_ATTACK_LANE:
		var source_id: int = _starting_hive_id
		if source_id <= 0:
			source_id = _selected_local_hive_id(_last_state, _local_owner_id)
		return _first_attack_target_hive_id(_last_state, source_id)
	if _current_step == STEP_4_SWARM_FINISH:
		if _swarm_target_hive_id > 0:
			return _swarm_target_hive_id
		return _last_enemy_hive_low_power_id(_last_state)
	return -1

func _arrow_target_screen_pos() -> Variant:
	if _current_step == STEP_4_BUFF:
		if not _buff_screen_pos_cb.is_valid():
			return null
		return _buff_screen_pos_cb.call()
	var target_hive_id: int = _arrow_target_hive_id()
	if target_hive_id <= 0 or not _hive_screen_pos_cb.is_valid():
		return null
	return _hive_screen_pos_cb.call(target_hive_id)

func _first_attack_target_hive_id(state: GameState, source_id: int) -> int:
	if state == null or source_id <= 0:
		return -1
	var source_hive: HiveData = state.find_hive_by_id(source_id)
	if source_hive == null:
		return -1
	var best_id: int = -1
	var best_score: float = INF
	var source_pos: Vector2 = source_hive.render_grid_pos
	for lane_any in state.lanes:
		if lane_any == null:
			continue
		var other_id: int = -1
		if lane_any is LaneData:
			var lane: LaneData = lane_any as LaneData
			if int(lane.a_id) == source_id:
				other_id = int(lane.b_id)
			elif int(lane.b_id) == source_id:
				other_id = int(lane.a_id)
		elif typeof(lane_any) == TYPE_DICTIONARY:
			var lane_dict: Dictionary = lane_any as Dictionary
			if int(lane_dict.get("a_id", -1)) == source_id:
				other_id = int(lane_dict.get("b_id", -1))
			elif int(lane_dict.get("b_id", -1)) == source_id:
				other_id = int(lane_dict.get("a_id", -1))
		if other_id <= 0:
			continue
		var hive: HiveData = state.find_hive_by_id(other_id)
		if hive == null:
			continue
		var owner_id: int = int(hive.owner_id)
		if owner_id > 0 and _are_allies(_local_owner_id, owner_id):
			continue
		var hive_pos: Vector2 = hive.render_grid_pos
		var below_bonus: float = -1000.0 if hive_pos.y > source_pos.y else 0.0
		var neutral_bonus: float = -100.0 if owner_id <= 0 else 0.0
		var score: float = below_bonus + neutral_bonus + source_pos.distance_squared_to(hive_pos)
		if score < best_score:
			best_score = score
			best_id = other_id
	return best_id

func _first_local_hive_id(state: GameState) -> int:
	if state == null:
		return -1
	for hive in state.hives:
		if hive == null:
			continue
		if int(hive.owner_id) == _local_owner_id:
			return int(hive.id)
	return -1

func _update_arrow_head(start: Vector2, target: Vector2) -> void:
	if _arrow_head == null:
		return
	var dir: Vector2 = target - start
	if dir.length_squared() <= 0.001:
		_arrow_head.visible = false
		return
	dir = dir.normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = target
	var base: Vector2 = target - dir * 28.0
	_arrow_head.polygon = PackedVector2Array([
		tip,
		base + perp * 16.0,
		base - perp * 16.0
	])
	_arrow_head.visible = true

func _ring_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(32):
		var theta: float = (TAU * float(i)) / 32.0
		points.append(center + Vector2(cos(theta), sin(theta)) * radius)
	return points

func _is_match_running() -> bool:
	var ops_state: Node = _get_ops_state()
	if ops_state == null:
		return true
	return int(ops_state.get("match_phase")) == 1 and not bool(ops_state.get("input_locked"))

func _scene_tree() -> SceneTree:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null

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
