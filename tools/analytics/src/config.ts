import "dotenv/config";

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value == null) {
    return fallback;
  }
  const normalized = value.trim().toLowerCase();
  if (["1", "true", "yes", "y", "on"].includes(normalized)) {
    return true;
  }
  if (["0", "false", "no", "n", "off"].includes(normalized)) {
    return false;
  }
  return fallback;
}

function parseInteger(value: string | undefined, fallback: number): number {
  if (value == null || value.trim() === "") {
    return fallback;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export const config = {
  port: parseInteger(process.env.PORT, 8787),
  bindHost: process.env.BIND_HOST?.trim() || "127.0.0.1",
  databaseUrl: process.env.DATABASE_URL ?? "",
  ingestBatchMax: parseInteger(process.env.INGEST_BATCH_MAX, 100),
  adminAuthRealm: process.env.ADMIN_AUTH_REALM ?? "Swarmfront Analytics",
  enableRollupScheduler: parseBoolean(process.env.ENABLE_ROLLUP_SCHEDULER, true),
  rollupHourlyEnabled: parseBoolean(process.env.ROLLUP_HOURLY_ENABLED, true),
  rollupDailyEnabled: parseBoolean(process.env.ROLLUP_DAILY_ENABLED, true),
  adminBootstrapUsername: process.env.ADMIN_BOOTSTRAP_USERNAME ?? "Mattballou",
  adminBootstrapPassword: process.env.ADMIN_BOOTSTRAP_PASSWORD ?? "$warmFr0nt"
};

if (!config.databaseUrl) {
  throw new Error("DATABASE_URL is required");
}
