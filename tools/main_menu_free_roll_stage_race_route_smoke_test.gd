extends SceneTree

class ShellStub:
	extends Node
	var applied_maps: Array[String] = []

	func _apply_map_then_start(map_path: String) -> void:
		applied_maps.append(map_path)

const ROUTES: Array[Dictionary] = [
	{"path": "EntryScroll/EntryBody/EntryCanvas/StageRace3Button", "maps": 3},
	{"path": "EntryScroll/EntryBody/EntryCanvas/StageRace5Button", "maps": 5}
]

var _shell: ShellStub

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_shell = ShellStub.new()
	_shell.name = "Shell"
	get_root().add_child(_shell)
	await process_frame
	for route in ROUTES:
		var expected_maps: int = int(route.get("maps", 0))
		_clear_launch_meta()
		var menu: Node = await _build_menu()
		if menu == null:
			return
		var panel: Control = await _open_free_roll_panel(menu)
		if panel == null:
			menu.queue_free()
			return
		var button_path: String = str(route.get("path", ""))
		var button: Button = panel.get_node_or_null(button_path) as Button
		if button == null:
			push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: missing %s" % button_path)
			menu.queue_free()
			quit(1)
			return
		menu.set("_free_roll_press_block_until_msec", 0)
		menu.call("_on_free_roll_button_down", button)
		button.pressed.emit()
		await process_frame
		await process_frame
		if not _assert_stage_race_launch(expected_maps):
			menu.queue_free()
			return
		menu.queue_free()
		await process_frame
	print("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: PASS")
	quit(0)

func _build_menu() -> Node:
	var scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return null
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame
	return menu

func _open_free_roll_panel(menu: Node) -> Control:
	if not menu.has_method("_open_free_roll_split"):
		push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: free roll open method missing")
		quit(1)
		return null
	menu.call("_open_free_roll_split")
	await process_frame
	await process_frame
	var panel: Control = menu.get("_entry_route_modal") as Control
	if panel == null or not panel.visible:
		push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: free roll panel did not open")
		quit(1)
		return null
	return panel

func _assert_stage_race_launch(expected_maps: int) -> bool:
	if not bool(get_meta("start_game", false)):
		push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: Stage Race %d-map did not start a run" % expected_maps)
		quit(1)
		return false
	if str(get_meta("vs_mode", "")) != "STAGE_RACE":
		push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: Stage Race %d-map launched wrong mode: %s" % [expected_maps, str(get_meta("vs_mode", ""))])
		quit(1)
		return false
	if not bool(get_meta("vs_free_roll", false)):
		push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: Stage Race %d-map did not preserve free roll" % expected_maps)
		quit(1)
		return false
	var stage_paths: Array = get_meta("vs_stage_map_paths", []) as Array
	if stage_paths.size() != expected_maps:
		push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: expected %d stage maps, got %d" % [expected_maps, stage_paths.size()])
		quit(1)
		return false
	if str(get_meta("contest_id", "")).strip_edges().is_empty():
		push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: Stage Race %d-map missing contest_id" % expected_maps)
		quit(1)
		return false
	if str(get_meta("contest_scope", "")).strip_edges().to_upper() != "WEEKLY":
		push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: Stage Race %d-map missing weekly contest scope" % expected_maps)
		quit(1)
		return false
	var map_ids_any: Variant = get_meta("map_ids", PackedStringArray())
	var map_id_count: int = 0
	if typeof(map_ids_any) == TYPE_PACKED_STRING_ARRAY:
		map_id_count = (map_ids_any as PackedStringArray).size()
	elif typeof(map_ids_any) == TYPE_ARRAY:
		map_id_count = (map_ids_any as Array).size()
	if map_id_count != expected_maps:
		push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: expected %d contest map ids, got %d" % [expected_maps, map_id_count])
		quit(1)
		return false
	if _shell.applied_maps.is_empty() or _shell.applied_maps[_shell.applied_maps.size() - 1].strip_edges().is_empty():
		push_error("MAIN_MENU_FREE_ROLL_STAGE_RACE_ROUTE_SMOKE: Stage Race %d-map did not apply first map" % expected_maps)
		quit(1)
		return false
	return true

func _clear_launch_meta() -> void:
	for key in [
		"start_game",
		"vs_mode",
		"vs_free_roll",
		"vs_stage_map_paths",
		"contest_id",
		"contest_scope",
		"map_ids"
	]:
		if has_meta(key):
			remove_meta(key)
