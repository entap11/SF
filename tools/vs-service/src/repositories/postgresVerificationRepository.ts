import type { Pool, PoolClient } from "pg";
import {
  deepClone,
  DurableCoreError,
  sha256Canonical,
  uuidV7,
  type DurableCoreRepository,
  type JsonRecord,
  type TerminalResult
} from "./durableCore.js";
import { readContract } from "./postgresDurableCoreRepository.js";
import {
  clientReportHash,
  terminalInputFromVerified,
  validateClientReport,
  verificationInputHash,
  verifySignedSyncResult,
  type ClientTerminalReport,
  type ClientTerminalReportInput,
  type CompleteVerificationInput,
  type SignedSyncResult,
  type VerificationBundle,
  type VerificationRepository,
  type VerificationStatusView,
  type VerifierVerificationConfig
} from "./verificationAuthority.js";

type Row = Record<string, unknown>;
type Executor = Pick<Pool, "query"> | Pick<PoolClient, "query">;

export class PostgresVerificationRepository implements VerificationRepository {
  constructor(private readonly pool: Pool, private readonly core: DurableCoreRepository) {}

  async submitClientReport(input: ClientTerminalReportInput): Promise<{ report: ClientTerminalReport; status: VerificationStatusView }> {
    validateClientReport(input);
    const requestHash = clientReportHash(input);
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const membership = await client.query<Row>(
        `SELECT c.*, r.player_id FROM vs_match_contracts c
         JOIN vs_match_roster r ON r.contract_id = c.contract_id
         WHERE c.match_id = $1 AND r.player_id = $2 FOR UPDATE`,
        [input.matchId, input.playerId]
      );
      const contractRow = membership.rows[0];
      if (!contractRow) throw new DurableCoreError("player_not_in_match");
      if (!["STANDARD_1V1", "CTF_1V1"].includes(String(contractRow.mode_id))
        || Number(contractRow.required_players) !== 2) {
        throw new DurableCoreError("verification_contract_unsupported");
      }
      if (String(contractRow.authority_tier) !== "AUTHORITY_VERIFIED") {
        throw new DurableCoreError("authority_tier_not_verifiable");
      }
      const epoch = Number(contractRow.match_epoch);
      const existing = await client.query<Row>(
        `SELECT * FROM vs_match_client_terminal_reports
         WHERE match_id = $1 AND match_epoch = $2 AND player_id = $3 FOR UPDATE`,
        [input.matchId, epoch, input.playerId]
      );
      let report: ClientTerminalReport;
      if (existing.rows[0]) {
        report = reportFromRow(existing.rows[0], true);
        if (report.requestId !== input.requestId || report.requestHash !== requestHash) {
          throw new DurableCoreError("idempotency_conflict");
        }
      } else {
        if (!["RUNNING", "RECONNECTING"].includes(String(contractRow.status))) {
          throw new DurableCoreError("match_not_running");
        }
        const inserted = await client.query<Row>(
          `INSERT INTO vs_match_client_terminal_reports
            (report_id, match_id, contract_id, match_epoch, player_id, request_id, request_hash,
             final_state_hash, elapsed_sim_ticks, claimed_terminal_reason, claimed_winner_player_id,
             report_json, submitted_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12::jsonb, $13)
           RETURNING *`,
          [uuidV7(), input.matchId, contractRow.contract_id, epoch, input.playerId, input.requestId,
            requestHash, input.finalStateHash, input.elapsedSimTicks, input.claimedTerminalReason,
            input.claimedWinnerPlayerId, JSON.stringify(input.diagnostics), input.submittedAt]
        );
        report = reportFromRow(inserted.rows[0], false);
      }
      const reportCount = await client.query<{ count: number }>(
        `SELECT count(*)::int AS count FROM vs_match_client_terminal_reports
         WHERE match_id = $1 AND match_epoch = $2`, [input.matchId, epoch]
      );
      if (Number(reportCount.rows[0]?.count ?? 0) === Number(contractRow.required_players)) {
        const contract = await readContract(client, String(contractRow.contract_id));
        if (!contract) throw new DurableCoreError("contract_missing");
        const commands = await this.core.readCommands(input.matchId, epoch, 0);
        const lifecycle = await readLifecycle(client, input.matchId, epoch);
        const inputHash = verificationInputHash(contract, commands.events, lifecycle);
        await client.query(
          `INSERT INTO vs_match_verification_jobs
            (job_id, result_id, match_id, contract_id, match_epoch, contract_hash, input_hash,
             status, authority_method, available_at, receipt_issued_at, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, 'PENDING', 'SIM_REPLAY', $8, $8, $8, $8)
           ON CONFLICT (match_id, match_epoch) DO NOTHING`,
          [uuidV7(), uuidV7(), input.matchId, contract.contractId, epoch, contract.contractHash, inputHash, input.submittedAt]
        );
        await client.query(
          `UPDATE vs_match_contracts SET status = 'VERIFYING', updated_at = $2
           WHERE contract_id = $1 AND status IN ('RUNNING', 'RECONNECTING')`,
          [contract.contractId, input.submittedAt]
        );
      }
      await client.query("COMMIT");
      return { report, status: await this.status(input.matchId, epoch) };
    } catch (error) {
      await rollbackQuietly(client);
      throw normalizePgError(error);
    } finally {
      client.release();
    }
  }

  async getPlayerStatus(matchId: string, playerId: string): Promise<VerificationStatusView> {
    const membership = await this.pool.query<Row>(
      `SELECT c.match_epoch FROM vs_match_contracts c JOIN vs_match_roster r ON r.contract_id = c.contract_id
       WHERE c.match_id = $1 AND r.player_id = $2`, [matchId, playerId]
    );
    if (!membership.rows[0]) throw new DurableCoreError("player_not_in_match");
    return this.status(matchId, Number(membership.rows[0].match_epoch));
  }

  async leaseNext(workerId: string, nowIso: string, leaseSec: number): Promise<VerificationBundle | null> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `UPDATE vs_match_verification_jobs SET status = 'RETRY', lease_owner = NULL, lease_token = NULL,
           lease_expires_at = NULL, available_at = $1, updated_at = $1
         WHERE status = 'LEASED' AND lease_expires_at <= $1`, [nowIso]
      );
      const found = await client.query<Row>(
        `SELECT * FROM vs_match_verification_jobs
         WHERE status IN ('PENDING', 'RETRY') AND available_at <= $1
         ORDER BY available_at, created_at, job_id LIMIT 1 FOR UPDATE SKIP LOCKED`, [nowIso]
      );
      if (!found.rows[0]) {
        await client.query("COMMIT");
        return null;
      }
      const leaseToken = uuidV7();
      const leaseExpiresAt = new Date(new Date(nowIso).getTime() + leaseSec * 1_000).toISOString();
      const updated = await client.query<Row>(
        `UPDATE vs_match_verification_jobs SET status = 'LEASED', attempt_count = attempt_count + 1,
           lease_owner = $2, lease_token = $3, lease_expires_at = $4, updated_at = $1
         WHERE job_id = $5 RETURNING *`, [nowIso, workerId, leaseToken, leaseExpiresAt, found.rows[0].job_id]
      );
      await client.query("COMMIT");
      return this.bundle(updated.rows[0]);
    } catch (error) {
      await rollbackQuietly(client);
      throw normalizePgError(error);
    } finally {
      client.release();
    }
  }

  async complete(input: CompleteVerificationInput, config: VerifierVerificationConfig): Promise<VerificationStatusView> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const locked = await client.query<Row>(
        "SELECT * FROM vs_match_verification_jobs WHERE job_id = $1 FOR UPDATE", [input.jobId]
      );
      const job = locked.rows[0];
      if (!job) throw new DurableCoreError("verification_job_not_found");
      const completionHash = sha256Canonical(input.signedResult);
      if (["COMPLETED", "QUARANTINED"].includes(String(job.status))) {
        if (String(job.completion_hash) !== completionHash) throw new DurableCoreError("idempotency_conflict");
        await client.query("COMMIT");
        return this.status(String(job.match_id), Number(job.match_epoch));
      }
      requireLease(job, input.workerId, input.leaseToken);
      const bundle = await this.bundle(job);
      const payload = verifySignedSyncResult(input.signedResult, bundle, config);
      const terminal = terminalInputFromVerified(payload);
      const payloadHash = sha256Canonical(payload);
      await client.query(
        `INSERT INTO vs_match_verification_runs
          (run_id, job_id, attempt, worker_id, worker_build_id, input_hash, output_hash,
           final_state_hash, status, run_json, started_at, finished_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'COMPLETED', $9::jsonb, $10, $11)`,
        [uuidV7(), job.job_id, job.attempt_count, input.workerId, config.workerBuildId, job.input_hash,
          payloadHash, payload.final_state_hash ?? null, JSON.stringify(input.runDiagnostics), input.startedAt, input.finishedAt]
      );
      const existing = await client.query<Row>(
        "SELECT * FROM vs_terminal_results WHERE match_id = $1 AND match_epoch = $2 FOR UPDATE",
        [terminal.matchId, terminal.matchEpoch]
      );
      if (existing.rows[0]) {
        if (String(existing.rows[0].result_id) !== terminal.resultId
          || String(existing.rows[0].payload_hash) !== payloadHash) throw new DurableCoreError("idempotency_conflict");
      } else {
        await client.query(
          `INSERT INTO vs_terminal_results
            (result_id, match_id, contract_id, match_epoch, result_schema_version, terminal_reason,
             contract_hash, final_command_seq, command_log_hash, payload_hash, result_json, verified_at)
           VALUES ($1, $2, $3, $4, 1, $5, $6, $7, $8, $9, $10::jsonb, $11)`,
          [terminal.resultId, terminal.matchId, terminal.contractId, terminal.matchEpoch, terminal.terminalReason,
            terminal.contractHash, terminal.finalCommandSeq, terminal.commandLogHash, payloadHash,
            JSON.stringify(payload), terminal.verifiedAt]
        );
      }
      await client.query(
        `INSERT INTO vs_verifier_signed_receipts
          (result_id, job_id, authority_method, worker_id, worker_build_id, sim_build_id,
           verifier_key_id, signature_algorithm, signed_payload_hash, signature, signed_payload, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'ES256', $8, $9, $10::jsonb, $11)
         ON CONFLICT (result_id) DO NOTHING`,
        [terminal.resultId, job.job_id, payload.authority_method, input.workerId, config.workerBuildId,
          payload.sim_build_id, input.signedResult.keyId, input.signedResult.payloadHash,
          input.signedResult.signature, JSON.stringify(payload), input.finishedAt]
      );
      const jobStatus = terminal.terminalReason === "NO_CONTEST" ? "QUARANTINED" : "COMPLETED";
      await client.query(
        `UPDATE vs_match_verification_jobs SET status = $2, completion_hash = $3, lease_owner = NULL,
           lease_token = NULL, lease_expires_at = NULL, updated_at = $4 WHERE job_id = $1`,
        [job.job_id, jobStatus, completionHash, input.finishedAt]
      );
      await client.query(
        "UPDATE vs_match_contracts SET status = 'TERMINAL', updated_at = $2 WHERE contract_id = $1",
        [job.contract_id, input.finishedAt]
      );
      await client.query("COMMIT");
      return this.status(terminal.matchId, terminal.matchEpoch);
    } catch (error) {
      await rollbackQuietly(client);
      throw normalizePgError(error);
    } finally {
      client.release();
    }
  }

  async fail(input: {
    workerId: string; leaseToken: string; jobId: string; startedAt: string; finishedAt: string;
    retryable: boolean; errorCode: string; diagnostics: JsonRecord; retryDelaySec: number;
  }): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const locked = await client.query<Row>(
        "SELECT * FROM vs_match_verification_jobs WHERE job_id = $1 FOR UPDATE", [input.jobId]
      );
      const job = locked.rows[0];
      if (!job) throw new DurableCoreError("verification_job_not_found");
      requireLease(job, input.workerId, input.leaseToken);
      const retry = input.retryable && Number(job.attempt_count) < Number(job.max_attempts);
      await client.query(
        `INSERT INTO vs_match_verification_runs
          (run_id, job_id, attempt, worker_id, worker_build_id, input_hash, status, error_code,
           run_json, started_at, finished_at)
         VALUES ($1, $2, $3, $4, 'unknown', $5, $6, $7, $8::jsonb, $9, $10)`,
        [uuidV7(), job.job_id, job.attempt_count, input.workerId, job.input_hash,
          retry ? "RETRYABLE_FAILURE" : "PERMANENT_FAILURE", input.errorCode,
          JSON.stringify(input.diagnostics), input.startedAt, input.finishedAt]
      );
      const availableAt = new Date(new Date(input.finishedAt).getTime() + input.retryDelaySec * 1_000).toISOString();
      await client.query(
        `UPDATE vs_match_verification_jobs SET status = $2, available_at = $3, lease_owner = NULL,
           lease_token = NULL, lease_expires_at = NULL, last_error_code = $4,
           last_error_detail = $5::jsonb, updated_at = $6 WHERE job_id = $1`,
        [job.job_id, retry ? "RETRY" : "FAILED", availableAt, input.errorCode,
          JSON.stringify(input.diagnostics), input.finishedAt]
      );
      await client.query("COMMIT");
    } catch (error) {
      await rollbackQuietly(client);
      throw normalizePgError(error);
    } finally {
      client.release();
    }
  }

  async expireReconnectGrace(nowIso: string, limit: number): Promise<number> {
    let expired = 0;
    for (let index = 0; index < Math.max(1, Math.min(100, limit)); index += 1) {
      const client = await this.pool.connect();
      try {
        await client.query("BEGIN");
        const found = await client.query<Row>(
          `SELECT c.contract_id, c.match_id, c.match_epoch, c.contract_hash,
              rs.player_id AS loser_player_id, rs.grace_deadline_at,
              (SELECT r2.player_id FROM vs_match_roster r2
               WHERE r2.contract_id = c.contract_id AND r2.player_id <> rs.player_id
               ORDER BY r2.seat_id LIMIT 1) AS winner_player_id
           FROM vs_match_contracts c
           JOIN vs_match_reconnect_state rs ON rs.match_id = c.match_id AND rs.match_epoch = c.match_epoch
           WHERE c.status = 'RECONNECTING' AND c.mode_id IN ('STANDARD_1V1', 'CTF_1V1')
             AND c.authority_tier = 'AUTHORITY_VERIFIED' AND rs.connection_state = 'GRACE'
             AND rs.grace_deadline_at <= $1
           ORDER BY rs.grace_deadline_at, c.match_id LIMIT 1
           FOR UPDATE OF c, rs SKIP LOCKED`, [nowIso]
        );
        const row = found.rows[0];
        if (!row) { await client.query("COMMIT"); break; }
        const contract = await readContract(client, String(row.contract_id));
        if (!contract || !row.winner_player_id) throw new DurableCoreError("forfeit_contract_invalid");
        const graceRows = await client.query<Row>(
          `SELECT player_id, grace_deadline_at FROM vs_match_reconnect_state
           WHERE match_id = $1 AND match_epoch = $2 AND connection_state = 'GRACE'
           ORDER BY player_id FOR UPDATE`, [contract.matchId, contract.matchEpoch]
        );
        const expiredPlayers = graceRows.rows.filter((entry) => entry.grace_deadline_at != null
          && new Date(String(entry.grace_deadline_at)).getTime() <= new Date(nowIso).getTime());
        const simultaneousExpiry = expiredPlayers.length >= contract.requiredPlayers;
        const commandPage = await this.core.readCommands(contract.matchId, contract.matchEpoch, 0);
        const elapsedTicks = commandPage.events.length > 0
          ? Math.max(...commandPage.events.map((entry) => entry.executeTick)) : 0;
        const eventId = uuidV7();
        await client.query(
          `INSERT INTO vs_match_lifecycle_events
            (event_id, match_id, match_epoch, event_type, event_payload, occurred_at)
           VALUES ($1, $2, $3, $4, $5::jsonb, $6)`,
          [eventId, contract.matchId, contract.matchEpoch,
            simultaneousExpiry ? "MATCH_NO_CONTEST" : "MATCH_FORFEITED",
            JSON.stringify(simultaneousExpiry ? {
              no_contest_reason: "ALL_PLAYERS_GRACE_EXPIRED", elapsed_sim_ticks: elapsedTicks,
              expired_player_ids: expiredPlayers.map((entry) => String(entry.player_id))
            } : {
              winner_player_id: String(row.winner_player_id), loser_player_id: String(row.loser_player_id),
              forfeit_kind: "DISCONNECT", elapsed_sim_ticks: elapsedTicks,
              grace_deadline_at: iso(row.grace_deadline_at)
            }), nowIso]
        );
        const lifecycle = await readLifecycle(client, contract.matchId, contract.matchEpoch);
        await client.query(
          `INSERT INTO vs_match_verification_jobs
            (job_id, result_id, match_id, contract_id, match_epoch, contract_hash, input_hash,
             status, authority_method, available_at, receipt_issued_at, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, 'PENDING', 'SERVER_LIFECYCLE', $8, $8, $8, $8)
           ON CONFLICT (match_id, match_epoch) DO NOTHING`,
          [uuidV7(), uuidV7(), contract.matchId, contract.contractId, contract.matchEpoch,
            contract.contractHash, verificationInputHash(contract, commandPage.events, lifecycle), nowIso]
        );
        const disconnectedPlayerIds = simultaneousExpiry
          ? expiredPlayers.map((entry) => String(entry.player_id)) : [String(row.loser_player_id)];
        for (const playerId of disconnectedPlayerIds) {
          await client.query(
            `UPDATE vs_match_reconnect_state SET connection_state = 'DISCONNECTED', grace_deadline_at = NULL,
               updated_at = $2 WHERE match_id = $1 AND player_id = $3`, [contract.matchId, nowIso, playerId]
          );
          await client.query(
            "UPDATE vs_match_roster SET connection_state = 'DISCONNECTED' WHERE contract_id = $1 AND player_id = $2",
            [contract.contractId, playerId]
          );
        }
        await client.query(
          "UPDATE vs_match_contracts SET status = 'VERIFYING', updated_at = $2 WHERE contract_id = $1",
          [contract.contractId, nowIso]
        );
        await client.query("COMMIT");
        expired += 1;
      } catch (error) {
        await rollbackQuietly(client);
        throw normalizePgError(error);
      } finally { client.release(); }
    }
    return expired;
  }

  private async bundle(job: Row): Promise<VerificationBundle> {
    const contract = await this.core.getContractById(String(job.contract_id));
    if (!contract) throw new DurableCoreError("contract_missing");
    const commandPage = await this.core.readCommands(contract.matchId, contract.matchEpoch, 0);
    const lifecycleEvents = await readLifecycle(this.pool, contract.matchId, contract.matchEpoch);
    const reports = await this.pool.query<Row>(
      `SELECT * FROM vs_match_client_terminal_reports WHERE match_id = $1 AND match_epoch = $2
       ORDER BY player_id`, [contract.matchId, contract.matchEpoch]
    );
    const calculatedInputHash = verificationInputHash(contract, commandPage.events, lifecycleEvents);
    if (String(job.input_hash) !== calculatedInputHash) throw new DurableCoreError("verification_input_changed");
    return {
      jobId: String(job.job_id), resultId: String(job.result_id), leaseToken: String(job.lease_token ?? ""),
      attempt: Number(job.attempt_count), receiptIssuedAt: iso(job.receipt_issued_at),
      inputHash: String(job.input_hash), authorityMethod: String(job.authority_method) as VerificationBundle["authorityMethod"],
      contract, commands: commandPage.events, lifecycleEvents,
      clientReports: reports.rows.map((row) => reportFromRow(row, false)),
      finalCommandSeq: commandPage.highWaterSeq,
      commandLogHash: sha256Canonical(commandPage.events.map((entry) => entry.command))
    };
  }

  private async status(matchId: string, epoch: number): Promise<VerificationStatusView> {
    const [reports, jobs, result] = await Promise.all([
      this.pool.query<{ count: number }>(
        "SELECT count(*)::int AS count FROM vs_match_client_terminal_reports WHERE match_id = $1 AND match_epoch = $2",
        [matchId, epoch]
      ),
      this.pool.query<Row>("SELECT * FROM vs_match_verification_jobs WHERE match_id = $1 AND match_epoch = $2", [matchId, epoch]),
      this.core.getTerminalResult(matchId, epoch)
    ]);
    let signedReceipt: SignedSyncResult | null = null;
    if (result) {
      const signed = await this.pool.query<Row>("SELECT * FROM vs_verifier_signed_receipts WHERE result_id = $1", [result.resultId]);
      if (signed.rows[0]) signedReceipt = signedFromRow(signed.rows[0]);
    }
    return {
      matchId, matchEpoch: epoch,
      status: jobs.rows[0] ? String(jobs.rows[0].status) as VerificationStatusView["status"] : "AWAITING_REPORTS",
      reportCount: Number(reports.rows[0]?.count ?? 0), requiredReportCount: 2,
      result, signedReceipt
    };
  }
}

async function readLifecycle(executor: Executor, matchId: string, epoch: number): Promise<JsonRecord[]> {
  const rows = await executor.query<Row>(
    `SELECT event_id, event_type, event_payload, occurred_at FROM vs_match_lifecycle_events
     WHERE match_id = $1 AND match_epoch = $2 ORDER BY occurred_at, event_id`, [matchId, epoch]
  );
  return rows.rows.map((row) => ({
    event_id: String(row.event_id), event_type: String(row.event_type),
    event_payload: jsonRecord(row.event_payload), occurred_at: iso(row.occurred_at)
  }));
}

function reportFromRow(row: Row, duplicate: boolean): ClientTerminalReport {
  return {
    reportId: String(row.report_id), matchId: String(row.match_id), contractId: String(row.contract_id),
    matchEpoch: Number(row.match_epoch), playerId: String(row.player_id), requestId: String(row.request_id),
    requestHash: String(row.request_hash), finalStateHash: String(row.final_state_hash),
    elapsedSimTicks: Number(row.elapsed_sim_ticks), claimedTerminalReason: String(row.claimed_terminal_reason),
    claimedWinnerPlayerId: row.claimed_winner_player_id == null ? null : String(row.claimed_winner_player_id),
    diagnostics: jsonRecord(row.report_json), submittedAt: iso(row.submitted_at), duplicate
  };
}

function signedFromRow(row: Row): SignedSyncResult {
  return {
    payload: jsonRecord(row.signed_payload), payloadHash: String(row.signed_payload_hash),
    keyId: String(row.verifier_key_id), algorithm: "ES256", signature: String(row.signature)
  };
}

function requireLease(job: Row, workerId: string, leaseToken: string): void {
  if (String(job.status) !== "LEASED" || String(job.lease_owner) !== workerId || String(job.lease_token) !== leaseToken) {
    throw new DurableCoreError("verification_lease_invalid");
  }
}

function jsonRecord(value: unknown): JsonRecord {
  if (typeof value === "string") value = JSON.parse(value) as unknown;
  if (typeof value !== "object" || value == null || Array.isArray(value)) throw new DurableCoreError("stored_json_invalid");
  return deepClone(value as JsonRecord);
}

function iso(value: unknown): string {
  const date = value instanceof Date ? value : new Date(String(value));
  if (!Number.isFinite(date.getTime())) throw new DurableCoreError("stored_timestamp_invalid");
  return date.toISOString();
}

async function rollbackQuietly(client: PoolClient): Promise<void> {
  try { await client.query("ROLLBACK"); } catch { /* preserve original error */ }
}

function normalizePgError(error: unknown): unknown {
  if (error instanceof DurableCoreError) return error;
  const code = typeof error === "object" && error != null && "code" in error
    ? String((error as { code?: unknown }).code) : "";
  if (code === "23505") return new DurableCoreError("idempotency_conflict");
  if (code === "23503") return new DurableCoreError("durable_reference_missing");
  if (code === "23514" || code === "22P02") return new DurableCoreError("durable_input_invalid");
  return error;
}
