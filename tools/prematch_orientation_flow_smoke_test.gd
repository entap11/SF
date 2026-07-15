extends SceneTree

const DEFAULT_MAP: String = "res://maps/json/MAP_TEST.json"
const BOOT_TIMEOUT_MS: int = 18000

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var tree: SceneTree = self
	var profile_manager: Node = root.get_node_or_null("ProfileManager")
	if profile_manager != null:
		profile_manager.set("_user_id", "u_prematch_orientation_local")
		profile_manager.set("_display_name", "Swarm Father")
	var ops_state: Node = root.get_node_or_null("OpsState")
	if ops_state != null and ops_state.has_method("sim_mutate"):
		ops_state.call("sim_mutate", "prematch_orientation_flow_smoke.seed_roster", func() -> void:
			ops_state.set("match_roster", [
				{"seat": 1, "uid": "u_prematch_orientation_local", "display_name": "Swarm Father", "is_local": true, "is_cpu": false, "active": true, "team_id": 1},
				{"seat": 2, "uid": "u_prematch_orientation_remote", "display_name": "Mrs. SwarmDaddy", "is_local": false, "is_cpu": false, "active": true, "team_id": 2}
			])
		)

	var map_path: String = _arg_value("--prematch-orientation-map=")
	if map_path.is_empty():
		map_path = DEFAULT_MAP
	_set_1v1_tree_meta(map_path)

	var shell_scene: PackedScene = load("res://scenes/Shell.tscn") as PackedScene
	_expect(shell_scene != null, "Shell.tscn failed to load", {})
	if _failed:
		await _finish(tree)
		return
	var shell_instance: Node = shell_scene.instantiate()
	tree.root.add_child(shell_instance)
	await tree.process_frame

	var arena_node: Node = await _wait_for_node(tree, "/root/Shell/ArenaRoot/Main/WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena", BOOT_TIMEOUT_MS)
	_expect(arena_node != null, "Arena did not spawn", {})
	if _failed:
		await _finish(tree)
		return

	var card: Control = await _wait_for_node(tree, "/root/Shell/HUDCanvasLayer/HUDRoot/PreMatchOverlay/IdentityCard", BOOT_TIMEOUT_MS) as Control
	_expect(card != null and card.visible, "Identity card did not spawn under HUD", {"path": str(card.get_path()) if card != null else ""})
	if _failed:
		await _finish(tree)
		return
	_expect(not str(card.get_path()).contains("MapRoot"), "Identity card mounted under MapRoot", {"path": str(card.get_path())})
	_expect(_label_text(card, "P1Label") == "PLAYER 1", "P1 label missing", {"text": _label_text(card, "P1Label")})
	_expect(_label_text(card, "P2Label") == "PLAYER 2", "P2 label missing", {"text": _label_text(card, "P2Label")})
	_expect(_label_text(card, "P1Name") == "Swarm Father", "P1 metadata name not used", {"text": _label_text(card, "P1Name")})
	_expect(_label_text(card, "P2Name") == "Mrs. SwarmDaddy", "P2 metadata name not used", {"text": _label_text(card, "P2Name")})
	_expect(_label_font_size(card, "P1Label") >= 38, "Prematch player label is below the in-game readability floor", {"font_size": _label_font_size(card, "P1Label")})
	_expect(_label_font_size(card, "P1Name") >= 45, "Prematch player name is below the in-game readability floor", {"font_size": _label_font_size(card, "P1Name")})
	var records_panel: Control = tree.root.get_node_or_null("/root/Shell/HUDCanvasLayer/HUDRoot/PreMatchOverlay/RecordsPanel") as Control
	_expect(records_panel == null or not records_panel.visible, "Redundant prematch facts card should stay hidden", {})

	var top_wash: TextureRect = tree.root.get_node_or_null("/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot/TopBufferBackground/LocalTeamColorWash") as TextureRect
	var bottom_wash: TextureRect = tree.root.get_node_or_null("/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot/BottomBufferBackground/LocalTeamColorWash") as TextureRect
	var obsolete_top_wash: Node = tree.root.get_node_or_null("/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot/TopBufferBackground/OpponentTeamColorWash")
	_expect(top_wash != null and top_wash.visible, "Local top color buffer missing", {})
	_expect(bottom_wash != null and bottom_wash.visible, "Local bottom color buffer missing", {})
	_expect(obsolete_top_wash == null, "Opponent color buffer should not be used on local screen", {})
	if top_wash != null and bottom_wash != null:
		_expect(_colors_close(top_wash.modulate, bottom_wash.modulate), "Top and bottom buffers should use same local color", {
			"top": str(top_wash.modulate),
			"bottom": str(bottom_wash.modulate)
		})

	var local_hive_ids: Array = arena_node.call("_resolve_local_starting_hive_ids") as Array
	_expect(not local_hive_ids.is_empty(), "Local starting hives not identified", {})
	_assert_local_hives_owned(arena_node, local_hive_ids)

	var hives_before: String = _hive_snapshot(arena_node)
	var deadline: int = Time.get_ticks_msec() + 6500
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame
	var hives_after: String = _hive_snapshot(arena_node)
	_expect(hives_before == hives_after, "Pre-match orientation visuals mutated hives", {
		"before": hives_before,
		"after": hives_after
	})
	var pulse_root: Node = arena_node.get_node_or_null("PoolsRoot/PrematchPulseRoot")
	_expect(pulse_root != null, "Prematch pulse root not under PoolsRoot", {})

	var running_ok: bool = await _wait_for_match_running(tree, ops_state, BOOT_TIMEOUT_MS)
	_expect(running_ok, "Prematch orientation flow did not reach RUNNING", {
		"phase": int(ops_state.get("match_phase")) if ops_state != null else -1
	})
	if not _failed:
		print("PREMATCH_ORIENTATION_FLOW_SMOKE: PASS")
	await _finish(tree)

func _set_1v1_tree_meta(map_path: String) -> void:
	var tree: SceneTree = self
	tree.set_meta("start_game", true)
	tree.set_meta("vs_mode", "1V1")
	tree.set_meta("vs_price_usd", 0)
	tree.set_meta("vs_free_roll", true)
	tree.set_meta("vs_assigned_players", ["Swarm Father", "Mrs. SwarmDaddy"])
	tree.set_meta("vs_open_slots", 0)
	tree.set_meta("vs_required_players", 2)
	tree.set_meta("vs_sync_start", true)
	tree.set_meta("vs_stage_map_paths", [map_path])
	tree.set_meta("vs_stage_current_index", 0)
	tree.set_meta("vs_stage_round_results", [])
	tree.set_meta("vs_local_profile", {
		"uid": "u_prematch_orientation_local",
		"display_name": "Swarm Father"
	})
	tree.set_meta("vs_remote_profile", {
		"uid": "u_prematch_orientation_remote",
		"display_name": "Mrs. SwarmDaddy",
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

func _label_text(root: Node, path: String) -> String:
	var label: Label = root.get_node_or_null(path) as Label
	if label == null:
		return ""
	return label.text

func _label_font_size(root: Node, path: String) -> int:
	var label: Label = root.get_node_or_null(path) as Label
	if label == null:
		return 0
	return label.get_theme_font_size("font_size")

func _assert_local_hives_owned(arena_node: Node, hive_ids: Array) -> void:
	var state_ref: Variant = arena_node.get("state")
	var local_owner_id: int = int(arena_node.call("_resolve_local_owner_id"))
	for hive_id_any in hive_ids:
		var hive_id: int = int(hive_id_any)
		var hive: HiveData = state_ref.call("find_hive_by_id", hive_id) as HiveData
		_expect(hive != null and int(hive.owner_id) == local_owner_id, "Local hive id is not owned by local player", {
			"hive_id": hive_id,
			"owner_id": int(hive.owner_id) if hive != null else -1,
			"local_owner_id": local_owner_id
		})

func _hive_snapshot(arena_node: Node) -> String:
	var state_ref: Variant = arena_node.get("state")
	if state_ref == null:
		return ""
	var hives: Array = state_ref.get("hives") as Array
	var parts: Array[String] = []
	for hive_any in hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null:
			continue
		parts.append("%d:%d:%d:%s" % [int(hive.id), int(hive.owner_id), int(hive.power), str(hive.grid_pos)])
	parts.sort()
	return "|".join(parts)

func _colors_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 0.01 \
		and absf(a.g - b.g) <= 0.01 \
		and absf(a.b - b.b) <= 0.01 \
		and absf(a.a - b.a) <= 0.01

func _expect(condition: bool, message: String, details: Dictionary) -> void:
	if condition:
		return
	_failed = true
	push_error("PREMATCH_ORIENTATION_FLOW_SMOKE: %s -> %s" % [message, details])

func _finish(tree: SceneTree) -> void:
	var shell: Node = tree.root.get_node_or_null("Shell")
	if shell != null:
		shell.queue_free()
		await tree.process_frame
	tree.quit(1 if _failed else 0)

func _arg_value(prefix: String) -> String:
	for arg in OS.get_cmdline_args():
		var value: String = str(arg)
		if value.begins_with(prefix):
			return value.substr(prefix.length()).strip_edges()
	return ""
