extends SceneTree

const LANE_RENDERER_PATH := "res://scripts/renderers/lane_renderer.gd"
const LaneBandShader := preload("res://shaders/lane_band.gdshader")

var _failed := false

func _init() -> void:
	await process_frame
	var renderer_source := FileAccess.get_file_as_string(LANE_RENDERER_PATH)
	var shader_source := LaneBandShader.code
	_expect(renderer_source.contains("mat.set_shader_parameter(\"team_saturation\", 1.0)"), "lane material must preserve the owning team hue")
	_expect(renderer_source.contains("const LANE_BASE_BRIGHTNESS: float = 0.68"), "lane material must retain the calibrated satin brightness")
	_expect(renderer_source.contains("mat.set_shader_parameter(\"highlight_boost\", 0.05)"), "lane highlights must remain shallow")
	_expect(renderer_source.contains("mat.set_shader_parameter(\"glow_boost\", 0.0)"), "lane material must disable additive glow")
	_expect(renderer_source.contains("mat.set_shader_parameter(\"surface_variation\", 0.10)"), "lane surface must use compressed eggshell variation")
	_expect(renderer_source.contains("const LANE_ENDPOINT_TAPER_FRACTION: float = 0.15"), "lane taper must occupy the final 15 percent at each hive")
	_expect(renderer_source.contains("const LANE_ENDPOINT_WIDTH_SCALE: float = 0.75"), "lane endpoints must narrow by 25 percent")
	_expect(renderer_source.contains("lane_mat.set_shader_parameter(\"lane_u_start\""), "each rendered lane piece must retain its canonical full-lane position")
	_expect(renderer_source.contains("_get_lane_band_material().duplicate() as ShaderMaterial"), "persistent lane pieces must own reusable taper parameters")
	_expect(shader_source.contains("float endpoint_distance = min(lane_u, 1.0 - lane_u)"), "lane shader must taper both hive endpoints")
	_expect(shader_source.contains("float width_scale = mix(endpoint_width_scale, 1.0, endpoint_blend)"), "lane taper must smoothly restore full width toward the middle")
	_expect(shader_source.contains("vec2 tapered_uv = vec2(UV.x"), "lane taper must resample the visible rail and arrow artwork")
	_expect(shader_source.contains("vec3 satin_surface = mix"), "lane shader must blend highlights instead of adding them")
	_expect(shader_source.contains("vec3 recolor = satin_surface + glow"), "lane shader must expose only the explicitly controlled glow term")
	if _failed:
		quit(1)
		return
	print("LANE_SATIN_PRESENTATION_SMOKE: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("LANE_SATIN_PRESENTATION_SMOKE: %s" % message)
