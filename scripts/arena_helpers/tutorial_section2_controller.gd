class_name ArenaTutorialSection2Controller
extends RefCounted

const STATUS_NOT_STARTED: String = "not_started"
const STATUS_IN_PROGRESS: String = "in_progress"
const STATUS_COMPLETED: String = "completed"
const STATUS_SKIPPED: String = "skipped"

const STEP_0_INTRO: String = "step_0_intro"
const STEP_1_DUAL_LANE: String = "step_1_dual_lane"
const STEP_2_RETRACT_LANE: String = "step_2_retract_lane"
const STEP_3_REDIRECT_LANE: String = "step_3_redirect_lane"
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
var _signal_bound: bool = false
var _step1_keys: Dictionary = {}
var _step2_keys: Dictionary = {}
var _retracted_key: String = ""

func ensure_overlay(resolve_hud_root_cb: Callable, force_fullscreen_anchors_cb: Callable) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	if not resolve_hud_root_cb.is_valid():
		return
	var hud_root: Control = resolve_hud_root_cb.call() as Control
	if hud_root == null:
		return
	var overlay: Control = hud_root.get_node_or_null("TutorialSection2Overlay") as Control
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
	if profile_manager.has_method("is_tutorial_section2_unlocked") and not bool(profile_manager.call("is_tutorial_section2_unlocked")):
		hide(true)
		return false
	var status: String = STATUS_NOT_STARTED
	if profile_manager.has_method("get_tutorial_section2_status"):
		status = str(profile_manager.call("get_tutorial_section2_status"))
	status = _sanitize_status(status)
	if status == STATUS_COMPLETED or status == STATUS_SKIPPED:
		hide(true)
		return false
	ensure_overlay(resolve_hud_root_cb, force_fullscreen_anchors_cb)
	if _overlay == null:
		return false
	if status == STATUS_NOT_STARTED and profile_manager.has_method("begin_tutorial_section2"):
		profile_manager.call("begin_tutorial_section2")
	var persisted_step: String = STEP_0_INTRO
	if profile_manager.has_method("get_tutorial_section2_step"):
		persisted_step = str(profile_manager.call("get_tutorial_section2_step"))
	_current_step = _sanitize_step(persisted_step)
	if _current_step == STEP_COMPLETED or _current_step == STEP_SKIPPED:
		_current_step = STEP_0_INTRO
		_persist_step(_current_step)
	if _current_step == STEP_2_RETRACT_LANE or _current_step == STEP_3_REDIRECT_LANE:
		# Resume-safe fallback because tracked lane sets are session-local.
		_current_step = STEP_1_DUAL_LANE
		_persist_step(_current_step)
	_local_owner_id = clampi(local_owner_id, 1, 4)
	_step1_keys.clear()
	_step2_keys.clear()
	_retracted_key = ""
	_active = true
	_bind_signal_once()
	_show_overlay()
	_refresh_overlay_copy()
	_evaluate_current_step(state)
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
	_evaluate_current_step(state)

func _on_lane_intent_changed(_iid: int, _lane_id: int) -> void:
	if not _active:
		return
	var state: GameState = OpsState.get_state()
	if state == null:
		return
	_evaluate_current_step(state)

func _evaluate_current_step(state: GameState) -> void:
	if state == null:
		return
	var keys: Dictionary = _collect_local_attack_keys(state)
	if _current_step == STEP_1_DUAL_LANE:
		if _has_dual_lane_from_same_source(keys):
			_step1_keys = keys.duplicate(true)
			_current_step = STEP_2_RETRACT_LANE
			_persist_step(_current_step)
			_refresh_overlay_copy()
		return
	if _current_step == STEP_2_RETRACT_LANE:
		if _step1_keys.is_empty():
			_step1_keys = keys.duplicate(true)
		var removed_key: String = _first_missing_key(_step1_keys, keys)
		if removed_key == "":
			return
		_retracted_key = removed_key
		_step2_keys = keys.duplicate(true)
		_current_step = STEP_3_REDIRECT_LANE
		_persist_step(_current_step)
		_refresh_overlay_copy()
		return
	if _current_step == STEP_3_REDIRECT_LANE:
		var new_key: String = _first_new_redirect_key(_step2_keys, keys, _retracted_key)
		if new_key == "":
			return
		_complete_section()

func _collect_local_attack_keys(state: GameState) -> Dictionary:
	var out: Dictionary = {}
	if state == null:
		return out
	for lane_any in state.lanes:
		var lane: LaneData = lane_any as LaneData
		if lane == null:
			continue
		var a_hive: HiveData = state.find_hive_by_id(int(lane.a_id))
		var b_hive: HiveData = state.find_hive_by_id(int(lane.b_id))
		if a_hive == null or b_hive == null:
			continue
		var a_owner: int = int(a_hive.owner_id)
		var b_owner: int = int(b_hive.owner_id)
		if bool(lane.send_a) and a_owner == _local_owner_id and not _are_allies(a_owner, b_owner):
			var key_a: String = "%d>%d" % [int(lane.a_id), int(lane.b_id)]
			if state.intent_is_on(int(lane.a_id), int(lane.b_id)):
				out[key_a] = true
		if bool(lane.send_b) and b_owner == _local_owner_id and not _are_allies(b_owner, a_owner):
			var key_b: String = "%d>%d" % [int(lane.b_id), int(lane.a_id)]
			if state.intent_is_on(int(lane.b_id), int(lane.a_id)):
				out[key_b] = true
	return out

func _has_dual_lane_from_same_source(keys: Dictionary) -> bool:
	if keys.is_empty():
		return false
	var counts: Dictionary = {}
	for key_any in keys.keys():
		var key: String = str(key_any)
		var src: int = _src_from_key(key)
		if src <= 0:
			continue
		counts[src] = int(counts.get(src, 0)) + 1
	for src_any in counts.keys():
		if int(counts.get(src_any, 0)) >= 2:
			return true
	return false

func _first_missing_key(before: Dictionary, after: Dictionary) -> String:
	for key_any in before.keys():
		var key: String = str(key_any)
		if not bool(after.get(key, false)):
			return key
	return ""

func _first_new_redirect_key(before: Dictionary, after: Dictionary, blocked_key: String) -> String:
	for key_any in after.keys():
		var key: String = str(key_any)
		if key == blocked_key:
			continue
		if bool(before.get(key, false)):
			continue
		return key
	return ""

func _src_from_key(key: String) -> int:
	var parts: PackedStringArray = key.split(">", false)
	if parts.size() != 2:
		return -1
	return int(parts[0])

func _persist_step(step_name: String) -> void:
	var profile_manager: Object = _get_profile_manager()
	if profile_manager == null:
		return
	if profile_manager.has_method("set_tutorial_section2_step"):
		profile_manager.call("set_tutorial_section2_step", step_name)

func _complete_section() -> void:
	var profile_manager: Object = _get_profile_manager()
	if profile_manager != null and profile_manager.has_method("mark_tutorial_section2_completed"):
		profile_manager.call("mark_tutorial_section2_completed")
	_current_step = STEP_COMPLETED
	hide(true)

func _on_continue_pressed() -> void:
	if not _active:
		return
	if _current_step != STEP_0_INTRO:
		return
	_current_step = STEP_1_DUAL_LANE
	_persist_step(_current_step)
	_refresh_overlay_copy()

func _on_skip_pressed() -> void:
	if not _active:
		return
	var profile_manager: Object = _get_profile_manager()
	if profile_manager != null and profile_manager.has_method("mark_tutorial_section2_skipped"):
		profile_manager.call("mark_tutorial_section2_skipped")
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
		_title_label.text = "Tutorial: Section 2 (Advanced Lane Control)"
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
			return "Step 0/3: Advanced Objective"
		STEP_1_DUAL_LANE:
			return "Step 1/3: Build Dual Pressure"
		STEP_2_RETRACT_LANE:
			return "Step 2/3: Retract One Lane"
		STEP_3_REDIRECT_LANE:
			return "Step 3/3: Redirect Pressure"
		_:
			return ""

func _body_text_for_step(step_name: String) -> String:
	match step_name:
		STEP_0_INTRO:
			return "Now control tempo by managing multiple lanes.\nBuild pressure, retract, then redirect."
		STEP_1_DUAL_LANE:
			return "Create two active attack lanes from the same source hive."
		STEP_2_RETRACT_LANE:
			return "Retract one of those active lanes."
		STEP_3_REDIRECT_LANE:
			return "Create a new attack lane to a different target."
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
	if cleaned == STEP_1_DUAL_LANE:
		return STEP_1_DUAL_LANE
	if cleaned == STEP_2_RETRACT_LANE:
		return STEP_2_RETRACT_LANE
	if cleaned == STEP_3_REDIRECT_LANE:
		return STEP_3_REDIRECT_LANE
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
	overlay.name = "TutorialSection2Overlay"
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
	title.text = "Tutorial: Section 2 (Advanced Lane Control)"
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
