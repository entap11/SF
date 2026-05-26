import type {
  CollegeProgram,
  ScholasticProfile,
  ScholasticState,
  ScholasticTournament,
  SchoolProgram
} from "./types.js";

export const MINOR_AGE_CUTOFF = 18;
export const SFA_MAX_SCHOOL_YEARS = 4;
export const SFA_ROSTER_BLOCK_SIZE = 12;
export const SFA_ANALYTICS_PACKAGE_TIER_1 = "analytics_pack_tier_1";

export function nowUnix(): number {
  return Math.floor(Date.now() / 1000);
}

export function normalizeId(value: unknown): string {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[ .\\/-]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "");
}

export function cleanText(value: unknown, maxLen = 80): string {
  const out = String(value ?? "").trim();
  return maxLen > 0 && out.length > maxLen ? out.slice(0, maxLen) : out;
}

export function toBool(value: unknown): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  const normalized = String(value ?? "").trim().toLowerCase();
  return ["1", "true", "yes", "y", "on"].includes(normalized);
}

export function toRecord(value: unknown): Record<string, unknown> {
  if (typeof value === "object" && value !== null && !Array.isArray(value)) {
    return { ...(value as Record<string, unknown>) };
  }
  return {};
}

export function normalizeSchoolYear(value: unknown): string {
  const raw = String(value ?? "").trim();
  if (!raw) {
    return currentSchoolYear();
  }
  const parts = raw.replace(/[/_]/g, "-").split("-").filter(Boolean);
  const startYear = Number.parseInt(parts[0] ?? "", 10);
  if (!Number.isFinite(startYear) || startYear <= 0) {
    return currentSchoolYear();
  }
  return schoolYearFromStartYear(startYear);
}

export function currentSchoolYear(): string {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = now.getUTCMonth() + 1;
  const startYear = month >= 8 ? year : year - 1;
  return schoolYearFromStartYear(startYear);
}

export function schoolYearFromStartYear(startYear: number): string {
  const cleanStart = Math.max(1900, Math.floor(startYear));
  return `${cleanStart}-${cleanStart + 1}`;
}

export function schoolYearStartYear(schoolYear: string): number {
  const normalized = normalizeSchoolYear(schoolYear);
  return Number.parseInt(normalized.slice(0, 4), 10) || 0;
}

export function isSfaEligibleSchoolYear(freshmanSchoolYear: string, attestedSchoolYear: string): boolean {
  const freshmanStart = schoolYearStartYear(freshmanSchoolYear);
  const attestedStart = schoolYearStartYear(attestedSchoolYear);
  return freshmanStart > 0 && attestedStart >= freshmanStart && attestedStart < freshmanStart + SFA_MAX_SCHOOL_YEARS;
}

export function sfaEligibilityEndStartYear(freshmanSchoolYear: string): number {
  const freshmanStart = schoolYearStartYear(freshmanSchoolYear);
  return freshmanStart > 0 ? freshmanStart + SFA_MAX_SCHOOL_YEARS : 0;
}

export function newState(): ScholasticState {
  return { profiles: {}, schools: {}, colleges: {}, tournaments: {}, activity_events: [] };
}

export function newProfile(playerId: string, displayName = ""): ScholasticProfile {
  const cleanId = normalizeId(playerId);
  const skeleton = newProfileSkeleton();
  return normalizeProfile({
    ...skeleton,
    player_id: cleanId,
    display_name: cleanText(displayName || cleanId, 32),
    scholastic: { tournament_results: [] }
  } as ScholasticProfile);
}

export function normalizeProfile(raw: ScholasticProfile): ScholasticProfile {
  const profile = structuredClone(raw);
  profile.player_id = normalizeId(profile.player_id);
  profile.display_name = cleanText(profile.display_name || profile.player_id, 32);
  profile.age_years = Math.floor(Number(profile.age_years ?? -1));
  const isMinor = profile.age_years >= 0 && profile.age_years < MINOR_AGE_CUTOFF;

  profile.sfa = { ...newProfileSkeleton().sfa, ...(profile.sfa ?? {}) };
  const sfa = profile.sfa;
  sfa.school_id = normalizeId(sfa.school_id);
  sfa.freshman_school_year = sfa.freshman_school_year ? normalizeSchoolYear(sfa.freshman_school_year) : "";
  sfa.current_school_year_attested = sfa.current_school_year_attested
    ? normalizeSchoolYear(sfa.current_school_year_attested)
    : "";
  sfa.sfa_eligibility_end_start_year = sfa.freshman_school_year
    ? sfaEligibilityEndStartYear(sfa.freshman_school_year)
    : 0;
  const hasSfaAttestation = Boolean(sfa.school_id && sfa.school_enrollment_attested && sfa.current_school_year_attested);
  const withinWindow = hasSfaAttestation && sfa.freshman_school_year
    ? isSfaEligibleSchoolYear(sfa.freshman_school_year, sfa.current_school_year_attested)
    : false;
  sfa.is_candidate = isMinor || Boolean(sfa.is_candidate);
  sfa.is_user = isMinor && hasSfaAttestation && withinWindow;
  if (isMinor && sfa.is_user) {
    profile.ecosystem = "SFA";
    sfa.eligibility_status = "ACTIVE";
    sfa.transition_status = "ACTIVE";
  } else if (isMinor && hasSfaAttestation && !withinWindow) {
    profile.ecosystem = "SFA";
    sfa.eligibility_status = "EXPIRED";
    sfa.transition_status = "EXPIRED";
  } else if (isMinor) {
    profile.ecosystem = "SFA";
    sfa.eligibility_status = "AWAITING_SCHOOL";
    sfa.transition_status = "AWAITING_SCHOOL";
  }
  sfa.real_money_prize_eligible = !isMinor && !sfa.is_user;
  sfa.sfa_progression_locked_from_adult_money_games = isMinor || sfa.is_user;
  if (sfa.is_user) {
    const sfaRecord = sfa as unknown as Record<string, unknown>;
    const entitlements = Array.isArray(sfaRecord.analytics_package_entitlements)
      ? sfaRecord.analytics_package_entitlements.map(String)
      : [];
    if (!entitlements.includes(SFA_ANALYTICS_PACKAGE_TIER_1)) {
      entitlements.push(SFA_ANALYTICS_PACKAGE_TIER_1);
    }
    sfaRecord.analytics_package_entitlements = entitlements;
  }

  profile.sfu = { ...newProfileSkeleton().sfu, ...(profile.sfu ?? {}) };
  const sfu = profile.sfu;
  sfu.college_program_id = normalizeId(sfu.college_program_id);
  sfu.normal_comms_allowed = !isMinor;
  sfu.normal_money_games_allowed = !isMinor;
  sfu.normal_buffs_allowed = true;
  if (isMinor) {
    sfu.sfu_status = "UNKNOWN";
  } else if (sfu.program_affiliation_attested && sfu.college_program_id && !["ALUMNI", "EXPIRED"].includes(sfu.sfu_status)) {
    profile.ecosystem = "SFU";
    sfu.sfu_status = "ACTIVE";
    sfu.recruiting_status = "COLLEGE_PLAYER";
  }

  profile.privacy = { ...(profile.privacy ?? {}), is_minor: isMinor, safe_public_profile_only: isMinor };
  profile.communication_access = communicationAccess(profile);
  profile.money_access = moneyAccess(profile);
  return profile;
}

function newProfileSkeleton(): ScholasticProfile {
  return {
    player_id: "",
    display_name: "",
    age_years: -1,
    ecosystem: "NONE",
    sfa: {
      is_candidate: false,
      is_user: false,
      eligibility_status: "UNKNOWN",
      eligible_for_school_team: false,
      school_id: "",
      current_school_year_attested: "",
      freshman_school_year: "",
      sfa_eligibility_end_start_year: 0,
      school_enrollment_attested: false,
      school_enrollment_attested_at_unix: 0,
      school_attestation_expires_school_year: "",
      transition_status: "UNKNOWN",
      team_id: "",
      team_index: -1,
      team_label: "",
      roster_slot: -1,
      analytics_package_entitlements: [],
      real_money_prize_eligible: true,
      sfa_progression_locked_from_adult_money_games: false
    },
    sfu: {
      college_program_id: "",
      college_team_id: "",
      program_affiliation_attested: false,
      program_affiliation_attested_at_unix: 0,
      affiliation_school_year: "",
      sfu_status: "UNKNOWN",
      recruiting_status: "NOT_RECRUITABLE",
      normal_comms_allowed: true,
      normal_money_games_allowed: true,
      normal_buffs_allowed: true
    },
    competitive: {},
    scholastic: {},
    privacy: {},
    communication_access: {},
    money_access: {}
  };
}

export function communicationAccess(profile: ScholasticProfile): Record<string, unknown> {
  const isRestricted = profile.sfa.is_user || (profile.age_years >= 0 && profile.age_years < MINOR_AGE_CUTOFF);
  return {
    dm_enabled: !isRestricted,
    in_game_chat_enabled: !isRestricted,
    private_messaging_enabled: !isRestricted,
    voice_enabled: !isRestricted,
    reason: isRestricted ? "sfa_minor_restriction" : "adult_default"
  };
}

export function moneyAccess(profile: ScholasticProfile): Record<string, unknown> {
  const isRestricted = profile.sfa.is_user || (profile.age_years >= 0 && profile.age_years < MINOR_AGE_CUTOFF);
  return {
    can_win_real_money: !isRestricted,
    can_accrue_sfa_progression_from_public_money_games: !isRestricted,
    reason: isRestricted ? "sfa_minor_real_money_restriction" : "adult_default"
  };
}

export function adPolicy(profile: ScholasticProfile | undefined): Record<string, unknown> {
  const isMinor = profile != null && profile.age_years >= 0 && profile.age_years < MINOR_AGE_CUTOFF;
  const isSfa = profile?.sfa.is_user === true || profile?.ecosystem === "SFA";
  const familySafe = isMinor || isSfa;
  return {
    family_safe_ads_only: familySafe,
    behavioral_targeting_allowed: !familySafe,
    personalized_ads_allowed: !familySafe,
    ad_content_rating: familySafe ? "G" : "STANDARD",
    child_directed_treatment: familySafe,
    sensitive_school_data_targeting_allowed: false,
    reason: familySafe ? "sfa_minor_family_safe_ads" : "adult_default"
  };
}

export function newSchoolProgram(schoolId: string, identity: Record<string, unknown>): SchoolProgram {
  const cleanId = normalizeId(schoolId || identity.school_id || identity.school_name);
  return recalculateSchoolHiveReview({
    school_id: cleanId,
    school_name: cleanText(identity.school_name, 96),
    canonical_school_name: cleanText(identity.canonical_school_name, 96),
    public_school_name: "Pending School",
    city: cleanText(identity.city, 64),
    state: cleanText(identity.state, 32).toUpperCase(),
    mascot_name: cleanText(identity.mascot_name, 48),
    colors: sanitizeStringArray(identity.colors, 4, 24),
    verification_status: cleanText(identity.verification_status || "UNVERIFIED", 32).toUpperCase(),
    school_hive_review_status: cleanText(identity.school_hive_review_status || "SELF_REPORTED", 32).toUpperCase(),
    review_school_year: normalizeSchoolYear(identity.review_school_year || currentSchoolYear()),
    hive_bonus_eligible: false,
    hive_bonus_locked_reason: "pending_review",
    material_dispute_open: false,
    enrollment_complaints: [],
    teams: [],
    membership_by_player_id: {},
    attested_player_ids_by_school_year: {},
    created_at_unix: nowUnix(),
    updated_at_unix: nowUnix()
  });
}

export function mergeSchoolIdentity(program: SchoolProgram, identity: Record<string, unknown>): SchoolProgram {
  const out = structuredClone(program);
  for (const key of ["school_name", "canonical_school_name", "city", "state", "mascot_name", "verification_status", "school_hive_review_status"] as const) {
    if (key in identity) {
      (out as unknown as Record<string, unknown>)[key] = cleanText(identity[key], 96);
    }
  }
  if ("colors" in identity) {
    out.colors = sanitizeStringArray(identity.colors, 4, 24);
  }
  if ("school_year" in identity) {
    out.review_school_year = normalizeSchoolYear(identity.school_year);
  }
  out.updated_at_unix = nowUnix();
  return recalculateSchoolHiveReview(out);
}

export function newCollegeProgram(programId: string, identity: Record<string, unknown>): CollegeProgram {
  const cleanId = normalizeId(programId || identity.college_program_id || identity.university_name);
  return {
    college_program_id: cleanId,
    university_name: cleanText(identity.university_name, 96),
    city: cleanText(identity.city, 64),
    state: cleanText(identity.state, 32).toUpperCase(),
    mascot_name: cleanText(identity.mascot_name, 48),
    colors: sanitizeStringArray(identity.colors, 4, 24),
    program_type: cleanText(identity.program_type || "COLLEGE", 32).toUpperCase(),
    verification_status: cleanText(identity.verification_status || "UNVERIFIED", 32).toUpperCase(),
    membership_by_player_id: {},
    attested_player_ids_by_school_year: {},
    created_at_unix: nowUnix(),
    updated_at_unix: nowUnix()
  };
}

export function recalculateSchoolTeams(school: SchoolProgram, profiles: ScholasticProfile[]): SchoolProgram {
  const eligible = profiles
    .filter((profile) => profile.sfa.school_id === school.school_id && profile.sfa.is_user && profile.sfa.eligible_for_school_team)
    .sort((a, b) => assignmentScore(b) - assignmentScore(a) || a.display_name.localeCompare(b.display_name));
  const teams: Array<Record<string, unknown>> = [];
  const membership: Record<string, Record<string, unknown>> = {};
  for (const [index, profile] of eligible.entries()) {
    const teamIndex = Math.floor(index / SFA_ROSTER_BLOCK_SIZE);
    const rosterSlot = index % SFA_ROSTER_BLOCK_SIZE;
    teams[teamIndex] ??= {
      team_id: `${school.school_id}_team_${String(teamIndex).padStart(2, "0")}`,
      team_index: teamIndex,
      team_label: teamIndex === 0 ? "Varsity" : teamIndex === 1 ? "JV" : `JV${teamIndex + 1}`,
      roster_limit: SFA_ROSTER_BLOCK_SIZE,
      roster: []
    };
    const team = teams[teamIndex]!;
    const roster = team.roster as Array<Record<string, unknown>>;
    roster.push({
      player_id: profile.player_id,
      display_name: profile.display_name,
      roster_slot: rosterSlot,
      assignment_score: assignmentScore(profile)
    });
    membership[profile.player_id] = {
      school_id: school.school_id,
      team_id: String(team.team_id),
      team_index: teamIndex,
      team_label: String(team.team_label),
      roster_slot: rosterSlot
    };
  }
  const attested: Record<string, string[]> = {};
  for (const profile of profiles) {
    if (profile.sfa.school_id !== school.school_id || !profile.sfa.school_enrollment_attested) {
      continue;
    }
    const year = normalizeSchoolYear(profile.sfa.current_school_year_attested);
    attested[year] ??= [];
    if (!attested[year]!.includes(profile.player_id)) {
      attested[year]!.push(profile.player_id);
    }
  }
  return recalculateSchoolHiveReview({ ...school, teams, membership_by_player_id: membership, attested_player_ids_by_school_year: attested });
}

export function recalculateSchoolHiveReview(school: SchoolProgram): SchoolProgram {
  const out = structuredClone(school);
  let status = cleanText(out.school_hive_review_status || "SELF_REPORTED", 32).toUpperCase();
  if (out.material_dispute_open) {
    status = "DISPUTED";
  }
  out.school_hive_review_status = status;
  out.public_school_name = status === "APPROVED"
    ? cleanText(out.canonical_school_name || out.school_name || "Pending School", 96)
    : "Pending School";
  out.hive_bonus_eligible = false;
  out.hive_bonus_locked_reason = "pending_review";
  if (status === "APPROVED") {
    const rosterIds = Object.keys(out.membership_by_player_id);
    const attestedIds = out.attested_player_ids_by_school_year[normalizeSchoolYear(out.review_school_year)] ?? [];
    const missing = rosterIds.some((playerId) => !attestedIds.includes(playerId));
    if (rosterIds.length === 0) {
      out.hive_bonus_locked_reason = "empty_roster";
    } else if (missing) {
      out.hive_bonus_locked_reason = "missing_roster_attestations";
    } else {
      out.hive_bonus_eligible = true;
      out.hive_bonus_locked_reason = "";
    }
  } else if (status === "DISPUTED") {
    out.hive_bonus_locked_reason = "material_dispute_open";
  } else if (status === "REJECTED") {
    out.hive_bonus_locked_reason = "review_rejected";
  }
  return out;
}

export function recalculateCollegeMembership(program: CollegeProgram, profiles: ScholasticProfile[]): CollegeProgram {
  const membership: Record<string, Record<string, unknown>> = {};
  const attested: Record<string, string[]> = {};
  for (const profile of profiles) {
    if (profile.sfu.college_program_id !== program.college_program_id || !profile.sfu.program_affiliation_attested) {
      continue;
    }
    membership[profile.player_id] = { college_program_id: program.college_program_id, sfu_status: profile.sfu.sfu_status };
    const year = normalizeSchoolYear(profile.sfu.affiliation_school_year);
    attested[year] ??= [];
    attested[year]!.push(profile.player_id);
  }
  return { ...program, membership_by_player_id: membership, attested_player_ids_by_school_year: attested };
}

export function applySchoolAttestation(profile: ScholasticProfile, schoolId: string, attestation: Record<string, unknown>): { ok: boolean; reason?: string; profile: ScholasticProfile } {
  const next = normalizeProfile(structuredClone(profile));
  if (!toBool(attestation.attested_enrolled)) {
    return { ok: false, reason: "school_enrollment_attestation_required", profile: next };
  }
  const schoolYear = normalizeSchoolYear(attestation.school_year);
  const freshmanYear = normalizeSchoolYear(attestation.freshman_school_year || schoolYear);
  next.sfa.school_id = normalizeId(schoolId);
  next.sfa.school_enrollment_attested = true;
  next.sfa.school_enrollment_attested_at_unix = nowUnix();
  next.sfa.current_school_year_attested = schoolYear;
  next.sfa.school_attestation_expires_school_year = schoolYearFromStartYear(schoolYearStartYear(schoolYear) + 1);
  next.sfa.freshman_school_year = freshmanYear;
  next.sfa.sfa_eligibility_end_start_year = sfaEligibilityEndStartYear(freshmanYear);
  if (!isSfaEligibleSchoolYear(freshmanYear, schoolYear)) {
    next.sfa.is_user = false;
    next.sfa.eligible_for_school_team = false;
    next.sfa.eligibility_status = "EXPIRED";
    next.sfa.transition_status = "EXPIRED";
    return { ok: false, reason: "sfa_four_school_year_limit_exceeded", profile: normalizeProfile(next) };
  }
  next.sfa.is_candidate = true;
  next.sfa.is_user = true;
  next.sfa.eligible_for_school_team = true;
  return { ok: true, profile: normalizeProfile(next) };
}

export function newTournament(ecosystem: "SFA" | "SFU", tournamentId: string, tournamentType: string, title: string, config: Record<string, unknown> = {}): ScholasticTournament {
  const cleanId = normalizeId(tournamentId || `${ecosystem}_${tournamentType}_${nowUnix()}`);
  if (ecosystem === "SFA") {
    return {
      tournament_id: cleanId,
      ecosystem,
      tournament_type: cleanText(tournamentType || "REGIONAL", 32).toUpperCase(),
      title: cleanText(title, 96),
      real_money_prizes_allowed: false,
      counts_for_sfa_progression: true,
      created_at_unix: nowUnix()
    };
  }
  return {
    tournament_id: cleanId,
    ecosystem,
    tournament_type: cleanText(tournamentType || "CAMPUS", 32).toUpperCase(),
    title: cleanText(title, 96),
    buffs_allowed: toBool(config.buffs_allowed),
    cash_prizes_allowed: toBool(config.cash_prizes_allowed),
    entry_fee_allowed: toBool(config.entry_fee_allowed),
    program_roster_required: config.program_roster_required == null ? true : toBool(config.program_roster_required),
    official_sfu_event: config.official_sfu_event == null ? true : toBool(config.official_sfu_event),
    created_at_unix: nowUnix()
  };
}

export function assignmentScore(profile: ScholasticProfile): number {
  const competitive = toRecord(profile.competitive);
  return Number(competitive.mmr ?? 1000) + Number(competitive.tier_index ?? 0) * 10_000 + Math.max(0, 100_000 - Number(competitive.rank_position ?? 100_000));
}

export function sanitizeStringArray(raw: unknown, maxCount: number, maxLen: number): string[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const out: string[] = [];
  for (const item of raw) {
    const clean = cleanText(item, maxLen);
    if (clean && !out.includes(clean)) {
      out.push(clean);
    }
    if (out.length >= maxCount) {
      break;
    }
  }
  return out;
}
