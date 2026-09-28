extends CanvasLayer

signal submitted(answers: Dictionary)
signal skipped
signal answers_changed(answers: Dictionary)

const Values := preload("res://scripts/state/beta_feedback_record.gd")
var _choices: Dictionary = {}
var _answers: Dictionary = {}
var _save: Button
var _message: Label
var _body: VBoxContainer
var _initial_experience := "unknown"
var _draft: Dictionary = {}

func configure(experience: String, draft: Dictionary = {}) -> void:
	_initial_experience = experience if experience in Values.VALUES.experience else "unknown"
	_draft = draft.duplicate()

func _ready() -> void:
	layer = 1100
	var background := ColorRect.new()
	background.color = Color("101923")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 54)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 100)
	background.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	_label(column, "HOW WAS THAT GAME?", 52)
	_label(column, "Optional beta feedback", 30)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 22)
	scroll.add_child(_body)
	_question("challenge", "How was the challenge?", ["Too easy", "About right", "Too hard"])
	_question("interesting", "Was the opponent interesting?", ["Yes", "Partly", "No"])
	_question("controls", "Did controls get in the way?", ["Yes", "No", "Unsure"])
	_question("experience", "Your experience with Swarmfront", ["Prefer not to say", "New player", "Some experience", "Experienced"])
	select_answer("experience", _initial_experience)
	_message = _label(column, "Saved with this game. Shared only if beta game sharing is on.", 28)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	var skip := _button(buttons, "SKIP")
	skip.pressed.connect(func() -> void: skipped.emit())
	_save = _button(buttons, "SAVE FEEDBACK")
	_save.disabled = true
	_save.pressed.connect(func() -> void: submitted.emit(_answers.duplicate()))
	for key in _draft:
		select_answer(str(key), str(_draft[key]))

func _question(key: String, title: String, labels: Array) -> void:
	_label(_body, title, 40)
	var grid := GridContainer.new()
	grid.columns = 2 if key == "experience" else 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	_choices[key] = []
	var group := ButtonGroup.new()
	for index in labels.size():
		var button := _button(grid, str(labels[index]))
		button.toggle_mode = true
		button.button_group = group
		_choices[key].append(button)
		button.pressed.connect(select_answer.bind(key, str(Values.VALUES[key][index])))

func select_answer(key: String, value: String) -> void:
	if not Values.VALUES.has(key) or value not in Values.VALUES[key]:
		return
	_answers[key] = value
	for index in _choices.get(key, []).size():
		_choices[key][index].set_pressed_no_signal(Values.VALUES[key][index] == value)
	if _save != null:
		_save.disabled = not Values.valid_answers(_answers)
	answers_changed.emit(_answers.duplicate())

func show_error(message: String) -> void:
	_message.text = message

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 120
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 38)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("1d2b38")
	normal.border_color = Color("536577")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", normal)
	var selected: StyleBoxFlat = normal.duplicate()
	selected.bg_color = Color("314d57")
	selected.border_color = Color("ffda75")
	selected.set_border_width_all(4)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_color_override("font_pressed_color", Color("ffda75"))
	parent.add_child(button)
	return button
