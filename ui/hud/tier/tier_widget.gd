extends Control
class_name TierWidget

const RANK_TITLE_TEXT: String = "Rank"
const RANK_DRONE_OVERLAP_PX: int = 6

@export var rank_state_path: NodePath = NodePath("/root/RankState")
@export var tier_static_label_path: NodePath = NodePath("Content/Row/TierCol/TierStaticLabel")
@export var tier_value_label_path: NodePath = NodePath("Content/Row/TierCol/TierValueLabel")
@export var tier_label_path: NodePath = NodePath("Content/Row/RightCol/TierLabel")
@export var rank_row_path: NodePath = NodePath("Content/Row/RightCol/RankRow")
@export var rank_value_label_path: NodePath = NodePath("Content/Row/RightCol/RankRow/RankValueLabel")
@export var rank_static_label_path: NodePath = NodePath("Content/Row/RightCol/RankRow/RankStaticLabel")
@export var rank_up_flash_path: NodePath = NodePath("RankUpFlash")
@export var rankup_duration_sec: float = 0.20
@export var significant_rank_improvement: int = 10

var _rank_state: Node = null
var _tier_static_label: Label = null
var _tier_value_label: Label = null
var _tier_label: Label = null
var _rank_row: HBoxContainer = null
var _rank_value_label: Label = null
var _rank_static_label: Label = null
var _rank_up_flash: ColorRect = null

var _has_values: bool = false
var _tier_index: int = 0
var _tier_rank: int = 0
var _tier_id: String = "DRONE"
var _flash_tween: Tween = null

func _ready() -> void:
	_resolve_nodes()
	_apply_text_style()
	_bind_rank_state()
	_refresh_from_state(false)

func apply_label_fonts(font: Font, size: int) -> void:
	if font == null:
		return
	var base_size: int = maxi(1, size)
	var tier_size: int = maxi(1, int(round(base_size * 0.72)))
	if _tier_static_label != null:
		_tier_static_label.add_theme_font_override("font", font)
		_tier_static_label.add_theme_font_size_override("font_size", tier_size)
	if _tier_value_label != null:
		_tier_value_label.add_theme_font_override("font", font)
		_tier_value_label.add_theme_font_size_override("font_size", tier_size)
	if _tier_label != null:
		_tier_label.add_theme_font_override("font", font)
		_tier_label.add_theme_font_size_override("font_size", tier_size)
	if _rank_value_label != null:
		_rank_value_label.add_theme_font_override("font", font)
		_rank_value_label.add_theme_font_size_override("font_size", tier_size)
	if _rank_static_label != null:
		_rank_static_label.add_theme_font_override("font", font)
		_rank_static_label.add_theme_font_size_override("font_size", tier_size)
	_sync_rank_anchor_width()

func _resolve_nodes() -> void:
	_tier_static_label = get_node_or_null(tier_static_label_path) as Label
	_tier_value_label = get_node_or_null(tier_value_label_path) as Label
	_tier_label = get_node_or_null(tier_label_path) as Label
	_rank_row = get_node_or_null(rank_row_path) as HBoxContainer
	_rank_value_label = get_node_or_null(rank_value_label_path) as Label
	_rank_static_label = get_node_or_null(rank_static_label_path) as Label
	_rank_up_flash = get_node_or_null(rank_up_flash_path) as ColorRect
	if _rank_up_flash != null:
		_rank_up_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rank_up_flash.modulate = Color(0.56, 1.0, 0.62, 0.0)

func _apply_text_style() -> void:
	for label in [_tier_static_label, _tier_value_label, _tier_label, _rank_value_label, _rank_static_label]:
		if label == null:
			continue
		label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.01, 0.86))
		label.add_theme_constant_override("outline_size", 1)
	if _tier_label != null:
		_tier_label.add_theme_color_override("font_color", Color(0.64, 1.0, 0.70, 1.0))
	if _rank_value_label != null:
		_rank_value_label.add_theme_color_override("font_color", Color(0.64, 1.0, 0.70, 1.0))
	if _rank_static_label != null:
		_rank_static_label.add_theme_color_override("font_color", Color(0.64, 1.0, 0.70, 1.0))

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
	var tier_id: String = str(badge.get("tier_id", "DRONE"))
	_set_values(tier_index, tier_rank, tier_id, allow_anim)

func _on_tier_changed(tier_index: int, tier_rank: int) -> void:
	if _rank_state != null and _rank_state.has_method("get_local_tier_badge"):
		_refresh_from_state(true)
	else:
		_set_values(maxi(0, tier_index), maxi(0, tier_rank), _tier_id, true)

func _on_rank_state_changed(_snapshot: Dictionary) -> void:
	_refresh_from_state(true)

func _set_values(tier_index: int, tier_rank: int, tier_id: String, allow_anim: bool) -> void:
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
	_tier_id = _normalize_tier_id(tier_id)
	_has_values = true
	_update_text()
	if play_rankup:
		_play_rankup_flash()

func _update_text() -> void:
	if _tier_static_label != null:
		_tier_static_label.text = "Tier"
	if _tier_value_label != null:
		_tier_value_label.text = str(_tier_index)
	if _tier_label != null:
		_tier_label.text = RANK_TITLE_TEXT
	if _rank_value_label != null:
		_rank_value_label.text = "--" if _tier_rank <= 0 else str(_tier_rank)
	if _rank_static_label != null:
		_rank_static_label.text = _display_tier_name(_tier_id)
	_sync_rank_anchor_width()

func _sync_rank_anchor_width() -> void:
	if _tier_label == null or _rank_value_label == null:
		return
	var rank_font: Font = _tier_label.get_theme_font("font")
	var rank_font_size: int = _tier_label.get_theme_font_size("font_size")
	if rank_font == null or rank_font_size <= 0:
		return
	var rank_title_width: float = rank_font.get_string_size(RANK_TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font_size).x
	var rank_value_text: String = "--" if _tier_rank <= 0 else str(_tier_rank)
	var value_font: Font = _rank_value_label.get_theme_font("font")
	var value_font_size: int = _rank_value_label.get_theme_font_size("font_size")
	var rank_value_width: float = 0.0
	if value_font != null and value_font_size > 0:
		rank_value_width = value_font.get_string_size(rank_value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, value_font_size).x
	var slot_width: float = ceil(maxf(rank_title_width, rank_value_width)) + 2.0
	_tier_label.custom_minimum_size = Vector2(slot_width, _tier_label.custom_minimum_size.y)
	_rank_value_label.custom_minimum_size = Vector2(slot_width, _rank_value_label.custom_minimum_size.y)
	if _rank_row != null:
		_rank_row.add_theme_constant_override("separation", -RANK_DRONE_OVERLAP_PX)

func _play_rankup_flash() -> void:
	if _rank_up_flash == null:
		return
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	_rank_up_flash.modulate = Color(0.56, 1.0, 0.62, 0.22)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_rank_up_flash, "modulate:a", 0.0, rankup_duration_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _normalize_tier_id(tier_id: String) -> String:
	var clean: String = tier_id.strip_edges().to_upper()
	if clean == "":
		return "DRONE"
	return clean

func _display_tier_name(tier_id: String) -> String:
	match _normalize_tier_id(tier_id):
		"DRONE":
			return "DRONE"
		"WORKER":
			return "WORKER"
		"SOLDIER":
			return "SOLDIER"
		"HONEY_BEE":
			return "HONEY BEE"
		"BUMBLEBEE":
			return "BUMBLEBEE"
		"QUEEN":
			return "QUEEN"
		"YELLOWJACKET":
			return "YELLOWJACKET"
		"RED_WASP":
			return "RED WASP"
		"HORNET":
			return "HORNET"
		"BALD_FACED_HORNET":
			return "BALD-FACED"
		"KILLER_BEE":
			return "KILLER BEE"
		"ASIAN_GIANT_HORNET":
			return "GIANT HORNET"
		"EXECUTIONER_WASP":
			return "EXECUTIONER"
		"SCORPION_WASP":
			return "SCORPION"
		"COW_KILLER":
			return "COW KILLER"
	var fallback: String = _normalize_tier_id(tier_id).replace("_", " ")
	if fallback == "":
		return "DRONE"
	return fallback
