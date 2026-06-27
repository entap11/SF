extends SceneTree

const PLAYER_ID: String = "live_wax_backend_player"
const OPPONENT_ID: String = "live_wax_backend_opponent"
const MATCH_ID: String = "live_wax_backend_match"
const EVENT_ID: String = "competitive_wax:live_wax_backend_match:live_wax_backend_player"

func _init() -> void:
	await process_frame
	var handshake: Node = get_root().get_node_or_null("VsHandshake")
	var crucible_state: Node = get_root().get_node_or_null("CrucibleState")
	if handshake == null or crucible_state == null:
		_fail("required autoload missing")
		return
	if not handshake.has_method("get_transport_mode") or str(handshake.call("get_transport_mode")) != "http":
		_fail("VsHandshake must be configured for HTTP backend")
		return
	if crucible_state.has_method("debug_reset_state"):
		crucible_state.call("debug_reset_state")
	var result: Dictionary = crucible_state.call("intent_apply_competitive_wax_result", MATCH_ID, PLAYER_ID, OPPONENT_ID, true, "1V1", {
		"event_id": EVENT_ID,
		"player_rating": 1000.0,
		"opponent_rating": 1000.0,
		"winner_id": 1,
		"reason": "live_pvp_backend_smoke"
	}) as Dictionary
	_assert_ok(result, "publish competitive Wax result")
	_assert_eq(int(result.get("balance_millis", 0)), 3000, "backend credited 3 Wax")
	_assert_eq(int(crucible_state.call("get_balance_millis", PLAYER_ID)), 3000, "local mirror updated from backend")
	var snapshot: Dictionary = handshake.call("debug_get_crucible_snapshot") as Dictionary
	_assert_ok(snapshot, "fetch backend Crucible snapshot")
	var ledger: Dictionary = snapshot.get("ledger", {}) as Dictionary
	var balances: Dictionary = ledger.get("balances_by_player", {}) as Dictionary
	_assert_eq(int(balances.get(PLAYER_ID, 0)), 3000, "backend ledger balance")
	var awards: Dictionary = ledger.get("competitive_wax_awards_by_event", {}) as Dictionary
	if not awards.has(EVENT_ID):
		_fail("backend ledger missing competitive Wax award")
		return
	var duplicate: Dictionary = crucible_state.call("intent_apply_competitive_wax_result", MATCH_ID, PLAYER_ID, OPPONENT_ID, true, "1V1", {
		"event_id": EVENT_ID,
		"player_rating": 1000.0,
		"opponent_rating": 1000.0,
		"winner_id": 1,
		"reason": "live_pvp_backend_smoke_duplicate"
	}) as Dictionary
	_assert_ok(duplicate, "duplicate competitive Wax publish")
	_assert_eq(int(duplicate.get("balance_millis", 0)), 3000, "duplicate does not double-credit")
	print("LIVE_PVP_WAX_BACKEND_PUBLISH_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if not bool(result.get("ok", false)):
		_fail("%s failed: %s" % [label, JSON.stringify(result)])

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual != expected:
		_fail("%s expected %d got %d" % [label, expected, actual])

func _fail(message: String) -> void:
	push_error(message)
	print("LIVE_PVP_WAX_BACKEND_PUBLISH_SMOKE: FAIL %s" % message)
	quit(1)
