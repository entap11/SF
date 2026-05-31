extends SceneTree

const MAP_4P_SOURCE: String = "res://maps/_future/nomansland/MAP_nomansland__545__v01_top2_sides__1p.json"
const BOOT_TIMEOUT_MS: int = 10000

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile_manager: Node = root.get_node_or_null("ProfileManager")
	if profile_manager != null:
		profile_manager.set("_user_id", "u_prematch_4p_local")
		profile_manager.set("_display_name", "Swarm Father")
	var ops_state: Node = root.get_node_or_null("OpsState")
	if ops_state != null and ops_state.has_method("sim_mutate"):
		if ops_state.has_method("set_team_mode_override"):
			ops_state.call("set_team_mode_override", "ffa")
		ops_state.call("sim_mutate", "prematch_orientation_4p_card.seed_roster", func() -> void:
			ops_state.set("match_roster", [
				{"seat": 1, "uid": "u_prematch_4p_local", "display_name": "Swarm Father", "is_local": true, "is_cpu": false, "active": true, "team_id": 1},
				{"seat": 2, "uid": "u_prematch_4p_remote_a", "display_name": "Mrs. SwarmDaddy", "is_local": false, "is_cpu": false, "active": true, "team_id": 2},
				{"seat": 3, "uid": "u_prematch_4p_remote_b", "display_name": "Third Swarm", "is_local": false, "is_cpu": false, "active": true, "team_id": 3},
				{"seat": 4, "uid": "u_prematch_4p_remote_c", "display_name": "Fourth Swarm", "is_local": false, "is_cpu": false, "active": true, "team_id": 4}
			])
		)
	_set_4p_tree_meta()

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
	_expect(card != null and card.visible, "4p identity card did not spawn", {})
	if _failed:
		await _finish()
		return

	for seat in range(1, 5):
		_expect(_visible_label_text(card, "P%dLabel" % seat) == "PLAYER %d" % seat, "Player label missing", {"seat": seat})
		_expect(not _visible_label_text(card, "P%dName" % seat).strip_edges().is_empty(), "Player name missing", {"seat": seat})
		var wash: ColorRect = card.get_node_or_null("P%dWash" % seat) as ColorRect
		_expect(wash != null and wash.visible, "Player wash missing", {"seat": seat})

	var diagonal: ColorRect = card.get_node_or_null("DiagonalDivider") as ColorRect
	var divider_v: ColorRect = card.get_node_or_null("QuadrantDividerV") as ColorRect
	var divider_h: ColorRect = card.get_node_or_null("QuadrantDividerH") as ColorRect
	_expect(diagonal != null and not diagonal.visible, "4p card should not show diagonal divider", {})
	_expect(divider_v != null and divider_v.visible, "4p vertical divider missing", {})
	_expect(divider_h != null and divider_h.visible, "4p horizontal divider missing", {})
	_expect(_label_pos(card, "P2Label").x > _label_pos(card, "P1Label").x, "P2 is not in right quadrant", {})
	_expect(_label_pos(card, "P3Label").y > _label_pos(card, "P1Label").y, "P3 is not in lower quadrant", {})
	_expect(_label_pos(card, "P4Label").x > _label_pos(card, "P3Label").x and _label_pos(card, "P4Label").y > _label_pos(card, "P2Label").y, "P4 is not in lower-right quadrant", {})

	var focus_ids: Array = arena_node.call("_resolve_prematch_focus_hive_ids") as Array
	_expect(focus_ids.size() >= 4, "4p focus sequence does not include four hives", {"focus_ids": focus_ids})
	_assert_focus_has_owners(arena_node, focus_ids)
	var running_ok: bool = await _wait_for_match_running(ops_state, BOOT_TIMEOUT_MS)
	_expect(running_ok, "4p prematch identity flow did not reach RUNNING", {
		"phase": int(ops_state.get("match_phase")) if ops_state != null else -1
	})
	if not _failed:
		print("PREMATCH_ORIENTATION_4P_CARD_SMOKE: PASS")
	await _finish()

func _set_4p_tree_meta() -> void:
	set_meta("start_game", true)
	set_meta("vs_mode", "4P FFA")
	set_meta("vs_price_usd", 0)
	set_meta("vs_free_roll", true)
	set_meta("vs_assigned_players", ["Swarm Father", "Mrs. SwarmDaddy", "Third Swarm", "Fourth Swarm"])
	set_meta("vs_open_slots", 0)
	set_meta("vs_required_players", 4)
	set_meta("vs_sync_start", true)
	set_meta("vs_stage_map_paths", [MAP_4P_SOURCE])
	set_meta("vs_stage_current_index", 0)
	set_meta("vs_stage_round_results", [])
	set_meta("vs_local_profile", {
		"uid": "u_prematch_4p_local",
		"display_name": "Swarm Father"
	})
	set_meta("vs_remote_profile", {
		"uid": "u_prematch_4p_remote_a",
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

func _label_pos(parent: Node, path: String) -> Vector2:
	var label: Label = parent.get_node_or_null(path) as Label
	if label == null:
		return Vector2.ZERO
	return label.position

func _assert_focus_has_owners(arena_node: Node, focus_ids: Array) -> void:
	var state_ref: Variant = arena_node.get("state")
	var owner_seen: Dictionary = {}
	for hive_id_any in focus_ids:
		var hive: HiveData = state_ref.call("find_hive_by_id", int(hive_id_any)) as HiveData
		if hive != null:
			owner_seen[int(hive.owner_id)] = true
	for seat in range(1, 5):
		_expect(bool(owner_seen.get(seat, false)), "4p focus sequence missing player owner", {"seat": seat, "owners": owner_seen})

func _expect(condition: bool, message: String, details: Dictionary) -> void:
	if condition:
		return
	_failed = true
	push_error("PREMATCH_ORIENTATION_4P_CARD_SMOKE: %s -> %s" % [message, details])

func _finish() -> void:
	var shell: Node = root.get_node_or_null("Shell")
	if shell != null:
		shell.queue_free()
		await process_frame
	quit(1 if _failed else 0)
