class_name ProgressiveConfig
extends RefCounted

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")
const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")

const MODE_ID: String = "PROGRESSIVE"
const DEFAULT_STAGE_COUNT: int = 18
const MIN_STAGE_COUNT: int = 1
const MAX_STAGE_COUNT: int = 30
const HUMAN_OWNER_ID: int = 1

const STAR_NONE: int = 0
const STAR_PASS: int = 1
const STAR_TARGET: int = 2
const STAR_FAST: int = 3
const STAR_CRUSH: int = 4
const STAR_MAX: int = STAR_CRUSH

const TWO_STAR_BASE_MS: int = 90 * 1000
const TWO_STAR_PER_CONQUERABLE_HIVE_MS: int = 15 * 1000
const THREE_STAR_FACTOR: float = 0.82
const FOUR_STAR_FACTOR: float = 0.65
const BOT_ATTACK_GRACE_MS: int = 20 * 1000

const BOT_TIER_EASY: String = "easy"
const BOT_TIER_MEDIUM: String = "medium"
const BOT_TIER_HARD: String = "hard"
const BOT_TIERS: Array[String] = [BOT_TIER_EASY, BOT_TIER_MEDIUM, BOT_TIER_HARD]
const BOT_STYLES_EASY: Array[String] = ["balancer", "turtle", "greedy"]
const BOT_STYLES_MEDIUM: Array[String] = ["balancer", "turtle", "raider", "greedy", "swarm_lord"]
const BOT_STYLES_HARD: Array[String] = ["raider", "swarm_lord", "greedy", "turtle", "balancer"]

const DEFAULT_STAGE_MAP_IDS: Array[String] = [
	"MAP_nomansland__545__v01_top2_sides__1p",
	"MAP_nomansland__323__v01_corners_midline_spine__1p",
	"MAP_nomansland__545__v17_four_corners_only__1p",
	"MAP_nomansland__444__v01_pinched_spine__1p",
	"MAP_nomansland__545__v03_top_half_vs_bottom_half__1p",
	"MAP_nomansland__545__v04_top_corners_vs_bottom_corners__1p",
	"MAP_nomansland__545__v05_diagonal_TL_vs_BR__1p",
	"MAP_nomansland__545__v06_diagonal_BL_vs_TR__1p",
	"MAP_nomansland__545__v07_top_spine_vs_bottom_spine__1p",
	"MAP_nomansland__545__v08_spine_knife_fight__1p",
	"MAP_nomansland__545__v09_triad_top_vs_bottom__1p",
	"MAP_nomansland__545__v10_side_ladders_no_corners__1p",
	"MAP_nomansland__545__v11_outer_vs_inner__1p",
	"MAP_nomansland__545__v12_cross_spine_anchors__1p",
	"MAP_nomansland__545__v13_top3_each__1p",
	"MAP_nomansland__545__v14_bottom3_each__1p",
	"MAP_nomansland__545__v15_spine_ends_duel__1p",
	"MAP_nomansland__545__v18_two_hubs_each__1p"
]


static func normalize_stage_count(stage_count: int) -> int:
	return clampi(stage_count, MIN_STAGE_COUNT, MAX_STAGE_COUNT)


static func threshold_ms_for_hives(conquerable_hives: int) -> Dictionary:
	var hive_count: int = maxi(1, conquerable_hives)
	var two_star_ms: int = TWO_STAR_BASE_MS + (hive_count * TWO_STAR_PER_CONQUERABLE_HIVE_MS)
	var three_star_ms: int = maxi(1, int(round(float(two_star_ms) * THREE_STAR_FACTOR)))
	var four_star_ms: int = maxi(1, int(round(float(two_star_ms) * FOUR_STAR_FACTOR)))
	three_star_ms = mini(three_star_ms, two_star_ms - 1)
	four_star_ms = mini(four_star_ms, three_star_ms - 1)
	return {
		"four_star_ms": four_star_ms,
		"three_star_ms": three_star_ms,
		"two_star_ms": two_star_ms
	}


static func stars_for_elapsed(elapsed_ms: int, thresholds_ms: Dictionary, won: bool = true, win_reason: String = "domination") -> int:
	if not won:
		return STAR_NONE
	var reason: String = win_reason.strip_edges().to_lower()
	if not reason.is_empty() and reason != "domination" and reason != "capture_all" and reason != "conquest" and reason != "elimination":
		return STAR_NONE
	var elapsed: int = maxi(0, elapsed_ms)
	var four_star_ms: int = maxi(1, int(thresholds_ms.get("four_star_ms", 0)))
	var three_star_ms: int = maxi(four_star_ms + 1, int(thresholds_ms.get("three_star_ms", 0)))
	var two_star_ms: int = maxi(three_star_ms + 1, int(thresholds_ms.get("two_star_ms", 0)))
	if elapsed <= four_star_ms:
		return STAR_CRUSH
	if elapsed <= three_star_ms:
		return STAR_FAST
	if elapsed <= two_star_ms:
		return STAR_TARGET
	return STAR_PASS


static func conquerable_hive_count_from_map_data(map_data: Dictionary, human_owner_id: int = HUMAN_OWNER_ID) -> int:
	var hives_any: Variant = map_data.get("hives", [])
	if typeof(hives_any) == TYPE_ARRAY and not (hives_any as Array).is_empty():
		return _count_conquerable_hive_entries(hives_any as Array, human_owner_id)
	var nodes_any: Variant = map_data.get("nodes", [])
	if typeof(nodes_any) == TYPE_ARRAY:
		var hive_nodes: Array = []
		for node_any in nodes_any as Array:
			if typeof(node_any) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = node_any as Dictionary
			if str(node.get("kind", "")).strip_edges().to_lower() == "hive":
				hive_nodes.append(node)
		return _count_conquerable_hive_entries(hive_nodes, human_owner_id)
	return 1


static func progression_scaling_for_stage(stage_index: int, stage_count: int = DEFAULT_STAGE_COUNT) -> Dictionary:
	var count: int = normalize_stage_count(stage_count)
	var index: int = clampi(stage_index, 0, count - 1)
	var global_t: float = 0.0 if count <= 1 else float(index) / float(count - 1)
	var medium_start: int = maxi(1, int(floor(float(count) * 0.28)))
	var hard_start: int = maxi(medium_start + 1, int(floor(float(count) * 0.67)))
	var tier: String = BOT_TIER_EASY
	var style_pool: Array[String] = BOT_STYLES_EASY
	if index >= hard_start:
		tier = BOT_TIER_HARD
		style_pool = BOT_STYLES_HARD
	elif index >= medium_start:
		tier = BOT_TIER_MEDIUM
		style_pool = BOT_STYLES_MEDIUM
	var npc_power_bonus: int = int(round(lerpf(0.0, 12.0, global_t)))
	var bot_start_power_bonus: int = int(round(lerpf(0.0, 8.0, global_t)))
	var player_start_power_delta: int = -int(round(lerpf(0.0, 4.0, global_t)))
	if tier == BOT_TIER_EASY:
		var easy_span: int = maxi(1, medium_start - 1)
		var easy_t: float = 0.0 if easy_span <= 0 else float(index) / float(easy_span)
		npc_power_bonus = int(round(lerpf(0.0, 2.0, easy_t)))
		bot_start_power_bonus = 0
		player_start_power_delta = 0
	elif tier == BOT_TIER_MEDIUM:
		var medium_span: int = maxi(1, hard_start - medium_start - 1)
		var medium_t: float = 0.0 if medium_span <= 0 else float(index - medium_start) / float(medium_span)
		npc_power_bonus = int(round(lerpf(3.0, 7.0, medium_t)))
		bot_start_power_bonus = int(round(lerpf(1.0, 4.0, medium_t)))
		player_start_power_delta = -int(round(lerpf(0.0, 2.0, medium_t)))
	return {
		"bot_tier": tier,
		"bot_style": style_pool[index % style_pool.size()],
		"npc_power_bonus": npc_power_bonus,
		"bot_start_power_bonus": bot_start_power_bonus,
		"player_start_power_delta": player_start_power_delta
	}


static func build_stage_plan(stage_count: int = DEFAULT_STAGE_COUNT) -> Array[Dictionary]:
	var count: int = normalize_stage_count(stage_count)
	var out: Array[Dictionary] = []
	for i in range(count):
		var map_id: String = DEFAULT_STAGE_MAP_IDS[i % DEFAULT_STAGE_MAP_IDS.size()]
		var map_path: String = resolve_stage_map_path(map_id)
		var loaded: Dictionary = {}
		var hive_count: int = 1
		if not map_path.is_empty():
			loaded = MAP_LOADER.load_map(map_path)
			if bool(loaded.get("ok", false)):
				hive_count = conquerable_hive_count_from_map_data(loaded.get("data", {}) as Dictionary)
		var scaling: Dictionary = progression_scaling_for_stage(i, count)
		out.append({
			"mode_id": MODE_ID,
			"stage_index": i,
			"stage_number": i + 1,
			"map_id": map_id,
			"map_path": map_path,
			"conquerable_hive_count": hive_count,
			"thresholds_ms": threshold_ms_for_hives(hive_count),
			"bot_tier": str(scaling.get("bot_tier", BOT_TIER_EASY)),
			"bot_style": str(scaling.get("bot_style", "balancer")),
			"npc_power_bonus": int(scaling.get("npc_power_bonus", 0)),
			"bot_start_power_bonus": int(scaling.get("bot_start_power_bonus", 0)),
			"player_start_power_delta": int(scaling.get("player_start_power_delta", 0))
		})
	return out


static func launch_options_for_stage(stage: Dictionary) -> Dictionary:
	return {
		"mode_id": MODE_ID,
		"progressive_stage_index": int(stage.get("stage_index", 0)),
		"progressive_stage_number": int(stage.get("stage_number", 1)),
		"progressive_thresholds_ms": (stage.get("thresholds_ms", {}) as Dictionary).duplicate(true),
		"progressive_conquerable_hive_count": int(stage.get("conquerable_hive_count", 1)),
		"progressive_npc_power_bonus": int(stage.get("npc_power_bonus", 0)),
		"progressive_bot_start_power_bonus": int(stage.get("bot_start_power_bonus", 0)),
		"progressive_player_start_power_delta": int(stage.get("player_start_power_delta", 0)),
		"progressive_bot_attack_grace_ms": BOT_ATTACK_GRACE_MS,
		"progressive_human_owner_id": HUMAN_OWNER_ID,
		"progressive_bot_attack_grace_broken": false,
		"vs_cpu_style": str(stage.get("bot_style", "balancer")),
		"vs_cpu_tier": str(stage.get("bot_tier", BOT_TIER_EASY)),
		"stage_map_paths": [str(stage.get("map_path", ""))]
	}


static func resolve_stage_map_path(map_id: String) -> String:
	var resolved: String = MAP_LOADER._resolve_map_path(map_id)
	if not resolved.is_empty():
		return resolved
	var direct: String = "res://maps/_future/nomansland/%s.json" % map_id.strip_edges()
	if FileAccess.file_exists(direct):
		return direct
	return ""


static func _count_conquerable_hive_entries(entries: Array, human_owner_id: int) -> int:
	var count: int = 0
	for entry_any in entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var owner_id: int = _owner_id_for_entry(entry)
		if owner_id != human_owner_id:
			count += 1
	return maxi(1, count)


static func _owner_id_for_entry(entry: Dictionary) -> int:
	if entry.has("owner_id"):
		return int(entry.get("owner_id", 0))
	if entry.has("team_id"):
		return int(entry.get("team_id", 0))
	if entry.has("owner"):
		return MAP_SCHEMA.owner_to_owner_id(str(entry.get("owner", "")))
	if entry.has("team"):
		return MAP_SCHEMA.owner_to_owner_id(str(entry.get("team", "")))
	return 0
