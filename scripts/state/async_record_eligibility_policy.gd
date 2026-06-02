class_name AsyncRecordEligibilityPolicy
extends RefCounted

const STYLE_BALANCER: String = "balancer"
const TIER_MEDIUM: String = "medium"
const META_VS_CPU_STYLE: String = "vs_cpu_style"
const META_VS_CPU_TIER: String = "vs_cpu_tier"
const META_VS_REMOTE_PROFILE: String = "vs_remote_profile"
const META_JUKEBOX_BOARD_ENABLED: String = "jukebox_board_enabled"

static func is_balancer_medium_record_eligible(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var style: String = _record_style(tree)
	var tier: String = _record_tier(tree)
	if bool(tree.get_meta(META_JUKEBOX_BOARD_ENABLED, false)):
		if style.is_empty():
			style = STYLE_BALANCER
		if tier.is_empty():
			tier = TIER_MEDIUM
	return style == STYLE_BALANCER and tier == TIER_MEDIUM

static func _record_style(tree: SceneTree) -> String:
	var style: String = str(tree.get_meta(META_VS_CPU_STYLE, "")).strip_edges().to_lower()
	if not style.is_empty():
		return style
	var remote_any: Variant = tree.get_meta(META_VS_REMOTE_PROFILE, {})
	if typeof(remote_any) == TYPE_DICTIONARY:
		var remote: Dictionary = remote_any as Dictionary
		style = str(remote.get("style", remote.get("bot_style", ""))).strip_edges().to_lower()
	return style

static func _record_tier(tree: SceneTree) -> String:
	var tier: String = str(tree.get_meta(META_VS_CPU_TIER, "")).strip_edges().to_lower()
	if not tier.is_empty():
		return tier
	var remote_any: Variant = tree.get_meta(META_VS_REMOTE_PROFILE, {})
	if typeof(remote_any) == TYPE_DICTIONARY:
		var remote: Dictionary = remote_any as Dictionary
		tier = str(remote.get("tier", remote.get("difficulty", remote.get("bot_tier", "")))).strip_edges().to_lower()
	return tier
