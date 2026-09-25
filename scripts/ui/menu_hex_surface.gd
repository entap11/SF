extends Control
## Event-driven hex frame behind a native button and its live labels.
var _button: Button
var has_artwork := false

func _ready() -> void:
	_button = get_parent() as Button
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for signal_name in ["resized", "mouse_entered", "mouse_exited", "button_down", "button_up", "focus_entered", "focus_exited"]:
		_button.connect(signal_name, queue_redraw)
	_button.toggled.connect(func(_on: bool) -> void: queue_redraw())
	queue_redraw()

func _draw() -> void:
	if _button == null:
		return
	if has_artwork and not (_button.is_hovered() or _button.is_pressed() or _button.has_focus()):
		return
	var cut := minf(36, size.x * 0.10)
	var points := PackedVector2Array([Vector2(cut, 2), Vector2(size.x - cut, 2), Vector2(size.x - 2, size.y * 0.5), Vector2(size.x - cut, size.y - 2), Vector2(cut, size.y - 2), Vector2(2, size.y * 0.5)])
	var fill := Color("171c24")
	var edge := Color("697586")
	if _button.is_hovered():
		fill = Color("232d3b")
		edge = Color("b5c2d3")
	if _button.is_pressed():
		fill = Color("353020")
		edge = Color("f7ba30")
	if _button.disabled:
		fill = Color("101319")
		edge = Color("424957")
	if not has_artwork:
		draw_colored_polygon(points, fill)
	var border := points.duplicate()
	border.append(points[0])
	draw_polyline(border, Color("fff0b8") if _button.has_focus() else edge, 3, true)
	draw_line(Vector2(cut + 18, 9), Vector2(size.x - cut - 18, 9), Color(edge, 0.25), 2, true)
