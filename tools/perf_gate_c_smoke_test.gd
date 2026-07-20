extends SceneTree

const IsolationGuard := preload("res://scripts/tests/perf/perf_isolation_guard.gd")
const TestBackendPolicy := preload("res://scripts/state/test_backend_policy.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	var ops_state: Node = root.get_node_or_null("/root/OpsState")
	_expect(ops_state != null, "OpsState autoload must exist")
	if ops_state == null:
		quit(1)
		return
	var marker_existed: bool = has_meta("sf_perf_harness_active")
	var marker_value: Variant = get_meta("sf_perf_harness_active", false)
	set_meta("sf_perf_harness_active", true)
	var analytics: Node = root.get_node_or_null("/root/AnalyticsClient")
	var app_lifecycle: Node = root.get_node_or_null("/root/AppLifecycle")
	_expect(analytics != null and analytics.has_method("set_perf_harness_isolation"), "analytics isolation seam must exist")
	_expect(app_lifecycle != null and app_lifecycle.has_method("set_perf_harness_isolation"), "AppLifecycle isolation seam must exist")
	if analytics != null and analytics.has_method("set_perf_harness_isolation"):
		_expect(bool(analytics.call("set_perf_harness_isolation", true)), "analytics isolation must activate under the harness marker")
	if app_lifecycle != null and app_lifecycle.has_method("set_perf_harness_isolation"):
		_expect(bool(app_lifecycle.call("set_perf_harness_isolation", true)), "AppLifecycle isolation must activate under the harness marker")
	_test_backend_denial()
	await _test_snapshot_restore(ops_state)
	await _test_topology_detection(ops_state)
	_test_analytics_denial(analytics)
	_test_source_contracts()
	if analytics != null and analytics.has_method("set_perf_harness_isolation"):
		_expect(bool(analytics.call("set_perf_harness_isolation", false)), "analytics isolation must restore")
	if app_lifecycle != null and app_lifecycle.has_method("set_perf_harness_isolation"):
		_expect(bool(app_lifecycle.call("set_perf_harness_isolation", false)), "AppLifecycle isolation must restore")
	if marker_existed:
		set_meta("sf_perf_harness_active", marker_value)
	else:
		remove_meta("sf_perf_harness_active")
	if not _failed:
		print("PERF_GATE_C_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_backend_denial() -> void:
	_expect(not TestBackendPolicy.request_allowed("https://example.com"), "active harness must deny live backend transport")
	_expect(not TestBackendPolicy.request_allowed("http://127.0.0.1:9999"), "active harness must deny loopback transport too")


func _test_snapshot_restore(ops_state: Node) -> void:
	var snapshot: Dictionary = IsolationGuard.capture(self, ops_state)
	var polish_key: String = "swarmfront/arena/premium_polish_enabled"
	ProjectSettings.set_setting(polish_key, not bool(ProjectSettings.get_setting(polish_key, false)))
	Engine.time_scale = 0.75
	RenderingServer.set_default_clear_color(Color(0.91, 0.13, 0.77, 1.0))
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	ops_state.set("input_locked", not bool(ops_state.get("input_locked")))
	ops_state.set("bot_profiles", {1: {"enabled": false, "style": "gate_c_probe"}})
	set_meta("sf_perf_gate_c_temporary", {"must_restore": true})
	var restored: Dictionary = IsolationGuard.restore(snapshot, self, ops_state)
	_expect(bool(restored.get("pass", false)), "global snapshot must restore exactly: %s" % str(restored.get("mismatches", [])))
	_expect(str(restored.get("before_hash", "")) == str(restored.get("after_hash", "")), "pre/post global hashes must match")
	_expect(str(restored.get("before_protected_state_hash", "")) == str(restored.get("after_protected_state_hash", "")), "protected-state hashes must match")
	var restored_again: Dictionary = IsolationGuard.restore(snapshot, self, ops_state)
	_expect(bool(restored_again.get("pass", false)), "cleanup restoration must be idempotent")


func _test_topology_detection(ops_state: Node) -> void:
	var snapshot: Dictionary = IsolationGuard.capture(self, ops_state)
	var leaked_probe := Node.new()
	leaked_probe.name = "PerfGateCLeakProbe"
	root.add_child(leaked_probe)
	var detected: Dictionary = IsolationGuard.verify(snapshot, self, ops_state)
	_expect(not bool(detected.get("pass", true)), "root-child contamination must fail verification")
	_expect((detected.get("mismatches", []) as Array).has("tree_or_signal_topology_mismatch"), "topology mismatch must be explicit")
	leaked_probe.queue_free()
	await process_frame
	await process_frame
	var restored: Dictionary = IsolationGuard.restore(snapshot, self, ops_state)
	_expect(bool(restored.get("pass", false)), "topology must return to the captured state after cleanup")


func _test_analytics_denial(analytics: Node) -> void:
	if analytics == null or not analytics.has_method("record_event"):
		return
	var before_count: int = int(analytics.call("queue_count")) if analytics.has_method("queue_count") else -1
	var result: Dictionary = analytics.call("record_event", "match_start", {"source": "perf_gate_c_smoke"}) as Dictionary
	var after_count: int = int(analytics.call("queue_count")) if analytics.has_method("queue_count") else -1
	_expect(str(result.get("err", "")) == "perf_harness_isolated", "analytics writes must return the isolation diagnostic")
	_expect(before_count == after_count, "analytics queue count must not change")


func _test_source_contracts() -> void:
	var runner: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	_expect(runner.contains("PERF_ISOLATION_GUARD.capture(self, OpsState)"), "runner must capture before every scenario mode")
	_expect(runner.contains("_queue_fixture_root_additions"), "runner must remove fixture-created root nodes")
	_expect(runner.contains("release_fixture_state"), "runner must break discarded GameState cycles")
	_expect(runner.contains("func _finalize() -> void:"), "runner must expose a MainLoop shutdown cleanup path")
	_expect(runner.contains("_recover_interrupted_repetition()"), "shutdown must recover any armed repetition snapshot")
	_expect(runner.contains("_cleanup_entry_state()"), "shutdown must clear analytics isolation and the harness marker")
	_expect(runner.contains("DisplayServer.window_move_to_foreground()"), "foreground diagnostic must explicitly request foreground presentation")
	_expect(runner.contains("DisplayServer.window_is_focused()"), "foreground diagnostic must verify focus before measuring")
	_expect(runner.contains("OS.is_in_low_processor_usage_mode()"), "foreground diagnostic must record low-processor mode")
	_expect(runner.contains("PHASE0_ISOLATION_SENTINEL_V1"), "A-B-A sentinel fixture must remain registered")
	_expect(runner.contains("PHASE0_ISOLATION_MUTATOR_V1"), "A-B-A mutator fixture must remain registered")
	var analytics_source: String = FileAccess.get_file_as_string("res://scripts/state/analytics_client.gd")
	_expect(analytics_source.contains("perf_harness_isolated"), "analytics client must retain the harness denial path")
	var lifecycle_source: String = FileAccess.get_file_as_string("res://scripts/state/app_lifecycle_state.gd")
	_expect(lifecycle_source.contains("_perf_harness_isolation"), "AppLifecycle must retain the harness notification isolation path")
	var pacing_diagnostic_source: String = FileAccess.get_file_as_string("res://scripts/dev/run_perf_harness_pacing_diagnostic.sh")
	_expect(pacing_diagnostic_source.contains("/usr/bin/open -n -F -W"), "foreground diagnostic must use a fresh LaunchServices app process")
	_expect(pacing_diagnostic_source.contains("--perf-user-dir=${user_dir}"), "LaunchServices diagnostic must discover the unique Godot process")
	_expect(pacing_diagnostic_source.contains("reason=godot_pid_undiscovered"), "LaunchServices diagnostic must fail closed without an actual Godot PID")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_GATE_C_SMOKE: %s" % message)
