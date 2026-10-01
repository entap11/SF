extends "res://scripts/ui/ad_surface.gd"

# Presentation only. The loading coordinator owns the transition; this surface
# never starts, pauses, or changes the simulation.
const SLOT_ID: String = "match_loading"
const DISPLAY_SECONDS: float = 10.0
const TIMEOUT_SECONDS: float = 12.0

var display_seconds: float = DISPLAY_SECONDS
var timeout_seconds: float = TIMEOUT_SECONDS
var _pending: bool = false
var _started: bool = false
var _deadline_ms: int = 0
var _displayed_seconds: float = 0.0
var _video: VideoStreamPlayer = null
var _video_frame: AspectRatioContainer = null

func prepare() -> void:
	stop()
	configure(SLOT_ID, PLACEMENT_HANDSHAKE, Vector2.ONE, false)
	_pending = _ad_available
	_deadline_ms = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	var creative: Dictionary = _filled_ad_creative()
	var video_path: String = str(creative.get("video_path", "")).strip_edges()
	if _pending and not video_path.is_empty():
		var stream: Resource = load(video_path) if ResourceLoader.exists(video_path) else null
		if not stream is VideoStream:
			finish("video_unavailable")
			return
		if _video == null:
			_video_frame = AspectRatioContainer.new()
			_video_frame.name = "VideoFrame"
			_video_frame.ratio = 16.0 / 9.0
			_video_frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
			_video_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_video_frame)
			_video = VideoStreamPlayer.new()
			_video.name = "VideoCreative"
			_video.expand = true
			_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_video.finished.connect(_on_video_finished)
			_video_frame.add_child(_video)
		_video.stream = stream as VideoStream
		_video.volume_db = -80.0
		_video.show()
		_video_frame.show()
		_label.hide()
		_creative_texture_rect.hide()
	elif _pending and not _creative_texture_rect.visible and _filled_ad_label_text().is_empty():
		# A provider fill without a renderable creative is still a failure.
		finish("creative_unavailable")
		return
	set_process(_pending)

func start_playback() -> void:
	if not is_pending() or _started:
		return
	_started = true
	if _video != null and _video.visible:
		_video.play()
	set_process(true)

func is_pending() -> bool:
	if _pending and Time.get_ticks_msec() >= _deadline_ms:
		finish("timeout")
	return _pending

func stop() -> void:
	_pending = false
	_started = false
	_displayed_seconds = 0.0
	if _video != null:
		_video.stop()
		_video.hide()
		_video_frame.hide()
	set_ad_available(false)
	set_process(false)

func finish(reason: String) -> void:
	stop()
	var manager: Node = _ad_manager()
	if manager != null:
		manager.call("mark_empty", SLOT_ID, PLACEMENT_HANDSHAKE, get_policy_snapshot(), reason)

func _on_video_finished() -> void:
	finish("completed")

func _arm_auto_dismiss_if_needed() -> void:
	# The ordinary eight-second handshake timer must not cut off this creative.
	pass

func _should_show_internal_ticker() -> bool:
	# The coordinator selects a separate first-party surface for ad-free loading.
	return false

func _process(delta: float) -> void:
	if not is_pending():
		return
	if not _ad_available or not _ads_allowed_by_policy():
		finish("unavailable")
		return
	if not _started or not _is_surface_viewable_for_impression():
		return
	# A stalled loading frame must not count as seconds of video or exposure.
	var visible_delta: float = minf(maxf(delta, 0.0), 0.1)
	super._process(visible_delta)
	set_process(true)
	if _video != null and _video.visible:
		var texture: Texture2D = _video.get_video_texture()
		if texture != null and texture.get_height() > 0:
			_video_frame.ratio = float(texture.get_width()) / float(texture.get_height())
		if not _video.is_playing():
			finish("playback_failed")
		elif _video.stream_position >= display_seconds:
			finish("completed")
	else:
		_displayed_seconds += visible_delta
		if _displayed_seconds >= display_seconds:
			finish("completed")
