extends SceneTree

func _init() -> void:
	await process_frame
	var contest_state: Node = get_root().get_node_or_null("ContestState")
	if contest_state == null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: ContestState missing")
		quit(1)
		return
	_assert_scope_has_contests(contest_state, "WEEKLY")
	_assert_scope_has_contests(contest_state, "MONTHLY")
	await _assert_scope_routes_to_stage_race_lobby("WEEKLY")
	await _assert_scope_routes_to_stage_race_lobby("MONTHLY")
	await _assert_orphan_leaderboard_modal_is_closed()
	print("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: PASS")
	quit(0)

func _assert_scope_has_contests(contest_state: Node, scope: String) -> void:
	var contests: Array = contest_state.call("get_contests_by_scope", scope) as Array
	if contests.is_empty():
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: %s contests missing" % scope)
		quit(1)

func _assert_scope_routes_to_stage_race_lobby(scope: String) -> void:
	var time_puzzle_lobby_scene: PackedScene = load("res://scenes/ui/TimePuzzleLobby.tscn") as PackedScene
	if time_puzzle_lobby_scene == null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: TimePuzzleLobby scene missing")
		quit(1)
		return
	var lobby_any: Variant = time_puzzle_lobby_scene.instantiate()
	if not (lobby_any is TimePuzzleLobby):
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: lobby instantiate failed")
		quit(1)
		return
	var lobby: TimePuzzleLobby = lobby_any as TimePuzzleLobby
	get_root().add_child(lobby)
	await process_frame
	lobby.set_scope(scope)
	await process_frame
	var contest_list: VBoxContainer = lobby.get_node_or_null("Panel/VBox/ContestList") as VBoxContainer
	if contest_list == null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: contest list missing")
		quit(1)
		return
	var contest_button: Button = null
	for child in contest_list.get_children():
		if child is Button:
			contest_button = child as Button
			break
	if contest_button == null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: %s contest button missing" % scope)
		quit(1)
		return
	contest_button.pressed.emit()
	await process_frame
	var hub: ContestHub = _find_contest_hub(lobby)
	if hub == null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: %s contest hub missing" % scope)
		quit(1)
		return
	var play_button: Button = hub.get_node_or_null("Panel/VBox/StageRaceActions/StageRacePlay") as Button
	if play_button == null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: %s play button missing" % scope)
		quit(1)
		return
	play_button.pressed.emit()
	await process_frame
	var vs_lobby: Control = _find_descendant_by_name(hub, "VsLobby") as Control
	if vs_lobby == null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: %s did not open Stage Race VS lobby" % scope)
		quit(1)
		return
	var summary: Label = vs_lobby.get_node_or_null("Panel/VBox/Summary") as Label
	if summary == null or not summary.text.contains("Stage Race"):
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: %s VS lobby summary is not Stage Race" % scope)
		quit(1)
		return
	lobby.queue_free()
	await process_frame

func _assert_orphan_leaderboard_modal_is_closed() -> void:
	var main_menu_scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if main_menu_scene == null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: MainMenu scene missing")
		quit(1)
		return
	var menu: Node = main_menu_scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame
	if not menu.has_method("_open_async_stage_contest_leaderboard") or not menu.has_method("_open_stage_race_tournament_lobby"):
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: main menu routing methods missing")
		quit(1)
		return
	menu.call("_open_async_stage_contest_leaderboard", 3)
	await process_frame
	var modal: Control = menu.get("_entry_route_modal") as Control
	if modal == null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: leaderboard modal was not tracked")
		quit(1)
		return
	menu.call("_open_stage_race_tournament_lobby", "WEEKLY")
	await process_frame
	await process_frame
	var tracked_modal: Variant = menu.get("_entry_route_modal")
	if tracked_modal != null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: leaderboard modal remained tracked after tournament lobby opened")
		quit(1)
		return
	if menu.get_node_or_null("EntryRouteModal") != null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: orphan leaderboard modal remained under main menu")
		quit(1)
		return
	var lobby: Variant = menu.get("_time_puzzle_lobby")
	if lobby == null:
		push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: tournament lobby did not open")
		quit(1)
		return
	if lobby is TimePuzzleLobby:
		(lobby as TimePuzzleLobby).closed.emit()
		await process_frame
		await process_frame
		var async_panel: Control = menu.get_node_or_null("AsyncPanel") as Control
		if async_panel != null and async_panel.visible:
			push_error("TIME_PUZZLE_CONTEST_ROUTING_SMOKE: tournament lobby close reopened async panel without async origin")
			quit(1)
			return
	menu.queue_free()
	await process_frame

func _find_contest_hub(root: Node) -> ContestHub:
	if root == null:
		return null
	for child in root.get_children():
		if child is ContestHub:
			return child as ContestHub
		var found: ContestHub = _find_contest_hub(child)
		if found != null:
			return found
	return null

func _find_descendant_by_name(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	for child in root.get_children():
		if child.name == node_name:
			return child
		var found: Node = _find_descendant_by_name(child, node_name)
		if found != null:
			return found
	return null
