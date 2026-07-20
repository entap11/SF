extends SceneTree

const MAP_APPLIER := preload("res://scripts/maps/map_applier.gd")
const ARENA_POLISH_LAYER := preload("res://scripts/renderers/arena_polish_layer.gd")
const HIVE_GROWTH_RULES := preload("res://scripts/sim/hive_growth_rules.gd")
const PERF_RUN_POLICY := preload("res://scripts/tests/perf/perf_run_policy.gd")
const PERF_FIXTURE_CATALOG := preload("res://scripts/tests/perf/perf_fixture_catalog.gd")
const PERF_FEATURE_REGISTRY := preload("res://scripts/tests/perf/perf_feature_registry.gd")
const PERF_FIXTURE_VALIDATOR := preload("res://scripts/tests/perf/perf_fixture_validator.gd")
const PERF_DETERMINISTIC_WINDOWED_ADAPTER := preload("res://scripts/tests/perf/perf_deterministic_windowed_adapter.gd")
const PERF_DETERMINISTIC_HASH := preload("res://scripts/tests/perf/perf_deterministic_hash.gd")
const PERF_ISOLATION_GUARD := preload("res://scripts/tests/perf/perf_isolation_guard.gd")
const PERF_RESULT_CONTRACT := preload("res://scripts/tests/perf/perf_result_contract.gd")
const PERF_METRICS_COLLECTOR := preload("res://scripts/tests/perf/perf_metrics_collector.gd")
const PERF_BASELINE_COMPARATOR := preload("res://scripts/tests/perf/perf_baseline_comparator.gd")
const PERF_BASELINE_ELIGIBILITY := preload("res://scripts/tests/perf/perf_baseline_eligibility.gd")
const SPRITE_REGISTRY := preload("res://scripts/renderers/sprite_registry.gd")
const TEST_BACKEND_POLICY := preload("res://scripts/state/test_backend_policy.gd")

const DEFAULT_GATES_PATH := "res://data/perf/benchmark_gates.json"
const DEFAULT_FIXTURE_CATALOG_PATH := "res://data/perf/phase1_fixture_catalog_v1.json"
const DEFAULT_FEATURE_REGISTRY_PATH := "res://data/perf/feature_isolation_registry_v1.json"
const DEFAULT_OUTPUT_PATH := "res://debug_reports/perf_benchmark_latest.json"
const SCENARIO_OUTPUT_DIR := "res://debug_reports/perf_benchmarks"
const ARENA_SCENE_PATH := "res://scenes/Arena.tscn"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const FRAME_DELTA_SEC: float = 1.0 / 60.0
const SIM_TICK_INTERVAL_SEC: float = 0.1
const RENDER_DISCARD_INITIAL_FRAMES: int = 3
const DISABLE_GPU_VFX_AUTO_FALLBACK_ENV: String = "SF_DISABLE_GPU_VFX_AUTO_FALLBACK"

const MAP_QUICK := "res://maps/_future/centerstrike/MAP_centerstrike__SBASE__2p.json"
const MAP_PHASE1 := "res://maps/_future/centerstrike/MAP_centerstrike__SBASE__1p.json"
const MAP_LAYERS := "res://maps/_future/nomansland/MAP_nomansland__545__v08_spine_knife_fight__npc20__1p.json"
const MAP_STRUCTURES := "res://maps/_future/quadfight/MAP_quadfight__SBASE__1p.json"
const MAP_STRESS := "res://maps/_future/nomansland/MAP_nomansland__545__v13_top3_each__npc20__1p.json"

const EXPECTED_COUNTS_BY_MAP := {
	MAP_QUICK: {"hives": 12, "towers": 0, "barracks": 0, "structure_slots": 0},
	MAP_PHASE1: {"hives": 12, "towers": 0, "barracks": 0, "structure_slots": 0},
	MAP_LAYERS: {"hives": 14, "towers": 0, "barracks": 0, "structure_slots": 2},
	MAP_STRUCTURES: {"hives": 16, "towers": 0, "barracks": 0, "structure_slots": 4},
	MAP_STRESS: {"hives": 14, "towers": 0, "barracks": 0, "structure_slots": 2}
}
const NORMAL_MATCH_PILOT_SCHEDULE: Array = [
	{"tick": 5, "kind": "lane_intent_pair", "pair_index": 4, "intent": "attack"},
	{"tick": 15, "kind": "swarm_active_lane", "salt": 0},
	{"tick": 25, "kind": "lane_intent_pair", "pair_index": 5, "intent": "attack"},
	{"tick": 35, "kind": "lane_intent_pair", "pair_index": 6, "intent": "attack"}
]

var OpsState: Node = null
var _analytics_isolation_active: bool = false
var _app_lifecycle_isolation_active: bool = false
var _gpu_vfx_auto_fallback_env_restore: Dictionary = {}
var _interrupted_isolation_snapshot: Dictionary = {}
var _interrupted_scene_root: Node = null
var _interrupted_arena: Node = null
var _user_data_isolation: Dictionary = {
	"enabled": false,
	"name": "",
	"path": "",
	"error": ""
}
var _diagnostic_window_lifecycle: bool = false
var _diagnostic_window_events: Array[Dictionary] = []

func _init() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	_configure_user_data_isolation(user_args)
	_configure_diagnostic_window_lifecycle(user_args)
	call_deferred("_run_entry")

func _run_entry() -> void:
	if _diagnostic_window_lifecycle:
		_reassert_diagnostic_quit_guard("diagnostic_lifecycle_run_entry")
	var args: Dictionary = _parse_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not str(_user_data_isolation.get("error", "")).is_empty():
		push_error("perf_benchmark_suite: %s" % str(_user_data_isolation.get("error", "")))
		quit(2)
		return
	if not PERF_RUN_POLICY.enabled_for_runtime(OS.is_debug_build(), user_args):
		push_error("perf_benchmark_suite: %s" % PERF_RUN_POLICY.refusal_reason(OS.is_debug_build(), user_args))
		quit(2)
		return
	_disable_gpu_vfx_auto_fallback_for_harness()
	set_meta("sf_perf_harness_active", true)
	OpsState = root.get_node_or_null("/root/OpsState")
	if OpsState == null:
		push_error("perf_benchmark_suite: OpsState autoload is not available")
		remove_meta("sf_perf_harness_active")
		quit(2)
		return
	if not _set_app_lifecycle_harness_isolation(true):
		push_error("perf_benchmark_suite: app_lifecycle_isolation_unavailable")
		remove_meta("sf_perf_harness_active")
		quit(2)
		return
	_app_lifecycle_isolation_active = true
	if not _set_analytics_harness_isolation(true):
		push_error("perf_benchmark_suite: analytics_isolation_unavailable")
		_cleanup_entry_state()
		quit(2)
		return
	_analytics_isolation_active = true
	if not bool(_backend_isolation_state().get("pass", false)):
		push_error("perf_benchmark_suite: backend_isolation_unavailable")
		_cleanup_entry_state()
		quit(2)
		return
	await _prime_harness_shared_services()
	var report: Dictionary = await _run_suite(args)
	if _diagnostic_window_lifecycle:
		_diagnostic_window_event("diagnostic_lifecycle_report", {
			"auto_accept_quit": auto_accept_quit,
			"app_lifecycle_isolated": _app_lifecycle_isolation_active
		})
		report["diagnostic_window_lifecycle"] = {
			"auto_accept_quit": auto_accept_quit,
			"app_lifecycle_isolated": _app_lifecycle_isolation_active,
			"events": _diagnostic_window_events.duplicate(true)
		}
	var output_path := str(args.get("output", DEFAULT_OUTPUT_PATH))
	_write_json(output_path, report)
	for scenario_any in report.get("scenarios", []) as Array:
		var scenario: Dictionary = scenario_any as Dictionary
		_write_json("%s/%s_latest.json" % [SCENARIO_OUTPUT_DIR, str(scenario.get("scenario_id", "unknown"))], scenario)
	print("perf_benchmark_suite: %s" % JSON.stringify(_summary_for_print(report)))
	_cleanup_entry_state()
	var exit_code: int = 0 if bool(report.get("pass", false)) else 2 if str(report.get("run_status", "")) == "INVALID" else 1
	call_deferred("_quit_after_entry_unwinds", exit_code)

func _quit_after_entry_unwinds(exit_code: int) -> void:
	quit(exit_code)

func _run_suite(args: Dictionary) -> Dictionary:
	var benchmark_mode := _normalized_benchmark_mode(str(args.get("mode", "canonical_sim_headless")).strip_edges())
	if benchmark_mode.is_empty():
		benchmark_mode = "canonical_sim_headless"
	var suite_id := str(args.get("suite", "quick")).strip_edges()
	if suite_id.is_empty():
		suite_id = "quick"
	var catalog_result: Dictionary = PERF_FIXTURE_CATALOG.load_catalog(str(args.get("catalog", DEFAULT_FIXTURE_CATALOG_PATH)))
	args["_fixture_catalog_identity"] = (catalog_result.get("identity", {}) as Dictionary).duplicate(true)
	if not bool(catalog_result.get("ok", false)):
		return _invalid_suite_report(suite_id, benchmark_mode, "fixture_catalog_validation_failed", catalog_result.get("errors", []), args)
	var fixture_catalog_identity: Dictionary = (catalog_result.get("identity", {}) as Dictionary).duplicate(true)
	var fixture_catalog: Dictionary = catalog_result.get("catalog", {}) as Dictionary
	var catalog_fixtures_by_id: Dictionary = catalog_result.get("fixtures_by_id", {}) as Dictionary
	var catalog_common: Dictionary = fixture_catalog.get("common", {}) as Dictionary
	var feature_registry_result: Dictionary = PERF_FEATURE_REGISTRY.load_registry(DEFAULT_FEATURE_REGISTRY_PATH)
	args["_feature_registry_identity"] = (feature_registry_result.get("identity", {}) as Dictionary).duplicate(true)
	if not bool(feature_registry_result.get("ok", false)):
		return _invalid_suite_report(suite_id, benchmark_mode, "feature_registry_validation_failed", feature_registry_result.get("errors", []), args)
	var feature_registry: Dictionary = feature_registry_result.get("registry", {}) as Dictionary
	var feature_registry_identity: Dictionary = (feature_registry_result.get("identity", {}) as Dictionary).duplicate(true)
	var collection_level: String = PERF_RESULT_CONTRACT.normalize_collection_level(str(args.get("collection_level", PERF_RESULT_CONTRACT.COLLECTION_LEVEL_MINIMAL)))
	if not PERF_RESULT_CONTRACT.is_known_collection_level(collection_level):
		return _invalid_suite_report(suite_id, benchmark_mode, "collection_level_invalid", ["expected OFF, MINIMAL, or FULL"], args)
	if benchmark_mode in ["render_windowed", "deterministic_windowed_presentation", "static_windowed_deterministic"] and DisplayServer.get_name() == "headless":
		var refusal: String = "deterministic_windowed_requires_display" if benchmark_mode != "render_windowed" else "render_windowed_requires_display"
		return _invalid_suite_report(suite_id, benchmark_mode, refusal, ["windowed frame timing is unavailable on the headless display server"], args)
	var gate_result: Dictionary = PERF_FIXTURE_VALIDATOR.load_gate_config(str(args.get("gates", DEFAULT_GATES_PATH)))
	if not bool(gate_result.get("ok", false)):
		return _invalid_suite_report(suite_id, benchmark_mode, "gate_validation_failed", gate_result.get("errors", []), args)
	var gates: Dictionary = gate_result.get("gates", {}) as Dictionary
	var switch_overrides: Dictionary = args.get("switch_overrides", {}) as Dictionary
	var switch_errors: Array[String] = _validate_switch_overrides(switch_overrides)
	if not switch_errors.is_empty():
		return _invalid_suite_report(suite_id, benchmark_mode, "feature_switch_validation_failed", switch_errors, args)
	var scenario_defs: Array = _scenario_definitions(suite_id, switch_overrides, str(args.get("scenario", "")).strip_edges(), catalog_fixtures_by_id, catalog_common)
	if args.has("repetitions"):
		for scenario_any in scenario_defs:
			(scenario_any as Dictionary)["repetitions"] = clampi(int(args.get("repetitions", 1)), 1, 10)
	for scenario_any in scenario_defs:
		var scenario_def: Dictionary = scenario_any as Dictionary
		if str(scenario_def.get("measurement_profile", "")).strip_edges().is_empty():
			scenario_def["measurement_profile"] = _measurement_profile_for_benchmark_mode(benchmark_mode)
		var scenario_collection_level: String = PERF_RESULT_CONTRACT.normalize_collection_level(str(scenario_def.get("_collection_level_override", collection_level)))
		if not PERF_RESULT_CONTRACT.is_known_collection_level(scenario_collection_level):
			return _invalid_suite_report(suite_id, benchmark_mode, "scenario_collection_level_invalid", [str(scenario_def.get("scenario_id", "unknown"))], args)
		scenario_def["_collection_level"] = scenario_collection_level
	if args.has("map") and not str(args.get("map", "")).strip_edges().is_empty():
		for scenario_any in scenario_defs:
			var scenario_def: Dictionary = scenario_any as Dictionary
			scenario_def["map_path"] = str(args.get("map", ""))
			scenario_def.erase("expected_counts")
	if scenario_defs.is_empty():
		return _invalid_suite_report(suite_id, benchmark_mode, "scenario_selection_empty", ["suite or scenario filter selected no scenarios"], args)
	var preflight_errors: Array = []
	for scenario_any in scenario_defs:
		var scenario_def: Dictionary = scenario_any as Dictionary
		var preflight: Dictionary = PERF_FIXTURE_VALIDATOR.static_preflight(scenario_def, benchmark_mode)
		if not bool(preflight.get("ok", false)):
			preflight_errors.append({
				"scenario_id": str(scenario_def.get("scenario_id", "unknown")),
				"errors": (preflight.get("errors", []) as Array).duplicate(true)
			})
			continue
		scenario_def["_preflight_map_data"] = (preflight.get("map_data", {}) as Dictionary).duplicate(true)
		scenario_def["_preflight_runtime_counts"] = (preflight.get("expected_runtime_counts", {}) as Dictionary).duplicate(true)
		scenario_def["_preflight_map_content_hash"] = str(preflight.get("map_content_hash", ""))
		scenario_def["_fixture_config_hash"] = PERF_DETERMINISTIC_HASH.hash_variant(_fixture_identity_payload(scenario_def))
	if not preflight_errors.is_empty():
		return _invalid_suite_report(suite_id, benchmark_mode, "fixture_preflight_failed", preflight_errors, args)
	var scenarios: Array = []
	var suite_sequence_index: int = 0
	for scenario_def_any in scenario_defs:
		var base_scenario_def: Dictionary = scenario_def_any as Dictionary
		var repetitions: int = clampi(int(base_scenario_def.get("repetitions", 1)), 1, 10)
		for repetition_index in range(repetitions):
			suite_sequence_index += 1
			var scenario_def: Dictionary = base_scenario_def.duplicate(true)
			scenario_def["_repetition_index"] = repetition_index + 1
			scenario_def["_suite_sequence_index"] = suite_sequence_index
			var scenario: Dictionary
			match benchmark_mode:
				"deterministic_windowed_presentation", "static_windowed_deterministic":
					scenario = await _run_deterministic_windowed_scenario(scenario_def, benchmark_mode, gates)
				"render_windowed":
					scenario = await _run_render_scenario(scenario_def, benchmark_mode, gates)
				"layer_isolation_noncanonical":
					scenario = await _run_layer_isolation_scenario(scenario_def, benchmark_mode, gates)
				_:
					scenario = await _run_canonical_sim_scenario(scenario_def, benchmark_mode, gates)
			scenarios.append(scenario)
	var failed: Array = []
	var integrity_failed: Array = []
	for scenario_any in scenarios:
		var scenario: Dictionary = scenario_any as Dictionary
		if not bool(scenario.get("pass", false)) and not bool(scenario.get("allowed_failure", false)):
			failed.append(str(scenario.get("scenario_id", "")))
		for gate_any in scenario.get("failed_gates", []) as Array:
			if typeof(gate_any) == TYPE_DICTIONARY and str((gate_any as Dictionary).get("gate", "")) == "scenario_setup":
				integrity_failed.append(str(scenario.get("scenario_id", "")))
	var determinism: Dictionary = _determinism_evidence(scenarios)
	if not bool(determinism.get("pass", true)):
		integrity_failed.append("determinism")
	var isolation: Dictionary = _isolation_evidence(scenarios)
	if not bool(isolation.get("pass", true)):
		integrity_failed.append("isolation")
	var backend_isolation: Dictionary = _backend_isolation_state()
	if not bool(backend_isolation.get("pass", false)):
		integrity_failed.append("backend_isolation")
	var collector_calibration: Dictionary = {}
	if suite_id == "phase0_collector_calibration":
		collector_calibration = _collector_calibration_evidence(scenarios)
		if not bool(collector_calibration.get("pass", false)):
			integrity_failed.append("collector_calibration")
	var lifecycle_soak: Dictionary = _lifecycle_soak_evidence(scenarios) if suite_id == "phase2_lifecycle_soak" else {}
	if not lifecycle_soak.is_empty() and not bool(lifecycle_soak.get("pass", false)):
		integrity_failed.append("lifecycle_soak")
	var feature_isolation: Dictionary = _feature_isolation_evidence(scenarios, feature_registry) if suite_id == "phase2_feature_isolation" else {}
	if not feature_isolation.is_empty() and not bool(feature_isolation.get("pass", false)):
		integrity_failed.append("feature_isolation")
	var unit_scale_diagnostic: Dictionary = _unit_scale_diagnostic(scenarios) if suite_id == "phase1_unit_scale" else {}
	var report := {
		"report_type": "sf_perf_benchmark_suite",
		"result_schema_version": PERF_RESULT_CONTRACT.RESULT_SCHEMA_VERSION,
		"run_status": "INVALID" if not integrity_failed.is_empty() else "COMPLETED",
		"integrity_status": "FAIL" if not integrity_failed.is_empty() else "PASS",
		"suite_id": suite_id,
		"benchmark_mode": benchmark_mode,
		"collection_level": collection_level,
		"generated_at_unix": Time.get_unix_time_from_system(),
		"git": _git_metadata(),
		"godot": Engine.get_version_info(),
		"machine": _machine_metadata(),
		"user_data_isolation": _user_data_isolation.duplicate(true),
		"fixture_catalog": fixture_catalog_identity,
		"feature_registry": feature_registry_identity,
		"gates": gates.duplicate(true),
		"gate_source": str(gate_result.get("source", "")),
		"switch_overrides": switch_overrides.duplicate(true),
		"scenario_count": scenarios.size(),
		"scenarios": scenarios,
		"determinism": determinism,
		"isolation": isolation,
		"backend_isolation": backend_isolation,
		"collector_calibration": collector_calibration,
		"lifecycle_soak": lifecycle_soak,
		"feature_isolation": feature_isolation,
		"unit_scale_diagnostic": unit_scale_diagnostic,
		"pass": failed.is_empty() and bool(determinism.get("pass", true)) and bool(isolation.get("pass", true)) and bool(backend_isolation.get("pass", false)) and (collector_calibration.is_empty() or bool(collector_calibration.get("pass", false))) and (lifecycle_soak.is_empty() or bool(lifecycle_soak.get("pass", false))) and (feature_isolation.is_empty() or bool(feature_isolation.get("pass", false))),
		"failed_scenarios": failed,
		"integrity_failed_scenarios": integrity_failed
	}
	report.merge(_result_environment(gates), true)
	PERF_BASELINE_ELIGIBILITY.apply(report, fixture_catalog, catalog_fixtures_by_id)
	_apply_result_contract(report)
	var baseline_path := str(args.get("baseline", "")).strip_edges()
	if not baseline_path.is_empty():
		var baseline: Dictionary = _load_json(baseline_path)
		if not baseline.is_empty():
			var comparison: Dictionary = _compare_reports(baseline, report, gates)
			report["baseline_comparison"] = comparison
			report["baseline_approval"] = PERF_RESULT_CONTRACT.baseline_approval(report, comparison.get("compatibility", {}) as Dictionary, baseline)
		else:
			report["baseline_comparison"] = {
				"status": "INVALID_BASELINE",
				"pass": false,
				"baseline_path": baseline_path,
				"reason": "baseline_missing_or_invalid_json"
			}
			var approval: Dictionary = PERF_RESULT_CONTRACT.baseline_approval(report)
			var approval_reasons: Array = (approval.get("reasons", []) as Array).duplicate()
			approval_reasons.append("baseline_missing_or_invalid_json")
			approval["status"] = "REFUSED"
			approval["eligible"] = false
			approval["reasons"] = approval_reasons
			report["baseline_approval"] = approval
	return report

func _run_canonical_sim_scenario(scenario_def: Dictionary, benchmark_mode: String, gates: Dictionary) -> Dictionary:
	var isolation_snapshot: Dictionary = PERF_ISOLATION_GUARD.capture(self, OpsState)
	_arm_interrupted_cleanup(isolation_snapshot)
	var setup_start_usec: int = Time.get_ticks_usec()
	var setup: Dictionary = await _setup_arena_for_scenario(scenario_def, false)
	if not bool(setup.get("ok", false)):
		return await _finalize_scenario(
			_scenario_error(scenario_def, benchmark_mode, str(setup.get("reason", "setup_failed")), gates),
			isolation_snapshot,
			setup.get("scene_root", null) as Node,
			setup.get("arena", null) as Node
		)
	var scene_root: Node = setup.get("scene_root", null) as Node
	var arena: Node = setup.get("arena", null) as Node
	_update_interrupted_cleanup_nodes(scene_root, arena)
	var sim_runner: Node = _arena_sim_runner(arena)
	if sim_runner == null or not sim_runner.has_method("_tick"):
		return await _finalize_scenario(
			_scenario_error(scenario_def, benchmark_mode, "canonical_simrunner_tick_missing", gates),
			isolation_snapshot,
			scene_root,
			arena
		)
	sim_runner.set_process(false)
	sim_runner.set_physics_process(false)
	sim_runner.set_process_unhandled_input(false)
	var state: GameState = OpsState.require_state()
	_prepare_match_for_benchmark()
	_disable_bots_for_benchmark()
	var bot_isolation: Dictionary = _bot_isolation_evidence()
	var command_log: Array = []
	var initial_commands: Array = _apply_scenario_initial_state(arena, state, scenario_def)
	if not initial_commands.is_empty():
		command_log.append({"tick": 0, "commands": initial_commands})
	var setup_ms: float = float(Time.get_ticks_usec() - setup_start_usec) / 1000.0
	var tick_count: int = int(scenario_def.get("tick_count", round(float(scenario_def.get("duration_sec", 1.0)) / SIM_TICK_INTERVAL_SEC)))
	tick_count = maxi(1, tick_count)
	var warmup_ticks: int = clampi(int(scenario_def.get("warmup_ticks", 0)), 0, tick_count - 1)
	var collection_level: String = str(scenario_def.get("_collection_level", PERF_RESULT_CONTRACT.COLLECTION_LEVEL_MINIMAL))
	var collector := PERF_METRICS_COLLECTOR.new(
		collection_level,
		int(gates.get("worst_frame_limit", 10)),
		float(gates.get("target_frame_ms", INF))
	)
	var measured_tick_count: int = tick_count - warmup_ticks
	var measurement_wall_start_usec: int = 0
	for tick_index in range(1, tick_count + 1):
		var issued: Array = _issue_commands_for_tick(arena, state, scenario_def, tick_index)
		if not issued.is_empty():
			command_log.append({"tick": tick_index, "commands": issued})
		var measured: bool = tick_index > warmup_ticks
		if measured and measurement_wall_start_usec == 0:
			measurement_wall_start_usec = Time.get_ticks_usec()
		if measured and collector.timing_enabled():
			var tick_start_usec: int = Time.get_ticks_usec()
			sim_runner.call("_tick", SIM_TICK_INTERVAL_SEC)
			var tick_ms: float = float(Time.get_ticks_usec() - tick_start_usec) / 1000.0
			var context: Dictionary = {}
			if collector.needs_forensic_context(tick_ms):
				var phase_any: Variant = sim_runner.get("_last_tick_phase_costs")
				if typeof(phase_any) == TYPE_DICTIONARY:
					context["phase_times_ms"] = phase_any as Dictionary
			collector.observe(tick_index, tick_ms, context)
		else:
			sim_runner.call("_tick", SIM_TICK_INTERVAL_SEC)
	var measurement_wall_duration_ms: float = float(Time.get_ticks_usec() - measurement_wall_start_usec) / 1000.0 if measurement_wall_start_usec > 0 else 0.0
	var collection: Dictionary = collector.summary()
	var command_count: int = _scripted_command_count_from_log(command_log)
	var command_log_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(command_log)
	var accepted_command_evidence: Array = _flatten_command_log(command_log)
	var requested_seed: int = int(scenario_def.get("seed", 0))
	var effective_seed: int = int(setup.get("effective_seed", 0))
	var final_state_hash: String = str(OpsState.call("get_contract_state_hash")) if OpsState.has_method("get_contract_state_hash") else ""
	var integrity_failures: Array = []
	if not bool(bot_isolation.get("pass", false)):
		integrity_failures.append("bots_not_disabled")
	if requested_seed != effective_seed:
		integrity_failures.append("effective_seed_mismatch")
	if final_state_hash.is_empty():
		integrity_failures.append("final_state_hash_missing")
	if command_count < int(scenario_def.get("expected_command_count_min", 0)):
		integrity_failures.append("scheduled_command_count_below_minimum")
	if scenario_def.has("expected_command_count_exact") and command_count != int(scenario_def.get("expected_command_count_exact", -1)):
		integrity_failures.append("scheduled_command_count_not_exact")
	if not str(scenario_def.get("expected_command_log_hash", "")).is_empty() and command_log_hash != str(scenario_def.get("expected_command_log_hash", "")):
		integrity_failures.append("accepted_command_hash_mismatch")
	if scenario_def.has("expected_accepted_commands") and PERF_DETERMINISTIC_HASH.hash_variant(accepted_command_evidence) != PERF_DETERMINISTIC_HASH.hash_variant(scenario_def.get("expected_accepted_commands", [])):
		integrity_failures.append("accepted_command_evidence_mismatch")
	if benchmark_mode == "canonical_sim_headless" and not str(scenario_def.get("expected_canonical_final_state_hash", "")).is_empty() and final_state_hash != str(scenario_def.get("expected_canonical_final_state_hash", "")):
		integrity_failures.append("canonical_final_state_hash_mismatch")
	var observed_command_types: Array[String] = _command_types_from_log(command_log)
	for expected_type_any in scenario_def.get("expected_command_types", []) as Array:
		var expected_type: String = str(expected_type_any)
		if not observed_command_types.has(expected_type):
			integrity_failures.append("scheduled_command_type_missing:%s" % expected_type)
	if OpsState.match_phase != OpsState.MatchPhase.RUNNING or bool(OpsState.match_over):
		integrity_failures.append("fixture_ended_match")
	var baseline_reasons: Array = ["phase1_fixture_not_baseline_approved"] if bool(scenario_def.get("catalog_fixture_registered", false)) else ["phase0_integrity_or_unapproved_fixture"]
	if int(scenario_def.get("calibration_sequence_index", 0)) > 0:
		baseline_reasons = ["collector_overhead_calibration"]
	if collection_level == PERF_METRICS_COLLECTOR.LEVEL_OFF:
		baseline_reasons.append("timing_collection_off")
	var report := _base_scenario_report(scenario_def, benchmark_mode, gates)
	report.merge({
		"canonical_simulation": true,
		"baseline_eligible": false,
		"baseline_ineligible_reasons": baseline_reasons,
		"duration_sec": float(tick_count) * SIM_TICK_INTERVAL_SEC,
		"warmup_duration_sec": float(warmup_ticks) * SIM_TICK_INTERVAL_SEC,
		"measurement_duration_sec": float(measured_tick_count) * SIM_TICK_INTERVAL_SEC,
		"measurement_wall_duration_ms": measurement_wall_duration_ms,
		"sim_tick_interval_sec": SIM_TICK_INTERVAL_SEC,
		"setup_duration_ms": setup_ms,
		"tick_count": tick_count,
		"warmup_tick_count": warmup_ticks,
		"measured_tick_count": measured_tick_count,
		"collection": collection,
		"scripted_command_count": command_count,
		"scripted_command_ticks": command_log,
		"command_schedule_hash": command_log_hash,
		"accepted_command_evidence": accepted_command_evidence,
		"effective_seed": effective_seed,
		"observed_command_types": observed_command_types,
		"final_state_hash": final_state_hash,
		"runtime_counts": PERF_FIXTURE_VALIDATOR.runtime_counts(state, arena),
		"fixture_setup_evidence": {
			"content_kind": str(setup.get("content_kind", "")),
			"map_loader_used": bool(setup.get("map_loader_used", false)),
			"map_applier_used": bool(setup.get("map_applier_used", false)),
			"expected_counts": (setup.get("expected_counts", {}) as Dictionary).duplicate(true),
			"actual_counts": (setup.get("actual_counts", {}) as Dictionary).duplicate(true),
			"exact_counts": bool(setup.get("counts_exact", false))
		},
		"bot_isolation": bot_isolation,
		"match": _match_summary(state, tick_count),
		"average_tick_ms": collection.get("average_ms"),
		"median_tick_ms": collection.get("median_ms"),
		"p95_tick_ms": collection.get("p95_ms"),
		"p99_tick_ms": collection.get("p99_ms"),
		"max_tick_ms": collection.get("max_ms"),
		"worst_sim_ticks": _canonical_worst_records(collection.get("worst_records", []) as Array),
		"performance_status": "NOT_COLLECTED" if not collector.timing_enabled() else "NOT_GATED",
		"pass": integrity_failures.is_empty(),
		"integrity_failures": integrity_failures,
		"failed_gates": []
	}, true)
	return await _finalize_scenario(report, isolation_snapshot, scene_root, arena)

func _run_layer_isolation_scenario(scenario_def: Dictionary, benchmark_mode: String, gates: Dictionary) -> Dictionary:
	var isolation_snapshot: Dictionary = PERF_ISOLATION_GUARD.capture(self, OpsState)
	_arm_interrupted_cleanup(isolation_snapshot)
	var setup_start_usec := Time.get_ticks_usec()
	var setup: Dictionary = await _setup_arena_for_scenario(scenario_def, false)
	if not bool(setup.get("ok", false)):
		return await _finalize_scenario(
			_scenario_error(scenario_def, benchmark_mode, str(setup.get("reason", "setup_failed")), gates),
			isolation_snapshot,
			setup.get("scene_root", null) as Node,
			setup.get("arena", null) as Node
		)
	var scene_root: Node = setup.get("scene_root", null) as Node
	var arena: Node = setup.get("arena", null) as Node
	_update_interrupted_cleanup_nodes(scene_root, arena)
	var sim_runner: Node = _arena_sim_runner(arena)
	var state: GameState = OpsState.require_state()
	_prepare_match_for_benchmark()
	var initial_commands: Array = _apply_scenario_initial_state(arena, state, scenario_def)
	var setup_ms := float(Time.get_ticks_usec() - setup_start_usec) / 1000.0
	var command_log: Array = []
	if not initial_commands.is_empty():
		command_log.append({"tick": 0, "commands": initial_commands})
	var frame_count: int = int(ceil(float(scenario_def.get("duration_sec", 1.0)) / FRAME_DELTA_SEC))
	var collection_level: String = str(scenario_def.get("_collection_level", PERF_RESULT_CONTRACT.COLLECTION_LEVEL_MINIMAL))
	var collector := PERF_METRICS_COLLECTOR.new(
		collection_level,
		int(gates.get("worst_frame_limit", 10)),
		float(gates.get("target_frame_ms", INF))
	)
	var sim_phase_collector := PERF_METRICS_COLLECTOR.new(
		collection_level,
		int(gates.get("worst_frame_limit", 10)),
		INF
	)
	var tick_accumulator := 0.0
	var tick_index := 0
	for frame_index in range(frame_count):
		var frame_start_usec: int = Time.get_ticks_usec() if collector.timing_enabled() else 0
		tick_accumulator += FRAME_DELTA_SEC
		var last_sections: Dictionary = {}
		while tick_accumulator + 0.000001 >= SIM_TICK_INTERVAL_SEC:
			tick_accumulator -= SIM_TICK_INTERVAL_SEC
			tick_index += 1
			var issued: Array = _issue_scripted_commands(arena, state, scenario_def, tick_index)
			if not issued.is_empty():
				command_log.append({"tick": tick_index, "commands": issued})
			last_sections = _tick_selected_systems(arena, sim_runner, state, scenario_def, SIM_TICK_INTERVAL_SEC)
			if sim_phase_collector.timing_enabled():
				var sim_total_ms: float = float(last_sections.get("total_ms", 0.0))
				var sim_context: Dictionary = {"phase_times_ms": last_sections} if sim_phase_collector.needs_forensic_context(sim_total_ms) else {}
				sim_phase_collector.observe(tick_index, sim_total_ms, sim_context)
		if collector.timing_enabled():
			var frame_ms: float = float(Time.get_ticks_usec() - frame_start_usec) / 1000.0
			var frame_context: Dictionary = {}
			if collector.needs_forensic_context(frame_ms):
				frame_context = {
					"tick": tick_index,
					"phase": "simulation",
					"classification": _classification_for_frame(frame_ms, gates, last_sections),
					"sim_sections": last_sections
				}
			collector.observe(frame_index + 1, frame_ms, frame_context)
	var collection: Dictionary = collector.summary()
	var sim_phase_collection: Dictionary = sim_phase_collector.summary()
	var metrics: Dictionary = _collector_frame_metrics(collection)
	var failed_gates: Array = _failed_gates(metrics, int(collection.get("hitch_count", 0)), gates) if collector.timing_enabled() else []
	var report := _base_scenario_report(scenario_def, benchmark_mode, gates)
	report.merge({
		"canonical_simulation": false,
		"baseline_eligible": false,
		"baseline_ineligible_reasons": ["layer_isolation_noncanonical"],
		"duration_sec": float(scenario_def.get("duration_sec", 0.0)),
		"warmup_duration_sec": 0.0,
		"measurement_duration_sec": float(scenario_def.get("duration_sec", 0.0)),
		"frame_delta_sec": FRAME_DELTA_SEC,
		"sim_tick_interval_sec": SIM_TICK_INTERVAL_SEC,
		"setup_duration_ms": setup_ms,
		"frame_count": frame_count,
		"measured_frame_count": frame_count,
		"collection": collection,
		"sim_phase_collection": sim_phase_collection,
		"scripted_command_count": _scripted_command_count_from_log(command_log),
		"scripted_command_ticks": command_log,
		"command_schedule_hash": PERF_DETERMINISTIC_HASH.hash_variant(command_log),
		"match": _match_summary(state, tick_index),
		"average_frame_ms": collection.get("average_ms"),
		"median_frame_ms": collection.get("median_ms"),
		"p95_frame_ms": collection.get("p95_ms"),
		"p99_frame_ms": collection.get("p99_ms"),
		"p999_frame_ms": collection.get("p999_ms"),
		"max_frame_ms": collection.get("max_ms"),
		"hitch_threshold_ms": float(gates.get("target_frame_ms", 0.0)),
		"hitch_count": collection.get("hitch_count"),
		"hitches": _collector_hitch_records(collection.get("hitch_records", []) as Array),
		"worst_frames": _frame_worst_records(collection.get("worst_records", []) as Array),
		"worst_sim_ticks": _canonical_worst_records(sim_phase_collection.get("worst_records", []) as Array),
		"performance_status": "NOT_COLLECTED" if not collector.timing_enabled() else "GATED_NONCANONICAL",
		"pass": failed_gates.is_empty(),
		"failed_gates": failed_gates
	}, true)
	return await _finalize_scenario(report, isolation_snapshot, scene_root, arena)

func _run_deterministic_windowed_scenario(scenario_def: Dictionary, benchmark_mode: String, gates: Dictionary) -> Dictionary:
	var isolation_snapshot: Dictionary = PERF_ISOLATION_GUARD.capture(self, OpsState)
	var lifecycle_profile: String = str(scenario_def.get("phase2_lifecycle_profile", ""))
	var lifecycle_runtime_before: Dictionary = _runtime_counter_snapshot() if not lifecycle_profile.is_empty() else {}
	_arm_interrupted_cleanup(isolation_snapshot)
	var adapter := PERF_DETERMINISTIC_WINDOWED_ADAPTER.new(scenario_def.get("cadence", {}) as Dictionary)
	var cadence_errors: Array[String] = adapter.validation_errors()
	if not cadence_errors.is_empty():
		return await _finalize_scenario(
			_scenario_error(scenario_def, benchmark_mode, "deterministic_cadence_invalid:%s" % str(cadence_errors), gates),
			isolation_snapshot,
			null,
			null
		)
	Engine.max_fps = adapter.target_fps
	var setup_start_usec: int = Time.get_ticks_usec()
	var setup: Dictionary = await _setup_arena_for_scenario(scenario_def, true)
	if not bool(setup.get("ok", false)):
		return await _finalize_scenario(
			_scenario_error(scenario_def, benchmark_mode, str(setup.get("reason", "setup_failed")), gates),
			isolation_snapshot,
			setup.get("scene_root", null) as Node,
			setup.get("arena", null) as Node
		)
	var scene_root: Node = setup.get("scene_root", null) as Node
	var arena: Node = setup.get("arena", null) as Node
	_update_interrupted_cleanup_nodes(scene_root, arena)
	var sim_runner: Node = _arena_sim_runner(arena)
	if sim_runner == null or not sim_runner.has_method("_tick"):
		return await _finalize_scenario(
			_scenario_error(scenario_def, benchmark_mode, "deterministic_simrunner_tick_missing", gates),
			isolation_snapshot,
			scene_root,
			arena
		)
	# The adapter, not production processing or elapsed wall time, owns tick ordering.
	sim_runner.set_process(false)
	sim_runner.set_physics_process(false)
	sim_runner.set_process_unhandled_input(false)
	var state: GameState = OpsState.require_state()
	_prepare_match_for_benchmark()
	_disable_bots_for_benchmark()
	var bot_isolation: Dictionary = _bot_isolation_evidence()
	var initial_commands: Array = _apply_scenario_initial_state(arena, state, scenario_def)
	var unit_scale_setup: Dictionary = {}
	if int(scenario_def.get("target_units", 0)) > 0:
		unit_scale_setup = await _prepare_unit_scale_fixture(arena, sim_runner, state, scenario_def)
		if not bool(unit_scale_setup.get("pass", false)):
			return await _finalize_scenario(
				_scenario_error(scenario_def, benchmark_mode, "unit_scale_setup_failed:%s" % str(unit_scale_setup.get("reason", "unknown")), gates),
				isolation_snapshot,
				scene_root,
				arena
			)
	_apply_render_isolation(arena, scenario_def)
	var camera_settle: Dictionary = await _settle_windowed_camera(arena, str(scenario_def.get("camera_policy", "production_map_fit")))
	var camera_identity: Dictionary = camera_settle.get("identity", {}) as Dictionary
	var camera_identity_hash: String = str(camera_settle.get("hash", ""))
	var cadence_identity: Dictionary = adapter.cadence_identity()
	# Keep this explicit in the runner source: elapsed_wall_time_controls_simulation is always false.
	cadence_identity["elapsed_wall_time_controls_simulation"] = false
	var cadence_identity_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(cadence_identity)
	var setup_ms: float = float(Time.get_ticks_usec() - setup_start_usec) / 1000.0
	var collection_level: String = str(scenario_def.get("_collection_level", PERF_RESULT_CONTRACT.COLLECTION_LEVEL_MINIMAL))
	var collector := PERF_METRICS_COLLECTOR.new(
		collection_level,
		int(gates.get("worst_frame_limit", 10)),
		float(gates.get("hitch_threshold_ms", gates.get("p99_max_ms", INF))),
		-1,
		-1,
		0
	)
	var command_log: Array = []
	if not initial_commands.is_empty():
		command_log.append({"tick": 0, "commands": initial_commands})
	var measured_frame_count: int = 0
	var observed_warmup_duration_ms: float = 0.0
	var observed_measurement_duration_ms: float = 0.0
	var tick_index: int = 0
	var target_units: int = int(scenario_def.get("target_units", 0))
	var unit_count_policy: String = str(scenario_def.get("unit_count_policy", "exact_static"))
	var unit_count_min: int = _runtime_unit_count(state) if target_units > 0 else 0
	var unit_count_max: int = unit_count_min
	var unit_motion_start: Array = _unit_motion_snapshot(state) if target_units > 0 else []
	var unit_count_timeline: Array = []
	var phase2_stress_profile: String = str(scenario_def.get("phase2_stress_profile", ""))
	var phase2_stress_tracker: Dictionary = _phase2_stress_tracker_start(state, scenario_def) if not phase2_stress_profile.is_empty() else {}
	var phase2_render_peaks: Dictionary = {}
	var phase2_battlefield_profile: String = str(scenario_def.get("phase2_battlefield_profile", ""))
	var phase2_battlefield_tracker: Dictionary = _phase2_battlefield_tracker_start(state, scenario_def) if not phase2_battlefield_profile.is_empty() else {}
	var phase2_battlefield_render_peaks: Dictionary = {}
	var render_monitor_peaks: Dictionary = {
		"draw_calls": 0,
		"rendered_objects": 0,
		"rendered_primitives": 0
	}
	for frame_number in range(1, adapter.total_frames() + 1):
		var frame_start_usec: int = Time.get_ticks_usec()
		if not phase2_battlefield_tracker.is_empty():
			_phase2_apply_presentation_schedule(scene_root, arena, scenario_def, frame_number, phase2_battlefield_tracker)
		if adapter.should_tick(frame_number):
			tick_index = adapter.tick_number_for_frame(frame_number)
			var issued: Array = _issue_commands_for_tick(arena, state, scenario_def, tick_index)
			if not issued.is_empty():
				command_log.append({"tick": tick_index, "commands": issued})
			sim_runner.call("_tick", SIM_TICK_INTERVAL_SEC)
			if not phase2_stress_tracker.is_empty() or not phase2_battlefield_tracker.is_empty():
				# Manual deterministic ticks bypass Arena's process-owned publish cadence.
				# Publish the resulting canonical model through the production renderer path.
				if arena.has_method("mark_render_dirty"):
					arena.call("mark_render_dirty", "perf_phase2_canonical_tick")
				if arena.has_method("_push_render_model"):
					arena.call("_push_render_model")
			if not phase2_stress_tracker.is_empty():
				_phase2_stress_track_tick(phase2_stress_tracker, state, sim_runner, tick_index)
			if not phase2_battlefield_tracker.is_empty():
				_phase2_battlefield_track_tick(phase2_battlefield_tracker, state, tick_index)
			if target_units > 0 and unit_count_policy == "bounded_moving":
				unit_count_timeline.append({
					"tick": tick_index,
					"units": _runtime_unit_count(state)
				})
		await process_frame
		if not phase2_stress_tracker.is_empty():
			_phase2_stress_track_render(phase2_render_peaks, arena)
		if not phase2_battlefield_tracker.is_empty():
			_phase2_battlefield_track_render(phase2_battlefield_render_peaks, scene_root, arena)
		if target_units > 0:
			var current_unit_count: int = _runtime_unit_count(state)
			unit_count_min = mini(unit_count_min, current_unit_count)
			unit_count_max = maxi(unit_count_max, current_unit_count)
		var frame_ms: float = float(Time.get_ticks_usec() - frame_start_usec) / 1000.0
		if adapter.is_measurement_frame(frame_number):
			measured_frame_count += 1
			observed_measurement_duration_ms += frame_ms
			if collector.timing_enabled():
				var frame_context: Dictionary = {}
				if collector.needs_forensic_context(frame_ms):
					frame_context = {
						"tick": tick_index,
						"phase": "deterministic_windowed_presentation",
						"classification": _classification_for_frame(frame_ms, gates, {}),
						"renderer_configuration_state": _renderer_configuration_state(arena)
					}
				collector.observe(measured_frame_count, frame_ms, frame_context)
			_capture_render_monitor_peaks(render_monitor_peaks)
		else:
			observed_warmup_duration_ms += frame_ms
	var collection: Dictionary = collector.summary()
	var metrics: Dictionary = _collector_frame_metrics(collection)
	var performance_gating: bool = bool(scenario_def.get("performance_gating", true))
	var failed_gates: Array = _failed_gates(metrics, int(collection.get("hitch_count", 0)), gates) if collector.timing_enabled() and performance_gating else []
	var command_count: int = _scripted_command_count_from_log(command_log)
	var command_log_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(command_log)
	var accepted_command_evidence: Array = _flatten_command_log(command_log)
	var requested_seed: int = int(scenario_def.get("seed", 0))
	var effective_seed: int = int(setup.get("effective_seed", 0))
	var final_state_hash: String = str(OpsState.call("get_contract_state_hash")) if OpsState.has_method("get_contract_state_hash") else ""
	var renderer_configuration_state: Dictionary = _renderer_configuration_state(arena)
	var renderer_configuration_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(renderer_configuration_state)
	var phase2_stress_evidence: Dictionary = _phase2_stress_finalize(phase2_stress_tracker, phase2_render_peaks, state, sim_runner, arena, scenario_def) if not phase2_stress_tracker.is_empty() else {}
	var phase2_battlefield_evidence: Dictionary = _phase2_battlefield_finalize(phase2_battlefield_tracker, phase2_battlefield_render_peaks, state, scenario_def) if not phase2_battlefield_tracker.is_empty() else {}
	var integrity_failures: Array = []
	if not bool(bot_isolation.get("pass", false)):
		integrity_failures.append("bots_not_disabled")
	if requested_seed != effective_seed:
		integrity_failures.append("effective_seed_mismatch")
	if not bool(camera_settle.get("pass", false)):
		integrity_failures.append("camera_settle_failed")
	if camera_identity_hash.is_empty():
		integrity_failures.append("camera_hash_missing")
	if tick_index != adapter.total_ticks():
		integrity_failures.append("tick_count_mismatch")
	if measured_frame_count != adapter.measurement_frames:
		integrity_failures.append("measurement_frame_count_mismatch")
	if final_state_hash.is_empty():
		integrity_failures.append("final_state_hash_missing")
	if not phase2_stress_evidence.is_empty() and not bool(phase2_stress_evidence.get("pass", false)):
		for failure_any in phase2_stress_evidence.get("failures", []) as Array:
			integrity_failures.append("phase2_stress:%s" % str(failure_any))
	if not phase2_battlefield_evidence.is_empty() and not bool(phase2_battlefield_evidence.get("pass", false)):
		for failure_any in phase2_battlefield_evidence.get("failures", []) as Array:
			integrity_failures.append("phase2_battlefield:%s" % str(failure_any))
	var final_unit_count: int = _runtime_unit_count(state)
	var unit_motion_end: Array = _unit_motion_snapshot(state) if target_units > 0 else []
	var unit_motion_evidence: Dictionary = _unit_motion_evidence(unit_motion_start, unit_motion_end) if target_units > 0 else {}
	if target_units > 0:
		match unit_count_policy:
			"exact_static":
				if unit_count_min != target_units or unit_count_max != target_units or final_unit_count != target_units:
					integrity_failures.append("unit_count_measurement_invariant_failed")
			"bounded_moving":
				if int(unit_scale_setup.get("actual_units", 0)) != target_units or unit_count_min < 0 or unit_count_max > target_units or final_unit_count > target_units:
					integrity_failures.append("moving_unit_count_bounds_failed")
				if unit_count_timeline.size() != adapter.total_ticks():
					integrity_failures.append("moving_unit_timeline_incomplete")
				if int(unit_motion_evidence.get("changed_or_arrived", 0)) <= 0:
					integrity_failures.append("moving_unit_progress_not_observed")
			_:
				integrity_failures.append("unit_count_policy_unsupported")
	var renderer_pool_end: Dictionary = _unit_renderer_pool_snapshot(arena)
	var renderer_pool_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(_stable_pool_identity(renderer_pool_end)) if target_units > 0 else ""
	if target_units > 0 and int(renderer_pool_end.get("pool_expansions", -1)) != int((unit_scale_setup.get("renderer_pool_before", {}) as Dictionary).get("pool_expansions", -2)):
		integrity_failures.append("unexpected_renderer_pool_expansion")
	if target_units > 0 and int(renderer_pool_end.get("pool_misses", -1)) != int((unit_scale_setup.get("renderer_pool_before", {}) as Dictionary).get("pool_misses", -2)):
		integrity_failures.append("unexpected_renderer_pool_miss")
	var active_pool_count: int = int(renderer_pool_end.get("active_pooled_objects", -1))
	if target_units > 0:
		if unit_count_policy == "exact_static" and active_pool_count != target_units:
			integrity_failures.append("renderer_active_count_mismatch")
		elif unit_count_policy == "bounded_moving" and (active_pool_count < final_unit_count or active_pool_count > target_units):
			integrity_failures.append("moving_renderer_active_count_out_of_bounds")
	if command_count < int(scenario_def.get("expected_command_count_min", 0)):
		integrity_failures.append("scheduled_command_count_below_minimum")
	if scenario_def.has("expected_command_count_exact") and command_count != int(scenario_def.get("expected_command_count_exact", -1)):
		integrity_failures.append("scheduled_command_count_not_exact")
	if not str(scenario_def.get("expected_command_log_hash", "")).is_empty() and command_log_hash != str(scenario_def.get("expected_command_log_hash", "")):
		integrity_failures.append("accepted_command_hash_mismatch")
	if scenario_def.has("expected_accepted_commands") and PERF_DETERMINISTIC_HASH.hash_variant(accepted_command_evidence) != PERF_DETERMINISTIC_HASH.hash_variant(scenario_def.get("expected_accepted_commands", [])):
		integrity_failures.append("accepted_command_evidence_mismatch")
	var observed_command_types: Array[String] = _command_types_from_log(command_log)
	for expected_type_any in scenario_def.get("expected_command_types", []) as Array:
		var expected_type: String = str(expected_type_any)
		if not observed_command_types.has(expected_type):
			integrity_failures.append("scheduled_command_type_missing:%s" % expected_type)
	if OpsState.match_phase != OpsState.MatchPhase.RUNNING or bool(OpsState.match_over):
		integrity_failures.append("fixture_ended_match")
	var report := _base_scenario_report(scenario_def, benchmark_mode, gates)
	report.merge({
		"canonical_simulation": adapter.simulation_active,
		"baseline_eligible": false,
		"baseline_ineligible_reasons": [str(scenario_def.get("baseline_ineligible_reason", "phase1_fixture_not_baseline_approved" if bool(scenario_def.get("catalog_fixture_registered", false)) else "phase1_gate_b_internal_probe"))],
		"duration_sec": float(adapter.total_frames()) / float(adapter.target_fps),
		"target_duration_sec": float(adapter.total_frames()) / float(adapter.target_fps),
		"warmup_duration_sec": float(adapter.warmup_frames) / float(adapter.target_fps),
		"measurement_duration_sec": float(adapter.measurement_frames) / float(adapter.target_fps),
		"observed_warmup_duration_sec": observed_warmup_duration_ms / 1000.0,
		"observed_measurement_duration_sec": observed_measurement_duration_ms / 1000.0,
		"sim_tick_interval_sec": SIM_TICK_INTERVAL_SEC,
		"setup_duration_ms": setup_ms,
		"frame_count": adapter.total_frames(),
		"warmup_frame_count": adapter.warmup_frames,
		"measured_frame_count": measured_frame_count,
		"tick_count": tick_index,
		"warmup_tick_count": adapter.warmup_ticks(),
		"measured_tick_count": adapter.measurement_ticks(),
		"collection": collection,
		"scripted_command_count": command_count,
		"scripted_command_ticks": command_log,
		"command_schedule_hash": command_log_hash,
		"accepted_command_evidence": accepted_command_evidence,
		"observed_command_types": observed_command_types,
		"effective_seed": effective_seed,
		"final_state_hash": final_state_hash,
		"camera_settle": camera_settle,
		"camera_identity": camera_identity,
		"camera_identity_hash": camera_identity_hash,
		"cadence_identity": cadence_identity,
		"cadence_identity_hash": cadence_identity_hash,
		"renderer_configuration_state": renderer_configuration_state,
		"renderer_configuration_hash": renderer_configuration_hash,
		"phase2_stress_profile": phase2_stress_profile,
		"phase2_stress_evidence": phase2_stress_evidence,
		"phase2_event_hash": str(phase2_stress_evidence.get("event_hash", "")),
		"phase2_render_lifecycle_hash": str(phase2_stress_evidence.get("render_lifecycle_hash", "")),
		"phase2_battlefield_profile": phase2_battlefield_profile,
		"phase2_battlefield_evidence": phase2_battlefield_evidence,
		"phase2_battlefield_event_hash": str(phase2_battlefield_evidence.get("event_hash", "")),
		"phase2_battlefield_render_hash": str(phase2_battlefield_evidence.get("render_hash", "")),
		"phase2_lifecycle_profile": lifecycle_profile,
		"lifecycle_runtime_before": lifecycle_runtime_before,
		"lifecycle_runtime_during": _runtime_counter_snapshot() if not lifecycle_profile.is_empty() else {},
		"lifecycle_required_cycles": int(scenario_def.get("lifecycle_required_cycles", 0)),
		"lifecycle_limits": (scenario_def.get("lifecycle_limits", {}) as Dictionary).duplicate(true),
		"render_monitor_peaks": render_monitor_peaks,
		"runtime_counts": (setup.get("actual_counts", {}) as Dictionary).duplicate(true),
		"fixture_setup_evidence": {
			"content_kind": str(setup.get("content_kind", "")),
			"map_loader_used": bool(setup.get("map_loader_used", false)),
			"map_applier_used": bool(setup.get("map_applier_used", false)),
			"expected_counts": (setup.get("expected_counts", {}) as Dictionary).duplicate(true),
			"actual_counts": (setup.get("actual_counts", {}) as Dictionary).duplicate(true),
			"exact_counts": bool(setup.get("counts_exact", false))
		},
		"bot_isolation": bot_isolation,
		"unit_scale_setup": unit_scale_setup,
		"target_units": target_units,
		"unit_count_policy": unit_count_policy,
		"expected_pool_capacity": int(scenario_def.get("expected_pool_capacity", 0)),
		"expected_pool_expansions": int(scenario_def.get("expected_pool_expansions", -1)),
		"unit_count_window": {
			"target": target_units,
			"start": int(unit_scale_setup.get("actual_units", 0)) if target_units > 0 else 0,
			"minimum": unit_count_min,
			"maximum": unit_count_max,
			"end": final_unit_count,
			"invariant": target_units <= 0 or (unit_count_min == target_units and unit_count_max == target_units and final_unit_count == target_units) if unit_count_policy == "exact_static" else (int(unit_scale_setup.get("actual_units", 0)) == target_units and unit_count_min >= 0 and unit_count_max <= target_units and final_unit_count <= target_units)
		},
		"unit_count_timeline": unit_count_timeline,
		"unit_count_timeline_hash": PERF_DETERMINISTIC_HASH.hash_variant(unit_count_timeline) if target_units > 0 else "",
		"unit_motion_evidence": unit_motion_evidence,
		"unit_motion_hash": PERF_DETERMINISTIC_HASH.hash_variant(unit_motion_evidence) if target_units > 0 else "",
		"unit_injection_hash": str(unit_scale_setup.get("injection_hash", "")),
		"lane_setup_hash": str(unit_scale_setup.get("lane_setup_hash", "")),
		"renderer_pool_telemetry": renderer_pool_end,
		"renderer_sim_count_delta": active_pool_count - final_unit_count if target_units > 0 else 0,
		"renderer_pool_hash": renderer_pool_hash,
		"match": _match_summary(state, tick_index),
		"average_frame_ms": collection.get("average_ms"),
		"median_frame_ms": collection.get("median_ms"),
		"p95_frame_ms": collection.get("p95_ms"),
		"p99_frame_ms": collection.get("p99_ms"),
		"p999_frame_ms": collection.get("p999_ms"),
		"max_frame_ms": collection.get("max_ms"),
		"hitch_threshold_ms": float(gates.get("hitch_threshold_ms", gates.get("p99_max_ms", 0.0))),
		"hitch_count": collection.get("hitch_count"),
		"hitches": _collector_hitch_records(collection.get("hitch_records", []) as Array),
		"worst_frames": _frame_worst_records(collection.get("worst_records", []) as Array),
		"worst_sim_ticks": [],
		"performance_status": "NOT_COLLECTED" if not collector.timing_enabled() else "GATED_WINDOWED" if performance_gating else "NOT_GATED_GATE_PROBE",
		"performance_gating": performance_gating,
		"performance_gate_disposition": str(scenario_def.get("performance_gate_disposition", "GATED" if performance_gating else "DIAGNOSTIC_ONLY")),
		"pass": integrity_failures.is_empty() and failed_gates.is_empty(),
		"integrity_failures": integrity_failures,
		"failed_gates": failed_gates
	}, true)
	return await _finalize_scenario(report, isolation_snapshot, scene_root, arena)

func _run_render_scenario(scenario_def: Dictionary, benchmark_mode: String, gates: Dictionary) -> Dictionary:
	var isolation_snapshot: Dictionary = PERF_ISOLATION_GUARD.capture(self, OpsState)
	_arm_interrupted_cleanup(isolation_snapshot)
	var setup: Dictionary = await _setup_arena_for_scenario(scenario_def, true)
	if not bool(setup.get("ok", false)):
		return await _finalize_scenario(
			_scenario_error(scenario_def, benchmark_mode, str(setup.get("reason", "setup_failed")), gates),
			isolation_snapshot,
			setup.get("scene_root", null) as Node,
			setup.get("arena", null) as Node
		)
	var scene_root: Node = setup.get("scene_root", null) as Node
	var arena: Node = setup.get("arena", null) as Node
	_update_interrupted_cleanup_nodes(scene_root, arena)
	var state: GameState = OpsState.require_state()
	_prepare_match_for_benchmark()
	var initial_commands: Array = _apply_scenario_initial_state(arena, state, scenario_def)
	_apply_render_isolation(arena, scenario_def)
	if arena.has_method("start_sim"):
		arena.call("start_sim")
	var discard_initial_frames: int = max(0, int(scenario_def.get("render_discard_initial_frames", RENDER_DISCARD_INITIAL_FRAMES)))
	var duration_sec := float(scenario_def.get("duration_sec", 1.0))
	var max_frames: int = int(ceil(duration_sec * 90.0)) + discard_initial_frames
	var collection_level: String = str(scenario_def.get("_collection_level", PERF_RESULT_CONTRACT.COLLECTION_LEVEL_MINIMAL))
	var collector := PERF_METRICS_COLLECTOR.new(
		collection_level,
		int(gates.get("worst_frame_limit", 10)),
		float(gates.get("target_frame_ms", INF)),
		-1,
		-1,
		0
	)
	var command_log: Array = []
	if not initial_commands.is_empty():
		command_log.append({"tick": 0, "commands": initial_commands})
	var discarded_duration_ms: float = 0.0
	var observed_measurement_duration_ms: float = 0.0
	var measured_frame_count: int = 0
	var started_usec := Time.get_ticks_usec()
	var last_usec := started_usec
	var tick_index := 0
	var last_command_tick: int = 0
	for frame_index in range(max_frames):
		await process_frame
		var now_usec := Time.get_ticks_usec()
		var elapsed_sec := float(now_usec - started_usec) / 1000000.0
		var frame_ms := float(now_usec - last_usec) / 1000.0
		last_usec = now_usec
		tick_index = int(round(elapsed_sec / SIM_TICK_INTERVAL_SEC))
		if frame_index >= discard_initial_frames:
			measured_frame_count += 1
			if tick_index > last_command_tick:
				for command_tick in range(last_command_tick + 1, tick_index + 1):
					var issued: Array = _issue_commands_for_tick(arena, state, scenario_def, command_tick)
					if not issued.is_empty():
						command_log.append({"tick": command_tick, "commands": issued})
				last_command_tick = tick_index
			if collector.timing_enabled():
				observed_measurement_duration_ms += frame_ms
				var frame_context: Dictionary = {}
				if collector.needs_forensic_context(frame_ms):
					frame_context = {
						"tick": tick_index,
						"phase": "render",
						"classification": _classification_for_frame(frame_ms, gates, {}),
						"renderer_configuration_state": _renderer_configuration_state(arena)
					}
				collector.observe(measured_frame_count, frame_ms, frame_context)
		else:
			discarded_duration_ms += frame_ms
		if elapsed_sec >= duration_sec:
			break
	var collection: Dictionary = collector.summary()
	var metrics: Dictionary = _collector_frame_metrics(collection)
	var failed_gates: Array = _failed_gates(metrics, int(collection.get("hitch_count", 0)), gates) if collector.timing_enabled() else []
	var report := _base_scenario_report(scenario_def, benchmark_mode, gates)
	report.merge({
		"canonical_simulation": false,
		"baseline_eligible": false,
		"baseline_ineligible_reasons": ["phase0_render_fixture_not_approved"],
		"duration_sec": duration_sec,
		"target_duration_sec": duration_sec,
		"warmup_duration_sec": float(discard_initial_frames) * FRAME_DELTA_SEC,
		"measurement_duration_sec": duration_sec,
		"observed_warmup_duration_sec": discarded_duration_ms / 1000.0 if collector.timing_enabled() else null,
		"observed_measurement_duration_sec": observed_measurement_duration_ms / 1000.0 if collector.timing_enabled() else null,
		"frame_delta_sec": 0.0,
		"sim_tick_interval_sec": SIM_TICK_INTERVAL_SEC,
		"frame_count": measured_frame_count + discard_initial_frames,
		"measured_frame_count": measured_frame_count,
		"discarded_initial_frames": discard_initial_frames,
		"render_loop_control_clock_reads_per_frame": 1,
		"collection": collection,
		"scripted_command_count": _scripted_command_count_from_log(command_log),
		"scripted_command_ticks": command_log,
		"command_schedule_hash": PERF_DETERMINISTIC_HASH.hash_variant(command_log),
		"renderer_configuration_state": _renderer_configuration_state(arena),
		"match": _match_summary(state, tick_index),
		"average_frame_ms": collection.get("average_ms"),
		"median_frame_ms": collection.get("median_ms"),
		"p95_frame_ms": collection.get("p95_ms"),
		"p99_frame_ms": collection.get("p99_ms"),
		"p999_frame_ms": collection.get("p999_ms"),
		"max_frame_ms": collection.get("max_ms"),
		"hitch_threshold_ms": float(gates.get("target_frame_ms", 0.0)),
		"hitch_count": collection.get("hitch_count"),
		"hitches": _collector_hitch_records(collection.get("hitch_records", []) as Array),
		"worst_frames": _frame_worst_records(collection.get("worst_records", []) as Array),
		"worst_sim_ticks": [],
		"performance_status": "NOT_COLLECTED" if not collector.timing_enabled() else "GATED_WINDOWED",
		"pass": failed_gates.is_empty(),
		"failed_gates": failed_gates
	}, true)
	return await _finalize_scenario(report, isolation_snapshot, scene_root, arena)

func _setup_arena_for_scenario(scenario_def: Dictionary, real_scene: bool) -> Dictionary:
	var scene_path := MAIN_SCENE_PATH if real_scene else ARENA_SCENE_PATH
	var scene_res: Resource = load(scene_path)
	if scene_res == null or not (scene_res is PackedScene):
		return {"ok": false, "reason": "scene_load_failed", "scene_path": scene_path}
	var scene_root: Node = (scene_res as PackedScene).instantiate()
	if scene_root == null:
		return {"ok": false, "reason": "scene_instantiate_failed", "scene_path": scene_path}
	if real_scene:
		if "start_in_menu" in scene_root:
			scene_root.set("start_in_menu", false)
		if "enable_dev_map_loader" in scene_root:
			scene_root.set("enable_dev_map_loader", false)
		if "show_dev_map_loader_in_game" in scene_root:
			scene_root.set("show_dev_map_loader_in_game", false)
	root.add_child(scene_root)
	await process_frame
	await process_frame
	var arena: Node = _find_arena(scene_root)
	if arena == null:
		_teardown_node(scene_root)
		return {"ok": false, "reason": "arena_missing", "scene_path": scene_path}
	_apply_project_switches(arena, scenario_def)
	var content_kind: String = str(scenario_def.get("content_kind", "production_map"))
	var map_path := str(scenario_def.get("map_path", MAP_QUICK))
	var map_loader_used: bool = content_kind == "production_map"
	var map_applier_used: bool = content_kind == "production_map"
	if content_kind == "synthetic_scene":
		var synthetic_descriptor: Dictionary = scenario_def.get("synthetic_descriptor", {}) as Dictionary
		if synthetic_descriptor.is_empty():
			_teardown_node(scene_root)
			return {"ok": false, "reason": "synthetic_descriptor_missing", "map_path": ""}
		OpsState.call("reset_state_from_map", synthetic_descriptor.duplicate(true))
		if "current_map_data" in arena:
			arena.set("current_map_data", {})
		if arena.has_method("clear_map_render"):
			arena.call("clear_map_render")
		for _frame in range(3):
			await process_frame
	else:
		var map_data: Dictionary = scenario_def.get("_preflight_map_data", {}) as Dictionary
		if map_data.is_empty():
			_teardown_node(scene_root)
			return {"ok": false, "reason": "fixture_preflight_data_missing", "map_path": map_path}
		MAP_APPLIER.apply_map(arena as Node2D, map_data)
		await process_frame
		await process_frame
	var state: GameState = OpsState.require_state()
	var expected_counts: Dictionary = scenario_def.get("_preflight_runtime_counts", {}) as Dictionary
	var actual_counts: Dictionary = PERF_FIXTURE_VALIDATOR.runtime_counts(state, arena)
	var post_apply: Dictionary = PERF_FIXTURE_VALIDATOR.validate_post_apply(expected_counts, actual_counts)
	if not bool(post_apply.get("ok", false)):
		_teardown_node(scene_root)
		return {
			"ok": false,
			"reason": "post_apply_validation_failed:%s" % str(post_apply.get("errors", [])),
			"map_path": map_path,
			"expected_counts": expected_counts.duplicate(true),
			"actual_counts": actual_counts.duplicate(true)
		}
	if not arena.has_method("set_perf_match_seed_override") or not bool(arena.call("set_perf_match_seed_override", int(scenario_def.get("seed", 0)))):
		_teardown_node(scene_root)
		return {"ok": false, "reason": "perf_seed_override_refused", "map_path": map_path}
	var effective_seed: int = int(arena.call("get_effective_match_seed")) if arena.has_method("get_effective_match_seed") else 0
	if effective_seed != int(scenario_def.get("seed", 0)):
		_teardown_node(scene_root)
		return {
			"ok": false,
			"reason": "effective_seed_mismatch",
			"requested_seed": int(scenario_def.get("seed", 0)),
			"effective_seed": effective_seed
		}
	var sim_runner: Node = _arena_sim_runner(arena)
	if sim_runner != null and sim_runner.has_method("bind_state"):
		sim_runner.call("bind_state", OpsState.require_state())
		await process_frame
		await process_frame
	if content_kind == "synthetic_scene":
		if arena.has_method("mark_render_dirty"):
			arena.call("mark_render_dirty", "perf_synthetic_fixture_publish")
		if arena.has_method("_push_render_model"):
			arena.call("_push_render_model")
		await process_frame
		await process_frame
	return {
		"ok": true,
		"scene_root": scene_root,
		"arena": arena,
		"map_path": map_path,
		"effective_seed": effective_seed,
		"content_kind": content_kind,
		"map_loader_used": map_loader_used,
		"map_applier_used": map_applier_used,
		"expected_counts": expected_counts.duplicate(true),
		"actual_counts": actual_counts.duplicate(true),
		"counts_exact": bool(post_apply.get("ok", false))
	}

func _prepare_match_for_benchmark() -> void:
	OpsState.sim_mutate("PerfBenchmark.prepare_match", func() -> void:
		OpsState.match_phase = OpsState.MatchPhase.RUNNING
		OpsState.input_locked = false
		OpsState.input_locked_reason = ""
		OpsState.match_clock_started = false
		OpsState.match_clock_running = false
		OpsState.match_clock_paused = false
		OpsState.match_over = false
		OpsState.winner_id = 0
		OpsState.outcome = GameState.GameOutcome.NONE
	)

func _apply_project_switches(arena: Node, scenario_def: Dictionary) -> void:
	var switches: Dictionary = scenario_def.get("runtime_switches", {}) as Dictionary
	if switches.has("arena_polish_comparison_mode"):
		ARENA_POLISH_LAYER.apply_comparison_mode(str(switches.get("arena_polish_comparison_mode", "settings")))
	if switches.has("premium_polish_enabled"):
		ProjectSettings.set_setting("swarmfront/arena/premium_polish_enabled", bool(switches.get("premium_polish_enabled", false)))
	if switches.has("tower_visual_scale"):
		ProjectSettings.set_setting("swarmfront/arena/tower_visual_scale", float(switches.get("tower_visual_scale", 1.0)))
	var polish_layer: Node = arena.get_node_or_null("MapRoot/ArenaPolishLayer") if arena != null else null
	if polish_layer != null and polish_layer.has_method("apply_runtime_settings"):
		polish_layer.call("apply_runtime_settings")

func _apply_scenario_initial_state(arena: Node, state: GameState, scenario_def: Dictionary) -> Array:
	var commands: Array = []
	var initial_lanes: int = max(0, int(scenario_def.get("initial_lanes", 4)))
	var issued := 0
	var candidate_pairs: Array = _candidate_attack_pairs(state)
	for pair_any in candidate_pairs:
		if issued >= initial_lanes:
			break
		var pair: Dictionary = pair_any as Dictionary
		var intent := "feed" if bool(pair.get("friendly", false)) else "attack"
		var result: Dictionary = OpsState.apply_lane_intent(int(pair.get("src", -1)), int(pair.get("dst", -1)), intent)
		if bool(result.get("ok", false)):
			issued += 1
			commands.append({"type": intent, "src": int(pair.get("src", -1)), "dst": int(pair.get("dst", -1)), "setup": true})
	var swarm_count: int = max(0, int(scenario_def.get("initial_swarms", 0)))
	for i in range(swarm_count):
		var swarm_report: Dictionary = _issue_swarm_on_active_lane(state, i)
		if bool(swarm_report.get("ok", false)):
			swarm_report["setup"] = true
			commands.append(swarm_report)
	var route_count: int = max(0, int(scenario_def.get("initial_barracks_routes", 0)))
	if route_count > 0:
		_seed_barracks_routes(state, route_count)
	if arena != null and arena.has_method("mark_render_dirty"):
		arena.call("mark_render_dirty", "perf_benchmark_setup")
	return commands

func _disable_bots_for_benchmark() -> void:
	if OpsState.has_method("ensure_bot_profiles_from_roster"):
		OpsState.call("ensure_bot_profiles_from_roster")
	if not OpsState.has_method("get_bot_profiles_snapshot") or not OpsState.has_method("set_bot_profile"):
		return
	var profiles: Dictionary = OpsState.call("get_bot_profiles_snapshot") as Dictionary
	for seat_any in profiles.keys():
		OpsState.call("set_bot_profile", int(seat_any), {"enabled": false})

func _bot_isolation_evidence() -> Dictionary:
	if not OpsState.has_method("get_bot_profiles_snapshot"):
		return {"pass": false, "reason": "bot_profile_snapshot_unavailable", "profiles": {}}
	var profiles: Dictionary = OpsState.call("get_bot_profiles_snapshot") as Dictionary
	var enabled_seats: Array[int] = []
	for seat_any in profiles.keys():
		var profile_any: Variant = profiles.get(seat_any)
		if typeof(profile_any) == TYPE_DICTIONARY and bool((profile_any as Dictionary).get("enabled", false)):
			enabled_seats.append(int(seat_any))
	enabled_seats.sort()
	return {
		"pass": enabled_seats.is_empty(),
		"enabled_seats": enabled_seats,
		"profile_count": profiles.size(),
		"profiles_hash": PERF_DETERMINISTIC_HASH.hash_variant(profiles)
	}

func _prepare_unit_scale_fixture(arena: Node, sim_runner: Node, state: GameState, scenario_def: Dictionary) -> Dictionary:
	var target_units: int = int(scenario_def.get("target_units", 0))
	var expected_pool_capacity: int = int(scenario_def.get("expected_pool_capacity", 0))
	if target_units <= 0 or expected_pool_capacity <= 0 or target_units > expected_pool_capacity:
		return {"pass": false, "reason": "target_units_out_of_approved_range"}
	if bool(scenario_def.get("capacity_bypass_allowed", true)):
		return {"pass": false, "reason": "capacity_bypass_policy_not_locked"}
	var expected_lanes: int = int(scenario_def.get("initial_lanes", 0))
	if expected_lanes <= 0:
		return {"pass": false, "reason": "accepted_lane_setup_missing"}
	var lane_wait: Dictionary = await _wait_for_built_lanes(state, sim_runner, expected_lanes, int(scenario_def.get("lane_build_timeout_ms", 3000)))
	if not bool(lane_wait.get("pass", false)):
		return lane_wait
	if _runtime_unit_count(state) != 0:
		return {"pass": false, "reason": "unit_scale_setup_not_empty_before_injection"}
	var unit_system: Object = sim_runner.get("unit_system") if sim_runner != null else null
	if unit_system == null or not unit_system.has_method("spawn_unit"):
		return {"pass": false, "reason": "public_unit_spawn_unavailable"}
	var lanes: Array = state.lanes.duplicate()
	lanes.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as LaneData).id) < int((b as LaneData).id)
	)
	var lane_rows: Array = []
	var spawn_directions: Array = []
	for lane_any in lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		var source_id: int = int(lane.a_id) if bool(lane.send_a) else int(lane.b_id) if bool(lane.send_b) else -1
		var destination_id: int = int(lane.b_id) if source_id == int(lane.a_id) else int(lane.a_id)
		var source_hive: HiveData = state.find_hive_by_id(source_id)
		if source_id <= 0 or destination_id <= 0 or source_hive == null or int(source_hive.owner_id) <= 0:
			continue
		var direction: int = 1 if source_id == int(lane.a_id) else -1
		lane_rows.append({
			"lane_id": int(lane.id),
			"generation": int(lane.generation),
			"from_id": source_id,
			"to_id": destination_id,
			"owner_id": int(source_hive.owner_id),
			"direction": direction,
			"build_t": snappedf(float(lane.build_t), 0.001),
			"built": lane.is_built()
		})
		spawn_directions.append({"lane": lane, "from": source_id, "to": destination_id, "owner": int(source_hive.owner_id), "dir": direction})
	if spawn_directions.is_empty():
		return {"pass": false, "reason": "no_built_outgoing_lane"}
	var renderer_pool_before: Dictionary = _unit_renderer_pool_snapshot(arena)
	if int(renderer_pool_before.get("total_pooled_objects", 0)) != expected_pool_capacity:
		return {"pass": false, "reason": "renderer_pool_not_prewarmed", "renderer_pool_before": renderer_pool_before}
	if int(renderer_pool_before.get("pool_expansions", -1)) != int(scenario_def.get("expected_pool_expansions", -2)):
		return {"pass": false, "reason": "renderer_pool_expansion_baseline_invalid", "renderer_pool_before": renderer_pool_before}
	if int(renderer_pool_before.get("pool_misses", -1)) != 0:
		return {"pass": false, "reason": "renderer_pool_miss_baseline_invalid", "renderer_pool_before": renderer_pool_before}
	var injection_records: Array = []
	for unit_index in range(target_units):
		var direction_row: Dictionary = spawn_directions[unit_index % spawn_directions.size()] as Dictionary
		var lane: LaneData = direction_row.get("lane") as LaneData
		var progress: float = 0.1 + 0.8 * (float((unit_index * 37) % 997) / 996.0)
		var direction: int = int(direction_row.get("dir", 1))
		var lane_t: float = progress if direction > 0 else 1.0 - progress
		var unit: Dictionary = {
			"id": unit_index + 1,
			"owner_id": int(direction_row.get("owner", 0)),
			"amount": 1,
			"lane_id": int(lane.id),
			"lane_generation": int(lane.generation),
			"a_id": int(lane.a_id),
			"b_id": int(lane.b_id),
			"lane_key": state.lane_key(int(lane.a_id), int(lane.b_id)),
			"from_id": int(direction_row.get("from", -1)),
			"to_id": int(direction_row.get("to", -1)),
			"dir": direction,
			"t": lane_t,
			"arrive_source": "lane"
		}
		if not bool(unit_system.call("spawn_unit", unit, false)):
			return {
				"pass": false,
				"reason": "public_unit_spawn_rejected_at_%d" % unit_index,
				"accepted_units": _runtime_unit_count(state),
				"capacity_bypass_used": false
			}
		injection_records.append({
			"id": int(unit.get("id", 0)),
			"lane_id": int(unit.get("lane_id", -1)),
			"lane_generation": int(unit.get("lane_generation", 0)),
			"from_id": int(unit.get("from_id", -1)),
			"to_id": int(unit.get("to_id", -1)),
			"owner_id": int(unit.get("owner_id", 0)),
			"dir": int(unit.get("dir", 0)),
			"t": snappedf(float(unit.get("t", 0.0)), 0.000001)
		})
	if arena.has_method("mark_render_dirty"):
		arena.call("mark_render_dirty", "perf_unit_scale_injection")
	# With SimRunner paused there is no sim-tick signal to publish the dirty
	# production render model, so the harness explicitly performs that publish.
	if arena.has_method("_push_render_model"):
		arena.call("_push_render_model")
	var renderer_wait: Dictionary = await _wait_for_renderer_unit_count(arena, target_units, int(scenario_def.get("renderer_ready_timeout_ms", 3000)))
	if not bool(renderer_wait.get("pass", false)):
		return renderer_wait
	var actual_units: int = _runtime_unit_count(state)
	var renderer_pool_after_injection: Dictionary = _unit_renderer_pool_snapshot(arena)
	return {
		"pass": actual_units == target_units and int(renderer_pool_after_injection.get("active_pooled_objects", -1)) == target_units,
		"reason": "" if actual_units == target_units and int(renderer_pool_after_injection.get("active_pooled_objects", -1)) == target_units else "injected_unit_count_mismatch",
		"target_units": target_units,
		"actual_units": actual_units,
		"public_spawn_api": "UnitSystem.spawn_unit",
		"capacity_bypass_used": false,
		"lane_wait": lane_wait,
		"renderer_wait": renderer_wait,
		"lane_rows": lane_rows,
		"lane_setup_hash": PERF_DETERMINISTIC_HASH.hash_variant(lane_rows),
		"injection_hash": PERF_DETERMINISTIC_HASH.hash_variant(injection_records),
		"injection_record_count": injection_records.size(),
		"renderer_pool_before": renderer_pool_before,
		"renderer_pool_after_injection": renderer_pool_after_injection
	}

func _wait_for_built_lanes(state: GameState, sim_runner: Node, expected_lanes: int, timeout_ms: int) -> Dictionary:
	var started_ms: int = Time.get_ticks_msec()
	var observed_frames: int = 0
	var lane_system: Object = sim_runner.get("lane_system") if sim_runner != null else null
	if lane_system == null or not lane_system.has_method("tick_lane_fronts"):
		return {"pass": false, "reason": "production_lane_system_unavailable"}
	while Time.get_ticks_msec() - started_ms <= timeout_ms:
		# Advance only the production lane-build subsystem during setup. Full simulation
		# remains paused, so no incidental units can contaminate the static fixture.
		lane_system.call("tick_lane_fronts", SIM_TICK_INTERVAL_SEC)
		var built_count: int = 0
		for lane_any in state.lanes:
			if lane_any is LaneData and (lane_any as LaneData).is_built() and not bool((lane_any as LaneData).establish_a) and not bool((lane_any as LaneData).establish_b):
				built_count += 1
		if state.lanes.size() == expected_lanes and built_count == expected_lanes:
			return {
				"pass": true,
				"reason": "",
				"expected_lanes": expected_lanes,
				"actual_lanes": state.lanes.size(),
				"built_lanes": built_count,
				"condition_wait_frames": observed_frames,
				"timeout_ms": timeout_ms,
				"fixed_sleep_used": false
			}
		observed_frames += 1
		await process_frame
	return {
		"pass": false,
		"reason": "lane_build_condition_timeout",
		"expected_lanes": expected_lanes,
		"actual_lanes": state.lanes.size(),
		"condition_wait_frames": observed_frames,
		"timeout_ms": timeout_ms,
		"fixed_sleep_used": false
	}

func _wait_for_renderer_unit_count(arena: Node, target_units: int, timeout_ms: int) -> Dictionary:
	var started_ms: int = Time.get_ticks_msec()
	var observed_frames: int = 0
	while Time.get_ticks_msec() - started_ms <= timeout_ms:
		var snapshot: Dictionary = _unit_renderer_pool_snapshot(arena)
		if int(snapshot.get("active_pooled_objects", -1)) == target_units:
			return {
				"pass": true,
				"reason": "",
				"target_units": target_units,
				"active_pooled_objects": target_units,
				"condition_wait_frames": observed_frames,
				"timeout_ms": timeout_ms,
				"fixed_sleep_used": false
			}
		observed_frames += 1
		await process_frame
	return {
		"pass": false,
		"reason": "renderer_unit_count_condition_timeout",
		"target_units": target_units,
		"renderer_pool": _unit_renderer_pool_snapshot(arena),
		"condition_wait_frames": observed_frames,
		"timeout_ms": timeout_ms,
		"fixed_sleep_used": false
	}

func _runtime_unit_count(state: GameState) -> int:
	if state == null:
		return -1
	return (state.units_by_lane.get("_all", []) as Array).size()

func _unit_motion_snapshot(state: GameState) -> Array:
	var out: Array = []
	if state == null:
		return out
	for unit_any in state.units_by_lane.get("_all", []) as Array:
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_any as Dictionary
		out.append({
			"id": int(unit.get("id", -1)),
			"owner_id": int(unit.get("owner_id", 0)),
			"lane_id": int(unit.get("lane_id", -1)),
			"lane_generation": int(unit.get("lane_generation", 0)),
			"from_id": int(unit.get("from_id", -1)),
			"to_id": int(unit.get("to_id", -1)),
			"dir": int(unit.get("dir", 0)),
			"t": snappedf(float(unit.get("t", 0.0)), 0.000001)
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("id", -1)) < int(b.get("id", -1))
	)
	return out

func _unit_motion_evidence(start_snapshot: Array, end_snapshot: Array) -> Dictionary:
	var end_by_id: Dictionary = {}
	for row_any in end_snapshot:
		if typeof(row_any) == TYPE_DICTIONARY:
			var row: Dictionary = row_any as Dictionary
			end_by_id[int(row.get("id", -1))] = row
	var changed_or_arrived: int = 0
	var retained_changed: int = 0
	var arrived_or_removed: int = 0
	for start_any in start_snapshot:
		if typeof(start_any) != TYPE_DICTIONARY:
			continue
		var start_row: Dictionary = start_any as Dictionary
		var unit_id: int = int(start_row.get("id", -1))
		if not end_by_id.has(unit_id):
			changed_or_arrived += 1
			arrived_or_removed += 1
			continue
		var end_row: Dictionary = end_by_id.get(unit_id, {}) as Dictionary
		if PERF_DETERMINISTIC_HASH.hash_variant(start_row) != PERF_DETERMINISTIC_HASH.hash_variant(end_row):
			changed_or_arrived += 1
			retained_changed += 1
	return {
		"start_count": start_snapshot.size(),
		"end_count": end_snapshot.size(),
		"changed_or_arrived": changed_or_arrived,
		"retained_changed": retained_changed,
		"arrived_or_removed": arrived_or_removed,
		"start_hash": PERF_DETERMINISTIC_HASH.hash_variant(start_snapshot),
		"end_hash": PERF_DETERMINISTIC_HASH.hash_variant(end_snapshot)
	}

func _phase2_stress_tracker_start(state: GameState, scenario_def: Dictionary) -> Dictionary:
	return {
		"profile": str(scenario_def.get("phase2_stress_profile", "")),
		"target_hive_ids": (scenario_def.get("stress_target_hive_ids", []) as Array).duplicate(),
		"previous_tiers": _phase2_hive_tier_snapshot(state),
		"previous_swarms": _phase2_swarm_snapshot(state),
		"previous_chain_ledger_hash": "",
		"hive_tier_events": [],
		"swarm_events": [],
		"chain_ledger_events": [],
		"max_active_swarms": 0,
		"max_swarm_count_by_id": {}
	}

func _phase2_stress_track_tick(tracker: Dictionary, state: GameState, sim_runner: Node, tick: int) -> void:
	var target_hive_ids: Array = tracker.get("target_hive_ids", []) as Array
	var previous_tiers: Dictionary = tracker.get("previous_tiers", {}) as Dictionary
	var current_tiers: Dictionary = _phase2_hive_tier_snapshot(state)
	for hive_id_any in current_tiers.keys():
		var hive_id: int = int(hive_id_any)
		if not target_hive_ids.is_empty() and not target_hive_ids.has(hive_id):
			continue
		var old_tier: int = int(previous_tiers.get(hive_id, current_tiers.get(hive_id, 0)))
		var new_tier: int = int(current_tiers.get(hive_id, old_tier))
		if new_tier != old_tier:
			var hive: HiveData = state.find_hive_by_id(hive_id) if state != null else null
			(tracker.get("hive_tier_events", []) as Array).append({
				"tick": tick,
				"hive_id": hive_id,
				"old_tier": old_tier,
				"new_tier": new_tier,
				"power": int(hive.power) if hive != null else -1
			})
	tracker["previous_tiers"] = current_tiers

	var previous_swarms: Dictionary = tracker.get("previous_swarms", {}) as Dictionary
	var current_swarms: Dictionary = _phase2_swarm_snapshot(state)
	var swarm_events: Array = tracker.get("swarm_events", []) as Array
	var max_counts: Dictionary = tracker.get("max_swarm_count_by_id", {}) as Dictionary
	for swarm_id_any in current_swarms.keys():
		var swarm_id: int = int(swarm_id_any)
		var current: Dictionary = current_swarms.get(swarm_id, {}) as Dictionary
		var current_count: int = int(current.get("count", 0))
		max_counts[swarm_id] = maxi(int(max_counts.get(swarm_id, 0)), current_count)
		if not previous_swarms.has(swarm_id):
			swarm_events.append({
				"tick": tick,
				"event": "spawned",
				"swarm_id": swarm_id,
				"src": int(current.get("src", -1)),
				"dst": int(current.get("dst", -1)),
				"count": current_count
			})
		else:
			var previous: Dictionary = previous_swarms.get(swarm_id, {}) as Dictionary
			var previous_count: int = int(previous.get("count", 0))
			if current_count > previous_count:
				swarm_events.append({
					"tick": tick,
					"event": "grew",
					"swarm_id": swarm_id,
					"from_count": previous_count,
					"to_count": current_count
				})
	for swarm_id_any in previous_swarms.keys():
		var swarm_id: int = int(swarm_id_any)
		if current_swarms.has(swarm_id):
			continue
		var previous: Dictionary = previous_swarms.get(swarm_id, {}) as Dictionary
		swarm_events.append({
			"tick": tick,
			"event": "landed",
			"swarm_id": swarm_id,
			"src": int(previous.get("src", -1)),
			"dst": int(previous.get("dst", -1)),
			"count": int(previous.get("count", 0))
		})
	tracker["previous_swarms"] = current_swarms
	tracker["max_active_swarms"] = maxi(int(tracker.get("max_active_swarms", 0)), current_swarms.size())
	tracker["max_swarm_count_by_id"] = max_counts

	var ledger: Array = _phase2_swarm_chain_ledger_snapshot(sim_runner)
	var ledger_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(ledger)
	if not ledger.is_empty() and ledger_hash != str(tracker.get("previous_chain_ledger_hash", "")):
		(tracker.get("chain_ledger_events", []) as Array).append({"tick": tick, "entries": ledger})
	tracker["previous_chain_ledger_hash"] = ledger_hash

func _phase2_hive_tier_snapshot(state: GameState) -> Dictionary:
	var out: Dictionary = {}
	if state == null:
		return out
	for hive_any in state.hives:
		if hive_any is HiveData:
			var hive: HiveData = hive_any as HiveData
			out[int(hive.id)] = HIVE_GROWTH_RULES.tier_for_power(int(hive.power))
	return out

func _phase2_swarm_snapshot(state: GameState) -> Dictionary:
	var out: Dictionary = {}
	if state == null:
		return out
	for swarm_any in state.swarm_packets:
		if typeof(swarm_any) != TYPE_DICTIONARY:
			continue
		var swarm: Dictionary = swarm_any as Dictionary
		var swarm_id: int = int(swarm.get("id", -1))
		if swarm_id <= 0:
			continue
		out[swarm_id] = {
			"src": int(swarm.get("from_id", -1)),
			"dst": int(swarm.get("to_id", -1)),
			"lane_id": int(swarm.get("lane_id", -1)),
			"owner_id": int(swarm.get("owner_id", 0)),
			"count": int(swarm.get("count", 0))
		}
	return out

func _phase2_swarm_chain_ledger_snapshot(sim_runner: Node) -> Array:
	var out: Array = []
	var swarm_system: Object = sim_runner.get("swarm_system") if sim_runner != null else null
	if swarm_system == null:
		return out
	var ledger_any: Variant = swarm_system.get("_recent_landed_swarms_by_hive")
	if typeof(ledger_any) != TYPE_DICTIONARY:
		return out
	var ledger: Dictionary = ledger_any as Dictionary
	var hive_ids: Array = ledger.keys()
	hive_ids.sort()
	for hive_id_any in hive_ids:
		var entry_any: Variant = ledger.get(hive_id_any, {})
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		out.append({
			"hive_id": int(hive_id_any),
			"owner_id": int(entry.get("owner_id", 0)),
			"count": int(entry.get("count", 0)),
			"source_swarm_id": int(entry.get("swarm_id", -1)),
			"expires_us": int(entry.get("expires_us", 0))
		})
	return out

func _phase2_stress_track_render(peaks: Dictionary, arena: Node) -> void:
	var snapshot: Dictionary = _phase2_render_lifecycle_snapshot(arena)
	for key in [
		"growth_active_count",
		"growth_visible_ring_count",
		"growth_material_count",
		"growth_child_count",
		"swarm_renderer_count",
		"swarm_renderer_child_count"
	]:
		peaks[key] = maxi(int(peaks.get(key, 0)), int(snapshot.get(key, 0)))

func _phase2_render_lifecycle_snapshot(arena: Node) -> Dictionary:
	var out: Dictionary = {
		"growth_active_count": 0,
		"growth_visible_ring_count": 0,
		"growth_material_count": 0,
		"growth_child_count": 0,
		"swarm_renderer_count": 0,
		"swarm_renderer_child_count": 0
	}
	if arena == null:
		return out
	var hive_renderer: Node = arena.get_node_or_null("MapRoot/HiveRenderer")
	if hive_renderer != null and hive_renderer.has_method("get_hive_nodes"):
		for node_any in hive_renderer.call("get_hive_nodes") as Array:
			var hive_node: Node = node_any as Node
			if hive_node == null or not hive_node.has_method("get_growth_transition_debug_snapshot"):
				continue
			var growth: Dictionary = hive_node.call("get_growth_transition_debug_snapshot") as Dictionary
			if bool(growth.get("active", false)):
				out["growth_active_count"] = int(out.get("growth_active_count", 0)) + 1
			out["growth_visible_ring_count"] = int(out.get("growth_visible_ring_count", 0)) + int(growth.get("visible_ring_count", 0))
			out["growth_material_count"] = int(out.get("growth_material_count", 0)) + int(growth.get("material_count", 0))
			out["growth_child_count"] = int(out.get("growth_child_count", 0)) + int(growth.get("child_count", 0))
	var unit_renderer: Node = arena.get_node_or_null("PoolsRoot/UnitRenderer")
	if unit_renderer != null:
		var swarm_nodes_any: Variant = unit_renderer.get("swarm_nodes_by_id")
		if typeof(swarm_nodes_any) == TYPE_DICTIONARY:
			var swarm_nodes: Dictionary = swarm_nodes_any as Dictionary
			out["swarm_renderer_count"] = swarm_nodes.size()
			for swarm_node_any in swarm_nodes.values():
				var swarm_node: Node = swarm_node_any as Node
				if swarm_node != null:
					out["swarm_renderer_child_count"] = int(out.get("swarm_renderer_child_count", 0)) + swarm_node.get_child_count()
	return out

func _phase2_stress_finalize(
	tracker: Dictionary,
	render_peaks: Dictionary,
	state: GameState,
	sim_runner: Node,
	arena: Node,
	scenario_def: Dictionary
) -> Dictionary:
	var profile: String = str(tracker.get("profile", ""))
	var failures: Array = []
	var tier_events: Array = tracker.get("hive_tier_events", []) as Array
	var swarm_events: Array = tracker.get("swarm_events", []) as Array
	var ledger_events: Array = tracker.get("chain_ledger_events", []) as Array
	var max_counts: Dictionary = tracker.get("max_swarm_count_by_id", {}) as Dictionary
	var final_render: Dictionary = _phase2_render_lifecycle_snapshot(arena)
	var final_swarms: Dictionary = _phase2_swarm_snapshot(state)
	var final_ledger: Array = _phase2_swarm_chain_ledger_snapshot(sim_runner)
	if profile == "hive_upgrade_storm":
		if tier_events.size() != (scenario_def.get("stress_target_hive_ids", []) as Array).size():
			failures.append("hive_upgrade_transition_count_mismatch")
		for event_any in tier_events:
			var event: Dictionary = event_any as Dictionary
			if int(event.get("new_tier", 0)) != int(event.get("old_tier", 0)) + 1:
				failures.append("hive_upgrade_skipped_tier")
		if int(render_peaks.get("growth_active_count", 0)) <= 0:
			failures.append("hive_growth_renderer_transition_not_observed")
		if int(render_peaks.get("growth_visible_ring_count", 0)) <= 0:
			failures.append("hive_growth_ring_vfx_not_observed")
		if int(final_render.get("growth_active_count", 0)) != 0:
			failures.append("hive_growth_renderer_not_settled")
	elif profile == "super_swarm_chain":
		var spawned_ids: Array[int] = []
		var landed_ids: Array[int] = []
		for event_any in swarm_events:
			var event: Dictionary = event_any as Dictionary
			var event_name: String = str(event.get("event", ""))
			var swarm_id: int = int(event.get("swarm_id", -1))
			if event_name == "spawned" and not spawned_ids.has(swarm_id):
				spawned_ids.append(swarm_id)
			elif event_name == "landed" and not landed_ids.has(swarm_id):
				landed_ids.append(swarm_id)
		spawned_ids.sort()
		landed_ids.sort()
		if spawned_ids.size() < 2:
			failures.append("super_swarm_two_hop_spawn_missing")
		if landed_ids.size() < 2:
			failures.append("super_swarm_two_hop_landing_missing")
		if ledger_events.is_empty():
			failures.append("super_swarm_chain_ledger_not_observed")
		if spawned_ids.size() >= 1 and int(max_counts.get(spawned_ids[0], 0)) <= 5:
			failures.append("super_swarm_pickup_growth_not_observed")
		if spawned_ids.size() >= 2 and int(max_counts.get(spawned_ids[1], 0)) <= 5:
			failures.append("super_swarm_carry_chain_not_observed")
		if int(render_peaks.get("swarm_renderer_count", 0)) <= 0:
			failures.append("super_swarm_renderer_not_observed")
		if not final_swarms.is_empty() or int(final_render.get("swarm_renderer_count", 0)) != 0:
			failures.append("super_swarm_lifecycle_not_settled")
	else:
		failures.append("phase2_stress_profile_unknown")
	var event_payload: Dictionary = {
		"hive_tier_events": tier_events,
		"swarm_events": swarm_events,
		"chain_ledger_events": ledger_events,
		"max_active_swarms": int(tracker.get("max_active_swarms", 0)),
		"max_swarm_count_by_id": max_counts
	}
	var render_payload: Dictionary = {
		"peaks": render_peaks.duplicate(true),
		"final": final_render,
		"final_chain_ledger": final_ledger
	}
	return {
		"pass": failures.is_empty(),
		"failures": failures,
		"profile": profile,
		"events": event_payload,
		"event_hash": PERF_DETERMINISTIC_HASH.hash_variant(event_payload),
		"render_lifecycle": render_payload,
		"render_lifecycle_hash": PERF_DETERMINISTIC_HASH.hash_variant(render_payload)
	}

func _phase2_battlefield_tracker_start(state: GameState, scenario_def: Dictionary) -> Dictionary:
	var initial_counts: Dictionary = _phase2_battlefield_state_counts(state)
	return {
		"profile": str(scenario_def.get("phase2_battlefield_profile", "")),
		"target_hive_ids": (scenario_def.get("stress_target_hive_ids", []) as Array).duplicate(),
		"previous_owner_by_hive": _phase2_owner_snapshot(state),
		"previous_counts_hash": PERF_DETERMINISTIC_HASH.hash_variant(initial_counts),
		"count_events": [{"tick": 0, "counts": initial_counts}],
		"owner_events": [],
		"presentation_events": [],
		"max_lanes": int(initial_counts.get("lanes", 0)),
		"max_units": int(initial_counts.get("units", 0)),
		"max_swarms": int(initial_counts.get("swarms", 0)),
		"expected_camera_events": (scenario_def.get("camera_schedule", []) as Array).size(),
		"expected_ui_events": (scenario_def.get("ui_schedule", []) as Array).size()
	}

func _phase2_battlefield_track_tick(tracker: Dictionary, state: GameState, tick: int) -> void:
	var counts: Dictionary = _phase2_battlefield_state_counts(state)
	tracker["max_lanes"] = maxi(int(tracker.get("max_lanes", 0)), int(counts.get("lanes", 0)))
	tracker["max_units"] = maxi(int(tracker.get("max_units", 0)), int(counts.get("units", 0)))
	tracker["max_swarms"] = maxi(int(tracker.get("max_swarms", 0)), int(counts.get("swarms", 0)))
	var counts_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(counts)
	if counts_hash != str(tracker.get("previous_counts_hash", "")):
		(tracker.get("count_events", []) as Array).append({"tick": tick, "counts": counts})
	tracker["previous_counts_hash"] = counts_hash
	var previous_owners: Dictionary = tracker.get("previous_owner_by_hive", {}) as Dictionary
	var current_owners: Dictionary = _phase2_owner_snapshot(state)
	var target_hive_ids: Array = tracker.get("target_hive_ids", []) as Array
	for hive_id_any in current_owners.keys():
		var hive_id: int = int(hive_id_any)
		if not target_hive_ids.is_empty() and not target_hive_ids.has(hive_id):
			continue
		var old_owner: int = int(previous_owners.get(hive_id, current_owners.get(hive_id, 0)))
		var new_owner: int = int(current_owners.get(hive_id, old_owner))
		if old_owner != new_owner:
			(tracker.get("owner_events", []) as Array).append({
				"tick": tick,
				"hive_id": hive_id,
				"old_owner": old_owner,
				"new_owner": new_owner
			})
	tracker["previous_owner_by_hive"] = current_owners

func _phase2_battlefield_state_counts(state: GameState) -> Dictionary:
	if state == null:
		return {"hives": 0, "lanes": 0, "units": 0, "swarms": 0, "towers": 0, "barracks": 0}
	return {
		"hives": state.hives.size(),
		"lanes": state.lanes.size(),
		"units": _runtime_unit_count(state),
		"swarms": state.swarm_packets.size(),
		"towers": state.towers.size(),
		"barracks": state.barracks.size()
	}

func _phase2_owner_snapshot(state: GameState) -> Dictionary:
	var out: Dictionary = {}
	if state == null:
		return out
	for hive_any in state.hives:
		if hive_any is HiveData:
			var hive: HiveData = hive_any as HiveData
			out[int(hive.id)] = int(hive.owner_id)
	return out

func _phase2_apply_presentation_schedule(
	scene_root: Node,
	arena: Node,
	scenario_def: Dictionary,
	frame_number: int,
	tracker: Dictionary
) -> void:
	var presentation_events: Array = tracker.get("presentation_events", []) as Array
	for camera_any in scenario_def.get("camera_schedule", []) as Array:
		var entry: Dictionary = camera_any as Dictionary
		if int(entry.get("frame", -1)) != frame_number:
			continue
		var camera_node: Camera2D = arena.get_node_or_null("Camera2D") as Camera2D if arena != null else null
		var position_values: Array = entry.get("position", []) as Array
		var zoom_values: Array = entry.get("zoom", []) as Array
		var position := Vector2(float(position_values[0]), float(position_values[1]))
		var zoom := Vector2(float(zoom_values[0]), float(zoom_values[1]))
		if camera_node != null:
			camera_node.make_current()
			camera_node.global_position = position
			camera_node.zoom = zoom
			camera_node.force_update_scroll()
		presentation_events.append({
			"kind": "camera",
			"frame": frame_number,
			"path": "Camera2D",
			"position": [position.x, position.y],
			"zoom": [zoom.x, zoom.y],
			"ok": camera_node != null
		})
	for ui_any in scenario_def.get("ui_schedule", []) as Array:
		var entry: Dictionary = ui_any as Dictionary
		if int(entry.get("frame", -1)) != frame_number:
			continue
		var path: String = str(entry.get("path", ""))
		var node: CanvasItem = scene_root.get_node_or_null(path) as CanvasItem if scene_root != null else null
		var visible: bool = bool(entry.get("visible", false))
		if node != null:
			node.visible = visible
		presentation_events.append({
			"kind": "ui",
			"frame": frame_number,
			"path": path,
			"visible": visible,
			"ok": node != null
		})
	tracker["presentation_events"] = presentation_events

func _phase2_battlefield_track_render(peaks: Dictionary, scene_root: Node, arena: Node) -> void:
	var hive_renderer: Node = arena.get_node_or_null("MapRoot/HiveRenderer") if arena != null else null
	if hive_renderer != null and hive_renderer.has_method("get_distress_debug_snapshot"):
		var distress: Dictionary = hive_renderer.call("get_distress_debug_snapshot") as Dictionary
		peaks["distress_active_count"] = maxi(int(peaks.get("distress_active_count", 0)), int(distress.get("active_count", 0)))
		peaks["distress_pressure_count"] = maxi(int(peaks.get("distress_pressure_count", 0)), int(distress.get("pressure_count", 0)))
		peaks["distress_rupture_count"] = maxi(int(peaks.get("distress_rupture_count", 0)), int(distress.get("rupture_count", 0)))
	var lane_renderer: CanvasItem = arena.get_node_or_null("MapRoot/LaneRenderer") as CanvasItem if arena != null else null
	peaks["lane_renderer_observed"] = bool(peaks.get("lane_renderer_observed", false)) or (lane_renderer != null and lane_renderer.visible)
	var tower_renderer: Node = arena.get_node_or_null("MapRoot/TowerRenderer") if arena != null else null
	var barracks_renderer: Node = arena.get_node_or_null("MapRoot/BarracksRenderer") if arena != null else null
	peaks["tower_renderer_children"] = maxi(int(peaks.get("tower_renderer_children", 0)), tower_renderer.get_child_count() if tower_renderer != null else 0)
	peaks["barracks_renderer_children"] = maxi(int(peaks.get("barracks_renderer_children", 0)), barracks_renderer.get_child_count() if barracks_renderer != null else 0)
	var pool: Dictionary = _unit_renderer_pool_snapshot(arena)
	peaks["unit_pool_peak_active"] = maxi(int(peaks.get("unit_pool_peak_active", 0)), int(pool.get("peak_pooled_objects", 0)))
	var visible_scheduled_ui: int = 0
	if scene_root != null:
		for path in ["UI/SelectionHud", "UI/MissNOutBanner", "HudOverlayLayer/HudOverlay"]:
			var node: CanvasItem = scene_root.get_node_or_null(path) as CanvasItem
			if node != null and node.visible:
				visible_scheduled_ui += 1
	peaks["scheduled_ui_visible_count"] = maxi(int(peaks.get("scheduled_ui_visible_count", 0)), visible_scheduled_ui)

func _phase2_battlefield_finalize(
	tracker: Dictionary,
	render_peaks: Dictionary,
	state: GameState,
	scenario_def: Dictionary
) -> Dictionary:
	var profile: String = str(tracker.get("profile", ""))
	var failures: Array = []
	var presentation_events: Array = tracker.get("presentation_events", []) as Array
	var camera_events: int = 0
	var ui_events: int = 0
	for event_any in presentation_events:
		var event: Dictionary = event_any as Dictionary
		if not bool(event.get("ok", false)):
			failures.append("presentation_target_missing:%s" % str(event.get("path", "")))
		if str(event.get("kind", "")) == "camera":
			camera_events += 1
		elif str(event.get("kind", "")) == "ui":
			ui_events += 1
	match profile:
		"late_match_v1":
			if int(tracker.get("max_lanes", 0)) < 8 or int(tracker.get("max_units", 0)) < 200:
				failures.append("late_match_concurrency_target_missing")
			if int(render_peaks.get("unit_pool_peak_active", 0)) < 200:
				failures.append("late_match_unit_renderer_scale_missing")
		"lane_stress_v1":
			if int(tracker.get("max_lanes", 0)) < 8:
				failures.append("lane_stress_lane_target_missing")
			if int(tracker.get("max_swarms", 0)) <= 0:
				failures.append("lane_stress_swarm_target_missing")
			if not bool(render_peaks.get("lane_renderer_observed", false)):
				failures.append("lane_renderer_not_observed")
		"structure_stress_v1":
			if state == null or state.towers.size() != 2 or state.barracks.size() != 2:
				failures.append("structure_state_count_mismatch")
			if int(render_peaks.get("tower_renderer_children", 0)) < 2 or int(render_peaks.get("barracks_renderer_children", 0)) < 2:
				failures.append("structure_renderer_count_mismatch")
		"distress_storm_v1":
			var distress_target: int = (scenario_def.get("stress_target_hive_ids", []) as Array).size()
			if (
				int(render_peaks.get("distress_active_count", 0)) < distress_target
				or int(render_peaks.get("distress_pressure_count", 0)) < distress_target
				or int(render_peaks.get("distress_rupture_count", 0)) < distress_target
			):
				failures.append("distress_lifecycle_not_observed")
		"capture_storm_v1":
			var capture_target: int = (scenario_def.get("stress_target_hive_ids", []) as Array).size()
			if (tracker.get("owner_events", []) as Array).size() != capture_target:
				failures.append("capture_transition_target_missing")
		"camera_stress_v1":
			if camera_events != int(tracker.get("expected_camera_events", -1)):
				failures.append("camera_schedule_incomplete")
		"ui_stress_v1":
			if ui_events != int(tracker.get("expected_ui_events", -1)):
				failures.append("ui_schedule_incomplete")
			if int(render_peaks.get("scheduled_ui_visible_count", 0)) <= 0:
				failures.append("ui_visibility_not_observed")
		_:
			failures.append("phase2_battlefield_profile_unknown")
	var event_payload: Dictionary = {
		"count_events": (tracker.get("count_events", []) as Array).duplicate(true),
		"owner_events": (tracker.get("owner_events", []) as Array).duplicate(true),
		"presentation_events": presentation_events.duplicate(true),
		"max_lanes": int(tracker.get("max_lanes", 0)),
		"max_units": int(tracker.get("max_units", 0)),
		"max_swarms": int(tracker.get("max_swarms", 0))
	}
	var render_payload: Dictionary = {
		"peaks": render_peaks.duplicate(true),
		"final_counts": _phase2_battlefield_state_counts(state),
		"expected_camera_events": int(tracker.get("expected_camera_events", 0)),
		"expected_ui_events": int(tracker.get("expected_ui_events", 0))
	}
	return {
		"pass": failures.is_empty(),
		"failures": failures,
		"profile": profile,
		"events": event_payload,
		"event_hash": PERF_DETERMINISTIC_HASH.hash_variant(event_payload),
		"render": render_payload,
		"render_hash": PERF_DETERMINISTIC_HASH.hash_variant(render_payload)
	}

func _unit_renderer_pool_snapshot(arena: Node) -> Dictionary:
	var renderer: Node = arena.get_node_or_null("PoolsRoot/UnitRenderer") if arena != null else null
	if renderer == null or not renderer.has_method("get_pool_telemetry_snapshot"):
		return {}
	return (renderer.call("get_pool_telemetry_snapshot") as Dictionary).duplicate(true)

func _stable_pool_identity(snapshot: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in [
		"pool_hits", "pool_misses", "pool_expansions", "runtime_instantiates_avoided",
		"active_pooled_objects", "available_pooled_objects", "total_pooled_objects", "peak_pooled_objects"
	]:
		out[key] = int(snapshot.get(key, -1))
	return out

func _issue_commands_for_tick(arena: Node, state: GameState, scenario_def: Dictionary, tick: int) -> Array:
	var schedule: Array = scenario_def.get("command_schedule", []) as Array
	if not schedule.is_empty():
		return _issue_scheduled_commands(arena, state, schedule, tick)
	return _issue_scripted_commands(arena, state, scenario_def, tick)

func _issue_scheduled_commands(arena: Node, state: GameState, schedule: Array, tick: int) -> Array:
	var issued: Array = []
	for schedule_index in range(schedule.size()):
		var command_any: Variant = schedule[schedule_index]
		if typeof(command_any) != TYPE_DICTIONARY:
			continue
		var command: Dictionary = command_any as Dictionary
		if int(command.get("tick", -1)) != tick:
			continue
		var kind: String = str(command.get("kind", ""))
		match kind:
			"lane_intent_pair":
				var pairs: Array = _candidate_attack_pairs(state)
				if pairs.is_empty():
					continue
				var pair_index: int = posmod(int(command.get("pair_index", 0)), pairs.size())
				var pair: Dictionary = pairs[pair_index] as Dictionary
				var intent: String = str(command.get("intent", "attack"))
				var result: Dictionary = OpsState.apply_lane_intent(int(pair.get("src", -1)), int(pair.get("dst", -1)), intent)
				if bool(result.get("ok", false)):
					issued.append({
						"type": intent,
						"src": int(pair.get("src", -1)),
						"dst": int(pair.get("dst", -1)),
						"schedule_index": schedule_index
					})
			"swarm_active_lane":
				var swarm_report: Dictionary = _issue_swarm_on_active_lane(state, int(command.get("salt", schedule_index)))
				if bool(swarm_report.get("ok", false)):
					swarm_report["schedule_index"] = schedule_index
					issued.append(swarm_report)
			"exact_lane_intent":
				var src_id: int = int(command.get("src", -1))
				var dst_id: int = int(command.get("dst", -1))
				var intent: String = str(command.get("intent", "feed"))
				var lane_result: Dictionary = OpsState.apply_lane_intent(src_id, dst_id, intent)
				if bool(lane_result.get("ok", false)):
					issued.append({"type": intent, "src": src_id, "dst": dst_id, "schedule_index": schedule_index})
			"exact_swarm_intent":
				var src_id: int = int(command.get("src", -1))
				var dst_id: int = int(command.get("dst", -1))
				var swarm_result: Dictionary = OpsState.apply_lane_intent(src_id, dst_id, "swarm")
				if bool(swarm_result.get("ok", false)):
					issued.append({"type": "swarm", "src": src_id, "dst": dst_id, "schedule_index": schedule_index})
	if arena != null and arena.has_method("mark_render_dirty") and not issued.is_empty():
		arena.call("mark_render_dirty", "perf_benchmark_scheduled")
	return issued

func _tick_selected_systems(arena: Node, sim_runner: Node, state: GameState, scenario_def: Dictionary, dt: float) -> Dictionary:
	var enabled: Dictionary = _enabled_system_lookup(scenario_def)
	var sections: Dictionary = {}
	var dt_ms: int = int(round(dt * 1000.0))
	_timed_section(sections, "ops_events", func() -> void:
		if bool(enabled.get("ops_events", false)):
			OpsState.tick_match_clock(state, dt_ms)
			state.tick_unintended_power(float(dt_ms))
	)
	_timed_section(sections, "bot_system", func() -> void:
		var bot: Object = sim_runner.get("bot_system") if sim_runner != null else null
		if bool(enabled.get("bot_system", false)) and bot != null and bot.has_method("tick"):
			bot.call("tick", dt)
	)
	_timed_section(sections, "lane_flow", func() -> void:
		if bool(enabled.get("lane_flow", false)):
			state.tick_lane_flow(dt * 1000.0)
			var lane_system: Object = sim_runner.get("lane_system") if sim_runner != null else null
			if lane_system != null and lane_system.has_method("tick_lane_fronts"):
				lane_system.call("tick_lane_fronts", dt)
	)
	_timed_section(sections, "edge_cache", func() -> void:
		var edge_cache: Object = sim_runner.get("edge_cache_system") if sim_runner != null else null
		if bool(enabled.get("edge_cache", false)) and edge_cache != null and edge_cache.has_method("rebuild_edge_cache"):
			edge_cache.call("rebuild_edge_cache", OpsState)
	)
	_timed_section(sections, "swarm_system", func() -> void:
		var swarm: Object = sim_runner.get("swarm_system") if sim_runner != null else null
		var unit_system: Object = sim_runner.get("unit_system") if sim_runner != null else null
		if bool(enabled.get("swarm_system", false)) and swarm != null and swarm.has_method("tick"):
			swarm.call("tick", dt, unit_system)
	)
	_timed_section(sections, "unit_system", func() -> void:
		var unit_system: Object = sim_runner.get("unit_system") if sim_runner != null else null
		if bool(enabled.get("unit_system", false)) and unit_system != null and unit_system.has_method("tick"):
			unit_system.call("tick", dt)
			if unit_system.has_method("tick_render_units"):
				unit_system.call("tick_render_units", dt)
	)
	_timed_section(sections, "structure_control", func() -> void:
		var structure_control: Object = sim_runner.get("structure_control_system") if sim_runner != null else null
		if bool(enabled.get("structure_control", false)) and structure_control != null and structure_control.has_method("tick"):
			structure_control.call("tick", dt)
	)
	_timed_section(sections, "tower_system", func() -> void:
		var tower_system: Object = sim_runner.get("tower_system") if sim_runner != null else null
		var unit_system: Object = sim_runner.get("unit_system") if sim_runner != null else null
		if bool(enabled.get("tower_system", false)) and tower_system != null and tower_system.has_method("tick"):
			tower_system.call("tick", dt, unit_system)
	)
	_timed_section(sections, "barracks_system", func() -> void:
		var barracks_system: Object = sim_runner.get("barracks_system") if sim_runner != null else null
		if bool(enabled.get("barracks_system", false)) and barracks_system != null and barracks_system.has_method("tick"):
			barracks_system.call("tick", dt)
	)
	_timed_section(sections, "render_model", func() -> void:
		if bool(enabled.get("render_model", false)) and arena != null and arena.has_method("export_render_model"):
			arena.call("export_render_model")
	)
	sections["total_ms"] = _sum_values(sections)
	return sections

func _issue_scripted_commands(arena: Node, state: GameState, scenario_def: Dictionary, tick: int) -> Array:
	var issued: Array = []
	var cadence: int = max(1, int(scenario_def.get("command_interval_ticks", 5)))
	if tick % cadence != 0:
		return issued
	var commands_per_burst: int = max(1, int(scenario_def.get("commands_per_burst", 1)))
	var pairs: Array = _candidate_attack_pairs(state)
	for i in range(mini(commands_per_burst, pairs.size())):
		var index: int = (tick + i) % pairs.size()
		var pair: Dictionary = pairs[index] as Dictionary
		var intent := "feed" if bool(pair.get("friendly", false)) else "attack"
		var result: Dictionary = OpsState.apply_lane_intent(int(pair.get("src", -1)), int(pair.get("dst", -1)), intent)
		if bool(result.get("ok", false)):
			issued.append({"type": intent, "src": pair.get("src", -1), "dst": pair.get("dst", -1)})
	var swarm_burst: int = max(0, int(scenario_def.get("swarm_burst", 0)))
	for j in range(swarm_burst):
		var swarm_report: Dictionary = _issue_swarm_on_active_lane(state, tick + j)
		if bool(swarm_report.get("ok", false)):
			issued.append(swarm_report)
	if arena != null and arena.has_method("mark_render_dirty") and not issued.is_empty():
		arena.call("mark_render_dirty", "perf_benchmark_scripted")
	return issued

func _scenario_definitions(
	suite_id: String,
	switch_overrides: Dictionary = {},
	scenario_filter: String = "",
	catalog_fixtures_by_id: Dictionary = {},
	catalog_common: Dictionary = {}
) -> Array:
	var scenarios: Array
	match suite_id:
		"phase0_integrity":
			scenarios = [_phase0_integrity_scenario()]
		"phase1_windowed_adapter":
			scenarios = [_phase1_windowed_adapter_probe_scenario()]
		"phase1_static_fixtures":
			scenarios = [
				_phase1_static_catalog_scenario("EMPTY_ARENA_V1", catalog_fixtures_by_id, catalog_common),
				_phase1_static_catalog_scenario("STATIC_BATTLEFIELD_V1", catalog_fixtures_by_id, catalog_common)
			]
		"phase1_normal_match_pilot":
			scenarios = [_phase1_normal_match_pilot_scenario()]
		"phase1_normal_match":
			scenarios = [_phase1_normal_match_catalog_scenario(catalog_fixtures_by_id, catalog_common)]
		"phase1_unit_scale":
			scenarios = [
				_phase1_unit_scale_catalog_scenario("UNIT_SCALE_050_V1", catalog_fixtures_by_id, catalog_common),
				_phase1_unit_scale_catalog_scenario("UNIT_SCALE_100_V1", catalog_fixtures_by_id, catalog_common),
				_phase1_unit_scale_catalog_scenario("UNIT_SCALE_200_V1", catalog_fixtures_by_id, catalog_common),
				_phase1_unit_scale_catalog_scenario("UNIT_SCALE_400_V1", catalog_fixtures_by_id, catalog_common)
			]
		"phase2_moving_unit_scale":
			scenarios = [
				_phase2_moving_unit_scale_scenario(50, catalog_fixtures_by_id, catalog_common),
				_phase2_moving_unit_scale_scenario(100, catalog_fixtures_by_id, catalog_common),
				_phase2_moving_unit_scale_scenario(200, catalog_fixtures_by_id, catalog_common),
				_phase2_moving_unit_scale_scenario(400, catalog_fixtures_by_id, catalog_common)
			]
		"phase2_upgrade_swarm_stress":
			scenarios = [
				_phase2_hive_upgrade_storm_scenario(),
				_phase2_super_swarm_chain_scenario()
			]
		"phase2_battlefield_ui_stress":
			scenarios = [
				_phase2_late_match_scenario(),
				_phase2_lane_stress_scenario(),
				_phase2_structure_stress_scenario(),
				_phase2_distress_storm_scenario(),
				_phase2_capture_storm_scenario(),
				_phase2_camera_stress_scenario(),
				_phase2_ui_stress_scenario()
			]
		"phase2_lifecycle_soak":
			scenarios = [_phase2_lifecycle_soak_scenario()]
		"phase2_feature_isolation":
			scenarios = [
				_phase2_feature_isolation_scenario("off"),
				_phase2_feature_isolation_scenario("production"),
				_phase2_feature_isolation_scenario("exaggerated")
			]
		"phase0_collector_calibration":
			scenarios = _phase0_collector_calibration_scenarios()
		"phase0_isolation":
			var sentinel: Dictionary = _phase0_isolation_sentinel_scenario()
			scenarios = [
				sentinel,
				_phase0_isolation_mutator_scenario(),
				sentinel.duplicate(true)
			]
		"quick":
			scenarios = [
				_scenario_def("sim_bootstrap_5s", MAP_QUICK, 5.0, 4101, ["ops_events", "lane_flow", "edge_cache", "render_model"], 4, 0, 1),
				_scenario_def("arena_lane_unit_10s", MAP_QUICK, 10.0, 4201, ["ops_events", "lane_flow", "edge_cache", "swarm_system", "unit_system"], 6, 1, 2),
				_scenario_def("full_stack_10s", MAP_STRUCTURES, 10.0, 4301, _full_stack_systems(), 8, 2, 3)
			]
		"layers", "sprint_layers":
			scenarios = [
				_scenario_def("layer_lane_flow_10s", MAP_LAYERS, 10.0, 5101, ["ops_events", "lane_flow"], 12, 0, 2),
				_scenario_def("layer_edge_cache_10s", MAP_LAYERS, 10.0, 5111, ["edge_cache"], 12, 0, 1),
				_scenario_def("layer_units_10s", MAP_LAYERS, 10.0, 5121, ["ops_events", "lane_flow", "swarm_system", "unit_system"], 14, 3, 3),
				_scenario_def("layer_towers_10s", MAP_STRUCTURES, 10.0, 5131, ["structure_control", "tower_system"], 10, 2, 2),
				_scenario_def("layer_barracks_10s", MAP_STRUCTURES, 10.0, 5141, ["structure_control", "barracks_system", "lane_flow", "unit_system"], 10, 1, 2, 2),
				_scenario_def("layer_render_model_10s", MAP_LAYERS, 10.0, 5151, ["render_model"], 12, 0, 1),
				_scenario_def("full_stack_15s", MAP_STRUCTURES, 15.0, 5161, _full_stack_systems(), 14, 3, 4),
				_stress_scenario()
			]
		_:
			scenarios = [
				_scenario_def("sim_bootstrap_5s", MAP_QUICK, 5.0, 4101, ["ops_events", "lane_flow", "edge_cache", "render_model"], 4, 0, 1),
				_scenario_def("arena_lane_unit_10s", MAP_QUICK, 10.0, 4201, ["ops_events", "lane_flow", "edge_cache", "swarm_system", "unit_system"], 6, 1, 2),
				_scenario_def("full_stack_10s", MAP_STRUCTURES, 10.0, 4301, _full_stack_systems(), 8, 2, 3)
			]
	var filtered: Array = []
	var clean_filter := scenario_filter.strip_edges()
	if not clean_filter.is_empty():
		for scenario_any in scenarios:
			var scenario: Dictionary = scenario_any as Dictionary
			if str(scenario.get("scenario_id", "")) == clean_filter:
				filtered.append(scenario)
		scenarios = filtered
	for scenario_any in scenarios:
		var scenario: Dictionary = scenario_any as Dictionary
		_apply_runtime_switch_overrides(scenario, switch_overrides)
	return scenarios

func _scenario_def(
	scenario_id: String,
	map_path: String,
	duration_sec: float,
	seed_value: int,
	systems: Array,
	initial_lanes: int,
	initial_swarms: int,
	commands_per_burst: int,
	initial_barracks_routes: int = 0
) -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"map_path": map_path,
		"duration_sec": duration_sec,
		"fixture_version": 1,
		"seed": seed_value,
		"tick_count": maxi(1, int(round(duration_sec / SIM_TICK_INTERVAL_SEC))),
		"warmup_ticks": 0,
		"repetitions": 1,
		"systems": systems.duplicate(),
		"initial_lanes": initial_lanes,
		"initial_swarms": initial_swarms,
		"initial_barracks_routes": initial_barracks_routes,
		"command_interval_ticks": 5,
		"commands_per_burst": commands_per_burst,
		"swarm_burst": initial_swarms,
		"command_schedule": [],
		"runtime_switches": {
			"arena_polish_comparison_mode": "baseline",
			"premium_polish_enabled": false,
			"tower_visual_scale": 1.0
		},
		"renderers": ["floor", "hive", "lane", "unit", "tower", "wall", "barracks", "polish"],
		"expected_counts": (EXPECTED_COUNTS_BY_MAP.get(map_path, {}) as Dictionary).duplicate(true)
	}

func _phase0_integrity_scenario() -> Dictionary:
	var scenario: Dictionary = _scenario_def(
		"PHASE0_INTEGRITY_CENTERSTRIKE_V1",
		MAP_QUICK,
		5.0,
		4101,
		["canonical_simrunner"],
		4,
		0,
		1
	)
	scenario["tick_count"] = 50
	scenario["warmup_ticks"] = 10
	scenario["repetitions"] = 3
	scenario["expected_command_count_min"] = 8
	scenario["expected_command_types"] = ["attack", "swarm"]
	scenario["command_schedule"] = [
		{"tick": 5, "kind": "lane_intent_pair", "pair_index": 4, "intent": "attack"},
		{"tick": 15, "kind": "swarm_active_lane", "salt": 0},
		{"tick": 25, "kind": "lane_intent_pair", "pair_index": 5, "intent": "attack"},
		{"tick": 35, "kind": "lane_intent_pair", "pair_index": 6, "intent": "attack"}
	]
	return scenario

func _phase1_windowed_adapter_probe_scenario() -> Dictionary:
	var scenario: Dictionary = _scenario_def(
		"P1B_WINDOWED_ADAPTER_PROBE_V1",
		MAP_PHASE1,
		12.0,
		6101,
		["canonical_simrunner"],
		0,
		0,
		1
	)
	scenario["fixture_id"] = "P1B_WINDOWED_ADAPTER_PROBE_V1"
	scenario["measurement_profile"] = "deterministic_windowed_presentation"
	scenario["catalog_fixture_registered"] = false
	scenario["camera_policy"] = "production_map_fit"
	scenario["tick_count"] = 120
	scenario["warmup_ticks"] = 20
	scenario["repetitions"] = 3
	scenario["initial_lanes"] = 0
	scenario["command_schedule"] = []
	scenario["performance_gating"] = false
	scenario["cadence"] = {
		"target_fps": 30,
		"simulation_hz": 10,
		"frames_per_simulation_tick": 3,
		"warmup_frames": 60,
		"measurement_frames": 300,
		"simulation_active": true
	}
	return scenario

func _phase1_static_catalog_scenario(fixture_id: String, catalog_fixtures_by_id: Dictionary, catalog_common: Dictionary) -> Dictionary:
	var fixture: Dictionary = catalog_fixtures_by_id.get(fixture_id, {}) as Dictionary
	if fixture.is_empty():
		return {}
	var production_map: Dictionary = catalog_common.get("production_map", {}) as Dictionary
	var content_kind: String = str(fixture.get("content_kind", ""))
	var map_path: String = str(production_map.get("path", "")) if content_kind == "production_map" else ""
	var scenario: Dictionary = _scenario_def(
		fixture_id,
		map_path,
		12.0,
		int(fixture.get("seed", 0)),
		[],
		0,
		0,
		1
	)
	scenario["fixture_id"] = fixture_id
	scenario["fixture_version"] = int(fixture.get("fixture_version", 1))
	scenario["fixture_catalog_status"] = str(fixture.get("status", ""))
	scenario["measurement_profile"] = "static_windowed_deterministic"
	scenario["catalog_fixture_registered"] = true
	scenario["content_kind"] = content_kind
	scenario["content_identity"] = str(fixture.get("content_identity", "")) if content_kind == "synthetic_scene" else "sha256:%s" % str(production_map.get("sha256", ""))
	scenario["camera_policy"] = "authored_scene_transform" if content_kind == "synthetic_scene" else "production_map_fit"
	scenario["repetitions"] = int(catalog_common.get("repetitions", 3))
	scenario["initial_lanes"] = 0
	scenario["initial_swarms"] = 0
	scenario["command_schedule"] = []
	scenario["expected_counts"] = (fixture.get("expected_counts", {}) as Dictionary).duplicate(true)
	var cadence: Dictionary = (catalog_common.get("deterministic_windowed_cadence", {}) as Dictionary).duplicate(true)
	cadence["simulation_active"] = false
	scenario["cadence"] = cadence
	scenario["performance_gating"] = true
	scenario["baseline_candidate"] = bool(fixture.get("baseline_candidate", false))
	if content_kind == "synthetic_scene":
		scenario["synthetic_descriptor"] = {
			"_schema": "sf_perf_synthetic_scene_v1",
			"map_id": str(fixture.get("content_identity", fixture_id)),
			"grid": {"width": 12, "height": 20},
			"hives": [],
			"lane_candidates": [],
			"walls": [],
			"towers": [],
			"barracks": [],
			"structure_slots": [],
			"spawns": []
		}
	return scenario

func _phase1_normal_match_pilot_scenario() -> Dictionary:
	var scenario: Dictionary = _scenario_def(
		"P1D_NORMAL_MATCH_PILOT_V1",
		MAP_PHASE1,
		12.0,
		6201,
		["canonical_simrunner"],
		0,
		0,
		1
	)
	scenario["fixture_id"] = "P1D_NORMAL_MATCH_PILOT_V1"
	scenario["measurement_profile"] = "canonical_sim_headless"
	scenario["catalog_fixture_registered"] = false
	scenario["command_selector_version"] = "sorted_candidate_pair_v1"
	scenario["tick_count"] = 120
	scenario["warmup_ticks"] = 20
	scenario["repetitions"] = 3
	scenario["initial_lanes"] = 0
	scenario["expected_command_count_min"] = 4
	scenario["expected_command_count_exact"] = 4
	scenario["expected_command_types"] = ["attack", "swarm"]
	scenario["command_schedule"] = NORMAL_MATCH_PILOT_SCHEDULE.duplicate(true)
	return scenario

func _phase1_normal_match_catalog_scenario(catalog_fixtures_by_id: Dictionary, catalog_common: Dictionary) -> Dictionary:
	var fixture: Dictionary = catalog_fixtures_by_id.get("NORMAL_MATCH_V1", {}) as Dictionary
	if fixture.is_empty():
		return {}
	var production_map: Dictionary = catalog_common.get("production_map", {}) as Dictionary
	var timing: Dictionary = fixture.get("timing", {}) as Dictionary
	var expected_counts: Dictionary = (production_map.get("expected_counts", {}) as Dictionary).duplicate(true)
	expected_counts["active_lanes"] = 0
	expected_counts["units"] = 0
	var scenario: Dictionary = _scenario_def(
		"NORMAL_MATCH_V1",
		str(production_map.get("path", "")),
		float(timing.get("total_ticks", 120)) * SIM_TICK_INTERVAL_SEC,
		int(fixture.get("seed", 0)),
		["canonical_simrunner"],
		0,
		0,
		1
	)
	scenario["fixture_id"] = "NORMAL_MATCH_V1"
	scenario["fixture_version"] = int(fixture.get("fixture_version", 1))
	scenario["fixture_catalog_status"] = str(fixture.get("status", ""))
	scenario["catalog_fixture_registered"] = true
	scenario["content_kind"] = "production_map"
	scenario["content_identity"] = "sha256:%s" % str(production_map.get("sha256", ""))
	scenario["camera_policy"] = "production_map_fit"
	scenario["command_selector_version"] = str(fixture.get("command_selector_version", ""))
	scenario["tick_count"] = int(timing.get("total_ticks", 120))
	scenario["warmup_ticks"] = int(timing.get("warmup_ticks", 20))
	scenario["repetitions"] = int(catalog_common.get("repetitions", 3))
	scenario["initial_lanes"] = 0
	scenario["command_schedule"] = (fixture.get("command_schedule", []) as Array).duplicate(true)
	scenario["expected_command_count_min"] = int(fixture.get("expected_command_count", 0))
	scenario["expected_command_count_exact"] = int(fixture.get("expected_command_count", 0))
	scenario["expected_command_types"] = (fixture.get("expected_command_types", []) as Array).duplicate(true)
	scenario["expected_accepted_commands"] = (fixture.get("expected_accepted_commands", []) as Array).duplicate(true)
	scenario["expected_command_log_hash"] = str(fixture.get("pilot_accepted_command_hash", ""))
	scenario["expected_canonical_final_state_hash"] = str(fixture.get("pilot_canonical_final_state_hash", ""))
	scenario["expected_counts"] = expected_counts
	var cadence: Dictionary = (catalog_common.get("deterministic_windowed_cadence", {}) as Dictionary).duplicate(true)
	cadence["simulation_active"] = true
	scenario["cadence"] = cadence
	scenario["performance_gating"] = true
	scenario["baseline_candidate"] = bool(fixture.get("baseline_candidate", false))
	return scenario

func _phase1_unit_scale_catalog_scenario(fixture_id: String, catalog_fixtures_by_id: Dictionary, catalog_common: Dictionary) -> Dictionary:
	var fixture: Dictionary = catalog_fixtures_by_id.get(fixture_id, {}) as Dictionary
	if fixture.is_empty():
		return {}
	var production_map: Dictionary = catalog_common.get("production_map", {}) as Dictionary
	var expected_counts: Dictionary = (production_map.get("expected_counts", {}) as Dictionary).duplicate(true)
	expected_counts["active_lanes"] = 0
	expected_counts["units"] = 0
	var scenario: Dictionary = _scenario_def(
		fixture_id,
		str(production_map.get("path", "")),
		12.0,
		int(fixture.get("seed", 0)),
		[],
		2,
		0,
		1
	)
	scenario["fixture_id"] = fixture_id
	scenario["fixture_version"] = int(fixture.get("fixture_version", 1))
	scenario["fixture_catalog_status"] = str(fixture.get("status", ""))
	scenario["measurement_profile"] = "static_windowed_deterministic"
	scenario["catalog_fixture_registered"] = true
	scenario["content_kind"] = "production_map"
	scenario["content_identity"] = "sha256:%s" % str(production_map.get("sha256", ""))
	scenario["camera_policy"] = "production_map_fit"
	scenario["repetitions"] = int(catalog_common.get("repetitions", 3))
	scenario["target_units"] = int(fixture.get("target_units", 0))
	scenario["initial_lanes"] = int(fixture.get("initial_lanes", 0))
	scenario["lane_build_timeout_ms"] = int(fixture.get("lane_build_timeout_ms", 0))
	scenario["renderer_ready_timeout_ms"] = int(fixture.get("renderer_ready_timeout_ms", 0))
	scenario["capacity_bypass_allowed"] = bool(fixture.get("capacity_bypass_allowed", true))
	scenario["expected_pool_capacity"] = int(fixture.get("expected_pool_capacity", 0))
	scenario["expected_pool_expansions"] = int(fixture.get("expected_pool_expansions", -1))
	scenario["command_schedule"] = []
	scenario["expected_counts"] = expected_counts
	var cadence: Dictionary = (catalog_common.get("deterministic_windowed_cadence", {}) as Dictionary).duplicate(true)
	cadence["simulation_active"] = false
	scenario["cadence"] = cadence
	scenario["performance_gating"] = true
	scenario["baseline_candidate"] = bool(fixture.get("baseline_candidate", false))
	return scenario

func _phase2_moving_unit_scale_scenario(target_units: int, catalog_fixtures_by_id: Dictionary, catalog_common: Dictionary) -> Dictionary:
	var source_fixture_id: String = "UNIT_SCALE_%03d_V1" % target_units
	var scenario: Dictionary = _phase1_unit_scale_catalog_scenario(source_fixture_id, catalog_fixtures_by_id, catalog_common)
	if scenario.is_empty():
		return {}
	var fixture_id: String = "MOVING_UNIT_SCALE_%03d_V1" % target_units
	scenario["scenario_id"] = fixture_id
	scenario["fixture_id"] = fixture_id
	scenario["catalog_fixture_registered"] = false
	scenario["measurement_profile"] = "deterministic_windowed_presentation"
	scenario["systems"] = ["canonical_simrunner"]
	scenario["unit_count_policy"] = "bounded_moving"
	scenario["phase2_requires_three_repetitions"] = true
	scenario["baseline_candidate"] = false
	scenario["baseline_ineligible_reason"] = "phase2_moving_scale_diagnostic_not_yet_baseline_approved"
	scenario["performance_gating"] = false
	scenario["performance_gate_disposition"] = "DIAGNOSTIC_PENDING_BASELINE_REVIEW"
	var cadence: Dictionary = (scenario.get("cadence", {}) as Dictionary).duplicate(true)
	cadence["simulation_active"] = true
	scenario["cadence"] = cadence
	return scenario

func _phase2_hive_upgrade_storm_scenario() -> Dictionary:
	var scenario: Dictionary = _phase2_stress_scenario_base("HIVE_UPGRADE_STORM_V1", 7101)
	scenario["phase2_stress_profile"] = "hive_upgrade_storm"
	scenario["expected_command_count_exact"] = 12
	scenario["stress_target_hive_ids"] = [2, 4, 6, 8, 10, 12]
	var schedule: Array = []
	for pair_index in range(6):
		var src_id: int = (pair_index * 2) + 1
		var dst_id: int = src_id + 1
		schedule.append({"tick": 1, "kind": "exact_lane_intent", "src": src_id, "dst": dst_id, "intent": "feed"})
		schedule.append({"tick": 30, "kind": "exact_swarm_intent", "src": src_id, "dst": dst_id})
	scenario["command_schedule"] = schedule
	scenario["synthetic_descriptor"] = _phase2_hive_upgrade_storm_descriptor()
	scenario["expected_counts"] = {"hives": 13, "active_lanes": 0, "units": 0, "towers": 0, "barracks": 0, "structure_slots": 0, "walls": 0}
	return scenario

func _phase2_super_swarm_chain_scenario() -> Dictionary:
	var scenario: Dictionary = _phase2_stress_scenario_base("SUPER_SWARM_CHAIN_V1", 7201)
	scenario["phase2_stress_profile"] = "super_swarm_chain"
	scenario["expected_command_count_exact"] = 4
	scenario["command_schedule"] = [
		{"tick": 1, "kind": "exact_lane_intent", "src": 1, "dst": 2, "intent": "feed"},
		{"tick": 1, "kind": "exact_lane_intent", "src": 2, "dst": 3, "intent": "feed"},
		{"tick": 30, "kind": "exact_swarm_intent", "src": 1, "dst": 2},
		{"tick": 36, "kind": "exact_swarm_intent", "src": 2, "dst": 3}
	]
	scenario["synthetic_descriptor"] = _phase2_super_swarm_chain_descriptor()
	scenario["expected_counts"] = {"hives": 4, "active_lanes": 0, "units": 0, "towers": 0, "barracks": 0, "structure_slots": 0, "walls": 0}
	return scenario

func _phase2_stress_scenario_base(fixture_id: String, seed_value: int) -> Dictionary:
	var scenario: Dictionary = _scenario_def(
		fixture_id,
		"",
		8.0,
		seed_value,
		["canonical_simrunner", "swarm_system", "unit_system", "render_model"],
		0,
		0,
		1
	)
	scenario["fixture_id"] = fixture_id
	scenario["content_kind"] = "synthetic_scene"
	scenario["content_identity"] = "sf_perf:%s:v1" % fixture_id.to_lower()
	scenario["measurement_profile"] = "deterministic_windowed_presentation"
	scenario["camera_policy"] = "authored_scene_transform"
	scenario["phase2_requires_three_repetitions"] = true
	scenario["baseline_candidate"] = false
	scenario["baseline_ineligible_reason"] = "phase2_upgrade_swarm_stress_diagnostic_not_yet_baseline_approved"
	scenario["performance_gating"] = false
	scenario["performance_gate_disposition"] = "DIAGNOSTIC_PENDING_BASELINE_REVIEW"
	scenario["tick_count"] = 80
	scenario["warmup_ticks"] = 10
	scenario["repetitions"] = 3
	scenario["renderers"] = ["floor", "hive", "lane", "unit"]
	scenario["cadence"] = {
		"target_fps": 30,
		"simulation_hz": 10,
		"frames_per_simulation_tick": 3,
		"warmup_frames": 30,
		"measurement_frames": 210,
		"simulation_active": true
	}
	return scenario

func _phase2_hive_upgrade_storm_descriptor() -> Dictionary:
	var hives: Array = []
	var positions: Array = [
		[2, 5], [5, 5], [8, 5], [11, 5], [14, 5], [17, 5],
		[2, 15], [5, 15], [8, 15], [11, 15], [14, 15], [17, 15]
	]
	for index in range(positions.size()):
		var is_source: bool = index % 2 == 0
		var pair_index: int = int(index / 2)
		hives.append({
			"id": index + 1,
			"grid_pos": (positions[index] as Array).duplicate(),
			"owner_id": 1,
			"power": 30 if is_source else 7 if pair_index % 2 == 0 else 22,
			"kind": "Hive"
		})
	hives.append({"id": 13, "grid_pos": [10, 21], "owner_id": 2, "power": 5, "kind": "Hive"})
	return _phase2_synthetic_descriptor("HIVE_UPGRADE_STORM_V1", 20, 22, hives)

func _phase2_super_swarm_chain_descriptor() -> Dictionary:
	return _phase2_synthetic_descriptor("SUPER_SWARM_CHAIN_V1", 12, 20, [
		{"id": 1, "grid_pos": [2, 10], "owner_id": 1, "power": 30, "kind": "Hive"},
		{"id": 2, "grid_pos": [5, 10], "owner_id": 1, "power": 2, "kind": "Hive"},
		{"id": 3, "grid_pos": [8, 10], "owner_id": 1, "power": 2, "kind": "Hive"},
		{"id": 4, "grid_pos": [10, 3], "owner_id": 2, "power": 5, "kind": "Hive"}
	])

func _phase2_synthetic_descriptor(map_id: String, width: int, height: int, hives: Array) -> Dictionary:
	return {
		"_schema": "sf_perf_synthetic_scene_v1",
		"map_id": map_id,
		"grid": {"width": width, "height": height},
		"hives": hives.duplicate(true),
		"lane_candidates": [],
		"walls": [],
		"towers": [],
		"barracks": [],
		"structure_slots": [],
		"spawns": []
	}

func _phase2_battlefield_scenario_base(fixture_id: String, seed_value: int, map_path: String = MAP_STRESS) -> Dictionary:
	var scenario: Dictionary = _scenario_def(
		fixture_id,
		map_path,
		8.0,
		seed_value,
		["canonical_simrunner", "render_model"],
		0,
		0,
		1
	)
	scenario["fixture_id"] = fixture_id
	scenario["phase2_battlefield_profile"] = fixture_id.to_lower()
	scenario["measurement_profile"] = "deterministic_windowed_presentation"
	scenario["content_kind"] = "production_map"
	scenario["camera_policy"] = "production_map_fit"
	scenario["phase2_requires_three_repetitions"] = true
	scenario["baseline_candidate"] = false
	scenario["baseline_ineligible_reason"] = "phase2_battlefield_ui_stress_diagnostic_not_yet_baseline_approved"
	scenario["performance_gating"] = false
	scenario["performance_gate_disposition"] = "DIAGNOSTIC_PENDING_BASELINE_REVIEW"
	scenario["tick_count"] = 80
	scenario["warmup_ticks"] = 10
	scenario["repetitions"] = 3
	scenario["renderers"] = ["floor", "hive", "lane", "unit", "tower", "barracks", "wall", "polish"]
	scenario["cadence"] = {
		"target_fps": 30,
		"simulation_hz": 10,
		"frames_per_simulation_tick": 3,
		"warmup_frames": 30,
		"measurement_frames": 210,
		"simulation_active": true
	}
	return scenario

func _phase2_late_match_scenario() -> Dictionary:
	var scenario: Dictionary = _phase2_battlefield_scenario_base("LATE_MATCH_V1", 7301)
	scenario["initial_lanes"] = 8
	scenario["target_units"] = 200
	scenario["unit_count_policy"] = "bounded_moving"
	scenario["capacity_bypass_allowed"] = false
	scenario["expected_pool_capacity"] = 400
	scenario["expected_pool_expansions"] = 0
	scenario["lane_build_timeout_ms"] = 3000
	scenario["renderer_ready_timeout_ms"] = 3000
	scenario["expected_command_count_min"] = 8
	scenario["expected_counts"] = {"hives": 14, "active_lanes": 0, "units": 0, "towers": 0, "barracks": 0, "structure_slots": 2, "walls": 0}
	return scenario

func _phase2_lane_stress_scenario() -> Dictionary:
	var scenario: Dictionary = _phase2_battlefield_scenario_base("LANE_STRESS_V1", 7401)
	scenario["initial_lanes"] = 8
	scenario["expected_command_count_min"] = 8
	scenario["command_schedule"] = [
		{"tick": 20, "kind": "swarm_active_lane", "salt": 0},
		{"tick": 30, "kind": "swarm_active_lane", "salt": 1},
		{"tick": 40, "kind": "swarm_active_lane", "salt": 2},
		{"tick": 50, "kind": "swarm_active_lane", "salt": 3}
	]
	scenario["expected_counts"] = {"hives": 14, "active_lanes": 0, "units": 0, "towers": 0, "barracks": 0, "structure_slots": 2, "walls": 0}
	return scenario

func _phase2_structure_stress_scenario() -> Dictionary:
	var scenario: Dictionary = _phase2_battlefield_scenario_base("STRUCTURE_STRESS_V1", 7501, "")
	scenario["content_kind"] = "synthetic_scene"
	scenario["content_identity"] = "sf_perf:structure_stress_v1"
	scenario["camera_policy"] = "authored_scene_transform"
	scenario["initial_lanes"] = 4
	scenario["initial_barracks_routes"] = 2
	scenario["expected_command_count_min"] = 4
	var descriptor: Dictionary = _phase2_synthetic_descriptor("STRUCTURE_STRESS_V1", 18, 24, [
		{"id": 1, "grid_pos": [2, 3], "owner_id": 1, "power": 20, "kind": "Hive"},
		{"id": 2, "grid_pos": [6, 3], "owner_id": 1, "power": 20, "kind": "Hive"},
		{"id": 3, "grid_pos": [12, 3], "owner_id": 2, "power": 20, "kind": "Hive"},
		{"id": 4, "grid_pos": [16, 3], "owner_id": 2, "power": 20, "kind": "Hive"},
		{"id": 5, "grid_pos": [2, 20], "owner_id": 1, "power": 20, "kind": "Hive"},
		{"id": 6, "grid_pos": [6, 20], "owner_id": 1, "power": 20, "kind": "Hive"},
		{"id": 7, "grid_pos": [12, 20], "owner_id": 2, "power": 20, "kind": "Hive"},
		{"id": 8, "grid_pos": [16, 20], "owner_id": 2, "power": 20, "kind": "Hive"}
	])
	descriptor["towers"] = [
		{"id": 1, "x": 5, "y": 9, "control_hive_ids": [1, 2, 5], "owner_id": 1},
		{"id": 2, "x": 13, "y": 14, "control_hive_ids": [3, 4, 8], "owner_id": 2}
	]
	descriptor["barracks"] = [
		{"id": 1, "x": 5, "y": 14, "control_hive_ids": [1, 5, 6], "owner_id": 1},
		{"id": 2, "x": 13, "y": 9, "control_hive_ids": [3, 7, 8], "owner_id": 2}
	]
	scenario["synthetic_descriptor"] = descriptor
	scenario["expected_counts"] = {"hives": 8, "active_lanes": 0, "units": 0, "towers": 2, "barracks": 2, "structure_slots": 0, "walls": 0}
	return scenario

func _phase2_distress_storm_scenario() -> Dictionary:
	var scenario: Dictionary = _phase2_battlefield_scenario_base("DISTRESS_STORM_V1", 7601, "")
	scenario["content_kind"] = "synthetic_scene"
	scenario["content_identity"] = "sf_perf:distress_storm_v1"
	scenario["camera_policy"] = "authored_scene_transform"
	scenario["stress_target_hive_ids"] = [2, 4, 6, 8, 10, 12]
	scenario["expected_command_count_exact"] = 6
	var hives: Array = []
	var schedule: Array = []
	var pair_positions: Array = [[2, 2, 2, 20], [5, 2, 5, 20], [8, 2, 8, 20], [11, 2, 11, 20], [14, 2, 14, 20], [17, 2, 17, 20]]
	for pair_index in range(6):
		var src_id: int = pair_index * 2 + 1
		var dst_id: int = src_id + 1
		var pos: Array = pair_positions[pair_index] as Array
		hives.append({"id": src_id, "grid_pos": [pos[0], pos[1]], "owner_id": 2, "power": 30, "kind": "Hive"})
		hives.append({"id": dst_id, "grid_pos": [pos[2], pos[3]], "owner_id": 1, "power": 5, "kind": "Hive"})
		schedule.append({"tick": 1, "kind": "exact_lane_intent", "src": src_id, "dst": dst_id, "intent": "attack"})
	hives.append({"id": 13, "grid_pos": [28, 12], "owner_id": 1, "power": 5, "kind": "Hive"})
	scenario["command_schedule"] = schedule
	scenario["synthetic_descriptor"] = _phase2_synthetic_descriptor("DISTRESS_STORM_V1", 30, 24, hives)
	scenario["expected_counts"] = {"hives": 13, "active_lanes": 0, "units": 0, "towers": 0, "barracks": 0, "structure_slots": 0, "walls": 0}
	return scenario

func _phase2_capture_storm_scenario() -> Dictionary:
	var scenario: Dictionary = _phase2_battlefield_scenario_base("CAPTURE_STORM_V1", 7701, "")
	scenario["content_kind"] = "synthetic_scene"
	scenario["content_identity"] = "sf_perf:capture_storm_v1"
	scenario["camera_policy"] = "authored_scene_transform"
	scenario["stress_target_hive_ids"] = [2, 4, 6, 8, 10, 12]
	scenario["expected_command_count_exact"] = 6
	var hives: Array = []
	var schedule: Array = []
	var pair_positions: Array = [[2, 5, 5, 5], [8, 5, 11, 5], [14, 5, 17, 5], [2, 15, 5, 15], [8, 15, 11, 15], [14, 15, 17, 15]]
	for pair_index in range(6):
		var src_id: int = pair_index * 2 + 1
		var dst_id: int = src_id + 1
		var pos: Array = pair_positions[pair_index] as Array
		hives.append({"id": src_id, "grid_pos": [pos[0], pos[1]], "owner_id": 1, "power": 30, "kind": "Hive"})
		hives.append({"id": dst_id, "grid_pos": [pos[2], pos[3]], "owner_id": 0, "power": 1, "kind": "Hive"})
		schedule.append({"tick": 1, "kind": "exact_lane_intent", "src": src_id, "dst": dst_id, "intent": "attack"})
	hives.append({"id": 13, "grid_pos": [10, 21], "owner_id": 2, "power": 5, "kind": "Hive"})
	scenario["command_schedule"] = schedule
	scenario["synthetic_descriptor"] = _phase2_synthetic_descriptor("CAPTURE_STORM_V1", 20, 22, hives)
	scenario["expected_counts"] = {"hives": 13, "active_lanes": 0, "units": 0, "towers": 0, "barracks": 0, "structure_slots": 0, "walls": 0}
	return scenario

func _phase2_camera_stress_scenario() -> Dictionary:
	var scenario: Dictionary = _phase2_battlefield_scenario_base("CAMERA_STRESS_V1", 7801, MAP_PHASE1)
	scenario["cadence"] = {"target_fps": 30, "simulation_hz": 10, "frames_per_simulation_tick": 3, "warmup_frames": 30, "measurement_frames": 90, "simulation_active": false}
	scenario["camera_schedule"] = [
		{"frame": 10, "position": [180.0, 280.0], "zoom": [0.75, 0.75]},
		{"frame": 35, "position": [420.0, 560.0], "zoom": [1.20, 1.20]},
		{"frame": 60, "position": [280.0, 760.0], "zoom": [0.90, 0.90]},
		{"frame": 85, "position": [520.0, 320.0], "zoom": [1.10, 1.10]}
	]
	scenario["expected_counts"] = {"hives": 12, "active_lanes": 0, "units": 0, "towers": 0, "barracks": 0, "structure_slots": 0, "walls": 2}
	return scenario

func _phase2_ui_stress_scenario() -> Dictionary:
	var scenario: Dictionary = _phase2_battlefield_scenario_base("UI_STRESS_V1", 7901, MAP_PHASE1)
	scenario["cadence"] = {"target_fps": 30, "simulation_hz": 10, "frames_per_simulation_tick": 3, "warmup_frames": 30, "measurement_frames": 90, "simulation_active": false}
	scenario["ui_schedule"] = [
		{"frame": 10, "path": "UI/SelectionHud", "visible": true},
		{"frame": 30, "path": "UI/SelectionHud", "visible": false},
		{"frame": 50, "path": "UI/MissNOutBanner", "visible": true},
		{"frame": 70, "path": "UI/MissNOutBanner", "visible": false},
		{"frame": 90, "path": "HudOverlayLayer/HudOverlay", "visible": false},
		{"frame": 110, "path": "HudOverlayLayer/HudOverlay", "visible": true}
	]
	scenario["expected_counts"] = {"hives": 12, "active_lanes": 0, "units": 0, "towers": 0, "barracks": 0, "structure_slots": 0, "walls": 2}
	return scenario

func _phase2_lifecycle_soak_scenario() -> Dictionary:
	var scenario: Dictionary = _scenario_def(
		"LIFECYCLE_SOAK_V1",
		MAP_STRESS,
		4.0,
		8101,
		["canonical_simrunner", "unit_system", "render_model"],
		4,
		0,
		1
	)
	scenario["fixture_id"] = "LIFECYCLE_SOAK_V1"
	scenario["phase2_lifecycle_profile"] = "bounded_setup_run_cleanup_v1"
	scenario["measurement_profile"] = "deterministic_windowed_presentation"
	scenario["content_kind"] = "production_map"
	scenario["camera_policy"] = "production_map_fit"
	scenario["phase2_requires_three_repetitions"] = true
	scenario["lifecycle_required_cycles"] = 8
	scenario["repetitions"] = 8
	scenario["baseline_candidate"] = false
	scenario["baseline_ineligible_reason"] = "phase2_lifecycle_soak_correctness_evidence_not_timing_baseline"
	scenario["performance_gating"] = false
	scenario["performance_gate_disposition"] = "DIAGNOSTIC_LIFECYCLE_ONLY"
	scenario["target_units"] = 100
	scenario["unit_count_policy"] = "bounded_moving"
	scenario["capacity_bypass_allowed"] = false
	scenario["expected_pool_capacity"] = 400
	scenario["expected_pool_expansions"] = 0
	scenario["lane_build_timeout_ms"] = 3000
	scenario["renderer_ready_timeout_ms"] = 3000
	scenario["tick_count"] = 40
	scenario["warmup_ticks"] = 10
	scenario["expected_command_count_min"] = 4
	scenario["expected_counts"] = {"hives": 14, "active_lanes": 0, "units": 0, "towers": 0, "barracks": 0, "structure_slots": 2, "walls": 0}
	scenario["cadence"] = {
		"target_fps": 30,
		"simulation_hz": 10,
		"frames_per_simulation_tick": 3,
		"warmup_frames": 30,
		"measurement_frames": 90,
		"simulation_active": true
	}
	scenario["lifecycle_limits"] = {
		"node_growth": 2,
		"orphan_node_count": 0,
		"object_growth": 64,
		"resource_growth": 32,
		"static_memory_growth_bytes": 33554432,
		"report_payload_bytes": 1048576
	}
	return scenario

func _phase2_feature_isolation_scenario(variant: String) -> Dictionary:
	var normalized: String = variant.strip_edges().to_lower()
	var comparison_mode: String = {
		"off": "baseline",
		"production": "settings",
		"exaggerated": "tower_150"
	}.get(normalized, "")
	var fixture_id: String = "ARENA_POLISH_%s_V1" % normalized.to_upper()
	var scenario: Dictionary = _scenario_def(
		fixture_id,
		MAP_PHASE1,
		4.0,
		8201,
		[],
		0,
		0,
		1
	)
	scenario["fixture_id"] = fixture_id
	scenario["feature_id"] = "arena_polish_bundle"
	scenario["feature_variant"] = normalized
	scenario["feature_control_value"] = comparison_mode
	scenario["measurement_profile"] = "static_windowed_deterministic"
	scenario["content_kind"] = "production_map"
	scenario["camera_policy"] = "production_map_fit"
	scenario["phase2_requires_three_repetitions"] = true
	scenario["repetitions"] = 3
	scenario["baseline_candidate"] = false
	scenario["baseline_ineligible_reason"] = "phase2_feature_isolation_diagnostic_not_baseline_package"
	scenario["performance_gating"] = false
	scenario["performance_gate_disposition"] = "DIAGNOSTIC_FEATURE_COMPARISON"
	scenario["runtime_switches"] = {
		"arena_polish_comparison_mode": comparison_mode,
		"premium_polish_enabled": false,
		"tower_visual_scale": 1.0
	}
	scenario["expected_counts"] = {"hives": 12, "active_lanes": 0, "units": 0, "towers": 0, "barracks": 0, "structure_slots": 0, "walls": 2}
	scenario["cadence"] = {
		"target_fps": 30,
		"simulation_hz": 10,
		"frames_per_simulation_tick": 3,
		"warmup_frames": 30,
		"measurement_frames": 90,
		"simulation_active": false
	}
	return scenario

func _phase0_collector_calibration_scenarios() -> Array:
	var base: Dictionary = _phase0_integrity_scenario()
	base["scenario_id"] = "PHASE0_COLLECTOR_CALIBRATION_V1"
	base["repetitions"] = 1
	var order: Array[String] = [
		"OFF", "MINIMAL", "FULL",
		"FULL", "OFF", "MINIMAL",
		"MINIMAL", "FULL", "OFF"
	]
	var scenarios: Array = []
	for sequence_index in range(order.size()):
		var scenario: Dictionary = base.duplicate(true)
		scenario["_collection_level_override"] = order[sequence_index]
		scenario["calibration_sequence_index"] = sequence_index + 1
		scenarios.append(scenario)
	return scenarios

func _phase0_isolation_sentinel_scenario() -> Dictionary:
	var scenario: Dictionary = _scenario_def(
		"PHASE0_ISOLATION_SENTINEL_V1",
		MAP_QUICK,
		3.0,
		4101,
		["canonical_simrunner"],
		4,
		0,
		1
	)
	scenario["tick_count"] = 30
	scenario["warmup_ticks"] = 5
	scenario["expected_command_count_min"] = 7
	scenario["expected_command_types"] = ["attack", "swarm"]
	scenario["command_schedule"] = [
		{"tick": 5, "kind": "lane_intent_pair", "pair_index": 4, "intent": "attack"},
		{"tick": 15, "kind": "swarm_active_lane", "salt": 0},
		{"tick": 25, "kind": "lane_intent_pair", "pair_index": 5, "intent": "attack"}
	]
	return scenario

func _phase0_isolation_mutator_scenario() -> Dictionary:
	var scenario: Dictionary = _scenario_def(
		"PHASE0_ISOLATION_MUTATOR_V1",
		MAP_QUICK,
		3.0,
		5201,
		["canonical_simrunner"],
		6,
		0,
		1
	)
	scenario["tick_count"] = 30
	scenario["warmup_ticks"] = 5
	scenario["expected_command_count_min"] = 8
	scenario["expected_command_types"] = ["attack", "swarm"]
	scenario["runtime_switches"] = {
		"arena_polish_comparison_mode": "tower_150",
		"premium_polish_enabled": true,
		"tower_visual_scale": 1.5
	}
	scenario["command_schedule"] = [
		{"tick": 5, "kind": "lane_intent_pair", "pair_index": 7, "intent": "attack"},
		{"tick": 15, "kind": "swarm_active_lane", "salt": 1}
	]
	return scenario

func _stress_scenario() -> Dictionary:
	var scenario: Dictionary = _scenario_def(
		"stress_30s",
		MAP_STRESS,
		30.0,
		5191,
		_full_stack_systems(),
		24,
		6,
		8,
		4
	)
	scenario["allowed_failure"] = true
	scenario["command_interval_ticks"] = 2
	scenario["runtime_switches"] = {
		"arena_polish_comparison_mode": "tower_150",
		"premium_polish_enabled": true,
		"tower_visual_scale": 1.5
	}
	return scenario

func _full_stack_systems() -> Array:
	return [
		"ops_events",
		"bot_system",
		"lane_flow",
		"edge_cache",
		"swarm_system",
		"unit_system",
		"structure_control",
		"tower_system",
		"barracks_system",
		"render_model"
	]

func _apply_runtime_switch_overrides(scenario_def: Dictionary, switch_overrides: Dictionary) -> void:
	if switch_overrides.is_empty():
		return
	var switches: Dictionary = scenario_def.get("runtime_switches", {}) as Dictionary
	for key_any in switch_overrides.keys():
		switches[str(key_any)] = switch_overrides[key_any]
	scenario_def["runtime_switches"] = switches

func _validate_switch_overrides(switch_overrides: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key_any in switch_overrides.keys():
		var key: String = str(key_any)
		var value: Variant = switch_overrides.get(key_any)
		match key:
			"arena_polish_comparison_mode":
				if not (value is String) or not ARENA_POLISH_LAYER.comparison_modes().has(str(value)):
					errors.append("arena_polish_comparison_mode is unsupported")
			"premium_polish_enabled":
				if typeof(value) != TYPE_BOOL:
					errors.append("premium_polish_enabled must be boolean")
			"tower_visual_scale":
				if not (value is int or value is float) or float(value) < 1.0 or float(value) > 1.5:
					errors.append("tower_visual_scale must be between 1.0 and 1.5")
			_:
				errors.append("feature switch is not registered: %s" % key)
	return errors

func _enabled_system_lookup(scenario_def: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for system_any in scenario_def.get("systems", []) as Array:
		out[str(system_any)] = true
	return out

func _candidate_attack_pairs(state: GameState) -> Array:
	var hives: Array = state.hives.duplicate()
	var pairs: Array = []
	for src_any in hives:
		var src: HiveData = src_any as HiveData
		if src == null or int(src.owner_id) <= 0:
			continue
		for dst_any in hives:
			var dst: HiveData = dst_any as HiveData
			if dst == null or int(dst.id) == int(src.id):
				continue
			if not state.can_connect(int(src.id), int(dst.id)):
				continue
			pairs.append({
				"src": int(src.id),
				"dst": int(dst.id),
				"friendly": int(src.owner_id) == int(dst.owner_id) and int(dst.owner_id) > 0,
				"dist2": _grid_distance_squared(src.grid_pos, dst.grid_pos)
			})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var af := bool(a.get("friendly", false))
		var bf := bool(b.get("friendly", false))
		if af != bf:
			return not af
		var ad: float = float(a.get("dist2", 0.0))
		var bd: float = float(b.get("dist2", 0.0))
		if not is_equal_approx(ad, bd):
			return ad < bd
		var asrc: int = int(a.get("src", -1))
		var bsrc: int = int(b.get("src", -1))
		if asrc != bsrc:
			return asrc < bsrc
		return int(a.get("dst", -1)) < int(b.get("dst", -1))
	)
	return pairs

func _grid_distance_squared(a: Vector2i, b: Vector2i) -> int:
	var dx := int(a.x - b.x)
	var dy := int(a.y - b.y)
	return dx * dx + dy * dy

func _issue_swarm_on_active_lane(state: GameState, salt: int) -> Dictionary:
	if state == null or state.lanes.is_empty():
		return {"ok": false, "type": "swarm"}
	var candidates: Array = []
	for lane_any in state.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		if bool(lane.send_a):
			candidates.append({"src": int(lane.a_id), "dst": int(lane.b_id)})
		if bool(lane.send_b):
			candidates.append({"src": int(lane.b_id), "dst": int(lane.a_id)})
	if candidates.is_empty():
		return {"ok": false, "type": "swarm"}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var asrc: int = int(a.get("src", -1))
		var bsrc: int = int(b.get("src", -1))
		if asrc != bsrc:
			return asrc < bsrc
		return int(a.get("dst", -1)) < int(b.get("dst", -1))
	)
	var pair: Dictionary = candidates[abs(salt) % candidates.size()] as Dictionary
	var result: Dictionary = OpsState.apply_lane_intent(int(pair.get("src", -1)), int(pair.get("dst", -1)), "swarm")
	return {"ok": bool(result.get("ok", false)), "type": "swarm", "src": pair.get("src", -1), "dst": pair.get("dst", -1)}

func _seed_barracks_routes(state: GameState, route_count: int) -> void:
	var seeded := 0
	for barracks_any in state.barracks:
		if seeded >= route_count:
			return
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var barracks: Dictionary = barracks_any as Dictionary
		var owner_id := int(barracks.get("owner_id", 0))
		if owner_id <= 0:
			continue
		var route_ids: Array = []
		for hive_id_any in barracks.get("control_hive_ids", []) as Array:
			var hive: HiveData = state.find_hive_by_id(int(hive_id_any))
			if hive != null and int(hive.owner_id) == owner_id:
				route_ids.append(int(hive.id))
		if route_ids.is_empty():
			continue
		if OpsState.request_barracks_route(int(barracks.get("id", -1)), route_ids, owner_id):
			seeded += 1

func _apply_render_isolation(arena: Node, scenario_def: Dictionary) -> void:
	var renderers: Array = scenario_def.get("renderers", []) as Array
	if renderers.is_empty():
		return
	var allowed: Dictionary = {}
	for renderer_any in renderers:
		allowed[str(renderer_any)] = true
	var paths := {
		"floor": ["MapRoot/FloorRenderer"],
		"hive": ["MapRoot/HiveRenderer"],
		"lane": ["MapRoot/LaneRenderer"],
		"unit": ["PoolsRoot/UnitRenderer"],
		"tower": ["MapRoot/TowerRenderer", "MapRoot/TowerGroundGlowRenderer"],
		"wall": ["WallRenderer"],
		"barracks": ["MapRoot/BarracksRenderer", "MapRoot/BarracksGroundGlowRenderer"],
		"polish": ["MapRoot/ArenaPolishLayer"]
	}
	for key_any in paths.keys():
		var key := str(key_any)
		for path_any in paths.get(key_any, []) as Array:
			var node: Node = arena.get_node_or_null(str(path_any))
			if not (node is CanvasItem):
				continue
			if key == "polish" and bool(allowed.get(key, false)):
				continue
			(node as CanvasItem).visible = bool(allowed.get(key, false))

func _settle_windowed_camera(arena: Node, camera_policy: String) -> Dictionary:
	if arena == null:
		return {"pass": false, "reason": "arena_missing", "identity": {}, "hash": ""}
	if camera_policy == "production_map_fit":
		if not arena.has_method("apply_camera_fit_next_frame"):
			return {"pass": false, "reason": "production_camera_fit_missing", "identity": {}, "hash": ""}
		arena.call("apply_camera_fit_next_frame", "fitcam_once")
		for _frame in range(4):
			await process_frame
	var first: Dictionary = _windowed_camera_identity(arena, camera_policy)
	await process_frame
	var second: Dictionary = _windowed_camera_identity(arena, camera_policy)
	var first_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(first) if not first.is_empty() else ""
	var second_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(second) if not second.is_empty() else ""
	return {
		"pass": not first_hash.is_empty() and first_hash == second_hash and bool(second.get("is_current", false)),
		"policy": camera_policy,
		"settle_frames": 5 if camera_policy == "production_map_fit" else 1,
		"consecutive_hashes": [first_hash, second_hash],
		"identity": second,
		"hash": second_hash,
		"reason": "" if first_hash == second_hash else "camera_transform_changed_after_settle"
	}

func _windowed_camera_identity(arena: Node, camera_policy: String) -> Dictionary:
	var camera_node: Camera2D = arena.get_node_or_null("Camera2D") as Camera2D
	if camera_node == null:
		return {}
	var viewport: Viewport = camera_node.get_viewport()
	var viewport_size: Vector2i = viewport.get_visible_rect().size if viewport != null else Vector2i.ZERO
	return {
		"identity_version": 1,
		"policy": camera_policy,
		"node_path": str(arena.get_path_to(camera_node)),
		"is_current": viewport != null and viewport.get_camera_2d() == camera_node,
		"global_position": [_quantized_float(camera_node.global_position.x), _quantized_float(camera_node.global_position.y)],
		"zoom": [_quantized_float(camera_node.zoom.x), _quantized_float(camera_node.zoom.y)],
		"rotation_radians": _quantized_float(camera_node.global_rotation),
		"offset": [_quantized_float(camera_node.offset.x), _quantized_float(camera_node.offset.y)],
		"anchor_mode": int(camera_node.anchor_mode),
		"ignore_rotation": camera_node.ignore_rotation,
		"position_smoothing_enabled": camera_node.position_smoothing_enabled,
		"viewport_width": viewport_size.x,
		"viewport_height": viewport_size.y
	}

func _quantized_float(value: float) -> float:
	return snappedf(value, 0.000001)

func _capture_render_monitor_peaks(peaks: Dictionary) -> void:
	peaks["draw_calls"] = maxi(int(peaks.get("draw_calls", 0)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	peaks["rendered_objects"] = maxi(int(peaks.get("rendered_objects", 0)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	peaks["rendered_primitives"] = maxi(int(peaks.get("rendered_primitives", 0)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))

func _renderer_configuration_state(arena: Node) -> Dictionary:
	var state: Dictionary = {}
	if arena == null:
		return state
	var renderer_paths := {
		"floor_visible": "MapRoot/FloorRenderer",
		"hive_visible": "MapRoot/HiveRenderer",
		"lane_visible": "MapRoot/LaneRenderer",
		"unit_visible": "PoolsRoot/UnitRenderer",
		"tower_visible": "MapRoot/TowerRenderer",
		"tower_ground_glow_visible": "MapRoot/TowerGroundGlowRenderer",
		"wall_visible": "WallRenderer",
		"barracks_visible": "MapRoot/BarracksRenderer",
		"barracks_ground_glow_visible": "MapRoot/BarracksGroundGlowRenderer",
		"polish_visible": "MapRoot/ArenaPolishLayer"
	}
	for key_any in renderer_paths.keys():
		var node: Node = arena.get_node_or_null(str(renderer_paths[key_any]))
		state[str(key_any)] = bool(node is CanvasItem and (node as CanvasItem).visible)
	state["arena_polish_comparison_mode"] = ARENA_POLISH_LAYER.comparison_mode()
	state["arena_polish_enabled"] = ARENA_POLISH_LAYER.is_polish_enabled()
	state["arena_polish_tower_visual_scale"] = ARENA_POLISH_LAYER.tower_visual_scale()
	return state

func _base_scenario_report(scenario_def: Dictionary, benchmark_mode: String, gates: Dictionary) -> Dictionary:
	var fixture_id: String = str(scenario_def.get("fixture_id", scenario_def.get("scenario_id", "unknown")))
	var map_content_hash: String = str(scenario_def.get("_preflight_map_content_hash", ""))
	return {
		"scenario_id": str(scenario_def.get("scenario_id", "unknown")),
		"fixture_id": fixture_id,
		"fixture_version": int(scenario_def.get("fixture_version", 1)),
		"catalog_fixture_registered": bool(scenario_def.get("catalog_fixture_registered", false)),
		"phase2_requires_three_repetitions": bool(scenario_def.get("phase2_requires_three_repetitions", false)),
		"phase2_stress_profile": str(scenario_def.get("phase2_stress_profile", "")),
		"phase2_battlefield_profile": str(scenario_def.get("phase2_battlefield_profile", "")),
		"feature_id": str(scenario_def.get("feature_id", "")),
		"feature_variant": str(scenario_def.get("feature_variant", "")),
		"feature_control_value": scenario_def.get("feature_control_value"),
		"stress_target_hive_ids": (scenario_def.get("stress_target_hive_ids", []) as Array).duplicate(),
		"measurement_profile": str(scenario_def.get("measurement_profile", _measurement_profile_for_benchmark_mode(benchmark_mode))),
		"content_kind": str(scenario_def.get("content_kind", "production_map")),
		"content_identity": str(scenario_def.get("content_identity", "sha256:%s" % map_content_hash)),
		"fixture_config_hash": str(scenario_def.get("_fixture_config_hash", "")),
		"repetition_index": int(scenario_def.get("_repetition_index", 1)),
		"suite_sequence_index": int(scenario_def.get("_suite_sequence_index", 1)),
		"benchmark_mode": benchmark_mode,
		"collection_level": str(scenario_def.get("_collection_level", PERF_RESULT_CONTRACT.COLLECTION_LEVEL_MINIMAL)),
		"calibration_sequence_index": int(scenario_def.get("calibration_sequence_index", 0)),
		"requested_seed": int(scenario_def.get("seed", 0)),
		"effective_seed": int(scenario_def.get("seed", 0)),
		"map_path": str(scenario_def.get("map_path", "")),
		"map_content_hash": map_content_hash,
		"systems": (scenario_def.get("systems", []) as Array).duplicate(true),
		"runtime_switches": (scenario_def.get("runtime_switches", {}) as Dictionary).duplicate(true),
		"renderers": (scenario_def.get("renderers", []) as Array).duplicate(true),
		"allowed_failure": bool(scenario_def.get("allowed_failure", false)),
		"target_frame_ms": float(gates.get("target_frame_ms", 0.0)),
		"scripted_command_count": 0,
		"command_schedule_hash": PERF_DETERMINISTIC_HASH.hash_variant((scenario_def.get("command_schedule", []) as Array).duplicate(true)),
		"warmup_duration_sec": 0.0,
		"measurement_duration_sec": 0.0
	}

func _invalid_suite_report(suite_id: String, benchmark_mode: String, reason: String, errors: Variant, args: Dictionary) -> Dictionary:
	var report := {
		"report_type": "sf_perf_benchmark_suite",
		"result_schema_version": PERF_RESULT_CONTRACT.RESULT_SCHEMA_VERSION,
		"run_status": "INVALID",
		"integrity_status": "FAIL",
		"suite_id": suite_id,
		"benchmark_mode": benchmark_mode,
		"collection_level": PERF_RESULT_CONTRACT.normalize_collection_level(str(args.get("collection_level", PERF_RESULT_CONTRACT.COLLECTION_LEVEL_MINIMAL))),
		"generated_at_unix": Time.get_unix_time_from_system(),
		"git": _git_metadata(),
		"godot": Engine.get_version_info(),
		"machine": _machine_metadata(),
		"fixture_catalog": (args.get("_fixture_catalog_identity", {}) as Dictionary).duplicate(true),
		"feature_registry": (args.get("_feature_registry_identity", {}) as Dictionary).duplicate(true),
		"gate_source": str(args.get("gates", DEFAULT_GATES_PATH)),
		"scenario_count": 0,
		"scenarios": [],
		"pass": false,
		"failure_reason": reason,
		"errors": errors
	}
	report.merge(_result_environment({}), true)
	_apply_result_contract(report)
	return report

func _scenario_error(scenario_def: Dictionary, benchmark_mode: String, reason: String, gates: Dictionary) -> Dictionary:
	var report := _base_scenario_report(scenario_def, benchmark_mode, gates)
	var failed_collection := PERF_METRICS_COLLECTOR.new(
		str(scenario_def.get("_collection_level", PERF_RESULT_CONTRACT.COLLECTION_LEVEL_MINIMAL)),
		int(gates.get("worst_frame_limit", 10)),
		float(gates.get("target_frame_ms", INF))
	).summary()
	report.merge({
		"duration_sec": 0.0,
		"frame_count": 0,
		"measured_frame_count": 0,
		"average_frame_ms": 0.0,
		"median_frame_ms": 0.0,
		"p95_frame_ms": 0.0,
		"p99_frame_ms": 0.0,
		"p999_frame_ms": 0.0,
		"max_frame_ms": 0.0,
		"hitch_threshold_ms": float(gates.get("target_frame_ms", 0.0)),
		"hitch_count": 0,
		"hitches": [],
		"worst_frames": [],
		"worst_sim_ticks": [],
		"collection": failed_collection,
		"pass": false,
		"failed_gates": [{"gate": "scenario_setup", "actual": reason, "limit": "ready"}]
	}, true)
	return report

func _match_summary(state: GameState, tick_index: int) -> Dictionary:
	var units_count := 0
	if state != null and state.units_by_lane.has("_all"):
		var units: Array = state.units_by_lane.get("_all", []) as Array
		units_count = units.size()
	return {
		"final_tick": tick_index,
		"status": str(OpsState.match_phase),
		"winner_id": int(OpsState.winner_id),
		"hive_count": state.hives.size() if state != null else 0,
		"lane_count": state.lanes.size() if state != null else 0,
		"barracks_count": state.barracks.size() if state != null else 0,
		"tower_count": state.towers.size() if state != null else 0,
		"unit_count": units_count
	}

func _scripted_command_count_from_log(command_log: Array) -> int:
	var count := 0
	for entry_any in command_log:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var commands: Array = entry.get("commands", []) as Array
		count += commands.size()
	return count

func _flatten_command_log(command_log: Array) -> Array:
	var out: Array = []
	for entry_any in command_log:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var tick: int = int(entry.get("tick", 0))
		for command_any in entry.get("commands", []) as Array:
			if typeof(command_any) != TYPE_DICTIONARY:
				continue
			var command: Dictionary = command_any as Dictionary
			out.append({
				"tick": tick,
				"type": str(command.get("type", "")),
				"src": int(command.get("src", -1)),
				"dst": int(command.get("dst", -1)),
				"schedule_index": int(command.get("schedule_index", -1))
			})
	return out

func _command_types_from_log(command_log: Array) -> Array[String]:
	var seen: Dictionary = {}
	for entry_any in command_log:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		for command_any in (entry_any as Dictionary).get("commands", []) as Array:
			if typeof(command_any) != TYPE_DICTIONARY:
				continue
			var command_type: String = str((command_any as Dictionary).get("type", ""))
			if not command_type.is_empty():
				seen[command_type] = true
	var out: Array[String] = []
	for key_any in seen.keys():
		out.append(str(key_any))
	out.sort()
	return out

func _classification_for_frame(frame_ms: float, gates: Dictionary, sim_sections: Dictionary) -> String:
	if frame_ms <= float(gates.get("target_frame_ms", 0.0)):
		return "normal_frame"
	var sim_total := float(sim_sections.get("total_ms", 0.0))
	if sim_total > 1.0:
		return "sim_work"
	return "frame_pacing_or_unattributed"

func _collector_frame_metrics(collection: Dictionary) -> Dictionary:
	return {
		"average_frame_ms": collection.get("average_ms"),
		"median_frame_ms": collection.get("median_ms"),
		"p95_frame_ms": collection.get("p95_ms"),
		"p99_frame_ms": collection.get("p99_ms"),
		"p999_frame_ms": collection.get("p999_ms"),
		"max_frame_ms": collection.get("max_ms")
	}

func _frame_worst_records(records: Array) -> Array:
	var out: Array = []
	for record_any in records:
		var record: Dictionary = record_any as Dictionary
		out.append({
			"frame": int(record.get("sample_index", 0)),
			"duration_ms": float(record.get("duration_ms", 0.0))
		})
	return out

func _canonical_worst_records(records: Array) -> Array:
	var out: Array = []
	for record_any in records:
		var record: Dictionary = record_any as Dictionary
		var context: Dictionary = record.get("context", {}) as Dictionary
		var sections: Dictionary = context.get("phase_times_ms", {}) as Dictionary
		out.append({
			"tick": int(record.get("sample_index", 0)),
			"total_ms": float(record.get("duration_ms", 0.0)),
			"top_sim_sections": _top_sections(sections, 5)
		})
	return out

func _collector_hitch_records(records: Array) -> Array:
	var out: Array = []
	for record_any in records:
		var record: Dictionary = record_any as Dictionary
		var context: Dictionary = record.get("context", {}) as Dictionary
		var sim_sections: Dictionary = context.get("sim_sections", {}) as Dictionary
		out.append({
			"frame": int(record.get("sample_index", 0)),
			"tick": int(context.get("tick", 0)),
			"duration_ms": float(record.get("duration_ms", 0.0)),
			"phase": str(context.get("phase", "")),
			"classification": str(context.get("classification", "")),
			"top_sim_sections": _top_sections(sim_sections, 5),
			"renderer_configuration_state": (context.get("renderer_configuration_state", {}) as Dictionary).duplicate(true)
		})
	return out

func _failed_gates(metrics: Dictionary, hitch_count: int, gates: Dictionary) -> Array:
	var failed: Array = []
	if float(metrics.get("average_frame_ms", 0.0)) > float(gates.get("target_frame_ms", 0.0)):
		failed.append({"gate": "average_frame_ms", "actual": metrics.get("average_frame_ms", 0.0), "limit": gates.get("target_frame_ms", 0.0)})
	if gates.has("p95_max_ms") and float(metrics.get("p95_frame_ms", 0.0)) > float(gates.get("p95_max_ms")):
		failed.append({"gate": "p95_frame_ms", "actual": metrics.get("p95_frame_ms", 0.0), "limit": gates.get("p95_max_ms")})
	if float(metrics.get("p99_frame_ms", 0.0)) > float(gates.get("p99_max_ms", 0.0)):
		failed.append({"gate": "p99_frame_ms", "actual": metrics.get("p99_frame_ms", 0.0), "limit": gates.get("p99_max_ms", 0.0)})
	if float(metrics.get("max_frame_ms", 0.0)) > float(gates.get("max_frame_ms", 0.0)):
		failed.append({"gate": "max_frame_ms", "actual": metrics.get("max_frame_ms", 0.0), "limit": gates.get("max_frame_ms", 0.0)})
	if hitch_count > int(gates.get("max_hitches", 0)):
		failed.append({"gate": "hitch_count", "actual": hitch_count, "limit": gates.get("max_hitches", 0)})
	return failed

func _top_sections(sections: Dictionary, limit: int) -> Array:
	var out: Array = []
	for key_any in sections.keys():
		var key := str(key_any)
		if not _is_timing_section_key(key):
			continue
		var value := float(sections[key_any])
		if value <= 0.0:
			continue
		out.append({"section": key, "ms": value})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("ms", 0.0)) > float(b.get("ms", 0.0))
	)
	return out.slice(0, mini(limit, out.size()))

func _is_timing_section_key(key: String) -> bool:
	return key == "total_ms" or key.ends_with("_ms") or key.ends_with("_system") or key in [
		"ops_events",
		"bot_system",
		"lane_flow",
		"edge_cache",
		"swarm_system",
		"unit_system",
		"structure_control",
		"tower_system",
		"barracks_system",
		"render_model"
	]

func _timed_section(out: Dictionary, label: String, callback: Callable) -> void:
	var start_usec := Time.get_ticks_usec()
	callback.call()
	out[label] = float(Time.get_ticks_usec() - start_usec) / 1000.0

func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value_any in values:
		total += float(value_any)
	return total / float(values.size())

func _max(values: Array) -> float:
	var out := 0.0
	for value_any in values:
		out = maxf(out, float(value_any))
	return out

func _percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var index: int = clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return float(sorted[index])

func _sum_values(values: Dictionary) -> float:
	var total := 0.0
	for key_any in values.keys():
		var value: Variant = values[key_any]
		if value is int or value is float:
			total += float(value)
	return total

func _find_arena(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	if scene_root.name == "Arena":
		return scene_root
	var direct: Node = scene_root.get_node_or_null("WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")
	if direct != null:
		return direct
	return scene_root.find_child("Arena", true, false)

func _arena_sim_runner(arena: Node) -> Node:
	if arena == null:
		return null
	var direct: Node = arena.get_node_or_null("SimRunner")
	if direct != null:
		return direct
	var value: Variant = arena.get("sim_runner") if "sim_runner" in arena else null
	return value as Node

func _teardown_node(node: Node) -> void:
	if node == null:
		return
	node.queue_free()

func _finalize_scenario(
	report: Dictionary,
	isolation_snapshot: Dictionary,
	scene_root: Node,
	arena: Node
) -> Dictionary:
	var cleanup: Dictionary = await _cleanup_repetition(isolation_snapshot, scene_root, arena)
	var lifecycle_profile: String = str(report.get("phase2_lifecycle_profile", ""))
	if not lifecycle_profile.is_empty():
		var runtime_after_cleanup: Dictionary = _runtime_counter_snapshot()
		cleanup["runtime_after_cleanup"] = runtime_after_cleanup
		report["lifecycle_runtime_after_cleanup"] = runtime_after_cleanup
		report["lifecycle_interrupted_cleanup_contract"] = {
			"armed_before_setup": true,
			"synchronous_recovery_handler": "_finalize->_recover_interrupted_repetition",
			"fixture_state_release": true,
			"protected_state_restore": true
		}
	_disarm_interrupted_cleanup()
	report["isolation_cleanup"] = cleanup
	if not bool(cleanup.get("pass", false)):
		report["pass"] = false
		var integrity_failures: Array = (report.get("integrity_failures", []) as Array).duplicate()
		if not integrity_failures.has("isolation_restore_failed"):
			integrity_failures.append("isolation_restore_failed")
		report["integrity_failures"] = integrity_failures
		var failed_gates: Array = (report.get("failed_gates", []) as Array).duplicate(true)
		failed_gates.append({
			"gate": "scenario_isolation",
			"actual": (cleanup.get("mismatches", []) as Array).duplicate(),
			"limit": "exact_pre_scenario_state"
		})
		report["failed_gates"] = failed_gates
	if not lifecycle_profile.is_empty():
		report["lifecycle_report_payload_bytes"] = JSON.stringify(report).to_utf8_buffer().size()
	return report

func _runtime_counter_snapshot() -> Dictionary:
	return {
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"static_memory_peak_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
		"root_child_count": root.get_child_count() if root != null else -1
	}

func _cleanup_repetition(isolation_snapshot: Dictionary, scene_root: Node, arena: Node) -> Dictionary:
	if arena != null and is_instance_valid(arena) and arena.has_method("clear_perf_match_seed_override"):
		arena.call("clear_perf_match_seed_override")
	if OpsState != null and OpsState.has_method("set_match_telemetry_collector"):
		OpsState.call("set_match_telemetry_collector", null)
	if scene_root != null and is_instance_valid(scene_root):
		scene_root.process_mode = Node.PROCESS_MODE_DISABLED
		if not scene_root.is_queued_for_deletion():
			scene_root.queue_free()
	_queue_fixture_root_additions(isolation_snapshot)
	for _frame in range(3):
		await process_frame
	var node_freed: bool = scene_root == null or not is_instance_valid(scene_root)
	var fixture_state_release: Dictionary = PERF_ISOLATION_GUARD.release_fixture_state(isolation_snapshot, OpsState)
	var restore_result: Dictionary = PERF_ISOLATION_GUARD.restore(isolation_snapshot, self, OpsState)
	for _frame in range(2):
		await process_frame
	var settled_result: Dictionary = PERF_ISOLATION_GUARD.verify(isolation_snapshot, self, OpsState)
	var mismatches: Array = []
	for source_any in [restore_result.get("mismatches", []), settled_result.get("mismatches", [])]:
		for mismatch_any in source_any as Array:
			var mismatch: String = str(mismatch_any)
			if not mismatches.has(mismatch):
				mismatches.append(mismatch)
	if not node_freed:
		mismatches.append("fixture_root_not_freed")
	return {
		"pass": mismatches.is_empty(),
		"before_hash": str(isolation_snapshot.get("before_hash", "")),
		"after_hash": str(settled_result.get("after_hash", "")),
		"before_protected_state_hash": str(settled_result.get("before_protected_state_hash", "")),
		"after_protected_state_hash": str(settled_result.get("after_protected_state_hash", "")),
		"before_protected_state": settled_result.get("before_protected_state", {}),
		"after_protected_state": settled_result.get("after_protected_state", {}),
		"mismatches": mismatches,
		"mismatched_components": (settled_result.get("mismatched_components", []) as Array).duplicate(),
		"component_hashes_before": (settled_result.get("component_hashes_before", {}) as Dictionary).duplicate(true),
		"component_hashes_after": (settled_result.get("component_hashes_after", {}) as Dictionary).duplicate(true),
		"fixture_root_freed": node_freed,
		"fixture_state_release": fixture_state_release,
		"settle_frames_before_restore": 3,
		"settle_frames_after_restore": 2,
		"before_topology": settled_result.get("before_topology", {}),
		"after_topology": settled_result.get("after_topology", {})
	}

func _arm_interrupted_cleanup(isolation_snapshot: Dictionary) -> void:
	_interrupted_isolation_snapshot = isolation_snapshot
	_interrupted_scene_root = null
	_interrupted_arena = null

func _update_interrupted_cleanup_nodes(scene_root: Node, arena: Node) -> void:
	_interrupted_scene_root = scene_root
	_interrupted_arena = arena

func _disarm_interrupted_cleanup() -> void:
	_interrupted_isolation_snapshot = {}
	_interrupted_scene_root = null
	_interrupted_arena = null

func _recover_interrupted_repetition() -> void:
	if _interrupted_isolation_snapshot.is_empty():
		return
	var tree_available: bool = root != null and is_instance_valid(root)
	var ops_state_available: bool = OpsState != null and is_instance_valid(OpsState)
	_diagnostic_window_event("interrupted_recovery", {
		"tree_available": tree_available,
		"ops_state_available": ops_state_available
	})
	if _interrupted_arena != null and is_instance_valid(_interrupted_arena) and _interrupted_arena.has_method("clear_perf_match_seed_override"):
		_interrupted_arena.call("clear_perf_match_seed_override")
	if ops_state_available and OpsState.has_method("set_match_telemetry_collector"):
		OpsState.call("set_match_telemetry_collector", null)
	if _interrupted_scene_root != null and is_instance_valid(_interrupted_scene_root):
		_interrupted_scene_root.process_mode = Node.PROCESS_MODE_DISABLED
		_interrupted_scene_root.free()
	if tree_available:
		_free_fixture_root_additions(_interrupted_isolation_snapshot)
	if ops_state_available:
		PERF_ISOLATION_GUARD.release_fixture_state(_interrupted_isolation_snapshot, OpsState)
	if tree_available and ops_state_available:
		PERF_ISOLATION_GUARD.restore(_interrupted_isolation_snapshot, self, OpsState)
	_disarm_interrupted_cleanup()

func _free_fixture_root_additions(isolation_snapshot: Dictionary) -> void:
	if root == null:
		return
	var topology: Dictionary = isolation_snapshot.get("tree_topology", {}) as Dictionary
	var allowed_ids: Dictionary = {}
	for instance_id_any in topology.get("root_child_instance_ids", []) as Array:
		allowed_ids[int(instance_id_any)] = true
	for child_any in root.get_children():
		if not (child_any is Node):
			continue
		var child: Node = child_any as Node
		if bool(allowed_ids.get(int(child.get_instance_id()), false)):
			continue
		child.process_mode = Node.PROCESS_MODE_DISABLED
		child.free()

func _cleanup_entry_state() -> void:
	if _analytics_isolation_active and root != null and is_instance_valid(root):
		_set_analytics_harness_isolation(false)
	_analytics_isolation_active = false
	if _app_lifecycle_isolation_active and root != null and is_instance_valid(root):
		_set_app_lifecycle_harness_isolation(false)
	_app_lifecycle_isolation_active = false
	if has_meta("sf_perf_harness_active"):
		remove_meta("sf_perf_harness_active")
	_restore_gpu_vfx_auto_fallback_environment()

func _disable_gpu_vfx_auto_fallback_for_harness() -> void:
	if not _gpu_vfx_auto_fallback_env_restore.is_empty():
		return
	_gpu_vfx_auto_fallback_env_restore = {
		"existed": OS.has_environment(DISABLE_GPU_VFX_AUTO_FALLBACK_ENV),
		"value": OS.get_environment(DISABLE_GPU_VFX_AUTO_FALLBACK_ENV)
	}
	OS.set_environment(DISABLE_GPU_VFX_AUTO_FALLBACK_ENV, "1")

func _restore_gpu_vfx_auto_fallback_environment() -> void:
	if _gpu_vfx_auto_fallback_env_restore.is_empty():
		return
	if bool(_gpu_vfx_auto_fallback_env_restore.get("existed", false)):
		OS.set_environment(
			DISABLE_GPU_VFX_AUTO_FALLBACK_ENV,
			str(_gpu_vfx_auto_fallback_env_restore.get("value", ""))
		)
	else:
		OS.unset_environment(DISABLE_GPU_VFX_AUTO_FALLBACK_ENV)
	_gpu_vfx_auto_fallback_env_restore.clear()

func _finalize() -> void:
	_diagnostic_window_event("scene_tree_finalize", {
		"interrupted_repetition_armed": not _interrupted_isolation_snapshot.is_empty(),
		"tree_available": root != null and is_instance_valid(root),
		"ops_state_available": OpsState != null and is_instance_valid(OpsState)
	})
	_recover_interrupted_repetition()
	_cleanup_entry_state()

func _prime_harness_shared_services() -> void:
	SPRITE_REGISTRY.get_instance()
	await process_frame
	await process_frame

func _set_analytics_harness_isolation(enabled: bool) -> bool:
	if root == null or not is_instance_valid(root):
		return false
	var analytics: Node = root.get_node_or_null("/root/AnalyticsClient")
	return analytics != null \
		and analytics.has_method("set_perf_harness_isolation") \
		and bool(analytics.call("set_perf_harness_isolation", enabled))

func _set_app_lifecycle_harness_isolation(enabled: bool) -> bool:
	if root == null or not is_instance_valid(root):
		return false
	var lifecycle: Node = root.get_node_or_null("/root/AppLifecycle")
	return lifecycle != null \
		and lifecycle.has_method("set_perf_harness_isolation") \
		and bool(lifecycle.call("set_perf_harness_isolation", enabled))

func _configure_diagnostic_window_lifecycle(user_args: PackedStringArray) -> void:
	if not user_args.has("--diagnose-window-lifecycle"):
		return
	_diagnostic_window_lifecycle = true
	auto_accept_quit = false
	if root != null and is_instance_valid(root):
		if root.has_signal("close_requested"):
			root.connect("close_requested", _on_diagnostic_close_requested)
		if root.has_signal("focus_entered"):
			root.connect("focus_entered", _on_diagnostic_focus_entered)
		if root.has_signal("focus_exited"):
			root.connect("focus_exited", _on_diagnostic_focus_exited)
	_diagnostic_window_event("diagnostic_lifecycle_armed", {
		"auto_accept_quit": auto_accept_quit,
		"display_server": DisplayServer.get_name()
	})

func _on_diagnostic_close_requested() -> void:
	_diagnostic_window_event("window_close_requested", {
		"action": "ignored_in_diagnostic_mode"
	})

func _on_diagnostic_focus_entered() -> void:
	_reassert_diagnostic_quit_guard("window_focus_entered")

func _on_diagnostic_focus_exited() -> void:
	_reassert_diagnostic_quit_guard("window_focus_exited")

func _reassert_diagnostic_quit_guard(event_name: String) -> void:
	var previous_auto_accept_quit: bool = auto_accept_quit
	auto_accept_quit = false
	_diagnostic_window_event(event_name, {
		"auto_accept_quit_before_reassert": previous_auto_accept_quit,
		"auto_accept_quit_after_reassert": auto_accept_quit
	})

func _diagnostic_window_event(event_name: String, details: Dictionary = {}) -> void:
	if not _diagnostic_window_lifecycle:
		return
	var event: Dictionary = {
		"event": event_name,
		"ticks_msec": Time.get_ticks_msec(),
		"unix_time": Time.get_unix_time_from_system()
	}
	for key_any in details.keys():
		event[str(key_any)] = details.get(key_any)
	_diagnostic_window_events.append(event)
	print("PERF_WINDOW_LIFECYCLE: %s" % JSON.stringify(event))

func _backend_isolation_state() -> Dictionary:
	var analytics: Node = root.get_node_or_null("/root/AnalyticsClient")
	var analytics_isolated: bool = analytics != null and bool(analytics.get("_perf_harness_isolation"))
	var live_blocked: bool = not TEST_BACKEND_POLICY.request_allowed("https://benchmark-isolation.invalid")
	var loopback_blocked: bool = not TEST_BACKEND_POLICY.request_allowed("http://127.0.0.1:1")
	return {
		"pass": analytics_isolated and live_blocked and loopback_blocked,
		"analytics_writes_blocked": analytics_isolated,
		"live_transport_blocked": live_blocked,
		"loopback_transport_blocked": loopback_blocked,
		"policy": "deny_all_while_sf_perf_harness_active"
	}

func _queue_fixture_root_additions(isolation_snapshot: Dictionary) -> void:
	var topology: Dictionary = isolation_snapshot.get("tree_topology", {}) as Dictionary
	var allowed_ids: Dictionary = {}
	for instance_id_any in topology.get("root_child_instance_ids", []) as Array:
		allowed_ids[int(instance_id_any)] = true
	for child_any in root.get_children():
		if not (child_any is Node):
			continue
		var child: Node = child_any as Node
		if bool(allowed_ids.get(int(child.get_instance_id()), false)):
			continue
		child.process_mode = Node.PROCESS_MODE_DISABLED
		if not child.is_queued_for_deletion():
			child.queue_free()

func _normalized_benchmark_mode(raw_mode: String) -> String:
	var clean_mode: String = raw_mode.strip_edges().to_lower()
	if clean_mode.is_empty() or clean_mode == "sim_headless":
		return "canonical_sim_headless"
	return clean_mode

func _measurement_profile_for_benchmark_mode(benchmark_mode: String) -> String:
	match benchmark_mode:
		"deterministic_windowed_presentation":
			return "deterministic_windowed_presentation"
		"static_windowed_deterministic":
			return "static_windowed_deterministic"
		"render_windowed":
			return "investigative_render_windowed"
		"layer_isolation_noncanonical":
			return "investigative_layer_isolation"
		_:
			return "canonical_sim_headless"

func _fixture_identity_payload(scenario_def: Dictionary) -> Dictionary:
	return {
		"scenario_id": str(scenario_def.get("scenario_id", "")),
		"fixture_id": str(scenario_def.get("fixture_id", scenario_def.get("scenario_id", ""))),
		"fixture_version": int(scenario_def.get("fixture_version", 1)),
		"catalog_fixture_registered": bool(scenario_def.get("catalog_fixture_registered", false)),
		"measurement_profile": str(scenario_def.get("measurement_profile", "")),
		"content_kind": str(scenario_def.get("content_kind", "production_map")),
		"content_identity": str(scenario_def.get("content_identity", "")),
		"map_path": str(scenario_def.get("map_path", "")),
		"map_content_hash": str(scenario_def.get("_preflight_map_content_hash", "")),
		"seed": int(scenario_def.get("seed", 0)),
		"tick_count": int(scenario_def.get("tick_count", 0)),
		"warmup_ticks": int(scenario_def.get("warmup_ticks", 0)),
		"systems": (scenario_def.get("systems", []) as Array).duplicate(true),
		"initial_lanes": int(scenario_def.get("initial_lanes", 0)),
		"initial_swarms": int(scenario_def.get("initial_swarms", 0)),
		"initial_barracks_routes": int(scenario_def.get("initial_barracks_routes", 0)),
		"target_units": int(scenario_def.get("target_units", 0)),
		"unit_count_policy": str(scenario_def.get("unit_count_policy", "exact_static")),
		"phase2_requires_three_repetitions": bool(scenario_def.get("phase2_requires_three_repetitions", false)),
		"phase2_lifecycle_profile": str(scenario_def.get("phase2_lifecycle_profile", "")),
		"lifecycle_required_cycles": int(scenario_def.get("lifecycle_required_cycles", 0)),
		"lifecycle_limits": (scenario_def.get("lifecycle_limits", {}) as Dictionary).duplicate(true),
		"feature_id": str(scenario_def.get("feature_id", "")),
		"feature_variant": str(scenario_def.get("feature_variant", "")),
		"feature_control_value": scenario_def.get("feature_control_value"),
		"lane_build_timeout_ms": int(scenario_def.get("lane_build_timeout_ms", 0)),
		"renderer_ready_timeout_ms": int(scenario_def.get("renderer_ready_timeout_ms", 0)),
		"capacity_bypass_allowed": bool(scenario_def.get("capacity_bypass_allowed", true)),
		"expected_pool_capacity": int(scenario_def.get("expected_pool_capacity", 0)),
		"expected_pool_expansions": int(scenario_def.get("expected_pool_expansions", -1)),
		"command_interval_ticks": int(scenario_def.get("command_interval_ticks", 0)),
		"command_selector_version": str(scenario_def.get("command_selector_version", "")),
		"expected_command_count_exact": int(scenario_def.get("expected_command_count_exact", -1)),
		"commands_per_burst": int(scenario_def.get("commands_per_burst", 0)),
		"swarm_burst": int(scenario_def.get("swarm_burst", 0)),
		"command_schedule": (scenario_def.get("command_schedule", []) as Array).duplicate(true),
		"camera_schedule": (scenario_def.get("camera_schedule", []) as Array).duplicate(true),
		"ui_schedule": (scenario_def.get("ui_schedule", []) as Array).duplicate(true),
		"runtime_switches": (scenario_def.get("runtime_switches", {}) as Dictionary).duplicate(true),
		"camera_policy": str(scenario_def.get("camera_policy", "")),
		"cadence": (scenario_def.get("cadence", {}) as Dictionary).duplicate(true),
		"synthetic_descriptor": (scenario_def.get("synthetic_descriptor", {}) as Dictionary).duplicate(true),
		"expected_counts": (scenario_def.get("expected_counts", {}) as Dictionary).duplicate(true)
	}

func _determinism_evidence(scenarios: Array) -> Dictionary:
	var by_fixture: Dictionary = {}
	for scenario_any in scenarios:
		if typeof(scenario_any) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_any as Dictionary
		var fixture_id: String = str(scenario.get("fixture_id", scenario.get("scenario_id", "unknown")))
		if not by_fixture.has(fixture_id):
			by_fixture[fixture_id] = []
		(by_fixture[fixture_id] as Array).append(scenario)
	var fixture_rows: Array = []
	var all_pass: bool = true
	for fixture_id_any in by_fixture.keys():
		var fixture_id: String = str(fixture_id_any)
		var repetitions: Array = by_fixture.get(fixture_id, []) as Array
		var first_repetition: Dictionary = repetitions[0] as Dictionary if not repetitions.is_empty() else {}
		var required_repetitions: int = 3 if fixture_id in ["PHASE0_INTEGRITY_CENTERSTRIKE_V1", "P1B_WINDOWED_ADAPTER_PROBE_V1", "P1D_NORMAL_MATCH_PILOT_V1"] or bool(first_repetition.get("catalog_fixture_registered", false)) or bool(first_repetition.get("phase2_requires_three_repetitions", false)) else 1
		var fields: Array[String] = [
			"fixture_config_hash",
			"requested_seed",
			"effective_seed",
			"command_schedule_hash",
			"final_state_hash"
		]
		if str(first_repetition.get("content_kind", "production_map")) == "production_map":
			fields.append("map_content_hash")
		if str(first_repetition.get("benchmark_mode", "")) in ["deterministic_windowed_presentation", "static_windowed_deterministic"]:
			fields.append_array([
				"camera_identity_hash",
				"cadence_identity_hash",
				"renderer_configuration_hash",
				"frame_count",
				"measured_frame_count",
				"tick_count",
				"measured_tick_count"
			])
		if int(first_repetition.get("target_units", 0)) > 0:
			fields.append_array(["unit_injection_hash", "lane_setup_hash", "renderer_pool_hash"])
			if str(first_repetition.get("unit_count_policy", "exact_static")) == "bounded_moving":
				fields.append_array(["unit_count_timeline_hash", "unit_motion_hash"])
		if not str(first_repetition.get("phase2_stress_profile", "")).is_empty():
			fields.append("phase2_event_hash")
		if not str(first_repetition.get("phase2_battlefield_profile", "")).is_empty():
			fields.append("phase2_battlefield_event_hash")
		var mismatches: Array = []
		if repetitions.size() < required_repetitions:
			mismatches.append("repetition_count:%d<%d" % [repetitions.size(), required_repetitions])
		if repetitions.size() > 1:
			var first: Dictionary = repetitions[0] as Dictionary
			for field in fields:
				var expected: String = str(first.get(field, ""))
				if expected.is_empty():
					mismatches.append("missing:%s" % field)
					continue
				for i in range(1, repetitions.size()):
					var current: Dictionary = repetitions[i] as Dictionary
					if str(current.get(field, "")) != expected:
						mismatches.append("mismatch:%s:repetition_%d" % [field, i + 1])
		var fixture_pass: bool = mismatches.is_empty()
		all_pass = all_pass and fixture_pass
		fixture_rows.append({
			"fixture_id": fixture_id,
			"repetition_count": repetitions.size(),
			"required_repetition_count": required_repetitions,
			"fields_compared": fields,
			"pass": fixture_pass,
			"mismatches": mismatches
		})
	fixture_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("fixture_id", "")) < str(b.get("fixture_id", ""))
	)
	return {"pass": all_pass, "fixtures": fixture_rows}

func _unit_scale_diagnostic(scenarios: Array) -> Dictionary:
	var by_target: Dictionary = {}
	for scenario_any in scenarios:
		if typeof(scenario_any) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_any as Dictionary
		var target: int = int(scenario.get("target_units", 0))
		if target <= 0:
			continue
		if not by_target.has(target):
			by_target[target] = []
		(by_target[target] as Array).append(scenario)
	var targets: Array = by_target.keys()
	targets.sort()
	var rows: Array = []
	var rendered_objects_monotonic: bool = true
	var active_pooled_objects_monotonic: bool = true
	var average_frame_ms_monotonic: bool = true
	var previous_objects: float = -INF
	var previous_active_pooled_objects: int = -1
	var previous_average_ms: float = -INF
	for target_any in targets:
		var target: int = int(target_any)
		var repetitions: Array = by_target.get(target, []) as Array
		var average_sum: float = 0.0
		var p95_sum: float = 0.0
		var rendered_objects_peak: int = 0
		var active_pooled_objects: int = 0
		for scenario_any in repetitions:
			var scenario: Dictionary = scenario_any as Dictionary
			average_sum += float(scenario.get("average_frame_ms", 0.0))
			p95_sum += float(scenario.get("p95_frame_ms", 0.0))
			rendered_objects_peak = maxi(rendered_objects_peak, int((scenario.get("render_monitor_peaks", {}) as Dictionary).get("rendered_objects", 0)))
			active_pooled_objects = maxi(active_pooled_objects, int((scenario.get("renderer_pool_telemetry", {}) as Dictionary).get("active_pooled_objects", 0)))
		var denominator: float = maxf(1.0, float(repetitions.size()))
		var average_ms: float = average_sum / denominator
		var p95_ms: float = p95_sum / denominator
		if float(rendered_objects_peak) < previous_objects:
			rendered_objects_monotonic = false
		if active_pooled_objects < previous_active_pooled_objects or active_pooled_objects != target:
			active_pooled_objects_monotonic = false
		if average_ms < previous_average_ms:
			average_frame_ms_monotonic = false
		previous_objects = float(rendered_objects_peak)
		previous_active_pooled_objects = active_pooled_objects
		previous_average_ms = average_ms
		rows.append({
			"target_units": target,
			"repetitions": repetitions.size(),
			"average_frame_ms_mean": average_ms,
			"p95_frame_ms_mean": p95_ms,
			"rendered_objects_peak": rendered_objects_peak,
			"active_pooled_objects": active_pooled_objects
		})
	return {
		"status": "DIAGNOSTIC_ONLY",
		"rows": rows,
		"rendered_objects_monotonic": rendered_objects_monotonic,
		"active_pooled_objects_monotonic": active_pooled_objects_monotonic,
		"average_frame_ms_monotonic": average_frame_ms_monotonic,
		"affects_suite_pass": false
	}

func _collector_calibration_evidence(scenarios: Array) -> Dictionary:
	var by_level: Dictionary = {"OFF": [], "MINIMAL": [], "FULL": []}
	var behavior_mismatches: Array = []
	var sequence: Array = []
	for scenario_any in scenarios:
		if typeof(scenario_any) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_any as Dictionary
		var level: String = str(scenario.get("collection_level", ""))
		if not by_level.has(level):
			behavior_mismatches.append("unexpected_collection_level:%s" % level)
			continue
		var collection: Dictionary = scenario.get("collection", {}) as Dictionary
		var timing_enabled: bool = bool(collection.get("timing_enabled", false))
		var raw_capture: bool = bool((collection.get("retention", {}) as Dictionary).get("raw_sample_capture", false))
		if level == "OFF" and (timing_enabled or raw_capture):
			behavior_mismatches.append("OFF_behavior_not_disabled")
		if level == "MINIMAL" and (not timing_enabled or raw_capture):
			behavior_mismatches.append("MINIMAL_behavior_invalid")
		if level == "FULL" and (not timing_enabled or not raw_capture):
			behavior_mismatches.append("FULL_behavior_invalid")
		var wall_duration_ms: float = float(scenario.get("measurement_wall_duration_ms", 0.0))
		(by_level[level] as Array).append(wall_duration_ms)
		sequence.append({
			"suite_sequence_index": int(scenario.get("suite_sequence_index", 0)),
			"collection_level": level,
			"measurement_wall_duration_ms": wall_duration_ms,
			"final_state_hash": str(scenario.get("final_state_hash", "")),
			"command_schedule_hash": str(scenario.get("command_schedule_hash", ""))
		})
	var levels: Dictionary = {}
	var repeat_mismatches: Array = []
	for level_any in ["OFF", "MINIMAL", "FULL"]:
		var level: String = str(level_any)
		var samples: Array = by_level.get(level, []) as Array
		if samples.size() < 3:
			repeat_mismatches.append("%s_repetitions:%d<3" % [level, samples.size()])
		levels[level] = {
			"repetition_count": samples.size(),
			"measurement_wall_duration_ms": samples.duplicate(),
			"median_ms": _percentile(samples, 0.5) if not samples.is_empty() else null,
			"min_ms": _min_float_array(samples) if not samples.is_empty() else null,
			"max_ms": _max(samples) if not samples.is_empty() else null
		}
	var off_median: float = float((levels.get("OFF", {}) as Dictionary).get("median_ms", 0.0))
	var observed_deltas: Dictionary = {}
	if off_median > 0.0:
		for level_any in ["MINIMAL", "FULL"]:
			var level: String = str(level_any)
			var level_median: float = float((levels.get(level, {}) as Dictionary).get("median_ms", 0.0))
			observed_deltas[level] = ((level_median - off_median) / off_median) * 100.0
	return {
		"pass": behavior_mismatches.is_empty() and repeat_mismatches.is_empty(),
		"fixture_id": "PHASE0_COLLECTOR_CALIBRATION_V1",
		"method": "three staggered canonical-fixture repetitions per collection level",
		"interpretation": "directional repeated evidence only; observed median deltas are not an exact instrumentation-cost claim",
		"outer_measurement": "one wall-clock interval around the measured canonical tick window for every level",
		"levels": levels,
		"observed_median_delta_percent_vs_off": observed_deltas,
		"sequence": sequence,
		"behavior_mismatches": behavior_mismatches,
		"repeat_mismatches": repeat_mismatches
	}

func _min_float_array(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var minimum: float = float(values[0])
	for value_any in values:
		minimum = minf(minimum, float(value_any))
	return minimum

func _isolation_evidence(scenarios: Array) -> Dictionary:
	var rows: Array = []
	var mismatches: Array = []
	var expected_before_hash: String = ""
	for scenario_any in scenarios:
		if typeof(scenario_any) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_any as Dictionary
		var cleanup_any: Variant = scenario.get("isolation_cleanup", {})
		var cleanup: Dictionary = cleanup_any as Dictionary if typeof(cleanup_any) == TYPE_DICTIONARY else {}
		var scenario_id: String = str(scenario.get("scenario_id", "unknown"))
		var sequence_index: int = int(scenario.get("suite_sequence_index", rows.size() + 1))
		var before_hash: String = str(cleanup.get("before_hash", ""))
		var after_hash: String = str(cleanup.get("after_hash", ""))
		var row_mismatches: Array = (cleanup.get("mismatches", []) as Array).duplicate()
		if before_hash.is_empty() or after_hash.is_empty():
			row_mismatches.append("isolation_hash_missing")
		if not before_hash.is_empty() and not after_hash.is_empty() and before_hash != after_hash:
			row_mismatches.append("pre_post_hash_mismatch")
		if expected_before_hash.is_empty() and not before_hash.is_empty():
			expected_before_hash = before_hash
		elif not before_hash.is_empty() and before_hash != expected_before_hash:
			row_mismatches.append("cross_scenario_start_state_mismatch")
		for mismatch_any in row_mismatches:
			mismatches.append("sequence_%d:%s:%s" % [sequence_index, scenario_id, str(mismatch_any)])
		rows.append({
			"suite_sequence_index": sequence_index,
			"scenario_id": scenario_id,
			"before_hash": before_hash,
			"after_hash": after_hash,
			"fixture_root_freed": bool(cleanup.get("fixture_root_freed", false)),
			"pass": row_mismatches.is_empty(),
			"mismatches": row_mismatches
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("suite_sequence_index", 0)) < int(b.get("suite_sequence_index", 0))
	)
	return {
		"pass": mismatches.is_empty() and rows.size() == scenarios.size(),
		"shared_start_state_hash": expected_before_hash,
		"scenario_count": rows.size(),
		"scenarios": rows,
		"mismatches": mismatches
	}

func _lifecycle_soak_evidence(scenarios: Array) -> Dictionary:
	var mismatches: Array = []
	var cycle_rows: Array = []
	var first: Dictionary = scenarios[0] as Dictionary if not scenarios.is_empty() else {}
	var required_cycles: int = int(first.get("lifecycle_required_cycles", 0))
	var limits: Dictionary = (first.get("lifecycle_limits", {}) as Dictionary).duplicate(true)
	if required_cycles <= 0 or scenarios.size() != required_cycles:
		mismatches.append("cycle_count:%d!=%d" % [scenarios.size(), required_cycles])
	var after_cleanup_rows: Array = []
	var total_retained_percentile: int = 0
	var total_retained_raw: int = 0
	var total_report_payload_bytes: int = 0
	for cycle_index in range(scenarios.size()):
		var scenario: Dictionary = scenarios[cycle_index] as Dictionary
		var cycle_number: int = cycle_index + 1
		var cleanup: Dictionary = scenario.get("isolation_cleanup", {}) as Dictionary
		var before: Dictionary = scenario.get("lifecycle_runtime_before", {}) as Dictionary
		var during: Dictionary = scenario.get("lifecycle_runtime_during", {}) as Dictionary
		var after: Dictionary = scenario.get("lifecycle_runtime_after_cleanup", {}) as Dictionary
		var cycle_mismatches: Array = []
		if before.is_empty() or during.is_empty() or after.is_empty():
			cycle_mismatches.append("runtime_counter_snapshot_missing")
		if not bool(cleanup.get("pass", false)) or not bool(cleanup.get("fixture_root_freed", false)):
			cycle_mismatches.append("cleanup_not_exact")
		if str(cleanup.get("before_protected_state_hash", "")) != str(cleanup.get("after_protected_state_hash", "")):
			cycle_mismatches.append("protected_state_hash_mismatch")
		var component_before: Dictionary = cleanup.get("component_hashes_before", {}) as Dictionary
		var component_after: Dictionary = cleanup.get("component_hashes_after", {}) as Dictionary
		if str(component_before.get("tree_topology", "")) != str(component_after.get("tree_topology", "")):
			cycle_mismatches.append("topology_hash_mismatch")
		var pool: Dictionary = scenario.get("renderer_pool_telemetry", {}) as Dictionary
		if int(pool.get("total_pooled_objects", -1)) != int(scenario.get("expected_pool_capacity", -2)):
			cycle_mismatches.append("pool_capacity_mismatch")
		if int(pool.get("pool_misses", -1)) != 0 or int(pool.get("pool_expansions", -1)) != 0:
			cycle_mismatches.append("pool_growth_observed")
		var collection: Dictionary = scenario.get("collection", {}) as Dictionary
		var retention: Dictionary = collection.get("retention", {}) as Dictionary
		var percentile_limit: int = int(retention.get("percentile_sample_limit", -1))
		var retained_percentile: int = int(retention.get("retained_percentile_sample_count", -1))
		var forensic_limit: int = int(retention.get("forensic_record_limit", -1))
		var retained_worst: int = int(retention.get("retained_worst_record_count", -1))
		var retained_hitch: int = int(retention.get("retained_hitch_record_count", -1))
		var raw_limit: int = int(retention.get("raw_sample_limit", -1))
		var retained_raw: int = int(retention.get("retained_raw_sample_count", -1))
		if int(collection.get("sample_count", -1)) != int(scenario.get("measured_frame_count", -2)):
			cycle_mismatches.append("sample_count_mismatch")
		if retained_percentile < 0 or retained_percentile > percentile_limit:
			cycle_mismatches.append("percentile_retention_unbounded")
		if retained_worst < 0 or retained_worst > forensic_limit or retained_hitch < 0 or retained_hitch > forensic_limit:
			cycle_mismatches.append("forensic_retention_unbounded")
		if retained_raw < 0 or retained_raw > raw_limit or (collection.get("raw_samples", []) as Array).size() != retained_raw:
			cycle_mismatches.append("raw_retention_unbounded")
		var report_payload_bytes: int = int(scenario.get("lifecycle_report_payload_bytes", -1))
		if report_payload_bytes < 0 or report_payload_bytes > int(limits.get("report_payload_bytes", 0)):
			cycle_mismatches.append("report_payload_unbounded")
		total_retained_percentile += maxi(0, retained_percentile)
		total_retained_raw += maxi(0, retained_raw)
		total_report_payload_bytes += maxi(0, report_payload_bytes)
		if not after.is_empty():
			after_cleanup_rows.append(after.duplicate(true))
		for mismatch_any in cycle_mismatches:
			mismatches.append("cycle_%d:%s" % [cycle_number, str(mismatch_any)])
		cycle_rows.append({
			"cycle": cycle_number,
			"pass": cycle_mismatches.is_empty(),
			"mismatches": cycle_mismatches,
			"runtime_before": before.duplicate(true),
			"runtime_during": during.duplicate(true),
			"runtime_after_cleanup": after.duplicate(true),
			"protected_state_hash": str(cleanup.get("after_protected_state_hash", "")),
			"topology_hash": str(component_after.get("tree_topology", "")),
			"fixture_root_freed": bool(cleanup.get("fixture_root_freed", false)),
			"pool": _stable_pool_identity(pool),
			"retention": retention.duplicate(true),
			"report_payload_bytes": report_payload_bytes
		})
	var trend_rows: Dictionary = {}
	var counter_limits: Dictionary = {
		"node_count": int(limits.get("node_growth", 0)),
		"object_count": int(limits.get("object_growth", 0)),
		"resource_count": int(limits.get("resource_growth", 0)),
		"static_memory_bytes": int(limits.get("static_memory_growth_bytes", 0))
	}
	if after_cleanup_rows.size() == scenarios.size() and not after_cleanup_rows.is_empty():
		for key_any in counter_limits.keys():
			var key: String = str(key_any)
			var baseline: int = int((after_cleanup_rows[0] as Dictionary).get(key, 0))
			var peak: int = baseline
			for row_any in after_cleanup_rows:
				peak = maxi(peak, int((row_any as Dictionary).get(key, baseline)))
			var final_value: int = int((after_cleanup_rows[-1] as Dictionary).get(key, baseline))
			var peak_growth: int = maxi(0, peak - baseline)
			var final_growth: int = maxi(0, final_value - baseline)
			var limit: int = int(counter_limits.get(key, 0))
			if peak_growth > limit or final_growth > limit:
				mismatches.append("counter_growth:%s:peak=%d:final=%d:limit=%d" % [key, peak_growth, final_growth, limit])
			trend_rows[key] = {"baseline": baseline, "peak": peak, "final": final_value, "peak_growth": peak_growth, "final_growth": final_growth, "limit": limit}
		var max_orphans: int = 0
		var expected_root_children: int = int((after_cleanup_rows[0] as Dictionary).get("root_child_count", -1))
		for row_any in after_cleanup_rows:
			var row: Dictionary = row_any as Dictionary
			max_orphans = maxi(max_orphans, int(row.get("orphan_node_count", 0)))
			if int(row.get("root_child_count", -2)) != expected_root_children:
				mismatches.append("root_child_count_drift")
		var orphan_limit: int = int(limits.get("orphan_node_count", 0))
		if max_orphans > orphan_limit:
			mismatches.append("orphan_node_count:%d>%d" % [max_orphans, orphan_limit])
		trend_rows["orphan_node_count"] = {"maximum": max_orphans, "limit": orphan_limit}
		trend_rows["root_child_count"] = {"expected": expected_root_children}
	return {
		"pass": mismatches.is_empty(),
		"fixture_id": "LIFECYCLE_SOAK_V1",
		"cycle_count": scenarios.size(),
		"required_cycle_count": required_cycles,
		"bounded_by_maximum_harness_repetitions": 10,
		"limits": limits,
		"cycles": cycle_rows,
		"counter_trends": trend_rows,
		"total_retained_percentile_samples": total_retained_percentile,
		"total_retained_raw_samples": total_retained_raw,
		"total_report_payload_bytes": total_report_payload_bytes,
		"interrupted_cleanup_recovery": {
			"handler": "_finalize->_recover_interrupted_repetition",
			"focused_gate": "PERF_PHASE2_GATE_E_SMOKE"
		},
		"mismatches": mismatches
	}

func _feature_isolation_evidence(scenarios: Array, registry: Dictionary) -> Dictionary:
	var mismatches: Array = []
	var feature: Dictionary = PERF_FEATURE_REGISTRY.resolved_feature(registry, "arena_polish_bundle")
	if feature.is_empty():
		return {"pass": false, "mismatches": ["arena_polish_bundle_missing"]}
	var expected_variants: Array[String] = ["off", "production", "exaggerated"]
	var by_variant: Dictionary = {}
	for variant in expected_variants:
		by_variant[variant] = []
	for scenario_any in scenarios:
		var scenario: Dictionary = scenario_any as Dictionary
		var variant: String = str(scenario.get("feature_variant", ""))
		if str(scenario.get("feature_id", "")) != "arena_polish_bundle":
			mismatches.append("unexpected_feature_id:%s" % str(scenario.get("feature_id", "")))
		if not by_variant.has(variant):
			mismatches.append("unexpected_variant:%s" % variant)
			continue
		(by_variant[variant] as Array).append(scenario)
	var rows: Array = []
	var variants: Dictionary = feature.get("variants", {}) as Dictionary
	var first_scenario: Dictionary = scenarios[0] as Dictionary if not scenarios.is_empty() else {}
	var shared_fields: Array[String] = [
		"requested_seed", "effective_seed", "map_content_hash", "command_schedule_hash",
		"final_state_hash", "camera_identity_hash", "cadence_identity_hash", "frame_count",
		"measured_frame_count", "tick_count", "measured_tick_count", "collection_level"
	]
	for scenario_any in scenarios:
		var scenario: Dictionary = scenario_any as Dictionary
		for field in shared_fields:
			if str(scenario.get(field, "")) != str(first_scenario.get(field, "")):
				mismatches.append("non_target_identity_mismatch:%s:sequence_%d" % [field, int(scenario.get("suite_sequence_index", 0))])
	for variant in expected_variants:
		var repetitions: Array = by_variant.get(variant, []) as Array
		if repetitions.size() != 3:
			mismatches.append("variant_repetition_count:%s:%d!=3" % [variant, repetitions.size()])
		var policy_row: Dictionary = variants.get(variant, {}) as Dictionary
		if not bool(policy_row.get("supported", false)) or not bool(policy_row.get("comparison_safe", false)):
			mismatches.append("variant_not_registry_approved:%s" % variant)
		var expected_value: String = str(policy_row.get("value", ""))
		var config_hashes: Array[String] = []
		var timing_rows: Array = []
		for repetition_any in repetitions:
			var repetition: Dictionary = repetition_any as Dictionary
			if str(repetition.get("feature_control_value", "")) != expected_value:
				mismatches.append("control_value_mismatch:%s" % variant)
			var renderer_state: Dictionary = repetition.get("renderer_configuration_state", {}) as Dictionary
			if str(renderer_state.get("arena_polish_comparison_mode", "")) != expected_value:
				mismatches.append("resolved_mode_mismatch:%s" % variant)
			if variant == "off" and bool(renderer_state.get("arena_polish_enabled", true)):
				mismatches.append("off_variant_remained_visible")
			if variant == "exaggerated" and (
				not bool(renderer_state.get("arena_polish_enabled", false))
				or not is_equal_approx(float(renderer_state.get("arena_polish_tower_visual_scale", 0.0)), 1.5)
			):
				mismatches.append("exaggerated_variant_not_resolved")
			config_hashes.append(str(repetition.get("renderer_configuration_hash", "")))
			timing_rows.append({
				"repetition": int(repetition.get("repetition_index", 0)),
				"average_frame_ms": repetition.get("average_frame_ms"),
				"p95_frame_ms": repetition.get("p95_frame_ms"),
				"p99_frame_ms": repetition.get("p99_frame_ms"),
				"max_frame_ms": repetition.get("max_frame_ms")
			})
		if config_hashes.size() == 3 and (config_hashes[0].is_empty() or config_hashes[0] != config_hashes[1] or config_hashes[0] != config_hashes[2]):
			mismatches.append("variant_configuration_not_repeatable:%s" % variant)
		rows.append({
			"variant": variant,
			"control_value": expected_value,
			"repetition_count": repetitions.size(),
			"renderer_configuration_hash": config_hashes[0] if not config_hashes.is_empty() else "",
			"timings": timing_rows
		})
	var distinct_hashes: Dictionary = {}
	for row_any in rows:
		var hash_value: String = str((row_any as Dictionary).get("renderer_configuration_hash", ""))
		if not hash_value.is_empty():
			distinct_hashes[hash_value] = true
	# Production currently resolves arena polish off, so off/production may share
	# a renderer hash. Exaggerated must remain observably distinct.
	if distinct_hashes.size() < 2:
		mismatches.append("feature_variants_not_observably_distinct")
	return {
		"pass": mismatches.is_empty(),
		"feature_id": "arena_polish_bundle",
		"classification": str(feature.get("classification", "")),
		"owner": str(feature.get("owner", "")),
		"control": (feature.get("control", {}) as Dictionary).duplicate(true),
		"variants": rows,
		"one_variable_shared_fields": shared_fields,
		"production_default_note": "production settings currently resolve arena polish disabled; off and production may match",
		"mismatches": mismatches
	}

func _summary_for_print(report: Dictionary) -> Dictionary:
	var scenarios: Array = []
	for scenario_any in report.get("scenarios", []) as Array:
		var scenario: Dictionary = scenario_any as Dictionary
		var canonical: bool = str(scenario.get("benchmark_mode", "")) == "canonical_sim_headless"
		scenarios.append({
			"scenario_id": scenario.get("scenario_id", ""),
			"repetition_index": scenario.get("repetition_index", 1),
			"pass": scenario.get("pass", false),
			"allowed_failure": scenario.get("allowed_failure", false),
			"primary_timing": "simulation_tick_ms" if canonical else "display_or_layer_iteration_ms",
			"average_ms": scenario.get("average_tick_ms", 0.0) if canonical else scenario.get("average_frame_ms", 0.0),
			"p95_ms": scenario.get("p95_tick_ms", 0.0) if canonical else scenario.get("p95_frame_ms", 0.0),
			"p99_ms": scenario.get("p99_tick_ms", 0.0) if canonical else scenario.get("p99_frame_ms", 0.0),
			"max_ms": scenario.get("max_tick_ms", 0.0) if canonical else scenario.get("max_frame_ms", 0.0),
			"hitch_count": scenario.get("hitch_count", 0)
		})
	return {
		"pass": report.get("pass", false),
		"suite_id": report.get("suite_id", ""),
		"benchmark_mode": report.get("benchmark_mode", ""),
		"scenarios": scenarios
	}

func _compare_reports(baseline: Dictionary, current: Dictionary, gates: Dictionary) -> Dictionary:
	return PERF_BASELINE_COMPARATOR.compare(baseline, current, gates)

func _parse_args() -> Dictionary:
	var out := {
		"mode": "canonical_sim_headless",
		"suite": "quick",
		"collection_level": PERF_RESULT_CONTRACT.COLLECTION_LEVEL_MINIMAL,
		"gates": DEFAULT_GATES_PATH,
		"catalog": DEFAULT_FIXTURE_CATALOG_PATH,
		"output": DEFAULT_OUTPUT_PATH,
		"switch_overrides": {}
	}
	var args := _cmdline_args()
	var i := 0
	while i < args.size():
		var arg := str(args[i])
		if arg.begins_with("--mode="):
			out["mode"] = arg.trim_prefix("--mode=")
		elif arg == "--mode" and i + 1 < args.size():
			i += 1
			out["mode"] = str(args[i])
		elif arg.begins_with("--suite="):
			out["suite"] = arg.trim_prefix("--suite=")
		elif arg == "--suite" and i + 1 < args.size():
			i += 1
			out["suite"] = str(args[i])
		elif arg.begins_with("--collection-level="):
			out["collection_level"] = arg.trim_prefix("--collection-level=")
		elif arg == "--collection-level" and i + 1 < args.size():
			i += 1
			out["collection_level"] = str(args[i])
		elif arg.begins_with("--scenario="):
			out["scenario"] = arg.trim_prefix("--scenario=")
		elif arg == "--scenario" and i + 1 < args.size():
			i += 1
			out["scenario"] = str(args[i])
		elif arg.begins_with("--repetitions="):
			out["repetitions"] = int(arg.trim_prefix("--repetitions="))
		elif arg == "--repetitions" and i + 1 < args.size():
			i += 1
			out["repetitions"] = int(args[i])
		elif arg.begins_with("--gates="):
			out["gates"] = arg.trim_prefix("--gates=")
		elif arg == "--gates" and i + 1 < args.size():
			i += 1
			out["gates"] = str(args[i])
		elif arg.begins_with("--catalog="):
			out["catalog"] = arg.trim_prefix("--catalog=")
		elif arg == "--catalog" and i + 1 < args.size():
			i += 1
			out["catalog"] = str(args[i])
		elif arg.begins_with("--output="):
			out["output"] = arg.trim_prefix("--output=")
		elif arg == "--output" and i + 1 < args.size():
			i += 1
			out["output"] = str(args[i])
		elif arg.begins_with("--baseline="):
			out["baseline"] = arg.trim_prefix("--baseline=")
		elif arg == "--baseline" and i + 1 < args.size():
			i += 1
			out["baseline"] = str(args[i])
		elif arg.begins_with("--map="):
			out["map"] = arg.trim_prefix("--map=")
		elif arg == "--map" and i + 1 < args.size():
			i += 1
			out["map"] = str(args[i])
		elif arg.begins_with("--switch="):
			_parse_switch_override(arg.trim_prefix("--switch="), out["switch_overrides"] as Dictionary)
		elif arg == "--switch" and i + 1 < args.size():
			i += 1
			_parse_switch_override(str(args[i]), out["switch_overrides"] as Dictionary)
		i += 1
	return out

func _parse_switch_override(raw: String, out: Dictionary) -> void:
	var split := raw.split("=", false, 1)
	if split.size() != 2:
		return
	var key := str(split[0]).strip_edges()
	var value_raw := str(split[1]).strip_edges()
	if key.is_empty():
		return
	match value_raw.to_lower():
		"true":
			out[key] = true
		"false":
			out[key] = false
		_:
			if value_raw.is_valid_int():
				out[key] = int(value_raw)
			elif value_raw.is_valid_float():
				out[key] = float(value_raw)
			else:
				out[key] = value_raw

func _configure_user_data_isolation(args: PackedStringArray) -> void:
	var isolation_name: String = ""
	var i: int = 0
	while i < args.size():
		var arg: String = str(args[i])
		if arg.begins_with("--perf-user-dir="):
			isolation_name = arg.trim_prefix("--perf-user-dir=").strip_edges()
		elif arg == "--perf-user-dir" and i + 1 < args.size():
			i += 1
			isolation_name = str(args[i]).strip_edges()
		i += 1
	if isolation_name.is_empty():
		return
	if not _valid_user_data_isolation_name(isolation_name):
		_user_data_isolation["error"] = "perf_user_dir_name_invalid"
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", isolation_name)
	var isolated_path: String = ProjectSettings.globalize_path("user://")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(isolated_path)
	if make_error != OK:
		_user_data_isolation["error"] = "perf_user_dir_create_failed:%d" % make_error
		return
	_user_data_isolation = {
		"enabled": true,
		"name": isolation_name,
		"path": isolated_path,
		"error": ""
	}

func _valid_user_data_isolation_name(value: String) -> bool:
	if value in [".", ".."] or value.length() > 80:
		return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		var allowed: bool = (code >= 48 and code <= 57) \
			or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or code in [45, 46, 95]
		if not allowed:
			return false
	return true

func _cmdline_args() -> PackedStringArray:
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		return user_args
	return OS.get_cmdline_args()

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

func _write_json(path: String, data: Dictionary) -> void:
	var dir_path := path.get_base_dir()
	if dir_path.begins_with("res://") or dir_path.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("perf_benchmark_suite: failed to write %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))

func _apply_result_contract(report: Dictionary) -> void:
	report["collection_contract_version"] = 1
	report["metric_classifications"] = PERF_RESULT_CONTRACT.METRIC_CLASSIFICATIONS.duplicate()
	report["comparison_critical_fields"] = PERF_RESULT_CONTRACT.COMPARISON_CRITICAL_FIELDS.duplicate()
	var scenarios: Array = report.get("scenarios", []) as Array
	for scenario_index in range(scenarios.size()):
		var scenario: Dictionary = scenarios[scenario_index] as Dictionary
		if not scenario.has("collection_level"):
			scenario["collection_level"] = str(report.get("collection_level", PERF_RESULT_CONTRACT.COLLECTION_LEVEL_MINIMAL))
		scenario["metrics"] = _metric_contract_for_scenario(scenario)
		PERF_RESULT_CONTRACT.attach_scenario_fingerprint(report, scenario)
		scenarios[scenario_index] = scenario
	report["scenarios"] = scenarios
	report["result_validation"] = PERF_RESULT_CONTRACT.validate_report(report)
	report["baseline_approval"] = PERF_RESULT_CONTRACT.baseline_approval(report)

func _metric_contract_for_scenario(scenario: Dictionary) -> Dictionary:
	var metrics: Dictionary = {}
	var benchmark_mode: String = str(scenario.get("benchmark_mode", ""))
	var collection: Dictionary = scenario.get("collection", {}) as Dictionary
	var timing_available: bool = bool(collection.get("available", false))
	var collection_level: String = str(scenario.get("collection_level", ""))
	var timing_source: String = "bounded %s collector" % collection_level
	var timing_reason: String = str(collection.get("unavailable_reason", "timing unavailable"))
	var setup_failed: bool = false
	for failed_gate_any in scenario.get("failed_gates", []) as Array:
		if typeof(failed_gate_any) == TYPE_DICTIONARY and str((failed_gate_any as Dictionary).get("gate", "")) == "scenario_setup":
			setup_failed = true
			break
	if setup_failed:
		metrics["primary_timing"] = PERF_RESULT_CONTRACT.unavailable_metric("UNAVAILABLE", "ms", "scenario setup failed before measurement")
	elif not timing_available:
		metrics["primary_timing"] = PERF_RESULT_CONTRACT.unavailable_metric("UNAVAILABLE", "ms", timing_reason)
		match benchmark_mode:
			"canonical_sim_headless":
				for metric_name in ["simulation_tick_average_ms", "simulation_tick_median_ms", "simulation_tick_p95_ms", "simulation_tick_p99_ms", "simulation_tick_max_ms"]:
					metrics[metric_name] = PERF_RESULT_CONTRACT.unavailable_metric("UNAVAILABLE", "ms", timing_reason)
			"layer_isolation_noncanonical":
				for metric_name in ["layer_iteration_average_ms", "layer_iteration_p95_ms", "layer_iteration_p99_ms", "layer_iteration_max_ms"]:
					metrics[metric_name] = PERF_RESULT_CONTRACT.unavailable_metric("UNAVAILABLE", "ms", timing_reason)
			"render_windowed", "deterministic_windowed_presentation", "static_windowed_deterministic":
				for metric_name in ["display_frame_average_ms", "display_frame_median_ms", "display_frame_p95_ms", "display_frame_p99_ms", "display_frame_max_ms"]:
					metrics[metric_name] = PERF_RESULT_CONTRACT.unavailable_metric("UNAVAILABLE", "ms", timing_reason)
	else:
		match benchmark_mode:
			"canonical_sim_headless":
				metrics["simulation_tick_sample_count"] = PERF_RESULT_CONTRACT.metric("DIRECT", int(collection.get("sample_count", 0)), "count", timing_source)
				metrics["simulation_tick_average_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("average_tick_ms"), "ms", timing_source)
				metrics["simulation_tick_median_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("median_tick_ms"), "ms", timing_source)
				metrics["simulation_tick_p95_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("p95_tick_ms"), "ms", timing_source)
				metrics["simulation_tick_p99_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("p99_tick_ms"), "ms", timing_source)
				metrics["simulation_tick_max_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("max_tick_ms"), "ms", timing_source)
			"layer_isolation_noncanonical":
				metrics["layer_iteration_sample_count"] = PERF_RESULT_CONTRACT.metric("DIRECT", int(collection.get("sample_count", 0)), "count", timing_source)
				metrics["layer_iteration_average_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("average_frame_ms"), "ms", timing_source)
				metrics["layer_iteration_p95_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("p95_frame_ms"), "ms", timing_source)
				metrics["layer_iteration_p99_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("p99_frame_ms"), "ms", timing_source)
				metrics["layer_iteration_max_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("max_frame_ms"), "ms", timing_source)
			"render_windowed", "deterministic_windowed_presentation", "static_windowed_deterministic":
				metrics["display_frame_sample_count"] = PERF_RESULT_CONTRACT.metric("DIRECT", int(collection.get("sample_count", 0)), "count", timing_source)
				metrics["display_frame_average_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("average_frame_ms"), "ms", timing_source)
				metrics["display_frame_median_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("median_frame_ms"), "ms", timing_source)
				metrics["display_frame_p95_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("p95_frame_ms"), "ms", timing_source)
				metrics["display_frame_p99_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("p99_frame_ms"), "ms", timing_source)
				metrics["display_frame_max_ms"] = PERF_RESULT_CONTRACT.metric("DERIVED", scenario.get("max_frame_ms"), "ms", timing_source)
	if benchmark_mode in ["render_windowed", "deterministic_windowed_presentation", "static_windowed_deterministic"] and not setup_failed:
		metrics["renderer_visibility"] = PERF_RESULT_CONTRACT.metric("CONFIGURATION_STATE", (scenario.get("renderer_configuration_state", {}) as Dictionary).duplicate(true), "state", "CanvasItem visibility captured at measurement end")
	else:
		metrics["renderer_visibility"] = PERF_RESULT_CONTRACT.unavailable_metric("CONFIGURATION_STATE", "state", "renderer visibility is not captured as timing in this execution mode")
	if benchmark_mode not in ["render_windowed", "deterministic_windowed_presentation", "static_windowed_deterministic"]:
		metrics["display_frame_delta_ms"] = PERF_RESULT_CONTRACT.unavailable_metric("UNAVAILABLE", "ms", "this mode does not execute a windowed display-frame measurement loop")
	elif not timing_available:
		metrics["display_frame_delta_ms"] = PERF_RESULT_CONTRACT.unavailable_metric("UNAVAILABLE", "ms", timing_reason)
	metrics["gpu_frame_time_ms"] = PERF_RESULT_CONTRACT.unavailable_metric("EXTERNAL_PROFILER_REQUIRED", "ms", "Godot 4.2.2 harness exposes no trustworthy per-frame GPU duration for this runner")
	metrics["render_section_cost_ms"] = PERF_RESULT_CONTRACT.unavailable_metric("UNAVAILABLE", "ms", "renderer visibility is configuration state, not measured renderer section cost")
	return metrics

func _result_environment(gates: Dictionary) -> Dictionary:
	var viewport_size: Vector2i = root.size
	var target_frame_ms: float = float(gates.get("target_frame_ms", 0.0))
	var target_fps: int = int(round(1000.0 / target_frame_ms)) if target_frame_ms > 0.0 else 0
	var video_adapter: String = RenderingServer.get_video_adapter_name().strip_edges()
	if video_adapter.is_empty():
		video_adapter = "UNAVAILABLE_HEADLESS" if DisplayServer.get_name() == "headless" else "UNAVAILABLE"
	return {
		"build": {
			"type": "debug" if OS.is_debug_build() else "release",
			"debug": OS.is_debug_build()
		},
		"renderer": {
			"rendering_method": _effective_renderer_option("rendering-method", "rendering/renderer/rendering_method", "forward_plus"),
			"rendering_method_source": "engine command line override or effective ProjectSettings configuration",
			"rendering_driver": _effective_renderer_option("rendering-driver", "rendering/rendering_device/driver", "default"),
			"rendering_driver_source": "engine command line override or effective ProjectSettings configuration",
			"video_adapter": video_adapter,
			"video_adapter_reason": "headless rendering server does not expose an adapter" if video_adapter == "UNAVAILABLE_HEADLESS" else "",
			"display_server": DisplayServer.get_name(),
			"headless": DisplayServer.get_name() == "headless"
		},
		"viewport": {
			"width": viewport_size.x,
			"height": viewport_size.y,
			"content_scale_factor": root.content_scale_factor,
			"content_scale_width": root.content_scale_size.x,
			"content_scale_height": root.content_scale_size.y,
			"stretch_mode": str(ProjectSettings.get_setting("display/window/stretch/mode", "disabled")),
			"stretch_aspect": str(ProjectSettings.get_setting("display/window/stretch/aspect", "ignore")),
			"render_scale_3d": float(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0))
		},
		"pacing": {
			"benchmark_target_frame_ms": target_frame_ms,
			"benchmark_target_fps": target_fps,
			"engine_max_fps": Engine.max_fps,
			"physics_ticks_per_second": Engine.physics_ticks_per_second,
			"time_scale": Engine.time_scale,
			"vsync_mode": int(DisplayServer.window_get_vsync_mode()),
			"vsync_mode_name": _vsync_mode_name(int(DisplayServer.window_get_vsync_mode()))
		}
	}

func _effective_renderer_option(option_name: String, project_setting: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_args()
	for arg_index in range(args.size()):
		var arg: String = str(args[arg_index])
		var prefix: String = "--%s=" % option_name
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
		if arg == "--%s" % option_name and arg_index + 1 < args.size():
			return str(args[arg_index + 1])
	return str(ProjectSettings.get_setting(project_setting, fallback))

func _vsync_mode_name(mode: int) -> String:
	match mode:
		DisplayServer.VSYNC_DISABLED:
			return "DISABLED"
		DisplayServer.VSYNC_ENABLED:
			return "ENABLED"
		DisplayServer.VSYNC_ADAPTIVE:
			return "ADAPTIVE"
		DisplayServer.VSYNC_MAILBOX:
			return "MAILBOX"
		_:
			return "UNKNOWN_%d" % mode

func _git_metadata() -> Dictionary:
	return {
		"commit": _read_process(["git", "rev-parse", "--short", "HEAD"]).strip_edges(),
		"branch": _read_process(["git", "rev-parse", "--abbrev-ref", "HEAD"]).strip_edges(),
		"dirty": not _read_process(["git", "status", "--porcelain"]).strip_edges().is_empty()
	}

func _machine_metadata() -> Dictionary:
	return {
		"os": OS.get_name(),
		"model_name": OS.get_model_name(),
		"architecture": Engine.get_architecture_name(),
		"processor_count": OS.get_processor_count(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"display_server": DisplayServer.get_name(),
		"headless": DisplayServer.get_name() == "headless"
	}

func _read_process(args: Array) -> String:
	if args.is_empty():
		return ""
	var executable := str(args[0])
	var proc_args: PackedStringArray = PackedStringArray()
	for i in range(1, args.size()):
		proc_args.append(str(args[i]))
	var output: Array = []
	var rc := OS.execute(executable, proc_args, output, true, false)
	if rc != 0:
		return ""
	return "\n".join(output)
