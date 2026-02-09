extends Node2D

const P1_TEXT_COLOR := Color(0.0, 0.0, 0.0)
const P2_TEXT_COLOR := Color(1.0, 1.0, 1.0)
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const SFLog := preload("res://scripts/util/sf_log.gd")
const TEAM_GLOW_SHADER := preload("res://shaders/team_glow_recolor.gdshader")
@export var debug_show_kind_label := false
@export var debug_tint_log := false
@export var show_hive_ids: bool = OS.is_debug_build()
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
const HIVE_VISUAL_SCALE: float = 1.125
const HIVE_WIDTH_MULT: float = 0.90
const HIVE_HEIGHT_MULT: float = 1.28
const HIVE_COLOR_SAT_BOOST: float = 1.22
const HIVE_COLOR_VAL_BOOST: float = 1.12
const HIVE_RING_SCALE: float = 0.85
const HIVE_LABEL_SCALE_COMP: bool = true
const POWER_LABEL_OFFSET := Vector2(-10.0, -30.0)
const POWER_LABEL_SCALE := 0.5
const POWER_LABEL_FONT_SIZE := 20
const POWER_BADGE_PAD := Vector2(6.0, 3.0)
const POWER_BADGE_BG := Color(0.05, 0.05, 0.06, 0.65)
@export var power_label_offset_override := Vector2.INF

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
var _power_label_holder: Node2D = null
var _power_badge: Control = null
var _power_backing: PanelContainer = null
var _power_label: Label = null
var _hive_id_label: Label = null
var _current_size: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE
var _visual_tier: int = -1
var _last_radius_px: float = -1.0
var _power_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _tint_logged := false
var _power_label_logged: Dictionary = {}
var _power_label_state := ""
static var _scale_logged: bool = false

func _ready() -> void:
	_ensure_sprite()
	_ensure_shader_material()
	_base_scale = scale * HIVE_VISUAL_SCALE
	if not _scale_logged:
		_scale_logged = true
		SFLog.info("HIVE_VISUAL_SCALE_SET", {"scale": HIVE_VISUAL_SCALE, "ring_scale": HIVE_RING_SCALE})

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
	_apply_tint(owner_id, power)
	_update_power_label(owner_id, power)
	queue_redraw()

func _draw() -> void:
	SFLog.log_once("HIVEVIS_DRAW", "HiveVisual._draw ran", SFLog.Level.INFO)
	if _tex == null:
		draw_circle(Vector2.ZERO, radius_px, _power_color)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	if _power_label != null and is_instance_valid(_power_label):
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

func _ensure_power_label() -> void:
	if _power_label != null and is_instance_valid(_power_label):
		_ensure_hive_id_label()
		return
	var holder := get_node_or_null("PowerLabelHolder")
	if holder is Node2D:
		_power_label_holder = holder as Node2D
		_apply_label_scale_comp()
		var badge := _power_label_holder.get_node_or_null("PowerBadge")
		if badge is Control:
			_power_badge = badge as Control
			var backing := _power_badge.get_node_or_null("Backing")
			if backing is PanelContainer:
				_power_backing = backing as PanelContainer
				var existing := _power_backing.get_node_or_null("PowerLabel")
				if existing is Label:
					_power_label = existing as Label
					var existing_id := _power_label_holder.get_node_or_null("HiveIdLabel")
					if existing_id is Label:
						_hive_id_label = existing_id as Label
					return
	if _power_label_holder == null:
		var new_holder := Node2D.new()
		new_holder.name = "PowerLabelHolder"
		new_holder.z_index = 20
		add_child(new_holder)
		_power_label_holder = new_holder
		_apply_label_scale_comp()
	if _power_badge == null:
		var new_badge := Control.new()
		new_badge.name = "PowerBadge"
		new_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		new_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		new_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		new_badge.position = Vector2.ZERO
		_power_label_holder.add_child(new_badge)
		_power_badge = new_badge
	if _power_backing == null:
		var new_backing := PanelContainer.new()
		new_backing.name = "Backing"
		new_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		new_backing.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		new_backing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = POWER_BADGE_BG
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = POWER_BADGE_PAD.x
		style.content_margin_right = POWER_BADGE_PAD.x
		style.content_margin_top = POWER_BADGE_PAD.y
		style.content_margin_bottom = POWER_BADGE_PAD.y
		new_backing.add_theme_stylebox_override("panel", style)
		_power_badge.add_child(new_backing)
		_power_backing = new_backing
	var label := Label.new()
	label.name = "PowerLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 1
	var settings := LabelSettings.new()
	settings.font_size = POWER_LABEL_FONT_SIZE
	settings.outline_size = 1
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.8)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	settings.shadow_offset = Vector2(1.0, 1.0)
	label.label_settings = settings
	_power_backing.add_child(label)
	_power_label = label
	_ensure_hive_id_label()

func _apply_label_scale_comp() -> void:
	if not HIVE_LABEL_SCALE_COMP:
		return
	if _power_label_holder == null:
		return
	var comp := clampf(1.0 / HIVE_VISUAL_SCALE, 1.1, 1.35)
	_power_label_holder.scale = Vector2.ONE * comp

func _ensure_hive_id_label() -> void:
	if _power_label_holder == null:
		return
	if _hive_id_label != null and is_instance_valid(_hive_id_label):
		return
	var existing := _power_label_holder.get_node_or_null("HiveIdLabel")
	if existing is Label:
		_hive_id_label = existing as Label
		return
	var id_label := Label.new()
	id_label.name = "HiveIdLabel"
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	id_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	id_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	id_label.size = Vector2(56.0, 18.0)
	id_label.position = Vector2(-28.0, 16.0)
	var settings := LabelSettings.new()
	settings.font_size = 13
	settings.outline_size = 1
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	settings.shadow_offset = Vector2(1.0, 1.0)
	id_label.label_settings = settings
	_power_label_holder.add_child(id_label)
	_hive_id_label = id_label

func _update_power_label(owner_id_value: int, power_value: int) -> void:
	_ensure_power_label()
	if _power_label == null or not is_instance_valid(_power_label) or _power_label_holder == null or _power_badge == null:
		return
	var hive_id := -1
	var parent := get_parent()
	if parent != null and parent.has_method("get"):
		var id_v: Variant = parent.get("hive_id")
		if id_v != null:
			hive_id = int(id_v)
	_ensure_hive_id_label()
	if _hive_id_label != null and is_instance_valid(_hive_id_label):
		_hive_id_label.visible = show_hive_ids
		_hive_id_label.text = ("h" + str(hive_id)) if hive_id > 0 else ""
	var next_state := "%s:%s" % [str(owner_id_value), str(power_value)]
	if next_state == _power_label_state:
		return
	_power_label_state = next_state
	var team_color := _team_color_for_player(owner_id_value)
	team_color.a = 1.0
	_power_label.text = str(power_value)
	var label_color: Color = team_color.lerp(Color(1.0, 1.0, 1.0), 0.65)
	label_color.a = 1.0
	_power_label.modulate = label_color
	var label_size := _power_label.get_minimum_size()
	_power_label.custom_minimum_size = label_size
	_power_label.pivot_offset = label_size * 0.5
	_power_label.position = Vector2.ZERO
	_power_badge.scale = Vector2.ONE * POWER_LABEL_SCALE
	if _power_backing != null and is_instance_valid(_power_backing):
		_power_backing.custom_minimum_size = label_size + (POWER_BADGE_PAD * 2.0)
		_power_backing.size = _power_backing.custom_minimum_size
		_power_badge.size = _power_backing.size
	var off := POWER_LABEL_OFFSET
	if power_label_offset_override != Vector2.INF:
		off = power_label_offset_override
	_power_label_holder.position = off
	if not _power_label_logged.has(hive_id):
		_power_label_logged[hive_id] = true
		SFLog.info("HIVE_POWER_LABEL", {
			"hive_id": hive_id,
			"owner_id": owner_id_value,
			"power": power_value,
			"label_text": _power_label.text,
			"offset": POWER_LABEL_OFFSET,
			"label_global": _power_label.global_position
		})

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
		_shader_mat.shader = TEAM_GLOW_SHADER
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

static func _team_color_for_player(player_id: int) -> Color:
	match player_id:
		1:
			return Color8(255, 210, 0)
		2:
			return Color8(229, 57, 53)
		3:
			return Color(0.2, 1.0, 0.35, 1.0)
		4:
			return Color8(30, 136, 229)
		_:
			return Color8(224, 224, 224)

func _apply_tint(owner_id_value: int, power_value: int) -> void:
	_ensure_shader_material()
	var team_color: Color = _team_color_for_player(owner_id_value)
	if owner_id_value > 0:
		team_color = _boost_team_color(team_color)
	owner_color = team_color
	var t: float = clamp(
		float(power_value) / float(LARGE_MAX_POWER),
		0.0,
		1.0
	)
	var base: Color = team_color.darkened(0.25)
	var bright: Color = team_color.lightened(0.15)
	_power_color = base.lerp(bright, t)
	_power_color.a = 1.0
	if debug_tint_log and not _tint_logged:
		_tint_logged = true
		var hive_id := -1
		var parent := get_parent()
		if parent != null and parent.has_method("get"):
			var id_v: Variant = parent.get("hive_id")
			if id_v != null:
				hive_id = int(id_v)
		SFLog.info("HIVE_TINT_SAMPLE", {
			"hive_id": hive_id,
			"owner_id": owner_id_value,
			"team_color": team_color
		})
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("team_color", team_color)
		_shader_mat.set_shader_parameter("glow_strength", lerp(0.6, 1.0, t))

func _boost_team_color(in_color: Color) -> Color:
	var boosted_s: float = clampf(in_color.s * HIVE_COLOR_SAT_BOOST, 0.0, 1.0)
	var boosted_v: float = clampf(in_color.v * HIVE_COLOR_VAL_BOOST, 0.0, 1.0)
	return Color.from_hsv(in_color.h, boosted_s, boosted_v, 1.0)

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
	var width := (base_width_px if base_width_px > 0.0 else legacy_size.x) * HIVE_WIDTH_MULT
	var base_height := height_small_px if height_small_px > 0.0 else legacy_size.y
	var height := _height_for_tier(base_height, _resolve_tier(power)) * HIVE_HEIGHT_MULT
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
