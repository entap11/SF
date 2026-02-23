extends Panel

signal mode_selected(mode_key: String)

@onready var title_label: Label = $Root/VBox/Title
@onready var modes_text: RichTextLabel = $Root/VBox/ModesScroll/ModesText
@onready var standard_button: Button = $Root/VBox/ButtonsRow/StandardButton
@onready var steroids_button: Button = $Root/VBox/ButtonsRow/SteroidsButton
@onready var esports_none_button: Button = $Root/VBox/ButtonsRow/EsportsNoneButton
@onready var esports_std_button: Button = $Root/VBox/ButtonsRow/EsportsStdButton

func _ready() -> void:
	title_label.text = "Mode Selector"
	standard_button.pressed.connect(func() -> void:
		mode_selected.emit("STANDARD")
	)
	steroids_button.pressed.connect(func() -> void:
		mode_selected.emit("STEROIDS_LEAGUE")
	)
	esports_none_button.pressed.connect(func() -> void:
		mode_selected.emit("ESPORTS_NO_BUFFS")
	)
	esports_std_button.pressed.connect(func() -> void:
		mode_selected.emit("ESPORTS_STANDARDIZED")
	)
	var state_node: Node = _economy_state()
	if state_node != null and not state_node.mode_changed.is_connected(_on_mode_changed):
		state_node.mode_changed.connect(_on_mode_changed)
	_refresh()

func _exit_tree() -> void:
	var state_node: Node = _economy_state()
	if state_node != null and state_node.mode_changed.is_connected(_on_mode_changed):
		state_node.mode_changed.disconnect(_on_mode_changed)

func _on_mode_changed(_mode_key: String) -> void:
	_refresh()

func _refresh() -> void:
	var state_node: Node = _economy_state()
	if state_node == null:
		modes_text.text = "EconomyBuffState missing"
		return
	var snap: Dictionary = state_node.get_mode_snapshot()
	var rule: Dictionary = snap.get("rules", {}) as Dictionary
	modes_text.text = "Current: %s\nBuffs Enabled: %s\nLoadout UI: %s\nEntry: %s %d" % [
		str(snap.get("mode_key", "STANDARD")),
		str(rule.get("buffs_enabled", false)),
		str(rule.get("loadout_ui_enabled", false)),
		str(rule.get("entry_currency", "FREE")),
		int(rule.get("entry_cost", 0))
	]

func _economy_state() -> Node:
	return get_node_or_null("/root/EconomyBuffState")
