extends SceneTree

const HiveRendererScript := preload("res://scripts/renderers/hive_renderer.gd")
const HiveGrowthRules := preload("res://scripts/sim/hive_growth_rules.gd")
const ARTIFACT_DIR: String = "res://artifacts/hive_growth_transition"

var _renderer: Node2D = null
var _background: ColorRect = null
var _status: Label = null
var _iid: int = 8100
var _capture_once: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_capture_once = "--capture" in OS.get_cmdline_user_args()
	get_root().size = Vector2i(1080, 1920)
	get_root().window_input.connect(_on_window_input)
	_build_stage()
	_renderer = HiveRendererScript.new()
	_renderer.name = "HiveRenderer"
	_renderer.position = Vector2(30.0, 180.0)
	get_root().add_child(_renderer)
	_renderer.call("setup", null, null, null)
	await process_frame
	await process_frame
	if not _capture_once:
		_set_status("READY — 1 small→medium, 2 medium→large, 3 bright-field review, Esc exit")
		return

	_set_status("P1 SMALL → MEDIUM — first ring spawn")
	await _begin_growth(1, 9, 10)
	_set_ring_phase(0, 0.08)
	await _capture("01_p1_small_medium_spawn")
	_set_status("P1 SMALL → MEDIUM — first ring peak")
	_set_ring_phase(0, 0.38)
	await _capture("02_p1_small_medium_peak")
	_set_status("P1 SMALL → MEDIUM — final reveal ring")
	_set_ring_phase(1, 0.46)
	await _capture("03_p1_small_medium_final")

	_set_status("P2 MEDIUM → LARGE — three-ring final peak")
	await _begin_growth(2, 24, 25)
	_set_ring_phase(2, 0.46)
	await _capture("04_p2_medium_large_final")

	_background.color = Color(0.46, 0.50, 0.54, 1.0)
	_set_status("BRIGHT BATTLEFIELD — emissive bands remain distinct")
	await _begin_growth(1, 24, 25)
	_set_ring_phase(2, 0.46)
	await _capture("05_bright_battlefield_final")

	_background.color = Color(0.018, 0.026, 0.045, 1.0)
	_set_status("LOWER-COST PATH — one fixed reduced ring")
	await _begin_growth(1, 9, 10)
	var transition: Node = _transition()
	if transition != null:
		transition.call("cancel_and_reveal_final", "visual_harness_reduced", false)
		transition.call(
			"play",
			Vector2(104.0, 126.0),
			Vector2.ZERO,
			Color(0.32, 0.74, 1.0, 1.0),
			HiveGrowthRules.TIER_SMALL,
			HiveGrowthRules.TIER_MEDIUM,
			{},
			"reduced"
		)
		transition.call("set_debug_ring_phase", 0, 0.46)
	await _capture("06_reduced_motion_ring")

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
			_background.color = Color(0.018, 0.026, 0.045, 1.0)
			_set_status("P1 SMALL → MEDIUM")
			_begin_growth(1, 9, 10)
		KEY_2:
			_background.color = Color(0.018, 0.026, 0.045, 1.0)
			_set_status("P2 MEDIUM → LARGE")
			_begin_growth(2, 24, 25)
		KEY_3:
			_background.color = Color(0.46, 0.50, 0.54, 1.0)
			_set_status("BRIGHT BATTLEFIELD — P1 MEDIUM → LARGE")
			_begin_growth(1, 24, 25)
		KEY_ESCAPE:
			quit(0)

func _begin_growth(owner_id: int, old_power: int, new_power: int) -> void:
	_iid += 1
	_set_model(owner_id, old_power)
	await process_frame
	await create_timer(0.06).timeout
	_set_model(owner_id, new_power)
	await process_frame

func _set_model(owner_id: int, power: int) -> void:
	var tier: int = HiveGrowthRules.tier_for_power(power)
	_renderer.call("set_model", {
		"iid": _iid,
		"cell_size": 64,
		"sim_running": true,
		"viewer_owner_id": 1,
		"hives": [{
			"id": 1,
			"x": 7.6,
			"y": 12.0,
			"owner_id": owner_id,
			"pwr": power,
			"growth_tier": tier,
			"lane_budget_used": 0,
			"lane_budget_max": HiveGrowthRules.lane_budget_for_power(power),
			"hostile_capture_pressure": false,
			"kind": "Hive"
		}],
		"lanes": []
	})

func _transition() -> Node:
	var hive: Node = _renderer.call("get_hive_node_by_id", 1) as Node
	if hive == null:
		return null
	return hive.get_node_or_null("Visual/FxLayer/HiveGrowthTransition")

func _set_ring_phase(index: int, progress: float) -> void:
	var transition: Node = _transition()
	if transition != null and transition.has_method("set_debug_ring_phase"):
		transition.call("set_debug_ring_phase", index, progress)

func _build_stage() -> void:
	_background = ColorRect.new()
	_background.position = Vector2.ZERO
	_background.size = Vector2(1080.0, 1920.0)
	_background.color = Color(0.018, 0.026, 0.045, 1.0)
	_background.z_index = -100
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_root().add_child(_background)
	for x in range(0, 1081, 64):
		var vertical := Line2D.new()
		vertical.points = PackedVector2Array([Vector2(x, 170), Vector2(x, 1840)])
		vertical.width = 1.0
		vertical.default_color = Color(0.18, 0.34, 0.50, 0.16)
		vertical.z_index = -90
		get_root().add_child(vertical)
	for y in range(170, 1841, 64):
		var horizontal := Line2D.new()
		horizontal.points = PackedVector2Array([Vector2(0, y), Vector2(1080, y)])
		horizontal.width = 1.0
		horizontal.default_color = Color(0.18, 0.34, 0.50, 0.16)
		horizontal.z_index = -90
		get_root().add_child(horizontal)
	var title := Label.new()
	title.position = Vector2(42.0, 34.0)
	title.text = "HIVE GROWTH-RING FIXED-PHASE HARNESS"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0, 1.0))
	get_root().add_child(title)
	_status = Label.new()
	_status.position = Vector2(44.0, 86.0)
	_status.size = Vector2(990.0, 70.0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Color(1.0, 0.82, 0.40, 1.0))
	get_root().add_child(_status)

func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text

func _capture(filename: String) -> void:
	await process_frame
	var absolute_dir: String = ProjectSettings.globalize_path(ARTIFACT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var viewport_texture: ViewportTexture = get_root().get_texture()
	if viewport_texture == null:
		push_warning("HIVE_GROWTH_TRANSITION_VISUAL_HARNESS: capture unavailable for the active display driver")
		return
	var image: Image = viewport_texture.get_image()
	if image == null:
		push_warning("HIVE_GROWTH_TRANSITION_VISUAL_HARNESS: viewport returned no image")
		return
	var path: String = "%s/%s.png" % [absolute_dir, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("HIVE_GROWTH_TRANSITION_VISUAL_HARNESS: capture failed %s (%d)" % [path, int(error)])
	var transition: Node = _transition()
	var debug: Dictionary = transition.call("get_debug_snapshot") as Dictionary if transition != null else {}
	print("HIVE_GROWTH_CAPTURE ", filename, " ", debug)
