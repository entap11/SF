import cors from "cors";
import express, { type NextFunction, type Request, type Response } from "express";
import crypto from "node:crypto";
import http from "node:http";
import { config } from "./config.js";
import {
  contestDashInfo,
  handleContestDashDelete,
  handleContestDashPage,
  handleContestDashSave,
  handleContestDashState
} from "./contestDash.js";
import { moneyLedger, type JsonRecord as LedgerJsonRecord } from "./moneyLedger.js";
import { crucibleLedger } from "./crucibleLedger.js";
import { honeyLedger } from "./honeyLedger.js";
import { honeyActivitySpecsSnapshot } from "./honeyEconomyPolicy.js";
import { waxPolicySnapshot } from "./waxRewardPolicy.js";

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
  balance_cents?: number;
  crucible_wax_millis?: number;
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
  balance_cents?: number;
  crucible_wax_millis?: number;
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
  lastExecuteTick: number;
};

type SpectatorSnapshotEvent = {
  seq: number;
  uid: string;
  snapshot: JsonRecord;
  ts_unix: number;
};

type SpectatorSnapshotStream = {
  nextSeq: number;
  snapshots: SpectatorSnapshotEvent[];
};

type SpectatorRole = "admin_spectate" | "tournament_observer" | "invited_spectator" | "public_delayed_spectate";

type SpectatorGrant = {
  id: string;
  token: string;
  session_id: string;
  role: SpectatorRole;
  spectator_uid: string;
  display_name: string;
  created_unix: number;
  expires_unix: number;
  delay_sec: number;
  live: boolean;
  joined_unix?: number;
  last_seen_unix?: number;
};

const processStartUnix = nowUnix();
const sessions = new Map<string, Session>();
const inviteToSession = new Map<string, string>();
const queue: QueueTicket[] = [];
const intentStreams = new Map<string, IntentStream>();
const presenceByUid = new Map<string, Presence>();
const friendInvites = new Map<string, FriendInvite>();
const spectatorGrants = new Map<string, SpectatorGrant>();
const spectatorSnapshotStreams = new Map<string, SpectatorSnapshotStream>();
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
const SPECTATOR_ROLES = new Set<SpectatorRole>([
  "admin_spectate",
  "tournament_observer",
  "invited_spectator",
  "public_delayed_spectate"
]);

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

function adminTokenFromRequest(req: Request): string {
  const headerToken = stringValue(req.header("x-admin-token"));
  if (headerToken) {
    return headerToken;
  }
  const auth = stringValue(req.header("authorization"));
  if (auth.toLowerCase().startsWith("bearer ")) {
    return auth.slice(7).trim();
  }
  return stringValue((req.body as JsonRecord | undefined)?.admin_token);
}

function requireAdmin(req: Request, res: Response): boolean {
  if (!config.adminToken) {
    return true;
  }
  if (adminTokenFromRequest(req) !== config.adminToken) {
    fail(res, "admin_auth_required", 401, { required_role: config.adminRole });
    return false;
  }
  const role = stringValue(req.header("x-admin-role") || (req.body as JsonRecord | undefined)?.admin_role || config.adminRole);
  if (role !== config.adminRole) {
    fail(res, "admin_role_required", 403, { required_role: config.adminRole });
    return false;
  }
  return true;
}

function requestHasAdminAuthority(req: Request): boolean {
  if (!config.adminToken) {
    return false;
  }
  if (adminTokenFromRequest(req) !== config.adminToken) {
    return false;
  }
  const role = stringValue(req.header("x-admin-role") || (req.body as JsonRecord | undefined)?.admin_role || config.adminRole);
  return role === config.adminRole;
}

function matchAuthorityTokenFromRequest(req: Request): string {
  const headerToken = stringValue(req.header("x-match-authority-token") || req.header("x-match-token"));
  if (headerToken) {
    return headerToken;
  }
  const auth = stringValue(req.header("authorization"));
  if (auth.toLowerCase().startsWith("bearer ")) {
    return auth.slice(7).trim();
  }
  return stringValue((req.body as JsonRecord | undefined)?.match_authority_token);
}

function requireMatchAuthority(req: Request, res: Response): boolean {
  if (!config.matchAuthorityToken) {
    return true;
  }
  if (matchAuthorityTokenFromRequest(req) === config.matchAuthorityToken) {
    return true;
  }
  fail(res, "match_authority_required", 401, { authority: "server_match_result" });
  return false;
}

function requestHasMatchAuthority(req: Request): boolean {
  if (!config.matchAuthorityToken) {
    return false;
  }
  return matchAuthorityTokenFromRequest(req) === config.matchAuthorityToken;
}

function requestMayProvideCrucibleBalanceHint(req: Request): boolean {
  if (!config.adminToken && !config.matchAuthorityToken) {
    return true;
  }
  return requestHasAdminAuthority(req) || requestHasMatchAuthority(req);
}

function numberValue(value: unknown, fallback = 0): number {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

function optionalCentsValue(value: unknown): number | undefined {
  if (value == null) {
    return undefined;
  }
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.max(0, Math.trunc(numeric)) : undefined;
}

function profileBalanceCents(value: JsonRecord): number | undefined {
  const direct = optionalCentsValue(value.balance_cents ?? value.cash_balance_cents ?? value.wallet_balance_cents);
  if (direct != null) {
    return direct;
  }
  if (isRecord(value.wallet)) {
    return optionalCentsValue(value.wallet.balance_cents ?? value.wallet.cash_balance_cents);
  }
  return undefined;
}

function profileCrucibleWaxMillis(value: JsonRecord): number | undefined {
  const direct = optionalCentsValue(value.crucible_wax_millis ?? value.crucible_wax ?? value.wax_millis);
  if (direct != null) {
    return direct;
  }
  if (isRecord(value.wallet)) {
    return optionalCentsValue(value.wallet.crucible_wax_millis ?? value.wallet.wax_millis);
  }
  return undefined;
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
    color_id: stringValue(value.color_id).toUpperCase() || "GREEN",
    balance_cents: profileBalanceCents(value),
    crucible_wax_millis: profileCrucibleWaxMillis(value)
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

function nextSpectatorGrantId(): string {
  for (let i = 0; i < 100; i += 1) {
    const id = randomId("SG", 8);
    if (![...spectatorGrants.values()].some((grant) => grant.id === id)) {
      return id;
    }
  }
  return `SG${Date.now()}`;
}

function nextSpectatorGrantToken(): string {
  return crypto.randomBytes(24).toString("hex");
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
      color_id: host.color_id,
      balance_cents: host.balance_cents,
      crucible_wax_millis: host.crucible_wax_millis
    },
    guest: { uid: "", display_name: "", ready: false },
    close_reason: ""
  };
}

function markSessionStarted(session: Session): void {
  session.status = "started";
  session.started_unix = nowUnix();
}

function contextIsPaid(context: JsonRecord): boolean {
  if (boolValue(context.free_roll)) {
    return false;
  }
  return boolValue(context.paid_entry) || numberValue(context.wager_cents, 0) > 0 || numberValue(context.price_usd, 0) > 0;
}

function contextIsCrucible(context: JsonRecord): boolean {
  return stringValue(context.vs_ruleset ?? context.ruleset).toUpperCase() === "CRUCIBLE" || boolValue(context.vs_crucible);
}

function contextWagerCents(context: JsonRecord): number {
  const wagerCents = Math.trunc(numberValue(context.wager_cents, 0));
  if (wagerCents > 0) {
    return wagerCents;
  }
  const priceUsd = numberValue(context.price_usd, 0);
  return Math.max(0, Math.round(priceUsd * 100));
}

function activeCrucibleCount(): number {
  let count = queue.filter((ticket) => contextIsCrucible(ticket.context)).length;
  for (const session of sessions.values()) {
    if (session.status !== "closed" && contextIsCrucible(session.context)) {
      count += 1;
    }
  }
  return count;
}

function sessionFundingPlayer(player: Player): { player_id: string; balance_cents?: number } {
  return {
    player_id: player.uid,
    balance_cents: player.balance_cents
  };
}

function startSessionAuthoritatively(session: Session): LedgerJsonRecord {
  if (contextIsCrucible(session.context)) {
    if (!session.host.uid || !session.guest.uid) {
      return { ok: false, err: "not_enough_players", code: "not_enough_players" };
    }
    const matchId = stringValue(session.context.crucible_match_id) || `crucible_${session.id}`;
    const configSnapshot = crucibleLedger.getConfigSnapshot();
    const escrow = crucibleLedger.openEscrow(
      matchId,
      session.host.uid,
      session.guest.uid,
      {
        expected_config_version: session.context.crucible_config_version ?? configSnapshot.config_version,
        expected_config_hash: session.context.crucible_config_hash ?? configSnapshot.config_hash,
        session_id: session.id,
        player_balance_millis_by_id: {
          [session.host.uid]: session.host.crucible_wax_millis,
          [session.guest.uid]: session.guest.crucible_wax_millis
        },
        anti_collusion_signals: {
          repeated_same_opponent: false,
          unusual_win_trading: false,
          same_device_cluster: false,
          same_ip_pattern: false,
          suspicious_forfeit: false,
          high_stakes_repeated_transfer: false
        }
      },
      `open:${matchId}`
    );
    if (escrow.ok !== true) {
      return escrow;
    }
    const escrowRecord = isRecord(escrow.escrow) ? escrow.escrow : {};
    session.context = {
      ...session.context,
      mode: "1V1",
      vs_mode: "1V1",
      vs_ruleset: "CRUCIBLE",
      vs_crucible: true,
      free_roll: true,
      paid_entry: false,
      crucible_match_id: matchId,
      crucible_ledger_status: "escrowed",
      crucible_escrow_id: escrowRecord.escrow_id,
      crucible_stake_each: escrowRecord.stake_each,
      crucible_pot: escrowRecord.pot,
      crucible_burn: escrowRecord.burn,
      crucible_winner_payout: escrowRecord.winner_payout,
      crucible_config_version: escrowRecord.config_version,
      crucible_config_hash: escrowRecord.config_hash
    };
    markSessionStarted(session);
    return { ok: true, session, escrow };
  }
  if (!contextIsPaid(session.context)) {
    markSessionStarted(session);
    return { ok: true, session };
  }
  if (!session.host.uid || !session.guest.uid) {
    return { ok: false, err: "not_enough_players", code: "not_enough_players" };
  }
  const wagerCents = contextWagerCents(session.context);
  const escrow = moneyLedger.openMoneyEscrow(
    session.id,
    [sessionFundingPlayer(session.host), sessionFundingPlayer(session.guest)],
    wagerCents,
    `open:${session.id}`
  );
  if (escrow.ok !== true) {
    return escrow;
  }
  session.context = {
    ...session.context,
    paid_entry: true,
    free_roll: false,
    wager_cents: wagerCents,
    price_usd: wagerCents / 100,
    ledger_status: "escrowed",
    pot_cents: Number(escrow.pot_cents ?? wagerCents * 2)
  };
  markSessionStarted(session);
  return { ok: true, session, escrow };
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
  spectatorSnapshotStreams.delete(sessionId);
  for (const [token, grant] of spectatorGrants.entries()) {
    if (grant.session_id === sessionId) {
      spectatorGrants.delete(token);
    }
  }
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
  for (const [token, grant] of spectatorGrants.entries()) {
    if (now > grant.expires_unix) {
      spectatorGrants.delete(token);
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
    ? ["contest_id", "contest_scope", "vs_ruleset", "vs_crucible"]
    : ["map_ids", "stage_map_paths", "contest_id", "contest_scope", "vs_ruleset", "vs_crucible"];
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
      color_id: stringValue(candidateValue.color_id).toUpperCase() || "GREEN",
      crucible_wax_millis: optionalCentsValue(candidateValue.crucible_wax_millis)
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

function failLedger(res: Response, result: LedgerJsonRecord, status = 400): void {
  const err = stringValue(result.err ?? result.code) || "ledger_error";
  fail(res, err, status, result);
}

function okOrLedgerFailure(res: Response, result: LedgerJsonRecord, status = 400): void {
  if (result.ok === true) {
    ok(res, result);
    return;
  }
  failLedger(res, result, status);
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
    case "open_money_escrow":
      return openMoneyEscrow(req, res);
    case "settle_money_match":
      return settleMoneyMatch(req, res);
    case "refund_money_match":
      return refundMoneyMatch(req, res);
    case "open_async_entry_escrow":
      return openAsyncEntryEscrow(req, res);
    case "submit_async_contest_result":
      return submitAsyncContestResult(req, res);
    case "list_async_contest_results":
      return listAsyncContestResults(req, res);
    case "preview_async_contest_result_payout_report":
      return previewAsyncContestResultPayoutReport(req, res);
    case "preview_async_contest_payout_report":
      return previewAsyncContestPayoutReport(req, res);
    case "list_async_contest_payout_reports":
      return listAsyncContestPayoutReports(req, res);
    case "approve_async_contest_payout_report":
      return approveAsyncContestPayoutReport(req, res);
    case "settle_async_contest":
      return settleAsyncContest(req, res);
    case "settle_async_contest_payouts":
      return settleAsyncContestPayouts(req, res);
    case "settle_async_contest_payout_percentages":
      return settleAsyncContestPayoutPercentages(req, res);
    case "refund_async_entry":
      return refundAsyncEntry(req, res);
    case "get_money_transactions":
      return getMoneyTransactions(req, res);
    case "get_money_payout_summary":
      return getMoneyPayoutSummary(req, res);
    case "debug_get_money_ledger_snapshot":
      return debugGetMoneyLedgerSnapshot(req, res);
    case "get_honey_balance":
      return getHoneyBalance(req, res);
    case "get_honey_policy":
      return getHoneyPolicy(req, res);
    case "record_honey_activity":
      return recordHoneyActivity(req, res);
    case "grant_honey":
      return grantHoney(req, res);
    case "debit_honey":
      return debitHoney(req, res);
    case "preview_hive_honey_purchase":
      return previewHiveHoneyPurchase(req, res);
    case "debit_hive_honey_purchase":
      return debitHiveHoneyPurchase(req, res);
    case "get_honey_transactions":
      return getHoneyTransactions(req, res);
    case "debug_set_honey_balance":
      return debugSetHoneyBalance(req, res);
    case "debug_get_honey_ledger_snapshot":
      return debugGetHoneyLedgerSnapshot(req, res);
    case "get_crucible_config":
      return getCrucibleConfig(req, res);
    case "update_crucible_config":
      return updateCrucibleConfig(req, res);
    case "preview_crucible_entry":
      return previewCrucibleEntry(req, res);
    case "open_crucible_escrow":
      return openCrucibleEscrow(req, res);
    case "settle_crucible_match":
      return settleCrucibleMatch(req, res);
    case "refund_crucible_match":
      return refundCrucibleMatch(req, res);
    case "resolve_crucible_review":
      return resolveCrucibleReview(req, res);
    case "record_crucible_lifecycle":
      return recordCrucibleLifecycle(req, res);
    case "get_wax_policy":
      return getWaxPolicy(req, res);
    case "record_competitive_wax_result":
      return recordCompetitiveWaxResult(req, res);
    case "award_crucible_wax":
      return awardCrucibleWax(req, res);
    case "debug_set_crucible_balance":
      return debugSetCrucibleBalance(req, res);
    case "debug_get_crucible_snapshot":
      return debugGetCrucibleSnapshot(req, res);
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
    case "create_spectator_grant":
      return createSpectatorGrant(req, res);
    case "join_spectate":
      return joinSpectate(req, res);
    case "poll_spectator_events":
      return pollSpectatorEvents(req, res);
    case "publish_spectator_snapshot":
      return publishSpectatorSnapshot(req, res);
    case "poll_spectator_snapshots":
      return pollSpectatorSnapshots(req, res);
    case "leave_spectate":
      return leaveSpectate(req, res);
    case "publish_intent":
      return publishIntent(req, res);
    case "poll_intents":
      return pollIntents(req, res);
    default:
      return fail(res, "unknown_action", 404, { action: actionName(req) });
  }
}

function bearerToken(req: Request): string {
  const header = stringValue(req.header("authorization") ?? req.header("Authorization"));
  const prefix = "bearer ";
  if (header.toLowerCase().startsWith(prefix)) {
    return header.slice(prefix.length).trim();
  }
  return "";
}

function spectatorAdminAuthorized(req: Request): boolean {
  if (!config.spectatorEnabled) {
    return false;
  }
  if (config.spectatorDevOpen) {
    return true;
  }
  const expected = stringValue(config.spectatorAdminToken);
  if (!expected) {
    return false;
  }
  const supplied = bearerToken(req) || stringValue(req.body?.admin_token);
  return supplied === expected;
}

function normalizeSpectatorRole(value: unknown): SpectatorRole | null {
  const role = stringValue(value).toLowerCase() as SpectatorRole;
  if (!SPECTATOR_ROLES.has(role)) {
    return null;
  }
  if (role === "public_delayed_spectate" && !config.spectatorPublicEnabled) {
    return null;
  }
  return role;
}

function spectatorDelay(role: SpectatorRole, requestedValue: unknown): { delay_sec: number; live: boolean } {
  const requested = Math.trunc(numberValue(requestedValue, config.spectatorDefaultDelaySec));
  if (role === "admin_spectate" && config.spectatorLiveEnabled && requested <= 0) {
    return { delay_sec: 0, live: true };
  }
  const minDelay = Math.max(0, Math.trunc(config.spectatorMinDelaySec));
  const maxDelay = Math.max(minDelay, Math.trunc(config.spectatorMaxDelaySec));
  const fallback = Math.min(maxDelay, Math.max(minDelay, Math.trunc(config.spectatorDefaultDelaySec)));
  const delay = Number.isFinite(requested) ? requested : fallback;
  return { delay_sec: Math.min(maxDelay, Math.max(minDelay, delay)), live: false };
}

function spectatorGrantResponse(grant: SpectatorGrant, includeToken = false): JsonRecord {
  return {
    id: grant.id,
    ...(includeToken ? { token: grant.token } : {}),
    session_id: grant.session_id,
    role: grant.role,
    spectator_uid: grant.spectator_uid,
    display_name: grant.display_name,
    created_unix: grant.created_unix,
    expires_unix: grant.expires_unix,
    delay_sec: grant.delay_sec,
    live: grant.live,
    joined_unix: grant.joined_unix ?? 0,
    last_seen_unix: grant.last_seen_unix ?? 0
  };
}

function resolveSpectatorGrant(req: Request): SpectatorGrant | null {
  const token = stringValue(req.body?.grant_token ?? req.body?.spectator_token);
  if (!token) {
    return null;
  }
  const grant = spectatorGrants.get(token);
  if (!grant || nowUnix() > grant.expires_unix) {
    if (grant) {
      spectatorGrants.delete(token);
    }
    return null;
  }
  return grant;
}

function createSpectatorGrant(req: Request, res: Response): void {
  if (!spectatorAdminAuthorized(req)) {
    return fail(res, "spectator_unauthorized", 403);
  }
  const sessionId = stringValue(req.body?.session_id);
  const session = sessions.get(sessionId);
  if (!session || !isSessionLive(session)) {
    if (session) {
      closeSession(sessionId, "expired");
    }
    return fail(res, "session_not_found", 404);
  }
  const role = normalizeSpectatorRole(req.body?.role ?? "invited_spectator");
  if (role == null) {
    return fail(res, "invalid_spectator_role");
  }
  const delay = spectatorDelay(role, req.body?.delay_sec);
  const createdUnix = nowUnix();
  const ttlSec = Math.max(60, Math.trunc(config.spectatorGrantTtlSec));
  const token = nextSpectatorGrantToken();
  const grant: SpectatorGrant = {
    id: nextSpectatorGrantId(),
    token,
    session_id: session.id,
    role,
    spectator_uid: stringValue(req.body?.spectator_uid),
    display_name: stringValue(req.body?.display_name) || "Spectator",
    created_unix: createdUnix,
    expires_unix: createdUnix + ttlSec,
    delay_sec: delay.delay_sec,
    live: delay.live
  };
  spectatorGrants.set(token, grant);
  return ok(res, { grant: spectatorGrantResponse(grant, true) });
}

function joinSpectate(req: Request, res: Response): void {
  const grant = resolveSpectatorGrant(req);
  if (!grant) {
    return fail(res, "invalid_spectator_grant", 403);
  }
  const requestedSessionId = stringValue(req.body?.session_id);
  if (requestedSessionId && requestedSessionId !== grant.session_id) {
    return fail(res, "spectator_session_mismatch", 403);
  }
  const requestedUid = stringValue(req.body?.spectator_uid);
  if (grant.spectator_uid && requestedUid && requestedUid !== grant.spectator_uid) {
    return fail(res, "spectator_uid_mismatch", 403);
  }
  const session = sessions.get(grant.session_id);
  if (!session || !isSessionLive(session)) {
    if (session) {
      closeSession(grant.session_id, "expired");
    }
    return fail(res, "session_not_found", 404);
  }
  const now = nowUnix();
  grant.joined_unix = grant.joined_unix ?? now;
  grant.last_seen_unix = now;
  return ok(res, {
    spectator: spectatorGrantResponse(grant, false),
    session: cloneSession(session)
  });
}

function pollSpectatorEvents(req: Request, res: Response): void {
  const grant = resolveSpectatorGrant(req);
  if (!grant) {
    return fail(res, "invalid_spectator_grant", 403);
  }
  const requestedSessionId = stringValue(req.body?.session_id);
  if (requestedSessionId && requestedSessionId !== grant.session_id) {
    return fail(res, "spectator_session_mismatch", 403);
  }
  const session = sessions.get(grant.session_id);
  if (!session || !isSessionLive(session)) {
    if (session) {
      closeSession(grant.session_id, "expired");
    }
    return fail(res, "session_not_found", 404);
  }
  grant.last_seen_unix = nowUnix();
  const afterSeq = Math.max(0, Math.trunc(numberValue(req.body?.after_seq, 0)));
  const stream = intentStreams.get(grant.session_id);
  if (!stream) {
    return ok(res, {
      latest_seq: afterSeq,
      events: [],
      delay_sec: grant.delay_sec,
      live: grant.live
    });
  }
  const cutoffUnix = nowUnix() - Math.max(0, grant.delay_sec);
  const visibleEvents = stream.events
    .filter((event) => event.seq > afterSeq && event.ts_unix <= cutoffUnix)
    .slice(-Math.max(1, config.spectatorStreamMaxEvents))
    .map((event) => ({ ...event, command: { ...event.command } }));
  const latestVisibleSeq = visibleEvents.reduce((latest, event) => Math.max(latest, Number(event.seq ?? 0)), afterSeq);
  return ok(res, {
    latest_seq: latestVisibleSeq,
    events: visibleEvents,
    delay_sec: grant.delay_sec,
    live: grant.live
  });
}

function leaveSpectate(req: Request, res: Response): void {
  const grant = resolveSpectatorGrant(req);
  if (!grant) {
    return fail(res, "invalid_spectator_grant", 403);
  }
  spectatorGrants.delete(grant.token);
  return ok(res, { closed: true, spectator: spectatorGrantResponse(grant, false) });
}

function publishSpectatorSnapshot(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const uid = stringValue(req.body?.uid);
  const snapshot = req.body?.snapshot;
  const session = sessions.get(sessionId);
  if (!session || !uid || !isRecord(snapshot)) {
    return fail(res, "invalid_args");
  }
  if (!sessionHasPlayer(session, uid)) {
    return fail(res, "player_not_in_session");
  }
  const stream = spectatorSnapshotStreams.get(sessionId) ?? { nextSeq: 1, snapshots: [] };
  const seq = stream.nextSeq;
  stream.nextSeq += 1;
  stream.snapshots.push({
    seq,
    uid,
    snapshot: cloneContext(snapshot),
    ts_unix: nowUnix()
  });
  while (stream.snapshots.length > config.spectatorStreamMaxEvents) {
    stream.snapshots.shift();
  }
  spectatorSnapshotStreams.set(sessionId, stream);
  return ok(res, { seq, snapshot_seq: seq });
}

function pollSpectatorSnapshots(req: Request, res: Response): void {
  const grant = resolveSpectatorGrant(req);
  if (!grant) {
    return fail(res, "invalid_spectator_grant", 403);
  }
  const requestedSessionId = stringValue(req.body?.session_id);
  if (requestedSessionId && requestedSessionId !== grant.session_id) {
    return fail(res, "spectator_session_mismatch", 403);
  }
  const session = sessions.get(grant.session_id);
  if (!session || !isSessionLive(session)) {
    if (session) {
      closeSession(grant.session_id, "expired");
    }
    return fail(res, "session_not_found", 404);
  }
  grant.last_seen_unix = nowUnix();
  const afterSeq = Math.max(0, Math.trunc(numberValue(req.body?.after_seq, 0)));
  const stream = spectatorSnapshotStreams.get(grant.session_id);
  if (!stream) {
    return ok(res, {
      latest_seq: afterSeq,
      snapshots: [],
      delay_sec: grant.delay_sec,
      live: grant.live
    });
  }
  const cutoffUnix = nowUnix() - Math.max(0, grant.delay_sec);
  const visibleSnapshots = stream.snapshots
    .filter((snapshot) => snapshot.seq > afterSeq && snapshot.ts_unix <= cutoffUnix)
    .slice(-Math.max(1, config.spectatorStreamMaxEvents))
    .map((snapshot) => ({ ...snapshot, snapshot: cloneContext(snapshot.snapshot) }));
  const latestVisibleSeq = visibleSnapshots.reduce((latest, snapshot) => Math.max(latest, Number(snapshot.seq ?? 0)), afterSeq);
  return ok(res, {
    latest_seq: latestVisibleSeq,
    snapshots: visibleSnapshots,
    delay_sec: grant.delay_sec,
    live: grant.live
  });
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
  const previousGuest = { ...session.guest };
  const existingReady = session.guest.ready;
  session.guest = {
    uid: guest.uid,
    display_name: guest.display_name,
    ready: existingReady,
    tier_id: guest.tier_id,
    rank_position: guest.rank_position,
    wax_score: guest.wax_score,
    color_id: guest.color_id,
    balance_cents: guest.balance_cents,
    crucible_wax_millis: guest.crucible_wax_millis
  };
  const startResult = startSessionAuthoritatively(session);
  if (startResult.ok !== true) {
    session.guest = previousGuest;
    refreshSessionStatus(session);
    return failLedger(res, startResult, 402);
  }
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
      color_id: other.color_id,
      balance_cents: other.balance_cents,
      crucible_wax_millis: other.crucible_wax_millis
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
      color_id: player.color_id,
      balance_cents: player.balance_cents,
      crucible_wax_millis: player.crucible_wax_millis
    };
    const startResult = startSessionAuthoritatively(session);
    if (startResult.ok !== true) {
      queue.splice(matchIndex, 0, other);
      return failLedger(res, startResult, 402);
    }
    sessions.set(session.id, session);
    inviteToSession.set(session.invite_code, session.id);
    return ok(res, { matched: true, session_id: session.id, session: cloneSession(session) });
  }
  if (contextIsCrucible(context)) {
    if (player.crucible_wax_millis != null) {
      crucibleLedger.setBalanceMillis(player.uid, player.crucible_wax_millis);
    }
    const entryStatus = crucibleLedger.previewEntryStatus(player.uid, activeCrucibleCount(), false);
    if (entryStatus.ok !== true) {
      return failLedger(res, entryStatus, entryStatus.err === "capacity" ? 409 : 402);
    }
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
    color_id: String(player.color_id ?? "GREEN"),
    balance_cents: player.balance_cents,
    crucible_wax_millis: player.crucible_wax_millis
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
    ticket_id: ticketId,
    balance_cents: ticket.balance_cents,
    crucible_wax_millis: ticket.crucible_wax_millis
  };
  const session = newSession(host, ticket.context, "quick");
  session.guest = {
    uid: nextBotUid(),
    display_name: botName,
    ready: true,
    crucible_wax_millis: ticket.crucible_wax_millis
  };
  const startResult = startSessionAuthoritatively(session);
  if (startResult.ok !== true) {
    queue.splice(index, 0, ticket);
    return failLedger(res, startResult, 402);
  }
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
  const startResult = startSessionAuthoritatively(session);
  if (startResult.ok !== true) {
    return failLedger(res, startResult, 402);
  }
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
  const startResult = startSessionAuthoritatively(session);
  if (startResult.ok !== true) {
    return failLedger(res, startResult, 402);
  }
  return ok(res, { session: cloneSession(session) });
}

function playerBalanceHints(body: JsonRecord): Record<string, number> {
  const source = isRecord(body.player_balances_cents) ? body.player_balances_cents : {};
  const out: Record<string, number> = {};
  for (const [key, value] of Object.entries(source)) {
    const playerId = stringValue(key);
    const balance = optionalCentsValue(value);
    if (playerId && balance != null) {
      out[playerId] = balance;
    }
  }
  return out;
}

function requestPlayerFundings(body: JsonRecord, fallbackPlayers: Player[] = []): { player_id: string; balance_cents?: number }[] {
  const balances = playerBalanceHints(body);
  const rawPlayerIds = Array.isArray(body.player_ids) ? body.player_ids : [];
  const playerIds = rawPlayerIds.map((value: unknown) => stringValue(value)).filter(Boolean);
  if (playerIds.length > 0) {
    return playerIds.map((playerId) => ({ player_id: playerId, balance_cents: balances[playerId] }));
  }
  return fallbackPlayers
    .filter((player) => Boolean(player.uid))
    .map((player) => ({
      player_id: player.uid,
      balance_cents: player.balance_cents ?? balances[player.uid]
    }));
}

function openMoneyEscrow(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const session = sessions.get(sessionId);
  const fallbackPlayers = session ? [session.host, session.guest] : [];
  const wagerCents = Math.trunc(numberValue(req.body?.wager_cents, session ? contextWagerCents(session.context) : 0));
  const idempotencyKey = stringValue(req.body?.idempotency_key);
  const result = moneyLedger.openMoneyEscrow(sessionId, requestPlayerFundings(req.body ?? {}, fallbackPlayers), wagerCents, idempotencyKey);
  if (result.ok === true && session) {
    session.context = {
      ...session.context,
      paid_entry: true,
      free_roll: false,
      wager_cents: wagerCents,
      price_usd: wagerCents / 100,
      ledger_status: "escrowed",
      pot_cents: Number(result.pot_cents ?? 0)
    };
  }
  return okOrLedgerFailure(res, result, 402);
}

function settleMoneyMatch(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const result = moneyLedger.settleMoneyMatch(sessionId, stringValue(req.body?.winner_id), stringValue(req.body?.idempotency_key));
  const session = sessions.get(sessionId);
  if (result.ok === true && session) {
    session.context = {
      ...session.context,
      ledger_status: "settled",
      winner_id: stringValue(result.winner_id),
      winner_payout_cents: Number(result.winner_payout_cents ?? 0),
      house_rake_cents: Number(result.house_rake_cents ?? 0)
    };
  }
  return okOrLedgerFailure(res, result);
}

function refundMoneyMatch(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const result = moneyLedger.refundMoneyMatch(
    sessionId,
    stringValue(req.body?.reason),
    stringValue(req.body?.idempotency_key)
  );
  const session = sessions.get(sessionId);
  if (result.ok === true && session) {
    session.context = {
      ...session.context,
      ledger_status: "refunded",
      refund_reason: stringValue(result.refund_reason)
    };
  }
  return okOrLedgerFailure(res, result);
}

function openAsyncEntryEscrow(req: Request, res: Response): void {
  const body = (req.body ?? {}) as JsonRecord;
  const playerId = stringValue(body.player_id);
  const balances = playerBalanceHints(body);
  const player = {
    player_id: playerId,
    balance_cents: optionalCentsValue(body.balance_cents) ?? balances[playerId]
  };
  const result = moneyLedger.openAsyncEntryEscrow(
    stringValue(body.entry_id),
    stringValue(body.contest_id),
    player,
    Math.trunc(numberValue(body.wager_cents, 0)),
    stringValue(body.idempotency_key)
  );
  return okOrLedgerFailure(res, result, 402);
}

function submitAsyncContestResult(req: Request, res: Response): void {
  const body = (req.body ?? {}) as JsonRecord;
  const result = moneyLedger.submitAsyncContestResult(
    stringValue(body.contest_id),
    stringValue(body.contest_family),
    stringValue(body.player_id),
    isRecord(body.result) ? body.result : body,
    stringValue(body.idempotency_key)
  );
  return okOrLedgerFailure(res, result);
}

function listAsyncContestResults(req: Request, res: Response): void {
  const filters = isRecord(req.body?.filters) ? req.body.filters : (req.body ?? {});
  return ok(res, { results: moneyLedger.listAsyncContestResults(filters) });
}

function previewAsyncContestResultPayoutReport(req: Request, res: Response): void {
  const result = moneyLedger.previewAsyncContestResultPayoutReport(
    stringValue(req.body?.contest_id),
    stringValue(req.body?.contest_family),
    Array.isArray(req.body?.payout_schedule) ? req.body.payout_schedule : Array.isArray(req.body?.payouts) ? req.body.payouts : [],
    Math.trunc(numberValue(req.body?.house_rake_bps, 1000)),
    isRecord(req.body?.options) ? req.body.options : (req.body ?? {})
  );
  return okOrLedgerFailure(res, result);
}

function settleAsyncContest(req: Request, res: Response): void {
  if (Array.isArray(req.body?.payouts)) {
    return settleAsyncContestPayouts(req, res);
  }
  const result = moneyLedger.settleAsyncContest(
    stringValue(req.body?.contest_id),
    stringValue(req.body?.winner_id),
    stringValue(req.body?.idempotency_key)
  );
  return okOrLedgerFailure(res, result);
}

function settleAsyncContestPayouts(req: Request, res: Response): void {
  const result = moneyLedger.settleAsyncContestPayouts(
    stringValue(req.body?.contest_id),
    Array.isArray(req.body?.payouts) ? req.body.payouts : [],
    Math.trunc(numberValue(req.body?.house_rake_cents, 0)),
    stringValue(req.body?.idempotency_key)
  );
  return okOrLedgerFailure(res, result);
}

function settleAsyncContestPayoutPercentages(req: Request, res: Response): void {
  const result = moneyLedger.settleAsyncContestPayoutPercentages(
    stringValue(req.body?.contest_id),
    Array.isArray(req.body?.payouts) ? req.body.payouts : [],
    Math.trunc(numberValue(req.body?.house_rake_bps, 1000)),
    stringValue(req.body?.idempotency_key)
  );
  return okOrLedgerFailure(res, result);
}

function previewAsyncContestPayoutReport(req: Request, res: Response): void {
  const result = moneyLedger.previewAsyncContestPayoutApprovalReport(
    stringValue(req.body?.contest_id),
    Array.isArray(req.body?.payouts) ? req.body.payouts : [],
    Math.trunc(numberValue(req.body?.house_rake_bps, 1000))
  );
  return okOrLedgerFailure(res, result);
}

function listAsyncContestPayoutReports(req: Request, res: Response): void {
  const filters = isRecord(req.body?.filters) ? req.body.filters : (req.body ?? {});
  return ok(res, { reports: moneyLedger.listAsyncContestPayoutApprovalReports(filters) });
}

function approveAsyncContestPayoutReport(req: Request, res: Response): void {
  const report = isRecord(req.body?.report) ? req.body.report : {};
  const result = moneyLedger.approveAsyncContestPayoutReport(
    report,
    stringValue(req.body?.approver_id),
    stringValue(req.body?.idempotency_key)
  );
  if (result.ok === true) {
    result.wax_awards = recordAsyncContestWaxAwards(report, result, stringValue(req.body?.idempotency_key));
  }
  return okOrLedgerFailure(res, result);
}

function recordAsyncContestWaxAwards(report: JsonRecord, settlement: JsonRecord, idempotencyKey: string): JsonRecord[] {
  const contestId = stringValue(settlement.contest_id ?? report.contest_id);
  if (!contestId) {
    return [];
  }
  const approvalId = stringValue(settlement.approval_id ?? report.report_id) || stringValue(settlement.settle_idempotency_key) || idempotencyKey;
  const contestFamily = stringValue(settlement.contest_family ?? report.contest_family) || "ASYNC";
  const sourceRows = asyncWaxPlacementRows(report, settlement);
  const fieldSize = Math.max(
    sourceRows.length,
    Math.trunc(numberValue(report.players_count ?? settlement.players_count, 0)),
    Math.trunc(numberValue(report.qualified_results_count ?? settlement.qualified_results_count, 0))
  );
  const awards: JsonRecord[] = [];
  for (const row of sourceRows) {
    const playerId = stringValue(row.player_id);
    const placement = Math.max(1, Math.trunc(numberValue(row.placement ?? row.rank, 0)));
    if (!playerId || placement <= 0) {
      continue;
    }
    const eventId = `competitive_wax:async:${contestId}:${playerId}:${approvalId || "approval"}`;
    const waxResult = crucibleLedger.recordCompetitiveWaxResult({
      match_id: `async:${contestId}`,
      player_id: playerId,
      opponent_id: "",
      mode_name: "ASYNC",
      did_win: placement === 1,
      placement_based: true,
      placement,
      field_size: Math.max(1, fieldSize),
      event_id: eventId,
      metadata: {
        contest_id: contestId,
        contest_family: contestFamily,
        approval_id: approvalId,
        placement,
        field_size: Math.max(1, fieldSize),
        payout_approved: true,
        result_source: stringValue(report.result_source ?? settlement.result_source),
        payout_cents: Math.max(0, Math.trunc(numberValue(row.amount_cents ?? row.payout_cents, 0)))
      }
    }, eventId);
    awards.push({
      player_id: playerId,
      placement,
      event_id: eventId,
      wax_result: waxResult
    });
  }
  return awards;
}

function asyncWaxPlacementRows(report: JsonRecord, settlement: JsonRecord): JsonRecord[] {
  const leaderboardRows = Array.isArray(report.leaderboard_rows) ? report.leaderboard_rows : [];
  if (leaderboardRows.length > 0) {
    return leaderboardRows
      .filter((row): row is JsonRecord => isRecord(row))
      .map((row, index) => ({
        ...row,
        placement: Math.max(1, Math.trunc(numberValue(row.placement ?? row.rank, index + 1)))
      }));
  }
  const payoutRows = Array.isArray(settlement.payouts) ? settlement.payouts : Array.isArray(report.planned_payouts) ? report.planned_payouts : [];
  return payoutRows
    .filter((row): row is JsonRecord => isRecord(row))
    .map((row, index) => ({
      ...row,
      placement: Math.max(1, Math.trunc(numberValue(row.placement ?? row.rank, index + 1)))
    }));
}

function refundAsyncEntry(req: Request, res: Response): void {
  const result = moneyLedger.refundAsyncEntry(
    stringValue(req.body?.entry_id),
    stringValue(req.body?.reason),
    stringValue(req.body?.idempotency_key)
  );
  return okOrLedgerFailure(res, result);
}

function getMoneyTransactions(req: Request, res: Response): void {
  const filters = isRecord(req.body?.filters) ? req.body.filters : (req.body ?? {});
  return ok(res, { transactions: moneyLedger.getTransactionLedger(filters) });
}

function getMoneyPayoutSummary(req: Request, res: Response): void {
  const filters = isRecord(req.body?.filters) ? req.body.filters : (req.body ?? {});
  return ok(res, moneyLedger.getPayoutSummary(filters));
}

function debugGetMoneyLedgerSnapshot(_req: Request, res: Response): void {
  return ok(res, { ledger: moneyLedger.getSnapshot() });
}

function honeyMemberIds(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((entry) => stringValue(entry)).filter(Boolean);
}

function honeyCostCenti(body: JsonRecord): number {
  const direct = Number(body.cost_centi);
  if (Number.isFinite(direct)) {
    return Math.max(0, Math.trunc(direct));
  }
  const fallback = Number(body.honey_cost_centi);
  return Number.isFinite(fallback) ? Math.max(0, Math.trunc(fallback)) : 0;
}

function getHoneyBalance(req: Request, res: Response): void {
  const playerId = stringValue(req.body?.player_id);
  const result = honeyLedger.getBalanceSnapshot(playerId);
  return okOrLedgerFailure(res, result, 404);
}

function getHoneyPolicy(_req: Request, res: Response): void {
  return ok(res, { policy: honeyActivitySpecsSnapshot() });
}

function recordHoneyActivity(req: Request, res: Response): void {
  if (!requireMatchAuthority(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const opponentIds = Array.isArray(body.opponent_ids) ? body.opponent_ids.map((entry) => stringValue(entry)).filter(Boolean) : [];
  const result = honeyLedger.recordActivity({
    player_id: stringValue(body.player_id),
    activity_key: stringValue(body.activity_key),
    entap_title: stringValue(body.entap_title),
    completed: body.completed == null ? true : boolValue(body.completed),
    early_quit: boolValue(body.early_quit),
    duration_sec: numberValue(body.duration_sec, 0),
    opponent_ids: opponentIds,
    occurred_unix: Math.trunc(numberValue(body.occurred_unix, 0)),
    metadata
  }, stringValue(body.idempotency_key));
  return okOrLedgerFailure(res, result, 402);
}

function grantHoney(req: Request, res: Response): void {
  if (!requireMatchAuthority(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const result = honeyLedger.grant(
    stringValue(body.player_id),
    Math.trunc(numberValue(body.amount_centi, 0)),
    stringValue(body.source),
    metadata,
    stringValue(body.idempotency_key)
  );
  return okOrLedgerFailure(res, result, 402);
}

function debitHoney(req: Request, res: Response): void {
  if (!requireMatchAuthority(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const result = honeyLedger.debit(
    stringValue(body.player_id),
    Math.trunc(numberValue(body.amount_centi, 0)),
    stringValue(body.source),
    metadata,
    stringValue(body.idempotency_key)
  );
  return okOrLedgerFailure(res, result, 402);
}

function previewHiveHoneyPurchase(req: Request, res: Response): void {
  const body = (req.body ?? {}) as JsonRecord;
  const result = honeyLedger.previewHivePurchase(
    stringValue(body.hive_id),
    honeyMemberIds(body.member_ids),
    honeyCostCenti(body)
  );
  return okOrLedgerFailure(res, result, 402);
}

function debitHiveHoneyPurchase(req: Request, res: Response): void {
  if (!requireMatchAuthority(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const result = honeyLedger.debitHivePurchase(
    stringValue(body.hive_id),
    honeyMemberIds(body.member_ids),
    honeyCostCenti(body),
    stringValue(body.source),
    metadata,
    stringValue(body.idempotency_key)
  );
  return okOrLedgerFailure(res, result, 402);
}

function getHoneyTransactions(req: Request, res: Response): void {
  const filters = isRecord(req.body?.filters) ? req.body.filters : (req.body ?? {});
  return ok(res, { transactions: honeyLedger.getTransactionLedger(filters) });
}

function debugSetHoneyBalance(req: Request, res: Response): void {
  if (!requireAdmin(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const result = honeyLedger.setBalanceCenti(
    stringValue(body.player_id),
    Math.trunc(numberValue(body.balance_centi, 0)),
    stringValue(body.source) || "ops_debug",
    metadata,
    stringValue(body.idempotency_key)
  );
  return okOrLedgerFailure(res, result);
}

function debugGetHoneyLedgerSnapshot(req: Request, res: Response): void {
  if (!requireAdmin(req, res)) {
    return;
  }
  return ok(res, { ledger: honeyLedger.getSnapshot() });
}

function getCrucibleConfig(_req: Request, res: Response): void {
  return ok(res, {
    config: crucibleLedger.getConfigSnapshot(),
    active_crucible_count: activeCrucibleCount(),
    storage: crucibleLedger.getStorageSnapshot(),
    authority: {
      match_authority_required: Boolean(config.matchAuthorityToken),
      admin_auth_required: Boolean(config.adminToken)
    }
  });
}

function updateCrucibleConfig(req: Request, res: Response): void {
  if (!requireAdmin(req, res)) {
    return;
  }
  const patch = isRecord(req.body?.patch) ? req.body.patch : (req.body ?? {});
  const result = crucibleLedger.updateConfig(patch, stringValue(req.body?.actor_id) || "ops");
  return ok(res, result);
}

function previewCrucibleEntry(req: Request, res: Response): void {
  const body = (req.body ?? {}) as JsonRecord;
  const playerId = stringValue(body.player_id);
  const balance = optionalCentsValue(body.balance_millis ?? body.crucible_wax_millis);
  if (balance != null) {
    if (!requestMayProvideCrucibleBalanceHint(req)) {
      fail(res, "crucible_balance_hint_auth_required", 401, { authority: "admin_or_match_authority" });
      return;
    }
    crucibleLedger.setBalanceMillis(playerId, balance);
  }
  const count = body.active_crucible_count == null ? activeCrucibleCount() : Math.max(0, Math.trunc(numberValue(body.active_crucible_count, 0)));
  const result = crucibleLedger.previewEntryStatus(playerId, count, boolValue(body.has_priority_access));
  return okOrLedgerFailure(res, result, result.err === "capacity" ? 409 : 402);
}

function openCrucibleEscrow(req: Request, res: Response): void {
  if (!requireMatchAuthority(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const result = crucibleLedger.openEscrow(
    stringValue(body.match_id),
    stringValue(body.player_a_id),
    stringValue(body.player_b_id),
    metadata,
    stringValue(body.idempotency_key)
  );
  return okOrLedgerFailure(res, result, 402);
}

function settleCrucibleMatch(req: Request, res: Response): void {
  if (!requireMatchAuthority(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const result = crucibleLedger.settleMatch(
    stringValue(body.match_id),
    stringValue(body.winner_id),
    stringValue(body.result_source),
    stringValue(body.reason),
    metadata,
    stringValue(body.idempotency_key)
  );
  return okOrLedgerFailure(res, result);
}

function refundCrucibleMatch(req: Request, res: Response): void {
  if (!requireAdmin(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const result = crucibleLedger.refundMatch(
    stringValue(body.match_id),
    stringValue(body.reason),
    stringValue(body.result_source) || "SERVER_MATCH_RESULT",
    metadata,
    stringValue(body.idempotency_key)
  );
  return okOrLedgerFailure(res, result);
}

function resolveCrucibleReview(req: Request, res: Response): void {
  if (!requireAdmin(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const result = crucibleLedger.resolveReview(
    stringValue(body.match_id),
    stringValue(body.action),
    stringValue(body.actor_id) || "ops",
    metadata,
    stringValue(body.idempotency_key)
  );
  return okOrLedgerFailure(res, result);
}

function recordCrucibleLifecycle(req: Request, res: Response): void {
  if (!requireMatchAuthority(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const result = crucibleLedger.recordLifecycle(
    stringValue(body.match_id),
    stringValue(body.event_type),
    stringValue(body.player_id),
    metadata
  );
  return okOrLedgerFailure(res, result);
}

function awardCrucibleWax(req: Request, res: Response): void {
  if (!requireAdmin(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const result = crucibleLedger.awardWax(
    stringValue(body.player_id),
    Math.trunc(numberValue(body.amount_millis, 0)),
    stringValue(body.source),
    metadata
  );
  return okOrLedgerFailure(res, result);
}

function getWaxPolicy(_req: Request, res: Response): void {
  return ok(res, { policy: waxPolicySnapshot() });
}

function recordCompetitiveWaxResult(req: Request, res: Response): void {
  if (!requireMatchAuthority(req, res)) {
    return;
  }
  const body = (req.body ?? {}) as JsonRecord;
  const metadata = isRecord(body.metadata) ? body.metadata : {};
  const result = crucibleLedger.recordCompetitiveWaxResult({
    ...body,
    metadata,
    match_id: stringValue(body.match_id),
    player_id: stringValue(body.player_id),
    opponent_id: stringValue(body.opponent_id),
    mode_name: stringValue(body.mode_name ?? body.mode),
    did_win: boolValue(body.did_win),
    close_loss_qualified: boolValue(body.close_loss_qualified),
    player_rating: numberValue(body.player_rating ?? body.player_wax_score, 0),
    opponent_rating: numberValue(body.opponent_rating ?? body.opponent_wax_score, 0),
    occurred_unix: Math.trunc(numberValue(body.occurred_unix, 0))
  }, stringValue(body.idempotency_key));
  return okOrLedgerFailure(res, result, 402);
}

function debugSetCrucibleBalance(req: Request, res: Response): void {
  if (!requireAdmin(req, res)) {
    return;
  }
  const result = crucibleLedger.setBalanceMillis(stringValue(req.body?.player_id), Math.trunc(numberValue(req.body?.balance_millis, 0)));
  return okOrLedgerFailure(res, result);
}

function debugGetCrucibleSnapshot(req: Request, res: Response): void {
  if (!requireAdmin(req, res)) {
    return;
  }
  return ok(res, { ledger: crucibleLedger.getSnapshot() });
}

function leaveSession(req: Request, res: Response): void {
  const sessionId = stringValue(req.body?.session_id);
  const uid = stringValue(req.body?.uid);
  const session = sessions.get(sessionId);
  if (!session || !uid) {
    return fail(res, "session_not_found", 404);
  }
  if (session.status === "started" && contextIsCrucible(session.context) && sessionHasPlayer(session, uid)) {
    const matchId = stringValue(session.context.crucible_match_id) || `crucible_${session.id}`;
    const settlement = crucibleLedger.recordLifecycle(matchId, "voluntary_quit", uid, {
      session_id: session.id,
      suspicious_forfeit: true
    });
    session.context = {
      ...session.context,
      crucible_ledger_status: settlement.ok === true ? "settled" : "settlement_failed",
      crucible_leave_result: settlement
    };
    closeSession(sessionId, uid === session.host.uid ? "host_left_forfeit" : "guest_left_forfeit");
    return ok(res, { closed: true, settlement });
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
  const previousGuest = { ...session.guest };
  session.guest = {
    uid: guest.uid,
    display_name: guest.display_name || "Player 2",
    ready: false,
    tier_id: guest.tier_id,
    rank_position: guest.rank_position,
    wax_score: guest.wax_score,
    color_id: guest.color_id,
    balance_cents: guest.balance_cents
  };
  const startResult = startSessionAuthoritatively(session);
  if (startResult.ok !== true) {
    session.guest = previousGuest;
    refreshSessionStatus(session);
    return failLedger(res, startResult, 402);
  }
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
  const stream = intentStreams.get(sessionId) ?? { nextSeq: 1, events: [], lastExecuteTick: -1 };
  const seq = stream.nextSeq;
  stream.nextSeq += 1;
  const canonicalCommand = canonicalizeAuthoritativeCommand(sessionId, uid, command, seq, stream);
  stream.events.push({ seq, uid, command: canonicalCommand, ts_unix: nowUnix() });
  while (stream.events.length > config.intentStreamMaxEvents) {
    stream.events.shift();
  }
  intentStreams.set(sessionId, stream);
  return ok(res, {
    seq,
    command_seq: seq,
    command_id: stringValue(canonicalCommand.command_id),
    command: { ...canonicalCommand },
    canonical_command: { ...canonicalCommand }
  });
}

function canonicalizeAuthoritativeCommand(
  sessionId: string,
  senderUid: string,
  command: JsonRecord,
  seq: number,
  stream: IntentStream
): JsonRecord {
  const canonical = cloneContext(command);
  const commandSeq = Math.max(1, Math.trunc(seq));
  const issuedTick = Math.trunc(numberValue(canonical.issued_tick ?? canonical.local_issued_tick, 0));
  const requestedExecuteTick = Math.trunc(numberValue(canonical.requested_execute_tick ?? canonical.execute_tick, issuedTick + 3));
  const minExecuteTick = issuedTick + 3;
  let executeTick = requestedExecuteTick;
  if (executeTick < minExecuteTick) {
    executeTick = minExecuteTick;
  }
  if (executeTick <= stream.lastExecuteTick) {
    executeTick = stream.lastExecuteTick + 1;
  }
  stream.lastExecuteTick = executeTick;
  canonical.command_seq = commandSeq;
  canonical.command_id = `${sessionId}:${commandSeq}`;
  canonical.authority_session_id = sessionId;
  canonical.authority_uid = senderUid;
  canonical.canonical_execute_tick = executeTick;
  canonical.execute_tick = executeTick;
  canonical.requested_execute_tick = requestedExecuteTick;
  canonical.authority_action = executeTick === requestedExecuteTick ? "accepted" : "rebased";
  return canonical;
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
      queue: queue.length,
      spectator_grants: spectatorGrants.size,
      spectator_snapshot_streams: spectatorSnapshotStreams.size,
      crucible: {
        storage: crucibleLedger.getStorageSnapshot(),
        configured_storage: config.crucibleLedgerStore,
        configured_path: config.crucibleLedgerPath,
        admin_auth_required: Boolean(config.adminToken),
        match_authority_required: Boolean(config.matchAuthorityToken)
      },
      honey: {
        storage: honeyLedger.getStorageSnapshot(),
        configured_storage: config.honeyLedgerStore,
        configured_path: config.honeyLedgerPath,
        precision: "centi_honey",
        admin_auth_required: Boolean(config.adminToken),
        match_authority_required: Boolean(config.matchAuthorityToken)
      }
    });
  });
  app.get("/", (_req, res) => {
    ok(res, {
      service: "swarmfront-vs-service",
      build: serviceBuild,
      dashboard: "/dash",
      api_base: "/v1"
    });
  });
  app.get("/dash", handleContestDashPage);
  app.get("/v1", (_req, res) => {
    ok(res, {
      service: "swarmfront-vs-service",
      build: serviceBuild,
      dashboard: contestDashInfo(),
      routes: {
        health: "/v1/health",
        create_invite: "POST /v1/create_invite",
        contest_dash_config: "GET/POST /v1/contest_dash/config",
        get_honey_balance: "POST /v1/get_honey_balance",
        record_honey_activity: "POST /v1/record_honey_activity",
        grant_honey: "POST /v1/grant_honey",
        debit_hive_honey_purchase: "POST /v1/debit_hive_honey_purchase",
        get_wax_policy: "POST /v1/get_wax_policy",
        record_competitive_wax_result: "POST /v1/record_competitive_wax_result"
      },
      crucible: {
        storage: crucibleLedger.getStorageSnapshot(),
        configured_storage: config.crucibleLedgerStore,
        configured_path: config.crucibleLedgerPath,
        admin_auth_required: Boolean(config.adminToken),
        match_authority_required: Boolean(config.matchAuthorityToken)
      },
      honey: {
        storage: honeyLedger.getStorageSnapshot(),
        configured_storage: config.honeyLedgerStore,
        configured_path: config.honeyLedgerPath,
        precision: "centi_honey",
        admin_auth_required: Boolean(config.adminToken),
        match_authority_required: Boolean(config.matchAuthorityToken)
      }
    });
  });
  app.get("/v1/health", (_req, res) => {
    prune();
    ok(res, {
      service: "swarmfront-vs-service",
      build: serviceBuild,
      uptime_sec: nowUnix() - processStartUnix,
      sessions: sessions.size,
      queue: queue.length,
      spectator_grants: spectatorGrants.size,
      spectator_snapshot_streams: spectatorSnapshotStreams.size,
      crucible: {
        storage: crucibleLedger.getStorageSnapshot(),
        configured_storage: config.crucibleLedgerStore,
        configured_path: config.crucibleLedgerPath,
        admin_auth_required: Boolean(config.adminToken),
        match_authority_required: Boolean(config.matchAuthorityToken)
      },
      honey: {
        storage: honeyLedger.getStorageSnapshot(),
        configured_storage: config.honeyLedgerStore,
        configured_path: config.honeyLedgerPath,
        precision: "centi_honey",
        admin_auth_required: Boolean(config.adminToken),
        match_authority_required: Boolean(config.matchAuthorityToken)
      }
    });
  });
  app.get("/v1/contest_dash/config", (req, res, next) => {
    void handleContestDashState(req, res).catch(next);
  });
  app.post("/v1/contest_dash/config", (req, res, next) => {
    void handleContestDashSave(req, res).catch(next);
  });
  app.post("/v1/contest_dash/delete", (req, res, next) => {
    void handleContestDashDelete(req, res).catch(next);
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
