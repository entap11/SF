@tool
extends RefCounted
## Groups exact existing segments into connected runs. Does not smooth/move them.
const PRECISION := 100000.0

static func key(p: Vector2) -> String:
	return "%d:%d" % [roundi(p.x * PRECISION), roundi(p.y * PRECISION)]

static func edge_key(a: Vector2, b: Vector2) -> String:
	var ka := key(a)
	var kb := key(b)
	return ka + "|" + kb if ka < kb else kb + "|" + ka

static func build(segments: Array) -> Dictionary:
	var edges: Dictionary = {}
	var points: Dictionary = {}
	var adjacency: Dictionary = {}
	for segment in segments:
		if not segment is Dictionary or not segment.get("a") is Vector2 or not segment.get("b") is Vector2: continue
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		if not a.is_finite() or not b.is_finite() or a.distance_to(b) < 0.00001: continue
		var ka := key(a)
		var kb := key(b)
		var id := edge_key(a, b)
		if edges.has(id): continue
		edges[id] = [ka, kb]
		points[ka] = a
		points[kb] = b
		for endpoint in [ka, kb]:
			if not adjacency.has(endpoint): adjacency[endpoint] = []
			adjacency[endpoint].append(id)
	var keys: Array = points.keys()
	keys.sort()
	for endpoint in keys: adjacency[endpoint].sort()
	var visited: Dictionary = {}
	var paths: Array = []
	# Split at true ends/junctions, then collect remaining closed rings.
	for cycles in [false, true]:
		for endpoint in keys:
			if not cycles and adjacency[endpoint].size() == 2: continue
			for first_edge in adjacency[endpoint]:
				if visited.has(first_edge): continue
				var vertices := PackedVector2Array([points[endpoint]])
				var path_edges: Array[String] = []
				var current: String = endpoint
				var next_edge: String = first_edge
				while not visited.has(next_edge):
					visited[next_edge] = true
					path_edges.append(next_edge)
					var pair: Array = edges[next_edge]
					current = pair[1] if pair[0] == current else pair[0]
					vertices.append(points[current])
					if adjacency[current].size() != 2: break
					var adjacent: Array = adjacency[current]
					next_edge = adjacent[1] if adjacent[0] == next_edge else adjacent[0]
				paths.append({"points": vertices, "edges": path_edges,
					"start_cap": adjacency[endpoint].size() == 1, "end_cap": adjacency[current].size() == 1})
	var junctions := PackedVector2Array()
	for endpoint in keys:
		if adjacency[endpoint].size() > 2: junctions.append(points[endpoint])
	return {"paths": paths, "junctions": junctions, "edges": edges.keys()}
