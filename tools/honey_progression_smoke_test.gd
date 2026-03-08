extends SceneTree

class FakeSimRunner:
	extends Node
	signal match_ended(winner_id: int, reason: String)

const HONEY_STATE_PATH: String = "user://honey_progression_state.json"
const PROFILE_PATH: String = "user://profile.cfg"

func _init() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HONEY_STATE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))

	var honey_state: Node = get_root().get_node_or_null("HoneyProgressionState")
	var profile_manager: Node = get_root().get_node_or_null("ProfileManager")
	if honey_state == null or profile_manager == null:
		push_error("HONEY_SMOKE: required autoload missing")
		quit(1)
		return

	if honey_state.has_method("debug_reset_state"):
		honey_state.call("debug_reset_state")
	if profile_manager.has_method("set_honey_balance"):
		profile_manager.call("set_honey_balance", 0)
	await process_frame

	for i in range(5):
		_assert_ok(
			honey_state.call("intent_record_async_completion", "STAGE_RACE", 3, false, {"event_id": "free_async_%d" % i}) as Dictionary,
			"free async completion %d" % i
		)
	_assert_eq(int(profile_manager.call("get_honey_balance")), 1, "five async completions should mint one honey")

	var duplicate: Dictionary = honey_state.call("intent_record_async_completion", "STAGE_RACE", 3, false, {"event_id": "free_async_0"}) as Dictionary
	_assert_true(not bool(duplicate.get("ok", false)), "duplicate async event should be rejected")

	_assert_ok(
		honey_state.call("intent_record_async_final_placement", "STAGE_RACE", 3, 1, false, "WEEKLY", {"event_id": "place_stage_1"}) as Dictionary,
		"stage race placement"
	)
	_assert_eq(int(profile_manager.call("get_honey_balance")), 6, "first place async bonus should add five honey")

	_assert_ok(honey_state.call("intent_record_async_completion", "TIMED_RACE", 3, false, {"event_id": "timed_3"}) as Dictionary, "timed 3")
	_assert_ok(honey_state.call("intent_record_async_completion", "MISS_N_OUT", 3, false, {"event_id": "miss_3"}) as Dictionary, "miss 3")
	_assert_ok(honey_state.call("intent_record_async_completion", "STAGE_RACE", 5, false, {"event_id": "stage_5"}) as Dictionary, "stage 5")
	_assert_ok(honey_state.call("intent_record_async_completion", "TIMED_RACE", 5, false, {"event_id": "timed_5"}) as Dictionary, "timed 5")
	_assert_ok(honey_state.call("intent_record_async_completion", "MISS_N_OUT", 5, false, {"event_id": "miss_5"}) as Dictionary, "miss 5")

	var snapshot: Dictionary = honey_state.call("get_snapshot") as Dictionary
	var weekly_claimed: Dictionary = snapshot.get("weekly_claimed", {}) as Dictionary
	_assert_true(bool(weekly_claimed.get("free_async_variety", false)), "free async weekly bonus should auto-claim")
	_assert_true(bool(weekly_claimed.get("async_3_map_variety", false)), "3-map async weekly bonus should auto-claim")
	_assert_true(bool(weekly_claimed.get("async_5_map_variety", false)), "5-map async weekly bonus should auto-claim")
	_assert_eq(int(profile_manager.call("get_honey_balance")), 27, "async bonuses should settle to expected whole honey")

	var fake_runner := FakeSimRunner.new()
	fake_runner.name = "SimRunner"
	get_root().add_child(fake_runner)
	await process_frame

	set_meta("vs_mode", "1V1")
	set_meta("vs_sync_start", true)
	set_meta("vs_free_roll", true)
	set_meta("vs_price_usd", 0)
	set_meta("vs_local_profile", {"uid": str(profile_manager.call("get_user_id"))})
	set_meta("vs_handshake_role", "host")
	fake_runner.emit_signal("match_ended", 1, "timeout")
	await process_frame

	snapshot = honey_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("total_honey_tenths_awarded", 0)), 274, "auto pvp win should add four tenths")

	set_meta("vs_mode", "STAGE_RACE")
	set_meta("vs_sync_start", false)
	set_meta("vs_free_roll", true)
	set_meta("vs_price_usd", 0)
	set_meta("vs_stage_map_paths", ["map_a", "map_b", "map_c"])
	set_meta("vs_stage_current_index", 1)
	remove_meta("honey_runtime_nonce")
	fake_runner.emit_signal("match_ended", 1, "round_end")
	await process_frame
	snapshot = honey_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("total_honey_tenths_awarded", 0)), 274, "non-final stage round should not award honey")

	set_meta("vs_stage_current_index", 2)
	remove_meta("honey_runtime_nonce")
	fake_runner.emit_signal("match_ended", 1, "round_end")
	await process_frame
	snapshot = honey_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("total_honey_tenths_awarded", 0)), 276, "final stage round should award async completion honey")

	print("HONEY_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	push_error("HONEY_SMOKE: %s failed -> %s" % [label, result])
	quit(1)

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	push_error("HONEY_SMOKE: %s (expected %d, got %d)" % [label, expected, actual])
	quit(1)

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("HONEY_SMOKE: %s" % label)
	quit(1)
