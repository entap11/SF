extends SceneTree

const JUKEBOX_PANEL_SCENE := preload("res://scenes/ui/JukeboxPanel.tscn")
const TEST_VIEWPORT_SIZE := Vector2(944.0, 2048.0)

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
	root.size = Vector2i(int(TEST_VIEWPORT_SIZE.x), int(TEST_VIEWPORT_SIZE.y))
	var panel: Panel = JUKEBOX_PANEL_SCENE.instantiate() as Panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2.ZERO
	panel.size = TEST_VIEWPORT_SIZE
	root.add_child(panel)
	panel.visible = true
	panel.size = TEST_VIEWPORT_SIZE
	await process_frame
	await process_frame
	var background: Control = panel.get_node_or_null("JukeboxHexBackground") as Control
	if background == null:
		return _fail("Jukebox hex background missing")
	var play_button: Button = panel.find_child("PlayButton", true, false) as Button
	if play_button == null:
		return _fail("PlayButton missing")
	if play_button.custom_minimum_size.x < 300.0:
		return _fail("PlayButton is too narrow: %s" % str(play_button.custom_minimum_size))
	if play_button.custom_minimum_size.y < 100.0:
		return _fail("PlayButton is too small: %s" % str(play_button.custom_minimum_size))
	if play_button.disabled:
		return _fail("PlayButton should be enabled when a map is selected")
	var play_sprite: TextureRect = play_button.find_child("PlaySprite", true, false) as TextureRect
	if play_sprite == null or play_sprite.texture == null:
		return _fail("PlaySprite missing texture")
	if not play_sprite.visible or play_sprite.self_modulate.a < 0.9:
		return _fail("PlaySprite should be the visible PlayButton treatment")
	var footer_button: Button = panel.get_node_or_null("FooterCloseButton") as Button
	var footer_sprite: TextureRect = footer_button.get_node_or_null("MainMenuSprite") as TextureRect if footer_button != null else null
	if footer_button == null or footer_sprite == null or footer_sprite.texture == null or not footer_sprite.visible:
		return _fail("Footer Main Menu sprite missing")
	if panel.find_child("MapBest", true, false) != null:
		return _fail("Redundant top Map PB label should be removed")
	if footer_button.custom_minimum_size.y < 64.0:
		return _fail("Footer Main Menu action is below the 64-unit touch floor")
	if play_button.text != "PLAY":
		return _fail("PlayButton should use readable PLAY text")
	if play_button.get_theme_font_size("font_size") < 42:
		return _fail("PlayButton font is too small: %d" % play_button.get_theme_font_size("font_size"))
	var preview: Control = panel.find_child("MapSchematicPreview", true, false) as Control
	if preview == null:
		return _fail("MapSchematicPreview missing")
	if not preview.visible:
		return _fail("MapSchematicPreview should be visible for selected map")
	var preview_panel: Control = panel.find_child("HeroPreviewPanel", true, false) as Control
	if preview_panel == null:
		return _fail("HeroPreviewPanel missing")
	var hero_panel: Control = panel.get_node_or_null("VBox/HeroPanel") as Control
	if hero_panel == null:
		return _fail("HeroPanel missing")
	if hero_panel.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
		return _fail("HeroPanel should fill the content width so the schematic can align left")
	var selector_panel: Control = panel.find_child("SelectorPanel", true, false) as Control
	if selector_panel == null:
		return _fail("SelectorPanel missing")
	var leaderboard_panel: Control = panel.find_child("LeaderboardPanel", true, false) as Control
	var preview_rect: Rect2 = preview_panel.get_global_rect()
	var selector_rect: Rect2 = selector_panel.get_global_rect()
	var leaderboard_rect: Rect2 = leaderboard_panel.get_global_rect() if leaderboard_panel != null else Rect2()
	if selector_rect.position.x <= preview_rect.end.x:
		return _fail("Map selector should sit beside the preview when the debug/mobile panel is wide enough")
	var hero_rect: Rect2 = hero_panel.get_global_rect()
	var expected_preview_left: float = hero_rect.position.x + 14.0
	if absf(preview_rect.position.x - expected_preview_left) > 2.0:
		return _fail("Map schematic should align to the left edge of HeroPanel content: hero=%s preview=%s" % [str(hero_rect), str(preview_rect)])
	if not hero_rect.encloses(selector_rect):
		return _fail("Map selector should stay inside the selected-map panel: hero=%s selector=%s" % [str(hero_rect), str(selector_rect)])
	if leaderboard_rect.position.y < hero_rect.end.y:
		return _fail("Leaderboard should occupy the full-width slot below the selected map: hero=%s leaderboard=%s" % [str(hero_rect), str(leaderboard_rect)])
	if leaderboard_rect.size.x < hero_rect.size.x - 2.0:
		return _fail("Leaderboard should use the full landscape width: hero=%s leaderboard=%s" % [str(hero_rect), str(leaderboard_rect)])
	if leaderboard_rect.size.y < 650.0:
		return _fail("Leaderboard should inherit the tall selector slot: %s" % str(leaderboard_rect))
	if int(panel.call("_leaderboard_page_size")) != 5:
		return _fail("Full-width leaderboard should expose exactly five ranked slots")
	var leaderboard_list: VBoxContainer = panel.find_child("LeaderboardList", true, false) as VBoxContainer
	if leaderboard_list == null or leaderboard_list.get_child_count() <= 0:
		return _fail("LeaderboardList should contain header rows")
	if leaderboard_list.get_child_count() != 6:
		return _fail("LeaderboardList should contain one header and five ranked slots")
	for slot_index in range(5):
		var slot_row: HBoxContainer = leaderboard_list.get_child(slot_index + 1) as HBoxContainer
		var slot_rank: Label = slot_row.get_child(0) as Label if slot_row != null and slot_row.get_child_count() > 0 else null
		if slot_rank == null or slot_rank.text != "%d." % (slot_index + 1):
			return _fail("Leaderboard slot %d should remain visibly ranked" % (slot_index + 1))
	var leaderboard_header: HBoxContainer = leaderboard_list.get_child(0) as HBoxContainer
	if leaderboard_header == null or leaderboard_header.get_child_count() <= 0:
		return _fail("Leaderboard header row missing")
	var leaderboard_header_label: Label = leaderboard_header.get_child(0) as Label
	if leaderboard_header_label == null or leaderboard_header_label.get_theme_font_size("font_size") < 44:
		return _fail("Leaderboard header font should be 2x larger, got %d" % (leaderboard_header_label.get_theme_font_size("font_size") if leaderboard_header_label != null else 0))
	var preview_ratio: float = preview_panel.custom_minimum_size.y / TEST_VIEWPORT_SIZE.y
	if preview_ratio < 0.25 or preview_ratio > 0.43:
		return _fail("HeroPreviewPanel should occupy 25-43%% of panel height, got %.3f with %s" % [preview_ratio, str(preview_panel.custom_minimum_size)])
	if preview_panel.custom_minimum_size.y <= preview_panel.custom_minimum_size.x:
		return _fail("Portrait map schematic should read as portrait: %s" % str(preview_panel.custom_minimum_size))
	var play_rect: Rect2 = play_button.get_global_rect()
	if play_rect.position.y < preview_rect.end.y or play_rect.position.y - preview_rect.end.y > 20.0:
		return _fail("PlayButton should sit immediately beneath schematic: preview=%s play=%s" % [str(preview_rect), str(play_rect)])
	var hives_any: Variant = preview.get("_hives")
	if typeof(hives_any) != TYPE_ARRAY or (hives_any as Array).is_empty():
		return _fail("MapSchematicPreview did not load hive topology")
	root.size = Vector2i(1440, 900)
	panel.size = Vector2(1440.0, 900.0)
	if panel.has_method("_apply_responsive_layout"):
		panel.call("_apply_responsive_layout")
	await process_frame
	await process_frame
	var content_host: Control = panel.get_node_or_null("VBox/ContentHost") as Control
	if content_host != null:
		return _fail("Desktop should use the direct vertical hierarchy without ContentHost")
	var desktop_preview_panel: Control = panel.find_child("HeroPreviewPanel", true, false) as Control
	if desktop_preview_panel == null:
		return _fail("Desktop HeroPreviewPanel missing")
	var desktop_hero_panel: Control = panel.get_node_or_null("VBox/HeroPanel") as Control
	if desktop_hero_panel == null:
		return _fail("Desktop HeroPanel missing")
	var desktop_selector_panel: Control = panel.find_child("SelectorPanel", true, false) as Control
	var desktop_leaderboard_panel: Control = panel.find_child("LeaderboardPanel", true, false) as Control
	if desktop_selector_panel == null or desktop_selector_panel.get_global_rect().position.x <= desktop_preview_panel.get_global_rect().end.x:
		return _fail("Desktop map selector should sit beside the preview")
	if desktop_leaderboard_panel == null:
		return _fail("Desktop leaderboard missing")
	var desktop_hero_rect: Rect2 = desktop_hero_panel.get_global_rect()
	var desktop_preview_rect: Rect2 = desktop_preview_panel.get_global_rect()
	if absf(desktop_preview_rect.position.x - (desktop_hero_rect.position.x + 14.0)) > 2.0:
		return _fail("Desktop map schematic should remain left-aligned: hero=%s preview=%s" % [str(desktop_hero_rect), str(desktop_preview_rect)])
	var desktop_leaderboard_rect: Rect2 = desktop_leaderboard_panel.get_global_rect()
	if desktop_leaderboard_rect.position.y < desktop_hero_rect.end.y:
		return _fail("Desktop leaderboard should sit below the selected-map panel")
	if desktop_leaderboard_rect.size.x < desktop_hero_rect.size.x - 2.0:
		return _fail("Desktop leaderboard should use the full landscape width")
	var desktop_ratio: float = desktop_preview_panel.custom_minimum_size.y / 900.0
	if desktop_ratio < 0.25 or desktop_ratio > 0.43:
		return _fail("Desktop preview should occupy 25-43%% of panel height, got %.3f with %s" % [desktop_ratio, str(desktop_preview_panel.custom_minimum_size)])
	panel.queue_free()
	return false

func _fail(message: String) -> bool:
	push_error("JUKEBOX_PANEL_PREVIEW_SMOKE: %s" % message)
	return true
