extends SceneTree

const JUKEBOX_PANEL_SCENE := preload("res://scenes/ui/JukeboxPanel.tscn")

func _init() -> void:
	await process_frame
	var failed: bool = false
	failed = await _test_jukebox_preview_and_play_button_layout() or failed
	if failed:
		quit(1)
		return
	print("JUKEBOX_PANEL_PREVIEW_SMOKE: PASS")
	quit(0)

func _test_jukebox_preview_and_play_button_layout() -> bool:
	var panel: Panel = JUKEBOX_PANEL_SCENE.instantiate() as Panel
	root.add_child(panel)
	panel.visible = true
	await process_frame
	await process_frame
	var play_button: Button = panel.get_node_or_null("VBox/HeroPanel/HeroVBox/PlayButton") as Button
	if play_button == null:
		return _fail("PlayButton missing")
	if play_button.custom_minimum_size.x < 340.0:
		return _fail("PlayButton is too narrow: %s" % str(play_button.custom_minimum_size))
	if play_button.custom_minimum_size.y < 120.0:
		return _fail("PlayButton is too small: %s" % str(play_button.custom_minimum_size))
	if play_button.disabled:
		return _fail("PlayButton should be enabled when a map is selected")
	var play_sprite: TextureRect = panel.get_node_or_null("VBox/HeroPanel/HeroVBox/PlayButton/PlaySprite") as TextureRect
	if play_sprite == null or play_sprite.texture == null:
		return _fail("PlaySprite missing texture")
	if play_sprite.modulate.a < 0.99 or play_sprite.self_modulate.a < 0.99:
		return _fail("PlaySprite should be fully opaque")
	var preview: Control = panel.get_node_or_null("VBox/HeroPanel/HeroVBox/HeroPreviewPanel/MapSchematicPreview") as Control
	if preview == null:
		return _fail("MapSchematicPreview missing")
	if not preview.visible:
		return _fail("MapSchematicPreview should be visible for selected map")
	var hives_any: Variant = preview.get("_hives")
	if typeof(hives_any) != TYPE_ARRAY or (hives_any as Array).is_empty():
		return _fail("MapSchematicPreview did not load hive topology")
	panel.queue_free()
	return false

func _fail(message: String) -> bool:
	push_error("JUKEBOX_PANEL_PREVIEW_SMOKE: %s" % message)
	return true
