class_name ArenaControlsHintController
extends RefCounted

var _overlay: Control = null

func maybe_show_once(resolve_hud_root_cb: Callable, force_fullscreen_anchors_cb: Callable) -> void:
	if _has_seen_controls_hint():
		return
	ensure_overlay(resolve_hud_root_cb, force_fullscreen_anchors_cb)
	if _overlay == null:
		return
	_overlay.visible = true
	var parent_node: Node = _overlay.get_parent()
	if parent_node != null:
		parent_node.move_child(_overlay, parent_node.get_child_count() - 1)
	var got_it: Button = _overlay.get_node_or_null("Panel/VBox/GotItButton") as Button
	if got_it != null:
		got_it.grab_focus()

func ensure_overlay(resolve_hud_root_cb: Callable, force_fullscreen_anchors_cb: Callable) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	if not resolve_hud_root_cb.is_valid():
		return
	var hud_root: Control = resolve_hud_root_cb.call() as Control
	if hud_root == null:
		return
	var overlay: Control = hud_root.get_node_or_null("ControlsHintOverlay") as Control
	if overlay == null:
		overlay = _build_overlay()
		hud_root.add_child(overlay)
	elif overlay.get_parent() != hud_root:
		overlay.reparent(hud_root)
	if force_fullscreen_anchors_cb.is_valid():
		force_fullscreen_anchors_cb.call(overlay)
	overlay.z_as_relative = false
	overlay.z_index = 2050
	overlay.top_level = false
	var got_it: Button = overlay.get_node_or_null("Panel/VBox/GotItButton") as Button
	if got_it != null and not got_it.pressed.is_connected(_on_continue_pressed):
		got_it.pressed.connect(_on_continue_pressed)
	_overlay = overlay

func consume_dismiss_input(event: InputEvent, viewport: Viewport) -> bool:
	if not is_visible():
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			hide(true)
			if viewport != null:
				viewport.set_input_as_handled()
			return true
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			hide(true)
			if viewport != null:
				viewport.set_input_as_handled()
			return true
	return false

func hide(mark_seen: bool = false) -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var was_visible: bool = _overlay.visible
	_overlay.visible = false
	if mark_seen and was_visible:
		_mark_controls_hint_seen()

func is_visible() -> bool:
	return _overlay != null and is_instance_valid(_overlay) and _overlay.visible

func _build_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "ControlsHintOverlay"
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.layout_mode = 3
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.grow_horizontal = 2
	overlay.grow_vertical = 2
	var panel := Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -230.0
	panel.offset_top = -120.0
	panel.offset_right = 230.0
	panel.offset_bottom = 120.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 14.0
	vbox.offset_top = 14.0
	vbox.offset_right = -14.0
	vbox.offset_bottom = -14.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	var title := Label.new()
	title.name = "Title"
	title.text = "Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var body := Label.new()
	body.name = "Body"
	body.text = "Tap a hive to select.\nTap another hive to send units.\nDrag from hive to hive to build lanes."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)
	var got_it := Button.new()
	got_it.name = "GotItButton"
	got_it.text = "Got it"
	vbox.add_child(got_it)
	return overlay

func _on_continue_pressed() -> void:
	hide(true)

func _has_seen_controls_hint() -> bool:
	var profile_manager: Object = _get_profile_manager()
	if profile_manager != null and profile_manager.has_method("has_seen_controls_hint"):
		return bool(profile_manager.call("has_seen_controls_hint"))
	return false

func _mark_controls_hint_seen() -> void:
	var profile_manager: Object = _get_profile_manager()
	if profile_manager != null and profile_manager.has_method("mark_controls_hint_seen"):
		profile_manager.call("mark_controls_hint_seen")

func _get_profile_manager() -> Object:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null:
		return null
	if not (loop is SceneTree):
		return null
	var tree: SceneTree = loop as SceneTree
	if tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/ProfileManager")
