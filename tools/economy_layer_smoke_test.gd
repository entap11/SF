extends SceneTree

const WaxRewardPolicy = preload("res://scripts/state/wax_reward_policy.gd")
const HoneyEconomySimulator = preload("res://scripts/state/honey_economy_simulator.gd")
const WaxEconomySimulator = preload("res://scripts/state/wax_economy_simulator.gd")
const PlatformEconomyEventSchema = preload("res://scripts/state/platform_economy_event_schema.gd")
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
	_test_platform_economy_event_schema()
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
	var duplicate: Dictionary = battle_pass_state.call("intent_record_pvp_completion", "1V1", false, 0, true, {
		"event_id": "economy_second_win",
		"player_id": "nectar_a",
		"day_key": "2026-06-27"
	}) as Dictionary
	_assert_eq(str(duplicate.get("reason", "")), "event_already_awarded", "duplicate Nectar event should be ignored")
	var no_contest: Dictionary = battle_pass_state.call("intent_record_pvp_completion", "1V1", false, 0, true, {
		"event_id": "economy_no_contest",
		"no_contest": true
	}) as Dictionary
	_assert_true(bool(no_contest.get("suppressed", false)), "no-contest match should suppress Nectar")
	var too_short_nectar: Dictionary = battle_pass_state.call("intent_record_pvp_completion", "1V1", false, 0, true, {
		"event_id": "economy_too_short_nectar",
		"duration_sec": 5
	}) as Dictionary
	_assert_true(bool(too_short_nectar.get("suppressed", false)), "too-short match should suppress Nectar")
	_assert_eq(str(too_short_nectar.get("reason", "")), "match_too_short", "too-short Nectar suppression should be auditable")
	var repeated_opponent: Dictionary = battle_pass_state.call("intent_record_pvp_completion", "1V1", false, 0, false, {
		"event_id": "economy_repeated_opponent_nectar",
		"repeated_opponent_count": 5
	}) as Dictionary
	_assert_eq(int(repeated_opponent.get("xp_awarded", 0)), 7, "repeated opponent should diminish completion Nectar")
	var repeated_breakdown: Dictionary = repeated_opponent.get("nectar_breakdown", {}) as Dictionary
	_assert_eq(str(repeated_breakdown.get("validity_status", "")), "diminished", "repeated opponent should mark Nectar as diminished")
	var daily_snapshot: Dictionary = battle_pass_state.call("get_snapshot") as Dictionary
	_assert_eq(_daily_progress(daily_snapshot, "daily_complete_match"), 1, "daily complete counter should progress after a match")
	_assert_true(_daily_ready(daily_snapshot, "daily_complete_match"), "daily complete challenge should be ready to claim")
	_assert_true(not _daily_claimed(daily_snapshot, "daily_complete_match"), "daily challenge should not auto-claim")
	var daily_claim: Dictionary = battle_pass_state.call("intent_claim_daily_challenge", "daily_complete_match") as Dictionary
	_assert_true(bool(daily_claim.get("ok", false)), "daily complete challenge claim should succeed")
	_assert_eq(int(daily_claim.get("xp_awarded", 0)), 40, "daily complete challenge should award configured Nectar")
	var daily_claim_again: Dictionary = battle_pass_state.call("intent_claim_daily_challenge", "daily_complete_match") as Dictionary
	_assert_eq(str(daily_claim_again.get("reason", "")), "challenge_already_claimed", "daily challenge should not double-claim")

	battle_pass_state.call("debug_reset_state")
	var money_loss: Dictionary = battle_pass_state.call("intent_record_pvp_completion", "1V1", true, 3, false, {
		"event_id": "money_loss"
	}) as Dictionary
	_assert_eq(int(money_loss.get("xp_awarded", 0)), 12, "money loss should award modest completion Nectar")
	var money_win: Dictionary = battle_pass_state.call("intent_record_pvp_completion", "1V1", true, 3, true, {
		"event_id": "money_win",
		"player_id": "nectar_money",
		"day_key": "2026-06-27"
	}) as Dictionary
	_assert_eq(int(money_win.get("xp_awarded", 0)), 42, "money first win should award 12+10+20 Nectar")
	var async_loss: Dictionary = battle_pass_state.call("intent_record_async_completion", "STAGE_RACE", 3, false, {
		"event_id": "async_loss"
	}) as Dictionary
	_assert_eq(int(async_loss.get("xp_awarded", 0)), 8, "free async loss should award 8 Nectar")
	var async_win: Dictionary = battle_pass_state.call("intent_record_async_completion", "STAGE_RACE", 5, true, {
		"event_id": "async_win",
		"did_win": true
	}) as Dictionary
	_assert_eq(int(async_win.get("xp_awarded", 0)), 18, "money async win should award 10+8 Nectar")
	var tournament_win: Dictionary = battle_pass_state.call("intent_record_tournament_match_result", true, {
		"event_id": "tournament_win"
	}) as Dictionary
	_assert_eq(int(tournament_win.get("xp_awarded", 0)), 22, "tournament match win should award 12+10 Nectar")
	var tournament_champion: Dictionary = battle_pass_state.call("intent_record_tournament_placement", 1, {
		"event_id": "tournament_champion"
	}) as Dictionary
	_assert_eq(int(tournament_champion.get("xp_awarded", 0)), 75, "tournament champion should award 75 Nectar")

	battle_pass_state.call("debug_reset_state")
	for i in range(10):
		var win_result: Dictionary = battle_pass_state.call("intent_record_pvp_completion", "CTF", false, 0, true, {
			"event_id": "weekly_standard_win_%d" % i,
			"player_id": "nectar_weekly",
			"day_key": "2026-06-27"
		}) as Dictionary
		_assert_true(bool(win_result.get("ok", false)), "weekly standard win should award Nectar")
	var weekly_snapshot: Dictionary = battle_pass_state.call("get_snapshot") as Dictionary
	_assert_eq(int(weekly_snapshot.get("battle_pass_xp", 0)), 500, "ten standard wins should include first win and weekly win challenge Nectar")
	_assert_eq(_weekly_progress(weekly_snapshot, "weekly_win_standard_pvp"), 10, "weekly standard win counter should reach target")
	_assert_true(_weekly_claimed(weekly_snapshot, "weekly_win_standard_pvp"), "weekly standard win reward should auto-claim once complete")

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

func _test_platform_economy_event_schema() -> void:
	var event: Dictionary = PlatformEconomyEventSchema.build_award_event(
		"honey",
		"centi_honey",
		"award",
		"platform_schema_smoke",
		"player_platform_1",
		400,
		1200,
		"async_completion",
		{
			"mode_id": "STAGE_RACE",
			"call_sign": "VisibleName",
			"email": "player@example.com",
			"nested": {
				"payment": "should_not_export",
				"safe_flag": true
			}
		}
	)
	_assert_eq(str(event.get("platform_namespace", "")), "ENTaP", "platform schema should identify ENTaP namespace")
	_assert_eq(str(event.get("producer_game", "")), "swarmfront", "platform schema should identify Swarmfront producer")
	_assert_eq(str(event.get("idempotency_key", "")), "swarmfront:honey:award:platform_schema_smoke", "platform schema should produce stable idempotency key")
	var player_ref: Dictionary = event.get("player_ref", {}) as Dictionary
	_assert_eq(str(player_ref.get("kind", "")), "platform_player_id", "platform schema should use platform player reference")
	var metadata: Dictionary = event.get("metadata", {}) as Dictionary
	_assert_true(not metadata.has("call_sign"), "platform metadata should omit public identity")
	_assert_true(not metadata.has("email"), "platform metadata should omit private identity")
	var nested: Dictionary = metadata.get("nested", {}) as Dictionary
	_assert_true(not nested.has("payment"), "platform metadata should omit financial identity")
	_assert_true(bool(nested.get("safe_flag", false)), "platform metadata should preserve safe gameplay facts")

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

func _weekly_progress(snapshot: Dictionary, challenge_id: String) -> int:
	for row_any in snapshot.get("weekly_challenges", []) as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("id", "")) == challenge_id:
			return int(row.get("progress", 0))
	return 0

func _weekly_claimed(snapshot: Dictionary, challenge_id: String) -> bool:
	for row_any in snapshot.get("weekly_challenges", []) as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("id", "")) == challenge_id:
			return bool(row.get("claimed", false))
	return false

func _daily_progress(snapshot: Dictionary, challenge_id: String) -> int:
	for row_any in snapshot.get("daily_challenges", []) as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("id", "")) == challenge_id:
			return int(row.get("progress", 0))
	return 0

func _daily_ready(snapshot: Dictionary, challenge_id: String) -> bool:
	for row_any in snapshot.get("daily_challenges", []) as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("id", "")) == challenge_id:
			return bool(row.get("ready_to_claim", false))
	return false

func _daily_claimed(snapshot: Dictionary, challenge_id: String) -> bool:
	for row_any in snapshot.get("daily_challenges", []) as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("id", "")) == challenge_id:
			return bool(row.get("claimed", false))
	return false
