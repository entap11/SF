class_name BuffTargetingDeviceEvidenceCollector
extends Node

const RuntimeGate := preload("res://scripts/shell_helpers/buff_targeting_runtime_gate.gd")
const AUTOMATED_HARDENING_CHECKPOINT: String = "256b13afbd4c7299c95d1967c5ae58e522c10099"
const HARNESS_SCHEMA: String = "loop5_device_prep_v1"
const MAX_FRAME_SAMPLES: int = 18000
const FLUSH_INTERVAL_MSEC: int = 15000
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
	_resolve_production_components()
	_sample_production_components()
	_update_resource_counts()
	_update_status_label()
	var now_msec: int = Time.get_ticks_msec()
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
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"runtime_msec": maxi(0, Time.get_ticks_msec() - _started_at_msec),
		"frame_sample_count": sorted_frames.size(),
		"frame_min_msec": sorted_frames[0] if not sorted_frames.is_empty() else 0.0,
		"frame_p50_msec": _percentile(sorted_frames, 0.50),
		"frame_p95_msec": _percentile(sorted_frames, 0.95),
		"frame_p99_msec": _percentile(sorted_frames, 0.99),
		"frame_max_msec": sorted_frames[-1] if not sorted_frames.is_empty() else 0.0,
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
	if _lane_controller != null and is_instance_valid(_lane_controller) and _lane_controller.has_method("get_snapshot"):
		_latest_lane_snapshot = _lane_controller.call("get_snapshot") as Dictionary
		_maximum_geometry_rebuilds_per_frame = maxi(
			_maximum_geometry_rebuilds_per_frame,
			int(_latest_lane_snapshot.get("max_transform_rebuilds_single_frame", 0))
		)
	if _feedback_controller != null and is_instance_valid(_feedback_controller) and _feedback_controller.has_method("get_snapshot"):
		_latest_feedback_snapshot = _feedback_controller.call("get_snapshot") as Dictionary


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
	_status_label.position = Vector2(12, 72)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22, 1.0))
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_status_label.add_theme_constant_override("shadow_offset_x", 2)
	_status_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_status_label)


func _update_status_label() -> void:
	if _status_label == null:
		return
	var latency_count: int = int(_latest_feedback_snapshot.get("latency_sample_count", 0))
	_status_label.text = "LOOP 5 DEVICE HARNESS  %s\nframes %d  latency %d  rebuild max/frame %d" % [
		_role, _frame_samples_msec.size(), latency_count, _maximum_geometry_rebuilds_per_frame
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
