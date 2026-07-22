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
	_expect(cover.has_method("present_for_match_readiness"), "loading cover should support match readiness presentation")
	_expect(cover.has_method("release_after_match_ready"), "loading cover should wait for explicit match readiness")
	_expect(cover.has_method("set_match_readiness_stage"), "loading cover should expose truthful readiness stages")
	_expect(cover.has_method("hide_immediately"), "loading cover should support failure cleanup")
	_expect(float(cover.get("eye_fade_seconds")) <= 0.75, "logo eyes should reach visible brightness quickly", {
		"eye_fade_seconds": cover.get("eye_fade_seconds")
	})
	var black: ColorRect = cover.get_node_or_null("Black") as ColorRect
	var signage: TextureRect = cover.get_node_or_null("Signage") as TextureRect
	var logo_eyes: TextureRect = cover.get_node_or_null("LogoEyes") as TextureRect
	var preparation_status: Label = cover.get_node_or_null("PreparationStatus") as Label
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
	if logo_eyes != null and logo_eyes.texture != null:
		_expect(logo_eyes.texture.resource_path == LOGO_EYES_PATH, "loading cover should reuse the canonical logo eyes", {
			"actual": logo_eyes.texture.resource_path
		})
		_expect(is_equal_approx(logo_eyes.anchor_left, 0.5) and is_equal_approx(logo_eyes.anchor_right, 0.5), "logo eyes should remain horizontally centered")
		_expect(is_equal_approx(logo_eyes.anchor_top, 0.25) and is_equal_approx(logo_eyes.anchor_bottom, 0.25), "logo eyes should remain proportionally centered above the banner")
	_expect(preparation_status != null, "loading cover should include a preparation status line")
	get_root().add_child(cover)
	await process_frame
	cover.set("minimum_visible_seconds", 0.12)
	cover.set("fade_seconds", 0.01)
	cover.set("eye_fade_delay_seconds", 0.02)
	cover.set("eye_fade_seconds", 0.2)
	cover.set("eye_final_brighten_seconds", 0.01)
	await cover.present_for_main_menu()
	_expect(logo_eyes.modulate.a >= 0.45, "coordinator should draw visibly lit logo eyes before handing off to menu loading", {
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
	await cover.present_for_match_readiness()
	_expect(cover.is_match_transition_active(), "match readiness presentation should identify its transition kind")
	_expect(preparation_status != null and preparation_status.visible, "match readiness should show preparation copy")
	cover.set_match_readiness_stage("render")
	_expect(preparation_status != null and preparation_status.text == "Lighting up the hives...", "render stage should use truthful hive preparation copy")
	await cover.release_after_match_ready()
	_expect(not cover.visible, "match readiness cover should release cleanly")
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
