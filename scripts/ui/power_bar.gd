class_name PowerBar
extends Control

const SFLog = preload("res://scripts/util/sf_log.gd")

const P1_COLOR: Color = Color(0.85, 0.72, 0.12, 0.95)
const P2_COLOR: Color = Color(0.25, 0.95, 0.35, 0.95)
const P3_COLOR: Color = Color(0.15, 0.45, 0.95, 0.95)
const P4_COLOR: Color = Color(0.95, 0.20, 0.20, 0.95)
const PLAYER_COLORS: Array[Color] = [P1_COLOR, P2_COLOR, P3_COLOR, P4_COLOR]

@export var base_texture: Texture2D
@export var top_margin_px: float = 16.0
@export var height_scale_ratio: float = 0.6
@export var max_width_ratio: float = 0.72
@export var min_scale: float = 0.6
@export var max_scale: float = 1.0
@export var poll_hz: float = 8.0
@export var sample_interval_sec: float = 0.5
@export var history_samples: int = 10
@export var fill_inset_left: float = 6.0
@export var fill_inset_right: float = 6.0
@export var fill_inset_top: float = 6.0
@export var fill_inset_bottom: float = 6.0
@export var pulse_duration: float = 0.25
@export var pulse_expand_px: float = 6.0
@export var ghost_alpha: float = 0.28
@export var reveal_duration: float = 0.6
@export var reveal_slide_px: float = 6.0

@onready var frame: TextureRect = $Frame
@onready var fill_layer: Control = $FillLayer
@onready var ghost_layer: Control = $FillLayer/Ghosts
@onready var fill_layer_main: Control = $FillLayer/Fills

var _state: GameState = null
var _fill_nodes: Array[Control] = []
var _ghost_nodes: Array[Control] = []
var _visible_count: int = 4
var _current_shares: Array[float] = [0.25, 0.25, 0.25, 0.25]
var _ghost_shares: Array[float] = [0.25, 0.25, 0.25, 0.25]
var _history: Array = [[], [], [], []] # each entry is Array[float]
var _sample_accum: float = 0.0
var _poll_accum: float = 0.0
var _pulse_t: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _pulse_sign: Array[int] = [1, 1, 1, 1]
var _state_sig: String = ""
var _base_offset_top: float = 0.0
var _base_offset_bottom: float = 0.0
var _reveal_tween: Tween = null
var _revealed: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)
	z_index = 1000
	if base_texture == null and frame.texture != null:
		base_texture = frame.texture
	elif base_texture != null:
		frame.texture = base_texture
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_build_node_lists()
	_apply_base_size()
	_update_scale()
	_prepare_hidden()
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	var canvas_layer: CanvasLayer = get_parent() as CanvasLayer
	var layer: int = canvas_layer.layer if canvas_layer != null else -1
	SFLog.info("POWER_BAR_READY", {
		"pos": global_position,
		"size": size,
		"visible": visible,
		"modulate_a": modulate.a,
		"z": z_index,
		"layer": layer
	})

func set_state(state_ref: GameState) -> void:
	_state = state_ref

func tick(delta: float, state_ref: GameState) -> void:
	if state_ref != null:
		set_state(state_ref)
	_update_pulses(delta)
	_sample_accum += delta
	_poll_accum += delta
	var poll_interval: float = 0.0
	if poll_hz > 0.0:
		poll_interval = 1.0 / poll_hz
	if poll_interval <= 0.0 or _poll_accum >= poll_interval:
		if poll_interval > 0.0:
			_poll_accum = fmod(_poll_accum, poll_interval)
		_refresh_from_state()
	_layout_fills()

func pulse_player(player_index: int, gain_sign: int) -> void:
	var idx: int = player_index - 1
	if idx < 0 or idx >= 4:
		return
	_pulse_t[idx] = pulse_duration
	_pulse_sign[idx] = 1 if gain_sign >= 0 else -1
	SFLog.info("POWER_BAR_PULSE", {"player": player_index, "sign": _pulse_sign[idx]})

func prepare_hidden() -> void:
	_prepare_hidden()

func reveal_with_tween() -> void:
	SFLog.info("POWER_BAR_REVEAL_CALLED", {
		"was_revealed": _revealed,
		"visible_before": visible,
		"modulate_a_before": modulate.a,
		"pos": global_position,
		"size": size,
		"z": z_index
	})
	if _revealed:
		return
	_revealed = true
	visible = true
	if _reveal_tween != null and _reveal_tween.is_running():
		_reveal_tween.kill()
	modulate.a = 0.0
	_set_slide_offset(-reveal_slide_px)
	_reveal_tween = create_tween()
	_reveal_tween.set_trans(Tween.TRANS_SINE)
	_reveal_tween.set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(self, "modulate:a", 1.0, reveal_duration)
	_reveal_tween.parallel().tween_method(_set_slide_offset, -reveal_slide_px, 0.0, reveal_duration)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed or key.echo:
			return
		var gain_sign: int = -1 if key.shift_pressed else 1
		match key.keycode:
			KEY_1:
				pulse_player(1, gain_sign)
			KEY_2:
				pulse_player(2, gain_sign)
			KEY_3:
				pulse_player(3, gain_sign)
			KEY_4:
				pulse_player(4, gain_sign)

func _on_viewport_size_changed() -> void:
	_update_scale()

func _build_node_lists() -> void:
	_fill_nodes.clear()
	_ghost_nodes.clear()
	for i in range(1, 5):
		var ghost: Control = ghost_layer.get_node_or_null("GhostP%d" % i) as Control
		if ghost != null:
			_ghost_nodes.append(ghost)
		var fill: Control = fill_layer_main.get_node_or_null("FillP%d" % i) as Control
		if fill != null:
			_fill_nodes.append(fill)
	for node in _ghost_nodes:
		if node is ColorRect:
			(node as ColorRect).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in _fill_nodes:
		if node is ColorRect:
			(node as ColorRect).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_base_size() -> void:
	if base_texture == null:
		return
	var tex_size: Vector2 = Vector2(base_texture.get_width(), base_texture.get_height())
	var height_ratio: float = clamp(height_scale_ratio, 0.1, 1.0)
	var draw_size: Vector2 = Vector2(tex_size.x, tex_size.y * height_ratio)
	custom_minimum_size = draw_size
	size = draw_size
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -draw_size.x * 0.5
	offset_right = draw_size.x * 0.5
	offset_top = top_margin_px
	offset_bottom = top_margin_px + draw_size.y
	_base_offset_top = offset_top
	_base_offset_bottom = offset_bottom
	pivot_offset = draw_size * 0.5
	fill_layer.size = draw_size
	frame.size = draw_size

func _update_scale() -> void:
	if base_texture == null:
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var vp_size: Vector2 = viewport.get_visible_rect().size
	var tex_w: float = float(base_texture.get_width())
	if tex_w <= 0.0:
		return
	var max_w: float = vp_size.x * max_width_ratio
	var target_scale: float = max_w / tex_w
	target_scale = clamp(target_scale, min_scale, max_scale)
	scale = Vector2(target_scale, target_scale)

func _refresh_from_state() -> void:
	if _state == null:
		return
	var sig: String = _state_signature(_state)
	if sig != _state_sig:
		_state_sig = sig
		_visible_count = _resolve_visible_count(_state)
		_update_visibility()
	var totals: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for hive in _state.hives:
		var oid: int = int(hive.owner_id)
		if oid >= 1 and oid <= 4:
			totals[oid - 1] += float(hive.power)
	var total_visible: float = 0.0
	for i in range(_visible_count):
		total_visible += totals[i]
	if total_visible <= 0.0:
		var even_share: float = 1.0 / float(_visible_count)
		for i in range(4):
			_current_shares[i] = even_share if i < _visible_count else 0.0
	else:
		for i in range(4):
			_current_shares[i] = (totals[i] / total_visible) if i < _visible_count else 0.0
	if _sample_accum >= sample_interval_sec:
		_sample_accum = fmod(_sample_accum, sample_interval_sec)
		_update_history()

func _update_history() -> void:
	for i in range(4):
		var hist: Array = _history[i]
		var prev: float = float(hist.back()) if hist.size() > 0 else 0.0
		_ghost_shares[i] = prev
		hist.append(float(_current_shares[i]))
		while hist.size() > history_samples:
			hist.pop_front()
		_history[i] = hist

func _update_visibility() -> void:
	for i in range(4):
		var visible: bool = i < _visible_count
		if i < _fill_nodes.size():
			_fill_nodes[i].visible = visible
		if i < _ghost_nodes.size():
			_ghost_nodes[i].visible = visible

func _layout_fills() -> void:
	if base_texture == null:
		return
	var bar_size: Vector2 = size
	var inner_w: float = maxf(1.0, bar_size.x - fill_inset_left - fill_inset_right)
	var inner_h: float = maxf(1.0, bar_size.y - fill_inset_top - fill_inset_bottom)
	var base_x: float = fill_inset_left
	var base_y: float = fill_inset_top

	var cursor: float = 0.0
	var ghost_cursor: float = 0.0
	for i in range(4):
		var share: float = float(_current_shares[i] if _current_shares[i] != null else 0.0)
		var ghost_share: float = float(_ghost_shares[i] if _ghost_shares[i] != null else 0.0)
		var width: float = inner_w * share
		var ghost_width: float = inner_w * ghost_share
		var fill_node: Control = _fill_nodes[i] if i < _fill_nodes.size() else null
		var ghost_node: Control = _ghost_nodes[i] if i < _ghost_nodes.size() else null
		if i >= _visible_count:
			if fill_node != null:
				fill_node.visible = false
			if ghost_node != null:
				ghost_node.visible = false
			continue
		var pulse_f: float = _pulse_t[i] / pulse_duration if pulse_duration > 0.0 else 0.0
		pulse_f = clamp(pulse_f, 0.0, 1.0)
		var pulse_expand: float = pulse_expand_px * pulse_f
		var fill_x: float = base_x + cursor - pulse_expand * 0.5
		var fill_w: float = maxf(0.0, width + pulse_expand)
		if fill_node != null:
			fill_node.visible = true
			fill_node.position = Vector2(fill_x, base_y)
			fill_node.size = Vector2(fill_w, inner_h)
			fill_node.color = _pulse_color(i, pulse_f)
		if ghost_node != null:
			ghost_node.visible = true
			ghost_node.position = Vector2(base_x + ghost_cursor, base_y)
			ghost_node.size = Vector2(maxf(0.0, ghost_width), inner_h)
			ghost_node.color = _ghost_color(i)
		cursor += width
		ghost_cursor += ghost_width

func _pulse_color(idx: int, pulse_f: float) -> Color:
	var base: Color = PLAYER_COLORS[idx]
	var pulse_color: Color = base
	if pulse_f > 0.0:
		if _pulse_sign[idx] >= 0:
			pulse_color = base.lerp(Color(1, 1, 1, base.a), 0.25 * pulse_f)
		else:
			pulse_color = base.lerp(Color(0, 0, 0, base.a), 0.25 * pulse_f)
	pulse_color.a = base.a
	return pulse_color

func _ghost_color(idx: int) -> Color:
	var base: Color = PLAYER_COLORS[idx]
	base.a = ghost_alpha
	return base

func _update_pulses(delta: float) -> void:
	for i in range(4):
		if _pulse_t[i] > 0.0:
			_pulse_t[i] = maxf(0.0, _pulse_t[i] - delta)

func _prepare_hidden() -> void:
	_revealed = false
	visible = false
	modulate.a = 0.0
	_set_slide_offset(-reveal_slide_px)

func _set_slide_offset(offset_y: float) -> void:
	offset_top = _base_offset_top + offset_y
	offset_bottom = _base_offset_bottom + offset_y

func _resolve_visible_count(state_ref: GameState) -> int:
	var max_owner: int = 0
	for hive in state_ref.hives:
		var oid: int = int(hive.owner_id)
		if oid > max_owner:
			max_owner = oid
	if max_owner <= 0:
		max_owner = 2
	return clamp(max_owner, 2, 4)

func _state_signature(state_ref: GameState) -> String:
	var ids: Array[String] = []
	for hive in state_ref.hives:
		ids.append(str(hive.id))
	ids.sort()
	return "|".join(ids)
