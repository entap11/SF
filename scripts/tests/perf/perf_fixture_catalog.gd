class_name PerfFixtureCatalog
extends RefCounted

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const PERF_DETERMINISTIC_HASH := preload("res://scripts/tests/perf/perf_deterministic_hash.gd")
const UNIT_SYSTEM := preload("res://scripts/systems/unit_system.gd")
const UNIT_RENDERER := preload("res://scripts/renderers/unit_renderer.gd")

const CATALOG_SCHEMA: String = "sf_perf_fixture_catalog_design_v1"
const CATALOG_VERSION: int = 1
const CATALOG_STATUSES: Array[String] = ["DESIGN_APPROVED_NOT_IMPLEMENTED", "IMPLEMENTATION_IN_PROGRESS", "IMPLEMENTED"]
const FIXTURE_STATUSES: Array[String] = ["DESIGN_APPROVED_NOT_IMPLEMENTED", "IMPLEMENTED"]
const REQUIRED_RESULT_SCHEMA_VERSION: int = 3
const REQUIRED_COLLECTION_LEVEL: String = "MINIMAL"
const REQUIRED_REPETITIONS: int = 3
const APPROVED_FIXTURE_IDS: Array[String] = [
	"EMPTY_ARENA_V1",
	"NORMAL_MATCH_V1",
	"STATIC_BATTLEFIELD_V1",
	"UNIT_SCALE_050_V1",
	"UNIT_SCALE_100_V1",
	"UNIT_SCALE_200_V1",
	"UNIT_SCALE_400_V1"
]
const SUPPORTED_MEASUREMENT_PROFILES: Array[String] = [
	"canonical_sim_headless",
	"deterministic_windowed_presentation",
	"static_windowed_deterministic"
]
const UNIT_SCALE_TARGETS: Array[int] = [50, 100, 200, 400]
const APPROVED_SEEDS := {
	"EMPTY_ARENA_V1": 6101,
	"STATIC_BATTLEFIELD_V1": 6111,
	"NORMAL_MATCH_V1": 6201,
	"UNIT_SCALE_050_V1": 6401,
	"UNIT_SCALE_100_V1": 6401,
	"UNIT_SCALE_200_V1": 6401,
	"UNIT_SCALE_400_V1": 6401
}


static func load_catalog(path: String) -> Dictionary:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		return _load_failure(clean_path, ["catalog_path_empty"])
	var file: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		return _load_failure(clean_path, ["catalog_file_unavailable:%s" % clean_path])
	var source_text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_error: int = json.parse(source_text)
	if parse_error != OK:
		return _load_failure(clean_path, [
			"catalog_json_invalid:line_%d:%s" % [json.get_error_line(), json.get_error_message()]
		])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _load_failure(clean_path, ["catalog_root_not_dictionary"])
	var catalog: Dictionary = json.data as Dictionary
	var validation: Dictionary = validate_catalog(catalog)
	var content_hash: String = _sha256_file(clean_path)
	if content_hash.is_empty():
		var hash_errors: Array = (validation.get("errors", []) as Array).duplicate()
		hash_errors.append("catalog_content_hash_unavailable")
		validation = {"ok": false, "errors": hash_errors}
	var identity: Dictionary = catalog_identity(catalog, clean_path, content_hash, bool(validation.get("ok", false)))
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"errors": (validation.get("errors", []) as Array).duplicate(),
			"catalog": {},
			"fixtures_by_id": {},
			"identity": identity
		}
	return {
		"ok": true,
		"errors": [],
		"catalog": catalog.duplicate(true),
		"fixtures_by_id": fixtures_by_id(catalog),
		"identity": identity
	}


static func validate_catalog(catalog: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if str(catalog.get("catalog_schema", "")) != CATALOG_SCHEMA:
		errors.append("catalog_schema_unsupported")
	if int(catalog.get("catalog_version", 0)) != CATALOG_VERSION:
		errors.append("catalog_version_unsupported")
	if not CATALOG_STATUSES.has(str(catalog.get("status", ""))):
		errors.append("catalog_status_unsupported")
	_validate_baseline_policy(catalog.get("baseline_policy"), errors)
	_validate_common(catalog.get("common"), errors)
	_validate_fixtures(catalog.get("fixtures"), errors)
	var deferred_any: Variant = catalog.get("deferred")
	if typeof(deferred_any) != TYPE_ARRAY:
		errors.append("deferred_not_array")
	else:
		var deferred: Array = deferred_any as Array
		for required_deferral in ["3-player fixtures", "4-player fixtures", "multi-map or multi-stage async fixtures"]:
			if not deferred.has(required_deferral):
				errors.append("required_deferral_missing:%s" % required_deferral)
	return {"ok": errors.is_empty(), "errors": errors}


static func catalog_identity(
	catalog: Dictionary,
	source_path: String,
	content_hash: String = "",
	validation_pass: bool = false
) -> Dictionary:
	var fixtures_any: Variant = catalog.get("fixtures", [])
	var fixture_count: int = (fixtures_any as Array).size() if typeof(fixtures_any) == TYPE_ARRAY else 0
	var resolved_hash: String = content_hash
	if resolved_hash.is_empty() and not catalog.is_empty():
		resolved_hash = PERF_DETERMINISTIC_HASH.hash_variant(catalog)
	return {
		"schema": str(catalog.get("catalog_schema", "")),
		"version": int(catalog.get("catalog_version", 0)),
		"status": str(catalog.get("status", "")),
		"source": source_path,
		"content_hash": resolved_hash,
		"fixture_count": fixture_count,
		"validation": "PASS" if validation_pass else "FAIL",
		"baseline_default_eligible": false
	}


static func fixtures_by_id(catalog: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var fixtures_any: Variant = catalog.get("fixtures", [])
	if typeof(fixtures_any) != TYPE_ARRAY:
		return out
	for fixture_any in fixtures_any as Array:
		if typeof(fixture_any) != TYPE_DICTIONARY:
			continue
		var fixture: Dictionary = fixture_any as Dictionary
		var fixture_id: String = str(fixture.get("fixture_id", "")).strip_edges()
		if fixture_id.is_empty() or out.has(fixture_id):
			continue
		out[fixture_id] = fixture.duplicate(true)
	return out


static func _validate_baseline_policy(policy_any: Variant, errors: Array[String]) -> void:
	if typeof(policy_any) != TYPE_DICTIONARY:
		errors.append("baseline_policy_not_dictionary")
		return
	var policy: Dictionary = policy_any as Dictionary
	if not bool(policy.get("catalog_entries_are_candidates_only", false)):
		errors.append("baseline_policy_candidates_only_required")
	if bool(policy.get("default_baseline_eligible", true)):
		errors.append("baseline_policy_default_must_be_ineligible")
	if int(policy.get("required_repetitions", 0)) != REQUIRED_REPETITIONS:
		errors.append("baseline_policy_repetitions_must_be_%d" % REQUIRED_REPETITIONS)
	if str(policy.get("required_collection_level", "")) != REQUIRED_COLLECTION_LEVEL:
		errors.append("baseline_policy_collection_must_be_%s" % REQUIRED_COLLECTION_LEVEL)
	if int(policy.get("required_result_schema_version", 0)) != REQUIRED_RESULT_SCHEMA_VERSION:
		errors.append("baseline_policy_result_schema_must_be_%d" % REQUIRED_RESULT_SCHEMA_VERSION)
	for required_true in [
		"require_clean_worktree",
		"require_integrity_pass",
		"require_determinism_pass",
		"require_isolation_pass",
		"require_backend_isolation_pass",
		"require_exact_fixture_counts"
	]:
		if not bool(policy.get(required_true, false)):
			errors.append("baseline_policy_required_true:%s" % required_true)
	var key_fields_any: Variant = policy.get("baseline_key_fields")
	if typeof(key_fields_any) != TYPE_ARRAY:
		errors.append("baseline_key_fields_not_array")
	else:
		var key_fields: Array = key_fields_any as Array
		for required_field in ["fixture_id", "fixture_version", "measurement_profile", "fixture_config_hash", "environment_compatibility_hash"]:
			if not key_fields.has(required_field):
				errors.append("baseline_key_field_missing:%s" % required_field)


static func _validate_common(common_any: Variant, errors: Array[String]) -> void:
	if typeof(common_any) != TYPE_DICTIONARY:
		errors.append("common_not_dictionary")
		return
	var common: Dictionary = common_any as Dictionary
	var scene_path: String = str(common.get("scene_path", "")).strip_edges()
	if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
		errors.append("common_scene_unavailable:%s" % scene_path)
	if int(common.get("repetitions", 0)) != REQUIRED_REPETITIONS:
		errors.append("common_repetitions_must_be_%d" % REQUIRED_REPETITIONS)
	if str(common.get("collection_level", "")) != REQUIRED_COLLECTION_LEVEL:
		errors.append("common_collection_must_be_%s" % REQUIRED_COLLECTION_LEVEL)
	_validate_viewport(common.get("viewport"), errors)
	_validate_cadence(common.get("deterministic_windowed_cadence"), errors)
	_validate_production_map(common.get("production_map"), errors)


static func _validate_viewport(viewport_any: Variant, errors: Array[String]) -> void:
	if typeof(viewport_any) != TYPE_DICTIONARY:
		errors.append("common_viewport_not_dictionary")
		return
	var viewport: Dictionary = viewport_any as Dictionary
	var expected_width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var expected_height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	var expected_mode: String = str(ProjectSettings.get_setting("display/window/stretch/mode", ""))
	var expected_aspect: String = str(ProjectSettings.get_setting("display/window/stretch/aspect", ""))
	if int(viewport.get("width", 0)) != expected_width or int(viewport.get("height", 0)) != expected_height:
		errors.append("common_viewport_size_mismatch")
	if str(viewport.get("stretch_mode", "")) != expected_mode:
		errors.append("common_viewport_stretch_mode_mismatch")
	if str(viewport.get("stretch_aspect", "")) != expected_aspect:
		errors.append("common_viewport_stretch_aspect_mismatch")


static func _validate_cadence(cadence_any: Variant, errors: Array[String]) -> void:
	if typeof(cadence_any) != TYPE_DICTIONARY:
		errors.append("common_cadence_not_dictionary")
		return
	var cadence: Dictionary = cadence_any as Dictionary
	var target_fps: int = int(cadence.get("target_fps", 0))
	var simulation_hz: int = int(cadence.get("simulation_hz", 0))
	var frames_per_tick: int = int(cadence.get("frames_per_simulation_tick", 0))
	if target_fps != 30:
		errors.append("common_cadence_target_fps_must_be_30")
	if simulation_hz <= 0 or frames_per_tick <= 0 or simulation_hz * frames_per_tick != target_fps:
		errors.append("common_cadence_ratio_invalid")
	if int(cadence.get("warmup_frames", 0)) <= 0 or int(cadence.get("measurement_frames", 0)) <= 0:
		errors.append("common_cadence_frame_windows_invalid")


static func _validate_production_map(map_any: Variant, errors: Array[String]) -> void:
	if typeof(map_any) != TYPE_DICTIONARY:
		errors.append("common_production_map_not_dictionary")
		return
	var map_ref: Dictionary = map_any as Dictionary
	var path: String = str(map_ref.get("path", "")).strip_edges()
	if path.is_empty() or not FileAccess.file_exists(path):
		errors.append("production_map_unavailable:%s" % path)
		return
	var declared_hash: String = str(map_ref.get("sha256", ""))
	var actual_hash: String = _sha256_file(path)
	if declared_hash.length() != 64 or declared_hash != actual_hash:
		errors.append("production_map_hash_mismatch")
	var authored: Dictionary = _load_json_dictionary(path)
	if authored.is_empty():
		errors.append("production_map_authored_json_invalid")
	else:
		if str(map_ref.get("mode", "")) != str(authored.get("mode", "")):
			errors.append("production_map_mode_mismatch")
		if PERF_DETERMINISTIC_HASH.hash_variant(map_ref.get("player_buckets", [])) != PERF_DETERMINISTIC_HASH.hash_variant(authored.get("player_buckets", [])):
			errors.append("production_map_player_buckets_mismatch")
		if PERF_DETERMINISTIC_HASH.hash_variant(map_ref.get("start_slots", [])) != PERF_DETERMINISTIC_HASH.hash_variant(authored.get("start_slots", [])):
			errors.append("production_map_start_slots_mismatch")
	var load_result: Dictionary = MAP_LOADER.load_map(path)
	if not bool(load_result.get("ok", false)):
		errors.append("production_map_loader_rejected:%s" % str(load_result.get("err", "unknown")))
		return
	var map_data: Dictionary = load_result.get("data", {}) as Dictionary
	var actual_counts := {
		"hives": _array_count(map_data.get("hives")),
		"towers": _array_count(map_data.get("towers")),
		"barracks": _array_count(map_data.get("barracks")),
		"structure_slots": _array_count(map_data.get("structure_slots")),
		"walls": _array_count(map_data.get("walls"))
	}
	var expected_any: Variant = map_ref.get("expected_counts")
	if typeof(expected_any) != TYPE_DICTIONARY:
		errors.append("production_map_expected_counts_not_dictionary")
		return
	var expected: Dictionary = expected_any as Dictionary
	for count_key in actual_counts.keys():
		if not expected.has(count_key) or int(expected.get(count_key, -1)) != int(actual_counts.get(count_key, -2)):
			errors.append("production_map_count_mismatch:%s" % count_key)


static func _validate_fixtures(fixtures_any: Variant, errors: Array[String]) -> void:
	if typeof(fixtures_any) != TYPE_ARRAY:
		errors.append("fixtures_not_array")
		return
	var fixtures: Array = fixtures_any as Array
	var seen: Dictionary = {}
	var observed_ids: Array[String] = []
	var observed_targets: Array[int] = []
	for index in range(fixtures.size()):
		var fixture_any: Variant = fixtures[index]
		if typeof(fixture_any) != TYPE_DICTIONARY:
			errors.append("fixture_%d_not_dictionary" % index)
			continue
		var fixture: Dictionary = fixture_any as Dictionary
		var fixture_id: String = str(fixture.get("fixture_id", "")).strip_edges()
		if fixture_id.is_empty() or not fixture_id.is_valid_identifier():
			errors.append("fixture_%d_id_invalid" % index)
			continue
		if seen.has(fixture_id):
			errors.append("fixture_id_duplicate:%s" % fixture_id)
			continue
		seen[fixture_id] = true
		observed_ids.append(fixture_id)
		_validate_fixture(fixture, fixture_id, observed_targets, errors)
	observed_ids.sort()
	if observed_ids != APPROVED_FIXTURE_IDS:
		errors.append("fixture_id_set_not_approved")
	observed_targets.sort()
	if observed_targets != UNIT_SCALE_TARGETS:
		errors.append("unit_scale_target_set_not_approved")


static func _validate_fixture(
	fixture: Dictionary,
	fixture_id: String,
	observed_targets: Array[int],
	errors: Array[String]
) -> void:
	if int(fixture.get("fixture_version", 0)) != 1:
		errors.append("fixture_version_unsupported:%s" % fixture_id)
	if not FIXTURE_STATUSES.has(str(fixture.get("status", ""))):
		errors.append("fixture_status_unsupported:%s" % fixture_id)
	if not _is_number(fixture.get("seed")):
		errors.append("fixture_seed_invalid:%s" % fixture_id)
	elif int(fixture.get("seed", 0)) != int(APPROVED_SEEDS.get(fixture_id, -1)):
		errors.append("fixture_seed_not_approved:%s" % fixture_id)
	if not bool(fixture.get("baseline_candidate", false)):
		errors.append("fixture_not_baseline_candidate:%s" % fixture_id)
	if bool(fixture.get("baseline_eligible", true)):
		errors.append("fixture_must_default_ineligible:%s" % fixture_id)
	if str(fixture.get("setup_path", "")).strip_edges().is_empty():
		errors.append("fixture_setup_path_missing:%s" % fixture_id)
	if str(fixture.get("camera_policy", "")).strip_edges().is_empty():
		errors.append("fixture_camera_policy_missing:%s" % fixture_id)
	_validate_profiles(fixture.get("measurement_profiles"), fixture_id, errors)
	_validate_profile_matrix(fixture, fixture_id, errors)
	var content_kind: String = str(fixture.get("content_kind", ""))
	if content_kind == "synthetic_scene":
		if fixture_id != "EMPTY_ARENA_V1":
			errors.append("synthetic_content_not_approved:%s" % fixture_id)
		if str(fixture.get("content_identity", "")).strip_edges().is_empty():
			errors.append("synthetic_content_identity_missing:%s" % fixture_id)
		if fixture.get("map_path") != null:
			errors.append("synthetic_fixture_map_path_must_be_null:%s" % fixture_id)
	elif content_kind == "production_map":
		if str(fixture.get("map_ref", "")) != "common.production_map":
			errors.append("production_fixture_map_ref_invalid:%s" % fixture_id)
	else:
		errors.append("fixture_content_kind_unsupported:%s" % fixture_id)
	if fixture_id.begins_with("UNIT_SCALE_"):
		var target: int = int(fixture.get("target_units", 0))
		observed_targets.append(target)
		var capacity: int = mini(int(UNIT_SYSTEM.MAX_ACTIVE_UNITS), int(UNIT_RENDERER.UNIT_POOL_SIZE_TOTAL))
		if target <= 0 or target > capacity:
			errors.append("unit_scale_target_exceeds_capacity:%s" % fixture_id)
	match fixture_id:
		"EMPTY_ARENA_V1":
			_validate_expected_counts(fixture, fixture_id, {
				"hives": 0, "active_lanes": 0, "units": 0, "towers": 0,
				"barracks": 0, "structure_slots": 0, "walls": 0
			}, errors)
		"STATIC_BATTLEFIELD_V1":
			_validate_expected_counts(fixture, fixture_id, {
				"hives": 12, "active_lanes": 0, "units": 0, "towers": 0,
				"barracks": 0, "structure_slots": 0, "walls": 2
			}, errors)
		"NORMAL_MATCH_V1":
			if str(fixture.get("command_selector_version", "")) != "sorted_candidate_pair_v1":
				errors.append("normal_match_command_selector_not_approved")
			if str(fixture.get("schedule_status", "")) != "FROZEN_AFTER_PILOT":
				errors.append("normal_match_schedule_not_frozen")
			_validate_normal_match_schedule(fixture, errors)
			_validate_normal_match_timing(fixture.get("timing"), errors)


static func _validate_normal_match_schedule(fixture: Dictionary, errors: Array[String]) -> void:
	var approved_schedule: Array = [
		{"tick": 5, "kind": "lane_intent_pair", "pair_index": 4, "intent": "attack"},
		{"tick": 15, "kind": "swarm_active_lane", "salt": 0},
		{"tick": 25, "kind": "lane_intent_pair", "pair_index": 5, "intent": "attack"},
		{"tick": 35, "kind": "lane_intent_pair", "pair_index": 6, "intent": "attack"}
	]
	var approved_commands: Array = [
		{"tick": 5, "type": "attack", "src": 2, "dst": 9, "schedule_index": 0},
		{"tick": 15, "type": "swarm", "src": 2, "dst": 9, "schedule_index": 1},
		{"tick": 25, "type": "attack", "src": 3, "dst": 8, "schedule_index": 2},
		{"tick": 35, "type": "attack", "src": 3, "dst": 8, "schedule_index": 3}
	]
	if PERF_DETERMINISTIC_HASH.hash_variant(fixture.get("command_schedule", [])) != PERF_DETERMINISTIC_HASH.hash_variant(approved_schedule):
		errors.append("normal_match_schedule_not_approved")
	if PERF_DETERMINISTIC_HASH.hash_variant(fixture.get("expected_accepted_commands", [])) != PERF_DETERMINISTIC_HASH.hash_variant(approved_commands):
		errors.append("normal_match_accepted_commands_not_approved")
	if int(fixture.get("expected_command_count", 0)) != 4:
		errors.append("normal_match_expected_command_count_invalid")
	if PERF_DETERMINISTIC_HASH.hash_variant(fixture.get("expected_command_types", [])) != PERF_DETERMINISTIC_HASH.hash_variant(["attack", "swarm"]):
		errors.append("normal_match_expected_command_types_invalid")
	for hash_key in ["pilot_accepted_command_hash", "pilot_canonical_final_state_hash"]:
		if str(fixture.get(hash_key, "")).length() != 64:
			errors.append("normal_match_pilot_hash_invalid:%s" % hash_key)


static func _validate_profiles(profiles_any: Variant, fixture_id: String, errors: Array[String]) -> void:
	if typeof(profiles_any) != TYPE_ARRAY or (profiles_any as Array).is_empty():
		errors.append("fixture_profiles_invalid:%s" % fixture_id)
		return
	var seen: Dictionary = {}
	for profile_any in profiles_any as Array:
		var profile: String = str(profile_any).strip_edges()
		if not SUPPORTED_MEASUREMENT_PROFILES.has(profile):
			errors.append("fixture_profile_unsupported:%s:%s" % [fixture_id, profile])
		elif seen.has(profile):
			errors.append("fixture_profile_duplicate:%s:%s" % [fixture_id, profile])
		seen[profile] = true


static func _validate_profile_matrix(fixture: Dictionary, fixture_id: String, errors: Array[String]) -> void:
	var expected: Array = ["static_windowed_deterministic"]
	if fixture_id == "NORMAL_MATCH_V1":
		expected = ["canonical_sim_headless", "deterministic_windowed_presentation"]
	if PERF_DETERMINISTIC_HASH.hash_variant(fixture.get("measurement_profiles", [])) != PERF_DETERMINISTIC_HASH.hash_variant(expected):
		errors.append("fixture_profile_matrix_not_approved:%s" % fixture_id)


static func _validate_expected_counts(
	fixture: Dictionary,
	fixture_id: String,
	expected: Dictionary,
	errors: Array[String]
) -> void:
	var counts_any: Variant = fixture.get("expected_counts")
	if typeof(counts_any) != TYPE_DICTIONARY:
		errors.append("fixture_expected_counts_missing:%s" % fixture_id)
		return
	var counts: Dictionary = counts_any as Dictionary
	if PERF_DETERMINISTIC_HASH.hash_variant(counts) != PERF_DETERMINISTIC_HASH.hash_variant(expected):
		errors.append("fixture_expected_counts_not_approved:%s" % fixture_id)


static func _validate_normal_match_timing(timing_any: Variant, errors: Array[String]) -> void:
	if typeof(timing_any) != TYPE_DICTIONARY:
		errors.append("normal_match_timing_missing")
		return
	var timing: Dictionary = timing_any as Dictionary
	var warmup: int = int(timing.get("warmup_ticks", 0))
	var measurement: int = int(timing.get("measurement_ticks", 0))
	var total: int = int(timing.get("total_ticks", 0))
	if warmup != 20 or measurement != 100 or total != 120 or warmup + measurement != total:
		errors.append("normal_match_timing_not_approved")


static func _load_json_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


static func _sha256_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		file.close()
		return ""
	context.update(file.get_buffer(file.get_length()))
	file.close()
	return context.finish().hex_encode()


static func _array_count(value: Variant) -> int:
	return (value as Array).size() if typeof(value) == TYPE_ARRAY else -1


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _load_failure(path: String, errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors.duplicate(),
		"catalog": {},
		"fixtures_by_id": {},
		"identity": catalog_identity({}, path, "", false)
	}
