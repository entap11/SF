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
		"p5": _member("p5", "Member Five", "member", now_unix - 1000, 600),
		"p6": _member("p6", "Member Six", "member", now_unix - 900, 0),
		"p7": _member("p7", "Member Seven", "member", now_unix - 800, 0)
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
	var enter_tournament: Dictionary = state.call("intent_enter_hive_tournament", hive_id, "weekly_hive_skirmish", "p3") as Dictionary
	_assert_true(bool(enter_tournament.get("ok", false)), "queen should enter a hive tournament")
	var entered_hive: Dictionary = enter_tournament.get("hive", {}) as Dictionary
	_assert_eq(int(entered_hive.get("hive_honey_strength", 0)), 3200, "hive tournament entry should deduct hive honey strength")
	var duplicate_tournament: Dictionary = state.call("intent_enter_hive_tournament", hive_id, "weekly_hive_skirmish", "p3") as Dictionary
	_assert_true(not bool(duplicate_tournament.get("ok", false)) and str(duplicate_tournament.get("reason", "")) == "tournament_already_entered", "same hive tournament should not charge twice")

	var archive_hives: Dictionary = state.get("_hives_by_id") as Dictionary
	archive_hives["h_archive"] = {
		"hive_id": "h_archive",
		"name": "Archive Hive",
		"created_at_unix": now_unix - 7200,
		"created_by_player_id": "archive_q",
		"members": {
			"archive_q": _member("archive_q", "Archive Queen", "queen", now_unix - 7200, 50)
		},
		"pinned_notice": {},
		"about_profile": {},
		"soldier_demotion_votes": {},
		"queen_removal_vote": {},
		"queen_removal_vote_started_at_unix": 0,
		"leadership_removal_votes": {},
		"soldier_promotion_votes": {},
		"tournament_entries": {},
		"tournament_wins": 1,
		"hive_championships": 0,
		"seasonal_best_finish": 0,
		"award_records": [{
			"award_id": "hwa_archive",
			"title": "Weekly Hive Skirmish Champion Trophy",
			"detail": "Won recently",
			"award_type": "trophy",
			"tournament_id": "weekly_hive_skirmish",
			"tournament_title": "Weekly Hive Skirmish",
			"rank_multiplier_bps": 100,
			"awarded_at_unix": now_unix - 60,
			"owner_kind": "hive",
			"owner_hive_id": "h_archive",
			"owner_hive_name": "Archive Hive",
			"source_hive_id": "h_archive",
			"source_hive_name": "Archive Hive",
			"archived_at_unix": 0,
			"bracket_id": "htb_archive",
			"round_id": "htr_archive"
		}],
		"total_honey_spent": 0,
		"feed_entries": [],
		"total_honey_contributed": 50,
		"hive_honey_strength": 50
	}
	state.set("_hives_by_id", archive_hives)
	state.call("_reindex_memberships")
	state.set("_pending_leave_by_player_id", {
		"archive_q": {
			"player_id": "archive_q",
			"hive_id": "h_archive",
			"requested_at_unix": now_unix - 20,
			"effective_at_unix": now_unix - 10
		}
	})
	state.call("_finalize_leave_for_player", "archive_q", now_unix)
	var post_archive_hives: Dictionary = state.get("_hives_by_id") as Dictionary
	_assert_true(not post_archive_hives.has("h_archive"), "defunct hive should be removed after final member leaves")
	var company_trophy_case: Array = state.call("get_company_trophy_case") as Array
	_assert_eq(company_trophy_case.size(), 1, "defunct hive awards should move into the company trophy case")
	var archived_award: Dictionary = company_trophy_case[0] as Dictionary
	_assert_eq(str(archived_award.get("source_hive_name", "")), "Archive Hive", "company trophy case should retain original hive provenance")

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
