extends SceneTree

const MATCH_ID := "crucible_arena_settlement_smoke"
const NO_CONTEST_MATCH_ID := "crucible_arena_no_contest_smoke"
const PLAYER_A := "crucible_arena_a"
const PLAYER_B := "crucible_arena_b"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var crucible_state: Node = get_root().get_node_or_null("CrucibleState")
	if crucible_state == null:
		_fail("CrucibleState missing")
		return
	if crucible_state.has_method("debug_reset_state"):
		crucible_state.call("debug_reset_state")
	if crucible_state.has_method("intent_update_config"):
		_assert_ok(crucible_state.call("intent_update_config", {
			"enabled": true,
			"queue_enabled": true,
			"wagering_enabled": true,
			"settlement_enabled": true,
			"server_authoritative_settlement_required": false,
			"local_dev_settlement_enabled": true,
			"stake_bps": 500,
			"burn_bps": 1000,
			"minimum_stake_millis": 1000
		}, "crucible_arena_smoke") as Dictionary, "configure Crucible")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_A, 50000) as Dictionary, "seed A")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_B, 50000) as Dictionary, "seed B")
	_assert_ok(crucible_state.call("intent_open_escrow", MATCH_ID, PLAYER_A, PLAYER_B, {}) as Dictionary, "open arena escrow")

	var arena: Node = await _instantiate_arena()
	if arena == null:
		return
	_apply_crucible_tree_meta(MATCH_ID)
	arena.call("_maybe_settle_crucible_match", 1, "arena_authoritative_smoke")
	await process_frame
	var snapshot: Dictionary = crucible_state.call("get_snapshot") as Dictionary
	var settlements: Dictionary = snapshot.get("settlements_by_match_id", {}) as Dictionary
	var settlement: Dictionary = settlements.get(MATCH_ID, {}) as Dictionary
	if settlement.is_empty():
		_fail("Arena hook did not write Crucible settlement")
		return
	_assert_eq(str(settlement.get("winner_id", "")), PLAYER_A, "seat 1 should map to player A")
	_assert_eq(str(settlement.get("result_source", "")), "AUTHORITATIVE_SIM", "settlement source")
	_assert_eq(str(get_meta("crucible_settlement_status", "")), "SETTLED", "tree status")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_A)), 52000, "winner payout")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_B)), 47500, "loser remains debited")

	_clear_crucible_tree_meta()
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_A, 10000) as Dictionary, "seed no contest A")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_B, 10000) as Dictionary, "seed no contest B")
	_assert_ok(crucible_state.call("intent_open_escrow", NO_CONTEST_MATCH_ID, PLAYER_A, PLAYER_B, {}) as Dictionary, "open no contest arena escrow")
	_apply_crucible_tree_meta(NO_CONTEST_MATCH_ID)
	arena.call("_maybe_settle_crucible_match", 0, "arena_draw_smoke")
	await process_frame
	snapshot = crucible_state.call("get_snapshot") as Dictionary
	settlements = snapshot.get("settlements_by_match_id", {}) as Dictionary
	var no_contest: Dictionary = settlements.get(NO_CONTEST_MATCH_ID, {}) as Dictionary
	if no_contest.is_empty():
		_fail("Arena hook did not write no-contest settlement")
		return
	_assert_eq(str(no_contest.get("settlement_status", "")), "NO_CONTEST", "draw should no-contest")
	_assert_eq(int(no_contest.get("burn", -1)), 0, "draw burns nothing")
	_assert_eq(int(no_contest.get("winner_payout", -1)), 0, "draw pays nothing")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_A)), 10000, "A refunded")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_B)), 10000, "B refunded")

	arena.queue_free()
	_clear_crucible_tree_meta()
	await process_frame
	print("CRUCIBLE_ARENA_SETTLEMENT_SMOKE: PASS")
	quit(0)

func _instantiate_arena() -> Node:
	var arena_scene: PackedScene = load("res://scenes/Arena.tscn") as PackedScene
	if arena_scene == null:
		_fail("Arena scene missing")
		return null
	var arena: Node = arena_scene.instantiate()
	get_root().add_child(arena)
	await process_frame
	return arena

func _apply_crucible_tree_meta(match_id: String) -> void:
	set_meta("vs_ruleset", "CRUCIBLE")
	set_meta("vs_crucible", true)
	set_meta("crucible_match_id", match_id)
	set_meta("crucible_player_a_id", PLAYER_A)
	set_meta("crucible_player_b_id", PLAYER_B)
	set_meta("crucible_player_a_seat", 1)
	set_meta("crucible_player_b_seat", 2)
	set_meta("vs_handshake_session_id", "crucible_arena_smoke_session")
	if has_meta("crucible_settlement_status"):
		remove_meta("crucible_settlement_status")
	if has_meta("crucible_settlement_result"):
		remove_meta("crucible_settlement_result")

func _clear_crucible_tree_meta() -> void:
	for key in [
		"vs_ruleset",
		"vs_crucible",
		"crucible_match_id",
		"crucible_player_a_id",
		"crucible_player_b_id",
		"crucible_player_a_seat",
		"crucible_player_b_seat",
		"vs_handshake_session_id",
		"crucible_settlement_status",
		"crucible_settlement_result"
	]:
		if has_meta(key):
			remove_meta(key)

func _assert_ok(result: Dictionary, message: String) -> void:
	if bool(result.get("ok", false)):
		return
	_fail("%s failed: %s" % [message, str(result)])

func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_fail("%s expected=%s actual=%s" % [message, str(expected), str(actual)])

func _fail(message: String) -> void:
	push_error("CRUCIBLE_ARENA_SETTLEMENT_SMOKE: %s" % message)
	quit(1)
