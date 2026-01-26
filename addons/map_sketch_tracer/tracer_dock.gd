@tool
extends Control

@onready var load_button: Button = $VBox/ToolbarRow/LoadSketch
@onready var clear_button: Button = $VBox/ToolbarRow/ClearSketch
@onready var opacity_slider: HSlider = $VBox/ToolbarRow/OpacitySlider
@onready var opacity_label: Label = $VBox/ToolbarRow/OpacityValue
@onready var mode_select: OptionButton = $VBox/ModeRow/ModeSelect
@onready var node_type_select: OptionButton = $VBox/ModeRow/NodeType
@onready var owner_select: OptionButton = $VBox/ModeRow/OwnerSelect
@onready var hover_label: Label = $VBox/ModeRow/HoverLabel
@onready var name_edit: LineEdit = $VBox/MetaRow/MapName
@onready var desc_edit: LineEdit = $VBox/MetaRow/MapDesc
@onready var validate_button: Button = $VBox/ActionRow/Validate
@onready var export_button: Button = $VBox/ActionRow/Export
@onready var copy_button: Button = $VBox/ActionRow/CopyJson
@onready var status_label: Label = $VBox/ActionRow/StatusLabel
@onready var canvas: MapSketchCanvas = $VBox/Canvas

var load_dialog: EditorFileDialog
var save_dialog: EditorFileDialog

func _ready() -> void:
	_setup_dialogs()
	_setup_options()
	_opacity_changed(opacity_slider.value)
	_canvas_bind()
	load_button.pressed.connect(_on_load_pressed)
	clear_button.pressed.connect(func(): canvas.clear_sketch())
	opacity_slider.value_changed.connect(_opacity_changed)
	mode_select.item_selected.connect(_on_mode_selected)
	node_type_select.item_selected.connect(_on_node_type_selected)
	owner_select.item_selected.connect(_on_owner_selected)
	validate_button.pressed.connect(_on_validate)
	export_button.pressed.connect(_on_export)
	copy_button.pressed.connect(_on_copy)

func _setup_dialogs() -> void:
	load_dialog = EditorFileDialog.new()
	load_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	load_dialog.add_filter("*.png,*.jpg,*.jpeg;Image Files")
	load_dialog.title = "Load Sketch Image"
	add_child(load_dialog)
	load_dialog.file_selected.connect(_on_load_file_selected)

	save_dialog = EditorFileDialog.new()
	save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	save_dialog.add_filter("*.json;Map JSON")
	save_dialog.title = "Export Map JSON"
	add_child(save_dialog)
	save_dialog.file_selected.connect(_on_export_file_selected)

func _setup_options() -> void:
	mode_select.clear()
	mode_select.add_item("Select/Move", 0)
	mode_select.add_item("Place Node", 1)
	mode_select.add_item("Connect Lanes", 2)
	mode_select.select(0)

	node_type_select.clear()
	node_type_select.add_item("Player Hive", 0)
	node_type_select.add_item("NPC Hive", 1)
	node_type_select.add_item("Tower", 2)
	node_type_select.add_item("Barracks", 3)
	node_type_select.select(0)

	owner_select.clear()
	owner_select.add_item("P1", 0)
	owner_select.add_item("P2", 1)
	owner_select.add_item("P3", 2)
	owner_select.add_item("P4", 3)
	owner_select.select(0)

func _canvas_bind() -> void:
	canvas.status_changed.connect(_set_status)
	canvas.hover_changed.connect(func(text: String): hover_label.text = text)
	canvas.set_mode("select")
	canvas.set_place_type("player_hive")
	canvas.set_place_owner("P1")

func _on_load_pressed() -> void:
	load_dialog.popup_centered_ratio(0.6)

func _on_load_file_selected(path: String) -> void:
	canvas.load_sketch(path)

func _opacity_changed(value: float) -> void:
	canvas.set_sketch_opacity(value)
	opacity_label.text = "%d%%" % int(round(value * 100.0))

func _on_mode_selected(index: int) -> void:
	match index:
		0:
			canvas.set_mode("select")
		1:
			canvas.set_mode("place")
		2:
			canvas.set_mode("connect")

func _on_node_type_selected(index: int) -> void:
	match index:
		0:
			canvas.set_place_type("player_hive")
		1:
			canvas.set_place_type("npc_hive")
		2:
			canvas.set_place_type("tower")
		3:
			canvas.set_place_type("barracks")

func _on_owner_selected(index: int) -> void:
	var owner := "P1"
	match index:
		1:
			owner = "P2"
		2:
			owner = "P3"
		3:
			owner = "P4"
	canvas.set_place_owner(owner)

func _on_validate() -> void:
	var result := canvas.validate_map(name_edit.text, desc_edit.text)
	if result.get("ok", false):
		_set_status("Validation OK")
		return
	var errors: Array = result.get("errors", [])
	if errors.is_empty():
		_set_status("Validation failed")
		return
	_set_status("Validation: %s" % "; ".join(errors))

func _on_export() -> void:
	save_dialog.current_path = "res://maps/"
	save_dialog.popup_centered_ratio(0.6)

func _on_export_file_selected(path: String) -> void:
	var result := canvas.validate_map(name_edit.text, desc_edit.text)
	if not result.get("ok", false):
		_on_validate()
		return
	canvas.export_json_to_path(path, name_edit.text, desc_edit.text)

func _on_copy() -> void:
	var result := canvas.validate_map(name_edit.text, desc_edit.text)
	if not result.get("ok", false):
		_on_validate()
		return
	var json_text := canvas.export_json(name_edit.text, desc_edit.text)
	DisplayServer.clipboard_set(json_text)
	_set_status("JSON copied to clipboard")

func _set_status(message: String) -> void:
	status_label.text = message
