extends SceneTree

const AsyncRecordEligibilityPolicy := preload("res://scripts/state/async_record_eligibility_policy.gd")

var _failed: bool = false

func _init() -> void:
	_clear_record_meta()
	set_meta("vs_cpu_style", "balancer")
	set_meta("vs_cpu_tier", "medium")
	_expect(AsyncRecordEligibilityPolicy.is_balancer_medium_record_eligible(self), "balancer medium should be eligible")

	_clear_record_meta()
	set_meta("vs_cpu_style", "turtle")
	set_meta("vs_cpu_tier", "medium")
	_expect(not AsyncRecordEligibilityPolicy.is_balancer_medium_record_eligible(self), "non-balancer should not be eligible")

	_clear_record_meta()
	set_meta("vs_cpu_style", "balancer")
	set_meta("vs_cpu_tier", "hard")
	_expect(not AsyncRecordEligibilityPolicy.is_balancer_medium_record_eligible(self), "non-medium should not be eligible")

	_clear_record_meta()
	set_meta("jukebox_board_enabled", true)
	_expect(AsyncRecordEligibilityPolicy.is_balancer_medium_record_eligible(self), "jukebox should default to balancer medium")

	if not _failed:
		print("ASYNC_RECORD_ELIGIBILITY_POLICY_SMOKE: PASS")
	quit(1 if _failed else 0)

func _clear_record_meta() -> void:
	for key in ["vs_cpu_style", "vs_cpu_tier", "vs_remote_profile", "jukebox_board_enabled"]:
		if has_meta(key):
			remove_meta(key)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("ASYNC_RECORD_ELIGIBILITY_POLICY_SMOKE: %s" % message)
