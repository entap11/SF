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
const CONTEXT_NONE: String = ""
const CONTEXT_MAIN_MENU: String = "main_menu"
const CONTEXT_MATCH: String = "match"
const MATCH_LOADING_AD_SLOT: String = "match_loading_handshake"
const MATCH_LOADING_AD_PLACEMENT: String = "handshake"
const MATCH_LOADING_AD_SIZE: Vector2 = Vector2(780.0, 292.0)
const MATCH_LOADING_AD_DURATION_MS: int = 8000
const DEFAULT_MATCH_MIN_VISIBLE_SECONDS: float = 7.0
const MATCH_SAYINGS_PER_LOAD: int = 4

const MATCH_LOADING_SAYING_POOL: Array[String] = [
	"Packing the pollen...",
	"Calibrating the waggle dance...",
	"Checking the queen's Wi-Fi...",
	"Sharpening tiny stingers...",
	"Untangling flight paths...",
	"Counting every last bee...",
	"Pressurizing the honey...",
	"Polishing the royal jelly...",
	"Charging the bees...",
	"Negotiating with the drones...",
	"Mapping the flower district...",
	"Fastening microscopic helmets..."
]

const MENU_BOOT_PROGRESS: Dictionary = {
	"load_fonts": [12, "Teaching bees to read..."],
	"background_art": [18, "Painting the hive..."],
	"tier_widget": [23, "Counting royal jelly..."],
	"honey_widget": [28, "Bottling the honey..."],
	"style_labels": [33, "Polishing the signs..."],
	"friends_tab": [39, "Finding friendly bees..."],
	"beta_help_tab": [44, "Checking the beekeeper's notes..."],
	"scholastic_surface": [49, "Studying swarm theory..."],
	"style_buttons": [55, "Waxing the buttons..."],
	"bottom_nav_sprites": [60, "Drawing flight paths..."],
	"bottom_nav_layout": [64, "Aligning the honeycomb..."],
	"style_panels": [68, "Straightening the hive..."],
	"hive_mobile_layout": [72, "Making room for wings..."],
	"entry_skin_prewarm_start": [76, "Warming the wax..."],
	"async_stage_section": [80, "Scheduling the swarm..."],
	"payout_button": [83, "Counting nectar..."],
	"wire_buttons": [86, "Connecting the comb..."],
	"set_hex_buttons": [89, "Snapping in hexes..."],
	"safe_area_layout": [91, "Checking the flight ceiling..."],
	"home_replay_player": [93, "Rehearsing the last battle..."],
	"store_landing": [95, "Stocking the hive..."],
	"buffs_ui": [97, "Charging the bees..."],
	"hex_backgrounds": [98, "Sealing the honeycomb..."],
	"commerce_state": [99, "Queen's final inspection..."]
}

@export_range(0.0, 5.0, 0.05) var minimum_visible_seconds: float = DEFAULT_MIN_VISIBLE_SECONDS
@export_range(0.0, 15.0, 0.1) var match_minimum_visible_seconds: float = DEFAULT_MATCH_MIN_VISIBLE_SECONDS
@export_range(0.0, 2.0, 0.01) var fade_seconds: float = DEFAULT_FADE_SECONDS
@export_range(0.0, 5.0, 0.05) var eye_fade_delay_seconds: float = DEFAULT_EYE_FADE_DELAY_SECONDS
@export_range(0.0, 10.0, 0.05) var eye_fade_seconds: float = DEFAULT_EYE_FADE_SECONDS
@export_range(0.0, 1.0, 0.01) var eye_final_brighten_seconds: float = DEFAULT_EYE_FINAL_BRIGHTEN_SECONDS

@onready var black: ColorRect = $Black
@onready var signage: TextureRect = $Signage
@onready var logo_eyes: TextureRect = $LogoEyes
@onready var match_ad_panel: Control = $MatchAdPanel
@onready var match_ad_surface: Control = $MatchAdPanel/Surface
@onready var match_ad_countdown: Label = $MatchAdPanel/Countdown
@onready var loading_panel: Control = $LoadingPanel
@onready var status_label: Label = $LoadingPanel/Status
@onready var progress_bar: ProgressBar = $LoadingPanel/ProgressRow/ProgressBar
@onready var percent_label: Label = $LoadingPanel/ProgressRow/Percent

var _active: bool = false
var _shown_at_msec: int = 0
var _transition_generation: int = 0
var _fade_tween: Tween = null
var _eye_fade_tween: Tween = null
var _context: String = CONTEXT_NONE
var _progress_percent: int = 0
var _match_ad_deadline_server_ms: int = 0
var _match_ad_server_offset_ms: int = 0
var _match_saying_rotation_index: int = 0
var _match_loading_sayings: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	visible = false
	_set_cover_alpha(1.0)
	_set_logo_eyes_alpha(0.0)
	_reset_match_ad_surface()

func _process(_delta: float) -> void:
	if not is_match_loading_active() or _match_ad_deadline_server_ms <= 0:
		set_process(false)
		return
	var remaining_ms: int = maxi(0, _match_ad_deadline_server_ms - _synchronized_server_now_ms())
	_update_match_ad_countdown(remaining_ms)
	if remaining_ms <= 0:
		set_process(false)

func show_for_main_menu() -> void:
	_show(CONTEXT_MAIN_MENU, 6, "Opening the hive...")

func _show(context: String, progress_percent: int, message: String) -> void:
	_transition_generation += 1
	_cancel_fade()
	_cancel_eye_fade()
	_active = true
	_context = context
	_shown_at_msec = Time.get_ticks_msec()
	_set_cover_alpha(1.0)
	_set_logo_eyes_alpha(0.0)
	_reset_match_ad_surface()
	_set_loading_progress(progress_percent, message, false)
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

func present_for_match_loading() -> void:
	_prepare_match_loading_sayings()
	_show(CONTEXT_MATCH, 6, _match_loading_saying(0))
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	# Match preparation continues while the eyes animate. We only need to prove
	# the opaque branded frame reached the display before doing heavier work.
	await tree.process_frame
	if not _is_headless():
		await RenderingServer.frame_post_draw

func note_main_menu_boot_step(step_name: String) -> void:
	if not is_main_menu_loading_active() or not MENU_BOOT_PROGRESS.has(step_name):
		return
	var milestone: Array = MENU_BOOT_PROGRESS[step_name] as Array
	update_loading_progress(int(milestone[0]), str(milestone[1]))

func update_match_loading_progress(progress_percent: int, message: String) -> void:
	if not is_match_loading_active():
		return
	var resolved_progress: int = maxi(_progress_percent, clampi(progress_percent, 0, 100))
	var saying_index: int = clampi(int(floor(float(resolved_progress) / 25.0)), 0, MATCH_SAYINGS_PER_LOAD - 1)
	var rotated_message: String = _match_loading_saying(saying_index)
	update_loading_progress(progress_percent, rotated_message if not rotated_message.is_empty() else message)

func begin_synchronized_match_ad(start_unix_ms: int, server_offset_ms: int, prematch_duration_ms: int) -> void:
	if not is_match_loading_active() or start_unix_ms <= 0:
		return
	_match_ad_server_offset_ms = server_offset_ms
	_match_ad_deadline_server_ms = start_unix_ms - maxi(0, prematch_duration_ms)
	var remaining_ms: int = maxi(0, _match_ad_deadline_server_ms - _synchronized_server_now_ms())
	if remaining_ms <= 0:
		return
	if match_ad_surface != null:
		# Reserve the scheduled rectangle even if the certification provider ever
		# misses a fill, so a failed creative cannot masquerade as empty loading UI.
		match_ad_surface.call("configure", MATCH_LOADING_AD_SLOT, MATCH_LOADING_AD_PLACEMENT, MATCH_LOADING_AD_SIZE, true)
		if match_ad_surface.has_method("set_interaction_enabled"):
			match_ad_surface.call("set_interaction_enabled", false)
		if match_ad_surface.has_method("set_presentation_enabled"):
			match_ad_surface.call("set_presentation_enabled", true)
	if match_ad_panel != null:
		match_ad_panel.visible = true
	_update_match_ad_countdown(mini(MATCH_LOADING_AD_DURATION_MS, remaining_ms))
	set_process(true)

func update_loading_progress(progress_percent: int, message: String = "") -> void:
	if not _active:
		return
	_set_loading_progress(progress_percent, message, true)

func _set_loading_progress(progress_percent: int, message: String, monotonic: bool) -> void:
	var resolved_percent: int = clampi(progress_percent, 0, 100)
	if monotonic:
		resolved_percent = maxi(_progress_percent, resolved_percent)
	_progress_percent = resolved_percent
	if progress_bar != null:
		progress_bar.value = float(_progress_percent)
	if percent_label != null:
		percent_label.text = "%d%%" % _progress_percent
	if status_label != null and not message.strip_edges().is_empty():
		status_label.text = message.strip_edges()

func release_after_main_menu_ready() -> void:
	if not _active:
		return
	update_loading_progress(100, "Hive ready.")
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
	_fade_tween.tween_property(loading_panel, "modulate:a", 0.0, fade_seconds)
	await _fade_tween.finished
	if release_generation == _transition_generation:
		hide_immediately()

func release_for_synchronized_prematch() -> void:
	if not is_match_loading_active():
		return
	var release_generation: int = _transition_generation
	update_match_loading_progress(100, "")
	var tree: SceneTree = get_tree()
	if tree == null:
		hide_immediately()
		return
	var elapsed_seconds: float = float(Time.get_ticks_msec() - _shown_at_msec) / 1000.0
	var remaining_seconds: float = maxf(0.0, match_minimum_visible_seconds - elapsed_seconds)
	if remaining_seconds > 0.0:
		await tree.create_timer(remaining_seconds, true, false, true).timeout
	if release_generation != _transition_generation or not is_match_loading_active():
		return
	# Draw the completed bar over an already-rendered Arena, then clear the cover
	# just ahead of the shared countdown. The relay lead normally satisfies the
	# seven-second minimum before this method is reached; this is the client-side
	# guarantee if a future transport returns the shared epoch unusually early.
	await tree.process_frame
	if not _is_headless():
		await RenderingServer.frame_post_draw
	if release_generation != _transition_generation or not is_match_loading_active():
		return
	_set_logo_eyes_alpha(1.0)
	if fade_seconds <= 0.0:
		hide_immediately()
		return
	_cancel_fade()
	_cancel_eye_fade()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(black, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_property(signage, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_property(logo_eyes, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_property(match_ad_panel, "modulate:a", 0.0, fade_seconds)
	_fade_tween.tween_property(loading_panel, "modulate:a", 0.0, fade_seconds)
	await _fade_tween.finished
	if release_generation == _transition_generation:
		hide_immediately()

func cancel_match_loading() -> void:
	if is_match_loading_active():
		hide_immediately()

func hide_immediately() -> void:
	_transition_generation += 1
	_cancel_fade()
	_cancel_eye_fade()
	_active = false
	_context = CONTEXT_NONE
	_progress_percent = 0
	visible = false
	_set_cover_alpha(1.0)
	_set_logo_eyes_alpha(0.0)
	_reset_match_ad_surface()
	if progress_bar != null:
		progress_bar.value = 0.0
	if percent_label != null:
		percent_label.text = "0%"

func is_transition_active() -> bool:
	return _active and visible

func is_main_menu_loading_active() -> bool:
	return is_transition_active() and _context == CONTEXT_MAIN_MENU

func is_match_loading_active() -> bool:
	return is_transition_active() and _context == CONTEXT_MATCH

func _set_cover_alpha(alpha: float) -> void:
	var resolved_alpha: float = clampf(alpha, 0.0, 1.0)
	if black != null:
		black.modulate.a = resolved_alpha
	if signage != null:
		signage.modulate.a = resolved_alpha
	if loading_panel != null:
		loading_panel.modulate.a = resolved_alpha
	if match_ad_panel != null:
		match_ad_panel.modulate.a = resolved_alpha

func _reset_match_ad_surface() -> void:
	_match_ad_deadline_server_ms = 0
	_match_ad_server_offset_ms = 0
	set_process(false)
	if match_ad_surface != null and match_ad_surface.has_method("set_presentation_enabled"):
		match_ad_surface.call("set_presentation_enabled", false)
	if match_ad_panel != null:
		match_ad_panel.visible = false
	if match_ad_countdown != null:
		match_ad_countdown.text = "Match countdown follows • 8s"

func _update_match_ad_countdown(remaining_ms: int) -> void:
	if match_ad_countdown == null:
		return
	var bounded_ms: int = mini(MATCH_LOADING_AD_DURATION_MS, maxi(0, remaining_ms))
	var seconds_left: int = maxi(1, int(ceil(float(bounded_ms) / 1000.0))) if bounded_ms > 0 else 0
	match_ad_countdown.text = "Match countdown follows • %ds" % seconds_left

func _prepare_match_loading_sayings() -> void:
	_match_loading_sayings.clear()
	if MATCH_LOADING_SAYING_POOL.is_empty():
		return
	for offset in range(MATCH_SAYINGS_PER_LOAD):
		var pool_index: int = (_match_saying_rotation_index + offset) % MATCH_LOADING_SAYING_POOL.size()
		_match_loading_sayings.append(MATCH_LOADING_SAYING_POOL[pool_index])
	_match_saying_rotation_index = (_match_saying_rotation_index + MATCH_SAYINGS_PER_LOAD) % MATCH_LOADING_SAYING_POOL.size()

func _match_loading_saying(index: int) -> String:
	if _match_loading_sayings.is_empty():
		return "Loading the arena..."
	return _match_loading_sayings[clampi(index, 0, _match_loading_sayings.size() - 1)]

func _synchronized_server_now_ms() -> int:
	return int(round(Time.get_unix_time_from_system() * 1000.0)) + _match_ad_server_offset_ms

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
