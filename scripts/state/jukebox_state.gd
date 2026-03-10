extends RefCounted
class_name JukeboxState

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")

const PERIOD_LABELS: Array[String] = ["WEEKLY", "MONTHLY", "SEASON", "ALL TIME"]
const CATEGORY_ORDER: Array[String] = ["FEATURED", "CTF", "HIDDEN", "NOMANSLAND"]
const DIRECT_CTF_MAP_PATHS: Array[String] = [
	"res://maps/nomansland/MAP_nomansland__SBASE__1p.json"
]
const HIDDEN_CTF_MAP_PATHS: Array[String] = [
	"res://maps/_future/nomansland/MAP_nomansland__SBASE__1p__start_v12_top_row_vs_bottom_row_3each.json"
]
const FEATURED_MAP_PATHS: Array[String] = [
	"res://maps/nomansland/MAP_nomansland__SBASE__1p.json",
	"res://maps/nomansland/MAP_nomansland__SN6__1p.json",
	"res://maps/nomansland/MAP_nomansland__GBASE__1p.json",
	"res://maps/nomansland/MAP_nomansland__GBASE__BR2__TR2__1p.json",
	"res://maps/nomansland/MAP_nomansland__GBASE__TB__1p.json",
	"res://maps/_future/nomansland/MAP_nomansland__SBASE__1p__start_v12_top_row_vs_bottom_row_3each.json"
]

var _map_entries: Array[Dictionary] = []
var _entries_by_path: Dictionary = {}
var _categories: Array[String] = ["ALL"]

func refresh() -> void:
	_map_entries.clear()
	_entries_by_path.clear()
	_categories = ["ALL"]
	var category_seen: Dictionary = {"ALL": true}
	var map_paths: Array[String] = []
	map_paths.append_array(FEATURED_MAP_PATHS)
	for registry_path_any in MAP_REGISTRY.list_map_paths():
		var registry_path: String = str(registry_path_any)
		if not map_paths.has(registry_path):
			map_paths.append(registry_path)
	for path in map_paths:
		var loaded: Dictionary = MAP_LOADER.load_map(path)
		if not bool(loaded.get("ok", false)):
			continue
		var data: Dictionary = loaded.get("data", {}) as Dictionary
		var map_id: String = MAP_REGISTRY.map_id_from_path(path)
		if map_id == "MAP_TEST":
			continue
		var normalized: Dictionary = MAP_REGISTRY.normalize_map_id(map_id)
		var entry: Dictionary = {
			"path": path,
			"map_id": map_id,
			"title": map_title(map_id, data),
			"hero_title": hero_title(map_id, normalized),
			"category": primary_category(path, normalized),
			"filters": category_filters(path, normalized),
			"meta": map_meta_text(data, normalized),
			"desc": map_desc_text(data, normalized),
			"owner_counts": owner_counts(data),
			"supports_ctf": supports_ctf(path, normalized),
			"supports_hidden_ctf": supports_hidden_ctf(path, normalized)
		}
		_map_entries.append(entry)
		_entries_by_path[path] = entry
		for filter_any in entry.get("filters", []):
			var filter: String = str(filter_any)
			if filter.is_empty():
				continue
			category_seen[filter] = true
	_map_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("title", "")) < str(b.get("title", ""))
	)
	for label in CATEGORY_ORDER:
		if bool(category_seen.get(label, false)):
			_categories.append(label)
	for label_any in category_seen.keys():
		var label: String = str(label_any)
		if label == "ALL" or CATEGORY_ORDER.has(label):
			continue
		_categories.append(label)

func categories() -> Array[String]:
	if _map_entries.is_empty():
		refresh()
	return _categories.duplicate()

func catalog(category: String = "ALL") -> Array[Dictionary]:
	if _map_entries.is_empty():
		refresh()
	var wanted: String = category.strip_edges().to_upper()
	if wanted.is_empty() or wanted == "ALL":
		return _map_entries.duplicate(true)
	var out: Array[Dictionary] = []
	for entry in _map_entries:
		var filters: Array = entry.get("filters", []) as Array
		for filter_any in filters:
			if str(filter_any) == wanted:
				out.append(entry.duplicate(true))
				break
	return out

func entry_for_path(map_path: String) -> Dictionary:
	if _map_entries.is_empty():
		refresh()
	var entry: Dictionary = _entries_by_path.get(map_path, {})
	return entry.duplicate(true)

func board_snapshot(map_path: String, period: String, limit: int = 50) -> Dictionary:
	if _map_entries.is_empty():
		refresh()
	var selected: Dictionary = _entries_by_path.get(map_path, {})
	var map_id: String = str(selected.get("map_id", ""))
	return _build_stub_board(map_id, period, maxi(1, limit))

func owner_counts(data: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for hive_any in data.get("hives", []) as Array:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var owner_id: int = int(hive.get("owner_id", 0))
		counts[owner_id] = int(counts.get(owner_id, 0)) + 1
	return counts

func supports_ctf(path: String, normalized: Dictionary) -> bool:
	var family: String = str(normalized.get("family", "")).to_lower()
	return family == "nomansland" or DIRECT_CTF_MAP_PATHS.has(path)

func supports_hidden_ctf(path: String, normalized: Dictionary) -> bool:
	if HIDDEN_CTF_MAP_PATHS.has(path):
		return true
	var start: String = str(normalized.get("start", "")).to_lower()
	return start.contains("v12") or path.contains("3each")

func primary_category(path: String, normalized: Dictionary) -> String:
	if FEATURED_MAP_PATHS.has(path):
		return "FEATURED"
	var family: String = str(normalized.get("family", "other")).to_upper()
	return family if not family.is_empty() else "OTHER"

func category_filters(path: String, normalized: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.append("ALL")
	var category: String = primary_category(path, normalized)
	if not out.has(category):
		out.append(category)
	if supports_ctf(path, normalized) and not out.has("CTF"):
		out.append("CTF")
	if supports_hidden_ctf(path, normalized) and not out.has("HIDDEN"):
		out.append("HIDDEN")
	var family: String = str(normalized.get("family", "")).to_upper()
	if not family.is_empty() and not out.has(family):
		out.append(family)
	return out

func hero_title(map_id: String, normalized: Dictionary) -> String:
	var family: String = str(normalized.get("family", "map")).capitalize()
	var start: String = str(normalized.get("start", "starter")).replace("_", " ").capitalize()
	return "%s / %s" % [family, start]

func map_title(map_id: String, data: Dictionary) -> String:
	var raw_name: String = str(data.get("name", "")).strip_edges()
	if not raw_name.is_empty():
		return raw_name
	var body: String = map_id.trim_prefix("MAP_")
	var tokens: PackedStringArray = body.split("__", false)
	var pretty: Array[String] = []
	for token in tokens:
		var clean: String = token.replace("_", " ").strip_edges()
		if clean.is_empty():
			continue
		pretty.append(clean)
	return " / ".join(pretty)

func map_meta_text(data: Dictionary, normalized: Dictionary) -> String:
	var grid_w: int = int(data.get("grid_w", data.get("width", 0)))
	var grid_h: int = int(data.get("grid_h", data.get("height", 0)))
	var counts: Dictionary = owner_counts(data)
	var family: String = str(normalized.get("family", "map")).capitalize()
	var start: String = str(normalized.get("start", "START"))
	var mode: String = str(normalized.get("mode", "1p")).to_upper()
	return "%s | %s | %s | %dx%d | P1:%d P2:%d N:%d" % [
		family,
		start,
		mode,
		grid_w,
		grid_h,
		int(counts.get(1, 0)),
		int(counts.get(2, 0)),
		int(counts.get(0, 0))
	]

func map_desc_text(data: Dictionary, normalized: Dictionary) -> String:
	var family: String = str(normalized.get("family", "map")).capitalize()
	var start: String = str(normalized.get("start", "START"))
	var tags: Array[String] = []
	if supports_ctf("", normalized):
		tags.append("CTF")
	if supports_hidden_ctf("", normalized):
		tags.append("HIDDEN FLAG")
	var tag_text: String = ", ".join(tags)
	if tag_text.is_empty():
		tag_text = "DUEL"
	return "%s map scaffold. Start pattern: %s. Best fit right now: %s." % [family, start, tag_text]

func _build_stub_board(map_id: String, period: String, top_limit: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var seed_text: String = "%s|%s" % [map_id, period]
	rng.seed = int(seed_text.hash())
	var handles: Array[String] = [
		"SwarmDaddy", "HiveLaw", "BeeLine", "LaneLord", "WaxOn", "NectarKid", "HoneyBadger",
		"RushMint", "QueenStrat", "MapGrind", "BuzzKill", "Drone47", "TopRail", "SplitPush",
		"BotCheck", "FlagRunner", "GhostLine", "ApexHive", "TempoBee", "GridSmith"
	]
	var current_handle: String = "You"
	if ProfileManager != null and ProfileManager.has_method("get_display_name"):
		current_handle = str(ProfileManager.get_display_name()).strip_edges()
	if current_handle.is_empty():
		current_handle = "You"
	var base_ms: int = 76000 + int(abs(seed_text.hash()) % 22000)
	var user_rank: int = clampi(12 + int(abs((seed_text + "|you").hash()) % 34), 1, top_limit)
	var out: Array[Dictionary] = []
	for i in range(top_limit):
		var rank: int = i + 1
		var handle: String = handles[i % handles.size()]
		handle += "%02d" % int((i * 7 + abs(seed_text.hash())) % 97)
		if rank == user_rank:
			handle = current_handle
		var jitter: int = int(rng.randi_range(20, 260))
		var time_ms: int = base_ms + i * 410 + jitter
		var badge: String = ""
		if rank <= 5:
			badge = "TOP %d" % rank
		elif rank <= 10:
			badge = "TOP 10"
		out.append({
			"rank": rank,
			"handle": handle,
			"time_ms": time_ms,
			"badge": badge
		})
	var your_best_ms: int = int((out[user_rank - 1] as Dictionary).get("time_ms", base_ms))
	return {
		"entries": out,
		"your_rank": user_rank,
		"your_best_ms": your_best_ms
	}
