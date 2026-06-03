extends SceneTree

const MapAuthoringFinalize := preload("res://tools/map_authoring_finalize_lib.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MatchSetupRandomizer := preload("res://scripts/state/match_setup_randomizer.gd")

const OUT_PATH: String = "user://MAP_TEST.json"

func _init() -> void:
	await process_frame
	var failed: bool = false
	failed = _test_finalize_adds_tags_and_centroid_structure_slots() or failed
	failed = _test_randomizer_assigns_active_start_slots() or failed
	if failed:
		quit(1)
		return
	print("MAP_AUTHORING_FINALIZE_SMOKE: PASS")
	quit(0)

func _test_finalize_adds_tags_and_centroid_structure_slots() -> bool:
	var draft: Dictionary = {
		"id": "MAP_TEST",
		"name": "Authoring Finalize Smoke",
		"family": "test",
		"mode": "1p",
		"grid": {"w": 18, "h": 28, "quant": "full_or_half"},
		"defaults": {"player_start_power": 10, "npc_start_power": 5},
		"nodes": [
			{"id": "p1h1", "pos": {"x": 1, "y": 1}, "owner": "P1", "kind": "hive"},
			{"id": "p2h1", "pos": {"x": 7, "y": 1}, "owner": "P2", "kind": "hive"},
			{"id": "n1", "pos": {"x": 4, "y": 7}, "owner": "NPC", "kind": "hive"}
		],
		"structure_slot_groups": [
			{"id": "slot_triangle", "hive_ids": ["p1h1", "p2h1", "n1"], "allowed": ["tower", "barracks"]}
		],
		"occluders": {"walls": [], "blocks_los": []}
	}
	var finalized: Dictionary = MapAuthoringFinalize.finalize_map(draft, {})
	if not bool(finalized.get("ok", false)):
		return _fail("finalize_map failed: %s" % str(finalized))
	var data: Dictionary = finalized.get("data", {}) as Dictionary
	if data.has("structure_slot_groups"):
		return _fail("authoring-only structure_slot_groups should not remain in final map")
	if str(data.get("_schema", "")) != "swarmfront.map.v1.xy":
		return _fail("schema was not normalized")
	var buckets: Array = data.get("player_buckets", []) as Array
	if not buckets.has("1P") or not buckets.has("2V2") or not buckets.has("4P_FFA"):
		return _fail("shared non-3P player buckets missing: %s" % str(buckets))
	var slots: Array = data.get("structure_slots", []) as Array
	if slots.size() != 1:
		return _fail("expected exactly one generated structure slot: %s" % str(slots))
	var slot: Dictionary = slots[0] as Dictionary
	var gp: Array = slot.get("grid_pos", []) as Array
	if gp.size() < 2 or int(gp[0]) != 4 or int(gp[1]) != 3:
		return _fail("centroid slot grid_pos should be [4,3]: %s" % str(slot))
	if not (data.get("towers", []) as Array).is_empty() or not (data.get("barracks", []) as Array).is_empty():
		return _fail("finalizer should author slots, not actual structures")
	var saved: Dictionary = MapAuthoringFinalize.save_json(OUT_PATH, data)
	if not bool(saved.get("ok", false)):
		return _fail("save_json failed: %s" % str(saved))
	var loaded: Dictionary = MAP_LOADER.load_map(OUT_PATH)
	if not bool(loaded.get("ok", false)):
		return _fail("finalized map failed MAP_LOADER.load_map: %s" % str(loaded))
	var model: Dictionary = loaded.get("data", {}) as Dictionary
	var model_slots: Array = model.get("structure_slots", []) as Array
	if model_slots.size() != 1:
		return _fail("loaded model should preserve one structure slot: %s" % str(model_slots))
	var payload: Dictionary = {
		"version": 1,
		"hit": true,
		"categories": {MatchSetupRandomizer.CATEGORY_BARRACKS_POWER: 20},
		"structures": {"kind": "barracks", "slot_policy": "all_slots"}
	}
	var randomized: Dictionary = MatchSetupRandomizer.apply_to_map_data(model, payload)
	var randomized_barracks: Array = randomized.get("barracks", []) as Array
	var randomized_towers: Array = randomized.get("towers", []) as Array
	if randomized_barracks.size() != 1 or not randomized_towers.is_empty():
		return _fail("randomizer should materialize exactly one barracks from slot")
	var barracks: Dictionary = randomized_barracks[0] as Dictionary
	var barracks_gp: Array = barracks.get("grid_pos", []) as Array
	if barracks_gp.size() < 2 or int(barracks_gp[0]) != 4 or int(barracks_gp[1]) != 3:
		return _fail("randomized barracks should use centroid slot position: %s" % str(barracks))
	return false

func _test_randomizer_assigns_active_start_slots() -> bool:
	var map_data: Dictionary = {
		"id": "MAP_TEST",
		"hives": [
			{"id": 1, "grid_pos": [0, 0], "owner_id": 1},
			{"id": 2, "grid_pos": [1, 0], "owner_id": 3},
			{"id": 3, "grid_pos": [2, 0], "owner_id": 4},
			{"id": 4, "grid_pos": [3, 0], "owner_id": 2},
			{"id": 5, "grid_pos": [0, 1], "owner_id": 0}
		],
		"start_slots": [1, 2, 3, 4]
	}
	var payload: Dictionary = {"version": 1, "hit": false, "seed": 12345, "categories": {}}
	var assigned: Dictionary = MatchSetupRandomizer.apply_start_slots(map_data, payload, [1, 2])
	var hives: Array = assigned.get("hives", []) as Array
	var counts: Dictionary = _owner_counts(hives)
	if int(counts.get(1, 0)) != 1 or int(counts.get(2, 0)) != 1:
		return _fail("1v1 start slots should assign exactly one P1 and one P2 hive: %s" % str(counts))
	if int(counts.get(3, 0)) != 0 or int(counts.get(4, 0)) != 0:
		return _fail("1v1 start slots should neutralize inactive P3/P4 starts: %s" % str(counts))
	if int(counts.get(0, 0)) != 3:
		return _fail("1v1 start slots should leave two unused starts plus existing NPC neutral: %s" % str(counts))
	var assigned_4p: Dictionary = MatchSetupRandomizer.apply_start_slots(map_data, payload, [1, 2, 3, 4])
	var counts_4p: Dictionary = _owner_counts(assigned_4p.get("hives", []) as Array)
	for owner_id in [1, 2, 3, 4]:
		if int(counts_4p.get(owner_id, 0)) != 1:
			return _fail("4P start slots should assign one hive to owner %d: %s" % [owner_id, str(counts_4p)])
	return false

func _owner_counts(hives: Array) -> Dictionary:
	var counts: Dictionary = {}
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var owner_id: int = int((hive_any as Dictionary).get("owner_id", 0))
		counts[owner_id] = int(counts.get(owner_id, 0)) + 1
	return counts

func _fail(message: String) -> bool:
	push_error("MAP_AUTHORING_FINALIZE_SMOKE: %s" % message)
	return true
