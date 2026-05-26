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
const SFA_MAX_SCHOOL_YEARS: int = 4
const MINOR_AGE_CUTOFF: int = 18
const DEFAULT_MMR: float = 1000.0

const SFA_STATUS_UNKNOWN: String = "UNKNOWN"
const SFA_STATUS_AWAITING_SCHOOL: String = "AWAITING_SCHOOL"
const SFA_STATUS_ACTIVE: String = "ACTIVE"
const SFA_STATUS_EXPIRED: String = "EXPIRED"
const SFA_STATUS_TRANSITIONED: String = "TRANSITIONED"
const SFA_STATUS_ADULT: String = "ADULT"

const SFU_STATUS_UNKNOWN: String = "UNKNOWN"
const SFU_STATUS_CANDIDATE: String = "CANDIDATE"
const SFU_STATUS_ACTIVE: String = "ACTIVE"
const SFU_STATUS_ALUMNI: String = "ALUMNI"
const SFU_STATUS_EXPIRED: String = "EXPIRED"
const SFU_STATUS_OPEN_ADULT: String = "OPEN_ADULT"

const SCHOOL_HIVE_REVIEW_SELF_REPORTED: String = "SELF_REPORTED"
const SCHOOL_HIVE_REVIEW_PENDING: String = "PENDING_REVIEW"
const SCHOOL_HIVE_REVIEW_APPROVED: String = "APPROVED"
const SCHOOL_HIVE_REVIEW_REJECTED: String = "REJECTED"
const SCHOOL_HIVE_REVIEW_DISPUTED: String = "DISPUTED"
const SCHOOL_HIVE_REVIEW_EXPIRED: String = "EXPIRED"

const SCHOOL_PUBLIC_NAME_PENDING: String = "Pending School"
const SFA_ANALYTICS_PACKAGE_TIER_1: String = "analytics_pack_tier_1"

const SFU_TOURNAMENT_CAMPUS: String = "CAMPUS"
const SFU_TOURNAMENT_RIVALRY: String = "RIVALRY"
const SFU_TOURNAMENT_REGIONAL: String = "REGIONAL"
const SFU_TOURNAMENT_NATIONAL: String = "NATIONAL"
const SFU_TOURNAMENT_OPEN: String = "OPEN"

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

const SFU_TOURNAMENT_TYPES: Array[String] = [
	SFU_TOURNAMENT_CAMPUS,
	SFU_TOURNAMENT_RIVALRY,
	SFU_TOURNAMENT_REGIONAL,
	SFU_TOURNAMENT_NATIONAL,
	SFU_TOURNAMENT_OPEN
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

static func current_school_year() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var year: int = int(now.get("year", 0))
	var month: int = int(now.get("month", 1))
	var start_year: int = year if month >= 8 else year - 1
	return school_year_from_start_year(start_year)

static func school_year_from_start_year(start_year: int) -> String:
	var clean_start: int = maxi(1900, start_year)
	return "%04d-%04d" % [clean_start, clean_start + 1]

static func school_year_start_year(school_year: String) -> int:
	var normalized: String = normalize_school_year(school_year)
	if normalized.length() < 4:
		return 0
	return int(normalized.substr(0, 4))

static func normalize_school_year(school_year: String) -> String:
	var trimmed: String = school_year.strip_edges()
	if trimmed.is_empty():
		return current_school_year()
	trimmed = trimmed.replace("/", "-")
	trimmed = trimmed.replace("_", "-")
	var parts: PackedStringArray = trimmed.split("-", false)
	var start_year: int = 0
	if parts.size() >= 1:
		start_year = int(str(parts[0]).strip_edges())
	if start_year <= 0:
		return current_school_year()
	if parts.size() >= 2:
		var end_raw: String = str(parts[1]).strip_edges()
		var end_year: int = int(end_raw)
		if end_raw.length() == 2:
			end_year = int("%02d%02d" % [int(start_year / 100), end_year])
		if end_year != start_year + 1:
			return school_year_from_start_year(start_year)
	return school_year_from_start_year(start_year)

static func sfa_eligibility_end_start_year(freshman_school_year: String) -> int:
	var freshman_start: int = school_year_start_year(freshman_school_year)
	if freshman_start <= 0:
		return 0
	return freshman_start + SFA_MAX_SCHOOL_YEARS

static func is_school_year_sfa_eligible(freshman_school_year: String, attested_school_year: String) -> bool:
	var freshman_start: int = school_year_start_year(freshman_school_year)
	var attested_start: int = school_year_start_year(attested_school_year)
	if freshman_start <= 0 or attested_start <= 0:
		return false
	if attested_start < freshman_start:
		return false
	return attested_start < freshman_start + SFA_MAX_SCHOOL_YEARS

static func public_school_name(program: Dictionary) -> String:
	var review_status: String = str(program.get("school_hive_review_status", SCHOOL_HIVE_REVIEW_SELF_REPORTED)).strip_edges().to_upper()
	if review_status != SCHOOL_HIVE_REVIEW_APPROVED:
		return SCHOOL_PUBLIC_NAME_PENDING
	var name: String = clean_text(str(program.get("canonical_school_name", "")), 96)
	if name.is_empty():
		name = clean_text(str(program.get("school_name", "")), 96)
	return SCHOOL_PUBLIC_NAME_PENDING if name.is_empty() else name

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

static func is_valid_sfu_tournament_type(tournament_type: String) -> bool:
	return SFU_TOURNAMENT_TYPES.has(tournament_type.strip_edges().to_upper())

static func normalize_sfu_tournament_type(tournament_type: String) -> String:
	var normalized: String = tournament_type.strip_edges().to_upper()
	if is_valid_sfu_tournament_type(normalized):
		return normalized
	return SFU_TOURNAMENT_CAMPUS

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
