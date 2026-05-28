class_name MapAuthoringFinalize
extends RefCounted

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")
const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")
const MapModeRules := preload("res://scripts/maps/map_mode_rules.gd")

const SCHEMA_ID: String = "swarmfront.map.v1.xy"
const DEFAULT_GRID_W: int = 18
const DEFAULT_GRID_H: int = 28
const AUTHORING_GROUP_KEYS: Array[String] = ["structure_slot_groups", "centroid_slot_groups"]

static func finalize_map(draft: Dictionary, options: Dictionary = {}) -> Dictionary:
	var out: Dictionary = draft.duplicate(true)
	var warnings: Array[String] = []
	var errors: Array[String] = []

	_normalize_schema_and_grid(out)
	_apply_metadata(out, options)
	var nodes: Array[Dictionary] = _collect_hive_nodes(out)
	if nodes.is_empty():
		errors.append("map must contain at least one hive node/entity")

	var slot_result: Dictionary = _generate_centroid_structure_slots(out, nodes, options)
	for warning in slot_result.get("warnings", []) as Array:
		warnings.append(str(warning))
	for error in slot_result.get("errors", []) as Array:
		errors.append(str(error))
	_remove_authoring_only_fields(out)

	var static_validation: Dictionary = _validate_finalized_map_static(out)
	for warning in static_validation.get("warnings", []) as Array:
		warnings.append(str(warning))
	for error in static_validation.get("errors", []) as Array:
		errors.append(str(error))

	if errors.is_empty():
		var mode_summary: Dictionary = MapModeRules.map_supports_game_mode(_mode_rule_data(out), str(out.get("mode", "")))
		if not bool(mode_summary.get("ok", false)):
			errors.append("map/mode eligibility failed: %s" % str(mode_summary.get("reason", "invalid")))

	return {
		"ok": errors.is_empty(),
		"data": out,
		"errors": errors,
		"warnings": warnings
	}

static func load_json(path: String) -> Dictionary:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		return {"ok": false, "data": {}, "err": "missing_input_path"}
	if not FileAccess.file_exists(clean_path):
		return {"ok": false, "data": {}, "err": "file_not_found: %s" % clean_path}
	var file: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "data": {}, "err": "open_failed: %s" % clean_path}
	var raw: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err: Error = json.parse(raw)
	if err != OK:
		return {
			"ok": false,
			"data": {},
			"err": "json_parse_failed line=%d msg=%s" % [json.get_error_line(), json.get_error_message()]
		}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "err": "json_root_not_dictionary"}
	return {"ok": true, "data": json.data as Dictionary, "err": ""}

static func save_json(path: String, data: Dictionary) -> Dictionary:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		return {"ok": false, "err": "missing_output_path"}
	var file: FileAccess = FileAccess.open(clean_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "err": "open_failed: %s" % clean_path}
	file.store_string(JSON.stringify(data, "  "))
	file.store_string("\n")
	file.close()
	return {"ok": true, "err": ""}

static func validate_saved_map(path: String, mode_id: String = "") -> Dictionary:
	var loaded: Dictionary = MAP_LOADER.load_map(path)
	var data: Dictionary = {}
	if bool(loaded.get("ok", false)):
		data = loaded.get("data", {}) as Dictionary
	else:
		var raw: Dictionary = load_json(path)
		if not bool(raw.get("ok", false)):
			return {
				"ok": false,
				"err": str(raw.get("err", loaded.get("err", "load_failed"))),
				"data": {}
			}
		data = raw.get("data", {}) as Dictionary
		var static_validation: Dictionary = _validate_finalized_map_static(data)
		var errors: Array = static_validation.get("errors", []) as Array
		if not errors.is_empty():
			return {
				"ok": false,
				"err": "static_validation_failed: %s" % ", ".join(PackedStringArray(errors)),
				"data": data
			}
	var mode: String = mode_id.strip_edges()
	if mode.is_empty():
		mode = str(data.get("mode", ""))
	var mode_summary: Dictionary = MapModeRules.map_supports_game_mode(data if bool(loaded.get("ok", false)) else _mode_rule_data(data), mode)
	if not bool(mode_summary.get("ok", false)):
		return {
			"ok": false,
			"err": "map_mode_failed: %s" % str(mode_summary.get("reason", "invalid")),
			"data": data
		}
	return {"ok": true, "err": "", "data": data}

static func _normalize_schema_and_grid(map_data: Dictionary) -> void:
	map_data["_schema"] = SCHEMA_ID
	var grid_v: Variant = map_data.get("grid", {})
	var grid: Dictionary = grid_v as Dictionary if typeof(grid_v) == TYPE_DICTIONARY else {}
	var width: int = int(map_data.get("width", grid.get("w", grid.get("width", DEFAULT_GRID_W))))
	var height: int = int(map_data.get("height", grid.get("h", grid.get("height", DEFAULT_GRID_H))))
	width = maxi(1, width)
	height = maxi(1, height)
	map_data["width"] = width
	map_data["height"] = height
	map_data["grid"] = {
		"w": width,
		"h": height,
		"quant": str(grid.get("quant", "full_or_half"))
	}
	if not map_data.has("defaults"):
		map_data["defaults"] = {
			"player_start_power": 10,
			"npc_start_power": 5
		}

static func _apply_metadata(map_data: Dictionary, options: Dictionary) -> void:
	var map_id: String = str(options.get("id", map_data.get("id", ""))).strip_edges()
	if not map_id.is_empty():
		map_data["id"] = map_id
	var name: String = str(options.get("name", map_data.get("name", ""))).strip_edges()
	if not name.is_empty():
		map_data["name"] = name
	var family: String = str(options.get("family", map_data.get("family", _family_from_id(map_id)))).strip_edges().to_lower()
	if not family.is_empty():
		map_data["family"] = family
	var display_family: String = str(options.get("display_family", map_data.get("display_family", ""))).strip_edges()
	if display_family.is_empty() and not family.is_empty():
		display_family = family.capitalize()
	if not display_family.is_empty():
		map_data["display_family"] = display_family
	var mode: String = _normalize_mode(str(options.get("mode", map_data.get("mode", _mode_from_id(map_id)))))
	if not mode.is_empty():
		map_data["mode"] = mode
	var player_buckets: Array[String] = _string_list(options.get("player_buckets", map_data.get("player_buckets", [])))
	if player_buckets.is_empty():
		player_buckets = _default_player_buckets(mode)
	map_data["player_buckets"] = player_buckets
	var playstyle_tags: Array[String] = _string_list(options.get("playstyle_tags", map_data.get("playstyle_tags", [])))
	if playstyle_tags.is_empty():
		playstyle_tags = ["FFA", "STRATEGY"]
	map_data["playstyle_tags"] = playstyle_tags
	var season_tags: Array[String] = _string_list(options.get("season_tags", map_data.get("season_tags", [])))
	if season_tags.is_empty() and not family.is_empty():
		season_tags = [family]
	map_data["season_tags"] = season_tags
	var rotation_v: Variant = map_data.get("rotation", {})
	var rotation: Dictionary = rotation_v as Dictionary if typeof(rotation_v) == TYPE_DICTIONARY else {}
	var rotation_status: String = str(options.get("rotation_status", rotation.get("status", "candidate"))).strip_edges().to_lower()
	rotation["status"] = rotation_status if not rotation_status.is_empty() else "candidate"
	if not rotation.has("weight"):
		rotation["weight"] = 1
	map_data["rotation"] = rotation
	map_data["async_bot_count"] = int(options.get("async_bot_count", map_data.get("async_bot_count", _default_async_bot_count(mode))))
	if not map_data.has("towers"):
		map_data["towers"] = []
	if not map_data.has("barracks"):
		map_data["barracks"] = []

static func _generate_centroid_structure_slots(map_data: Dictionary, nodes: Array[Dictionary], options: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var existing_slots: Array = map_data.get("structure_slots", []) as Array if typeof(map_data.get("structure_slots", [])) == TYPE_ARRAY else []
	var slots: Array = existing_slots.duplicate(true)
	var groups: Array = _centroid_groups(map_data, options)
	if groups.is_empty():
		map_data["structure_slots"] = slots
		return {"errors": errors, "warnings": warnings}
	var node_by_id: Dictionary = {}
	var occupied_cells: Dictionary = {}
	for node in nodes:
		var node_id: String = str(node.get("id", "")).strip_edges()
		var pos: Vector2 = node.get("pos", Vector2(-1, -1))
		if not node_id.is_empty():
			node_by_id[node_id] = node
		occupied_cells[_cell_key(int(round(pos.x)), int(round(pos.y)))] = node_id
	var slot_cells: Dictionary = {}
	var slot_ids: Dictionary = {}
	for slot_any in slots:
		if typeof(slot_any) != TYPE_DICTIONARY:
			continue
		var slot: Dictionary = slot_any as Dictionary
		var slot_id: String = str(slot.get("id", "")).strip_edges()
		if not slot_id.is_empty():
			slot_ids[slot_id] = true
		var slot_pos: Vector2 = _slot_pos(slot)
		if slot_pos.x >= 0 and slot_pos.y >= 0:
			slot_cells[_cell_key(int(round(slot_pos.x)), int(round(slot_pos.y)))] = slot_id
	var grid: Vector2i = _map_grid_size(map_data)
	var group_index: int = 1
	for group_any in groups:
		var group: Dictionary = _normalize_centroid_group(group_any, group_index)
		group_index += 1
		var hive_ids: Array[String] = _string_list(group.get("hive_ids", group.get("ids", [])))
		if hive_ids.size() < 3:
			errors.append("structure slot group %s must reference at least 3 hives" % str(group.get("id", "")))
			continue
		var centroid: Vector2 = Vector2.ZERO
		var missing_ids: Array[String] = []
		for hive_id in hive_ids:
			if not node_by_id.has(hive_id):
				missing_ids.append(hive_id)
				continue
			var node: Dictionary = node_by_id[hive_id] as Dictionary
			centroid += node.get("pos", Vector2.ZERO) as Vector2
		if not missing_ids.is_empty():
			errors.append("structure slot group %s references missing hives: %s" % [str(group.get("id", "")), ", ".join(missing_ids)])
			continue
		centroid /= float(hive_ids.size())
		var gx: int = int(round(centroid.x))
		var gy: int = int(round(centroid.y))
		if gx < 0 or gy < 0 or gx >= grid.x or gy >= grid.y:
			errors.append("structure slot group %s centroid out of bounds: %d,%d" % [str(group.get("id", "")), gx, gy])
			continue
		var cell: String = _cell_key(gx, gy)
		if occupied_cells.has(cell):
			errors.append("structure slot group %s centroid overlaps hive cell %s" % [str(group.get("id", "")), cell])
			continue
		if slot_cells.has(cell):
			warnings.append("structure slot group %s skipped duplicate slot cell %s" % [str(group.get("id", "")), cell])
			continue
		var slot_id: String = str(group.get("id", "structure_slot_%02d" % group_index)).strip_edges()
		if slot_id.is_empty():
			slot_id = "structure_slot_%02d" % group_index
		var base_slot_id: String = slot_id
		var suffix: int = 2
		while slot_ids.has(slot_id):
			slot_id = "%s_%d" % [base_slot_id, suffix]
			suffix += 1
		var slot: Dictionary = {
			"id": slot_id,
			"grid_pos": [gx, gy],
			"allowed": _allowed_structure_kinds(group.get("allowed", ["tower", "barracks"])),
			"control_hive_ids": hive_ids,
			"centroid_of_hive_ids": hive_ids
		}
		slots.append(slot)
		slot_ids[slot_id] = true
		slot_cells[cell] = slot_id
	map_data["structure_slots"] = slots
	return {"errors": errors, "warnings": warnings}

static func _validate_finalized_map_static(map_data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var grid: Vector2i = _map_grid_size(map_data)
	if grid.x <= 0 or grid.y <= 0:
		errors.append("grid must be positive")
	var nodes: Array[Dictionary] = _collect_hive_nodes(map_data)
	var hive_cells: Dictionary = {}
	for node in nodes:
		var pos: Vector2 = node.get("pos", Vector2(-1, -1))
		var x: int = int(round(pos.x))
		var y: int = int(round(pos.y))
		if x < 0 or y < 0 or x >= grid.x or y >= grid.y:
			errors.append("hive out of bounds: %s at %d,%d" % [str(node.get("id", "")), x, y])
			continue
		var cell: String = _cell_key(x, y)
		if hive_cells.has(cell):
			errors.append("duplicate hive cell: %s" % cell)
		hive_cells[cell] = str(node.get("id", ""))
	var slots_v: Variant = map_data.get("structure_slots", [])
	if typeof(slots_v) != TYPE_ARRAY:
		errors.append("structure_slots must be an array")
		return {"errors": errors, "warnings": warnings}
	var slot_ids: Dictionary = {}
	for slot_any in slots_v as Array:
		if typeof(slot_any) != TYPE_DICTIONARY:
			errors.append("structure slot must be a dictionary")
			continue
		var slot: Dictionary = slot_any as Dictionary
		var slot_id: String = str(slot.get("id", "")).strip_edges()
		if slot_id.is_empty():
			errors.append("structure slot missing id")
		elif slot_ids.has(slot_id):
			errors.append("duplicate structure slot id: %s" % slot_id)
		slot_ids[slot_id] = true
		var pos: Vector2 = _slot_pos(slot)
		var sx: int = int(round(pos.x))
		var sy: int = int(round(pos.y))
		if sx < 0 or sy < 0 or sx >= grid.x or sy >= grid.y:
			errors.append("structure slot %s out of bounds: %d,%d" % [slot_id, sx, sy])
			continue
		var cell: String = _cell_key(sx, sy)
		if hive_cells.has(cell):
			errors.append("structure slot %s overlaps hive cell %s" % [slot_id, cell])
		var allowed: Array[String] = _allowed_structure_kinds(slot.get("allowed", []))
		if allowed.is_empty():
			errors.append("structure slot %s must allow tower and/or barracks" % slot_id)
	return {"errors": errors, "warnings": warnings}

static func _mode_rule_data(map_data: Dictionary) -> Dictionary:
	var data: Dictionary = map_data.duplicate(true)
	data["hives"] = []
	for node in _collect_hive_nodes(map_data):
		var pos: Vector2 = node.get("pos", Vector2.ZERO)
		data["hives"].append({
			"id": str(node.get("id", "")),
			"x": pos.x,
			"y": pos.y,
			"owner_id": MAP_SCHEMA.owner_to_owner_id(str(node.get("owner", "")))
		})
	return data

static func _collect_hive_nodes(map_data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var nodes_v: Variant = map_data.get("nodes", [])
	if typeof(nodes_v) == TYPE_ARRAY:
		for node_any in nodes_v as Array:
			if typeof(node_any) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = node_any as Dictionary
			var kind: String = str(node.get("kind", "hive")).strip_edges().to_lower()
			if kind != "hive" and kind != "player_hive" and kind != "npc_hive":
				continue
			var pos: Vector2 = _entry_pos(node)
			if pos.x < 0 or pos.y < 0:
				continue
			out.append({
				"id": str(node.get("id", "")),
				"pos": pos,
				"owner": str(node.get("owner", node.get("team", "")))
			})
	if not out.is_empty():
		return out
	var entities_v: Variant = map_data.get("entities", [])
	if typeof(entities_v) == TYPE_ARRAY:
		for entity_any in entities_v as Array:
			if typeof(entity_any) != TYPE_DICTIONARY:
				continue
			var entity: Dictionary = entity_any as Dictionary
			var kind: String = str(entity.get("kind", entity.get("type", ""))).strip_edges().to_lower()
			if kind != "hive" and kind != "player_hive" and kind != "npc_hive":
				continue
			var pos: Vector2 = _entry_pos(entity)
			if pos.x < 0 or pos.y < 0:
				continue
			out.append({
				"id": str(entity.get("id", "")),
				"pos": pos,
				"owner": str(entity.get("owner", entity.get("team", "")))
			})
	return out

static func _centroid_groups(map_data: Dictionary, options: Dictionary) -> Array:
	var groups: Array = []
	for key in AUTHORING_GROUP_KEYS:
		var groups_v: Variant = options.get(key, map_data.get(key, []))
		if typeof(groups_v) == TYPE_ARRAY:
			groups.append_array(groups_v as Array)
	return groups

static func _normalize_centroid_group(group_any: Variant, group_index: int) -> Dictionary:
	if typeof(group_any) == TYPE_DICTIONARY:
		var group: Dictionary = (group_any as Dictionary).duplicate(true)
		if not group.has("id"):
			group["id"] = "structure_slot_%02d" % group_index
		return group
	if typeof(group_any) == TYPE_ARRAY:
		return {
			"id": "structure_slot_%02d" % group_index,
			"hive_ids": group_any as Array,
			"allowed": ["tower", "barracks"]
		}
	return {
		"id": "structure_slot_%02d" % group_index,
		"hive_ids": [],
		"allowed": ["tower", "barracks"]
	}

static func _remove_authoring_only_fields(map_data: Dictionary) -> void:
	for key in AUTHORING_GROUP_KEYS:
		if map_data.has(key):
			map_data.erase(key)

static func _entry_pos(entry: Dictionary) -> Vector2:
	var pos_v: Variant = entry.get("pos", null)
	if typeof(pos_v) == TYPE_DICTIONARY:
		var pos: Dictionary = pos_v as Dictionary
		return Vector2(float(pos.get("x", pos.get("gx", -1))), float(pos.get("y", pos.get("gy", -1))))
	if typeof(pos_v) == TYPE_ARRAY:
		var pos_arr: Array = pos_v as Array
		if pos_arr.size() >= 2:
			return Vector2(float(pos_arr[0]), float(pos_arr[1]))
	var gp_v: Variant = entry.get("grid_pos", null)
	if typeof(gp_v) == TYPE_ARRAY:
		var gp: Array = gp_v as Array
		if gp.size() >= 2:
			return Vector2(float(gp[0]), float(gp[1]))
	if entry.has("x") and entry.has("y"):
		return Vector2(float(entry.get("x", -1)), float(entry.get("y", -1)))
	return Vector2(-1, -1)

static func _slot_pos(slot: Dictionary) -> Vector2:
	return _entry_pos(slot)

static func _map_grid_size(map_data: Dictionary) -> Vector2i:
	var grid_v: Variant = map_data.get("grid", {})
	var grid: Dictionary = grid_v as Dictionary if typeof(grid_v) == TYPE_DICTIONARY else {}
	return Vector2i(
		int(map_data.get("width", grid.get("w", grid.get("width", DEFAULT_GRID_W)))),
		int(map_data.get("height", grid.get("h", grid.get("height", DEFAULT_GRID_H))))
	)

static func _allowed_structure_kinds(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(value) == TYPE_ARRAY:
		for item_any in value as Array:
			var item: String = str(item_any).strip_edges().to_lower()
			if (item == "tower" or item == "barracks") and not out.has(item):
				out.append(item)
	else:
		var single: String = str(value).strip_edges().to_lower()
		if single == "tower" or single == "barracks":
			out.append(single)
	if out.is_empty():
		out = ["tower", "barracks"]
	return out

static func _default_player_buckets(mode: String) -> Array[String]:
	match _normalize_mode(mode):
		"3p":
			return ["3P"]
		"4p":
			return ["4P_FFA"]
		"2p":
			return ["1P", "2V2"]
		_:
			return ["1P", "2V2", "4P_FFA"]

static func _default_async_bot_count(mode: String) -> int:
	match _normalize_mode(mode):
		"3p":
			return 2
		"4p":
			return 3
		_:
			return 1

static func _normalize_mode(value: String) -> String:
	var clean: String = value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	match clean:
		"3p_ffa", "3p":
			return "3p"
		"4p_ffa", "4p":
			return "4p"
		"2p", "2v2":
			return "2p"
		"1v1", "1p", "":
			return "1p"
		_:
			return clean

static func _mode_from_id(map_id: String) -> String:
	var normalized: Dictionary = MAP_REGISTRY.normalize_map_id(map_id)
	if bool(normalized.get("ok", false)):
		return str(normalized.get("mode", ""))
	return ""

static func _family_from_id(map_id: String) -> String:
	var normalized: Dictionary = MAP_REGISTRY.normalize_map_id(map_id)
	if bool(normalized.get("ok", false)):
		return str(normalized.get("family", "")).strip_edges().to_lower()
	return ""

static func _string_list(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		for item in value as PackedStringArray:
			var text: String = str(item).strip_edges()
			if not text.is_empty() and not out.has(text):
				out.append(text)
	elif typeof(value) == TYPE_ARRAY:
		for item_any in value as Array:
			var text: String = str(item_any).strip_edges()
			if not text.is_empty() and not out.has(text):
				out.append(text)
	elif typeof(value) == TYPE_STRING:
		for token in str(value).split(",", false):
			var text: String = str(token).strip_edges()
			if not text.is_empty() and not out.has(text):
				out.append(text)
	return out

static func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]
