class_name MatchShadowCatalog
extends RefCounted

const DEFAULT_CATALOG_PATH: String = "res://assets/sprites/sf_skin_v1/match_shadows.json"
const REQUIRED_PROFILE_KEYS: PackedStringArray = [
	"ground_anchor_px",
	"local_offset",
	"scale",
	"opacity",
	"color",
	"keyframes"
]
const ALPHA_FORMATS: Array[int] = [
	Image.FORMAT_LA8,
	Image.FORMAT_RGBA8,
	Image.FORMAT_RGBA4444,
	Image.FORMAT_RGBAF,
	Image.FORMAT_RGBAH
]
const CORNER_ALPHA_MAX: float = 0.02
const MIN_TRANSPARENT_PADDING_PX: int = 2

var catalog_path: String = DEFAULT_CATALOG_PATH
var data: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()

func load_catalog(
	path: String = DEFAULT_CATALOG_PATH,
	validate_assets: bool = true,
	include_disabled_profiles: bool = false
) -> bool:
	catalog_path = path
	data = load_catalog_data(path)
	errors = validate_catalog(data, validate_assets, include_disabled_profiles)
	return not data.is_empty() and errors.is_empty()

func profile_for_tier_key(tier_key: String) -> Dictionary:
	var profiles_any: Variant = data.get("profiles", {})
	if typeof(profiles_any) != TYPE_DICTIONARY:
		return {}
	var profile_any: Variant = (profiles_any as Dictionary).get(tier_key, {})
	if typeof(profile_any) != TYPE_DICTIONARY:
		return {}
	return (profile_any as Dictionary).duplicate(true)

func is_catalog_enabled() -> bool:
	return bool(data.get("enabled", true))

static func load_catalog_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

static func validate_catalog(
	catalog: Dictionary,
	validate_assets: bool = true,
	include_disabled_profiles: bool = false
) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if catalog.is_empty():
		out.append("catalog_missing_or_invalid")
		return out
	if int(catalog.get("version", 0)) <= 0:
		out.append("catalog.version must be positive")
	var profiles_any: Variant = catalog.get("profiles", {})
	if typeof(profiles_any) != TYPE_DICTIONARY:
		out.append("catalog.profiles must be a dictionary")
		return out
	var profiles: Dictionary = profiles_any as Dictionary
	for tier_key in ["small", "med", "large"]:
		var profile_any: Variant = profiles.get(tier_key, {})
		if typeof(profile_any) != TYPE_DICTIONARY:
			out.append("%s profile must be a dictionary" % tier_key)
			continue
		var profile: Dictionary = profile_any as Dictionary
		var profile_enabled: bool = bool(profile.get("enabled", true))
		if not profile_enabled and not include_disabled_profiles:
			continue
		_validate_profile_schema(tier_key, profile, out)
		if validate_assets and profile_enabled:
			_validate_profile_assets(tier_key, profile, out)
	return out

static func _validate_profile_schema(
	tier_key: String,
	profile: Dictionary,
	out: PackedStringArray
) -> void:
	for required_key in REQUIRED_PROFILE_KEYS:
		if not profile.has(required_key):
			out.append("%s.%s is required" % [tier_key, required_key])
	if not _is_vec2_array(profile.get("ground_anchor_px", null)):
		out.append("%s.ground_anchor_px must contain two numbers" % tier_key)
	if not _is_vec2_array(profile.get("local_offset", null)):
		out.append("%s.local_offset must contain two numbers" % tier_key)
	if float(profile.get("scale", 0.0)) <= 0.0:
		out.append("%s.scale must be positive" % tier_key)
	var length_scale: float = float(profile.get("length_scale", 1.0))
	if length_scale <= 0.0 or length_scale > 1.0:
		out.append("%s.length_scale must be within 0..1" % tier_key)
	var edge_softness_px: float = float(profile.get("edge_softness_px", 1.0))
	if edge_softness_px < 0.0 or edge_softness_px > 4.0:
		out.append("%s.edge_softness_px must be within 0..4" % tier_key)
	var opacity: float = float(profile.get("opacity", -1.0))
	if opacity < 0.0 or opacity > 1.0:
		out.append("%s.opacity must be within 0..1" % tier_key)
	if not Color.html_is_valid(str(profile.get("color", ""))):
		out.append("%s.color must be a valid HTML color" % tier_key)
	var keyframes_any: Variant = profile.get("keyframes", [])
	if typeof(keyframes_any) != TYPE_ARRAY:
		out.append("%s.keyframes must be an array" % tier_key)
		return
	var keyframes: Array = keyframes_any as Array
	if keyframes.is_empty():
		out.append("%s.keyframes must not be empty" % tier_key)
		return
	var previous_progress: float = -1.0
	var effective_progresses: Array[float] = []
	for index in range(keyframes.size()):
		var frame_any: Variant = keyframes[index]
		if typeof(frame_any) != TYPE_DICTIONARY:
			out.append("%s.keyframes[%d] must be a dictionary" % [tier_key, index])
			continue
		var frame: Dictionary = frame_any as Dictionary
		var progress: float = float(frame.get("progress", -1.0))
		if progress < 0.0 or progress > 1.0:
			out.append("%s.keyframes[%d].progress must be within 0..1" % [tier_key, index])
		if progress <= previous_progress:
			out.append("%s.keyframes must be strictly ordered" % tier_key)
		previous_progress = progress
		var path: String = str(frame.get("path", "")).strip_edges()
		if path.is_empty():
			out.append("%s.keyframes[%d].path is required" % [tier_key, index])
		if not bool(frame.get("optional", false)):
			effective_progresses.append(progress)
	if effective_progresses.is_empty():
		out.append("%s requires non-optional endpoint keyframes" % tier_key)
		return
	if not is_equal_approx(effective_progresses.front(), 0.0):
		out.append("%s requires a non-optional keyframe at progress 0.0" % tier_key)
	if not is_equal_approx(effective_progresses.back(), 1.0):
		out.append("%s requires a non-optional keyframe at progress 1.0" % tier_key)

static func _validate_profile_assets(
	tier_key: String,
	profile: Dictionary,
	out: PackedStringArray
) -> void:
	var expected_size: Vector2i = Vector2i.ZERO
	var allow_mismatched_canvases: bool = bool(profile.get("allow_mismatched_canvases", false))
	var keyframes: Array = profile.get("keyframes", []) as Array
	for index in range(keyframes.size()):
		var frame: Dictionary = keyframes[index] as Dictionary
		var path: String = str(frame.get("path", "")).strip_edges()
		var optional: bool = bool(frame.get("optional", false))
		if not FileAccess.file_exists(path):
			if not optional:
				out.append("%s keyframe asset missing: %s" % [tier_key, path])
			continue
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			out.append("%s keyframe image unreadable: %s" % [tier_key, path])
			continue
		var mask_source: String = str(frame.get("mask_source", "alpha"))
		if not (mask_source in ["alpha", "luminance_inverse"]):
			out.append("%s keyframe has unsupported mask_source: %s" % [tier_key, mask_source])
			continue
		if mask_source == "alpha" and not (int(image.get_format()) in ALPHA_FORMATS):
			out.append("%s alpha keyframe lacks an alpha channel: %s" % [tier_key, path])
			continue
		var image_size := Vector2i(image.get_width(), image.get_height())
		if expected_size == Vector2i.ZERO:
			expected_size = image_size
		elif image_size != expected_size and not allow_mismatched_canvases:
			out.append("%s keyframe canvas mismatch: %s" % [tier_key, path])
		if mask_source == "alpha":
			for corner in [
				Vector2i(0, 0),
				Vector2i(image.get_width() - 1, 0),
				Vector2i(0, image.get_height() - 1),
				Vector2i(image.get_width() - 1, image.get_height() - 1)
			]:
				if image.get_pixelv(corner).a > CORNER_ALPHA_MAX:
					out.append("%s keyframe corner is not transparent: %s" % [tier_key, path])
					break
			var opaque_bounds: Rect2i = _alpha_bounds(image)
			if opaque_bounds.size == Vector2i.ZERO:
				out.append("%s keyframe contains no visible alpha mask: %s" % [tier_key, path])
				continue
			var right_padding: int = image.get_width() - opaque_bounds.end.x
			var bottom_padding: int = image.get_height() - opaque_bounds.end.y
			if (
				opaque_bounds.position.x < MIN_TRANSPARENT_PADDING_PX
				or opaque_bounds.position.y < MIN_TRANSPARENT_PADDING_PX
				or right_padding < MIN_TRANSPARENT_PADDING_PX
				or bottom_padding < MIN_TRANSPARENT_PADDING_PX
			):
				out.append("%s keyframe lacks transparent clipping padding: %s" % [tier_key, path])

static func _is_vec2_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var values: Array = value as Array
	if values.size() < 2:
		return false
	return (values[0] is int or values[0] is float) and (values[1] is int or values[1] is float)

static func _alpha_bounds(image: Image) -> Rect2i:
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= CORNER_ALPHA_MAX:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, (max_x - min_x) + 1, (max_y - min_y) + 1)

static func vec2_from_array(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if not _is_vec2_array(value):
		return fallback
	var values: Array = value as Array
	return Vector2(float(values[0]), float(values[1]))
