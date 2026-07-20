import type { Pool } from "pg";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { runMigrations } from "../db/migrate.js";
import { DurableCoreError, uuidV7, type JsonRecord } from "./durableCore.js";
import { PGlitePoolAdapter } from "./pglitePoolAdapter.js";
import { PostgresDurableCoreRepository } from "./postgresDurableCoreRepository.js";
import { PostgresPublic1v1Repository } from "./postgresPublic1v1Repository.js";
import type { EnqueuePublic1v1Input, Public1v1Policy } from "./public1v1.js";

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

async function expectCode(promise: Promise<unknown>, code: string): Promise<void> {
  try {
    await promise;
  } catch (error) {
    expect(error instanceof DurableCoreError && error.code === code,
      `expected ${code}`, error instanceof Error ? error.message : error);
    return;
  }
  throw new Error(`expected ${code}`);
}

const policy: Public1v1Policy = {
  modeId: "STANDARD_1V1",
  clientMode: "1V1",
  vsRuleset: "STANDARD",
  minimumClientBuild: "2026071801",
  simBuildId: "godot-4.2.2-swarmfront-package-3",
  rulesetId: "standard-v1",
  rulesetHash: "1".repeat(64),
  mapId: "closequarters",
  mapHash: "2".repeat(64),
  queueTtlSec: 90,
  sessionTtlSec: 900,
  reconnectGraceSec: 30,
  authorityTier: "RELAY_ATTESTED",
  ranked: false
};

function enqueueInput(playerId: string, displayName: string, requestId: string, nowIso: string): EnqueuePublic1v1Input {
  return {
    requestId,
    player: { playerId, displayName },
    protocolVersion: 2,
    clientBuild: "2026071801",
    nowIso,
    policy
  };
}

async function main(): Promise<void> {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.waitReady;
  const pool = new PGlitePoolAdapter(db) as unknown as Pool;
  await runMigrations(pool);
  const playerA = uuidV7();
  const playerB = uuidV7();
  const playerC = uuidV7();
  const playerD = uuidV7();
  const playerE = uuidV7();
  const playerF = uuidV7();
  const nowIso = new Date().toISOString();
  const core = new PostgresDurableCoreRepository(pool);
  const queue = new PostgresPublic1v1Repository(pool, core);

  const waiting = await queue.enqueue(enqueueInput(playerA, "Verified A", "enqueue-a", nowIso));
  expect(waiting.ticket.status === "WAITING" && waiting.session == null, "first player did not wait", waiting);
  const matched = await queue.enqueue(enqueueInput(playerB, "Verified B", "enqueue-b", nowIso));
  expect(matched.ticket.status === "MATCHED" && matched.session != null, "second player did not match", matched);
  const matchId = matched.ticket.matchId!;
  const session = matched.session!;
  const roster = session.roster as JsonRecord[];
  expect(roster.length === 2 && roster[0].player_id === playerA && roster[1].player_id === playerB,
    "server roster/seat assignment incorrect", session);
  expect(roster[0].seat_id === 1 && roster[0].color_id === "GREEN"
    && roster[1].seat_id === 2 && roster[1].color_id === "PURPLE", "server colors incorrect", roster);
  expect((session.host as JsonRecord).player_id === playerA && (session.guest as JsonRecord).player_id === playerB,
    "compatibility projections diverged from roster", session);
  expect((session.context as JsonRecord).economic === false && (session.context as JsonRecord).ranked === false,
    "standard 1v1 acquired economy/rank side effects", session.context);

  const duplicate = await queue.enqueue(enqueueInput(playerB, "Verified B", "enqueue-b", nowIso));
  expect(duplicate.duplicate && duplicate.ticket.matchId === matchId, "queue retry did not restore receipt", duplicate);
  await expectCode(queue.enqueue({ ...enqueueInput(playerB, "Changed", "enqueue-b", nowIso) }), "idempotency_conflict");
  await expectCode(queue.getSession(matchId, playerC), "player_not_in_match");

  const restarted = new PostgresPublic1v1Repository(pool, new PostgresDurableCoreRepository(pool));
  const restoredA = await restarted.poll(waiting.ticket.ticketId, playerA, new Date().toISOString());
  expect(restoredA.ticket.status === "MATCHED" && restoredA.ticket.matchId === matchId,
    "restart lost matched queue ticket", restoredA);
  await expectCode(restarted.appendCommand({
    matchId, matchEpoch: 1, playerId: playerA, seatId: 1, clientCommandId: uuidV7(),
    issuedTick: 1, requestedExecuteTick: 2, command: { type: "MOVE", lane_id: 1 }, receivedAt: nowIso
  }), "match_not_running");
  const readyA = await restarted.setReady({ matchId, playerId: playerA, requestId: "ready-a", nowIso, ready: true });
  expect((readyA.roster as JsonRecord[])[0].ready === true, "ready state was not persisted", readyA);
  const readyADuplicate = await restarted.setReady({ matchId, playerId: playerA, requestId: "ready-a", nowIso, ready: true });
  expect(readyADuplicate.duplicate === true, "ready retry was not idempotent", readyADuplicate);
  await expectCode(restarted.start({ matchId, playerId: playerA, requestId: "early-start", nowIso }), "roster_not_ready");
  await restarted.setReady({ matchId, playerId: playerB, requestId: "ready-b", nowIso, ready: true });
  const started = await restarted.start({ matchId, playerId: playerA, requestId: "start", nowIso });
  expect(started.lifecycle_status === "RUNNING" && started.status === "started", "match did not start", started);

  const command = await restarted.appendCommand({
    matchId,
    matchEpoch: 1,
    playerId: playerA,
    seatId: 1,
    clientCommandId: uuidV7(),
    issuedTick: 10,
    requestedExecuteTick: 11,
    command: { type: "MOVE", lane_id: 1 },
    receivedAt: nowIso
  });
  expect(command.commandSeq === 1 && command.executeTick === 13, "command was not canonicalized", command);
  const commandPage = await restarted.readCommands(matchId, 1, playerB, 0);
  expect(commandPage.highWaterSeq === 1 && commandPage.events[0].playerId === playerA,
    "opponent could not restore canonical stream", commandPage);

  const reconnecting = await restarted.leave({ matchId, playerId: playerA, requestId: "leave-a", nowIso }, 30);
  expect(reconnecting.lifecycle_status === "RECONNECTING"
    && (reconnecting.roster as JsonRecord[])[0].connection_state === "GRACE", "grace state missing", reconnecting);
  const afterSecondRestart = new PostgresPublic1v1Repository(pool, new PostgresDurableCoreRepository(pool));
  const resumed = await afterSecondRestart.resume(playerA, "resume-a", new Date().toISOString());
  expect(resumed.lifecycle_status === "RUNNING"
    && (resumed.roster as JsonRecord[])[0].seat_id === 1
    && (resumed.roster as JsonRecord[])[0].connection_state === "CONNECTED",
    "restart resume changed seat or failed to reconnect", resumed);

  const ctfPolicy: Public1v1Policy = {
    ...policy,
    modeId: "CTF_1V1",
    clientMode: "CAPTURE_FLAG",
    vsRuleset: "CAPTURE_FLAG",
    rulesetId: "capture-flag-v1",
    rulesetHash: "3".repeat(64),
    mapId: "ctf-closequarters",
    mapHash: "4".repeat(64),
    authorityTier: "AUTHORITY_VERIFIED",
    ranked: false
  };
  const ctfInput = (playerId: string, displayName: string, requestId: string, at: string): EnqueuePublic1v1Input => ({
    requestId, player: { playerId, displayName }, protocolVersion: 2,
    clientBuild: "2026071801", nowIso: at, policy: ctfPolicy
  });
  const ctfWaiting = await afterSecondRestart.enqueue(ctfInput(playerD, "Flag A", "ctf-a", nowIso));
  const ctfMatched = await afterSecondRestart.enqueue(ctfInput(playerE, "Flag B", "ctf-b", nowIso));
  const ctfContext = ctfMatched.session!.context as JsonRecord;
  expect(ctfWaiting.ticket.status === "WAITING" && ctfMatched.ticket.status === "MATCHED",
    "CTF players did not use the durable two-seat queue", ctfMatched);
  expect(ctfContext.mode_id === "CTF_1V1" && ctfContext.vs_mode === "CAPTURE_FLAG"
    && ctfContext.ruleset_hash === ctfPolicy.rulesetHash && ctfContext.map_hash === ctfPolicy.mapHash
    && ctfContext.ranked === false && ctfContext.economic === false && ctfContext.practice === false,
    "CTF contract classification or content hashes incorrect", ctfContext);

  const botQueuedAt = new Date(new Date(nowIso).getTime() + 60_000).toISOString();
  const botWaiting = await afterSecondRestart.enqueue(ctfInput(playerF, "Flag Solo", "ctf-solo", botQueuedAt));
  const earlyOffer = await afterSecondRestart.getBotFallbackOffer(botWaiting.ticket.ticketId, playerF,
    new Date(new Date(botQueuedAt).getTime() + 29_000).toISOString(), 30);
  expect(!earlyOffer.eligible && earlyOffer.remainingSec === 1, "bot fallback offered before server threshold", earlyOffer);
  const botSession = await afterSecondRestart.acceptBotFallback({
    ticketId: botWaiting.ticket.ticketId,
    playerId: playerF,
    requestId: "accept-ctf-bot",
    nowIso: new Date(new Date(botQueuedAt).getTime() + 30_000).toISOString(),
    thresholdSec: 30,
    botProfileId: "ctf-practice-v1",
    botDisplayName: "Capture Flag Practice Bot"
  });
  const botContext = botSession.context as JsonRecord;
  const botRoster = botSession.roster as JsonRecord[];
  expect(botContext.mode_id === "CTF_BOT" && botContext.vs_mode === "CAPTURE_FLAG"
    && botContext.practice === true && botContext.bot_fill === true
    && botContext.ranked === false && botContext.economic === false,
    "accepted bot fallback was not isolated as practice", botContext);
  expect(botRoster[1].participant_type === "BOT" && botRoster[1].uid === "bot_ctf-practice-v1",
    "bot fallback did not use the canonical server bot identity", botRoster);
  const cancelledSource = await afterSecondRestart.poll(botWaiting.ticket.ticketId, playerF,
    new Date(new Date(botQueuedAt).getTime() + 31_000).toISOString());
  expect(cancelledSource.ticket.status === "CANCELLED", "bot fallback left human search active", cancelledSource);
  const botDuplicate = await afterSecondRestart.acceptBotFallback({
    ticketId: botWaiting.ticket.ticketId, playerId: playerF, requestId: "accept-ctf-bot",
    nowIso: new Date(new Date(botQueuedAt).getTime() + 32_000).toISOString(), thresholdSec: 30,
    botProfileId: "ctf-practice-v1", botDisplayName: "Capture Flag Practice Bot"
  });
  expect(botDuplicate.duplicate === true && botDuplicate.match_id === botSession.match_id,
    "bot fallback acceptance was not idempotent", botDuplicate);

  const counts = await pool.query<Record<string, unknown>>(
    `SELECT
       (SELECT count(*)::int FROM vs_match_queue_tickets) AS tickets,
       (SELECT count(*)::int FROM vs_match_contracts) AS contracts,
       (SELECT count(*)::int FROM vs_match_lifecycle_events) AS lifecycle_events,
       (SELECT count(*)::int FROM vs_command_events) AS commands`
  );
  console.log(JSON.stringify({
    ok: true,
    smoke: "durable_public_1v1_embedded",
    restart_restore: true,
    canonical_roster: true,
    human_ctf_contract: true,
    explicit_ctf_bot_fallback: true,
    counts: counts.rows[0]
  }));
  await db.close();
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
