extends SceneTree

func _init() -> void:
	await process_frame
	var ops: Node = get_root().get_node_or_null("OpsState")
	if ops == null:
		_fail("OpsState autoload missing")
		return

	var state: GameState = GameState.new()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 10, "Hive"),
		HiveData.new(2, Vector2i(1, 0), 1, 10, "Hive"),
		HiveData.new(3, Vector2i(4, 0), 2, 10, "Hive"),
		HiveData.new(4, Vector2i(5, 0), 2, 10, "Hive")
	]
	state.rebuild_indexes()
	ops.state = state
	ops.reset_match_state()
	ops.match_phase = ops.MatchPhase.RUNNING

	var auto_assign_result: Dictionary = ops.configure_capture_flag_mode({
		"hidden_flag": false
	})
	var auto_flags: Dictionary = auto_assign_result.get("flags_by_owner", {}) as Dictionary
	_assert_eq(int((auto_flags.get(1, {}) as Dictionary).get("hive_id", 0)), 1, "auto assign should pick the outer mirrored hive for owner 1")
	_assert_eq(int((auto_flags.get(2, {}) as Dictionary).get("hive_id", 0)), 4, "auto assign should pick the outer mirrored hive for owner 2")

	ops.reset_match_state()
	ops.match_phase = ops.MatchPhase.RUNNING
	ops.state = state
	var ctf_result: Dictionary = ops.configure_capture_flag_mode({
		"hidden_flag": true,
		"flag_hives": {1: 1, 2: 4}
	})
	_assert_true(bool(ctf_result.get("flags_by_owner", {}).has(1)), "owner 1 flag should be assigned")
	_assert_true(bool(ctf_result.get("flags_by_owner", {}).has(2)), "owner 2 flag should be assigned")

	var owner_one_view: Dictionary = ops.build_capture_flag_view(1)
	var owner_two_view: Dictionary = ops.build_capture_flag_view(2)
	_assert_true(_viewer_can_see_flag(owner_one_view, 1), "owner 1 should see own hidden flag")
	_assert_true(not _viewer_can_see_flag(owner_one_view, 2), "owner 1 should not see owner 2 hidden flag")
	_assert_true(_viewer_can_see_flag(owner_two_view, 2), "owner 2 should see own hidden flag")
	_assert_true(not _viewer_can_see_flag(owner_two_view, 1), "owner 2 should not see owner 1 hidden flag")

	var win_system: Node = WinSystem.new()
	win_system.bind_state(state, ops)
	state.find_hive_by_id(4).owner_id = 1
	win_system.notify_hive_owner_changed()
	var result: Variant = win_system.tick(state, Time.get_ticks_msec())
	if typeof(result) != TYPE_DICTIONARY:
		_fail("flag capture win result missing")
		return
	var win_result: Dictionary = result as Dictionary
	_assert_eq(int(win_result.get("winner_id", 0)), 1, "capturing enemy flag should award player 1 the win")
	_assert_str_eq(str(win_result.get("reason", "")), "flag_capture", "capture flag win should use flag_capture reason")

	print("CAPTURE_FLAG_SMOKE: PASS")
	quit(0)

func _viewer_can_see_flag(view: Dictionary, owner_id: int) -> bool:
	var flags: Array = view.get("flags", []) as Array
	for flag_any in flags:
		if typeof(flag_any) != TYPE_DICTIONARY:
			continue
		var flag: Dictionary = flag_any as Dictionary
		if int(flag.get("owner_id", 0)) != owner_id:
			continue
		return bool(flag.get("visible_to_viewer", false))
	return false

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	_fail("%s (expected %d, got %d)" % [label, expected, actual])

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_fail(label)

func _assert_str_eq(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		return
	_fail("%s (expected %s, got %s)" % [label, expected, actual])

func _fail(message: String) -> void:
	push_error("CAPTURE_FLAG_SMOKE: %s" % message)
	quit(1)
