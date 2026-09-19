import crypto, { type JsonWebKey } from "node:crypto";
import type { Pool, PoolClient } from "pg";
import type { PlayerTokenClaims } from "./playerToken.js";
import { IdentitySessionError, verifyDeviceSignature } from "./sessionStore.js";

export const DELETION_APPLICATION = "swarmfront";
export const DELETION_DOMAINS = ["identity", "multiplayer", "analytics", "community", "support", "backups"] as const;
const hash = (value: string): string => crypto.createHash("sha256").update(value).digest("hex");
type RequestRow = {
  request_id: string; player_id: string | null; receipt_hash: string; status: string;
  requested_at: Date | string; target_at: Date | string; completed_at: Date | string | null;
};
export type Retention = { category: string; reason: string; expires_at: string };

export class AccountDeletionStore {
  constructor(private readonly pool: Pool, readonly acceptingRequests = false) {}

  async assertActiveSession(claims: PlayerTokenClaims): Promise<void> {
    const deleted = await this.pool.query("SELECT 1 FROM entap_account_deletion_requests WHERE application_id = 'swarmfront' AND subject_hash = $1", [hash(claims.sub)]);
    if (deleted.rowCount) throw new IdentitySessionError("account_deletion_pending", 403);
    const result = await this.pool.query(`SELECT 1 FROM entap_player_sessions s
      JOIN entap_player_devices d ON d.id = s.device_id JOIN rank_players p ON p.id = s.player_id
      WHERE s.id = $1::uuid AND s.player_id = $2::uuid AND s.device_id = $3::uuid
        AND s.revoked_at IS NULL AND s.expires_at > now() AND d.status = 'active'
        AND p.account_status = 'active' AND s.application_id = 'swarmfront' AND d.application_id = 'swarmfront'`, [claims.sid, claims.sub, claims.did]);
    if (!result.rowCount) throw new IdentitySessionError("account_or_session_inactive", 403);
  }

  async challenge(claims: PlayerTokenClaims, requestId: string, receiptToken: string): Promise<Record<string, unknown>> {
    if (!this.acceptingRequests) throw new IdentitySessionError("deletion_requests_not_enabled", 503);
    this.validateReceipt(requestId, receiptToken);
    await this.assertActiveSession(claims);
    const receiptHash = hash(receiptToken);
    const message = `swarmfront:account-delete:v1:${claims.sub}:${claims.did}:${requestId}:${receiptHash}:${crypto.randomBytes(32).toString("base64url")}`;
    const result = await this.pool.query<{ challenge: string; expires_at: Date | string }>(`
      INSERT INTO entap_account_deletion_challenges (request_id, player_id, device_id, receipt_hash, challenge)
      VALUES ($1, $2::uuid, $3::uuid, $4, $5)
      ON CONFLICT (request_id) DO UPDATE SET request_id = EXCLUDED.request_id
      WHERE entap_account_deletion_challenges.player_id = EXCLUDED.player_id
        AND entap_account_deletion_challenges.device_id = EXCLUDED.device_id
        AND entap_account_deletion_challenges.receipt_hash = EXCLUDED.receipt_hash
      RETURNING challenge, expires_at`, [requestId, claims.sub, claims.did, receiptHash, message]);
    if (!result.rows[0]) throw new IdentitySessionError("deletion_request_conflict", 409);
    return { request_id: requestId, ...result.rows[0] };
  }

  async confirm(requestId: string, receiptToken: string, signature: string): Promise<Record<string, unknown>> {
    this.validateReceipt(requestId, receiptToken);
    return this.transaction(async client => {
      // Same lock as RankStore: an in-flight rank write cannot restore a hidden player.
      await client.query("SELECT pg_advisory_xact_lock($1)", [934_771_112]);
      const existing = await client.query<RequestRow>("SELECT * FROM entap_account_deletion_requests WHERE request_id = $1", [requestId]);
      if (existing.rows[0]) {
        this.checkReceipt(existing.rows[0], receiptToken);
        return this.publicReceipt(existing.rows[0]);
      }
      const proof = await client.query<{
        player_id: string; device_id: string; receipt_hash: string; challenge: string;
        expires_at: Date | string; public_key_jwk: JsonWebKey; status: string;
      }>(`SELECT c.*, d.public_key_jwk, d.status FROM entap_account_deletion_challenges c
        JOIN entap_player_devices d ON d.id = c.device_id WHERE c.request_id = $1 AND d.application_id = 'swarmfront' FOR UPDATE OF c, d`, [requestId]);
      const row = proof.rows[0];
      if (!row || row.receipt_hash !== hash(receiptToken)) throw new IdentitySessionError("deletion_proof_invalid", 401);
      if (new Date(row.expires_at).getTime() <= Date.now()) throw new IdentitySessionError("deletion_challenge_expired", 410);
      if (row.status !== "active" || !verifyDeviceSignature(row.public_key_jwk, row.challenge, signature)) {
        throw new IdentitySessionError("deletion_proof_invalid", 401);
      }
      return this.createPending(client, requestId, row.player_id, row.receipt_hash);
    });
  }


  async acceptVerifiedSupportRequest(input: {
    requestId: string; receiptToken: string; playerId: string; verificationEvidenceRef: string;
  }): Promise<Record<string, unknown>> {
    if (!this.acceptingRequests) throw new IdentitySessionError("deletion_requests_not_enabled", 503);
    this.validateReceipt(input.requestId, input.receiptToken);
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(input.playerId)
      || !/^[A-Za-z0-9][A-Za-z0-9._:/-]{7,255}$/.test(input.verificationEvidenceRef)) {
      throw new IdentitySessionError("verified_ownership_evidence_required");
    }
    return this.transaction(async client => {
      await client.query("SELECT pg_advisory_xact_lock($1)", [934_771_112]);
      const existing = (await client.query<RequestRow>(
        "SELECT * FROM entap_account_deletion_requests WHERE request_id = $1", [input.requestId])).rows[0];
      if (existing) {
        this.checkReceipt(existing, input.receiptToken);
        return this.publicReceipt(existing);
      }
      const player = await client.query("SELECT 1 FROM rank_players WHERE id = $1::uuid AND account_status = 'active' FOR UPDATE", [input.playerId]);
      if (!player.rowCount) throw new IdentitySessionError("active_account_not_found", 404);
      const result = await this.createPending(client, input.requestId, input.playerId, hash(input.receiptToken));
      await client.query(`UPDATE entap_account_deletion_requests SET verification_evidence_ref = $2
        WHERE request_id = $1`, [input.requestId, input.verificationEvidenceRef]);
      return result;
    });
  }

  private async createPending(client: PoolClient, requestId: string, playerId: string, receiptHash: string): Promise<Record<string, unknown>> {
    playerId = playerId.toLowerCase();
    const created = await client.query<RequestRow>(`INSERT INTO entap_account_deletion_requests
      (request_id, player_id, subject_hash, receipt_hash) VALUES ($1, $2::uuid, $3, $4) RETURNING *`,
    [requestId, playerId, hash(playerId), receiptHash]);
    await client.query("UPDATE rank_players SET account_status = 'deletion_pending' WHERE id = $1::uuid", [playerId]);
    await client.query("UPDATE entap_player_devices SET status = 'revoked' WHERE player_id = $1::uuid AND application_id = 'swarmfront'", [playerId]);
    await client.query(`UPDATE entap_player_sessions SET revoked_at = COALESCE(revoked_at, now()),
      revoke_reason = 'swarmfront_account_deletion' WHERE player_id = $1::uuid AND application_id = 'swarmfront'`, [playerId]);
    await client.query(`INSERT INTO entap_account_deletion_tasks (request_id, domain)
      SELECT $1, unnest($2::text[])`, [requestId, [...DELETION_DOMAINS]]);
    await client.query("DELETE FROM entap_account_deletion_challenges WHERE player_id = $1::uuid", [playerId]);
    return this.publicReceipt(created.rows[0]);
  }

  async status(requestId: string, receiptToken: string): Promise<Record<string, unknown>> {
    this.validateReceipt(requestId, receiptToken);
    const result = await this.pool.query<RequestRow>("SELECT * FROM entap_account_deletion_requests WHERE request_id = $1", [requestId]);
    if (!result.rows[0]) throw new IdentitySessionError("deletion_request_not_found", 404);
    this.checkReceipt(result.rows[0], receiptToken);
    const tasks = await this.pool.query<{ retention: Retention[] }>(
      "SELECT retention FROM entap_account_deletion_tasks WHERE request_id = $1 ORDER BY domain", [requestId]);
    return { ...this.publicReceipt(result.rows[0]), retained_information: tasks.rows.flatMap(row => row.retention) };
  }

  async pending(): Promise<unknown[]> {
    return (await this.pool.query(`SELECT r.request_id, r.player_id, r.requested_at, r.target_at,
      jsonb_agg(jsonb_build_object('domain', t.domain, 'completed_at', t.completed_at,
        'evidence_ref', t.evidence_ref, 'retention', t.retention) ORDER BY t.domain) AS tasks
      FROM entap_account_deletion_requests r JOIN entap_account_deletion_tasks t USING (request_id)
      WHERE r.status = 'pending' GROUP BY r.request_id ORDER BY r.requested_at`)).rows;
  }

  // This is a fulfillment record, never a substitute for performing the deletion.
  // Only an operator with the dedicated deletion credential can record external evidence.
  async recordFulfillment(requestId: string, domain: string, evidenceRef: string, retention: Retention[]): Promise<void> {
    if (!DELETION_DOMAINS.includes(domain as typeof DELETION_DOMAINS[number]) || domain === "identity"
      || !/^[A-Za-z0-9][A-Za-z0-9._:/-]{7,255}$/.test(evidenceRef)
      || !Array.isArray(retention) || retention.length > 20 || retention.some(item =>
        !item || typeof item.category !== "string" || !item.category.trim() || item.category.length > 120
        || typeof item.reason !== "string" || item.reason.trim().length < 8 || item.reason.length > 500
        || typeof item.expires_at !== "string" || !Number.isFinite(Date.parse(item.expires_at))
        || Date.parse(item.expires_at) <= Date.now())) {
      throw new IdentitySessionError("invalid_fulfillment_evidence");
    }
    const result = await this.pool.query(`UPDATE entap_account_deletion_tasks t
      SET completed_at = now(), evidence_ref = $3, retention = $4::jsonb
      FROM entap_account_deletion_requests r WHERE t.request_id = $1 AND t.domain = $2
        AND r.request_id = t.request_id AND r.status = 'pending'`,
    [requestId, domain, evidenceRef, JSON.stringify(retention)]);
    if (!result.rowCount) throw new IdentitySessionError("pending_deletion_task_not_found", 404);
  }

  async complete(requestId: string): Promise<Record<string, unknown>> {
    return this.transaction(async client => {
      await client.query("SELECT pg_advisory_xact_lock($1)", [934_771_112]);
      const request = (await client.query<RequestRow>(
        "SELECT * FROM entap_account_deletion_requests WHERE request_id = $1 FOR UPDATE", [requestId])).rows[0];
      if (!request) throw new IdentitySessionError("deletion_request_not_found", 404);
      if (request.status === "completed") return this.publicReceipt(request);
      const missing = await client.query(`SELECT domain FROM entap_account_deletion_tasks
        WHERE request_id = $1 AND domain <> 'identity' AND completed_at IS NULL`, [requestId]);
      if (missing.rowCount) throw new IdentitySessionError("deletion_fulfillment_incomplete", 409);
      const playerId = request.player_id!;
      const financialReferences = await client.query(`SELECT 1 FROM platform_economy_accounts
        WHERE owner_id = $1 UNION ALL SELECT 1 FROM platform_journal_transactions
        WHERE strpos(metadata::text, $1) > 0 OR strpos(external_ref, $1) > 0
        UNION ALL SELECT 1 FROM platform_event_receipts
        WHERE strpos(COALESCE(response_json::text, ''), $1) > 0 OR strpos(producer_event_id, $1) > 0 LIMIT 1`, [playerId]);
      if (financialReferences.rowCount) throw new IdentitySessionError("retained_records_require_review", 409);
      // Immutable financial references intentionally fail closed. An operator must resolve
      // their deletion/retention first; we never disable financial-integrity triggers.
      await client.query("DELETE FROM platform_honey_activity_history WHERE player_id = $1::uuid", [playerId]);
      await client.query("DELETE FROM platform_nectar_award_history WHERE player_id = $1::uuid", [playerId]);
      await client.query("DELETE FROM platform_nectar_progression WHERE player_id = $1::uuid", [playerId]);
      await client.query("UPDATE rank_players SET friends = friends - $1 WHERE friends ? $1", [playerId]);
      await client.query(`DELETE FROM rank_audit_events WHERE application_id = 'swarmfront' AND (player_id = $1 OR related_player_id = $1
        OR strpos(payload::text, $1) > 0)`, [playerId]);
      await client.query("DELETE FROM rank_processed_events WHERE strpos(dedupe_key, $1) > 0", [playerId]);
      await client.query("DELETE FROM rank_meta WHERE strpos(value::text, $1) > 0", [playerId]);
      // Application-bound credentials only. ENTaP identity, credentials, sessions and
      // app-owned audit evidence survive; deleting a game is not deleting ENTaP.
      await client.query("DELETE FROM entap_player_sessions WHERE player_id = $1::uuid AND application_id = 'swarmfront'", [playerId]);
      await client.query("DELETE FROM entap_player_devices WHERE player_id = $1::uuid AND application_id = 'swarmfront'", [playerId]);
      await client.query("DELETE FROM rank_players WHERE id = $1::uuid", [playerId]);
      await client.query(`UPDATE entap_account_deletion_tasks SET completed_at = now(),
        evidence_ref = 'identity:transactional-purge-v1' WHERE request_id = $1 AND domain = 'identity'`, [requestId]);
      const completed = await client.query<RequestRow>(`UPDATE entap_account_deletion_requests
        SET status = 'completed', player_id = NULL, verification_evidence_ref = 'completed:verification-removed',
          completed_at = now() WHERE request_id = $1 RETURNING *`, [requestId]);
      return this.publicReceipt(completed.rows[0]);
    });
  }

  private validateReceipt(requestId: string, token: string): void {
    if (!/^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/.test(requestId) || !/^[A-Za-z0-9_-]{43}$/.test(token)) {
      throw new IdentitySessionError("invalid_deletion_receipt");
    }
  }
  private checkReceipt(row: RequestRow, token: string): void {
    if (!crypto.timingSafeEqual(Buffer.from(row.receipt_hash, "hex"), Buffer.from(hash(token), "hex"))) {
      throw new IdentitySessionError("deletion_request_not_found", 404);
    }
  }
  private publicReceipt(row: RequestRow): Record<string, unknown> {
    return { application_id: DELETION_APPLICATION, request_id: row.request_id, status: row.status, requested_at: row.requested_at,
      target_at: row.target_at, completed_at: row.completed_at };
  }
  private async transaction<T>(operation: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const value = await operation(client);
      await client.query("COMMIT");
      return value;
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      if ((error as { code?: string }).code === "23503") {
        throw new IdentitySessionError("retained_records_require_review", 409);
      }
      throw error;
    } finally { client.release(); }
  }
}
