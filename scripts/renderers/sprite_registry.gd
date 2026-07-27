class_name SpriteRegistry
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const HiveGrowthRules := preload("res://scripts/sim/hive_growth_rules.gd")

const DEFAULT_MANIFEST_PATH := "res://assets/sprites/sf_skin_v1/skin_manifest.json"

static var _instance: SpriteRegistry = null

var _manifest_path: String = DEFAULT_MANIFEST_PATH
var _loaded: bool = false
var _textures_by_key: Dictionary = {}
var _paths_by_key: Dictionary = {}
var _meta_by_key: Dictionary = {}
var _missing_keys: Dictionary = {}
var _missing_keys_order: Array[String] = []
var _tex_alpha_cache: Dictionary = {}
var _hive_textures_prewarmed: bool = false

static func get_instance() -> SpriteRegistry:
	if _instance != null:
		return _instance
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var root := (loop as SceneTree).root
		var existing := root.get_node_or_null("SpriteRegistry")
		if existing is SpriteRegistry:
			_instance = existing
			return _instance
		var node := SpriteRegistry.new()
		node.name = "SpriteRegistry"
		root.call_deferred("add_child", node)
		_instance = node
		return _instance
	return null

static func owner_key(owner_id: int) -> String:
	if owner_id <= 0:
		return "neutral"
	return "p%d" % owner_id

static func hive_kind_key(kind: String) -> String:
	var normalized := kind.strip_edges().to_lower()
	if normalized == "hive":
		return "small"
	if normalized == "medium":
		return "med"
	if normalized.is_empty():
		return "hive"
	return normalized

static func hive_power_tier_key(power: int) -> String:
	return HiveGrowthRules.tier_key(HiveGrowthRules.tier_for_power(power))

static func hive_tier_key(tier: int) -> String:
	return HiveGrowthRules.tier_key(tier)

static func hive_sprite_key_for_tier(owner_id: int, tier: int) -> String:
	return "hive.%s.%s" % [hive_tier_key(tier), owner_key(owner_id)]

static func hive_sprite_key(owner_id: int, kind: String, power: int = 0) -> String:
	return "hive.%s.%s" % [
		hive_visual_kind_key(kind, power),
		owner_key(owner_id)
	]

static func hive_visual_kind_key(kind: String, power: int = 0) -> String:
	if power > 0:
		return hive_power_tier_key(power)
	var kind_key := hive_kind_key(kind)
	if kind_key == "med" or kind_key == "large":
		return kind_key
	return "small"

static func key_from_path(path: String) -> String:
	var base := path.get_file().get_basename()
	return base.replace("_", ".")

func get_manifest_path() -> String:
	return _manifest_path

func _ready() -> void:
	SFLog.log_once("SPRITE_REGISTRY_READY", "SpriteRegistry ready; manifest=%s" % _manifest_path, SFLog.Level.INFO)
	_ensure_loaded()

func _exit_tree() -> void:
	_log_missing_summary()

func set_skin(path_to_manifest: String) -> void:
	if path_to_manifest.is_empty():
		return
	_manifest_path = path_to_manifest
	_load_manifest(_manifest_path)

func has_tex(key: String) -> bool:
	_ensure_loaded()
	if not _textures_by_key.has(key):
		return false
	return _textures_by_key[key] != null

func get_tex(key: String) -> Texture2D:
	_ensure_loaded()
	var tex: Texture2D = null
	if _textures_by_key.has(key):
		tex = _textures_by_key[key]
	if tex == null:
		_mark_missing(key)
	tex = _ensure_alpha(tex, key)
	if tex != null:
		_textures_by_key[key] = tex
	return tex

func prewarm_hive_textures() -> void:
	if _hive_textures_prewarmed:
		return
	_hive_textures_prewarmed = true
	_ensure_loaded()
	var start_us: int = Time.get_ticks_usec()
	var loaded_count: int = 0
	for tier_key in ["small", "med", "large"]:
		for owner_key_value in ["neutral", "p1", "p2", "p3", "p4"]:
			var key := "hive.%s.%s" % [tier_key, owner_key_value]
			if get_tex(key) != null:
				loaded_count += 1
	SFLog.info("SPRITE_REGISTRY_HIVE_PREWARM", {
		"keys": loaded_count,
		"alpha_cache_entries": _tex_alpha_cache.size(),
		"ms": float(Time.get_ticks_usec() - start_us) / 1000.0
	})

func get_tex_path(key: String) -> String:
	_ensure_loaded()
	return str(_paths_by_key.get(key, ""))

func _ensure_alpha(tex: Texture2D, key: String) -> Texture2D:
	if tex == null:
		_tex_alpha_cache[key] = null
		return null

	var colorkey: Dictionary = get_colorkey(key)
	var colorkey_enabled: bool = bool(colorkey.get("enabled", false))
	var auto_key_white: bool = _should_auto_key_white(key)
	if not colorkey_enabled and not auto_key_white:
		return tex
	var cache_key: String = _alpha_cache_key(tex, key, colorkey, auto_key_white)
	if _tex_alpha_cache.has(cache_key):
		return _tex_alpha_cache[cache_key]

	var img: Image = tex.get_image()
	if img == null:
		_tex_alpha_cache[cache_key] = tex
		return tex

	var fmt: int = img.get_format()
	var has_alpha: bool = fmt in [
		Image.FORMAT_RGBA8, Image.FORMAT_RGBAF,
		Image.FORMAT_RGBAH
	]
	if has_alpha and not colorkey_enabled and not auto_key_white:
		_tex_alpha_cache[cache_key] = tex
		return tex

	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()

	var key_color: Color = Color(1.0, 1.0, 1.0, 1.0)
	var threshold: float = 0.20
	var softness: float = 0.08
	if colorkey_enabled:
		var color_v: Variant = colorkey.get("color", key_color)
		if color_v is Color:
			key_color = color_v as Color
		threshold = float(colorkey.get("threshold", threshold))
		softness = float(colorkey.get("softness", softness))
	softness = maxf(0.001, softness)

	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			var dr: float = absf(c.r - key_color.r)
			var dg: float = absf(c.g - key_color.g)
			var db: float = absf(c.b - key_color.b)
			var d: float = maxf(dr, maxf(dg, db))
			if d <= threshold - softness:
				c.a = 0.0
				img.set_pixel(x, y, c)
				continue
			if d >= threshold + softness:
				continue
			var t: float = (d - (threshold - softness)) / (2.0 * softness)
			c.a *= clampf(t, 0.0, 1.0)
			img.set_pixel(x, y, c)

	var itex: ImageTexture = ImageTexture.create_from_image(img)
	if auto_key_white and key.begins_with("tower."):
		SFLog.allow_tag("STRUCTURE_TEX_ALPHA_FIX")
		SFLog.warn("STRUCTURE_TEX_ALPHA_FIX", {
			"key": key,
			"path": get_tex_path(key),
			"size": Vector2i(w, h),
			"threshold": threshold,
			"softness": softness
		}, "", 0)
	_tex_alpha_cache[cache_key] = itex
	return itex

func _alpha_cache_key(tex: Texture2D, key: String, colorkey: Dictionary, auto_key_white: bool) -> String:
	var source_key: String = str(_paths_by_key.get(key, ""))
	if source_key.is_empty() and tex.resource_path != "":
		source_key = tex.resource_path
	if tex is AtlasTexture:
		var atlas_tex := tex as AtlasTexture
		var atlas_path := ""
		if atlas_tex.atlas != null:
			atlas_path = atlas_tex.atlas.resource_path
		source_key = "%s|atlas=%s|region=%s" % [
			source_key,
			atlas_path,
			str(atlas_tex.region)
		]
	return "%s|size=%dx%d|auto=%s|ck=%s|color=%s|threshold=%.5f|softness=%.5f" % [
		source_key,
		tex.get_width(),
		tex.get_height(),
		str(auto_key_white),
		str(bool(colorkey.get("enabled", false))),
		str(colorkey.get("color", Color(0.0, 0.0, 0.0, 1.0))),
		float(colorkey.get("threshold", 0.28)),
		float(colorkey.get("softness", 0.10))
	]

func _should_auto_key_white(key: String) -> bool:
	if key.begins_with("unit."):
		return true
	if key.begins_with("tower."):
		return true
	if key.begins_with("barracks."):
		return true
	return false

func _ensure_loaded() -> void:
	if _loaded:
		return
	_load_manifest(_manifest_path)

func _load_manifest(path: String) -> void:
	_loaded = true
	_textures_by_key.clear()
	_paths_by_key.clear()
	_meta_by_key.clear()
	_tex_alpha_cache.clear()
	_hive_textures_prewarmed = false
	_missing_keys.clear()
	_missing_keys_order.clear()
	if not FileAccess.file_exists(path):
		SFLog.log_once("SPRITE_MANIFEST_MISSING", "SpriteRegistry: manifest missing at %s" % path, SFLog.Level.WARN)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		SFLog.log_once("SPRITE_MANIFEST_OPEN_FAIL", "SpriteRegistry: failed to open manifest at %s" % path, SFLog.Level.WARN)
		return
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		SFLog.log_once("SPRITE_MANIFEST_PARSE_FAIL", "SpriteRegistry: invalid manifest JSON at %s" % path, SFLog.Level.WARN)
		return
	var manifest: Dictionary = parsed as Dictionary
	var sprites_v: Variant = manifest.get("sprites", {})
	if typeof(sprites_v) != TYPE_DICTIONARY:
		SFLog.error("SPRITE_MANIFEST_BAD", {"reason": "missing sprites dict"})
		return
	var sprites: Dictionary = sprites_v as Dictionary
	for key in sprites.keys():
		var entry_v: Variant = sprites.get(key)
		var tex_path := ""
		var slice := ""
		var layout := "horizontal"
		var region := Rect2()
		var has_region := false
		var scale := 1.0
		var offset := Vector2.ZERO
		var colorkey_enabled := false
		var colorkey_color := Color(0.0, 0.0, 0.0, 1.0)
		var colorkey_threshold := 0.28
		var colorkey_softness := 0.10
		if typeof(entry_v) == TYPE_STRING:
			tex_path = str(entry_v)
		elif typeof(entry_v) == TYPE_DICTIONARY:
			var entry: Dictionary = entry_v as Dictionary
			tex_path = str(entry.get("path", ""))
			slice = str(entry.get("slice", "")).strip_edges().to_lower()
			layout = str(entry.get("layout", "horizontal")).strip_edges().to_lower()
			scale = float(entry.get("scale", 1.0))
			var offset_v: Variant = entry.get("offset", null)
			if typeof(offset_v) == TYPE_DICTIONARY:
				var offset_d: Dictionary = offset_v as Dictionary
				offset = Vector2(float(offset_d.get("x", 0)), float(offset_d.get("y", 0)))
			var key_color_v: Variant = entry.get("key_color", null)
			if typeof(key_color_v) == TYPE_STRING:
				var key_color_s := str(key_color_v).strip_edges()
				if not key_color_s.is_empty():
					colorkey_color = Color(key_color_s)
					colorkey_enabled = true
			elif typeof(key_color_v) == TYPE_ARRAY:
				var key_color_arr: Array = key_color_v as Array
				if key_color_arr.size() >= 3:
					var r := float(key_color_arr[0])
					var g := float(key_color_arr[1])
					var b := float(key_color_arr[2])
					if r > 1.0 or g > 1.0 or b > 1.0:
						r /= 255.0
						g /= 255.0
						b /= 255.0
					colorkey_color = Color(r, g, b, 1.0)
					colorkey_enabled = true
			if colorkey_enabled:
				colorkey_threshold = float(entry.get("threshold", colorkey_threshold))
				colorkey_softness = float(entry.get("softness", colorkey_softness))
			var region_v: Variant = entry.get("region", null)
			if typeof(region_v) == TYPE_DICTIONARY:
				var region_d: Dictionary = region_v as Dictionary
				var x := float(region_d.get("x", 0))
				var y := float(region_d.get("y", 0))
				var w := float(region_d.get("w", 0))
				var h := float(region_d.get("h", 0))
				if w > 0.0 and h > 0.0:
					region = Rect2(x, y, w, h)
					has_region = true
		else:
			continue
		if tex_path.is_empty():
			continue
		_paths_by_key[key] = tex_path
		_meta_by_key[key] = {
			"scale": scale,
			"offset": offset,
			"colorkey": {
				"enabled": colorkey_enabled,
				"color": colorkey_color,
				"threshold": colorkey_threshold,
				"softness": colorkey_softness
			}
		}
		var res: Resource = ResourceLoader.load(tex_path)
		if res is Texture2D:
			var base_tex: Texture2D = res
			if has_region:
				var region_tex := AtlasTexture.new()
				region_tex.atlas = res
				region_tex.region = region
				base_tex = region_tex
			var tex: Texture2D = base_tex
			if not slice.is_empty():
				var w := float(tex.get_width())
				var h := float(tex.get_height())
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				if layout == "vertical":
					var half_h := h * 0.5
					if slice == "top":
						atlas.region = Rect2(0.0, 0.0, w, half_h)
						tex = atlas
					elif slice == "bottom":
						atlas.region = Rect2(0.0, half_h, w, half_h)
						tex = atlas
				else:
					var half_w := w * 0.5
					if slice == "left":
						atlas.region = Rect2(0.0, 0.0, half_w, h)
						tex = atlas
					elif slice == "right":
						atlas.region = Rect2(half_w, 0.0, half_w, h)
						tex = atlas
			_textures_by_key[key] = tex
		else:
			_textures_by_key[key] = null

func _mark_missing(key: String) -> void:
	if _missing_keys.has(key):
		return
	_missing_keys[key] = true
	_missing_keys_order.append(key)
	var path := str(_paths_by_key.get(key, ""))
	SFLog.log_once(
		"SPRITE_MISSING:" + key,
		"SpriteRegistry: missing sprite key=%s path=%s" % [key, path],
		SFLog.Level.WARN
	)

func _log_missing_summary() -> void:
	if _missing_keys_order.is_empty():
		return
	SFLog.warn("SPRITE_MISSING_SUMMARY", {
		"count": _missing_keys_order.size(),
		"keys": _missing_keys_order
	})

func get_scale(key: String) -> float:
	_ensure_loaded()
	if _meta_by_key.has(key):
		var meta: Dictionary = _meta_by_key[key]
		return float(meta.get("scale", 1.0))
	return 1.0

func get_offset(key: String) -> Vector2:
	_ensure_loaded()
	if _meta_by_key.has(key):
		var meta: Dictionary = _meta_by_key[key]
		var offset_v: Variant = meta.get("offset", Vector2.ZERO)
		return offset_v as Vector2 if offset_v is Vector2 else Vector2.ZERO
	return Vector2.ZERO

func get_colorkey(key: String) -> Dictionary:
	_ensure_loaded()
	if _meta_by_key.has(key):
		var meta: Dictionary = _meta_by_key[key]
		var ck_v: Variant = meta.get("colorkey", {})
		if typeof(ck_v) == TYPE_DICTIONARY:
			var ck: Dictionary = ck_v as Dictionary
			if bool(ck.get("enabled", false)):
				return ck
	return {
		"enabled": false,
		"color": Color(0.0, 0.0, 0.0, 1.0),
		"threshold": 0.28,
		"softness": 0.10
	}
