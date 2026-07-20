import type { Pool, PoolClient, QueryResult } from "pg";
import {
  canonicalCommand,
  commandRequestHash,
  contractRequestHash,
  deepClone,
  DurableCoreError,
  materializeContract,
  outboxRequestHash,
  sha256Canonical,
  uuidV7,
  validateTerminalResultInput,
  type AppendCommandInput,
  type CommandPage,
  type CommandReceipt,
  type CreateContractInput,
  type DurableContract,
  type DurableCoreRepository,
  type JsonRecord,
  type OutboxEvent,
  type OutboxEventInput,
  type ReconnectState,
  type RosterEntry,
  type TerminalResult,
  type TerminalResultInput
} from "./durableCore.js";

type Executor = Pick<Pool, "query"> | Pick<PoolClient, "query">;
type Row = Record<string, unknown>;

export class PostgresDurableCoreRepository implements DurableCoreRepository {
  constructor(private readonly pool: Pool) {}

  async createContract(input: CreateContractInput): Promise<{ contract: DurableContract; duplicate: boolean }> {
    const requestHash = contractRequestHash(input);
    const prepared = materializeContract(input);
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const claimed = await client.query(
        `INSERT INTO vs_idempotency_receipts
          (namespace, authoritative_subject, idempotency_key, request_hash, status)
         VALUES ('match.queue.v1', $1, $2, $3, 'PENDING')
         ON CONFLICT DO NOTHING
         RETURNING idempotency_key`,
        [input.idempotencySubject, input.requestId, requestHash]
      );
      if ((claimed.rowCount ?? 0) === 0) {
        const existing = await client.query<Row>(
          `SELECT request_hash, status, response_json
           FROM vs_idempotency_receipts
           WHERE namespace = 'match.queue.v1' AND authoritative_subject = $1 AND idempotency_key = $2
           FOR UPDATE`,
          [input.idempotencySubject, input.requestId]
        );
        const receipt = existing.rows[0];
        if (!receipt || String(receipt.request_hash) !== requestHash) throw new DurableCoreError("idempotency_conflict");
        if (receipt.status !== "COMPLETED") throw new DurableCoreError("idempotency_in_progress");
        const response = jsonRecord(receipt.response_json);
        const contract = await readContract(client, String(response.contract_id ?? ""));
        if (!contract) throw new DurableCoreError("idempotency_receipt_corrupt");
        await client.query("COMMIT");
        return { contract, duplicate: true };
      }

      await insertContract(client, prepared);
      await client.query(
        `INSERT INTO vs_command_streams (match_id, match_epoch, next_seq, last_execute_tick)
         VALUES ($1, $2, 1, -1)`,
        [prepared.matchId, prepared.matchEpoch]
      );
      await client.query(
        `INSERT INTO vs_match_lifecycle_events
          (event_id, match_id, match_epoch, event_type, event_payload, occurred_at)
         VALUES ($1, $2, $3, 'CONTRACT_CREATED', $4::jsonb, $5)`,
        [uuidV7(), prepared.matchId, prepared.matchEpoch,
          JSON.stringify({ contract_id: prepared.contractId, contract_hash: prepared.contractHash }), prepared.createdAt]
      );
      await client.query(
        `UPDATE vs_idempotency_receipts
         SET status = 'COMPLETED', response_json = $4::jsonb, side_effect_ref = $5, updated_at = now()
         WHERE namespace = 'match.queue.v1' AND authoritative_subject = $1 AND idempotency_key = $2 AND request_hash = $3`,
        [input.idempotencySubject, input.requestId, requestHash,
          JSON.stringify({ contract_id: prepared.contractId, match_id: prepared.matchId }), prepared.contractId]
      );
      await client.query("COMMIT");
      return { contract: prepared, duplicate: false };
    } catch (error) {
      await rollbackQuietly(client);
      throw translatePgError(error);
    } finally {
      client.release();
    }
  }

  async getContractById(contractId: string): Promise<DurableContract | null> {
    return readContract(this.pool, contractId);
  }

  async getContractByMatchId(matchId: string): Promise<DurableContract | null> {
    const found = await this.pool.query<{ contract_id: string }>(
      "SELECT contract_id FROM vs_match_contracts WHERE match_id = $1", [matchId]
    );
    return found.rows[0] ? readContract(this.pool, found.rows[0].contract_id) : null;
  }

  async listRecoverableContracts(nowIso: string): Promise<DurableContract[]> {
    const rows = await this.pool.query<{ contract_id: string }>(
      `SELECT contract_id FROM vs_match_contracts
       WHERE status IN ('FROZEN', 'RUNNING', 'RECONNECTING', 'VERIFYING') AND expires_at >= $1
       ORDER BY created_at, contract_id`,
      [nowIso]
    );
    const contracts = await Promise.all(rows.rows.map((row) => readContract(this.pool, row.contract_id)));
    return contracts.filter((contract): contract is DurableContract => contract != null);
  }

  async updateContractStatus(contractId: string, status: DurableContract["status"], updatedAt: string): Promise<DurableContract> {
    const updated = await this.pool.query<Row>(
      "UPDATE vs_match_contracts SET status = $2, updated_at = $3 WHERE contract_id = $1 RETURNING contract_id",
      [contractId, status, updatedAt]
    );
    if (!updated.rows[0]) throw new DurableCoreError("contract_missing");
    const contract = await readContract(this.pool, contractId);
    if (!contract) throw new DurableCoreError("contract_missing");
    return contract;
  }

  async setReconnectState(input: ReconnectState): Promise<ReconnectState> {
    if (input.connectionState === "GRACE" && !input.graceDeadlineAt) {
      throw new DurableCoreError("reconnect_grace_deadline_required");
    }
    const membership = await this.pool.query(
      `SELECT 1
       FROM vs_match_contracts c
       JOIN vs_match_roster r ON r.contract_id = c.contract_id
       WHERE c.match_id = $1 AND c.match_epoch = $2 AND r.player_id = $3`,
      [input.matchId, input.matchEpoch, input.playerId]
    );
    if ((membership.rowCount ?? 0) === 0) throw new DurableCoreError("reconnect_player_not_in_match");
    const saved = await this.pool.query<Row>(
      `INSERT INTO vs_match_reconnect_state
        (match_id, player_id, match_epoch, reconnect_epoch, connection_state, grace_deadline_at, last_seen_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (match_id, player_id) DO UPDATE SET
         match_epoch = EXCLUDED.match_epoch,
         reconnect_epoch = EXCLUDED.reconnect_epoch,
         connection_state = EXCLUDED.connection_state,
         grace_deadline_at = EXCLUDED.grace_deadline_at,
         last_seen_at = EXCLUDED.last_seen_at,
         updated_at = now()
       RETURNING *`,
      [input.matchId, input.playerId, input.matchEpoch, input.reconnectEpoch,
        input.connectionState, input.graceDeadlineAt, input.lastSeenAt]
    );
    return reconnectFromRow(saved.rows[0]);
  }

  async getReconnectStates(matchId: string): Promise<ReconnectState[]> {
    const rows = await this.pool.query<Row>(
      "SELECT * FROM vs_match_reconnect_state WHERE match_id = $1 ORDER BY player_id", [matchId]
    );
    return rows.rows.map(reconnectFromRow);
  }

  async appendCommand(input: AppendCommandInput): Promise<CommandReceipt> {
    validateCommandNumbers(input);
    const requestHash = commandRequestHash(input);
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const membership = await client.query<Row>(
        `SELECT c.contract_id, c.status, r.seat_id
         FROM vs_match_contracts c
         JOIN vs_match_roster r ON r.contract_id = c.contract_id
         WHERE c.match_id = $1 AND c.match_epoch = $2 AND r.player_id = $3
         FOR UPDATE`,
        [input.matchId, input.matchEpoch, input.playerId]
      );
      const member = membership.rows[0];
      if (!member) throw new DurableCoreError("command_contract_unavailable");
      if (Number(member.seat_id) !== input.seatId) throw new DurableCoreError("command_sender_mismatch");

      const existing = await client.query<Row>(
        `SELECT * FROM vs_command_events
         WHERE match_id = $1 AND match_epoch = $2 AND client_command_id = $3
         FOR UPDATE`,
        [input.matchId, input.matchEpoch, input.clientCommandId]
      );
      if (existing.rows[0]) {
        if (String(existing.rows[0].request_hash) !== requestHash) throw new DurableCoreError("idempotency_conflict");
        await client.query("COMMIT");
        return commandFromRow(existing.rows[0], true);
      }
      if (!["RUNNING", "RECONNECTING"].includes(String(member.status))) {
        throw new DurableCoreError("match_not_running");
      }

      const streamResult = await client.query<Row>(
        `SELECT next_seq, last_execute_tick FROM vs_command_streams
         WHERE match_id = $1 AND match_epoch = $2 FOR UPDATE`,
        [input.matchId, input.matchEpoch]
      );
      const stream = streamResult.rows[0];
      if (!stream) throw new DurableCoreError("command_stream_missing");
      const commandSeq = Number(stream.next_seq);
      const executeTick = Math.max(input.requestedExecuteTick, input.issuedTick + 3, Number(stream.last_execute_tick) + 1);
      const command = canonicalCommand(input, commandSeq, executeTick);
      const commandHash = sha256Canonical(command);
      const inserted = await client.query<Row>(
        `INSERT INTO vs_command_events
          (match_id, match_epoch, command_seq, contract_id, player_id, seat_id, client_command_id,
           command_schema_version, issued_tick, requested_execute_tick, execute_tick, request_hash,
           command_hash, command_payload, received_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 1, $8, $9, $10, $11, $12, $13::jsonb, $14)
         RETURNING *`,
        [input.matchId, input.matchEpoch, commandSeq, member.contract_id, input.playerId, input.seatId,
          input.clientCommandId, input.issuedTick, input.requestedExecuteTick, executeTick, requestHash,
          commandHash, JSON.stringify(command), input.receivedAt]
      );
      await client.query(
        `UPDATE vs_command_streams
         SET next_seq = $3, last_execute_tick = $4, updated_at = now()
         WHERE match_id = $1 AND match_epoch = $2`,
        [input.matchId, input.matchEpoch, commandSeq + 1, executeTick]
      );
      await client.query("COMMIT");
      return commandFromRow(inserted.rows[0], false);
    } catch (error) {
      await rollbackQuietly(client);
      throw translatePgError(error);
    } finally {
      client.release();
    }
  }

  async readCommands(matchId: string, matchEpoch: number, afterSeq: number): Promise<CommandPage> {
    const stream = await this.pool.query<Row>(
      "SELECT next_seq FROM vs_command_streams WHERE match_id = $1 AND match_epoch = $2",
      [matchId, matchEpoch]
    );
    if (!stream.rows[0]) throw new DurableCoreError("command_stream_missing");
    const highWaterSeq = Number(stream.rows[0].next_seq) - 1;
    const rows = await this.pool.query<Row>(
      `SELECT * FROM vs_command_events
       WHERE match_id = $1 AND match_epoch = $2 ORDER BY command_seq`,
      [matchId, matchEpoch]
    );
    if (rows.rows.length !== highWaterSeq
      || rows.rows.some((row, index) => Number(row.command_seq) !== index + 1)) {
      throw new DurableCoreError("command_stream_gap");
    }
    return {
      afterSeq,
      highWaterSeq,
      events: rows.rows.filter((row) => Number(row.command_seq) > afterSeq).map((row) => commandFromRow(row, false))
    };
  }

  async saveTerminalResult(input: TerminalResultInput): Promise<TerminalResult> {
    validateTerminalResultInput(input);
    const payloadHash = sha256Canonical(input.result);
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const contractResult = await client.query<Row>(
        `SELECT contract_id, contract_hash, match_epoch
         FROM vs_match_contracts WHERE match_id = $1 FOR UPDATE`, [input.matchId]
      );
      const contract = contractResult.rows[0];
      if (!contract || String(contract.contract_id) !== input.contractId
        || Number(contract.match_epoch) !== input.matchEpoch || String(contract.contract_hash) !== input.contractHash) {
        throw new DurableCoreError("result_contract_mismatch");
      }
      const stream = await client.query<Row>(
        "SELECT next_seq FROM vs_command_streams WHERE match_id = $1 AND match_epoch = $2 FOR UPDATE",
        [input.matchId, input.matchEpoch]
      );
      if (!stream.rows[0] || input.finalCommandSeq !== Number(stream.rows[0].next_seq) - 1) {
        throw new DurableCoreError("result_command_high_water_mismatch");
      }
      const commandRows = await client.query<Row>(
        `SELECT command_payload FROM vs_command_events
         WHERE match_id = $1 AND match_epoch = $2 ORDER BY command_seq`,
        [input.matchId, input.matchEpoch]
      );
      if (input.commandLogHash !== sha256Canonical(commandRows.rows.map((row) => jsonRecord(row.command_payload)))) {
        throw new DurableCoreError("result_command_log_hash_mismatch");
      }
      const existing = await client.query<Row>(
        "SELECT * FROM vs_terminal_results WHERE match_id = $1 AND match_epoch = $2 FOR UPDATE",
        [input.matchId, input.matchEpoch]
      );
      if (existing.rows[0]) {
        if (String(existing.rows[0].result_id) !== input.resultId
          || String(existing.rows[0].payload_hash) !== payloadHash) {
          throw new DurableCoreError("idempotency_conflict");
        }
        await client.query("COMMIT");
        return terminalFromRow(existing.rows[0], true);
      }
      const inserted = await client.query<Row>(
        `INSERT INTO vs_terminal_results
          (result_id, match_id, contract_id, match_epoch, result_schema_version, terminal_reason,
           contract_hash, final_command_seq, command_log_hash, payload_hash, result_json, verified_at)
         VALUES ($1, $2, $3, $4, 1, $5, $6, $7, $8, $9, $10::jsonb, $11)
         RETURNING *`,
        [input.resultId, input.matchId, input.contractId, input.matchEpoch, input.terminalReason,
          input.contractHash, input.finalCommandSeq, input.commandLogHash, payloadHash,
          JSON.stringify(input.result), input.verifiedAt]
      );
      await client.query(
        "UPDATE vs_match_contracts SET status = 'TERMINAL', updated_at = now() WHERE contract_id = $1",
        [input.contractId]
      );
      await client.query("COMMIT");
      return terminalFromRow(inserted.rows[0], false);
    } catch (error) {
      await rollbackQuietly(client);
      throw translatePgError(error);
    } finally {
      client.release();
    }
  }

  async getTerminalResult(matchId: string, matchEpoch: number): Promise<TerminalResult | null> {
    const result = await this.pool.query<Row>(
      "SELECT * FROM vs_terminal_results WHERE match_id = $1 AND match_epoch = $2",
      [matchId, matchEpoch]
    );
    return result.rows[0] ? terminalFromRow(result.rows[0], false) : null;
  }

  async enqueueOutbox(input: OutboxEventInput): Promise<OutboxEvent> {
    const eventId = uuidV7();
    const requestHash = outboxRequestHash(input);
    const inserted = await this.pool.query<Row>(
      `INSERT INTO vs_outbox_events
        (event_id, topic, recipient_player_id, aggregate_type, aggregate_id,
         dedupe_namespace, dedupe_key, request_hash, payload, available_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10)
       ON CONFLICT (dedupe_namespace, dedupe_key) DO NOTHING
       RETURNING *`,
      [eventId, input.topic, input.recipientPlayerId ?? null, input.aggregateType, input.aggregateId,
        input.dedupeNamespace, input.dedupeKey, requestHash, JSON.stringify(input.payload), input.availableAt]
    );
    if (inserted.rows[0]) return outboxFromRow(inserted.rows[0], false);
    const existing = await this.pool.query<Row>(
      "SELECT * FROM vs_outbox_events WHERE dedupe_namespace = $1 AND dedupe_key = $2",
      [input.dedupeNamespace, input.dedupeKey]
    );
    const row = existing.rows[0];
    if (!row || String(row.request_hash) !== requestHash) {
      throw new DurableCoreError("idempotency_conflict");
    }
    return outboxFromRow(row, true);
  }

  async listPendingOutbox(recipientPlayerId: string, limit: number): Promise<OutboxEvent[]> {
    const rows = await this.pool.query<Row>(
      `SELECT * FROM vs_outbox_events
       WHERE recipient_player_id = $1 AND status = 'PENDING' AND available_at <= now()
       ORDER BY available_at, event_id LIMIT $2`,
      [recipientPlayerId, Math.max(1, Math.min(100, limit))]
    );
    return rows.rows.map((row) => outboxFromRow(row, false));
  }

  async acknowledgeOutbox(eventId: string, recipientPlayerId: string, deliveredAt: string): Promise<OutboxEvent> {
    const updated = await this.pool.query<Row>(
      `UPDATE vs_outbox_events
       SET status = 'DELIVERED', delivered_at = $3,
         delivery_attempts = CASE WHEN status = 'PENDING' THEN delivery_attempts + 1 ELSE delivery_attempts END
       WHERE event_id = $1 AND recipient_player_id = $2 AND status IN ('PENDING', 'DELIVERED')
       RETURNING *`,
      [eventId, recipientPlayerId, deliveredAt]
    );
    if (!updated.rows[0]) throw new DurableCoreError("outbox_event_not_found");
    return outboxFromRow(updated.rows[0], false);
  }
}

export async function insertContract(client: PoolClient, contract: DurableContract): Promise<void> {
  await client.query(
    `INSERT INTO vs_match_contracts
      (contract_id, match_id, legacy_session_id, protocol_version, command_schema_version,
       result_schema_version, minimum_client_build, sim_build_id, mode_id, ruleset_id,
       ruleset_hash, map_id, map_hash, seed, authority_tier, match_epoch, required_players,
       status, contract_hash, contract_json, created_at, expires_at)
     VALUES ($1, $2, $3, 2, 1, 1, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13,
       $14, $15, $16, $17::jsonb, $18, $19)`,
    [contract.contractId, contract.matchId, contract.legacySessionId, contract.minimumClientBuild,
      contract.simBuildId, contract.modeId, contract.rulesetId, contract.rulesetHash, contract.mapId,
      contract.mapHash, contract.seed, contract.authorityTier, contract.matchEpoch, contract.requiredPlayers,
      contract.status, contract.contractHash, JSON.stringify(contract.contractJson), contract.createdAt, contract.expiresAt]
  );
  for (const entry of contract.roster) {
    await client.query(
      `INSERT INTO vs_match_roster
        (contract_id, player_id, public_entap_id, display_name, participant_type, bot_profile_id,
         seat_id, team_id, color_id, party_id, rank_value, ready_state, connection_state, joined_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
      [contract.contractId, entry.playerId, entry.publicEntapId ?? null, entry.displayName,
        entry.participantType, entry.botProfileId ?? null, entry.seatId, entry.teamId ?? null,
        entry.colorId, entry.partyId ?? null, entry.rankValue ?? null, entry.readyState,
        entry.connectionState, entry.joinedAt]
    );
  }
}

export async function readContract(executor: Executor, contractId: string): Promise<DurableContract | null> {
  if (!contractId) return null;
  const contractResult = await executor.query<Row>("SELECT * FROM vs_match_contracts WHERE contract_id = $1", [contractId]);
  const row = contractResult.rows[0];
  if (!row) return null;
  const rosterResult = await executor.query<Row>(
    "SELECT * FROM vs_match_roster WHERE contract_id = $1 ORDER BY seat_id", [contractId]
  );
  return {
    contractId: String(row.contract_id),
    matchId: String(row.match_id),
    legacySessionId: row.legacy_session_id == null ? null : String(row.legacy_session_id),
    protocolVersion: 2,
    commandSchemaVersion: 1,
    resultSchemaVersion: 1,
    minimumClientBuild: String(row.minimum_client_build),
    simBuildId: String(row.sim_build_id),
    modeId: String(row.mode_id),
    rulesetId: String(row.ruleset_id),
    rulesetHash: String(row.ruleset_hash),
    mapId: String(row.map_id),
    mapHash: String(row.map_hash),
    seed: String(row.seed),
    authorityTier: String(row.authority_tier) as DurableContract["authorityTier"],
    matchEpoch: Number(row.match_epoch),
    requiredPlayers: Number(row.required_players),
    status: String(row.status) as DurableContract["status"],
    contractHash: String(row.contract_hash),
    roster: rosterResult.rows.map(rosterFromRow),
    contractJson: jsonRecord(row.contract_json),
    createdAt: iso(row.created_at),
    expiresAt: iso(row.expires_at)
  };
}

function rosterFromRow(row: Row): RosterEntry {
  return {
    playerId: row.player_id == null ? null : String(row.player_id),
    publicEntapId: row.public_entap_id == null ? null : String(row.public_entap_id),
    displayName: String(row.display_name),
    participantType: String(row.participant_type) as RosterEntry["participantType"],
    botProfileId: row.bot_profile_id == null ? null : String(row.bot_profile_id),
    seatId: Number(row.seat_id),
    teamId: row.team_id == null ? null : Number(row.team_id),
    colorId: String(row.color_id),
    partyId: row.party_id == null ? null : String(row.party_id),
    rankValue: row.rank_value == null ? null : Number(row.rank_value),
    readyState: String(row.ready_state) as RosterEntry["readyState"],
    connectionState: String(row.connection_state) as RosterEntry["connectionState"],
    joinedAt: iso(row.joined_at)
  };
}

function reconnectFromRow(row: Row): ReconnectState {
  return {
    matchId: String(row.match_id),
    playerId: String(row.player_id),
    matchEpoch: Number(row.match_epoch),
    reconnectEpoch: Number(row.reconnect_epoch),
    connectionState: String(row.connection_state) as ReconnectState["connectionState"],
    graceDeadlineAt: row.grace_deadline_at == null ? null : iso(row.grace_deadline_at),
    lastSeenAt: iso(row.last_seen_at)
  };
}

function commandFromRow(row: Row, duplicate: boolean): CommandReceipt {
  return {
    matchId: String(row.match_id),
    matchEpoch: Number(row.match_epoch),
    commandSeq: Number(row.command_seq),
    contractId: String(row.contract_id),
    playerId: String(row.player_id),
    seatId: Number(row.seat_id),
    clientCommandId: String(row.client_command_id),
    issuedTick: Number(row.issued_tick),
    requestedExecuteTick: Number(row.requested_execute_tick),
    executeTick: Number(row.execute_tick),
    requestHash: String(row.request_hash),
    commandHash: String(row.command_hash),
    command: jsonRecord(row.command_payload),
    receivedAt: iso(row.received_at),
    committedAt: iso(row.committed_at),
    duplicate
  };
}

function terminalFromRow(row: Row, duplicate: boolean): TerminalResult {
  return {
    resultId: String(row.result_id),
    matchId: String(row.match_id),
    contractId: String(row.contract_id),
    matchEpoch: Number(row.match_epoch),
    terminalReason: String(row.terminal_reason),
    contractHash: String(row.contract_hash),
    finalCommandSeq: Number(row.final_command_seq),
    commandLogHash: String(row.command_log_hash),
    payloadHash: String(row.payload_hash),
    result: jsonRecord(row.result_json),
    verifiedAt: iso(row.verified_at),
    duplicate
  };
}

function outboxFromRow(row: Row, duplicate: boolean): OutboxEvent {
  return {
    eventId: String(row.event_id),
    topic: String(row.topic),
    recipientPlayerId: row.recipient_player_id == null ? null : String(row.recipient_player_id),
    aggregateType: String(row.aggregate_type),
    aggregateId: String(row.aggregate_id),
    dedupeNamespace: String(row.dedupe_namespace),
    dedupeKey: String(row.dedupe_key),
    payload: jsonRecord(row.payload),
    status: String(row.status) as OutboxEvent["status"],
    deliveryAttempts: Number(row.delivery_attempts),
    availableAt: iso(row.available_at),
    deliveredAt: row.delivered_at == null ? null : iso(row.delivered_at),
    createdAt: iso(row.created_at),
    duplicate
  };
}

function validateCommandNumbers(input: AppendCommandInput): void {
  if (!input.clientCommandId.trim() || !Number.isSafeInteger(input.issuedTick) || input.issuedTick < 0
    || !Number.isSafeInteger(input.requestedExecuteTick) || input.requestedExecuteTick < 0) {
    throw new DurableCoreError("invalid_command");
  }
}

function jsonRecord(value: unknown): JsonRecord {
  if (typeof value === "string") {
    try {
      value = JSON.parse(value) as unknown;
    } catch {
      throw new DurableCoreError("stored_json_invalid");
    }
  }
  if (typeof value !== "object" || value == null || Array.isArray(value)) {
    throw new DurableCoreError("stored_json_invalid");
  }
  return deepClone(value as JsonRecord);
}

function iso(value: unknown): string {
  const date = value instanceof Date ? value : new Date(String(value));
  if (!Number.isFinite(date.getTime())) throw new DurableCoreError("stored_timestamp_invalid");
  return date.toISOString();
}

async function rollbackQuietly(client: PoolClient): Promise<void> {
  try {
    await client.query("ROLLBACK");
  } catch {
    // Preserve the original transaction error.
  }
}

function translatePgError(error: unknown): unknown {
  if (error instanceof DurableCoreError) return error;
  const code = typeof error === "object" && error != null && "code" in error ? String((error as { code?: unknown }).code) : "";
  if (code === "23505") return new DurableCoreError("idempotency_conflict");
  if (code === "23503") return new DurableCoreError("durable_reference_missing");
  if (code === "23514" || code === "22P02") return new DurableCoreError("durable_input_invalid");
  return error;
}
