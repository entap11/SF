extends SceneTree

const WaxRewardPolicy = preload("res://scripts/state/wax_reward_policy.gd")
const HoneyEconomySimulator = preload("res://scripts/state/honey_economy_simulator.gd")
const WaxEconomySimulator = preload("res://scripts/state/wax_economy_simulator.gd")
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
	_test_wax_simulator()
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
		"close_loss_margin_ratio": 0.04,
		"player_rating": 1000.0,
		"opponent_rating": 1125.0
	})
	_assert_eq(int(close_loss.get("final_wax_delta", 0)), 1, "close loss vs slightly stronger should award 1 Wax")
	_assert_true(bool(close_loss.get("close_loss_qualified", false)), "metric-backed close loss should qualify")
	var close_loss_missing_metric: Dictionary = WaxRewardPolicy.evaluate_match({
		"match_id": "wax_policy_close_missing",
		"player_id": "wax_a",
		"opponent_id": "wax_b",
		"mode_name": "PROGRESSIVE",
		"did_win": false,
		"close_loss_qualified": true,
		"player_rating": 1000.0,
		"opponent_rating": 1125.0
	})
	_assert_eq(int(close_loss_missing_metric.get("final_wax_delta", 0)), 0, "close loss without metric should not award Wax")
	_assert_eq(str(close_loss_missing_metric.get("close_loss_reason", "")), "missing_close_loss_metric", "missing close-loss metric should be auditable")
	var close_loss_weaker: Dictionary = WaxRewardPolicy.evaluate_match({
		"match_id": "wax_policy_close_weaker",
		"player_id": "wax_a",
		"opponent_id": "wax_b",
		"mode_name": "PROGRESSIVE",
		"did_win": false,
		"close_loss_score": 1.0,
		"player_rating": 1500.0,
		"opponent_rating": 1000.0
	})
	_assert_eq(int(close_loss_weaker.get("final_wax_delta", 0)), -2, "loss to weaker opponent should never receive close-loss Wax")
	var too_short: Dictionary = WaxRewardPolicy.evaluate_match({
		"match_id": "wax_policy_short",
		"player_id": "wax_a",
		"opponent_id": "wax_b",
		"mode_name": "1V1",
		"did_win": true,
		"duration_sec": 5
	})
	_assert_eq(str(too_short.get("validity_status", "")), "blocked", "too-short match should be blocked")
	_assert_eq(str(too_short.get("anti_harvest_reason_if_blocked", "")), "match_too_short", "too-short block should be auditable")
	var held_review: Dictionary = WaxRewardPolicy.evaluate_match({
		"match_id": "wax_policy_held",
		"player_id": "wax_a",
		"opponent_id": "wax_b",
		"mode_name": "1V1",
		"did_win": true,
		"suspicious_win_trading": true
	})
	_assert_eq(str(held_review.get("validity_status", "")), "held_review", "suspicious award should be held for review")
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
	_assert_true(bool(award.get("suppressed", false)), "competitive Wax ledger path should be suppressed")
	_assert_eq(int(crucible_state.call("get_balance_millis", "wax_ledger_a")), 10000, "suppressed competitive award should not change Wax")
	var dup: Dictionary = crucible_state.call("intent_apply_competitive_wax_result", "wax_match", "wax_ledger_a", "wax_ledger_b", true, "1V1", {
		"event_id": "wax_match:wax_ledger_a",
		"player_rating": 1000.0,
		"opponent_rating": 1000.0
	}) as Dictionary
	_assert_true(bool(dup.get("suppressed", false)), "duplicate competitive Wax result should remain suppressed")
	_assert_eq(int(crucible_state.call("get_balance_millis", "wax_ledger_a")), 10000, "duplicate should not award Wax")
	var held: Dictionary = crucible_state.call("intent_apply_competitive_wax_result", "wax_match_held", "wax_ledger_a", "wax_ledger_b", true, "1V1", {
		"event_id": "wax_match_held:wax_ledger_a",
		"player_rating": 1000.0,
		"opponent_rating": 1000.0,
		"suspicious_win_trading": true
	}) as Dictionary
	_assert_true(bool(held.get("suppressed", false)), "suspicious competitive Wax should also be suppressed")
	_assert_eq(int(crucible_state.call("get_balance_millis", "wax_ledger_a")), 10000, "suppressed review should not change Wax balance")
	var summary: Dictionary = crucible_state.call("get_player_wax_summary", "wax_ledger_a", 5) as Dictionary
	_assert_true(bool(summary.get("ok", false)), "Wax summary should return ok")
	_assert_eq(int(summary.get("balance_millis", 0)), 10000, "Wax summary should expose current balance")
	_assert_eq(int(summary.get("held_review_count", 0)), 0, "suppressed awards are not held reviews")
	var activity: Array = summary.get("recent_activity", []) as Array
	_assert_eq(activity.size(), 0, "suppressed awards should not appear as activity")
	var audit: Dictionary = crucible_state.call("get_wax_audit_snapshot", {"player_id": "wax_ledger_a", "validity_status": "held_review"}) as Dictionary
	_assert_true(bool(audit.get("ok", false)), "Wax audit snapshot should return ok")
	_assert_eq(int(audit.get("held_review_count", 0)), 0, "Wax audit snapshot should not invent held reviews")

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

func _test_wax_simulator() -> void:
	var sim: Dictionary = WaxEconomySimulator.simulate(90)
	_assert_true(bool(sim.get("ok", false)), "Wax simulator should return ok")
	var profiles: Array = sim.get("profiles", []) as Array
	_assert_true(profiles.size() >= 8, "Wax simulator should include required profiles")
	_assert_true(not bool(sim.get("farmer_beats_average", true)), "Wax farming should not beat average play")

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
