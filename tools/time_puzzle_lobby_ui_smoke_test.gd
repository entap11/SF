extends SceneTree

const TimePuzzleLobbyScene: PackedScene = preload("res://scenes/ui/TimePuzzleLobby.tscn")
const ContestHubScene: PackedScene = preload("res://scenes/ui/ContestHub.tscn")

func _init() -> void:
	var lobby_any: Variant = TimePuzzleLobbyScene.instantiate()
	if not (lobby_any is Control):
		push_error("TIME_PUZZLE_LOBBY_UI_SMOKE: lobby instantiate failed")
		quit(1)
		return
	var lobby: Control = lobby_any as Control
	get_root().add_child(lobby)
	await process_frame

	var title: Label = lobby.get_node_or_null("Panel/VBox/Header/Title") as Label
	var back: Button = lobby.get_node_or_null("Panel/VBox/Header/Back") as Button
	if title == null or title.text != "STAGE RACE TOURNAMENTS":
		push_error("TIME_PUZZLE_LOBBY_UI_SMOKE: readable title missing")
		quit(1)
		return
	if back == null or back.custom_minimum_size.y < 56.0:
		push_error("TIME_PUZZLE_LOBBY_UI_SMOKE: back button too small")
		quit(1)
		return
	if lobby.has_method("configure_entry"):
		lobby.call("configure_entry", true, 0)
	await process_frame
	var leaderboard_3: Button = _find_button_with_text(lobby, "LEADERBOARD 3 MAPS")
	var leaderboard_5: Button = _find_button_with_text(lobby, "LEADERBOARD 5 MAPS")
	var play_3: Button = _find_button_with_text(lobby, "PLAY 3 MAPS")
	var play_5: Button = _find_button_with_text(lobby, "PLAY 5 MAPS")
	if leaderboard_3 == null or leaderboard_3.custom_minimum_size.y < 68.0:
		push_error("TIME_PUZZLE_LOBBY_UI_SMOKE: free 3-map leaderboard button missing or too small")
		quit(1)
		return
	if leaderboard_5 == null or leaderboard_5.custom_minimum_size.y < 68.0:
		push_error("TIME_PUZZLE_LOBBY_UI_SMOKE: free 5-map leaderboard button missing or too small")
		quit(1)
		return
	if play_3 == null or play_3.custom_minimum_size.y < 68.0:
		push_error("TIME_PUZZLE_LOBBY_UI_SMOKE: free 3-map play button missing or too small")
		quit(1)
		return
	if play_5 == null or play_5.custom_minimum_size.y < 68.0:
		push_error("TIME_PUZZLE_LOBBY_UI_SMOKE: free 5-map play button missing or too small")
		quit(1)
		return

	var hub_any: Variant = ContestHubScene.instantiate()
	if not (hub_any is Control):
		push_error("TIME_PUZZLE_LOBBY_UI_SMOKE: hub instantiate failed")
		quit(1)
		return
	var hub: Control = hub_any as Control
	get_root().add_child(hub)
	await process_frame
	var play: Button = hub.get_node_or_null("Panel/VBox/StageRaceActions/StageRacePlay") as Button
	var hub_back: Button = hub.get_node_or_null("Panel/VBox/Header/Back") as Button
	if play == null or play.custom_minimum_size.y < 56.0:
		push_error("TIME_PUZZLE_LOBBY_UI_SMOKE: stage race play button too small")
		quit(1)
		return
	if hub_back == null or hub_back.custom_minimum_size.y < 56.0:
		push_error("TIME_PUZZLE_LOBBY_UI_SMOKE: hub back button too small")
		quit(1)
		return

	print("TIME_PUZZLE_LOBBY_UI_SMOKE: PASS")
	quit(0)

func _find_button_with_text(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text == text:
		return root as Button
	for child in root.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null
