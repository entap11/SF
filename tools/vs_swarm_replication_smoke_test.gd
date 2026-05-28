extends SceneTree

const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const SETTINGS_CRASH_ON_CONTRACT_VIOLATION: String = "swarmfront/vs/crash_on_contract_violation"

func _init() -> void:
	await process_frame
	var failed: bool = false
	failed = _test_successful_swarm_intent_replicates() or failed
	failed = _test_invalid_remote_command_trips_contract_guard() or failed
	failed = _test_missed_scheduled_command_updates_diagnostics() or failed
	failed = _test_state_hash_mismatch_trips_contract_guard() or failed
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
	var early_attack: Array = runtime.call("consume_remote_commands", 1) as Array
	if not early_attack.is_empty():
		return _fail("scheduled attack command should not mature early: %s" % str(early_attack))
	var early_diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if int(early_diag.get("contract_command_lead_ticks", -1)) != 2:
		return _fail("early scheduled command lead should be 2 ticks: %s" % str(early_diag))
	var scheduled_attack: Array = runtime.call("consume_remote_commands", 3) as Array
	if scheduled_attack.is_empty():
		return _fail("scheduled attack command missing")
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
	ProjectSettings.set_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, true)
	return false

func _test_missed_scheduled_command_updates_diagnostics() -> bool:
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
	if not matured.is_empty():
		return _fail("missed scheduled command should not be delivered after execute tick: %s" % str(matured))
	var after_count: int = int(runtime.call("get_contract_violation_count"))
	if after_count <= before_count:
		return _fail("missed scheduled command did not trip contract guard")
	var diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if int(diag.get("contract_missed_scheduled_commands", 0)) <= 0:
		return _fail("missed scheduled command should increment diagnostics: %s" % str(diag))
	if int(diag.get("contract_command_lead_ticks", 0)) != -1:
		return _fail("missed scheduled command should record negative lead: %s" % str(diag))
	if runtime.has_method("clear"):
		runtime.call("clear")
	ProjectSettings.set_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, true)
	return false

func _test_state_hash_mismatch_trips_contract_guard() -> bool:
	ProjectSettings.set_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, false)
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
	runtime.set("_local_hash_by_tick", {5: "local_hash"})
	var before_count: int = int(runtime.call("get_contract_violation_count"))
	runtime.call("_handle_remote_intent_poll_result", {
		"ok": true,
		"latest_seq": 1,
		"events": [
			{
				"seq": 1,
				"uid": "hash_guest",
				"command": {
					"kind": "state_hash",
					"contract_version": 1,
					"issued_ms": Time.get_ticks_msec(),
					"issued_tick": 5,
					"execute_tick": 8,
					"issued_sim_us": 500000,
					"sender_seat": 2,
					"sender_uid": "hash_guest",
					"hash_tick": 5,
					"state_hash": "remote_hash"
				}
			}
		]
	}, Time.get_ticks_usec(), 0)
	var after_count: int = int(runtime.call("get_contract_violation_count"))
	if after_count <= before_count:
		return _fail("state hash mismatch did not trip contract guard")
	var diag: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	if int(diag.get("contract_state_hash_mismatches", 0)) <= 0:
		return _fail("state hash mismatch should increment diagnostics: %s" % str(diag))
	if str(diag.get("contract_last_violation_reason", "")) != "state_hash_mismatch":
		return _fail("state hash mismatch should record latest violation reason: %s" % str(diag))
	if runtime.has_method("clear"):
		runtime.call("clear")
	ProjectSettings.set_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, true)
	return false

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
