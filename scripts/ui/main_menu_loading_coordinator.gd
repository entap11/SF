extends CanvasLayer

const MatchLoadingAd := preload("res://scripts/ui/match_loading_ad.gd")
const MatchLoadingContent := preload("res://scripts/ui/match_loading_content.gd")
const MatchHudLayout := preload("res://scripts/ui/match_hud_layout.gd")
const DEFAULT_MIN_VISIBLE_SECONDS: float = 1.75
const DEFAULT_FADE_SECONDS: float = 0.22
const DEFAULT_EYE_FADE_DELAY_SECONDS: float = 0.65
const DEFAULT_EYE_FADE_SECONDS: float = 0.55
const DEFAULT_EYE_FINAL_BRIGHTEN_SECONDS: float = 0.1
const EYE_CRUISE_ALPHA: float = 0.9
const EYE_LOADING_HANDOFF_ALPHA: float = 0.5
const PREPARATION_MESSAGE_SECONDS: float = 1.45
const PREPARATION_MESSAGES: PackedStringArray = [
	"Prepping the arena...",
	"Charging the bees...",
	"Lighting up the hives...",
	"Calibrating flight paths...",
	"Polishing the power grid...",
	"Briefing the swarm...",
	"Cutting the grass... just kidding, there is no grass.",
	"Checking every tiny helmet...",
]
const PREPARATION_STAGE_MESSAGES: Dictionary = {
	"scene": "Opening the arena gates...",
	"map": "Laying out the battlefield...",
	"render": "Lighting up the hives...",
	"final": "Tightening the spring...",
}

@export_range(0.0, 5.0, 0.05) var minimum_visible_seconds: float = DEFAULT_MIN_VISIBLE_SECONDS
@export_range(0.0, 2.0, 0.01) var fade_seconds: float = DEFAULT_FADE_SECONDS
@export_range(0.0, 5.0, 0.05) var eye_fade_delay_seconds: float = DEFAULT_EYE_FADE_DELAY_SECONDS
@export_range(0.0, 10.0, 0.05) var eye_fade_seconds: float = DEFAULT_EYE_FADE_SECONDS
@export_range(0.0, 1.0, 0.01) var eye_final_brighten_seconds: float = DEFAULT_EYE_FINAL_BRIGHTEN_SECONDS

@onready var black: ColorRect = $Black
@onready var signage: TextureRect = $Signage
@onready var logo_eyes: TextureRect = $LogoEyes
@onready var preparation_status: Label = $PreparationStatus

var _active: bool = false
var _shown_at_msec: int = 0
var _transition_generation: int = 0
var _fade_tween: Tween = null
var _eye_fade_tween: Tween = null
var _transition_kind: String = ""
var _preparation_message_index: int = 0
var _preparation_message_elapsed: float = 0.0
var _loading_progress: ProgressBar = null
var _sponsor_content: Control = null
var _sponsor_label: Label = null
var _sponsor_note: Label = null
var _match_ad: MatchLoadingAd = null
var _internal_content: MatchLoadingContent = null
var _loading_content: Control = null
var _menu_geometry: Dictionary = {}
var _menu_signage_texture: Texture2D = null
var _match_signage_texture: AtlasTexture = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_set_cover_alpha(1.0)
	_set_logo_eyes_alpha(0.0)
	_set_preparation_status_alpha(1.0)
	preparation_status.visible = false
	_build_match_loading_ui()
	get_viewport().size_changed.connect(_layout_loading_content)
	set_process(false)

func _process(delta: float) -> void:
	if not _active or _transition_kind != "match":
		return
	_sponsor_content.visible = _loading_content.visible
	_preparation_message_elapsed += delta
	if _preparation_message_elapsed < PREPARATION_MESSAGE_SECONDS:
		return
	_preparation_message_elapsed = 0.0
	_preparation_message_index = (_preparation_message_index + 1) % PREPARATION_MESSAGES.size()
	preparation_status.text = PREPARATION_MESSAGES[_preparation_message_index]

func show_for_main_menu() -> void:
	_show_transition("main_menu")

func show_for_match_readiness() -> void:
	_show_transition("match")

func _show_transition(kind: String) -> void:
	_transition_generation += 1
	_cancel_fade()
	_cancel_eye_fade()
	_active = true
	_transition_kind = kind
	_shown_at_msec = Time.get_ticks_msec()
	_set_cover_alpha(1.0)
	_set_logo_eyes_alpha(0.0)
	_set_preparation_status_alpha(1.0)
	_preparation_message_index = 0
	_preparation_message_elapsed = 0.0
	preparation_status.text = PREPARATION_MESSAGES[0]
	preparation_status.visible = kind == "match"
	_loading_progress.value = 0.0
	_loading_progress.modulate.a = 1.0
	_loading_progress.visible = kind == "match"
	_sponsor_content.modulate.a = 1.0
	_match_ad.stop()
	_internal_content.stop()
	_loading_content = _match_ad
	_sponsor_content.visible = false
	set_process(kind == "match")
	visible = true
	_layout_loading_content()
	if kind == "match":
		var manager: Node = get_node_or_null("/root/AdManager")
		var policy: Dictionary = manager.call("get_policy", "match_loading", "handshake") if manager != null else {}
		if bool(policy.get("zero_ads", false)) and bool(policy.get("surface_allowed", false)):
			_loading_content = _internal_content
			_internal_content.prepare()
			_sponsor_label.text = _internal_content.category_label()
			_sponsor_note.text = "Around the swarm, while your arena gets ready."
		else:
			_match_ad.prepare()
			_sponsor_label.text = "SPONSORED"
			_sponsor_note.text = "Thanks for keeping Swarmfront free while we prep your arena."
		_sponsor_content.visible = _loading_content.visible
		_start_match_ad_after_draw(_transition_generation)
	_begin_logo_eyes_fade(_transition_generation)

func present_for_main_menu() -> void:
	show_for_main_menu()
	await _await_presented()

func present_for_match_readiness() -> void:
	show_for_match_readiness()
	await _await_presented()

func _await_presented() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	# A process tick alone does not prove the cover reached the display. Waiting
	# for post-draw guarantees the branding frame exists before scene loading.
	await tree.process_frame
	if not _is_headless():
		await RenderingServer.frame_post_draw
	# Scene loading can starve UI animation frames on slower devices. Do not
	# return control to the shell until the eyes are visibly lit and drawn.
	var presentation_generation: int = _transition_generation
	while presentation_generation == _transition_generation and _active and logo_eyes.modulate.a < EYE_LOADING_HANDOFF_ALPHA:
		await tree.process_frame
	if presentation_generation != _transition_generation or not _active:
		return
	if not _is_headless():
		await RenderingServer.frame_post_draw

func release_after_main_menu_ready() -> void:
	await _release_after_ready()

func release_after_match_ready() -> void:
	await _release_after_ready()

func _release_after_ready() -> void:
	if not _active:
		return
	var release_generation: int = _transition_generation
	var tree: SceneTree = get_tree()
	if tree == null:
		hide_immediately()
		return
	var elapsed_seconds: float = float(Time.get_ticks_msec() - _shown_at_msec) / 1000.0
	var remaining_seconds: float = maxf(0.0, minimum_visible_seconds - elapsed_seconds)
	if remaining_seconds > 0.0:
		await tree.create_timer(remaining_seconds, true, false, true).timeout
	if release_generation != _transition_generation or not _active:
		return
	if _transition_kind == "match":
		_loading_progress.value = 100.0
		while release_generation == _transition_generation and _active and bool(_loading_content.call("is_pending")):
			await tree.process_frame
	if release_generation != _transition_generation or not _active:
		return
	# Let the initialized menu render under the opaque cover before revealing it.
	await tree.process_frame
	if not _is_headless():
		await RenderingServer.frame_post_draw
	if release_generation != _transition_generation or not _active:
		return
	await _finish_logo_eyes_fade(release_generation)
	if release_generation != _transition_generation or not _active:
		return
	if fade_seconds <= 0.0:
		hide_immediately()
		return
	_cancel_fade()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(black, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_property(signage, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_property(logo_eyes, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_property(preparation_status, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_property(_loading_progress, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_property(_sponsor_content, "modulate:a", 0.0, fade_seconds)
	await _fade_tween.finished
	if release_generation == _transition_generation:
		hide_immediately()

func hide_immediately() -> void:
	_transition_generation += 1
	_cancel_fade()
	_cancel_eye_fade()
	_active = false
	_transition_kind = ""
	set_process(false)
	visible = false
	_set_cover_alpha(1.0)
	_set_logo_eyes_alpha(0.0)
	_set_preparation_status_alpha(1.0)
	preparation_status.visible = false
	_match_ad.stop()
	_internal_content.stop()
	_loading_progress.hide()
	_sponsor_content.hide()

func is_transition_active() -> bool:
	return _active and visible

func is_match_transition_active() -> bool:
	return _active and visible and _transition_kind == "match"

func set_match_readiness_stage(stage: String) -> void:
	if _transition_kind != "match":
		return
	var clean_stage: String = stage.strip_edges().to_lower()
	if PREPARATION_STAGE_MESSAGES.has(clean_stage):
		preparation_status.text = str(PREPARATION_STAGE_MESSAGES[clean_stage])
		_preparation_message_elapsed = 0.0
	# Milestones represent arena preparation, not elapsed ad time. Some launch
	# paths revisit map/scene stages, so progress must never move backwards.
	var milestones: Dictionary = {"scene": 20.0, "map": 40.0, "render": 70.0, "final": 90.0}
	_loading_progress.value = maxf(_loading_progress.value, float(milestones.get(clean_stage, 0.0)))

func _build_match_loading_ui() -> void:
	for control: Control in [signage, logo_eyes, preparation_status]:
		var geometry: Array[float] = []
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			geometry.append(control.get_anchor(side))
			geometry.append(control.get_offset(side))
		_menu_geometry[control.name] = geometry
	_menu_signage_texture = signage.texture
	_match_signage_texture = AtlasTexture.new()
	_match_signage_texture.atlas = signage.texture
	_match_signage_texture.region = Rect2(100.0, 310.0, 1340.0, 350.0)
	_loading_progress = ProgressBar.new()
	_loading_progress.name = "LoadingProgress"
	_loading_progress.show_percentage = false
	_loading_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.10, 0.09, 0.06)
	background.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.77, 0.10)
	fill.set_corner_radius_all(8)
	_loading_progress.add_theme_stylebox_override("background", background)
	_loading_progress.add_theme_stylebox_override("fill", fill)
	_loading_progress.hide()
	add_child(_loading_progress)
	_sponsor_content = Control.new()
	_sponsor_content.name = "LoadingSponsor"
	_sponsor_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sponsor_content.hide()
	add_child(_sponsor_content)
	_sponsor_label = _make_loading_label("SPONSORED", 22, Color(0.67, 0.66, 0.61))
	_sponsor_content.add_child(_sponsor_label)
	_match_ad = MatchLoadingAd.new()
	_match_ad.name = "MatchLoadingAd"
	_sponsor_content.add_child(_match_ad)
	_internal_content = MatchLoadingContent.new()
	_internal_content.name = "SwarmfrontLoadingContent"
	_sponsor_content.add_child(_internal_content)
	_loading_content = _match_ad
	_sponsor_note = _make_loading_label("Thanks for keeping Swarmfront free while we prep your arena.", 24, Color(0.77, 0.76, 0.70))
	_sponsor_content.add_child(_sponsor_note)

func _make_loading_label(copy: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = copy
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _layout_loading_content() -> void:
	if _transition_kind != "match":
		signage.texture = _menu_signage_texture
		for control: Control in [signage, logo_eyes, preparation_status]:
			var geometry: Array = _menu_geometry[control.name]
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				control.set_anchor(side, geometry[side * 2])
				control.set_offset(side, geometry[side * 2 + 1])
		return
	var safe: Rect2 = MatchHudLayout.safe_rect_for_viewport(get_viewport())
	var w: float = safe.size.x
	var h: float = safe.size.y
	var margin: float = w * 0.05
	var eye_size: float = minf(w * 0.52, h * 0.25)
	signage.texture = _match_signage_texture
	_place_loading_control(logo_eyes, Rect2(safe.position + Vector2((w - eye_size) * 0.5, h * 0.015), Vector2(eye_size, eye_size)))
	_place_loading_control(signage, Rect2(safe.position + Vector2(margin, h * 0.26), Vector2(w - margin * 2.0, h * 0.12)))
	_place_loading_control(_loading_progress, Rect2(safe.position + Vector2(w * 0.13, h * 0.40), Vector2(w * 0.74, maxf(8.0, h * 0.007))))
	_place_loading_control(preparation_status, Rect2(safe.position + Vector2(margin, h * 0.425), Vector2(w - margin * 2.0, h * 0.06)))
	_place_loading_control(_sponsor_content, Rect2(safe.position + Vector2(margin, h * 0.51), Vector2(w - margin * 2.0, h * 0.47)))
	_place_loading_control(_sponsor_label, Rect2(Vector2.ZERO, Vector2(_sponsor_content.size.x, h * 0.025)))
	_place_loading_control(_match_ad, Rect2(Vector2(0.0, h * 0.035), Vector2(_sponsor_content.size.x, h * 0.385)))
	_place_loading_control(_internal_content, Rect2(Vector2(0.0, h * 0.035), Vector2(_sponsor_content.size.x, h * 0.385)))
	_place_loading_control(_sponsor_note, Rect2(Vector2(0.0, h * 0.43), Vector2(_sponsor_content.size.x, h * 0.04)))

func _place_loading_control(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size

func _start_match_ad_after_draw(generation: int) -> void:
	await get_tree().process_frame
	if not _is_headless():
		await RenderingServer.frame_post_draw
	if generation == _transition_generation and is_match_transition_active():
		# configure() sets a minimum size; restore the reserved half-screen layout.
		_layout_loading_content()
		_loading_content.call("start_playback")

func _set_cover_alpha(alpha: float) -> void:
	var resolved_alpha: float = clampf(alpha, 0.0, 1.0)
	if black != null:
		black.modulate.a = resolved_alpha
	if signage != null:
		signage.modulate.a = resolved_alpha

func _set_logo_eyes_alpha(alpha: float) -> void:
	if logo_eyes != null:
		logo_eyes.modulate.a = clampf(alpha, 0.0, 1.0)

func _set_preparation_status_alpha(alpha: float) -> void:
	if preparation_status != null:
		preparation_status.modulate.a = clampf(alpha, 0.0, 1.0)

func _begin_logo_eyes_fade(generation: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if eye_fade_delay_seconds > 0.0:
		await tree.create_timer(eye_fade_delay_seconds, true, false, true).timeout
	if generation != _transition_generation or not _active:
		return
	_cancel_eye_fade()
	if eye_fade_seconds <= 0.0:
		_set_logo_eyes_alpha(EYE_CRUISE_ALPHA)
		return
	_eye_fade_tween = create_tween()
	_eye_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_eye_fade_tween.tween_property(logo_eyes, "modulate:a", EYE_CRUISE_ALPHA, eye_fade_seconds)

func _finish_logo_eyes_fade(generation: int) -> void:
	_cancel_eye_fade()
	if generation != _transition_generation or not _active:
		return
	if eye_final_brighten_seconds <= 0.0:
		_set_logo_eyes_alpha(1.0)
		return
	_eye_fade_tween = create_tween()
	_eye_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_eye_fade_tween.tween_property(logo_eyes, "modulate:a", 1.0, eye_final_brighten_seconds)
	await _eye_fade_tween.finished

func _cancel_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null

func _cancel_eye_fade() -> void:
	if _eye_fade_tween != null and _eye_fade_tween.is_valid():
		_eye_fade_tween.kill()
	_eye_fade_tween = null

func _is_headless() -> bool:
	return OS.has_feature("server") or DisplayServer.get_name() == "headless"
