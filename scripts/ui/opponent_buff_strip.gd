extends Control
class_name OpponentBuffStrip

const SLOT_READY_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const SLOT_USED_COLOR: Color = Color(0.48, 0.12, 0.12, 0.96)

@export var default_visible_slots: int = 3

var _slots: Array[Panel] = []
var _used_marks: Array[Label] = []

func _ready() -> void:
	_cache_nodes()
	reset_slots()
	set_visible_slot_count(default_visible_slots)

func _cache_nodes() -> void:
	_slots.clear()
	_used_marks.clear()
	for idx in range(1, 4):
		var slot_path: String = "SlotsColumn/OpponentSlot%d" % idx
		var mark_path: String = "SlotsColumn/OpponentSlot%d/UsedMark" % idx
		var slot: Panel = get_node_or_null(slot_path) as Panel
		var mark: Label = get_node_or_null(mark_path) as Label
		if slot == null:
			continue
		_slots.append(slot)
		_used_marks.append(mark)

func reset_slots() -> void:
	for i in range(_slots.size()):
		set_slot_used(i, false)

func set_visible_slot_count(count: int) -> void:
	var clamped: int = clampi(count, 0, _slots.size())
	for i in range(_slots.size()):
		_slots[i].visible = i < clamped

func set_slot_used(index: int, used: bool) -> void:
	if index < 0 or index >= _slots.size():
		return
	var slot: Panel = _slots[index]
	var mark: Label = _used_marks[index]
	slot.self_modulate = SLOT_USED_COLOR if used else SLOT_READY_COLOR
	if mark != null:
		mark.visible = used

func set_used_slots(indices: Array) -> void:
	reset_slots()
	for entry in indices:
		set_slot_used(int(entry), true)
