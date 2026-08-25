import type { Pool, PoolClient } from "pg";
import { deepClone, DurableCoreError, sha256Canonical, uuidV7, type JsonRecord } from "./durableCore.js";
import type { SignedSyncResult } from "./verificationAuthority.js";
import type { EconomyRolloutBoundary } from "./platformEconomyDelivery.js";

type Row = Record<string, unknown>;
export type RankSettlementStatus = "PENDING" | "LEASED" | "RETRY" | "SETTLED" | "FAILED" | "NOT_APPLICABLE";
export type RankSettlementBundle = {
  settlementId: string; resultId: string; rankEventId: string; matchId: string; contractId: string;
  matchEpoch: number; leaseToken: string; attempt: number; signedReceipt: SignedSyncResult; result: JsonRecord;
};
export type RankSettlementView = {
  status: "NOT_ELIGIBLE" | RankSettlementStatus; resultId: string | null; rankEventId: string | null;
  attemptCount: number; lastErrorCode: string | null; rankResponse: JsonRecord | null; settledAt: string | null;
};

export class PostgresRankSettlementRepository {
  constructor(private readonly pool: Pool) {}

  async reconcile(nowIso: string, boundary: EconomyRolloutBoundary = {}): Promise<number> {
    const rollout = normalizeBoundary(boundary);
    const inserted = await this.pool.query(
      `INSERT INTO vs_rank_settlement_jobs
        (settlement_id, result_id, rank_event_id, match_id, contract_id, match_epoch,
         status, available_at, created_at, updated_at)
       SELECT r.result_id, r.result_id, r.result_id, r.match_id, r.contract_id, r.match_epoch,
         CASE WHEN r.terminal_reason = 'NO_CONTEST' THEN 'NOT_APPLICABLE' ELSE 'PENDING' END,
         $1, $1, $1
       FROM vs_terminal_results r
       JOIN vs_match_contracts c ON c.contract_id = r.contract_id
       JOIN vs_verifier_signed_receipts s ON s.result_id = r.result_id
       WHERE c.mode_id = 'STANDARD_1V1'
         AND c.authority_tier = 'AUTHORITY_VERIFIED'
         AND COALESCE((c.contract_json->'rank_policy'->>'enabled')::boolean, false) = true
         AND ($2::timestamptz IS NULL OR r.verified_at >= $2::timestamptz)
         AND (COALESCE(array_length($3::text[], 1), 0) = 0 OR
           (EXISTS (SELECT 1 FROM vs_match_roster allowed_roster
              WHERE allowed_roster.contract_id = c.contract_id
                AND allowed_roster.participant_type = 'HUMAN')
            AND NOT EXISTS (SELECT 1 FROM vs_match_roster denied_roster
              WHERE denied_roster.contract_id = c.contract_id
                AND denied_roster.participant_type = 'HUMAN'
                AND NOT (denied_roster.player_id::text = ANY($3::text[])))))
       ON CONFLICT (result_id) DO NOTHING`, [nowIso, rollout.verifiedAtOrAfter, rollout.allowedPlayerIds]
    );
    return inserted.rowCount ?? 0;
  }

  async leaseNext(workerId: string, nowIso: string, leaseSec: number,
    boundary: EconomyRolloutBoundary = {}): Promise<RankSettlementBundle | null> {
    const rollout = normalizeBoundary(boundary);
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `UPDATE vs_rank_settlement_jobs SET status = 'RETRY', lease_owner = NULL, lease_token = NULL,
           lease_expires_at = NULL, available_at = $1, updated_at = $1
         WHERE status = 'LEASED' AND lease_expires_at <= $1`, [nowIso]
      );
      const found = await client.query<Row>(
        `SELECT j.* FROM vs_rank_settlement_jobs j
         JOIN vs_terminal_results r ON r.result_id = j.result_id
         JOIN vs_match_contracts c ON c.contract_id = j.contract_id
         WHERE j.status IN ('PENDING', 'RETRY') AND j.available_at <= $1
           AND ($2::timestamptz IS NULL OR r.verified_at >= $2::timestamptz)
           AND (COALESCE(array_length($3::text[], 1), 0) = 0 OR
             (EXISTS (SELECT 1 FROM vs_match_roster allowed_roster
                WHERE allowed_roster.contract_id = c.contract_id
                  AND allowed_roster.participant_type = 'HUMAN')
              AND NOT EXISTS (SELECT 1 FROM vs_match_roster denied_roster
                WHERE denied_roster.contract_id = c.contract_id
                  AND denied_roster.participant_type = 'HUMAN'
                  AND NOT (denied_roster.player_id::text = ANY($3::text[])))))
         ORDER BY j.available_at, j.created_at, j.settlement_id
         LIMIT 1 FOR UPDATE OF j SKIP LOCKED`, [nowIso, rollout.verifiedAtOrAfter, rollout.allowedPlayerIds]
      );
      if (!found.rows[0]) { await client.query("COMMIT"); return null; }
      const leaseToken = uuidV7();
      const leaseExpiresAt = new Date(new Date(nowIso).getTime() + leaseSec * 1_000).toISOString();
      const updated = await client.query<Row>(
        `UPDATE vs_rank_settlement_jobs SET status = 'LEASED', attempt_count = attempt_count + 1,
           lease_owner = $2, lease_token = $3, lease_expires_at = $4, updated_at = $1
         WHERE settlement_id = $5 RETURNING *`, [nowIso, workerId, leaseToken, leaseExpiresAt, found.rows[0].settlement_id]
      );
      await client.query("COMMIT");
      return this.bundle(updated.rows[0]);
    } catch (error) {
      await rollback(client);
      throw error;
    } finally { client.release(); }
  }

  async complete(input: {
    settlementId: string; workerId: string; leaseToken: string; startedAt: string; finishedAt: string;
    request: JsonRecord; response: JsonRecord;
  }): Promise<RankSettlementView> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const locked = await client.query<Row>(
        "SELECT * FROM vs_rank_settlement_jobs WHERE settlement_id = $1 FOR UPDATE", [input.settlementId]
      );
      const job = locked.rows[0];
      if (!job) throw new DurableCoreError("rank_settlement_not_found");
      if (String(job.status) === "SETTLED") { await client.query("COMMIT"); return view(job); }
      requireLease(job, input.workerId, input.leaseToken);
      if (input.response.ok !== true || input.response.status !== "SETTLED"
        || String(input.response.rank_event_id) !== String(job.rank_event_id)) {
        throw new DurableCoreError("rank_settlement_response_invalid");
      }
      await client.query(
        `INSERT INTO vs_rank_settlement_attempts
          (attempt_id, settlement_id, attempt, worker_id, status, request_hash, response_json, started_at, finished_at)
         VALUES ($1, $2, $3, $4, 'SETTLED', $5, $6::jsonb, $7, $8)`,
        [uuidV7(), job.settlement_id, job.attempt_count, input.workerId, sha256Canonical(input.request),
          JSON.stringify(input.response), input.startedAt, input.finishedAt]
      );
      const updated = await client.query<Row>(
        `UPDATE vs_rank_settlement_jobs SET status = 'SETTLED', rank_response = $2::jsonb,
           settled_at = $3, lease_owner = NULL, lease_token = NULL, lease_expires_at = NULL, updated_at = $3
         WHERE settlement_id = $1 RETURNING *`, [job.settlement_id, JSON.stringify(input.response), input.finishedAt]
      );
      await client.query("COMMIT");
      return view(updated.rows[0]);
    } catch (error) { await rollback(client); throw error; } finally { client.release(); }
  }

  async fail(input: {
    settlementId: string; workerId: string; leaseToken: string; startedAt: string; finishedAt: string;
    request: JsonRecord; response: JsonRecord; errorCode: string; retryable: boolean; retryDelaySec: number;
  }): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const locked = await client.query<Row>(
        "SELECT * FROM vs_rank_settlement_jobs WHERE settlement_id = $1 FOR UPDATE", [input.settlementId]
      );
      const job = locked.rows[0];
      if (!job) throw new DurableCoreError("rank_settlement_not_found");
      requireLease(job, input.workerId, input.leaseToken);
      // A verified result must remain recoverable through an arbitrarily long Rank outage.
      // max_attempts is an alert threshold, not a license to discard trusted settlement work.
      const retry = input.retryable;
      await client.query(
        `INSERT INTO vs_rank_settlement_attempts
          (attempt_id, settlement_id, attempt, worker_id, status, request_hash, response_json,
           error_code, started_at, finished_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9, $10)`,
        [uuidV7(), job.settlement_id, job.attempt_count, input.workerId,
          retry ? "RETRYABLE_FAILURE" : "PERMANENT_FAILURE", sha256Canonical(input.request),
          JSON.stringify(input.response), input.errorCode, input.startedAt, input.finishedAt]
      );
      const availableAt = new Date(new Date(input.finishedAt).getTime() + input.retryDelaySec * 1_000).toISOString();
      await client.query(
        `UPDATE vs_rank_settlement_jobs SET status = $2, available_at = $3, last_error_code = $4,
           last_error_detail = $5::jsonb, lease_owner = NULL, lease_token = NULL,
           lease_expires_at = NULL, updated_at = $6 WHERE settlement_id = $1`,
        [job.settlement_id, retry ? "RETRY" : "FAILED", availableAt, input.errorCode,
          JSON.stringify(input.response), input.finishedAt]
      );
      await client.query("COMMIT");
    } catch (error) { await rollback(client); throw error; } finally { client.release(); }
  }

  async getForPlayer(matchId: string, playerId: string): Promise<RankSettlementView> {
    const member = await this.pool.query(
      `SELECT 1 FROM vs_match_contracts c JOIN vs_match_roster r ON r.contract_id = c.contract_id
       WHERE c.match_id = $1 AND r.player_id = $2`, [matchId, playerId]
    );
    if ((member.rowCount ?? 0) === 0) throw new DurableCoreError("player_not_in_match");
    const row = await this.pool.query<Row>("SELECT * FROM vs_rank_settlement_jobs WHERE match_id = $1", [matchId]);
    return row.rows[0] ? view(row.rows[0]) : {
      status: "NOT_ELIGIBLE", resultId: null, rankEventId: null, attemptCount: 0,
      lastErrorCode: null, rankResponse: null, settledAt: null
    };
  }

  private async bundle(job: Row): Promise<RankSettlementBundle> {
    const rows = await this.pool.query<Row>(
      `SELECT r.result_json, s.signed_payload, s.signed_payload_hash, s.verifier_key_id,
          s.signature_algorithm, s.signature
       FROM vs_terminal_results r JOIN vs_verifier_signed_receipts s ON s.result_id = r.result_id
       WHERE r.result_id = $1`, [job.result_id]
    );
    const row = rows.rows[0];
    if (!row) throw new DurableCoreError("rank_settlement_evidence_missing");
    if (String(row.signature_algorithm) !== "ES256") {
      throw new DurableCoreError("rank_settlement_evidence_invalid");
    }
    return {
      settlementId: String(job.settlement_id), resultId: String(job.result_id), rankEventId: String(job.rank_event_id),
      matchId: String(job.match_id), contractId: String(job.contract_id), matchEpoch: Number(job.match_epoch),
      leaseToken: String(job.lease_token), attempt: Number(job.attempt_count), result: json(row.result_json),
      signedReceipt: { payload: json(row.signed_payload), payloadHash: String(row.signed_payload_hash),
        keyId: String(row.verifier_key_id), algorithm: "ES256", signature: String(row.signature) }
    };
  }
}

function view(row: Row): RankSettlementView {
  return {
    status: String(row.status) as RankSettlementStatus, resultId: String(row.result_id),
    rankEventId: String(row.rank_event_id), attemptCount: Number(row.attempt_count),
    lastErrorCode: row.last_error_code == null ? null : String(row.last_error_code),
    rankResponse: row.rank_response == null ? null : json(row.rank_response),
    settledAt: row.settled_at == null ? null : iso(row.settled_at)
  };
}
function requireLease(row: Row, workerId: string, leaseToken: string): void {
  if (row.status !== "LEASED" || row.lease_owner !== workerId || row.lease_token !== leaseToken) {
    throw new DurableCoreError("rank_settlement_lease_invalid");
  }
}
function json(value: unknown): JsonRecord {
  if (typeof value === "string") value = JSON.parse(value);
  if (typeof value !== "object" || value == null || Array.isArray(value)) throw new DurableCoreError("stored_json_invalid");
  return deepClone(value as JsonRecord);
}
function iso(value: unknown): string { return new Date(value instanceof Date ? value : String(value)).toISOString(); }
async function rollback(client: PoolClient): Promise<void> { try { await client.query("ROLLBACK"); } catch {} }

function normalizeBoundary(boundary: EconomyRolloutBoundary): {
  verifiedAtOrAfter: string | null;
  allowedPlayerIds: string[];
} {
  const rawCutover = String(boundary.verifiedAtOrAfter ?? "").trim();
  const verifiedAtOrAfter = rawCutover ? new Date(rawCutover).toISOString() : null;
  const allowedPlayerIds = [...new Set((boundary.allowedPlayerIds ?? [])
    .map((playerId) => String(playerId).trim().toLowerCase()).filter(Boolean))];
  return { verifiedAtOrAfter, allowedPlayerIds };
}
