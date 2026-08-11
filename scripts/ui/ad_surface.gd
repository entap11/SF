class_name AdSurface
extends PanelContainer

const UITypography := preload("res://scripts/ui/ui_typography.gd")

const PLACEHOLDER_ENV: String = "SF_AD_PLACEHOLDERS"
const ZERO_ADS_ENTITLEMENT: String = "zero_ads"
const PLACEMENT_HANDSHAKE: String = "handshake"
const PLACEMENT_IN_GAME: String = "in_game"
const PLACEMENT_POST_MATCH: String = "post_match"
const CONTENT_MODE_AD: String = "ad"
const CONTENT_MODE_INTERNAL_TICKER: String = "internal_ticker"
const CONTENT_MODE_HIDDEN: String = "hidden"
const HANDSHAKE_AUTO_DISMISS_SEC: float = 8.0
const POST_MATCH_AUTO_DISMISS_SEC: float = 9.0
const IMPRESSION_VIEWABLE_MS: float = 1000.0
const TICKER_TYPE_SCALE: float = 2.5

var slot_id: String = ""
var placement: String = ""
var reserved_size: Vector2 = Vector2(320.0, 50.0)
var reserve_when_empty: bool = false
var ticker_items: Array[String] = []

var _label: Label = null
var _creative_texture_rect: TextureRect = null
var _ad_available: bool = false
var _auto_dismiss_token: int = 0
var _policy_snapshot: Dictionary = {}
var _viewable_ms: float = 0.0
var _impression_recorded: bool = false
var _loaded_creative_path: String = ""
var _presentation_enabled: bool = true
var _interaction_enabled: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_ensure_placeholder_ui()
	_refresh_policy_snapshot()
	_sync_empty_state()

func configure(slot_id_in: String, placement_in: String, size_in: Vector2, reserve_empty: bool = false) -> void:
	slot_id = slot_id_in.strip_edges()
	placement = placement_in.strip_edges()
	reserved_size = Vector2(maxf(1.0, size_in.x), maxf(1.0, size_in.y))
	reserve_when_empty = reserve_empty
	custom_minimum_size = reserved_size
	size = reserved_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ad_slot_id", slot_id)
	set_meta("ad_placement", placement)
	_ensure_placeholder_ui()
	_refresh_policy_snapshot()
	_sync_empty_state()
	request_ad()

func set_ad_available(available: bool) -> void:
	_refresh_policy_snapshot()
	var was_available: bool = _ad_available
	_ad_available = available and _ads_allowed_by_policy()
	if _ad_available and not was_available:
		_viewable_ms = 0.0
		_impression_recorded = false
	if not _ad_available:
		_cancel_auto_dismiss()
		_viewable_ms = 0.0
	_sync_empty_state()
	if _ad_available and _presentation_enabled:
		_arm_auto_dismiss_if_needed()

func set_presentation_enabled(enabled: bool) -> void:
	if _presentation_enabled == enabled:
		return
	_presentation_enabled = enabled
	if not _presentation_enabled:
		_cancel_auto_dismiss()
		_viewable_ms = 0.0
	_sync_empty_state()
	if _presentation_enabled and _ad_available:
		_arm_auto_dismiss_if_needed()

func is_presentation_enabled() -> bool:
	return _presentation_enabled

func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	_sync_empty_state()

func set_internal_ticker_items(items: Array) -> void:
	ticker_items.clear()
	for item in items:
		var text: String = str(item).strip_edges()
		if not text.is_empty():
			ticker_items.append(text)
	_sync_empty_state()

func set_internal_ticker_text(text: String) -> void:
	set_internal_ticker_items([text])

func get_policy_snapshot() -> Dictionary:
	_refresh_policy_snapshot()
	return _policy_snapshot.duplicate(true)

func request_ad() -> Dictionary:
	_refresh_policy_snapshot()
	var manager: Node = _ad_manager()
	if manager != null and manager.has_method("request_ad"):
		return manager.call("request_ad", slot_id, placement, self) as Dictionary
	set_ad_available(false)
	return {"ok": true, "filled": false, "reason": "ad_manager_unavailable", "policy": _policy_snapshot.duplicate(true)}

func _ensure_placeholder_ui() -> void:
	if _label == null:
		_label = get_node_or_null("PlaceholderLabel") as Label
	if _label == null:
		_label = Label.new()
		_label.name = "PlaceholderLabel"
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.clip_text = true
		_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.96, 0.82))
		add_child(_label)
	UITypography.apply_token(_label, UITypography.regular_font(), "meta", TICKER_TYPE_SCALE)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_ensure_creative_texture_rect()
	_label.text = "AD SPACE" if slot_id.is_empty() else "AD SPACE: %s" % slot_id
	_apply_surface_style(false)

func _ensure_creative_texture_rect() -> void:
	if _creative_texture_rect == null:
		_creative_texture_rect = get_node_or_null("CreativeTexture") as TextureRect
	if _creative_texture_rect == null:
		_creative_texture_rect = TextureRect.new()
		_creative_texture_rect.name = "CreativeTexture"
		_creative_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_creative_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_creative_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(_creative_texture_rect)
	_ensure_texture_below_label()
	_creative_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT, true)

func _sync_empty_state() -> void:
	_refresh_policy_snapshot()
	var policy_allows_ads: bool = _ads_allowed_by_policy()
	var show_internal_ticker: bool = _should_show_internal_ticker()
	var show_placeholder: bool = policy_allows_ads and _placeholders_enabled()
	var has_presentable_content: bool = show_internal_ticker or (policy_allows_ads and (_ad_available or reserve_when_empty or show_placeholder))
	visible = _presentation_enabled and has_presentable_content
	modulate.a = 1.0 if _presentation_enabled and (_ad_available or show_placeholder or show_internal_ticker) else 0.0
	set_meta("ad_surface_content_mode", _current_content_mode())
	set_meta("ad_surface_presentation_enabled", _presentation_enabled)
	mouse_filter = Control.MOUSE_FILTER_STOP if _presentation_enabled and _interaction_enabled and _ad_available and _current_content_mode() == CONTENT_MODE_AD else Control.MOUSE_FILTER_IGNORE
	set_process(_presentation_enabled and _ad_available and not _impression_recorded)
	_apply_surface_style(show_internal_ticker)
	if _label != null:
		var filled_label: String = _filled_ad_label_text()
		var creative_texture_visible: bool = _sync_creative_texture()
		if show_internal_ticker:
			_label.text = _ticker_label_text()
			_label.visible = true
		elif _ad_available and creative_texture_visible:
			_label.visible = false
		elif _ad_available and not filled_label.is_empty():
			_label.text = filled_label
			_label.visible = true
		else:
			_label.text = "AD SPACE" if slot_id.is_empty() else "AD SPACE: %s" % slot_id
			_label.visible = show_placeholder and not _ad_available

func _placeholders_enabled() -> bool:
	var env_value: String = OS.get_environment(PLACEHOLDER_ENV).strip_edges().to_lower()
	if ["1", "true", "yes", "on"].has(env_value):
		return true
	if ProjectSettings.has_setting("swarmfront/ads/show_placeholders"):
		return bool(ProjectSettings.get_setting("swarmfront/ads/show_placeholders"))
	return false

func _refresh_policy_snapshot() -> void:
	var manager: Node = _ad_manager()
	if manager != null and manager.has_method("get_policy"):
		_policy_snapshot = manager.call("get_policy", slot_id, placement) as Dictionary
		set_meta("ad_policy", _policy_snapshot.duplicate(true))
		return
	var placement_allowed: bool = _is_approved_placement(placement)
	var zero_ads: bool = _has_zero_ads_entitlement()
	var family_safe_only: bool = _requires_family_safe_ads()
	var auto_dismiss_sec: float = _auto_dismiss_sec_for_placement(placement)
	var ads_allowed: bool = placement_allowed and not zero_ads
	_policy_snapshot = {
		"allowed": ads_allowed,
		"ad_allowed": ads_allowed,
		"surface_allowed": placement_allowed,
		"placement_allowed": placement_allowed,
		"zero_ads": zero_ads,
		"slot_id": slot_id,
		"placement": placement,
		"content_mode": _content_mode_for_policy(placement_allowed, zero_ads),
		"family_safe_only": family_safe_only,
		"personalized_ads_allowed": false,
		"auto_dismiss_sec": auto_dismiss_sec,
		"external_open_requires_tap": true,
		"interrupts_gameplay": false
	}
	set_meta("ad_policy", _policy_snapshot.duplicate(true))

func _ads_allowed_by_policy() -> bool:
	return bool(_policy_snapshot.get("allowed", false))

func _surface_allowed_by_policy() -> bool:
	return bool(_policy_snapshot.get("surface_allowed", _policy_snapshot.get("placement_allowed", false)))

func _should_show_internal_ticker() -> bool:
	return _surface_allowed_by_policy() and str(_policy_snapshot.get("content_mode", "")) == CONTENT_MODE_INTERNAL_TICKER

func _current_content_mode() -> String:
	if _should_show_internal_ticker():
		return CONTENT_MODE_INTERNAL_TICKER
	if _ads_allowed_by_policy():
		return CONTENT_MODE_AD
	return CONTENT_MODE_HIDDEN

func _is_approved_placement(value: String) -> bool:
	var clean: String = value.strip_edges()
	return clean == PLACEMENT_HANDSHAKE or clean == PLACEMENT_IN_GAME or clean == PLACEMENT_POST_MATCH

func _auto_dismiss_sec_for_placement(value: String) -> float:
	var clean: String = value.strip_edges()
	if clean == PLACEMENT_HANDSHAKE:
		return HANDSHAKE_AUTO_DISMISS_SEC
	if clean == PLACEMENT_POST_MATCH:
		return POST_MATCH_AUTO_DISMISS_SEC
	return 0.0

func _content_mode_for_policy(placement_allowed: bool, zero_ads: bool) -> String:
	if not placement_allowed:
		return CONTENT_MODE_HIDDEN
	return CONTENT_MODE_INTERNAL_TICKER if zero_ads else CONTENT_MODE_AD

func _has_zero_ads_entitlement() -> bool:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager == null or not profile_manager.has_method("has_store_entitlement"):
		return false
	return bool(profile_manager.call("has_store_entitlement", ZERO_ADS_ENTITLEMENT))

func _requires_family_safe_ads() -> bool:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager == null or not profile_manager.has_method("get_user_id"):
		return false
	var player_id: String = str(profile_manager.call("get_user_id")).strip_edges()
	if player_id.is_empty():
		return false
	var scholastic_state: Node = get_node_or_null("/root/ScholasticState")
	if scholastic_state == null or not scholastic_state.has_method("get_player_profile_snapshot"):
		return false
	var profile: Dictionary = scholastic_state.call("get_player_profile_snapshot", player_id) as Dictionary
	if profile.is_empty():
		return false
	if str(profile.get("ecosystem", "")).strip_edges().to_upper() == "SFA":
		return true
	var privacy: Dictionary = profile.get("privacy", {}) as Dictionary
	return bool(privacy.get("is_minor", false))

func _arm_auto_dismiss_if_needed() -> void:
	var dismiss_sec: float = float(_policy_snapshot.get("auto_dismiss_sec", 0.0))
	if dismiss_sec <= 0.0 or not is_inside_tree():
		return
	_auto_dismiss_token += 1
	var token: int = _auto_dismiss_token
	var timer: SceneTreeTimer = get_tree().create_timer(dismiss_sec)
	timer.timeout.connect(Callable(self, "_on_auto_dismiss_timeout").bind(token), CONNECT_ONE_SHOT)

func _cancel_auto_dismiss() -> void:
	_auto_dismiss_token += 1

func _on_auto_dismiss_timeout(token: int) -> void:
	if token != _auto_dismiss_token:
		return
	_ad_available = false
	_sync_empty_state()

func _process(delta: float) -> void:
	if _impression_recorded:
		set_process(false)
		return
	if not _ad_available or _current_content_mode() != CONTENT_MODE_AD or not _is_surface_viewable_for_impression():
		_viewable_ms = 0.0
		return
	_viewable_ms += maxf(0.0, delta) * 1000.0
	if _viewable_ms >= IMPRESSION_VIEWABLE_MS:
		_record_viewable_impression()

func _gui_input(event: InputEvent) -> void:
	if not _presentation_enabled or not _interaction_enabled or not _ad_available or _current_content_mode() != CONTENT_MODE_AD:
		return
	var pressed: bool = false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		pressed = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		pressed = touch_event.pressed
	if not pressed:
		return
	var manager: Node = _ad_manager()
	if manager != null and manager.has_method("record_tap"):
		manager.call("record_tap", slot_id, _surface_measurement_context("tap"))
	accept_event()

func _ad_manager() -> Node:
	return get_node_or_null("/root/AdManager")

func _sync_creative_texture() -> bool:
	_ensure_creative_texture_rect()
	if _creative_texture_rect == null:
		return false
	if not _ad_available or _current_content_mode() != CONTENT_MODE_AD:
		_creative_texture_rect.visible = false
		return false
	var image_path: String = _filled_ad_image_path()
	if image_path.is_empty():
		_creative_texture_rect.visible = false
		return false
	if image_path != _loaded_creative_path or _creative_texture_rect.texture == null:
		var texture: Texture2D = _load_creative_texture(image_path)
		_creative_texture_rect.texture = texture
		_loaded_creative_path = image_path if texture != null else ""
	_creative_texture_rect.visible = _creative_texture_rect.texture != null
	return _creative_texture_rect.visible

func _filled_ad_image_path() -> String:
	var creative: Dictionary = _filled_ad_creative()
	if creative.is_empty():
		return ""
	for key in ["image_path", "asset_path", "texture_path", "banner_path"]:
		var path: String = str(creative.get(key, "")).strip_edges()
		if not path.is_empty():
			return path
	return ""

func _filled_ad_creative() -> Dictionary:
	var manager: Node = _ad_manager()
	if manager == null or not manager.has_method("get_slot_state"):
		return {}
	var state: Dictionary = manager.call("get_slot_state", slot_id) as Dictionary
	if state.is_empty() or not bool(state.get("filled", false)):
		return {}
	var creative_any: Variant = state.get("creative", {})
	if typeof(creative_any) != TYPE_DICTIONARY:
		return {}
	return (creative_any as Dictionary).duplicate(true)

func _load_creative_texture(path: String) -> Texture2D:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		return null
	if ResourceLoader.exists(clean_path):
		var loaded: Resource = load(clean_path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var image := Image.new()
	var err: Error = image.load(clean_path)
	if err != OK and clean_path.begins_with("res://"):
		err = image.load(ProjectSettings.globalize_path(clean_path))
	if err != OK:
		push_warning("AdSurface: failed to load creative texture %s err=%d" % [clean_path, err])
		return null
	return ImageTexture.create_from_image(image)

func _ensure_texture_below_label() -> void:
	if _creative_texture_rect == null or _label == null or _creative_texture_rect.get_parent() != self or _label.get_parent() != self:
		return
	if _creative_texture_rect.get_index() > _label.get_index():
		move_child(_creative_texture_rect, _label.get_index())

func _record_viewable_impression() -> void:
	if _impression_recorded:
		return
	_impression_recorded = true
	set_process(false)
	var manager: Node = _ad_manager()
	if manager != null and manager.has_method("record_impression"):
		manager.call("record_impression", slot_id, _surface_measurement_context("impression"))

func _is_surface_viewable_for_impression() -> bool:
	if not visible or not is_visible_in_tree():
		return false
	if modulate.a <= 0.01:
		return false
	var rect: Rect2 = get_global_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return false
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return true
	var visible_rect: Rect2 = viewport.get_visible_rect()
	return visible_rect.intersects(rect)

func _surface_measurement_context(reason: String) -> Dictionary:
	var rect: Rect2 = get_global_rect()
	return {
		"source": "ad_surface",
		"reason": reason,
		"content_mode": _current_content_mode(),
		"surface_visible": visible and is_visible_in_tree(),
		"interaction_enabled": _interaction_enabled,
		"viewable_ms": int(_viewable_ms),
		"reserved_size": {"x": reserved_size.x, "y": reserved_size.y},
		"global_rect": {
			"x": rect.position.x,
			"y": rect.position.y,
			"w": rect.size.x,
			"h": rect.size.y
		}
	}

func _ticker_label_text() -> String:
	if not ticker_items.is_empty():
		return "  |  ".join(ticker_items)
	var manager: Node = _ad_manager()
	if manager != null and manager.has_method("get_house_ticker_items"):
		var configured_items: Array = manager.call("get_house_ticker_items") as Array
		var lines: Array[String] = []
		for item_any in configured_items:
			var item: String = str(item_any).strip_edges()
			if not item.is_empty():
				lines.append(item)
		if not lines.is_empty():
			return "  |  ".join(lines)
	match placement:
		PLACEMENT_HANDSHAKE:
			return "SWARMFRONT STATUS  |  QUEUE SECURED"
		PLACEMENT_IN_GAME:
			return "SWARMFRONT LIVE  |  HOLD LANES  |  BREAK HIVES"
		PLACEMENT_POST_MATCH:
			return "SWARMFRONT RECAP  |  REVIEW THE REPLAY"
	return "SWARMFRONT TICKER"

func _apply_surface_style(internal_ticker: bool) -> void:
	var style := StyleBoxFlat.new()
	if internal_ticker:
		style.bg_color = Color(0.035, 0.045, 0.05, 0.84)
		style.border_color = Color(0.95, 0.82, 0.24, 0.58)
		if _label != null:
			_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62, 0.96))
	else:
		style.bg_color = Color(0.02, 0.025, 0.03, 0.72)
		style.border_color = Color(0.8, 0.86, 0.95, 0.35)
		if _label != null:
			_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.96, 0.82))
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)

func _filled_ad_label_text() -> String:
	var creative: Dictionary = _filled_ad_creative()
	if creative.is_empty():
		return ""
	if not _filled_ad_image_path().is_empty():
		return ""
	if not str(creative.get("id", "")).begins_with("fake_"):
		return ""
	var title: String = str(creative.get("title", "ENTaP")).strip_edges()
	var body: String = str(creative.get("body", "Test ad")).strip_edges()
	return "%s\n%s" % [title, body]
