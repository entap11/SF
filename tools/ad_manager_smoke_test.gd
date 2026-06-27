extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = root.get_node_or_null("AdManager")
	if manager == null:
		_fail("AdManager autoload missing")
		return
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_test_ads", false)
	if manager.has_method("clear_provider"):
		manager.call("clear_provider")
	if manager.has_method("clear_measurement_events"):
		manager.call("clear_measurement_events")
	_force_external_ads_config()
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", false)
	var policy: Dictionary = manager.call("get_policy", "smoke_in_game", "in_game") as Dictionary
	if not bool(policy.get("allowed", false)):
		_fail("in_game placement should be allowed")
		return
	if bool(policy.get("personalized_ads_allowed", true)):
		_fail("personalized ads should default off")
		return
	if str(policy.get("content_mode", "")) != "ad" or not bool(policy.get("surface_allowed", false)):
		_fail("approved ad placement should expose ad surface mode")
		return
	var no_provider: Dictionary = manager.call("request_ad", "smoke_in_game", "in_game") as Dictionary
	if bool(no_provider.get("filled", false)):
		_fail("manager should not fill without provider or fake ads")
		return
	var unsupported: Dictionary = manager.call("request_ad", "bad_slot", "unsupported") as Dictionary
	if bool(unsupported.get("filled", false)):
		_fail("unsupported placement should not fill")
		return
	var unsupported_policy: Dictionary = unsupported.get("policy", {}) as Dictionary
	if str(unsupported_policy.get("content_mode", "")) != "hidden" or bool(unsupported_policy.get("surface_allowed", true)):
		_fail("unsupported placement should expose hidden surface mode")
		return
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", true)
	var fake_fill: Dictionary = manager.call("request_ad", "fake_slot", "post_match") as Dictionary
	if not bool(fake_fill.get("filled", false)):
		_fail("fake ads should fill approved placement")
		return
	var impression: Dictionary = manager.call("record_impression", "fake_slot") as Dictionary
	if not bool(impression.get("ok", false)):
		_fail("filled fake slot should accept impression")
		return
	var duplicate_impression: Dictionary = manager.call("record_impression", "fake_slot") as Dictionary
	if bool(duplicate_impression.get("ok", false)) or str(duplicate_impression.get("reason", "")) != "impression_already_recorded":
		_fail("manager should dedupe repeated impressions for same fill")
		return
	var tap: Dictionary = manager.call("record_tap", "fake_slot") as Dictionary
	if not bool(tap.get("ok", false)):
		_fail("filled fake slot should accept tap")
		return
	var conversion: Dictionary = manager.call("record_conversion", "fake_slot", {"attribution_id": "smoke_attr"}) as Dictionary
	if not bool(conversion.get("ok", false)):
		_fail("filled fake slot should accept conversion attribution callback")
		return
	var state: Dictionary = manager.call("get_slot_state", "fake_slot") as Dictionary
	if int(state.get("impressions", 0)) != 1 or int(state.get("taps", 0)) != 1:
		_fail("slot counters did not persist")
		return
	if int(state.get("conversions", 0)) != 1:
		_fail("slot conversion counter did not persist")
		return
	var events: Array = manager.call("get_measurement_events") as Array
	if events.size() != 3:
		_fail("measurement event queue should contain impression, tap, conversion")
		return
	if str((events[0] as Dictionary).get("type", "")) != "impression" or str((events[1] as Dictionary).get("type", "")) != "tap" or str((events[2] as Dictionary).get("type", "")) != "conversion":
		_fail("measurement event queue order/type mismatch")
		return
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", false)
	print("AD_MANAGER_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("AD_MANAGER_SMOKE: %s" % message)
	quit(1)

func _force_external_ads_config() -> void:
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null or not ops_config.has_method("force_config_for_smoke"):
		return
	var config: Dictionary = ops_config.call("get_config_snapshot") as Dictionary
	config["config_version"] = "ad-manager-smoke-external"
	var flags: Dictionary = config.get("feature_flags", {}) as Dictionary
	flags["enable_ads"] = true
	flags["enable_house_ads"] = false
	config["feature_flags"] = flags
	var ads: Dictionary = config.get("ads", {}) as Dictionary
	ads["external_ads_enabled"] = true
	ads["house_ads_enabled"] = false
	ads["placements"] = {
		"handshake": true,
		"in_game": true,
		"post_match": true
	}
	config["ads"] = ads
	ops_config.call("force_config_for_smoke", config, "remote_fresh")
