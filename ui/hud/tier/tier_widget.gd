extends Control
class_name TierWidget

@export var rank_state_path: NodePath = NodePath("/root/RankState")
@export var plate_path: NodePath = NodePath("Plate")
@export var tier_label_path: NodePath = NodePath("HBox/TierLabel")
@export var hex_icon_path: NodePath = NodePath("HBox/HexIcon")
@export var hex_label_path: NodePath = NodePath("HBox/HexLabel")
@export var rank_label_path: NodePath = NodePath("HBox/RankLabel")
@export var rank_up_flash_path: NodePath = NodePath("RankUpFlash")
@export var hex_icon_texture_path: String = "res://ui/hud/tier/hex_separator.png"
@export var hex_fallback_glyph: String = "⬡"
@export var hex_fallback_dot: String = "·"
@export var rankup_duration_sec: float = 0.20
@export var significant_rank_improvement: int = 10

var _rank_state: Node = null
var _plate: Panel = null
var _tier_label: Label = null
var _hex_icon: TextureRect = null
var _hex_label: Label = null
var _rank_label: Label = null
var _rank_up_flash: ColorRect = null

var _has_values: bool = false
var _tier_index: int = 0
var _tier_rank: int = 0

var _text_materials: Array[ShaderMaterial] = []
var _material_base_inlay: Array[float] = []
var _sweep_tween: Tween = null

func _ready() -> void:
	_resolve_nodes()
	_configure_plate()
	_prepare_text_materials()
	_resolve_separator_visual()
	_bind_rank_state()
	_refresh_from_state(false)

func apply_label_fonts(font: Font, size: int) -> void:
	if font == null:
		return
	if _tier_label != null:
		_tier_label.add_theme_font_override("font", font)
		_tier_label.add_theme_font_size_override("font_size", maxi(1, size))
	if _rank_label != null:
		_rank_label.add_theme_font_override("font", font)
		_rank_label.add_theme_font_size_override("font_size", maxi(1, size))
	if _hex_label != null:
		_hex_label.add_theme_font_override("font", font)
		_hex_label.add_theme_font_size_override("font_size", maxi(1, int(round(size * 0.86))))
	_resolve_separator_glyph()

func _resolve_nodes() -> void:
	_plate = get_node_or_null(plate_path) as Panel
	_tier_label = get_node_or_null(tier_label_path) as Label
	_hex_icon = get_node_or_null(hex_icon_path) as TextureRect
	_hex_label = get_node_or_null(hex_label_path) as Label
	_rank_label = get_node_or_null(rank_label_path) as Label
	_rank_up_flash = get_node_or_null(rank_up_flash_path) as ColorRect

func _configure_plate() -> void:
	if _plate == null:
		return
	var plate_style: StyleBoxFlat = StyleBoxFlat.new()
	plate_style.bg_color = Color(0.09, 0.10, 0.12, 0.84)
	plate_style.border_width_left = 1
	plate_style.border_width_top = 1
	plate_style.border_width_right = 1
	plate_style.border_width_bottom = 1
	plate_style.border_color = Color(0.74, 0.47, 0.12, 0.38)
	plate_style.corner_radius_top_left = 6
	plate_style.corner_radius_top_right = 6
	plate_style.corner_radius_bottom_right = 6
	plate_style.corner_radius_bottom_left = 6
	plate_style.content_margin_left = 8
	plate_style.content_margin_top = 2
	plate_style.content_margin_right = 8
	plate_style.content_margin_bottom = 2
	_plate.add_theme_stylebox_override("panel", plate_style)
	if _rank_up_flash != null:
		_rank_up_flash.modulate = Color(1.0, 0.78, 0.35, 0.0)
		_rank_up_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _prepare_text_materials() -> void:
	_text_materials.clear()
	_material_base_inlay.clear()
	_register_label_material(_tier_label)
	_register_label_material(_rank_label)
	_register_label_material(_hex_label)
	_apply_sweep_state(-0.3, 0.0, 1.0)

func _register_label_material(label: Label) -> void:
	if label == null:
		return
	var material_any: Variant = label.material
	if not (material_any is ShaderMaterial):
		return
	var unique_mat: ShaderMaterial = (material_any as ShaderMaterial).duplicate() as ShaderMaterial
	label.material = unique_mat
	_text_materials.append(unique_mat)
	var inlay_strength_any: Variant = unique_mat.get_shader_parameter("inlay_strength")
	var inlay_strength: float = 0.55
	if typeof(inlay_strength_any) == TYPE_FLOAT or typeof(inlay_strength_any) == TYPE_INT:
		inlay_strength = inlay_strength_any
	_material_base_inlay.append(inlay_strength)

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
	if _rank_state == null:
		return
	if not _rank_state.has_method("get_local_tier_badge"):
		return
	var badge_any: Variant = _rank_state.call("get_local_tier_badge")
	if typeof(badge_any) != TYPE_DICTIONARY:
		return
	var badge: Dictionary = badge_any as Dictionary
	var tier_index: int = maxi(0, int(badge.get("tier_index", 0)))
	var tier_rank: int = maxi(0, int(badge.get("tier_rank", 0)))
	_set_values(tier_index, tier_rank, allow_anim)

func _on_tier_changed(tier_index: int, tier_rank: int) -> void:
	_set_values(maxi(0, tier_index), maxi(0, tier_rank), true)

func _on_rank_state_changed(_snapshot: Dictionary) -> void:
	_refresh_from_state(true)

func _set_values(tier_index: int, tier_rank: int, allow_anim: bool) -> void:
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
	_has_values = true
	_update_text()
	if play_rankup:
		_play_rankup_sweep()

func _update_text() -> void:
	if _tier_label != null:
		_tier_label.text = "T%d" % _tier_index
	if _rank_label != null:
		_rank_label.text = str(_tier_rank)

func _resolve_separator_visual() -> void:
	var icon_tex: Texture2D = null
	if ResourceLoader.exists(hex_icon_texture_path):
		var loaded_any: Variant = load(hex_icon_texture_path)
		if loaded_any is Texture2D:
			icon_tex = loaded_any as Texture2D
	if icon_tex != null and _hex_icon != null:
		_hex_icon.texture = icon_tex
		_hex_icon.modulate = Color(0.86, 0.62, 0.18, 0.85)
		_hex_icon.visible = true
		if _hex_label != null:
			_hex_label.visible = false
	else:
		if _hex_icon != null:
			_hex_icon.visible = false
		if _hex_label != null:
			_hex_label.visible = true
			_resolve_separator_glyph()

func _resolve_separator_glyph() -> void:
	if _hex_label == null:
		return
	var glyph: String = hex_fallback_glyph
	var font_any: Variant = _hex_label.get_theme_font("font")
	if font_any is Font:
		var font_ref: Font = font_any as Font
		if font_ref.has_char(hex_fallback_glyph.unicode_at(0)) == false:
			glyph = hex_fallback_dot
	_hex_label.text = glyph

func _play_rankup_sweep() -> void:
	if _sweep_tween != null and _sweep_tween.is_running():
		_sweep_tween.kill()
	_sweep_tween = create_tween()
	_apply_sweep_state(-0.2, 0.9, 1.35)
	_sweep_tween.tween_method(Callable(self, "_set_sweep_position"), -0.2, 1.2, rankup_duration_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sweep_tween.parallel().tween_method(Callable(self, "_set_sweep_strength"), 0.9, 0.0, rankup_duration_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sweep_tween.parallel().tween_method(Callable(self, "_set_inlay_multiplier"), 1.35, 1.0, rankup_duration_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _rank_up_flash != null:
		_rank_up_flash.modulate = Color(1.0, 0.78, 0.35, 0.22)
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
	var current_any: Variant = _text_materials[0].get_shader_parameter("inlay_strength")
	var current: float = 0.55
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
		var base_inlay: float = _material_base_inlay[idx] if idx < _material_base_inlay.size() else 0.55
		mat.set_shader_parameter("inlay_strength", base_inlay * inlay_multiplier)
