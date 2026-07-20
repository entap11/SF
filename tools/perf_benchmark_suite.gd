extends SceneTree

const MapLoader := preload("res://scripts/maps/map_loader.gd")
const MapApplier := preload("res://scripts/maps/map_applier.gd")
const MapCatalog := preload("res://scripts/dev/map_catalog.gd")

const DEFAULT_GATES_PATH := "res://data/perf/benchmark_gates.json"
const DEFAULT_OUTPUT_PATH := "res://debug_reports/perf_benchmark_latest.json"
const SCENARIO_OUTPUT_DIR := "res://debug_reports/perf_benchmarks"
const ARENA_SCENE_PATH := "res://scenes/Arena.tscn"
const DEFAULT_START_TIMEOUT_MS := 15000

var _failures: Array[String] = []

func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var report: Dictionary = await _run_suite(args)
	var output_path := str(args.get("output", DEFAULT_OUTPUT_PATH))
	_write_json(output_path, report)
	for scenario_any in report.get("scenarios", []) as Array:
		var scenario: Dictionary = scenario_any as Dictionary
		_write_json("%s/%s_latest.json" % [SCENARIO_OUTPUT_DIR, str(scenario.get("scenario_id", "unknown"))], scenario)
	print("perf_benchmark_suite: %s" % JSON.stringify(_summary_for_print(report)))
	quit(0 if bool(report.get("pass", false)) else 1)

func _run_suite(args: Dictionary) -> Dictionary:
	var suite_id := str(args.get("suite", "quick")).strip_edges()
	if suite_id.is_empty():
		suite_id = "quick"
	var benchmark_mode := str(args.get("mode", "render_windowed")).strip_edges()
	if benchmark_mode.is_empty():
		benchmark_mode = "render_windowed"
	var gates: Dictionary = _load_json(str(args.get("gates", DEFAULT_GATES_PATH)))
	if gates.is_empty():
		gates = _default_gates()
	var map_path := str(args.get("map", "")).strip_edges()
	if map_path.is_empty():
		map_path = _default_map_path()
	var scenarios: Array = _scenario_definitions(suite_id, str(args.get("scenario", "")).strip_edges())
	var results: Array = []
	for scenario_any in scenarios:
		var scenario_def: Dictionary = scenario_any as Dictionary
		results.append(await _run_arena_scenario(scenario_def, benchmark_mode, gates, map_path))
	var failed: Array = []
	for result_any in results:
		var result: Dictionary = result_any as Dictionary
		if not bool(result.get("pass", false)):
			failed.append(str(result.get("scenario_id", "")))
	return {
		"report_type": "sf_perf_benchmark_suite",
		"suite_id": suite_id,
		"benchmark_mode": benchmark_mode,
		"generated_at_unix": Time.get_unix_time_from_system(),
		"godot": Engine.get_version_info(),
		"machine": _machine_metadata(),
		"gates": gates.duplicate(true),
		"map_path": map_path,
		"scenario_count": results.size(),
		"scenarios": results,
		"pass": failed.is_empty(),
		"failed_scenarios": failed,
		"failures": _failures.duplicate()
	}

func _run_arena_scenario(scenario_def: Dictionary, benchmark_mode: String, gates: Dictionary, map_path: String) -> Dictionary:
	if benchmark_mode != "render_windowed" and benchmark_mode != "arena_headless":
		return _scenario_error(scenario_def, benchmark_mode, map_path, gates, "unsupported_mode")
	var arena_scene: PackedScene = load(ARENA_SCENE_PATH) as PackedScene
	if arena_scene == null:
		return _scenario_error(scenario_def, benchmark_mode, map_path, gates, "arena_scene_load_failed")
	var map_result: Dictionary = MapLoader.load_map(map_path)
	if not bool(map_result.get("ok", false)):
		return _scenario_error(scenario_def, benchmark_mode, map_path, gates, "map_load_failed:%s" % str(map_result.get("err", map_result.get("error", "unknown"))))
	var arena := arena_scene.instantiate() as Node2D
	if arena == null:
		return _scenario_error(scenario_def, benchmark_mode, map_path, gates, "arena_instantiate_failed")
	root.add_child(arena)
	await process_frame
	await process_frame
	MapApplier.apply_map(arena, map_result.get("data", {}) as Dictionary)
	if _ops_state() != null and _ops_state().has_method("reset_runtime_telemetry"):
		_ops_state().call("reset_runtime_telemetry")
	if arena.has_method("start_sim"):
		arena.call("start_sim")
	var running_ok: bool = await _wait_for_running(int(scenario_def.get("start_timeout_ms", DEFAULT_START_TIMEOUT_MS)))
	if not running_ok:
		await _cleanup_arena(arena)
		return _scenario_error(scenario_def, benchmark_mode, map_path, gates, "match_not_running")
	_disable_bots()
	var warmup_frames: int = max(0, int(scenario_def.get("warmup_frames", 2)))
	for _i in range(warmup_frames):
		await process_frame
	var frames: Array = []
	var hitches: Array = []
	var worst_runtime_samples: Array = []
	var pairs: Array = []
	var pair_count: int = int(scenario_def.get("pairs", 0))
	if pair_count > 0:
		pairs = _pick_duel_pairs(pair_count)
		if pairs.is_empty():
			await _cleanup_arena(arena)
			return _scenario_error(scenario_def, benchmark_mode, map_path, gates, "no_opposing_pairs")
		_ensure_pairs_active(pairs)
	var duration_sec: float = float(scenario_def.get("duration_sec", 1.0))
	var reapply_ms: int = int(scenario_def.get("reapply_ms", 1000))
	var end_us: int = Time.get_ticks_usec() + int(round(duration_sec * 1000000.0))
	var last_frame_us: int = Time.get_ticks_usec()
	var last_reapply_ms: int = 0
	var frame_index: int = 0
	while Time.get_ticks_usec() < end_us:
		await process_frame
		frame_index += 1
		var now_us: int = Time.get_ticks_usec()
		var frame_ms: float = float(now_us - last_frame_us) / 1000.0
		last_frame_us = now_us
		frames.append(frame_ms)
		var telemetry: Dictionary = _runtime_telemetry_snapshot()
		_add_worst_runtime_sample(worst_runtime_samples, frame_index, frame_ms, telemetry, 10)
		if frame_ms > float(gates.get("target_frame_ms", 33.33)):
			hitches.append({
				"frame": frame_index,
				"duration_ms": frame_ms,
				"classification": _classification_for_frame(frame_ms, telemetry),
				"top_sim_sections": _top_sections((telemetry.get("sim_phase_costs_ms", {}) as Dictionary), 5),
				"runtime_telemetry": telemetry
			})
		if pair_count > 0:
			var now_ms: int = Time.get_ticks_msec()
			if now_ms - last_reapply_ms >= reapply_ms:
				last_reapply_ms = now_ms
				if not _ensure_pairs_active(pairs):
					pairs = _pick_duel_pairs(pair_count)
					_ensure_pairs_active(pairs)
	var metrics: Dictionary = _frame_metrics(frames)
	var failed_gates: Array = _failed_gates(metrics, hitches.size(), gates)
	var final_telemetry: Dictionary = _runtime_telemetry_snapshot()
	var final_phase: int = _match_phase()
	await _cleanup_arena(arena)
	return {
		"scenario_id": str(scenario_def.get("scenario_id", "unknown")),
		"benchmark_mode": benchmark_mode,
		"map_path": map_path,
		"duration_sec": duration_sec,
		"frame_count": frames.size(),
		"warmup_frames": warmup_frames,
		"pairs": pair_count,
		"reapply_ms": reapply_ms,
		"average_frame_ms": metrics.get("average_frame_ms", 0.0),
		"median_frame_ms": metrics.get("median_frame_ms", 0.0),
		"p95_frame_ms": metrics.get("p95_frame_ms", 0.0),
		"p99_frame_ms": metrics.get("p99_frame_ms", 0.0),
		"p999_frame_ms": metrics.get("p999_frame_ms", 0.0),
		"max_frame_ms": metrics.get("max_frame_ms", 0.0),
		"hitch_threshold_ms": float(gates.get("target_frame_ms", 33.33)),
		"hitch_count": hitches.size(),
		"hitches": hitches,
		"worst_frames": _worst_frames(frames, 10),
		"worst_runtime_samples": worst_runtime_samples,
		"runtime_telemetry": final_telemetry,
		"match": {"phase": final_phase},
		"pass": failed_gates.is_empty(),
		"failed_gates": failed_gates
	}

func _scenario_definitions(suite_id: String, scenario_filter: String = "") -> Array:
	var scenarios: Array = []
	match suite_id:
		"sprint_layers":
			scenarios = [
				_scenario_def("boot_5s", 5.0, 0, 1000),
				_scenario_def("duel_10s", 10.0, 2, 1000),
				_scenario_def("pressure_20s", 20.0, 4, 500),
				_scenario_def("stress_30s", 30.0, 8, 250)
			]
		_:
			scenarios = [
				_scenario_def("boot_5s", 5.0, 0, 1000),
				_scenario_def("duel_10s", 10.0, 2, 1000),
				_scenario_def("pressure_20s", 20.0, 4, 500)
			]
	if scenario_filter.strip_edges().is_empty():
		return scenarios
	var filtered: Array = []
	for scenario_any in scenarios:
		var scenario: Dictionary = scenario_any as Dictionary
		if str(scenario.get("scenario_id", "")) == scenario_filter:
			filtered.append(scenario)
	return filtered

func _scenario_def(scenario_id: String, duration_sec: float, pairs: int, reapply_ms: int) -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"duration_sec": duration_sec,
		"pairs": pairs,
		"reapply_ms": reapply_ms,
		"warmup_frames": 2,
		"start_timeout_ms": DEFAULT_START_TIMEOUT_MS
	}

func _wait_for_running(timeout_ms: int) -> bool:
	var ops_state: Node = _ops_state()
	if ops_state == null:
		return false
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		if int(ops_state.get("match_phase")) == int(ops_state.MatchPhase.RUNNING):
			return true
		await process_frame
	return false

func _pick_duel_pairs(max_pairs: int) -> Array:
	var ops_state: Node = _ops_state()
	if ops_state == null or not ops_state.has_method("get_state"):
		return []
	var st: Variant = ops_state.call("get_state")
	if st == null:
		return []
	var candidates: Array = []
	for src_any in st.get("hives"):
		var src_hive = src_any
		if src_hive == null:
			continue
		var src_owner: int = int(src_hive.get("owner_id"))
		if src_owner <= 0:
			continue
		for dst_any in st.get("hives"):
			var dst_hive = dst_any
			if dst_hive == null:
				continue
			var src_id: int = int(src_hive.get("id"))
			var dst_id: int = int(dst_hive.get("id"))
			if src_id == dst_id:
				continue
			var dst_owner: int = int(dst_hive.get("owner_id"))
			if dst_owner == src_owner:
				continue
			if st.has_method("can_connect") and not bool(st.call("can_connect", src_id, dst_id)):
				continue
			var src_pos: Vector2 = st.call("hive_world_pos_by_id", src_id) as Vector2
			var dst_pos: Vector2 = st.call("hive_world_pos_by_id", dst_id) as Vector2
			candidates.append({"src": src_id, "dst": dst_id, "len": src_pos.distance_to(dst_pos)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("len", 0.0)) > float(b.get("len", 0.0))
	)
	return candidates.slice(0, mini(max_pairs, candidates.size()))

func _ensure_pairs_active(pairs: Array) -> bool:
	var ops_state: Node = _ops_state()
	if ops_state == null or not ops_state.has_method("get_state"):
		return false
	var st: Variant = ops_state.call("get_state")
	if st == null:
		return false
	var kept: int = 0
	for pair_any in pairs:
		var pair: Dictionary = pair_any as Dictionary
		var src: int = int(pair.get("src", -1))
		var dst: int = int(pair.get("dst", -1))
		if src <= 0 or dst <= 0 or src == dst:
			continue
		if st.has_method("intent_is_on") and bool(st.call("intent_is_on", src, dst)):
			kept += 1
		elif ops_state.has_method("apply_lane_intent"):
			ops_state.call("apply_lane_intent", src, dst, "attack")
			kept += 1
	return kept > 0

func _disable_bots() -> void:
	var ops_state: Node = _ops_state()
	if ops_state == null or not ops_state.has_method("set_bot_profile"):
		return
	for seat in [1, 2, 3, 4]:
		ops_state.call("set_bot_profile", int(seat), {"enabled": false})

func _ops_state() -> Node:
	return root.get_node_or_null("OpsState")

func _match_phase() -> int:
	var ops_state: Node = _ops_state()
	return int(ops_state.get("match_phase")) if ops_state != null else -1

func _runtime_telemetry_snapshot() -> Dictionary:
	var ops_state: Node = _ops_state()
	if ops_state == null or not ops_state.has_method("get_runtime_telemetry_snapshot"):
		return {}
	return (ops_state.call("get_runtime_telemetry_snapshot") as Dictionary).duplicate(true)

func _cleanup_arena(arena: Node) -> void:
	if arena != null and is_instance_valid(arena):
		arena.queue_free()
	await process_frame
	await process_frame

func _classification_for_frame(frame_ms: float, telemetry: Dictionary) -> String:
	if frame_ms <= 33.5:
		return "normal_frame"
	var sim_ms: float = float(telemetry.get("sim_ms", 0.0))
	if sim_ms > 1.0 and sim_ms / frame_ms >= 0.35:
		return "sim_work"
	return "frame_pacing_or_render_or_external"

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
	if float(metrics.get("average_frame_ms", 0.0)) > float(gates.get("target_frame_ms", 33.33)):
		failed.append({"gate": "average_frame_ms", "actual": metrics.get("average_frame_ms", 0.0), "limit": gates.get("target_frame_ms", 33.33)})
	if float(metrics.get("p99_frame_ms", 0.0)) > float(gates.get("p99_max_ms", 41.67)):
		failed.append({"gate": "p99_frame_ms", "actual": metrics.get("p99_frame_ms", 0.0), "limit": gates.get("p99_max_ms", 41.67)})
	if float(metrics.get("max_frame_ms", 0.0)) > float(gates.get("max_frame_ms", 55.0)):
		failed.append({"gate": "max_frame_ms", "actual": metrics.get("max_frame_ms", 0.0), "limit": gates.get("max_frame_ms", 55.0)})
	if hitch_count > int(gates.get("max_hitches", 0)):
		failed.append({"gate": "hitch_count", "actual": hitch_count, "limit": gates.get("max_hitches", 0)})
	return failed

func _add_worst_runtime_sample(samples: Array, frame_index: int, frame_ms: float, telemetry: Dictionary, limit: int) -> void:
	samples.append({
		"frame": frame_index,
		"duration_ms": frame_ms,
		"sim_ms": float(telemetry.get("sim_ms", 0.0)),
		"sim_ms_max": float(telemetry.get("sim_ms_max", 0.0)),
		"sim_phase_hotspot": str(telemetry.get("sim_phase_hotspot", "")),
		"sim_phase_hotspot_ms": float(telemetry.get("sim_phase_hotspot_ms", 0.0)),
		"top_sim_sections": _top_sections((telemetry.get("sim_phase_costs_ms", {}) as Dictionary), 5)
	})
	samples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("duration_ms", 0.0)) > float(b.get("duration_ms", 0.0))
	)
	if samples.size() > limit:
		samples.resize(limit)

func _top_sections(sections: Dictionary, limit: int) -> Array:
	var out: Array = []
	for key_any in sections.keys():
		var value: float = float(sections.get(key_any, 0.0))
		if value <= 0.0:
			continue
		out.append({"section": str(key_any), "ms": value})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("ms", 0.0)) > float(b.get("ms", 0.0))
	)
	return out.slice(0, mini(limit, out.size()))

func _worst_frames(values: Array, limit: int) -> Array:
	var out: Array = []
	for i in range(values.size()):
		out.append({"frame": i + 1, "duration_ms": float(values[i])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("duration_ms", 0.0)) > float(b.get("duration_ms", 0.0))
	)
	return out.slice(0, mini(limit, out.size()))

func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value_any in values:
		total += float(value_any)
	return total / float(values.size())

func _percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(percentile * float(sorted.size())) - 1), 0, sorted.size() - 1)
	return float(sorted[index])

func _max(values: Array) -> float:
	var out := 0.0
	for value_any in values:
		out = maxf(out, float(value_any))
	return out

func _scenario_error(scenario_def: Dictionary, benchmark_mode: String, map_path: String, gates: Dictionary, reason: String) -> Dictionary:
	return {
		"scenario_id": str(scenario_def.get("scenario_id", "unknown")),
		"benchmark_mode": benchmark_mode,
		"map_path": map_path,
		"duration_sec": 0.0,
		"frame_count": 0,
		"average_frame_ms": 0.0,
		"median_frame_ms": 0.0,
		"p95_frame_ms": 0.0,
		"p99_frame_ms": 0.0,
		"p999_frame_ms": 0.0,
		"max_frame_ms": 0.0,
		"hitch_threshold_ms": float(gates.get("target_frame_ms", 33.33)),
		"hitch_count": 0,
		"hitches": [],
		"worst_frames": [],
		"pass": false,
		"failed_gates": [{"gate": "scenario_setup", "actual": reason, "limit": "ready"}]
	}

func _summary_for_print(report: Dictionary) -> Dictionary:
	var scenarios: Array = []
	for scenario_any in report.get("scenarios", []) as Array:
		var scenario: Dictionary = scenario_any as Dictionary
		scenarios.append({
			"scenario_id": scenario.get("scenario_id", ""),
			"pass": scenario.get("pass", false),
			"average_frame_ms": scenario.get("average_frame_ms", 0.0),
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

func _parse_args(args: Array) -> Dictionary:
	var out := {}
	var positional: Array = []
	for arg_any in args:
		var arg := str(arg_any)
		if arg.begins_with("--suite="):
			out["suite"] = arg.trim_prefix("--suite=")
		elif arg.begins_with("--mode="):
			out["mode"] = arg.trim_prefix("--mode=")
		elif arg.begins_with("--scenario="):
			out["scenario"] = arg.trim_prefix("--scenario=")
		elif arg.begins_with("--map="):
			out["map"] = arg.trim_prefix("--map=")
		elif arg.begins_with("--gates="):
			out["gates"] = arg.trim_prefix("--gates=")
		elif arg.begins_with("--output="):
			out["output"] = arg.trim_prefix("--output=")
		else:
			positional.append(arg)
	out["positional"] = positional
	return out

func _default_map_path() -> String:
	var maps: Array[String] = MapCatalog.list_json_maps()
	if maps.is_empty():
		return ""
	return maps[0]

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))

func _default_gates() -> Dictionary:
	return {
		"target_fps": 30,
		"target_frame_ms": 33.5,
		"p99_max_ms": 41.67,
		"max_frame_ms": 55.0,
		"max_hitches": 0,
		"warn_regression_percent": 10.0,
		"fail_regression_percent": 20.0
	}

func _machine_metadata() -> Dictionary:
	return {
		"os": OS.get_name(),
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count()
	}
