extends Node2D

const P1_TEXT_COLOR = Color(0.0, 0.0, 0.0)
const P2_TEXT_COLOR = Color(1.0, 1.0, 1.0)
const SpriteRegistry = preload("res://scripts/renderers/sprite_registry.gd")
const RenderTuning = preload("res://scripts/renderers/render_tuning.gd")
const SFLog = preload("res://scripts/util/sf_log.gd")
const COLORKEY_SHADER = preload("res://shaders/sf_colorkey_alpha.gdshader")
@export var debug_show_kind_label = false

var radius_px: float = 18.0
var owner_color: Color = Color(1.0, 1.0, 1.0)
var owner_id: int = 0
var power: int = 0
var font_size: int = 14
var hive_kind: String = "Hive"
var _tex: Texture2D = null
var _sprite_key: String = ""
var _sprite_scale: float = 1.0
var _sprite_offset: Vector2 = Vector2.ZERO
var _last_log_scale: Vector2 = Vector2.ZERO
var _last_log_global_scale: Vector2 = Vector2.ZERO
var _last_log_sprite_key: String = ""
var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = COLORKEY_SHADER
	_base_scale = scale

func configure(owner_id_value: int, color: Color, radius: float, power_value: int, font_size_value: int, kind_value: String = "Hive") -> void:
	scale = _base_scale
	owner_id = owner_id_value
	owner_color = color
	radius_px = radius
	power = power_value
	font_size = font_size_value
	hive_kind = kind_value
	SFLog.log_once(
		"HIVEVIS_CONFIGURE",
		"HiveVisual.configure called: owner=%s power=%s kind=%s radius=%s" % [str(owner_id), str(power), str(hive_kind), str(radius_px)],
		SFLog.Level.INFO
	)
	var kind_key = SpriteRegistry.hive_size_key(hive_kind, power)
	var key = "hive.%s.%s" % [
		kind_key,
		SpriteRegistry.owner_key(owner_id)
	]
	var scale_key = "hive.%s.neutral" % [kind_key]
	SFLog.log_once(
		"HIVE_SPRITE_KEY_SAMPLE",
		"Hive sprite key sample: kind=%s kind_key=%s owner=%s power=%s key=%s" % [str(hive_kind), str(kind_key), str(owner_id), str(power), key],
		SFLog.Level.INFO
	)
	var registry = SpriteRegistry.get_instance()
	_tex = registry.get_tex(key) if registry != null else null
	_sprite_key = key
	if registry != null:
		if registry.has_tex(scale_key):
			_sprite_scale = registry.get_scale(scale_key)
		else:
			_sprite_scale = registry.get_scale(key)
	else:
		_sprite_scale = 1.0
	_sprite_offset = Vector2.ZERO
	if material is ShaderMaterial:
		var mat = material as ShaderMaterial
		var ck_color = Color(0.0, 0.0, 0.0, 1.0)
		var ck_threshold = 0.28
		var ck_softness = 0.10
		if registry != null:
			var ck = registry.get_colorkey(key)
			if bool(ck.get("enabled", false)):
				ck_color = ck.get("color", ck_color)
				ck_threshold = float(ck.get("threshold", ck_threshold))
				ck_softness = float(ck.get("softness", ck_softness))
		mat.set_shader_parameter("key_color", ck_color)
		mat.set_shader_parameter("threshold", ck_threshold)
		mat.set_shader_parameter("softness", ck_softness)
	if _tex == null:
		SFLog.log_once(
			"HIVE_SPRITE_MISSING_" + key,
			"Hive sprite missing key=" + key + " kind=" + hive_kind + " power=" + str(power) + " owner_id=" + str(owner_id),
			SFLog.Level.WARN
		)
	var current_scale: Vector2 = scale
	var current_global_scale: Vector2 = global_transform.get_scale()
	var scale_changed: bool = current_scale != _last_log_scale or current_global_scale != _last_log_global_scale
	var sprite_changed: bool = _sprite_key != _last_log_sprite_key
	if scale_changed:
		_last_log_scale = current_scale
		_last_log_global_scale = current_global_scale
	if sprite_changed:
		_last_log_sprite_key = _sprite_key
	if scale_changed or sprite_changed:
		var tex_size: Vector2 = Vector2.ZERO
		if _tex != null:
			tex_size = Vector2(float(_tex.get_width()), float(_tex.get_height()))
		var parent_path: String = "<none>"
		var parent = get_parent()
		if parent != null:
			parent_path = str(parent.get_path())
		SFLog.debug_log(1, "HIVE_VISUAL_CHANGE " + str({
			"event": "configure",
			"node": name,
			"owner_id": owner_id,
			"power": power,
			"kind": hive_kind,
			"node_scale": current_scale,
			"node_global_scale": current_global_scale,
			"tex_size": tex_size,
			"sprite_key": _sprite_key,
			"parent": parent_path,
			"path": str(get_path())
		}))
	queue_redraw()

func _draw() -> void:
	SFLog.log_once("HIVEVIS_DRAW", "HiveVisual._draw ran", SFLog.Level.INFO)
	var draw_radius = radius_px * RenderTuning.HIVE_SCALE_MUL
	if _tex != null:
		SFLog.log_once(
			"HIVE_TEX_INFO",
			_hive_tex_debug(_tex, _sprite_key, _sprite_scale, _sprite_offset),
			SFLog.Level.INFO
		)
		var size = Vector2(draw_radius * 2.0, draw_radius * 2.0) * _sprite_scale
		var rect = Rect2(-size * 0.5 + _sprite_offset, size)
		draw_texture_rect(_tex, rect, false)
	else:
		draw_circle(Vector2.ZERO, draw_radius, owner_color)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text = str(power)
	var size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos = -size * 0.5 + Vector2(0.0, size.y * 0.35)
	var text_color = Color(1.0, 1.0, 1.0, 1.0)
	var shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	if debug_show_kind_label:
		var kind_pos = pos + Vector2(0.0, font_size * 1.2)
		draw_string(font, kind_pos, hive_kind, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

func _hive_tex_debug(tex: Texture2D, key: String, scale: float, offset: Vector2) -> String:
	var region_enabled = false
	var region_rect = Rect2()
	var base_path = ""
	if tex is AtlasTexture:
		var atlas = tex as AtlasTexture
		region_enabled = true
		region_rect = atlas.region
		if atlas.atlas != null:
			base_path = str(atlas.atlas.resource_path)
	var img = tex.get_image() if tex != null else null
	var alpha_info = "unknown"
	if img != null:
		alpha_info = str(img.get_format() in [
			Image.FORMAT_RGBA8,
			Image.FORMAT_RGBAF,
			Image.FORMAT_RGBAH,
			Image.FORMAT_RGBA4444
		])
	return "key=%s scale=%s offset=%s tex=%s base_tex=%s w=%d h=%d region_enabled=%s region=%s alpha=%s" % [
		key,
		str(scale),
		str(offset),
		str(tex.resource_path),
		base_path,
		tex.get_width(),
		tex.get_height(),
		str(region_enabled),
		str(region_rect),
		alpha_info
	]
