extends SceneTree

const PUBLIC_CONTEST_CONTENT := preload("res://scripts/state/public_contest_content.gd")

func _init() -> void:
	for map_count in [3, 5]:
		var definition: Dictionary = _definition(map_count)
		var valid: Dictionary = PUBLIC_CONTEST_CONTENT.validate_definition(definition)
		if not bool(valid.get("ok", false)):
			_fail("%d-map definition rejected: %s" % [map_count, str(valid)])
			return
		var wrong_family: Dictionary = definition.duplicate(true)
		(wrong_family.get("closure_policy", {}) as Dictionary)["cohort_family_id"] = "ASYNC_5_ROLLING_4P_V1" if map_count == 3 else "ASYNC_3_ROLLING_4P_V1"
		if bool(PUBLIC_CONTEST_CONTENT.validate_definition(wrong_family).get("ok", false)):
			_fail("%d-map definition accepted the other cohort family" % map_count)
			return
		var wrong_hash: Dictionary = definition.duplicate(true)
		(wrong_hash.get("content_hashes", {}) as Dictionary)["map_1"] = "wrong"
		if bool(PUBLIC_CONTEST_CONTENT.validate_definition(wrong_hash).get("ok", false)):
			_fail("%d-map definition accepted a mismatched map hash" % map_count)
			return
	print("PUBLIC_ASYNC_COHORT_CONTENT_SMOKE: PASS")
	quit(0)

func _definition(map_count: int) -> Dictionary:
	var catalog: Dictionary = PUBLIC_CONTEST_CONTENT.build_catalog()
	var key: String = "three_map" if map_count == 3 else "five_map"
	var pack: Dictionary = (catalog.get("time_puzzle", {}) as Dictionary).get(key, {}) as Dictionary
	var map_ids: Array[String] = []
	var hashes: Dictionary = {"pack": str(pack.get("pack_hash", ""))}
	var maps: Array = pack.get("maps", []) as Array
	for index in range(maps.size()):
		var map_entry: Dictionary = maps[index] as Dictionary
		map_ids.append(str(map_entry.get("map_id", "")))
		hashes["map_%d" % (index + 1)] = str(map_entry.get("sha256", ""))
	return {
		"family": "ASYNC_MAP_SET",
		"scope": "ROLLING_COHORT",
		"map_count": map_count,
		"map_ids": map_ids,
		"content_hashes": hashes,
		"closure_policy": {
			"kind": "QUALIFIED_PLAYER_COUNT",
			"cohort_family_id": "ASYNC_3_ROLLING_4P_V1" if map_count == 3 else "ASYNC_5_ROLLING_4P_V1",
			"roster_capacity": 4,
			"qualified_player_count": 4
		}
	}

func _fail(message: String) -> void:
	push_error("PUBLIC_ASYNC_COHORT_CONTENT_SMOKE: %s" % message)
	quit(1)
