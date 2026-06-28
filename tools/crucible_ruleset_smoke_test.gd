extends SceneTree

class FakeSimRunner:
	extends Node
	signal match_ended(winner_id: int, reason: String)

const CrucibleRulesetPolicyScript = preload("res://scripts/state/crucible_ruleset_policy.gd")

const PLAYER_A: String = "crucible_a"
const PLAYER_B: String = "crucible_b"
const MATCH_ID: String = "crucible_smoke_match_001"
const NO_CONTEST_MATCH_ID: String = "crucible_smoke_no_contest_001"
const INVALID_SOURCE_MATCH_ID: String = "crucible_smoke_invalid_source_001"
const RUNTIME_MATCH_ID: String = "crucible_smoke_runtime_001"
const LIFECYCLE_MATCH_ID: String = "crucible_smoke_lifecycle_001"
const DESYNC_MATCH_ID: String = "crucible_smoke_desync_001"
const BUFF_CLASSIC: String = "buff_unit_speed_classic"

func _init() -> void:
	await process_frame

	var crucible_state: Node = get_root().get_node_or_null("CrucibleState")
	var honey_state: Node = get_root().get_node_or_null("HoneyProgressionState")
	var battle_pass_state: Node = get_root().get_node_or_null("BattlePassState")
	var rank_state: Node = get_root().get_node_or_null("RankState")
	var economy_state: Node = get_root().get_node_or_null("EconomyBuffState")
	if crucible_state == null or honey_state == null or battle_pass_state == null or rank_state == null or economy_state == null:
		_fail("required autoload missing")
		return

	if crucible_state.has_method("debug_reset_state"):
		crucible_state.call("debug_reset_state")
	if honey_state.has_method("debug_reset_state"):
		honey_state.call("debug_reset_state")
	if battle_pass_state.has_method("debug_reset_state"):
		battle_pass_state.call("debug_reset_state")
	await process_frame

	var no_wax_status: Dictionary = crucible_state.call("preview_entry_status", PLAYER_A, 0, false) as Dictionary
	_assert_code(no_wax_status, "no_wax", "zero Wax entry should route to Wax Melted")
	var capacity_status: Dictionary = crucible_state.call("preview_entry_status", PLAYER_A, 100, false) as Dictionary
	_assert_code(capacity_status, "capacity", "capacity block should be distinct from no Wax")

	# Stake math: Crucible always stakes exactly 1 Wax from each player and burns nothing.
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_A, 5000) as Dictionary, "seed A low balance")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_B, 50000) as Dictionary, "seed B high balance")
	var low_preview: Dictionary = crucible_state.call("preview_match", PLAYER_A, PLAYER_B) as Dictionary
	_assert_ok(low_preview, "low-vs-high preview")
	_assert_eq(int(low_preview.get("stake_each", 0)), 1000, "5 vs 50 Wax should stake 1 Wax")
	_assert_eq(int(low_preview.get("burn", 0)), 0, "Crucible burns no Wax")
	_assert_eq(int(low_preview.get("winner_payout", 0)), 2000, "1+1 Wax pot should pay 2 Wax")

	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_A, 50000) as Dictionary, "seed A 50 Wax")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_B, 50000) as Dictionary, "seed B 50 Wax")
	var equal_preview: Dictionary = crucible_state.call("preview_match", PLAYER_A, PLAYER_B) as Dictionary
	_assert_ok(equal_preview, "equal preview")
	_assert_eq(int(equal_preview.get("stake_each", 0)), 1000, "50 vs 50 Wax should stake 1 Wax")
	_assert_eq(int(equal_preview.get("burn", 0)), 0, "Crucible burns no Wax")
	_assert_eq(int(equal_preview.get("winner_payout", 0)), 2000, "1+1 Wax pot should pay 2 Wax")

	var escrow_result: Dictionary = crucible_state.call("intent_open_escrow", MATCH_ID, PLAYER_A, PLAYER_B, {}) as Dictionary
	_assert_ok(escrow_result, "open escrow")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_A)), 49000, "A escrow debit")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_B)), 49000, "B escrow debit")
	var settle_result: Dictionary = crucible_state.call(
		"intent_settle_match",
		MATCH_ID,
		PLAYER_A,
		CrucibleRulesetPolicyScript.RESULT_SOURCE_LOCAL_DEV_SIM,
		"smoke_win",
		{}
	) as Dictionary
	_assert_ok(settle_result, "settle winner")
	var settlement: Dictionary = settle_result.get("settlement", {}) as Dictionary
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_A)), 51000, "winner receives 2-Wax payout")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_B)), 49000, "loser remains debited")
	_assert_str_eq(str(settlement.get("ruleset", "")), "CRUCIBLE", "audit ruleset")
	_assert_str_eq(str(settlement.get("settlement_status", "")), "SETTLED", "settlement status")
	_assert_true(settlement.has("match_id") and settlement.has("config_version") and settlement.has("result_source"), "audit fields present")

	var duplicate_settle: Dictionary = crucible_state.call(
		"intent_settle_match",
		MATCH_ID,
		PLAYER_A,
		CrucibleRulesetPolicyScript.RESULT_SOURCE_LOCAL_DEV_SIM,
		"smoke_duplicate",
		{}
	) as Dictionary
	_assert_ok(duplicate_settle, "duplicate settlement")
	_assert_true(bool(duplicate_settle.get("idempotent", false)), "duplicate settlement should be idempotent")

	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_A, 10000) as Dictionary, "seed A no contest")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_B, 10000) as Dictionary, "seed B no contest")
	_assert_ok(crucible_state.call("intent_open_escrow", NO_CONTEST_MATCH_ID, PLAYER_A, PLAYER_B, {}) as Dictionary, "open no contest escrow")
	var no_contest: Dictionary = crucible_state.call(
		"intent_settle_match",
		NO_CONTEST_MATCH_ID,
		"",
		CrucibleRulesetPolicyScript.RESULT_SOURCE_LOCAL_DEV_SIM,
		"draw",
		{}
	) as Dictionary
	_assert_ok(no_contest, "no contest settlement")
	var no_contest_record: Dictionary = no_contest.get("settlement", {}) as Dictionary
	_assert_str_eq(str(no_contest_record.get("settlement_status", "")), "NO_CONTEST", "no winner should no-contest")
	_assert_eq(int(no_contest_record.get("burn", -1)), 0, "no contest burns nothing")
	_assert_eq(int(no_contest_record.get("winner_payout", -1)), 0, "no contest pays nothing")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_A)), 10000, "A refunded on no contest")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_B)), 10000, "B refunded on no contest")

	_assert_ok(crucible_state.call("intent_open_escrow", INVALID_SOURCE_MATCH_ID, PLAYER_A, PLAYER_B, {}) as Dictionary, "open invalid-source escrow")
	var invalid_source: Dictionary = crucible_state.call(
		"intent_settle_match",
		INVALID_SOURCE_MATCH_ID,
		PLAYER_A,
		CrucibleRulesetPolicyScript.RESULT_SOURCE_UI,
		"ui_attempt",
		{}
	) as Dictionary
	_assert_ok(invalid_source, "invalid source resolves no-contest")
	var invalid_record: Dictionary = invalid_source.get("settlement", {}) as Dictionary
	_assert_str_eq(str(invalid_record.get("settlement_status", "")), "NO_CONTEST", "UI result source must not settle")

	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_A, 20000) as Dictionary, "seed A lifecycle")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_B, 20000) as Dictionary, "seed B lifecycle")
	_assert_ok(crucible_state.call("intent_open_escrow", LIFECYCLE_MATCH_ID, PLAYER_A, PLAYER_B, {}) as Dictionary, "open lifecycle escrow")
	var forfeit_result: Dictionary = crucible_state.call("intent_record_lifecycle", LIFECYCLE_MATCH_ID, "voluntary_quit", PLAYER_B, {}) as Dictionary
	_assert_ok(forfeit_result, "voluntary quit lifecycle")
	_assert_str_eq(str((forfeit_result.get("settlement", {}) as Dictionary).get("winner_id", "")), PLAYER_A, "voluntary quit awards opponent")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_A, 12000) as Dictionary, "seed A desync")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_B, 12000) as Dictionary, "seed B desync")
	_assert_ok(crucible_state.call("intent_open_escrow", DESYNC_MATCH_ID, PLAYER_A, PLAYER_B, {}) as Dictionary, "open desync escrow")
	var desync_result: Dictionary = crucible_state.call("intent_record_lifecycle", DESYNC_MATCH_ID, "desync", "", {}) as Dictionary
	_assert_ok(desync_result, "desync lifecycle")
	_assert_str_eq(str((desync_result.get("settlement", {}) as Dictionary).get("settlement_status", "")), "NO_CONTEST", "desync refunds no contest")

	var balance_before_earn: int = int(crucible_state.call("get_balance_millis", PLAYER_A))
	var earn_result: Dictionary = crucible_state.call("intent_award_earn_path", PLAYER_A, "STANDARD_PVP_WIN", {"match_id": "earn_smoke"}) as Dictionary
	_assert_ok(earn_result, "standard pvp earn")
	_assert_true(bool(earn_result.get("suppressed", false)), "Crucible has no direct Wax earn path")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_A)), balance_before_earn, "standard pvp win does not earn Crucible Wax")
	var tournament_earn: Dictionary = crucible_state.call("intent_award_earn_path", PLAYER_A, "TOURNAMENT_PLACEMENT", {"placement": 2}) as Dictionary
	_assert_ok(tournament_earn, "tournament earn")
	_assert_true(bool(tournament_earn.get("suppressed", false)), "tournament earn path is suppressed")
	_assert_eq(int(tournament_earn.get("amount_millis", 0)), 0, "Crucible tournaments do not mint Wax")

	# Direct rewards and normal rank Wax are suppressed when metadata declares Crucible.
	var direct_honey: Dictionary = honey_state.call("intent_record_pvp_completion", "1V1", false, 0, true, {"ruleset": "CRUCIBLE"}) as Dictionary
	_assert_true(bool(direct_honey.get("suppressed", false)), "direct honey award suppressed")
	var direct_nectar: Dictionary = battle_pass_state.call("intent_record_pvp_completion", "1V1", false, 0, true, {"ruleset": "CRUCIBLE"}) as Dictionary
	_assert_true(bool(direct_nectar.get("suppressed", false)), "direct nectar award suppressed")
	var rank_direct: Dictionary = rank_state.call("intent_record_match_result", PLAYER_A, PLAYER_B, true, "CRUCIBLE", {"ruleset": "CRUCIBLE"}) as Dictionary
	_assert_true(bool(rank_direct.get("suppressed", false)), "normal rank wax suppressed")

	# Saved loadout cannot activate when the match tree is Crucible.
	_assert_ok(economy_state.call("intent_set_mode", "STANDARD") as Dictionary, "standard economy mode")
	_assert_ok(economy_state.call("intent_set_wallet", PLAYER_A, {"nectar": 200, "honey": 0, "wax": 0, "usd": 0}) as Dictionary, "seed economy wallet")
	_assert_ok(economy_state.call("intent_equip_buff", PLAYER_A, 0, BUFF_CLASSIC) as Dictionary, "saved loadout exists")
	CrucibleRulesetPolicyScript.apply_crucible_tree_meta(self)
	var blocked_activate: Dictionary = economy_state.call("intent_activate_buff", PLAYER_A, 0) as Dictionary
	_assert_code(blocked_activate, "crucible_buffs_disabled", "Crucible blocks saved loadout activation")
	CrucibleRulesetPolicyScript.clear_ruleset_tree_meta(self)
	_assert_ok(economy_state.call("intent_set_mode", "CRUCIBLE") as Dictionary, "crucible economy mode")
	var crucible_snap: Dictionary = economy_state.call("get_player_snapshot", PLAYER_A) as Dictionary
	_assert_true(not bool(crucible_snap.get("loadout_ui_enabled", true)), "Crucible hides loadout UI")
	_assert_eq((crucible_snap.get("entries", []) as Array).size(), 0, "Crucible strips loadout entries")

	# Runtime listeners suppress Honey/Nectar and settle through CrucibleState only.
	if honey_state.has_method("debug_reset_state"):
		honey_state.call("debug_reset_state")
	if battle_pass_state.has_method("debug_reset_state"):
		battle_pass_state.call("debug_reset_state")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_A, 50000) as Dictionary, "runtime seed A")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_B, 50000) as Dictionary, "runtime seed B")
	_assert_ok(crucible_state.call("intent_open_escrow", RUNTIME_MATCH_ID, PLAYER_A, PLAYER_B, {}) as Dictionary, "runtime escrow")
	set_meta("vs_mode", "1V1")
	set_meta("vs_ruleset", "CRUCIBLE")
	set_meta("vs_crucible", true)
	set_meta("vs_sync_start", true)
	set_meta("vs_free_roll", true)
	set_meta("crucible_match_id", RUNTIME_MATCH_ID)
	set_meta("vs_assigned_players", [
		{"uid": PLAYER_A, "seat": 1},
		{"uid": PLAYER_B, "seat": 2}
	])
	var runner := FakeSimRunner.new()
	runner.name = "SimRunner"
	get_root().add_child(runner)
	await process_frame
	runner.emit_signal("match_ended", 1, "runtime_win")
	await process_frame
	var honey_snapshot: Dictionary = honey_state.call("get_snapshot") as Dictionary
	var bp_snapshot: Dictionary = battle_pass_state.call("get_snapshot") as Dictionary
	var crucible_snapshot: Dictionary = crucible_state.call("get_snapshot") as Dictionary
	var settlements: Dictionary = crucible_snapshot.get("settlements_by_match_id", {}) as Dictionary
	_assert_eq(int(honey_snapshot.get("total_honey_centi_awarded", 0)), 0, "runtime Crucible awards no Honey")
	_assert_eq(int(bp_snapshot.get("battle_pass_xp", 0)), 0, "runtime Crucible awards no Nectar")
	_assert_true(settlements.has(RUNTIME_MATCH_ID), "runtime Crucible settles via CrucibleState")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_A)), 51000, "runtime winner payout")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_B)), 49000, "runtime loser debit")

	print("CRUCIBLE_RULESET_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	_fail("%s failed -> %s" % [label, result])

func _assert_code(result: Dictionary, code: String, label: String) -> void:
	if bool(result.get("ok", false)):
		_fail("%s expected code %s but got ok" % [label, code])
		return
	if str(result.get("code", "")) != code:
		_fail("%s expected code %s but got %s" % [label, code, str(result.get("code", ""))])

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %d got %d" % [label, expected, actual])

func _assert_str_eq(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %s got %s" % [label, expected, actual])

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_fail(label)

func _fail(message: String) -> void:
	push_error("CRUCIBLE_RULESET_SMOKE: %s" % message)
	quit(1)
