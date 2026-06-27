extends SceneTree

const PLAYER_A := "crucible_lobby_a"
const PLAYER_B := "crucible_lobby_b"

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
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_A, 50000) as Dictionary, "seed local")
	_assert_ok(crucible_state.call("intent_set_balance_millis", PLAYER_B, 50000) as Dictionary, "seed remote")
	var scene := load("res://scenes/ui/VsLobby.tscn") as PackedScene
	if scene == null:
		_fail("VsLobby scene missing")
		return
	var lobby: Control = scene.instantiate() as Control
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
	lobby.set("_local_name", "Lobby A")
	lobby.set("_session_role", "host")
	lobby.set("_session_id", "crucible_lobby_smoke_session")
	lobby.set("_bot_filled_match", true)
	lobby.set("_bot_remote_profile", {
		"uid": PLAYER_B,
		"display_name": "Lobby B",
		"is_cpu": true,
		"seat": 2
	})
	var prepared: bool = bool(lobby.call("_prepare_crucible_match_context"))
	if not prepared:
		_fail("Crucible lobby escrow did not prepare")
		return
	var context_meta: Dictionary = lobby.get("_context_meta") as Dictionary
	if str(context_meta.get("vs_ruleset", "")) != "CRUCIBLE" or not bool(context_meta.get("vs_crucible", false)):
		_fail("Crucible lobby context missing ruleset")
		return
	var match_id: String = str(context_meta.get("crucible_match_id", ""))
	if match_id.is_empty() or str(context_meta.get("crucible_escrow_id", "")).is_empty():
		_fail("Crucible lobby context missing escrow ids")
		return
	_assert_eq(int(context_meta.get("crucible_stake_each_millis", 0)), 2500, "stake metadata")
	_assert_eq(int(context_meta.get("crucible_winner_payout_millis", 0)), 4500, "winner payout metadata")
	_assert_eq(int(context_meta.get("crucible_local_balance_start_millis", 0)), 50000, "local start metadata")
	_assert_eq(int(context_meta.get("crucible_local_balance_after_escrow_millis", 0)), 47500, "local after escrow metadata")
	var status_node: Label = lobby.get("status_label") as Label
	if status_node == null or not status_node.text.contains("Crucible escrow locked"):
		_fail("Crucible lobby did not show escrow status")
		return
	var snapshot: Dictionary = crucible_state.call("get_snapshot") as Dictionary
	var settlements: Dictionary = snapshot.get("settlements_by_match_id", {}) as Dictionary
	var escrows: Dictionary = snapshot.get("escrows_by_id", {}) as Dictionary
	if escrows.is_empty() or settlements.has(match_id):
		_fail("Crucible lobby escrow snapshot invalid")
		return
	if int(crucible_state.call("get_balance_millis", PLAYER_A)) != 47500:
		_fail("Crucible lobby did not debit local stake")
		return
	lobby.queue_free()
	await process_frame
	print("CRUCIBLE_LOBBY_ESCROW_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	_fail("%s failed: %s" % [label, str(result)])

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	push_error("CRUCIBLE_LOBBY_ESCROW_SMOKE: %s" % message)
	quit(1)
