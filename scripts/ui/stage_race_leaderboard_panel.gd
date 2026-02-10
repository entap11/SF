extends Control
class_name StageRaceLeaderboardPanel

signal closed

@export var contest_id: String = ""
@export var map_ids: PackedStringArray = PackedStringArray()

@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var summary_label: Label = $Panel/VBox/Summary
@onready var overall_button: Button = $Panel/VBox/ViewTabs/Overall
@onready var maps_button: Button = $Panel/VBox/ViewTabs/Maps
@onready var map_tabs: HBoxContainer = $Panel/VBox/MapTabs
@onready var entries_box: VBoxContainer = $Panel/VBox/Scroll/Entries
@onready var back_button: Button = $Panel/VBox/Footer/Back
@onready var contest_state := get_node_or_null("/root/ContestState")

var _view_mode: String = "overall"
var _selected_map_id: String = ""
var _map_tab_buttons: Dictionary = {}

func _ready() -> void:
	overall_button.pressed.connect(func(): _set_view_mode("overall"))
	maps_button.pressed.connect(func(): _set_view_mode("maps"))
	back_button.pressed.connect(_on_back_pressed)
	_build_map_tabs()
	_set_view_mode("overall")

func _build_map_tabs() -> void:
	for child in map_tabs.get_children():
		child.queue_free()
	_map_tab_buttons.clear()
	if map_ids.is_empty():
		_selected_map_id = ""
		return
	for i in range(map_ids.size()):
		var map_id: String = map_ids[i]
		var button := Button.new()
		button.toggle_mode = true
		button.text = "Map %d" % (i + 1)
		button.pressed.connect(func(): _select_map(map_id))
		map_tabs.add_child(button)
		_map_tab_buttons[map_id] = button
	_selected_map_id = map_ids[0]

func _set_view_mode(mode: String) -> void:
	_view_mode = mode
	overall_button.button_pressed = mode == "overall"
	maps_button.button_pressed = mode == "maps"
	map_tabs.visible = mode == "maps"
	_refresh_entries()

func _select_map(map_id: String) -> void:
	_selected_map_id = map_id
	for key in _map_tab_buttons.keys():
		var button: Button = _map_tab_buttons[key] as Button
		if button != null:
			button.button_pressed = key == map_id
	_refresh_entries()

func _refresh_entries() -> void:
	for child in entries_box.get_children():
		child.queue_free()
	if contest_id.is_empty():
		title_label.text = "Stage Race Leaderboard"
		summary_label.text = "No contest selected."
		return
	title_label.text = "Stage Race Leaderboard"
	if contest_state == null:
		summary_label.text = "ContestState unavailable."
		return
	if _view_mode == "maps":
		_refresh_map_entries()
		return
	_refresh_overall_entries()

func _refresh_overall_entries() -> void:
	var rows: Array = []
	if contest_state.has_method("build_stage_race_overall_leaderboard"):
		rows = contest_state.call("build_stage_race_overall_leaderboard", contest_id, map_ids.size(), 25) as Array
	if rows.is_empty():
		summary_label.text = "Overall: no results yet."
		_add_empty_row("No overall stage race results yet.")
		return
	var lead: Dictionary = rows[0] as Dictionary
	var required_maps: int = int(lead.get("required_maps", map_ids.size()))
	summary_label.text = "Overall lead (%d maps): %s  %s" % [
		required_maps,
		str(lead.get("player_name", "Player")),
		_format_time_ms(int(lead.get("aggregate_time_ms", 0)))
	]
	for row_v in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v as Dictionary
		var rank: int = int(row.get("rank", 0))
		var name: String = str(row.get("player_name", "Player"))
		var completed: int = int(row.get("completed_maps", 0))
		var required: int = int(row.get("required_maps", map_ids.size()))
		var agg: int = int(row.get("aggregate_time_ms", 0))
		_add_row("%d) %s  %s  [%d/%d]" % [rank, name, _format_time_ms(agg), completed, required])

func _refresh_map_entries() -> void:
	if _selected_map_id.is_empty():
		summary_label.text = "Map results unavailable."
		_add_empty_row("No map selected.")
		return
	var rows: Array = []
	if contest_state.has_method("get_stage_race_map_leaderboard"):
		rows = contest_state.call("get_stage_race_map_leaderboard", contest_id, _selected_map_id, 25) as Array
	if rows.is_empty():
		summary_label.text = "Map %s: no results yet." % _selected_map_id
		_add_empty_row("No map results yet.")
		return
	summary_label.text = "Map %s lead: %s  %s" % [
		_selected_map_id,
		str((rows[0] as Dictionary).get("player_name", "Player")),
		_format_time_ms(int((rows[0] as Dictionary).get("time_ms", 0)))
	]
	for row_v in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v as Dictionary
		_add_row("%d) %s  %s  runs:%d" % [
			int(row.get("rank", 0)),
			str(row.get("player_name", "Player")),
			_format_time_ms(int(row.get("time_ms", 0))),
			int(row.get("runs_count", 0))
		])

func _add_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	entries_box.add_child(label)

func _add_empty_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	entries_box.add_child(label)

func _format_time_ms(value: int) -> String:
	var ms: int = maxi(0, value)
	var minutes: int = ms / 60000
	var seconds: int = (ms % 60000) / 1000
	var millis: int = ms % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, millis]

func _on_back_pressed() -> void:
	closed.emit()
