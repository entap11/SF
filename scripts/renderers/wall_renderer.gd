@tool
extends Node2D
class_name WallRenderer

const SFLog := preload("res://scripts/util/sf_log.gd")
const PathGeometry = preload("res://scripts/renderers/wall_path_geometry.gd")
const Ribbon = preload("res://scripts/renderers/wall_ribbon.gd")

const SEGMENT_KEY_PRECISION: float = 10.0

var _segment_nodes_by_key: Dictionary = {}
var _segment_data_by_key: Dictionary = {}
var _last_keys: Array = []
var _ribbons: Array[Node2D] = []

func _ready() -> void:
	SFLog.allow_tag("WALL_VIS_SEGMENTS")
	SFLog.allow_tag("WALL_BLOCK_PULSE")

func set_wall_segments(segments: Array) -> void:
	var normalized: Array = _normalize_segments(segments)
	var unique: Dictionary = {}
	for segment in normalized:
		if (segment.a as Vector2).distance_to(segment.b) > 0.00001:
			unique[PathGeometry.edge_key(segment.a, segment.b)] = true
	var keys: Array = unique.keys()
	keys.sort()
	if keys == _last_keys:
		return
	_last_keys = keys
	var geometry: Dictionary = PathGeometry.build(normalized)
	for ribbon in _ribbons:
		ribbon.free()
	_ribbons.clear()
	_segment_nodes_by_key.clear()
	_segment_data_by_key.clear()
	for path in geometry.paths:
		var ribbon := Ribbon.new()
		add_child(ribbon)
		ribbon.setup(path.points, path.start_cap, path.end_cap)
		_ribbons.append(ribbon)
		for key in path.edges:
			_segment_nodes_by_key[key] = ribbon
	for p in geometry.junctions:
		var junction := Ribbon.new()
		add_child(junction)
		junction._brace(p, 0.0, true)
		_ribbons.append(junction)
	for segment in normalized:
		_segment_data_by_key[PathGeometry.edge_key(segment.a, segment.b)] = segment
	SFLog.warn("WALL_VIS_SEGMENTS", {"segments": keys.size(), "continuous_paths": geometry.paths.size(), "junctions": geometry.junctions.size()})

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
	for node_any in _ribbons:
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
