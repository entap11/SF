class_name ProgressiveStarDecayHud
extends Control

const STAR_COUNT: int = 4
const STAR_POINTS: int = 10

var thresholds_ms: Dictionary = {}
var elapsed_ms: int = 0


static func decay_fractions_for_elapsed(elapsed_ms_in: int, thresholds_ms_in: Dictionary) -> Array[float]:
	var elapsed: int = maxi(0, elapsed_ms_in)
	var four_star_ms: int = maxi(1, int(thresholds_ms_in.get("four_star_ms", 0)))
	var three_star_ms: int = maxi(four_star_ms + 1, int(thresholds_ms_in.get("three_star_ms", 0)))
	var two_star_ms: int = maxi(three_star_ms + 1, int(thresholds_ms_in.get("two_star_ms", 0)))
	var decay: Array[float] = [0.0, 0.0, 0.0, 0.0]
	if elapsed <= four_star_ms:
		decay[3] = clampf(float(elapsed) / float(four_star_ms), 0.0, 1.0)
		return decay
	decay[3] = 1.0
	if elapsed <= three_star_ms:
		decay[2] = _range_fraction(elapsed, four_star_ms, three_star_ms)
		return decay
	decay[2] = 1.0
	if elapsed <= two_star_ms:
		decay[1] = _range_fraction(elapsed, three_star_ms, two_star_ms)
		return decay
	decay[1] = 1.0
	return decay


static func _range_fraction(value: int, start_value: int, end_value: int) -> float:
	var span: int = maxi(1, end_value - start_value)
	return clampf(float(value - start_value) / float(span), 0.0, 1.0)


func configure(next_thresholds_ms: Dictionary, next_elapsed_ms: int) -> void:
	thresholds_ms = next_thresholds_ms.duplicate(true)
	elapsed_ms = maxi(0, next_elapsed_ms)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var star_gap: float = 10.0
	var available_w: float = maxf(1.0, size.x - (star_gap * float(STAR_COUNT - 1)))
	var outer_radius: float = minf(size.y * 0.42, available_w / float(STAR_COUNT) * 0.50)
	if outer_radius <= 1.0:
		return
	var inner_radius: float = outer_radius * 0.47
	var total_w: float = (outer_radius * 2.0 * float(STAR_COUNT)) + (star_gap * float(STAR_COUNT - 1))
	var start_x: float = (size.x - total_w) * 0.5 + outer_radius
	var center_y: float = size.y * 0.50
	var decay: Array[float] = decay_fractions_for_elapsed(elapsed_ms, thresholds_ms)
	for i in range(STAR_COUNT):
		var center := Vector2(start_x + (float(i) * ((outer_radius * 2.0) + star_gap)), center_y)
		var points: PackedVector2Array = _star_points(center, outer_radius, inner_radius)
		var fraction: float = clampf(float(decay[i]), 0.0, 1.0)
		_draw_single_star(points, center, fraction)


func _draw_single_star(points: PackedVector2Array, center: Vector2, decay_fraction: float) -> void:
	var base_color := Color(1.0, 0.78, 0.15, 0.96)
	var rim_color := Color(0.18, 0.10, 0.02, 0.95)
	var inner_color := Color(1.0, 0.91, 0.42, 1.0)
	var decayed_color := Color(0.16, 0.13, 0.09, 0.82)
	var shadow_color := Color(0.0, 0.0, 0.0, 0.34)
	var shadow_points: PackedVector2Array = _offset_points(points, Vector2(0.0, 2.5))
	draw_colored_polygon(shadow_points, shadow_color)
	draw_colored_polygon(points, base_color)
	draw_polyline(_closed_points(points), rim_color, 2.4, true)
	if decay_fraction < 1.0:
		var glint_outer: float = maxf(2.0, center.distance_to(points[0]) * 0.22)
		draw_circle(center + Vector2(-glint_outer * 0.32, -glint_outer * 0.22), glint_outer, inner_color)
		draw_circle(center + Vector2(-glint_outer * 0.32, -glint_outer * 0.22), glint_outer * 0.58, base_color)
	if decay_fraction > 0.0:
		var decay_points: PackedVector2Array = _scale_points_x(points, center.x, decay_fraction)
		draw_colored_polygon(decay_points, decayed_color)
		draw_polyline(_closed_points(decay_points), Color(0.0, 0.0, 0.0, 0.45), 1.3, true)


func _star_points(center: Vector2, outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(STAR_POINTS):
		var radius: float = outer_radius if i % 2 == 0 else inner_radius
		var angle: float = (-PI * 0.5) + (float(i) * TAU / float(STAR_POINTS))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not closed.is_empty():
		closed.append(closed[0])
	return closed


func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(point + offset)
	return out


func _scale_points_x(points: PackedVector2Array, center_x: float, scale_x: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(Vector2(center_x + ((point.x - center_x) * scale_x), point.y))
	return out
