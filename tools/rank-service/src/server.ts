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
  normalizePlayerRecord,
  nowUnix,
  playerSnapshot,
  pruneProcessedEvents,
  recomputeRankings,
  sanitizeFriends,
  stateSnapshot,
  tierNames
} from "./logic.js";
import { RankStore } from "./store.js";
import type { MatchQueueEntry, RankState } from "./types.js";

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
            const result = await store.write((state) => {
              const ensured = ensureLocalPlayer(state, requestedLocalId);
              if (ensured.created) {
                recomputeRankings(state);
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
          const displayName = toStringValue(payload.display_name);
          const region = toStringValue(payload.region);
          const friends = sanitizeFriends(payload.friends);

          const result = await store.write((state) => {
            const existing = state.players_by_id[playerId];
            if (!existing) {
              state.players_by_id[playerId] = newPlayerRecord(playerId, displayName || playerId, region, nowUnix(), friends);
            } else {
              const merged = {
                ...existing,
                display_name: displayName || existing.display_name,
                region: region || existing.region,
                friends
              };
              state.players_by_id[playerId] = normalizePlayerRecord(playerId, merged);
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
          const friends = sanitizeFriends(payload.friends);
          const result = await store.write((state) => {
            const existing = state.players_by_id[playerId];
            if (!existing) {
              return { ok: false, err: "player_not_found" };
            }
            existing.friends = friends;
            state.players_by_id[playerId] = normalizePlayerRecord(playerId, existing);
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
          const region = toStringValue(payload.region);
          const result = await store.write((state) => {
            const existing = state.players_by_id[playerId];
            if (!existing) {
              return { ok: false, err: "player_not_found" };
            }
            existing.region = region || existing.region;
            state.players_by_id[playerId] = normalizePlayerRecord(playerId, existing);
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
          if (playerId === opponentId) {
            res.status(400).json({ ok: false, err: "same_player_ids" });
            return;
          }

          const didPlayerWin = toBooleanValue(payload.did_player_win);
          const modeName = toStringValue(payload.mode_name).toUpperCase() || "STANDARD";
          const metadata = isRecord(payload.metadata) ? payload.metadata : {};
          const eventId = toStringValue(metadata.event_id);

          const result = await store.write((state) => {
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
          const result = await store.write((state) => {
            const applied = applyDecayAll(state, nowUnix());
            if (applied > 0) {
              recomputeRankings(state);
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
          const queueEntries = normalizeQueueEntries(payload.queue_entries);
          const result = await store.read((state) => ({
            ok: true,
            rows: findMatchCandidates(state, requesterId, queueEntries)
          }));
          res.json(result);
          return;
        }

        case "debug_set_player_wax": {
          const playerId = toStringValue(payload.player_id);
          if (!playerId) {
            res.status(400).json({ ok: false, err: "missing_player_id" });
            return;
          }
          const waxScore = toNumberValue(payload.wax_score, config.rank.waxFloor);
          const result = await store.write((state) => {
            ensurePlayerExists(state, playerId, playerId);
            const existing = state.players_by_id[playerId];
            existing.wax_score = Math.max(config.rank.waxFloor, waxScore);
            state.players_by_id[playerId] = normalizePlayerRecord(playerId, existing);
            recomputeRankings(state);
            return { ok: true, player: playerSnapshot(state.players_by_id[playerId]), snapshot: stateSnapshot(state) };
          });
          res.json(result);
          return;
        }

        case "debug_set_last_active": {
          const playerId = toStringValue(payload.player_id);
          if (!playerId) {
            res.status(400).json({ ok: false, err: "missing_player_id" });
            return;
          }
          const lastActiveUnix = Math.max(0, Math.trunc(toNumberValue(payload.last_active_unix, nowUnix())));
          const result = await store.write((state) => {
            ensurePlayerExists(state, playerId, playerId);
            const existing = state.players_by_id[playerId];
            existing.last_active_unix = lastActiveUnix;
            existing.last_decay_day = -1;
            state.players_by_id[playerId] = normalizePlayerRecord(playerId, existing);
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
