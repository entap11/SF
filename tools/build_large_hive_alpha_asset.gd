extends SceneTree

const SOURCE_PATH: String = "res://assets/sprites/sf_skin_v1/hive_large_flatop.png"
const OUTPUT_PATH: String = "res://assets/sprites/sf_skin_v1/hive_large_flatop_alpha.png"
const KEY_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
const THRESHOLD: float = 0.035
const SOFTNESS: float = 0.018

func _init() -> void:
	var image: Image = Image.load_from_file(SOURCE_PATH)
	if image == null or image.is_empty():
		push_error("LARGE_HIVE_ALPHA_BUILD: source image could not be loaded")
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	_apply_color_key(image)
	var error: Error = image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("LARGE_HIVE_ALPHA_BUILD: save failed with error %d" % error)
		quit(1)
		return
	print("LARGE_HIVE_ALPHA_BUILD: wrote %s" % OUTPUT_PATH)
	quit(0)

func _apply_color_key(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			var distance: float = maxf(
				absf(color.r - KEY_COLOR.r),
				maxf(absf(color.g - KEY_COLOR.g), absf(color.b - KEY_COLOR.b))
			)
			if distance <= THRESHOLD - SOFTNESS:
				color.a = 0.0
				image.set_pixel(x, y, color)
				continue
			if distance >= THRESHOLD + SOFTNESS:
				continue
			var feather: float = (distance - (THRESHOLD - SOFTNESS)) / (2.0 * SOFTNESS)
			color.a *= clampf(feather, 0.0, 1.0)
			image.set_pixel(x, y, color)
