import type { Pool } from "pg";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { runMigrations } from "../db/migrate.js";
import { sha256Canonical, uuidV7, type CreateContractInput, type JsonRecord } from "./durableCore.js";
import { PGlitePoolAdapter } from "./pglitePoolAdapter.js";
import { PostgresDurableCoreRepository } from "./postgresDurableCoreRepository.js";
import { PostgresPlatformEconomyDeliveryRepository } from "./platformEconomyDelivery.js";
import { PostgresRankSettlementRepository } from "./rankSettlement.js";
import { validatePlatformEconomyResponse } from "../platformEconomyProcessor.js";

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

function expectThrows(run: () => void, message: string): void {
  try { run(); } catch { return; }
  throw new Error(message);
}

function contractInput(modeId: "STANDARD_1V1" | "CRUCIBLE_1V1", playerA: string, playerB: string,
  nowIso: string): CreateContractInput {
  return {
    requestId: `${modeId}:${playerA}`, idempotencySubject: `${modeId}:delivery-smoke`,
    minimumClientBuild: "1", simBuildId: "economy-delivery-smoke-v1", modeId,
    rulesetId: `${modeId.toLowerCase()}-v1`, rulesetHash: "1".repeat(64),
    mapId: "closequarters", mapHash: "2".repeat(64), seed: "42",
    authorityTier: "AUTHORITY_VERIFIED", status: "FROZEN", assignmentPolicyId: "SERVER_SEATS_COLORS_V1",
    roster: [
      { playerId: playerA, displayName: "A", participantType: "HUMAN", seatId: 1,
        teamId: 1, colorId: "GREEN", readyState: "READY", connectionState: "CONNECTED", joinedAt: nowIso },
      { playerId: playerB, displayName: "B", participantType: "HUMAN", seatId: 2,
        teamId: 2, colorId: "PURPLE", readyState: "READY", connectionState: "CONNECTED", joinedAt: nowIso }
    ],
    rankPolicy: { enabled: modeId === "STANDARD_1V1" },
    economyPolicy: modeId === "CRUCIBLE_1V1"
      ? { policy_id: "CRUCIBLE_WAX_V1", stake_each_millis: 1000, winner_payout_millis: 1800,
        award_reserve_millis: 200 } : { policy_id: "NONE" },
    practicePolicy: { practice: false }, createdAt: nowIso,
    expiresAt: new Date(new Date(nowIso).getTime() + 900_000).toISOString()
  };
}

async function completeVerifiedStandard(pool: Pool, contract: Awaited<ReturnType<PostgresDurableCoreRepository["createContract"]>>,
  playerA: string, playerB: string, nowIso: string): Promise<string> {
  const resultId = uuidV7();
  const jobId = uuidV7();
  const payload: JsonRecord = {
    result_id: resultId, result_schema_version: 1, match_id: contract.contract.matchId,
    contract_id: contract.contract.contractId, match_epoch: 1, contract_hash: contract.contract.contractHash,
    authority_method: "SIM_REPLAY", terminal_reason: "OBJECTIVE_COMPLETE",
    placements: [{ place: 1, player_ids: [playerA] }, { place: 2, player_ids: [playerB] }],
    winning_team_id: null, elapsed_sim_ticks: 3600, final_state_hash: "3".repeat(64),
    final_command_seq: 0, command_log_hash: "4".repeat(64), sim_build_id: contract.contract.simBuildId,
    worker_build_id: "smoke-worker", verified_at: nowIso, verifier_key_id: "smoke-key"
  };
  await pool.query(
    `INSERT INTO vs_match_verification_jobs
      (job_id, result_id, match_id, contract_id, match_epoch, contract_hash, input_hash, status,
       authority_method, attempt_count, max_attempts, available_at, receipt_issued_at, completion_hash,
       created_at, updated_at)
     VALUES ($1, $2, $3, $4, 1, $5, $6, 'COMPLETED', 'SIM_REPLAY', 1, 5, $7, $7, $8, $7, $7)`,
    [jobId, resultId, contract.contract.matchId, contract.contract.contractId,
      contract.contract.contractHash, "5".repeat(64), nowIso, "6".repeat(64)]
  );
  await pool.query(
    `INSERT INTO vs_terminal_results
      (result_id, match_id, contract_id, match_epoch, result_schema_version, terminal_reason,
       contract_hash, final_command_seq, command_log_hash, payload_hash, result_json, verified_at)
     VALUES ($1, $2, $3, 1, 1, 'OBJECTIVE_COMPLETE', $4, 0, $5, $6, $7::jsonb, $8)`,
    [resultId, contract.contract.matchId, contract.contract.contractId, contract.contract.contractHash,
      "4".repeat(64), sha256Canonical(payload), JSON.stringify(payload), nowIso]
  );
  await pool.query(
    `INSERT INTO vs_verifier_signed_receipts
      (result_id, job_id, authority_method, worker_id, worker_build_id, sim_build_id,
       verifier_key_id, signature_algorithm, signed_payload_hash, signature, signed_payload, created_at)
     VALUES ($1, $2, 'SIM_REPLAY', 'smoke', 'smoke-worker', $3, 'smoke-key', 'ES256', $4, 'sig', $5::jsonb, $6)`,
    [resultId, jobId, contract.contract.simBuildId, sha256Canonical(payload), JSON.stringify(payload), nowIso]
  );
  return resultId;
}

async function main(): Promise<void> {
  const responseBinding = {
    economyEpoch: "beta_launch_0001", matchId: uuidV7(), playerId: uuidV7()
  };
  validatePlatformEconomyResponse(responseBinding, {
    ok: true, epoch_id: responseBinding.economyEpoch, player_id: responseBinding.playerId
  });
  expectThrows(() => validatePlatformEconomyResponse(responseBinding, {
    ok: true, epoch_id: responseBinding.economyEpoch, player_id: responseBinding.playerId,
    match_id: uuidV7()
  }), "an explicitly mismatched response match was accepted");
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.waitReady;
  const pool = new PGlitePoolAdapter(db) as unknown as Pool;
  await runMigrations(pool);
  const core = new PostgresDurableCoreRepository(pool);
  const repository = new PostgresPlatformEconomyDeliveryRepository(pool);
  const nowIso = new Date().toISOString();
  const crucibleA = uuidV7(); const crucibleB = uuidV7();
  const crucible = await core.createContract(contractInput("CRUCIBLE_1V1", crucibleA, crucibleB, nowIso));
  expect(await repository.enqueueCrucibleReservations(crucible.contract.matchId, "beta_launch_0001", nowIso) === 2,
    "Crucible reservations were not durably enqueued");
  expect(await repository.enqueueCrucibleReservations(crucible.contract.matchId, "beta_launch_0001", nowIso) === 0,
    "Crucible enqueue was not idempotent");
  const first = await repository.leaseNext("smoke", nowIso, 60,
    { matchId: crucible.contract.matchId, operation: "CRUCIBLE_RESERVE" });
  expect(first?.payload.contract_hash === crucible.contract.contractHash, "contract binding missing", first);
  await repository.complete({ deliveryId: first!.deliveryId, workerId: "smoke", leaseToken: first!.leaseToken,
    startedAt: nowIso, finishedAt: nowIso,
    response: { ok: true, epoch_id: "beta_launch_0001", match_id: crucible.contract.matchId,
      player_id: first!.playerId } });
  expect(!await repository.crucibleReservationsCommitted(crucible.contract.matchId),
    "one reservation incorrectly opened the start gate");
  const second = await repository.leaseNext("smoke", nowIso, 60,
    { matchId: crucible.contract.matchId, operation: "CRUCIBLE_RESERVE" });
  await repository.fail({ deliveryId: second!.deliveryId, workerId: "smoke", leaseToken: second!.leaseToken,
    startedAt: nowIso, finishedAt: nowIso, response: { ok: false, err: "temporary" },
    errorCode: "temporary", retryable: true, retryDelaySec: 1 });
  const retryAt = new Date(new Date(nowIso).getTime() + 2_000).toISOString();
  const retried = await repository.leaseNext("smoke-restart", retryAt, 60,
    { matchId: crucible.contract.matchId, operation: "CRUCIBLE_RESERVE" });
  expect(retried?.attempt === 2 && retried.producerEventId === second!.producerEventId,
    "retry did not preserve producer identity", retried);
  await repository.complete({ deliveryId: retried!.deliveryId, workerId: "smoke-restart",
    leaseToken: retried!.leaseToken, startedAt: retryAt, finishedAt: retryAt,
    response: { ok: true, epoch_id: "beta_launch_0001", match_id: crucible.contract.matchId,
      player_id: retried!.playerId } });
  expect(await repository.crucibleReservationsCommitted(crucible.contract.matchId),
    "two receipts did not open the start gate");

  const standardA = uuidV7(); const standardB = uuidV7();
  const standard = await core.createContract(contractInput("STANDARD_1V1", standardA, standardB, nowIso));
  const resultId = await completeVerifiedStandard(pool, standard, standardA, standardB, nowIso);
  const historicalIso = new Date(new Date(nowIso).getTime() - 120_000).toISOString();
  const cutoverIso = new Date(new Date(nowIso).getTime() - 60_000).toISOString();
  const historicalA = uuidV7(); const historicalB = uuidV7();
  const historical = await core.createContract(contractInput(
    "STANDARD_1V1", historicalA, historicalB, historicalIso
  ));
  const historicalResultId = await completeVerifiedStandard(
    pool, historical, historicalA, historicalB, historicalIso
  );
  const outsiderA = uuidV7(); const outsiderB = uuidV7();
  const outsider = await core.createContract(contractInput("STANDARD_1V1", outsiderA, outsiderB, nowIso));
  const outsiderResultId = await completeVerifiedStandard(pool, outsider, outsiderA, outsiderB, nowIso);
  const boundary = { verifiedAtOrAfter: cutoverIso, allowedPlayerIds: [standardA, standardB] };
  expect(await repository.reconcileVerifiedResults("beta_launch_0001", nowIso, boundary) === 4,
    "verified standard result did not produce two Honey and two Nectar facts");
  expect(await repository.reconcileVerifiedResults("beta_launch_0001", nowIso, boundary) === 0,
    "verified fact reconciliation duplicated deliveries");
  expect(await repository.reconcileVerifiedResults("beta_launch_0001", nowIso) === 8,
    "unfiltered setup did not expose historical and non-allowlisted deliveries");
  await pool.query(
    `DELETE FROM vs_platform_economy_deliveries
     WHERE delivery_id = (
       SELECT delivery_id FROM vs_platform_economy_deliveries
       WHERE result_id = $1 AND operation = 'NECTAR_MATCH' LIMIT 1
     )`, [resultId]
  );
  expect(await repository.reconcileVerifiedResults("beta_launch_0001", nowIso, boundary) === 1,
    "partial verified fact fanout was not repaired idempotently");
  const facts = await pool.query<{ operation: string; player_id: string; producer_event_id: string }>(
    "SELECT operation, player_id::text, producer_event_id FROM vs_platform_economy_deliveries WHERE result_id = $1 ORDER BY operation, player_id",
    [resultId]
  );
  expect(facts.rows.filter((row) => row.operation === "HONEY_ACTIVITY").length === 2
    && facts.rows.filter((row) => row.operation === "NECTAR_MATCH").length === 2,
  "fact fanout incorrect", facts.rows);
  const leasedResultIds: string[] = [];
  for (let index = 0; index < 4; index += 1) {
    const leased = await repository.leaseNext(`boundary-worker-${index}`, nowIso, 60, {}, boundary);
    expect(leased?.resultId === resultId, "rollout lease escaped the bounded result", leased);
    leasedResultIds.push(String(leased!.resultId));
    await repository.complete({ deliveryId: leased!.deliveryId, workerId: `boundary-worker-${index}`,
      leaseToken: leased!.leaseToken, startedAt: nowIso, finishedAt: nowIso,
      response: { ok: true, epoch_id: "beta_launch_0001", player_id: leased!.playerId } });
  }
  expect(await repository.leaseNext("boundary-worker-empty", nowIso, 60, {}, boundary) === null,
    "historical or non-allowlisted delivery was leaseable");
  expect(leasedResultIds.every((leasedResultId) => leasedResultId === resultId),
    "rollout lease returned a foreign result", leasedResultIds);
  const blockedDeliveryCounts = await pool.query<{ result_id: string; count: number }>(
    `SELECT result_id::text, count(*)::int AS count FROM vs_platform_economy_deliveries
     WHERE result_id IN ($1, $2) GROUP BY result_id ORDER BY result_id`,
    [historicalResultId, outsiderResultId]
  );
  expect(blockedDeliveryCounts.rows.every((row) => row.count === 4),
    "blocked delivery fixtures were not retained as pending evidence", blockedDeliveryCounts.rows);

  const rankSettlements = new PostgresRankSettlementRepository(pool);
  expect(await rankSettlements.reconcile(nowIso) === 3,
    "rank settlement boundary setup did not retain all verified results");
  const boundedRankLease = await rankSettlements.leaseNext("bounded-rank-worker", nowIso, 60, boundary);
  expect(boundedRankLease?.resultId === resultId, "rank settlement lease escaped the bounded result", boundedRankLease);
  await rankSettlements.fail({ settlementId: boundedRankLease!.settlementId, workerId: "bounded-rank-worker",
    leaseToken: boundedRankLease!.leaseToken, startedAt: nowIso, finishedAt: nowIso,
    request: {}, response: { ok: false, err: "bounded_test_complete" }, errorCode: "bounded_test_complete",
    retryable: false, retryDelaySec: 0 });
  expect(await rankSettlements.leaseNext("bounded-rank-worker-empty", nowIso, 60, boundary) === null,
    "historical or non-allowlisted rank settlement was leaseable");
  console.log(JSON.stringify({ ok: true, smoke: "platform_economy_delivery",
    crucible_reservations_receipt_gated: true, durable_retry: true,
    standard_fact_fanout: { honey: 2, nectar: 2 }, partial_fanout_repaired: true,
    rollout_cutover_enforced: true, rollout_roster_enforced: true, lease_boundary_enforced: true,
    pending: await repository.pendingCount() }));
  await db.close();
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
