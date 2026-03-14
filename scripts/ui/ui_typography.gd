class_name UITypography
extends RefCounted

const FONT_REGULAR_PATH: String = "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH: String = "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const FONT_FREE_ROLL_ATLAS_PATH: String = "res://assets/fonts/free_roll_display_v2_font.tres"
const FONT_FREE_ROLL_SUPPORTED: String = " ABCDEFGHIJKLMNOPQRSTUVWXYZ01235789"

const SIZE_TOKENS: Dictionary = {
	"screen_title": 24,
	"panel_title": 20,
	"panel_subtitle": 14,
	"body": 13,
	"meta": 11,
	"button": 13
}

static var _regular_font: Font = null
static var _semibold_font: Font = null
static var _free_roll_font: Font = null

static func regular_font() -> Font:
	if _regular_font == null and ResourceLoader.exists(FONT_REGULAR_PATH):
		_regular_font = load(FONT_REGULAR_PATH) as Font
	return _regular_font

static func semibold_font() -> Font:
	if _semibold_font == null and ResourceLoader.exists(FONT_SEMIBOLD_PATH):
		_semibold_font = load(FONT_SEMIBOLD_PATH) as Font
	return _semibold_font

static func free_roll_font() -> Font:
	if _free_roll_font == null and ResourceLoader.exists(FONT_FREE_ROLL_ATLAS_PATH):
		_free_roll_font = load(FONT_FREE_ROLL_ATLAS_PATH) as Font
	return _free_roll_font

static func scaled_size(size: int, scale: float = 1.0) -> int:
	return maxi(1, int(round(float(size) * maxf(0.01, scale))))

static func token_size(token: String, fallback: int = 12, scale: float = 1.0) -> int:
	return scaled_size(int(SIZE_TOKENS.get(token, fallback)), scale)

static func apply_font(control: Control, font: Font, size: int, scale: float = 1.0) -> void:
	if control == null or font == null:
		return
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", scaled_size(size, scale))

static func _control_text(control: Control) -> String:
	if control is Label:
		return (control as Label).text
	if control is BaseButton:
		return (control as BaseButton).text
	return ""

static func sanitize_for_stylized(text: String) -> String:
	var lines: PackedStringArray = text.to_upper().split("\n", false)
	var sanitized_lines: PackedStringArray = PackedStringArray()
	for line in lines:
		var sanitized_line: String = ""
		var last_was_space: bool = false
		for i in line.length():
			var ch: String = line.substr(i, 1)
			var safe_char: String = ch if text_uses_free_roll_charset(ch) else " "
			if safe_char == " ":
				if last_was_space:
					continue
				last_was_space = true
			else:
				last_was_space = false
			sanitized_line += safe_char
		sanitized_lines.append(sanitized_line.strip_edges())
	return "\n".join(sanitized_lines)

static func text_uses_free_roll_charset(text: String) -> bool:
	var source: String = text.to_upper()
	for i in source.length():
		var ch: String = source.substr(i, 1)
		if FONT_FREE_ROLL_SUPPORTED.find(ch) == -1:
			return false
	return true

static func apply_free_roll_atlas_font(control: Control, size: int, scale: float = 1.0) -> bool:
	var atlas_font: Font = free_roll_font()
	if control == null or atlas_font == null:
		return false
	var raw_text: String = _control_text(control)
	if raw_text.is_empty():
		return false
	var upper_text: String = raw_text.to_upper()
	if not text_uses_free_roll_charset(upper_text):
		return false
	if control is Label:
		(control as Label).text = upper_text
	elif control is BaseButton:
		(control as BaseButton).text = upper_text
	control.add_theme_font_override("font", atlas_font)
	control.add_theme_font_size_override("font_size", scaled_size(size, scale))
	return true

static func apply_display_label(control: Control, atlas_size: int, fallback_font: Font, fallback_size: int, scale: float = 1.0) -> void:
	if control == null:
		return
	if not apply_free_roll_atlas_font(control, atlas_size, scale):
		apply_font(control, fallback_font, fallback_size, scale)
