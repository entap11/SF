extends SceneTree

const MANIFEST_PATH: String = "res://assets/sprites/sf_skin_v1/skin_manifest.json"
const SOURCE_PATH: String = "res://assets/sprites/sf_skin_v1/hive_large_flatop.png"
const ALPHA_PATH: String = "res://assets/sprites/sf_skin_v1/hive_large_flatop_alpha.png"
const THRESHOLD: float = 0.035
const SOFTNESS: float = 0.018

var _failed: bool = false

func _init() -> void:
	var source: Image = Image.load_from_file(SOURCE_PATH)
	var alpha_ready: Image = Image.load_from_file(ALPHA_PATH)
	_expect(source != null and not source.is_empty(), "source image should load")
	_expect(alpha_ready != null and not alpha_ready.is_empty(), "alpha-ready image should load")
	if source == null or source.is_empty() or alpha_ready == null or alpha_ready.is_empty():
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	alpha_ready.convert(Image.FORMAT_RGBA8)
	_expect(source.get_size() == alpha_ready.get_size(), "alpha-ready image should preserve source dimensions")
	_apply_expected_color_key(source)
	_expect(source.get_data() == alpha_ready.get_data(), "alpha-ready pixels should exactly match the former runtime conversion")
	var imported_texture: Texture2D = load(ALPHA_PATH) as Texture2D
	_expect(imported_texture != null, "alpha-ready asset should import as a texture")
	if imported_texture != null:
		var imported_image: Image = imported_texture.get_image()
		imported_image.convert(Image.FORMAT_RGBA8)
		_expect(source.get_data() == imported_image.get_data(), "imported texture pixels should preserve the former runtime conversion")

	var manifest_any: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(typeof(manifest_any) == TYPE_DICTIONARY, "sprite manifest should parse")
	if typeof(manifest_any) == TYPE_DICTIONARY:
		var sprites: Dictionary = (manifest_any as Dictionary).get("sprites", {}) as Dictionary
		for owner_key in ["neutral", "p1", "p2", "p3", "p4"]:
			var key: String = "hive.large.%s" % owner_key
			var entry: Dictionary = sprites.get(key, {}) as Dictionary
			_expect(str(entry.get("path", "")) == ALPHA_PATH, "%s should use the alpha-ready asset" % key)
			_expect(not entry.has("key_color") and not entry.has("threshold") and not entry.has("softness"), "%s should not request runtime color keying" % key)

	if _failed:
		quit(1)
		return
	print("LARGE_HIVE_ALPHA_ASSET_SMOKE: PASS")
	quit(0)

func _apply_expected_color_key(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			var distance: float = maxf(absf(color.r), maxf(absf(color.g), absf(color.b)))
			if distance <= THRESHOLD - SOFTNESS:
				color.a = 0.0
				image.set_pixel(x, y, color)
				continue
			if distance >= THRESHOLD + SOFTNESS:
				continue
			var feather: float = (distance - (THRESHOLD - SOFTNESS)) / (2.0 * SOFTNESS)
			color.a *= clampf(feather, 0.0, 1.0)
			image.set_pixel(x, y, color)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("LARGE_HIVE_ALPHA_ASSET_SMOKE: %s" % message)
