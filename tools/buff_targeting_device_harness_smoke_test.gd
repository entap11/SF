extends SceneTree

const RuntimeGate := preload("res://scripts/shell_helpers/buff_targeting_runtime_gate.gd")
const HeavyFixtureScript := preload("res://scripts/dev/buff_targeting_device_heavy_fixture.gd")
const DeviceSessionScript := preload("res://scripts/arena_helpers/buff_device_evidence_session.gd")
const CollectorScript := preload("res://scripts/dev/buff_targeting_device_evidence_collector.gd")
const BuffStateScript := preload("res://scripts/state/buff_state.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_debug_gate_contract()
	_test_release_inert_source_contract()
	_test_device_sim_session_contract()
	_test_collector_readiness_contract()
	await _test_heavy_fixture_uses_production_controller()
	if not _failed:
		print("BUFF_TARGETING_DEVICE_HARNESS_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_debug_gate_contract() -> void:
	var build_id: String = "0123456789abcdef0123456789abcdef01234567"
	var harness_args := PackedStringArray([
		RuntimeGate.DEVICE_HARNESS_ARG,
		"--buff-targeting-device-role=pvp_host",
		"--buff-targeting-device-build=%s" % build_id
	])
	var fixture_args := PackedStringArray([RuntimeGate.HEAVY_FIXTURE_ARG])
	_expect(not RuntimeGate.enabled_for_runtime(false, true, PackedStringArray()), "debug build without exact launch argument must remain disabled")
	_expect(RuntimeGate.enabled_for_runtime(false, true, harness_args), "debug build with exact harness argument must enable production targeting presentation")
	_expect(not RuntimeGate.enabled_for_runtime(false, false, harness_args), "release build must ignore the harness launch argument")
	_expect(RuntimeGate.enabled_for_runtime(true, false, PackedStringArray()), "future explicitly approved production constant remains the only release enable path")
	_expect(RuntimeGate.heavy_fixture_enabled_for_runtime(true, fixture_args), "debug build may enter the heavy fixture")
	_expect(not RuntimeGate.heavy_fixture_enabled_for_runtime(false, fixture_args), "release build must refuse the heavy fixture")
	_expect(RuntimeGate.device_role(harness_args) == "pvp_host", "approved evidence role must parse")
	_expect(RuntimeGate.device_role(PackedStringArray(["--buff-targeting-device-role=admin"])) == "unspecified", "unapproved role must not create a new runtime mode")
	_expect(RuntimeGate.device_build_id(harness_args) == build_id, "exact 40-character evidence commit must parse")
	_expect(RuntimeGate.device_build_id(PackedStringArray(["--buff-targeting-device-build=not-a-commit"])) == "unattributed", "invalid evidence commit must fail attribution")


func _test_release_inert_source_contract() -> void:
	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	var gate_source: String = FileAccess.get_file_as_string("res://scripts/shell_helpers/buff_targeting_runtime_gate.gd")
	var collector_source: String = FileAccess.get_file_as_string("res://scripts/dev/buff_targeting_device_evidence_collector.gd")
	var fixture_source: String = FileAccess.get_file_as_string("res://scripts/dev/buff_targeting_device_heavy_fixture.gd")
	var device_plan: String = FileAccess.get_file_as_string("res://docs/buff_targeting_loop5_iphone_device_plan_2026-07-15.md")
	_expect(shell_source.count("const MATCH_BUFF_TARGETING_ENABLED: bool = false") == 1, "production gate must remain exactly false")
	_expect(shell_source.count("_buff_targeting_runtime_enabled()") >= 5, "all production gate call sites must use the guarded runtime decision")
	_expect(gate_source.contains("if not is_debug_build:") and gate_source.contains("return false"), "runtime gate must fail closed before reading the debug argument")
	for source: String in [gate_source, collector_source, fixture_source]:
		_expect(not source.contains("get_environment") and not source.contains("OpsConfig") and not source.contains("remote"), "device harness must not expose a remote, environment, or ops override")
	_expect(fixture_source.contains("if not OS.is_debug_build():"), "heavy fixture must contain its own release-build refusal")
	_expect(collector_source.contains("production_gate_constant\": false"), "device evidence must record that the production constant stayed false")
	_expect(collector_source.contains("BUFF_TARGETING_DEVICE_HARNESS_READY") and collector_source.contains("BUFF_TARGETING_DEVICE_HARNESS_BLOCKED"), "device harness must fail loudly when its production buff UI is unavailable")
	_expect(not arena_source.contains("grant_buff(") and not arena_source.contains("set_buff_loadout_ids_for_mode"), "device session must not mutate persisted profile inventory or loadouts")
	_expect(device_plan.contains("com.matthew.swarmfront \\\n  -- \\\n  --buff-targeting-device-harness"), "documented device launch must place custom arguments after Godot's user-argument separator")


func _test_device_sim_session_contract() -> void:
	var session: RefCounted = DeviceSessionScript.new()
	session.call("configure", false, PackedStringArray([
		RuntimeGate.DEVICE_HARNESS_ARG,
		"--buff-targeting-device-role=local"
	]))
	_expect(not bool((session.call("snapshot") as Dictionary).get("enabled", true)), "release runtime must not configure a device simulation session")

	var local_args := PackedStringArray([
		RuntimeGate.DEVICE_HARNESS_ARG,
		"--buff-targeting-device-role=local"
	])
	session.call("configure", true, local_args)
	var local_snapshot: Dictionary = session.call("snapshot") as Dictionary
	_expect(bool(local_snapshot.get("enabled", false)), "debug harness must configure the simulation-owned device session")
	_expect((local_snapshot.get("loadout_ids", []) as Array) == [
		"buff_unit_speed_classic",
		"buff_freeze_lane_classic",
		"buff_global_production_boost_classic"
	], "device session must guarantee hive, lane, and global buff identities")
	_expect(int(local_snapshot.get("uses_per_slot", 0)) == 64, "local evidence role must provide a bounded repeat-sampling allotment")
	_expect(not bool(local_snapshot.get("persistent_inventory_mutated", true)), "device session must remain match-scoped and non-persistent")
	var local_entries: Array = session.call("loadout_entries") as Array
	_expect(local_entries.size() == 3, "device session must build three catalog-valid loadout entries")
	var local_state: RefCounted = BuffStateScript.new()
	var configure_result: Dictionary = local_state.call("configure_loadout", local_entries) as Dictionary
	_expect(bool(configure_result.get("ok", false)), "device evidence entries must configure the production BuffState")
	var configured_slots: Array = local_state.get("slots") as Array
	var configured_ids: Array[String] = []
	for slot_any: Variant in configured_slots:
		configured_ids.append(str((slot_any as Dictionary).get("inventory_id", "")))
	_expect(configured_ids == (local_snapshot.get("loadout_ids", []) as Array), "production BuffState must retain the exact evidence inventory IDs")
	_expect(int((configured_slots[0] as Dictionary).get("uses_remaining", 0)) == 64, "production BuffState must retain the local evidence use allotment")

	var async_args := PackedStringArray([
		RuntimeGate.DEVICE_HARNESS_ARG,
		"--buff-targeting-device-role=async_first"
	])
	session.call("configure", true, async_args)
	var buff_id := "buff_unit_speed_classic"
	var source_one: Dictionary = session.call("source_descriptor", buff_id) as Dictionary
	_expect(bool(source_one.get("ok", false)) and int(source_one.get("source_use_ordinal", 0)) == 1, "Async device use one must expose ordinal one")
	_expect(bool((session.call("commit", buff_id) as Dictionary).get("ok", false)), "Async device use one must commit through Arena-owned session")
	var source_two: Dictionary = session.call("source_descriptor", buff_id) as Dictionary
	_expect(bool(source_two.get("ok", false)) and int(source_two.get("source_use_ordinal", 0)) == 2, "Async device use two must expose ordinal two")
	_expect(bool((session.call("commit", buff_id) as Dictionary).get("ok", false)), "Async device use two must commit through Arena-owned session")
	var source_three: Dictionary = session.call("source_descriptor", buff_id) as Dictionary
	_expect(not bool(source_three.get("ok", true)) and str(source_three.get("reason", "")) == "device_evidence_uses_exhausted", "Async device use three must reject without profile consumption")


func _test_collector_readiness_contract() -> void:
	var collector: Node = CollectorScript.new()
	collector.set("_role", "local")
	collector.set("_latest_device_session_snapshot", {
		"enabled": true,
		"role": "local",
		"persistent_inventory_mutated": false
	})
	collector.set("_latest_buff_ui_snapshot", {
		"buffs_enabled": true,
		"active_player_id": 1,
		"players": {
			1: {
				"slots_active": 3,
				"slots": [
					{"inventory_id": "buff_unit_speed_classic"},
					{"inventory_id": "buff_freeze_lane_classic"},
					{"inventory_id": "buff_global_production_boost_classic"}
				]
			}
		}
	})
	_expect(str(collector.call("_device_readiness_failure")) == "", "collector must accept the complete production buff snapshot")
	collector.set("_latest_buff_ui_snapshot", {
		"buffs_enabled": true,
		"active_player_id": 1,
		"players": {1: {"slots_active": 0, "slots": []}}
	})
	_expect(str(collector.call("_device_readiness_failure")) == "three_active_slots_unavailable", "collector must fail loudly when the player strip has no usable slots")
	collector.free()


func _test_heavy_fixture_uses_production_controller() -> void:
	var fixture: Node2D = HeavyFixtureScript.new()
	get_root().add_child(fixture)
	for _i in range(5):
		await process_frame
	var snapshot: Dictionary = fixture.call("evidence_snapshot", "smoke") as Dictionary
	_expect(int(snapshot.get("lane_count", 0)) == 64 and int(snapshot.get("segment_count", 0)) == 640, "device fixture must instantiate the established heavy presentation dimensions")
	_expect(int(snapshot.get("maximum_geometry_rebuilds_per_frame", 99)) <= 1, "device fixture must preserve one rebuild maximum per rendered frame")
	_expect(fixture.get_node_or_null("BuffLaneGlobalTargetPresentation") != null, "device fixture must instantiate the production lane targeting controller")
	fixture.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_TARGETING_DEVICE_HARNESS_SMOKE: %s" % message)
