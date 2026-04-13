extends Node2D
class_name HoneyDrip

signal finished(drip: HoneyDrip)

enum DripPhase {
	FORM,
	DROP_TO_SURFACE,
	POOL,
	DRIP_OFF_SIDE,
	FALL
}

@export var form_duration: float = 0.48
@export var drop_duration: float = 0.26
@export var pool_duration: float = 0.78
@export var drip_off_duration: float = 1.05
@export var lifetime: float = 5.4
@export var gravity: float = 1180.0
@export var release_speed_y: float = 22.0
@export var fall_sway_amplitude: float = 8.0
@export var fall_sway_frequency: float = 5.0
@export var fall_morph_duration: float = 0.34
@export var fade_start_ratio: float = 0.91
@export var base_radius: float = 15.0
@export var ribbon_width: float = 12.0

var _active: bool = false
var _phase: int = DripPhase.FORM
var _elapsed: float = 0.0
var _phase_elapsed: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _sway_phase: float = 0.0
var _drop_variation: float = 0.0
var _release_drift: float = 0.0
var _viewport_bottom: float = 0.0

var _source_anchor: Vector2 = Vector2.ZERO
var _spawn_position: Vector2 = Vector2.ZERO
var _surface_point: Vector2 = Vector2.ZERO
var _pool_center: Vector2 = Vector2.ZERO
var _spill_point: Vector2 = Vector2.ZERO
var _phase_start_position: Vector2 = Vector2.ZERO
var _surface_width: float = 24.0
var _digit_local_center: Vector2 = Vector2.ZERO
var _digit_size: Vector2 = Vector2(20.0, 32.0)
var _fall_anchor_global: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = false
	set_process(false)

func reset(path: Dictionary) -> void:
	var fallback: Vector2 = path.get("spawn", Vector2.ZERO)
	_spawn_position = fallback
	_source_anchor = path.get("anchor", fallback)
	_surface_point = path.get("surface", fallback + Vector2(0.0, 18.0))
	_pool_center = path.get("pool", _surface_point)
	_spill_point = path.get("spill", _pool_center + Vector2(10.0, 18.0))
	_viewport_bottom = float(path.get("viewport_bottom", get_viewport_rect().size.y + 84.0))
	_surface_width = maxf(18.0, float(path.get("surface_width", 24.0)))
	var digit_center: Vector2 = path.get("digit_center", _pool_center)
	_digit_local_center = digit_center - _pool_center
	_digit_size = path.get("digit_size", Vector2(20.0, 32.0))
	_fall_anchor_global = _pool_center
	_phase_start_position = _spawn_position
	global_position = _spawn_position
	_active = true
	_phase = DripPhase.FORM
	_elapsed = 0.0
	_phase_elapsed = 0.0
	_velocity = Vector2.ZERO
	_sway_phase = randf_range(0.0, TAU)
	_drop_variation = randf_range(-0.08, 0.08)
	_release_drift = randf_range(-9.0, 9.0)
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_phase_elapsed += delta

	match _phase:
		DripPhase.FORM:
			_process_form()
		DripPhase.DROP_TO_SURFACE:
			_process_drop_to_surface()
		DripPhase.POOL:
			_process_pool()
		DripPhase.DRIP_OFF_SIDE:
			_process_drip_off_side()
		DripPhase.FALL:
			_process_fall(delta)

	var fade_start: float = lifetime * clampf(fade_start_ratio, 0.1, 0.98)
	if _elapsed >= fade_start:
		var fade_t: float = clampf((_elapsed - fade_start) / maxf(0.001, lifetime - fade_start), 0.0, 1.0)
		modulate.a = 1.0 - fade_t

	if _elapsed >= lifetime or global_position.y >= _viewport_bottom:
		_finish()
		return

	queue_redraw()

func _process_form() -> void:
	var t: float = clampf(_phase_elapsed / maxf(0.001, form_duration), 0.0, 1.0)
	var eased: float = _ease_in_out_cubic(t)
	var hang_distance: float = lerpf(2.0, maxf(24.0, (_surface_point.y - _source_anchor.y) * 0.40), eased)
	global_position = _source_anchor + Vector2(_drop_variation, hang_distance)
	if t >= 1.0:
		_begin_phase(DripPhase.DROP_TO_SURFACE)

func _process_drop_to_surface() -> void:
	var t: float = clampf(_phase_elapsed / maxf(0.001, drop_duration), 0.0, 1.0)
	var eased: float = _ease_in_cubic(t)
	var from: Vector2 = _phase_start_position
	var c1: Vector2 = from + Vector2(0.0, 16.0)
	var c2: Vector2 = _surface_point + Vector2(0.0, -12.0)
	global_position = _sample_bezier(from, c1, c2, _surface_point, eased)
	if t >= 1.0:
		global_position = _pool_center
		_begin_phase(DripPhase.POOL)

func _process_pool() -> void:
	global_position = _pool_center
	if _phase_elapsed >= pool_duration:
		_begin_phase(DripPhase.DRIP_OFF_SIDE)

func _process_drip_off_side() -> void:
	global_position = _pool_center
	if _phase_elapsed >= drip_off_duration:
		var spill_geom: Dictionary = _sample_spill_geometry(1.0)
		_fall_anchor_global = _pool_center + (spill_geom.get("pull_anchor", Vector2.ZERO) as Vector2)
		global_position = _pool_center + (spill_geom.get("drip_tip", Vector2.ZERO) as Vector2)
		_begin_phase(DripPhase.FALL)
		_velocity = Vector2(_release_drift, release_speed_y)

func _process_fall(delta: float) -> void:
	_velocity.y += gravity * delta
	var sway_velocity: float = cos((_elapsed * fall_sway_frequency) + _sway_phase) * fall_sway_amplitude
	global_position.x += (_velocity.x + sway_velocity) * delta
	global_position.y += _velocity.y * delta

func _begin_phase(next_phase: int) -> void:
	_phase = next_phase
	_phase_elapsed = 0.0
	_phase_start_position = global_position

func _finish() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	visible = false
	finished.emit(self)

func _draw() -> void:
	var body_color: Color = Color(0.96, 0.61, 0.14, 0.96)
	var edge_color: Color = Color(0.36, 0.14, 0.01, 0.92)
	var core_color: Color = Color(1.0, 0.82, 0.28, 0.92)
	var highlight_color: Color = Color(1.0, 0.95, 0.76, 0.86)
	var shadow_color: Color = Color(0.28, 0.10, 0.01, 0.16)

	match _phase:
		DripPhase.FORM, DripPhase.DROP_TO_SURFACE:
			var air_size: Vector2 = _sample_air_drop_size()
			_draw_drop_body(Vector2.ZERO, air_size, body_color, edge_color, core_color, highlight_color, shadow_color)
			var top_tip: Vector2 = Vector2(0.0, -(base_radius * air_size.y) * 1.22)
			_draw_ribbon(_source_anchor - global_position, top_tip, ribbon_width * air_size.x, body_color, edge_color)
		DripPhase.POOL:
			var pool_progress: float = clampf(_phase_elapsed / maxf(0.001, pool_duration), 0.0, 1.0)
			_draw_pool_shape(pool_progress, body_color, edge_color, core_color, highlight_color, shadow_color)
		DripPhase.DRIP_OFF_SIDE:
			var spill_progress: float = clampf(_phase_elapsed / maxf(0.001, drip_off_duration), 0.0, 1.0)
			_draw_pool_spill_shape(spill_progress, body_color, edge_color, core_color, highlight_color, shadow_color)
		DripPhase.FALL:
			var release_blend: float = clampf(_phase_elapsed / maxf(0.001, fall_morph_duration), 0.0, 1.0)
			var fall_size: Vector2 = _sample_fall_drop_size(release_blend)
			var pull_progress: float = clampf(_phase_elapsed / 0.52, 0.0, 1.0)
			var drop_top_local: Vector2 = Vector2(0.0, -(base_radius * fall_size.y) * 1.02)
			_draw_fall_pull(_fall_anchor_global - global_position, drop_top_local, pull_progress, body_color, edge_color, core_color, highlight_color, shadow_color)
			_draw_drop_body(Vector2.ZERO, fall_size, body_color, edge_color, core_color, highlight_color, shadow_color)

func _sample_air_drop_size() -> Vector2:
	match _phase:
		DripPhase.FORM:
			var t: float = clampf(_phase_elapsed / maxf(0.001, form_duration), 0.0, 1.0)
			return Vector2(lerpf(0.70, 0.96, t), lerpf(0.34, 1.42, t))
		DripPhase.DROP_TO_SURFACE:
			var drop_t: float = clampf(_phase_elapsed / maxf(0.001, drop_duration), 0.0, 1.0)
			return Vector2(lerpf(0.96, 0.90, drop_t), lerpf(1.42, 1.18, drop_t))
	return Vector2.ONE

func _sample_fall_drop_size(release_blend: float = 1.0) -> Vector2:
	var fall_speed: float = clampf(_velocity.y / 1100.0, 0.0, 1.0)
	var base_size: Vector2 = Vector2(lerpf(0.90, 0.76, fall_speed), lerpf(1.22, 1.62, fall_speed))
	var intro_size: Vector2 = Vector2(0.62, 1.46)
	return Vector2(
		lerpf(intro_size.x, base_size.x, release_blend),
		lerpf(intro_size.y, base_size.y, release_blend)
	)

func _draw_drop_body(center: Vector2, size_state: Vector2, body_color: Color, edge_color: Color, core_color: Color, highlight_color: Color, shadow_color: Color) -> void:
	var radius_x: float = base_radius * size_state.x
	var radius_y: float = base_radius * size_state.y
	var body_points: PackedVector2Array = _offset_polygon(_build_drop_polygon(radius_x, radius_y), center)
	var shadow_points: PackedVector2Array = _offset_polygon(body_points, Vector2(1.2, 2.3))
	draw_colored_polygon(shadow_points, shadow_color)
	draw_colored_polygon(body_points, body_color)
	var outline: PackedVector2Array = body_points.duplicate()
	outline.append(body_points[0])
	draw_polyline(outline, edge_color, 2.1, true)
	var core_points: PackedVector2Array = _offset_polygon(_scaled_polygon(_build_drop_polygon(radius_x, radius_y), Vector2(0.62, 0.58), Vector2(0.0, radius_y * 0.14)), center)
	draw_colored_polygon(core_points, core_color)
	draw_circle(center + Vector2(-radius_x * 0.18, -radius_y * 0.34), maxf(2.2, base_radius * 0.30), highlight_color)
	draw_circle(center + Vector2(radius_x * 0.12, -radius_y * 0.56), maxf(1.4, base_radius * 0.16), Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.52))

func _draw_pool_shape(pool_progress: float, body_color: Color, edge_color: Color, core_color: Color, highlight_color: Color, shadow_color: Color) -> void:
	var eased: float = _ease_in_out_cubic(pool_progress)
	var left_radius_x: float = lerpf(base_radius * 0.18, maxf(base_radius * 0.28, _surface_width * 0.10), eased)
	var right_radius_x: float = lerpf(base_radius * 0.46, maxf(base_radius * 0.92, _surface_width * 0.42), eased)
	var pool_radius_y: float = lerpf(base_radius * 0.82, base_radius * 0.38, eased)
	var pool_center: Vector2 = Vector2(right_radius_x * 0.06, 0.0)
	_draw_digit_wrap(eased, false, body_color, edge_color, core_color, highlight_color, shadow_color)
	_draw_pool_base(pool_center, left_radius_x, right_radius_x, pool_radius_y, body_color, edge_color, core_color, highlight_color, shadow_color)
	var mound_size: Vector2 = Vector2(lerpf(0.82, 0.60, eased), lerpf(1.10, 0.86, eased))
	_draw_drop_body(pool_center + Vector2(left_radius_x * 0.10, -pool_radius_y * 0.52), mound_size, Color(body_color.r, body_color.g, body_color.b, 0.94), edge_color, core_color, highlight_color, Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_color.a * 0.55))

func _draw_pool_spill_shape(spill_progress: float, body_color: Color, edge_color: Color, core_color: Color, highlight_color: Color, shadow_color: Color) -> void:
	var spill_geom: Dictionary = _sample_spill_geometry(spill_progress)
	var eased: float = float(spill_geom.get("eased", 0.0))
	var left_radius_x: float = float(spill_geom.get("left_radius_x", base_radius * 0.24))
	var right_radius_x: float = float(spill_geom.get("right_radius_x", base_radius * 0.92))
	var pool_radius_y: float = float(spill_geom.get("pool_radius_y", base_radius * 0.30))
	var pool_offset: Vector2 = spill_geom.get("pool_offset", Vector2.ZERO)
	var lip_origin: Vector2 = spill_geom.get("lip_origin", Vector2.ZERO)
	var drip_tip: Vector2 = spill_geom.get("drip_tip", Vector2.ZERO)
	_draw_digit_wrap(eased, true, body_color, edge_color, core_color, highlight_color, shadow_color)
	_draw_pool_base(pool_offset, left_radius_x, right_radius_x, pool_radius_y, body_color, edge_color, core_color, highlight_color, shadow_color)
	_draw_connected_flow(lip_origin, drip_tip, eased, true, body_color, edge_color, core_color, highlight_color, shadow_color)

func _sample_spill_geometry(spill_progress: float) -> Dictionary:
	var eased: float = _ease_in_out_cubic(spill_progress)
	var left_radius_x: float = lerpf(maxf(base_radius * 0.28, _surface_width * 0.10), maxf(base_radius * 0.20, _surface_width * 0.08), eased)
	var right_radius_x: float = lerpf(maxf(base_radius * 0.92, _surface_width * 0.42), maxf(base_radius * 1.14, _surface_width * 0.54), eased)
	var pool_radius_y: float = lerpf(base_radius * 0.38, base_radius * 0.30, eased)
	var pool_offset: Vector2 = Vector2(lerpf(right_radius_x * 0.06, right_radius_x * 0.18, eased), lerpf(0.0, base_radius * 0.04, eased))
	var spill_target: Vector2 = (_spill_point - _pool_center) - pool_offset
	var lip_origin: Vector2 = pool_offset + Vector2(right_radius_x * 0.34, pool_radius_y * 0.04)
	var downward_progress: float = eased
	var outward_progress: float = pow(eased, 1.85)
	var pull_depth: float = lerpf(0.0, maxf(base_radius * 1.05, _digit_size.y * 0.34), eased)
	var drip_tip: Vector2 = Vector2(
		lerpf(lip_origin.x + 1.0, spill_target.x, outward_progress),
		lerpf(lip_origin.y + 1.0, spill_target.y + pull_depth, downward_progress)
	)
	return {
		"eased": eased,
		"left_radius_x": left_radius_x,
		"right_radius_x": right_radius_x,
		"pool_radius_y": pool_radius_y,
		"pool_offset": pool_offset,
		"lip_origin": lip_origin,
		"pull_anchor": lip_origin + Vector2(-right_radius_x * 0.08, -pool_radius_y * 0.02),
		"drip_tip": drip_tip,
	}

func _draw_stream_end(center: Vector2, progress: float, body_color: Color, edge_color: Color, core_color: Color, highlight_color: Color, shadow_color: Color) -> void:
	var width: float = lerpf(base_radius * 0.20, base_radius * 0.34, progress)
	var height: float = lerpf(base_radius * 0.78, base_radius * 1.08, progress)
	var shadow_points: PackedVector2Array = _build_ellipse_polygon(center + Vector2(1.0, 1.8), Vector2(width, height), 18)
	draw_colored_polygon(shadow_points, Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_color.a * 0.90))
	var body_points: PackedVector2Array = _build_ellipse_polygon(center, Vector2(width, height), 20)
	draw_colored_polygon(body_points, body_color)
	var outline: PackedVector2Array = body_points.duplicate()
	outline.append(body_points[0])
	draw_polyline(outline, Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.78), 1.3, true)
	var core_points: PackedVector2Array = _build_ellipse_polygon(center + Vector2(0.0, height * 0.08), Vector2(width * 0.58, height * 0.54), 16)
	draw_colored_polygon(core_points, Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.84))
	draw_circle(center + Vector2(-width * 0.20, -height * 0.34), maxf(1.4, width * 0.24), Color(highlight_color.r, highlight_color.g, highlight_color.b, highlight_color.a * 0.88))

func _draw_connected_flow(anchor: Vector2, tip: Vector2, progress: float, draw_tip_blob: bool, body_color: Color, edge_color: Color, core_color: Color, highlight_color: Color, shadow_color: Color) -> void:
	var eased: float = _ease_in_out_cubic(progress)
	var width_scale: float = lerpf(1.08, 0.82, eased)
	_draw_ribbon(anchor, tip, ribbon_width * 0.34 * width_scale, body_color, Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.86))
	var shoulder_center: Vector2 = anchor.lerp(tip, 0.30)
	var shoulder_rx: float = lerpf(base_radius * 0.24, base_radius * 0.16, eased)
	var shoulder_ry: float = lerpf(base_radius * 0.32, base_radius * 0.22, eased)
	var shoulder_shadow: PackedVector2Array = _build_ellipse_polygon(shoulder_center + Vector2(0.9, 1.5), Vector2(shoulder_rx, shoulder_ry), 14)
	draw_colored_polygon(shoulder_shadow, Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_color.a * 0.84))
	var shoulder_points: PackedVector2Array = _build_ellipse_polygon(shoulder_center, Vector2(shoulder_rx, shoulder_ry), 16)
	draw_colored_polygon(shoulder_points, Color(body_color.r, body_color.g, body_color.b, body_color.a * 0.95))
	var shoulder_outline: PackedVector2Array = shoulder_points.duplicate()
	shoulder_outline.append(shoulder_points[0])
	draw_polyline(shoulder_outline, Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.72), 1.0, true)
	if draw_tip_blob:
		_draw_stream_end(tip, progress, body_color, edge_color, core_color, highlight_color, shadow_color)

func _draw_fall_pull(anchor_local: Vector2, drop_top_local: Vector2, progress: float, body_color: Color, edge_color: Color, core_color: Color, highlight_color: Color, shadow_color: Color) -> void:
	var eased: float = _ease_in_out_cubic(progress)
	var residue_center: Vector2 = anchor_local + Vector2(lerpf(0.0, 1.6, eased), lerpf(0.0, base_radius * 0.42, eased))
	var residue_rx: float = lerpf(base_radius * 0.34, base_radius * 0.20, eased)
	var residue_ry: float = lerpf(base_radius * 0.24, base_radius * 0.14, eased)
	var shadow_points: PackedVector2Array = _build_ellipse_polygon(residue_center + Vector2(0.9, 1.6), Vector2(residue_rx, residue_ry), 14)
	draw_colored_polygon(shadow_points, Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_color.a * 0.82))
	var residue_points: PackedVector2Array = _build_ellipse_polygon(residue_center, Vector2(residue_rx, residue_ry), 16)
	draw_colored_polygon(residue_points, Color(body_color.r, body_color.g, body_color.b, body_color.a * 0.94))
	var residue_outline: PackedVector2Array = residue_points.duplicate()
	residue_outline.append(residue_points[0])
	draw_polyline(residue_outline, Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.72), 1.1, true)
	var residue_core: PackedVector2Array = _build_ellipse_polygon(residue_center + Vector2(residue_rx * 0.08, -residue_ry * 0.08), Vector2(residue_rx * 0.54, residue_ry * 0.50), 12)
	draw_colored_polygon(residue_core, Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.74))
	draw_circle(residue_center + Vector2(-residue_rx * 0.18, -residue_ry * 0.18), maxf(1.0, residue_ry * 0.46), Color(highlight_color.r, highlight_color.g, highlight_color.b, highlight_color.a * 0.72))
	var stream_start: Vector2 = residue_center + Vector2(residue_rx * 0.26, residue_ry * 0.10)
	_draw_connected_flow(stream_start, drop_top_local, progress, false, body_color, edge_color, core_color, highlight_color, shadow_color)

func _draw_digit_wrap(progress: float, spilling: bool, body_color: Color, edge_color: Color, core_color: Color, highlight_color: Color, shadow_color: Color) -> void:
	if _digit_size.x <= 1.0 or _digit_size.y <= 1.0:
		return
	var wrap_center: Vector2 = _digit_local_center + Vector2(
		lerpf(_digit_size.x * 0.04, _digit_size.x * 0.10, progress),
		lerpf(-_digit_size.y * 0.10, -_digit_size.y * 0.04, progress)
	)
	var outer_radius: Vector2 = Vector2(
		maxf(base_radius * 0.72, _digit_size.x * (0.42 if not spilling else 0.46)),
		maxf(base_radius * 0.90, _digit_size.y * (0.44 if not spilling else 0.48))
	)
	var thickness: Vector2 = Vector2(
		maxf(3.4, _digit_size.x * 0.12),
		maxf(4.8, _digit_size.y * 0.14)
	)
	var inner_radius: Vector2 = Vector2(
		maxf(outer_radius.x - thickness.x, 2.0),
		maxf(outer_radius.y - thickness.y, 2.0)
	)
	var start_deg: float = lerpf(235.0, 246.0, progress)
	var end_deg: float = lerpf(112.0, 138.0, progress) if spilling else lerpf(98.0, 116.0, progress)
	var shadow_points: PackedVector2Array = _build_elliptical_band_polygon(wrap_center + Vector2(1.0, 2.0), outer_radius, inner_radius, start_deg, end_deg, 28)
	draw_colored_polygon(shadow_points, Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_color.a * 0.95))
	var band_points: PackedVector2Array = _build_elliptical_band_polygon(wrap_center, outer_radius, inner_radius, start_deg, end_deg, 32)
	draw_colored_polygon(band_points, Color(body_color.r, body_color.g, body_color.b, body_color.a * 0.96))
	var outline: PackedVector2Array = band_points.duplicate()
	outline.append(band_points[0])
	draw_polyline(outline, Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.82), 1.4, true)
	var inner_gloss_radius: Vector2 = Vector2(maxf(inner_radius.x - thickness.x * 0.26, 1.0), maxf(inner_radius.y - thickness.y * 0.20, 1.0))
	var gloss_points: PackedVector2Array = _build_elliptical_band_polygon(
		wrap_center + Vector2(_digit_size.x * 0.05, -_digit_size.y * 0.04),
		Vector2(outer_radius.x * 0.86, outer_radius.y * 0.84),
		inner_gloss_radius,
		start_deg + 6.0,
		end_deg - 10.0,
		26
	)
	draw_colored_polygon(gloss_points, Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.82))
	draw_circle(
		wrap_center + Vector2(outer_radius.x * 0.34, -outer_radius.y * 0.56),
		maxf(1.8, thickness.y * 0.34),
		Color(highlight_color.r, highlight_color.g, highlight_color.b, highlight_color.a * 0.92)
	)

func _draw_pool_base(center: Vector2, left_radius_x: float, right_radius_x: float, radius_y: float, body_color: Color, edge_color: Color, core_color: Color, highlight_color: Color, shadow_color: Color) -> void:
	var shadow_points: PackedVector2Array = _build_asymmetric_pool_polygon(center + Vector2(1.2, 2.0), left_radius_x, right_radius_x, radius_y, 28)
	draw_colored_polygon(shadow_points, shadow_color)
	var body_points: PackedVector2Array = _build_asymmetric_pool_polygon(center, left_radius_x, right_radius_x, radius_y, 30)
	draw_colored_polygon(body_points, body_color)
	var outline: PackedVector2Array = body_points.duplicate()
	outline.append(body_points[0])
	draw_polyline(outline, edge_color, 1.8, true)
	var core_points: PackedVector2Array = _build_asymmetric_pool_polygon(
		center + Vector2(right_radius_x * 0.06, -radius_y * 0.10),
		left_radius_x * 0.42,
		right_radius_x * 0.58,
		radius_y * 0.60,
		24
	)
	draw_colored_polygon(core_points, core_color)
	draw_circle(center + Vector2(right_radius_x * 0.10, -radius_y * 0.12), maxf(2.2, radius_y * 0.74), highlight_color)
	draw_circle(center + Vector2(right_radius_x * 0.28, -radius_y * 0.18), maxf(1.4, radius_y * 0.44), Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.50))

func _draw_ribbon(anchor: Vector2, drop_top: Vector2, width: float, fill_color: Color, edge_color: Color) -> void:
	var segment: Vector2 = drop_top - anchor
	if segment.length() < 2.0:
		return
	var dir: Vector2 = segment.normalized()
	var normal: Vector2 = Vector2(-dir.y, dir.x)
	var start_width: float = maxf(1.8, width * 0.44)
	var end_width: float = maxf(1.2, width * 0.18)
	var ribbon_points: PackedVector2Array = PackedVector2Array([
		anchor - (normal * start_width),
		anchor + (normal * start_width),
		drop_top + (normal * end_width),
		drop_top - (normal * end_width),
	])
	draw_colored_polygon(ribbon_points, Color(fill_color.r, fill_color.g, fill_color.b, fill_color.a * 0.94))
	var outline: PackedVector2Array = ribbon_points.duplicate()
	outline.append(ribbon_points[0])
	draw_polyline(outline, Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.42), 1.2, true)
	draw_circle(anchor, start_width, Color(fill_color.r, fill_color.g, fill_color.b, fill_color.a * 0.96))

func _build_drop_polygon(radius_x: float, radius_y: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -radius_y * 1.34),
		Vector2(-radius_x * 0.24, -radius_y * 1.05),
		Vector2(-radius_x * 0.56, -radius_y * 0.70),
		Vector2(-radius_x * 0.82, -radius_y * 0.08),
		Vector2(-radius_x * 0.92, radius_y * 0.34),
		Vector2(-radius_x * 0.70, radius_y * 0.90),
		Vector2(-radius_x * 0.28, radius_y * 1.30),
		Vector2(0.0, radius_y * 1.44),
		Vector2(radius_x * 0.28, radius_y * 1.30),
		Vector2(radius_x * 0.70, radius_y * 0.90),
		Vector2(radius_x * 0.92, radius_y * 0.34),
		Vector2(radius_x * 0.82, -radius_y * 0.08),
		Vector2(radius_x * 0.56, -radius_y * 0.70),
		Vector2(radius_x * 0.24, -radius_y * 1.05),
	])

func _build_ellipse_polygon(center: Vector2, radius: Vector2, points_count: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var safe_count: int = maxi(12, points_count)
	for idx in range(safe_count):
		var angle: float = (TAU * float(idx)) / float(safe_count)
		out.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return out

func _build_asymmetric_pool_polygon(center: Vector2, left_radius_x: float, right_radius_x: float, radius_y: float, points_count: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var safe_count: int = maxi(16, points_count)
	for idx in range(safe_count):
		var angle: float = (TAU * float(idx)) / float(safe_count)
		var unit_x: float = cos(angle)
		var radius_x: float = right_radius_x if unit_x >= 0.0 else left_radius_x
		var skew: float = 1.0 - (abs(sin(angle)) * 0.12)
		out.append(center + Vector2(unit_x * radius_x * skew, sin(angle) * radius_y))
	return out

func _build_elliptical_band_polygon(center: Vector2, outer_radius: Vector2, inner_radius: Vector2, start_deg: float, end_deg: float, points_count: int) -> PackedVector2Array:
	var outer_points: PackedVector2Array = _build_elliptical_arc_points(center, outer_radius, start_deg, end_deg, points_count)
	var inner_points: PackedVector2Array = _build_elliptical_arc_points(center, inner_radius, start_deg, end_deg, points_count)
	var out: PackedVector2Array = PackedVector2Array()
	for point in outer_points:
		out.append(point)
	for idx in range(inner_points.size() - 1, -1, -1):
		out.append(inner_points[idx])
	return out

func _build_elliptical_arc_points(center: Vector2, radius: Vector2, start_deg: float, end_deg: float, points_count: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var safe_count: int = maxi(8, points_count)
	var start_rad: float = deg_to_rad(start_deg)
	var end_rad: float = deg_to_rad(end_deg)
	if end_rad < start_rad:
		end_rad += TAU
	for idx in range(safe_count + 1):
		var t: float = float(idx) / float(safe_count)
		var angle: float = lerpf(start_rad, end_rad, t)
		out.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return out

func _scaled_polygon(points: PackedVector2Array, scale_vec: Vector2, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for point in points:
		out.append(Vector2(point.x * scale_vec.x, point.y * scale_vec.y) + offset)
	return out

func _offset_polygon(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for point in points:
		out.append(point + offset)
	return out

func _sample_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var omt: float = 1.0 - t
	return (
		(p0 * (omt * omt * omt)) +
		(p1 * (3.0 * omt * omt * t)) +
		(p2 * (3.0 * omt * t * t)) +
		(p3 * (t * t * t))
	)

func _ease_in_cubic(t: float) -> float:
	return t * t * t

func _ease_in_out_cubic(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	var inv: float = -2.0 * t + 2.0
	return 1.0 - ((inv * inv * inv) * 0.5)
