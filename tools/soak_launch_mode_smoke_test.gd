extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var shell_script: Script = load("res://scripts/shell.gd") as Script
	_expect(shell_script != null, "Shell script must load")
	if shell_script == null:
		_finish()
		return

	var shell: Node = shell_script.new() as Node
	var explicit_config: Dictionary = shell.call("_parse_soak_perf_config", [
		"--soak-perf",
		"--soak-mode=1p"
	]) as Dictionary
	_expect(bool(explicit_config.get("enabled", false)), "soak flag must enable the harness")
	_expect(str(explicit_config.get("mode", "")) == "1p", "explicit 1P soak mode must parse")

	var default_config: Dictionary = shell.call("_parse_soak_perf_config", ["--soak-perf"]) as Dictionary
	_expect(str(default_config.get("mode", "")) == "1p", "legacy direct launches must default deterministically to 1P")

	var ops_state: Node = root.get_node_or_null("OpsState")
	_expect(ops_state != null, "OpsState autoload must be available")
	if ops_state == null:
		shell.free()
		_finish()
		return
	var previous_mode: String = str(ops_state.call("get_team_mode_override"))
	ops_state.call("set_team_mode_override", "2v2")
	_expect(bool(shell.call("_apply_soak_launch_mode", explicit_config)), "1P soak mode must apply")
	_expect(
		str(ops_state.call("get_team_mode_override")) == "1p",
		"soak launch must set the authoritative OpsState team mode to 1P"
	)
	_expect(
		not bool(shell.call("_apply_soak_launch_mode", {"mode": "2v2"})),
		"legacy 1P soak must reject an incompatible team mode"
	)
	ops_state.call("set_team_mode_override", previous_mode)
	shell.free()

	var runner_source: String = FileAccess.get_file_as_string("res://scripts/dev/run_soak_gate.sh")
	_expect(runner_source.contains('SOAK_MODE="${SOAK_MODE:-1p}"'), "runner must declare its 1P mode")
	_expect(runner_source.contains('--soak-mode="${SOAK_MODE}"'), "runner must pass the mode to Shell")
	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	_expect(
		shell_source.contains("await _apply_map_then_start(map_path)\n\tvar boot_running_ok"),
		"RUNNING timeout must begin after asynchronous map launch completes"
	)
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("SOAK_LAUNCH_MODE_SMOKE: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("SOAK_LAUNCH_MODE_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
