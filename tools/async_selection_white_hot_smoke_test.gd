extends SceneTree

const INPUT_SYSTEM_PATH := "res://scripts/systems/input_system.gd"
const HIVE_RENDERER_PATH := "res://scripts/renderers/hive_renderer.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var input_source: String = FileAccess.get_file_as_string(INPUT_SYSTEM_PATH)
	var renderer_source: String = FileAccess.get_file_as_string(HIVE_RENDERER_PATH)

	if not input_source.contains("arena_api.set_selected_hive_id(hive_id)"):
		_fail("input selection should publish selected hive through ArenaAPI")
		return
	if not input_source.contains("arena_api.clear_selection()"):
		_fail("input clear should publish cleared selection through ArenaAPI")
		return
	if not input_source.contains("_set_selected_for_player(arena_api, actor_id, hive_id)"):
		_fail("press-time friendly selection should route through shared selection helper")
		return
	if not renderer_source.contains("_apply_selection(_current_selected_hive_id(arena_api))"):
		_fail("renderer setup should not blindly apply stale ArenaAPI selection")
		return
	if not renderer_source.contains("func _current_selected_hive_id(arena_api: ArenaAPI) -> int:"):
		_fail("renderer should expose selected id reconciliation helper")
		return
	if not renderer_source.contains("sel.get(\"selected_hive_id\")"):
		_fail("renderer setup should fall back to SelectionState selected hive")
		return

	print("ASYNC_SELECTION_WHITE_HOT_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("ASYNC_SELECTION_WHITE_HOT_SMOKE: %s" % message)
	quit(1)
