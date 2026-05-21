class_name SchoolTeam
extends RefCounted

const ScholasticTypesScript = preload("res://scripts/state/scholastic_types.gd")

static func new_school_team(school_id: String, team_index: int) -> Dictionary:
	var clean_school_id: String = ScholasticTypesScript.normalize_id(school_id)
	var clean_index: int = maxi(0, team_index)
	return {
		"team_id": ScholasticTypesScript.school_team_id(clean_school_id, clean_index),
		"school_id": clean_school_id,
		"team_index": clean_index,
		"team_label": ScholasticTypesScript.school_team_label(clean_index),
		"roster_limit": ScholasticTypesScript.SFA_ROSTER_BLOCK_SIZE,
		"roster": [],
		"created_by_assignment_service": true
	}
