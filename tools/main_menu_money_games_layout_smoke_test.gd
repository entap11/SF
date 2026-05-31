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
	_assert_tooltip_button(buttons, "1V1", 250.0, 104.0)
	_assert_tooltip_button(buttons, "4P FFA", 250.0, 104.0)
	_assert_tooltip_button(buttons, "WEEKLY", 350.0, 132.0)
	_assert_tooltip_button(buttons, "MONTHLY", 350.0, 132.0)
	_assert_text_button(buttons, "DIVISION I", 208.0, 82.0)
	_assert_text_button(buttons, "$1", 128.0, 56.0)

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
	for button in buttons:
		if not button.tooltip_text.contains(token):
			continue
		_assert_button_size(button, min_width, min_height, token)
		return
	push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: missing tooltip button %s" % token)
	quit(1)

func _assert_text_button(buttons: Array[Button], text_value: String, min_width: float, min_height: float) -> void:
	for button in buttons:
		if button.text.strip_edges() != text_value:
			continue
		_assert_button_size(button, min_width, min_height, text_value)
		return
	push_error("MAIN_MENU_MONEY_GAMES_LAYOUT_SMOKE: missing text button %s" % text_value)
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
