extends SceneTree

const AsyncContestDashPanelScript := preload("res://scripts/ui/async_contest_dash_panel.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var panel: Panel = AsyncContestDashPanelScript.new() as Panel
	get_root().add_child(panel)
	await process_frame
	await process_frame
	var scope_buttons: Dictionary = panel.get("_scope_buttons") as Dictionary
	var daily: Button = scope_buttons.get("DAILY") as Button
	if daily == null or not daily.disabled:
		_fail("Daily tab should exist as a disabled hook")
		return
	var map_dropdowns: Array = panel.get("_map_dropdowns") as Array
	if map_dropdowns.size() != 3:
		_fail("expected three stage dropdowns by default")
		return
	var count_buttons: Dictionary = panel.get("_count_buttons") as Dictionary
	var five_button: Button = count_buttons.get(5) as Button
	if five_button == null:
		_fail("5-map tab missing")
		return
	five_button.pressed.emit()
	await process_frame
	map_dropdowns = panel.get("_map_dropdowns") as Array
	if map_dropdowns.size() != 5:
		_fail("expected five stage dropdowns after 5-map tab")
		return
	var bot_dropdown: OptionButton = panel.get("_bot_dropdown") as OptionButton
	var tier_dropdown: OptionButton = panel.get("_tier_dropdown") as OptionButton
	var prize_dropdown: OptionButton = panel.get("_prize_dropdown") as OptionButton
	var randomizer_slider: HSlider = panel.get("_randomizer_slider") as HSlider
	if bot_dropdown == null or tier_dropdown == null or prize_dropdown == null or randomizer_slider == null:
		_fail("expected bot, difficulty, prize, and randomizer controls")
		return
	if randomizer_slider.min_value != 0.0 or randomizer_slider.max_value != 100.0:
		_fail("randomizer slider should be 0-100")
		return
	print("ASYNC_CONTEST_DASH_PANEL_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("ASYNC_CONTEST_DASH_PANEL_SMOKE: %s" % message)
	quit(1)
