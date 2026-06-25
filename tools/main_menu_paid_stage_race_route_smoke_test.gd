extends SceneTree

class ShellStub:
	extends Node
	var applied_maps: Array[String] = []

	func _apply_map_then_start(map_path: String) -> void:
		applied_maps.append(map_path)

const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const DENOMINATIONS: Array[int] = [1, 2, 3, 5, 10, 15, 20, 50]
const SCOPES: Array[String] = ["WEEKLY", "MONTHLY"]
const MAP_COUNTS: Array[int] = [3, 5]

var _shell: ShellStub

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
	var handshake: Node = get_root().get_node_or_null("/root/VsHandshake")
	if handshake != null and handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	_shell = ShellStub.new()
	_shell.name = "Shell"
	get_root().add_child(_shell)
	await process_frame
	var menu: Node = await _build_menu()
	if menu == null:
		return
	_assert_buyin_buttons(menu, "weekly")
	_assert_buyin_buttons(menu, "monthly")
	menu.queue_free()
	await process_frame
	_clear_launch_meta()
	_shell.applied_maps.clear()
	menu = await _build_menu()
	if menu == null:
		return
	menu.call("_open_stage_race_tournament_lobby", "WEEKLY", true, 1)
	await process_frame
	await process_frame
	var lobby: Control = menu.get("_time_puzzle_lobby") as Control
	if lobby == null:
		_fail("weekly $1 paid Stage Race lobby did not open")
		return
	var play_3_button: Button = _find_button_with_text(lobby, "PLAY 3 MAPS")
	if play_3_button == null:
		_fail("weekly $1 paid Stage Race lobby missing PLAY 3 MAPS")
		return
	play_3_button.pressed.emit()
	await process_frame
	await process_frame
	if not _assert_paid_stage_race_launch("WEEKLY", 3, 1):
		menu.queue_free()
		return
	menu.queue_free()
	await process_frame
	for map_count in MAP_COUNTS:
		_clear_launch_meta()
		_shell.applied_maps.clear()
		menu = await _build_menu()
		if menu == null:
			return
		var mode_id: String = "STAGE_RACE_%d" % map_count
		menu.call("_on_async_mode_selected", mode_id, true, 20)
		await process_frame
		await process_frame
		if not _assert_paid_stage_race_launch("WEEKLY", map_count, 20):
			menu.queue_free()
			return
		menu.queue_free()
		await process_frame
	for scope in SCOPES:
		for map_count in MAP_COUNTS:
			for denomination in DENOMINATIONS:
				_clear_launch_meta()
				_shell.applied_maps.clear()
				menu = await _build_menu()
				if menu == null:
					return
				menu.call("_start_paid_stage_race_contest", scope, map_count, denomination)
				await process_frame
				await process_frame
				if not _assert_paid_stage_race_launch(scope, map_count, denomination):
					menu.queue_free()
					return
				menu.queue_free()
				await process_frame
	print("MAIN_MENU_PAID_STAGE_RACE_ROUTE_SMOKE: PASS")
	quit(0)

func _build_menu() -> Node:
	var scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_PAID_STAGE_RACE_ROUTE_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return null
	var menu: Node = scene.instantiate()
	menu.set("_dev_bypass_cash_balance", false)
	menu.set("_wallet_profile", {"balance_usd": 500})
	get_root().add_child(menu)
	await process_frame
	await process_frame
	return menu

func _assert_buyin_buttons(menu: Node, mode: String) -> void:
	menu.call("_sync_async_buyin_buttons", mode)
	var buttons_any: Variant = menu.call("_get_async_buyin_buttons", mode)
	if typeof(buttons_any) != TYPE_ARRAY:
		_fail("%s buy-in buttons did not return an array" % mode)
		return
	var buttons: Array = buttons_any as Array
	if buttons.size() < DENOMINATIONS.size():
		_fail("%s buy-in buttons expected at least %d got %d" % [mode, DENOMINATIONS.size(), buttons.size()])
		return
	for i in range(DENOMINATIONS.size()):
		var button: Button = buttons[i] as Button
		if button == null:
			_fail("%s buy-in button %d is null" % [mode, i])
			return
		var expected_amount: int = DENOMINATIONS[i]
		if str(button.tooltip_text).find("$%d" % expected_amount) < 0 and str(button.text).find("$%d" % expected_amount) < 0:
			_fail("%s buy-in button %d missing $%d label" % [mode, i, expected_amount])
			return

func _assert_paid_stage_race_launch(scope: String, expected_maps: int, denomination: int) -> bool:
	if not bool(get_meta("start_game", false)):
		_fail("%s $%d %d-map Stage Race did not start a run" % [scope, denomination, expected_maps])
		return false
	if str(get_meta("vs_mode", "")) != "STAGE_RACE":
		_fail("%s $%d %d-map launched wrong mode: %s" % [scope, denomination, expected_maps, str(get_meta("vs_mode", ""))])
		return false
	if bool(get_meta("vs_free_roll", true)):
		_fail("%s $%d %d-map incorrectly launched as free roll" % [scope, denomination, expected_maps])
		return false
	if not bool(get_meta("vs_paid_entry", false)):
		_fail("%s $%d %d-map did not mark paid entry" % [scope, denomination, expected_maps])
		return false
	if int(get_meta("vs_price_usd", 0)) != denomination:
		_fail("%s $%d %d-map price mismatch: %d" % [scope, denomination, expected_maps, int(get_meta("vs_price_usd", 0))])
		return false
	if int(get_meta("vs_wager_cents", 0)) != denomination * 100:
		_fail("%s $%d %d-map wager mismatch: %d" % [scope, denomination, expected_maps, int(get_meta("vs_wager_cents", 0))])
		return false
	var stage_paths: Array = get_meta("vs_stage_map_paths", []) as Array
	if stage_paths.size() != expected_maps:
		_fail("%s $%d expected %d stage maps, got %d" % [scope, denomination, expected_maps, stage_paths.size()])
		return false
	var contest_id: String = str(get_meta("contest_id", "")).strip_edges()
	var expected_prefix: String = "%s_USD_%d_" % [scope, denomination]
	if not contest_id.begins_with(expected_prefix):
		_fail("%s $%d contest id mismatch: %s" % [scope, denomination, contest_id])
		return false
	if str(get_meta("contest_scope", "")).strip_edges().to_upper() != scope:
		_fail("%s $%d missing contest scope: %s" % [scope, denomination, str(get_meta("contest_scope", ""))])
		return false
	var entry_id: String = str(get_meta("async_money_entry_id", "")).strip_edges()
	if entry_id.is_empty():
		_fail("%s $%d missing async money entry id" % [scope, denomination])
		return false
	if str(get_meta("async_money_contest_id", "")).strip_edges() != contest_id:
		_fail("%s $%d async money contest mismatch: %s vs %s" % [scope, denomination, str(get_meta("async_money_contest_id", "")), contest_id])
		return false
	if int(get_meta("async_money_balance_start_cents", 0)) != 50000:
		_fail("%s $%d missing starting wallet telemetry: %d" % [scope, denomination, int(get_meta("async_money_balance_start_cents", 0))])
		return false
	if int(get_meta("async_money_balance_after_entry_cents", 0)) != (500 - denomination) * 100:
		_fail("%s $%d after-entry wallet telemetry mismatch: %d" % [scope, denomination, int(get_meta("async_money_balance_after_entry_cents", 0))])
		return false
	if _shell.applied_maps.is_empty() or _shell.applied_maps[_shell.applied_maps.size() - 1].strip_edges().is_empty():
		_fail("%s $%d %d-map did not apply first map" % [scope, denomination, expected_maps])
		return false
	return true

func _clear_launch_meta() -> void:
	for key in [
		"start_game",
		"vs_mode",
		"vs_price_usd",
		"vs_wager_cents",
		"vs_paid_entry",
		"vs_free_roll",
		"vs_stage_map_paths",
		"contest_id",
		"contest_scope",
		"map_ids",
		"async_money_entry_id",
		"async_money_contest_id",
		"async_money_ledger_status",
		"async_money_pot_cents",
		"async_money_escrow_cents",
		"async_money_ledger_source",
		"async_money_balance_start_cents",
		"async_money_balance_after_entry_cents",
		"async_money_balance_finish_cents"
	]:
		if has_meta(key):
			remove_meta(key)

func _find_button_with_text(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text == text:
		return root as Button
	for child in root.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	push_error("MAIN_MENU_PAID_STAGE_RACE_ROUTE_SMOKE: %s" % message)
	quit(1)
