extends Panel

signal close_requested()
signal store_requested()

const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")
const UITypography = preload("res://scripts/ui/ui_typography.gd")

@export var battle_pass_state_path: NodePath = NodePath("/root/BattlePassState")

const OFFSHOOT_TRACKS: Array[String] = ["premium", "elite"]
const LEVEL_RANGES: Array[Dictionary] = [
	{"label": "1-25", "level": 1},
	{"label": "26-50", "level": 26},
	{"label": "51-75", "level": 51},
	{"label": "76-100", "level": 76}
]
const PANEL_BG: Color = Color(0.035, 0.038, 0.046, 0.94)
const PANEL_BORDER: Color = Color(0.95, 0.75, 0.26, 0.28)
const SECTION_BG: Color = Color(0.055, 0.06, 0.073, 0.82)
const CARD_BG: Color = Color(0.075, 0.080, 0.095, 0.90)
const CARD_BORDER: Color = Color(0.42, 0.36, 0.20, 0.62)
const TRACK_BG: Color = Color(0.035, 0.038, 0.046, 0.72)
const TRACK_BORDER: Color = Color(0.35, 0.35, 0.42, 0.45)
const GOLD: Color = Color(1.0, 0.82, 0.28, 1.0)
const MUTED: Color = Color(0.75, 0.78, 0.84, 0.78)
const GOOD: Color = Color(0.56, 0.88, 0.58, 1.0)
const LOCKED: Color = Color(0.52, 0.55, 0.62, 0.82)
const TOUCH_LAYOUT_MAX_WIDTH: float = 1100.0
const TOUCH_LAYOUT_SCALE: float = 1.18
const WARPATH_VISUAL_SCALE: float = 2.0
const TOUCH_PANEL_MARGIN_X: float = 34.0
const TOUCH_PANEL_TOP: float = 128.0
const TOUCH_PANEL_BOTTOM: float = 132.0

var _state: Node = null
var _last_snapshot: Dictionary = {}
var _texture_cache: Dictionary = {}
var _level_cards: Dictionary = {}

var _root: MarginContainer = null
var _season_label: Label = null
var _summary_label: Label = null
var _wallet_label: Label = null
var _veteran_label: Label = null
var _event_label: Label = null
var _progress_title_label: Label = null
var _progress_bar: ProgressBar = null
var _levels_scroll: ScrollContainer = null
var _cards_vbox: VBoxContainer = null
var _range_bar: HBoxContainer = null
var _premium_button: Button = null
var _elite_button: Button = null
var _claim_current_button: Button = null
var _claim_all_button: Button = null
var _veteran_start_button: Button = null
var _veteran_opt_out_button: Button = null
var _close_button: Button = null
var _font_regular: Font = null
var _font_semibold: Font = null

func _ready() -> void:
	_load_fonts()
	_apply_responsive_frame()
	_build_layout()
	_bind_state()
	_refresh_from_state()

func _exit_tree() -> void:
	if _state == null:
		return
	if _state.has_signal("battle_pass_state_changed") and _state.battle_pass_state_changed.is_connected(_on_state_changed):
		_state.battle_pass_state_changed.disconnect(_on_state_changed)
	if _state.has_signal("battle_pass_event") and _state.battle_pass_event.is_connected(_on_pass_event):
		_state.battle_pass_event.disconnect(_on_pass_event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_frame()
		call_deferred("_refresh_card_sizes")

func _load_fonts() -> void:
	_font_regular = UITypography.regular_font()
	_font_semibold = UITypography.semibold_font()

func _apply_font(control: Control, font: Font, size: int) -> void:
	UITypography.apply_font(control, font, size, WARPATH_VISUAL_SCALE)

func _apply_responsive_frame() -> void:
	if not _uses_touch_layout():
		return
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	offset_left = TOUCH_PANEL_MARGIN_X
	offset_top = TOUCH_PANEL_TOP
	offset_right = -TOUCH_PANEL_MARGIN_X
	offset_bottom = -TOUCH_PANEL_BOTTOM

func _build_layout() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _style(PANEL_BG, PANEL_BORDER, 2, 8))

	_root = MarginContainer.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	var outer_margin: int = _scaled_int(16 if _uses_touch_layout() else 24)
	_root.add_theme_constant_override("margin_left", outer_margin)
	_root.add_theme_constant_override("margin_top", outer_margin)
	_root.add_theme_constant_override("margin_right", outer_margin)
	_root.add_theme_constant_override("margin_bottom", outer_margin)
	add_child(_root)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", _scaled_int(8 if _uses_touch_layout() else 12))
	_root.add_child(vbox)

	vbox.add_child(_build_header())
	vbox.add_child(_build_actions())

	_veteran_label = Label.new()
	_veteran_label.visible = false
	_veteran_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_veteran_label.add_theme_color_override("font_color", GOLD)
	_apply_font(_veteran_label, _font_regular, 16 if _uses_touch_layout() else 13)
	vbox.add_child(_veteran_label)

	var body := Panel.new()
	body.name = "LevelsBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_stylebox_override("panel", _style(Color(0.02, 0.022, 0.028, 0.52), Color(0.95, 0.77, 0.28, 0.14), 1, 6))
	vbox.add_child(body)

	var body_margin := MarginContainer.new()
	body_margin.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	var body_pad: int = _scaled_int(8 if _uses_touch_layout() else 14)
	body_margin.add_theme_constant_override("margin_left", body_pad)
	body_margin.add_theme_constant_override("margin_top", body_pad)
	body_margin.add_theme_constant_override("margin_right", body_pad)
	body_margin.add_theme_constant_override("margin_bottom", body_pad)
	body.add_child(body_margin)

	_levels_scroll = ScrollContainer.new()
	_levels_scroll.name = "LevelsScroll"
	_levels_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_levels_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_levels_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_levels_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_margin.add_child(_levels_scroll)

	_cards_vbox = VBoxContainer.new()
	_cards_vbox.name = "Cards"
	_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_vbox.add_theme_constant_override("separation", _scaled_int(10 if _uses_touch_layout() else 14))
	_levels_scroll.add_child(_cards_vbox)
	_enable_touch_drag_scroll(_levels_scroll)

	vbox.add_child(_build_range_bar())

	_event_label = Label.new()
	_event_label.name = "EventLog"
	_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_label.add_theme_color_override("font_color", MUTED)
	_apply_font(_event_label, _font_regular, 14 if _uses_touch_layout() else 12)
	vbox.add_child(_event_label)

	vbox.add_child(_build_footer_close())

func _build_header() -> Control:
	var header := Panel.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0.0, _scaled_float(128.0 if _uses_touch_layout() else 142.0))
	header.add_theme_stylebox_override("panel", _style(SECTION_BG, Color(0.95, 0.77, 0.28, 0.22), 1, 6))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	var header_pad: int = _scaled_int(10 if _uses_touch_layout() else 14)
	margin.add_theme_constant_override("margin_left", _scaled_int(12 if _uses_touch_layout() else 16))
	margin.add_theme_constant_override("margin_top", header_pad)
	margin.add_theme_constant_override("margin_right", _scaled_int(12 if _uses_touch_layout() else 16))
	margin.add_theme_constant_override("margin_bottom", header_pad)
	header.add_child(margin)

	var row: BoxContainer = VBoxContainer.new() if _uses_touch_layout() else HBoxContainer.new()
	row.add_theme_constant_override("separation", _scaled_int(8 if _uses_touch_layout() else 18))
	margin.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	row.add_child(text_col)

	var title := Label.new()
	title.text = "WARPATH"
	_apply_font(title, _font_semibold, 28 if _uses_touch_layout() else 22)
	title.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0, 1.0))
	text_col.add_child(title)

	_season_label = Label.new()
	_apply_font(_season_label, _font_semibold, 17 if _uses_touch_layout() else 13)
	_season_label.add_theme_color_override("font_color", GOLD)
	text_col.add_child(_season_label)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(_summary_label, _font_regular, 16 if _uses_touch_layout() else 13)
	_summary_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96, 0.95))
	text_col.add_child(_summary_label)

	_wallet_label = Label.new()
	_wallet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(_wallet_label, _font_regular, 15 if _uses_touch_layout() else 12)
	_wallet_label.add_theme_color_override("font_color", MUTED)
	text_col.add_child(_wallet_label)

	var progress_col := VBoxContainer.new()
	progress_col.custom_minimum_size = Vector2(0.0 if _uses_touch_layout() else 230.0, 0.0)
	progress_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_col.add_theme_constant_override("separation", 8)
	row.add_child(progress_col)

	_progress_title_label = Label.new()
	_progress_title_label.text = "NECTAR"
	_progress_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_progress_title_label, _font_semibold, 15 if _uses_touch_layout() else 12)
	_progress_title_label.add_theme_color_override("font_color", GOLD)
	progress_col.add_child(_progress_title_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.show_percentage = true
	_progress_bar.custom_minimum_size = Vector2(0.0, _scaled_float(26.0 if _uses_touch_layout() else 30.0))
	_apply_font(_progress_bar, _font_semibold, 13 if _uses_touch_layout() else 11)
	progress_col.add_child(_progress_bar)

	return header

func _build_actions() -> Control:
	var row: Container
	if _uses_touch_layout():
		var grid := GridContainer.new()
		grid.columns = 2
		row = grid
	else:
		row = HBoxContainer.new()
	row.name = "Actions"
	row.add_theme_constant_override("h_separation", _scaled_int(8))
	row.add_theme_constant_override("v_separation", _scaled_int(8))
	row.add_theme_constant_override("separation", _scaled_int(8))
	_premium_button = _make_button("Buy Premium")
	_elite_button = _make_button("Buy Elite")
	_claim_current_button = _make_button("Claim Current")
	_claim_all_button = _make_button("Claim All")
	_veteran_start_button = _make_button("Veteran Start")
	_veteran_opt_out_button = _make_button("Veteran Opt-Out")
	for button in [_premium_button, _elite_button, _claim_current_button, _claim_all_button, _veteran_start_button, _veteran_opt_out_button]:
		row.add_child(button)
	_premium_button.pressed.connect(func() -> void:
		store_requested.emit()
	)
	_elite_button.pressed.connect(func() -> void:
		store_requested.emit()
	)
	_claim_current_button.pressed.connect(func() -> void:
		_claim_track(int(_last_snapshot.get("battle_pass_level", 1)), "free")
	)
	_claim_all_button.pressed.connect(func() -> void:
		_call_state("intent_claim_all_available", [])
	)
	_veteran_start_button.pressed.connect(func() -> void:
		var flags: Dictionary = {
			"member_this_season": true,
			"member_last_season": true,
			"played_every_mode_last_season": true,
			"money_async_last_season": true,
			"money_vs_last_season": true
		}
		_call_state("intent_apply_veteran_start", [flags, false])
	)
	_veteran_opt_out_button.pressed.connect(func() -> void:
		_call_state("intent_apply_veteran_start", [{}, true])
	)
	return row

func _build_footer_close() -> Control:
	var row := HBoxContainer.new()
	row.name = "FooterClose"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_close_button = _make_close_button()
	_close_button.pressed.connect(func() -> void:
		close_requested.emit()
	)
	row.add_child(_close_button)
	return row

func _build_range_bar() -> Control:
	var panel := Panel.new()
	panel.name = "LevelRangeBar"
	panel.custom_minimum_size = Vector2(0.0, _scaled_float(52.0 if _uses_touch_layout() else 58.0))
	panel.add_theme_stylebox_override("panel", _style(SECTION_BG, Color(0.95, 0.77, 0.28, 0.20), 1, 6))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	_range_bar = HBoxContainer.new()
	_range_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_range_bar.add_theme_constant_override("separation", 10)
	margin.add_child(_range_bar)
	for range_def in LEVEL_RANGES:
		var button := _make_button(str(range_def.get("label", "")))
		button.custom_minimum_size = Vector2(_scaled_float(132.0), _scaled_float(40.0))
		var level: int = int(range_def.get("level", 1))
		button.pressed.connect(func() -> void:
			_scroll_to_level(level)
		)
		_range_bar.add_child(button)
	return panel

func _bind_state() -> void:
	_state = get_node_or_null(battle_pass_state_path)
	if _state == null:
		return
	if _state.has_signal("battle_pass_state_changed") and not _state.battle_pass_state_changed.is_connected(_on_state_changed):
		_state.battle_pass_state_changed.connect(_on_state_changed)
	if _state.has_signal("battle_pass_event") and not _state.battle_pass_event.is_connected(_on_pass_event):
		_state.battle_pass_event.connect(_on_pass_event)

func _refresh_from_state() -> void:
	if _state == null or not _state.has_method("get_snapshot"):
		return
	var snapshot_any: Variant = _state.call("get_snapshot")
	if typeof(snapshot_any) == TYPE_DICTIONARY:
		_on_state_changed(snapshot_any as Dictionary)

func _on_state_changed(snapshot: Dictionary) -> void:
	_last_snapshot = snapshot.duplicate(true)
	_render_summary(snapshot)
	_render_level_cards(snapshot.get("rows", []) as Array)
	_update_action_state(snapshot)
	call_deferred("_refresh_card_sizes")

func _render_summary(snapshot: Dictionary) -> void:
	var season_id: String = str(snapshot.get("season_id", "season"))
	var remaining_days: int = int(floor(float(int(snapshot.get("season_seconds_remaining", 0))) / 86400.0))
	var projection_any: Variant = snapshot.get("prestige_projection", {})
	var projection: Dictionary = projection_any as Dictionary if typeof(projection_any) == TYPE_DICTIONARY else {}
	var growth_factor: float = float(projection.get("growth_factor", 1.0))
	_season_label.text = "Season %s | %dd left | Prestige growth x%.2f" % [season_id, remaining_days, growth_factor]

	var level: int = int(snapshot.get("battle_pass_level", 1))
	var total_levels: int = int(snapshot.get("total_levels", 120))
	var next_level: int = int(snapshot.get("next_level", mini(total_levels, level + 1)))
	var total_nectar: int = int(snapshot.get("battle_pass_xp", 0))
	var nectar_into_level: int = int(snapshot.get("xp_into_level", 0))
	var nectar_for_level: int = int(snapshot.get("xp_for_level", 0))
	var nectar_needed: int = maxi(0, nectar_for_level - nectar_into_level)
	var progress_ratio: float = clampf(float(snapshot.get("progress_ratio", 0.0)), 0.0, 1.0)
	var side_quest_paths: int = int(snapshot.get("side_quest_paths_available", 1))
	var premium_owned: bool = bool(snapshot.get("premium_owned", false))
	var elite_owned: bool = bool(snapshot.get("elite_owned", false))
	var speed_text: String = "Elite speed x1.30" if elite_owned else ("Premium speed x1.20" if premium_owned else "Base speed x1.00")
	if _uses_touch_layout():
		_summary_label.text = "Level %d/%d | %s | Paths %d" % [
			level,
			total_levels,
			speed_text,
			side_quest_paths
		]
	else:
		_summary_label.text = "Level %d/%d | %s | Paths %d | Premium %s | Elite %s" % [
			level,
			total_levels,
			speed_text,
			side_quest_paths,
			"YES" if premium_owned else "NO",
			"YES" if elite_owned else "NO"
		]

	var wallet_any: Variant = snapshot.get("wallet", {})
	var wallet: Dictionary = wallet_any as Dictionary if typeof(wallet_any) == TYPE_DICTIONARY else {}
	var inventory_any: Variant = snapshot.get("inventory", {})
	var inventory: Dictionary = inventory_any as Dictionary if typeof(inventory_any) == TYPE_DICTIONARY else {}
	if _uses_touch_layout():
		_wallet_label.text = "Nectar %d | Need %d for L%d | Honey %d | Tickets %d" % [
			total_nectar,
			nectar_needed,
			next_level,
			int(wallet.get("honey", 0)),
			int(inventory.get("access_tickets", 0))
		]
	else:
		_wallet_label.text = "Nectar %d total | Need %d for Level %d | Current level %d/%d | Honey %d | Tickets %d" % [
			total_nectar,
			nectar_needed,
			next_level,
			nectar_into_level,
			nectar_for_level,
			int(wallet.get("honey", 0)),
			int(inventory.get("access_tickets", 0))
		]
	if _progress_title_label != null:
		_progress_title_label.text = "NECTAR %d / %d" % [nectar_into_level, nectar_for_level]
	_progress_bar.value = progress_ratio * 100.0

	var lock_notice: String = str(snapshot.get("veteran_lock_notice", ""))
	_veteran_label.text = lock_notice
	_veteran_label.visible = not lock_notice.is_empty()

func _render_level_cards(rows: Array) -> void:
	if _cards_vbox == null:
		return
	for child in _cards_vbox.get_children():
		_cards_vbox.remove_child(child)
		child.queue_free()
	_level_cards.clear()
	var cumulative_nectar: int = 0
	for row_any in rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		row["unlock_nectar"] = cumulative_nectar
		var card := _build_level_card(row)
		_cards_vbox.add_child(card)
		_level_cards[int(row.get("level", 0))] = card
		cumulative_nectar += maxi(0, int(row.get("xp_required", 0)))
	_enable_touch_drag_scroll(_levels_scroll)

func _build_level_card(row: Dictionary) -> Panel:
	var level: int = int(row.get("level", 0))
	var unlocked: bool = bool(row.get("unlocked", false))
	var card := Panel.new()
	card.name = "Level%03d" % level
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(CARD_BG, CARD_BORDER if unlocked else Color(0.35, 0.36, 0.44, 0.52), 1, 6))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	var card_pad_x: int = _scaled_int(10 if _uses_touch_layout() else 14)
	var card_pad_y: int = _scaled_int(9 if _uses_touch_layout() else 12)
	margin.add_theme_constant_override("margin_left", card_pad_x)
	margin.add_theme_constant_override("margin_top", card_pad_y)
	margin.add_theme_constant_override("margin_right", card_pad_x)
	margin.add_theme_constant_override("margin_bottom", card_pad_y)
	card.add_child(margin)

	var row_box: BoxContainer = VBoxContainer.new() if _uses_touch_layout() else HBoxContainer.new()
	row_box.add_theme_constant_override("separation", _scaled_int(8 if _uses_touch_layout() else 14))
	margin.add_child(row_box)

	var meta := VBoxContainer.new()
	meta.custom_minimum_size = Vector2(0.0 if _uses_touch_layout() else _scaled_float(172.0), 0.0)
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_theme_constant_override("separation", _scaled_int(4 if _uses_touch_layout() else 6))
	row_box.add_child(meta)

	var level_label := Label.new()
	level_label.text = "LEVEL %03d" % level
	_apply_font(level_label, _font_semibold, 24 if _uses_touch_layout() else 20)
	level_label.add_theme_color_override("font_color", GOLD if unlocked else LOCKED)
	meta.add_child(level_label)

	var xp_label := Label.new()
	if _uses_touch_layout():
		xp_label.text = "Unlock: %d nectar | Cost: %d nectar" % [
			int(row.get("unlock_nectar", 0)),
			int(row.get("xp_required", 0))
		]
	else:
		xp_label.text = "Unlock total: %d nectar\nLevel cost: %d nectar" % [
			int(row.get("unlock_nectar", 0)),
			int(row.get("xp_required", 0))
		]
	xp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(xp_label, _font_regular, 16 if _uses_touch_layout() else 12)
	xp_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96, 0.88))
	meta.add_child(xp_label)

	var status := Label.new()
	status.text = "OPEN" if unlocked else "LOCKED"
	_apply_font(status, _font_semibold, 15 if _uses_touch_layout() else 12)
	status.add_theme_color_override("font_color", GOOD if unlocked else LOCKED)
	meta.add_child(status)

	var scarcity_remaining: int = int(row.get("scarcity_remaining", -1))
	if scarcity_remaining >= 0:
		var scarcity := Label.new()
		scarcity.text = "Prestige slots: %d" % scarcity_remaining
		scarcity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_font(scarcity, _font_regular, 15 if _uses_touch_layout() else 12)
		scarcity.add_theme_color_override("font_color", GOLD)
		meta.add_child(scarcity)

	var tracks_any: Variant = row.get("tracks", {})
	var tracks: Dictionary = tracks_any as Dictionary if typeof(tracks_any) == TYPE_DICTIONARY else {}
	var reward_col := VBoxContainer.new()
	reward_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reward_col.add_theme_constant_override("separation", _scaled_int(10))
	row_box.add_child(reward_col)

	var main_track_slot: String = "free"
	var main_state: Dictionary = tracks.get(main_track_slot, {}) as Dictionary
	if level > 100 and _reward_is_empty(main_state.get("reward", {}) as Dictionary):
		main_track_slot = _first_nonempty_offshoot_track(tracks)
		main_state = tracks.get(main_track_slot, {}) as Dictionary
	reward_col.add_child(_build_main_reward_card(level, main_track_slot, main_state))

	var offshoots: BoxContainer = VBoxContainer.new() if _uses_touch_layout() else HBoxContainer.new()
	offshoots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offshoots.add_theme_constant_override("separation", _scaled_int(8 if _uses_touch_layout() else 10))
	reward_col.add_child(offshoots)
	for track in OFFSHOOT_TRACKS:
		var track_state: Dictionary = tracks.get(track, {}) as Dictionary
		if _reward_is_empty(track_state.get("reward", {}) as Dictionary):
			continue
		offshoots.add_child(_build_offshoot_card(level, track, track_state))
	return card

func _build_main_reward_card(level: int, track: String, track_state: Dictionary) -> Panel:
	var panel: Panel = _build_reward_card(level, "MAIN TRACK", track, track_state, true)
	panel.custom_minimum_size = Vector2(0.0, _scaled_float(104.0 if _uses_touch_layout() else 112.0))
	return panel

func _build_offshoot_card(level: int, track: String, track_state: Dictionary) -> Panel:
	var panel: Panel = _build_reward_card(level, "%s OFFSHOOT" % track.to_upper(), track, track_state, false)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0.0, _scaled_float(88.0 if _uses_touch_layout() else 96.0))
	return panel

func _build_reward_card(level: int, label_text: String, track: String, track_state: Dictionary, main_track: bool) -> Panel:
	var reward_any: Variant = track_state.get("reward", {})
	var reward: Dictionary = reward_any as Dictionary if typeof(reward_any) == TYPE_DICTIONARY else {}
	var claimable: bool = bool(track_state.get("claimable", false))
	var claimed: bool = bool(track_state.get("claimed", false))
	var locked_reason: String = str(track_state.get("locked_reason", ""))
	var track_panel := Panel.new()
	track_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_panel.add_theme_stylebox_override("panel", _style(TRACK_BG, _reward_border_color(label_text, claimable, claimed), 1, 5))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	var reward_pad: int = _scaled_int(8 if _uses_touch_layout() else 10)
	margin.add_theme_constant_override("margin_left", reward_pad)
	margin.add_theme_constant_override("margin_top", reward_pad)
	margin.add_theme_constant_override("margin_right", reward_pad)
	margin.add_theme_constant_override("margin_bottom", reward_pad)
	track_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _scaled_int(6))
	margin.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", _scaled_int(8))
	box.add_child(top)

	var icon := TextureRect.new()
	var reward_tex: Texture2D = _reward_texture(reward)
	icon.custom_minimum_size = Vector2(_scaled_float(50.0 if _uses_touch_layout() else 64.0), _scaled_float(50.0 if _uses_touch_layout() else 64.0))
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = reward_tex
	if reward_tex != null:
		top.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", _scaled_int(2))
	top.add_child(text_col)

	var track_label := Label.new()
	track_label.text = label_text
	_apply_font(track_label, _font_semibold, 15 if _uses_touch_layout() else 12)
	track_label.add_theme_color_override("font_color", GOLD if main_track else _offshoot_title_color(label_text))
	text_col.add_child(track_label)

	var reward_label := Label.new()
	reward_label.text = _reward_title(reward)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(reward_label, _font_regular, 17 if _uses_touch_layout() else 13)
	reward_label.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98, 0.96))
	text_col.add_child(reward_label)

	var status_label := Label.new()
	status_label.text = _track_status_text(claimable, claimed, locked_reason)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(status_label, _font_regular, 15 if _uses_touch_layout() else 12)
	status_label.add_theme_color_override("font_color", GOOD if claimable else (GOLD if claimed else LOCKED))
	box.add_child(status_label)

	var claim_button := _make_button("Claim")
	claim_button.custom_minimum_size = Vector2(0.0, _scaled_float(38.0 if _uses_touch_layout() else 34.0))
	claim_button.disabled = not claimable
	claim_button.pressed.connect(func() -> void:
		_claim_track(level, track)
	)
	box.add_child(claim_button)
	return track_panel

func _update_action_state(snapshot: Dictionary) -> void:
	if _premium_button != null:
		var premium_owned: bool = bool(snapshot.get("premium_owned", false))
		_premium_button.text = "Premium Owned" if premium_owned else "Buy Premium"
		_premium_button.disabled = premium_owned
	if _elite_button != null:
		var elite_owned: bool = bool(snapshot.get("elite_owned", false))
		_elite_button.text = "Elite Owned" if elite_owned else "Buy Elite"
		_elite_button.disabled = elite_owned

func _claim_track(level: int, track: String) -> void:
	_call_state("intent_claim_reward", [level, track])

func _call_state(method_name: String, args: Array) -> void:
	if _state == null or not _state.has_method(method_name):
		return
	var result: Variant = _state.callv(method_name, args)
	if typeof(result) == TYPE_DICTIONARY:
		var result_dict: Dictionary = result as Dictionary
		if bool(result_dict.get("ok", false)):
			_event_label.text = "%s: ok" % method_name
		else:
			_event_label.text = "%s: %s" % [method_name, str(result_dict.get("reason", "blocked"))]

func _on_pass_event(event: Dictionary) -> void:
	_event_label.text = "Last event: %s" % str(event.get("type", "event"))
	_refresh_from_state()

func _scroll_to_level(level: int) -> void:
	call_deferred("_ensure_level_card_visible", level)

func _ensure_level_card_visible(level: int) -> void:
	if _levels_scroll == null or not _level_cards.has(level):
		return
	var card: Control = _level_cards.get(level) as Control
	if card != null:
		_levels_scroll.ensure_control_visible(card)

func _refresh_card_sizes() -> void:
	if _levels_scroll == null or _cards_vbox == null:
		return
	var available: float = maxf(240.0, _levels_scroll.size.y)
	var card_height: float
	if _uses_touch_layout():
		card_height = clampf(available * 0.86, 360.0 * WARPATH_VISUAL_SCALE, 560.0 * WARPATH_VISUAL_SCALE)
	else:
		card_height = clampf((available - 28.0) / 2.0, 240.0 * WARPATH_VISUAL_SCALE, 620.0 * WARPATH_VISUAL_SCALE)
	for child in _cards_vbox.get_children():
		if child is Control:
			(child as Control).custom_minimum_size = Vector2(0.0, card_height)

func _uses_touch_layout() -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	return viewport_size.y > viewport_size.x or viewport_size.x <= TOUCH_LAYOUT_MAX_WIDTH

func _touch_layout_scale() -> float:
	var layout_scale: float = TOUCH_LAYOUT_SCALE if _uses_touch_layout() else 1.0
	return layout_scale * WARPATH_VISUAL_SCALE

func _scaled_float(value: float) -> float:
	return round(value * _touch_layout_scale())

func _scaled_int(value: int) -> int:
	return maxi(1, int(round(float(value) * _touch_layout_scale())))

func _enable_touch_drag_scroll(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_bind_touch_drag_scroll_to_control(scroll, scroll)

func _bind_touch_drag_scroll_to_control(control: Control, scroll: ScrollContainer) -> void:
	if control == null or scroll == null:
		return
	if not control.has_meta("sf_touch_drag_scroll_bound"):
		control.set_meta("sf_touch_drag_scroll_bound", true)
		var callback := Callable(self, "_on_touch_drag_scroll_gui_input").bind(scroll)
		if not control.gui_input.is_connected(callback):
			control.gui_input.connect(callback)
	for child in control.get_children():
		if child is Control:
			_bind_touch_drag_scroll_to_control(child as Control, scroll)

func _on_touch_drag_scroll_gui_input(event: InputEvent, scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	var delta_y: float = 0.0
	if event is InputEventScreenDrag:
		delta_y = (event as InputEventScreenDrag).relative.y
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		delta_y = (event as InputEventMouseMotion).relative.y
	if is_zero_approx(delta_y):
		return
	scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - int(round(delta_y)))
	scroll.accept_event()

func _reward_title(reward: Dictionary) -> String:
	var reward_type: String = str(reward.get("reward_type", "none")).strip_edges().to_lower()
	var quantity: int = maxi(1, int(reward.get("quantity", 1)))
	match reward_type:
		"honey":
			return "%d Honey" % quantity
		"access_ticket":
			return "%d Access Ticket%s" % [quantity, "" if quantity == 1 else "s"]
		"cosmetic":
			return _titleize_id(str(reward.get("cosmetic_id", "Cosmetic")))
		"buff":
			var buff_id: String = str(reward.get("buff_id", ""))
			var buff: Dictionary = BuffCatalog.get_buff(buff_id)
			return str(buff.get("name", _titleize_id(buff_id)))
		"analytics_credit":
			return "%d Analytics Credit%s" % [quantity, "" if quantity == 1 else "s"]
		"bundle_token":
			return "%d Bundle Token%s" % [quantity, "" if quantity == 1 else "s"]
		"ad_free_days":
			return "%d Ad-Free Day%s" % [quantity, "" if quantity == 1 else "s"]
		_:
			return "No prize"

func _track_status_text(claimable: bool, claimed: bool, locked_reason: String) -> String:
	if claimed:
		return "Claimed"
	if claimable:
		return "Ready to claim"
	if locked_reason.is_empty() or locked_reason == "no_reward_for_track":
		return "No claim available"
	return _titleize_id(locked_reason)

func _reward_texture(reward: Dictionary) -> Texture2D:
	var reward_type: String = str(reward.get("reward_type", "none")).strip_edges().to_lower()
	if reward_type == "buff":
		var buff: Dictionary = BuffCatalog.get_buff(str(reward.get("buff_id", "")))
		var icon_path: String = str(buff.get("icon_path", ""))
		if not icon_path.is_empty():
			return _load_texture(icon_path)
	if reward_type == "honey":
		return null
	if reward_type == "access_ticket":
		return _load_texture("res://assets/sprites/sf_skin_v1/battle_pass.png")
	if reward_type == "cosmetic":
		return _load_texture("res://assets/sprites/sf_skin_v1/skins_alpha.png")
	if reward_type == "analytics_credit":
		return _load_texture("res://assets/sprites/sf_skin_v1/Analyticsii.png")
	if reward_type == "bundle_token":
		return _load_texture("res://assets/sprites/sf_skin_v1/Bundles.png")
	if reward_type == "ad_free_days":
		return _load_texture("res://assets/sprites/sf_skin_v1/Premium.png")
	return _load_texture("res://assets/sprites/sf_skin_v1/Lock.png")

func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache.get(path) as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_texture_cache[path] = tex
	return tex

func _reward_is_empty(reward: Dictionary) -> bool:
	return reward.is_empty() or str(reward.get("reward_type", "none")).strip_edges().to_lower() == "none"

func _first_nonempty_offshoot_track(tracks: Dictionary) -> String:
	for track in OFFSHOOT_TRACKS:
		var track_state: Dictionary = tracks.get(track, {}) as Dictionary
		var reward: Dictionary = track_state.get("reward", {}) as Dictionary
		if not _reward_is_empty(reward):
			return track
	return "free"

func _reward_border_color(label_text: String, claimable: bool, claimed: bool) -> Color:
	if claimable:
		return Color(0.55, 0.88, 0.48, 0.80)
	if claimed:
		return Color(0.95, 0.77, 0.28, 0.64)
	var clean_label: String = label_text.to_lower()
	if clean_label.find("elite") >= 0:
		return Color(0.62, 0.48, 0.95, 0.46)
	if clean_label.find("premium") >= 0:
		return Color(0.95, 0.77, 0.28, 0.42)
	return TRACK_BORDER

func _offshoot_title_color(label_text: String) -> Color:
	var clean_label: String = label_text.to_lower()
	if clean_label.find("elite") >= 0:
		return Color(0.78, 0.66, 1.0, 1.0)
	if clean_label.find("premium") >= 0:
		return GOLD
	return Color(0.88, 0.92, 1.0, 1.0)

func _titleize_id(raw: String) -> String:
	var text: String = raw.strip_edges().replace("_", " ").replace("-", " ")
	if text.is_empty():
		return "Reward"
	var parts: PackedStringArray = text.split(" ", false)
	var out: PackedStringArray = PackedStringArray()
	for part in parts:
		if part.length() <= 1:
			out.append(part.to_upper())
		else:
			out.append(part.substr(0, 1).to_upper() + part.substr(1).to_lower())
	return " ".join(out)

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, _scaled_float(50.0 if _uses_touch_layout() else 38.0))
	button.add_theme_stylebox_override("normal", _style(Color(0.10, 0.105, 0.12, 0.86), Color(0.95, 0.77, 0.28, 0.30), 1, 5))
	button.add_theme_stylebox_override("hover", _style(Color(0.15, 0.14, 0.12, 0.92), Color(0.95, 0.80, 0.36, 0.58), 1, 5))
	button.add_theme_stylebox_override("pressed", _style(Color(0.06, 0.06, 0.07, 0.96), Color(0.95, 0.77, 0.28, 0.72), 1, 5))
	button.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.56, 0.58, 0.64, 0.72))
	_apply_font(button, _font_semibold, 16 if _uses_touch_layout() else 13)
	return button

func _make_close_button() -> Button:
	var button := Button.new()
	button.name = "CloseButton"
	button.tooltip_text = "CLOSE"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.text = "Close"
	button.custom_minimum_size = Vector2(_scaled_float(220.0), _scaled_float(52.0))
	button.add_theme_stylebox_override("normal", _style(Color(0.10, 0.105, 0.12, 0.86), Color(0.95, 0.77, 0.28, 0.30), 1, 5))
	button.add_theme_stylebox_override("hover", _style(Color(0.15, 0.14, 0.12, 0.92), Color(0.95, 0.80, 0.36, 0.58), 1, 5))
	button.add_theme_stylebox_override("pressed", _style(Color(0.06, 0.06, 0.07, 0.96), Color(0.95, 0.77, 0.28, 0.72), 1, 5))
	button.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98, 1.0))
	_apply_font(button, _font_semibold, 18 if _uses_touch_layout() else 14)
	return button

func _style(bg: Color, border: Color, border_width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 10.0 * WARPATH_VISUAL_SCALE
	style.content_margin_top = 8.0 * WARPATH_VISUAL_SCALE
	style.content_margin_right = 10.0 * WARPATH_VISUAL_SCALE
	style.content_margin_bottom = 8.0 * WARPATH_VISUAL_SCALE
	return style
