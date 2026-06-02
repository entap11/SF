class_name AsyncContestDashPanel
extends Panel

const AsyncContestConfigStoreScript := preload("res://scripts/state/async_contest_config_store.gd")

signal close_requested
signal config_saved(config: Dictionary)

var _store: RefCounted = AsyncContestConfigStoreScript.new()
var _scope: String = AsyncContestConfigStoreScript.SCOPE_WEEKLY
var _map_count: int = 3
var _map_entries: Array[Dictionary] = []
var _scope_buttons: Dictionary = {}
var _count_buttons: Dictionary = {}
var _map_dropdowns: Array[OptionButton] = []
var _bot_dropdown: OptionButton = null
var _tier_dropdown: OptionButton = null
var _prize_dropdown: OptionButton = null
var _amount_edit: LineEdit = null
var _randomizer_slider: HSlider = null
var _randomizer_value_label: Label = null
var _stage_rows: VBoxContainer = null
var _status_label: Label = null
var _content_top_offset: float = 0.0

func set_content_top_offset(value: float) -> void:
	_content_top_offset = maxf(0.0, value)
	if is_node_ready():
		_update_outer_padding()

func _ready() -> void:
	visible = false
	_map_entries = _store.available_async_maps()
	_build_ui()
	_load_current_config()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	var margin := MarginContainer.new()
	margin.name = "AsyncContestDashMargin"
	margin.anchor_left = 0.0
	margin.anchor_top = 0.0
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "AsyncContestDashRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title := Label.new()
	title.text = "ASYNC CONTEST DASH"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)
	var save_button := Button.new()
	save_button.text = "SAVE"
	save_button.custom_minimum_size = Vector2(110.0, 44.0)
	save_button.pressed.connect(_save_current_config)
	header.add_child(save_button)
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(110.0, 44.0)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)

	var scope_row := HBoxContainer.new()
	scope_row.add_theme_constant_override("separation", 8)
	root.add_child(scope_row)
	for scope in AsyncContestConfigStoreScript.SCOPES:
		var button := Button.new()
		button.text = scope
		button.toggle_mode = true
		button.disabled = scope == AsyncContestConfigStoreScript.SCOPE_DAILY
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 42.0)
		scope_row.add_child(button)
		_scope_buttons[scope] = button
		if scope != AsyncContestConfigStoreScript.SCOPE_DAILY:
			button.pressed.connect(func(scope_value: String = scope) -> void:
				_set_scope(scope_value)
			)

	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 8)
	root.add_child(count_row)
	for count in AsyncContestConfigStoreScript.MAP_COUNTS:
		var button := Button.new()
		button.text = "%d MAP" % count
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 42.0)
		count_row.add_child(button)
		_count_buttons[count] = button
		button.pressed.connect(func(count_value: int = count) -> void:
			_set_map_count(count_value)
		)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)

	var maps_label := Label.new()
	maps_label.text = "MAPS"
	maps_label.add_theme_font_size_override("font_size", 16)
	body.add_child(maps_label)
	_stage_rows = VBoxContainer.new()
	_stage_rows.add_theme_constant_override("separation", 8)
	body.add_child(_stage_rows)

	var bot_grid := GridContainer.new()
	bot_grid.columns = 2
	bot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_grid.add_theme_constant_override("h_separation", 12)
	bot_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(bot_grid)
	_bot_dropdown = _add_labeled_dropdown(bot_grid, "Bot", AsyncContestConfigStoreScript.BOT_STYLES)
	_tier_dropdown = _add_labeled_dropdown(bot_grid, "Difficulty", AsyncContestConfigStoreScript.BOT_TIERS)
	_prize_dropdown = _add_labeled_dropdown(bot_grid, "Prize", AsyncContestConfigStoreScript.PRIZE_TYPES)
	_add_labeled_amount(bot_grid)

	var randomizer_row := HBoxContainer.new()
	randomizer_row.add_theme_constant_override("separation", 12)
	randomizer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(randomizer_row)
	var randomizer_label := Label.new()
	randomizer_label.text = "Randomizer"
	randomizer_label.custom_minimum_size = Vector2(120.0, 0.0)
	randomizer_row.add_child(randomizer_label)
	_randomizer_slider = HSlider.new()
	_randomizer_slider.min_value = 0.0
	_randomizer_slider.max_value = 100.0
	_randomizer_slider.step = 1.0
	_randomizer_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	randomizer_row.add_child(_randomizer_slider)
	_randomizer_value_label = Label.new()
	_randomizer_value_label.custom_minimum_size = Vector2(72.0, 0.0)
	_randomizer_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	randomizer_row.add_child(_randomizer_value_label)
	_randomizer_slider.value_changed.connect(func(value: float) -> void:
		_randomizer_value_label.text = "%d%%" % int(round(value))
	)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_status_label)
	_update_outer_padding()

func _update_outer_padding() -> void:
	var margin: MarginContainer = get_node_or_null("AsyncContestDashMargin") as MarginContainer
	if margin == null:
		return
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_theme_constant_override("margin_top", int(maxf(24.0, _content_top_offset + 12.0)))

func _add_labeled_dropdown(parent: GridContainer, label_text: String, values: Array) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(120.0, 42.0)
	parent.add_child(label)
	var dropdown := OptionButton.new()
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dropdown.custom_minimum_size = Vector2(220.0, 42.0)
	for value_any in values:
		var value: String = str(value_any)
		dropdown.add_item(value.capitalize())
		dropdown.set_item_metadata(dropdown.get_item_count() - 1, value)
	parent.add_child(dropdown)
	return dropdown

func _add_labeled_amount(parent: GridContainer) -> void:
	var label := Label.new()
	label.text = "Amount"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(120.0, 42.0)
	parent.add_child(label)
	_amount_edit = LineEdit.new()
	_amount_edit.placeholder_text = "Open"
	_amount_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_amount_edit.custom_minimum_size = Vector2(220.0, 42.0)
	parent.add_child(_amount_edit)

func _set_scope(scope: String) -> void:
	_scope = AsyncContestConfigStoreScript.normalize_scope(scope)
	_load_current_config()

func _set_map_count(map_count: int) -> void:
	_map_count = AsyncContestConfigStoreScript.normalize_map_count(map_count)
	_load_current_config()

func _load_current_config() -> void:
	_refresh_tabs()
	_rebuild_stage_dropdowns()
	var config: Dictionary = _store.config_for(_scope, _map_count)
	var paths_any: Variant = config.get("map_paths", [])
	if typeof(paths_any) == TYPE_ARRAY:
		var paths: Array = paths_any as Array
		for i in range(_map_dropdowns.size()):
			var path: String = str(paths[i]) if i < paths.size() else ""
			_select_dropdown_metadata(_map_dropdowns[i], path)
	_select_dropdown_metadata(_bot_dropdown, str(config.get("bot_style", "balancer")))
	_select_dropdown_metadata(_tier_dropdown, str(config.get("bot_tier", "medium")))
	_select_dropdown_metadata(_prize_dropdown, str(config.get("prize_type", "Honey")))
	if _amount_edit != null:
		_amount_edit.text = str(config.get("amount", ""))
	if _randomizer_slider != null:
		_randomizer_slider.value = clampi(int(config.get("randomizer_pct", 0)), 0, 100)
	if _randomizer_value_label != null:
		_randomizer_value_label.text = "%d%%" % clampi(int(config.get("randomizer_pct", 0)), 0, 100)
	if _status_label != null:
		_status_label.text = "Daily is reserved. Active contest settings save locally for weekly, monthly, and seasonal async launches."

func _refresh_tabs() -> void:
	for scope_any in _scope_buttons.keys():
		var scope: String = str(scope_any)
		var button: Button = _scope_buttons.get(scope) as Button
		if button != null:
			button.button_pressed = scope == _scope
	for count_any in _count_buttons.keys():
		var count: int = int(count_any)
		var button: Button = _count_buttons.get(count) as Button
		if button != null:
			button.button_pressed = count == _map_count

func _rebuild_stage_dropdowns() -> void:
	if _stage_rows == null:
		return
	for child in _stage_rows.get_children():
		child.queue_free()
	_map_dropdowns.clear()
	for i in range(_map_count):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stage_rows.add_child(row)
		var label := Label.new()
		label.text = "Stage %d" % (i + 1)
		label.custom_minimum_size = Vector2(120.0, 42.0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var dropdown := OptionButton.new()
		dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dropdown.custom_minimum_size = Vector2(320.0, 42.0)
		for entry in _map_entries:
			var title: String = str(entry.get("title", entry.get("map_id", "Map")))
			var map_id: String = str(entry.get("map_id", ""))
			dropdown.add_item("%s  (%s)" % [title, map_id])
			dropdown.set_item_metadata(dropdown.get_item_count() - 1, str(entry.get("path", "")))
		row.add_child(dropdown)
		_map_dropdowns.append(dropdown)

func _save_current_config() -> void:
	var paths: Array[String] = []
	for dropdown in _map_dropdowns:
		paths.append(str(dropdown.get_selected_metadata()).strip_edges())
	var config: Dictionary = _store.config_for(_scope, _map_count)
	config["map_paths"] = paths
	config["bot_style"] = _selected_metadata(_bot_dropdown, "balancer")
	config["bot_tier"] = _selected_metadata(_tier_dropdown, "medium")
	config["prize_type"] = _selected_metadata(_prize_dropdown, "Honey")
	config["amount"] = _amount_edit.text.strip_edges() if _amount_edit != null else ""
	config["randomizer_pct"] = int(round(_randomizer_slider.value)) if _randomizer_slider != null else 0
	config = _store.update_config(_scope, _map_count, config)
	if _status_label != null:
		_status_label.text = "%s %d-map async contest saved." % [_scope.capitalize(), _map_count]
	config_saved.emit(config)

func _selected_metadata(dropdown: OptionButton, fallback: String) -> String:
	if dropdown == null or dropdown.selected < 0:
		return fallback
	return str(dropdown.get_selected_metadata()).strip_edges()

func _select_dropdown_metadata(dropdown: OptionButton, value: String) -> void:
	if dropdown == null:
		return
	var clean: String = value.strip_edges()
	for i in range(dropdown.get_item_count()):
		if str(dropdown.get_item_metadata(i)).strip_edges() == clean:
			dropdown.select(i)
			return
	if dropdown.get_item_count() > 0:
		dropdown.select(0)
