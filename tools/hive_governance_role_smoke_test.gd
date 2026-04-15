extends SceneTree

const HiveClanStateScript = preload("res://scripts/state/hive_clan_state.gd")
const SAVE_PATH := "user://hive_governance_role_smoke.json"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	await process_frame

	var state: Node = HiveClanStateScript.new()
	state.set("save_path", SAVE_PATH)
	get_root().add_child(state)
	await process_frame

	var now_unix: int = int(Time.get_unix_time_from_system())
	var hive_id := "h_smoke"
	var members := {
		"p1": _member("p1", "Queen", "queen", now_unix - 5000, 1200),
		"p2": _member("p2", "Soldier One", "soldier", now_unix - 4000, 900),
		"p3": _member("p3", "Soldier Two", "soldier", now_unix - 3000, 800),
		"p4": _member("p4", "Soldier Three", "soldier", now_unix - 2000, 700),
		"p5": _member("p5", "Member Five", "member", now_unix - 1000, 600)
	}
	state.set("_hives_by_id", {
		hive_id: {
			"hive_id": hive_id,
			"name": "Smoke Hive",
			"created_at_unix": now_unix - 6000,
			"created_by_player_id": "p1",
				"members": members,
				"pinned_notice": {},
				"about_profile": {},
				"soldier_demotion_votes": {},
			"queen_removal_vote": {},
			"queen_removal_vote_started_at_unix": 0,
			"leadership_removal_votes": {},
			"soldier_promotion_votes": {},
			"tournament_wins": 0,
			"hive_championships": 0,
			"seasonal_best_finish": 0,
			"total_honey_spent": 0,
			"feed_entries": [],
			"total_honey_contributed": 3400,
			"hive_honey_strength": 3400
			}
		})

	var about_result: Dictionary = state.call("intent_set_hive_about", hive_id, _repeat_text("a", 350), "p1") as Dictionary
	_assert_true(bool(about_result.get("ok", false)), "queen should publish hive profile")
	var about_hive: Dictionary = about_result.get("hive", {}) as Dictionary
	var about_profile: Dictionary = about_hive.get("about_profile", {}) as Dictionary
	_assert_eq(str(about_profile.get("message", "")).length(), 300, "hive profile should be capped at 300 characters")
	var about_cooldown: Dictionary = state.call("intent_set_hive_about", hive_id, "Updated profile", "p1") as Dictionary
	_assert_true(not bool(about_cooldown.get("ok", false)) and str(about_cooldown.get("reason", "")) == "update_cooldown", "hive profile should enforce daily edit cooldown")

	var demote_start: Dictionary = state.call("intent_vote_demote_soldier", hive_id, "p2", "p1") as Dictionary
	_assert_true(bool(demote_start.get("ok", false)) and not bool(demote_start.get("demoted", false)), "queen vote should start soldier demotion")
	var demote_finish: Dictionary = state.call("intent_vote_demote_soldier", hive_id, "p2", "p3") as Dictionary
	_assert_true(bool(demote_finish.get("ok", false)) and bool(demote_finish.get("demoted", false)), "supporting soldier vote should demote soldier")

	var promote_p5: Dictionary = state.call("intent_set_soldier", hive_id, "p5", true, "p1") as Dictionary
	_assert_true(bool(promote_p5.get("ok", false)), "queen should fill open soldier post")

	for voter_id in ["p3", "p4", "p5"]:
		var vote: Dictionary = state.call("intent_vote_remove_queen", hive_id, voter_id) as Dictionary
		_assert_true(bool(vote.get("ok", false)), "soldier should cast queen removal vote")
	var hive: Dictionary = state.call("get_hive_snapshot", hive_id) as Dictionary
	_assert_eq(_role_for(hive, "p3"), "queen", "senior soldier should auto-promote after queen removal")

	var application: Dictionary = state.call("intent_apply_for_soldier", hive_id, "p2") as Dictionary
	_assert_true(bool(application.get("ok", false)), "member should apply for open soldier post")

	var bundles: Array = state.call("get_invite_offer_bundles") as Array
	_assert_true(bundles.size() >= 3, "invite offers should expose at least three bundles")
	var tournaments: Array = state.call("get_hive_tournament_entries") as Array
	_assert_true(tournaments.size() >= 3, "queen tournament list should expose hive honey costs")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("HIVE_GOVERNANCE_ROLE_SMOKE: PASS")
	quit(0)

func _member(player_id: String, display_name: String, role: String, joined_at_unix: int, honey: int) -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"role": role,
		"joined_at_unix": joined_at_unix,
		"last_seen_at_unix": int(Time.get_unix_time_from_system()),
		"honey_contributed": honey
	}

func _repeat_text(text: String, count: int) -> String:
	var out: String = ""
	for _i in range(count):
		out += text
	return out

func _role_for(hive: Dictionary, player_id: String) -> String:
	for member_any in hive.get("members", []) as Array:
		if typeof(member_any) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_any as Dictionary
		if str(member.get("player_id", "")) == player_id:
			return str(member.get("role", ""))
	return ""

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("HIVE_GOVERNANCE_ROLE_SMOKE: %s" % label)
	quit(1)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	push_error("HIVE_GOVERNANCE_ROLE_SMOKE: %s (expected %s, got %s)" % [label, expected, actual])
	quit(1)
