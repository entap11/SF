extends SceneTree

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const TowerSystemScript := preload("res://scripts/systems/tower_system.gd")
const BarracksSystemScript := preload("res://scripts/systems/barracks_system.gd")

const STRUCTURE_MAPS: Array[String] = [
	"res://maps/nomansland/MAP_nomansland__GBASE__TB__1p.json",
	"res://maps/nomansland/MAP_nomansland__GBASE__BR2__TR2__1p.json"
]

func _init() -> void:
	await process_frame

	var failures: Array[String] = []
	for map_path in STRUCTURE_MAPS:
		_check_map(map_path, failures)

	if not failures.is_empty():
		for failure in failures:
			push_error("STRUCTURE_CONTROL_ASSIGNMENT_SMOKE: %s" % failure)
		push_error("STRUCTURE_CONTROL_ASSIGNMENT_SMOKE: %d failure(s)" % failures.size())
		quit(1)
		return

	print("STRUCTURE_CONTROL_ASSIGNMENT_SMOKE: PASS maps=%d" % STRUCTURE_MAPS.size())
	quit(0)

func _check_map(map_path: String, failures: Array[String]) -> void:
	var loaded: Dictionary = MAP_LOADER.load_map(map_path)
	if not bool(loaded.get("ok", false)):
		failures.append("%s failed load: %s" % [map_path, str(loaded.get("err", "unknown"))])
		return
	var model: Dictionary = loaded.get("data", {}) as Dictionary
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	if ops_state == null or not ops_state.has_method("reset_state_from_map"):
		failures.append("%s OpsState reset unavailable" % map_path)
		return
	var state: GameState = ops_state.call("reset_state_from_map", model) as GameState
	var tower_system = TowerSystemScript.new()
	get_root().add_child(tower_system)
	tower_system.bind_state(state)
	var barracks_system = BarracksSystemScript.new()
	get_root().add_child(barracks_system)
	barracks_system.bind_state(state)

	_expect_ids(failures, map_path, "tower", state.towers, 1, [2, 11, 12])
	_expect_ids(failures, map_path, "tower", state.towers, 2, [9, 14, 13])
	_expect_ids(failures, map_path, "barracks", state.barracks, 1, [3, 12, 13])
	_expect_ids(failures, map_path, "barracks", state.barracks, 2, [8, 13, 12])

	tower_system.queue_free()
	barracks_system.queue_free()

func _expect_ids(
	failures: Array[String],
	map_path: String,
	structure_type: String,
	structures: Array,
	structure_id: int,
	expected: Array
) -> void:
	var found: Dictionary = {}
	for structure_any in structures:
		if typeof(structure_any) != TYPE_DICTIONARY:
			continue
		var structure: Dictionary = structure_any as Dictionary
		if int(structure.get("id", -1)) == structure_id:
			found = structure
			break
	if found.is_empty():
		failures.append("%s missing %s %d" % [map_path, structure_type, structure_id])
		return
	var actual_v: Variant = found.get("control_hive_ids", [])
	var actual: Array = actual_v as Array if typeof(actual_v) == TYPE_ARRAY else []
	if not _same_id_set(actual, expected):
		failures.append("%s %s %d control ids expected %s got %s" % [
			map_path,
			structure_type,
			structure_id,
			str(expected),
			str(actual)
		])

func _same_id_set(actual: Array, expected: Array) -> bool:
	var actual_counts: Dictionary = {}
	for id_v in actual:
		var id: int = int(id_v)
		actual_counts[id] = int(actual_counts.get(id, 0)) + 1
	var expected_counts: Dictionary = {}
	for id_v in expected:
		var id: int = int(id_v)
		expected_counts[id] = int(expected_counts.get(id, 0)) + 1
	return actual_counts == expected_counts
