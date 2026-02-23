class_name IonPop
extends Node2D

@export var lifetime: float = 0.12

@onready var beam: Sprite2D = $Beam
@onready var flash: Sprite2D = $Flash
@onready var sparks: GPUParticles2D = $Sparks

const MIN_BEAM_DISTANCE_PX: float = 1.0

var _timer: float = 0.0
var _active: bool = false
var _pool: Node = null
var _fallback_tex: Texture2D = null

func _ready() -> void:
	_ensure_fallback_texture()
	hide()

func init(pool: Node) -> void:
	_pool = pool
	_active = false
	_timer = 0.0
	hide()
	if sparks != null:
		sparks.one_shot = true
		sparks.emitting = false

func play(from_pos: Vector2, to_pos: Vector2) -> void:
	_ensure_fallback_texture()
	global_position = from_pos
	var delta: Vector2 = to_pos - from_pos
	var distance: float = delta.length()
	if distance < MIN_BEAM_DISTANCE_PX:
		delta = Vector2.RIGHT
		distance = MIN_BEAM_DISTANCE_PX
	rotation = delta.angle()

	var beam_tex_width: float = 100.0
	if beam.texture != null:
		beam_tex_width = maxf(1.0, float(beam.texture.get_width()))
	beam.scale.x = distance / beam_tex_width

	_timer = lifetime
	_active = true
	show()

	if flash != null:
		flash.visible = true
		flash.scale = Vector2.ONE
		flash.modulate.a = 0.9
	if sparks != null:
		sparks.restart()
		sparks.emitting = true

func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if flash != null:
		var t: float = clampf(_timer / maxf(0.001, lifetime), 0.0, 1.0)
		flash.modulate.a = t
		flash.scale = Vector2.ONE * lerpf(0.9, 0.5, 1.0 - t)
	if _timer > 0.0:
		return
	_active = false
	hide()
	if sparks != null:
		sparks.emitting = false
	if _pool != null:
		_pool.call_deferred("return_ionpop", self)

func _ensure_fallback_texture() -> void:
	if _fallback_tex == null:
		var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 1.0, 1.0, 1.0))
		_fallback_tex = ImageTexture.create_from_image(img)
	if beam != null and beam.texture == null:
		beam.texture = _fallback_tex
	if flash != null and flash.texture == null:
		flash.texture = _fallback_tex
