extends SceneTree

const PROFILE_ID := "018f2b2c-1234-7abc-8def-123456789abc"
const ENTAP_ID := "SFP 501"
const CALL_SIGN := "S01"

func _init() -> void:
	var root_node: Window = root
	var profile_manager: Node = load("res://scripts/profile/profile_manager.gd").new()
	root_node.add_child(profile_manager)
	profile_manager.name = "ProfileManager"
	if not profile_manager.has_method("smoke_force_identity_state"):
		push_error("LOCAL_ONBOARDING_UNBLOCK: ProfileManager missing smoke_force_identity_state")
		quit(1)
		return
	var forced := bool(profile_manager.call(
		"smoke_force_identity_state",
		PROFILE_ID,
		ENTAP_ID,
		CALL_SIGN,
		true,
		false
	))
	if not forced:
		push_error("LOCAL_ONBOARDING_UNBLOCK: debug identity force failed")
		quit(1)
		return
	profile_manager.set("_handle_change_count", 0)
	profile_manager.set("_handle_history", [])
	profile_manager.set("_handle_changed_at_unix", 0)
	profile_manager.set("_next_handle_change_unix", 0)
	profile_manager.call("mark_onboarding_complete")
	var complete := bool(profile_manager.call("is_onboarding_complete"))
	if not complete:
		push_error("LOCAL_ONBOARDING_UNBLOCK: onboarding did not persist")
		quit(1)
		return
	print("LOCAL_ONBOARDING_UNBLOCK: PASS profile=%s entap=%s call_sign=%s" % [
		profile_manager.call("get_user_id"),
		profile_manager.call("get_entap_id"),
		profile_manager.call("get_call_sign")
	])
	quit(0)
