extends SceneTree
const Loader = preload("res://scripts/maps/map_loader.gd")
const Layout = preload("res://scripts/maps/map_layout_contract.gd")
const Setup = preload("res://scripts/state/match_setup_randomizer.gd")
const Compiler = preload("res://tools/map_sketch_compile.gd")
var failures: Array[String] = []
var checked_setups := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("SIMPLE_SYRUP_MAP: " + message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var original: Dictionary = Loader.load_map("res://maps/simple_syrup/MAP_simple_syrup__TB__1p.json").data
	var original_positions := _positions(original)
	var baseline := GameState.new()
	baseline.load_from_map_dict(original)
	var baseline_graph := _graph(baseline)
	for region in ["START", "CENTER"]:
		for suffix in ["T", "B"]:
			var path := "res://maps/_future/simple_syrup/MAP_simple_syrup__%s_%s__1p.json" % [region, suffix]
			var loaded: Dictionary = Loader.load_authoring_map(path)
			check(loaded.ok, "candidate loads: " + path + " " + str(loaded.err))
			if not loaded.ok: continue
			var model: Dictionary = loaded.data
			check(_positions(model) == original_positions, "all seven original fractional hive positions retained")
			check(Layout.validate(model).ok, "normalized structures and control groups preserve player symmetry")
			check(model.structure_slots.size() == 2, "one paired opportunity per player")
			var state := GameState.new()
			state.load_from_map_dict(model)
			check(_graph(state) == baseline_graph, "structure placement does not alter the hive connection graph")
			check(Loader._validate_connection_symmetry(model, state).is_empty(), "runtime uses preserved fractional positions")
			var expected: Array = [1, 2, 3] if region == "START" else [2, 3, 4]
			var expected_top: Array = [5, 6, 7] if region == "START" else [4, 5, 6]
			var tower_system := TowerSystem.new()
			var barracks_system := BarracksSystem.new()
			root.add_child(tower_system)
			root.add_child(barracks_system)
			tower_system.bind_state(state)
			barracks_system.bind_state(state)
			for rows in [model.towers, model.barracks, state.towers, state.barracks]:
				for row in rows:
					var ids: Array = row.control_hive_ids.duplicate()
					ids.sort()
					check(ids == (expected if row.grid_pos[1] > 13.5 else expected_top), "authored triangle survives compact import and simulation binding")
			for row in state.towers + state.barracks:
				var bottom: bool = row.grid_pos[1] > 13.5
				var center_y: float = (20.0 if bottom else 7.0) if region == "START" else (16.5 if bottom else 10.5)
				var expected_center := state._grid_coord_to_world(Vector2(8.5, center_y))
				var actual_center: Vector2 = tower_system._tower_center_pos(row) if suffix == "T" else barracks_system._barracks_center_pos(row)
				check(actual_center.distance_to(expected_center) < 0.0001, "simulation structure center preserves fractional controlling hives")
			tower_system.free()
			barracks_system.free()
			for slot in model.structure_slots:
				if slot.grid_pos[1] > 13.5:
					check(slot.control_hive_ids == expected, "bottom triangle controls are exact")
				check(slot.get("symmetry_group", "") == "syrup_%s_pair" % region.to_lower(), "paired type group survives import")
			for kind in ["tower", "barracks", "mixed"]:
				for seed_value in range(1, 13):
					var payload := {"hit": true, "seed": seed_value, "structures": {"kind": kind}, "categories": {"tower_power": 10, "barracks_power": 20}}
					var source_before := JSON.stringify(model)
					var resolved: Dictionary = Setup.apply_to_map_data(model, payload)
					check(JSON.stringify(model) == source_before, "setup leaves map source unchanged")
					check(Layout.validate(resolved).ok, "resolved %s setup remains symmetric seed=%d" % [kind, seed_value])
					check(resolved.towers.size() == 2 or resolved.barracks.size() == 2, "mixed selection respects paired types")
					check(JSON.stringify(resolved) == JSON.stringify(Setup.apply_to_map_data(model, payload)), "setup is deterministic")
					var swapped: Dictionary = Setup.apply_start_slots(resolved, {"seed": seed_value}, [1, 2])
					check(Layout.validate(swapped).ok, "both start assignments preserve structure equivalence")
					check(Loader._validate_opening_lane_availability(swapped).ok, "resolved actual graph preserves symmetry")
					checked_setups += 1
			var bad: Dictionary = model.duplicate(true)
			bad.structure_slots[0].symmetry_group = "unpaired"
			check(not Layout.validate(bad).ok, "unpaired type randomization group rejected")
			bad = model.duplicate(true)
			var structures: Array = bad.towers if suffix == "T" else bad.barracks
			structures[0].control_hive_ids = [1, 4, 7]
			check(not Layout.validate(bad).ok, "mismatched structure control triangle rejected")
			# Setup mixed selection is independent of allowed-array order within a group.
			var slots: Array = model.structure_slots
			var reversed: Dictionary = slots[1].duplicate(true)
			reversed.allowed.reverse()
			for seed_value in range(1, 13):
				check(Setup._structure_kind_for_slot(slots[0], "mixed", seed_value, 0) == Setup._structure_kind_for_slot(reversed, "mixed", seed_value, 1), "paired allowed ordering cannot bias type")
	_test_intake()
	print("SIMPLE_SYRUP_MAP_SMOKE: %s setups=%d" % ["PASS" if failures.is_empty() else "FAIL " + str(failures), checked_setups])
	quit(0 if failures.is_empty() else 1)

func _positions(model: Dictionary) -> Array:
	var out: Array = []
	for h in model.hives: out.append([h.id, h.grid_pos])
	return out

func _graph(state: GameState) -> Array:
	var out: Array = []
	for a in state.hives:
		for b in state.hives:
			out.append(state.can_connect(a.id, b.id))
	return out

func _test_intake() -> void:
	check(Loader._resolve_hive_id_list([1.0, 2.0, 3.0], {"1": 1, "2": 2, "3": 3}) == [1, 2, 3], "JSON numeric structure references survive string hive IDs")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://map_sources/simple_syrup_start.draft.json"))
	var compiled: Dictionary = Compiler.compile(source).data
	check(Layout.validate(compiled).ok, "native half-cell source supported")
	var powered: Dictionary = compiled.duplicate(true)
	for node in powered.nodes:
		if node.kind == "tower":
			node.power = 17
			node.current_power = 12
	var expanded: Dictionary = Loader._expand_v1xy_compact_if_needed(powered, "syrup_power_roundtrip")
	var powered_model: Dictionary = Loader._load_v1xy(expanded, "syrup_power_roundtrip")
	for tower in powered_model.towers:
		check(tower.power == 17 and tower.current_power == 12, "compact structure powers survive conversion")
	var bad: Dictionary = compiled.duplicate(true)
	bad.nodes[0].pos.x = 18
	check(not Layout.validate(bad).ok, "x=18 is rejected before an entity can silently disappear")
	bad = compiled.duplicate(true)
	bad.nodes[0].pos.y = 28
	check(not Layout.validate(bad).ok, "y=28 is rejected before an entity can silently disappear")
	bad = compiled.duplicate(true)
	bad.nodes[0].pos.x = 8.25
	check(not Layout.validate(bad).ok, "unsupported quarter-cell source rejected explicitly")
	bad = compiled.duplicate(true)
	for node in bad.nodes:
		if node.kind == "tower":
			node.power = 99
			break
	check(not Layout.validate(bad).ok, "entity-authored unequal structures rejected before export")
	# Cell (0,0) is a cell center, half a cell inside the drawing border.
	var Canvas = preload("res://addons/map_sketch_tracer/tracer_canvas.gd")
	var canvas = Canvas.new()
	canvas.size = Vector2(720, 1120)
	var pixel: Vector2 = canvas._screen(Vector2(17, 27))
	check(canvas._grid(pixel).distance_to(Vector2(17, 27)) < 0.00001, "drawing and studio coordinates round-trip at far valid cell")
	check(canvas._grid(canvas._origin()).distance_to(Vector2(-0.5, -0.5)) < 0.00001, "drawing border is not the first cell center")
	canvas.free()
