class_name PerfFixtureValidator
extends RefCounted

const MapLoader := preload("res://scripts/maps/map_loader.gd")

const SUPPORTED_MODES: Array[String] = ["canonical_sim_headless", "layer_isolation_noncanonical", "render_windowed"]
const SUPPORTED_FIXTURE_VERSIONS: Array[int] = [1]
const SUPPORTED_COMMAND_KINDS: Array[String] = ["lane_intent_pair", "swarm_active_lane"]
const MAX_DURATION_SEC: float = 600.0
const REQUIRED_GATE_KEYS: Array[String] = [
	"target_fps",
	"target_frame_ms",
	"p99_max_ms",
	"max_frame_ms",
	"max_hitches",
	"warn_regression_percent",
	"fail_regression_percent"
]


static func load_gate_config(path: String) -> Dictionary:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		return _failure(["gate path is empty"])
	var file: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		return _failure(["gate file cannot be opened: %s" % clean_path])
	var json := JSON.new()
	var parse_error: int = json.parse(file.get_as_text())
	if parse_error != OK:
		return _failure(["gate JSON parse failed at line %d: %s" % [json.get_error_line(), json.get_error_message()]])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _failure(["gate root must be a Dictionary"])
	var gates: Dictionary = json.data as Dictionary
	var validation: Dictionary = validate_gate_config(gates)
	if not bool(validation.get("ok", false)):
		return validation
	return {
		"ok": true,
		"errors": [],
		"gates": gates.duplicate(true),
		"source": clean_path
	}


static func validate_gate_config(gates: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for key in REQUIRED_GATE_KEYS:
		if not gates.has(key):
			errors.append("missing required gate: %s" % key)
	for key in ["target_fps", "target_frame_ms", "p99_max_ms", "max_frame_ms"]:
		if gates.has(key) and not _is_number(gates.get(key)):
			errors.append("gate %s must be numeric" % key)
		elif gates.has(key) and float(gates.get(key)) <= 0.0:
			errors.append("gate %s must be greater than zero" % key)
	for key in ["max_hitches", "warn_regression_percent", "fail_regression_percent"]:
		if gates.has(key) and not _is_number(gates.get(key)):
			errors.append("gate %s must be numeric" % key)
		elif gates.has(key) and float(gates.get(key)) < 0.0:
			errors.append("gate %s cannot be negative" % key)
	if gates.has("target_fps") and _is_number(gates.get("target_fps")) and not is_equal_approx(float(gates.get("target_fps")), 30.0):
		errors.append("Phase 0 benchmark target must remain 30 FPS")
	if (
		gates.has("warn_regression_percent")
		and gates.has("fail_regression_percent")
		and _is_number(gates.get("warn_regression_percent"))
		and _is_number(gates.get("fail_regression_percent"))
		and float(gates.get("fail_regression_percent")) < float(gates.get("warn_regression_percent"))
	):
		errors.append("fail_regression_percent cannot be lower than warn_regression_percent")
	return {"ok": errors.is_empty(), "errors": errors}


static func static_preflight(scenario: Dictionary, execution_mode: String) -> Dictionary:
	var errors: Array[String] = []
	var scenario_id: String = str(scenario.get("scenario_id", "")).strip_edges()
	if scenario_id.is_empty():
		errors.append("scenario_id is required")
	if not scenario.has("fixture_version") or not _is_number(scenario.get("fixture_version")):
		errors.append("fixture_version must be numeric")
	elif not SUPPORTED_FIXTURE_VERSIONS.has(int(scenario.get("fixture_version", 0))):
		errors.append("unsupported fixture_version: %d" % int(scenario.get("fixture_version", 0)))
	if not SUPPORTED_MODES.has(execution_mode):
		errors.append("unsupported execution mode: %s" % execution_mode)
	var duration_sec: float = float(scenario.get("duration_sec", 0.0))
	if duration_sec <= 0.0 or duration_sec > MAX_DURATION_SEC:
		errors.append("duration_sec must be greater than zero and at most %.0f" % MAX_DURATION_SEC)
	if int(scenario.get("tick_count", 1)) <= 0:
		errors.append("tick_count must be greater than zero when present")
	var warmup_ticks: int = int(scenario.get("warmup_ticks", 0))
	if warmup_ticks < 0 or warmup_ticks >= int(scenario.get("tick_count", 1)):
		errors.append("warmup_ticks must be non-negative and lower than tick_count")
	if int(scenario.get("repetitions", 1)) < 1 or int(scenario.get("repetitions", 1)) > 10:
		errors.append("repetitions must be between 1 and 10")
	if not scenario.has("seed") or not _is_number(scenario.get("seed")):
		errors.append("seed must be numeric")
	if typeof(scenario.get("systems", [])) != TYPE_ARRAY:
		errors.append("systems must be an Array")
	if typeof(scenario.get("renderers", [])) != TYPE_ARRAY:
		errors.append("renderers must be an Array")
	if int(scenario.get("command_interval_ticks", 0)) <= 0:
		errors.append("command_interval_ticks must be greater than zero")
	var command_schedule_any: Variant = scenario.get("command_schedule", [])
	if typeof(command_schedule_any) != TYPE_ARRAY:
		errors.append("command_schedule must be an Array when present")
	else:
		for command_any in command_schedule_any as Array:
			if typeof(command_any) != TYPE_DICTIONARY:
				errors.append("every command_schedule entry must be a Dictionary")
				continue
			var command: Dictionary = command_any as Dictionary
			if not _is_number(command.get("tick")) or int(command.get("tick", 0)) <= 0:
				errors.append("scheduled command tick must be greater than zero")
			elif int(command.get("tick", 0)) > int(scenario.get("tick_count", 1)):
				errors.append("scheduled command tick exceeds tick_count")
			var command_kind: String = str(command.get("kind", "")).strip_edges()
			if command_kind.is_empty():
				errors.append("scheduled command kind is required")
			elif not SUPPORTED_COMMAND_KINDS.has(command_kind):
				errors.append("unsupported scheduled command kind: %s" % command_kind)
			elif command_kind == "lane_intent_pair":
				if not _is_number(command.get("pair_index")):
					errors.append("lane_intent_pair pair_index must be numeric")
				if not ["attack", "feed"].has(str(command.get("intent", ""))):
					errors.append("lane_intent_pair intent must be attack or feed")
			elif command_kind == "swarm_active_lane" and command.has("salt") and not _is_number(command.get("salt")):
				errors.append("swarm_active_lane salt must be numeric when present")
	var camera_schedule_any: Variant = scenario.get("camera_schedule", [])
	if typeof(camera_schedule_any) != TYPE_ARRAY:
		errors.append("camera_schedule must be an Array when present")
	elif not (camera_schedule_any as Array).is_empty():
		errors.append("camera_schedule entries are not supported by Phase 0 fixtures")
	for key in ["initial_lanes", "initial_swarms", "initial_barracks_routes", "commands_per_burst", "swarm_burst"]:
		if int(scenario.get(key, 0)) < 0:
			errors.append("%s cannot be negative" % key)
	var map_path: String = str(scenario.get("map_path", "")).strip_edges()
	if map_path.is_empty():
		errors.append("map_path is required")
		return {"ok": false, "errors": errors}
	if not FileAccess.file_exists(map_path):
		errors.append("map resource does not exist: %s" % map_path)
		return {"ok": false, "errors": errors, "map_path": map_path}
	var map_hash: String = _sha256_file(map_path)
	if map_hash.is_empty():
		errors.append("map resource could not be hashed: %s" % map_path)
	var load_result: Dictionary = MapLoader.load_map(map_path)
	if not bool(load_result.get("ok", false)):
		errors.append("production MapLoader rejected %s: %s" % [map_path, str(load_result.get("err", "unknown"))])
		return {"ok": false, "errors": errors, "map_path": map_path, "map_content_hash": map_hash}
	var map_data: Dictionary = load_result.get("data", {}) as Dictionary
	var normalized_counts: Dictionary = counts_from_map_data(map_data)
	var expected_counts_any: Variant = scenario.get("expected_counts", {})
	if typeof(expected_counts_any) != TYPE_DICTIONARY:
		errors.append("expected_counts must be a Dictionary when present")
	else:
		var expected_counts: Dictionary = expected_counts_any as Dictionary
		for key in expected_counts.keys():
			var clean_key: String = str(key)
			if not normalized_counts.has(clean_key):
				errors.append("unsupported expected count: %s" % clean_key)
			elif not _is_number(expected_counts.get(key)) or int(expected_counts.get(key, -1)) < 0:
				errors.append("expected count %s must be a non-negative number" % clean_key)
			elif int(expected_counts.get(key, -1)) != int(normalized_counts.get(clean_key, -2)):
				errors.append("expected %s=%d but normalized map contains %d" % [
					clean_key,
					int(expected_counts.get(key, -1)),
					int(normalized_counts.get(clean_key, -2))
				])
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"map_path": map_path,
		"map_content_hash": map_hash,
		"map_data": map_data,
		"expected_runtime_counts": normalized_counts
	}


static func validate_post_apply(expected_counts: Dictionary, actual_counts: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for key_any in expected_counts.keys():
		var key: String = str(key_any)
		if not actual_counts.has(key):
			errors.append("post-apply count missing: %s" % key)
			continue
		var expected: int = int(expected_counts.get(key_any, -1))
		var actual: int = int(actual_counts.get(key, -1))
		if expected != actual:
			errors.append("post-apply %s mismatch: expected %d, got %d" % [key, expected, actual])
	return {"ok": errors.is_empty(), "errors": errors, "actual_counts": actual_counts.duplicate(true)}


static func counts_from_map_data(map_data: Dictionary) -> Dictionary:
	return {
		"hives": _array_count(map_data.get("hives", [])),
		"towers": _array_count(map_data.get("towers", [])),
		"barracks": _array_count(map_data.get("barracks", [])),
		"structure_slots": _array_count(map_data.get("structure_slots", []))
	}


static func runtime_counts(state: GameState, arena: Node) -> Dictionary:
	var current_map_data: Dictionary = {}
	if arena != null and "current_map_data" in arena:
		var map_data_any: Variant = arena.get("current_map_data")
		if typeof(map_data_any) == TYPE_DICTIONARY:
			current_map_data = map_data_any as Dictionary
	return {
		"hives": state.hives.size() if state != null else -1,
		"towers": state.towers.size() if state != null else -1,
		"barracks": state.barracks.size() if state != null else -1,
		"structure_slots": _array_count(current_map_data.get("structure_slots", []))
	}


static func _sha256_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(file.get_buffer(file.get_length()))
	return context.finish().hex_encode()


static func _array_count(value: Variant) -> int:
	return (value as Array).size() if typeof(value) == TYPE_ARRAY else -1


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _failure(errors: Array[String]) -> Dictionary:
	return {"ok": false, "errors": errors, "gates": {}, "source": ""}
