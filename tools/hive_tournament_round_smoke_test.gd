extends SceneTree

class FakeSimRunner:
	extends Node
	signal match_ended(winner_id: int, reason: String)

class FakeRankState:
	extends Node

	func get_snapshot() -> Dictionary:
		return {"player_count": 200}

	func get_player_snapshot(player_id: String) -> Dictionary:
		var suffix: String = player_id.strip_edges().right(1)
		var rank_position: int = int(suffix.to_int())
		if rank_position <= 0:
			rank_position = 50
		return {
			"rank_position": rank_position,
			"tier_id": "DRONE",
			"wax_score": float(1000 - rank_position)
		}

const HiveClanStateScript = preload("res://scripts/state/hive_clan_state.gd")
const SAVE_PATH := "user://hive_tournament_round_smoke.json"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	await process_frame

	var profile_manager: Node = get_root().get_node_or_null("ProfileManager")
	if profile_manager == null:
		_fail("ProfileManager autoload missing")
		return
	profile_manager.call("set_user_id", "ta1")
	profile_manager.call("set_display_name", "Alpha Queen")

	var existing_rank_state: Node = get_root().get_node_or_null("RankState")
	if existing_rank_state != null:
		existing_rank_state.name = "RankStateOriginal"
	var fake_rank_state := FakeRankState.new()
	fake_rank_state.name = "RankState"
	get_root().add_child(fake_rank_state)

	var state: Node = HiveClanStateScript.new()
	state.set("save_path", SAVE_PATH)
	get_root().add_child(state)
	await process_frame

	var now_unix: int = int(Time.get_unix_time_from_system())
	state.set("_hives_by_id", {
		"h_alpha": _build_hive("h_alpha", "Alpha Hive", "ta1", now_unix, "ta"),
		"h_beta": _build_hive("h_beta", "Beta Hive", "tb1", now_unix, "tb"),
		"h_gamma": _build_hive("h_gamma", "Gamma Hive", "tc1", now_unix, "tc"),
		"h_delta": _build_hive("h_delta", "Delta Hive", "td1", now_unix, "td")
	})
	state.call("_reindex_memberships")

	for entry_request in [
		{"hive_id": "h_alpha", "player_id": "ta1"},
		{"hive_id": "h_beta", "player_id": "tb1"},
		{"hive_id": "h_gamma", "player_id": "tc1"},
		{"hive_id": "h_delta", "player_id": "td1"}
	]:
		var entry_result: Dictionary = state.call("intent_enter_hive_tournament", str(entry_request.get("hive_id", "")), "weekly_hive_skirmish", str(entry_request.get("player_id", ""))) as Dictionary
		_assert_true(bool(entry_result.get("ok", false)), "weekly bracket entry should succeed")

	var assignment: Dictionary = state.call("get_player_active_tournament_assignment", "ta1") as Dictionary
	_assert_true(not assignment.is_empty(), "local queen should get a semifinal assignment")
	var round_id: String = str(assignment.get("round_id", ""))
	_assert_true(round_id != "", "local semifinal assignment should include a round id")
	var round: Dictionary = (state.get("_hive_tournament_rounds_by_id") as Dictionary).get(round_id, {}) as Dictionary
	_assert_eq(str(round.get("status", "")), "active", "local semifinal should be active")
	_assert_eq(int(assignment.get("bracket_round_number", 0)), 1, "local assignment should begin in bracket round one")

	var tree: SceneTree = self
	tree.set_meta("vs_mode", "STAGE_RACE")
	tree.set_meta("vs_stage_map_paths", (round.get("map_paths", []) as Array).duplicate(true))
	tree.set_meta("vs_stage_current_index", 2)
	tree.set_meta("vs_stage_round_results", [
		{"round_index": 0, "elapsed_ms": 61000},
		{"round_index": 1, "elapsed_ms": 62000}
	])
	tree.set_meta("hive_tournament_round_id", str(round.get("round_id", "")))
	tree.set_meta("hive_tournament_player_id", "ta1")
	tree.set_meta("hive_tournament_submission_recorded", false)

	var ops_state: Node = get_root().get_node_or_null("OpsState")
	if ops_state == null:
		_fail("OpsState autoload missing")
		return
	ops_state.set("match_elapsed_ms", 63000)

	var fake_runner := FakeSimRunner.new()
	fake_runner.name = "SimRunner"
	get_root().add_child(fake_runner)
	await process_frame
	fake_runner.emit_signal("match_ended", 1, "tournament_finish")
	await process_frame

	var rounds_after_runtime: Dictionary = state.get("_hive_tournament_rounds_by_id") as Dictionary
	var runtime_round: Dictionary = rounds_after_runtime.get(str(round.get("round_id", "")), {}) as Dictionary
	var runtime_slot: Dictionary = _find_round_slot(runtime_round, "ta1")
	_assert_eq(str(runtime_slot.get("status", "")), "submitted", "runtime hook should submit the local tournament run")
	_assert_eq(int(runtime_slot.get("total_time_ms", 0)), 186000, "runtime hook should aggregate all three stage times")
	var runtime_assignment: Dictionary = state.call("get_player_active_tournament_assignment", "ta1") as Dictionary
	_assert_true(runtime_assignment.is_empty(), "submitted player should no longer be queue-blocked")

	_submit_remaining_round_slots(state, runtime_round, "ta1", 186000, 196000)
	var semifinal_two: Dictionary = _find_other_active_round(state, str(round.get("round_id", "")))
	_assert_true(not semifinal_two.is_empty(), "bracket should create a second semifinal")
	_submit_all_round_slots(state, semifinal_two, 202000, 212000)

	var final_assignment: Dictionary = state.call("get_player_active_tournament_assignment", "ta1") as Dictionary
	_assert_true(not final_assignment.is_empty(), "semifinal winner should auto-advance into a final assignment")
	_assert_eq(int(final_assignment.get("bracket_round_number", 0)), 2, "winner should advance into bracket round two")
	var final_round: Dictionary = (state.get("_hive_tournament_rounds_by_id") as Dictionary).get(str(final_assignment.get("round_id", "")), {}) as Dictionary
	_assert_eq(str(final_round.get("status", "")), "active", "final should be active once both semifinals resolve")
	_submit_all_round_slots(state, final_round, 185000, 195000)

	var resolved_final: Dictionary = (state.get("_hive_tournament_rounds_by_id") as Dictionary).get(str(final_assignment.get("round_id", "")), {}) as Dictionary
	_assert_eq(str(resolved_final.get("status", "")), "resolved", "final should resolve after all submissions")
	_assert_eq(str(resolved_final.get("winner_hive_id", "")), "h_alpha", "faster hive should win the bracket final")
	var final_hives: Dictionary = state.get("_hives_by_id") as Dictionary
	var alpha_hive: Dictionary = final_hives.get("h_alpha", {}) as Dictionary
	_assert_eq(int(alpha_hive.get("tournament_wins", 0)), 1, "bracket champion should receive a tournament win")
	var alpha_awards: Array = alpha_hive.get("award_records", []) as Array
	_assert_eq(alpha_awards.size(), 1, "weekly bracket champion should mint one permanent hive trophy")
	var alpha_snapshot: Dictionary = state.call("get_hive_snapshot", "h_alpha") as Dictionary
	var alpha_rank_breakdown: Dictionary = alpha_snapshot.get("rank_breakdown", {}) as Dictionary
	_assert_true(float(alpha_rank_breakdown.get("multiplier", 1.0)) > 1.0, "weekly trophy should permanently raise hive rank multiplier")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("HIVE_TOURNAMENT_ROUND_SMOKE: PASS")
	quit(0)

func _build_hive(hive_id: String, hive_name: String, queen_id: String, now_unix: int, prefix: String) -> Dictionary:
	var members: Dictionary = {}
	for i in range(7):
		var player_id: String = "%s%d" % [prefix, i + 1]
		var role: String = "queen" if i == 0 else ("soldier" if i < 3 else "member")
		members[player_id] = _member(player_id, "%s %d" % [prefix.to_upper(), i + 1], role, now_unix - ((i + 1) * 120), 1000 - (i * 50))
	return {
		"hive_id": hive_id,
		"name": hive_name,
		"created_at_unix": now_unix - 10000,
		"created_by_player_id": queen_id,
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
		"total_honey_spent": 0,
		"feed_entries": [],
		"total_honey_contributed": 5950,
		"hive_honey_strength": 5950
	}

func _member(player_id: String, display_name: String, role: String, joined_at_unix: int, honey: int) -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"role": role,
		"joined_at_unix": joined_at_unix,
		"last_seen_at_unix": int(Time.get_unix_time_from_system()),
		"honey_contributed": honey
	}

func _find_round_slot(round: Dictionary, player_id: String) -> Dictionary:
	for key in ["hive_a_slots", "hive_b_slots"]:
		for slot_any in round.get(key, []) as Array:
			if typeof(slot_any) != TYPE_DICTIONARY:
				continue
			var slot: Dictionary = slot_any as Dictionary
			if str(slot.get("player_id", "")) == player_id:
				return slot
	return {}

func _submit_remaining_round_slots(state: Node, round: Dictionary, skip_player_id: String, hive_a_base_time_ms: int, hive_b_base_time_ms: int) -> void:
	for i in range((round.get("hive_a_slots", []) as Array).size()):
		var hive_a_slot: Dictionary = (round.get("hive_a_slots", []) as Array)[i] as Dictionary
		var hive_b_slot: Dictionary = (round.get("hive_b_slots", []) as Array)[i] as Dictionary
		var hive_a_player_id: String = str(hive_a_slot.get("player_id", ""))
		if hive_a_player_id != skip_player_id:
			state.call("intent_record_hive_tournament_submission", str(round.get("round_id", "")), hive_a_player_id, hive_a_base_time_ms + (i * 1000), [])
		state.call("intent_record_hive_tournament_submission", str(round.get("round_id", "")), str(hive_b_slot.get("player_id", "")), hive_b_base_time_ms + (i * 1000), [])

func _submit_all_round_slots(state: Node, round: Dictionary, hive_a_base_time_ms: int, hive_b_base_time_ms: int) -> void:
	for i in range((round.get("hive_a_slots", []) as Array).size()):
		var hive_a_slot: Dictionary = (round.get("hive_a_slots", []) as Array)[i] as Dictionary
		var hive_b_slot: Dictionary = (round.get("hive_b_slots", []) as Array)[i] as Dictionary
		state.call("intent_record_hive_tournament_submission", str(round.get("round_id", "")), str(hive_a_slot.get("player_id", "")), hive_a_base_time_ms + (i * 1000), [])
		state.call("intent_record_hive_tournament_submission", str(round.get("round_id", "")), str(hive_b_slot.get("player_id", "")), hive_b_base_time_ms + (i * 1000), [])

func _find_other_active_round(state: Node, excluded_round_id: String) -> Dictionary:
	var rounds_by_id: Dictionary = state.get("_hive_tournament_rounds_by_id") as Dictionary
	for round_any in rounds_by_id.values():
		var round: Dictionary = round_any as Dictionary
		if str(round.get("status", "")) != "active":
			continue
		if str(round.get("round_id", "")) == excluded_round_id:
			continue
		if int(round.get("bracket_round_number", 0)) != 1:
			continue
		return round
	return {}

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("HIVE_TOURNAMENT_ROUND_SMOKE: %s" % label)
	quit(1)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	push_error("HIVE_TOURNAMENT_ROUND_SMOKE: %s (expected %s, got %s)" % [label, expected, actual])
	quit(1)

func _fail(message: String) -> void:
	push_error("HIVE_TOURNAMENT_ROUND_SMOKE: %s" % message)
	quit(1)
