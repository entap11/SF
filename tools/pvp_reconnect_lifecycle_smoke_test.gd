extends SceneTree

var _failed: bool = false
var _transport_events: Array[Dictionary] = []

func _initialize() -> void:
	await process_frame
	var arena_script: Resource = load("res://scripts/arena.gd")
	var runtime_script: Resource = load("res://scripts/state/vs_pvp_runtime.gd")
	var runner_script: Resource = load("res://scripts/systems/sim_runner.gd")
	_expect(arena_script is Script and (arena_script as Script).can_instantiate(), "Arena reconnect integration should parse")
	_expect(runtime_script is Script and (runtime_script as Script).can_instantiate(), "PvP runtime reconnect integration should parse")
	_expect(runner_script is Script and (runner_script as Script).can_instantiate(), "SimRunner forfeit integration should parse")
	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/state/vs_pvp_runtime.gd")
	var runner_source: String = FileAccess.get_file_as_string("res://scripts/systems/sim_runner.gd")
	var server_source: String = FileAccess.get_file_as_string("res://tools/vs-service/src/server.ts")
	_expect(arena_source.contains("notify_match_backgrounded"), "actual app background should notify the PvP relay")
	_expect(not arena_source.contains("app_focus_changed\", Callable(self, \"_on_app_backgrounded"), "focus loss alone must not count as a disconnect")
	_expect(arena_source.contains("If your opponent doesn't reconnect in"), "waiting player should receive the reconnect deadline explanation")
	_expect(arena_source.contains("grace_deadline_unix_ms"), "disconnect overlay should render the server grace deadline")
	_expect(arena_source.contains("They have disconnected %d/%d times."), "waiting player should see the opponent's authoritative strike count")
	_expect(arena_source.contains("You have disconnected %d/%d times."), "returning player should receive the authoritative strike warning")
	_expect(arena_source.contains("If you disconnect %s, you will forfeit the game."), "returning player should see the remaining disconnect allowance")
	_expect(arena_source.contains("_match_disconnect_countdown.add_theme_font_size_override(\"font_size\", 72)"), "grace countdown should be materially larger than the explanatory copy")
	_expect(arena_source.contains("restore_authority_snapshot"), "returning client should restore one authoritative snapshot")
	_expect(arena_source.contains("MATCH RESUMES IN %d"), "both players should see the shared restart countdown")
	_expect(arena_source.contains("resume_checkpoint_tick"), "restart overlay should report the agreed checkpoint tick")
	_expect(runtime_source.contains("get_match_lifecycle_phase() == \"running\""), "gameplay intents should be blocked during reconnect")
	_expect(runtime_source.contains("not is_local_transport_interrupted()"), "gameplay intents should be blocked on local transport loss")
	_expect(arena_source.contains("Waiting for the match server to confirm the disconnect"), "local transport loss should show an immediate disconnect popup")
	_expect(arena_source.contains("The exact authoritative deadline will replace this estimate"), "local countdown should disclose authoritative server takeover")
	_expect(arena_source.contains("_pause_for_match_lifecycle(\"local_transport_interrupted\")"), "sustained transport loss should stop the simulation runner")
	_expect(arena_source.contains("_match_disconnect_overlay != null and _match_disconnect_overlay.visible"), "disconnect overlay should consume all gameplay input")
	_expect(arena_source.contains("if _local_transport_interruption_snapshot.is_empty()"), "authoritative running updates must not dismiss an active local interruption")
	_expect(runtime_source.contains("transport_recovery_stale_response_ignored"), "pre-interruption responses must not clear transport loss")
	_expect(server_source.contains("presence_stale_ms: MATCH_PRESENCE_STALE_MS"), "relay lifecycle should publish its stale boundary for client timer alignment")
	_expect(runtime_source.contains("complete_reconnect_snapshot_restore"), "snapshot restore should discard already-applied commands")
	_expect(runner_source.contains("func resolve_authoritative_forfeit"), "forfeit should resolve through the simulation system")
	_exercise_local_transport_fail_safe(runtime_script as Script)
	if not _failed:
		print("PVP_RECONNECT_LIFECYCLE_SMOKE: PASS")
	quit(1 if _failed else 0)

func _exercise_local_transport_fail_safe(runtime_script: Script) -> void:
	var runtime: Node = runtime_script.new() as Node
	root.add_child(runtime)
	runtime.set("_active", true)
	runtime.set("_session_id", "transport-fail-safe-test")
	runtime.set("_local_uid", "local-player")
	runtime.connect("local_transport_interruption_changed", Callable(self, "_on_transport_interruption_changed"))
	runtime.call("_update_match_lifecycle", {
		"phase": "running",
		"epoch": 1,
		"server_unix_ms": 1_000_000,
		"reconnect_grace_sec": 60,
		"presence_stale_ms": 2500
	})
	_expect(bool(runtime.call("can_accept_gameplay_intents")), "healthy running runtime should accept gameplay intents")
	runtime.call("_record_transport_result", "poll", {
		"ok": false,
		"transport_error": true,
		"err": "connect_timeout"
	}, Time.get_ticks_usec())
	_expect(bool(runtime.call("is_local_transport_interrupted")), "transport error should enter local interruption state")
	_expect(not bool(runtime.call("can_accept_gameplay_intents")), "transport error should block gameplay intents immediately")
	var interrupted: Dictionary = runtime.call("get_local_transport_interruption") as Dictionary
	_expect(int(interrupted.get("estimated_grace_deadline_server_unix_ms", 0))
		- int(interrupted.get("estimated_grace_start_server_unix_ms", 0)) == 60_000,
		"estimated reconnect deadline should preserve the server's 60-second grace")
	_expect(not _transport_events.is_empty() and bool(_transport_events[0].get("active", false)),
		"first transport failure should emit the popup state")
	var detected_local_us: int = int(interrupted.get("detected_local_us", 0))
	runtime.call("_record_transport_result", "poll", {
		"ok": true,
		"match_lifecycle": {
			"phase": "running",
			"epoch": 1,
			"server_unix_ms": 1_000_001
		}
	}, detected_local_us - 1)
	_expect(bool(runtime.call("is_local_transport_interrupted")),
		"response started before interruption detection must not dismiss the popup")
	_expect(not bool(runtime.call("can_accept_gameplay_intents")),
		"stale reachable response must not unlock gameplay input")
	interrupted["estimated_grace_start_server_unix_ms"] = int(runtime.call(
		"_estimated_authoritative_server_unix_ms", Time.get_ticks_msec()
	)) - 251
	runtime.set("_local_transport_interruption", interrupted)
	runtime.call("_refresh_local_transport_interruption", Time.get_ticks_msec(), false)
	_expect(bool((runtime.call("get_local_transport_interruption") as Dictionary).get("should_pause", false)),
		"sustained outage should request a local simulation pause at the server stale boundary")
	_expect(bool(_transport_events.back().get("should_pause", false)),
		"pause transition should be emitted to the Arena")
	runtime.call("_record_transport_result", "poll", {
		"ok": true,
		"match_lifecycle": {
			"phase": "resuming",
			"epoch": 2,
			"server_unix_ms": 1_003_000,
			"resume_checkpoint_tick": 42
		}
	}, Time.get_ticks_usec())
	_expect(not bool(runtime.call("is_local_transport_interrupted")), "reachable server response should hand control back to authoritative lifecycle")
	_expect(not bool(_transport_events.back().get("active", true)), "transport recovery should clear the local-only popup state")
	runtime.free()

func _on_transport_interruption_changed(snapshot: Dictionary) -> void:
	_transport_events.append(snapshot.duplicate(true))

func _expect(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("PVP_RECONNECT_LIFECYCLE_SMOKE: %s" % message)
