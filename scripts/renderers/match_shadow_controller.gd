class_name MatchShadowController
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")
const MatchShadowCatalogScript := preload("res://scripts/renderers/match_shadow_catalog.gd")
const HiveGrowthRules := preload("res://scripts/sim/hive_growth_rules.gd")
const SHADOW_SHADER: Shader = preload("res://shaders/match_shadow_mask.gdshader")

const SETTINGS_ENABLED: String = "swarmfront/arena/dynamic_hive_shadows_enabled"
const DEFAULT_ENABLED: bool = false

var _enabled: bool = false
var _catalog: RefCounted = null
var _profiles_by_tier: Dictionary = {}
var _materials_by_tier: Dictionary = {}
var _progress: float = 0.0
var _errors: PackedStringArray = PackedStringArray()

func configure(
	catalog_path: String = MatchShadowCatalogScript.DEFAULT_CATALOG_PATH,
	force_enabled: Variant = null
) -> void:
	clear()
	var setting_enabled: bool = bool(ProjectSettings.get_setting(SETTINGS_ENABLED, DEFAULT_ENABLED))
	_enabled = bool(force_enabled) if force_enabled is bool else setting_enabled
	if not _enabled:
		return
	_catalog = MatchShadowCatalogScript.new()
	# Full pixel validation belongs in the authoring validator. Runtime loading
	# performs schema checks here and rejects missing/unreadable textures below.
	if not _catalog.load_catalog(catalog_path, false, false):
		_errors = _catalog.errors.duplicate()
		_enabled = false
		SFLog.log_once(
			"MATCH_SHADOW_CATALOG_INVALID",
			"Dynamic hive shadows disabled because the catalog or assets are invalid: %s" % str(_errors),
			SFLog.Level.WARN
		)
		return
	if not _catalog.is_catalog_enabled():
		_enabled = false
		return
	_build_profiles(_catalog.data)
	if _profiles_by_tier.is_empty():
		_enabled = false

func configure_from_data(catalog_data: Dictionary) -> void:
	clear()
	_enabled = true
	_catalog = MatchShadowCatalogScript.new()
	_catalog.data = catalog_data.duplicate(true)
	_catalog.errors = MatchShadowCatalogScript.validate_catalog(catalog_data, true, false)
	if not _catalog.errors.is_empty():
		_errors = _catalog.errors.duplicate()
		_enabled = false
		return
	_build_profiles(_catalog.data)
	if _profiles_by_tier.is_empty():
		_enabled = false

func clear() -> void:
	_enabled = false
	_catalog = null
	_profiles_by_tier.clear()
	_materials_by_tier.clear()
	_errors = PackedStringArray()
	_progress = 0.0

func is_enabled() -> bool:
	return _enabled

func errors() -> PackedStringArray:
	return _errors.duplicate()

func update_from_render_model(render_model: Dictionary) -> void:
	var clock_any: Variant = render_model.get("clock", {})
	var clock: Dictionary = clock_any as Dictionary if typeof(clock_any) == TYPE_DICTIONARY else {}
	set_progress(progress_from_clock(clock))

func set_progress(value: float) -> void:
	var next_progress: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(next_progress, _progress) and not _materials_by_tier.is_empty():
		return
	_progress = next_progress
	for tier_any in _materials_by_tier.keys():
		_update_tier_material(int(tier_any))

func progress() -> float:
	return _progress

func presentation_for_tier(tier: int) -> Dictionary:
	if not _enabled or not _profiles_by_tier.has(tier) or not _materials_by_tier.has(tier):
		return {"enabled": false}
	var profile: Dictionary = _profiles_by_tier[tier] as Dictionary
	return {
		"enabled": true,
		"profile_id": str(profile.get("profile_id", "")),
		"tier": tier,
		"material": _materials_by_tier[tier],
		"canvas_texture": profile.get("canvas_texture", null),
		"ground_anchor_px": profile.get("ground_anchor_px", Vector2.ZERO),
		"local_offset": profile.get("local_offset", Vector2.ZERO),
		"scale": float(profile.get("scale", 1.0)),
		"length_scale": float(profile.get("length_scale", 1.0))
	}

func material_for_tier(tier: int) -> ShaderMaterial:
	return _materials_by_tier.get(tier, null) as ShaderMaterial

func debug_snapshot() -> Dictionary:
	return {
		"enabled": _enabled,
		"progress": _progress,
		"profile_tiers": _profiles_by_tier.keys(),
		"material_count": _materials_by_tier.size(),
		"errors": _errors
	}

static func progress_from_clock(clock: Dictionary) -> float:
	var regulation_duration_ms: int = int(clock.get(
		"regulation_duration_ms",
		clock.get("duration_ms", 0)
	))
	if regulation_duration_ms <= 0:
		return 0.0
	if not bool(clock.get("started", false)):
		return 0.0
	if bool(clock.get("in_overtime", false)):
		return 1.0
	var elapsed_ms: int = maxi(0, int(clock.get("elapsed_ms", 0)))
	return clampf(float(elapsed_ms) / float(regulation_duration_ms), 0.0, 1.0)

static func segment_for_progress(keyframes: Array, value: float) -> Dictionary:
	if keyframes.is_empty():
		return {}
	var progress_value: float = clampf(value, 0.0, 1.0)
	if keyframes.size() == 1 or progress_value <= float((keyframes[0] as Dictionary).get("progress", 0.0)):
		return {"a": keyframes[0], "b": keyframes[0], "blend": 0.0}
	for index in range(1, keyframes.size()):
		var frame_b: Dictionary = keyframes[index] as Dictionary
		var progress_b: float = float(frame_b.get("progress", 1.0))
		if progress_value > progress_b:
			continue
		var frame_a: Dictionary = keyframes[index - 1] as Dictionary
		var progress_a: float = float(frame_a.get("progress", 0.0))
		var span: float = maxf(0.000001, progress_b - progress_a)
		return {
			"a": frame_a,
			"b": frame_b,
			"blend": clampf((progress_value - progress_a) / span, 0.0, 1.0)
		}
	var last_frame: Dictionary = keyframes.back() as Dictionary
	return {"a": last_frame, "b": last_frame, "blend": 0.0}

func _build_profiles(catalog_data: Dictionary) -> void:
	var profiles_any: Variant = catalog_data.get("profiles", {})
	if typeof(profiles_any) != TYPE_DICTIONARY:
		return
	var profiles: Dictionary = profiles_any as Dictionary
	for tier_key in ["small", "med", "large"]:
		var raw_any: Variant = profiles.get(tier_key, {})
		if typeof(raw_any) != TYPE_DICTIONARY:
			continue
		var raw: Dictionary = raw_any as Dictionary
		if not bool(raw.get("enabled", true)):
			continue
		var tier: int = _tier_for_key(tier_key)
		var loaded_frames: Array[Dictionary] = []
		for frame_any in raw.get("keyframes", []) as Array:
			if typeof(frame_any) != TYPE_DICTIONARY:
				continue
			var frame: Dictionary = frame_any as Dictionary
			var path: String = str(frame.get("path", ""))
			if not FileAccess.file_exists(path):
				if bool(frame.get("optional", false)):
					continue
				loaded_frames.clear()
				break
			var texture: Texture2D = _load_texture(path)
			if texture == null:
				if bool(frame.get("optional", false)):
					continue
				loaded_frames.clear()
				break
			loaded_frames.append({
				"progress": float(frame.get("progress", 0.0)),
				"path": path,
				"texture": texture,
				"mask_mode": 1.0 if str(frame.get("mask_source", "alpha")) == "luminance_inverse" else 0.0,
				"mask_cutoff": clampf(float(frame.get("mask_cutoff", 0.0)), 0.0, 1.0),
				"mask_softness": clampf(float(frame.get("mask_softness", 0.1)), 0.001, 1.0)
			})
		if loaded_frames.size() < 2:
			continue
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SHADOW_SHADER
		var color := Color(str(raw.get("color", "#15131B")))
		material.set_shader_parameter("shadow_color", color)
		material.set_shader_parameter("shadow_opacity", clampf(float(raw.get("opacity", 0.52)), 0.0, 1.0))
		material.set_shader_parameter("edge_softness_px", clampf(float(raw.get("edge_softness_px", 1.0)), 0.0, 4.0))
		_profiles_by_tier[tier] = {
			"profile_id": "%s:%s" % [tier_key, str(catalog_data.get("version", 1))],
			"ground_anchor_px": MatchShadowCatalogScript.vec2_from_array(raw.get("ground_anchor_px", [])),
			"local_offset": MatchShadowCatalogScript.vec2_from_array(raw.get("local_offset", [])),
			"scale": maxf(0.0001, float(raw.get("scale", 1.0))),
			"length_scale": clampf(float(raw.get("length_scale", 1.0)), 0.01, 1.0),
			"keyframes": loaded_frames,
			"canvas_texture": (loaded_frames[0] as Dictionary).get("texture", null)
		}
		_materials_by_tier[tier] = material
		_update_tier_material(tier)

func _update_tier_material(tier: int) -> void:
	var material: ShaderMaterial = _materials_by_tier.get(tier, null) as ShaderMaterial
	var profile: Dictionary = _profiles_by_tier.get(tier, {}) as Dictionary
	if material == null or profile.is_empty():
		return
	var segment: Dictionary = segment_for_progress(profile.get("keyframes", []) as Array, _progress)
	if segment.is_empty():
		return
	var frame_a: Dictionary = segment.get("a", {}) as Dictionary
	var frame_b: Dictionary = segment.get("b", {}) as Dictionary
	material.set_shader_parameter("mask_a", frame_a.get("texture", null))
	material.set_shader_parameter("mask_b", frame_b.get("texture", null))
	material.set_shader_parameter("mask_mode_a", float(frame_a.get("mask_mode", 0.0)))
	material.set_shader_parameter("mask_mode_b", float(frame_b.get("mask_mode", 0.0)))
	material.set_shader_parameter("mask_cutoff_a", float(frame_a.get("mask_cutoff", 0.0)))
	material.set_shader_parameter("mask_cutoff_b", float(frame_b.get("mask_cutoff", 0.0)))
	material.set_shader_parameter("mask_softness_a", float(frame_a.get("mask_softness", 0.1)))
	material.set_shader_parameter("mask_softness_b", float(frame_b.get("mask_softness", 0.1)))
	material.set_shader_parameter("keyframe_blend", float(segment.get("blend", 0.0)))

static func _load_texture(path: String) -> Texture2D:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path)
		if resource is Texture2D:
			return resource as Texture2D
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

static func _tier_for_key(tier_key: String) -> int:
	match tier_key:
		"med":
			return HiveGrowthRules.TIER_MEDIUM
		"large":
			return HiveGrowthRules.TIER_LARGE
		_:
			return HiveGrowthRules.TIER_SMALL
