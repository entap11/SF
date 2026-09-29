extends SceneTree

const View := preload("res://scripts/renderers/buff_effect_presentation.gd")
const System := preload("res://scripts/sim/authoritative_buff_system.gd")
const Catalog := preload("res://scripts/state/buff_catalog.gd")
var failed: bool = false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var view := View.new()
	root.add_child(view)
	view.setup(null, null, null)
	var checked: int = 0
	for buff: Dictionary in Catalog.list_all():
		if buff["canonical_id"] == "FREEZE_LANE":
			continue
		var state := GameState.new()
		state.init_demo_map()
		state.rebuild_indexes()
		var target_type: String = str(buff["target_type"])
		if target_type == "none":
			target_type = "global"
		var result: Dictionary = System.activate(state, {"match_id": "view-test", "activation_id": buff["id"],
			"owner_id": 1, "buff_id": buff["id"], "tier": buff["tier"], "target_type": target_type,
			"target_id": "global" if target_type == "global" else 1})
		check(bool(result.get("ok", false)), "authoritative activation: " + str(buff["id"]))
		var snapshot: Dictionary = System.snapshot(state)
		var before: String = JSON.stringify(snapshot)
		view.clear_presentation()
		view.apply_authoritative_snapshot(snapshot)
		check(view.get_snapshot()["active_count"] == 1, "family/tier projects once")
		check(view.get_snapshot()["markers"][0]["remaining_ms"] == int(float(buff["duration_sec"]) * 1000), "duration follows actual tier")
		view._process(60.0)
		check(JSON.stringify(System.snapshot(state)) == before and JSON.stringify(snapshot) == before, "rendering cannot mutate authority or input")
		check(view.get_snapshot()["markers"][0]["remaining_ms"] == int(float(buff["duration_sec"]) * 1000), "wall time cannot run countdown")
		for repeat in range(12):
			view.apply_authoritative_snapshot(snapshot)
		check(view.get_child_count() == 0 and view.get_snapshot()["active_count"] == 1, "snapshots do not allocate effect nodes")
		state.tick = int(float(buff["duration_sec"]) * 10)
		var events: Array[Dictionary] = System.tick(state)
		for event: Dictionary in events:
			view.handle_lifecycle_event(event)
			view.handle_lifecycle_event(event)
		view.apply_authoritative_snapshot(System.snapshot(state))
		check(view.get_snapshot()["active_count"] == 0 and view.get_snapshot()["ending_count"] == 1, "canonical expiry ends once")
		check(view.get_snapshot()["release_count"] == 0, "empty Supercharge cannot claim a release")
		state.tick += 8
		view.apply_authoritative_snapshot(System.snapshot(state))
		check(not view.is_processing() and view.get_snapshot()["ending_count"] == 0, "ending retires and renderer sleeps")
		view.apply_authoritative_snapshot(snapshot, "reduced")
		check(not view.is_processing(), "reduced VFX retains snapshot cues without a frame loop")
		for event: Dictionary in events:
			view.handle_lifecycle_event(event)
		check(view.get_snapshot()["ending_count"] == 0, "reduced VFX omits ending motion")
		checked += 1
	check(checked == 33, "all eleven remaining families and three tiers are covered")
	_test_scope_and_cancellation(view)
	_test_release(view)
	_test_ops_event_forwarding(view)
	view.clear_presentation()
	view.queue_free()
	await process_frame
	print("BUFF_EFFECT_PRESENTATION_SMOKE: %s (%d tier entries)" % ["FAIL" if failed else "PASS", checked])
	quit(1 if failed else 0)

func _test_scope_and_cancellation(view: Node2D) -> void:
	var state := GameState.new()
	state.init_demo_map()
	state.rebuild_indexes()
	System.activate(state, {"match_id": "scope", "activation_id": "scope-one", "owner_id": 1,
		"buff_id": "buff_global_shock_immunity_classic", "tier": "classic", "target_type": "global", "target_id": "global"})
	var original: Dictionary = System.snapshot(state)
	view.apply_authoritative_snapshot(original)
	check(view.get_snapshot()["markers"][0]["hive_ids"] == [1, 2], "global cue follows exact canonical scope")
	state.find_hive_by_id(1).owner_id = 2
	state.find_hive_by_id(3).owner_id = 1
	state.tick = 1
	System.tick(state)
	view.apply_authoritative_snapshot(System.snapshot(state))
	check(view.get_snapshot()["markers"][0]["hive_ids"] == [2], "lost hive clears and new capture is not added")
	var missing: Dictionary = original.duplicate(true)
	missing["tick"] = 30
	missing["effects"] = []
	view.apply_authoritative_snapshot(missing)
	check(view.get_snapshot()["ending_count"] == 0, "missing snapshots cannot fabricate terminal events")
	view.apply_authoritative_snapshot(original)
	missing["match_id"] = "other"
	missing["effects"] = original["effects"]
	view.apply_authoritative_snapshot(missing)
	check(view.get_snapshot()["active_count"] == 0, "stale effects cannot cross match epoch")

func _test_release(view: Node2D) -> void:
	for lose_source: bool in [false, true]:
		var state := GameState.new()
		state.init_demo_map()
		state.rebuild_indexes()
		var units := UnitSystem.new()
		units.bind_state(state)
		System.activate(state, {"match_id": "queue", "activation_id": "queue-one", "owner_id": 1,
			"buff_id": "buff_supercharge_queue_classic", "tier": "classic", "target_type": "lane", "target_id": 1})
		units.spawn_unit({"owner_id": 1, "from_id": 1, "to_id": 2, "lane_id": 1, "amount": 1})
		view.clear_presentation()
		view.apply_authoritative_snapshot(System.snapshot(state))
		check(view.get_snapshot()["markers"][0]["queued_units"] == 1, "queue display uses actual banked bees")
		if lose_source:
			state.find_hive_by_id(1).owner_id = 2
		state.tick = 50
		for event: Dictionary in System.tick(state):
			view.handle_lifecycle_event(event)
		view.apply_authoritative_snapshot(System.snapshot(state))
		check(view.get_snapshot()["release_count"] == (0 if lose_source else 1), "source loss on expiry cannot masquerade as release")
		check(view.get_snapshot()["ending_count"] == (0 if lose_source else 1), "source loss clears immediately")
		units.set("state", null)

func _test_ops_event_forwarding(view: Node2D) -> void:
	var ops: Node = root.get_node("OpsState")
	var previous: Variant = ops.get("state")
	var state := GameState.new()
	state.init_demo_map()
	state.rebuild_indexes()
	ops.set("state", state)
	var result: Dictionary = ops.call("apply_authoritative_buff_command", {"match_id": "ops-events", "activation_id": "ops-one", "owner_id": 1,
		"buff_id": "buff_hive_shield_single_classic", "tier": "classic", "target_type": "hive", "target_id": 1})
	check(bool(result.get("ok", false)), "OpsState accepts authoritative event fixture")
	view.apply_authoritative_snapshot(ops.call("get_authoritative_buff_snapshot"))
	var callback := Callable(view, "handle_lifecycle_event")
	var isolated_observer := func(event: Dictionary) -> void:
		(event["effect"] as Dictionary)["owner_id"] = 99
	ops.connect("authoritative_buff_lifecycle", callback)
	ops.connect("authoritative_buff_lifecycle", isolated_observer)
	state.tick = 50
	var events: Array = ops.call("tick_authoritative_buff_effects", 50)
	check(view.get_snapshot()["ending_count"] == 1, "OpsState publishes simulation expiry to presentation")
	check(events.size() == 1 and int(events[0]["effect"]["owner_id"]) == 1, "observers receive copies, not the returned simulation event")
	ops.disconnect("authoritative_buff_lifecycle", callback)
	ops.disconnect("authoritative_buff_lifecycle", isolated_observer)
	ops.set("state", previous)

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("BUFF_EFFECT_PRESENTATION: " + message)
