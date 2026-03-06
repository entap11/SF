class_name RankPromotionResolver
extends RefCounted

const RankConfigScript = preload("res://scripts/state/rank_config.gd")

const APEX_TIERS: Array[String] = ["EXECUTIONER_WASP", "SCORPION_WASP", "COW_KILLER"]

func resolve_player(
		player_record: Dictionary,
		percentile: float,
		rank_position: int,
		total_players: int,
		config: RankConfigScript
	) -> Dictionary:
	var tiers: Array[String] = config.ordered_tier_ids()
	var current_tier: String = str(player_record.get("tier_id", "DRONE")).strip_edges().to_upper()
	var current_tier_index: int = _index_of(tiers, current_tier)
	if current_tier_index < 0:
		current_tier = "DRONE"
		current_tier_index = _index_of(tiers, current_tier)
	var target_tier: String = config.resolve_tier_for_percentile(percentile, rank_position, total_players)
	var target_tier_index: int = _index_of(tiers, target_tier)

	var resolved_tier: String = current_tier
	var tier_promoted: bool = false
	var tier_demoted: bool = false
	if current_tier_index < 0:
		resolved_tier = target_tier
	elif target_tier_index > current_tier_index:
		resolved_tier = target_tier
		tier_promoted = true
	elif target_tier_index < current_tier_index:
		resolved_tier = _resolve_demotion_tier(
			current_tier,
			target_tier,
			percentile,
			total_players,
			config,
			tiers
		)
		tier_demoted = _index_of(tiers, resolved_tier) < current_tier_index

	var history_any: Variant = player_record.get("promotion_history", {})
	var history: Dictionary = (history_any as Dictionary).duplicate(true) if typeof(history_any) == TYPE_DICTIONARY else {}
	if history.is_empty():
		history[current_tier] = true
	var first_time_tier_promotion: bool = false
	if tier_promoted:
		if not history.has(resolved_tier):
			first_time_tier_promotion = true
		history[resolved_tier] = true

	var current_color: String = str(player_record.get("color_id", "GREEN")).strip_edges().to_upper()
	var resolved_color: String = _resolve_color(
		config,
		resolved_tier,
		current_tier,
		current_color,
		percentile,
		total_players,
		tier_promoted,
		tier_demoted
	)
	var color_promoted: bool = false
	var color_demoted: bool = false
	var colors: Array[String] = config.normalized_color_quintiles()
	var old_color_index: int = _index_of(colors, current_color)
	var new_color_index: int = _index_of(colors, resolved_color)
	if new_color_index > old_color_index:
		color_promoted = true
	elif new_color_index < old_color_index:
		color_demoted = true

	var apex_active: bool = APEX_TIERS.has(resolved_tier)
	return {
		"tier_id": resolved_tier,
		"color_id": resolved_color,
		"tier_changed": resolved_tier != current_tier,
		"color_changed": resolved_color != current_color,
		"tier_promoted": tier_promoted,
		"tier_demoted": tier_demoted,
		"color_promoted": color_promoted,
		"color_demoted": color_demoted,
		"first_time_tier_promotion": first_time_tier_promotion,
		"promotion_history": history,
		"apex_active": apex_active
	}

func _resolve_demotion_tier(
		current_tier: String,
		target_tier: String,
		percentile: float,
		total_players: int,
		config: RankConfigScript,
		tiers: Array[String]
	) -> String:
	var idx_current: int = _index_of(tiers, current_tier)
	var idx_target: int = _index_of(tiers, target_tier)
	if idx_current < 0:
		return target_tier
	if idx_target < 0:
		idx_target = 0

	var idx: int = idx_current
	while idx > idx_target:
		var current_id: String = tiers[idx]
		if not config.is_tier_open(current_id, total_players):
			idx -= 1
			continue
		var min_pct: float = config.tier_min_percentile_for_population(current_id, total_players)
		var grace_slots: int = maxi(0, config.tier_demotion_grace_slots)
		var percentile_step: float = 1.0
		if total_players > 1:
			percentile_step = 1.0 / float(total_players - 1)
		var demotion_grace_pct: float = percentile_step * float(grace_slots)
		var demotion_floor: float = min_pct - config.promotion_buffer
		if grace_slots > 0:
			demotion_floor = min_pct - demotion_grace_pct
		if percentile < demotion_floor:
			idx -= 1
			continue
		break
	return tiers[idx]

func _resolve_color(
		config: RankConfigScript,
		resolved_tier: String,
		old_tier: String,
		current_color: String,
		percentile: float,
		total_players: int,
		tier_promoted: bool,
		tier_demoted: bool
	) -> String:
	var colors: Array[String] = config.normalized_color_quintiles()
	var target_color: String = config.resolve_color_for_tier_progress(resolved_tier, total_players)
	if tier_promoted or tier_demoted or resolved_tier != old_tier:
		return target_color

	var idx_current: int = _index_of(colors, current_color)
	if idx_current < 0:
		idx_current = 0
	var idx_target: int = _index_of(colors, target_color)
	if idx_target < 0:
		idx_target = idx_current
	if idx_target == idx_current:
		return current_color
	if idx_target > idx_current:
		return target_color

	var global_pct: float = clampf(percentile, 0.0, 1.0)
	var step: float = 1.0 / float(maxi(1, colors.size()))
	var current_color_start: float = float(idx_current) * step
	if global_pct < (current_color_start - config.color_buffer):
		return target_color
	return current_color

func _index_of(items: Array[String], value: String) -> int:
	for i in range(items.size()):
		if items[i] == value:
			return i
	return -1
