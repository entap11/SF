extends SceneTree

var _failed: bool = false

func _init() -> void:
	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	var vfx_source: String = FileAccess.get_file_as_string("res://scripts/vfx/vfx_manager.gd")
	_expect(shell_source.contains("present_for_match_readiness"), "Shell should present the loading cover before match construction")
	_expect(shell_source.contains("_wait_for_arena_startup_readiness"), "Shell should wait for Arena readiness before reveal")
	_expect(shell_source.contains("release_after_match_ready"), "Shell should explicitly release the readiness cover")
	_expect(arena_source.contains("_match_loading_cover_holds_countdown"), "Arena should hold the countdown behind the readiness cover")
	_expect(arena_source.contains("_run_prematch_warmup_budget"), "Arena should own a bounded countdown warmup queue")
	_expect(arena_source.contains("_run_post_start_work_budget"), "Arena should own a deferred post-start work queue")
	_expect(not arena_source.contains("call_deferred(\"_ensure_in_game_ad_surface\")"), "in-game ad setup should not compete with startup")
	_expect(vfx_source.contains("take_prematch_warmup_tasks"), "VFX first-use nodes should enter the countdown queue")
	_expect(not vfx_source.contains("call_deferred(\"_prewarm_vfx_nodes\")"), "VFX first-use work should not run as an unbounded startup deferred call")

	if _failed:
		quit(1)
		return
	print("STARTUP_READINESS_PIPELINE_SMOKE: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("STARTUP_READINESS_PIPELINE_SMOKE: %s" % message)
