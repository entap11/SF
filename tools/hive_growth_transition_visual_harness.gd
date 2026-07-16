extends SceneTree

const GameStateScript := preload("res://scripts/state/game_state.gd")
const HiveDataScript := preload("res://scripts/data/hive_data.gd")
const ARTIFACT_DIR: String = "res://artifacts/hive_growth_transition"

var _state: GameState = null
var _renderer: Node2D = null
var _capture_once: bool = false
var _slow_motion: bool = false
var _status_label: Label = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_capture_once = "--capture" in OS.get_cmdline_user_args()
	get_root().size = Vector2i(1080, 1920)
	get_root().window_input.connect(_on_window_input)
	_build_background()
	_build_battlefield_overlays()
	_build_fixture()
	await process_frame
	await process_frame
	if _capture_once:
		await _run_capture_sequence()
		return
	_set_status("READY — choose a transition")

func _run_capture_sequence() -> void:
	_capture("baseline")
	await create_timer(0.35).timeout
	_authoritative_fixture_growth()
	await create_timer(0.04).timeout
	_capture("precharge")
	await create_timer(0.09).timeout
	_capture("first_ring")
	await create_timer(0.10).timeout
	_capture("overlapping_rings")
	await create_timer(0.07).timeout
	_capture("final_ring_reveal_start")
	await create_timer(0.08).timeout
	_capture("mid_reveal")
	await create_timer(0.13).timeout
	_capture("final_ring_clear")
	await create_timer(0.20).timeout
	_capture("settled")
	print("HIVE_GROWTH_TRANSITION_VISUAL_HARNESS: CAPTURED")
	quit(0)

func _on_window_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_trigger_small_to_medium()
		KEY_2:
			_trigger_medium_to_large()
		KEY_3:
			_trigger_small_to_large()
		KEY_R:
			_reset_all()
		KEY_SPACE:
			_repeat_all()
		KEY_S:
			_toggle_slow_motion()
		KEY_ESCAPE:
			Engine.time_scale = 1.0
			quit(0)

func _build_background() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.position = Vector2.ZERO
	background.size = Vector2(1080.0, 1920.0)
	background.color = Color(0.025, 0.032, 0.048, 1.0)
	background.z_index = -100
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_root().add_child(background)
	for x in range(0, 1081, 64):
		var grid_line := Line2D.new()
		grid_line.points = PackedVector2Array([Vector2(x, 190), Vector2(x, 1740)])
		grid_line.width = 1.0
		grid_line.default_color = Color(0.16, 0.24, 0.34, 0.14)
		grid_line.z_index = -90
		get_root().add_child(grid_line)
	for y in range(190, 1741, 64):
		var grid_line := Line2D.new()
		grid_line.points = PackedVector2Array([Vector2(0, y), Vector2(1080, y)])
		grid_line.width = 1.0
		grid_line.default_color = Color(0.16, 0.24, 0.34, 0.14)
		grid_line.z_index = -90
		get_root().add_child(grid_line)
	var title := Label.new()
	title.position = Vector2(48.0, 48.0)
	title.text = "HIVE GROWTH — ENERGY RING REVIEW"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
	get_root().add_child(title)
	var controls := Label.new()
	controls.position = Vector2(50.0, 98.0)
	controls.text = "1 Small→Medium   2 Medium→Large   3 Small→Large   R Reset   Space Repeat all   S 0.25×   Esc Exit"
	controls.add_theme_font_size_override("font_size", 20)
	controls.add_theme_color_override("font_color", Color(0.62, 0.76, 0.88, 1.0))
	get_root().add_child(controls)
	_status_label = Label.new()
	_status_label.position = Vector2(50.0, 138.0)
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 1.0))
	get_root().add_child(_status_label)

func _build_battlefield_overlays() -> void:
	var lanes: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(300, 530), Vector2(650, 790)]),
		PackedVector2Array([Vector2(650, 790), Vector2(330, 1260)]),
		PackedVector2Array([Vector2(330, 1260), Vector2(760, 1450)])
	]
	for i in range(lanes.size()):
		var lane := Line2D.new()
		lane.name = "RepresentativeLane_%d" % i
		lane.points = lanes[i]
		lane.width = 18.0
		lane.default_color = Color(0.22, 0.52, 0.76, 0.26)
		lane.z_index = -40
		get_root().add_child(lane)
		var lane_core := Line2D.new()
		lane_core.points = lanes[i]
		lane_core.width = 3.0
		lane_core.default_color = Color(0.52, 0.82, 1.0, 0.54)
		lane_core.z_index = -39
		get_root().add_child(lane_core)
	for position in [Vector2(460, 650), Vector2(555, 735), Vector2(500, 1030), Vector2(435, 1165)]:
		var unit := Polygon2D.new()
		unit.position = position
		unit.polygon = PackedVector2Array([
			Vector2(0, -8), Vector2(7, 5), Vector2(0, 9), Vector2(-7, 5)
		])
		unit.color = Color(0.72, 0.90, 1.0, 0.92)
		unit.z_index = -10
		get_root().add_child(unit)

func _build_fixture() -> void:
	_state = GameStateScript.new()
	_state.hives = [
		HiveDataScript.new(1, Vector2i(3, 6), 1, 9),
		HiveDataScript.new(2, Vector2i(8, 11), 2, 24),
		HiveDataScript.new(3, Vector2i(3, 17), 3, 9)
	]
	var renderer_script: Script = load("res://scripts/renderers/hive_renderer.gd") as Script
	if renderer_script == null:
		push_error("HIVE_GROWTH_TRANSITION_VISUAL_HARNESS: renderer script failed to load")
		quit(1)
		return
	_renderer = renderer_script.new()
	_renderer.name = "HiveRenderer"
	_renderer.position = Vector2(130.0, 110.0)
	_renderer.z_index = 10
	get_root().add_child(_renderer)
	_renderer.setup(_state, null, null)
	_push_authoritative_model()

func _trigger_small_to_medium() -> void:
	_set_power(1, 9)
	_push_authoritative_model()
	_set_power(1, 10)
	_push_authoritative_model()
	_set_status("SMALL → MEDIUM — two rings")

func _trigger_medium_to_large() -> void:
	_set_power(2, 24)
	_push_authoritative_model()
	_set_power(2, 25)
	_push_authoritative_model()
	_set_status("MEDIUM → LARGE — three rings")

func _trigger_small_to_large() -> void:
	_set_power(3, 9)
	_push_authoritative_model()
	_set_power(3, 25)
	_push_authoritative_model()
	_set_status("SMALL → LARGE — three rings")

func _repeat_all() -> void:
	_reset_all()
	call_deferred("_authoritative_fixture_growth")
	_set_status("ALL TRANSITIONS")

func _reset_all() -> void:
	_authoritative_fixture_reset()
	_set_status("RESET")

func _toggle_slow_motion() -> void:
	_slow_motion = not _slow_motion
	Engine.time_scale = 0.25 if _slow_motion else 1.0
	_set_status("SLOW MOTION 0.25×" if _slow_motion else "NORMAL SPEED")

func _authoritative_fixture_growth() -> void:
	_set_power(1, 10)
	_set_power(2, 25)
	_set_power(3, 25)
	_push_authoritative_model()

func _authoritative_fixture_reset() -> void:
	_set_power(1, 9)
	_set_power(2, 24)
	_set_power(3, 9)
	_push_authoritative_model()

func _set_power(hive_id: int, power: int) -> void:
	var hive: HiveData = _state.find_hive_by_id(hive_id)
	if hive != null:
		hive.power = power

func _push_authoritative_model() -> void:
	var hives: Array[Dictionary] = []
	for hive_any in _state.hives:
		var hive: HiveData = hive_any as HiveData
		var tier: int = int(_state.lanes_allowed_for_power(int(hive.power)))
		hives.append({
			"id": int(hive.id),
			"x": float(hive.grid_pos.x),
			"y": float(hive.grid_pos.y),
			"owner_id": int(hive.owner_id),
			"pwr": int(hive.power),
			"growth_tier": tier,
			"lane_budget_used": 0,
			"lane_budget_max": tier,
			"kind": "Hive"
		})
	_renderer.set_model({
		"iid": int(_state.get_instance_id()),
		"cell_size": 64,
		"sim_running": true,
		"hives": hives,
		"lanes": []
	})

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = "%s    speed=%s" % [text, "0.25×" if _slow_motion else "1×"]

func _capture(label: String) -> void:
	var debug_rows: Array = []
	for hive_id in [1, 2, 3]:
		var hive_node: Node = _renderer.call("get_hive_node_by_id", hive_id)
		if hive_node == null:
			continue
		debug_rows.append({
			"hive_id": hive_id,
			"growth": hive_node.call("get_growth_transition_debug_snapshot")
		})
	print("HIVE_GROWTH_CAPTURE_STATE ", label, " ", debug_rows)
	var absolute_dir: String = ProjectSettings.globalize_path(ARTIFACT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image: Image = get_root().get_texture().get_image()
	var path: String = "%s/%s.png" % [absolute_dir, label]
	var err: Error = image.save_png(path)
	if err != OK:
		push_error("HIVE_GROWTH_TRANSITION_VISUAL_HARNESS: capture failed %s (%d)" % [path, int(err)])
