extends SceneTree

const HiveClanStateScript = preload("res://scripts/state/hive_clan_state.gd")
const SAVE_PATH := "user://hive_honey_proportional_spend_smoke.json"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	await process_frame

	var state: Node = HiveClanStateScript.new()
	state.set("save_path", SAVE_PATH)
	state.set("_allow_test_local_hive_economy", true)
	get_root().add_child(state)
	await process_frame

	var now_unix: int = int(Time.get_unix_time_from_system())
	state.set("_hives_by_id", {
		"h_honey": {
			"hive_id": "h_honey",
			"name": "Honey Hive",
			"created_at_unix": now_unix,
			"created_by_player_id": "p1",
			"members": {
				"p1": _member("p1", "Queen", "queen", now_unix, 1000),
				"p2": _member("p2", "Soldier", "soldier", now_unix, 3000),
				"p3": _member("p3", "Member", "member", now_unix, 6000)
			},
			"pinned_notice": {},
			"about_profile": {},
			"soldier_demotion_votes": {},
			"queen_removal_vote": {},
			"queen_removal_vote_started_at_unix": 0,
			"leadership_removal_votes": {},
			"soldier_promotion_votes": {},
			"tournament_entries": {},
			"tournament_wins": 0,
			"hive_championships": 0,
			"seasonal_best_finish": 0,
			"total_honey_spent": 0,
			"feed_entries": [],
			"total_honey_contributed": 0,
			"hive_honey_strength": 0
		}
	})
	state.call("_reindex_memberships")
	var hives: Dictionary = state.get("_hives_by_id") as Dictionary
	var hive: Dictionary = hives.get("h_honey", {}) as Dictionary
	state.call("_recompute_hive_metrics", hive)
	hives["h_honey"] = hive
	state.set("_hives_by_id", hives)

	var preview: Dictionary = state.call("preview_hive_honey_purchase", "h_honey", 2500) as Dictionary
	_assert_true(bool(preview.get("ok", false)), "preview should succeed")
	_assert_eq(int(preview.get("available_hive_honey", 0)), 10000, "preview should sum member balances")
	var preview_deductions: Array = preview.get("deductions", []) as Array
	_assert_eq(_deduction_for(preview_deductions, "p1"), 250, "p1 preview deduction")
	_assert_eq(_deduction_for(preview_deductions, "p2"), 750, "p2 preview deduction")
	_assert_eq(_deduction_for(preview_deductions, "p3"), 1500, "p3 preview deduction")

	var debit: Dictionary = state.call("intent_debit_hive_honey_proportional", "h_honey", 2500, "smoke_purchase", {}, "p1") as Dictionary
	_assert_true(bool(debit.get("ok", false)), "debit should succeed")
	var snapshot: Dictionary = state.call("get_hive_snapshot", "h_honey") as Dictionary
	_assert_eq(int(snapshot.get("hive_honey_strength", 0)), 7500, "spendable Hive Honey should be remaining member balances")
	_assert_eq(int(snapshot.get("total_honey_spent", 0)), 2500, "historical spent total should record cost")

	var members: Array = snapshot.get("members", []) as Array
	_assert_eq(int(_member_snapshot(members, "p1").get("honey_balance_snapshot", 0)), 750, "p1 balance after")
	_assert_eq(int(_member_snapshot(members, "p2").get("honey_balance_snapshot", 0)), 2250, "p2 balance after")
	_assert_eq(int(_member_snapshot(members, "p3").get("honey_balance_snapshot", 0)), 4500, "p3 balance after")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("HIVE_HONEY_PROPORTIONAL_SPEND_SMOKE: PASS")
	quit(0)

func _member(player_id: String, display_name: String, role: String, joined_at_unix: int, honey_balance: int) -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"role": role,
		"joined_at_unix": joined_at_unix,
		"last_seen_at_unix": joined_at_unix,
		"honey_contributed": honey_balance,
		"honey_balance_snapshot": honey_balance,
		"honey_spent": 0
	}

func _deduction_for(deductions: Array, player_id: String) -> int:
	for deduction_any in deductions:
		if typeof(deduction_any) != TYPE_DICTIONARY:
			continue
		var deduction: Dictionary = deduction_any as Dictionary
		if str(deduction.get("player_id", "")) == player_id:
			return int(deduction.get("deduction", 0))
	return -1

func _member_snapshot(members: Array, player_id: String) -> Dictionary:
	for member_any in members:
		if typeof(member_any) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_any as Dictionary
		if str(member.get("player_id", "")) == player_id:
			return member
	return {}

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("HIVE_HONEY_PROPORTIONAL_SPEND_SMOKE: %s" % label)
	quit(1)

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	push_error("HIVE_HONEY_PROPORTIONAL_SPEND_SMOKE: %s (expected %d, got %d)" % [label, expected, actual])
	quit(1)
