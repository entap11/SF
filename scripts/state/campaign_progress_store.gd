extends RefCounted

# One local transaction owns attempts, unlocks, stingers and challenge records.
# These records are device-local, never public verified result authority.
const Catalog = preload("res://scripts/state/campaign_catalog.gd")
var save_path: String = "user://campaign_progress_v1.json"
var _data: Dictionary = {}
var _loaded := false
var _load_error := false

func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(save_path):
		_data = {"schema": 1, "players": {}}
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) != OK:
		_load_error = true
		return
	var parsed: Variant = parser.data
	if not parsed is Dictionary or int(parsed.get("schema", 0)) != 1 or not parsed.get("players") is Dictionary:
		_load_error = true
		return
	for player in (parsed.players as Dictionary).values():
		if not player is Dictionary or not player.get("unlocked") is Array or not player.get("levels") is Dictionary or not player.get("runs") is Dictionary:
			_load_error = true
			return
		for stats in (player.levels as Dictionary).values():
			if not stats is Dictionary:
				_load_error = true
				return
		for result in (player.runs as Dictionary).values():
			if not result is Dictionary:
				_load_error = true
				return
	_data = parsed

func _player(uid: String) -> Dictionary:
	_load()
	return (_data.get("players", {}) as Dictionary).get(uid, {"bookmark": "", "unlocked": [], "levels": {}, "runs": {}}).duplicate(true)

func snapshot(uid: String, level: Dictionary) -> Dictionary:
	return (_player(uid).get("levels", {}) as Dictionary).get(str(level.record_key), {}).duplicate(true)

func is_unlocked(uid: String, id: String) -> bool:
	var all: Array[Dictionary] = Catalog.levels()
	if all.is_empty() or Catalog.find(id).is_empty():
		return false
	return id == str(all[0].id) or (_player(uid).get("unlocked", []) as Array).has(id)

func continue_id(uid: String) -> String:
	var all: Array[Dictionary] = Catalog.levels()
	if all.is_empty():
		return ""
	var id: String = str(_player(uid).get("bookmark", ""))
	return id if is_unlocked(uid, id) else str(all[0].id)

func bookmark(uid: String, id: String) -> bool:
	return prepare_attempt(uid, id, true)

func prepare_attempt(uid: String, id: String, remember: bool) -> bool:
	if uid.is_empty() or not is_unlocked(uid, id):
		return false
	var player: Dictionary = _player(uid)
	if remember:
		player.bookmark = id
	return _commit(uid, player)

func record_attempt(uid: String, handle: String, level: Dictionary, run_id: String, won: bool, elapsed_ms: int, entry: String) -> Dictionary:
	if uid.is_empty() or run_id.is_empty() or elapsed_ms <= 0 or level.is_empty() or not is_unlocked(uid, str(level.id)):
		return {"ok": false, "error": "invalid_attempt"}
	var player: Dictionary = _player(uid)
	if (player.runs as Dictionary).has(run_id):
		return (player.runs[run_id] as Dictionary).duplicate(true)
	var stats: Dictionary = (player.levels as Dictionary).get(str(level.record_key), {"attempts": 0, "wins": 0, "best_ms": 0, "stingers": 0})
	stats.attempts = int(stats.attempts) + 1
	var earned: int = Catalog.stingers(level, won, elapsed_ms)
	if won:
		stats.wins = int(stats.wins) + 1
		stats.best_ms = elapsed_ms if int(stats.best_ms) <= 0 else mini(elapsed_ms, int(stats.best_ms))
		stats.stingers = maxi(int(stats.stingers), earned)
	player.levels[str(level.record_key)] = stats
	player["handle"] = handle
	var next: String = Catalog.next_id(str(level.id))
	if not next.is_empty() and not (player.unlocked as Array).has(next):
		player.unlocked.append(next)
	if entry == "campaign":
		player.bookmark = next if not next.is_empty() else str(level.id)
	var result: Dictionary = {"ok": true, "won": won, "elapsed_ms": elapsed_ms, "stingers": earned, "best_ms": int(stats.best_ms), "next_id": next}
	player.runs[run_id] = result
	if not _commit(uid, player):
		return {"ok": false, "error": "save_failed"}
	return result.duplicate(true)

func board(level: Dictionary) -> Array[Dictionary]:
	_load()
	var rows: Array[Dictionary] = []
	for uid in (_data.get("players", {}) as Dictionary):
		var player: Dictionary = _data.players[uid]
		var stats: Dictionary = (player.get("levels", {}) as Dictionary).get(str(level.record_key), {})
		if int(stats.get("best_ms", 0)) > 0:
			rows.append({"player_id": str(uid), "handle": str(player.get("handle", "Player")), "best_ms": int(stats.best_ms)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.best_ms) < int(b.best_ms) if int(a.best_ms) != int(b.best_ms) else str(a.player_id) < str(b.player_id)
	)
	return rows

func _commit(uid: String, player: Dictionary) -> bool:
	_load()
	if _load_error:
		return false # Preserve unreadable historical data rather than overwrite it.
	var updated: Dictionary = _data.duplicate(true)
	updated.players[uid] = player
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(updated))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path + ".tmp"), ProjectSettings.globalize_path(save_path)) != OK:
		return false
	_data = updated
	return true
