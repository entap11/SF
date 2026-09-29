class_name BotObservationBuilder
extends RefCounted

const VisibilityAdapterScript := preload("res://scripts/bot/bot_ruleset_visibility_adapter.gd")

const SCHEMA_VERSION: int = 1

var _visibility_adapter: RefCounted = VisibilityAdapterScript.new()


func build(state: GameState, seat: int, ops_state: Object) -> Dictionary:
	if state == null:
		return {}
	var visibility: Dictionary = _visibility_adapter.call("build_context", ops_state, seat) as Dictionary
	var hives: Array[Dictionary] = []
	var visible_hive_by_id: Dictionary = {}
	for hive_any in state.hives:
		if not (hive_any is HiveData):
			continue
		var hive: HiveData = hive_any as HiveData
		var row: Dictionary = _visibility_adapter.call("visible_hive", hive, seat, visibility) as Dictionary
		hives.append(row)
		visible_hive_by_id[int(row.get("id", -1))] = row
	hives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("id", -1)) < int(b.get("id", -1))
	)
	var routes: Array[Dictionary] = []
	for lane_any in state.lanes:
		var route: Dictionary = _visible_route(lane_any, seat, visible_hive_by_id)
		if not route.is_empty():
			routes.append(route)
	routes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_lane: int = int(a.get("lane_id", -1))
		var b_lane: int = int(b.get("lane_id", -1))
		if a_lane != b_lane:
			return a_lane < b_lane
		var a_src: int = int(a.get("src_id", -1))
		var b_src: int = int(b.get("src_id", -1))
		if a_src != b_src:
			return a_src < b_src
		return int(a.get("dst_id", -1)) < int(b.get("dst_id", -1))
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"seat": seat,
		"observation_tick": int(state.tick),
		"observation_time_ms": maxi(0, int(int(state.get("_sim_time_us")) / 1000)),
		"visibility": visibility,
		"hives": hives,
		"routes": routes
	}


func _visible_route(lane_any: Variant, seat: int, hive_by_id: Dictionary) -> Dictionary:
	var lane_id: int = -1
	var a_id: int = -1
	var b_id: int = -1
	var send_a: bool = false
	var send_b: bool = false
	var a_pressure_milli: int = 0
	var b_pressure_milli: int = 0
	if lane_any is LaneData:
		var lane: LaneData = lane_any as LaneData
		lane_id = int(lane.id)
		a_id = int(lane.a_id)
		b_id = int(lane.b_id)
		send_a = bool(lane.send_a)
		send_b = bool(lane.send_b)
		a_pressure_milli = int(round(float(lane.a_pressure) * 1000.0))
		b_pressure_milli = int(round(float(lane.b_pressure) * 1000.0))
	elif typeof(lane_any) == TYPE_DICTIONARY:
		var lane: Dictionary = lane_any as Dictionary
		lane_id = int(lane.get("lane_id", lane.get("id", -1)))
		a_id = int(lane.get("a_id", -1))
		b_id = int(lane.get("b_id", -1))
		send_a = bool(lane.get("send_a", false))
		send_b = bool(lane.get("send_b", false))
		a_pressure_milli = int(round(float(lane.get("a_pressure", 0.0)) * 1000.0))
		b_pressure_milli = int(round(float(lane.get("b_pressure", 0.0)) * 1000.0))
	else:
		return {}
	var a_hive: Dictionary = hive_by_id.get(a_id, {}) as Dictionary
	var b_hive: Dictionary = hive_by_id.get(b_id, {}) as Dictionary
	if int(a_hive.get("owner_id", 0)) == seat and send_a:
		return _route_row(lane_id, a_id, b_id, send_b, a_pressure_milli, b_pressure_milli, a_hive, b_hive)
	if int(b_hive.get("owner_id", 0)) == seat and send_b:
		return _route_row(lane_id, b_id, a_id, send_a, b_pressure_milli, a_pressure_milli, b_hive, a_hive)
	return {}


func _route_row(
	lane_id: int,
	src_id: int,
	dst_id: int,
	counterflow: bool,
	outbound_pressure_milli: int,
	inbound_pressure_milli: int,
	src_hive: Dictionary,
	dst_hive: Dictionary
) -> Dictionary:
	return {
		"lane_id": lane_id,
		"src_id": src_id,
		"dst_id": dst_id,
		"src_power": int(src_hive.get("power", -1)),
		"dst_power": int(dst_hive.get("power", -1)),
		"dst_owner_id": int(dst_hive.get("owner_id", 0)),
		"counterflow": counterflow,
		"outbound_pressure_milli": outbound_pressure_milli,
		"inbound_pressure_milli": inbound_pressure_milli,
		"pressure_balance_milli": outbound_pressure_milli - inbound_pressure_milli
	}
