class_name RankWaxCalculator
extends RefCounted

const RankConfigScript = preload("res://scripts/state/rank_config.gd")

var _config: RankConfigScript = null

func configure(config: RankConfigScript) -> void:
	_config = config

func compute_gain(_player_wax: float, _opponent_wax: float, mode_name: String, money_tier: int = 0) -> float:
	if _config == null:
		return 0.0
	return _config.match_win_wax(mode_name, money_tier)

func compute_loss(_player_wax: float, _opponent_wax: float, mode_name: String, money_tier: int = 0) -> float:
	if _config == null:
		return 0.0
	return _config.match_loss_wax(mode_name, money_tier)

func compute_contest_bonus(contest_scope: String, placement: int) -> float:
	if _config == null:
		return 0.0
	return _config.contest_placement_wax(contest_scope, placement)
