class_name ScholasticProfile
extends RefCounted

const ScholasticTypesScript = preload("res://scripts/state/scholastic_types.gd")

static func new_profile(player_id: String, display_name: String = "") -> Dictionary:
	var clean_id: String = ScholasticTypesScript.normalize_id(player_id)
	var clean_name: String = ScholasticTypesScript.clean_text(display_name, 32)
	if clean_name.is_empty():
		clean_name = clean_id
	return {
		"player_id": clean_id,
		"display_name": clean_name,
		"age_years": -1,
		"ecosystem": ScholasticTypesScript.ECOSYSTEM_NONE,
		"sfa": {
			"is_candidate": false,
			"is_user": false,
			"eligibility_status": "UNKNOWN",
			"eligible_for_school_team": false,
			"school_id": "",
			"team_id": "",
			"team_index": -1,
			"team_label": "",
			"roster_slot": -1,
			"real_money_prize_eligible": true,
			"sfa_progression_locked_from_adult_money_games": false
		},
		"sfu": {
			"college_program_id": "",
			"college_team_id": "",
			"recruiting_status": ScholasticTypesScript.RECRUITING_NOT_RECRUITABLE
		},
		"competitive": default_competitive_profile(),
		"scholastic": {
			"graduation_year": 0,
			"role_tags": [],
			"playstyle_tags": [],
			"awards": [],
			"highlight_replay_ids": [],
			"tournament_results": []
		},
		"privacy": {
			"is_minor": false,
			"safe_public_profile_only": true,
			"parent_guardian_contact_hook": "",
			"coach_contact_hook": ""
		}
	}

static func default_competitive_profile() -> Dictionary:
	return {
		"rank_position": 0,
		"tier_id": "",
		"tier_index": 0,
		"mmr": ScholasticTypesScript.DEFAULT_MMR,
		"rank_source": "LOCAL_PLACEHOLDER",
		"updated_at_unix": 0
	}

static func normalize_profile(raw_profile: Dictionary) -> Dictionary:
	var player_id: String = ScholasticTypesScript.normalize_id(str(raw_profile.get("player_id", "")))
	var profile: Dictionary = new_profile(player_id, str(raw_profile.get("display_name", player_id)))
	profile.merge(raw_profile, true)
	profile["player_id"] = player_id
	profile["display_name"] = ScholasticTypesScript.clean_text(str(profile.get("display_name", player_id)), 32)
	profile["age_years"] = int(profile.get("age_years", -1))
	var age_years: int = int(profile.get("age_years", -1))
	var is_minor: bool = ScholasticTypesScript.is_minor_age(age_years)
	if is_minor:
		profile["ecosystem"] = ScholasticTypesScript.ECOSYSTEM_SFA
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	sfa["is_candidate"] = is_minor or bool(sfa.get("is_candidate", false))
	sfa["is_user"] = is_minor or bool(sfa.get("is_user", false))
	if bool(sfa.get("is_user", false)):
		sfa["real_money_prize_eligible"] = false
		sfa["sfa_progression_locked_from_adult_money_games"] = true
	profile["sfa"] = sfa
	var privacy: Dictionary = profile.get("privacy", {}) as Dictionary
	privacy["is_minor"] = is_minor
	privacy["safe_public_profile_only"] = is_minor or bool(privacy.get("safe_public_profile_only", true))
	profile["privacy"] = privacy
	var sfu: Dictionary = profile.get("sfu", {}) as Dictionary
	sfu["recruiting_status"] = ScholasticTypesScript.normalize_recruiting_status(str(sfu.get("recruiting_status", "")))
	profile["sfu"] = sfu
	return profile
