extends Node

const DEFAULT_MAP: String = "res://maps/json/MAP_TEST.json"
const BOOT_TIMEOUT_MS: int = 18000
const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"

var _failed: bool = false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var tree: SceneTree = get_tree()
	var role: String = _arg_value("--human-pvp-role=").strip_edges().to_lower()
	if role != "guest":
		role = "host"
	var local_uid: String = "u_human_pvp_smoke_remote" if role == "guest" else "u_human_pvp_smoke_local"
	var local_name: String = "SmokeRemote" if role == "guest" else "SmokeLocal"
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null:
		profile_manager.set("_user_id", local_uid)
		profile_manager.set("_display_name", local_name)

	var map_path: String = _arg_value("--human-pvp-map=")
	if map_path.is_empty():
		map_path = DEFAULT_MAP
	var session_id: String = _prepare_handshake_session(role)
	if _failed:
		await _finish(tree)
		return
	_set_1v1_tree_meta(map_path, role, session_id)
	var gamebot: Node = get_node_or_null("/root/Gamebot")
	if gamebot != null and gamebot.has_method("set_vs"):
		gamebot.call("set_vs", map_path)

	var shell_scene: PackedScene = load("res://scenes/Shell.tscn") as PackedScene
	_expect(shell_scene != null, "Shell.tscn failed to load", {})
	if _failed:
		await _finish(tree)
		return
	var shell_instance: Node = shell_scene.instantiate()
	tree.root.add_child(shell_instance)
	await tree.process_frame

	var shell_node: Node = await _wait_for_node(tree, "/root/Shell", BOOT_TIMEOUT_MS)
	_expect(shell_node != null, "Shell did not spawn", {})
	if _failed:
		await _finish(tree)
		return
	var arena_node: Node = await _wait_for_node(tree, "/root/Shell/ArenaRoot/Main/WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena", BOOT_TIMEOUT_MS)
	_expect(arena_node != null, "Arena did not spawn", {})
	if _failed:
		await _finish(tree)
		return
	var countdown_label: Label = await _wait_for_node(tree, "/root/Shell/HUDCanvasLayer/HUDRoot/PreMatchOverlay/CountdownLabel", BOOT_TIMEOUT_MS) as Label
	_expect(countdown_label != null, "Shell prematch countdown did not spawn", {})
	if _failed:
		await _finish(tree)
		return
	await tree.process_frame
	_expect(countdown_label.visible and not countdown_label.text.strip_edges().is_empty(), "Shell prematch countdown is not visible", {
		"text": countdown_label.text if countdown_label != null else "",
		"visible": countdown_label.visible if countdown_label != null else false
	})
	_expect(_count_nodes_named(tree.root, "CountdownLabel") == 1, "Expected exactly one prematch countdown label", {
		"count": _count_nodes_named(tree.root, "CountdownLabel")
	})
	if _failed:
		await _finish(tree)
		return

	var ops_state: Node = get_node_or_null("/root/OpsState")
	var running_ok: bool = await _wait_for_match_running(tree, ops_state, BOOT_TIMEOUT_MS)
	_expect(running_ok, "1v1 boot did not reach RUNNING", {
		"phase": int(ops_state.get("match_phase")) if ops_state != null else -1,
		"map": map_path
	})
	if not _failed:
		_assert_runtime_local_seat(role)
	if not _failed:
		_assert_runtime_lane_can_be_instanced(ops_state, 2 if role == "guest" else 1)
	if not _failed:
		await _assert_runtime_telemetry_log(tree)
	if not _failed:
		print("HUMAN_PVP_BOOT_SMOKE: PASS")
	await _finish(tree)

func _prepare_handshake_session(_role: String) -> String:
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	_expect(handshake != null, "VsHandshake autoload missing", {})
	if _failed:
		return ""
	if handshake.has_method("clear"):
		handshake.call("clear")
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
	if handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	var host_profile: Dictionary = {
		"uid": "u_human_pvp_smoke_local",
		"display_name": "SmokeLocal"
	}
	var guest_profile: Dictionary = {
		"uid": "u_human_pvp_smoke_remote",
		"display_name": "SmokeRemote"
	}
	var invite: Dictionary = handshake.call("create_invite", host_profile, {"mode": "PVP", "free_roll": true}) as Dictionary
	_expect(bool(invite.get("ok", false)), "create_invite failed", invite)
	if _failed:
		return ""
	var invite_code: String = str(invite.get("invite_code", "")).strip_edges()
	var session_id: String = str(invite.get("session_id", "")).strip_edges()
	var join_result: Dictionary = handshake.call("join_invite", invite_code, guest_profile) as Dictionary
	_expect(bool(join_result.get("ok", false)), "join_invite failed", join_result)
	if _failed:
		return ""
	var joined_session_id: String = str(join_result.get("session_id", "")).strip_edges()
	_expect(joined_session_id == session_id, "join_invite returned wrong session", {
		"invite_session": session_id,
		"joined_session": joined_session_id
	})
	return session_id

func _set_1v1_tree_meta(map_path: String, role: String, session_id: String) -> void:
	var tree: SceneTree = get_tree()
	var is_guest: bool = role == "guest"
	tree.set_meta("start_game", true)
	tree.set_meta("vs_mode", "1V1")
	tree.set_meta("vs_price_usd", 0)
	tree.set_meta("vs_free_roll", true)
	tree.set_meta("vs_assigned_players", ["SmokeLocal", "SmokeRemote"])
	tree.set_meta("vs_open_slots", 0)
	tree.set_meta("vs_required_players", 2)
	tree.set_meta("vs_sync_start", true)
	tree.set_meta("vs_sync_join_sec", 0)
	tree.set_meta("vs_window_sec", 0)
	tree.set_meta("vs_window_started_unix", 0)
	tree.set_meta("vs_window_deadline_unix", 0)
	tree.set_meta("vs_stage_map_paths", [map_path])
	tree.set_meta("vs_stage_current_index", 0)
	tree.set_meta("vs_stage_round_results", [])
	tree.set_meta("vs_handshake_session_id", session_id)
	tree.set_meta("vs_handshake_role", role)
	tree.set_meta("vs_handshake_invite_code", "")
	tree.set_meta("vs_local_profile", {
		"uid": "u_human_pvp_smoke_remote" if is_guest else "u_human_pvp_smoke_local",
		"display_name": "SmokeRemote" if is_guest else "SmokeLocal"
	})
	tree.set_meta("vs_remote_profile", {
		"uid": "u_human_pvp_smoke_local" if is_guest else "u_human_pvp_smoke_remote",
		"display_name": "SmokeLocal" if is_guest else "SmokeRemote",
		"is_cpu": false
	})

func _wait_for_node(tree: SceneTree, path: NodePath, timeout_ms: int) -> Node:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		var node: Node = tree.root.get_node_or_null(path)
		if node != null:
			return node
		await tree.process_frame
	return null

func _wait_for_match_running(tree: SceneTree, ops_state: Node, timeout_ms: int) -> bool:
	if ops_state == null:
		return false
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if int(ops_state.get("match_phase")) == int(ops_state.MatchPhase.RUNNING):
			return true
		await tree.process_frame
	return false

func _count_nodes_named(root_node: Node, node_name: String) -> int:
	if root_node == null:
		return 0
	var count: int = 1 if root_node.name == node_name else 0
	for child in root_node.get_children():
		count += _count_nodes_named(child, node_name)
	return count

func _assert_runtime_local_seat(role: String) -> void:
	var runtime: Node = get_node_or_null("/root/VsPvpRuntime")
	_expect(runtime != null and runtime.has_method("get_local_seat"), "VsPvpRuntime missing local seat API", {})
	if _failed:
		return
	var expected_seat: int = 2 if role == "guest" else 1
	var local_seat: int = int(runtime.call("get_local_seat"))
	_expect(local_seat == expected_seat, "PvP runtime resolved wrong local seat", {
		"role": role,
		"local_seat": local_seat,
		"expected": expected_seat,
		"debug": runtime.call("get_debug_snapshot") if runtime.has_method("get_debug_snapshot") else {}
	})
	var shell_arena: Node = get_node_or_null("/root/Shell/ArenaRoot/Main/WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")
	if shell_arena != null:
		var active_player: int = int(shell_arena.get("active_player_id"))
		_expect(active_player == expected_seat, "Arena active player should match local PvP seat", {
			"role": role,
			"active_player_id": active_player,
			"expected": expected_seat
		})

func _assert_runtime_lane_can_be_instanced(ops_state: Node, owner_id: int) -> void:
	if ops_state == null or not ops_state.has_method("get_state") or not ops_state.has_method("apply_lane_intent"):
		_expect(false, "OpsState missing lane APIs", {})
		return
	var state_ref: Variant = ops_state.call("get_state")
	if state_ref == null:
		_expect(false, "OpsState has no GameState", {})
		return
	var hives: Array = state_ref.get("hives") as Array
	var src_id: int = -1
	var dst_id: int = -1
	for src_any in hives:
		if not (src_any is HiveData):
			continue
		var src: HiveData = src_any as HiveData
		if int(src.owner_id) != owner_id:
			continue
		for dst_any in hives:
			if not (dst_any is HiveData):
				continue
			var dst: HiveData = dst_any as HiveData
			if int(dst.owner_id) == owner_id:
				continue
			if state_ref.call("can_connect", int(src.id), int(dst.id)):
				src_id = int(src.id)
				dst_id = int(dst.id)
				break
		if src_id > 0:
			break
	_expect(src_id > 0 and dst_id > 0, "No runtime lane candidate found", {})
	if _failed:
		return
	var result: Dictionary = ops_state.call("apply_lane_intent", src_id, dst_id, "attack") as Dictionary
	_expect(bool(result.get("ok", false)), "Runtime lane intent failed", result)

func _assert_runtime_telemetry_log(tree: SceneTree) -> void:
	var runtime: Node = get_node_or_null("/root/VsPvpRuntime")
	_expect(runtime != null and runtime.has_method("get_debug_snapshot"), "VsPvpRuntime missing debug snapshot API", {})
	if _failed:
		return
	var deadline: int = Time.get_ticks_msec() + 2500
	var log_path: String = ""
	while Time.get_ticks_msec() < deadline:
		var snapshot: Dictionary = runtime.call("get_debug_snapshot") as Dictionary
		log_path = str(snapshot.get("runtime_telemetry_log_path", "")).strip_edges()
		if not log_path.is_empty() and FileAccess.file_exists(log_path):
			var file: FileAccess = FileAccess.open(log_path, FileAccess.READ)
			if file != null:
				var line_count: int = 0
				var saw_sample: bool = false
				var saw_lane_event: bool = false
				while not file.eof_reached():
					var line: String = file.get_line()
					if line.strip_edges().is_empty():
						continue
					line_count += 1
					if line.find("\"event\":\"sample\"") >= 0:
						saw_sample = true
					if line.find("\"event\":\"lane_intent_sent\"") >= 0:
						saw_lane_event = true
				file.close()
				_expect(line_count >= 2 and saw_sample and saw_lane_event, "Runtime telemetry JSONL did not receive required samples/events", {
					"path": log_path,
					"line_count": line_count,
					"saw_sample": saw_sample,
					"saw_lane_event": saw_lane_event
				})
				return
		await tree.process_frame
	_expect(false, "Runtime telemetry JSONL was not created", {"path": log_path})

func _expect(condition: bool, message: String, details: Dictionary) -> void:
	if condition:
		return
	_failed = true
	push_error("HUMAN_PVP_BOOT_SMOKE: %s -> %s" % [message, details])

func _finish(tree: SceneTree) -> void:
	var shell: Node = tree.root.get_node_or_null("Shell")
	if shell != null:
		shell.queue_free()
		await tree.process_frame
	tree.quit(1 if _failed else 0)

func _arg_value(prefix: String) -> String:
	var args: Array = []
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	for arg in args:
		var value: String = str(arg)
		if value.begins_with(prefix):
			return value.substr(prefix.length()).strip_edges()
	return ""
