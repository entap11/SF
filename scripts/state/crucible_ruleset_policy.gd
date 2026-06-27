class_name CrucibleRulesetPolicy
extends RefCounted

const RULESET_STANDARD: String = "STANDARD"
const RULESET_CRUCIBLE: String = "CRUCIBLE"

const TREE_META_RULESET: String = "vs_ruleset"
const TREE_META_CRUCIBLE: String = "vs_crucible"

const RESULT_SOURCE_AUTHORITATIVE_SIM: String = "AUTHORITATIVE_SIM"
const RESULT_SOURCE_SERVER_MATCH_RESULT: String = "SERVER_MATCH_RESULT"
const RESULT_SOURCE_LOCAL_DEV_SIM: String = "LOCAL_DEV_SIM"
const RESULT_SOURCE_UI: String = "UI"

static func normalized_ruleset(ruleset: String) -> String:
	var clean: String = ruleset.strip_edges().to_upper()
	if clean == RULESET_CRUCIBLE:
		return RULESET_CRUCIBLE
	return RULESET_STANDARD

static func is_crucible_ruleset(ruleset: String) -> bool:
	return normalized_ruleset(ruleset) == RULESET_CRUCIBLE

static func is_crucible_tree(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var ruleset: String = normalized_ruleset(str(tree.get_meta(TREE_META_RULESET, "")))
	if ruleset == RULESET_CRUCIBLE:
		return true
	return bool(tree.get_meta(TREE_META_CRUCIBLE, false))

static func apply_crucible_tree_meta(tree: SceneTree) -> void:
	if tree == null:
		return
	tree.set_meta(TREE_META_RULESET, RULESET_CRUCIBLE)
	tree.set_meta(TREE_META_CRUCIBLE, true)

static func clear_ruleset_tree_meta(tree: SceneTree) -> void:
	if tree == null:
		return
	if tree.has_meta(TREE_META_RULESET):
		tree.remove_meta(TREE_META_RULESET)
	if tree.has_meta(TREE_META_CRUCIBLE):
		tree.remove_meta(TREE_META_CRUCIBLE)

static func allowed_result_sources(local_dev_settlement_enabled: bool) -> Array[String]:
	var out: Array[String] = [
		RESULT_SOURCE_AUTHORITATIVE_SIM,
		RESULT_SOURCE_SERVER_MATCH_RESULT
	]
	if local_dev_settlement_enabled:
		out.append(RESULT_SOURCE_LOCAL_DEV_SIM)
	return out

static func result_source_allowed(result_source: String, local_dev_settlement_enabled: bool) -> bool:
	return allowed_result_sources(local_dev_settlement_enabled).has(result_source.strip_edges().to_upper())

static func purity_requirements() -> Dictionary:
	return {
		"buff_selection_enabled": false,
		"buff_activation_enabled": false,
		"buff_effects_enabled": false,
		"consumables_enabled": false,
		"loadout_ui_enabled": false,
		"battle_pass_gameplay_modifiers_enabled": false,
		"paid_stat_advantages_enabled": false,
		"store_prompts_enabled": false,
		"honey_rewards_enabled": false,
		"nectar_rewards_enabled": false,
		"normal_rank_wax_payout_enabled": false
	}
