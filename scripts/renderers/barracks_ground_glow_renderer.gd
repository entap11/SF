# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# Renderers MUST NOT mutate state; they only render from render_model.
class_name BarracksGroundGlowRenderer
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const HiveRenderer := preload("res://scripts/renderers/hive_renderer.gd")

# Tune these
@export var alpha: float = 0.18
@export var glow_blend_additive: bool = true
@export var end_width_px: float = 46.0     # width near hive
@export var start_width_px: float = 56.0   # width near barracks
@export var shorten_px: float = 10.0       # pull ends inward (avoid overlapping node circles)
@export var z_layer: int = -10             # draw under lanes/hives

var _barracks: Array = []
var _hives_by_id: Dictionary = {} # id -> {world_pos, owner_id}

func _ready() -> void:
	z_index = z_layer
	if glow_blend_additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
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
		var control_v: Variant = b0.get("control_hive_ids", [])
		if typeof(control_v) == TYPE_ARRAY:
			sample_control_ids = control_v as Array
	SFLog.log_on_change_payload("BARRACKS_GLOW_MODEL", _barracks.size(), {
		"barracks_count": _barracks.size(),
		"sample_control_ids": sample_control_ids
	})

	queue_redraw()

func _draw() -> void:
	if _barracks.is_empty():
		return

	for b_any in _barracks:
		if typeof(b_any) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = b_any as Dictionary

		var barracks_pos_v: Variant = b.get("world_pos", b.get("pos_px", b.get("pos", Vector2.ZERO)))
		var barracks_pos: Vector2 = barracks_pos_v as Vector2 if barracks_pos_v is Vector2 else Vector2.ZERO
		var control_ids_v: Variant = b.get("control_hive_ids", [])
		if typeof(control_ids_v) != TYPE_ARRAY:
			continue

		for hid_v in control_ids_v as Array:
			var hid: int = int(hid_v)
			var hinfo: Dictionary = _hives_by_id.get(hid, {})
			if hinfo.is_empty():
				continue

			var hive_pos: Vector2 = hinfo.get("world_pos", Vector2.ZERO)
			var owner_id: int = int(hinfo.get("owner_id", 0))
			if owner_id == 0:
				continue # neutral: no glow

			var col: Color = _owner_color(owner_id, alpha)
			var poly: PackedVector2Array = _quad_between(
				barracks_pos,
				hive_pos,
				start_width_px,
				end_width_px,
				shorten_px
			)
			if not poly.is_empty():
				draw_colored_polygon(poly, col)

func _quad_between(a: Vector2, b: Vector2, a_width: float, b_width: float, shorten: float) -> PackedVector2Array:
	var dir: Vector2 = (b - a)
	var len: float = dir.length()
	if len < 1.0:
		return PackedVector2Array()

	dir /= len
	var n: Vector2 = Vector2(-dir.y, dir.x)

	var a2: Vector2 = a + dir * shorten
	var b2: Vector2 = b - dir * shorten

	var ha: float = a_width * 0.5
	var hb: float = b_width * 0.5

	var p0: Vector2 = a2 + n * ha
	var p1: Vector2 = a2 - n * ha
	var p2: Vector2 = b2 - n * hb
	var p3: Vector2 = b2 + n * hb

	return PackedVector2Array([p0, p1, p2, p3])

func _owner_color(owner_id: int, a: float) -> Color:
	var col: Color = HiveRenderer._owner_color(owner_id)
	col.a = a
	return col
