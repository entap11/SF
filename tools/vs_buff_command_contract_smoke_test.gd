extends SceneTree

const ResolverScript = preload("res://scripts/state/buff_target_resolver.gd")

class FakeState:
	extends RefCounted
	var tick: int = 25
	var hives: Array = [
		{"id": 1, "owner_id": 1},
		{"id": 2, "owner_id": 2}
	]
	var lanes: Array = [{"id": 10, "a_id": 1, "b_id": 2}]

var _failed: bool = false

func _init() -> void:
	await process_frame
	var runtime: Node = get_root().get_node_or_null("/root/VsPvpRuntime")
	if runtime == null:
		_fail("VsPvpRuntime autoload missing")
		quit(1)
		return
	runtime.call("clear")
	var command: Dictionary = _valid_command()
	_expect(bool(runtime.call("_validate_contract_command", command, "smoke")), "stable-ID buff command passes contract")
	_expect(command.get("target_id") == 1, "stable target ID enters canonical command")
	for forbidden_key in ["world_pos", "local_pos", "grid_pos", "touch_id", "screen_pos"]:
		_expect(not command.has(forbidden_key), "canonical command excludes %s" % forbidden_key)

	var transient: Dictionary = command.duplicate(true)
	transient["touch_id"] = 7
	_expect(not bool(runtime.call("_validate_contract_command", transient, "smoke")), "touch identity is rejected by canonical contract")
	var async_three: Dictionary = command.duplicate(true)
	async_three["source_kind"] = "async"
	async_three["source_use_ordinal"] = 3
	_expect(not bool(runtime.call("_validate_contract_command", async_three, "smoke")), "Async use three is rejected by canonical contract")

	runtime.call("clear")
	runtime.call("_queue_scheduled_command", command)
	runtime.call("_queue_scheduled_command", command.duplicate(true))
	var due: Array = runtime.call("consume_remote_commands", 100) as Array
	_expect(due.size() == 1, "duplicate canonical buff command executes once")
	var diagnostics: Dictionary = runtime.call("get_contract_diagnostics_snapshot") as Dictionary
	_expect(int(diagnostics.get("contract_late_scheduled_commands", 0)) == 1, "late buff command preserves late-command diagnostics")
	runtime.call("_queue_scheduled_command", command.duplicate(true))
	_expect((runtime.call("consume_remote_commands", 100) as Array).is_empty(), "replayed canonical buff command remains deduplicated")

	var host_resolver := ResolverScript.new()
	var guest_resolver := ResolverScript.new()
	var state := FakeState.new()
	var host_result: Dictionary = host_resolver.validate_canonical_target(state, 1, str(command.get("buff_id", "")), "hive", 1)
	var guest_result: Dictionary = guest_resolver.validate_canonical_target(state, 1, str(command.get("buff_id", "")), "hive", 1)
	_expect(host_result == guest_result and bool(host_result.get("ok", false)), "host and guest resolve the same executable outcome")
	state.hives[0]["owner_id"] = 2
	host_result = host_resolver.validate_canonical_target(state, 1, str(command.get("buff_id", "")), "hive", 1)
	guest_result = guest_resolver.validate_canonical_target(state, 1, str(command.get("buff_id", "")), "hive", 1)
	_expect(host_result == guest_result and str(host_result.get("reason", "")) == "target_ineligible", "host and guest resolve the same deterministic no-op")

	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	_expect(arena_source.contains("func submit_buff_activation(\n\tpid: int,\n\tslot_index: int,\n\ttarget_type: String,\n\ttarget_id: Variant"), "UI-facing submission accepts slot and stable target, not buff identity")
	_expect(arena_source.contains("func _canonical_buff_command_from_reservation(reservation: Dictionary)"), "canonical command derives identity from reservation")
	_expect(shell_source.contains("const MATCH_BUFF_TARGETING_ENABLED: bool = false"), "production buff targeting gate remains disabled")
	_expect(not shell_source.contains("LEGACY_MATCH_BUFF_STRIPS_ENABLED"), "legacy-named production gate is retired")

	runtime.call("clear")
	if _failed:
		quit(1)
		return
	print("VS_BUFF_COMMAND_CONTRACT_SMOKE: PASS")
	quit(0)

func _valid_command() -> Dictionary:
	return {
		"kind": "buff_activate",
		"contract_version": 1,
		"client_command_id": "buff-smoke-client-1",
		"command_id": "buff-smoke:1",
		"command_seq": 1,
		"issued_ms": maxi(1, Time.get_ticks_msec()),
		"issued_tick": 20,
		"local_issued_tick": 20,
		"issued_sim_us": 2_000_000,
		"requested_execute_tick": 23,
		"canonical_execute_tick": 25,
		"execute_tick": 25,
		"sender_seat": 1,
		"sender_uid": "buff-smoke-host",
		"activation_id": "activation-1",
		"owner_id": 1,
		"buff_id": "buff_unit_speed_classic",
		"tier": "classic",
		"target_type": "hive",
		"target_id": 1,
		"source_kind": "vs",
		"source_use_ordinal": 1
	}

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_fail(label)

func _fail(message: String) -> void:
	_failed = true
	push_error("VS_BUFF_COMMAND_CONTRACT_SMOKE: %s" % message)
