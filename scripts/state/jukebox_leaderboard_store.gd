class_name JukeboxLeaderboardStore
extends RefCounted

const SAVE_PATH_DEFAULT: String = "user://jukebox_leaderboard_v1.json"
const SCHEMA_V1: String = "swarmfront.jukebox_leaderboard.v1"
const SEED_COMPETITOR_COUNT: int = 24
const DEFAULT_MODE: String = "ASYNC_SINGLE_MAP_TIMED"
const DEFAULT_PERIOD: String = "WEEKLY"
const PERIOD_ALL_TIME: String = "ALL TIME"
const PERIOD_LABELS: Array[String] = ["WEEKLY", "MONTHLY", "SEASON", "ALL TIME"]
const SEED_HANDLES: Array[String] = [
	"SwarmDaddy", "HiveLaw", "BeeLine", "LaneLord", "WaxOn", "NectarKid", "HoneyBadger",
	"RushMint", "QueenStrat", "MapGrind", "BuzzKill", "Drone47", "TopRail", "SplitPush",
	"BotCheck", "FlagRunner", "GhostLine", "ApexHive", "TempoBee", "GridSmith",
	"LanePilot", "HoneyRush", "RailGuard", "MapScout", "HiveForge", "PathSniper"
]

var save_path: String = SAVE_PATH_DEFAULT

var _loaded: bool = false
var _boards_by_key: Dictionary = {}

func reload() -> void:
	_loaded = false
	_boards_by_key.clear()
	_ensure_loaded()

func record_run_all_periods(map_id: String, mode: String, result: Dictionary) -> Dictionary:
	_ensure_loaded()
	var clean_map_id: String = _normalize_token(map_id)
	var clean_mode: String = _normalize_mode(mode)
	var recorded_at: int = _resolve_updated_at(int(result.get("updated_at", 0)))
	var updated_periods: Array[String] = []
	var best_time_ms: int = 0
	for period_label in PERIOD_LABELS:
		var write_result: Dictionary = _append_result(clean_map_id, clean_mode, str(period_label), result, recorded_at)
		if not bool(write_result.get("ok", false)):
			return write_result
		updated_periods.append(str(period_label))
		best_time_ms = maxi(best_time_ms, int(write_result.get("best_time_ms", 0)))
	return {
		"ok": true,
		"updated": true,
		"map_id": clean_map_id,
		"mode": clean_mode,
		"periods_updated": updated_periods,
		"player_id": str(result.get("player_id", "")),
		"best_time_ms": best_time_ms
	}

func get_board_snapshot(
		map_id: String,
		mode: String,
		period: String,
		requester_id: String = "",
		requester_handle: String = "",
		limit: int = 50
	) -> Dictionary:
	_ensure_loaded()
	var board: Dictionary = _ensure_board(map_id, mode, period, requester_id, requester_handle)
	var rows: Array[Dictionary] = _sorted_rows(board.get("rows", []) as Array)
	var safe_limit: int = maxi(1, limit)
	var entries: Array[Dictionary] = []
	var your_rank: int = 0
	var your_best_ms: int = 0
	var clean_requester_id: String = _normalize_token(requester_id)
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var rank: int = i + 1
		var player_id: String = str(row.get("player_id", ""))
		var time_ms: int = maxi(0, int(row.get("best_time_ms", 0)))
		if clean_requester_id != "" and player_id == clean_requester_id:
			if your_rank <= 0 or time_ms < your_best_ms:
				your_rank = rank
				your_best_ms = time_ms
		if rank > safe_limit:
			continue
		entries.append({
			"rank": rank,
			"player_id": player_id,
			"handle": str(row.get("handle", player_id)),
			"time_ms": time_ms,
			"badge": _badge_for_rank(rank),
			"updated_at": int(row.get("updated_at", 0)),
			"source": str(row.get("source", "local"))
		})
	return {
		"map_id": str(board.get("map_id", "")),
		"mode": str(board.get("mode", DEFAULT_MODE)),
		"period": str(board.get("period", DEFAULT_PERIOD)),
		"period_scope": str(board.get("period_scope", "")),
		"board_key": str(board.get("board_key", "")),
		"entries": entries,
		"your_rank": your_rank,
		"your_best_ms": your_best_ms,
		"total_entries": rows.size(),
		"updated_at": int(board.get("updated_at", 0))
	}

func get_player_map_summary(
		map_id: String,
		mode: String,
		player_id: String,
		player_handle: String = "",
		period: String = PERIOD_ALL_TIME
	) -> Dictionary:
	_ensure_loaded()
	var clean_player_id: String = _normalize_token(player_id)
	if clean_player_id.is_empty():
		return {
			"player_id": "",
			"best_time_ms": 0,
			"run_count": 0,
			"latest_time_ms": 0,
			"period": _normalize_period(period)
		}
	var board: Dictionary = _ensure_board(map_id, mode, period, clean_player_id, player_handle)
	var rows: Array = board.get("rows", []) as Array
	var best_time_ms: int = 0
	var latest_time_ms: int = 0
	var latest_updated_at: int = 0
	var run_count: int = 0
	for row_any in rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("player_id", "")) != clean_player_id:
			continue
		var time_ms: int = maxi(0, int(row.get("best_time_ms", row.get("time_ms", 0))))
		var updated_at: int = maxi(0, int(row.get("updated_at", 0)))
		if time_ms <= 0:
			continue
		run_count += 1
		if best_time_ms <= 0 or time_ms < best_time_ms:
			best_time_ms = time_ms
		if updated_at >= latest_updated_at:
			latest_updated_at = updated_at
			latest_time_ms = time_ms
	return {
		"player_id": clean_player_id,
		"handle": _sanitize_handle(player_handle, clean_player_id),
		"best_time_ms": best_time_ms,
		"run_count": run_count,
		"latest_time_ms": latest_time_ms,
		"latest_updated_at": latest_updated_at,
		"period": str(board.get("period", _normalize_period(period))),
		"period_scope": str(board.get("period_scope", "")),
		"board_key": str(board.get("board_key", ""))
	}

func upsert_result(
		map_id: String,
		mode: String,
		period: String,
		result: Dictionary
	) -> Dictionary:
	return _append_result(_normalize_token(map_id), _normalize_mode(mode), period, result, _resolve_updated_at(int(result.get("updated_at", 0))))

func debug_reset_state() -> void:
	_loaded = true
	_boards_by_key.clear()
	var resolved_path: String = _resolved_save_path()
	if FileAccess.file_exists(resolved_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resolved_path))

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_boards_by_key.clear()
	var resolved_path: String = _resolved_save_path()
	if not FileAccess.file_exists(resolved_path):
		return
	var file: FileAccess = FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_hydrate(parsed as Dictionary)

func _hydrate(root: Dictionary) -> void:
	var boards_any: Variant = root.get("boards_by_key", {})
	if typeof(boards_any) != TYPE_DICTIONARY:
		return
	var boards: Dictionary = boards_any as Dictionary
	for board_key_any in boards.keys():
		var board_any: Variant = boards.get(board_key_any)
		if typeof(board_any) != TYPE_DICTIONARY:
			continue
		var normalized: Dictionary = _normalize_board(board_any as Dictionary)
		if normalized.is_empty():
			continue
		_boards_by_key[str(normalized.get("board_key", ""))] = normalized

func _ensure_board(
		map_id: String,
		mode: String,
		period: String,
		requester_id: String = "",
		requester_handle: String = "",
		scope_id: String = ""
	) -> Dictionary:
	var clean_map_id: String = _normalize_token(map_id)
	if clean_map_id.is_empty():
		return {}
	var clean_mode: String = _normalize_mode(mode)
	var clean_period: String = _normalize_period(period)
	var resolved_scope_id: String = scope_id.strip_edges()
	if resolved_scope_id.is_empty():
		resolved_scope_id = _period_scope_id(clean_period, int(Time.get_unix_time_from_system()))
	var board_key: String = _board_key(clean_map_id, clean_mode, clean_period, resolved_scope_id)
	var board: Dictionary = {}
	var existing_any: Variant = _boards_by_key.get(board_key, null)
	if typeof(existing_any) == TYPE_DICTIONARY:
		board = _normalize_board(existing_any as Dictionary)
	if board.is_empty():
		board = {
			"board_key": board_key,
			"map_id": clean_map_id,
			"mode": clean_mode,
			"period": clean_period,
			"period_scope": resolved_scope_id,
			"created_at": int(Time.get_unix_time_from_system()),
			"updated_at": int(Time.get_unix_time_from_system()),
			"rows": []
		}
	if _seed_board(board, requester_id, requester_handle):
		_store_board(board)
		_save()
	elif not _boards_by_key.has(board_key):
		_store_board(board)
	return board

func _seed_board(board: Dictionary, requester_id: String, requester_handle: String) -> bool:
	var rows: Array = board.get("rows", []) as Array
	if not rows.is_empty():
		return false
	var map_id: String = str(board.get("map_id", ""))
	var mode: String = str(board.get("mode", DEFAULT_MODE))
	var period: String = str(board.get("period", DEFAULT_PERIOD))
	var seed_text: String = "%s|%s|%s" % [map_id, mode, period]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_text.hash())
	var now_unix: int = int(Time.get_unix_time_from_system())
	var base_ms: int = 76000 + int(abs(seed_text.hash()) % 22000)
	var user_rank_target: int = clampi(8 + int(abs((seed_text + "|you").hash()) % 16), 1, SEED_COMPETITOR_COUNT + 1)
	for i in range(SEED_COMPETITOR_COUNT):
		var rank: int = i + 1
		var player_id: String = "seed_%s_%02d" % [_slug(seed_text), rank]
		var handle_seed: String = SEED_HANDLES[i % SEED_HANDLES.size()]
		var handle: String = "%s%02d" % [handle_seed, int((i * 7 + abs(seed_text.hash())) % 97)]
		var time_ms: int = base_ms + i * 410 + int(rng.randi_range(20, 260))
		rows.append({
			"row_id": "seed_%02d" % rank,
			"player_id": player_id,
			"handle": handle,
			"best_time_ms": time_ms,
			"updated_at": now_unix - i,
			"source": "seed"
		})
	board["rows"] = rows
	board["updated_at"] = now_unix
	return true

func _sorted_rows(rows_any: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row_any in rows_any:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		rows.append(_normalize_row(row_any as Dictionary))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_time: int = int(a.get("best_time_ms", 0))
		var b_time: int = int(b.get("best_time_ms", 0))
		if a_time != b_time:
			return a_time < b_time
		var a_updated: int = int(a.get("updated_at", 0))
		var b_updated: int = int(b.get("updated_at", 0))
		if a_updated != b_updated:
			return a_updated < b_updated
		var a_id: String = str(a.get("player_id", ""))
		var b_id: String = str(b.get("player_id", ""))
		return a_id < b_id
	)
	return rows

func _normalize_board(raw: Dictionary) -> Dictionary:
	var clean_map_id: String = _normalize_token(str(raw.get("map_id", "")))
	if clean_map_id.is_empty():
		return {}
	var clean_mode: String = _normalize_mode(str(raw.get("mode", DEFAULT_MODE)))
	var clean_period: String = _normalize_period(str(raw.get("period", DEFAULT_PERIOD)))
	var period_scope: String = str(raw.get("period_scope", "")).strip_edges()
	if period_scope.is_empty():
		period_scope = _period_scope_id(clean_period, int(raw.get("updated_at", raw.get("created_at", Time.get_unix_time_from_system()))))
	var board_key: String = _board_key(clean_map_id, clean_mode, clean_period, period_scope)
	var rows_any: Variant = raw.get("rows", null)
	var rows: Array = []
	if typeof(rows_any) == TYPE_ARRAY:
		for row_any in rows_any as Array:
			if typeof(row_any) != TYPE_DICTIONARY:
				continue
			var normalized_row: Dictionary = _normalize_row(row_any as Dictionary)
			if str(normalized_row.get("player_id", "")).is_empty():
				continue
			if str(normalized_row.get("source", "")).begins_with("seed_local"):
				continue
			rows.append(normalized_row)
	elif typeof(raw.get("rows_by_player", null)) == TYPE_DICTIONARY:
		for player_id_any in (raw.get("rows_by_player", {}) as Dictionary).keys():
			var row_any: Variant = (raw.get("rows_by_player", {}) as Dictionary).get(player_id_any)
			if typeof(row_any) != TYPE_DICTIONARY:
				continue
			var normalized_row: Dictionary = _normalize_row(row_any as Dictionary)
			if str(normalized_row.get("player_id", "")).is_empty():
				continue
			if str(normalized_row.get("source", "")).begins_with("seed_local"):
				continue
			rows.append(normalized_row)
	return {
		"board_key": board_key,
		"map_id": clean_map_id,
		"mode": clean_mode,
		"period": clean_period,
		"period_scope": period_scope,
		"created_at": maxi(0, int(raw.get("created_at", 0))),
		"updated_at": maxi(0, int(raw.get("updated_at", 0))),
		"rows": rows
	}

func _normalize_row(raw: Dictionary) -> Dictionary:
	var clean_player_id: String = _normalize_token(str(raw.get("player_id", raw.get("id", ""))))
	return {
		"row_id": str(raw.get("row_id", "")),
		"player_id": clean_player_id,
		"handle": _sanitize_handle(str(raw.get("handle", raw.get("player_name", clean_player_id))), clean_player_id),
		"best_time_ms": maxi(0, int(raw.get("best_time_ms", raw.get("time_ms", 0)))),
		"updated_at": _resolve_updated_at(int(raw.get("updated_at", 0))),
		"source": str(raw.get("source", "local"))
	}

func _player_best_time_ms(rows: Array, player_id: String) -> int:
	var clean_player_id: String = _normalize_token(player_id)
	if clean_player_id.is_empty():
		return 0
	var best: int = 0
	for row_any in rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("player_id", "")) != clean_player_id:
			continue
		var value: int = maxi(0, int(row.get("best_time_ms", row.get("time_ms", 0))))
		if value <= 0:
			continue
		if best <= 0 or value < best:
			best = value
	return best

func _store_board(board: Dictionary) -> void:
	var board_key: String = str(board.get("board_key", ""))
	if board_key.is_empty():
		return
	_boards_by_key[board_key] = _normalize_board(board)

func _save() -> void:
	var payload: Dictionary = {
		"_schema": SCHEMA_V1,
		"updated_unix": int(Time.get_unix_time_from_system()),
		"boards_by_key": _boards_by_key
	}
	var file: FileAccess = FileAccess.open(_resolved_save_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _resolved_save_path() -> String:
	var clean: String = save_path.strip_edges()
	return clean if not clean.is_empty() else SAVE_PATH_DEFAULT

func _badge_for_rank(rank: int) -> String:
	if rank <= 0:
		return ""
	if rank <= 5:
		return "TOP %d" % rank
	if rank <= 10:
		return "TOP 10"
	return ""

func _board_key(map_id: String, mode: String, period: String, period_scope: String) -> String:
	return "%s|%s|%s|%s" % [
		_normalize_token(map_id),
		_normalize_mode(mode),
		_normalize_period(period),
		period_scope.strip_edges()
	]

func _normalize_mode(raw_mode: String) -> String:
	var clean: String = _normalize_token(raw_mode).to_upper()
	return clean if not clean.is_empty() else DEFAULT_MODE

func _normalize_period(raw_period: String) -> String:
	var clean: String = _normalize_token(raw_period).to_upper()
	if PERIOD_LABELS.has(clean):
		return clean
	return DEFAULT_PERIOD

func _normalize_token(raw: String) -> String:
	return raw.strip_edges()

func _sanitize_handle(raw_handle: String, fallback: String) -> String:
	var clean: String = raw_handle.strip_edges()
	if clean.is_empty():
		clean = fallback.strip_edges()
	if clean.is_empty():
		return "Player"
	return clean

func _resolve_updated_at(value: int) -> int:
	return value if value > 0 else int(Time.get_unix_time_from_system())

func _slug(raw: String) -> String:
	var out: String = raw.to_lower()
	out = out.replace("|", "_")
	out = out.replace(" ", "_")
	out = out.replace("/", "_")
	return out

func _append_result(clean_map_id: String, clean_mode: String, period: String, result: Dictionary, recorded_at: int) -> Dictionary:
	var clean_period: String = _normalize_period(period)
	var clean_player_id: String = _normalize_token(str(result.get("player_id", "")))
	if clean_map_id.is_empty():
		return {"ok": false, "reason": "map_id_required"}
	if clean_player_id.is_empty():
		return {"ok": false, "reason": "player_id_required"}
	var best_time_ms: int = maxi(0, int(result.get("best_time_ms", result.get("time_ms", 0))))
	if best_time_ms <= 0:
		return {"ok": false, "reason": "best_time_ms_required"}
	var scope_id: String = _period_scope_id(clean_period, recorded_at)
	var board: Dictionary = _ensure_board(clean_map_id, clean_mode, clean_period, "", "", scope_id)
	var rows: Array = board.get("rows", []) as Array
	rows.append({
		"row_id": "%s_%d_%d" % [clean_player_id, recorded_at, rows.size()],
		"player_id": clean_player_id,
		"handle": _sanitize_handle(str(result.get("handle", clean_player_id)), clean_player_id),
		"best_time_ms": best_time_ms,
		"updated_at": recorded_at,
		"source": str(result.get("source", "run"))
	})
	board["rows"] = rows
	board["updated_at"] = recorded_at
	board["period_scope"] = scope_id
	_store_board(board)
	_save()
	return {
		"ok": true,
		"updated": true,
		"board_key": str(board.get("board_key", "")),
		"player_id": clean_player_id,
		"best_time_ms": _player_best_time_ms(rows, clean_player_id),
		"period": clean_period,
		"period_scope": scope_id
	}

func _period_scope_id(period: String, unix_time: int) -> String:
	var clean_period: String = _normalize_period(period)
	if clean_period == PERIOD_ALL_TIME:
		return "all_time"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(maxi(1, unix_time))
	var year: int = maxi(1, int(dt.get("year", 1)))
	var month: int = clampi(int(dt.get("month", 1)), 1, 12)
	var day: int = clampi(int(dt.get("day", 1)), 1, 31)
	match clean_period:
		"WEEKLY":
			var iso: Dictionary = _iso_week_components(year, month, day)
			return "%04d-W%02d" % [int(iso.get("year", year)), int(iso.get("week", 1))]
		"MONTHLY":
			return "%04d-%02d" % [year, month]
		"SEASON":
			var quarter: int = int(floor(float(month - 1) / 3.0)) + 1
			return "%04d-Q%d" % [year, quarter]
		_:
			return "all_time"

func _iso_week_components(year: int, month: int, day: int) -> Dictionary:
	var safe_year: int = maxi(1, year)
	var safe_month: int = clampi(month, 1, 12)
	var safe_day: int = clampi(day, 1, 31)
	var day_of_year: int = _day_of_year(safe_year, safe_month, safe_day)
	var iso_weekday: int = _iso_weekday(safe_year, safe_month, safe_day)
	var week: int = int(floor(float(day_of_year - iso_weekday + 10) / 7.0))
	var iso_year: int = safe_year
	if week < 1:
		iso_year = safe_year - 1
		week = _iso_weeks_in_year(iso_year)
	elif week > _iso_weeks_in_year(safe_year):
		iso_year = safe_year + 1
		week = 1
	return {"year": iso_year, "week": week}

func _iso_weeks_in_year(year: int) -> int:
	var jan1_iso_weekday: int = _iso_weekday(year, 1, 1)
	if jan1_iso_weekday == 4:
		return 53
	if jan1_iso_weekday == 3 and _is_leap_year(year):
		return 53
	return 52

func _day_of_year(year: int, month: int, day: int) -> int:
	var total: int = day
	for m in range(1, month):
		total += _days_in_month(year, m)
	return total

func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap_year(year) else 28
		_:
			return 30

func _is_leap_year(year: int) -> bool:
	if year % 400 == 0:
		return true
	if year % 100 == 0:
		return false
	return year % 4 == 0

func _iso_weekday(year: int, month: int, day: int) -> int:
	var t: Array[int] = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
	var adjusted_year: int = year
	if month < 3:
		adjusted_year -= 1
	var sunday_zero: int = (adjusted_year + int(floor(adjusted_year / 4.0)) - int(floor(adjusted_year / 100.0)) + int(floor(adjusted_year / 400.0)) + t[month - 1] + day) % 7
	return ((sunday_zero + 6) % 7) + 1
