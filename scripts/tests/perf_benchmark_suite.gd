extends SceneTree

const MAP_APPLIER := preload("res://scripts/maps/map_applier.gd")
const ARENA_POLISH_LAYER := preload("res://scripts/renderers/arena_polish_layer.gd")
const PERF_RUN_POLICY := preload("res://scripts/tests/perf/perf_run_policy.gd")
const PERF_FIXTURE_CATALOG := preload("res://scripts/tests/perf/perf_fixture_catalog.gd")
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
const DEFAULT_OUTPUT_PATH := "res://debug_reports/perf_benchmark_latest.json"
const SCENARIO_OUTPUT_DIR := "res://debug_reports/perf_benchmarks"
const ARENA_SCENE_PATH := "res://scenes/Arena.tscn"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const FRAME_DELTA_SEC: float = 1.0 / 60.0
const SIM_TICK_INTERVAL_SEC: float = 0.1
const RENDER_DISCARD_INITIAL_FRAMES: int = 3

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
var _interrupted_isolation_snapshot: Dictionary = {}
var _interrupted_scene_root: Node = null
var _interrupted_arena: Node = null

func _init() -> void:
	call_deferred("_run_entry")

func _run_entry() -> void:
	var args: Dictionary = _parse_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not PERF_RUN_POLICY.enabled_for_runtime(OS.is_debug_build(), user_args):
		push_error("perf_benchmark_suite: %s" % PERF_RUN_POLICY.refusal_reason(OS.is_debug_build(), user_args))
		quit(2)
		return
	set_meta("sf_perf_harness_active", true)
	OpsState = root.get_node_or_null("/root/OpsState")
	if OpsState == null:
		push_error("perf_benchmark_suite: OpsState autoload is not available")
		remove_meta("sf_perf_harness_active")
		quit(2)
		return
	if not _set_analytics_harness_isolation(true):
		push_error("perf_benchmark_suite: analytics_isolation_unavailable")
		remove_meta("sf_perf_harness_active")
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
		"fixture_catalog": fixture_catalog_identity,
		"gates": gates.duplicate(true),
		"gate_source": str(gate_result.get("source", "")),
		"switch_overrides": switch_overrides.duplicate(true),
		"scenario_count": scenarios.size(),
		"scenarios": scenarios,
		"determinism": determinism,
		"isolation": isolation,
		"backend_isolation": backend_isolation,
		"collector_calibration": collector_calibration,
		"unit_scale_diagnostic": unit_scale_diagnostic,
		"pass": failed.is_empty() and bool(determinism.get("pass", true)) and bool(isolation.get("pass", true)) and bool(backend_isolation.get("pass", false)) and (collector_calibration.is_empty() or bool(collector_calibration.get("pass", false))),
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
	var unit_count_min: int = _runtime_unit_count(state) if target_units > 0 else 0
	var unit_count_max: int = unit_count_min
	var render_monitor_peaks: Dictionary = {
		"draw_calls": 0,
		"rendered_objects": 0,
		"rendered_primitives": 0
	}
	for frame_number in range(1, adapter.total_frames() + 1):
		var frame_start_usec: int = Time.get_ticks_usec()
		if adapter.should_tick(frame_number):
			tick_index = adapter.tick_number_for_frame(frame_number)
			var issued: Array = _issue_commands_for_tick(arena, state, scenario_def, tick_index)
			if not issued.is_empty():
				command_log.append({"tick": tick_index, "commands": issued})
			sim_runner.call("_tick", SIM_TICK_INTERVAL_SEC)
		await process_frame
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
	var final_unit_count: int = _runtime_unit_count(state)
	if target_units > 0 and (unit_count_min != target_units or unit_count_max != target_units or final_unit_count != target_units):
		integrity_failures.append("unit_count_measurement_invariant_failed")
	var renderer_pool_end: Dictionary = _unit_renderer_pool_snapshot(arena)
	var renderer_pool_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(_stable_pool_identity(renderer_pool_end)) if target_units > 0 else ""
	if target_units > 0 and int(renderer_pool_end.get("pool_expansions", -1)) != int((unit_scale_setup.get("renderer_pool_before", {}) as Dictionary).get("pool_expansions", -2)):
		integrity_failures.append("unexpected_renderer_pool_expansion")
	if target_units > 0 and int(renderer_pool_end.get("pool_misses", -1)) != int((unit_scale_setup.get("renderer_pool_before", {}) as Dictionary).get("pool_misses", -2)):
		integrity_failures.append("unexpected_renderer_pool_miss")
	if target_units > 0 and int(renderer_pool_end.get("active_pooled_objects", -1)) != target_units:
		integrity_failures.append("renderer_active_count_mismatch")
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
		"unit_count_window": {
			"target": target_units,
			"start": int(unit_scale_setup.get("actual_units", 0)) if target_units > 0 else 0,
			"minimum": unit_count_min,
			"maximum": unit_count_max,
			"end": final_unit_count,
			"invariant": target_units <= 0 or (unit_count_min == target_units and unit_count_max == target_units and final_unit_count == target_units)
		},
		"unit_injection_hash": str(unit_scale_setup.get("injection_hash", "")),
		"lane_setup_hash": str(unit_scale_setup.get("lane_setup_hash", "")),
		"renderer_pool_telemetry": renderer_pool_end,
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
	_apply_project_switches(scenario_def)
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

func _apply_project_switches(scenario_def: Dictionary) -> void:
	var switches: Dictionary = scenario_def.get("runtime_switches", {}) as Dictionary
	if switches.has("arena_polish_comparison_mode"):
		ARENA_POLISH_LAYER.apply_comparison_mode(str(switches.get("arena_polish_comparison_mode", "settings")))
	if switches.has("premium_polish_enabled"):
		ProjectSettings.set_setting("swarmfront/arena/premium_polish_enabled", bool(switches.get("premium_polish_enabled", false)))
	if switches.has("tower_visual_scale"):
		ProjectSettings.set_setting("swarmfront/arena/tower_visual_scale", float(switches.get("tower_visual_scale", 1.0)))

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
		"floor": "MapRoot/FloorRenderer",
		"hive": "MapRoot/HiveRenderer",
		"lane": "MapRoot/LaneRenderer",
		"unit": "PoolsRoot/UnitRenderer",
		"tower": "MapRoot/TowerRenderer",
		"wall": "WallRenderer",
		"barracks": "MapRoot/BarracksRenderer",
		"polish": "MapRoot/ArenaPolishLayer"
	}
	for key_any in paths.keys():
		var key := str(key_any)
		var node: Node = arena.get_node_or_null(str(paths[key_any]))
		if node is CanvasItem:
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
		"wall_visible": "WallRenderer",
		"polish_visible": "MapRoot/ArenaPolishLayer"
	}
	for key_any in renderer_paths.keys():
		var node: Node = arena.get_node_or_null(str(renderer_paths[key_any]))
		state[str(key_any)] = bool(node is CanvasItem and (node as CanvasItem).visible)
	return state

func _base_scenario_report(scenario_def: Dictionary, benchmark_mode: String, gates: Dictionary) -> Dictionary:
	var fixture_id: String = str(scenario_def.get("fixture_id", scenario_def.get("scenario_id", "unknown")))
	var map_content_hash: String = str(scenario_def.get("_preflight_map_content_hash", ""))
	return {
		"scenario_id": str(scenario_def.get("scenario_id", "unknown")),
		"fixture_id": fixture_id,
		"fixture_version": int(scenario_def.get("fixture_version", 1)),
		"catalog_fixture_registered": bool(scenario_def.get("catalog_fixture_registered", false)),
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
	return report

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
	if _interrupted_arena != null and is_instance_valid(_interrupted_arena) and _interrupted_arena.has_method("clear_perf_match_seed_override"):
		_interrupted_arena.call("clear_perf_match_seed_override")
	if OpsState != null and OpsState.has_method("set_match_telemetry_collector"):
		OpsState.call("set_match_telemetry_collector", null)
	if _interrupted_scene_root != null and is_instance_valid(_interrupted_scene_root):
		_interrupted_scene_root.process_mode = Node.PROCESS_MODE_DISABLED
		_interrupted_scene_root.free()
	_free_fixture_root_additions(_interrupted_isolation_snapshot)
	PERF_ISOLATION_GUARD.release_fixture_state(_interrupted_isolation_snapshot, OpsState)
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
	if _analytics_isolation_active:
		_set_analytics_harness_isolation(false)
		_analytics_isolation_active = false
	if has_meta("sf_perf_harness_active"):
		remove_meta("sf_perf_harness_active")

func _finalize() -> void:
	_recover_interrupted_repetition()
	_cleanup_entry_state()

func _prime_harness_shared_services() -> void:
	SPRITE_REGISTRY.get_instance()
	await process_frame
	await process_frame

func _set_analytics_harness_isolation(enabled: bool) -> bool:
	var analytics: Node = root.get_node_or_null("/root/AnalyticsClient")
	return analytics != null \
		and analytics.has_method("set_perf_harness_isolation") \
		and bool(analytics.call("set_perf_harness_isolation", enabled))

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
		var required_repetitions: int = 3 if fixture_id in ["PHASE0_INTEGRITY_CENTERSTRIKE_V1", "P1B_WINDOWED_ADAPTER_PROBE_V1", "P1D_NORMAL_MATCH_PILOT_V1"] or bool(first_repetition.get("catalog_fixture_registered", false)) else 1
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
