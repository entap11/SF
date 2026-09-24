extends "res://scripts/hive/hive_distress_light.gd"
## Frozen first review candidate: inherits all existing pressure rules and timers unchanged.
const SURFACE := preload("res://tools/hive_pressure_study/pressure_v1.gdshader")
var _surface: ShaderMaterial

func _ready() -> void:
	super._ready()
	_surface = material as ShaderMaterial
	_surface.shader = SURFACE

func _draw() -> void:
	if not _has_visible_energy() or _surface == null:
		return
	var burst := 0.0
	var progress := 0.0
	if _burst_kind != HiveDistressRules.BURST_NONE:
		progress = clampf(_burst_elapsed / maxf(0.001, float(_burst_profile.get("duration_sec", 1.0))), 0.0, 1.0)
		burst = smoothstep(0.0, 0.075, progress) * (1.0 - smoothstep(0.12, 1.0, progress))
		burst *= 1.0 if _burst_kind == HiveDistressRules.BURST_MAJOR_RUPTURE else 0.64
	var surge := 0.0
	if _surge_elapsed >= 0.0 and _surge_duration > 0.0:
		surge = sin(clampf(_surge_elapsed / _surge_duration, 0.0, 1.0) * PI) * _surge_strength
	var moving := _motion_mode == "full"
	var size := _current_size
	_surface.set_shader_parameter("owner_color", _owner_color)
	_surface.set_shader_parameter("energy", _critical_base_intensity * 0.66 + burst * 0.95 + surge * 0.45)
	_surface.set_shader_parameter("burst", burst)
	_surface.set_shader_parameter("progress", progress)
	_surface.set_shader_parameter("phase", _presentation_t if moving else 0.0)
	_surface.set_shader_parameter("seed", float(_stable_seed % 23) * 0.43)
	_surface.set_shader_parameter("motion", 1.0 if moving else 0.0)
	_surface.set_shader_parameter("footprint", size)
	# A single bounded surface, with no particle/node allocation or screen reads.
	draw_rect(Rect2(-size.x * 0.48, -size.y * 0.28, size.x * 0.96, size.y * 0.60), Color.WHITE)
