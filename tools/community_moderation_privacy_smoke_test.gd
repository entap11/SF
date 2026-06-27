extends SceneTree

const PROFILE_PATH: String = "user://profile.cfg"
const MODERATION_PATH: String = "user://moderation_state.json"

var _failed: bool = false

func _initialize() -> void:
	await _run()
	if _failed:
		quit(1)
		return
	print("COMMUNITY_MODERATION_PRIVACY_SMOKE: PASS")
	quit(0)

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MODERATION_PATH))
	var profile_manager: Node = root.get_node_or_null("ProfileManager")
	var moderation_state: Node = root.get_node_or_null("ModerationState")
	_expect(profile_manager != null, "ProfileManager autoload should exist")
	_expect(moderation_state != null, "ModerationState autoload should exist")
	if _failed:
		return
	profile_manager.set("_has_loaded", false)
	profile_manager.call("ensure_loaded")
	if moderation_state.has_method("debug_reset_state"):
		moderation_state.call("debug_reset_state")

	var initial: Dictionary = profile_manager.call("request_handle_change", "InitialCall", false, "smoke_initial") as Dictionary
	_expect(bool(initial.get("ok", false)), "initial Call Sign pick should pass", initial)
	var free_change: Dictionary = profile_manager.call("request_handle_change", "SecondCall", false, "smoke_free") as Dictionary
	_expect(bool(free_change.get("ok", false)), "first calendar-year free Call Sign change should pass", free_change)
	var blocked_extra: Dictionary = profile_manager.call("request_handle_change", "ThirdCall", false, "smoke_extra") as Dictionary
	_expect(not bool(blocked_extra.get("ok", false)) and str(blocked_extra.get("reason", "")) == "requires_honey_payment", "second same-year free Call Sign change should require Honey", blocked_extra)
	_expect(int(blocked_extra.get("honey_cost", 0)) > 0, "Honey rename hook should expose a cost", blocked_extra)

	var local_player_id: String = str(profile_manager.call("get_user_id"))
	var report_result: Dictionary = moderation_state.call(
		"submit_report",
		local_player_id,
		"player",
		"u_badactor0001",
		"call_sign",
		"Impersonating staff",
		{"surface": "profile"}
	) as Dictionary
	_expect(bool(report_result.get("ok", false)), "report submission should pass", report_result)

	var action_result: Dictionary = moderation_state.call(
		"record_moderation_action",
		local_player_id,
		"forced_rename",
		"Call Sign violates impersonation policy",
		"mod_smoke",
		{"report_id": str((report_result.get("report", {}) as Dictionary).get("report_id", ""))}
	) as Dictionary
	_expect(bool(action_result.get("ok", false)), "forced rename moderation action should pass", action_result)
	var policy_after_action: Dictionary = profile_manager.call("get_handle_policy_snapshot") as Dictionary
	_expect(bool(policy_after_action.get("forced_rename_required", false)), "local forced rename should be reflected in profile policy", policy_after_action)

	var same_name_result: Dictionary = profile_manager.call("request_handle_change", "SecondCall", false, "smoke_forced_same") as Dictionary
	_expect(not bool(same_name_result.get("ok", false)) and str(same_name_result.get("reason", "")) == "forced_rename_required", "forced rename should require a new Call Sign", same_name_result)
	var forced_change: Dictionary = profile_manager.call("request_handle_change", "CleanCall", false, "smoke_forced_clear") as Dictionary
	_expect(bool(forced_change.get("ok", false)), "forced rename should allow compliant replacement without Honey", forced_change)
	var policy_after_clear: Dictionary = profile_manager.call("get_handle_policy_snapshot") as Dictionary
	_expect(not bool(policy_after_clear.get("forced_rename_required", false)), "successful forced rename should clear forced state", policy_after_clear)

	var action: Dictionary = action_result.get("action", {}) as Dictionary
	var appeal_result: Dictionary = moderation_state.call("submit_appeal", str(action.get("action_id", "")), local_player_id, "I changed the name and request review.") as Dictionary
	_expect(bool(appeal_result.get("ok", false)), "appeal submission should pass for appealable action", appeal_result)
	var appeal: Dictionary = appeal_result.get("appeal", {}) as Dictionary
	var review_result: Dictionary = moderation_state.call("review_appeal", str(appeal.get("appeal_id", "")), "senior_mod", "upheld", "Forced rename was appropriate.") as Dictionary
	_expect(bool(review_result.get("ok", false)), "appeal review should pass", review_result)

	var public_identity: Dictionary = profile_manager.call("get_public_identity_snapshot") as Dictionary
	_expect(public_identity.has("player_id"), "public identity should include stable player id", public_identity)
	_expect(public_identity.has("call_sign"), "public identity should include Call Sign", public_identity)
	_expect(not public_identity.has("honey_balance"), "public identity must not include Honey balance", public_identity)
	_expect(not public_identity.has("admin_dashboard_password"), "public identity must not include private credentials", public_identity)
	_expect(not public_identity.has("store_entitlements"), "public identity must not include entitlement/payment facts", public_identity)
	var private_snapshot: Dictionary = profile_manager.call("get_private_profile_snapshot") as Dictionary
	var privacy_posture: Dictionary = private_snapshot.get("privacy_posture", {}) as Dictionary
	_expect(not bool(privacy_posture.get("public_identity_includes_financial_identity", true)), "privacy posture should assert no public financial identity", private_snapshot)

func _expect(condition: bool, message: String, details: Variant = null) -> void:
	if condition:
		return
	_failed = true
	if details == null:
		push_error("COMMUNITY_MODERATION_PRIVACY_SMOKE: %s" % message)
	else:
		push_error("COMMUNITY_MODERATION_PRIVACY_SMOKE: %s :: %s" % [message, str(details)])
