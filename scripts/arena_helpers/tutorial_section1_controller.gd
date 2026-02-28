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
const STEP_COMPLETED: String = "completed"
const STEP_SKIPPED: String = "skipped"

var _overlay: Control = null
var _title_label: Label = null
var _body_label: Label = null
var _status_label: Label = null
var _continue_button: Button = null
var _skip_button: Button = null

var _active: bool = false
var _current_step: String = STEP_0_INTRO
var _local_owner_id: int = 1
var _baseline_owned_hives: int = 0
var _tracked_src_id: int = -1
var _tracked_dst_id: int = -1
var _signal_bound: bool = false

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
	if _continue_button != null and not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	if _skip_button != null and not _skip_button.pressed.is_connected(_on_skip_pressed):
		_skip_button.pressed.connect(_on_skip_pressed)

func start_if_needed(resolve_hud_root_cb: Callable, force_fullscreen_anchors_cb: Callable, local_owner_id: int, state: GameState) -> bool:
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
	if _current_step == STEP_2_RETRACT_LANE:
		# Resume-safe fallback because tracked lane endpoints are session-local.
		_current_step = STEP_1_ATTACK_LANE
		_persist_step(_current_step)
	_local_owner_id = clampi(local_owner_id, 1, 4)
	_baseline_owned_hives = _count_owned_hives(state, _local_owner_id)
	_tracked_src_id = -1
	_tracked_dst_id = -1
	_active = true
	_bind_signal_once()
	_show_overlay()
	_refresh_overlay_copy()
	return true

func is_active() -> bool:
	return _active

func hide(mark_inactive: bool = true) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false
	if mark_inactive:
		_active = false
		_unbind_signal()

func on_match_ended() -> void:
	hide(true)

func tick(state: GameState, local_owner_id: int) -> void:
	if not _active:
		return
	if state == null:
		return
	_local_owner_id = clampi(local_owner_id, 1, 4)
	if _current_step == STEP_3_CAPTURE_HIVE:
		var owned_now: int = _count_owned_hives(state, _local_owner_id)
		if owned_now >= _baseline_owned_hives + 1:
			_complete_section()

func _on_lane_intent_changed(_iid: int, lane_id: int) -> void:
	if not _active:
		return
	var state: GameState = OpsState.get_state()
	if state == null:
		return
	if _current_step == STEP_1_ATTACK_LANE:
		var src_dst: Dictionary = _resolve_local_attack_lane(state, lane_id)
		if src_dst.is_empty():
			return
		_tracked_src_id = int(src_dst.get("src", -1))
		_tracked_dst_id = int(src_dst.get("dst", -1))
		if _tracked_src_id <= 0 or _tracked_dst_id <= 0:
			return
		_current_step = STEP_2_RETRACT_LANE
		_persist_step(_current_step)
		_refresh_overlay_copy()
		return
	if _current_step == STEP_2_RETRACT_LANE:
		if _tracked_src_id <= 0 or _tracked_dst_id <= 0:
			return
		if state.intent_is_on(_tracked_src_id, _tracked_dst_id):
			return
		_current_step = STEP_3_CAPTURE_HIVE
		_baseline_owned_hives = _count_owned_hives(state, _local_owner_id)
		_persist_step(_current_step)
		_refresh_overlay_copy()

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
	var parent_node: Node = _overlay.get_parent()
	if parent_node != null:
		parent_node.move_child(_overlay, parent_node.get_child_count() - 1)
	if _current_step == STEP_0_INTRO and _continue_button != null:
		_continue_button.grab_focus()

func _refresh_overlay_copy() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	if _title_label != null:
		_title_label.text = "Tutorial: Section 1 (Basics)"
	if _status_label != null:
		_status_label.text = _status_text_for_step(_current_step)
	if _body_label != null:
		_body_label.text = _body_text_for_step(_current_step)
	if _continue_button != null:
		_continue_button.visible = _current_step == STEP_0_INTRO
		_continue_button.disabled = _current_step != STEP_0_INTRO
	if _skip_button != null:
		_skip_button.visible = _current_step != STEP_COMPLETED and _current_step != STEP_SKIPPED
		_skip_button.disabled = false

func _status_text_for_step(step_name: String) -> String:
	match step_name:
		STEP_0_INTRO:
			return "Step 0/3: Objective"
		STEP_1_ATTACK_LANE:
			return "Step 1/3: Send Attack Lane"
		STEP_2_RETRACT_LANE:
			return "Step 2/3: Retract Lane"
		STEP_3_CAPTURE_HIVE:
			return "Step 3/3: Capture One Hive"
		_:
			return ""

func _body_text_for_step(step_name: String) -> String:
	match step_name:
		STEP_0_INTRO:
			return "Capture hives to control the map and win.\nSelect your hive, then tap a target.\nPress Continue to begin."
		STEP_1_ATTACK_LANE:
			return "Tap your hive, then tap an enemy or neutral hive to send an attack lane."
		STEP_2_RETRACT_LANE:
			return "Double-tap the source side of that active lane to stop sending."
		STEP_3_CAPTURE_HIVE:
			return "Send units again and capture one hive."
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
	if cleaned == STEP_COMPLETED:
		return STEP_COMPLETED
	if cleaned == STEP_SKIPPED:
		return STEP_SKIPPED
	return STEP_0_INTRO

func _bind_signal_once() -> void:
	if _signal_bound:
		return
	if OpsState == null:
		return
	if not OpsState.lane_intent_changed.is_connected(_on_lane_intent_changed):
		OpsState.lane_intent_changed.connect(_on_lane_intent_changed)
	_signal_bound = true

func _unbind_signal() -> void:
	if not _signal_bound:
		return
	if OpsState != null and OpsState.lane_intent_changed.is_connected(_on_lane_intent_changed):
		OpsState.lane_intent_changed.disconnect(_on_lane_intent_changed)
	_signal_bound = false

func _are_allies(owner_a: int, owner_b: int) -> bool:
	if owner_a <= 0 or owner_b <= 0:
		return false
	if OpsState != null and OpsState.has_method("are_allies"):
		return bool(OpsState.call("are_allies", owner_a, owner_b))
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
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.0
	panel.offset_left = -280.0
	panel.offset_top = 24.0
	panel.offset_right = 280.0
	panel.offset_bottom = 228.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 16.0
	vbox.offset_top = 16.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -16.0
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Tutorial: Section 1 (Basics)"
	vbox.add_child(title)

	var status_label: Label = Label.new()
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.modulate = Color(1.0, 0.86, 0.52, 1.0)
	vbox.add_child(status_label)

	var body: Label = Label.new()
	body.name = "Body"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.text = ""
	vbox.add_child(body)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	var continue_button: Button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "Continue"
	buttons.add_child(continue_button)

	var skip_button: Button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "Skip"
	buttons.add_child(skip_button)

	return overlay

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
