extends SceneTree

const AdSurfaceScript := preload("res://scripts/ui/ad_surface.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = root.get_node_or_null("AdManager")
	if manager == null:
		_fail("AdManager autoload missing")
		return
	if manager.has_method("clear_measurement_events"):
		manager.call("clear_measurement_events")
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", true)
	_force_external_ads_config()
	var root_control := Control.new()
	root_control.size = Vector2(640.0, 480.0)
	root.add_child(root_control)
	var surface: Control = AdSurfaceScript.new() as Control
	root_control.add_child(surface)
	surface.position = Vector2(20.0, 20.0)
	surface.call("configure", "measurement_slot", "in_game", Vector2(320.0, 50.0), false)
	await create_timer(1.15).timeout
	var state: Dictionary = manager.call("get_slot_state", "measurement_slot") as Dictionary
	if int(state.get("impressions", 0)) != 1:
		_fail("viewable filled surface should record exactly one impression")
		return
	if surface.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("filled ad surface should accept intentional taps")
		return
	var tap_event := InputEventMouseButton.new()
	tap_event.button_index = MOUSE_BUTTON_LEFT
	tap_event.pressed = true
	tap_event.position = Vector2(40.0, 40.0)
	surface.call("_gui_input", tap_event)
	state = manager.call("get_slot_state", "measurement_slot") as Dictionary
	if int(state.get("taps", 0)) != 1:
		_fail("filled ad surface tap should record one tap")
		return
	var events: Array = manager.call("get_measurement_events") as Array
	if events.size() != 2:
		_fail("surface path should emit impression and tap measurement events")
		return
	if str((events[0] as Dictionary).get("type", "")) != "impression" or str((events[1] as Dictionary).get("type", "")) != "tap":
		_fail("surface measurement events type/order mismatch")
		return
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", false)
	print("AD_SURFACE_MEASUREMENT_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", false)
	push_error("AD_SURFACE_MEASUREMENT_SMOKE: %s" % message)
	quit(1)

func _force_external_ads_config() -> void:
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null or not ops_config.has_method("force_config_for_smoke"):
		return
	var config: Dictionary = ops_config.call("get_config_snapshot") as Dictionary
	config["config_version"] = "ad-surface-measurement-smoke"
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
