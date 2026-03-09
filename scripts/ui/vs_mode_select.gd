extends Control

signal closed

const FONT_REGULAR_PATH := "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const FONT_FREE_ROLL_ATLAS_PATH := "res://assets/fonts/free_roll_display_v2_font.tres"
const FONT_FREE_ROLL_SUPPORTED := " ABCDEFGHIJKLMNOPQRSTUVWXYZ01235789"
const MODES := [
	{"id": "STAGE_RACE", "label": "Stage Race"},
	{"id": "CAPTURE_FLAG", "label": "Capture the Flag"},
	{"id": "HIDDEN_CAPTURE_FLAG", "label": "Hidden CTF"},
	{"id": "TIMED_RACE", "label": "Timed Race"},
	{"id": "MISS_N_OUT", "label": "Miss-N-Out"}
]
const MAP_COUNTS := [3, 5]
const PRICES := [1, 5, 10, 20]

@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var back_button: Button = $Panel/VBox/Header/Back
@onready var mode_label: Label = $Panel/VBox/ModeRow/ModeLabel
@onready var mode_buttons: HBoxContainer = $Panel/VBox/ModeRow/ModeButtons
@onready var map_label: Label = $Panel/VBox/MapRow/MapLabel
@onready var map_buttons: HBoxContainer = $Panel/VBox/MapRow/MapButtons
@onready var price_label: Label = $Panel/VBox/PriceRow/PriceLabel
@onready var price_buttons: HBoxContainer = $Panel/VBox/PriceRow/PriceButtons
@onready var summary_label: Label = $Panel/VBox/Summary
@onready var confirm_button: Button = $Panel/VBox/ConfirmRow/Confirm

var _mode_buttons: Dictionary = {}
var _map_buttons: Dictionary = {}
var _price_buttons: Dictionary = {}
var _font_regular: Font
var _font_semibold: Font
var _font_free_roll_atlas: Font

var _selected_mode := "STAGE_RACE"
var _selected_map_count := 3
var _selected_price := 1
var _free_roll := false
var _entry_lock := "any" # "any", "free_only", "paid_only"

func configure_entry(free_roll: bool) -> void:
	_entry_lock = "free_only" if free_roll else "paid_only"
	_selected_price = 0 if free_roll else PRICES[0]
	_free_roll = free_roll
	if not _price_buttons.is_empty():
		_build_buttons()

func _ready() -> void:
	_load_fonts()
	_apply_static_fonts()
	back_button.pressed.connect(_on_back_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	_build_buttons()
	_refresh_summary()

func _build_buttons() -> void:
	for child in mode_buttons.get_children():
		child.queue_free()
	for child in map_buttons.get_children():
		child.queue_free()
	for child in price_buttons.get_children():
		child.queue_free()
	_mode_buttons.clear()
	_map_buttons.clear()
	_price_buttons.clear()

	var mode_group := ButtonGroup.new()
	for entry in MODES:
		var mode_id := str(entry.get("id", ""))
		var label := str(entry.get("label", mode_id))
		if mode_id.is_empty():
			continue
		var button := Button.new()
		button.text = label
		_apply_font(button, _font_regular, 13)
		button.toggle_mode = true
		button.button_group = mode_group
		button.pressed.connect(func(): _select_mode(mode_id))
		mode_buttons.add_child(button)
		_mode_buttons[mode_id] = button

	var count_group := ButtonGroup.new()
	for count in MAP_COUNTS:
		var button := Button.new()
		button.text = "%d Maps" % count
		_apply_font(button, _font_regular, 13)
		button.toggle_mode = true
		button.button_group = count_group
		button.pressed.connect(func(): _select_map_count(count))
		map_buttons.add_child(button)
		_map_buttons[count] = button

	var price_group := ButtonGroup.new()
	if _entry_lock != "free_only":
		for price in PRICES:
			var button := Button.new()
			button.text = "$%d" % price
			_apply_font(button, _font_regular, 13)
			button.toggle_mode = true
			button.button_group = price_group
			button.pressed.connect(func(): _select_price(price))
			price_buttons.add_child(button)
			_price_buttons[price] = button

	if _entry_lock != "paid_only":
		var free_button := Button.new()
		free_button.text = "Free Roll"
		if not _apply_free_roll_atlas_font(free_button, 13):
			_apply_font(free_button, _font_semibold, 13)
		free_button.toggle_mode = true
		free_button.button_group = price_group
		free_button.pressed.connect(func(): _select_price(0))
		price_buttons.add_child(free_button)
		_price_buttons[0] = free_button

	_select_mode(_selected_mode)
	_select_map_count(_selected_map_count)
	if _entry_lock == "free_only":
		_select_price(0)
	elif _entry_lock == "paid_only":
		_select_price(PRICES[0])
	else:
		_select_price(_selected_price)

func _select_mode(mode_id: String) -> void:
	_selected_mode = mode_id
	if _is_capture_flag_mode(mode_id):
		_selected_map_count = 1
	map_label.visible = not _is_capture_flag_mode(mode_id)
	map_buttons.visible = not _is_capture_flag_mode(mode_id)
	_refresh_summary()

func _select_map_count(count: int) -> void:
	_selected_map_count = count
	_refresh_summary()

func _select_price(price: int) -> void:
	_selected_price = price
	_free_roll = price <= 0
	_refresh_summary()

func _refresh_summary() -> void:
	var price_text := "Free Roll" if _free_roll else "$%d Entry" % _selected_price
	summary_label.text = "%s | %d Maps | %s" % [_mode_label(_selected_mode), _selected_map_count, price_text]

func _mode_label(mode_id: String) -> String:
	for entry in MODES:
		if str(entry.get("id", "")) == mode_id:
			return str(entry.get("label", mode_id))
	return mode_id

func _is_capture_flag_mode(mode_id: String) -> bool:
	return mode_id == "CAPTURE_FLAG" or mode_id == "HIDDEN_CAPTURE_FLAG"

func _on_confirm_pressed() -> void:
	var lobby := preload("res://scenes/ui/VsLobby.tscn").instantiate()
	lobby.configure(_selected_mode, _selected_map_count, _selected_price, _free_roll)
	lobby.closed.connect(func():
		lobby.queue_free()
		visible = true
	)
	add_child(lobby)
	visible = false

func _on_back_pressed() -> void:
	closed.emit()

func _load_fonts() -> void:
	_font_regular = load(FONT_REGULAR_PATH)
	_font_semibold = load(FONT_SEMIBOLD_PATH)
	_font_free_roll_atlas = load(FONT_FREE_ROLL_ATLAS_PATH)

func _apply_static_fonts() -> void:
	_apply_free_roll_atlas_font(title_label, 20)
	_apply_font(back_button, _font_regular, 14)
	_apply_font(mode_label, _font_semibold, 14)
	_apply_font(map_label, _font_semibold, 14)
	_apply_font(price_label, _font_semibold, 14)
	_apply_font(summary_label, _font_regular, 14)
	_apply_font(confirm_button, _font_semibold, 14)

func _apply_font(node: Control, font: Font, size: int) -> void:
	if node == null or font == null:
		return
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", maxi(1, size))

func _text_uses_free_roll_charset(text: String) -> bool:
	var source := text.to_upper()
	for i in source.length():
		var ch := source.substr(i, 1)
		if FONT_FREE_ROLL_SUPPORTED.find(ch) == -1:
			return false
	return true

func _apply_free_roll_atlas_font(node: Control, size: int) -> bool:
	if node == null or _font_free_roll_atlas == null:
		return false
	var raw_text := ""
	if node is Label:
		raw_text = (node as Label).text
	elif node is BaseButton:
		raw_text = (node as BaseButton).text
	if raw_text == "":
		return false
	var upper_text := raw_text.to_upper()
	if not _text_uses_free_roll_charset(upper_text):
		return false
	if node is Label:
		(node as Label).text = upper_text
	elif node is BaseButton:
		(node as BaseButton).text = upper_text
	node.add_theme_font_override("font", _font_free_roll_atlas)
	node.add_theme_font_size_override("font_size", maxi(1, size))
	return true
