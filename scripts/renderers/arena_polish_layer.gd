extends Node2D
class_name ArenaPolishLayer

const SETTINGS_POLISH_ENABLED: String = "swarmfront/arena/premium_polish_enabled"
const SETTINGS_TOWER_VISUAL_SCALE: String = "swarmfront/arena/tower_visual_scale"
const SETTINGS_COMPARISON_MODE: String = "swarmfront/arena/polish_comparison_mode"
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

func _ready() -> void:
	# Render-only hook point for premium arena cosmetics. This node must not read
	# or mutate OpsState/SimState, and must never feed gameplay hashes.
	z_index = POLISH_Z_INDEX
	set_meta("render_only", true)
	set_meta("gameplay_affects_state", false)
	set_meta("premium_arena_polish", true)
	set_process(false)
	set_physics_process(false)
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
