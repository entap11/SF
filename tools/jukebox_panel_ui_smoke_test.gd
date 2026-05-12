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
	if play_button.icon == null:
		push_error("JUKEBOX_PANEL_UI_SMOKE: play sprite not applied")
		quit(1)
		return
	if play_button.custom_minimum_size.y < 100.0:
		push_error("JUKEBOX_PANEL_UI_SMOKE: play button is too small")
		quit(1)
		return

	print("JUKEBOX_PANEL_UI_SMOKE: PASS")
	quit(0)
