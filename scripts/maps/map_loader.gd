extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")
const CANON_GRID_W := 8
const CANON_GRID_H := 12
const CANON_CELL_SIZE := 64
const MAP_DIRS: Array[String] = [
	"res://maps/json",
	"res://maps"
]

static func list_maps() -> Array[String]:
	var out: Array[String] = []
	for dir_path in MAP_DIRS:
		var d: DirAccess = DirAccess.open(dir_path)
		if d == null:
			continue
		d.list_dir_begin()
		while true:
			var name: String = d.get_next()
			if name == "":
				break
			if d.current_is_dir():
				continue
			if name.ends_with(".json"):
				out.append(dir_path + "/" + name)
		d.list_dir_end()
	out.sort()
	return out

static func load_map(path_or_id: String) -> Dictionary:
	var resolved: String = _resolve_map_path(path_or_id)
	if resolved.is_empty():
		return _fail("map_not_found path=%s" % path_or_id)

	SFLog.debug("MAP_LOADER: load_map path=%s" % resolved)
	var f: FileAccess = FileAccess.open(resolved, FileAccess.READ)
	if f == null:
		return _fail("open_failed path=%s err=%s" % [resolved, FileAccess.get_open_error()])
	var raw: String = f.get_as_text()
	if raw.strip_edges().is_empty():
		return _fail("empty_file path=%s" % resolved)

	var json: JSON = JSON.new()
	var err: int = json.parse(raw)
	if err != OK:
		return _fail("json_parse_error path=%s err=%d msg=%s line=%d" % [
			resolved,
			err,
			json.get_error_message(),
			json.get_error_line()
		])

	var data_v: Variant = json.data
	if typeof(data_v) != TYPE_DICTIONARY:
		return _fail("root_not_dict path=%s" % resolved)
	var data: Dictionary = data_v as Dictionary

	var schema_id: String = str(data.get("_schema", ""))
	if schema_id == MAP_SCHEMA.SCHEMA_ID and data.has("entities"):
		var width: int = _as_int(data.get("width", 0), 0)
		var height: int = _as_int(data.get("height", 0), 0)
		if width != CANON_GRID_W or height != CANON_GRID_H:
			if _is_dev_runner() and width == CANON_GRID_H and height == CANON_GRID_W:
				SFLog.debug("MAP_LOADER: dev transpose v1.xy width/height -> 8x12")
				data = _transpose_v1_xy(data)
				width = _as_int(data.get("width", 0), 0)
				height = _as_int(data.get("height", 0), 0)
			else:
				return _fail("v1.xy wrong dims %dx%d (canon %dx%d) path=%s" % [
					width,
					height,
					CANON_GRID_W,
					CANON_GRID_H,
					resolved
				])
		var model: Dictionary = _load_v1xy(data, resolved)
		if model.is_empty():
			return _fail("v1.xy load failed path=%s" % resolved)
		_log_map_summary(resolved, schema_id, width, height, model)
		return _ok(model)

	var grid_w: int = int(data.get("grid_width", data.get("grid_w", 0)))
	var grid_h: int = int(data.get("grid_height", data.get("grid_h", 0)))
	if grid_w != CANON_GRID_W or grid_h != CANON_GRID_H:
		return _fail("canon_mismatch path=%s grid=%dx%d expected=%dx%d" % [
			resolved,
			grid_w,
			grid_h,
			CANON_GRID_W,
			CANON_GRID_H
		])

	var result: Dictionary = MAP_SCHEMA.validate_map(data)
	if not bool(result.get("ok", false)):
		var errors: Array = result.get("errors", []) as Array
		var idx := 0
		for e in errors:
			if idx < 5:
				if SFLog.LOGGING_ENABLED:
					push_error("MAP_LOADER: validate err path=%s err=%s" % [resolved, str(e)])
			else:
				SFLog.trace("MAP_LOADER: validate err path=%s err=%s" % [resolved, str(e)])
			idx += 1
		return _fail("validation_failed path=%s" % resolved)

	_log_map_summary(resolved, schema_id, grid_w, grid_h, data)
	return _ok(data)

static func _ok(data: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"err": ""
	}

static func _fail(err: String) -> Dictionary:
	if SFLog.LOGGING_ENABLED:
		push_error("MAP_LOADER: " + err)
	return {
		"ok": false,
		"data": {},
		"err": err
	}

static func _resolve_map_path(path_or_id: String) -> String:
	var raw: String = path_or_id.strip_edges()
	if raw.is_empty():
		return ""
	var normalized: String = MAP_SCHEMA.normalize_path(raw)
	if FileAccess.file_exists(normalized):
		return normalized
	if normalized.begins_with("res://"):
		return ""
	var name: String = normalized
	if not name.ends_with(".json"):
		name += ".json"
	for dir_path in MAP_DIRS:
		var candidate: String = dir_path + "/" + name
		if FileAccess.file_exists(candidate):
			return candidate
	return ""

static func _is_dev_runner() -> bool:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return false
	var tree := loop as SceneTree
	return tree.get_root().get_node_or_null("DevMapRunner") != null

static func _transpose_v1_xy(source: Dictionary) -> Dictionary:
	var out: Dictionary = source.duplicate(true)
	var width: int = int(out.get("width", 0))
	var height: int = int(out.get("height", 0))
	out["width"] = height
	out["height"] = width
	var entities_v: Variant = out.get("entities", [])
	if typeof(entities_v) != TYPE_ARRAY:
		return out
	var entities: Array = entities_v as Array
	for i in range(entities.size()):
		var e_v: Variant = entities[i]
		if typeof(e_v) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e_v as Dictionary
		if e.has("x") or e.has("y"):
			var x: float = float(e.get("x", 0.0))
			var y: float = float(e.get("y", 0.0))
			e["x"] = y
			e["y"] = x
		if e.has("grid_pos") and typeof(e["grid_pos"]) == TYPE_ARRAY:
			var gp: Array = e["grid_pos"] as Array
			if gp.size() >= 2:
				var gx: Variant = gp[0]
				var gy: Variant = gp[1]
				gp[0] = gy
				gp[1] = gx
				e["grid_pos"] = gp
		entities[i] = e
	out["entities"] = entities
	return out

static func _v1_kind(e: Dictionary) -> String:
	var k: String = ""
	if e.has("kind"):
		k = str(e["kind"])
	elif e.has("type"):
		k = str(e["type"])
	elif e.has("entity"):
		k = str(e["entity"])
	return k.strip_edges().to_lower()

static func _as_int(v: Variant, fallback: int) -> int:
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	if typeof(v) == TYPE_STRING:
		var s: String = str(v)
		if s.is_valid_int():
			return int(s)
	return fallback

static func _resolve_v1_ref(raw_id: Variant, id_map: Dictionary) -> int:
	if raw_id is int:
		return int(raw_id)
	var id_str: String = str(raw_id)
	if id_str.is_valid_int():
		return int(id_str)
	if id_map.has(id_str):
		return int(id_map[id_str])
	return 0

static func _load_v1xy(data: Dictionary, path: String) -> Dictionary:
	var w: int = _as_int(data.get("width", 0), 0)
	var h: int = _as_int(data.get("height", 0), 0)
	if w != CANON_GRID_W or h != CANON_GRID_H:
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_LOADER: v1.xy wrong dims %dx%d (canon %dx%d) path=%s" % [
			w,
			h,
			CANON_GRID_W,
			CANON_GRID_H,
			path
		])
		return {}

	var ents_v: Variant = data.get("entities", [])
	if typeof(ents_v) != TYPE_ARRAY:
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_LOADER: v1.xy entities not array path=%s" % path)
		return {}
	var ents: Array = ents_v as Array

	var model: Dictionary = {
		"_schema": "swarmfront.map.v1.model",
		"id": str(data.get("id", path.get_file().get_basename())),
		"name": str(data.get("name", path.get_file().get_basename())),
		"grid_w": w,
		"grid_h": h,
		"hives": [],
		"lanes": [],
		"lane_candidates": [],
		"towers": [],
		"barracks": [],
		"spawns": []
	}

	var hives: Array = []
	var towers: Array = []
	var barracks: Array = []
	var spawns: Array = []
	var tower_ids: Dictionary = {}
	var barracks_ids: Dictionary = {}
	var id_map: Dictionary = {}
	var used_ids: Dictionary = {}
	var next_id: int = 1
	var next_tower_id: int = 1
	var next_barracks_id: int = 1
	var next_spawn_id: int = 1

	for i in range(ents.size()):
		var e_v: Variant = ents[i]
		if typeof(e_v) != TYPE_DICTIONARY:
			if SFLog.LOGGING_ENABLED:
				push_error("MAP_LOADER: v1.xy entity[%d] not dict path=%s" % [i, path])
			continue
		var e: Dictionary = e_v as Dictionary

		var id_raw: Variant = e.get("id", "e_%d" % i)
		var id_str: String = str(id_raw)
		if id_str.is_empty():
			id_str = "e_%d" % i

		var x: int = _as_int(e.get("x", null), -999)
		var y: int = _as_int(e.get("y", null), -999)
		if x < 0 or y < 0:
			if SFLog.LOGGING_ENABLED:
				push_error("MAP_LOADER: v1.xy entity[%s] missing x/y path=%s" % [id_str, path])
			continue
		if x >= w or y >= h:
			if SFLog.LOGGING_ENABLED:
				push_error("MAP_LOADER: v1.xy entity[%s] out of bounds x=%d y=%d path=%s" % [id_str, x, y, path])
			continue

		var kind: String = _v1_kind(e)
		if kind.is_empty():
			if SFLog.LOGGING_ENABLED:
				push_error("MAP_LOADER: v1.xy entity[%s] missing kind/type/entity path=%s" % [id_str, path])
			continue

		if kind == "hive" or kind == "player_hive" or kind == "npc_hive":
			if id_map.has(id_str):
				if SFLog.LOGGING_ENABLED:
					push_error("MAP_LOADER: v1.xy duplicate hive id=%s path=%s" % [id_str, path])
				continue
			var hive_id: int = 0
			if id_raw is int:
				hive_id = int(id_raw)
			elif id_str.is_valid_int():
				hive_id = int(id_str)
			if hive_id <= 0 or used_ids.has(hive_id):
				while used_ids.has(next_id):
					next_id += 1
				hive_id = next_id
				next_id += 1
			used_ids[hive_id] = true
			id_map[id_str] = hive_id

			var owner_id: int = 0
			if e.has("team_id"):
				owner_id = _as_int(e.get("team_id", 0), 0)
			elif e.has("owner_id"):
				owner_id = _as_int(e.get("owner_id", 0), 0)
			elif e.has("team"):
				owner_id = MAP_SCHEMA.owner_to_owner_id(str(e.get("team", "")))
			elif e.has("owner"):
				owner_id = MAP_SCHEMA.owner_to_owner_id(str(e.get("owner", "")))

			hives.append({
				"id": hive_id,
				"x": x,
				"y": y,
				"grid_pos": [x, y],
				"owner_id": owner_id,
				"kind": "Hive",
				"power": maxi(1, _as_int(e.get("power", 10), 10))
			})
		elif kind == "tower":
			var tower_id: int = _as_int(e.get("id", next_tower_id), next_tower_id)
			if tower_id == next_tower_id:
				next_tower_id += 1
			if tower_ids.has(tower_id):
				if SFLog.LOGGING_ENABLED:
					push_warning("MAP_LOADER: v1.xy duplicate tower id=%d path=%s" % [tower_id, path])
				continue
			tower_ids[tower_id] = true
			var req_v: Variant = e.get("required_hive_ids", [])
			var req: Array = req_v as Array if typeof(req_v) == TYPE_ARRAY else []
			var control_v: Variant = e.get("control_hive_ids", null)
			var control_ids: Array = control_v as Array if typeof(control_v) == TYPE_ARRAY else []
			var owner_id: int = _as_int(e.get("owner_id", 0), 0)
			towers.append({
				"id": tower_id,
				"grid_pos": [x, y],
				"required_hive_ids": req,
				"control_hive_ids": control_ids,
				"owner_id": owner_id
			})
		elif kind == "barracks":
			var barracks_id: int = _as_int(e.get("id", next_barracks_id), next_barracks_id)
			if barracks_id == next_barracks_id:
				next_barracks_id += 1
			if barracks_ids.has(barracks_id):
				if SFLog.LOGGING_ENABLED:
					push_warning("MAP_LOADER: v1.xy duplicate barracks id=%d path=%s" % [barracks_id, path])
				continue
			barracks_ids[barracks_id] = true
			var req_v: Variant = e.get("required_hive_ids", [])
			var req: Array = req_v as Array if typeof(req_v) == TYPE_ARRAY else []
			var control_v: Variant = e.get("control_hive_ids", null)
			var control_ids: Array = control_v as Array if typeof(control_v) == TYPE_ARRAY else []
			var owner_id: int = _as_int(e.get("owner_id", 0), 0)
			barracks.append({
				"id": barracks_id,
				"grid_pos": [x, y],
				"required_hive_ids": req,
				"control_hive_ids": control_ids,
				"owner_id": owner_id
			})
		elif kind == "spawn":
			var spawn_id: int = _as_int(e.get("id", next_spawn_id), next_spawn_id)
			if spawn_id == next_spawn_id:
				next_spawn_id += 1
			spawns.append({
				"id": spawn_id,
				"grid_pos": [x, y]
			})
		else:
			if SFLog.LOGGING_ENABLED:
				push_error("MAP_LOADER: v1.xy unknown kind='%s' id=%s path=%s" % [kind, id_str, path])

	var towers_v: Variant = data.get("towers", [])
	if typeof(towers_v) == TYPE_ARRAY:
		for tower_v in towers_v as Array:
			if typeof(tower_v) != TYPE_DICTIONARY:
				continue
			var td: Dictionary = tower_v as Dictionary
			var tower_id: int = _as_int(td.get("id", next_tower_id), next_tower_id)
			if tower_id == next_tower_id:
				next_tower_id += 1
			if tower_ids.has(tower_id):
				continue
			var tx: int = _as_int(td.get("x", null), -999)
			var ty: int = _as_int(td.get("y", null), -999)
			var gp_v: Variant = td.get("grid_pos", null)
			if gp_v is Array:
				var gp: Array = gp_v as Array
				if gp.size() >= 2:
					tx = _as_int(gp[0], tx)
					ty = _as_int(gp[1], ty)
			if tx < 0 or ty < 0:
				continue
			tower_ids[tower_id] = true
			var req_v: Variant = td.get("required_hive_ids", [])
			var req: Array = req_v as Array if typeof(req_v) == TYPE_ARRAY else []
			var control_v: Variant = td.get("control_hive_ids", null)
			var control_ids: Array = control_v as Array if typeof(control_v) == TYPE_ARRAY else []
			var owner_id: int = _as_int(td.get("owner_id", 0), 0)
			towers.append({
				"id": tower_id,
				"grid_pos": [tx, ty],
				"required_hive_ids": req,
				"control_hive_ids": control_ids,
				"owner_id": owner_id
			})

	var barracks_v: Variant = data.get("barracks", [])
	if typeof(barracks_v) == TYPE_ARRAY:
		for barracks_any in barracks_v as Array:
			if typeof(barracks_any) != TYPE_DICTIONARY:
				continue
			var bd: Dictionary = barracks_any as Dictionary
			var barracks_id: int = _as_int(bd.get("id", next_barracks_id), next_barracks_id)
			if barracks_id == next_barracks_id:
				next_barracks_id += 1
			if barracks_ids.has(barracks_id):
				continue
			var bx: int = _as_int(bd.get("x", null), -999)
			var by: int = _as_int(bd.get("y", null), -999)
			var gp_b: Variant = bd.get("grid_pos", null)
			if gp_b is Array:
				var gp_b_arr: Array = gp_b as Array
				if gp_b_arr.size() >= 2:
					bx = _as_int(gp_b_arr[0], bx)
					by = _as_int(gp_b_arr[1], by)
			if bx < 0 or by < 0:
				continue
			barracks_ids[barracks_id] = true
			var req_b_v: Variant = bd.get("required_hive_ids", [])
			var req_b: Array = req_b_v as Array if typeof(req_b_v) == TYPE_ARRAY else []
			var control_b_v: Variant = bd.get("control_hive_ids", null)
			var control_b: Array = control_b_v as Array if typeof(control_b_v) == TYPE_ARRAY else []
			var owner_id_b: int = _as_int(bd.get("owner_id", 0), 0)
			barracks.append({
				"id": barracks_id,
				"grid_pos": [bx, by],
				"required_hive_ids": req_b,
				"control_hive_ids": control_b,
				"owner_id": owner_id_b
			})

	var lane_candidates: Array = []
	var auto_result: Dictionary = MAP_SCHEMA._auto_generate_lanes(hives, w, h, data)
	if bool(auto_result.get("ok", false)):
		lane_candidates = auto_result.get("lanes", []) as Array
	else:
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_LOADER: v1.xy auto lanes failed path=%s err=%s" % [
			path,
			str(auto_result.get("error", "auto lanes failed"))
		])

	if hives.is_empty():
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_LOADER: v1.xy no hives parsed path=%s" % path)
		return {}

	if spawns.is_empty():
		var hives_v: Array = hives
		for hive_entry in hives_v:
			if typeof(hive_entry) != TYPE_DICTIONARY:
				continue
			var hd: Dictionary = hive_entry as Dictionary
			var p: int = int(hd.get("power", 0))
			if p > 0:
				spawns.append({
					"hive_id": hd.get("id", 0),
					"rate": 1.0,
					"owner": hd.get("owner", "neutral")
				})

	model["hives"] = hives
	model["lane_candidates"] = lane_candidates
	model["lanes"] = []
	if (model.get("lanes", []) as Array).is_empty() and not lane_candidates.is_empty():
		# Dev/default behavior: start with all candidates active.
		model["lanes"] = lane_candidates.duplicate(true)
	if (model.get("lanes", []) as Array).is_empty():
		if SFLog.LOGGING_ENABLED:
			push_warning("Loaded map has 0 active lanes. Spawns will be blocked unless lanes are created.")
	model["towers"] = towers
	model["barracks"] = barracks
	model["spawns"] = spawns

	SFLog.debug("MAP_LOADER: v1.xy -> model hives=%d lanes=%d candidates=%d" % [
		(hives as Array).size(),
		(model.get("lanes", []) as Array).size(),
		(lane_candidates as Array).size()
	])
	return model

static func _count_array(v: Variant) -> int:
	return (v as Array).size() if typeof(v) == TYPE_ARRAY else 0

static func _log_map_summary(map_id: String, schema_id: String, grid_w: int, grid_h: int, model: Dictionary) -> void:
	var world_px: Vector2i = Vector2i(grid_w * CANON_CELL_SIZE, grid_h * CANON_CELL_SIZE)
	var hives_count: int = _count_array(model.get("hives", []))
	var lanes_count: int = _count_array(model.get("lanes", []))
	var towers_count: int = _count_array(model.get("towers", []))
	var barracks_count: int = _count_array(model.get("barracks", []))
	var npc_count: int = _count_array(model.get("npc", []))
	var bounds: String = "grid=(0,0)-(%d,%d)" % [maxi(grid_w - 1, 0), maxi(grid_h - 1, 0)]
	SFLog.info("MAP_LOAD_SUMMARY: map_id=%s schema=%s grid=%dx%d world_px=(%d,%d) counts={hives:%d, lanes:%d, towers:%d, barracks:%d, npc:%d} bounds=%s" % [
		map_id,
		schema_id,
		grid_w,
		grid_h,
		world_px.x,
		world_px.y,
		hives_count,
		lanes_count,
		towers_count,
		barracks_count,
		npc_count,
		bounds
	])
