class_name BuffLaneGlobalTargetingController
extends Node2D

signal selection_changed(pointer_session_id: int, target_type: String, target_id: Variant, reason: String)

const Config := preload("res://scripts/renderers/buff_targeting_presentation_config.gd")
const TARGET_LANE: String = "lane"
const TARGET_GLOBAL: String = "global"
const LANE_ACQUISITION_RADIUS_PX: float = Config.LANE_ACQUISITION_RADIUS_ROOT_SCREEN_PX
const LANE_RETENTION_RADIUS_PX: float = Config.LANE_RETENTION_RADIUS_ROOT_SCREEN_PX
const LANE_SWITCH_MARGIN_PX: float = Config.LANE_SWITCH_MARGIN_ROOT_SCREEN_PX
const DISTANCE_EPSILON_PX: float = 0.001
const TRAVEL_PERIOD_PX: float = Config.LANE_TRAVEL_PERIOD_LOCAL_PX
const TRAVEL_LENGTH_PX: float = Config.LANE_TRAVEL_LENGTH_LOCAL_PX

var _arena: Node = null
var _lane_renderer: Node2D = null
var _active: bool = false
var _pointer_session_id: int = 0
var _target_type: String = ""
var _eligible_lane_ids: Array[int] = []
var _selected_lane_id: int = -1
var _global_valid: bool = false
var _finger_root_screen_pos: Vector2 = Vector2.ZERO
var _lane_geometry_cache: Dictionary = {}
var _global_boundary_local: PackedVector2Array = PackedVector2Array()
var _last_transform_signature: Variant = null
var _last_renderer_generation: int = -1
var _phase_override: float = -1.0
var _pulse_phase: float = 0.0
var _movement_event_count: int = 0
var _geometry_rebuild_count: int = 0
var _geometry_rebuild_elapsed_us: int = 0
var _geometry_dirty: bool = false
var _geometry_revision: int = 0
var _last_drawn_geometry_revision: int = -1
var _last_transform_rebuild_frame: int = -1
var _coalesced_transform_invalidation_count: int = 0
var _max_transform_rebuilds_single_frame: int = 0


func _ready() -> void:
	z_as_relative = false
	z_index = 24
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		_reset_state(false, "controller_teardown")


func setup(arena_ref: Node, lane_renderer_ref: Node2D) -> void:
	_arena = arena_ref
	_lane_renderer = lane_renderer_ref
	_last_transform_signature = _transform_signature()
	_last_renderer_generation = _renderer_generation()


func begin_or_update(
	pointer_session_id: int,
	preview: Dictionary,
	selected_target_type: String,
	selected_target_id: Variant,
	finger_root_screen_pos: Vector2
) -> bool:
	if pointer_session_id <= 0 or not bool(preview.get("ok", false)):
		return false
	var requested_type: String = str(preview.get("target_type", "")).strip_edges()
	if requested_type != TARGET_LANE and requested_type != TARGET_GLOBAL:
		return false
	var replacing: bool = not _active or _pointer_session_id != pointer_session_id or _target_type != requested_type
	var eligible_geometry_changed: bool = false
	if replacing:
		_reset_state(false, "session_replaced")
		_active = true
		_pointer_session_id = pointer_session_id
		_target_type = requested_type
		set_process(true)
	_finger_root_screen_pos = finger_root_screen_pos
	var eligible: Array = preview.get("eligible_target_ids", []) as Array
	if requested_type == TARGET_LANE:
		var normalized: Array[int] = _normalized_lane_ids(eligible)
		if normalized != _eligible_lane_ids:
			_eligible_lane_ids = normalized
			_lane_geometry_cache.clear()
			eligible_geometry_changed = true
		if replacing and selected_target_type == TARGET_LANE and selected_target_id != null:
			var selected_id: int = int(selected_target_id)
			_selected_lane_id = selected_id if _eligible_lane_ids.has(selected_id) else -1
	else:
		_eligible_lane_ids.clear()
		_lane_geometry_cache.clear()
		_global_valid = selected_target_type == TARGET_GLOBAL and str(selected_target_id) == TARGET_GLOBAL
	var current_transform_signature: Variant = _transform_signature()
	var current_renderer_generation: int = _renderer_generation()
	if not replacing and requested_type == TARGET_LANE \
	and (current_transform_signature != _last_transform_signature or current_renderer_generation != _last_renderer_generation):
		_mark_transform_geometry_dirty("pointer_transform_changed")
		_flush_transform_geometry("pointer_transform_changed")
		return true
	_last_transform_signature = current_transform_signature
	_last_renderer_generation = current_renderer_generation
	_geometry_dirty = false
	_recompute_selection("pointer_update")
	if eligible_geometry_changed:
		_geometry_revision += 1
		_last_drawn_geometry_revision = -1
	return true


func update_finger(pointer_session_id: int, finger_root_screen_pos: Vector2) -> bool:
	if not _active or pointer_session_id != _pointer_session_id:
		return false
	_finger_root_screen_pos = finger_root_screen_pos
	_movement_event_count += 1
	if _transform_signature() != _last_transform_signature:
		_mark_transform_geometry_dirty("pointer_transform_changed")
		_flush_transform_geometry("pointer_transform_changed")
	if _geometry_dirty:
		return true
	_recompute_selection("pointer_moved")
	return true


func clear(pointer_session_id: int = -1, notify_shell: bool = true, reason: String = "cleared") -> bool:
	if not _active:
		return false
	if pointer_session_id >= 0 and pointer_session_id != _pointer_session_id:
		return false
	_reset_state(notify_shell, reason)
	return true


func notify_render_nodes_changed() -> void:
	_lane_geometry_cache.clear()
	_last_renderer_generation = _renderer_generation()
	if _active and _target_type == TARGET_LANE and not _geometry_dirty:
		_recompute_selection("lane_renderer_changed")
		_geometry_revision += 1


func force_recompute(reason: String = "forced") -> void:
	if not _active:
		return
	_mark_transform_geometry_dirty(reason)
	_flush_transform_geometry(reason)


func is_release_ready(pointer_session_id: int, target_type: String) -> bool:
	if not _active or pointer_session_id != _pointer_session_id or target_type != _target_type:
		return false
	if target_type != TARGET_LANE:
		return _global_valid
	if _transform_signature() != _last_transform_signature or _renderer_generation() != _last_renderer_generation:
		_mark_transform_geometry_dirty("release_transform_dirty")
		return false
	return not _geometry_dirty \
		and _selected_lane_id > 0 \
		and _last_drawn_geometry_revision == _geometry_revision


func set_phase_override(phase: float) -> void:
	_phase_override = clampf(phase, 0.0, 1.0)
	_pulse_phase = _phase_override
	queue_redraw()


func clear_phase_override() -> void:
	_phase_override = -1.0


func get_snapshot() -> Dictionary:
	return {
		"active": _active,
		"pointer_session_id": _pointer_session_id,
		"target_type": _target_type,
		"eligible_lane_ids": _eligible_lane_ids.duplicate(),
		"selected_lane_id": _selected_lane_id,
		"global_valid": _global_valid,
		"pulse_phase": _pulse_phase,
		"movement_event_count": _movement_event_count,
		"geometry_cache_size": _lane_geometry_cache.size(),
		"geometry_rebuild_count": _geometry_rebuild_count,
		"geometry_rebuild_elapsed_us": _geometry_rebuild_elapsed_us,
		"geometry_dirty": _geometry_dirty,
		"geometry_revision": _geometry_revision,
		"last_drawn_geometry_revision": _last_drawn_geometry_revision,
		"coalesced_transform_invalidation_count": _coalesced_transform_invalidation_count,
		"max_transform_rebuilds_single_frame": _max_transform_rebuilds_single_frame,
		"processing": is_processing()
	}


func get_visual_state_snapshot() -> Dictionary:
	var lanes: Dictionary = {}
	if _active and _target_type == TARGET_LANE and not _geometry_dirty:
		_ensure_lane_geometry_cache()
		for lane_id in _eligible_lane_ids:
			var cached_any: Variant = _lane_geometry_cache.get(lane_id, null)
			if typeof(cached_any) != TYPE_DICTIONARY:
				continue
			var cached: Dictionary = cached_any as Dictionary
			if not bool(cached.get("valid", false)):
				continue
			lanes[lane_id] = {
				"selected": lane_id == _selected_lane_id,
				"pulse_phase": _pulse_phase,
				"path_revision": int(cached.get("path_revision", 0)),
				"point_count": (cached.get("screen_points", PackedVector2Array()) as PackedVector2Array).size(),
				"eligible_width_px": Config.LANE_ELIGIBLE_WIDTH_LOCAL_PX,
				"selected_width_px": Config.LANE_PREVIEW_WIDTH_LOCAL_PX if lane_id == _selected_lane_id else Config.LANE_ELIGIBLE_WIDTH_LOCAL_PX
			}
	return {
		"target_type": _target_type,
		"lanes": lanes,
		"global_valid": _global_valid,
		"global_boundary_point_count": _global_boundary_local.size(),
		"pulse_phase": _pulse_phase
	}


func _process(_delta: float) -> void:
	_update_pulse_phase()
	var transform_signature: Variant = _transform_signature()
	var renderer_generation: int = _renderer_generation()
	if transform_signature != _last_transform_signature or renderer_generation != _last_renderer_generation:
		_mark_transform_geometry_dirty("presentation_transform_changed")
	_flush_transform_geometry("presentation_transform_changed")
	queue_redraw()


func _update_pulse_phase() -> void:
	if _phase_override >= 0.0:
		_pulse_phase = _phase_override
		return
	var seconds: float = float(Time.get_ticks_msec()) / 1000.0
	_pulse_phase = fposmod(seconds * Config.ELIGIBLE_PULSE_FREQUENCY_HZ, 1.0)


func _mark_transform_geometry_dirty(reason: String) -> void:
	if not _active or _target_type != TARGET_LANE:
		return
	if _geometry_dirty:
		_coalesced_transform_invalidation_count += 1
	else:
		_geometry_dirty = true
		_lane_geometry_cache.clear()
		_geometry_revision += 1
		_last_drawn_geometry_revision = -1
	_set_lane_selection(-1, reason)
	queue_redraw()


func _flush_transform_geometry(reason: String) -> bool:
	if not _geometry_dirty or not _active or _target_type != TARGET_LANE:
		return false
	var frame: int = Engine.get_process_frames()
	if _last_transform_rebuild_frame == frame:
		_coalesced_transform_invalidation_count += 1
		return false
	_last_transform_rebuild_frame = frame
	_max_transform_rebuilds_single_frame = maxi(_max_transform_rebuilds_single_frame, 1)
	_last_transform_signature = _transform_signature()
	_last_renderer_generation = _renderer_generation()
	_lane_geometry_cache.clear()
	_geometry_dirty = false
	_recompute_selection(reason)
	_geometry_revision += 1
	return true


func _recompute_selection(reason: String) -> void:
	if not _active:
		return
	if _target_type == TARGET_GLOBAL:
		_recompute_global(reason)
	else:
		_recompute_lane(reason)
	queue_redraw()


func _recompute_lane(reason: String) -> void:
	if _geometry_dirty:
		_set_lane_selection(-1, reason)
		return
	_global_valid = false
	_global_boundary_local = PackedVector2Array()
	_ensure_lane_geometry_cache()
	var distances: Dictionary = {}
	for lane_id in _eligible_lane_ids:
		var cached_any: Variant = _lane_geometry_cache.get(lane_id, null)
		if typeof(cached_any) != TYPE_DICTIONARY:
			continue
		var cached: Dictionary = cached_any as Dictionary
		if not bool(cached.get("valid", false)):
			continue
		distances[lane_id] = _distance_to_cached_path(_finger_root_screen_pos, cached)
	var next_selected: int = -1
	var selected_distance: float = float(distances.get(_selected_lane_id, INF))
	if _selected_lane_id > 0 and selected_distance <= LANE_RETENTION_RADIUS_PX + DISTANCE_EPSILON_PX:
		next_selected = _selected_lane_id
		var challenger: Dictionary = _nearest_lane(distances, _selected_lane_id, LANE_ACQUISITION_RADIUS_PX)
		if not challenger.is_empty():
			var challenger_distance: float = float(challenger.get("distance", INF))
			if challenger_distance + LANE_SWITCH_MARGIN_PX < selected_distance - DISTANCE_EPSILON_PX:
				next_selected = int(challenger.get("lane_id", -1))
	else:
		var nearest: Dictionary = _nearest_lane(distances, -1, LANE_ACQUISITION_RADIUS_PX)
		if not nearest.is_empty():
			next_selected = int(nearest.get("lane_id", -1))
	_set_lane_selection(next_selected, reason)


func _recompute_global(reason: String) -> void:
	_selected_lane_id = -1
	var query: Dictionary = {}
	if _arena != null and _arena.has_method("get_buff_global_targeting_query"):
		var query_any: Variant = _arena.call("get_buff_global_targeting_query", _finger_root_screen_pos)
		if typeof(query_any) == TYPE_DICTIONARY:
			query = query_any as Dictionary
	var valid: bool = bool(query.get("valid", false))
	var boundary_local := PackedVector2Array()
	if valid:
		var points_any: Variant = query.get("boundary_arena_local_points", PackedVector2Array())
		if points_any is PackedVector2Array:
			for arena_local_point in points_any as PackedVector2Array:
				boundary_local.append(_arena_local_to_controller_local(arena_local_point))
	_global_boundary_local = boundary_local
	if valid == _global_valid and ((_global_valid and _global_boundary_local.size() >= 4) or not _global_valid):
		queue_redraw()
		return
	_global_valid = valid
	emit_signal(
		"selection_changed",
		_pointer_session_id,
		TARGET_GLOBAL if valid else "",
		TARGET_GLOBAL if valid else null,
		reason
	)


func _ensure_lane_geometry_cache() -> void:
	var started_us: int = Time.get_ticks_usec()
	var rebuilt: bool = false
	var eligible_lookup: Dictionary = {}
	for lane_id in _eligible_lane_ids:
		eligible_lookup[lane_id] = true
		var existing_any: Variant = _lane_geometry_cache.get(lane_id, null)
		var current_revision: int = _lane_probe_revision(lane_id)
		if typeof(existing_any) == TYPE_DICTIONARY and current_revision >= 0:
			var existing: Dictionary = existing_any as Dictionary
			if int(existing.get("path_revision", -1)) == current_revision and existing.get("transform_signature", null) == _last_transform_signature:
				continue
		var probe: Dictionary = _lane_probe(lane_id)
		if not bool(probe.get("valid", false)):
			if _lane_geometry_cache.has(lane_id):
				_lane_geometry_cache.erase(lane_id)
				rebuilt = true
			continue
		var path_revision: int = int(probe.get("path_revision", 0))
		var transform_signature: Variant = _last_transform_signature
		if typeof(existing_any) == TYPE_DICTIONARY:
			var existing: Dictionary = existing_any as Dictionary
			if int(existing.get("path_revision", -1)) == path_revision and existing.get("transform_signature", null) == transform_signature:
				continue
		var built: Dictionary = _build_cached_geometry(lane_id, probe, transform_signature)
		if bool(built.get("valid", false)):
			_lane_geometry_cache[lane_id] = built
		else:
			_lane_geometry_cache.erase(lane_id)
		rebuilt = true
	for cached_id_any in _lane_geometry_cache.keys():
		if not eligible_lookup.has(int(cached_id_any)):
			_lane_geometry_cache.erase(cached_id_any)
			rebuilt = true
	if rebuilt:
		_geometry_rebuild_count += 1
		_geometry_rebuild_elapsed_us += Time.get_ticks_usec() - started_us


func _lane_probe(lane_id: int) -> Dictionary:
	if _lane_renderer == null or not is_instance_valid(_lane_renderer):
		return {"valid": false}
	if not _lane_renderer.has_method("get_buff_target_lane_probe"):
		return {"valid": false}
	var probe_any: Variant = _lane_renderer.call("get_buff_target_lane_probe", lane_id)
	return probe_any as Dictionary if typeof(probe_any) == TYPE_DICTIONARY else {"valid": false}


func _lane_probe_revision(lane_id: int) -> int:
	if _lane_renderer == null or not is_instance_valid(_lane_renderer):
		return -1
	if not _lane_renderer.has_method("get_buff_target_lane_probe_revision"):
		return -1
	return int(_lane_renderer.call("get_buff_target_lane_probe_revision", lane_id))


func _build_cached_geometry(lane_id: int, probe: Dictionary, transform_signature: Variant) -> Dictionary:
	var raw_points_any: Variant = probe.get("points", PackedVector2Array())
	if not (raw_points_any is PackedVector2Array):
		return {"valid": false}
	var raw_points: PackedVector2Array = raw_points_any as PackedVector2Array
	if raw_points.size() < 2:
		return {"valid": false}
	var screen_points := PackedVector2Array()
	var local_points := PackedVector2Array()
	var segment_bounds: Array[Rect2] = []
	for lane_local_point in raw_points:
		var arena_local: Vector2 = _lane_local_to_arena_local(lane_local_point)
		var projected: Dictionary = _project_arena_local_to_root(arena_local)
		if not bool(projected.get("ok", false)):
			return {"valid": false}
		screen_points.append(projected.get("root_screen_pos", Vector2.ZERO) as Vector2)
		local_points.append(_arena_local_to_controller_local(arena_local))
	for i in range(screen_points.size() - 1):
		var a: Vector2 = screen_points[i]
		var b: Vector2 = screen_points[i + 1]
		segment_bounds.append(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()))
	return {
		"valid": true,
		"lane_id": lane_id,
		"path_revision": int(probe.get("path_revision", 0)),
		"transform_signature": transform_signature,
		"screen_points": screen_points,
		"local_points": local_points,
		"segment_bounds": segment_bounds
	}


func _distance_to_cached_path(point: Vector2, cached: Dictionary) -> float:
	var points: PackedVector2Array = cached.get("screen_points", PackedVector2Array()) as PackedVector2Array
	var bounds: Array = cached.get("segment_bounds", []) as Array
	var best: float = INF
	for i in range(points.size() - 1):
		if i < bounds.size() and _distance_to_rect(point, bounds[i] as Rect2) > LANE_RETENTION_RADIUS_PX:
			continue
		best = minf(best, _distance_to_segment(point, points[i], points[i + 1]))
	return best


func _nearest_lane(distances: Dictionary, excluded_lane_id: int, radius: float) -> Dictionary:
	var best_id: int = -1
	var best_distance: float = INF
	for lane_id_any in distances.keys():
		var lane_id: int = int(lane_id_any)
		if lane_id == excluded_lane_id:
			continue
		var distance: float = float(distances.get(lane_id, INF))
		if distance > radius + DISTANCE_EPSILON_PX:
			continue
		if distance < best_distance - DISTANCE_EPSILON_PX or (absf(distance - best_distance) <= DISTANCE_EPSILON_PX and (best_id < 0 or lane_id < best_id)):
			best_id = lane_id
			best_distance = distance
	return {} if best_id < 0 else {"lane_id": best_id, "distance": best_distance}


func _set_lane_selection(lane_id: int, reason: String) -> void:
	if lane_id == _selected_lane_id:
		return
	_selected_lane_id = lane_id
	_geometry_revision += 1
	_last_drawn_geometry_revision = -1
	emit_signal(
		"selection_changed",
		_pointer_session_id,
		TARGET_LANE if lane_id > 0 else "",
		lane_id if lane_id > 0 else null,
		reason
	)


func _reset_state(notify_shell: bool, reason: String) -> void:
	var old_session_id: int = _pointer_session_id
	var had_selection: bool = _selected_lane_id > 0 or _global_valid
	_active = false
	_pointer_session_id = 0
	_target_type = ""
	_eligible_lane_ids.clear()
	_selected_lane_id = -1
	_global_valid = false
	_lane_geometry_cache.clear()
	_global_boundary_local = PackedVector2Array()
	_movement_event_count = 0
	_geometry_dirty = false
	_geometry_revision += 1
	_last_drawn_geometry_revision = -1
	set_process(false)
	queue_redraw()
	if notify_shell and old_session_id > 0 and had_selection:
		emit_signal("selection_changed", old_session_id, "", null, reason)


func _normalized_lane_ids(raw_ids: Array) -> Array[int]:
	var seen: Dictionary = {}
	var out: Array[int] = []
	for id_any in raw_ids:
		var lane_id: int = int(id_any)
		if lane_id <= 0 or seen.has(lane_id):
			continue
		seen[lane_id] = true
		out.append(lane_id)
	out.sort()
	return out


func _renderer_generation() -> int:
	if _lane_renderer != null and is_instance_valid(_lane_renderer) and _lane_renderer.has_method("get_buff_target_lane_generation"):
		return int(_lane_renderer.call("get_buff_target_lane_generation"))
	return 0


func _transform_signature() -> Variant:
	if _arena != null and _arena.has_method("get_buff_targeting_transform_signature"):
		return _arena.call("get_buff_targeting_transform_signature")
	return 0


func _lane_local_to_arena_local(lane_local: Vector2) -> Vector2:
	if _lane_renderer == null or not is_instance_valid(_lane_renderer):
		return lane_local
	var parent_2d: Node2D = get_parent() as Node2D
	if parent_2d == null:
		return lane_local
	return parent_2d.to_local(_lane_renderer.to_global(lane_local))


func _arena_local_to_controller_local(arena_local: Vector2) -> Vector2:
	var parent_2d: Node2D = get_parent() as Node2D
	if parent_2d == null:
		return arena_local
	return to_local(parent_2d.to_global(arena_local))


func _project_arena_local_to_root(arena_local: Vector2) -> Dictionary:
	if _arena == null or not _arena.has_method("buff_arena_local_to_root_screen"):
		return {"ok": false}
	var projected_any: Variant = _arena.call("buff_arena_local_to_root_screen", arena_local)
	return projected_any as Dictionary if typeof(projected_any) == TYPE_DICTIONARY else {"ok": false}


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var length_sq: float = ab.length_squared()
	if length_sq <= 0.000001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var closest := Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y)
	)
	return point.distance_to(closest)


func _draw() -> void:
	if not _active:
		return
	if _target_type == TARGET_GLOBAL:
		_draw_global_boundary()
		return
	if _geometry_dirty:
		return
	_ensure_lane_geometry_cache()
	for lane_id in _eligible_lane_ids:
		if lane_id == _selected_lane_id:
			continue
		_draw_lane_path(lane_id, false)
	if _selected_lane_id > 0:
		_draw_lane_path(_selected_lane_id, true)
	_last_drawn_geometry_revision = _geometry_revision


func _draw_lane_path(lane_id: int, selected: bool) -> void:
	var cached_any: Variant = _lane_geometry_cache.get(lane_id, null)
	if typeof(cached_any) != TYPE_DICTIONARY:
		return
	var points: PackedVector2Array = (cached_any as Dictionary).get("local_points", PackedVector2Array()) as PackedVector2Array
	if points.size() < 2:
		return
	var pulse: float = 0.5 - 0.5 * cos(_pulse_phase * TAU)
	var base_alpha: float = lerpf(Config.ELIGIBLE_PULSE_ALPHA_MIN, Config.ELIGIBLE_PULSE_ALPHA_MAX, pulse)
	var width: float = Config.LANE_ELIGIBLE_WIDTH_LOCAL_PX
	if selected:
		draw_polyline(points, Color(0.01, 0.03, 0.06, 0.72), Config.LANE_PREVIEW_BACKDROP_WIDTH_LOCAL_PX, true)
		draw_polyline(points, Color(1.0, 1.0, 1.0, Config.PREVIEW_PULSE_STRENGTH), Config.LANE_PREVIEW_WIDTH_LOCAL_PX, true)
		width = Config.LANE_ELIGIBLE_WIDTH_LOCAL_PX + 1.0
	else:
		draw_polyline(points, Color(1.0, 1.0, 1.0, base_alpha), width, true)
	_draw_traveling_path(points, Color(1.0, 1.0, 1.0, 1.0 if selected else 0.78), width, _pulse_phase)


func _draw_global_boundary() -> void:
	if not _global_valid or _global_boundary_local.size() < 4:
		return
	var closed: PackedVector2Array = _global_boundary_local.duplicate()
	if closed[0] != closed[closed.size() - 1]:
		closed.append(closed[0])
	var pulse: float = 0.5 - 0.5 * cos(_pulse_phase * TAU)
	draw_polyline(closed, Color(1.0, 1.0, 1.0, lerpf(Config.ELIGIBLE_PULSE_ALPHA_MIN, Config.ELIGIBLE_PULSE_ALPHA_MAX, pulse)), Config.GLOBAL_BOUNDARY_WIDTH_LOCAL_PX, true)
	_draw_traveling_path(closed, Color(1.0, 1.0, 1.0, 0.88), 3.0, _pulse_phase)


func _draw_traveling_path(points: PackedVector2Array, color: Color, width: float, phase: float) -> void:
	var accumulated: float = 0.0
	var travel_offset: float = phase * TRAVEL_PERIOD_PX
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var segment: Vector2 = b - a
		var length: float = segment.length()
		if length <= 0.001:
			continue
		var direction: Vector2 = segment / length
		var first_start: float = fposmod(travel_offset - accumulated, TRAVEL_PERIOD_PX) - TRAVEL_PERIOD_PX
		var start: float = first_start
		while start < length:
			var clipped_start: float = maxf(0.0, start)
			var clipped_end: float = minf(length, start + TRAVEL_LENGTH_PX)
			if clipped_end > clipped_start:
				draw_line(a + direction * clipped_start, a + direction * clipped_end, color, width, true)
			start += TRAVEL_PERIOD_PX
		accumulated += length
