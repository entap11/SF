extends SceneTree

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")
const MAP_APPLIER := preload("res://scripts/maps/map_applier.gd")
const ARENA_SCENE := preload("res://scenes/Arena.tscn")
const MAP_PATH := "res://maps/json/MAP_SKETCH_LR_8x12_v1xy_BARRACKS_1.json"

func _initialize() -> void:
	_run()

func _run() -> void:
	var arena := ARENA_SCENE.instantiate() as Node2D
	if arena == null:
		push_error("HEADLESS: failed to instantiate Arena.tscn")
		quit()
		return
	root.add_child(arena)
	await process_frame
	await process_frame

	_log_owner_summary_from_schema()

	var result: Dictionary = MAP_LOADER.load_map(MAP_PATH)
	if not bool(result.get("ok", false)):
		push_error("HEADLESS: load_map failed %s" % str(result.get("err", result.get("error", "unknown"))))
		quit()
		return
	var data: Dictionary = result.get("data", {})
	if arena.has_method("apply_loaded_map"):
		arena.call("apply_loaded_map", data)
	MAP_APPLIER.apply_map(arena, data)
	await process_frame

	_simulate_clicks(arena)
	await process_frame
	quit()

func _simulate_clicks(arena: Node2D) -> void:
	var state = arena.state
	if state == null or state.hives.is_empty():
		push_error("HEADLESS: no hives in state")
		return
	var hives: Array = state.hives.duplicate()
	hives.sort_custom(Callable(self, "_sort_hive_x"))
	var left = hives[0]
	var right = hives[hives.size() - 1]
	var center = hives[int(hives.size() / 2)]
	var api = arena.api
	var input_sys = arena.input_system
	_click_hive(input_sys, api, left, MOUSE_BUTTON_LEFT)
	_click_hive(input_sys, api, right, MOUSE_BUTTON_RIGHT)
	_click_hive(input_sys, api, center, MOUSE_BUTTON_LEFT)

func _click_hive(input_sys: Object, api: ArenaAPI, hive: HiveData, button: int) -> void:
	if input_sys == null or api == null:
		return
	var local_pos: Vector2 = api.cell_center(hive.grid_pos)
	var dev_pid: int = input_sys._dev_mouse_pid_from_button(button)
	input_sys._handle_press(local_pos, int(hive.id), -1, dev_pid, api, button)

func _sort_hive_x(a: HiveData, b: HiveData) -> bool:
	return int(a.grid_pos.x) < int(b.grid_pos.x)

func _log_owner_summary_from_schema() -> void:
	var f: FileAccess = FileAccess.open(MAP_PATH, FileAccess.READ)
	if f == null:
		push_error("HEADLESS: map file open failed for %s" % MAP_PATH)
		return
	var raw: String = f.get_as_text()
	if raw.strip_edges().is_empty():
		push_error("HEADLESS: map file empty for %s" % MAP_PATH)
		return
	var json := JSON.new()
	var err: int = json.parse(raw)
	if err != OK:
		push_error("HEADLESS: map json parse failed for %s" % MAP_PATH)
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("HEADLESS: map json root not dict for %s" % MAP_PATH)
		return
	MAP_SCHEMA._adapt_v1_xy_to_internal(json.data as Dictionary)
