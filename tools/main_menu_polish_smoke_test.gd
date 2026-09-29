extends SceneTree

var failures: Array[String] = []
var menu: Control

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("MENU_POLISH: " + message)

func _run() -> void:
	if not OS.get_user_data_dir().contains("SwarmfrontCampaignChecks-sf-menu-"):
		push_error("Use tools/run_menu_polish_checks.py to isolate player data.")
		quit(2)
		return
	root.size = Vector2i(1080, 1920)
	var profile := root.get_node("ProfileManager")
	profile.call("smoke_force_identity_state", "01900000-0000-7000-8000-000000000002", "ABC 124", "Menu Pilot", true, true)
	profile.call("mark_onboarding_complete")
	menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	menu.set("_dev_bypass_cash_balance", false)
	menu.set("_wallet_profile", {"balance_usd": 10})
	for dimensions in [Vector2i(1080, 1920), Vector2i(944, 2048), Vector2i(720, 1280), Vector2i(1080, 1500)]:
		root.size = dimensions
		await settle()
		var home: Control = menu.get("_home_menu")
		check(home.is_visible_in_tree(), "home is visible")
		var campaign: Button = menu.get("menu_jukebox_button")
		check(campaign.size.y >= 200 and campaign.size.x >= home.size.x * 0.8, "Campaign receives a full-width primary choice")
		for property in ["menu_jukebox_button", "menu_free_roll_button", "menu_cash_button", "menu_unused_button", "menu_store_button", "menu_buffs_button", "menu_battle_pass_button"]:
			var button: Button = menu.get(property)
			check(button.size.y >= 96, "home touch target: " + property)
			check(button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= root.get_visible_rect().size.x + 1, "home width: " + property)
		await capture("home-%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1080, 1920)
	await settle()
	var home_mode: Button = menu.get("menu_free_roll_button")
	menu.call("_on_free_roll_button_down", home_mode)
	menu.call("_update_free_roll_button_drag_guard", home_mode, home_mode.get_local_mouse_position() + Vector2(0, 160))
	home_mode.pressed.emit()
	check(menu.get("_entry_route_modal") == null, "scrolling home cannot open a mode")
	menu.set("_free_roll_press_block_until_msec", 0)
	(menu.get("menu_jukebox_button") as Button).pressed.emit()
	await settle()
	check(is_instance_valid(menu.get("_challenge_hub")), "Campaign button still opens the campaign hub")
	check(not (menu.get("_home_menu") as Control).is_visible_in_tree(), "home controls are hidden while a destination is open")
	menu.call("_close_challenge_hub")
	await settle()
	menu.call("_toggle_dash")
	await create_timer(0.3).timeout
	check((menu.get("dash_tab") as Control).is_visible_in_tree(), "Dashboard retains its escape control")
	menu.call("_toggle_dash")
	await create_timer(0.3).timeout
	await settle()
	check((menu.get("_home_menu") as Control).is_visible_in_tree(), "Dashboard closes back to home")
	menu.call("_on_free_roll_button_down", home_mode)
	home_mode.pressed.emit()
	await settle()
	var panel: Control = menu.get("_entry_route_modal")
	var hub: Control = panel.get_node("ReadableHub")
	check((hub.get("_routes") as Array).size() == 19, "every existing Free Roll mode remains reachable")
	for index in range(3):
		hub.call("_select_category", index)
		await settle()
		_check_hub(hub)
		await capture("free-roll-%d" % index)
	hub.call("_select_category", 0)
	hub.call("set_cluster_arrangement", "3-2")
	await settle()
	_check_hub(hub)
	await capture("free-roll-cluster-3-2")
	hub.call("set_cluster_arrangement", "2-1-2")
	await settle()
	var route: Button = (hub.get("_routes") as Array)[0]
	menu.call("_on_free_roll_button_down", route)
	menu.call("_update_free_roll_button_drag_guard", route, route.get_local_mouse_position() + Vector2(0, 160))
	check(not bool(menu.call("_consume_free_roll_button_press", route)), "scroll drag cannot launch a mode")
	(hub.get("_back") as Button).pressed.emit()
	await settle()
	check((menu.get("_home_menu") as Control).is_visible_in_tree(), "Free Roll Back returns home")
	(menu.get("menu_cash_button") as Button).pressed.emit()
	await settle()
	panel = menu.get("_entry_route_modal")
	hub = panel.get_node("ReadableHub")
	_check_hub(hub)
	await capture("money-games-live")
	hub.call("_select_category", 1)
	await settle()
	await capture("money-games-contests")
	var division_buttons: Array[Node] = (hub.get("_money_tabs") as Control).get_children()
	(division_buttons[1] as Button).pressed.emit()
	await create_timer(0.35).timeout
	await settle()
	check(int(menu.get("_money_games_selected_tier")) == 5, "division selection retains its existing tier behavior")
	for button: Button in hub.get("_routes"):
		check(button.text.contains("$5"), "all paid choices show the selected entry")
	(division_buttons[2] as Button).pressed.emit()
	await create_timer(0.35).timeout
	await settle()
	check((division_buttons[3] as Button).disabled, "Classified remains locked")
	var tiers: Array[Node] = (hub.get("_tier_row") as Control).get_children()
	var fifty: Button = tiers[1]
	check(fifty.text.contains("Add funds") and not fifty.disabled, "unaffordable entry retains readable add-funds route")
	await capture("money-games-add-funds")
	for dimensions in [Vector2i(944, 2048), Vector2i(720, 1280), Vector2i(1080, 1500)]:
		root.size = dimensions
		await settle()
		_check_hub(hub)
		await capture("money-games-%dx%d" % [dimensions.x, dimensions.y])
	fifty.pressed.emit()
	await settle()
	check(bool(get_meta("money_payment_window_requested", false)), "unaffordable selection follows existing add-funds intent")
	check(menu.get("_entry_route_modal") != panel, "add-funds state replaces the selector")
	menu.queue_free()
	await process_frame
	await process_frame
	print("MAIN_MENU_POLISH_SMOKE: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)

func _check_hub(hub: Control) -> void:
	var back: Button = hub.get("_back")
	var scroll: ScrollContainer = hub.get("_scroll")
	check(root.get_visible_rect().encloses(back.get_global_rect()), "Back is inside the viewport")
	check(scroll.get_global_rect().end.y <= back.get_global_rect().position.y, "Back stays outside scrolling content")
	for button: Button in hub.get("_routes"):
		check(button.custom_minimum_size.y >= 140 and button.get_theme_font_size("font_size") >= 44, "mode has readable text and a large target")
		if button.is_visible_in_tree():
			check(button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= root.get_visible_rect().size.x + 1, "mode fits viewport width")
			var copy: Control = button.get_node("ReadableCopy/Copy")
			check(copy.size.y <= button.size.y - 20, "wrapped mode text fits its hex button")
	var routes: Array = hub.get("_routes")
	for i in range(routes.size()):
		for j in range(i + 1, routes.size()):
			if routes[i].is_visible_in_tree() and routes[j].is_visible_in_tree():
				check(not routes[i].get_global_rect().intersects(routes[j].get_global_rect()), "hex touch targets never overlap")

func settle() -> void:
	for _frame in range(6):
		await process_frame

func capture(filename: String) -> void:
	var directory := OS.get_environment("SF_MENU_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw(false)
	var screenshot := root.get_texture().get_image()
	check(screenshot.save_png(directory.path_join(filename + ".png")) == OK, "native screenshot saved")
