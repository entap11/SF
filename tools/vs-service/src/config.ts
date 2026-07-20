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

function normalizePem(value: string | undefined): string {
  return String(value ?? "").trim().replace(/\\n/g, "\n");
}

const productionMode = process.env.NODE_ENV?.trim().toLowerCase() === "production"
  || parseBoolean(process.env.VS_PRODUCTION_MODE, false)
  || parseBoolean(process.env.RENDER, false)
  || Boolean(process.env.RENDER_SERVICE_ID?.trim());

const durableStore: "memory" | "postgres" = process.env.VS_DURABLE_STORE?.trim().toLowerCase() === "postgres"
  ? "postgres"
  : "memory";

const public1v1AuthorityTier: "RELAY_ATTESTED" | "AUTHORITY_VERIFIED" =
  process.env.VS_PUBLIC_1V1_AUTHORITY_TIER?.trim().toUpperCase() === "AUTHORITY_VERIFIED"
    ? "AUTHORITY_VERIFIED" : "RELAY_ATTESTED";

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
  honeyLedgerPath: process.env.HONEY_LEDGER_PATH?.trim() || "data/honey-ledger.json",
  durableCoreEnabled: parseBoolean(process.env.VS_DURABLE_CORE_ENABLED, false),
  durableStore,
  databaseUrl: process.env.VS_DATABASE_URL?.trim() || process.env.DATABASE_URL?.trim() || "",
  databasePoolMax: Math.max(1, parseIntValue(process.env.VS_DATABASE_POOL_MAX, 16)),
  durableRetentionDays: Math.max(30, parseIntValue(process.env.VS_DURABLE_RETENTION_DAYS, 120)),
  durablePublic1v1Enabled: parseBoolean(process.env.VS_DURABLE_PUBLIC_1V1_ENABLED, false),
  enablePublic1v1: parseBoolean(process.env.VS_ENABLE_PUBLIC_1V1, false),
  enablePublicCtf: parseBoolean(process.env.VS_ENABLE_PUBLIC_CTF, false),
  enablePublicHctf: parseBoolean(process.env.VS_ENABLE_PUBLIC_HCTF, false),
  enablePublicCrucible: parseBoolean(process.env.VS_ENABLE_PUBLIC_CRUCIBLE, false),
  enableCrucibleWaxSettlement: parseBoolean(process.env.VS_ENABLE_CRUCIBLE_WAX_SETTLEMENT, false),
  hctfLiveSecrecyCertified: parseBoolean(process.env.VS_HCTF_LIVE_SECRECY_CERTIFIED, false),
  enableCtfBotFallback: parseBoolean(process.env.VS_ENABLE_CTF_BOT_FALLBACK, false),
  enableRankMutations: parseBoolean(process.env.VS_ENABLE_RANK_MUTATIONS, false),
  enablePublicLeaderboards: parseBoolean(process.env.VS_ENABLE_PUBLIC_LEADERBOARDS, false),
  enablePublicContests: parseBoolean(process.env.VS_ENABLE_PUBLIC_CONTESTS, false),
  enablePublicTimePuzzles: parseBoolean(process.env.VS_ENABLE_PUBLIC_TIME_PUZZLES, false),
  enablePublicGauntlet: parseBoolean(process.env.VS_ENABLE_PUBLIC_GAUNTLET, false),
  publicContestGrantSecret: process.env.VS_PUBLIC_CONTEST_GRANT_SECRET?.trim() || "",
  publicContestLeaderboardLimit: Math.max(1,
    Math.min(100, parseIntValue(process.env.VS_PUBLIC_CONTEST_LEADERBOARD_LIMIT, 25))),
  public1v1MinimumClientBuild: process.env.VS_PUBLIC_1V1_MINIMUM_CLIENT_BUILD?.trim() || "",
  public1v1SimBuildId: process.env.VS_PUBLIC_1V1_SIM_BUILD_ID?.trim() || "",
  public1v1RulesetId: process.env.VS_PUBLIC_1V1_RULESET_ID?.trim() || "",
  public1v1RulesetHash: process.env.VS_PUBLIC_1V1_RULESET_HASH?.trim().toLowerCase() || "",
  public1v1MapId: process.env.VS_PUBLIC_1V1_MAP_ID?.trim() || "",
  public1v1MapHash: process.env.VS_PUBLIC_1V1_MAP_HASH?.trim().toLowerCase() || "",
  publicCtfRulesetId: process.env.VS_PUBLIC_CTF_RULESET_ID?.trim() || "",
  publicCtfRulesetHash: process.env.VS_PUBLIC_CTF_RULESET_HASH?.trim().toLowerCase() || "",
  publicCtfMapId: process.env.VS_PUBLIC_CTF_MAP_ID?.trim() || "",
  publicCtfMapHash: process.env.VS_PUBLIC_CTF_MAP_HASH?.trim().toLowerCase() || "",
  publicHctfRulesetId: process.env.VS_PUBLIC_HCTF_RULESET_ID?.trim() || "",
  publicHctfRulesetHash: process.env.VS_PUBLIC_HCTF_RULESET_HASH?.trim().toLowerCase() || "",
  publicHctfMapId: process.env.VS_PUBLIC_HCTF_MAP_ID?.trim() || "",
  publicHctfMapHash: process.env.VS_PUBLIC_HCTF_MAP_HASH?.trim().toLowerCase() || "",
  publicCrucibleRulesetId: process.env.VS_PUBLIC_CRUCIBLE_RULESET_ID?.trim() || "",
  publicCrucibleRulesetHash: process.env.VS_PUBLIC_CRUCIBLE_RULESET_HASH?.trim().toLowerCase() || "",
  publicCrucibleMapId: process.env.VS_PUBLIC_CRUCIBLE_MAP_ID?.trim() || "",
  publicCrucibleMapHash: process.env.VS_PUBLIC_CRUCIBLE_MAP_HASH?.trim().toLowerCase() || "",
  ctfBotFallbackThresholdSec: Math.max(0, parseIntValue(process.env.VS_CTF_BOT_FALLBACK_THRESHOLD_SEC, 30)),
  ctfBotProfileId: process.env.VS_CTF_BOT_PROFILE_ID?.trim() || "ctf-practice-v1",
  hctfBotProfileId: process.env.VS_HCTF_BOT_PROFILE_ID?.trim() || "hctf-practice-v1",
  public1v1ReconnectGraceSec: Math.max(5, parseIntValue(process.env.VS_PUBLIC_1V1_RECONNECT_GRACE_SEC, 30)),
  public1v1AuthorityTier,
  matchVerificationEnabled: parseBoolean(process.env.VS_MATCH_VERIFICATION_ENABLED, false),
  verifierWorkerToken: process.env.VS_VERIFIER_WORKER_TOKEN?.trim() || "",
  verifierKeyId: process.env.VS_VERIFIER_KEY_ID?.trim() || "",
  verifierPublicKeyPem: normalizePem(process.env.VS_VERIFIER_PUBLIC_KEY_PEM),
  verifierWorkerBuildId: process.env.VS_VERIFIER_WORKER_BUILD_ID?.trim() || "",
  verifierLeaseSec: Math.max(10, parseIntValue(process.env.VS_VERIFIER_LEASE_SEC, 60)),
  verifierRetryDelaySec: Math.max(1, parseIntValue(process.env.VS_VERIFIER_RETRY_DELAY_SEC, 10)),
  rankServiceUrl: process.env.VS_RANK_SERVICE_URL?.trim().replace(/\/$/, "") || "",
  rankServiceIssuer: process.env.VS_RANK_SERVICE_TOKEN_ISSUER?.trim() || "swarmfront-vs",
  rankServiceAudience: process.env.VS_RANK_SERVICE_TOKEN_AUDIENCE?.trim() || "swarmfront-rank",
  rankServiceSubject: process.env.VS_RANK_SERVICE_TOKEN_SUBJECT?.trim() || "vs-settlement-worker",
  rankServiceKeyId: process.env.VS_RANK_SERVICE_TOKEN_KEY_ID?.trim() || "vs-rank-service-v1",
  rankServicePrivateKeyPem: normalizePem(process.env.VS_RANK_SERVICE_TOKEN_PRIVATE_KEY_PEM),
  rankSettlementLeaseSec: Math.max(10, parseIntValue(process.env.VS_RANK_SETTLEMENT_LEASE_SEC, 60)),
  rankSettlementRetryDelaySec: Math.max(1, parseIntValue(process.env.VS_RANK_SETTLEMENT_RETRY_DELAY_SEC, 15)),
  rankSettlementPollMs: Math.max(250, parseIntValue(process.env.VS_RANK_SETTLEMENT_POLL_MS, 1_000)),
  rankLeaderboardMaxStaleSec: Math.max(0, parseIntValue(process.env.VS_RANK_LEADERBOARD_MAX_STALE_SEC, 300)),
  authenticated1v1SliceEnabled: parseBoolean(process.env.VS_AUTHENTICATED_1V1_SLICE_ENABLED, false),
  playerTokenIssuer: process.env.VS_PLAYER_TOKEN_ISSUER?.trim() || "entap-identity",
  playerTokenAudience: process.env.VS_PLAYER_TOKEN_AUDIENCE?.trim() || "swarmfront-vs",
  playerTokenKeyId: process.env.VS_PLAYER_TOKEN_KEY_ID?.trim() || "entap-player-v1",
  playerTokenPublicKeyPem: normalizePem(process.env.VS_PLAYER_TOKEN_PUBLIC_KEY_PEM)
};
