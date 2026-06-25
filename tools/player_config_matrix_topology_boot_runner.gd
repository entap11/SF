extends SceneTree

const Manifest := preload("res://tools/player_config_matrix_manifest.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")

const BOOT_TIMEOUT_MS: int = 18000

var _config_id := ""
var _seed := 0
var _failed := false
var _row: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_parse_args()
	_row = Manifest.row_by_id(_config_id)
	_expect(not _row.is_empty(), "manifest config not found", {"config_id": _config_id})
	_expect(str(_row.get("expected_contract", "")) == Manifest.EXPECT_VALID, "topology boot requires a valid manifest row", {
		"config_id": _config_id,
		"expected_contract": str(_row.get("expected_contract", ""))
	})
	if _failed:
		await _finish()
		return

	_validate_manifest_contract_shape()
	var expected_roster: Array = _roster_for_row(_row)
	var runtime_roster: Array = expected_roster.duplicate(true)
	_seed_profile_and_roster(runtime_roster)
	_set_tree_meta(expected_roster)
	if _failed:
		await _finish()
		return

	var shell_scene: PackedScene = load("res://scenes/Shell.tscn") as PackedScene
	_expect(shell_scene != null, "Shell.tscn failed to load", {})
	if _failed:
		await _finish()
		return

	var shell_instance: Node = shell_scene.instantiate()
	root.add_child(shell_instance)
	await process_frame

	var arena_node: Node = await _wait_for_node("/root/Shell/ArenaRoot/Main/WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena", BOOT_TIMEOUT_MS)
	_expect(arena_node != null, "Arena did not spawn", {})
	var card: Control = await _wait_for_node("/root/Shell/HUDCanvasLayer/HUDRoot/PreMatchOverlay/IdentityCard", BOOT_TIMEOUT_MS) as Control
	_expect(card != null and card.visible, "prematch identity card did not spawn", {})
	if _failed:
		await _finish()
		return

	await _enforce_manifest_roster(expected_roster, 900)
	_assert_card_seats(card, expected_roster)
	_assert_roster_contract(expected_roster)
	_assert_local_starting_hives(arena_node)

	var ops_state: Node = root.get_node_or_null("OpsState")
	var running_ok: bool = await _wait_for_match_running(ops_state, BOOT_TIMEOUT_MS)
	_expect(running_ok, "match did not reach RUNNING", {
		"phase": int(ops_state.get("match_phase")) if ops_state != null else -1
	})
	if not _failed:
		_assert_one_legal_lane_intent(arena_node, ops_state)

	if not _failed:
		print("PLAYER_CONFIG_MATRIX_TOPOLOGY_BOOT: PASS config=%s seed=%d" % [_config_id, _seed])
	await _finish()

func _parse_args() -> void:
	var args: Array = []
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	for arg_any in args:
		var arg: String = str(arg_any)
		if arg.begins_with("--matrix-config="):
			_config_id = arg.trim_prefix("--matrix-config=").strip_edges()
		elif arg.begins_with("--config="):
			_config_id = arg.trim_prefix("--config=").strip_edges()
		elif arg.begins_with("--matrix-seed="):
			_seed = int(arg.trim_prefix("--matrix-seed="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))

func _validate_manifest_contract_shape() -> void:
	var contract_mode: String = str(_row.get("contract_mode", ""))
	var map_path: String = str(_row.get("resolved_map_path", ""))
	var required_variant: String = Manifest.required_variant_for_contract_mode(contract_mode)
	var actual_variant: String = MAP_REGISTRY.player_variant_for_path(map_path)
	_expect(required_variant == actual_variant, "resolved map variant does not match contract mode", {
		"config_id": _config_id,
		"contract_mode": contract_mode,
		"required_variant": required_variant,
		"actual_variant": actual_variant,
		"map_path": map_path
	})
	_expect(Manifest.required_players_for_topology(str(_row.get("topology", ""))) > 0, "unknown topology", {
		"topology": str(_row.get("topology", ""))
	})

func _seed_profile_and_roster(roster: Array) -> void:
	if roster.is_empty():
		_expect(false, "empty roster", {"config_id": _config_id})
		return
	var local: Dictionary = roster[0] as Dictionary
	var profile_manager: Node = root.get_node_or_null("ProfileManager")
	if profile_manager != null:
		profile_manager.set("_user_id", str(local.get("uid", "")))
		profile_manager.set("_display_name", str(local.get("display_name", "")))
	var ops_state: Node = root.get_node_or_null("OpsState")
	if ops_state != null and ops_state.has_method("set_team_mode_override"):
		var override_mode: String = _team_mode_override_for_topology(str(_row.get("topology", "")))
		if not override_mode.is_empty():
			ops_state.call("set_team_mode_override", override_mode)
	if ops_state != null and ops_state.has_method("sim_mutate"):
		ops_state.call("sim_mutate", "player_config_matrix_topology_boot.seed_roster", func() -> void:
			ops_state.set("match_roster", roster)
		)

func _set_tree_meta(roster: Array) -> void:
	var local: Dictionary = roster[0] as Dictionary
	var remote: Dictionary = _first_remote_opponent(roster)
	var assigned_players: Array[String] = []
	for entry_any in roster:
		var entry: Dictionary = entry_any as Dictionary
		assigned_players.append(str(entry.get("display_name", "")))
	set_meta("start_game", true)
	set_meta("vs_mode", _display_mode_for_contract(str(_row.get("contract_mode", ""))))
	set_meta("vs_price_usd", 1 if str(_row.get("entry_type", "")) == Manifest.ENTRY_PAID_1 else 0)
	set_meta("vs_free_roll", str(_row.get("entry_type", "")) != Manifest.ENTRY_PAID_1)
	set_meta("vs_assigned_players", assigned_players)
	set_meta("vs_open_slots", 0)
	set_meta("vs_required_players", Manifest.required_players_for_topology(str(_row.get("topology", ""))))
	set_meta("vs_sync_start", true)
	set_meta("vs_stage_map_paths", [str(_row.get("resolved_map_path", ""))])
	set_meta("vs_stage_current_index", 0)
	set_meta("vs_stage_round_results", [])
	set_meta("vs_local_profile", {
		"uid": str(local.get("uid", "")),
		"display_name": str(local.get("display_name", ""))
	})
	set_meta("vs_remote_profile", {
		"uid": str(remote.get("uid", "")),
		"display_name": str(remote.get("display_name", "")),
		"is_cpu": false
	})

func _roster_for_row(row: Dictionary) -> Array:
	var topology: String = str(row.get("topology", ""))
	var teams: Array[int] = Manifest.expected_team_layout(topology)
	var names: Array[String] = ["Swarm Father", "Mrs. SwarmDaddy", "Third Swarm", "Fourth Swarm"]
	var roster: Array = []
	for i in range(teams.size()):
		roster.append({
			"seat": i + 1,
			"uid": "u_matrix_%s_seat_%d" % [topology, i + 1],
			"display_name": names[i],
			"is_local": i == 0,
			"is_cpu": false,
			"active": true,
			"team_id": int(teams[i])
		})
	return roster

func _display_mode_for_contract(contract_mode: String) -> String:
	match contract_mode:
		Manifest.CONTRACT_1V1:
			return "1V1"
		Manifest.CONTRACT_2V2:
			return "2V2"
		Manifest.CONTRACT_3P_FFA:
			return "3P FFA"
		Manifest.CONTRACT_4P_FFA:
			return "4P FFA"
		_:
			return contract_mode

func _team_mode_override_for_topology(topology: String) -> String:
	match topology:
		Manifest.TOPOLOGY_2V2:
			return "2v2"
		Manifest.TOPOLOGY_3P_FFA, Manifest.TOPOLOGY_4P_FFA:
			return "ffa"
		_:
			return ""

func _first_remote_opponent(roster: Array) -> Dictionary:
	for entry_any in roster:
		var entry: Dictionary = entry_any as Dictionary
		if bool(entry.get("is_local", false)):
			continue
		if int(entry.get("team_id", 0)) != 1:
			return entry
	for entry_any in roster:
		var fallback: Dictionary = entry_any as Dictionary
		if not bool(fallback.get("is_local", false)):
			return fallback
	return roster[0] as Dictionary

func _assert_card_seats(card: Control, roster: Array) -> void:
	for entry_any in roster:
		var entry: Dictionary = entry_any as Dictionary
		var seat: int = int(entry.get("seat", 0))
		_expect(_visible_label_text(card, "P%dLabel" % seat) == "PLAYER %d" % seat, "player label missing", {
			"seat": seat,
			"text": _visible_label_text(card, "P%dLabel" % seat)
		})
		_expect(not _visible_label_text(card, "P%dName" % seat).strip_edges().is_empty(), "player display name missing", {
			"seat": seat,
			"text": _visible_label_text(card, "P%dName" % seat)
		})

func _enforce_manifest_roster(expected_roster: Array, duration_ms: int) -> void:
	var deadline: int = Time.get_ticks_msec() + duration_ms
	while Time.get_ticks_msec() < deadline:
		_seed_profile_and_roster(expected_roster.duplicate(true))
		await process_frame
		if _roster_prefix_matches(expected_roster):
			await process_frame
			return
	_seed_profile_and_roster(expected_roster.duplicate(true))
	await process_frame

func _roster_prefix_matches(expected_roster: Array) -> bool:
	var ops_state: Node = root.get_node_or_null("OpsState")
	if ops_state == null:
		return false
	var actual_roster: Array = ops_state.get("match_roster") as Array
	for expected_any in expected_roster:
		var expected: Dictionary = expected_any as Dictionary
		var seat: int = int(expected.get("seat", 0))
		var actual: Dictionary = _roster_entry_for_seat(actual_roster, seat)
		if actual.is_empty():
			return false
		if str(actual.get("display_name", "")) != str(expected.get("display_name", "")):
			return false
		if int(actual.get("team_id", 0)) != int(expected.get("team_id", 0)):
			return false
	return true

func _assert_roster_contract(expected_roster: Array) -> void:
	var required_players: int = Manifest.required_players_for_topology(str(_row.get("topology", "")))
	_expect(int(get_meta("vs_required_players", 0)) == required_players, "required player meta mismatch", {
		"actual": int(get_meta("vs_required_players", 0)),
		"expected": required_players
	})
	var assigned_any: Variant = get_meta("vs_assigned_players", [])
	var assigned: Array = assigned_any as Array if typeof(assigned_any) == TYPE_ARRAY else []
	_expect(assigned.size() == required_players, "assigned player count mismatch", {
		"actual": assigned.size(),
		"expected": required_players,
		"assigned": assigned
	})
	var ops_state: Node = root.get_node_or_null("OpsState")
	_expect(ops_state != null, "OpsState missing", {})
	if ops_state == null:
		return
	var actual_roster: Array = ops_state.get("match_roster") as Array
	var expected_teams: Array[int] = Manifest.expected_team_layout(str(_row.get("topology", "")))
	var actual_teams: Array[int] = []
	for expected_any in expected_roster:
		var expected: Dictionary = expected_any as Dictionary
		var seat: int = int(expected.get("seat", 0))
		var entry: Dictionary = _roster_entry_for_seat(actual_roster, seat)
		_expect(not entry.is_empty(), "roster seat missing", {"seat": seat, "actual_roster": actual_roster})
		actual_teams.append(int(entry.get("team_id", 0)))
	_expect(actual_teams == expected_teams, "roster team layout mismatch", {
		"actual": actual_teams,
		"expected": expected_teams
	})

func _roster_entry_for_seat(roster: Array, seat: int) -> Dictionary:
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		if int(entry.get("seat", 0)) == seat:
			return entry
	return {}

func _assert_local_starting_hives(arena_node: Node) -> void:
	_expect(arena_node != null, "arena missing for local hive assertion", {})
	if arena_node == null:
		return
	var local_hive_ids: Array = arena_node.call("_resolve_local_starting_hive_ids") as Array
	_expect(not local_hive_ids.is_empty(), "local starting hives not identified", {})
	var state_ref: Variant = arena_node.get("state")
	var local_owner_id: int = int(arena_node.call("_resolve_local_owner_id"))
	for hive_id_any in local_hive_ids:
		var hive: HiveData = state_ref.call("find_hive_by_id", int(hive_id_any)) as HiveData
		_expect(hive != null and int(hive.owner_id) == local_owner_id, "local starting hive is not owned by local player", {
			"hive_id": int(hive_id_any),
			"owner_id": int(hive.owner_id) if hive != null else -1,
			"local_owner_id": local_owner_id
		})

func _assert_one_legal_lane_intent(arena_node: Node, ops_state: Node) -> void:
	_expect(arena_node != null and ops_state != null, "arena or OpsState missing for lane intent", {})
	if arena_node == null or ops_state == null:
		return
	var state_ref: GameState = ops_state.call("get_state") as GameState
	_expect(state_ref != null, "GameState missing for lane intent", {})
	if state_ref == null:
		return
	var local_owner_id: int = int(arena_node.call("_resolve_local_owner_id"))
	var candidate: Dictionary = _pick_local_attack_pair(state_ref, local_owner_id)
	_expect(not candidate.is_empty(), "no legal local non-self attack pair found", {
		"config_id": _config_id,
		"map": str(_row.get("resolved_map_path", "")),
		"local_owner_id": local_owner_id
	})
	if candidate.is_empty():
		return
	var result: Dictionary = ops_state.call("apply_lane_intent", int(candidate.get("src", -1)), int(candidate.get("dst", -1)), "attack") as Dictionary
	_expect(bool(result.get("ok", false)), "legal lane intent was rejected", {
		"pair": candidate,
		"result": result
	})
	_expect(state_ref.intent_is_on(int(candidate.get("src", -1)), int(candidate.get("dst", -1))), "lane intent did not become active", {
		"pair": candidate,
		"result": result
	})

func _pick_local_attack_pair(state_ref: GameState, local_owner_id: int) -> Dictionary:
	for src_any in state_ref.hives:
		if not (src_any is HiveData):
			continue
		var src_hive: HiveData = src_any as HiveData
		if int(src_hive.owner_id) != local_owner_id:
			continue
		for dst_any in state_ref.hives:
			if not (dst_any is HiveData):
				continue
			var dst_hive: HiveData = dst_any as HiveData
			if int(dst_hive.owner_id) == local_owner_id:
				continue
			var src_id: int = int(src_hive.id)
			var dst_id: int = int(dst_hive.id)
			if state_ref.can_connect(src_id, dst_id):
				return {"src": src_id, "dst": dst_id, "dst_owner": int(dst_hive.owner_id)}
	return {}

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

func _expect(condition: bool, message: String, details: Dictionary) -> void:
	if condition:
		return
	_failed = true
	push_error("PLAYER_CONFIG_MATRIX_TOPOLOGY_BOOT: %s -> %s" % [message, details])

func _finish() -> void:
	var shell: Node = root.get_node_or_null("Shell")
	if shell != null:
		shell.queue_free()
		await process_frame
	quit(1 if _failed else 0)
