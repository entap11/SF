extends SceneTree

class ShellStub:
	extends Node
	var applied_map: String = ""

	func _apply_map_then_start(map_path: String) -> void:
		applied_map = map_path

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var shell: ShellStub = ShellStub.new()
	shell.name = "Shell"
	get_root().add_child(shell)
	await process_frame
	var scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame
	if not menu.has_method("_open_stage_race_tournament_lobby"):
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: tournament lobby method missing")
		quit(1)
		return
	menu.call("_open_stage_race_tournament_lobby", "WEEKLY", false, 0)
	await process_frame
	var lobby: TimePuzzleLobby = menu.get("_time_puzzle_lobby") as TimePuzzleLobby
	if lobby == null or not lobby.visible:
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: tournament lobby did not open")
		quit(1)
		return
	var leaderboard_button: Button = _find_button_with_text(lobby, "LEADERBOARD 5 MAPS")
	if leaderboard_button == null:
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: 5-map leaderboard button missing")
		quit(1)
		return
	if _find_button_with_text(lobby, "LEADERBOARD 3 MAPS") == null:
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: 3-map leaderboard button missing")
		quit(1)
		return
	if _find_button_with_text(lobby, "PLAY 3 MAPS") == null or _find_button_with_text(lobby, "PLAY 5 MAPS") == null:
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: 3-map/5-map play buttons missing")
		quit(1)
		return
	leaderboard_button.pressed.emit()
	await process_frame
	var leaderboard: Control = menu.get("_entry_route_modal") as Control
	if leaderboard == null:
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: styled leaderboard did not open")
		quit(1)
		return
	var leaderboard_title: Label = leaderboard.get_node_or_null("EntryScroll/EntryBody/EntryTitle") as Label
	if leaderboard_title == null or not leaderboard_title.text.contains("STAGE CONTEST LEADERBOARD"):
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: leaderboard did not use styled stage contest board")
		quit(1)
		return
	var leaderboard_subtitle: Label = leaderboard.get_node_or_null("EntryScroll/EntryBody/EntrySubtitle") as Label
	if leaderboard_subtitle == null or not leaderboard_subtitle.text.contains("Free Roll") or leaderboard_subtitle.text.contains("$1"):
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: free leaderboard routed to paid contest: %s" % (leaderboard_subtitle.text if leaderboard_subtitle != null else "missing"))
		quit(1)
		return
	if _find_button_with_text(leaderboard, "PLAY") == null:
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: leaderboard play CTA missing")
		quit(1)
		return
	menu.call("_close_entry_route_modal")
	await process_frame
	if not menu.has_method("_start_free_stage_race_contest"):
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: free contest start method missing")
		quit(1)
		return
	menu.call("_start_free_stage_race_contest", "WEEKLY", 5)
	await process_frame
	if not has_meta("start_game") or str(get_meta("vs_mode", "")) != "STAGE_RACE":
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: direct free play launch did not set match metadata")
		quit(1)
		return
	if shell.applied_map.strip_edges().is_empty():
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: direct free play launch did not apply first map")
		quit(1)
		return
	var hidden_lobby: Control = menu.get("_vs_lobby") as Control
	if hidden_lobby != null and hidden_lobby.visible:
		push_error("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: direct free play exposed VS lobby")
		quit(1)
		return
	print("MAIN_MENU_STAGE_RACE_CHOICE_SMOKE: PASS")
	quit(0)

func _find_button_with_text(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text == text:
		return root as Button
	for child in root.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null
