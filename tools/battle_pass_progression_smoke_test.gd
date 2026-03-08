extends SceneTree

class FakeSimRunner:
	extends Node
	signal match_ended(winner_id: int, reason: String)

const PASS_STATE_PATH: String = "user://battle_pass_state.json"
const PROFILE_PATH: String = "user://profile.cfg"

func _init() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PASS_STATE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))

	var battle_pass_state: Node = get_root().get_node_or_null("BattlePassState")
	var profile_manager: Node = get_root().get_node_or_null("ProfileManager")
	if battle_pass_state == null or profile_manager == null:
		push_error("BATTLE_PASS_SMOKE: required autoload missing")
		quit(1)
		return

	if battle_pass_state.has_method("debug_reset_state"):
		battle_pass_state.call("debug_reset_state")
	await process_frame

	var snapshot: Dictionary = battle_pass_state.call("get_snapshot") as Dictionary
	var projection: Dictionary = snapshot.get("prestige_projection", {}) as Dictionary
	_assert_eq(int(snapshot.get("side_quest_paths_available", 0)), 1, "free pass should expose one quest path")
	_assert_eq(int(snapshot.get("visible_level_cap", 0)), 100, "free pass should cap at level 100")
	_assert_eq(int(snapshot.get("prestige_pool_base_slots", 0)), 500, "season-start prestige pool should seed to 500")
	_assert_eq(int(projection.get("projected_prestige_pool_base", 0)), 500, "prestige projection should match the seeded base")
	_assert_eq((snapshot.get("quests", []) as Array).size(), 4, "free pass should expose only base quests")
	_assert_eq((snapshot.get("quest_bonuses", []) as Array).size(), 1, "free pass should expose only base quest bonus")

	for i in range(5):
		_assert_ok(
			battle_pass_state.call("intent_record_pvp_completion", "1V1", false, 0, false, {"event_id": "free_pvp_%d" % i}) as Dictionary,
			"free pvp completion %d" % i
		)
	snapshot = battle_pass_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("battle_pass_level", 0)), 3, "five free pvp completions should reach level 3 on the progressive curve")

	battle_pass_state.call("debug_reset_state")
	await process_frame
	var veteran_result: Dictionary = battle_pass_state.call("intent_apply_veteran_start", {
		"member_this_season": true,
		"member_last_season": true,
		"played_every_mode_last_season": true,
		"money_async_last_season": true,
		"money_vs_last_season": true
	}, false) as Dictionary
	_assert_ok(veteran_result, "veteran start")
	snapshot = battle_pass_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("battle_pass_level", 0)), 5, "full veteran grant should start at level 5")
	_assert_true(bool(snapshot.get("veteran_lock_active", false)), "veteran rewards should stay locked until level 10")

	battle_pass_state.call("debug_reset_state")
	await process_frame
	_assert_ok(battle_pass_state.call("intent_set_pass_entitlements", true, false) as Dictionary, "premium entitlements")
	var premium_result: Dictionary = battle_pass_state.call(
		"intent_record_pvp_completion",
		"1V1",
		false,
		0,
		false,
		{"event_id": "premium_free_pvp"}
	) as Dictionary
	_assert_ok(premium_result, "premium free pvp")
	_assert_eq(int(premium_result.get("xp_awarded", 0)), 24, "premium should apply a 20 percent nectar bonus")
	snapshot = battle_pass_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("side_quest_paths_available", 0)), 2, "premium should unlock the first side quest path")
	_assert_eq(int(snapshot.get("visible_level_cap", 0)), 110, "premium should see level 110")
	_assert_eq((snapshot.get("quests", []) as Array).size(), 6, "premium should expose six quests")
	_assert_eq((snapshot.get("quest_bonuses", []) as Array).size(), 2, "premium should expose two quest bonuses")
	var premium_rows: Array = snapshot.get("rows", []) as Array
	_assert_eq(int((premium_rows[100] as Dictionary).get("level", 0)), 101, "premium rows should include level 101")
	_assert_eq(int((premium_rows[100] as Dictionary).get("scarcity_cap", 0)), 500, "level 101 should start with 500 prestige slots")
	_assert_eq(int((premium_rows[101] as Dictionary).get("scarcity_cap", 0)), 450, "level 102 should decay to 450 slots")

	battle_pass_state.call("debug_reset_state")
	await process_frame
	_assert_ok(battle_pass_state.call("intent_set_pass_entitlements", true, true) as Dictionary, "elite entitlements")
	var elite_result: Dictionary = battle_pass_state.call(
		"intent_record_pvp_completion",
		"1V1",
		false,
		0,
		false,
		{"event_id": "elite_free_pvp"}
	) as Dictionary
	_assert_ok(elite_result, "elite free pvp")
	_assert_eq(int(elite_result.get("xp_awarded", 0)), 26, "elite should apply a 30 percent nectar bonus")
	snapshot = battle_pass_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("side_quest_paths_available", 0)), 3, "elite should unlock both side quest paths")
	_assert_eq(int(snapshot.get("visible_level_cap", 0)), 120, "elite should see level 120")
	_assert_eq((snapshot.get("quests", []) as Array).size(), 8, "elite should expose all quest paths")
	_assert_eq((snapshot.get("quest_bonuses", []) as Array).size(), 3, "elite should expose all quest bonuses")
	var contest_result: Dictionary = battle_pass_state.call("intent_record_contest_result", "WEEKLY", 1, {"event_id": "weekly_contest_top1"}) as Dictionary
	_assert_ok(contest_result, "weekly contest result")
	_assert_eq(int(contest_result.get("xp_awarded", 0)), 39, "elite weekly contest win should award 39 nectar XP")

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
	remove_meta("bp_runtime_nonce")
	fake_runner.emit_signal("match_ended", 1, "timeout")
	await process_frame
	snapshot = battle_pass_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("battle_pass_xp", 0)), 96, "runtime free pvp should add elite-weighted nectar XP including the win bonus")

	set_meta("vs_mode", "STAGE_RACE")
	set_meta("vs_sync_start", false)
	set_meta("vs_free_roll", true)
	set_meta("vs_price_usd", 0)
	set_meta("vs_stage_map_paths", ["map_a", "map_b", "map_c"])
	set_meta("vs_stage_current_index", 1)
	remove_meta("bp_runtime_nonce")
	fake_runner.emit_signal("match_ended", 1, "round_end")
	await process_frame
	snapshot = battle_pass_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("battle_pass_xp", 0)), 96, "non-final async stage round should not award nectar")

	set_meta("vs_stage_current_index", 2)
	remove_meta("bp_runtime_nonce")
	fake_runner.emit_signal("match_ended", 1, "round_end")
	await process_frame
	snapshot = battle_pass_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("battle_pass_xp", 0)), 119, "final async stage round should award elite-weighted async nectar XP")

	print("BATTLE_PASS_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	push_error("BATTLE_PASS_SMOKE: %s failed -> %s" % [label, result])
	quit(1)

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	push_error("BATTLE_PASS_SMOKE: %s (expected %d, got %d)" % [label, expected, actual])
	quit(1)

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("BATTLE_PASS_SMOKE: %s" % label)
	quit(1)
