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
const CTF_PLAYER_SELECT_PCTS := [0, 25, 35, 50, 100]
const CTF_FLAG_MOVE_COUNTS := [0, 1, 2]

@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var back_button: Button = $Panel/VBox/Header/Back
@onready var map_row: VBoxContainer = $Panel/VBox/MapRow
@onready var mode_label: Label = $Panel/VBox/ModeRow/ModeLabel
@onready var mode_buttons: HBoxContainer = $Panel/VBox/ModeRow/ModeButtons
@onready var map_label: Label = $Panel/VBox/MapRow/MapLabel
@onready var map_buttons: HBoxContainer = $Panel/VBox/MapRow/MapButtons
@onready var ctf_settings_row: VBoxContainer = $Panel/VBox/CtfSettingsRow
@onready var ctf_label: Label = $Panel/VBox/CtfSettingsRow/CtfLabel
@onready var ctf_select_row: HBoxContainer = $Panel/VBox/CtfSettingsRow/CtfSelectRow
@onready var ctf_select_prompt: Label = $Panel/VBox/CtfSettingsRow/CtfSelectRow/CtfSelectPrompt
@onready var ctf_select_buttons: HBoxContainer = $Panel/VBox/CtfSettingsRow/CtfSelectRow/CtfSelectButtons
@onready var ctf_move_prompt: Label = $Panel/VBox/CtfSettingsRow/CtfMoveRow/CtfMovePrompt
@onready var ctf_move_buttons: HBoxContainer = $Panel/VBox/CtfSettingsRow/CtfMoveRow/CtfMoveButtons
@onready var ctf_reveal_row: HBoxContainer = $Panel/VBox/CtfSettingsRow/CtfRevealRow
@onready var ctf_reveal_prompt: Label = $Panel/VBox/CtfSettingsRow/CtfRevealRow/CtfRevealPrompt
@onready var ctf_reveal_buttons: HBoxContainer = $Panel/VBox/CtfSettingsRow/CtfRevealRow/CtfRevealButtons
@onready var price_label: Label = $Panel/VBox/PriceRow/PriceLabel
@onready var price_buttons: HBoxContainer = $Panel/VBox/PriceRow/PriceButtons
@onready var summary_label: Label = $Panel/VBox/Summary
@onready var confirm_button: Button = $Panel/VBox/ConfirmRow/Confirm

var _mode_buttons: Dictionary = {}
var _map_buttons: Dictionary = {}
var _price_buttons: Dictionary = {}
var _ctf_select_pct_buttons: Dictionary = {}
var _ctf_move_count_buttons: Dictionary = {}
var _ctf_reveal_buttons: Dictionary = {}
var _font_regular: Font
var _font_semibold: Font
var _font_free_roll_atlas: Font

var _selected_mode := "STAGE_RACE"
var _selected_map_count := 3
var _selected_price := 1
var _selected_ctf_player_select_pct := 35
var _selected_ctf_flag_move_count_max := 1
var _selected_ctf_flag_move_reveals := true
var _free_roll := false
var _entry_lock := "any" # "any", "free_only", "paid_only"

func configure_entry(free_roll: bool) -> void:
	_entry_lock = "free_only" if free_roll else "paid_only"
	_selected_price = 0 if free_roll else PRICES[0]
	_free_roll = free_roll
	if not _price_buttons.is_empty():
		_build_buttons()

func configure_preset_mode(mode_id: String) -> void:
	var normalized: String = mode_id.strip_edges().to_upper()
	if normalized.is_empty():
		return
	_selected_mode = normalized
	if _is_capture_flag_mode(_selected_mode):
		_selected_map_count = 1
	if _selected_mode == "HIDDEN_CAPTURE_FLAG":
		_selected_ctf_player_select_pct = 100
		_selected_ctf_flag_move_reveals = true
	if is_node_ready() and not _mode_buttons.is_empty():
		_select_mode(_selected_mode)

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
	for child in ctf_select_buttons.get_children():
		child.queue_free()
	for child in ctf_move_buttons.get_children():
		child.queue_free()
	for child in ctf_reveal_buttons.get_children():
		child.queue_free()
	for child in price_buttons.get_children():
		child.queue_free()
	_mode_buttons.clear()
	_map_buttons.clear()
	_price_buttons.clear()
	_ctf_select_pct_buttons.clear()
	_ctf_move_count_buttons.clear()
	_ctf_reveal_buttons.clear()

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

	var ctf_select_group := ButtonGroup.new()
	for pct in CTF_PLAYER_SELECT_PCTS:
		var button := Button.new()
		button.text = "%d%% Pick" % int(pct)
		_apply_font(button, _font_regular, 13)
		button.toggle_mode = true
		button.button_group = ctf_select_group
		button.pressed.connect(Callable(self, "_select_ctf_player_select_pct").bind(int(pct)))
		ctf_select_buttons.add_child(button)
		_ctf_select_pct_buttons[int(pct)] = button

	var ctf_move_group := ButtonGroup.new()
	for move_count in CTF_FLAG_MOVE_COUNTS:
		var button := Button.new()
		button.text = "%d" % int(move_count)
		_apply_font(button, _font_regular, 13)
		button.toggle_mode = true
		button.button_group = ctf_move_group
		button.pressed.connect(Callable(self, "_select_ctf_move_count").bind(int(move_count)))
		ctf_move_buttons.add_child(button)
		_ctf_move_count_buttons[int(move_count)] = button

	var ctf_reveal_group := ButtonGroup.new()
	for reveal_on_move in [true, false]:
		var button := Button.new()
		button.text = "Reveal" if bool(reveal_on_move) else "Hidden"
		_apply_font(button, _font_regular, 13)
		button.toggle_mode = true
		button.button_group = ctf_reveal_group
		button.pressed.connect(Callable(self, "_select_ctf_reveal_on_move").bind(bool(reveal_on_move)))
		ctf_reveal_buttons.add_child(button)
		_ctf_reveal_buttons[bool(reveal_on_move)] = button

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
	_sync_button_states()

func _select_mode(mode_id: String) -> void:
	_selected_mode = mode_id
	if _is_capture_flag_mode(mode_id):
		_selected_map_count = 1
	if _selected_mode == "HIDDEN_CAPTURE_FLAG":
		_selected_ctf_player_select_pct = 100
		_selected_ctf_flag_move_reveals = true
	map_row.visible = not _is_capture_flag_mode(mode_id)
	ctf_settings_row.visible = _is_capture_flag_mode(mode_id)
	ctf_select_row.visible = _selected_mode != "HIDDEN_CAPTURE_FLAG"
	ctf_reveal_row.visible = _selected_mode != "HIDDEN_CAPTURE_FLAG"
	_sync_button_states()
	_refresh_summary()

func _select_map_count(count: int) -> void:
	_selected_map_count = count
	_sync_button_states()
	_refresh_summary()

func _select_price(price: int) -> void:
	_selected_price = price
	_free_roll = price <= 0
	_sync_button_states()
	_refresh_summary()

func _select_ctf_player_select_pct(pct: int) -> void:
	if _selected_mode == "HIDDEN_CAPTURE_FLAG":
		_selected_ctf_player_select_pct = 100
		_sync_button_states()
		_refresh_summary()
		return
	_selected_ctf_player_select_pct = clampi(pct, 0, 100)
	_sync_button_states()
	_refresh_summary()

func _select_ctf_move_count(move_count: int) -> void:
	_selected_ctf_flag_move_count_max = maxi(0, move_count)
	_sync_button_states()
	_refresh_summary()

func _select_ctf_reveal_on_move(reveal_on_move: bool) -> void:
	if _selected_mode == "HIDDEN_CAPTURE_FLAG":
		_selected_ctf_flag_move_reveals = true
		_sync_button_states()
		_refresh_summary()
		return
	_selected_ctf_flag_move_reveals = reveal_on_move
	_sync_button_states()
	_refresh_summary()

func _refresh_summary() -> void:
	var price_text := "Free Roll" if _free_roll else "$%d Entry" % _selected_price
	if _is_capture_flag_mode(_selected_mode):
		var reveal_text := "Reveal on Move" if _selected_ctf_flag_move_reveals else "Keep Hidden"
		var selection_text := "Player Picks Flag" if _selected_mode == "HIDDEN_CAPTURE_FLAG" else "%d%% Player Pick" % _selected_ctf_player_select_pct
		summary_label.text = "%s | %s | %d Moves | %s | %s" % [
			_mode_label(_selected_mode),
			selection_text,
			_selected_ctf_flag_move_count_max,
			reveal_text,
			price_text
		]
		return
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
	var options: Dictionary = {}
	if _is_capture_flag_mode(_selected_mode):
		options["ctf_flag_selection_mode"] = "player_select" if _selected_mode == "HIDDEN_CAPTURE_FLAG" else "weighted"
		options["ctf_player_select_pct"] = 100 if _selected_mode == "HIDDEN_CAPTURE_FLAG" else _selected_ctf_player_select_pct
		options["ctf_randomize_flag_hive"] = true
		options["ctf_flag_move_count_max"] = _selected_ctf_flag_move_count_max
		options["ctf_flag_move_reveals"] = true if _selected_mode == "HIDDEN_CAPTURE_FLAG" else _selected_ctf_flag_move_reveals
	lobby.configure(_selected_mode, _selected_map_count, _selected_price, _free_roll, options)
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
	_apply_font(ctf_label, _font_semibold, 14)
	_apply_font(ctf_select_prompt, _font_regular, 13)
	_apply_font(ctf_move_prompt, _font_regular, 13)
	_apply_font(ctf_reveal_prompt, _font_regular, 13)
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

func _sync_button_states() -> void:
	for mode_id in _mode_buttons.keys():
		var button := _mode_buttons.get(mode_id) as BaseButton
		if button != null:
			button.button_pressed = str(mode_id) == _selected_mode
	for count in _map_buttons.keys():
		var button := _map_buttons.get(count) as BaseButton
		if button != null:
			button.button_pressed = int(count) == _selected_map_count
	for price in _price_buttons.keys():
		var button := _price_buttons.get(price) as BaseButton
		if button != null:
			button.button_pressed = int(price) == _selected_price
	for pct in _ctf_select_pct_buttons.keys():
		var button := _ctf_select_pct_buttons.get(pct) as BaseButton
		if button != null:
			button.button_pressed = int(pct) == _selected_ctf_player_select_pct
	for move_count in _ctf_move_count_buttons.keys():
		var button := _ctf_move_count_buttons.get(move_count) as BaseButton
		if button != null:
			button.button_pressed = int(move_count) == _selected_ctf_flag_move_count_max
	for reveal_key in _ctf_reveal_buttons.keys():
		var button := _ctf_reveal_buttons.get(reveal_key) as BaseButton
		if button != null:
			button.button_pressed = bool(reveal_key) == _selected_ctf_flag_move_reveals
