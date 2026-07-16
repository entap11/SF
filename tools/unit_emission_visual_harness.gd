extends SceneTree

const UNIT_TEXTURE: Texture2D = preload("res://assets/sprites/sf_skin_v1/unit_v4.png")
const UNIT_EMISSION_SHADER: Shader = preload("res://shaders/unit_emission.gdshader")
const CAPTURE_SIZE: Vector2i = Vector2i(512, 384)
# Matches the production renderer's approximately 64 px texture box for the
# default 2.52 registry scale.
const UNIT_BOX_PX: float = 64.0
const YELLOW_BASE_CENTER: Vector2 = Vector2(144.0, 96.0)
const YELLOW_EMISSION_CENTER: Vector2 = Vector2(368.0, 96.0)
const RED_BASE_CENTER: Vector2 = Vector2(144.0, 288.0)
const RED_EMISSION_CENTER: Vector2 = Vector2(368.0, 288.0)
const YELLOW_TEAM_COLOR: Color = Color(1.0, 0.76, 0.05, 1.0)
const RED_TEAM_COLOR: Color = Color(1.0, 0.12, 0.12, 1.0)
const BACKGROUND: Color = Color(0.055, 0.060, 0.075, 1.0)
const OUTPUT_PATH: String = "/tmp/swarmfront_unit_emission/unit_emission_comparison.png"

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(BACKGROUND)
	DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	_add_unit(YELLOW_BASE_CENTER, false, YELLOW_TEAM_COLOR)
	_add_unit(YELLOW_EMISSION_CENTER, true, YELLOW_TEAM_COLOR)
	_add_unit(RED_BASE_CENTER, false, RED_TEAM_COLOR)
	_add_unit(RED_EMISSION_CENTER, true, RED_TEAM_COLOR)
	for _frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("capture image is empty")
	else:
		if image.get_width() >= CAPTURE_SIZE.x and image.get_height() >= CAPTURE_SIZE.y:
			image = image.get_region(Rect2i(Vector2i.ZERO, CAPTURE_SIZE))
		var save_error: Error = image.save_png(OUTPUT_PATH)
		if save_error != OK:
			_fail("failed to save capture (%d)" % save_error)
		_validate_capture(image)
	if _failed:
		quit(1)
		return
	print("UNIT_EMISSION_VISUAL: PASS")
	print(OUTPUT_PATH)
	quit(0)

func _add_unit(center: Vector2, with_emission: bool, team_color: Color) -> void:
	var root_node: Node2D = Node2D.new()
	root_node.position = center
	root.add_child(root_node)
	var scale_value: float = UNIT_BOX_PX / maxf(1.0, float(UNIT_TEXTURE.get_width()))
	var sprite_scale: Vector2 = Vector2.ONE * scale_value
	var base: Sprite2D = Sprite2D.new()
	base.texture = UNIT_TEXTURE
	base.centered = true
	base.scale = sprite_scale
	base.self_modulate = team_color
	root_node.add_child(base)
	if not with_emission:
		return
	var emission: Sprite2D = Sprite2D.new()
	emission.texture = UNIT_TEXTURE
	emission.centered = true
	emission.scale = sprite_scale
	emission.z_index = 1
	emission.self_modulate = team_color.lightened(0.10)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = UNIT_EMISSION_SHADER
	emission.material = material
	root_node.add_child(emission)

func _validate_capture(image: Image) -> void:
	_validate_pair(image, YELLOW_BASE_CENTER, YELLOW_EMISSION_CENTER, "yellow")
	_validate_pair(image, RED_BASE_CENTER, RED_EMISSION_CENTER, "red")
	var yellow_center: Color = image.get_pixel(int(YELLOW_EMISSION_CENTER.x), int(YELLOW_EMISSION_CENTER.y))
	var red_center: Color = image.get_pixel(int(RED_EMISSION_CENTER.x), int(RED_EMISSION_CENTER.y))
	_expect(yellow_center.g >= yellow_center.b * 1.25, "yellow emission must retain yellow team chroma instead of clipping to white")
	_expect(red_center.r >= red_center.g * 1.35 and red_center.r >= red_center.b * 1.35, "red emission must retain red team chroma instead of clipping to white")
	var owner_color_distance: float = Vector3(yellow_center.r, yellow_center.g, yellow_center.b).distance_to(Vector3(red_center.r, red_center.g, red_center.b))
	_expect(owner_color_distance >= 0.20, "emission must preserve a visible distinction between owner colors")

func _validate_pair(image: Image, base_center: Vector2, emission_center: Vector2, label: String) -> void:
	var half: int = int(UNIT_BOX_PX * 0.5)
	var base_sum: float = 0.0
	var emission_sum: float = 0.0
	var contributing: int = 0
	var outside_max_delta: float = 0.0
	for oy in range(-half, half + 1):
		for ox in range(-half, half + 1):
			var base_pixel: Color = image.get_pixel(int(base_center.x) + ox, int(base_center.y) + oy)
			var emission_pixel: Color = image.get_pixel(int(emission_center.x) + ox, int(emission_center.y) + oy)
			var base_luma: float = _luma(base_pixel)
			var emission_luma: float = _luma(emission_pixel)
			if base_luma > _luma(BACKGROUND) + 0.025:
				base_sum += base_luma
				emission_sum += emission_luma
				contributing += 1
			else:
				outside_max_delta = maxf(outside_max_delta, absf(emission_luma - base_luma))
	_expect(contributing > 0, "%s capture must contain visible unit pixels" % label)
	if contributing > 0:
		var base_mean: float = base_sum / float(contributing)
		var emission_mean: float = emission_sum / float(contributing)
		_expect(emission_mean >= base_mean + 0.035, "%s additive pass must materially increase source-silhouette luminance" % label)
	_expect(outside_max_delta <= 0.025, "%s emission must not create visible pixels outside the source silhouette" % label)

func _luma(color: Color) -> float:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error("UNIT_EMISSION_VISUAL: %s" % message)
