class_name PerfFeatureRegistry
extends RefCounted

const REGISTRY_SCHEMA: String = "sf_perf_feature_isolation_registry_v1"
const REGISTRY_VERSION: int = 1
const CLASSIFICATIONS: Array[String] = ["PRESENT_ISOLATABLE", "PRESENT_COUPLED", "NOT_PRESENT", "FUTURE"]
const VARIANTS: Array[String] = ["off", "production", "exaggerated"]
const REQUIRED_CATEGORIES: Array[String] = [
	"arena_environment", "lighting_post", "units", "hives", "lanes", "structures",
	"ui", "camera", "swarm_vfx", "audio_haptics", "simulation_network", "future_scope"
]
const SAFE_CONTROL_KINDS: Array[String] = [
	"scene_visibility", "project_setting_bundle", "fixture_configuration",
	"exact_scene_schedule", "execution_mode"
]
const SAFE_SCENE_PATHS: Array[String] = [
	"MapRoot/FloorRenderer", "MapRoot/HiveRenderer", "MapRoot/LaneRenderer",
	"PoolsRoot/UnitRenderer", "MapRoot/TowerRenderer", "MapRoot/BarracksRenderer",
	"WallRenderer", "UI/SelectionHud", "UI/MissNOutBanner",
	"HudOverlayLayer/HudOverlay", "Camera2D"
]

static func load_registry(path: String) -> Dictionary:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty() or not FileAccess.file_exists(clean_path):
		return {"ok": false, "errors": ["feature registry cannot be opened: %s" % clean_path]}
	var text: String = FileAccess.get_file_as_string(clean_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "errors": ["feature registry root must be a Dictionary"]}
	var registry: Dictionary = parsed as Dictionary
	var validation: Dictionary = validate_registry(registry)
	if not bool(validation.get("ok", false)):
		return validation
	var features_by_id: Dictionary = {}
	var classification_counts: Dictionary = {}
	for feature_any in registry.get("features", []) as Array:
		var feature: Dictionary = feature_any as Dictionary
		features_by_id[str(feature.get("feature_id", ""))] = feature.duplicate(true)
		var classification: String = str(feature.get("classification", ""))
		classification_counts[classification] = int(classification_counts.get(classification, 0)) + 1
	return {
		"ok": true,
		"errors": [],
		"registry": registry.duplicate(true),
		"features_by_id": features_by_id,
		"identity": {
			"registry_schema": REGISTRY_SCHEMA,
			"registry_version": REGISTRY_VERSION,
			"source": clean_path,
			"content_hash": _sha256_file(clean_path),
			"feature_count": features_by_id.size(),
			"classification_counts": classification_counts
		}
	}

static func validate_registry(registry: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if str(registry.get("registry_schema", "")) != REGISTRY_SCHEMA:
		errors.append("feature registry schema mismatch")
	if int(registry.get("registry_version", 0)) != REGISTRY_VERSION:
		errors.append("feature registry version mismatch")
	var policies_any: Variant = registry.get("variant_policies", {})
	if typeof(policies_any) != TYPE_DICTIONARY:
		errors.append("variant_policies must be a Dictionary")
		policies_any = {}
	var policies: Dictionary = policies_any as Dictionary
	for policy_id_any in policies.keys():
		_validate_policy(errors, str(policy_id_any), policies.get(policy_id_any))
	var features_any: Variant = registry.get("features", [])
	if typeof(features_any) != TYPE_ARRAY or (features_any as Array).is_empty():
		errors.append("features must be a non-empty Array")
		return {"ok": false, "errors": errors}
	var seen_ids: Dictionary = {}
	var seen_categories: Dictionary = {}
	var safe_three_variant_count: int = 0
	for index in range((features_any as Array).size()):
		var feature_any: Variant = (features_any as Array)[index]
		if typeof(feature_any) != TYPE_DICTIONARY:
			errors.append("feature %d must be a Dictionary" % index)
			continue
		var feature: Dictionary = feature_any as Dictionary
		var prefix: String = "feature_%d" % index
		var feature_id: String = str(feature.get("feature_id", "")).strip_edges()
		if not _valid_id(feature_id):
			errors.append("%s feature_id is invalid" % prefix)
		elif seen_ids.has(feature_id):
			errors.append("duplicate feature_id: %s" % feature_id)
		else:
			seen_ids[feature_id] = true
		if str(feature.get("label", "")).strip_edges().is_empty():
			errors.append("%s label is required" % prefix)
		var category: String = str(feature.get("category", "")).strip_edges()
		if not REQUIRED_CATEGORIES.has(category):
			errors.append("%s category is unsupported: %s" % [prefix, category])
		else:
			seen_categories[category] = true
		var classification: String = str(feature.get("classification", ""))
		if not CLASSIFICATIONS.has(classification):
			errors.append("%s classification is unsupported" % prefix)
		var owner: String = str(feature.get("owner", "")).strip_edges()
		if owner.is_empty():
			errors.append("%s owner is required" % prefix)
		var source: String = str(feature.get("source", "")).strip_edges()
		if classification.begins_with("PRESENT_") and (source.is_empty() or not FileAccess.file_exists(source)):
			errors.append("%s present feature source is missing: %s" % [prefix, source])
		var scope_items_any: Variant = feature.get("scope_items", [])
		if typeof(scope_items_any) != TYPE_ARRAY or (scope_items_any as Array).is_empty():
			errors.append("%s scope_items must be non-empty" % prefix)
		var policy_id: String = str(feature.get("variant_policy", ""))
		if not policies.has(policy_id):
			errors.append("%s variant_policy is unknown: %s" % [prefix, policy_id])
		var policy: Dictionary = policies.get(policy_id, {}) as Dictionary
		var control_any: Variant = feature.get("control", {})
		if typeof(control_any) != TYPE_DICTIONARY:
			errors.append("%s control must be a Dictionary" % prefix)
			continue
		var control: Dictionary = control_any as Dictionary
		var control_kind: String = str(control.get("kind", ""))
		if classification == "PRESENT_ISOLATABLE":
			if not SAFE_CONTROL_KINDS.has(control_kind):
				errors.append("%s isolatable control is not exact/reversible" % prefix)
			_validate_exact_control(errors, prefix, control)
			if _policy_safe_variant_count(policy) < 2:
				errors.append("%s isolatable feature needs at least two safe variants" % prefix)
			if _policy_safe_variant_count(policy) == 3:
				safe_three_variant_count += 1
		elif control_kind != "none":
			errors.append("%s non-isolatable feature cannot expose a harness control" % prefix)
		if classification in ["NOT_PRESENT", "FUTURE"] and _policy_supported_variant_count(policy) != 0:
			errors.append("%s absent/future feature cannot expose supported variants" % prefix)
	if safe_three_variant_count <= 0:
		errors.append("registry must contain at least one safe off/production/exaggerated feature")
	for category in REQUIRED_CATEGORIES:
		if not seen_categories.has(category):
			errors.append("required feature category missing: %s" % category)
	return {"ok": errors.is_empty(), "errors": errors}

static func resolved_feature(registry: Dictionary, feature_id: String) -> Dictionary:
	for feature_any in registry.get("features", []) as Array:
		if typeof(feature_any) != TYPE_DICTIONARY:
			continue
		var feature: Dictionary = feature_any as Dictionary
		if str(feature.get("feature_id", "")) != feature_id:
			continue
		var out: Dictionary = feature.duplicate(true)
		out["variants"] = (registry.get("variant_policies", {}) as Dictionary).get(str(feature.get("variant_policy", "")), {}).duplicate(true)
		return out
	return {}

static func _validate_policy(errors: Array[String], policy_id: String, policy_any: Variant) -> void:
	if typeof(policy_any) != TYPE_DICTIONARY:
		errors.append("variant policy %s must be a Dictionary" % policy_id)
		return
	var policy: Dictionary = policy_any as Dictionary
	for variant in VARIANTS:
		var row_any: Variant = policy.get(variant, {})
		if typeof(row_any) != TYPE_DICTIONARY:
			errors.append("variant policy %s.%s must be a Dictionary" % [policy_id, variant])
			continue
		var row: Dictionary = row_any as Dictionary
		if typeof(row.get("supported")) != TYPE_BOOL or typeof(row.get("comparison_safe")) != TYPE_BOOL:
			errors.append("variant policy %s.%s needs boolean support/safety" % [policy_id, variant])
		elif bool(row.get("comparison_safe", false)) and not bool(row.get("supported", false)):
			errors.append("variant policy %s.%s cannot be safe when unsupported" % [policy_id, variant])

static func _validate_exact_control(errors: Array[String], prefix: String, control: Dictionary) -> void:
	var kind: String = str(control.get("kind", ""))
	match kind:
		"scene_visibility":
			if not SAFE_SCENE_PATHS.has(str(control.get("path", ""))):
				errors.append("%s scene visibility path is not approved" % prefix)
		"project_setting_bundle":
			if str(control.get("setting", "")) != "swarmfront/arena/polish_comparison_mode":
				errors.append("%s project-setting bundle is not snapshotted" % prefix)
			if (control.get("allowed_values", []) as Array) != ["baseline", "settings", "tower_150"]:
				errors.append("%s polish values must remain exact" % prefix)
		"fixture_configuration":
			if str(control.get("field", "")) != "target_units":
				errors.append("%s fixture configuration field is unsupported" % prefix)
		"exact_scene_schedule":
			var paths: Array = control.get("paths", []) as Array
			if paths.is_empty():
				errors.append("%s exact scene schedule needs paths" % prefix)
			for path_any in paths:
				if not SAFE_SCENE_PATHS.has(str(path_any)):
					errors.append("%s exact scene path is not approved: %s" % [prefix, str(path_any)])
		"execution_mode":
			if not ["canonical_sim_headless", "layer_isolation_noncanonical"].has(str(control.get("value", ""))):
				errors.append("%s execution mode is unsupported" % prefix)

static func _policy_safe_variant_count(policy: Dictionary) -> int:
	var count: int = 0
	for variant in VARIANTS:
		var row: Dictionary = policy.get(variant, {}) as Dictionary
		if bool(row.get("supported", false)) and bool(row.get("comparison_safe", false)):
			count += 1
	return count

static func _policy_supported_variant_count(policy: Dictionary) -> int:
	var count: int = 0
	for variant in VARIANTS:
		if bool((policy.get(variant, {}) as Dictionary).get("supported", false)):
			count += 1
	return count

static func _valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		var character: String = value.substr(index, 1)
		if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") and character != "_":
			return false
	return true

static func _sha256_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(file.get_buffer(file.get_length()))
	return context.finish().hex_encode()
