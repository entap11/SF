extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")

const ACH_BP_LEVEL_1: String = "ACH_BP_LEVEL_1"
const POWERBAR_UNLOCK_THEME_ID: String = "upgraded_dynamic"
const POWERBAR_FALLBACK_THEME_ID: String = "upgraded"
const DEBUG_TARGET_DISPLAY_NAME: String = "Swarmfather"

var _target_skip_logged: bool = false

func ensure_bp_level_achievements(bp_level: int) -> void:
	if bp_level < 1:
		return
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager == null:
		return
	if not _is_target_profile(profile_manager):
		return
	if not profile_manager.has_method("has_achievement"):
		return
	if bool(profile_manager.call("has_achievement", ACH_BP_LEVEL_1)):
		_apply_phase2_theme_if_needed(profile_manager)
		return
	if not profile_manager.has_method("grant_achievement"):
		return
	var granted: bool = bool(profile_manager.call("grant_achievement", ACH_BP_LEVEL_1))
	if not granted:
		return
	print("Granted ACH_BP_LEVEL_1")
	_apply_phase2_theme_if_needed(profile_manager)

func _apply_phase2_theme_if_needed(profile_manager: Node) -> void:
	if not profile_manager.has_method("set_powerbar_theme"):
		return
	var desired_theme: String = _resolve_unlock_theme(profile_manager)
	profile_manager.call("set_powerbar_theme", desired_theme)
	print("PowerBar theme set to %s" % desired_theme)

func _resolve_unlock_theme(profile_manager: Node) -> String:
	if not profile_manager.has_method("get_performance_mode"):
		return POWERBAR_UNLOCK_THEME_ID
	var mode: String = str(profile_manager.call("get_performance_mode")).strip_edges().to_lower()
	if mode == "performance":
		return POWERBAR_FALLBACK_THEME_ID
	return POWERBAR_UNLOCK_THEME_ID

func _is_target_profile(profile_manager: Node) -> bool:
	if not OS.is_debug_build():
		return true
	if DEBUG_TARGET_DISPLAY_NAME == "":
		return true
	if not profile_manager.has_method("get_display_name"):
		return true
	var display_name: String = str(profile_manager.call("get_display_name")).strip_edges()
	var is_target: bool = display_name.to_lower() == DEBUG_TARGET_DISPLAY_NAME.to_lower()
	if not is_target and not _target_skip_logged:
		_target_skip_logged = true
		SFLog.info("ACH_BP_LEVEL_TARGET_SKIP", {
			"target": DEBUG_TARGET_DISPLAY_NAME,
			"active": display_name
		})
	return is_target
