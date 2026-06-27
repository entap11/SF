extends SceneTree

const AdSurfaceScript := preload("res://scripts/ui/ad_surface.gd")
const OutcomeOverlayScript := preload("res://scripts/ui/outcome_overlay.gd")

class FakeProfileManager:
	extends Node
	var zero_ads: bool = false

	func has_store_entitlement(flag: String) -> bool:
		return zero_ads and flag == "zero_ads"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_test_ads", false)
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", false)
	_force_external_ads_config()
	var manager: Node = root.get_node_or_null("AdManager")
	if manager != null and manager.has_method("clear_provider"):
		manager.call("clear_provider")
	var original_profile_manager: Node = get_root().get_node_or_null("ProfileManager")
	if original_profile_manager != null:
		original_profile_manager.name = "ProfileManagerOriginal"
	var fake_profile := FakeProfileManager.new()
	fake_profile.name = "ProfileManager"
	get_root().add_child(fake_profile)
	var root_control := Control.new()
	get_root().add_child(root_control)
	var surface: Control = AdSurfaceScript.new() as Control
	root_control.add_child(surface)
	surface.call("configure", "smoke_slot", "in_game", Vector2(320.0, 50.0), false)
	await process_frame
	if surface.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		push_error("AD_SURFACE_SMOKE: surface should ignore mouse input")
		quit(1)
		return
	if surface.is_processing():
		push_error("AD_SURFACE_SMOKE: surface should not process frames")
		quit(1)
		return
	if bool(surface.visible):
		push_error("AD_SURFACE_SMOKE: surface should be hidden without placeholder mode or filled ad")
		quit(1)
		return
	if str(surface.get_meta("ad_slot_id", "")) != "smoke_slot":
		push_error("AD_SURFACE_SMOKE: slot metadata missing")
		quit(1)
		return
	var policy: Dictionary = surface.call("get_policy_snapshot") as Dictionary
	if not bool(policy.get("allowed", false)):
		push_error("AD_SURFACE_SMOKE: approved placement should be allowed")
		quit(1)
		return
	if bool(policy.get("personalized_ads_allowed", true)):
		push_error("AD_SURFACE_SMOKE: personalized ads should default off")
		quit(1)
		return
	surface.call("set_ad_available", true)
	if not bool(surface.visible):
		push_error("AD_SURFACE_SMOKE: populated surface should become visible")
		quit(1)
		return
	fake_profile.zero_ads = true
	surface.call("set_ad_available", true)
	if not bool(surface.visible):
		push_error("AD_SURFACE_SMOKE: zero_ads should switch approved ad surface to ticker")
		quit(1)
		return
	if str(surface.get_meta("ad_surface_content_mode", "")) != "internal_ticker":
		push_error("AD_SURFACE_SMOKE: zero_ads surface should report internal_ticker mode")
		quit(1)
		return
	var ticker_label: Label = surface.get_node_or_null("PlaceholderLabel") as Label
	if ticker_label == null or not ticker_label.visible or not ticker_label.text.contains("SWARMFRONT"):
		push_error("AD_SURFACE_SMOKE: zero_ads ticker label missing")
		quit(1)
		return
	surface.call("set_internal_ticker_items", ["LANE ALERT", "HIVE PRESSURE"])
	if ticker_label.text != "LANE ALERT  |  HIVE PRESSURE":
		push_error("AD_SURFACE_SMOKE: custom ticker items did not render")
		quit(1)
		return
	fake_profile.zero_ads = false
	surface.call("configure", "bad_slot", "unsupported", Vector2(320.0, 50.0), false)
	surface.call("set_ad_available", true)
	if bool(surface.visible):
		push_error("AD_SURFACE_SMOKE: unsupported placements should not show")
		quit(1)
		return
	if fake_profile != null and is_instance_valid(fake_profile):
		fake_profile.queue_free()
	if original_profile_manager != null and is_instance_valid(original_profile_manager):
		original_profile_manager.name = "ProfileManager"
	print("AD_SURFACE_SMOKE: PASS")
	quit(0)

func _force_external_ads_config() -> void:
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null or not ops_config.has_method("force_config_for_smoke"):
		return
	var config: Dictionary = ops_config.call("get_config_snapshot") as Dictionary
	config["config_version"] = "ad-surface-smoke-external"
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
