extends "res://tools/player_config_matrix_topology_boot_runner.gd"

class OpsFixture extends Node:
	enum MatchPhase { PREMATCH, RUNNING }
	var match_phase: int = MatchPhase.PREMATCH

func _run() -> void:
	# Reproduce a loading frame that completes after the polling deadline.
	call_deferred("_spawn_after_slow_frame")
	var found: Node = await _wait_for_node("/root/DelayedArena", 10)
	_expect(found != null, "missed node added during a slow frame", {})
	var spawned: Node = root.get_node_or_null("DelayedArena")
	if spawned != null:
		spawned.free()
	var missing: Node = await _wait_for_node("/root/MissingArena", 10)
	_expect(missing == null, "missing node must time out", {})
	var ops := OpsFixture.new()
	root.add_child(ops)
	call_deferred("_run_after_slow_frame", ops)
	var running: bool = await _wait_for_match_running(ops, 10)
	_expect(running, "missed RUNNING reached during a slow frame", {})
	ops.match_phase = OpsFixture.MatchPhase.PREMATCH
	var stalled: bool = await _wait_for_match_running(ops, 10)
	_expect(not stalled, "stalled match must time out", {})
	var absent: bool = await _wait_for_match_running(null, 10)
	_expect(not absent, "missing match state must fail", {})
	ops.free()
	if not _failed:
		print("PLAYER_CONFIG_MATRIX_WAIT_REGRESSION: PASS")
	quit(1 if _failed else 0)

func _spawn_after_slow_frame() -> void:
	OS.delay_msec(30)
	var node := Node.new()
	node.name = "DelayedArena"
	root.add_child(node)

func _run_after_slow_frame(ops: OpsFixture) -> void:
	OS.delay_msec(30)
	ops.match_phase = OpsFixture.MatchPhase.RUNNING
