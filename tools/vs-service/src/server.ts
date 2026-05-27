import cors from "cors";
import express, { type NextFunction, type Request, type Response } from "express";
import http from "node:http";
import { config } from "./config.js";

type JsonRecord = Record<string, unknown>;

type Player = {
  uid: string;
  display_name: string;
  ready: boolean;
  ticket_id?: string;
  tier_id?: string;
  rank_position?: number;
  wax_score?: number;
  color_id?: string;
};

type Session = {
  id: string;
  invite_code: string;
  source: "invite" | "quick";
  context: JsonRecord;
  created_unix: number;
  expires_unix: number;
  started_unix?: number;
  status: "waiting" | "matched" | "ready" | "started" | "closed";
  host: Player;
  guest: Player;
  close_reason: string;
};

type QueueTicket = {
  id: string;
  uid: string;
  display_name: string;
  context: JsonRecord;
  created_unix: number;
  last_seen_unix: number;
  tier_id: string;
  rank_position: number;
  wax_score: number;
  color_id: string;
};

type Presence = {
  uid: string;
  display_name: string;
  last_seen_unix: number;
};

type FriendInvite = {
  id: string;
  from_uid: string;
  from_name: string;
  target_uid: string;
  session_id: string;
  context: JsonRecord;
  created_unix: number;
  expires_unix: number;
  status: "pending" | "accepted" | "rejected" | "expired";
};

type IntentEvent = {
  seq: number;
  uid: string;
  command: JsonRecord;
  ts_unix: number;
};

type IntentStream = {
  nextSeq: number;
  events: IntentEvent[];
};

const processStartUnix = nowUnix();
const sessions = new Map<string, Session>();
const inviteToSession = new Map<string, string>();
const queue: QueueTicket[] = [];
const intentStreams = new Map<string, IntentStream>();
const presenceByUid = new Map<string, Presence>();
const friendInvites = new Map<string, FriendInvite>();
const serviceBuild = process.env.RENDER_GIT_COMMIT
  ?? process.env.SOURCE_VERSION
  ?? process.env.npm_package_version
  ?? "dev";
const TIER_ORDER = [
  "DRONE",
  "WORKER",
  "SOLDIER",
  "HONEY_BEE",
  "BUMBLEBEE",
  "QUEEN",
  "YELLOWJACKET",
  "RED_WASP",
  "HORNET",
  "BALD_FACED_HORNET",
  "KILLER_BEE",
  "ASIAN_GIANT_HORNET",
  "EXECUTIONER_WASP",
  "SCORPION_WASP",
  "COW_KILLER"
];

function nowUnix(): number {
  return Math.floor(Date.now() / 1000);
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringValue(value: unknown): string {
  return String(value ?? "").trim();
}

function boolValue(value: unknown): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  const normalized = stringValue(value).toLowerCase();
  return ["1", "true", "yes", "on"].includes(normalized);
}

function numberValue(value: unknown, fallback = 0): number {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

function normalizeTier(value: unknown): string {
  const tier = stringValue(value).toUpperCase();
  return tier || "DRONE";
}

function tierIndex(tierId: string): number {
  const idx = TIER_ORDER.indexOf(normalizeTier(tierId));
  return idx >= 0 ? idx : 99_999;
}

function normalizeProfile(value: unknown, fallbackName: string): Player | null {
  if (!isRecord(value)) {
    return null;
  }
  const uid = stringValue(value.uid);
  if (!uid) {
    return null;
  }
  const displayName = stringValue(value.display_name) || fallbackName;
  return {
    uid,
    display_name: displayName,
    ready: false,
    tier_id: normalizeTier(value.tier_id),
    rank_position: Math.max(0, Math.trunc(numberValue(value.rank_position, 0))),
    wax_score: numberValue(value.wax_score, 0),
    color_id: stringValue(value.color_id).toUpperCase() || "GREEN"
  };
}

function cloneSession(session: Session): Session {
  return JSON.parse(JSON.stringify(session)) as Session;
}

function cloneContext(value: unknown): JsonRecord {
  if (!isRecord(value)) {
    return {};
  }
  return JSON.parse(JSON.stringify(value)) as JsonRecord;
}

function randomId(prefix: string, digits: number): string {
  const max = 10 ** digits;
  const value = Math.floor(Math.random() * max);
  return `${prefix}${value.toString().padStart(digits, "0")}`;
}

function nextSessionId(): string {
  for (let i = 0; i < 100; i += 1) {
    const id = randomId("S", 8);
    if (!sessions.has(id)) {
      return id;
    }
  }
  return `S${Date.now()}`;
}

function nextTicketId(): string {
  for (let i = 0; i < 100; i += 1) {
    const id = randomId("Q", 8);
    if (!queue.some((ticket) => ticket.id === id)) {
      return id;
    }
  }
  return `Q${Date.now()}`;
}

function nextInviteCode(): string {
  for (let i = 0; i < 100; i += 1) {
    const code = randomId("VS", 5);
    if (!inviteToSession.has(code)) {
      return code;
    }
  }
  return `VS${Date.now().toString().slice(-5)}`;
}

function nextFriendInviteId(): string {
  for (let i = 0; i < 100; i += 1) {
    const id = randomId("FI", 8);
    if (!friendInvites.has(id)) {
      return id;
    }
  }
  return `FI${Date.now()}`;
}

function nextBotUid(): string {
  return randomId("bot_", 6);
}

function newSession(host: Player, context: JsonRecord, source: "invite" | "quick"): Session {
  const createdUnix = nowUnix();
  return {
    id: nextSessionId(),
    invite_code: nextInviteCode(),
    source,
    context: cloneContext(context),
    created_unix: createdUnix,
    expires_unix: createdUnix + Math.max(1, config.sessionTtlSec),
    status: "waiting",
    host: {
      uid: host.uid,
      display_name: host.display_name || "Player 1",
      ready: false,
      ticket_id: host.ticket_id,
      tier_id: host.tier_id,
      rank_position: host.rank_position,
      wax_score: host.wax_score,
      color_id: host.color_id
    },
    guest: { uid: "", display_name: "", ready: false },
    close_reason: ""
  };
}

function markSessionStarted(session: Session): void {
  session.status = "started";
  session.started_unix = nowUnix();
}

function refreshSessionStatus(session: Session): void {
  if (session.status === "started" || session.status === "closed") {
    return;
  }
  if (!session.guest.uid) {
    session.status = "waiting";
    return;
  }
  session.status = session.host.ready && session.guest.ready ? "ready" : "matched";
}

function sessionHasPlayer(session: Session, uid: string): boolean {
  return session.host.uid === uid || session.guest.uid === uid;
}

function isSessionLive(session: Session): boolean {
  return session.status === "started" || nowUnix() <= session.expires_unix;
}

function closeSession(sessionId: string, reason: string): void {
  const session = sessions.get(sessionId);
  if (!session) {
    return;
  }
  session.status = "closed";
  session.close_reason = reason;
  sessions.delete(sessionId);
  inviteToSession.delete(session.invite_code);
  intentStreams.delete(sessionId);
}

function prune(): void {
  const now = nowUnix();
  for (const [sessionId, session] of sessions.entries()) {
    if (session.status !== "started" && now > session.expires_unix) {
      closeSession(sessionId, "expired");
    }
  }
  for (let i = queue.length - 1; i >= 0; i -= 1) {
    if (now - queue[i].last_seen_unix > config.queueTtlSec) {
      queue.splice(i, 1);
    }
  }
  for (const [uid, presence] of presenceByUid.entries()) {
    if (now - presence.last_seen_unix > Math.max(30, config.queueTtlSec * 2)) {
      presenceByUid.delete(uid);
    }
  }
  for (const invite of friendInvites.values()) {
    if (invite.status === "pending" && now > invite.expires_unix) {
      invite.status = "expired";
    }
  }
}

function contextValueMatches(a: JsonRecord, b: JsonRecord, key: string): boolean {
  const aHas = Object.prototype.hasOwnProperty.call(a, key);
  const bHas = Object.prototype.hasOwnProperty.call(b, key);
  if (aHas !== bHas) {
    return false;
  }
  if (!aHas) {
    return true;
  }
  const aValue = a[key];
  const bValue = b[key];
  if (Array.isArray(aValue) || Array.isArray(bValue)) {
    return JSON.stringify(aValue ?? []) === JSON.stringify(bValue ?? []);
  }
  return String(aValue ?? "") === String(bValue ?? "");
}

function contextsCompatible(a: JsonRecord, b: JsonRecord): boolean {
  if (String(a.mode ?? "") !== String(b.mode ?? "")) {
    return false;
  }
  if (Number(a.map_count ?? 0) !== Number(b.map_count ?? 0)) {
    return false;
  }
  if (Number(a.price_usd ?? 0) !== Number(b.price_usd ?? 0)) {
    return false;
  }
  if (Boolean(a.free_roll ?? false) !== Boolean(b.free_roll ?? false)) {
    return false;
  }
  const keys = Boolean(a.human_pvp ?? false) || Boolean(b.human_pvp ?? false)
    ? ["contest_id", "contest_scope"]
    : ["map_ids", "stage_map_paths", "contest_id", "contest_scope"];
  return keys.every((key) => contextValueMatches(a, b, key));
}

function matchScore(requester: Player, candidate: QueueTicket): [number, number, number, number] {
  const requesterRank = Math.max(0, Math.trunc(numberValue(requester.rank_position, 0)));
  const candidateRank = Math.max(0, Math.trunc(numberValue(candidate.rank_position, 0)));
  const rankDelta = requesterRank > 0 && candidateRank > 0 ? Math.abs(requesterRank - candidateRank) : 999_999_999;
  const waxDelta = Math.abs(numberValue(requester.wax_score, 0) - numberValue(candidate.wax_score, 0));
  const tierDistance = Math.abs(tierIndex(String(requester.tier_id ?? "DRONE")) - tierIndex(candidate.tier_id));
  return [tierDistance, rankDelta, waxDelta, candidate.created_unix];
}

function compareScore(a: [number, number, number, number], b: [number, number, number, number]): number {
  for (let i = 0; i < a.length; i += 1) {
    if (a[i] !== b[i]) {
      return a[i] - b[i];
    }
  }
  return 0;
}

function bestQuickMatchIndex(player: Player, context: JsonRecord): number {
  let bestIndex = -1;
  let bestScore: [number, number, number, number] | null = null;
  for (let i = 0; i < queue.length; i += 1) {
    const ticket = queue[i];
    if (ticket.uid === player.uid || !contextsCompatible(context, ticket.context)) {
      continue;
    }
    const score = matchScore(player, ticket);
    if (bestScore == null || compareScore(score, bestScore) < 0) {
      bestScore = score;
      bestIndex = i;
    }
  }
  return bestIndex;
}

export function bestQuickMatchCandidateForTest(playerValue: JsonRecord, context: JsonRecord, candidates: JsonRecord[]): JsonRecord | null {
  const player = normalizeProfile(playerValue, "Player");
  if (player == null) {
    return null;
  }
  let bestCandidate: JsonRecord | null = null;
  let bestScore: [number, number, number, number] | null = null;
  for (const candidateValue of candidates) {
    const candidate: QueueTicket = {
      id: stringValue(candidateValue.id),
      uid: stringValue(candidateValue.uid),
      display_name: stringValue(candidateValue.display_name) || "Player",
      context: isRecord(candidateValue.context) ? candidateValue.context : {},
      created_unix: Math.max(0, Math.trunc(numberValue(candidateValue.created_unix, 0))),
      last_seen_unix: Math.max(0, Math.trunc(numberValue(candidateValue.last_seen_unix, numberValue(candidateValue.created_unix, 0)))),
      tier_id: normalizeTier(candidateValue.tier_id),
      rank_position: Math.max(0, Math.trunc(numberValue(candidateValue.rank_position, 0))),
      wax_score: numberValue(candidateValue.wax_score, 0),
      color_id: stringValue(candidateValue.color_id).toUpperCase() || "GREEN"
    };
    if (candidate.uid === player.uid || !contextsCompatible(context, candidate.context)) {
      continue;
    }
    const score = matchScore(player, candidate);
    if (bestScore == null || compareScore(score, bestScore) < 0) {
      bestCandidate = candidateValue;
      bestScore = score;
    }
  }
  return bestCandidate;
}

function ok(res: Response, body: JsonRecord = {}): void {
  const startedMs = typeof res.locals.startedMs === "number" ? res.locals.startedMs : Date.now();
  res.json({
    ok: true,
    server_unix_ms: Date.now(),
    server_frametime_ms: Math.max(0, Date.now() - startedMs),
    server_tick_rate_hz: 0,
    ...body
  });
}

function fail(res: Response, err: string, status = 400, extra: JsonRecord = {}): void {
  res.status(status).json({ ok: false, err, ...extra });
}

function actionName(req: Request): string {
  return stringValue(req.params.action);
}

function handleAction(req: Request, res: Response): void {
  prune();
  switch (actionName(req)) {
    case "create_invite":
      return createInvite(req, res);
    case "join_invite":
      return joinInvite(req, res);
    case "enqueue_quick_match":
      return enqueueQuickMatch(req, res);
    case "poll_quick_match":
      return pollQuickMatch(req, res);
    case "cancel_quick_match":
      return cancelQuickMatch(req, res);
    case "debug_fill_quick_match":
      return debugFillQuickMatch(req, res);
    case "debug_fill_session":
      return debugFillSession(req, res);
    case "get_session":
      return getSession(req, res);
    case "set_ready":
      return setReady(req, res);
    case "can_start":
      return canStart(req, res);
    case "start_session":
      return startSession(req, res);
    case "leave_session":
      return leaveSession(req, res);
    case "heartbeat":
      return heartbeat(req, res);
    case "list_online_friends":
      return listOnlineFriends(req, res);
    case "create_friend_invite":
      return createFriendInvite(req, res);
    case "poll_friend_invites":
      return pollFriendInvites(req, res);
    case "respond_friend_invite":
      return respondFriendInvite(req, res);
    case "publish_intent":
      return publishIntent(req, res);
    case "poll_intents":
      return pollIntents(req, res);
    default:
      return fail(res, "unknown_action", 404, { action: actionName(req) });
  }
}

function createInvite(req: Request, res: Response): void {
  const host = normalizeProfile(req.body?.profile, "Player 1");
  if (!host) {
    return fail(res, "invalid_profile");
  }
  const session = newSession(host, cloneContext(req.body?.context), "invite");
  sessions.set(session.id, session);
  inviteToSession.set(session.invite_code, session.id);
  return ok(res, { session_id: session.id, invite_code: session.invite_code, session: cloneSession(session) });
}

function joinInvite(req: Request, res: Response): void {
  const code = stringValue(req.body?.invite_code).toUpperCase();
  const guest = normalizeProfile(req.body?.profile, "Player 2");
  if (!code) {
    return fail(res, "invite_code_empty");
  }
  if (!guest) {
    return fail(res, "invalid_profile");
  }
  const sessionId = inviteToSession.get(code);
  if (!sessionId) {
    return fail(res, "invite_not_found", 404);
  }
  const session = sessions.get(sessionId);
  if (!session || !isSessionLive(session)) {
    if (sessionId) {
      closeSession(sessionId, "expired");
    }
    return fail(res, "session_not_found", 404);
  }
  if (session.host.uid === guest.uid) {
    return fail(res, "cannot_join_own_invite");
  }
  if (session.guest.uid && session.guest.uid !== guest.uid) {
    return fail(res, "invite_full");
  }
  const existingReady = session.guest.ready;
  session.guest = {
    uid: guest.uid,
    display_name: guest.display_name,
    ready: existingReady,
    tier_id: guest.tier_id,
    rank_position: guest.rank_position,
    wax_score: guest.wax_score,
    color_id: guest.color_id
  };
  markSessionStarted(session);
  return ok(res, { session_id: session.id, session: cloneSession(session) });
}

function enqueueQuickMatch(req: Request, res: Response): void {
  const player = normalizeProfile(req.body?.profile, "Player");
  if (!player) {
    return fail(res, "invalid_profile");
  }
  const context = cloneContext(req.body?.context);
  const existing = queue.find((ticket) => ticket.uid === player.uid);
  if (existing) {
    return ok(res, { matched: false, ticket_id: existing.id });
  }
  const matchIndex = bestQuickMatchIndex(player, context);
  if (matchIndex >= 0) {
    const other = queue.splice(matchIndex, 1)[0];
    const host: Player = {
      uid: other.uid,
      display_name: other.display_name || "Player 1",
      ready: false,
      ticket_id: other.id,
      tier_id: other.tier_id,
      rank_position: other.rank_position,
      wax_score: other.wax_score,
      color_id: other.color_id
    };
    const session = newSession(host, other.context, "quick");
    session.guest = {
      uid: player.uid,
      display_name: player.display_name || "Player 2",
      ready: false,
      ticket_id: "",
      tier_id: player.tier_id,
      rank_position: player.rank_position,
      wax_score: player.wax_score,
      color_id: player.color_id
    };
    markSessionStarted(session);
    sessions.set(session.id, session);
    inviteToSession.set(session.invite_code, session.id);
    return ok(res, { matched: true, session_id: session.id, session: cloneSession(session) });
  }
  const ticket: QueueTicket = {
    id: nextTicketId(),
    uid: player.uid,
    display_name: player.display_name || "Player",
    context,
    created_unix: nowUnix(),
    last_seen_unix: nowUnix(),
    tier_id: String(player.tier_id ?? "DRONE"),
    rank_position: Number(player.rank_position ?? 0),
    wax_score: Number(player.wax_score ?? 0),
    color_id: String(player.color_id ?? "GREEN")
  };
  queue.push(ticket);
  return ok(res, { matched: false, ticket_id: ticket.id });
}

function pollQuickMatch(req: Request, res: Response): void {
  const ticketId = stringValue(req.body?.ticket_id);
  if (!ticketId) {
    return fail(res, "ticket_empty");
  }
  for (const session of sessions.values()) {
    if (session.source !== "quick") {
      continue;
    }
    if (session.host.ticket_id === ticketId || session.guest.ticket_id === ticketId) {
      return ok(res, { matched: true, session_id: session.id, session: cloneSession(session) });
    }
  }
  const waiting = queue.find((ticket) => ticket.id === ticketId);
  if (waiting) {
    waiting.last_seen_unix = nowUnix();
    return ok(res, { matched: false, ticket_id: ticketId });
  }
  return fail(res, "ticket_not_found", 404);
}

function cancelQuickMatch(req: Request, res: Response): void {
  const ticketId = stringValue(req.body?.ticket_id);
  const uid = stringValue(req.body?.uid);
  if (!ticketId) {
    return fail(res, "ticket_empty");
  }
  const index = queue.findIndex((ticket) => ticket.id === ticketId);
  if (index < 0) {
    return fail(res, "ticket_not_found", 404);
  }
  if (uid && queue[index].uid !== uid) {
    return fail(res, "ticket_owner_mismatch");
  }
  queue.splice(index, 1);
  return ok(res);
}

function debugFillQuickMatch(req: Request, res: Response): void {
  const ticketId = stringValue(req.body?.ticket_id);
  const botName = stringValue(req.body?.bot_name) || "Rival";
  if (!ticketId) {
    return fail(res, "ticket_empty");
  }
  const index = queue.findIndex((ticket) => ticket.id === ticketId);
  if (index < 0) {
    return fail(res, "ticket_not_found", 404);
  }
  const ticket = queue.splice(index, 1)[0];
  const host: Player = {
    uid: ticket.uid,
    display_name: ticket.display_name || "Player",
    ready: false,
    ticket_id: ticketId
  };
  const session = newSession(host, ticket.context, "quick");
  session.guest = {
    uid: nextBotUid(),
    display_name: botName,
    ready: true
  };
  markSessionStarted(session);
  sessions.set(session.id, session);
  inviteToSession.set(session.invite_code, session.id);
  return ok(res, { session_id: session.id, session: cloneSession(session) });
}

function debugFillSession(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const botName = stringValue(req.body?.bot_name) || "Rival";
  const session = sessions.get(sessionId);
  if (!session || !isSessionLive(session)) {
    if (session) {
      closeSession(sessionId, "expired");
    }
    return fail(res, "session_not_found", 404);
  }
  if (!session.guest.uid) {
    session.guest = {
      uid: nextBotUid(),
      display_name: botName,
      ready: true
    };
  }
  markSessionStarted(session);
  return ok(res, { session_id: session.id, session: cloneSession(session) });
}

function getSession(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const session = sessions.get(sessionId);
  if (!session || !isSessionLive(session)) {
    if (session) {
      closeSession(sessionId, "expired");
    }
    return fail(res, "session_not_found", 404);
  }
  return ok(res, { session: cloneSession(session) });
}

function setReady(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const uid = stringValue(req.body?.uid);
  const session = sessions.get(sessionId);
  if (!session || !uid) {
    return fail(res, "invalid_args");
  }
  if (session.host.uid === uid) {
    session.host.ready = boolValue(req.body?.ready);
  } else if (session.guest.uid === uid) {
    session.guest.ready = boolValue(req.body?.ready);
  } else {
    return fail(res, "player_not_in_session");
  }
  refreshSessionStatus(session);
  return ok(res, { session: cloneSession(session) });
}

function canStart(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const uid = stringValue(req.body?.uid);
  const session = sessions.get(sessionId);
  const allowed = Boolean(session && ["matched", "ready", "started"].includes(session.status) && session.host.uid === uid);
  return ok(res, { can_start: allowed });
}

function startSession(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const uid = stringValue(req.body?.uid);
  const session = sessions.get(sessionId);
  if (!session || !uid) {
    return fail(res, "session_not_found", 404);
  }
  if (session.status === "started" && session.host.uid === uid) {
    return ok(res, { session: cloneSession(session) });
  }
  if (!["matched", "ready"].includes(session.status) || session.host.uid !== uid) {
    return fail(res, "not_ready_or_not_host");
  }
  markSessionStarted(session);
  return ok(res, { session: cloneSession(session) });
}

function leaveSession(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const uid = stringValue(req.body?.uid);
  const session = sessions.get(sessionId);
  if (!session || !uid) {
    return fail(res, "session_not_found", 404);
  }
  if (session.host.uid === uid) {
    closeSession(sessionId, "host_left");
    return ok(res, { closed: true });
  }
  if (session.guest.uid === uid) {
    session.guest = { uid: "", display_name: "", ready: false };
    session.host.ready = false;
    refreshSessionStatus(session);
    return ok(res, { closed: false, session: cloneSession(session) });
  }
  return fail(res, "player_not_in_session");
}

function heartbeat(req: Request, res: Response): void {
  const player = normalizeProfile(req.body?.profile, "Player");
  if (!player) {
    return fail(res, "invalid_profile");
  }
  const presence: Presence = {
    uid: player.uid,
    display_name: player.display_name || player.uid,
    last_seen_unix: nowUnix()
  };
  presenceByUid.set(player.uid, presence);
  return ok(res, { presence: { ...presence } });
}

function listOnlineFriends(req: Request, res: Response): void {
  const uid = stringValue(req.body?.uid);
  const friendsRaw: unknown[] = Array.isArray(req.body?.friends) ? req.body.friends : [];
  const friendIds = friendsRaw.map((value: unknown) => stringValue(value)).filter((value: string) => value && value !== uid);
  const now = nowUnix();
  const online = friendIds.flatMap((friendId: string) => {
    const presence = presenceByUid.get(friendId);
    if (!presence || now - presence.last_seen_unix > Math.max(30, config.queueTtlSec * 2)) {
      return [];
    }
    return [{ ...presence }];
  });
  return ok(res, { online });
}

function createFriendInvite(req: Request, res: Response): void {
  const host = normalizeProfile(req.body?.profile, "Player 1");
  const targetUid = stringValue(req.body?.target_uid);
  if (!host) {
    return fail(res, "invalid_profile");
  }
  if (!targetUid || targetUid === host.uid) {
    return fail(res, "invalid_target");
  }
  const context = cloneContext(req.body?.context);
  const session = newSession(host, context, "invite");
  sessions.set(session.id, session);
  inviteToSession.set(session.invite_code, session.id);
  const createdUnix = nowUnix();
  const invite: FriendInvite = {
    id: nextFriendInviteId(),
    from_uid: host.uid,
    from_name: host.display_name || "Player 1",
    target_uid: targetUid,
    session_id: session.id,
    context: cloneContext(context),
    created_unix: createdUnix,
    expires_unix: createdUnix + Math.max(30, config.sessionTtlSec),
    status: "pending"
  };
  friendInvites.set(invite.id, invite);
  return ok(res, { invite: { ...invite }, session_id: session.id, session: cloneSession(session) });
}

function pollFriendInvites(req: Request, res: Response): void {
  const uid = stringValue(req.body?.uid);
  if (!uid) {
    return fail(res, "invalid_uid");
  }
  const invites = [...friendInvites.values()]
    .filter((invite) => invite.target_uid === uid && invite.status === "pending" && nowUnix() <= invite.expires_unix)
    .map((invite) => ({ ...invite }));
  return ok(res, { invites });
}

function respondFriendInvite(req: Request, res: Response): void {
  const inviteId = stringValue(req.body?.invite_id);
  const accept = boolValue(req.body?.accept);
  const guest = normalizeProfile(req.body?.profile, "Player 2");
  const invite = friendInvites.get(inviteId);
  if (!invite || invite.status !== "pending") {
    return fail(res, "invite_not_found", 404);
  }
  if (!guest || guest.uid !== invite.target_uid) {
    return fail(res, "invalid_profile");
  }
  if (!accept) {
    invite.status = "rejected";
    return ok(res, { accepted: false });
  }
  const session = sessions.get(invite.session_id);
  if (!session || !isSessionLive(session)) {
    invite.status = "expired";
    return fail(res, "session_not_found", 404);
  }
  session.guest = {
    uid: guest.uid,
    display_name: guest.display_name || "Player 2",
    ready: false,
    tier_id: guest.tier_id,
    rank_position: guest.rank_position,
    wax_score: guest.wax_score,
    color_id: guest.color_id
  };
  markSessionStarted(session);
  invite.status = "accepted";
  return ok(res, { accepted: true, session_id: session.id, session: cloneSession(session) });
}

function publishIntent(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const uid = stringValue(req.body?.uid);
  const command = req.body?.command;
  const session = sessions.get(sessionId);
  if (!session || !uid || !isRecord(command)) {
    return fail(res, "invalid_args");
  }
  if (!sessionHasPlayer(session, uid)) {
    return fail(res, "player_not_in_session");
  }
  const stream = intentStreams.get(sessionId) ?? { nextSeq: 1, events: [] };
  const seq = stream.nextSeq;
  stream.nextSeq += 1;
  stream.events.push({ seq, uid, command: cloneContext(command), ts_unix: nowUnix() });
  while (stream.events.length > config.intentStreamMaxEvents) {
    stream.events.shift();
  }
  intentStreams.set(sessionId, stream);
  return ok(res, { seq });
}

function pollIntents(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const uid = stringValue(req.body?.uid);
  const afterSeq = Number(req.body?.after_seq ?? 0);
  const session = sessions.get(sessionId);
  if (!session || !uid) {
    return fail(res, "invalid_args");
  }
  if (!sessionHasPlayer(session, uid)) {
    return fail(res, "player_not_in_session");
  }
  const stream = intentStreams.get(sessionId);
  if (!stream) {
    return ok(res, { latest_seq: Math.max(0, afterSeq), events: [] });
  }
  const latestSeq = Math.max(0, stream.nextSeq - 1, afterSeq);
  const events = stream.events.filter((event) => event.seq > afterSeq).map((event) => ({ ...event, command: { ...event.command } }));
  return ok(res, { latest_seq: latestSeq, events });
}

export function createApp(): express.Express {
  const app = express();
  if (config.corsEnabled) {
    app.use(cors());
  }
  app.use(express.json({ limit: "256kb" }));
  app.use((req: Request, res: Response, next: NextFunction) => {
    const started = Date.now();
    res.locals.startedMs = started;
    res.on("finish", () => {
      console.log(JSON.stringify({
        ts: new Date().toISOString(),
        method: req.method,
        path: req.path,
        status: res.statusCode,
        ms: Date.now() - started
      }));
    });
    next();
  });
  app.get("/health", (_req, res) => {
    prune();
    ok(res, {
      service: "swarmfront-vs-service",
      build: serviceBuild,
      uptime_sec: nowUnix() - processStartUnix,
      sessions: sessions.size,
      queue: queue.length
    });
  });
  app.get("/v1/health", (_req, res) => {
    prune();
    ok(res, {
      service: "swarmfront-vs-service",
      build: serviceBuild,
      uptime_sec: nowUnix() - processStartUnix,
      sessions: sessions.size,
      queue: queue.length
    });
  });
  app.post("/:action", handleAction);
  app.post("/v1/:action", handleAction);
  app.use((_req, res) => fail(res, "not_found", 404));
  return app;
}

export function startServer(port = config.port, host = config.bindHost): http.Server {
  const app = createApp();
  const server = app.listen(port, host, () => {
    const address = server.address();
    console.log(JSON.stringify({
      ts: new Date().toISOString(),
      event: "vs_service_started",
      address,
      session_ttl_sec: config.sessionTtlSec,
      queue_ttl_sec: config.queueTtlSec
    }));
  });
  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  startServer();
}
