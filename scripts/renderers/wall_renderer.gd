extends Node2D
class_name WallRenderer

const SFLog := preload("res://scripts/util/sf_log.gd")

const WALL_THICKNESS_PX: float = 6.0
const WALL_END_INSET_PX: float = 6.0
const TEX_W: int = 32
const TEX_H: int = 8

var _mmi: MultiMeshInstance2D = null
var _mm: MultiMesh = null
var _tex: Texture2D = null
var _last_sig: int = -1

func _ready() -> void:
	_mmi = MultiMeshInstance2D.new()
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.instance_count = 0
	_mmi.multimesh = _mm
	_mmi.texture = _get_placeholder_texture()
	_mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_mmi)

func set_wall_pairs(pairs: Array, hive_pos_by_id: Dictionary) -> void:
	if _mmi == null or _mm == null:
		return
	if pairs == null or pairs.is_empty():
		if _mm.instance_count != 0:
			_mm.instance_count = 0
		_last_sig = 0
		return
	var sig := _compute_sig(pairs, hive_pos_by_id)
	if sig == _last_sig:
		return
	_last_sig = sig
	_apply_pairs(pairs, hive_pos_by_id)

func _apply_pairs(pairs: Array, hive_pos_by_id: Dictionary) -> void:
	var tex_size: Vector2 = _mmi.texture.get_size() if _mmi.texture != null else Vector2(TEX_W, TEX_H)
	var tex_w := maxf(1.0, tex_size.x)
	var tex_h := maxf(1.0, tex_size.y)
	var transforms: Array[Transform2D] = []
	for pair_any in pairs:
		if typeof(pair_any) != TYPE_VECTOR2I:
			continue
		var pair: Vector2i = pair_any as Vector2i
		var a_id := int(pair.x)
		var b_id := int(pair.y)
		var a_pos: Variant = hive_pos_by_id.get(a_id, null)
		var b_pos: Variant = hive_pos_by_id.get(b_id, null)
		if not (a_pos is Vector2 and b_pos is Vector2):
			continue
		var p0: Vector2 = a_pos as Vector2
		var p1: Vector2 = b_pos as Vector2
		var dir := p1 - p0
		var len := dir.length()
		if len <= 0.01:
			continue
		var eff_len := maxf(0.0, len - 2.0 * WALL_END_INSET_PX)
		if eff_len <= 0.01:
			continue
		var angle := atan2(dir.y, dir.x)
		var mid := (p0 + p1) * 0.5
		var sx := eff_len / tex_w
		var sy := WALL_THICKNESS_PX / tex_h
		var xf := Transform2D(angle, mid)
		xf = xf.scaled(Vector2(sx, sy))
		transforms.append(xf)
	_mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		_mm.set_instance_transform_2d(i, transforms[i])
	SFLog.info("WALL_RENDER_REBUILD", {"count": transforms.size()})

func _compute_sig(pairs: Array, hive_pos_by_id: Dictionary) -> int:
	var sig := pairs.size()
	var mix := 0
	for pair_any in pairs:
		if typeof(pair_any) != TYPE_VECTOR2I:
			continue
		var pair: Vector2i = pair_any as Vector2i
		var a_id := int(pair.x)
		var b_id := int(pair.y)
		var a_pos: Variant = hive_pos_by_id.get(a_id, null)
		var b_pos: Variant = hive_pos_by_id.get(b_id, null)
		var ax := 0
		var ay := 0
		var bx := 0
		var by := 0
		if a_pos is Vector2:
			var av: Vector2 = a_pos as Vector2
			ax = int(round(av.x))
			ay = int(round(av.y))
		if b_pos is Vector2:
			var bv: Vector2 = b_pos as Vector2
			bx = int(round(bv.x))
			by = int(round(bv.y))
		mix = mix ^ ((a_id * 31 + b_id * 131) ^ (ax * 7 + ay * 13 + bx * 17 + by * 19))
	sig = (sig * 31 + mix) & 0x7fffffff
	return sig

func _get_placeholder_texture() -> Texture2D:
	if _tex != null:
		return _tex
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	var c1 := Color(1.0, 0.85, 0.1, 1.0)
	var c2 := Color(0.1, 0.1, 0.1, 1.0)
	for y in range(TEX_H):
		for x in range(TEX_W):
			var band := int((x + y * 2) / 4) % 2
			img.set_pixel(x, y, c1 if band == 0 else c2)
	_tex = ImageTexture.create_from_image(img)
	return _tex
