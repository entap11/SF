@tool
extends RefCounted
## Offline transformation of a retained draft into canonical map input.
const Layout = preload("res://scripts/maps/map_layout_contract.gd")

static func compile(draft: Dictionary) -> Dictionary:
	var out: Dictionary = draft.duplicate(true)
	var errors: Array[String] = []
	var notes: Array[String] = []
	for key in ["authoring", "layout_symmetry", "defaults", "grid"]:
		if draft.has(key) and not draft[key] is Dictionary: errors.append("%s must be an object" % key)
	for key in ["nodes", "entities", "structure_slots", "towers", "barracks"]:
		if draft.has(key) and not draft[key] is Array: errors.append("%s must be an array" % key)
	errors.append_array(Layout.validate_wall_fields(draft))
	if not errors.is_empty(): return {"ok": false, "errors": errors, "data": {}}
	var grid: Dictionary = draft.get("grid", {})
	if int(draft.get("width", grid.get("w", 18))) != 18 or int(draft.get("height", grid.get("h", 28))) != 28:
		return {"ok": false, "errors": ["Draft must use the native 18x28 grid; do not silently reinterpret a legacy grid"], "data": {}}
	var authoring: Dictionary = out.get("authoring", {})
	var symmetry: Dictionary = out.get("layout_symmetry", {"kind": "none", "center": [8.5, 13.5]})
	var kind := str(symmetry.get("kind", "none"))
	var center := Layout.point(symmetry.get("center", [8.5, 13.5]))
	if not Layout.PRESETS.has(kind) or not center.is_finite():
		return {"ok": false, "errors": ["Invalid symmetry preset or center"], "data": {}}
	var operations: Array = Layout.PRESETS[kind] if bool(authoring.get("single_sector", false)) else ["identity"]
	if operations.size() > 1 and (not out.get("towers", []).is_empty() or not out.get("barracks", []).is_empty()):
		errors.append("Sector authoring uses structure slots; remove separately authored towers/barracks")
	var nodes: Array = out.get("nodes", out.get("entities", []))
	var generated_nodes: Array = []
	var seen_nodes: Dictionary = {}
	var node_positions: Dictionary = {}
	for node in nodes:
		if not node is Dictionary:
			errors.append("Invalid node")
			continue
		var p := Layout.point(node)
		if not p.is_finite():
			errors.append("Invalid node coordinates")
			continue
		node_positions[str(node.get("id", ""))] = p
		for index in range(operations.size()):
			var position := Layout.transform_point(p, operations[index], center)
			var copy: Dictionary = node.duplicate(true)
			copy["pos"] = {"x": position.x, "y": position.y}
			copy.erase("x")
			copy.erase("y")
			copy.erase("grid_x")
			copy.erase("grid_y")
			copy.erase("grid_pos")
			copy["kind"] = str(copy.get("kind", copy.get("type", "hive")))
			if copy.kind in ["player_hive", "npc_hive"]: copy.kind = "hive"
			copy.erase("type")
			var owner := int(node.get("owner_id", Layout.Schema.owner_to_owner_id(str(node.get("owner", "NPC")))))
			if operations.size() > 1 and owner > 0:
				if owner > operations.size(): errors.append("Owner does not fit symmetry player count")
				owner = ((owner - 1) ^ index) + 1 if kind == "both_mirrors" else ((owner - 1 + index) % operations.size()) + 1
			copy["owner"] = "NPC" if owner == 0 else "P%d" % owner
			copy.erase("owner_id")
			copy["id"] = str(node.get("id", "hive")) + ("_s%d" % index if operations.size() > 1 else "")
			var key := Layout.point_key(position)
			if seen_nodes.has(key):
				var existing: Dictionary = seen_nodes[key]
				if existing.owner != copy.owner or existing.get("power", -1) != copy.get("power", -1) or existing.kind != copy.kind:
					errors.append("Symmetry creates conflicting nodes at %s; keep player starts off the symmetry axes" % str(position))
				continue
			seen_nodes[key] = copy
			generated_nodes.append(copy)
	out["nodes"] = generated_nodes
	out.erase("entities")
	out.erase("hives")
	out.erase("lanes") # Active lanes belong to simulation intents.
	var slots: Array = []
	var seen_slots: Dictionary = {}
	for slot in out.get("structure_slots", []):
		if not slot is Dictionary or not Layout.point(slot).is_finite():
			errors.append("Invalid structure slot")
			continue
		for index in range(operations.size()):
			var copy: Dictionary = slot.duplicate(true)
			var position := Layout.transform_point(Layout.point(slot), operations[index], center)
			copy["pos"] = {"x": position.x, "y": position.y}
			copy.erase("grid_pos")
			copy["id"] = str(slot.get("id", "slot")) + "_s%d" % index
			for key in ["control_hive_ids", "required_hive_ids"]:
				if not slot.has(key): continue
				copy[key] = []
				for id in slot[key]:
					if not node_positions.has(str(id)):
						errors.append("Unknown slot control hive: %s" % str(id))
						continue
					var node_key := Layout.point_key(Layout.transform_point(node_positions[str(id)], operations[index], center))
					copy[key].append(seen_nodes[node_key].id)
			var position_key := Layout.point_key(position)
			if not seen_slots.has(position_key):
				slots.append(copy)
				seen_slots[position_key] = copy
			elif seen_slots[position_key].get("allowed", []) != copy.get("allowed", []) or seen_slots[position_key].get("control_hive_ids", []) != copy.get("control_hive_ids", []):
				errors.append("Conflicting structure slots on symmetry axis")
	out["structure_slots"] = slots
	var wall_segments: Array = []
	var seen_segments: Dictionary = {}
	var strokes: Variant = authoring.get("wall_strokes", [])
	if not strokes is Array: errors.append("wall_strokes must be an array")
	else:
		for stroke in strokes:
			if not stroke is Dictionary or not stroke.get("points") is Array:
				errors.append("Wall stroke needs a points array")
				continue
			var points := PackedVector2Array()
			for raw in stroke.points:
				var p := Layout.point(raw)
				if not p.is_finite(): errors.append("Invalid wall point")
				else: points.append(p)
			if points.size() < 2:
				errors.append("Wall stroke needs at least two points")
				continue
			var clean := clean_stroke(points, bool(stroke.get("smooth", true)))
			notes.append("Wall %s: %d draft points → %d clean points; endpoints retained" % [str(stroke.get("id", "")), points.size(), clean.size()])
			for i in range(clean.size() - 1):
				for operation in operations:
					_append_wall(wall_segments, seen_segments, Layout.transform_point(clean[i], operation, center), Layout.transform_point(clean[i + 1], operation, center))
	# Explicit unsmoothed segments can coexist with strokes (corners, junctions).
	for segment in Layout.walls(draft):
		for operation in operations:
			_append_wall(wall_segments, seen_segments, Layout.transform_point(segment.a, operation, center), Layout.transform_point(segment.b, operation, center))
	out["walls"] = wall_segments
	out.erase("occluders")
	out.erase("authoring")
	out["_schema"] = "swarmfront.map.v1.xy"
	out["width"] = 18
	out["height"] = 28
	out["grid"] = {"w": 18, "h": 28, "quant": "full"}
	for node in generated_nodes:
		var p := Layout.point(node)
		if p.distance_to(p.round()) > Layout.EPS:
			out.grid.quant = "full_or_half"
			break
	out["symmetry"] = "none" # Already expanded; legacy lane builder must not mirror again.
	out["start_slots"] = []
	for node in generated_nodes:
		if node.owner != "NPC": out.start_slots.append(node.id)
	return {"ok": errors.is_empty(), "errors": errors, "warnings": notes, "data": out}

static func _append_wall(out: Array, seen: Dictionary, a: Vector2, b: Vector2) -> void:
	var key := Layout.segment_key(a, b)
	if a.distance_to(b) <= Layout.EPS or seen.has(key): return
	seen[key] = true
	out.append({"x1": a.x, "y1": a.y, "x2": b.x, "y2": b.y})

static func clean_stroke(points: PackedVector2Array, smooth: bool) -> PackedVector2Array:
	var clean := PackedVector2Array()
	for p in points:
		if clean.is_empty() or p.distance_to(clean[-1]) > 0.025: clean.append(p)
	if clean.size() < 3 or not smooth: return clean
	clean = _simplify(clean, 0.10)
	# Bounded corner cutting; no overshooting or inventing closed gaps.
	for _pass in range(2):
		var next := PackedVector2Array([clean[0]])
		for i in range(clean.size() - 1):
			var a := clean[i]
			var b := clean[i + 1]
			var inset := minf(0.20, 0.20 / maxf(a.distance_to(b), 0.001))
			next.append(a.lerp(b, inset))
			next.append(a.lerp(b, 1.0 - inset))
		next.append(clean[-1])
		clean = next
	return clean

static func _simplify(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3: return points
	var largest := 0.0
	var split := 0
	for i in range(1, points.size() - 1):
		var distance: float = Layout.Schema._point_segment_distance(points[i], points[0], points[-1])
		if distance > largest:
			largest = distance
			split = i
	if largest <= tolerance: return PackedVector2Array([points[0], points[-1]])
	var left := _simplify(points.slice(0, split + 1), tolerance)
	left.remove_at(left.size() - 1)
	left.append_array(_simplify(points.slice(split), tolerance))
	return left
