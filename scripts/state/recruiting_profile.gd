class_name RecruitingProfile
extends RefCounted

const ScholasticTypesScript = preload("res://scripts/state/scholastic_types.gd")

static func build_safe_profile(
		player_profile: Dictionary,
		school_program: Dictionary = {},
		college_program: Dictionary = {}
	) -> Dictionary:
	var scholastic: Dictionary = player_profile.get("scholastic", {}) as Dictionary
	var competitive: Dictionary = player_profile.get("competitive", {}) as Dictionary
	var sfu: Dictionary = player_profile.get("sfu", {}) as Dictionary
	var school_name: String = str(school_program.get("school_name", ""))
	var university_name: String = str(college_program.get("university_name", ""))
	return {
		"player_id": str(player_profile.get("player_id", "")),
		"display_name": str(player_profile.get("display_name", "")),
		"school": school_name,
		"university": university_name,
		"graduation_year": int(scholastic.get("graduation_year", 0)),
		"rank_position": int(competitive.get("rank_position", 0)),
		"tier_id": str(competitive.get("tier_id", "")),
		"tier_index": int(competitive.get("tier_index", 0)),
		"mmr": float(competitive.get("mmr", ScholasticTypesScript.DEFAULT_MMR)),
		"role_tags": (scholastic.get("role_tags", []) as Array).duplicate(true),
		"playstyle_tags": (scholastic.get("playstyle_tags", []) as Array).duplicate(true),
		"tournament_results": (scholastic.get("tournament_results", []) as Array).duplicate(true),
		"awards": (scholastic.get("awards", []) as Array).duplicate(true),
		"highlight_replay_ids": (scholastic.get("highlight_replay_ids", []) as Array).duplicate(true),
		"recruiting_status": ScholasticTypesScript.normalize_recruiting_status(str(sfu.get("recruiting_status", ""))),
		"contact": {}
	}
