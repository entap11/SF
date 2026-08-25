import { readFile } from "node:fs/promises";
import pg from "../../tools/vs-service/node_modules/pg/lib/index.js";
import { PostgresDurableCoreRepository } from "../../tools/vs-service/dist/repositories/postgresDurableCoreRepository.js";
import { PostgresVerificationRepository } from "../../tools/vs-service/dist/repositories/postgresVerificationRepository.js";
import { uuidV7 } from "../../tools/vs-service/dist/repositories/durableCore.js";

const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.VS_DATABASE_URL, ssl: { rejectUnauthorized: false }, max: 2 });
const core = new PostgresDurableCoreRepository(pool);
const verification = new PostgresVerificationRepository(pool, core);
const mode = process.argv.at(-1) ?? "";
const mapHash = "325e97a6677eb32e2f396fa9077b614c76a2150dad960243e8ae00b55909d14a";
const rulesHash = "d7a78887b71c7d010db1b8ea1af84aa847ca877644878f6c3a0d96aed26aa57c";
const simBuildId = process.env.P5_SIM_BUILD_ID?.trim() ?? "";
const canaryPlayerA = process.env.ECONOMY_CANARY_PLAYER_A?.trim().toLowerCase() ?? "";
const canaryPlayerB = process.env.ECONOMY_CANARY_PLAYER_B?.trim().toLowerCase() ?? "";
const managedCommandTickOffset = 2;
if (!simBuildId) throw new Error("P5_SIM_BUILD_ID is required");

function requiredUuid(value, name) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value)) {
    throw new Error(`${name} is required and must be a UUID`);
  }
  return value;
}

function contractInput(label, nowIso, overrides = {}) {
  const economyCanary = label === "economy-canary";
  const playerA = economyCanary ? requiredUuid(canaryPlayerA, "ECONOMY_CANARY_PLAYER_A") : uuidV7();
  const playerB = economyCanary ? requiredUuid(canaryPlayerB, "ECONOMY_CANARY_PLAYER_B") : uuidV7();
  if (playerA === playerB) throw new Error("canary players must be distinct");
  return {
    playerA,
    playerB,
    input: {
      requestId: `p5-${label}-${uuidV7()}`,
      idempotencySubject: `p5-certification:${label}:${uuidV7()}`,
      minimumClientBuild: "2026071701",
      simBuildId: overrides.simBuildId ?? simBuildId,
      modeId: "STANDARD_1V1",
      rulesetId: "standard-v1",
      rulesetHash: overrides.rulesetHash ?? rulesHash,
      mapId: "MAP_closequarters__CQ2__1p",
      mapHash: overrides.mapHash ?? mapHash,
      seed: "42",
      authorityTier: "AUTHORITY_VERIFIED",
      status: "RUNNING",
      assignmentPolicyId: "SERVER_SEATS_COLORS_V1",
      roster: [
        { playerId: playerA, displayName: "P5 A", participantType: "HUMAN", seatId: 1,
          teamId: 1, colorId: "GREEN", readyState: "LOCKED", connectionState: "CONNECTED", joinedAt: nowIso },
        { playerId: playerB, displayName: "P5 B", participantType: "HUMAN", seatId: 2,
          teamId: 2, colorId: "PURPLE", readyState: "LOCKED", connectionState: "CONNECTED", joinedAt: nowIso }
      ],
      rankPolicy: economyCanary
        ? { enabled: true, policy_id: "BETA_STANDARD_WAX_V1" }
        : { enabled: false, policy_id: "P5_CERTIFICATION_NONE" },
      economyPolicy: { policy_id: "NONE" },
      practicePolicy: { practice: !economyCanary },
      createdAt: nowIso,
      expiresAt: new Date(Date.parse(nowIso) + 900_000).toISOString()
    }
  };
}

async function prepareReplay(label, overrides = {}) {
  const nowIso = new Date().toISOString();
  const spec = contractInput(label, nowIso, overrides);
  const created = await core.createContract(spec.input);
  const fixture = JSON.parse(await readFile(new URL("../../tools/match-authority/fixtures/closequarters-standard-golden-intents.json", import.meta.url), "utf8"));
  for (const intent of fixture.intents) {
    const executeTick = intent.execute_tick + managedCommandTickOffset;
    await core.appendCommand({
      matchId: created.contract.matchId,
      matchEpoch: created.contract.matchEpoch,
      playerId: intent.seat_id === 1 ? spec.playerA : spec.playerB,
      seatId: intent.seat_id,
      clientCommandId: uuidV7(),
      issuedTick: Math.max(0, executeTick - 3),
      requestedExecuteTick: executeTick,
      command: { kind: "lane_intent", src: intent.src, dst: intent.dst, intent: intent.intent },
      receivedAt: nowIso
    });
  }
  for (const [index, playerId] of [spec.playerA, spec.playerB].entries()) {
    await verification.submitClientReport({
      matchId: created.contract.matchId,
      playerId,
      requestId: `p5-${label}-report-${index + 1}`,
      finalStateHash: `${index + 1}`.repeat(64),
      elapsedSimTicks: 9999 + index,
      claimedTerminalReason: "OBJECTIVE_COMPLETE",
      claimedWinnerPlayerId: spec.playerB,
      diagnostics: { certification: "P5", deliberately_untrusted_claim: true },
      submittedAt: nowIso
    });
  }
  return jobSummary(created.contract.matchId, label);
}

async function prepareLifecycle(label, simultaneous) {
  const nowIso = new Date().toISOString();
  const spec = contractInput(label, nowIso);
  const created = await core.createContract(spec.input);
  const deadline = new Date(Date.parse(nowIso) - 5_000).toISOString();
  const players = simultaneous ? [spec.playerA, spec.playerB] : [spec.playerB];
  for (const playerId of players) {
    await core.setReconnectState({
      matchId: created.contract.matchId, playerId, matchEpoch: 1, reconnectEpoch: 1,
      connectionState: "GRACE", graceDeadlineAt: deadline, lastSeenAt: deadline
    });
  }
  await core.updateContractStatus(created.contract.contractId, "RECONNECTING", nowIso);
  const expired = await verification.expireReconnectGrace(nowIso, 25);
  if (expired !== 1) throw new Error(`lifecycle fixture did not expire exactly one contract: ${expired}`);
  return jobSummary(created.contract.matchId, label);
}

async function jobSummary(matchId, label) {
  const result = await pool.query(
    `SELECT job_id, match_id, contract_hash, input_hash, authority_method, status, attempt_count,
            receipt_issued_at FROM vs_match_verification_jobs WHERE match_id = $1`,
    [matchId]
  );
  if (result.rowCount !== 1) throw new Error(`expected one verification job for ${label}`);
  return { ok: true, label, ...result.rows[0] };
}

async function snapshot() {
  const result = await pool.query(`SELECT
    (SELECT count(*)::int FROM vs_match_contracts) AS contracts,
    (SELECT count(*)::int FROM vs_command_events) AS commands,
    (SELECT count(*)::int FROM vs_match_client_terminal_reports) AS reports,
    (SELECT count(*)::int FROM vs_match_verification_jobs) AS jobs,
    (SELECT count(*)::int FROM vs_match_verification_runs) AS runs,
    (SELECT count(*)::int FROM vs_terminal_results) AS results,
    (SELECT count(*)::int FROM vs_verifier_signed_receipts) AS receipts,
    (SELECT count(*)::int FROM vs_rank_settlement_jobs) AS rank_jobs,
    (SELECT count(*)::int FROM vs_rank_settlement_attempts) AS rank_attempts,
    (SELECT count(*)::int FROM vs_public_match_history) AS history,
    (SELECT count(*)::int FROM vs_outbox_events) AS outbox,
    (SELECT count(*)::int FROM vs_crucible_escrows) AS crucible_escrows,
    (SELECT count(*)::int FROM vs_crucible_journal_entries) AS crucible_journal,
    (SELECT count(*)::int FROM vs_crucible_settlements) AS crucible_settlements`);
  return { ok: true, label: "snapshot", counts: result.rows[0] };
}

async function matrixStatus() {
  const result = await pool.query(`SELECT j.job_id, j.status, j.authority_method, j.attempt_count,
    j.last_error_code, j.contract_hash, j.input_hash, c.map_hash, c.ruleset_hash, c.sim_build_id,
    r.worker_build_id, r.final_state_hash, r.status AS run_status, t.terminal_reason
    FROM vs_match_verification_jobs j
    JOIN vs_match_contracts c ON c.contract_id = j.contract_id
    LEFT JOIN LATERAL (
      SELECT worker_build_id, final_state_hash, status FROM vs_match_verification_runs
      WHERE job_id = j.job_id ORDER BY attempt DESC, finished_at DESC LIMIT 1
    ) r ON true
    LEFT JOIN vs_terminal_results t ON t.result_id = j.result_id
    ORDER BY j.created_at, j.job_id`);
  return { ok: true, label: "status", jobs: result.rows };
}

try {
  let output;
  if (mode === "snapshot") output = await snapshot();
  else if (mode === "status") output = await matrixStatus();
  else if (mode === "replay-positive") output = await prepareReplay(mode);
  else if (mode === "economy-canary") output = await prepareReplay(mode);
  else if (mode === "replay-restart") output = await prepareReplay(mode);
  else if (mode === "negative-map") output = await prepareReplay(mode, { mapHash: "a".repeat(64) });
  else if (mode === "negative-rules") output = await prepareReplay(mode, { rulesetHash: "b".repeat(64) });
  else if (mode === "negative-sim") output = await prepareReplay(mode, { simBuildId: "sf-sim-unavailable" });
  else if (mode === "lifecycle-forfeit") output = await prepareLifecycle(mode, false);
  else if (mode === "lifecycle-no-contest") output = await prepareLifecycle(mode, true);
  else throw new Error(`unknown mode: ${mode}`);
  console.log(`P5_MANAGED_FIXTURE ${JSON.stringify(output)}`);
} finally {
  await pool.end();
}
