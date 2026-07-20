import type { Pool } from "pg";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { runMigrations } from "../db/migrate.js";
import { DurableCoreError } from "./durableCore.js";
import { PGlitePoolAdapter } from "./pglitePoolAdapter.js";
import {
  failClosedPublicFlags, PostgresPublicModesOpsRepository, PUBLIC_ROLLOUT_FLAGS
} from "./publicModesOps.js";

function expect(value: unknown, message: string, details?: unknown): void {
  if (!value) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}
async function expectCode(promise: Promise<unknown>, code: string): Promise<void> {
  try { await promise; } catch (error) {
    expect(error instanceof DurableCoreError && error.code === code, `expected ${code}`,
      error instanceof Error ? error.message : error); return;
  }
  throw new Error(`expected ${code}`);
}

async function main(): Promise<void> {
  const db = new PGlite({ extensions: { pgcrypto } }); await db.waitReady;
  const pool = new PGlitePoolAdapter(db) as unknown as Pool;
  await runMigrations(pool);
  const repository = new PostgresPublicModesOpsRepository(pool);
  const now = "2026-07-19T20:00:00.000Z";
  expect(await repository.active(now) == null, "store without an active revision did not fail closed");
  expect(Object.values(failClosedPublicFlags()).every((enabled) => !enabled)
    && Object.keys(failClosedPublicFlags()).length === PUBLIC_ROLLOUT_FLAGS.length,
  "canonical default flags were not all false");

  const first = await repository.publish({ configVersion: "rollout-001", minSupportedBuild: 2026071901,
    expiresAt: "2026-07-26T20:00:00.000Z", featureFlags: { enable_public_1v1: true,
      enable_public_leaderboards: true }, publicationReason: "open standard canary",
    publishedBy: "ops-smoke", publishedAt: now, requestId: "publish-001" });
  expect(first.revision.active && first.revision.featureFlags.enable_public_1v1
    && !first.revision.featureFlags.enable_public_crucible
    && first.revision.minSupportedBuild === 2026071901,
  "publication did not normalize omitted flags to false", first);
  const duplicate = await repository.publish({ configVersion: "ignored-on-idempotent-retry", minSupportedBuild: 0,
    featureFlags: {}, publicationReason: "retry", publishedBy: "ops-smoke", publishedAt: now,
    requestId: "publish-001" });
  expect(duplicate.duplicate && duplicate.revision.revisionId === first.revision.revisionId,
    "publication request was not idempotent", duplicate);
  await expectCode(repository.publish({ configVersion: "bad-flags", minSupportedBuild: 0,
    featureFlags: { enable_future_mode: true }, publicationReason: "reject unknown",
    publishedBy: "ops-smoke", publishedAt: now, requestId: "publish-bad" }), "ops_config_unknown_flag");

  const second = await repository.publish({ configVersion: "rollout-002", minSupportedBuild: 2026071902,
    expiresAt: "2026-07-27T20:00:00.000Z", featureFlags: { enable_public_1v1: false,
      enable_public_3p_ffa: true }, publicationReason: "advance canary", publishedBy: "ops-smoke",
    publishedAt: "2026-07-19T21:00:00.000Z", requestId: "publish-002" });
  expect(second.revision.previousRevisionId === first.revision.revisionId
    && (await repository.active(now))?.revisionId === second.revision.revisionId,
  "new revision was not singular and active", second);

  const rollback = await repository.rollback(first.revision.revisionId, { configVersion: "rollback-003",
    publicationReason: "canary regression", publishedBy: "ops-smoke",
    publishedAt: "2026-07-19T22:00:00.000Z", requestId: "rollback-003" });
  expect(rollback.revision.rollbackOfRevisionId === first.revision.revisionId
    && rollback.revision.featureFlags.enable_public_1v1
    && !rollback.revision.featureFlags.enable_public_3p_ffa,
  "rollback did not append an auditable copy of target config", rollback);
  const history = await repository.history(10);
  expect(history.length === 3 && history.filter((item) => item.active).length === 1
    && history[0].revisionId === rollback.revision.revisionId,
  "revision history/active invariant failed", history);
  expect(await repository.active("2026-07-27T20:00:00.000Z") == null,
    "expired active config did not fail closed");

  const run = await repository.recordReconciliation("ops-smoke", now,
    "2026-07-19T20:00:01.000Z", { alert_count: 0, expired_reconnects: 1 });
  await repository.syncAlert("smoke_backlog", "WARNING", { count: 7 }, true, now);
  const alerted = await repository.dashboard(now);
  expect(Array.isArray(alerted.alerts) && alerted.alerts.length === 1,
    "open operational alert was not support-visible", alerted);
  await repository.syncAlert("smoke_backlog", "WARNING", { count: 0 }, false,
    "2026-07-19T20:00:02.000Z");
  const dashboard = await repository.dashboard(now);
  expect(run.status === "OK" && (dashboard.active_config as { revisionId?: string })?.revisionId === rollback.revision.revisionId
    && Array.isArray(dashboard.config_history) && Array.isArray(dashboard.reconciliation_runs)
    && Array.isArray(dashboard.alerts) && dashboard.alerts.length === 0,
  "support dashboard omitted effective configuration or reconciliation", dashboard);
  await db.close();
  console.log("PUBLIC_MODES_OPS_EMBEDDED_SMOKE: PASS");
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
