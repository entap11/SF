import type { Pool, PoolClient } from "pg";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { runMigrations } from "../db/migrate.js";
import { materializeContract, uuidV7, type JsonRecord, type RosterEntry } from "./durableCore.js";
import { insertContract } from "./postgresDurableCoreRepository.js";
import { PGlitePoolAdapter } from "./pglitePoolAdapter.js";
import { PostgresCrucibleSettlementRepository } from "./crucibleSettlement.js";

function expect(value: unknown, message: string, details?: unknown): void {
  if (!value) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

async function createCrucibleMatch(pool: Pool, players: [string, string], nowIso: string) {
  const roster: RosterEntry[] = players.map((playerId, index) => ({
    playerId, displayName: `Crucible ${index + 1}`, participantType: "HUMAN", seatId: index + 1,
    teamId: index + 1, colorId: index === 0 ? "GREEN" : "PURPLE", readyState: "LOCKED",
    connectionState: "CONNECTED", joinedAt: nowIso
  }));
  const contract = materializeContract({ requestId: `crucible-smoke-${uuidV7()}`, idempotencySubject: "crucible-smoke",
    minimumClientBuild: "smoke", simBuildId: "smoke", modeId: "CRUCIBLE_1V1", rulesetId: "crucible-v1",
    rulesetHash: "a".repeat(64), mapId: "crucible-map", mapHash: "b".repeat(64), seed: "42",
    authorityTier: "AUTHORITY_VERIFIED", status: "FROZEN", assignmentPolicyId: "SERVER_SEATS_COLORS_V1",
    roster, rankPolicy: { enabled: false, policy_id: "NONE" },
    economyPolicy: { policy_id: "CRUCIBLE_WAX_V1", stake_each_millis: 1000, winner_payout_millis: 1800,
      award_reserve_millis: 200 }, practicePolicy: { practice: false, bot_fill: false }, createdAt: nowIso,
    expiresAt: new Date(new Date(nowIso).getTime() + 600_000).toISOString() });
  await insertContract(pool as unknown as PoolClient, contract);
  return contract;
}

async function addVerifiedResult(pool: Pool, contract: Awaited<ReturnType<typeof createCrucibleMatch>>,
  winner: string, loser: string, nowIso: string): Promise<string> {
  const resultId = uuidV7();
  const jobId = uuidV7();
  const result: JsonRecord = { terminal_reason: "WIN", authority_method: "SIM_REPLAY",
    placements: [{ place: 1, player_ids: [winner] }, { place: 2, player_ids: [loser] }] };
  await pool.query(
    `INSERT INTO vs_terminal_results
      (result_id, match_id, contract_id, match_epoch, result_schema_version, terminal_reason, contract_hash,
       final_command_seq, command_log_hash, payload_hash, result_json, verified_at, created_at)
     VALUES ($1, $2, $3, 1, 1, 'WIN', $4, 0, $5, $6, $7::jsonb, $8, $8)`,
    [resultId, contract.matchId, contract.contractId, contract.contractHash, "c".repeat(64), "d".repeat(64),
      JSON.stringify(result), nowIso]
  );
  await pool.query(
    `INSERT INTO vs_match_verification_jobs
      (job_id, result_id, match_id, contract_id, match_epoch, contract_hash, input_hash, status, authority_method,
       available_at, receipt_issued_at, created_at, updated_at)
     VALUES ($1, $2, $3, $4, 1, $5, $6, 'COMPLETED', 'SIM_REPLAY', $7, $7, $7, $7)`,
    [jobId, resultId, contract.matchId, contract.contractId, contract.contractHash, "e".repeat(64), nowIso]
  );
  await pool.query(
    `INSERT INTO vs_verifier_signed_receipts
      (result_id, job_id, authority_method, worker_id, worker_build_id, sim_build_id, verifier_key_id,
       signature_algorithm, signed_payload_hash, signature, signed_payload, created_at)
     VALUES ($1, $2, 'SIM_REPLAY', 'smoke-worker', 'smoke', 'smoke', 'smoke-key', 'ES256', $3,
       'smoke-signature', $4::jsonb, $5)`,
    [resultId, jobId, "f".repeat(64), JSON.stringify({ result_id: resultId }), nowIso]
  );
  return resultId;
}

async function main(): Promise<void> {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.waitReady;
  const pool = new PGlitePoolAdapter(db) as unknown as Pool;
  await runMigrations(pool);
  const nowIso = "2026-07-19T20:00:00.000Z";
  const playerA = uuidV7(); const playerB = uuidV7();
  const repository = new PostgresCrucibleSettlementRepository(pool);
  await repository.setPlayerBalance(playerA, 10_000, "seed-a", nowIso);
  await repository.setPlayerBalance(playerB, 10_000, "seed-b", nowIso);
  const match = await createCrucibleMatch(pool, [playerA, playerB], nowIso);
  const opened = await repository.openEscrow(match.matchId, "open-1", nowIso);
  expect((opened.escrow as JsonRecord).stakeEachMillis === 1000
    && (opened.escrow as JsonRecord).winnerPayoutMillis === 1800
    && (opened.escrow as JsonRecord).awardReserveMillis === 200, "escrow constants incorrect", opened);
  expect(await repository.balance(playerA) === 9_000 && await repository.balance(playerB) === 9_000,
    "stakes were not debited exactly");
  const resultId = await addVerifiedResult(pool, match, playerA, playerB, nowIso);
  const settled = await repository.settleVerified(match.matchId, resultId, "settle-1", nowIso);
  const restarted = new PostgresCrucibleSettlementRepository(pool);
  const duplicate = await restarted.settleVerified(match.matchId, resultId, "settle-1", nowIso);
  expect((settled.settlement as JsonRecord).winner_payout === 1800 && duplicate.duplicate === true,
    "settlement receipt did not survive restart", { settled, duplicate });
  expect(await restarted.balance(playerA) === 10_800 && await restarted.balance(playerB) === 9_000,
    "winner/loser balances incorrect");
  const metrics = await restarted.metrics();
  expect(metrics.award_reserve_balance_millis === 200 && metrics.escrow_balance_millis === 0
    && metrics.ledger_imbalance_millis === 0, "reserve or ledger balance incorrect", metrics);
  expect((metrics.reconciliation as JsonRecord).ok === true, "reconciliation failed", metrics);
  const reversed = await restarted.reverseSettlement(match.matchId, "verified_ops_correction", "reverse-1", nowIso);
  const reversedDuplicate = await new PostgresCrucibleSettlementRepository(pool)
    .reverseSettlement(match.matchId, "verified_ops_correction", "reverse-1", nowIso);
  expect(String((reversed.reversal as JsonRecord).reversal_of_transaction_id).length > 0
    && reversedDuplicate.duplicate === true && await restarted.balance(playerA) === 10_000
    && await restarted.balance(playerB) === 10_000, "reversal reference/refund incorrect", { reversed, reversedDuplicate });
  const afterReversal = await restarted.metrics();
  expect(afterReversal.award_reserve_balance_millis === 0
    && (afterReversal.reconciliation as JsonRecord).ok === true, "reversal did not reconcile", afterReversal);

  const playerC = uuidV7(); const playerD = uuidV7();
  await restarted.setPlayerBalance(playerC, 5_000, "seed-c", nowIso);
  await restarted.setPlayerBalance(playerD, 5_000, "seed-d", nowIso);
  const cancelled = await createCrucibleMatch(pool, [playerC, playerD], nowIso);
  await restarted.openEscrow(cancelled.matchId, "open-2", nowIso);
  const refund = await restarted.refund(cancelled.matchId, "cancel_before_first_tick", "refund-1", nowIso);
  const refundDuplicate = await new PostgresCrucibleSettlementRepository(pool)
    .refund(cancelled.matchId, "cancel_before_first_tick", "refund-1", nowIso);
  expect((refund.refund as JsonRecord).player_a_refund === 1000 && refundDuplicate.duplicate === true
    && await restarted.balance(playerC) === 5_000 && await restarted.balance(playerD) === 5_000,
  "refund was not exact/idempotent", { refund, refundDuplicate });
  expect((await restarted.metrics()).ledger_imbalance_millis === 0, "ledger imbalance after refund");
  await db.close();
  console.log("CRUCIBLE_SETTLEMENT_EMBEDDED_SMOKE: PASS");
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
