extends SceneTree

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")

var _failed: bool = false

func _init() -> void:
	await process_frame
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_assert_true(ops_state != null, "OpsState autoload should exist")
	if ops_state == null:
		quit(1)
		return
	var map_paths: Array[String] = MAP_LOADER.list_maps()
	_assert_true(not map_paths.is_empty(), "map catalog should not be empty")
	for path in map_paths:
		_check_map(path, ops_state)
	for extra_path in _extra_map_paths():
		_check_map(extra_path, ops_state)
	if _failed:
		quit(1)
		return
	print("MAP_LANE_AVAILABILITY_SMOKE: PASS maps=%d" % map_paths.size())
	quit(0)

func _check_map(path: String, ops_state: Node) -> void:
	var loaded: Dictionary = _load_map_data(path)
	if not bool(loaded.get("ok", false)):
		_fail("%s failed to load: %s" % [path, str(loaded.get("err", "unknown_error"))])
		return
	var data: Dictionary = loaded.get("data", {}) as Dictionary
	var owners: Array[int] = _active_owners(data)
	if owners.is_empty():
		_fail("%s has no active owners" % path)
		return
	for owner_id in owners:
		var result: Dictionary = _first_successful_lane_intent(data, ops_state, owner_id)
		if not bool(result.get("ok", false)):
			_fail("%s owner=%d cannot instance any opening lane; last=%s" % [path, owner_id, str(result)])

func _extra_map_paths() -> Array[String]:
	var raw: String = OS.get_environment("SF_EXTRA_MAP_PATHS").strip_edges()
	if raw.is_empty():
		return []
	var out: Array[String] = []
	for part in raw.split(",", false):
		var path: String = str(part).strip_edges()
		if not path.is_empty():
			out.append(path)
	return out

func _load_map_data(path: String) -> Dictionary:
	if path.begins_with("res://"):
		return MAP_LOADER.load_map(path)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return MAP_LOADER.load_map(path)
	var raw: String = f.get_as_text()
	var json := JSON.new()
	var err: int = json.parse(raw)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "err": "json_parse_error"}
	var source: Dictionary = json.data as Dictionary
	if str(source.get("_schema", "")) == "swarmfront.map.v1.xy":
		var expanded: Dictionary = MAP_LOADER._expand_v1xy_compact_if_needed(source, path)
		var model: Dictionary = MAP_LOADER._load_v1xy(expanded, path)
		if model.is_empty():
			return {"ok": false, "data": {}, "err": "v1.xy load failed"}
		return {"ok": true, "data": model, "err": ""}
	return {"ok": true, "data": source, "err": ""}

func _active_owners(data: Dictionary) -> Array[int]:
	var seen: Dictionary = {}
	for hive_any in data.get("hives", []) as Array:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var owner_id: int = int(hive.get("owner_id", 0))
		if owner_id > 0:
			seen[owner_id] = true
	var owners: Array[int] = []
	for owner_key in seen.keys():
		owners.append(int(owner_key))
	owners.sort()
	return owners

func _first_successful_lane_intent(data: Dictionary, ops_state: Node, owner_id: int) -> Dictionary:
	var last_result: Dictionary = {"ok": false, "reason": "no_attempt", "owner_id": owner_id}
	var state: GameState = ops_state.call("reset_state_from_map", data.duplicate(true))
	ops_state.set("match_phase", 1)
	for src_any in state.hives:
		if not (src_any is HiveData):
			continue
		var src: HiveData = src_any as HiveData
		if int(src.owner_id) != owner_id:
			continue
		for dst_any in state.hives:
			if not (dst_any is HiveData):
				continue
			var dst: HiveData = dst_any as HiveData
			if int(dst.id) == int(src.id):
				continue
			if not state.can_connect(int(src.id), int(dst.id)):
				continue
			last_result = ops_state.call("apply_lane_intent", int(src.id), int(dst.id), "attack")
			if bool(last_result.get("ok", false)):
				return last_result
	return last_result

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_fail(label)

func _fail(message: String) -> void:
	_failed = true
	push_error("MAP_LANE_AVAILABILITY_SMOKE: %s" % message)
