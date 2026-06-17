extends RefCounted
class_name ArenaPolishPlacementPolicy

const SAFE_ZONES: Array = [
	"arena_dead_space",
	"outer_floor_edges",
	"lane_edges",
	"hq_adjacency_glow",
	"corner_atmosphere"
]

const FORBIDDEN_ZONES: Array = [
	"active_lane_core",
	"hive_body",
	"tower_body",
	"barracks_body",
	"unit_path_core",
	"ui",
	"tap_target_area"
]

const DEFAULT_MAX_Z_INDEX: int = -11
const DEFAULT_MIN_OPACITY: float = 0.0
const DEFAULT_MAX_OPACITY: float = 0.85
const DEFAULT_MIN_SCALE: float = 0.1
const DEFAULT_MAX_SCALE: float = 2.0

static func safe_zones() -> PackedStringArray:
	return PackedStringArray(SAFE_ZONES)

static func forbidden_zones() -> PackedStringArray:
	return PackedStringArray(FORBIDDEN_ZONES)

static func is_safe_zone(zone: String) -> bool:
	return zone.strip_edges().to_lower() in SAFE_ZONES

static func is_forbidden_zone(zone: String) -> bool:
	return zone.strip_edges().to_lower() in FORBIDDEN_ZONES

static func validate_defaults(errors: PackedStringArray, defaults: Dictionary) -> void:
	_validate_zone_array(errors, "defaults_allowed_placement_zones", defaults.get("allowed_placement_zones", []), true)
	_validate_forbidden_array(errors, "defaults_forbidden_overlap", defaults.get("forbidden_overlap", []), true)
	var max_z: int = int(defaults.get("allowed_z_index_max", DEFAULT_MAX_Z_INDEX))
	if max_z > DEFAULT_MAX_Z_INDEX:
		errors.append("defaults_allowed_z_index_too_high")
	if int(defaults.get("mobile_total_instance_limit", 0)) <= 0:
		errors.append("mobile_total_instance_limit_missing")
	_validate_range(errors, "defaults_opacity_range", defaults.get("opacity_range", []), DEFAULT_MIN_OPACITY, DEFAULT_MAX_OPACITY)
	_validate_range(errors, "defaults_scale_range", defaults.get("scale_range", []), DEFAULT_MIN_SCALE, DEFAULT_MAX_SCALE)

static func validate_entry(errors: PackedStringArray, prefix: String, entry: Dictionary, defaults: Dictionary) -> void:
	_validate_zone_array(errors, "%s_allowed_placement_zones" % prefix, entry.get("allowed_placement_zones", defaults.get("allowed_placement_zones", [])), true)
	_validate_forbidden_array(errors, "%s_forbidden_overlap" % prefix, entry.get("forbidden_overlap", defaults.get("forbidden_overlap", [])), false)
	var z_index: int = int(entry.get("z_index", defaults.get("allowed_z_index_max", DEFAULT_MAX_Z_INDEX)))
	var max_z: int = int(defaults.get("allowed_z_index_max", DEFAULT_MAX_Z_INDEX))
	if z_index > max_z:
		errors.append("%s_z_index_above_safe_max" % prefix)
	if int(entry.get("max_instances", 1)) <= 0:
		errors.append("%s_max_instances_missing" % prefix)
	if bool(entry.get("affects_gameplay", false)):
		errors.append("%s_affects_gameplay_true" % prefix)

static func _validate_zone_array(errors: PackedStringArray, label: String, zones_v: Variant, require_nonempty: bool) -> void:
	if typeof(zones_v) != TYPE_ARRAY:
		errors.append("%s_not_array" % label)
		return
	var zones: Array = zones_v as Array
	if require_nonempty and zones.is_empty():
		errors.append("%s_missing" % label)
	for zone_any in zones:
		var zone: String = str(zone_any).strip_edges().to_lower()
		if zone.is_empty():
			errors.append("%s_empty_zone" % label)
		elif is_forbidden_zone(zone):
			errors.append("%s_uses_forbidden_zone_%s" % [label, zone])
		elif not is_safe_zone(zone):
			errors.append("%s_unknown_zone_%s" % [label, zone])

static func _validate_forbidden_array(errors: PackedStringArray, label: String, zones_v: Variant, require_nonempty: bool) -> void:
	if typeof(zones_v) != TYPE_ARRAY:
		errors.append("%s_not_array" % label)
		return
	var zones: Array = zones_v as Array
	if require_nonempty and zones.is_empty():
		errors.append("%s_missing" % label)
	for zone_any in zones:
		var zone: String = str(zone_any).strip_edges().to_lower()
		if zone.is_empty():
			errors.append("%s_empty_zone" % label)
		elif not is_forbidden_zone(zone):
			errors.append("%s_unknown_forbidden_zone_%s" % [label, zone])

static func _validate_range(errors: PackedStringArray, label: String, range_v: Variant, min_allowed: float, max_allowed: float) -> void:
	if typeof(range_v) != TYPE_ARRAY:
		errors.append("%s_not_array" % label)
		return
	var values: Array = range_v as Array
	if values.size() != 2:
		errors.append("%s_invalid_size" % label)
		return
	var low: float = float(values[0])
	var high: float = float(values[1])
	if low < min_allowed or high > max_allowed or low > high:
		errors.append("%s_out_of_bounds" % label)
