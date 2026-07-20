import crypto from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { canonicalJson, sha256Canonical } from "./canonical.js";

type RecordJson = Record<string, unknown>;
export type Job = RecordJson & { contract: RecordJson; commands: RecordJson[] };
export type ReplayResult = RecordJson & { ok: boolean };

export type WorkerConfig = {
  baseUrl: string; workerToken: string; workerId: string; workerBuildId: string;
  verifierKeyId: string; verifierPrivateKeyPem: string; artifactManifestPath: string;
  godotBin: string; pollMs: number; replayTimeoutMs: number; runOnce: boolean;
};

export async function runOne(config: WorkerConfig, replayOverride?: (job: Job) => Promise<[ReplayResult, ReplayResult]>): Promise<boolean> {
  const leased = await action(config, "lease_match_verification", { worker_id: config.workerId });
  const job = leased.job as Job | null;
  if (!job) return false;
  const startedAt = new Date().toISOString();
  try {
    validateJobBundle(job);
    const outputs = String(job.authorityMethod) === "SERVER_LIFECYCLE"
      ? null
      : replayOverride ? await replayOverride(job) : await replayTwice(config, job);
    const payload = outputs == null
      ? buildLifecyclePayload(job, config)
      : buildPayload(job, outputs[0], outputs[1], config);
    const payloadHash = sha256Canonical(payload);
    const signature = crypto.sign("sha256", Buffer.from(canonicalJson(payload), "utf8"), {
      key: config.verifierPrivateKeyPem,
      dsaEncoding: "ieee-p1363"
    }).toString("base64url");
    await action(config, "complete_match_verification", {
      worker_id: config.workerId,
      job_id: job.jobId,
      lease_token: job.leaseToken,
      started_at: startedAt,
      signed_result: {
        payload,
        payload_hash: payloadHash,
        key_id: config.verifierKeyId,
        algorithm: "ES256",
        signature
      },
      run_diagnostics: outputs == null
        ? { authority_method: "SERVER_LIFECYCLE" }
        : { replay_a: outputs[0], replay_b: outputs[1] }
    });
    return true;
  } catch (error) {
    const code = error instanceof AuthorityError ? error.code : "WORKER_EXCEPTION";
    await action(config, "fail_match_verification", {
      worker_id: config.workerId,
      job_id: job.jobId,
      lease_token: job.leaseToken,
      started_at: startedAt,
      retryable: error instanceof AuthorityError ? error.retryable : true,
      error_code: code,
      diagnostics: { message: error instanceof Error ? error.message : String(error) }
    });
    return true;
  }
}

export function validateJobBundle(job: Job): void {
  const contract = job.contract;
  const commandPayloads = job.commands.map((entry) => asRecord(entry.command));
  const lifecycleEvents = Array.isArray(job.lifecycleEvents) ? job.lifecycleEvents : [];
  const inputHash = sha256Canonical({
    contract_id: contract.contractId,
    contract_hash: contract.contractHash,
    match_epoch: contract.matchEpoch,
    commands: commandPayloads,
    lifecycle_events: lifecycleEvents
  });
  if (inputHash !== job.inputHash) throw new AuthorityError("JOB_INPUT_HASH_MISMATCH", false);
  const finalSeq = commandPayloads.length === 0 ? 0 : Number(commandPayloads.at(-1)?.command_seq ?? -1);
  if (finalSeq !== job.finalCommandSeq || sha256Canonical(commandPayloads) !== job.commandLogHash) {
    throw new AuthorityError("JOB_COMMAND_BINDING_MISMATCH", false);
  }
}

export function buildLifecyclePayload(job: Job, config: WorkerConfig): RecordJson {
  if (String(job.authorityMethod) !== "SERVER_LIFECYCLE") {
    throw new AuthorityError("LIFECYCLE_AUTHORITY_METHOD_REQUIRED", false);
  }
  const events = Array.isArray(job.lifecycleEvents) ? job.lifecycleEvents as RecordJson[] : [];
  const terminals = events.filter((event) => ["MATCH_FORFEITED", "MATCH_NO_CONTEST"].includes(String(event.event_type ?? "")));
  if (terminals.length !== 1) throw new AuthorityError("LIFECYCLE_TERMINAL_AMBIGUOUS", false);
  const terminal = terminals[0]!;
  const eventPayload = asRecord(terminal.event_payload);
  const eventType = String(terminal.event_type);
  const contract = job.contract;
  const roster = contract.roster as RecordJson[];
  const playerIds = roster.map((entry) => String(entry.playerId ?? entry.player_id ?? "")).filter(Boolean);
  const noContest = eventType === "MATCH_NO_CONTEST";
  const winner = String(eventPayload.winner_player_id ?? "");
  const loser = playerIds.find((id) => id !== winner) ?? "";
  const forfeitKind = String(eventPayload.forfeit_kind ?? "");
  if (!noContest && (!playerIds.includes(winner) || !loser || !["DISCONNECT", "VOLUNTARY"].includes(forfeitKind))) {
    throw new AuthorityError("LIFECYCLE_FORFEIT_INVALID", false);
  }
  const noContestReason = String(eventPayload.no_contest_reason ?? "");
  if (noContest && !noContestReason) throw new AuthorityError("LIFECYCLE_NO_CONTEST_REASON_REQUIRED", false);
  const elapsed = Number(eventPayload.elapsed_sim_ticks ?? 0);
  if (!Number.isSafeInteger(elapsed) || elapsed < 0) throw new AuthorityError("LIFECYCLE_ELAPSED_INVALID", false);
  return {
    result_id: job.resultId,
    result_schema_version: 1,
    match_id: contract.matchId,
    contract_id: contract.contractId,
    match_epoch: contract.matchEpoch,
    contract_hash: contract.contractHash,
    authority_method: "SERVER_LIFECYCLE",
    terminal_reason: noContest ? "NO_CONTEST" : `FORFEIT_${forfeitKind}`,
    placements: noContest ? [] : [
      { place: 1, player_ids: [winner] },
      { place: 2, player_ids: [loser] }
    ],
    winning_team_id: null,
    elapsed_sim_ticks: elapsed,
    final_state_hash: null,
    final_command_seq: job.finalCommandSeq,
    command_log_hash: job.commandLogHash,
    sim_build_id: contract.simBuildId,
    worker_build_id: config.workerBuildId,
    verified_at: job.receiptIssuedAt,
    verifier_key_id: config.verifierKeyId,
    lifecycle_event_id: terminal.event_id,
    ...(noContest ? { no_contest_reason: noContestReason } : {})
  };
}

export function buildPayload(job: Job, first: ReplayResult, second: ReplayResult, config: WorkerConfig): RecordJson {
  if (!first.ok) throw new AuthorityError(String(first.error_code ?? "REPLAY_FAILED"), false);
  if (!second.ok) throw new AuthorityError(String(second.error_code ?? "REPLAY_FAILED"), false);
  const contract = job.contract;
  const disagreement = first.final_state_hash !== second.final_state_hash
    || first.winner_player_id !== second.winner_player_id
    || first.elapsed_sim_ticks !== second.elapsed_sim_ticks
    || first.terminal_reason !== second.terminal_reason;
  const noContest = disagreement;
  const winner = String(first.winner_player_id ?? "");
  const roster = contract.roster as RecordJson[];
  const loser = roster.map((entry) => String(entry.playerId ?? entry.player_id ?? "")).find((id) => id && id !== winner) ?? "";
  if (!noContest && (!winner || !loser)) throw new AuthorityError("REPLAY_WINNER_INVALID", false);
  return {
    result_id: job.resultId,
    result_schema_version: 1,
    match_id: contract.matchId,
    contract_id: contract.contractId,
    match_epoch: contract.matchEpoch,
    contract_hash: contract.contractHash,
    authority_method: job.authorityMethod,
    terminal_reason: noContest ? "NO_CONTEST" : String(first.terminal_reason ?? "OBJECTIVE_COMPLETE"),
    placements: noContest ? [] : [
      { place: 1, player_ids: [winner] },
      { place: 2, player_ids: [loser] }
    ],
    winning_team_id: null,
    elapsed_sim_ticks: Number(first.elapsed_sim_ticks ?? 0),
    final_state_hash: noContest ? null : first.final_state_hash,
    final_command_seq: job.finalCommandSeq,
    command_log_hash: job.commandLogHash,
    sim_build_id: contract.simBuildId,
    worker_build_id: config.workerBuildId,
    verified_at: job.receiptIssuedAt,
    verifier_key_id: config.verifierKeyId,
    ...(noContest ? { no_contest_reason: "VERIFIER_DISAGREEMENT" } : {})
  };
}

async function replayTwice(config: WorkerConfig, job: Job): Promise<[ReplayResult, ReplayResult]> {
  const manifest = JSON.parse(await readFile(config.artifactManifestPath, "utf8")) as RecordJson;
  if (manifest.worker_build_id !== config.workerBuildId) throw new AuthorityError("WORKER_BUILD_MISMATCH", false);
  const contract = job.contract;
  if (manifest.sim_build_id !== contract.simBuildId) throw new AuthorityError("SIM_BUILD_UNAVAILABLE", false);
  const projectPath = path.resolve(String(manifest.project_path ?? ""));
  const mapPath = resolveArtifact(manifest.map_artifacts, String(contract.mapHash), projectPath);
  const rulesPath = resolveArtifact(manifest.ruleset_artifacts, String(contract.rulesetHash), projectPath);
  const [mapBytes, rulesBytes] = await Promise.all([readFile(mapPath), readFile(rulesPath)]);
  if (crypto.createHash("sha256").update(mapBytes).digest("hex") !== contract.mapHash) {
    throw new AuthorityError("MAP_HASH_MISMATCH", false);
  }
  if (crypto.createHash("sha256").update(rulesBytes).digest("hex") !== contract.rulesetHash) {
    throw new AuthorityError("RULESET_HASH_MISMATCH", false);
  }
  const replayInput = {
    contract: contractForGodot(contract),
    commands: job.commands.map((entry) => entry.command as RecordJson),
    map_data: JSON.parse(mapBytes.toString("utf8")),
    map_artifact_path: projectResourcePath(projectPath, mapPath),
    ruleset_data: JSON.parse(rulesBytes.toString("utf8"))
  };
  return [await runGodot(config, projectPath, replayInput), await runGodot(config, projectPath, replayInput)];
}

export async function replayJobTwice(config: WorkerConfig, job: Job): Promise<[ReplayResult, ReplayResult]> {
  return replayTwice(config, job);
}

async function runGodot(config: WorkerConfig, projectPath: string, input: RecordJson): Promise<ReplayResult> {
  const dir = await mkdtemp(path.join(tmpdir(), "sf-match-authority-"));
  const inputPath = path.join(dir, "input.json");
  const outputPath = path.join(dir, "output.json");
  try {
    await writeFile(inputPath, JSON.stringify(input), "utf8");
    await new Promise<void>((resolve, reject) => {
      const child = spawn(config.godotBin, ["--headless", "--path", projectPath,
        "--script", "res://tools/match_authority_replay.gd", "--", "--input", inputPath, "--output", outputPath],
      { stdio: ["ignore", "pipe", "pipe"] });
      let stderr = "";
      child.stdout.resume();
      child.stderr.on("data", (chunk) => { stderr = `${stderr}${String(chunk)}`.slice(-4_000); });
      const timeout = setTimeout(() => {
        child.kill("SIGKILL");
        reject(new AuthorityError("GODOT_REPLAY_TIMEOUT", true));
      }, config.replayTimeoutMs);
      child.on("error", (error) => { clearTimeout(timeout); reject(error); });
      child.on("exit", (code) => {
        clearTimeout(timeout);
        code === 0 || code === 3
          ? resolve()
          : reject(new AuthorityError(`GODOT_EXIT_${code}:${stderr.slice(-500)}`, true));
      });
    });
    return JSON.parse(await readFile(outputPath, "utf8")) as ReplayResult;
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

async function action(config: WorkerConfig, name: string, body: RecordJson): Promise<RecordJson> {
  const response = await fetch(`${config.baseUrl.replace(/\/$/, "")}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-verifier-worker-token": config.workerToken },
    body: JSON.stringify(body)
  });
  const payload = await response.json() as RecordJson;
  if (!response.ok || payload.ok !== true) throw new AuthorityError(String(payload.err ?? `HTTP_${response.status}`), response.status >= 500);
  return payload;
}

function resolveArtifact(value: unknown, hash: string, projectPath: string): string {
  if (typeof value !== "object" || value == null || Array.isArray(value)) throw new AuthorityError("ARTIFACT_MANIFEST_INVALID", false);
  const artifact = String((value as RecordJson)[hash] ?? "");
  if (!artifact) throw new AuthorityError("ARTIFACT_UNAVAILABLE", false);
  const resolved = path.resolve(projectPath, artifact);
  projectResourcePath(projectPath, resolved);
  return resolved;
}

function projectResourcePath(projectPath: string, artifactPath: string): string {
  const relative = path.relative(projectPath, artifactPath);
  if (!relative || relative === ".." || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) {
    throw new AuthorityError("ARTIFACT_PATH_INVALID", false);
  }
  return `res://${relative.split(path.sep).join("/")}`;
}

function contractForGodot(contract: RecordJson): RecordJson {
  return {
    protocol_version: contract.protocolVersion,
    mode_id: contract.modeId,
    seed: contract.seed,
    authority_tier: contract.authorityTier,
    roster: (contract.roster as RecordJson[]).map((entry) => ({
      player_id: entry.playerId,
      seat_id: entry.seatId,
      team_id: entry.teamId
    }))
  };
}

function asRecord(value: unknown): RecordJson {
  return typeof value === "object" && value != null && !Array.isArray(value) ? value as RecordJson : {};
}

export class AuthorityError extends Error {
  constructor(readonly code: string, readonly retryable: boolean) { super(code); }
}

export function loadConfig(): WorkerConfig {
  const integer = Number.parseInt(process.env.MATCH_AUTHORITY_POLL_MS ?? "1000", 10);
  return {
    baseUrl: process.env.VS_BASE_URL?.trim() || "http://127.0.0.1:8791/v1",
    workerToken: process.env.VS_VERIFIER_WORKER_TOKEN?.trim() || "",
    workerId: process.env.MATCH_AUTHORITY_WORKER_ID?.trim() || "authority-worker-1",
    workerBuildId: process.env.MATCH_AUTHORITY_WORKER_BUILD_ID?.trim() || "",
    verifierKeyId: process.env.MATCH_AUTHORITY_VERIFIER_KEY_ID?.trim() || "",
    verifierPrivateKeyPem: String(process.env.MATCH_AUTHORITY_VERIFIER_PRIVATE_KEY_PEM ?? "").replace(/\\n/g, "\n").trim(),
    artifactManifestPath: process.env.MATCH_AUTHORITY_ARTIFACT_MANIFEST?.trim() || "",
    godotBin: process.env.MATCH_AUTHORITY_GODOT_BIN?.trim() || "godot",
    pollMs: Number.isFinite(integer) ? Math.max(100, integer) : 1000,
    replayTimeoutMs: Math.max(1_000, Number.parseInt(process.env.MATCH_AUTHORITY_REPLAY_TIMEOUT_MS ?? "120000", 10) || 120_000),
    runOnce: ["1", "true", "yes"].includes(process.env.MATCH_AUTHORITY_RUN_ONCE?.trim().toLowerCase() ?? "")
  };
}

async function main(): Promise<void> {
  const config = loadConfig();
  if (!config.workerToken || !config.workerBuildId || !config.verifierKeyId
    || !config.verifierPrivateKeyPem || !config.artifactManifestPath) throw new Error("match_authority_not_configured");
  do {
    try {
      const worked = await runOne(config);
      if (config.runOnce) return;
      if (!worked) await new Promise((resolve) => setTimeout(resolve, config.pollMs));
    } catch (error) {
      if (config.runOnce) throw error;
      console.error(error);
      await new Promise((resolve) => setTimeout(resolve, config.pollMs));
    }
  } while (true);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  void main().catch((error) => { console.error(error); process.exitCode = 1; });
}
