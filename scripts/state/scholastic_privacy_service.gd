class_name ScholasticPrivacyService
extends RefCounted

const ScholasticTypesScript = preload("res://scripts/state/scholastic_types.gd")
const RecruitingProfileScript = preload("res://scripts/state/recruiting_profile.gd")

static func communication_access_for_profile(player_profile: Dictionary) -> Dictionary:
	var age_years: int = int(player_profile.get("age_years", -1))
	var ecosystem: String = str(player_profile.get("ecosystem", ScholasticTypesScript.ECOSYSTEM_NONE))
	var sfa: Dictionary = player_profile.get("sfa", {}) as Dictionary
	var is_sfa_user: bool = ecosystem == ScholasticTypesScript.ECOSYSTEM_SFA or bool(sfa.get("is_user", false))
	var is_minor: bool = ScholasticTypesScript.is_minor_age(age_years)
	if is_sfa_user or is_minor:
		return {
			"dm_enabled": false,
			"in_game_chat_enabled": false,
			"private_messaging_enabled": false,
			"voice_enabled": false,
			"reason": "sfa_minor_restriction"
		}
	return {
		"dm_enabled": true,
		"in_game_chat_enabled": true,
		"private_messaging_enabled": true,
		"voice_enabled": true,
		"reason": "adult_default"
	}

static func real_money_prize_access_for_profile(player_profile: Dictionary) -> Dictionary:
	var age_years: int = int(player_profile.get("age_years", -1))
	var sfa: Dictionary = player_profile.get("sfa", {}) as Dictionary
	var is_sfa_user: bool = bool(sfa.get("is_user", false)) or ScholasticTypesScript.is_minor_age(age_years)
	return {
		"can_win_real_money": not is_sfa_user,
		"can_accrue_sfa_progression_from_public_money_games": false if is_sfa_user else true,
		"reason": "sfa_minor_real_money_restriction" if is_sfa_user else "adult_default"
	}

static func build_safe_recruiting_profile(
		player_profile: Dictionary,
		school_program: Dictionary = {},
		college_program: Dictionary = {}
	) -> Dictionary:
	var safe_profile: Dictionary = RecruitingProfileScript.build_safe_profile(player_profile, school_program, college_program)
	safe_profile.erase("email")
	safe_profile.erase("phone")
	safe_profile.erase("private_contact")
	return safe_profile
