extends SceneTree

const TEST_VIEWPORT_SIZE := Vector2i(944, 2048)
const GUIDE_USER_PATH := "user://help/Swarmfront Quick Start Guide.pdf"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = TEST_VIEWPORT_SIZE
	await process_frame
	var scene := load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_GUIDE_BUTTON_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame

	var guide_tab: Button = menu.get_node_or_null("DashPanel/DashRoot/DashTabs/GuideTab") as Button
	if guide_tab == null:
		push_error("MAIN_MENU_GUIDE_BUTTON_SMOKE: Guide tab missing")
		quit(1)
		return
	guide_tab.pressed.emit()
	await process_frame
	await process_frame

	if not FileAccess.file_exists(GUIDE_USER_PATH):
		push_error("MAIN_MENU_GUIDE_BUTTON_SMOKE: guide PDF was not copied")
		quit(1)
		return
	var status_label: Label = menu.get_node_or_null("BottomBar/StatusLabel") as Label
	if status_label == null:
		push_error("MAIN_MENU_GUIDE_BUTTON_SMOKE: status label missing")
		quit(1)
		return
	if status_label.text == "Quick Start guide could not be opened.":
		push_error("MAIN_MENU_GUIDE_BUTTON_SMOKE: guide still reports open failure")
		quit(1)
		return
	if not status_label.text.contains("Quick Start guide opened"):
		push_error("MAIN_MENU_GUIDE_BUTTON_SMOKE: unexpected guide status: %s" % status_label.text)
		quit(1)
		return
	var dialog: AcceptDialog = menu.get("_beta_help_dialog") as AcceptDialog
	if OS.get_environment("SF_FORCE_GUIDE_DIALOG") == "1":
		if dialog == null or not dialog.visible:
			push_error("MAIN_MENU_GUIDE_BUTTON_SMOKE: forced guide dialog did not open")
			quit(1)
			return
		if not dialog.dialog_text.contains("Saved copy:"):
			push_error("MAIN_MENU_GUIDE_BUTTON_SMOKE: guide dialog missing saved-copy fallback")
			quit(1)
			return

	print("MAIN_MENU_GUIDE_BUTTON_SMOKE: PASS")
	quit(0)
