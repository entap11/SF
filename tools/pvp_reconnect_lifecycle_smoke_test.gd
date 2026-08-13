extends SceneTree

var _failed: bool = false

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
	_expect(runtime_source.contains("complete_reconnect_snapshot_restore"), "snapshot restore should discard already-applied commands")
	_expect(runner_source.contains("func resolve_authoritative_forfeit"), "forfeit should resolve through the simulation system")
	if not _failed:
		print("PVP_RECONNECT_LIFECYCLE_SMOKE: PASS")
	quit(1 if _failed else 0)

func _expect(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("PVP_RECONNECT_LIFECYCLE_SMOKE: %s" % message)
