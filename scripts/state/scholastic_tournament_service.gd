class_name ScholasticTournamentService
extends RefCounted

const ScholasticTypesScript = preload("res://scripts/state/scholastic_types.gd")

static func new_sfa_tournament(tournament_id: String, tournament_type: String, title: String = "") -> Dictionary:
	var normalized_type: String = ScholasticTypesScript.normalize_sfa_tournament_type(tournament_type)
	var clean_id: String = ScholasticTypesScript.normalize_id(tournament_id)
	if clean_id.is_empty():
		clean_id = ScholasticTypesScript.normalize_id("%s_%d" % [normalized_type, Time.get_unix_time_from_system()])
	return {
		"tournament_id": clean_id,
		"ecosystem": ScholasticTypesScript.ECOSYSTEM_SFA,
		"tournament_type": normalized_type,
		"title": ScholasticTypesScript.clean_text(title, 96),
		"real_money_prizes_allowed": false,
		"counts_for_sfa_progression": true,
		"requires_school_or_guardian_review": true,
		"created_at_unix": int(Time.get_unix_time_from_system())
	}

static func new_sfu_tournament(tournament_id: String, tournament_type: String, title: String = "", config: Dictionary = {}) -> Dictionary:
	var normalized_type: String = ScholasticTypesScript.normalize_sfu_tournament_type(tournament_type)
	var clean_id: String = ScholasticTypesScript.normalize_id(tournament_id)
	if clean_id.is_empty():
		clean_id = ScholasticTypesScript.normalize_id("sfu_%s_%d" % [normalized_type, Time.get_unix_time_from_system()])
	return {
		"tournament_id": clean_id,
		"ecosystem": ScholasticTypesScript.ECOSYSTEM_SFU,
		"tournament_type": normalized_type,
		"title": ScholasticTypesScript.clean_text(title, 96),
		"buffs_allowed": bool(config.get("buffs_allowed", false)),
		"cash_prizes_allowed": bool(config.get("cash_prizes_allowed", false)),
		"entry_fee_allowed": bool(config.get("entry_fee_allowed", false)),
		"program_roster_required": bool(config.get("program_roster_required", true)),
		"official_sfu_event": bool(config.get("official_sfu_event", true)),
		"adult_only": true,
		"created_at_unix": int(Time.get_unix_time_from_system())
	}

static func is_sfa_progression_result_eligible(result: Dictionary) -> bool:
	if bool(result.get("is_money_game", false)):
		return false
	if bool(result.get("awards_real_money", false)):
		return false
	if bool(result.get("public_adult_money_game", false)):
		return false
	var tournament_type: String = str(result.get("tournament_type", ""))
	if tournament_type.is_empty():
		return false
	return ScholasticTypesScript.is_valid_sfa_tournament_type(tournament_type)

static func is_sfu_result_eligible(player_profile: Dictionary, tournament: Dictionary, result: Dictionary) -> bool:
	if int(player_profile.get("age_years", -1)) < ScholasticTypesScript.MINOR_AGE_CUTOFF:
		return false
	var sfu: Dictionary = player_profile.get("sfu", {}) as Dictionary
	if bool(tournament.get("program_roster_required", true)) and not bool(sfu.get("program_affiliation_attested", false)):
		return false
	if not bool(tournament.get("buffs_allowed", false)) and bool(result.get("buffs_used", false)):
		return false
	if not bool(tournament.get("cash_prizes_allowed", false)) and bool(result.get("awards_real_money", false)):
		return false
	return str(tournament.get("ecosystem", "")) == ScholasticTypesScript.ECOSYSTEM_SFU
