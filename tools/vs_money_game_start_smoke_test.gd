extends SceneTree

const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const VS_MODE_SELECT_PATH: String = "res://scripts/ui/vs_mode_select.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var handshake: Node = get_root().get_node_or_null("/root/VsHandshake")
	if handshake == null:
		_fail("VsHandshake autoload missing")
		return
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
	if handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	if handshake.has_method("clear"):
		handshake.call("clear")

	for price_usd in _money_game_prices_from_menu():
		if int(price_usd) <= 0:
			continue
		_test_paid_invite_escrows_listed_stake(handshake, int(price_usd))

	_test_paid_match_draw_refunds_escrow(handshake)
	_test_paid_rematch_requires_fresh_cash(handshake)
	_test_insufficient_funds_blocks_paid_start(handshake)
	_test_free_roll_starts_without_ledger(handshake)

	print("VS_MONEY_GAME_START_SMOKE: PASS")
	quit(0)

func _money_game_prices_from_menu() -> Array[int]:
	var out: Array[int] = []
	var source: String = FileAccess.get_file_as_string(VS_MODE_SELECT_PATH)
	for line in source.split("\n"):
		var clean_line: String = line.strip_edges()
		if not clean_line.begins_with("const PRICES"):
			continue
		var open_bracket: int = clean_line.find("[")
		var close_bracket: int = clean_line.find("]")
		if open_bracket < 0 or close_bracket <= open_bracket:
			break
		var csv: String = clean_line.substr(open_bracket + 1, close_bracket - open_bracket - 1)
		for token in csv.split(","):
			var price: int = int(str(token).strip_edges())
			if price > 0:
				out.append(price)
		break
	if out.is_empty():
		_fail("no money-game prices found in %s" % VS_MODE_SELECT_PATH)
	return out

func _test_paid_invite_escrows_listed_stake(handshake: Node, price_usd: int) -> void:
	var wager_cents: int = price_usd * 100
	var host_uid: String = "money_host_%d" % price_usd
	var guest_uid: String = "money_guest_%d" % price_usd
	_assert_ok(handshake.call("debug_set_money_balance_cents", host_uid, wager_cents), "seed host $%d" % price_usd)
	_assert_ok(handshake.call("debug_set_money_balance_cents", guest_uid, wager_cents), "seed guest $%d" % price_usd)
	_assert_ok(handshake.call("debug_set_money_balance_cents", "house", 0), "reset house $%d" % price_usd)

	var invite: Dictionary = handshake.call(
		"create_invite",
		{"uid": host_uid, "display_name": "Money Host %d" % price_usd},
		{"mode": "PVP", "map_count": 1, "price_usd": price_usd, "free_roll": false}
	) as Dictionary
	_assert_ok(invite, "create paid invite $%d" % price_usd)
	var join_result: Dictionary = handshake.call(
		"join_invite",
		str(invite.get("invite_code", "")),
		{"uid": guest_uid, "display_name": "Money Guest %d" % price_usd}
	) as Dictionary
	_assert_ok(join_result, "join paid invite $%d" % price_usd)

	var session: Dictionary = join_result.get("session", {}) as Dictionary
	var context: Dictionary = session.get("context", {}) as Dictionary
	_assert_eq(str(session.get("status", "")), "started", "paid session starts after escrow")
	_assert_bool(bool(context.get("paid_entry", false)), true, "paid entry flag set")
	_assert_eq(int(context.get("price_usd", 0)), price_usd, "price_usd preserved")
	_assert_eq(int(context.get("wager_cents", 0)), wager_cents, "wager cents derived from listed price")
	_assert_eq(str(context.get("ledger_status", "")), "escrowed", "ledger status stored on context")
	_assert_eq(int(context.get("pot_cents", 0)), wager_cents * 2, "pot contains both wagers")
	_assert_eq(handshake.call("debug_get_money_balance_cents", host_uid), 0, "host debited into escrow")
	_assert_eq(handshake.call("debug_get_money_balance_cents", guest_uid), 0, "guest debited into escrow")

	var ledger_match: Dictionary = handshake.call("debug_get_money_match_snapshot", str(session.get("id", ""))) as Dictionary
	_assert_eq(str(ledger_match.get("status", "")), "escrowed", "ledger match escrowed")
	_assert_eq(int(ledger_match.get("wager_cents", 0)), wager_cents, "ledger wager cents")
	var session_id: String = str(session.get("id", ""))
	var open_transactions: Array[Dictionary] = handshake.call("debug_get_money_transaction_ledger", {"session_id": session_id}) as Array[Dictionary]
	_assert_eq(open_transactions.size(), 2, "paid VS open writes two escrow transactions")

	var settle_result: Dictionary = handshake.call("settle_money_match", session_id, 1, "smoke_p1_win") as Dictionary
	_assert_ok(settle_result, "settle paid VS host win $%d" % price_usd)
	var expected_payout: int = wager_cents * 2 - int((wager_cents * 2 * 1000) / 10000)
	var expected_rake: int = wager_cents * 2 - expected_payout
	_assert_eq(int(settle_result.get("winner_payout_cents", 0)), expected_payout, "paid VS winner payout")
	_assert_eq(int(settle_result.get("house_rake_cents", 0)), expected_rake, "paid VS house rake")
	_assert_eq(handshake.call("debug_get_money_balance_cents", host_uid), expected_payout, "host credited settlement payout")
	_assert_eq(handshake.call("debug_get_money_balance_cents", guest_uid), 0, "guest receives no settlement payout")
	_assert_eq(handshake.call("debug_get_money_balance_cents", "house"), expected_rake, "house credited rake")
	var settled_session: Dictionary = (settle_result.get("session", {}) as Dictionary)
	var settled_context: Dictionary = settled_session.get("context", {}) as Dictionary
	_assert_eq(str(settled_context.get("ledger_status", "")), "settled", "session context marks paid match settled")
	var settled_transactions: Array[Dictionary] = handshake.call("debug_get_money_transaction_ledger", {"session_id": session_id}) as Array[Dictionary]
	_assert_eq(settled_transactions.size(), 4, "paid VS settlement writes payout and rake transactions")
	var duplicate_settle: Dictionary = handshake.call("settle_money_match", session_id, 1, "smoke_p1_win") as Dictionary
	_assert_ok(duplicate_settle, "duplicate paid VS settlement returns ok")
	_assert_eq((handshake.call("debug_get_money_transaction_ledger", {"session_id": session_id}) as Array).size(), 4, "duplicate paid VS settlement does not add transactions")

func _test_paid_match_draw_refunds_escrow(handshake: Node) -> void:
	var host_uid: String = "money_draw_host"
	var guest_uid: String = "money_draw_guest"
	_assert_ok(handshake.call("debug_set_money_balance_cents", host_uid, 100), "seed draw host")
	_assert_ok(handshake.call("debug_set_money_balance_cents", guest_uid, 100), "seed draw guest")
	var invite: Dictionary = handshake.call(
		"create_invite",
		{"uid": host_uid, "display_name": "Draw Host"},
		{"mode": "PVP", "map_count": 1, "price_usd": 1, "free_roll": false}
	) as Dictionary
	_assert_ok(invite, "create draw paid invite")
	var join_result: Dictionary = handshake.call(
		"join_invite",
		str(invite.get("invite_code", "")),
		{"uid": guest_uid, "display_name": "Draw Guest"}
	) as Dictionary
	_assert_ok(join_result, "join draw paid invite")
	var session: Dictionary = join_result.get("session", {}) as Dictionary
	var session_id: String = str(session.get("id", ""))
	var refund_result: Dictionary = handshake.call("settle_money_match", session_id, 0, "smoke_draw") as Dictionary
	_assert_ok(refund_result, "draw paid VS refunds escrow")
	_assert_eq(str(refund_result.get("type", "")), "match_refunded", "draw settlement uses refund result")
	_assert_eq(handshake.call("debug_get_money_balance_cents", host_uid), 100, "draw refund restores host")
	_assert_eq(handshake.call("debug_get_money_balance_cents", guest_uid), 100, "draw refund restores guest")
	var refunded_match: Dictionary = handshake.call("debug_get_money_match_snapshot", session_id) as Dictionary
	_assert_eq(str(refunded_match.get("status", "")), "refunded", "draw marks ledger refunded")

func _test_paid_rematch_requires_fresh_cash(handshake: Node) -> void:
	var host_uid: String = "money_broke_rematch_host"
	var guest_uid: String = "money_broke_rematch_guest"
	_assert_ok(handshake.call("debug_set_money_balance_cents", host_uid, 5500), "seed rematch host")
	_assert_ok(handshake.call("debug_set_money_balance_cents", guest_uid, 5000), "seed rematch guest")
	var invite: Dictionary = handshake.call(
		"create_invite",
		{"uid": host_uid, "display_name": "Broke Rematch Host"},
		{"mode": "PVP", "map_count": 1, "price_usd": 50, "free_roll": false}
	) as Dictionary
	_assert_ok(invite, "create broke-rematch paid invite")
	var join_result: Dictionary = handshake.call(
		"join_invite",
		str(invite.get("invite_code", "")),
		{"uid": guest_uid, "display_name": "Broke Rematch Guest"}
	) as Dictionary
	_assert_ok(join_result, "join broke-rematch paid invite")
	var session: Dictionary = join_result.get("session", {}) as Dictionary
	var session_id: String = str(session.get("id", ""))
	var settle_result: Dictionary = handshake.call("settle_money_match", session_id, 2, "smoke_guest_win") as Dictionary
	_assert_ok(settle_result, "settle guest win before rematch")
	_assert_eq(handshake.call("debug_get_money_balance_cents", host_uid), 500, "host has only five dollars after losing")

	var host_funding: Dictionary = handshake.call("get_money_rematch_funding_status", session_id, 1) as Dictionary
	_assert_ok(host_funding, "check broke host rematch funding")
	_assert_bool(bool(host_funding.get("payment_required", false)), true, "host needs cash for $50 rematch")
	_assert_eq(int(host_funding.get("wager_cents", 0)), 5000, "rematch requires original wager")
	_assert_eq(int(host_funding.get("balance_cents", 0)), 500, "rematch funding sees current balance")
	_assert_eq(int(host_funding.get("missing_cents", 0)), 4500, "rematch funding reports missing cash")

	var prepare_blocked: Dictionary = handshake.call("prepare_money_rematch", session_id) as Dictionary
	_assert_code(prepare_blocked, "insufficient_funds", "rematch escrow rejected while host is short")
	var blocked_transactions: Array[Dictionary] = handshake.call("debug_get_money_transaction_ledger", {"session_id": session_id}) as Array[Dictionary]
	_assert_eq(blocked_transactions.size(), 4, "failed rematch prepare does not add parent transactions")

	_assert_ok(handshake.call("debug_set_money_balance_cents", host_uid, 5000), "top up rematch host")
	var prepare_ok: Dictionary = handshake.call("prepare_money_rematch", session_id) as Dictionary
	_assert_ok(prepare_ok, "prepare paid rematch after top-up")
	var rematch_session: Dictionary = prepare_ok.get("session", {}) as Dictionary
	var rematch_session_id: String = str(rematch_session.get("id", ""))
	if rematch_session_id.is_empty():
		_fail("prepared rematch should return new session id")
	var rematch_context: Dictionary = rematch_session.get("context", {}) as Dictionary
	_assert_eq(str(rematch_session.get("status", "")), "started", "prepared rematch starts after escrow")
	_assert_eq(str(rematch_context.get("ledger_status", "")), "escrowed", "prepared rematch context is escrowed")
	_assert_eq(int(rematch_context.get("wager_cents", 0)), 5000, "prepared rematch preserves wager")
	var rematch_ledger_match: Dictionary = handshake.call("debug_get_money_match_snapshot", rematch_session_id) as Dictionary
	_assert_eq(str(rematch_ledger_match.get("status", "")), "escrowed", "prepared rematch has fresh ledger match")
	_assert_eq(handshake.call("debug_get_money_balance_cents", host_uid), 0, "top-up host debited into rematch escrow")

	var prepare_duplicate: Dictionary = handshake.call("prepare_money_rematch", session_id) as Dictionary
	_assert_ok(prepare_duplicate, "duplicate rematch prepare returns cached session")
	_assert_bool(bool(prepare_duplicate.get("cached", false)), true, "duplicate rematch prepare is cached")
	_assert_eq(str(prepare_duplicate.get("session_id", "")), rematch_session_id, "duplicate rematch prepare returns same session")

func _test_insufficient_funds_blocks_paid_start(handshake: Node) -> void:
	var host_uid: String = "money_poor_host"
	var guest_uid: String = "money_poor_guest"
	_assert_ok(handshake.call("debug_set_money_balance_cents", host_uid, 99), "seed poor host")
	_assert_ok(handshake.call("debug_set_money_balance_cents", guest_uid, 100), "seed poor guest")
	var invite: Dictionary = handshake.call(
		"create_invite",
		{"uid": host_uid, "display_name": "Poor Host"},
		{"mode": "PVP", "map_count": 1, "price_usd": 1, "free_roll": false}
	) as Dictionary
	_assert_ok(invite, "create insufficient invite")
	var join_result: Dictionary = handshake.call(
		"join_invite",
		str(invite.get("invite_code", "")),
		{"uid": guest_uid, "display_name": "Poor Guest"}
	) as Dictionary
	_assert_code(join_result, "insufficient_funds", "insufficient paid join rejected")
	_assert_eq(handshake.call("debug_get_money_balance_cents", host_uid), 99, "failed escrow does not debit host")
	_assert_eq(handshake.call("debug_get_money_balance_cents", guest_uid), 100, "failed escrow does not debit guest")
	var session: Dictionary = handshake.call("get_session", str(invite.get("session_id", ""))) as Dictionary
	_assert_eq(str(session.get("status", "")), "waiting", "failed paid join leaves session waiting")

func _test_free_roll_starts_without_ledger(handshake: Node) -> void:
	var host_uid: String = "money_free_host"
	var guest_uid: String = "money_free_guest"
	var invite: Dictionary = handshake.call(
		"create_invite",
		{"uid": host_uid, "display_name": "Free Host"},
		{"mode": "PVP", "map_count": 1, "price_usd": 0, "free_roll": true}
	) as Dictionary
	_assert_ok(invite, "create free invite")
	var join_result: Dictionary = handshake.call(
		"join_invite",
		str(invite.get("invite_code", "")),
		{"uid": guest_uid, "display_name": "Free Guest"}
	) as Dictionary
	_assert_ok(join_result, "join free invite")
	var session: Dictionary = join_result.get("session", {}) as Dictionary
	var context: Dictionary = session.get("context", {}) as Dictionary
	_assert_eq(str(session.get("status", "")), "started", "free roll still starts")
	_assert_bool(bool(context.get("paid_entry", true)), false, "free roll is not paid")
	_assert_eq(int(context.get("wager_cents", -1)), 0, "free roll wager is zero")
	var ledger_match: Dictionary = handshake.call("debug_get_money_match_snapshot", str(session.get("id", ""))) as Dictionary
	if not ledger_match.is_empty():
		_fail("free roll should not create ledger match: %s" % str(ledger_match))

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	_fail("%s failed: %s" % [label, str(result)])

func _assert_code(result: Dictionary, code: String, label: String) -> void:
	if bool(result.get("ok", false)):
		_fail("%s expected code %s but got ok" % [label, code])
		return
	if str(result.get("code", "")) != code and str(result.get("err", "")) != code:
		_fail("%s expected code %s but got %s" % [label, code, str(result)])

func _assert_bool(actual: bool, expected: bool, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %s got %s" % [label, str(expected), str(actual)])

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %s got %s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	push_error("VS_MONEY_GAME_START_SMOKE: %s" % message)
	quit(1)
