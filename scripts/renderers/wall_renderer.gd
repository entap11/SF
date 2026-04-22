extends Node2D
class_name WallRenderer

const SFLog := preload("res://scripts/util/sf_log.gd")
const WallGrowthBarrierSegmentScene: PackedScene = preload("res://scenes/renderers/WallGrowthBarrierSegment.tscn")

const SEGMENT_KEY_PRECISION: float = 10.0

var _segment_nodes_by_key: Dictionary = {}
var _segment_data_by_key: Dictionary = {}
var _last_sig: int = -1

func _ready() -> void:
	SFLog.allow_tag("WALL_VIS_SEGMENTS")
	SFLog.allow_tag("WALL_BLOCK_PULSE")

func set_wall_segments(segments: Array) -> void:
	var normalized: Array = _normalize_segments(segments)
	var sig: int = _compute_segment_sig(normalized)
	if sig == _last_sig:
		return
	_last_sig = sig
	var desired_keys: Dictionary = {}
	for seg_any in normalized:
		if typeof(seg_any) != TYPE_DICTIONARY:
			continue
		var seg: Dictionary = seg_any as Dictionary
		var a: Vector2 = seg.get("a", Vector2.ZERO) as Vector2
		var b: Vector2 = seg.get("b", Vector2.ZERO) as Vector2
		var key: String = _segment_key(a, b)
		desired_keys[key] = true
		_segment_data_by_key[key] = {
			"a": a,
			"b": b
		}
		var node: Node = _segment_nodes_by_key.get(key, null) as Node
		if node == null or not is_instance_valid(node):
			node = WallGrowthBarrierSegmentScene.instantiate() as Node
			node.name = "WallSegment_%s" % key.replace("|", "_").replace(":", "_")
			_segment_nodes_by_key[key] = node
			add_child(node)
		node.call("set_segment", a, b)
	for key_any in _segment_nodes_by_key.keys():
		var key_str: String = str(key_any)
		if desired_keys.has(key_str):
			continue
		var stale_node: Node = _segment_nodes_by_key.get(key_str, null) as Node
		if stale_node != null and is_instance_valid(stale_node):
			stale_node.queue_free()
		_segment_nodes_by_key.erase(key_str)
		_segment_data_by_key.erase(key_str)
	SFLog.warn("WALL_VIS_SEGMENTS", {
		"segments": normalized.size(),
		"instances": _segment_nodes_by_key.size()
	})

func set_wall_pairs(pairs: Array, hive_pos_by_id: Dictionary) -> void:
	var segments: Array = []
	for pair_any in pairs:
		if typeof(pair_any) != TYPE_VECTOR2I:
			continue
		var pair: Vector2i = pair_any as Vector2i
		var a_pos_any: Variant = hive_pos_by_id.get(int(pair.x), null)
		var b_pos_any: Variant = hive_pos_by_id.get(int(pair.y), null)
		if not (a_pos_any is Vector2 and b_pos_any is Vector2):
			continue
		segments.append({
			"a": a_pos_any as Vector2,
			"b": b_pos_any as Vector2
		})
	set_wall_segments(segments)

func tick_visuals(delta: float) -> void:
	for node_any in _segment_nodes_by_key.values():
		var node: Node = node_any as Node
		if node == null or not is_instance_valid(node):
			continue
		node.call("tick_visuals", delta)

func notify_blocked_attempt_path(a: Vector2, b: Vector2, kind: String = "attack") -> void:
	var key: String = _find_intersecting_segment_key(a, b)
	if key.is_empty():
		return
	var node: Node = _segment_nodes_by_key.get(key, null) as Node
	if node == null or not is_instance_valid(node):
		return
	node.call("trigger_block_pulse", kind)
	SFLog.warn("WALL_BLOCK_PULSE", {
		"key": key,
		"kind": kind,
		"path_a": a,
		"path_b": b
	})

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

func _segment_key(a: Vector2, b: Vector2) -> String:
	var first: Vector2 = a
	var second: Vector2 = b
	if a.x > b.x or (is_equal_approx(a.x, b.x) and a.y > b.y):
		first = b
		second = a
	return "%d:%d|%d:%d" % [
		int(round(first.x * SEGMENT_KEY_PRECISION)),
		int(round(first.y * SEGMENT_KEY_PRECISION)),
		int(round(second.x * SEGMENT_KEY_PRECISION)),
		int(round(second.y * SEGMENT_KEY_PRECISION))
	]

func _compute_segment_sig(segments: Array) -> int:
	var sig: int = segments.size()
	var mix: int = 0
	for seg_any in segments:
		if typeof(seg_any) != TYPE_DICTIONARY:
			continue
		var seg: Dictionary = seg_any as Dictionary
		var a: Vector2 = seg.get("a", Vector2.ZERO) as Vector2
		var b: Vector2 = seg.get("b", Vector2.ZERO) as Vector2
		mix = mix ^ hash(_segment_key(a, b))
	sig = (sig * 31 + mix) & 0x7fffffff
	return sig

func _find_intersecting_segment_key(a: Vector2, b: Vector2) -> String:
	var midpoint: Vector2 = (a + b) * 0.5
	var best_key: String = ""
	var best_dist: float = INF
	for key_any in _segment_data_by_key.keys():
		var key: String = str(key_any)
		var seg_any: Variant = _segment_data_by_key.get(key, null)
		if typeof(seg_any) != TYPE_DICTIONARY:
			continue
		var seg: Dictionary = seg_any as Dictionary
		var seg_a: Vector2 = seg.get("a", Vector2.ZERO) as Vector2
		var seg_b: Vector2 = seg.get("b", Vector2.ZERO) as Vector2
		if not _segments_intersect(a, b, seg_a, seg_b):
			continue
		var dist: float = _distance_to_segment(midpoint, seg_a, seg_b)
		if dist < best_dist:
			best_dist = dist
			best_key = key
	return best_key

func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab: Vector2 = b - a
	var cd: Vector2 = d - c
	var denom: float = ab.cross(cd)
	if absf(denom) <= 0.000001:
		var ac: Vector2 = c - a
		if absf(ac.cross(ab)) > 0.000001:
			return false
		var ab_len2: float = ab.length_squared()
		if ab_len2 <= 0.000001:
			return a.distance_squared_to(c) <= 0.000001 or a.distance_squared_to(d) <= 0.000001
		var t0: float = ac.dot(ab) / ab_len2
		var t1: float = (d - a).dot(ab) / ab_len2
		var t_min: float = minf(t0, t1)
		var t_max: float = maxf(t0, t1)
		return t_max >= 0.0 and t_min <= 1.0
	var ac2: Vector2 = c - a
	var t: float = ac2.cross(cd) / denom
	var u: float = ac2.cross(ab) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

func _distance_to_segment(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var seg: Vector2 = seg_b - seg_a
	var len2: float = seg.length_squared()
	if len2 <= 0.000001:
		return point.distance_to(seg_a)
	var t: float = clampf((point - seg_a).dot(seg) / len2, 0.0, 1.0)
	var proj: Vector2 = seg_a + seg * t
	return point.distance_to(proj)
