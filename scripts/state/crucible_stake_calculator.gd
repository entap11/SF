class_name CrucibleStakeCalculator
extends RefCounted

const CrucibleConfigScript = preload("res://scripts/state/crucible_config.gd")
const STAKE_EACH_MILLIS: int = 1000
const WINNER_PAYOUT_MILLIS: int = 1800
const AWARD_RESERVE_MILLIS: int = 200

static func preview_stake(player_a_balance_millis: int, player_b_balance_millis: int, config: CrucibleConfigScript) -> Dictionary:
	if config == null:
		return _blocked("missing_config", "Crucible config is unavailable.")
	if not config.enabled or not config.queue_enabled:
		return _blocked("queue_disabled", "Crucible queue is disabled.")
	if not config.wagering_enabled:
		return _blocked("wagering_disabled", "Crucible wagering is disabled.")
	var a_balance: int = maxi(0, player_a_balance_millis)
	var b_balance: int = maxi(0, player_b_balance_millis)
	var minimum: int = maxi(1, config.minimum_stake_millis)
	if a_balance < minimum or b_balance < minimum:
		return _blocked("insufficient_wax", "Both players need Wax to enter.")
	var stake: int = STAKE_EACH_MILLIS
	var pot: int = stake * 2
	var burn: int = 0
	var payout: int = WINNER_PAYOUT_MILLIS
	return {
		"ok": true,
		"stake_each": stake,
		"stake_unit": "wax_millis",
		"pot": pot,
		"burn": burn,
		"award_reserve": AWARD_RESERVE_MILLIS,
		"winner_payout": payout,
		"config_version": config.config_version,
		"config_hash": config.config_hash()
	}

static func _round_millis(value: float, mode: String) -> int:
	match mode:
		CrucibleConfigScript.ROUND_CEIL:
			return int(ceil(value))
		CrucibleConfigScript.ROUND_NEAREST:
			return int(round(value))
		_:
			return int(floor(value))

static func _blocked(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"message": message
	}
