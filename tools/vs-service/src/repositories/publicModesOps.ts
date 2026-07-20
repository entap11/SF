import type { Pool, PoolClient } from "pg";
import { DurableCoreError, sha256Canonical, uuidV7, type JsonRecord } from "./durableCore.js";

export const PUBLIC_ROLLOUT_FLAGS = [
  "enable_public_1v1", "enable_public_crucible", "enable_public_3p_ffa",
  "enable_public_2v2", "enable_public_4p_ffa", "enable_public_ctf",
  "enable_public_hctf", "enable_public_time_puzzles", "enable_public_gauntlet",
  "enable_public_async_3map", "enable_public_async_5map", "enable_rank_mutations",
  "enable_crucible_wax_settlement", "enable_contest_rewards", "enable_bot_fallback",
  "enable_public_leaderboards"
] as const;

export type PublicRolloutFlag = typeof PUBLIC_ROLLOUT_FLAGS[number];
export type PublicRolloutFlags = Record<PublicRolloutFlag, boolean>;

export type OpsConfigRevision = {
  revisionId: string;
  revisionSeq: number;
  configVersion: string;
  minSupportedBuild: number;
  expiresAt: string | null;
  featureFlags: PublicRolloutFlags;
  configHash: string;
  publicationReason: string;
  publishedBy: string;
  publishedAt: string;
  previousRevisionId: string | null;
  rollbackOfRevisionId: string | null;
  requestId: string;
  active: boolean;
};

export type PublishOpsConfigInput = {
  configVersion: string;
  minSupportedBuild: number;
  expiresAt?: string | null;
  featureFlags: Record<string, unknown>;
  publicationReason: string;
  publishedBy: string;
  publishedAt: string;
  requestId: string;
  rollbackOfRevisionId?: string | null;
};

export function failClosedPublicFlags(): PublicRolloutFlags {
  return Object.fromEntries(PUBLIC_ROLLOUT_FLAGS.map((flag) => [flag, false])) as PublicRolloutFlags;
}

export class PostgresPublicModesOpsRepository {
  constructor(private readonly pool: Pool) {}

  async active(nowIso = new Date().toISOString()): Promise<OpsConfigRevision | null> {
    const result = await this.pool.query<Record<string, unknown>>(
      `SELECT * FROM vs_ops_config_revisions
       WHERE active = TRUE AND (expires_at IS NULL OR expires_at > $1::timestamptz)
       ORDER BY revision_seq DESC LIMIT 1`, [nowIso]);
    return result.rows[0] ? revision(result.rows[0]) : null;
  }

  async publish(input: PublishOpsConfigInput): Promise<{ revision: OpsConfigRevision; duplicate: boolean }> {
    validatePublish(input);
    const existing = await this.pool.query<Record<string, unknown>>(
      "SELECT * FROM vs_ops_config_revisions WHERE request_id = $1", [input.requestId]);
    if (existing.rows[0]) return { revision: revision(existing.rows[0]), duplicate: true };
    const flags = normalizeFlags(input.featureFlags);
    const payload: JsonRecord = {
      schema_version: 1, config_version: input.configVersion,
      min_supported_build: input.minSupportedBuild, expires_at: input.expiresAt ?? null,
      feature_flags: flags
    };
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const active = await client.query<Record<string, unknown>>(
        "SELECT revision_id FROM vs_ops_config_revisions WHERE active = TRUE FOR UPDATE");
      const previousId = text(active.rows[0]?.revision_id) || null;
      if (previousId) await client.query("UPDATE vs_ops_config_revisions SET active = FALSE WHERE revision_id = $1", [previousId]);
      const inserted = await client.query<Record<string, unknown>>(
        `INSERT INTO vs_ops_config_revisions
          (revision_id, config_version, min_supported_build, expires_at, feature_flags, config_hash,
           publication_reason, published_by, published_at, previous_revision_id, rollback_of_revision_id,
           request_id, active)
         VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8, $9, $10, $11, $12, TRUE)
         RETURNING *`,
        [uuidV7(), input.configVersion, input.minSupportedBuild, input.expiresAt ?? null,
          JSON.stringify(flags), sha256Canonical(payload), input.publicationReason, input.publishedBy,
          input.publishedAt, previousId, input.rollbackOfRevisionId ?? null, input.requestId]);
      await client.query("COMMIT");
      return { revision: revision(inserted.rows[0]), duplicate: false };
    } catch (error) {
      await client.query("ROLLBACK");
      if (String(error).includes("config_version")) throw new DurableCoreError("ops_config_version_conflict");
      if (String(error).includes("request_id")) {
        const retry = await this.pool.query<Record<string, unknown>>(
          "SELECT * FROM vs_ops_config_revisions WHERE request_id = $1", [input.requestId]);
        if (retry.rows[0]) return { revision: revision(retry.rows[0]), duplicate: true };
      }
      throw error;
    } finally { client.release(); }
  }

  async rollback(targetRevisionId: string, input: Omit<PublishOpsConfigInput, "featureFlags" | "minSupportedBuild" | "expiresAt" | "rollbackOfRevisionId">) {
    const target = await this.pool.query<Record<string, unknown>>(
      "SELECT * FROM vs_ops_config_revisions WHERE revision_id = $1", [targetRevisionId]);
    if (!target.rows[0]) throw new DurableCoreError("ops_config_revision_not_found");
    const value = revision(target.rows[0]);
    return this.publish({ ...input, minSupportedBuild: value.minSupportedBuild, expiresAt: value.expiresAt,
      featureFlags: value.featureFlags, rollbackOfRevisionId: value.revisionId });
  }

  async history(limit = 25): Promise<OpsConfigRevision[]> {
    const result = await this.pool.query<Record<string, unknown>>(
      "SELECT * FROM vs_ops_config_revisions ORDER BY revision_seq DESC LIMIT $1", [Math.max(1, Math.min(limit, 100))]);
    return result.rows.map(revision);
  }

  async recordReconciliation(startedBy: string, startedAt: string, finishedAt: string, result: JsonRecord): Promise<JsonRecord> {
    const status = Number(result.alert_count ?? 0) > 0 ? "ALERT" : "OK";
    const runId = uuidV7();
    await this.pool.query(
      `INSERT INTO vs_ops_reconciliation_runs
       (run_id, started_at, finished_at, started_by, status, result)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb)`,
      [runId, startedAt, finishedAt, startedBy, status, JSON.stringify(result)]);
    return { run_id: runId, started_at: startedAt, finished_at: finishedAt, started_by: startedBy, status, result };
  }

  async syncAlert(alertKey: string, severity: "WARNING" | "CRITICAL", details: JsonRecord,
    open: boolean, nowIso: string): Promise<void> {
    if (open) {
      await this.pool.query(
        `INSERT INTO vs_ops_alerts
          (alert_id, alert_key, severity, status, details, first_seen_at, last_seen_at)
         VALUES ($1, $2, $3, 'OPEN', $4::jsonb, $5, $5)
         ON CONFLICT (alert_key, status) DO UPDATE
         SET severity = EXCLUDED.severity, details = EXCLUDED.details, last_seen_at = EXCLUDED.last_seen_at`,
        [uuidV7(), alertKey, severity, JSON.stringify(details), nowIso]);
      return;
    }
    await this.pool.query("DELETE FROM vs_ops_alerts WHERE alert_key = $1 AND status = 'RESOLVED'", [alertKey]);
    await this.pool.query(
      `UPDATE vs_ops_alerts SET status = 'RESOLVED', resolved_at = $2, last_seen_at = $2
       WHERE alert_key = $1 AND status = 'OPEN'`, [alertKey, nowIso]);
  }

  async dashboard(nowIso = new Date().toISOString()): Promise<JsonRecord> {
    const [active, history, runs, alerts, metrics] = await Promise.all([
      this.active(nowIso), this.history(10),
      this.pool.query<Record<string, unknown>>("SELECT * FROM vs_ops_reconciliation_runs ORDER BY started_at DESC LIMIT 10"),
      this.pool.query<Record<string, unknown>>("SELECT * FROM vs_ops_alerts WHERE status = 'OPEN' ORDER BY last_seen_at DESC LIMIT 50"),
      this.pool.query<Record<string, unknown>>(`SELECT
        (SELECT count(*)::int FROM vs_match_queue_tickets WHERE status = 'WAITING') AS waiting_tickets,
        (SELECT count(*)::int FROM vs_match_contracts WHERE status IN ('FORMED','READY','STARTED')) AS active_matches,
        (SELECT count(*)::int FROM vs_match_verification_jobs WHERE status IN ('PENDING','LEASED','RETRY')) AS verification_backlog,
        (SELECT count(*)::int FROM vs_public_contest_evidence WHERE status IN ('PENDING','LEASED')) AS contest_evidence_backlog,
        (SELECT count(*)::int FROM vs_outbox_events WHERE delivered_at IS NULL) AS undelivered_messages`)
    ]);
    return { generated_at: nowIso, active_config: active, config_history: history,
      metrics: metrics.rows[0] ?? {}, reconciliation_runs: runs.rows, alerts: alerts.rows };
  }
}

function validatePublish(input: PublishOpsConfigInput): void {
  if (!input.configVersion.trim() || input.configVersion.length > 128) throw new DurableCoreError("ops_config_version_invalid");
  if (!input.requestId.trim() || input.requestId.length > 256) throw new DurableCoreError("idempotency_key_required");
  if (!input.publicationReason.trim() || !input.publishedBy.trim()) throw new DurableCoreError("ops_config_audit_fields_required");
  if (!Number.isSafeInteger(input.minSupportedBuild) || input.minSupportedBuild < 0) throw new DurableCoreError("minimum_client_build_invalid");
  if (input.expiresAt && !Number.isFinite(Date.parse(input.expiresAt))) throw new DurableCoreError("ops_config_expiry_invalid");
}

function normalizeFlags(value: Record<string, unknown>): PublicRolloutFlags {
  const unknown = Object.keys(value).filter((key) => !PUBLIC_ROLLOUT_FLAGS.includes(key as PublicRolloutFlag));
  if (unknown.length > 0) throw new DurableCoreError("ops_config_unknown_flag");
  const flags = failClosedPublicFlags();
  for (const flag of PUBLIC_ROLLOUT_FLAGS) {
    if (value[flag] != null && typeof value[flag] !== "boolean") throw new DurableCoreError("ops_config_flag_invalid");
    flags[flag] = value[flag] === true;
  }
  return flags;
}

function revision(row: Record<string, unknown>): OpsConfigRevision {
  const rawFlags = typeof row.feature_flags === "string" ? JSON.parse(row.feature_flags) : row.feature_flags;
  return {
    revisionId: text(row.revision_id), revisionSeq: Number(row.revision_seq),
    configVersion: text(row.config_version), minSupportedBuild: Number(row.min_supported_build),
    expiresAt: iso(row.expires_at), featureFlags: normalizeFlags((rawFlags ?? {}) as Record<string, unknown>),
    configHash: text(row.config_hash), publicationReason: text(row.publication_reason),
    publishedBy: text(row.published_by), publishedAt: iso(row.published_at) ?? "",
    previousRevisionId: text(row.previous_revision_id) || null,
    rollbackOfRevisionId: text(row.rollback_of_revision_id) || null,
    requestId: text(row.request_id), active: row.active === true
  };
}

function text(value: unknown): string { return String(value ?? "").trim(); }
function iso(value: unknown): string | null {
  if (value == null || value === "") return null;
  const parsed = value instanceof Date ? value : new Date(String(value));
  return Number.isFinite(parsed.getTime()) ? parsed.toISOString() : null;
}
