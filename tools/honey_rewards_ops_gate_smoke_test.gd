extends SceneTree

const HONEY_STATE_PATH: String = "user://honey_progression_state.json"
const PROFILE_PATH: String = "user://profile.cfg"

func _init() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HONEY_STATE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))

	var ops_config: Node = get_root().get_node_or_null("OpsConfig")
	var honey_state: Node = get_root().get_node_or_null("HoneyProgressionState")
	var profile_manager: Node = get_root().get_node_or_null("ProfileManager")
	if ops_config == null or honey_state == null or profile_manager == null:
		_fail("required autoload missing")
		return

	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "honey-rewards-disabled-smoke",
		"feature_flags": {
			"enable_honey_rewards": false
		}
	})
	if honey_state.has_method("debug_reset_state"):
		honey_state.call("debug_reset_state")
	if profile_manager.has_method("set_honey_balance"):
		profile_manager.call("set_honey_balance", 0)
	await process_frame

	var disabled_result: Dictionary = honey_state.call(
		"intent_record_async_completion",
		"STAGE_RACE",
		3,
		false,
		{"event_id": "ops_gate_disabled"}
	) as Dictionary
	_assert_true(bool(disabled_result.get("ok", false)), "disabled gate should return a handled result")
	_assert_eq(str(disabled_result.get("reason", "")), "honey_rewards_disabled", "disabled reason")
	_assert_int_eq(int(disabled_result.get("honey_tenths_awarded", -1)), 0, "disabled tenths awarded")
	_assert_int_eq(int(profile_manager.call("get_honey_balance")), 0, "disabled profile balance")

	var snapshot: Dictionary = honey_state.call("get_snapshot") as Dictionary
	_assert_int_eq(int(snapshot.get("total_honey_tenths_awarded", -1)), 0, "disabled total awarded")
	_assert_int_eq(int(snapshot.get("community_honey_tenths", -1)), 0, "disabled community total")
	_assert_true((snapshot.get("weekly_progress", {}) as Dictionary).is_empty(), "disabled weekly progress")
	_assert_true((snapshot.get("recent_events", []) as Array).is_empty(), "disabled recent events")

	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "honey-rewards-enabled-smoke",
		"feature_flags": {
			"enable_honey_rewards": true
		}
	})
	var enabled_result: Dictionary = honey_state.call(
		"intent_record_async_completion",
		"STAGE_RACE",
		3,
		false,
		{"event_id": "ops_gate_disabled"}
	) as Dictionary
	_assert_true(bool(enabled_result.get("ok", false)), "event id should not be consumed while disabled")
	_assert_int_eq(int(enabled_result.get("honey_tenths_awarded", -1)), 2, "enabled tenths awarded")
	snapshot = honey_state.call("get_snapshot") as Dictionary
	_assert_int_eq(int(snapshot.get("total_honey_tenths_awarded", -1)), 2, "enabled total awarded")

	print("HONEY_REWARDS_OPS_GATE_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("HONEY_REWARDS_OPS_GATE_SMOKE: %s" % message)
	quit(1)

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_fail(label)

func _assert_eq(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		return
	_fail("%s (expected %s, got %s)" % [label, expected, actual])

func _assert_int_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	_fail("%s (expected %d, got %d)" % [label, expected, actual])
