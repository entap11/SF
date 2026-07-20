import type { Pool } from "pg";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { runMigrations } from "../db/migrate.js";
import {
  DurableCoreError,
  sha256Canonical,
  uuidV7,
  type CreateContractInput,
  type DurableCoreRepository
} from "./durableCore.js";
import { MemoryDurableCoreRepository } from "./memoryDurableCoreRepository.js";
import { PostgresDurableCoreRepository } from "./postgresDurableCoreRepository.js";
import { PGlitePoolAdapter } from "./pglitePoolAdapter.js";

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

function contractInput(now: Date, playerA: string, playerB: string): CreateContractInput {
  const joinedAt = now.toISOString();
  return {
    requestId: "queue-request-0001",
    idempotencySubject: `${playerA}:STANDARD_1V1`,
    legacySessionId: "S00000001",
    minimumClientBuild: "2026071801",
    simBuildId: "godot-4.2.2-swarmfront-smoke",
    modeId: "STANDARD_1V1",
    rulesetId: "standard-v1",
    rulesetHash: "1".repeat(64),
    mapId: "closequarters",
    mapHash: "2".repeat(64),
    seed: "42",
    authorityTier: "RELAY_ATTESTED",
    status: "RUNNING",
    assignmentPolicyId: "SERVER_SEATS_V1",
    roster: [
      {
        playerId: playerA,
        displayName: "Durable A",
        participantType: "HUMAN",
        seatId: 1,
        teamId: 1,
        colorId: "GREEN",
        readyState: "LOCKED",
        connectionState: "CONNECTED",
        joinedAt
      },
      {
        playerId: playerB,
        displayName: "Durable B",
        participantType: "HUMAN",
        seatId: 2,
        teamId: 2,
        colorId: "PURPLE",
        readyState: "LOCKED",
        connectionState: "CONNECTED",
        joinedAt
      }
    ],
    rankPolicy: { enabled: false, queue: "GLOBAL_RANK" },
    economyPolicy: { policy_id: "NONE" },
    practicePolicy: { practice: false, bot_fill: false },
    createdAt: joinedAt,
    expiresAt: new Date(now.getTime() + 15 * 60_000).toISOString()
  };
}

async function exerciseRepository(repository: DurableCoreRepository, input: CreateContractInput): Promise<{
  contractId: string;
  matchId: string;
  playerA: string;
  outboxEventId: string;
}> {
  const playerA = input.roster[0].playerId!;
  const playerB = input.roster[1].playerId!;
  const created = await repository.createContract(input);
  expect(!created.duplicate, "contract create failed", created);
  expect(/^.{8}-.{4}-7/.test(created.contract.contractId) && /^.{8}-.{4}-7/.test(created.contract.matchId),
    "contract IDs are not UUIDv7", created.contract);
  expect(created.contract.roster.length === 2 && created.contract.contractHash.length === 64,
    "contract/roster materialization failed", created.contract);

  const duplicate = await repository.createContract(input);
  expect(duplicate.duplicate && duplicate.contract.contractId === created.contract.contractId,
    "contract idempotency failed", duplicate);
  await expectCode(repository.createContract({ ...input, mapId: "conflicting-map" }), "idempotency_conflict");

  const commandOne = await repository.appendCommand({
    matchId: created.contract.matchId,
    matchEpoch: 1,
    playerId: playerA,
    seatId: 1,
    clientCommandId: "019f77c0-0001-7000-8000-000000000001",
    issuedTick: 10,
    requestedExecuteTick: 11,
    command: { type: "MOVE", lane_id: 1 },
    receivedAt: new Date().toISOString()
  });
  expect(commandOne.commandSeq === 1 && commandOne.executeTick === 13 && !commandOne.duplicate,
    "first command was not durably canonicalized", commandOne);
  const commandDuplicate = await repository.appendCommand({
    matchId: created.contract.matchId,
    matchEpoch: 1,
    playerId: playerA,
    seatId: 1,
    clientCommandId: "019f77c0-0001-7000-8000-000000000001",
    issuedTick: 10,
    requestedExecuteTick: 11,
    command: { type: "MOVE", lane_id: 1 },
    receivedAt: new Date(Date.now() + 1_000).toISOString()
  });
  expect(commandDuplicate.duplicate && commandDuplicate.commandSeq === 1,
    "command retry did not return original receipt", commandDuplicate);
  await expectCode(repository.appendCommand({
    matchId: created.contract.matchId,
    matchEpoch: 1,
    playerId: playerA,
    seatId: 1,
    clientCommandId: "019f77c0-0001-7000-8000-000000000001",
    issuedTick: 10,
    requestedExecuteTick: 11,
    command: { type: "MOVE", lane_id: 2 },
    receivedAt: new Date().toISOString()
  }), "idempotency_conflict");
  const commandTwo = await repository.appendCommand({
    matchId: created.contract.matchId,
    matchEpoch: 1,
    playerId: playerB,
    seatId: 2,
    clientCommandId: "019f77c0-0002-7000-8000-000000000002",
    issuedTick: 10,
    requestedExecuteTick: 12,
    command: { type: "BUFF", lane_id: 2 },
    receivedAt: new Date().toISOString()
  });
  expect(commandTwo.commandSeq === 2 && commandTwo.executeTick === 14,
    "command ordering/high-water failed", commandTwo);

  const graceDeadline = new Date(Date.now() + 30_000).toISOString();
  await repository.setReconnectState({
    matchId: created.contract.matchId,
    playerId: playerA,
    matchEpoch: 1,
    reconnectEpoch: 1,
    connectionState: "GRACE",
    graceDeadlineAt: graceDeadline,
    lastSeenAt: new Date().toISOString()
  });

  const outbox = await repository.enqueueOutbox({
    topic: "match.result.ready",
    recipientPlayerId: playerA,
    aggregateType: "MATCH",
    aggregateId: created.contract.matchId,
    dedupeNamespace: "outbox.delivery.v1",
    dedupeKey: `${created.contract.matchId}:${playerA}:result`,
    payload: { match_id: created.contract.matchId, state: "VERIFYING" },
    availableAt: input.createdAt
  });
  expect(!outbox.duplicate, "outbox create marked duplicate", outbox);
  return { contractId: created.contract.contractId, matchId: created.contract.matchId, playerA, outboxEventId: outbox.eventId };
}

async function main(): Promise<void> {
  const playerA = uuidV7();
  const playerB = uuidV7();
  const input = contractInput(new Date(), playerA, playerB);

  const memory = new MemoryDurableCoreRepository();
  const memoryState = await exerciseRepository(memory, input);
  const memoryPage = await memory.readCommands(memoryState.matchId, 1, 0);
  expect(memoryPage.highWaterSeq === 2 && memoryPage.events.length === 2, "memory adapter parity failed", memoryPage);

  const db = new PGlite({ extensions: { pgcrypto } });
  await db.waitReady;
  const adapter = new PGlitePoolAdapter(db);
  const pool = adapter as unknown as Pool;
  await runMigrations(pool);
  const firstStore = new PostgresDurableCoreRepository(pool);
  const state = await exerciseRepository(firstStore, input);

  const restartedStore = new PostgresDurableCoreRepository(pool);
  const retriedContract = await restartedStore.createContract(input);
  expect(retriedContract.duplicate && retriedContract.contract.contractId === state.contractId,
    "restart contract retry did not return original receipt", retriedContract);
  const retriedCommand = await restartedStore.appendCommand({
    matchId: state.matchId,
    matchEpoch: 1,
    playerId: state.playerA,
    seatId: 1,
    clientCommandId: "019f77c0-0001-7000-8000-000000000001",
    issuedTick: 10,
    requestedExecuteTick: 11,
    command: { type: "MOVE", lane_id: 1 },
    receivedAt: new Date().toISOString()
  });
  expect(retriedCommand.duplicate && retriedCommand.commandSeq === 1 && retriedCommand.executeTick === 13,
    "restart command retry did not return original receipt", retriedCommand);
  const retriedOutbox = await restartedStore.enqueueOutbox({
    topic: "match.result.ready",
    recipientPlayerId: state.playerA,
    aggregateType: "MATCH",
    aggregateId: state.matchId,
    dedupeNamespace: "outbox.delivery.v1",
    dedupeKey: `${state.matchId}:${state.playerA}:result`,
    payload: { match_id: state.matchId, state: "VERIFYING" },
    availableAt: input.createdAt
  });
  expect(retriedOutbox.duplicate && retriedOutbox.eventId === state.outboxEventId,
    "restart outbox retry did not return original event", retriedOutbox);
  await expectCode(restartedStore.enqueueOutbox({
    topic: "match.result.ready",
    recipientPlayerId: state.playerA,
    aggregateType: "MATCH",
    aggregateId: state.matchId,
    dedupeNamespace: "outbox.delivery.v1",
    dedupeKey: `${state.matchId}:${state.playerA}:result`,
    payload: { match_id: state.matchId, state: "CONFLICTING" },
    availableAt: input.createdAt
  }), "idempotency_conflict");
  const restoredContract = await restartedStore.getContractByMatchId(state.matchId);
  const restoredCommands = await restartedStore.readCommands(state.matchId, 1, 0);
  const restoredReconnect = await restartedStore.getReconnectStates(state.matchId);
  const pendingOutbox = await restartedStore.listPendingOutbox(state.playerA, 20);
  expect(restoredContract?.contractId === state.contractId, "restart lost contract", restoredContract);
  expect(restoredCommands.highWaterSeq === 2 && restoredCommands.events.map((event) => event.commandSeq).join(",") === "1,2",
    "restart lost contiguous command stream", restoredCommands);
  expect(restoredReconnect.length === 1 && restoredReconnect[0].connectionState === "GRACE",
    "restart lost reconnect deadline", restoredReconnect);
  expect(pendingOutbox.length === 1 && pendingOutbox[0].eventId === state.outboxEventId,
    "restart lost outbox event", pendingOutbox);

  const commandLogHash = sha256Canonical(restoredCommands.events.map((event) => event.command));
  const resultId = uuidV7();
  const resultInput = {
    resultId,
    matchId: state.matchId,
    contractId: state.contractId,
    matchEpoch: 1,
    terminalReason: "NO_CONTEST",
    contractHash: restoredContract!.contractHash,
    finalCommandSeq: restoredCommands.highWaterSeq,
    commandLogHash,
    result: {
      result_id: resultId,
      match_id: state.matchId,
      contract_id: state.contractId,
      match_epoch: 1,
      result_schema_version: 1,
      terminal_reason: "NO_CONTEST",
      no_contest_reason: "ADMINISTRATIVE_CANCELLATION",
      placements: [],
      final_command_seq: restoredCommands.highWaterSeq,
      command_log_hash: commandLogHash
    },
    verifiedAt: new Date().toISOString()
  };
  await expectCode(restartedStore.saveTerminalResult({
    ...resultInput,
    commandLogHash: "0".repeat(64)
  }), "result_command_log_hash_mismatch");
  const result = await restartedStore.saveTerminalResult(resultInput);
  const resultDuplicate = await restartedStore.saveTerminalResult(resultInput);
  expect(!result.duplicate && resultDuplicate.duplicate && result.payloadHash === resultDuplicate.payloadHash,
    "terminal result idempotency failed", { result, resultDuplicate });
  await expectCode(restartedStore.saveTerminalResult({
    ...resultInput,
    result: { ...resultInput.result, no_contest_reason: "VERIFIER_FAILURE" }
  }), "idempotency_conflict");

  const acknowledged = await restartedStore.acknowledgeOutbox(state.outboxEventId, state.playerA, new Date().toISOString());
  const acknowledgedAgain = await restartedStore.acknowledgeOutbox(state.outboxEventId, state.playerA, new Date().toISOString());
  expect(acknowledged.status === "DELIVERED" && acknowledged.deliveryAttempts === 1
    && acknowledgedAgain.deliveryAttempts === 1, "outbox acknowledgement was not idempotent", acknowledgedAgain);

  const counts = await adapter.query<{ contracts: string; roster: string; commands: string; results: string; outbox: string }>(`
    SELECT
      (SELECT count(*)::text FROM vs_match_contracts) AS contracts,
      (SELECT count(*)::text FROM vs_match_roster) AS roster,
      (SELECT count(*)::text FROM vs_command_events) AS commands,
      (SELECT count(*)::text FROM vs_terminal_results) AS results,
      (SELECT count(*)::text FROM vs_outbox_events) AS outbox
  `);
  expect(JSON.stringify(counts.rows[0]) === JSON.stringify({ contracts: "1", roster: "2", commands: "2", results: "1", outbox: "1" }),
    "durable row counts mismatch", counts.rows[0]);
  await db.close();
  console.log(JSON.stringify({
    ok: true,
    smoke: "durable_core_embedded",
    migrations: 4,
    restart_restore: true,
    command_high_water: 2,
    terminal_result: "NO_CONTEST",
    outbox_ack_idempotent: true
  }));
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
