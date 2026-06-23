extends SceneTree

const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const DEFAULT_BACKEND_URL: String = "http://127.0.0.1:8791/v1"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var backend_url: String = OS.get_environment("SF_VS_BACKEND_URL").strip_edges()
	if backend_url.is_empty():
		backend_url = DEFAULT_BACKEND_URL
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, backend_url)
	var handshake: Node = get_root().get_node_or_null("/root/VsHandshake")
	if handshake == null:
		_fail("VsHandshake autoload missing")
		return
	if handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	if handshake.has_method("clear"):
		handshake.call("clear")
	_assert_eq(str(handshake.call("get_transport_mode")), "http", "backend smoke requires HTTP transport")

	await _test_async_entry_uses_backend_ledger(handshake)
	_test_paid_vs_settles_on_backend(handshake)

	print("MONEY_GAME_BACKEND_TRANSPORT_SMOKE: PASS")
	quit(0)

func _test_async_entry_uses_backend_ledger(handshake: Node) -> void:
	var stamp: int = Time.get_ticks_msec()
	var scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		_fail("failed to load MainMenu.tscn")
		return
	var menu: Node = scene.instantiate()
	menu.set("_dev_bypass_cash_balance", false)
	menu.set("_wallet_profile", {"balance_usd": 10})
	get_root().add_child(menu)
	await process_frame
	await process_frame
	var map_ids: PackedStringArray = PackedStringArray(["MAP_nomansland__545__v01_top2_sides__1p"])
	menu.call("_open_async_vs_lobby", "STAGE_RACE", 1, false, 5, {
		"contest_id": "BACKEND_SMOKE_ASYNC_%d" % stamp,
		"contest_scope": "WEEKLY",
		"map_ids": map_ids
	})
	await process_frame
	await process_frame
	_assert_eq(int((menu.get("_wallet_profile") as Dictionary).get("balance_usd", -1)), 5, "backend async entry debits preview wallet")
	var local_snapshot: Dictionary = menu.call("debug_get_async_money_ledger_snapshot") as Dictionary
	var local_entries: Dictionary = local_snapshot.get("entries", {}) as Dictionary
	_assert_eq(local_entries.size(), 0, "backend async escrow should not write local async ledger")
	var lobby: Node = menu.get("_vs_lobby") as Node
	if lobby == null:
		_fail("VS lobby did not open after backend async escrow")
		return
	var context: Dictionary = lobby.call("_handshake_context") as Dictionary
	_assert_eq(str(context.get("async_money_ledger_source", "")), "backend", "async lobby context uses backend ledger")
	_assert_eq(str(context.get("async_money_ledger_status", "")), "escrowed", "async lobby context carries backend escrow status")
	_assert_eq(int(context.get("async_money_pot_cents", 0)), 500, "backend async pot contains wager")
	var entry_id: String = str(context.get("async_money_entry_id", "")).strip_edges()
	if entry_id.is_empty():
		_fail("backend async escrow did not return entry id")
		return
	var refund: Dictionary = handshake.call("refund_async_entry", entry_id, "backend_smoke_cleanup", "refund:%s:backend_smoke_cleanup" % entry_id) as Dictionary
	_assert_ok(refund, "refund backend async entry")
	menu.queue_free()

func _test_paid_vs_settles_on_backend(handshake: Node) -> void:
	var stamp: int = Time.get_ticks_msec()
	var host_uid: String = "backend_paid_host_%d" % stamp
	var guest_uid: String = "backend_paid_guest_%d" % stamp
	var invite: Dictionary = handshake.call(
		"create_invite",
		{"uid": host_uid, "display_name": "Backend Paid Host", "balance_cents": 1000},
		{"mode": "PVP_BACKEND_SMOKE", "map_count": 1, "price_usd": 1, "wager_cents": 100, "free_roll": false, "paid_entry": true}
	) as Dictionary
	_assert_ok(invite, "create backend paid invite")
	var join_result: Dictionary = handshake.call(
		"join_invite",
		str(invite.get("invite_code", "")),
		{"uid": guest_uid, "display_name": "Backend Paid Guest", "balance_cents": 1000}
	) as Dictionary
	_assert_ok(join_result, "join backend paid invite")
	var session: Dictionary = join_result.get("session", {}) as Dictionary
	var context: Dictionary = session.get("context", {}) as Dictionary
	var session_id: String = str(join_result.get("session_id", ""))
	_assert_eq(str(session.get("status", "")), "started", "backend paid session starts after escrow")
	_assert_eq(str(context.get("ledger_status", "")), "escrowed", "backend paid session context is escrowed")
	_assert_eq(int(context.get("pot_cents", 0)), 200, "backend paid session pot contains both wagers")
	var settle_result: Dictionary = handshake.call("settle_money_match", session_id, 1, "backend_smoke_host_win") as Dictionary
	_assert_ok(settle_result, "settle backend paid VS")
	_assert_eq(str(settle_result.get("type", "")), "match_settled", "backend paid settlement type")
	_assert_eq(str(settle_result.get("winner_uid", "")), host_uid, "backend paid settlement maps owner 1 to host uid")
	_assert_eq(int(settle_result.get("winner_payout_cents", 0)), 180, "backend paid settlement pays winner")
	_assert_eq(int(settle_result.get("house_rake_cents", 0)), 20, "backend paid settlement pays house rake")
	var settled_session: Dictionary = handshake.call("get_session", session_id) as Dictionary
	var settled_context: Dictionary = settled_session.get("context", {}) as Dictionary
	_assert_eq(str(settled_context.get("ledger_status", "")), "settled", "backend session context marks ledger settled")

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	_fail("%s failed: %s" % [label, str(result)])

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %s got %s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	push_error("MONEY_GAME_BACKEND_TRANSPORT_SMOKE: %s" % message)
	quit(1)
