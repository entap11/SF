@tool
extends Control

const CanvasScript = preload("res://addons/map_sketch_tracer/tracer_canvas.gd")
const Layout = preload("res://scripts/maps/map_layout_contract.gd")
var canvas: MapSketchCanvas
var _status: Label
var _usage: OptionButton
var _symmetry: OptionButton
var _name_edit: LineEdit
var _id_edit: LineEdit
var _dialog: FileDialog
var _action := ""
var _report: AcceptDialog
var _syncing := false
var _preview_picker: OptionButton
var _barriers: CheckButton
var _connections: CheckButton

func _ready() -> void:
	custom_minimum_size = Vector2(540, 720)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.text = "MAP STUDIO  /  18 × 28"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	var files := HFlowContainer.new()
	column.add_child(files)
	_button(files, "New", func():
		canvas._checkpoint()
		canvas.draft = CanvasScript.new_draft()
		canvas._reset_selection()
		canvas._changed())
	_button(files, "Load sketch", func(): _choose("sketch"))
	_button(files, "Align sketch", func(): canvas.set_mode("align"))
	_button(files, "Open draft", func(): _choose("open"))
	_button(files, "Save draft", func(): _choose("save"))
	_button(files, "Restore draft", func(): canvas.load_draft(CanvasScript.AUTOSAVE))
	_button(files, "Rink Rat pilot", func(): canvas.load_draft("res://map_sources/rink_rat_symmetry.draft.json"))
	var metadata := GridContainer.new()
	metadata.columns = 2
	column.add_child(metadata)
	_label(metadata, "Name")
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metadata.add_child(_name_edit)
	_name_edit.text_changed.connect(func(value: String):
		if not _syncing:
			canvas.draft.name = value
			canvas._changed())
	_label(metadata, "Map ID")
	_id_edit = LineEdit.new()
	metadata.add_child(_id_edit)
	_id_edit.text_changed.connect(func(value: String):
		if not _syncing:
			canvas.draft.id = value
			canvas._changed())
	_label(metadata, "Use")
	_usage = _options(metadata, ["Campaign — asymmetry allowed", "Multiplayer — symmetry required", "Both — symmetry required"])
	_usage.item_selected.connect(func(_index: int): _policy())
	_label(metadata, "Generate from one sector")
	_symmetry = _options(metadata, ["None", "Mirror left / right", "Mirror top / bottom", "Rotate 180°", "Both mirrors / four players", "Rotate 90° / four players"])
	_symmetry.item_selected.connect(func(_index: int): _policy())
	var tools_row := HFlowContainer.new()
	column.add_child(tools_row)
	var mode_picker := _options(tools_row, ["Select / move", "Place hive", "Draw curved wall", "Draw straight wall", "Click wall corners (Enter ends)"])
	mode_picker.item_selected.connect(func(index: int): canvas.set_mode(["select", "place", "curve", "straight", "corners"][index]))
	var node_picker := _options(tools_row, ["Player hive", "Neutral hive", "Structure slot"])
	node_picker.item_selected.connect(func(index: int): canvas.set_place_type(["hive", "npc", "slot"][index]))
	var owner_picker := _options(tools_row, ["P1", "P2", "P3", "P4"])
	owner_picker.item_selected.connect(func(index: int): canvas.set_place_owner("P%d" % (index + 1)))
	_button(tools_row, "Undo", func(): canvas.undo())
	_button(tools_row, "Redo", func(): canvas.redo())
	var previews := HFlowContainer.new()
	column.add_child(previews)
	_preview_picker = _options(previews, ["Clean layout", "Sketch + corrections", "Finished walls"])
	_preview_picker.item_selected.connect(func(index: int):
		canvas.preview_mode = ["layout", "sketch", "finished"][index]
		canvas.queue_redraw())
	_barriers = CheckButton.new()
	_barriers.text = "Barriers"
	_barriers.button_pressed = true
	previews.add_child(_barriers)
	_barriers.toggled.connect(func(enabled: bool):
		canvas.show_barriers = enabled
		canvas.queue_redraw())
	_connections = CheckButton.new()
	_connections.text = "Legal connections"
	previews.add_child(_connections)
	_connections.toggled.connect(func(enabled: bool):
		canvas.show_connections = enabled
		canvas._refresh())
	var hint := Label.new()
	hint.text = "Draw one sector. Matching sectors are generated. Leave gaps between separate strokes."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	canvas = CanvasScript.new()
	canvas.custom_minimum_size = Vector2(480, 420)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(canvas)
	canvas.status_changed.connect(func(message: String): _status.text = message)
	canvas.draft_changed.connect(_sync)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	_button(actions, "Validate", _validate)
	_button(actions, "Export playable JSON", func(): _choose("export"))
	_button(actions, "Fit board", func():
		canvas.zoom = 1.0
		canvas.pan = Vector2.ZERO
		canvas.queue_redraw())
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 45
	column.add_child(_status)
	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.file_selected.connect(_file_selected)
	add_child(_dialog)
	_report = AcceptDialog.new()
	_report.title = "Map validation"
	add_child(_report)
	_sync()

func _button(parent: Node, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	parent.add_child(button)

func _label(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)

func _options(parent: Node, items: Array) -> OptionButton:
	var option := OptionButton.new()
	for item in items: option.add_item(item)
	option.select(0)
	parent.add_child(option)
	return option

func _policy() -> void:
	if _syncing or canvas == null: return
	canvas.set_policy(["campaign", "multiplayer", "both"][_usage.selected], Layout.PRESETS.keys()[_symmetry.selected])

func _sync() -> void:
	if _status == null: return
	_syncing = true
	_name_edit.text = str(canvas.draft.get("name", ""))
	_id_edit.text = str(canvas.draft.get("id", ""))
	_usage.select(["campaign", "multiplayer", "both"].find(canvas.draft.get("map_usage", "campaign")))
	_symmetry.select(Layout.PRESETS.keys().find(canvas.draft.layout_symmetry.get("kind", "none")))
	_preview_picker.select(["layout", "sketch", "finished"].find(canvas.preview_mode))
	_barriers.set_pressed_no_signal(canvas.show_barriers)
	_connections.set_pressed_no_signal(canvas.show_connections)
	_status.text = "Layout checks pass. Validate checks export and runtime loading." if canvas._issues.is_empty() else "%d issue(s): %s" % [canvas._issues.size(), str(canvas._issues[0])]
	_syncing = false

func _validate() -> void:
	var result: Dictionary = canvas.validate_map()
	_report.dialog_text = "Layout, symmetry and runtime playability checks pass.\n" if result.ok else "Export blocked:\n" + "\n".join(result.errors)
	_report.popup_centered(Vector2i(650, 260))

func _choose(action: String) -> void:
	_action = action
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if action in ["sketch", "open"] else FileDialog.FILE_MODE_SAVE_FILE
	_dialog.clear_filters()
	_dialog.add_filter("*.png,*.jpg,*.jpeg", "Sketch images") if action == "sketch" else _dialog.add_filter("*.json", "JSON")
	_dialog.current_dir = ProjectSettings.globalize_path("res://map_sources" if action in ["save", "open"] else "res://maps/_future/rink_rat")
	if action == "save": _dialog.current_file = str(canvas.draft.id) + ".draft.json"
	if action == "export": _dialog.current_file = str(canvas.draft.id) + ".json"
	_dialog.title = {"sketch": "Load drawing", "open": "Open retained authoring draft", "save": "Save retained authoring draft", "export": "Export validated map"}[action]
	_dialog.popup_centered_ratio(0.8)

func _file_selected(path: String) -> void:
	if _action in ["save", "export"] and not path.to_lower().ends_with(".json"): path += ".json"
	match _action:
		"sketch": canvas.load_sketch(path)
		"open": canvas.load_draft(path)
		"save": _status.text = "Draft saved" if canvas.save_draft(path) else "Draft save failed"
		"export": canvas.export_json_to_path(path)
