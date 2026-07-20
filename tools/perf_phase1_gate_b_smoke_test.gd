extends SceneTree

const Adapter := preload("res://scripts/tests/perf/perf_deterministic_windowed_adapter.gd")
const DeterministicHash := preload("res://scripts/tests/perf/perf_deterministic_hash.gd")
const FixtureValidator := preload("res://scripts/tests/perf/perf_fixture_validator.gd")

var _failed: bool = false


func _init() -> void:
	_test_default_schedule()
	_test_static_schedule()
	_test_invalid_schedule_refused()
	_test_runner_contract()
	if not _failed:
		print("PERF_PHASE1_GATE_B_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_default_schedule() -> void:
	var adapter := Adapter.new()
	_expect(adapter.validation_errors().is_empty(), "approved cadence must validate")
	_expect(adapter.total_frames() == 360, "approved cadence must execute exactly 360 frames")
	_expect(adapter.warmup_ticks() == 20, "approved cadence must warm up exactly 20 ticks")
	_expect(adapter.measurement_ticks() == 100, "approved cadence must measure exactly 100 ticks")
	_expect(adapter.total_ticks() == 120, "approved cadence must execute exactly 120 ticks")
	var ticks: Array[int] = []
	for frame_number in range(1, adapter.total_frames() + 1):
		if adapter.should_tick(frame_number):
			ticks.append(adapter.tick_number_for_frame(frame_number))
	_expect(ticks.size() == 120, "frame-index schedule must emit exactly 120 ticks")
	_expect(ticks.front() == 1 and ticks.back() == 120, "tick ordering must be contiguous from 1 through 120")
	for tick_index in range(ticks.size()):
		_expect(ticks[tick_index] == tick_index + 1, "elapsed time must not alter tick ordering")
	var identity: Dictionary = adapter.cadence_identity()
	_expect(not bool(identity.get("elapsed_wall_time_controls_simulation", true)), "cadence identity must refuse elapsed-time control")
	_expect(DeterministicHash.hash_variant(identity).length() == 64, "cadence identity must be hashable")


func _test_static_schedule() -> void:
	var adapter := Adapter.new({"simulation_active": false})
	var observed_ticks: int = 0
	for frame_number in range(1, adapter.total_frames() + 1):
		if adapter.should_tick(frame_number):
			observed_ticks += 1
	_expect(observed_ticks == 0, "static cadence must execute zero simulation ticks")
	_expect(adapter.measurement_frames == 300, "static cadence must preserve the 300-frame measurement window")


func _test_invalid_schedule_refused() -> void:
	var adapter := Adapter.new({"target_fps": 30, "simulation_hz": 10, "frames_per_simulation_tick": 2})
	_expect(adapter.validation_errors().has("target_fps_must_equal_simulation_hz_times_frames_per_tick"), "incoherent cadence must fail closed")


func _test_runner_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	_expect(FixtureValidator.SUPPORTED_MODES.has("deterministic_windowed_presentation"), "validator must accept the deterministic windowed mode")
	_expect(source.contains("_run_deterministic_windowed_scenario"), "runner must expose a separate deterministic windowed path")
	_expect(source.contains("deterministic_windowed_requires_display"), "deterministic windowed execution must refuse headless display")
	_expect(source.contains("sim_runner.set_process(false)"), "manual cadence must disable automatic SimRunner processing")
	_expect(source.contains("camera_settle"), "runner must record camera-settle evidence")
	_expect(source.contains("elapsed_wall_time_controls_simulation"), "runner must record frame-index scheduling identity")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_PHASE1_GATE_B_SMOKE: %s" % message)
