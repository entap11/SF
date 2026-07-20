import type { Request, Response } from "express";
import { config } from "./config.js";
import { DurableCoreError, type JsonRecord } from "./repositories/durableCore.js";
import { getPublic1v1Repository } from "./repositories/durableCoreRuntime.js";
import type { Public1v1Policy, Public1v1QueueResult, PublicDuelQueueMode } from "./repositories/public1v1.js";
import { bearerPlayerToken, PlayerAuthError, verifyPlayerToken } from "./playerAuth.js";

const ACTIONS = new Set([
  "poll_public_1v1", "cancel_public_1v1", "get_public_1v1_session",
  "set_public_1v1_ready", "start_public_1v1", "publish_public_1v1_command",
  "poll_public_1v1_commands", "leave_public_1v1", "resume_public_1v1",
  "get_public_bot_fallback_offer", "accept_public_bot_fallback"
]);

export async function handleDurablePublic1v1Action(
  action: string,
  req: Request,
  res: Response
): Promise<boolean> {
  const isDurableEnqueue = action === "enqueue_public_1v1" && config.durablePublic1v1Enabled;
  if (!isDurableEnqueue && !ACTIONS.has(action)) return false;
  if (!config.durablePublic1v1Enabled || !config.durableCoreEnabled) {
    fail(res, "durable_public_1v1_disabled", 503);
    return true;
  }
  if (!config.matchVerificationEnabled || config.public1v1AuthorityTier !== "AUTHORITY_VERIFIED") {
    fail(res, "public_1v1_authority_not_configured", 503);
    return true;
  }
  try {
    const authenticated = authenticatedPlayer(req);
    rejectConflictingIdentity(req, authenticated.playerId);
    const repository = getPublic1v1Repository();
    const nowIso = new Date().toISOString();
    switch (action) {
      case "enqueue_public_1v1": {
        const requestId = requestKey(req);
        const policy = policyForMode(publicMode(req.body?.mode_id));
        const result = await repository.enqueue({
          requestId,
          player: {
            playerId: authenticated.playerId,
            displayName: authenticated.displayName || `Player_${authenticated.playerId.slice(-6)}`,
            publicEntapId: authenticated.entapId || undefined
          },
          protocolVersion: integer(req.body?.protocol_version, 0),
          clientBuild: text(req.body?.client_build),
          nowIso,
          policy
        });
        respondQueue(res, result);
        return true;
      }
      case "poll_public_1v1": {
        respondQueue(res, await repository.poll(text(req.body?.ticket_id), authenticated.playerId, nowIso));
        return true;
      }
      case "cancel_public_1v1": {
        respondQueue(res, await repository.cancel(text(req.body?.ticket_id), authenticated.playerId, requestKey(req), nowIso));
        return true;
      }
      case "get_public_bot_fallback_offer": {
        if (!config.enableCtfBotFallback) throw new DurableCoreError("ctf_bot_fallback_disabled");
        const offer = await repository.getBotFallbackOffer(text(req.body?.ticket_id), authenticated.playerId,
          nowIso, config.ctfBotFallbackThresholdSec);
        ok(res, { offer });
        return true;
      }
      case "accept_public_bot_fallback": {
        if (!config.enableCtfBotFallback) throw new DurableCoreError("ctf_bot_fallback_disabled");
        const ticketId = text(req.body?.ticket_id);
        const offer = await repository.getBotFallbackOffer(ticketId, authenticated.playerId,
          nowIso, config.ctfBotFallbackThresholdSec);
        const hidden = offer.modeId === "HCTF_1V1";
        const session = await repository.acceptBotFallback({
          ticketId,
          playerId: authenticated.playerId,
          requestId: requestKey(req),
          nowIso,
          thresholdSec: config.ctfBotFallbackThresholdSec,
          botProfileId: hidden ? config.hctfBotProfileId : config.ctfBotProfileId,
          botDisplayName: hidden ? "Hidden Flag Practice Bot" : "Capture Flag Practice Bot"
        });
        ok(res, { session, session_id: session.session_id, source_ticket_status: "CANCELLED" });
        return true;
      }
      case "get_public_1v1_session": {
        ok(res, { session: await repository.getSession(text(req.body?.match_id ?? req.body?.session_id), authenticated.playerId) });
        return true;
      }
      case "set_public_1v1_ready": {
        const session = await repository.setReady({
          matchId: text(req.body?.match_id ?? req.body?.session_id),
          playerId: authenticated.playerId,
          requestId: requestKey(req),
          nowIso,
          ready: boolean(req.body?.ready)
        });
        ok(res, { session, session_id: session.session_id });
        return true;
      }
      case "start_public_1v1": {
        const session = await repository.start(lifecycle(req, authenticated.playerId, requestKey(req), nowIso));
        ok(res, { session, session_id: session.session_id });
        return true;
      }
      case "leave_public_1v1": {
        const session = await repository.leave(lifecycle(req, authenticated.playerId, requestKey(req), nowIso),
          config.public1v1ReconnectGraceSec);
        ok(res, { session, session_id: session.session_id });
        return true;
      }
      case "resume_public_1v1": {
        const session = await repository.resume(authenticated.playerId, requestKey(req), nowIso);
        ok(res, { session, session_id: session.session_id });
        return true;
      }
      case "publish_public_1v1_command": {
        const matchId = text(req.body?.match_id ?? req.body?.session_id);
        const session = await repository.getSession(matchId, authenticated.playerId);
        const roster = Array.isArray(session.roster) ? session.roster as JsonRecord[] : [];
        const player = roster.find((entry) => text(entry.player_id ?? entry.uid) === authenticated.playerId);
        if (!player) throw new DurableCoreError("player_not_in_match");
        const command = record(req.body?.command);
        const receipt = await repository.appendCommand({
          matchId,
          matchEpoch: integer(session.match_epoch, 1),
          playerId: authenticated.playerId,
          seatId: integer(player.seat_id ?? player.seat, 0),
          clientCommandId: text(req.body?.client_command_id ?? command.client_command_id),
          issuedTick: integer(command.issued_tick ?? command.local_issued_tick, 0),
          requestedExecuteTick: integer(command.requested_execute_tick ?? command.execute_tick, 0),
          command,
          receivedAt: nowIso
        });
        ok(res, {
          seq: receipt.commandSeq,
          command_seq: receipt.commandSeq,
          command_id: receipt.command.command_id,
          command: receipt.command,
          canonical_command: receipt.command,
          duplicate: receipt.duplicate
        });
        return true;
      }
      case "poll_public_1v1_commands": {
        const matchId = text(req.body?.match_id ?? req.body?.session_id);
        const session = await repository.getSession(matchId, authenticated.playerId);
        const page = await repository.readCommands(matchId, integer(session.match_epoch, 1),
          authenticated.playerId, Math.max(0, integer(req.body?.after_seq, 0)));
        ok(res, {
          latest_seq: page.highWaterSeq,
          contiguous_from: page.events.length > 0 ? page.events[0].commandSeq : page.afterSeq + 1,
          events: page.events.map((event) => ({
            seq: event.commandSeq,
            uid: event.playerId,
            command: event.command,
            ts_unix: Math.floor(new Date(event.committedAt).getTime() / 1000)
          }))
        });
        return true;
      }
      default:
        return false;
    }
  } catch (error) {
    if (error instanceof PlayerAuthError) fail(res, error.code, error.status);
    else if (error instanceof DurableCoreError) fail(res, error.code, statusFor(error.code));
    else throw error;
    return true;
  }
}

function authenticatedPlayer(req: Request) {
  const token = bearerPlayerToken(req.header("authorization"));
  if (!token) throw new PlayerAuthError("player_token_required", 401);
  return verifyPlayerToken(token, {
    issuer: config.playerTokenIssuer,
    audience: config.playerTokenAudience,
    keyId: config.playerTokenKeyId,
    publicKeyPem: config.playerTokenPublicKeyPem
  }, "match:queue");
}

function rejectConflictingIdentity(req: Request, playerId: string): void {
  const profile = record(req.body?.profile);
  const supplied = text(profile.uid ?? req.body?.uid ?? req.body?.player_id);
  if (supplied && supplied !== playerId) throw new PlayerAuthError("identity_mismatch", 403);
}

function requestKey(req: Request): string {
  const value = text(req.body?.request_id ?? req.body?.idempotency_key);
  if (!value || value.length > 256) throw new DurableCoreError("idempotency_key_required");
  return value;
}

function lifecycle(req: Request, playerId: string, requestId: string, nowIso: string) {
  return {
    matchId: text(req.body?.match_id ?? req.body?.session_id),
    playerId,
    requestId,
    nowIso
  };
}

function respondQueue(res: Response, result: Public1v1QueueResult): void {
  ok(res, {
    matched: result.ticket.status === "MATCHED",
    ticket_id: result.ticket.ticketId,
    ticket_status: result.ticket.status,
    session_id: result.ticket.matchId,
    contract_id: result.ticket.contractId,
    session: result.session,
    duplicate: result.duplicate
  });
}

function statusFor(code: string): number {
  if (["queue_ticket_not_found", "resumable_match_not_found", "contract_missing"].includes(code)) return 404;
  if (["player_not_in_match", "command_sender_mismatch"].includes(code)) return 403;
  if (["idempotency_conflict", "idempotency_in_progress", "roster_not_ready",
    "match_not_startable", "match_not_ready_mutable", "match_not_running", "reconnect_grace_expired",
    "bot_fallback_not_eligible"].includes(code)) return 409;
  if (["durable_1v1_contract_not_configured", "command_stream_missing", "public_1v1_disabled",
    "public_ctf_disabled", "public_hctf_disabled", "human_hctf_secrecy_not_certified",
    "ctf_bot_fallback_disabled"].includes(code)) return 503;
  return 400;
}

function publicMode(value: unknown): PublicDuelQueueMode {
  const mode = text(value).toUpperCase() || "STANDARD_1V1";
  if (mode === "STANDARD_1V1" || mode === "CTF_1V1" || mode === "HCTF_1V1") return mode;
  throw new DurableCoreError("public_duel_mode_unsupported");
}

function policyForMode(modeId: PublicDuelQueueMode): Public1v1Policy {
  const shared = {
    minimumClientBuild: config.public1v1MinimumClientBuild,
    simBuildId: config.public1v1SimBuildId,
    queueTtlSec: config.queueTtlSec,
    sessionTtlSec: config.sessionTtlSec,
    reconnectGraceSec: config.public1v1ReconnectGraceSec,
    authorityTier: config.public1v1AuthorityTier
  };
  if (modeId === "STANDARD_1V1") {
    if (!config.enablePublic1v1) throw new DurableCoreError("public_1v1_disabled");
    return {
      ...shared, modeId, clientMode: "1V1", vsRuleset: "STANDARD",
      rulesetId: config.public1v1RulesetId, rulesetHash: config.public1v1RulesetHash,
      mapId: config.public1v1MapId, mapHash: config.public1v1MapHash, ranked: true
    };
  }
  if (modeId === "CTF_1V1") {
    if (!config.enablePublicCtf) throw new DurableCoreError("public_ctf_disabled");
    return {
      ...shared, modeId, clientMode: "CAPTURE_FLAG", vsRuleset: "CAPTURE_FLAG",
      rulesetId: config.publicCtfRulesetId, rulesetHash: config.publicCtfRulesetHash,
      mapId: config.publicCtfMapId, mapHash: config.publicCtfMapHash, ranked: false
    };
  }
  if (!config.enablePublicHctf) throw new DurableCoreError("public_hctf_disabled");
  if (!config.hctfLiveSecrecyCertified) throw new DurableCoreError("human_hctf_secrecy_not_certified");
  return {
    ...shared, modeId, clientMode: "HIDDEN_CAPTURE_FLAG", vsRuleset: "HIDDEN_CAPTURE_FLAG",
    rulesetId: config.publicHctfRulesetId, rulesetHash: config.publicHctfRulesetHash,
    mapId: config.publicHctfMapId, mapHash: config.publicHctfMapHash, ranked: false
  };
}

function ok(res: Response, body: JsonRecord): void {
  res.json({ ok: true, server_unix_ms: Date.now(), ...body });
}

function fail(res: Response, err: string, status: number): void {
  res.status(status).json({ ok: false, err });
}

function record(value: unknown): JsonRecord {
  return typeof value === "object" && value != null && !Array.isArray(value) ? value as JsonRecord : {};
}

function text(value: unknown): string {
  return String(value ?? "").trim();
}

function boolean(value: unknown): boolean {
  if (typeof value !== "boolean") throw new DurableCoreError("ready_boolean_required");
  return value;
}

function integer(value: unknown, fallback: number): number {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) ? parsed : fallback;
}
