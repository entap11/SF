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
