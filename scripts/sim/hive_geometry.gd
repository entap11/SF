class_name HiveGeometry
extends RefCounted

# Single source of truth for hive base geometry used by both visuals and LOS occlusion.
const BASE_DIAMETER_PX: float = 54.0
const BASE_RADIUS_PX: float = BASE_DIAMETER_PX * 0.5

# Keep LOS occlusion coupled to rendered hive size: changing base radius changes occlusion.
const LANE_OCCLUSION_RADIUS_SCALE: float = 1.0

static func lane_occlusion_radius_px(base_radius_px: float) -> float:
	var radius: float = maxf(1.0, base_radius_px)
	return radius * LANE_OCCLUSION_RADIUS_SCALE
