extends SceneTree

const TEST_VIEWPORT_SIZE := Vector2i(944, 2048)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = TEST_VIEWPORT_SIZE
	await process_frame
	var scene := load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame
	if not menu.has_method("_open_buffs_panel"):
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: buffs open method missing")
		quit(1)
		return
	menu.call("_open_buffs_panel")
	await process_frame
	await process_frame

	var panel: Control = menu.get_node_or_null("DashPanel/DashBuffsPanel") as Control
	if panel == null or not panel.visible:
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: DashBuffsPanel did not open")
		quit(1)
		return
	var content: Control = menu.get_node_or_null("DashPanel/DashBuffsPanel/BuffsVBox") as Control
	var viewport_size: Vector2 = get_root().get_visible_rect().size
	var content_rect: Rect2 = content.get_global_rect() if content != null else Rect2()
	if content == null or content_rect.position.y < -0.5 or content_rect.end.y > viewport_size.y + 0.5:
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: buffs content is offscreen")
		quit(1)
		return

	_assert_font_at_least(menu, "DashPanel/DashBuffsPanel/BuffsVBox/BuffsTitle", 25, "title")
	_assert_font_at_least(menu, "DashPanel/DashBuffsPanel/BuffsVBox/BuffsSub", 18, "subtitle")
	_assert_button_min(menu, "DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsModeTabs/BuffsModeVS", 48.0, "mode tab")
	_assert_button_min(menu, "DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLoadoutPanel/BuffsLoadoutVBox/LoadoutTopPanel/LoadoutTopVBox/BuffsSlotsRow/BuffSlot1", 38.0, "loadout slot")

	var classic_tier: Control = menu.get_node_or_null("DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffsTopRow/BuffsLibraryPanel/BuffsLibraryVBox/BuffLibraryTierRoot/Tier_classic") as Control
	var classic_grid: GridContainer = _find_first_descendant_of_type(classic_tier, "GridContainer") as GridContainer
	if classic_grid == null:
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: classic buff grid missing")
		quit(1)
		return
	if classic_grid.columns != 1:
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: buff library should use one readable column")
		quit(1)
		return
	var first_library_button: Button = null
	for child in classic_grid.get_children():
		if child is Button:
			first_library_button = child as Button
			break
	if first_library_button == null or first_library_button.custom_minimum_size.y < 38.0:
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: library buttons are still too small")
		quit(1)
		return

	var cart_root: Control = menu.get_node_or_null("DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffCartRoot") as Control
	if cart_root == null or cart_root.custom_minimum_size.y < 232.0:
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: cart area was not enlarged")
		quit(1)
		return

	print("MAIN_MENU_BUFFS_LAYOUT_SMOKE: PASS")
	quit(0)

func _assert_font_at_least(root: Node, path: String, expected: int, label: String) -> void:
	var control: Control = root.get_node_or_null(path) as Control
	if control == null:
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: missing %s" % label)
		quit(1)
		return
	var size: int = control.get_theme_font_size("font_size")
	if size < expected:
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: %s font too small: %d" % [label, size])
		quit(1)

func _assert_button_min(root: Node, path: String, expected_height: float, label: String) -> void:
	var button: Button = root.get_node_or_null(path) as Button
	if button == null:
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: missing %s" % label)
		quit(1)
		return
	if button.custom_minimum_size.y < expected_height:
		push_error("MAIN_MENU_BUFFS_LAYOUT_SMOKE: %s too short: %.1f" % [label, button.custom_minimum_size.y])
		quit(1)

func _find_first_descendant_of_type(node: Node, target_class: String) -> Node:
	if node == null:
		return null
	for child in node.get_children():
		if child.get_class() == target_class:
			return child
		var nested: Node = _find_first_descendant_of_type(child, target_class)
		if nested != null:
			return nested
	return null
