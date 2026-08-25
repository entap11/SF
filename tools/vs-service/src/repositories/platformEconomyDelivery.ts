import type { Pool, PoolClient } from "pg";
import { deepClone, DurableCoreError, sha256Canonical, uuidV7, type JsonRecord } from "./durableCore.js";

type Row = Record<string, unknown>;

export type PlatformEconomyOperation = "HONEY_ACTIVITY" | "NECTAR_MATCH" | "CRUCIBLE_RESERVE"
  | "CRUCIBLE_SETTLE" | "CRUCIBLE_REFUND";

export type EconomyRolloutBoundary = {
  verifiedAtOrAfter?: string;
  allowedPlayerIds?: readonly string[];
};

export type PlatformEconomyDelivery = {
  deliveryId: string;
  producerEventId: string;
  operation: PlatformEconomyOperation;
  matchId: string | null;
  contractId: string | null;
  resultId: string | null;
  playerId: string | null;
  economyEpoch: string;
  sourceAuthority: string;
  occurredAt: string;
  payload: JsonRecord;
  requestHash: string;
  leaseToken: string;
  attempt: number;
};

export class PostgresPlatformEconomyDeliveryRepository {
  constructor(private readonly pool: Pool) {}

  async enqueueCrucibleReservations(matchId: string, economyEpoch: string, nowIso: string,
    boundary: EconomyRolloutBoundary = {}): Promise<number> {
    const contract = await this.pool.query<Row>(
      `SELECT c.contract_id, c.match_id, c.contract_hash, c.expires_at, c.authority_tier,
          array_agg(r.player_id ORDER BY r.seat_id) FILTER (WHERE r.participant_type = 'HUMAN') AS player_ids
       FROM vs_match_contracts c JOIN vs_match_roster r ON r.contract_id = c.contract_id
       WHERE c.match_id = $1 AND c.mode_id = 'CRUCIBLE_1V1'
       GROUP BY c.contract_id`, [matchId]
    );
    const row = contract.rows[0];
    const playerIds = Array.isArray(row?.player_ids) ? row.player_ids.map(String) : [];
    if (!row) throw new DurableCoreError("crucible_contract_not_found");
    if (String(row.authority_tier) !== "AUTHORITY_VERIFIED" || playerIds.length !== 2) {
      throw new DurableCoreError("crucible_contract_not_reservable");
    }
    if (!rolloutAllows(nowIso, playerIds, boundary)) throw new DurableCoreError("economy_rollout_boundary_denied");
    let inserted = 0;
    for (const playerId of playerIds) {
      const payload: JsonRecord = {
        match_id: String(row.match_id), contract_id: String(row.contract_id),
        contract_hash: String(row.contract_hash), player_id: playerId,
        player_a_id: playerIds[0], player_b_id: playerIds[1],
        expires_at: iso(row.expires_at)
      };
      inserted += await this.insert({
        producerEventId: `crucible:${matchId}:reserve:${playerId}`,
        operation: "CRUCIBLE_RESERVE", matchId, contractId: String(row.contract_id),
        resultId: null, playerId, economyEpoch, sourceAuthority: "VS_MATCH_CONTRACT",
        occurredAt: nowIso, payload
      });
    }
    return inserted;
  }

  async enqueueCrucibleCancellationRefund(matchId: string, economyEpoch: string, reason: string,
    nowIso: string): Promise<number> {
    const contract = await this.pool.query<Row>(
      "SELECT contract_id FROM vs_match_contracts WHERE match_id = $1 AND mode_id = 'CRUCIBLE_1V1'", [matchId]
    );
    if (!contract.rows[0]) throw new DurableCoreError("crucible_contract_not_found");
    return this.insert({
      producerEventId: `crucible:${matchId}:refund:cancellation`, operation: "CRUCIBLE_REFUND",
      matchId, contractId: String(contract.rows[0].contract_id), resultId: null, playerId: null,
      economyEpoch, sourceAuthority: "VS_MATCH_LIFECYCLE", occurredAt: nowIso,
      payload: { match_id: matchId, result_id: matchId, reason }
    });
  }

  async reconcileVerifiedResults(economyEpoch: string, nowIso: string,
    boundary: EconomyRolloutBoundary = {}): Promise<number> {
    const rollout = normalizeBoundary(boundary);
    const results = await this.pool.query<Row>(
      `SELECT r.result_id, r.match_id, r.contract_id, r.terminal_reason, r.result_json,
          r.verified_at, c.mode_id, c.authority_tier,
          ARRAY(SELECT rr.player_id::text FROM vs_match_roster rr
            WHERE rr.contract_id = c.contract_id AND rr.participant_type = 'HUMAN'
            ORDER BY rr.seat_id) AS human_player_ids
       FROM vs_terminal_results r
       JOIN vs_verifier_signed_receipts s ON s.result_id = r.result_id
       JOIN vs_match_contracts c ON c.contract_id = r.contract_id
       WHERE c.authority_tier = 'AUTHORITY_VERIFIED'
         AND ($1::timestamptz IS NULL OR r.verified_at >= $1::timestamptz)
       ORDER BY r.verified_at, r.result_id`, [rollout.verifiedAtOrAfter]
    );
    let inserted = 0;
    for (const row of results.rows) {
      const result = json(row.result_json);
      const resultId = String(row.result_id);
      const matchId = String(row.match_id);
      const contractId = String(row.contract_id);
      const modeId = String(row.mode_id);
      const terminalReason = String(row.terminal_reason);
      const occurredAt = iso(row.verified_at);
      const rosterPlayerIds = Array.isArray(row.human_player_ids) ? row.human_player_ids.map(String) : [];
      if (!rolloutAllows(occurredAt, rosterPlayerIds, boundary)) continue;
      const placements = Array.isArray(result.placements) ? result.placements as JsonRecord[] : [];
      if (modeId === "CRUCIBLE_1V1") {
        const winner = firstPlayer(placements[0]);
        const operation: PlatformEconomyOperation = terminalReason === "NO_CONTEST"
          ? "CRUCIBLE_REFUND" : "CRUCIBLE_SETTLE";
        const payload: JsonRecord = operation === "CRUCIBLE_SETTLE"
          ? { match_id: matchId, result_id: resultId, winner_player_id: winner }
          : { match_id: matchId, result_id: resultId, reason: String(result.no_contest_reason ?? "no_contest") };
        inserted += await this.insert({
          producerEventId: `${resultId}:${operation.toLowerCase()}`, operation, matchId, contractId,
          resultId, playerId: null, economyEpoch, sourceAuthority: String(result.authority_method),
          occurredAt, payload
        });
        continue;
      }
      if (terminalReason === "NO_CONTEST") continue;
      const playerIds = placements.flatMap((placement) => {
        const ids = Array.isArray(placement.player_ids) ? placement.player_ids.map(String) : [];
        return ids.map((playerId) => ({ playerId, place: Number(placement.place) }));
      });
      const durationSec = Math.max(0, Number(result.elapsed_sim_ticks ?? 0) / 10);
      for (const entry of playerIds) {
        const opponents = playerIds.filter((other) => other.playerId !== entry.playerId).map((other) => other.playerId);
        const common = {
          player_id: entry.playerId, mode_id: platformMode(modeId), opponent_ids: opponents,
          duration_sec: durationSec, completed: true, did_win: entry.place === 1,
          terminal_reason: terminalReason, result_id: resultId, match_id: matchId
        };
        inserted += await this.insert({
          producerEventId: `${resultId}:honey:${entry.playerId}`, operation: "HONEY_ACTIVITY",
          matchId, contractId, resultId, playerId: entry.playerId, economyEpoch,
          sourceAuthority: String(result.authority_method), occurredAt,
          payload: { ...common, activity_key: "competitive.live_free", entap_title: "swarmfront" }
        });
        inserted += await this.insert({
          producerEventId: `${resultId}:nectar:${entry.playerId}`, operation: "NECTAR_MATCH",
          matchId, contractId, resultId, playerId: entry.playerId, economyEpoch,
          sourceAuthority: String(result.authority_method), occurredAt, payload: common
        });
      }
    }
    return inserted;
  }

  async leaseNext(workerId: string, nowIso: string, leaseSec: number,
    filter: { matchId?: string; operation?: PlatformEconomyOperation } = {},
    boundary: EconomyRolloutBoundary = {}): Promise<PlatformEconomyDelivery | null> {
    const rollout = normalizeBoundary(boundary);
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `UPDATE vs_platform_economy_deliveries SET status = 'RETRY', lease_owner = NULL,
           lease_token = NULL, lease_expires_at = NULL, available_at = $1, updated_at = $1
         WHERE status = 'LEASED' AND lease_expires_at <= $1`, [nowIso]
      );
      const found = await client.query<Row>(
        `SELECT d.* FROM vs_platform_economy_deliveries d
         WHERE d.status IN ('PENDING', 'RETRY') AND d.available_at <= $1
           AND ($2::uuid IS NULL OR d.match_id = $2)
           AND ($3::text IS NULL OR d.operation = $3)
           AND ($4::timestamptz IS NULL OR d.occurred_at >= $4::timestamptz)
           AND (COALESCE(array_length($5::text[], 1), 0) = 0 OR
             (d.contract_id IS NULL AND d.player_id::text = ANY($5::text[])) OR
             (d.contract_id IS NOT NULL
               AND EXISTS (SELECT 1 FROM vs_match_roster allowed_roster
                 WHERE allowed_roster.contract_id = d.contract_id
                   AND allowed_roster.participant_type = 'HUMAN')
               AND NOT EXISTS (SELECT 1 FROM vs_match_roster denied_roster
                 WHERE denied_roster.contract_id = d.contract_id
                   AND denied_roster.participant_type = 'HUMAN'
                   AND NOT (denied_roster.player_id::text = ANY($5::text[])))))
         ORDER BY d.available_at, d.created_at, d.delivery_id LIMIT 1 FOR UPDATE OF d SKIP LOCKED`,
        [nowIso, filter.matchId ?? null, filter.operation ?? null,
          rollout.verifiedAtOrAfter, rollout.allowedPlayerIds]
      );
      if (!found.rows[0]) { await client.query("COMMIT"); return null; }
      const leaseToken = uuidV7();
      const leaseExpiresAt = new Date(new Date(nowIso).getTime() + leaseSec * 1_000).toISOString();
      const updated = await client.query<Row>(
        `UPDATE vs_platform_economy_deliveries SET status = 'LEASED', attempt_count = attempt_count + 1,
           lease_owner = $2, lease_token = $3, lease_expires_at = $4, updated_at = $1
         WHERE delivery_id = $5 RETURNING *`,
        [nowIso, workerId, leaseToken, leaseExpiresAt, found.rows[0].delivery_id]
      );
      await client.query("COMMIT");
      return delivery(updated.rows[0]);
    } catch (error) { await rollback(client); throw error; } finally { client.release(); }
  }

  async complete(input: { deliveryId: string; workerId: string; leaseToken: string;
    startedAt: string; finishedAt: string; response: JsonRecord }): Promise<void> {
    await this.finish({ ...input, retryable: false, errorCode: "", delivered: true, retryDelaySec: 0 });
  }

  async fail(input: { deliveryId: string; workerId: string; leaseToken: string;
    startedAt: string; finishedAt: string; response: JsonRecord; retryable: boolean;
    errorCode: string; retryDelaySec: number }): Promise<void> {
    await this.finish({ ...input, delivered: false });
  }

  async crucibleReservationsCommitted(matchId: string): Promise<boolean> {
    const result = await this.pool.query<{ count: number }>(
      `SELECT count(DISTINCT player_id)::int AS count FROM vs_platform_economy_deliveries
       WHERE match_id = $1 AND operation = 'CRUCIBLE_RESERVE' AND status = 'DELIVERED'`, [matchId]
    );
    return Number(result.rows[0]?.count ?? 0) === 2;
  }

  async pendingCount(): Promise<number> {
    const result = await this.pool.query<{ count: number }>(
      "SELECT count(*)::int AS count FROM vs_platform_economy_deliveries WHERE status IN ('PENDING', 'LEASED', 'RETRY')"
    );
    return Number(result.rows[0]?.count ?? 0);
  }

  private async insert(input: {
    producerEventId: string; operation: PlatformEconomyOperation; matchId: string | null;
    contractId: string | null; resultId: string | null; playerId: string | null;
    economyEpoch: string; sourceAuthority: string; occurredAt: string; payload: JsonRecord;
  }): Promise<number> {
    if (!input.economyEpoch.trim()) throw new DurableCoreError("platform_economy_epoch_missing");
    const requestHash = sha256Canonical(envelope(input));
    const inserted = await this.pool.query(
      `INSERT INTO vs_platform_economy_deliveries
        (delivery_id, producer_event_id, operation, match_id, contract_id, result_id, player_id,
         economy_epoch, source_authority, occurred_at, payload, request_hash, status,
         available_at, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12, 'PENDING', $10, $10, $10)
       ON CONFLICT (producer_event_id) DO NOTHING`,
      [uuidV7(), input.producerEventId, input.operation, input.matchId, input.contractId,
        input.resultId, input.playerId, input.economyEpoch, input.sourceAuthority,
        input.occurredAt, JSON.stringify(input.payload), requestHash]
    );
    return inserted.rowCount ?? 0;
  }

  private async finish(input: { deliveryId: string; workerId: string; leaseToken: string;
    startedAt: string; finishedAt: string; response: JsonRecord; retryable: boolean;
    errorCode: string; retryDelaySec: number; delivered: boolean }): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const locked = await client.query<Row>(
        "SELECT * FROM vs_platform_economy_deliveries WHERE delivery_id = $1 FOR UPDATE", [input.deliveryId]
      );
      const row = locked.rows[0];
      if (!row) throw new DurableCoreError("platform_delivery_not_found");
      if (String(row.status) === "DELIVERED" && input.delivered) { await client.query("COMMIT"); return; }
      if (row.status !== "LEASED" || row.lease_owner !== input.workerId || row.lease_token !== input.leaseToken) {
        throw new DurableCoreError("platform_delivery_lease_invalid");
      }
      const attemptStatus = input.delivered ? "DELIVERED"
        : input.retryable ? "RETRYABLE_FAILURE" : "PERMANENT_FAILURE";
      await client.query(
        `INSERT INTO vs_platform_economy_delivery_attempts
          (attempt_id, delivery_id, attempt, worker_id, status, request_hash, response_json,
           error_code, started_at, finished_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9, $10)`,
        [uuidV7(), row.delivery_id, row.attempt_count, input.workerId, attemptStatus,
          row.request_hash, JSON.stringify(input.response), input.errorCode || null,
          input.startedAt, input.finishedAt]
      );
      const availableAt = new Date(new Date(input.finishedAt).getTime() + input.retryDelaySec * 1000).toISOString();
      await client.query(
        `UPDATE vs_platform_economy_deliveries SET status = $2, available_at = $3,
           response_json = $4::jsonb, last_error_code = $5,
           delivered_at = CASE WHEN $2 = 'DELIVERED' THEN $6::timestamptz ELSE delivered_at END,
           lease_owner = NULL, lease_token = NULL, lease_expires_at = NULL, updated_at = $6
         WHERE delivery_id = $1`,
        [row.delivery_id, input.delivered ? "DELIVERED" : input.retryable ? "RETRY" : "FAILED",
          availableAt, JSON.stringify(input.response), input.errorCode || null, input.finishedAt]
      );
      await client.query("COMMIT");
    } catch (error) { await rollback(client); throw error; } finally { client.release(); }
  }
}

export function platformDeliveryEnvelope(delivery: Pick<PlatformEconomyDelivery,
  "producerEventId" | "economyEpoch" | "sourceAuthority" | "occurredAt" | "payload">): JsonRecord {
  return {
    producer_event_id: delivery.producerEventId, economy_epoch: delivery.economyEpoch,
    source_authority: delivery.sourceAuthority, occurred_at: delivery.occurredAt,
    schema_version: 1, payload: deepClone(delivery.payload)
  };
}

function envelope(input: { producerEventId: string; economyEpoch: string; sourceAuthority: string;
  occurredAt: string; payload: JsonRecord }): JsonRecord {
  return platformDeliveryEnvelope(input);
}

function delivery(row: Row): PlatformEconomyDelivery {
  return {
    deliveryId: String(row.delivery_id), producerEventId: String(row.producer_event_id),
    operation: String(row.operation) as PlatformEconomyOperation,
    matchId: row.match_id == null ? null : String(row.match_id),
    contractId: row.contract_id == null ? null : String(row.contract_id),
    resultId: row.result_id == null ? null : String(row.result_id),
    playerId: row.player_id == null ? null : String(row.player_id), economyEpoch: String(row.economy_epoch),
    sourceAuthority: String(row.source_authority), occurredAt: iso(row.occurred_at), payload: json(row.payload),
    requestHash: String(row.request_hash), leaseToken: String(row.lease_token), attempt: Number(row.attempt_count)
  };
}

function platformMode(modeId: string): string {
  if (modeId === "STANDARD_1V1") return "STANDARD";
  if (modeId.includes("CTF")) return "STANDARD";
  return modeId.replace(/_[0-9].*$/, "") || "STANDARD";
}

function firstPlayer(placement: JsonRecord | undefined): string {
  return String((Array.isArray(placement?.player_ids) ? placement.player_ids as unknown[] : [])[0] ?? "");
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
  const verifiedAtOrAfter = rawCutover ? iso(rawCutover) : null;
  const allowedPlayerIds = [...new Set((boundary.allowedPlayerIds ?? [])
    .map((playerId) => String(playerId).trim().toLowerCase()).filter(Boolean))];
  return { verifiedAtOrAfter, allowedPlayerIds };
}

function rolloutAllows(occurredAt: string, rosterPlayerIds: string[], boundary: EconomyRolloutBoundary): boolean {
  const rollout = normalizeBoundary(boundary);
  if (rollout.verifiedAtOrAfter && Date.parse(occurredAt) < Date.parse(rollout.verifiedAtOrAfter)) return false;
  if (rollout.allowedPlayerIds.length === 0) return true;
  if (rosterPlayerIds.length === 0) return false;
  const allowed = new Set(rollout.allowedPlayerIds);
  return rosterPlayerIds.every((playerId) => allowed.has(String(playerId).trim().toLowerCase()));
}
