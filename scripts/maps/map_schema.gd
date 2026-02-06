extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")
const SCHEMA_ID := "swarmfront.map.v1.xy"
const CANON_GRID_W := 8
const CANON_GRID_H := 12
const DEFAULT_CELL_SIZE := 64.0
const OCCLUSION_RADIUS_MAX := 0.45
const OCCLUSION_EPS := 0.0001
const DEFAULT_SYMMETRY_MODE := "mirror_x"
const HIVE_RADIUS_RATIO_BY_KIND := {
	"hive": 0.28,
	"npc": 0.28,
	"tower": 0.22,
	"barracks": 0.24
}

static func _walls_from_field(walls_v: Variant) -> Array:
	var out: Array = []
	if typeof(walls_v) == TYPE_DICTIONARY:
		var wdict: Dictionary = walls_v as Dictionary
		var vlist: Variant = wdict.get("vertical", [])
		if typeof(vlist) == TYPE_ARRAY:
			for entry_any in vlist as Array:
				var entry: Dictionary = entry_any as Dictionary if typeof(entry_any) == TYPE_DICTIONARY else {}
				var x := int(entry.get("x", entry.get("gx", -1)))
				var y := int(entry.get("y", entry.get("gy", -1)))
				if x >= 0 and y >= 0:
					out.append({"dir": "v", "x": x, "y": y})
		var hlist: Variant = wdict.get("horizontal", [])
		if typeof(hlist) == TYPE_ARRAY:
			for entry_any in hlist as Array:
				var entry: Dictionary = entry_any as Dictionary if typeof(entry_any) == TYPE_DICTIONARY else {}
				var x := int(entry.get("x", entry.get("gx", -1)))
				var y := int(entry.get("y", entry.get("gy", -1)))
				if x >= 0 and y >= 0:
					out.append({"dir": "h", "x": x, "y": y})
	elif typeof(walls_v) == TYPE_ARRAY:
		for entry_any in walls_v as Array:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			if entry.has("x1") and entry.has("y1") and entry.has("x2") and entry.has("y2"):
				out.append({
					"x1": float(entry.get("x1")),
					"y1": float(entry.get("y1")),
					"x2": float(entry.get("x2")),
					"y2": float(entry.get("y2"))
				})
				continue
			var dir := str(entry.get("dir", entry.get("orientation", entry.get("axis", "")))).to_lower()
			var x := int(entry.get("x", entry.get("gx", -1)))
			var y := int(entry.get("y", entry.get("gy", -1)))
			if x >= 0 and y >= 0:
				if dir == "v" or dir == "vertical":
					out.append({"dir": "v", "x": x, "y": y})
				elif dir == "h" or dir == "horizontal":
					out.append({"dir": "h", "x": x, "y": y})
	return out

static func _walls_from_entities(entities_v: Variant) -> Array:
	var out: Array = []
	if typeof(entities_v) != TYPE_ARRAY:
		return out
	for e_any in entities_v as Array:
		if typeof(e_any) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e_any as Dictionary
		var kind := str(e.get("type", e.get("kind", e.get("entity", "")))).strip_edges().to_lower()
		if kind != "wall" and kind != "walls":
			continue
		var x := int(e.get("x", e.get("gx", -1)))
		var y := int(e.get("y", e.get("gy", -1)))
		if e.has("x1") and e.has("y1") and e.has("x2") and e.has("y2"):
			out.append({
				"x1": float(e.get("x1")),
				"y1": float(e.get("y1")),
				"x2": float(e.get("x2")),
				"y2": float(e.get("y2"))
			})
		elif x >= 0 and y >= 0:
			var dir := str(e.get("dir", e.get("orientation", e.get("axis", "")))).to_lower()
			if dir == "v" or dir == "vertical":
				out.append({"dir": "v", "x": x, "y": y})
			elif dir == "h" or dir == "horizontal":
				out.append({"dir": "h", "x": x, "y": y})
	return out

static func _wall_segments_from_walls(walls: Array) -> Array:
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

static func _seg_intersects(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var denom := ab.cross(cd)
	if absf(denom) <= 0.000001:
		# Parallel or colinear; treat as no intersection for walls.
		return false
	var ac := c - a
	var t := ac.cross(cd) / denom
	var u := ac.cross(ab) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

static func _segment_intersects_any_wall(a: Vector2, b: Vector2, wall_segments: Array) -> bool:
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

static func hive_radius_px_for_kind(kind: String, cell_size: float = -1.0) -> float:
	if cell_size <= 0.0:
		cell_size = DEFAULT_CELL_SIZE
	var key := kind.strip_edges().to_lower()
	if key == "player_hive" or key == "npc_hive":
		key = "hive"
	elif key == "neutral":
		key = "npc"
	var ratio := float(HIVE_RADIUS_RATIO_BY_KIND.get(key, HIVE_RADIUS_RATIO_BY_KIND.get("hive", 0.28)))
	return maxf(1.0, ratio * cell_size)

static func owner_to_owner_id(owner: String) -> int:
	var normalized := owner.strip_edges().to_upper()
	match normalized:
		"P1":
			return 1
		"P2":
			return 2
		"P3":
			return 3
		"P4":
			return 4
		"NEUTRAL", "NPC", "":
			return 0
		_:
			if normalized.is_valid_int():
				return int(normalized)
			return 0

static func _default_owner_for_grid_pos(gx: float, gy: float) -> int:
	# Dev-safe fallback owner assignment:
	# Left half = P1, Right half = P2 (for now).
	# CANON grid is 8x12, x in [0..7]. Midline at 3.5.
	# If you later want 4 players: split by y too.
	if gx <= 3.5:
		return 1
	return 2

static func _adapt_v1_xy_to_internal(human: Dictionary) -> Dictionary:
	# Accepts:
	# {
	#   "_schema":"swarmfront.map.v1.xy",
	#   "width":8,"height":12,
	#   "entities":[ { "type":"npc_hive","x":..,"y":.. }, ... ]
	# }
	var grid_w := int(human.get("width", 0))
	var grid_h := int(human.get("height", 0))
	if grid_w <= 0 or grid_h <= 0:
		return {"ok": false, "error": "v1.xy missing width/height"}

	var entities_raw: Variant = human.get("entities", [])
	if typeof(entities_raw) != TYPE_ARRAY:
		return {"ok": false, "error": "v1.xy entities must be an Array"}
	var entities: Array = entities_raw

	var hives: Array = []
	var towers: Array = []
	var barracks: Array = []
	var walls: Array = []
	var hive_counts: Dictionary = {}
	var seen_hive_cells: Dictionary = {}
	var next_tower_id := 1
	var next_barracks_id := 1
	var lanes: Array = []
	var lanes_raw: Variant = human.get("lanes", [])
	if typeof(lanes_raw) == TYPE_ARRAY:
		lanes = lanes_raw
	for e in entities:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var t := str(e.get("type", ""))
		var x := int(e.get("x", e.get("grid_x", -1)))
		var y := int(e.get("y", e.get("grid_y", -1)))
		if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
			return {
				"ok": false,
				"error": "entity %s out of bounds id=%s x=%d y=%d for grid %dx%d" % [
					t,
					str(e.get("id", "")),
					x,
					y,
					grid_w,
					grid_h
				]
			}

		match t:
			"player_hive":
				var owner := str(e.get("owner", "P1"))
				var owner_id: int = 0
				if e.has("owner_id"):
					owner_id = int(e.get("owner_id", 0))
				elif e.has("owner"):
					owner_id = owner_to_owner_id(str(e.get("owner", "")))
				if owner_id <= 0:
					owner_id = _default_owner_for_grid_pos(x, y)
				var hive_id := str(e.get("id", ""))
				if hive_id.is_empty():
					var count := int(hive_counts.get(owner, 0)) + 1
					hive_counts[owner] = count
					hive_id = "%s_H%d" % [owner, count]
				var cell_key := "%d,%d" % [x, y]
				if seen_hive_cells.has(cell_key):
					return {"ok": false, "error": "duplicate hive cell %s" % cell_key}
				seen_hive_cells[cell_key] = true
				hives.append({
					"id": hive_id,
					"x": x,
					"y": y,
					"tier": str(e.get("tier", "MEDIUM")),
					"owner": owner,
					"owner_id": owner_id,
					"kind": "Hive"
				})
			"npc_hive":
				var owner_id: int = 0
				if e.has("owner_id"):
					owner_id = int(e.get("owner_id", 0))
				elif e.has("owner"):
					owner_id = owner_to_owner_id(str(e.get("owner", "")))
				if owner_id <= 0:
					owner_id = _default_owner_for_grid_pos(x, y)
				var hive_id := str(e.get("id", ""))
				if hive_id.is_empty():
					var count := int(hive_counts.get("NEUTRAL", 0)) + 1
					hive_counts["NEUTRAL"] = count
					hive_id = "NPC_H%d" % count
				var cell_key := "%d,%d" % [x, y]
				if seen_hive_cells.has(cell_key):
					return {"ok": false, "error": "duplicate hive cell %s" % cell_key}
				seen_hive_cells[cell_key] = true
				hives.append({
					"id": hive_id,
					"x": x,
					"y": y,
					"tier": str(e.get("tier", "MEDIUM")),
					"owner": "NEUTRAL",
					"owner_id": owner_id,
					"kind": "Hive"
				})
			"tower":
				var tower_id := str(e.get("id", ""))
				if tower_id.is_empty():
					tower_id = "T%d" % next_tower_id
					next_tower_id += 1
				towers.append({
					"id": tower_id,
					"x": x,
					"y": y
				})
			"barracks":
				var barracks_id := str(e.get("id", ""))
				if barracks_id.is_empty():
					barracks_id = "B%d" % next_barracks_id
					next_barracks_id += 1
				barracks.append({
					"id": barracks_id,
					"x": x,
					"y": y
				})
			"wall", "walls":
				var dir := str(e.get("dir", e.get("orientation", e.get("axis", "")))).to_lower()
				if e.has("x1") and e.has("y1") and e.has("x2") and e.has("y2"):
					walls.append({
						"x1": float(e.get("x1")),
						"y1": float(e.get("y1")),
						"x2": float(e.get("x2")),
						"y2": float(e.get("y2"))
					})
				elif dir == "v" or dir == "vertical":
					walls.append({"dir": "v", "x": x, "y": y})
				elif dir == "h" or dir == "horizontal":
					walls.append({"dir": "h", "x": x, "y": y})
			_:
				SFLog.warn("MAP_ENTITY_KIND_UNKNOWN", {"kind": t, "id": str(e.get("id", ""))})
				continue

	var walls_from_field: Array = _walls_from_field(human.get("walls", null))
	if not walls_from_field.is_empty():
		walls.append_array(walls_from_field)

	SFLog.info("MAP_OWNER_SUMMARY", {
		"p1": hives.filter(func(x): return int(x.get("owner_id", 0)) == 1).size(),
		"p2": hives.filter(func(x): return int(x.get("owner_id", 0)) == 2).size(),
		"neutral": hives.filter(func(x): return int(x.get("owner_id", 0)) == 0).size()
	})
	return {
		"ok": true,
		"data": {
			"_schema": SCHEMA_ID,
			"id": str(human.get("id", "")),
			"name": str(human.get("name", "")),
			"grid_w": grid_w,
			"grid_h": grid_h,
			"hives": hives,
			"lanes": lanes,
			"towers": towers,
			"barracks": barracks,
			"walls": walls,
			"spawns": []
		}
	}

static func normalize_path(path: String) -> String:
	var p := path.strip_edges()
	if p.ends_with(".tscn.json"):
		return p.replace(".tscn.json", ".json")
	if p.ends_with(".tscn"):
		var candidate := p.replace(".tscn", ".json")
		if candidate.begins_with("res://maps/"):
			candidate = candidate.replace("res://maps/", "res://maps/json/")
		if FileAccess.file_exists(candidate):
			return candidate
		var tscn_json := p + ".json"
		if tscn_json.begins_with("res://maps/"):
			tscn_json = tscn_json.replace("res://maps/", "res://maps/json/")
		if FileAccess.file_exists(tscn_json):
			return tscn_json
		return p
	return p

static func _lane_key(a_id: int, b_id: int) -> String:
	if a_id < b_id:
		return "%d:%d" % [a_id, b_id]
	return "%d:%d" % [b_id, a_id]

static func _segment_distance_t(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.000001:
		return Vector2(p.distance_to(a), 0.0)
	var t: float = ((p - a).dot(ab)) / ab_len_sq
	var t_clamped: float = clamp(t, 0.0, 1.0)
	var closest: Vector2 = a + ab * t_clamped
	return Vector2(p.distance_to(closest), t)

static func _segment_occluded(a: Vector2, b: Vector2, hives: Array, a_id: int, b_id: int, radius: float) -> bool:
	for hive in hives:
		if typeof(hive) != TYPE_DICTIONARY:
			continue
		var hive_id := int(hive.get("id", 0))
		if hive_id == a_id or hive_id == b_id:
			continue
		var p: Vector2 = hive.get("pos", Vector2.ZERO)
		var dt := _segment_distance_t(p, a, b)
		var dist := dt.x
		var t := dt.y
		if t > OCCLUSION_EPS and t < 1.0 - OCCLUSION_EPS and dist <= radius:
			return true
	return false

static func _resolve_symmetry_config(config: Dictionary) -> Dictionary:
	var mode: String = str(config.get("symmetry_mode", config.get("symmetry", "")))
	var enforce := true
	if config.has("symmetric") and not bool(config.get("symmetric")):
		enforce = false
	if mode.is_empty():
		mode = DEFAULT_SYMMETRY_MODE
	if mode == "none" or mode == "false":
		enforce = false
	if mode != "mirror_x":
		enforce = false
	return {"mode": mode, "enforce": enforce}

static func _mirror_id(hive_id: int, id_to_pos: Dictionary, pos_to_id: Dictionary, grid_w: int) -> int:
	if not id_to_pos.has(hive_id):
		return 0
	var pos: Vector2 = id_to_pos[hive_id]
	var mx := int(grid_w - 1 - int(pos.x))
	var my := int(pos.y)
	var key := "%d,%d" % [mx, my]
	return int(pos_to_id.get(key, 0))

static func _mirror_pair(a_id: int, b_id: int, id_to_pos: Dictionary, pos_to_id: Dictionary, grid_w: int) -> Dictionary:
	var a_m := _mirror_id(a_id, id_to_pos, pos_to_id, grid_w)
	var b_m := _mirror_id(b_id, id_to_pos, pos_to_id, grid_w)
	if a_m <= 0 or b_m <= 0:
		return {"ok": false}
	return {"ok": true, "a_id": a_m, "b_id": b_m, "key": _lane_key(a_m, b_m)}

static func _add_lane(a_id: int, b_id: int, lanes: Array, lane_set: Dictionary, degree: Dictionary) -> void:
	var key := _lane_key(a_id, b_id)
	if lane_set.has(key):
		return
	lanes.append({"a_id": a_id, "b_id": b_id})
	lane_set[key] = true
	degree[a_id] = int(degree.get(a_id, 0)) + 1
	degree[b_id] = int(degree.get(b_id, 0)) + 1

static func _compute_components(hive_ids: Array, lanes: Array) -> Dictionary:
	var adjacency: Dictionary = {}
	for hive_id in hive_ids:
		adjacency[hive_id] = []
	for lane_v in lanes:
		if typeof(lane_v) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = lane_v
		var a_id := int(lane.get("a_id", 0))
		var b_id := int(lane.get("b_id", 0))
		if not adjacency.has(a_id) or not adjacency.has(b_id):
			continue
		(adjacency[a_id] as Array).append(b_id)
		(adjacency[b_id] as Array).append(a_id)
	var comp_of: Dictionary = {}
	var components: Array = []
	for hive_id in hive_ids:
		if comp_of.has(hive_id):
			continue
		var stack: Array = [hive_id]
		var comp: Array = []
		comp_of[hive_id] = components.size()
		while not stack.is_empty():
			var current := int(stack.pop_back())
			comp.append(current)
			for neighbor in adjacency.get(current, []):
				var neighbor_id := int(neighbor)
				if comp_of.has(neighbor_id):
					continue
				comp_of[neighbor_id] = components.size()
				stack.append(neighbor_id)
		components.append(comp)
	return {"comp_of": comp_of, "components": components}

static func _auto_generate_lanes(hives: Array, grid_w: int, grid_h: int, config: Dictionary) -> Dictionary:
	var hive_points: Array = []
	var hive_ids: Array = []
	var id_to_pos: Dictionary = {}
	var pos_to_id: Dictionary = {}
	for hive_v in hives:
		if typeof(hive_v) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_v
		var hive_id := int(hive.get("id", 0))
		var gp: Array = hive.get("grid_pos", [0, 0])
		var pos := Vector2(float(gp[0]), float(gp[1]))
		hive_points.append({"id": hive_id, "pos": pos})
		hive_ids.append(hive_id)
		id_to_pos[hive_id] = pos
		pos_to_id["%d,%d" % [int(pos.x), int(pos.y)]] = hive_id

	if hive_ids.size() <= 1:
		return {"ok": true, "lanes": []}

	var walls: Array = []
	if config.has("walls"):
		walls.append_array(_walls_from_field(config.get("walls", null)))
	if config.has("entities"):
		walls.append_array(_walls_from_entities(config.get("entities", [])))
	var wall_segments: Array = _wall_segments_from_walls(walls)

	var symmetry_cfg := _resolve_symmetry_config(config)
	var enforce_symmetry := bool(symmetry_cfg.get("enforce", false))

	var candidate_set: Dictionary = {}
	var lanes: Array = []
	var lane_set: Dictionary = {}
	var degree: Dictionary = {}
	for hive_id in hive_ids:
		degree[hive_id] = 0
	for i in range(hive_points.size()):
		var a: Dictionary = hive_points[i]
		var a_id := int(a.get("id", 0))
		var a_pos: Vector2 = a.get("pos", Vector2.ZERO)
		for j in range(i + 1, hive_points.size()):
			var b: Dictionary = hive_points[j]
			var b_id := int(b.get("id", 0))
			var b_pos: Vector2 = b.get("pos", Vector2.ZERO)
			if not wall_segments.is_empty() and _segment_intersects_any_wall(a_pos, b_pos, wall_segments):
				continue
			if _segment_occluded(a_pos, b_pos, hive_points, a_id, b_id, OCCLUSION_RADIUS_MAX):
				continue
			var key := _lane_key(a_id, b_id)
			candidate_set[key] = true
			_add_lane(a_id, b_id, lanes, lane_set, degree)

	if enforce_symmetry:
		var filtered: Array = []
		var filtered_set: Dictionary = {}
		var filtered_degree: Dictionary = {}
		for hive_id in hive_ids:
			filtered_degree[hive_id] = 0
		for lane_v in lanes:
			if typeof(lane_v) != TYPE_DICTIONARY:
				continue
			var a_id := int(lane_v.get("a_id", 0))
			var b_id := int(lane_v.get("b_id", 0))
			var mirror := _mirror_pair(a_id, b_id, id_to_pos, pos_to_id, grid_w)
			if not mirror.get("ok", false):
				continue
			var mirror_key := str(mirror.get("key", ""))
			if not candidate_set.has(mirror_key):
				continue
			_add_lane(a_id, b_id, filtered, filtered_set, filtered_degree)
		lanes = filtered
		lane_set = filtered_set
		degree = filtered_degree

	if OS.is_debug_build():
		var total_degree := 0
		for hive_id in hive_ids:
			total_degree += int(degree.get(hive_id, 0))
		var avg_degree := 0.0
		if hive_ids.size() > 0:
			avg_degree = float(total_degree) / float(hive_ids.size())
		var components_info := _compute_components(hive_ids, lanes)
		var components: Array = components_info.get("components", [])
		SFLog.trace("MAP_SCHEMA: auto lanes hives=%d candidates=%d lanes=%d components=%d" % [
			hive_ids.size(),
			candidate_set.size(),
			lanes.size(),
			components.size()
		])
		SFLog.trace("MAP_SCHEMA: auto lanes avg_degree=%.2f" % avg_degree)
	return {"ok": true, "lanes": lanes}

static func build_internal_map(human: Dictionary) -> Dictionary:
	var config: Dictionary = human
	var schema_id := str(human.get("_schema", ""))
	if schema_id != SCHEMA_ID:
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_SCHEMA: expected _schema=%s" % SCHEMA_ID)
		return {"ok": false, "error": "expected _schema=%s" % SCHEMA_ID}
	if not human.has("entities"):
		return {"ok": false, "error": "v1.xy missing entities[]"}
	var adapted := _adapt_v1_xy_to_internal(human)
	if not adapted.get("ok", false):
		return adapted
	var source: Dictionary = adapted.get("data", {})
	var grid_w := int(source.get("grid_w", 0))
	var grid_h := int(source.get("grid_h", 0))
	if grid_w <= 0 or grid_h <= 0:
		return {"ok": false, "error": "grid_w/grid_h must be > 0"}
	if grid_w != CANON_GRID_W or grid_h != CANON_GRID_H:
		SFLog.info("MAP_SCHEMA: non-canon grid %dx%d (canon %dx%d)" % [
			grid_w,
			grid_h,
			CANON_GRID_W,
			CANON_GRID_H
		])
	var hives_raw: Array = source.get("hives", [])
	if typeof(hives_raw) != TYPE_ARRAY or hives_raw.is_empty():
		return {"ok": false, "error": "missing hives[]"}

	var seen_ids: Dictionary = {}
	var used_int_ids: Dictionary = {}
	var seen_cells: Dictionary = {}
	var id_map: Dictionary = {}
	var next_id := 1
	var hives: Array = []

	for hive_v in hives_raw:
		if typeof(hive_v) != TYPE_DICTIONARY:
			return {"ok": false, "error": "hive entry is not a Dictionary"}
		var hive: Dictionary = hive_v
		var id_str := str(hive.get("id", ""))
		if id_str == "":
			return {"ok": false, "error": "hive missing id"}
		if seen_ids.has(id_str):
			return {"ok": false, "error": "duplicate hive id: %s" % id_str}
		seen_ids[id_str] = true

		var int_id := 0
		if hive.get("id") is int or id_str.is_valid_int():
			int_id = int(id_str)
			if int_id <= 0:
				return {"ok": false, "error": "invalid numeric hive id: %s" % id_str}
			if used_int_ids.has(int_id):
				return {"ok": false, "error": "duplicate numeric hive id: %s" % id_str}
			used_int_ids[int_id] = true
		else:
			while used_int_ids.has(next_id):
				next_id += 1
			int_id = next_id
			used_int_ids[int_id] = true
			next_id += 1

		id_map[id_str] = int_id

		var x := int(hive.get("x", -1))
		var y := int(hive.get("y", -1))
		if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
			return {
				"ok": false,
				"error": "hive out of bounds id=%s x=%d y=%d for grid %dx%d" % [
					id_str,
					x,
					y,
					grid_w,
					grid_h
				]
			}
		var cell_key := "%d,%d" % [x, y]
		if seen_cells.has(cell_key):
			return {"ok": false, "error": "duplicate hive cell %s" % cell_key}
		seen_cells[cell_key] = true

		var owner_id := owner_to_owner_id(str(hive.get("owner", "")))
		var kind := str(hive.get("kind", "Hive"))
		hives.append({
			"id": int_id,
			"grid_pos": [x, y],
			"owner_id": owner_id,
			"kind": kind
		})

	var lanes_raw: Variant = source.get("lanes", [])
	var lanes: Array = []
	if typeof(lanes_raw) == TYPE_ARRAY:
		var lanes_list: Array = lanes_raw
		if lanes_list.is_empty():
			var auto_result := _auto_generate_lanes(hives, grid_w, grid_h, config)
			if not auto_result.get("ok", false):
				return {"ok": false, "error": str(auto_result.get("error", "auto lanes failed"))}
			lanes = auto_result.get("lanes", [])
		else:
			lanes = _convert_lanes(lanes_list, id_map)
	else:
		var auto_result := _auto_generate_lanes(hives, grid_w, grid_h, config)
		if not auto_result.get("ok", false):
			return {"ok": false, "error": str(auto_result.get("error", "auto lanes failed"))}
		lanes = auto_result.get("lanes", [])
	var towers: Array = _convert_structures(source.get("towers", []), id_map)
	var barracks: Array = _convert_structures(source.get("barracks", []), id_map)
	var tower_bounds := _validate_structures_in_bounds(towers, grid_w, grid_h, "tower")
	if not tower_bounds.get("ok", false):
		return tower_bounds
	var barracks_bounds := _validate_structures_in_bounds(barracks, grid_w, grid_h, "barracks")
	if not barracks_bounds.get("ok", false):
		return barracks_bounds
	var spawns: Array = []
	if typeof(source.get("spawns", null)) == TYPE_ARRAY:
		spawns = source.get("spawns", [])

	var internal := {
		"_schema": SCHEMA_ID,
		"id": str(source.get("id", "")),
		"name": str(source.get("name", "")),
		"grid_w": grid_w,
		"grid_h": grid_h,
		"hives": hives,
		"lanes": lanes,
		"towers": towers,
		"barracks": barracks,
		"walls": source.get("walls", []),
		"spawns": spawns
	}

	return {"ok": true, "data": internal}

static func _resolve_hive_ref(raw_id: Variant, id_map: Dictionary) -> int:
	if raw_id is int:
		return int(raw_id)
	var id_str := str(raw_id)
	if id_str.is_valid_int():
		return int(id_str)
	if id_map.has(id_str):
		return int(id_map[id_str])
	return 0

static func _validate_structures_in_bounds(structures: Array, grid_w: int, grid_h: int, label: String) -> Dictionary:
	for entry_v in structures:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var gp: Variant = entry.get("grid_pos", null)
		if not (gp is Array) or gp.size() < 2:
			continue
		var x := int(gp[0])
		var y := int(gp[1])
		if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
			return {
				"ok": false,
				"error": "%s out of bounds id=%s x=%d y=%d for grid %dx%d" % [
					label,
					str(entry.get("id", "")),
					x,
					y,
					grid_w,
					grid_h
				]
			}
	return {"ok": true}

static func _convert_lanes(lanes_raw: Variant, id_map: Dictionary) -> Array:
	var lanes: Array = []
	if typeof(lanes_raw) != TYPE_ARRAY:
		return lanes
	for lane_v in lanes_raw:
		if typeof(lane_v) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = lane_v
		var from_raw: Variant = lane.get("from_hive", lane.get("from", lane.get("a_id", null)))
		var to_raw: Variant = lane.get("to_hive", lane.get("to", lane.get("b_id", null)))
		var a_id := _resolve_hive_ref(from_raw, id_map)
		var b_id := _resolve_hive_ref(to_raw, id_map)
		if a_id <= 0 or b_id <= 0 or a_id == b_id:
			continue
		lanes.append({"a_id": a_id, "b_id": b_id})
	return lanes

static func _convert_structures(structures_raw: Variant, id_map: Dictionary) -> Array:
	var structures: Array = []
	if typeof(structures_raw) != TYPE_ARRAY:
		return structures
	var next_id := 1
	for entry_v in structures_raw:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var id_val := _resolve_hive_ref(entry.get("id", 0), {})
		if id_val <= 0:
			id_val = next_id
			next_id += 1
		var x := int(entry.get("x", 0))
		var y := int(entry.get("y", 0))
		var gp: Variant = entry.get("grid_pos", null)
		if gp is Array and gp.size() >= 2:
			x = int(gp[0])
			y = int(gp[1])
		var required: Array = []
		var required_raw: Variant = entry.get("required_hive_ids", [])
		if typeof(required_raw) == TYPE_ARRAY:
			for req in required_raw:
				var req_id := _resolve_hive_ref(req, id_map)
				if req_id > 0:
					required.append(req_id)
		structures.append({
			"id": id_val,
			"grid_pos": [x, y],
			"required_hive_ids": required
		})
	return structures

static func validate_map(d: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if d.is_empty():
		errors.append("map is empty")
		return {"ok": false, "errors": errors}

	var map_id: String = str(d.get("id", ""))
	if map_id.is_empty():
		errors.append("missing id")
	var map_name: String = str(d.get("name", ""))
	if map_name.is_empty():
		errors.append("missing name")

	var grid_w: int = int(d.get("grid_width", 0))
	var grid_h: int = int(d.get("grid_height", 0))
	if grid_w <= 0 or grid_h <= 0:
		errors.append("grid_width/grid_height must be > 0")

	var hives_v: Variant = d.get("hives", null)
	if typeof(hives_v) != TYPE_ARRAY:
		errors.append("hives must be an Array")
	else:
		var hives: Array = hives_v as Array
		if hives.is_empty():
			errors.append("hives must be non-empty")
		var hive_ids: Dictionary = {}
		for h in hives:
			if typeof(h) != TYPE_DICTIONARY:
				errors.append("hive entry must be Dictionary")
				continue
			var hd: Dictionary = h as Dictionary
			var hid: String = str(hd.get("id", ""))
			if hid.is_empty():
				errors.append("hive missing id")
			elif hive_ids.has(hid):
				errors.append("duplicate hive id: " + hid)
			else:
				hive_ids[hid] = true
			var owner: String = str(hd.get("owner", ""))
			if owner.is_empty():
				errors.append("hive missing owner (id=" + hid + ")")

			var x_v: Variant = hd.get("x", null)
			var y_v: Variant = hd.get("y", null)
			if (typeof(x_v) != TYPE_INT and typeof(x_v) != TYPE_FLOAT) or (typeof(y_v) != TYPE_INT and typeof(y_v) != TYPE_FLOAT):
				if hd.has("grid_pos") and typeof(hd["grid_pos"]) == TYPE_ARRAY:
					var gp: Array = hd["grid_pos"] as Array
					if gp.size() >= 2:
						x_v = gp[0]
						y_v = gp[1]
			if typeof(x_v) != TYPE_INT and typeof(x_v) != TYPE_FLOAT:
				errors.append("hive missing x (id=" + hid + ")")
			if typeof(y_v) != TYPE_INT and typeof(y_v) != TYPE_FLOAT:
				errors.append("hive missing y (id=" + hid + ")")
			if typeof(x_v) == TYPE_INT or typeof(x_v) == TYPE_FLOAT:
				var xf: float = float(x_v)
				if absf(xf - round(xf)) > 0.0001:
					errors.append("hive x must be int (id=" + hid + ")")
				var xi: int = int(round(xf))
				if grid_w > 0 and (xi < 0 or xi >= grid_w):
					errors.append("hive x out of bounds (id=" + hid + ")")
			if typeof(y_v) == TYPE_INT or typeof(y_v) == TYPE_FLOAT:
				var yf: float = float(y_v)
				if absf(yf - round(yf)) > 0.0001:
					errors.append("hive y must be int (id=" + hid + ")")
				var yi: int = int(round(yf))
				if grid_h > 0 and (yi < 0 or yi >= grid_h):
					errors.append("hive y out of bounds (id=" + hid + ")")

	var lanes_v: Variant = d.get("lanes", [])
	if typeof(lanes_v) != TYPE_ARRAY:
		errors.append("lanes must be an Array if present")
	else:
		var lanes: Array = lanes_v as Array
		var lane_keys: Dictionary = {}
		var hive_ids_local: Dictionary = {}
		var hives_for_ids: Array = []
		if typeof(hives_v) == TYPE_ARRAY:
			hives_for_ids = hives_v as Array
		for h in hives_for_ids:
			if typeof(h) != TYPE_DICTIONARY:
				continue
			var hd: Dictionary = h as Dictionary
			var hid: String = str(hd.get("id", ""))
			if not hid.is_empty():
				hive_ids_local[hid] = true
		for l in lanes:
			if typeof(l) != TYPE_DICTIONARY:
				errors.append("lane entry must be Dictionary")
				continue
			var ld: Dictionary = l as Dictionary
			var from_id: String = str(ld.get("from", ""))
			var to_id: String = str(ld.get("to", ""))
			if from_id.is_empty() or to_id.is_empty():
				errors.append("lane missing from/to")
				continue
			if from_id == to_id:
				errors.append("lane from/to must differ (" + from_id + ")")
			if not hive_ids_local.has(from_id):
				errors.append("lane from id not found: " + from_id)
			if not hive_ids_local.has(to_id):
				errors.append("lane to id not found: " + to_id)
			var bidir: bool = false
			if ld.has("bidir") and typeof(ld["bidir"]) == TYPE_BOOL:
				bidir = bool(ld["bidir"])
			var key: String = ""
			if bidir:
				var lo: String = from_id
				var hi: String = to_id
				if hi < lo:
					var tmp: String = lo
					lo = hi
					hi = tmp
				key = lo + ":" + hi + ":b"
			else:
				key = from_id + "->" + to_id
			if lane_keys.has(key):
				errors.append("duplicate lane: " + key)
			else:
				lane_keys[key] = true

	return {"ok": errors.is_empty(), "errors": errors}
