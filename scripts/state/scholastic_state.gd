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
			"sfa_progression_from_public_adult_money_games": false,
			"cash_competition_min_age": 18
		},
		"sfa_policy": {
			"school_required": true,
			"max_school_years": ScholasticTypesScript.SFA_MAX_SCHOOL_YEARS,
			"hive_bonus_scope": "school_hive_after_review",
			"current_school_year": ScholasticTypesScript.current_school_year()
		},
		"sfu_policy": {
			"adult_only": true,
			"normal_comms_allowed": true,
			"normal_money_games_allowed": true,
			"normal_buffs_allowed": true,
			"default_tournament_buffs_allowed": false
		},
		"repository": repo_snapshot,
		"sfa_tournament_types": ScholasticTypesScript.SFA_TOURNAMENT_TYPES.duplicate(),
		"sfu_tournament_types": ScholasticTypesScript.SFU_TOURNAMENT_TYPES.duplicate()
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
		sfa["is_user"] = bool(sfa.get("school_enrollment_attested", false)) and not str(sfa.get("school_id", "")).is_empty()
		sfa["eligibility_status"] = ScholasticTypesScript.SFA_STATUS_ACTIVE if bool(sfa.get("is_user", false)) else ScholasticTypesScript.SFA_STATUS_AWAITING_SCHOOL
		sfa["transition_status"] = str(sfa.get("eligibility_status", ScholasticTypesScript.SFA_STATUS_AWAITING_SCHOOL))
		sfa["real_money_prize_eligible"] = false
		sfa["sfa_progression_locked_from_adult_money_games"] = true
		profile["sfa"] = sfa
	else:
		if str(profile.get("ecosystem", ScholasticTypesScript.ECOSYSTEM_NONE)) == ScholasticTypesScript.ECOSYSTEM_SFA:
			profile["ecosystem"] = ScholasticTypesScript.ECOSYSTEM_NONE
		var adult_sfa: Dictionary = profile.get("sfa", {}) as Dictionary
		adult_sfa["is_candidate"] = false
		adult_sfa["is_user"] = false
		adult_sfa["eligibility_status"] = ScholasticTypesScript.SFA_STATUS_ADULT
		adult_sfa["transition_status"] = ScholasticTypesScript.SFA_STATUS_ADULT
		adult_sfa["eligible_for_school_team"] = false
		adult_sfa["real_money_prize_eligible"] = true
		adult_sfa["sfa_progression_locked_from_adult_money_games"] = false
		profile["sfa"] = adult_sfa
	profile = _normalize_profile(profile)
	_repository.put_profile(clean_id, profile)
	_recalculate_school_for_profile(profile)
	_grant_sfa_student_entitlements_if_possible(clean_id)
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
	if not bool(sfa.get("is_candidate", false)):
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
	var join_result: Dictionary = intent_join_school_program(clean_player_id, school_id, _school_attestation_from_identity(identity))
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
	program = _recalculate_school_hive_review(program)
	_repository.put_school_program(clean_id, program)
	_commit_and_emit("school_identity_updated", {"school_id": clean_id})
	return {"ok": true, "school": get_school_program_snapshot(clean_id)}

func intent_join_school_program(player_id: String, school_id: String, attestation: Dictionary = {}) -> Dictionary:
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
	if not bool(sfa.get("is_candidate", false)):
		return {"ok": false, "reason": "sfa_required"}
	var attestation_result: Dictionary = _apply_school_attestation_to_sfa(sfa, clean_school_id, attestation)
	if not bool(attestation_result.get("ok", false)):
		sfa["school_id"] = clean_school_id
		sfa["eligible_for_school_team"] = false
		sfa["eligibility_status"] = str(attestation_result.get("status", ScholasticTypesScript.SFA_STATUS_AWAITING_SCHOOL))
		sfa["transition_status"] = str(attestation_result.get("status", ScholasticTypesScript.SFA_STATUS_AWAITING_SCHOOL))
		profile["sfa"] = sfa
		_repository.put_profile(clean_player_id, _normalize_profile(profile))
		_recalculate_school_teams(clean_school_id)
		_commit_and_emit("school_attestation_rejected", {"player_id": clean_player_id, "school_id": clean_school_id, "reason": str(attestation_result.get("reason", "unknown"))})
		return attestation_result
	sfa = attestation_result.get("sfa", {}) as Dictionary
	sfa["school_id"] = clean_school_id
	sfa["eligible_for_school_team"] = true
	sfa["eligibility_status"] = ScholasticTypesScript.SFA_STATUS_ACTIVE
	sfa["transition_status"] = ScholasticTypesScript.SFA_STATUS_ACTIVE
	profile["sfa"] = sfa
	profile = _normalize_profile(profile)
	_repository.put_profile(clean_player_id, profile)
	_recalculate_school_teams(clean_school_id)
	_grant_sfa_student_entitlements_if_possible(clean_player_id)
	_commit_and_emit("school_program_joined", {"player_id": clean_player_id, "school_id": clean_school_id, "school_year": str(sfa.get("current_school_year_attested", ""))})
	return {"ok": true, "profile": get_player_profile_snapshot(clean_player_id), "school": get_school_program_snapshot(clean_school_id)}

func intent_leave_school_program(player_id: String) -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	var profile: Dictionary = get_player_profile_snapshot(clean_player_id)
	if profile.is_empty():
		return {"ok": false, "reason": "profile_not_found"}
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	var old_school_id: String = ScholasticTypesScript.normalize_id(str(sfa.get("school_id", "")))
	sfa["school_id"] = ""
	sfa["school_enrollment_attested"] = false
	sfa["current_school_year_attested"] = ""
	sfa["team_id"] = ""
	sfa["team_index"] = -1
	sfa["team_label"] = ""
	sfa["roster_slot"] = -1
	sfa["eligible_for_school_team"] = false
	sfa["eligibility_status"] = ScholasticTypesScript.SFA_STATUS_AWAITING_SCHOOL
	sfa["transition_status"] = ScholasticTypesScript.SFA_STATUS_AWAITING_SCHOOL
	profile["sfa"] = sfa
	_repository.put_profile(clean_player_id, _normalize_profile(profile))
	if not old_school_id.is_empty():
		_recalculate_school_teams(old_school_id)
	_commit_and_emit("school_program_left", {"player_id": clean_player_id, "school_id": old_school_id})
	return {"ok": true, "profile": get_player_profile_snapshot(clean_player_id)}

func intent_attest_school_enrollment(player_id: String, school_id: String, school_year: String, freshman_school_year: String = "") -> Dictionary:
	return intent_join_school_program(player_id, school_id, {
		"attested_enrolled": true,
		"school_year": school_year,
		"freshman_school_year": freshman_school_year
	})

func intent_review_school_hive(school_id: String, approved: bool, review_identity: Dictionary = {}) -> Dictionary:
	var clean_school_id: String = ScholasticTypesScript.normalize_id(school_id)
	if clean_school_id.is_empty():
		return {"ok": false, "reason": "missing_school_id"}
	var school: Dictionary = _repository.get_school_program(clean_school_id)
	if school.is_empty():
		return {"ok": false, "reason": "school_not_found"}
	if not review_identity.is_empty():
		school = SchoolProgramScript.merge_identity(school, review_identity)
	if approved:
		school["school_hive_review_status"] = ScholasticTypesScript.SCHOOL_HIVE_REVIEW_APPROVED
		school["verification_status"] = ScholasticTypesScript.VERIFICATION_VERIFIED
		school["material_dispute_open"] = false
	else:
		school["school_hive_review_status"] = ScholasticTypesScript.SCHOOL_HIVE_REVIEW_REJECTED
		school["verification_status"] = ScholasticTypesScript.VERIFICATION_REJECTED
	if review_identity.has("school_year"):
		school["review_school_year"] = ScholasticTypesScript.normalize_school_year(str(review_identity.get("school_year", "")))
	school["updated_at_unix"] = _now_unix()
	school = _recalculate_school_hive_review(school)
	_repository.put_school_program(clean_school_id, school)
	_commit_and_emit("school_hive_reviewed", {"school_id": clean_school_id, "approved": approved})
	return {"ok": true, "school": get_school_program_snapshot(clean_school_id)}

func intent_file_school_enrollment_complaint(reporter_player_id: String, target_player_id: String, reason: String = "") -> Dictionary:
	var clean_reporter_id: String = ScholasticTypesScript.normalize_id(reporter_player_id)
	var clean_target_id: String = ScholasticTypesScript.normalize_id(target_player_id)
	if clean_reporter_id.is_empty() or clean_target_id.is_empty():
		return {"ok": false, "reason": "missing_ids"}
	var target_profile: Dictionary = get_player_profile_snapshot(clean_target_id)
	if target_profile.is_empty():
		return {"ok": false, "reason": "target_profile_not_found"}
	var target_sfa: Dictionary = target_profile.get("sfa", {}) as Dictionary
	var school_id: String = ScholasticTypesScript.normalize_id(str(target_sfa.get("school_id", "")))
	if school_id.is_empty():
		return {"ok": false, "reason": "target_school_not_found"}
	var school: Dictionary = _repository.get_school_program(school_id)
	if school.is_empty():
		return {"ok": false, "reason": "school_not_found"}
	var complaints: Array = school.get("enrollment_complaints", []) as Array
	complaints.append({
		"complaint_id": "%s_%s_%d" % [clean_reporter_id, clean_target_id, _now_unix()],
		"reporter_player_id": clean_reporter_id,
		"target_player_id": clean_target_id,
		"reason": ScholasticTypesScript.clean_text(reason, 160),
		"status": "OPEN",
		"created_at_unix": _now_unix()
	})
	school["enrollment_complaints"] = complaints
	school["material_dispute_open"] = true
	school["school_hive_review_status"] = ScholasticTypesScript.SCHOOL_HIVE_REVIEW_DISPUTED
	school = _recalculate_school_hive_review(school)
	_repository.put_school_program(school_id, school)
	_commit_and_emit("school_enrollment_complaint_filed", {"school_id": school_id, "target_player_id": clean_target_id})
	return {"ok": true, "school": get_school_program_snapshot(school_id)}

func intent_transition_out_of_sfa(player_id: String, target_ecosystem: String, program_id: String = "") -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	var profile: Dictionary = get_player_profile_snapshot(clean_player_id)
	if profile.is_empty():
		return {"ok": false, "reason": "profile_not_found"}
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	var old_school_id: String = ScholasticTypesScript.normalize_id(str(sfa.get("school_id", "")))
	sfa["is_user"] = false
	sfa["eligible_for_school_team"] = false
	sfa["transition_status"] = ScholasticTypesScript.SFA_STATUS_TRANSITIONED
	sfa["eligibility_status"] = ScholasticTypesScript.SFA_STATUS_TRANSITIONED
	sfa["team_id"] = ""
	sfa["team_index"] = -1
	sfa["team_label"] = ""
	sfa["roster_slot"] = -1
	profile["sfa"] = sfa
	var clean_target: String = target_ecosystem.strip_edges().to_upper()
	if clean_target == ScholasticTypesScript.ECOSYSTEM_SFU:
		if int(profile.get("age_years", -1)) < ScholasticTypesScript.MINOR_AGE_CUTOFF:
			return {"ok": false, "reason": "sfu_requires_adult"}
		var sfu: Dictionary = profile.get("sfu", {}) as Dictionary
		sfu["college_program_id"] = ScholasticTypesScript.normalize_id(program_id)
		sfu["sfu_status"] = ScholasticTypesScript.SFU_STATUS_CANDIDATE
		if not str(sfu.get("college_program_id", "")).is_empty():
			sfu["program_affiliation_attested"] = true
			sfu["program_affiliation_attested_at_unix"] = _now_unix()
			sfu["sfu_status"] = ScholasticTypesScript.SFU_STATUS_ACTIVE
			sfu["recruiting_status"] = ScholasticTypesScript.RECRUITING_COLLEGE_PLAYER
		profile["sfu"] = sfu
		profile["ecosystem"] = ScholasticTypesScript.ECOSYSTEM_SFU
	else:
		profile["ecosystem"] = ScholasticTypesScript.ECOSYSTEM_NONE
	_repository.put_profile(clean_player_id, _normalize_profile(profile))
	if not old_school_id.is_empty():
		_recalculate_school_teams(old_school_id)
	if clean_target == ScholasticTypesScript.ECOSYSTEM_SFU and not program_id.strip_edges().is_empty():
		_recalculate_college_program_membership(program_id)
	_commit_and_emit("sfa_player_transitioned", {"player_id": clean_player_id, "target_ecosystem": clean_target})
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

func intent_join_college_program(player_id: String, program_id: String, attestation: Dictionary = {}) -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	var clean_program_id: String = ScholasticTypesScript.normalize_id(program_id)
	if clean_player_id.is_empty() or clean_program_id.is_empty():
		return {"ok": false, "reason": "missing_ids"}
	var profile: Dictionary = get_player_profile_snapshot(clean_player_id)
	if profile.is_empty():
		return {"ok": false, "reason": "profile_not_found"}
	if int(profile.get("age_years", -1)) < ScholasticTypesScript.MINOR_AGE_CUTOFF:
		return {"ok": false, "reason": "sfu_requires_adult"}
	var program: Dictionary = _repository.get_college_program(clean_program_id)
	if program.is_empty():
		return {"ok": false, "reason": "college_program_not_found"}
	if not bool(attestation.get("attested_affiliated", false)):
		return {"ok": false, "reason": "sfu_affiliation_attestation_required"}
	var sfu: Dictionary = profile.get("sfu", {}) as Dictionary
	sfu["college_program_id"] = clean_program_id
	sfu["program_affiliation_attested"] = true
	sfu["program_affiliation_attested_at_unix"] = _now_unix()
	sfu["affiliation_school_year"] = ScholasticTypesScript.normalize_school_year(str(attestation.get("school_year", "")))
	sfu["sfu_status"] = ScholasticTypesScript.SFU_STATUS_ACTIVE
	sfu["recruiting_status"] = ScholasticTypesScript.RECRUITING_COLLEGE_PLAYER
	sfu["normal_comms_allowed"] = true
	sfu["normal_money_games_allowed"] = true
	sfu["normal_buffs_allowed"] = true
	profile["sfu"] = sfu
	profile["ecosystem"] = ScholasticTypesScript.ECOSYSTEM_SFU
	_repository.put_profile(clean_player_id, _normalize_profile(profile))
	_recalculate_college_program_membership(clean_program_id)
	_commit_and_emit("college_program_joined", {"player_id": clean_player_id, "college_program_id": clean_program_id})
	return {"ok": true, "profile": get_player_profile_snapshot(clean_player_id), "college_program": get_college_program_snapshot(clean_program_id)}

func intent_leave_college_program(player_id: String, alumni: bool = false) -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	var profile: Dictionary = get_player_profile_snapshot(clean_player_id)
	if profile.is_empty():
		return {"ok": false, "reason": "profile_not_found"}
	var sfu: Dictionary = profile.get("sfu", {}) as Dictionary
	var old_program_id: String = ScholasticTypesScript.normalize_id(str(sfu.get("college_program_id", "")))
	sfu["college_program_id"] = ""
	sfu["college_team_id"] = ""
	sfu["program_affiliation_attested"] = false
	sfu["sfu_status"] = ScholasticTypesScript.SFU_STATUS_ALUMNI if alumni else ScholasticTypesScript.SFU_STATUS_OPEN_ADULT
	profile["sfu"] = sfu
	profile["ecosystem"] = ScholasticTypesScript.ECOSYSTEM_NONE
	_repository.put_profile(clean_player_id, _normalize_profile(profile))
	if not old_program_id.is_empty():
		_recalculate_college_program_membership(old_program_id)
	_commit_and_emit("college_program_left", {"player_id": clean_player_id, "college_program_id": old_program_id, "alumni": alumni})
	return {"ok": true, "profile": get_player_profile_snapshot(clean_player_id)}

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

func intent_create_sfu_tournament(tournament_id: String, tournament_type: String, title: String = "", config: Dictionary = {}) -> Dictionary:
	var tournament: Dictionary = ScholasticTournamentServiceScript.new_sfu_tournament(tournament_id, tournament_type, title, config)
	var clean_id: String = str(tournament.get("tournament_id", ""))
	_repository.put_sfu_tournament(clean_id, tournament)
	_commit_and_emit("sfu_tournament_created", {"tournament_id": clean_id, "tournament_type": str(tournament.get("tournament_type", "")), "buffs_allowed": bool(tournament.get("buffs_allowed", false))})
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

func intent_record_sfu_tournament_result(player_id: String, tournament_id: String, result: Dictionary) -> Dictionary:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	var clean_tournament_id: String = ScholasticTypesScript.normalize_id(tournament_id)
	var profile: Dictionary = get_player_profile_snapshot(clean_player_id)
	if profile.is_empty():
		return {"ok": false, "reason": "profile_not_found"}
	var tournament: Dictionary = (_repository.sfu_tournaments_by_id.get(clean_tournament_id, {}) as Dictionary).duplicate(true)
	if tournament.is_empty():
		return {"ok": false, "reason": "sfu_tournament_not_found"}
	if not ScholasticTournamentServiceScript.is_sfu_result_eligible(profile, tournament, result):
		return {"ok": false, "reason": "result_not_sfu_eligible"}
	var scholastic: Dictionary = profile.get("scholastic", {}) as Dictionary
	var results: Array = scholastic.get("tournament_results", []) as Array
	var safe_result: Dictionary = result.duplicate(true)
	safe_result["ecosystem"] = ScholasticTypesScript.ECOSYSTEM_SFU
	safe_result["tournament_id"] = clean_tournament_id
	safe_result["recorded_at_unix"] = _now_unix()
	results.append(safe_result)
	scholastic["tournament_results"] = results
	profile["scholastic"] = scholastic
	_repository.put_profile(clean_player_id, _normalize_profile(profile))
	_commit_and_emit("sfu_tournament_result_recorded", {"player_id": clean_player_id, "tournament_id": clean_tournament_id})
	return {"ok": true, "profile": get_player_profile_snapshot(clean_player_id)}

func preview_school_team_assignments(school_id: String) -> Dictionary:
	var clean_id: String = ScholasticTypesScript.normalize_id(school_id)
	var school: Dictionary = _repository.get_school_program(clean_id)
	if school.is_empty():
		return {}
	return ScholasticAssignmentServiceScript.recalculate_school_teams(school, _repository.profiles_by_player_id.values())

func _school_attestation_from_identity(identity: Dictionary) -> Dictionary:
	var school_year: String = str(identity.get("school_year", identity.get("current_school_year", "")))
	var freshman_school_year: String = str(identity.get("freshman_school_year", identity.get("freshman_year", "")))
	if freshman_school_year.strip_edges().is_empty():
		freshman_school_year = school_year
	return {
		"attested_enrolled": bool(identity.get("attested_enrolled", false)),
		"school_year": school_year,
		"freshman_school_year": freshman_school_year
	}

func _apply_school_attestation_to_sfa(sfa: Dictionary, school_id: String, attestation: Dictionary) -> Dictionary:
	if not bool(attestation.get("attested_enrolled", false)):
		return {"ok": false, "reason": "school_enrollment_attestation_required", "status": ScholasticTypesScript.SFA_STATUS_AWAITING_SCHOOL}
	var school_year: String = ScholasticTypesScript.normalize_school_year(str(attestation.get("school_year", "")))
	var existing_freshman_year: String = str(sfa.get("freshman_school_year", ""))
	var freshman_school_year: String = str(attestation.get("freshman_school_year", existing_freshman_year))
	if freshman_school_year.strip_edges().is_empty():
		freshman_school_year = school_year
	freshman_school_year = ScholasticTypesScript.normalize_school_year(freshman_school_year)
	var out_sfa: Dictionary = sfa.duplicate(true)
	out_sfa["school_id"] = ScholasticTypesScript.normalize_id(school_id)
	out_sfa["school_enrollment_attested"] = true
	out_sfa["school_enrollment_attested_at_unix"] = _now_unix()
	out_sfa["current_school_year_attested"] = school_year
	out_sfa["school_attestation_expires_school_year"] = ScholasticTypesScript.school_year_from_start_year(ScholasticTypesScript.school_year_start_year(school_year) + 1)
	out_sfa["freshman_school_year"] = freshman_school_year
	out_sfa["sfa_eligibility_end_start_year"] = ScholasticTypesScript.sfa_eligibility_end_start_year(freshman_school_year)
	if not ScholasticTypesScript.is_school_year_sfa_eligible(freshman_school_year, school_year):
		out_sfa["eligible_for_school_team"] = false
		out_sfa["is_user"] = false
		out_sfa["eligibility_status"] = ScholasticTypesScript.SFA_STATUS_EXPIRED
		out_sfa["transition_status"] = ScholasticTypesScript.SFA_STATUS_EXPIRED
		return {"ok": false, "reason": "sfa_four_school_year_limit_exceeded", "status": ScholasticTypesScript.SFA_STATUS_EXPIRED, "sfa": out_sfa}
	out_sfa["is_candidate"] = true
	out_sfa["is_user"] = true
	out_sfa["eligible_for_school_team"] = true
	out_sfa["eligibility_status"] = ScholasticTypesScript.SFA_STATUS_ACTIVE
	out_sfa["transition_status"] = ScholasticTypesScript.SFA_STATUS_ACTIVE
	out_sfa["real_money_prize_eligible"] = false
	out_sfa["sfa_progression_locked_from_adult_money_games"] = true
	return {"ok": true, "sfa": out_sfa}

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

func _grant_sfa_student_entitlements_if_possible(player_id: String) -> void:
	var clean_player_id: String = ScholasticTypesScript.normalize_id(player_id)
	var profile: Dictionary = get_player_profile_snapshot(clean_player_id)
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	if not bool(sfa.get("is_user", false)):
		return
	var battle_pass_state: Node = get_node_or_null("/root/BattlePassState")
	if battle_pass_state == null or not battle_pass_state.has_method("intent_grant_analytics_credit"):
		return
	var source_key: String = "sfa_student:%s:%s" % [clean_player_id, str(sfa.get("freshman_school_year", ""))]
	battle_pass_state.call("intent_grant_analytics_credit", ScholasticTypesScript.SFA_ANALYTICS_PACKAGE_TIER_1, 1, source_key)

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
	recalculated = _apply_school_attestation_index(recalculated)
	recalculated = _recalculate_school_hive_review(recalculated)
	_repository.put_school_program(clean_school_id, recalculated)
	_apply_school_membership_to_profiles(clean_school_id, recalculated)

func _apply_school_attestation_index(school: Dictionary) -> Dictionary:
	var school_id: String = ScholasticTypesScript.normalize_id(str(school.get("school_id", "")))
	var attested_by_year: Dictionary = {}
	for profile_any in _repository.profiles_by_player_id.values():
		if typeof(profile_any) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = profile_any as Dictionary
		var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
		if ScholasticTypesScript.normalize_id(str(sfa.get("school_id", ""))) != school_id:
			continue
		if not bool(sfa.get("school_enrollment_attested", false)):
			continue
		var school_year: String = ScholasticTypesScript.normalize_school_year(str(sfa.get("current_school_year_attested", "")))
		if not attested_by_year.has(school_year):
			attested_by_year[school_year] = []
		var ids: Array = attested_by_year.get(school_year, []) as Array
		var player_id: String = str(profile.get("player_id", ""))
		if not ids.has(player_id):
			ids.append(player_id)
		attested_by_year[school_year] = ids
	var out: Dictionary = school.duplicate(true)
	out["attested_player_ids_by_school_year"] = attested_by_year
	return out

func _recalculate_school_hive_review(school: Dictionary) -> Dictionary:
	var out: Dictionary = school.duplicate(true)
	var review_status: String = str(out.get("school_hive_review_status", ScholasticTypesScript.SCHOOL_HIVE_REVIEW_SELF_REPORTED)).strip_edges().to_upper()
	var review_school_year: String = ScholasticTypesScript.normalize_school_year(str(out.get("review_school_year", ScholasticTypesScript.current_school_year())))
	out["review_school_year"] = review_school_year
	if bool(out.get("material_dispute_open", false)):
		review_status = ScholasticTypesScript.SCHOOL_HIVE_REVIEW_DISPUTED
	out["school_hive_review_status"] = review_status
	out["hive_bonus_eligible"] = false
	out["hive_bonus_locked_reason"] = "pending_review"
	if review_status == ScholasticTypesScript.SCHOOL_HIVE_REVIEW_APPROVED:
		var membership_by_player_id: Dictionary = out.get("membership_by_player_id", {}) as Dictionary
		var attested_by_year: Dictionary = out.get("attested_player_ids_by_school_year", {}) as Dictionary
		var attested_ids: Array = attested_by_year.get(review_school_year, []) as Array
		if membership_by_player_id.is_empty():
			out["hive_bonus_locked_reason"] = "empty_roster"
		else:
			var missing_attestation: bool = false
			for player_id_any in membership_by_player_id.keys():
				if not attested_ids.has(str(player_id_any)):
					missing_attestation = true
					break
			if missing_attestation:
				out["hive_bonus_locked_reason"] = "missing_roster_attestations"
			else:
				out["hive_bonus_eligible"] = true
				out["hive_bonus_locked_reason"] = ""
	elif review_status == ScholasticTypesScript.SCHOOL_HIVE_REVIEW_DISPUTED:
		out["hive_bonus_locked_reason"] = "material_dispute_open"
	elif review_status == ScholasticTypesScript.SCHOOL_HIVE_REVIEW_REJECTED:
		out["hive_bonus_locked_reason"] = "review_rejected"
	elif review_status == ScholasticTypesScript.SCHOOL_HIVE_REVIEW_EXPIRED:
		out["hive_bonus_locked_reason"] = "review_expired"
	out["public_school_name"] = ScholasticTypesScript.public_school_name(out)
	return out

func _recalculate_college_program_membership(program_id: String) -> void:
	var clean_program_id: String = ScholasticTypesScript.normalize_id(program_id)
	var program: Dictionary = _repository.get_college_program(clean_program_id)
	if program.is_empty():
		return
	var membership_by_player_id: Dictionary = {}
	var attested_by_year: Dictionary = {}
	for profile_any in _repository.profiles_by_player_id.values():
		if typeof(profile_any) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = profile_any as Dictionary
		var sfu: Dictionary = profile.get("sfu", {}) as Dictionary
		if ScholasticTypesScript.normalize_id(str(sfu.get("college_program_id", ""))) != clean_program_id:
			continue
		if not bool(sfu.get("program_affiliation_attested", false)):
			continue
		var player_id: String = str(profile.get("player_id", ""))
		membership_by_player_id[player_id] = {
			"college_program_id": clean_program_id,
			"sfu_status": str(sfu.get("sfu_status", ScholasticTypesScript.SFU_STATUS_ACTIVE))
		}
		var school_year: String = ScholasticTypesScript.normalize_school_year(str(sfu.get("affiliation_school_year", "")))
		if not attested_by_year.has(school_year):
			attested_by_year[school_year] = []
		var ids: Array = attested_by_year.get(school_year, []) as Array
		if not ids.has(player_id):
			ids.append(player_id)
		attested_by_year[school_year] = ids
	program["membership_by_player_id"] = membership_by_player_id
	program["attested_player_ids_by_school_year"] = attested_by_year
	_repository.put_college_program(clean_program_id, program)

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
	for school_id_any in _repository.school_programs_by_id.keys():
		_recalculate_school_teams(str(school_id_any))
	for program_id_any in _repository.college_programs_by_id.keys():
		_recalculate_college_program_membership(str(program_id_any))

func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
