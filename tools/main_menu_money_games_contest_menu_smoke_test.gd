extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		_fail("failed to load MainMenu.tscn")
		return
	var menu: Node = scene.instantiate()
	menu.set("_dev_bypass_cash_balance", false)
	menu.set("_wallet_profile", {"balance_usd": 500})
	get_root().add_child(menu)
	await process_frame
	await process_frame
	menu.call("_open_game_hub", true, 15)
	await process_frame
	await process_frame
	if _find_button_containing_text(menu, "STAGE RACE", "$15") == null:
		_fail("missing scheduled Stage Race $15")
		return
	if _find_button_containing_text(menu, "RACE", "$100") == null:
		_fail("missing scheduled Race $100")
		return
	if _find_button_containing_text(menu, "GAUNTLET", "$100") == null:
		_fail("missing scheduled Gauntlet $100")
		return
	if _find_button_containing_text(menu, "MISS N OUT", "$15") == null:
		_fail("missing Miss N Out $15 sit-and-go")
		return
	if _find_button_containing_text(menu, "STAGE RACE", "$100") != null:
		_fail("Stage Race should not expose $100")
		return
	menu.queue_free()
	await process_frame
	print("MAIN_MENU_MONEY_GAMES_CONTEST_MENU_SMOKE: PASS")
	quit(0)

func _find_button_containing_text(root: Node, required_a: String, required_b: String) -> Button:
	if root is Button:
		var button: Button = root as Button
		var text: String = button.text.strip_edges().to_upper()
		if text.contains(required_a.strip_edges().to_upper()) and text.contains(required_b.strip_edges().to_upper()):
			return button
	for child in root.get_children():
		var found: Button = _find_button_containing_text(child, required_a, required_b)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	push_error("MAIN_MENU_MONEY_GAMES_CONTEST_MENU_SMOKE: %s" % message)
	quit(1)
