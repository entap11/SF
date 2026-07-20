import crypto from "node:crypto";
import type { Pool } from "pg";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { runMigrations } from "../db/migrate.js";
import {
  canonicalJson,
  sha256Canonical,
  uuidV7,
  type CreateContractInput,
  type JsonRecord
} from "./durableCore.js";
import { PGlitePoolAdapter } from "./pglitePoolAdapter.js";
import { PostgresDurableCoreRepository } from "./postgresDurableCoreRepository.js";
import { PostgresRankSettlementRepository } from "./rankSettlement.js";
import { PostgresVerificationRepository } from "./postgresVerificationRepository.js";
import type { SignedSyncResult, VerificationBundle } from "./verificationAuthority.js";

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

function contractInput(playerA: string, playerB: string, nowIso: string): CreateContractInput {
  return {
    requestId: "standard-1v1-release", idempotencySubject: `${playerA}:standard-1v1-release`,
    minimumClientBuild: "2026071901", simBuildId: "godot-standard-1v1-release-v1",
    modeId: "STANDARD_1V1", rulesetId: "standard-v1", rulesetHash: "1".repeat(64),
    mapId: "closequarters", mapHash: "2".repeat(64), seed: "42",
    authorityTier: "AUTHORITY_VERIFIED", status: "RUNNING", assignmentPolicyId: "SERVER_SEATS_COLORS_V1",
    roster: [
      { playerId: playerA, displayName: "Release A", participantType: "HUMAN", seatId: 1,
        teamId: 1, colorId: "GREEN", readyState: "LOCKED", connectionState: "CONNECTED", joinedAt: nowIso },
      { playerId: playerB, displayName: "Release B", participantType: "HUMAN", seatId: 2,
        teamId: 2, colorId: "PURPLE", readyState: "LOCKED", connectionState: "CONNECTED", joinedAt: nowIso }
    ],
    rankPolicy: { enabled: true, queue: "GLOBAL_RANK", policy_id: "STANDARD_1V1_V1" },
    economyPolicy: { policy_id: "NONE" }, practicePolicy: { practice: false }, createdAt: nowIso,
    expiresAt: new Date(new Date(nowIso).getTime() + 900_000).toISOString()
  };
}

function signLifecycle(bundle: VerificationBundle, privateKey: string, keyId: string,
  workerBuildId: string, winnerId: string, loserId: string): SignedSyncResult {
  const forfeit = bundle.lifecycleEvents.find((event) => event.event_type === "MATCH_FORFEITED");
  const eventPayload = forfeit?.event_payload as JsonRecord | undefined;
  expect(forfeit && eventPayload?.winner_player_id === winnerId && eventPayload?.loser_player_id === loserId,
    "authoritative forfeit event missing", bundle.lifecycleEvents);
  if (!forfeit || !eventPayload) throw new Error("authoritative forfeit event missing");
  const payload: JsonRecord = {
    result_id: bundle.resultId, result_schema_version: 1,
    match_id: bundle.contract.matchId, contract_id: bundle.contract.contractId,
    match_epoch: bundle.contract.matchEpoch, contract_hash: bundle.contract.contractHash,
    authority_method: "SERVER_LIFECYCLE", terminal_reason: "FORFEIT_DISCONNECT",
    placements: [{ place: 1, player_ids: [winnerId] }, { place: 2, player_ids: [loserId] }],
    winning_team_id: null, elapsed_sim_ticks: Number(eventPayload.elapsed_sim_ticks), final_state_hash: null,
    final_command_seq: bundle.finalCommandSeq, command_log_hash: bundle.commandLogHash,
    sim_build_id: bundle.contract.simBuildId, worker_build_id: workerBuildId,
    verified_at: bundle.receiptIssuedAt, verifier_key_id: keyId,
    lifecycle_event_id: String(forfeit.event_id)
  };
  return {
    payload, payloadHash: sha256Canonical(payload), keyId, algorithm: "ES256",
    signature: crypto.sign("sha256", Buffer.from(canonicalJson(payload)), {
      key: privateKey, dsaEncoding: "ieee-p1363"
    }).toString("base64url")
  };
}

function signLifecycleNoContest(bundle: VerificationBundle, privateKey: string, keyId: string,
  workerBuildId: string): SignedSyncResult {
  const terminal = bundle.lifecycleEvents.find((event) => event.event_type === "MATCH_NO_CONTEST");
  const eventPayload = terminal?.event_payload as JsonRecord | undefined;
  expect(terminal && eventPayload?.no_contest_reason === "ALL_PLAYERS_GRACE_EXPIRED",
    "simultaneous disconnect did not produce no-contest", bundle.lifecycleEvents);
  if (!terminal || !eventPayload) throw new Error("authoritative no-contest event missing");
  const payload: JsonRecord = {
    result_id: bundle.resultId, result_schema_version: 1,
    match_id: bundle.contract.matchId, contract_id: bundle.contract.contractId,
    match_epoch: bundle.contract.matchEpoch, contract_hash: bundle.contract.contractHash,
    authority_method: "SERVER_LIFECYCLE", terminal_reason: "NO_CONTEST", placements: [],
    winning_team_id: null, elapsed_sim_ticks: Number(eventPayload.elapsed_sim_ticks), final_state_hash: null,
    final_command_seq: bundle.finalCommandSeq, command_log_hash: bundle.commandLogHash,
    sim_build_id: bundle.contract.simBuildId, worker_build_id: workerBuildId,
    verified_at: bundle.receiptIssuedAt, verifier_key_id: keyId,
    lifecycle_event_id: String(terminal.event_id), no_contest_reason: "ALL_PLAYERS_GRACE_EXPIRED"
  };
  return {
    payload, payloadHash: sha256Canonical(payload), keyId, algorithm: "ES256",
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
  const verification = new PostgresVerificationRepository(pool, core);
  const playerA = uuidV7();
  const playerB = uuidV7();
  const nowIso = new Date().toISOString();
  const created = await core.createContract(contractInput(playerA, playerB, nowIso));
  await core.appendCommand({
    matchId: created.contract.matchId, matchEpoch: 1, playerId: playerA, seatId: 1,
    clientCommandId: uuidV7(), issuedTick: 2, requestedExecuteTick: 3,
    command: { kind: "lane_intent", src: 1, dst: 2, intent: "attack" }, receivedAt: nowIso
  });
  const expiredDeadline = new Date(new Date(nowIso).getTime() - 5_000).toISOString();
  await core.setReconnectState({
    matchId: created.contract.matchId, playerId: playerB, matchEpoch: 1, reconnectEpoch: 1,
    connectionState: "GRACE", graceDeadlineAt: expiredDeadline, lastSeenAt: expiredDeadline
  });
  await core.updateContractStatus(created.contract.contractId, "RECONNECTING", nowIso);
  const expired = await verification.expireReconnectGrace(nowIso, 25);
  expect(expired === 1, "disconnect grace did not expire authoritatively", expired);
  expect(await verification.expireReconnectGrace(nowIso, 25) === 0, "disconnect expiry was not idempotent");

  const bundle = await verification.leaseNext("lifecycle-worker", nowIso, 60);
  expect(bundle?.authorityMethod === "SERVER_LIFECYCLE", "lifecycle verification job missing", bundle);
  const pair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const privateKey = pair.privateKey.export({ format: "pem", type: "pkcs8" }).toString();
  const publicKey = pair.publicKey.export({ format: "pem", type: "spki" }).toString();
  const keyId = "release-verifier-key";
  const workerBuildId = "release-verifier-v1";
  const signed = signLifecycle(bundle!, privateKey, keyId, workerBuildId, playerA, playerB);
  const completed = await verification.complete({
    workerId: "lifecycle-worker", leaseToken: bundle!.leaseToken, jobId: bundle!.jobId,
    startedAt: nowIso, finishedAt: new Date().toISOString(), signedResult: signed,
    runDiagnostics: { source: "disconnect_grace_expiry" }
  }, { keyId, publicKeyPem: publicKey, workerBuildId });
  expect(completed.status === "COMPLETED" && completed.result?.terminalReason === "FORFEIT_DISCONNECT",
    "disconnect result did not become authoritative", completed);

  const settlement = new PostgresRankSettlementRepository(pool);
  expect(await settlement.reconcile(new Date().toISOString()) === 1, "rank settlement was not reconciled");
  expect(await settlement.reconcile(new Date().toISOString()) === 0, "rank settlement reconciliation duplicated work");
  const firstLease = await settlement.leaseNext("rank-worker-a", new Date().toISOString(), 60);
  expect(firstLease?.resultId === completed.result?.resultId && firstLease?.signedReceipt.signature === signed.signature,
    "settlement lease lost verified receipt", firstLease);
  const request: JsonRecord = {
    rank_event_id: firstLease!.rankEventId, mode_id: "STANDARD_1V1",
    signed_result: { payload: signed.payload, payload_hash: signed.payloadHash, key_id: signed.keyId,
      algorithm: signed.algorithm, signature: signed.signature }
  };
  await pool.query("UPDATE vs_rank_settlement_jobs SET max_attempts = 1 WHERE settlement_id = $1",
    [firstLease!.settlementId]);
  await settlement.fail({
    settlementId: firstLease!.settlementId, workerId: "rank-worker-a", leaseToken: firstLease!.leaseToken,
    startedAt: nowIso, finishedAt: nowIso, request,
    response: { ok: false, err: "rank_players_missing", retryable: true },
    errorCode: "rank_players_missing", retryable: true, retryDelaySec: 1
  });
  const restarted = new PostgresRankSettlementRepository(pool);
  const retryAt = new Date(new Date(nowIso).getTime() + 2_000).toISOString();
  const retryLease = await restarted.leaseNext("rank-worker-b", retryAt, 60);
  expect(retryLease?.attempt === 2 && retryLease.resultId === firstLease!.resultId,
    "durable retry did not survive repository restart", retryLease);
  const rankResponse: JsonRecord = {
    ok: true, status: "SETTLED", rank_event_id: retryLease!.rankEventId,
    result_id: retryLease!.resultId, duplicate: false
  };
  const settled = await restarted.complete({
    settlementId: retryLease!.settlementId, workerId: "rank-worker-b", leaseToken: retryLease!.leaseToken,
    startedAt: retryAt, finishedAt: retryAt, request, response: rankResponse
  });
  const duplicate = await restarted.complete({
    settlementId: retryLease!.settlementId, workerId: "rank-worker-b", leaseToken: retryLease!.leaseToken,
    startedAt: retryAt, finishedAt: retryAt, request, response: rankResponse
  });
  const visible = await restarted.getForPlayer(created.contract.matchId, playerA);

  const noContestA = uuidV7();
  const noContestB = uuidV7();
  const noContestContract = await core.createContract(contractInput(noContestA, noContestB, nowIso));
  for (const playerId of [noContestA, noContestB]) {
    await core.setReconnectState({
      matchId: noContestContract.contract.matchId, playerId, matchEpoch: 1, reconnectEpoch: 1,
      connectionState: "GRACE", graceDeadlineAt: expiredDeadline, lastSeenAt: expiredDeadline
    });
  }
  await core.updateContractStatus(noContestContract.contract.contractId, "RECONNECTING", nowIso);
  expect(await verification.expireReconnectGrace(nowIso, 25) === 1,
    "simultaneous grace expiry was not resolved");
  const noContestBundle = await verification.leaseNext("lifecycle-worker", nowIso, 60);
  expect(noContestBundle?.authorityMethod === "SERVER_LIFECYCLE", "no-contest verification job missing");
  const signedNoContest = signLifecycleNoContest(noContestBundle!, privateKey, keyId, workerBuildId);
  const noContestResult = await verification.complete({
    workerId: "lifecycle-worker", leaseToken: noContestBundle!.leaseToken, jobId: noContestBundle!.jobId,
    startedAt: nowIso, finishedAt: new Date().toISOString(), signedResult: signedNoContest,
    runDiagnostics: { source: "all_players_grace_expired" }
  }, { keyId, publicKeyPem: publicKey, workerBuildId });
  expect(noContestResult.status === "QUARANTINED" && noContestResult.result?.terminalReason === "NO_CONTEST",
    "simultaneous disconnect did not quarantine result", noContestResult);
  expect(await restarted.reconcile(new Date().toISOString()) === 1,
    "no-contest settlement disposition missing");
  const noContestSettlement = await restarted.getForPlayer(noContestContract.contract.matchId, noContestA);
  expect(noContestSettlement.status === "NOT_APPLICABLE", "no-contest became rank eligible", noContestSettlement);
  const counts = await pool.query<Record<string, unknown>>(
    `SELECT
      (SELECT count(*)::int FROM vs_match_lifecycle_events WHERE event_type = 'MATCH_FORFEITED') AS forfeits,
      (SELECT count(*)::int FROM vs_match_lifecycle_events WHERE event_type = 'MATCH_NO_CONTEST') AS no_contests,
      (SELECT count(*)::int FROM vs_terminal_results) AS results,
      (SELECT count(*)::int FROM vs_rank_settlement_jobs) AS settlements,
      (SELECT count(*)::int FROM vs_rank_settlement_attempts) AS attempts`
  );
  expect(settled.status === "SETTLED" && duplicate.status === "SETTLED" && visible.status === "SETTLED",
    "settlement completion was not durable/idempotent", { settled, duplicate, visible });
  expect(Number(counts.rows[0]?.forfeits) === 1 && Number(counts.rows[0]?.no_contests) === 1
    && Number(counts.rows[0]?.results) === 2 && Number(counts.rows[0]?.settlements) === 2
    && Number(counts.rows[0]?.attempts) === 2,
    "release evidence counts mismatch", counts.rows[0]);
  console.log(JSON.stringify({ ok: true, smoke: "standard_1v1_release", disconnect_expiry: true,
    simultaneous_disconnect_no_contest: true, signed_lifecycle_result: true,
    settlement_retry_restart: true, settlement_idempotent: true,
    counts: counts.rows[0] }));
  await db.close();
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
