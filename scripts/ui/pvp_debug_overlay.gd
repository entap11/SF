extends Control

const SETTINGS_ENABLED: String = "swarmfront/debug/pvp_overlay_enabled"
const ENV_ENABLED: String = "SF_PVP_DEBUG_OVERLAY"
const UPDATE_INTERVAL_SEC: float = 0.25
const PANEL_WIDTH: float = 430.0
const STUDY_PANEL_HEIGHT: float = 142.0

var _panel: PanelContainer = null
var _label: Label = null
var _toggle_button: Button = null
var _study_panel: PanelContainer = null
var _study_status: Label = null
var _study_hint: Label = null
var _update_accum: float = 0.0
var _panel_open: bool = true
var _build_marker: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_build_marker = _resolve_build_marker()
	_build_ui()
	_build_screen_angle_study_ui()
	set_process(true)
	_refresh_visibility()
	_update_text()

func _process(delta: float) -> void:
	_update_accum += maxf(0.0, delta)
	if _update_accum < UPDATE_INTERVAL_SEC:
		return
	_update_accum = 0.0
	_refresh_visibility()
	if visible and _panel_open:
		_update_text()
	if visible:
		_update_screen_angle_study_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event == null:
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F9:
			_toggle_panel()

func _build_ui() -> void:
	_toggle_button = Button.new()
	_toggle_button.name = "PvpDebugToggle"
	_toggle_button.text = "PVP DBG"
	_toggle_button.focus_mode = Control.FOCUS_NONE
	_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_button.anchor_left = 1.0
	_toggle_button.anchor_right = 1.0
	_toggle_button.anchor_top = 0.0
	_toggle_button.anchor_bottom = 0.0
	_toggle_button.offset_left = -104.0
	_toggle_button.offset_right = -12.0
	_toggle_button.offset_top = 12.0
	_toggle_button.offset_bottom = 44.0
	_toggle_button.add_theme_font_size_override("font_size", 12)
	add_child(_toggle_button)
	_toggle_button.pressed.connect(_toggle_panel)

	_panel = PanelContainer.new()
	_panel.name = "PvpDebugPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -PANEL_WIDTH - 12.0
	_panel.offset_right = -12.0
	_panel.offset_top = 48.0
	_panel.offset_bottom = 430.0
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.68)
	style.border_color = Color(0.86, 0.72, 0.24, 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	_label = Label.new()
	_label.name = "Text"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_label.add_theme_constant_override("outline_size", 1)
	margin.add_child(_label)

func _build_screen_angle_study_ui() -> void:
	_study_panel = PanelContainer.new()
	_study_panel.name = "BattlefieldScreenAngleStudy"
	_study_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_study_panel.anchor_left = 1.0
	_study_panel.anchor_right = 1.0
	_study_panel.anchor_top = 0.0
	_study_panel.anchor_bottom = 0.0
	_study_panel.offset_left = -PANEL_WIDTH - 12.0
	_study_panel.offset_right = -12.0
	_study_panel.custom_minimum_size = Vector2(PANEL_WIDTH, STUDY_PANEL_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.92)
	style.border_color = Color(0.38, 0.84, 0.96, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_study_panel.add_theme_stylebox_override("panel", style)
	add_child(_study_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_study_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	_study_status = Label.new()
	_study_status.add_theme_font_size_override("font_size", 14)
	_study_status.add_theme_color_override("font_color", Color(0.76, 0.94, 1.0, 1.0))
	column.add_child(_study_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	column.add_child(buttons)
	_add_study_angle_button(buttons, "-4°", -4.0)
	_add_study_angle_button(buttons, "-2°", -2.0)
	_add_study_angle_button(buttons, "0°", 0.0)
	_add_study_angle_button(buttons, "+2°", 2.0)
	_add_study_angle_button(buttons, "+4°", 4.0)
	var ab_button := Button.new()
	ab_button.name = "SameStateAB"
	ab_button.text = "A/B"
	ab_button.tooltip_text = "Toggle between 0° and the last non-zero candidate without resetting the match."
	ab_button.focus_mode = Control.FOCUS_NONE
	ab_button.mouse_filter = Control.MOUSE_FILTER_STOP
	ab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab_button.pressed.connect(_toggle_screen_angle_study_ab)
	buttons.add_child(ab_button)

	_study_hint = Label.new()
	_study_hint.add_theme_font_size_override("font_size", 11)
	_study_hint.add_theme_color_override("font_color", Color(0.72, 0.78, 0.84, 1.0))
	_study_hint.text = "Same-state comparison • camera roll only • simulation unchanged"
	column.add_child(_study_hint)

func _add_study_angle_button(parent: HBoxContainer, text_value: String, angle_deg: float) -> void:
	var button := Button.new()
	button.name = "Angle%s" % text_value.replace("°", "").replace("+", "Plus").replace("-", "Minus")
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: _set_screen_angle_study_angle(angle_deg))
	parent.add_child(button)

func _set_screen_angle_study_angle(angle_deg: float) -> void:
	var shell: Node = _shell()
	if shell != null and shell.has_method("set_battlefield_screen_angle_degrees"):
		shell.call("set_battlefield_screen_angle_degrees", angle_deg)
	_update_screen_angle_study_ui()

func _toggle_screen_angle_study_ab() -> void:
	var shell: Node = _shell()
	if shell != null and shell.has_method("toggle_battlefield_screen_angle_ab"):
		shell.call("toggle_battlefield_screen_angle_ab")
	_update_screen_angle_study_ui()

func _screen_angle_study_snapshot() -> Dictionary:
	var shell: Node = _shell()
	if shell != null and shell.has_method("get_battlefield_screen_angle_study_snapshot"):
		var snapshot_any: Variant = shell.call("get_battlefield_screen_angle_study_snapshot")
		if typeof(snapshot_any) == TYPE_DICTIONARY:
			return snapshot_any as Dictionary
	return {"available": false}

func _update_screen_angle_study_ui() -> void:
	if _study_panel == null or not _study_panel.visible:
		return
	var snapshot: Dictionary = _screen_angle_study_snapshot()
	var angle_deg: float = float(snapshot.get("screen_angle_deg", 0.0))
	var mode: String = "BASELINE" if absf(angle_deg) <= 0.001 else "CANDIDATE"
	var applied_text: String = "LIVE" if bool(snapshot.get("applied", false)) else "WAITING FOR MATCH"
	if _study_status != null:
		_study_status.text = "BATTLEFIELD SCREEN ANGLE • %s %+.1f° • %s" % [mode, angle_deg, applied_text]
	if _study_hint != null:
		_study_hint.text = "A/B keeps the same match state • input: %s" % str(snapshot.get("input_mapping", "pending"))

func _shell() -> Node:
	return get_node_or_null("/root/Shell")

func _toggle_panel() -> void:
	_panel_open = not _panel_open
	if _panel != null:
		_panel.visible = _panel_open
	if _panel_open:
		_update_text()

func _refresh_visibility() -> void:
	var debug_visible: bool = _overlay_enabled() and _is_pvp_context()
	var study_snapshot: Dictionary = _screen_angle_study_snapshot()
	var study_visible: bool = (
		bool(study_snapshot.get("available", false))
		and bool(study_snapshot.get("armed", false))
		and bool(study_snapshot.get("arena_present", false))
	)
	visible = debug_visible or study_visible
	if _toggle_button != null:
		_toggle_button.visible = debug_visible
	if _panel != null:
		_panel.visible = debug_visible and _panel_open
	if _study_panel != null:
		_study_panel.visible = study_visible
		var top: float = 442.0 if debug_visible and _panel_open else 12.0
		_study_panel.offset_top = top
		_study_panel.offset_bottom = top + STUDY_PANEL_HEIGHT

func _overlay_enabled() -> bool:
	var env_value: String = OS.get_environment(ENV_ENABLED).strip_edges().to_lower()
	if env_value == "0" or env_value == "false" or env_value == "off":
		return false
	if env_value == "1" or env_value == "true" or env_value == "on":
		return true
	if ProjectSettings.has_setting(SETTINGS_ENABLED):
		return bool(ProjectSettings.get_setting(SETTINGS_ENABLED, false))
	return false

func _is_pvp_context() -> bool:
	var runtime: Node = _runtime()
	if runtime != null and runtime.has_method("is_active") and bool(runtime.call("is_active")):
		return true
	var mode: String = _mode_id()
	match mode:
		"1V1", "2V2", "PVP", "3P FFA", "3P_FFA", "4P FFA", "4P_FFA", "CAPTURE_FLAG", "HIDDEN_CAPTURE_FLAG", "CTF", "HIDDEN CTF":
			return true
		_:
			return false

func _update_text() -> void:
	if _label == null:
		return
	var runtime_snapshot: Dictionary = _runtime_snapshot()
	var diagnostics: Dictionary = runtime_snapshot.get("diagnostics", {}) as Dictionary if typeof(runtime_snapshot.get("diagnostics", {})) == TYPE_DICTIONARY else {}
	var state_snapshot: Dictionary = _debug_state_snapshot()
	var perf: Dictionary = _perf_snapshot()
	var arena: Node = _arena()
	var active_scene_path: String = _active_scene_path()
	var map_path: String = _map_path(arena)
	var map_id: String = _map_id(state_snapshot, map_path)
	var scale_value: String = _scale_value(arena)
	var local_uid: String = str(runtime_snapshot.get("local_uid", _tree_meta_string("vs_local_profile", "")))
	if local_uid.is_empty():
		local_uid = _local_profile_uid()
	var role: String = str(runtime_snapshot.get("role", _tree_meta_string("vs_handshake_role", ""))).strip_edges()
	if role.is_empty():
		role = "local"
	var hash_value: String = str(state_snapshot.get("hash", ""))
	var hash_short: String = hash_value.substr(0, mini(12, hash_value.length()))
	var lines: Array[String] = []
	lines.append("PVP DEBUG %s" % _build_marker)
	lines.append("scene: %s" % active_scene_path)
	lines.append("mode: %s | role: %s | seat: %d" % [_mode_id(), role, int(runtime_snapshot.get("local_seat", 0))])
	lines.append("remote: %s | seat: %d" % [
		str(runtime_snapshot.get("remote_uid", "")).strip_edges(),
		int(runtime_snapshot.get("remote_seat", 0))
	])
	lines.append("player: %s" % local_uid)
	lines.append("map: %s" % map_id)
	lines.append("path: %s" % map_path)
	lines.append("scale: %s" % scale_value)
	lines.append("fps: %.1f | frame: %.1f ms" % [float(perf.get("fps", 0.0)), float(perf.get("frame_ms", 0.0))])
	lines.append("units: %d | lanes: %d" % [_active_unit_count(), _active_lane_count()])
	lines.append("pub %d/%d | poll %d/%d | tx/rx/cmd %d/%d/%d | pending %d" % [
		int(runtime_snapshot.get("publish_count", 0)),
		int(runtime_snapshot.get("publish_fail_count", 0)),
		int(runtime_snapshot.get("poll_count", 0)),
		int(runtime_snapshot.get("poll_fail_count", 0)),
		int(runtime_snapshot.get("intent_events_tx", 0)),
		int(runtime_snapshot.get("intent_events_rx", 0)),
		int(runtime_snapshot.get("remote_commands_rx", 0)),
		int(runtime_snapshot.get("pending_commands", 0))
	])
	var telemetry_log_path: String = str(runtime_snapshot.get("runtime_telemetry_log_path", "")).strip_edges()
	if not telemetry_log_path.is_empty():
		lines.append("log: %s" % telemetry_log_path)
	lines.append("recovery: %s | violations: %d (%s)" % [
		str(runtime_snapshot.get("recovery_state", "running")),
		int(diagnostics.get("contract_violation_count", 0)),
		str(diagnostics.get("contract_last_violation_reason", "")).strip_edges()
	])
	lines.append("state hash: %s" % hash_short)
	if bool(runtime_snapshot.get("desync", false)) or int(diagnostics.get("contract_state_hash_mismatches", 0)) > 0:
		lines.append("DESYNC DETECTED")
		lines.append("pre-diverge: %s" % _event_summary(runtime_snapshot.get("desync_event_before_divergence", {})))
	lines.append("events:")
	var events_any: Variant = runtime_snapshot.get("events", [])
	if typeof(events_any) == TYPE_ARRAY:
		for event_any in events_any as Array:
			if typeof(event_any) != TYPE_DICTIONARY:
				continue
			lines.append("  %s" % _event_summary(event_any))
	_label.text = "\n".join(lines)

func _runtime_snapshot() -> Dictionary:
	var runtime: Node = _runtime()
	if runtime != null and runtime.has_method("get_debug_snapshot"):
		var snapshot_any: Variant = runtime.call("get_debug_snapshot")
		if typeof(snapshot_any) == TYPE_DICTIONARY:
			return snapshot_any as Dictionary
	return {}

func _debug_state_snapshot() -> Dictionary:
	if OpsState != null and OpsState.has_method("get_pvp_debug_state_snapshot"):
		var snapshot_any: Variant = OpsState.call("get_pvp_debug_state_snapshot")
		if typeof(snapshot_any) == TYPE_DICTIONARY:
			return snapshot_any as Dictionary
	return {}

func _perf_snapshot() -> Dictionary:
	var fps: float = float(Engine.get_frames_per_second())
	var frame_ms: float = 0.0
	if fps > 0.01:
		frame_ms = 1000.0 / fps
	return {"fps": fps, "frame_ms": frame_ms}

func _runtime() -> Node:
	return get_node_or_null("/root/VsPvpRuntime")

func _arena() -> Node:
	var root: Window = get_tree().root if get_tree() != null else null
	if root == null:
		return null
	var arena: Node = root.get_node_or_null("/root/Shell/ArenaRoot/Main/WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")
	if arena != null:
		return arena
	return root.find_child("Arena", true, false)

func _active_scene_path() -> String:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return "<none>"
	var path: String = str(tree.current_scene.scene_file_path).strip_edges()
	if path.is_empty():
		return str(tree.current_scene.name)
	return path

func _mode_id() -> String:
	var tree: SceneTree = get_tree()
	if tree == null:
		return ""
	return str(tree.get_meta("vs_mode", "")).strip_edges().to_upper()

func _map_path(arena: Node) -> String:
	if arena != null:
		var arena_path: String = str(arena.get("current_map_path")).strip_edges()
		if not arena_path.is_empty():
			return arena_path
	var tree: SceneTree = get_tree()
	if tree == null:
		return ""
	var jukebox_path: String = str(tree.get_meta("jukebox_map_path", "")).strip_edges()
	if not jukebox_path.is_empty():
		return jukebox_path
	var stage_maps_any: Variant = tree.get_meta("vs_stage_map_paths", [])
	if typeof(stage_maps_any) == TYPE_ARRAY:
		var stage_maps: Array = stage_maps_any as Array
		var stage_index: int = clampi(int(tree.get_meta("vs_stage_current_index", 0)), 0, maxi(stage_maps.size() - 1, 0))
		if stage_index >= 0 and stage_index < stage_maps.size():
			return str(stage_maps[stage_index]).strip_edges()
	return ""

func _map_id(state_snapshot: Dictionary, map_path: String) -> String:
	var state_map: String = str(state_snapshot.get("map_id", "")).strip_edges()
	if not state_map.is_empty():
		return state_map
	if map_path.is_empty():
		return "<none>"
	return map_path.get_file().get_basename()

func _scale_value(arena: Node) -> String:
	var profile_scale: float = 1.0
	var profile_mode: String = "unknown"
	if ProfileManager != null and ProfileManager.has_method("get_content_scale_factor"):
		profile_scale = float(ProfileManager.call("get_content_scale_factor"))
	if ProfileManager != null and ProfileManager.has_method("get_performance_mode"):
		profile_mode = str(ProfileManager.call("get_performance_mode")).strip_edges()
	var window_scale: float = 1.0
	var window_ref: Window = get_window()
	if window_ref != null:
		window_scale = float(window_ref.content_scale_factor)
	var cam_fit_y: float = 0.0
	if arena != null:
		cam_fit_y = float(arena.get("cam_fit_height_y_scale"))
	return "user://profile.cfg profile/performance_mode=%s content_scale=%.3f window=%.3f cam_fit_y=%.3f" % [profile_mode, profile_scale, window_scale, cam_fit_y]

func _active_unit_count() -> int:
	var st: GameState = OpsState.get_state() if OpsState != null and OpsState.has_method("get_state") else null
	if st == null:
		return 0
	if st.unit_system != null:
		var units_any: Variant = st.unit_system.get("units")
		if typeof(units_any) == TYPE_ARRAY:
			return (units_any as Array).size()
	var units_by_lane_any: Variant = st.units_by_lane.get("_all", [])
	if typeof(units_by_lane_any) == TYPE_ARRAY:
		return (units_by_lane_any as Array).size()
	return 0

func _active_lane_count() -> int:
	var st: GameState = OpsState.get_state() if OpsState != null and OpsState.has_method("get_state") else null
	if st == null:
		return 0
	var count: int = 0
	for lane_any in st.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		if bool(lane.send_a) or bool(lane.send_b):
			count += 1
	return count

func _event_summary(event_any: Variant) -> String:
	if typeof(event_any) != TYPE_DICTIONARY:
		return "<none>"
	var event: Dictionary = event_any as Dictionary
	if event.is_empty():
		return "<none>"
	var payload: Dictionary = event.get("payload", {}) as Dictionary if typeof(event.get("payload", {})) == TYPE_DICTIONARY else {}
	var event_type: String = str(event.get("type", "event"))
	var reason: String = str(payload.get("reason", "")).strip_edges()
	var src: int = int(payload.get("src", payload.get("from_id", -1)))
	var dst: int = int(payload.get("dst", payload.get("to_id", -1)))
	var intent: String = str(payload.get("intent", "")).strip_edges()
	var tick: int = int(event.get("tick", -1))
	var base: String = "t%d %s" % [tick, event_type]
	if src > 0 or dst > 0:
		base += " %d>%d" % [src, dst]
	if not intent.is_empty():
		base += " %s" % intent
	if not reason.is_empty():
		base += " (%s)" % reason
	return base

func _local_profile_uid() -> String:
	var tree: SceneTree = get_tree()
	if tree == null:
		return ""
	var profile_any: Variant = tree.get_meta("vs_local_profile", {})
	if typeof(profile_any) != TYPE_DICTIONARY:
		return ""
	var profile: Dictionary = profile_any as Dictionary
	return str(profile.get("uid", profile.get("id", profile.get("name", "")))).strip_edges()

func _tree_meta_string(key: String, fallback: String) -> String:
	var tree: SceneTree = get_tree()
	if tree == null:
		return fallback
	return str(tree.get_meta(key, fallback)).strip_edges()

func _resolve_build_marker() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	var git_hash: String = OS.get_environment("SF_BUILD_GIT_HASH").strip_edges()
	if git_hash.is_empty():
		git_hash = OS.get_environment("GIT_COMMIT").strip_edges()
	if git_hash.is_empty():
		git_hash = _read_git_hash()
	if git_hash.length() > 12:
		git_hash = git_hash.substr(0, 12)
	if version.is_empty():
		version = "dev"
	if git_hash.is_empty():
		return version
	return "%s %s" % [version, git_hash]

func _read_git_hash() -> String:
	if not FileAccess.file_exists("res://.git/HEAD"):
		return ""
	var head_file: FileAccess = FileAccess.open("res://.git/HEAD", FileAccess.READ)
	if head_file == null:
		return ""
	var head: String = head_file.get_as_text().strip_edges()
	head_file.close()
	if head.begins_with("ref:"):
		var ref_path: String = "res://.git/" + head.trim_prefix("ref:").strip_edges()
		if not FileAccess.file_exists(ref_path):
			return ""
		var ref_file: FileAccess = FileAccess.open(ref_path, FileAccess.READ)
		if ref_file == null:
			return ""
		var ref_hash: String = ref_file.get_as_text().strip_edges()
		ref_file.close()
		return ref_hash
	return head
