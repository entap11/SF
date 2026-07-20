import crypto from "node:crypto";
import type { Request, Response } from "express";
import { config } from "./config.js";
import { DurableCoreError, type JsonRecord } from "./repositories/durableCore.js";
import { getCrucibleSettlementRepository, getPublic1v1Repository } from "./repositories/durableCoreRuntime.js";
import type { Public1v1Policy, Public1v1QueueResult, PublicDuelQueueMode } from "./repositories/public1v1.js";
import { bearerPlayerToken, PlayerAuthError, verifyPlayerToken } from "./playerAuth.js";
import { requirePublicRollout } from "./publicModesOpsHttp.js";

const ACTIONS = new Set([
  "poll_public_1v1", "cancel_public_1v1", "get_public_1v1_session",
  "set_public_1v1_ready", "start_public_1v1", "publish_public_1v1_command",
  "poll_public_1v1_commands", "leave_public_1v1", "resume_public_1v1",
  "get_public_bot_fallback_offer", "accept_public_bot_fallback", "sync_public_competitive_identity"
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
    if (action === "sync_public_competitive_identity") {
      requireAdmin(req);
      if (config.durableStore !== "postgres") throw new DurableCoreError("postgres_multiseat_store_required");
      const identity = await getPublic1v1Repository().syncCompetitiveIdentity({
        playerId: text(req.body?.player_id),
        rankValue: integer(req.body?.rank_value, Number.NaN),
        friendPlayerIds: Array.isArray(req.body?.friend_player_ids)
          ? req.body.friend_player_ids.map(text).filter(Boolean) : [],
        sourceRevision: text(req.body?.source_revision),
        nowIso: new Date().toISOString()
      });
      ok(res, { identity });
      return true;
    }
    const authenticated = authenticatedPlayer(req);
    rejectConflictingIdentity(req, authenticated.playerId);
    const repository = getPublic1v1Repository();
    const nowIso = new Date().toISOString();
    switch (action) {
      case "enqueue_public_1v1": {
        const requestId = requestKey(req);
        const modeId = publicMode(req.body?.mode_id);
        const policy = await policyForMode(modeId, text(req.body?.client_build));
        if (modeId === "CRUCIBLE_1V1") {
          await requirePublicRollout("enable_crucible_wax_settlement", text(req.body?.client_build),
            "crucible_wax_settlement_disabled");
          if (await getCrucibleSettlementRepository().balance(authenticated.playerId) < 1000) {
            throw new DurableCoreError("insufficient_wax");
          }
        }
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
        if (modeId === "CRUCIBLE_1V1" && result.ticket.matchId) {
          await getCrucibleSettlementRepository().openEscrow(result.ticket.matchId,
            `match:${result.ticket.matchId}:open`, nowIso);
        }
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
        await requirePublicRollout("enable_bot_fallback", text(req.body?.client_build), "ctf_bot_fallback_disabled");
        const offer = await repository.getBotFallbackOffer(text(req.body?.ticket_id), authenticated.playerId,
          nowIso, config.ctfBotFallbackThresholdSec);
        ok(res, { offer });
        return true;
      }
      case "accept_public_bot_fallback": {
        await requirePublicRollout("enable_bot_fallback", text(req.body?.client_build), "ctf_bot_fallback_disabled");
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
  if (code === "minimum_client_build_required") return 426;
  if (code.startsWith("enable_") && code.endsWith("_disabled")) return 503;
  if (["queue_ticket_not_found", "resumable_match_not_found", "contract_missing"].includes(code)) return 404;
  if (["player_not_in_match", "command_sender_mismatch"].includes(code)) return 403;
  if (["idempotency_conflict", "idempotency_in_progress", "roster_not_ready",
    "match_not_startable", "match_not_ready_mutable", "match_not_running", "reconnect_grace_expired",
    "bot_fallback_not_eligible"].includes(code)) return 409;
  if (["durable_1v1_contract_not_configured", "command_stream_missing", "public_1v1_disabled",
    "public_ctf_disabled", "public_hctf_disabled", "human_hctf_secrecy_not_certified",
    "ctf_bot_fallback_disabled", "public_crucible_disabled", "crucible_wax_settlement_disabled",
    "public_3p_ffa_disabled", "public_2v2_disabled", "public_4p_ffa_disabled",
    "postgres_multiseat_store_required"].includes(code)) return 503;
  if (code === "insufficient_wax") return 402;
  return 400;
}

function publicMode(value: unknown): PublicDuelQueueMode {
  const mode = text(value).toUpperCase() || "STANDARD_1V1";
  if (["STANDARD_1V1", "CTF_1V1", "HCTF_1V1", "CRUCIBLE_1V1", "STANDARD_3P_FFA",
    "STANDARD_2V2", "STANDARD_4P_FFA"].includes(mode)) return mode as PublicDuelQueueMode;
  throw new DurableCoreError("public_duel_mode_unsupported");
}

async function policyForMode(modeId: PublicDuelQueueMode, clientBuild: string): Promise<Public1v1Policy> {
  const flag = modeId === "STANDARD_1V1" ? "enable_public_1v1"
    : modeId === "STANDARD_3P_FFA" ? "enable_public_3p_ffa"
    : modeId === "STANDARD_2V2" ? "enable_public_2v2"
    : modeId === "STANDARD_4P_FFA" ? "enable_public_4p_ffa"
    : modeId === "CTF_1V1" ? "enable_public_ctf"
    : modeId === "HCTF_1V1" ? "enable_public_hctf" : "enable_public_crucible";
  const disabledCode = modeId === "STANDARD_1V1" ? "public_1v1_disabled"
    : modeId === "STANDARD_3P_FFA" ? "public_3p_ffa_disabled"
    : modeId === "STANDARD_2V2" ? "public_2v2_disabled"
    : modeId === "STANDARD_4P_FFA" ? "public_4p_ffa_disabled"
    : modeId === "CTF_1V1" ? "public_ctf_disabled"
    : modeId === "HCTF_1V1" ? "public_hctf_disabled" : "public_crucible_disabled";
  const rollout = await requirePublicRollout(flag, clientBuild, disabledCode);
  const shared = {
    minimumClientBuild: String(Math.max(Number.parseInt(config.public1v1MinimumClientBuild, 10) || 0,
      rollout.minSupportedBuild)) || config.public1v1MinimumClientBuild,
    simBuildId: config.public1v1SimBuildId,
    queueTtlSec: config.queueTtlSec,
    sessionTtlSec: config.sessionTtlSec,
    reconnectGraceSec: config.public1v1ReconnectGraceSec,
    authorityTier: config.public1v1AuthorityTier
  };
  if (modeId === "STANDARD_1V1") {
    return {
      ...shared, modeId, clientMode: "1V1", vsRuleset: "STANDARD",
      rulesetId: config.public1v1RulesetId, rulesetHash: config.public1v1RulesetHash,
      mapId: config.public1v1MapId, mapHash: config.public1v1MapHash, ranked: true
    };
  }
  if (["STANDARD_3P_FFA", "STANDARD_2V2", "STANDARD_4P_FFA"].includes(modeId)) {
    if (config.durableStore !== "postgres") throw new DurableCoreError("postgres_multiseat_store_required");
    const mode = modeId as "STANDARD_3P_FFA" | "STANDARD_2V2" | "STANDARD_4P_FFA";
    const presentation = mode === "STANDARD_3P_FFA" ? { clientMode: "3P FFA" as const, requiredPlayers: 3 as const,
      mapId: config.public3pFfaMapId, mapHash: config.public3pFfaMapHash }
      : mode === "STANDARD_2V2" ? { clientMode: "2V2" as const, requiredPlayers: 4 as const,
        mapId: config.public2v2MapId, mapHash: config.public2v2MapHash }
      : { clientMode: "4P FFA" as const, requiredPlayers: 4 as const,
        mapId: config.public4pFfaMapId, mapHash: config.public4pFfaMapHash };
    return {
      ...shared,
      minimumClientBuild: String(Math.max(Number.parseInt(config.publicMultiMinimumClientBuild, 10) || 0,
        rollout.minSupportedBuild)) || config.publicMultiMinimumClientBuild,
      simBuildId: config.publicMultiSimBuildId,
      modeId: mode,
      clientMode: presentation.clientMode,
      vsRuleset: "STANDARD",
      rulesetId: config.publicMultiRulesetId,
      rulesetHash: config.publicMultiRulesetHash,
      mapId: presentation.mapId,
      mapHash: presentation.mapHash,
      ranked: false,
      requiredPlayers: presentation.requiredPlayers,
      assignmentPolicyId: mode === "STANDARD_2V2" ? "FRIEND_THEN_RANK_V1" : "SERVER_SEATS_COLORS_V1"
    };
  }
  if (modeId === "CTF_1V1") {
    return {
      ...shared, modeId, clientMode: "CAPTURE_FLAG", vsRuleset: "CAPTURE_FLAG",
      rulesetId: config.publicCtfRulesetId, rulesetHash: config.publicCtfRulesetHash,
      mapId: config.publicCtfMapId, mapHash: config.publicCtfMapHash, ranked: false
    };
  }
  if (modeId === "CRUCIBLE_1V1") {
    return {
      ...shared, modeId, clientMode: "1V1", vsRuleset: "CRUCIBLE",
      rulesetId: config.publicCrucibleRulesetId, rulesetHash: config.publicCrucibleRulesetHash,
      mapId: config.publicCrucibleMapId, mapHash: config.publicCrucibleMapHash, ranked: false
    };
  }
  if (!config.hctfLiveSecrecyCertified) throw new DurableCoreError("human_hctf_secrecy_not_certified");
  return {
    ...shared, modeId, clientMode: "HIDDEN_CAPTURE_FLAG", vsRuleset: "HIDDEN_CAPTURE_FLAG",
    rulesetId: config.publicHctfRulesetId, rulesetHash: config.publicHctfRulesetHash,
    mapId: config.publicHctfMapId, mapHash: config.publicHctfMapHash, ranked: false
  };
}

function requireAdmin(req: Request): void {
  const supplied = bearerPlayerToken(req.header("authorization"));
  const expected = config.adminToken;
  const valid = supplied.length === expected.length && supplied.length > 0
    && crypto.timingSafeEqual(Buffer.from(supplied), Buffer.from(expected));
  if (!valid) throw new PlayerAuthError("admin_auth_required", 401);
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
