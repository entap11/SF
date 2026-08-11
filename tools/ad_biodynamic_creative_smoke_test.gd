extends SceneTree

const AdSurfaceScript := preload("res://scripts/ui/ad_surface.gd")

const CREATIVE_IMAGE_PATH: String = "res://assets/ads/test_creatives/biodynamic_laser_cleaning_banner.png"
const DESTINATION_URL: String = "https://www.biodynamicusa.com"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not FileAccess.file_exists(CREATIVE_IMAGE_PATH):
		_fail("missing creative image: %s" % CREATIVE_IMAGE_PATH)
		return
	var manager: Node = root.get_node_or_null("AdManager")
	if manager == null:
		_fail("AdManager autoload missing")
		return
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_test_ads", true)
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_image_path", CREATIVE_IMAGE_PATH)
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_destination_url", DESTINATION_URL)
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_open_url_on_tap", false)
	_force_external_ads_config()
	if manager.has_method("clear_measurement_events"):
		manager.call("clear_measurement_events")
	manager.call("_install_dev_biodynamic_provider_if_enabled")
	var provider_snapshot: Dictionary = manager.call("get_provider_debug_snapshot") as Dictionary
	if not bool(provider_snapshot.get("is_dev_test", false)):
		_fail("dev Biodynamic provider did not install")
		return
	var root_control := Control.new()
	root_control.size = Vector2(760.0, 520.0)
	root.add_child(root_control)
	var cases: Array[Dictionary] = [
		{"slot": "match_loading_handshake", "placement": "handshake", "size": Vector2(468.0, 176.0), "light_backdrop": true},
		{"slot": "prematch_handshake", "placement": "handshake", "size": Vector2(468.0, 60.0)},
		{"slot": "vs_handshake", "placement": "handshake", "size": Vector2(468.0, 60.0)},
		{"slot": "in_game_hud", "placement": "in_game", "size": Vector2(320.0, 50.0)},
		{"slot": "post_match_summary", "placement": "post_match", "size": Vector2(520.0, 72.0)}
	]
	var surfaces: Array[Control] = []
	var y: float = 20.0
	for case in cases:
		var surface: Control = AdSurfaceScript.new() as Control
		root_control.add_child(surface)
		surface.set("light_creative_backdrop", bool(case.get("light_backdrop", false)))
		surface.position = Vector2(20.0, y)
		surface.call("configure", str(case.get("slot", "")), str(case.get("placement", "")), case.get("size", Vector2.ZERO), false)
		surfaces.append(surface)
		y += float((case.get("size", Vector2.ZERO) as Vector2).y) + 24.0
	await create_timer(1.20).timeout
	for idx in range(cases.size()):
		var case: Dictionary = cases[idx]
		var surface: Control = surfaces[idx]
		var slot_id: String = str(case.get("slot", ""))
		if not bool(surface.visible):
			_fail("%s surface should be visible" % slot_id)
			return
		var texture_rect: TextureRect = surface.get_node_or_null("CreativeTexture") as TextureRect
		if texture_rect == null or not texture_rect.visible or texture_rect.texture == null:
			_fail("%s should render the Biodynamic banner image" % slot_id)
			return
		if texture_rect.stretch_mode != TextureRect.STRETCH_SCALE:
			_fail("%s should stretch the banner to fill its surface" % slot_id)
			return
		if bool(case.get("light_backdrop", false)):
			var style: StyleBoxFlat = surface.get_theme_stylebox("panel") as StyleBoxFlat
			if style == null or style.bg_color.get_luminance() < 0.9:
				_fail("%s should render the transparent creative on a light backplate" % slot_id)
				return
		var label: Label = surface.get_node_or_null("PlaceholderLabel") as Label
		if label != null and label.visible:
			_fail("%s should be image-only, but label is visible" % slot_id)
			return
		var state: Dictionary = manager.call("get_slot_state", slot_id) as Dictionary
		if int(state.get("impressions", 0)) != 1:
			_fail("%s should record one viewable impression" % slot_id)
			return
		var tap_event := InputEventMouseButton.new()
		tap_event.button_index = MOUSE_BUTTON_LEFT
		tap_event.pressed = true
		tap_event.position = surface.position + Vector2(8.0, 8.0)
		surface.call("_gui_input", tap_event)
		state = manager.call("get_slot_state", slot_id) as Dictionary
		if int(state.get("taps", 0)) != 1:
			_fail("%s should record one tap" % slot_id)
			return
	provider_snapshot = manager.call("get_provider_debug_snapshot") as Dictionary
	var opened_urls: Array = provider_snapshot.get("opened_urls", []) as Array
	if opened_urls.size() != cases.size():
		_fail("dev provider should receive one open_ad call per placement")
		return
	for url in opened_urls:
		if str(url) != DESTINATION_URL:
			_fail("unexpected destination URL: %s" % str(url))
			return
	var events: Array = manager.call("get_measurement_events") as Array
	if events.size() != cases.size() * 2:
		_fail("expected impression+tap measurement event per placement")
		return
	_cleanup(manager)
	print("AD_BIODYNAMIC_CREATIVE_SMOKE: PASS")
	quit(0)

func _cleanup(manager: Node) -> void:
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_test_ads", false)
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_open_url_on_tap", false)
	if manager != null and manager.has_method("clear_provider"):
		manager.call("clear_provider")

func _force_external_ads_config() -> void:
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null or not ops_config.has_method("force_config_for_smoke"):
		return
	var config: Dictionary = ops_config.call("get_config_snapshot") as Dictionary
	config["config_version"] = "ad-biodynamic-creative-smoke"
	var flags: Dictionary = config.get("feature_flags", {}) as Dictionary
	flags["enable_ads"] = true
	flags["enable_house_ads"] = false
	config["feature_flags"] = flags
	var ads: Dictionary = config.get("ads", {}) as Dictionary
	ads["external_ads_enabled"] = true
	ads["house_ads_enabled"] = false
	ads["placements"] = {"handshake": true, "in_game": true, "post_match": true}
	config["ads"] = ads
	ops_config.call("force_config_for_smoke", config, "remote_fresh")

func _fail(message: String) -> void:
	_cleanup(root.get_node_or_null("AdManager"))
	push_error("AD_BIODYNAMIC_CREATIVE_SMOKE: %s" % message)
	quit(1)
