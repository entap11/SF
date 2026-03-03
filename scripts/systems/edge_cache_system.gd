extends Node
class_name EdgeCacheSystem

const SFLog := preload("res://scripts/util/sf_log.gd")
const EdgeGeometry := preload("res://scripts/geo/edge_geometry.gd")
const HiveNodeScript := preload("res://scripts/hive/hive_node.gd")

@export var lane_start_cap_trim_px: float = 18.0
@export var lane_end_cap_trim_px: float = 18.0
const LANE_CAP_TRIM_RADIUS_RATIO: float = 0.45

var _last_sig: String = ""

func _walls_from_state(gs: GameState) -> Array:
	if gs == null:
		return []
	if gs.has_method("get"):
		var w_any: Variant = gs.get("walls")
		if typeof(w_any) == TYPE_ARRAY:
			return w_any as Array
	return []

func _wall_segments_from_walls(walls: Array) -> Array:
	var segs: Array = []
	for w_any in walls:
		if typeof(w_any) != TYPE_DICTIONARY:
			continue
		var w: Dictionary = w_any as Dictionary
		if w.has("x1") and w.has("y1") and w.has("x2") and w.has("y2"):
			segs.append({
				"a": Vector2(float(w.get("x1")), float(w.get("y1"))),
				"b": Vector2(float(w.get("x2")), float(w.get("y2")))
			})
			continue
		var dir := str(w.get("dir", "")).to_lower()
		var x := float(w.get("x", -999))
		var y := float(w.get("y", -999))
		if x < -100 or y < -100:
			continue
		if dir == "v" or dir == "vertical":
			var xline := x - 0.5
			segs.append({"a": Vector2(xline, y - 0.5), "b": Vector2(xline, y + 0.5)})
		elif dir == "h" or dir == "horizontal":
			var yline := y - 0.5
			segs.append({"a": Vector2(x - 0.5, yline), "b": Vector2(x + 0.5, yline)})
	return segs

func _blocked_edges_from_walls(walls: Array) -> Dictionary:
	var out: Dictionary = {}
	for w_any in walls:
		if typeof(w_any) != TYPE_DICTIONARY:
			continue
		var w: Dictionary = w_any as Dictionary
		var dir := str(w.get("dir", "")).to_lower()
		var x := int(w.get("x", -999))
		var y := int(w.get("y", -999))
		if x < 0 or y < 0:
			continue
		var a: String = ""
		var b: String = ""
		if dir == "v" or dir == "vertical":
			a = "%d,%d" % [x - 1, y]
			b = "%d,%d" % [x, y]
		elif dir == "h" or dir == "horizontal":
			a = "%d,%d" % [x, y - 1]
			b = "%d,%d" % [x, y]
		if a == "" or b == "":
			continue
		var key := (a + "|" + b) if a < b else (b + "|" + a)
		out[key] = true
	return out

func _seg_intersects(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var denom := ab.cross(cd)
	if absf(denom) <= 0.000001:
		return false
	var ac := c - a
	var t := ac.cross(cd) / denom
	var u := ac.cross(ab) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

func _segment_intersects_any_wall(a: Vector2, b: Vector2, wall_segments: Array) -> bool:
	for seg_any in wall_segments:
		if typeof(seg_any) != TYPE_DICTIONARY:
			continue
		var seg: Dictionary = seg_any as Dictionary
		var wa: Variant = seg.get("a", null)
		var wb: Variant = seg.get("b", null)
		if wa is Vector2 and wb is Vector2:
			if _seg_intersects(a, b, wa as Vector2, wb as Vector2):
				return true
	return false

func _lane_pair_key(src_id: int, dst_id: int) -> String:
	return "%d->%d" % [src_id, dst_id]

func _lane_sig_for(lane_any: Variant) -> String:
	var lane_id: int = -1
	var src_id: int = 0
	var dst_id: int = 0
	if lane_any is LaneData:
		var lane: LaneData = lane_any as LaneData
		lane_id = int(lane.id)
		src_id = int(lane.a_id)
		dst_id = int(lane.b_id)
	elif lane_any is Dictionary:
		var d: Dictionary = lane_any as Dictionary
		lane_id = int(d.get("lane_id", d.get("id", -1)))
		src_id = int(d.get("a_id", d.get("from", 0)))
		dst_id = int(d.get("b_id", d.get("to", 0)))
	return "%d:%d:%d" % [lane_id, src_id, dst_id]

func _cache_signature(gs: GameState) -> String:
	var lane_sigs: Array[String] = []
	for lane_any in gs.lanes:
		lane_sigs.append(_lane_sig_for(lane_any))
	lane_sigs.sort()
	return "%d|%d|%s|%s|%s" % [
		int(gs.get_instance_id()),
		int(gs.hives_set_version),
		str(snapped(lane_start_cap_trim_px, 0.001)),
		str(snapped(lane_end_cap_trim_px, 0.001)),
		"|".join([
			"|".join(lane_sigs),
			str(snapped(LANE_CAP_TRIM_RADIUS_RATIO, 0.001)),
			str(snapped(float(HiveNodeScript.LANE_ANCHOR_Y_PX), 0.001)),
			str(snapped(float(HiveNodeScript.LANE_ANCHOR_LEFT_EXTRA_Y_PX), 0.001)),
			str(snapped(float(HiveNodeScript.LANE_ANCHOR_RIGHT_EXTRA_Y_PX), 0.001))
		])
	]

func _resolve_ops_state(obj: Object) -> Object:
	if obj == null:
		return null
	if obj.has_method("set_edge_cache") and obj.has_method("get_state"):
		return obj
	return null

func _resolve_game_state(obj: Object) -> GameState:
	if obj == null:
		return null
	if obj is GameState:
		return obj as GameState
	if obj.has_method("get_state"):
		var st_any: Variant = obj.call("get_state")
		if st_any is GameState:
			return st_any as GameState
	return null

func rebuild_edge_cache(state: Object) -> void:
	var ops_state: Object = _resolve_ops_state(state)
	var gs: GameState = _resolve_game_state(state)
	if ops_state == null or gs == null:
		return
	if gs.hive_by_id.is_empty():
		gs.rebuild_indexes()
	var sig: String = _cache_signature(gs)
	if sig == _last_sig:
		return
	_last_sig = sig
	var cache: Dictionary = {}
	var walls: Array = _walls_from_state(gs)
	var wall_segments: Array = _wall_segments_from_walls(walls)
	var walls_count: int = walls.size()
	var blocked_edge_count: int = 0
	var edges_before: int = 0
	var edges_after: int = 0
	var blocked_lanes: int = 0
	var blocked_pairs_set: Dictionary = {}
	var blocked_pairs: Array = []
	for lane_any in gs.lanes:
		var lane_id: int = -1
		var src_id: int = 0
		var dst_id: int = 0
		if lane_any is LaneData:
			var lane: LaneData = lane_any as LaneData
			lane_id = int(lane.id)
			src_id = int(lane.a_id)
			dst_id = int(lane.b_id)
		elif lane_any is Dictionary:
			var d: Dictionary = lane_any as Dictionary
			lane_id = int(d.get("lane_id", d.get("id", -1)))
			src_id = int(d.get("a_id", d.get("from", 0)))
			dst_id = int(d.get("b_id", d.get("to", 0)))
		if src_id <= 0 or dst_id <= 0:
			continue
		var src_hive: HiveData = gs.find_hive_by_id(src_id)
		var dst_hive: HiveData = gs.find_hive_by_id(dst_id)
		if src_hive == null or dst_hive == null:
			continue
		edges_before += 1
		if not wall_segments.is_empty():
			var a_grid := Vector2(float(src_hive.grid_pos.x), float(src_hive.grid_pos.y))
			var b_grid := Vector2(float(dst_hive.grid_pos.x), float(dst_hive.grid_pos.y))
			if _segment_intersects_any_wall(a_grid, b_grid, wall_segments):
				blocked_edge_count += 1
				blocked_lanes += 1
				var lo := mini(src_id, dst_id)
				var hi := maxi(src_id, dst_id)
				var key := "%d:%d" % [lo, hi]
				if not blocked_pairs_set.has(key):
					blocked_pairs_set[key] = true
					blocked_pairs.append(Vector2i(lo, hi))
				continue
		var src_center_world: Vector2 = gs.hive_world_pos_by_id(src_id)
		var dst_center_world: Vector2 = gs.hive_world_pos_by_id(dst_id)
		var src_radius: float = maxf(0.0, float(src_hive.radius_px))
		var dst_radius: float = maxf(0.0, float(dst_hive.radius_px))
		var anchor_pair: Dictionary = HiveNodeScript.lane_anchor_pair_world(
			src_center_world,
			dst_center_world,
			null,
			src_radius,
			dst_radius
		)
		var a: Vector2 = anchor_pair.get("a", HiveNodeScript.lane_anchor_world_from_center(src_center_world))
		var b: Vector2 = anchor_pair.get("b", HiveNodeScript.lane_anchor_world_from_center(dst_center_world))
		var start_trim: float = minf(maxf(0.0, lane_start_cap_trim_px), maxf(0.0, src_radius * LANE_CAP_TRIM_RADIUS_RATIO))
		var end_trim: float = minf(maxf(0.0, lane_end_cap_trim_px), maxf(0.0, dst_radius * LANE_CAP_TRIM_RADIUS_RATIO))
		var forward: EdgeGeometry = EdgeGeometry.build(
			src_id,
			dst_id,
			a,
			b,
			start_trim,
			end_trim
		)
		var reverse: EdgeGeometry = EdgeGeometry.build(
			dst_id,
			src_id,
			b,
			a,
			end_trim,
			start_trim
		)
		if lane_id > 0:
			cache[lane_id] = forward
			cache[str(lane_id)] = forward
		cache[_lane_pair_key(src_id, dst_id)] = forward
		cache[_lane_pair_key(dst_id, src_id)] = reverse
		edges_after += 1
	ops_state.call("set_edge_cache", cache)
	ops_state.call("bump_edge_cache_version", int(sig.hash()))
	if ops_state.has_method("set_blocked_wall_pairs"):
		ops_state.call("set_blocked_wall_pairs", blocked_pairs)
	SFLog.info("EDGE_CACHE_REBUILT", {
		"edges": cache.size(),
		"edges_before": edges_before,
		"edges_after": edges_after,
		"walls_count": walls_count,
		"blocked_edge_count": blocked_edge_count,
		"blocked_lanes": blocked_lanes
	})
