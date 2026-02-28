extends RefCounted
class_name BeeClipController

const CUT_PARAM: StringName = &"cut"
const CUT_DIR_PARAM: StringName = &"cut_dir"
const KEY_COLOR_PARAM: StringName = &"key_color"
const KEY_THRESHOLD_PARAM: StringName = &"key_threshold"
const KEY_SOFTNESS_PARAM: StringName = &"key_softness"
const KEY_ENABLED_PARAM: StringName = &"key_enabled"
const FULL_CUT_EPS: float = 0.999

var distance_to_plane_px: float = 0.0
var entering_state: bool = false
var cut_value: float = 0.0
var shield_active: bool = false
var penetration_px: float = 0.0
var precontact_3_5px: bool = false

var _entrance_point_world: Vector2 = Vector2.ZERO
var _travel_dir_world: Vector2 = Vector2.RIGHT
var _local_cut_dir: Vector2 = Vector2.RIGHT
var _bee_visual_length_px: float = 1.0
var _sprite: Sprite2D = null
var _material: ShaderMaterial = null
var _reported_fully_clipped: bool = false
var _prev_nose_world: Vector2 = Vector2.ZERO
var _has_prev_nose_world: bool = false

func configure_sprite(sprite: Sprite2D, clip_shader: Shader) -> void:
	if sprite == null or clip_shader == null:
		return
	_sprite = sprite
	if _material != null and _material.shader == clip_shader:
		if _sprite.material != _material:
			_sprite.material = _material
		return
	_material = ShaderMaterial.new()
	_material.shader = clip_shader
	_material.resource_local_to_scene = true
	_material.set_shader_parameter(CUT_PARAM, 0.0)
	_material.set_shader_parameter(CUT_DIR_PARAM, Vector2.RIGHT)
	_material.set_shader_parameter(KEY_COLOR_PARAM, Color(0.0, 0.0, 0.0, 1.0))
	_material.set_shader_parameter(KEY_THRESHOLD_PARAM, 0.28)
	_material.set_shader_parameter(KEY_SOFTNESS_PARAM, 0.10)
	_material.set_shader_parameter(KEY_ENABLED_PARAM, 0.0)
	_sprite.material = _material

func set_plane(entrance_point_world: Vector2, travel_dir_world: Vector2) -> void:
	_entrance_point_world = entrance_point_world
	if travel_dir_world.length_squared() <= 0.000001:
		_travel_dir_world = Vector2.RIGHT
	else:
		_travel_dir_world = travel_dir_world.normalized()

func set_visual_length_px(bee_visual_length_px: float) -> void:
	_bee_visual_length_px = maxf(1.0, bee_visual_length_px)

func set_local_cut_dir(local_cut_dir: Vector2) -> void:
	var next_dir: Vector2 = local_cut_dir
	if next_dir.length_squared() <= 0.000001:
		next_dir = Vector2.RIGHT
	else:
		next_dir = next_dir.normalized()
	_local_cut_dir = next_dir
	if _material != null:
		_material.set_shader_parameter(CUT_DIR_PARAM, _local_cut_dir)

func set_shield_active(active: bool) -> void:
	shield_active = active

func set_colorkey(enabled: bool, key_color: Color, threshold: float, softness: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter(KEY_ENABLED_PARAM, 1.0 if enabled else 0.0)
	_material.set_shader_parameter(KEY_COLOR_PARAM, key_color)
	_material.set_shader_parameter(KEY_THRESHOLD_PARAM, threshold)
	_material.set_shader_parameter(KEY_SOFTNESS_PARAM, softness)

func update_from_world_position(
	bee_world_position: Vector2,
	nose_offset_px: float = 0.0,
	entrance_plane_offset_px: float = 0.0
) -> float:
	var entrance_shifted_world: Vector2 = _entrance_point_world - (_travel_dir_world * entrance_plane_offset_px)
	var nose_world: Vector2 = bee_world_position + (_travel_dir_world * nose_offset_px)
	distance_to_plane_px = (nose_world - entrance_shifted_world).dot(_travel_dir_world)
	precontact_3_5px = distance_to_plane_px <= -3.0 and distance_to_plane_px >= -5.0
	var target_penetration_px: float = maxf(0.0, distance_to_plane_px)
	if target_penetration_px <= 0.0:
		penetration_px = 0.0
	elif _has_prev_nose_world:
		var forward_step_px: float = maxf(0.0, (nose_world - _prev_nose_world).dot(_travel_dir_world))
		if target_penetration_px < penetration_px:
			penetration_px = target_penetration_px
		else:
			penetration_px = minf(target_penetration_px, penetration_px + forward_step_px)
	else:
		# On first contact frame, avoid a deep snap by starting at boundary.
		penetration_px = 0.0
	_prev_nose_world = nose_world
	_has_prev_nose_world = true
	entering_state = distance_to_plane_px >= 0.0
	cut_value = clampf(penetration_px / _bee_visual_length_px, 0.0, 1.0)
	if _material != null:
		_material.set_shader_parameter(CUT_PARAM, cut_value)
	if cut_value >= FULL_CUT_EPS:
		_reported_fully_clipped = true
	return cut_value

func consume_full_clip_transition() -> bool:
	if _reported_fully_clipped:
		_reported_fully_clipped = false
		return true
	return false

func reset() -> void:
	distance_to_plane_px = 0.0
	entering_state = false
	cut_value = 0.0
	shield_active = false
	penetration_px = 0.0
	precontact_3_5px = false
	_reported_fully_clipped = false
	_prev_nose_world = Vector2.ZERO
	_has_prev_nose_world = false
	if _material != null:
		_material.set_shader_parameter(CUT_PARAM, 0.0)
		_material.set_shader_parameter(CUT_DIR_PARAM, _local_cut_dir)
