import { config } from "./config.js";
import {
  processOnePlatformEconomyDelivery,
  reconcilePlatformEconomyDeliveries
} from "./platformEconomyProcessor.js";
import {
  processOneCanaryRankSettlement,
  reconcileRankSettlements
} from "./rankSettlementProcessor.js";

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
    completed_settlements: completedSettlements }));
}

void main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
