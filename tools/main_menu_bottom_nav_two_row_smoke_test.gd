extends SceneTree
# Historical test entry point retained for release scripts; home now uses a primary
# Campaign choice, mode list, and a persistent two-row utility footer.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(944, 2048)
	var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	for _frame in range(6):
		await process_frame
	var home: Control = menu.get("_home_menu")
	if home == null:
		push_error("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: home shell missing")
		quit(1)
		return
	for property in ["menu_store_button", "menu_buffs_button", "menu_battle_pass_button", "menu_free_roll_button", "menu_cash_button", "menu_jukebox_button", "menu_unused_button"]:
		var button: Button = menu.get(property)
		var rect := button.get_global_rect()
		if button.size.y < 96 or rect.position.x < 0 or rect.end.x > root.get_visible_rect().size.x + 1:
			push_error("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: button is too small or offscreen: " + property)
			quit(1)
			return
		if button.get_signal_connection_list("pressed").size() != 1:
			push_error("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: missing or duplicated route: " + property)
			quit(1)
			return
	for property in ["menu_store_button", "menu_buffs_button", "menu_battle_pass_button"]:
		var button: Button = menu.get(property)
		if not root.get_visible_rect().encloses(button.get_global_rect()):
			push_error("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: utility footer is offscreen")
			quit(1)
			return
	menu.queue_free()
	await process_frame
	print("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: PASS")
	quit(0)
