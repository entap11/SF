class_name ControlBar
extends Control

var power_by_player: Array[float] = [0.0, 0.0, 0.0, 0.0]

func set_powers(p1: float, p2: float, p3: float, p4: float) -> void:
	power_by_player[0] = p1
	power_by_player[1] = p2
	power_by_player[2] = p3
	power_by_player[3] = p4
	queue_redraw()

func _draw() -> void:
	var total: float = power_by_player[0] + power_by_player[1] + power_by_player[2] + power_by_player[3]
	var width: float = size.x
	var height: float = size.y
	if total <= 0.0:
		draw_rect(Rect2(0, 0, width, height), Color(0.08, 0.08, 0.08, 0.8), true)
		return
	var colors: Array = [
		Color(0.95, 0.85, 0.2),
		Color(0.12, 0.12, 0.12),
		Color(0.9, 0.2, 0.2),
		Color(0.2, 0.5, 0.95)
	]
	var x: float = 0.0
	for i in range(4):
		var pct: float = power_by_player[i] / total
		var w: float = width * pct
		if w > 0.0:
			draw_rect(Rect2(x, 0, w, height), colors[i], true)
		x += w
