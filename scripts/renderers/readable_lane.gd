extends Node2D
## Draws a route, never a second unit path or a simulated battle front.

var route: Dictionary = {}
const INK := Color(0.015, 0.018, 0.026, 0.94)
const CHEVRON_SPACING := 110.0

func set_route(value: Dictionary) -> void:
	visible = true
	if route == value:
		return
	route = value
	z_index = int(value.get("z_index", -4))
	queue_redraw()

func _draw() -> void:
	if route.is_empty():
		return
	var a: Vector2 = route.a
	var b: Vector2 = route.b
	var delta: Vector2 = b - a
	var length: float = delta.length()
	if length < 6.0:
		return
	var direction: Vector2 = delta / length
	var normal := Vector2(-direction.y, direction.x)
	var color: Color = route.color
	var width: float = route.width
	var offset: Vector2 = normal * float(route.get("offset", 0.0))
	var intervals: Array = route.get("intervals", [Vector2(0, 1)])
	for interval: Vector2 in intervals:
		var start: Vector2 = a.lerp(b, interval.x) + offset
		var end: Vector2 = a.lerp(b, interval.y) + offset
		draw_line(start, end, Color(INK, color.a), width + 4.0, true)
		draw_line(start, end, color, width, true)
	# Sparse, static chevrons express direction even with reduced motion.
	var first: float = minf(45.0, length * 0.35)
	var distance: float = first
	while distance < length - 30.0:
		var t: float = distance / length
		for interval: Vector2 in intervals:
			if t > interval.x + 10.0 / length and t < interval.y - 10.0 / length:
				_chevron(a + direction * distance + offset, direction, normal, color, 8.0, width)
				break
		distance += CHEVRON_SPACING
	# Circle = source; inward arrow = destination. A focus adds a white rim.
	var source: Vector2 = a + offset + direction * 4.0
	var target: Vector2 = b + offset - direction * 5.0
	var focused: bool = bool(route.get("focused", false))
	draw_circle(source, 7.0 if focused else 5.0, Color(INK, color.a))
	draw_arc(source, 5.0 if focused else 3.5, 0, TAU, 16, Color.WHITE if focused else color, 2.0, true)
	_chevron(target, direction, normal, color, 13.0 if focused else 10.0, width + 0.5)

func _chevron(point: Vector2, direction: Vector2, normal: Vector2, color: Color, length: float, width: float) -> void:
	var points := PackedVector2Array([point - direction * length + normal * length * 0.55, point, point - direction * length - normal * length * 0.55])
	draw_polyline(points, Color(INK, color.a), width + 3.5, true)
	draw_polyline(points, color, maxf(2.0, width * 0.7), true)
