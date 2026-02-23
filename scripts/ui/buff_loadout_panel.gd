extends Panel

signal equip_buff(slot_index: int, buff_id: String)
signal unequip_buff(slot_index: int)
signal purchase_slot_unlock()
signal purchase_buff(buff_id: String)

@export var player_id: String = ""

@onready var title_label: Label = $Root/VBox/Title
@onready var mode_label: Label = $Root/VBox/ModeLabel
@onready var summary_label: Label = $Root/VBox/Summary
@onready var slots_text: RichTextLabel = $Root/VBox/SlotsScroll/SlotsText
@onready var unlock_button: Button = $Root/VBox/ActionsRow/UnlockSlotButton
@onready var buy_button: Button = $Root/VBox/ActionsRow/BuyBuffButton

func _ready() -> void:
	title_label.text = "Buff Loadout"
	unlock_button.pressed.connect(func() -> void:
		purchase_slot_unlock.emit()
	)
	buy_button.pressed.connect(func() -> void:
		purchase_buff.emit("")
	)
	var state_node: Node = _economy_state()
	if state_node != null and not state_node.economy_state_changed.is_connected(_on_economy_state_changed):
		state_node.economy_state_changed.connect(_on_economy_state_changed)
	_refresh()

func _exit_tree() -> void:
	var state_node: Node = _economy_state()
	if state_node != null and state_node.economy_state_changed.is_connected(_on_economy_state_changed):
		state_node.economy_state_changed.disconnect(_on_economy_state_changed)

func _on_economy_state_changed(_snapshot: Dictionary) -> void:
	_refresh()

func _refresh() -> void:
	var state_node: Node = _economy_state()
	if state_node == null:
		mode_label.text = "EconomyBuffState missing"
		summary_label.text = ""
		slots_text.text = ""
		unlock_button.disabled = true
		buy_button.disabled = true
		return
	var resolved_player_id: String = _resolve_player_id()
	var snapshot: Dictionary = state_node.get_player_snapshot(resolved_player_id)
	if snapshot.is_empty():
		mode_label.text = "No player snapshot"
		summary_label.text = ""
		slots_text.text = ""
		return
	mode_label.text = "Mode: %s" % str(snapshot.get("mode_key", "STANDARD"))
	var available_slots: int = int(snapshot.get("available_slots", 0))
	var nectar_balance: int = int((snapshot.get("wallet", {}) as Dictionary).get("nectar", 0))
	summary_label.text = "Available slots: %d · Nectar: %d" % [available_slots, nectar_balance]
	unlock_button.disabled = not bool(snapshot.get("loadout_ui_enabled", false))
	buy_button.disabled = not bool(snapshot.get("loadout_ui_enabled", false))
	var lines: PackedStringArray = PackedStringArray()
	var entries_any: Variant = snapshot.get("entries", [])
	if typeof(entries_any) == TYPE_ARRAY:
		for entry_any in entries_any as Array:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			var lock_text: String = " (classic locked)" if bool(entry.get("classic_locked", false)) else ""
			lines.append("Slot %d: %s [%s]%s" % [
				int(entry.get("slot_index", 0)) + 1,
				str(entry.get("name", "")),
				str(entry.get("tier", "CLASSIC")),
				lock_text
			])
	slots_text.text = "\n".join(lines)

func _resolve_player_id() -> String:
	if player_id.strip_edges() != "":
		return player_id.strip_edges()
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null and profile_manager.has_method("get_user_id"):
		var local_id: String = str(profile_manager.call("get_user_id")).strip_edges()
		if local_id != "":
			return local_id
	return "local_player"

func _economy_state() -> Node:
	return get_node_or_null("/root/EconomyBuffState")
