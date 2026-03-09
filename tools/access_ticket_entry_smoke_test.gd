extends SceneTree

const PASS_STATE_PATH: String = "user://battle_pass_state.json"
const PROFILE_PATH: String = "user://profile.cfg"
const CONTEST_ENTRY_PATH: String = "user://contest_entries.json"

func _init() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PASS_STATE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CONTEST_ENTRY_PATH))

	var battle_pass_state: Node = get_root().get_node_or_null("BattlePassState")
	var contest_state: Node = get_root().get_node_or_null("ContestState")
	if battle_pass_state == null or contest_state == null:
		push_error("ACCESS_TICKET_SMOKE: required autoload missing")
		quit(1)
		return

	if battle_pass_state.has_method("debug_reset_state"):
		battle_pass_state.call("debug_reset_state")
	if contest_state.has_method("debug_reset_entries"):
		contest_state.call("debug_reset_entries")
	await process_frame

	var contest: ContestDef = contest_state.call("get_contest_by_scope", "WEEKLY") as ContestDef
	if contest == null:
		push_error("ACCESS_TICKET_SMOKE: weekly contest missing")
		quit(1)
		return
	contest.access_ticket_cost = 1
	contest.prize_rewards = [
		{"placement": 1, "reward_type": "honey", "quantity": 7},
		{"placements": [1], "reward_type": "cosmetic", "cosmetic_id": "smoke_ticket_crown", "quantity": 1},
		{"placement": 1, "reward_type": "analytics_credit", "package_id": "analytics_pack_10_match", "quantity": 1},
		{"placement": 1, "reward_type": "bundle_token", "bundle_id": "bundle_founders_pack_lite", "quantity": 1},
		{"placement": 1, "reward_type": "ad_free_days", "quantity": 3}
	]

	var preview_before: Dictionary = contest_state.call("preview_entry_requirements", contest.id) as Dictionary
	_assert_true(bool(preview_before.get("requires_access_ticket", false)), "contest should require an access ticket")
	_assert_true(not bool(preview_before.get("can_enter", true)), "entry should be blocked before earning a ticket")

	_assert_ok(battle_pass_state.call("intent_award_nectar_xp", "smoke_ticket_bootstrap", 500, {}) as Dictionary, "battle pass bootstrap xp")
	_assert_ok(battle_pass_state.call("intent_claim_reward", 10, "free") as Dictionary, "claim free level 10 ticket")
	_assert_eq(int(battle_pass_state.call("get_access_ticket_balance")), 1, "free level 10 claim should grant one ticket")

	var preview_after: Dictionary = contest_state.call("preview_entry_requirements", contest.id) as Dictionary
	_assert_true(bool(preview_after.get("can_enter", false)), "entry should open once a ticket is owned")

	var enter_result: Dictionary = contest_state.call("intent_enter_contest", contest.id, {"source": "access_ticket_smoke"}) as Dictionary
	_assert_ok(enter_result, "contest entry")
	_assert_true(bool(contest_state.call("is_entered", contest.id)), "contest should be marked entered")
	_assert_eq(int(battle_pass_state.call("get_access_ticket_balance")), 0, "entry should spend one ticket")

	var reenter_result: Dictionary = contest_state.call("intent_enter_contest", contest.id, {"source": "access_ticket_smoke_reenter"}) as Dictionary
	_assert_ok(reenter_result, "re-enter contest")
	_assert_true(bool(reenter_result.get("already_entered", false)), "re-enter should be idempotent")
	_assert_eq(int(battle_pass_state.call("get_access_ticket_balance")), 0, "re-enter must not spend another ticket")

	var prize_result: Dictionary = contest_state.call("intent_claim_contest_prizes", contest.id, 1, {"source": "access_ticket_smoke"}) as Dictionary
	_assert_ok(prize_result, "claim contest prizes")
	var snapshot: Dictionary = battle_pass_state.call("get_snapshot") as Dictionary
	var wallet: Dictionary = snapshot.get("wallet", {}) as Dictionary
	var inventory: Dictionary = snapshot.get("inventory", {}) as Dictionary
	var cosmetics: Dictionary = inventory.get("cosmetics", {}) as Dictionary
	var analytics_credits: Dictionary = inventory.get("analytics_credits", {}) as Dictionary
	var bundle_tokens: Dictionary = inventory.get("bundle_tokens", {}) as Dictionary
	_assert_eq(int(wallet.get("honey", 0)), 7, "contest prizes should grant honey")
	_assert_true(bool(cosmetics.get("smoke_ticket_crown", {}).get("owned", false)), "contest prizes should grant the cosmetic")
	_assert_eq(int(analytics_credits.get("analytics_pack_10_match", 0)), 1, "contest prizes should grant analytics credits")
	_assert_eq(int(bundle_tokens.get("bundle_founders_pack_lite", 0)), 1, "contest prizes should grant a bundle token")
	_assert_eq(int(inventory.get("ad_free_days", 0)), 3, "contest prizes should grant ad-free days")

	var duplicate_prize_result: Dictionary = contest_state.call("intent_claim_contest_prizes", contest.id, 1, {"source": "access_ticket_smoke_dup"}) as Dictionary
	_assert_ok(duplicate_prize_result, "duplicate prize claim")
	_assert_true(bool(duplicate_prize_result.get("already_claimed", false)), "duplicate prize claim should be idempotent")

	var refund_result: Dictionary = contest_state.call("intent_refund_contest_entry", contest.id, "smoke_refund") as Dictionary
	_assert_ok(refund_result, "refund contest entry")
	_assert_true(not bool(contest_state.call("is_entered", contest.id)), "refund should clear the contest entry")
	_assert_eq(int(battle_pass_state.call("get_access_ticket_balance")), 1, "refund should restore the spent ticket")

	print("ACCESS_TICKET_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	push_error("ACCESS_TICKET_SMOKE: %s failed -> %s" % [label, result])
	quit(1)

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	push_error("ACCESS_TICKET_SMOKE: %s (expected %d, got %d)" % [label, expected, actual])
	quit(1)

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("ACCESS_TICKET_SMOKE: %s" % label)
	quit(1)
