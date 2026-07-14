extends SceneTree

const EconomyEpochScript := preload("res://scripts/state/economy_epoch.gd")
const OpsConfigScript := preload("res://scripts/state/ops_config.gd")

var _failed: bool = false

func _initialize() -> void:
	_expect(EconomyEpochScript.CURRENT == "beta_2026071301", "Security Sprint 0 must not change the active economy epoch")
	_expect(not bool(ProjectSettings.get_setting("swarmfront/economy/reset_enabled", true)), "Godot reset must default disabled")
	_expect(str(ProjectSettings.get_setting("swarmfront/vs/backend_token", "not-empty")).is_empty(), "VS authority token must not be embedded in the project")
	_expect(str(ProjectSettings.get_setting("swarmfront/rank/backend_token", "not-empty")).is_empty(), "rank authority token must not be embedded in the project")
	_expect(
		not EconomyEpochScript.reset_enabled_for_runtime(false, false, "true"),
		"release exports must ignore the development environment reset override"
	)
	_expect(
		EconomyEpochScript.reset_enabled_for_runtime(true, false, "true"),
		"debug builds may use the explicitly named development reset override"
	)
	_expect(
		not EconomyEpochScript.reset_enabled_for_runtime(true, false, "false"),
		"debug reset override must also default closed"
	)
	_expect(
		not OpsConfigScript.rank_local_beta_fallback_allowed_for_runtime(false, true),
		"release exports must ignore a configured local Rank/Wax fallback"
	)
	_expect(
		not OpsConfigScript.rank_local_beta_fallback_allowed_for_runtime(false, false),
		"release local Rank/Wax fallback must default closed"
	)
	_expect(
		OpsConfigScript.rank_local_beta_fallback_allowed_for_runtime(true, true),
		"debug local Rank/Wax simulation requires its explicit debug flag"
	)
	if not _failed:
		print("ECONOMY_QUARANTINE_CONFIG_SMOKE: PASS")
	quit(1 if _failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("ECONOMY_QUARANTINE_CONFIG_SMOKE: %s" % message)
