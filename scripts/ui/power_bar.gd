class_name PowerBar
extends Control

const SFLog = preload("res://scripts/util/sf_log.gd")
const FILL_SHADER: Shader = preload("res://assets/shaders/ui_fill_clip.gdshader")
const DEBUG_FILL_PROBE: bool = false

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
@export var auto_fit_to_parent: bool = false
@export var allow_auto_layout: bool = false
@export var allow_runtime_docking: bool = false
@export var debug_socket: bool = false
@export var drive_layout: bool = false
@export var debug_draw_rect: bool = true

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
var _fill_wired_logged: bool = false
var _fill_missing_logged: bool = false
var _fill_probe_ready_logged: bool = false
var _fill_probe_last_log_ms: int = 0
var _powerbar_bind_logged: bool = false
var _powerbar_ready_logged: bool = false
var _powerbar_last_visible_logged: int = -1
var _powerbar_last_ratio_logged: float = -1.0
var _powerbar_last_total_logged: float = -1.0
var _powerbar_last_display_logged: float = -1.0
var _powerbar_last_update_log_ms: int = 0
var _progress_probe_node: ProgressBar = null
var _debug_rect: ColorRect = null

func _control_font_size(control: Control) -> int:
	if control == null:
		return -1
	if control.has_theme_font_size_override("font_size") or control.has_theme_font_size("font_size"):
		return int(control.get_theme_font_size("font_size"))
	return -1

func _ui_node_info(node: CanvasItem) -> Dictionary:
	if node == null:
		return {
			"path": "<null>",
			"class": "<null>",
			"inside_tree": false,
			"visible_in_tree": false,
			"modulate": Color(0, 0, 0, 0),
			"self_modulate": Color(0, 0, 0, 0),
			"scale": Vector2.ZERO,
			"size": Vector2.ZERO,
			"font_size": -1
		}
	var size: Vector2 = Vector2.ZERO
	var font_size: int = -1
	if node is Control:
		var control: Control = node as Control
		size = control.size
		font_size = _control_font_size(control)
	return {
		"path": str(node.get_path()),
		"class": node.get_class(),
		"inside_tree": node.is_inside_tree(),
		"visible_in_tree": node.is_visible_in_tree(),
		"modulate": node.modulate,
		"self_modulate": node.self_modulate,
		"scale": node.scale,
		"size": size,
		"font_size": font_size
	}

func _find_progress_bar(node: Node) -> ProgressBar:
	for child_any in node.get_children():
		var child: Node = child_any as Node
		if child == null:
			continue
		if child is ProgressBar:
			return child as ProgressBar
		var found: ProgressBar = _find_progress_bar(child)
		if found != null:
			return found
	return null

func _progress_probe_info() -> Dictionary:
	if _progress_probe_node == null:
		return {
			"type": "custom",
			"min_value": 0.0,
			"max_value": 1.0,
			"value": _display_share_p1,
			"percent": _display_share_p1,
			"show_percentage": null,
			"texture_progress": null,
			"tint_progress": null,
			"theme_overrides": {
				"fill_style": null,
				"fg_style": null,
				"bg_style": null
			}
	}
	var progress: Control = _progress_probe_node
	var range: Range = null
	var texture_present: Variant = null
	var tint_progress: Variant = null
	var show_percentage: Variant = null
	if progress is TextureProgressBar:
		var tpb: TextureProgressBar = progress as TextureProgressBar
		range = tpb
		texture_present = tpb.texture_progress != null
		tint_progress = tpb.tint_progress
		show_percentage = tpb.show_percentage
	elif progress is ProgressBar:
		var pb: ProgressBar = progress as ProgressBar
		range = pb
		show_percentage = pb.show_percentage
	else:
		SFLog.warn("POWER_BAR_UNKNOWN_TYPE", {
			"class": progress.get_class()
		})
		return {
			"type": progress.get_class(),
			"min_value": null,
			"max_value": null,
			"value": null,
			"percent": null,
			"show_percentage": null,
			"texture_progress": null,
			"tint_progress": null,
			"theme_overrides": {
				"fill_style": null,
				"fg_style": null,
				"bg_style": null
			}
		}
	var denom: float = maxf(1.0, range.max_value - range.min_value)
	var percent: float = (range.value - range.min_value) / denom
	return {
		"type": range.get_class(),
		"min_value": range.min_value,
		"max_value": range.max_value,
		"value": range.value,
		"percent": percent,
		"show_percentage": show_percentage,
		"texture_progress": texture_present,
		"tint_progress": tint_progress,
		"theme_overrides": {
			"fill_style": range.has_theme_stylebox_override("fill"),
			"fg_style": range.has_theme_stylebox_override("fg"),
			"bg_style": range.has_theme_stylebox_override("bg")
		}
	}

func _ensure_fill_bounds() -> void:
	if _fill_mask != null:
		_fill_mask.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_fill_mask.offset_left = 0.0
		_fill_mask.offset_top = 0.0
		_fill_mask.offset_right = 0.0
		_fill_mask.offset_bottom = 0.0
	if _fill_p1 != null:
		_fill_p1.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_fill_p1.offset_left = 0.0
		_fill_p1.offset_top = 0.0
		_fill_p1.offset_right = 0.0
		_fill_p1.offset_bottom = 0.0
	if _fill_p2 != null:
		_fill_p2.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_fill_p2.offset_left = 0.0
		_fill_p2.offset_top = 0.0
		_fill_p2.offset_right = 0.0
		_fill_p2.offset_bottom = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_sf_debug_dump("ready")
	if base_texture == null:
		base_texture = _frame_art.texture
	_apply_base_size()
	_ensure_visual_nodes()
	_ensure_debug_rect()
	_log_power_bar_diag()
	_progress_probe_node = _find_progress_bar(self)
	_base_offset_top = offset_top
	_base_offset_bottom = offset_bottom
	_apply_layout(top_margin_px if top_margin_px > 0.0 else DEFAULT_TOP_PX)
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_update_visibility_from_state()
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_bind_hud()
	_apply_hud_snapshot(OpsState.get_hud_snapshot())
	_apply_fill()
	_enforce_layer_order()
	if not _powerbar_ready_logged:
		_powerbar_ready_logged = true
		SFLog.info("UI_POWERBAR_READY", {
			"node": _ui_node_info(self),
			"rig": _ui_node_info(_rig),
			"frame": _ui_node_info(_frame_art),
			"dock": _ui_node_info(_bar_dock),
			"fill_mask": _ui_node_info(_fill_mask),
			"fill_p1": _ui_node_info(_fill_p1),
			"fill_p2": _ui_node_info(_fill_p2),
			"progress": _progress_probe_info(),
			"target_share_p1": _target_share_p1,
			"display_share_p1": _display_share_p1
		})
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
	if DEBUG_FILL_PROBE:
		_run_fill_probe()
	var now_ms: int = Time.get_ticks_msec()
	var display_delta: float = absf(_display_share_p1 - _powerbar_last_display_logged)
	if now_ms - _powerbar_last_update_log_ms >= 1000 or display_delta >= 0.01:
		_powerbar_last_update_log_ms = now_ms
		_powerbar_last_display_logged = _display_share_p1
		SFLog.info("UI_POWERBAR_UPDATE", {
			"node": _ui_node_info(self),
			"target_share_p1": _target_share_p1,
			"display_share_p1": _display_share_p1,
			"progress": _progress_probe_info(),
			"fill_mask": _ui_node_info(_fill_mask),
			"fill_p1": _ui_node_info(_fill_p1),
			"fill_p2": _ui_node_info(_fill_p2),
			"reason": "process_tick"
		})
	_update_visibility_from_state()

func _update_visibility_from_state() -> void:
	var phase: int = int(OpsState.match_phase)
	var prematch_ms: int = int(OpsState.prematch_remaining_ms)
	var should_show: bool = (phase != int(OpsState.MatchPhase.PREMATCH)) or (prematch_ms <= 0)
	if visible != should_show:
		visible = should_show
	var vis_i: int = int(visible)
	if _powerbar_last_visible_logged != vis_i:
		_powerbar_last_visible_logged = vis_i
		SFLog.info("UI_POWERBAR_VIS", {
			"node": _ui_node_info(self),
			"phase": phase,
			"prematch_ms": prematch_ms,
			"should_show": should_show
		})

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
	_dump_powerbar_once()

func _dump_powerbar_once() -> void:
	var pb: Node = get_node_or_null(
		"/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot/TopBufferBackground/PowerBarAnchor/PowerBar"
	)
	if pb == null:
		SFLog.warn("POWERBAR_MISSING", {"path": "expected full path"})
		return

	var info: Dictionary = {
		"path": str(pb.get_path()),
		"type": pb.get_class(),
		"visible": (pb.visible if pb is CanvasItem else false),
		"vis_in_tree": (pb.is_visible_in_tree() if pb is CanvasItem else false),
		"modulate_a": (pb.modulate.a if pb is CanvasItem else -1.0),
		"z_index": (pb.z_index if pb is CanvasItem else 0)
	}

	if pb is Control:
		var pb_control: Control = pb as Control
		info["rect_pos"] = pb_control.position
		info["rect_size"] = pb_control.size
		info["global_rect"] = pb_control.get_global_rect()
		var p: Node = pb_control.get_parent()
		var chain: Array = []
		while p != null and p != get_tree().root:
			var entry: Dictionary = {
				"name": p.name,
				"type": p.get_class()
			}
			if p is Control:
				var pc: Control = p as Control
				entry["clip"] = pc.clip_contents
				entry["pos"] = pc.position
				entry["size"] = pc.size
			chain.append(entry)
			p = p.get_parent()
		info["parent_chain"] = chain

	SFLog.info("POWERBAR_ONEPASS", info)

func pulse_player(_player_index: int, _gain_sign: int) -> void:
	return

func prepare_hidden() -> void:
	# UI observes OpsState; visibility is derived in _update_visibility_from_state().
	return

func reveal_with_tween() -> void:
	# UI observes OpsState; visibility is derived in _update_visibility_from_state().
	return

func snap_to_play_surface(camera: Camera2D, map_top_world_y: float, margin_px: float = 8.0) -> void:
	# WYSIWYG: power bar does not reposition at runtime.
	return

func _bind_hud() -> void:
	var was_connected: bool = OpsState.hud_changed.is_connected(_on_hud_changed)
	if not was_connected:
		OpsState.hud_changed.connect(_on_hud_changed)
	if not _powerbar_bind_logged:
		_powerbar_bind_logged = true
		SFLog.info("UI_POWERBAR_BIND", {
			"node": _ui_node_info(self),
			"signal_connected": OpsState.hud_changed.is_connected(_on_hud_changed),
			"was_connected": was_connected,
			"progress": _progress_probe_info()
		})

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
	var p1: float = float(totals.get(1, 0.0))
	var p2: float = float(totals.get(2, 0.0))
	var total: float = p1 + p2
	if absf(_target_share_p1 - _powerbar_last_ratio_logged) > 0.001 or absf(total - _powerbar_last_total_logged) > 0.1:
		_powerbar_last_ratio_logged = _target_share_p1
		_powerbar_last_total_logged = total
		SFLog.info("UI_POWERBAR_UPDATE", {
			"node": _ui_node_info(self),
			"p1_power": p1,
			"p2_power": p2,
			"total": total,
			"target_share_p1": _target_share_p1,
			"display_share_p1": _display_share_p1,
			"progress": _progress_probe_info(),
			"fill_mask": _ui_node_info(_fill_mask),
			"fill_p1": _ui_node_info(_fill_p1),
			"fill_p2": _ui_node_info(_fill_p2)
		})

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
	if _should_auto_layout():
		_apply_layout(_current_top_px)

func _on_resized() -> void:
	_maybe_sync_layout()

func _draw() -> void:
	if not debug_socket or _bar_dock == null or _rig == null:
		return
	draw_rect(Rect2(_rig.position + _dock_rect_local.position, _dock_rect_local.size), Color(0.0, 1.0, 0.0, 0.35), false, 2.0)

func _ensure_visual_nodes() -> void:
	if base_texture != null:
		_frame_art.texture = base_texture
	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_mask.clip_contents = true
	_fill_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_p1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_p2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_p1.color = P1_COLOR
	_fill_p2.color = P2_COLOR
	_ensure_fill_bounds()
	_setup_fill_materials()
	if not _should_auto_layout():
		return
	_rig.anchor_left = 0.0
	_rig.anchor_top = 0.0
	_rig.anchor_right = 0.0
	_rig.anchor_bottom = 0.0
	_rig.offset_left = -_design_texture_size.x * 0.5
	_rig.offset_top = 0.0
	_rig.offset_right = _rig.offset_left + _design_texture_size.x
	_rig.offset_bottom = _design_texture_size.y
	_frame_art.anchor_left = 0.0
	_frame_art.anchor_top = 0.0
	_frame_art.anchor_right = 1.0
	_frame_art.anchor_bottom = 1.0
	_frame_art.offset_left = 0.0
	_frame_art.offset_top = 0.0
	_frame_art.offset_right = 0.0
	_frame_art.offset_bottom = 0.0
	_fill_mask.anchor_left = 0.0
	_fill_mask.anchor_top = 0.0
	_fill_mask.anchor_right = 1.0
	_fill_mask.anchor_bottom = 1.0
	_fill_mask.offset_left = 0.0
	_fill_mask.offset_top = 0.0
	_fill_mask.offset_right = 0.0
	_fill_mask.offset_bottom = 0.0
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
	if _rig != null and _should_auto_layout():
		_rig.offset_left = -_design_texture_size.x * 0.5
		_rig.offset_top = 0.0
		_rig.offset_right = _rig.offset_left + _design_texture_size.x
		_rig.offset_bottom = _design_texture_size.y

func _apply_layout(top: float) -> void:
	_current_top_px = top
	if not _should_auto_layout():
		return

	if auto_fit_to_parent:
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
		if drive_layout and allow_runtime_docking:
			custom_minimum_size = fit_size

	_maybe_sync_layout()
	_apply_fill()
	queue_redraw()

func _should_auto_layout() -> bool:
	return OS.is_debug_build() and allow_auto_layout

func _maybe_sync_layout() -> void:
	if _should_auto_layout():
		_sync_layout()

func _sync_layout() -> void:
	if _frame_art == null or _bar_dock == null or _fill_mask == null:
		return
	var root_rect: Rect2 = Rect2(Vector2.ZERO, size)
	var pad: Vector2 = Vector2(0.0, 0.0)
	var frame_rect: Rect2 = Rect2(root_rect.position + pad, root_rect.size - pad * 2.0)

	if _rig != null:
		var rig: Control = _rig
		rig.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		rig.offset_left = 0.0
		rig.offset_top = 0.0
		rig.offset_right = 0.0
		rig.offset_bottom = 0.0

	_frame_art.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_frame_art.offset_left = frame_rect.position.x
	_frame_art.offset_top = frame_rect.position.y
	_frame_art.offset_right = -(root_rect.size.x - (frame_rect.position.x + frame_rect.size.x))
	_frame_art.offset_bottom = -(root_rect.size.y - (frame_rect.position.y + frame_rect.size.y))

	var socket_pos_n: Vector2 = Vector2(
		SOCKET_PX_POS.x / FRAME_TEX_SIZE.x,
		SOCKET_PX_POS.y / FRAME_TEX_SIZE.y
	)
	var socket_size_n: Vector2 = Vector2(
		SOCKET_PX_SIZE.x / FRAME_TEX_SIZE.x,
		SOCKET_PX_SIZE.y / FRAME_TEX_SIZE.y
	)
	var socket_pos: Vector2 = frame_rect.position + Vector2(
		frame_rect.size.x * socket_pos_n.x,
		frame_rect.size.y * socket_pos_n.y
	)
	var socket_size: Vector2 = Vector2(
		frame_rect.size.x * socket_size_n.x,
		frame_rect.size.y * socket_size_n.y
	)
	socket_size.x = maxf(1.0, socket_size.x)
	socket_size.y = maxf(1.0, socket_size.y)
	_dock_rect_local = Rect2(socket_pos, socket_size)
	_bar_dock.anchor_left = 0.0
	_bar_dock.anchor_top = 0.0
	_bar_dock.anchor_right = 0.0
	_bar_dock.anchor_bottom = 0.0
	if allow_runtime_docking:
		_bar_dock.position = _dock_rect_local.position
		_bar_dock.size = _dock_rect_local.size
	_fill_mask.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_fill_mask.offset_left = 0.0
	_fill_mask.offset_top = 0.0
	_fill_mask.offset_right = 0.0
	_fill_mask.offset_bottom = 0.0
	_max_width = maxf(1.0, _dock_rect_local.size.x)
	if debug_socket:
		queue_redraw()

func _apply_fill() -> void:
	if _fill_p1 == null or _fill_p2 == null:
		return
	var mat1: ShaderMaterial = _fill_p1.material as ShaderMaterial
	var mat2: ShaderMaterial = _fill_p2.material as ShaderMaterial
	if mat1 == null or mat2 == null:
		if not _fill_missing_logged:
			_fill_missing_logged = true
			SFLog.warn("POWERBAR_FILL_MISSING", {
				"expected": "ShaderMaterial on FillP1/FillP2",
				"root": str(get_path())
			})
		return
	var p1: float = clampf(_display_share_p1, 0.0, 1.0)
	var p2: float = clampf(_display_share_p2, 0.0, 1.0)
	mat1.set_shader_parameter("fill_ratio", p1)
	mat2.set_shader_parameter("fill_ratio", p2)
	if not _fill_wired_logged:
		_fill_wired_logged = true
		SFLog.info("POWERBAR_FILL_WIRED", {
			"ratio": p1,
			"bar_path": str(get_path())
		})

func _ensure_debug_rect() -> void:
	if not debug_draw_rect:
		return
	if _debug_rect != null and is_instance_valid(_debug_rect):
		_debug_rect.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_debug_rect.position = Vector2.ZERO
		_debug_rect.size = size
		_debug_rect.z_as_relative = true
		_debug_rect.z_index = -50
		_debug_rect.modulate = Color(1, 0, 1, 0.18)
		_debug_rect.show_behind_parent = false
		return
	var r: ColorRect = ColorRect.new()
	r.name = "DebugBarRect"
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(1, 0, 1, 0.18)
	r.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	r.position = Vector2.ZERO
	r.size = size
	r.z_as_relative = true
	r.z_index = -50
	r.show_behind_parent = false
	add_child(r)
	_debug_rect = r
	SFLog.info("POWER_BAR_DIAG", {
		"dbg_added": true,
		"parent_path": str(get_path()),
		"parent_size": str(size),
		"dbg_size": str(_debug_rect.size),
		"dbg_global": str(_debug_rect.global_position),
		"dbg_visible": _debug_rect.visible
	})

func _node_diag(node: Node) -> Dictionary:
	if node == null:
		return {"path": "<null>", "type": "<null>"}
	var info: Dictionary = {
		"path": str(node.get_path()),
		"type": node.get_class()
	}
	if node is CanvasItem:
		var ci: CanvasItem = node as CanvasItem
		info["global_pos"] = ci.global_position
		info["z_index"] = ci.z_index
	if node is Control:
		var c: Control = node as Control
		info["size"] = c.size
		info["global_rect"] = c.get_global_rect()
	return info

func _log_power_bar_diag() -> void:
	var anchor: Node = get_node_or_null(
		"/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot/TopBufferBackground/PowerBarAnchor"
	)
	SFLog.info("POWER_BAR_DIAG", {
		"root": _node_diag(self),
		"anchor": _node_diag(anchor),
		"bar_dock": _node_diag(_bar_dock),
		"frame": _node_diag(_frame_art),
		"fill_mask": _node_diag(_fill_mask)
	})

func _run_fill_probe() -> void:
	if _fill_p1 == null:
		if not _fill_missing_logged:
			_fill_missing_logged = true
			SFLog.warn("POWER_FILL_PROBE_MISSING", {
				"expected": "FillP1",
				"root": str(get_path())
			})
		return
	var now_ms: int = Time.get_ticks_msec()
	var t_raw: float = fmod(float(now_ms) / 1000.0, 1.0)
	var alpha: float = lerpf(0.15, 1.0, t_raw)
	_fill_p1.modulate.a = alpha
	if _fill_p2 != null:
		_fill_p2.modulate.a = alpha
	if not _fill_probe_ready_logged:
		_fill_probe_ready_logged = true
		SFLog.info("POWER_FILL_PROBE_READY", {
			"fill_path": str(_fill_p1.get_path()),
			"fill_type": _fill_p1.get_class(),
			"initial_visible": _fill_p1.visible,
			"initial_modulate": _fill_p1.modulate
		})
	if now_ms - _fill_probe_last_log_ms >= 1000:
		_fill_probe_last_log_ms = now_ms
		SFLog.info("POWER_FILL_PROBE_TICK", {
			"t": t_raw,
			"fill_alpha": alpha
		})

func _setup_fill_materials() -> void:
	if _fill_p1 != null:
		var mat1: ShaderMaterial = _fill_p1.material as ShaderMaterial
		if mat1 == null or mat1.shader != FILL_SHADER:
			mat1 = ShaderMaterial.new()
			mat1.shader = FILL_SHADER
			_fill_p1.material = mat1
	if _fill_p2 != null:
		var mat2: ShaderMaterial = _fill_p2.material as ShaderMaterial
		if mat2 == null or mat2.shader != FILL_SHADER:
			mat2 = ShaderMaterial.new()
			mat2.shader = FILL_SHADER
			_fill_p2.material = mat2
		if mat2 != null:
			mat2.set_shader_parameter("align_right", true)

func _enforce_layer_order() -> void:
	if _rig == null:
		return
	if not _should_auto_layout():
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
	# No-op in WYSIWYG mode.
	return

func _find_canvas_layer() -> CanvasLayer:
	var p: Node = get_parent()
	while p != null:
		var cl: CanvasLayer = p as CanvasLayer
		if cl != null:
			return cl
		p = p.get_parent()
	return null
