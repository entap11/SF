extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, 0.98)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 64)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	margin.add_child(content)
	var heading := Label.new()
	heading.text = "SAVED ADS"
	heading.add_theme_font_size_override("font_size", 64)
	content.add_child(heading)
	var description := Label.new()
	description.text = "Choose a link to open in your browser."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 44)
	content.add_child(description)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 16)
	scroll.add_child(rows)
	var manager: Node = get_node("/root/AdManager")
	var ads: Array = manager.call("saved_match_ads")
	for index in range(ads.size()):
		var button := Button.new()
		button.text = "OPEN · " + str(ads[index].title)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size.y = 132
		button.add_theme_font_size_override("font_size", 44)
		rows.add_child(button)
		button.pressed.connect(func():
			var result: Dictionary = manager.call("open_saved_match_ad", index)
			if not bool(result.get("ok", false)):
				description.text = "The link could not be opened. Please try again."
		)
	var close := Button.new()
	close.text = "BACK TO RESULTS"
	close.custom_minimum_size.y = 132
	close.add_theme_font_size_override("font_size", 44)
	content.add_child(close)
	close.pressed.connect(queue_free)
	close.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
