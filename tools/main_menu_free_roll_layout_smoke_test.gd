extends SceneTree

const TEST_VIEWPORT_SIZE := Vector2i(944, 2048)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = TEST_VIEWPORT_SIZE
	await process_frame
	var scene := load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame
	var tournament_button: Button = menu.get("menu_unused_button") as Button
	if tournament_button == null or not tournament_button.visible or tournament_button.text != "TOURNAMENTS":
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: bottom tournament button is not visible")
		quit(1)
		return
	var jukebox_button: Button = menu.get("menu_jukebox_button") as Button
	if jukebox_button == null or not jukebox_button.visible:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: bottom jukebox button is not visible")
		quit(1)
		return
	if not menu.has_method("_open_free_roll_split"):
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: free roll open method missing")
		quit(1)
		return
	menu.call("_open_free_roll_split")
	await process_frame
	await process_frame

	var panel: Control = menu.get("_entry_route_modal") as Control
	if panel == null or not panel.visible:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: free roll panel did not open")
		quit(1)
		return
	var viewport_size: Vector2 = get_root().get_visible_rect().size
	var panel_rect: Rect2 = panel.get_global_rect()
	var center_delta: float = absf(panel_rect.get_center().x - (viewport_size.x * 0.5))
	if center_delta > 1.0:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: panel is not centered: %.1f" % center_delta)
		quit(1)
		return
	if panel_rect.position.x < -0.5 or panel_rect.end.x > viewport_size.x + 0.5:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: panel extends past viewport: %s" % str(panel_rect))
		quit(1)
		return

	var hub: Control = panel.get_node_or_null("ReadableHub")
	if hub == null:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: readable mode selector missing")
		quit(1)
		return
	var back: Button = hub.get("_back")
	if not get_root().get_visible_rect().encloses(back.get_global_rect()):
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: persistent Back is offscreen")
		quit(1)
		return
	for control: Button in hub.get("_routes"):
		if control.custom_minimum_size.y < 140 or control.get_theme_font_size("font_size") < 44:
			push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: mode text or target is too small")
			quit(1)
			return
	var button: Button = panel.find_child("Human1v1Button", true, false) as Button
	if button == null or not button.has_meta("sf_free_roll_press_guard"):
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: free roll press guard missing")
		quit(1)
		return
	menu.call("_on_free_roll_button_down", button)
	button.set_meta("sf_free_roll_press_started_msec", Time.get_ticks_msec() - 500)
	menu.call("_finalize_free_roll_button_press", button)
	var accepted_after_hold: bool = bool(menu.call("_consume_free_roll_button_press", button))
	if accepted_after_hold:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: long hold release was accepted")
		quit(1)
		return
	menu.set("_free_roll_press_block_until_msec", 0)

	var weekly_button: Button = panel.find_child("WeeklyButton", true, false) as Button
	if weekly_button == null:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: weekly button missing")
		quit(1)
		return
	menu.call("_on_free_roll_button_down", weekly_button)
	weekly_button.pressed.emit()
	await process_frame
	await process_frame
	var contest: Control = menu.get("_public_contest_dash") as Control
	if contest == null or not contest.visible:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: weekly free roll did not open public contests")
		quit(1)
		return
	if str(contest.get("_scope")) != "WEEKLY" or str(contest.get("_family")) != "TIME_PUZZLE":
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: weekly route changed scope or family")
		quit(1)
		return
	if bool(get_meta("start_game", false)):
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: browsing a contest must not bypass entry")
		quit(1)
		return
	var async_panel: Control = menu.get_node_or_null("AsyncPanel") as Control
	if async_panel != null and async_panel.visible:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: weekly free roll incorrectly opened async panel")
		quit(1)
		return

	print("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: PASS")
	quit(0)
