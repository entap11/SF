import crypto from "node:crypto";
import type { Request, Response } from "express";
import { config } from "./config.js";
import { DurableCoreError, type JsonRecord } from "./repositories/durableCore.js";
import { getPublicContestRepository } from "./repositories/durableCoreRuntime.js";
import type { ContestFamily, ContestScope, PublishContestInput } from "./repositories/publicContest.js";
import { bearerPlayerToken, PlayerAuthError, verifyPlayerToken } from "./playerAuth.js";
import { buildTimeGauntletPeriodInputs } from "./publicContestPeriods.js";
import { buildAsyncCohortInputs } from "./publicAsyncCohorts.js";
import { effectivePublicRollout } from "./publicModesOpsHttp.js";
import type { PublicRolloutFlags } from "./repositories/publicModesOps.js";

const ACTIONS = new Set([
  "list_public_contests", "get_public_contest_roster", "enter_public_contest",
  "submit_public_contest_result", "get_public_contest_leaderboard",
  "list_public_contest_messages", "ack_public_contest_message",
  "submit_public_contest_evidence", "get_public_contest_evidence",
  "lease_public_contest_evidence", "complete_public_contest_evidence", "reject_public_contest_evidence",
  "publish_public_contest", "publish_public_time_gauntlet_periods", "publish_public_async_cohorts",
  "reconcile_public_contests"
]);

export async function handlePublicContestAction(action: string, req: Request, res: Response): Promise<boolean> {
  if (!ACTIONS.has(action)) return false;
  if (!config.enablePublicContests || !config.durableCoreEnabled || config.durableStore !== "postgres"
    || !config.databaseUrl) {
    fail(res, "public_contests_disabled", 503);
    return true;
  }
  if (config.publicContestGrantSecret.length < 32) {
    fail(res, "contest_grant_secret_not_configured", 503);
    return true;
  }
  const repository = getPublicContestRepository();
  const nowIso = new Date().toISOString();
  try {
    const rollout = await effectivePublicRollout(nowIso);
    if (!["publish_public_contest", "publish_public_time_gauntlet_periods", "publish_public_async_cohorts",
      "reconcile_public_contests", "lease_public_contest_evidence", "complete_public_contest_evidence",
      "reject_public_contest_evidence"].includes(action)) {
      requireMinimumClientBuild(rollout.minSupportedBuild, text(req.body?.client_build));
    }
    switch (action) {
      case "list_public_contests": {
        const family = optionalFamily(req.body?.family);
        const scope = optionalScope(req.body?.scope);
        const mapCount = optionalPositiveInteger(req.body?.map_count);
        const contests = (await repository.listCurrent({ family, scope, mapCount }, nowIso))
          .filter((definition) => familyEnabled(definition, rollout.flags));
        ok(res, { contests: contests.map(definitionJson),
          server_time: nowIso, source: "SERVER_PUBLIC_CONTEST_STORE" });
        return true;
      }
      case "get_public_contest_roster": {
        ok(res, { contest_id: text(req.body?.contest_id),
          roster: (await repository.getRoster(text(req.body?.contest_id))).map((entry) => ({
            player_id: entry.playerId, display_name: entry.displayName,
            public_entap_id: entry.publicEntapId, joined_at: entry.joinedAt
          })), source: "SERVER_PUBLIC_CONTEST_STORE" });
        return true;
      }
      case "get_public_contest_leaderboard": {
        if (!rollout.flags.enable_public_leaderboards) throw new ContestHttpError("public_leaderboards_disabled", 503);
        requireFamilyEnabled(await repository.getDefinition(text(req.body?.contest_id)), rollout.flags);
        const board = await repository.getLeaderboard(text(req.body?.contest_id),
          Math.min(config.publicContestLeaderboardLimit, optionalPositiveInteger(req.body?.limit) ?? config.publicContestLeaderboardLimit),
          nowIso);
        ok(res, leaderboardJson(board));
        return true;
      }
      case "enter_public_contest": {
        const player = authenticatedPlayer(req);
        rejectConflictingIdentity(req, player.playerId);
        requireFamilyEnabled(await repository.getDefinition(text(req.body?.contest_id)), rollout.flags);
        const result = await repository.enter({
          contestId: text(req.body?.contest_id), playerId: player.playerId,
          displayName: player.displayName || `Player_${player.playerId.slice(-6)}`,
          publicEntapId: player.entapId || null, requestId: requestKey(req), nowIso,
          grantSecret: config.publicContestGrantSecret
        });
        ok(res, { attempt: attemptJson(result.attempt), duplicate: result.duplicate,
          source: "SERVER_PUBLIC_CONTEST_STORE" });
        return true;
      }
      case "submit_public_contest_evidence": {
        const player = authenticatedPlayer(req);
        rejectConflictingIdentity(req, player.playerId);
        requireFamilyEnabled(await repository.getDefinition(text(req.body?.contest_id)), rollout.flags);
        const evidence = await repository.submitEvidence({
          contestId: text(req.body?.contest_id), attemptId: text(req.body?.attempt_id),
          playerId: player.playerId, submissionId: requestKey(req),
          definitionHash: text(req.body?.definition_hash), grantHash: text(req.body?.grant_hash),
          evidence: record(req.body?.evidence), submittedAt: nowIso
        });
        ok(res, { evidence: evidenceJson(evidence), source: "SERVER_PUBLIC_CONTEST_STORE" });
        return true;
      }
      case "get_public_contest_evidence": {
        const player = authenticatedPlayer(req);
        rejectConflictingIdentity(req, player.playerId);
        ok(res, { evidence: evidenceJson(await repository.getEvidence(
          text(req.body?.evidence_id), player.playerId)), source: "SERVER_PUBLIC_CONTEST_STORE" });
        return true;
      }
      case "submit_public_contest_result": {
        requireMatchAuthority(req);
        const result = await repository.commitTrustedResult({
          contestId: text(req.body?.contest_id), attemptId: text(req.body?.attempt_id),
          playerId: text(req.body?.player_id), submissionId: requestKey(req),
          definitionHash: text(req.body?.definition_hash), grantHash: text(req.body?.grant_hash),
          verificationMethod: text(req.body?.verification_method), evidenceRef: text(req.body?.evidence_ref),
          metrics: record(req.body?.metrics), qualifiedAt: nowIso
        });
        ok(res, { contest_result_id: result.contestResultId, contest_id: result.contestId,
          attempt_id: result.attemptId, player_id: result.playerId, result: result.result,
          qualified_at: result.qualifiedAt, best_updated: result.bestUpdated,
          leaderboard_version: result.leaderboardVersion, duplicate: result.duplicate });
        return true;
      }
      case "list_public_contest_messages": {
        const player = authenticatedPlayer(req);
        rejectConflictingIdentity(req, player.playerId);
        const messages = await repository.listMessages(player.playerId,
          optionalPositiveInteger(req.body?.limit) ?? 25);
        ok(res, { messages: messages.map(messageJson), source: "SERVER_PUBLIC_CONTEST_STORE" });
        return true;
      }
      case "ack_public_contest_message": {
        const player = authenticatedPlayer(req);
        rejectConflictingIdentity(req, player.playerId);
        ok(res, { message: messageJson(await repository.acknowledgeMessage(
          text(req.body?.event_id), player.playerId, nowIso)) });
        return true;
      }
      case "publish_public_contest": {
        requireAdmin(req);
        ok(res, { contest: definitionJson(await repository.publish(publishInput(req.body, nowIso))) });
        return true;
      }
      case "publish_public_time_gauntlet_periods": {
        requireAdmin(req);
        const definitions = buildTimeGauntletPeriodInputs(record(req.body), nowIso);
        const contests = [];
        for (const definition of definitions) contests.push(await repository.publish(definition));
        ok(res, { contests: contests.map(definitionJson), catalog_schema: "swarmfront.public_contest_catalog.v1" });
        return true;
      }
      case "publish_public_async_cohorts": {
        requireAdmin(req);
        const definitions = buildAsyncCohortInputs(record(req.body), nowIso);
        const contests = [];
        for (const definition of definitions) contests.push(await repository.publish(definition));
        ok(res, { contests: contests.map(definitionJson), payouts: [] });
        return true;
      }
      case "reconcile_public_contests": {
        requireAdmin(req);
        ok(res, { ...(await repository.reconcile(nowIso)), server_time: nowIso });
        return true;
      }
      case "lease_public_contest_evidence": {
        requireWorker(req);
        const workerId = workerIdentity(req);
        const job = await repository.leaseNextEvidence(workerId, nowIso, config.verifierLeaseSec);
        ok(res, { job: job ? evidenceLeaseJson(job) : null });
        return true;
      }
      case "complete_public_contest_evidence": {
        requireWorker(req);
        const workerId = workerIdentity(req);
        const evidenceId = text(req.body?.evidence_id);
        const leased = await repository.getEvidence(evidenceId, text(req.body?.player_id));
        if (leased.status !== "LEASED") throw new DurableCoreError("contest_evidence_lease_conflict");
        const authority = record(leased.evidence);
        const result = await repository.commitTrustedResult({
          contestId: leased.contestId, attemptId: leased.attemptId, playerId: leased.playerId,
          submissionId: `verified:${evidenceId}`, definitionHash: text(authority.definition_hash),
          grantHash: text(authority.grant_hash), verificationMethod: "SERVER_SIM_V1",
          evidenceRef: evidenceId, metrics: record(req.body?.metrics), qualifiedAt: leased.submittedAt
        });
        const resolved = await repository.resolveEvidence(evidenceId, workerId,
          text(req.body?.lease_token), nowIso, result);
        ok(res, { evidence: evidenceJson(resolved), contest_result_id: result.contestResultId,
          leaderboard_version: result.leaderboardVersion });
        return true;
      }
      case "reject_public_contest_evidence": {
        requireWorker(req);
        const workerId = workerIdentity(req);
        const resolved = await repository.resolveEvidence(text(req.body?.evidence_id), workerId,
          text(req.body?.lease_token), nowIso, null, text(req.body?.rejection_code));
        ok(res, { evidence: evidenceJson(resolved) });
        return true;
      }
      default:
        return false;
    }
  } catch (error) {
    if (error instanceof PlayerAuthError) fail(res, error.code, error.status);
    else if (error instanceof DurableCoreError) fail(res, error.code, statusFor(error.code));
    else if (error instanceof ContestHttpError) fail(res, error.code, error.status);
    else throw error;
    return true;
  }
}

function authenticatedPlayer(req: Request) {
  const token = bearerPlayerToken(req.header("authorization"));
  if (!token) throw new PlayerAuthError("player_token_required", 401);
  return verifyPlayerToken(token, {
    issuer: config.playerTokenIssuer, audience: config.playerTokenAudience,
    keyId: config.playerTokenKeyId, publicKeyPem: config.playerTokenPublicKeyPem
  }, "contest:play");
}

function requireAdmin(req: Request): void {
  if (!config.adminToken || req.header("x-admin-token") !== config.adminToken
    || req.header("x-admin-role") !== config.adminRole) throw new ContestHttpError("admin_unauthorized", 401);
}

function requireMatchAuthority(req: Request): void {
  if (!config.matchAuthorityToken || req.header("x-match-authority-token") !== config.matchAuthorityToken) {
    throw new ContestHttpError("match_authority_unauthorized", 401);
  }
}

function requireWorker(req: Request): void {
  if (!config.verifierWorkerToken) throw new ContestHttpError("verifier_worker_not_configured", 503);
  const expected = Buffer.from(config.verifierWorkerToken, "utf8");
  const actual = Buffer.from(text(req.header("x-verifier-worker-token")), "utf8");
  if (actual.length !== expected.length || !crypto.timingSafeEqual(actual, expected)) {
    throw new ContestHttpError("verifier_worker_unauthorized", 401);
  }
}

function workerIdentity(req: Request): string {
  const workerId = text(req.body?.worker_id);
  if (!workerId || workerId.length > 128) throw new DurableCoreError("worker_id_required");
  return workerId;
}

function familyEnabled(definition: { family: ContestFamily; mapCount: number }, flags: PublicRolloutFlags): boolean {
  if (definition.family === "TIME_PUZZLE") return flags.enable_public_time_puzzles;
  if (definition.family === "GAUNTLET") return flags.enable_public_gauntlet;
  return definition.mapCount === 3 ? flags.enable_public_async_3map
    : definition.mapCount === 5 ? flags.enable_public_async_5map : false;
}

function requireFamilyEnabled(definition: { family: ContestFamily; mapCount: number }, flags: PublicRolloutFlags): void {
  if (!familyEnabled(definition, flags)) throw new ContestHttpError("public_contest_family_disabled", 503);
}

function rejectConflictingIdentity(req: Request, playerId: string): void {
  const supplied = text(req.body?.player_id ?? req.body?.uid);
  if (supplied && supplied !== playerId) throw new PlayerAuthError("identity_mismatch", 403);
}

function requireMinimumClientBuild(minimum: number, clientBuild: string): void {
  if (minimum <= 0) return;
  const parsed = Number.parseInt(clientBuild, 10);
  if (!Number.isSafeInteger(parsed) || parsed < minimum) throw new ContestHttpError("minimum_client_build_required", 426);
}

function publishInput(body: unknown, nowIso: string): PublishContestInput {
  const value = record(body);
  return {
    contestId: optionalText(value.contest_id), leaderboardId: optionalText(value.leaderboard_id),
    seriesKey: text(value.series_key), generation: positiveInteger(value.generation),
    family: requiredFamily(value.family), scope: requiredScope(value.scope),
    mapCount: positiveInteger(value.map_count), mapPackId: text(value.map_pack_id),
    mapIds: stringArray(value.map_ids), contentHashes: record(value.content_hashes),
    simBuildId: text(value.sim_build_id), comparatorId: comparator(value.comparator_id),
    bestEntryPolicy: text(value.best_entry_policy) as PublishContestInput["bestEntryPolicy"],
    attemptPolicy: record(value.attempt_policy), closurePolicy: record(value.closure_policy),
    eligibilityPolicy: record(value.eligibility_policy), startsAt: text(value.starts_at),
    endsAt: text(value.ends_at), createdAt: nowIso
  };
}

function definitionJson(value: Awaited<ReturnType<ReturnType<typeof getPublicContestRepository>["getDefinition"]>>) {
  return {
    contest_id: value.contestId, leaderboard_id: value.leaderboardId,
    contest_schema_version: value.contestSchemaVersion, series_key: value.seriesKey,
    generation: value.generation, family: value.family, scope: value.scope, map_count: value.mapCount,
    status: value.status, map_pack_id: value.mapPackId, map_ids: value.mapIds,
    content_hashes: value.contentHashes, sim_build_id: value.simBuildId,
    comparator_id: value.comparatorId, best_entry_policy: value.bestEntryPolicy,
    attempt_policy: value.attemptPolicy, closure_policy: value.closurePolicy,
    eligibility_policy: value.eligibilityPolicy, starts_at: value.startsAt, ends_at: value.endsAt,
    created_at: value.createdAt, opened_at: value.openedAt, closed_at: value.closedAt,
    definition_hash: value.definitionHash, leaderboard_version: value.leaderboardVersion
  };
}

function attemptJson(value: Awaited<ReturnType<ReturnType<typeof getPublicContestRepository>["enter"]>>["attempt"]) {
  return {
    attempt_id: value.attemptId, contest_id: value.contestId, player_id: value.playerId,
    attempt_number: value.attemptNumber, definition_hash: value.definitionHash, seed: value.seed,
    issued_at: value.issuedAt, submission_deadline_at: value.submissionDeadlineAt,
    grant_hash: value.grantHash, status: value.status
  };
}

function leaderboardJson(value: Awaited<ReturnType<ReturnType<typeof getPublicContestRepository>["getLeaderboard"]>>) {
  return {
    leaderboard_id: value.leaderboardId, contest_id: value.contestId,
    definition_hash: value.definitionHash, comparator_id: value.comparatorId, status: value.status,
    version: value.version, generated_at: value.generatedAt, source: value.source,
    rows: value.rows.map((row) => ({ ordinal_place: row.ordinalPlace,
      competitive_place: row.competitivePlace, player_id: row.playerId,
      display_name: row.displayName, contest_result_id: row.contestResultId,
      qualified_at: row.qualifiedAt, result: row.result }))
  };
}

function messageJson(value: Awaited<ReturnType<ReturnType<typeof getPublicContestRepository>["acknowledgeMessage"]>>) {
  return { event_id: value.eventId, contest_id: value.contestId, status: value.status,
    payload: value.payload, available_at: value.availableAt, delivered_at: value.deliveredAt };
}

function evidenceJson(value: Awaited<ReturnType<ReturnType<typeof getPublicContestRepository>["getEvidence"]>>) {
  return { evidence_id: value.evidenceId, contest_id: value.contestId, attempt_id: value.attemptId,
    player_id: value.playerId, submission_id: value.submissionId, evidence: value.evidence,
    status: value.status, submitted_at: value.submittedAt, contest_result_id: value.contestResultId,
    rejection_code: value.rejectionCode, duplicate: value.duplicate };
}

function evidenceLeaseJson(value: NonNullable<Awaited<ReturnType<ReturnType<typeof getPublicContestRepository>["leaseNextEvidence"]>>>) {
  return { ...evidenceJson(value), worker_id: value.workerId, lease_token: value.leaseToken,
    lease_expires_at: value.leaseExpiresAt };
}

function optionalFamily(value: unknown): ContestFamily | undefined {
  const raw = text(value).toUpperCase();
  return raw ? requiredFamily(raw) : undefined;
}
function requiredFamily(value: unknown): ContestFamily {
  const raw = text(value).toUpperCase();
  if (["TIME_PUZZLE", "GAUNTLET", "ASYNC_MAP_SET"].includes(raw)) return raw as ContestFamily;
  throw new DurableCoreError("invalid_contest_family");
}
function optionalScope(value: unknown): ContestScope | undefined {
  const raw = text(value).toUpperCase();
  return raw ? requiredScope(raw) : undefined;
}
function requiredScope(value: unknown): ContestScope {
  const raw = text(value).toUpperCase();
  if (["WEEKLY", "MONTHLY", "SEASONAL", "ROLLING_COHORT"].includes(raw)) return raw as ContestScope;
  throw new DurableCoreError("invalid_contest_scope");
}
function comparator(value: unknown): PublishContestInput["comparatorId"] {
  const raw = text(value).toUpperCase();
  if (["TIME_TOTAL_V1", "GAUNTLET_STARS_V1"].includes(raw)) return raw as PublishContestInput["comparatorId"];
  throw new DurableCoreError("invalid_contest_comparator");
}
function requestKey(req: Request): string {
  const key = text(req.body?.request_id ?? req.body?.idempotency_key ?? req.body?.submission_id);
  if (!key || key.length > 256) throw new DurableCoreError("idempotency_key_required");
  return key;
}
function optionalPositiveInteger(value: unknown): number | undefined {
  if (value == null || value === "") return undefined;
  return positiveInteger(value);
}
function positiveInteger(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 1) {
    throw new DurableCoreError("positive_integer_required");
  }
  return value;
}
function stringArray(value: unknown): string[] { return Array.isArray(value) ? value.map(text) : []; }
function record(value: unknown): JsonRecord {
  return typeof value === "object" && value != null && !Array.isArray(value) ? value as JsonRecord : {};
}
function text(value: unknown): string { return typeof value === "string" ? value.trim() : ""; }
function optionalText(value: unknown): string | undefined { const result = text(value); return result || undefined; }
function statusFor(code: string): number {
  if (["contest_not_found", "contest_attempt_not_found", "contest_message_not_found",
    "contest_evidence_not_found"].includes(code)) return 404;
  if (["contest_attempt_identity_mismatch"].includes(code)) return 403;
  if (["idempotency_conflict", "idempotency_in_progress", "contest_not_open",
    "contest_attempt_already_committed", "contest_player_already_scored",
    "contest_definition_conflict"].includes(code)) return 409;
  if (["contest_grant_secret_not_configured", "verifier_worker_not_configured"].includes(code)) return 503;
  return 400;
}
function ok(res: Response, body: JsonRecord): void { res.json({ ok: true, ...body }); }
function fail(res: Response, code: string, status: number): void { res.status(status).json({ ok: false, err: code }); }
class ContestHttpError extends Error {
  constructor(readonly code: string, readonly status: number) { super(code); }
}
