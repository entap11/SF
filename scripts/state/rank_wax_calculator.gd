class_name RankWaxCalculator
extends RefCounted

const RankConfigScript = preload("res://scripts/state/rank_config.gd")

var _config: RankConfigScript = null

func configure(config: RankConfigScript) -> void:
	_config = config

func compute_gain(player_wax: float, opponent_wax: float, mode_name: String) -> float:
	if _config == null:
		return 0.0
	var safe_player: float = maxf(player_wax, 1.0)
	var safe_opponent: float = maxf(opponent_wax, 1.0)
	var ratio: float = safe_opponent / safe_player
	var modifier: float = pow(ratio, _config.opponent_strength_exponent)
	modifier = clampf(modifier, _config.opponent_strength_min, _config.opponent_strength_max)
	var mode_modifier: float = _config.normalized_mode_modifier(mode_name)
	var gain: float = _config.base_gain * modifier * mode_modifier
	return maxf(0.0, gain)

func compute_loss(player_wax: float, opponent_wax: float, mode_name: String) -> float:
	if _config == null:
		return 0.0
	if not _config.losses_subtract_wax:
		return 0.0
	var base_loss: float = compute_gain(player_wax, opponent_wax, mode_name)
	return maxf(0.0, base_loss * maxf(0.0, _config.loss_scale))
