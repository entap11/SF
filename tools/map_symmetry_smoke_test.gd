extends SceneTree
const Layout = preload("res://scripts/maps/map_layout_contract.gd")
const Compiler = preload("res://tools/map_sketch_compile.gd")
const Finalizer = preload("res://tools/map_authoring_finalize_lib.gd")
const Loader = preload("res://scripts/maps/map_loader.gd")
const Geometry = preload("res://scripts/renderers/wall_path_geometry.gd")
const Renderer = preload("res://scripts/renderers/wall_renderer.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("MAP_SYMMETRY: " + message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var draft: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://map_sources/rink_rat_symmetry.draft.json"))
	var input_before := JSON.stringify(draft)
	var compiled: Dictionary = Compiler.compile(draft)
	check(compiled.ok, "pilot compiles: " + str(compiled.get("errors")))
	check(JSON.stringify(draft) == input_before, "compiler never mutates retained source")
	check(JSON.stringify(compiled) == JSON.stringify(Compiler.compile(draft)), "repeat compilation is deterministic")
	var wrong_grid: Dictionary = draft.duplicate(true)
	wrong_grid.grid = {"w": 12, "h": 8}
	check(not Compiler.compile(wrong_grid).ok, "legacy draft coordinates cannot silently change grid scale")
	var data: Dictionary = compiled.data
	var validation: Dictionary = Layout.validate(data)
	check(validation.ok, "pilot has equivalent starts: " + str(validation.errors))
	check(data.nodes.size() == 13, "axis deduplication preserves original 13 hive locations")
	check(Layout.supports_usage(data, "multiplayer").ok and Layout.supports_usage(data, "campaign").ok, "Both classification")
	var bad: Dictionary = data.duplicate(true)
	bad.walls[0].x1 += 0.20
	check(not Layout.validate(bad).ok, "unequal counterpart wall rejected")
	bad = data.duplicate(true)
	bad.walls = [{"x1": "invalid", "y1": 0, "x2": 1, "y2": 1}]
	check(not Layout.validate(bad).ok, "malformed walls cannot silently disappear")
	bad = data.duplicate(true)
	bad.nodes[0].pos.x += 1
	check(not Layout.validate(bad).ok, "shifted hive rejected")
	bad = data.duplicate(true)
	bad.nodes[0].power = 99
	check(not Layout.validate(bad).ok, "unequal starting power rejected")
	bad = data.duplicate(true)
	bad.nodes[4].power = 99
	check(not Layout.validate(bad).ok, "unequal neutral resources rejected")
	bad = data.duplicate(true)
	bad.structure_slots = [{"id": "asymmetric", "pos": {"x": 6, "y": 9}, "allowed": ["tower"]}]
	check(not Layout.validate(bad).ok, "unpaired structure opportunity rejected")
	bad = data.duplicate(true)
	bad.erase("map_usage")
	check(not Layout.validate(bad).ok, "new exports require an explicit bucket")
	check(not Layout.supports_usage(bad, "multiplayer").ok, "legacy is unclassified, never implicitly certified")
	bad = data.duplicate(true)
	bad.map_usage = "campaign"
	bad.nodes[0].power = 99
	check(Layout.validate(bad).ok, "asymmetric campaign encounter permitted")
	check(not Layout.supports_usage(bad, "multiplayer").ok, "campaign-only cannot enter multiplayer bucket")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/_future/rink_rat/MAP_rink_rat__SBASE__4p.json"))
	original.map_usage = "multiplayer"
	original.layout_symmetry = {"kind": "both_mirrors", "center": [9, 14]}
	check(not Layout.validate(original).ok, "old rink top/side starts are inequivalent despite visual symmetry")
	var stroke := PackedVector2Array([Vector2(1, 2), Vector2(3, 3), Vector2(4, 7), Vector2(4, 10)])
	var clean: PackedVector2Array = Compiler.clean_stroke(stroke, true)
	check(clean[0] == stroke[0] and clean[-1] == stroke[-1], "intentional openings retain endpoints")
	var deceptive: Dictionary = draft.duplicate(true)
	deceptive.authoring.wall_strokes[0].points.push_front([5.9, 2.2])
	deceptive.authoring.wall_strokes[0].points.push_front([7.2, 2.0])
	deceptive.authoring.wall_strokes[0].points[-1] = [2, 12]
	var deceptive_result: Dictionary = Finalizer.finalize_map(deceptive)
	check(deceptive_result.ok, "reference-shaped mirrored walls pass geometric checks")
	if deceptive_result.ok:
		var rejected: Dictionary = Finalizer.save_json("user://inequivalent_connections.json", deceptive_result.data)
		check(not rejected.ok and "asymmetric_legal_connection" in str(rejected.err), "mirrored art with unequal actual connections cannot export")
	var finalized: Dictionary = Finalizer.finalize_map(draft)
	check(finalized.ok, "real finalizer accepts pilot: " + str(finalized.get("errors")))
	if finalized.ok:
		var frozen := FileAccess.get_file_as_string("res://maps/_future/rink_rat/MAP_rink_rat__SYMMETRY_PILOT__4p.json")
		check(frozen == JSON.stringify(finalized.data, "  ") + "\n", "checked-in pilot matches its generator and retained draft")
		var saved: Dictionary = Finalizer.save_json("user://MAP_rink_rat__SYMMETRY_PILOT__4p.json", finalized.data)
		check(saved.ok, "atomic export through actual runtime loader: " + str(saved))
		if saved.ok:
			var loaded: Dictionary = Loader.load_authoring_map("user://MAP_rink_rat__SYMMETRY_PILOT__4p.json")
			check(loaded.ok, "runtime accepts exported pilot")
			if loaded.ok:
				check(loaded.data.map_usage == "both", "designation survives runtime conversion")
				await _test_renderer(loaded.data)
		var path := "user://atomic_map_rejection.json"
		var sentinel := FileAccess.open(path, FileAccess.WRITE)
		sentinel.store_string("original map")
		sentinel.close()
		bad = finalized.data.duplicate(true)
		bad.walls[0].x1 += 0.2
		check(not Finalizer.save_json(path, bad).ok, "invalid map cannot be exported directly")
		check(FileAccess.get_file_as_string(path) == "original map", "failed export preserves previous map")
	_test_junctions()
	print("MAP_SYMMETRY_SMOKE: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)

func _test_renderer(model: Dictionary) -> void:
	var state := GameState.new()
	state.load_from_map_dict(model)
	check(Loader._validate_connection_symmetry(model, state).is_empty(), "actual legal connections are equivalent under every symmetry")
	var before := _connections(state)
	var walls_before := JSON.stringify(state.walls)
	var segments: Array = state._wall_segments_world()
	var geometry: Dictionary = Geometry.build(segments)
	check(geometry.paths.size() == 4 and geometry.junctions.is_empty(), "rink produces four continuous walls")
	var renderer := Renderer.new()
	root.add_child(renderer)
	renderer.set_wall_segments(segments)
	check(renderer.get_child_count() == 4, "one ribbon per path, not per tiny segment")
	renderer.notify_blocked_attempt_path(Vector2.ZERO, Vector2(800, 800))
	renderer.tick_visuals(0.4)
	check(_connections(state) == before and JSON.stringify(state.walls) == walls_before, "rendering preserves every gameplay connection and wall")
	segments.reverse()
	renderer.set_wall_segments(segments)
	check(renderer.get_child_count() == 4, "segment ordering does not rebuild or duplicate walls")
	renderer.set_wall_segments([])
	check(renderer.get_child_count() == 0, "map transition clears all old geometry")
	renderer.free()

func _connections(state: GameState) -> Array:
	var out: Array = []
	for a in state.hives:
		for b in state.hives:
			if a.id != b.id: out.append(state.can_connect(a.id, b.id))
	return out

func _test_junctions() -> void:
	var segments := [{"a": Vector2(0, 0), "b": Vector2(1, 0)}, {"a": Vector2(1, 0), "b": Vector2(2, 0)}, {"a": Vector2(1, 0), "b": Vector2(1, 1)}]
	var geometry: Dictionary = Geometry.build(segments)
	check(geometry.paths.size() == 3 and geometry.junctions.size() == 1, "T junction has one shared hub")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/_future/swirly/MAP_swirly__SBASE__4p.json"))
	var swirly: Array = Layout.walls(source)
	geometry = Geometry.build(swirly)
	var edge_count := 0
	for path in geometry.paths: edge_count += path.edges.size()
	check(edge_count == swirly.size(), "Swirly keeps every segment exactly once across curves/junctions")
