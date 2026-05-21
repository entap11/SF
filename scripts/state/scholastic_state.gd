extends Node

const ScholasticTypesScript = preload("res://scripts/state/scholastic_types.gd")
const ScholasticProfileScript = preload("res://scripts/state/scholastic_profile.gd")
const SchoolProgramScript = preload("res://scripts/state/school_program.gd")
const CollegeProgramScript = preload("res://scripts/state/college_program.gd")
const ScholasticAssignmentServiceScript = preload("res://scripts/state/scholastic_assignment_service.gd")
const ScholasticPrivacyServiceScript = preload("res://scripts/state/scholastic_privacy_service.gd")
const ScholasticTournamentServiceScript = preload("res://scripts/state/scholastic_tournament_service.gd")
const ScholasticRepositoryScript = preload("res://scripts/state/scholastic_repository.gd")

signal scholastic_state_changed(snapshot: Dictionary)
signal scholastic_event(event: Dictionary)

const SAVE_PATH: String = "user://scholastic_state.json"
const SAVE_SCHEMA_VERSION: int = 1

var save_path: String = SAVE_PATH
var _repository = ScholasticRepositoryScript.new()

func _ready() -> void:
	_load_state()
	_emit_changed()

func get_snapshot() -> Dictionary:
	var repo_snapshot: Dictionary = _repository.to_snapshot()
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"ecosystems": {
			"sfa": "Swarmfront Academy",
			"sfu": "Swarmfront University"
		},
		"communication_policy": {
			"sfa_minors": "NO_DM_NO_CHAT_NO_PRIVATE_MESSAGE_NO_VOICE"
		},
		"money_policy": {
			"sfa_real_money_prizes_allowed": false,
			"sfa_progression_from_public_adult_money_games": false
		},
		"repository": repo_snapshot,
		"sfa_tournament_types": ScholasticTypesScript.SFA_TOURNAMENT_TYPES.duplicate()
	}

func get_player_profile_snapshot(player_id: String) -> Dictionary:
	var clean_id: String = ScholasticTypesScript.normalize_id(player_id)
	if clean_id.is_empty():
		return {}
	return _repository.get_profile(clean_id)

func get_school_program_snapshot(school_id: String) -> Dictionary:
	var clean_id: String = ScholasticTypesScript.normalize_id(school_id)
	if clean_id.is_empty():
		return {}
	return _repository.get_school_program(clean_id)

func get_college_program_snapshot(program_id: String) -> Dictionary:
	var clean_id: String = ScholasticTypesScript.normalize_id(program_id)
	if clean_id.is_empty():
		return {}
	return _repository.get_college_program(clean_id)

func get_communication_access(player_id: String) -> Dictionary:
	var profile: Dictionary = get_player_profile_snapshot(player_id)
	if profile.is_empty():
		return ScholasticPrivacyServiceScript.communication_access_for_profile({})
	return ScholasticPrivacyServiceScript.communication_access_for_profile(profile)

func get_real_money_prize_access(player_id: String) -> Dictionary:
	var profile: Dictionary = get_player_profile_snapshot(player_id)
	if profile.is_empty():
		return {"can_win_real_money": true, "can_accrue_sfa_progression_from_public_money_games": true, "reason": "profile_not_found"}
	return ScholasticPrivacyServiceScript.real_money_prize_access_for_profile(profile)

func get_safe_recruiting_profile(player_id: String) -> Dictionary:
	var profile: Dictionary = get_player_profile_snapshot(player_id)
	if profile.is_empty():
		return {}
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	var sfu: Dictionary = profile.get("sfu", {}) as Dictionary
	var school: Dictionary = _repository.get_school_program(str(sfa.get("school_id", "")))
	var college: Dictionary = _repository.get_college_program(str(sfu.get("college_program_id", "")))
	return ScholasticPrivacyServiceScript.build_safe_recruiting_profile(profile, school, college)

func intent_report_age(player_id: String, age_years: int, display_name: String = "") -> Dictionary:
	var clean_id: String = ScholasticTypesScript.normalize_id(player_id)
	if clean_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var profile: Dictionary = _ensure_profile(clean_id, display_name)
	profile["age_years"] = age_years
	if not display_name.strip_edges().is_empty():
		profile["display_name"] = ScholasticTypesScript.clean_text(display_name, 32)
	if ScholasticTypesScript.is_minor_age(age_years):
		profile["ecosystem"] = ScholasticTypesScript.ECOSYSTEM_SFA
		var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
		sfa["is_candidate"] = true
		sfa["is_user"] = true
		sfa["eligibility_status"] = "ASSIGNED"
		sfa["real_money_prize_eligible"] = false
		sfa["sfa_progression_locked_from_adult_money_games"] = true
		profile["sfa"] = sfa
	else:
		if str(profile.get("ecosystem", ScholasticTypesScript.ECOSYSTEM_NONE)) == ScholasticTypesScript.ECOSYSTEM_SFA:
			profile["ecosystem"] = ScholasticTypesScript.ECOSYSTEM_NONE
		var adult_sfa: Dictionary = profile.get("sfa", {}) as Dictionary
		adult_sfa["is_candidate"] = false
		adult_sfa["is_user"] = false
		adult_sfa["eligibility_status"] = "ADULT"
		adult_sfa["eligible_for_school_team"] = false
		adult_sfa["real_money_prize_eligible"] = true
		adult_sfa["sfa_progression_locked_from_adult_money_games"] = false
		profile["sfa"] = adult_sfa
	profile = _normalize_profile(profile)
	_repository.put_profile(clean_id, profile)
	_recalculate_school_for_profile(profile)
	_commit_and_emit("age_reported", {"player_id": clean_id, "ecosystem": str(profile.get("ecosystem", ""))})
	return {"ok": true, "profile": profile, "communication_access": get_communication_access(clean_id), "money_access": get_real_money_prize_access(clean_id)}

func intent_register_high_school(player_id: String, identity: Dictionary) -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	if clean_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var profile: Dictionary = get_player_profile_snapshot(clean_player_id)
	if profile.is_empty():
		return {"ok": false, "reason": "profile_not_found"}
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	if not bool(sfa.get("is_user", false)):
		return {"ok": false, "reason": "sfa_required"}
	var school_id: String = ScholasticTypesScript.normalize_id(str(identity.get("school_id", "")))
	if school_id.is_empty():
		school_id = ScholasticTypesScript.normalize_id(str(identity.get("school_name", "")))
	if school_id.is_empty():
		return {"ok": false, "reason": "missing_school_id"}
	var existing: Dictionary = _repository.get_school_program(school_id)
	var program: Dictionary = SchoolProgramScript.new_school_program(school_id, identity) if existing.is_empty() else SchoolProgramScript.merge_identity(existing, identity)
	program["updated_at_unix"] = _now_unix()
	if int(program.get("created_at_unix", 0)) <= 0:
		program["created_at_unix"] = _now_unix()
	_repository.put_school_program(school_id, program)
	var join_result: Dictionary = intent_join_school_program(clean_player_id, school_id)
	if not bool(join_result.get("ok", false)):
		return join_result
	return {"ok": true, "school": get_school_program_snapshot(school_id), "profile": get_player_profile_snapshot(clean_player_id)}

func intent_set_school_identity(school_id: String, identity: Dictionary) -> Dictionary:
	var clean_id: String = ScholasticTypesScript.normalize_id(school_id)
	if clean_id.is_empty():
		return {"ok": false, "reason": "missing_school_id"}
	var existing: Dictionary = _repository.get_school_program(clean_id)
	if existing.is_empty():
		existing = SchoolProgramScript.new_school_program(clean_id, identity)
	var program: Dictionary = SchoolProgramScript.merge_identity(existing, identity)
	program["updated_at_unix"] = _now_unix()
	# TODO: require school admin approval and verification workflow before VERIFIED status is accepted.
	_repository.put_school_program(clean_id, program)
	_commit_and_emit("school_identity_updated", {"school_id": clean_id})
	return {"ok": true, "school": get_school_program_snapshot(clean_id)}

func intent_join_school_program(player_id: String, school_id: String) -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	var clean_school_id: String = ScholasticTypesScript.normalize_id(school_id)
	if clean_player_id.is_empty() or clean_school_id.is_empty():
		return {"ok": false, "reason": "missing_ids"}
	var profile: Dictionary = get_player_profile_snapshot(clean_player_id)
	if profile.is_empty():
		return {"ok": false, "reason": "profile_not_found"}
	var school: Dictionary = _repository.get_school_program(clean_school_id)
	if school.is_empty():
		return {"ok": false, "reason": "school_not_found"}
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	if not bool(sfa.get("is_user", false)):
		return {"ok": false, "reason": "sfa_required"}
	sfa["school_id"] = clean_school_id
	sfa["eligible_for_school_team"] = true
	sfa["eligibility_status"] = "ELIGIBLE"
	profile["sfa"] = sfa
	profile = _normalize_profile(profile)
	_repository.put_profile(clean_player_id, profile)
	_recalculate_school_teams(clean_school_id)
	_commit_and_emit("school_program_joined", {"player_id": clean_player_id, "school_id": clean_school_id})
	return {"ok": true, "profile": get_player_profile_snapshot(clean_player_id), "school": get_school_program_snapshot(clean_school_id)}

func intent_leave_school_program(player_id: String) -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	var profile: Dictionary = get_player_profile_snapshot(clean_player_id)
	if profile.is_empty():
		return {"ok": false, "reason": "profile_not_found"}
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	var old_school_id: String = ScholasticTypesScript.normalize_id(str(sfa.get("school_id", "")))
	sfa["school_id"] = ""
	sfa["team_id"] = ""
	sfa["team_index"] = -1
	sfa["team_label"] = ""
	sfa["roster_slot"] = -1
	sfa["eligible_for_school_team"] = false
	sfa["eligibility_status"] = "LEFT_SCHOOL"
	profile["sfa"] = sfa
	_repository.put_profile(clean_player_id, _normalize_profile(profile))
	if not old_school_id.is_empty():
		_recalculate_school_teams(old_school_id)
	_commit_and_emit("school_program_left", {"player_id": clean_player_id, "school_id": old_school_id})
	return {"ok": true, "profile": get_player_profile_snapshot(clean_player_id)}

func intent_update_player_competitive_profile(player_id: String, competitive_update: Dictionary) -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	if clean_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var profile: Dictionary = _ensure_profile(clean_player_id)
	var competitive: Dictionary = profile.get("competitive", ScholasticProfileScript.default_competitive_profile()) as Dictionary
	for key: String in ["rank_position", "tier_id", "tier_index", "mmr", "rank_source"]:
		if competitive_update.has(key):
			competitive[key] = competitive_update.get(key)
	competitive["rank_position"] = maxi(0, int(competitive.get("rank_position", 0)))
	competitive["tier_index"] = maxi(0, int(competitive.get("tier_index", 0)))
	competitive["mmr"] = maxf(0.0, float(competitive.get("mmr", ScholasticTypesScript.DEFAULT_MMR)))
	competitive["updated_at_unix"] = _now_unix()
	profile["competitive"] = competitive
	if competitive_update.has("graduation_year") or competitive_update.has("role_tags") or competitive_update.has("playstyle_tags"):
		var scholastic: Dictionary = profile.get("scholastic", {}) as Dictionary
		if competitive_update.has("graduation_year"):
			scholastic["graduation_year"] = maxi(0, int(competitive_update.get("graduation_year", 0)))
		if competitive_update.has("role_tags"):
			scholastic["role_tags"] = _sanitize_string_array(competitive_update.get("role_tags", []) as Array, 8, 32)
		if competitive_update.has("playstyle_tags"):
			scholastic["playstyle_tags"] = _sanitize_string_array(competitive_update.get("playstyle_tags", []) as Array, 8, 32)
		profile["scholastic"] = scholastic
	profile = _normalize_profile(profile)
	_repository.put_profile(clean_player_id, profile)
	_recalculate_school_for_profile(profile)
	_commit_and_emit("competitive_profile_updated", {"player_id": clean_player_id})
	return {"ok": true, "profile": get_player_profile_snapshot(clean_player_id)}

func intent_update_eligibility(player_id: String, eligible: bool, reason: String = "") -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	var profile: Dictionary = get_player_profile_snapshot(clean_player_id)
	if profile.is_empty():
		return {"ok": false, "reason": "profile_not_found"}
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	if not bool(sfa.get("is_user", false)):
		return {"ok": false, "reason": "sfa_required"}
	sfa["eligible_for_school_team"] = eligible
	sfa["eligibility_status"] = "ELIGIBLE" if eligible else ScholasticTypesScript.clean_text(reason, 48)
	if str(sfa.get("eligibility_status", "")).is_empty():
		sfa["eligibility_status"] = "INELIGIBLE"
	profile["sfa"] = sfa
	_repository.put_profile(clean_player_id, _normalize_profile(profile))
	_recalculate_school_for_profile(profile)
	_commit_and_emit("sfa_eligibility_updated", {"player_id": clean_player_id, "eligible": eligible})
	return {"ok": true, "profile": get_player_profile_snapshot(clean_player_id)}

func intent_register_college_program(identity: Dictionary) -> Dictionary:
	var program_id: String = ScholasticTypesScript.normalize_id(str(identity.get("college_program_id", "")))
	if program_id.is_empty():
		program_id = ScholasticTypesScript.normalize_id(str(identity.get("university_name", "")))
	if program_id.is_empty():
		return {"ok": false, "reason": "missing_college_program_id"}
	var existing: Dictionary = _repository.get_college_program(program_id)
	var program: Dictionary = CollegeProgramScript.new_college_program(program_id, identity) if existing.is_empty() else CollegeProgramScript.merge_identity(existing, identity)
	program["updated_at_unix"] = _now_unix()
	if int(program.get("created_at_unix", 0)) <= 0:
		program["created_at_unix"] = _now_unix()
	# TODO: verify university identity, coach/scout accounts, and recruiting access server-side.
	_repository.put_college_program(program_id, program)
	_commit_and_emit("college_program_registered", {"college_program_id": program_id})
	return {"ok": true, "college_program": get_college_program_snapshot(program_id)}

func intent_update_recruiting_status(player_id: String, recruiting_status: String) -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	var profile: Dictionary = _ensure_profile(clean_player_id)
	var normalized_status: String = ScholasticTypesScript.normalize_recruiting_status(recruiting_status)
	var privacy: Dictionary = profile.get("privacy", {}) as Dictionary
	if bool(privacy.get("is_minor", false)) and normalized_status not in [ScholasticTypesScript.RECRUITING_NOT_RECRUITABLE, ScholasticTypesScript.RECRUITING_SFA_RECRUITABLE]:
		return {"ok": false, "reason": "minor_recruiting_status_restricted"}
	var sfu: Dictionary = profile.get("sfu", {}) as Dictionary
	sfu["recruiting_status"] = normalized_status
	profile["sfu"] = sfu
	profile = _normalize_profile(profile)
	_repository.put_profile(clean_player_id, profile)
	_commit_and_emit("recruiting_status_updated", {"player_id": clean_player_id, "status": normalized_status})
	return {"ok": true, "profile": get_player_profile_snapshot(clean_player_id), "recruiting_profile": get_safe_recruiting_profile(clean_player_id)}

func intent_create_sfa_tournament(tournament_id: String, tournament_type: String, title: String = "") -> Dictionary:
	var tournament: Dictionary = ScholasticTournamentServiceScript.new_sfa_tournament(tournament_id, tournament_type, title)
	var clean_id: String = str(tournament.get("tournament_id", ""))
	_repository.put_sfa_tournament(clean_id, tournament)
	_commit_and_emit("sfa_tournament_created", {"tournament_id": clean_id, "tournament_type": str(tournament.get("tournament_type", ""))})
	return {"ok": true, "tournament": tournament}

func intent_record_sfa_tournament_result(player_id: String, result: Dictionary) -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	var profile: Dictionary = get_player_profile_snapshot(clean_player_id)
	if profile.is_empty():
		return {"ok": false, "reason": "profile_not_found"}
	if not ScholasticTournamentServiceScript.is_sfa_progression_result_eligible(result):
		return {"ok": false, "reason": "result_not_sfa_progression_eligible"}
	var scholastic: Dictionary = profile.get("scholastic", {}) as Dictionary
	var results: Array = scholastic.get("tournament_results", []) as Array
	var safe_result: Dictionary = result.duplicate(true)
	safe_result["recorded_at_unix"] = _now_unix()
	safe_result["awards_real_money"] = false
	results.append(safe_result)
	scholastic["tournament_results"] = results
	profile["scholastic"] = scholastic
	_repository.put_profile(clean_player_id, _normalize_profile(profile))
	_commit_and_emit("sfa_tournament_result_recorded", {"player_id": clean_player_id})
	return {"ok": true, "profile": get_player_profile_snapshot(clean_player_id)}

func preview_school_team_assignments(school_id: String) -> Dictionary:
	var clean_id: String = ScholasticTypesScript.normalize_id(school_id)
	var school: Dictionary = _repository.get_school_program(clean_id)
	if school.is_empty():
		return {}
	return ScholasticAssignmentServiceScript.recalculate_school_teams(school, _repository.profiles_by_player_id.values())

func _ensure_profile(player_id: String, display_name: String = "") -> Dictionary:
	var clean_id: String = ScholasticTypesScript.normalize_id(player_id)
	var profile: Dictionary = _repository.get_profile(clean_id)
	if profile.is_empty():
		profile = ScholasticProfileScript.new_profile(clean_id, display_name)
	else:
		if not display_name.strip_edges().is_empty():
			profile["display_name"] = ScholasticTypesScript.clean_text(display_name, 32)
	profile = _normalize_profile(profile)
	_repository.put_profile(clean_id, profile)
	return profile

func _normalize_profile(profile: Dictionary) -> Dictionary:
	var out: Dictionary = ScholasticProfileScript.normalize_profile(profile)
	out["communication_access"] = ScholasticPrivacyServiceScript.communication_access_for_profile(out)
	out["money_access"] = ScholasticPrivacyServiceScript.real_money_prize_access_for_profile(out)
	return out

func _recalculate_school_for_profile(profile: Dictionary) -> void:
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	var school_id: String = ScholasticTypesScript.normalize_id(str(sfa.get("school_id", "")))
	if school_id.is_empty():
		return
	_recalculate_school_teams(school_id)

func _recalculate_school_teams(school_id: String) -> void:
	var clean_school_id: String = ScholasticTypesScript.normalize_id(school_id)
	var school: Dictionary = _repository.get_school_program(clean_school_id)
	if school.is_empty():
		return
	var recalculated: Dictionary = ScholasticAssignmentServiceScript.recalculate_school_teams(school, _repository.profiles_by_player_id.values())
	_repository.put_school_program(clean_school_id, recalculated)
	_apply_school_membership_to_profiles(clean_school_id, recalculated)

func _apply_school_membership_to_profiles(school_id: String, school: Dictionary) -> void:
	var membership_by_player_id: Dictionary = school.get("membership_by_player_id", {}) as Dictionary
	for player_id_any in _repository.profiles_by_player_id.keys():
		var player_id: String = str(player_id_any)
		var profile: Dictionary = _repository.get_profile(player_id)
		var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
		if ScholasticTypesScript.normalize_id(str(sfa.get("school_id", ""))) != school_id:
			continue
		var membership: Dictionary = membership_by_player_id.get(player_id, {}) as Dictionary
		if membership.is_empty():
			sfa["team_id"] = ""
			sfa["team_index"] = -1
			sfa["team_label"] = ""
			sfa["roster_slot"] = -1
		else:
			sfa["team_id"] = str(membership.get("team_id", ""))
			sfa["team_index"] = int(membership.get("team_index", -1))
			sfa["team_label"] = str(membership.get("team_label", ""))
			sfa["roster_slot"] = int(membership.get("roster_slot", -1))
		profile["sfa"] = sfa
		_repository.put_profile(player_id, _normalize_profile(profile))

func _sanitize_string_array(raw: Array, max_count: int, max_len: int) -> Array[String]:
	var out: Array[String] = []
	for item_any in raw:
		var item: String = ScholasticTypesScript.clean_text(str(item_any), max_len)
		if item.is_empty():
			continue
		if out.has(item):
			continue
		out.append(item)
		if out.size() >= max_count:
			break
	return out

func _commit_and_emit(event_name: String, event_payload: Dictionary) -> void:
	_save_state()
	var event: Dictionary = event_payload.duplicate(true)
	event["event_name"] = event_name
	event["created_at_unix"] = _now_unix()
	scholastic_event.emit(event)
	_emit_changed()

func _emit_changed() -> void:
	scholastic_state_changed.emit(get_snapshot())

func _load_state() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed_any: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed_any) != TYPE_DICTIONARY:
		return
	var parsed: Dictionary = parsed_any as Dictionary
	var repo_snapshot: Dictionary = parsed.get("repository", {}) as Dictionary
	_repository.load_snapshot(repo_snapshot)
	_normalize_all_loaded_profiles()

func _save_state() -> void:
	var payload: Dictionary = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"repository": _repository.to_snapshot()
	}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _normalize_all_loaded_profiles() -> void:
	for player_id_any in _repository.profiles_by_player_id.keys():
		var player_id: String = str(player_id_any)
		var profile: Dictionary = _repository.get_profile(player_id)
		_repository.put_profile(player_id, _normalize_profile(profile))

func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
