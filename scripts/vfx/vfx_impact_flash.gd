class_name VfxImpactFlash
extends Node2D

@export var lifetime_s: float = 0.08
@export var start_alpha: float = 1.5
@export var end_alpha: float = 0.0
@export var light_peak_energy: float = 1.4
@export var light_final_energy: float = 0.0

@onready var _flash: Polygon2D = $Flash
@onready var _light: PointLight2D = $Light

var _light_tex: Texture2D = null
var _pending_rot: float = 0.0
var _pending_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _pending_intensity: float = 1.0
var _release_callback: Callable = Callable()
var _play_tween: Tween = null

func prime(rot_rad: float, color: Color, intensity: float) -> void:
	_pending_rot = rot_rad
	_pending_color = color
	_pending_intensity = clampf(intensity, 0.0, 1.0)

func set_release_callback(cb: Callable) -> void:
	_release_callback = cb

func _ready() -> void:
	_ensure_light_texture()
	var blend_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	blend_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = blend_mat
	reset_for_pool()

func play(world_pos: Vector2, rot_rad: float, color: Color, intensity: float) -> void:
	_pending_rot = rot_rad
	_pending_color = color
	_pending_intensity = clampf(intensity, 0.0, 1.0)
	_cancel_active()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = world_pos
	rotation = _pending_rot
	_flash.color = _pending_color
	_flash.modulate = Color(1.0, 1.0, 1.0, start_alpha * maxf(0.1, _pending_intensity))
	_light.color = _pending_color
	_light.enabled = true
	_light.energy = light_peak_energy * maxf(0.1, _pending_intensity)
	scale = Vector2.ONE
	_play_tween = create_tween()
	_play_tween.set_trans(Tween.TRANS_QUAD)
	_play_tween.set_ease(Tween.EASE_OUT)
	_play_tween.tween_property(_flash, "modulate:a", end_alpha, lifetime_s)
	_play_tween.parallel().tween_property(self, "scale", Vector2(1.25, 0.85), lifetime_s)
	_play_tween.parallel().tween_property(_light, "energy", light_final_energy, lifetime_s)
	_play_tween.tween_callback(Callable(self, "_release_or_free"))

func reset_for_pool() -> void:
	_cancel_active()
	visible = false
	position = Vector2(-99999.0, -99999.0)
	rotation = 0.0
	scale = Vector2.ONE
	process_mode = Node.PROCESS_MODE_DISABLED

func _cancel_active() -> void:
	if _play_tween != null:
		_play_tween.kill()
		_play_tween = null
	_light.enabled = false
	_light.energy = light_final_energy
	_flash.modulate = Color(1.0, 1.0, 1.0, 0.0)

func _release_or_free() -> void:
	if _release_callback.is_valid():
		_release_callback.call(self)
		return
	queue_free()

func _ensure_light_texture() -> void:
	if _light_tex != null:
		_light.texture = _light_tex
		return
	var size_px: int = 64
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
	_light_tex = ImageTexture.create_from_image(image)
	_light.texture = _light_tex
