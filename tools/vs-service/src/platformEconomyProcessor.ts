import { config } from "./config.js";
import { getPlatformEconomyDeliveryRepository } from "./repositories/durableCoreRuntime.js";
import {
  platformDeliveryEnvelope,
  type PlatformEconomyDelivery,
  type PlatformEconomyOperation
} from "./repositories/platformEconomyDelivery.js";
import { signServiceJwt } from "./serviceJwt.js";
import type { JsonRecord } from "./repositories/durableCore.js";

const ROUTES: Record<PlatformEconomyOperation, { path: string; scope: string }> = {
  HONEY_ACTIVITY: { path: "/v1/service/economy/honey-activity", scope: "economy:produce" },
  NECTAR_MATCH: { path: "/v1/service/economy/nectar-match", scope: "economy:produce" },
  CRUCIBLE_RESERVE: { path: "/v1/service/economy/crucible/reserve", scope: "economy:reserve" },
  CRUCIBLE_SETTLE: { path: "/v1/service/economy/crucible/settle", scope: "economy:settle" },
  CRUCIBLE_REFUND: { path: "/v1/service/economy/crucible/refund", scope: "economy:settle" }
};

export async function reconcilePlatformEconomyDeliveries(nowIso = new Date().toISOString()): Promise<number> {
  if (config.durableStore !== "postgres") return 0;
  if (!config.enablePlatformEconomyDelivery) return 0;
  if (!config.economyEpoch) throw new Error("VS_ECONOMY_EPOCH_required");
  return getPlatformEconomyDeliveryRepository().reconcileVerifiedResults(config.economyEpoch, nowIso,
    rolloutBoundary());
}

export async function processOnePlatformEconomyDelivery(workerId: string, nowIso = new Date().toISOString(),
  filter: { matchId?: string; operation?: PlatformEconomyOperation } = {}): Promise<boolean> {
  if (config.durableStore !== "postgres") return false;
  if (!config.enablePlatformEconomyDelivery) return false;
  if (!config.rankServiceUrl || !config.rankServicePrivateKeyPem || !config.economyEpoch) {
    throw new Error("platform_economy_delivery_not_configured");
  }
  const repository = getPlatformEconomyDeliveryRepository();
  const job = await repository.leaseNext(workerId, nowIso, config.platformEconomyLeaseSec, filter,
    rolloutBoundary());
  if (!job) return false;
  const startedAt = new Date().toISOString();
  let response: JsonRecord = {};
  try {
    const route = ROUTES[job.operation];
    const token = signServiceJwt({
      issuer: config.rankServiceIssuer, audience: config.rankServiceAudience,
      subject: config.rankServiceSubject, keyId: config.rankServiceKeyId,
      privateKeyPem: config.rankServicePrivateKeyPem
    }, route.scope);
    const http = await fetch(`${config.rankServiceUrl}${route.path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify(platformDeliveryEnvelope(job))
    });
    response = await safeJson(http);
    if (!http.ok || response.ok !== true) {
      const code = String(response.err ?? `PLATFORM_HTTP_${http.status}`);
      await repository.fail({
        deliveryId: job.deliveryId, workerId, leaseToken: job.leaseToken, startedAt,
        finishedAt: new Date().toISOString(), response, errorCode: code,
        retryable: retryable(http.status, code), retryDelaySec: config.platformEconomyRetryDelaySec
      });
      return true;
    }
    validatePlatformEconomyResponse(job, response);
    await repository.complete({ deliveryId: job.deliveryId, workerId, leaseToken: job.leaseToken,
      startedAt, finishedAt: new Date().toISOString(), response });
    return true;
  } catch (error) {
    response = { ok: false, err: error instanceof Error ? error.message : String(error) };
    await repository.fail({
      deliveryId: job.deliveryId, workerId, leaseToken: job.leaseToken, startedAt,
      finishedAt: new Date().toISOString(), response, errorCode: "PLATFORM_TRANSPORT_FAILURE",
      retryable: true, retryDelaySec: config.platformEconomyRetryDelaySec
    });
    return true;
  }
}

export async function reserveCrucibleMatch(matchId: string, nowIso = new Date().toISOString()): Promise<boolean> {
  if (!config.economyEpoch) throw new Error("VS_ECONOMY_EPOCH_required");
  const repository = getPlatformEconomyDeliveryRepository();
  await repository.enqueueCrucibleReservations(matchId, config.economyEpoch, nowIso, rolloutBoundary());
  for (let index = 0; index < 2; index += 1) {
    await processOnePlatformEconomyDelivery(`crucible-reserve:${matchId}`, new Date().toISOString(),
      { matchId, operation: "CRUCIBLE_RESERVE" });
  }
  return repository.crucibleReservationsCommitted(matchId);
}

export function validatePlatformEconomyResponse(job: Pick<PlatformEconomyDelivery,
  "economyEpoch" | "matchId" | "playerId">, response: JsonRecord): void {
  if (String(response.epoch_id) !== job.economyEpoch) throw new Error("platform_epoch_response_mismatch");
  if (job.matchId && response.match_id != null && String(response.match_id) !== job.matchId) {
    throw new Error("platform_match_response_mismatch");
  }
  if (job.playerId && String(response.player_id ?? "") !== job.playerId) {
    throw new Error("platform_player_response_mismatch");
  }
}

function retryable(status: number, code: string): boolean {
  if (status >= 500 || status === 408 || status === 429) return true;
  return ["idempotency_in_progress", "active_epoch_missing"].includes(code);
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
