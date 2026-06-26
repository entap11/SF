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
	if bool(surface.visible):
		push_error("AD_SURFACE_SMOKE: zero_ads should suppress ad surface")
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
