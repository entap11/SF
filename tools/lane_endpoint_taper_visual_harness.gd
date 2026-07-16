extends SceneTree

const LaneBandShader := preload("res://shaders/lane_band.gdshader")
const VIEW_SIZE := Vector2i(512, 128)
const LANE_RECT := Rect2(56.0, 32.0, 400.0, 64.0)

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = VIEW_SIZE
	root.transparent_bg = false
	RenderingServer.set_default_clear_color(Color.BLACK)

	var source_image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	source_image.fill(Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.position = LANE_RECT.get_center()
	sprite.texture = ImageTexture.create_from_image(source_image)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, LANE_RECT.size)

	var material := ShaderMaterial.new()
	material.shader = LaneBandShader
	material.set_shader_parameter("band", 0.94)
	material.set_shader_parameter("feather", 0.04)
	material.set_shader_parameter("endpoint_taper_fraction", 0.15)
	material.set_shader_parameter("endpoint_width_scale", 0.75)
	material.set_shader_parameter("lane_u_start", 0.0)
	material.set_shader_parameter("lane_u_end", 1.0)
	sprite.material = material
	root.add_child(sprite)

	for _frame in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	var rendered := root.get_texture().get_image()
	var endpoint_width := _visible_column_width(rendered, int(LANE_RECT.position.x + 3.0))
	var middle_width := _visible_column_width(rendered, int(LANE_RECT.get_center().x))
	var ratio := float(endpoint_width) / maxf(1.0, float(middle_width))
	_expect(middle_width >= 58, "middle must retain the full source width")
	_expect(endpoint_width < middle_width, "hive endpoint must be visibly narrower than the lane middle")
	_expect(ratio >= 0.70 and ratio <= 0.80, "endpoint width must render near the requested 75 percent; got %.3f" % ratio)

	sprite.queue_free()
	if _failed:
		quit(1)
		return
	print("LANE_ENDPOINT_TAPER_VISUAL: PASS endpoint=%d middle=%d ratio=%.3f" % [endpoint_width, middle_width, ratio])
	quit(0)

func _visible_column_width(image: Image, x: int) -> int:
	var top := image.get_height()
	var bottom := -1
	for y in range(image.get_height()):
		var pixel := image.get_pixel(x, y)
		if maxf(pixel.r, maxf(pixel.g, pixel.b)) <= 0.10:
			continue
		top = mini(top, y)
		bottom = maxi(bottom, y)
	return 0 if bottom < top else (bottom - top) + 1

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("LANE_ENDPOINT_TAPER_VISUAL: %s" % message)
