class_name ScholasticTypes
extends RefCounted

const ECOSYSTEM_NONE: String = "NONE"
const ECOSYSTEM_SFA: String = "SFA"
const ECOSYSTEM_SFU: String = "SFU"

const VERIFICATION_UNVERIFIED: String = "UNVERIFIED"
const VERIFICATION_PENDING: String = "PENDING"
const VERIFICATION_VERIFIED: String = "VERIFIED"
const VERIFICATION_REJECTED: String = "REJECTED"

const RECRUITING_NOT_RECRUITABLE: String = "NOT_RECRUITABLE"
const RECRUITING_SFA_RECRUITABLE: String = "SFA_RECRUITABLE"
const RECRUITING_COLLEGE_PLAYER: String = "COLLEGE_PLAYER"
const RECRUITING_TRANSFER_PORTAL: String = "TRANSFER_PORTAL"
const RECRUITING_ALUMNI: String = "ALUMNI"

const TOURNAMENT_SCHOOL_RIVALRY: String = "SCHOOL_RIVALRY"
const TOURNAMENT_REGIONAL: String = "REGIONAL"
const TOURNAMENT_NATIONAL: String = "NATIONAL"
const TOURNAMENT_INVITATIONAL: String = "INVITATIONAL"

const SFA_ROSTER_BLOCK_SIZE: int = 12
const MINOR_AGE_CUTOFF: int = 18
const DEFAULT_MMR: float = 1000.0

const RECRUITING_STATUSES: Array[String] = [
	RECRUITING_NOT_RECRUITABLE,
	RECRUITING_SFA_RECRUITABLE,
	RECRUITING_COLLEGE_PLAYER,
	RECRUITING_TRANSFER_PORTAL,
	RECRUITING_ALUMNI
]

const SFA_TOURNAMENT_TYPES: Array[String] = [
	TOURNAMENT_SCHOOL_RIVALRY,
	TOURNAMENT_REGIONAL,
	TOURNAMENT_NATIONAL,
	TOURNAMENT_INVITATIONAL
]

static func normalize_id(value: String) -> String:
	var out: String = value.strip_edges().to_lower()
	out = out.replace(" ", "_")
	out = out.replace("-", "_")
	out = out.replace("/", "_")
	out = out.replace("\\", "_")
	out = out.replace(".", "_")
	while out.find("__") >= 0:
		out = out.replace("__", "_")
	return out.strip_edges()

static func clean_text(value: String, max_len: int = 80) -> String:
	var out: String = value.strip_edges()
	if max_len > 0 and out.length() > max_len:
		out = out.substr(0, max_len)
	return out

static func sanitize_colors(raw_colors: Array) -> Array[String]:
	var out: Array[String] = []
	for color_any in raw_colors:
		var color: String = clean_text(str(color_any), 24)
		if color.is_empty():
			continue
		if out.has(color):
			continue
		out.append(color)
		if out.size() >= 4:
			break
	return out

static func is_minor_age(age_years: int) -> bool:
	return age_years >= 0 and age_years < MINOR_AGE_CUTOFF

static func classify_age(age_years: int) -> String:
	if is_minor_age(age_years):
		return ECOSYSTEM_SFA
	return ECOSYSTEM_NONE

static func is_valid_recruiting_status(status: String) -> bool:
	return RECRUITING_STATUSES.has(status.strip_edges().to_upper())

static func normalize_recruiting_status(status: String) -> String:
	var normalized: String = status.strip_edges().to_upper()
	if is_valid_recruiting_status(normalized):
		return normalized
	return RECRUITING_NOT_RECRUITABLE

static func is_valid_sfa_tournament_type(tournament_type: String) -> bool:
	return SFA_TOURNAMENT_TYPES.has(tournament_type.strip_edges().to_upper())

static func normalize_sfa_tournament_type(tournament_type: String) -> String:
	var normalized: String = tournament_type.strip_edges().to_upper()
	if is_valid_sfa_tournament_type(normalized):
		return normalized
	return TOURNAMENT_SCHOOL_RIVALRY

static func school_team_label(team_index: int) -> String:
	if team_index <= 0:
		return "Varsity"
	if team_index == 1:
		return "JV"
	return "JV%s" % _roman(maxi(2, team_index))

static func school_team_id(school_id: String, team_index: int) -> String:
	return "%s_team_%02d" % [normalize_id(school_id), maxi(0, team_index)]

static func _roman(value: int) -> String:
	var n: int = maxi(1, value)
	var parts: PackedStringArray = PackedStringArray()
	var table: Array[Dictionary] = [
		{"value": 10, "symbol": "X"},
		{"value": 9, "symbol": "IX"},
		{"value": 5, "symbol": "V"},
		{"value": 4, "symbol": "IV"},
		{"value": 1, "symbol": "I"}
	]
	for entry_any in table:
		var entry: Dictionary = entry_any as Dictionary
		while n >= int(entry.get("value", 1)):
			parts.append(str(entry.get("symbol", "I")))
			n -= int(entry.get("value", 1))
	return "".join(parts)
