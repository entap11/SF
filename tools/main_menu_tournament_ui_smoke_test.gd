extends SceneTree

func _init() -> void:
	await process_frame
	var scene := load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame

	var tournaments_button: Button = menu.get_node_or_null("BottomBar/MenuButtons/SettingsButton") as Button
	if tournaments_button == null or not tournaments_button.visible or tournaments_button.text != "TOURNAMENTS":
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: tournament nav button missing")
		quit(1)
		return
	var tournaments_skin: TextureRect = tournaments_button.get_node_or_null("SkinTex") as TextureRect
	var registry := SpriteRegistry.get_instance()
	var expected_skin_path := "res://assets/sprites/sf_skin_v1/tournaments.png"
	if (
		tournaments_skin == null
		or not tournaments_skin.visible
		or tournaments_skin.texture == null
		or registry == null
		or registry.get_tex_path("ui.mm.tournaments.normal") != expected_skin_path
		or tournaments_skin.texture != registry.get_tex("ui.mm.tournaments.normal")
	):
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: tournament nav sprite missing")
		quit(1)
		return
	tournaments_button.pressed.emit()
	await process_frame

	var async_panel: Control = menu.get_node_or_null("AsyncPanel") as Control
	var browser: VBoxContainer = menu.get_node_or_null("AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/TournamentBrowser") as VBoxContainer
	var list: VBoxContainer = menu.get_node_or_null("AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/TournamentBrowser/TournamentScroll/TournamentList") as VBoxContainer
	if async_panel == null or not async_panel.visible or browser == null or not browser.visible or list == null:
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: tournament browser did not open")
		quit(1)
		return
	if list.get_child_count() < 3:
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: free tournament rows missing")
		quit(1)
		return
	var free_row_count: int = list.get_child_count()
	var free_tab: Button = menu.get_node_or_null("AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/TournamentBrowser/TournamentTabs/TournamentFreeTab") as Button
	if free_tab == null or free_tab.text != "FREE ROLL":
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: free roll tab missing or mislabeled")
		quit(1)
		return

	var money_tab: Button = menu.get_node_or_null("AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/TournamentBrowser/TournamentTabs/TournamentMoneyTab") as Button
	if money_tab == null or money_tab.text != "MONEY GAME":
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: money game tab missing or mislabeled")
		quit(1)
		return
	money_tab.pressed.emit()
	await process_frame
	if list.get_child_count() < 3:
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: money tournament rows missing")
		quit(1)
		return
	if list.get_child_count() != free_row_count:
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: free and money tabs should expose matching menu row counts")
		quit(1)
		return

	print("MAIN_MENU_TOURNAMENT_UI_SMOKE: PASS")
	quit(0)
