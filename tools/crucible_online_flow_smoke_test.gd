extends SceneTree

const PLAYER_A := "crucible_online_a"
const PLAYER_B := "crucible_online_b"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var crucible_state: Node = get_root().get_node_or_null("CrucibleState")
	if crucible_state == null:
		_fail("CrucibleState missing")
		return
	if crucible_state.has_method("debug_reset_state"):
		crucible_state.call("debug_reset_state")
	_assert_ok(crucible_state.call("intent_update_config", {
		"enabled": true,
		"queue_enabled": true,
		"wagering_enabled": true,
		"settlement_enabled": true,
		"server_authoritative_settlement_required": false,
		"local_dev_settlement_enabled": true,
		"stake_bps": 0,
		"burn_bps": 0,
		"minimum_stake_millis": 1000
	}, "crucible_online_smoke") as Dictionary, "configure Crucible")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_A, 50000) as Dictionary, "seed local")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_B, 50000) as Dictionary, "seed remote")

	var lobby_scene := load("res://scenes/ui/VsLobby.tscn") as PackedScene
	if lobby_scene == null:
		_fail("VsLobby scene missing")
		return
	var lobby: Control = lobby_scene.instantiate() as Control
	get_root().add_child(lobby)
	await process_frame
	lobby.call("configure", "1V1", 1, 0, true, {
		"human_pvp": true,
		"start_players": 2,
		"pregame_setup": "session_seeded",
		"vs_ruleset": "CRUCIBLE",
		"vs_crucible": true
	})
	lobby.set("_local_uid", PLAYER_A)
	lobby.set("_local_name", "Online A")
	lobby.set("_session_role", "host")
	lobby.set("_session_id", "crucible_online_smoke_session")
	lobby.set("_bot_filled_match", true)
	lobby.set("_bot_remote_profile", {
		"uid": PLAYER_B,
		"display_name": "Online B",
		"is_cpu": true,
		"seat": 2
	})
	if not bool(lobby.call("_prepare_crucible_match_context")):
		_fail("VsLobby did not prepare Crucible escrow")
		return
	var context_meta: Dictionary = lobby.get("_context_meta") as Dictionary
	var match_id: String = str(context_meta.get("crucible_match_id", "")).strip_edges()
	if match_id.is_empty():
		_fail("VsLobby did not write Crucible match id")
		return
	_assert_eq(int(context_meta.get("crucible_stake_each_millis", 0)), 1000, "stake metadata")
	_assert_eq(int(context_meta.get("crucible_local_balance_start_millis", 0)), 50000, "start balance metadata")
	_assert_eq(int(context_meta.get("crucible_local_balance_after_escrow_millis", 0)), 49000, "after escrow metadata")

	var arena_scene := load("res://scenes/Arena.tscn") as PackedScene
	if arena_scene == null:
		_fail("Arena scene missing")
		return
	var arena: Node = arena_scene.instantiate()
	get_root().add_child(arena)
	await process_frame
	_apply_context_meta(context_meta)
	arena.call("_maybe_settle_crucible_match", 1, "online_flow_authoritative_smoke")
	await process_frame

	var snapshot: Dictionary = crucible_state.call("get_snapshot") as Dictionary
	var settlements: Dictionary = snapshot.get("settlements_by_match_id", {}) as Dictionary
	var settlement: Dictionary = settlements.get(match_id, {}) as Dictionary
	if settlement.is_empty():
		_fail("Arena did not settle lobby-created Crucible match")
		return
	_assert_eq(str(settlement.get("winner_id", "")), PLAYER_A, "winner id")
	_assert_eq(str(settlement.get("settlement_status", "")), "SETTLED", "settlement status")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_A)), 50800, "winner balance")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_B)), 49000, "loser balance")
	_assert_eq(str(get_meta("crucible_settlement_status", "")), "SETTLED", "tree settlement status")
	_assert_eq(int(get_meta("crucible_local_balance_finish_millis", 0)), 50800, "local finish balance")
	_assert_eq(int(get_meta("crucible_remote_balance_finish_millis", 0)), 49000, "remote finish balance")
	_assert_eq(int(get_meta("crucible_balance_delta_millis", 0)), 800, "local balance delta")

	lobby.queue_free()
	arena.queue_free()
	_clear_context_meta()
	await process_frame
	print("CRUCIBLE_ONLINE_FLOW_SMOKE: PASS")
	quit(0)

func _apply_context_meta(context_meta: Dictionary) -> void:
	for key in [
		"vs_ruleset",
		"vs_crucible",
		"crucible_match_id",
		"crucible_config_version",
		"crucible_config_hash",
		"crucible_escrow_id",
		"crucible_stake_each_millis",
		"crucible_pot_millis",
		"crucible_burn_millis",
		"crucible_winner_payout_millis",
		"crucible_local_balance_start_millis",
		"crucible_local_balance_after_escrow_millis",
		"crucible_remote_balance_start_millis",
		"crucible_remote_balance_after_escrow_millis",
		"crucible_player_a_id",
		"crucible_player_b_id",
		"crucible_player_a_seat",
		"crucible_player_b_seat"
	]:
		if context_meta.has(key):
			set_meta(key, context_meta.get(key))
	set_meta("vs_handshake_session_id", "crucible_online_smoke_session")
	set_meta("vs_local_profile", {"uid": PLAYER_A, "display_name": "Online A", "seat": 1})
	set_meta("vs_remote_profile", {"uid": PLAYER_B, "display_name": "Online B", "seat": 2})

func _clear_context_meta() -> void:
	for key in [
		"vs_ruleset",
		"vs_crucible",
		"crucible_match_id",
		"crucible_config_version",
		"crucible_config_hash",
		"crucible_escrow_id",
		"crucible_stake_each_millis",
		"crucible_pot_millis",
		"crucible_burn_millis",
		"crucible_winner_payout_millis",
		"crucible_local_balance_start_millis",
		"crucible_local_balance_after_escrow_millis",
		"crucible_remote_balance_start_millis",
		"crucible_remote_balance_after_escrow_millis",
		"crucible_local_balance_finish_millis",
		"crucible_remote_balance_finish_millis",
		"crucible_balance_delta_millis",
		"crucible_player_a_balance_finish_millis",
		"crucible_player_b_balance_finish_millis",
		"crucible_player_a_id",
		"crucible_player_b_id",
		"crucible_player_a_seat",
		"crucible_player_b_seat",
		"vs_handshake_session_id",
		"vs_local_profile",
		"vs_remote_profile",
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
	push_error("CRUCIBLE_ONLINE_FLOW_SMOKE: %s" % message)
	quit(1)
