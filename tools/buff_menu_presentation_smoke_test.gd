extends SceneTree

const Catalog := preload("res://scripts/state/buff_catalog.gd")
const Copy := preload("res://scripts/ui/buff_ui_copy.gd")
var failures: Array[String] = []
var menu: Control

func _init() -> void:
	call_deferred("run")

func run() -> void:
	if not OS.get_user_data_dir().contains("SwarmfrontCampaignChecks-sf-menu-"):
		push_error("Use the isolated menu check runner")
		quit(2)
		return
	root.size = Vector2i(1080, 1920)
	var profile: Node = root.get_node("ProfileManager")
	profile.call("smoke_force_identity_state", "01900000-0000-7000-8000-000000000002", "ABC 124", "Buff Review", true, true)
	profile.call("mark_onboarding_complete")
	for buff: Dictionary in Catalog.list_all():
		check(not Copy.description(buff).is_empty(), "every tier has a player explanation")
		profile.call("grant_buff", buff["id"], 2, "isolated_visual_fixture")
	var inventory: Dictionary = profile.call("get_buff_inventory_snapshot")
	menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	(menu.get("menu_buffs_button") as Button).pressed.emit()
	await settle()
	var view: Node = menu.get_node("BuffMenuPresentation")
	for dimensions in [Vector2i(1080,1920), Vector2i(720,1280), Vector2i(1080,1500), Vector2i(944,2048)]:
		root.size = dimensions
		view.set("_section", "loadout")
		view.call("refresh")
		await settle()
		check_layout()
		await capture("loadout-%dx%d" % [dimensions.x, dimensions.y])
		view.set("_section", "store")
		view.call("refresh")
		menu.call("_set_buff_category_filter", "lane")
		menu.call("_set_selected_buff", "buff_treacherous_lane_classic", "library", -1)
		await settle()
		check_layout()
		await capture("store-%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1080,1920)
	for index in range(3):
		var tier: String = ["classic", "premium", "elite"][index]
		((view.get("_tiers") as HBoxContainer).get_child(index) as Button).pressed.emit()
		await settle()
		check(str(menu.get("_buff_selected_id")).ends_with(tier), "tier selection updates the selected duration and explanation")
		await capture("lane-" + tier)
	menu.call("_set_buff_mode", "async")
	await settle()
	check(str((menu.get("buffs_footer_label") as Label).text).contains("unused second"), "Async keeps its two-use explanation")
	await capture("async-store")
	check(profile.call("get_buff_inventory_snapshot") == inventory, "visual navigation cannot change inventory")
	(menu.get("dash_buffs_close") as Button).pressed.emit()
	await settle()
	check(not (menu.get("dash_buffs_panel") as Control).is_visible_in_tree(), "Back exits the buff screen")
	menu.queue_free()
	await process_frame
	await process_frame
	print("BUFF_MENU_PRESENTATION_SMOKE: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)

func check_layout() -> void:
	var back: Control = menu.get("dash_buffs_close")
	var body: Control = menu.get("buffs_top_row")
	check(root.get_visible_rect().encloses(back.get_global_rect()), "Back remains inside viewport")
	check(back.is_visible_in_tree() and (back as Button).get_theme_color("font_color").a > 0.9, "Back has visible text")
	check(body.get_global_rect().end.y <= back.get_global_rect().position.y, "content remains above Back")
	for property in ["buffs_loadout_panel", "buffs_library_panel"]:
		var panel: Control = menu.get(property)
		if panel.is_visible_in_tree():
			check(panel.size.x >= 800, "active section uses available phone width")
	var adapter: Node = menu.get_node("BuffMenuPresentation")
	var summary: Control = adapter.get("_summary")
	check(summary.get_global_rect().end.y <= body.get_global_rect().position.y, "effect explanation cannot be covered by the section below")
	if str(adapter.get("_section")) == "loadout":
		for button: Button in menu.get("buffs_slot_buttons"):
			if button.is_visible_in_tree():
				check(button.get_global_rect().end.y <= body.get_global_rect().end.y, "loadout stays inside content")
	else:
		var tier: String = adapter.get("_tier")
		var grid: Control = (menu.get("_buff_library_tier_grids") as Dictionary)[tier]
		var scroll: Control = grid.get_parent()
		check(scroll.size.y >= 148, "store has room for a full readable item")

func settle() -> void:
	for i in range(8):
		await process_frame

func capture(name: String) -> void:
	var output: String = OS.get_environment("SF_MENU_CAPTURE_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw(false)
	var metadata: Dictionary = {}
	for path in ["DashPanel/DashBuffsPanel/BuffsVBox/BuffsBody/BuffsBodyVBox/BuffExplanation", "DashPanel/DashBuffsPanel/BuffsVBox/BuffsClose"]:
		var control: Control = menu.get_node(path)
		metadata[path] = {"visible": control.is_visible_in_tree(), "rect": str(control.get_global_rect()), "text": control.get("text")}
	var file := FileAccess.open(output.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "  "))
	file.close()
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "native capture saved")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("BUFF_MENU: " + message)
