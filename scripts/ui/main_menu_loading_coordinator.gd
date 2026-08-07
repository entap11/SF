extends CanvasLayer

const DEFAULT_MIN_VISIBLE_SECONDS: float = 5.0
const DEFAULT_FADE_SECONDS: float = 0.22
const DEFAULT_EYE_FADE_DELAY_SECONDS: float = 0.35
const DEFAULT_EYE_FADE_SECONDS: float = 2.6
const DEFAULT_EYE_FINAL_BRIGHTEN_SECONDS: float = 0.1
const EYE_CRUISE_ALPHA: float = 0.9
# Tween interpolation can finish a few floating-point ulps below its target.
# A 99% threshold is visually complete without relying on exact float equality.
const EYE_LOADING_HANDOFF_ALPHA: float = EYE_CRUISE_ALPHA * 0.99

@export_range(0.0, 5.0, 0.05) var minimum_visible_seconds: float = DEFAULT_MIN_VISIBLE_SECONDS
@export_range(0.0, 2.0, 0.01) var fade_seconds: float = DEFAULT_FADE_SECONDS
@export_range(0.0, 5.0, 0.05) var eye_fade_delay_seconds: float = DEFAULT_EYE_FADE_DELAY_SECONDS
@export_range(0.0, 10.0, 0.05) var eye_fade_seconds: float = DEFAULT_EYE_FADE_SECONDS
@export_range(0.0, 1.0, 0.01) var eye_final_brighten_seconds: float = DEFAULT_EYE_FINAL_BRIGHTEN_SECONDS

@onready var black: ColorRect = $Black
@onready var signage: TextureRect = $Signage
@onready var logo_eyes: TextureRect = $LogoEyes

var _active: bool = false
var _shown_at_msec: int = 0
var _transition_generation: int = 0
var _fade_tween: Tween = null
var _eye_fade_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_set_cover_alpha(1.0)
	_set_logo_eyes_alpha(0.0)

func show_for_main_menu() -> void:
	_transition_generation += 1
	_cancel_fade()
	_cancel_eye_fade()
	_active = true
	_shown_at_msec = Time.get_ticks_msec()
	_set_cover_alpha(1.0)
	_set_logo_eyes_alpha(0.0)
	visible = true
	_begin_logo_eyes_fade(_transition_generation)

func present_for_main_menu() -> void:
	show_for_main_menu()
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
	if not _active:
		return
	var release_generation: int = _transition_generation
	var tree: SceneTree = get_tree()
	if tree == null:
		hide_immediately()
		return
	var elapsed_seconds: float = float(Time.get_ticks_msec() - _shown_at_msec) / 1000.0
	# The configured minimum describes the complete branded transition, including
	# the final eye brighten and cover fade, so a five-second presentation does
	# not accidentally become 5.32 seconds.
	var exit_seconds: float = maxf(0.0, eye_final_brighten_seconds) + maxf(0.0, fade_seconds)
	var remaining_seconds: float = maxf(0.0, minimum_visible_seconds - elapsed_seconds - exit_seconds)
	if remaining_seconds > 0.0:
		await tree.create_timer(remaining_seconds, true, false, true).timeout
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
	await _fade_tween.finished
	if release_generation == _transition_generation:
		hide_immediately()

func hide_immediately() -> void:
	_transition_generation += 1
	_cancel_fade()
	_cancel_eye_fade()
	_active = false
	visible = false
	_set_cover_alpha(1.0)
	_set_logo_eyes_alpha(0.0)

func is_transition_active() -> bool:
	return _active and visible

func _set_cover_alpha(alpha: float) -> void:
	var resolved_alpha: float = clampf(alpha, 0.0, 1.0)
	if black != null:
		black.modulate.a = resolved_alpha
	if signage != null:
		signage.modulate.a = resolved_alpha

func _set_logo_eyes_alpha(alpha: float) -> void:
	if logo_eyes != null:
		logo_eyes.modulate.a = clampf(alpha, 0.0, 1.0)

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
	# A symmetric ease keeps the glow from popping into visibility at the start;
	# it builds gently, blooms through the middle, then settles into cruise.
	_eye_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
