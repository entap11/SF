extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("LOBBY_READABILITY: " + message)

func _run() -> void:
	if not OS.get_user_data_dir().contains("SwarmfrontCampaignChecks-sf-menu-"):
		push_error("Use run_menu_polish_checks.py for isolated player data.")
		quit(2)
		return
	root.size = Vector2i(1080, 1920)
	var profile: Node = root.get_node("ProfileManager")
	profile.call("smoke_force_identity_state", "01900000-0000-7000-8000-000000000002", "ABC 124", "Menu Pilot", true, true)
	profile.call("mark_onboarding_complete")
	await settle()
	for paid in [false, true]:
		var lobby = load("res://scenes/ui/VsLobby.tscn").instantiate()
		lobby.configure("2V2" if paid else "1V1", 1, 5 if paid else 0, not paid)
		root.add_child(lobby)
		await settle()
		check(lobby.summary_label.text.contains("$5 Entry") if paid else lobby.summary_label.text.contains("Free Roll"), "lobby shows the configured entry")
		check(lobby.summary_label.text.contains("4 players" if paid else "2 players"), "lobby shows required player count")
		check_frame(lobby._journey)
		await capture("paid-lobby" if paid else "free-lobby")
		if not paid:
			await stress_size(Vector2i(1080, 1500))
			check_frame(lobby._journey)
			await capture("free-lobby-short-stress")
			await stress_size(Vector2i(1080, 1920))
			# Presentation fixture only; no server queue or opponent is created.
			lobby._quick_ticket_id = "readability-fixture"
			lobby._countdown_mode = "quick_search"
			lobby._countdown_left = 18
			lobby._status("Searching for players")
			lobby._sync_quick_button_text()
			lobby._update_countdown_label()
			check(lobby.quick_button.text == "Cancel Search", "search state offers its existing cancellation action")
			await settle()
			await capture("free-searching-fixture")
			lobby._quick_ticket_id = ""
			lobby._countdown_mode = ""
			lobby._sync_quick_button_text()
			lobby._update_countdown_label()
		lobby.quick_button.pressed.emit()
		await settle()
		check(not lobby.status_label.text.is_empty(), "offline matchmaking leaves visible feedback")
		check(not bool(get_meta("start_game", false)), "offline lobby cannot start a match")
		await capture("paid-offline" if paid else "free-offline")
		var closed := [false]
		lobby.closed.connect(func(): closed[0] = true)
		lobby.back_button.pressed.emit()
		check(closed[0], "Back invokes the existing lobby close path")
		lobby.queue_free()
		await settle()
	var setup = load("res://scenes/ui/VsModeSelect.tscn").instantiate()
	setup.configure_entry(true, 0)
	root.add_child(setup)
	await settle()
	check_frame(setup._journey)
	check_grid(setup._mode_buttons.values())
	await capture("free-setup")
	await stress_size(Vector2i(1080, 1500))
	check_frame(setup._journey)
	await capture("free-setup-short-stress")
	await stress_size(Vector2i(1080, 1920))
	setup._mode_buttons["CAPTURE_FLAG"].pressed.emit()
	await settle()
	check(setup.ctf_settings_row.visible and not setup.map_row.visible, "flag setup preserves mode-specific controls")
	await capture("flag-setup")
	setup.confirm_button.pressed.emit()
	await settle()
	var nested: Control = setup.find_child("VsLobby", true, false)
	check(nested != null and nested.is_visible_in_tree(), "Continue opens a visible child lobby")
	if nested != null:
		check(int(nested.get("_map_count")) == 1 and bool(nested.get("_free_roll")), "setup preserves single-map free entry")
		(nested.get("back_button") as Button).pressed.emit()
	await settle()
	check(setup._journey.is_visible_in_tree(), "lobby Back restores setup")
	setup.configure_entry(false, 5)
	await settle()
	check(setup._free_roll and setup._entry_notice.visible, "disabled paid entry explains its Free Roll fallback")
	await capture("paid-locked-setup")
	var ops: Node = root.get_node("OpsConfig")
	var original_config: Dictionary = ops.call("get_config_snapshot")
	var fixture_config := original_config.duplicate(true)
	fixture_config["feature_flags"]["enable_paid_entries"] = true
	ops.call("force_config_for_smoke", fixture_config, "remote_fresh")
	setup.configure_entry(false, 5)
	await settle()
	check(setup._selected_price == 5, "paid setup keeps selected entry")
	check_grid(setup._price_buttons.values())
	await capture("paid-setup")
	ops.call("force_config_for_smoke", original_config, "bundled_default")
	setup.queue_free()
	await settle()
	var contests = load("res://scenes/ui/PublicContestDashPanel.tscn").instantiate()
	root.add_child(contests)
	contests.configure("WEEKLY", "GAUNTLET", 18)
	await settle()
	check_frame(contests._journey)
	check(contests._play.disabled, "offline public contest cannot issue an attempt")
	check(contests._mode_buttons["GAUNTLET:18"].button_pressed, "Gauntlet selection is visible")
	await capture("public-contests-offline")
	contests._scope_buttons["MONTHLY"].pressed.emit()
	check(contests._family == "TIME_PUZZLE", "monthly selection retains existing contest family behavior")
	contests.queue_free()
	await settle()
	var races = load("res://scenes/ui/TimePuzzleLobby.tscn").instantiate()
	root.add_child(races)
	races.configure_entry(false, 5)
	races.configure_direct_stage_race_play(true)
	await settle()
	check_frame(races._journey)
	await capture("paid-stage-race")
	var route := []
	races.stage_race_play_requested.connect(func(scope, paid, entry, count): route.assign([scope, paid, entry, count]))
	var play := find_button(races, "PLAY 3 MAPS")
	check(play != null, "paid stage-race entry is reachable")
	if play != null:
		play.pressed.emit()
		check(route == ["WEEKLY", true, 5, 3], "stage-race Play preserves scope, fee and maps")
	find_button(races, "DETAILS").pressed.emit()
	await settle()
	var details: Control = races.find_child("ContestHub", true, false)
	check(details != null and details.is_visible_in_tree(), "Details opens visibly above its parent lobby")
	if details != null:
		check_frame(details.get("_journey"))
		await capture("paid-contest-details")
		details.get("back_button").pressed.emit()
	await settle()
	check(races._journey.is_visible_in_tree(), "Details Back returns to the stage-race list")
	races.queue_free()
	await settle()
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await settle()
	menu.call("_open_vs_mode_select_panel", true)
	await settle()
	check(not menu.get("_home_menu").is_visible_in_tree(), "home is hidden behind setup")
	menu.get("_vs_mode_select").get("back_button").pressed.emit()
	await settle()
	check(menu.get("_home_menu").is_visible_in_tree(), "setup Back restores home")
	menu.set("_dev_bypass_cash_balance", false)
	menu.set("_wallet_profile", {"balance_usd": 2})
	menu.call("_open_add_funds_for_money_entry", 5)
	await settle()
	var modal: Control = menu.get("_entry_route_modal")
	check_frame(modal.get_node("JourneyFrame"))
	check(int(menu.call("_wallet_balance_usd")) == 2, "showing insufficient funds does not debit the wallet")
	check(find_button(modal, "ADD FUNDS · UNAVAILABLE").disabled, "placeholder funding action is clearly unavailable")
	await capture("insufficient-funds")
	find_button(modal, "PLAY A FREE ROLL").pressed.emit()
	await settle()
	check(is_instance_valid(menu.get("_entry_route_modal")) and menu.get("_entry_route_modal").has_node("ReadableHub"), "insufficient funds retains a working Free Roll exit")
	menu.queue_free()
	await settle()
	print("LOBBY_READABILITY_SMOKE: " + ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)

func check_frame(frame: Control) -> void:
	var back: Button = frame.get("back")
	var scroll: ScrollContainer = frame.get("scroll")
	check(root.get_visible_rect().encloses(back.get_global_rect()), "Back fits inside the viewport")
	check(scroll.get_global_rect().end.y <= back.get_global_rect().position.y, "Back stays outside scrolling content")
	check(back.size.y >= 132, "Back has a large touch target")
	for child in frame.get("footer").get_children():
		if child is Button:
			check(root.get_visible_rect().encloses(child.get_global_rect()), "footer actions remain reachable")

func check_grid(buttons: Array) -> void:
	for button: Button in buttons:
		check(button.size.y >= 132, "setup options have large targets")
		check(button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= root.get_visible_rect().size.x + 1, "setup options fit screen width")

func find_button(node: Node, value: String) -> Button:
	if node is Button and node.text == value:
		return node
	for child in node.get_children():
		var result := find_button(child, value)
		if result != null:
			return result
	return null

func settle() -> void:
	for _frame in range(6):
		await process_frame

func stress_size(dimensions: Vector2i) -> void:
	# Explicit logical-size stress case; production keeps its existing viewport scaling.
	root.content_scale_size = dimensions
	root.size = dimensions
	await settle()

func capture(filename: String) -> void:
	var directory := OS.get_environment("SF_MENU_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(directory.path_join(filename + ".png")) == OK, "native capture saved")
