class_name MapValidator
extends RefCounted

static func validate(map_data: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	if not map_data.has("hives") or map_data["hives"] == null or map_data["hives"].is_empty():
		errors.append("Hives list is missing or empty")
		return {"ok": false, "errors": errors}

	if not map_data.has("lanes") or map_data["lanes"] == null or map_data["lanes"].is_empty():
		errors.append("Lanes list is missing or empty")
		return {"ok": false, "errors": errors}

	var hives: Array = map_data["hives"]
	var lanes: Array = map_data["lanes"]
	var towers: Array = map_data.get("towers", [])
	var barracks: Array = map_data.get("barracks", [])

	var hive_ids: Dictionary = {}

	for hive_v in hives:
		if typeof(hive_v) != TYPE_DICTIONARY:
			errors.append("Hive entry is not a Dictionary")
			continue
		var hive: Dictionary = hive_v
		if not hive.has("id"):
			errors.append("Hive missing id")
			continue
		var hid: int = int(hive["id"])
		if hive_ids.has(hid):
			errors.append("Duplicate hive id: %d" % hid)
		else:
			hive_ids[hid] = true

	if hive_ids.size() == 0:
		errors.append("No valid hive ids")
		return {"ok": false, "errors": errors}

	var lane_pairs: Dictionary = {}
	var adjacency: Dictionary = {}
	for hid in hive_ids.keys():
		adjacency[hid] = []

	for lane_v in lanes:
		if typeof(lane_v) != TYPE_DICTIONARY:
			errors.append("Lane entry is not a Dictionary")
			continue
		var lane: Dictionary = lane_v
		if not lane.has("a_id") or not lane.has("b_id"):
			errors.append("Lane missing endpoints")
			continue

		var a_id: int = int(lane["a_id"])
		var b_id: int = int(lane["b_id"])

		if a_id == b_id:
			errors.append("Lane connects hive to itself: %d" % a_id)
			continue
		if not hive_ids.has(a_id) or not hive_ids.has(b_id):
			errors.append("Lane references missing hive id: %d-%d" % [a_id, b_id])
			continue

		var min_id: int = min(a_id, b_id)
		var max_id: int = max(a_id, b_id)
		var key: String = "%d-%d" % [min_id, max_id]

		if lane_pairs.has(key):
			errors.append("Duplicate lane for pair: %s" % key)
			continue

		lane_pairs[key] = true
		adjacency[a_id].append(b_id)
		adjacency[b_id].append(a_id)

	if _component_count(adjacency) > 1:
		errors.append("Map has multiple disconnected components")

	_validate_structure_lists(towers, "Tower", hive_ids, errors)
	_validate_structure_lists(barracks, "Barracks", hive_ids, errors)

	return {"ok": errors.is_empty(), "errors": errors}


static func _component_count(adjacency: Dictionary) -> int:
	var visited: Dictionary = {}
	var count: int = 0

	for start in adjacency.keys():
		var start_id: int = int(start)
		if visited.has(start_id):
			continue
		count += 1
		var queue: Array[int] = [start_id]
		visited[start_id] = true

		while not queue.is_empty():
			var current: int = int(queue.pop_front())
			for neighbor in adjacency[current]:
				var neighbor_id: int = int(neighbor)
				if not visited.has(neighbor_id):
					visited[neighbor_id] = true
					queue.append(neighbor_id)

	return count


static func _validate_structure_lists(structs: Array, label: String, hive_ids: Dictionary, errors: Array[String]) -> void:
	for s_v in structs:
		if typeof(s_v) != TYPE_DICTIONARY:
			errors.append("%s entry is not a Dictionary" % label)
			continue
		var s: Dictionary = s_v

		if not s.has("required_hive_ids") or typeof(s["required_hive_ids"]) != TYPE_ARRAY:
			if label == "Barracks" or label == "Tower":
				continue
			errors.append("%s missing required_hive_ids" % label)
			continue

		var req: Array = s["required_hive_ids"]
		if req.is_empty() and (label == "Barracks" or label == "Tower"):
			continue
		if req.size() < 3:
			errors.append("%s requires at least 3 hives" % label)
		if (label == "Barracks" or label == "Tower") and req.size() > 6:
			errors.append("%s requires at most 6 hives" % label)

		var seen: Dictionary = {}
		for hid_v in req:
			var id: int = int(hid_v)
			if seen.has(id):
				errors.append("%s required_hive_ids contains duplicate id %d" % [label, id])
			else:
				seen[id] = true
			if not hive_ids.has(id):
				errors.append("%s required_hive_ids references missing hive id %d" % [label, id])
