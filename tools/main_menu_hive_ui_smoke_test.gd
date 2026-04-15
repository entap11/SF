extends SceneTree

func _init() -> void:
	await process_frame
	var scene := load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_HIVE_UI_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	if menu.get_node_or_null("DashPanel/DashHivePanel") == null:
		push_error("MAIN_MENU_HIVE_UI_SMOKE: DashHivePanel missing")
		quit(1)
		return
	if menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow/HiveAbout") == null:
		push_error("MAIN_MENU_HIVE_UI_SMOKE: HiveAbout action missing")
		quit(1)
		return
	print("MAIN_MENU_HIVE_UI_SMOKE: PASS")
	quit(0)
