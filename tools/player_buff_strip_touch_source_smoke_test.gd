extends SceneTree

const StripScript := preload("res://scripts/ui/player_buff_strip.gd")

var _failed: bool = false
var _captures: Array[Dictionary] = []
var _moves: Array[Dictionary] = []
var _releases: Array[Dictionary] = []
var _cancellations: Array[Dictionary] = []


func _init() -> void:
	var strip: Control = StripScript.new()
	strip.name = "PlayerBuffStripTouchSourceSmoke"
	strip.position = Vector2(80.0, 80.0)
	strip.size = Vector2(520.0, 140.0)
	var center := MarginContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip.add_child(center)
	var row := HBoxContainer.new()
	row.name = "SlotsRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	center.add_child(row)
	for i in range(3):
		var slot := Panel.new()
		slot.name = "BuffSlot%d" % (i + 1)
		slot.custom_minimum_size = Vector2(96.0, 96.0)
		row.add_child(slot)
	root.add_child(strip)
	await process_frame
	strip.call("apply_snapshot", {
		"pid": 1,
		"slots_active": 3,
		"slots": [
			{"id": "buff_swarm_damage_classic", "uses_remaining": 1, "uses_total": 1},
			{"id": "buff_freeze_lane_classic", "uses_remaining": 1, "uses_total": 1},
			{"id": "buff_unit_speed_classic", "uses_remaining": 1, "uses_total": 1}
		]
	})
	strip.connect("buff_press_captured", func(slot_index, buff_id, pointer_kind, pointer_id, root_screen_pos):
		var session_id: int = 101 if str(pointer_kind) == "touch" else 202
		_captures.append({
			"slot_index": int(slot_index),
			"buff_id": str(buff_id),
			"pointer_kind": str(pointer_kind),
			"pointer_id": int(pointer_id),
			"root_screen_pos": root_screen_pos,
			"pointer_session_id": session_id
		})
		strip.call("bind_pointer_session", pointer_kind, pointer_id, session_id)
	)
	strip.connect("buff_pointer_moved", func(pointer_kind, pointer_id, pointer_session_id, root_screen_pos):
		_moves.append({
			"pointer_kind": str(pointer_kind),
			"pointer_id": int(pointer_id),
			"pointer_session_id": int(pointer_session_id),
			"root_screen_pos": root_screen_pos
		})
	)
	strip.connect("buff_pointer_released", func(pointer_kind, pointer_id, pointer_session_id, root_screen_pos):
		_releases.append({
			"pointer_kind": str(pointer_kind),
			"pointer_id": int(pointer_id),
			"pointer_session_id": int(pointer_session_id),
			"root_screen_pos": root_screen_pos
		})
	)
	strip.connect("buff_pointer_cancelled", func(pointer_kind, pointer_id, pointer_session_id, reason):
		_cancellations.append({
			"pointer_kind": str(pointer_kind),
			"pointer_id": int(pointer_id),
			"pointer_session_id": int(pointer_session_id),
			"reason": str(reason)
		})
	)

	var slot: Control = strip.get_node("Center/SlotsRow/BuffSlot1") as Control
	var slot_center: Vector2 = slot.get_global_rect().get_center()
	var icon: TextureRect = slot.get_node("BuffIcon") as TextureRect
	var icon_parent: Node = icon.get_parent()
	var icon_position: Vector2 = icon.position

	var touch_down: InputEventScreenTouch = _touch_event(5, true, slot.size * 0.5)
	strip.call("_on_slot_gui_input", touch_down, 0)
	_expect(_captures.size() == 1, "real screen-touch press should emit one capture")
	if not _captures.is_empty():
		_expect(str(_captures[0].get("pointer_kind", "")) == "touch" and int(_captures[0].get("pointer_id", -1)) == 5, "capture should retain initiating touch identity")
		var captured_pos: Vector2 = _captures[0].get("root_screen_pos", Vector2.INF) as Vector2
		_expect(captured_pos.distance_to(slot_center) <= 1.0, "GUI-local touch should be converted back to root-screen coordinates")

	strip.call("_input", _drag_event(6, slot_center + Vector2(80.0, 0.0)))
	_expect(_moves.is_empty(), "foreign screen drag must not emit movement")
	strip.call("_input", _drag_event(5, slot_center + Vector2(30.0, 0.0)))
	_expect(_moves.size() == 1 and int(_moves[0].get("pointer_session_id", 0)) == 101, "initiating touch should emit continuous movement with generation")
	strip.call("_input", _touch_event(6, false, slot_center))
	_expect(_releases.is_empty(), "foreign release must not release the initiating touch")
	strip.call("_input", _touch_event(5, false, slot_center + Vector2(30.0, 0.0)))
	_expect(_releases.size() == 1 and int(_releases[0].get("pointer_session_id", 0)) == 101, "initiating release should emit exactly once")
	strip.call("_input", _touch_event(5, false, slot_center))
	_expect(_releases.size() == 1, "duplicate release after cleanup must be ignored")
	_expect(icon.get_parent() == icon_parent and icon.position == icon_position, "drag lifecycle must not move or remove source inventory icon node")
	strip.call("_on_slot_gui_input", _touch_event(9, true, slot.size * 0.5), 0)
	var interrupted: InputEventScreenTouch = _touch_event(9, false, slot_center)
	interrupted.canceled = true
	strip.call("_input", interrupted)
	_expect(_cancellations.size() == 1 and str(_cancellations[0].get("reason", "")) == "touch_cancelled", "OS-cancelled touch should cancel rather than submit")
	_expect(_releases.size() == 1, "OS-cancelled touch must not emit a release")

	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	mouse_down.position = slot.size * 0.5
	mouse_down.global_position = slot_center
	strip.call("_on_slot_gui_input", mouse_down, 0)
	_expect(_captures.size() == 3, "editor mouse press should adapt into the same capture source")
	if _captures.size() >= 3:
		_expect(str(_captures[2].get("pointer_kind", "")) == "mouse" and int(_captures[2].get("pointer_id", -1)) == 0, "mouse adapter should use explicit synthetic identity")
	var mouse_move := InputEventMouseMotion.new()
	mouse_move.position = slot_center + Vector2(40.0, 0.0)
	mouse_move.global_position = mouse_move.position
	strip.call("_input", mouse_move)
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	mouse_up.position = mouse_move.position
	mouse_up.global_position = mouse_move.position
	strip.call("_input", mouse_up)
	_expect(_moves.size() == 2 and str(_moves[1].get("pointer_kind", "")) == "mouse", "mouse movement should use the same raw lifecycle")
	_expect(_releases.size() == 2 and int(_releases[1].get("pointer_session_id", 0)) == 202, "mouse release should use the same generation-bound release")

	var source: String = FileAccess.get_file_as_string("res://scripts/ui/player_buff_strip.gd")
	_expect(not source.contains("DROP TO APPLY"), "production drag source must not display instructional copy")
	_expect(not source.contains("HOLD_TO_ARM_MS"), "production drag should be slop-owned by Shell, not hold-timed in the strip")

	strip.call("_on_slot_gui_input", _touch_event(10, true, slot.size * 0.5), 0)
	strip.free()
	_expect(_cancellations.size() == 2 and str(_cancellations[1].get("reason", "")) == "strip_scene_exit", "strip scene exit should cancel active presentation state")
	if not _failed:
		print("PLAYER_BUFF_STRIP_TOUCH_SOURCE_SMOKE: PASS")
	quit(1 if _failed else 0)


func _touch_event(index: int, pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	return event


func _drag_event(index: int, position: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PLAYER_BUFF_STRIP_TOUCH_SOURCE_SMOKE: %s" % message)
