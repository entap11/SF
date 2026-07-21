class_name StartupHitchDiagnostic
extends Node

const SCHEMA: String = "sf_startup_hitch_diagnostic_v1"
const DEFAULT_OUTPUT_PATH: String = "user://startup_hitch_diagnostic/startup_hitch_latest.json"
const DEFAULT_WINDOW_SECONDS: float = 20.0
const DEFAULT_FRAME_HITCH_MS: float = 50.0
const DEFAULT_TICK_HITCH_MS: float = 8.0
const MAX_MARKERS: int = 96
const MAX_HITCHES: int = 64
const GROUP_NAME: StringName = &"startup_hitch_diagnostic"
const PerfIsolationGuard := preload("res://scripts/tests/perf/perf_isolation_guard.gd")

const READY_PROBE_LABEL_BY_SCRIPT: Dictionary = {
	"res://scripts/renderers/floor_renderer.gd": "floor_renderer",
	"res://scripts/renderers/arena_polish_layer.gd": "arena_polish_layer",
	"res://scripts/renderers/tower_ground_glow_renderer.gd": "tower_ground_glow_renderer",
	"res://scripts/renderers/barracks_ground_glow_renderer.gd": "barracks_ground_glow_renderer",
	"res://scripts/renderers/lane_renderer.gd": "lane_renderer",
	"res://scripts/renderers/tower_renderer.gd": "tower_renderer",
	"res://scripts/renderers/barracks_renderer.gd": "barracks_renderer",
	"res://scripts/renderers/hive_renderer.gd": "hive_renderer",
	"res://scripts/renderers/unit_renderer.gd": "unit_renderer",
	"res://scripts/renderers/wall_renderer.gd": "wall_renderer"
}
const READY_PROBE_NODE_NAMES: Dictionary = {
	"FloorRenderer": true,
	"ArenaPolishLayer": true,
	"TowerGroundGlowRenderer": true,
	"BarracksGroundGlowRenderer": true,
	"LaneRenderer": true,
	"TowerRenderer": true,
	"BarracksRenderer": true,
	"HiveRenderer": true,
	"UnitRenderer": true,
	"WallRenderer": true
}

const MARKER_ORDER: Array[String] = [
	"diagnostic_invoked",
	"match_scene_load_requested",
	"match_scene_resource_loaded",
	"match_scene_instantiated",
	"match_scene_added",
	"arena_enter_tree",
	"arena_ready_entered",
	"unit_pool_prewarm_started",
	"unit_pool_prewarm_completed",
	"vfx_pool_prewarm_started",
	"vfx_pool_prewarm_completed",
	"arena_ready_completed",
	"map_prewarm_requested",
	"map_model_ready",
	"map_application_started",
	"map_application_completed",
	"simulation_activation_requested",
	"first_canonical_tick_started",
	"first_canonical_tick_completed",
	"prematch_completed",
	"arena_presentation_visible",
	"player_input_unlocked",
	"first_interactive_frame",
	"first_lane_activity",
	"first_unit_activity",
	"diagnostic_window_completed"
]
const NEXT_EXPECTED_BY_MARKER: Dictionary = {
	"diagnostic_invoked": "map_prewarm_requested",
	"map_prewarm_requested": "match_scene_load_requested",
	"match_scene_load_requested": "match_scene_resource_loaded",
	"match_scene_resource_loaded": "match_scene_instantiated",
	"match_scene_instantiated": "arena_enter_tree",
	"arena_enter_tree": "arena_ready_entered",
	"arena_ready_entered": "match_scene_added",
	"match_scene_added": "arena_ready_completed",
	"arena_ready_completed": "map_model_ready",
	"map_model_ready": "map_application_started",
	"map_application_started": "map_application_completed",
	"map_application_completed": "arena_presentation_visible",
	"arena_presentation_visible": "prematch_completed",
	"prematch_completed": "simulation_activation_requested",
	"simulation_activation_requested": "player_input_unlocked",
	"player_input_unlocked": "first_canonical_tick_started",
	"first_canonical_tick_started": "first_canonical_tick_completed",
	"first_canonical_tick_completed": "first_interactive_frame",
	"first_interactive_frame": "diagnostic_window_completed"
}

var _active: bool = false
var _completed: bool = false
var _started_usec: int = 0
var _window_usec: int = 0
var _frame_hitch_ms: float = DEFAULT_FRAME_HITCH_MS
var _tick_hitch_ms: float = DEFAULT_TICK_HITCH_MS
var _output_path: String = DEFAULT_OUTPUT_PATH
var _config: Dictionary = {}
var _markers: Array[Dictionary] = []
var _marked_names: Dictionary = {}
var _hitches: Array[Dictionary] = []
var _last_frame_ms: float = 0.0
var _last_sim_tick_ms: float = 0.0
var _last_sim_tick: int = -1
var _last_sim_phase_timings: Dictionary = {}
var _report: Dictionary = {}
var _observed_frame_count: int = 0
var _observed_tick_count: int = 0
var _maximum_observed_frame_ms: float = 0.0
var _maximum_observed_tick_ms: float = 0.0
var _protected_state_before_hash: String = ""
var _protected_state_after_hash: String = ""
var _tree_probe_connected: bool = false
var _post_add_probe_scheduled: bool = false


static func activation_check(is_debug_build: bool, args: Array) -> Dictionary:
	var diagnostic_requested: bool = args.has("--startup-hitch-diagnostic")
	var soak_requested: bool = args.has("--soak-perf")
	if not diagnostic_requested:
		return {"requested": false, "allowed": false, "reason": "not_requested"}
	if not is_debug_build:
		return {"requested": true, "allowed": false, "reason": "debug_build_required"}
	if not soak_requested:
		return {"requested": true, "allowed": false, "reason": "soak_perf_required"}
	return {"requested": true, "allowed": true, "reason": ""}


static func requested_for_current_debug_process() -> bool:
	return bool(activation_check(OS.is_debug_build(), OS.get_cmdline_user_args()).get("allowed", false))


static func mark_tree_event(tree: SceneTree, marker_name: String, detail: Dictionary = {}) -> bool:
	if tree == null or marker_name.is_empty():
		return false
	var diagnostic_nodes: Array[Node] = tree.get_nodes_in_group(GROUP_NAME)
	if diagnostic_nodes.is_empty():
		return false
	var diagnostic: Node = diagnostic_nodes.back()
	if diagnostic == null or not is_instance_valid(diagnostic) or not diagnostic.has_method("mark_event"):
		return false
	diagnostic.call("mark_event", marker_name, detail)
	return true


func configure(config: Dictionary) -> bool:
	if not OS.is_debug_build():
		return false
	_config = config.duplicate(true)
	_output_path = str(_config.get("output_path", DEFAULT_OUTPUT_PATH)).strip_edges()
	if _output_path.is_empty():
		_output_path = DEFAULT_OUTPUT_PATH
	_window_usec = int(clampf(float(_config.get("window_seconds", DEFAULT_WINDOW_SECONDS)), 5.0, 60.0) * 1000000.0)
	_frame_hitch_ms = maxf(1.0, float(_config.get("frame_hitch_ms", DEFAULT_FRAME_HITCH_MS)))
	_tick_hitch_ms = maxf(1.0, float(_config.get("tick_hitch_ms", DEFAULT_TICK_HITCH_MS)))
	_started_usec = Time.get_ticks_usec()
	_protected_state_before_hash = PerfIsolationGuard.protected_state_hash(get_tree())
	_protected_state_after_hash = ""
	_active = true
	_completed = false
	add_to_group(GROUP_NAME)
	_arm_tree_probes()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	mark_once("diagnostic_invoked", {
		"launch_classification": str(_config.get("launch_classification", "unspecified")),
		"source_commit": str(_config.get("source_commit", "unavailable"))
	})
	return true


func _process(delta: float) -> void:
	if not _active or _completed:
		return
	_last_frame_ms = delta * 1000.0
	_observed_frame_count += 1
	_observe_runtime_boundaries()
	# A node added mid-frame receives a delta whose interval began before the
	# diagnostic was armed. Keep its boundary observations, but never classify
	# that inherited first callback as a startup hitch.
	if _observed_frame_count > 1:
		_maximum_observed_frame_ms = maxf(_maximum_observed_frame_ms, _last_frame_ms)
		if _last_frame_ms > _frame_hitch_ms:
			_record_hitch("rendered_frame", _last_frame_ms, {})
	if Time.get_ticks_usec() - _started_usec >= _window_usec:
		complete("window_elapsed")


func mark_once(marker_name: String, detail: Dictionary = {}) -> void:
	if not _active or _completed or marker_name.is_empty() or _marked_names.has(marker_name):
		return
	mark_event(marker_name, detail)


func mark_event(marker_name: String, detail: Dictionary = {}) -> void:
	if not _active or _completed or marker_name.is_empty():
		return
	if _markers.size() >= MAX_MARKERS:
		return
	_marked_names[marker_name] = true
	_markers.append({
		"name": marker_name,
		"elapsed_ms": _elapsed_ms(),
		"process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames(),
		"simulation_tick": _simulation_tick(),
		"detail": detail.duplicate(true)
	})
	if marker_name == "match_scene_added" and not _post_add_probe_scheduled:
		_post_add_probe_scheduled = true
		call_deferred("_record_post_add_deferred_queue_drained")


func record_sim_tick(tick_ms: float, phase_timings: Dictionary, simulation_tick: int) -> void:
	if not _active or _completed:
		return
	_last_sim_tick_ms = tick_ms
	_observed_tick_count += 1
	_maximum_observed_tick_ms = maxf(_maximum_observed_tick_ms, tick_ms)
	_last_sim_tick = simulation_tick
	_last_sim_phase_timings = phase_timings.duplicate(true)
	mark_once("first_canonical_tick_completed", {
		"tick_ms": snappedf(tick_ms, 0.001),
		"phase_timings": _last_sim_phase_timings.duplicate(true),
		"simulation_tick": simulation_tick
	})
	if tick_ms > _tick_hitch_ms:
		_record_hitch("canonical_simulation_tick", tick_ms, {
			"phase_timings": _last_sim_phase_timings.duplicate(true),
			"simulation_tick": simulation_tick
		})


func complete(reason: String = "completed") -> Dictionary:
	if _completed:
		return _report.duplicate(true)
	mark_once("diagnostic_window_completed", {"reason": reason})
	_completed = true
	_active = false
	set_process(false)
	_disarm_tree_probes()
	_protected_state_after_hash = PerfIsolationGuard.protected_state_hash(get_tree())
	_report = _build_report(reason)
	_write_report(_report)
	print("STARTUP_HITCH_DIAGNOSTIC_REPORT path=%s markers=%d hitches=%d interactive_hitches=%d" % [
		_output_path,
		_markers.size(),
		_hitches.size(),
		_count_interactive_hitches()
	])
	return _report.duplicate(true)


func _arm_tree_probes() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or _tree_probe_connected:
		return
	var callback := Callable(self, "_on_tree_node_added")
	if not tree.node_added.is_connected(callback):
		tree.node_added.connect(callback)
	_tree_probe_connected = true


func _disarm_tree_probes() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or not _tree_probe_connected:
		return
	var callback := Callable(self, "_on_tree_node_added")
	if tree.node_added.is_connected(callback):
		tree.node_added.disconnect(callback)
	_tree_probe_connected = false


func _on_tree_node_added(node: Node) -> void:
	if not _active or _completed or node == null:
		return
	if not READY_PROBE_NODE_NAMES.has(str(node.name)):
		return
	var script: Script = node.get_script() as Script
	if script == null:
		return
	var script_path: String = script.resource_path
	var label: String = str(READY_PROBE_LABEL_BY_SCRIPT.get(script_path, ""))
	if label.is_empty():
		return
	var marker_name: String = "%s_ready_completed" % label
	var path: String = str(node.get_path()) if node.is_inside_tree() else str(node.name)
	var callback := Callable(self, "_on_probed_node_ready").bind(marker_name, path, script_path)
	if not node.ready.is_connected(callback):
		node.ready.connect(callback, CONNECT_ONE_SHOT)


func _on_probed_node_ready(marker_name: String, path: String, script_path: String) -> void:
	mark_once(marker_name, {
		"path": path,
		"script": script_path
	})


func _record_post_add_deferred_queue_drained() -> void:
	if not _active or _completed:
		return
	mark_once("post_add_deferred_queue_drained")
	await get_tree().process_frame
	if not _active or _completed:
		return
	mark_once("post_add_first_process_frame_completed")
	await get_tree().process_frame
	if not _active or _completed:
		return
	mark_once("post_add_second_process_frame_completed")


func report_snapshot() -> Dictionary:
	if _completed:
		return _report.duplicate(true)
	return _build_report("in_progress")


func _observe_runtime_boundaries() -> void:
	var context: Dictionary = _runtime_context()
	if bool(context.get("presentation_visible", false)):
		mark_once("arena_presentation_visible")
	if not bool(context.get("input_locked", true)):
		mark_once("player_input_unlocked")
	if str(context.get("visibility", "")) == "INTERACTIVE":
		mark_once("first_interactive_frame")
	var counts: Dictionary = context.get("authority_counts", {}) as Dictionary
	if int(counts.get("active_lane_count", 0)) > 0:
		mark_once("first_lane_activity", {"active_lane_count": int(counts.get("active_lane_count", 0))})
	if int(counts.get("active_unit_count", 0)) > 0:
		mark_once("first_unit_activity", {"active_unit_count": int(counts.get("active_unit_count", 0))})


func _record_hitch(kind: String, duration_ms: float, extra: Dictionary) -> void:
	if _hitches.size() >= MAX_HITCHES:
		return
	var context: Dictionary = _runtime_context()
	var rendering_available: bool = DisplayServer.get_name() != "headless"
	var event: Dictionary = {
		"sequence": _hitches.size() + 1,
		"kind": kind,
		"elapsed_ms": _elapsed_ms(),
		"duration_ms": snappedf(duration_ms, 0.001),
		"process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames(),
		"simulation_tick": _simulation_tick(),
		"startup_phase": _last_marker_name(),
		"last_completed_marker": _last_marker_name(),
		"next_expected_marker": _next_expected_marker(),
		"frame_ms": snappedf(_last_frame_ms, 0.001),
		"engine_process_ms": snappedf(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0, 0.001),
		"physics_process_ms": snappedf(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0, 0.001),
		"render_time_ms": null,
		"render_time_availability": "not_exposed_by_godot_performance_monitors",
		"last_sim_tick_ms": snappedf(_last_sim_tick_ms, 0.001),
		"last_sim_phase_timings": _last_sim_phase_timings.duplicate(true),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) if rendering_available else null,
		"rendered_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)) if rendering_available else null,
		"rendered_primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)) if rendering_available else null,
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"texture_memory_bytes": null,
		"video_memory_bytes": null,
		"memory_metric_availability": "texture_and_video_memory_not_exposed_by_current_runtime",
		"visibility": str(context.get("visibility", "UNKNOWN_VISIBILITY")),
		"presentation_visible": bool(context.get("presentation_visible", false)),
		"prematch_overlay_visible": bool(context.get("prematch_overlay_visible", false)),
		"input_locked": bool(context.get("input_locked", true)),
		"accepting_gameplay_commands": bool(context.get("accepting_gameplay_commands", false)),
		"authority_counts": (context.get("authority_counts", {}) as Dictionary).duplicate(true),
		"pool_telemetry": (context.get("pool_telemetry", {}) as Dictionary).duplicate(true),
		"thermal_state": {"available": false, "reason": "requires_external_device_or_instruments_capture"}
	}
	for key_any in extra.keys():
		event[key_any] = extra.get(key_any)
	_hitches.append(event)


func _runtime_context() -> Dictionary:
	var arena: Node = _arena_node()
	var arena_snapshot: Dictionary = {}
	if arena != null and arena.has_method("startup_hitch_diagnostic_snapshot"):
		var snapshot_any: Variant = arena.call("startup_hitch_diagnostic_snapshot")
		if typeof(snapshot_any) == TYPE_DICTIONARY:
			arena_snapshot = snapshot_any as Dictionary
	var ops_state: Node = get_node_or_null("/root/OpsState")
	var input_locked: bool = true
	var match_phase: int = -1
	var running_phase: int = 1
	if ops_state != null:
		input_locked = bool(ops_state.get("input_locked"))
		match_phase = int(ops_state.get("match_phase"))
		running_phase = int(ops_state.MatchPhase.RUNNING)
	var presentation_visible: bool = bool(arena_snapshot.get("presentation_visible", _canvas_item_effectively_visible(arena as CanvasItem)))
	var shell_prematch_overlay: CanvasItem = get_node_or_null("/root/Shell/HUDCanvasLayer/HUDRoot/PreMatchOverlay") as CanvasItem
	var prematch_visible: bool = bool(arena_snapshot.get("prematch_overlay_visible", false)) \
		or (shell_prematch_overlay != null and shell_prematch_overlay.is_visible_in_tree())
	var accepting: bool = arena != null and match_phase == running_phase and not input_locked
	var visibility: String = "UNKNOWN_VISIBILITY"
	if not presentation_visible or prematch_visible:
		visibility = "PRE_INPUT_LOADING"
	elif accepting:
		visibility = "INTERACTIVE"
	elif input_locked:
		visibility = "POST_OVERLAY_PRE_INPUT"
	return {
		"visibility": visibility,
		"presentation_visible": presentation_visible,
		"prematch_overlay_visible": prematch_visible,
		"input_locked": input_locked if arena != null else true,
		"accepting_gameplay_commands": accepting,
		"match_phase": match_phase,
		"authority_counts": (arena_snapshot.get("authority_counts", {}) as Dictionary).duplicate(true),
		"pool_telemetry": (arena_snapshot.get("pool_telemetry", {}) as Dictionary).duplicate(true)
	}


func _arena_node() -> Node:
	var arenas: Array[Node] = get_tree().get_nodes_in_group("Arena") if get_tree() != null else []
	return arenas.back() if not arenas.is_empty() else null


func _canvas_item_effectively_visible(item: CanvasItem) -> bool:
	if item == null or not item.is_inside_tree() or not item.is_visible_in_tree():
		return false
	var alpha: float = 1.0
	var current: Node = item
	while current != null:
		if current is CanvasItem:
			alpha *= (current as CanvasItem).modulate.a
		current = current.get_parent()
	return alpha > 0.01


func _simulation_tick() -> int:
	if _last_sim_tick >= 0:
		return _last_sim_tick
	var ops_state: Node = get_node_or_null("/root/OpsState")
	if ops_state != null and ops_state.has_method("get_state"):
		var state_any: Variant = ops_state.call("get_state")
		if state_any is Object:
			return int((state_any as Object).get("tick"))
	return -1


func _elapsed_ms() -> float:
	return snappedf(float(Time.get_ticks_usec() - _started_usec) / 1000.0, 0.001)


func _last_marker_name() -> String:
	return str(_markers.back().get("name", "")) if not _markers.is_empty() else ""


func _next_expected_marker() -> String:
	return str(NEXT_EXPECTED_BY_MARKER.get(_last_marker_name(), "diagnostic_window_completed"))


func _build_report(reason: String) -> Dictionary:
	return {
		"schema": SCHEMA,
		"version": 1,
		"status": "COMPLETE" if _completed else "IN_PROGRESS",
		"completion_reason": reason,
		"configuration": _config.duplicate(true),
		"runtime": _runtime_identity(),
		"external_device_fields": {
			"battery_level": {"available": false, "reason": "record_from_device_capture"},
			"external_power": {"available": false, "reason": "record_from_device_capture"},
			"low_power_mode": {"available": false, "reason": "record_from_device_capture"},
			"initial_thermal_state": {"available": false, "reason": "record_from_device_or_instruments_capture"},
			"final_thermal_state": {"available": false, "reason": "record_from_device_or_instruments_capture"},
			"available_storage": {"available": false, "reason": "not_exposed_by_current_godot_runtime"}
		},
		"thresholds": {
			"rendered_frame_ms_strictly_greater_than": _frame_hitch_ms,
			"canonical_tick_ms_strictly_greater_than": _tick_hitch_ms
		},
		"marker_catalog": MARKER_ORDER.duplicate(),
		"protected_state_integrity": _protected_state_integrity(),
		"markers": _markers.duplicate(true),
		"hitches": _hitches.duplicate(true),
		"summary": {
			"elapsed_ms": _elapsed_ms(),
			"observed_frame_count": maxi(0, _observed_frame_count - 1),
			"observed_tick_count": _observed_tick_count,
			"marker_count": _markers.size(),
			"hitch_count": _hitches.size(),
			"interactive_hitch_count": _count_interactive_hitches(),
			"maximum_rendered_frame_ms": snappedf(_maximum_observed_frame_ms, 0.001) if _observed_frame_count > 1 else null,
			"maximum_canonical_tick_ms": snappedf(_maximum_observed_tick_ms, 0.001) if _observed_tick_count > 0 else null,
			"first_canonical_tick_ms": _first_marker_detail_float("first_canonical_tick_completed", "tick_ms")
		}
	}


func _protected_state_integrity() -> Dictionary:
	var after_hash: String = _protected_state_after_hash if _completed else PerfIsolationGuard.protected_state_hash(get_tree())
	return {
		"before_hash": _protected_state_before_hash,
		"after_hash": after_hash,
		"pass": not _protected_state_before_hash.is_empty() and _protected_state_before_hash == after_hash
	}


func _runtime_identity() -> Dictionary:
	var refresh_rate: float = DisplayServer.screen_get_refresh_rate()
	return {
		"godot": Engine.get_version_info(),
		"platform": OS.get_name(),
		"device_model": OS.get_model_name(),
		"os_version": OS.get_version(),
		"display_server": DisplayServer.get_name(),
		"display_refresh_hz": refresh_rate if refresh_rate > 0.0 else null,
		"vsync_mode": int(DisplayServer.window_get_vsync_mode()),
		"engine_max_fps": int(Engine.max_fps),
		"physics_ticks_per_second": int(Engine.physics_ticks_per_second),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unavailable")),
		"rendering_driver": str(ProjectSettings.get_setting("rendering/rendering_device/driver", "unavailable")),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"debug_build": OS.is_debug_build()
	}


func _count_interactive_hitches() -> int:
	var count: int = 0
	for hitch in _hitches:
		if str(hitch.get("visibility", "")) == "INTERACTIVE":
			count += 1
	return count


func _first_marker_detail_float(marker_name: String, key: String) -> Variant:
	for marker in _markers:
		if str(marker.get("name", "")) != marker_name:
			continue
		return float((marker.get("detail", {}) as Dictionary).get(key, 0.0))
	return null


func _write_report(report: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(_output_path)
	var directory: String = absolute_path.get_base_dir()
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if dir_error != OK:
		push_error("STARTUP_HITCH_DIAGNOSTIC_WRITE_FAIL directory=%s error=%d" % [directory, int(dir_error)])
		return
	var file: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("STARTUP_HITCH_DIAGNOSTIC_WRITE_FAIL path=%s error=%d" % [_output_path, int(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
