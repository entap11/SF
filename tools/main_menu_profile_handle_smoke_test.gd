extends SceneTree

const MAIN_MENU_SCENE_PATH: String = "res://scenes/MainMenu.tscn"

var _failed: bool = false

func _initialize() -> void:
	await _run()
	quit(1 if _failed else 0)

func _run() -> void:
	var profile_manager: Node = root.get_node_or_null("ProfileManager")
	_expect(profile_manager != null, "ProfileManager autoload should exist")
	if _failed:
		return
	if profile_manager.has_method("ensure_loaded"):
		profile_manager.call("ensure_loaded")
	var handle: String = str(profile_manager.call("get_display_name")).strip_edges()
	if handle.is_empty():
		handle = "Player"
	var scene: PackedScene = load(MAIN_MENU_SCENE_PATH) as PackedScene
	_expect(scene != null, "main menu scene should load")
	if _failed:
		return
	var menu: Control = scene.instantiate() as Control
	_expect(menu != null, "main menu scene should instantiate as Control")
	if _failed:
		return
	root.add_child(menu)
	await process_frame
	await process_frame
	var welcome_label: Label = menu.get_node_or_null("TopBar/WelcomeHandleLabel") as Label
	var dash_label: Label = menu.get_node_or_null("DashPanel/DashRoot/DashHandleLabel") as Label
	_expect(welcome_label != null, "welcome handle label should exist")
	_expect(dash_label != null, "dash handle label should exist")
	if _failed:
		return
	_expect(welcome_label.text == "Welcome %s" % handle, "welcome label should use profile handle", {
		"expected": "Welcome %s" % handle,
		"actual": welcome_label.text
	})
	_expect(dash_label.text == handle, "dash label should use profile handle", {
		"expected": handle,
		"actual": dash_label.text
	})
	if not _failed:
		print("MAIN_MENU_PROFILE_HANDLE_SMOKE: PASS")

func _expect(condition: bool, message: String, details: Variant = null) -> void:
	if condition:
		return
	_failed = true
	if details == null:
		push_error("MAIN_MENU_PROFILE_HANDLE_SMOKE: %s" % message)
	else:
		push_error("MAIN_MENU_PROFILE_HANDLE_SMOKE: %s :: %s" % [message, str(details)])
