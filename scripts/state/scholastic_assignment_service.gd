class_name ScholasticAssignmentService
extends RefCounted

const ScholasticTypesScript = preload("res://scripts/state/scholastic_types.gd")
const SchoolTeamScript = preload("res://scripts/state/school_team.gd")

static func recalculate_school_teams(school_program: Dictionary, player_profiles: Array) -> Dictionary:
	var school_id: String = ScholasticTypesScript.normalize_id(str(school_program.get("school_id", "")))
	var eligible_players: Array[Dictionary] = []
	for profile_any in player_profiles:
		if typeof(profile_any) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = profile_any as Dictionary
		var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
		if ScholasticTypesScript.normalize_id(str(sfa.get("school_id", ""))) != school_id:
			continue
		if not bool(sfa.get("is_user", false)):
			continue
		if not bool(sfa.get("eligible_for_school_team", false)):
			continue
		eligible_players.append(profile.duplicate(true))

	eligible_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _compare_assignment_profiles(a, b)
	)

	var teams: Array[Dictionary] = []
	var membership_by_player_id: Dictionary = {}
	for index: int in range(eligible_players.size()):
		var team_index: int = int(index / ScholasticTypesScript.SFA_ROSTER_BLOCK_SIZE)
		while teams.size() <= team_index:
			teams.append(SchoolTeamScript.new_school_team(school_id, teams.size()))
		var team: Dictionary = teams[team_index]
		var profile_for_slot: Dictionary = eligible_players[index]
		var roster_slot: int = index % ScholasticTypesScript.SFA_ROSTER_BLOCK_SIZE
		var player_id: String = str(profile_for_slot.get("player_id", ""))
		var competitive: Dictionary = profile_for_slot.get("competitive", {}) as Dictionary
		var roster_entry: Dictionary = {
			"player_id": player_id,
			"display_name": str(profile_for_slot.get("display_name", "")),
			"roster_slot": roster_slot,
			"rank_position": int(competitive.get("rank_position", 0)),
			"tier_id": str(competitive.get("tier_id", "")),
			"tier_index": int(competitive.get("tier_index", 0)),
			"mmr": float(competitive.get("mmr", ScholasticTypesScript.DEFAULT_MMR)),
			"assignment_score": assignment_score(profile_for_slot)
		}
		var roster: Array = team.get("roster", []) as Array
		roster.append(roster_entry)
		team["roster"] = roster
		teams[team_index] = team
		membership_by_player_id[player_id] = {
			"school_id": school_id,
			"team_id": str(team.get("team_id", "")),
			"team_index": team_index,
			"team_label": str(team.get("team_label", "")),
			"roster_slot": roster_slot
		}

	var out: Dictionary = school_program.duplicate(true)
	out["teams"] = teams
	out["membership_by_player_id"] = membership_by_player_id
	return out

static func assignment_score(profile: Dictionary) -> float:
	var competitive: Dictionary = profile.get("competitive", {}) as Dictionary
	var mmr: float = float(competitive.get("mmr", ScholasticTypesScript.DEFAULT_MMR))
	var tier_index: int = int(competitive.get("tier_index", 0))
	var rank_position: int = int(competitive.get("rank_position", 0))
	var rank_score: float = 0.0
	if rank_position > 0:
		rank_score = maxf(0.0, 100000.0 - float(rank_position))
	return mmr + (float(tier_index) * 10000.0) + rank_score

static func _compare_assignment_profiles(a: Dictionary, b: Dictionary) -> bool:
	var score_a: float = assignment_score(a)
	var score_b: float = assignment_score(b)
	if not is_equal_approx(score_a, score_b):
		return score_a > score_b
	return str(a.get("display_name", "")) < str(b.get("display_name", ""))
