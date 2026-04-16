extends SceneTree

const Section1Script := preload("res://scripts/arena_helpers/tutorial_section1_controller.gd")
const Section2Script := preload("res://scripts/arena_helpers/tutorial_section2_controller.gd")
const Section3Script := preload("res://scripts/arena_helpers/tutorial_section3_controller.gd")

const PROFILE_PATH: String = "user://profile.cfg"

var _hud_root: Control = null
var _profile_backup_exists: bool = false
var _profile_backup_text: String = ""

func _init() -> void:
	await process_frame
	_backup_profile_file()
	_hud_root = Control.new()
	_hud_root.name = "TutorialSmokeHudRoot"
	get_root().add_child(_hud_root)

	_test_profile_sandbox_preparation()
	_test_section1_authoritative_flow()
	_test_section2_authoritative_flow()
	_test_section3_authoritative_flow()

	_restore_profile_file()
	print("TUTORIAL_FLOW_SMOKE: PASS")
	quit(0)

func _test_profile_sandbox_preparation() -> void:
	var profile_manager: Node = _profile_manager()
	_assert_true(profile_manager != null, "ProfileManager autoload should exist")
	_seed_profile_base()
	profile_manager.call("prepare_tutorial_section1_sandbox")
	_assert_eq(str(profile_manager.call("get_tutorial_section1_status")), "in_progress", "section1 sandbox status")
	_assert_eq(str(profile_manager.call("get_tutorial_section1_step")), "step_0_intro", "section1 sandbox step")
	_assert_true(not bool(profile_manager.call("is_tutorial_section2_unlocked")), "section1 sandbox should lock section2")

	profile_manager.call("prepare_tutorial_section2_sandbox")
	_assert_eq(str(profile_manager.call("get_tutorial_section1_status")), "completed", "section2 sandbox should complete section1")
	_assert_true(bool(profile_manager.call("is_tutorial_section2_unlocked")), "section2 sandbox should unlock section2")
	_assert_eq(str(profile_manager.call("get_tutorial_section2_status")), "in_progress", "section2 sandbox status")

	profile_manager.call("prepare_tutorial_section3_sandbox")
	_assert_eq(str(profile_manager.call("get_tutorial_section2_status")), "completed", "section3 sandbox should complete section2")
	_assert_true(bool(profile_manager.call("is_tutorial_section3_unlocked")), "section3 sandbox should unlock section3")
	_assert_eq(str(profile_manager.call("get_tutorial_section3_status")), "in_progress", "section3 sandbox status")

func _test_section1_authoritative_flow() -> void:
	_seed_profile_base()
	var profile_manager: Node = _profile_manager()
	profile_manager.call("prepare_tutorial_section1_sandbox")
	var state: GameState = _make_lane_state([
		{"id": 1, "owner_id": 1},
		{"id": 2, "owner_id": 0}
	], [
		LaneData.new(1, 1, 2, 0, false, false)
	])
	_set_ops_state(state)

	var controller = Section1Script.new()
	_assert_true(
		controller.start_if_needed(Callable(self, "_resolve_hud_root"), Callable(self, "_force_fullscreen_anchors"), 1, state),
		"section1 should start"
	)
	_press_overlay_button("TutorialSection1Overlay", "ContinueButton")
	_assert_eq(str(profile_manager.call("get_tutorial_section1_step")), "step_1_attack_lane", "section1 continue should advance to attack step")

	var lane: LaneData = state.lanes[0] as LaneData
	lane.send_a = true
	_emit_lane_changed(1, state)
	_assert_eq(str(profile_manager.call("get_tutorial_section1_step")), "step_2_retract_lane", "section1 attack should advance to retract step")

	lane.send_a = false
	_emit_lane_changed(1, state)
	_assert_eq(str(profile_manager.call("get_tutorial_section1_step")), "step_3_capture_hive", "section1 retract should advance to capture step")

	var target: HiveData = state.find_hive_by_id(2)
	target.owner_id = 1
	controller.tick(state, 1)
	_assert_eq(str(profile_manager.call("get_tutorial_section1_status")), "completed", "section1 capture should complete section")
	_assert_true(bool(profile_manager.call("is_tutorial_section2_unlocked")), "section1 completion should unlock section2")

func _test_section2_authoritative_flow() -> void:
	_seed_profile_base()
	var profile_manager: Node = _profile_manager()
	profile_manager.call("prepare_tutorial_section2_sandbox")
	profile_manager.call("set_tutorial_section2_step", "step_1_dual_lane")
	var lane_a := LaneData.new(1, 1, 2, 0, true, false)
	var lane_b := LaneData.new(2, 1, 3, 0, true, false)
	var lane_c := LaneData.new(3, 1, 4, 0, false, false)
	var state: GameState = _make_lane_state([
		{"id": 1, "owner_id": 1},
		{"id": 2, "owner_id": 0},
		{"id": 3, "owner_id": 0},
		{"id": 4, "owner_id": 0}
	], [lane_a, lane_b, lane_c])
	_set_ops_state(state)

	var controller = Section2Script.new()
	_assert_true(
		controller.start_if_needed(Callable(self, "_resolve_hud_root"), Callable(self, "_force_fullscreen_anchors"), 1, state),
		"section2 should start"
	)
	_assert_eq(str(profile_manager.call("get_tutorial_section2_step")), "step_2_retract_lane", "section2 dual lane should advance to retract")

	lane_a.send_a = false
	_emit_lane_changed(1, state)
	_assert_eq(str(profile_manager.call("get_tutorial_section2_step")), "step_3_redirect_lane", "section2 retract should advance to redirect")

	lane_c.send_a = true
	_emit_lane_changed(3, state)
	_assert_eq(str(profile_manager.call("get_tutorial_section2_status")), "completed", "section2 redirect should complete section")
	_assert_true(bool(profile_manager.call("is_tutorial_section3_unlocked")), "section2 completion should unlock section3")

func _test_section3_authoritative_flow() -> void:
	_seed_profile_base()
	var profile_manager: Node = _profile_manager()
	profile_manager.call("prepare_tutorial_section3_sandbox")
	profile_manager.call("set_tutorial_section3_step", "step_1_swarm")
	var state: GameState = _make_lane_state([
		{"id": 1, "owner_id": 1},
		{"id": 2, "owner_id": 0}
	], [])
	state.towers = [{"id": 1, "owner_id": 0}]
	state.barracks = [{"id": 1, "owner_id": 0, "route_targets": []}]
	_set_ops_state(state)

	var controller = Section3Script.new()
	_assert_true(
		controller.start_if_needed(Callable(self, "_resolve_hud_root"), Callable(self, "_force_fullscreen_anchors"), 1, state),
		"section3 should start"
	)
	state.swarm_packets.append({"id": 101, "owner_id": 1})
	controller.tick(state, 1)
	_assert_eq(str(profile_manager.call("get_tutorial_section3_step")), "step_2_tower_control", "section3 swarm should advance to tower control")

	(state.towers[0] as Dictionary)["owner_id"] = 1
	controller.tick(state, 1)
	_assert_eq(str(profile_manager.call("get_tutorial_section3_step")), "step_3_barracks_route", "section3 tower control should advance to barracks route")

	(state.barracks[0] as Dictionary)["owner_id"] = 1
	(state.barracks[0] as Dictionary)["route_targets"] = [2]
	controller.tick(state, 1)
	_assert_eq(str(profile_manager.call("get_tutorial_section3_status")), "completed", "section3 barracks route should complete section")

func _make_lane_state(hive_specs: Array, lanes: Array) -> GameState:
	var state: GameState = GameState.new()
	for spec_any in hive_specs:
		var spec: Dictionary = spec_any as Dictionary
		state.hives.append(HiveData.new(
			int(spec.get("id", 0)),
			Vector2i(int(spec.get("id", 0)), 0),
			int(spec.get("owner_id", 0)),
			10
		))
	for lane_any in lanes:
		state.lanes.append(lane_any)
	state.rebuild_indexes()
	return state

func _set_ops_state(state: GameState) -> void:
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_assert_true(ops_state != null, "OpsState autoload should exist")
	ops_state.set("state", state)

func _emit_lane_changed(lane_id: int, state: GameState) -> void:
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	ops_state.emit_signal("lane_intent_changed", int(state.get_instance_id()), lane_id)

func _press_overlay_button(overlay_name: String, button_name: String) -> void:
	var button: Button = _hud_root.get_node_or_null("%s/Panel/VBox/Buttons/%s" % [overlay_name, button_name]) as Button
	_assert_true(button != null, "%s %s should exist" % [overlay_name, button_name])
	button.emit_signal("pressed")

func _resolve_hud_root() -> Control:
	return _hud_root

func _force_fullscreen_anchors(control: Control) -> void:
	if control == null:
		return
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0

func _seed_profile_base() -> void:
	var profile_manager: Node = _profile_manager()
	_assert_true(profile_manager != null, "ProfileManager autoload should exist")
	profile_manager.call("ensure_loaded")
	profile_manager.set("_onboarding_complete", true)
	profile_manager.set("_controls_hint_seen", true)
	profile_manager.set("_tutorial_section1_status", "not_started")
	profile_manager.set("_tutorial_section1_step", "step_0_intro")
	profile_manager.set("_tutorial_section2_unlocked", false)
	profile_manager.set("_tutorial_section2_status", "not_started")
	profile_manager.set("_tutorial_section2_step", "step_0_intro")
	profile_manager.set("_tutorial_section3_unlocked", false)
	profile_manager.set("_tutorial_section3_status", "not_started")
	profile_manager.set("_tutorial_section3_step", "step_0_intro")

func _profile_manager() -> Node:
	return get_root().get_node_or_null("/root/ProfileManager")

func _backup_profile_file() -> void:
	var path: String = ProjectSettings.globalize_path(PROFILE_PATH)
	_profile_backup_exists = FileAccess.file_exists(PROFILE_PATH)
	if not _profile_backup_exists:
		return
	var f: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if f != null:
		_profile_backup_text = f.get_as_text()

func _restore_profile_file() -> void:
	var path: String = ProjectSettings.globalize_path(PROFILE_PATH)
	if _profile_backup_exists:
		var f: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_profile_backup_text)
	else:
		DirAccess.remove_absolute(path)

func _assert_eq(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		return
	_fail("%s (expected %s, got %s)" % [label, expected, actual])

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_fail(label)

func _fail(message: String) -> void:
	_restore_profile_file()
	push_error("TUTORIAL_FLOW_SMOKE: %s" % message)
	quit(1)
