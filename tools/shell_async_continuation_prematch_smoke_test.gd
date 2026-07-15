extends SceneTree

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ops_state: Node = get_root().get_node_or_null("OpsState")
	if ops_state == null:
		_fail("OpsState autoload missing")
		return
	if ops_state.has_method("sim_mutate"):
		ops_state.call("sim_mutate", "shell_async_continuation_prematch_smoke", func() -> void:
			ops_state.set("match_phase", ops_state.MatchPhase.PREMATCH)
			ops_state.set("prematch_remaining_ms", 5000)
		)
	else:
		ops_state.set("match_phase", 0)
		ops_state.set("prematch_remaining_ms", 5000)

	var shell_scene: PackedScene = load("res://scenes/Shell.tscn") as PackedScene
	if shell_scene == null:
		_fail("Shell.tscn failed to load")
		return
	var shell: Node = shell_scene.instantiate()
	get_root().add_child(shell)
	await process_frame

	var arena_stub: Node = Node.new()
	arena_stub.name = "ArenaStub"
	shell.set("_arena_instance", arena_stub)
	shell.add_child(arena_stub)

	for mode in ["STAGE_RACE", "TIMED_RACE", "MISS_N_OUT"]:
		_set_continuation_meta(mode)
		var should_show: bool = bool(shell.call("_show_shell_async_prematch_card"))
		_expect(not should_show, "%s continuation should not repeat match facts in prematch" % mode)
		var line: String = str(shell.call("_shell_async_prematch_round_line"))
		_expect(line.find("2") >= 0 and line.find("3") >= 0, "%s continuation state should retain internal round progress: %s" % [mode, line])

	shell.queue_free()
	if not _failed:
		print("SHELL_ASYNC_CONTINUATION_PREMATCH_SMOKE: PASS")
	quit(1 if _failed else 0)

func _set_continuation_meta(mode: String) -> void:
	set_meta("vs_mode", mode)
	set_meta("vs_stage_map_paths", [
		"res://maps/json/MAP_TEST.json",
		"res://maps/json/MAP_TEST_8x12.json",
		"res://maps/json/MAP_TEST.json"
	])
	set_meta("vs_stage_current_index", 1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error("SHELL_ASYNC_CONTINUATION_PREMATCH_SMOKE: %s" % message)
