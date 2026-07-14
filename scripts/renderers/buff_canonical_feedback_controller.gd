class_name BuffCanonicalFeedbackController
extends Node2D

signal feedback_started(activation_id: String, target_type: String, target_id: Variant, latency_msec: int)
signal canonical_outcome_ignored(activation_id: String, reason: String)

const Config := preload("res://scripts/renderers/buff_targeting_presentation_config.gd")
const ReceiptsScript := preload("res://scripts/renderers/buff_activation_presentation_receipts.gd")

var _arena: Node = null
var _hive_renderer: Node2D = null
var _lane_renderer: Node2D = null
var _presentation_epoch: String = ""
var _receipts: RefCounted = ReceiptsScript.new()
var _flashes: Array[Dictionary] = []
var _latency_sample_count: int = 0
var _latency_total_msec: int = 0
var _latency_max_msec: int = 0


func _ready() -> void:
	z_as_relative = false
	z_index = 36
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)


func setup(arena_ref: Node, hive_renderer_ref: Node2D, lane_renderer_ref: Node2D, presentation_epoch: String) -> void:
	_arena = arena_ref
	_hive_renderer = hive_renderer_ref
	_lane_renderer = lane_renderer_ref
	set_presentation_epoch(presentation_epoch)


func set_presentation_epoch(presentation_epoch: String) -> void:
	var clean_epoch: String = presentation_epoch.strip_edges()
	if clean_epoch == _presentation_epoch:
		return
	_presentation_epoch = clean_epoch
	_receipts.clear()
	_flashes.clear()
	set_process(false)
	queue_redraw()


func register_submission_receipt(
	match_id: String,
	owner_id: int,
	activation_id: String,
	target_type: String,
	target_id: Variant,
	presentation_epoch: String,
	submitted_at_msec: int = -1
) -> Dictionary:
	if presentation_epoch != _presentation_epoch or _presentation_epoch.is_empty():
		return {"ok": false, "reason": "presentation_epoch_mismatch"}
	var result: Dictionary = _receipts.register_submission(
		match_id, owner_id, activation_id, target_type, target_id,
		presentation_epoch, submitted_at_msec
	)
	if bool(result.get("ok", false)):
		set_process(true)
	return result


func handle_canonical_outcome(outcome: Dictionary, presentation_epoch: String) -> Dictionary:
	var activation_id: String = str(outcome.get("activation_id", ""))
	if presentation_epoch != _presentation_epoch or _presentation_epoch.is_empty():
		canonical_outcome_ignored.emit(activation_id, "presentation_epoch_mismatch")
		return {"feedback": false, "reason": "presentation_epoch_mismatch"}
	var result: Dictionary = _receipts.consume_canonical_outcome(outcome, presentation_epoch)
	if not bool(result.get("feedback", false)):
		canonical_outcome_ignored.emit(activation_id, str(result.get("reason", "outcome_ignored")))
		_update_processing()
		return result
	var receipt: Dictionary = result.get("receipt", {}) as Dictionary
	var target_type: String = str(receipt.get("target_type", ""))
	var target_id: Variant = receipt.get("target_id", null)
	if not _target_has_current_probe(target_type, target_id):
		result["feedback"] = false
		result["reason"] = "current_render_probe_missing"
		canonical_outcome_ignored.emit(activation_id, "current_render_probe_missing")
		_update_processing()
		return result
	var latency_msec: int = int(result.get("receipt_age_msec", 0))
	_latency_sample_count += 1
	_latency_total_msec += latency_msec
	_latency_max_msec = maxi(_latency_max_msec, latency_msec)
	_flashes.append({
		"activation_id": activation_id,
		"target_type": target_type,
		"target_id": target_id,
		"owner_id": int(receipt.get("owner_id", 0)),
		"started_at_msec": Time.get_ticks_msec(),
		"color": _owner_color(int(receipt.get("owner_id", 0)))
	})
	feedback_started.emit(activation_id, target_type, target_id, latency_msec)
	set_process(true)
	queue_redraw()
	return result


func clear_presentation() -> void:
	_receipts.clear()
	_flashes.clear()
	set_process(false)
	queue_redraw()


func get_snapshot() -> Dictionary:
	var receipt_snapshot: Dictionary = _receipts.snapshot()
	receipt_snapshot.merge({
		"presentation_epoch": _presentation_epoch,
		"active_flash_count": _flashes.size(),
		"latency_sample_count": _latency_sample_count,
		"latency_average_msec": float(_latency_total_msec) / float(_latency_sample_count) if _latency_sample_count > 0 else 0.0,
		"latency_max_msec": _latency_max_msec,
		"processing": is_processing()
	}, true)
	return receipt_snapshot


func _process(_delta: float) -> void:
	var now_msec: int = Time.get_ticks_msec()
	_receipts.expire(now_msec)
	var live_flashes: Array[Dictionary] = []
	for flash: Dictionary in _flashes:
		var age_seconds: float = float(now_msec - int(flash.get("started_at_msec", now_msec))) / 1000.0
		if age_seconds <= Config.SUCCESS_FLASH_DURATION_SECONDS:
			live_flashes.append(flash)
	_flashes = live_flashes
	_update_processing()
	queue_redraw()


func _update_processing() -> void:
	var receipt_snapshot: Dictionary = _receipts.snapshot()
	set_process(not _flashes.is_empty() or int(receipt_snapshot.get("live_receipt_count", 0)) > 0)


func _draw() -> void:
	var now_msec: int = Time.get_ticks_msec()
	for flash: Dictionary in _flashes:
		var elapsed: float = float(now_msec - int(flash.get("started_at_msec", now_msec))) / 1000.0
		var progress: float = clampf(elapsed / Config.SUCCESS_FLASH_DURATION_SECONDS, 0.0, 1.0)
		_draw_flash(flash, progress)


func _draw_flash(flash: Dictionary, progress: float) -> void:
	var color: Color = flash.get("color", Color.WHITE) as Color
	var strength: float = Config.SUCCESS_FLASH_STRENGTH * pow(1.0 - progress, 1.35)
	color.a = clampf(0.95 * strength, 0.0, 1.0)
	match str(flash.get("target_type", "")):
		"hive":
			_draw_hive_flash(int(flash.get("target_id", -1)), color, progress)
		"lane":
			_draw_lane_flash(int(flash.get("target_id", -1)), color, strength)
		"global":
			_draw_global_flash(color, strength)


func _draw_hive_flash(hive_id: int, color: Color, progress: float) -> void:
	var geometry: Dictionary = _hive_geometry(hive_id)
	if not bool(geometry.get("valid", false)):
		return
	var center: Vector2 = geometry.get("center", Vector2.ZERO) as Vector2
	var radius: float = float(geometry.get("radius", 1.0)) + Config.SUCCESS_HIVE_RING_PAD_LOCAL_PX + progress * 12.0
	draw_arc(center, radius + 3.0, 0.0, TAU, 96, Color(0.01, 0.02, 0.04, color.a * 0.72), Config.SUCCESS_HIVE_RING_WIDTH_LOCAL_PX + 6.0, true)
	draw_arc(center, radius, 0.0, TAU, 96, color, Config.SUCCESS_HIVE_RING_WIDTH_LOCAL_PX, true)


func _draw_lane_flash(lane_id: int, color: Color, strength: float) -> void:
	var points: PackedVector2Array = _lane_points(lane_id)
	if points.size() < 2:
		return
	draw_polyline(points, Color(0.01, 0.02, 0.04, 0.70 * strength), Config.SUCCESS_LANE_WIDTH_LOCAL_PX + 8.0, true)
	draw_polyline(points, color, Config.SUCCESS_LANE_WIDTH_LOCAL_PX, true)


func _draw_global_flash(color: Color, strength: float) -> void:
	var points: PackedVector2Array = _global_boundary_points()
	if points.size() < 4:
		return
	if points[0] != points[points.size() - 1]:
		points.append(points[0])
	draw_polyline(points, Color(0.01, 0.02, 0.04, 0.70 * strength), Config.SUCCESS_GLOBAL_WIDTH_LOCAL_PX + 7.0, true)
	draw_polyline(points, color, Config.SUCCESS_GLOBAL_WIDTH_LOCAL_PX, true)


func _target_has_current_probe(target_type: String, target_id: Variant) -> bool:
	match target_type:
		"hive":
			return bool(_hive_geometry(int(target_id)).get("valid", false))
		"lane":
			return _lane_points(int(target_id)).size() >= 2
		"global":
			return str(target_id) == "global" and _global_boundary_points().size() >= 4
	return false


func _hive_geometry(hive_id: int) -> Dictionary:
	if _hive_renderer == null or not is_instance_valid(_hive_renderer) or not _hive_renderer.has_method("get_buff_target_probe"):
		return {"valid": false}
	var probe_any: Variant = _hive_renderer.call("get_buff_target_probe", hive_id)
	if typeof(probe_any) != TYPE_DICTIONARY:
		return {"valid": false}
	var probe: Dictionary = probe_any as Dictionary
	if not bool(probe.get("ok", false)):
		return {"valid": false}
	var parent_2d: Node2D = get_parent() as Node2D
	if parent_2d == null:
		return {"valid": false}
	var center_arena: Vector2 = probe.get("center_arena_local", Vector2.ZERO) as Vector2
	var edge_arena: Vector2 = probe.get("radius_edge_arena_local", center_arena) as Vector2
	return {
		"valid": true,
		"center": to_local(parent_2d.to_global(center_arena)),
		"radius": to_local(parent_2d.to_global(edge_arena)).distance_to(to_local(parent_2d.to_global(center_arena)))
	}


func _lane_points(lane_id: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	if _lane_renderer == null or not is_instance_valid(_lane_renderer) or not _lane_renderer.has_method("get_buff_target_lane_probe"):
		return points
	var probe_any: Variant = _lane_renderer.call("get_buff_target_lane_probe", lane_id)
	if typeof(probe_any) != TYPE_DICTIONARY:
		return points
	var probe: Dictionary = probe_any as Dictionary
	if not bool(probe.get("valid", false)):
		return points
	var raw: PackedVector2Array = probe.get("points", PackedVector2Array()) as PackedVector2Array
	for point: Vector2 in raw:
		points.append(to_local(_lane_renderer.to_global(point)))
	return points


func _global_boundary_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if _arena == null or not _arena.has_method("get_buff_global_presentation_boundary"):
		return points
	var result_any: Variant = _arena.call("get_buff_global_presentation_boundary")
	if typeof(result_any) != TYPE_DICTIONARY:
		return points
	var result: Dictionary = result_any as Dictionary
	if not bool(result.get("valid", false)):
		return points
	var parent_2d: Node2D = get_parent() as Node2D
	if parent_2d == null:
		return points
	var arena_points: PackedVector2Array = result.get("boundary_arena_local_points", PackedVector2Array()) as PackedVector2Array
	for point: Vector2 in arena_points:
		points.append(to_local(parent_2d.to_global(point)))
	return points


func _owner_color(owner_id: int) -> Color:
	if _arena != null and _arena.has_method("get_buff_presentation_owner_color"):
		var color_any: Variant = _arena.call("get_buff_presentation_owner_color", owner_id)
		if color_any is Color:
			return color_any as Color
	return Color.WHITE
