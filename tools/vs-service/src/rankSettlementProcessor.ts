import { config } from "./config.js";
import { requirePublicRollout } from "./publicModesOpsHttp.js";
import { signServiceJwt } from "./serviceJwt.js";
import { sha256Canonical, type JsonRecord } from "./repositories/durableCore.js";
import { getRankSettlementRepository, getVerificationRepository } from "./repositories/durableCoreRuntime.js";
import type { RankSettlementBundle } from "./repositories/rankSettlement.js";

export async function reconcileRankSettlements(nowIso = new Date().toISOString()): Promise<number> {
  if (config.durableStore !== "postgres") return 0;
  return getRankSettlementRepository().reconcile(nowIso, rolloutBoundary());
}

export async function expireReconnectGrace(nowIso = new Date().toISOString()): Promise<number> {
  if (!config.matchVerificationEnabled || config.durableStore !== "postgres") return 0;
  return getVerificationRepository().expireReconnectGrace(nowIso, 25);
}

export async function processOneRankSettlement(workerId: string, nowIso = new Date().toISOString()): Promise<boolean> {
  if (config.durableStore !== "postgres") return false;
  try { await requirePublicRollout("enable_rank_mutations"); } catch { return false; }
  return processOneAuthorizedRankSettlement(workerId, nowIso);
}

export async function processOneCanaryRankSettlement(workerId: string,
  nowIso = new Date().toISOString()): Promise<boolean> {
  if (config.durableStore !== "postgres") return false;
  if (!config.enableRankMutations) throw new Error("VS_ENABLE_RANK_MUTATIONS must be true for the canary process");
  if (!config.economyEpoch) throw new Error("VS_ECONOMY_EPOCH_required");
  const expected = `${config.economyEpoch}:STANDARD_WAX`;
  if (process.env.VS_ECONOMY_CANARY_CONFIRM?.trim() !== expected) {
    throw new Error(`VS_ECONOMY_CANARY_CONFIRM must equal ${expected}`);
  }
  if (!config.economyRolloutCutoverAt || config.economyRolloutPlayerIds.length !== 2) {
    throw new Error("exactly two rollout players and a cutoff are required");
  }
  return processOneAuthorizedRankSettlement(workerId, nowIso);
}

async function processOneAuthorizedRankSettlement(workerId: string, nowIso: string): Promise<boolean> {
  if (!config.rankServiceUrl || !config.rankServicePrivateKeyPem) throw new Error("rank_settlement_not_configured");
  const repository = getRankSettlementRepository();
  const job = await repository.leaseNext(workerId, nowIso, config.rankSettlementLeaseSec, rolloutBoundary());
  if (!job) return false;
  const startedAt = new Date().toISOString();
  const request = requestFor(job);
  let response: JsonRecord = {};
  try {
    const token = signServiceJwt({
      issuer: config.rankServiceIssuer, audience: config.rankServiceAudience,
      subject: config.rankServiceSubject, keyId: config.rankServiceKeyId,
      privateKeyPem: config.rankServicePrivateKeyPem
    }, "rank:settle");
    const http = await fetch(`${config.rankServiceUrl}/v1/service/settle-standard-1v1`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify(request)
    });
    response = await safeJson(http);
    if (!http.ok || response.ok !== true) {
      const errorCode = String(response.err ?? `RANK_HTTP_${http.status}`);
      await repository.fail({
        settlementId: job.settlementId, workerId, leaseToken: job.leaseToken, startedAt,
        finishedAt: new Date().toISOString(), request, response, errorCode,
        retryable: http.status >= 500 || http.status === 409 || response.retryable === true,
        retryDelaySec: config.rankSettlementRetryDelaySec
      });
      return true;
    }
    await repository.complete({
      settlementId: job.settlementId, workerId, leaseToken: job.leaseToken,
      startedAt, finishedAt: new Date().toISOString(), request, response
    });
    return true;
  } catch (error) {
    response = { ok: false, err: error instanceof Error ? error.message : String(error) };
    await repository.fail({
      settlementId: job.settlementId, workerId, leaseToken: job.leaseToken, startedAt,
      finishedAt: new Date().toISOString(), request, response, errorCode: "RANK_TRANSPORT_FAILURE",
      retryable: true, retryDelaySec: config.rankSettlementRetryDelaySec
    });
    return true;
  }
}

export function rankSettlementRequestHash(bundle: RankSettlementBundle): string {
  return sha256Canonical(requestFor(bundle));
}

function requestFor(bundle: RankSettlementBundle): JsonRecord {
  return {
    rank_event_id: bundle.rankEventId,
    mode_id: "STANDARD_1V1",
    signed_result: {
      payload: bundle.signedReceipt.payload,
      payload_hash: bundle.signedReceipt.payloadHash,
      key_id: bundle.signedReceipt.keyId,
      algorithm: bundle.signedReceipt.algorithm,
      signature: bundle.signedReceipt.signature
    }
  };
}

async function safeJson(response: Response): Promise<JsonRecord> {
  try {
    const value = await response.json();
    return typeof value === "object" && value != null && !Array.isArray(value) ? value as JsonRecord : {};
  } catch { return {}; }
}

function rolloutBoundary() {
  return {
    verifiedAtOrAfter: config.economyRolloutCutoverAt,
    allowedPlayerIds: config.economyRolloutPlayerIds
  };
}
