import type { Pool } from "pg";
import { readFileSync } from "node:fs";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { runMigrations } from "../db/migrate.js";
import { DurableCoreError, uuidV7, type JsonRecord } from "./durableCore.js";
import { scoreVerifiedResult, type PublishContestInput } from "./publicContest.js";
import { PGlitePoolAdapter } from "./pglitePoolAdapter.js";
import { PostgresPublicContestRepository } from "./postgresPublicContestRepository.js";
import { buildTimeGauntletPeriodInputs } from "../publicContestPeriods.js";

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

async function expectCode(promise: Promise<unknown>, code: string): Promise<void> {
  try { await promise; } catch (error) {
    expect(error instanceof DurableCoreError && error.code === code, `expected ${code}`,
      error instanceof Error ? error.message : error);
    return;
  }
  throw new Error(`expected ${code}`);
}

function definition(createdAt: string, startsAt: string, endsAt: string): PublishContestInput {
  return {
    seriesKey: "time-weekly-3-smoke", generation: 1, family: "TIME_PUZZLE", scope: "WEEKLY",
    mapCount: 3, mapPackId: "smoke-pack-3", mapIds: ["map-a", "map-b", "map-c"],
    contentHashes: { map_pack: "1".repeat(64), rules: "2".repeat(64), simulation: "3".repeat(64) },
    simBuildId: "contest-platform-smoke-v1", comparatorId: "TIME_TOTAL_V1",
    bestEntryPolicy: "BEST_PER_PLAYER", attemptPolicy: { submission_window_sec: 90 },
    closurePolicy: { kind: "SERVER_TIME", rollover_interval_sec: 120 },
    eligibilityPolicy: { authentication_required: true, authority_required: true },
    startsAt, endsAt, createdAt
  };
}

function timeMetrics(a: number, b: number, c: number): JsonRecord {
  return {
    per_map: [
      { map_id: "map-a", completed: true, elapsed_ticks: a, penalty_ticks: 0 },
      { map_id: "map-b", completed: true, elapsed_ticks: b, penalty_ticks: 0 },
      { map_id: "map-c", completed: true, elapsed_ticks: c, penalty_ticks: 0 }
    ],
    aggregate_elapsed_ticks: a + b + c
  };
}

async function main(): Promise<void> {
  const golden = JSON.parse(readFileSync(new URL("../../../../data/public_contests/comparator_golden_v1.json",
    import.meta.url), "utf8")) as { cases: Array<Record<string, unknown>> };
  for (const fixture of golden.cases) {
    const expected = fixture.expected as JsonRecord;
    const score = scoreVerifiedResult(String(fixture.comparator_id) as "TIME_TOTAL_V1" | "GAUNTLET_STARS_V1",
      fixture.map_ids as string[], fixture.metrics as JsonRecord, fixture.attempt_policy as JsonRecord);
    expect(score.primary === expected.primary && score.secondary === expected.secondary
      && score.tertiary === expected.tertiary, `comparator fixture failed: ${fixture.id}`, score);
    for (const key of ["aggregate_elapsed_ticks", "stars", "completed_stage_count", "elapsed_ticks"]) {
      if (expected[key] != null) expect(score.result[key] === expected[key], `fixture result failed: ${fixture.id}:${key}`, score);
    }
  }
  const catalogMap = (map_id: string, value: string) => ({ map_id, sha256: value.repeat(64) });
  const threeMaps = [catalogMap("map-a", "a"), catalogMap("map-b", "b"), catalogMap("map-c", "c")];
  const fiveMaps = [...threeMaps, catalogMap("map-d", "d"), catalogMap("map-a", "a")];
  const stages = Array.from({ length: 18 }, (_, index) => ({ stage_number: index + 1,
    map_id: `stage-${index + 1}`, map_sha256: ((index % 9) + 1).toString().repeat(64),
    thresholds_ms: { four_star_ms: 10_000, three_star_ms: 20_000, two_star_ms: 30_000 } }));
  const periodInputs = buildTimeGauntletPeriodInputs({ sim_build_id: "contest-sim-v1",
    catalog: { schema: "swarmfront.public_contest_catalog.v1",
      time_puzzle: { three_map: { pack_id: "three", pack_hash: "3".repeat(64), maps: threeMaps },
        five_map: { pack_id: "five", pack_hash: "5".repeat(64), maps: fiveMaps } },
      gauntlet: { plan_id: "gauntlet", plan_hash: "6".repeat(64), stage_count: 18, stages } },
    periods: { weekly: { generation: 1, starts_at: "2026-07-13T00:00:00.000Z", ends_at: "2026-07-20T00:00:00.000Z" },
      monthly: { generation: 7, starts_at: "2026-07-01T00:00:00.000Z", ends_at: "2026-08-01T00:00:00.000Z" },
      seasonal: { generation: 2, starts_at: "2026-07-01T00:00:00.000Z", ends_at: "2026-10-01T00:00:00.000Z" } }
  }, "2026-07-19T18:00:00.000Z");
  expect(periodInputs.length === 7 && periodInputs.filter((value) => value.family === "TIME_PUZZLE").length === 6
    && periodInputs.find((value) => value.family === "GAUNTLET")?.attemptPolicy.stage_plan_hash === "6".repeat(64)
    && periodInputs.every((value) => value.closurePolicy.rollover_interval_sec == null),
  "period publisher did not freeze separate time/gauntlet definitions", periodInputs);
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.waitReady;
  const pool = new PGlitePoolAdapter(db) as unknown as Pool;
  await runMigrations(pool);
  const deviceA = new PostgresPublicContestRepository(pool);
  const deviceB = new PostgresPublicContestRepository(pool);
  const base = Date.parse("2026-07-19T18:00:00.000Z");
  const at = (offsetMs: number) => new Date(base + offsetMs).toISOString();
  const published = await deviceA.publish(definition(at(0), at(-1_000), at(120_000)));
  expect(published.status === "OPEN" && published.leaderboardVersion === 0, "contest did not publish open", published);
  const playerA = uuidV7(base);
  const playerB = uuidV7(base + 1);
  const grantSecret = "contest-smoke-secret-is-at-least-thirty-two-characters";

  const firstA = await deviceA.enter({ contestId: published.contestId, playerId: playerA,
    displayName: "Device A", requestId: "attempt-a-1", nowIso: at(1_000), grantSecret });
  const duplicateA = await deviceB.enter({ contestId: published.contestId, playerId: playerA,
    displayName: "Device A", requestId: "attempt-a-1", nowIso: at(2_000), grantSecret });
  expect(duplicateA.duplicate && duplicateA.attempt.attemptId === firstA.attempt.attemptId,
    "attempt receipt was not shared across devices", duplicateA);
  await expectCode(deviceA.enter({ contestId: published.contestId, playerId: playerA,
    displayName: "Changed identity body", requestId: "attempt-a-1", nowIso: at(2_000), grantSecret }),
  "idempotency_conflict");

  const firstResult = await deviceA.commitTrustedResult({
    contestId: published.contestId, attemptId: firstA.attempt.attemptId, playerId: playerA,
    submissionId: "result-a-1", definitionHash: published.definitionHash,
    grantHash: firstA.attempt.grantHash, verificationMethod: "SERVER_SIM_V1",
    evidenceRef: "evidence://a/1", metrics: timeMetrics(100, 100, 100), qualifiedAt: at(10_000)
  });
  const duplicateResult = await deviceB.commitTrustedResult({
    contestId: published.contestId, attemptId: firstA.attempt.attemptId, playerId: playerA,
    submissionId: "result-a-1", definitionHash: published.definitionHash,
    grantHash: firstA.attempt.grantHash, verificationMethod: "SERVER_SIM_V1",
    evidenceRef: "evidence://a/1", metrics: timeMetrics(100, 100, 100), qualifiedAt: at(11_000)
  });
  expect(firstResult.bestUpdated && firstResult.leaderboardVersion === 1 && duplicateResult.duplicate,
    "result receipt was not idempotent", { firstResult, duplicateResult });

  const worseAttempt = await deviceA.enter({ contestId: published.contestId, playerId: playerA,
    displayName: "Device A", requestId: "attempt-a-2", nowIso: at(20_000), grantSecret });
  const worse = await deviceA.commitTrustedResult({
    contestId: published.contestId, attemptId: worseAttempt.attempt.attemptId, playerId: playerA,
    submissionId: "result-a-2", definitionHash: published.definitionHash,
    grantHash: worseAttempt.attempt.grantHash, verificationMethod: "SERVER_SIM_V1",
    evidenceRef: "evidence://a/2", metrics: timeMetrics(150, 150, 150), qualifiedAt: at(25_000)
  });
  expect(!worse.bestUpdated && worse.leaderboardVersion === 1, "worse result replaced the best row", worse);

  const firstB = await deviceB.enter({ contestId: published.contestId, playerId: playerB,
    displayName: "Device B", requestId: "attempt-b-1", nowIso: at(30_000), grantSecret });
  await deviceB.commitTrustedResult({
    contestId: published.contestId, attemptId: firstB.attempt.attemptId, playerId: playerB,
    submissionId: "result-b-1", definitionHash: published.definitionHash,
    grantHash: firstB.attempt.grantHash, verificationMethod: "SIGNED_REPLAY_V1",
    evidenceRef: "evidence://b/1", metrics: timeMetrics(80, 80, 80), qualifiedAt: at(35_000)
  });
  const boardA = await deviceA.getLeaderboard(published.contestId, 10, at(40_000));
  const boardB = await deviceB.getLeaderboard(published.contestId, 10, at(40_000));
  expect(JSON.stringify(boardA) === JSON.stringify(boardB), "two devices received different boards", { boardA, boardB });
  expect(boardA.version === 2 && boardA.rows.length === 2 && boardA.rows[0].playerId === playerB
    && boardA.rows[1].result.aggregate_elapsed_ticks === 300,
  "best-per-player projection or ordering failed", boardA);
  expect(boardA.source === "SERVER_PUBLIC_CONTEST_STORE"
    && !JSON.stringify(boardA).includes("user://") && !JSON.stringify(boardA).includes(".tres"),
  "local fixture provenance entered the public response", boardA);

  const restarted = new PostgresPublicContestRepository(pool);
  const restored = await restarted.getLeaderboard(published.contestId, 10, at(50_000));
  const roster = await restarted.getRoster(published.contestId);
  expect(restored.version === 2 && roster.length === 2, "restart lost board or roster", { restored, roster });
  const roll = await restarted.reconcile(at(121_000));
  expect(roll.closed === 1 && roll.rolled === 1, "server-time close/roll did not execute", roll);
  const historical = await restarted.getLeaderboard(published.contestId, 10, at(121_000));
  const current = await restarted.listCurrent({ family: "TIME_PUZZLE", scope: "WEEKLY", mapCount: 3 }, at(121_000));
  expect(historical.status === "CLOSED" && historical.rows[0].ordinalPlace === 1
    && current.length === 1 && current[0].generation === 2 && current[0].status === "OPEN",
  "rollover lost history or failed to open the next generation", { historical, current });
  await expectCode(restarted.enter({ contestId: published.contestId, playerId: uuidV7(base + 2),
    displayName: "Late", requestId: "late", nowIso: at(121_000), grantSecret }), "contest_not_open");

  const messages = await restarted.listMessages(playerB, 10);
  expect(messages.length === 1 && messages[0].payload.ordinal_place === 1,
    "winner placement message missing", messages);
  const acknowledged = await restarted.acknowledgeMessage(messages[0].eventId, playerB, at(122_000));
  const acknowledgedAgain = await restarted.acknowledgeMessage(messages[0].eventId, playerB, at(123_000));
  expect(acknowledged.status === "DELIVERED" && acknowledgedAgain.deliveredAt === acknowledged.deliveredAt,
    "message acknowledgement was not idempotent", { acknowledged, acknowledgedAgain });

  const playerC = uuidV7(base + 3);
  const nextContest = current[0];
  const attemptC = await restarted.enter({ contestId: nextContest.contestId, playerId: playerC,
    displayName: "Evidence Player", requestId: "attempt-c-1", nowIso: at(200_000), grantSecret });
  const evidenceC = await restarted.submitEvidence({ contestId: nextContest.contestId,
    attemptId: attemptC.attempt.attemptId, playerId: playerC, submissionId: "evidence-c-1",
    definitionHash: nextContest.definitionHash, grantHash: attemptC.attempt.grantHash,
    evidence: { schema: "swarmfront.time_puzzle_evidence.v1", command_log_hash: "c".repeat(64) },
    submittedAt: at(230_000) });
  const duplicateEvidence = await deviceB.submitEvidence({ contestId: nextContest.contestId,
    attemptId: attemptC.attempt.attemptId, playerId: playerC, submissionId: "evidence-c-1",
    definitionHash: nextContest.definitionHash, grantHash: attemptC.attempt.grantHash,
    evidence: { schema: "swarmfront.time_puzzle_evidence.v1", command_log_hash: "c".repeat(64) },
    submittedAt: at(230_500) });
  expect(duplicateEvidence.duplicate && duplicateEvidence.evidenceId === evidenceC.evidenceId,
    "evidence receipt was not idempotent", duplicateEvidence);
  const lease = await restarted.leaseNextEvidence("contest-worker-1", at(231_000), 30);
  expect(lease?.evidenceId === evidenceC.evidenceId && lease.status === "LEASED", "evidence was not leased", lease);
  const heldForEvidence = await restarted.reconcile(at(241_000));
  expect(heldForEvidence.closed === 0
    && (await restarted.getDefinition(nextContest.contestId)).status === "FINALIZING",
  "period closed before pre-deadline evidence verification completed", heldForEvidence);
  const verifiedC = await restarted.commitTrustedResult({ contestId: nextContest.contestId,
    attemptId: attemptC.attempt.attemptId, playerId: playerC, submissionId: `verified:${evidenceC.evidenceId}`,
    definitionHash: nextContest.definitionHash, grantHash: attemptC.attempt.grantHash,
    verificationMethod: "SERVER_SIM_V1", evidenceRef: evidenceC.evidenceId,
    metrics: timeMetrics(70, 70, 70), qualifiedAt: evidenceC.submittedAt });
  const resolvedC = await restarted.resolveEvidence(evidenceC.evidenceId, "contest-worker-1",
    lease?.leaseToken ?? "", at(242_000), verifiedC);
  expect(resolvedC.status === "VERIFIED" && resolvedC.contestResultId === verifiedC.contestResultId,
    "evidence did not resolve to a trusted result", resolvedC);
  const finalizedAfterEvidence = await restarted.reconcile(at(243_000));
  const nextBoard = await restarted.getLeaderboard(nextContest.contestId, 10, at(244_000));
  expect(finalizedAfterEvidence.closed === 1 && nextBoard.status === "CLOSED" && nextBoard.rows.length === 1,
    "verified evidence did not finalize exactly one public row", { finalizedAfterEvidence, nextBoard });

  const gauntletA = scoreVerifiedResult("GAUNTLET_STARS_V1", ["stage-plan"],
    { stars: 18, completed_stage_count: 12, elapsed_ticks: 500 });
  const gauntletB = scoreVerifiedResult("GAUNTLET_STARS_V1", ["stage-plan"],
    { stars: 18, completed_stage_count: 12, elapsed_ticks: 450 });
  expect(gauntletB.tertiary > gauntletA.tertiary, "gauntlet comparator did not prefer lower time");

  const counts = await pool.query<Record<string, unknown>>(
    `SELECT
       (SELECT count(*)::int FROM vs_public_contests) AS contests,
       (SELECT count(*)::int FROM vs_public_contest_roster) AS roster,
       (SELECT count(*)::int FROM vs_public_contest_attempts) AS attempts,
       (SELECT count(*)::int FROM vs_public_contest_results) AS results,
       (SELECT count(*)::int FROM vs_public_contest_best_results) AS best_rows,
       (SELECT count(*)::int FROM vs_public_contest_placements) AS placements,
       (SELECT count(*)::int FROM vs_idempotency_receipts WHERE namespace LIKE 'contest.%') AS receipts,
       (SELECT count(*)::int FROM vs_outbox_events WHERE topic = 'PUBLIC_CONTEST_RESULT_V1') AS messages`
  );
  expect(Number(counts.rows[0]?.contests) === 3 && Number(counts.rows[0]?.best_rows) === 3
    && Number(counts.rows[0]?.placements) === 3 && Number(counts.rows[0]?.messages) === 3,
  "durable contest evidence counts mismatch", counts.rows[0]);
  console.log(JSON.stringify({ ok: true, smoke: "public_contest_platform_embedded",
    shared_two_device_board: true, restart_persistence: true, server_time_rollover: true,
    best_per_player: true, trusted_result_boundary: true, local_fixture_isolation: true,
    idempotent_outbox: true, evidence_worker_boundary: true, finalizing_waits_for_evidence: true,
    comparator_golden: true,
    period_definitions: true, counts: counts.rows[0] }));
  await db.close();
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
