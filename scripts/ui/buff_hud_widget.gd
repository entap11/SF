extends Panel

signal activate_buff(slot_index: int)

@export var player_id: String = ""

@onready var title_label: Label = $Root/VBox/Title
@onready var status_label: Label = $Root/VBox/Status
@onready var slots_text: RichTextLabel = $Root/VBox/SlotsScroll/SlotsText

func _ready() -> void:
	title_label.text = "Match Buff HUD"
	var state_node: Node = _economy_state()
	if state_node != null and not state_node.economy_state_changed.is_connected(_on_economy_state_changed):
		state_node.economy_state_changed.connect(_on_economy_state_changed)
	_refresh()

func _exit_tree() -> void:
	var state_node: Node = _economy_state()
	if state_node != null and state_node.economy_state_changed.is_connected(_on_economy_state_changed):
		state_node.economy_state_changed.disconnect(_on_economy_state_changed)

func request_activate(slot_index: int) -> void:
	activate_buff.emit(slot_index)

func _on_economy_state_changed(_snapshot: Dictionary) -> void:
	_refresh()

func _refresh() -> void:
	var state_node: Node = _economy_state()
	if state_node == null:
		status_label.text = "EconomyBuffState missing"
		slots_text.text = ""
		return
	var resolved_player_id: String = _resolve_player_id()
	var snapshot: Dictionary = state_node.get_player_snapshot(resolved_player_id)
	if snapshot.is_empty():
		status_label.text = "No player snapshot"
		slots_text.text = ""
		return
	status_label.text = "Mode %s · Overtime: %s · Unlimited: %s" % [
		str(snapshot.get("mode_key", "STANDARD")),
		"ON" if bool(snapshot.get("overtime_active", false)) else "OFF",
		str(snapshot.get("unlimited_buffs", false))
	]
	var lines: PackedStringArray = PackedStringArray()
	var entries_any: Variant = snapshot.get("entries", [])
	if typeof(entries_any) == TYPE_ARRAY:
		for entry_any in entries_any as Array:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			var lock_text: String = "LOCKED" if bool(entry.get("classic_locked", false)) else "READY"
			var active_text: String = "ACTIVE" if bool(entry.get("activated", false)) else "IDLE"
			lines.append("[%s] Slot %d · %s · %s" % [
				lock_text,
				int(entry.get("slot_index", 0)) + 1,
				str(entry.get("name", "")),
				active_text
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
