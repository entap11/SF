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
	var tournament_button: Button = menu.get_node_or_null("BottomBar/MenuButtons/SettingsButton") as Button
	if tournament_button == null or not tournament_button.visible or tournament_button.text != "TOURNAMENTS":
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: bottom tournament button is not visible")
		quit(1)
		return
	var jukebox_button: Button = menu.get_node_or_null("BottomBar/MenuButtons/JukeboxButton") as Button
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
	var entry_scroll: ScrollContainer = panel.get_node_or_null("EntryScroll") as ScrollContainer
	if entry_scroll == null:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: entry scroll missing")
		quit(1)
		return
	for background_name in ["Background_Base", "Background_Noise", "Frame_Inlay", "Midfield_Hex_Dark"]:
		var background_layer: Control = panel.get_node_or_null(background_name) as Control
		if background_layer != null and background_layer.get_index() >= entry_scroll.get_index():
			push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: %s covers authored foreground content" % background_name)
			quit(1)
			return
	if OS.get_environment("SF_FREE_ROLL_LAYER_ORDER_ONLY") == "1":
		print("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: LAYER ORDER PASS")
		quit(0)
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
	_assert_button(panel, "EntryScroll/EntryBody/EntryCanvas/CrucibleButton", 360.0, 150.0, "crucible")
	_assert_button(panel, "EntryScroll/EntryBody/EntryCanvas/WeeklyButton", 360.0, 142.0, "weekly")
	_assert_button(panel, "EntryScroll/EntryBody/EntryCanvas/CancelButton", 320.0, 116.0, "cancel")
	var crucible_button: Button = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/CrucibleButton") as Button
	var one_v_one_button: Button = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/Human1v1Button") as Button
	var four_player_button: Button = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/Human4pFfaButton") as Button
	var time_puzzles_heading: Label = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/TimePuzzlesHeading") as Label
	var weekly_rect: Rect2 = (panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/WeeklyButton") as Button).get_rect()
	if crucible_button == null or crucible_button.icon == null or not crucible_button.text.is_empty() or crucible_button.get_rect().intersects(weekly_rect):
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: Crucible button missing or overlaps weekly row")
		quit(1)
		return
	if one_v_one_button == null or not is_equal_approx(crucible_button.position.y, one_v_one_button.position.y):
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: Crucible is not paired with 1V1")
		quit(1)
		return
	if four_player_button == null or time_puzzles_heading == null or four_player_button.get_rect().end.y > time_puzzles_heading.position.y:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: multiplayer grid overlaps Time Puzzles")
		quit(1)
		return
	var crucible_image: Image = crucible_button.icon.get_image()
	if crucible_image == null or crucible_image.is_empty():
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: Crucible button art did not produce an image")
		quit(1)
		return
	var crucible_aspect: float = float(crucible_image.get_width()) / float(crucible_image.get_height())
	if crucible_aspect < 1.45 or crucible_aspect > 1.55 or crucible_image.get_pixel(0, 0).a > 0.05:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: Crucible art was not normalized to the human-match frame")
		quit(1)
		return
	var capture_path: String = OS.get_environment("SF_CRUCIBLE_CAPTURE_PATH")
	if not capture_path.is_empty():
		var capture_error: Error = crucible_image.save_png(capture_path)
		if capture_error != OK:
			push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: failed to save Crucible art capture")
			quit(1)
			return

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
	var lobby: TimePuzzleLobby = menu.get("_time_puzzle_lobby") as TimePuzzleLobby
	if lobby == null or not lobby.visible:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: weekly free roll did not open tournament lobby")
		quit(1)
		return
	var lobby_title: Label = lobby.get_node_or_null("Panel/VBox/Header/Title") as Label
	if lobby_title == null or lobby_title.text != "STAGE RACE TOURNAMENTS":
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: weekly free roll did not route to tournament lobby")
		quit(1)
		return
	var leaderboard_button: Button = _find_button_with_text(lobby, "LEADERBOARD 5 MAPS")
	if leaderboard_button == null or leaderboard_button.custom_minimum_size.y < 68.0:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: 5-map leaderboard button missing or too small")
		quit(1)
		return
	leaderboard_button.pressed.emit()
	await process_frame
	await process_frame
	var leaderboard: Control = menu.get("_entry_route_modal") as Control
	if leaderboard == null or not leaderboard.visible:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: leaderboard path did not open")
		quit(1)
		return
	var leaderboard_title: Label = leaderboard.get_node_or_null("EntryScroll/EntryBody/EntryTitle") as Label
	if leaderboard_title == null or not leaderboard_title.text.contains("STAGE CONTEST LEADERBOARD"):
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: leaderboard path did not open styled stage contest board")
		quit(1)
		return
	var leaderboard_subtitle: Label = leaderboard.get_node_or_null("EntryScroll/EntryBody/EntrySubtitle") as Label
	if leaderboard_subtitle == null or not leaderboard_subtitle.text.contains("Free Roll") or leaderboard_subtitle.text.contains("$1"):
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: free roll leaderboard routed to paid contest: %s" % (leaderboard_subtitle.text if leaderboard_subtitle != null else "missing"))
		quit(1)
		return
	var leaderboard_play: Button = _find_button_with_text(leaderboard, "PLAY")
	if leaderboard_play == null:
		push_error("MAIN_MENU_FREE_ROLL_LAYOUT_SMOKE: leaderboard play CTA missing")
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

func _find_button_with_text(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text == text:
		return root as Button
	for child in root.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null
