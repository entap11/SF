extends SceneTree

const StartupHitchDiagnosticScript := preload("res://scripts/dev/startup_hitch_diagnostic.gd")
const TestBackendPolicy := preload("res://scripts/state/test_backend_policy.gd")

const OUTPUT_PATH: String = "user://startup_hitch_diagnostic/startup_hitch_smoke.json"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_test_activation_contract()
	_test_backend_denial()
	var diagnostic: Node = StartupHitchDiagnosticScript.new()
	diagnostic.name = "StartupHitchDiagnosticSmoke"
	root.add_child(diagnostic)
	_expect(bool(diagnostic.call("configure", {
		"output_path": OUTPUT_PATH,
		"window_seconds": 5.0,
		"launch_classification": "warm",
		"source_commit": "smoke",
		"route": "smoke"
	})), "debug diagnostic should configure")
	diagnostic.set_process(false)
	diagnostic.call("mark_once", "match_scene_load_requested", {"source": "smoke"})
	diagnostic.call("_process", 0.016)
	diagnostic.call("_process", 0.051)
	diagnostic.call("mark_once", "first_canonical_tick_started")
	diagnostic.call("record_sim_tick", 9.0, {"unit_system": 6.0}, 1)
	var report: Dictionary = diagnostic.call("complete", "smoke_complete") as Dictionary
	_expect(str(report.get("schema", "")) == StartupHitchDiagnosticScript.SCHEMA, "report schema must match")
	_expect(str(report.get("status", "")) == "COMPLETE", "report must complete")
	_expect(bool((report.get("protected_state_integrity", {}) as Dictionary).get("pass", false)), "diagnostic must not mutate protected state")
	_expect((report.get("markers", []) as Array).size() >= 5, "report must contain bounded startup markers")
	var hitches: Array = report.get("hitches", []) as Array
	_expect(hitches.size() == 2, "one rendered-frame and one tick hitch should be captured")
	if hitches.size() == 2:
		_expect(str((hitches[0] as Dictionary).get("kind", "")) == "rendered_frame", "first hitch should be rendered frame")
		_expect(str((hitches[1] as Dictionary).get("kind", "")) == "canonical_simulation_tick", "second hitch should be canonical tick")
		_expect(str((hitches[0] as Dictionary).get("visibility", "")) == "PRE_INPUT_LOADING", "missing Arena before input must classify as pre-input loading")
	_expect(FileAccess.file_exists(OUTPUT_PATH), "structured JSON report must be written")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT_PATH))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "written report must parse as JSON object")
	diagnostic.queue_free()
	await process_frame
	var absolute_output: String = ProjectSettings.globalize_path(OUTPUT_PATH)
	if FileAccess.file_exists(OUTPUT_PATH):
		DirAccess.remove_absolute(absolute_output)
	if _failures.is_empty():
		print("STARTUP_HITCH_DIAGNOSTIC_SMOKE: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("STARTUP_HITCH_DIAGNOSTIC_SMOKE: %s" % failure)
		quit(1)


func _test_activation_contract() -> void:
	var allowed: Dictionary = StartupHitchDiagnosticScript.activation_check(true, ["--soak-perf", "--startup-hitch-diagnostic"])
	_expect(bool(allowed.get("allowed", false)), "debug soak route should allow diagnostic activation")
	var release_refusal: Dictionary = StartupHitchDiagnosticScript.activation_check(false, ["--soak-perf", "--startup-hitch-diagnostic"])
	_expect(not bool(release_refusal.get("allowed", true)), "release build must refuse diagnostic activation")
	_expect(str(release_refusal.get("reason", "")) == "debug_build_required", "release refusal must be explicit")
	var route_refusal: Dictionary = StartupHitchDiagnosticScript.activation_check(true, ["--startup-hitch-diagnostic"])
	_expect(not bool(route_refusal.get("allowed", true)), "diagnostic must require production soak route")
	_expect(str(route_refusal.get("reason", "")) == "soak_perf_required", "missing soak route refusal must be explicit")


func _test_backend_denial() -> void:
	var marker_existed: bool = has_meta("sf_perf_harness_active")
	var marker_value: Variant = get_meta("sf_perf_harness_active", false)
	set_meta("sf_perf_harness_active", true)
	_expect(not TestBackendPolicy.request_allowed("https://example.com"), "diagnostic harness marker must deny live backend transport")
	_expect(not TestBackendPolicy.request_allowed("http://127.0.0.1:9999"), "diagnostic harness marker must deny loopback transport")
	if marker_existed:
		set_meta("sf_perf_harness_active", marker_value)
	else:
		remove_meta("sf_perf_harness_active")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
