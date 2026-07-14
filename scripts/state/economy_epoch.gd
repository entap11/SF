class_name EconomyEpoch
extends RefCounted

# Bump this value only when all beta economy records must start from a clean slate.
# Client saves persist the applied value, so each epoch is applied exactly once.
const CURRENT: String = "beta_2026071301"
const STARTING_HONEY: int = 0
const SETTINGS_RESET_ENABLED: String = "swarmfront/economy/reset_enabled"
const DEV_ENV_RESET_ENABLED: String = "SF_ECONOMY_RESET_ENABLED"

static func reset_enabled() -> bool:
	return reset_enabled_for_runtime(
		OS.is_debug_build(),
		bool(ProjectSettings.get_setting(SETTINGS_RESET_ENABLED, false)),
		OS.get_environment(DEV_ENV_RESET_ENABLED)
	)

static func reset_enabled_for_runtime(is_debug_build: bool, project_enabled: bool, environment_value: String) -> bool:
	if project_enabled:
		return true
	# Environment overrides are intentionally ignored by production exports.
	if not is_debug_build:
		return false
	return environment_value.strip_edges().to_lower() in ["1", "true", "yes", "on"]
