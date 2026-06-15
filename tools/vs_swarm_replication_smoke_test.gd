extends SceneTree

const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const SETTINGS_CRASH_ON_CONTRACT_VIOLATION: String = "swarmfront/vs/crash_on_contract_violation"
const SETTINGS_HASH_RECOVERY_PAUSE_ENABLED: String = "swarmfront/vs/hash_recovery_pause_enabled"

func _init() -> void:
	await process_frame
	var failed: bool = false
	failed = _test_successful_swarm_intent_replicates() or failed
	failed = _test_invalid_remote_command_trips_contract_guard() or failed
	failed = _test_late_scheduled_command_delivers_and_updates_diagnostics() or failed
	failed = _test_same_authoritative_command_log_hashes_match() or failed
	failed = _test_contract_hash_ignores_clock_and_visual_drift() or failed
	failed = _test_state_hash_mismatch_threshold_and_self_heal() or failed
	failed = _test_desync_recovery_uses_snapshot_and_command_log() or failed
	if not failed:
		print("VS_SWARM_REPLICATION_SMOKE: PASS")
	quit(1 if failed else 0)

func _test_successful_swarm_intent_replicates() -> bool:
	var root_node: Window = get_root()
	var ops_state: Node = root_node.get_node_or_null("/root/OpsState")
	var handshake: Node = root_node.get_node_or_null("/root/VsHandshake")
	var runtime: Node = root_node.get_node_or_null("/root/VsPvpRuntime")
	if ops_state == null:
		return _fail("OpsState autoload missing")
	if handshake == null:
		return _fail("VsHandshake autoload missing")
	if runtime == null:
		return _fail("VsPvpRuntime autoload missing")
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
	if handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	if runtime.has_method("clear"):
		runtime.call("clear")

	var stamp: int = int(Time.get_unix_time_from_system())
	var host_uid: String = "swarm_host_%d" % stamp
	var guest_uid: String = "swarm_guest_%d" % stamp
	var invite: Dictionary = handshake.call(
		"create_invite",
		{"uid": host_uid, "display_name": "SwarmHost"},
		{"mode": "PVP", "free_roll": true}
	) as Dictionary
	if not bool(invite.get("ok", false)):
		return _fail("create_invite failed: %s" % str(invite))
	var session_id: String = str(invite.get("session_id", ""))
	var invite_code: String = str(invite.get("invite_code", ""))
	var join_result: Dictionary = handshake.call(
		"join_invite",
		invite_code,
		{"uid": guest_uid, "display_name": "SwarmGuest"}
	) as Dictionary
	if not bool(join_result.get("ok", false)):
		return _fail("join_invite failed: %s" % str(join_result))

	set_meta("vs_handshake_session_id", session_id)
	set_meta("vs_handshake_role", "host")
	set_meta("vs_mode", "PVP")
	set_meta("vs_local_profile", {"uid": host_uid, "display_name": "SwarmHost"})
	var roster: Array = [
		{"uid": host_uid, "seat": 1, "active": true},
		{"uid": guest_uid, "seat": 2, "active": true}
	]
	runtime.call("configure_from_tree", self, roster)

	var map_dict: Dictionary = {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 10, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2}
		]
	}
	ops_state.call("reset_state_from_map", map_dict)
	ops_state.set("match_phase", 1)
	var state_hash: String = str(ops_state.call("get_contract_state_hash"))
	if state_hash.is_empty():
		return _fail("contract state hash should not be empty")
	var open_result: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "attack") as Dictionary
	if not bool(open_result.get("ok", false)):
		return _fail("attack route setup failed: %s" % str(open_result))
	var scheduled_hash: String = str(ops_state.call("get_contract_state_hash"))
	if scheduled_hash != state_hash:
		return _fail("local PvP request mutated state before authority apply: before=%s after=%s result=%s" % [state_hash, scheduled_hash, str(open_result)])
	var early_attack: Array = runtime.call("consume_remote_commands", 1) as Array
	if not early_attack.is_empty():
		return _fail("scheduled attack command should not mature early: %s" % str(early_attack))
	var early_diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if int(early_diag.get("contract_command_lead_ticks", -1)) != 5:
		return _fail("early scheduled command lead should be 5 ticks: %s" % str(early_diag))
	var scheduled_attack: Array = runtime.call("consume_remote_commands", 6) as Array
	if scheduled_attack.is_empty():
		return _fail("scheduled attack command missing")
	var attack_command: Dictionary = scheduled_attack[0] as Dictionary
	if int(attack_command.get("command_seq", 0)) != 1:
		return _fail("scheduled attack missing canonical command_seq: %s" % str(attack_command))
	if str(attack_command.get("command_id", "")).strip_edges().is_empty():
		return _fail("scheduled attack missing canonical command_id: %s" % str(attack_command))
	if int(attack_command.get("execute_tick", -1)) != 6:
		return _fail("scheduled attack should use canonical execute tick 6: %s" % str(attack_command))
	var due_diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if int(due_diag.get("contract_command_lead_ticks", -1)) != 0:
		return _fail("due scheduled command lead should be 0 ticks: %s" % str(due_diag))
	if int(due_diag.get("contract_min_command_lead_ticks", -1)) != 0:
		return _fail("minimum scheduled command lead should be 0 ticks: %s" % str(due_diag))
	ops_state.call("with_remote_replication_apply", func() -> void:
		ops_state.call("apply_lane_intent", 1, 2, "attack")
	)
	var swarm_result: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "swarm") as Dictionary
	if not bool(swarm_result.get("ok", false)):
		return _fail("swarm intent failed: %s" % str(swarm_result))

	var poll: Dictionary = handshake.call("poll_intents", session_id, guest_uid, 0) as Dictionary
	if not bool(poll.get("ok", false)):
		return _fail("guest poll_intents failed: %s" % str(poll))
	var swarm_command: Dictionary = _find_lane_intent_command(poll, host_uid, "swarm", 1, 2)
	if swarm_command.is_empty():
		return _fail("guest poll did not include replicated swarm intent: %s" % str(poll))
	if int(swarm_command.get("contract_version", 0)) != 1:
		return _fail("replicated swarm command missing contract version: %s" % str(swarm_command))
	if int(swarm_command.get("issued_tick", -1)) < 0 or int(swarm_command.get("issued_sim_us", -1)) < 0:
		return _fail("replicated swarm command missing sim metadata: %s" % str(swarm_command))
	if int(swarm_command.get("execute_tick", -1)) < 0:
		return _fail("replicated swarm command missing execute tick: %s" % str(swarm_command))
	if int(swarm_command.get("command_seq", 0)) <= 1:
		return _fail("replicated swarm command missing canonical sequence after lane open: %s" % str(swarm_command))
	if runtime.has_method("clear"):
		runtime.call("clear")
	return false

func _test_invalid_remote_command_trips_contract_guard() -> bool:
	ProjectSettings.set_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, false)
	var root_node: Window = get_root()
	var runtime: Node = root_node.get_node_or_null("/root/VsPvpRuntime")
	if runtime == null:
		return _fail("VsPvpRuntime autoload missing")
	if runtime.has_method("clear"):
		runtime.call("clear")
	set_meta("vs_handshake_session_id", "contract_guard_smoke")
	set_meta("vs_handshake_role", "host")
	set_meta("vs_mode", "PVP")
	set_meta("vs_local_profile", {"uid": "contract_host", "display_name": "ContractHost"})
	runtime.call("configure_from_tree", self, [
		{"uid": "contract_host", "seat": 1, "active": true},
		{"uid": "contract_guest", "seat": 2, "active": true}
	])
	var before_count: int = int(runtime.call("get_contract_violation_count"))
	runtime.call("_handle_remote_intent_poll_result", {
		"ok": true,
		"latest_seq": 1,
		"events": [
			{
				"seq": 1,
				"uid": "contract_guest",
				"command": {
					"kind": "lane_intent",
					"src": 2,
					"dst": 1,
					"intent": "attack",
					"src_owner": 2
				}
			}
		]
	}, Time.get_ticks_usec(), 0)
	var after_count: int = int(runtime.call("get_contract_violation_count"))
	if after_count <= before_count:
		return _fail("invalid remote command did not trip contract guard")
	var diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if str(diag.get("contract_last_violation_reason", "")) != "bad_contract_version":
		return _fail("invalid remote command should record bad_contract_version: %s" % str(diag))
	if str(diag.get("contract_report_path", "")).strip_edges().is_empty():
		return _fail("contract diagnostics should include report path: %s" % str(diag))
	var pending: Array = runtime.call("consume_remote_commands") as Array
	if not pending.is_empty():
		return _fail("invalid remote command should not be queued: %s" % str(pending))
	if runtime.has_method("clear"):
		runtime.call("clear")
	ProjectSettings.set_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, false)
	return false

func _test_late_scheduled_command_delivers_and_updates_diagnostics() -> bool:
	ProjectSettings.set_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, false)
	var root_node: Window = get_root()
	var runtime: Node = root_node.get_node_or_null("/root/VsPvpRuntime")
	if runtime == null:
		return _fail("VsPvpRuntime autoload missing")
	if runtime.has_method("clear"):
		runtime.call("clear")
	set_meta("vs_handshake_session_id", "missed_command_guard_smoke")
	set_meta("vs_handshake_role", "host")
	set_meta("vs_mode", "PVP")
	set_meta("vs_local_profile", {"uid": "missed_host", "display_name": "MissedHost"})
	runtime.call("configure_from_tree", self, [
		{"uid": "missed_host", "seat": 1, "active": true},
		{"uid": "missed_guest", "seat": 2, "active": true}
	])
	runtime.call("_handle_remote_intent_poll_result", {
		"ok": true,
		"latest_seq": 1,
		"events": [
			{
				"seq": 1,
				"uid": "missed_guest",
				"command": {
					"kind": "lane_intent",
					"contract_version": 1,
					"issued_ms": Time.get_ticks_msec(),
					"issued_tick": 0,
					"execute_tick": 2,
					"canonical_execute_tick": 2,
					"issued_sim_us": 0,
					"sender_seat": 2,
					"sender_uid": "missed_guest",
					"src": 2,
					"dst": 1,
					"intent": "attack",
					"src_owner": 2,
					"dst_owner": 1
				}
			}
		]
	}, Time.get_ticks_usec(), 0)
	var before_count: int = int(runtime.call("get_contract_violation_count"))
	var matured: Array = runtime.call("consume_remote_commands", 3) as Array
	if matured.is_empty():
		return _fail("late scheduled command should be delivered on the next available tick")
	var after_count: int = int(runtime.call("get_contract_violation_count"))
	if after_count != before_count:
		return _fail("late scheduled command should not trip contract guard")
	var diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if int(diag.get("contract_missed_scheduled_commands", 0)) <= 0:
		return _fail("late scheduled command should increment compatibility diagnostics: %s" % str(diag))
	if int(diag.get("contract_late_scheduled_commands", 0)) <= 0:
		return _fail("late scheduled command should increment late diagnostics: %s" % str(diag))
	if int(diag.get("contract_command_lead_ticks", 0)) != -1:
		return _fail("late scheduled command should record negative lead: %s" % str(diag))
	runtime.call("_handle_remote_intent_poll_result", {
		"ok": true,
		"latest_seq": 2,
		"events": [
			{
				"seq": 2,
				"uid": "missed_guest",
				"command": {
					"kind": "lane_intent",
					"contract_version": 1,
					"issued_ms": Time.get_ticks_msec(),
					"issued_tick": 1,
					"execute_tick": 4,
					"canonical_execute_tick": 4,
					"issued_sim_us": 100000,
					"sender_seat": 2,
					"sender_uid": "missed_guest",
					"src": 2,
					"dst": 1,
					"intent": "attack",
					"src_owner": 2,
					"dst_owner": 1
				}
			}
		]
	}, Time.get_ticks_usec(), 1)
	before_count = int(runtime.call("get_contract_violation_count"))
	var several_late: Array = runtime.call("consume_remote_commands", 10) as Array
	if several_late.is_empty():
		return _fail("several-ticks-late command should still deliver within tolerance")
	after_count = int(runtime.call("get_contract_violation_count"))
	if after_count != before_count:
		return _fail("several-ticks-late command should not trip contract guard")
	diag = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if int(diag.get("contract_late_scheduled_commands", 0)) < 2:
		return _fail("several-ticks-late command should increment late diagnostics: %s" % str(diag))
	if runtime.has_method("clear"):
		runtime.call("clear")
	ProjectSettings.set_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, false)
	if _test_outside_tolerance_delivers_without_recovery():
		return true
	return false

func _test_outside_tolerance_delivers_without_recovery() -> bool:
	var root_node: Window = get_root()
	var runtime: Node = root_node.get_node_or_null("/root/VsPvpRuntime")
	if runtime == null:
		return _fail("VsPvpRuntime autoload missing")
	if runtime.has_method("clear"):
		runtime.call("clear")
	set_meta("vs_handshake_session_id", "outside_tolerance_guard_smoke")
	set_meta("vs_handshake_role", "host")
	set_meta("vs_mode", "PVP")
	set_meta("vs_local_profile", {"uid": "lag_host", "display_name": "LagHost"})
	runtime.call("configure_from_tree", self, [
		{"uid": "lag_host", "seat": 1, "active": true},
		{"uid": "lag_guest", "seat": 2, "active": true}
	])
	runtime.call("_handle_remote_intent_poll_result", {
		"ok": true,
		"latest_seq": 1,
		"events": [
			{
				"seq": 1,
				"uid": "lag_guest",
				"command": {
					"kind": "lane_intent",
					"contract_version": 1,
					"issued_ms": Time.get_ticks_msec(),
					"issued_tick": 0,
					"execute_tick": 2,
					"canonical_execute_tick": 2,
					"issued_sim_us": 0,
					"sender_seat": 2,
					"sender_uid": "lag_guest",
					"src": 2,
					"dst": 1,
					"intent": "attack",
					"src_owner": 2,
					"dst_owner": 1
				}
			}
		]
	}, Time.get_ticks_usec(), 0)
	var matured: Array = runtime.call("consume_remote_commands", 20) as Array
	if matured.is_empty():
		return _fail("outside tolerance command should deliver late instead of blocking input")
	var diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if bool(diag.get("peer_desync_or_lagging", false)):
		return _fail("outside tolerance command should not set peer_desync_or_lagging: %s" % str(diag))
	if int(diag.get("contract_buffered_lagging_commands", 0)) != 0:
		return _fail("outside tolerance command should not increment buffered diagnostics: %s" % str(diag))
	if int(diag.get("contract_late_scheduled_commands", 0)) <= 0:
		return _fail("outside tolerance command should increment late diagnostics: %s" % str(diag))
	if int(runtime.call("get_contract_violation_count")) != 0:
		return _fail("outside tolerance should not be an app-crash contract violation")
	if str(diag.get("recovery_state", "")) != "running":
		return _fail("outside tolerance should keep recovery state running: %s" % str(diag))
	if not bool(runtime.call("can_accept_gameplay_intents")):
		return _fail("outside tolerance should keep gameplay intents enabled: %s" % str(diag))
	runtime.set("_local_hash_by_tick", {35: "late_local_hash", 40: "late_healed_hash"})
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("lag_guest", 2, 35, "late_remote_hash"), Time.get_ticks_usec(), 1)
	diag = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if str(diag.get("recovery_state", "")) != "running":
		return _fail("late command followed by temporary hash mismatch should not enter recovery: %s" % str(diag))
	if not bool(runtime.call("can_accept_gameplay_intents")):
		return _fail("late command followed by temporary hash mismatch should keep gameplay intents enabled")
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("lag_guest", 3, 40, "late_healed_hash"), Time.get_ticks_usec(), 2)
	diag = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if int(diag.get("hash_mismatch_consecutive_count", -1)) != 0:
		return _fail("temporary hash mismatch after late command should self-heal: %s" % str(diag))
	if runtime.has_method("clear"):
		runtime.call("clear")
	return false

func _test_same_authoritative_command_log_hashes_match() -> bool:
	var root_node: Window = get_root()
	var ops_state: Node = root_node.get_node_or_null("/root/OpsState")
	var runtime: Node = root_node.get_node_or_null("/root/VsPvpRuntime")
	if ops_state == null:
		return _fail("OpsState autoload missing")
	if runtime != null and runtime.has_method("clear"):
		runtime.call("clear")
	var map_dict: Dictionary = _deterministic_authority_map()
	var command_log: Array = [
		{"command_seq": 1, "kind": "lane_intent", "src": 1, "dst": 3, "intent": "feed"},
		{"command_seq": 2, "kind": "lane_intent", "src": 1, "dst": 2, "intent": "attack"},
		{"command_seq": 3, "kind": "lane_intent", "src": 1, "dst": 2, "intent": "swarm"},
		{"command_seq": 4, "kind": "lane_retract", "from_id": 1, "to_id": 2, "owner_id": 1},
		{"command_seq": 5, "kind": "lane_intent", "src": 2, "dst": 1, "intent": "attack"}
	]
	var first: Dictionary = _apply_authoritative_command_log(ops_state, map_dict, command_log)
	if not bool(first.get("ok", false)):
		return _fail(str(first.get("reason", "first command log failed")))
	var second: Dictionary = _apply_authoritative_command_log(ops_state, map_dict, command_log)
	if not bool(second.get("ok", false)):
		return _fail(str(second.get("reason", "second command log failed")))
	if str(first.get("hash", "")) != str(second.get("hash", "")):
		return _fail("same accepted command log produced different hashes: first=%s second=%s" % [str(first), str(second)])
	if int(first.get("swarm_requests", 0)) != 1 or int(second.get("swarm_requests", 0)) != 1:
		return _fail("swarm command should enqueue exactly one deterministic request: first=%s second=%s" % [str(first), str(second)])
	if runtime != null and runtime.has_method("clear"):
		runtime.call("clear")
	return false

func _deterministic_authority_map() -> Dictionary:
	return {
		"map_id": "pvp_authority_regression",
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 5, "y": 0, "owner_id": 2, "power": 50, "kind": "Hive"},
			{"id": 3, "x": 0, "y": 5, "owner_id": 1, "power": 20, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2},
			{"a_id": 1, "b_id": 3}
		]
	}

func _apply_authoritative_command_log(ops_state: Node, map_dict: Dictionary, command_log: Array) -> Dictionary:
	ops_state.call("reset_state_from_map", map_dict)
	ops_state.set("match_phase", 1)
	var failure_reason: String = ""
	var sorted_log: Array = command_log.duplicate(true)
	sorted_log.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("command_seq", 0)) < int(b.get("command_seq", 0))
	)
	ops_state.call("with_remote_replication_apply", func() -> void:
		for command_any in sorted_log:
			if typeof(command_any) != TYPE_DICTIONARY:
				failure_reason = "command log entry is not a dictionary"
				return
			var command: Dictionary = command_any as Dictionary
			var kind: String = str(command.get("kind", "")).strip_edges().to_lower()
			match kind:
				"lane_intent":
					var result: Dictionary = ops_state.call(
						"apply_lane_intent",
						int(command.get("src", -1)),
						int(command.get("dst", -1)),
						str(command.get("intent", ""))
					) as Dictionary
					if not bool(result.get("ok", false)):
						failure_reason = "command_seq %d failed: %s" % [int(command.get("command_seq", 0)), str(result)]
						return
				"lane_retract":
					ops_state.call(
						"retract_lane",
						int(command.get("from_id", -1)),
						int(command.get("to_id", -1)),
						int(command.get("owner_id", 0))
					)
				_:
					failure_reason = "unsupported command kind: %s" % kind
					return
	)
	if not failure_reason.is_empty():
		return {"ok": false, "reason": failure_reason}
	var state: GameState = ops_state.call("get_state") as GameState
	if state == null:
		return {"ok": false, "reason": "state missing after command log"}
	if int(state.swarm_requests.size()) != 1:
		return {"ok": false, "reason": "swarm command should enqueue exactly one request, got %d" % int(state.swarm_requests.size())}
	return {
		"ok": true,
		"hash": str(ops_state.call("get_contract_state_hash")),
		"swarm_requests": int(state.swarm_requests.size()),
		"hive_1_power": int((state.find_hive_by_id(1) as HiveData).power)
	}

func _test_contract_hash_ignores_clock_and_visual_drift() -> bool:
	var root_node: Window = get_root()
	var ops_state: Node = root_node.get_node_or_null("/root/OpsState")
	var runtime: Node = root_node.get_node_or_null("/root/VsPvpRuntime")
	if ops_state == null:
		return _fail("OpsState autoload missing")
	if runtime != null and runtime.has_method("clear"):
		runtime.call("clear")
	ops_state.call("reset_state_from_map", _deterministic_authority_map())
	ops_state.set("match_phase", 1)
	var open_result: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "attack") as Dictionary
	if not bool(open_result.get("ok", false)):
		return _fail("clock drift hash smoke failed to open lane: %s" % str(open_result))
	var baseline_hash: String = str(ops_state.call("get_contract_state_hash"))
	ops_state.set("match_elapsed_ms", int(ops_state.get("match_elapsed_ms")) + 1700)
	ops_state.set("match_time_remaining_ms", maxi(0, int(ops_state.get("match_time_remaining_ms")) - 1700))
	ops_state.set("match_remaining_ms", maxi(0, int(ops_state.get("match_remaining_ms")) - 1700))
	ops_state.set("match_deadline_ms", int(ops_state.get("match_deadline_ms")) + 333)
	var front_by_lane: Dictionary = ops_state.get("lane_front_by_lane_id") as Dictionary
	for key_any in front_by_lane.keys():
		front_by_lane[key_any] = 0.91
	var state: GameState = ops_state.call("get_state") as GameState
	if state != null:
		for lane_any in state.lanes:
			if lane_any is LaneData:
				var lane: LaneData = lane_any as LaneData
				lane.build_t = 0.17
				lane.establish_a = true
				lane.establish_b = false
				lane.establish_t0_ms = Time.get_ticks_msec() + 12345
	var drift_hash: String = str(ops_state.call("get_contract_state_hash"))
	if drift_hash != baseline_hash:
		return _fail("contract hash should ignore clock and visual lane drift: before=%s after=%s" % [baseline_hash, drift_hash])
	return false

func _test_state_hash_mismatch_threshold_and_self_heal() -> bool:
	ProjectSettings.set_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, false)
	ProjectSettings.set_setting(SETTINGS_HASH_RECOVERY_PAUSE_ENABLED, false)
	var root_node: Window = get_root()
	var runtime: Node = root_node.get_node_or_null("/root/VsPvpRuntime")
	if runtime == null:
		return _fail("VsPvpRuntime autoload missing")
	if runtime.has_method("clear"):
		runtime.call("clear")
	set_meta("vs_handshake_session_id", "hash_guard_smoke")
	set_meta("vs_handshake_role", "host")
	set_meta("vs_mode", "PVP")
	set_meta("vs_local_profile", {"uid": "hash_host", "display_name": "HashHost"})
	runtime.call("configure_from_tree", self, [
		{"uid": "hash_host", "seat": 1, "active": true},
		{"uid": "hash_guest", "seat": 2, "active": true}
	])
	runtime.set("_local_hash_by_tick", {35: "local_hash_35", 40: "local_hash_40", 45: "local_hash_45"})
	var before_count: int = int(runtime.call("get_contract_violation_count"))
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("hash_guest", 1, 35, "remote_hash_35"), Time.get_ticks_usec(), 0)
	var diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if str(diag.get("recovery_state", "")) != "running":
		return _fail("single state hash mismatch should not enter recovery: %s" % str(diag))
	if int(diag.get("hash_mismatch_consecutive_count", 0)) != 1:
		return _fail("single state hash mismatch should increment consecutive count: %s" % str(diag))
	if int(runtime.call("get_contract_violation_count")) != before_count:
		return _fail("single state hash mismatch should not trip contract guard")
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("hash_guest", 2, 40, "remote_hash_40"), Time.get_ticks_usec(), 1)
	diag = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if str(diag.get("recovery_state", "")) != "running":
		return _fail("two state hash mismatches should not enter recovery: %s" % str(diag))
	if int(diag.get("hash_mismatch_consecutive_count", 0)) != 2:
		return _fail("two state hash mismatches should keep consecutive count at two: %s" % str(diag))
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("hash_guest", 3, 45, "remote_hash_45"), Time.get_ticks_usec(), 2)
	var after_count: int = int(runtime.call("get_contract_violation_count"))
	if after_count <= before_count:
		return _fail("third persistent state hash mismatch should trip contract guard")
	diag = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if int(diag.get("contract_state_hash_mismatches", 0)) < 3:
		return _fail("state hash mismatch samples should increment diagnostics: %s" % str(diag))
	if str(diag.get("contract_last_violation_reason", "")) != "state_hash_mismatch":
		return _fail("persistent state hash mismatch should record latest violation reason: %s" % str(diag))
	if str(diag.get("recovery_state", "")) != "running":
		return _fail("hash recovery pause disabled should keep runtime running: %s" % str(diag))
	if not bool(runtime.call("can_accept_gameplay_intents")):
		return _fail("hash recovery pause disabled should keep gameplay intents enabled")
	if runtime.has_method("clear"):
		runtime.call("clear")
	set_meta("vs_handshake_session_id", "hash_self_heal_smoke")
	set_meta("vs_handshake_role", "host")
	set_meta("vs_mode", "PVP")
	set_meta("vs_local_profile", {"uid": "hash_host", "display_name": "HashHost"})
	runtime.call("configure_from_tree", self, [
		{"uid": "hash_host", "seat": 1, "active": true},
		{"uid": "hash_guest", "seat": 2, "active": true}
	])
	runtime.set("_local_hash_by_tick", {35: "local_hash_35", 40: "same_hash_40"})
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("hash_guest", 1, 35, "remote_hash_35"), Time.get_ticks_usec(), 0)
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("hash_guest", 2, 40, "same_hash_40"), Time.get_ticks_usec(), 1)
	diag = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if int(diag.get("hash_mismatch_consecutive_count", -1)) != 0:
		return _fail("matching hash should reset mismatch counter after self-heal: %s" % str(diag))
	var events: Array = runtime.call("get_debug_event_log") as Array
	var saw_self_heal: bool = false
	for event_any in events:
		if typeof(event_any) == TYPE_DICTIONARY and str((event_any as Dictionary).get("type", "")) == "hash_mismatch_self_healed":
			saw_self_heal = true
			break
	if not saw_self_heal:
		return _fail("hash mismatch self-heal event missing: %s" % str(events))
	if runtime.has_method("clear"):
		runtime.call("clear")
	set_meta("vs_handshake_session_id", "hash_startup_grace_smoke")
	runtime.call("configure_from_tree", self, [
		{"uid": "hash_host", "seat": 1, "active": true},
		{"uid": "hash_guest", "seat": 2, "active": true}
	])
	runtime.set("_local_hash_by_tick", {5: "local_hash_5", 10: "local_hash_10", 15: "local_hash_15"})
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("hash_guest", 1, 5, "remote_hash_5"), Time.get_ticks_usec(), 0)
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("hash_guest", 2, 10, "remote_hash_10"), Time.get_ticks_usec(), 1)
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("hash_guest", 3, 15, "remote_hash_15"), Time.get_ticks_usec(), 2)
	diag = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if str(diag.get("recovery_state", "")) != "running":
		return _fail("startup grace should suppress early persistent mismatch recovery: %s" % str(diag))
	if not bool(runtime.call("can_accept_gameplay_intents")):
		return _fail("startup grace mismatch should not block gameplay intents")
	if runtime.has_method("clear"):
		runtime.call("clear")
	ProjectSettings.set_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, false)
	ProjectSettings.set_setting(SETTINGS_HASH_RECOVERY_PAUSE_ENABLED, false)
	return false

func _test_desync_recovery_uses_snapshot_and_command_log() -> bool:
	ProjectSettings.set_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, false)
	ProjectSettings.set_setting(SETTINGS_HASH_RECOVERY_PAUSE_ENABLED, true)
	var root_node: Window = get_root()
	var ops_state: Node = root_node.get_node_or_null("/root/OpsState")
	var runtime: Node = root_node.get_node_or_null("/root/VsPvpRuntime")
	if ops_state == null:
		return _fail("OpsState autoload missing")
	if runtime == null:
		return _fail("VsPvpRuntime autoload missing")
	if runtime.has_method("clear"):
		runtime.call("clear")
	set_meta("vs_handshake_session_id", "desync_recovery_smoke")
	set_meta("vs_handshake_role", "host")
	set_meta("vs_mode", "PVP")
	set_meta("vs_local_profile", {"uid": "recovery_host", "display_name": "RecoveryHost"})
	runtime.call("configure_from_tree", self, [
		{"uid": "recovery_host", "seat": 1, "active": true},
		{"uid": "recovery_guest", "seat": 2, "active": true}
	])
	ops_state.call("reset_state_from_map", _deterministic_authority_map())
	ops_state.set("match_phase", 1)
	var checkpoint_hash: String = str(ops_state.call("get_contract_state_hash"))
	var checkpoint_snapshot: Dictionary = ops_state.call("get_authority_snapshot") as Dictionary
	runtime.call("_record_authority_snapshot", 0, checkpoint_hash, checkpoint_snapshot)
	runtime.set("_local_hash_by_tick", {0: checkpoint_hash})
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("recovery_guest", 1, 0, checkpoint_hash), Time.get_ticks_usec(), 0)
	var checkpoint_diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if int(checkpoint_diag.get("last_matching_checkpoint_tick", -1)) != 0:
		return _fail("matching checkpoint should be recorded before recovery: %s" % str(checkpoint_diag))

	var command_log: Array = [
		_recovery_lane_command(1, 1, "recovery_host", 1, 1, 3, "feed", 1, 1),
		_recovery_lane_command(2, 2, "recovery_host", 1, 1, 2, "attack", 1, 2),
		_recovery_lane_command(3, 3, "recovery_host", 1, 1, 2, "swarm", 1, 2),
		_recovery_retract_command(4, 4, "recovery_host", 1, 1, 2, 1),
		_recovery_lane_command(5, 5, "recovery_guest", 2, 2, 1, "attack", 2, 1)
	]
	for command_any in command_log:
		runtime.call("_queue_scheduled_command", command_any as Dictionary)
	var expected_apply: Dictionary = _apply_command_rows_to_current_state(ops_state, command_log)
	if not bool(expected_apply.get("ok", false)):
		return _fail("expected authoritative replay failed before desync: %s" % str(expected_apply))
	var expected_hash: String = str(ops_state.call("get_contract_state_hash"))
	var expected_state: GameState = ops_state.call("get_state") as GameState
	if expected_state == null or int(expected_state.swarm_requests.size()) != 1:
		return _fail("swarm command should be part of command-log replay before recovery")

	var local_hashes_any: Variant = runtime.get("_local_hash_by_tick")
	var local_hashes: Dictionary = local_hashes_any as Dictionary if typeof(local_hashes_any) == TYPE_DICTIONARY else {}
	local_hashes[35] = "artificial_local_desync_35"
	local_hashes[40] = "artificial_local_desync_40"
	local_hashes[45] = "artificial_local_desync_45"
	runtime.set("_local_hash_by_tick", local_hashes)
	runtime.call("_record_authority_snapshot", 45, "artificial_local_desync_45", ops_state.call("get_authority_snapshot") as Dictionary)
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("recovery_guest", 2, 35, expected_hash), Time.get_ticks_usec(), 1)
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("recovery_guest", 3, 40, expected_hash), Time.get_ticks_usec(), 2)
	runtime.call("_handle_remote_intent_poll_result", _state_hash_poll("recovery_guest", 4, 45, expected_hash), Time.get_ticks_usec(), 3)
	var desync_diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if str(desync_diag.get("recovery_state", "")) != "desync_recovery":
		return _fail("desync mismatch should freeze into recovery: %s" % str(desync_diag))
	if bool(runtime.call("can_accept_gameplay_intents")):
		return _fail("gameplay intents should be blocked during desync recovery")

	var plan: Dictionary = runtime.call("build_desync_recovery_plan") as Dictionary
	if not bool(plan.get("ok", false)):
		return _fail("recovery plan should be available: %s" % str(plan))
	if int(plan.get("rollback_tick", -1)) != 0:
		return _fail("recovery should roll back to last matching checkpoint: %s" % str(plan))
	var commands_any: Variant = plan.get("commands", [])
	var commands: Array = commands_any as Array if typeof(commands_any) == TYPE_ARRAY else []
	if commands.size() != command_log.size():
		return _fail("recovery plan should replay every accepted command since checkpoint: %s" % str(plan))
	var restored: bool = bool(ops_state.call("restore_authority_snapshot", plan.get("snapshot", {}) as Dictionary))
	if not restored:
		return _fail("authority snapshot restore failed")
	var replay_apply: Dictionary = _apply_command_rows_to_current_state(ops_state, commands)
	if not bool(replay_apply.get("ok", false)):
		return _fail("recovery replay failed: %s" % str(replay_apply))
	var recovered_hash: String = str(ops_state.call("get_contract_state_hash"))
	var recovery_result: Dictionary = runtime.call("complete_desync_recovery", 45, recovered_hash, commands.size()) as Dictionary
	if not bool(recovery_result.get("recovered", false)):
		return _fail("recovery should complete when command-log replay reaches remote hash: result=%s expected=%s recovered=%s" % [str(recovery_result), expected_hash, recovered_hash])
	var recovered_diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if str(recovered_diag.get("recovery_state", "")) != "running":
		return _fail("runtime should return to running after recovery: %s" % str(recovered_diag))
	if str(ops_state.call("get_contract_state_hash")) != expected_hash:
		return _fail("recovered authoritative hash should match canonical replay")

	runtime.set("_recovery_remote_hash", "unreachable_hash")
	var failed_once: Dictionary = runtime.call("complete_desync_recovery", 45, recovered_hash, commands.size()) as Dictionary
	var failed_twice: Dictionary = runtime.call("complete_desync_recovery", 45, recovered_hash, commands.size()) as Dictionary
	if not bool(failed_once.get("ok", true)) and not bool(failed_twice.get("ended", false)):
		return _fail("failed recovery should end cleanly after retry budget: once=%s twice=%s" % [str(failed_once), str(failed_twice)])
	if runtime.has_method("clear"):
		runtime.call("clear")
	ProjectSettings.set_setting(SETTINGS_HASH_RECOVERY_PAUSE_ENABLED, false)
	return false

func _state_hash_poll(uid: String, seq: int, hash_tick: int, state_hash: String) -> Dictionary:
	return {
		"ok": true,
		"latest_seq": int(seq),
		"events": [
			{
				"seq": int(seq),
				"uid": uid,
				"command": {
					"kind": "state_hash",
					"contract_version": 1,
					"issued_ms": Time.get_ticks_msec(),
					"issued_tick": int(hash_tick),
					"execute_tick": int(hash_tick) + 3,
					"issued_sim_us": int(hash_tick) * 100000,
					"sender_seat": 2,
					"sender_uid": uid,
					"hash_tick": int(hash_tick),
					"state_hash": state_hash
				}
			}
		]
	}

func _recovery_lane_command(seq: int, execute_tick: int, sender_uid: String, sender_seat: int, src: int, dst: int, intent: String, src_owner: int, dst_owner: int) -> Dictionary:
	return {
		"kind": "lane_intent",
		"contract_version": 1,
		"command_seq": int(seq),
		"command_id": "desync_recovery_smoke:%d" % int(seq),
		"issued_ms": Time.get_ticks_msec(),
		"issued_tick": 0,
		"local_issued_tick": 0,
		"requested_execute_tick": int(execute_tick),
		"execute_tick": int(execute_tick),
		"canonical_execute_tick": int(execute_tick),
		"issued_sim_us": 0,
		"sender_seat": int(sender_seat),
		"sender_uid": sender_uid,
		"src": int(src),
		"dst": int(dst),
		"intent": intent,
		"src_owner": int(src_owner),
		"dst_owner": int(dst_owner)
	}

func _recovery_retract_command(seq: int, execute_tick: int, sender_uid: String, sender_seat: int, from_id: int, to_id: int, owner_id: int) -> Dictionary:
	return {
		"kind": "lane_retract",
		"contract_version": 1,
		"command_seq": int(seq),
		"command_id": "desync_recovery_smoke:%d" % int(seq),
		"issued_ms": Time.get_ticks_msec(),
		"issued_tick": 0,
		"local_issued_tick": 0,
		"requested_execute_tick": int(execute_tick),
		"execute_tick": int(execute_tick),
		"canonical_execute_tick": int(execute_tick),
		"issued_sim_us": 0,
		"sender_seat": int(sender_seat),
		"sender_uid": sender_uid,
		"from_id": int(from_id),
		"to_id": int(to_id),
		"owner_id": int(owner_id)
	}

func _apply_command_rows_to_current_state(ops_state: Node, command_log: Array) -> Dictionary:
	var failure_reason: String = ""
	var sorted_log: Array = command_log.duplicate(true)
	sorted_log.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("command_seq", 0)) < int(b.get("command_seq", 0))
	)
	ops_state.call("with_remote_replication_apply", func() -> void:
		for command_any in sorted_log:
			if typeof(command_any) != TYPE_DICTIONARY:
				failure_reason = "command log entry is not a dictionary"
				return
			var command: Dictionary = command_any as Dictionary
			var kind: String = str(command.get("kind", "")).strip_edges().to_lower()
			match kind:
				"lane_intent":
					var result: Dictionary = ops_state.call(
						"apply_lane_intent",
						int(command.get("src", -1)),
						int(command.get("dst", -1)),
						str(command.get("intent", ""))
					) as Dictionary
					if not bool(result.get("ok", false)):
						failure_reason = "command_seq %d failed: %s" % [int(command.get("command_seq", 0)), str(result)]
						return
				"lane_retract":
					ops_state.call(
						"retract_lane",
						int(command.get("from_id", -1)),
						int(command.get("to_id", -1)),
						int(command.get("owner_id", 0))
					)
				_:
					failure_reason = "unsupported command kind: %s" % kind
					return
	)
	if not failure_reason.is_empty():
		return {"ok": false, "reason": failure_reason}
	return {"ok": true, "hash": str(ops_state.call("get_contract_state_hash"))}

func _find_lane_intent_command(poll: Dictionary, uid: String, intent: String, src: int, dst: int) -> Dictionary:
	var events_any: Variant = poll.get("events", [])
	if typeof(events_any) != TYPE_ARRAY:
		return {}
	for event_any in events_any as Array:
		if typeof(event_any) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_any as Dictionary
		if str(event.get("uid", "")) != uid:
			continue
		var command_any: Variant = event.get("command", {})
		if typeof(command_any) != TYPE_DICTIONARY:
			continue
		var command: Dictionary = command_any as Dictionary
		if str(command.get("kind", "")) != "lane_intent":
			continue
		if str(command.get("intent", "")) != intent:
			continue
		if int(command.get("src", -1)) == src and int(command.get("dst", -1)) == dst:
			return command.duplicate(true)
	return {}

func _fail(message: String) -> bool:
	push_error("VS_SWARM_REPLICATION_SMOKE: " + message)
	return true
