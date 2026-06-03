extends SceneTree

const JukeboxPanelScene: PackedScene = preload("res://scenes/ui/JukeboxPanel.tscn")
const TEST_VIEWPORT_SIZE := Vector2(944.0, 2048.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
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

	var brand_banner: Label = panel.get_node_or_null("VBox/BrandBanner") as Label
	if brand_banner == null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: brand banner missing")
		quit(1)
		return
	if brand_banner.text != "SWARMFRONT":
		push_error("JUKEBOX_PANEL_UI_SMOKE: brand banner text incorrect")
		quit(1)
		return
	if brand_banner.material == null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: brand banner shader material missing")
		quit(1)
		return
	var play_any: Node = panel.get_node_or_null("VBox/HeroPanel/HeroVBox/PlayButton")
	if not (play_any is Button):
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button missing from hero section")
		quit(1)
		return
	var play_button: Button = play_any as Button
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
	var page_label_any: Node = panel.get_node_or_null("VBox/LeaderboardPanel/LeaderboardVBox/LeaderboardNav/LeaderboardPage")
	if not (page_label_any is Label):
		push_error("JUKEBOX_PANEL_UI_SMOKE: leaderboard page label missing")
		quit(1)
		return
	if str((page_label_any as Label).text).strip_edges().is_empty():
		push_error("JUKEBOX_PANEL_UI_SMOKE: leaderboard did not refresh after map click")
		quit(1)
		return
	var top_row: HBoxContainer = panel.get_node_or_null("VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapTopRow") as HBoxContainer
	if top_row == null or top_row.get_child_count() <= 0:
		push_error("JUKEBOX_PANEL_UI_SMOKE: map selector did not populate")
		quit(1)
		return
	var first_card: Button = top_row.get_child(0) as Button
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
	var hero_preview_panel: Control = panel.get_node_or_null("VBox/HeroPanel/HeroVBox/HeroPreviewPanel") as Control
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
	for blocker_path in [
		"VBox/SelectorPanel",
		"VBox/LeaderboardPanel",
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
	var race_tab: Button = _category_button(panel, "RACE")
	if race_tab == null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: RACE category tab missing")
		quit(1)
		return
	race_tab.pressed.emit()
	await process_frame
	await process_frame
	var race_state: Dictionary = panel.call("capture_runtime_state") as Dictionary
	if str(race_state.get("selected_category", "")) != "RACE":
		push_error("JUKEBOX_PANEL_UI_SMOKE: RACE tab did not select category")
		quit(1)
		return
	if not str(race_state.get("selected_map_path", "")).contains("MAP_race__SBASE__1p.json"):
		push_error("JUKEBOX_PANEL_UI_SMOKE: RACE category did not select Race map")
		quit(1)
		return

	print("JUKEBOX_PANEL_UI_SMOKE: PASS")
	quit(0)

func _second_map_button(panel: Control, initial_map_path: String) -> Button:
	var paths: Array[String] = [
		"VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapTopRow",
		"VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapBottomRow/MapBottomCards"
	]
	for path in paths:
		var container: Node = panel.get_node_or_null(path)
		if container == null:
			continue
		for child in container.get_children():
			if not (child is Button):
				continue
			var button: Button = child as Button
			if not button.button_pressed:
				return button
	return null

func _category_button(panel: Control, label: String) -> Button:
	var tabs: Node = panel.get_node_or_null("VBox/SelectorPanel/SelectorVBox/CategoryTabs")
	if tabs == null:
		tabs = panel.get_node_or_null("VBox/SelectorPanel/SelectorVBox/CategoryTabsScroll/CategoryTabs")
	if tabs == null:
		return null
	for child in tabs.get_children():
		if not (child is Button):
			continue
		var button: Button = child as Button
		if button.text == label:
			return button
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
