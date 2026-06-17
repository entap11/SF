extends Node2D
class_name ArenaPolishLayer

const SETTINGS_POLISH_ENABLED: String = "swarmfront/arena/premium_polish_enabled"
const SETTINGS_TOWER_VISUAL_SCALE: String = "swarmfront/arena/tower_visual_scale"
const SETTINGS_COMPARISON_MODE: String = "swarmfront/arena/polish_comparison_mode"
const MANIFEST_PATH: String = "res://assets/sprites/arena_polish/arena_polish_manifest.json"
const DEFAULT_POLISH_ENABLED: bool = false
const DEFAULT_TOWER_VISUAL_SCALE: float = 1.0
const DEFAULT_COMPARISON_MODE: String = "settings"
const COMPARISON_MODE_SETTINGS: String = "settings"
const COMPARISON_MODE_BASELINE: String = "baseline"
const COMPARISON_MODE_POLISH: String = "polish"
const COMPARISON_MODE_TOWER_110: String = "tower_110"
const COMPARISON_MODE_TOWER_125: String = "tower_125"
const COMPARISON_MODE_TOWER_150: String = "tower_150"
const MIN_TOWER_VISUAL_SCALE: float = 1.0
const MAX_TOWER_VISUAL_SCALE: float = 1.5
const POLISH_Z_INDEX: int = -15

var _manifest: Dictionary = {}
var _manifest_errors: PackedStringArray = PackedStringArray()

func _ready() -> void:
	# Render-only hook point for premium arena cosmetics. This node must not read
	# or mutate OpsState/SimState, and must never feed gameplay hashes.
	z_index = POLISH_Z_INDEX
	set_meta("render_only", true)
	set_meta("gameplay_affects_state", false)
	set_meta("premium_arena_polish", true)
	set_process(false)
	set_physics_process(false)
	load_manifest()
	apply_runtime_settings()

static func is_polish_enabled() -> bool:
	match comparison_mode():
		COMPARISON_MODE_BASELINE:
			return false
		COMPARISON_MODE_POLISH, COMPARISON_MODE_TOWER_110, COMPARISON_MODE_TOWER_125, COMPARISON_MODE_TOWER_150:
			return true
	return bool(ProjectSettings.get_setting(SETTINGS_POLISH_ENABLED, DEFAULT_POLISH_ENABLED))

static func tower_visual_scale() -> float:
	match comparison_mode():
		COMPARISON_MODE_BASELINE, COMPARISON_MODE_POLISH:
			return DEFAULT_TOWER_VISUAL_SCALE
		COMPARISON_MODE_TOWER_110:
			return 1.10
		COMPARISON_MODE_TOWER_125:
			return 1.25
		COMPARISON_MODE_TOWER_150:
			return 1.50
	var raw: Variant = ProjectSettings.get_setting(SETTINGS_TOWER_VISUAL_SCALE, DEFAULT_TOWER_VISUAL_SCALE)
	var scale: float = DEFAULT_TOWER_VISUAL_SCALE
	if raw is int or raw is float:
		scale = float(raw)
	return clampf(scale, MIN_TOWER_VISUAL_SCALE, MAX_TOWER_VISUAL_SCALE)

static func comparison_mode() -> String:
	var mode: String = str(ProjectSettings.get_setting(SETTINGS_COMPARISON_MODE, DEFAULT_COMPARISON_MODE)).strip_edges().to_lower()
	if mode in comparison_modes():
		return mode
	return DEFAULT_COMPARISON_MODE

static func comparison_modes() -> PackedStringArray:
	return PackedStringArray([
		COMPARISON_MODE_SETTINGS,
		COMPARISON_MODE_BASELINE,
		COMPARISON_MODE_POLISH,
		COMPARISON_MODE_TOWER_110,
		COMPARISON_MODE_TOWER_125,
		COMPARISON_MODE_TOWER_150
	])

static func apply_comparison_mode(mode: String) -> void:
	var normalized: String = mode.strip_edges().to_lower()
	if not (normalized in comparison_modes()):
		normalized = DEFAULT_COMPARISON_MODE
	ProjectSettings.set_setting(SETTINGS_COMPARISON_MODE, normalized)
	match normalized:
		COMPARISON_MODE_BASELINE:
			ProjectSettings.set_setting(SETTINGS_POLISH_ENABLED, false)
			ProjectSettings.set_setting(SETTINGS_TOWER_VISUAL_SCALE, DEFAULT_TOWER_VISUAL_SCALE)
		COMPARISON_MODE_POLISH:
			ProjectSettings.set_setting(SETTINGS_POLISH_ENABLED, true)
			ProjectSettings.set_setting(SETTINGS_TOWER_VISUAL_SCALE, DEFAULT_TOWER_VISUAL_SCALE)
		COMPARISON_MODE_TOWER_110:
			ProjectSettings.set_setting(SETTINGS_POLISH_ENABLED, true)
			ProjectSettings.set_setting(SETTINGS_TOWER_VISUAL_SCALE, 1.10)
		COMPARISON_MODE_TOWER_125:
			ProjectSettings.set_setting(SETTINGS_POLISH_ENABLED, true)
			ProjectSettings.set_setting(SETTINGS_TOWER_VISUAL_SCALE, 1.25)
		COMPARISON_MODE_TOWER_150:
			ProjectSettings.set_setting(SETTINGS_POLISH_ENABLED, true)
			ProjectSettings.set_setting(SETTINGS_TOWER_VISUAL_SCALE, 1.50)

func apply_runtime_settings() -> void:
	visible = is_polish_enabled()
	z_index = POLISH_Z_INDEX
	set_meta("render_only", true)
	set_meta("gameplay_affects_state", false)
	set_meta("premium_arena_polish", true)
	set_process(false)
	set_physics_process(false)

func set_polish_enabled_for_preview(enabled: bool) -> void:
	visible = enabled

func load_manifest() -> Dictionary:
	_manifest_errors = PackedStringArray()
	_manifest = load_manifest_from_path(MANIFEST_PATH)
	_manifest_errors = validate_manifest(_manifest)
	return _manifest

func manifest() -> Dictionary:
	if _manifest.is_empty():
		load_manifest()
	return _manifest.duplicate(true)

func manifest_errors() -> PackedStringArray:
	if _manifest.is_empty():
		load_manifest()
	return _manifest_errors.duplicate()

func approved_entries(kind: String = "") -> Array:
	var data: Dictionary = manifest()
	var kinds: Array = [kind] if not kind.strip_edges().is_empty() else ["props", "vfx", "lighting"]
	var out: Array = []
	for entry_kind in kinds:
		var entries_v: Variant = data.get(entry_kind, [])
		if typeof(entries_v) != TYPE_ARRAY:
			continue
		for entry_any in entries_v as Array:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			if not bool(entry.get("enabled", true)):
				continue
			out.append(entry.duplicate(true))
	return out

static func load_manifest_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

static func validate_manifest(data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if data.is_empty():
		errors.append("manifest_missing_or_empty")
		return errors
	if int(data.get("version", 0)) <= 0:
		errors.append("version_missing")
	var defaults_v: Variant = data.get("defaults", {})
	if typeof(defaults_v) != TYPE_DICTIONARY:
		errors.append("defaults_missing")
	else:
		var defaults: Dictionary = defaults_v as Dictionary
		if not bool(defaults.get("render_only", false)):
			errors.append("defaults_render_only_not_true")
		if bool(defaults.get("affects_gameplay", true)):
			errors.append("defaults_affects_gameplay_not_false")
		if int(defaults.get("mobile_total_instance_limit", 0)) <= 0:
			errors.append("mobile_total_instance_limit_missing")
	for kind in ["props", "vfx", "lighting"]:
		var entries_v: Variant = data.get(kind, [])
		if typeof(entries_v) != TYPE_ARRAY:
			errors.append("%s_not_array" % kind)
			continue
		var entries: Array = entries_v as Array
		for i in range(entries.size()):
			var entry_v: Variant = entries[i]
			if typeof(entry_v) != TYPE_DICTIONARY:
				errors.append("%s_%d_not_dictionary" % [kind, i])
				continue
			_validate_manifest_entry(errors, kind, i, entry_v as Dictionary)
	return errors

static func _validate_manifest_entry(errors: PackedStringArray, kind: String, index: int, entry: Dictionary) -> void:
	var prefix: String = "%s_%d" % [kind, index]
	var id: String = str(entry.get("id", "")).strip_edges()
	if id.is_empty():
		errors.append("%s_id_missing" % prefix)
	var texture_path: String = str(entry.get("texture", "")).strip_edges()
	if texture_path.is_empty():
		errors.append("%s_texture_missing" % prefix)
	elif not texture_path.begins_with("res://assets/sprites/arena_polish/"):
		errors.append("%s_texture_outside_arena_polish" % prefix)
	elif not ResourceLoader.exists(texture_path):
		errors.append("%s_texture_missing_resource" % prefix)
	var zones_v: Variant = entry.get("allowed_placement_zones", [])
	if typeof(zones_v) != TYPE_ARRAY or (zones_v as Array).is_empty():
		errors.append("%s_allowed_placement_zones_missing" % prefix)
	if bool(entry.get("affects_gameplay", false)):
		errors.append("%s_affects_gameplay_true" % prefix)
