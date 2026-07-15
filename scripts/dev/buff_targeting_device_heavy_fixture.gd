class_name BuffTargetingDeviceHeavyFixture
extends Node2D

const LaneTargetingScript := preload("res://scripts/renderers/buff_lane_global_targeting_controller.gd")
const RuntimeGate := preload("res://scripts/shell_helpers/buff_targeting_runtime_gate.gd")
const AUTOMATED_HARDENING_CHECKPOINT: String = "256b13afbd4c7299c95d1967c5ae58e522c10099"
const HARNESS_SCHEMA: String = "loop5_device_prep_v1"
const LANE_COUNT: int = 64
const SEGMENTS_PER_LANE: int = 10
const MAX_FRAME_SAMPLES: int = 18000
const FLUSH_INTERVAL_MSEC: int = 15000


class FixtureArena:
	extends Node2D

	var projection_offset: Vector2 = Vector2.ZERO
	var revision: int = 1

	func buff_arena_local_to_root_screen(arena_local_pos: Vector2) -> Dictionary:
		return {"ok": true, "root_screen_pos": arena_local_pos + projection_offset}

	func get_buff_targeting_transform_signature() -> String:
		return "%d|%s" % [revision, str(projection_offset)]


class FixtureLaneRenderer:
	extends Node2D

	var probes: Dictionary = {}
	var generation: int = 1

	func get_buff_target_lane_probe(lane_id: int) -> Dictionary:
		return (probes.get(lane_id, {"valid": false}) as Dictionary).duplicate(true)

	func get_buff_target_lane_probe_revision(lane_id: int) -> int:
		return int((probes.get(lane_id, {}) as Dictionary).get("path_revision", -1))

	func get_buff_target_lane_generation() -> int:
		return generation


var _arena: FixtureArena = null
var _renderer: FixtureLaneRenderer = null
var _controller: Node2D = null
var _eligible_lane_ids: Array[int] = []
var _pointer_session_id: int = 1
var _finger_pos: Vector2 = Vector2.ZERO
var _frame_samples_msec: Array[float] = []
var _started_at_msec: int = 0
var _last_flush_msec: int = 0
var _baseline_node_count: int = 0
var _baseline_material_count: int = 0
var _maximum_node_count: int = 0
var _maximum_material_count: int = 0
var _maximum_geometry_rebuilds_per_frame: int = 0
var _latest_snapshot: Dictionary = {}
var _status_label: Label = null
var _evidence_build_commit: String = "unattributed"


func _ready() -> void:
	if not OS.is_debug_build():
		push_error("BUFF_TARGETING_DEVICE_HEAVY_FIXTURE_REFUSED: release build")
		queue_free()
		return
	_evidence_build_commit = RuntimeGate.device_build_id(OS.get_cmdline_user_args())
	set_process_input(true)
	set_process_unhandled_input(true)
	_build_background_and_status()
	_arena = FixtureArena.new()
	_arena.name = "FixtureArena"
	add_child(_arena)
	_renderer = FixtureLaneRenderer.new()
	_renderer.name = "FixtureLaneRenderer"
	add_child(_renderer)
	_build_probes()
	_controller = LaneTargetingScript.new()
	_controller.name = "BuffLaneGlobalTargetPresentation"
	add_child(_controller)
	_controller.call("setup", _arena, _renderer)
	_finger_pos = get_viewport_rect().size * Vector2(0.5, 0.5)
	_controller.call("begin_or_update", _pointer_session_id, {
		"ok": true,
		"target_type": "lane",
		"eligible_target_ids": _eligible_lane_ids
	}, "", null, _finger_pos)
	_started_at_msec = Time.get_ticks_msec()
	_last_flush_msec = _started_at_msec
	await get_tree().process_frame
	await get_tree().process_frame
	_baseline_node_count = _count_nodes(self)
	_baseline_material_count = _count_unique_materials(self)
	_maximum_node_count = _baseline_node_count
	_maximum_material_count = _baseline_material_count
	_latest_snapshot = _controller.call("get_snapshot") as Dictionary
	set_process(true)
	print("BUFF_TARGETING_DEVICE_HEAVY_FIXTURE_STARTED lanes=%d segments=%d" % [LANE_COUNT, LANE_COUNT * SEGMENTS_PER_LANE])


func _process(delta: float) -> void:
	_frame_samples_msec.append(maxf(0.0, delta * 1000.0))
	if _frame_samples_msec.size() > MAX_FRAME_SAMPLES:
		_frame_samples_msec.pop_front()
	var elapsed_seconds: float = float(Time.get_ticks_msec() - _started_at_msec) / 1000.0
	_arena.projection_offset = Vector2(sin(elapsed_seconds * 0.9) * 8.0, cos(elapsed_seconds * 0.7) * 6.0)
	_arena.revision += 1
	_controller.call("force_recompute", "device_camera_motion")
	_latest_snapshot = _controller.call("get_snapshot") as Dictionary
	_maximum_geometry_rebuilds_per_frame = maxi(
		_maximum_geometry_rebuilds_per_frame,
		int(_latest_snapshot.get("max_transform_rebuilds_single_frame", 0))
	)
	_maximum_node_count = maxi(_maximum_node_count, _count_nodes(self))
	_maximum_material_count = maxi(_maximum_material_count, _count_unique_materials(self))
	_update_status()
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_flush_msec >= FLUSH_INTERVAL_MSEC:
		_flush_evidence("periodic")
		_last_flush_msec = now_msec


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_finger_pos = touch.position
			_controller.call("update_finger", _pointer_session_id, _finger_pos)
	elif event is InputEventScreenDrag:
		_finger_pos = (event as InputEventScreenDrag).position
		_controller.call("update_finger", _pointer_session_id, _finger_pos)
	elif event is InputEventMouseMotion:
		_finger_pos = (event as InputEventMouseMotion).position
		_controller.call("update_finger", _pointer_session_id, _finger_pos)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_flush_evidence("application_paused")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_flush_evidence("shutdown")


func evidence_snapshot(reason: String = "manual") -> Dictionary:
	var sorted_frames: Array[float] = _frame_samples_msec.duplicate()
	sorted_frames.sort()
	var current_nodes: int = _count_nodes(self)
	var current_materials: int = _count_unique_materials(self)
	return {
		"schema": "buff_targeting_device_heavy_fixture_v1",
		"harness_schema": HARNESS_SCHEMA,
		"automated_hardening_checkpoint": AUTOMATED_HARDENING_CHECKPOINT,
		"evidence_build_commit": _evidence_build_commit,
		"reason": reason,
		"debug_build": OS.is_debug_build(),
		"production_gate_constant": false,
		"lane_count": LANE_COUNT,
		"segment_count": LANE_COUNT * SEGMENTS_PER_LANE,
		"runtime_msec": maxi(0, Time.get_ticks_msec() - _started_at_msec),
		"frame_sample_count": sorted_frames.size(),
		"frame_min_msec": sorted_frames[0] if not sorted_frames.is_empty() else 0.0,
		"frame_p50_msec": _percentile(sorted_frames, 0.50),
		"frame_p95_msec": _percentile(sorted_frames, 0.95),
		"frame_p99_msec": _percentile(sorted_frames, 0.99),
		"frame_max_msec": sorted_frames[-1] if not sorted_frames.is_empty() else 0.0,
		"maximum_geometry_rebuilds_per_frame": _maximum_geometry_rebuilds_per_frame,
		"geometry_rebuild_count": int(_latest_snapshot.get("geometry_rebuild_count", 0)),
		"geometry_rebuild_elapsed_us": int(_latest_snapshot.get("geometry_rebuild_elapsed_us", 0)),
		"baseline_node_count": _baseline_node_count,
		"current_node_count": current_nodes,
		"maximum_node_count": _maximum_node_count,
		"node_growth": current_nodes - _baseline_node_count,
		"baseline_material_count": _baseline_material_count,
		"current_material_count": current_materials,
		"maximum_material_count": _maximum_material_count,
		"material_growth": current_materials - _baseline_material_count,
		"selected_lane_id": int(_latest_snapshot.get("selected_lane_id", -1)),
		"geometry_dirty": bool(_latest_snapshot.get("geometry_dirty", false))
	}


func _build_probes() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: float = maxf(600.0, viewport_size.x)
	var height: float = maxf(900.0, viewport_size.y)
	var top: float = 180.0
	var usable_height: float = maxf(600.0, height - 300.0)
	for lane_id in range(1, LANE_COUNT + 1):
		var points := PackedVector2Array()
		var base_y: float = top + usable_height * float(lane_id - 1) / float(LANE_COUNT - 1)
		for point_index in range(SEGMENTS_PER_LANE + 1):
			var x: float = 24.0 + (width - 48.0) * float(point_index) / float(SEGMENTS_PER_LANE)
			var wave: float = sin(float(point_index + lane_id) * 0.72) * 11.0
			points.append(Vector2(x, base_y + wave))
		_renderer.probes[lane_id] = {
			"valid": true,
			"renderable": true,
			"points": points,
			"path_revision": lane_id
		}
		_eligible_lane_ids.append(lane_id)
	_renderer.generation += 1


func _build_background_and_status() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FixtureUi"
	layer.layer = -10
	add_child(layer)
	var background := ColorRect.new()
	background.color = Color(0.025, 0.035, 0.06, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(background)
	var foreground := CanvasLayer.new()
	foreground.name = "FixtureStatusUi"
	foreground.layer = 100
	add_child(foreground)
	_status_label = Label.new()
	_status_label.position = Vector2(18, 48)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22, 1.0))
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_status_label.add_theme_constant_override("shadow_offset_x", 2)
	_status_label.add_theme_constant_override("shadow_offset_y", 2)
	foreground.add_child(_status_label)


func _update_status() -> void:
	if _status_label == null:
		return
	var snapshot: Dictionary = evidence_snapshot("display")
	_status_label.text = "LOOP 5 DEBUG-ONLY HEAVY FIXTURE\n64 lanes / 640 segments — drag across lanes\nframe p50 %.2f ms  p95 %.2f ms  p99 %.2f ms\nrebuild max/frame %d  selected %d  node growth %d  material growth %d" % [
		float(snapshot.get("frame_p50_msec", 0.0)),
		float(snapshot.get("frame_p95_msec", 0.0)),
		float(snapshot.get("frame_p99_msec", 0.0)),
		int(snapshot.get("maximum_geometry_rebuilds_per_frame", 0)),
		int(snapshot.get("selected_lane_id", -1)),
		int(snapshot.get("node_growth", 0)),
		int(snapshot.get("material_growth", 0))
	]


func _flush_evidence(reason: String) -> void:
	if _started_at_msec <= 0:
		return
	var snapshot: Dictionary = evidence_snapshot(reason)
	var json: String = JSON.stringify(snapshot)
	var file: FileAccess = FileAccess.open("user://buff_targeting_device_heavy_fixture.json", FileAccess.WRITE)
	if file != null:
		file.store_string(json)
		file.close()
	print("BUFF_TARGETING_DEVICE_HEAVY_EVIDENCE %s" % json)


func _count_nodes(root_node: Node) -> int:
	if root_node == null or not is_instance_valid(root_node):
		return 0
	var total: int = 1
	for child: Node in root_node.get_children():
		total += _count_nodes(child)
	return total


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
