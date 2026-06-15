extends SceneTree

const TEST_VIEWPORT_SIZE := Vector2i(944, 2048)
const ICELAND_FONT_PATH := "res://assets/fonts/brand/Iceland/Iceland-Regular.ttf"
const HONEY_LETTERS_PATH := "res://assets/sprites/sf_skin_v1/honey_letters.png"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = TEST_VIEWPORT_SIZE
	await process_frame
	var scene := load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame
	if not menu.has_method("_open_battle_pass_panel"):
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: battle pass open method missing")
		quit(1)
		return
	menu.call("_open_battle_pass_panel")
	await process_frame
	await process_frame
	await process_frame

	var panel: Control = menu.get_node_or_null("BattlePassPanel") as Control
	if panel == null or not panel.visible:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: BattlePassPanel did not open")
		quit(1)
		return
	var viewport_size: Vector2 = get_root().get_visible_rect().size
	var panel_rect: Rect2 = panel.get_global_rect()
	if panel_rect.position.x < -0.5 or panel_rect.position.y < -0.5 or panel_rect.end.x > viewport_size.x + 0.5 or panel_rect.end.y > viewport_size.y + 0.5:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: battle pass panel is offscreen: %s viewport %s" % [panel_rect, viewport_size])
		quit(1)
		return
	if panel_rect.size.x < 860.0:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: battle pass panel is still too narrow: %.1f" % panel_rect.size.x)
		quit(1)
		return

	var title: Label = _find_label_with_text(panel, "BATTLE PASS")
	if title == null:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: title label missing")
		quit(1)
		return
	if title.get_theme_font_size("font_size") < 28:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: title font too small: %d" % title.get_theme_font_size("font_size"))
		quit(1)
		return
	if not _uses_iceland(title):
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: title is not using Iceland")
		quit(1)
		return

	var close_button: Button = _find_button_with_text(panel, "Close")
	if close_button == null:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: text close button missing")
		quit(1)
		return
	if close_button.icon != null:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: close button should not use the old image icon")
		quit(1)
		return
	if close_button.custom_minimum_size.y < 52.0:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: close button is too short: %.1f" % close_button.custom_minimum_size.y)
		quit(1)
		return
	if not _uses_iceland(close_button):
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: close button is not using Iceland")
		quit(1)
		return

	var progress_bar: ProgressBar = _find_progress_bar(panel)
	if progress_bar == null:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: progress bar missing")
		quit(1)
		return
	if not _uses_iceland(progress_bar):
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: progress percentage is not using Iceland")
		quit(1)
		return

	var first_level_label: Label = _find_label_with_text(panel, "LEVEL 001")
	if first_level_label == null:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: first level card missing")
		quit(1)
		return
	if first_level_label.get_theme_font_size("font_size") < 24:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: level font too small: %d" % first_level_label.get_theme_font_size("font_size"))
		quit(1)
		return
	if not _uses_iceland(first_level_label):
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: level label is not using Iceland")
		quit(1)
		return
	var level_card: Control = _nearest_panel(first_level_label)
	if level_card == null or level_card.custom_minimum_size.y > 560.0:
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: level card did not use compact mobile height")
		quit(1)
		return

	if _has_texture_path(panel, HONEY_LETTERS_PATH):
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: honey-letter reward image is still present")
		quit(1)
		return
	if not _all_text_controls_use_iceland(panel):
		push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: Battle Pass has a text control without Iceland font")
		quit(1)
		return

	print("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: PASS")
	quit(0)

func _find_label_with_text(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node as Label
	for child in node.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null

func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null

func _find_progress_bar(node: Node) -> ProgressBar:
	if node is ProgressBar:
		return node as ProgressBar
	for child in node.get_children():
		var found: ProgressBar = _find_progress_bar(child)
		if found != null:
			return found
	return null

func _nearest_panel(node: Node) -> Control:
	var parent: Node = node.get_parent()
	while parent != null:
		if parent is Panel:
			return parent as Control
		parent = parent.get_parent()
	return null

func _has_texture_path(node: Node, path: String) -> bool:
	if node is TextureRect:
		var tex: Texture2D = (node as TextureRect).texture
		if tex != null and tex.resource_path == path:
			return true
	for child in node.get_children():
		if _has_texture_path(child, path):
			return true
	return false

func _all_text_controls_use_iceland(node: Node) -> bool:
	if node is Label or node is Button:
		var control := node as Control
		if not _uses_iceland(control):
			push_error("MAIN_MENU_BATTLE_PASS_LAYOUT_SMOKE: non-Iceland text control %s" % control.get_path())
			return false
	for child in node.get_children():
		if not _all_text_controls_use_iceland(child):
			return false
	return true

func _uses_iceland(control: Control) -> bool:
	var font: Font = control.get_theme_font("font")
	return font != null and font.resource_path == ICELAND_FONT_PATH
