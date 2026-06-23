extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
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
	if not menu.has_method("_open_async_vs_lobby"):
		_fail("MainMenu missing async lobby opener")
		return
	var map_ids: PackedStringArray = PackedStringArray(["MAP_nomansland__545__v01_top2_sides__1p"])
	menu.call("_open_async_vs_lobby", "STAGE_RACE", 1, false, 5, {
		"contest_id": "SMOKE_USD_5_WEEKLY",
		"contest_scope": "WEEKLY",
		"map_ids": map_ids
	})
	await process_frame
	await process_frame
	_assert_eq(int((menu.get("_wallet_profile") as Dictionary).get("balance_usd", -1)), 5, "paid async entry debits wallet into escrow")
	var snapshot: Dictionary = menu.call("debug_get_async_money_ledger_snapshot") as Dictionary
	var entries: Dictionary = snapshot.get("entries", {}) as Dictionary
	if entries.size() != 1:
		_fail("expected one async escrow entry: %s" % str(snapshot))
		return
	var entry: Dictionary = {}
	for entry_any in entries.values():
		entry = entry_any as Dictionary
		break
	_assert_eq(str(entry.get("status", "")), "escrowed", "entry escrow status")
	_assert_eq(str(entry.get("contest_id", "")), "SMOKE_USD_5_WEEKLY", "entry uses resolved contest id")
	_assert_eq(int(entry.get("wager_cents", 0)), 500, "entry wager cents")
	var lobby: Node = menu.get("_vs_lobby") as Node
	if lobby == null:
		_fail("VS lobby did not open after escrow")
		return
	var context: Dictionary = lobby.call("_handshake_context") as Dictionary
	_assert_eq(int(context.get("wager_cents", 0)), 500, "lobby context carries wager cents")
	_assert_eq(bool(context.get("paid_entry", false)), true, "lobby context marks paid entry")
	_assert_eq(str(context.get("async_money_ledger_status", "")), "escrowed", "lobby context carries async escrow status")

	print("MAIN_MENU_ASYNC_MONEY_ESCROW_SMOKE: PASS")
	quit(0)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %s got %s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	push_error("MAIN_MENU_ASYNC_MONEY_ESCROW_SMOKE: %s" % message)
	quit(1)
