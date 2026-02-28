extends RefCounted
class_name EdgeVisual

const LANE_NORMAL_OFFSET_PX: float = 0.0
const UNIT_NORMAL_OFFSET_PX: float = 0.0
const UNIT_LIFT_Y_PX: float = -4.0

static func apply_normal_offset(p: Vector2, normal: Vector2, px: float) -> Vector2:
	return p + normal * px

static func apply_lift(p: Vector2, lift_y: float) -> Vector2:
	return p + Vector2(0.0, lift_y)

static func lane_point(p: Vector2, normal: Vector2) -> Vector2:
	var out_p: Vector2 = p
	out_p = apply_normal_offset(out_p, normal, LANE_NORMAL_OFFSET_PX)
	return out_p

static func unit_point(p: Vector2, normal: Vector2) -> Vector2:
	var out_p: Vector2 = p
	out_p = apply_normal_offset(out_p, normal, UNIT_NORMAL_OFFSET_PX)
	out_p = apply_lift(out_p, UNIT_LIFT_Y_PX)
	return out_p
