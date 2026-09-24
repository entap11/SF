extends SceneTree
## Native presentation fixture, separate from the live-match evidence.
const Renderer := preload("res://scripts/renderers/hive_renderer.gd")
const FontAsset := preload("res://assets/fonts/brand/Iceland/Iceland-Regular.ttf")
var renderer: Node2D
var caption: Label
var output: String

func _init() -> void:
	call_deferred("run")

func label(text: String, at: Vector2, size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.add_theme_font_override("font", FontAsset)
	node.add_theme_font_size_override("font_size", size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(node)
	return node

func model(owner: int) -> Dictionary:
	var hives: Array = []
	for i in range(6):
		var tier := 1 + i % 3
		hives.append({"id": i + 1, "x": (260.0 + 450.0 * (i % 3)) / 64.0,
			"y": (365.0 if i < 3 else 775.0) / 64.0,
			"owner_id": 1 if i < 3 else owner, "pwr": [8, 18, 30][i % 3],
			"growth_tier": tier, "lane_budget_used": 1, "lane_budget_max": tier,
			"hostile_capture_pressure": false, "kind": "Hive"})
	return {"iid": 9001, "sim_running": true, "viewer_owner_id": 1, "cell_size": 64, "hives": hives, "lanes": []}

func run() -> void:
	output = OS.get_environment("SF_PRESSURE_MATCH_OUTPUT")
	if DisplayServer.get_name() == "headless" or output.is_empty():
		push_error("Run the native interaction fixture through run_hive_pressure_checks.py --capture")
		quit(2)
		return
	root.size = Vector2i(1440, 1000)
	root.content_scale_size = Vector2i(1440, 1000)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	RenderingServer.set_default_clear_color(Color(0.035, 0.047, 0.060))
	label("SWARMFRONT / SELECTION & CAPTURE", Vector2(60, 34), 28)
	caption = label("", Vector2(60, 82), 43)
	label("SELECTION / Steady ivory brackets. Team color stays visible.", Vector2(60, 156), 28)
	label("CAPTURE / One fitted sweep confirms the new owner.", Vector2(60, 552), 28)
	for i in range(3):
		label(["SMALL", "MEDIUM", "LARGE"][i], Vector2(220 + 450 * i, 467), 25)
	label("Presentation fixture / canonical sample inputs / physical-phone profiling pending", Vector2(60, 947), 24)
	renderer = Renderer.new()
	root.add_child(renderer)
	renderer.setup(null, null, null)
	await process_frame
	var profile := root.get_node("ProfileManager")
	var preference: bool = profile.is_gpu_vfx_enabled()
	for mode in ["full", "reduced", "none"]:
		renderer.clear_all()
		await process_frame
		profile.set_gpu_vfx_enabled(mode != "reduced")
		renderer.animations_enabled = mode != "none"
		renderer.set_model(model(1))
		renderer.set_model(model(2))
		for id in renderer.get_hive_ids():
			var hive: Node = renderer.get_hive_node_by_id(id)
			# Three simultaneous selections are display examples, not a live input state.
			if id <= 3:
				hive.call("set_selected", true, Color.WHITE)
			var light: Node = hive.get_node("Visual/FxLayer/HiveInteractionLight")
			light.call("_process", 0.18 if mode == "full" else 0.08)
			light.set_process(false)
		caption.text = {"full": "Quick lock. Clean ownership confirmation.", "reduced": "Reduced motion / stationary capture confirmation", "none": "Animations disabled / steady selection, immediate owner color"}[mode]
		await process_frame
		RenderingServer.force_draw(false)
		var result := root.get_texture().get_image().save_png(output.path_join(mode + ".png"))
		if result != OK:
			push_error("Interaction fixture capture failed")
			quit(1)
			return
	profile.set_gpu_vfx_enabled(preference)
	renderer.clear_all()
	renderer.queue_free()
	await process_frame
	print("HIVE_INTERACTION_VISUAL_HARNESS: PASS")
	quit()
