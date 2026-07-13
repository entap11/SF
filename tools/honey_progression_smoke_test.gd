extends SceneTree

class FakeSimRunner:
	extends Node
	signal match_ended(winner_id: int, reason: String)

const HONEY_STATE_PATH: String = "user://honey_progression_state.json"
const PROFILE_PATH: String = "user://profile.cfg"

func _init() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HONEY_STATE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))

	var honey_state: Node = get_root().get_node_or_null("HoneyProgressionState")
	var profile_manager: Node = get_root().get_node_or_null("ProfileManager")
	var ops_config: Node = get_root().get_node_or_null("OpsConfig")
	if honey_state == null or profile_manager == null or ops_config == null:
		push_error("HONEY_SMOKE: required autoload missing")
		quit(1)
		return
	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "honey-progression-smoke",
		"feature_flags": {
			"enable_honey_rewards": true,
			"enable_local_honey_rewards": true
		}
	})
	OS.set_environment("SF_VS_BACKEND_URL", "")
	ProjectSettings.set_setting("swarmfront/vs/backend_url", "")
	var vs_handshake: Node = get_root().get_node_or_null("VsHandshake")
	if vs_handshake != null and vs_handshake.has_method("_configure_transport"):
		vs_handshake.call("_configure_transport")

	if honey_state.has_method("debug_reset_state"):
		honey_state.call("debug_reset_state")
	if profile_manager.has_method("set_honey_balance"):
		profile_manager.call("set_honey_balance", 0)
	await process_frame

	for i in range(5):
		_assert_ok(
			honey_state.call("intent_record_async_completion", "STAGE_RACE", 3, false, {"event_id": "free_async_%d" % i, "duration_sec": 120.0}) as Dictionary,
			"free async completion %d" % i
		)
	_assert_eq(int(profile_manager.call("get_honey_balance")), 20, "five async completions should mint v2 participation honey")

	var duplicate: Dictionary = honey_state.call("intent_record_async_completion", "STAGE_RACE", 3, false, {"event_id": "free_async_0", "duration_sec": 120.0}) as Dictionary
	_assert_true(not bool(duplicate.get("ok", false)), "duplicate async event should be rejected")

	_assert_ok(
		honey_state.call("intent_record_async_final_placement", "STAGE_RACE", 3, 1, false, "WEEKLY", {"event_id": "place_stage_1"}) as Dictionary,
		"stage race placement"
	)
	_assert_eq(int(profile_manager.call("get_honey_balance")), 28, "first place async bonus should add competitive success honey")

	_assert_ok(
		honey_state.call("intent_record_purchase_bundle", 25, {"event_id": "bundle_25"}) as Dictionary,
		"platform growth purchase bundle"
	)
	_assert_eq(int(profile_manager.call("get_honey_balance")), 44, "platform growth should use the Honey v2 tier")

	_assert_ok(
		honey_state.call("intent_record_referral", "active_30d", {"event_id": "ref_30d"}) as Dictionary,
		"retained referral"
	)
	_assert_eq(int(profile_manager.call("get_honey_balance")), 60, "retained referral should use platform growth tier")

	_assert_ok(honey_state.call("intent_record_async_completion", "TIMED_RACE", 3, false, {"event_id": "timed_3", "duration_sec": 120.0}) as Dictionary, "timed 3")
	_assert_ok(honey_state.call("intent_record_async_completion", "MISS_N_OUT", 3, false, {"event_id": "miss_3", "duration_sec": 120.0}) as Dictionary, "miss 3")
	_assert_ok(honey_state.call("intent_record_async_completion", "STAGE_RACE", 5, false, {"event_id": "stage_5", "duration_sec": 120.0}) as Dictionary, "stage 5")
	_assert_ok(honey_state.call("intent_record_async_completion", "TIMED_RACE", 5, false, {"event_id": "timed_5", "duration_sec": 120.0}) as Dictionary, "timed 5")
	_assert_ok(honey_state.call("intent_record_async_completion", "MISS_N_OUT", 5, false, {"event_id": "miss_5", "duration_sec": 120.0}) as Dictionary, "miss 5")

	var snapshot: Dictionary = honey_state.call("get_snapshot") as Dictionary
	var weekly_claimed: Dictionary = snapshot.get("weekly_claimed", {}) as Dictionary
	_assert_true(bool(weekly_claimed.get("free_async_variety", false)), "free async weekly bonus should auto-claim")
	_assert_true(bool(weekly_claimed.get("async_3_map_variety", false)), "3-map async weekly bonus should auto-claim")
	_assert_true(bool(weekly_claimed.get("async_5_map_variety", false)), "5-map async weekly bonus should auto-claim")
	_assert_eq(int(profile_manager.call("get_honey_balance")), 92, "async bonuses should settle to expected whole honey")

	var spend_result: Dictionary = honey_state.call("intent_spend_player_honey", 5, "smoke_store_purchase", {"event_id": "smoke_store_debit"}) as Dictionary
	_assert_ok(spend_result, "authoritative Honey spend")
	_assert_eq(int(profile_manager.call("get_honey_balance")), 87, "Honey spend should debit the one player balance")
	var duplicate_spend: Dictionary = honey_state.call("intent_spend_player_honey", 5, "smoke_store_purchase", {"event_id": "smoke_store_debit"}) as Dictionary
	_assert_ok(duplicate_spend, "idempotent Honey spend retry")
	_assert_eq(int(profile_manager.call("get_honey_balance")), 87, "Honey spend retry should not debit twice")

	var fake_runner := FakeSimRunner.new()
	fake_runner.name = "SimRunner"
	get_root().add_child(fake_runner)
	await process_frame

	set_meta("vs_mode", "1V1")
	set_meta("vs_sync_start", true)
	set_meta("vs_free_roll", true)
	set_meta("vs_price_usd", 0)
	set_meta("vs_local_profile", {"uid": str(profile_manager.call("get_user_id"))})
	set_meta("vs_handshake_role", "host")
	set_meta("match_elapsed_ms", 120000)
	fake_runner.emit_signal("match_ended", 1, "timeout")
	await process_frame

	snapshot = honey_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("total_honey_centi_awarded", 0)), 9600, "auto pvp completion should add participation honey")

	set_meta("vs_mode", "STAGE_RACE")
	set_meta("vs_sync_start", false)
	set_meta("vs_free_roll", true)
	set_meta("vs_price_usd", 0)
	set_meta("vs_stage_map_paths", ["map_a", "map_b", "map_c"])
	set_meta("vs_stage_current_index", 1)
	remove_meta("honey_runtime_nonce")
	fake_runner.emit_signal("match_ended", 1, "round_end")
	await process_frame
	snapshot = honey_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("total_honey_centi_awarded", 0)), 9600, "non-final stage round should not award honey")

	set_meta("vs_stage_current_index", 2)
	remove_meta("honey_runtime_nonce")
	fake_runner.emit_signal("match_ended", 1, "round_end")
	await process_frame
	snapshot = honey_state.call("get_snapshot") as Dictionary
	_assert_eq(int(snapshot.get("total_honey_centi_awarded", 0)), 10000, "final stage round should award async completion honey")

	print("HONEY_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	push_error("HONEY_SMOKE: %s failed -> %s" % [label, result])
	quit(1)

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	push_error("HONEY_SMOKE: %s (expected %d, got %d)" % [label, expected, actual])
	quit(1)

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("HONEY_SMOKE: %s" % label)
	quit(1)
