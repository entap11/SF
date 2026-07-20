import crypto from "node:crypto";
import type { Request, Response } from "express";
import { config } from "./config.js";
import { bearerPlayerToken, PlayerAuthError, verifyPlayerToken } from "./playerAuth.js";
import { DurableCoreError, type JsonRecord } from "./repositories/durableCore.js";
import { getRankSettlementRepository, getVerificationRepository } from "./repositories/durableCoreRuntime.js";
import { reconcileRankSettlements } from "./rankSettlementProcessor.js";
import type { SignedSyncResult } from "./repositories/verificationAuthority.js";

const PLAYER_ACTIONS = new Set(["submit_public_1v1_terminal_report", "get_public_1v1_result"]);
const WORKER_ACTIONS = new Set(["lease_match_verification", "complete_match_verification", "fail_match_verification"]);

export async function handleVerificationAction(action: string, req: Request, res: Response): Promise<boolean> {
  if (!PLAYER_ACTIONS.has(action) && !WORKER_ACTIONS.has(action)) return false;
  if (!config.matchVerificationEnabled || !config.durablePublic1v1Enabled || !config.durableCoreEnabled) {
    fail(res, "match_verification_disabled", 503);
    return true;
  }
  if (!config.verifierWorkerToken || !config.verifierKeyId || !config.verifierPublicKeyPem
    || !config.verifierWorkerBuildId) {
    fail(res, "match_verification_not_configured", 503);
    return true;
  }
  try {
    const repository = getVerificationRepository();
    const nowIso = new Date().toISOString();
    if (PLAYER_ACTIONS.has(action)) {
      const player = authenticatedPlayer(req);
      rejectConflictingIdentity(req, player.playerId);
      const matchId = text(req.body?.match_id ?? req.body?.session_id);
      if (action === "get_public_1v1_result") {
        if (config.durableStore === "postgres") await reconcileRankSettlements(nowIso);
        ok(res, {
          verification: await repository.getPlayerStatus(matchId, player.playerId),
          rank_settlement: config.durableStore === "postgres"
            ? await getRankSettlementRepository().getForPlayer(matchId, player.playerId) : null
        });
        return true;
      }
      const submitted = await repository.submitClientReport({
        matchId,
        playerId: player.playerId,
        requestId: requestKey(req),
        finalStateHash: text(req.body?.final_state_hash),
        elapsedSimTicks: integer(req.body?.elapsed_sim_ticks),
        claimedTerminalReason: text(req.body?.claimed_terminal_reason),
        claimedWinnerPlayerId: nullableText(req.body?.claimed_winner_player_id),
        diagnostics: record(req.body?.diagnostics),
        submittedAt: nowIso
      });
      ok(res, { report: submitted.report, verification: submitted.status });
      return true;
    }

    requireWorker(req);
    const workerId = text(req.body?.worker_id);
    if (!workerId || workerId.length > 128) throw new DurableCoreError("worker_id_required");
    if (action === "lease_match_verification") {
      ok(res, { job: await repository.leaseNext(workerId, nowIso, config.verifierLeaseSec) });
      return true;
    }
    if (action === "complete_match_verification") {
      const signed = signedResult(req.body?.signed_result);
      const verification = await repository.complete({
        workerId,
        leaseToken: text(req.body?.lease_token),
        jobId: text(req.body?.job_id),
        startedAt: isoOrNow(req.body?.started_at, nowIso),
        finishedAt: nowIso,
        signedResult: signed,
        runDiagnostics: record(req.body?.run_diagnostics)
      }, {
        keyId: config.verifierKeyId,
        publicKeyPem: config.verifierPublicKeyPem,
        workerBuildId: config.verifierWorkerBuildId
      });
      if (config.durableStore === "postgres") await reconcileRankSettlements(nowIso);
      ok(res, { verification });
      return true;
    }
    await repository.fail({
      workerId,
      leaseToken: text(req.body?.lease_token),
      jobId: text(req.body?.job_id),
      startedAt: isoOrNow(req.body?.started_at, nowIso),
      finishedAt: nowIso,
      retryable: req.body?.retryable === true,
      errorCode: text(req.body?.error_code) || "VERIFIER_FAILURE",
      diagnostics: record(req.body?.diagnostics),
      retryDelaySec: config.verifierRetryDelaySec
    });
    ok(res, { accepted: true });
    return true;
  } catch (error) {
    if (error instanceof PlayerAuthError) fail(res, error.code, error.status);
    else if (error instanceof DurableCoreError) fail(res, error.code, statusFor(error.code));
    else throw error;
    return true;
  }
}

function authenticatedPlayer(req: Request) {
  const token = bearerPlayerToken(req.header("authorization"));
  if (!token) throw new PlayerAuthError("player_token_required", 401);
  return verifyPlayerToken(token, {
    issuer: config.playerTokenIssuer,
    audience: config.playerTokenAudience,
    keyId: config.playerTokenKeyId,
    publicKeyPem: config.playerTokenPublicKeyPem
  }, "match:queue");
}

function requireWorker(req: Request): void {
  if (!config.verifierWorkerToken) throw new DurableCoreError("verifier_worker_not_configured");
  const supplied = text(req.header("x-verifier-worker-token"));
  const expected = Buffer.from(config.verifierWorkerToken, "utf8");
  const actual = Buffer.from(supplied, "utf8");
  if (actual.length !== expected.length || !crypto.timingSafeEqual(actual, expected)) {
    throw new DurableCoreError("verifier_worker_required");
  }
}

function rejectConflictingIdentity(req: Request, playerId: string): void {
  const supplied = text(req.body?.uid ?? req.body?.player_id);
  if (supplied && supplied !== playerId) throw new PlayerAuthError("identity_mismatch", 403);
}

function signedResult(value: unknown): SignedSyncResult {
  const source = record(value);
  const algorithm = text(source.algorithm);
  if (algorithm !== "ES256") throw new DurableCoreError("verifier_signature_invalid");
  return {
    payload: record(source.payload),
    payloadHash: text(source.payload_hash),
    keyId: text(source.key_id),
    algorithm: "ES256",
    signature: text(source.signature)
  };
}

function statusFor(code: string): number {
  if (["verification_job_not_found", "contract_missing"].includes(code)) return 404;
  if (["player_not_in_match", "identity_mismatch"].includes(code)) return 403;
  if (["verifier_worker_required", "player_token_required"].includes(code)) return 401;
  if (["verifier_worker_not_configured", "authority_tier_not_verifiable"].includes(code)) return 503;
  if (["idempotency_conflict", "verification_lease_invalid", "verification_input_changed", "match_not_running"].includes(code)) return 409;
  return 400;
}

function requestKey(req: Request): string {
  const value = text(req.body?.request_id ?? req.body?.idempotency_key);
  if (!value || value.length > 256) throw new DurableCoreError("idempotency_key_required");
  return value;
}

function isoOrNow(value: unknown, fallback: string): string {
  const raw = text(value);
  if (!raw) return fallback;
  const parsed = new Date(raw);
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString() !== raw) throw new DurableCoreError("timestamp_invalid");
  return raw;
}

function ok(res: Response, body: JsonRecord): void {
  res.json({ ok: true, server_unix_ms: Date.now(), ...body });
}

function fail(res: Response, err: string, status: number): void {
  res.status(status).json({ ok: false, err });
}

function record(value: unknown): JsonRecord {
  return typeof value === "object" && value != null && !Array.isArray(value) ? value as JsonRecord : {};
}

function text(value: unknown): string { return String(value ?? "").trim(); }
function nullableText(value: unknown): string | null { const clean = text(value); return clean || null; }
function integer(value: unknown): number { const parsed = Number(value); return Number.isSafeInteger(parsed) ? parsed : -1; }
