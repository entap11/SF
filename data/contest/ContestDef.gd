class_name ContestDef
extends Resource

const POOL_TYPE_FREE: String = "FREE"
const POOL_TYPE_MONEY: String = "MONEY"
const SCHEDULE_KIND_SCHEDULED: String = "SCHEDULED"
const SCHEDULE_KIND_SIT_AND_GO: String = "SIT_AND_GO"
const FAMILY_WEEKLY: String = "WEEKLY"
const FAMILY_MONTHLY: String = "MONTHLY"
const FAMILY_SEASONAL: String = "SEASONAL"
const FAMILY_GAUNTLET: String = "GAUNTLET"
const FAMILY_STAGE_RACE: String = "STAGE_RACE"
const FAMILY_MISS_N_OUT: String = "MISS_N_OUT"
const FAMILY_RACE: String = "RACE"
const DEFAULT_HOUSE_RAKE_BPS: int = 1000
const BASIS_POINTS_DENOMINATOR: int = 10000

@export var id: String = ""
@export var scope: String = "WEEKLY"
@export var currency: String = "USD"
@export var price: int = 0
@export var time_slice: String = ""
@export var mode: String = "TIME_PUZZLE"
@export var pool_type: String = POOL_TYPE_FREE
@export var contest_family: String = FAMILY_STAGE_RACE
@export var schedule_kind: String = SCHEDULE_KIND_SCHEDULED
@export var status: String = "OPEN"
@export var prize_pool_cents: int = 0
@export var house_rake_bps: int = 1000
@export var access_ticket_cost: int = 0
@export var prize_rewards: Array[Dictionary] = []
@export var min_players: int = 0
@export var max_players: int = 0

@export var name: String = ""
@export var start_ts: int = 0
@export var end_ts: int = 0
@export var published: bool = false
@export var map_ids: PackedStringArray = []
@export var buff_cap_per_map: int = 0
@export var bonus_rules: Dictionary = {}

func normalize_definition() -> void:
	pool_type = normalize_pool_type(pool_type, currency, price)
	contest_family = normalize_contest_family(contest_family, mode, scope)
	schedule_kind = normalize_schedule_kind(schedule_kind)
	if is_money_contest():
		currency = "USD"
		house_rake_bps = DEFAULT_HOUSE_RAKE_BPS
	else:
		currency = POOL_TYPE_FREE
		price = 0
		house_rake_bps = 0
	min_players = maxi(0, min_players)
	max_players = maxi(min_players, max_players)

func is_money_contest() -> bool:
	return normalize_pool_type(pool_type, currency, price) == POOL_TYPE_MONEY

func is_free_contest() -> bool:
	return not is_money_contest()

func is_scheduled_contest() -> bool:
	return normalize_schedule_kind(schedule_kind) == SCHEDULE_KIND_SCHEDULED

func is_sit_and_go_contest() -> bool:
	return normalize_schedule_kind(schedule_kind) == SCHEDULE_KIND_SIT_AND_GO

func requires_payout_approval() -> bool:
	return is_money_contest() and is_scheduled_contest()

func payout_percentages_are_post_rake_pool() -> bool:
	return true

static func normalize_pool_type(value: String, fallback_currency: String = "", fallback_price: int = 0) -> String:
	var clean: String = value.strip_edges().to_upper()
	if fallback_price > 0:
		return POOL_TYPE_MONEY
	if clean == POOL_TYPE_MONEY or clean == "PAID" or clean == "WAGER":
		return POOL_TYPE_MONEY
	if clean == POOL_TYPE_FREE:
		return POOL_TYPE_FREE
	if fallback_currency.strip_edges().to_upper() == "USD":
		return POOL_TYPE_MONEY
	return POOL_TYPE_FREE

static func normalize_schedule_kind(value: String) -> String:
	var clean: String = value.strip_edges().to_upper().replace("-", "_").replace(" ", "_")
	if clean == "SIT_N_GO" or clean == "SIT_AND_GO" or clean == "LOBBY":
		return SCHEDULE_KIND_SIT_AND_GO
	return SCHEDULE_KIND_SCHEDULED

static func normalize_contest_family(value: String, fallback_mode: String = "", fallback_scope: String = "") -> String:
	var clean: String = value.strip_edges().to_upper().replace("-", "_").replace(" ", "_")
	if clean == "MISS_N_OUT" or clean == "MISS_AND_OUT" or clean == "MISS_NOUT":
		return FAMILY_MISS_N_OUT
	if clean == FAMILY_GAUNTLET or clean == FAMILY_STAGE_RACE or clean == FAMILY_RACE:
		return clean
	if clean == FAMILY_WEEKLY or clean == FAMILY_MONTHLY or clean == FAMILY_SEASONAL:
		return clean
	var mode_clean: String = fallback_mode.strip_edges().to_upper().replace("-", "_").replace(" ", "_")
	if mode_clean == "MISS_N_OUT" or mode_clean == "MISS_AND_OUT":
		return FAMILY_MISS_N_OUT
	if mode_clean == FAMILY_GAUNTLET or mode_clean == FAMILY_STAGE_RACE or mode_clean == FAMILY_RACE:
		return mode_clean
	var scope_clean: String = fallback_scope.strip_edges().to_upper()
	if scope_clean == FAMILY_WEEKLY or scope_clean == FAMILY_MONTHLY or scope_clean == "YEARLY":
		return FAMILY_SEASONAL if scope_clean == "YEARLY" else scope_clean
	return FAMILY_STAGE_RACE

func requires_access_ticket() -> bool:
	return access_ticket_cost > 0

func get_access_ticket_cost() -> int:
	return maxi(0, access_ticket_cost)

func get_prize_rewards_for_placement(placement: int) -> Array[Dictionary]:
	var safe_placement: int = maxi(1, placement)
	var filtered: Array[Dictionary] = []
	for reward_any in prize_rewards:
		if typeof(reward_any) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = (reward_any as Dictionary).duplicate(true)
		if reward.has("placement"):
			if maxi(1, int(reward.get("placement", 0))) != safe_placement:
				continue
		elif reward.has("placements"):
			var placements_any: Variant = reward.get("placements", [])
			if typeof(placements_any) != TYPE_ARRAY:
				continue
			var matched: bool = false
			for placement_any in placements_any as Array:
				if int(placement_any) == safe_placement:
					matched = true
					break
			if not matched:
				continue
		filtered.append(reward)
	return filtered

func get_house_rake_bps() -> int:
	if not is_money_contest():
		return 0
	return DEFAULT_HOUSE_RAKE_BPS

func get_cash_payout_schedule() -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	for reward_any in prize_rewards:
		if typeof(reward_any) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = reward_any as Dictionary
		var reward_type: String = str(reward.get("reward_type", "cash")).strip_edges().to_lower()
		if reward_type != "cash":
			continue
		var placement: int = maxi(1, int(reward.get("placement", schedule.size() + 1)))
		var amount_cents: int = maxi(0, int(reward.get("amount_cents", reward.get("amount", 0))))
		var payout_bps: int = clampi(int(reward.get("payout_bps", 0)), 0, 10000)
		schedule.append({
			"placement": placement,
			"reward_type": "cash",
			"amount_cents": amount_cents,
			"payout_bps": payout_bps
		})
	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("placement", 0)) < int(b.get("placement", 0))
	)
	return schedule

func set_cash_payout_schedule(schedule: Array[Dictionary]) -> void:
	var normalized: Array[Dictionary] = []
	for row_any in schedule:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		var placement: int = maxi(1, int(row.get("placement", normalized.size() + 1)))
		var amount_cents: int = maxi(0, int(row.get("amount_cents", row.get("amount", 0))))
		var payout_bps: int = clampi(int(row.get("payout_bps", 0)), 0, 10000)
		normalized.append({
			"placement": placement,
			"reward_type": "cash",
			"amount_cents": amount_cents,
			"payout_bps": payout_bps
		})
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("placement", 0)) < int(b.get("placement", 0))
	)
	prize_rewards = normalized

func get_cash_payout_total_cents() -> int:
	var total: int = 0
	for payout in get_cash_payout_schedule():
		total += maxi(0, int(payout.get("amount_cents", 0)))
	return total

func get_cash_payout_total_bps() -> int:
	var total: int = 0
	for payout in get_cash_payout_schedule():
		total += clampi(int(payout.get("payout_bps", 0)), 0, 10000)
	return total

func calculate_house_rake_cents(pot_cents: int) -> int:
	return int((maxi(0, pot_cents) * get_house_rake_bps()) / 10000)

func validate_cash_payout_schedule(entry_count: int, entry_cents: int) -> Dictionary:
	var pot_cents: int = maxi(0, entry_count) * maxi(0, entry_cents)
	var rake_cents: int = calculate_house_rake_cents(pot_cents)
	var distributable_cents: int = maxi(0, pot_cents - rake_cents)
	var schedule: Array[Dictionary] = get_cash_payout_schedule()
	var seen_placements: Dictionary = {}
	var total_cents: int = 0
	var total_bps: int = 0
	for payout in schedule:
		var placement: int = maxi(1, int(payout.get("placement", 0)))
		if seen_placements.has(placement):
			return {
				"ok": false,
				"code": "duplicate_placement",
				"placement": placement,
				"pot_cents": pot_cents,
				"house_rake_cents": rake_cents,
				"distributable_cents": distributable_cents
			}
		seen_placements[placement] = true
		var amount_cents: int = maxi(0, int(payout.get("amount_cents", 0)))
		var payout_bps: int = clampi(int(payout.get("payout_bps", 0)), 0, 10000)
		if amount_cents <= 0 and payout_bps <= 0:
			return {
				"ok": false,
				"code": "empty_payout",
				"placement": placement,
				"pot_cents": pot_cents,
				"house_rake_cents": rake_cents,
				"distributable_cents": distributable_cents
			}
		total_cents += amount_cents
		total_bps += payout_bps
	var expected_payout_bps: int = BASIS_POINTS_DENOMINATOR if is_money_contest() else 0
	var bps_valid: bool = total_bps == expected_payout_bps or (not is_money_contest() and total_bps == 0)
	return {
		"ok": total_cents <= distributable_cents and bps_valid,
		"code": "" if total_cents <= distributable_cents and bps_valid else "payouts_exceed_post_rake_pool",
		"pot_cents": pot_cents,
		"house_rake_cents": rake_cents,
		"distributable_cents": distributable_cents,
		"payout_total_cents": total_cents,
		"payout_total_bps": total_bps,
		"expected_payout_bps": expected_payout_bps,
		"payout_basis": "post_rake_pool",
		"winner_count": schedule.size(),
		"unallocated_cents": maxi(0, distributable_cents - total_cents),
		"unallocated_bps": maxi(0, expected_payout_bps - total_bps)
	}
