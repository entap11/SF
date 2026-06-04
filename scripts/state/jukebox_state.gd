extends RefCounted
class_name JukeboxState

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")
const JukeboxLeaderboardStoreScript := preload("res://scripts/state/jukebox_leaderboard_store.gd")

const PERIOD_LABELS: Array[String] = ["WEEKLY", "MONTHLY", "SEASON", "ALL TIME"]
const CATEGORY_ORDER: Array[String] = ["FEATURED", "CTF", "HIDDEN", "FFA", "NOMANSLAND", "DELTA", "RACE"]
const INTERNAL_CATEGORY_LABELS: Array[String] = ["STRATEGY", "TEMPO", "REACTION", "GREED", "GREEDY"]
const DEFAULT_BOARD_MODE: String = "ASYNC_SINGLE_MAP_TIMED"
const DIRECT_CTF_MAP_PATHS: Array[String] = [
	"res://maps/_future/nomansland/MAP_nomansland__545__v01_top2_sides__1p.json"
]
const HIDDEN_CTF_MAP_PATHS: Array[String] = []
const FEATURED_MAP_PATHS: Array[String] = [
	"res://maps/_future/nomansland/MAP_nomansland__545__v01_top2_sides__1p.json",
	"res://maps/_future/nomansland/MAP_nomansland__545__v17_four_corners_only__1p.json",
	"res://maps/_future/nomansland/MAP_nomansland__444__v01_pinched_spine__1p.json"
]
const HERO_FALLBACK_PREVIEW_PATH: String = "res://assets/sprites/sf_skin_v1/map_jukebox.png"

var _map_entries: Array[Dictionary] = []
var _entries_by_path: Dictionary = {}
var _categories: Array[String] = ["ALL"]
var _leaderboard_store: RefCounted = JukeboxLeaderboardStoreScript.new()

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
	var seen_catalog_paths: Dictionary = {}
	for path in map_paths:
		var source_path: String = path
		var catalog_path: String = _preferred_jukebox_map_path(source_path)
		if seen_catalog_paths.has(catalog_path):
			continue
		seen_catalog_paths[catalog_path] = true
		var loaded: Dictionary = MAP_LOADER.load_map(catalog_path)
		if not bool(loaded.get("ok", false)):
			continue
		var data: Dictionary = loaded.get("data", {}) as Dictionary
		var source_map_id: String = MAP_REGISTRY.map_id_from_path(source_path)
		var map_id: String = MAP_REGISTRY.map_id_from_path(catalog_path)
		if map_id == "MAP_TEST":
			continue
		var normalized: Dictionary = MAP_REGISTRY.normalize_map_id(map_id)
		var source_normalized: Dictionary = MAP_REGISTRY.normalize_map_id(source_map_id)
		var public_title: String = MAP_REGISTRY.public_map_display_name_for_id(source_map_id)
		var playstyle_tags: Array[String] = _entry_playstyle_tags(data, normalized)
		var entry: Dictionary = {
			"path": catalog_path,
			"source_path": source_path,
			"map_id": map_id,
			"source_map_id": source_map_id,
			"title": public_title,
			"hero_title": "",
			"map_family": _entry_map_family(data, normalized),
			"display_family": _entry_display_family(data, normalized),
			"player_buckets": _entry_player_buckets(data, normalized),
			"playstyle_tags": playstyle_tags,
			"season_tags": _entry_string_array(data, "season_tags"),
			"rotation": _entry_rotation(data),
			"async_bot_count": _entry_async_bot_count(data, normalized),
			"preview_path": preview_path(data),
			"category": primary_category(source_path, source_normalized),
			"filters": category_filters(source_path, source_normalized, playstyle_tags),
			"meta": "",
			"desc": "",
			"sort_key": MAP_REGISTRY.public_map_sort_key_for_id(source_map_id),
			"public_alias_status": str(MAP_REGISTRY.public_map_alias_entry_for_id(source_map_id).get("status", "unlisted")),
			"owner_counts": owner_counts(data),
			"supports_ctf": supports_ctf(source_path, source_normalized),
			"supports_hidden_ctf": supports_hidden_ctf(source_path, source_normalized)
		}
		_map_entries.append(entry)
		_entries_by_path[catalog_path] = entry
		for filter_any in entry.get("filters", []):
			var filter: String = str(filter_any)
			if filter.is_empty():
				continue
			if _is_internal_category_label(filter):
				continue
			category_seen[filter] = true
	_map_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("sort_key", "")) < str(b.get("sort_key", ""))
	)
	_ensure_unique_titles()
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
	var catalog_path: String = _preferred_jukebox_map_path(map_path)
	var entry: Dictionary = _entries_by_path.get(catalog_path, {})
	return entry.duplicate(true)

func board_snapshot(map_path: String, period: String, limit: int = 50) -> Dictionary:
	if _map_entries.is_empty():
		refresh()
	var selected: Dictionary = _entries_by_path.get(map_path, {})
	var map_id: String = str(selected.get("map_id", ""))
	if map_id.is_empty():
		return {
			"entries": [],
			"your_rank": 0,
			"your_best_ms": 0
		}
	var requester_id: String = ""
	var requester_handle: String = ""
	var profile_manager: Node = _profile_manager()
	if profile_manager != null:
		if profile_manager.has_method("get_user_id"):
			requester_id = str(profile_manager.call("get_user_id")).strip_edges()
		if profile_manager.has_method("get_display_name"):
			requester_handle = str(profile_manager.call("get_display_name")).strip_edges()
	if _leaderboard_store != null and _leaderboard_store.has_method("reload"):
		_leaderboard_store.call("reload")
	return _leaderboard_store.get_board_snapshot(
		map_id,
		_board_mode_for_entry(selected),
		period,
		requester_id,
		requester_handle,
		maxi(1, limit)
	)

func player_map_summary(map_path: String, player_id: String, player_handle: String = "", period: String = "ALL TIME") -> Dictionary:
	if _map_entries.is_empty():
		refresh()
	var selected: Dictionary = _entries_by_path.get(map_path, {})
	var map_id: String = str(selected.get("map_id", ""))
	if map_id.is_empty():
		return {
			"player_id": player_id.strip_edges(),
			"best_time_ms": 0,
			"run_count": 0,
			"latest_time_ms": 0,
			"period": period.strip_edges().to_upper()
		}
	if _leaderboard_store != null and _leaderboard_store.has_method("reload"):
		_leaderboard_store.call("reload")
	return _leaderboard_store.get_player_map_summary(
		map_id,
		_board_mode_for_entry(selected),
		player_id,
		player_handle,
		period
	)

func owner_counts(data: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for hive_any in data.get("hives", []) as Array:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var owner_id: int = int(hive.get("owner_id", 0))
		counts[owner_id] = int(counts.get(owner_id, 0)) + 1
	if not counts.is_empty():
		return counts
	for node_any in data.get("nodes", []) as Array:
		if typeof(node_any) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_any as Dictionary
		var kind: String = str(node.get("kind", "hive")).strip_edges().to_lower()
		if kind != "hive" and kind != "player_hive" and kind != "npc_hive":
			continue
		var owner: String = str(node.get("owner", node.get("team", ""))).strip_edges().to_upper()
		var owner_id: int = 0
		if owner.begins_with("P") and owner.trim_prefix("P").is_valid_int():
			owner_id = int(owner.trim_prefix("P"))
		counts[owner_id] = int(counts.get(owner_id, 0)) + 1
	return counts

func _preferred_jukebox_map_path(path: String) -> String:
	var clean: String = path.strip_edges()
	if clean.ends_with("__4p.json"):
		var one_player_path: String = clean.trim_suffix("__4p.json") + "__1p.json"
		if FileAccess.file_exists(one_player_path):
			return one_player_path
	return clean

func supports_ctf(path: String, normalized: Dictionary) -> bool:
	var family: String = _map_family_for_path(path, normalized)
	return family == "nomansland" or DIRECT_CTF_MAP_PATHS.has(path)

func supports_hidden_ctf(path: String, normalized: Dictionary) -> bool:
	if HIDDEN_CTF_MAP_PATHS.has(path):
		return true
	var start: String = str(normalized.get("start", "")).to_lower()
	return start.contains("v12") or path.contains("3each")

func primary_category(path: String, normalized: Dictionary) -> String:
	if FEATURED_MAP_PATHS.has(path):
		return "FEATURED"
	var family: String = _map_family_for_path(path, normalized).to_upper()
	return family if not family.is_empty() else "OTHER"

func category_filters(path: String, normalized: Dictionary, _playstyle_tags: Array[String] = []) -> Array[String]:
	var out: Array[String] = []
	out.append("ALL")
	var category: String = primary_category(path, normalized)
	if not _is_internal_category_label(category) and not out.has(category):
		out.append(category)
	if supports_ctf(path, normalized) and not out.has("CTF"):
		out.append("CTF")
	if supports_hidden_ctf(path, normalized) and not out.has("HIDDEN"):
		out.append("HIDDEN")
	var family: String = _map_family_for_path(path, normalized).to_upper()
	if (family == "NOMANSLAND" or family == "DELTA") and not out.has("FFA"):
		out.append("FFA")
	if not family.is_empty() and not _is_internal_category_label(family) and not out.has(family):
		out.append(family)
	return out

func _is_internal_category_label(label: String) -> bool:
	return INTERNAL_CATEGORY_LABELS.has(label.strip_edges().to_upper())

func _map_family_for_path(path: String, normalized: Dictionary) -> String:
	var family: String = str(normalized.get("family", "")).strip_edges().to_lower()
	if not family.is_empty():
		return family
	var map_id: String = MAP_REGISTRY.map_id_from_path(path)
	var alias: Dictionary = MAP_REGISTRY.public_map_alias_entry_for_id(map_id)
	family = str(alias.get("family", "")).strip_edges().to_lower()
	if not family.is_empty():
		return family
	if map_id.to_lower().begins_with("map_nomansland__") or path.to_lower().contains("/nomansland/"):
		return "nomansland"
	if map_id.to_lower().begins_with("map_delta__") or path.to_lower().contains("/delta/"):
		return "delta"
	return ""

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

func _entry_map_family(data: Dictionary, normalized: Dictionary) -> String:
	var family: String = str(data.get("family", normalized.get("family", ""))).strip_edges().to_lower()
	if not family.is_empty():
		return family
	return str(normalized.get("family", "")).strip_edges().to_lower()

func _entry_display_family(data: Dictionary, normalized: Dictionary) -> String:
	var display_family: String = str(data.get("display_family", "")).strip_edges()
	if not display_family.is_empty():
		return display_family
	var family: String = _entry_map_family(data, normalized)
	if family.is_empty():
		return ""
	return family.capitalize()

func _entry_string_array(data: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	var values_v: Variant = data.get(key, [])
	if typeof(values_v) != TYPE_ARRAY:
		return out
	for value_any in values_v as Array:
		var value: String = str(value_any).strip_edges().to_upper()
		if value.is_empty():
			continue
		if not out.has(value):
			out.append(value)
	return out

func _entry_playstyle_tags(data: Dictionary, normalized: Dictionary) -> Array[String]:
	var out: Array[String] = _entry_string_array(data, "playstyle_tags")
	if out.is_empty():
		out = _entry_string_array(data, "game_types")
	if out.is_empty():
		out.append_array(_family_default_playstyle_tags(_entry_map_family(data, normalized)))
	for tag in out.duplicate():
		var clean: String = str(tag).strip_edges().to_upper()
		if clean.is_empty():
			out.erase(tag)
			continue
		if clean != tag:
			out.erase(tag)
			if not out.has(clean):
				out.append(clean)
	return out

func _family_default_playstyle_tags(family: String) -> Array[String]:
	match family.strip_edges().to_lower():
		"nomansland":
			return ["FFA", "STRATEGY"]
		"delta":
			return ["FFA", "STRATEGY"]
		_:
			return []

func _entry_player_buckets(data: Dictionary, normalized: Dictionary) -> Array[String]:
	var buckets: Array[String] = _entry_string_array(data, "player_buckets")
	if buckets.is_empty():
		buckets = _entry_string_array(data, "player_modes")
	var mode: String = str(data.get("mode", normalized.get("mode", ""))).strip_edges().to_upper()
	if buckets.is_empty() and not mode.is_empty():
		buckets.append(mode)
	return buckets

func _entry_rotation(data: Dictionary) -> Dictionary:
	var rotation_v: Variant = data.get("rotation", {})
	if typeof(rotation_v) != TYPE_DICTIONARY:
		return {}
	return (rotation_v as Dictionary).duplicate(true)

func _entry_async_bot_count(data: Dictionary, normalized: Dictionary) -> int:
	var explicit_count: int = int(data.get("async_bot_count", -1))
	if explicit_count >= 0:
		return explicit_count
	var buckets: Array[String] = _entry_player_buckets(data, normalized)
	var max_players: int = 0
	for bucket in buckets:
		var clean: String = bucket.strip_edges().to_upper()
		if clean.ends_with("P"):
			clean = clean.left(clean.length() - 1)
		if clean.is_valid_int():
			max_players = maxi(max_players, int(clean))
	var mode: String = str(data.get("mode", normalized.get("mode", ""))).strip_edges().to_lower()
	if max_players <= 1 and mode == "1p":
		return 1
	return maxi(0, max_players - 1)

func preview_path(data: Dictionary) -> String:
	var raw: String = str(data.get("preview_path", "")).strip_edges()
	if not raw.is_empty() and ResourceLoader.exists(raw):
		return raw
	return HERO_FALLBACK_PREVIEW_PATH

func _ensure_unique_titles() -> void:
	var used_titles: Dictionary = {}
	var duplicate_counts: Dictionary = {}
	for index in range(_map_entries.size()):
		var entry: Dictionary = _map_entries[index]
		var base_title: String = str(entry.get("title", "")).strip_edges()
		var map_id: String = str(entry.get("map_id", "")).strip_edges()
		if base_title.is_empty():
			base_title = MAP_REGISTRY.fallback_public_map_display_name_for_id(map_id)
		var title_key: String = base_title.to_lower()
		var resolved_title: String = base_title
		if used_titles.has(title_key):
			var fallback_title: String = MAP_REGISTRY.fallback_public_map_display_name_for_id(map_id).strip_edges()
			var fallback_key: String = fallback_title.to_lower()
			if not fallback_title.is_empty() and not used_titles.has(fallback_key):
				resolved_title = fallback_title
			else:
				var next_index: int = int(duplicate_counts.get(title_key, 1)) + 1
				duplicate_counts[title_key] = next_index
				resolved_title = "%s_%d" % [base_title, next_index]
				while used_titles.has(resolved_title.to_lower()):
					next_index += 1
					duplicate_counts[title_key] = next_index
					resolved_title = "%s_%d" % [base_title, next_index]
		else:
			duplicate_counts[title_key] = 1
		used_titles[resolved_title.to_lower()] = true
		entry["title"] = resolved_title
		_map_entries[index] = entry
		var path: String = str(entry.get("path", ""))
		if not path.is_empty():
			_entries_by_path[path] = entry

func _board_mode_for_entry(entry: Dictionary) -> String:
	return str(entry.get("board_mode", DEFAULT_BOARD_MODE)).strip_edges().to_upper()

func _profile_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	var tree: SceneTree = loop as SceneTree
	if tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/ProfileManager")
