@tool
extends ColorRect
class_name HexSeamBackground

const SHADER_PATH: String = "res://ui/backgrounds/hex_seam_background.gdshader"
const HexBgPresets = preload("res://ui/backgrounds/HexBgPresets.gd")

var _sync_locked: bool = false

@export var glow_color: Color = Color(1.0, 0.831, 0.0, 1.0):
	set(value):
		glow_color = value
		_sync_shader_params()
@export_range(0.001, 0.2, 0.001) var seam_width: float = 0.034:
	set(value):
		seam_width = value
		_sync_shader_params()
@export_range(0.0, 4.0, 0.01) var seam_intensity: float = 1.0:
	set(value):
		seam_intensity = value
		_sync_shader_params()
@export_range(0.1, 20.0, 0.1) var noise_scale: float = 3.5:
	set(value):
		noise_scale = value
		_sync_shader_params()
@export_range(0.0, 1.0, 0.01) var noise_amount: float = 0.24:
	set(value):
		noise_amount = value
		_sync_shader_params()
@export_range(0.0, 2.5, 0.01) var center_bias: float = 0.5:
	set(value):
		center_bias = value
		_sync_shader_params()
@export var pulse_enabled: bool = false:
	set(value):
		pulse_enabled = value
		_sync_shader_params()
@export_range(1.0, 12.0, 0.1) var pulse_period: float = 5.0:
	set(value):
		pulse_period = value
		_sync_shader_params()
@export_range(0.0, 0.5, 0.005) var pulse_amount: float = 0.04:
	set(value):
		pulse_amount = value
		_sync_shader_params()
@export_range(0.0, 0.4, 0.005) var flicker_amount: float = 0.01:
	set(value):
		flicker_amount = value
		_sync_shader_params()
@export_range(2.0, 60.0, 0.5) var hex_scale: float = 17.0:
	set(value):
		hex_scale = value
		_sync_shader_params()
@export var seed: float = 11.0:
	set(value):
		seed = value
		_sync_shader_params()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_shader_material()
	_sync_shader_params()


func _enter_tree() -> void:
	_ensure_shader_material()
	_sync_shader_params()


func apply_preset(preset_name: StringName) -> void:
	var preset: Dictionary = HexBgPresets.get_preset(preset_name)
	if preset.is_empty():
		return
	_sync_locked = true
	if preset.has("glow_color"):
		glow_color = preset["glow_color"] as Color
	if preset.has("seam_width"):
		seam_width = float(preset["seam_width"])
	if preset.has("seam_intensity"):
		seam_intensity = float(preset["seam_intensity"])
	if preset.has("noise_scale"):
		noise_scale = float(preset["noise_scale"])
	if preset.has("noise_amount"):
		noise_amount = float(preset["noise_amount"])
	if preset.has("center_bias"):
		center_bias = float(preset["center_bias"])
	if preset.has("pulse_enabled"):
		pulse_enabled = bool(preset["pulse_enabled"])
	if preset.has("pulse_period"):
		pulse_period = float(preset["pulse_period"])
	if preset.has("pulse_amount"):
		pulse_amount = float(preset["pulse_amount"])
	if preset.has("flicker_amount"):
		flicker_amount = float(preset["flicker_amount"])
	if preset.has("hex_scale"):
		hex_scale = float(preset["hex_scale"])
	if preset.has("seed"):
		seed = float(preset["seed"])
	_sync_locked = false
	_sync_shader_params()


func _ensure_shader_material() -> void:
	var shader_resource: Shader = load(SHADER_PATH) as Shader
	if shader_resource == null:
		return
	var shader_material: ShaderMaterial = material as ShaderMaterial
	if shader_material == null:
		shader_material = ShaderMaterial.new()
		shader_material.resource_local_to_scene = true
		material = shader_material
	elif not shader_material.resource_local_to_scene:
		var unique_material: ShaderMaterial = shader_material.duplicate() as ShaderMaterial
		if unique_material != null:
			unique_material.resource_local_to_scene = true
			shader_material = unique_material
			material = shader_material
	if shader_material.shader != shader_resource:
		shader_material.shader = shader_resource


func _sync_shader_params() -> void:
	if _sync_locked:
		return
	_ensure_shader_material()
	var shader_material: ShaderMaterial = material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("glow_color", glow_color)
	shader_material.set_shader_parameter("seam_width", seam_width)
	shader_material.set_shader_parameter("seam_intensity", seam_intensity)
	shader_material.set_shader_parameter("noise_scale", noise_scale)
	shader_material.set_shader_parameter("noise_amount", noise_amount)
	shader_material.set_shader_parameter("center_bias", center_bias)
	shader_material.set_shader_parameter("pulse_enabled", pulse_enabled)
	shader_material.set_shader_parameter("pulse_period", pulse_period)
	shader_material.set_shader_parameter("pulse_amount", pulse_amount)
	shader_material.set_shader_parameter("flicker_amount", flicker_amount)
	shader_material.set_shader_parameter("hex_scale", hex_scale)
	shader_material.set_shader_parameter("seed", seed)
	queue_redraw()
