extends RefCounted

const Typography = preload("res://scripts/ui/ui_typography.gd")
const TEXT := Color("ebedf3")
const MUTED := Color("aeb3c0")
const GOLD := Color("f7ba30")

static func surface(fill: Color, edge: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

static func action(button: Button, primary: bool = false) -> void:
	button.flat = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Typography.regular_font())
	button.add_theme_font_size_override("font_size", Typography.token_size("button", 17, 2.0))
	button.add_theme_color_override("font_color", Color("fff0b8") if primary else TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", surface(Color("242016") if primary else Color("14171f"), Color("ac8432") if primary else Color("424957")))
	button.add_theme_stylebox_override("hover", surface(Color("352b19") if primary else Color("202630"), GOLD if primary else Color("828c9e")))
	button.add_theme_stylebox_override("pressed", surface(Color("49391c") if primary else Color("2b3543"), GOLD if primary else Color("b9c7dd")))
	button.add_theme_stylebox_override("disabled", surface(Color("11141a"), Color("303642")))
	button.add_theme_stylebox_override("focus", surface(Color(0, 0, 0, 0), Color("fff0b8"), 3))
	button.custom_minimum_size.y = 96
