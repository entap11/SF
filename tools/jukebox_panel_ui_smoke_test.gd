extends SceneTree

const JukeboxPanelScene: PackedScene = preload("res://scenes/ui/JukeboxPanel.tscn")
const TEST_VIEWPORT_SIZE := Vector2(944.0, 2048.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(int(TEST_VIEWPORT_SIZE.x), int(TEST_VIEWPORT_SIZE.y))
	var panel_any: Variant = JukeboxPanelScene.instantiate()
	if not (panel_any is Control):
		push_error("JUKEBOX_PANEL_UI_SMOKE: panel instantiate failed")
		quit(1)
		return
	var panel: Control = panel_any as Control
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2.ZERO
	panel.size = TEST_VIEWPORT_SIZE
	get_root().add_child(panel)
	await process_frame
	panel.visible = true
	panel.size = TEST_VIEWPORT_SIZE
	await process_frame

	var brand_banner: TextureRect = panel.get_node_or_null("VBox/BrandBannerArt") as TextureRect
	if brand_banner == null or brand_banner.texture == null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: red brand banner art missing")
		quit(1)
		return
	if brand_banner.custom_minimum_size.y < 130.0:
		push_error("JUKEBOX_PANEL_UI_SMOKE: brand banner art is too small")
		quit(1)
		return
	var play_any: Node = panel.find_child("PlayButton", true, false)
	if not (play_any is Button):
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button missing from hero section")
		quit(1)
		return
	var play_button: Button = play_any as Button
	if play_button.text != "PLAY":
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button should use readable PLAY text")
		quit(1)
		return
	if panel.get_node_or_null("VBox/SelectorPanel/SelectorVBox/PlayButton") != null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: stale selector play button still present")
		quit(1)
		return
	var play_sprite_any: Node = play_button.get_node_or_null("PlaySprite")
	if not (play_sprite_any is TextureRect):
		push_error("JUKEBOX_PANEL_UI_SMOKE: play sprite node missing")
		quit(1)
		return
	var play_sprite: TextureRect = play_sprite_any as TextureRect
	if play_sprite.texture == null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: play sprite texture not applied")
		quit(1)
		return
	if play_button.custom_minimum_size.y < 120.0:
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button is too small")
		quit(1)
		return
	var cpu_panel_any: Node = panel.get_node_or_null("VBox/CpuPanel")
	if not (cpu_panel_any is Control):
		push_error("JUKEBOX_PANEL_UI_SMOKE: CPU panel missing")
		quit(1)
		return
	if (cpu_panel_any as Control).visible:
		push_error("JUKEBOX_PANEL_UI_SMOKE: Jukebox CPU selector should be hidden")
		quit(1)
		return
	if not panel.has_method("capture_runtime_state"):
		push_error("JUKEBOX_PANEL_UI_SMOKE: panel cannot expose runtime state")
		quit(1)
		return
	var initial_state: Dictionary = panel.call("capture_runtime_state") as Dictionary
	var initial_map_path: String = str(initial_state.get("selected_map_path", ""))
	var second_button: Button = _second_map_button(panel, initial_map_path)
	if second_button == null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: second map button unavailable")
		quit(1)
		return
	second_button.pressed.emit()
	await process_frame
	var changed_state: Dictionary = panel.call("capture_runtime_state") as Dictionary
	var changed_map_path: String = str(changed_state.get("selected_map_path", ""))
	if changed_map_path.is_empty() or changed_map_path == initial_map_path:
		push_error("JUKEBOX_PANEL_UI_SMOKE: clicking a map card did not change selected map")
		quit(1)
		return
	var page_label_any: Node = panel.find_child("LeaderboardPage", true, false)
	if not (page_label_any is Label):
		push_error("JUKEBOX_PANEL_UI_SMOKE: leaderboard page label missing")
		quit(1)
		return
	if str((page_label_any as Label).text).strip_edges().is_empty():
		push_error("JUKEBOX_PANEL_UI_SMOKE: leaderboard did not refresh after map click")
		quit(1)
		return
	var map_list: VBoxContainer = _map_list(panel)
	if map_list == null or map_list.get_child_count() <= 0:
		push_error("JUKEBOX_PANEL_UI_SMOKE: map selector did not populate")
		quit(1)
		return
	if map_list.get_child_count() < 6:
		push_error("JUKEBOX_PANEL_UI_SMOKE: map selector should expose more rows before scrolling")
		quit(1)
		return
	var first_card: Button = map_list.get_child(0) as Button
	if first_card == null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: first map card is not clickable")
		quit(1)
		return
	first_card.pressed.emit()
	await process_frame
	await process_frame
	if play_button.disabled:
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button disabled after map selection")
		quit(1)
		return
	var hero_panel: Control = panel.get_node_or_null("VBox/HeroPanel") as Control
	var hero_preview_panel: Control = panel.find_child("HeroPreviewPanel", true, false) as Control
	var selector_panel: Control = panel.get_node_or_null("VBox/SelectorPanel") as Control
	var leaderboard_panel: Control = panel.find_child("LeaderboardPanel", true, false) as Control
	var play_rect: Rect2 = play_button.get_global_rect()
	var hero_rect: Rect2 = hero_panel.get_global_rect() if hero_panel != null else Rect2()
	if hero_panel == null or not _rect_contains_rect(hero_rect, play_rect):
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button overflows hero panel after map selection")
		quit(1)
		return
	if hero_preview_panel == null or play_rect.position.y < hero_preview_panel.get_global_rect().end.y:
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button is not below map preview")
		quit(1)
		return
	if play_rect.position.y - hero_preview_panel.get_global_rect().end.y > 20.0:
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button is too far from map preview")
		quit(1)
		return
	if selector_panel == null or leaderboard_panel == null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: selector or leaderboard panel missing")
		quit(1)
		return
	var selected_title: Label = panel.find_child("SelectedTitle", true, false) as Label
	var selected_title_width: float = selected_title.get_combined_minimum_size().x if selected_title != null else 0.0
	var preview_rect: Rect2 = hero_preview_panel.get_global_rect()
	var leaderboard_rect: Rect2 = leaderboard_panel.get_global_rect()
	var uses_side_leaderboard: bool = leaderboard_rect.position.x > preview_rect.end.x
	var compact_content_width: float = maxf(maxf(hero_preview_panel.custom_minimum_size.x, play_button.custom_minimum_size.x), selected_title_width)
	if uses_side_leaderboard:
		compact_content_width = maxf(compact_content_width, maxf(hero_preview_panel.custom_minimum_size.x, play_button.custom_minimum_size.x) + leaderboard_panel.custom_minimum_size.x)
	else:
		compact_content_width = maxf(compact_content_width, leaderboard_panel.custom_minimum_size.x)
	if hero_panel.custom_minimum_size.x > compact_content_width + 80.0:
		push_error("JUKEBOX_PANEL_UI_SMOKE: selected map card is wider than its preview/play content")
		quit(1)
		return
	if hero_panel.custom_minimum_size.x < TEST_VIEWPORT_SIZE.x * 0.82:
		push_error("JUKEBOX_PANEL_UI_SMOKE: selected map card should use more left/right space")
		quit(1)
		return
	if not (hero_panel.get_global_rect().position.y < selector_panel.get_global_rect().position.y):
		push_error("JUKEBOX_PANEL_UI_SMOKE: visual hierarchy is not selected card -> map list")
		quit(1)
		return
	if not uses_side_leaderboard:
		push_error("JUKEBOX_PANEL_UI_SMOKE: leaderboard should sit beside preview at this debug/mobile width")
		quit(1)
		return
	if absf(leaderboard_panel.custom_minimum_size.x - hero_preview_panel.custom_minimum_size.x) > 2.0:
		push_error("JUKEBOX_PANEL_UI_SMOKE: side leaderboard should match preview width")
		quit(1)
		return
	if absf(leaderboard_panel.custom_minimum_size.y - hero_preview_panel.custom_minimum_size.y) > 2.0:
		push_error("JUKEBOX_PANEL_UI_SMOKE: side leaderboard should match preview height")
		quit(1)
		return
	for blocker_path in [
		"VBox/SelectorPanel",
		"VBox/FooterCloseButton"
	]:
		var blocker: Control = panel.get_node_or_null(blocker_path) as Control
		if blocker != null and blocker.visible and blocker.get_global_rect().intersects(play_rect):
			push_error("JUKEBOX_PANEL_UI_SMOKE: play button is overlapped by %s" % blocker_path)
			quit(1)
			return
	var requested: Array[String] = []
	panel.play_requested.connect(func(map_path: String, _cpu_style: String, _cpu_tier: String) -> void:
		requested.append(map_path)
	)
	var hit_control: Control = _topmost_control_at(panel, play_rect.get_center())
	if hit_control != play_button:
		var hit_path: String = str(hit_control.get_path()) if hit_control != null else "<none>"
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button center is blocked by %s" % hit_path)
		quit(1)
		return
	play_button.pressed.emit()
	await process_frame
	await process_frame
	if requested.is_empty():
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button did not emit play_requested")
		quit(1)
		return
	var alternate_tab: Button = _first_alternate_category_button(panel)
	if alternate_tab == null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: alternate category tab missing")
		quit(1)
		return
	var alternate_label: String = alternate_tab.text
	alternate_tab.pressed.emit()
	await process_frame
	await process_frame
	var alternate_state: Dictionary = panel.call("capture_runtime_state") as Dictionary
	if str(alternate_state.get("selected_category", "")) != alternate_label:
		push_error("JUKEBOX_PANEL_UI_SMOKE: alternate tab did not select category")
		quit(1)
		return
	if str(alternate_state.get("selected_map_path", "")).strip_edges().is_empty():
		push_error("JUKEBOX_PANEL_UI_SMOKE: alternate category did not select a map")
		quit(1)
		return
	get_root().size = Vector2i(1440, 900)
	panel.size = Vector2(1440.0, 900.0)
	if panel.has_method("_apply_responsive_layout"):
		panel.call("_apply_responsive_layout")
	await process_frame
	await process_frame
	var content_host: Control = panel.get_node_or_null("VBox/ContentHost") as Control
	var desktop_selector: Control = panel.get_node_or_null("VBox/SelectorPanel") as Control
	var desktop_hero: Control = panel.get_node_or_null("VBox/HeroPanel") as Control
	var desktop_leaderboard: Control = panel.find_child("LeaderboardPanel", true, false) as Control
	var desktop_preview: Control = panel.find_child("HeroPreviewPanel", true, false) as Control
	if content_host != null or desktop_selector == null or desktop_hero == null or desktop_leaderboard == null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: desktop vertical hierarchy not active")
		quit(1)
		return
	if not (desktop_hero.get_global_rect().position.y < desktop_selector.get_global_rect().position.y):
		push_error("JUKEBOX_PANEL_UI_SMOKE: desktop hierarchy is not selected card -> map list")
		quit(1)
		return
	if desktop_hero.custom_minimum_size.x > 980.0:
		push_error("JUKEBOX_PANEL_UI_SMOKE: desktop selected map card should stay compact while hosting leaderboard")
		quit(1)
		return
	if desktop_preview == null or desktop_leaderboard.get_global_rect().position.x <= desktop_preview.get_global_rect().end.x:
		push_error("JUKEBOX_PANEL_UI_SMOKE: desktop leaderboard should sit beside preview")
		quit(1)
		return
	if not _rect_contains_rect(desktop_hero.get_global_rect(), desktop_leaderboard.get_global_rect()):
		push_error("JUKEBOX_PANEL_UI_SMOKE: desktop leaderboard should stay inside selected map card")
		quit(1)
		return

	print("JUKEBOX_PANEL_UI_SMOKE: PASS")
	quit(0)

func _second_map_button(panel: Control, initial_map_path: String) -> Button:
	var container: Node = _map_list(panel)
	if container == null:
		return null
	for child in container.get_children():
		if not (child is Button):
			continue
		var button: Button = child as Button
		if not button.button_pressed:
			return button
	return null

func _category_button(panel: Control, label: String) -> Button:
	var tabs: Node = _category_tabs(panel)
	if tabs == null:
		return null
	for child in tabs.get_children():
		if not (child is Button):
			continue
		var button: Button = child as Button
		if button.text == label:
			return button
	return null

func _first_alternate_category_button(panel: Control) -> Button:
	var tabs: Node = _category_tabs(panel)
	if tabs == null:
		return null
	for child in tabs.get_children():
		if not (child is Button):
			continue
		var button: Button = child as Button
		if button.text != "ALL":
			return button
	return null

func _map_list(panel: Control) -> VBoxContainer:
	return panel.get_node_or_null("VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapList") as VBoxContainer

func _category_tabs(panel: Control) -> Node:
	for path in [
		"VBox/SelectorPanel/SelectorVBox/CategoryTabs",
		"VBox/SelectorPanel/SelectorVBox/CategoryTabsScroll/CategoryTabs"
	]:
		var tabs: Node = panel.get_node_or_null(path)
		if tabs != null:
			return tabs
	return null

func _rect_contains_rect(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x \
		and inner.position.y >= outer.position.y \
		and inner.end.x <= outer.end.x \
		and inner.end.y <= outer.end.y

func _topmost_control_at(node: Node, position: Vector2) -> Control:
	var children: Array[Node] = node.get_children()
	for i in range(children.size() - 1, -1, -1):
		var hit_child: Control = _topmost_control_at(children[i], position)
		if hit_child != null:
			return hit_child
	if node is Control:
		var control: Control = node as Control
		if control.visible \
			and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			and control.get_global_rect().has_point(position):
			return control
	return null
