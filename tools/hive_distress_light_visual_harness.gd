extends SceneTree

const HiveRendererScript := preload("res://scripts/renderers/hive_renderer.gd")
const HiveGrowthRules := preload("res://scripts/sim/hive_growth_rules.gd")
const ARTIFACT_DIR: String = "res://artifacts/hive_distress_light"

var _renderer: Node2D = null
var _status: Label = null
var _iid: int = 7001

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1080, 1920)
	_build_background()
	_build_dense_traffic()
	_renderer = HiveRendererScript.new()
	_renderer.name = "HiveRenderer"
	_renderer.position = Vector2(30.0, 180.0)
	get_root().add_child(_renderer)
	_renderer.call("setup", null, null, null)
	await process_frame
	await process_frame

	_set_status("MINOR RUPTURE — large to medium")
	await _begin_scenario([_hive(1, 6.7, 8.5, 1, 30, false)])
	_set_hives([_hive(1, 6.7, 8.5, 1, 24, false)])
	await process_frame
	_set_debug_phase(1, 0.12)
	_capture("01_minor_flash")
	_set_debug_phase(1, 0.46)
	_capture("02_minor_peak")

	_set_status("MAJOR COLLAPSE — medium to small")
	await _begin_scenario([_hive(1, 6.7, 8.5, 1, 11, false)])
	_set_hives([_hive(1, 6.7, 8.5, 1, 9, false)])
	await process_frame
	_set_debug_phase(1, 0.12)
	_capture("03_major_flash")
	_set_debug_phase(1, 0.44)
	_capture("04_major_peak")

	_set_status("PRESSURE ENTRY — hostile 6 to 5")
	await _begin_scenario([_hive(1, 6.7, 8.5, 1, 6, true)])
	_set_hives([_hive(1, 6.7, 8.5, 1, 5, true)])
	await process_frame
	_set_debug_phase(1, 0.40)
	_capture("05_pressure_entry")
	_set_status("PRESSURE SURGE — bounded emission during active decline")
	_set_debug_phase(1, 1.0, 0.48, 4)
	_capture("06_pressure_strong_surge")

	_set_status("VIEWER RELATIVE — only P1 receives pressure presentation")
	await _begin_scenario([
		_hive(1, 2.5, 8.5, 1, 6, true),
		_hive(2, 11.0, 8.5, 2, 6, true)
	])
	_set_hives([
		_hive(1, 2.5, 8.5, 1, 5, true),
		_hive(2, 11.0, 8.5, 2, 5, true)
	])
	await process_frame
	_capture("07_viewer_relative")

	_set_status("MULTIPLE DECLINING HIVES — bounded simultaneous effects")
	await _begin_scenario([
		_hive(1, 2.5, 4.5, 1, 6, true),
		_hive(2, 11.0, 4.5, 1, 6, true),
		_hive(3, 2.5, 13.5, 1, 6, true),
		_hive(4, 11.0, 13.5, 2, 6, true)
	])
	_set_hives([
		_hive(1, 2.5, 4.5, 1, 5, true),
		_hive(2, 11.0, 4.5, 1, 4, true),
		_hive(3, 2.5, 13.5, 1, 3, true),
		_hive(4, 11.0, 13.5, 2, 3, true)
	])
	await process_frame
	for hive_id in [1, 2, 3]:
		_set_debug_phase(hive_id, -1.0, 0.52, 4)
	_capture("08_multiple_pressure")

	_renderer.set("animations_enabled", false)
	_set_status("ANIMATION DISABLED — static active-pressure treatment")
	await _begin_scenario([_hive(1, 6.7, 8.5, 1, 6, true)])
	_set_hives([_hive(1, 6.7, 8.5, 1, 5, true)])
	await process_frame
	_capture("09_static_motion_mode")
	_renderer.set("animations_enabled", true)

	_set_status("CAPTURE PRECEDENCE — pressure clears immediately")
	await _begin_scenario([_hive(1, 6.7, 8.5, 1, 6, true)])
	_set_hives([_hive(1, 6.7, 8.5, 1, 5, true)])
	await process_frame
	_set_hives([_hive(1, 6.7, 8.5, 2, 1, true)])
	await process_frame
	_capture("10_capture_precedence")

	_set_status("STABLE LOW POWER — bounded hold fully clears")
	await _begin_scenario([_hive(1, 6.7, 8.5, 1, 6, true)])
	_set_hives([_hive(1, 6.7, 8.5, 1, 5, true)])
	await process_frame
	_set_hives([_hive(1, 6.7, 8.5, 1, 5, true)])
	await create_timer(0.90).timeout
	_capture("11_stable_low_cleared")

	print("HIVE_DISTRESS_LIGHT_VISUAL_HARNESS: CAPTURED")
	quit(0)


func _begin_scenario(hives: Array[Dictionary]) -> void:
	_iid += 1
	_set_hives(hives)
	await process_frame
	await create_timer(0.14).timeout

func _set_hives(hives: Array[Dictionary]) -> void:
	_renderer.call("set_model", {
		"iid": _iid,
		"cell_size": 64,
		"sim_running": true,
		"viewer_owner_id": 1,
		"hives": hives,
		"lanes": []
	})

func _set_debug_phase(
	hive_id: int,
	burst_progress: float,
	surge_progress: float = -1.0,
	pulse_index: int = 1
) -> void:
	var hive_node: Node = _renderer.call("get_hive_node_by_id", hive_id) as Node
	if hive_node == null:
		return
	var component: Node = hive_node.get_node_or_null("Visual/FxLayer/HiveDistressLight")
	if component != null and component.has_method("set_debug_presentation_phase"):
		component.call(
			"set_debug_presentation_phase",
			burst_progress,
			surge_progress,
			pulse_index
		)

func _hive(
	id: int,
	x: float,
	y: float,
	owner_id: int,
	power: int,
	pressure: bool,
	tier_override: int = 0
) -> Dictionary:
	var tier: int = HiveGrowthRules.tier_for_power(power) if tier_override <= 0 else tier_override
	return {
		"id": id,
		"x": x,
		"y": y,
		"owner_id": owner_id,
		"pwr": power,
		"growth_tier": tier,
		"lane_budget_used": 0,
		"lane_budget_max": tier,
		"hostile_capture_pressure": pressure,
		"kind": "Hive" if owner_id > 0 else "npc_hive"
	}

func _build_background() -> void:
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(1080.0, 1920.0)
	background.color = Color(0.018, 0.026, 0.045, 1.0)
	background.z_index = -100
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_root().add_child(background)
	for x in range(0, 1081, 64):
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x, 170), Vector2(x, 1840)])
		line.width = 1.0
		line.default_color = Color(0.18, 0.34, 0.50, 0.12)
		line.z_index = -90
		get_root().add_child(line)
	for y in range(170, 1841, 64):
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(0, y), Vector2(1080, y)])
		line.width = 1.0
		line.default_color = Color(0.18, 0.34, 0.50, 0.12)
		line.z_index = -90
		get_root().add_child(line)
	var title := Label.new()
	title.position = Vector2(42.0, 34.0)
	title.text = "HIVE TIER RUPTURE / ACTIVE PRESSURE"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0, 1.0))
	get_root().add_child(title)
	_status = Label.new()
	_status.position = Vector2(44.0, 86.0)
	_status.size = Vector2(990.0, 70.0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Color(1.0, 0.82, 0.40, 1.0))
	get_root().add_child(_status)

func _build_dense_traffic() -> void:
	var routes: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(100, 520), Vector2(970, 820)]),
		PackedVector2Array([Vector2(140, 1420), Vector2(920, 620)]),
		PackedVector2Array([Vector2(80, 1020), Vector2(990, 1180)])
	]
	for route in routes:
		var lane := Line2D.new()
		lane.points = route
		lane.width = 16.0
		lane.default_color = Color(0.16, 0.50, 0.78, 0.20)
		lane.z_index = -35
		get_root().add_child(lane)
		var core := Line2D.new()
		core.points = route
		core.width = 2.0
		core.default_color = Color(0.58, 0.86, 1.0, 0.56)
		core.z_index = -34
		get_root().add_child(core)
	for i in range(42):
		var bee := Polygon2D.new()
		var lane_index: int = i % routes.size()
		var t: float = float((i * 19) % 100) / 100.0
		bee.position = routes[lane_index][0].lerp(routes[lane_index][1], t)
		bee.polygon = PackedVector2Array([
			Vector2(0, -6), Vector2(5, 3), Vector2(0, 7), Vector2(-5, 3)
		])
		bee.color = Color(0.76, 0.92, 1.0, 0.72) if i % 3 else Color(1.0, 0.35, 0.32, 0.72)
		bee.z_index = -8
		get_root().add_child(bee)

func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text

func _capture(filename: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(ARTIFACT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var viewport_texture: ViewportTexture = get_root().get_texture()
	if viewport_texture == null:
		push_warning("HIVE_DISTRESS_LIGHT_VISUAL_HARNESS: capture unavailable for the active display driver")
		return
	var image: Image = viewport_texture.get_image()
	if image == null:
		push_warning("HIVE_DISTRESS_LIGHT_VISUAL_HARNESS: viewport returned no image")
		return
	var path: String = "%s/%s.png" % [absolute_dir, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("HIVE_DISTRESS_LIGHT_VISUAL_HARNESS: capture failed %s (%d)" % [path, int(error)])
	var debug: Dictionary = _renderer.call("get_distress_debug_snapshot") as Dictionary
	print("HIVE_DISTRESS_CAPTURE ", filename, " ", debug)
