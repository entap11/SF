extends SceneTree

const JukeboxPanelScene: PackedScene = preload("res://scenes/ui/JukeboxPanel.tscn")

func _init() -> void:
	var panel_any: Variant = JukeboxPanelScene.instantiate()
	if not (panel_any is Control):
		push_error("JUKEBOX_PANEL_UI_SMOKE: panel instantiate failed")
		quit(1)
		return
	var panel: Control = panel_any as Control
	get_root().add_child(panel)
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
	var play_any: Node = panel.get_node_or_null("VBox/SelectorPanel/SelectorVBox/PlayButton")
	if not (play_any is Button):
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button missing from selector section")
		quit(1)
		return
	var play_button: Button = play_any as Button
	if panel.get_node_or_null("VBox/HeroPanel/HeroVBox/HeroActions/PlayButton") != null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: stale hero play button still present")
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
	panel.size = Vector2(432.0, 790.0)
	if panel.has_method("_apply_responsive_layout"):
		panel.call("_apply_responsive_layout")
	await process_frame
	if _widest_map_button_right(panel) > 432.0:
		push_error("JUKEBOX_PANEL_UI_SMOKE: narrow Jukebox map buttons overflow right edge")
		quit(1)
		return
	var emitted_payload: Array = []
	if panel.has_signal("play_requested"):
		panel.connect("play_requested", func(map_path: String, cpu_style: String, cpu_tier: String) -> void:
			emitted_payload.append(map_path)
			emitted_payload.append(cpu_style)
			emitted_payload.append(cpu_tier)
		)
	play_button.pressed.emit()
	await process_frame
	if emitted_payload.size() != 3:
		push_error("JUKEBOX_PANEL_UI_SMOKE: play request did not emit")
		quit(1)
		return
	if not str(emitted_payload[1]).is_empty() or not str(emitted_payload[2]).is_empty():
		push_error("JUKEBOX_PANEL_UI_SMOKE: Jukebox play should not emit CPU overrides")
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

func _widest_map_button_right(panel: Control) -> float:
	var max_right: float = 0.0
	var paths: Array[String] = [
		"VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapTopRow",
		"VBox/SelectorPanel/SelectorVBox/MapSelectorRows/MapBottomRow/MapBottomCards"
	]
	for path in paths:
		var container: Node = panel.get_node_or_null(path)
		if container == null:
			continue
		for child in container.get_children():
			if not (child is Control):
				continue
			var control: Control = child as Control
			var rect: Rect2 = control.get_global_rect()
			max_right = maxf(max_right, rect.position.x + rect.size.x)
	return max_right
