class_name RankConfig
extends Resource

@export var enabled: bool = true

# Wax gain formula controls.
@export var base_gain: float = 100.0
@export var opponent_strength_exponent: float = 0.6
@export var opponent_strength_min: float = 0.6
@export var opponent_strength_max: float = 1.6
@export var losses_subtract_wax: bool = true
@export var loss_scale: float = 0.55

# Mode modifiers.
@export var mode_modifiers: Dictionary = {
	"STANDARD": 1.0,
	"TOURNAMENT": 1.5,
	"MONEY_MATCH": 2.0,
	"STEROIDS_LEAGUE": 3.0
}

# Decay controls.
@export var inactivity_grace_days: int = 14
@export var daily_decay_rate: float = 0.0075
@export var wax_floor: float = 100.0

# Tier unlock + distribution controls.
@export var players_per_tier_to_unlock: int = 300
@export var full_open_top_tier_weight: float = 1.0
@export var full_open_middle_weight_multiplier_vs_top: float = 1.25
@export var full_open_bottom_weight_multiplier_vs_middle: float = 1.0

# Dynamic tiers by percentile.
@export var tier_bands: Array[Dictionary] = [
	{"id": "DRONE", "name": "Drone", "min_pct": 0.0000, "max_pct": 0.2000},
	{"id": "WORKER", "name": "Worker", "min_pct": 0.2000, "max_pct": 0.3500},
	{"id": "SOLDIER", "name": "Soldier", "min_pct": 0.3500, "max_pct": 0.5000},
	{"id": "HONEY_BEE", "name": "Honey Bee", "min_pct": 0.5000, "max_pct": 0.6500},
	{"id": "BUMBLEBEE", "name": "Bumblebee", "min_pct": 0.6500, "max_pct": 0.8000},
	{"id": "QUEEN", "name": "Queen", "min_pct": 0.8000, "max_pct": 0.9000},
	{"id": "YELLOWJACKET", "name": "Yellowjacket", "min_pct": 0.9000, "max_pct": 0.9400},
	{"id": "RED_WASP", "name": "Red Wasp", "min_pct": 0.9400, "max_pct": 0.9650},
	{"id": "HORNET", "name": "Hornet", "min_pct": 0.9650, "max_pct": 0.9800},
	{"id": "BALD_FACED_HORNET", "name": "Bald-Faced Hornet", "min_pct": 0.9800, "max_pct": 0.9890},
	{"id": "KILLER_BEE", "name": "Killer Bee", "min_pct": 0.9890, "max_pct": 0.9950},
	{"id": "ASIAN_GIANT_HORNET", "name": "Asian Giant Hornet (Murder Hornet)", "min_pct": 0.9950, "max_pct": 0.9980},
	{"id": "EXECUTIONER_WASP", "name": "Executioner Wasp", "min_pct": 0.9980, "max_pct": 0.9990},
	{"id": "SCORPION_WASP", "name": "Scorpion Wasp", "min_pct": 0.9990, "max_pct": 1.0000},
	{"id": "COW_KILLER", "name": "Cow Killer", "min_pct": 1.0000, "max_pct": 1.0000}
]
@export var apex_top_count: int = 5
@export var promotion_buffer: float = 0.005
@export var color_buffer: float = 0.002
@export var tier_demotion_grace_slots: int = 5

# Color quintiles (no gameplay impact).
@export var color_quintiles: Array[String] = ["GREEN", "BLUE", "RED", "BLACK", "YELLOW"]

# Matchmaking defaults.
@export var mm_same_tier_priority: float = 25.0
@export var mm_same_color_priority: float = 10.0
@export var mm_base_wax_tolerance: float = 120.0
@export var mm_wax_tolerance_per_sec: float = 4.0
@export var mm_max_wax_tolerance: float = 800.0
@export var default_region: String = "GLOBAL"
@export var ceremony_first_time_only: bool = true

func normalized_mode_modifier(mode_name: String) -> float:
	var key: String = mode_name.strip_edges().to_upper()
	return float(mode_modifiers.get(key, 1.0))

func normalized_color_quintiles() -> Array[String]:
	var out: Array[String] = []
	for color_any in color_quintiles:
		var color_name: String = str(color_any).strip_edges().to_upper()
		if color_name == "":
			continue
		out.append(color_name)
	if out.is_empty():
		out = ["GREEN", "BLUE", "RED", "BLACK", "YELLOW"]
	return out

func ordered_tier_ids() -> Array[String]:
	var out: Array[String] = []
	for band_any in tier_bands:
		if typeof(band_any) != TYPE_DICTIONARY:
			continue
		var band: Dictionary = band_any as Dictionary
		var tier_id: String = str(band.get("id", "")).strip_edges().to_upper()
		if tier_id == "":
			continue
		out.append(tier_id)
	return out

func opened_tier_count(total_players: int) -> int:
	var tiers: Array[String] = ordered_tier_ids()
	if tiers.is_empty():
		return 0
	var unlock_size: int = maxi(1, players_per_tier_to_unlock)
	var safe_total: int = maxi(1, total_players)
	var opened: int = int(floor(float(safe_total) / float(unlock_size))) + 1
	return clampi(opened, 1, tiers.size())

func tier_band_by_id(tier_id: String) -> Dictionary:
	var target: String = tier_id.strip_edges().to_upper()
	for band_any in tier_bands:
		if typeof(band_any) != TYPE_DICTIONARY:
			continue
		var band: Dictionary = band_any as Dictionary
		if str(band.get("id", "")).strip_edges().to_upper() == target:
			return band
	return {}

func tier_index(tier_id: String) -> int:
	var tiers: Array[String] = ordered_tier_ids()
	var target: String = tier_id.strip_edges().to_upper()
	for i in range(tiers.size()):
		if tiers[i] == target:
			return i
	return -1

func tier_min_percentile(tier_id: String) -> float:
	var band: Dictionary = tier_band_by_id(tier_id)
	return clampf(float(band.get("min_pct", 0.0)), 0.0, 1.0)

func tier_min_percentile_for_population(tier_id: String, total_players: int) -> float:
	var target: String = tier_id.strip_edges().to_upper()
	var bands: Array[Dictionary] = tier_percentile_bands(total_players)
	for band in bands:
		if str(band.get("id", "")).strip_edges().to_upper() != target:
			continue
		return clampf(float(band.get("min_pct", 0.0)), 0.0, 1.0)
	return 0.0

func is_tier_open(tier_id: String, total_players: int) -> bool:
	var target: String = tier_id.strip_edges().to_upper()
	if target == "":
		return false
	var bands: Array[Dictionary] = tier_percentile_bands(total_players)
	for band in bands:
		if str(band.get("id", "")).strip_edges().to_upper() == target:
			return true
	return false

func tier_percentile_bands(total_players: int) -> Array[Dictionary]:
	var all_tiers: Array[String] = ordered_tier_ids()
	var out: Array[Dictionary] = []
	if all_tiers.is_empty():
		return out
	var open_count: int = opened_tier_count(total_players)
	var active_tiers: Array[String] = []
	for i in range(mini(open_count, all_tiers.size())):
		active_tiers.append(all_tiers[i])
	if active_tiers.is_empty():
		return out
	if active_tiers.size() < all_tiers.size():
		return _build_even_bands(active_tiers)
	return _build_full_open_bands(active_tiers)

func resolve_tier_for_percentile(percentile: float, rank_position: int, total_players: int) -> String:
	var p: float = clampf(percentile, 0.0, 1.0)
	var _safe_rank: int = maxi(1, rank_position)
	var safe_total: int = maxi(1, total_players)
	var bands: Array[Dictionary] = tier_percentile_bands(safe_total)
	if bands.is_empty():
		return "DRONE"
	for band in bands:
		var tier_id: String = str(band.get("id", "")).strip_edges().to_upper()
		if tier_id.is_empty():
			continue
		var min_pct: float = clampf(float(band.get("min_pct", 0.0)), 0.0, 1.0)
		var max_pct: float = clampf(float(band.get("max_pct", 1.0)), 0.0, 1.0)
		if p >= min_pct and (p < max_pct or is_equal_approx(p, max_pct) or is_equal_approx(max_pct, 1.0)):
			return tier_id
	return "DRONE"

func resolve_color_for_percentile(tier_id: String, percentile: float) -> String:
	var colors: Array[String] = normalized_color_quintiles()
	var _tier_id: String = tier_id
	var p: float = clampf(percentile, 0.0, 1.0)
	var color_index: int = clampi(int(floor(p * float(colors.size()))), 0, colors.size() - 1)
	return colors[color_index]

func _build_even_bands(active_tiers: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if active_tiers.is_empty():
		return out
	var step: float = 1.0 / float(active_tiers.size())
	for i in range(active_tiers.size()):
		var min_pct: float = step * float(i)
		var max_pct: float = step * float(i + 1)
		if i == active_tiers.size() - 1:
			max_pct = 1.0
		out.append({
			"id": active_tiers[i],
			"min_pct": min_pct,
			"max_pct": max_pct
		})
	return out

func _build_full_open_bands(active_tiers: Array[String]) -> Array[Dictionary]:
	if active_tiers.size() < 11:
		return _build_even_bands(active_tiers)
	var out: Array[Dictionary] = []
	var top_weight: float = maxf(0.0001, full_open_top_tier_weight)
	var middle_weight: float = top_weight * maxf(0.0001, full_open_middle_weight_multiplier_vs_top)
	var bottom_weight: float = middle_weight * maxf(0.0001, full_open_bottom_weight_multiplier_vs_middle)
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for i in range(active_tiers.size()):
		var w: float = middle_weight
		if i < 5:
			w = bottom_weight
		elif i >= active_tiers.size() - 5:
			w = top_weight
		weights.append(w)
		total_weight += w
	if total_weight <= 0.0:
		return _build_even_bands(active_tiers)
	var cursor: float = 0.0
	for i in range(active_tiers.size()):
		var min_pct: float = cursor
		cursor += weights[i] / total_weight
		var max_pct: float = cursor
		if i == active_tiers.size() - 1:
			max_pct = 1.0
		out.append({
			"id": active_tiers[i],
			"min_pct": min_pct,
			"max_pct": max_pct
		})
	return out
