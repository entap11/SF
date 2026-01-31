extends Node2D

const P1_TEXT_COLOR := Color(0.0, 0.0, 0.0)
const P2_TEXT_COLOR := Color(1.0, 1.0, 1.0)
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const SFLog := preload("res://scripts/util/sf_log.gd")
const COLORKEY_SHADER := preload("res://shaders/sf_colorkey_alpha.gdshader")
@export var debug_show_kind_label := false
@export var nine_margin_top: int = 48
@export var nine_margin_bottom: int = 48
@export var base_width_px: float = 0.0
@export var height_small_px: float = 0.0
@export var height_med_px: float = 0.0
@export var height_large_px: float = 0.0
@export var height_max_px: float = 0.0
@export var debug_tier_changes := false

const TIER_2_MIN_POWER := 10
const TIER_3_MIN_POWER := 25
const TIER_4_MIN_POWER := 50
const SMALL_MAX_POWER := 9
const MED_MAX_POWER := 24
const LARGE_MAX_POWER := 50
const HEIGHT_MED_SCALE := 1.10
const HEIGHT_LARGE_SCALE := 1.20
const HEIGHT_MAX_SCALE := 1.30
const HIVE_VISUAL_SCALE := 2.0

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
var _sprite: Sprite2D = null
var _shader_mat: ShaderMaterial = null
var _current_size: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE
var _visual_tier: int = -1
var _last_radius_px: float = -1.0

func _ready() -> void:
	_ensure_sprite()
	_ensure_shader_material()
	_base_scale = scale * HIVE_VISUAL_SCALE

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
	var desired_tier := _visual_tier_for_power(power)
	var kind_key := _tier_key_for_tier(desired_tier)
	var key := "hive.%s.%s" % [
		kind_key,
		SpriteRegistry.owner_key(owner_id)
	]
	SFLog.log_once(
		"HIVE_SPRITE_KEY_SAMPLE",
		"Hive sprite key sample: kind=%s kind_key=%s owner=%s power=%s key=%s" % [str(hive_kind), str(kind_key), str(owner_id), str(power), key],
		SFLog.Level.INFO
	)
	var registry := SpriteRegistry.get_instance()
	var next_tex: Texture2D = registry.get_tex(key) if registry != null else null
	var next_scale := registry.get_scale(key) if registry != null else 1.0
	var next_offset := registry.get_offset(key) if registry != null else Vector2.ZERO
	var tier_changed := desired_tier != _visual_tier
	if tier_changed:
		if debug_tier_changes:
			var hive_id := -1
			var parent := get_parent()
			if parent != null and parent.has_method("get"):
				var id_v: Variant = parent.get("hive_id")
				if id_v != null:
					hive_id = int(id_v)
			SFLog.info("HIVE_TIER_CHANGE", {
				"id": hive_id,
				"old": _visual_tier,
				"new": desired_tier,
				"power": power
			})
		_visual_tier = desired_tier
	var needs_sprite_refresh := (
		tier_changed
		or key != _sprite_key
		or not is_equal_approx(radius_px, _last_radius_px)
		or next_tex != _tex
	)
	if needs_sprite_refresh:
		_tex = next_tex
		_sprite_key = key
		_sprite_scale = next_scale
		_sprite_offset = next_offset
		_last_radius_px = radius_px
		_ensure_shader_material()
		if _shader_mat != null:
			var mat := _shader_mat
			var ck_color := Color(0.0, 0.0, 0.0, 1.0)
			var ck_threshold := 0.28
			var ck_softness := 0.10
			if registry != null:
				var ck := registry.get_colorkey(key)
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
		elif _tex != null:
			SFLog.log_once(
				"HIVE_TEX_INFO",
				_hive_tex_debug(_tex, _sprite_key, _sprite_scale, _sprite_offset),
				SFLog.Level.INFO
			)
		_apply_sprite()
	queue_redraw()

func _draw() -> void:
	SFLog.log_once("HIVEVIS_DRAW", "HiveVisual._draw ran", SFLog.Level.INFO)
	if _tex == null:
		draw_circle(Vector2.ZERO, radius_px, owner_color)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text := str(power)
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := -size * 0.5 + Vector2(0.0, size.y * 0.35)
	var text_color := Color(1.0, 1.0, 1.0, 1.0)
	var shadow_color := Color(0.0, 0.0, 0.0, 0.8)
	draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	if debug_show_kind_label:
		var kind_pos := pos + Vector2(0.0, font_size * 1.2)
		draw_string(font, kind_pos, hive_kind, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

func _ensure_sprite() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		return
	var existing := get_node_or_null("HiveSprite")
	if existing is Sprite2D:
		_sprite = existing as Sprite2D
		return
	var sprite := Sprite2D.new()
	sprite.name = "HiveSprite"
	sprite.centered = true
	sprite.z_index = -1
	add_child(sprite)
	_sprite = sprite

func _ensure_shader_material() -> void:
	if _shader_mat == null:
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = COLORKEY_SHADER
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.material = _shader_mat

func _resolve_tier(power_value: int) -> int:
	return _visual_tier_for_power(power_value)

func _visual_tier_for_power(power_value: int) -> int:
	if power_value <= 0:
		return 1
	if power_value <= SMALL_MAX_POWER:
		return 1
	if power_value <= MED_MAX_POWER:
		return 2
	return 3

func _tier_key_for_tier(tier: int) -> String:
	match tier:
		2:
			return "med"
		3:
			return "large"
		_:
			return "small"

func _height_for_tier(base_height: float, tier: int) -> float:
	var small_h := height_small_px if height_small_px > 0.0 else base_height
	var med_h := height_med_px if height_med_px > 0.0 else base_height * HEIGHT_MED_SCALE
	var large_h := height_large_px if height_large_px > 0.0 else base_height * HEIGHT_LARGE_SCALE
	var max_h := height_max_px if height_max_px > 0.0 else base_height * HEIGHT_MAX_SCALE
	match tier:
		4:
			return max_h
		3:
			return large_h
		2:
			return med_h
		_:
			return small_h

func _apply_sprite() -> void:
	_ensure_sprite()
	_ensure_shader_material()
	if _sprite == null or not is_instance_valid(_sprite):
		return
	_sprite.texture = _tex
	_sprite.visible = _tex != null
	_sprite.position = _sprite_offset
	if _tex == null:
		return
	var legacy_size := Vector2(radius_px * 2.0, radius_px * 2.0) * _sprite_scale
	var width := base_width_px if base_width_px > 0.0 else legacy_size.x
	var base_height := height_small_px if height_small_px > 0.0 else legacy_size.y
	var height := _height_for_tier(base_height, _resolve_tier(power))
	_current_size = Vector2(width, height)
	var tex_size := Vector2(float(_tex.get_width()), float(_tex.get_height()))
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		_sprite.scale = Vector2(_current_size.x / tex_size.x, _current_size.y / tex_size.y)
	else:
		_sprite.scale = Vector2.ONE

func _hive_tex_debug(tex: Texture2D, key: String, scale: float, offset: Vector2) -> String:
	var region_enabled := false
	var region_rect := Rect2()
	var base_path := ""
	if tex is AtlasTexture:
		var atlas := tex as AtlasTexture
		region_enabled = true
		region_rect = atlas.region
		if atlas.atlas != null:
			base_path = str(atlas.atlas.resource_path)
	var img := tex.get_image() if tex != null else null
	var alpha_info := "unknown"
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
