extends Node2D
class_name WallRenderer

const SFLog := preload("res://scripts/util/sf_log.gd")

const WALL_THICKNESS_PX: float = 6.0
const WALL_END_INSET_PX: float = 0.0
const TEX_W: int = 32
const TEX_H: int = 8
const WALL_ALPHA_EPS: float = 0.02
const WALL_USE_TEXTURE: bool = false
const WALL_TEXTURE_PATHS: Array = [
	"res://assets/sprites/sf_skin_v1/straight_wall.tres",
	"res://assets/sprites/sf_skin_v1/wall_short.tres"
]
const LOG_WALL_VIS_TEXTURE: String = "WALL_VIS_TEXTURE"
const LOG_WALL_VIS_SEGMENTS: String = "WALL_VIS_SEGMENTS"
const LOG_WALL_VIS_PAIRS: String = "WALL_VIS_PAIRS"

var _tex: Texture2D = null
var _tex_path: String = ""
var _last_sig: int = -1
var _draw_segments: Array = []

func _ready() -> void:
	SFLog.allow_tag(LOG_WALL_VIS_TEXTURE)
	SFLog.allow_tag(LOG_WALL_VIS_SEGMENTS)
	SFLog.allow_tag(LOG_WALL_VIS_PAIRS)
	SFLog.allow_tag("WALL_TEXTURE_FALLBACK")
	_tex = _get_wall_texture()
	var tex_size: Vector2 = _tex.get_size() if _tex != null else Vector2.ZERO
	SFLog.warn(LOG_WALL_VIS_TEXTURE, {
		"tex_path": _tex_path,
		"tex_size": tex_size,
		"renderer_path": str(get_path()),
		"renderer_z": z_index,
		"renderer_visible": visible,
		"draw_mode": "texture_rect" if WALL_USE_TEXTURE else "solid_line"
	})

func set_wall_segments(segments: Array) -> void:
	if segments == null or segments.is_empty():
		_draw_segments = []
		_last_sig = 0
		queue_redraw()
		return
	var sig: int = _compute_segment_sig(segments)
	if sig == _last_sig:
		return
	_last_sig = sig
	_draw_segments = _normalize_segments(segments)
	queue_redraw()
	var sample_a: Variant = null
	var sample_b: Variant = null
	if not _draw_segments.is_empty():
		var first: Dictionary = _draw_segments[0] as Dictionary
		sample_a = first.get("a", null)
		sample_b = first.get("b", null)
	SFLog.warn(LOG_WALL_VIS_SEGMENTS, {
		"segments_in": segments.size(),
		"instances": _draw_segments.size(),
		"tex_path": _tex_path,
		"tex_size": _tex.get_size() if _tex != null else Vector2.ZERO,
		"sample_a": sample_a,
		"sample_b": sample_b,
		"draw_mode": "texture_rect" if WALL_USE_TEXTURE else "solid_line"
	})

func set_wall_pairs(pairs: Array, hive_pos_by_id: Dictionary) -> void:
	if pairs == null or pairs.is_empty():
		_draw_segments = []
		_last_sig = 0
		queue_redraw()
		return
	var sig: int = _compute_sig(pairs, hive_pos_by_id)
	if sig == _last_sig:
		return
	_last_sig = sig
	_draw_segments = []
	for pair_any in pairs:
		if typeof(pair_any) != TYPE_VECTOR2I:
			continue
		var pair: Vector2i = pair_any as Vector2i
		var a_id: int = int(pair.x)
		var b_id: int = int(pair.y)
		var a_pos_any: Variant = hive_pos_by_id.get(a_id, null)
		var b_pos_any: Variant = hive_pos_by_id.get(b_id, null)
		if not (a_pos_any is Vector2 and b_pos_any is Vector2):
			continue
		_draw_segments.append({
			"a": a_pos_any as Vector2,
			"b": b_pos_any as Vector2
		})
	queue_redraw()
	SFLog.warn(LOG_WALL_VIS_PAIRS, {
		"pairs_in": pairs.size(),
		"instances": _draw_segments.size(),
		"tex_path": _tex_path,
		"tex_size": _tex.get_size() if _tex != null else Vector2.ZERO,
		"draw_mode": "texture_rect" if WALL_USE_TEXTURE else "solid_line"
	})

func _draw() -> void:
	if _draw_segments.is_empty():
		return
	if _tex == null:
		_tex = _get_wall_texture()
	if _tex == null:
		return
	for seg_any in _draw_segments:
		if typeof(seg_any) != TYPE_DICTIONARY:
			continue
		var seg: Dictionary = seg_any as Dictionary
		var a_any: Variant = seg.get("a", null)
		var b_any: Variant = seg.get("b", null)
		if not (a_any is Vector2 and b_any is Vector2):
			continue
		var p0: Vector2 = a_any as Vector2
		var p1: Vector2 = b_any as Vector2
		var dir: Vector2 = p1 - p0
		var len: float = dir.length()
		if len <= 0.01:
			continue
		var eff_len: float = maxf(0.0, len - 2.0 * WALL_END_INSET_PX)
		if eff_len <= 0.01:
			continue
		var draw_a: Vector2 = p0
		var draw_b: Vector2 = p1
		if WALL_END_INSET_PX > 0.0:
			var dn: Vector2 = dir / len
			draw_a = p0 + dn * WALL_END_INSET_PX
			draw_b = p1 - dn * WALL_END_INSET_PX
		if not WALL_USE_TEXTURE:
			draw_line(draw_a, draw_b, Color(0.31, 0.10, 0.56, 0.95), WALL_THICKNESS_PX, true)
			continue
		var mid: Vector2 = (p0 + p1) * 0.5
		var ang: float = dir.angle()
		draw_set_transform(mid, ang, Vector2.ONE)
		draw_texture_rect(
			_tex,
			Rect2(Vector2(-eff_len * 0.5, -WALL_THICKNESS_PX * 0.5), Vector2(eff_len, WALL_THICKNESS_PX)),
			false,
			Color.WHITE
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _normalize_segments(segments: Array) -> Array:
	var out: Array = []
	for seg_any in segments:
		if typeof(seg_any) != TYPE_DICTIONARY:
			continue
		var seg: Dictionary = seg_any as Dictionary
		var a_any: Variant = seg.get("a", null)
		var b_any: Variant = seg.get("b", null)
		if not (a_any is Vector2 and b_any is Vector2):
			continue
		out.append({
			"a": a_any as Vector2,
			"b": b_any as Vector2
		})
	return out

func _compute_segment_sig(segments: Array) -> int:
	var sig: int = segments.size()
	var mix: int = 0
	for seg_any in segments:
		if typeof(seg_any) != TYPE_DICTIONARY:
			continue
		var seg: Dictionary = seg_any as Dictionary
		var a_any: Variant = seg.get("a", null)
		var b_any: Variant = seg.get("b", null)
		if not (a_any is Vector2 and b_any is Vector2):
			continue
		var a: Vector2 = a_any as Vector2
		var b: Vector2 = b_any as Vector2
		var ax: int = int(round(a.x))
		var ay: int = int(round(a.y))
		var bx: int = int(round(b.x))
		var by: int = int(round(b.y))
		mix = mix ^ (ax * 7 + ay * 13 + bx * 17 + by * 19)
	sig = (sig * 31 + mix) & 0x7fffffff
	return sig

func _compute_sig(pairs: Array, hive_pos_by_id: Dictionary) -> int:
	var sig: int = pairs.size()
	var mix: int = 0
	for pair_any in pairs:
		if typeof(pair_any) != TYPE_VECTOR2I:
			continue
		var pair: Vector2i = pair_any as Vector2i
		var a_id: int = int(pair.x)
		var b_id: int = int(pair.y)
		var a_pos_any: Variant = hive_pos_by_id.get(a_id, null)
		var b_pos_any: Variant = hive_pos_by_id.get(b_id, null)
		var ax: int = 0
		var ay: int = 0
		var bx: int = 0
		var by: int = 0
		if a_pos_any is Vector2:
			var av: Vector2 = a_pos_any as Vector2
			ax = int(round(av.x))
			ay = int(round(av.y))
		if b_pos_any is Vector2:
			var bv: Vector2 = b_pos_any as Vector2
			bx = int(round(bv.x))
			by = int(round(bv.y))
		mix = mix ^ ((a_id * 31 + b_id * 131) ^ (ax * 7 + ay * 13 + bx * 17 + by * 19))
	sig = (sig * 31 + mix) & 0x7fffffff
	return sig

func _get_wall_texture() -> Texture2D:
	if _tex != null:
		return _tex
	for path in WALL_TEXTURE_PATHS:
		var loaded: Resource = ResourceLoader.load(path)
		if loaded is Texture2D:
			var src_tex: Texture2D = loaded as Texture2D
			_tex_path = path
			_tex = _tighten_texture_alpha(src_tex)
			SFLog.info("WALL_TEXTURE_OK", {"path": path})
			return _tex
	SFLog.warn("WALL_TEXTURE_FALLBACK", {"paths": WALL_TEXTURE_PATHS})
	_tex = _get_placeholder_texture()
	_tex_path = "<placeholder>"
	return _tex

func _tighten_texture_alpha(src_tex: Texture2D) -> Texture2D:
	if src_tex == null:
		return src_tex
	var img: Image = src_tex.get_image()
	if img == null:
		return src_tex
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 0 or h <= 0:
		return src_tex
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			if c.a <= WALL_ALPHA_EPS:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0 or max_y < 0:
		return src_tex
	var crop_w: int = max_x - min_x + 1
	var crop_h: int = max_y - min_y + 1
	if crop_w <= 0 or crop_h <= 0:
		return src_tex
	if crop_w == w and crop_h == h:
		return src_tex
	var tight: Image = Image.create(crop_w, crop_h, false, Image.FORMAT_RGBA8)
	for yy in range(crop_h):
		for xx in range(crop_w):
			tight.set_pixel(xx, yy, img.get_pixel(min_x + xx, min_y + yy))
	SFLog.warn(LOG_WALL_VIS_TEXTURE, {
		"crop_from": Vector2i(w, h),
		"crop_to": Vector2i(crop_w, crop_h),
		"path": _tex_path
	})
	return ImageTexture.create_from_image(tight)

func _get_placeholder_texture() -> Texture2D:
	var img: Image = Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	var c1: Color = Color(1.0, 0.85, 0.1, 1.0)
	var c2: Color = Color(0.1, 0.1, 0.1, 1.0)
	for y in range(TEX_H):
		for x in range(TEX_W):
			var band: int = int((x + y * 2) / 4) % 2
			img.set_pixel(x, y, c1 if band == 0 else c2)
	return ImageTexture.create_from_image(img)
