extends Node2D
class_name HoneyDrip

signal finished(drip: HoneyDrip)

@export var stretch_duration: float = 0.12
@export var lifetime: float = 2.0
@export var gravity: float = 2100.0
@export var initial_fall_speed: float = 60.0
@export var sway_amplitude: float = 20.0
@export var sway_frequency: float = 7.5
@export var fade_start_ratio: float = 0.62
@export var base_radius: float = 9.0

var _active: bool = false
var _phase: int = 0
var _elapsed: float = 0.0
var _stretch_elapsed: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _sway_phase: float = 0.0

func _ready() -> void:
	visible = false
	set_process(false)

func reset(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	_active = true
	_phase = 0
	_elapsed = 0.0
	_stretch_elapsed = 0.0
	_velocity = Vector2(0.0, initial_fall_speed)
	_sway_phase = float(int(get_instance_id()) % 360) * PI / 180.0
	scale = Vector2(0.9, 0.3)
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta

	if _phase == 0:
		_stretch_elapsed += delta
		var stretch_t: float = clampf(_stretch_elapsed / maxf(0.001, stretch_duration), 0.0, 1.0)
		scale = Vector2(lerpf(0.90, 1.00, stretch_t), lerpf(0.30, 1.16, stretch_t))
		if stretch_t >= 1.0:
			_phase = 1
			scale = Vector2.ONE
	else:
		_velocity.y += gravity * delta
		var sway_velocity: float = cos((_elapsed * sway_frequency) + _sway_phase) * sway_amplitude
		global_position.x += sway_velocity * delta
		global_position.y += _velocity.y * delta

	var fade_start: float = lifetime * clampf(fade_start_ratio, 0.1, 0.95)
	if _elapsed >= fade_start:
		var fade_t: float = clampf((_elapsed - fade_start) / maxf(0.001, lifetime - fade_start), 0.0, 1.0)
		modulate.a = 1.0 - fade_t

	var viewport_bottom: float = get_viewport_rect().size.y + (base_radius * 8.0)
	if _elapsed >= lifetime or global_position.y >= viewport_bottom:
		_finish()

func _finish() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	visible = false
	finished.emit(self)

func _draw() -> void:
	var body_color: Color = Color(0.98, 0.73, 0.24, 0.95)
	var core_color: Color = Color(1.0, 0.84, 0.36, 0.95)
	var highlight_color: Color = Color(1.0, 0.97, 0.78, 0.82)

	var tail_points: PackedVector2Array = PackedVector2Array([
		Vector2(-base_radius * 0.32, -base_radius * 0.25),
		Vector2(base_radius * 0.32, -base_radius * 0.25),
		Vector2(0.0, -base_radius * 1.35)
	])
	var tail_colors: PackedColorArray = PackedColorArray([body_color, body_color, body_color])
	draw_polygon(tail_points, tail_colors)
	draw_circle(Vector2.ZERO, base_radius, body_color)
	draw_circle(Vector2(0.0, base_radius * 0.15), base_radius * 0.68, core_color)
	draw_circle(Vector2(-base_radius * 0.28, -base_radius * 0.38), base_radius * 0.23, highlight_color)
