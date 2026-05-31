extends SceneTree

const TEST_VIEWPORT_SIZE := Vector2i(944, 2048)
const EXPECTED_MIN_TOP_Y: float = 430.0
const EXPECTED_BOTTOM_INSET: float = 14.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = TEST_VIEWPORT_SIZE
	await process_frame
	var scene := load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_STORE_LAYOUT_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame
	if not menu.has_method("_open_storefront_panel"):
		push_error("MAIN_MENU_STORE_LAYOUT_SMOKE: storefront open method missing")
		quit(1)
		return
	menu.call("_open_storefront_panel")
	await process_frame
	await process_frame
	var store_panel: Control = menu.get_node_or_null("DashPanel/DashStorePanel") as Control
	if store_panel == null:
		push_error("MAIN_MENU_STORE_LAYOUT_SMOKE: DashStorePanel missing")
		quit(1)
		return
	if not store_panel.visible:
		push_error("MAIN_MENU_STORE_LAYOUT_SMOKE: DashStorePanel did not open")
		quit(1)
		return
	var rect: Rect2 = store_panel.get_global_rect()
	if rect.position.y < EXPECTED_MIN_TOP_Y:
		push_error("MAIN_MENU_STORE_LAYOUT_SMOKE: store panel still opens too high: %.1f" % rect.position.y)
		quit(1)
		return
	if rect.end.y > float(TEST_VIEWPORT_SIZE.y) - EXPECTED_BOTTOM_INSET + 0.5:
		push_error("MAIN_MENU_STORE_LAYOUT_SMOKE: store panel pushed off bottom: %.1f" % rect.end.y)
		quit(1)
		return
	print("MAIN_MENU_STORE_LAYOUT_SMOKE: PASS top=%.1f bottom=%.1f" % [rect.position.y, rect.end.y])
	quit(0)
