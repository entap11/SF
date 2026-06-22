extends SceneTree

class ShellStub:
	extends Node
	var applied_maps: Array[String] = []

	func _apply_map_then_start(map_path: String) -> void:
		applied_maps.append(map_path)

const ProgressiveConfigScript := preload("res://scripts/state/progressive_config.gd")
const ProgressiveRunStoreScript := preload("res://scripts/state/progressive_run_store.gd")

const SMOKE_SAVE_PATH: String = "user://progressive_route_smoke.json"

var _shell: ShellStub


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	_clear_launch_meta()
	_shell = ShellStub.new()
	_shell.name = "Shell"
	get_root().add_child(_shell)
	await process_frame
	var menu: Node = await _build_menu()
	if menu == null:
		return
	var store: RefCounted = ProgressiveRunStoreScript.new()
	store.save_path = SMOKE_SAVE_PATH
	menu.set("_progressive_run_store", store)
	var panel: Control = await _open_free_roll_panel(menu)
	if panel == null:
		menu.queue_free()
		return
	var button: Button = panel.get_node_or_null("EntryScroll/EntryBody/EntryCanvas/ProgressiveButton") as Button
	if button == null:
		_fail("missing Gauntlet button")
		return
	if button.tooltip_text != "GAUNTLET":
		_fail("Progressive button should be presented as Gauntlet")
		return
	if button.icon == null:
		_fail("Gauntlet button should use gauntlet art")
		return
	menu.set("_free_roll_press_block_until_msec", 0)
	menu.call("_on_free_roll_button_down", button)
	button.pressed.emit()
	await process_frame
	await process_frame
	if not _assert_progressive_launch():
		return
	var loaded: Dictionary = store.load_current_run()
	if loaded.is_empty():
		_fail("Progressive run should be persisted")
		return
	if str(loaded.get("run_id", "")) != str(get_meta("progressive_run_id", "")):
		_fail("persisted run id should match launch metadata")
		return
	store.clear_current_run()
	print("MAIN_MENU_PROGRESSIVE_ROUTE_SMOKE: PASS")
	quit(0)


func _build_menu() -> Node:
	var scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		_fail("failed to load MainMenu.tscn")
		return null
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame
	return menu


func _open_free_roll_panel(menu: Node) -> Control:
	if not menu.has_method("_open_free_roll_split"):
		_fail("free roll open method missing")
		return null
	menu.call("_open_free_roll_split")
	await process_frame
	await process_frame
	var panel: Control = menu.get("_entry_route_modal") as Control
	if panel == null or not panel.visible:
		_fail("free roll panel did not open")
		return null
	return panel


func _assert_progressive_launch() -> bool:
	if not bool(get_meta("start_game", false)):
		return _fail("Progressive did not start a run")
	if str(get_meta("vs_mode", "")) != ProgressiveConfigScript.MODE_ID:
		return _fail("Progressive launched wrong mode: %s" % str(get_meta("vs_mode", "")))
	if not bool(get_meta("vs_free_roll", false)):
		return _fail("Progressive should launch as free roll")
	if str(get_meta("vs_handshake_session_id", "not_empty")) != "":
		return _fail("Progressive should not set a handshake session")
	if str(get_meta("vs_cpu_tier", "")) != ProgressiveConfigScript.BOT_TIER_EASY:
		return _fail("Progressive first stage should use easy CPU tier")
	var stage_paths: Array = get_meta("vs_stage_map_paths", []) as Array
	if stage_paths.size() != 1 or str(stage_paths[0]).strip_edges().is_empty():
		return _fail("Progressive should launch exactly one current stage map")
	if _shell.applied_maps.is_empty() or _shell.applied_maps[_shell.applied_maps.size() - 1] != str(stage_paths[0]):
		return _fail("Progressive should apply the first stage map")
	var thresholds: Dictionary = get_meta("progressive_thresholds_ms", {}) as Dictionary
	if not (int(thresholds.get("four_star_ms", 0)) < int(thresholds.get("three_star_ms", 0)) and int(thresholds.get("three_star_ms", 0)) < int(thresholds.get("two_star_ms", 0))):
		return _fail("Progressive launch should carry ordered thresholds")
	if int(get_meta("progressive_max_stars", 0)) != ProgressiveConfigScript.DEFAULT_STAGE_COUNT * ProgressiveConfigScript.STAR_MAX:
		return _fail("Progressive max stars should match default stage plan")
	if int(get_meta("progressive_bot_attack_grace_ms", 0)) != ProgressiveConfigScript.BOT_ATTACK_GRACE_MS:
		return _fail("Progressive should launch with bot attack grace metadata")
	if int(get_meta("progressive_human_owner_id", 0)) != ProgressiveConfigScript.HUMAN_OWNER_ID:
		return _fail("Progressive should launch with human owner metadata")
	if bool(get_meta("progressive_bot_attack_grace_broken", true)):
		return _fail("Progressive should launch with bot attack grace unbroken")
	return true


func _clear_launch_meta() -> void:
	for key in [
		"start_game",
		"vs_mode",
		"vs_free_roll",
		"vs_stage_map_paths",
		"vs_handshake_session_id",
		"vs_cpu_style",
		"vs_cpu_tier",
		"progressive_run_id",
		"progressive_stage_plan",
		"progressive_stage_index",
		"progressive_stage_number",
		"progressive_thresholds_ms",
		"progressive_bot_attack_grace_ms",
		"progressive_human_owner_id",
		"progressive_bot_attack_grace_broken",
		"progressive_max_stars"
	]:
		if has_meta(key):
			remove_meta(key)


func _fail(message: String) -> bool:
	push_error("MAIN_MENU_PROGRESSIVE_ROUTE_SMOKE: %s" % message)
	quit(1)
	return false
