extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	await process_frame
	_test_barracks_route_resets_when_offline()
	if not _failed:
		print("BARRACKS_ROUTE_RESET_SMOKE: PASS")
	quit(1 if _failed else 0)

func _test_barracks_route_resets_when_offline() -> void:
	var state := GameState.new()
	state.load_from_map_dict({
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 2, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 3, "x": 4, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"}
		],
		"barracks": [
			{
				"id": 10,
				"x": 2,
				"y": 1,
				"owner_id": 1,
				"is_controlled": true,
				"active": true,
				"control_hive_ids": [1, 2, 3],
				"required_hive_ids": [1, 2, 3],
				"route_targets": [2, 1],
				"route_hive_ids": [2, 1],
				"preferred_targets": [2, 1],
				"route_cursor": 7,
				"rr_index": 7
			}
		]
	})
	_expect_eq(state.barracks.size(), 1, "state should load one barracks")
	if state.barracks.is_empty():
		return
	var barracks: Dictionary = state.barracks[0] as Dictionary
	var system_script: Script = load("res://scripts/systems/barracks_system.gd")
	_expect_true(system_script != null, "BarracksSystem script should load")
	if system_script == null:
		return
	var barracks_system: Node = system_script.new()
	get_root().add_child(barracks_system)
	barracks_system.call("bind_state", state)
	barracks["owner_id"] = 0
	barracks["is_controlled"] = false
	barracks_system.call("tick", 0.1)
	_expect_true((barracks.get("route_targets", []) as Array).is_empty(), "offline barracks should clear route_targets")
	_expect_true((barracks.get("route_hive_ids", []) as Array).is_empty(), "offline barracks should clear route_hive_ids")
	_expect_true((barracks.get("preferred_targets", []) as Array).is_empty(), "offline barracks should clear preferred_targets")
	_expect_eq(int(barracks.get("route_cursor", -1)), 0, "offline barracks should reset route_cursor")
	_expect_eq(int(barracks.get("rr_index", -1)), 0, "offline barracks should reset rr_index")
	barracks_system.queue_free()

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("BARRACKS_ROUTE_RESET_SMOKE: %s" % message)

func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failed = true
	push_error("BARRACKS_ROUTE_RESET_SMOKE: %s actual=%s expected=%s" % [message, str(actual), str(expected)])
