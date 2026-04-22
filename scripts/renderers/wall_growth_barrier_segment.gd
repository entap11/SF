extends Node2D
class_name WallGrowthBarrierSegment

const BODY_SHADER: Shader = preload("res://shaders/wall_growth_barrier.gdshader")

const SHADOW_Z_INDEX: int = -9
const ROOT_Z_INDEX: int = -8
const BODY_Z_INDEX: int = -4
const FX_Z_INDEX: int = -3

const MIN_SEGMENT_LEN_PX: float = 8.0
const HEAT_GAIN_PER_BLOCK: float = 0.16
const HEAT_DECAY_PER_SEC: float = 0.06
const PULSE_DECAY_PER_SEC: float = 1.35
const RIPPLE_SPEED_PER_SEC: float = 1.65

const CONTACT_SHADOW_HEIGHT_PX: float = 20.0
const BODY_SHADOW_HEIGHT_PX: float = 12.0
const ROOT_SEAT_HEIGHT_PX: float = 18.0
const ROOT_RIM_HEIGHT_PX: float = 7.0
const ROOT_SEAT_EXTRA_LEN_PX: float = 28.0
const BODY_HEIGHT_PX: float = 11.0
const BODY_SPINE_HEIGHT_PX: float = 4.2
const SEAM_HEIGHT_PX: float = 2.2
const PULSE_HEIGHT_PX: float = 5.4
const BODY_END_NODE_HALF_WIDTH_PX: float = 14.0
const BODY_END_NODE_HALF_HEIGHT_PX: float = 8.5
const BODY_SIDE_INSET_PX: float = 6.0
const FEEDER_LENGTH_PX: float = 18.0
const FEEDER_HALF_WIDTH_PX: float = 3.4
const FEEDER_ATTACH_OFFSET_PX: float = 16.0
const FEEDER_DROP_PX: float = 11.0

const CONTACT_SHADOW_COLOR: Color = Color(0.02, 0.02, 0.03, 0.22)
const BODY_SHADOW_COLOR: Color = Color(0.04, 0.04, 0.05, 0.17)
const ROOT_SEAT_COLOR: Color = Color(0.12, 0.12, 0.13, 0.92)
const ROOT_RIM_COLOR: Color = Color(0.18, 0.18, 0.20, 0.84)
const FEEDER_TRACE_COLOR: Color = Color(0.18, 0.18, 0.20, 0.42)
const BODY_SPINE_COLOR: Color = Color(0.29, 0.30, 0.33, 0.62)
const END_NODE_COLOR: Color = Color(0.16, 0.16, 0.18, 0.96)
const END_NODE_RIDGE_COLOR: Color = Color(0.28, 0.28, 0.31, 0.74)
const SEAM_COLOR: Color = Color(0.61, 0.57, 0.74, 0.38)
const PULSE_COLOR: Color = Color(0.83, 0.81, 0.95, 0.56)

var _segment_length: float = MIN_SEGMENT_LEN_PX
var _heat: float = 0.0
var _pulse: float = 0.0
var _ripple_pos: float = 2.0

var _body_material: ShaderMaterial = null

@onready var _shadow_layer: Node2D = $ShadowLayer
@onready var _root_layer: Node2D = $RootLayer
@onready var _body_layer: Node2D = $BodyLayer
@onready var _fx_layer: Node2D = $FxLayer

@onready var _contact_shadow: Polygon2D = $ShadowLayer/ContactShadow
@onready var _body_shadow: Polygon2D = $ShadowLayer/BodyShadow

@onready var _root_seat: Polygon2D = $RootLayer/RootSeat
@onready var _root_rim: Polygon2D = $RootLayer/RootRim
@onready var _left_feeder_upper: Polygon2D = $RootLayer/LeftFeederUpper
@onready var _left_feeder_lower: Polygon2D = $RootLayer/LeftFeederLower
@onready var _right_feeder_upper: Polygon2D = $RootLayer/RightFeederUpper
@onready var _right_feeder_lower: Polygon2D = $RootLayer/RightFeederLower

@onready var _body_core: Polygon2D = $BodyLayer/BodyCore
@onready var _body_spine: Polygon2D = $BodyLayer/BodySpine
@onready var _left_growth_node: Polygon2D = $BodyLayer/LeftGrowthNode
@onready var _left_growth_ridge: Polygon2D = $BodyLayer/LeftGrowthRidge
@onready var _right_growth_node: Polygon2D = $BodyLayer/RightGrowthNode
@onready var _right_growth_ridge: Polygon2D = $BodyLayer/RightGrowthRidge

@onready var _inner_seam: Polygon2D = $FxLayer/InnerSeam
@onready var _pulse_band: Polygon2D = $FxLayer/PulseBand

func _ready() -> void:
	_apply_layer_depth()
	_configure_materials()
	_rebuild_geometry()
	_apply_visual_state()

func set_segment(a: Vector2, b: Vector2) -> void:
	var delta: Vector2 = b - a
	var center: Vector2 = (a + b) * 0.5
	_segment_length = maxf(MIN_SEGMENT_LEN_PX, delta.length())
	position = center
	rotation = delta.angle()
	_rebuild_geometry()
	_apply_visual_state()

func set_heat(v: float) -> void:
	_heat = clampf(v, 0.0, 1.0)
	_apply_visual_state()

func trigger_block_pulse(_kind: String) -> void:
	_pulse = 1.0
	_heat = clampf(_heat + HEAT_GAIN_PER_BLOCK, 0.0, 1.0)
	_ripple_pos = -0.08
	_apply_visual_state()

func tick_visuals(dt: float) -> void:
	var safe_dt: float = maxf(0.0, dt)
	_heat = move_toward(_heat, 0.0, HEAT_DECAY_PER_SEC * safe_dt)
	_pulse = move_toward(_pulse, 0.0, PULSE_DECAY_PER_SEC * safe_dt)
	if _ripple_pos <= 1.18:
		_ripple_pos += RIPPLE_SPEED_PER_SEC * safe_dt
	_apply_visual_state()

func _apply_layer_depth() -> void:
	_shadow_layer.z_as_relative = false
	_shadow_layer.z_index = SHADOW_Z_INDEX
	_root_layer.z_as_relative = false
	_root_layer.z_index = ROOT_Z_INDEX
	_body_layer.z_as_relative = false
	_body_layer.z_index = BODY_Z_INDEX
	_fx_layer.z_as_relative = false
	_fx_layer.z_index = FX_Z_INDEX

func _configure_materials() -> void:
	_body_material = ShaderMaterial.new()
	_body_material.shader = BODY_SHADER
	_body_core.material = _body_material

func _rebuild_geometry() -> void:
	var root_len: float = _segment_length + ROOT_SEAT_EXTRA_LEN_PX
	var body_len: float = maxf(MIN_SEGMENT_LEN_PX, _segment_length - BODY_SIDE_INSET_PX)
	var end_node_offset: float = body_len * 0.5

	_set_rect_polygon(_contact_shadow, 0.0, 4.8, root_len + 4.0, CONTACT_SHADOW_HEIGHT_PX)
	_set_rect_polygon(_body_shadow, 0.0, 6.2, body_len + 2.0, BODY_SHADOW_HEIGHT_PX)

	_set_rect_polygon(_root_seat, 0.0, 2.5, root_len, ROOT_SEAT_HEIGHT_PX)
	_set_rect_polygon(_root_rim, 0.0, -1.1, root_len - 6.0, ROOT_RIM_HEIGHT_PX)

	_set_feeder_polygon(_left_feeder_upper, -FEEDER_ATTACH_OFFSET_PX, -2.8, -FEEDER_LENGTH_PX, -FEEDER_DROP_PX)
	_set_feeder_polygon(_left_feeder_lower, -FEEDER_ATTACH_OFFSET_PX * 0.25, 3.8, -FEEDER_LENGTH_PX * 0.85, FEEDER_DROP_PX)
	_set_feeder_polygon(_right_feeder_upper, FEEDER_ATTACH_OFFSET_PX, -2.8, FEEDER_LENGTH_PX, -FEEDER_DROP_PX)
	_set_feeder_polygon(_right_feeder_lower, FEEDER_ATTACH_OFFSET_PX * 0.25, 3.8, FEEDER_LENGTH_PX * 0.85, FEEDER_DROP_PX)

	_set_rect_polygon(_body_core, 0.0, -0.8, body_len, BODY_HEIGHT_PX)
	_set_rect_polygon(_body_spine, 0.0, -3.6, body_len - 10.0, BODY_SPINE_HEIGHT_PX)
	_set_growth_node_polygon(_left_growth_node, -end_node_offset, BODY_END_NODE_HALF_WIDTH_PX, BODY_END_NODE_HALF_HEIGHT_PX)
	_set_growth_node_polygon(_right_growth_node, end_node_offset, BODY_END_NODE_HALF_WIDTH_PX, BODY_END_NODE_HALF_HEIGHT_PX)
	_set_growth_ridge_polygon(_left_growth_ridge, -end_node_offset, BODY_END_NODE_HALF_WIDTH_PX * 0.7, BODY_END_NODE_HALF_HEIGHT_PX * 0.35)
	_set_growth_ridge_polygon(_right_growth_ridge, end_node_offset, BODY_END_NODE_HALF_WIDTH_PX * 0.7, BODY_END_NODE_HALF_HEIGHT_PX * 0.35)

	_set_rect_polygon(_inner_seam, 0.0, -1.0, body_len - 16.0, SEAM_HEIGHT_PX)
	_set_rect_polygon(_pulse_band, 0.0, -1.0, 3.0, PULSE_HEIGHT_PX)

func _apply_visual_state() -> void:
	var pulse_energy: float = _pulse * _pulse
	var heat_mix: float = clampf(_heat + pulse_energy * 0.40, 0.0, 1.0)

	_contact_shadow.color = CONTACT_SHADOW_COLOR
	_body_shadow.color = BODY_SHADOW_COLOR
	_contact_shadow.modulate = Color(1.0, 1.0, 1.0, 0.86 + heat_mix * 0.04)
	_body_shadow.modulate = Color(1.0, 1.0, 1.0, 0.86 + heat_mix * 0.06)

	_root_seat.color = ROOT_SEAT_COLOR
	_root_rim.color = ROOT_RIM_COLOR
	_root_rim.modulate = Color(1.0, 1.0, 1.0, 0.86 + heat_mix * 0.10)

	_left_feeder_upper.color = FEEDER_TRACE_COLOR
	_left_feeder_lower.color = FEEDER_TRACE_COLOR
	_right_feeder_upper.color = FEEDER_TRACE_COLOR
	_right_feeder_lower.color = FEEDER_TRACE_COLOR

	_body_spine.color = BODY_SPINE_COLOR
	_body_spine.modulate = Color(1.0, 1.0, 1.0, 0.84 + heat_mix * 0.18)

	_left_growth_node.color = END_NODE_COLOR
	_right_growth_node.color = END_NODE_COLOR
	_left_growth_ridge.color = END_NODE_RIDGE_COLOR.lerp(SEAM_COLOR, heat_mix * 0.35)
	_right_growth_ridge.color = END_NODE_RIDGE_COLOR.lerp(SEAM_COLOR, heat_mix * 0.35)

	_inner_seam.color = SEAM_COLOR.lerp(Color(0.92, 0.90, 0.98, 0.62), heat_mix)
	_inner_seam.modulate = Color(1.0, 1.0, 1.0, 0.62 + pulse_energy * 0.20)

	if _body_material != null:
		_body_material.set_shader_parameter("base_dark", Color(0.11, 0.11, 0.12, 1.0))
		_body_material.set_shader_parameter("base_mid", Color(0.17, 0.17, 0.19, 1.0))
		_body_material.set_shader_parameter("ridge_color", Color(0.28, 0.28, 0.31, 1.0))
		_body_material.set_shader_parameter("seam_color", Color(0.62, 0.58, 0.74, 1.0))
		_body_material.set_shader_parameter("heat", _heat)
		_body_material.set_shader_parameter("pulse", pulse_energy)
		_body_material.set_shader_parameter("shimmer", 0.16)
		_body_material.set_shader_parameter("alpha_scale", 1.0)

	_update_pulse_band()

func _update_pulse_band() -> void:
	if _pulse <= 0.01 or _ripple_pos < -0.05 or _ripple_pos > 1.12:
		_pulse_band.visible = false
		return
	_pulse_band.visible = true
	var body_len: float = maxf(MIN_SEGMENT_LEN_PX, _segment_length - BODY_SIDE_INSET_PX)
	var local_x: float = lerpf(-body_len * 0.5, body_len * 0.5, clampf(_ripple_pos, 0.0, 1.0))
	var pulse_width: float = 8.0 + _heat * 4.0 + _pulse * 5.0
	_set_rect_polygon(_pulse_band, local_x, -1.0, pulse_width, PULSE_HEIGHT_PX)
	_pulse_band.color = PULSE_COLOR
	_pulse_band.modulate = Color(1.0, 1.0, 1.0, 0.18 + _pulse * 0.26)

func _set_rect_polygon(poly: Polygon2D, center_x: float, center_y: float, width_px: float, height_px: float) -> void:
	if poly == null:
		return
	var half_w: float = maxf(0.5, width_px * 0.5)
	var half_h: float = maxf(0.5, height_px * 0.5)
	poly.polygon = PackedVector2Array([
		Vector2(center_x - half_w, center_y - half_h),
		Vector2(center_x + half_w, center_y - half_h),
		Vector2(center_x + half_w, center_y + half_h),
		Vector2(center_x - half_w, center_y + half_h)
	])
	poly.uv = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0)
	])

func _set_feeder_polygon(poly: Polygon2D, attach_x: float, attach_y: float, dx: float, dy: float) -> void:
	if poly == null:
		return
	var start: Vector2 = Vector2(attach_x, attach_y)
	var end: Vector2 = start + Vector2(dx, dy)
	var direction: Vector2 = (end - start).normalized()
	if direction.length_squared() <= 0.000001:
		direction = Vector2.RIGHT
	var normal: Vector2 = Vector2(-direction.y, direction.x) * FEEDER_HALF_WIDTH_PX
	var tail_normal: Vector2 = normal * 0.42
	poly.polygon = PackedVector2Array([
		start - normal,
		start + normal,
		end + tail_normal,
		end - tail_normal
	])

func _set_growth_node_polygon(poly: Polygon2D, center_x: float, half_w: float, half_h: float) -> void:
	if poly == null:
		return
	poly.polygon = PackedVector2Array([
		Vector2(center_x - half_w, -half_h * 0.36),
		Vector2(center_x - half_w * 0.62, -half_h),
		Vector2(center_x + half_w * 0.46, -half_h * 0.86),
		Vector2(center_x + half_w, 0.0),
		Vector2(center_x + half_w * 0.46, half_h * 0.86),
		Vector2(center_x - half_w * 0.62, half_h),
		Vector2(center_x - half_w, half_h * 0.36)
	])

func _set_growth_ridge_polygon(poly: Polygon2D, center_x: float, half_w: float, half_h: float) -> void:
	if poly == null:
		return
	poly.polygon = PackedVector2Array([
		Vector2(center_x - half_w, -half_h * 0.35),
		Vector2(center_x + half_w * 0.42, -half_h),
		Vector2(center_x + half_w, 0.0),
		Vector2(center_x + half_w * 0.42, half_h),
		Vector2(center_x - half_w, half_h * 0.35)
	])
