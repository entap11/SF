extends SceneTree

const WaxRewardPolicy = preload("res://scripts/state/wax_reward_policy.gd")
const HoneyEconomySimulator = preload("res://scripts/state/honey_economy_simulator.gd")
const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const SETTINGS_BACKEND_TOKEN: String = "swarmfront/vs/backend_token"

func _init() -> void:
	OS.set_environment("SF_VS_BACKEND_URL", "")
	OS.set_environment("SF_VS_BACKEND_TOKEN", "")
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
	ProjectSettings.set_setting(SETTINGS_BACKEND_TOKEN, "")
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var handshake: Node = get_root().get_node_or_null("VsHandshake")
	if handshake != null and handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	_test_wax_policy()
	await _test_competitive_wax_ledger()
	await _test_nectar_policy()
	_test_honey_simulator()
	print("ECONOMY_LAYER_SMOKE: PASS")
	quit(0)

func _test_wax_policy() -> void:
	var win_stronger: Dictionary = WaxRewardPolicy.evaluate_match({
		"match_id": "wax_policy_win",
		"player_id": "wax_a",
		"opponent_id": "wax_b",
		"mode_name": "1V1",
		"did_win": true,
		"player_rating": 1000.0,
		"opponent_rating": 1425.0
	})
	_assert_eq(int(win_stronger.get("final_wax_delta", 0)), 5, "win vs much stronger should award 5 Wax")
	var loss_weaker: Dictionary = WaxRewardPolicy.evaluate_match({
		"match_id": "wax_policy_loss",
		"player_id": "wax_a",
		"opponent_id": "wax_b",
		"mode_name": "CTF",
		"did_win": false,
		"player_rating": 1500.0,
		"opponent_rating": 1000.0
	})
	_assert_eq(int(loss_weaker.get("final_wax_delta", 0)), -2, "loss vs much weaker should subtract 2 Wax")
	var close_loss: Dictionary = WaxRewardPolicy.evaluate_match({
		"match_id": "wax_policy_close",
		"player_id": "wax_a",
		"opponent_id": "wax_b",
		"mode_name": "PROGRESSIVE",
		"did_win": false,
		"close_loss_qualified": true,
		"player_rating": 1000.0,
		"opponent_rating": 1125.0
	})
	_assert_eq(int(close_loss.get("final_wax_delta", 0)), 1, "close loss vs slightly stronger should award 1 Wax")
	var crucible: Dictionary = WaxRewardPolicy.evaluate_match({
		"match_id": "wax_policy_crucible",
		"player_id": "wax_a",
		"mode_name": "1V1",
		"did_win": true,
		"vs_ruleset": "CRUCIBLE"
	})
	_assert_eq(int(crucible.get("final_wax_delta", 0)), 0, "Crucible participation should not award Wax")
	_assert_eq(str(crucible.get("validity_status", "")), "blocked", "Crucible Wax should be blocked")

func _test_competitive_wax_ledger() -> void:
	var crucible_state: Node = get_root().get_node_or_null("CrucibleState")
	if crucible_state == null:
		_fail("CrucibleState missing")
		return
	if crucible_state.has_method("debug_reset_state"):
		crucible_state.call("debug_reset_state")
	crucible_state.call("intent_set_balance_millis", "wax_ledger_a", 10000)
	var award: Dictionary = crucible_state.call("intent_apply_competitive_wax_result", "wax_match", "wax_ledger_a", "wax_ledger_b", true, "1V1", {
		"event_id": "wax_match:wax_ledger_a",
		"player_rating": 1000.0,
		"opponent_rating": 1000.0
	}) as Dictionary
	_assert_true(bool(award.get("ok", false)), "competitive Wax award should succeed")
	_assert_eq(int(crucible_state.call("get_balance_millis", "wax_ledger_a")), 13000, "equal win should add 3 Wax")
	var dup: Dictionary = crucible_state.call("intent_apply_competitive_wax_result", "wax_match", "wax_ledger_a", "wax_ledger_b", true, "1V1", {
		"event_id": "wax_match:wax_ledger_a",
		"player_rating": 1000.0,
		"opponent_rating": 1000.0
	}) as Dictionary
	_assert_true(bool(dup.get("duplicate", false)), "duplicate Wax result should be ignored")
	_assert_eq(int(crucible_state.call("get_balance_millis", "wax_ledger_a")), 13000, "duplicate should not double-award Wax")

func _test_nectar_policy() -> void:
	var battle_pass_state: Node = get_root().get_node_or_null("BattlePassState")
	if battle_pass_state == null:
		_fail("BattlePassState missing")
		return
	if battle_pass_state.has_method("debug_reset_state"):
		battle_pass_state.call("debug_reset_state")
	var first_win: Dictionary = battle_pass_state.call("intent_record_pvp_completion", "1V1", false, 0, true, {
		"event_id": "economy_first_win",
		"player_id": "nectar_a",
		"day_key": "2026-06-27"
	}) as Dictionary
	_assert_eq(int(first_win.get("xp_awarded", 0)), 38, "classic first win should award 18+20 Nectar")
	var second_win: Dictionary = battle_pass_state.call("intent_record_pvp_completion", "1V1", false, 0, true, {
		"event_id": "economy_second_win",
		"player_id": "nectar_a",
		"day_key": "2026-06-27"
	}) as Dictionary
	_assert_eq(int(second_win.get("xp_awarded", 0)), 18, "second win same day should not repeat first-win Nectar")
	var crucible_block: Dictionary = battle_pass_state.call("intent_record_pvp_completion", "1V1", false, 0, true, {
		"event_id": "economy_crucible_nectar",
		"vs_ruleset": "CRUCIBLE"
	}) as Dictionary
	_assert_true(bool(crucible_block.get("suppressed", false)), "Crucible should suppress Nectar")

func _test_honey_simulator() -> void:
	var sim: Dictionary = HoneyEconomySimulator.simulate(90)
	_assert_true(bool(sim.get("ok", false)), "Honey simulator should return ok")
	var profiles: Array = sim.get("profiles", []) as Array
	_assert_true(profiles.size() >= 8, "Honey simulator should include required profiles")
	var hives: Dictionary = sim.get("hive_examples", {}) as Dictionary
	_assert_true(hives.has("mixed") and hives.has("free_only"), "Honey simulator should include hive examples")

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_fail(label)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	push_error("ECONOMY_LAYER_SMOKE: %s" % message)
	quit(1)
