extends SceneTree

const SOURCE_ROOT: String = "res://assets/sprites/sf_skin_v1"
const OUTPUT_ROOT: String = "res://assets/sprites/sf_skin_v1/baked_ui"
const BUFF_SOURCE_ROOT: String = "res://assets/sprites/sf_skin_v1/buffs"
const BUFF_THUMBNAIL_OUTPUT: String = "res://assets/sprites/sf_skin_v1/baked_ui/buff_icons"

const NEUTRAL_JOBS: Array[Dictionary] = [
	{"source": "play.png", "output": "nav_play.png", "width": 640, "height": 320, "trim": 0.035},
	{"source": "Hive.png", "output": "nav_hive.png", "width": 640, "height": 320, "trim": 0.035},
	{"source": "time_puzzle.png", "output": "nav_time_puzzle.png", "width": 640, "height": 320, "trim": 0.035},
	{"source": "Store.png", "output": "nav_store.png", "width": 640, "height": 320, "trim": 0.035},
	{"source": "buffs_ii.png", "output": "nav_buffs.png", "width": 640, "height": 320, "trim": 0.035},
	{"source": "Free_Roll.png", "output": "nav_free_roll.png", "width": 640, "height": 320, "trim": 0.035},
	{"source": "$_money_games.png", "output": "nav_money_games.png", "width": 640, "height": 320, "trim": 0.035},
	{"source": "battle_pass.png", "output": "nav_battle_pass.png", "width": 640, "height": 320, "trim": 0.035},
	{"source": "map_jukebox.png", "output": "nav_jukebox.png", "width": 640, "height": 320, "trim": 0.035},
	{"source": "tournaments.png", "output": "nav_tournaments.png", "width": 640, "height": 320, "trim": 0.035},
	{"source": "settings_final.png", "output": "nav_settings.png", "width": 640, "height": 320, "trim": 0.035},
	{"source": "Bundles.png", "output": "store_bundles.png", "width": 768, "height": 384, "trim": 0.03},
	{"source": "battle_pass.png", "output": "store_battle_pass.png", "width": 768, "height": 384, "trim": 0.03},
	{"source": "Buffs_1.png", "output": "store_buffs.png", "width": 768, "height": 384, "trim": 0.03},
	{"source": "game_analytics.png", "output": "store_game_analytics.png", "width": 768, "height": 384, "trim": 0.03},
	{"source": "skins_alpha.png", "output": "store_skins.png", "width": 768, "height": 384, "trim": 0.03},
	{"source": "merchii.png", "output": "store_merch.png", "width": 768, "height": 384, "trim": 0.03}
]

const BLACK_JOB_SOURCES: Array[String] = [
	"1v1.png",
	"capture_the_flag.png",
	"hidden_flag.png",
	"2v2.png",
	"3_player.png",
	"4p_ffa.png",
	"crucible_money.png",
	"weekly_color.png",
	"monthly.png",
	"season.png",
	"gauntlet.png",
	"Stage_Race.png",
	"Race.png",
	"Miss_n_Out.png",
	"cancel.png",
	"Close.png",
	"$.png",
	"$1.png",
	"$2.png",
	"$3.png",
	"$5.png",
	"$10.png",
	"$20.png",
	"$50.png",
	"$100.png"
]

func _initialize() -> void:
	var absolute_output: String = ProjectSettings.globalize_path(OUTPUT_ROOT)
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_output)
	if mkdir_error != OK:
		push_error("Could not create baked menu asset directory: %s" % error_string(mkdir_error))
		quit(1)
		return
	var failures: int = 0
	for job in NEUTRAL_JOBS:
		var source_name: String = str(job.get("source", ""))
		var source_image: Image = _load_source_image(source_name)
		if source_image == null:
			failures += 1
			continue
		var baked: Image = _key_neutral_to_alpha(
			source_image,
			int(job.get("width", 768)),
			int(job.get("height", 384)),
			float(job.get("trim", 0.03))
		)
		failures += _save_image(baked, str(job.get("output", "")))
	for source_name in BLACK_JOB_SOURCES:
		var source_image: Image = _load_source_image(source_name)
		if source_image == null:
			failures += 1
			continue
		var baked: Image = _key_black_to_alpha(source_image, 512, 256)
		failures += _save_image(baked, "keyed_%s" % source_name)
	failures += _bake_crucible_skin()
	failures += _bake_portrait_inlay()
	failures += _bake_buff_thumbnails()
	print("MENU_ASSET_BAKE_COMPLETE failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func _load_source_image(source_name: String) -> Image:
	var path: String = "%s/%s" % [SOURCE_ROOT, source_name]
	var texture: Texture2D = ResourceLoader.load(path) as Texture2D
	if texture == null:
		push_error("Missing source texture: %s" % path)
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("Could not read source texture: %s" % path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

func _save_image(image: Image, output_name: String) -> int:
	if image == null or image.is_empty() or output_name.is_empty():
		return 1
	var output_path: String = "%s/%s" % [OUTPUT_ROOT, output_name]
	var error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(error)])
		return 1
	print("Baked %s (%dx%d)" % [output_path, image.get_width(), image.get_height()])
	return 0

func _bake_buff_thumbnails() -> int:
	var output_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(BUFF_THUMBNAIL_OUTPUT)
	)
	if output_error != OK:
		push_error("Could not create buff thumbnail directory: %s" % error_string(output_error))
		return 1
	var source_dir: DirAccess = DirAccess.open(BUFF_SOURCE_ROOT)
	if source_dir == null:
		push_error("Could not open buff source directory: %s" % BUFF_SOURCE_ROOT)
		return 1
	var failures: int = 0
	for source_name in source_dir.get_files():
		if not source_name.to_lower().ends_with(".png"):
			continue
		var source_path: String = "%s/%s" % [BUFF_SOURCE_ROOT, source_name]
		var source_texture: Texture2D = ResourceLoader.load(source_path) as Texture2D
		if source_texture == null:
			failures += 1
			continue
		var thumbnail: Image = source_texture.get_image()
		if thumbnail == null or thumbnail.is_empty():
			failures += 1
			continue
		thumbnail.convert(Image.FORMAT_RGBA8)
		thumbnail.resize(96, 96, Image.INTERPOLATE_LANCZOS)
		var output_name: String = "%s.png" % source_name.get_basename().to_lower()
		var output_path: String = "%s/%s" % [BUFF_THUMBNAIL_OUTPUT, output_name]
		var save_error: Error = thumbnail.save_png(ProjectSettings.globalize_path(output_path))
		if save_error != OK:
			failures += 1
			push_error("Could not save %s: %s" % [output_path, error_string(save_error)])
		else:
			print("Baked %s (96x96)" % output_path)
	return failures

func _resize_to_fit(image: Image, max_width: int, max_height: int) -> void:
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= max_width and height <= max_height:
		return
	var resize_scale: float = minf(float(max_width) / float(width), float(max_height) / float(height))
	image.resize(
		maxi(1, int(round(float(width) * resize_scale))),
		maxi(1, int(round(float(height) * resize_scale))),
		Image.INTERPOLATE_LANCZOS
	)

func _key_black_to_alpha(source: Image, max_width: int, max_height: int) -> Image:
	var image: Image = source.duplicate()
	_resize_to_fit(image, max_width, max_height)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var max_value: float = max(pixel.r, max(pixel.g, pixel.b))
			var min_value: float = min(pixel.r, min(pixel.g, pixel.b))
			var saturation: float = max_value - min_value
			if max_value <= 0.03:
				pixel.a = 0.0
			elif max_value < 0.14 and saturation < 0.20:
				pixel.a *= clampf((max_value - 0.03) / 0.11, 0.0, 1.0)
			image.set_pixel(x, y, pixel)
	return image

func _neutral_background_candidate(pixel: Color) -> bool:
	if pixel.a <= 0.0:
		return false
	var max_value: float = max(pixel.r, max(pixel.g, pixel.b))
	var min_value: float = min(pixel.r, min(pixel.g, pixel.b))
	var saturation: float = max_value - min_value
	return saturation <= 0.24 and (max_value <= 0.68 or max_value >= 0.86)

func _queue_neutral_pixel(
		image: Image,
		x: int,
		y: int,
		width: int,
		height: int,
		mask: PackedByteArray,
		queue: Array[Vector2i]
	) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	var index: int = (y * width) + x
	if mask[index] != 0 or not _neutral_background_candidate(image.get_pixel(x, y)):
		return
	mask[index] = 1
	queue.append(Vector2i(x, y))

func _key_neutral_to_alpha(source: Image, max_width: int, max_height: int, trim_threshold: float) -> Image:
	var image: Image = source.duplicate()
	_resize_to_fit(image, max_width, max_height)
	var width: int = image.get_width()
	var height: int = image.get_height()
	var mask := PackedByteArray()
	mask.resize(width * height)
	var queue: Array[Vector2i] = []
	for x in range(width):
		_queue_neutral_pixel(image, x, 0, width, height, mask, queue)
		_queue_neutral_pixel(image, x, height - 1, width, height, mask, queue)
	for y in range(height):
		_queue_neutral_pixel(image, 0, y, width, height, mask, queue)
		_queue_neutral_pixel(image, width - 1, y, width, height, mask, queue)
	var queue_index: int = 0
	while queue_index < queue.size():
		var cell: Vector2i = queue[queue_index]
		queue_index += 1
		_queue_neutral_pixel(image, cell.x - 1, cell.y, width, height, mask, queue)
		_queue_neutral_pixel(image, cell.x + 1, cell.y, width, height, mask, queue)
		_queue_neutral_pixel(image, cell.x, cell.y - 1, width, height, mask, queue)
		_queue_neutral_pixel(image, cell.x, cell.y + 1, width, height, mask, queue)
	var min_x: int = width
	var min_y: int = height
	var max_x: int = -1
	var max_y: int = -1
	for y in range(height):
		for x in range(width):
			var index: int = (y * width) + x
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			if mask[index] != 0:
				image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, 0.0))
				continue
			var max_value: float = max(pixel.r, max(pixel.g, pixel.b))
			var min_value: float = min(pixel.r, min(pixel.g, pixel.b))
			var saturation: float = max_value - min_value
			var dark_key: float = 1.0 - smoothstep(0.04, 0.22, max_value)
			var bright_key: float = smoothstep(0.74, 0.98, max_value)
			var neutral_key: float = 1.0 - smoothstep(0.015, 0.22, saturation)
			var output_alpha: float = clampf(pixel.a * (1.0 - clampf((dark_key + bright_key) * neutral_key, 0.0, 1.0)), 0.0, 1.0)
			if output_alpha <= trim_threshold:
				image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, 0.0))
				continue
			var fringe: float = clampf((1.0 - output_alpha) * (1.0 - smoothstep(0.02, 0.20, saturation)) * smoothstep(0.65, 1.0, max_value), 0.0, 1.0)
			pixel.r = lerpf(pixel.r, pixel.r * 0.30, fringe)
			pixel.g = lerpf(pixel.g, pixel.g * 0.30, fringe)
			pixel.b = lerpf(pixel.b, pixel.b * 0.30, fringe)
			pixel.a = output_alpha
			image.set_pixel(x, y, pixel)
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return image
	return image.get_region(Rect2i(min_x, min_y, (max_x - min_x) + 1, (max_y - min_y) + 1))

func _bake_portrait_inlay() -> int:
	var source: Image = _load_source_image("match_background_inlay.png")
	if source == null:
		return 1
	var source_width: int = source.get_width()
	var source_height: int = source.get_height()
	var rotated := Image.create(source_height, source_width, false, source.get_format())
	for y in range(source_height):
		for x in range(source_width):
			rotated.set_pixel(source_height - y - 1, x, source.get_pixel(x, y))
	var crop_x: int = clampi(int(round(float(rotated.get_width()) * 0.120)), 0, (rotated.get_width() / 2) - 1)
	var crop_y: int = clampi(int(round(float(rotated.get_height()) * 0.040)), 0, (rotated.get_height() / 2) - 1)
	var cropped: Image = rotated.get_region(Rect2i(
		crop_x,
		crop_y,
		rotated.get_width() - (crop_x * 2),
		rotated.get_height() - (crop_y * 2)
	))
	return _save_image(cropped, "match_background_inlay_portrait.png")

func _bake_crucible_skin() -> int:
	var source: Image = _load_source_image("crucible.png")
	if source == null:
		return 1
	var crop_top: int = clampi(int(round(float(source.get_height()) * 0.31)), 0, source.get_height() - 1)
	var crop_bottom: int = clampi(int(round(float(source.get_height()) * 0.69)), crop_top + 1, source.get_height())
	var cropped: Image = source.get_region(Rect2i(
		0,
		crop_top,
		source.get_width(),
		crop_bottom - crop_top
	))
	var keyed: Image = _key_black_to_alpha(cropped, 768, 256)
	var framed := Image.create(768, 512, false, Image.FORMAT_RGBA8)
	framed.fill(Color(0.0, 0.0, 0.0, 0.0))
	framed.blit_rect(
		keyed,
		Rect2i(0, 0, keyed.get_width(), keyed.get_height()),
		Vector2i((768 - keyed.get_width()) / 2, (512 - keyed.get_height()) / 2)
	)
	return _save_image(framed, "keyed_crucible.png")
