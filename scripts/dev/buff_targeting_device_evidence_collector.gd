class_name BuffTargetingDeviceEvidenceCollector
extends Node

const RuntimeGate := preload("res://scripts/shell_helpers/buff_targeting_runtime_gate.gd")
const AUTOMATED_HARDENING_CHECKPOINT: String = "256b13afbd4c7299c95d1967c5ae58e522c10099"
const HARNESS_SCHEMA: String = "loop5_device_prep_v1"
const MAX_FRAME_SAMPLES: int = 18000
const FLUSH_INTERVAL_MSEC: int = 15000
const COMPONENT_SAMPLE_INTERVAL_MSEC: int = 250
const HARNESS_READY_TIMEOUT_MSEC: int = 6000
const REQUIRED_LOADOUT_IDS: Array[String] = [
	"buff_unit_speed_classic",
	"buff_freeze_lane_classic",
	"buff_global_production_boost_classic"
]
const ARENA_PATH: NodePath = NodePath("ArenaRoot/Main/WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")
const HIVE_PRESENTATION_PATH: NodePath = NodePath("MapRoot/BuffHiveTargetPresentation")
const LANE_PRESENTATION_PATH: NodePath = NodePath("MapRoot/BuffLaneGlobalTargetPresentation")
const FEEDBACK_PRESENTATION_PATH: NodePath = NodePath("MapRoot/BuffCanonicalFeedbackPresentation")

var _shell: Node = null
var _role: String = "unspecified"
var _evidence_build_commit: String = "unattributed"
var _frame_samples_msec: Array[float] = []
var _started_at_msec: int = 0
var _last_flush_msec: int = 0
var _last_component_sample_msec: int = 0
var _arena: Node = null
var _hive_controller: Node = null
var _lane_controller: Node = null
var _feedback_controller: Node = null
var _baseline_node_count: int = -1
var _baseline_material_count: int = -1
var _maximum_node_count: int = 0
var _maximum_material_count: int = 0
var _maximum_geometry_rebuilds_per_frame: int = 0
var _latest_lane_snapshot: Dictionary = {}
var _latest_feedback_snapshot: Dictionary = {}
var _latest_buff_ui_snapshot: Dictionary = {}
var _latest_device_session_snapshot: Dictionary = {}
var _harness_ready: bool = false
var _harness_blocked_reason: String = ""
var _arena_first_seen_msec: int = 0
var _engine_process_samples_msec: Array[float] = []
var _physics_process_samples_msec: Array[float] = []
var _maximum_draw_calls: int = 0
var _maximum_primitives: int = 0
var _maximum_render_objects: int = 0
var _status_label: Label = null


func setup(shell_ref: Node, role: String, evidence_build_commit: String = "unattributed") -> void:
	_shell = shell_ref
	_role = role if RuntimeGate.VALID_ROLES.has(role) else "unspecified"
	_evidence_build_commit = evidence_build_commit
	_started_at_msec = Time.get_ticks_msec()
	_last_flush_msec = _started_at_msec
	_build_status_label()
	set_process(true)
	print("BUFF_TARGETING_DEVICE_HARNESS_STARTED role=%s debug=%s" % [_role, str(OS.is_debug_build())])


func _process(delta: float) -> void:
	_frame_samples_msec.append(maxf(0.0, delta * 1000.0))
	if _frame_samples_msec.size() > MAX_FRAME_SAMPLES:
		_frame_samples_msec.pop_front()
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_component_sample_msec >= COMPONENT_SAMPLE_INTERVAL_MSEC:
		_resolve_production_components()
		_sample_production_components()
		_update_resource_counts()
		_sample_engine_performance()
		_evaluate_harness_readiness(now_msec)
		_update_status_label()
		_last_component_sample_msec = now_msec
	if now_msec - _last_flush_msec >= FLUSH_INTERVAL_MSEC:
		_flush_evidence("periodic")
		_last_flush_msec = now_msec


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_flush_evidence("application_paused")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_flush_evidence("shutdown")


func evidence_snapshot(reason: String = "manual") -> Dictionary:
	var sorted_frames: Array[float] = _frame_samples_msec.duplicate()
	sorted_frames.sort()
	var sorted_process: Array[float] = _engine_process_samples_msec.duplicate()
	sorted_process.sort()
	var sorted_physics: Array[float] = _physics_process_samples_msec.duplicate()
	sorted_physics.sort()
	var current_node_count: int = _count_presentation_nodes()
	var current_material_count: int = _count_presentation_materials()
	return {
		"schema": "buff_targeting_device_evidence_v1",
		"harness_schema": HARNESS_SCHEMA,
		"automated_hardening_checkpoint": AUTOMATED_HARDENING_CHECKPOINT,
		"evidence_build_commit": _evidence_build_commit,
		"reason": reason,
		"role": _role,
		"debug_build": OS.is_debug_build(),
		"production_gate_constant": false,
		"harness_ready": _harness_ready,
		"harness_blocked_reason": _harness_blocked_reason,
		"required_loadout_ids": REQUIRED_LOADOUT_IDS.duplicate(),
		"buff_ui": _latest_buff_ui_snapshot.duplicate(true),
		"device_sim_session": _latest_device_session_snapshot.duplicate(true),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"runtime_msec": maxi(0, Time.get_ticks_msec() - _started_at_msec),
		"frame_sample_count": sorted_frames.size(),
		"frame_min_msec": sorted_frames[0] if not sorted_frames.is_empty() else 0.0,
		"frame_p50_msec": _percentile(sorted_frames, 0.50),
		"frame_p95_msec": _percentile(sorted_frames, 0.95),
		"frame_p99_msec": _percentile(sorted_frames, 0.99),
		"frame_max_msec": sorted_frames[-1] if not sorted_frames.is_empty() else 0.0,
		"engine_process_p50_msec": _percentile(sorted_process, 0.50),
		"engine_process_p95_msec": _percentile(sorted_process, 0.95),
		"engine_process_max_msec": sorted_process[-1] if not sorted_process.is_empty() else 0.0,
		"physics_process_p50_msec": _percentile(sorted_physics, 0.50),
		"physics_process_p95_msec": _percentile(sorted_physics, 0.95),
		"physics_process_max_msec": sorted_physics[-1] if not sorted_physics.is_empty() else 0.0,
		"maximum_draw_calls": _maximum_draw_calls,
		"maximum_primitives": _maximum_primitives,
		"maximum_render_objects": _maximum_render_objects,
		"maximum_geometry_rebuilds_per_frame": _maximum_geometry_rebuilds_per_frame,
		"lane_presentation": _latest_lane_snapshot.duplicate(true),
		"canonical_feedback": _latest_feedback_snapshot.duplicate(true),
		"baseline_node_count": _baseline_node_count,
		"current_node_count": current_node_count,
		"maximum_node_count": _maximum_node_count,
		"node_growth": current_node_count - _baseline_node_count if _baseline_node_count >= 0 else 0,
		"baseline_material_count": _baseline_material_count,
		"current_material_count": current_material_count,
		"maximum_material_count": _maximum_material_count,
		"material_growth": current_material_count - _baseline_material_count if _baseline_material_count >= 0 else 0
	}


func _resolve_production_components() -> void:
	if _shell == null or not is_instance_valid(_shell):
		return
	if _arena == null or not is_instance_valid(_arena):
		_arena = _shell.get_node_or_null(ARENA_PATH)
		_hive_controller = null
		_lane_controller = null
		_feedback_controller = null
		_baseline_node_count = -1
		_baseline_material_count = -1
		_arena_first_seen_msec = Time.get_ticks_msec() if _arena != null else 0
	if _arena == null:
		return
	if _hive_controller == null or not is_instance_valid(_hive_controller):
		_hive_controller = _arena.get_node_or_null(HIVE_PRESENTATION_PATH)
	if _lane_controller == null or not is_instance_valid(_lane_controller):
		_lane_controller = _arena.get_node_or_null(LANE_PRESENTATION_PATH)
	if _feedback_controller == null or not is_instance_valid(_feedback_controller):
		_feedback_controller = _arena.get_node_or_null(FEEDBACK_PRESENTATION_PATH)
	if _baseline_node_count < 0 and _hive_controller != null and _lane_controller != null and _feedback_controller != null:
		_baseline_node_count = _count_presentation_nodes()
		_baseline_material_count = _count_presentation_materials()
		_maximum_node_count = _baseline_node_count
		_maximum_material_count = _baseline_material_count


func _sample_production_components() -> void:
	if _arena != null and is_instance_valid(_arena):
		if _arena.has_method("get_buff_ui_snapshot"):
			_latest_buff_ui_snapshot = _arena.call("get_buff_ui_snapshot") as Dictionary
		if _arena.has_method("get_buff_device_evidence_session_snapshot"):
			_latest_device_session_snapshot = _arena.call("get_buff_device_evidence_session_snapshot") as Dictionary
	if _lane_controller != null and is_instance_valid(_lane_controller) and _lane_controller.has_method("get_snapshot"):
		_latest_lane_snapshot = _lane_controller.call("get_snapshot") as Dictionary
		_maximum_geometry_rebuilds_per_frame = maxi(
			_maximum_geometry_rebuilds_per_frame,
			int(_latest_lane_snapshot.get("max_transform_rebuilds_single_frame", 0))
		)
	if _feedback_controller != null and is_instance_valid(_feedback_controller) and _feedback_controller.has_method("get_snapshot"):
		_latest_feedback_snapshot = _feedback_controller.call("get_snapshot") as Dictionary


func _sample_engine_performance() -> void:
	_engine_process_samples_msec.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	_physics_process_samples_msec.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	if _engine_process_samples_msec.size() > MAX_FRAME_SAMPLES:
		_engine_process_samples_msec.pop_front()
	if _physics_process_samples_msec.size() > MAX_FRAME_SAMPLES:
		_physics_process_samples_msec.pop_front()
	_maximum_draw_calls = maxi(_maximum_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_maximum_primitives = maxi(_maximum_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	_maximum_render_objects = maxi(_maximum_render_objects, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))


func _evaluate_harness_readiness(now_msec: int) -> void:
	if _harness_ready or not _harness_blocked_reason.is_empty() or _arena == null:
		return
	var reason: String = _device_readiness_failure()
	if reason.is_empty():
		_harness_ready = true
		print("BUFF_TARGETING_DEVICE_HARNESS_READY role=%s loadout=%s" % [_role, str(REQUIRED_LOADOUT_IDS)])
		return
	if _arena_first_seen_msec <= 0 or now_msec - _arena_first_seen_msec < HARNESS_READY_TIMEOUT_MSEC:
		return
	_harness_blocked_reason = reason
	push_error("BUFF_TARGETING_DEVICE_HARNESS_BLOCKED role=%s reason=%s" % [_role, reason])


func _device_readiness_failure() -> String:
	if not bool(_latest_device_session_snapshot.get("enabled", false)):
		return "device_sim_session_disabled"
	if str(_latest_device_session_snapshot.get("role", "")) != _role:
		return "device_role_mismatch"
	if bool(_latest_device_session_snapshot.get("persistent_inventory_mutated", true)):
		return "persistent_inventory_mutated"
	if not bool(_latest_buff_ui_snapshot.get("buffs_enabled", false)):
		return "arena_buffs_disabled"
	var active_pid: int = int(_latest_buff_ui_snapshot.get("active_player_id", 0))
	var players: Dictionary = _latest_buff_ui_snapshot.get("players", {}) as Dictionary
	var player: Dictionary = players.get(active_pid, {}) as Dictionary
	if int(player.get("slots_active", 0)) < REQUIRED_LOADOUT_IDS.size():
		return "three_active_slots_unavailable"
	var actual_ids: Array[String] = []
	for slot_any: Variant in player.get("slots", []) as Array:
		if typeof(slot_any) == TYPE_DICTIONARY:
			actual_ids.append(str((slot_any as Dictionary).get("inventory_id", "")))
	for required_id: String in REQUIRED_LOADOUT_IDS:
		if not actual_ids.has(required_id):
			return "required_buff_missing:%s" % required_id
	return ""


func _update_resource_counts() -> void:
	if _baseline_node_count < 0:
		return
	_maximum_node_count = maxi(_maximum_node_count, _count_presentation_nodes())
	_maximum_material_count = maxi(_maximum_material_count, _count_presentation_materials())


func _flush_evidence(reason: String) -> void:
	if _started_at_msec <= 0:
		return
	var snapshot: Dictionary = evidence_snapshot(reason)
	var json: String = JSON.stringify(snapshot)
	var path: String = "user://buff_targeting_device_evidence_%s.json" % _role
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(json)
		file.close()
	print("BUFF_TARGETING_DEVICE_EVIDENCE %s" % json)


func _build_status_label() -> void:
	if _shell == null or not is_instance_valid(_shell):
		return
	var layer := CanvasLayer.new()
	layer.name = "BuffTargetingDeviceEvidenceLayer"
	layer.layer = 250
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_shell.add_child(layer)
	_status_label = Label.new()
	_status_label.name = "BuffTargetingDeviceEvidenceStatus"
	_status_label.position = Vector2(24, 124)
	_status_label.custom_minimum_size = Vector2(960, 112)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 34)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22, 1.0))
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_status_label.add_theme_constant_override("shadow_offset_x", 2)
	_status_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_status_label)


func _update_status_label() -> void:
	if _status_label == null:
		return
	var latency_count: int = int(_latest_feedback_snapshot.get("latency_sample_count", 0))
	var state_label: String = "READY" if _harness_ready else ("BLOCKED" if not _harness_blocked_reason.is_empty() else "WAITING")
	_status_label.add_theme_color_override(
		"font_color",
		Color(0.35, 1.0, 0.42, 1.0) if _harness_ready else (Color(1.0, 0.25, 0.20, 1.0) if state_label == "BLOCKED" else Color(1.0, 0.86, 0.22, 1.0))
	)
	_status_label.text = "LOOP 5  %s  %s\nframes %d  latency %d  rebuild max/frame %d%s" % [
		_role,
		state_label,
		_frame_samples_msec.size(),
		latency_count,
		_maximum_geometry_rebuilds_per_frame,
		"  %s" % _harness_blocked_reason if not _harness_blocked_reason.is_empty() else ""
	]


func _count_nodes(root_node: Node) -> int:
	if root_node == null or not is_instance_valid(root_node):
		return 0
	var total: int = 1
	for child: Node in root_node.get_children():
		total += _count_nodes(child)
	return total


func _count_presentation_nodes() -> int:
	return _count_nodes(_hive_controller) + _count_nodes(_lane_controller) + _count_nodes(_feedback_controller)


func _count_presentation_materials() -> int:
	var ids: Dictionary = {}
	_collect_material_ids(_hive_controller, ids)
	_collect_material_ids(_lane_controller, ids)
	_collect_material_ids(_feedback_controller, ids)
	return ids.size()


func _count_unique_materials(root_node: Node) -> int:
	var ids: Dictionary = {}
	_collect_material_ids(root_node, ids)
	return ids.size()


func _collect_material_ids(root_node: Node, ids: Dictionary) -> void:
	if root_node == null or not is_instance_valid(root_node):
		return
	if root_node is CanvasItem:
		var material: Material = (root_node as CanvasItem).material
		if material != null:
			ids[material.get_instance_id()] = true
	for child: Node in root_node.get_children():
		_collect_material_ids(child, ids)


func _percentile(sorted_values: Array[float], percentile: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var rank: int = int(ceil(clampf(percentile, 0.0, 1.0) * float(sorted_values.size())))
	return sorted_values[clampi(rank - 1, 0, sorted_values.size() - 1)]
