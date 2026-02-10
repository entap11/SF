extends Control
class_name PlayerBuffStrip

signal buff_drag_started(slot_index: int, buff_id: String)
signal buff_drop_requested(slot_index: int, screen_pos: Vector2, held_ms: int)
signal buff_drag_cancelled(slot_index: int, reason: String)

const SLOT_READY_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const SLOT_ACTIVE_COLOR: Color = Color(0.62, 1.0, 0.64, 1.0)
const SLOT_LOCKED_COLOR: Color = Color(0.33, 0.33, 0.38, 0.9)
const SLOT_USED_COLOR: Color = Color(0.48, 0.12, 0.12, 0.96)
const SLOT_ARMED_COLOR: Color = Color(1.0, 0.96, 0.68, 1.0)

const HOLD_TO_ARM_MS: int = 180
const DRAG_DEADZONE_PX: float = 18.0

@export var allow_tap_activation: bool = false
@export var require_hold_before_drag: bool = true

var _slots: Array[Panel] = []
var _name_labels: Array[Label] = []
var _meta_labels: Array[Label] = []
var _state_labels: Array[Label] = []
var _slot_snapshots: Array[Dictionary] = []

var _press_slot_index: int = -1
var _press_started_ms: int = 0
var _press_start_screen: Vector2 = Vector2.ZERO
var _drag_armed: bool = false
var _active_touch_id: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	_cache_slots()
	_ensure_slot_labels()
	_reset_interaction_state()
	_apply_empty_state()

func apply_snapshot(snapshot: Dictionary) -> void:
	var slots_active: int = int(snapshot.get("slots_active", 0))
	var slots_any: Variant = snapshot.get("slots", [])
	var slots: Array = slots_any if typeof(slots_any) == TYPE_ARRAY else []
	_slot_snapshots.clear()
	for i in range(_slots.size()):
		var slot_data: Dictionary = {}
		if i < slots.size() and typeof(slots[i]) == TYPE_DICTIONARY:
			slot_data = slots[i] as Dictionary
		slot_data["index"] = i
		slot_data["locked"] = bool(slot_data.get("locked", i >= slots_active))
		_slot_snapshots.append(slot_data)
		_apply_slot_visual(i, slot_data)

func _input(event: InputEvent) -> void:
	if _press_slot_index < 0:
		return
	if event is InputEventMouseMotion:
		_handle_pointer_motion(_viewport_pointer_pos())
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_handle_pointer_release(_viewport_pointer_pos())
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if _active_touch_id == sd.index:
			_handle_pointer_motion(sd.position)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if _active_touch_id == st.index and not st.pressed:
			_handle_pointer_release(st.position)

func _cache_slots() -> void:
	_slots.clear()
	for idx in range(1, 4):
		var path: String = "Center/SlotsRow/BuffSlot%d" % idx
		var slot: Panel = get_node_or_null(path) as Panel
		if slot == null:
			continue
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_gui_input.bind(idx - 1))
		_slots.append(slot)

func _ensure_slot_labels() -> void:
	_name_labels.clear()
	_meta_labels.clear()
	_state_labels.clear()
	for idx in range(_slots.size()):
		var slot: Panel = _slots[idx]
		var vbox: VBoxContainer = slot.get_node_or_null("SlotText") as VBoxContainer
		if vbox == null:
			vbox = VBoxContainer.new()
			vbox.name = "SlotText"
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.set_anchors_preset(Control.PRESET_FULL_RECT, true)
			vbox.offset_left = 8.0
			vbox.offset_top = 8.0
			vbox.offset_right = -8.0
			vbox.offset_bottom = -8.0
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			vbox.add_theme_constant_override("separation", 2)
			slot.add_child(vbox)
		var name_label: Label = vbox.get_node_or_null("Name") as Label
		if name_label == null:
			name_label = Label.new()
			name_label.name = "Name"
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_label.add_theme_font_size_override("font_size", 14)
			vbox.add_child(name_label)
		var meta_label: Label = vbox.get_node_or_null("Meta") as Label
		if meta_label == null:
			meta_label = Label.new()
			meta_label.name = "Meta"
			meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			meta_label.add_theme_font_size_override("font_size", 12)
			meta_label.modulate = Color(0.86, 0.90, 0.98, 0.95)
			vbox.add_child(meta_label)
		var state_label: Label = vbox.get_node_or_null("State") as Label
		if state_label == null:
			state_label = Label.new()
			state_label.name = "State"
			state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			state_label.add_theme_font_size_override("font_size", 12)
			state_label.modulate = Color(0.96, 0.96, 0.96, 0.92)
			vbox.add_child(state_label)
		_name_labels.append(name_label)
		_meta_labels.append(meta_label)
		_state_labels.append(state_label)

func _apply_empty_state() -> void:
	for i in range(_slots.size()):
		_apply_slot_visual(i, {
			"name": "Buff %d" % (i + 1),
			"tier": "classic",
			"locked": i >= 2,
			"active": false,
			"consumed": false
		})

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_try_begin_press(slot_index, _viewport_pointer_pos(), -1)
		else:
			_handle_pointer_release(_viewport_pointer_pos())
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_try_begin_press(slot_index, st.position, st.index)
		elif _active_touch_id == st.index:
			_handle_pointer_release(st.position)

func _try_begin_press(slot_index: int, screen_pos: Vector2, touch_id: int) -> void:
	if not _slot_can_arm(slot_index):
		return
	_press_slot_index = slot_index
	_press_started_ms = Time.get_ticks_msec()
	_press_start_screen = screen_pos
	_drag_armed = false
	_active_touch_id = touch_id

func _handle_pointer_motion(screen_pos: Vector2) -> void:
	if _press_slot_index < 0:
		return
	if _drag_armed:
		return
	var held_ms: int = Time.get_ticks_msec() - _press_started_ms
	if require_hold_before_drag and held_ms < HOLD_TO_ARM_MS:
		return
	if screen_pos.distance_to(_press_start_screen) < DRAG_DEADZONE_PX:
		return
	_drag_armed = true
	_apply_slot_armed_visual(_press_slot_index)
	var slot_data: Dictionary = _slot_snapshot(_press_slot_index)
	emit_signal("buff_drag_started", _press_slot_index, str(slot_data.get("id", "")))

func _handle_pointer_release(screen_pos: Vector2) -> void:
	if _press_slot_index < 0:
		return
	var slot_index: int = _press_slot_index
	var held_ms: int = Time.get_ticks_msec() - _press_started_ms
	if _drag_armed:
		emit_signal("buff_drop_requested", slot_index, screen_pos, held_ms)
	elif allow_tap_activation and _slot_can_arm(slot_index):
		emit_signal("buff_drop_requested", slot_index, screen_pos, held_ms)
	else:
		emit_signal("buff_drag_cancelled", slot_index, "tap_ignored")
	_reset_interaction_state()
	var slot_data: Dictionary = _slot_snapshot(slot_index)
	_apply_slot_visual(slot_index, slot_data)

func _slot_can_arm(slot_index: int) -> bool:
	var slot_data: Dictionary = _slot_snapshot(slot_index)
	if slot_data.is_empty():
		return false
	var locked: bool = bool(slot_data.get("locked", true))
	var active: bool = bool(slot_data.get("active", false))
	var consumed: bool = bool(slot_data.get("consumed", false))
	return not locked and not active and not consumed

func _slot_snapshot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= _slot_snapshots.size():
		return {}
	return _slot_snapshots[slot_index]

func _apply_slot_armed_visual(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	_slots[slot_index].self_modulate = SLOT_ARMED_COLOR
	if slot_index >= 0 and slot_index < _state_labels.size():
		_state_labels[slot_index].text = "DROP TO APPLY"

func _apply_slot_visual(slot_index: int, slot_data: Dictionary) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	var name_text: String = str(slot_data.get("name", "Buff %d" % (slot_index + 1)))
	var tier_text: String = str(slot_data.get("tier", "classic")).to_upper()
	var locked: bool = bool(slot_data.get("locked", false))
	var active: bool = bool(slot_data.get("active", false))
	var consumed: bool = bool(slot_data.get("consumed", false))
	var remaining_ms: int = max(0, int(slot_data.get("remaining_ms", 0)))
	var state_text: String = "READY"
	var meta_text: String = tier_text
	var tint: Color = SLOT_READY_COLOR
	if locked:
		state_text = "LOCKED"
		meta_text = "OVERTIME"
		tint = SLOT_LOCKED_COLOR
	elif active:
		state_text = "ACTIVE"
		meta_text = "%.1fs" % (float(remaining_ms) / 1000.0)
		tint = SLOT_ACTIVE_COLOR
	elif consumed:
		state_text = "USED"
		meta_text = "SPENT"
		tint = SLOT_USED_COLOR
	_slots[slot_index].self_modulate = tint
	if slot_index >= 0 and slot_index < _name_labels.size():
		_name_labels[slot_index].text = name_text
	if slot_index >= 0 and slot_index < _meta_labels.size():
		_meta_labels[slot_index].text = meta_text
	if slot_index >= 0 and slot_index < _state_labels.size():
		_state_labels[slot_index].text = state_text

func _viewport_pointer_pos() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_mouse_position()

func _reset_interaction_state() -> void:
	_press_slot_index = -1
	_press_started_ms = 0
	_press_start_screen = Vector2.ZERO
	_drag_armed = false
	_active_touch_id = -1
