import express, { type NextFunction, type Request, type Response } from "express";
import { config } from "./config.js";
import { pool } from "./db/pool.js";
import {
  applyDecayAll,
  buildLeaderboardView,
  computeGain,
  computeLoss,
  ensurePlayerExists,
  findMatchCandidates,
  newPlayerRecord,
  normalizedColorQuintiles,
  normalizePlayerRecord,
  nowUnix,
  orderedTierIds,
  playerSnapshot,
  pruneProcessedEvents,
  recomputeRankings,
  sanitizeFriends,
  stateSnapshot,
  tierNames
} from "./logic.js";
import { RankStore } from "./store.js";
import type { MatchQueueEntry, PlayerRecord, RankState } from "./types.js";

const CANONICAL_HUMAN_PLAYER_ID = /^u_[0-9a-f]{12}$/i;
const BOT_PLAYER_ID = /^bot_[0-9]{6}$/;
const PROCESS_START_UNIX = nowUnix();

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function toStringValue(value: unknown): string {
  return String(value ?? "").trim();
}

function toNumberValue(value: unknown, fallback = 0): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function toBooleanValue(value: unknown): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  const normalized = toStringValue(value).toLowerCase();
  if (!normalized) {
    return false;
  }
  if (["true", "1", "yes", "y", "on"].includes(normalized)) {
    return true;
  }
  if (["false", "0", "no", "n", "off"].includes(normalized)) {
    return false;
  }
  return false;
}

function redactDatabaseUrl(rawUrl: string): string {
  try {
    const parsed = new URL(rawUrl);
    const host = parsed.host || "unknown-host";
    const database = parsed.pathname.replace(/^\/+/, "") || "unknown-db";
    return `${parsed.protocol}//${host}/${database}`;
  } catch {
    return "configured";
  }
}

function isCanonicalHumanPlayerId(value: string): boolean {
  return CANONICAL_HUMAN_PLAYER_ID.test(value.trim());
}

function isRankParticipantId(value: string): boolean {
  const clean = value.trim();
  return isCanonicalHumanPlayerId(clean) || BOT_PLAYER_ID.test(clean);
}

function invalidRequest(res: Response, err: string, extra: Record<string, unknown> = {}): void {
  res.status(400).json({ ok: false, err, ...extra });
}

function requireCanonicalHumanPlayerId(res: Response, playerId: string, field: string): boolean {
  if (!config.enforceCanonicalPlayerIds || isCanonicalHumanPlayerId(playerId)) {
    return true;
  }
  invalidRequest(res, "invalid_player_id", { field, expected: "u_<12 hex chars>" });
  return false;
}

function requireRankParticipantId(res: Response, playerId: string, field: string): boolean {
  if (!config.enforceCanonicalPlayerIds || isRankParticipantId(playerId)) {
    return true;
  }
  invalidRequest(res, "invalid_player_id", { field, expected: "u_<12 hex chars> or bot_<6 digits>" });
  return false;
}

function requireFriendIds(res: Response, friendIds: string[]): boolean {
  if (!config.enforceCanonicalPlayerIds) {
    return true;
  }
  for (const friendId of friendIds) {
    if (!isCanonicalHumanPlayerId(friendId)) {
      invalidRequest(res, "invalid_friend_id", { friend_id: friendId });
      return false;
    }
  }
  return true;
}

function allowDebugActions(res: Response): boolean {
  if (config.allowDebugActions) {
    return true;
  }
  res.status(403).json({ ok: false, err: "debug_actions_disabled" });
  return false;
}

function openedTierIdsForPopulation(totalPlayers: number): string[] {
  const tiers = orderedTierIds();
  if (tiers.length === 0) {
    return [];
  }
  const unlockSize = Math.max(1, config.rank.playersPerTierToUnlock);
  const openCount = Math.min(tiers.length, Math.floor(Math.max(1, totalPlayers) / unlockSize) + 1);
  return tiers.slice(0, openCount);
}

function summarizeTierCounts(
  totalPlayers: number,
  rows: Array<{ tier_id: string; color_id: string; player_count: number }>
): Record<string, unknown> {
  const tiers = orderedTierIds();
  const colors = normalizedColorQuintiles();
  const openTierSet = new Set(openedTierIdsForPopulation(totalPlayers));
  const byTier = new Map<string, { total_players: number; colors: Record<string, number> }>();
  for (const tierId of tiers) {
    const colorCounts: Record<string, number> = {};
    for (const colorId of colors) {
      colorCounts[colorId] = 0;
    }
    byTier.set(tierId, { total_players: 0, colors: colorCounts });
  }
  const colorTotals: Record<string, number> = {};
  for (const colorId of colors) {
    colorTotals[colorId] = 0;
  }
  for (const row of rows) {
    const tierId = row.tier_id.trim().toUpperCase();
    const colorId = row.color_id.trim().toUpperCase();
    const bucket = byTier.get(tierId);
    if (!bucket || !(colorId in bucket.colors)) {
      continue;
    }
    bucket.colors[colorId] += row.player_count;
    bucket.total_players += row.player_count;
    colorTotals[colorId] += row.player_count;
  }
  return {
    total_players: totalPlayers,
    open_tiers: Array.from(openTierSet),
    colors: colorTotals,
    tiers: tiers.map((tierId) => {
      const bucket = byTier.get(tierId) ?? { total_players: 0, colors: {} };
      return {
        tier_id: tierId,
        open: openTierSet.has(tierId),
        total_players: bucket.total_players,
        colors: bucket.colors
      };
    })
  };
}

function describeRankDelta(before: PlayerRecord | undefined, after: PlayerRecord | undefined): Record<string, unknown> {
  if (!after) {
    return {};
  }
  const delta: Record<string, unknown> = {};
  if (!before || before.wax_score !== after.wax_score) {
    delta.wax_score = { before: before?.wax_score ?? null, after: after.wax_score };
  }
  if (!before || before.rank_position !== after.rank_position) {
    delta.rank_position = { before: before?.rank_position ?? null, after: after.rank_position };
  }
  if (!before || before.tier_id !== after.tier_id) {
    delta.tier_id = { before: before?.tier_id ?? "", after: after.tier_id };
  }
  if (!before || before.color_id !== after.color_id) {
    delta.color_id = { before: before?.color_id ?? "", after: after.color_id };
  }
  if (!before || before.percentile !== after.percentile) {
    delta.percentile = { before: before?.percentile ?? null, after: after.percentile };
  }
  return delta;
}

function recordRankChangeAudit(
  recordAuditEvent: (event: {
    event_type: string;
    player_id?: string;
    related_player_id?: string;
    payload?: Record<string, unknown>;
  }) => void,
  eventType: string,
  before: PlayerRecord | undefined,
  after: PlayerRecord | undefined,
  extraPayload: Record<string, unknown> = {},
  relatedPlayerId = ""
): void {
  const changes = describeRankDelta(before, after);
  if (!after || Object.keys(changes).length === 0) {
    return;
  }
  recordAuditEvent({
    event_type: eventType,
    player_id: after.player_id,
    related_player_id: relatedPlayerId,
    payload: {
      ...extraPayload,
      changes
    }
  });
}

function unauthorized(res: Response): void {
  res.status(401).json({ ok: false, err: "unauthorized" });
}

function requireBearerAuth(req: Request, res: Response, next: NextFunction): void {
  if (!config.apiToken) {
    next();
    return;
  }
  const rawAuth = req.header("authorization") ?? "";
  const prefix = "Bearer ";
  if (!rawAuth.startsWith(prefix)) {
    unauthorized(res);
    return;
  }
  const token = rawAuth.slice(prefix.length).trim();
  if (!token || token !== config.apiToken) {
    unauthorized(res);
    return;
  }
  next();
}

function asyncHandler(fn: (req: Request, res: Response) => Promise<void>) {
  return (req: Request, res: Response, next: NextFunction) => {
    void fn(req, res).catch(next);
  };
}

function ensureLocalPlayer(state: RankState, requestedId: string): { created: boolean } {
  const cleanId = requestedId.trim();
  if (!cleanId) {
    return { created: false };
  }
  let created = false;
  if (!state.players_by_id[cleanId]) {
    state.players_by_id[cleanId] = newPlayerRecord(cleanId, cleanId, config.rank.defaultRegion, nowUnix(), []);
    created = true;
  }
  state.local_player_id = cleanId;
  return { created };
}

function normalizeQueueEntries(raw: unknown): MatchQueueEntry[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const out: MatchQueueEntry[] = [];
  for (const row of raw) {
    if (!isRecord(row)) {
      continue;
    }
    const playerId = toStringValue(row.player_id);
    if (!playerId) {
      continue;
    }
    out.push({
      player_id: playerId,
      wait_seconds: Math.max(0, toNumberValue(row.wait_seconds, 0))
    });
  }
  return out;
}

async function main(): Promise<void> {
  const store = new RankStore(pool, config.legacyStatePath);
  await store.init();

  const app = express();
  app.use(express.json({ limit: "1mb" }));

  app.get(
    "/health",
    asyncHandler(async (_req, res) => {
      const dbOk = await store.healthCheck();
      res.status(dbOk ? 200 : 503).json({ ok: dbOk, db_ok: dbOk, service: "swarmfront-rank-service" });
    })
  );

  app.get("/", (_req, res) => {
    res.json({ ok: true, service: "swarmfront-rank-service", route: "/v1/rank/<action>" });
  });

  app.get(
    "/health/details",
    requireBearerAuth,
    asyncHandler(async (_req, res) => {
      const dbOk = await store.healthCheck();
      const stats = dbOk ? await store.readServiceStats() : {
        player_count: 0,
        processed_event_count: 0,
        audit_event_count: 0
      };
      res.status(dbOk ? 200 : 503).json({
        ok: dbOk,
        db_ok: dbOk,
        service: "swarmfront-rank-service",
        uptime_sec: Math.max(0, nowUnix() - PROCESS_START_UNIX),
        ...stats,
        config: {
          players_per_tier_to_unlock: config.rank.playersPerTierToUnlock,
          enforce_canonical_player_ids: config.enforceCanonicalPlayerIds,
          debug_actions_enabled: config.allowDebugActions
        }
      });
    })
  );

  app.get(
    "/v1/admin/players/:playerId",
    requireBearerAuth,
    asyncHandler(async (req, res) => {
      const playerId = toStringValue(req.params.playerId);
      if (!playerId) {
        invalidRequest(res, "missing_player_id");
        return;
      }
      const result = await store.read((state) => {
        const player = state.players_by_id[playerId];
        if (!player) {
          return { ok: false, err: "player_not_found" };
        }
        return {
          ok: true,
          player: playerSnapshot(player),
          board: buildLeaderboardView(state, playerId, "GLOBAL", 5)
        };
      });
      res.status(result.ok ? 200 : 404).json(result);
    })
  );

  app.get(
    "/v1/admin/tier-counts",
    requireBearerAuth,
    asyncHandler(async (_req, res) => {
      const [stats, counts] = await Promise.all([store.readServiceStats(), store.readTierColorCounts()]);
      res.json({
        ok: true,
        summary: summarizeTierCounts(stats.player_count, counts)
      });
    })
  );

  app.get(
    "/v1/admin/audit",
    requireBearerAuth,
    asyncHandler(async (req, res) => {
      const limit = Math.max(1, Math.min(200, Math.trunc(toNumberValue(req.query.limit, 50))));
      const playerId = toStringValue(req.query.player_id);
      const eventType = toStringValue(req.query.event_type);
      const rows = await store.readAuditTrail(limit, playerId, eventType);
      res.json({ ok: true, rows });
    })
  );

  app.post(
    "/v1/admin/recompute",
    requireBearerAuth,
    asyncHandler(async (_req, res) => {
      const result = await store.write((state, context) => {
        recomputeRankings(state);
        context.recordAuditEvent({
          event_type: "admin_recompute",
          payload: {
            player_count: Object.keys(state.players_by_id).length
          }
        });
        return {
          ok: true,
          player_count: Object.keys(state.players_by_id).length,
          snapshot: stateSnapshot(state)
        };
      });
      res.json(result);
    })
  );

  app.post(
    "/v1/rank/:action",
    requireBearerAuth,
    asyncHandler(async (req, res) => {
      const action = toStringValue(req.params.action).replace(/^\/+/, "");
      const payload = isRecord(req.body) ? req.body : {};

      switch (action) {
        case "get_snapshot": {
          const requestedLocalId = toStringValue(payload.local_player_id);
          if (requestedLocalId) {
            if (!requireCanonicalHumanPlayerId(res, requestedLocalId, "local_player_id")) {
              return;
            }
            const result = await store.write((state, context) => {
              const ensured = ensureLocalPlayer(state, requestedLocalId);
              if (ensured.created) {
                recomputeRankings(state);
                context.recordAuditEvent({
                  event_type: "player_registered",
                  player_id: requestedLocalId,
                  payload: {
                    source: "get_snapshot",
                    auto_created: true
                  }
                });
              }
              return {
                ok: true,
                snapshot: stateSnapshot(state)
              };
            });
            res.json(result);
            return;
          }
          const result = await store.read((state) => ({ ok: true, snapshot: stateSnapshot(state) }));
          res.json(result);
          return;
        }

        case "register_player": {
          const playerId = toStringValue(payload.player_id);
          if (!playerId) {
            res.status(400).json({ ok: false, err: "missing_player_id" });
            return;
          }
          if (!requireCanonicalHumanPlayerId(res, playerId, "player_id")) {
            return;
          }
          const displayName = toStringValue(payload.display_name);
          const region = toStringValue(payload.region);
          const friends = sanitizeFriends(payload.friends);
          if (!requireFriendIds(res, friends)) {
            return;
          }

          const result = await store.write((state, context) => {
            const existing = state.players_by_id[playerId];
            if (!existing) {
              state.players_by_id[playerId] = newPlayerRecord(playerId, displayName || playerId, region, nowUnix(), friends);
              context.recordAuditEvent({
                event_type: "player_registered",
                player_id: playerId,
                payload: {
                  display_name: displayName || playerId,
                  region: region || config.rank.defaultRegion
                }
              });
            } else {
              const merged = {
                ...existing,
                display_name: displayName || existing.display_name,
                region: region || existing.region,
                friends
              };
              state.players_by_id[playerId] = normalizePlayerRecord(playerId, merged);
              context.recordAuditEvent({
                event_type: "player_profile_updated",
                player_id: playerId,
                payload: {
                  display_name: displayName || existing.display_name,
                  region: region || existing.region,
                  friend_count: friends.length
                }
              });
            }
            if (!state.local_player_id) {
              state.local_player_id = playerId;
            }
            recomputeRankings(state);
            return {
              ok: true,
              player: playerSnapshot(state.players_by_id[playerId]),
              snapshot: stateSnapshot(state)
            };
          });
          res.json(result);
          return;
        }

        case "set_player_friends": {
          const playerId = toStringValue(payload.player_id);
          if (!playerId) {
            res.status(400).json({ ok: false, err: "missing_player_id" });
            return;
          }
          if (!requireCanonicalHumanPlayerId(res, playerId, "player_id")) {
            return;
          }
          const friends = sanitizeFriends(payload.friends);
          if (!requireFriendIds(res, friends)) {
            return;
          }
          const result = await store.write((state, context) => {
            const existing = state.players_by_id[playerId];
            if (!existing) {
              return { ok: false, err: "player_not_found" };
            }
            existing.friends = friends;
            state.players_by_id[playerId] = normalizePlayerRecord(playerId, existing);
            context.recordAuditEvent({
              event_type: "player_friends_updated",
              player_id: playerId,
              payload: {
                friend_count: friends.length
              }
            });
            return { ok: true, player: playerSnapshot(state.players_by_id[playerId]), snapshot: stateSnapshot(state) };
          });
          res.json(result);
          return;
        }

        case "set_player_region": {
          const playerId = toStringValue(payload.player_id);
          if (!playerId) {
            res.status(400).json({ ok: false, err: "missing_player_id" });
            return;
          }
          if (!requireCanonicalHumanPlayerId(res, playerId, "player_id")) {
            return;
          }
          const region = toStringValue(payload.region);
          const result = await store.write((state, context) => {
            const existing = state.players_by_id[playerId];
            if (!existing) {
              return { ok: false, err: "player_not_found" };
            }
            existing.region = region || existing.region;
            state.players_by_id[playerId] = normalizePlayerRecord(playerId, existing);
            context.recordAuditEvent({
              event_type: "player_region_updated",
              player_id: playerId,
              payload: {
                region: state.players_by_id[playerId].region
              }
            });
            return { ok: true, player: playerSnapshot(state.players_by_id[playerId]), snapshot: stateSnapshot(state) };
          });
          res.json(result);
          return;
        }

        case "record_match_result": {
          const playerId = toStringValue(payload.player_id);
          const opponentId = toStringValue(payload.opponent_id);
          if (!playerId || !opponentId) {
            res.status(400).json({ ok: false, err: "missing_player_ids" });
            return;
          }
          if (!requireCanonicalHumanPlayerId(res, playerId, "player_id")) {
            return;
          }
          if (!requireRankParticipantId(res, opponentId, "opponent_id")) {
            return;
          }
          if (playerId === opponentId) {
            res.status(400).json({ ok: false, err: "same_player_ids" });
            return;
          }

          const didPlayerWin = toBooleanValue(payload.did_player_win);
          const modeName = toStringValue(payload.mode_name).toUpperCase() || "STANDARD";
          const metadata = isRecord(payload.metadata) ? payload.metadata : {};
          const eventId = toStringValue(metadata.event_id);

          const result = await store.write((state, context) => {
            if (eventId) {
              const dedupeKey = `${playerId}:${eventId}`;
              if (state.processed_events[dedupeKey]) {
                return {
                  ok: true,
                  duplicate: true,
                  player: playerSnapshot(state.players_by_id[playerId]),
                  opponent: playerSnapshot(state.players_by_id[opponentId])
                };
              }
            }

            ensurePlayerExists(state, playerId, playerId);
            ensurePlayerExists(state, opponentId, opponentId);
            const playerBefore = state.players_by_id[playerId] ? { ...state.players_by_id[playerId] } : undefined;
            const opponentBefore = state.players_by_id[opponentId] ? { ...state.players_by_id[opponentId] } : undefined;

            const unixNow = nowUnix();
            applyDecayAll(state, unixNow);

            const player = state.players_by_id[playerId];
            const opponent = state.players_by_id[opponentId];
            const playerWaxBefore = player.wax_score;
            const opponentWaxBefore = opponent.wax_score;

            const playerGain = computeGain(playerWaxBefore, opponentWaxBefore, modeName);
            const opponentGain = computeGain(opponentWaxBefore, playerWaxBefore, modeName);
            const playerLoss = computeLoss(playerWaxBefore, opponentWaxBefore, modeName);
            const opponentLoss = computeLoss(opponentWaxBefore, playerWaxBefore, modeName);

            if (didPlayerWin) {
              player.wax_score = playerWaxBefore + playerGain;
              opponent.wax_score = Math.max(config.rank.waxFloor, opponentWaxBefore - opponentLoss);
            } else {
              player.wax_score = Math.max(config.rank.waxFloor, playerWaxBefore - playerLoss);
              opponent.wax_score = opponentWaxBefore + opponentGain;
            }

            const decayDay = Math.floor(unixNow / 86_400);
            player.last_active_unix = unixNow;
            opponent.last_active_unix = unixNow;
            player.last_decay_day = decayDay;
            opponent.last_decay_day = decayDay;

            state.players_by_id[playerId] = normalizePlayerRecord(playerId, player, unixNow);
            state.players_by_id[opponentId] = normalizePlayerRecord(opponentId, opponent, unixNow);

            recomputeRankings(state);

            if (eventId) {
              const dedupeKey = `${playerId}:${eventId}`;
              state.processed_events[dedupeKey] = unixNow;
              pruneProcessedEvents(state);
            }
            context.recordAuditEvent({
              event_type: "match_result_recorded",
              player_id: playerId,
              related_player_id: opponentId,
              payload: {
                did_player_win: didPlayerWin,
                mode_name: modeName,
                event_id: eventId,
                player_wax_before: playerWaxBefore,
                player_wax_after: state.players_by_id[playerId].wax_score,
                opponent_wax_before: opponentWaxBefore,
                opponent_wax_after: state.players_by_id[opponentId].wax_score
              }
            });
            recordRankChangeAudit(context.recordAuditEvent, "rank_state_changed", playerBefore, state.players_by_id[playerId], {
              reason: "match_result",
              mode_name: modeName,
              did_player_win: didPlayerWin,
              event_id: eventId
            }, opponentId);
            recordRankChangeAudit(context.recordAuditEvent, "rank_state_changed", opponentBefore, state.players_by_id[opponentId], {
              reason: "match_result",
              mode_name: modeName,
              did_player_win: !didPlayerWin,
              event_id: eventId
            }, playerId);

            return {
              ok: true,
              player: playerSnapshot(state.players_by_id[playerId]),
              opponent: playerSnapshot(state.players_by_id[opponentId]),
              snapshot: stateSnapshot(state)
            };
          });

          res.json(result);
          return;
        }

        case "apply_decay_tick": {
          const result = await store.write((state, context) => {
            const applied = applyDecayAll(state, nowUnix());
            if (applied > 0) {
              recomputeRankings(state);
              context.recordAuditEvent({
                event_type: "decay_tick_applied",
                payload: {
                  players_decayed: applied
                }
              });
            }
            return { ok: true, players_decayed: applied, snapshot: stateSnapshot(state) };
          });
          res.json(result);
          return;
        }

        case "get_player_snapshot": {
          const playerId = toStringValue(payload.player_id);
          if (!playerId) {
            res.status(400).json({ ok: false, err: "missing_player_id" });
            return;
          }
          const result = await store.read((state) => {
            const player = state.players_by_id[playerId];
            if (!player) {
              return { ok: false, err: "player_not_found" };
            }
            return { ok: true, player: playerSnapshot(player) };
          });
          res.json(result);
          return;
        }

        case "get_local_rank_view": {
          const requesterId = toStringValue(payload.requester_id);
          if (requesterId && !requireCanonicalHumanPlayerId(res, requesterId, "requester_id")) {
            return;
          }
          const filterName = toStringValue(payload.filter_name) || "GLOBAL";
          const limit = Math.max(1, Math.trunc(toNumberValue(payload.limit, 25)));

          const result = await store.read((state) => {
            const resolvedRequesterId = requesterId || state.local_player_id;
            const board = buildLeaderboardView(state, resolvedRequesterId, filterName, limit);
            return {
              ok: true,
              board: {
                ...board,
                local_player_id: resolvedRequesterId,
                player: playerSnapshot(state.players_by_id[resolvedRequesterId])
              }
            };
          });
          res.json(result);
          return;
        }

        case "get_leaderboard_snapshot": {
          const requesterId = toStringValue(payload.requester_id);
          if (requesterId && !requireCanonicalHumanPlayerId(res, requesterId, "requester_id")) {
            return;
          }
          const filterName = toStringValue(payload.filter_name) || "GLOBAL";
          const limit = Math.max(1, Math.trunc(toNumberValue(payload.limit, 25)));

          const result = await store.read((state) => {
            const resolvedRequesterId = requesterId || state.local_player_id;
            const board = buildLeaderboardView(state, resolvedRequesterId, filterName, limit);
            return { ok: true, board };
          });
          res.json(result);
          return;
        }

        case "find_match_candidates": {
          const requesterId = toStringValue(payload.requester_id);
          if (!requesterId) {
            res.status(400).json({ ok: false, err: "missing_requester_id" });
            return;
          }
          if (!requireCanonicalHumanPlayerId(res, requesterId, "requester_id")) {
            return;
          }
          const queueEntries = normalizeQueueEntries(payload.queue_entries);
          const result = await store.read((state) => ({
            ok: true,
            rows: findMatchCandidates(
              state,
              requesterId,
              config.enforceCanonicalPlayerIds
                ? queueEntries.filter((entry) => isRankParticipantId(entry.player_id))
                : queueEntries
            )
          }));
          res.json(result);
          return;
        }

        case "debug_set_player_wax": {
          if (!allowDebugActions(res)) {
            return;
          }
          const playerId = toStringValue(payload.player_id);
          if (!playerId) {
            res.status(400).json({ ok: false, err: "missing_player_id" });
            return;
          }
          if (!requireRankParticipantId(res, playerId, "player_id")) {
            return;
          }
          const waxScore = toNumberValue(payload.wax_score, config.rank.waxFloor);
          const result = await store.write((state, context) => {
            ensurePlayerExists(state, playerId, playerId);
            const before = state.players_by_id[playerId] ? { ...state.players_by_id[playerId] } : undefined;
            const existing = state.players_by_id[playerId];
            existing.wax_score = Math.max(config.rank.waxFloor, waxScore);
            state.players_by_id[playerId] = normalizePlayerRecord(playerId, existing);
            recomputeRankings(state);
            recordRankChangeAudit(context.recordAuditEvent, "rank_state_changed", before, state.players_by_id[playerId], {
              reason: "debug_set_player_wax"
            });
            return { ok: true, player: playerSnapshot(state.players_by_id[playerId]), snapshot: stateSnapshot(state) };
          });
          res.json(result);
          return;
        }

        case "debug_set_last_active": {
          if (!allowDebugActions(res)) {
            return;
          }
          const playerId = toStringValue(payload.player_id);
          if (!playerId) {
            res.status(400).json({ ok: false, err: "missing_player_id" });
            return;
          }
          if (!requireRankParticipantId(res, playerId, "player_id")) {
            return;
          }
          const lastActiveUnix = Math.max(0, Math.trunc(toNumberValue(payload.last_active_unix, nowUnix())));
          const result = await store.write((state, context) => {
            ensurePlayerExists(state, playerId, playerId);
            const existing = state.players_by_id[playerId];
            existing.last_active_unix = lastActiveUnix;
            existing.last_decay_day = -1;
            state.players_by_id[playerId] = normalizePlayerRecord(playerId, existing);
            context.recordAuditEvent({
              event_type: "player_last_active_updated",
              player_id: playerId,
              payload: {
                last_active_unix: lastActiveUnix,
                reason: "debug_set_last_active"
              }
            });
            return { ok: true, player: playerSnapshot(state.players_by_id[playerId]), snapshot: stateSnapshot(state) };
          });
          res.json(result);
          return;
        }

        case "get_tier_metadata": {
          res.json({ ok: true, tiers: tierNames() });
          return;
        }

        default:
          res.status(404).json({ ok: false, err: "unknown_action" });
      }
    })
  );

  app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
    // eslint-disable-next-line no-console
    console.error(error);
    res.status(500).json({ ok: false, err: "internal_server_error" });
  });

  app.listen(config.port, config.bindHost, () => {
    // eslint-disable-next-line no-console
    console.log(`rank service running on ${config.bindHost}:${config.port}`);
    // eslint-disable-next-line no-console
    console.log(`database: ${redactDatabaseUrl(config.databaseUrl)}`);
    // eslint-disable-next-line no-console
    console.log(`legacy import path: ${config.legacyStatePath}`);
  });
}

void main();
