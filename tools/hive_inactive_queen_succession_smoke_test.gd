extends SceneTree

const HiveClanStateScript = preload("res://scripts/state/hive_clan_state.gd")
const SAVE_PATH := "user://hive_inactive_queen_succession_smoke.json"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	await process_frame

	var state: Node = HiveClanStateScript.new()
	state.set("save_path", SAVE_PATH)
	get_root().add_child(state)
	await process_frame

	var now_unix: int = int(Time.get_unix_time_from_system())
	_test_senior_active_soldier_succeeds(state, now_unix)
	_test_active_queen_blocks_claim(state, now_unix)
	_test_active_member_fallback_when_soldiers_inactive(state, now_unix)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("HIVE_INACTIVE_QUEEN_SUCCESSION_SMOKE: PASS")
	quit(0)

func _test_senior_active_soldier_succeeds(state: Node, now_unix: int) -> void:
	var hive_id := "h_inactive_soldier"
	var hives: Dictionary = {
		hive_id: _hive(hive_id, {
			"q1": _member("q1", "Old Queen", "queen", now_unix - 2000000, now_unix - (13 * 7 * 24 * 60 * 60), 1000),
			"s_old": _member("s_old", "Senior Soldier", "soldier", now_unix - 1000000, now_unix - 60, 800),
			"s_new": _member("s_new", "New Soldier", "soldier", now_unix - 500000, now_unix - 60, 400),
			"m1": _member("m1", "Member", "member", now_unix - 400000, now_unix - 60, 1200)
		})
	}
	state.set("_hives_by_id", hives)
	state.call("_reindex_memberships")
	var result: Dictionary = state.call("intent_claim_inactive_queen_succession", hive_id, "s_new") as Dictionary
	_assert_true(bool(result.get("ok", false)), "inactive queen claim should pass", result)
	_assert_eq(str(result.get("new_queen_player_id", "")), "s_old", "senior active soldier should become queen")
	var hive: Dictionary = state.call("get_hive_snapshot", hive_id) as Dictionary
	_assert_eq(_role_for(hive, "s_old"), "queen", "senior soldier should now be queen")
	_assert_eq(_role_for(hive, "q1"), "member", "inactive queen should become member")

func _test_active_queen_blocks_claim(state: Node, now_unix: int) -> void:
	var hive_id := "h_active_queen"
	state.set("_hives_by_id", {
		hive_id: _hive(hive_id, {
			"q2": _member("q2", "Active Queen", "queen", now_unix - 2000000, now_unix - 60, 1000),
			"s2": _member("s2", "Soldier", "soldier", now_unix - 1000000, now_unix - 60, 800)
		})
	})
	state.call("_reindex_memberships")
	var result: Dictionary = state.call("intent_claim_inactive_queen_succession", hive_id, "s2") as Dictionary
	_assert_true(not bool(result.get("ok", false)) and str(result.get("reason", "")) == "queen_still_active", "active queen should block succession", result)

func _test_active_member_fallback_when_soldiers_inactive(state: Node, now_unix: int) -> void:
	var hive_id := "h_member_fallback"
	state.set("_hives_by_id", {
		hive_id: _hive(hive_id, {
			"q3": _member("q3", "Old Queen", "queen", now_unix - 2000000, now_unix - (13 * 7 * 24 * 60 * 60), 1000),
			"s_inactive": _member("s_inactive", "Inactive Soldier", "soldier", now_unix - 1000000, now_unix - (8 * 24 * 60 * 60), 5000),
			"m_low": _member("m_low", "Low Member", "member", now_unix - 900000, now_unix - 60, 100),
			"m_high": _member("m_high", "High Member", "member", now_unix - 800000, now_unix - 60, 900)
		})
	})
	state.call("_reindex_memberships")
	var result: Dictionary = state.call("intent_claim_inactive_queen_succession", hive_id, "m_low") as Dictionary
	_assert_true(bool(result.get("ok", false)), "active member fallback claim should pass", result)
	_assert_eq(str(result.get("new_queen_player_id", "")), "m_high", "highest-contribution active member should become queen when soldiers are inactive")
	var hive: Dictionary = state.call("get_hive_snapshot", hive_id) as Dictionary
	_assert_eq(_role_for(hive, "m_high"), "queen", "fallback member should now be queen")
	_assert_eq(_role_for(hive, "s_inactive"), "soldier", "inactive soldier should keep Soldier role but not receive Queen")

func _hive(hive_id: String, members: Dictionary) -> Dictionary:
	return {
		"hive_id": hive_id,
		"name": "Succession Smoke",
		"created_at_unix": int(Time.get_unix_time_from_system()) - 3000000,
		"created_by_player_id": "q",
		"members": members,
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
		"award_records": [],
		"total_honey_spent": 0,
		"feed_entries": [],
		"total_honey_contributed": 0,
		"hive_honey_strength": 0
	}

func _member(player_id: String, display_name: String, role: String, joined_at_unix: int, last_seen_at_unix: int, honey: int) -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"role": role,
		"joined_at_unix": joined_at_unix,
		"last_seen_at_unix": last_seen_at_unix,
		"honey_contributed": honey,
		"last_honey_reason": "",
		"last_honey_at_unix": 0
	}

func _role_for(hive: Dictionary, player_id: String) -> String:
	for member_any in hive.get("members", []) as Array:
		if typeof(member_any) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_any as Dictionary
		if str(member.get("player_id", "")) == player_id:
			return str(member.get("role", ""))
	return ""

func _assert_true(value: bool, label: String, details: Variant = null) -> void:
	if value:
		return
	if details == null:
		push_error("HIVE_INACTIVE_QUEEN_SUCCESSION_SMOKE: %s" % label)
	else:
		push_error("HIVE_INACTIVE_QUEEN_SUCCESSION_SMOKE: %s :: %s" % [label, str(details)])
	quit(1)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	push_error("HIVE_INACTIVE_QUEEN_SUCCESSION_SMOKE: %s (expected %s, got %s)" % [label, expected, actual])
	quit(1)
