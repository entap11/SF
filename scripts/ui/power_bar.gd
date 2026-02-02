class_name PowerBar
extends Control

const SFLog = preload("res://scripts/util/sf_log.gd")

const P1_COLOR: Color = Color(0.85, 0.72, 0.12, 0.95)
const P2_COLOR: Color = Color(0.25, 0.95, 0.35, 0.95)
const P3_COLOR: Color = Color(0.15, 0.45, 0.95, 0.95)
const P4_COLOR: Color = Color(0.95, 0.20, 0.20, 0.95)
const DEFAULT_TOP_PX: float = 10.0

const INNER_LEFT_PX: float = 110.0
const INNER_TOP_PX: float = 22.0
const INNER_W_PX: float = 720.0
const INNER_H_PX: float = 72.0

@export var base_texture: Texture2D
@export var top_margin_px: float = 16.0
@export var height_scale_ratio: float = 0.6
@export var max_width_ratio: float = 0.72
@export var min_scale: float = 0.6
@export var max_scale: float = 1.0
@export var reveal_duration: float = 0.6
@export var reveal_slide_px: float = 6.0

@onready var _fill_mask: Control = $FillMask
@onready var _fill_p1: ColorRect = $FillMask/FillP1
@onready var _fill_p2: ColorRect = $FillMask/FillP2
@onready var _frame: TextureRect = $Frame

var _state: GameState = null
var _target_share_p1: float = 0.5
var _target_share_p2: float = 0.5
var _display_share_p1: float = 0.5
var _display_share_p2: float = 0.5
var _lerp_speed: float = 6.0
var _max_width: float = 0.0
var _base_size: Vector2 = Vector2.ZERO
var _current_top_px: float = DEFAULT_TOP_PX
var _base_offset_top: float = 0.0
var _base_offset_bottom: float = 0.0
var _reveal_tween: Tween = null
var _revealed: bool = false
var _inner_full_pos: Vector2 = Vector2.ZERO
var _inner_full_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000
	if base_texture == null:
		base_texture = _frame.texture
	_ensure_visual_textures()
	_apply_base_size()
	_apply_layout(_current_top_px)
	_prepare_hidden()
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_bind_hud()
	_apply_hud_snapshot(OpsState.get_hud_snapshot())
	_max_width = _fill_mask.size.x
	_apply_fill()
	_enforce_layer_order()
	SFLog.info("POWERBAR_READY_V2", {
		"path": str(get_path()),
		"mask_w": _max_width,
		"fill_mask_path": str(_fill_mask.get_path()),
		"fill_p1_path": str(_fill_p1.get_path()),
		"fill_p2_path": str(_fill_p2.get_path()),
		"frame_path": str(_frame.get_path())
	})
	SFLog.info("POWERBAR_LAYER_OK", {
		"fill_mask_z": _fill_mask.z_index,
		"frame_z": _frame.z_index
	})

func set_state(state_ref: GameState) -> void:
	_state = state_ref

func tick(delta: float, state_ref: GameState) -> void:
	if state_ref != null:
		_state = state_ref

func set_power(pct: float) -> void:
	var p1_ratio: float = clampf(pct, 0.0, 1.0)
	_target_share_p1 = p1_ratio
	_target_share_p2 = 1.0 - p1_ratio

func set_power_ratio(pct: float) -> void:
	set_power(pct)

func _process(delta: float) -> void:
	var t: float = clampf(delta * _lerp_speed, 0.0, 1.0)
	_display_share_p1 = lerpf(_display_share_p1, _target_share_p1, t)
	_display_share_p2 = lerpf(_display_share_p2, _target_share_p2, t)
	_apply_fill()

func pulse_player(_player_index: int, _gain_sign: int) -> void:
	return

func prepare_hidden() -> void:
	_prepare_hidden()

func reveal_with_tween() -> void:
	if _revealed:
		return
	_revealed = true
	# Hard safety
	visible = true
	modulate.a = 1.0
	self_modulate.a = 1.0
	if _reveal_tween != null and _reveal_tween.is_running():
		_reveal_tween.kill()
	modulate.a = 0.0
	_set_slide_offset(-reveal_slide_px)
	_reveal_tween = create_tween()
	_reveal_tween.set_trans(Tween.TRANS_SINE)
	_reveal_tween.set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(self, "modulate:a", 1.0, reveal_duration)
	_reveal_tween.parallel().tween_method(_set_slide_offset, -reveal_slide_px, 0.0, reveal_duration)

func snap_to_play_surface(camera: Camera2D, map_top_world_y: float, margin_px: float = 8.0) -> void:
	if camera == null:
		return
	var top_screen_y: float = camera.project_position(Vector2(0.0, map_top_world_y)).y
	var top: float = top_screen_y + margin_px
	_apply_layout(top)

func _bind_hud() -> void:
	if not OpsState.hud_changed.is_connected(_on_hud_changed):
		OpsState.hud_changed.connect(_on_hud_changed)

func _on_hud_changed(hud: Dictionary) -> void:
	_apply_hud_snapshot(hud)

func _apply_hud_snapshot(hud: Dictionary) -> void:
	var totals: Dictionary = {1: 0.0, 2: 0.0}
	var state_ref: GameState = OpsState.get_state()
	if state_ref != null:
		totals = compute_team_power(state_ref)
	elif hud != null:
		totals[1] = _seat_power_from_hud(hud, 1)
		totals[2] = _seat_power_from_hud(hud, 2)
	_fill_p1.color = P1_COLOR
	_fill_p2.color = P2_COLOR
	apply_power_totals(totals)

func _seat_power_from_hud(hud: Dictionary, seat: int) -> float:
	if hud == null or not hud.has(seat):
		return 0.0
	var entry_any: Variant = hud.get(seat)
	if typeof(entry_any) != TYPE_DICTIONARY:
		return 0.0
	var entry: Dictionary = entry_any as Dictionary
	return float(entry.get("power", 0.0))

func compute_team_power(state_ref: GameState) -> Dictionary:
	var totals: Dictionary = {1: 0.0, 2: 0.0}
	if state_ref == null:
		return totals
	var hive_list: Array = state_ref.hives
	for hive_any in hive_list:
		if hive_any == null:
			continue
		var owner_id: int = 0
		var power: float = 0.0
		if hive_any is HiveData:
			var hive_data: HiveData = hive_any as HiveData
			owner_id = int(hive_data.owner_id)
			power = float(hive_data.power)
		elif typeof(hive_any) == TYPE_DICTIONARY:
			var hive_dict: Dictionary = hive_any as Dictionary
			owner_id = int(hive_dict.get("owner_id", 0))
			power = float(hive_dict.get("power", 0.0))
		if owner_id == 0:
			continue
		if not totals.has(owner_id):
			continue
		totals[owner_id] = float(totals.get(owner_id, 0.0)) + power
	return totals

func apply_power_totals(totals: Dictionary) -> void:
	var p1: float = float(totals.get(1, 0.0))
	var p2: float = float(totals.get(2, 0.0))
	var total: float = p1 + p2
	if total <= 0.0:
		_set_balanced()
		return
	_target_share_p1 = p1 / total
	_target_share_p2 = p2 / total

func _set_balanced() -> void:
	_target_share_p1 = 0.5
	_target_share_p2 = 0.5

func _seat_color(seat: int) -> Color:
	match seat:
		1:
			return P1_COLOR
		2:
			return P2_COLOR
		3:
			return P3_COLOR
		4:
			return P4_COLOR
		_:
			return P1_COLOR

func _on_viewport_size_changed() -> void:
	_apply_layout(_current_top_px)

func _ensure_visual_textures() -> void:
	if base_texture != null:
		_frame.texture = base_texture
	_fill_mask.clip_contents = true
	_fill_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_p1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_p2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_mask.z_index = 0
	_frame.z_index = 100
	_fill_p1.color = P1_COLOR
	_fill_p2.color = P2_COLOR
	move_child(_frame, get_child_count() - 1)

func _apply_base_size() -> void:
	var ref_tex: Texture2D = base_texture
	if ref_tex == null:
		ref_tex = _frame.texture
	if ref_tex == null:
		_base_size = Vector2(960.0, 128.0)
		return
	var tex_size: Vector2 = Vector2(ref_tex.get_width(), ref_tex.get_height())
	var height_ratio: float = clampf(height_scale_ratio, 0.1, 1.0)
	_base_size = Vector2(tex_size.x, tex_size.y * height_ratio)

func _apply_layout(top: float) -> void:
	_current_top_px = top
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0

	var vp_w: float = get_viewport_rect().size.x
	var target_max_w: float = maxf(1.0, vp_w * clampf(max_width_ratio, 0.1, 1.0))
	var base_w: float = maxf(1.0, _base_size.x)
	var base_h: float = maxf(1.0, _base_size.y)

	var fit_scale: float = target_max_w / base_w
	fit_scale = clampf(fit_scale, min_scale, max_scale)

	var fit_size: Vector2 = Vector2(base_w, base_h) * fit_scale
	custom_minimum_size = fit_size
	size = fit_size

	offset_left = -fit_size.x * 0.5
	offset_right = fit_size.x * 0.5
	offset_top = top
	offset_bottom = top + fit_size.y

	_base_offset_top = offset_top
	_base_offset_bottom = offset_bottom

	_frame.anchor_left = 0.0
	_frame.anchor_top = 0.0
	_frame.anchor_right = 1.0
	_frame.anchor_bottom = 1.0
	_frame.offset_left = 0.0
	_frame.offset_top = 0.0
	_frame.offset_right = 0.0
	_frame.offset_bottom = 0.0

	var design_w: float = maxf(1.0, _base_size.x)
	var design_h: float = maxf(1.0, _base_size.y)
	var scale_x: float = size.x / design_w
	var scale_y: float = size.y / design_h

	_inner_full_pos = Vector2(INNER_LEFT_PX * scale_x, INNER_TOP_PX * scale_y)
	_inner_full_size = Vector2(INNER_W_PX * scale_x, INNER_H_PX * scale_y)
	_fill_mask.position = _inner_full_pos
	_fill_mask.size = _inner_full_size
	_max_width = _fill_mask.size.x

	_fill_p1.anchor_left = 0.0
	_fill_p1.anchor_top = 0.0
	_fill_p1.anchor_right = 0.0
	_fill_p1.anchor_bottom = 1.0
	_fill_p1.offset_left = 0.0
	_fill_p1.offset_right = 0.0
	_fill_p1.offset_top = 0.0
	_fill_p1.offset_bottom = 0.0

	_fill_p2.anchor_left = 0.0
	_fill_p2.anchor_top = 0.0
	_fill_p2.anchor_right = 0.0
	_fill_p2.anchor_bottom = 1.0
	_fill_p2.offset_left = 0.0
	_fill_p2.offset_right = 0.0
	_fill_p2.offset_top = 0.0
	_fill_p2.offset_bottom = 0.0

	_apply_fill()

func _apply_fill() -> void:
	if _fill_mask == null or _fill_p1 == null or _fill_p2 == null:
		return
	var left_width: float = _max_width * clampf(_display_share_p1, 0.0, 1.0)
	var right_width: float = maxf(0.0, _max_width - left_width)
	var mask_h: float = _fill_mask.size.y
	_fill_p1.position = Vector2(0.0, 0.0)
	_fill_p1.size = Vector2(left_width, mask_h)
	_fill_p2.position = Vector2(_max_width - right_width, 0.0)
	_fill_p2.size = Vector2(right_width, mask_h)

func _enforce_layer_order() -> void:
	_fill_mask.z_as_relative = false
	_frame.z_as_relative = false
	_fill_p1.z_as_relative = false
	_fill_p2.z_as_relative = false
	_fill_mask.z_index = 0
	_fill_p1.z_index = 0
	_fill_p2.z_index = 0
	_frame.z_index = 100
	move_child(_frame, get_child_count() - 1)
	if has_theme_stylebox_override("panel"):
		remove_theme_stylebox_override("panel")
	if _fill_mask.has_theme_stylebox_override("panel"):
		_fill_mask.remove_theme_stylebox_override("panel")

func _prepare_hidden() -> void:
	_revealed = false
	visible = false
	modulate.a = 0.0
	_set_slide_offset(-reveal_slide_px)

func _set_slide_offset(offset_y: float) -> void:
	offset_top = _base_offset_top + offset_y
	offset_bottom = _base_offset_bottom + offset_y
