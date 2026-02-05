class_name PowerBar
extends Control

const SFLog = preload("res://scripts/util/sf_log.gd")

const P1_COLOR: Color = Color(0.85, 0.72, 0.12, 0.95)
const P2_COLOR: Color = Color(0.25, 0.95, 0.35, 0.95)
const P3_COLOR: Color = Color(0.15, 0.45, 0.95, 0.95)
const P4_COLOR: Color = Color(0.95, 0.20, 0.20, 0.95)
const DEFAULT_TOP_PX: float = 10.0
const DEFAULT_ART_SIZE: Vector2 = Vector2(960.0, 128.0)
const FRAME_TEX_SIZE: Vector2 = Vector2(1536.0, 1024.0)
const SOCKET_PX_POS: Vector2 = Vector2(151.0, 408.0)
const SOCKET_PX_SIZE: Vector2 = Vector2(1231.0, 159.0)

@export var base_texture: Texture2D
@export var top_margin_px: float = 16.0
@export var height_scale_ratio: float = 1.0
@export var max_width_ratio: float = 0.72
@export var min_scale: float = 0.6
@export var max_scale: float = 1.0
@export var reveal_duration: float = 0.6
@export var reveal_slide_px: float = 6.0
@export var debug_socket: bool = false
@export var drive_layout: bool = false

@onready var _rig: Control = $Rig
@onready var _frame_art: TextureRect = $Rig/FrameArt
@onready var _bar_dock: Control = $Rig/BarDock
@onready var _fill_mask: Control = $Rig/BarDock/FillMask
@onready var _fill_p1: ColorRect = $Rig/BarDock/FillMask/FillP1
@onready var _fill_p2: ColorRect = $Rig/BarDock/FillMask/FillP2

var _state: GameState = null
var _target_share_p1: float = 0.5
var _target_share_p2: float = 0.5
var _display_share_p1: float = 0.5
var _display_share_p2: float = 0.5
var _lerp_speed: float = 6.0
var _max_width: float = 0.0
var _base_size: Vector2 = Vector2.ZERO
var _design_texture_size: Vector2 = DEFAULT_ART_SIZE
var _current_top_px: float = DEFAULT_TOP_PX
var _base_offset_top: float = 0.0
var _base_offset_bottom: float = 0.0
var _reveal_tween: Tween = null
var _revealed: bool = false
var _dock_rect_local: Rect2 = Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000
	# Editor-authoritative placement: fill the authored PowerBarAnchor rect.
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	position = Vector2.ZERO
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	top_level = false

	_sf_debug_dump("ready")
	if base_texture == null:
		base_texture = _frame_art.texture
	_apply_base_size()
	_ensure_visual_nodes()
	custom_minimum_size = Vector2.ZERO
	size = Vector2.ZERO
	_apply_layout(top_margin_px if top_margin_px > 0.0 else DEFAULT_TOP_PX)
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_revealed = true
	visible = true
	modulate.a = 1.0
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_bind_hud()
	_apply_hud_snapshot(OpsState.get_hud_snapshot())
	_apply_fill()
	_enforce_layer_order()
	SFLog.info("POWERBAR_READY_V3", {
		"path": str(get_path()),
		"dock_rect": str(_dock_rect_local),
		"frame_path": str(_frame_art.get_path()),
		"bar_dock_path": str(_bar_dock.get_path())
	})
	SFLog.info("POWERBAR_RIG", {
		"rig_pos": _rig.position if _rig != null else Vector2.ZERO,
		"frame_pos": _frame_art.position if _frame_art != null else Vector2.ZERO,
		"dock_pos": _bar_dock.position if _bar_dock != null else Vector2.ZERO,
		"dock_size": _bar_dock.size if _bar_dock != null else Vector2.ZERO
	})
	var canvas_layer: CanvasLayer = _find_canvas_layer()
	var parent_node: Node = get_parent()
	var global_rect: Rect2 = get_global_rect()
	SFLog.info("POWER_BAR_RUNTIME_POS", {
		"path": str(get_path()),
		"parent": str(parent_node.get_path()) if parent_node != null else "<none>",
		"global_rect_pos": global_rect.position,
		"global_rect_size": global_rect.size,
		"canvas_layer_path": str(canvas_layer.get_path()) if canvas_layer != null else "<none>",
		"canvas_layer": int(canvas_layer.layer) if canvas_layer != null else 0,
		"local_pos": position,
		"local_size": size
	})
	SFLog.info("POWERBAR_VISIBLE_CHECK", {
		"path": str(get_path()),
		"global_pos": global_position,
		"size": size,
		"visible": visible,
		"canvas_layer_path": str(canvas_layer.get_path()) if canvas_layer != null else "<none>",
		"canvas_layer": int(canvas_layer.layer) if canvas_layer != null else 0
	})
	# Optional one-shot sanity log during placement debugging:
	# print("PB READY pos=", global_position, " rect=", size)

func set_state(state_ref: GameState) -> void:
	_state = state_ref

func tick(_delta: float, state_ref: GameState) -> void:
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

func _sf_debug_dump(tag: String) -> void:
	var parent_node: Node = get_parent()
	var parent_path: String = "<none>"
	if parent_node != null and parent_node.is_inside_tree():
		parent_path = str(parent_node.get_path())
	var parent_gp: Vector2 = Vector2.ZERO
	var parent_sz: Vector2 = Vector2.ZERO
	if parent_node is Control:
		var parent_control: Control = parent_node as Control
		parent_gp = parent_control.global_position
		parent_sz = parent_control.size
	print("POWER_BAR_DUMP ", tag,
		" path=", (str(get_path()) if is_inside_tree() else "<notree>"),
		" parent=", parent_path,
		" gp=", global_position,
		" sz=", size,
		" parent_gp=", parent_gp,
		" parent_sz=", parent_sz
	)

func pulse_player(_player_index: int, _gain_sign: int) -> void:
	return

func prepare_hidden() -> void:
	_prepare_hidden()

func reveal_with_tween() -> void:
	if _revealed:
		return
	_revealed = true
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

func _on_resized() -> void:
	_sync_layout()

func _draw() -> void:
	if not debug_socket or _bar_dock == null or _rig == null:
		return
	draw_rect(Rect2(_rig.position + _dock_rect_local.position, _dock_rect_local.size), Color(0.0, 1.0, 0.0, 0.35), false, 2.0)

func _ensure_visual_nodes() -> void:
	if base_texture != null:
		_frame_art.texture = base_texture
	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.anchor_left = 0.0
	_rig.anchor_top = 0.0
	_rig.anchor_right = 0.0
	_rig.anchor_bottom = 0.0
	_rig.offset_left = -_design_texture_size.x * 0.5
	_rig.offset_top = 0.0
	_rig.offset_right = _rig.offset_left + _design_texture_size.x
	_rig.offset_bottom = _design_texture_size.y
	_frame_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_art.anchor_left = 0.0
	_frame_art.anchor_top = 0.0
	_frame_art.anchor_right = 1.0
	_frame_art.anchor_bottom = 1.0
	_frame_art.offset_left = 0.0
	_frame_art.offset_top = 0.0
	_frame_art.offset_right = 0.0
	_frame_art.offset_bottom = 0.0
	_bar_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_mask.clip_contents = true
	_fill_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_mask.anchor_left = 0.0
	_fill_mask.anchor_top = 0.0
	_fill_mask.anchor_right = 1.0
	_fill_mask.anchor_bottom = 1.0
	_fill_mask.offset_left = 0.0
	_fill_mask.offset_top = 0.0
	_fill_mask.offset_right = 0.0
	_fill_mask.offset_bottom = 0.0
	_fill_p1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_p2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_p1.color = P1_COLOR
	_fill_p2.color = P2_COLOR
	_fill_p1.anchor_left = 0.0
	_fill_p1.anchor_top = 0.0
	_fill_p1.anchor_right = 0.0
	_fill_p1.anchor_bottom = 1.0
	_fill_p1.offset_left = 0.0
	_fill_p1.offset_top = 0.0
	_fill_p1.offset_right = 0.0
	_fill_p1.offset_bottom = 0.0
	_fill_p2.anchor_left = 0.0
	_fill_p2.anchor_top = 0.0
	_fill_p2.anchor_right = 0.0
	_fill_p2.anchor_bottom = 1.0
	_fill_p2.offset_left = 0.0
	_fill_p2.offset_top = 0.0
	_fill_p2.offset_right = 0.0
	_fill_p2.offset_bottom = 0.0

func _apply_base_size() -> void:
	var ref_tex: Texture2D = base_texture
	if ref_tex == null:
		ref_tex = _frame_art.texture
	if ref_tex == null:
		_design_texture_size = DEFAULT_ART_SIZE
		_base_size = DEFAULT_ART_SIZE
		return
	_design_texture_size = Vector2(ref_tex.get_width(), ref_tex.get_height())
	var height_ratio: float = clampf(height_scale_ratio, 0.25, 1.0)
	_base_size = Vector2(_design_texture_size.x, _design_texture_size.y * height_ratio)
	if _rig != null:
		_rig.offset_left = -_design_texture_size.x * 0.5
		_rig.offset_top = 0.0
		_rig.offset_right = _rig.offset_left + _design_texture_size.x
		_rig.offset_bottom = _design_texture_size.y

func _apply_layout(top: float) -> void:
	_current_top_px = top
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	position = Vector2.ZERO
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var parent_control: Control = get_parent() as Control
	var parent_width: float = get_viewport_rect().size.x
	if parent_control != null:
		parent_width = parent_control.size.x
	var target_max_w: float = clampf(parent_width * 0.85, 0.0, 99999.0)
	var tex: Texture2D = base_texture
	if tex == null:
		tex = _frame_art.texture
	var fit_scale: float = 1.0
	if tex != null and tex.get_width() > 0:
		fit_scale = target_max_w / float(tex.get_width())
	fit_scale = clampf(fit_scale, min_scale, max_scale)
	scale = Vector2.ONE * fit_scale

	var fit_size: Vector2 = Vector2(maxf(1.0, _base_size.x), maxf(1.0, _base_size.y)) * fit_scale
	if drive_layout:
		custom_minimum_size = fit_size
	_base_offset_top = 0.0
	_base_offset_bottom = 0.0
	_sync_layout()
	_apply_fill()
	queue_redraw()

func _sync_layout() -> void:
	if _rig == null or _frame_art == null or _bar_dock == null:
		return
	var frame_size: Vector2 = _frame_art.size
	var scale_x: float = frame_size.x / FRAME_TEX_SIZE.x
	var scale_y: float = frame_size.y / FRAME_TEX_SIZE.y
	var socket_pos: Vector2 = _frame_art.position + Vector2(SOCKET_PX_POS.x * scale_x, SOCKET_PX_POS.y * scale_y)
	var socket_size: Vector2 = Vector2(SOCKET_PX_SIZE.x * scale_x, SOCKET_PX_SIZE.y * scale_y)
	socket_size.x = maxf(1.0, socket_size.x)
	socket_size.y = maxf(1.0, socket_size.y)
	_dock_rect_local = Rect2(socket_pos, socket_size)
	_bar_dock.anchor_left = 0.0
	_bar_dock.anchor_top = 0.0
	_bar_dock.anchor_right = 0.0
	_bar_dock.anchor_bottom = 0.0
	_bar_dock.position = _dock_rect_local.position
	_bar_dock.size = _dock_rect_local.size
	_fill_mask.anchor_left = 0.0
	_fill_mask.anchor_top = 0.0
	_fill_mask.anchor_right = 1.0
	_fill_mask.anchor_bottom = 1.0
	_fill_mask.offset_left = 0.0
	_fill_mask.offset_top = 0.0
	_fill_mask.offset_right = 0.0
	_fill_mask.offset_bottom = 0.0
	_max_width = maxf(1.0, _dock_rect_local.size.x)
	if debug_socket:
		queue_redraw()

func _apply_fill() -> void:
	if _fill_mask == null or _fill_p1 == null or _fill_p2 == null:
		return
	_max_width = maxf(1.0, _fill_mask.size.x)
	var left_width: float = _max_width * clampf(_display_share_p1, 0.0, 1.0)
	var right_width: float = maxf(0.0, _max_width - left_width)
	var mask_h: float = _fill_mask.size.y
	_fill_p1.position = Vector2(0.0, 0.0)
	_fill_p1.size = Vector2(left_width, mask_h)
	_fill_p2.position = Vector2(_max_width - right_width, 0.0)
	_fill_p2.size = Vector2(right_width, mask_h)

func _enforce_layer_order() -> void:
	if _rig == null:
		return
	_bar_dock.z_as_relative = false
	_fill_mask.z_as_relative = false
	_fill_p1.z_as_relative = false
	_fill_p2.z_as_relative = false
	_frame_art.z_as_relative = false
	_bar_dock.z_index = 0
	_fill_mask.z_index = 0
	_fill_p1.z_index = 0
	_fill_p2.z_index = 0
	_frame_art.z_index = 10
	_rig.move_child(_frame_art, _rig.get_child_count() - 1)
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
	# No-op: avoid runtime drift; anchor decides placement.
	offset_top = _base_offset_top
	offset_bottom = _base_offset_bottom

func _find_canvas_layer() -> CanvasLayer:
	var p: Node = get_parent()
	while p != null:
		var cl: CanvasLayer = p as CanvasLayer
		if cl != null:
			return cl
		p = p.get_parent()
	return null
