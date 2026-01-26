extends Control
class_name TimePuzzleLobby

signal closed

const SCOPES := ["WEEKLY", "MONTHLY", "YEARLY"]

@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var back_button: Button = $Panel/VBox/Header/Back
@onready var scope_box: HBoxContainer = $Panel/VBox/ScopeTabs
@onready var contest_list: VBoxContainer = $Panel/VBox/ContestList
@onready var contest_state := get_node_or_null("/root/ContestState")

var _scope_buttons: Dictionary = {}
var _current_scope := "WEEKLY"

func _ready() -> void:
	_build_scope_tabs()
	_set_scope(_current_scope)
	back_button.pressed.connect(_on_back_pressed)

func set_scope(scope: String) -> void:
	if SCOPES.has(scope):
		_set_scope(scope)

func _build_scope_tabs() -> void:
	for child in scope_box.get_children():
		child.queue_free()
	_scope_buttons.clear()
	for scope in SCOPES:
		var button := Button.new()
		button.text = scope.capitalize()
		button.toggle_mode = true
		button.pressed.connect(func(): _set_scope(scope))
		scope_box.add_child(button)
		_scope_buttons[scope] = button

func _set_scope(scope: String) -> void:
	_current_scope = scope
	for key in _scope_buttons.keys():
		var button: Button = _scope_buttons[key]
		button.button_pressed = key == scope
	_refresh_contests()

func _refresh_contests() -> void:
	for child in contest_list.get_children():
		child.queue_free()
	if contest_state == null:
		return
	var contests: Array[ContestDef] = contest_state.get_contests_by_scope(_current_scope)
	if contests.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No contests available."
		contest_list.add_child(empty_label)
		return
	for contest in contests:
		var button := Button.new()
		button.text = _format_contest_tile(contest)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): _open_contest(contest.id))
		contest_list.add_child(button)

func _format_contest_tile(contest: ContestDef) -> String:
	var entered := false
	if contest_state != null:
		entered = contest_state.is_entered(contest.id)
	var entry_text := "Entered" if entered else "Not entered"
	var cap_text := _cap_text(contest.buff_cap_per_map)
	var remaining := _format_remaining(contest.end_ts)
	return "%s\n%s | %s | %s" % [
		contest.name,
		entry_text,
		cap_text,
		remaining
	]

func _open_contest(contest_id: String) -> void:
	var panel := preload("res://scenes/ui/ContestHub.tscn").instantiate()
	panel.contest_id = contest_id
	panel.closed.connect(func():
		panel.queue_free()
		visible = true
		_refresh_contests()
	)
	add_child(panel)
	visible = false

func _cap_text(cap: int) -> String:
	if cap < 0:
		return "Unlimited buffs"
	if cap == 1:
		return "1 buff/map"
	return "%d buffs/map" % cap

func _format_remaining(end_ts: int) -> String:
	if end_ts <= 0:
		return "No end"
	var now: int = int(Time.get_unix_time_from_system())
	var remaining: int = int(max(0, end_ts - now))
	var hours: int = remaining / 3600
	var mins: int = (remaining % 3600) / 60
	return "Remaining %02dh%02dm" % [hours, mins]

func _on_back_pressed() -> void:
	closed.emit()
