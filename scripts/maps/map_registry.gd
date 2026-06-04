class_name MapRegistry
extends RefCounted

const MAP_ROOT: String = "res://maps"
const SKIP_DIR_TOKENS: Array[String] = ["/_legacy", "/templates"]
const SANDBOX_ENABLED: bool = true
const SANDBOX_ENV_VAR: String = "SF_MAP_SANDBOX"
const SANDBOX_ALLOWED_MAP_IDS: Array[String] = [
	"MAP_TEST"
]
const SANDBOXED_PUBLIC_STYLES: Dictionary = {
	"nomansland": ["656"]
}
const PUBLIC_NOMANSLAND_SEQUENCE_IDS: Array[String] = [
	"MAP_nomansland__545__v01_top2_sides__1p",
	"MAP_nomansland__545__v17_four_corners_only__1p",
	"MAP_nomansland__444__v01_pinched_spine__1p"
]
const ALLOWED_MODES: Array[String] = ["1p", "2p", "3p", "4p"]
const PUBLIC_MAP_ALIASES: Dictionary = {
	"MAP_nomansland__SBASE__1p": {
		"public_name": "nomansland",
		"family": "nomansland",
		"sequence": 1,
		"status": "active"
	},
	"MAP_nomansland__SN6__1p": {
		"public_name": "nomansland2",
		"family": "nomansland",
		"sequence": 2,
		"status": "active"
	},
	"MAP_nomansland__GBASE__1p": {
		"public_name": "nomansland3",
		"family": "nomansland",
		"sequence": 3,
		"status": "active"
	},
	"MAP_nomansland__GBASE__BR2__TR2__1p": {
		"public_name": "nomansland4",
		"family": "nomansland",
		"sequence": 4,
		"status": "active"
	},
	"MAP_nomansland__GBASE__TB__1p": {
		"public_name": "nomansland5",
		"family": "nomansland",
		"sequence": 5,
		"status": "active"
	},
	"MAP_nomansland__SBASE__1p__start_v12_top_row_vs_bottom_row_3each": {
		"public_name": "nomansland6",
		"family": "nomansland",
		"sequence": 6,
		"status": "active"
	},
	"MAP_nomansland__SBASE__1p__midrails_v01": {
		"public_name": "nomansland656-midrails1",
		"family": "nomansland",
		"style": "656",
		"style_sequence": 61,
		"sequence": 61,
		"status": "active"
	},
	"MAP_delta__SBASE__3p": {
		"public_name": "delta",
		"family": "delta",
		"sequence": 1,
		"status": "active"
	},
	"MAP_delta__SBASE__BR3__3p": {
		"public_name": "delta1",
		"family": "delta",
		"sequence": 2,
		"status": "active"
	},
	"MAP_delta__SBASE__TR3__3p": {
		"public_name": "delta2",
		"family": "delta",
		"sequence": 3,
		"status": "active"
	},
	"MAP_tritip__SBASE__3p": {
		"public_name": "tritip1",
		"family": "tritip",
		"sequence": 1,
		"status": "candidate"
	},
	"MAP_rink_rat__SBASE__4p": {
		"public_name": "rinkrat1",
		"family": "rink_rat",
		"sequence": 1,
		"status": "candidate"
	},
	"MAP_rink_rat__LR__4p": {
		"public_name": "rinkrat2",
		"family": "rink_rat",
		"sequence": 2,
		"status": "candidate"
	},
	"MAP_iron_cross__SBASE__4p": {
		"public_name": "ironcross1",
		"family": "iron_cross",
		"sequence": 1,
		"status": "candidate"
	},
	"MAP_swirly__SBASE__4p": {
		"public_name": "swirly1",
		"family": "swirly",
		"sequence": 1,
		"status": "candidate"
	},
	"MAP_race__SBASE__1p": {
		"public_name": "race",
		"family": "race",
		"sequence": 1,
		"status": "active"
	},
	"MAP_corkscrew__SBASE__1p": {
		"public_name": "corkscrew",
		"family": "corkscrew",
		"sequence": 1,
		"status": "candidate"
	},
	"MAP_laneclimb__SBASE__4p": {
		"public_name": "laneclimb",
		"family": "laneclimb",
		"sequence": 1,
		"status": "candidate"
	},
	"MAP_knifefight__SBASE__1p": {
		"public_name": "knifefight1",
		"family": "knifefight",
		"sequence": 1,
		"status": "candidate"
	},
	"MAP_knifefight__KF2__1p": {
		"public_name": "knifefight2",
		"family": "knifefight",
		"sequence": 2,
		"status": "candidate"
	},
	"MAP_knifefight__KF2_CLOSE__4p": {
		"public_name": "knifefight2close",
		"family": "knifefight",
		"sequence": 3,
		"status": "candidate"
	},
	"MAP_knifefight__KF3__1p": {
		"public_name": "knifefight3",
		"family": "knifefight",
		"sequence": 4,
		"status": "candidate"
	},
	"MAP_knifefight__KF3_CLOSE__4p": {
		"public_name": "knifefight3close",
		"family": "knifefight",
		"sequence": 5,
		"status": "candidate"
	},
	"MAP_knifefight__KF4_WALLS__1p": {
		"public_name": "knifefight4",
		"family": "knifefight",
		"sequence": 6,
		"status": "candidate"
	},
	"MAP_quadfight__SBASE__4p": {
		"public_name": "quadfight1",
		"family": "quadfight",
		"sequence": 1,
		"status": "candidate"
	},
	"MAP_closequarters__SBASE__4p": {
		"public_name": "closequarters1",
		"family": "closequarters",
		"sequence": 1,
		"status": "candidate"
	},
	"MAP_closequarters__CQ2__4p": {
		"public_name": "closequarters2",
		"family": "closequarters",
		"sequence": 2,
		"status": "candidate"
	},
	"MAP_closequarters__CQ3__4p": {
		"public_name": "closequarters3",
		"family": "closequarters",
		"sequence": 3,
		"status": "candidate"
	},
	"MAP_corridors__SBASE__4p": {
		"public_name": "corridors1",
		"family": "corridors",
		"sequence": 1,
		"status": "candidate"
	},
	"MAP_centerstrike__SBASE__4p": {
		"public_name": "centerstrike1",
		"family": "centerstrike",
		"sequence": 1,
		"status": "candidate"
	},
	"MAP_centerstrike__CS2__4p": {
		"public_name": "centerstrike2",
		"family": "centerstrike",
		"sequence": 2,
		"status": "candidate"
	},
	"MAP_centerstrike__CS3__4p": {
		"public_name": "centerstrike3",
		"family": "centerstrike",
		"sequence": 3,
		"status": "candidate"
	}
}

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

static func public_map_display_name_for_path(path: String) -> String:
	return public_map_display_name_for_id(map_id_from_path(path))

static func public_map_display_name_for_id(map_id: String) -> String:
	var raw_id: String = map_id_from_input(map_id)
	if raw_id.is_empty():
		return ""
	var alias: Dictionary = public_map_alias_entry_for_id(raw_id)
	var public_name: String = str(alias.get("public_name", "")).strip_edges()
	if not public_name.is_empty():
		return public_name
	return _fallback_public_map_name(raw_id)

static func fallback_public_map_display_name_for_id(map_id: String) -> String:
	var raw_id: String = map_id_from_input(map_id)
	if raw_id.is_empty():
		return ""
	return _fallback_public_map_name(raw_id)

static func public_map_style_for_id(map_id: String) -> String:
	var raw_id: String = map_id_from_input(map_id)
	if raw_id.is_empty():
		return ""
	var alias: Dictionary = public_map_alias_entry_for_id(raw_id)
	var style: String = str(alias.get("style", "")).strip_edges().to_lower()
	if not style.is_empty():
		return style
	return _nomansland_public_style_for_id(raw_id)

static func public_map_sort_key_for_path(path: String) -> String:
	return public_map_sort_key_for_id(map_id_from_path(path))

static func public_map_sort_key_for_id(map_id: String) -> String:
	var raw_id: String = map_id_from_input(map_id)
	var alias: Dictionary = public_map_alias_entry_for_id(raw_id)
	var family: String = str(alias.get("family", "")).strip_edges().to_lower()
	if family.is_empty():
		family = _public_family_from_id(raw_id)
	var style: String = str(alias.get("style", "")).strip_edges().to_lower()
	if style.is_empty():
		style = public_map_style_for_id(raw_id)
	var style_rank: int = _public_style_sort_rank(family, style)
	var sequence: int = int(alias.get("style_sequence", alias.get("sequence", 999999)))
	return "%s:%03d:%s:%06d:%s" % [family, style_rank, style, sequence, raw_id]

static func public_map_alias_entry_for_id(map_id: String) -> Dictionary:
	var raw_id: String = map_id_from_input(map_id)
	if raw_id.is_empty():
		return {}
	var sequence_entry: Dictionary = _public_nomansland_sequence_alias_for_id(raw_id)
	if not sequence_entry.is_empty():
		if _is_public_alias_sandboxed(sequence_entry):
			return {}
		return sequence_entry
	var candidates: Array[String] = [raw_id]
	var normalized: Dictionary = normalize_map_id(raw_id)
	if bool(normalized.get("ok", false)):
		var canonical_id: String = str(normalized.get("id", "")).strip_edges()
		if not canonical_id.is_empty() and not candidates.has(canonical_id):
			candidates.append(canonical_id)
	for key_any in PUBLIC_MAP_ALIASES.keys():
		var key: String = str(key_any)
		for candidate in candidates:
			if key.to_upper() == candidate.to_upper():
				var entry: Dictionary = PUBLIC_MAP_ALIASES[key] as Dictionary
				var out: Dictionary = entry.duplicate(true)
				out["map_id"] = key
				if _is_public_alias_sandboxed(out):
					return {}
				return out
	return {}

static func has_public_map_alias_for_id(map_id: String) -> bool:
	return not public_map_alias_entry_for_id(map_id).is_empty()

static func registered_public_map_aliases() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for i in range(PUBLIC_NOMANSLAND_SEQUENCE_IDS.size()):
		var key: String = str(PUBLIC_NOMANSLAND_SEQUENCE_IDS[i])
		var row: Dictionary = _public_nomansland_sequence_alias_for_id(key)
		if _is_public_alias_sandboxed(row):
			continue
		out.append(row)
		seen[key.to_upper()] = true
	for key_any in PUBLIC_MAP_ALIASES.keys():
		var key: String = str(key_any)
		if seen.has(key.to_upper()):
			continue
		var entry: Dictionary = PUBLIC_MAP_ALIASES[key] as Dictionary
		var row: Dictionary = entry.duplicate(true)
		row["map_id"] = key
		if _is_public_alias_sandboxed(row):
			continue
		out.append(row)
		seen[key.to_upper()] = true
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var family_a: String = str(a.get("family", "")).to_lower()
		var family_b: String = str(b.get("family", "")).to_lower()
		if family_a == family_b:
			var style_a: String = str(a.get("style", "")).to_lower()
			var style_b: String = str(b.get("style", "")).to_lower()
			var style_rank_a: int = _public_style_sort_rank(family_a, style_a)
			var style_rank_b: int = _public_style_sort_rank(family_b, style_b)
			if style_rank_a == style_rank_b:
				return int(a.get("style_sequence", a.get("sequence", 0))) < int(b.get("style_sequence", b.get("sequence", 0)))
			return style_rank_a < style_rank_b
		return family_a < family_b
	)
	return out

static func _is_public_alias_sandboxed(alias: Dictionary) -> bool:
	if not _is_sandbox_enabled():
		return false
	if alias.is_empty():
		return false
	var family: String = str(alias.get("family", "")).strip_edges().to_lower()
	var style: String = str(alias.get("style", "")).strip_edges().to_lower()
	if family.is_empty():
		return false
	if style.is_empty():
		style = _nomansland_public_style_for_id(str(alias.get("map_id", ""))) if family == "nomansland" else ""
	if style.is_empty():
		return false
	var sandboxed_any: Variant = SANDBOXED_PUBLIC_STYLES.get(family, [])
	if typeof(sandboxed_any) != TYPE_ARRAY:
		return false
	for style_any in sandboxed_any as Array:
		if style == str(style_any).strip_edges().to_lower():
			return true
	return false

static func _public_nomansland_sequence_alias_for_id(map_id: String) -> Dictionary:
	var raw_id: String = map_id_from_input(map_id)
	var style: String = _nomansland_public_style_for_id(raw_id)
	var style_sequence: int = 0
	for i in range(PUBLIC_NOMANSLAND_SEQUENCE_IDS.size()):
		var key: String = str(PUBLIC_NOMANSLAND_SEQUENCE_IDS[i])
		if _nomansland_public_style_for_id(key) == style:
			style_sequence += 1
		if key.to_upper() == raw_id.to_upper():
			return _make_public_nomansland_sequence_alias(key, style, style_sequence)
	return {}

static func _make_public_nomansland_sequence_alias(map_id: String, style: String, style_sequence: int) -> Dictionary:
	return {
		"map_id": map_id,
		"public_name": "nomansland%s-%d" % [style, style_sequence],
		"family": "nomansland",
		"style": style,
		"style_sequence": style_sequence,
		"sequence": style_sequence,
		"status": "active"
	}

static func is_map_path_allowed(path: String) -> bool:
	return is_map_id_allowed(map_id_from_path(path))

static func is_map_id_allowed(map_id: String) -> bool:
	if not _is_sandbox_enabled():
		return true
	var normalized: String = map_id_from_input(map_id).to_upper()
	for allow_any in SANDBOX_ALLOWED_MAP_IDS:
		if normalized == str(allow_any).to_upper():
			return true
	if has_public_map_alias_for_id(normalized):
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

static func _fallback_public_map_name(raw_id: String) -> String:
	var clean_id: String = map_id_from_input(raw_id)
	var body: String = clean_id.trim_prefix("MAP_").strip_edges()
	if body.is_empty():
		return clean_id.to_lower()
	var family: String = _public_family_from_id(raw_id)
	if family == "nomansland":
		var style: String = _nomansland_public_style_for_id(raw_id)
		if not style.is_empty():
			var nomansland_name: String = _fallback_nomansland_public_map_name(clean_id, style)
			if not nomansland_name.is_empty():
				return nomansland_name
	var tokens: PackedStringArray = body.split("__", false)
	if tokens.is_empty():
		return body.replace("__", "_").replace(" ", "").strip_edges().to_lower()
	family = str(tokens[0]).strip_edges().to_lower()
	if family.is_empty():
		family = _public_family_from_id(raw_id)
	if family.is_empty():
		family = "map"
	var suffix_tokens: Array[String] = []
	for token_any in tokens:
		var raw_token: String = str(token_any)
		var fallback_token: String = _fallback_public_name_token(raw_token)
		if fallback_token.is_empty():
			continue
		if fallback_token == family:
			continue
		suffix_tokens.append(fallback_token)
	if suffix_tokens.is_empty():
		return family
	return "%s_%s" % [family, "_".join(suffix_tokens)]

static func _fallback_public_name_token(raw_token: String) -> String:
	var token: String = raw_token.strip_edges().to_lower()
	if token.is_empty():
		return ""
	if token == "map":
		return ""
	if ALLOWED_MODES.has(token):
		return ""
	if token == "sbase":
		return ""
	if token == "gbase":
		return ""
	if token.begins_with("start_v"):
		var start_digits: String = _leading_digits(token.substr(7))
		if not start_digits.is_empty():
			return "v%s" % start_digits
	if token.begins_with("v"):
		var version_digits: String = _leading_digits(token.substr(1))
		if not version_digits.is_empty():
			return "v%s" % version_digits
	if token.begins_with("sn") and _is_digits(token.substr(2)):
		return token
	var cleaned: String = ""
	var last_was_separator: bool = false
	for i in range(token.length()):
		var codepoint: int = token.unicode_at(i)
		var is_digit: bool = codepoint >= 48 and codepoint <= 57
		var is_lower_alpha: bool = codepoint >= 97 and codepoint <= 122
		if is_digit or is_lower_alpha:
			cleaned += char(codepoint)
			last_was_separator = false
			continue
		if codepoint == 95:
			if last_was_separator:
				continue
			cleaned += "_"
			last_was_separator = true
	return cleaned.strip_edges().trim_suffix("_")

static func _leading_digits(text: String) -> String:
	var digits: String = ""
	for i in range(text.length()):
		var codepoint: int = text.unicode_at(i)
		if codepoint < 48 or codepoint > 57:
			break
		digits += char(codepoint)
	return digits

static func _nomansland_public_style_for_id(raw_id: String) -> String:
	var clean_id: String = map_id_from_input(raw_id).to_lower()
	if clean_id.is_empty() or not clean_id.begins_with("map_nomansland__"):
		return ""
	if clean_id.contains("__323__"):
		return "323"
	if clean_id.contains("__444__"):
		return "444"
	if clean_id.contains("__545__"):
		return "545"
	return "656"

static func _public_style_sort_rank(family: String, style: String) -> int:
	if family != "nomansland":
		return 999
	match style:
		"656":
			return 1
		"545":
			return 2
		"323":
			return 3
		"444":
			return 4
		_:
			return 999

static func _fallback_nomansland_public_map_name(clean_id: String, style: String) -> String:
	var tokens: PackedStringArray = clean_id.trim_prefix("MAP_").split("__", false)
	if tokens.is_empty():
		return ""
	var base_id: String = clean_id
	var suffix_tokens: Array[String] = []
	if style == "545" or style == "323":
		if tokens.size() >= 4:
			base_id = "MAP_%s__%s__%s__%s" % [tokens[0], tokens[1], tokens[2], tokens[tokens.size() - 1]]
			for i in range(3, tokens.size() - 1):
				suffix_tokens.append(_fallback_public_name_token(str(tokens[i])))
	elif tokens.size() >= 4 and str(tokens[2]).to_lower() == "1p":
		base_id = "MAP_%s__%s__%s__%s" % [tokens[0], tokens[1], tokens[2], tokens[3]]
		for i in range(4, tokens.size()):
			suffix_tokens.append(_fallback_public_name_token(str(tokens[i])))
	var style_sequence: int = _public_nomansland_style_sequence_for_id(base_id, style)
	var suffix_parts: Array[String] = []
	for token_any in suffix_tokens:
		var token: String = str(token_any).strip_edges().to_lower()
		if token.is_empty():
			continue
		suffix_parts.append(token)
	var base_name: String = "nomansland%s" % style
	if style_sequence > 0:
		base_name = "%s-%d" % [base_name, style_sequence]
	if suffix_parts.is_empty():
		return base_name
	return "%s-%s" % [base_name, "-".join(suffix_parts)]

static func _public_nomansland_style_sequence_for_id(map_id: String, style: String) -> int:
	var raw_id: String = map_id_from_input(map_id)
	var sequence: int = 0
	for key_any in PUBLIC_NOMANSLAND_SEQUENCE_IDS:
		var key: String = str(key_any)
		if _nomansland_public_style_for_id(key) != style:
			continue
		sequence += 1
		if key.to_upper() == raw_id.to_upper():
			return sequence
	return 0

static func _public_family_from_id(raw_id: String) -> String:
	var normalized: Dictionary = normalize_map_id(raw_id)
	if bool(normalized.get("ok", false)):
		return str(normalized.get("family", "")).strip_edges().to_lower()
	var clean: String = map_id_from_input(raw_id)
	if clean.begins_with("MAP_"):
		var body: String = clean.trim_prefix("MAP_")
		var tokens: PackedStringArray = body.split("__", false)
		if tokens.size() > 0:
			return str(tokens[0]).strip_edges().to_lower()
	return ""

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

static func _is_sandbox_enabled() -> bool:
	if not SANDBOX_ENABLED:
		return false
	var override_raw: String = OS.get_environment(SANDBOX_ENV_VAR).strip_edges().to_lower()
	if override_raw.is_empty():
		return true
	match override_raw:
		"0", "false", "off", "disable", "disabled", "all":
			return false
		_:
			return true
