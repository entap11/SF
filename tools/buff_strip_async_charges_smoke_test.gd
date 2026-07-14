extends SceneTree

const PlayerBuffStripScript = preload("res://scripts/ui/player_buff_strip.gd")
const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")

const BUFF_ID: String = "buff_swarm_speed_classic"

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var strip: Control = PlayerBuffStripScript.new()
	strip.name = "BuffStrip"
	var center: MarginContainer = MarginContainer.new()
	center.name = "Center"
	strip.add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "SlotsRow"
	center.add_child(row)
	for slot_number in range(1, 4):
		var slot: Panel = Panel.new()
		slot.name = "BuffSlot%d" % slot_number
		row.add_child(slot)
	get_root().add_child(strip)
	await process_frame

	var buff: Dictionary = BuffCatalog.get_buff(BUFF_ID)
	var base_slot: Dictionary = {
		"id": BUFF_ID,
		"name": str(buff.get("name", "Swarm Speed")),
		"tier": str(buff.get("tier", "classic")),
		"icon_path": str(buff.get("icon_path", "")),
		"locked": false,
		"uses_total": 2
	}

	var first_use: Dictionary = base_slot.duplicate(true)
	first_use.merge({
		"active": true,
		"consumed": false,
		"uses_remaining": 1,
		"remaining_ms": 9000
	}, true)
	strip.call("apply_snapshot", {"pid": 1, "slots_active": 2, "slots": [first_use]})
	_assert_visible(strip, "Center/SlotsRow/BuffSlot1/UseSlash", true, "first Async use shows slash")
	_assert_visible(strip, "Center/SlotsRow/BuffSlot1/BuffIcon", true, "first Async use keeps sprite")

	var second_use: Dictionary = base_slot.duplicate(true)
	second_use.merge({
		"active": true,
		"consumed": true,
		"uses_remaining": 0,
		"remaining_ms": 9000
	}, true)
	strip.call("apply_snapshot", {"pid": 1, "slots_active": 2, "slots": [second_use]})
	_assert_visible(strip, "Center/SlotsRow/BuffSlot1/UseSlash", false, "second Async use clears slash")
	_assert_visible(strip, "Center/SlotsRow/BuffSlot1/BuffIcon", false, "second Async use removes sprite")

	second_use["active"] = false
	second_use["remaining_ms"] = 0
	strip.call("apply_snapshot", {"pid": 1, "slots_active": 2, "slots": [second_use]})
	var state_label: Label = strip.get_node_or_null("Center/SlotsRow/BuffSlot1/SlotText/State") as Label
	var meta_label: Label = strip.get_node_or_null("Center/SlotsRow/BuffSlot1/SlotText/Meta") as Label
	_assert_true(state_label != null and state_label.text == "EMPTY", "exhausted Async slot reads EMPTY")
	_assert_true(meta_label != null and meta_label.text == "0/2", "exhausted Async slot reads 0/2")

	if _failed:
		quit(1)
		return
	print("BUFF_STRIP_ASYNC_CHARGES_SMOKE: PASS")
	quit(0)

func _assert_visible(root: Node, path: String, expected: bool, label: String) -> void:
	var control: CanvasItem = root.get_node_or_null(path) as CanvasItem
	_assert_true(control != null and control.visible == expected, label)

func _assert_true(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_STRIP_ASYNC_CHARGES_SMOKE: %s" % label)
