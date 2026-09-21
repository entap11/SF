@tool
extends RefCounted
## Pure authoring/runtime validation. Never repairs or mutates gameplay data.

const Schema = preload("res://scripts/maps/map_schema.gd")
const USAGES := ["campaign", "multiplayer", "both"]
const PRESETS := {
	"none": ["identity"],
	"mirror_x": ["identity", "mirror_x"],
	"mirror_y": ["identity", "mirror_y"],
	"half_turn": ["identity", "half_turn"],
	"both_mirrors": ["identity", "mirror_x", "half_turn", "mirror_y"],
	"quarter_turn": ["identity", "quarter_turn", "half_turn", "three_quarter_turn"]
}
const EPS := 0.00001

static func transform_point(p: Vector2, operation: String, center: Vector2) -> Vector2:
	var v := p - center
	match operation:
		"mirror_x": v.x = -v.x
		"mirror_y": v.y = -v.y
		"half_turn": v = -v
		"quarter_turn": v = Vector2(-v.y, v.x)
		"three_quarter_turn": v = Vector2(v.y, -v.x)
	return v + center

static func point(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	if value is Array and value.size() == 2 and _number(value[0]) and _number(value[1]):
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		for key in ["pos", "grid_pos"]:
			if value.has(key):
				return point(value[key])
		if _number(value.get("x")) and _number(value.get("y")):
			return Vector2(float(value.x), float(value.y))
	return Vector2(INF, INF)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func point_key(p: Vector2) -> String:
	return "%d,%d" % [roundi(p.x / EPS), roundi(p.y / EPS)]

static func segment_key(a: Vector2, b: Vector2) -> String:
	var ka := point_key(a)
	var kb := point_key(b)
	return ka + ":" + kb if ka < kb else kb + ":" + ka

static func hive_entries(data: Dictionary) -> Array:
	var source: Variant = data.get("nodes", data.get("entities", data.get("hives", [])))
	var out: Array = []
	if not source is Array:
		return out
	var defaults: Dictionary = data.get("defaults", {})
	for entry in source:
		if not entry is Dictionary:
			continue
		var kind := str(entry.get("kind", entry.get("type", "hive"))).to_lower()
		if not kind in ["hive", "npc_hive", "player_hive", "npc", "neutral"]:
			continue
		var owner := int(entry.get("owner_id", Schema.owner_to_owner_id(str(entry.get("owner", "NPC")))))
		out.append({"id": str(entry.get("id", "")), "pos": point(entry), "owner": owner,
			"power": int(entry.get("power", defaults.get("player_start_power" if owner > 0 else "npc_start_power", 10 if owner > 0 else 5)))})
	return out

static func walls(data: Dictionary) -> Array:
	var out: Array = Schema._walls_from_field(data.get("walls", []))
	if data.get("occluders") is Dictionary:
		out.append_array(Schema._walls_from_field(data.occluders.get("walls", [])))
	for key in ["entities", "nodes"]:
		out.append_array(Schema._walls_from_entities(data.get(key, [])))
	return Schema._wall_segments_from_walls(out)

static func supports_usage(data: Dictionary, usage: String) -> Dictionary:
	var designation := str(data.get("map_usage", ""))
	if not designation in USAGES:
		return {"ok": false, "reason": "map_usage_unclassified"}
	if usage not in ["campaign", "multiplayer"] or (designation != "both" and designation != usage):
		return {"ok": false, "reason": "map_usage_mismatch"}
	var result := validate(data, true)
	return {"ok": result.ok, "reason": "" if result.ok else "; ".join(result.errors)}

static func validate(data: Dictionary, require_usage: bool = true) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var usage := str(data.get("map_usage", ""))
	if not usage in USAGES:
		if require_usage or not usage.is_empty():
			errors.append("Choose map_usage: campaign, multiplayer, or both")
		return {"ok": errors.is_empty(), "errors": errors, "warnings": ["Unclassified legacy map; no multiplayer certification"]}
	for key in ["grid", "defaults", "layout_symmetry"]:
		if data.has(key) and not data[key] is Dictionary: errors.append("%s must be an object" % key)
	for key in ["nodes", "entities", "hives", "structure_slots", "start_slots", "towers", "barracks"]:
		if data.has(key) and not data[key] is Array: errors.append("%s must be an array" % key)
	if not errors.is_empty(): return {"ok": false, "errors": errors, "warnings": warnings}
	var grid: Dictionary = data.get("grid", {})
	var width := int(data.get("width", data.get("grid_w", data.get("grid_width", grid.get("w", 18)))))
	var height := int(data.get("height", data.get("grid_h", data.get("grid_height", grid.get("h", 28)))))
	if width != 18 or height != 28:
		errors.append("Author on the native 18x28 grid; runtime rescaling would change the approved layout")
	var hives := hive_entries(data)
	var by_pos: Dictionary = {}
	var by_id: Dictionary = {}
	var owners: Array[int] = []
	for hive in hives:
		var p: Vector2 = hive.pos
		if not p.is_finite() or p.x < 0 or p.y < 0 or p.x >= width or p.y >= height:
			errors.append("Hive %s has invalid/out-of-bounds coordinates" % hive.id)
			continue
		if p.distance_to(p.round()) > EPS:
			errors.append("Hive %s must occupy an integer cell; runtime rounds fractional hives" % hive.id)
		if hive.power < 1 or hive.owner < 0 or hive.owner > 4:
			errors.append("Hive %s needs positive power and owner NPC/P1/P2/P3/P4" % hive.id)
		var key := point_key(p)
		if by_pos.has(key): errors.append("Overlapping hive cell: %s" % str(p))
		if hive.id.is_empty() or by_id.has(hive.id): errors.append("Missing or duplicate hive ID: %s" % hive.id)
		by_pos[key] = hive
		by_id[hive.id] = hive
		if hive.owner > 0 and not owners.has(hive.owner): owners.append(hive.owner)
	if hives.is_empty(): errors.append("Place at least one hive")
	errors.append_array(validate_wall_fields(data))
	if not errors.is_empty(): return {"ok": false, "errors": errors, "warnings": warnings}
	var segments := walls(data)
	var segment_set: Dictionary = {}
	for segment in segments:
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		if not a.is_finite() or not b.is_finite() or a.distance_to(b) < EPS:
			errors.append("Invalid or zero-length wall")
			continue
		if minf(a.x, b.x) < -0.5 or minf(a.y, b.y) < -0.5 or maxf(a.x, b.x) > width - 0.5 or maxf(a.y, b.y) > height - 0.5:
			errors.append("Wall outside the playable board")
		segment_set[segment_key(a, b)] = true
		for hive in hives:
			if Schema._point_segment_distance(hive.pos, a, b) < 0.45:
				errors.append("Wall overlaps hive %s" % hive.id)
	var slot_rows: Array = []
	for category in ["structure_slots", "towers", "barracks"]:
		var source: Variant = data.get(category, [])
		if not source is Array:
			errors.append("%s must be an array" % category)
			continue
		for item in source:
			if not item is Dictionary:
				errors.append("Invalid %s entry" % category)
				continue
			var p := point(item)
			if not p.is_finite() or p.x < 0 or p.y < 0 or p.x >= width or p.y >= height or p.distance_to(p.round()) > EPS:
				errors.append("Invalid structure/slot position")
				continue
			if by_pos.has(point_key(p)): errors.append("Structure/slot overlaps hive")
			var row: Dictionary = item.duplicate(true)
			var allowed: Variant = row.get("allowed", ["tower", "barracks"])
			if not allowed is Array or allowed.is_empty():
				errors.append("Structure slot allowed must contain tower and/or barracks")
				continue
			for allowed_kind in allowed:
				if allowed_kind not in ["tower", "barracks"]: errors.append("Unknown structure slot kind")
			row["category"] = category
			row["pos"] = p
			slot_rows.append(row)
	if usage == "campaign":
		return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings}
	if owners.size() < 2: errors.append("Multiplayer needs at least two equivalent player starts")
	if owners.size() == 3: errors.append("Exact three-player rotational symmetry needs fractional hive positions unsupported by this grid")
	var symmetry: Variant = data.get("layout_symmetry", {})
	if not symmetry is Dictionary:
		errors.append("layout_symmetry must be an object")
		return {"ok": false, "errors": errors, "warnings": warnings}
	var kind := str(symmetry.get("kind", "none"))
	if not PRESETS.has(kind) or kind == "none":
		errors.append("Multiplayer requires an explicit supported symmetry preset")
		return {"ok": false, "errors": errors, "warnings": warnings}
	var center := point(symmetry.get("center", [8.5, 13.5]))
	if not center.is_finite(): errors.append("Invalid symmetry center")
	if not errors.is_empty(): return {"ok": false, "errors": errors, "warnings": warnings}
	var start_ids: Dictionary = {}
	for value in data.get("start_slots", []):
		var id := str(value.get("hive_id", value.get("id", ""))) if value is Dictionary else str(value)
		if not by_id.has(id): errors.append("Unknown start slot: %s" % id)
		start_ids[id] = true
	var reachable: Dictionary = {}
	for owner in owners: reachable[owner] = [owner]
	for operation in PRESETS[kind]:
		var owner_map: Dictionary = {0: 0}
		var valid := true
		for hive in hives:
			var other: Dictionary = by_pos.get(point_key(transform_point(hive.pos, operation, center)), {})
			if other.is_empty() or other.power != hive.power:
				valid = false
				break
			if start_ids.has(hive.id) != start_ids.has(other.id): valid = false
			if owner_map.has(hive.owner) and owner_map[hive.owner] != other.owner: valid = false
			owner_map[hive.owner] = other.owner
		if owner_map.get(0, 0) != 0: valid = false
		var mapped_owners: Array = []
		for owner in owners:
			var target := int(owner_map.get(owner, 0))
			if target <= 0 or mapped_owners.has(target): valid = false
			mapped_owners.append(target)
		for segment in segments:
			if not _has_segment(segments, segment_set, transform_point(segment.a, operation, center), transform_point(segment.b, operation, center)):
				valid = false
		for slot in slot_rows:
			var found := false
			for other in slot_rows:
				if _slot_matches(slot, other, by_id, operation, center, owner_map):
					found = true
					break
			if not found: valid = false
		if not valid:
			errors.append("%s does not preserve walls, hives, powers, structures and starting positions" % operation)
			continue
		for owner in owners:
			if not reachable[owner].has(owner_map[owner]): reachable[owner].append(owner_map[owner])
	for owner in owners:
		if reachable[owner].size() != owners.size():
			errors.append("Player %d is not geometrically equivalent to every other start" % owner)
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings, "player_orbits": reachable}

static func validate_wall_fields(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var sources: Array = [data.get("walls", [])]
	if data.get("occluders") is Dictionary: sources.append(data.occluders.get("walls", []))
	for source in sources:
		if not source is Array and not source is Dictionary:
			errors.append("Walls must be an array or a vertical/horizontal object")
			continue
		var rows: Array = source if source is Array else []
		if source is Dictionary:
			for axis in ["vertical", "horizontal"]:
				if not source.get(axis, []) is Array:
					errors.append("Wall axis entries must be arrays")
					continue
				for entry in source.get(axis, []):
					if not entry is Dictionary:
						errors.append("Invalid wall entry")
						continue
					var copy: Dictionary = entry.duplicate(true)
					copy["dir"] = axis
					rows.append(copy)
		for entry in rows:
			if not entry is Dictionary:
				errors.append("Invalid wall entry")
				continue
			if entry.has("x1") or entry.has("x2"):
				for key in ["x1", "y1", "x2", "y2"]:
					if not _number(entry.get(key)): errors.append("Wall endpoints need four finite numbers")
			elif not _number(entry.get("x", entry.get("gx"))) or not _number(entry.get("y", entry.get("gy"))) or Schema._walls_from_field([entry]).is_empty():
				errors.append("Invalid wall coordinates or direction")
	return errors

static func _has_segment(segments: Array, keys: Dictionary, a: Vector2, b: Vector2) -> bool:
	if keys.has(segment_key(a, b)): return true
	# Vector2 uses float32; reflection can cross a quantization bucket by one ULP.
	# This numerical tolerance is 0.00064 world pixels, not an authoring allowance.
	for candidate in segments:
		if (a.distance_to(candidate.a) <= EPS and b.distance_to(candidate.b) <= EPS) or (a.distance_to(candidate.b) <= EPS and b.distance_to(candidate.a) <= EPS): return true
	return false

static func _slot_matches(a: Dictionary, b: Dictionary, hives: Dictionary, operation: String, center: Vector2, owner_map: Dictionary) -> bool:
	if a.category != b.category or transform_point(a.pos, operation, center).distance_to(b.pos) > EPS:
		return false
	for key in ["power", "tier"]:
		if a.get(key, 0) != b.get(key, 0): return false
	if int(b.get("owner_id", 0)) != int(owner_map.get(int(a.get("owner_id", 0)), -1)): return false
	var allowed_a: Array = a.get("allowed", ["tower", "barracks"]).duplicate()
	var allowed_b: Array = b.get("allowed", ["tower", "barracks"]).duplicate()
	allowed_a.sort()
	allowed_b.sort()
	if allowed_a != allowed_b: return false
	for key in ["control_hive_ids", "required_hive_ids"]:
		var positions_a: Array[String] = []
		var positions_b: Array[String] = []
		for id in a.get(key, []):
			if not hives.has(str(id)): return false
			positions_a.append(point_key(transform_point(hives[str(id)].pos, operation, center)))
		for id in b.get(key, []):
			if not hives.has(str(id)): return false
			positions_b.append(point_key(hives[str(id)].pos))
		positions_a.sort()
		positions_b.sort()
		if positions_a != positions_b: return false
	return true
