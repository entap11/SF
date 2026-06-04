extends SceneTree

const MAP_2V2_SOURCE: String = "res://maps/_future/nomansland/MAP_nomansland__545__v01_top2_sides__1p.json"
const BOOT_TIMEOUT_MS: int = 18000

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile_manager: Node = root.get_node_or_null("ProfileManager")
	if profile_manager != null:
		profile_manager.set("_user_id", "u_prematch_2v2_local")
		profile_manager.set("_display_name", "Swarm Father")
	var ops_state: Node = root.get_node_or_null("OpsState")
	if ops_state != null and ops_state.has_method("sim_mutate"):
		if ops_state.has_method("set_team_mode_override"):
			ops_state.call("set_team_mode_override", "2v2")
		ops_state.call("sim_mutate", "prematch_orientation_2v2_card.seed_roster", func() -> void:
			ops_state.set("match_roster", [
				{"seat": 1, "uid": "u_prematch_2v2_local", "display_name": "Swarm Father", "is_local": true, "is_cpu": false, "active": true, "team_id": 1},
				{"seat": 2, "uid": "u_prematch_2v2_ally", "display_name": "Mrs. SwarmDaddy", "is_local": false, "is_cpu": false, "active": true, "team_id": 1},
				{"seat": 3, "uid": "u_prematch_2v2_remote_a", "display_name": "Third Swarm", "is_local": false, "is_cpu": false, "active": true, "team_id": 2},
				{"seat": 4, "uid": "u_prematch_2v2_remote_b", "display_name": "Fourth Swarm", "is_local": false, "is_cpu": false, "active": true, "team_id": 2}
			])
		)
	_set_2v2_tree_meta()

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
	_expect(card != null and card.visible, "2v2 identity card did not spawn", {})
	if _failed:
		await _finish()
		return

	for seat in range(1, 5):
		_expect(_visible_label_text(card, "P%dLabel" % seat) == "PLAYER %d" % seat, "Player label missing", {"seat": seat})
		_expect(not _visible_label_text(card, "P%dName" % seat).strip_edges().is_empty(), "Player name missing", {"seat": seat})
		var wash: ColorRect = card.get_node_or_null("P%dWash" % seat) as ColorRect
		var accent: ColorRect = card.get_node_or_null("P%dAccent" % seat) as ColorRect
		_expect(wash != null and wash.visible, "Player wash missing", {"seat": seat})
		_expect(accent != null and accent.visible, "Player accent missing", {"seat": seat})

	var diagonal: ColorRect = card.get_node_or_null("DiagonalDivider") as ColorRect
	var divider_v: ColorRect = card.get_node_or_null("QuadrantDividerV") as ColorRect
	var divider_h: ColorRect = card.get_node_or_null("QuadrantDividerH") as ColorRect
	var vs_streak: ColorRect = card.get_node_or_null("TeamVsStreak") as ColorRect
	var vs_label: Label = card.get_node_or_null("TeamVsLabel") as Label
	_expect(diagonal != null and not diagonal.visible, "2v2 card should not show 1v1 diagonal divider", {})
	_expect(divider_v != null and divider_v.visible, "2v2 vertical divider missing", {})
	_expect(divider_h != null and divider_h.visible, "2v2 horizontal divider missing", {})
	_expect(vs_streak != null and vs_streak.visible, "2v2 VS streak missing", {})
	_expect(vs_label != null and vs_label.visible and vs_label.text == "VS.", "2v2 VS label missing", {"text": vs_label.text if vs_label != null else ""})

	_expect(_label_pos(card, "P1Label").x < _label_pos(card, "P3Label").x, "P1 should be on left team side", {})
	_expect(_label_pos(card, "P2Label").x < _label_pos(card, "P4Label").x, "P2 should be on left team side", {})
	_expect(_label_pos(card, "P2Label").y > _label_pos(card, "P1Label").y, "P2 should be below P1", {})
	_expect(_label_pos(card, "P4Label").y > _label_pos(card, "P3Label").y, "P4 should be below P3", {})

	var records_panel: Control = await _wait_for_node("/root/Shell/HUDCanvasLayer/HUDRoot/PreMatchOverlay/RecordsPanel", BOOT_TIMEOUT_MS) as Control
	_expect(records_panel != null, "Prematch records panel missing", {})
	if records_panel != null:
		var team_line: String = _visible_label_text(records_panel, "RecordsBg/RecordsVBox/RecordP2")
		_expect(team_line.find("Swarm Father") >= 0, "Prematch team line should show local handle", {"text": team_line})
		_expect(team_line.find("u_prematch") < 0, "Prematch team line should not show raw uid", {"text": team_line})
		_expect(team_line.find("[") < 0 and team_line.find("]") < 0, "Prematch team line should not show id brackets", {"text": team_line})

	var focus_ids: Array = arena_node.call("_resolve_prematch_focus_hive_ids") as Array
	var local_ids: Array = arena_node.call("_resolve_local_starting_hive_ids") as Array
	_expect(focus_ids == local_ids, "2v2 focus should remain local-only", {"focus_ids": focus_ids, "local_ids": local_ids})
	var running_ok: bool = await _wait_for_match_running(ops_state, BOOT_TIMEOUT_MS)
	_expect(running_ok, "2v2 prematch identity flow did not reach RUNNING", {
		"phase": int(ops_state.get("match_phase")) if ops_state != null else -1
	})
	if not _failed:
		print("PREMATCH_ORIENTATION_2V2_CARD_SMOKE: PASS")
	await _finish()

func _set_2v2_tree_meta() -> void:
	set_meta("start_game", true)
	set_meta("vs_mode", "2V2")
	set_meta("vs_price_usd", 0)
	set_meta("vs_free_roll", true)
	set_meta("vs_assigned_players", ["Swarm Father", "Mrs. SwarmDaddy", "Third Swarm", "Fourth Swarm"])
	set_meta("vs_open_slots", 0)
	set_meta("vs_required_players", 4)
	set_meta("vs_sync_start", true)
	set_meta("vs_stage_map_paths", [MAP_2V2_SOURCE])
	set_meta("vs_stage_current_index", 0)
	set_meta("vs_stage_round_results", [])
	set_meta("vs_local_profile", {
		"uid": "u_prematch_2v2_local",
		"display_name": "Swarm Father"
	})
	set_meta("vs_remote_profile", {
		"uid": "u_prematch_2v2_remote_a",
		"display_name": "Third Swarm",
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

func _label_pos(parent: Node, path: String) -> Vector2:
	var label: Label = parent.get_node_or_null(path) as Label
	if label == null:
		return Vector2.ZERO
	return label.position

func _expect(condition: bool, message: String, details: Dictionary) -> void:
	if condition:
		return
	_failed = true
	push_error("PREMATCH_ORIENTATION_2V2_CARD_SMOKE: %s -> %s" % [message, details])

func _finish() -> void:
	var shell: Node = root.get_node_or_null("Shell")
	if shell != null:
		shell.queue_free()
		await process_frame
	quit(1 if _failed else 0)
