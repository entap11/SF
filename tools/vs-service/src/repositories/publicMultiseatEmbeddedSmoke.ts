import crypto from "node:crypto";
import type { Pool } from "pg";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { runMigrations } from "../db/migrate.js";
import { canonicalJson, DurableCoreError, sha256Canonical, uuidV7, type JsonRecord } from "./durableCore.js";
import { PGlitePoolAdapter } from "./pglitePoolAdapter.js";
import { PostgresDurableCoreRepository } from "./postgresDurableCoreRepository.js";
import { PostgresPublic1v1Repository } from "./postgresPublic1v1Repository.js";
import { PostgresVerificationRepository } from "./postgresVerificationRepository.js";
import type { EnqueuePublic1v1Input, Public1v1Policy, PublicDuelQueueMode } from "./public1v1.js";
import type { SignedSyncResult, VerificationBundle } from "./verificationAuthority.js";

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
function policy(modeId: PublicDuelQueueMode): Public1v1Policy {
  const requiredPlayers = modeId === "STANDARD_3P_FFA" ? 3 : 4;
  const clientMode = modeId === "STANDARD_3P_FFA" ? "3P FFA" : modeId === "STANDARD_2V2" ? "2V2" : "4P FFA";
  return {
    modeId, clientMode, vsRuleset: "STANDARD", minimumClientBuild: "2026071901",
    simBuildId: "multiseat-authority-smoke-v1", rulesetId: "standard-multiseat-v1",
    rulesetHash: "a".repeat(64), mapId: `${modeId.toLowerCase()}-fixture`, mapHash: "b".repeat(64),
    queueTtlSec: 90, sessionTtlSec: 900, reconnectGraceSec: 30,
    authorityTier: "AUTHORITY_VERIFIED", ranked: false, requiredPlayers,
    assignmentPolicyId: modeId === "STANDARD_2V2" ? "FRIEND_THEN_RANK_V1" : "SERVER_SEATS_COLORS_V1"
  };
}
function enqueue(playerId: string, index: number, modePolicy: Public1v1Policy, nowIso: string): EnqueuePublic1v1Input {
  return { requestId: `${modePolicy.modeId}-${index}`, player: { playerId, displayName: `Player ${index + 1}` },
    protocolVersion: 2, clientBuild: "2026071901", nowIso, policy: modePolicy };
}
async function form(repository: PostgresPublic1v1Repository, modePolicy: Public1v1Policy,
  players: string[], nowIso: string): Promise<JsonRecord> {
  let session: JsonRecord | null = null;
  for (let index = 0; index < players.length; index += 1) {
    const result = await repository.enqueue(enqueue(players[index], index, modePolicy, nowIso));
    if (index < players.length - 1) expect(result.ticket.status === "WAITING", "cohort formed too early", result);
    else { expect(result.ticket.status === "MATCHED" && result.session != null, "cohort did not form", result); session = result.session; }
  }
  const views = await Promise.all(players.map((playerId) => repository.getSession(String(session!.match_id), playerId)));
  expect(new Set(views.map((view) => view.contract_hash)).size === 1
    && views.every((view) => JSON.stringify(view.roster) === JSON.stringify(session!.roster)),
  "peers received different frozen rosters", views);
  return session!;
}
function sign(bundle: VerificationBundle, privateKey: string, keyId: string, workerBuildId: string,
  placements: JsonRecord[], winningTeamId: number | null): SignedSyncResult {
  const payload: JsonRecord = {
    result_id: bundle.resultId, result_schema_version: 1, match_id: bundle.contract.matchId,
    contract_id: bundle.contract.contractId, match_epoch: bundle.contract.matchEpoch,
    contract_hash: bundle.contract.contractHash, authority_method: "SIM_REPLAY",
    terminal_reason: "OBJECTIVE_COMPLETE", placements, winning_team_id: winningTeamId,
    elapsed_sim_ticks: 120, final_state_hash: "c".repeat(64), final_command_seq: bundle.finalCommandSeq,
    command_log_hash: bundle.commandLogHash, sim_build_id: bundle.contract.simBuildId,
    worker_build_id: workerBuildId, verified_at: bundle.receiptIssuedAt, verifier_key_id: keyId
  };
  return { payload, payloadHash: sha256Canonical(payload), keyId, algorithm: "ES256",
    signature: crypto.sign("sha256", Buffer.from(canonicalJson(payload)), {
      key: privateKey, dsaEncoding: "ieee-p1363"
    }).toString("base64url") };
}
async function verifyMatch(pool: Pool, repository: PostgresPublic1v1Repository, session: JsonRecord,
  players: string[], placements: JsonRecord[], winningTeamId: number | null, label: string,
  key: { privateKey: string; publicKey: string; keyId: string; workerBuildId: string }, nowIso: string,
  alreadyStarted = false): Promise<void> {
  const matchId = String(session.match_id);
  if (!alreadyStarted) {
    for (let index = 0; index < players.length; index += 1) {
      await repository.setReady({ matchId, playerId: players[index], requestId: `${label}-ready-${index}`, nowIso, ready: true });
    }
    await repository.start({ matchId, playerId: players[0], requestId: `${label}-start`, nowIso });
  }
  const roster = session.roster as JsonRecord[];
  for (let index = 0; index < players.length; index += 1) {
    const seatId = Number(roster.find((entry) => entry.player_id === players[index])?.seat_id ?? 0);
    await repository.appendCommand({ matchId, matchEpoch: 1, playerId: players[index], seatId,
      clientCommandId: uuidV7(), issuedTick: index, requestedExecuteTick: index + 1,
      command: { type: "MOVE", lane_id: index + 1 }, receivedAt: nowIso });
  }
  for (const playerId of players) {
    const page = await repository.readCommands(matchId, 1, playerId, 0);
    expect(page.events.length === players.length, "peer did not receive the full command stream", { label, page });
    await repository.readCommands(matchId, 1, playerId, page.highWaterSeq);
  }
  const verification = new PostgresVerificationRepository(pool, new PostgresDurableCoreRepository(pool));
  for (let index = 0; index < players.length; index += 1) {
    const submitted = await verification.submitClientReport({ matchId, playerId: players[index],
      requestId: `${label}-report-${index}`, finalStateHash: String(index + 1).repeat(64),
      elapsedSimTicks: 120 + index, claimedTerminalReason: "OBJECTIVE_COMPLETE",
      claimedWinnerPlayerId: players[players.length - 1], diagnostics: { peer: index }, submittedAt: nowIso });
    expect(submitted.status.requiredReportCount === players.length, "wrong report quorum", submitted.status);
  }
  const bundle = await verification.leaseNext(`${label}-worker`, nowIso, 60);
  expect(bundle != null && bundle.clientReports.length === players.length, "verification bundle missing peer reports", bundle);
  if (label === "3p") {
    const duplicated = [{ place: 1, player_ids: [players[0]] }, { place: 2, player_ids: [players[0]] },
      { place: 3, player_ids: [players[2]] }];
    await expectCode(verification.complete({ workerId: `${label}-worker`, leaseToken: bundle!.leaseToken,
      jobId: bundle!.jobId, startedAt: nowIso, finishedAt: nowIso,
      signedResult: sign(bundle!, key.privateKey, key.keyId, key.workerBuildId, duplicated, null), runDiagnostics: {} },
    { keyId: key.keyId, publicKeyPem: key.publicKey, workerBuildId: key.workerBuildId }), "verifier_placements_invalid");
  }
  const completed = await verification.complete({ workerId: `${label}-worker`, leaseToken: bundle!.leaseToken,
    jobId: bundle!.jobId, startedAt: nowIso, finishedAt: nowIso,
    signedResult: sign(bundle!, key.privateKey, key.keyId, key.workerBuildId, placements, winningTeamId),
    runDiagnostics: { client_hash_conflict_resolved_by_replay: true } },
  { keyId: key.keyId, publicKeyPem: key.publicKey, workerBuildId: key.workerBuildId });
  expect(completed.status === "COMPLETED", "multi-seat result did not complete", completed);
  const receiptHashes = [];
  for (const playerId of players) {
    const status = await verification.getPlayerStatus(matchId, playerId);
    receiptHashes.push(status.signedReceipt?.payloadHash);
  }
  expect(new Set(receiptHashes).size === 1 && Boolean(receiptHashes[0]), "peers did not receive one result receipt", receiptHashes);
}

async function main(): Promise<void> {
  const db = new PGlite({ extensions: { pgcrypto } }); await db.waitReady;
  const pool = new PGlitePoolAdapter(db) as unknown as Pool; await runMigrations(pool);
  const core = new PostgresDurableCoreRepository(pool);
  const repository = new PostgresPublic1v1Repository(pool, core);
  const nowIso = "2026-07-19T20:00:00.000Z";
  const pair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const key = { privateKey: pair.privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
    publicKey: pair.publicKey.export({ format: "pem", type: "spki" }).toString(),
    keyId: "multiseat-smoke-key", workerBuildId: "multiseat-worker-v1" };

  const three = [uuidV7(), uuidV7(), uuidV7()];
  const threeSession = await form(repository, policy("STANDARD_3P_FFA"), three, nowIso);
  const threeRoster = threeSession.roster as JsonRecord[];
  expect(new Set(threeRoster.map((row) => row.seat_id)).size === 3
    && new Set(threeRoster.map((row) => row.team_id)).size === 3
    && new Set(threeRoster.map((row) => row.color_id)).size === 3,
  "3P FFA assignment was not unique", threeRoster);
  await verifyMatch(pool, repository, threeSession, three,
    three.map((playerId, index) => ({ place: index + 1, player_ids: [playerId] })), null, "3p", key, nowIso);

  const friendPlayers = [uuidV7(), uuidV7(), uuidV7(), uuidV7()];
  for (let index = 0; index < friendPlayers.length; index += 1) {
    await repository.syncCompetitiveIdentity({ playerId: friendPlayers[index], rankValue: 400 - index * 100,
      friendPlayerIds: index === 0 ? [friendPlayers[1]] : index === 1 ? [friendPlayers[0]] : [],
      sourceRevision: `friend-${index}`, nowIso });
  }
  const friendSession = await form(repository, policy("STANDARD_2V2"), friendPlayers, nowIso);
  const friendRoster = friendSession.roster as JsonRecord[];
  const friendA = friendRoster.find((row) => row.player_id === friendPlayers[0]);
  const friendB = friendRoster.find((row) => row.player_id === friendPlayers[1]);
  expect(friendA?.team_id === friendB?.team_id
    && ((friendSession.context as JsonRecord).assignment_evidence as JsonRecord).strategy === "EXACT_FRIEND_PAIR",
  "exact friend pair was not preserved", friendRoster);
  const teamGroups = [1, 2].map((teamId, index) => ({ place: index + 1, team_id: teamId,
    player_ids: friendRoster.filter((row) => row.team_id === teamId).map((row) => row.player_id) }));
  await verifyMatch(pool, repository, friendSession, friendPlayers, teamGroups, 1, "2v2", key, nowIso);

  const balanced = [uuidV7(), uuidV7(), uuidV7(), uuidV7()];
  const ranks = [400, 300, 200, 100];
  for (let index = 0; index < balanced.length; index += 1) {
    await repository.syncCompetitiveIdentity({ playerId: balanced[index], rankValue: ranks[index],
      friendPlayerIds: [balanced[index % 2 === 0 ? index + 1 : index - 1]],
      sourceRevision: `balanced-${index}`, nowIso });
  }
  const balancedSession = await form(repository, policy("STANDARD_2V2"), balanced, nowIso);
  const balancedRoster = balancedSession.roster as JsonRecord[];
  const teamOf = (playerId: string) => balancedRoster.find((row) => row.player_id === playerId)?.team_id;
  expect(teamOf(balanced[0]) === teamOf(balanced[3]) && teamOf(balanced[1]) === teamOf(balanced[2])
    && ((balancedSession.context as JsonRecord).assignment_evidence as JsonRecord).strategy === "RANK_BALANCED",
  "multiple friend pairs did not fall back to high+low rank balance", balancedRoster);

  const four = [uuidV7(), uuidV7(), uuidV7(), uuidV7()];
  const fourSession = await form(repository, policy("STANDARD_4P_FFA"), four, nowIso);
  const fourRoster = fourSession.roster as JsonRecord[];
  expect(new Set(fourRoster.map((row) => row.team_id)).size === 4
    && new Set(fourRoster.map((row) => row.color_id)).size === 4,
  "4P FFA assignment was not unique", fourRoster);
  for (let index = 0; index < four.length; index += 1) {
    await repository.setReady({ matchId: String(fourSession.match_id), playerId: four[index],
      requestId: `4p-ready-${index}`, nowIso, ready: true });
  }
  await repository.start({ matchId: String(fourSession.match_id), playerId: four[0], requestId: "4p-start", nowIso });
  await repository.leave({ matchId: String(fourSession.match_id), playerId: four[2], requestId: "4p-leave", nowIso }, 30);
  const restarted = new PostgresPublic1v1Repository(pool, new PostgresDurableCoreRepository(pool));
  const resumed = await restarted.resume(four[2], "4p-resume", new Date(Date.parse(nowIso) + 10_000).toISOString());
  expect(resumed.lifecycle_status === "RUNNING" && (resumed.roster as JsonRecord[])[2].seat_id === 3,
    "multi-seat restart/reconnect changed the frozen seat", resumed);
  await verifyMatch(pool, restarted, fourSession, four,
    four.map((playerId, index) => ({ place: index + 1, player_ids: [playerId] })), null,
    "4p", key, new Date(Date.parse(nowIso) + 10_000).toISOString(), true);

  const counts = await pool.query<Record<string, unknown>>(
    `SELECT
      (SELECT count(*)::int FROM vs_match_peer_acks) AS peer_acks,
      (SELECT count(*)::int FROM vs_public_match_history) AS history,
      (SELECT count(*)::int FROM vs_public_shadow_results) AS shadow_results,
      (SELECT count(*)::int FROM vs_rank_settlement_jobs) AS rank_settlements,
      (SELECT count(*)::int FROM vs_crucible_escrows) AS crucible_escrows`
  );
  expect(Number(counts.rows[0].peer_acks) === 11 && Number(counts.rows[0].history) === 11
    && Number(counts.rows[0].shadow_results) === 3 && Number(counts.rows[0].rank_settlements) === 0
    && Number(counts.rows[0].crucible_escrows) === 0, "multi-seat persistence or mutation boundary failed", counts.rows[0]);
  console.log(JSON.stringify({ ok: true, smoke: "public_multiseat_embedded", friend_first: true,
    rank_balance: true, peer_acknowledgements: true, signed_results: true, restart_reconnect: true,
    no_rank_or_economy_mutation: true, counts: counts.rows[0] }));
  await db.close();
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
