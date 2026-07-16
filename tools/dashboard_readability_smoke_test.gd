extends SceneTree

const GARAGE_SCENE_PATH: String = "res://scenes/ui/GaragePanel.tscn"
const BUFFS_SCENE_PATH: String = "res://scenes/ui/DashBuffsHero.tscn"
const ACHIEVEMENTS_SCENE_PATH: String = "res://scenes/ui/DashAchievementsHero.tscn"
const TEST_VIEWPORT_SIZE := Vector2i(944, 2048)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = TEST_VIEWPORT_SIZE
	await process_frame
	if not await _check_garage(GARAGE_SCENE_PATH):
		quit(1)
		return
	if not await _check_simple_hero(BUFFS_SCENE_PATH, "BUFFS"):
		quit(1)
		return
	if not await _check_simple_hero(ACHIEVEMENTS_SCENE_PATH, "ACHIEVEMENTS"):
		quit(1)
		return
	print("DASHBOARD_READABILITY_SMOKE: PASS")
	quit(0)

func _check_garage(scene_path: String) -> bool:
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		return _fail("Garage scene failed to load")
	var panel: Control = scene.instantiate() as Control
	root.add_child(panel)
	panel.size = Vector2(TEST_VIEWPORT_SIZE)
	await process_frame
	await process_frame
	var title: Label = panel.get_node_or_null("VBox/Body/CategoryPanel/CategoryVBox/Header/TitleBlock/Title") as Label
	if title == null or title.get_theme_font_size("font_size") < 52:
		return _fail("Garage title is below the portrait title floor")
	var category_header: Label = panel.get_node_or_null("VBox/Body/CategoryPanel/CategoryVBox/CategoryHeader") as Label
	if category_header == null or category_header.get_theme_font_size("font_size") < 34:
		return _fail("Garage section title is too small")
	var category_list: GridContainer = panel.get_node_or_null("VBox/Body/CategoryPanel/CategoryVBox/CategoryList") as GridContainer
	if category_list == null or category_list.get_child_count() < 7:
		return _fail("Garage category controls are missing")
	for child in category_list.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		if button.get_theme_font_size("font_size") < 28 or button.custom_minimum_size.y < 64.0:
			return _fail("Garage category is not readable/touchable: %s" % button.text)
	var selected_meta: Label = panel.get_node_or_null("VBox/Body/PreviewPanel/PreviewVBox/SelectedMeta") as Label
	if selected_meta == null or selected_meta.get_theme_font_size("font_size") < 28:
		return _fail("Garage selected-item metadata is too small")
	var selected_desc: Label = panel.get_node_or_null("VBox/Body/PreviewPanel/PreviewVBox/SelectedDesc") as Label
	var inventory_note: Label = panel.get_node_or_null("VBox/Body/InventoryPanel/InventoryVBox/InventoryNote") as Label
	if selected_desc == null or selected_desc.visible or inventory_note == null or inventory_note.visible:
		return _fail("Garage still exposes low-priority technical copy in the primary mobile view")
	panel.queue_free()
	await process_frame
	return true

func _check_simple_hero(scene_path: String, expected_title: String) -> bool:
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		return _fail("%s dashboard scene failed to load" % expected_title)
	var panel: Control = scene.instantiate() as Control
	root.add_child(panel)
	panel.size = Vector2(TEST_VIEWPORT_SIZE)
	await process_frame
	await process_frame
	var title: Label = panel.find_child("Title", true, false) as Label
	if title == null or title.text != expected_title or title.get_theme_font_size("font_size") < 52:
		return _fail("%s dashboard title is below the portrait title floor" % expected_title)
	for child in panel.find_children("*", "Label", true, false):
		var label: Label = child as Label
		if label != null and label.visible and not label.text.strip_edges().is_empty() and label.get_theme_font_size("font_size") < 28:
			return _fail("%s contains undersized visible copy: %s" % [expected_title, label.text])
	panel.queue_free()
	await process_frame
	return true

func _fail(message: String) -> bool:
	push_error("DASHBOARD_READABILITY_SMOKE: %s" % message)
	return false
