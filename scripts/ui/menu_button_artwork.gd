extends RefCounted
## Fits the existing keyed sprites without stretching them or changing hit targets.

var _trimmed: Dictionary = {}

func fitted_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var key := source.get_rid()
	if _trimmed.has(key):
		return _trimmed[key]
	var pixels := source.get_image()
	if pixels == null or pixels.is_empty():
		return source
	# Ignore near-transparent keying residue when finding the visible art. These
	# faint outer pixels otherwise keep the old canvas padding in the layout.
	var low := pixels.get_size()
	var high := Vector2i(-1, -1)
	for y in range(pixels.get_height()):
		for x in range(pixels.get_width()):
			if pixels.get_pixel(x, y).a < 0.12:
				continue
			low.x = mini(low.x, x)
			low.y = mini(low.y, y)
			high.x = maxi(high.x, x)
			high.y = maxi(high.y, y)
	var bounds := Rect2i(low, high - low + Vector2i.ONE)
	if not bounds.has_area():
		return source
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = Rect2(bounds)
	_trimmed[key] = texture
	return texture

func view(source: Texture2D) -> TextureRect:
	var art := TextureRect.new()
	art.name = "ButtonArtwork"
	art.texture = fitted_texture(source)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return art

static func quiet_surface(button: Button) -> void:
	# The sprite supplies the resting frame. Native button states still provide
	# an immediate hover, pressed, disabled and keyboard-focus treatment.
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
