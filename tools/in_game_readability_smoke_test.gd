extends SceneTree

const TEST_VIEWPORT_SIZE := Vector2i(944, 2048)

func _initialize() -> void:
	root.size = TEST_VIEWPORT_SIZE
	var packed: PackedScene = load("res://scenes/Shell.tscn") as PackedScene
	if packed == null:
		_fail("failed to load Shell.tscn")
		return
	var shell: Node = packed.instantiate()
	root.add_child(shell)
	await process_frame
	await process_frame
	var menu_button: Button = shell.get_node_or_null("MenuRoot/BackButton") as Button
	if menu_button == null:
		_fail("persistent in-game Menu button is missing")
		return
	if menu_button.get_theme_font_size("font_size") < 38:
		_fail("persistent in-game Menu text is below the compact-button floor")
		return
	if menu_button.custom_minimum_size.y < 110.0 or menu_button.size.y < 110.0:
		_fail("persistent in-game Menu action is below the enlarged 110-unit touch floor")
		return
	shell.queue_free()
	print("IN_GAME_READABILITY_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("IN_GAME_READABILITY_SMOKE: %s" % message)
	quit(1)
