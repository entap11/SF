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
	var auto_owner_one_hive: int = int((auto_flags.get(1, {}) as Dictionary).get("hive_id", 0))
	var auto_owner_two_hive: int = int((auto_flags.get(2, {}) as Dictionary).get("hive_id", 0))
	_assert_true(auto_owner_one_hive > 0, "auto assign should choose a visible flag hive for owner 1")
	_assert_true(auto_owner_two_hive > 0, "auto assign should choose a visible flag hive for owner 2")
	_assert_eq(auto_owner_two_hive, _mirrored_partner_for_test(auto_owner_one_hive), "standard CTF auto assign should stay mirrored")

	ops.reset_match_state()
	ops.match_phase = ops.MatchPhase.PREMATCH
	ops.state = state
	var ctf_result: Dictionary = ops.configure_capture_flag_mode({
		"hidden_flag": true,
		"flag_selection_owner_id": 1
	})
	_assert_true(bool(ctf_result.get("rules", {}).get("flag_selection_pending", false)), "hidden CTF should default to prematch player flag selection")
	var hidden_select_result: Dictionary = ops.request_capture_flag_selection(1, 1)
	_assert_true(bool(hidden_select_result.get("ok", false)), "hidden CTF prematch selection should succeed")

	var owner_one_view: Dictionary = ops.build_capture_flag_view(1)
	var owner_two_view: Dictionary = ops.build_capture_flag_view(2)
	_assert_true(_viewer_can_see_flag(owner_one_view, 1), "owner 1 should see own hidden flag")
	_assert_true(not _viewer_can_see_flag(owner_one_view, 2), "owner 1 should not see owner 2 hidden flag")
	_assert_true(_viewer_can_see_flag(owner_two_view, 2), "owner 2 should see own hidden flag")
	_assert_true(not _viewer_can_see_flag(owner_two_view, 1), "owner 2 should not see owner 1 hidden flag")

	ops.reset_match_state()
	ops.match_phase = ops.MatchPhase.PREMATCH
	ops.state = state
	var pending_result: Dictionary = ops.configure_capture_flag_mode({
		"hidden_flag": true,
		"flag_selection_random_mirrored": false,
		"flag_selection_mode": "player_select",
		"flag_selection_owner_id": 1
	})
	_assert_true(bool(pending_result.get("rules", {}).get("flag_selection_pending", false)), "player-select timeout path should start pending")
	var timeout_result: Dictionary = ops.auto_complete_capture_flag_selection(1)
	_assert_true(bool(timeout_result.get("ok", false)), "timeout auto-select should resolve the pending flag choice")
	var timeout_owner_one_hive: int = int(ops.get_capture_flag_hive_id(1))
	var timeout_owner_two_hive: int = int(ops.get_capture_flag_hive_id(2))
	_assert_true(timeout_owner_one_hive > 0, "timeout auto-select should assign a hidden flag hive for owner 1")
	_assert_true(timeout_owner_two_hive > 0, "timeout auto-select should assign a hidden flag hive for owner 2")
	_assert_true(timeout_owner_two_hive != _mirrored_partner_for_test(timeout_owner_one_hive), "hidden timeout auto-select should avoid mirrored pair reveals")

	ops.reset_match_state()
	ops.match_phase = ops.MatchPhase.PREMATCH
	ops.state = state
	pending_result = ops.configure_capture_flag_mode({
		"hidden_flag": true,
		"flag_selection_mode": "player_select",
		"flag_selection_owner_id": 1,
		"flag_selection_random_mirrored": false,
		"flag_move_count_max": 1,
		"flag_move_reveals": true
	})
	_assert_true(bool(pending_result.get("rules", {}).get("flag_selection_pending", false)), "player-select mode should start pending")
	var select_result: Dictionary = ops.request_capture_flag_selection(1, 2)
	_assert_true(bool(select_result.get("ok", false)), "player flag selection should succeed")
	_assert_eq(int(ops.get_capture_flag_hive_id(1)), 2, "owner 1 selected flag hive should stick")
	_assert_eq(int(ops.get_capture_flag_hive_id(2)), 4, "owner 2 hidden flag hive should stay balanced without mirroring owner 1 selection")
	_assert_true(not ops.is_capture_flag_selection_pending(1), "player-select mode should clear pending after selection")

	ops.match_phase = ops.MatchPhase.RUNNING
	var move_result: Dictionary = ops.request_capture_flag_move(1, 1)
	_assert_true(bool(move_result.get("ok", false)), "flag move should succeed while running")
	var moved_flag: Dictionary = ops.get_capture_flag_for_owner(1)
	_assert_eq(int(moved_flag.get("hive_id", 0)), 1, "flag move should land on requested hive")
	_assert_true(bool(moved_flag.get("revealed_to_all", false)), "moved flag should reveal to all when configured")
	_assert_eq(int(moved_flag.get("moves_remaining", -1)), 0, "flag move should consume move budget")

	var win_system: Node = WinSystem.new()
	win_system.bind_state(state, ops)
	state.find_hive_by_id(int(ops.get_capture_flag_hive_id(2))).owner_id = 1
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

func _mirrored_partner_for_test(hive_id: int) -> int:
	match hive_id:
		1:
			return 4
		2:
			return 3
		3:
			return 2
		4:
			return 1
	return 0

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
