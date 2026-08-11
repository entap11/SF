extends SceneTree

const LOADING_COVER_SCENE_PATH: String = "res://scenes/ui/MainMenuLoadingCover.tscn"
const SHELL_SCENE_PATH: String = "res://scenes/Shell.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/MainMenu.tscn"
const SIGNAGE_PATH: String = "res://assets/sprites/sf_skin_v1/signage_main_yellow.png"
const LOGO_EYES_PATH: String = "res://assets/branding/swarmfront_logo_1024.png"
const BANNER_OFFSET_Y_PX: float = 25.0

var _failed: bool = false

func _init() -> void:
	call_deferred("_execute")

func _execute() -> void:
	await process_frame
	await _run()
	quit(1 if _failed else 0)

func _run() -> void:
	var cover_scene: PackedScene = load(LOADING_COVER_SCENE_PATH) as PackedScene
	_expect(cover_scene != null, "loading cover scene should load")
	if cover_scene == null:
		return
	var cover: Variant = cover_scene.instantiate()
	_expect(cover != null, "loading cover root should be a CanvasLayer")
	if cover == null:
		return
	_expect(not cover.visible, "persistent loading cover should start hidden")
	_expect(cover.layer >= 100, "loading cover should render above shell and menu UI", {"layer": cover.layer})
	_expect(cover.has_method("present_for_main_menu"), "loading cover should support a guaranteed rendered presentation")
	_expect(cover.has_method("release_after_main_menu_ready"), "loading cover should wait for explicit main-menu readiness")
	_expect(cover.has_method("present_for_match_loading"), "loading cover should support synchronized match preparation")
	_expect(cover.has_method("update_match_loading_progress"), "loading cover should expose real match-loading milestones")
	_expect(cover.has_method("begin_synchronized_match_ad"), "loading cover should expose a server-clocked match ad window")
	_expect(cover.has_method("release_for_synchronized_prematch"), "loading cover should release into the shared prematch clock")
	_expect(cover.has_method("hide_immediately"), "loading cover should support failure cleanup")
	_expect(float(cover.get("minimum_visible_seconds")) >= 5.0, "loading cover should reserve a deliberate five-second branding beat", {
		"minimum_visible_seconds": cover.get("minimum_visible_seconds")
	})
	_expect(is_equal_approx(float(cover.get("match_minimum_visible_seconds")), 7.0), "handshake-to-arena loading should reserve a seven-second minimum", {
		"match_minimum_visible_seconds": cover.get("match_minimum_visible_seconds")
	})
	_expect(float(cover.get("eye_fade_seconds")) >= 2.5 and float(cover.get("eye_fade_seconds")) <= 3.0, "logo glow should use a slow, controlled build", {
		"eye_fade_seconds": cover.get("eye_fade_seconds")
	})
	var black: ColorRect = cover.get_node_or_null("Black") as ColorRect
	var signage: TextureRect = cover.get_node_or_null("Signage") as TextureRect
	var logo_eyes: TextureRect = cover.get_node_or_null("LogoEyes") as TextureRect
	var match_ad_panel: Control = cover.get_node_or_null("MatchAdPanel") as Control
	var match_ad_surface: Control = cover.get_node_or_null("MatchAdPanel/Surface") as Control
	var match_ad_countdown: Label = cover.get_node_or_null("MatchAdPanel/Countdown") as Label
	var loading_panel: Control = cover.get_node_or_null("LoadingPanel") as Control
	var loading_status: Label = cover.get_node_or_null("LoadingPanel/Status") as Label
	var loading_progress: ProgressBar = cover.get_node_or_null("LoadingPanel/ProgressRow/ProgressBar") as ProgressBar
	var loading_percent: Label = cover.get_node_or_null("LoadingPanel/ProgressRow/Percent") as Label
	_expect(black != null and black.color == Color.BLACK, "loading cover should have an opaque black background")
	_expect(black != null and black.mouse_filter == Control.MOUSE_FILTER_STOP, "loading cover should block input during transition")
	_expect(signage != null and signage.texture != null, "loading cover should display the yellow signage")
	if signage != null and signage.texture != null:
		_expect(signage.texture.resource_path == SIGNAGE_PATH, "loading cover should reuse the main-menu yellow signage", {
			"actual": signage.texture.resource_path
		})
		_expect(is_equal_approx(signage.offset_top, BANNER_OFFSET_Y_PX) and is_equal_approx(signage.offset_bottom, BANNER_OFFSET_Y_PX), "loading banner should sit 25 px below center", {
			"offset_top": signage.offset_top,
			"offset_bottom": signage.offset_bottom
		})
	_expect(logo_eyes != null and logo_eyes.texture != null, "loading cover should display the centered logo eyes")
	_expect(match_ad_panel != null and not match_ad_panel.visible, "match ad surface should stay hidden during ordinary boot")
	_expect(match_ad_surface != null and match_ad_surface.get_script() != null, "match loading should reuse the governed AdSurface implementation")
	_expect(match_ad_countdown != null, "match ad surface should disclose its remaining window")
	_expect(loading_panel != null, "loading cover should include the progress surface")
	_expect(loading_status != null and not loading_status.text.is_empty(), "loading cover should include a status saying")
	_expect(loading_progress != null and not loading_progress.show_percentage, "loading cover should include a custom-styled progress bar")
	_expect(loading_percent != null, "loading cover should show an explicit loaded percentage")
	if logo_eyes != null and logo_eyes.texture != null:
		_expect(logo_eyes.texture.resource_path == LOGO_EYES_PATH, "loading cover should reuse the canonical logo eyes", {
			"actual": logo_eyes.texture.resource_path
		})
		_expect(is_equal_approx(logo_eyes.anchor_left, 0.5) and is_equal_approx(logo_eyes.anchor_right, 0.5), "logo eyes should remain horizontally centered")
		_expect(is_equal_approx(logo_eyes.anchor_top, 0.25) and is_equal_approx(logo_eyes.anchor_bottom, 0.25), "logo eyes should remain proportionally centered above the banner")
	get_root().add_child(cover)
	await process_frame
	cover.set("minimum_visible_seconds", 0.12)
	cover.set("fade_seconds", 0.01)
	cover.set("eye_fade_delay_seconds", 0.02)
	cover.set("eye_fade_seconds", 0.2)
	cover.set("eye_final_brighten_seconds", 0.01)
	cover.set("match_minimum_visible_seconds", 0.12)
	await cover.present_for_main_menu()
	_expect(logo_eyes.modulate.a >= 0.88, "coordinator should complete the logo glow before handing off to menu loading", {
		"alpha": logo_eyes.modulate.a
	})
	cover.hide_immediately()
	cover.show_for_main_menu()
	_expect(cover.visible, "coordinator should become visible before menu loading begins")
	_expect(cover.is_transition_active(), "coordinator should report an active transition")
	_expect(is_equal_approx(logo_eyes.modulate.a, 0.0), "logo eyes should begin dark before their delayed fade")
	var shown_at_msec: int = Time.get_ticks_msec()
	await create_timer(0.06, true, false, true).timeout
	_expect(logo_eyes.modulate.a > 0.0 and logo_eyes.modulate.a < 0.9, "logo eyes should fade in gradually after their delay", {
		"alpha": logo_eyes.modulate.a
	})
	await cover.release_after_main_menu_ready()
	var visible_msec: int = Time.get_ticks_msec() - shown_at_msec
	_expect(not cover.visible, "coordinator should hide cleanly after Main Menu reports readiness")
	_expect(visible_msec >= 115, "coordinator should honor its minimum branding duration", {"visible_msec": visible_msec})
	await cover.present_for_match_loading()
	_expect(cover.is_match_loading_active(), "match loading should use a distinct active context")
	var match_shown_at_msec: int = int(cover.get("_shown_at_msec"))
	var selected_match_sayings: Array = cover.get("_match_loading_sayings") as Array
	var unique_match_sayings: Dictionary = {}
	for saying_any in selected_match_sayings:
		unique_match_sayings[str(saying_any)] = true
	_expect(selected_match_sayings.size() == 4 and unique_match_sayings.size() == 4, "one match load should select exactly four unique sayings", {
		"sayings": selected_match_sayings
	})
	var test_start_ms: int = int(round(Time.get_unix_time_from_system() * 1000.0)) + 18000
	cover.begin_synchronized_match_ad(test_start_ms, 0, 10000)
	_expect(match_ad_panel.visible, "server start epoch should reveal the match-loading ad surface")
	_expect(match_ad_surface.mouse_filter == Control.MOUSE_FILTER_IGNORE, "scheduled gameplay ads should not offer a tap that can pull players out of the match")
	_expect(match_ad_countdown.text.contains("8s"), "match-loading ad should reserve an eight-second display window", {
		"text": match_ad_countdown.text
	})
	cover.update_match_loading_progress(72, "technical milestone")
	_expect(is_equal_approx(loading_progress.value, 72.0), "match milestone should advance the loading bar", {
		"value": loading_progress.value
	})
	_expect(loading_percent.text == "72%", "match milestone should update the explicit percentage", {
		"text": loading_percent.text
	})
	_expect(selected_match_sayings.has(loading_status.text), "match milestone should use one of the four selected sayings", {"text": loading_status.text})
	cover.update_match_loading_progress(40, "Regressing")
	_expect(is_equal_approx(loading_progress.value, 72.0), "loading progress should remain monotonic")
	await cover.release_for_synchronized_prematch()
	var match_visible_msec: int = Time.get_ticks_msec() - match_shown_at_msec
	_expect(not cover.visible, "shared prematch release should hide the match cover")
	_expect(match_visible_msec >= 115, "shared prematch release should honor the configured match minimum", {"visible_msec": match_visible_msec})
	cover.free()
	var autoload_path: String = str(ProjectSettings.get_setting("autoload/MainMenuLoadingCoordinator", ""))
	_expect(autoload_path == "*%s" % LOADING_COVER_SCENE_PATH, "loading cover should be registered as a persistent autoload", {
		"actual": autoload_path
	})
	var coordinator: CanvasLayer = get_root().get_node_or_null("MainMenuLoadingCoordinator") as CanvasLayer
	_expect(coordinator != null, "persistent loading coordinator should exist above the current scene")
	_expect(coordinator == null or not coordinator.visible, "autoloaded coordinator should remain hidden outside transitions")

	var shell_scene: PackedScene = load(SHELL_SCENE_PATH) as PackedScene
	var shell: Node = shell_scene.instantiate() if shell_scene != null else null
	_expect(shell != null, "shell scene should instantiate")
	var shell_cover: CanvasLayer = shell.get_node_or_null("MainMenuLoadingCover") as CanvasLayer if shell != null else null
	_expect(shell_cover == null, "shell should rely on the persistent cover instead of owning a disposable copy")
	if shell != null:
		shell.free()

	var menu_scene: PackedScene = load(MAIN_MENU_SCENE_PATH) as PackedScene
	var menu: Control = menu_scene.instantiate() as Control if menu_scene != null else null
	_expect(menu != null, "main menu scene should instantiate")
	var menu_cover: CanvasLayer = menu.get_node_or_null("MainMenuLoadingCover") as CanvasLayer if menu != null else null
	_expect(menu_cover == null, "main menu should not replace the persistent cover during its heavy initialization")
	if menu != null:
		menu.free()

	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	_expect(shell_source.contains("await loading_coordinator.present_for_main_menu()"), "shell should wait until the banner has rendered")
	_expect(shell_source.contains("await _await_preloaded_main_menu_scene()"), "shell should load the menu asynchronously behind the banner")
	var menu_source: String = FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	_expect(menu_source.contains("release_after_main_menu_ready"), "main menu should explicitly release the persistent cover")
	_expect(menu_source.contains("note_main_menu_boot_step"), "main menu should report completed boot milestones")
	_expect(not menu_source.contains("call_deferred(\"_auto_start_home_replay\")"), "replay autoplay should not race Android's staggered history load")
	var noncritical_boot_start: int = menu_source.find("func _finish_noncritical_menu_boot()")
	var noncritical_boot_end: int = menu_source.find("\nfunc ", noncritical_boot_start + 1)
	var noncritical_boot_source: String = menu_source.substr(noncritical_boot_start, noncritical_boot_end - noncritical_boot_start)
	_expect(noncritical_boot_source.find("_load_match_history") < noncritical_boot_source.find("_auto_start_home_replay"), "replay autoplay should run only after match history is loaded")
	var lobby_source: String = FileAccess.get_file_as_string("res://scripts/ui/vs_lobby.gd")
	_expect(lobby_source.contains("present_for_match_loading"), "private PvP launch should present the branded cover before Arena work")
	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	_expect(arena_source.contains("release_for_synchronized_prematch"), "Arena should release the cover from the synchronized clock")
	_expect(arena_source.contains("_begin_synchronized_match_loading_ad"), "Arena should start the ad window only after accepting the shared epoch")
	var relay_source: String = FileAccess.get_file_as_string("res://tools/vs-service/src/server.ts")
	_expect(relay_source.contains("SYNCHRONIZED_MATCH_LOADING_MIN_MS = 7_000"), "relay should reserve the seven-second minimum load window")
	_expect(relay_source.contains("SYNCHRONIZED_START_NETWORK_BUFFER_MS = 1_000"), "relay should preserve a network cushion around the minimum load window")
	var return_menu_start: int = arena_source.find("func _return_to_main_menu()")
	var return_menu_end: int = arena_source.find("\nfunc ", return_menu_start + 1)
	var return_menu_source: String = arena_source.substr(return_menu_start, return_menu_end - return_menu_start)
	_expect(return_menu_source.find("present_for_main_menu") >= 0, "post-match return should cover the outgoing Arena")
	_expect(return_menu_source.find("present_for_main_menu") < return_menu_source.find("outcome_overlay.hide_overlay"), "post-match cover should render before the outcome overlay is removed")

	if not _failed:
		print("MAIN_MENU_LOADING_COVER_SMOKE: PASS")

func _expect(condition: bool, message: String, details: Variant = null) -> void:
	if condition:
		return
	_failed = true
	if details == null:
		push_error("MAIN_MENU_LOADING_COVER_SMOKE: %s" % message)
	else:
		push_error("MAIN_MENU_LOADING_COVER_SMOKE: %s :: %s" % [message, str(details)])
