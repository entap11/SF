extends SceneTree

const CONTEST_ID: String = "WEEKLY_USD_5_2026-W26_ENTRY_SMOKE"
const CLOSED_CONTEST_ID: String = "WEEKLY_USD_5_2026-W25_ENTRY_SMOKE_CLOSED"

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("swarmfront/vs/backend_url", "")
	var handshake: Node = get_root().get_node_or_null("VsHandshake")
	if handshake != null and handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	var contest_state: Node = get_root().get_node_or_null("ContestState")
	if contest_state == null:
		_fail("ContestState autoload missing")
		return
	if contest_state.has_method("debug_reset_entries"):
		contest_state.call("debug_reset_entries")
	_install_contest(contest_state, _money_contest(CONTEST_ID, "STAGE_RACE", 5, 0, 4102444800))
	_install_contest(contest_state, _money_contest(CLOSED_CONTEST_ID, "STAGE_RACE", 5, 0, 1))

	var exact_matches: Array = contest_state.call("get_contests_by_definition", {
		"scope": "WEEKLY",
		"pool_type": "MONEY",
		"family": "STAGE_RACE",
		"price": 5
	}) as Array
	if not _contains_contest_id(exact_matches, CONTEST_ID):
		_fail("definition lookup did not include exact $5 stage race")
		return
	var wrong_price_matches: Array = contest_state.call("get_contests_by_definition", {
		"scope": "WEEKLY",
		"pool_type": "MONEY",
		"family": "STAGE_RACE",
		"price": 50
	}) as Array
	if _contains_contest_id(wrong_price_matches, CONTEST_ID):
		_fail("definition lookup leaked $5 contest into $50 query")
		return

	var short_preview: Dictionary = contest_state.call("preview_entry_requirements", CONTEST_ID, {
		"player_id": "entry_smoke_player",
		"balance_cents": 400
	}) as Dictionary
	_assert_eq(bool(short_preview.get("can_enter", true)), false, "short balance preview blocks")
	_assert_eq(str(short_preview.get("reason", "")), "insufficient_funds", "short balance reason")
	_assert_eq(int(short_preview.get("missing_cents", 0)), 100, "short balance missing cents")
	var short_enter: Dictionary = contest_state.call("intent_enter_contest", CONTEST_ID, {
		"player_id": "entry_smoke_player",
		"balance_cents": 400
	}) as Dictionary
	_assert_eq(bool(short_enter.get("ok", true)), false, "short balance entry blocks")
	_assert_eq(bool(contest_state.call("is_entered", CONTEST_ID)), false, "blocked paid entry should not mark entered")
	var empty_ledger: Dictionary = contest_state.call("debug_get_async_money_ledger_snapshot") as Dictionary
	_assert_eq((empty_ledger.get("entries", {}) as Dictionary).size(), 0, "blocked paid entry should not escrow")

	var paid_enter: Dictionary = contest_state.call("intent_enter_contest", CONTEST_ID, {
		"player_id": "entry_smoke_player",
		"balance_cents": 500
	}) as Dictionary
	_assert_eq(bool(paid_enter.get("ok", false)), true, "funded paid entry succeeds")
	_assert_eq(bool(paid_enter.get("paid_entry", false)), true, "funded entry marked paid")
	_assert_eq(bool(contest_state.call("is_entered", CONTEST_ID)), true, "funded paid entry marks entered")
	var escrow: Dictionary = paid_enter.get("escrow", {}) as Dictionary
	_assert_eq(str(escrow.get("contest_id", "")), CONTEST_ID, "escrow uses contest id")
	_assert_eq(int(escrow.get("wager_cents", 0)), 500, "escrow uses contest denomination")
	_assert_eq(str(escrow.get("ledger_source", "")), "local", "offline smoke uses local ledger fallback")
	var refund: Dictionary = contest_state.call("intent_refund_contest_entry", CONTEST_ID, "entry_smoke_refund", {
		"player_id": "entry_smoke_player"
	}) as Dictionary
	_assert_eq(bool(refund.get("ok", false)), true, "funded paid entry refund succeeds")
	_assert_eq(bool(contest_state.call("is_entered", CONTEST_ID)), false, "paid refund clears local entry")
	var refunded_ledger: Dictionary = contest_state.call("debug_get_async_money_ledger_snapshot") as Dictionary
	var refund_rows: int = 0
	for transaction_any in refunded_ledger.get("transactions", []) as Array:
		if typeof(transaction_any) != TYPE_DICTIONARY:
			continue
		if str((transaction_any as Dictionary).get("transaction_type", "")) == "async_entry_refund_credit":
			refund_rows += 1
	_assert_eq(refund_rows, 1, "paid refund posts one refund transaction")

	var closed_preview: Dictionary = contest_state.call("preview_entry_requirements", CLOSED_CONTEST_ID, {
		"player_id": "entry_smoke_closed",
		"balance_cents": 500
	}) as Dictionary
	_assert_eq(bool(closed_preview.get("can_enter", true)), false, "closed contest blocks")
	_assert_eq(str(closed_preview.get("reason", "")), "contest_closed", "closed contest reason")

	if not _failed:
		print("ASYNC_PAID_CONTEST_ENTRY_CONTRACT_SMOKE: PASS")
		quit(0)

func _money_contest(id: String, family: String, price: int, start_ts: int, end_ts: int) -> ContestDef:
	var contest: ContestDef = ContestDef.new()
	contest.id = id
	contest.scope = "WEEKLY"
	contest.currency = "USD"
	contest.price = price
	contest.time_slice = "2026-W26"
	contest.mode = family
	contest.pool_type = "MONEY"
	contest.contest_family = family
	contest.schedule_kind = "SCHEDULED"
	contest.status = "OPEN"
	contest.name = "%s Entry Smoke" % family
	contest.start_ts = start_ts
	contest.end_ts = end_ts
	contest.published = true
	contest.map_ids = PackedStringArray([
		"MAP_nomansland__545__v01_top2_sides__1p",
		"MAP_nomansland__545__v17_four_corners_only__1p",
		"MAP_nomansland__444__v01_pinched_spine__1p",
		"MAP_race__SBASE__1p",
		"MAP_nomansland__545__v01_top2_sides__1p"
	])
	contest.normalize_definition()
	return contest

func _install_contest(contest_state: Node, contest: ContestDef) -> void:
	var current: Dictionary = contest_state.get("contests") as Dictionary
	current[contest.id] = contest
	contest_state.set("contests", current)

func _contains_contest_id(contests: Array, contest_id: String) -> bool:
	for contest_any in contests:
		if contest_any == null:
			continue
		if str(contest_any.get("id")) == contest_id:
			return true
	return false

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %s got %s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	_failed = true
	push_error("ASYNC_PAID_CONTEST_ENTRY_CONTRACT_SMOKE: %s" % message)
	quit(1)
