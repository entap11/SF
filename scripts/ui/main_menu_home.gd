extends PanelContainer
## Home presentation. Reads profile/progression projections; existing menu routes own actions.

const Typography = preload("res://scripts/ui/ui_typography.gd")
const Style = preload("res://scripts/ui/menu_surface_style.gd")
const Catalog = preload("res://scripts/state/campaign_catalog.gd")

var _menu: Control
var _margin: MarginContainer
var _welcome: Label
var _campaign_context: Label
var _campaign_detail: Label
var _tier: Button
var _rank: Button
var _honey: Button
var _replay: Button
var _status: Label
var _scroll: ScrollContainer
var _last_focus: Button

func configure(menu: Control) -> void:
	_menu = menu
	name = "HomeMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", Style.surface(Color("0e1015"), Color("0e1015"), 0))
	_margin = MarginContainer.new()
	add_child(_margin)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 16)
	_margin.add_child(frame)
	var brand := TextureRect.new()
	var wordmark := AtlasTexture.new()
	wordmark.atlas = preload("res://assets/sprites/sf_skin_v1/signage_main_yellow.png")
	wordmark.region = Rect2(128, 300, 1280, 370)
	brand.texture = wordmark
	brand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.custom_minimum_size.y = 216
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	brand.material = additive
	frame.add_child(brand)
	_welcome = _label(frame, "", 48, Style.TEXT)
	_welcome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_welcome.autowrap_mode = TextServer.AUTOWRAP_OFF
	var account := HBoxContainer.new()
	account.add_theme_constant_override("separation", 16)
	frame.add_child(account)
	_tier = _route_button(account, "Tier", "_on_tier_widget_tier_pressed")
	_rank = _route_button(account, "Rank", "_on_tier_widget_rank_pressed")
	_honey = _route_button(account, "Honey", "_open_storefront_panel")
	_scroll = ScrollContainer.new()
	_scroll.name = "ChoicesScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	frame.add_child(_scroll)
	var choices := VBoxContainer.new()
	choices.name = "Choices"
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 12)
	_scroll.add_child(choices)
	var campaign: Button = _menu.get("menu_jukebox_button")
	var campaign_copy := _adopt_action(choices, campaign, "CAMPAIGN", "Your next challenge", true, 256)
	_campaign_context = campaign_copy[1]
	_campaign_detail = _label(campaign_copy[0].get_parent(), "", 34, Style.MUTED)
	_label(choices, "OTHER WAYS TO PLAY", 32, Style.MUTED)
	_adopt_action(choices, _menu.get("menu_free_roll_button"), "FREE ROLL", "Choose a game. Play without a cash entry.")
	_adopt_action(choices, _menu.get("menu_cash_button"), "MONEY GAMES", "Browse games with a cash entry.")
	_adopt_action(choices, _menu.get("menu_unused_button"), "TOURNAMENTS", "Explore tournament play.")
	_replay = _route_button(choices, "LAST MATCH REPLAY", "_open_home_replay", true)
	_replay.name = "LatestReplay"
	_replay.custom_minimum_size.y = 104
	var destinations := HBoxContainer.new()
	destinations.add_theme_constant_override("separation", 16)
	frame.add_child(destinations)
	_route_button(destinations, "DASHBOARD", "_toggle_dash").name = "Dashboard"
	_route_button(destinations, "HIVE", "_toggle_hive_dropdown").name = "Hive"
	for button: Button in destinations.get_children():
		button.custom_minimum_size.y = 132
		button.add_theme_font_size_override("font_size", 40)
	var utilities := HBoxContainer.new()
	utilities.name = "Utilities"
	utilities.add_theme_constant_override("separation", 16)
	frame.add_child(utilities)
	for entry in [["menu_store_button", "STORE"], ["menu_buffs_button", "BUFFS"], ["menu_battle_pass_button", "BATTLE PASS"]]:
		var button: Button = _menu.get(entry[0])
		_adopt_button(utilities, button, entry[1])
	_status = _menu.get("status_label")
	_status.reparent(frame)
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Typography.apply_token(_status, Typography.regular_font(), "meta", 2.0)
	_menu.call("_enable_touch_drag_scroll", _scroll)
	_scroll.gui_input.connect(Callable(_menu, "_on_free_roll_scroll_gui_input"))
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	CampaignRuntime.progress_changed.connect(refresh_campaign)
	ProfileManager.honey_balance_changed.connect(_on_honey_changed)
	RankState.rank_state_changed.connect(_on_rank_changed)
	refresh_campaign()
	_refresh_account()
	refresh_identity()
	_layout()

func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Typography.regular_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _adopt_button(parent: Container, button: Button, title: String) -> void:
	button.reparent(parent)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = title
	var skin := button.get_node_or_null("SkinTex") as Control
	if skin != null:
		skin.hide()
	Style.action(button)
	button.custom_minimum_size.y = 132
	button.add_theme_font_size_override("font_size", 40)
	button.show()
	button.focus_entered.connect(func() -> void: _last_focus = button)

func _adopt_action(parent: Container, button: Button, title: String, detail: String, primary: bool = false, height: float = 180) -> Array[Label]:
	_adopt_button(parent, button, title)
	if not button.has_meta("sf_free_roll_press_guard"):
		for connection in button.get_signal_connection_list("pressed"):
			var action: Callable = connection.callable
			button.pressed.disconnect(action)
			_menu.call("_connect_free_roll_guarded_press", button, action)
	Style.action(button, primary)
	button.custom_minimum_size.y = height
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.size_flags_stretch_ratio = 1.25 if primary else 1.0
	# Live labels remain separate from art; the button retains its accessible name.
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		button.add_theme_color_override(key, Color.TRANSPARENT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 8)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(copy)
	var heading := _label(copy, title, 64 if primary else 56, Color("fff0b8") if primary else Style.TEXT)
	var subtitle := _label(copy, detail, 38 if primary else 36, Style.TEXT if primary else Style.MUTED)
	return [heading, subtitle]

func _route_button(parent: Container, title: String, method: String, guard_scroll: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.action(button)
	parent.add_child(button)
	if guard_scroll:
		_menu.call("_connect_free_roll_guarded_press", button, Callable(_menu, method))
	else:
		button.pressed.connect(Callable(_menu, method))
	button.focus_entered.connect(func() -> void: _last_focus = button)
	return button

func refresh_identity() -> void:
	var value := "Welcome %s" % ProfileManager.get_display_name()
	if _welcome.text != value:
		_welcome.text = value
	_status.visible = not _status.text.is_empty() and _status.text != "Ready"

func refresh_campaign() -> void:
	var level: Dictionary = Catalog.find(CampaignRuntime.store.continue_id(CampaignRuntime.player_id()))
	_campaign_context.text = "Continue · Level %02d · %s" % [int(level.get("number", 1)), str(level.get("title", "Campaign"))]
	_campaign_detail.text = "%s · %s" % [str(level.get("bot", "")).replace("_", " ").capitalize(), str(level.get("difficulty", "")).capitalize()]

func set_replay(summary: String, available: bool) -> void:
	_replay.disabled = not available
	_replay.text = "LAST MATCH REPLAY\n" + summary if available else "Your last match replay will appear here."

func _on_honey_changed(_value: int, _delta: int, _reason: String) -> void:
	_refresh_account()

func _on_rank_changed(_snapshot: Dictionary) -> void:
	_refresh_account()

func _refresh_account() -> void:
	var badge: Dictionary = RankState.get_local_tier_badge()
	_tier.text = "TIER %d · %s" % [int(badge.get("tier_index", 0)), str(badge.get("tier_id", "DRONE")).capitalize()]
	_rank.text = "RANK %s" % (str(badge.get("tier_rank", 0)) if int(badge.get("tier_rank", 0)) > 0 else "—")
	_honey.text = "HONEY %s" % _menu.call("_format_number", ProfileManager.get_honey_balance())

func _on_visibility_changed() -> void:
	if visible and is_instance_valid(_menu):
		refresh_campaign()
		_refresh_account()
		if is_instance_valid(_last_focus):
			_last_focus.call_deferred("grab_focus")

func _layout() -> void:
	if _margin == null:
		return
	var top := 0.0
	var bottom := 0.0
	if OS.has_feature("android") or OS.has_feature("ios"):
		var window_size := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var factor := size.y / maxf(1.0, window_size.y)
		top = maxf(0, safe.position.y * factor)
		bottom = maxf(0, (window_size.y - safe.end.y) * factor)
	_margin.add_theme_constant_override("margin_left", 4)
	_margin.add_theme_constant_override("margin_right", 4)
	_margin.add_theme_constant_override("margin_top", 8 + int(top))
	_margin.add_theme_constant_override("margin_bottom", 16 + int(bottom))
