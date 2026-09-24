extends PanelContainer
## Shared presentation only. Owners retain all entry, matchmaking and launch callbacks.
const Style = preload("res://scripts/ui/menu_surface_style.gd")
const Typography = preload("res://scripts/ui/ui_typography.gd")

var body: VBoxContainer
var scroll: ScrollContainer
var footer: VBoxContainer
var back: Button
var _margin: MarginContainer

func configure(title: Label, back_button: Button, primary: Button = null) -> void:
	name = "JourneyFrame"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", Style.surface(Color("0e1015"), Color("0e1015"), 0))
	_margin = MarginContainer.new()
	add_child(_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_margin.add_child(column)
	adopt(title, column)
	label(title, 60)
	scroll = ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.name = "Content"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	footer = VBoxContainer.new()
	footer.name = "Actions"
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	if primary != null:
		adopt(primary, footer)
		action(primary, true)
	back = back_button
	adopt(back, footer)
	action(back)
	back.custom_minimum_size.y = 144
	resized.connect(_layout)
	_layout()

static func adopt(control: Control, parent: Node) -> void:
	if control.get_parent() == null:
		parent.add_child(control)
	else:
		control.reparent(parent)
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

static func label(control: Label, font_size: int = 38) -> void:
	control.add_theme_font_override("font", Typography.regular_font())
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", Style.TEXT)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func action(button: Button, primary: bool = false) -> void:
	Style.action(button, primary)
	button.custom_minimum_size = Vector2(0, 216 if primary else 168)
	button.add_theme_font_size_override("font_size", 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not back.disabled:
		back.pressed.emit()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree() and is_instance_valid(back) and not back.disabled:
		back.pressed.emit()

func _layout() -> void:
	if _margin == null:
		return
	var top := 0.0
	var bottom := 0.0
	if OS.has_feature("android") or OS.has_feature("ios"):
		var window_size := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var factor := size.y / maxf(1.0, window_size.y)
		top = maxf(0.0, safe.position.y * factor)
		bottom = maxf(0.0, (window_size.y - safe.end.y) * factor)
	_margin.add_theme_constant_override("margin_left", 0)
	_margin.add_theme_constant_override("margin_right", 0)
	_margin.add_theme_constant_override("margin_top", 16 + int(top))
	_margin.add_theme_constant_override("margin_bottom", 12 + int(bottom))
