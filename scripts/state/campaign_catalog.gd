extends RefCounted

const PATH := "res://data/campaign/starter_v1.json"
const BOTS := ["turtle", "balancer", "raider", "greedy", "swarm_lord"]
const TIERS := ["easy", "medium", "hard"]
static var _levels: Array[Dictionary] = []

static func levels() -> Array[Dictionary]:
	if _levels.is_empty():
		var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if not document is Dictionary:
			return []
		var policy: String = str(document.get("rules_fingerprint", ""))
		if policy.is_empty():
			return []
		var loaded: Array[Dictionary] = []
		var seen: Dictionary = {}
		for item in document.get("levels", []):
			if not item is Dictionary:
				return []
			var row: Dictionary = item.duplicate(true)
			var id: String = str(row.get("id", ""))
			if id.is_empty() or seen.has(id) or not BOTS.has(row.get("bot")) or not TIERS.has(row.get("difficulty")):
				return []
			if not FileAccess.file_exists(str(row.get("map_path", ""))):
				return []
			if str(row.get("map_fingerprint", "")).length() != 64 or int(row.get("three_stinger_ms", 0)) <= 0 or int(row.get("two_stinger_ms", 0)) <= int(row.get("three_stinger_ms", 0)):
				return []
			seen[id] = true
			row["number"] = loaded.size() + 1
			# Checked-in fingerprints survive script compilation/export on both phones.
			var comparison := "%s|%s|%s|%s|%d|%d|%d" % [policy, str(row.get("map_fingerprint", "")), str(row.bot), str(row.difficulty), int(row.seed), int(row.two_stinger_ms), int(row.three_stinger_ms)]
			row["record_key"] = id + ":" + comparison.sha256_text()
			loaded.append(row)
		_levels = loaded
	return _levels.duplicate(true)

static func find(id: String) -> Dictionary:
	for level in levels():
		if str(level.id) == id:
			return level
	return {}

static func next_id(id: String) -> String:
	var all: Array[Dictionary] = levels()
	for i in range(all.size() - 1):
		if str(all[i].id) == id:
			return str(all[i + 1].id)
	return ""

static func resolve(map_path: String, bot: String, tier: String) -> Dictionary:
	for level in levels():
		if str(level.map_path) == map_path and str(level.bot) == bot and str(level.difficulty) == tier:
			return level
	return {}

static func stingers(level: Dictionary, won: bool, elapsed_ms: int) -> int:
	if not won or elapsed_ms <= 0:
		return 0
	if elapsed_ms <= int(level.three_stinger_ms):
		return 3
	if elapsed_ms <= int(level.two_stinger_ms):
		return 2
	return 1

static func time_text(ms: int) -> String:
	if ms <= 0:
		return "—"
	return "%d:%05.2f" % [ms / 60000, float(ms % 60000) / 1000.0]
