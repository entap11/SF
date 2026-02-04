extends RefCounted
class_name LaneGeometry

static func compute_endpoints(a: Vector2, b: Vector2, start_trim_px: float, end_trim_px: float) -> Dictionary:
	var dir: Vector2 = (b - a)
	var len: float = dir.length()
	if len <= 0.001:
		return {
			"a": a,
			"b": b,
			"start": a,
			"end": b,
			"dir": Vector2.ZERO,
			"normal": Vector2.ZERO,
			"len": 0.0
		}

	dir /= len
	var start: Vector2 = a + dir * start_trim_px
	var end: Vector2 = b + dir * end_trim_px

	# Perpendicular normal (right-hand). Useful for debugging unintended offsets.
	var normal: Vector2 = Vector2(-dir.y, dir.x)

	return {
		"a": a,
		"b": b,
		"start": start,
		"end": end,
		"dir": dir,
		"normal": normal,
		"len": (end - start).length()
	}
