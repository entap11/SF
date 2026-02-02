class_name CollisionVfx
extends Node2D

@export var lifetime_s: float = 0.35
@export var spark_amount: int = 18
@export var spark_speed: float = 420.0
@export var spread_deg: float = 18.0
@export var flash_scale: float = 0.35

@onready var _sparks: GPUParticles2D = $Sparks
@onready var _core_flash: Sprite2D = $CoreFlash

var _fallback_tex: Texture2D = null
var _cleanup_tween: Tween = null
var _release_callback: Callable = Callable()

func _ready() -> void:
	if _core_flash.texture == null:
		_core_flash.texture = _fallback_texture()
	if _sparks.process_material == null:
		_sparks.process_material = _build_default_particle_material()
	_sparks.one_shot = true
	_sparks.emitting = false
	_core_flash.visible = false
	visible = false

func set_release_callback(cb: Callable) -> void:
	_release_callback = cb

func reset_for_pool() -> void:
	_cancel_active()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	position = Vector2(-99999.0, -99999.0)
	rotation = 0.0
	scale = Vector2.ONE

func play(world_pos: Vector2, dir: Vector2, c1: Color, c2: Color, intensity: float) -> void:
	_cancel_active()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = world_pos
	var facing: Vector2 = dir
	if facing.length_squared() <= 0.000001:
		facing = Vector2.RIGHT
	facing = facing.normalized()

	var blend: Color = c1.lerp(c2, 0.5)
	var white_hot: Color = Color(1.0, 1.0, 1.0, 1.0)
	var spark_color: Color = blend.lerp(white_hot, 0.4)
	var core_color: Color = white_hot.lerp(blend, 0.25)
	var clamped_intensity: float = clampf(intensity, 0.2, 2.0)

	var spark_mat: ParticleProcessMaterial = _ensure_particle_material()
	spark_mat.direction = Vector3(facing.x, facing.y, 0.0)
	spark_mat.initial_velocity_min = spark_speed * 0.55 * clamped_intensity
	spark_mat.initial_velocity_max = spark_speed * clamped_intensity
	spark_mat.spread = spread_deg
	spark_mat.color = spark_color

	_sparks.amount = maxi(1, int(round(float(spark_amount) * clamped_intensity)))
	_sparks.lifetime = maxf(0.05, lifetime_s * 0.8)
	_sparks.emitting = false
	_sparks.emitting = true

	_core_flash.visible = true
	_core_flash.rotation = facing.angle()
	_core_flash.modulate = core_color
	_core_flash.modulate.a = 1.0
	_core_flash.scale = Vector2.ONE * (flash_scale * clamped_intensity)

	_cleanup_tween = create_tween()
	_cleanup_tween.set_trans(Tween.TRANS_QUAD)
	_cleanup_tween.set_ease(Tween.EASE_OUT)
	_cleanup_tween.tween_property(_core_flash, "scale", Vector2.ONE * (flash_scale * 0.08), lifetime_s * 0.55)
	_cleanup_tween.parallel().tween_property(_core_flash, "modulate:a", 0.0, lifetime_s * 0.55)
	_cleanup_tween.tween_interval(maxf(0.05, lifetime_s))
	_cleanup_tween.tween_callback(Callable(self, "_release_or_free"))

func _cancel_active() -> void:
	if _cleanup_tween != null:
		_cleanup_tween.kill()
		_cleanup_tween = null
	_sparks.emitting = false
	_core_flash.visible = false
	_core_flash.modulate.a = 1.0
	_core_flash.scale = Vector2.ONE * flash_scale

func _release_or_free() -> void:
	if _release_callback.is_valid():
		_release_callback.call(self)
		return
	queue_free()

func _ensure_particle_material() -> ParticleProcessMaterial:
	var mat: ParticleProcessMaterial = _sparks.process_material as ParticleProcessMaterial
	if mat != null:
		return mat
	mat = _build_default_particle_material()
	_sparks.process_material = mat
	return mat

func _build_default_particle_material() -> ParticleProcessMaterial:
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.gravity = Vector3.ZERO
	mat.damping_min = 8.0
	mat.damping_max = 12.0
	mat.scale_min = 0.10
	mat.scale_max = 0.22
	mat.color = Color(1.0, 0.95, 0.7, 1.0)
	return mat

func _fallback_texture() -> Texture2D:
	if _fallback_tex != null:
		return _fallback_tex
	var img: Image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))
	_fallback_tex = ImageTexture.create_from_image(img)
	return _fallback_tex
