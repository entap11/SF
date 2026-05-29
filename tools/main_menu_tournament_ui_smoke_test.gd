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

	var tournaments_button: Button = menu.get_node_or_null("BottomBar/MenuButtons/RightButtons/SettingsButton") as Button
	if tournaments_button == null or not tournaments_button.visible or tournaments_button.text != "TOURNAMENTS":
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: tournament nav button missing")
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

	var money_tab: Button = menu.get_node_or_null("AsyncPanel/AsyncVBox/AsyncBody/AsyncBodyVBox/TournamentBrowser/TournamentTabs/TournamentMoneyTab") as Button
	if money_tab == null:
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: money tab missing")
		quit(1)
		return
	money_tab.pressed.emit()
	await process_frame
	if list.get_child_count() < 3:
		push_error("MAIN_MENU_TOURNAMENT_UI_SMOKE: money tournament rows missing")
		quit(1)
		return

	print("MAIN_MENU_TOURNAMENT_UI_SMOKE: PASS")
	quit(0)
