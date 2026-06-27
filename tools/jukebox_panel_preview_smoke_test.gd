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
	if hero_panel.size_flags_horizontal != Control.SIZE_SHRINK_CENTER:
		return _fail("HeroPanel should shrink-center around selected map card")
	var selected_title: Label = panel.find_child("SelectedTitle", true, false) as Label
	var selected_title_width: float = selected_title.get_combined_minimum_size().x if selected_title != null else 0.0
	var leaderboard_panel: Control = panel.find_child("LeaderboardPanel", true, false) as Control
	var leaderboard_width: float = leaderboard_panel.custom_minimum_size.x if leaderboard_panel != null else 0.0
	var preview_rect: Rect2 = preview_panel.get_global_rect()
	var leaderboard_rect: Rect2 = leaderboard_panel.get_global_rect() if leaderboard_panel != null else Rect2()
	var uses_side_leaderboard: bool = leaderboard_panel != null and leaderboard_rect.position.x > preview_rect.end.x
	var card_content_width: float = maxf(maxf(preview_panel.custom_minimum_size.x, play_button.custom_minimum_size.x), selected_title_width)
	if uses_side_leaderboard:
		card_content_width = maxf(card_content_width, maxf(preview_panel.custom_minimum_size.x, play_button.custom_minimum_size.x) + leaderboard_width)
	else:
		card_content_width = maxf(card_content_width, leaderboard_width)
	if hero_panel.custom_minimum_size.x > card_content_width + 80.0:
		return _fail("HeroPanel is too wide for compact preview card: hero=%s preview=%s play=%s" % [str(hero_panel.custom_minimum_size), str(preview_panel.custom_minimum_size), str(play_button.custom_minimum_size)])
	if hero_panel.custom_minimum_size.x > TEST_VIEWPORT_SIZE.x * 0.94:
		return _fail("HeroPanel still reads as a full-width billboard on mobile: %s" % str(hero_panel.custom_minimum_size))
	if hero_panel.custom_minimum_size.x < TEST_VIEWPORT_SIZE.x * 0.82:
		return _fail("HeroPanel should use the available left/right space: %s" % str(hero_panel.custom_minimum_size))
	if not uses_side_leaderboard:
		return _fail("Leaderboard should sit beside the preview when the debug/mobile panel is wide enough")
	if absf(leaderboard_panel.custom_minimum_size.x - preview_panel.custom_minimum_size.x) > 2.0:
		return _fail("Side leaderboard should match preview width: leaderboard=%s preview=%s" % [str(leaderboard_panel.custom_minimum_size), str(preview_panel.custom_minimum_size)])
	if absf(leaderboard_panel.custom_minimum_size.y - preview_panel.custom_minimum_size.y) > 2.0:
		return _fail("Side leaderboard should match preview height: leaderboard=%s preview=%s" % [str(leaderboard_panel.custom_minimum_size), str(preview_panel.custom_minimum_size)])
	var leaderboard_list: VBoxContainer = panel.find_child("LeaderboardList", true, false) as VBoxContainer
	if leaderboard_list == null or leaderboard_list.get_child_count() <= 0:
		return _fail("LeaderboardList should contain header rows")
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
	var desktop_title: Label = panel.find_child("SelectedTitle", true, false) as Label
	var desktop_title_width: float = desktop_title.get_combined_minimum_size().x if desktop_title != null else 0.0
	var desktop_leaderboard_panel: Control = panel.find_child("LeaderboardPanel", true, false) as Control
	var desktop_leaderboard_width: float = desktop_leaderboard_panel.custom_minimum_size.x if desktop_leaderboard_panel != null else 0.0
	var desktop_card_content_width: float = maxf(desktop_preview_panel.custom_minimum_size.x, play_button.custom_minimum_size.x) + desktop_leaderboard_width
	desktop_card_content_width = maxf(desktop_card_content_width, desktop_title_width)
	if desktop_hero_panel.custom_minimum_size.x > desktop_card_content_width + 80.0:
		return _fail("Desktop HeroPanel does not hug selected map content: hero=%s preview=%s play=%s" % [str(desktop_hero_panel.custom_minimum_size), str(desktop_preview_panel.custom_minimum_size), str(play_button.custom_minimum_size)])
	if desktop_hero_panel.custom_minimum_size.x > 980.0:
		return _fail("Desktop HeroPanel should stay compact while hosting leaderboard: %s" % str(desktop_hero_panel.custom_minimum_size))
	if desktop_leaderboard_panel == null or desktop_leaderboard_panel.get_global_rect().position.x <= desktop_preview_panel.get_global_rect().end.x:
		return _fail("Desktop leaderboard should sit beside the preview")
	var desktop_ratio: float = desktop_preview_panel.custom_minimum_size.y / 900.0
	if desktop_ratio < 0.25 or desktop_ratio > 0.43:
		return _fail("Desktop preview should occupy 25-43%% of panel height, got %.3f with %s" % [desktop_ratio, str(desktop_preview_panel.custom_minimum_size)])
	panel.queue_free()
	return false

func _fail(message: String) -> bool:
	push_error("JUKEBOX_PANEL_PREVIEW_SMOKE: %s" % message)
	return true
