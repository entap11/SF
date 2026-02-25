import { config } from "../config.js";
import { pool } from "../db/pool.js";
import { computeRollupsForDate } from "./compute.js";
import { todayUtc, yesterdayUtc } from "../util/date.js";

let running = false;
let lastHourlyKey = "";
let lastDailyKey = "";

async function runSafely(task: () => Promise<void>): Promise<void> {
  if (running) {
    return;
  }
  running = true;
  try {
    await task();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("rollup scheduler error", error);
  } finally {
    running = false;
  }
}

async function tick(): Promise<void> {
  const now = new Date();
  const minute = now.getUTCMinutes();
  const hour = now.getUTCHours();
  const dayKey = todayUtc();

  if (config.rollupHourlyEnabled && minute >= 5 && minute < 10) {
    const hourlyKey = `${dayKey}:${hour}`;
    if (hourlyKey !== lastHourlyKey) {
      lastHourlyKey = hourlyKey;
      await runSafely(async () => {
        await computeRollupsForDate(pool, dayKey);
      });
    }
  }

  if (config.rollupDailyEnabled && hour === 0 && minute >= 15 && minute < 20) {
    const yday = yesterdayUtc();
    if (lastDailyKey !== yday) {
      lastDailyKey = yday;
      await runSafely(async () => {
        await computeRollupsForDate(pool, yday);
        await computeRollupsForDate(pool, dayKey);
      });
    }
  }
}

export function startRollupScheduler(): NodeJS.Timeout | null {
  if (!config.enableRollupScheduler) {
    return null;
  }
  const timer = setInterval(() => {
    void tick();
  }, 60_000);
  timer.unref();
  return timer;
}
