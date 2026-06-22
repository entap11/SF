extends SceneTree

const ProgressiveConfigScript := preload("res://scripts/state/progressive_config.gd")
const MapLoaderScript := preload("res://scripts/maps/map_loader.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _test_star_thresholds():
		return
	if not _test_hive_counting():
		return
	if not _test_stage_plan():
		return
	print("PROGRESSIVE_CONFIG_SMOKE: PASS")
	quit(0)


func _test_star_thresholds() -> bool:
	var t12: Dictionary = ProgressiveConfigScript.threshold_ms_for_hives(12)
	var t13: Dictionary = ProgressiveConfigScript.threshold_ms_for_hives(13)
	var four12: int = int(t12.get("four_star_ms", 0))
	var three12: int = int(t12.get("three_star_ms", 0))
	var two12: int = int(t12.get("two_star_ms", 0))
	if not (four12 < three12 and three12 < two12):
		return _fail("expected four-star threshold < three-star threshold < two-star threshold")
	if int(t13.get("two_star_ms", 0)) <= two12:
		return _fail("larger hive count should receive more normalized two-star time")
	if ProgressiveConfigScript.stars_for_elapsed(four12, t12, true, "domination") != 4:
		return _fail("elapsed at four-star threshold should award 4")
	if ProgressiveConfigScript.stars_for_elapsed(four12 + 1, t12, true, "domination") != 3:
		return _fail("elapsed after four-star threshold should award 3")
	if ProgressiveConfigScript.stars_for_elapsed(three12 + 1, t12, true, "domination") != 2:
		return _fail("elapsed after three-star threshold should award 2")
	if ProgressiveConfigScript.stars_for_elapsed(two12 + 1, t12, true, "domination") != 1:
		return _fail("domination win after two-star threshold should award 1")
	if ProgressiveConfigScript.stars_for_elapsed(two12 + 1, t12, true, "Elimination") != 1:
		return _fail("elimination win after two-star threshold should award 1")
	if ProgressiveConfigScript.stars_for_elapsed(1, t12, false, "domination") != 0:
		return _fail("loss should award 0")
	if ProgressiveConfigScript.stars_for_elapsed(1, t12, true, "timeout") != 0:
		return _fail("non-domination win reason should not award progressive stars")
	return true


func _test_hive_counting() -> bool:
	var map_data: Dictionary = {
		"hives": [
			{"id": 1, "owner_id": 1},
			{"id": 2, "owner_id": 0},
			{"id": 3, "owner_id": 2},
			{"id": 4, "owner": "P1"},
			{"id": 5, "owner": "NPC"}
		]
	}
	var count: int = ProgressiveConfigScript.conquerable_hive_count_from_map_data(map_data)
	if count != 3:
		return _fail("expected 3 conquerable hives, got %d" % count)
	var node_schema_map_data: Dictionary = {
		"hives": [],
		"nodes": [
			{"id": "p1", "kind": "hive", "owner": "P1"},
			{"id": "p2", "kind": "hive", "owner": "P2"},
			{"id": "n1", "kind": "hive", "owner": "NPC"},
			{"id": "n2", "kind": "buff", "owner": "NPC"}
		]
	}
	var node_count: int = ProgressiveConfigScript.conquerable_hive_count_from_map_data(node_schema_map_data)
	if node_count != 2:
		return _fail("expected 2 node-schema conquerable hives, got %d" % node_count)
	return true


func _test_stage_plan() -> bool:
	var plan: Array[Dictionary] = ProgressiveConfigScript.build_stage_plan(ProgressiveConfigScript.DEFAULT_STAGE_COUNT)
	if plan.size() != ProgressiveConfigScript.DEFAULT_STAGE_COUNT:
		return _fail("default stage plan size mismatch")
	var first: Dictionary = plan[0]
	var middle: Dictionary = plan[int(plan.size() / 2)]
	var last: Dictionary = plan[plan.size() - 1]
	if str(first.get("bot_tier", "")) != ProgressiveConfigScript.BOT_TIER_EASY:
		return _fail("first stage should be easy")
	if str(first.get("bot_style", "")) != "balancer":
		return _fail("first stage should use the balancer bot style")
	if int(first.get("conquerable_hive_count", 0)) != 12:
		return _fail("first stage should count 12 conquerable hives")
	if int(first.get("bot_start_power_bonus", -1)) != 0:
		return _fail("first stage should not give the bot a starting power bonus")
	if int(first.get("player_start_power_delta", -1)) != 0:
		return _fail("first stage should not reduce the player start power")
	if str(middle.get("bot_tier", "")) != ProgressiveConfigScript.BOT_TIER_MEDIUM:
		return _fail("middle stage should be medium")
	if str(last.get("bot_tier", "")) != ProgressiveConfigScript.BOT_TIER_HARD:
		return _fail("last stage should be hard")
	if int(first.get("stage_number", 0)) != 1 or int(last.get("stage_number", 0)) != plan.size():
		return _fail("stage numbers should be one-based and sequential")
	for stage in plan:
		var stage_number: int = int(stage.get("stage_number", 0))
		var path: String = str(stage.get("map_path", ""))
		if path.is_empty():
			return _fail("stage %d has no resolved map path" % stage_number)
		var loaded: Dictionary = MapLoaderScript.load_map(path)
		if not bool(loaded.get("ok", false)):
			return _fail("stage %d map path should load: %s" % [stage_number, str(loaded.get("err", ""))])
		var hives: int = int(stage.get("conquerable_hive_count", 0))
		if hives <= 0:
			return _fail("stage %d has invalid conquerable hive count" % stage_number)
		var thresholds: Dictionary = stage.get("thresholds_ms", {}) as Dictionary
		if not (int(thresholds.get("four_star_ms", 0)) < int(thresholds.get("three_star_ms", 0)) and int(thresholds.get("three_star_ms", 0)) < int(thresholds.get("two_star_ms", 0))):
			return _fail("stage %d has invalid threshold ordering" % stage_number)
	if int(last.get("npc_power_bonus", 0)) <= int(first.get("npc_power_bonus", 0)):
		return _fail("late stages should increase NPC power pressure")
	if int(last.get("npc_power_bonus", 0)) > 12:
		return _fail("late stages should cap NPC power pressure")
	if int(last.get("bot_start_power_bonus", 0)) > 8:
		return _fail("late stages should cap bot starting power pressure")
	if int(last.get("player_start_power_delta", 0)) >= int(first.get("player_start_power_delta", 0)):
		return _fail("late stages should lower the player start power")
	if int(last.get("player_start_power_delta", 0)) < -4:
		return _fail("late stages should not over-reduce player start power")
	var launch_options: Dictionary = ProgressiveConfigScript.launch_options_for_stage(first)
	if str(launch_options.get("mode_id", "")) != ProgressiveConfigScript.MODE_ID:
		return _fail("launch options should carry progressive mode id")
	if not launch_options.has("progressive_thresholds_ms"):
		return _fail("launch options should carry progressive thresholds")
	if int(launch_options.get("progressive_bot_attack_grace_ms", 0)) != ProgressiveConfigScript.BOT_ATTACK_GRACE_MS:
		return _fail("launch options should carry the Progressive bot attack grace")
	return true


func _fail(message: String) -> bool:
	push_error("PROGRESSIVE_CONFIG_SMOKE: %s" % message)
	quit(1)
	return false
