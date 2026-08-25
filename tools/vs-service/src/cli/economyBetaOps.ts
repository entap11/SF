import { config } from "../config.js";
import { durablePool } from "../db/pool.js";
import { failClosedPublicFlags } from "../repositories/publicModesOps.js";
import { getPublicModesOpsRepository } from "../repositories/durableCoreRuntime.js";

const EPOCH = process.env.VS_ECONOMY_EPOCH?.trim() || "beta_launch_0001";

async function main(): Promise<void> {
  if (config.durableStore !== "postgres" || !config.databaseUrl) throw new Error("durable_postgres_required");
  const action = String(process.argv[2] ?? "").trim().toLowerCase();
  if (action !== "enable-rank" && action !== "disable-rank") {
    throw new Error("action must be enable-rank or disable-rank");
  }
  const operation = action === "enable-rank" ? "ENABLE_RANK" : "DISABLE_RANK";
  const expected = `${EPOCH}:${operation}`;
  if (process.env.VS_ECONOMY_BETA_OPS_CONFIRM?.trim() !== expected) {
    throw new Error(`VS_ECONOMY_BETA_OPS_CONFIRM must equal ${expected}`);
  }
  const version = String(process.env.VS_ECONOMY_BETA_CONFIG_VERSION ?? "").trim();
  const requestId = String(process.env.VS_ECONOMY_BETA_REQUEST_ID ?? "").trim();
  if (!version || !requestId) throw new Error("config version and request id are required");
  const flags = failClosedPublicFlags();
  flags.enable_rank_mutations = action === "enable-rank";
  const result = await getPublicModesOpsRepository().publish({
    configVersion: version,
    minSupportedBuild: 0,
    expiresAt: null,
    featureFlags: flags,
    publicationReason: action === "enable-rank"
      ? "Enable automatic Standard Wax after bounded Honey Nectar Wax certification"
      : "Disable automatic Standard Wax",
    publishedBy: "economy-beta-operator",
    publishedAt: new Date().toISOString(),
    requestId
  });
  console.log(JSON.stringify({ ok: true, action, duplicate: result.duplicate,
    revision_id: result.revision.revisionId, revision_seq: result.revision.revisionSeq,
    config_version: result.revision.configVersion, feature_flags: result.revision.featureFlags }));
}

void main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
}).finally(async () => durablePool.end());
