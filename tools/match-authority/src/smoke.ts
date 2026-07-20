import crypto from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { canonicalJson, sha256Canonical } from "./canonical.js";
import { AuthorityError, buildLifecyclePayload, buildPayload, replayJobTwice, validateJobBundle, type Job, type WorkerConfig } from "./worker.js";

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

async function main(): Promise<void> {
  const projectPath = path.resolve(import.meta.dirname, "../../..");
  const mapRelative = "tools/match-authority/fixtures/authority-map.json";
  const rulesRelative = "tools/match-authority/fixtures/standard-rules.json";
  const [mapBytes, rulesBytes] = await Promise.all([
    readFile(path.join(projectPath, mapRelative)), readFile(path.join(projectPath, rulesRelative))
  ]);
  const mapHash = crypto.createHash("sha256").update(mapBytes).digest("hex");
  const rulesHash = crypto.createHash("sha256").update(rulesBytes).digest("hex");
  const keyPair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const privateKey = keyPair.privateKey.export({ format: "pem", type: "pkcs8" }).toString();
  const publicKey = keyPair.publicKey.export({ format: "pem", type: "spki" }).toString();
  const tempDir = await mkdtemp(path.join(tmpdir(), "sf-authority-smoke-"));
  const manifestPath = path.join(tempDir, "manifest.json");
  await writeFile(manifestPath, JSON.stringify({
    worker_build_id: "authority-worker-smoke-v1",
    sim_build_id: "godot-4.2.2-smoke",
    project_path: projectPath,
    map_artifacts: { [mapHash]: mapRelative, ["0".repeat(64)]: mapRelative },
    ruleset_artifacts: { [rulesHash]: rulesRelative }
  }));
  const playerA = "0190f47a-1234-7abc-8def-123456789abc";
  const playerB = "0190f47a-2234-7abc-8def-123456789abc";
  const job: Job = {
    jobId: "0190f47a-3234-7abc-8def-123456789abc",
    resultId: "0190f47a-4234-7abc-8def-123456789abc",
    leaseToken: "0190f47a-5234-7abc-8def-123456789abc",
    attempt: 1,
    receiptIssuedAt: "2026-07-18T00:00:00.000Z",
    inputHash: "1".repeat(64),
    authorityMethod: "SIM_REPLAY",
    finalCommandSeq: 1,
    commandLogHash: "2".repeat(64),
    contract: {
      contractId: "0190f47a-6234-7abc-8def-123456789abc",
      matchId: "0190f47a-7234-7abc-8def-123456789abc",
      matchEpoch: 1,
      contractHash: "3".repeat(64),
      protocolVersion: 2,
      modeId: "STANDARD_1V1",
      seed: "42",
      authorityTier: "AUTHORITY_VERIFIED",
      simBuildId: "godot-4.2.2-smoke",
      mapHash,
      rulesetHash: rulesHash,
      roster: [
        { playerId: playerA, seatId: 1, teamId: 1 },
        { playerId: playerB, seatId: 2, teamId: 2 }
      ]
    },
    commands: [{ command: {
      command_seq: 1, command_id: "smoke:1", kind: "lane_intent", seat_id: 1,
      src: 1, dst: 2, intent: "attack", execute_tick: 1
    }}]
  };
  const config: WorkerConfig = {
    baseUrl: "", workerToken: "", workerId: "authority-smoke", workerBuildId: "authority-worker-smoke-v1",
    verifierKeyId: "authority-key-smoke", verifierPrivateKeyPem: privateKey,
    artifactManifestPath: manifestPath, godotBin: process.env.MATCH_AUTHORITY_GODOT_BIN?.trim() || "godot",
    pollMs: 100, replayTimeoutMs: 30_000, runOnce: true
  };
  try {
    const commandPayloads = job.commands.map((entry) => entry.command);
    job.commandLogHash = sha256Canonical(commandPayloads);
    job.inputHash = sha256Canonical({
      contract_id: job.contract.contractId,
      contract_hash: job.contract.contractHash,
      match_epoch: job.contract.matchEpoch,
      commands: commandPayloads,
      lifecycle_events: []
    });
    validateJobBundle(job);
    try {
      validateJobBundle({ ...job, commandLogHash: "0".repeat(64) });
      throw new Error("tampered command binding was accepted");
    } catch (error) {
      expect(error instanceof AuthorityError && error.code === "JOB_COMMAND_BINDING_MISMATCH",
        "tampered command binding did not fail closed", error instanceof Error ? error.message : error);
    }
    const [first, second] = await replayJobTwice(config, job);
    expect(first.ok && second.ok && first.final_state_hash === second.final_state_hash,
      "headless replays diverged", { first, second });
    const ctfJob: Job = {
      ...job,
      jobId: "0190f47a-a234-7abc-8def-123456789abc",
      resultId: "0190f47a-b234-7abc-8def-123456789abc",
      contract: {
        ...job.contract,
        contractId: "0190f47a-c234-7abc-8def-123456789abc",
        matchId: "0190f47a-d234-7abc-8def-123456789abc",
        modeId: "CTF_1V1",
        seed: "84"
      }
    };
    ctfJob.inputHash = sha256Canonical({
      contract_id: ctfJob.contract.contractId,
      contract_hash: ctfJob.contract.contractHash,
      match_epoch: ctfJob.contract.matchEpoch,
      commands: commandPayloads,
      lifecycle_events: []
    });
    validateJobBundle(ctfJob);
    const [ctfFirst, ctfSecond] = await replayJobTwice(config, ctfJob);
    expect(ctfFirst.ok && ctfSecond.ok && ctfFirst.final_state_hash === ctfSecond.final_state_hash
      && ctfFirst.winner_player_id === playerA,
      "visible CTF did not replay deterministically on the certified authority path", { ctfFirst, ctfSecond });
    const winner = buildPayload(job, first, second, config);
    const winnerPlacements = winner.placements as Record<string, unknown>[];
    expect(winner.terminal_reason === "OBJECTIVE_COMPLETE"
      && winnerPlacements.length === 2 && winnerPlacements[0]?.player_ids instanceof Array,
      "winner receipt invalid", winner);
    const conflict = buildPayload(job, first, { ...second, final_state_hash: "f".repeat(64) }, config);
    expect(conflict.terminal_reason === "NO_CONTEST" && conflict.no_contest_reason === "VERIFIER_DISAGREEMENT"
      && (conflict.placements as unknown[]).length === 0, "disagreement did not no-contest", conflict);
    const lifecycle = buildLifecyclePayload({
      ...job,
      authorityMethod: "SERVER_LIFECYCLE",
      lifecycleEvents: [{
        event_id: "0190f47a-8234-7abc-8def-123456789abc",
        event_type: "MATCH_FORFEITED",
        event_payload: { winner_player_id: playerB, forfeit_kind: "DISCONNECT", elapsed_sim_ticks: 12 }
      }]
    }, config);
    expect(lifecycle.terminal_reason === "FORFEIT_DISCONNECT" && lifecycle.final_state_hash == null
      && (((lifecycle.placements as Record<string, unknown>[])[0]!).player_ids as string[])[0] === playerB,
      "trusted lifecycle forfeit receipt invalid", lifecycle);
    const lifecycleNoContest = buildLifecyclePayload({
      ...job,
      authorityMethod: "SERVER_LIFECYCLE",
      lifecycleEvents: [{
        event_id: "0190f47a-9234-7abc-8def-123456789abc",
        event_type: "MATCH_NO_CONTEST",
        event_payload: { no_contest_reason: "SERVER_RESTART", elapsed_sim_ticks: 12 }
      }]
    }, config);
    expect(lifecycleNoContest.terminal_reason === "NO_CONTEST"
      && lifecycleNoContest.no_contest_reason === "SERVER_RESTART",
      "trusted lifecycle no-contest receipt invalid", lifecycleNoContest);
    try {
      await replayJobTwice(config, {
        ...job,
        contract: { ...job.contract, mapHash: "0".repeat(64) }
      });
      throw new Error("wrong map hash was accepted");
    } catch (error) {
      expect(error instanceof AuthorityError && error.code === "MAP_HASH_MISMATCH",
        "wrong map artifact did not fail closed", error instanceof Error ? error.message : error);
    }
    const payloadHash = sha256Canonical(winner);
    const signature = crypto.sign("sha256", Buffer.from(canonicalJson(winner)), {
      key: privateKey, dsaEncoding: "ieee-p1363"
    });
    expect(payloadHash.length === 64 && crypto.verify("sha256", Buffer.from(canonicalJson(winner)), {
      key: publicKey, dsaEncoding: "ieee-p1363"
    }, signature), "receipt signature failed");
    console.log(JSON.stringify({ ok: true, smoke: "match_authority", deterministic_hash: first.final_state_hash,
      elapsed_sim_ticks: first.elapsed_sim_ticks, disagreement: "NO_CONTEST", lifecycle_forfeit: true,
      lifecycle_no_contest: true, human_ctf_replay: true, wrong_map_rejected: true,
      command_binding_rejected: true, signature: "ES256" }));
  } finally {
    await rm(tempDir, { recursive: true, force: true });
  }
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
