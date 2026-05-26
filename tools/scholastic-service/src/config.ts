import "dotenv/config";
import type { ScholasticServiceConfig } from "./types.js";

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

export const config: ScholasticServiceConfig = {
  port: parseIntValue(process.env.PORT, 8792),
  bindHost: process.env.BIND_HOST?.trim() || "127.0.0.1",
  databaseUrl: process.env.DATABASE_URL?.trim() || "",
  apiToken: process.env.SCHOLASTIC_API_TOKEN?.trim() || "",
  adminToken: process.env.SCHOLASTIC_ADMIN_TOKEN?.trim() || "",
  enableDebugActions: parseBoolean(process.env.SCHOLASTIC_ENABLE_DEBUG_ACTIONS, false)
};
