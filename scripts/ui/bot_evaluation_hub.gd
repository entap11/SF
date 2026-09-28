extends Control

var status: Label

func _ready() -> void:
	var cover := get_node_or_null("/root/MainMenuLoadingCoordinator")
	if cover != null:
		cover.call("hide_immediately")
	var background := ColorRect.new()
	background.color = Color("101923")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 210)
	add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 38)
	margin.add_child(column)
	_label(column, "BOT PLAYTEST", 64, Color("ffda75"))
	_label(column, "Simple Syrup", 52)
	_label(column, "You start at the bottom.\nMedium difficulty · No buffs\nPlay one game, or both if you have time.", 34)
	_button(column, "GAME 1 · BALANCER CPU", 0)
	_button(column, "GAME 2 · RAIDER CPU (OPTIONAL)", 1)
	status = _label(column, "Games save automatically on this phone.", 30)
	if not BotEvaluationSession.last_save.is_empty():
		status.text = "Recording saved. Thank you!" if bool(BotEvaluationSession.last_save.get("ok", false)) else "Recording could not be saved. Keep the app open."
	_label(column, "After playing, tell me one move that felt\nclever, strange, or too easy.", 32)
	_label(column, "Playtest · September 28 · Build 2026092801", 24, Color("99aabb"))

func _label(parent: Node, value: String, size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, game: int) -> void:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 135
	button.add_theme_font_size_override("font_size", 36)
	button.disabled = not BotEvaluationSession.enabled()
	button.pressed.connect(func() -> void:
		var result: Dictionary = BotEvaluationSession.request_launch(game)
		if not bool(result.get("ok", false)):
			status.text = str(result.get("error", "Could not start."))
	)
	parent.add_child(button)
