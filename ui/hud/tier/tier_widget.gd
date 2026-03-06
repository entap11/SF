extends Control
class_name TierWidget

const HERO_BLOCK_FONT: Font = preload("res://assets/fonts/ChakraPetch-SemiBold.ttf")
const DISPLAY_ATLAS_FONT_PATH: String = "res://assets/fonts/free_roll_display_v2_font.tres"
const DISPLAY_ATLAS_SUPPORTED: String = " ABCDEFGHIJKLMNOPQRSTUVWXYZ01235789"
const HERO_YELLOW_TOP: Color = Color(0.90, 0.74, 0.09, 1.0)
const HERO_YELLOW_BOTTOM: Color = Color(1.0, 0.831, 0.0, 1.0) # #FFD400
const HERO_STROKE: Color = Color(0.44, 0.28, 0.05, 1.0)
const HERO_GLOW: Color = Color(1.0, 0.80, 0.22, 1.0)
const DEFAULT_WIDGET_HEIGHT: float = 200.0

@export var rank_state_path: NodePath = NodePath("/root/RankState")
@export var rank_config_path: String = "res://data/rank/rank_config.tres"
@export var plate_path: NodePath = NodePath("Plate")
@export var tier_title_label_path: NodePath = NodePath("Row/TierColumn/TierTitle")
@export var tier_value_label_path: NodePath = NodePath("Row/TierColumn/TierValue")
@export var tier_name_label_path: NodePath = NodePath("Row/TierColumn/TierName")
@export var rank_title_label_path: NodePath = NodePath("Row/RankColumn/RankTitle")
@export var rank_value_label_path: NodePath = NodePath("Row/RankColumn/RankValue")
@export var rank_up_flash_path: NodePath = NodePath("RankUpFlash")
@export var rankup_duration_sec: float = 0.20
@export var significant_rank_improvement: int = 10

var _rank_state: Node = null
var _plate: Panel = null
var _tier_title_label: Label = null
var _tier_value_label: Label = null
var _tier_name_label: Label = null
var _rank_title_label: Label = null
var _rank_value_label: Label = null
var _rank_up_flash: ColorRect = null

var _has_values: bool = false
var _base_label_font: Font = HERO_BLOCK_FONT
var _display_atlas_font: Font = null
var _tier_index: int = 0
var _tier_rank: int = 0
var _tier_total: int = 0
var _tier_population: int = 0
var _tier_name: String = "Drone"
var _rank_color_id: String = "GREEN"

var _text_materials: Array[ShaderMaterial] = []
var _material_base_inlay: Array[float] = []
var _sweep_tween: Tween = null

func _ready() -> void:
	_resolve_nodes()
	_configure_plate()
	_load_display_atlas_font()
	_apply_hero_font(HERO_BLOCK_FONT, 10)
	_apply_base_typography()
	_prepare_text_materials()
	_bind_rank_state()
	_refresh_from_state(false)

func apply_label_fonts(font: Font, size: int) -> void:
	var selected_font: Font = HERO_BLOCK_FONT
	if font != null:
		selected_font = font
	if selected_font == null:
		return
	_base_label_font = selected_font
	_apply_hero_font(selected_font, maxi(10, size))
	_apply_base_typography()

func _apply_hero_font(font: Font, base_size: int) -> void:
	if font == null:
		return
	var widget_height: float = size.y
	if widget_height < 1.0:
		widget_height = custom_minimum_size.y
	if widget_height < 1.0:
		widget_height = DEFAULT_WIDGET_HEIGHT
	var title_size: int = maxi(11, int(round(widget_height * 0.075)))
	var hinted_title_size: int = maxi(11, int(round(float(base_size) * 0.64)))
	title_size = maxi(title_size, hinted_title_size)
	var tier_name_size: int = maxi(title_size + 1, int(round(widget_height * 0.095)))
	var value_size: int = maxi(title_size + 16, int(round(widget_height * 0.58)))
	var hinted_value_size: int = maxi(title_size + 16, int(round(float(base_size) * 2.10)))
	value_size = maxi(value_size, hinted_value_size)
	for label in [_tier_title_label, _rank_title_label]:
		if label == null:
			continue
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", title_size)
		label.add_theme_constant_override("outline_size", 1)
		label.custom_minimum_size = Vector2(0.0, round(float(title_size) * 0.92))
	for label in [_tier_value_label, _rank_value_label]:
		if label == null:
			continue
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", value_size)
		label.add_theme_constant_override("outline_size", 1)
		label.custom_minimum_size = Vector2(0.0, round(float(value_size) * 0.98))
	if _tier_name_label != null:
		_tier_name_label.add_theme_font_override("font", font)
		_tier_name_label.add_theme_font_size_override("font_size", tier_name_size)
		_tier_name_label.add_theme_constant_override("outline_size", 1)
		_tier_name_label.custom_minimum_size = Vector2(0.0, round(float(tier_name_size) * 0.94))
	_apply_display_fonts(font, title_size, tier_name_size)

func _load_display_atlas_font() -> void:
	if not ResourceLoader.exists(DISPLAY_ATLAS_FONT_PATH):
		return
	_display_atlas_font = load(DISPLAY_ATLAS_FONT_PATH)

func _apply_display_fonts(fallback_font: Font, title_size: int, tier_name_size: int) -> void:
	_apply_display_font_override(_tier_title_label, "TIER", title_size, fallback_font)
	_apply_display_font_override(_rank_title_label, "RANK", title_size, fallback_font)
	var tier_name_text: String = _tier_name.to_upper()
	if _tier_name_label != null and _tier_name_label.text.strip_edges() != "":
		tier_name_text = _tier_name_label.text.to_upper()
	_apply_display_font_override(_tier_name_label, tier_name_text, tier_name_size, fallback_font)

func _apply_display_font_override(label: Label, text: String, size: int, fallback_font: Font) -> void:
	if label == null:
		return
	var use_atlas: bool = _display_atlas_font != null and _text_uses_display_charset(text)
	label.add_theme_font_override("font", _display_atlas_font if use_atlas else fallback_font)
	label.add_theme_font_size_override("font_size", maxi(1, size))

func _text_uses_display_charset(text: String) -> bool:
	var source: String = text.to_upper()
	for i in range(source.length()):
		var ch: String = source.substr(i, 1)
		if DISPLAY_ATLAS_SUPPORTED.find(ch) == -1:
			return false
	return true

func _resolve_nodes() -> void:
	_plate = get_node_or_null(plate_path) as Panel
	_tier_title_label = get_node_or_null(tier_title_label_path) as Label
	_tier_value_label = get_node_or_null(tier_value_label_path) as Label
	_tier_name_label = get_node_or_null(tier_name_label_path) as Label
	_rank_title_label = get_node_or_null(rank_title_label_path) as Label
	_rank_value_label = get_node_or_null(rank_value_label_path) as Label
	_rank_up_flash = get_node_or_null(rank_up_flash_path) as ColorRect

func _configure_plate() -> void:
	if _plate == null:
		return
	var plate_style: StyleBoxFlat = StyleBoxFlat.new()
	plate_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	plate_style.border_width_left = 0
	plate_style.border_width_top = 0
	plate_style.border_width_right = 0
	plate_style.border_width_bottom = 0
	plate_style.content_margin_left = 0
	plate_style.content_margin_top = 0
	plate_style.content_margin_right = 0
	plate_style.content_margin_bottom = 0
	_plate.add_theme_stylebox_override("panel", plate_style)
	if _rank_up_flash != null:
		_rank_up_flash.modulate = Color(1.0, 0.82, 0.42, 0.0)
		_rank_up_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_base_typography() -> void:
	if _tier_title_label != null:
		_tier_title_label.text = "TIER"
	if _rank_title_label != null:
		_rank_title_label.text = "RANK"
	for label in [_tier_title_label, _rank_title_label]:
		if label == null:
			continue
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", HERO_STROKE)
		label.add_theme_color_override("font_shadow_color", Color(0.20, 0.10, 0.02, 0.35))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
	for label in [_tier_value_label, _rank_value_label]:
		if label == null:
			continue
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", HERO_STROKE)
		label.add_theme_color_override("font_shadow_color", Color(0.20, 0.10, 0.02, 0.42))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
	if _tier_name_label != null:
		_tier_name_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84, 1.0))
		_tier_name_label.add_theme_color_override("font_outline_color", HERO_STROKE)
		_tier_name_label.add_theme_color_override("font_shadow_color", Color(0.20, 0.10, 0.02, 0.35))
		_tier_name_label.add_theme_constant_override("shadow_offset_x", 0)
		_tier_name_label.add_theme_constant_override("shadow_offset_y", 0)

func _prepare_text_materials() -> void:
	_text_materials.clear()
	_material_base_inlay.clear()
	_register_label_material(_tier_title_label)
	_register_label_material(_tier_value_label)
	_register_label_material(_rank_title_label)
	_register_label_material(_rank_value_label)
	_apply_sweep_state(-0.3, 0.0, 1.0)

func _register_label_material(label: Label) -> void:
	if label == null:
		return
	var material_any: Variant = label.material
	if not (material_any is ShaderMaterial):
		return
	var unique_mat: ShaderMaterial = (material_any as ShaderMaterial).duplicate() as ShaderMaterial
	label.material = unique_mat
	unique_mat.set_shader_parameter("top_color", HERO_YELLOW_TOP)
	unique_mat.set_shader_parameter("bottom_color", HERO_YELLOW_BOTTOM)
	unique_mat.set_shader_parameter("stroke_color", HERO_STROKE)
	unique_mat.set_shader_parameter("stroke_width", 1.0)
	unique_mat.set_shader_parameter("glow_color", HERO_GLOW)
	unique_mat.set_shader_parameter("glow_strength", 0.22)
	unique_mat.set_shader_parameter("glow_radius", 2.3)
	unique_mat.set_shader_parameter("bevel_strength", 0.20)
	unique_mat.set_shader_parameter("inner_shadow_strength", 0.16)
	var bevel_strength_any: Variant = unique_mat.get_shader_parameter("bevel_strength")
	var base_bevel: float = 0.20
	if typeof(bevel_strength_any) == TYPE_FLOAT or typeof(bevel_strength_any) == TYPE_INT:
		base_bevel = maxf(0.0, float(bevel_strength_any))
	_text_materials.append(unique_mat)
	_material_base_inlay.append(base_bevel)

func _bind_rank_state() -> void:
	_rank_state = get_node_or_null(rank_state_path)
	if _rank_state == null:
		return
	if _rank_state.has_signal("tier_changed"):
		var tier_changed_cb: Callable = Callable(self, "_on_tier_changed")
		if not _rank_state.is_connected("tier_changed", tier_changed_cb):
			_rank_state.connect("tier_changed", tier_changed_cb)
	if _rank_state.has_signal("rank_state_changed"):
		var rank_changed_cb: Callable = Callable(self, "_on_rank_state_changed")
		if not _rank_state.is_connected("rank_state_changed", rank_changed_cb):
			_rank_state.connect("rank_state_changed", rank_changed_cb)

func _refresh_from_state(allow_anim: bool) -> void:
	var metrics: Dictionary = _resolve_rank_metrics()
	_set_values(metrics, allow_anim)

func _on_tier_changed(_tier_index: int, _tier_rank: int) -> void:
	_refresh_from_state(true)

func _on_rank_state_changed(_snapshot: Dictionary) -> void:
	_refresh_from_state(true)

func _resolve_rank_metrics() -> Dictionary:
	var out: Dictionary = {
		"tier_index": 0,
		"tier_rank": 0,
		"tier_total": _resolve_total_tiers(),
		"tier_population": 0,
		"tier_id": "DRONE",
		"tier_name": "Drone",
		"color_id": "GREEN"
	}
	if _rank_state == null:
		return out
	if _rank_state.has_method("get_local_tier_badge"):
		var badge_any: Variant = _rank_state.call("get_local_tier_badge")
		if typeof(badge_any) == TYPE_DICTIONARY:
			var badge: Dictionary = badge_any as Dictionary
			out["tier_index"] = maxi(0, int(badge.get("tier_index", 0)))
			out["tier_rank"] = maxi(0, int(badge.get("tier_rank", 0)))
			out["tier_id"] = str(badge.get("tier_id", out["tier_id"])).strip_edges().to_upper()
	var local_player_id: String = ""
	if _rank_state.has_method("get_local_rank_view"):
		var board_any: Variant = _rank_state.call("get_local_rank_view", "GLOBAL", 100000)
		if typeof(board_any) == TYPE_DICTIONARY:
			var board: Dictionary = board_any as Dictionary
			local_player_id = str(board.get("local_player_id", "")).strip_edges()
			var local_context_any: Variant = board.get("local_context", {})
			if typeof(local_context_any) == TYPE_DICTIONARY:
				var local_context: Dictionary = local_context_any as Dictionary
				out["color_id"] = str(local_context.get("color_id", out["color_id"])).strip_edges().to_upper()
				out["tier_id"] = str(local_context.get("tier_id", out["tier_id"])).strip_edges().to_upper()
			var rows_any: Variant = board.get("rows", [])
			if typeof(rows_any) == TYPE_ARRAY:
				var rows: Array = rows_any as Array
				var tier_id: String = str(out.get("tier_id", "DRONE")).strip_edges().to_upper()
				var tier_rank_running: int = 0
				var local_rank_in_tier: int = int(out.get("tier_rank", 0))
				var tier_population: int = 0
				for row_any in rows:
					if typeof(row_any) != TYPE_DICTIONARY:
						continue
					var row: Dictionary = row_any as Dictionary
					var row_tier: String = str(row.get("tier_id", "")).strip_edges().to_upper()
					if row_tier != tier_id:
						continue
					tier_population += 1
					tier_rank_running += 1
					if local_player_id != "" and str(row.get("player_id", "")) == local_player_id:
						local_rank_in_tier = tier_rank_running
						out["color_id"] = str(row.get("color_id", out["color_id"])).strip_edges().to_upper()
				out["tier_population"] = tier_population
				if local_rank_in_tier > 0:
					out["tier_rank"] = local_rank_in_tier
	if local_player_id != "" and _rank_state.has_method("get_player_snapshot"):
		var player_any: Variant = _rank_state.call("get_player_snapshot", local_player_id)
		if typeof(player_any) == TYPE_DICTIONARY:
			var player: Dictionary = player_any as Dictionary
			out["color_id"] = str(player.get("color_id", out["color_id"])).strip_edges().to_upper()
	if int(out.get("tier_population", 0)) <= 0:
		out["tier_population"] = maxi(0, int(out.get("tier_rank", 0)))
	out["tier_name"] = _resolve_tier_name(str(out.get("tier_id", "DRONE")))
	return out

func _resolve_total_tiers() -> int:
	if not ResourceLoader.exists(rank_config_path):
		return 0
	var cfg_any: Variant = load(rank_config_path)
	if cfg_any == null:
		return 0
	if cfg_any.has_method("ordered_tier_ids"):
		var tiers_any: Variant = cfg_any.call("ordered_tier_ids")
		if typeof(tiers_any) == TYPE_ARRAY:
			return maxi(0, (tiers_any as Array).size())
	var bands_any: Variant = cfg_any.get("tier_bands")
	if typeof(bands_any) == TYPE_ARRAY:
		return maxi(0, (bands_any as Array).size())
	return 0

func _set_values(metrics: Dictionary, allow_anim: bool) -> void:
	var tier_index: int = maxi(0, int(metrics.get("tier_index", 0)))
	var tier_rank: int = maxi(0, int(metrics.get("tier_rank", 0)))
	var tier_total: int = maxi(0, int(metrics.get("tier_total", 0)))
	var tier_population: int = maxi(0, int(metrics.get("tier_population", 0)))
	var tier_name: String = str(metrics.get("tier_name", "Drone")).strip_edges()
	var color_id: String = str(metrics.get("color_id", "GREEN")).strip_edges().to_upper()

	var play_rankup: bool = false
	if _has_values and allow_anim:
		if tier_index > _tier_index:
			play_rankup = true
		elif tier_index == _tier_index and _tier_rank > 0 and tier_rank > 0:
			var gain: int = _tier_rank - tier_rank
			if gain >= significant_rank_improvement:
				play_rankup = true

	_tier_index = tier_index
	_tier_rank = tier_rank
	_tier_total = tier_total
	_tier_population = tier_population
	_tier_name = tier_name if tier_name != "" else "Drone"
	_rank_color_id = color_id
	_has_values = true
	_update_text()
	if play_rankup:
		_play_rankup_sweep()

func _update_text() -> void:
	if _tier_title_label != null:
		_tier_title_label.text = "TIER"
	if _rank_title_label != null:
		_rank_title_label.text = "RANK"
	if _tier_value_label != null:
		_tier_value_label.text = str(maxi(0, _tier_index))
	if _tier_name_label != null:
		_tier_name_label.text = _tier_name.to_upper()
	if _rank_value_label != null:
		_rank_value_label.text = str(maxi(0, _tier_rank))
	_apply_display_fonts(_base_label_font, _tier_title_label.get_theme_font_size("font_size") if _tier_title_label != null else 12, _tier_name_label.get_theme_font_size("font_size") if _tier_name_label != null else 14)
	_apply_shader_palette(_tier_value_label, _hero_value_palette())
	_apply_shader_palette(_rank_value_label, _rank_value_palette(_rank_color_id))

func _apply_shader_palette(label: Label, palette: Dictionary) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	var material_any: Variant = label.material
	if material_any is ShaderMaterial:
		var mat: ShaderMaterial = material_any as ShaderMaterial
		mat.set_shader_parameter("top_color", palette.get("top", HERO_YELLOW_TOP))
		mat.set_shader_parameter("bottom_color", palette.get("bottom", HERO_YELLOW_BOTTOM))
		mat.set_shader_parameter("stroke_color", palette.get("stroke", HERO_STROKE))
		mat.set_shader_parameter("glow_color", palette.get("glow", HERO_GLOW))

func _hero_value_palette() -> Dictionary:
	return {
		"top": HERO_YELLOW_TOP,
		"bottom": HERO_YELLOW_BOTTOM,
		"stroke": HERO_STROKE,
		"glow": HERO_GLOW
	}

func _rank_value_palette(color_id: String) -> Dictionary:
	var rank_base: Color = _rank_color_for_id(color_id)
	return {
		"top": rank_base.lightened(0.26),
		"bottom": rank_base.darkened(0.12),
		"stroke": rank_base.darkened(0.55),
		"glow": rank_base.lightened(0.20)
	}

func _rank_color_for_id(color_id: String) -> Color:
	match color_id.strip_edges().to_upper():
		"YELLOW":
			return Color(1.0, 0.90, 0.38, 1.0)
		"RED":
			return Color(1.0, 0.37, 0.28, 1.0)
		"GREEN":
			return Color(0.47, 1.0, 0.49, 1.0)
		"BLUE":
			return Color(0.48, 0.78, 1.0, 1.0)
		"BLACK":
			# Keep it readable on dark UI while honoring the black tier band.
			return Color(0.85, 0.88, 0.95, 1.0)
		_:
			return Color(0.98, 0.96, 0.90, 1.0)

func _resolve_tier_name(tier_id: String) -> String:
	if not ResourceLoader.exists(rank_config_path):
		return "Drone"
	var cfg_any: Variant = load(rank_config_path)
	if cfg_any == null:
		return "Drone"
	if cfg_any.has_method("tier_name"):
		return str(cfg_any.call("tier_name", tier_id))
	return tier_id.strip_edges().replace("_", " ").capitalize()

func _play_rankup_sweep() -> void:
	if _sweep_tween != null and _sweep_tween.is_running():
		_sweep_tween.kill()
	_sweep_tween = create_tween()
	_apply_sweep_state(-0.2, 0.9, 1.35)
	_sweep_tween.tween_method(Callable(self, "_set_sweep_position"), -0.2, 1.2, rankup_duration_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sweep_tween.parallel().tween_method(Callable(self, "_set_sweep_strength"), 0.9, 0.0, rankup_duration_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sweep_tween.parallel().tween_method(Callable(self, "_set_inlay_multiplier"), 1.35, 1.0, rankup_duration_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _rank_up_flash != null:
		_rank_up_flash.modulate = Color(1.0, 0.82, 0.42, 0.20)
		_sweep_tween.parallel().tween_property(_rank_up_flash, "modulate:a", 0.0, rankup_duration_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sweep_tween.finished.connect(func() -> void:
		_apply_sweep_state(-0.3, 0.0, 1.0)
	)

func _set_sweep_position(value: float) -> void:
	_apply_sweep_state(value, _current_sweep_strength(), _current_inlay_multiplier())

func _set_sweep_strength(value: float) -> void:
	_apply_sweep_state(_current_sweep_position(), value, _current_inlay_multiplier())

func _set_inlay_multiplier(value: float) -> void:
	_apply_sweep_state(_current_sweep_position(), _current_sweep_strength(), value)

func _current_sweep_position() -> float:
	if _text_materials.is_empty():
		return -0.3
	var value_any: Variant = _text_materials[0].get_shader_parameter("sweep_pos")
	if typeof(value_any) == TYPE_FLOAT or typeof(value_any) == TYPE_INT:
		return value_any
	return -0.3

func _current_sweep_strength() -> float:
	if _text_materials.is_empty():
		return 0.0
	var value_any: Variant = _text_materials[0].get_shader_parameter("sweep_strength")
	if typeof(value_any) == TYPE_FLOAT or typeof(value_any) == TYPE_INT:
		return value_any
	return 0.0

func _current_inlay_multiplier() -> float:
	if _text_materials.is_empty() or _material_base_inlay.is_empty():
		return 1.0
	var current_any: Variant = _text_materials[0].get_shader_parameter("bevel_strength")
	var current: float = 0.20
	if typeof(current_any) == TYPE_FLOAT or typeof(current_any) == TYPE_INT:
		current = current_any
	var base: float = _material_base_inlay[0]
	if is_zero_approx(base):
		return 1.0
	return current / base

func _apply_sweep_state(position: float, strength: float, inlay_multiplier: float) -> void:
	for idx in range(_text_materials.size()):
		var mat: ShaderMaterial = _text_materials[idx]
		if mat == null:
			continue
		mat.set_shader_parameter("sweep_pos", position)
		mat.set_shader_parameter("sweep_strength", strength)
		var base_bevel: float = _material_base_inlay[idx] if idx < _material_base_inlay.size() else 0.20
		mat.set_shader_parameter("bevel_strength", base_bevel * inlay_multiplier)
