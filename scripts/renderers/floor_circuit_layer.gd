extends Node2D
## Ambient presentation only; no gameplay state or shared random generator.

const TRACE_COUNT: int = 16
const PULSE_INTERVAL_SEC: float = 2.8
const PULSE_DURATION_SEC: float = 3.6
const TRACE_COLOR := Color(0.34, 0.43, 0.53, 0.14)
const GLOW_COLOR := Color(0.38, 0.54, 0.65)

var preview_time_sec: float = -1.0
var _bounds := Rect2()
var _paths: Array[PackedVector2Array] = []
var _elapsed_sec: float = 0.0
var _motion_active: bool = false
var _profile: Node = null
var _lifecycle: Node = null

func _ready() -> void:
	_profile = get_node_or_null("/root/ProfileManager")
	_lifecycle = get_node_or_null("/root/AppLifecycle")

func configure(bounds: Rect2) -> void:
	if bounds == _bounds and not _paths.is_empty():
		return
	_bounds = bounds
	_paths.clear()
	# Eight staggered paths on each edge; the central command area stays quiet.
	for index in range(TRACE_COUNT):
		var row: int = index / 2
		var side: int = index % 2
		var y: float = 0.045 + float(row) * 0.119 + float(side) * 0.028
		var reach: float = 0.23 + _fraction(index + 9) * 0.13
		var uv := PackedVector2Array([Vector2(0.015, y), Vector2(reach - 0.08, y),
			Vector2(reach, y + 0.045), Vector2(reach, y + 0.075)])
		var points := PackedVector2Array()
		for point in uv:
			if side == 1:
				point.x = 1.0 - point.x
			points.append(bounds.position + point * bounds.size)
		_paths.append(points)
	queue_redraw()

static func _fraction(value: int) -> float:
	# Stable decorative variation, independent of simulation and frame rate.
	var mixed: int = (value ^ 0x45d9f3b) * 0x45d9f3b
	mixed = (mixed ^ (mixed >> 16)) & 0x7fffffff
	return float(mixed) / 2147483647.0

static func pulses_at(time_sec: float) -> Array[Dictionary]:
	var pulses: Array[Dictionary] = []
	var slot: int = int(floor(maxf(0.0, time_sec) / PULSE_INTERVAL_SEC))
	for event in [slot - 1, slot]:
		if event < 0:
			continue
		var age: float = time_sec - float(event) * PULSE_INTERVAL_SEC
		if age < 0.0 or age >= PULSE_DURATION_SEC:
			continue
		var envelope: float = smoothstep(0.0, 1.2, age) * (1.0 - smoothstep(1.6, PULSE_DURATION_SEC, age))
		pulses.append({"trace": mini(TRACE_COUNT - 1, int(_fraction(event + 71) * TRACE_COUNT)), "strength": envelope})
	return pulses

func _motion_allowed() -> bool:
	if _profile != null:
		if not bool(_profile.call("is_floor_graphics_enabled")) or not bool(_profile.call("is_gpu_vfx_enabled")):
			return false
	return _lifecycle == null or not bool(_lifecycle.call("is_backgrounded"))

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var active: bool = _motion_allowed()
	if active:
		_elapsed_sec += maxf(0.0, delta)
	if active or active != _motion_active:
		_motion_active = active
		queue_redraw()

func _draw() -> void:
	var width: float = clampf(_bounds.size.x / 1080.0, 0.8, 2.0)
	for points in _paths:
		draw_polyline(points, TRACE_COLOR, width, true)
		draw_arc(points[-1], width * 2.4, 0.0, TAU, 12, TRACE_COLOR, width, true)
	if not _motion_active and preview_time_sec < 0.0:
		return
	var time_sec: float = preview_time_sec if preview_time_sec >= 0.0 else _elapsed_sec
	for pulse in pulses_at(time_sec):
		if int(pulse.trace) >= _paths.size():
			continue
		var points: PackedVector2Array = _paths[int(pulse.trace)]
		var strength: float = float(pulse.strength)
		draw_polyline(points, Color(GLOW_COLOR, strength * 0.035), width * 9.0, true)
		draw_polyline(points, Color(GLOW_COLOR, strength * 0.10), width * 3.0, true)
		draw_polyline(points, Color(GLOW_COLOR, strength * 0.34), width * 1.2, true)
		draw_circle(points[-1], width * 2.0, Color(GLOW_COLOR, strength * 0.32))
