import type { Pool } from "pg";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { runMigrations } from "../db/migrate.js";
import { buildAsyncCohortInputs } from "../publicAsyncCohorts.js";
import { DurableCoreError, uuidV7, type JsonRecord } from "./durableCore.js";
import { PGlitePoolAdapter } from "./pglitePoolAdapter.js";
import { PostgresPublicContestRepository } from "./postgresPublicContestRepository.js";
import type { ContestAttempt } from "./publicContest.js";

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
function metrics(mapIds: string[], base: number): JsonRecord {
  const perMap = mapIds.map((map_id, index) => ({ map_id, completed: true, elapsed_ticks: base + index, penalty_ticks: 0 }));
  return { per_map: perMap, aggregate_elapsed_ticks: perMap.reduce((sum, row) => sum + row.elapsed_ticks, 0) };
}

async function main(): Promise<void> {
  const db = new PGlite({ extensions: { pgcrypto } }); await db.waitReady;
  const pool = new PGlitePoolAdapter(db) as unknown as Pool;
  await runMigrations(pool);
  const repository = new PostgresPublicContestRepository(pool);
  const start = "2026-07-19T20:00:00.000Z";
  const definitions = buildAsyncCohortInputs({ sim_build_id: "async-smoke-v1", rules_hash: "a".repeat(64),
    simulation_hash: "b".repeat(64), starts_at: start, ends_at: "2026-07-26T20:00:00.000Z",
    shared: { submission_window_sec: 86_400, max_attempts_per_player: 3, cohort_window_sec: 604_800 },
    catalog: {
      three_map: { pack_id: "async-three-v1", pack_hash: "3".repeat(64), maps: [
        { map_id: "three-a", sha256: "1".repeat(64) }, { map_id: "three-b", sha256: "2".repeat(64) },
        { map_id: "three-c", sha256: "3".repeat(64) }] },
      five_map: { pack_id: "async-five-v1", pack_hash: "5".repeat(64), maps: [
        { map_id: "five-a", sha256: "4".repeat(64) }, { map_id: "five-b", sha256: "5".repeat(64) },
        { map_id: "five-c", sha256: "6".repeat(64) }, { map_id: "five-d", sha256: "7".repeat(64) },
        { map_id: "five-e", sha256: "8".repeat(64) }] }
    }
  }, start);
  const three = await repository.publish(definitions[0]);
  const five = await repository.publish(definitions[1]);
  expect(three.mapCount === 3 && five.mapCount === 5 && three.definitionHash !== five.definitionHash,
    "3/5 cohort families not separated", { three, five });
  const players = [uuidV7(), uuidV7(), uuidV7(), uuidV7()];
  const attempts: ContestAttempt[] = [];
  for (let index = 0; index < players.length; index += 1) {
    attempts.push((await repository.enter({ contestId: three.contestId, playerId: players[index],
      displayName: `Real Player ${index + 1}`, publicEntapId: `ENTAP-${index + 1}`,
      requestId: `three-enter-${index}`, nowIso: start, grantSecret: "async-cohort-smoke-secret-at-least-32-characters" })).attempt);
  }
  await expectCode(repository.enter({ contestId: three.contestId, playerId: uuidV7(), displayName: "Fifth Player",
    publicEntapId: "ENTAP-5", requestId: "three-enter-fifth", nowIso: start,
    grantSecret: "async-cohort-smoke-secret-at-least-32-characters" }), "contest_cohort_roster_locked");
  const retryA = (await repository.enter({ contestId: three.contestId, playerId: players[0], displayName: "Ignored Rename",
    publicEntapId: "FORGED-RENAME", requestId: "three-enter-a-retry", nowIso: start,
    grantSecret: "async-cohort-smoke-secret-at-least-32-characters" })).attempt;
  const commit = (attempt: typeof attempts[number], index: number, base: number, suffix = "") => repository.commitTrustedResult({
    contestId: three.contestId, attemptId: attempt.attemptId, playerId: players[index],
    submissionId: `three-result-${index}${suffix}`, definitionHash: three.definitionHash,
    grantHash: attempt.grantHash, verificationMethod: "SERVER_SIM_V1", evidenceRef: `evidence://three/${index}${suffix}`,
    metrics: metrics(three.mapIds, base), qualifiedAt: new Date(Date.parse(start) + 1_000 + index).toISOString()
  });
  const bestA = await commit(attempts[0], 0, 100);
  const worseA = await commit(retryA, 0, 500, "-worse");
  expect(bestA.bestUpdated && !worseA.bestUpdated, "worse retry replaced the best row", { bestA, worseA });
  await commit(attempts[1], 1, 200);
  await commit(attempts[2], 2, 300);
  const fourth = await commit(attempts[3], 3, 400);
  expect(fourth.bestUpdated, "fourth distinct qualified result was rejected", fourth);
  const closed = await repository.getDefinition(three.contestId);
  expect(closed.status === "CLOSED", "fourth qualified result did not atomically close cohort", closed);
  const board = await new PostgresPublicContestRepository(pool).getLeaderboard(three.contestId, 10,
    new Date(Date.parse(start) + 10_000).toISOString());
  expect(board.rows.length === 4 && board.rows[0].playerId === players[0]
    && board.rows.filter((row) => row.playerId === players[0]).length === 1,
  "closed snapshot/best-player ranking incorrect", board);
  const roster = await repository.getRoster(three.contestId);
  const rosterA = roster.find((entry) => entry.playerId === players[0]);
  expect(roster.length === 4 && rosterA?.displayName === "Real Player 1" && rosterA.publicEntapId === "ENTAP-1",
    "locked roster identity mutated", roster);
  const allMessages = [];
  for (const player of players) allMessages.push(...await new PostgresPublicContestRepository(pool).listMessages(player, 10));
  expect(allMessages.length === 4 && allMessages.filter((message) => message.payload.top_three === true).length === 3
    && allMessages.every((message) => Array.isArray(message.payload.payouts) && (message.payload.payouts as unknown[]).length === 0),
  "placement outbox did not message all four without payouts", allMessages);
  const counts = await pool.query<Record<string, unknown>>(
    `SELECT
      (SELECT count(*)::int FROM vs_public_contest_cohorts WHERE contest_id = $1 AND finalized_at IS NOT NULL) AS closures,
      (SELECT count(*)::int FROM vs_public_contest_placements WHERE contest_id = $1) AS placements,
      (SELECT count(*)::int FROM vs_outbox_events WHERE aggregate_id = $1::text) AS messages,
      (SELECT count(*)::int FROM vs_public_contest_cohorts c JOIN vs_public_contests p ON p.contest_id = c.contest_id
        WHERE p.series_key = $2 AND p.generation = 2 AND p.status = 'OPEN') AS next_generation`,
    [three.contestId, three.seriesKey]
  );
  expect(Number(counts.rows[0]?.closures) === 1 && Number(counts.rows[0]?.placements) === 4
    && Number(counts.rows[0]?.messages) === 4 && Number(counts.rows[0]?.next_generation) === 1,
  "cohort closure was not singular/recoverable/rolling", counts.rows[0]);

  const fiveAttempt = (await repository.enter({ contestId: five.contestId, playerId: players[0], displayName: "Real Player 1",
    publicEntapId: "ENTAP-1", requestId: "five-enter-a", nowIso: start,
    grantSecret: "async-cohort-smoke-secret-at-least-32-characters" })).attempt;
  await expectCode(repository.commitTrustedResult({ contestId: five.contestId, attemptId: attempts[0].attemptId,
    playerId: players[0], submissionId: "cross-family", definitionHash: five.definitionHash,
    grantHash: fiveAttempt.grantHash, verificationMethod: "SERVER_SIM_V1", evidenceRef: "evidence://cross",
    metrics: metrics(five.mapIds, 100), qualifiedAt: new Date(Date.parse(start) + 20_000).toISOString() }),
  "contest_attempt_identity_mismatch");
  expect((await repository.getRoster(five.contestId)).length === 1
    && (await repository.getLeaderboard(five.contestId, 10, start)).rows.length === 0,
  "3-map result contaminated 5-map cohort");
  const fiveAttempts: ContestAttempt[] = [fiveAttempt];
  for (let index = 1; index < players.length; index += 1) {
    fiveAttempts.push((await repository.enter({ contestId: five.contestId, playerId: players[index],
      displayName: `Real Player ${index + 1}`, publicEntapId: `ENTAP-${index + 1}`,
      requestId: `five-enter-${index}`, nowIso: start,
      grantSecret: "async-cohort-smoke-secret-at-least-32-characters" })).attempt);
    await repository.commitTrustedResult({ contestId: five.contestId, attemptId: fiveAttempts[index].attemptId,
      playerId: players[index], submissionId: `five-result-${index}`, definitionHash: five.definitionHash,
      grantHash: fiveAttempts[index].grantHash, verificationMethod: "SERVER_SIM_V1", evidenceRef: `evidence://five/${index}`,
      metrics: metrics(five.mapIds, 100 + index * 100),
      qualifiedAt: new Date(Date.parse(start) + 30_000 + index).toISOString() });
  }
  const reconciled = await repository.reconcile("2026-07-27T20:00:00.000Z");
  const dnfRows = await pool.query<Record<string, unknown>>(
    "SELECT payload FROM vs_outbox_events WHERE aggregate_id = $1 AND recipient_player_id = $2",
    [five.contestId, players[0]]);
  const dnfMessages = dnfRows.rows.map((row) => typeof row.payload === "string" ? JSON.parse(row.payload) as JsonRecord : row.payload as JsonRecord);
  expect(reconciled.closed >= 1 && dnfMessages.some((message) => message.message_kind === "PUBLIC_CONTEST_DNF"
    && message.qualified === false),
  "deadline DNF did not close/message the locked roster", { reconciled, dnfMessages });
  await db.close();
  console.log("PUBLIC_ASYNC_COHORT_EMBEDDED_SMOKE: PASS");
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
