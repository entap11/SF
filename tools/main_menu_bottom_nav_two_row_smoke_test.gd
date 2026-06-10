extends SceneTree

const TEST_VIEWPORT_SIZE := Vector2i(944, 2048)
const MIN_BUTTON_WIDTH := 180.0
const MIN_BUTTON_HEIGHT := 320.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = TEST_VIEWPORT_SIZE
	await process_frame
	var scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame

	var utility_row: HBoxContainer = menu.get_node_or_null("BottomBar/UtilityButtons") as HBoxContainer
	var primary_row: HBoxContainer = menu.get_node_or_null("BottomBar/MenuButtons") as HBoxContainer
	if utility_row == null or primary_row == null:
		push_error("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: two-row bottom nav missing")
		quit(1)
		return
	var top_buttons: Array[Button] = [
		menu.get_node_or_null("BottomBar/UtilityButtons/AsyncButton") as Button,
		menu.get_node_or_null("BottomBar/UtilityButtons/BuffsButton") as Button,
		menu.get_node_or_null("BottomBar/UtilityButtons/ClanButton") as Button
	]
	var bottom_buttons: Array[Button] = [
		menu.get_node_or_null("BottomBar/MenuButtons/StoreButton") as Button,
		menu.get_node_or_null("BottomBar/MenuButtons/PlayButton") as Button,
		menu.get_node_or_null("BottomBar/MenuButtons/JukeboxButton") as Button,
		menu.get_node_or_null("BottomBar/MenuButtons/SettingsButton") as Button
	]
	_assert_row_buttons(top_buttons, "utility")
	_assert_row_buttons(bottom_buttons, "primary")
	if top_buttons[0].get_global_rect().position.y >= bottom_buttons[0].get_global_rect().position.y:
		push_error("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: utility row is not above primary row")
		quit(1)
		return
	_assert_even_spacing(top_buttons, "utility")
	_assert_even_spacing(bottom_buttons, "primary")
	print("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: PASS")
	quit(0)

func _assert_row_buttons(buttons: Array[Button], label: String) -> void:
	var viewport_width: float = get_root().get_visible_rect().size.x
	for button in buttons:
		if button == null or not button.visible:
			push_error("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: %s row button missing" % label)
			quit(1)
			return
		if button.custom_minimum_size.x < MIN_BUTTON_WIDTH or button.custom_minimum_size.y < MIN_BUTTON_HEIGHT:
			push_error("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: %s row button too small: %s" % [label, str(button.custom_minimum_size)])
			quit(1)
			return
		var rect: Rect2 = button.get_global_rect()
		if rect.position.x < -0.5 or rect.end.x > viewport_width + 0.5:
			push_error("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: %s row button offscreen: %s" % [label, str(rect)])
			quit(1)
			return

func _assert_even_spacing(buttons: Array[Button], label: String) -> void:
	var widths: Array[float] = []
	for button in buttons:
		widths.append(button.get_global_rect().size.x)
	var first_width: float = widths[0]
	for width in widths:
		if absf(width - first_width) > 2.0:
			push_error("MAIN_MENU_BOTTOM_NAV_TWO_ROW_SMOKE: %s row is not evenly sized: %s" % [label, str(widths)])
			quit(1)
			return
