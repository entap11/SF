class_name RankModels
extends RefCounted

enum WaxMode {
	STANDARD,
	TOURNAMENT,
	MONEY_MATCH,
	STEROIDS_LEAGUE
}

enum QueueFilter {
	GLOBAL,
	REGION,
	FRIENDS
}

enum TierId {
	DRONE,
	WORKER,
	SOLDIER,
	HONEY_BEE,
	BUMBLEBEE,
	QUEEN,
	YELLOWJACKET,
	RED_WASP,
	HORNET,
	BALD_FACED_HORNET,
	KILLER_BEE,
	ASIAN_GIANT_HORNET,
	EXECUTIONER_WASP,
	SCORPION_WASP,
	COW_KILLER
}

enum ColorId {
	GREEN,
	BLUE,
	RED,
	BLACK,
	YELLOW
}

const DEFAULT_TIER: String = "DRONE"
const DEFAULT_COLOR: String = "GREEN"

static func mode_name(mode_id: int) -> String:
	match mode_id:
		WaxMode.TOURNAMENT:
			return "TOURNAMENT"
		WaxMode.MONEY_MATCH:
			return "MONEY_MATCH"
		WaxMode.STEROIDS_LEAGUE:
			return "STEROIDS_LEAGUE"
		_:
			return "STANDARD"

static func filter_name(filter_id: int) -> String:
	match filter_id:
		QueueFilter.REGION:
			return "REGION"
		QueueFilter.FRIENDS:
			return "FRIENDS"
		_:
			return "GLOBAL"

static func new_player_record(
		player_id: String,
		display_name: String,
		region: String,
		wax_score: float,
		last_active_unix: int,
		friends: Array[String]
	) -> Dictionary:
	var clean_name: String = display_name.strip_edges()
	if clean_name == "":
		clean_name = player_id
	var clean_region: String = region.strip_edges().to_upper()
	if clean_region == "":
		clean_region = "GLOBAL"
	return {
		"player_id": player_id,
		"display_name": clean_name,
		"region": clean_region,
		"wax_score": maxf(0.0, wax_score),
		"last_active_unix": last_active_unix,
		"last_decay_day": -1,
		"tier_id": DEFAULT_TIER,
		"color_id": DEFAULT_COLOR,
		"rank_position": 0,
		"percentile": 0.0,
		"promotion_history": {DEFAULT_TIER: true},
		"friends": friends.duplicate(),
		"apex_active": false
	}

static func sanitize_friends(raw: Array) -> Array[String]:
	var out: Array[String] = []
	for friend_any in raw:
		var friend_id: String = str(friend_any).strip_edges()
		if friend_id == "":
			continue
		if out.has(friend_id):
			continue
		out.append(friend_id)
	return out
