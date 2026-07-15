extends SceneTree

const RuntimeGate := preload("res://scripts/shell_helpers/buff_targeting_runtime_gate.gd")
const HeavyFixtureScript := preload("res://scripts/dev/buff_targeting_device_heavy_fixture.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_debug_gate_contract()
	_test_release_inert_source_contract()
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
	var gate_source: String = FileAccess.get_file_as_string("res://scripts/shell_helpers/buff_targeting_runtime_gate.gd")
	var collector_source: String = FileAccess.get_file_as_string("res://scripts/dev/buff_targeting_device_evidence_collector.gd")
	var fixture_source: String = FileAccess.get_file_as_string("res://scripts/dev/buff_targeting_device_heavy_fixture.gd")
	_expect(shell_source.count("const MATCH_BUFF_TARGETING_ENABLED: bool = false") == 1, "production gate must remain exactly false")
	_expect(shell_source.count("_buff_targeting_runtime_enabled()") >= 5, "all production gate call sites must use the guarded runtime decision")
	_expect(gate_source.contains("if not is_debug_build:") and gate_source.contains("return false"), "runtime gate must fail closed before reading the debug argument")
	for source: String in [gate_source, collector_source, fixture_source]:
		_expect(not source.contains("get_environment") and not source.contains("OpsConfig") and not source.contains("remote"), "device harness must not expose a remote, environment, or ops override")
	_expect(fixture_source.contains("if not OS.is_debug_build():"), "heavy fixture must contain its own release-build refusal")
	_expect(collector_source.contains("production_gate_constant\": false"), "device evidence must record that the production constant stayed false")


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
