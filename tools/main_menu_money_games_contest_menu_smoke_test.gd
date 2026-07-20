extends SceneTree

const EXPECTED_VISIBLE_CONTEST_BUTTONS: int = 11

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

	menu.call("_open_game_hub", true, 1)
	await process_frame
	await process_frame
	if not _assert_selected_denomination_menu(menu, 1):
		return
	var two_dollar_tier: Button = _find_tier_button(menu, 2)
	if two_dollar_tier == null:
		_fail("$1 menu missing $2 tier selector")
		return
	two_dollar_tier.emit_signal("pressed")
	await process_frame
	if not _assert_selected_denomination_menu(menu, 2):
		return

	menu.call("_open_game_hub", true, 50)
	await process_frame
	await process_frame
	if not _assert_selected_denomination_menu(menu, 50):
		return

	menu.queue_free()
	await process_frame
	print("MAIN_MENU_MONEY_GAMES_CONTEST_MENU_SMOKE: PASS")
	quit(0)

func _assert_selected_denomination_menu(menu: Node, selected_denomination: int) -> bool:
	var contest_buttons: Array[Button] = []
	_collect_contest_buttons(menu, contest_buttons)
	var visible_count: int = 0
	var visible_labels: Dictionary = {}
	for button in contest_buttons:
		if not button.visible:
			continue
		visible_count += 1
		var button_denomination: int = int(button.get_meta("sf_paid_contest_denomination", 0))
		if button_denomination != selected_denomination:
			_fail("$%d menu exposed $%d contest %s" % [selected_denomination, button_denomination, button.text])
			return false
		var family_label: String = str(button.get_meta("sf_paid_contest_family_label", "")).strip_edges().to_upper()
		if button.icon == null or not button.text.strip_edges().is_empty():
			_fail("$%d menu still uses a placeholder for %s" % [selected_denomination, family_label])
			return false
		if button.tooltip_text.contains("$"):
			_fail("$%d menu repeats denomination on contest %s" % [selected_denomination, family_label])
			return false
		visible_labels[family_label] = true
	if visible_count != EXPECTED_VISIBLE_CONTEST_BUTTONS:
		_fail("$%d menu exposed %d contest buttons; expected %d" % [selected_denomination, visible_count, EXPECTED_VISIBLE_CONTEST_BUTTONS])
		return false
	for expected_label in ["STAGE RACE", "RACE", "GAUNTLET", "MISS N OUT"]:
		if not visible_labels.has(expected_label):
			_fail("$%d menu missing %s" % [selected_denomination, expected_label])
			return false
	var route_buttons: Array[Button] = []
	_collect_paid_route_buttons(menu, route_buttons)
	for button in route_buttons:
		if button.visible and (button.text.contains("$") or button.tooltip_text.contains("$")):
			_fail("$%d menu repeats denomination on route %s" % [selected_denomination, button.tooltip_text])
			return false
	return true

func _collect_contest_buttons(root: Node, out: Array[Button]) -> void:
	if root is Button and root.has_meta("sf_paid_contest_denomination"):
		out.append(root as Button)
	for child in root.get_children():
		_collect_contest_buttons(child, out)

func _collect_paid_route_buttons(root: Node, out: Array[Button]) -> void:
	if root is Button and bool(root.get_meta("sf_money_paid_route", false)):
		out.append(root as Button)
	for child in root.get_children():
		_collect_paid_route_buttons(child, out)

func _find_tier_button(root: Node, amount: int) -> Button:
	if root is Button and int((root as Button).get_meta("sf_money_entry_tier_usd", 0)) == amount:
		return root as Button
	for child in root.get_children():
		var found: Button = _find_tier_button(child, amount)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	push_error("MAIN_MENU_MONEY_GAMES_CONTEST_MENU_SMOKE: %s" % message)
	quit(1)
