extends Control

const MAIN_MENU_SCENE := preload("res://scenes/MainMenu.tscn")
const OUTPUT_PATH: String = "/tmp/swarmfront_tier_widget_header.png"

func _ready() -> void:
	get_viewport().size = Vector2i(1080, 1920)
	var menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	for _frame in range(8):
		await get_tree().process_frame
	var widget: Control = menu.get_node_or_null("TopBar/TierWidget") as Control
	if widget == null:
		_fail("TierWidget missing")
		return
	widget.call("_set_values", {
		"tier_index": 1,
		"tier_rank": 1,
		"tier_total": 19,
		"tier_population": 1,
		"tier_name": "Drone",
		"color_id": "YELLOW"
	}, false)
	for _frame in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image = image.get_region(Rect2i(0, 0, 1080, 600))
	var save_error: Error = image.save_png(OUTPUT_PATH)
	if save_error != OK:
		_fail("failed to save screenshot (%d)" % save_error)
		return
	print("TIER_WIDGET_VISUAL: %s" % OUTPUT_PATH)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("TIER_WIDGET_VISUAL: %s" % message)
	get_tree().quit(1)
