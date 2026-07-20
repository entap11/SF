import crypto from "node:crypto";
import type { Request, Response } from "express";
import { config } from "./config.js";
import { DurableCoreError, type JsonRecord } from "./repositories/durableCore.js";
import {
  getCrucibleSettlementRepository, getPublicContestRepository, getPublicModesOpsRepository,
  getRankSettlementRepository, getVerificationRepository
} from "./repositories/durableCoreRuntime.js";
import {
  failClosedPublicFlags, PUBLIC_ROLLOUT_FLAGS, type PublicRolloutFlag, type PublicRolloutFlags
} from "./repositories/publicModesOps.js";

const ACTIONS = new Set([
  "publish_public_ops_config", "rollback_public_ops_config", "get_public_ops_config_history",
  "get_public_modes_ops_dashboard", "run_public_modes_reconciliation"
]);

const DEPLOYMENT_CAPS: Record<PublicRolloutFlag, () => boolean> = {
  enable_public_1v1: () => config.enablePublic1v1,
  enable_public_crucible: () => config.enablePublicCrucible,
  enable_public_3p_ffa: () => config.enablePublic3pFfa,
  enable_public_2v2: () => config.enablePublic2v2,
  enable_public_4p_ffa: () => config.enablePublic4pFfa,
  enable_public_ctf: () => config.enablePublicCtf,
  enable_public_hctf: () => config.enablePublicHctf,
  enable_public_time_puzzles: () => config.enablePublicTimePuzzles,
  enable_public_gauntlet: () => config.enablePublicGauntlet,
  enable_public_async_3map: () => config.enablePublicAsync3map,
  enable_public_async_5map: () => config.enablePublicAsync5map,
  enable_rank_mutations: () => config.enableRankMutations,
  enable_crucible_wax_settlement: () => config.enableCrucibleWaxSettlement,
  enable_contest_rewards: () => config.enableContestRewards,
  enable_bot_fallback: () => config.enableCtfBotFallback,
  enable_public_leaderboards: () => config.enablePublicLeaderboards
};

export async function effectivePublicRollout(nowIso = new Date().toISOString()): Promise<{
  flags: PublicRolloutFlags; configVersion: string; configHash: string; minSupportedBuild: number;
  expiresAt: string | null; source: string;
}> {
  const deployed = failClosedPublicFlags();
  for (const flag of PUBLIC_ROLLOUT_FLAGS) deployed[flag] = DEPLOYMENT_CAPS[flag]();
  if (!config.enableRemoteOpsConfig) return { flags: deployed, configVersion: "deployment-caps",
    configHash: "", minSupportedBuild: 0, expiresAt: null, source: "DEPLOYMENT_CAPS" };
  if (config.durableStore !== "postgres" || !config.databaseUrl) return { flags: failClosedPublicFlags(),
    configVersion: "missing-fail-closed", configHash: "", minSupportedBuild: 0, expiresAt: null,
    source: "REMOTE_CONFIG_UNAVAILABLE" };
  const active = await getPublicModesOpsRepository().active(nowIso);
  if (!active) return { flags: failClosedPublicFlags(), configVersion: "missing-fail-closed",
    configHash: "", minSupportedBuild: 0, expiresAt: null, source: "NO_ACTIVE_REMOTE_CONFIG" };
  const flags = failClosedPublicFlags();
  for (const flag of PUBLIC_ROLLOUT_FLAGS) flags[flag] = deployed[flag] && active.featureFlags[flag];
  return { flags, configVersion: active.configVersion, configHash: active.configHash,
    minSupportedBuild: active.minSupportedBuild, expiresAt: active.expiresAt, source: "REMOTE_AND_DEPLOYMENT_CAPS" };
}

export async function requirePublicRollout(flag: PublicRolloutFlag, clientBuild: string | null = null,
  disabledCode = `${flag}_disabled`): Promise<Awaited<ReturnType<typeof effectivePublicRollout>>> {
  const effective = await effectivePublicRollout();
  if (!effective.flags[flag]) throw new DurableCoreError(disabledCode);
  if (effective.minSupportedBuild > 0 && clientBuild != null) {
    const parsed = Number.parseInt(clientBuild, 10);
    if (!Number.isSafeInteger(parsed) || parsed < effective.minSupportedBuild) {
      throw new DurableCoreError("minimum_client_build_required");
    }
  }
  return effective;
}

export async function handlePublicModesOpsAction(action: string, req: Request, res: Response): Promise<boolean> {
  if (!ACTIONS.has(action)) return false;
  try {
    requireAdmin(req);
    requireStore();
    const repository = getPublicModesOpsRepository();
    const nowIso = new Date().toISOString();
    const publishedBy = text(req.header("x-admin-actor")) || config.adminRole;
    if (action === "publish_public_ops_config") {
      const result = await repository.publish({ configVersion: text(req.body?.config_version),
        minSupportedBuild: integer(req.body?.min_supported_build, 0), expiresAt: optionalText(req.body?.expires_at),
        featureFlags: record(req.body?.feature_flags), publicationReason: text(req.body?.publication_reason),
        publishedBy, publishedAt: nowIso, requestId: requestId(req) });
      ok(res, { revision: result.revision, duplicate: result.duplicate }); return true;
    }
    if (action === "rollback_public_ops_config") {
      const result = await repository.rollback(text(req.body?.target_revision_id), {
        configVersion: text(req.body?.config_version), publicationReason: text(req.body?.publication_reason),
        publishedBy, publishedAt: nowIso, requestId: requestId(req) });
      ok(res, { revision: result.revision, duplicate: result.duplicate }); return true;
    }
    if (action === "get_public_ops_config_history") {
      ok(res, { revisions: await repository.history(integer(req.body?.limit, 25)),
        effective: await effectivePublicRollout(nowIso) }); return true;
    }
    if (action === "get_public_modes_ops_dashboard") {
      ok(res, { dashboard: await repository.dashboard(nowIso), effective: await effectivePublicRollout(nowIso) }); return true;
    }
    ok(res, { reconciliation: await runPublicModesReconciliation(publishedBy, nowIso) }); return true;
  } catch (error) {
    if (error instanceof OpsHttpError) fail(res, error.code, error.status);
    else if (error instanceof DurableCoreError) fail(res, error.code, statusFor(error.code));
    else throw error;
    return true;
  }
}

export async function runPublicModesReconciliation(startedBy = "scheduled_ops_job", startedAt = new Date().toISOString()): Promise<JsonRecord> {
    requireStore();
    const [expiredReconnects, contests, rankSettlements, crucible] = await Promise.all([
      getVerificationRepository().expireReconnectGrace(startedAt, 100),
      getPublicContestRepository().reconcile(startedAt),
      getRankSettlementRepository().reconcile(startedAt),
      getCrucibleSettlementRepository().reconcile()
    ]);
    const alertCount = Number((crucible as JsonRecord).ok === false);
    const result: JsonRecord = { expired_reconnects: expiredReconnects, contests,
      rank_settlements: rankSettlements, crucible, alert_count: alertCount };
    const finishedAt = new Date().toISOString();
    const repository = getPublicModesOpsRepository();
    await repository.syncAlert("crucible_ledger_reconciliation", "CRITICAL", crucible as JsonRecord,
      (crucible as JsonRecord).ok === false, finishedAt);
    return repository.recordReconciliation(startedBy, startedAt, finishedAt, result);
}

export async function handlePublicOpsConfigGet(_req: Request, res: Response): Promise<void> {
  try {
    const effective = await effectivePublicRollout();
    res.setHeader("Cache-Control", "public, max-age=15, must-revalidate");
    if (effective.configHash) res.setHeader("ETag", `\"${effective.configHash}\"`);
    res.json({ schema_version: 1, config_version: effective.configVersion,
      generated_utc: new Date().toISOString(), expires_utc: effective.expiresAt ?? "",
      min_supported_build: effective.minSupportedBuild, force_update: effective.minSupportedBuild > 0,
      feature_flags: effective.flags, rollout_source: effective.source });
  } catch {
    res.status(503).json({ schema_version: 1, config_version: "error-fail-closed", min_supported_build: 0,
      force_update: false, feature_flags: failClosedPublicFlags(), rollout_source: "ERROR_FAIL_CLOSED" });
  }
}

function requireAdmin(req: Request): void {
  if (!config.adminToken) throw new OpsHttpError("admin_auth_not_configured", 503);
  const supplied = text(req.header("x-admin-token")) || text(req.header("authorization")).replace(/^Bearer\s+/i, "");
  const expected = config.adminToken;
  if (supplied.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(supplied), Buffer.from(expected))
    || text(req.header("x-admin-role")) !== config.adminRole) throw new OpsHttpError("admin_auth_required", 401);
}
function requireStore(): void {
  if (config.durableStore !== "postgres" || !config.databaseUrl) throw new OpsHttpError("public_modes_ops_store_not_configured", 503);
}
function requestId(req: Request): string { return text(req.body?.request_id ?? req.body?.idempotency_key); }
function record(value: unknown): Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : {}; }
function text(value: unknown): string { return String(value ?? "").trim(); }
function optionalText(value: unknown): string | null { const out = text(value); return out || null; }
function integer(value: unknown, fallback: number): number { const parsed = Number(value); return Number.isSafeInteger(parsed) ? parsed : fallback; }
function ok(res: Response, body: JsonRecord): void { res.json({ ok: true, server_unix_ms: Date.now(), ...body }); }
function fail(res: Response, err: string, status: number): void { res.status(status).json({ ok: false, err }); }
function statusFor(code: string): number { return code === "minimum_client_build_required" ? 426 : code.endsWith("_disabled") ? 503 : 400; }
class OpsHttpError extends Error { constructor(readonly code: string, readonly status: number) { super(code); } }
