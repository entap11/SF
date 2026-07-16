extends SceneTree

const UNIT_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/unit_v5.png"
const UNIT_IMPORT_PATH: String = "res://assets/sprites/sf_skin_v1/unit_v5.png.import"
const MANIFEST_PATH: String = "res://assets/sprites/sf_skin_v1/skin_manifest.json"
const UNIT_RENDERER_PATH: String = "res://scripts/renderers/unit_renderer.gd"
const LANE_RENDERER_PATH: String = "res://scripts/renderers/lane_renderer.gd"
const UnitShader := preload("res://shaders/sf_colorkey_alpha.gdshader")
const NeutralUnitShader := preload("res://shaders/team_glow_recolor.gdshader")
const UnitEmissionShader := preload("res://shaders/unit_emission.gdshader")

const UNIT_BASE_DIAMETER_PX: float = 20.0
const UNIT_RENDER_SCALE: float = 1.44
const UNIT_VISUAL_SCALE_MULT: float = 0.88
const LANE_UNIT_SCALE_MATCH: float = 1.44
const LANE_NARROW_WIDTH_MULTIPLIER: float = 0.50

var _failed: bool = false

func _init() -> void:
	await process_frame
	_validate_asset_alpha_and_lane_fit()
	_validate_manifest()
	_validate_renderer_contract()
	if _failed:
		quit(1)
		return
	print("UNIT_V5_PRESENTATION_SMOKE: PASS")
	quit(0)

func _validate_asset_alpha_and_lane_fit() -> void:
	var imported_texture: Texture2D = load(UNIT_TEXTURE_PATH) as Texture2D
	_expect(imported_texture != null, "unit_v5 must load through Godot's texture importer")
	var absolute_path: String = ProjectSettings.globalize_path(UNIT_TEXTURE_PATH)
	var image: Image = Image.load_from_file(absolute_path)
	_expect(image != null and not image.is_empty(), "unit_v5 image must load")
	if image == null or image.is_empty():
		return
	_expect(image.get_width() == 1254 and image.get_height() == 1254, "unit_v5 canvas must remain 1254x1254")
	_expect(image.get_pixel(0, 0).a <= 0.001, "unit_v5 corner must be transparent")
	_expect(image.get_pixel(image.get_width() / 2, image.get_height() / 2).a >= 0.99, "unit_v5 body center must be opaque")

	var min_x: int = image.get_width()
	var max_x: int = -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a < 0.5:
				continue
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
	_expect(max_x >= min_x, "unit_v5 must contain opaque sprite pixels")
	if max_x < min_x:
		return

	var manifest: Dictionary = _manifest_root()
	var sprites: Dictionary = manifest.get("sprites", {}) as Dictionary
	var unit_p1: Dictionary = sprites.get("unit.p1", {}) as Dictionary
	var registry_scale: float = float(unit_p1.get("scale", 0.0))
	var opaque_width_ratio: float = float(max_x - min_x + 1) / float(image.get_width())
	var rendered_box_px: float = UNIT_BASE_DIAMETER_PX * registry_scale * UNIT_RENDER_SCALE * UNIT_VISUAL_SCALE_MULT
	var rendered_hard_width_px: float = rendered_box_px * opaque_width_ratio
	var lane_width_px: float = UNIT_BASE_DIAMETER_PX * registry_scale * LANE_UNIT_SCALE_MATCH * LANE_NARROW_WIDTH_MULTIPLIER
	_expect(rendered_hard_width_px <= lane_width_px + 1.0, "unit_v5 hard silhouette should fit within one pixel of the lane width")

func _validate_manifest() -> void:
	var manifest: Dictionary = _manifest_root()
	var sprites: Dictionary = manifest.get("sprites", {}) as Dictionary
	for key in ["unit.neutral", "unit.p1", "unit.p2", "unit.p3", "unit.p4"]:
		var entry: Dictionary = sprites.get(key, {}) as Dictionary
		_expect(str(entry.get("path", "")) == UNIT_TEXTURE_PATH, "%s must resolve to unit_v5" % key)
		_expect(str(entry.get("key_color", "")).to_lower() == "#ff00ff", "%s must key the generated edge matte's magenta fringe" % key)

func _validate_renderer_contract() -> void:
	var unit_renderer_source: String = FileAccess.get_file_as_string(UNIT_RENDERER_PATH)
	var lane_renderer_source: String = FileAccess.get_file_as_string(LANE_RENDERER_PATH)
	var import_source: String = FileAccess.get_file_as_string(UNIT_IMPORT_PATH)
	_expect(unit_renderer_source.contains("const UNIT_OUTLINE_ENABLED: bool = false"), "scaled duplicate outline must stay disabled for unit_v5")
	_expect(unit_renderer_source.contains("TEXTURE_FILTER_LINEAR_WITH_MIPMAPS"), "production sprites must use mipmapped minification filtering")
	_expect(import_source.contains("mipmaps/generate=true"), "unit_v5 import must generate mipmaps for gameplay-scale minification")
	_expect(unit_renderer_source.contains("const UNIT_RENDER_SCALE: float = %.2f" % UNIT_RENDER_SCALE), "smoke-test unit render scale must match the renderer")
	_expect(unit_renderer_source.contains("const UNIT_VISUAL_SCALE_MULT: float = %.2f" % UNIT_VISUAL_SCALE_MULT), "smoke-test visual scale must match the renderer")
	_expect(lane_renderer_source.contains("const UNIT_RENDER_SCALE_MATCH: float = %.2f" % LANE_UNIT_SCALE_MATCH), "smoke-test lane unit scale must match the renderer")
	_expect(lane_renderer_source.contains("const LANE_NARROW_WIDTH_MULTIPLIER := %.2f" % LANE_NARROW_WIDTH_MULTIPLIER), "smoke-test lane width multiplier must match the renderer")
	var shader_code: String = UnitShader.code
	_expect(shader_code.contains("body_glow_strength"), "unit shader must expose body emission")
	_expect(shader_code.contains("body_halo_radius_uv"), "unit shader must expose body halo geometry")
	_expect(shader_code.contains("body_mask_at"), "unit shader must keep body emission spatially separate from wings")
	_expect(shader_code.contains("body_burst"), "unit shader must apply the abdomen-specific burst curve")
	_expect(unit_renderer_source.contains("_mat_set(mat, \"body_glow_strength\", 2.60)"), "player unit abdomen must use the deliberate overshoot emission")
	_expect(unit_renderer_source.contains("_mat_set(mat, \"body_halo_alpha\", 0.0)"), "base unit pass must not synthesize a silhouette halo")
	_expect(unit_renderer_source.contains("UnitEmissionSprite"), "renderer must create a dedicated pooled emission pass")
	_expect(unit_renderer_source.contains("_bee_clip_emission_by_unit_id"), "emission pass must share unit clipping lifecycle")
	var emission_code: String = UnitEmissionShader.code
	_expect(emission_code.contains("render_mode blend_add, unshaded"), "unit emission must use additive unshaded blending")
	_expect(emission_code.contains("emission_mask = alpha"), "unit emission alpha must remain bounded by source texture alpha")
	_expect(not emission_code.contains("UV +"), "unit emission must not sample neighboring pixels into a halo")
	var neutral_shader_code: String = NeutralUnitShader.code
	_expect(neutral_shader_code.contains("body_glow_strength"), "neutral unit shader must expose body emission")
	_expect(neutral_shader_code.contains("body_burst"), "neutral unit shader must apply the abdomen-specific burst curve")
	_expect(neutral_shader_code.contains("key_enabled"), "neutral unit shader must remove the same edge matte as player units")
	_expect(unit_renderer_source.contains("_mat_set(mat, \"key_enabled\", 1.0)"), "neutral unit material must enable its bounded edge key")
	_expect(unit_renderer_source.contains("_mat_set(mat, \"body_glow_strength\", 1.80)"), "neutral unit material must enable strong body emission")

func _manifest_root() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(text)
	_expect(typeof(parsed) == TYPE_DICTIONARY, "skin manifest must parse")
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("UNIT_V5_PRESENTATION_SMOKE: %s" % message)
