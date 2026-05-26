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
			"eligibility_status": ScholasticTypesScript.SFA_STATUS_UNKNOWN,
			"eligible_for_school_team": false,
			"school_id": "",
			"current_school_year_attested": "",
			"freshman_school_year": "",
			"sfa_eligibility_end_start_year": 0,
			"school_enrollment_attested": false,
			"school_enrollment_attested_at_unix": 0,
			"school_attestation_expires_school_year": "",
			"transition_status": ScholasticTypesScript.SFA_STATUS_UNKNOWN,
			"team_id": "",
			"team_index": -1,
			"team_label": "",
			"roster_slot": -1,
			"analytics_package_entitlements": [],
			"real_money_prize_eligible": true,
			"sfa_progression_locked_from_adult_money_games": false
		},
		"sfu": {
			"college_program_id": "",
			"college_team_id": "",
			"program_affiliation_attested": false,
			"program_affiliation_attested_at_unix": 0,
			"affiliation_school_year": "",
			"sfu_status": ScholasticTypesScript.SFU_STATUS_UNKNOWN,
			"recruiting_status": ScholasticTypesScript.RECRUITING_NOT_RECRUITABLE,
			"normal_comms_allowed": true,
			"normal_money_games_allowed": true,
			"normal_buffs_allowed": true
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
	var freshman_school_year: String = ScholasticTypesScript.normalize_school_year(str(sfa.get("freshman_school_year", ""))) if not str(sfa.get("freshman_school_year", "")).strip_edges().is_empty() else ""
	var attested_school_year: String = ScholasticTypesScript.normalize_school_year(str(sfa.get("current_school_year_attested", ""))) if not str(sfa.get("current_school_year_attested", "")).strip_edges().is_empty() else ""
	sfa["freshman_school_year"] = freshman_school_year
	sfa["current_school_year_attested"] = attested_school_year
	sfa["sfa_eligibility_end_start_year"] = ScholasticTypesScript.sfa_eligibility_end_start_year(freshman_school_year) if not freshman_school_year.is_empty() else 0
	var has_school_attestation: bool = not str(sfa.get("school_id", "")).is_empty() and bool(sfa.get("school_enrollment_attested", false)) and not attested_school_year.is_empty()
	var within_sfa_window: bool = true
	if has_school_attestation and not freshman_school_year.is_empty():
		within_sfa_window = ScholasticTypesScript.is_school_year_sfa_eligible(freshman_school_year, attested_school_year)
	sfa["is_user"] = is_minor and has_school_attestation and within_sfa_window
	if is_minor and not has_school_attestation:
		sfa["eligibility_status"] = ScholasticTypesScript.SFA_STATUS_AWAITING_SCHOOL
		sfa["transition_status"] = ScholasticTypesScript.SFA_STATUS_AWAITING_SCHOOL
	elif is_minor and not within_sfa_window:
		sfa["eligibility_status"] = ScholasticTypesScript.SFA_STATUS_EXPIRED
		sfa["transition_status"] = ScholasticTypesScript.SFA_STATUS_EXPIRED
	elif bool(sfa.get("is_user", false)):
		sfa["eligibility_status"] = ScholasticTypesScript.SFA_STATUS_ACTIVE
		sfa["transition_status"] = ScholasticTypesScript.SFA_STATUS_ACTIVE
	elif not is_minor and str(sfa.get("transition_status", "")) != ScholasticTypesScript.SFA_STATUS_TRANSITIONED:
		sfa["eligibility_status"] = ScholasticTypesScript.SFA_STATUS_ADULT
		sfa["transition_status"] = ScholasticTypesScript.SFA_STATUS_ADULT
	if bool(sfa.get("is_user", false)):
		sfa["real_money_prize_eligible"] = false
		sfa["sfa_progression_locked_from_adult_money_games"] = true
		var analytics_entitlements: Array = sfa.get("analytics_package_entitlements", []) as Array
		if not analytics_entitlements.has(ScholasticTypesScript.SFA_ANALYTICS_PACKAGE_TIER_1):
			analytics_entitlements.append(ScholasticTypesScript.SFA_ANALYTICS_PACKAGE_TIER_1)
		sfa["analytics_package_entitlements"] = analytics_entitlements
	elif is_minor:
		sfa["real_money_prize_eligible"] = false
		sfa["sfa_progression_locked_from_adult_money_games"] = true
	profile["sfa"] = sfa
	var privacy: Dictionary = profile.get("privacy", {}) as Dictionary
	privacy["is_minor"] = is_minor
	privacy["safe_public_profile_only"] = is_minor or bool(privacy.get("safe_public_profile_only", true))
	profile["privacy"] = privacy
	var sfu: Dictionary = profile.get("sfu", {}) as Dictionary
	sfu["recruiting_status"] = ScholasticTypesScript.normalize_recruiting_status(str(sfu.get("recruiting_status", "")))
	sfu["normal_comms_allowed"] = not is_minor
	sfu["normal_money_games_allowed"] = not is_minor
	sfu["normal_buffs_allowed"] = true
	if is_minor:
		sfu["sfu_status"] = ScholasticTypesScript.SFU_STATUS_UNKNOWN
	elif bool(sfu.get("program_affiliation_attested", false)) and not str(sfu.get("college_program_id", "")).is_empty():
		if str(sfu.get("sfu_status", ScholasticTypesScript.SFU_STATUS_UNKNOWN)) not in [ScholasticTypesScript.SFU_STATUS_ALUMNI, ScholasticTypesScript.SFU_STATUS_EXPIRED]:
			sfu["sfu_status"] = ScholasticTypesScript.SFU_STATUS_ACTIVE
	profile["sfu"] = sfu
	return profile
