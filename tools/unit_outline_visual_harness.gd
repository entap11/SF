extends SceneTree

const UNIT_V3: Texture2D = preload("res://assets/sprites/sf_skin_v1/unit_v3.png")
const UNIT_V4: Texture2D = preload("res://assets/sprites/sf_skin_v1/unit_v4.png")
const UNIT_V5: Texture2D = preload("res://assets/sprites/sf_skin_v1/unit_v5.png")
const UNIT_SHADER: Shader = preload("res://shaders/sf_colorkey_alpha.gdshader")
const NEUTRAL_UNIT_SHADER: Shader = preload("res://shaders/team_glow_recolor.gdshader")
const CAPTURE_SIZE: Vector2i = Vector2i(1024, 256)
const UNIT_BOX_PX: float = 64.0
const CENTERS: Array[Vector2] = [
	Vector2(128.0, 128.0),
	Vector2(384.0, 128.0),
	Vector2(640.0, 128.0),
	Vector2(896.0, 128.0),
]
const BACKGROUND: Color = Color(0.055, 0.060, 0.075, 1.0)
const OUTPUT_PATH: String = "/tmp/swarmfront_unit_outline/unit_outline_comparison.png"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(BACKGROUND)
	DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	var textures: Array[Texture2D] = [UNIT_V3, UNIT_V4, UNIT_V5, UNIT_V5]
	for index in range(textures.size()):
		_add_unit(CENTERS[index], textures[index], index == 3)
	for _frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("UNIT_OUTLINE_VISUAL: capture image is empty")
		quit(1)
		return
	if image.get_width() >= CAPTURE_SIZE.x and image.get_height() >= CAPTURE_SIZE.y:
		image = image.get_region(Rect2i(Vector2i.ZERO, CAPTURE_SIZE))
	for index in range(CENTERS.size()):
		if not _has_visible_unit_pixels(image, CENTERS[index]):
			push_error("UNIT_OUTLINE_VISUAL: comparison %d contains no visible unit pixels" % index)
			quit(1)
			return
	var save_error: Error = image.save_png(OUTPUT_PATH)
	if save_error != OK:
		push_error("UNIT_OUTLINE_VISUAL: failed to save capture (%d)" % save_error)
		quit(1)
		return
	print("UNIT_OUTLINE_VISUAL: PASS (V3, V4, V5 player, V5 neutral left to right)")
	print(OUTPUT_PATH)
	quit(0)

func _add_unit(center: Vector2, texture: Texture2D, neutral: bool) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.position = center
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if texture == UNIT_V5 else CanvasItem.TEXTURE_FILTER_LINEAR
	var texture_width: float = maxf(1.0, float(texture.get_width()))
	sprite.scale = Vector2.ONE * (UNIT_BOX_PX / texture_width)
	if neutral:
		var neutral_material: ShaderMaterial = ShaderMaterial.new()
		neutral_material.shader = NEUTRAL_UNIT_SHADER
		neutral_material.set_shader_parameter(&"key_color", Color(1.0, 0.0, 1.0, 1.0))
		neutral_material.set_shader_parameter(&"key_threshold", 0.10)
		neutral_material.set_shader_parameter(&"key_softness", 0.05)
		neutral_material.set_shader_parameter(&"key_enabled", 1.0)
		sprite.material = neutral_material
	elif texture == UNIT_V5:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = UNIT_SHADER
		material.set_shader_parameter(&"key_color", Color(1.0, 0.0, 1.0, 1.0))
		material.set_shader_parameter(&"threshold", 0.10)
		material.set_shader_parameter(&"softness", 0.05)
		material.set_shader_parameter(&"outline_strength", 0.0)
		material.set_shader_parameter(&"inner_outline_strength", 0.0)
		sprite.material = material
	root.add_child(sprite)

func _has_visible_unit_pixels(image: Image, center: Vector2) -> bool:
	var half: int = int(UNIT_BOX_PX * 0.5)
	var background_luma: float = _luma(BACKGROUND)
	for oy in range(-half, half + 1):
		for ox in range(-half, half + 1):
			var pixel: Color = image.get_pixel(int(center.x) + ox, int(center.y) + oy)
			if _luma(pixel) >= background_luma + 0.05:
				return true
	return false

func _luma(color: Color) -> float:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114
