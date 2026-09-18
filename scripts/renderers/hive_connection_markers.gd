extends Node2D
## Presentation-only endpoint and incoming-route markers outside hive artwork.

var markers: Array = []
var connected: bool = false
var selected: bool = false
var radius: float = 45.0
var tint: Color = Color.WHITE

func configure(entries: Array, is_connected: bool, is_selected: bool, size: float, color: Color) -> void:
	if markers == entries and connected == is_connected and selected == is_selected and radius == size and tint == color:
		return
	markers = entries
	connected = is_connected
	selected = is_selected
	radius = size
	tint = color
	queue_redraw()

func _draw() -> void:
	if selected or connected:
		var points := PackedVector2Array()
		for i in range(49):
			var angle: float = float(i) / 48.0 * TAU
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.42 + 18.0))
		draw_polyline(points, Color(0.01, 0.015, 0.02, 0.9), 7.0, true)
		draw_polyline(points, Color.WHITE if selected else Color(tint, 0.8), 3.0, true)
	for entry in markers:
		var point: Vector2 = entry.point
		var direction: Vector2 = entry.direction
		var normal := Vector2(-direction.y, direction.x)
		var color: Color = entry.color
		var points := PackedVector2Array([point - direction * 12.0 + normal * 7.0, point, point - direction * 12.0 - normal * 7.0])
		draw_polyline(points, Color(0.01, 0.015, 0.02, 0.95), 7.0, true)
		draw_polyline(points, color, 3.5, true)
