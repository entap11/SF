class_name HiveGeometry
extends RefCounted

# Single source of truth for hive base geometry used by both visuals and LOS occlusion.
const BASE_DIAMETER_PX: float = 64.8
const BASE_RADIUS_PX: float = BASE_DIAMETER_PX * 0.5

# Keep LOS occlusion coupled to rendered hive size: changing base radius changes occlusion.
const LANE_OCCLUSION_RADIUS_SCALE: float = 1.0
const DEFAULT_LANE_BODY_HALF_WIDTH_PX: float = 28.0
const DEFAULT_LANE_OCCLUSION_PAD_PX: float = 8.0
const TIER_2_MIN_POWER := 10
const TIER_3_MIN_POWER := 25
const TIER_4_MIN_POWER := 50

# Approximate the cropped hive sprite footprint after HiveVisual's current
# tier/manifest scaling. This blocks lanes against the art, not just gameplay radius.
const HIVE_VISUAL_FOOTPRINT_SCALE_SMALL: float = 3.15
const HIVE_VISUAL_FOOTPRINT_SCALE_MED: float = 3.45
const HIVE_VISUAL_FOOTPRINT_SCALE_LARGE: float = 3.95
const HIVE_VISUAL_FOOTPRINT_SCALE_MAX: float = 4.40

static func lane_occlusion_radius_px(base_radius_px: float) -> float:
	var radius: float = maxf(1.0, base_radius_px)
	return radius * LANE_OCCLUSION_RADIUS_SCALE

static func hive_visual_footprint_radius_px(base_radius_px: float, power: int = 0) -> float:
	var radius: float = maxf(1.0, base_radius_px)
	var scale: float = HIVE_VISUAL_FOOTPRINT_SCALE_SMALL
	if power >= TIER_4_MIN_POWER:
		scale = HIVE_VISUAL_FOOTPRINT_SCALE_MAX
	elif power >= TIER_3_MIN_POWER:
		scale = HIVE_VISUAL_FOOTPRINT_SCALE_LARGE
	elif power >= TIER_2_MIN_POWER:
		scale = HIVE_VISUAL_FOOTPRINT_SCALE_MED
	return radius * scale

static func lane_block_radius_px(
	base_radius_px: float,
	power: int = 0,
	lane_half_width_px: float = DEFAULT_LANE_BODY_HALF_WIDTH_PX,
	pad_px: float = DEFAULT_LANE_OCCLUSION_PAD_PX
) -> float:
	var visual_radius: float = hive_visual_footprint_radius_px(base_radius_px, power)
	return lane_occlusion_radius_px(visual_radius) + maxf(0.0, lane_half_width_px) + maxf(0.0, pad_px)
