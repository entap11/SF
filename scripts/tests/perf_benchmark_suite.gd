extends SceneTree

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_APPLIER := preload("res://scripts/maps/map_applier.gd")
const ARENA_POLISH_LAYER := preload("res://scripts/renderers/arena_polish_layer.gd")

const DEFAULT_GATES_PATH := "res://data/perf/benchmark_gates.json"
const DEFAULT_OUTPUT_PATH := "res://debug_reports/perf_benchmark_latest.json"
const SCENARIO_OUTPUT_DIR := "res://debug_reports/perf_benchmarks"
const ARENA_SCENE_PATH := "res://scenes/Arena.tscn"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const FRAME_DELTA_SEC: float = 1.0 / 60.0
const SIM_TICK_INTERVAL_SEC: float = 0.1
const RENDER_DISCARD_INITIAL_FRAMES: int = 3

const MAP_QUICK := "res://maps/_future/centerstrike/MAP_centerstrike__SBASE__2p.json"
const MAP_LAYERS := "res://maps/_future/nomansland/MAP_nomansland__545__v08_spine_knife_fight__npc20__p24.json"
const MAP_STRUCTURES := "res://maps/_future/quadfight/MAP_quadfight__SBASE__1p.json"
const MAP_STRESS := "res://maps/_future/nomansland/MAP_nomansland__545__v13_top3_each__npc20__p24.json"

var OpsState: Node = null

func _init() -> void:
	call_deferred("_run_entry")

func _run_entry() -> void:
	OpsState = root.get_node_or_null("/root/OpsState")
	if OpsState == null:
		push_error("perf_benchmark_suite: OpsState autoload is not available")
		quit(2)
		return
	var args: Dictionary = _parse_args()
	var report: Dictionary = await _run_suite(args)
	var output_path := str(args.get("output", DEFAULT_OUTPUT_PATH))
	_write_json(output_path, report)
	for scenario_any in report.get("scenarios", []) as Array:
		var scenario: Dictionary = scenario_any as Dictionary
		_write_json("%s/%s_latest.json" % [SCENARIO_OUTPUT_DIR, str(scenario.get("scenario_id", "unknown"))], scenario)
	print("perf_benchmark_suite: %s" % JSON.stringify(_summary_for_print(report)))
	quit(0 if bool(report.get("pass", false)) else 1)

func _run_suite(args: Dictionary) -> Dictionary:
	var benchmark_mode := str(args.get("mode", "sim_headless")).strip_edges()
	if benchmark_mode.is_empty():
		benchmark_mode = "sim_headless"
	var suite_id := str(args.get("suite", "quick")).strip_edges()
	if suite_id.is_empty():
		suite_id = "quick"
	var gates: Dictionary = _load_json(str(args.get("gates", DEFAULT_GATES_PATH)))
	if gates.is_empty():
		gates = _default_gates()
	var switch_overrides: Dictionary = args.get("switch_overrides", {}) as Dictionary
	var scenario_defs: Array = _scenario_definitions(suite_id, switch_overrides, str(args.get("scenario", "")).strip_edges())
	if args.has("map") and not str(args.get("map", "")).strip_edges().is_empty():
		for scenario_any in scenario_defs:
			var scenario_def: Dictionary = scenario_any as Dictionary
			scenario_def["map_path"] = str(args.get("map", ""))
	var scenarios: Array = []
	for scenario_def_any in scenario_defs:
		var scenario: Dictionary
		var scenario_def: Dictionary = scenario_def_any as Dictionary
		if benchmark_mode == "render_windowed":
			scenario = await _run_render_scenario(scenario_def, benchmark_mode, gates)
		else:
			scenario = await _run_sim_scenario(scenario_def, benchmark_mode, gates)
		scenarios.append(scenario)
	var failed: Array = []
	for scenario_any in scenarios:
		var scenario: Dictionary = scenario_any as Dictionary
		if not bool(scenario.get("pass", false)) and not bool(scenario.get("allowed_failure", false)):
			failed.append(str(scenario.get("scenario_id", "")))
	var report := {
		"report_type": "sf_perf_benchmark_suite",
		"suite_id": suite_id,
		"benchmark_mode": benchmark_mode,
		"generated_at_unix": Time.get_unix_time_from_system(),
		"git": _git_metadata(),
		"godot": Engine.get_version_info(),
		"machine": _machine_metadata(),
		"gates": gates.duplicate(true),
		"switch_overrides": switch_overrides.duplicate(true),
		"scenario_count": scenarios.size(),
		"scenarios": scenarios,
		"pass": failed.is_empty(),
		"failed_scenarios": failed
	}
	var baseline_path := str(args.get("baseline", "")).strip_edges()
	if not baseline_path.is_empty():
		var baseline: Dictionary = _load_json(baseline_path)
		if not baseline.is_empty():
			report["baseline_comparison"] = _compare_reports(baseline, report, gates)
	return report

func _run_sim_scenario(scenario_def: Dictionary, benchmark_mode: String, gates: Dictionary) -> Dictionary:
	var setup_start_usec := Time.get_ticks_usec()
	var setup: Dictionary = await _setup_arena_for_scenario(scenario_def, false)
	if not bool(setup.get("ok", false)):
		return _scenario_error(scenario_def, benchmark_mode, str(setup.get("reason", "setup_failed")), gates)
	var arena: Node = setup.get("arena", null) as Node
	var sim_runner: Node = _arena_sim_runner(arena)
	var state: GameState = OpsState.require_state()
	_prepare_match_for_benchmark()
	_apply_scenario_initial_state(arena, state, scenario_def)
	var setup_ms := float(Time.get_ticks_usec() - setup_start_usec) / 1000.0
	var frames: Array = []
	var hitches: Array = []
	var tick_reports: Array = []
	var command_log: Array = []
	var frame_count: int = int(ceil(float(scenario_def.get("duration_sec", 1.0)) / FRAME_DELTA_SEC))
	var tick_accumulator := 0.0
	var tick_index := 0
	for frame_index in range(frame_count):
		var frame_start_usec := Time.get_ticks_usec()
		tick_accumulator += FRAME_DELTA_SEC
		var last_sections: Dictionary = {}
		while tick_accumulator + 0.000001 >= SIM_TICK_INTERVAL_SEC:
			tick_accumulator -= SIM_TICK_INTERVAL_SEC
			tick_index += 1
			var issued: Array = _issue_scripted_commands(arena, state, scenario_def, tick_index)
			if not issued.is_empty():
				command_log.append({"tick": tick_index, "commands": issued})
			last_sections = _tick_selected_systems(arena, sim_runner, state, scenario_def, SIM_TICK_INTERVAL_SEC)
			tick_reports.append({"tick": tick_index, "phase_times_ms": last_sections.duplicate(true)})
		var frame_ms := float(Time.get_ticks_usec() - frame_start_usec) / 1000.0
		frames.append(frame_ms)
		_add_hitch_if_needed(
			hitches,
			frames.size(),
			tick_index,
			frame_ms,
			"simulation",
			_classification_for_frame(frame_ms, gates, last_sections, {}),
			gates,
			last_sections,
			{}
		)
	var metrics: Dictionary = _frame_metrics(frames)
	var failed_gates: Array = _failed_gates(metrics, hitches.size(), gates)
	var report := _base_scenario_report(scenario_def, benchmark_mode, gates)
	report.merge({
		"duration_sec": float(scenario_def.get("duration_sec", 0.0)),
		"frame_delta_sec": FRAME_DELTA_SEC,
		"sim_tick_interval_sec": SIM_TICK_INTERVAL_SEC,
		"setup_duration_ms": setup_ms,
		"frame_count": frames.size(),
		"measured_frame_count": frames.size(),
		"scripted_command_count": _scripted_command_count_from_log(command_log),
		"scripted_command_ticks": command_log,
		"match": _match_summary(state, tick_index),
		"average_frame_ms": metrics.get("average_frame_ms", 0.0),
		"median_frame_ms": metrics.get("median_frame_ms", 0.0),
		"p95_frame_ms": metrics.get("p95_frame_ms", 0.0),
		"p99_frame_ms": metrics.get("p99_frame_ms", 0.0),
		"p999_frame_ms": metrics.get("p999_frame_ms", 0.0),
		"max_frame_ms": metrics.get("max_frame_ms", 0.0),
		"hitch_threshold_ms": float(gates.get("target_frame_ms", 16.67)),
		"hitch_count": hitches.size(),
		"hitches": hitches,
		"worst_frames": _worst_frames(frames, int(gates.get("worst_frame_limit", 10))),
		"worst_sim_ticks": _worst_sim_ticks(tick_reports, int(gates.get("worst_frame_limit", 10))),
		"pass": failed_gates.is_empty(),
		"failed_gates": failed_gates
	}, true)
	_teardown_node(arena)
	await process_frame
	return report

func _run_render_scenario(scenario_def: Dictionary, benchmark_mode: String, gates: Dictionary) -> Dictionary:
	var setup: Dictionary = await _setup_arena_for_scenario(scenario_def, true)
	if not bool(setup.get("ok", false)):
		return _scenario_error(scenario_def, benchmark_mode, str(setup.get("reason", "setup_failed")), gates)
	var scene_root: Node = setup.get("scene_root", null) as Node
	var arena: Node = setup.get("arena", null) as Node
	var state: GameState = OpsState.require_state()
	_prepare_match_for_benchmark()
	_apply_scenario_initial_state(arena, state, scenario_def)
	_apply_render_isolation(arena, scenario_def)
	if arena.has_method("start_sim"):
		arena.call("start_sim")
	var discard_initial_frames: int = max(0, int(scenario_def.get("render_discard_initial_frames", RENDER_DISCARD_INITIAL_FRAMES)))
	var duration_sec := float(scenario_def.get("duration_sec", 1.0))
	var max_frames: int = int(ceil(duration_sec * 90.0)) + discard_initial_frames
	var frames: Array = []
	var hitches: Array = []
	var command_log: Array = []
	var started_usec := Time.get_ticks_usec()
	var last_usec := started_usec
	var tick_index := 0
	for frame_index in range(max_frames):
		await process_frame
		var now_usec := Time.get_ticks_usec()
		var elapsed_sec := float(now_usec - started_usec) / 1000000.0
		var frame_ms := float(now_usec - last_usec) / 1000.0
		last_usec = now_usec
		if frame_index >= discard_initial_frames:
			frames.append(frame_ms)
			var issued: Array = _issue_scripted_commands(arena, state, scenario_def, tick_index)
			if not issued.is_empty():
				command_log.append({"frame": frame_index + 1, "commands": issued})
			var render_sections: Dictionary = _render_sections_for_frame(arena, frame_ms)
			_add_hitch_if_needed(
				hitches,
				frames.size(),
				tick_index,
				frame_ms,
				"render",
				_classification_for_frame(frame_ms, gates, {}, render_sections),
				gates,
				{},
				render_sections
			)
		tick_index = int(round(elapsed_sec / SIM_TICK_INTERVAL_SEC))
		if elapsed_sec >= duration_sec:
			break
	var metrics: Dictionary = _frame_metrics(frames)
	var failed_gates: Array = _failed_gates(metrics, hitches.size(), gates)
	var report := _base_scenario_report(scenario_def, benchmark_mode, gates)
	report.merge({
		"duration_sec": duration_sec,
		"target_duration_sec": duration_sec,
		"frame_delta_sec": 0.0,
		"sim_tick_interval_sec": SIM_TICK_INTERVAL_SEC,
		"frame_count": frames.size() + discard_initial_frames,
		"measured_frame_count": frames.size(),
		"discarded_initial_frames": discard_initial_frames,
		"scripted_command_count": _scripted_command_count_from_log(command_log),
		"scripted_command_ticks": command_log,
		"match": _match_summary(state, tick_index),
		"average_frame_ms": metrics.get("average_frame_ms", 0.0),
		"median_frame_ms": metrics.get("median_frame_ms", 0.0),
		"p95_frame_ms": metrics.get("p95_frame_ms", 0.0),
		"p99_frame_ms": metrics.get("p99_frame_ms", 0.0),
		"p999_frame_ms": metrics.get("p999_frame_ms", 0.0),
		"max_frame_ms": metrics.get("max_frame_ms", 0.0),
		"hitch_threshold_ms": float(gates.get("target_frame_ms", 16.67)),
		"hitch_count": hitches.size(),
		"hitches": hitches,
		"worst_frames": _worst_frames(frames, int(gates.get("worst_frame_limit", 10))),
		"worst_sim_ticks": [],
		"pass": failed_gates.is_empty(),
		"failed_gates": failed_gates
	}, true)
	_teardown_node(scene_root)
	await process_frame
	return report

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
	var map_path := str(scenario_def.get("map_path", MAP_QUICK))
	var load_result: Dictionary = MAP_LOADER.load_map(map_path)
	if not bool(load_result.get("ok", false)):
		_teardown_node(scene_root)
		return {"ok": false, "reason": "map_load_failed:%s" % str(load_result.get("err", load_result.get("error", "unknown"))), "map_path": map_path}
	var map_data: Dictionary = load_result.get("data", {}) as Dictionary
	MAP_APPLIER.apply_map(arena as Node2D, map_data)
	await process_frame
	await process_frame
	var sim_runner: Node = _arena_sim_runner(arena)
	if sim_runner != null and sim_runner.has_method("bind_state"):
		sim_runner.call("bind_state", OpsState.require_state())
		await process_frame
		await process_frame
	return {"ok": true, "scene_root": scene_root, "arena": arena, "map_path": map_path}

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

func _apply_scenario_initial_state(arena: Node, state: GameState, scenario_def: Dictionary) -> void:
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
	var swarm_count: int = max(0, int(scenario_def.get("initial_swarms", 0)))
	for i in range(swarm_count):
		_issue_swarm_on_active_lane(state, i)
	var route_count: int = max(0, int(scenario_def.get("initial_barracks_routes", 0)))
	if route_count > 0:
		_seed_barracks_routes(state, route_count)
	if arena != null and arena.has_method("mark_render_dirty"):
		arena.call("mark_render_dirty", "perf_benchmark_setup")

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

func _scenario_definitions(suite_id: String, switch_overrides: Dictionary = {}, scenario_filter: String = "") -> Array:
	var scenarios: Array
	match suite_id:
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
		"seed": seed_value,
		"systems": systems.duplicate(),
		"initial_lanes": initial_lanes,
		"initial_swarms": initial_swarms,
		"initial_barracks_routes": initial_barracks_routes,
		"command_interval_ticks": 5,
		"commands_per_burst": commands_per_burst,
		"swarm_burst": initial_swarms,
		"runtime_switches": {
			"arena_polish_comparison_mode": "baseline",
			"premium_polish_enabled": false,
			"tower_visual_scale": 1.0
		},
		"renderers": ["floor", "hive", "lane", "unit", "tower", "wall", "barracks", "polish"]
	}

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
		return float(a.get("dist2", 0.0)) < float(b.get("dist2", 0.0))
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

func _render_sections_for_frame(arena: Node, frame_ms: float) -> Dictionary:
	var sections := {"frame_ms": frame_ms}
	if arena == null:
		return sections
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
		sections[str(key_any)] = 1.0 if node is CanvasItem and (node as CanvasItem).visible else 0.0
	return sections

func _base_scenario_report(scenario_def: Dictionary, benchmark_mode: String, gates: Dictionary) -> Dictionary:
	return {
		"scenario_id": str(scenario_def.get("scenario_id", "unknown")),
		"benchmark_mode": benchmark_mode,
		"seed": int(scenario_def.get("seed", 0)),
		"map_path": str(scenario_def.get("map_path", "")),
		"systems": (scenario_def.get("systems", []) as Array).duplicate(true),
		"runtime_switches": (scenario_def.get("runtime_switches", {}) as Dictionary).duplicate(true),
		"renderers": (scenario_def.get("renderers", []) as Array).duplicate(true),
		"allowed_failure": bool(scenario_def.get("allowed_failure", false)),
		"target_frame_ms": float(gates.get("target_frame_ms", 16.67)),
		"scripted_command_count": 0
	}

func _scenario_error(scenario_def: Dictionary, benchmark_mode: String, reason: String, gates: Dictionary) -> Dictionary:
	var report := _base_scenario_report(scenario_def, benchmark_mode, gates)
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
		"hitch_threshold_ms": float(gates.get("target_frame_ms", 16.67)),
		"hitch_count": 0,
		"hitches": [],
		"worst_frames": [],
		"worst_sim_ticks": [],
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

func _add_hitch_if_needed(hitches: Array, frame: int, tick: int, duration_ms: float, phase: String, classification: String, gates: Dictionary, sim_sections: Dictionary, render_sections: Dictionary) -> void:
	var threshold := float(gates.get("target_frame_ms", 16.67))
	if duration_ms <= threshold:
		return
	hitches.append({
		"frame": frame,
		"tick": tick,
		"duration_ms": duration_ms,
		"phase": phase,
		"classification": classification,
		"top_sim_sections": _top_sections(sim_sections, 5),
		"top_render_sections": _top_sections(render_sections, 5)
	})

func _classification_for_frame(frame_ms: float, gates: Dictionary, sim_sections: Dictionary, render_sections: Dictionary) -> String:
	if frame_ms <= float(gates.get("target_frame_ms", 16.67)):
		return "normal_frame"
	var sim_total := float(sim_sections.get("total_ms", 0.0))
	var render_total := _sum_values(render_sections)
	if render_total > sim_total and render_total > 1.0:
		return "render_work"
	if sim_total > 1.0:
		return "sim_work"
	return "frame_pacing_or_external"

func _frame_metrics(values: Array) -> Dictionary:
	return {
		"average_frame_ms": _avg(values),
		"median_frame_ms": _percentile(values, 0.5),
		"p95_frame_ms": _percentile(values, 0.95),
		"p99_frame_ms": _percentile(values, 0.99),
		"p999_frame_ms": _percentile(values, 0.999),
		"max_frame_ms": _max(values)
	}

func _failed_gates(metrics: Dictionary, hitch_count: int, gates: Dictionary) -> Array:
	var failed: Array = []
	if float(metrics.get("average_frame_ms", 0.0)) > float(gates.get("target_frame_ms", 16.67)):
		failed.append({"gate": "average_frame_ms", "actual": metrics.get("average_frame_ms", 0.0), "limit": gates.get("target_frame_ms", 16.67)})
	if float(metrics.get("p95_frame_ms", 0.0)) > float(gates.get("p95_max_ms", 22.0)):
		failed.append({"gate": "p95_frame_ms", "actual": metrics.get("p95_frame_ms", 0.0), "limit": gates.get("p95_max_ms", 22.0)})
	if float(metrics.get("p99_frame_ms", 0.0)) > float(gates.get("p99_max_ms", 33.33)):
		failed.append({"gate": "p99_frame_ms", "actual": metrics.get("p99_frame_ms", 0.0), "limit": gates.get("p99_max_ms", 33.33)})
	if float(metrics.get("max_frame_ms", 0.0)) > float(gates.get("max_frame_ms", 50.0)):
		failed.append({"gate": "max_frame_ms", "actual": metrics.get("max_frame_ms", 0.0), "limit": gates.get("max_frame_ms", 50.0)})
	if hitch_count > int(gates.get("max_hitches", 0)):
		failed.append({"gate": "hitch_count", "actual": hitch_count, "limit": gates.get("max_hitches", 0)})
	return failed

func _worst_frames(values: Array, limit: int) -> Array:
	var out: Array = []
	for i in range(values.size()):
		out.append({"frame": i + 1, "duration_ms": float(values[i])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("duration_ms", 0.0)) > float(b.get("duration_ms", 0.0))
	)
	return out.slice(0, mini(limit, out.size()))

func _worst_sim_ticks(reports: Array, limit: int) -> Array:
	var out: Array = []
	for report_any in reports:
		var report: Dictionary = report_any as Dictionary
		var sections: Dictionary = report.get("phase_times_ms", {}) as Dictionary
		out.append({
			"tick": int(report.get("tick", 0)),
			"total_ms": float(sections.get("total_ms", 0.0)),
			"top_sim_sections": _top_sections(sections, 5)
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("total_ms", 0.0)) > float(b.get("total_ms", 0.0))
	)
	return out.slice(0, mini(limit, out.size()))

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
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()

func _summary_for_print(report: Dictionary) -> Dictionary:
	var scenarios: Array = []
	for scenario_any in report.get("scenarios", []) as Array:
		var scenario: Dictionary = scenario_any as Dictionary
		scenarios.append({
			"scenario_id": scenario.get("scenario_id", ""),
			"pass": scenario.get("pass", false),
			"allowed_failure": scenario.get("allowed_failure", false),
			"average_frame_ms": scenario.get("average_frame_ms", 0.0),
			"p95_frame_ms": scenario.get("p95_frame_ms", 0.0),
			"p99_frame_ms": scenario.get("p99_frame_ms", 0.0),
			"max_frame_ms": scenario.get("max_frame_ms", 0.0),
			"hitch_count": scenario.get("hitch_count", 0)
		})
	return {
		"pass": report.get("pass", false),
		"suite_id": report.get("suite_id", ""),
		"benchmark_mode": report.get("benchmark_mode", ""),
		"scenarios": scenarios
	}

func _compare_reports(baseline: Dictionary, current: Dictionary, gates: Dictionary) -> Dictionary:
	var baseline_by_id: Dictionary = _scenarios_by_id(baseline)
	var current_by_id: Dictionary = _scenarios_by_id(current)
	var ids: Array = current_by_id.keys()
	ids.sort()
	var out: Dictionary = {"status": "PASS", "scenarios": []}
	for id_any in ids:
		var scenario_id := str(id_any)
		var base: Dictionary = baseline_by_id.get(scenario_id, {}) as Dictionary
		var cur: Dictionary = current_by_id.get(scenario_id, {}) as Dictionary
		var rows: Array = []
		var status := "PASS"
		for key in ["average_frame_ms", "p95_frame_ms", "p99_frame_ms", "max_frame_ms", "hitch_count"]:
			var base_value := float(base.get(key, 0.0))
			var cur_value := float(cur.get(key, 0.0))
			var regression := _regression_percent(base_value, cur_value)
			var marker := _marker_for_regression(regression, gates)
			if marker == "FAIL" and not bool(cur.get("allowed_failure", false)):
				status = "FAIL"
				out["status"] = "FAIL"
			elif marker == "WARN" and status == "PASS":
				status = "WARN"
				if str(out.get("status", "PASS")) == "PASS":
					out["status"] = "WARN"
			rows.append({"metric": key, "baseline": base_value, "current": cur_value, "regression_percent": regression, "status": marker})
		out["scenarios"].append({"scenario_id": scenario_id, "status": status, "metrics": rows})
	return out

func _scenarios_by_id(report: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for scenario_any in report.get("scenarios", []) as Array:
		var scenario: Dictionary = scenario_any as Dictionary
		out[str(scenario.get("scenario_id", ""))] = scenario
	return out

func _marker_for_regression(regression_percent: float, gates: Dictionary) -> String:
	if regression_percent >= float(gates.get("fail_regression_percent", 20.0)):
		return "FAIL"
	if regression_percent >= float(gates.get("warn_regression_percent", 10.0)):
		return "WARN"
	return "PASS"

func _regression_percent(baseline_value: float, current_value: float) -> float:
	if baseline_value <= 0.000001:
		return 0.0 if current_value <= 0.000001 else 9999.0
	return ((current_value - baseline_value) / baseline_value) * 100.0

func _parse_args() -> Dictionary:
	var out := {
		"mode": "sim_headless",
		"suite": "quick",
		"gates": DEFAULT_GATES_PATH,
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
		elif arg.begins_with("--scenario="):
			out["scenario"] = arg.trim_prefix("--scenario=")
		elif arg == "--scenario" and i + 1 < args.size():
			i += 1
			out["scenario"] = str(args[i])
		elif arg.begins_with("--gates="):
			out["gates"] = arg.trim_prefix("--gates=")
		elif arg == "--gates" and i + 1 < args.size():
			i += 1
			out["gates"] = str(args[i])
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

func _default_gates() -> Dictionary:
	return {
		"target_fps": 60,
		"target_frame_ms": 16.67,
		"p95_max_ms": 22.0,
		"p99_max_ms": 33.33,
		"max_frame_ms": 50.0,
		"max_hitches": 0,
		"worst_frame_limit": 10,
		"warn_regression_percent": 10.0,
		"fail_regression_percent": 20.0
	}

func _git_metadata() -> Dictionary:
	return {
		"commit": _read_process(["git", "rev-parse", "--short", "HEAD"]).strip_edges(),
		"branch": _read_process(["git", "rev-parse", "--abbrev-ref", "HEAD"]).strip_edges(),
		"dirty": not _read_process(["git", "status", "--porcelain"]).strip_edges().is_empty()
	}

func _machine_metadata() -> Dictionary:
	return {
		"os": OS.get_name(),
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
