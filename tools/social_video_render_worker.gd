extends SceneTree

const SFLog := preload("res://scripts/util/sf_log.gd")
const MapLoader := preload("res://scripts/maps/map_loader.gd")

const DEFAULT_OUT_DIR: String = "user://social_video_frames"
const DEFAULT_MAX_FRAMES: int = 900
const START_TIMEOUT_MS: int = 15000

var _replay_path: String = ""
var _out_dir: String = DEFAULT_OUT_DIR
var _max_frames: int = DEFAULT_MAX_FRAMES
var _dry_run: bool = false
var _phase: String = ""
var _package: Dictionary = {}
var _viewport: SubViewport = null
var _frames: Array[String] = []
var _input_events: Array = []
var _input_index: int = 0
var _clip_start_ms: int = 0
var _clip_end_ms: int = 0
var _frame_interval_ms: int = 33
var _next_capture_ms: int = 0
var _start_ticks: int = 0
var _wait_frames: int = 0
var _exit_code: int = 0
var _cleanup_wait_frames: int = 0
var _baseline_root_instance_ids: Dictionary = {}

func _initialize() -> void:
	_parse_args(OS.get_cmdline_user_args())
	_start()

func _process(_delta: float) -> bool:
	match _phase:
		"wait_running":
			_step_wait_running()
		"render":
			_step_render()
		"capture_wait":
			_step_capture_wait()
		"cleanup_wait":
			_step_cleanup_wait()
	return false

func _parse_args(args: Array) -> void:
	for arg_any in args:
		var arg: String = str(arg_any)
		if arg.begins_with("--replay="):
			_replay_path = arg.trim_prefix("--replay=").strip_edges()
		elif arg.begins_with("--out-dir="):
			_out_dir = arg.trim_prefix("--out-dir=").strip_edges()
		elif arg.begins_with("--max-frames="):
			_max_frames = maxi(1, int(arg.trim_prefix("--max-frames=")))
		elif arg == "--dry-run":
			_dry_run = true

func _start() -> void:
	if _replay_path.is_empty():
		push_error("SOCIAL_VIDEO_RENDER: missing --replay=<path>")
		_begin_shutdown(1)
		return
	var payload: Dictionary = _load_json_dict(_replay_path)
	if payload.is_empty():
		push_error("SOCIAL_VIDEO_RENDER: replay payload missing or invalid")
		_begin_shutdown(1)
		return
	var package: Dictionary = _video_replay_package(payload)
	var validation: Dictionary = _validate_package(package)
	if not bool(validation.get("ok", false)):
		push_error("SOCIAL_VIDEO_RENDER: invalid video replay package %s" % str(validation))
		_begin_shutdown(1)
		return
	if _dry_run:
		print(JSON.stringify(_manifest(package, [], "dry_run"), "\t"))
		_begin_shutdown(0)
		return
	var start_result: Dictionary = _start_render(package)
	if not bool(start_result.get("ok", false)):
		push_error("SOCIAL_VIDEO_RENDER: render failed %s" % str(start_result))
		_begin_shutdown(1)
		return

func _load_json_dict(path: String) -> Dictionary:
	var resolved_path: String = path
	if not FileAccess.file_exists(resolved_path) and not path.begins_with("user://") and not path.begins_with("res://"):
		resolved_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(resolved_path):
		return {}
	var file: FileAccess = FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var err: int = parser.parse(file.get_as_text())
	if err != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data as Dictionary

func _video_replay_package(payload: Dictionary) -> Dictionary:
	var package_any: Variant = payload.get("video_replay", {})
	if typeof(package_any) == TYPE_DICTIONARY:
		return (package_any as Dictionary).duplicate(true)
	return {}

func _validate_package(package: Dictionary) -> Dictionary:
	if str(package.get("render_mode", "")) != "actual_arena_scene":
		return {"ok": false, "reason": "wrong_render_mode"}
	var map_data: Dictionary = _resolve_map_data(package)
	if map_data.is_empty():
		return {"ok": false, "reason": "missing_map_data"}
	var inputs_any: Variant = package.get("input_events", [])
	if typeof(inputs_any) != TYPE_ARRAY:
		return {"ok": false, "reason": "bad_input_events"}
	return {"ok": true}

func _resolve_map_data(package: Dictionary) -> Dictionary:
	var map_data_any: Variant = package.get("map_data", {})
	if typeof(map_data_any) == TYPE_DICTIONARY and not (map_data_any as Dictionary).is_empty():
		return (map_data_any as Dictionary).duplicate(true)
	var map_path: String = str(package.get("map_path", "")).strip_edges()
	if map_path.is_empty():
		return {}
	var result: Dictionary = MapLoader.load_map(map_path)
	if not bool(result.get("ok", false)):
		return {}
	var data_any: Variant = result.get("data", {})
	if typeof(data_any) == TYPE_DICTIONARY:
		return (data_any as Dictionary).duplicate(true)
	return {}

func _start_render(package: Dictionary) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {"ok": false, "reason": "headless_dummy_renderer_cannot_capture_viewport"}
	_package = package.duplicate(true)
	_record_baseline_root_children()
	var export: Dictionary = package.get("export", {}) as Dictionary
	var width: int = maxi(320, int(export.get("width", 1080)))
	var height: int = maxi(320, int(export.get("height", 1920)))
	var fps: int = clampi(int(export.get("fps", 30)), 1, 60)
	_frame_interval_ms = maxi(1, int(round(1000.0 / float(fps))))
	var clip: Dictionary = _first_clip_window(package)
	_clip_start_ms = maxi(0, int(clip.get("start_ms", 0)))
	var clip_duration_ms: int = maxi(_frame_interval_ms, int(clip.get("duration_ms", 30000)))
	_clip_end_ms = _clip_start_ms + clip_duration_ms
	var map_data: Dictionary = _resolve_map_data(package)
	_input_events = package.get("input_events", []) as Array

	_viewport = SubViewport.new()
	_viewport.name = "SocialVideoViewport"
	_viewport.size = Vector2i(width, height)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	var arena_scene: PackedScene = load("res://scenes/Arena.tscn") as PackedScene
	if arena_scene == null:
		return {"ok": false, "reason": "arena_scene_load_failed"}
	var arena := arena_scene.instantiate() as Node2D
	if arena == null:
		return {"ok": false, "reason": "arena_instantiate_failed"}
	_viewport.add_child(arena)
	var map_applier: Script = load("res://scripts/maps/map_applier.gd") as Script
	if map_applier == null or not map_applier.has_method("apply_map"):
		return {"ok": false, "reason": "map_applier_load_failed"}
	map_applier.call("apply_map", arena, map_data)
	if arena.has_method("start_sim"):
		arena.call("start_sim")

	var mk_err: int = DirAccess.make_dir_recursive_absolute(_out_dir)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		return {"ok": false, "reason": "mkdir_failed", "code": mk_err, "out_dir": _out_dir}
	_frames.clear()
	_input_index = 0
	_next_capture_ms = _clip_start_ms
	_start_ticks = Time.get_ticks_msec()
	_phase = "wait_running"
	return {"ok": true}

func _step_wait_running() -> void:
	if _ops_state() != null and int(_ops_state().get("match_phase")) == 1:
		_start_ticks = Time.get_ticks_msec()
		_phase = "render"
		return
	if Time.get_ticks_msec() - _start_ticks > START_TIMEOUT_MS:
		_fail({"ok": false, "reason": "match_not_running"})

func _step_render() -> void:
	var sim_elapsed_ms: int = Time.get_ticks_msec() - _start_ticks
	while _input_index < _input_events.size():
		var event: Dictionary = _input_events[_input_index] as Dictionary
		if int(event.get("t_ms", 0)) > sim_elapsed_ms:
			break
		_apply_input_event(event)
		_input_index += 1
	if sim_elapsed_ms > _clip_end_ms or _frames.size() >= _max_frames:
		_finish()
		return
	if sim_elapsed_ms >= _next_capture_ms:
		_wait_frames = 2
		_phase = "capture_wait"
		return

func _step_capture_wait() -> void:
	_wait_frames -= 1
	if _wait_frames > 0:
		return
	var path: String = "%s/frame_%06d.png" % [_out_dir, _frames.size()]
	var save_err: int = _capture_frame(_viewport, path)
	if save_err != OK:
		_fail({"ok": false, "reason": "frame_save_failed", "code": save_err, "path": path})
		return
	_frames.append(path)
	_next_capture_ms += _frame_interval_ms
	if _frames.size() >= _max_frames:
		_finish()
		return
	_phase = "render"

func _finish() -> void:
	var manifest: Dictionary = _manifest(_package, _frames, "rendered")
	manifest["manifest_path"] = "%s/manifest.json" % _out_dir
	var manifest_file: FileAccess = FileAccess.open(str(manifest["manifest_path"]), FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string(JSON.stringify(manifest, "\t"))
	print(JSON.stringify({"ok": true, "manifest": manifest, "frames": _frames.size()}, "\t"))
	_begin_shutdown(0)

func _fail(result: Dictionary) -> void:
	push_error("SOCIAL_VIDEO_RENDER: render failed %s" % str(result))
	_begin_shutdown(1)

func _begin_shutdown(exit_code: int) -> void:
	_exit_code = exit_code
	_cleanup_render_nodes()
	_cleanup_singletons()
	_package.clear()
	_frames.clear()
	_input_events.clear()
	_input_index = 0
	_cleanup_wait_frames = 20
	_phase = "cleanup_wait"

func _step_cleanup_wait() -> void:
	_cleanup_wait_frames -= 1
	if _cleanup_wait_frames > 0:
		return
	quit(_exit_code)

func _cleanup_render_nodes() -> void:
	for child in root.get_children():
		if child == null:
			continue
		if _baseline_root_instance_ids.has(child.get_instance_id()):
			continue
		child.queue_free()
	if _viewport != null and is_instance_valid(_viewport):
		_viewport.queue_free()
		_viewport = null

func _cleanup_singletons() -> void:
	var ops_state: Node = _ops_state()
	if ops_state == null:
		return
	if ops_state.has_method("set_match_telemetry_collector"):
		ops_state.call("set_match_telemetry_collector", null)
	if ops_state.has_method("reset_match_state"):
		ops_state.call("reset_match_state")
	ops_state.set("state", null)
	ops_state.set("edge_cache", {})
	ops_state.set("blocked_wall_pairs", [])

func _record_baseline_root_children() -> void:
	_baseline_root_instance_ids.clear()
	for child in root.get_children():
		if child != null:
			_baseline_root_instance_ids[child.get_instance_id()] = true

func _first_clip_window(package: Dictionary) -> Dictionary:
	var clips_any: Variant = package.get("clip_windows", [])
	if typeof(clips_any) == TYPE_ARRAY and not (clips_any as Array).is_empty() and typeof((clips_any as Array)[0]) == TYPE_DICTIONARY:
		return ((clips_any as Array)[0] as Dictionary).duplicate(true)
	return {"start_ms": 0, "duration_ms": 30000, "reason": "fallback"}

func _apply_input_event(event: Dictionary) -> void:
	var src: int = int(event.get("src_hive_id", -1))
	var dst: int = int(event.get("dst_hive_id", -1))
	var intent: String = str(event.get("intent", "attack")).strip_edges().to_lower()
	if src <= 0 or dst <= 0 or src == dst:
		return
	if intent != "attack" and intent != "feed" and intent != "swarm" and intent != "none":
		intent = "attack"
	var ops_state: Node = _ops_state()
	if ops_state == null or not ops_state.has_method("apply_lane_intent"):
		return
	ops_state.call("apply_lane_intent", src, dst, intent)

func _ops_state() -> Node:
	return root.get_node_or_null("OpsState")

func _capture_frame(viewport: SubViewport, path: String) -> int:
	if viewport == null:
		return ERR_INVALID_PARAMETER
	var image: Image = viewport.get_texture().get_image()
	if image == null:
		return ERR_CANT_CREATE
	return image.save_png(path)

func _manifest(package: Dictionary, frames: Array[String], status: String) -> Dictionary:
	var export: Dictionary = package.get("export", {}) as Dictionary
	return {
		"schema_version": 1,
		"status": status,
		"render_mode": "actual_arena_scene",
		"source_replay": _replay_path,
		"frame_count": frames.size(),
		"frames": frames,
		"cta": _cta(package),
		"output": {
			"width": int(export.get("width", 1080)),
			"height": int(export.get("height", 1920)),
			"fps": int(export.get("fps", 30)),
			"format": "png_sequence",
			"target_format": str(export.get("format", "mp4"))
		}
	}

func _cta(package: Dictionary) -> Dictionary:
	var cta_any: Variant = package.get("cta", {})
	if typeof(cta_any) == TYPE_DICTIONARY:
		var cta: Dictionary = (cta_any as Dictionary).duplicate(true)
		if not cta.has("text_overlay"):
			cta["text_overlay"] = "Tap the link to play Swarmfront"
		if not cta.has("link_url"):
			cta["link_url"] = ""
		if not cta.has("safe_area"):
			cta["safe_area"] = "bottom"
		return cta
	return {
		"text_overlay": "Tap the link to play Swarmfront",
		"link_url": "",
		"safe_area": "bottom"
	}
