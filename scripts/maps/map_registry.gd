class_name MapRegistry
extends RefCounted

const MAP_ROOT: String = "res://maps"
const SKIP_DIR_TOKENS: Array[String] = ["/_legacy", "/templates", "/_future"]
const SANDBOX_ENABLED: bool = true
const SANDBOX_ALLOWED_MAP_IDS: Array[String] = [
	"MAP_TEST",
	"MAP_nomansland__SBASE__1p",
	"MAP_nomansland__SN6__1p",
	"MAP_nomansland__GBASE__1p",
	"MAP_nomansland__GBASE__BR2__TR2__1p",
	"MAP_nomansland__GBASE__TB__1p",
	"MAP_nomansland__SBASE__1p__start_v12_top_row_vs_bottom_row_3each"
]
const ALLOWED_MODES: Array[String] = ["1p", "2p", "3p", "4p"]

static func list_map_paths() -> Array[String]:
	var out: Array[String] = []
	_collect_json_map_files(MAP_ROOT, out)
	var filtered: Array[String] = []
	for path_any in out:
		var path: String = str(path_any)
		if not is_map_path_allowed(path):
			continue
		filtered.append(path)
	filtered.sort()
	return filtered

static func map_id_from_path(path: String) -> String:
	return path.get_file().get_basename().strip_edges()

static func map_id_from_input(path_or_id: String) -> String:
	var raw: String = path_or_id.strip_edges()
	if raw.is_empty():
		return ""
	if raw.begins_with("res://"):
		return map_id_from_path(raw)
	var file_name: String = raw.get_file()
	if file_name.find("/") != -1:
		file_name = file_name.get_file()
	if file_name.to_lower().ends_with(".json"):
		return file_name.get_basename().strip_edges()
	return file_name.strip_edges()

static func is_map_path_allowed(path: String) -> bool:
	return is_map_id_allowed(map_id_from_path(path))

static func is_map_id_allowed(map_id: String) -> bool:
	if not SANDBOX_ENABLED:
		return true
	var normalized: String = map_id_from_input(map_id).to_upper()
	for allow_any in SANDBOX_ALLOWED_MAP_IDS:
		if normalized == str(allow_any).to_upper():
			return true
	return false

static func normalize_map_id(map_id: String) -> Dictionary:
	var raw_id: String = map_id_from_input(map_id)
	if raw_id.is_empty():
		return _normalize_fail("empty_map_id")
	if raw_id.to_upper() == "MAP_TEST":
		return {
			"ok": true,
			"id": "MAP_TEST",
			"family": "test",
			"start": "SBASE",
			"mode": "1p",
			"mods": [],
			"legacy_exception": true
		}
	var parts: PackedStringArray = raw_id.split("__", false)
	if parts.size() < 3:
		return _normalize_fail("id_requires_at_least_family_start_mode")
	var family_token: String = parts[0]
	if not family_token.begins_with("MAP_") or family_token.length() <= 4:
		return _normalize_fail("family_token_must_start_with_MAP_")
	var start_token: String = str(parts[1]).to_upper()
	if not _is_valid_start_token(start_token):
		return _normalize_fail("start_token_must_be_SBASE_GBASE_or_SN#")
	var mode_token: String = str(parts[parts.size() - 1]).to_lower()
	if not ALLOWED_MODES.has(mode_token):
		return _normalize_fail("mode_token_must_be_1p_2p_3p_or_4p")

	var player_fixed: int = -1
	var npc_fixed: int = -1
	var player_layer: bool = false
	var npc_layer: bool = false
	var barracks_count: int = -1
	var tower_count: int = -1
	var seen_unknown: Array[String] = []
	for i in range(2, parts.size() - 1):
		var token_raw: String = str(parts[i]).strip_edges()
		if token_raw.is_empty():
			continue
		var token: String = token_raw.to_upper()
		if token == "PLAYERLAYER":
			if player_layer or player_fixed >= 0:
				return _normalize_fail("duplicate_player_modifier")
			player_layer = true
			continue
		if token == "NPCLAYER":
			if npc_layer or npc_fixed >= 0:
				return _normalize_fail("duplicate_npc_modifier")
			npc_layer = true
			continue
		if token.begins_with("P") and _is_digits(token.substr(1)):
			if player_layer or player_fixed >= 0:
				return _normalize_fail("duplicate_player_modifier")
			player_fixed = int(token.substr(1))
			continue
		if token.begins_with("NPC") and _is_digits(token.substr(3)):
			if npc_layer or npc_fixed >= 0:
				return _normalize_fail("duplicate_npc_modifier")
			npc_fixed = int(token.substr(3))
			continue
		if token.begins_with("BR") and _is_digits(token.substr(2)):
			if barracks_count >= 0:
				return _normalize_fail("duplicate_br_modifier")
			barracks_count = int(token.substr(2))
			continue
		if token.begins_with("TR") and _is_digits(token.substr(2)):
			if tower_count >= 0:
				return _normalize_fail("duplicate_tr_modifier")
			tower_count = int(token.substr(2))
			continue
		seen_unknown.append(token_raw)
	if not seen_unknown.is_empty():
		return _normalize_fail("unknown_tokens: %s" % ", ".join(seen_unknown))

	var mods: Array[String] = []
	if player_layer:
		mods.append("PLAYERLAYER")
	elif player_fixed > 0 and player_fixed != 10:
		mods.append("P%d" % player_fixed)
	if npc_layer:
		mods.append("NPCLAYER")
	elif npc_fixed > 0 and npc_fixed != 5:
		mods.append("NPC%d" % npc_fixed)
	if barracks_count > 0:
		mods.append("BR%d" % barracks_count)
	if tower_count > 0:
		mods.append("TR%d" % tower_count)

	var normalized_tokens: Array[String] = [family_token, start_token]
	normalized_tokens.append_array(mods)
	normalized_tokens.append(mode_token)
	return {
		"ok": true,
		"id": "__".join(normalized_tokens),
		"family": family_token.trim_prefix("MAP_").to_lower(),
		"start": start_token,
		"mode": mode_token,
		"mods": mods.duplicate()
	}

static func _normalize_fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"id": "",
		"reason": reason
	}

static func _is_valid_start_token(token: String) -> bool:
	if token == "SBASE":
		return true
	if token == "GBASE":
		return true
	if not token.begins_with("SN"):
		return false
	return _is_digits(token.substr(2))

static func _is_digits(text: String) -> bool:
	if text.is_empty():
		return false
	for i in range(text.length()):
		var c: int = text.unicode_at(i)
		if c < 48 or c > 57:
			return false
	return true

static func _collect_json_map_files(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var path: String = dir_path.path_join(name)
		if dir.current_is_dir():
			if _should_skip_dir(path):
				continue
			_collect_json_map_files(path, out)
			continue
		if not name.to_lower().ends_with(".json"):
			continue
		if not _is_map_candidate_path(path):
			continue
		out.append(path)
	dir.list_dir_end()

static func _should_skip_dir(path: String) -> bool:
	for token_any in SKIP_DIR_TOKENS:
		var token: String = str(token_any)
		if path.find(token) != -1:
			return true
	return false

static func _is_map_candidate_path(path: String) -> bool:
	var map_id: String = map_id_from_path(path)
	return map_id.begins_with("MAP_")
