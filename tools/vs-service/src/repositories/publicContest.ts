import crypto from "node:crypto";
import {
  DurableCoreError, canonicalJson, isUuidV7, sha256Canonical, type JsonRecord
} from "./durableCore.js";

export type ContestFamily = "TIME_PUZZLE" | "GAUNTLET" | "ASYNC_MAP_SET";
export type ContestScope = "WEEKLY" | "MONTHLY" | "SEASONAL" | "ROLLING_COHORT";
export type ContestStatus = "SCHEDULED" | "OPEN" | "FINALIZING" | "CLOSED";
export type ContestComparator = "TIME_TOTAL_V1" | "GAUNTLET_STARS_V1";
export type BestEntryPolicy = "BEST_PER_PLAYER" | "ONLY_SCORED_ATTEMPT";

export type PublicContestDefinition = {
  contestId: string;
  leaderboardId: string;
  contestSchemaVersion: 1;
  seriesKey: string;
  generation: number;
  family: ContestFamily;
  scope: ContestScope;
  mapCount: number;
  status: ContestStatus;
  mapPackId: string;
  mapIds: string[];
  contentHashes: JsonRecord;
  simBuildId: string;
  comparatorId: ContestComparator;
  bestEntryPolicy: BestEntryPolicy;
  attemptPolicy: JsonRecord;
  closurePolicy: JsonRecord;
  eligibilityPolicy: JsonRecord;
  startsAt: string;
  endsAt: string;
  createdAt: string;
  openedAt: string | null;
  closedAt: string | null;
  definitionHash: string;
  leaderboardVersion: number;
};

export type PublishContestInput = Omit<PublicContestDefinition,
  "contestId" | "leaderboardId" | "contestSchemaVersion" | "status" | "createdAt" |
  "openedAt" | "closedAt" | "definitionHash" | "leaderboardVersion"> & {
    contestId?: string;
    leaderboardId?: string;
    createdAt: string;
  };

export type ContestRosterEntry = {
  playerId: string;
  displayName: string;
  publicEntapId: string | null;
  joinedAt: string;
};

export type ContestAttempt = {
  attemptId: string;
  contestId: string;
  playerId: string;
  attemptNumber: number;
  definitionHash: string;
  seed: string;
  issuedAt: string;
  submissionDeadlineAt: string;
  grantHash: string;
  status: "ISSUED" | "COMMITTED" | "EXPIRED" | "VOID";
};

export type ContestLeaderboardRow = {
  ordinalPlace: number;
  competitivePlace: number;
  playerId: string;
  displayName: string;
  contestResultId: string;
  qualifiedAt: string;
  result: JsonRecord;
};

export type ContestLeaderboard = {
  leaderboardId: string;
  contestId: string;
  definitionHash: string;
  comparatorId: ContestComparator;
  status: ContestStatus;
  version: number;
  generatedAt: string;
  source: "SERVER_PUBLIC_CONTEST_STORE";
  rows: ContestLeaderboardRow[];
};

export type EnterContestInput = {
  contestId: string;
  playerId: string;
  displayName: string;
  publicEntapId?: string | null;
  requestId: string;
  nowIso: string;
  grantSecret: string;
};

export type TrustedContestResultInput = {
  contestId: string;
  attemptId: string;
  playerId: string;
  submissionId: string;
  definitionHash: string;
  grantHash: string;
  verificationMethod: string;
  evidenceRef: string;
  metrics: JsonRecord;
  qualifiedAt: string;
};

export type ContestResultReceipt = {
  contestResultId: string;
  contestId: string;
  attemptId: string;
  playerId: string;
  result: JsonRecord;
  qualifiedAt: string;
  bestUpdated: boolean;
  leaderboardVersion: number;
  duplicate: boolean;
};

export type ContestMessage = {
  eventId: string;
  contestId: string;
  status: "PENDING" | "DELIVERED";
  payload: JsonRecord;
  availableAt: string;
  deliveredAt: string | null;
};

export type ContestEvidence = {
  evidenceId: string;
  contestId: string;
  attemptId: string;
  playerId: string;
  submissionId: string;
  evidence: JsonRecord;
  status: "PENDING" | "LEASED" | "VERIFIED" | "REJECTED";
  submittedAt: string;
  contestResultId: string | null;
  rejectionCode: string | null;
  duplicate: boolean;
};

export type ContestEvidenceLease = ContestEvidence & {
  workerId: string;
  leaseToken: string;
  leaseExpiresAt: string;
};

export interface PublicContestRepository {
  publish(input: PublishContestInput): Promise<PublicContestDefinition>;
  reconcile(nowIso: string): Promise<{ opened: number; closed: number; rolled: number }>;
  listCurrent(filters: { family?: ContestFamily; scope?: ContestScope; mapCount?: number }, nowIso: string):
    Promise<PublicContestDefinition[]>;
  getDefinition(contestId: string): Promise<PublicContestDefinition>;
  enter(input: EnterContestInput): Promise<{ attempt: ContestAttempt; duplicate: boolean }>;
  getRoster(contestId: string): Promise<ContestRosterEntry[]>;
  commitTrustedResult(input: TrustedContestResultInput): Promise<ContestResultReceipt>;
  getLeaderboard(contestId: string, limit: number, nowIso: string): Promise<ContestLeaderboard>;
  listMessages(playerId: string, limit: number): Promise<ContestMessage[]>;
  acknowledgeMessage(eventId: string, playerId: string, deliveredAt: string): Promise<ContestMessage>;
  submitEvidence(input: { contestId: string; attemptId: string; playerId: string; submissionId: string;
    definitionHash: string; grantHash: string; evidence: JsonRecord; submittedAt: string }): Promise<ContestEvidence>;
  getEvidence(evidenceId: string, playerId: string): Promise<ContestEvidence>;
  leaseNextEvidence(workerId: string, nowIso: string, leaseSec: number): Promise<ContestEvidenceLease | null>;
  resolveEvidence(evidenceId: string, workerId: string, leaseToken: string, resolvedAt: string,
    result: ContestResultReceipt | null, rejectionCode?: string): Promise<ContestEvidence>;
}

export type CompetitiveScore = { primary: number; secondary: number; tertiary: number; result: JsonRecord };

export function validatePublishInput(input: PublishContestInput): void {
  if (input.contestId && !isUuidV7(input.contestId)) throw new DurableCoreError("invalid_contest_id");
  if (input.leaderboardId && !isUuidV7(input.leaderboardId)) throw new DurableCoreError("invalid_leaderboard_id");
  if (!input.seriesKey.trim() || !input.mapPackId.trim() || !input.simBuildId.trim()) {
    throw new DurableCoreError("invalid_contest_definition");
  }
  if (!Number.isSafeInteger(input.generation) || input.generation < 1
    || !Number.isSafeInteger(input.mapCount) || input.mapCount < 1
    || input.mapIds.length !== input.mapCount
    || input.mapIds.some((mapId) => !mapId.trim())) {
    throw new DurableCoreError("invalid_contest_maps");
  }
  if (!(["TIME_PUZZLE", "GAUNTLET", "ASYNC_MAP_SET"] as string[]).includes(input.family)
    || !(["WEEKLY", "MONTHLY", "SEASONAL", "ROLLING_COHORT"] as string[]).includes(input.scope)
    || !(["TIME_TOTAL_V1", "GAUNTLET_STARS_V1"] as string[]).includes(input.comparatorId)
    || !(["BEST_PER_PLAYER", "ONLY_SCORED_ATTEMPT"] as string[]).includes(input.bestEntryPolicy)) {
    throw new DurableCoreError("invalid_contest_policy");
  }
  if (input.family === "GAUNTLET" && input.comparatorId !== "GAUNTLET_STARS_V1") {
    throw new DurableCoreError("invalid_contest_comparator");
  }
  if (input.family !== "GAUNTLET" && input.comparatorId !== "TIME_TOTAL_V1") {
    throw new DurableCoreError("invalid_contest_comparator");
  }
  const starts = parseIso(input.startsAt, "invalid_contest_starts_at");
  const ends = parseIso(input.endsAt, "invalid_contest_ends_at");
  parseIso(input.createdAt, "invalid_contest_created_at");
  if (ends <= starts) throw new DurableCoreError("invalid_contest_window");
  for (const value of Object.values(input.contentHashes)) {
    if (typeof value !== "string" || !/^[0-9a-f]{64}$/.test(value)) {
      throw new DurableCoreError("invalid_content_hash");
    }
  }
  const closureKind = stringValue(input.closurePolicy.kind);
  if (closureKind !== "SERVER_TIME") throw new DurableCoreError("contest_closure_policy_unsupported");
  const rollover = input.closurePolicy.rollover_interval_sec;
  if (rollover != null && (!Number.isSafeInteger(rollover) || Number(rollover) < 1)) {
    throw new DurableCoreError("invalid_contest_rollover");
  }
}

export function definitionDocument(input: PublishContestInput, ids: {
  contestId: string; leaderboardId: string;
}): JsonRecord {
  return {
    contest_id: ids.contestId,
    leaderboard_id: ids.leaderboardId,
    contest_schema_version: 1,
    series_key: input.seriesKey,
    generation: input.generation,
    family: input.family,
    scope: input.scope,
    map_count: input.mapCount,
    map_pack_id: input.mapPackId,
    map_ids: [...input.mapIds],
    content_hashes: input.contentHashes,
    sim_build_id: input.simBuildId,
    comparator_id: input.comparatorId,
    best_entry_policy: input.bestEntryPolicy,
    attempt_policy: input.attemptPolicy,
    closure_policy: input.closurePolicy,
    eligibility_policy: input.eligibilityPolicy,
    starts_at: input.startsAt,
    ends_at: input.endsAt
  };
}

export function scoreVerifiedResult(comparator: ContestComparator, mapIds: string[], metrics: JsonRecord,
  attemptPolicy: JsonRecord = {}): CompetitiveScore {
  if (comparator === "TIME_TOTAL_V1") {
    const perMap = Array.isArray(metrics.per_map) ? metrics.per_map : [];
    if (perMap.length !== mapIds.length) throw new DurableCoreError("contest_result_incomplete");
    let aggregate = 0;
    const normalized = perMap.map((raw, index) => {
      const row = recordValue(raw);
      const mapId = stringValue(row.map_id);
      const elapsed = safeNonnegativeInteger(row.elapsed_ticks, "invalid_contest_elapsed_ticks");
      const penalty = safeNonnegativeInteger(row.penalty_ticks ?? 0, "invalid_contest_penalty_ticks");
      if (row.completed !== true || mapId !== mapIds[index]) throw new DurableCoreError("contest_result_incomplete");
      aggregate = safeSum(aggregate, elapsed, penalty);
      return { map_id: mapId, completed: true, elapsed_ticks: elapsed, penalty_ticks: penalty };
    });
    if (metrics.aggregate_elapsed_ticks != null
      && safeNonnegativeInteger(metrics.aggregate_elapsed_ticks, "invalid_contest_aggregate") !== aggregate) {
      throw new DurableCoreError("contest_aggregate_mismatch");
    }
    return {
      primary: -aggregate, secondary: 0, tertiary: 0,
      result: { per_map: normalized, aggregate_elapsed_ticks: aggregate }
    };
  }
  const stagePlan = Array.isArray(attemptPolicy.stage_plan) ? attemptPolicy.stage_plan : [];
  if (stagePlan.length > 0) return scoreGauntletEvidence(stagePlan, metrics);
  const stars = safeNonnegativeInteger(metrics.stars, "invalid_gauntlet_stars");
  const stages = safeNonnegativeInteger(metrics.completed_stage_count, "invalid_gauntlet_stages");
  const elapsed = safeNonnegativeInteger(metrics.elapsed_ticks, "invalid_gauntlet_elapsed_ticks");
  return {
    primary: stars, secondary: stages, tertiary: -elapsed,
    result: { stars, completed_stage_count: stages, elapsed_ticks: elapsed }
  };
}

function scoreGauntletEvidence(stagePlan: unknown[], metrics: JsonRecord): CompetitiveScore {
  const evidence = Array.isArray(metrics.stage_evidence) ? metrics.stage_evidence : [];
  if (evidence.length < 1 || evidence.length > stagePlan.length) {
    throw new DurableCoreError("gauntlet_stage_evidence_incomplete");
  }
  let stars = 0;
  let completedStages = 0;
  let elapsedTicks = 0;
  const normalized: JsonRecord[] = [];
  let terminalSeen = false;
  for (let index = 0; index < evidence.length; index += 1) {
    const stage = recordValue(stagePlan[index]);
    const row = recordValue(evidence[index]);
    const stageNumber = safeNonnegativeInteger(row.stage_number, "invalid_gauntlet_stage_number");
    if (stageNumber !== index + 1 || Number(stage.stage_number) !== stageNumber
      || stringValue(row.map_id) !== stringValue(stage.map_id) || terminalSeen) {
      throw new DurableCoreError("gauntlet_stage_evidence_mismatch");
    }
    const ticks = safeNonnegativeInteger(row.elapsed_ticks, "invalid_gauntlet_elapsed_ticks");
    elapsedTicks = safeSum(elapsedTicks, ticks);
    const won = row.won === true;
    const reason = stringValue(row.win_reason).toLowerCase();
    const thresholds = recordValue(stage.thresholds_ms);
    const stageStars = won ? starsForElapsed(ticks * 100, thresholds, reason) : 0;
    if (won && stageStars > 0) completedStages += 1;
    else terminalSeen = true;
    stars = safeSum(stars, stageStars);
    normalized.push({ stage_number: stageNumber, map_id: stringValue(row.map_id),
      elapsed_ticks: ticks, won, win_reason: reason, stars: stageStars,
      final_state_hash: stringValue(row.final_state_hash), command_log_hash: stringValue(row.command_log_hash) });
  }
  if (!terminalSeen && evidence.length < stagePlan.length) {
    throw new DurableCoreError("gauntlet_stage_evidence_incomplete");
  }
  return { primary: stars, secondary: completedStages, tertiary: -elapsedTicks,
    result: { stars, completed_stage_count: completedStages, elapsed_ticks: elapsedTicks,
      stage_evidence: normalized } };
}

function starsForElapsed(elapsedMs: number, thresholds: JsonRecord, reason: string): number {
  if (!["", "domination", "capture_all", "conquest", "elimination"].includes(reason)) return 0;
  const four = safeNonnegativeInteger(thresholds.four_star_ms, "invalid_gauntlet_thresholds");
  const three = safeNonnegativeInteger(thresholds.three_star_ms, "invalid_gauntlet_thresholds");
  const two = safeNonnegativeInteger(thresholds.two_star_ms, "invalid_gauntlet_thresholds");
  if (!(four < three && three < two)) throw new DurableCoreError("invalid_gauntlet_thresholds");
  if (elapsedMs <= four) return 4;
  if (elapsedMs <= three) return 3;
  if (elapsedMs <= two) return 2;
  return 1;
}

export function grantHash(secret: string, grant: JsonRecord): string {
  if (secret.length < 32) throw new DurableCoreError("contest_grant_secret_not_configured");
  return crypto.createHmac("sha256", secret).update(canonicalJson(grant), "utf8").digest("hex");
}

export function resultRequestHash(input: TrustedContestResultInput): string {
  return sha256Canonical({
    contest_id: input.contestId, attempt_id: input.attemptId, player_id: input.playerId,
    submission_id: input.submissionId, definition_hash: input.definitionHash,
    grant_hash: input.grantHash, verification_method: input.verificationMethod,
    evidence_ref: input.evidenceRef, metrics: input.metrics
  });
}

export function isBetterScore(candidate: CompetitiveScore & { qualifiedAt: string }, existing: {
  primary: number; secondary: number; tertiary: number; qualifiedAt: string;
}): boolean {
  if (candidate.primary !== existing.primary) return candidate.primary > existing.primary;
  if (candidate.secondary !== existing.secondary) return candidate.secondary > existing.secondary;
  if (candidate.tertiary !== existing.tertiary) return candidate.tertiary > existing.tertiary;
  return candidate.qualifiedAt < existing.qualifiedAt;
}

export function parseIso(value: string, code: string): number {
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed) || new Date(parsed).toISOString() !== value) throw new DurableCoreError(code);
  return parsed;
}

function safeNonnegativeInteger(value: unknown, code: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw new DurableCoreError(code);
  return value;
}

function safeSum(...values: number[]): number {
  const sum = values.reduce((total, value) => total + value, 0);
  if (!Number.isSafeInteger(sum)) throw new DurableCoreError("contest_score_overflow");
  return sum;
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function recordValue(value: unknown): JsonRecord {
  return typeof value === "object" && value != null && !Array.isArray(value) ? value as JsonRecord : {};
}
