class_name HiveGrowthRules
extends RefCounted

# Canonical hive growth tiers. These thresholds also govern outgoing lane
# capacity; presentation consumes the exported tier and must not duplicate them.
const TIER_SMALL: int = 1
const TIER_MEDIUM: int = 2
const TIER_LARGE: int = 3

const TIER_MEDIUM_MIN_POWER: int = 10
const TIER_LARGE_MIN_POWER: int = 25

static func tier_for_power(power: int) -> int:
	if power >= TIER_LARGE_MIN_POWER:
		return TIER_LARGE
	if power >= TIER_MEDIUM_MIN_POWER:
		return TIER_MEDIUM
	return TIER_SMALL

static func lane_budget_for_power(power: int) -> int:
	return tier_for_power(power)

static func tier_key(tier: int) -> String:
	match clampi(tier, TIER_SMALL, TIER_LARGE):
		TIER_MEDIUM:
			return "med"
		TIER_LARGE:
			return "large"
		_:
			return "small"
