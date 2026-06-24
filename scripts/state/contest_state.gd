extends Node

signal run_requested(context: Dictionary)

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const AsyncMoneyGameLedgerScript := preload("res://scripts/state/async_money_game_ledger.gd")
const CONTESTS_DIR := "res://data/contests"
const LEADERBOARDS_DIR := "res://data/leaderboards"
const ENTRY_SAVE_PATH := "user://contest_entries.json"
const RUNTIME_LEADERBOARD_SAVE_PATH: String = "user://contest_leaderboards_v1.json"
const RUNTIME_LEADERBOARD_SCHEMA: String = "swarmfront.contest_leaderboards.v1"
const TIMED_GAME_DEFAULT_MAP_COUNT := 3
const TIMED_GAME_MAP_COUNT_3 := 3
const TIMED_GAME_MAP_COUNT_5 := 5
const TIMED_GAME_SUPPORTED_MAP_COUNTS: Array[int] = [TIMED_GAME_MAP_COUNT_3, TIMED_GAME_MAP_COUNT_5]
const TIMED_GAME_MIN_PLAYERS := 5
const TIMED_GAME_MAX_PLAYERS := 10
const TIMED_GAME_DEFAULT_LIMIT_MS := 30 * 60 * 1000
const TIMED_GAME_MAIN_LEADERBOARD_THRESHOLD := 0.5
const DEFAULT_STAGE_RACE_MAP_IDS := [
	"MAP_nomansland__545__v01_top2_sides__1p",
	"MAP_nomansland__545__v17_four_corners_only__1p",
	"MAP_nomansland__444__v01_pinched_spine__1p",
	"MAP_race__SBASE__1p",
	"MAP_nomansland__545__v01_top2_sides__1p"
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
const RACE_LEADERBOARD_KEY: String = "__race_overall"
const MISS_N_OUT_LEADERBOARD_KEY: String = "__miss_n_out_overall"
const GAUNTLET_LEADERBOARD_KEY: String = "__gauntlet_overall"

var contests: Dictionary = {}
var player_entries: Dictionary = {}
var runtime_leaderboards: Dictionary = {}
var _runtime_leaderboard_save_path: String = RUNTIME_LEADERBOARD_SAVE_PATH
var _async_money_entry_ledger: RefCounted = AsyncMoneyGameLedgerScript.new()

func _ready() -> void:
	load_contests()
	_load_entries()
	_load_runtime_leaderboards()

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
			var suffix: String = str(parts.get("suffix", "")).strip_edges().to_upper()
			if not suffix.is_empty():
				contest.contest_family = suffix
		if contest.mode.is_empty():
			contest.mode = "STAGE_RACE"
		if contest.has_method("normalize_definition"):
			contest.normalize_definition()
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

func get_contests_by_definition(filters: Dictionary = {}) -> Array[ContestDef]:
	var result: Array[ContestDef] = []
	var clean_scope: String = str(filters.get("scope", "")).strip_edges().to_upper()
	if clean_scope == "YEARLY":
		clean_scope = "SEASONAL"
	var clean_pool: String = str(filters.get("pool_type", "")).strip_edges().to_upper()
	var clean_family: String = str(filters.get("contest_family", filters.get("family", ""))).strip_edges().to_upper()
	var clean_schedule: String = str(filters.get("schedule_kind", "")).strip_edges().to_upper()
	var has_price: bool = filters.has("price") or filters.has("entry_price") or filters.has("denomination")
	var target_price: int = maxi(0, int(filters.get("price", filters.get("entry_price", filters.get("denomination", 0)))))
	for contest_any in contests.values():
		var contest: ContestDef = contest_any as ContestDef
		if contest == null:
			continue
		if not contest.published:
			continue
		if not clean_scope.is_empty():
			var contest_scope: String = str(contest.scope).strip_edges().to_upper()
			if contest_scope == "YEARLY":
				contest_scope = "SEASONAL"
			if contest_scope != clean_scope:
				continue
		if not clean_pool.is_empty():
			var contest_pool: String = ContestDef.normalize_pool_type(contest.pool_type, contest.currency, contest.price)
			if contest_pool != clean_pool:
				continue
		if not clean_family.is_empty():
			var contest_family: String = ContestDef.normalize_contest_family(contest.contest_family, contest.mode, contest.scope)
			if contest_family != clean_family:
				continue
		if not clean_schedule.is_empty():
			var contest_schedule: String = ContestDef.normalize_schedule_kind(contest.schedule_kind)
			if contest_schedule != clean_schedule:
				continue
		if has_price and maxi(0, int(contest.price)) != target_price:
			continue
		result.append(contest)
	result.sort_custom(func(a: ContestDef, b: ContestDef) -> bool:
		if a.price != b.price:
			return a.price < b.price
		return a.id < b.id
	)
	return result

func get_contest_by_definition(filters: Dictionary = {}) -> ContestDef:
	var matches: Array[ContestDef] = get_contests_by_definition(filters)
	if matches.is_empty():
		return null
	return matches[0]

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

func preview_entry_requirements(contest_id: String, metadata: Dictionary = {}) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var normalized_id: String = normalize_contest_id(contest_id)
	var ticket_cost: int = contest.get_access_ticket_cost() if contest.has_method("get_access_ticket_cost") else maxi(0, int(contest.access_ticket_cost))
	var requires_ticket: bool = contest.requires_access_ticket() if contest.has_method("requires_access_ticket") else ticket_cost > 0
	var paid_entry: bool = contest.is_money_contest() if contest.has_method("is_money_contest") else int(contest.price) > 0
	var now_unix: int = int(Time.get_unix_time_from_system())
	var starts_at: int = maxi(0, int(contest.start_ts))
	var ends_at: int = maxi(0, int(contest.end_ts))
	var status_open: bool = str(contest.status).strip_edges().to_upper() in ["", "OPEN"]
	var entry_started: bool = starts_at <= 0 or now_unix >= starts_at
	var entry_not_closed: bool = ends_at <= 0 or now_unix < ends_at
	var entry_open: bool = status_open and entry_started and entry_not_closed
	var entry_price_usd: int = maxi(0, int(contest.price))
	var entry_price_cents: int = entry_price_usd * 100
	var balance_cents_known: bool = metadata.has("balance_cents") or metadata.has("wallet_balance_cents") or metadata.has("balance_usd")
	var balance_cents: int = _entry_balance_cents_from_metadata(metadata)
	var payment_required: bool = paid_entry and balance_cents_known and balance_cents < entry_price_cents
	var preview: Dictionary = {
		"ok": true,
		"contest_id": normalized_id,
		"already_entered": is_entered(normalized_id),
		"pool_type": ContestDef.normalize_pool_type(contest.pool_type, contest.currency, contest.price),
		"contest_family": ContestDef.normalize_contest_family(contest.contest_family, contest.mode, contest.scope),
		"schedule_kind": ContestDef.normalize_schedule_kind(contest.schedule_kind),
		"paid_entry": paid_entry,
		"requires_access_ticket": requires_ticket,
		"access_ticket_cost": ticket_cost,
		"entry_currency": "ACCESS_TICKET" if requires_ticket else str(contest.currency).to_upper(),
		"entry_price": ticket_cost if requires_ticket else int(contest.price),
		"entry_price_usd": entry_price_usd,
		"entry_price_cents": entry_price_cents,
		"wager_cents": entry_price_cents if paid_entry else 0,
		"entry_open": entry_open,
		"entry_status": str(contest.status).strip_edges().to_upper(),
		"entry_starts_unix": starts_at,
		"entry_ends_unix": ends_at,
		"balance_cents_known": balance_cents_known,
		"balance_cents": balance_cents if balance_cents_known else -1,
		"payment_required": payment_required,
		"missing_cents": maxi(0, entry_price_cents - balance_cents) if balance_cents_known else entry_price_cents,
		"prize_rewards": contest.prize_rewards.duplicate(true),
		"cash_payout_schedule": contest.get_cash_payout_schedule() if contest.has_method("get_cash_payout_schedule") else contest.prize_rewards.duplicate(true),
		"house_rake_bps": contest.get_house_rake_bps() if contest.has_method("get_house_rake_bps") else 1000,
		"payout_basis": "post_rake_pool" if paid_entry else ""
	}
	if not entry_open:
		preview["can_enter"] = false
		preview["reason"] = _entry_window_reason(status_open, entry_started, entry_not_closed)
		return preview
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
	elif paid_entry:
		if not balance_cents_known:
			preview["can_enter"] = false
			preview["reason"] = "balance_unknown"
		elif payment_required:
			preview["can_enter"] = false
			preview["reason"] = "insufficient_funds"
		else:
			preview["can_enter"] = true
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
	var preview: Dictionary = preview_entry_requirements(contest_id, metadata)
	if not bool(preview.get("ok", false)):
		return preview
	if bool(preview.get("already_entered", false)):
		return {"ok": true, "contest_id": str(preview.get("contest_id", "")), "already_entered": true}
	var normalized_id: String = str(preview.get("contest_id", ""))
	if not bool(preview.get("can_enter", false)):
		var blocked: Dictionary = preview.duplicate(true)
		blocked["ok"] = false
		blocked["entry_blocked"] = true
		return blocked
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
	if bool(preview.get("paid_entry", false)):
		var escrow_result: Dictionary = _open_paid_contest_entry_escrow(normalized_id, preview, metadata)
		if not bool(escrow_result.get("ok", false)):
			return escrow_result
		enter_contest(normalized_id)
		return {
			"ok": true,
			"contest_id": normalized_id,
			"paid_entry": true,
			"escrow": escrow_result,
			"entry_id": str(escrow_result.get("entry_id", "")),
			"wager_cents": maxi(0, int(escrow_result.get("wager_cents", preview.get("wager_cents", 0)))),
			"ledger_status": str(escrow_result.get("status", ""))
		}
	enter_contest(normalized_id)
	return {"ok": true, "contest_id": normalized_id}

func debug_get_async_money_entry_snapshot(entry_id: String) -> Dictionary:
	if _async_money_entry_ledger != null and _async_money_entry_ledger.has_method("get_entry_snapshot"):
		return _async_money_entry_ledger.call("get_entry_snapshot", entry_id) as Dictionary
	return {}

func debug_get_async_money_contest_snapshot(contest_id: String) -> Dictionary:
	if _async_money_entry_ledger != null and _async_money_entry_ledger.has_method("get_contest_snapshot"):
		return _async_money_entry_ledger.call("get_contest_snapshot", contest_id) as Dictionary
	return {}

func debug_get_async_money_ledger_snapshot() -> Dictionary:
	if _async_money_entry_ledger != null and _async_money_entry_ledger.has_method("get_snapshot"):
		return _async_money_entry_ledger.call("get_snapshot") as Dictionary
	return {}

func _entry_balance_cents_from_metadata(metadata: Dictionary) -> int:
	if metadata.has("balance_cents"):
		return maxi(0, int(metadata.get("balance_cents", 0)))
	if metadata.has("wallet_balance_cents"):
		return maxi(0, int(metadata.get("wallet_balance_cents", 0)))
	if metadata.has("balance_usd"):
		return maxi(0, int(metadata.get("balance_usd", 0))) * 100
	return -1

func _entry_window_reason(status_open: bool, entry_started: bool, entry_not_closed: bool) -> String:
	if not status_open:
		return "contest_not_open"
	if not entry_started:
		return "contest_not_started"
	if not entry_not_closed:
		return "contest_closed"
	return ""

func _open_paid_contest_entry_escrow(contest_id: String, preview: Dictionary, metadata: Dictionary) -> Dictionary:
	var player_id: String = _entry_player_id(metadata)
	if player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id", "contest_id": contest_id}
	var wager_cents: int = maxi(0, int(preview.get("wager_cents", 0)))
	if wager_cents <= 0:
		return {"ok": false, "reason": "invalid_wager", "contest_id": contest_id}
	var entry_id: String = str(metadata.get("entry_id", "")).strip_edges()
	if entry_id.is_empty():
		entry_id = _build_async_entry_id(contest_id, player_id)
	var idempotency_key: String = str(metadata.get("idempotency_key", "")).strip_edges()
	if idempotency_key.is_empty():
		idempotency_key = "open:%s" % entry_id
	var balance_cents: int = _entry_balance_cents_from_metadata(metadata)
	var backend_result: Dictionary = _open_paid_contest_entry_escrow_backend(entry_id, contest_id, player_id, wager_cents, idempotency_key, balance_cents)
	if bool(backend_result.get("ok", false)):
		backend_result["ledger_source"] = "backend"
		backend_result["paid_entry"] = true
		return backend_result
	if not _async_money_backend_fallback_allowed(backend_result):
		return backend_result
	if _async_money_entry_ledger == null or not _async_money_entry_ledger.has_method("intent_open_entry_escrow"):
		return {"ok": false, "reason": "async_money_ledger_unavailable", "contest_id": contest_id}
	var local_result: Dictionary = _async_money_entry_ledger.call("intent_open_entry_escrow", entry_id, contest_id, player_id, wager_cents, idempotency_key) as Dictionary
	if bool(local_result.get("ok", false)):
		local_result["ledger_source"] = "local"
		local_result["paid_entry"] = true
	return local_result

func _open_paid_contest_entry_escrow_backend(entry_id: String, contest_id: String, player_id: String, wager_cents: int, idempotency_key: String, balance_cents: int) -> Dictionary:
	var backend: Node = get_node_or_null("/root/VsHandshake")
	if backend == null or not backend.has_method("open_async_entry_escrow"):
		return {"ok": false, "handled": false, "err": "transport_not_configured"}
	return backend.call("open_async_entry_escrow", entry_id, contest_id, player_id, wager_cents, idempotency_key, balance_cents) as Dictionary

func _async_money_backend_fallback_allowed(result: Dictionary) -> bool:
	if result.is_empty():
		return true
	if bool(result.get("transport_error", false)):
		return true
	if not bool(result.get("handled", true)):
		return true
	var err: String = str(result.get("err", result.get("code", result.get("reason", "")))).strip_edges()
	return ["transport_not_configured", "unknown_action", "not_found"].has(err)

func _entry_player_id(metadata: Dictionary) -> String:
	var player_id: String = str(metadata.get("player_id", metadata.get("uid", ""))).strip_edges()
	if not player_id.is_empty():
		return player_id
	var profile_any: Variant = metadata.get("profile", {})
	if typeof(profile_any) == TYPE_DICTIONARY:
		player_id = str((profile_any as Dictionary).get("uid", (profile_any as Dictionary).get("player_id", ""))).strip_edges()
		if not player_id.is_empty():
			return player_id
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null and profile_manager.has_method("get_user_id"):
		player_id = str(profile_manager.call("get_user_id")).strip_edges()
	if player_id.is_empty():
		player_id = "local"
	return player_id

func _build_async_entry_id(contest_id: String, player_id: String) -> String:
	var clean_contest: String = contest_id.strip_edges()
	var clean_player: String = player_id.strip_edges()
	return "async:%s:%s" % [clean_contest, clean_player]

func _refund_paid_contest_entry_escrow(contest_id: String, reason: String, metadata: Dictionary = {}) -> Dictionary:
	var player_id: String = _entry_player_id(metadata)
	var entry_id: String = _build_async_entry_id(contest_id, player_id)
	var clean_reason: String = reason.strip_edges()
	if clean_reason.is_empty():
		clean_reason = "contest_entry_refund"
	var backend: Node = get_node_or_null("/root/VsHandshake")
	var idempotency_key: String = "refund:%s:%s" % [entry_id, clean_reason]
	if backend != null and backend.has_method("refund_async_entry"):
		var backend_result: Dictionary = backend.call("refund_async_entry", entry_id, clean_reason, idempotency_key) as Dictionary
		if bool(backend_result.get("ok", false)):
			backend_result["ledger_source"] = "backend"
			return backend_result
		if not _async_money_backend_fallback_allowed(backend_result):
			return backend_result
	if _async_money_entry_ledger == null or not _async_money_entry_ledger.has_method("intent_refund_entry"):
		return {"ok": false, "reason": "async_money_ledger_unavailable", "contest_id": contest_id, "entry_id": entry_id}
	var local_result: Dictionary = _async_money_entry_ledger.call("intent_refund_entry", entry_id, clean_reason, idempotency_key) as Dictionary
	if bool(local_result.get("ok", false)):
		local_result["ledger_source"] = "local"
	return local_result

func intent_refund_contest_entry(contest_id: String, reason: String = "contest_entry_refund", metadata: Dictionary = {}) -> Dictionary:
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
	var paid_entry: bool = contest.is_money_contest() if contest.has_method("is_money_contest") else int(contest.price) > 0
	if paid_entry:
		var paid_refund: Dictionary = _refund_paid_contest_entry_escrow(normalized_id, reason, metadata)
		if not bool(paid_refund.get("ok", false)):
			return paid_refund
		player_entries.erase(normalized_id)
		_save_entries()
		return {"ok": true, "contest_id": normalized_id, "paid_entry": true, "refund_result": paid_refund}
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
	var normalized_id: String = normalize_contest_id(contest_id)
	var seed_entries: Array = _load_seed_leaderboard_entries(normalized_id, map_id)
	var runtime_entries: Array = _runtime_leaderboard_entries(normalized_id, map_id)
	return _merge_leaderboard_entries(seed_entries, runtime_entries)

func record_stage_race_map_result(contest_id: String, map_id: String, result: Dictionary) -> Dictionary:
	var normalized_id: String = normalize_contest_id(contest_id)
	var normalized_map_id: String = str(map_id).strip_edges()
	if normalized_id.is_empty():
		return {"ok": false, "reason": "contest_id_empty"}
	if normalized_map_id.is_empty():
		return {"ok": false, "reason": "map_id_empty", "contest_id": normalized_id}
	var player_id: String = str(result.get("player_id", result.get("uid", ""))).strip_edges()
	if player_id.is_empty():
		return {"ok": false, "reason": "player_id_empty", "contest_id": normalized_id, "map_id": normalized_map_id}
	var time_ms: int = _result_time_ms(result)
	if time_ms <= 0:
		return {"ok": false, "reason": "time_ms_empty", "contest_id": normalized_id, "map_id": normalized_map_id}
	var now_ts: int = int(Time.get_unix_time_from_system())
	var player_name: String = str(result.get("player_name", result.get("handle", result.get("name", player_id)))).strip_edges()
	if player_name.is_empty():
		player_name = player_id
	var stage_index: int = _result_stage_index(result)
	var contest_rows: Dictionary = {}
	if typeof(runtime_leaderboards.get(normalized_id, {})) == TYPE_DICTIONARY:
		contest_rows = (runtime_leaderboards.get(normalized_id, {}) as Dictionary).duplicate(true)
	var rows: Array = []
	if typeof(contest_rows.get(normalized_map_id, [])) == TYPE_ARRAY:
		rows = (contest_rows.get(normalized_map_id, []) as Array).duplicate(true)
	var run_id: String = str(result.get("run_id", "")).strip_edges()
	var entry_index: int = -1
	for i in range(rows.size()):
		var row_any: Variant = rows[i]
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if _entry_stage_index(row) != stage_index:
			continue
		if run_id.is_empty() and str(row.get("player_id", "")).strip_edges() == player_id and str(row.get("run_id", "")).strip_edges().is_empty():
			entry_index = i
			break
		if not run_id.is_empty() and str(row.get("player_id", "")).strip_edges() == player_id and str(row.get("run_id", "")).strip_edges() == run_id:
			entry_index = i
			break
	var updated: bool = false
	var entry: Dictionary = {}
	if entry_index >= 0:
		entry = (rows[entry_index] as Dictionary).duplicate(true)
		var existing_time_ms: int = _entry_time_ms(entry)
		if existing_time_ms <= 0 or time_ms < existing_time_ms:
			entry["best_time_ms"] = time_ms
			entry["best_score"] = time_ms
			entry["time_ms"] = time_ms
			entry["best_run_ts"] = int(result.get("updated_at", now_ts))
			updated = true
		entry["runs_count"] = int(entry.get("runs_count", 0)) + 1
	else:
		entry = {
			"player_id": player_id,
			"player_name": player_name,
			"hive_name": str(result.get("hive_name", "")).strip_edges(),
			"best_time_ms": time_ms,
			"best_score": time_ms,
			"time_ms": time_ms,
			"best_run_ts": int(result.get("updated_at", now_ts)),
			"runs_count": 1,
			"source": str(result.get("source", "stage_race_runtime")).strip_edges()
		}
		if not run_id.is_empty():
			entry["run_id"] = run_id
		if stage_index >= 0:
			entry["stage_index"] = stage_index
		updated = true
	var hive_name: String = str(result.get("hive_name", "")).strip_edges()
	if not player_name.is_empty():
		entry["player_name"] = player_name
	if not hive_name.is_empty():
		entry["hive_name"] = hive_name
	entry["updated_at"] = int(result.get("updated_at", now_ts))
	entry["source"] = str(entry.get("source", "stage_race_runtime")).strip_edges()
	if not run_id.is_empty():
		entry["run_id"] = run_id
	if stage_index >= 0:
		entry["stage_index"] = stage_index
	if entry_index >= 0:
		rows[entry_index] = entry
	else:
		rows.append(entry)
	rows.sort_custom(func(a: Variant, b: Variant) -> bool:
		if typeof(a) != TYPE_DICTIONARY:
			return false
		if typeof(b) != TYPE_DICTIONARY:
			return true
		var a_entry: Dictionary = a as Dictionary
		var b_entry: Dictionary = b as Dictionary
		var a_time: int = _entry_time_ms(a_entry)
		var b_time: int = _entry_time_ms(b_entry)
		if a_time != b_time:
			return a_time < b_time
		var a_player: String = str(a_entry.get("player_id", ""))
		var b_player: String = str(b_entry.get("player_id", ""))
		if a_player != b_player:
			return a_player < b_player
		var a_stage: int = _entry_stage_index(a_entry)
		var b_stage: int = _entry_stage_index(b_entry)
		if a_stage != b_stage:
			return a_stage < b_stage
		return str(a_entry.get("run_id", "")) < str(b_entry.get("run_id", ""))
	)
	contest_rows[normalized_map_id] = rows
	runtime_leaderboards[normalized_id] = contest_rows
	_save_runtime_leaderboards()
	return {
		"ok": true,
		"contest_id": normalized_id,
		"map_id": normalized_map_id,
		"player_id": player_id,
		"run_id": run_id,
		"stage_index": stage_index,
		"best_time_ms": int(entry.get("best_time_ms", time_ms)),
		"runs_count": int(entry.get("runs_count", 1)),
		"updated": updated
	}

func debug_set_runtime_leaderboard_save_path(path: String) -> void:
	_runtime_leaderboard_save_path = path if not path.strip_edges().is_empty() else RUNTIME_LEADERBOARD_SAVE_PATH
	_load_runtime_leaderboards()

func debug_reset_runtime_leaderboards() -> void:
	runtime_leaderboards.clear()
	_save_runtime_leaderboards()

func _load_seed_leaderboard_entries(normalized_id: String, map_id: String) -> Array:
	var path: String = "%s/%s/%s.json" % [LEADERBOARDS_DIR, normalized_id, map_id]
	if not FileAccess.file_exists(path):
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var json: JSON = JSON.new()
	var err: int = json.parse(f.get_as_text())
	if err != OK:
		return []
	if typeof(json.data) != TYPE_ARRAY:
		return []
	return json.data

func get_best_score(contest_id: String, map_id: String) -> int:
	var entries: Array = get_leaderboard_entries(contest_id, map_id)
	if entries.is_empty():
		return 0
	var best_score: int = 0
	for entry_any in entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var score: int = _entry_time_ms(entry_any as Dictionary)
		if score <= 0:
			continue
		if best_score <= 0 or score < best_score:
			best_score = score
	return best_score

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

func record_timed_race_result(contest_id: String, result: Dictionary) -> Dictionary:
	var normalized_id: String = normalize_contest_id(contest_id)
	if normalized_id.is_empty():
		return {"ok": false, "reason": "contest_id_empty"}
	var player_id: String = str(result.get("player_id", result.get("uid", ""))).strip_edges()
	if player_id.is_empty():
		return {"ok": false, "reason": "player_id_empty", "contest_id": normalized_id}
	var resolved_map_count: int = _resolve_timed_map_count(int(result.get("map_count", result.get("required_maps", TIMED_RACE_DEFAULT_MAP_COUNT))))
	var map_times: Array[int] = _int_array(result.get("map_times_ms", []), resolved_map_count)
	var completed_maps: int = mini(maxi(int(result.get("completed_maps", map_times.size())), 0), resolved_map_count)
	if map_times.size() > completed_maps:
		map_times = map_times.slice(0, completed_maps)
	var aggregate_ms: int = maxi(0, int(result.get("aggregate_ms", 0)))
	if aggregate_ms <= 0:
		for time_ms in map_times:
			aggregate_ms += maxi(0, int(time_ms))
	var failed_elapsed_ms: int = maxi(0, int(result.get("failed_map_elapsed_ms", 0)))
	var run_id: String = str(result.get("run_id", "")).strip_edges()
	var now_ts: int = int(Time.get_unix_time_from_system())
	var player_name: String = str(result.get("player_name", result.get("handle", result.get("name", player_id)))).strip_edges()
	if player_name.is_empty():
		player_name = player_id
	var contest_rows: Dictionary = {}
	if typeof(runtime_leaderboards.get(normalized_id, {})) == TYPE_DICTIONARY:
		contest_rows = (runtime_leaderboards.get(normalized_id, {}) as Dictionary).duplicate(true)
	var rows: Array = []
	if typeof(contest_rows.get(RACE_LEADERBOARD_KEY, [])) == TYPE_ARRAY:
		rows = (contest_rows.get(RACE_LEADERBOARD_KEY, []) as Array).duplicate(true)
	var entry_index: int = -1
	for i in range(rows.size()):
		var row_any: Variant = rows[i]
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		var row_player: String = str(row.get("player_id", "")).strip_edges()
		var row_run: String = str(row.get("run_id", "")).strip_edges()
		if row_player == player_id and ((run_id.is_empty() and row_run.is_empty()) or (not run_id.is_empty() and row_run == run_id)):
			entry_index = i
			break
	var entry: Dictionary = {
		"player_id": player_id,
		"player_name": player_name,
		"hive_name": str(result.get("hive_name", "")).strip_edges(),
		"run_id": run_id,
		"completed_maps": completed_maps,
		"required_maps": resolved_map_count,
		"completed_all": completed_maps >= resolved_map_count,
		"aggregate_ms": aggregate_ms,
		"failed_map_elapsed_ms": failed_elapsed_ms,
		"map_times_ms": map_times.duplicate(),
		"status": str(result.get("status", "")).strip_edges(),
		"updated_at": int(result.get("updated_at", now_ts)),
		"source": str(result.get("source", "timed_race_runtime")).strip_edges()
	}
	if entry_index >= 0:
		rows[entry_index] = entry
	else:
		rows.append(entry)
	rows.sort_custom(func(a: Variant, b: Variant) -> bool:
		if typeof(a) != TYPE_DICTIONARY:
			return false
		if typeof(b) != TYPE_DICTIONARY:
			return true
		return _timed_race_row_precedes(a as Dictionary, b as Dictionary)
	)
	contest_rows[RACE_LEADERBOARD_KEY] = rows
	runtime_leaderboards[normalized_id] = contest_rows
	_save_runtime_leaderboards()
	var rank: int = 0
	for i in range(rows.size()):
		var row_any: Variant = rows[i]
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("player_id", "")).strip_edges() == player_id and str(row.get("run_id", "")).strip_edges() == run_id:
			rank = i + 1
			break
	return {
		"ok": true,
		"contest_id": normalized_id,
		"player_id": player_id,
		"run_id": run_id,
		"rank": rank,
		"completed_maps": completed_maps,
		"required_maps": resolved_map_count,
		"aggregate_ms": aggregate_ms,
		"updated": true
	}

func build_timed_race_leaderboard(contest_id: String, limit: int = 10) -> Array[Dictionary]:
	var normalized_id: String = normalize_contest_id(contest_id)
	if typeof(runtime_leaderboards.get(normalized_id, {})) != TYPE_DICTIONARY:
		return []
	var contest_rows: Dictionary = runtime_leaderboards.get(normalized_id, {}) as Dictionary
	if typeof(contest_rows.get(RACE_LEADERBOARD_KEY, [])) != TYPE_ARRAY:
		return []
	var rows: Array[Dictionary] = []
	for row_any in contest_rows.get(RACE_LEADERBOARD_KEY, []) as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		rows.append((row_any as Dictionary).duplicate(true))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _timed_race_row_precedes(a, b)
	)
	rows = _best_timed_race_rows_by_player(rows)
	for i in range(rows.size()):
		rows[i]["rank"] = i + 1
	if limit > 0 and rows.size() > limit:
		return rows.slice(0, limit)
	return rows

func build_timed_race_money_closeout_request(contest_id: String, map_count: int = TIMED_RACE_DEFAULT_MAP_COUNT) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var normalized_id: String = normalize_contest_id(contest_id)
	if maxi(0, int(contest.price)) <= 0:
		return {"ok": false, "reason": "contest_not_money", "contest_id": normalized_id}
	var schedule: Array[Dictionary] = _cash_payout_schedule_for_closeout(contest)
	var validation: Dictionary = _validate_money_payout_schedule_for_closeout(normalized_id, contest, schedule)
	if not bool(validation.get("ok", false)):
		return validation
	var max_placement: int = int(validation.get("max_placement", 1))
	var resolved_map_count: int = _resolve_timed_map_count(map_count)
	var rows: Array[Dictionary] = build_timed_race_leaderboard(normalized_id, 0)
	var qualified_rows: Array[Dictionary] = []
	for row in rows:
		if int(row.get("completed_maps", 0)) >= resolved_map_count:
			qualified_rows.append(row)
	if qualified_rows.size() < max_placement:
		return {
			"ok": false,
			"reason": "insufficient_completed_runs",
			"contest_id": normalized_id,
			"qualified_count": qualified_rows.size(),
			"required_placement": max_placement,
			"required_maps": resolved_map_count
		}
	var payout_rows: Array[Dictionary] = qualified_rows.slice(0, max_placement)
	var backend_payouts: Array[Dictionary] = _build_payouts_from_ranked_rows(normalized_id, payout_rows, schedule)
	if backend_payouts.is_empty():
		return {"ok": false, "reason": "missing_qualified_payouts", "contest_id": normalized_id}
	return {
		"ok": true,
		"type": "timed_race_money_closeout_request",
		"contest_id": normalized_id,
		"contest_family": "RACE",
		"map_count": resolved_map_count,
		"house_rake_bps": int(validation.get("house_rake_bps", 1000)),
		"payouts": backend_payouts,
		"leaderboard_rows": payout_rows
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
	var by_run: Dictionary = {}
	for stage_index in range(stage_maps.size()):
		var map_id: String = str(stage_maps[stage_index])
		var entries: Array = get_leaderboard_entries(contest.id, map_id)
		for entry_v in entries:
			if typeof(entry_v) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_v as Dictionary
			var entry_stage_index: int = _entry_stage_index(entry)
			if entry_stage_index >= 0 and entry_stage_index != stage_index:
				continue
			var player_id: String = str(entry.get("player_id", ""))
			if player_id.is_empty():
				continue
			var run_id: String = str(entry.get("run_id", "")).strip_edges()
			var row_key: String = _stage_race_overall_row_key(player_id, run_id)
			var row: Dictionary = by_run.get(row_key, {
				"player_id": player_id,
				"player_name": str(entry.get("player_name", player_id)),
				"hive_name": str(entry.get("hive_name", "")),
				"run_id": run_id,
				"completed_maps": 0,
				"aggregate_time_ms": 0,
				"map_times_ms": {},
				"runs_count": 0
			})
			var map_times: Dictionary = row.get("map_times_ms", {}) as Dictionary
			var stage_slot_key: String = _stage_slot_key(map_id, stage_index, entry_stage_index)
			if map_times.has(stage_slot_key):
				continue
			var time_ms: int = _entry_time_ms(entry)
			map_times[stage_slot_key] = time_ms
			row["map_times_ms"] = map_times
			row["completed_maps"] = int(row.get("completed_maps", 0)) + 1
			row["aggregate_time_ms"] = int(row.get("aggregate_time_ms", 0)) + time_ms
			row["runs_count"] = int(row.get("runs_count", 0)) + int(entry.get("runs_count", 0))
			by_run[row_key] = row
	var rows: Array[Dictionary] = []
	var required_maps: int = stage_maps.size()
	for player_row_v in by_run.values():
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
		if a_id != b_id:
			return a_id < b_id
		return str(a.get("run_id", "")) < str(b.get("run_id", ""))
	)
	rows = _best_stage_race_rows_by_player(rows)
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

func build_stage_race_money_closeout_request(contest_id: String, map_count: int = TIMED_GAME_DEFAULT_MAP_COUNT) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var normalized_id: String = normalize_contest_id(contest_id)
	if maxi(0, int(contest.price)) <= 0:
		return {"ok": false, "reason": "contest_not_money", "contest_id": normalized_id}
	var schedule: Array[Dictionary] = contest.get_cash_payout_schedule() if contest.has_method("get_cash_payout_schedule") else []
	if schedule.is_empty():
		return {"ok": false, "reason": "missing_cash_payout_schedule", "contest_id": normalized_id}
	var house_rake_bps: int = contest.get_house_rake_bps() if contest.has_method("get_house_rake_bps") else 1000
	var payout_total_bps: int = 0
	var max_placement: int = 1
	for payout in schedule:
		var placement: int = maxi(1, int(payout.get("placement", 0)))
		var payout_bps: int = clampi(int(payout.get("payout_bps", 0)), 0, 10000)
		max_placement = maxi(max_placement, placement)
		payout_total_bps += payout_bps
	if payout_total_bps != 10000:
		return {
			"ok": false,
			"reason": "payout_schedule_not_balanced",
			"contest_id": normalized_id,
			"payout_total_bps": payout_total_bps,
			"house_rake_bps": house_rake_bps,
			"payout_basis": "post_rake_pool"
		}
	var resolved_map_count: int = _resolve_timed_map_count(map_count)
	if map_count <= 0:
		resolved_map_count = contest.map_ids.size()
	var rows: Array[Dictionary] = build_stage_race_overall_leaderboard(normalized_id, resolved_map_count, max_placement)
	if rows.size() < max_placement:
		return {
			"ok": false,
			"reason": "insufficient_qualified_players",
			"contest_id": normalized_id,
			"qualified_count": rows.size(),
			"required_placement": max_placement
		}
	var backend_payouts: Array[Dictionary] = []
	for payout in schedule:
		var placement: int = maxi(1, int(payout.get("placement", 0)))
		var row: Dictionary = rows[placement - 1]
		var player_id: String = str(row.get("player_id", "")).strip_edges()
		var completed_maps: int = maxi(0, int(row.get("completed_maps", 0)))
		if player_id.is_empty():
			return {"ok": false, "reason": "leaderboard_player_id_empty", "contest_id": normalized_id, "placement": placement}
		if completed_maps < resolved_map_count:
			return {
				"ok": false,
				"reason": "insufficient_completed_runs",
				"contest_id": normalized_id,
				"placement": placement,
				"player_id": player_id,
				"completed_maps": completed_maps,
				"required_maps": resolved_map_count
			}
		backend_payouts.append({
			"placement": placement,
			"player_id": player_id,
			"payout_bps": clampi(int(payout.get("payout_bps", 0)), 0, 10000)
		})
	return {
		"ok": true,
		"type": "stage_race_money_closeout_request",
		"contest_id": normalized_id,
		"map_count": resolved_map_count,
		"house_rake_bps": house_rake_bps,
		"payouts": backend_payouts,
		"leaderboard_rows": rows
	}

func record_gauntlet_run_result(contest_id: String, result: Dictionary) -> Dictionary:
	var normalized_id: String = normalize_contest_id(contest_id)
	if normalized_id.is_empty():
		return {"ok": false, "reason": "contest_id_empty"}
	var player_id: String = str(result.get("player_id", result.get("uid", ""))).strip_edges()
	if player_id.is_empty():
		return {"ok": false, "reason": "player_id_empty", "contest_id": normalized_id}
	var run_id: String = str(result.get("run_id", "")).strip_edges()
	if run_id.is_empty():
		return {"ok": false, "reason": "run_id_empty", "contest_id": normalized_id, "player_id": player_id}
	var total_stars: int = maxi(0, int(result.get("total_stars", 0)))
	var max_stars: int = maxi(total_stars, int(result.get("max_stars", 0)))
	var completed_stages: int = maxi(0, int(result.get("completed_stages", result.get("completed_maps", 0))))
	var stage_count: int = maxi(completed_stages, int(result.get("stage_count", result.get("required_stages", 0))))
	var elapsed_ms: int = maxi(0, int(result.get("elapsed_ms", result.get("total_elapsed_ms", 0))))
	var now_ts: int = int(Time.get_unix_time_from_system())
	var player_name: String = str(result.get("player_name", result.get("handle", result.get("name", player_id)))).strip_edges()
	if player_name.is_empty():
		player_name = player_id
	var contest_rows: Dictionary = {}
	if typeof(runtime_leaderboards.get(normalized_id, {})) == TYPE_DICTIONARY:
		contest_rows = (runtime_leaderboards.get(normalized_id, {}) as Dictionary).duplicate(true)
	var rows: Array = []
	if typeof(contest_rows.get(GAUNTLET_LEADERBOARD_KEY, [])) == TYPE_ARRAY:
		rows = (contest_rows.get(GAUNTLET_LEADERBOARD_KEY, []) as Array).duplicate(true)
	var entry_index: int = -1
	for i in range(rows.size()):
		var row_any: Variant = rows[i]
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("player_id", "")).strip_edges() == player_id and str(row.get("run_id", "")).strip_edges() == run_id:
			entry_index = i
			break
	var entry: Dictionary = {
		"player_id": player_id,
		"player_name": player_name,
		"hive_name": str(result.get("hive_name", "")).strip_edges(),
		"run_id": run_id,
		"total_stars": total_stars,
		"max_stars": max_stars,
		"completed_stages": completed_stages,
		"stage_count": stage_count,
		"elapsed_ms": elapsed_ms,
		"status": str(result.get("status", "")).strip_edges(),
		"updated_at": int(result.get("updated_at", now_ts)),
		"source": str(result.get("source", "gauntlet_runtime")).strip_edges()
	}
	var stage_results_any: Variant = result.get("stage_results", [])
	if typeof(stage_results_any) == TYPE_ARRAY:
		entry["stage_results"] = (stage_results_any as Array).duplicate(true)
	if entry_index >= 0:
		rows[entry_index] = entry
	else:
		rows.append(entry)
	rows.sort_custom(func(a: Variant, b: Variant) -> bool:
		if typeof(a) != TYPE_DICTIONARY:
			return false
		if typeof(b) != TYPE_DICTIONARY:
			return true
		return _gauntlet_row_precedes(a as Dictionary, b as Dictionary)
	)
	contest_rows[GAUNTLET_LEADERBOARD_KEY] = rows
	runtime_leaderboards[normalized_id] = contest_rows
	_save_runtime_leaderboards()
	var rank: int = 0
	for i in range(rows.size()):
		var row_any: Variant = rows[i]
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("player_id", "")).strip_edges() == player_id and str(row.get("run_id", "")).strip_edges() == run_id:
			rank = i + 1
			break
	return {
		"ok": true,
		"contest_id": normalized_id,
		"player_id": player_id,
		"run_id": run_id,
		"rank": rank,
		"total_stars": total_stars,
		"completed_stages": completed_stages,
		"updated": true
	}

func build_gauntlet_leaderboard(contest_id: String, limit: int = 10) -> Array[Dictionary]:
	var normalized_id: String = normalize_contest_id(contest_id)
	if typeof(runtime_leaderboards.get(normalized_id, {})) != TYPE_DICTIONARY:
		return []
	var contest_rows: Dictionary = runtime_leaderboards.get(normalized_id, {}) as Dictionary
	if typeof(contest_rows.get(GAUNTLET_LEADERBOARD_KEY, [])) != TYPE_ARRAY:
		return []
	var rows: Array[Dictionary] = []
	for row_any in contest_rows.get(GAUNTLET_LEADERBOARD_KEY, []) as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		rows.append((row_any as Dictionary).duplicate(true))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _gauntlet_row_precedes(a, b)
	)
	for i in range(rows.size()):
		rows[i]["rank"] = i + 1
	if limit > 0 and rows.size() > limit:
		return rows.slice(0, limit)
	return rows

func build_gauntlet_money_closeout_request(contest_id: String) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var normalized_id: String = normalize_contest_id(contest_id)
	if maxi(0, int(contest.price)) <= 0:
		return {"ok": false, "reason": "contest_not_money", "contest_id": normalized_id}
	var schedule: Array[Dictionary] = _cash_payout_schedule_for_closeout(contest)
	var validation: Dictionary = _validate_money_payout_schedule_for_closeout(normalized_id, contest, schedule)
	if not bool(validation.get("ok", false)):
		return validation
	var max_placement: int = int(validation.get("max_placement", 1))
	var rows: Array[Dictionary] = build_gauntlet_leaderboard(normalized_id, max_placement)
	if rows.size() < max_placement:
		return {
			"ok": false,
			"reason": "insufficient_qualified_players",
			"contest_id": normalized_id,
			"qualified_count": rows.size(),
			"required_placement": max_placement
		}
	var backend_payouts: Array[Dictionary] = _build_payouts_from_ranked_rows(normalized_id, rows, schedule)
	if backend_payouts.is_empty():
		return {"ok": false, "reason": "missing_qualified_payouts", "contest_id": normalized_id}
	return {
		"ok": true,
		"type": "gauntlet_money_closeout_request",
		"contest_id": normalized_id,
		"contest_family": "GAUNTLET",
		"house_rake_bps": int(validation.get("house_rake_bps", 1000)),
		"payouts": backend_payouts,
		"leaderboard_rows": rows
	}

func build_money_contest_closeout_request(contest_id: String, map_count: int = TIMED_GAME_DEFAULT_MAP_COUNT) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var family: String = ContestDef.normalize_contest_family(contest.contest_family, contest.mode, contest.scope)
	match family:
		"STAGE_RACE":
			return build_stage_race_money_closeout_request(contest_id, map_count)
		"GAUNTLET":
			return build_gauntlet_money_closeout_request(contest_id)
		"RACE":
			return build_timed_race_money_closeout_request(contest_id, map_count)
		"MISS_N_OUT":
			return build_miss_n_out_money_closeout_request(contest_id)
		_:
			return {
				"ok": false,
				"reason": "unsupported_money_closeout_family",
				"contest_id": normalize_contest_id(contest_id),
				"contest_family": family
			}

func request_stage_race_money_payout_approval(contest_id: String, map_count: int = TIMED_GAME_DEFAULT_MAP_COUNT) -> Dictionary:
	var status_check: Dictionary = _validate_money_payout_status_for_request(contest_id)
	if not bool(status_check.get("ok", false)):
		return status_check
	var backend_result_report: Dictionary = _request_backend_result_payout_approval(contest_id, map_count)
	if bool(backend_result_report.get("ok", false)) or not _async_money_backend_fallback_allowed(backend_result_report):
		if bool(backend_result_report.get("ok", false)):
			_mark_contest_payout_pending(str(backend_result_report.get("contest_id", contest_id)))
		return backend_result_report
	var closeout: Dictionary = build_money_contest_closeout_request(contest_id, map_count)
	if not bool(closeout.get("ok", false)):
		return closeout
	var backend: Node = get_node_or_null("/root/VsHandshake")
	if backend == null or not backend.has_method("preview_async_contest_payout_report"):
		closeout["ok"] = false
		closeout["reason"] = "backend_unavailable"
		return closeout
	var result: Dictionary = backend.call(
		"preview_async_contest_payout_report",
		str(closeout.get("contest_id", "")),
		closeout.get("payouts", []) as Array,
		int(closeout.get("house_rake_bps", 1000))
	) as Dictionary
	if bool(result.get("ok", false)):
		result["closeout_request"] = closeout.duplicate(true)
		_mark_contest_payout_pending(str(result.get("contest_id", closeout.get("contest_id", contest_id))))
		return result
	result["closeout_request"] = closeout.duplicate(true)
	return result

func finalize_stage_race_money_contest(contest_id: String, map_count: int = TIMED_GAME_DEFAULT_MAP_COUNT) -> Dictionary:
	return request_stage_race_money_payout_approval(contest_id, map_count)

func request_money_contest_payout_approval(contest_id: String, map_count: int = TIMED_GAME_DEFAULT_MAP_COUNT) -> Dictionary:
	return request_stage_race_money_payout_approval(contest_id, map_count)

func process_scheduled_money_contest_closeouts(now_unix: int = 0, options: Dictionary = {}) -> Dictionary:
	var resolved_now: int = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var result: Dictionary = {
		"ok": true,
		"type": "scheduled_money_contest_closeout_sweep",
		"now_unix": resolved_now,
		"checked_count": 0,
		"closed_count": 0,
		"queued_count": 0,
		"skipped_count": 0,
		"failed_count": 0,
		"closed_contests": [],
		"queued_reports": [],
		"skipped": [],
		"failed": []
	}
	var map_count_override: int = maxi(0, int(options.get("map_count", 0)))
	for contest_any in contests.values():
		var contest: ContestDef = contest_any as ContestDef
		if contest == null:
			continue
		if not _scheduled_money_closeout_due(contest, resolved_now):
			continue
		result["checked_count"] = int(result.get("checked_count", 0)) + 1
		var normalized_id: String = normalize_contest_id(contest.id)
		if _mark_contest_closed_for_payout(contest):
			result["closed_count"] = int(result.get("closed_count", 0)) + 1
			(result["closed_contests"] as Array).append(normalized_id)
		var existing: Dictionary = _existing_payout_report_for_contest(normalized_id)
		if bool(existing.get("ok", false)) and bool(existing.get("found", false)):
			_sync_contest_status_from_existing_report(contest, existing.get("report", {}) as Dictionary)
			result["skipped_count"] = int(result.get("skipped_count", 0)) + 1
			(result["skipped"] as Array).append({
				"contest_id": normalized_id,
				"reason": "payout_report_already_exists",
				"report_id": str((existing.get("report", {}) as Dictionary).get("report_id", ""))
			})
			continue
		if not bool(existing.get("ok", false)) and not _async_money_backend_fallback_allowed(existing):
			result["failed_count"] = int(result.get("failed_count", 0)) + 1
			(result["failed"] as Array).append({
				"contest_id": normalized_id,
				"reason": _result_reason(existing),
				"result": existing
			})
			continue
		var closeout_map_count: int = map_count_override if map_count_override > 0 else _closeout_map_count_for_contest(contest)
		var report: Dictionary = request_money_contest_payout_approval(normalized_id, closeout_map_count)
		if bool(report.get("ok", false)):
			result["queued_count"] = int(result.get("queued_count", 0)) + 1
			(result["queued_reports"] as Array).append({
				"contest_id": normalized_id,
				"report_id": str(report.get("report_id", "")),
				"result_source": str(report.get("result_source", report.get("closeout_source", ""))),
				"approval_status": str(report.get("approval_status", "pending_approval"))
			})
		else:
			result["failed_count"] = int(result.get("failed_count", 0)) + 1
			(result["failed"] as Array).append({
				"contest_id": normalized_id,
				"reason": _result_reason(report),
				"result": report
			})
	return result

func _scheduled_money_closeout_due(contest: ContestDef, now_unix: int) -> bool:
	if contest == null:
		return false
	if contest.has_method("normalize_definition"):
		contest.normalize_definition()
	if not contest.published:
		return false
	if not contest.requires_payout_approval():
		return false
	var end_ts: int = maxi(0, int(contest.end_ts))
	if end_ts <= 0 or now_unix < end_ts:
		return false
	var status: String = str(contest.status).strip_edges().to_upper()
	return not _contest_status_blocks_payout(status)

func _mark_contest_closed_for_payout(contest: ContestDef) -> bool:
	var status: String = str(contest.status).strip_edges().to_upper()
	if status == "CLOSED" or status == "PAYOUT_PENDING" or status == "PAYOUT_APPROVED" or status == "SETTLED":
		return false
	contest.status = "CLOSED"
	return true

func mark_money_contest_payout_approved(contest_id: String, approval_report: Dictionary = {}) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var normalized_id: String = normalize_contest_id(contest_id)
	var status: String = str(contest.status).strip_edges().to_upper()
	if _contest_status_blocks_payout(status):
		return {"ok": false, "reason": "contest_status_blocks_payout", "contest_id": normalized_id, "status": status}
	if status == "PAYOUT_APPROVED" or status == "SETTLED":
		return {"ok": true, "contest_id": normalized_id, "status": status, "already_marked": true}
	contest.status = "PAYOUT_APPROVED"
	return {
		"ok": true,
		"contest_id": normalized_id,
		"status": contest.status,
		"approval_id": str(approval_report.get("report_id", approval_report.get("approval_id", ""))),
		"approved_by": str(approval_report.get("approved_by", ""))
	}

func _mark_contest_payout_pending(contest_id: String) -> void:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return
	var status: String = str(contest.status).strip_edges().to_upper()
	if status == "PAYOUT_APPROVED" or status == "SETTLED" or _contest_status_blocks_payout(status):
		return
	contest.status = "PAYOUT_PENDING"

func _sync_contest_status_from_existing_report(contest: ContestDef, report: Dictionary) -> void:
	if contest == null:
		return
	var status: String = str(report.get("approval_status", "")).strip_edges().to_lower()
	if status == "approved":
		contest.status = "PAYOUT_APPROVED"
	elif status == "pending_approval":
		contest.status = "PAYOUT_PENDING"

func _validate_money_payout_status_for_request(contest_id: String) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var normalized_id: String = normalize_contest_id(contest_id)
	var status: String = str(contest.status).strip_edges().to_upper()
	if _contest_status_blocks_payout(status) or status == "PAYOUT_APPROVED" or status == "SETTLED":
		return {"ok": false, "reason": "contest_status_blocks_payout", "contest_id": normalized_id, "status": status}
	return {"ok": true, "contest_id": normalized_id, "status": status}

func _contest_status_blocks_payout(status: String) -> bool:
	return ["CANCELLED", "CANCELED", "VOID", "VOIDED", "REFUNDED"].has(status.strip_edges().to_upper())

func _existing_payout_report_for_contest(contest_id: String) -> Dictionary:
	var backend: Node = get_node_or_null("/root/VsHandshake")
	if backend == null or not backend.has_method("list_async_contest_payout_reports"):
		return {"ok": false, "handled": false, "err": "transport_not_configured"}
	var result: Dictionary = backend.call("list_async_contest_payout_reports", {
		"contest_id": contest_id,
		"limit": 1,
		"sort_desc": true
	}) as Dictionary
	if not bool(result.get("ok", false)):
		return result
	var reports: Array = result.get("reports", []) as Array
	if reports.is_empty():
		return {"ok": true, "found": false}
	var report_any: Variant = reports[0]
	if typeof(report_any) != TYPE_DICTIONARY:
		return {"ok": false, "err": "invalid_payout_report_payload"}
	return {"ok": true, "found": true, "report": (report_any as Dictionary).duplicate(true)}

func _closeout_map_count_for_contest(contest: ContestDef) -> int:
	var family: String = ContestDef.normalize_contest_family(contest.contest_family, contest.mode, contest.scope)
	if family == "RACE":
		return _resolve_timed_map_count(contest.map_ids.size())
	if contest.map_ids.size() > 0:
		return _resolve_timed_map_count(contest.map_ids.size())
	return TIMED_GAME_DEFAULT_MAP_COUNT

func _result_reason(result: Dictionary) -> String:
	var reason: String = str(result.get("reason", result.get("err", result.get("code", "")))).strip_edges()
	return reason if not reason.is_empty() else "unknown_error"

func _request_backend_result_payout_approval(contest_id: String, map_count: int = TIMED_GAME_DEFAULT_MAP_COUNT) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var family: String = ContestDef.normalize_contest_family(contest.contest_family, contest.mode, contest.scope)
	if family != "RACE" and family != "MISS_N_OUT":
		return {"ok": false, "handled": false, "err": "backend_result_approval_not_required"}
	var normalized_id: String = normalize_contest_id(contest_id)
	var schedule: Array[Dictionary] = _cash_payout_schedule_for_closeout(contest)
	var validation: Dictionary = _validate_money_payout_schedule_for_closeout(normalized_id, contest, schedule)
	if not bool(validation.get("ok", false)):
		return validation
	var backend: Node = get_node_or_null("/root/VsHandshake")
	if backend == null or not backend.has_method("preview_async_contest_result_payout_report"):
		return {"ok": false, "handled": false, "err": "transport_not_configured"}
	var options: Dictionary = {
		"map_count": _resolve_timed_map_count(map_count) if family == "RACE" else map_count,
		"required_maps": _resolve_timed_map_count(map_count) if family == "RACE" else map_count
	}
	var result: Dictionary = backend.call(
		"preview_async_contest_result_payout_report",
		normalized_id,
		family,
		schedule,
		int(validation.get("house_rake_bps", 1000)),
		options
	) as Dictionary
	if bool(result.get("ok", false)):
		result["closeout_source"] = "backend_result_ledger"
		return result
	return result

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
			"run_id": str(entry.get("run_id", "")).strip_edges(),
			"stage_index": _entry_stage_index(entry),
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
		if a_id != b_id:
			return a_id < b_id
		var a_stage: int = int(a.get("stage_index", -1))
		var b_stage: int = int(b.get("stage_index", -1))
		if a_stage != b_stage:
			return a_stage < b_stage
		return str(a.get("run_id", "")) < str(b.get("run_id", ""))
	)
	rows = _best_stage_race_rows_by_player(rows)
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

func record_miss_n_out_result(contest_id: String, result: Dictionary) -> Dictionary:
	var normalized_id: String = normalize_contest_id(contest_id)
	if normalized_id.is_empty():
		return {"ok": false, "reason": "contest_id_empty"}
	var incoming_rows: Array[Dictionary] = _miss_n_out_result_rows(result)
	if incoming_rows.is_empty():
		return {"ok": false, "reason": "missing_miss_n_out_result_rows", "contest_id": normalized_id}
	var contest_rows: Dictionary = {}
	if typeof(runtime_leaderboards.get(normalized_id, {})) == TYPE_DICTIONARY:
		contest_rows = (runtime_leaderboards.get(normalized_id, {}) as Dictionary).duplicate(true)
	var rows_by_player: Dictionary = {}
	if typeof(contest_rows.get(MISS_N_OUT_LEADERBOARD_KEY, [])) == TYPE_ARRAY:
		for existing_any in contest_rows.get(MISS_N_OUT_LEADERBOARD_KEY, []) as Array:
			if typeof(existing_any) != TYPE_DICTIONARY:
				continue
			var existing: Dictionary = (existing_any as Dictionary).duplicate(true)
			var existing_player: String = str(existing.get("player_id", "")).strip_edges()
			if existing_player.is_empty():
				continue
			rows_by_player[existing_player] = existing
	for incoming in incoming_rows:
		var incoming_player: String = str(incoming.get("player_id", "")).strip_edges()
		if incoming_player.is_empty():
			continue
		rows_by_player[incoming_player] = incoming.duplicate(true)
	var rows: Array[Dictionary] = []
	for row_any in rows_by_player.values():
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		rows.append((row_any as Dictionary).duplicate(true))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _miss_n_out_row_precedes(a, b)
	)
	for i in range(rows.size()):
		rows[i]["rank"] = i + 1
	contest_rows[MISS_N_OUT_LEADERBOARD_KEY] = rows
	runtime_leaderboards[normalized_id] = contest_rows
	_save_runtime_leaderboards()
	return {
		"ok": true,
		"contest_id": normalized_id,
		"player_count": rows.size(),
		"winner_id": str(rows[0].get("player_id", "")),
		"updated": true
	}

func build_miss_n_out_leaderboard(contest_id: String, limit: int = 10) -> Array[Dictionary]:
	var normalized_id: String = normalize_contest_id(contest_id)
	if typeof(runtime_leaderboards.get(normalized_id, {})) != TYPE_DICTIONARY:
		return []
	var contest_rows: Dictionary = runtime_leaderboards.get(normalized_id, {}) as Dictionary
	if typeof(contest_rows.get(MISS_N_OUT_LEADERBOARD_KEY, [])) != TYPE_ARRAY:
		return []
	var rows: Array[Dictionary] = []
	for row_any in contest_rows.get(MISS_N_OUT_LEADERBOARD_KEY, []) as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		rows.append((row_any as Dictionary).duplicate(true))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _miss_n_out_row_precedes(a, b)
	)
	for i in range(rows.size()):
		rows[i]["rank"] = i + 1
	if limit > 0 and rows.size() > limit:
		return rows.slice(0, limit)
	return rows

func build_miss_n_out_money_closeout_request(contest_id: String) -> Dictionary:
	var contest: ContestDef = get_contest(contest_id)
	if contest == null:
		return {"ok": false, "reason": "contest_not_found", "contest_id": contest_id}
	var normalized_id: String = normalize_contest_id(contest_id)
	if maxi(0, int(contest.price)) <= 0:
		return {"ok": false, "reason": "contest_not_money", "contest_id": normalized_id}
	var schedule: Array[Dictionary] = _cash_payout_schedule_for_closeout(contest)
	var validation: Dictionary = _validate_money_payout_schedule_for_closeout(normalized_id, contest, schedule)
	if not bool(validation.get("ok", false)):
		return validation
	var max_placement: int = int(validation.get("max_placement", 1))
	var rows: Array[Dictionary] = build_miss_n_out_leaderboard(normalized_id, max_placement)
	if rows.size() < max_placement:
		return {
			"ok": false,
			"reason": "insufficient_qualified_players",
			"contest_id": normalized_id,
			"qualified_count": rows.size(),
			"required_placement": max_placement
		}
	var backend_payouts: Array[Dictionary] = _build_payouts_from_ranked_rows(normalized_id, rows, schedule)
	if backend_payouts.is_empty():
		return {"ok": false, "reason": "missing_qualified_payouts", "contest_id": normalized_id}
	return {
		"ok": true,
		"type": "miss_n_out_money_closeout_request",
		"contest_id": normalized_id,
		"contest_family": "MISS_N_OUT",
		"house_rake_bps": int(validation.get("house_rake_bps", 1000)),
		"payouts": backend_payouts,
		"leaderboard_rows": rows
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

func _int_array(value: Variant, limit: int = 0) -> Array[int]:
	var out: Array[int] = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for item in value as Array:
		out.append(maxi(0, int(item)))
		if limit > 0 and out.size() >= limit:
			break
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
	if entry.has("time_ms"):
		return maxi(0, int(entry.get("time_ms", 0)))
	return maxi(0, int(entry.get("best_score", 0)))

func _result_time_ms(result: Dictionary) -> int:
	if result.has("best_time_ms"):
		return maxi(0, int(result.get("best_time_ms", 0)))
	if result.has("time_ms"):
		return maxi(0, int(result.get("time_ms", 0)))
	return maxi(0, int(result.get("best_score", 0)))

func _result_stage_index(result: Dictionary) -> int:
	if result.has("stage_index"):
		return maxi(-1, int(result.get("stage_index", -1)))
	if result.has("map_index"):
		return maxi(-1, int(result.get("map_index", -1)))
	return -1

func _entry_stage_index(entry: Dictionary) -> int:
	if entry.has("stage_index"):
		return maxi(-1, int(entry.get("stage_index", -1)))
	if entry.has("map_index"):
		return maxi(-1, int(entry.get("map_index", -1)))
	return -1

func _stage_slot_key(map_id: String, stage_index: int, entry_stage_index: int) -> String:
	if entry_stage_index >= 0:
		return "%d:%s" % [stage_index, map_id]
	return map_id

func _runtime_leaderboard_entries(contest_id: String, map_id: String) -> Array:
	var normalized_id: String = normalize_contest_id(contest_id)
	if typeof(runtime_leaderboards.get(normalized_id, {})) != TYPE_DICTIONARY:
		return []
	var contest_rows: Dictionary = runtime_leaderboards.get(normalized_id, {}) as Dictionary
	if typeof(contest_rows.get(map_id, [])) != TYPE_ARRAY:
		return []
	return (contest_rows.get(map_id, []) as Array).duplicate(true)

func _stage_race_overall_row_key(player_id: String, run_id: String) -> String:
	var clean_run_id: String = run_id.strip_edges()
	if not clean_run_id.is_empty():
		return "run:%s:%s" % [player_id, clean_run_id]
	return "player:%s" % player_id

func _best_stage_race_rows_by_player(sorted_rows: Array[Dictionary]) -> Array[Dictionary]:
	var seen_players: Dictionary = {}
	var out: Array[Dictionary] = []
	for row in sorted_rows:
		var player_id: String = str(row.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			out.append(row)
			continue
		if seen_players.has(player_id):
			continue
		seen_players[player_id] = true
		out.append(row)
	return out

func _validate_money_payout_schedule_for_closeout(contest_id: String, contest: ContestDef, schedule: Array[Dictionary]) -> Dictionary:
	var normalized_id: String = normalize_contest_id(contest_id)
	if schedule.is_empty():
		return {"ok": false, "reason": "missing_cash_payout_schedule", "contest_id": normalized_id}
	var house_rake_bps: int = contest.get_house_rake_bps() if contest != null and contest.has_method("get_house_rake_bps") else 1000
	var payout_total_bps: int = 0
	var max_placement: int = 1
	for payout in schedule:
		var placement: int = maxi(1, int(payout.get("placement", 0)))
		var payout_bps: int = clampi(int(payout.get("payout_bps", 0)), 0, 10000)
		max_placement = maxi(max_placement, placement)
		payout_total_bps += payout_bps
	if payout_total_bps != 10000:
		return {
			"ok": false,
			"reason": "payout_schedule_not_balanced",
			"contest_id": normalized_id,
			"payout_total_bps": payout_total_bps,
			"house_rake_bps": house_rake_bps,
			"payout_basis": "post_rake_pool"
		}
	return {
		"ok": true,
		"contest_id": normalized_id,
		"house_rake_bps": house_rake_bps,
		"payout_total_bps": payout_total_bps,
		"max_placement": max_placement
	}

func _build_payouts_from_ranked_rows(contest_id: String, rows: Array[Dictionary], schedule: Array[Dictionary]) -> Array[Dictionary]:
	var normalized_id: String = normalize_contest_id(contest_id)
	var out: Array[Dictionary] = []
	for payout in schedule:
		var placement: int = maxi(1, int(payout.get("placement", 0)))
		if placement > rows.size():
			continue
		var row: Dictionary = rows[placement - 1]
		var player_id: String = str(row.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			push_warning("ContestState: payout row missing player_id for %s placement %d" % [normalized_id, placement])
			continue
		out.append({
			"placement": placement,
			"player_id": player_id,
			"payout_bps": clampi(int(payout.get("payout_bps", 0)), 0, 10000)
		})
	return out

func _cash_payout_schedule_for_closeout(contest: ContestDef) -> Array[Dictionary]:
	if contest == null:
		return []
	var schedule: Array[Dictionary] = contest.get_cash_payout_schedule() if contest.has_method("get_cash_payout_schedule") else []
	if not schedule.is_empty():
		return schedule
	var is_money: bool = contest.is_money_contest() if contest.has_method("is_money_contest") else int(contest.price) > 0
	var schedule_kind: String = ContestDef.normalize_schedule_kind(contest.schedule_kind)
	if is_money and schedule_kind == ContestDef.SCHEDULE_KIND_SIT_AND_GO:
		return [{"placement": 1, "reward_type": "cash", "amount_cents": 0, "payout_bps": 10000}]
	return []

func _timed_race_row_precedes(a: Dictionary, b: Dictionary) -> bool:
	var a_done: bool = bool(a.get("completed_all", int(a.get("completed_maps", 0)) >= int(a.get("required_maps", TIMED_RACE_DEFAULT_MAP_COUNT))))
	var b_done: bool = bool(b.get("completed_all", int(b.get("completed_maps", 0)) >= int(b.get("required_maps", TIMED_RACE_DEFAULT_MAP_COUNT))))
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
	var a_failed: int = int(a.get("failed_map_elapsed_ms", 0))
	var b_failed: int = int(b.get("failed_map_elapsed_ms", 0))
	if a_failed != b_failed:
		return a_failed > b_failed
	var a_player: String = str(a.get("player_id", ""))
	var b_player: String = str(b.get("player_id", ""))
	if a_player != b_player:
		return a_player < b_player
	return str(a.get("run_id", "")) < str(b.get("run_id", ""))

func _best_timed_race_rows_by_player(sorted_rows: Array[Dictionary]) -> Array[Dictionary]:
	var seen_players: Dictionary = {}
	var out: Array[Dictionary] = []
	for row in sorted_rows:
		var player_id: String = str(row.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			out.append(row)
			continue
		if seen_players.has(player_id):
			continue
		seen_players[player_id] = true
		out.append(row)
	return out

func _miss_n_out_result_rows(result: Dictionary) -> Array[Dictionary]:
	if typeof(result.get("leaderboard", [])) == TYPE_ARRAY and not (result.get("leaderboard", []) as Array).is_empty():
		return _miss_n_out_rows_from_leaderboard(result.get("leaderboard", []) as Array, result)
	var winner_any: Variant = result.get("winner", {})
	if typeof(winner_any) != TYPE_DICTIONARY:
		return []
	var winner: Dictionary = winner_any as Dictionary
	var winner_id: String = str(winner.get("player_id", "")).strip_edges()
	if winner_id.is_empty():
		return []
	var eliminated_order: Array = result.get("eliminated_order", []) as Array
	var total_players: int = maxi(1, int(result.get("player_count", result.get("participants_total", eliminated_order.size() + 1))))
	total_players = maxi(total_players, eliminated_order.size() + 1)
	var now_ts: int = int(Time.get_unix_time_from_system())
	var source: String = str(result.get("source", "miss_n_out_runtime")).strip_edges()
	var rows: Array[Dictionary] = [{
		"player_id": winner_id,
		"player_name": str(winner.get("player_name", winner_id)),
		"placement": 1,
		"is_winner": true,
		"eliminated": false,
		"eliminated_round": 0,
		"survived_rounds": int(winner.get("survived_rounds", result.get("map_count", 0))),
		"time_ms": int(winner.get("time_ms", 0)),
		"updated_at": int(result.get("updated_at", now_ts)),
		"source": source
	}]
	for i in range(eliminated_order.size()):
		var row_any: Variant = eliminated_order[i]
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var eliminated: Dictionary = row_any as Dictionary
		var player_id: String = str(eliminated.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			continue
		rows.append({
			"player_id": player_id,
			"player_name": str(eliminated.get("player_name", player_id)),
			"placement": maxi(2, total_players - i),
			"is_winner": false,
			"eliminated": true,
			"eliminated_round": int(eliminated.get("round_index", eliminated.get("map_index", 0))),
			"time_ms": int(eliminated.get("time_ms", 0)),
			"dnf": bool(eliminated.get("dnf", false)),
			"reason": str(eliminated.get("reason", "")),
			"updated_at": int(result.get("updated_at", now_ts)),
			"source": source
		})
	return rows

func _miss_n_out_rows_from_leaderboard(leaderboard: Array, result: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var now_ts: int = int(Time.get_unix_time_from_system())
	var source: String = str(result.get("source", "miss_n_out_runtime")).strip_edges()
	for i in range(leaderboard.size()):
		var row_any: Variant = leaderboard[i]
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		var player_id: String = str(row.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			continue
		var placement: int = maxi(1, int(row.get("placement", row.get("rank", i + 1))))
		rows.append({
			"player_id": player_id,
			"player_name": str(row.get("player_name", row.get("name", player_id))),
			"placement": placement,
			"is_winner": bool(row.get("is_winner", placement == 1)),
			"eliminated": bool(row.get("eliminated", placement > 1)),
			"eliminated_round": int(row.get("eliminated_round", row.get("round_index", 0))),
			"time_ms": int(row.get("time_ms", 0)),
			"dnf": bool(row.get("dnf", false)),
			"reason": str(row.get("reason", "")),
			"updated_at": int(row.get("updated_at", result.get("updated_at", now_ts))),
			"source": str(row.get("source", source)).strip_edges()
		})
	return rows

func _miss_n_out_row_precedes(a: Dictionary, b: Dictionary) -> bool:
	var a_placement: int = maxi(1, int(a.get("placement", a.get("rank", 999999))))
	var b_placement: int = maxi(1, int(b.get("placement", b.get("rank", 999999))))
	if a_placement != b_placement:
		return a_placement < b_placement
	var a_round: int = int(a.get("eliminated_round", 0))
	var b_round: int = int(b.get("eliminated_round", 0))
	if a_round != b_round:
		return a_round > b_round
	var a_time: int = int(a.get("time_ms", 0))
	var b_time: int = int(b.get("time_ms", 0))
	if a_time != b_time:
		if a_time <= 0:
			return false
		if b_time <= 0:
			return true
		return a_time < b_time
	var a_player: String = str(a.get("player_id", ""))
	var b_player: String = str(b.get("player_id", ""))
	return a_player < b_player

func _gauntlet_row_precedes(a: Dictionary, b: Dictionary) -> bool:
	var a_stars: int = int(a.get("total_stars", 0))
	var b_stars: int = int(b.get("total_stars", 0))
	if a_stars != b_stars:
		return a_stars > b_stars
	var a_completed: int = int(a.get("completed_stages", 0))
	var b_completed: int = int(b.get("completed_stages", 0))
	if a_completed != b_completed:
		return a_completed > b_completed
	var a_elapsed: int = int(a.get("elapsed_ms", 0))
	var b_elapsed: int = int(b.get("elapsed_ms", 0))
	if a_elapsed != b_elapsed:
		if a_elapsed <= 0:
			return false
		if b_elapsed <= 0:
			return true
		return a_elapsed < b_elapsed
	var a_player: String = str(a.get("player_id", ""))
	var b_player: String = str(b.get("player_id", ""))
	if a_player != b_player:
		return a_player < b_player
	return str(a.get("run_id", "")) < str(b.get("run_id", ""))

func _leaderboard_entry_key(entry: Dictionary) -> String:
	var player_id: String = str(entry.get("player_id", "")).strip_edges()
	if player_id.is_empty():
		return ""
	var run_id: String = str(entry.get("run_id", "")).strip_edges()
	if not run_id.is_empty():
		return "run:%s:%s:%d" % [player_id, run_id, _entry_stage_index(entry)]
	var stage_index: int = _entry_stage_index(entry)
	if stage_index >= 0:
		return "stage:%s:%d" % [player_id, stage_index]
	return "player:%s" % player_id

func _merge_leaderboard_entries(seed_entries: Array, runtime_entries: Array) -> Array:
	var by_entry: Dictionary = {}
	var ordered_fallback: Array = []
	for source_entries in [seed_entries, runtime_entries]:
		for entry_any in source_entries:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = (entry_any as Dictionary).duplicate(true)
			var player_id: String = str(entry.get("player_id", "")).strip_edges()
			if player_id.is_empty():
				ordered_fallback.append(entry)
				continue
			var entry_key: String = _leaderboard_entry_key(entry)
			if entry_key.is_empty():
				ordered_fallback.append(entry)
				continue
			if not by_entry.has(entry_key):
				by_entry[entry_key] = entry
				continue
			var existing: Dictionary = by_entry[entry_key] as Dictionary
			var existing_time: int = _entry_time_ms(existing)
			var entry_time: int = _entry_time_ms(entry)
			if existing_time <= 0 or (entry_time > 0 and entry_time < existing_time):
				var merged: Dictionary = existing.duplicate(true)
				for key in entry.keys():
					merged[key] = entry[key]
				merged["runs_count"] = int(existing.get("runs_count", 0)) + int(entry.get("runs_count", 0))
				by_entry[entry_key] = merged
			else:
				existing["runs_count"] = int(existing.get("runs_count", 0)) + int(entry.get("runs_count", 0))
				if str(existing.get("player_name", "")).strip_edges().is_empty():
					existing["player_name"] = str(entry.get("player_name", player_id))
				if str(existing.get("hive_name", "")).strip_edges().is_empty():
					existing["hive_name"] = str(entry.get("hive_name", ""))
				by_entry[entry_key] = existing
	var merged_entries: Array = []
	for entry_any in by_entry.values():
		merged_entries.append(entry_any)
	for entry_any in ordered_fallback:
		merged_entries.append(entry_any)
	merged_entries.sort_custom(func(a: Variant, b: Variant) -> bool:
		if typeof(a) != TYPE_DICTIONARY:
			return false
		if typeof(b) != TYPE_DICTIONARY:
			return true
		var a_entry: Dictionary = a as Dictionary
		var b_entry: Dictionary = b as Dictionary
		var a_time: int = _entry_time_ms(a_entry)
		var b_time: int = _entry_time_ms(b_entry)
		if a_time != b_time:
			return a_time < b_time
		var a_player: String = str(a_entry.get("player_id", ""))
		var b_player: String = str(b_entry.get("player_id", ""))
		if a_player != b_player:
			return a_player < b_player
		return str(a_entry.get("run_id", "")) < str(b_entry.get("run_id", ""))
	)
	return merged_entries

func _load_runtime_leaderboards() -> void:
	runtime_leaderboards.clear()
	if not FileAccess.file_exists(_runtime_leaderboard_save_path):
		return
	var f: FileAccess = FileAccess.open(_runtime_leaderboard_save_path, FileAccess.READ)
	if f == null:
		return
	var json: JSON = JSON.new()
	var err: int = json.parse(f.get_as_text())
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var data: Dictionary = json.data as Dictionary
	if str(data.get("schema", "")) == RUNTIME_LEADERBOARD_SCHEMA and typeof(data.get("leaderboards", {})) == TYPE_DICTIONARY:
		runtime_leaderboards = data.get("leaderboards", {}) as Dictionary
		return
	runtime_leaderboards = data

func _save_runtime_leaderboards() -> void:
	var f: FileAccess = FileAccess.open(_runtime_leaderboard_save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"schema": RUNTIME_LEADERBOARD_SCHEMA,
		"leaderboards": runtime_leaderboards
	}))

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
