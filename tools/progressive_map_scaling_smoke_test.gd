extends SceneTree

const MapApplierScript := preload("res://scripts/maps/map_applier.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	set_meta("vs_mode", "PROGRESSIVE")
	set_meta("progressive_npc_power_bonus", 5)
	set_meta("progressive_bot_start_power_bonus", 7)
	set_meta("progressive_player_start_power_delta", -3)
	var map_data: Dictionary = {
		"id": "progressive_scaling_smoke",
		"hives": [
			{"id": 1, "owner_id": 1, "power": 10},
			{"id": 2, "owner_id": 2, "power": 10},
			{"id": 3, "owner_id": 0, "power": 10}
		]
	}
	var scaled: Dictionary = MapApplierScript._apply_progressive_scaling(map_data)
	var hives: Array = scaled.get("hives", []) as Array
	if int((hives[0] as Dictionary).get("power", 0)) != 7:
		_fail("player hive should be reduced")
		return
	if int((hives[1] as Dictionary).get("power", 0)) != 17:
		_fail("bot hive should receive bot bonus")
		return
	if int((hives[2] as Dictionary).get("power", 0)) != 15:
		_fail("NPC hive should receive NPC bonus")
		return
	print("PROGRESSIVE_MAP_SCALING_SMOKE: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error("PROGRESSIVE_MAP_SCALING_SMOKE: %s" % message)
	quit(1)
