import { config } from "./config.js";
import { expireReconnectGrace, processOneRankSettlement, reconcileRankSettlements } from "./rankSettlementProcessor.js";

async function main(): Promise<void> {
  if (!config.durableCoreEnabled || config.durableStore !== "postgres") throw new Error("durable_postgres_required");
  const workerId = process.env.VS_RANK_SETTLEMENT_WORKER_ID?.trim() || "rank-settlement-worker-1";
  do {
    try {
      await expireReconnectGrace();
      await reconcileRankSettlements();
      const worked = await processOneRankSettlement(workerId);
      if (!worked) await delay(config.rankSettlementPollMs);
    } catch (error) {
      console.error(error);
      await delay(config.rankSettlementPollMs);
    }
  } while (true);
}

function delay(ms: number): Promise<void> { return new Promise((resolve) => setTimeout(resolve, ms)); }

void main().catch((error) => { console.error(error); process.exitCode = 1; });
