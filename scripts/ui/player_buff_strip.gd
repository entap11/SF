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
const TEAM_COLOR_P1: Color = Color(0.85, 0.72, 0.12, 1.0)
const TEAM_COLOR_P2: Color = Color(0.95, 0.20, 0.20, 1.0)
const TEAM_COLOR_P3: Color = Color(0.25, 0.95, 0.35, 1.0)
const TEAM_COLOR_P4: Color = Color(0.15, 0.45, 0.95, 1.0)
const TIER_DURATION_MS := {
	"classic": 10000,
	"premium": 15000,
	"elite": 20000
}

const HOLD_TO_ARM_MS: int = 180
const DRAG_DEADZONE_PX: float = 18.0

@export var allow_tap_activation: bool = false
@export var require_hold_before_drag: bool = true

var _slots: Array[Panel] = []
var _name_labels: Array[Label] = []
var _meta_labels: Array[Label] = []
var _state_labels: Array[Label] = []
var _fill_overlays: Array[Panel] = []
var _countdown_labels: Array[Label] = []
var _slot_snapshots: Array[Dictionary] = []
var _slots_row: HBoxContainer = null
var _snapshot_pid: int = 1
var _ui_remaining_ms: Array[int] = []

var _press_slot_index: int = -1
var _press_started_ms: int = 0
var _press_start_screen: Vector2 = Vector2.ZERO
var _drag_armed: bool = false
var _active_touch_id: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	set_process_input(true)
	_cache_slots()
	_ui_remaining_ms.resize(_slots.size())
	_configure_layout_for_thumb_access()
	_ensure_slot_labels()
	_ensure_slot_runtime_fx()
	_reset_interaction_state()
	_apply_empty_state()

func _process(delta: float) -> void:
	if _slot_snapshots.is_empty() or _ui_remaining_ms.is_empty():
		return
	var step_ms: int = int(round(maxf(0.0, delta) * 1000.0))
	if step_ms <= 0:
		return
	var count: int = mini(_slot_snapshots.size(), _ui_remaining_ms.size())
	for i in range(count):
		var slot_data: Dictionary = _slot_snapshot(i)
		if slot_data.is_empty() or not bool(slot_data.get("active", false)):
			continue
		_ui_remaining_ms[i] = max(0, _ui_remaining_ms[i] - step_ms)
		_update_active_slot_runtime_fx(i, slot_data)

func apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot_pid = int(snapshot.get("pid", _snapshot_pid))
	var slots_active: int = int(snapshot.get("slots_active", 0))
	var slots_any: Variant = snapshot.get("slots", [])
	var slots: Array = slots_any if typeof(slots_any) == TYPE_ARRAY else []
	_slot_snapshots.clear()
	_ui_remaining_ms.resize(_slots.size())
	for i in range(_slots.size()):
		var slot_data: Dictionary = {}
		if i < slots.size() and typeof(slots[i]) == TYPE_DICTIONARY:
			slot_data = slots[i] as Dictionary
		slot_data["index"] = i
		slot_data["locked"] = bool(slot_data.get("locked", i >= slots_active))
		if bool(slot_data.get("active", false)):
			_ui_remaining_ms[i] = max(0, int(slot_data.get("remaining_ms", 0)))
		else:
			_ui_remaining_ms[i] = 0
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
	_slots_row = get_node_or_null("Center/SlotsRow") as HBoxContainer
	for idx in range(1, 4):
		var path: String = "Center/SlotsRow/BuffSlot%d" % idx
		var slot: Panel = get_node_or_null(path) as Panel
		if slot == null:
			continue
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_gui_input.bind(idx - 1))
		_slots.append(slot)

func _configure_layout_for_thumb_access() -> void:
	if _slots_row == null:
		return
	# Keep the authored spacing, but dock the strip to the right edge and make slot 1 closest to thumb.
	_slots_row.alignment = BoxContainer.ALIGNMENT_END
	var visual_order: Array[StringName] = [&"BuffSlot3", &"BuffSlot2", &"BuffSlot1"]
	var insert_at: int = 0
	for node_name in visual_order:
		var slot_node: Node = _slots_row.get_node_or_null(NodePath(str(node_name)))
		if slot_node == null:
			continue
		_slots_row.move_child(slot_node, insert_at)
		insert_at += 1

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

func _ensure_slot_runtime_fx() -> void:
	_fill_overlays.clear()
	_countdown_labels.clear()
	for idx in range(_slots.size()):
		var slot: Panel = _slots[idx]
		slot.clip_contents = true
		var fill: Panel = slot.get_node_or_null("ActiveFill") as Panel
		if fill == null:
			fill = Panel.new()
			fill.name = "ActiveFill"
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fill.set_anchors_preset(Control.PRESET_FULL_RECT, true)
			var slot_style: StyleBoxFlat = slot.get_theme_stylebox("panel") as StyleBoxFlat
			if slot_style != null:
				var fill_style: StyleBoxFlat = slot_style.duplicate() as StyleBoxFlat
				fill_style.border_width_left = 0
				fill_style.border_width_top = 0
				fill_style.border_width_right = 0
				fill_style.border_width_bottom = 0
				fill_style.shadow_size = 0
				fill_style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
				fill_style.bg_color = Color(1.0, 1.0, 1.0, 0.58)
				fill.add_theme_stylebox_override("panel", fill_style)
			slot.add_child(fill)
			slot.move_child(fill, 0)
		var countdown: Label = slot.get_node_or_null("Countdown") as Label
		if countdown == null:
			countdown = Label.new()
			countdown.name = "Countdown"
			countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
			countdown.set_anchors_preset(Control.PRESET_FULL_RECT, true)
			countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			countdown.add_theme_font_size_override("font_size", 28)
			countdown.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))
			countdown.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
			countdown.add_theme_constant_override("outline_size", 2)
			slot.add_child(countdown)
		fill.visible = false
		countdown.visible = false
		_fill_overlays.append(fill)
		_countdown_labels.append(countdown)

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
	_set_slot_active_fill(slot_index, 0.0, Color(1.0, 1.0, 1.0, 0.0))
	_set_slot_countdown(slot_index, "", false)
	if slot_index >= 0 and slot_index < _state_labels.size():
		_name_labels[slot_index].visible = true
		_meta_labels[slot_index].visible = true
		_state_labels[slot_index].visible = true
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
	var show_detail_labels: bool = true
	var active_fill_pct: float = 0.0
	var countdown_text: String = ""
	if locked:
		state_text = "LOCKED"
		meta_text = "OVERTIME"
		tint = SLOT_LOCKED_COLOR
	elif active:
		state_text = "ACTIVE"
		meta_text = ""
		tint = SLOT_ACTIVE_COLOR
		show_detail_labels = false
		remaining_ms = _active_remaining_ms(slot_index, slot_data)
		var tier_key: String = tier_text.to_lower()
		var duration_ms: int = int(TIER_DURATION_MS.get(tier_key, TIER_DURATION_MS["classic"]))
		active_fill_pct = clampf(float(remaining_ms) / float(maxi(1, duration_ms)), 0.0, 1.0)
		countdown_text = "%.1f" % (float(remaining_ms) / 1000.0)
	elif consumed:
		state_text = "USED"
		meta_text = "SPENT"
		tint = SLOT_USED_COLOR
	_slots[slot_index].self_modulate = tint
	_set_slot_active_fill(slot_index, active_fill_pct, _team_color_for_pid(_snapshot_pid))
	_set_slot_countdown(slot_index, countdown_text, active)
	if slot_index >= 0 and slot_index < _name_labels.size():
		_name_labels[slot_index].visible = show_detail_labels
		_name_labels[slot_index].text = name_text
	if slot_index >= 0 and slot_index < _meta_labels.size():
		_meta_labels[slot_index].visible = show_detail_labels
		_meta_labels[slot_index].text = meta_text
	if slot_index >= 0 and slot_index < _state_labels.size():
		_state_labels[slot_index].visible = show_detail_labels
		_state_labels[slot_index].text = state_text

func _active_remaining_ms(slot_index: int, slot_data: Dictionary) -> int:
	var snapshot_remaining: int = max(0, int(slot_data.get("remaining_ms", 0)))
	if slot_index < 0 or slot_index >= _ui_remaining_ms.size():
		return snapshot_remaining
	var ui_remaining: int = max(0, int(_ui_remaining_ms[slot_index]))
	return ui_remaining if ui_remaining > 0 else snapshot_remaining

func _update_active_slot_runtime_fx(slot_index: int, slot_data: Dictionary) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	if not bool(slot_data.get("active", false)):
		return
	var tier_key: String = str(slot_data.get("tier", "classic")).to_lower()
	var duration_ms: int = int(TIER_DURATION_MS.get(tier_key, TIER_DURATION_MS["classic"]))
	var remaining_ms: int = _active_remaining_ms(slot_index, slot_data)
	var fill_pct: float = clampf(float(remaining_ms) / float(maxi(1, duration_ms)), 0.0, 1.0)
	_set_slot_active_fill(slot_index, fill_pct, _team_color_for_pid(_snapshot_pid))
	_set_slot_countdown(slot_index, "%.1f" % (float(remaining_ms) / 1000.0), remaining_ms > 0)

func _set_slot_active_fill(slot_index: int, fill_pct: float, team_color: Color) -> void:
	if slot_index < 0 or slot_index >= _fill_overlays.size() or slot_index >= _slots.size():
		return
	var fill: Panel = _fill_overlays[slot_index]
	if fill == null:
		return
	var pct: float = clampf(fill_pct, 0.0, 1.0)
	if pct <= 0.0:
		fill.visible = false
		return
	fill.visible = true
	var fill_style: StyleBoxFlat = fill.get_theme_stylebox("panel") as StyleBoxFlat
	if fill_style != null:
		fill_style.bg_color = Color(team_color.r, team_color.g, team_color.b, 0.58)
	var slot_h: float = maxf(1.0, _slots[slot_index].size.y)
	fill.offset_top = slot_h * (1.0 - pct)
	fill.offset_bottom = 0.0
	fill.offset_left = 0.0
	fill.offset_right = 0.0

func _set_slot_countdown(slot_index: int, text: String, visible: bool) -> void:
	if slot_index < 0 or slot_index >= _countdown_labels.size():
		return
	var label: Label = _countdown_labels[slot_index]
	if label == null:
		return
	label.visible = visible
	label.text = text

func _team_color_for_pid(pid: int) -> Color:
	match int(pid):
		1:
			return TEAM_COLOR_P1
		2:
			return TEAM_COLOR_P2
		3:
			return TEAM_COLOR_P3
		4:
			return TEAM_COLOR_P4
	return TEAM_COLOR_P1

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
