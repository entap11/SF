extends RefCounted
class_name EdgeEndpoints

const EDGE_TUCK_PX: float = 38.0

static func compute(from_anchor: Vector2, to_anchor: Vector2, tuck_px: float) -> Dictionary:
	var delta: Vector2 = to_anchor - from_anchor
	var len: float = delta.length()
	if len <= 0.001:
		return {
			"start": from_anchor,
			"end": to_anchor,
			"dir": Vector2.RIGHT,
			"len": 0.0
		}
	var dir: Vector2 = delta / len
	var start: Vector2 = from_anchor + dir * tuck_px
	var end: Vector2 = to_anchor - dir * tuck_px
	return {
		"start": start,
		"end": end,
		"dir": dir,
		"len": len
	}
