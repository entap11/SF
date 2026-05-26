import {
  applySchoolAttestation,
  cleanText,
  currentSchoolYear,
  mergeSchoolIdentity,
  MINOR_AGE_CUTOFF,
  newCollegeProgram,
  newProfile,
  newSchoolProgram,
  newTournament,
  normalizeId,
  normalizeProfile,
  normalizeSchoolYear,
  nowUnix,
  adPolicy,
  recalculateSchoolHiveReview,
  recalculateSchoolTeams,
  toBool,
  toRecord
} from "./logic.js";
import type { AuditEventInput, ScholasticState } from "./types.js";

export interface ActionContext {
  audit: (event: AuditEventInput) => void;
}

export function reportAge(state: ScholasticState, context: ActionContext, body: Record<string, unknown>): Record<string, unknown> {
  const playerId = normalizeId(body.player_id);
  if (!playerId) {
    return fail("missing_player_id");
  }
  const profile = state.profiles[playerId] ?? newProfile(playerId, cleanText(body.display_name, 32));
  profile.age_years = Math.floor(Number(body.age_years ?? -1));
  if (body.display_name != null) {
    profile.display_name = cleanText(body.display_name, 32);
  }
  state.profiles[playerId] = normalizeProfile(profile);
  context.audit({ event_type: "age_reported", player_id: playerId, payload: { ecosystem: state.profiles[playerId]!.ecosystem } });
  return ok({ profile: state.profiles[playerId] });
}

export function registerHighSchool(state: ScholasticState, context: ActionContext, body: Record<string, unknown>): Record<string, unknown> {
  const playerId = normalizeId(body.player_id);
  const identity = toRecord(body.identity);
  const schoolId = normalizeId(identity.school_id || identity.school_name);
  if (!playerId || !schoolId) {
    return fail("missing_ids");
  }
  const profile = state.profiles[playerId];
  if (!profile?.sfa.is_candidate) {
    return fail("sfa_required");
  }
  state.schools[schoolId] = state.schools[schoolId]
    ? mergeSchoolIdentity(state.schools[schoolId]!, identity)
    : newSchoolProgram(schoolId, identity);
  return joinSchool(state, context, {
    player_id: playerId,
    school_id: schoolId,
    attestation: {
      attested_enrolled: identity.attested_enrolled,
      school_year: identity.school_year ?? currentSchoolYear(),
      freshman_school_year: identity.freshman_school_year ?? identity.school_year ?? currentSchoolYear()
    }
  });
}

export function joinSchool(state: ScholasticState, context: ActionContext, body: Record<string, unknown>): Record<string, unknown> {
  const playerId = normalizeId(body.player_id);
  const schoolId = normalizeId(body.school_id);
  if (!playerId || !schoolId) {
    return fail("missing_ids");
  }
  const school = state.schools[schoolId];
  const profile = state.profiles[playerId];
  if (!school) {
    return fail("school_not_found");
  }
  if (!profile?.sfa.is_candidate) {
    return fail("sfa_required");
  }
  const result = applySchoolAttestation(profile, schoolId, toRecord(body.attestation));
  state.profiles[playerId] = result.profile;
  context.audit({
    event_type: result.ok ? "school_program_joined" : "school_attestation_rejected",
    player_id: playerId,
    related_id: schoolId,
    payload: { reason: result.reason ?? "", school_year: result.profile.sfa.current_school_year_attested }
  });
  return result.ok ? ok({ profile: result.profile, school }) : fail(result.reason ?? "school_attestation_rejected", { profile: result.profile });
}

export function reviewSchoolHive(state: ScholasticState, context: ActionContext, body: Record<string, unknown>): Record<string, unknown> {
  const schoolId = normalizeId(body.school_id);
  const school = state.schools[schoolId];
  if (!school) {
    return fail("school_not_found");
  }
  const identity = toRecord(body.identity);
  const reviewed = mergeSchoolIdentity(school, identity);
  reviewed.school_hive_review_status = toBool(body.approved) ? "APPROVED" : "REJECTED";
  reviewed.verification_status = toBool(body.approved) ? "VERIFIED" : "REJECTED";
  reviewed.material_dispute_open = false;
  reviewed.review_school_year = normalizeSchoolYear(identity.school_year ?? reviewed.review_school_year);
  state.schools[schoolId] = recalculateSchoolTeams(reviewed, Object.values(state.profiles));
  context.audit({ event_type: "school_hive_reviewed", related_id: schoolId, payload: { approved: toBool(body.approved) } });
  return ok({ school: state.schools[schoolId] });
}

export function fileEnrollmentComplaint(state: ScholasticState, context: ActionContext, body: Record<string, unknown>): Record<string, unknown> {
  const reporterId = normalizeId(body.reporter_player_id);
  const targetId = normalizeId(body.target_player_id);
  const target = state.profiles[targetId];
  if (!reporterId || !targetId) {
    return fail("missing_ids");
  }
  if (!target?.sfa.school_id) {
    return fail("target_school_not_found");
  }
  const school = state.schools[target.sfa.school_id];
  if (!school) {
    return fail("school_not_found");
  }
  school.enrollment_complaints.push({
    complaint_id: `${reporterId}_${targetId}_${nowUnix()}`,
    reporter_player_id: reporterId,
    target_player_id: targetId,
    reason: cleanText(body.reason, 160),
    status: "OPEN",
    created_at_unix: nowUnix()
  });
  school.material_dispute_open = true;
  school.school_hive_review_status = "DISPUTED";
  state.schools[target.sfa.school_id] = recalculateSchoolHiveReview(school);
  context.audit({ event_type: "school_enrollment_complaint_filed", player_id: reporterId, related_id: target.sfa.school_id, payload: { target_player_id: targetId } });
  return ok({ school: state.schools[target.sfa.school_id] });
}

export function registerCollegeProgram(state: ScholasticState, context: ActionContext, body: Record<string, unknown>): Record<string, unknown> {
	const identity = toRecord(body.identity);
	const programId = normalizeId(identity.college_program_id || identity.university_name);
	if (!programId) {
		return fail("missing_college_program_id");
	}
	if (state.colleges[programId]) {
		const existing = state.colleges[programId]!;
		state.colleges[programId] = {
			...existing,
			university_name: cleanText(identity.university_name ?? existing.university_name, 96),
			city: cleanText(identity.city ?? existing.city, 64),
			state: cleanText(identity.state ?? existing.state, 32).toUpperCase(),
			mascot_name: cleanText(identity.mascot_name ?? existing.mascot_name, 48),
			program_type: cleanText(identity.program_type ?? existing.program_type, 32).toUpperCase(),
			verification_status: cleanText(identity.verification_status ?? existing.verification_status, 32).toUpperCase(),
			updated_at_unix: nowUnix()
		};
	} else {
		state.colleges[programId] = newCollegeProgram(programId, identity);
	}
	context.audit({ event_type: "college_program_registered", related_id: programId });
	return ok({ college_program: state.colleges[programId] });
}

export function joinCollegeProgram(state: ScholasticState, context: ActionContext, body: Record<string, unknown>): Record<string, unknown> {
  const playerId = normalizeId(body.player_id);
  const programId = normalizeId(body.program_id);
  const profile = state.profiles[playerId];
  if (!playerId || !programId) {
    return fail("missing_ids");
  }
  if (!profile) {
    return fail("profile_not_found");
  }
  if (profile.age_years < MINOR_AGE_CUTOFF) {
    return fail("sfu_requires_adult");
  }
  if (!state.colleges[programId]) {
    return fail("college_program_not_found");
  }
  const attestation = toRecord(body.attestation);
  if (!toBool(attestation.attested_affiliated)) {
    return fail("sfu_affiliation_attestation_required");
  }
  profile.ecosystem = "SFU";
  profile.sfu.college_program_id = programId;
  profile.sfu.program_affiliation_attested = true;
  profile.sfu.program_affiliation_attested_at_unix = nowUnix();
  profile.sfu.affiliation_school_year = normalizeSchoolYear(attestation.school_year);
  profile.sfu.sfu_status = "ACTIVE";
  profile.sfu.recruiting_status = "COLLEGE_PLAYER";
  state.profiles[playerId] = normalizeProfile(profile);
  context.audit({ event_type: "college_program_joined", player_id: playerId, related_id: programId });
  return ok({ profile: state.profiles[playerId], college_program: state.colleges[programId] });
}

export function createTournament(state: ScholasticState, context: ActionContext, body: Record<string, unknown>, ecosystem: "SFA" | "SFU"): Record<string, unknown> {
  const tournament = newTournament(ecosystem, String(body.tournament_id ?? ""), String(body.tournament_type ?? ""), String(body.title ?? ""), toRecord(body.config));
  state.tournaments[tournament.tournament_id] = tournament;
  context.audit({ event_type: `${ecosystem.toLowerCase()}_tournament_created`, related_id: tournament.tournament_id, payload: { tournament_type: tournament.tournament_type } });
  return ok({ tournament });
}

export function recordTournamentResult(state: ScholasticState, context: ActionContext, body: Record<string, unknown>, ecosystem: "SFA" | "SFU"): Record<string, unknown> {
  const playerId = normalizeId(body.player_id);
  const tournamentId = normalizeId(body.tournament_id);
  const profile = state.profiles[playerId];
  const tournament = state.tournaments[tournamentId];
  const result = toRecord(body.result);
  if (!profile) {
    return fail("profile_not_found");
  }
  if (!tournament || tournament.ecosystem !== ecosystem) {
    return fail(`${ecosystem.toLowerCase()}_tournament_not_found`);
  }
  if (ecosystem === "SFA") {
    if (toBool(result.is_money_game) || toBool(result.awards_real_money) || toBool(result.public_adult_money_game)) {
      return fail("result_not_sfa_eligible");
    }
  } else {
    if (profile.age_years < MINOR_AGE_CUTOFF) {
      return fail("sfu_requires_adult");
    }
    if (tournament.program_roster_required !== false && !profile.sfu.program_affiliation_attested) {
      return fail("sfu_program_roster_required");
    }
    if (!tournament.buffs_allowed && toBool(result.buffs_used)) {
      return fail("sfu_tournament_buffs_disabled");
    }
    if (!tournament.cash_prizes_allowed && toBool(result.awards_real_money)) {
      return fail("sfu_tournament_cash_disabled");
    }
  }
  const results = Array.isArray(profile.scholastic.tournament_results)
    ? [...profile.scholastic.tournament_results]
    : [];
  results.push({ ...result, ecosystem, tournament_id: tournamentId, recorded_at_unix: nowUnix() });
  profile.scholastic.tournament_results = results;
  state.profiles[playerId] = normalizeProfile(profile);
  context.audit({ event_type: `${ecosystem.toLowerCase()}_tournament_result_recorded`, player_id: playerId, related_id: tournamentId });
  return ok({ profile: state.profiles[playerId] });
}

export function recordActivity(state: ScholasticState, context: ActionContext, body: Record<string, unknown>): Record<string, unknown> {
  const playerId = normalizeId(body.player_id);
  if (!playerId) {
    return fail("missing_player_id");
  }
  const profile = state.profiles[playerId];
  const ecosystem = cleanText(body.ecosystem ?? profile?.ecosystem ?? "NONE", 12).toUpperCase();
  const safeEcosystem = ecosystem === "SFA" || ecosystem === "SFU" ? ecosystem : "NONE";
  const eventDate = cleanText(body.event_date ?? new Date().toISOString().slice(0, 10), 10);
  const eventId = cleanText(body.event_id ?? `${playerId}_${eventDate}_${nowUnix()}_${state.activity_events.length}`, 120);
  if (state.activity_events.some((event) => event.event_id === eventId)) {
    return ok({ duplicate: true, event_id: eventId });
  }
  state.activity_events.push({
    event_id: eventId,
    player_id: playerId,
    ecosystem: safeEcosystem as "NONE" | "SFA" | "SFU",
    event_date: eventDate,
    duration_seconds: Math.max(0, Math.floor(Number(body.duration_seconds ?? 0))),
    is_new_player: toBool(body.is_new_player),
    props: toRecord(body.props)
  });
  context.audit({ event_type: "activity_recorded", player_id: playerId, payload: { ecosystem: safeEcosystem, event_date: eventDate } });
  return ok({ event_id: eventId });
}

export function metricsSummary(state: ScholasticState, nowDate = new Date()): Record<string, unknown> {
  const schools = Object.values(state.schools);
  const profiles = Object.values(state.profiles);
  const teamCounts = schools.map((school) => school.teams.length).sort((a, b) => a - b);
  const medianTeams = teamCounts.length === 0
    ? 0
    : teamCounts[Math.floor((teamCounts.length - 1) / 2)]!;
  const totalTeams = teamCounts.reduce((sum, count) => sum + count, 0);
  const windows = {
    day: daysAgo(nowDate, 1),
    week: daysAgo(nowDate, 7),
    month: daysAgo(nowDate, 30)
  };
  return ok({
    schools: {
      total: schools.length,
      approved: schools.filter((school) => school.school_hive_review_status === "APPROVED").length,
      disputed: schools.filter((school) => school.material_dispute_open).length,
      hive_bonus_eligible: schools.filter((school) => school.hive_bonus_eligible).length,
      teams_total: totalTeams,
      teams_avg_per_school: schools.length === 0 ? 0 : totalTeams / schools.length,
      teams_median_per_school: medianTeams
    },
    players: {
      total_known: profiles.length,
      sfa_active: profiles.filter((profile) => profile.sfa.is_user).length,
      sfu_active: profiles.filter((profile) => profile.sfu.sfu_status === "ACTIVE").length,
      open_or_unknown: profiles.filter((profile) => profile.ecosystem === "NONE").length
    },
    activity: {
      day: activityWindow(state, windows.day),
      week: activityWindow(state, windows.week),
      month: activityWindow(state, windows.month)
    },
    advertising: {
      sfa_family_safe_ads_only: true,
      sfa_behavioral_targeting_allowed: false,
      sensitive_school_data_targeting_allowed: false
    }
  });
}

export function resolveAdPolicy(state: ScholasticState, playerIdRaw: unknown): Record<string, unknown> {
  const playerId = normalizeId(playerIdRaw);
  return ok({ player_id: playerId, ad_policy: adPolicy(state.profiles[playerId]) });
}

export function fail(reason: string, extra: Record<string, unknown> = {}): Record<string, unknown> {
  return { ok: false, reason, err: reason, ...extra };
}

export function ok(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return { ok: true, ...extra };
}

function daysAgo(nowDate: Date, days: number): string {
  const date = new Date(nowDate);
  date.setUTCDate(date.getUTCDate() - days + 1);
  return date.toISOString().slice(0, 10);
}

function activityWindow(state: ScholasticState, sinceDate: string): Record<string, unknown> {
  const events = state.activity_events.filter((event) => event.event_date >= sinceDate);
  const byEcosystem: Record<string, { players: Set<string>; newPlayers: Set<string>; duration: number }> = {
    SFA: { players: new Set(), newPlayers: new Set(), duration: 0 },
    SFU: { players: new Set(), newPlayers: new Set(), duration: 0 },
    NONE: { players: new Set(), newPlayers: new Set(), duration: 0 }
  };
  for (const event of events) {
    const bucket = byEcosystem[event.ecosystem] ?? byEcosystem.NONE!;
    bucket.players.add(event.player_id);
    if (event.is_new_player) {
      bucket.newPlayers.add(event.player_id);
    }
    bucket.duration += Math.max(0, Number(event.duration_seconds) || 0);
  }
  const out: Record<string, unknown> = {};
  for (const [ecosystem, bucket] of Object.entries(byEcosystem)) {
    out[ecosystem] = {
      active_players: bucket.players.size,
      new_players: bucket.newPlayers.size,
      avg_seconds_per_active_player: bucket.players.size === 0 ? 0 : bucket.duration / bucket.players.size,
      avg_minutes_per_active_player: bucket.players.size === 0 ? 0 : bucket.duration / bucket.players.size / 60
    };
  }
  return out;
}
