class_name PublicContestContent
extends RefCounted

const ProgressiveConfigScript := preload("res://scripts/state/progressive_config.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const TIME_MAP_IDS: Array[String] = [
	"MAP_nomansland__545__v01_top2_sides__1p",
	"MAP_nomansland__545__v17_four_corners_only__1p",
	"MAP_nomansland__444__v01_pinched_spine__1p",
	"MAP_knifefight__SBASE__1p",
	"MAP_nomansland__545__v01_top2_sides__1p"
]

static func build_catalog() -> Dictionary:
	var time_maps: Array[Dictionary] = []
	for map_id in TIME_MAP_IDS:
		time_maps.append(_map_entry(map_id))
	var stages: Array[Dictionary] = []
	for stage in ProgressiveConfigScript.build_stage_plan():
		var map_entry: Dictionary = _map_entry(str(stage.get("map_id", "")))
		stages.append({
			"stage_index": int(stage.get("stage_index", 0)),
			"stage_number": int(stage.get("stage_number", 1)),
			"map_id": str(stage.get("map_id", "")),
			"map_sha256": str(map_entry.get("sha256", "")),
			"conquerable_hive_count": int(stage.get("conquerable_hive_count", 1)),
			"thresholds_ms": (stage.get("thresholds_ms", {}) as Dictionary).duplicate(true),
			"bot_tier": str(stage.get("bot_tier", "")), "bot_style": str(stage.get("bot_style", "")),
			"npc_power_bonus": int(stage.get("npc_power_bonus", 0)),
			"bot_start_power_bonus": int(stage.get("bot_start_power_bonus", 0)),
			"player_start_power_delta": int(stage.get("player_start_power_delta", 0))
		})
	var time_three: Array = time_maps.slice(0, 3)
	return {
		"schema": "swarmfront.public_contest_catalog.v1",
		"time_puzzle": {
			"three_map": {"pack_id": "time-puzzle-3-v1", "maps": time_three,
				"pack_hash": JSON.stringify(time_three).sha256_text()},
			"five_map": {"pack_id": "time-puzzle-5-v1", "maps": time_maps,
				"pack_hash": JSON.stringify(time_maps).sha256_text()}
		},
		"gauntlet": {"plan_id": "gauntlet-18-v1", "stage_count": stages.size(), "stages": stages,
			"plan_hash": JSON.stringify(stages).sha256_text()}
	}

static func validate_definition(definition: Dictionary) -> Dictionary:
	var family: String = str(definition.get("family", "")).to_upper()
	var catalog: Dictionary = build_catalog()
	var expected: Dictionary
	if family == "TIME_PUZZLE":
		var key: String = "three_map" if int(definition.get("map_count", 0)) == 3 else "five_map"
		expected = (catalog.get("time_puzzle", {}) as Dictionary).get(key, {}) as Dictionary
	elif family == "GAUNTLET":
		expected = catalog.get("gauntlet", {}) as Dictionary
	else:
		return {"ok": false, "err": "unsupported_public_contest_family"}
	var pack_hash: String = str(expected.get("pack_hash", expected.get("plan_hash", "")))
	var hashes: Dictionary = definition.get("content_hashes", {}) as Dictionary
	if str(hashes.get("pack", "")) != pack_hash:
		return {"ok": false, "err": "public_contest_pack_hash_mismatch"}
	var local_maps: Array = expected.get("maps", expected.get("stages", [])) as Array
	var definition_maps: Array = definition.get("map_ids", []) as Array
	if local_maps.size() != definition_maps.size():
		return {"ok": false, "err": "public_contest_map_count_mismatch"}
	var paths: PackedStringArray = PackedStringArray()
	for index in range(local_maps.size()):
		var local: Dictionary = local_maps[index] as Dictionary
		if str(local.get("map_id", "")) != str(definition_maps[index]):
			return {"ok": false, "err": "public_contest_map_order_mismatch"}
		var sha: String = str(local.get("sha256", local.get("map_sha256", "")))
		if str(hashes.get("map_%d" % (index + 1), "")) != sha:
			return {"ok": false, "err": "public_contest_map_hash_mismatch", "map_index": index}
		paths.append(str(local.get("path", ProgressiveConfigScript.resolve_stage_map_path(str(local.get("map_id", ""))))))
	if family == "GAUNTLET":
		var policy: Dictionary = definition.get("attempt_policy", {}) as Dictionary
		if str(policy.get("stage_plan_hash", "")) != pack_hash \
				or policy.get("stage_plan", []) != local_maps:
			return {"ok": false, "err": "public_contest_stage_plan_hash_mismatch"}
	return {"ok": true, "map_paths": paths, "catalog_hash": pack_hash}

static func _map_entry(map_id: String) -> Dictionary:
	var path: String = MAP_LOADER._resolve_map_path(map_id)
	if path.is_empty():
		path = ProgressiveConfigScript.resolve_stage_map_path(map_id)
	return {"map_id": map_id, "path": path, "sha256": FileAccess.get_sha256(path) if not path.is_empty() else ""}
