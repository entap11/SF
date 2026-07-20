import type { Pool, PoolClient } from "pg";
import {
  deepClone,
  DurableCoreError,
  materializeContract,
  isUuidV7,
  sha256Canonical,
  uuidV7,
  type AppendCommandInput,
  type CommandPage,
  type CommandReceipt,
  type DurableCoreRepository,
  type JsonRecord,
  type RosterEntry
} from "./durableCore.js";
import { insertContract, readContract } from "./postgresDurableCoreRepository.js";
import { assignMultiSeatRoster, requiredPlayersForPublicMode, type CompetitivePlayerSnapshot,
  type FriendEdge, type MultiSeatMode } from "./multiSeatAssignment.js";
import {
  publicQueueCompatibilityHash,
  publicQueueRequestHash,
  publicSessionView,
  validatePublic1v1Enqueue,
  type EnqueuePublic1v1Input,
  type CompetitiveIdentityInput,
  type LifecycleInput,
  type Public1v1Policy,
  type PublicBotFallbackInput,
  type PublicBotFallbackOffer,
  type Public1v1QueueResult,
  type Public1v1Repository,
  type Public1v1Ticket
} from "./public1v1.js";

type Row = Record<string, unknown>;
type ReceiptClaim = { duplicateResponse: JsonRecord | null; requestHash: string; subject: string };

export class PostgresPublic1v1Repository implements Public1v1Repository {
  constructor(private readonly pool: Pool, private readonly core: DurableCoreRepository) {}

  async enqueue(input: EnqueuePublic1v1Input): Promise<Public1v1QueueResult> {
    validatePublic1v1Enqueue(input);
    const requestHash = publicQueueRequestHash(input);
    const compatibilityHash = publicQueueCompatibilityHash(input);
    const subject = `${input.player.playerId}:${input.policy.modeId}`;
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await expireWaitingTickets(client, input.nowIso);
      const claim = await claimReceipt(client, "match.queue.v1", subject, input.requestId, requestHash);
      if (claim.duplicateResponse) {
        const result = await queueResult(client, String(claim.duplicateResponse.ticket_id ?? ""), input.player.playerId, true);
        await client.query("COMMIT");
        return result;
      }
      const existingWaiting = await client.query<Row>(
        `SELECT ticket_id FROM vs_match_queue_tickets
         WHERE player_id = $1 AND mode_id = $2 AND status = 'WAITING'
         FOR UPDATE`,
        [input.player.playerId, input.policy.modeId]
      );
      if (existingWaiting.rows[0]) {
        const ticketId = String(existingWaiting.rows[0].ticket_id);
        await completeReceipt(client, "match.queue.v1", subject, input.requestId,
          { ticket_id: ticketId }, ticketId);
        const result = await queueResult(client, ticketId, input.player.playerId, true);
        await client.query("COMMIT");
        return result;
      }

      const requiredPlayers = input.policy.requiredPlayers ?? requiredPlayersForPublicMode(input.policy.modeId);
      const candidateResult = await client.query<Row>(
        `SELECT * FROM vs_match_queue_tickets
         WHERE mode_id = $3 AND status = 'WAITING' AND compatibility_hash = $1
           AND player_id <> $2 AND expires_at >= $4
         ORDER BY created_at, ticket_id
         LIMIT $5 FOR UPDATE SKIP LOCKED`,
        [compatibilityHash, input.player.playerId, input.policy.modeId, input.nowIso, requiredPlayers - 1]
      );
      const ticketId = uuidV7();
      const expiresAt = new Date(new Date(input.nowIso).getTime() + input.policy.queueTtlSec * 1_000).toISOString();
      await client.query(
        `INSERT INTO vs_match_queue_tickets
          (ticket_id, player_id, public_entap_id, display_name, mode_id, protocol_version,
           client_build, request_id, request_hash, compatibility_hash, queue_payload,
           status, created_at, last_seen_at, expires_at)
         VALUES ($1, $2, $3, $4, $12, 2, $5, $6, $7, $8, $9::jsonb,
           'WAITING', $10, $10, $11)`,
        [ticketId, input.player.playerId, input.player.publicEntapId ?? null, input.player.displayName,
          input.clientBuild, input.requestId, requestHash, compatibilityHash,
          JSON.stringify({ policy: input.policy }), input.nowIso, expiresAt, input.policy.modeId]
      );

      const candidates = candidateResult.rows;
      if (candidates.length === requiredPlayers - 1) {
        const assignment = await assignedRoster(client, input, candidates);
        const roster: RosterEntry[] = assignment.roster;
        const contract = materializeContract({
          requestId: `match:${[...candidates.map((candidate) => String(candidate.ticket_id)), ticketId].join(":")}`,
          idempotencySubject: `${input.policy.modeId}:matchmaker`,
          minimumClientBuild: input.policy.minimumClientBuild,
          simBuildId: input.policy.simBuildId,
          modeId: input.policy.modeId,
          rulesetId: input.policy.rulesetId,
          rulesetHash: input.policy.rulesetHash,
          mapId: input.policy.mapId,
          mapHash: input.policy.mapHash,
          seed: randomSeed(),
          authorityTier: input.policy.authorityTier,
          status: "FROZEN",
          assignmentPolicyId: assignment.assignmentPolicyId,
          roster,
          rankPolicy: input.policy.ranked
            ? { enabled: true, queue: "GLOBAL_RANK", policy_id: "STANDARD_1V1_V1" }
            : { enabled: false, queue: "NONE", policy_id: "NONE", assignment_evidence: assignment.evidence },
          economyPolicy: input.policy.modeId === "CRUCIBLE_1V1"
            ? { policy_id: "CRUCIBLE_WAX_V1", stake_each_millis: 1000, winner_payout_millis: 1800,
              award_reserve_millis: 200 }
            : { policy_id: "NONE" },
          practicePolicy: { practice: false, bot_fill: false },
          createdAt: input.nowIso,
          expiresAt: new Date(new Date(input.nowIso).getTime() + input.policy.sessionTtlSec * 1_000).toISOString()
        });
        await insertContract(client, contract);
        await client.query(
          "INSERT INTO vs_command_streams (match_id, match_epoch, next_seq, last_execute_tick) VALUES ($1, 1, 1, -1)",
          [contract.matchId]
        );
        await insertLifecycleEvent(client, contract.matchId, 1, "ROSTER_FROZEN", {
          contract_id: contract.contractId,
          contract_hash: contract.contractHash
        }, input.nowIso);
        const matchedTicketIds = [...candidates.map((candidate) => String(candidate.ticket_id)), ticketId];
        await client.query(
          `UPDATE vs_match_queue_tickets SET status = 'MATCHED', contract_id = $1, last_seen_at = $2
           WHERE ticket_id = ANY($3::uuid[])`,
          [contract.contractId, input.nowIso, matchedTicketIds]
        );
      }
      await completeReceipt(client, "match.queue.v1", subject, input.requestId,
        { ticket_id: ticketId }, ticketId);
      const result = await queueResult(client, ticketId, input.player.playerId, false);
      await client.query("COMMIT");
      return result;
    } catch (error) {
      await rollbackQuietly(client);
      throw normalizePgError(error);
    } finally {
      client.release();
    }
  }

  async poll(ticketId: string, playerId: string, nowIso: string): Promise<Public1v1QueueResult> {
    await expireWaitingTickets(this.pool, nowIso, ticketId);
    await this.pool.query(
      "UPDATE vs_match_queue_tickets SET last_seen_at = $3 WHERE ticket_id = $1 AND player_id = $2",
      [ticketId, playerId, nowIso]
    );
    return queueResult(this.pool, ticketId, playerId, false);
  }

  async cancel(ticketId: string, playerId: string, _requestId: string, nowIso: string): Promise<Public1v1QueueResult> {
    const updated = await this.pool.query(
      `UPDATE vs_match_queue_tickets SET status = 'CANCELLED', last_seen_at = $3
       WHERE ticket_id = $1 AND player_id = $2 AND status = 'WAITING'`,
      [ticketId, playerId, nowIso]
    );
    const result = await queueResult(this.pool, ticketId, playerId, (updated.rowCount ?? 0) === 0);
    return result;
  }

  async getBotFallbackOffer(ticketId: string, playerId: string, nowIso: string, thresholdSec: number): Promise<PublicBotFallbackOffer> {
    await expireWaitingTickets(this.pool, nowIso, ticketId);
    const result = await this.pool.query<Row>(
      "SELECT * FROM vs_match_queue_tickets WHERE ticket_id = $1 AND player_id = $2",
      [ticketId, playerId]
    );
    const row = result.rows[0];
    if (!row) throw new DurableCoreError("queue_ticket_not_found");
    return botFallbackOffer(row, nowIso, thresholdSec);
  }

  async acceptBotFallback(input: PublicBotFallbackInput): Promise<JsonRecord> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await expireWaitingTickets(client, input.nowIso, input.ticketId);
      const found = await client.query<Row>(
        "SELECT * FROM vs_match_queue_tickets WHERE ticket_id = $1 AND player_id = $2 FOR UPDATE",
        [input.ticketId, input.playerId]
      );
      const row = found.rows[0];
      if (!row) throw new DurableCoreError("queue_ticket_not_found");
      const requestHash = sha256Canonical({
        action: "accept_bot_fallback", ticket_id: input.ticketId, player_id: input.playerId,
        bot_profile_id: input.botProfileId
      });
      const subject = `${input.ticketId}:${input.playerId}`;
      const claim = await claimReceipt(client, "match.bot-fallback.v1", subject, input.requestId, requestHash);
      if (claim.duplicateResponse) {
        await client.query("COMMIT");
        return { ...claim.duplicateResponse, duplicate: true };
      }
      const offer = botFallbackOffer(row, input.nowIso, input.thresholdSec);
      if (!offer.eligible) throw new DurableCoreError("bot_fallback_not_eligible");
      const queuePayload = jsonRecord(row.queue_payload);
      const policy = jsonRecord(queuePayload.policy) as Public1v1Policy;
      const roster: RosterEntry[] = [rosterEntry(row, 1, input.nowIso), {
        playerId: null,
        displayName: input.botDisplayName,
        participantType: "BOT",
        botProfileId: input.botProfileId,
        seatId: 2,
        teamId: 2,
        colorId: "PURPLE",
        readyState: "READY",
        connectionState: "CONNECTED",
        joinedAt: input.nowIso
      }];
      const modeId = String(row.mode_id) === "HCTF_1V1" ? "HCTF_BOT" : "CTF_BOT";
      const contract = materializeContract({
        requestId: `bot:${input.ticketId}:${input.requestId}`,
        idempotencySubject: `${String(row.mode_id)}:bot-fallback`,
        minimumClientBuild: policy.minimumClientBuild,
        simBuildId: policy.simBuildId,
        modeId,
        rulesetId: policy.rulesetId,
        rulesetHash: policy.rulesetHash,
        mapId: policy.mapId,
        mapHash: policy.mapHash,
        seed: randomSeed(),
        authorityTier: policy.authorityTier,
        status: "FROZEN",
        assignmentPolicyId: "SERVER_SEATS_CANONICAL_BOT_V1",
        roster,
        rankPolicy: { enabled: false, queue: "NONE", policy_id: "NONE" },
        economyPolicy: { policy_id: "NONE" },
        practicePolicy: { practice: true, bot_fill: true, bot_profile_id: input.botProfileId },
        createdAt: input.nowIso,
        expiresAt: new Date(new Date(input.nowIso).getTime() + policy.sessionTtlSec * 1_000).toISOString()
      });
      await insertContract(client, contract);
      await client.query(
        "INSERT INTO vs_command_streams (match_id, match_epoch, next_seq, last_execute_tick) VALUES ($1, 1, 1, -1)",
        [contract.matchId]
      );
      await insertLifecycleEvent(client, contract.matchId, 1, "BOT_FALLBACK_ACCEPTED", {
        source_ticket_id: input.ticketId,
        selected_mode: offer.selectedMode,
        bot_profile_id: input.botProfileId,
        practice: true,
        ranked: false,
        economic: false
      }, input.nowIso);
      await client.query(
        "UPDATE vs_match_queue_tickets SET status = 'CANCELLED', last_seen_at = $2 WHERE ticket_id = $1",
        [input.ticketId, input.nowIso]
      );
      const response = publicSessionView(contract);
      await completeReceipt(client, "match.bot-fallback.v1", subject, input.requestId, response, contract.matchId);
      await client.query("COMMIT");
      return { ...response, duplicate: false };
    } catch (error) {
      await rollbackQuietly(client);
      throw normalizePgError(error);
    } finally {
      client.release();
    }
  }

  async getSession(matchId: string, playerId: string): Promise<JsonRecord> {
    return sessionForPlayer(this.pool, matchId, playerId);
  }

  async setReady(input: LifecycleInput & { ready: boolean }): Promise<JsonRecord> {
    return this.lifecycleTransaction("ready", input, { ready: input.ready }, async (client, contractId, epoch, status) => {
      if (!['FROZEN', 'FORMING'].includes(status)) throw new DurableCoreError("match_not_ready_mutable");
      await client.query(
        "UPDATE vs_match_roster SET ready_state = $3 WHERE contract_id = $1 AND player_id = $2",
        [contractId, input.playerId, input.ready ? "READY" : "NOT_READY"]
      );
      await insertLifecycleEvent(client, input.matchId, epoch, input.ready ? "PLAYER_READY" : "PLAYER_NOT_READY",
        { player_id: input.playerId }, input.nowIso);
      return sessionForPlayer(client, input.matchId, input.playerId);
    });
  }

  async start(input: LifecycleInput): Promise<JsonRecord> {
    return this.lifecycleTransaction("start", input, {}, async (client, contractId, epoch, status) => {
      if (status === "RUNNING") return sessionForPlayer(client, input.matchId, input.playerId);
      if (status !== "FROZEN") throw new DurableCoreError("match_not_startable");
      const notReady = await client.query(
        "SELECT 1 FROM vs_match_roster WHERE contract_id = $1 AND ready_state <> 'READY' LIMIT 1",
        [contractId]
      );
      if ((notReady.rowCount ?? 0) > 0) throw new DurableCoreError("roster_not_ready");
      await client.query("UPDATE vs_match_roster SET ready_state = 'LOCKED' WHERE contract_id = $1", [contractId]);
      await client.query(
        "UPDATE vs_match_contracts SET status = 'RUNNING', updated_at = $2 WHERE contract_id = $1",
        [contractId, input.nowIso]
      );
      await insertLifecycleEvent(client, input.matchId, epoch, "MATCH_STARTED", {}, input.nowIso);
      return sessionForPlayer(client, input.matchId, input.playerId);
    });
  }

  async leave(input: LifecycleInput, reconnectGraceSec: number): Promise<JsonRecord> {
    return this.lifecycleTransaction("leave", input, { reconnect_grace_sec: reconnectGraceSec },
      async (client, contractId, epoch, status) => {
        if (["FORMING", "FROZEN"].includes(status)) {
          await client.query(
            "UPDATE vs_match_roster SET connection_state = 'DISCONNECTED' WHERE contract_id = $1 AND player_id = $2",
            [contractId, input.playerId]
          );
          await client.query(
            "UPDATE vs_match_contracts SET status = 'CANCELLED', updated_at = $2 WHERE contract_id = $1",
            [contractId, input.nowIso]
          );
          await insertLifecycleEvent(client, input.matchId, epoch, "MATCH_CANCELLED_BY_PLAYER",
            { player_id: input.playerId }, input.nowIso);
        } else if (["RUNNING", "RECONNECTING"].includes(status)) {
          const graceDeadline = new Date(new Date(input.nowIso).getTime() + reconnectGraceSec * 1_000).toISOString();
          await client.query(
            "UPDATE vs_match_roster SET connection_state = 'GRACE' WHERE contract_id = $1 AND player_id = $2",
            [contractId, input.playerId]
          );
          await client.query(
            `INSERT INTO vs_match_reconnect_state
              (match_id, player_id, match_epoch, reconnect_epoch, connection_state, grace_deadline_at, last_seen_at)
             VALUES ($1, $2, $3, 1, 'GRACE', $4, $5)
             ON CONFLICT (match_id, player_id) DO UPDATE SET
               reconnect_epoch = vs_match_reconnect_state.reconnect_epoch + 1,
               connection_state = 'GRACE', grace_deadline_at = EXCLUDED.grace_deadline_at,
               last_seen_at = EXCLUDED.last_seen_at, updated_at = now()`,
            [input.matchId, input.playerId, epoch, graceDeadline, input.nowIso]
          );
          await client.query(
            "UPDATE vs_match_contracts SET status = 'RECONNECTING', updated_at = $2 WHERE contract_id = $1",
            [contractId, input.nowIso]
          );
          await insertLifecycleEvent(client, input.matchId, epoch, "PLAYER_GRACE_STARTED",
            { player_id: input.playerId, grace_deadline_at: graceDeadline }, input.nowIso);
        }
        return sessionForPlayer(client, input.matchId, input.playerId);
      });
  }

  async resume(playerId: string, requestId: string, nowIso: string): Promise<JsonRecord> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const found = await client.query<Row>(
        `SELECT c.contract_id, c.match_id, c.match_epoch, c.status
         FROM vs_match_contracts c
         JOIN vs_match_roster r ON r.contract_id = c.contract_id
         WHERE r.player_id = $1 AND c.status IN ('FROZEN', 'RUNNING', 'RECONNECTING')
         ORDER BY c.created_at DESC LIMIT 1 FOR UPDATE`,
        [playerId]
      );
      const row = found.rows[0];
      if (!row) throw new DurableCoreError("resumable_match_not_found");
      const matchId = String(row.match_id);
      const epoch = Number(row.match_epoch);
      const claim = await claimReceipt(client, "match.lifecycle.v1", `${matchId}:${epoch}:${playerId}:resume`,
        requestId, sha256Canonical({ action: "resume", match_id: matchId, player_id: playerId }));
      if (claim.duplicateResponse) {
        await client.query("COMMIT");
        return { ...claim.duplicateResponse, duplicate: true };
      }
      const reconnect = await client.query<Row>(
        `SELECT * FROM vs_match_reconnect_state WHERE match_id = $1 AND player_id = $2 FOR UPDATE`,
        [matchId, playerId]
      );
      if (reconnect.rows[0]?.grace_deadline_at
        && new Date(String(reconnect.rows[0].grace_deadline_at)).getTime() < new Date(nowIso).getTime()) {
        throw new DurableCoreError("reconnect_grace_expired");
      }
      await client.query(
        "UPDATE vs_match_roster SET connection_state = 'CONNECTED' WHERE contract_id = $1 AND player_id = $2",
        [row.contract_id, playerId]
      );
      await client.query(
        `UPDATE vs_match_reconnect_state SET connection_state = 'CONNECTED', grace_deadline_at = NULL,
           last_seen_at = $3, updated_at = now() WHERE match_id = $1 AND player_id = $2`,
        [matchId, playerId, nowIso]
      );
      const disconnected = await client.query(
        "SELECT 1 FROM vs_match_roster WHERE contract_id = $1 AND connection_state <> 'CONNECTED' LIMIT 1",
        [row.contract_id]
      );
      if ((disconnected.rowCount ?? 0) === 0 && row.status === "RECONNECTING") {
        await client.query(
          "UPDATE vs_match_contracts SET status = 'RUNNING', updated_at = $2 WHERE contract_id = $1",
          [row.contract_id, nowIso]
        );
      }
      await insertLifecycleEvent(client, matchId, epoch, "PLAYER_RECONNECTED", { player_id: playerId }, nowIso);
      const response = await sessionForPlayer(client, matchId, playerId);
      await completeReceipt(client, "match.lifecycle.v1", claim.subject, requestId, response, matchId);
      await client.query("COMMIT");
      return { ...response, duplicate: false };
    } catch (error) {
      await rollbackQuietly(client);
      throw normalizePgError(error);
    } finally {
      client.release();
    }
  }

  async appendCommand(input: AppendCommandInput): Promise<CommandReceipt> {
    await ensureMembership(this.pool, input.matchId, input.playerId);
    return this.core.appendCommand(input);
  }

  async readCommands(matchId: string, matchEpoch: number, playerId: string, afterSeq: number): Promise<CommandPage> {
    await ensureMembership(this.pool, matchId, playerId);
    const page = await this.core.readCommands(matchId, matchEpoch, afterSeq);
    await this.pool.query(
      `INSERT INTO vs_match_peer_acks
        (match_id, match_epoch, player_id, acknowledged_seq, acknowledged_at)
       VALUES ($1, $2, $3, $4, now())
       ON CONFLICT (match_id, match_epoch, player_id) DO UPDATE SET
         acknowledged_seq = GREATEST(vs_match_peer_acks.acknowledged_seq, EXCLUDED.acknowledged_seq),
         acknowledged_at = EXCLUDED.acknowledged_at`,
      [matchId, matchEpoch, playerId, Math.max(0, afterSeq)]
    );
    return page;
  }

  async syncCompetitiveIdentity(input: CompetitiveIdentityInput): Promise<JsonRecord> {
    if (!isUuidV7(input.playerId) || !Number.isSafeInteger(input.rankValue)
      || input.rankValue < -2_147_483_648 || input.rankValue > 2_147_483_647
      || !input.sourceRevision.trim() || !Number.isFinite(new Date(input.nowIso).getTime())) {
      throw new DurableCoreError("competitive_identity_invalid");
    }
    const friends = [...new Set(input.friendPlayerIds)].sort();
    if (friends.some((friendId) => friendId === input.playerId || !isUuidV7(friendId))) {
      throw new DurableCoreError("competitive_identity_invalid");
    }
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `INSERT INTO vs_public_competitive_profiles (player_id, rank_value, source_revision, updated_at)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (player_id) DO UPDATE SET rank_value = EXCLUDED.rank_value,
           source_revision = EXCLUDED.source_revision, updated_at = EXCLUDED.updated_at`,
        [input.playerId, input.rankValue, input.sourceRevision, input.nowIso]
      );
      await client.query(
        `UPDATE vs_public_friend_relationships SET active = FALSE, source_revision = $2, updated_at = $3
         WHERE player_a_id = $1 OR player_b_id = $1`,
        [input.playerId, input.sourceRevision, input.nowIso]
      );
      for (const friendId of friends) {
        const [playerAId, playerBId] = [input.playerId, friendId].sort();
        await client.query(
          `INSERT INTO vs_public_friend_relationships
            (player_a_id, player_b_id, source_revision, active, updated_at)
           VALUES ($1, $2, $3, TRUE, $4)
           ON CONFLICT (player_a_id, player_b_id) DO UPDATE SET source_revision = EXCLUDED.source_revision,
             active = TRUE, updated_at = EXCLUDED.updated_at`,
          [playerAId, playerBId, input.sourceRevision, input.nowIso]
        );
      }
      await client.query("COMMIT");
      return { player_id: input.playerId, rank_value: input.rankValue,
        friend_player_ids: friends, source_revision: input.sourceRevision };
    } catch (error) {
      await rollbackQuietly(client);
      throw normalizePgError(error);
    } finally {
      client.release();
    }
  }

  private async lifecycleTransaction(
    action: string,
    input: LifecycleInput,
    payload: JsonRecord,
    operation: (client: PoolClient, contractId: string, epoch: number, status: string) => Promise<JsonRecord>
  ): Promise<JsonRecord> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const membership = await client.query<Row>(
        `SELECT c.contract_id, c.match_epoch, c.status
         FROM vs_match_contracts c JOIN vs_match_roster r ON r.contract_id = c.contract_id
         WHERE c.match_id = $1 AND r.player_id = $2 FOR UPDATE`,
        [input.matchId, input.playerId]
      );
      const row = membership.rows[0];
      if (!row) throw new DurableCoreError("player_not_in_match");
      const epoch = Number(row.match_epoch);
      const subject = `${input.matchId}:${epoch}:${input.playerId}:${action}`;
      const requestHash = sha256Canonical({ action, match_id: input.matchId, player_id: input.playerId, ...payload });
      const claim = await claimReceipt(client, "match.lifecycle.v1", subject, input.requestId, requestHash);
      if (claim.duplicateResponse) {
        await client.query("COMMIT");
        return { ...claim.duplicateResponse, duplicate: true };
      }
      const response = await operation(client, String(row.contract_id), epoch, String(row.status));
      await completeReceipt(client, "match.lifecycle.v1", subject, input.requestId, response, input.matchId);
      await client.query("COMMIT");
      return { ...response, duplicate: false };
    } catch (error) {
      await rollbackQuietly(client);
      throw normalizePgError(error);
    } finally {
      client.release();
    }
  }
}

async function assignedRoster(
  client: PoolClient,
  input: EnqueuePublic1v1Input,
  candidates: Row[]
): Promise<{ assignmentPolicyId: string; roster: RosterEntry[]; evidence: JsonRecord }> {
  const allRows: Row[] = [...candidates, {
    player_id: input.player.playerId,
    public_entap_id: input.player.publicEntapId ?? null,
    display_name: input.player.displayName,
    created_at: input.nowIso
  }];
  if (!["STANDARD_3P_FFA", "STANDARD_2V2", "STANDARD_4P_FFA"].includes(input.policy.modeId)) {
    return {
      assignmentPolicyId: "SERVER_SEATS_COLORS_V1",
      roster: allRows.map((row, index) => rosterEntry(row, index + 1, iso(row.created_at ?? input.nowIso))),
      evidence: {}
    };
  }
  const playerIds = allRows.map((row) => String(row.player_id));
  const [profiles, edges] = await Promise.all([
    client.query<Row>(
      "SELECT player_id, rank_value FROM vs_public_competitive_profiles WHERE player_id = ANY($1::uuid[])",
      [playerIds]
    ),
    client.query<Row>(
      `SELECT player_a_id, player_b_id FROM vs_public_friend_relationships
       WHERE active AND player_a_id = ANY($1::uuid[]) AND player_b_id = ANY($1::uuid[])
       ORDER BY player_a_id, player_b_id`,
      [playerIds]
    )
  ]);
  const ranks = new Map(profiles.rows.map((row) => [String(row.player_id), Number(row.rank_value)]));
  const snapshots: CompetitivePlayerSnapshot[] = allRows.map((row) => ({
    playerId: String(row.player_id),
    publicEntapId: row.public_entap_id == null ? null : String(row.public_entap_id),
    displayName: String(row.display_name),
    rankValue: ranks.get(String(row.player_id)) ?? 0,
    joinedAt: iso(row.created_at ?? input.nowIso)
  }));
  const friendEdges: FriendEdge[] = edges.rows.map((row) => ({
    playerAId: String(row.player_a_id), playerBId: String(row.player_b_id)
  }));
  return assignMultiSeatRoster(input.policy.modeId as MultiSeatMode, snapshots, friendEdges);
}

async function queueResult(
  executor: Pick<Pool, "query"> | Pick<PoolClient, "query">,
  ticketId: string,
  playerId: string,
  duplicate: boolean
): Promise<Public1v1QueueResult> {
  const result = await executor.query<Row>(
    `SELECT q.*, c.match_id FROM vs_match_queue_tickets q
     LEFT JOIN vs_match_contracts c ON c.contract_id = q.contract_id
     WHERE q.ticket_id = $1 AND q.player_id = $2`,
    [ticketId, playerId]
  );
  const row = result.rows[0];
  if (!row) throw new DurableCoreError("queue_ticket_not_found");
  const ticket: Public1v1Ticket = {
    ticketId: String(row.ticket_id),
    playerId: String(row.player_id),
    status: String(row.status) as Public1v1Ticket["status"],
    contractId: row.contract_id == null ? null : String(row.contract_id),
    matchId: row.match_id == null ? null : String(row.match_id),
    createdAt: iso(row.created_at),
    expiresAt: iso(row.expires_at)
  };
  return {
    ticket,
    session: ticket.matchId ? await sessionForPlayer(executor, ticket.matchId, playerId) : null,
    duplicate
  };
}

async function sessionForPlayer(
  executor: Pick<Pool, "query"> | Pick<PoolClient, "query">,
  matchId: string,
  playerId: string
): Promise<JsonRecord> {
  const membership = await executor.query<{ contract_id: string }>(
    `SELECT c.contract_id FROM vs_match_contracts c
     JOIN vs_match_roster r ON r.contract_id = c.contract_id
     WHERE c.match_id = $1 AND r.player_id = $2`,
    [matchId, playerId]
  );
  if (!membership.rows[0]) throw new DurableCoreError("player_not_in_match");
  const contract = await readContract(executor, membership.rows[0].contract_id);
  if (!contract) throw new DurableCoreError("contract_missing");
  return publicSessionView(contract);
}

async function ensureMembership(executor: Pick<Pool, "query">, matchId: string, playerId: string): Promise<void> {
  const found = await executor.query(
    `SELECT 1 FROM vs_match_contracts c JOIN vs_match_roster r ON r.contract_id = c.contract_id
     WHERE c.match_id = $1 AND r.player_id = $2`,
    [matchId, playerId]
  );
  if ((found.rowCount ?? 0) === 0) throw new DurableCoreError("player_not_in_match");
}

async function expireWaitingTickets(
  executor: Pick<Pool, "query"> | Pick<PoolClient, "query">,
  nowIso: string,
  ticketId?: string
): Promise<void> {
  await executor.query(
    `UPDATE vs_match_queue_tickets SET status = 'EXPIRED', last_seen_at = $1
     WHERE status = 'WAITING' AND expires_at < $1 ${ticketId ? "AND ticket_id = $2" : ""}`,
    ticketId ? [nowIso, ticketId] : [nowIso]
  );
}

async function claimReceipt(
  client: PoolClient,
  namespace: string,
  subject: string,
  key: string,
  requestHash: string
): Promise<ReceiptClaim> {
  const inserted = await client.query(
    `INSERT INTO vs_idempotency_receipts
      (namespace, authoritative_subject, idempotency_key, request_hash, status)
     VALUES ($1, $2, $3, $4, 'PENDING') ON CONFLICT DO NOTHING`,
    [namespace, subject, key, requestHash]
  );
  if ((inserted.rowCount ?? 0) > 0) return { duplicateResponse: null, requestHash, subject };
  const existing = await client.query<Row>(
    `SELECT request_hash, status, response_json FROM vs_idempotency_receipts
     WHERE namespace = $1 AND authoritative_subject = $2 AND idempotency_key = $3 FOR UPDATE`,
    [namespace, subject, key]
  );
  const row = existing.rows[0];
  if (!row || String(row.request_hash) !== requestHash) throw new DurableCoreError("idempotency_conflict");
  if (row.status !== "COMPLETED") throw new DurableCoreError("idempotency_in_progress");
  return { duplicateResponse: jsonRecord(row.response_json), requestHash, subject };
}

async function completeReceipt(
  client: PoolClient,
  namespace: string,
  subject: string,
  key: string,
  response: JsonRecord,
  sideEffectRef: string
): Promise<void> {
  await client.query(
    `UPDATE vs_idempotency_receipts SET status = 'COMPLETED', response_json = $4::jsonb,
       side_effect_ref = $5, updated_at = now()
     WHERE namespace = $1 AND authoritative_subject = $2 AND idempotency_key = $3`,
    [namespace, subject, key, JSON.stringify(response), sideEffectRef]
  );
}

async function insertLifecycleEvent(
  client: PoolClient,
  matchId: string,
  epoch: number,
  eventType: string,
  payload: JsonRecord,
  occurredAt: string
): Promise<void> {
  await client.query(
    `INSERT INTO vs_match_lifecycle_events
      (event_id, match_id, match_epoch, event_type, event_payload, occurred_at)
     VALUES ($1, $2, $3, $4, $5::jsonb, $6)`,
    [uuidV7(), matchId, epoch, eventType, JSON.stringify(payload), occurredAt]
  );
}

function rosterEntry(row: Row, seatId: number, joinedAt: string): RosterEntry {
  return {
    playerId: String(row.player_id),
    publicEntapId: row.public_entap_id == null ? null : String(row.public_entap_id),
    displayName: String(row.display_name),
    participantType: "HUMAN",
    seatId,
    teamId: seatId,
    colorId: seatId === 1 ? "GREEN" : "PURPLE",
    readyState: "NOT_READY",
    connectionState: "CONNECTED",
    joinedAt
  };
}

function botFallbackOffer(row: Row, nowIso: string, thresholdSec: number): PublicBotFallbackOffer {
  const modeId = String(row.mode_id);
  if (modeId !== "CTF_1V1" && modeId !== "HCTF_1V1") {
    throw new DurableCoreError("bot_fallback_mode_unsupported");
  }
  const waitedSec = Math.max(0, Math.floor((new Date(nowIso).getTime() - new Date(iso(row.created_at)).getTime()) / 1_000));
  const remainingSec = Math.max(0, thresholdSec - waitedSec);
  return {
    eligible: String(row.status) === "WAITING" && remainingSec === 0,
    modeId,
    selectedMode: modeId === "HCTF_1V1" ? "HIDDEN_CAPTURE_FLAG" : "CAPTURE_FLAG",
    waitedSec,
    remainingSec
  };
}

function randomSeed(): string {
  return BigInt(`0x${uuidV7().replaceAll("-", "").slice(-16)}`).toString(10);
}

function iso(value: unknown): string {
  return (value instanceof Date ? value : new Date(String(value))).toISOString();
}

function jsonRecord(value: unknown): JsonRecord {
  if (typeof value === "string") value = JSON.parse(value) as unknown;
  if (typeof value !== "object" || value == null || Array.isArray(value)) {
    throw new DurableCoreError("stored_json_invalid");
  }
  return deepClone(value as JsonRecord);
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
