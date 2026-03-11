extends Node

signal run_requested(context: Dictionary)

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const CONTESTS_DIR := "res://data/contests"
const LEADERBOARDS_DIR := "res://data/leaderboards"
const ENTRY_SAVE_PATH := "user://contest_entries.json"
const TIMED_GAME_DEFAULT_MAP_COUNT := 3
const TIMED_GAME_MAP_COUNT_3 := 3
const TIMED_GAME_MAP_COUNT_5 := 5
const TIMED_GAME_SUPPORTED_MAP_COUNTS: Array[int] = [TIMED_GAME_MAP_COUNT_3, TIMED_GAME_MAP_COUNT_5]
const TIMED_GAME_MIN_PLAYERS := 5
const TIMED_GAME_MAX_PLAYERS := 10
const TIMED_GAME_DEFAULT_LIMIT_MS := 30 * 60 * 1000
const TIMED_GAME_MAIN_LEADERBOARD_THRESHOLD := 0.5
const DEFAULT_STAGE_RACE_MAP_IDS := [
	"MAP_nomansland__SBASE__1p",
	"MAP_nomansland__SN6__1p",
	"MAP_nomansland__GBASE__1p",
	"MAP_nomansland__GBASE__BR2__TR2__1p",
	"MAP_nomansland__GBASE__TB__1p"
]
const TIMED_RACE_DEFAULT_MAP_COUNT := TIMED_GAME_MAP_COUNT_3
const TIMED_RACE_SUPPORTED_MAP_COUNTS: Array[int] = TIMED_GAME_SUPPORTED_MAP_COUNTS
const TIMED_RACE_MIN_PLAYERS := 5
const TIMED_RACE_MAX_PLAYERS := 10
const TIMED_RACE_START_COUNTDOWN_SEC := 30
const MISS_N_OUT_MIN_PLAYERS := 4
const MISS_N_OUT_MAX_PLAYERS := 8
const MISS_N_OUT_DEFAULT_PLAYERS := 5
const MISS_N_OUT_DEFAULT_LIMIT_MS := 30 * 60 * 1000
const MISS_N_OUT_DNF_TIME_MS := 2147483647
const MISS_N_OUT_ACTION_KEEP_PLAYING := "keep_playing_for_practice"
const MISS_N_OUT_ACTION_RETURN_TO_LOBBY := "return_to_lobby"

var contests: Dictionary = {}
var player_entries: Dictionary = {}

func _ready() -> void:
	load_contests()
	_load_entries()

func build_contest_id(parts: Dictionary) -> String:
	var scope := str(parts.get("scope", "")).to_upper()
	var currency := str(parts.get("currency", "")).to_upper()
	var price := int(parts.get("price", 0))
	var time_slice := _normalize_time_slice(str(parts.get("time", "")))
	var suffix := str(parts.get("suffix", ""))
	var base := "%s_%s_%d_%s" % [scope, currency, price, time_slice]
	if not suffix.is_empty():
		base = "%s_%s" % [base, suffix]
	return base

func parse_contest_id(contest_id: String) -> Dictionary:
	var parts := contest_id.split("_")
	if parts.size() < 4:
		return {}
	var scope := str(parts[0]).to_upper()
	var currency := str(parts[1]).to_upper()
	var price := int(parts[2])
	var time_slice := _normalize_time_slice(str(parts[3]))
	var suffix := ""
	if parts.size() > 4:
		suffix = "_".join(parts.slice(4, parts.size()))
	return {
		"scope": scope,
		"currency": currency,
		"price": price,
		"time": time_slice,
		"suffix": suffix
	}

func normalize_contest_id(contest_id: String) -> String:
	var parts := parse_contest_id(contest_id)
	if parts.is_empty():
		return contest_id
	return build_contest_id(parts)

func load_contests() -> void:
	contests.clear()
	var dir := DirAccess.open(CONTESTS_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not _is_resource_file(file_name):
			continue
		var contest: ContestDef = _load_contest_def("%s/%s" % [CONTESTS_DIR, file_name], file_name)
		if contest == null:
			continue
		var normalized_id := normalize_contest_id(contest.id)
		if normalized_id.is_empty():
			continue
		if normalized_id != contest.id:
			contest.id = normalized_id
		var parts := parse_contest_id(normalized_id)
		if not parts.is_empty():
			if contest.scope.is_empty():
				contest.scope = str(parts.get("scope", contest.scope))
			if contest.currency.is_empty():
				contest.currency = str(parts.get("currency", contest.currency))
			if contest.price <= 0:
				contest.price = int(parts.get("price", contest.price))
			if contest.time_slice.is_empty():
				contest.time_slice = str(parts.get("time", contest.time_slice))
		if contest.mode.is_empty():
			contest.mode = "STAGE_RACE"
		if contest.map_ids.is_empty():
			contest.map_ids = PackedStringArray(DEFAULT_STAGE_RACE_MAP_IDS)
		else:
			contest.map_ids = _sanitize_stage_map_ids(contest.map_ids)
			if contest.map_ids.is_empty():
				contest.map_ids = PackedStringArray(DEFAULT_STAGE_RACE_MAP_IDS)
		if contest.name.is_empty():
			contest.name = "%s Stage Race — $%d" % [contest.scope, contest.price]
		contests[normalized_id] = contest

func get_contest(contest_id: String) -> ContestDef:
	return contests.get(normalize_contest_id(contest_id))

func _sanitize_stage_map_ids(map_ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for map_id_any in map_ids:
		var map_id: String = str(map_id_any).strip_edges()
		if map_id.is_empty():
			continue
		var resolved: String = MAP_LOADER._resolve_map_path(map_id)
		if resolved.is_empty():
			continue
		out.append(map_id)
	return out

func get_contests_by_scope(scope: String) -> Array[ContestDef]:
	var result: Array[ContestDef] = []
	var scope_upper := scope.to_upper()
	for contest in contests.values():
		if contest == null:
			continue
		if contest.scope.to_upper() != scope_upper:
			continue
		if not contest.published:
			continue
		if contest.price <= 0:
			continue
		if contest.map_ids.size() != 5:
			continue
		result.append(contest)
	result.sort_custom(func(a: ContestDef, b: ContestDef) -> bool:
		return a.price < b.price
	)
	return result

func get_contest_by_scope(scope: String) -> ContestDef:
	var contests_by_scope := get_contests_by_scope(scope)
	if contests_by_scope.is_empty():
		return null
	return contests_by_scope[0]

func get_buff_cap_per_map(contest_id: String) -> int:
	var contest: ContestDef = contests.get(normalize_contest_id(contest_id))
	if contest == null:
		return 0
	return contest.buff_cap_per_map

func is_entered(contest_id: String) -> bool:
	return player_entries.has(normalize_contest_id(contest_id))

func enter_contest(contest_id: String) -> void:
	var normalized_id := normalize_contest_id(contest_id)
	if normalized_id.is_empty():
		return
	player_entries[normalized_id] = int(Time.get_unix_time_from_system())
	_save_entries()

func preview_entry_requirements(contest_id: String) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var normalized_id: String = normalize_contest_id(contest_id)
	var ticket_cost: int = contest.get_access_ticket_cost() if contest.has_method("get_access_ticket_cost") else maxi(0, int(contest.access_ticket_cost))
	var requires_ticket: bool = contest.requires_access_ticket() if contest.has_method("requires_access_ticket") else ticket_cost > 0
	var preview: Dictionary = {
		"ok": true,
		"contest_id": normalized_id,
		"already_entered": is_entered(normalized_id),
		"requires_access_ticket": requires_ticket,
		"access_ticket_cost": ticket_cost,
		"entry_currency": "ACCESS_TICKET" if requires_ticket else str(contest.currency).to_upper(),
		"entry_price": ticket_cost if requires_ticket else int(contest.price),
		"prize_rewards": contest.prize_rewards.duplicate(true)
	}
	if requires_ticket:
		var battle_pass_state: Node = get_node_or_null("/root/BattlePassState")
		if battle_pass_state != null and battle_pass_state.has_method("preview_exclusive_event_entry"):
			var ticket_preview: Dictionary = battle_pass_state.call("preview_exclusive_event_entry", "contest", normalized_id, ticket_cost, contest.prize_rewards) as Dictionary
			preview["ticket_preview"] = ticket_preview
			preview["can_enter"] = bool(ticket_preview.get("can_authorize", false))
		elif battle_pass_state != null and battle_pass_state.has_method("preview_access_ticket_entry"):
			var ticket_preview_legacy: Dictionary = battle_pass_state.call("preview_access_ticket_entry", "contest", normalized_id, ticket_cost) as Dictionary
			preview["ticket_preview"] = ticket_preview_legacy
			preview["can_enter"] = bool(ticket_preview_legacy.get("can_authorize", false))
		else:
			preview["ticket_preview"] = {"ok": false, "reason": "battle_pass_state_missing"}
			preview["can_enter"] = false
	else:
		preview["can_enter"] = true
	return preview

func preview_prize_requirements(contest_id: String, placement: int) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var normalized_id: String = normalize_contest_id(contest_id)
	var rewards: Array[Dictionary] = contest.get_prize_rewards_for_placement(placement) if contest.has_method("get_prize_rewards_for_placement") else []
	return {
		"ok": true,
		"contest_id": normalized_id,
		"placement": maxi(1, placement),
		"prize_rewards": rewards,
		"has_prizes": not rewards.is_empty()
	}

func intent_claim_contest_prizes(contest_id: String, placement: int, metadata: Dictionary = {}) -> Dictionary:
	var prize_preview: Dictionary = preview_prize_requirements(contest_id, placement)
	if not bool(prize_preview.get("ok", false)):
		return prize_preview
	var rewards: Array = prize_preview.get("prize_rewards", []) as Array
	if rewards.is_empty():
		return {"ok": false, "reason": "no_prize_rewards", "contest_id": str(prize_preview.get("contest_id", ""))}
	var battle_pass_state: Node = get_node_or_null("/root/BattlePassState")
	if battle_pass_state == null:
		return {"ok": false, "reason": "battle_pass_state_missing"}
	var normalized_id: String = str(prize_preview.get("contest_id", ""))
	var claim_metadata: Dictionary = metadata.duplicate(true)
	claim_metadata["placement"] = maxi(1, placement)
	if battle_pass_state.has_method("intent_claim_exclusive_event_prizes"):
		return battle_pass_state.call("intent_claim_exclusive_event_prizes", "contest", normalized_id, rewards, claim_metadata) as Dictionary
	return {"ok": false, "reason": "prize_claim_api_missing"}

func intent_enter_contest(contest_id: String, metadata: Dictionary = {}) -> Dictionary:
	var preview: Dictionary = preview_entry_requirements(contest_id)
	if not bool(preview.get("ok", false)):
		return preview
	if bool(preview.get("already_entered", false)):
		return {"ok": true, "contest_id": str(preview.get("contest_id", "")), "already_entered": true}
	var normalized_id: String = str(preview.get("contest_id", ""))
	if bool(preview.get("requires_access_ticket", false)):
		var battle_pass_state: Node = get_node_or_null("/root/BattlePassState")
		if battle_pass_state == null:
			return {"ok": false, "reason": "battle_pass_state_missing"}
		var ticket_cost: int = maxi(1, int(preview.get("access_ticket_cost", 1)))
		var ticket_result: Dictionary = {}
		if battle_pass_state.has_method("intent_authorize_exclusive_event_entry"):
			ticket_result = battle_pass_state.call("intent_authorize_exclusive_event_entry", "contest", normalized_id, ticket_cost, metadata) as Dictionary
		elif battle_pass_state.has_method("intent_authorize_access_ticket_entry"):
			ticket_result = battle_pass_state.call("intent_authorize_access_ticket_entry", "contest", normalized_id, ticket_cost, metadata) as Dictionary
		else:
			return {"ok": false, "reason": "ticket_authorize_api_missing"}
		if not bool(ticket_result.get("ok", false)):
			return ticket_result
		enter_contest(normalized_id)
		return {"ok": true, "contest_id": normalized_id, "ticket_result": ticket_result}
	enter_contest(normalized_id)
	return {"ok": true, "contest_id": normalized_id}

func intent_refund_contest_entry(contest_id: String, reason: String = "contest_entry_refund") -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var normalized_id: String = normalize_contest_id(contest_id)
	if not player_entries.has(normalized_id):
		return {"ok": false, "reason": "contest_not_entered", "contest_id": normalized_id}
	var ticket_cost: int = contest.get_access_ticket_cost() if contest.has_method("get_access_ticket_cost") else maxi(0, int(contest.access_ticket_cost))
	if ticket_cost > 0:
		var battle_pass_state: Node = get_node_or_null("/root/BattlePassState")
		if battle_pass_state == null:
			return {"ok": false, "reason": "battle_pass_state_missing"}
		var refund_result: Dictionary = {}
		if battle_pass_state.has_method("intent_refund_exclusive_event_entry"):
			refund_result = battle_pass_state.call("intent_refund_exclusive_event_entry", "contest", normalized_id, reason) as Dictionary
		elif battle_pass_state.has_method("intent_refund_access_ticket_entry"):
			refund_result = battle_pass_state.call("intent_refund_access_ticket_entry", "contest", normalized_id, reason) as Dictionary
		else:
			return {"ok": false, "reason": "ticket_refund_api_missing"}
		if not bool(refund_result.get("ok", false)):
			return refund_result
		player_entries.erase(normalized_id)
		_save_entries()
		return {"ok": true, "contest_id": normalized_id, "refund_result": refund_result}
	player_entries.erase(normalized_id)
	_save_entries()
	return {"ok": true, "contest_id": normalized_id, "refunded": false}

func build_run_context(contest_id: String, map_id: String) -> Dictionary:
	var normalized_id := normalize_contest_id(contest_id)
	var contest: ContestDef = contests.get(normalized_id)
	if contest == null:
		return {}
	var context: Dictionary = {
		"contest_id": normalized_id,
		"map_id": map_id,
		"scope": contest.scope,
		"price": contest.price,
		"buff_cap_per_map": contest.buff_cap_per_map
	}
	run_requested.emit(context)
	return context

func get_map_ids(contest: ContestDef) -> PackedStringArray:
	if contest == null:
		return PackedStringArray()
	return contest.map_ids

func get_leaderboard_entries(contest_id: String, map_id: String) -> Array:
	var normalized_id := normalize_contest_id(contest_id)
	var path := "%s/%s/%s.json" % [LEADERBOARDS_DIR, normalized_id, map_id]
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	if err != OK:
		return []
	if typeof(json.data) != TYPE_ARRAY:
		return []
	return json.data

func get_best_score(contest_id: String, map_id: String) -> int:
	var entries := get_leaderboard_entries(contest_id, map_id)
	if entries.is_empty():
		return 0
	var first: Dictionary = entries[0]
	return int(first.get("best_score", 0))

func timed_game_rules() -> Dictionary:
	return {
		"mode": "TIMED_GAME",
		"map_count_default": TIMED_GAME_DEFAULT_MAP_COUNT,
		"map_count_supported": TIMED_GAME_SUPPORTED_MAP_COUNTS.duplicate(),
		"player_count_min": TIMED_GAME_MIN_PLAYERS,
		"player_count_max": TIMED_GAME_MAX_PLAYERS,
		"time_limit_ms": TIMED_GAME_DEFAULT_LIMIT_MS,
		"main_leaderboard_threshold": TIMED_GAME_MAIN_LEADERBOARD_THRESHOLD,
		"ad_hook_between_maps": true
	}

func evaluate_timed_game(participants: Array, map_count: int = TIMED_GAME_DEFAULT_MAP_COUNT) -> Dictionary:
	var resolved_map_count: int = _resolve_timed_map_count(map_count)
	var normalized: Array[Dictionary] = _normalize_timed_participants(participants, resolved_map_count)
	if normalized.is_empty():
		return {
			"ok": false,
			"err": "no_participants",
			"rules": timed_game_rules()
		}
	var main_map_index: int = _timed_main_leaderboard_map_index(normalized, resolved_map_count)
	var main_leaders: Array[Dictionary] = _timed_rank_for_map(normalized, main_map_index)
	var clubhouse: Dictionary = _timed_clubhouse(normalized, resolved_map_count)
	var winner: Dictionary = _timed_pick_winner(normalized, resolved_map_count)
	return {
		"ok": true,
		"rules": timed_game_rules(),
		"map_count": resolved_map_count,
		"participants_total": normalized.size(),
		"main": {
			"map_index": main_map_index,
			"leaders": main_leaders
		},
		"clubhouse": clubhouse,
		"winner": winner
	}

func evaluate_stage_race_3(participants: Array) -> Dictionary:
	return evaluate_timed_game(participants, TIMED_GAME_MAP_COUNT_3)

func evaluate_stage_race_5(participants: Array) -> Dictionary:
	return evaluate_timed_game(participants, TIMED_GAME_MAP_COUNT_5)

func timed_race_rules() -> Dictionary:
	return {
		"mode": "TIMED_RACE",
		"map_count_default": TIMED_RACE_DEFAULT_MAP_COUNT,
		"map_count_supported": TIMED_RACE_SUPPORTED_MAP_COUNTS.duplicate(),
		"player_count_min": TIMED_RACE_MIN_PLAYERS,
		"player_count_max": TIMED_RACE_MAX_PLAYERS,
		"start_countdown_sec": TIMED_RACE_START_COUNTDOWN_SEC,
		"sync_start": true,
		"winner_rule": "first_to_finish"
	}

func build_timed_race_plan(contest_id: String, map_count: int = TIMED_RACE_DEFAULT_MAP_COUNT) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "err": "contest_not_found", "contest_id": contest_id}
	var resolved_map_count: int = _resolve_timed_map_count(map_count)
	var map_ids: PackedStringArray = _take_stage_maps(contest.map_ids, resolved_map_count)
	if map_ids.size() < resolved_map_count:
		return {
			"ok": false,
			"err": "insufficient_maps",
			"contest_id": contest.id,
			"map_count": resolved_map_count,
			"map_ids": map_ids
		}
	return {
		"ok": true,
		"contest_id": contest.id,
		"mode": "TIMED_RACE",
		"map_count": resolved_map_count,
		"map_ids": map_ids,
		"start_countdown_sec": TIMED_RACE_START_COUNTDOWN_SEC
	}

func evaluate_timed_race(participants: Array, map_count: int = TIMED_RACE_DEFAULT_MAP_COUNT) -> Dictionary:
	var resolved_map_count: int = _resolve_timed_map_count(map_count)
	var normalized: Array[Dictionary] = _normalize_timed_participants(participants, resolved_map_count)
	if normalized.is_empty():
		return {
			"ok": false,
			"err": "no_participants",
			"rules": timed_race_rules()
		}
	var leaderboard: Array[Dictionary] = []
	for p in normalized:
		var completed_maps: int = int(p.get("completed_maps", 0))
		var completed_all: bool = completed_maps >= resolved_map_count
		leaderboard.append({
			"player_id": str(p.get("player_id", "")),
			"player_name": str(p.get("player_name", "")),
			"completed_maps": completed_maps,
			"completed_all": completed_all,
			"aggregate_ms": int(p.get("aggregate_ms", 0)),
			"failed_map_elapsed_ms": int(p.get("failed_map_elapsed_ms", 0))
		})
	leaderboard.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_done: bool = bool(a.get("completed_all", false))
		var b_done: bool = bool(b.get("completed_all", false))
		if a_done != b_done:
			return a_done
		var a_completed: int = int(a.get("completed_maps", 0))
		var b_completed: int = int(b.get("completed_maps", 0))
		if a_completed != b_completed:
			return a_completed > b_completed
		var a_agg: int = int(a.get("aggregate_ms", 0))
		var b_agg: int = int(b.get("aggregate_ms", 0))
		if a_agg != b_agg:
			return a_agg < b_agg
		var a_id: String = str(a.get("player_id", ""))
		var b_id: String = str(b.get("player_id", ""))
		return a_id < b_id
	)
	for i in range(leaderboard.size()):
		leaderboard[i]["rank"] = i + 1
	var winner: Dictionary = leaderboard[0] if not leaderboard.is_empty() else {}
	return {
		"ok": true,
		"rules": timed_race_rules(),
		"map_count": resolved_map_count,
		"participants_total": leaderboard.size(),
		"leaderboard": leaderboard,
		"winner": winner,
		"winner_reason": "first_to_finish" if bool(winner.get("completed_all", false)) else "most_progress_then_fastest_time"
	}

func get_stage_race_maps(contest_id: String, map_count: int = TIMED_GAME_DEFAULT_MAP_COUNT) -> PackedStringArray:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return PackedStringArray()
	return _take_stage_maps(contest.map_ids, _resolve_timed_map_count(map_count))

func get_stage_race_3_maps(contest_id: String) -> PackedStringArray:
	return get_stage_race_maps(contest_id, TIMED_GAME_MAP_COUNT_3)

func get_stage_race_5_maps(contest_id: String) -> PackedStringArray:
	return get_stage_race_maps(contest_id, TIMED_GAME_MAP_COUNT_5)

func build_stage_race_plan(contest_id: String, map_count: int = TIMED_GAME_DEFAULT_MAP_COUNT) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "err": "contest_not_found", "contest_id": contest_id}
	var resolved_map_count: int = _resolve_timed_map_count(map_count)
	var stage_maps: PackedStringArray = _take_stage_maps(contest.map_ids, resolved_map_count)
	if stage_maps.size() < resolved_map_count:
		return {
			"ok": false,
			"err": "insufficient_maps",
			"contest_id": contest.id,
			"map_count": resolved_map_count,
			"map_ids": stage_maps
		}
	return {
		"ok": true,
		"contest_id": contest.id,
		"mode": "STAGE_RACE",
		"map_count": resolved_map_count,
		"map_ids": stage_maps,
		"time_limit_ms": TIMED_GAME_DEFAULT_LIMIT_MS,
		"main_leaderboard_threshold": TIMED_GAME_MAIN_LEADERBOARD_THRESHOLD
	}

func build_stage_race_3_plan(contest_id: String) -> Dictionary:
	return build_stage_race_plan(contest_id, TIMED_GAME_MAP_COUNT_3)

func build_stage_race_5_plan(contest_id: String) -> Dictionary:
	return build_stage_race_plan(contest_id, TIMED_GAME_MAP_COUNT_5)

func build_stage_race_overall_leaderboard(contest_id: String, map_count: int = TIMED_GAME_DEFAULT_MAP_COUNT, limit: int = 10) -> Array[Dictionary]:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return []
	var resolved_map_count: int = _resolve_timed_map_count(map_count)
	if map_count <= 0:
		resolved_map_count = contest.map_ids.size()
	var stage_maps: PackedStringArray = _take_stage_maps(contest.map_ids, resolved_map_count)
	if stage_maps.is_empty():
		return []
	var by_player: Dictionary = {}
	for map_id in stage_maps:
		var entries: Array = get_leaderboard_entries(contest.id, map_id)
		for entry_v in entries:
			if typeof(entry_v) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_v as Dictionary
			var player_id: String = str(entry.get("player_id", ""))
			if player_id.is_empty():
				continue
			var row: Dictionary = by_player.get(player_id, {
				"player_id": player_id,
				"player_name": str(entry.get("player_name", player_id)),
				"hive_name": str(entry.get("hive_name", "")),
				"completed_maps": 0,
				"aggregate_time_ms": 0,
				"map_times_ms": {},
				"runs_count": 0
			})
			var map_times: Dictionary = row.get("map_times_ms", {}) as Dictionary
			if map_times.has(map_id):
				continue
			var time_ms: int = _entry_time_ms(entry)
			map_times[map_id] = time_ms
			row["map_times_ms"] = map_times
			row["completed_maps"] = int(row.get("completed_maps", 0)) + 1
			row["aggregate_time_ms"] = int(row.get("aggregate_time_ms", 0)) + time_ms
			row["runs_count"] = int(row.get("runs_count", 0)) + int(entry.get("runs_count", 0))
			by_player[player_id] = row
	var rows: Array[Dictionary] = []
	var required_maps: int = stage_maps.size()
	for player_row_v in by_player.values():
		if typeof(player_row_v) != TYPE_DICTIONARY:
			continue
		var player_row: Dictionary = player_row_v as Dictionary
		player_row["required_maps"] = required_maps
		rows.append(player_row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_completed: int = int(a.get("completed_maps", 0))
		var b_completed: int = int(b.get("completed_maps", 0))
		if a_completed != b_completed:
			return a_completed > b_completed
		var a_agg: int = int(a.get("aggregate_time_ms", 0))
		var b_agg: int = int(b.get("aggregate_time_ms", 0))
		if a_agg != b_agg:
			return a_agg < b_agg
		var a_id: String = str(a.get("player_id", ""))
		var b_id: String = str(b.get("player_id", ""))
		return a_id < b_id
	)
	for i in range(rows.size()):
		rows[i]["rank"] = i + 1
	if limit > 0 and rows.size() > limit:
		return rows.slice(0, limit)
	return rows

func get_stage_race_overall_lead(contest_id: String, map_count: int = TIMED_GAME_DEFAULT_MAP_COUNT) -> Dictionary:
	var rows: Array[Dictionary] = build_stage_race_overall_leaderboard(contest_id, map_count, 1)
	if rows.is_empty():
		return {}
	return rows[0]

func get_stage_race_map_leaderboard(contest_id: String, map_id: String, limit: int = 10) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var entries: Array = get_leaderboard_entries(contest_id, map_id)
	for entry_v in entries:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v as Dictionary
		rows.append({
			"player_id": str(entry.get("player_id", "")),
			"player_name": str(entry.get("player_name", "Player")),
			"hive_name": str(entry.get("hive_name", "")),
			"time_ms": _entry_time_ms(entry),
			"runs_count": int(entry.get("runs_count", 0))
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_time: int = int(a.get("time_ms", 0))
		var b_time: int = int(b.get("time_ms", 0))
		if a_time != b_time:
			return a_time < b_time
		var a_id: String = str(a.get("player_id", ""))
		var b_id: String = str(b.get("player_id", ""))
		return a_id < b_id
	)
	for i in range(rows.size()):
		rows[i]["rank"] = i + 1
	if limit > 0 and rows.size() > limit:
		return rows.slice(0, limit)
	return rows

func miss_n_out_rules() -> Dictionary:
	return {
		"mode": "MISS_N_OUT",
		"player_count_min": MISS_N_OUT_MIN_PLAYERS,
		"player_count_max": MISS_N_OUT_MAX_PLAYERS,
		"player_count_default": MISS_N_OUT_DEFAULT_PLAYERS,
		"map_count_formula": "players_minus_one",
		"time_limit_ms": MISS_N_OUT_DEFAULT_LIMIT_MS,
		"async_resolution": true,
		"elimination_notice": true,
		"eliminated_player_actions": [
			MISS_N_OUT_ACTION_KEEP_PLAYING,
			MISS_N_OUT_ACTION_RETURN_TO_LOBBY
		]
	}

func build_miss_n_out_plan(contest_id: String, player_count: int = MISS_N_OUT_DEFAULT_PLAYERS) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "err": "contest_not_found", "contest_id": contest_id}
	var resolved_players: int = _resolve_miss_n_out_player_count(player_count)
	var map_count: int = maxi(resolved_players - 1, 1)
	var map_ids: PackedStringArray = _take_stage_maps(contest.map_ids, map_count)
	if map_ids.size() < map_count:
		return {
			"ok": false,
			"err": "insufficient_maps",
			"contest_id": contest.id,
			"player_count": resolved_players,
			"map_count": map_count,
			"map_ids": map_ids
		}
	return {
		"ok": true,
		"contest_id": contest.id,
		"mode": "MISS_N_OUT",
		"player_count": resolved_players,
		"map_count": map_count,
		"map_ids": map_ids,
		"time_limit_ms": MISS_N_OUT_DEFAULT_LIMIT_MS
	}

func evaluate_miss_n_out(participants: Array, player_count: int = MISS_N_OUT_DEFAULT_PLAYERS, round_benchmarks_ms: Array = []) -> Dictionary:
	var normalized: Array[Dictionary] = _normalize_miss_n_out_participants(participants)
	if normalized.is_empty():
		return {
			"ok": false,
			"err": "no_participants",
			"rules": miss_n_out_rules()
		}
	var target_players: int = player_count
	if normalized.size() > 0:
		target_players = normalized.size()
	var resolved_players: int = _resolve_miss_n_out_player_count(target_players)
	if normalized.size() > resolved_players:
		normalized = normalized.slice(0, resolved_players)
	if normalized.size() < MISS_N_OUT_MIN_PLAYERS:
		return {
			"ok": false,
			"err": "insufficient_participants",
			"rules": miss_n_out_rules(),
			"participants_total": normalized.size()
		}
	var map_count: int = normalized.size() - 1
	var benchmarks: Array[int] = _normalize_miss_n_out_benchmarks(round_benchmarks_ms, map_count)
	var by_id: Dictionary = {}
	var alive_ids: Array[String] = []
	for p in normalized:
		var pid: String = str(p.get("player_id", ""))
		by_id[pid] = p
		alive_ids.append(pid)
	var rounds: Array[Dictionary] = []
	var eliminated_order: Array[Dictionary] = []
	var winner_id: String = ""
	for round_idx in range(map_count):
		if alive_ids.size() <= 0:
			break
		var rows: Array[Dictionary] = []
		var benchmark_ms: int = benchmarks[round_idx]
		for pid in alive_ids:
			var p: Dictionary = by_id.get(pid, {})
			rows.append(_miss_n_out_round_row(p, round_idx, benchmark_ms))
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_time: int = int(a.get("effective_time_ms", MISS_N_OUT_DNF_TIME_MS))
			var b_time: int = int(b.get("effective_time_ms", MISS_N_OUT_DNF_TIME_MS))
			if a_time != b_time:
				return a_time < b_time
			var a_id: String = str(a.get("player_id", ""))
			var b_id: String = str(b.get("player_id", ""))
			return a_id < b_id
		)
		var is_final_round: bool = rows.size() <= 2 or round_idx == map_count - 1
		if is_final_round:
			var winner_row: Dictionary = rows[0]
			winner_id = str(winner_row.get("player_id", ""))
			var eliminated_ids: Array[String] = []
			var eliminated_rows: Array[Dictionary] = []
			for i in range(1, rows.size()):
				var elim_row: Dictionary = rows[i]
				var elim_id: String = str(elim_row.get("player_id", ""))
				eliminated_ids.append(elim_id)
				eliminated_rows.append(elim_row)
				eliminated_order.append({
					"round_index": round_idx + 1,
					"map_index": round_idx + 1,
					"player_id": elim_id,
					"player_name": str(elim_row.get("player_name", "")),
					"time_ms": int(elim_row.get("time_ms", 0)),
					"dnf": bool(elim_row.get("dnf", false)),
					"reason": str(elim_row.get("reason", ""))
				})
			rounds.append({
				"round_index": round_idx + 1,
				"map_index": round_idx + 1,
				"benchmark_ms": benchmark_ms,
				"is_final": true,
				"rows": rows,
				"winner": winner_row,
				"eliminated_player_ids": eliminated_ids,
				"eliminated_rows": eliminated_rows
			})
			alive_ids = [winner_id]
			break
		var eliminated_row: Dictionary = rows[rows.size() - 1]
		var eliminated_id: String = str(eliminated_row.get("player_id", ""))
		alive_ids.erase(eliminated_id)
		eliminated_order.append({
			"round_index": round_idx + 1,
			"map_index": round_idx + 1,
			"player_id": eliminated_id,
			"player_name": str(eliminated_row.get("player_name", "")),
			"time_ms": int(eliminated_row.get("time_ms", 0)),
			"dnf": bool(eliminated_row.get("dnf", false)),
			"reason": str(eliminated_row.get("reason", ""))
		})
		rounds.append({
			"round_index": round_idx + 1,
			"map_index": round_idx + 1,
			"benchmark_ms": benchmark_ms,
			"is_final": false,
			"rows": rows,
			"eliminated_player_id": eliminated_id,
			"eliminated_row": eliminated_row
		})
	if winner_id.is_empty() and alive_ids.size() == 1:
		winner_id = alive_ids[0]
	var winner: Dictionary = {}
	if not winner_id.is_empty():
		var w: Dictionary = by_id.get(winner_id, {})
		winner = {
			"player_id": winner_id,
			"player_name": str(w.get("player_name", winner_id)),
			"survived_rounds": map_count,
			"reason": "final_lowest_time"
		}
	var player_states: Dictionary = _build_miss_n_out_player_states(normalized, eliminated_order, winner_id)
	return {
		"ok": true,
		"rules": miss_n_out_rules(),
		"participants_total": normalized.size(),
		"player_count": normalized.size(),
		"map_count": map_count,
		"benchmarks_ms": benchmarks,
		"rounds": rounds,
		"eliminated_order": eliminated_order,
		"winner": winner,
		"player_states": player_states
	}

func miss_n_out_player_status(result: Dictionary, player_id: String) -> Dictionary:
	if player_id.is_empty():
		return {}
	if typeof(result.get("player_states", null)) == TYPE_DICTIONARY:
		var states: Dictionary = result.get("player_states", {}) as Dictionary
		if states.has(player_id):
			return states[player_id] as Dictionary
	var eliminated_order: Array = result.get("eliminated_order", []) as Array
	var eliminated_round: int = 0
	for row_v in eliminated_order:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v as Dictionary
		if str(row.get("player_id", "")) != player_id:
			continue
		eliminated_round = int(row.get("round_index", 0))
		break
	var winner_id: String = str((result.get("winner", {}) as Dictionary).get("player_id", ""))
	var is_winner: bool = winner_id == player_id and not winner_id.is_empty()
	if eliminated_round > 0:
		return {
			"player_id": player_id,
			"is_winner": false,
			"eliminated": true,
			"eliminated_round": eliminated_round,
			"can_win": false,
			"actions": [MISS_N_OUT_ACTION_KEEP_PLAYING, MISS_N_OUT_ACTION_RETURN_TO_LOBBY],
			"notice": "Eliminated in round %d. You can keep playing for practice or return to lobby." % eliminated_round
		}
	if is_winner:
		return {
			"player_id": player_id,
			"is_winner": true,
			"eliminated": false,
			"eliminated_round": 0,
			"can_win": true,
			"actions": [],
			"notice": "You won Miss-N-Out."
		}
	return {
		"player_id": player_id,
		"is_winner": false,
		"eliminated": false,
		"eliminated_round": 0,
		"can_win": true,
		"actions": [],
		"notice": "Still alive in Miss-N-Out."
	}

func _normalize_timed_participants(participants: Array, map_count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(participants.size()):
		var raw_v: Variant = participants[i]
		if typeof(raw_v) != TYPE_DICTIONARY:
			continue
		var raw: Dictionary = raw_v as Dictionary
		var player_id: String = str(raw.get("player_id", "p_%d" % (i + 1)))
		var player_name: String = str(raw.get("player_name", player_id))
		var times_raw: Variant = raw.get("map_times_ms", [])
		var times: Array[int] = []
		if typeof(times_raw) == TYPE_ARRAY:
			for t_v in times_raw as Array:
				var t: int = maxi(0, int(t_v))
				times.append(t)
		var completed_maps: int = int(raw.get("completed_maps", times.size()))
		completed_maps = mini(maxi(completed_maps, 0), map_count)
		if times.size() > completed_maps:
			times = times.slice(0, completed_maps)
		if times.size() > map_count:
			times = times.slice(0, map_count)
		var aggregate_ms: int = 0
		for t in times:
			aggregate_ms += int(t)
		var failed_elapsed_ms: int = maxi(0, int(raw.get("failed_map_elapsed_ms", 0)))
		var status: String = str(raw.get("status", "active"))
		out.append({
			"player_id": player_id,
			"player_name": player_name,
			"completed_maps": completed_maps,
			"map_times_ms": times,
			"aggregate_ms": aggregate_ms,
			"failed_map_elapsed_ms": failed_elapsed_ms,
			"status": status
		})
	return out

func _timed_main_leaderboard_map_index(participants: Array[Dictionary], map_count: int) -> int:
	if participants.is_empty():
		return 0
	var total: int = participants.size()
	var required: int = int(ceil(float(total) * TIMED_GAME_MAIN_LEADERBOARD_THRESHOLD))
	var best_threshold_map: int = 0
	for map_idx in range(map_count, 0, -1):
		var completed_here: int = 0
		for p in participants:
			if int(p.get("completed_maps", 0)) >= map_idx:
				completed_here += 1
		if completed_here >= required:
			best_threshold_map = map_idx
			break
	if best_threshold_map > 0:
		return best_threshold_map
	# Fallback matching edge-case expectation:
	# if no map reached the threshold, show the map with the highest completion count.
	var best_count: int = -1
	var best_map: int = 0
	for map_idx in range(1, map_count + 1):
		var completed_here: int = 0
		for p in participants:
			if int(p.get("completed_maps", 0)) >= map_idx:
				completed_here += 1
		if completed_here > best_count:
			best_count = completed_here
			best_map = map_idx
	return best_map

func _timed_rank_for_map(participants: Array[Dictionary], map_index: int) -> Array[Dictionary]:
	if map_index <= 0:
		return []
	var rows: Array[Dictionary] = []
	for p in participants:
		var completed_maps: int = int(p.get("completed_maps", 0))
		if completed_maps < map_index:
			continue
		var times: Array[int] = p.get("map_times_ms", []) as Array[int]
		var agg: int = 0
		for i in range(mini(times.size(), map_index)):
			agg += int(times[i])
		rows.append({
			"player_id": str(p.get("player_id", "")),
			"player_name": str(p.get("player_name", "")),
			"completed_maps": completed_maps,
			"aggregate_ms": agg,
			"failed_map_elapsed_ms": int(p.get("failed_map_elapsed_ms", 0)),
			"status": str(p.get("status", "active"))
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_agg: int = int(a.get("aggregate_ms", 0))
		var b_agg: int = int(b.get("aggregate_ms", 0))
		if a_agg != b_agg:
			return a_agg < b_agg
		var a_id: String = str(a.get("player_id", ""))
		var b_id: String = str(b.get("player_id", ""))
		return a_id < b_id
	)
	for i in range(rows.size()):
		rows[i]["rank"] = i + 1
	return rows

func _timed_clubhouse(participants: Array[Dictionary], map_count: int) -> Dictionary:
	if participants.is_empty():
		return {"frontier_map_index": 0, "leaders": [], "leader": {}}
	var frontier: int = 0
	for p in participants:
		frontier = maxi(frontier, int(p.get("completed_maps", 0)))
	frontier = mini(frontier, map_count)
	var rows: Array[Dictionary] = []
	for p in participants:
		var completed_maps: int = int(p.get("completed_maps", 0))
		if completed_maps != frontier:
			continue
		var adjusted: int = _timed_adjusted_score_ms(p, map_count)
		rows.append({
			"player_id": str(p.get("player_id", "")),
			"player_name": str(p.get("player_name", "")),
			"completed_maps": completed_maps,
			"aggregate_ms": int(p.get("aggregate_ms", 0)),
			"failed_map_elapsed_ms": int(p.get("failed_map_elapsed_ms", 0)),
			"adjusted_score_ms": adjusted,
			"status": str(p.get("status", "active"))
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score: int = int(a.get("adjusted_score_ms", 0))
		var b_score: int = int(b.get("adjusted_score_ms", 0))
		if a_score != b_score:
			return a_score < b_score
		var a_fail: int = int(a.get("failed_map_elapsed_ms", 0))
		var b_fail: int = int(b.get("failed_map_elapsed_ms", 0))
		if a_fail != b_fail:
			return a_fail > b_fail
		var a_id: String = str(a.get("player_id", ""))
		var b_id: String = str(b.get("player_id", ""))
		return a_id < b_id
	)
	for i in range(rows.size()):
		rows[i]["rank"] = i + 1
	var leader: Dictionary = rows[0] if not rows.is_empty() else {}
	return {
		"frontier_map_index": frontier,
		"leaders": rows,
		"leader": leader
	}

func _timed_pick_winner(participants: Array[Dictionary], map_count: int) -> Dictionary:
	if participants.is_empty():
		return {}
	var top_completed: int = 0
	for p in participants:
		top_completed = maxi(top_completed, int(p.get("completed_maps", 0)))
	var candidates: Array[Dictionary] = []
	for p in participants:
		if int(p.get("completed_maps", 0)) == top_completed:
			candidates.append(p)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score: int = _timed_adjusted_score_ms(a, map_count)
		var b_score: int = _timed_adjusted_score_ms(b, map_count)
		if a_score != b_score:
			return a_score < b_score
		var a_fail: int = int(a.get("failed_map_elapsed_ms", 0))
		var b_fail: int = int(b.get("failed_map_elapsed_ms", 0))
		if a_fail != b_fail:
			return a_fail > b_fail
		var a_id: String = str(a.get("player_id", ""))
		var b_id: String = str(b.get("player_id", ""))
		return a_id < b_id
	)
	if candidates.is_empty():
		return {}
	var winner: Dictionary = candidates[0]
	return {
		"player_id": str(winner.get("player_id", "")),
		"player_name": str(winner.get("player_name", "")),
		"completed_maps": int(winner.get("completed_maps", 0)),
		"aggregate_ms": int(winner.get("aggregate_ms", 0)),
		"failed_map_elapsed_ms": int(winner.get("failed_map_elapsed_ms", 0)),
		"adjusted_score_ms": _timed_adjusted_score_ms(winner, map_count),
		"reason": "completed_all_lowest_aggregate" if int(winner.get("completed_maps", 0)) >= map_count else "most_progress_adjusted_score"
	}

func _timed_adjusted_score_ms(p: Dictionary, map_count: int) -> int:
	var completed_maps: int = mini(maxi(int(p.get("completed_maps", 0)), 0), map_count)
	var aggregate_ms: int = int(p.get("aggregate_ms", 0))
	if completed_maps >= map_count:
		return aggregate_ms
	var failed_elapsed_ms: int = maxi(0, int(p.get("failed_map_elapsed_ms", 0)))
	return aggregate_ms - failed_elapsed_ms

func _resolve_timed_map_count(map_count: int) -> int:
	if TIMED_GAME_SUPPORTED_MAP_COUNTS.has(map_count):
		return map_count
	return TIMED_GAME_DEFAULT_MAP_COUNT

func _take_stage_maps(map_ids: PackedStringArray, map_count: int) -> PackedStringArray:
	var out := PackedStringArray()
	var count: int = mini(map_ids.size(), map_count)
	for i in range(count):
		out.append(map_ids[i])
	return out

func _resolve_miss_n_out_player_count(player_count: int) -> int:
	return mini(maxi(player_count, MISS_N_OUT_MIN_PLAYERS), MISS_N_OUT_MAX_PLAYERS)

func _normalize_miss_n_out_participants(participants: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(participants.size()):
		var raw_v: Variant = participants[i]
		if typeof(raw_v) != TYPE_DICTIONARY:
			continue
		var raw: Dictionary = raw_v as Dictionary
		var player_id: String = str(raw.get("player_id", "p_%d" % (i + 1)))
		var player_name: String = str(raw.get("player_name", player_id))
		var times_raw: Variant = raw.get("map_times_ms", [])
		var times: Array[int] = []
		if typeof(times_raw) == TYPE_ARRAY:
			for t_v in times_raw as Array:
				times.append(maxi(0, int(t_v)))
		out.append({
			"player_id": player_id,
			"player_name": player_name,
			"map_times_ms": times
		})
	return out

func _normalize_miss_n_out_benchmarks(round_benchmarks_ms: Array, map_count: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(map_count):
		if i < round_benchmarks_ms.size():
			out.append(maxi(0, int(round_benchmarks_ms[i])))
		else:
			out.append(0)
	return out

func _build_miss_n_out_player_states(participants: Array[Dictionary], eliminated_order: Array[Dictionary], winner_id: String) -> Dictionary:
	var eliminated_round_by_id: Dictionary = {}
	for row in eliminated_order:
		var pid: String = str(row.get("player_id", ""))
		if pid.is_empty() or eliminated_round_by_id.has(pid):
			continue
		eliminated_round_by_id[pid] = int(row.get("round_index", 0))
	var states: Dictionary = {}
	for p in participants:
		var pid: String = str(p.get("player_id", ""))
		if pid.is_empty():
			continue
		var eliminated_round: int = int(eliminated_round_by_id.get(pid, 0))
		if eliminated_round > 0:
			states[pid] = {
				"player_id": pid,
				"player_name": str(p.get("player_name", pid)),
				"is_winner": false,
				"eliminated": true,
				"eliminated_round": eliminated_round,
				"can_win": false,
				"actions": [MISS_N_OUT_ACTION_KEEP_PLAYING, MISS_N_OUT_ACTION_RETURN_TO_LOBBY],
				"notice": "Eliminated in round %d. You can keep playing for practice or return to lobby." % eliminated_round
			}
			continue
		var is_winner: bool = winner_id == pid and not winner_id.is_empty()
		states[pid] = {
			"player_id": pid,
			"player_name": str(p.get("player_name", pid)),
			"is_winner": is_winner,
			"eliminated": false,
			"eliminated_round": 0,
			"can_win": true,
			"actions": [],
			"notice": "You won Miss-N-Out." if is_winner else "Still alive in Miss-N-Out."
		}
	return states

func _miss_n_out_round_row(p: Dictionary, round_idx: int, benchmark_ms: int) -> Dictionary:
	var times: Array[int] = p.get("map_times_ms", []) as Array[int]
	var has_time: bool = round_idx >= 0 and round_idx < times.size() and int(times[round_idx]) > 0
	var time_ms: int = int(times[round_idx]) if has_time else 0
	var dnf: bool = false
	var reason: String = ""
	var effective_time_ms: int = time_ms
	if not has_time:
		dnf = true
		reason = "missing_time"
		effective_time_ms = MISS_N_OUT_DNF_TIME_MS
	elif benchmark_ms > 0 and time_ms > benchmark_ms:
		dnf = true
		reason = "missed_benchmark"
		effective_time_ms = MISS_N_OUT_DNF_TIME_MS
	return {
		"player_id": str(p.get("player_id", "")),
		"player_name": str(p.get("player_name", "")),
		"time_ms": time_ms,
		"benchmark_ms": benchmark_ms,
		"dnf": dnf,
		"reason": reason,
		"effective_time_ms": effective_time_ms
	}

func _entry_time_ms(entry: Dictionary) -> int:
	if entry.has("best_time_ms"):
		return maxi(0, int(entry.get("best_time_ms", 0)))
	return maxi(0, int(entry.get("best_score", 0)))

func _load_entries() -> void:
	player_entries.clear()
	if not FileAccess.file_exists(ENTRY_SAVE_PATH):
		return
	var f := FileAccess.open(ENTRY_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	player_entries = json.data
	var normalized: Dictionary = {}
	for key in player_entries.keys():
		var normalized_id := normalize_contest_id(str(key))
		normalized[normalized_id] = player_entries[key]
	player_entries = normalized

func debug_reset_entries() -> void:
	player_entries.clear()
	_save_entries()

func _save_entries() -> void:
	var f := FileAccess.open(ENTRY_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(player_entries))

func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".res")

func _normalize_time_slice(time_slice: String) -> String:
	if time_slice.length() == 7 and time_slice.substr(4, 1) == "W":
		return "%s-%s" % [time_slice.substr(0, 4), time_slice.substr(4, 3)]
	if time_slice.length() == 6 and time_slice.is_valid_int():
		return "%s-%s" % [time_slice.substr(0, 4), time_slice.substr(4, 2)]
	return time_slice

func _load_contest_def(path: String, file_name: String) -> ContestDef:
	var res: Resource = load(path)
	if res is ContestDef:
		var typed: ContestDef = res as ContestDef
		if not typed.id.is_empty():
			return typed
	var fallback := ContestDef.new()
	var stem: String = file_name.get_basename()
	var normalized_id: String = normalize_contest_id(stem)
	var parts: Dictionary = parse_contest_id(normalized_id)
	if parts.is_empty():
		return null
	fallback.id = normalized_id
	fallback.scope = str(parts.get("scope", "WEEKLY"))
	fallback.currency = str(parts.get("currency", "USD"))
	fallback.price = int(parts.get("price", 1))
	fallback.time_slice = str(parts.get("time", ""))
	fallback.mode = "STAGE_RACE"
	fallback.status = "OPEN"
	fallback.name = "%s Stage Race — $%d" % [fallback.scope, fallback.price]
	fallback.published = true
	fallback.start_ts = 0
	fallback.end_ts = 4102444800
	fallback.map_ids = PackedStringArray(DEFAULT_STAGE_RACE_MAP_IDS)
	fallback.buff_cap_per_map = -1 if fallback.price >= 50 else 2
	return fallback
