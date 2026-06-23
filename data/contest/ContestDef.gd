class_name ContestDef
extends Resource

@export var id: String = ""
@export var scope: String = "WEEKLY"
@export var currency: String = "USD"
@export var price: int = 0
@export var time_slice: String = ""
@export var mode: String = "TIME_PUZZLE"
@export var status: String = "OPEN"
@export var prize_pool_cents: int = 0
@export var house_rake_bps: int = 1000
@export var access_ticket_cost: int = 0
@export var prize_rewards: Array[Dictionary] = []

@export var name: String = ""
@export var start_ts: int = 0
@export var end_ts: int = 0
@export var published: bool = false
@export var map_ids: PackedStringArray = []
@export var buff_cap_per_map: int = 0
@export var bonus_rules: Dictionary = {}

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
	return clampi(house_rake_bps, 0, 10000)

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
	var available_bps: int = maxi(0, 10000 - get_house_rake_bps())
	var bps_valid: bool = total_bps <= available_bps
	return {
		"ok": total_cents <= distributable_cents and bps_valid,
		"code": "" if total_cents <= distributable_cents and bps_valid else "payouts_exceed_distributable",
		"pot_cents": pot_cents,
		"house_rake_cents": rake_cents,
		"distributable_cents": distributable_cents,
		"payout_total_cents": total_cents,
		"payout_total_bps": total_bps,
		"available_payout_bps": available_bps,
		"winner_count": schedule.size(),
		"unallocated_cents": maxi(0, distributable_cents - total_cents),
		"unallocated_bps": maxi(0, available_bps - total_bps)
	}
