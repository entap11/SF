class_name CrucibleConfig
extends Resource

const ROUND_FLOOR: String = "FLOOR"
const ROUND_NEAREST: String = "NEAREST"
const ROUND_CEIL: String = "CEIL"

@export var enabled: bool = true
@export var queue_enabled: bool = true
@export var wagering_enabled: bool = true
@export var ads_enabled: bool = true
@export var capacity_cap_enabled: bool = true
@export var settlement_enabled: bool = true
@export var earn_path_buttons_enabled: bool = false

@export var config_version: int = 1
@export var capacity_max: int = 100
@export var reserved_slots: int = 0
@export var priority_access_enabled: bool = false

@export var pre_ad_seconds: int = 25
@export var post_ad_seconds: int = 12
@export var banner_ads_enabled: bool = true
@export var ticker_ads_enabled: bool = false

@export var stake_bps: int = 0
@export var burn_bps: int = 0
@export var minimum_stake_millis: int = 1000
@export var rounding_mode: String = ROUND_FLOOR

@export var starting_crucible_wax_millis: int = 0
@export var launch_grant_enabled: bool = false
@export var launch_grant_millis: int = 0

@export var standard_pvp_win_earn_millis: int = 0
@export var standard_pvp_loss_earn_millis: int = 0
@export var tournament_placement_earn_millis: int = 0
@export var challenge_earn_millis: int = 0
@export var event_earn_millis: int = 0

@export var server_authoritative_settlement_required: bool = false
@export var local_dev_settlement_enabled: bool = true

func config_hash() -> String:
	var parts: Array[String] = [
		"v:%d" % config_version,
		"stake:%d" % stake_bps,
		"burn:%d" % burn_bps,
		"min:%d" % minimum_stake_millis,
		"round:%s" % rounding_mode.strip_edges().to_upper(),
		"wager:%s" % str(wagering_enabled)
	]
	return "|".join(parts).sha256_text()

func normalized_rounding_mode() -> String:
	var clean: String = rounding_mode.strip_edges().to_upper()
	if clean == ROUND_NEAREST or clean == ROUND_CEIL:
		return clean
	return ROUND_FLOOR
