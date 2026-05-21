extends SceneTree

const ProfileManagerScript := preload("res://scripts/profile/profile_manager.gd")

func _init() -> void:
	var failed: bool = false
	failed = _expect_ok("Flick") or failed
	failed = _expect_ok("MurderHornet57") or failed
	failed = _expect_ok("FatherOfSwarm") or failed
	failed = _expect_ok("JewishPlayer") or failed
	failed = _expect_block("SwarmFather", "reserved_founder") or failed
	failed = _expect_block("SwarmDaddy", "reserved_founder") or failed
	failed = _expect_block("SwarmDad57", "reserved_founder") or failed
	failed = _expect_block("FvckYou", "prohibited_language") or failed
	failed = _expect_block("Fuuuck", "prohibited_language") or failed
	failed = _expect_block("RapistHive", "prohibited_language") or failed
	failed = _expect_block("IncestKing", "prohibited_language") or failed
	failed = _expect_block("GenocideRun", "prohibited_language") or failed
	failed = _expect_block("JewGas", "protected_class_abuse") or failed
	failed = _expect_block("Bad-Name", "invalid_chars") or failed
	if failed:
		quit(1)
		return
	print("HANDLE_POLICY_SMOKE: PASS")
	quit(0)

func _expect_ok(handle: String) -> bool:
	var result: Dictionary = ProfileManagerScript.validate_handle_policy(handle)
	if bool(result.get("ok", false)):
		return false
	push_error("HANDLE_POLICY_SMOKE: expected ok for %s, got %s" % [handle, str(result)])
	return true

func _expect_block(handle: String, reason: String) -> bool:
	var result: Dictionary = ProfileManagerScript.validate_handle_policy(handle)
	if not bool(result.get("ok", false)) and str(result.get("reason", "")) == reason:
		return false
	push_error("HANDLE_POLICY_SMOKE: expected %s for %s, got %s" % [reason, handle, str(result)])
	return true
