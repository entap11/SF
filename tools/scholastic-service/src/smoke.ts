import {
  createTournament,
  fileEnrollmentComplaint,
  joinCollegeProgram,
  metricsSummary,
  recordTournamentResult,
  recordActivity,
  registerCollegeProgram,
  registerHighSchool,
  reportAge,
  reviewSchoolHive
} from "./actions.js";
import { InMemoryScholasticStore } from "./store.js";

function assertOk(result: Record<string, unknown>, label: string): void {
  if (result.ok !== true) {
    throw new Error(`${label} failed: ${String(result.reason ?? result.err ?? "unknown")}`);
  }
}

function assertRejected(result: Record<string, unknown>, label: string): void {
  if (result.ok === true) {
    throw new Error(`${label} should have been rejected`);
  }
}

const store = new InMemoryScholasticStore();
await store.init();

const schoolYear = "2026-2027";
const freshmanSchoolYear = "2026-2027";

await store.write((state, context) => {
  const age = reportAge(state, context, { player_id: "p01", age_years: 16, display_name: "Alpha" });
  assertOk(age, "minor age report");
  const profile = age.profile as Record<string, unknown>;
  const sfa = profile.sfa as Record<string, unknown>;
  if (sfa.is_user === true) {
    throw new Error("minor should not be active SFA before school attestation");
  }
  assertOk(registerHighSchool(state, context, {
    player_id: "p01",
    identity: {
      school_id: "demo_high",
      school_name: "Demo High",
      state: "CA",
      attested_enrolled: true,
      school_year: schoolYear,
      freshman_school_year: freshmanSchoolYear
    }
  }), "register high school");
  if (!state.profiles.p01!.sfa.analytics_package_entitlements.includes("analytics_pack_tier_1")) {
    throw new Error("active SFA student should receive tier 1 analytics entitlement");
  }
  for (let index = 2; index <= 12; index += 1) {
    const playerId = `p${String(index).padStart(2, "0")}`;
    assertOk(reportAge(state, context, { player_id: playerId, age_years: 16, display_name: `Player ${index}` }), `age ${playerId}`);
    assertOk(registerHighSchool(state, context, {
      player_id: playerId,
      identity: {
        school_id: "demo_high",
        school_name: "Demo High",
        attested_enrolled: true,
        school_year: schoolYear,
        freshman_school_year: freshmanSchoolYear
      }
    }), `join ${playerId}`);
  }
  assertOk(reviewSchoolHive(state, context, {
    school_id: "demo_high",
    approved: true,
    identity: { canonical_school_name: "Demo High", school_year: schoolYear }
  }), "review school hive");
  const school = state.schools.demo_high!;
  if (!school.hive_bonus_eligible) {
    throw new Error(`expected hive bonus eligibility, got ${school.hive_bonus_locked_reason}`);
  }
  assertOk(reportAge(state, context, { player_id: "p26", age_years: 16, display_name: "Fifth Year" }), "fifth-year age report");
  assertRejected(registerHighSchool(state, context, {
    player_id: "p26",
    identity: {
      school_id: "demo_high",
      school_name: "Demo High",
      attested_enrolled: true,
      school_year: "2030-2031",
      freshman_school_year: freshmanSchoolYear
    }
  }), "fifth-year SFA attestation");
  assertOk(fileEnrollmentComplaint(state, context, {
    reporter_player_id: "p02",
    target_player_id: "p01",
    reason: "not enrolled"
  }), "file complaint");
  if (state.schools.demo_high!.hive_bonus_eligible) {
    throw new Error("disputed school should not stay bonus eligible");
  }

  assertOk(registerCollegeProgram(state, context, {
    identity: {
      college_program_id: "demo_u",
      university_name: "Demo University",
      program_type: "COLLEGE",
      state: "CA"
    }
  }), "register college");
  assertRejected(joinCollegeProgram(state, context, {
    player_id: "p01",
    program_id: "demo_u",
    attestation: { attested_affiliated: true, school_year: schoolYear }
  }), "minor SFU join");
  assertOk(reportAge(state, context, { player_id: "adult01", age_years: 19, display_name: "Adult One" }), "adult age report");
  assertOk(joinCollegeProgram(state, context, {
    player_id: "adult01",
    program_id: "demo_u",
    attestation: { attested_affiliated: true, school_year: schoolYear }
  }), "adult SFU join");
  assertOk(createTournament(state, context, {
    tournament_id: "campus_no_buffs",
    tournament_type: "CAMPUS",
    title: "Campus No Buffs",
    config: { buffs_allowed: false, cash_prizes_allowed: false }
  }, "SFU"), "create SFU no-buff tournament");
  assertRejected(recordTournamentResult(state, context, {
    player_id: "adult01",
    tournament_id: "campus_no_buffs",
    result: { buffs_used: true }
  }, "SFU"), "no-buff SFU result");
  assertOk(createTournament(state, context, {
    tournament_id: "campus_buff_open",
    tournament_type: "OPEN",
    title: "Campus Buff Open",
    config: { buffs_allowed: true, cash_prizes_allowed: true }
  }, "SFU"), "create SFU buff tournament");
  assertOk(recordTournamentResult(state, context, {
    player_id: "adult01",
    tournament_id: "campus_buff_open",
    result: { buffs_used: true, awards_real_money: true }
  }, "SFU"), "SFU buff cash result");
  assertOk(recordActivity(state, context, {
    event_id: "activity_sfa_p01_day",
    player_id: "p01",
    ecosystem: "SFA",
    event_date: schoolYear.slice(0, 4) + "-09-01",
    duration_seconds: 1800,
    is_new_player: true
  }), "record SFA activity");
  assertOk(recordActivity(state, context, {
    event_id: "activity_open_day",
    player_id: "open01",
    ecosystem: "NONE",
    event_date: schoolYear.slice(0, 4) + "-09-01",
    duration_seconds: 900,
    is_new_player: true
  }), "record gen-pop activity");
  const metrics = metricsSummary(state, new Date("2026-09-01T12:00:00Z"));
  assertOk(metrics, "metrics summary");
  const schools = metrics.schools as Record<string, unknown>;
  if (Number(schools.total) !== 1 || Number(schools.teams_median_per_school) < 1) {
    throw new Error("metrics should include school/team counts");
  }
  const activity = metrics.activity as Record<string, unknown>;
  const day = activity.day as Record<string, unknown>;
  const sfaActivity = day.SFA as Record<string, unknown>;
  if (Number(sfaActivity.avg_minutes_per_active_player) !== 30) {
    throw new Error("metrics should include SFA average minutes");
  }
});

console.log("scholastic-service smoke: PASS");
