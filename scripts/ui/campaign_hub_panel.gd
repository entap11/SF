extends Panel

signal closed
const Catalog = preload("res://scripts/state/campaign_catalog.gd")
const Typography = preload("res://scripts/ui/ui_typography.gd")
const Preview = preload("res://scripts/ui/map_schematic_preview.gd")
const MapLoader = preload("res://scripts/maps/map_loader.gd")

var mode := "campaign"
var selected_id := ""
var _runtime: Node
var _body: VBoxContainer
var _margin: MarginContainer
var _bot: OptionButton
var _tier: OptionButton
var _map: OptionButton
var _level_list: OptionButton
var _heading: Label
var _details: Label
var _records: Label
var _notice: Label
var _preview: Control
var _play: Button
var _close: Button
var _top_inset := 0.0
var _selecting := false

func _ready() -> void:
	_runtime = get_node("/root/CampaignRuntime")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("10151e")
	add_theme_stylebox_override("panel", surface)
	add_theme_font_override("font", Typography.regular_font())
	add_theme_color_override("font_color", Color("f3f0e8"))
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 20)
	_margin.add_child(frame)
	_label(frame, "CAMPAIGN" if mode == "campaign" else "JUKEBOX", 64)
	_label(frame, "Find your next challenge." if mode == "campaign" else "Choose your opponent. Find your campaign level.", 44)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 20)
	scroll.add_child(_body)
	if mode == "campaign":
		_label(_body, "Browse levels", 44)
		_level_list = _option(_body)
		for level in Catalog.levels():
			var unlocked: bool = _runtime.store.is_unlocked(_runtime.player_id(), str(level.id))
			_level_list.add_item("%02d · %s%s" % [int(level.number), str(level.title), "" if unlocked else " · Locked"])
			_level_list.set_item_metadata(_level_list.item_count - 1, str(level.id))
		_level_list.item_selected.connect(func(index: int) -> void: select_level(str(_level_list.get_item_metadata(index))))
	else:
		_label(_body, "Opponent", 44)
		_bot = _option(_body)
		for bot in Catalog.BOTS:
			_bot.add_item(str(bot).replace("_", " ").capitalize())
		_bot.item_selected.connect(func(_index: int) -> void: _refresh_filter_options())
		_label(_body, "Difficulty", 44)
		_tier = _option(_body)
		for tier in Catalog.TIERS:
			_tier.add_item(str(tier).capitalize())
		_tier.item_selected.connect(func(_index: int) -> void: _refresh_filter_options())
		_label(_body, "Map / variant", 44)
		_map = _option(_body)
		_map.item_selected.connect(func(index: int) -> void: select_level(str(_map.get_item_metadata(index))))
	_heading = _label(_body, "", 54)
	_details = _label(_body, "", 44)
	_preview = Preview.new()
	_preview.custom_minimum_size = Vector2(0, 300)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_preview)
	_records = _label(_body, "", 44)
	_notice = _label(frame, "", 40)
	_play = _button(frame, "PLAY LEVEL")
	_play.name = "PlayLevel"
	_style_action(_play, true)
	_play.pressed.connect(_launch)
	_close = _button(frame, "BACK TO MAIN MENU" if mode == "campaign" else "BACK TO DASHBOARD")
	_close.name = "Back"
	_close.pressed.connect(func() -> void: closed.emit())
	resized.connect(_layout)
	_layout()
	select_level(selected_id if not selected_id.is_empty() else _runtime.store.continue_id(_runtime.player_id()))

func _label(parent: Node, value: String, size_px: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size_px)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 132)
	button.add_theme_font_size_override("font_size", 44)
	_style_action(button, false)
	parent.add_child(button)
	return button

func _style_action(button: Button, primary: bool) -> void:
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("493d20") if primary else Color("202938")
	surface.border_color = Color("e4bd63") if primary else Color("465468")
	surface.set_border_width_all(2)
	surface.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", surface)
	button.add_theme_stylebox_override("hover", surface)
	button.add_theme_stylebox_override("pressed", surface)
	button.add_theme_color_override("font_color", Color("ffe4a5") if primary else Color("f3f0e8"))

func _option(parent: Node) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(0, 132)
	option.fit_to_longest_item = false
	option.add_theme_font_size_override("font_size", 44)
	option.get_popup().add_theme_font_size_override("font_size", 44)
	option.get_popup().add_theme_constant_override("v_separation", 24)
	parent.add_child(option)
	return option

func set_content_top_offset(inset: float) -> void:
	_top_inset = maxf(0, inset)
	_layout()

func _layout() -> void:
	if _margin == null:
		return
	_margin.add_theme_constant_override("margin_left", 32)
	_margin.add_theme_constant_override("margin_right", 32)
	var top: float = _top_inset
	var bottom: float = 0.0
	if OS.has_feature("android") or OS.has_feature("ios"):
		var window_size := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var scale_y: float = size.y / maxf(1.0, window_size.y)
		top = maxf(top, safe.position.y * scale_y)
		bottom = maxf(0.0, (window_size.y - safe.end.y) * scale_y)
	_margin.add_theme_constant_override("margin_top", 24 + int(top))
	_margin.add_theme_constant_override("margin_bottom", 24 + int(bottom))

func _refresh_filter_options(preferred_id: String = "") -> void:
	if _selecting:
		return
	_map.clear()
	for level in Catalog.levels():
		if str(level.bot) == str(Catalog.BOTS[_bot.selected]) and str(level.difficulty) == str(Catalog.TIERS[_tier.selected]):
			_map.add_item("%s · Level %d" % [str(level.title), int(level.number)])
			_map.set_item_metadata(_map.item_count - 1, str(level.id))
			if str(level.id) == preferred_id:
				_map.select(_map.item_count - 1)
	if _map.item_count > 0:
		select_level(str(_map.get_item_metadata(maxi(0, _map.selected))))

func select_level(id: String) -> void:
	selected_id = id
	if _details == null:
		return
	var level: Dictionary = Catalog.find(id)
	if level.is_empty():
		_play.disabled = true
		_notice.text = "This challenge is unavailable."
		return
	if mode == "jukebox" and not _selecting:
		_selecting = true
		_bot.select(Catalog.BOTS.find(str(level.bot)))
		_tier.select(Catalog.TIERS.find(str(level.difficulty)))
		_selecting = false
		# Rebuild dependent map choices without recursively selecting again.
		_map.clear()
		for candidate in Catalog.levels():
			if str(candidate.bot) == str(level.bot) and str(candidate.difficulty) == str(level.difficulty):
				_map.add_item("%s · Level %d" % [str(candidate.title), int(candidate.number)])
				_map.set_item_metadata(_map.item_count - 1, str(candidate.id))
				if str(candidate.id) == id:
					_map.select(_map.item_count - 1)
	elif _level_list != null:
		_level_list.select(int(level.number) - 1)
	var stats: Dictionary = _runtime.store.snapshot(_runtime.player_id(), level)
	_heading.text = "LEVEL %02d · %s\n%s" % [int(level.number), str(level.title), str(level.chapter)]
	_details.text = "%s · %s\nStingers: %d / 3 · Personal best: %s\n1: Win   2: %s   3: %s\nFixed challenge · No buffs" % [str(level.bot).replace("_", " ").capitalize(), str(level.difficulty).capitalize(), int(stats.get("stingers", 0)), Catalog.time_text(int(stats.get("best_ms", 0))), Catalog.time_text(int(level.two_stinger_ms)), Catalog.time_text(int(level.three_stinger_ms))]
	var loaded: Dictionary = MapLoader.load_map(str(level.map_path))
	_preview.call("set_map_data", loaded.get("data", {}))
	var lines: PackedStringArray = ["LEVEL LEADERBOARD · ALL TIME", "Records on this device"]
	var board: Array[Dictionary] = _runtime.store.board(level)
	for i in range(mini(board.size(), 10)):
		lines.append("%d. %s   %s" % [i + 1, str(board[i].handle), Catalog.time_text(int(board[i].best_ms))])
	if board.is_empty():
		lines.append("No winning times yet. Set your first record.")
	_records.text = "\n".join(lines)
	var unlocked: bool = _runtime.store.is_unlocked(_runtime.player_id(), id)
	_play.disabled = not unlocked or not bool(loaded.get("ok", false))
	var action: String = "CONTINUE" if mode == "campaign" and id == str(_runtime.store.continue_id(_runtime.player_id())) else "PLAY"
	_play.text = "%s · LEVEL %d" % [action, int(level.number)] if unlocked else "LEVEL LOCKED"
	_notice.text = "A completed attempt opens the next level. Wins earn stingers and records." if unlocked else "Complete level %d to unlock. A win or loss counts." % (int(level.number) - 1)

func restore_runtime_state(snapshot: Dictionary) -> void:
	select_level(str(snapshot.get("level_id", selected_id)))

func _launch() -> void:
	var response: Dictionary = _runtime.request_launch(selected_id, mode)
	if not bool(response.get("ok", false)):
		_notice.text = str(response.get("error", "Unable to start level."))
