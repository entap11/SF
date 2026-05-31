extends SceneTree

const MAP_3P: String = "res://maps/delta/MAP_delta__SBASE__3p.json"
const BOOT_TIMEOUT_MS: int = 10000

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile_manager: Node = root.get_node_or_null("ProfileManager")
	if profile_manager != null:
		profile_manager.set("_user_id", "u_prematch_3p_local")
		profile_manager.set("_display_name", "Swarm Father")
	var ops_state: Node = root.get_node_or_null("OpsState")
	if ops_state != null and ops_state.has_method("sim_mutate"):
		if ops_state.has_method("set_team_mode_override"):
			ops_state.call("set_team_mode_override", "ffa")
		ops_state.call("sim_mutate", "prematch_orientation_3p_card.seed_roster", func() -> void:
			ops_state.set("match_roster", [
				{"seat": 1, "uid": "u_prematch_3p_local", "display_name": "Swarm Father", "is_local": true, "is_cpu": false, "active": true, "team_id": 1},
				{"seat": 2, "uid": "u_prematch_3p_remote_a", "display_name": "Mrs. SwarmDaddy", "is_local": false, "is_cpu": false, "active": true, "team_id": 2},
				{"seat": 3, "uid": "u_prematch_3p_remote_b", "display_name": "Third Swarm", "is_local": false, "is_cpu": false, "active": true, "team_id": 3}
			])
		)
	_set_3p_tree_meta()

	var shell_scene: PackedScene = load("res://scenes/Shell.tscn") as PackedScene
	_expect(shell_scene != null, "Shell.tscn failed to load", {})
	if _failed:
		quit(1)
		return
	var shell_instance: Node = shell_scene.instantiate()
	root.add_child(shell_instance)
	await process_frame

	var arena_node: Node = await _wait_for_node("/root/Shell/ArenaRoot/Main/WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena", BOOT_TIMEOUT_MS)
	_expect(arena_node != null, "Arena did not spawn", {})
	var card: Control = await _wait_for_node("/root/Shell/HUDCanvasLayer/HUDRoot/PreMatchOverlay/IdentityCard", BOOT_TIMEOUT_MS) as Control
	_expect(card != null and card.visible, "3p identity card did not spawn", {})
	if _failed:
		await _finish()
		return

	_expect(_visible_label_text(card, "P1Label") == "PLAYER 1", "P1 label missing", {"text": _visible_label_text(card, "P1Label")})
	_expect(_visible_label_text(card, "P2Label") == "PLAYER 2", "P2 label missing", {"text": _visible_label_text(card, "P2Label")})
	_expect(_visible_label_text(card, "P3Label") == "PLAYER 3", "P3 label missing", {"text": _visible_label_text(card, "P3Label")})
	_expect(_visible_label_text(card, "P1Name") == "Swarm Father", "P1 name missing", {"text": _visible_label_text(card, "P1Name")})
	_expect(_visible_label_text(card, "P2Name") == "Mrs. SwarmDaddy", "P2 name missing", {"text": _visible_label_text(card, "P2Name")})
	_expect(not _visible_label_text(card, "P3Name").strip_edges().is_empty(), "P3 name missing", {"text": _visible_label_text(card, "P3Name")})

	var divider: ColorRect = card.get_node_or_null("DiagonalDivider") as ColorRect
	var p3_wash: ColorRect = card.get_node_or_null("P3Wash") as ColorRect
	_expect(divider != null and not divider.visible, "3p card should not show diagonal divider", {})
	_expect(p3_wash != null and p3_wash.visible, "P3 wash missing", {})
	_expect(_label_y(card, "P1Label") < _label_y(card, "P2Label"), "P2 row is not below P1", {})
	_expect(_label_y(card, "P2Label") < _label_y(card, "P3Label"), "P3 row is not below P2", {})

	var local_hive_ids: Array = arena_node.call("_resolve_local_starting_hive_ids") as Array
	_expect(not local_hive_ids.is_empty(), "Local starting hives not identified in 3p", {})
	var running_ok: bool = await _wait_for_match_running(ops_state, BOOT_TIMEOUT_MS)
	_expect(running_ok, "3p prematch identity flow did not reach RUNNING", {
		"phase": int(ops_state.get("match_phase")) if ops_state != null else -1
	})
	if not _failed:
		print("PREMATCH_ORIENTATION_3P_CARD_SMOKE: PASS")
	await _finish()

func _set_3p_tree_meta() -> void:
	set_meta("start_game", true)
	set_meta("vs_mode", "3P FFA")
	set_meta("vs_price_usd", 0)
	set_meta("vs_free_roll", true)
	set_meta("vs_assigned_players", ["Swarm Father", "Mrs. SwarmDaddy", "Third Swarm"])
	set_meta("vs_open_slots", 0)
	set_meta("vs_required_players", 3)
	set_meta("vs_sync_start", true)
	set_meta("vs_stage_map_paths", [MAP_3P])
	set_meta("vs_stage_current_index", 0)
	set_meta("vs_stage_round_results", [])
	set_meta("vs_local_profile", {
		"uid": "u_prematch_3p_local",
		"display_name": "Swarm Father"
	})
	set_meta("vs_remote_profile", {
		"uid": "u_prematch_3p_remote_a",
		"display_name": "Mrs. SwarmDaddy",
		"is_cpu": false
	})

func _wait_for_node(path: NodePath, timeout_ms: int) -> Node:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		var node: Node = root.get_node_or_null(path)
		if node != null:
			return node
		await process_frame
	return null

func _wait_for_match_running(ops_state: Node, timeout_ms: int) -> bool:
	if ops_state == null:
		return false
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if int(ops_state.get("match_phase")) == int(ops_state.MatchPhase.RUNNING):
			return true
		await process_frame
	return false

func _visible_label_text(parent: Node, path: String) -> String:
	var label: Label = parent.get_node_or_null(path) as Label
	if label == null or not label.visible:
		return ""
	return label.text

func _label_y(parent: Node, path: String) -> float:
	var label: Label = parent.get_node_or_null(path) as Label
	if label == null:
		return -1.0
	return label.position.y

func _expect(condition: bool, message: String, details: Dictionary) -> void:
	if condition:
		return
	_failed = true
	push_error("PREMATCH_ORIENTATION_3P_CARD_SMOKE: %s -> %s" % [message, details])

func _finish() -> void:
	var shell: Node = root.get_node_or_null("Shell")
	if shell != null:
		shell.queue_free()
		await process_frame
	quit(1 if _failed else 0)
