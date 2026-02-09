# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# Renderers MUST NOT mutate state; they only render from render_model.
class_name BarracksGroundGlowRenderer
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const HiveRenderer := preload("res://scripts/renderers/hive_renderer.gd")
const NPC_CIRCUIT_COLOR: Color = Color(0.55, 0.50, 0.70, 1.0)
const CIRCUIT_SURFACE_COLOR: Color = Color(0.84, 0.90, 1.0, 1.0)
const CIRCUIT_TRENCH_COLOR: Color = Color(0.06, 0.09, 0.13, 1.0)

@export var alpha: float = 0.38
@export var glow_blend_additive: bool = false
@export var shorten_px: float = 12.0
@export var z_layer: int = -10
@export var trace_width_px: float = 1.15
@export var trench_extra_px: float = 1.6
@export var substrate_alpha: float = 0.34
@export var tint_alpha: float = 0.48
@export var glow_alpha: float = 0.22
@export var trace_wobble_px: float = 3.0
@export var trace_segment_len_px: float = 42.0
@export var via_radius_px: float = 1.4
@export var branch_len_px: float = 4.0

var _barracks: Array = []
var _hives_by_id: Dictionary = {}

func _ready() -> void:
	z_index = z_layer
	SFLog.allow_tag("CIRCUIT_GLOW_MODEL")
	SFLog.allow_tag("CIRCUIT_GLOW_DRAW")
	SFLog.allow_tag("BARRACKS_GLOW_MODEL")
	if glow_blend_additive:
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
	else:
		material = null
	set_process(false)

func set_model(model: Dictionary) -> void:
	var barracks_v: Variant = model.get("barracks", [])
	_barracks = barracks_v as Array if typeof(barracks_v) == TYPE_ARRAY else []

	_hives_by_id.clear()
	var hives_v: Variant = model.get("hives", [])
	if typeof(hives_v) == TYPE_ARRAY:
		for h_any in hives_v as Array:
			if typeof(h_any) != TYPE_DICTIONARY:
				continue
			var h: Dictionary = h_any as Dictionary
			var id: int = int(h.get("id", -1))
			if id <= 0:
				continue
			var pos_v: Variant = h.get("world_pos", h.get("pos", Vector2.ZERO))
			var pos: Vector2 = pos_v as Vector2 if pos_v is Vector2 else Vector2.ZERO
			_hives_by_id[id] = {
				"world_pos": pos,
				"owner_id": int(h.get("owner_id", 0))
			}

	var sample_control_ids: Array = []
	if not _barracks.is_empty() and typeof(_barracks[0]) == TYPE_DICTIONARY:
		var b0: Dictionary = _barracks[0] as Dictionary
		var control_v: Variant = b0.get("control_hive_ids", b0.get("required_hive_ids", []))
		if typeof(control_v) == TYPE_ARRAY:
			sample_control_ids = control_v as Array
	SFLog.log_on_change_payload("BARRACKS_GLOW_MODEL", "%d|%d|%d" % [_barracks.size(), _hives_by_id.size(), sample_control_ids.size()], {
		"barracks_count": _barracks.size(),
		"hives_count": _hives_by_id.size(),
		"sample_control_ids": sample_control_ids,
		"z_index": z_index,
		"blend_additive": glow_blend_additive
	})

	queue_redraw()

func _draw() -> void:
	if _barracks.is_empty():
		return

	var traces_drawn: int = 0
	var sample_a: Vector2 = Vector2.ZERO
	var sample_b: Vector2 = Vector2.ZERO
	var has_sample: bool = false
	for b_any in _barracks:
		if typeof(b_any) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = b_any as Dictionary

		var barracks_pos_v: Variant = b.get("world_pos", b.get("pos_px", b.get("pos", Vector2.ZERO)))
		var barracks_pos: Vector2 = barracks_pos_v as Vector2 if barracks_pos_v is Vector2 else Vector2.ZERO
		var control_ids_v: Variant = b.get("control_hive_ids", b.get("required_hive_ids", []))
		if typeof(control_ids_v) != TYPE_ARRAY:
			continue

		for hid_v in control_ids_v as Array:
			var hid: int = int(hid_v)
			var hinfo: Dictionary = _hives_by_id.get(hid, {})
			if hinfo.is_empty():
				continue

			var hive_pos: Vector2 = hinfo.get("world_pos", Vector2.ZERO)
			var owner_id: int = int(hinfo.get("owner_id", 0))
			var trim: Dictionary = _trim_segment(barracks_pos, hive_pos, shorten_px)
			var a2: Vector2 = trim.get("a", barracks_pos)
			var b2: Vector2 = trim.get("b", hive_pos)
			_draw_embedded_trace(a2, b2, owner_id)
			traces_drawn += 1
			if not has_sample:
				has_sample = true
				sample_a = a2
				sample_b = b2
	SFLog.warn("CIRCUIT_GLOW_DRAW", {
		"type": "barracks",
		"traces": traces_drawn,
		"barracks": _barracks.size(),
		"sample_a": sample_a if has_sample else null,
		"sample_b": sample_b if has_sample else null,
		"z_index": z_index,
		"blend_additive": glow_blend_additive
	}, "", 5000)

func _owner_color(owner_id: int) -> Color:
	if owner_id <= 0:
		return NPC_CIRCUIT_COLOR
	return HiveRenderer._owner_color(owner_id)

func _trim_segment(a: Vector2, b: Vector2, shorten: float) -> Dictionary:
	var dir: Vector2 = b - a
	var len: float = dir.length()
	if len < 1.0:
		return {"a": a, "b": b}
	var unit: Vector2 = dir / len
	return {
		"a": a + unit * shorten,
		"b": b - unit * shorten
	}

func _draw_embedded_trace(a: Vector2, b: Vector2, owner_id: int) -> void:
	var points: Array[Vector2] = _build_trace_points(a, b)
	if points.size() < 2:
		return
	var owner_col: Color = _owner_color(owner_id)
	var trench_col: Color = CIRCUIT_TRENCH_COLOR
	trench_col.a = clampf(alpha * 0.40, 0.0, 1.0)
	var surface_col: Color = CIRCUIT_SURFACE_COLOR
	surface_col.a = clampf(alpha * substrate_alpha, 0.0, 1.0)
	var glow_col: Color = owner_col
	glow_col.a = clampf(alpha * glow_alpha, 0.0, 1.0)
	var tint_col: Color = owner_col
	tint_col.a = clampf(alpha * tint_alpha, 0.0, 1.0)
	_draw_path(points, trench_col, trace_width_px + trench_extra_px)
	_draw_path(points, surface_col, trace_width_px + 0.8)
	_draw_path(points, glow_col, trace_width_px + 0.45)
	_draw_path(points, tint_col, trace_width_px)
	_draw_trace_branches(points, surface_col, glow_col)
	draw_circle(points[0], via_radius_px, surface_col)
	draw_circle(points[0], maxf(0.6, via_radius_px - 0.5), tint_col)
	var last_idx: int = points.size() - 1
	draw_circle(points[last_idx], via_radius_px, surface_col)
	draw_circle(points[last_idx], maxf(0.6, via_radius_px - 0.5), tint_col)

func _build_trace_points(a: Vector2, b: Vector2) -> Array[Vector2]:
	var dir: Vector2 = b - a
	var len: float = dir.length()
	var points: Array[Vector2] = []
	if len < 0.001:
		points.append(a)
		points.append(b)
		return points
	var unit: Vector2 = dir / len
	var normal: Vector2 = Vector2(-unit.y, unit.x)
	var segment_count: int = clampi(int(round(len / maxf(8.0, trace_segment_len_px))), 2, 8)
	points.append(a)
	for i in range(1, segment_count):
		var t: float = float(i) / float(segment_count)
		var p: Vector2 = a.lerp(b, t)
		var center_bias: float = 1.0 - absf(2.0 * t - 1.0) * 0.30
		var sign: float = -1.0
		if i % 2 == 0:
			sign = 1.0
		var wobble: float = trace_wobble_px * center_bias
		p += normal * (sign * wobble)
		points.append(p)
	points.append(b)
	return points

func _draw_path(points: Array[Vector2], color: Color, width_px: float) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		var p0: Vector2 = points[i]
		var p1: Vector2 = points[i + 1]
		draw_line(p0, p1, color, width_px)

func _draw_trace_branches(points: Array[Vector2], surface_col: Color, glow_col: Color) -> void:
	if points.size() < 3:
		return
	var branch_width: float = maxf(0.6, trace_width_px * 0.75)
	for i in range(1, points.size() - 1):
		var prev: Vector2 = points[i - 1]
		var curr: Vector2 = points[i]
		var next: Vector2 = points[i + 1]
		var tangent: Vector2 = (next - prev).normalized()
		if tangent.length() < 0.001:
			continue
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		var sign: float = -1.0
		if i % 2 == 0:
			sign = 1.0
		var branch_start: Vector2 = curr + normal * (sign * 0.7)
		var branch_end: Vector2 = curr + normal * (sign * branch_len_px)
		draw_line(branch_start, branch_end, surface_col, branch_width + 0.35)
		draw_line(branch_start, branch_end, glow_col, branch_width)
		draw_circle(branch_end, maxf(0.55, via_radius_px * 0.52), glow_col)
