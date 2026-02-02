class_name ImpactFlash
extends Node2D

@export var flash_duration_s: float = 0.10
@export var lifetime_s: float = 0.18
@export var spark_speed_min: float = 80.0
@export var spark_speed_max: float = 220.0
@export var spark_amount_min: int = 20
@export var spark_amount_max: int = 80

@onready var _flash_light: PointLight2D = $FlashLight
@onready var _sparks: GPUParticles2D = $Sparks

var _light_tex: Texture2D = null
var _spark_tex: Texture2D = null

func _ready() -> void:
	_ensure_textures()
	_configure_particles()
	_flash_light.energy = 0.0
	_sparks.emitting = false

func play(world_pos: Vector2, color: Color, intensity: float, dir: Vector2) -> void:
	global_position = world_pos
	var n: float = clampf(intensity, 0.0, 1.0)
	var axis: Vector2 = dir
	if axis.length_squared() <= 0.000001:
		axis = Vector2.RIGHT
	axis = axis.normalized()

	var core_color: Color = color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.5)
	_flash_light.color = core_color
	var peak_energy: float = lerpf(0.8, 2.0, n)
	var peak_scale: float = lerpf(0.65, 1.25, n)
	_flash_light.texture_scale = peak_scale
	_flash_light.enabled = true
	_flash_light.energy = 0.0

	var spark_mat: ParticleProcessMaterial = _ensure_particle_material()
	spark_mat.color = core_color
	spark_mat.direction = Vector3(axis.x, axis.y, 0.0)
	spark_mat.initial_velocity_min = lerpf(spark_speed_min * 0.5, spark_speed_min, n)
	spark_mat.initial_velocity_max = lerpf(spark_speed_max * 0.5, spark_speed_max, n)
	spark_mat.spread = lerpf(12.0, 24.0, n)

	_sparks.amount = maxi(1, int(round(lerpf(float(spark_amount_min), float(spark_amount_max), n))))
	_sparks.lifetime = lerpf(0.12, 0.18, n)
	_sparks.emitting = false
	_sparks.restart()
	_sparks.emitting = true

	scale = Vector2.ONE * 0.9
	modulate.a = 1.0

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash_light, "energy", peak_energy, 0.03)
	tween.tween_property(_flash_light, "energy", 0.0, flash_duration_s)
	tween.parallel().tween_property(self, "scale", Vector2.ONE * 1.15, flash_duration_s)
	tween.parallel().tween_property(self, "modulate:a", 0.0, lifetime_s)
	tween.tween_callback(Callable(self, "queue_free"))

func _configure_particles() -> void:
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.texture = _spark_tex
	var canvas_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sparks.material = canvas_mat
	if _sparks.process_material == null:
		_sparks.process_material = _build_particle_material()

func _ensure_particle_material() -> ParticleProcessMaterial:
	var mat: ParticleProcessMaterial = _sparks.process_material as ParticleProcessMaterial
	if mat != null:
		return mat
	mat = _build_particle_material()
	_sparks.process_material = mat
	return mat

func _build_particle_material() -> ParticleProcessMaterial:
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.gravity = Vector3.ZERO
	mat.damping_min = 6.0
	mat.damping_max = 12.0
	mat.scale_min = 0.08
	mat.scale_max = 0.22
	return mat

func _ensure_textures() -> void:
	if _light_tex == null:
		_light_tex = _build_radial_texture(64)
	if _spark_tex == null:
		_spark_tex = _build_radial_texture(8)
	_flash_light.texture = _light_tex

func _build_radial_texture(size_px: int) -> Texture2D:
	var image: Image = Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var cx: float = (float(size_px) - 1.0) * 0.5
	var cy: float = (float(size_px) - 1.0) * 0.5
	var radius: float = maxf(1.0, float(size_px) * 0.5)
	for y in range(size_px):
		for x in range(size_px):
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			var dist: float = sqrt(dx * dx + dy * dy)
			var t: float = clampf(1.0 - (dist / radius), 0.0, 1.0)
			var alpha: float = t * t
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
