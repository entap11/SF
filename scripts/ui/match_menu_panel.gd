extends Control

signal closed
signal leave_requested

var warning_text := ""
var finished := false
var _body: Label
var _leave: Button
var _resume: Button
var _confirming := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(880, get_viewport_rect().size.x - 64)
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101720")
	style.border_color = Color("d9b95d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	panel.add_child(content)
	var title := Label.new()
	title.text = "MATCH MENU"
	title.add_theme_font_size_override("font_size", 64)
	content.add_child(title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = panel.custom_minimum_size.x - 64
	_body.add_theme_font_size_override("font_size", 46)
	_body.text = "The match keeps running while this menu is open." if not finished else "Match complete."
	content.add_child(_body)
	_resume = _button(content, "BACK TO GAME", func(): closed.emit())
	_leave = _button(content, "LEAVE MATCH", _on_leave)
	_resume.grab_focus()

func _button(parent: Node, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 132
	button.add_theme_font_size_override("font_size", 44)
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _on_leave() -> void:
	if not _confirming and not finished:
		_confirming = true
		_body.text = warning_text
		_leave.text = "YES, LEAVE MATCH"
		_resume.text = "NO, KEEP PLAYING"
		_resume.grab_focus()
		return
	_leave.disabled = true
	leave_requested.emit()

func show_failure() -> void:
	_body.text = "Could not confirm your exit with the match service. You're still in this match. Try again or keep playing."
	_leave.disabled = false
	_leave.text = "TRY AGAIN"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
