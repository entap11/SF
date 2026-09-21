extends SceneTree
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("MAP_STUDIO: " + message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1100, 1400)
	root.content_scale_size = Vector2i(1100, 1400)
	var scene: PackedScene = load("res://addons/map_sketch_tracer/tracer_dock.tscn")
	var studio: Control = scene.instantiate()
	root.add_child(studio)
	await process_frame
	var canvas: Control = studio.canvas
	check(canvas.load_draft("res://map_sources/rink_rat_symmetry.draft.json"), "open retained pilot")
	check(canvas.validate_map().ok, "studio export shares finalizer symmetry check")
	var before: String = JSON.stringify(canvas.draft)
	canvas._checkpoint()
	canvas.draft.nodes[0].power = 99
	canvas._changed()
	# One seed is changed, so ALL counterpart starts must receive the same power.
	check(canvas.validate_map().ok, "single-sector power edit keeps all starts equivalent")
	canvas.undo()
	check(JSON.stringify(canvas.draft) == before, "Undo restores retained source")
	canvas.redo()
	check(canvas.draft.nodes[0].power == 99, "Redo restores edit")
	canvas.undo()
	canvas.show_connections = true
	canvas._refresh()
	check(not canvas._connections.is_empty(), "actual gameplay connection preview")
	canvas.preview_mode = "finished"
	canvas.show_barriers = false
	canvas.queue_redraw()
	await process_frame
	await process_frame
	check(canvas._walls.get_child_count() == 4, "finished preview uses four runtime wall ribbons")
	check(canvas.save_draft("user://studio_roundtrip.draft.json"), "save draft")
	check(canvas.load_draft("user://studio_roundtrip.draft.json"), "reopen draft")
	check(JSON.stringify(canvas.draft) == before, "draft roundtrip preserves editable source")
	check(canvas.export_json_to_path("user://studio_compiled.json"), "studio exports through actual runtime validation")
	canvas.set_policy("multiplayer", "none")
	check(not canvas.validate_map().ok, "multiplayer cannot export with symmetry disabled")
	canvas.load_draft("res://map_sources/rink_rat_symmetry.draft.json")
	var capture_dir: String = OS.get_environment("SF_MAP_AUTHORING_CAPTURE_DIR")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		for frame in range(5): await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(capture_dir.path_join("map-studio.png"))
	print("MAP_STUDIO_SMOKE: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)
