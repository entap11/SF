extends Node
class_name EdgeCacheSystem

const SFLog := preload("res://scripts/util/sf_log.gd")
const EdgeGeometry := preload("res://scripts/geo/edge_geometry.gd")
const HiveNodeScript := preload("res://scripts/hive/hive_node.gd")

@export var lane_start_cap_trim_px: float = 18.0
@export var lane_end_cap_trim_px: float = 18.0

var _last_sig: String = ""

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
		"|".join(lane_sigs)
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
		var src_center_world: Vector2 = gs.hive_world_pos_by_id(src_id)
		var dst_center_world: Vector2 = gs.hive_world_pos_by_id(dst_id)
		var a: Vector2 = HiveNodeScript.lane_anchor_world_from_center(src_center_world)
		var b: Vector2 = HiveNodeScript.lane_anchor_world_from_center(dst_center_world)
		var forward: EdgeGeometry = EdgeGeometry.build(
			src_id,
			dst_id,
			a,
			b,
			lane_start_cap_trim_px,
			lane_end_cap_trim_px
		)
		var reverse: EdgeGeometry = EdgeGeometry.build(
			dst_id,
			src_id,
			b,
			a,
			lane_start_cap_trim_px,
			lane_end_cap_trim_px
		)
		if lane_id > 0:
			cache[lane_id] = forward
			cache[str(lane_id)] = forward
		cache[_lane_pair_key(src_id, dst_id)] = forward
		cache[_lane_pair_key(dst_id, src_id)] = reverse
	ops_state.call("set_edge_cache", cache)
	ops_state.call("bump_edge_cache_version", int(sig.hash()))
	SFLog.info("EDGE_CACHE_REBUILT", {"edges": cache.size()})
