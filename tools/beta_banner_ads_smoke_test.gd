extends SceneTree

const Manager := preload("res://scripts/state/ad_manager.gd")
const Surface := preload("res://scripts/ui/ad_surface.gd")
const CaptureRecord := preload("res://scripts/state/beta_capture_record.gd")

class TestProfile:
	extends Node
	var zero_ads := false
	func has_store_entitlement(flag: String) -> bool:
		return zero_ads and flag == "zero_ads"

var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	check(Manager.beta_banners_enabled_for_runtime(true, true, false, true, false), "release beta exports must enable banners")
	check(Manager.beta_banners_enabled_for_runtime(false, false, true, true, false), "local debug games must enable banners")
	check(not Manager.beta_banners_enabled_for_runtime(false, true, false, true, false), "production release must not enable beta banners")
	check(not Manager.beta_banners_enabled_for_runtime(false, true, true, true, false), "non-beta store debug exports must not enable beta banners")
	check(not Manager.beta_banners_enabled_for_runtime(true, true, false, false, false), "setting must disable beta banners")
	check(not Manager.beta_banners_enabled_for_runtime(true, true, false, true, true), "environment kill switch must disable beta banners")
	var manager: Node = root.get_node("AdManager")
	var old_profile: Node = root.get_node("ProfileManager")
	old_profile.name = "OriginalProfileManager"
	var profile := TestProfile.new()
	profile.name = "ProfileManager"
	root.add_child(profile)
	var config_node: Node = root.get_node("OpsConfig")
	var config: Dictionary = config_node.call("get_config_snapshot")
	config.feature_flags.enable_ads = false
	config.ads.external_ads_enabled = false
	config_node.call("force_config_for_smoke", config, "remote_fresh")
	ProjectSettings.set_setting("swarmfront/ads/beta_biodynamic_banners", true)
	manager.call("_install_dev_biodynamic_provider_if_enabled")
	check(manager.call("get_provider_debug_snapshot").is_dev_test, "beta provider must install without a dev opt-in")
	check(not manager.call("get_policy", "match_loading", "handshake").allowed, "beta banners must not enable loading video")
	check(not manager.call("get_policy", "other_slot", "in_game").allowed, "beta allowance must be restricted to the two banners")
	check(not manager.call("get_policy", "in_game_hud", "unsupported").allowed, "unapproved placements must remain blocked")
	for slot_id in ["in_game_hud", "in_game_footer"]:
		var surface := Surface.new()
		root.add_child(surface)
		surface.configure(slot_id, "in_game", Vector2(600, 100), true)
		check(manager.call("get_slot_state", slot_id).filled, "%s must fill with external inventory disabled" % slot_id)
		check(surface.get_node("CreativeTexture").texture != null, "%s must load the actual PNG" % slot_id)
		surface.free()
	var diag: Dictionary = manager.call("get_diagnostics_snapshot")
	check(diag.slots.in_game_hud.texture_loads == 1 and diag.slots.in_game_footer.texture_load_failures == 0, "image load diagnostics must record success once per surface")
	manager.call("record_creative_load", "missing_fixture", 2300, false)
	check(manager.call("get_diagnostics_snapshot").slots.missing_fixture.texture_load_failures == 1, "image failures must be diagnosable")
	profile.zero_ads = true
	check(not manager.call("request_ad", "in_game_hud", "in_game").filled, "ad-free entitlement must suppress beta banners")
	profile.zero_ads = false
	config.ads.placements.in_game = false
	config_node.call("force_config_for_smoke", config, "remote_fresh")
	check(not manager.call("request_ad", "in_game_footer", "in_game").filled, "placement switch must suppress beta banners")
	config.ads.placements.in_game = true
	config_node.call("force_config_for_smoke", config, "remote_fresh")
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_top_image_path", "res://missing-banner.png")
	manager.call("_install_dev_biodynamic_provider_if_enabled")
	check(manager.call("request_ad", "in_game_hud", "in_game").reason == "creative_missing", "missing creative must return no fill")
	check(manager.call("get_diagnostics_snapshot").slots.in_game_hud.last_reason == "creative_missing", "no-fill reason must appear in diagnostics")
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_top_image_path", Manager.DEV_BIODYNAMIC_DEFAULT_TOP_IMAGE_PATH)
	manager.call("_install_dev_biodynamic_provider_if_enabled")
	manager.call("clear_measurement_events")
	for index in range(Manager.MAX_MEASUREMENT_EVENTS + 12):
		manager.call("request_ad", "in_game_hud", "in_game")
		manager.call("record_impression", "in_game_hud")
	var events: Array = manager.call("get_measurement_events")
	check(events.size() == Manager.MAX_MEASUREMENT_EVENTS, "measurement history must remain bounded")
	check(not events.back().client_billable_candidate, "test ads must never be marked billable")
	check(manager.call("get_provider_debug_snapshot").recorded_event_count == Manager.MAX_MEASUREMENT_EVENTS, "provider history must remain bounded")
	diag = manager.call("get_diagnostics_snapshot")
	check(diag.slots.in_game_hud.impression == Manager.MAX_MEASUREMENT_EVENTS + 12, "session totals must survive history eviction")
	var panel: Control = load("res://scenes/ui/SupportDiagnosticsPanel.tscn").instantiate()
	root.add_child(panel)
	check(panel.call("build_diagnostics_payload").ads == diag, "support diagnostics must expose the ad summary")
	var capture := CaptureRecord.project({}, {"metadata": {"ad_diagnostics": diag}})
	check(capture.metadata.ad_diagnostics == diag, "beta capture must preserve the diagnostic summary")
	panel.free()
	profile.free()
	old_profile.name = "ProfileManager"
	print("BETA_BANNER_ADS_SMOKE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
