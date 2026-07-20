import crypto from "node:crypto";
import http from "node:http";
import { mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { canonicalJson, sha256Canonical } from "./repositories/durableCore.js";

type JsonRecord = Record<string, unknown>;
type ListenableApp = { listen: (port: number, hostname: string, callback: () => void) => http.Server };

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : ` :: ${JSON.stringify(details)}`}`);
}

function listen(app: ListenableApp): Promise<http.Server> {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function close(server: http.Server): Promise<void> {
  return new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}

function encode(value: unknown): string {
  return Buffer.from(JSON.stringify(value), "utf8").toString("base64url");
}

function token(privateKeyPem: string, claims: JsonRecord): string {
  const input = `${encode({ alg: "ES256", typ: "JWT", kid: "durable-1v1-key" })}.${encode(claims)}`;
  const signature = crypto.sign("sha256", Buffer.from(input, "ascii"), {
    key: privateKeyPem,
    dsaEncoding: "ieee-p1363"
  });
  return `${input}.${signature.toString("base64url")}`;
}

async function post(
  base: string,
  action: string,
  body: JsonRecord,
  accessToken = "",
  extraHeaders: Record<string, string> = {}
): Promise<JsonRecord> {
  const response = await fetch(`${base}/${action}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
      ...extraHeaders
    },
    body: JSON.stringify(body)
  });
  return { ...await response.json() as JsonRecord, http_status: response.status };
}

async function main(): Promise<void> {
  const tempDir = mkdtempSync(join(tmpdir(), "sf-durable-1v1-http-"));
  const pair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const privatePem = pair.privateKey.export({ format: "pem", type: "pkcs8" }).toString();
  const publicPem = pair.publicKey.export({ format: "pem", type: "spki" }).toString();
  const verifierPair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const verifierPrivatePem = verifierPair.privateKey.export({ format: "pem", type: "pkcs8" }).toString();
  const verifierPublicPem = verifierPair.publicKey.export({ format: "pem", type: "spki" }).toString();
  Object.assign(process.env, {
    CRUCIBLE_LEDGER_PATH: join(tempDir, "crucible.json"),
    HONEY_LEDGER_PATH: join(tempDir, "honey.json"),
    VS_DURABLE_CORE_ENABLED: "true",
    VS_DURABLE_STORE: "memory",
    VS_DURABLE_PUBLIC_1V1_ENABLED: "true",
    VS_ENABLE_PUBLIC_1V1: "true",
    VS_ENABLE_PUBLIC_CTF: "true",
    VS_ENABLE_PUBLIC_HCTF: "true",
    VS_HCTF_LIVE_SECRECY_CERTIFIED: "false",
    VS_ENABLE_CTF_BOT_FALLBACK: "true",
    VS_CTF_BOT_FALLBACK_THRESHOLD_SEC: "0",
    VS_PUBLIC_1V1_AUTHORITY_TIER: "AUTHORITY_VERIFIED",
    VS_MATCH_VERIFICATION_ENABLED: "true",
    VS_VERIFIER_WORKER_TOKEN: "verification-worker-only",
    VS_VERIFIER_KEY_ID: "verification-key",
    VS_VERIFIER_PUBLIC_KEY_PEM: verifierPublicPem,
    VS_VERIFIER_WORKER_BUILD_ID: "authority-worker-http-smoke-v1",
    VS_AUTHENTICATED_1V1_SLICE_ENABLED: "false",
    VS_PUBLIC_1V1_MINIMUM_CLIENT_BUILD: "2026071801",
    VS_PUBLIC_1V1_SIM_BUILD_ID: "godot-4.2.2-swarmfront-package-3",
    VS_PUBLIC_1V1_RULESET_ID: "standard-v1",
    VS_PUBLIC_1V1_RULESET_HASH: "1".repeat(64),
    VS_PUBLIC_1V1_MAP_ID: "closequarters",
    VS_PUBLIC_1V1_MAP_HASH: "2".repeat(64),
    VS_PUBLIC_CTF_RULESET_ID: "capture-flag-v1",
    VS_PUBLIC_CTF_RULESET_HASH: "3".repeat(64),
    VS_PUBLIC_CTF_MAP_ID: "ctf-closequarters",
    VS_PUBLIC_CTF_MAP_HASH: "4".repeat(64),
    VS_PUBLIC_HCTF_RULESET_ID: "hidden-capture-flag-v1",
    VS_PUBLIC_HCTF_RULESET_HASH: "5".repeat(64),
    VS_PUBLIC_HCTF_MAP_ID: "hctf-closequarters",
    VS_PUBLIC_HCTF_MAP_HASH: "6".repeat(64),
    VS_PUBLIC_1V1_RECONNECT_GRACE_SEC: "30",
    VS_PLAYER_TOKEN_ISSUER: "durable-1v1-issuer",
    VS_PLAYER_TOKEN_AUDIENCE: "durable-1v1-audience",
    VS_PLAYER_TOKEN_KEY_ID: "durable-1v1-key",
    VS_PLAYER_TOKEN_PUBLIC_KEY_PEM: publicPem,
    VS_ADMIN_TOKEN: "admin-only",
    VS_MATCH_AUTHORITY_TOKEN: "authority-only"
  });
  const { createApp } = await import("./server.js");
  const server = await listen(createApp());
  const address = server.address();
  if (address == null || typeof address === "string") throw new Error("missing listen address");
  const root = `http://127.0.0.1:${address.port}`;
  const base = `${root}/v1`;
  const now = Math.floor(Date.now() / 1000);
  const playerA = "0190f47a-1234-7abc-8def-123456789abc";
  const playerB = "0190f47a-2234-7abc-8def-123456789abc";
  const playerC = "0190f47a-7234-7abc-8def-123456789abc";
  const common = {
    iss: "durable-1v1-issuer", aud: "durable-1v1-audience", scp: ["match:queue"],
    iat: now, nbf: now - 1, exp: now + 600, ver: 1
  };
  const tokenA = token(privatePem, { ...common, sub: playerA, name: "Verified A", entap_id: "AAA 001",
    sid: "0190f47a-3234-7abc-8def-123456789abc", did: "0190f47a-4234-7abc-8def-123456789abc", jti: "a" });
  const tokenB = token(privatePem, { ...common, sub: playerB, name: "Verified B", entap_id: "BBB 002",
    sid: "0190f47a-5234-7abc-8def-123456789abc", did: "0190f47a-6234-7abc-8def-123456789abc", jti: "b" });
  const tokenC = token(privatePem, { ...common, sub: playerC, name: "Verified C",
    sid: "0190f47a-8234-7abc-8def-123456789abc", did: "0190f47a-9234-7abc-8def-123456789abc", jti: "c" });
  try {
    const health = await fetch(`${root}/health`).then((response) => response.json() as Promise<JsonRecord>);
    expect(health.durable_public_1v1_enabled === true && health.match_verification_enabled === true
      && health.public_1v1_enabled === true,
      "durable slice flag/public quarantine incorrect", health);
    const disabledLegacyIdentity = await post(base, "enqueue_public_1v1", {
      request_id: "bad-owner", protocol_version: 2, client_build: "2026071801", player_id: playerB
    }, tokenA);
    expect(disabledLegacyIdentity.http_status === 403 && disabledLegacyIdentity.err === "identity_mismatch",
      "body identity overrode token", disabledLegacyIdentity);
    const oldProtocol = await post(base, "enqueue_public_1v1", {
      request_id: "old-protocol", protocol_version: 1, client_build: "2026071801"
    }, tokenA);
    expect(oldProtocol.http_status === 400 && oldProtocol.err === "protocol_incompatible",
      "incompatible protocol entered queue", oldProtocol);
    const oldBuild = await post(base, "enqueue_public_1v1", {
      request_id: "old-build", protocol_version: 2, client_build: "2026071701"
    }, tokenA);
    expect(oldBuild.http_status === 400 && oldBuild.err === "client_build_too_old",
      "old build entered queue", oldBuild);

    const queued = await post(base, "enqueue_public_1v1", {
      request_id: "enqueue-a", protocol_version: 2, client_build: "2026071801",
      profile: { display_name: "Forged A" }
    }, tokenA);
    expect(queued.ok === true && queued.ticket_status === "WAITING", "first player did not queue", queued);
    const queuedRetry = await post(base, "enqueue_public_1v1", {
      request_id: "enqueue-a", protocol_version: 2, client_build: "2026071801"
    }, tokenA);
    expect(queuedRetry.ok === true && queuedRetry.duplicate === true
      && queuedRetry.ticket_id === queued.ticket_id, "queue retry not idempotent", queuedRetry);
    const matched = await post(base, "enqueue_public_1v1", {
      request_id: "enqueue-b", protocol_version: 2, client_build: "2026071801"
    }, tokenB);
    expect(matched.ok === true && matched.ticket_status === "MATCHED", "second player did not match", matched);
    const matchId = String(matched.session_id);
    const session = matched.session as JsonRecord;
    const roster = session.roster as JsonRecord[];
    expect(roster.length === 2 && roster[0].player_id === playerA && roster[1].player_id === playerB,
      "canonical token-owned roster incorrect", session);
    expect(roster[0].display_name === "Verified A" && roster[1].display_name === "Verified B",
      "body display hint was trusted", roster);
    expect((session.host as JsonRecord).player_id === roster[0].player_id
      && (session.guest as JsonRecord).player_id === roster[1].player_id,
      "host/guest projections diverged", session);
    expect(typeof session.contract_hash === "string" && String(session.contract_hash).length === 64,
      "contract is not frozen/hashed", session);

    const restoredA = await post(base, "poll_public_1v1", { ticket_id: queued.ticket_id }, tokenA);
    expect(restoredA.ticket_status === "MATCHED" && restoredA.session_id === matchId,
      "waiting player could not restore match", restoredA);
    const outsider = await post(base, "get_public_1v1_session", { match_id: matchId }, tokenC);
    expect(outsider.http_status === 403 && outsider.err === "player_not_in_match",
      "outsider read match", outsider);
    const prematureCommand = await post(base, "publish_public_1v1_command", {
      match_id: matchId,
      client_command_id: "0190f47a-b234-7abc-8def-123456789abc",
      command: { type: "MOVE", lane_id: 1, issued_tick: 1, requested_execute_tick: 2 }
    }, tokenA);
    expect(prematureCommand.http_status === 409 && prematureCommand.err === "match_not_running",
      "pregame command entered canonical stream", prematureCommand);
    const invalidReady = await post(base, "set_public_1v1_ready", {
      match_id: matchId, request_id: "invalid-ready", ready: "false"
    }, tokenA);
    expect(invalidReady.http_status === 400 && invalidReady.err === "ready_boolean_required",
      "non-boolean ready value accepted", invalidReady);
    const readyA = await post(base, "set_public_1v1_ready", {
      match_id: matchId, request_id: "ready-a", ready: true
    }, tokenA);
    expect(readyA.ok === true && (readyA.session as JsonRecord).duplicate === false, "A ready failed", readyA);
    const earlyStart = await post(base, "start_public_1v1", { match_id: matchId, request_id: "early" }, tokenA);
    expect(earlyStart.http_status === 409 && earlyStart.err === "roster_not_ready", "early start accepted", earlyStart);
    await post(base, "set_public_1v1_ready", { match_id: matchId, request_id: "ready-b", ready: true }, tokenB);
    const started = await post(base, "start_public_1v1", { match_id: matchId, request_id: "start" }, tokenA);
    expect(started.ok === true && (started.session as JsonRecord).lifecycle_status === "RUNNING",
      "ready roster did not start", started);

    const commandId = "0190f47a-a234-7abc-8def-123456789abc";
    const published = await post(base, "publish_public_1v1_command", {
      match_id: matchId,
      client_command_id: commandId,
      command: { type: "MOVE", lane_id: 1, seat_id: 2, issued_tick: 10, requested_execute_tick: 11 }
    }, tokenA);
    const canonical = published.canonical_command as JsonRecord;
    expect(published.ok === true && canonical.player_id === playerA && canonical.seat_id === 1
      && canonical.command_seq === 1 && canonical.execute_tick === 13,
      "server did not own command sender/order/tick", published);
    const publishedRetry = await post(base, "publish_public_1v1_command", {
      match_id: matchId,
      client_command_id: commandId,
      command: { type: "MOVE", lane_id: 1, seat_id: 2, issued_tick: 10, requested_execute_tick: 11 }
    }, tokenA);
    expect(publishedRetry.duplicate === true && publishedRetry.command_seq === 1,
      "command retry appended twice", publishedRetry);
    const polled = await post(base, "poll_public_1v1_commands", { match_id: matchId, after_seq: 0 }, tokenB);
    expect(polled.latest_seq === 1 && (polled.events as JsonRecord[]).length === 1,
      "opponent did not receive contiguous stream", polled);

    const left = await post(base, "leave_public_1v1", { match_id: matchId, request_id: "leave-a" }, tokenA);
    expect((left.session as JsonRecord).lifecycle_status === "RECONNECTING", "leave did not enter grace", left);
    const resumed = await post(base, "resume_public_1v1", { request_id: "resume-a" }, tokenA);
    const resumedRoster = (resumed.session as JsonRecord).roster as JsonRecord[];
    expect((resumed.session as JsonRecord).lifecycle_status === "RUNNING"
      && resumedRoster[0].seat_id === 1 && resumedRoster[0].connection_state === "CONNECTED",
      "resume failed or changed seat", resumed);

    const reportA = await post(base, "submit_public_1v1_terminal_report", {
      match_id: matchId, request_id: "terminal-a", final_state_hash: "b".repeat(64),
      elapsed_sim_ticks: 18, claimed_terminal_reason: "OBJECTIVE_COMPLETE",
      claimed_winner_player_id: playerB, diagnostics: { client_view: "diagnostic_only" }
    }, tokenA);
    expect(reportA.ok === true && (reportA.verification as JsonRecord).status === "AWAITING_REPORTS",
      "first diagnostic report did not wait for peer", reportA);
    const reportB = await post(base, "submit_public_1v1_terminal_report", {
      match_id: matchId, request_id: "terminal-b", final_state_hash: "c".repeat(64),
      elapsed_sim_ticks: 19, claimed_terminal_reason: "OBJECTIVE_COMPLETE",
      claimed_winner_player_id: playerB, diagnostics: { client_view: "also_diagnostic_only" }
    }, tokenB);
    expect(reportB.ok === true && (reportB.verification as JsonRecord).status === "PENDING",
      "complete report set did not schedule verification", reportB);
    const lateCommand = await post(base, "publish_public_1v1_command", {
      match_id: matchId,
      client_command_id: "0190f47a-c234-7abc-8def-123456789abc",
      command: { type: "MOVE", lane_id: 1, issued_tick: 20, requested_execute_tick: 21 }
    }, tokenA);
    expect(lateCommand.http_status === 409 && lateCommand.err === "match_not_running",
      "verification input was not frozen against late commands", lateCommand);
    const resultOutsider = await post(base, "get_public_1v1_result", { match_id: matchId }, tokenC);
    expect(resultOutsider.http_status === 403 && resultOutsider.err === "player_not_in_match",
      "outsider read verification state", resultOutsider);
    const untrustedLease = await post(base, "lease_match_verification", { worker_id: "http-worker" }, tokenA);
    expect(untrustedLease.http_status === 401 && untrustedLease.err === "verifier_worker_required",
      "player token crossed verifier trust boundary", untrustedLease);
    const workerHeaders = { "x-verifier-worker-token": "verification-worker-only" };
    const leased = await post(base, "lease_match_verification", { worker_id: "http-worker" }, "", workerHeaders);
    const job = leased.job as JsonRecord;
    expect(leased.ok === true && job != null && job.authorityMethod === "SIM_REPLAY",
      "trusted worker did not lease replay job", leased);
    const contract = job.contract as JsonRecord;
    const payload: JsonRecord = {
      result_id: job.resultId,
      result_schema_version: 1,
      match_id: contract.matchId,
      contract_id: contract.contractId,
      match_epoch: contract.matchEpoch,
      contract_hash: contract.contractHash,
      authority_method: job.authorityMethod,
      terminal_reason: "OBJECTIVE_COMPLETE",
      placements: [
        { place: 1, player_ids: [playerA] },
        { place: 2, player_ids: [playerB] }
      ],
      winning_team_id: null,
      elapsed_sim_ticks: 18,
      final_state_hash: "a".repeat(64),
      final_command_seq: job.finalCommandSeq,
      command_log_hash: job.commandLogHash,
      sim_build_id: contract.simBuildId,
      worker_build_id: "authority-worker-http-smoke-v1",
      verified_at: job.receiptIssuedAt,
      verifier_key_id: "verification-key"
    };
    const signature = crypto.sign("sha256", Buffer.from(canonicalJson(payload), "utf8"), {
      key: verifierPrivatePem, dsaEncoding: "ieee-p1363"
    }).toString("base64url");
    const completed = await post(base, "complete_match_verification", {
      worker_id: "http-worker", job_id: job.jobId, lease_token: job.leaseToken,
      signed_result: { payload, payload_hash: sha256Canonical(payload), key_id: "verification-key",
        algorithm: "ES256", signature }, run_diagnostics: { smoke: true }
    }, "", workerHeaders);
    expect(completed.ok === true && (completed.verification as JsonRecord).status === "COMPLETED",
      "signed verifier result was not committed", completed);
    const authoritative = await post(base, "get_public_1v1_result", { match_id: matchId }, tokenA);
    const authoritativeView = authoritative.verification as JsonRecord;
    const authoritativeResult = authoritativeView.result as JsonRecord;
    const authoritativePlacements = (authoritativeResult.result as JsonRecord).placements as JsonRecord[];
    const winningPlayerIds = authoritativePlacements[0].player_ids as string[];
    expect(authoritativeView.status === "COMPLETED"
      && winningPlayerIds[0] === playerA
      && (authoritativeView.signedReceipt as JsonRecord).signature === signature,
      "player-visible result trusted client claim or lost signed receipt", authoritative);

    const heldHctf = await post(base, "enqueue_public_1v1", {
      request_id: "hctf-held", mode_id: "HCTF_1V1", protocol_version: 2, client_build: "2026071801"
    }, tokenC);
    expect(heldHctf.http_status === 503 && heldHctf.err === "human_hctf_secrecy_not_certified",
      "human HCTF escaped the live-secrecy hard gate", heldHctf);
    const ctfQueued = await post(base, "enqueue_public_1v1", {
      request_id: "ctf-solo", mode_id: "CTF_1V1", protocol_version: 2, client_build: "2026071801"
    }, tokenC);
    expect(ctfQueued.ok === true && ctfQueued.ticket_status === "WAITING",
      "human CTF did not enter its authenticated human queue", ctfQueued);
    const fallbackOffer = await post(base, "get_public_bot_fallback_offer", {
      ticket_id: ctfQueued.ticket_id
    }, tokenC);
    expect(fallbackOffer.ok === true && (fallbackOffer.offer as JsonRecord).eligible === true,
      "server did not expose an eligible CTF fallback after its configured threshold", fallbackOffer);
    const fallbackAccepted = await post(base, "accept_public_bot_fallback", {
      ticket_id: ctfQueued.ticket_id, request_id: "accept-ctf-practice"
    }, tokenC);
    const fallbackSession = fallbackAccepted.session as JsonRecord;
    const fallbackContext = fallbackSession.context as JsonRecord;
    const fallbackRoster = fallbackSession.roster as JsonRecord[];
    expect(fallbackAccepted.ok === true && fallbackContext.mode_id === "CTF_BOT"
      && fallbackContext.practice === true && fallbackContext.ranked === false
      && fallbackContext.economic === false && fallbackRoster[1].participant_type === "BOT"
      && fallbackRoster[1].uid === "bot_ctf-practice-v1",
      "explicit CTF fallback did not create an isolated canonical practice contract", fallbackAccepted);
  } finally {
    await close(server);
    rmSync(tempDir, { recursive: true, force: true });
  }
  console.log(JSON.stringify({ ok: true, smoke: "durable_public_1v1_http", canonical_roster: true,
    token_owned_identity: true, command_stream: true, reconnect: true, trusted_verification: true,
    client_claims_diagnostic_only: true, public_1v1_enabled: true,
    human_ctf_queue: true, explicit_bot_fallback: true, human_hctf_held: true }));
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
