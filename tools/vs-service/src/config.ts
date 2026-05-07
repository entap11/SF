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

export const config = {
  port: parseIntValue(process.env.PORT, 8791),
  bindHost: process.env.BIND_HOST?.trim() || "0.0.0.0",
  corsEnabled: parseBoolean(process.env.VS_CORS_ENABLED, true),
  sessionTtlSec: parseIntValue(process.env.VS_SESSION_TTL_SEC, 15 * 60),
  queueTtlSec: parseIntValue(process.env.VS_QUEUE_TTL_SEC, 90),
  intentStreamMaxEvents: parseIntValue(process.env.VS_INTENT_STREAM_MAX_EVENTS, 512)
};
