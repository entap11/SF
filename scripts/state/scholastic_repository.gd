class_name ScholasticRepository
extends RefCounted

var profiles_by_player_id: Dictionary = {}
var school_programs_by_id: Dictionary = {}
var college_programs_by_id: Dictionary = {}
var sfa_tournaments_by_id: Dictionary = {}

func load_snapshot(snapshot: Dictionary) -> void:
	profiles_by_player_id = (snapshot.get("profiles_by_player_id", {}) as Dictionary).duplicate(true)
	school_programs_by_id = (snapshot.get("school_programs_by_id", {}) as Dictionary).duplicate(true)
	college_programs_by_id = (snapshot.get("college_programs_by_id", {}) as Dictionary).duplicate(true)
	sfa_tournaments_by_id = (snapshot.get("sfa_tournaments_by_id", {}) as Dictionary).duplicate(true)

func to_snapshot() -> Dictionary:
	return {
		"profiles_by_player_id": profiles_by_player_id.duplicate(true),
		"school_programs_by_id": school_programs_by_id.duplicate(true),
		"college_programs_by_id": college_programs_by_id.duplicate(true),
		"sfa_tournaments_by_id": sfa_tournaments_by_id.duplicate(true)
	}

func get_profile(player_id: String) -> Dictionary:
	return (profiles_by_player_id.get(player_id, {}) as Dictionary).duplicate(true)

func put_profile(player_id: String, profile: Dictionary) -> void:
	profiles_by_player_id[player_id] = profile.duplicate(true)

func get_school_program(school_id: String) -> Dictionary:
	return (school_programs_by_id.get(school_id, {}) as Dictionary).duplicate(true)

func put_school_program(school_id: String, program: Dictionary) -> void:
	school_programs_by_id[school_id] = program.duplicate(true)

func get_college_program(program_id: String) -> Dictionary:
	return (college_programs_by_id.get(program_id, {}) as Dictionary).duplicate(true)

func put_college_program(program_id: String, program: Dictionary) -> void:
	college_programs_by_id[program_id] = program.duplicate(true)

func put_sfa_tournament(tournament_id: String, tournament: Dictionary) -> void:
	sfa_tournaments_by_id[tournament_id] = tournament.duplicate(true)
