extends Node

signal progress_changed

const Catalog = preload("res://scripts/state/campaign_catalog.gd")
const Store = preload("res://scripts/state/campaign_progress_store.gd")
var store = Store.new()
var _active: Dictionary = {}
var _result: Dictionary = {}
var _run_id := ""
var _entry := "campaign"
var _launching := false

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func player_id() -> String:
	return ProfileManager.get_user_id()

func active_level() -> Dictionary:
	return _active.duplicate(true)

func entry() -> String:
	return _entry

func result() -> Dictionary:
	return _result.duplicate(true)

func is_active() -> bool:
	return not _active.is_empty() and str(get_tree().get_meta("campaign_level_id", "")) == str(_active.id)

func request_launch(id: String, source: String = "campaign") -> Dictionary:
	if _launching:
		return {"ok": false, "error": "A level is already starting."}
	if player_id().is_empty():
		return {"ok": false, "error": "Finish setting up your player profile before starting Campaign."}
	var level: Dictionary = Catalog.find(id)
	if level.is_empty() or not store.is_unlocked(player_id(), id):
		return {"ok": false, "error": "Complete the preceding level to unlock this challenge. A win or loss counts."}
	if not store.prepare_attempt(player_id(), id, source != "jukebox"):
		return {"ok": false, "error": "Progress could not be saved. Please try again."}
	_launching = true
	var tree := get_tree()
	# Session setup owns the launch contract; UI only requests a catalog entry.
	for key in tree.get_meta_list():
		var token := str(key)
		if token.begins_with("vs_") or token.begins_with("jukebox_") or token.begins_with("tutorial_") or token.begins_with("progressive_") or token.begins_with("durable_") or token.begins_with("ctf_") or token.begins_with("async_") or token in ["practice", "open_map_picker_on_ready"]:
			tree.remove_meta(key)
	_active = level
	_result = {}
	_entry = "jukebox" if source == "jukebox" else "campaign"
	_run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	tree.set_meta("campaign_level_id", id)
	tree.set_meta("start_game", true)
	tree.set_meta("vs_mode", "ASYNC_SINGLE_MAP_TIMED")
	tree.set_meta("vs_price_usd", 0)
	tree.set_meta("vs_free_roll", true)
	tree.set_meta("vs_sync_start", false)
	tree.set_meta("vs_stage_map_paths", [str(level.map_path)])
	tree.set_meta("vs_stage_current_index", 0)
	tree.set_meta("vs_stage_round_results", [])
	tree.set_meta("vs_local_profile", {"uid": player_id(), "name": ProfileManager.get_display_name()})
	tree.set_meta("vs_cpu_style", str(level.bot))
	tree.set_meta("vs_cpu_tier", str(level.difficulty))
	tree.set_meta("jukebox_board_enabled", true)
	tree.set_meta("jukebox_map_path", str(level.map_path))
	tree.set_meta("jukebox_local_owner_id", 1)
	var error: Error = tree.change_scene_to_file("res://scenes/Shell.tscn")
	if error != OK:
		finish_session()
		return {"ok": false, "error": "The level could not be loaded. Please try again."}
	tree.scene_changed.connect(_on_launch_scene_changed, CONNECT_ONE_SHOT)
	return {"ok": true}

func _on_launch_scene_changed() -> void:
	_launching = false

func finish_session() -> void:
	_launching = false
	_active = {}
	_result = {}
	_run_id = ""
	if get_tree().has_meta("campaign_level_id"):
		get_tree().remove_meta("campaign_level_id")

func request_return() -> void:
	get_tree().set_meta("campaign_return", {"entry": _entry, "level_id": str(_active.get("id", ""))})
	var shell: Node = get_tree().current_scene
	if shell != null and shell.has_method("_open_main_menu"):
		shell.call("_open_main_menu")
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_node_added(node: Node) -> void:
	if node.name == "SimRunner" and node.has_signal("match_ended"):
		if not node.is_connected("match_ended", _on_match_ended):
			node.connect("match_ended", _on_match_ended)

func _on_match_ended(winner: int, reason: String) -> void:
	if not is_active() or bool(_result.get("ok", false)):
		return
	if winner != int(OpsState.winner_id) or int(OpsState.match_phase) < int(OpsState.MatchPhase.ENDING):
		return # Abandoned, invalid and no-contest sessions are not completed attempts.
	if (winner <= 0 and reason != "domination_draw") or reason in ["desync_failure", "contest_expired", "disconnect", "cancelled"]:
		_result = {"ok": true, "no_contest": true, "won": false, "stingers": 0, "best_ms": 0, "next_id": ""}
		return
	_result = store.record_attempt(player_id(), ProfileManager.get_display_name(), _active, _run_id, winner == 1, int(OpsState.match_elapsed_ms), _entry)
	progress_changed.emit()

func retry_result_save() -> void:
	_on_match_ended(int(OpsState.winner_id), str(OpsState.match_end_reason))
