extends RefCounted
class_name LaneOverlapGaps

static func visible_intervals(
	start_pos: Vector2,
	end_pos: Vector2,
	lane_id: int,
	a_id: int,
	b_id: int,
	lane_z_index: int,
	lane_width_px: float,
	prepared_by_key: Dictionary,
	self_key: Variant,
	gap_extra_px: float,
	endpoint_ignore_t: float,
	min_segment_px: float
) -> Array:
	var intervals: Array = [Vector2(0.0, 1.0)]
	var length_px: float = start_pos.distance_to(end_pos)
	if length_px <= 0.001:
		return []
	var min_t: float = clampf(min_segment_px / length_px, 0.0, 0.45)
	for other_key in prepared_by_key.keys():
		if other_key == self_key:
			continue
		var other_any: Variant = prepared_by_key.get(other_key, null)
		if typeof(other_any) != TYPE_DICTIONARY:
			continue
		var other: Dictionary = other_any as Dictionary
		var other_a_id: int = int(other.get("a_id", 0))
		var other_b_id: int = int(other.get("b_id", 0))
		if share_hive_endpoint(a_id, b_id, other_a_id, other_b_id):
			continue
		var other_lane_id: int = int(other.get("lane_id", -1))
		var other_z: int = int(other.get("z_index", 0))
		if not other_occludes_current(lane_id, lane_z_index, other_lane_id, other_z, self_key, other_key):
			continue
		var other_start: Vector2 = other.get("a_pos", Vector2.ZERO) as Vector2
		var other_end: Vector2 = other.get("b_pos", Vector2.ZERO) as Vector2
		var hit: Dictionary = segment_intersection_t(start_pos, end_pos, other_start, other_end)
		if not bool(hit.get("hit", false)):
			continue
		var t: float = float(hit.get("t", 0.0))
		var u: float = float(hit.get("u", 0.0))
		if t <= endpoint_ignore_t or t >= 1.0 - endpoint_ignore_t:
			continue
		if u <= endpoint_ignore_t or u >= 1.0 - endpoint_ignore_t:
			continue
		var other_width: float = float(other.get("width", lane_width_px))
		var gap_t: float = ((maxf(lane_width_px, other_width) * 0.5) + gap_extra_px) / length_px
		intervals = subtract_interval(intervals, t - gap_t, t + gap_t, min_t)
		if intervals.is_empty():
			return intervals
	return intervals

static func share_hive_endpoint(a_id: int, b_id: int, other_a_id: int, other_b_id: int) -> bool:
	return a_id == other_a_id or a_id == other_b_id or b_id == other_a_id or b_id == other_b_id

static func other_occludes_current(
	lane_id: int,
	lane_z_index: int,
	other_lane_id: int,
	other_z_index: int,
	self_key: Variant,
	other_key: Variant
) -> bool:
	if other_z_index > lane_z_index:
		return true
	if other_z_index < lane_z_index:
		return false
	if other_lane_id != lane_id:
		return other_lane_id > lane_id
	return str(other_key) > str(self_key)

static func segment_intersection_t(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Dictionary:
	var r: Vector2 = b - a
	var s: Vector2 = d - c
	var denom: float = r.cross(s)
	if absf(denom) <= 0.0001:
		return {"hit": false}
	var ca: Vector2 = c - a
	var t: float = ca.cross(s) / denom
	var u: float = ca.cross(r) / denom
	if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0:
		return {"hit": false}
	return {"hit": true, "t": t, "u": u}

static func subtract_interval(intervals: Array, cut_start: float, cut_end: float, min_t: float) -> Array:
	var start_t: float = clampf(minf(cut_start, cut_end), 0.0, 1.0)
	var end_t: float = clampf(maxf(cut_start, cut_end), 0.0, 1.0)
	if end_t <= start_t:
		return intervals
	var out: Array = []
	for interval_any in intervals:
		if not (interval_any is Vector2):
			continue
		var interval: Vector2 = interval_any as Vector2
		var a: float = interval.x
		var b: float = interval.y
		if end_t <= a or start_t >= b:
			out.append(interval)
			continue
		if start_t - a >= min_t:
			out.append(Vector2(a, start_t))
		if b - end_t >= min_t:
			out.append(Vector2(end_t, b))
	return out
