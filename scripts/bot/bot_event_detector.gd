class_name BotEventDetector
extends RefCounted

const ROUTE_BECAME_LOSING: String = "route_became_losing"


func detect(
	previous: Dictionary,
	current: Dictionary,
	profile: Dictionary,
	first_event_id: int
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var previous_losing: Dictionary = _losing_routes(previous, profile)
	var current_losing: Dictionary = _losing_routes(current, profile)
	var keys: Array = current_losing.keys()
	keys.sort()
	var next_id: int = first_event_id
	for key_any in keys:
		var key: String = str(key_any)
		if previous_losing.has(key):
			continue
		var route: Dictionary = current_losing.get(key, {}) as Dictionary
		events.append({
			"event_id": next_id,
			"kind": ROUTE_BECAME_LOSING,
			"event_tick": int(current.get("observation_tick", -1)),
			"observable_tick": int(current.get("observation_tick", -1)),
			"observed_time_ms": int(current.get("observation_time_ms", 0)),
			"lane_id": int(route.get("lane_id", -1)),
			"src_id": int(route.get("src_id", -1)),
			"dst_id": int(route.get("dst_id", -1)),
			"evidence": {
				"counterflow": bool(route.get("counterflow", false)),
				"pressure_balance_milli": int(route.get("pressure_balance_milli", 0)),
				"src_power": int(route.get("src_power", -1)),
				"dst_power": int(route.get("dst_power", -1))
			}
		})
		next_id += 1
	return events


func route_is_losing(observation: Dictionary, src_id: int, dst_id: int, profile: Dictionary) -> bool:
	return _losing_routes(observation, profile).has(_route_key(src_id, dst_id))


func _losing_routes(observation: Dictionary, profile: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if observation.is_empty():
		return out
	var pressure_margin: int = maxi(0, int(profile.get("adaptive_losing_pressure_margin_milli", 2000)))
	var power_margin: int = maxi(0, int(profile.get("adaptive_losing_power_margin", 6)))
	var reserve_power: int = maxi(1, int(profile.get("adaptive_source_reserve_power", 8)))
	var routes_any: Variant = observation.get("routes", [])
	if typeof(routes_any) != TYPE_ARRAY:
		return out
	for route_any in routes_any as Array:
		if typeof(route_any) != TYPE_DICTIONARY:
			continue
		var route: Dictionary = route_any as Dictionary
		if not bool(route.get("counterflow", false)):
			continue
		var pressure_losing: bool = int(route.get("pressure_balance_milli", 0)) <= -pressure_margin
		var src_power: int = int(route.get("src_power", -1))
		var dst_power: int = int(route.get("dst_power", -1))
		var power_losing: bool = src_power >= 0 and dst_power >= 0 and (
			src_power <= reserve_power or dst_power - src_power >= power_margin
		)
		if not pressure_losing and not power_losing:
			continue
		var src_id: int = int(route.get("src_id", -1))
		var dst_id: int = int(route.get("dst_id", -1))
		out[_route_key(src_id, dst_id)] = route.duplicate(true)
	return out


func _route_key(src_id: int, dst_id: int) -> String:
	return "%d|%d" % [src_id, dst_id]
