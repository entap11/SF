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
	var tournament_button: Button = menu.get_node_or_null("BottomBar/MenuButtons/RightButtons/SettingsButton") as Button
	if tournament_button == null or not tournament_button.visible or tournament_button.text != "TOURNAMENTS":
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: bottom tournament button is not visible")
		quit(1)
		return
	var jukebox_button: Button = menu.get_node_or_null("BottomBar/MenuButtons/RightButtons/JukeboxButton") as Button
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

	var canvas: Control = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas") as Control
	if canvas == null:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: entry canvas missing")
		quit(1)
		return
	if canvas.custom_minimum_size.x > panel_rect.size.x:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: canvas wider than centered panel")
		quit(1)
		return

	_assert_button(panel, "EntryScroll/EntryBody/EntryCanvas/Human1v1Button", 360.0, 150.0, "1v1")
	_assert_button(panel, "EntryScroll/EntryBody/EntryCanvas/HumanCtfButton", 360.0, 150.0, "ctf")
	_assert_button(panel, "EntryScroll/EntryBody/EntryCanvas/WeeklyButton", 360.0, 142.0, "weekly")
	_assert_button(panel, "EntryScroll/EntryBody/EntryCanvas/CancelButton", 320.0, 116.0, "cancel")

	var button: Button = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/Human1v1Button") as Button
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

	var weekly_button: Button = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/WeeklyButton") as Button
	if weekly_button == null:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: weekly button missing")
		quit(1)
		return
	menu.call("_on_free_roll_button_down", weekly_button)
	weekly_button.pressed.emit()
	await process_frame
	await process_frame
	var vs_lobby: Control = menu.get("_vs_lobby") as Control
	if vs_lobby == null or not vs_lobby.visible:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: weekly free roll did not open VS lobby")
		quit(1)
		return
	var summary: Label = vs_lobby.get_node_or_null("Panel/VBox/Summary") as Label
	if summary == null or not summary.text.contains("Stage Race"):
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: weekly free roll did not route to Stage Race")
		quit(1)
		return
	var async_panel: Control = menu.get_node_or_null("AsyncPanel") as Control
	if async_panel != null and async_panel.visible:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: weekly free roll incorrectly opened async panel")
		quit(1)
		return

	print("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: PASS")
	quit(0)

func _assert_button(panel: Control, path: String, min_width: float, min_height: float, label: String) -> void:
	var button: Button = panel.get_node_or_null(path) as Button
	if button == null:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: missing %s button" % label)
		quit(1)
		return
	if button.custom_minimum_size.x < min_width or button.custom_minimum_size.y < min_height:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: %s button too small: %s" % [label, str(button.custom_minimum_size)])
		quit(1)
		return
	var rect: Rect2 = button.get_global_rect()
	var viewport_size: Vector2 = get_root().get_visible_rect().size
	if rect.position.x < -0.5 or rect.end.x > viewport_size.x + 0.5:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: %s button is horizontally offscreen: %s" % [label, str(rect)])
		quit(1)
		return
