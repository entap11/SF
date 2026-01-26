class_name StructureControlSolver
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")
const TAU := PI * 2.0
const EPS := 0.000001

static func pick_min_enclosing_cycle(
	adj_lanes: Array,
	hive_positions: Dictionary,
	center: Vector2,
	min_len: int,
	max_len: int,
	structure_type: String,
	structure_id: int
) -> Dictionary:
	var graph: Dictionary = build_adj_graph(adj_lanes, hive_positions)
	var cycles: Array = enumerate_cycles(graph, min_len, max_len)
	if cycles.is_empty():
		return {"cycle_count": 0, "valid_count": 0, "ids": []}
	var best: Dictionary = {}
	var best_area: float = INF
	var best_perim: float = INF
	var best_len: int = 0
	var valid_count: int = 0
	for cycle in cycles:
		var ordered: Dictionary = _order_cycle_by_angle(cycle, hive_positions, center)
		var ids: Array = ordered.get("ids", [])
		var points: Array = ordered.get("points", [])
		if ids.size() < 3 or points.size() < 3:
			continue
		if _polygon_self_intersects(points):
			continue
		if not point_in_polygon(center, points):
			continue
		valid_count += 1
		var area: float = _polygon_area(points)
		var perim: float = _polygon_perimeter(points)
		if area < best_area or (is_equal_approx(area, best_area) and (perim < best_perim or (is_equal_approx(perim, best_perim) and ids.size() < best_len))):
			best_area = area
			best_perim = perim
			best_len = ids.size()
			best = {"ids": ids, "area": area, "perim": perim, "len": best_len}
	if best.is_empty():
		return {"cycle_count": cycles.size(), "valid_count": valid_count, "ids": []}
	_log_cycle_pick(structure_type, structure_id, best)
	best["cycle_count"] = cycles.size()
	best["valid_count"] = valid_count
	return best

static func pick_min_enclosing_cycle_from_nearest(
	hives: Array,
	lanes: Array,
	center: Vector2,
	structure_type: String,
	structure_id: int,
	base_radius_px: float,
	min_len: int,
	max_len: int,
	nearest_sizes: Array = [6, 8, 10]
) -> Dictionary:
	var entries: Array = []
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var hive_id: int = int(hive.get("id", -1))
		if hive_id <= 0:
			continue
		var pos_v: Variant = hive.get("pos", null)
		if not (pos_v is Vector2):
			continue
		var pos: Vector2 = pos_v as Vector2
		var d2: float = pos.distance_squared_to(center)
		entries.append({"id": hive_id, "pos": pos, "d2": d2})
	if entries.is_empty():
		_log_cycle_fail(structure_type, structure_id, "no_hives", 0)
		return {"ids": []}
	entries.sort_custom(Callable(StructureControlSolver, "_nearest_entry_less"))
	var sizes: Array = nearest_sizes
	if sizes.is_empty():
		sizes = [6, 8, 10]
	for size_any in sizes:
		var target_n: int = int(size_any)
		if target_n <= 0:
			continue
		var n: int = mini(target_n, entries.size())
		if n < min_len:
			_log_cycle_fail(structure_type, structure_id, "too_few_hives", n)
			continue
		var hive_positions: Dictionary = {}
		var id_set: Dictionary = {}
		var ids: Array = []
		for i in range(n):
			var entry: Dictionary = entries[i] as Dictionary
			var entry_id: int = int(entry.get("id", -1))
			if entry_id <= 0:
				continue
			var entry_pos: Vector2 = entry.get("pos", Vector2.ZERO)
			ids.append(entry_id)
			id_set[entry_id] = true
			hive_positions[entry_id] = entry_pos
		_log_nearest_set(structure_type, structure_id, n, ids)
		var candidate_lanes: Array = _candidate_lanes_from_set(lanes, id_set, hive_positions, center, base_radius_px)
		if candidate_lanes.is_empty():
			_log_cycle_fail(structure_type, structure_id, "no_lanes", n)
			continue
		var result: Dictionary = pick_min_enclosing_cycle(
			candidate_lanes,
			hive_positions,
			center,
			min_len,
			max_len,
			structure_type,
			structure_id
		)
		var picked: Array = result.get("ids", [])
		if picked.is_empty():
			var cycle_count: int = int(result.get("cycle_count", 0))
			var valid_count: int = int(result.get("valid_count", 0))
			var reason: String = "no_enclosing"
			if cycle_count == 0:
				reason = "no_cycles"
			elif valid_count == 0:
				reason = "no_enclosing"
			_log_cycle_fail(structure_type, structure_id, reason, n)
			continue
		result["N"] = n
		return result
	return {"ids": []}

static func _candidate_lanes_from_set(
	lanes: Array,
	id_set: Dictionary,
	hive_positions: Dictionary,
	center: Vector2,
	base_radius_px: float
) -> Array:
	var out: Array = []
	for lane_any in lanes:
		var lane_id: int = -1
		var a_id: int = -1
		var b_id: int = -1
		if lane_any is Dictionary:
			var d: Dictionary = lane_any as Dictionary
			lane_id = int(d.get("lane_id", d.get("id", -1)))
			a_id = int(d.get("a_id", d.get("from", d.get("from_hive", 0))))
			b_id = int(d.get("b_id", d.get("to", d.get("to_hive", 0))))
		elif lane_any is Object:
			var obj: Object = lane_any as Object
			var a_v: Variant = obj.get("a_id")
			var b_v: Variant = obj.get("b_id")
			var id_v: Variant = obj.get("id")
			if id_v == null:
				id_v = obj.get("lane_id")
			if a_v != null:
				a_id = int(a_v)
			if b_v != null:
				b_id = int(b_v)
			if id_v != null:
				lane_id = int(id_v)
		if a_id <= 0 or b_id <= 0:
			continue
		if not id_set.has(a_id) or not id_set.has(b_id):
			continue
		if base_radius_px > 0.0:
			if hive_positions.has(a_id) and hive_positions.has(b_id):
				var a_pos: Vector2 = hive_positions[a_id]
				var b_pos: Vector2 = hive_positions[b_id]
				if segment_intersects_circle(a_pos, b_pos, center, base_radius_px):
					continue
		out.append({
			"lane_id": lane_id,
			"a_id": a_id,
			"b_id": b_id
		})
	return out

static func _nearest_entry_less(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("d2", 0.0)) < float(b.get("d2", 0.0))

static func _log_nearest_set(structure_type: String, structure_id: int, n: int, ids: Array) -> void:
	var event := _log_event_name(structure_type, "NEAREST_SET")
	var payload := {"id": structure_id, "N": n, "ids": ids}
	if structure_type != "tower":
		payload["type"] = structure_type
	SFLog.info(event, payload)

static func _log_cycle_pick(structure_type: String, structure_id: int, best: Dictionary) -> void:
	var event := _log_event_name(structure_type, "CYCLE_PICK")
	var payload := {
		"id": structure_id,
		"ids": best.get("ids", []),
		"area": best.get("area", 0.0),
		"perim": best.get("perim", 0.0),
		"len": best.get("len", 0)
	}
	if structure_type != "tower":
		payload["type"] = structure_type
	SFLog.info(event, payload)

static func _log_cycle_fail(structure_type: String, structure_id: int, reason: String, n: int) -> void:
	var event := _log_event_name(structure_type, "CYCLE_FAIL")
	var payload := {"id": structure_id, "reason": reason, "N": n}
	if structure_type != "tower":
		payload["type"] = structure_type
	SFLog.info(event, payload)

static func _log_event_name(structure_type: String, suffix: String) -> String:
	if structure_type == "tower":
		return "TOWER_%s" % suffix
	return "STRUCT_%s" % suffix

static func distance_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= EPS:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	var proj := a + ab * t
	return p.distance_to(proj)

static func segment_intersects_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	if radius <= 0.0:
		return false
	return distance_point_to_segment(center, a, b) <= radius

static func _order_cycle_by_angle(cycle: Array, hive_positions: Dictionary, center: Vector2) -> Dictionary:
	var entries: Array = []
	for hive_id_v in cycle:
		var hive_id: int = int(hive_id_v)
		if not hive_positions.has(hive_id):
			continue
		var pos: Vector2 = hive_positions[hive_id]
		var angle: float = atan2(pos.y - center.y, pos.x - center.x)
		var dist: float = pos.distance_squared_to(center)
		entries.append({
			"id": hive_id,
			"angle": angle,
			"dist": dist,
			"pos": pos
		})
	entries.sort_custom(Callable(StructureControlSolver, "_angle_entry_less"))
	var ids: Array = []
	var points: Array = []
	for entry_any in entries:
		var entry: Dictionary = entry_any as Dictionary
		ids.append(int(entry.get("id", -1)))
		points.append(entry.get("pos", Vector2.ZERO))
	return {"ids": ids, "points": points}

static func _angle_entry_less(a: Dictionary, b: Dictionary) -> bool:
	var angle_a: float = float(a.get("angle", 0.0))
	var angle_b: float = float(b.get("angle", 0.0))
	if is_equal_approx(angle_a, angle_b):
		return float(a.get("dist", 0.0)) < float(b.get("dist", 0.0))
	return angle_a < angle_b

static func _polygon_area(points: Array) -> float:
	var count := points.size()
	if count < 3:
		return 0.0
	var area := 0.0
	for i in range(count):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5

static func _polygon_perimeter(points: Array) -> float:
	var count := points.size()
	if count < 2:
		return 0.0
	var total := 0.0
	for i in range(count):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		total += a.distance_to(b)
	return total

static func _polygon_self_intersects(points: Array) -> bool:
	var count := points.size()
	if count < 4:
		return false
	for i in range(count):
		var a1: Vector2 = points[i]
		var a2: Vector2 = points[(i + 1) % count]
		for j in range(i + 1, count):
			if i == j:
				continue
			if (i + 1) % count == j or i == (j + 1) % count:
				continue
			var b1: Vector2 = points[j]
			var b2: Vector2 = points[(j + 1) % count]
			if _segments_intersect(a1, a2, b1, b2):
				return true
	return false

static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var o1 := _orient(a, b, c)
	var o2 := _orient(a, b, d)
	var o3 := _orient(c, d, a)
	var o4 := _orient(c, d, b)
	if (o1 > EPS and o2 < -EPS) or (o1 < -EPS and o2 > EPS):
		if (o3 > EPS and o4 < -EPS) or (o3 < -EPS and o4 > EPS):
			return true
	if absf(o1) <= EPS and _on_segment(a, b, c):
		return true
	if absf(o2) <= EPS and _on_segment(a, b, d):
		return true
	if absf(o3) <= EPS and _on_segment(c, d, a):
		return true
	if absf(o4) <= EPS and _on_segment(c, d, b):
		return true
	return false

static func _orient(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

static func _on_segment(a: Vector2, b: Vector2, p: Vector2) -> bool:
	return (
		minf(a.x, b.x) - EPS <= p.x
		and p.x <= maxf(a.x, b.x) + EPS
		and minf(a.y, b.y) - EPS <= p.y
		and p.y <= maxf(a.y, b.y) + EPS
	)

static func build_adj_graph(adj_lanes: Array, hive_positions: Dictionary) -> Dictionary:
	var nodes: Dictionary = {}
	var adj: Dictionary = {}
	var edge_len: Dictionary = {}
	for lane in adj_lanes:
		var a_id := int(lane.get("a_id", 0))
		var b_id := int(lane.get("b_id", 0))
		if a_id <= 0 or b_id <= 0:
			continue
		if not hive_positions.has(a_id) or not hive_positions.has(b_id):
			continue
		if not adj.has(a_id):
			adj[a_id] = []
		if not adj.has(b_id):
			adj[b_id] = []
		(adj[a_id] as Array).append(b_id)
		(adj[b_id] as Array).append(a_id)
		nodes[a_id] = true
		nodes[b_id] = true
		var key := _edge_key(a_id, b_id)
		if not edge_len.has(key):
			var a_pos: Vector2 = hive_positions[a_id]
			var b_pos: Vector2 = hive_positions[b_id]
			edge_len[key] = a_pos.distance_to(b_pos)
	var out_nodes: Array = []
	for node_id_v in nodes.keys():
		out_nodes.append(int(node_id_v))
	out_nodes.sort()
	for node_id in out_nodes:
		var list: Array = adj.get(node_id, [])
		list.sort()
		adj[node_id] = list
	return {
		"nodes": out_nodes,
		"adj": adj,
		"edge_len": edge_len
	}

static func enumerate_cycles(graph: Dictionary, min_len: int, max_len: int) -> Array:
	var nodes: Array = graph.get("nodes", [])
	var adj: Dictionary = graph.get("adj", {})
	var cycles: Array = []
	var seen: Dictionary = {}
	for start_v in nodes:
		var start_id := int(start_v)
		var visited: Dictionary = {}
		var path: Array = []
		_dfs_cycles(start_id, start_id, adj, visited, path, min_len, max_len, seen, cycles)
	return cycles

static func cycle_points(cycle: Array, hive_positions: Dictionary) -> Array:
	var points: Array = []
	for hive_id_v in cycle:
		var hive_id := int(hive_id_v)
		if hive_positions.has(hive_id):
			points.append(hive_positions[hive_id])
	return points

static func point_in_polygon(point: Vector2, poly: Array) -> bool:
	var count := poly.size()
	if count < 3:
		return false
	var inside := false
	var j := count - 1
	for i in range(count):
		var pi: Vector2 = poly[i]
		var pj: Vector2 = poly[j]
		var intersects := ((pi.y > point.y) != (pj.y > point.y))
		if intersects:
			var denom := (pj.y - pi.y)
			if absf(denom) < 0.000001:
				denom = 0.000001
			var x_at := (pj.x - pi.x) * (point.y - pi.y) / denom + pi.x
			if point.x < x_at:
				inside = not inside
		j = i
	return inside

static func cycle_perimeter(cycle: Array, graph: Dictionary, hive_positions: Dictionary) -> float:
	var edge_len: Dictionary = graph.get("edge_len", {})
	var total := 0.0
	if cycle.size() < 2:
		return total
	for i in range(cycle.size()):
		var a_id := int(cycle[i])
		var b_id := int(cycle[(i + 1) % cycle.size()])
		var key := _edge_key(a_id, b_id)
		if edge_len.has(key):
			total += float(edge_len[key])
		elif hive_positions.has(a_id) and hive_positions.has(b_id):
			var a_pos: Vector2 = hive_positions[a_id]
			var b_pos: Vector2 = hive_positions[b_id]
			total += a_pos.distance_to(b_pos)
	return total

static func _dfs_cycles(start_id: int, current_id: int, adj: Dictionary, visited: Dictionary, path: Array, min_len: int, max_len: int, seen: Dictionary, out_cycles: Array) -> void:
	visited[current_id] = true
	path.append(current_id)
	var neighbors: Array = adj.get(current_id, [])
	for neighbor_v in neighbors:
		var neighbor := int(neighbor_v)
		if neighbor == start_id:
			if path.size() >= min_len:
				if _min_id_in_cycle(path) == start_id:
					_record_cycle(path, seen, out_cycles)
		elif not visited.has(neighbor) and path.size() < max_len:
			_dfs_cycles(start_id, neighbor, adj, visited, path, min_len, max_len, seen, out_cycles)
	path.pop_back()
	visited.erase(current_id)

static func _record_cycle(cycle: Array, seen: Dictionary, out_cycles: Array) -> void:
	var normalized: Array = _normalize_cycle(cycle)
	var key := _cycle_key(normalized)
	if seen.has(key):
		return
	seen[key] = true
	out_cycles.append(normalized)

static func _normalize_cycle(cycle: Array) -> Array:
	var n := cycle.size()
	if n == 0:
		return []
	var min_id: int = int(cycle[0])
	var min_idx: int = 0
	for i in range(1, n):
		var v := int(cycle[i])
		if v < int(min_id):
			min_id = v
			min_idx = i
	var forward := _rotate_cycle(cycle, min_idx)
	var reversed := cycle.duplicate()
	reversed.reverse()
	var rev_idx := reversed.find(min_id)
	var backward := _rotate_cycle(reversed, rev_idx)
	if _cycle_lex_less(backward, forward):
		return backward
	return forward

static func _rotate_cycle(cycle: Array, idx: int) -> Array:
	var n := cycle.size()
	var out: Array = []
	for i in range(n):
		out.append(int(cycle[(idx + i) % n]))
	return out

static func _cycle_lex_less(a: Array, b: Array) -> bool:
	var n: int = min(a.size(), b.size())
	for i in range(n):
		var av := int(a[i])
		var bv := int(b[i])
		if av < bv:
			return true
		if av > bv:
			return false
	return a.size() < b.size()

static func _cycle_key(cycle: Array) -> String:
	var parts: Array = []
	for v in cycle:
		parts.append(str(int(v)))
	return ",".join(parts)

static func _min_id_in_cycle(cycle: Array) -> int:
	var min_id := int(cycle[0]) if cycle.size() > 0 else 0
	for v in cycle:
		min_id = mini(min_id, int(v))
	return min_id

static func _edge_key(a_id: int, b_id: int) -> String:
	var lo := mini(a_id, b_id)
	var hi := maxi(a_id, b_id)
	return "%d:%d" % [lo, hi]
