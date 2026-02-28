class_name ArenaTutorialSection3Controller
extends RefCounted

const STATUS_NOT_STARTED: String = "not_started"
const STATUS_IN_PROGRESS: String = "in_progress"
const STATUS_COMPLETED: String = "completed"
const STATUS_SKIPPED: String = "skipped"

const STEP_0_INTRO: String = "step_0_intro"
const STEP_1_SWARM: String = "step_1_swarm"
const STEP_2_TOWER_CONTROL: String = "step_2_tower_control"
const STEP_3_BARRACKS_ROUTE: String = "step_3_barracks_route"
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
var _seen_swarm_ids: Dictionary = {}
var _baseline_local_tower_ids: Dictionary = {}
var _baseline_local_barracks_routes: Dictionary = {}

func ensure_overlay(resolve_hud_root_cb: Callable, force_fullscreen_anchors_cb: Callable) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	if not resolve_hud_root_cb.is_valid():
		return
	var hud_root: Control = resolve_hud_root_cb.call() as Control
	if hud_root == null:
		return
	var overlay: Control = hud_root.get_node_or_null("TutorialSection3Overlay") as Control
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
	if profile_manager.has_method("is_tutorial_section3_unlocked") and not bool(profile_manager.call("is_tutorial_section3_unlocked")):
		hide(true)
		return false
	var status: String = STATUS_NOT_STARTED
	if profile_manager.has_method("get_tutorial_section3_status"):
		status = str(profile_manager.call("get_tutorial_section3_status"))
	status = _sanitize_status(status)
	if status == STATUS_COMPLETED or status == STATUS_SKIPPED:
		hide(true)
		return false
	ensure_overlay(resolve_hud_root_cb, force_fullscreen_anchors_cb)
	if _overlay == null:
		return false
	if status == STATUS_NOT_STARTED and profile_manager.has_method("begin_tutorial_section3"):
		profile_manager.call("begin_tutorial_section3")
	var persisted_step: String = STEP_0_INTRO
	if profile_manager.has_method("get_tutorial_section3_step"):
		persisted_step = str(profile_manager.call("get_tutorial_section3_step"))
	_current_step = _sanitize_step(persisted_step)
	if _current_step == STEP_COMPLETED or _current_step == STEP_SKIPPED:
		_current_step = STEP_0_INTRO
		_persist_step(_current_step)
	_local_owner_id = clampi(local_owner_id, 1, 4)
	_capture_baselines(state)
	_active = true
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

func on_match_ended() -> void:
	hide(true)

func tick(state: GameState, local_owner_id: int) -> void:
	if not _active:
		return
	if state == null:
		return
	_local_owner_id = clampi(local_owner_id, 1, 4)
	_evaluate_current_step(state)

func _evaluate_current_step(state: GameState) -> void:
	if state == null:
		return
	if _current_step == STEP_1_SWARM:
		if not _has_new_local_swarm(state):
			return
		_current_step = STEP_2_TOWER_CONTROL
		_capture_tower_baseline(state)
		_persist_step(_current_step)
		_refresh_overlay_copy()
		return
	if _current_step == STEP_2_TOWER_CONTROL:
		if not _owns_tower_for_step(state):
			return
		_current_step = STEP_3_BARRACKS_ROUTE
		_capture_barracks_route_baseline(state)
		_persist_step(_current_step)
		_refresh_overlay_copy()
		return
	if _current_step == STEP_3_BARRACKS_ROUTE:
		if not _has_barracks_route_for_step(state):
			return
		_complete_section()

func _capture_baselines(state: GameState) -> void:
	_capture_swarm_baseline(state)
	_capture_tower_baseline(state)
	_capture_barracks_route_baseline(state)

func _capture_swarm_baseline(state: GameState) -> void:
	_seen_swarm_ids.clear()
	if state == null:
		return
	var packets: Array = state.swarm_packets
	for packet_any in packets:
		if typeof(packet_any) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = packet_any as Dictionary
		var swarm_id: int = int(packet.get("id", -1))
		if swarm_id > 0:
			_seen_swarm_ids[swarm_id] = true

func _capture_tower_baseline(state: GameState) -> void:
	_baseline_local_tower_ids.clear()
	if state == null:
		return
	var towers: Array = state.towers
	for tower_any in towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var tower: Dictionary = tower_any as Dictionary
		var tower_id: int = int(tower.get("id", -1))
		var owner_id: int = int(tower.get("owner_id", 0))
		if tower_id <= 0 or owner_id != _local_owner_id:
			continue
		_baseline_local_tower_ids[tower_id] = true

func _capture_barracks_route_baseline(state: GameState) -> void:
	_baseline_local_barracks_routes.clear()
	if state == null:
		return
	var barracks_list: Array = state.barracks
	for barracks_any in barracks_list:
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var barracks_data: Dictionary = barracks_any as Dictionary
		if int(barracks_data.get("owner_id", 0)) != _local_owner_id:
			continue
		var route_targets: Array = _extract_route_targets(barracks_data)
		if route_targets.is_empty():
			continue
		var key: String = _barracks_route_signature(int(barracks_data.get("id", -1)), route_targets)
		if key != "":
			_baseline_local_barracks_routes[key] = true

func _has_new_local_swarm(state: GameState) -> bool:
	if state == null:
		return false
	var packets: Array = state.swarm_packets
	for packet_any in packets:
		if typeof(packet_any) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = packet_any as Dictionary
		var swarm_id: int = int(packet.get("id", -1))
		if swarm_id <= 0:
			continue
		var was_seen: bool = bool(_seen_swarm_ids.get(swarm_id, false))
		_seen_swarm_ids[swarm_id] = true
		if was_seen:
			continue
		if int(packet.get("owner_id", 0)) == _local_owner_id:
			return true
	return false

func _owns_tower_for_step(state: GameState) -> bool:
	if state == null:
		return false
	var local_tower_count: int = 0
	var non_local_tower_count: int = 0
	var towers: Array = state.towers
	for tower_any in towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var tower: Dictionary = tower_any as Dictionary
		var tower_id: int = int(tower.get("id", -1))
		if tower_id <= 0:
			continue
		var owner_id: int = int(tower.get("owner_id", 0))
		if owner_id == _local_owner_id:
			local_tower_count += 1
			if not bool(_baseline_local_tower_ids.get(tower_id, false)):
				return true
		else:
			non_local_tower_count += 1
	if local_tower_count > 0 and non_local_tower_count == 0:
		return true
	return false

func _has_barracks_route_for_step(state: GameState) -> bool:
	if state == null:
		return false
	var local_routed_count: int = 0
	var non_local_barracks_count: int = 0
	var barracks_list: Array = state.barracks
	for barracks_any in barracks_list:
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var barracks_data: Dictionary = barracks_any as Dictionary
		var barracks_id: int = int(barracks_data.get("id", -1))
		if barracks_id <= 0:
			continue
		var owner_id: int = int(barracks_data.get("owner_id", 0))
		if owner_id != _local_owner_id:
			non_local_barracks_count += 1
			continue
		var route_targets: Array = _extract_route_targets(barracks_data)
		if route_targets.is_empty():
			continue
		local_routed_count += 1
		var key: String = _barracks_route_signature(barracks_id, route_targets)
		if key != "" and not bool(_baseline_local_barracks_routes.get(key, false)):
			return true
	if local_routed_count > 0 and non_local_barracks_count == 0:
		return true
	return false

func _extract_route_targets(barracks_data: Dictionary) -> Array:
	var source_v: Variant = barracks_data.get("route_targets", [])
	if typeof(source_v) != TYPE_ARRAY or (source_v as Array).is_empty():
		source_v = barracks_data.get("route_hive_ids", [])
	if typeof(source_v) != TYPE_ARRAY or (source_v as Array).is_empty():
		source_v = barracks_data.get("preferred_targets", [])
	var out: Array = []
	var seen: Dictionary = {}
	if typeof(source_v) != TYPE_ARRAY:
		return out
	for hive_id_any in source_v as Array:
		var hive_id: int = int(hive_id_any)
		if hive_id <= 0 or seen.has(hive_id):
			continue
		seen[hive_id] = true
		out.append(hive_id)
	return out

func _barracks_route_signature(barracks_id: int, route_targets: Array) -> String:
	if barracks_id <= 0 or route_targets.is_empty():
		return ""
	var route_parts: PackedStringArray = PackedStringArray()
	for hive_id_any in route_targets:
		route_parts.append(str(int(hive_id_any)))
	return "%d:[%s]" % [barracks_id, ",".join(route_parts)]

func _persist_step(step_name: String) -> void:
	var profile_manager: Object = _get_profile_manager()
	if profile_manager == null:
		return
	if profile_manager.has_method("set_tutorial_section3_step"):
		profile_manager.call("set_tutorial_section3_step", step_name)

func _complete_section() -> void:
	var profile_manager: Object = _get_profile_manager()
	if profile_manager != null and profile_manager.has_method("mark_tutorial_section3_completed"):
		profile_manager.call("mark_tutorial_section3_completed")
	_current_step = STEP_COMPLETED
	hide(true)

func _on_continue_pressed() -> void:
	if not _active:
		return
	if _current_step != STEP_0_INTRO:
		return
	_current_step = STEP_1_SWARM
	_persist_step(_current_step)
	_refresh_overlay_copy()

func _on_skip_pressed() -> void:
	if not _active:
		return
	var profile_manager: Object = _get_profile_manager()
	if profile_manager != null and profile_manager.has_method("mark_tutorial_section3_skipped"):
		profile_manager.call("mark_tutorial_section3_skipped")
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
		_title_label.text = "Tutorial: Section 3 (Swarms, Towers, Barracks)"
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
		STEP_1_SWARM:
			return "Step 1/3: Launch a Swarm"
		STEP_2_TOWER_CONTROL:
			return "Step 2/3: Control a Tower"
		STEP_3_BARRACKS_ROUTE:
			return "Step 3/3: Route a Barracks"
		_:
			return ""

func _body_text_for_step(step_name: String) -> String:
	match step_name:
		STEP_0_INTRO:
			return "Now learn higher-impact systems: swarms, towers, and barracks.\nPress Continue to begin."
		STEP_1_SWARM:
			return "Launch one swarm from a lane you already control."
		STEP_2_TOWER_CONTROL:
			return "Take control of a tower by owning its required hives."
		STEP_3_BARRACKS_ROUTE:
			return "Activate a barracks and set at least one route target."
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
	if cleaned == STEP_1_SWARM:
		return STEP_1_SWARM
	if cleaned == STEP_2_TOWER_CONTROL:
		return STEP_2_TOWER_CONTROL
	if cleaned == STEP_3_BARRACKS_ROUTE:
		return STEP_3_BARRACKS_ROUTE
	if cleaned == STEP_COMPLETED:
		return STEP_COMPLETED
	if cleaned == STEP_SKIPPED:
		return STEP_SKIPPED
	return STEP_0_INTRO

func _build_overlay() -> Control:
	var overlay: Control = Control.new()
	overlay.name = "TutorialSection3Overlay"
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
	panel.offset_bottom = 236.0
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
	title.text = "Tutorial: Section 3 (Swarms, Towers, Barracks)"
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
