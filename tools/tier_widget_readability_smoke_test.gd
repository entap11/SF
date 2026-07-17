extends SceneTree

const WIDGET_SCENE: PackedScene = preload("res://ui/hud/tier/tier_widget.tscn")
const TYPOGRAPHY := preload("res://scripts/ui/ui_typography.gd")
const EXPECTED_YELLOW: Color = Color(1.0, 0.831, 0.0, 1.0)

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var widget: Control = WIDGET_SCENE.instantiate() as Control
	root.add_child(widget)
	widget.size = Vector2(415.0, 200.0)
	for _frame in range(3):
		await process_frame

	var title_floor: int = TYPOGRAPHY.token_size("section_title", 18, TYPOGRAPHY.PORTRAIT_CANVAS_SCALE)
	var body_floor: int = TYPOGRAPHY.token_size("body", 16, TYPOGRAPHY.PORTRAIT_CANVAS_SCALE)
	for path in ["Row/TierColumn/TierTitle", "Row/RankColumn/RankTitle"]:
		var label: Label = widget.get_node(path) as Label
		_expect(label.get_theme_font_size("font_size") >= title_floor, "%s is below the section-title floor" % path)
	for path in ["Row/TierColumn/TierValue", "Row/RankColumn/RankValue"]:
		var label: Label = widget.get_node(path) as Label
		_expect(label.get_theme_font_size("font_size") >= body_floor, "%s is below the body/value floor" % path)
		_expect(label.material is ShaderMaterial, "%s must retain its emissive forged material" % path)
		if label.material is ShaderMaterial:
			var material: ShaderMaterial = label.material as ShaderMaterial
			var bottom: Color = material.get_shader_parameter("bottom_color") as Color
			_expect(bottom.is_equal_approx(EXPECTED_YELLOW), "%s must use honey yellow" % path)
			_expect(float(material.get_shader_parameter("glow_strength")) >= 0.4, "%s glow is too weak for the requested emissive treatment" % path)

	var tier_name: Label = widget.get_node("Row/TierColumn/TierName") as Label
	_expect(tier_name.get_theme_font_size("font_size") >= body_floor, "Tier name is below the body-text floor")
	var tier_title: Label = widget.get_node("Row/TierColumn/TierTitle") as Label
	var rank_title: Label = widget.get_node("Row/RankColumn/RankTitle") as Label
	var tier_value: Label = widget.get_node("Row/TierColumn/TierValue") as Label
	var rank_value_default: Label = widget.get_node("Row/RankColumn/RankValue") as Label
	_expect(is_equal_approx(tier_title.position.y, rank_title.position.y), "Tier and Rank titles should share a row")
	_expect(is_equal_approx(tier_value.position.y, rank_value_default.position.y), "Tier and Rank values should share a row")
	_expect(tier_name.position.y >= tier_title.position.y + tier_title.size.y - 0.5, "Tier name should follow the TIER title")
	_expect(tier_name.position.y + tier_name.size.y <= tier_value.position.y + 0.5, "Tier name should sit between TIER and its value")
	for path in ["Row/TierColumn", "Row/RankColumn"]:
		var target: Control = widget.get_node(path) as Control
		_expect(target.size.y >= TYPOGRAPHY.PORTRAIT_TOUCH_HEIGHT, "%s is below the touch-height floor" % path)

	# A five-digit in-tier rank is a realistic stress case and must shrink without
	# falling below the declared body floor or clipping its half of the widget.
	widget.call("_set_values", {
		"tier_index": 19,
		"tier_rank": 99999,
		"tier_total": 19,
		"tier_population": 99999,
		"tier_name": "Yellowjacket",
		"color_id": "YELLOW"
	}, false)
	for _frame in range(2):
		await process_frame
	var rank_value: Label = widget.get_node("Row/RankColumn/RankValue") as Label
	var rank_font_size: int = rank_value.get_theme_font_size("font_size")
	var rank_text_width: float = rank_value.get_theme_font("font").get_string_size(rank_value.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, rank_font_size).x
	_expect(rank_font_size >= body_floor, "Five-digit rank shrank below the body/value floor")
	_expect(rank_text_width <= rank_value.size.x, "Five-digit rank clips its value column")
	var long_tier_name: Label = widget.get_node("Row/TierColumn/TierName") as Label
	var tier_name_font_size: int = long_tier_name.get_theme_font_size("font_size")
	var tier_name_text_width: float = long_tier_name.get_theme_font("font").get_string_size(long_tier_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tier_name_font_size).x
	_expect(tier_name_font_size >= body_floor, "Long tier name shrank below the body floor")
	_expect(tier_name_text_width <= long_tier_name.size.x, "Long tier name clips its column (text %.1f, column %.1f)" % [tier_name_text_width, long_tier_name.size.x])
	var stressed_tier_value: Label = widget.get_node("Row/TierColumn/TierValue") as Label
	_expect(is_equal_approx(stressed_tier_value.position.y, rank_value.position.y), "Value rows should stay aligned after rank fitting (tier %.1f, rank %.1f)" % [stressed_tier_value.position.y, rank_value.position.y])
	for path in ["Row/TierColumn/TierTitle", "Row/TierColumn/TierValue", "Row/TierColumn/TierName", "Row/RankColumn/RankTitle", "Row/RankColumn/RankValue"]:
		var label: Label = widget.get_node(path) as Label
		_expect(widget.get_global_rect().encloses(label.get_global_rect()), "%s escapes the widget bounds" % path)

	# The solid yellow fill, not its glow, must satisfy the large-text contrast floor.
	var contrast: float = _contrast_ratio(EXPECTED_YELLOW, Color(0.035, 0.039, 0.047, 1.0))
	_expect(contrast >= 3.0, "Yellow value fill does not reach 3:1 contrast (%.2f:1)" % contrast)

	widget.queue_free()
	if _failed:
		quit(1)
	else:
		print("TIER_WIDGET_READABILITY_SMOKE: PASS (yellow contrast %.2f:1)" % contrast)
		quit(0)

func _contrast_ratio(foreground: Color, background: Color) -> float:
	var foreground_luminance: float = _relative_luminance(foreground)
	var background_luminance: float = _relative_luminance(background)
	return (maxf(foreground_luminance, background_luminance) + 0.05) / (minf(foreground_luminance, background_luminance) + 0.05)

func _relative_luminance(color: Color) -> float:
	return 0.2126 * _linear_channel(color.r) + 0.7152 * _linear_channel(color.g) + 0.0722 * _linear_channel(color.b)

func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("TIER_WIDGET_READABILITY_SMOKE: %s" % message)
