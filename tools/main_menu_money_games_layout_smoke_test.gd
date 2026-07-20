extends SceneTree

const TEST_VIEWPORT_SIZE: Vector2i = Vector2i(944, 2048)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = TEST_VIEWPORT_SIZE
	await process_frame
	var scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	menu.set("_dev_bypass_cash_balance", false)
	menu.set("_wallet_profile", {"balance_usd": 10})
	get_root().add_child(menu)
	await process_frame
	await process_frame
	if not menu.has_method("_open_game_hub"):
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: money games open method missing")
		quit(1)
		return
	menu.call("_open_game_hub", true, 1)
	await process_frame
	await process_frame

	var panel: Control = menu.get("_entry_route_modal") as Control
	if panel == null or not panel.visible:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: money games panel did not open")
		quit(1)
		return
	var viewport_size: Vector2 = get_root().get_visible_rect().size
	var panel_rect: Rect2 = panel.get_global_rect()
	if panel_rect.position.x < -0.5 or panel_rect.end.x > viewport_size.x + 0.5:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: panel extends past viewport: %s" % str(panel_rect))
		quit(1)
		return

	var buttons: Array[Button] = _collect_buttons(panel)
	_assert_tooltip_button(buttons, "1V1", 330.0, 145.0)
	_assert_tooltip_button(buttons, "4P FFA", 330.0, 145.0)
	_assert_tooltip_button(buttons, "Weekly", 400.0, 110.0)
	_assert_tooltip_button(buttons, "Monthly", 400.0, 110.0)
	_assert_text_button(buttons, "DIVISION I", 208.0, 112.0)
	_assert_tier_sprite(buttons, 1, 168.0, 78.0)
	_assert_tier_sprite(buttons, 2, 168.0, 78.0)
	_assert_tier_sprite(buttons, 3, 168.0, 78.0)
	var crucible_money_button: Button = _find_tooltip_button(buttons, "1V1")
	if crucible_money_button == null or crucible_money_button.icon == null:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: paid 1V1 Crucible art missing")
		quit(1)
		return
	var crucible_money_image: Image = crucible_money_button.icon.get_image()
	if crucible_money_image == null or crucible_money_image.is_empty():
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: paid 1V1 Crucible art did not produce an image")
		quit(1)
		return
	var crucible_money_aspect: float = float(crucible_money_image.get_width()) / float(crucible_money_image.get_height())
	if crucible_money_aspect < 1.62 or crucible_money_aspect > 1.72 or crucible_money_image.get_pixel(0, 0).a > 0.05:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: paid 1V1 is not using normalized Money Games Crucible art")
		quit(1)
		return
	_press_text_button(buttons, "DIVISION II")
	await create_timer(0.35).timeout
	buttons = _collect_buttons(panel)
	_assert_tier_sprite(buttons, 5, 168.0, 78.0)
	_assert_tier_sprite(buttons, 10, 168.0, 78.0)
	_assert_tier_text_fallback(buttons, 15, 168.0, 78.0)
	_press_text_button(buttons, "DIVISION III")
	await create_timer(0.35).timeout
	buttons = _collect_buttons(panel)
	_assert_tier_sprite(buttons, 20, 168.0, 78.0)
	_assert_tier_sprite(buttons, 50, 168.0, 78.0)
	_assert_tier_unaffordable_clickable(buttons, 50)
	_assert_tooltip_button_unaffordable_clickable(buttons, "1V1")
	_press_tier_button(buttons, 50)
	await process_frame
	await process_frame
	var funds_panel: Control = menu.get("_entry_route_modal") as Control
	if funds_panel == null or not funds_panel.visible:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: add-funds panel did not open")
		quit(1)
		return
	var funds_buttons: Array[Button] = _collect_buttons(funds_panel)
	_assert_text_button(funds_buttons, "ADD FUNDS", 0.0, 0.0)
	if not bool(get_meta("money_payment_window_requested", false)):
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: add-funds click should mark payment window requested")
		quit(1)
		return

	print("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: PASS")
	quit(0)

func _collect_buttons(root_node: Node) -> Array[Button]:
	var out: Array[Button] = []
	if root_node is Button:
		out.append(root_node as Button)
	for child in root_node.get_children():
		out.append_array(_collect_buttons(child))
	return out

func _assert_tooltip_button(buttons: Array[Button], token: String, min_width: float, min_height: float) -> void:
	var button: Button = _find_tooltip_button(buttons, token)
	if button != null:
		_assert_button_size(button, min_width, min_height, token)
		return
	push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: missing tooltip button %s" % token)
	quit(1)

func _find_tooltip_button(buttons: Array[Button], token: String) -> Button:
	for button in buttons:
		if button.tooltip_text.contains(token):
			return button
	return null

func _assert_text_button(buttons: Array[Button], text_value: String, min_width: float, min_height: float) -> void:
	for button in buttons:
		if button.text.strip_edges() != text_value:
			continue
		_assert_button_size(button, min_width, min_height, text_value)
		return
	push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: missing text button %s" % text_value)
	quit(1)

func _find_tier_button(buttons: Array[Button], amount: int) -> Button:
	for button in buttons:
		if int(button.get_meta("sf_money_entry_tier_usd", 0)) == amount:
			return button
	return null

func _assert_tier_sprite(buttons: Array[Button], amount: int, min_width: float, min_height: float) -> void:
	var button: Button = _find_tier_button(buttons, amount)
	if button == null:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: missing $%d tier button" % amount)
		quit(1)
		return
	_assert_button_size(button, min_width, min_height, "$%d" % amount)
	var expected_path: String = "res://assets/sprites/sf_skin_v1/$%d.png" % amount
	if button.icon == null or not button.text.strip_edges().is_empty():
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: $%d tier is not using sprite art" % amount)
		quit(1)
		return
	if str(button.get_meta("sf_money_entry_tier_asset_path", "")) != expected_path:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: $%d tier uses the wrong sprite asset" % amount)
		quit(1)
		return
	var image: Image = button.icon.get_image()
	if image == null or image.is_empty():
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: $%d tier sprite did not produce an image" % amount)
		quit(1)

func _assert_tier_text_fallback(buttons: Array[Button], amount: int, min_width: float, min_height: float) -> void:
	var button: Button = _find_tier_button(buttons, amount)
	if button == null or button.text.strip_edges() != "$%d" % amount or button.icon != null:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: $%d tier should retain its text fallback" % amount)
		quit(1)
		return
	_assert_button_size(button, min_width, min_height, "$%d" % amount)

func _assert_tier_unaffordable_clickable(buttons: Array[Button], amount: int) -> void:
	var button: Button = _find_tier_button(buttons, amount)
	if button == null:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: missing unaffordable $%d tier button" % amount)
		quit(1)
		return
	if button.disabled:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: $%d button should stay clickable" % amount)
		quit(1)
		return
	if not bool(button.get_meta("sf_money_unaffordable", false)):
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: $%d button should be marked unaffordable" % amount)
		quit(1)

func _assert_tooltip_button_unaffordable_clickable(buttons: Array[Button], token: String) -> void:
	for button in buttons:
		if not button.tooltip_text.contains(token):
			continue
		if button.disabled:
			push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: %s route should stay clickable" % token)
			quit(1)
			return
		if not bool(button.get_meta("sf_money_unaffordable", false)):
			push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: %s route should be marked unaffordable" % token)
			quit(1)
			return
		if not button.tooltip_text.contains("Insufficient balance"):
			push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: %s route missing insufficient balance tooltip" % token)
			quit(1)
			return
		return
	push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: missing unaffordable tooltip button %s" % token)
	quit(1)

func _press_text_button(buttons: Array[Button], text_value: String) -> void:
	for button in buttons:
		if button.text.strip_edges() != text_value:
			continue
		button.emit_signal("pressed")
		return
	push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: missing press target %s" % text_value)
	quit(1)

func _press_tier_button(buttons: Array[Button], amount: int) -> void:
	var button: Button = _find_tier_button(buttons, amount)
	if button != null:
		button.emit_signal("pressed")
		return
	push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: missing tier press target $%d" % amount)
	quit(1)

func _assert_button_size(button: Button, min_width: float, min_height: float, label: String) -> void:
	if button.custom_minimum_size.x < min_width or button.custom_minimum_size.y < min_height:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: %s button too small: %s" % [label, str(button.custom_minimum_size)])
		quit(1)
		return
	var rect: Rect2 = button.get_global_rect()
	var viewport_size: Vector2 = get_root().get_visible_rect().size
	if rect.position.x < -0.5 or rect.end.x > viewport_size.x + 0.5:
		push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: %s button is horizontally offscreen: %s" % [label, str(rect)])
		quit(1)
