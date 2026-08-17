import { config } from "./config.js";
import {
  processOnePlatformEconomyDelivery,
  reconcilePlatformEconomyDeliveries
} from "./platformEconomyProcessor.js";

async function main(): Promise<void> {
  if (!config.durableCoreEnabled || config.durableStore !== "postgres") throw new Error("durable_postgres_required");
  const workerId = process.env.VS_PLATFORM_ECONOMY_WORKER_ID?.trim() || "platform-economy-worker-1";
  do {
    try {
      await reconcilePlatformEconomyDeliveries();
      const worked = await processOnePlatformEconomyDelivery(workerId);
      if (!worked) await delay(config.platformEconomyPollMs);
    } catch (error) {
      console.error(error);
      await delay(config.platformEconomyPollMs);
    }
  } while (true);
}

function delay(ms: number): Promise<void> { return new Promise((resolve) => setTimeout(resolve, ms)); }

void main().catch((error) => { console.error(error); process.exitCode = 1; });
