class_name SwarmPassConfig
extends Resource

enum PrestigeModel {
	HARD_BRICK,
	SOFT_CAP
}

@export var enabled: bool = true
@export var season_duration_days: int = 30
@export var total_levels: int = 100
@export var standard_level_end: int = 60
@export var advanced_level_end: int = 75
@export var prestige_level_start: int = 76
@export var apex_level_start: int = 91

@export var xp_per_level_standard: int = 100
@export var xp_per_level_advanced: int = 140
@export var xp_per_level_prestige: int = 185
@export var xp_per_level_apex: int = 240

@export var premium_multiplier: float = 1.18
@export var elite_multiplier: float = 1.30
@export var premium_price_usd: float = 9.99
@export var elite_price_usd: float = 14.99
@export var elite_async_access: bool = true

@export var prestige_model: int = PrestigeModel.SOFT_CAP

# Keys are pass levels in [76..100].
@export var hard_brick_caps: Dictionary = {
	"76": 3000,
	"77": 2500,
	"78": 2000,
	"79": 1600,
	"80": 1300,
	"81": 1100,
	"82": 950,
	"83": 820,
	"84": 700,
	"85": 600,
	"86": 520,
	"87": 450,
	"88": 380,
	"89": 320,
	"90": 280,
	"91": 230,
	"92": 190,
	"93": 150,
	"94": 120,
	"95": 90,
	"96": 60,
	"97": 40,
	"98": 25,
	"99": 12,
	"100": 5
}

# Keys are pass levels in [76..100].
@export var soft_variant_cutoffs: Dictionary = {
	"76": 5000,
	"77": 4500,
	"78": 4000,
	"79": 3500,
	"80": 3000,
	"81": 2600,
	"82": 2200,
	"83": 2000,
	"84": 1800,
	"85": 1600,
	"86": 1400,
	"87": 1200,
	"88": 1000,
	"89": 850,
	"90": 700,
	"91": 560,
	"92": 460,
	"93": 360,
	"94": 280,
	"95": 220,
	"96": 170,
	"97": 120,
	"98": 80,
	"99": 40,
	"100": 12
}

# Transparent Nectar award defaults used by authoritative event handlers.
@export var nectar_awards: Dictionary = {
	"match_completed_free": 8,
	"match_completed_money": 24,
	"async_completed": 6,
	"contest_participation": 10,
	"tournament_participation": 14,
	"tournament_placement_bonus": 20,
	"money_match_completed": 30
}
@export var store_kickback_nectar_per_usd: float = 6.0

func clamp_level(level: int) -> int:
	return clampi(level, 1, max(total_levels, 1))

func pass_xp_required_for_level(level: int) -> int:
	var clamped: int = clamp_level(level)
	if clamped <= standard_level_end:
		return max(xp_per_level_standard, 1)
	if clamped <= advanced_level_end:
		return max(xp_per_level_advanced, 1)
	if clamped < apex_level_start:
		return max(xp_per_level_prestige, 1)
	return max(xp_per_level_apex, 1)

func normalized_prestige_model() -> int:
	if prestige_model == PrestigeModel.HARD_BRICK:
		return PrestigeModel.HARD_BRICK
	return PrestigeModel.SOFT_CAP

