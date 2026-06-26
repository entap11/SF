class_name AdSurface
extends PanelContainer

const PLACEHOLDER_ENV: String = "SF_AD_PLACEHOLDERS"
const ZERO_ADS_ENTITLEMENT: String = "zero_ads"
const PLACEMENT_HANDSHAKE: String = "handshake"
const PLACEMENT_IN_GAME: String = "in_game"
const PLACEMENT_POST_MATCH: String = "post_match"
const HANDSHAKE_AUTO_DISMISS_SEC: float = 8.0
const POST_MATCH_AUTO_DISMISS_SEC: float = 9.0

var slot_id: String = ""
var placement: String = ""
var reserved_size: Vector2 = Vector2(320.0, 50.0)
var reserve_when_empty: bool = false

var _label: Label = null
var _ad_available: bool = false
var _auto_dismiss_token: int = 0
var _policy_snapshot: Dictionary = {}

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
	_ad_available = available and _ads_allowed_by_policy()
	if not _ad_available:
		_cancel_auto_dismiss()
	_sync_empty_state()
	if _ad_available:
		_arm_auto_dismiss_if_needed()

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
		_label.add_theme_font_size_override("font_size", 13)
		_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.96, 0.82))
		add_child(_label)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_label.text = "AD SPACE" if slot_id.is_empty() else "AD SPACE: %s" % slot_id
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.03, 0.72)
	style.border_color = Color(0.8, 0.86, 0.95, 0.35)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)

func _sync_empty_state() -> void:
	_refresh_policy_snapshot()
	var policy_allows_ads: bool = _ads_allowed_by_policy()
	var show_placeholder: bool = policy_allows_ads and _placeholders_enabled()
	visible = policy_allows_ads and (_ad_available or reserve_when_empty or show_placeholder)
	modulate.a = 1.0 if (_ad_available or show_placeholder) else 0.0
	if _label != null:
		var filled_label: String = _filled_ad_label_text()
		if _ad_available and not filled_label.is_empty():
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
	_policy_snapshot = {
		"allowed": placement_allowed and not zero_ads,
		"placement_allowed": placement_allowed,
		"zero_ads": zero_ads,
		"slot_id": slot_id,
		"placement": placement,
		"family_safe_only": family_safe_only,
		"personalized_ads_allowed": false,
		"auto_dismiss_sec": auto_dismiss_sec,
		"external_open_requires_tap": true,
		"interrupts_gameplay": false
	}
	set_meta("ad_policy", _policy_snapshot.duplicate(true))

func _ads_allowed_by_policy() -> bool:
	return bool(_policy_snapshot.get("allowed", false))

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

func _ad_manager() -> Node:
	return get_node_or_null("/root/AdManager")

func _filled_ad_label_text() -> String:
	var manager: Node = _ad_manager()
	if manager == null or not manager.has_method("get_slot_state"):
		return ""
	var state: Dictionary = manager.call("get_slot_state", slot_id) as Dictionary
	if state.is_empty() or not bool(state.get("filled", false)):
		return ""
	var creative: Dictionary = state.get("creative", {}) as Dictionary
	if not str(creative.get("id", "")).begins_with("fake_"):
		return ""
	var title: String = str(creative.get("title", "ENTaP")).strip_edges()
	var body: String = str(creative.get("body", "Test ad")).strip_edges()
	return "%s\n%s" % [title, body]
