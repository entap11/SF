extends RefCounted
class_name LaneTypes

static func make_lane(id: int, a_id: int, b_id: int, a_pos: Vector2, b_pos: Vector2) -> Dictionary:
	return {
		"id": id,
		"a_id": a_id,
		"b_id": b_id,
		"a_pos": a_pos,
		"b_pos": b_pos,
		# Directional intent flags (flow)
		"send_a": false,
		"send_b": false,
		# Visual split point (0..1). 0 means all A color, 1 means all B color.
		"split_t": 0.5,
		# Lane lifecycle helpers
		"created_ms": Time.get_ticks_msec(),
		"establish_a": false,
		"establish_b": false,
		"retract_a": false,
		"retract_b": false,
		"a_stream_len": 0.0,
		"b_stream_len": 0.0,
		"a_pressure": 0.0,
		"b_pressure": 0.0
	}

static func other_end_id(lane: Dictionary, hive_id: int) -> int:
	if int(lane.get("a_id", -1)) == hive_id:
		return int(lane.get("b_id", -1))
	return int(lane.get("a_id", -1))

static func is_endpoint(lane: Dictionary, hive_id: int) -> bool:
	return int(lane.get("a_id", -1)) == hive_id or int(lane.get("b_id", -1)) == hive_id

static func endpoint_pos(lane: Dictionary, hive_id: int) -> Vector2:
	if int(lane.get("a_id", -1)) == hive_id:
		return lane.get("a_pos", Vector2.ZERO)
	return lane.get("b_pos", Vector2.ZERO)

static func other_pos(lane: Dictionary, hive_id: int) -> Vector2:
	if int(lane.get("a_id", -1)) == hive_id:
		return lane.get("b_pos", Vector2.ZERO)
	return lane.get("a_pos", Vector2.ZERO)
