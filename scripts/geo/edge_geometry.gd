extends RefCounted
class_name EdgeGeometry

var src_id: int
var dst_id: int

var a: Vector2
var b: Vector2
var start: Vector2
var end: Vector2
var dir: Vector2
var normal: Vector2
var length: float

static func build(src_id_: int, dst_id_: int, a_: Vector2, b_: Vector2, start_trim_px: float, end_trim_px: float) -> EdgeGeometry:
	var e := EdgeGeometry.new()
	e.src_id = src_id_
	e.dst_id = dst_id_
	e.a = a_
	e.b = b_

	var v: Vector2 = (b_ - a_)
	var len: float = v.length()
	if len <= 0.001:
		e.dir = Vector2.ZERO
		e.normal = Vector2.ZERO
		e.start = a_
		e.end = b_
		e.length = 0.0
		return e

	e.dir = v / len
	e.normal = Vector2(-e.dir.y, e.dir.x)
	e.start = a_ + e.dir * start_trim_px
	e.end = b_ - e.dir * end_trim_px
	e.length = (e.end - e.start).length()
	return e
