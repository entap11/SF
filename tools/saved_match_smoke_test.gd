extends SceneTree

const Policy = preload("res://scripts/state/saved_match_policy.gd")
const Store = preload("res://scripts/state/saved_match_store.gd")
const Boards = preload("res://scripts/state/jukebox_leaderboard_store.gd")
var failed := false
var ops: Node

func _initialize() -> void:
	await process_frame
	ops = root.get_node("OpsState")
	_test_policy()
	_test_store()
	_test_periods()
	_test_simulation_restart()
	for path in ["res://scripts/arena.gd", "res://scripts/shell.gd", "res://scripts/ui/main_menu.gd"]:
		var script: Script = load(path)
		check(script != null and script.can_instantiate(), "runtime script compiles: " + path)
	print("SAVED_MATCH_SMOKE: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("SAVED_MATCH_SMOKE: " + message)

func _test_policy() -> void:
	var solo := [{"seat": 1, "is_cpu": false}, {"seat": 2, "is_cpu": true}]
	check(Policy.eligibility({"vs_mode": "TIMED_RACE"}, solo).ok, "non-money async eligible")
	check(Policy.eligibility({"vs_mode": "PROGRESSIVE", "async_money_contest_id": "free-gauntlet"}, solo).ok, "legacy money-named contest ID alone does not exclude a free Gauntlet")
	for context in [{"vs_price_usd": 5}, {"vs_wager_cents": 100}, {"vs_paid_entry": true}, {"async_money_entry_id": "entry"}, {"vs_crucible": true}, {"vs_handshake_session_id": "live"}, {"vs_sync_start": true}]:
		check(not Policy.eligibility(context, solo).ok, "excluded contract: " + str(context))
	check(not Policy.eligibility({}, [{"is_cpu": false}, {"is_cpu": false}]).ok, "local multiplayer excluded")
	var close := Policy.parse_deadline("2026-10-05T00:00:00.000Z")
	check(close == 1791158400, "UTC service timestamp parsed")
	check(Policy.deadline({"vs_window_deadline_unix": close + 10, "hive_tournament_deadline_unix": close - 10, "public_contest_attempt": {"submission_deadline_at": "2026-10-05T00:00:00Z"}}) == close - 10, "earliest round / attempt / contest deadline wins")

func _test_store() -> void:
	var store = Store.new()
	store.root_path = "user://saved_match_smoke"
	var payload := {"id": "run", "owner": "alice", "saved_at": 7, "position": Vector2(1.25, 9.5), "keys": {2: {"remaining": 3}}, "rng": 9223372036854775700}
	check(store.write("alice", "run", payload), "atomic checkpoint write")
	var loaded: Dictionary = store.read("alice", "run")
	check(loaded == payload, "disk roundtrip preserves vectors, integer keys, 64-bit RNG")
	check(store.read("bob", "run").is_empty(), "account isolation")
	var file := FileAccess.open(store.path_for("alice", "run") + ".tmp", FileAccess.WRITE)
	file.store_string("interrupted write")
	file.close()
	check(store.read("alice", "run") == payload, "interrupted replacement preserves last committed save")
	file = FileAccess.open(store.path_for("alice", "run"), FileAccess.WRITE)
	file.store_var({"version": 1, "owner": "alice", "bytes": PackedByteArray([1, 2]), "sha256": "wrong"})
	file.close()
	check(store.read("alice", "run").is_empty(), "corrupt save rejected")
	store.remove("alice", "run")

func _test_periods() -> void:
	var boards = Boards.new()
	boards.save_path = "user://saved_match_boards_smoke.json"
	boards.debug_reset_state()
	var before := Policy.parse_deadline("2026-10-04T23:59:00Z")
	var after := Policy.parse_deadline("2026-10-05T00:01:00Z")
	var result: Dictionary = boards.record_run_all_periods("map", "ASYNC_SINGLE_MAP_TIMED", {"player_id": "alice", "best_time_ms": 9000, "started_at": before, "updated_at": after})
	check(result.ok and not result.periods_updated.has("WEEKLY"), "week rollover cannot enter either weekly board")
	check(result.periods_updated.has("MONTHLY") and result.periods_updated.has("ALL TIME"), "still-open month and all-time remain eligible")
	result = boards.record_run_all_periods("map", "ASYNC_SINGLE_MAP_TIMED", {"player_id": "alice", "best_time_ms": 8000, "started_at": after, "updated_at": after + 1})
	check(result.periods_updated.has("WEEKLY"), "same-week run eligible")
	boards.debug_reset_state()

func _new_runner() -> Node:
	var runner: Node = load("res://scripts/systems/sim_runner.gd").new()
	runner.scene_structure_binding_enabled = false
	runner.autostart_on_bind = false
	root.add_child(runner)
	runner.set_process(false)
	runner.set_physics_process(false)
	runner.enable_deterministic_clock()
	runner.bind_state(ops.state)
	return runner

func _test_simulation_restart() -> void:
	var map := {"map_id": "saved_smoke", "hives": [
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 80, "kind": "Hive"},
		{"id": 2, "x": 9, "y": 0, "owner_id": 2, "power": 80, "kind": "Hive"},
		{"id": 3, "x": 0, "y": 6, "owner_id": 1, "power": 20, "kind": "Hive"}],
		"lane_candidates": [{"a_id": 1, "b_id": 2}, {"a_id": 1, "b_id": 3}, {"a_id": 2, "b_id": 3}]}
	ops.reset_state_from_map(map)
	ops.match_phase = 1
	ops.input_locked = false
	ops.set_team_mode_override("ffa")
	ops.set_bot_profile(2, {"enabled": true, "style": "balancer", "tier": "medium", "opening_delay_ms": 0})
	var runner := _new_runner()
	runner.set_running(true)
	ops.apply_lane_intent(1, 2, "attack")
	ops.apply_lane_intent(1, 3, "feed")
	ops.apply_lane_intent(2, 1, "attack")
	for i in 45:
		runner.step_canonical()
	ops.apply_lane_intent(1, 2, "swarm")
	runner.step_canonical()
	var store = Store.new()
	store.root_path = "user://saved_match_smoke"
	var checkpoint: Dictionary = runner.capture_match_checkpoint()
	var elapsed: int = ops.match_elapsed_ms
	var hash_before: String = ops.get_contract_state_hash()
	check(store.write("alice", "simulation", {"owner": "alice", "id": "simulation", "sim": checkpoint}), "simulation encoded to disk")
	for i in 20:
		runner.step_canonical()
	var expected: Dictionary = runner.capture_match_checkpoint()
	var expected_hash: String = ops.get_contract_state_hash()
	runner.free()
	ops.reset_state_from_map(map)
	runner = _new_runner()
	var restored: Dictionary = store.read("alice", "simulation")
	check(runner.restore_match_checkpoint(restored.sim), "restore into fresh map and systems")
	check(ops.get_contract_state_hash() == hash_before, "exact authoritative state restored")
	check(ops.match_elapsed_ms == elapsed and not runner.running and ops.match_clock_paused, "clock and simulation frozen for countdown")
	check(abs(ops.match_deadline_ms - Time.get_ticks_msec() - ops.match_remaining_ms) < 30, "uptime deadline rebased")
	ops.finish_saved_match_countdown()
	runner.set_running(true)
	for i in 20:
		runner.step_canonical()
	check(ops.get_contract_state_hash() == expected_hash, "20 subsequent ticks with bots match uninterrupted simulation")
	check(ops.match_elapsed_ms == expected.authority.match_elapsed_ms, "countdown / absence never charged to match clock")
	check(runner.swarm_system._next_swarm_id == expected.systems.swarm_system._next_swarm_id, "swarm identity sequence preserved")
	runner.free()
	store.remove("alice", "simulation")
