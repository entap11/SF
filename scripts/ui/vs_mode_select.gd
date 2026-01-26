extends Control

signal closed

const MODES := [
	{"id": "STAGE_RACE", "label": "Stage Race"},
	{"id": "RACE", "label": "Race"},
	{"id": "MISS_N_OUT", "label": "Miss-N-Out"}
]
const MAP_COUNTS := [3, 5]
const PRICES := [1, 5, 10, 15, 20, 50, 100]

@onready var back_button: Button = $Panel/VBox/Header/Back
@onready var mode_buttons: HBoxContainer = $Panel/VBox/ModeRow/ModeButtons
@onready var map_buttons: HBoxContainer = $Panel/VBox/MapRow/MapButtons
@onready var price_buttons: HBoxContainer = $Panel/VBox/PriceRow/PriceButtons
@onready var summary_label: Label = $Panel/VBox/Summary
@onready var confirm_button: Button = $Panel/VBox/ConfirmRow/Confirm

var _mode_buttons: Dictionary = {}
var _map_buttons: Dictionary = {}
var _price_buttons: Dictionary = {}

var _selected_mode := "STAGE_RACE"
var _selected_map_count := 3
var _selected_price := 1
var _free_roll := false

func _ready() -> void:
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
		button.toggle_mode = true
		button.button_group = mode_group
		button.pressed.connect(func(): _select_mode(mode_id))
		mode_buttons.add_child(button)
		_mode_buttons[mode_id] = button

	var count_group := ButtonGroup.new()
	for count in MAP_COUNTS:
		var button := Button.new()
		button.text = "%d Maps" % count
		button.toggle_mode = true
		button.button_group = count_group
		button.pressed.connect(func(): _select_map_count(count))
		map_buttons.add_child(button)
		_map_buttons[count] = button

	var price_group := ButtonGroup.new()
	for price in PRICES:
		var button := Button.new()
		button.text = "$%d" % price
		button.toggle_mode = true
		button.button_group = price_group
		button.pressed.connect(func(): _select_price(price))
		price_buttons.add_child(button)
		_price_buttons[price] = button

	var free_button := Button.new()
	free_button.text = "Free Roll"
	free_button.toggle_mode = true
	free_button.button_group = price_group
	free_button.pressed.connect(func(): _select_price(0))
	price_buttons.add_child(free_button)
	_price_buttons[0] = free_button

	_select_mode(_selected_mode)
	_select_map_count(_selected_map_count)
	_select_price(_selected_price)

func _select_mode(mode_id: String) -> void:
	_selected_mode = mode_id
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
