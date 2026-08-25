import { config } from "./config.js";
import {
  processOnePlatformEconomyDelivery,
  reconcilePlatformEconomyDeliveries
} from "./platformEconomyProcessor.js";
import {
  processOneCanaryRankSettlement,
  reconcileRankSettlements
} from "./rankSettlementProcessor.js";
import { signServiceJwt } from "./serviceJwt.js";

type JsonRecord = Record<string, unknown>;

async function main(): Promise<void> {
  if (!config.durableCoreEnabled || config.durableStore !== "postgres") throw new Error("durable_postgres_required");
  if (!config.enablePlatformEconomyDelivery) throw new Error("VS_ENABLE_PLATFORM_ECONOMY_DELIVERY must be true");
  if (!config.economyEpoch) throw new Error("VS_ECONOMY_EPOCH_required");
  if (!config.economyRolloutCutoverAt || config.economyRolloutPlayerIds.length !== 2) {
    throw new Error("exactly two rollout players and a cutoff are required");
  }
  const expected = `${config.economyEpoch}:DELIVER`;
  if (process.env.VS_ECONOMY_CANARY_DELIVERY_CONFIRM?.trim() !== expected) {
    throw new Error(`VS_ECONOMY_CANARY_DELIVERY_CONFIRM must equal ${expected}`);
  }

  const honeyPolicyCanary = truthy(process.env.VS_ECONOMY_CANARY_HONEY);
  let honeyPolicyChecks = 0;
  if (honeyPolicyCanary) honeyPolicyChecks = await runHoneyPolicyCanary();

  const enqueuedDeliveries = await reconcilePlatformEconomyDeliveries();
  let completedDeliveries = 0;
  while (await processOnePlatformEconomyDelivery(`economy-canary:${process.pid}`)) {
    completedDeliveries += 1;
    if (completedDeliveries > 20) throw new Error("canary delivery bound exceeded");
  }

  let enqueuedSettlements = 0;
  let completedSettlements = 0;
  if (config.enableRankMutations) {
    enqueuedSettlements = await reconcileRankSettlements();
    while (await processOneCanaryRankSettlement(`wax-canary:${process.pid}`)) {
      completedSettlements += 1;
      if (completedSettlements > 2) throw new Error("canary settlement bound exceeded");
    }
  }
  console.log(JSON.stringify({ ok: true, enqueued_deliveries: enqueuedDeliveries,
    completed_deliveries: completedDeliveries, enqueued_settlements: enqueuedSettlements,
    completed_settlements: completedSettlements, honey_policy_checks: honeyPolicyChecks }));
}

async function runHoneyPolicyCanary(): Promise<number> {
  const expected = `${config.economyEpoch}:HONEY`;
  if (process.env.VS_ECONOMY_CANARY_HONEY_CONFIRM?.trim() !== expected) {
    throw new Error(`VS_ECONOMY_CANARY_HONEY_CONFIRM must equal ${expected}`);
  }
  if (!config.rankServiceUrl || !config.rankServicePrivateKeyPem || !config.economyEpoch) {
    throw new Error("platform_economy_delivery_not_configured");
  }
  let checks = 0;
  for (const [index, playerId] of config.economyRolloutPlayerIds.entries()) {
    const opponentId = config.economyRolloutPlayerIds[index === 0 ? 1 : 0];
    const producerEventId = `economy-live-canary:honey:${config.economyEpoch}:${playerId}`;
    const request = honeyEnvelope(producerEventId, playerId, opponentId, true);
    const first = await postHoney(request);
    if (first.status !== 200 || first.body.ok !== true || Number(first.body.amount_centi) !== 100) {
      throw new Error(`honey_policy_canary_failed:${first.status}:${String(first.body.err ?? "unexpected_response")}`);
    }
    const duplicate = await postHoney(request);
    if (duplicate.status !== 200 || duplicate.body.ok !== true || duplicate.body.duplicate !== true) {
      throw new Error("honey_policy_duplicate_not_idempotent");
    }
    const altered = await postHoney(honeyEnvelope(producerEventId, playerId, opponentId, false));
    if (altered.status !== 409) throw new Error("honey_policy_altered_retry_not_rejected");
    checks += 3;
  }
  return checks;
}

function honeyEnvelope(producerEventId: string, playerId: string, opponentId: string,
  completed: boolean): JsonRecord {
  return {
    producer_event_id: producerEventId,
    economy_epoch: config.economyEpoch,
    source_authority: "economy-live-canary",
    occurred_at: new Date().toISOString(),
    schema_version: 1,
    payload: {
      player_id: playerId,
      activity_key: "community.challenge",
      entap_title: "swarmfront",
      opponent_ids: [opponentId],
      duration_sec: 300,
      completed
    }
  };
}

async function postHoney(request: JsonRecord): Promise<{ status: number; body: JsonRecord }> {
  const token = signServiceJwt({
    issuer: config.rankServiceIssuer,
    audience: config.rankServiceAudience,
    subject: config.rankServiceSubject,
    keyId: config.rankServiceKeyId,
    privateKeyPem: config.rankServicePrivateKeyPem
  }, "economy:produce");
  const response = await fetch(`${config.rankServiceUrl}/v1/service/economy/honey-activity`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify(request)
  });
  let body: JsonRecord = {};
  try {
    const value = await response.json();
    if (typeof value === "object" && value != null && !Array.isArray(value)) body = value as JsonRecord;
  } catch {}
  return { status: response.status, body };
}

function truthy(value: string | undefined): boolean {
  return ["1", "true", "yes", "on"].includes(String(value ?? "").trim().toLowerCase());
}

void main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
