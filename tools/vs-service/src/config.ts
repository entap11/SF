import "dotenv/config";

function parseIntValue(value: string | undefined, fallback: number): number {
  if (!value || value.trim() === "") {
    return fallback;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value == null) {
    return fallback;
  }
  const normalized = value.trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) {
    return true;
  }
  if (["0", "false", "no", "off"].includes(normalized)) {
    return false;
  }
  return fallback;
}

const productionMode = process.env.NODE_ENV?.trim().toLowerCase() === "production"
  || parseBoolean(process.env.VS_PRODUCTION_MODE, false)
  || parseBoolean(process.env.RENDER, false)
  || Boolean(process.env.RENDER_SERVICE_ID?.trim());

export const config = {
  port: parseIntValue(process.env.PORT, 8791),
  bindHost: process.env.BIND_HOST?.trim() || "0.0.0.0",
  productionMode,
  corsEnabled: parseBoolean(process.env.VS_CORS_ENABLED, true),
  sessionTtlSec: parseIntValue(process.env.VS_SESSION_TTL_SEC, 15 * 60),
  queueTtlSec: parseIntValue(process.env.VS_QUEUE_TTL_SEC, 90),
  intentStreamMaxEvents: parseIntValue(process.env.VS_INTENT_STREAM_MAX_EVENTS, 512),
  spectatorEnabled: parseBoolean(process.env.VS_SPECTATOR_ENABLED, true),
  spectatorAdminToken: process.env.VS_SPECTATOR_ADMIN_TOKEN?.trim() || "",
  spectatorDevOpen: parseBoolean(process.env.VS_SPECTATOR_DEV_OPEN, false),
  spectatorGrantTtlSec: parseIntValue(process.env.VS_SPECTATOR_GRANT_TTL_SEC, 30 * 60),
  spectatorDefaultDelaySec: parseIntValue(process.env.VS_SPECTATOR_DEFAULT_DELAY_SEC, 20),
  spectatorMinDelaySec: parseIntValue(process.env.VS_SPECTATOR_MIN_DELAY_SEC, 10),
  spectatorMaxDelaySec: parseIntValue(process.env.VS_SPECTATOR_MAX_DELAY_SEC, 30),
  spectatorLiveEnabled: parseBoolean(process.env.VS_SPECTATOR_LIVE_ENABLED, false),
  spectatorPublicEnabled: parseBoolean(process.env.VS_SPECTATOR_PUBLIC_ENABLED, false),
  spectatorStreamMaxEvents: parseIntValue(process.env.VS_SPECTATOR_STREAM_MAX_EVENTS, 512),
  adminToken: process.env.VS_ADMIN_TOKEN?.trim() || "",
  adminRole: process.env.VS_ADMIN_ROLE?.trim() || "ops_admin",
  matchAuthorityToken: process.env.VS_MATCH_AUTHORITY_TOKEN?.trim() || "",
  economyMutationsEnabled: parseBoolean(process.env.VS_ECONOMY_MUTATIONS_ENABLED, false),
  economyResetEnabled: parseBoolean(process.env.VS_ECONOMY_RESET_ENABLED, false),
  economyEpoch: process.env.VS_ECONOMY_EPOCH?.trim() || "",
  crucibleLedgerStore: process.env.CRUCIBLE_LEDGER_STORE?.trim() || "file",
  crucibleLedgerPath: process.env.CRUCIBLE_LEDGER_PATH?.trim() || "data/crucible-ledger.json",
  honeyLedgerStore: process.env.HONEY_LEDGER_STORE?.trim() || "file",
  honeyLedgerPath: process.env.HONEY_LEDGER_PATH?.trim() || "data/honey-ledger.json"
};
