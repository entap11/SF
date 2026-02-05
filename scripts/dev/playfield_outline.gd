class_name PlayfieldOutline
extends Node2D

@export var enabled: bool = true
@export var inset_px: float = 0.0
@export var line_px: float = 3.0
@export var dash_px: float = 14.0
@export var gap_px: float = 10.0
@export var show_center_crosshair: bool = true

const OUTLINE_COLOR: Color = Color(1.0, 0.9, 0.2, 0.95)
const CROSSHAIR_HALF_PX: float = 8.0

var _playfield_rect_world: Rect2 = Rect2()
var _has_rect: bool = false

func _ready() -> void:
	set_notify_transform(true)

func set_playfield_rect_world(r: Rect2) -> void:
	_playfield_rect_world = r
	_has_rect = true
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()

func _draw() -> void:
	if not enabled or not _has_rect:
		return
	var inset: float = maxf(0.0, inset_px)
	var rect_world: Rect2 = _playfield_rect_world.grow(-inset)
	if rect_world.size.x <= 0.0 or rect_world.size.y <= 0.0:
		return
	var a: Vector2 = to_local(rect_world.position)
	var b: Vector2 = to_local(rect_world.position + Vector2(rect_world.size.x, 0.0))
	var c: Vector2 = to_local(rect_world.position + rect_world.size)
	var d: Vector2 = to_local(rect_world.position + Vector2(0.0, rect_world.size.y))
	_draw_dashed_edge(a, b)
	_draw_dashed_edge(b, c)
	_draw_dashed_edge(c, d)
	_draw_dashed_edge(d, a)
	if show_center_crosshair:
		var center_world: Vector2 = rect_world.get_center()
		var center: Vector2 = to_local(center_world)
		draw_line(
			center + Vector2(-CROSSHAIR_HALF_PX, 0.0),
			center + Vector2(CROSSHAIR_HALF_PX, 0.0),
			OUTLINE_COLOR,
			line_px,
			true
		)
		draw_line(
			center + Vector2(0.0, -CROSSHAIR_HALF_PX),
			center + Vector2(0.0, CROSSHAIR_HALF_PX),
			OUTLINE_COLOR,
			line_px,
			true
		)

func _draw_dashed_edge(from_point: Vector2, to_point: Vector2) -> void:
	var edge: Vector2 = to_point - from_point
	var edge_len: float = edge.length()
	if edge_len <= 0.0:
		return
	var dash_len: float = maxf(1.0, dash_px)
	var gap_len: float = maxf(0.0, gap_px)
	var step_len: float = dash_len + gap_len
	if step_len <= 0.0:
		draw_line(from_point, to_point, OUTLINE_COLOR, line_px, true)
		return
	var dir: Vector2 = edge / edge_len
	var cursor: float = 0.0
	while cursor < edge_len:
		var seg_start: Vector2 = from_point + dir * cursor
		var seg_end_dist: float = minf(cursor + dash_len, edge_len)
		var seg_end: Vector2 = from_point + dir * seg_end_dist
		draw_line(seg_start, seg_end, OUTLINE_COLOR, line_px, true)
		cursor += step_len
