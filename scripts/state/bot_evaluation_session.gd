extends Node

# Session setup and recording only. Gameplay remains in OpsState/SimRunner.
const MAP_PATH := "res://maps/tutorial/MAP_simple_syrup__1p.json"
const MAP_ID := "MAP_simple_syrup__1p"
const SEED := 9282026
const BUILD := "2026092801"
const HUB := "res://scenes/BotEvaluation.tscn"
const SAVE_DIR := "user://bot_evaluation"
var _active: Dictionary = {}
var _collector: RefCounted
var _saving: Thread
var _launching := false
var last_save: Dictionary = {}

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 15.0
	timer.timeout.connect(_checkpoint)
	add_child(timer)
	timer.start()

func enabled() -> bool:
	return OS.has_feature("bot_evaluation") or (OS.is_debug_build() and OS.get_cmdline_user_args().has("--bot-evaluation"))

func is_active() -> bool:
	return enabled() and not _active.is_empty()

func descriptor() -> Dictionary:
	return _active.duplicate(true)

func request_launch(game: int) -> Dictionary:
	if not enabled() or game not in [0, 1] or _launching:
		return {"ok": false, "error": "This playtest cannot start right now."}
	if is_active() and OpsState.is_match_running():
		return {"ok": false, "error": "Finish the current game first."}
	_flush_writer()
	_collector = null
	var tree := get_tree()
	CampaignRuntime.finish_session()
	for key in tree.get_meta_list():
		var token := str(key)
		if token.begins_with("vs_") or token.begins_with("jukebox_") or token.begins_with("tutorial_") or token.begins_with("progressive_") or token.begins_with("durable_") or token.begins_with("ctf_") or token.begins_with("async_") or token in ["practice", "economic", "open_map_picker_on_ready"]:
			tree.remove_meta(key)
	var style := "balancer" if game == 0 else "raider"
	var title := "Balancer" if game == 0 else "Raider"
	_active = {
		"schema_version": 1, "session_id": "simple_syrup_20260928",
		"run_id": Crypto.new().generate_random_bytes(12).hex_encode(),
		"game": game, "style": style, "tier": "medium", "seed": SEED,
		"human_seat": 1, "cpu_seat": 2, "map_path": MAP_PATH,
		"map_sha256": FileAccess.get_sha256(MAP_PATH), "buff_loadout": [],
		"expected_policy": "human_balancer_v3" if game == 0 else "baseline_v3",
		"build": BUILD, "engine": Engine.get_version_info(),
		"source": _source_manifest(), "completed": false
	}
	tree.set_meta("bot_evaluation_session", descriptor())
	var setup := {
		"start_game": true, "vs_mode": "1V1", "practice": true,
		"vs_practice": true, "vs_ranked": false, "vs_economic": false,
		"economic": false, "vs_price_usd": 0, "vs_wager_cents": 0,
		"vs_paid_entry": false, "vs_free_roll": true, "vs_sync_start": true,
		"vs_sync_join_sec": 0, "vs_window_sec": 0, "vs_required_players": 2,
		"vs_open_slots": 0, "vs_stage_map_paths": [MAP_PATH],
		"vs_stage_current_index": 0, "vs_stage_round_results": [],
		"vs_handshake_session_id": "", "vs_handshake_role": "host",
		"vs_roster": [], "vs_cpu_style": style, "vs_cpu_tier": "medium",
		"vs_assigned_players": ["You", title + " CPU"],
		"vs_local_profile": {"uid": ProfileManager.get_user_id(), "name": "You", "display_name": "You"},
		"vs_remote_profile": {"uid": "bot_evaluation_" + style, "name": title + " CPU", "display_name": title + " CPU", "is_cpu": true, "seat": 2, "style": style, "tier": "medium"}
	}
	for key in setup:
		tree.set_meta(key, setup[key])
	_launching = true
	var error := tree.change_scene_to_file("res://scenes/Shell.tscn")
	if error != OK:
		_launching = false
		_active.clear()
		tree.remove_meta("bot_evaluation_session")
		return {"ok": false, "error": "The playtest could not be loaded."}
	tree.scene_changed.connect(func() -> void: _launching = false, CONNECT_ONE_SHOT)
	return {"ok": true}

func _source_manifest() -> Dictionary:
	var path := "res://data/bot_evaluation_build.json"
	if not FileAccess.file_exists(path):
		return {"revision": "development", "build": BUILD}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func attach_collector(collector: RefCounted) -> void:
	if is_active():
		_collector = collector

func _checkpoint() -> void:
	if not is_active() or _collector == null or not _collector.call("is_active"):
		return
	if _saving != null and _saving.is_alive():
		return
	_flush_writer()
	var payload: Dictionary = _collector.call("evaluation_snapshot", int(OpsState.match_elapsed_ms))
	var path := SAVE_DIR.path_join(str(_active.run_id) + ".json")
	_saving = Thread.new()
	var error := _saving.start(_write_snapshot.bind(payload, path))
	if error != OK:
		_saving = null
		last_save = {"ok": false, "error": "checkpoint_thread_failed"}

func finish_recording(completed: bool) -> Dictionary:
	if not is_active() or _collector == null:
		return last_save.duplicate(true)
	_flush_writer()
	var payload: Dictionary = _collector.call("evaluation_snapshot", int(OpsState.match_elapsed_ms))
	payload["metadata"]["bot_evaluation"]["completed"] = completed
	payload["metadata"]["bot_evaluation"]["end_reason"] = str(OpsState.match_end_reason) if completed else "left_or_interrupted"
	last_save = _write_snapshot(payload, SAVE_DIR.path_join(str(_active.run_id) + ".json"))
	return last_save.duplicate(true)

func request_return() -> void:
	if is_active():
		finish_recording(OpsState.has_outcome())
	_collector = null
	_active.clear()
	get_tree().remove_meta("bot_evaluation_session")
	get_tree().change_scene_to_file(HUB)

func _flush_writer() -> void:
	if _saving != null:
		last_save = _saving.wait_to_finish()
		_saving = null

func _write_snapshot(payload: Dictionary, path: String) -> Dictionary:
	var error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if error != OK and error != ERR_ALREADY_EXISTS:
		return {"ok": false, "error": "mkdir_failed"}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "open_failed"}
	file.store_string(JSON.stringify(payload))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "error": "write_failed"}
	error = DirAccess.rename_absolute(path + ".tmp", path)
	return {"ok": error == OK, "path": path, "error": "" if error == OK else "rename_failed"}

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_active():
		_checkpoint()

func _exit_tree() -> void:
	_flush_writer()
