import crypto from "node:crypto";
import type { Pool } from "pg";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { runMigrations } from "../db/migrate.js";
import {
  canonicalJson,
  DurableCoreError,
  sha256Canonical,
  uuidV7,
  type CreateContractInput,
  type JsonRecord
} from "./durableCore.js";
import { PGlitePoolAdapter } from "./pglitePoolAdapter.js";
import { PostgresDurableCoreRepository } from "./postgresDurableCoreRepository.js";
import { PostgresVerificationRepository } from "./postgresVerificationRepository.js";
import type { SignedSyncResult, VerificationBundle } from "./verificationAuthority.js";

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

async function expectCode(promise: Promise<unknown>, code: string): Promise<void> {
  try { await promise; } catch (error) {
    expect(error instanceof DurableCoreError && error.code === code,
      `expected ${code}`, error instanceof Error ? error.message : error);
    return;
  }
  throw new Error(`expected ${code}`);
}

function contractInput(playerA: string, playerB: string, nowIso: string): CreateContractInput {
  return {
    requestId: "verification-contract", idempotencySubject: `${playerA}:verification-smoke`,
    minimumClientBuild: "2026071801", simBuildId: "godot-4.2.2-authority-smoke",
    modeId: "STANDARD_1V1", rulesetId: "standard-v1", rulesetHash: "1".repeat(64),
    mapId: "authority-fixture", mapHash: "2".repeat(64), seed: "42",
    authorityTier: "AUTHORITY_VERIFIED", status: "RUNNING", assignmentPolicyId: "SERVER_SEATS_COLORS_V1",
    roster: [
      { playerId: playerA, displayName: "Authority A", participantType: "HUMAN", seatId: 1,
        teamId: 1, colorId: "GREEN", readyState: "LOCKED", connectionState: "CONNECTED", joinedAt: nowIso },
      { playerId: playerB, displayName: "Authority B", participantType: "HUMAN", seatId: 2,
        teamId: 2, colorId: "PURPLE", readyState: "LOCKED", connectionState: "CONNECTED", joinedAt: nowIso }
    ],
    rankPolicy: { enabled: false }, economyPolicy: { policy_id: "NONE" },
    practicePolicy: { practice: false }, createdAt: nowIso,
    expiresAt: new Date(new Date(nowIso).getTime() + 900_000).toISOString()
  };
}

function sign(bundle: VerificationBundle, privateKey: string, keyId: string, workerBuildId: string,
  playerA: string, playerB: string): SignedSyncResult {
  const payload: JsonRecord = {
    result_id: bundle.resultId,
    result_schema_version: 1,
    match_id: bundle.contract.matchId,
    contract_id: bundle.contract.contractId,
    match_epoch: bundle.contract.matchEpoch,
    contract_hash: bundle.contract.contractHash,
    authority_method: "SIM_REPLAY",
    terminal_reason: "OBJECTIVE_COMPLETE",
    placements: [{ place: 1, player_ids: [playerA] }, { place: 2, player_ids: [playerB] }],
    winning_team_id: null,
    elapsed_sim_ticks: 18,
    final_state_hash: "a".repeat(64),
    final_command_seq: bundle.finalCommandSeq,
    command_log_hash: bundle.commandLogHash,
    sim_build_id: bundle.contract.simBuildId,
    worker_build_id: workerBuildId,
    verified_at: bundle.receiptIssuedAt,
    verifier_key_id: keyId
  };
  return {
    payload,
    payloadHash: sha256Canonical(payload),
    keyId,
    algorithm: "ES256",
    signature: crypto.sign("sha256", Buffer.from(canonicalJson(payload)), {
      key: privateKey, dsaEncoding: "ieee-p1363"
    }).toString("base64url")
  };
}

async function main(): Promise<void> {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.waitReady;
  const pool = new PGlitePoolAdapter(db) as unknown as Pool;
  await runMigrations(pool);
  const core = new PostgresDurableCoreRepository(pool);
  const repository = new PostgresVerificationRepository(pool, core);
  const playerA = uuidV7();
  const playerB = uuidV7();
  const outsider = uuidV7();
  const nowIso = new Date().toISOString();
  const created = await core.createContract(contractInput(playerA, playerB, nowIso));
  await core.appendCommand({
    matchId: created.contract.matchId, matchEpoch: 1, playerId: playerA, seatId: 1,
    clientCommandId: uuidV7(), issuedTick: 0, requestedExecuteTick: 3,
    command: { kind: "lane_intent", src: 1, dst: 2, intent: "attack" }, receivedAt: nowIso
  });
  const reportA = await repository.submitClientReport({
    matchId: created.contract.matchId, playerId: playerA, requestId: "report-a",
    finalStateHash: "b".repeat(64), elapsedSimTicks: 999, claimedTerminalReason: "OBJECTIVE_COMPLETE",
    claimedWinnerPlayerId: playerB, diagnostics: { client_winner: playerB }, submittedAt: nowIso
  });
  expect(reportA.status.status === "AWAITING_REPORTS" && reportA.status.reportCount === 1,
    "first report prematurely scheduled verification", reportA);
  const reportADuplicate = await repository.submitClientReport({
    matchId: created.contract.matchId, playerId: playerA, requestId: "report-a",
    finalStateHash: "b".repeat(64), elapsedSimTicks: 999, claimedTerminalReason: "OBJECTIVE_COMPLETE",
    claimedWinnerPlayerId: playerB, diagnostics: { client_winner: playerB }, submittedAt: nowIso
  });
  expect(reportADuplicate.report.duplicate, "client report retry was not idempotent", reportADuplicate);
  await expectCode(repository.getPlayerStatus(created.contract.matchId, outsider), "player_not_in_match");
  const reportB = await repository.submitClientReport({
    matchId: created.contract.matchId, playerId: playerB, requestId: "report-b",
    finalStateHash: "c".repeat(64), elapsedSimTicks: 1001, claimedTerminalReason: "OBJECTIVE_COMPLETE",
    claimedWinnerPlayerId: playerB, diagnostics: { client_winner: playerB }, submittedAt: nowIso
  });
  expect(reportB.status.status === "PENDING" && reportB.status.reportCount === 2,
    "report quorum did not create a verification job", reportB);
  await expectCode(core.appendCommand({
    matchId: created.contract.matchId, matchEpoch: 1, playerId: playerA, seatId: 1,
    clientCommandId: uuidV7(), issuedTick: 20, requestedExecuteTick: 23,
    command: { kind: "lane_intent", src: 1, dst: 2, intent: "attack" }, receivedAt: new Date().toISOString()
  }), "match_not_running");

  const bundle = await repository.leaseNext("worker-a", new Date().toISOString(), 60);
  expect(bundle != null && bundle.contract.authorityTier === "AUTHORITY_VERIFIED"
    && bundle.commands.length === 1 && bundle.clientReports.length === 2,
    "worker lease bundle incomplete", bundle);
  const pair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const privateKey = pair.privateKey.export({ format: "pem", type: "pkcs8" }).toString();
  const publicKey = pair.publicKey.export({ format: "pem", type: "spki" }).toString();
  const workerBuildId = "authority-worker-smoke-v1";
  const keyId = "authority-key-smoke";
  const signed = sign(bundle!, privateKey, keyId, workerBuildId, playerA, playerB);
  const forged: SignedSyncResult = { ...signed, signature: Buffer.alloc(64).toString("base64url") };
  await expectCode(repository.complete({
    workerId: "worker-a", leaseToken: bundle!.leaseToken, jobId: bundle!.jobId,
    startedAt: nowIso, finishedAt: new Date().toISOString(), signedResult: forged, runDiagnostics: {}
  }, { keyId, publicKeyPem: publicKey, workerBuildId }), "verifier_signature_invalid");
  const stalePayload = { ...signed.payload, match_epoch: 2 };
  const staleEpoch: SignedSyncResult = {
    ...signed,
    payload: stalePayload,
    payloadHash: sha256Canonical(stalePayload),
    signature: crypto.sign("sha256", Buffer.from(canonicalJson(stalePayload)), {
      key: privateKey, dsaEncoding: "ieee-p1363"
    }).toString("base64url")
  };
  await expectCode(repository.complete({
    workerId: "worker-a", leaseToken: bundle!.leaseToken, jobId: bundle!.jobId,
    startedAt: nowIso, finishedAt: new Date().toISOString(), signedResult: staleEpoch, runDiagnostics: {}
  }, { keyId, publicKeyPem: publicKey, workerBuildId }), "verifier_result_binding_mismatch");
  const completed = await repository.complete({
    workerId: "worker-a", leaseToken: bundle!.leaseToken, jobId: bundle!.jobId,
    startedAt: nowIso, finishedAt: new Date().toISOString(), signedResult: signed,
    runDiagnostics: { replays: 2, client_claims_ignored: true }
  }, { keyId, publicKeyPem: publicKey, workerBuildId });
  const resultPayload = completed.result?.result as JsonRecord;
  expect(completed.status === "COMPLETED" && resultPayload.terminal_reason === "OBJECTIVE_COMPLETE"
    && ((resultPayload.placements as JsonRecord[])[0].player_ids as string[])[0] === playerA,
    "verified result did not override forged client winner", completed);
  expect(completed.signedReceipt?.signature === signed.signature, "signed receipt not retained", completed);

  const restarted = new PostgresVerificationRepository(pool, new PostgresDurableCoreRepository(pool));
  const retried = await restarted.complete({
    workerId: "worker-a", leaseToken: bundle!.leaseToken, jobId: bundle!.jobId,
    startedAt: nowIso, finishedAt: new Date().toISOString(), signedResult: signed, runDiagnostics: {}
  }, { keyId, publicKeyPem: publicKey, workerBuildId });
  expect(retried.result?.resultId === completed.result?.resultId && retried.signedReceipt?.signature === signed.signature,
    "completion retry after restart did not return immutable receipt", retried);
  const counts = await pool.query<Record<string, unknown>>(
    `SELECT
      (SELECT count(*)::int FROM vs_match_client_terminal_reports) AS reports,
      (SELECT count(*)::int FROM vs_match_verification_jobs) AS jobs,
      (SELECT count(*)::int FROM vs_match_verification_runs) AS runs,
      (SELECT count(*)::int FROM vs_terminal_results) AS results,
      (SELECT count(*)::int FROM vs_verifier_signed_receipts) AS receipts`
  );
  console.log(JSON.stringify({ ok: true, smoke: "verification_embedded", restart_retry: true,
    client_winner_ignored: true, signature_rejection: true, counts: counts.rows[0] }));
  await db.close();
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
