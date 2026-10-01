extends PanelContainer

# First-party editorial content only: no ad requests, taps, or impressions.
const CATEGORIES: Dictionary = {
	"company": "FROM SWARMFRONT",
	"match_highlight": "MATCH HIGHLIGHT",
	"upset": "UPSET SPOTLIGHT",
	"accomplishment": "SWARM ACHIEVEMENTS",
	"promo": "INSIDE SWARMFRONT",
}
const FALLBACK: Dictionary = {
	"kind": "company",
	"title": "Thanks for backing the swarm.",
	"body": "Your support helps us build Swarmfront.\nNow, let's get your arena ready.",
}

var hold_for_content: bool = true
var display_seconds: float = 10.0
var _next_item: int = 0
var _item: Dictionary = {}
var _started_ms: int = 0
var _deadline_ms: int = 0
var _active: bool = false
var _title: Label = null
var _body: Label = null
var _image: TextureRect = null
var _video_frame: AspectRatioContainer = null
var _video: VideoStreamPlayer = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.05)
	style.border_color = Color(0.48, 0.39, 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 40.0
	style.content_margin_right = 40.0
	style.content_margin_top = 40.0
	style.content_margin_bottom = 40.0
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 28)
	add_child(column)
	_title = _make_label(44, Color(1.0, 0.86, 0.3))
	column.add_child(_title)
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_image)
	_video_frame = AspectRatioContainer.new()
	_video_frame.ratio = 16.0 / 9.0
	_video_frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_video_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_video_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_video_frame)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.volume_db = -80.0
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.finished.connect(_on_video_finished)
	_video_frame.add_child(_video)
	_body = _make_label(32, Color(0.86, 0.87, 0.89))
	column.add_child(_body)
	stop()

func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func prepare() -> void:
	stop()
	var items: Array[Dictionary] = []
	var config: Node = get_node_or_null("/root/OpsConfig")
	if config != null:
		var snapshot: Dictionary = config.call("get_config_snapshot")
		var raw: Variant = snapshot.get("ads", {}).get("loading_content_items", [])
		if raw is Array:
			for entry: Variant in raw:
				if entry is Dictionary and CATEGORIES.has(str(entry.get("kind", "company"))) \
				and not str(entry.get("title", "")).strip_edges().is_empty():
					items.append(entry.duplicate(true))
	if items.is_empty():
		items.append(FALLBACK.duplicate(true))
	_item = items[_next_item % items.size()]
	_next_item += 1
	_title.text = str(_item.get("title", ""))
	_body.text = str(_item.get("body", ""))
	var image_resource: Resource = _load_media(str(_item.get("image_path", "")))
	_image.texture = image_resource as Texture2D
	_image.visible = _image.texture != null
	var video_resource: Resource = _load_media(str(_item.get("video_path", "")))
	_video.stream = video_resource as VideoStream
	_video_frame.visible = _video.stream != null
	if _video_frame.visible:
		_image.hide()
	_active = true
	_deadline_ms = Time.get_ticks_msec() + int((display_seconds + 2.0) * 1000.0)
	show()

func category_label() -> String:
	return str(CATEGORIES.get(str(_item.get("kind", "company")), CATEGORIES.company))

func start_playback() -> void:
	if not _active:
		return
	_started_ms = Time.get_ticks_msec()
	if _video.stream != null:
		_video.play()
		set_process(true)

func is_pending() -> bool:
	var now_ms: int = Time.get_ticks_msec()
	return _active and hold_for_content and now_ms < _deadline_ms \
		and (_started_ms == 0 or now_ms - _started_ms < int(display_seconds * 1000.0))

func stop() -> void:
	_active = false
	_started_ms = 0
	if _video != null:
		_video.stop()
	set_process(false)
	hide()

func _process(_delta: float) -> void:
	var texture: Texture2D = _video.get_video_texture()
	if texture != null and texture.get_height() > 0:
		_video_frame.ratio = float(texture.get_width()) / float(texture.get_height())
	if not _video.is_playing():
		_on_video_finished()

func _on_video_finished() -> void:
	# Keep the accompanying message visible if arena preparation takes longer.
	_video_frame.hide()
	set_process(false)

func _load_media(path: String) -> Resource:
	# This surface consumes already downloaded/bundled media only.
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)
