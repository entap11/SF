import type { Pool, PoolClient } from "pg";
import {
  DurableCoreError, deepClone, sha256Canonical, uuidV7, type JsonRecord
} from "./durableCore.js";
import {
  definitionDocument, grantHash, isBetterScore, parseIso, resultRequestHash, scoreVerifiedResult,
  validatePublishInput, type ContestLeaderboard, type ContestLeaderboardRow, type ContestMessage,
  type ContestRosterEntry, type EnterContestInput, type PublicContestDefinition,
  type PublicContestRepository, type PublishContestInput, type TrustedContestResultInput,
  type ContestResultReceipt, type ContestAttempt, type ContestEvidence, type ContestEvidenceLease
} from "./publicContest.js";

type Row = Record<string, unknown>;

export class PostgresPublicContestRepository implements PublicContestRepository {
  constructor(private readonly pool: Pool) {}

  async publish(input: PublishContestInput): Promise<PublicContestDefinition> {
    validatePublishInput(input);
    const contestId = input.contestId ?? uuidV7(parseIso(input.createdAt, "invalid_contest_created_at"));
    const leaderboardId = input.leaderboardId ?? uuidV7(parseIso(input.createdAt, "invalid_contest_created_at"));
    const document = definitionDocument(input, { contestId, leaderboardId });
    const definitionHash = sha256Canonical(document);
    const now = parseIso(input.createdAt, "invalid_contest_created_at");
    const starts = parseIso(input.startsAt, "invalid_contest_starts_at");
    const ends = parseIso(input.endsAt, "invalid_contest_ends_at");
    const status = now < starts ? "SCHEDULED" : now < ends ? "OPEN" : "CLOSED";
    try {
      const inserted = await this.pool.query<Row>(
        `INSERT INTO vs_public_contests
          (contest_id, leaderboard_id, contest_schema_version, series_key, generation,
           family, scope, map_count, status, map_pack_id, map_ids, content_hashes,
           sim_build_id, comparator_id, best_entry_policy, attempt_policy, closure_policy,
           eligibility_policy, starts_at, ends_at, created_at, opened_at, closed_at,
           definition_hash, definition_json)
         VALUES ($1, $2, 1, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11::jsonb,
           $12, $13, $14, $15::jsonb, $16::jsonb, $17::jsonb, $18, $19, $20, $21, $22, $23, $24::jsonb)
         RETURNING *`,
        [contestId, leaderboardId, input.seriesKey, input.generation, input.family, input.scope,
          input.mapCount, status, input.mapPackId, JSON.stringify(input.mapIds),
          JSON.stringify(input.contentHashes), input.simBuildId, input.comparatorId,
          input.bestEntryPolicy, JSON.stringify(input.attemptPolicy), JSON.stringify(input.closurePolicy),
          JSON.stringify(input.eligibilityPolicy), input.startsAt, input.endsAt, input.createdAt,
          status === "OPEN" ? input.createdAt : null, status === "CLOSED" ? input.createdAt : null,
          definitionHash, JSON.stringify(document)]
      );
      return definitionFromRow(inserted.rows[0]);
    } catch (error) {
      if (isUniqueViolation(error)) throw new DurableCoreError("contest_definition_conflict");
      throw error;
    }
  }

  async reconcile(nowIso: string): Promise<{ opened: number; closed: number; rolled: number }> {
    parseIso(nowIso, "invalid_server_time");
    const client = await this.pool.connect();
    let opened = 0;
    let closed = 0;
    let rolled = 0;
    try {
      await client.query("BEGIN");
      const openedRows = await client.query(
        `UPDATE vs_public_contests SET status = 'OPEN', opened_at = $1, updated_at = $1
         WHERE status = 'SCHEDULED' AND starts_at <= $1 AND ends_at > $1`, [nowIso]
      );
      opened += openedRows.rowCount ?? 0;
      for (let guard = 0; guard < 100; guard += 1) {
        const expired = await client.query<Row>(
          `SELECT * FROM vs_public_contests
           WHERE status IN ('SCHEDULED', 'OPEN') AND ends_at <= $1
           ORDER BY ends_at, contest_id FOR UPDATE SKIP LOCKED LIMIT 1`, [nowIso]
        );
        const row = expired.rows[0];
        if (!row) break;
        const finalized = await closeContest(client, row, nowIso);
        if (finalized) closed += 1;
        const intervalSec = integerOrZero(jsonRecord(row.closure_policy).rollover_interval_sec);
        if (intervalSec > 0) {
          const created = await cloneNextGeneration(client, row, intervalSec, nowIso);
          if (created) rolled += 1;
        }
        if (guard === 99) throw new DurableCoreError("contest_rollover_limit_exceeded");
      }
      const openedAfterRoll = await client.query(
        `UPDATE vs_public_contests SET status = 'OPEN', opened_at = $1, updated_at = $1
         WHERE status = 'SCHEDULED' AND starts_at <= $1 AND ends_at > $1`, [nowIso]
      );
      opened += openedAfterRoll.rowCount ?? 0;
      for (let guard = 0; guard < 100; guard += 1) {
        const ready = await client.query<Row>(
          `SELECT c.* FROM vs_public_contests c
           WHERE c.status = 'FINALIZING'
             AND NOT EXISTS (SELECT 1 FROM vs_public_contest_evidence e
               WHERE e.contest_id = c.contest_id AND e.status IN ('PENDING', 'LEASED'))
           ORDER BY c.ends_at, c.contest_id FOR UPDATE OF c SKIP LOCKED LIMIT 1`
        );
        if (!ready.rows[0]) break;
        if (await closeContest(client, ready.rows[0], nowIso)) closed += 1;
        if (guard === 99) throw new DurableCoreError("contest_finalize_limit_exceeded");
      }
      await client.query("COMMIT");
      return { opened, closed, rolled };
    } catch (error) {
      await rollbackQuietly(client);
      throw error;
    } finally {
      client.release();
    }
  }

  async listCurrent(filters: {
    family?: PublicContestDefinition["family"];
    scope?: PublicContestDefinition["scope"];
    mapCount?: number;
  }, nowIso: string): Promise<PublicContestDefinition[]> {
    await this.reconcile(nowIso);
    const rows = await this.pool.query<Row>(
      `SELECT * FROM vs_public_contests
       WHERE status = 'OPEN' AND starts_at <= $1 AND ends_at > $1
         AND ($2::text IS NULL OR family = $2)
         AND ($3::text IS NULL OR scope = $3)
         AND ($4::integer IS NULL OR map_count = $4)
       ORDER BY family, scope, map_count, starts_at, contest_id`,
      [nowIso, filters.family ?? null, filters.scope ?? null, filters.mapCount ?? null]
    );
    return rows.rows.map(definitionFromRow);
  }

  async getDefinition(contestId: string): Promise<PublicContestDefinition> {
    const found = await this.pool.query<Row>("SELECT * FROM vs_public_contests WHERE contest_id = $1", [contestId]);
    if (!found.rows[0]) throw new DurableCoreError("contest_not_found");
    return definitionFromRow(found.rows[0]);
  }

  async enter(input: EnterContestInput): Promise<{ attempt: ContestAttempt; duplicate: boolean }> {
    parseIso(input.nowIso, "invalid_server_time");
    if (!input.requestId.trim() || input.requestId.length > 256 || !input.displayName.trim()) {
      throw new DurableCoreError("invalid_contest_entry");
    }
    await this.reconcile(input.nowIso);
    const requestHash = sha256Canonical({ contest_id: input.contestId, player_id: input.playerId,
      display_name: input.displayName, public_entap_id: input.publicEntapId ?? null });
    const subject = `${input.contestId}:${input.playerId}`;
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const claimed = await claimReceipt(client, "contest.attempt.v1", subject, input.requestId, requestHash);
      if (!claimed) {
        const receipt = await readReceipt(client, "contest.attempt.v1", subject, input.requestId, requestHash);
        const attempt = await readAttempt(client, stringValue(receipt.attempt_id));
        if (!attempt) throw new DurableCoreError("idempotency_receipt_corrupt");
        await client.query("COMMIT");
        return { attempt, duplicate: true };
      }
      const contestResult = await client.query<Row>(
        "SELECT * FROM vs_public_contests WHERE contest_id = $1 FOR UPDATE", [input.contestId]
      );
      const contest = contestResult.rows[0];
      if (!contest) throw new DurableCoreError("contest_not_found");
      const now = parseIso(input.nowIso, "invalid_server_time");
      if (String(contest.status) !== "OPEN" || now < dateMs(contest.starts_at) || now >= dateMs(contest.ends_at)) {
        throw new DurableCoreError("contest_not_open");
      }
      if (String(contest.best_entry_policy) === "ONLY_SCORED_ATTEMPT") {
        const scored = await client.query(
          "SELECT 1 FROM vs_public_contest_best_results WHERE contest_id = $1 AND player_id = $2",
          [input.contestId, input.playerId]
        );
        if ((scored.rowCount ?? 0) > 0) throw new DurableCoreError("contest_player_already_scored");
      }
      await client.query(
        `INSERT INTO vs_public_contest_roster
          (contest_id, player_id, display_name, public_entap_id, joined_at)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (contest_id, player_id) DO UPDATE SET
           display_name = EXCLUDED.display_name,
           public_entap_id = COALESCE(EXCLUDED.public_entap_id, vs_public_contest_roster.public_entap_id)`,
        [input.contestId, input.playerId, input.displayName, input.publicEntapId ?? null, input.nowIso]
      );
      const sequence = await client.query<{ next_number: number }>(
        `SELECT COALESCE(MAX(attempt_number), 0)::int + 1 AS next_number
         FROM vs_public_contest_attempts WHERE contest_id = $1 AND player_id = $2`,
        [input.contestId, input.playerId]
      );
      const attemptNumber = Number(sequence.rows[0]?.next_number ?? 1);
      const attemptId = uuidV7(now);
      const policy = jsonRecord(contest.attempt_policy);
      const windowSec = integerOrZero(policy.submission_window_sec);
      const contestEnd = dateMs(contest.ends_at);
      const deadlineMs = windowSec > 0 ? Math.min(contestEnd, now + windowSec * 1_000) : contestEnd;
      if (deadlineMs <= now) throw new DurableCoreError("contest_not_open");
      const seed = sha256Canonical({ contest_id: input.contestId, attempt_id: attemptId }).slice(0, 32);
      const grant = {
        contest_schema_version: 1, attempt_id: attemptId, contest_id: input.contestId,
        player_id: input.playerId, attempt_number: attemptNumber,
        definition_hash: String(contest.definition_hash), sim_build_id: String(contest.sim_build_id),
        content_hashes: jsonRecord(contest.content_hashes), seed, issued_at: input.nowIso,
        submission_deadline_at: new Date(deadlineMs).toISOString()
      };
      const signedGrantHash = grantHash(input.grantSecret, grant);
      await client.query(
        `INSERT INTO vs_public_contest_attempts
          (attempt_id, contest_id, player_id, attempt_number, definition_hash, seed,
           issued_at, submission_deadline_at, grant_hash, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'ISSUED')`,
        [attemptId, input.contestId, input.playerId, attemptNumber, contest.definition_hash, seed,
          input.nowIso, grant.submission_deadline_at, signedGrantHash]
      );
      await completeReceipt(client, "contest.attempt.v1", subject, input.requestId, requestHash,
        { attempt_id: attemptId }, attemptId);
      const attempt = await readAttempt(client, attemptId);
      await client.query("COMMIT");
      if (!attempt) throw new DurableCoreError("contest_attempt_missing");
      return { attempt, duplicate: false };
    } catch (error) {
      await rollbackQuietly(client);
      throw error;
    } finally {
      client.release();
    }
  }

  async getRoster(contestId: string): Promise<ContestRosterEntry[]> {
    const contest = await this.pool.query("SELECT 1 FROM vs_public_contests WHERE contest_id = $1", [contestId]);
    if ((contest.rowCount ?? 0) === 0) throw new DurableCoreError("contest_not_found");
    const rows = await this.pool.query<Row>(
      `SELECT * FROM vs_public_contest_roster WHERE contest_id = $1 ORDER BY joined_at, player_id`, [contestId]
    );
    return rows.rows.map((row) => ({
      playerId: String(row.player_id), displayName: String(row.display_name),
      publicEntapId: row.public_entap_id == null ? null : String(row.public_entap_id),
      joinedAt: isoValue(row.joined_at)
    }));
  }

  async commitTrustedResult(input: TrustedContestResultInput): Promise<ContestResultReceipt> {
    parseIso(input.qualifiedAt, "invalid_qualified_at");
    if (!input.submissionId.trim() || input.submissionId.length > 256
      || !input.verificationMethod.trim() || input.verificationMethod.startsWith("CLIENT")
      || !input.evidenceRef.trim()) throw new DurableCoreError("invalid_contest_result_authority");
    await this.reconcile(input.qualifiedAt);
    const requestHash = resultRequestHash(input);
    const subject = `${input.contestId}:${input.attemptId}`;
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const claimed = await claimReceipt(client, "contest.result.v1", subject, input.submissionId, requestHash);
      if (!claimed) {
        const response = await readReceipt(client, "contest.result.v1", subject, input.submissionId, requestHash);
        const result = await readResult(client, stringValue(response.contest_result_id));
        if (!result) throw new DurableCoreError("idempotency_receipt_corrupt");
        await client.query("COMMIT");
        return { ...result, bestUpdated: response.best_updated === true,
          leaderboardVersion: Number(response.leaderboard_version), duplicate: true };
      }
      const found = await client.query<Row>(
        `SELECT a.*, c.status AS contest_status, c.ends_at, c.map_ids, c.comparator_id,
                c.best_entry_policy, c.definition_hash AS contest_definition_hash,
                r.display_name
         FROM vs_public_contest_attempts a
         JOIN vs_public_contests c ON c.contest_id = a.contest_id
         JOIN vs_public_contest_roster r ON r.contest_id = a.contest_id AND r.player_id = a.player_id
         WHERE a.attempt_id = $1 FOR UPDATE OF a, c`, [input.attemptId]
      );
      const row = found.rows[0];
      if (!row) throw new DurableCoreError("contest_attempt_not_found");
      if (String(row.contest_id) !== input.contestId || String(row.player_id) !== input.playerId) {
        throw new DurableCoreError("contest_attempt_identity_mismatch");
      }
      if (String(row.definition_hash) !== input.definitionHash
        || String(row.contest_definition_hash) !== input.definitionHash
        || String(row.grant_hash) !== input.grantHash) throw new DurableCoreError("contest_attempt_grant_mismatch");
      if (String(row.status) !== "ISSUED") throw new DurableCoreError("contest_attempt_already_committed");
      const qualifiedAt = parseIso(input.qualifiedAt, "invalid_qualified_at");
      if (qualifiedAt > dateMs(row.submission_deadline_at) || qualifiedAt >= dateMs(row.ends_at)) {
        await client.query("UPDATE vs_public_contest_attempts SET status = 'EXPIRED' WHERE attempt_id = $1", [input.attemptId]);
        throw new DurableCoreError("contest_attempt_deadline_expired");
      }
      if (!["OPEN", "FINALIZING"].includes(String(row.contest_status))) {
        throw new DurableCoreError("contest_not_open");
      }
      const score = scoreVerifiedResult(String(row.comparator_id) as PublicContestDefinition["comparatorId"],
        stringArray(row.map_ids), input.metrics, jsonRecord(row.attempt_policy));
      const resultId = uuidV7(qualifiedAt);
      await client.query(
        `INSERT INTO vs_public_contest_results
          (contest_result_id, contest_id, attempt_id, player_id, submission_id, request_hash,
           verification_method, evidence_ref, result_json, competitive_primary,
           competitive_secondary, competitive_tertiary, qualified_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10, $11, $12, $13)`,
        [resultId, input.contestId, input.attemptId, input.playerId, input.submissionId, requestHash,
          input.verificationMethod, input.evidenceRef, JSON.stringify(score.result), score.primary,
          score.secondary, score.tertiary, input.qualifiedAt]
      );
      await client.query(
        "UPDATE vs_public_contest_attempts SET status = 'COMMITTED', committed_result_id = $2 WHERE attempt_id = $1",
        [input.attemptId, resultId]
      );
      const existingResult = await client.query<Row>(
        `SELECT * FROM vs_public_contest_best_results WHERE contest_id = $1 AND player_id = $2 FOR UPDATE`,
        [input.contestId, input.playerId]
      );
      const existing = existingResult.rows[0];
      const bestUpdated = !existing || isBetterScore({ ...score, qualifiedAt: input.qualifiedAt }, {
        primary: Number(existing.competitive_primary), secondary: Number(existing.competitive_secondary),
        tertiary: Number(existing.competitive_tertiary), qualifiedAt: isoValue(existing.qualified_at)
      });
      if (bestUpdated) {
        await client.query(
          `INSERT INTO vs_public_contest_best_results
            (contest_id, player_id, contest_result_id, display_name, competitive_primary,
             competitive_secondary, competitive_tertiary, qualified_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $8)
           ON CONFLICT (contest_id, player_id) DO UPDATE SET
             contest_result_id = EXCLUDED.contest_result_id,
             display_name = EXCLUDED.display_name,
             competitive_primary = EXCLUDED.competitive_primary,
             competitive_secondary = EXCLUDED.competitive_secondary,
             competitive_tertiary = EXCLUDED.competitive_tertiary,
             qualified_at = EXCLUDED.qualified_at,
             updated_at = EXCLUDED.updated_at`,
          [input.contestId, input.playerId, resultId, row.display_name, score.primary,
            score.secondary, score.tertiary, input.qualifiedAt]
        );
        await client.query(
          "UPDATE vs_public_contests SET leaderboard_version = leaderboard_version + 1, updated_at = $2 WHERE contest_id = $1",
          [input.contestId, input.qualifiedAt]
        );
      }
      const version = await client.query<{ leaderboard_version: string }>(
        "SELECT leaderboard_version::text FROM vs_public_contests WHERE contest_id = $1", [input.contestId]
      );
      const leaderboardVersion = Number(version.rows[0]?.leaderboard_version ?? 0);
      await completeReceipt(client, "contest.result.v1", subject, input.submissionId, requestHash,
        { contest_result_id: resultId, best_updated: bestUpdated, leaderboard_version: leaderboardVersion }, resultId);
      await client.query("COMMIT");
      return {
        contestResultId: resultId, contestId: input.contestId, attemptId: input.attemptId,
        playerId: input.playerId, result: deepClone(score.result), qualifiedAt: input.qualifiedAt,
        bestUpdated, leaderboardVersion, duplicate: false
      };
    } catch (error) {
      await rollbackQuietly(client);
      throw error;
    } finally {
      client.release();
    }
  }

  async getLeaderboard(contestId: string, limit: number, nowIso: string): Promise<ContestLeaderboard> {
    await this.reconcile(nowIso);
    const contestResult = await this.pool.query<Row>("SELECT * FROM vs_public_contests WHERE contest_id = $1", [contestId]);
    const contest = contestResult.rows[0];
    if (!contest) throw new DurableCoreError("contest_not_found");
    const rows = await this.pool.query<Row>(
      `SELECT b.*, r.result_json, p.ordinal_place AS final_ordinal_place,
              p.competitive_place AS final_competitive_place
       FROM vs_public_contest_best_results b
       JOIN vs_public_contest_results r ON r.contest_result_id = b.contest_result_id
       LEFT JOIN vs_public_contest_placements p
         ON p.contest_id = b.contest_id AND p.player_id = b.player_id
       WHERE b.contest_id = $1
       ORDER BY b.competitive_primary DESC, b.competitive_secondary DESC,
                b.competitive_tertiary DESC, b.qualified_at ASC, b.player_id ASC
       LIMIT $2`, [contestId, Math.max(1, Math.min(100, limit))]
    );
    let priorScore = "";
    let competitivePlace = 0;
    const mapped: ContestLeaderboardRow[] = rows.rows.map((row, index) => {
      const score = `${row.competitive_primary}:${row.competitive_secondary}:${row.competitive_tertiary}`;
      if (score !== priorScore) competitivePlace = index + 1;
      priorScore = score;
      return {
        ordinalPlace: row.final_ordinal_place == null ? index + 1 : Number(row.final_ordinal_place),
        competitivePlace: row.final_competitive_place == null ? competitivePlace : Number(row.final_competitive_place),
        playerId: String(row.player_id), displayName: String(row.display_name),
        contestResultId: String(row.contest_result_id), qualifiedAt: isoValue(row.qualified_at),
        result: jsonRecord(row.result_json)
      };
    });
    return {
      leaderboardId: String(contest.leaderboard_id), contestId, definitionHash: String(contest.definition_hash),
      comparatorId: String(contest.comparator_id) as PublicContestDefinition["comparatorId"],
      status: String(contest.status) as PublicContestDefinition["status"],
      version: Number(contest.leaderboard_version), generatedAt: nowIso,
      source: "SERVER_PUBLIC_CONTEST_STORE", rows: mapped
    };
  }

  async listMessages(playerId: string, limit: number): Promise<ContestMessage[]> {
    const rows = await this.pool.query<Row>(
      `SELECT * FROM vs_outbox_events
       WHERE recipient_player_id = $1 AND topic = 'PUBLIC_CONTEST_RESULT_V1'
         AND status = 'PENDING' AND available_at <= now()
       ORDER BY available_at, event_id LIMIT $2`, [playerId, Math.max(1, Math.min(100, limit))]
    );
    return rows.rows.map(messageFromRow);
  }

  async acknowledgeMessage(eventId: string, playerId: string, deliveredAt: string): Promise<ContestMessage> {
    parseIso(deliveredAt, "invalid_delivered_at");
    const updated = await this.pool.query<Row>(
      `UPDATE vs_outbox_events SET status = 'DELIVERED', delivered_at = COALESCE(delivered_at, $3),
         delivery_attempts = CASE WHEN status = 'PENDING' THEN delivery_attempts + 1 ELSE delivery_attempts END
       WHERE event_id = $1 AND recipient_player_id = $2 AND topic = 'PUBLIC_CONTEST_RESULT_V1'
         AND status IN ('PENDING', 'DELIVERED') RETURNING *`, [eventId, playerId, deliveredAt]
    );
    if (!updated.rows[0]) throw new DurableCoreError("contest_message_not_found");
    return messageFromRow(updated.rows[0]);
  }

  async submitEvidence(input: { contestId: string; attemptId: string; playerId: string; submissionId: string;
    definitionHash: string; grantHash: string; evidence: JsonRecord; submittedAt: string }): Promise<ContestEvidence> {
    const submittedAt = parseIso(input.submittedAt, "invalid_submitted_at");
    if (!input.submissionId.trim() || input.submissionId.length > 256 || Object.keys(input.evidence).length === 0) {
      throw new DurableCoreError("invalid_contest_evidence");
    }
    await this.reconcile(input.submittedAt);
    const requestHash = sha256Canonical({ contest_id: input.contestId, attempt_id: input.attemptId,
      player_id: input.playerId, submission_id: input.submissionId, definition_hash: input.definitionHash,
      grant_hash: input.grantHash, evidence: input.evidence });
    const subject = `${input.contestId}:${input.attemptId}:${input.playerId}`;
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const claimed = await claimReceipt(client, "contest.evidence.v1", subject, input.submissionId, requestHash);
      if (!claimed) {
        const receipt = await readReceipt(client, "contest.evidence.v1", subject, input.submissionId, requestHash);
        const found = await client.query<Row>(
          "SELECT * FROM vs_public_contest_evidence WHERE evidence_id = $1", [stringValue(receipt.evidence_id)]
        );
        if (!found.rows[0]) throw new DurableCoreError("idempotency_receipt_corrupt");
        await client.query("COMMIT");
        return { ...evidenceFromRow(found.rows[0]), duplicate: true };
      }
      const found = await client.query<Row>(
        `SELECT a.*, c.status AS contest_status, c.ends_at,
                c.definition_hash AS contest_definition_hash
         FROM vs_public_contest_attempts a
         JOIN vs_public_contests c ON c.contest_id = a.contest_id
         WHERE a.attempt_id = $1 FOR UPDATE OF a, c`, [input.attemptId]
      );
      const row = found.rows[0];
      if (!row) throw new DurableCoreError("contest_attempt_not_found");
      if (String(row.contest_id) !== input.contestId || String(row.player_id) !== input.playerId) {
        throw new DurableCoreError("contest_attempt_identity_mismatch");
      }
      if (String(row.definition_hash) !== input.definitionHash
        || String(row.contest_definition_hash) !== input.definitionHash
        || String(row.grant_hash) !== input.grantHash) throw new DurableCoreError("contest_attempt_grant_mismatch");
      if (String(row.status) !== "ISSUED") throw new DurableCoreError("contest_attempt_already_committed");
      if (submittedAt > dateMs(row.submission_deadline_at) || submittedAt >= dateMs(row.ends_at)) {
        await client.query("UPDATE vs_public_contest_attempts SET status = 'EXPIRED' WHERE attempt_id = $1", [input.attemptId]);
        throw new DurableCoreError("contest_attempt_deadline_expired");
      }
      if (String(row.contest_status) !== "OPEN") throw new DurableCoreError("contest_not_open");
      const evidenceId = uuidV7(submittedAt);
      const envelope = { contest_schema_version: 1, definition_hash: input.definitionHash,
        grant_hash: input.grantHash, payload: deepClone(input.evidence) };
      const inserted = await client.query<Row>(
        `INSERT INTO vs_public_contest_evidence
          (evidence_id, contest_id, attempt_id, player_id, submission_id, request_hash,
           evidence_json, status, submitted_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, 'PENDING', $8, $8) RETURNING *`,
        [evidenceId, input.contestId, input.attemptId, input.playerId, input.submissionId,
          requestHash, JSON.stringify(envelope), input.submittedAt]
      );
      await completeReceipt(client, "contest.evidence.v1", subject, input.submissionId, requestHash,
        { evidence_id: evidenceId }, evidenceId);
      await client.query("COMMIT");
      return evidenceFromRow(inserted.rows[0]);
    } catch (error) {
      await rollbackQuietly(client);
      throw error;
    } finally {
      client.release();
    }
  }

  async getEvidence(evidenceId: string, playerId: string): Promise<ContestEvidence> {
    const found = await this.pool.query<Row>(
      "SELECT * FROM vs_public_contest_evidence WHERE evidence_id = $1 AND player_id = $2",
      [evidenceId, playerId]
    );
    if (!found.rows[0]) throw new DurableCoreError("contest_evidence_not_found");
    return evidenceFromRow(found.rows[0]);
  }

  async leaseNextEvidence(workerId: string, nowIso: string, leaseSec: number): Promise<ContestEvidenceLease | null> {
    const now = parseIso(nowIso, "invalid_server_time");
    if (!workerId.trim() || !Number.isSafeInteger(leaseSec) || leaseSec < 1) {
      throw new DurableCoreError("invalid_contest_evidence_lease");
    }
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `UPDATE vs_public_contest_evidence SET status = 'PENDING', worker_id = NULL,
           lease_token = NULL, lease_expires_at = NULL, updated_at = $1
         WHERE status = 'LEASED' AND lease_expires_at <= $1`, [nowIso]
      );
      const found = await client.query<Row>(
        `SELECT * FROM vs_public_contest_evidence WHERE status = 'PENDING'
         ORDER BY submitted_at, evidence_id FOR UPDATE SKIP LOCKED LIMIT 1`
      );
      if (!found.rows[0]) {
        await client.query("COMMIT");
        return null;
      }
      const leaseToken = uuidV7(now);
      const leaseExpiresAt = new Date(now + leaseSec * 1_000).toISOString();
      const updated = await client.query<Row>(
        `UPDATE vs_public_contest_evidence SET status = 'LEASED', worker_id = $2,
           lease_token = $3, lease_expires_at = $4, delivery_attempts = delivery_attempts + 1,
           updated_at = $1 WHERE evidence_id = $5 RETURNING *`,
        [nowIso, workerId, leaseToken, leaseExpiresAt, found.rows[0].evidence_id]
      );
      await client.query("COMMIT");
      return { ...evidenceFromRow(updated.rows[0]), workerId, leaseToken, leaseExpiresAt };
    } catch (error) {
      await rollbackQuietly(client);
      throw error;
    } finally {
      client.release();
    }
  }

  async resolveEvidence(evidenceId: string, workerId: string, leaseToken: string, resolvedAt: string,
    result: ContestResultReceipt | null, rejectionCode = ""): Promise<ContestEvidence> {
    parseIso(resolvedAt, "invalid_resolved_at");
    const status = result ? "VERIFIED" : "REJECTED";
    if (!result && !rejectionCode.trim()) throw new DurableCoreError("contest_evidence_rejection_required");
    const updated = await this.pool.query<Row>(
      `UPDATE vs_public_contest_evidence SET status = $4, contest_result_id = $5,
         rejection_code = $6, resolved_at = $7, updated_at = $7
       WHERE evidence_id = $1 AND status = 'LEASED' AND worker_id = $2 AND lease_token = $3
         AND lease_expires_at > $7 RETURNING *`,
      [evidenceId, workerId, leaseToken, status, result?.contestResultId ?? null,
        result ? null : rejectionCode.trim(), resolvedAt]
    );
    if (!updated.rows[0]) throw new DurableCoreError("contest_evidence_lease_conflict");
    return evidenceFromRow(updated.rows[0]);
  }
}

async function closeContest(client: PoolClient, contest: Row, nowIso: string): Promise<boolean> {
  await client.query(
    "UPDATE vs_public_contests SET status = 'FINALIZING', updated_at = $2 WHERE contest_id = $1",
    [contest.contest_id, nowIso]
  );
  const unresolved = await client.query(
    `SELECT 1 FROM vs_public_contest_evidence
     WHERE contest_id = $1 AND status IN ('PENDING', 'LEASED') LIMIT 1`, [contest.contest_id]
  );
  if ((unresolved.rowCount ?? 0) > 0) return false;
  const best = await client.query<Row>(
    `SELECT * FROM vs_public_contest_best_results WHERE contest_id = $1
     ORDER BY competitive_primary DESC, competitive_secondary DESC, competitive_tertiary DESC,
              qualified_at ASC, player_id ASC`, [contest.contest_id]
  );
  let priorScore = "";
  let competitivePlace = 0;
  for (let index = 0; index < best.rows.length; index += 1) {
    const row = best.rows[index];
    const score = `${row.competitive_primary}:${row.competitive_secondary}:${row.competitive_tertiary}`;
    if (score !== priorScore) competitivePlace = index + 1;
    priorScore = score;
    await client.query(
      `INSERT INTO vs_public_contest_placements
        (contest_id, player_id, contest_result_id, ordinal_place, competitive_place, placed_at)
       VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (contest_id, player_id) DO NOTHING`,
      [contest.contest_id, row.player_id, row.contest_result_id, index + 1, competitivePlace, nowIso]
    );
    if (index < 3) {
      const payload = {
        message_schema_version: 1, message_kind: "PUBLIC_CONTEST_PLACEMENT",
        contest_id: String(contest.contest_id), leaderboard_id: String(contest.leaderboard_id),
        definition_hash: String(contest.definition_hash), ordinal_place: index + 1,
        competitive_place: competitivePlace, contest_result_id: String(row.contest_result_id),
        closed_at: nowIso
      };
      const dedupeKey = `${contest.contest_id}:${row.player_id}:placement`;
      await client.query(
        `INSERT INTO vs_outbox_events
          (event_id, topic, recipient_player_id, aggregate_type, aggregate_id,
           dedupe_namespace, dedupe_key, request_hash, payload, available_at)
         VALUES ($1, 'PUBLIC_CONTEST_RESULT_V1', $2, 'PUBLIC_CONTEST', $3,
           'contest.message.v1', $4, $5, $6::jsonb, $7)
         ON CONFLICT (dedupe_namespace, dedupe_key) DO NOTHING`,
        [uuidV7(dateMs(nowIso) + index), row.player_id, contest.contest_id, dedupeKey,
          sha256Canonical(payload), JSON.stringify(payload), nowIso]
      );
    }
  }
  await client.query(
    "UPDATE vs_public_contests SET status = 'CLOSED', closed_at = $2, updated_at = $2 WHERE contest_id = $1",
    [contest.contest_id, nowIso]
  );
  return true;
}

async function cloneNextGeneration(client: PoolClient, row: Row, intervalSec: number, nowIso: string): Promise<boolean> {
  const generation = Number(row.generation) + 1;
  const exists = await client.query(
    "SELECT 1 FROM vs_public_contests WHERE series_key = $1 AND generation = $2", [row.series_key, generation]
  );
  if ((exists.rowCount ?? 0) > 0) return false;
  const startsAt = new Date(dateMs(row.starts_at) + intervalSec * 1_000).toISOString();
  const endsAt = new Date(dateMs(row.ends_at) + intervalSec * 1_000).toISOString();
  const contestId = uuidV7(dateMs(nowIso));
  const leaderboardId = uuidV7(dateMs(nowIso));
  const original = jsonRecord(row.definition_json);
  const document: JsonRecord = {
    ...original, contest_id: contestId, leaderboard_id: leaderboardId, generation,
    starts_at: startsAt, ends_at: endsAt
  };
  const now = dateMs(nowIso);
  const status = now < dateMs(startsAt) ? "SCHEDULED" : now < dateMs(endsAt) ? "OPEN" : "SCHEDULED";
  await client.query(
    `INSERT INTO vs_public_contests
      (contest_id, leaderboard_id, contest_schema_version, series_key, generation, family, scope,
       map_count, status, map_pack_id, map_ids, content_hashes, sim_build_id, comparator_id,
       best_entry_policy, attempt_policy, closure_policy, eligibility_policy, starts_at, ends_at,
       created_at, opened_at, definition_hash, definition_json)
     VALUES ($1, $2, 1, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11::jsonb, $12, $13,
       $14, $15::jsonb, $16::jsonb, $17::jsonb, $18, $19, $20, $21, $22, $23::jsonb)`,
    [contestId, leaderboardId, row.series_key, generation, row.family, row.scope, row.map_count,
      status, row.map_pack_id, JSON.stringify(stringArray(row.map_ids)), JSON.stringify(jsonRecord(row.content_hashes)),
      row.sim_build_id, row.comparator_id, row.best_entry_policy, JSON.stringify(jsonRecord(row.attempt_policy)),
      JSON.stringify(jsonRecord(row.closure_policy)), JSON.stringify(jsonRecord(row.eligibility_policy)),
      startsAt, endsAt, nowIso, status === "OPEN" ? nowIso : null, sha256Canonical(document), JSON.stringify(document)]
  );
  return true;
}

function definitionFromRow(row: Row): PublicContestDefinition {
  return {
    contestId: String(row.contest_id), leaderboardId: String(row.leaderboard_id), contestSchemaVersion: 1,
    seriesKey: String(row.series_key), generation: Number(row.generation),
    family: String(row.family) as PublicContestDefinition["family"],
    scope: String(row.scope) as PublicContestDefinition["scope"], mapCount: Number(row.map_count),
    status: String(row.status) as PublicContestDefinition["status"], mapPackId: String(row.map_pack_id),
    mapIds: stringArray(row.map_ids), contentHashes: jsonRecord(row.content_hashes),
    simBuildId: String(row.sim_build_id),
    comparatorId: String(row.comparator_id) as PublicContestDefinition["comparatorId"],
    bestEntryPolicy: String(row.best_entry_policy) as PublicContestDefinition["bestEntryPolicy"],
    attemptPolicy: jsonRecord(row.attempt_policy), closurePolicy: jsonRecord(row.closure_policy),
    eligibilityPolicy: jsonRecord(row.eligibility_policy), startsAt: isoValue(row.starts_at),
    endsAt: isoValue(row.ends_at), createdAt: isoValue(row.created_at),
    openedAt: row.opened_at == null ? null : isoValue(row.opened_at),
    closedAt: row.closed_at == null ? null : isoValue(row.closed_at),
    definitionHash: String(row.definition_hash), leaderboardVersion: Number(row.leaderboard_version)
  };
}

async function readAttempt(client: PoolClient, attemptId: string): Promise<ContestAttempt | null> {
  const found = await client.query<Row>("SELECT * FROM vs_public_contest_attempts WHERE attempt_id = $1", [attemptId]);
  const row = found.rows[0];
  return row ? {
    attemptId: String(row.attempt_id), contestId: String(row.contest_id), playerId: String(row.player_id),
    attemptNumber: Number(row.attempt_number), definitionHash: String(row.definition_hash), seed: String(row.seed),
    issuedAt: isoValue(row.issued_at), submissionDeadlineAt: isoValue(row.submission_deadline_at),
    grantHash: String(row.grant_hash), status: String(row.status) as ContestAttempt["status"]
  } : null;
}

async function readResult(client: PoolClient, resultId: string): Promise<Omit<ContestResultReceipt,
  "bestUpdated" | "leaderboardVersion" | "duplicate"> | null> {
  const found = await client.query<Row>("SELECT * FROM vs_public_contest_results WHERE contest_result_id = $1", [resultId]);
  const row = found.rows[0];
  return row ? {
    contestResultId: String(row.contest_result_id), contestId: String(row.contest_id),
    attemptId: String(row.attempt_id), playerId: String(row.player_id), result: jsonRecord(row.result_json),
    qualifiedAt: isoValue(row.qualified_at)
  } : null;
}

async function claimReceipt(client: PoolClient, namespace: string, subject: string, key: string, hash: string): Promise<boolean> {
  const result = await client.query(
    `INSERT INTO vs_idempotency_receipts
      (namespace, authoritative_subject, idempotency_key, request_hash, status)
     VALUES ($1, $2, $3, $4, 'PENDING') ON CONFLICT DO NOTHING RETURNING idempotency_key`,
    [namespace, subject, key, hash]
  );
  return (result.rowCount ?? 0) > 0;
}

async function readReceipt(client: PoolClient, namespace: string, subject: string, key: string, hash: string): Promise<JsonRecord> {
  const found = await client.query<Row>(
    `SELECT request_hash, status, response_json FROM vs_idempotency_receipts
     WHERE namespace = $1 AND authoritative_subject = $2 AND idempotency_key = $3 FOR UPDATE`,
    [namespace, subject, key]
  );
  const row = found.rows[0];
  if (!row || String(row.request_hash) !== hash) throw new DurableCoreError("idempotency_conflict");
  if (String(row.status) !== "COMPLETED") throw new DurableCoreError("idempotency_in_progress");
  return jsonRecord(row.response_json);
}

async function completeReceipt(client: PoolClient, namespace: string, subject: string, key: string, hash: string,
  response: JsonRecord, sideEffectRef: string): Promise<void> {
  await client.query(
    `UPDATE vs_idempotency_receipts SET status = 'COMPLETED', response_json = $5::jsonb,
       side_effect_ref = $6, updated_at = now()
     WHERE namespace = $1 AND authoritative_subject = $2 AND idempotency_key = $3 AND request_hash = $4`,
    [namespace, subject, key, hash, JSON.stringify(response), sideEffectRef]
  );
}

function messageFromRow(row: Row): ContestMessage {
  return {
    eventId: String(row.event_id), contestId: String(row.aggregate_id),
    status: String(row.status) as ContestMessage["status"], payload: jsonRecord(row.payload),
    availableAt: isoValue(row.available_at), deliveredAt: row.delivered_at == null ? null : isoValue(row.delivered_at)
  };
}

function evidenceFromRow(row: Row): ContestEvidence {
  return {
    evidenceId: String(row.evidence_id), contestId: String(row.contest_id),
    attemptId: String(row.attempt_id), playerId: String(row.player_id),
    submissionId: String(row.submission_id), evidence: jsonRecord(row.evidence_json),
    status: String(row.status) as ContestEvidence["status"], submittedAt: isoValue(row.submitted_at),
    contestResultId: row.contest_result_id == null ? null : String(row.contest_result_id),
    rejectionCode: row.rejection_code == null ? null : String(row.rejection_code), duplicate: false
  };
}

function jsonRecord(value: unknown): JsonRecord {
  if (typeof value === "string") {
    try { return jsonRecord(JSON.parse(value) as unknown); } catch { return {}; }
  }
  return typeof value === "object" && value != null && !Array.isArray(value) ? deepClone(value as JsonRecord) : {};
}

function stringArray(value: unknown): string[] {
  if (typeof value === "string") {
    try { return stringArray(JSON.parse(value) as unknown); } catch { return []; }
  }
  return Array.isArray(value) ? value.map(String) : [];
}

function stringValue(value: unknown): string { return typeof value === "string" ? value : ""; }
function integerOrZero(value: unknown): number { return typeof value === "number" && Number.isSafeInteger(value) ? value : 0; }
function isoValue(value: unknown): string { return new Date(value as string | number | Date).toISOString(); }
function dateMs(value: unknown): number { return new Date(value as string | number | Date).getTime(); }
function isUniqueViolation(error: unknown): boolean {
  return typeof error === "object" && error != null && "code" in error && (error as { code?: string }).code === "23505";
}
async function rollbackQuietly(client: PoolClient): Promise<void> {
  try { await client.query("ROLLBACK"); } catch { /* preserve the original failure */ }
}
