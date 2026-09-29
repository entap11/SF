extends SceneTree

const Renderer := preload("res://scripts/renderers/hive_renderer.gd")
const Light := preload("res://scripts/hive/hive_interaction_light.gd")
var failed := false
var renderer: Node2D

func _init() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("HIVE_INTERACTION: " + message)

func model(iid := 1001, owner := 1, power := 8, viewer := 1, count := 1) -> Dictionary:
	var hives: Array = []
	for i in range(count):
		var tier := 3 if power >= 25 else 2 if power >= 10 else 1
		hives.append({"id": i + 1, "x": 2.5 + (i % 4) * 4.0, "y": 3.5 + (i / 4) * 4.0,
			"owner_id": owner, "pwr": power, "growth_tier": tier, "lane_budget_max": tier,
			"lane_budget_used": 0, "hostile_capture_pressure": false, "kind": "Hive"})
	return {"iid": iid, "sim_running": true, "viewer_owner_id": viewer, "cell_size": 64, "hives": hives, "lanes": []}

func effect(hive_id := 1) -> Node2D:
	return renderer.get_hive_node_by_id(hive_id).get_node("Visual/FxLayer/HiveInteractionLight")

func advance(light: Node2D, seconds: float) -> void:
	light.call("_process", seconds)
	light.set_process(false)

func run() -> void:
	renderer = Renderer.new()
	root.add_child(renderer)
	renderer.setup(null, null, null)
	await process_frame
	renderer.set_model(model())
	var light := effect()
	var material_id := light.material.get_instance_id()
	expect(light.get_debug_snapshot().capture_serial == 0, "initial map must seed silently")
	renderer.set_selected_hive(1, Color.WHITE)
	advance(light, 0.12)
	expect(is_equal_approx(light.get_debug_snapshot().selection, 1.0), "selection must seat promptly")
	renderer.set_selected_hive(1, Color.WHITE)
	expect(is_equal_approx(light.get_debug_snapshot().selection, 1.0), "duplicate selection must not restart the marker")
	var input := model(1001, 2, 7)
	var before := input.duplicate(true)
	renderer.set_model(input)
	expect(input == before, "presentation must not mutate canonical samples")
	expect(light.get_debug_snapshot().capture_serial == 1, "one ownership edge produces one capture")
	expect(renderer.get_hive_node_by_id(1).owner_id == 2 and renderer.get_hive_node_by_id(1).power == 7,
		"owner and power must be canonical immediately")
	renderer.set_model(input)
	expect(light.get_debug_snapshot().capture_serial == 1, "repeated snapshots must not replay capture")
	advance(light, 0.18)
	expect(light.get_debug_snapshot().capture_energy > 0.0 and light.get_debug_snapshot().selection == 1.0,
		"capture and held selection must coexist")
	renderer.clear_selected_hive()
	advance(light, 0.10)
	expect(is_zero_approx(light.get_debug_snapshot().selection), "deselection must clear without lingering")
	advance(light, 0.5)
	expect(not light.visible and not light.is_processing(), "finished effects must become invisible and idle")
	expect(light.get_child_count() == 0 and light.material.get_instance_id() == material_id, "effects must reuse one material and no child nodes")

	# Ownership switches replace the existing sweep; neutralization does not invent a capture.
	renderer.set_model(model(1001, 1, 7))
	advance(light, 0.10)
	renderer.set_model(model(1001, 3, 7))
	expect(light.get_debug_snapshot().capture_serial == 3 and light.get_debug_snapshot().capture_progress == 0.0,
		"rapid recapture must replace the previous owner's sweep")
	renderer.set_model(model(1001, 0, 7))
	expect(not light.get_debug_snapshot().capture_active, "neutralization must clear the old capture")
	renderer.set_model(model(1001, 1, 7))
	expect(light.get_debug_snapshot().capture_serial == 4, "neutral to player is a real capture")
	renderer.set_model(model(1002, 2, 7))
	expect(not light.get_debug_snapshot().capture_active and light.get_debug_snapshot().capture_serial == 4,
		"match identity changes must reseed without capture")
	renderer.set_model(model(1002, 1, 7, 2))
	expect(not light.get_debug_snapshot().capture_active, "viewer switches must reseed without capture")
	renderer.set_model(model(1002, 2, 7, 2))
	expect(light.get_debug_snapshot().capture_active, "later canonical edge must resume")
	renderer.call("_on_app_backgrounded", "test", 0, 0)
	expect(not light.get_debug_snapshot().capture_active, "backgrounding cancels transient capture")
	renderer.call("_on_app_foregrounded", "test", 0, 0)
	renderer.set_model(model(1002, 2, 7, 2))
	expect(not light.get_debug_snapshot().capture_active, "foreground must not replay history")
	renderer.set_model(model(1002, 1, 7, 2))
	renderer.set_model(model(1002, 1, 10, 2))
	expect(not light.get_debug_snapshot().capture_active, "growth takes over from a capture sweep")

	# Reduced/static mode keeps selection decisive and never resumes an old sweep.
	var profile := root.get_node("ProfileManager")
	var previous_preference: bool = profile.is_gpu_vfx_enabled()
	profile.set_gpu_vfx_enabled(false)
	renderer.set_model(model(1003, 1, 7))
	renderer.set_model(model(1003, 2, 7))
	advance(light, 0.08)
	expect(light.get_debug_snapshot().mode == "reduced" and light.get_debug_snapshot().capture_progress == 0.0,
		"reduced capture is a stationary confirmation")
	renderer.set_selected_hive(1, Color.WHITE)
	expect(light.get_debug_snapshot().selection == 1.0, "reduced selection must be immediate")
	renderer.animations_enabled = false
	renderer.set_model(model(1003, 1, 7))
	expect(not light.get_debug_snapshot().capture_active and light.get_debug_snapshot().selection == 1.0,
		"disabled motion retains selection without a capture animation")
	renderer.animations_enabled = true
	profile.set_gpu_vfx_enabled(previous_preference)
	renderer.set_model(model(1003, 1, 7))
	expect(not light.get_debug_snapshot().capture_active, "enabling animation must not replay a completed edge")

	# Admission is stable even if simultaneous canonical samples arrive reordered.
	renderer.clear_selected_hive()
	renderer.set_model(model(2001, 1, 8, 1, 10))
	var batch := model(2001, 2, 8, 1, 10)
	batch.hives.reverse()
	renderer.set_model(batch)
	for hive_id in range(1, 11):
		var pose: Dictionary = effect(hive_id).get_debug_snapshot()
		expect(pose.capture_active and pose.mode == ("full" if hive_id <= 6 else "reduced"),
			"simultaneous captures must use stable, bounded detail")
	renderer.set_model(batch)
	expect(effect(10).get_debug_snapshot().mode == "reduced" and effect(10).get_debug_snapshot().capture_active,
		"overflow confirmation must survive duplicate samples")
	renderer.clear_all()
	await process_frame
	expect(renderer.get_hive_ids().is_empty(), "cleanup must release every interaction component")
	renderer.set_model(model(3001, 3, 8))
	expect(effect().get_debug_snapshot().capture_serial == 0, "reconstructed nodes must seed silently")

	# Elapsed-time sampling is independent of presentation update frequency.
	var a := Light.new()
	var b := Light.new()
	root.add_child(a)
	root.add_child(b)
	for item in [a, b]:
		item.configure(Vector2.ZERO, Vector2(100, 120), Color.GOLD, "full", 1.0)
		item.set_selected(true)
		item.play_capture()
	advance(a, 0.23)
	for i in range(23):
		advance(b, 0.01)
	for key in ["selection", "capture_progress", "capture_energy"]:
		expect(is_equal_approx(a.get_debug_snapshot()[key], b.get_debug_snapshot()[key]), "elapsed sampling must match for " + key)
	a.free()
	b.free()
	renderer.clear_all()
	renderer.queue_free()
	await process_frame
	print("HIVE_INTERACTION_LIGHT_SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
