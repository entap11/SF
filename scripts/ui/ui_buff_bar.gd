class_name UIBuffBar
extends Control

const BuffDefinitions = preload("res://scripts/state/buff_definitions.gd")

signal activate_intent(owner_id: int, buff_id: String, tier: String, target: Dictionary)
signal target_highlight_intent(target_type: String, buff_id: String)
signal release_supercharge_intent(owner_id: int, hive_id: int)

@export var player_id: int = 1
@export var default_tier: String = BuffDefinitions.TIER_CLASSIC
@export var activation_system_path: NodePath = NodePath("")

var _header_label: Label = null
var _status_label: Label = null
var _cooldown_label: Label = null
var _buttons_root: VBoxContainer = null
var _buff_buttons: Dictionary = {}
var _pending_target_buff_id: String = ""
var _pending_target_type: String = BuffDefinitions.TARGET_NONE

func _ready() -> void:
	_build_ui()
	_wire_optional_state_feed()
	_apply_snapshot(_empty_snapshot())

func _build_ui() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "BuffBarRoot"
	root.layout_mode = 1
	root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	root.offset_left = 8.0
	root.offset_top = 8.0
	root.offset_right = -8.0
	root.offset_bottom = -8.0
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	_header_label = Label.new()
	_header_label.text = "BUFF BAR"
	root.add_child(_header_label)

	_status_label = Label.new()
	_status_label.text = "Ready"
	root.add_child(_status_label)

	_cooldown_label = Label.new()
	_cooldown_label.text = "Global Chill: 0.0s"
	root.add_child(_cooldown_label)

	_buttons_root = VBoxContainer.new()
	_buttons_root.add_theme_constant_override("separation", 4)
	root.add_child(_buttons_root)

	for category in BuffDefinitions.supported_categories():
		var category_key: String = str(category)
		var category_label: Label = Label.new()
		category_label.text = category_key.to_upper()
		_buttons_root.add_child(category_label)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_buttons_root.add_child(row)
		for buff_id in BuffDefinitions.list_ids_for_category(category_key):
			var buff_def: Dictionary = BuffDefinitions.get_definition(buff_id)
			var button: Button = Button.new()
			button.text = str(buff_def.get("display_name", buff_id))
			button.tooltip_text = _button_tooltip(buff_def)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(func(): _on_buff_pressed(buff_id))
			row.add_child(button)
			_buff_buttons[buff_id] = button

func _wire_optional_state_feed() -> void:
	if activation_system_path.is_empty():
		return
	var activation_node: Node = get_node_or_null(activation_system_path)
	if activation_node == null:
		return
	if activation_node.has_signal("buff_state_changed"):
		activation_node.connect("buff_state_changed", Callable(self, "_on_external_buff_state_changed"))
	if activation_node.has_method("get_snapshot"):
		var snapshot_any: Variant = activation_node.call("get_snapshot")
		if typeof(snapshot_any) == TYPE_DICTIONARY:
			_apply_snapshot(snapshot_any as Dictionary)

func apply_snapshot(snapshot: Dictionary) -> void:
	_apply_snapshot(snapshot)

func select_hive_target(hive_id: int) -> void:
	if _pending_target_buff_id == "" or _pending_target_type != BuffDefinitions.TARGET_HIVE:
		return
	var payload: Dictionary = {"owner_id": player_id, "hive_id": hive_id}
	activate_intent.emit(player_id, _pending_target_buff_id, default_tier, payload)
	_status_label.text = "Requested %s on hive %d" % [_pending_target_buff_id, hive_id]
	_clear_pending_target()

func select_lane_target(lane_id: int) -> void:
	if _pending_target_buff_id == "" or _pending_target_type != BuffDefinitions.TARGET_LANE:
		return
	var payload: Dictionary = {"owner_id": player_id, "lane_id": lane_id}
	activate_intent.emit(player_id, _pending_target_buff_id, default_tier, payload)
	_status_label.text = "Requested %s on lane %d" % [_pending_target_buff_id, lane_id]
	_clear_pending_target()

func release_supercharge(hive_id: int) -> void:
	release_supercharge_intent.emit(player_id, hive_id)

func set_default_tier(tier: String) -> void:
	default_tier = BuffDefinitions.normalize_tier(tier)

func _on_buff_pressed(buff_id: String) -> void:
	var target_type: String = BuffDefinitions.target_type_for(buff_id)
	if target_type == BuffDefinitions.TARGET_NONE:
		var payload: Dictionary = {"owner_id": player_id}
		activate_intent.emit(player_id, buff_id, default_tier, payload)
		_status_label.text = "Requested %s" % buff_id
		_clear_pending_target()
		return
	_pending_target_buff_id = buff_id
	_pending_target_type = target_type
	_status_label.text = "Select %s target for %s" % [target_type, buff_id]
	target_highlight_intent.emit(target_type, buff_id)

func _clear_pending_target() -> void:
	_pending_target_buff_id = ""
	_pending_target_type = BuffDefinitions.TARGET_NONE

func _on_external_buff_state_changed(snapshot: Dictionary) -> void:
	_apply_snapshot(snapshot)

func _apply_snapshot(snapshot: Dictionary) -> void:
	var chill_sec: float = max(0.0, float(snapshot.get("buff_chill_timer", 0.0)))
	var disabled: bool = chill_sec > 0.0
	for buff_id_any in _buff_buttons.keys():
		var buff_id: String = str(buff_id_any)
		var button_any: Variant = _buff_buttons.get(buff_id)
		if button_any is Button:
			var button: Button = button_any as Button
			button.disabled = disabled
	_cooldown_label.text = "Global Chill: %.1fs" % chill_sec
	var active_lines: PackedStringArray = PackedStringArray()
	for category in BuffDefinitions.supported_categories():
		var key: String = str(category)
		var active_any: Variant = snapshot.get("active_%s_buff" % key, null)
		if typeof(active_any) == TYPE_DICTIONARY:
			var active: Dictionary = active_any as Dictionary
			active_lines.append("%s: %s" % [key.to_upper(), str(active.get("id", "none"))])
		else:
			active_lines.append("%s: none" % key.to_upper())
	if _pending_target_buff_id != "":
		active_lines.append("Pending target: %s (%s)" % [_pending_target_buff_id, _pending_target_type])
	_status_label.text = " | ".join(active_lines)

func _button_tooltip(buff_def: Dictionary) -> String:
	var buff_id: String = str(buff_def.get("id", ""))
	var target_type: String = str(buff_def.get("target_type", BuffDefinitions.TARGET_NONE))
	var duration_classic: float = BuffDefinitions.duration_seconds_for(buff_id, BuffDefinitions.TIER_CLASSIC)
	var duration_premium: float = BuffDefinitions.duration_seconds_for(buff_id, BuffDefinitions.TIER_PREMIUM)
	var duration_elite: float = BuffDefinitions.duration_seconds_for(buff_id, BuffDefinitions.TIER_ELITE)
	return "id=%s | target=%s | duration=%.0f/%.0f/%.0fs" % [
		buff_id,
		target_type,
		duration_classic,
		duration_premium,
		duration_elite
	]

func _empty_snapshot() -> Dictionary:
	return {
		"active_unit_buff": null,
		"active_hive_buff": null,
		"active_lane_buff": null,
		"buff_chill_timer": 0.0,
		"buff_category_timers": {
			BuffDefinitions.CATEGORY_UNIT: 0.0,
			BuffDefinitions.CATEGORY_HIVE: 0.0,
			BuffDefinitions.CATEGORY_LANE: 0.0
		}
	}
