extends Node

signal jukebox_result_recorded(event: Dictionary)

const SFLog = preload("res://scripts/util/sf_log.gd")
const MAP_REGISTRY = preload("res://scripts/maps/map_registry.gd")
const JukeboxLeaderboardStoreScript = preload("res://scripts/state/jukebox_leaderboard_store.gd")

const MAP_RECORD_MODE_ID: String = "ASYNC_SINGLE_MAP_TIMED"
const DEFAULT_PERIOD: String = "WEEKLY"
const META_MAP_PATH: String = "jukebox_map_path"
const META_MAP_ID: String = "jukebox_map_id"
const META_PERIOD: String = "jukebox_board_period"
const META_LOCAL_OWNER_ID: String = "jukebox_local_owner_id"
const META_RESULT_SIGNATURE: String = "jukebox_result_commit_signature"

@export var profile_manager_path: NodePath = NodePath("/root/ProfileManager")
@export var store_save_path: String = ""

var _leaderboard_store: RefCounted = JukeboxLeaderboardStoreScript.new()

func _ready() -> void:
	SFLog.allow_tag("JUKEBOX_RUNTIME")
	if not store_save_path.strip_edges().is_empty():
		_leaderboard_store.save_path = store_save_path.strip_edges()
	_connect_tree_signals()
	_scan_for_sim_runner()

func debug_set_store_save_path(path: String) -> void:
	store_save_path = path.strip_edges()
	_leaderboard_store.save_path = store_save_path

func debug_reset_store() -> void:
	if _leaderboard_store != null and _leaderboard_store.has_method("debug_reset_state"):
		_leaderboard_store.call("debug_reset_state")

func _connect_tree_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var node_added_cb: Callable = Callable(self, "_on_tree_node_added")
	if not tree.node_added.is_connected(node_added_cb):
		tree.node_added.connect(node_added_cb)

func _scan_for_sim_runner() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var root: Node = tree.get_root()
	if root == null:
		return
	var runner: Node = root.find_child("SimRunner", true, false)
	if runner != null:
		_connect_sim_runner(runner)

func _on_tree_node_added(node: Node) -> void:
	if node == null:
		return
	if node.name != "SimRunner" and not node.has_signal("match_ended"):
		return
	_connect_sim_runner(node)

func _connect_sim_runner(node: Node) -> void:
	if node == null or not node.has_signal("match_ended"):
		return
	var callback: Callable = Callable(self, "_on_runtime_match_ended")
	if not node.is_connected("match_ended", callback):
		node.connect("match_ended", callback)

func _on_runtime_match_ended(winner_id: int, reason: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var local_owner_id: int = clampi(int(tree.get_meta(META_LOCAL_OWNER_ID, 1)), 1, 4)
	if winner_id <= 0 or winner_id != local_owner_id:
		return
	var elapsed_ms: int = maxi(0, int(OpsState.match_elapsed_ms))
	if elapsed_ms <= 0:
		return
	var map_id: String = _resolve_map_id(tree)
	if map_id.is_empty():
		return
	var identity: Dictionary = _resolve_local_identity(tree)
	var player_id: String = str(identity.get("player_id", "")).strip_edges()
	if player_id.is_empty():
		return
	var result_signature: String = _result_signature(map_id, player_id, elapsed_ms, winner_id, reason)
	if str(tree.get_meta(META_RESULT_SIGNATURE, "")).strip_edges() == result_signature:
		return
	var result: Dictionary = _leaderboard_store.record_run_all_periods(map_id, MAP_RECORD_MODE_ID, {
		"player_id": player_id,
		"handle": str(identity.get("handle", "You")).strip_edges(),
		"best_time_ms": elapsed_ms,
		"updated_at": int(Time.get_unix_time_from_system()),
		"source": "jukebox_run"
	})
	if not bool(result.get("ok", false)):
		return
	tree.set_meta(META_RESULT_SIGNATURE, result_signature)
	var event: Dictionary = {
		"type": "jukebox_result_recorded",
		"map_id": map_id,
		"mode_id": MAP_RECORD_MODE_ID,
		"source_mode": str(tree.get_meta("vs_mode", "")).strip_edges().to_upper(),
		"period": _resolve_period(tree),
		"periods_updated": result.get("periods_updated", []),
		"player_id": player_id,
		"winner_id": winner_id,
		"reason": reason,
		"best_time_ms": int(result.get("best_time_ms", elapsed_ms)),
		"updated": bool(result.get("updated", false))
	}
	jukebox_result_recorded.emit(event)
	SFLog.info("JUKEBOX_RUNTIME", event)

func _resolve_map_id(tree: SceneTree) -> String:
	var map_id: String = str(tree.get_meta(META_MAP_ID, "")).strip_edges()
	if not map_id.is_empty():
		return map_id
	var map_path: String = str(tree.get_meta(META_MAP_PATH, "")).strip_edges()
	if map_path.is_empty():
		var stage_maps_any: Variant = tree.get_meta("vs_stage_map_paths", [])
		if typeof(stage_maps_any) == TYPE_ARRAY:
			var stage_maps: Array = stage_maps_any as Array
			var stage_index: int = clampi(int(tree.get_meta("vs_stage_current_index", 0)), 0, maxi(stage_maps.size() - 1, 0))
			if stage_index >= 0 and stage_index < stage_maps.size():
				map_path = str(stage_maps[stage_index]).strip_edges()
	if map_path.is_empty():
		return ""
	return MAP_REGISTRY.map_id_from_path(map_path)

func _resolve_period(tree: SceneTree) -> String:
	var period: String = str(tree.get_meta(META_PERIOD, DEFAULT_PERIOD)).strip_edges().to_upper()
	return period if not period.is_empty() else DEFAULT_PERIOD

func _resolve_local_identity(tree: SceneTree) -> Dictionary:
	var player_id: String = ""
	var handle: String = ""
	var local_profile_any: Variant = tree.get_meta("vs_local_profile", {})
	if typeof(local_profile_any) == TYPE_DICTIONARY:
		var local_profile: Dictionary = local_profile_any as Dictionary
		player_id = str(local_profile.get("uid", local_profile.get("player_id", ""))).strip_edges()
		handle = str(local_profile.get("name", local_profile.get("handle", ""))).strip_edges()
	if player_id.is_empty():
		var profile_manager: Node = get_node_or_null(profile_manager_path)
		if profile_manager != null:
			if profile_manager.has_method("get_user_id"):
				player_id = str(profile_manager.call("get_user_id")).strip_edges()
			if profile_manager.has_method("get_display_name"):
				handle = str(profile_manager.call("get_display_name")).strip_edges()
	if handle.is_empty():
		handle = "You"
	return {
		"player_id": player_id,
		"handle": handle
	}

func _result_signature(map_id: String, player_id: String, elapsed_ms: int, winner_id: int, reason: String) -> String:
	return "%s|%s|%d|%d|%s" % [map_id, player_id, elapsed_ms, winner_id, reason.strip_edges()]
