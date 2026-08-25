import express, { type NextFunction, type Request, type Response } from "express";
import { config } from "./config.js";
import {
  economyMutationsEnabled,
  isRankEconomyMutationAction,
  isRankSupersededAction,
  rankTokenAuthorized
} from "./economyGuard.js";
import { pool } from "./db/pool.js";
import {
  applyDecayAll,
  buildLeaderboardView,
  computeContestPlacementWax,
  computeGain,
  computeLoss,
  ensurePlayerExists,
  generateUuidV7,
  isCallSign,
  isUuidV7,
  findMatchCandidates,
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
import {
  PlatformEconomyError,
  PlatformEconomyRepository,
  type ProducerEnvelope
} from "./platformEconomy.js";
import type { MatchQueueEntry, PlayerRecord, RankState } from "./types.js";
import {
  bearerTokenFromHeader,
  playerTokenConfigured,
  playerTokenPublicJwk,
  PlayerTokenError,
  verifyPlayerAccessToken
} from "./identity/playerToken.js";
import { IdentitySessionError, IdentitySessionStore } from "./identity/sessionStore.js";
import { bearerToken, ServiceTrustError, verifyServiceJwt } from "./serviceTrust.js";
import { parseSignedVerifierReceipt, VerifiedReceiptError, verifyStandard1v1Receipt } from "./verifiedReceipt.js";

const BOT_PLAYER_ID = /^bot_[0-9]{6}$/;
const PROCESS_START_UNIX = nowUnix();
const SERVICE_BUILD = process.env.RENDER_GIT_COMMIT
  ?? process.env.SOURCE_VERSION
  ?? process.env.npm_package_version
  ?? "dev";

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

function matchRewardBlockReason(metadata: Record<string, unknown>): string {
  const eventId = toStringValue(metadata.event_id);
  if (!eventId) {
    return "event_id_missing";
  }
  for (const flag of [
    "tutorial", "practice", "custom_match", "private_match", "no_contest", "refunded",
    "immediate_surrender", "early_quit", "afk", "insufficient_input",
    "insufficient_participation", "desync", "invalid_result"
  ]) {
    if (toBooleanValue(metadata[flag])) {
      return flag;
    }
  }
  if (metadata.completed != null && !toBooleanValue(metadata.completed)) {
    return "match_not_completed";
  }
  if (metadata.minimum_quality_met != null && !toBooleanValue(metadata.minimum_quality_met)) {
    return "minimum_quality_not_met";
  }
  const durationSec = toNumberValue(
    metadata.duration_sec,
    toNumberValue(metadata.match_elapsed_ms, toNumberValue(metadata.elapsed_ms, 0)) / 1000
  );
  if (durationSec <= 0) {
    return "match_duration_missing";
  }
  if (durationSec < 30) {
    return "match_too_short";
  }
  return "";
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
  return isUuidV7(value);
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
  invalidRequest(res, "invalid_player_id", { field, expected: "UUIDv7" });
  return false;
}

function requireRankParticipantId(res: Response, playerId: string, field: string): boolean {
  if (!config.enforceCanonicalPlayerIds || isRankParticipantId(playerId)) {
    return true;
  }
  invalidRequest(res, "invalid_player_id", { field, expected: "UUIDv7 or bot_<6 digits>" });
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

function validRequestId(value: string): boolean {
  return /^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/.test(value);
}

function identityFailure(res: Response, error: unknown): void {
  if (error instanceof IdentitySessionError) {
    res.status(error.status).json({ ok: false, err: error.code });
    return;
  }
  if (error instanceof PlayerTokenError) {
    res.status(error.code === "token_scope_missing" ? 403 : 401).json({ ok: false, err: error.code });
    return;
  }
  throw error;
}

function platformFailure(res: Response, error: unknown): void {
  if (error instanceof PlatformEconomyError) {
    res.status(error.status).json({ ok: false, err: error.code });
    return;
  }
  if (error instanceof ServiceTrustError) {
    res.status(error.status).json({ ok: false, err: error.code });
    return;
  }
  if (error instanceof PlayerTokenError) {
    identityFailure(res, error);
    return;
  }
  throw error;
}

function producerEnvelope(body: Record<string, unknown>, producerService: string, eventType: string): ProducerEnvelope {
  const payload = isRecord(body.payload) ? body.payload : {};
  return {
    producerService,
    producerEventId: toStringValue(body.producer_event_id),
    eventType,
    epochId: toStringValue(body.economy_epoch),
    sourceAuthority: toStringValue(body.source_authority) || producerService,
    occurredAt: toStringValue(body.occurred_at) || new Date().toISOString(),
    schemaVersion: Math.max(1, Math.trunc(toNumberValue(body.schema_version, 1))),
    payload
  };
}

function requireBearerAuth(req: Request, res: Response, next: NextFunction): void {
  if (!config.apiToken) {
    res.status(503).json({ ok: false, err: "rank_auth_not_configured", code: "rank_auth_not_configured" });
    return;
  }
  const rawAuth = req.header("authorization") ?? "";
  const prefix = "Bearer ";
  if (!rawAuth.startsWith(prefix)) {
    unauthorized(res);
    return;
  }
  const token = rawAuth.slice(prefix.length).trim();
  if (!rankTokenAuthorized(config.apiToken, token)) {
    unauthorized(res);
    return;
  }
  next();
}

function requireRankActionAuth(req: Request, res: Response, next: NextFunction): void {
  const action = toStringValue(req.params.action).replace(/^\/+/, "");
  if (isRankSupersededAction(action)) {
    res.status(410).json({
      ok: false,
      err: action === "register_player"
        ? "player_identity_authority_required"
        : "platform_economy_authority_required",
      code: "legacy_rank_action_superseded",
      action
    });
    return;
  }
  requireBearerAuth(req, res, next);
}

function asyncHandler(fn: (req: Request, res: Response) => Promise<void>) {
  return (req: Request, res: Response, next: NextFunction) => {
    void fn(req, res).catch(next);
  };
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
  const platformEconomy = new PlatformEconomyRepository(pool);
  const identitySessions = new IdentitySessionStore(pool, config.identity, config.identity.challengeTtlSec);
  const identityConfigured = playerTokenConfigured(config.identity);

  const app = express();
  app.use(express.json({ limit: "1mb" }));

  app.get(
    "/health",
    asyncHandler(async (_req, res) => {
      const dbOk = await store.healthCheck();
      const [platformEpoch, platformCapabilities] = dbOk
        ? await Promise.all([platformEconomy.getCurrentEpoch(), platformEconomy.capabilitySnapshot()])
        : [null, {}];
      res.status(dbOk ? 200 : 503).json({
        ok: dbOk,
        service: "swarmfront-rank-service",
        build: SERVICE_BUILD,
        platform_economy_authority: true,
        economy_mutations_enabled: economyMutationsEnabled(),
        verified_match_mutations_enabled: config.verifiedMatchMutationsEnabled,
        public_leaderboards_enabled: config.publicLeaderboardsEnabled,
        service_auth_configured: Boolean(config.serviceAuth.publicKeyPem),
        verifier_receipt_auth_configured: Boolean(config.verifier.publicKeyPem),
        admin_auth_required: Boolean(config.apiToken),
        match_authority_auth_required: Boolean(config.apiToken),
        player_identity_sessions_configured: identityConfigured,
        player_token_issuer: config.identity.issuer,
        player_token_audience: config.identity.audience,
        platform_economy_epoch: platformEpoch,
        platform_economy_capabilities: platformCapabilities,
        storage: { kind: "postgres", path: redactDatabaseUrl(config.databaseUrl) }
      });
    })
  );

  app.get("/", (_req, res) => {
    res.json({ ok: true, service: "swarmfront-rank-service", route: "/v1/rank/<action>" });
  });

  app.get(
    "/v1/public/leaderboard/global",
    asyncHandler(async (req, res) => {
      if (!config.publicLeaderboardsEnabled) {
        res.status(503).json({ ok: false, err: "public_leaderboards_disabled" });
        return;
      }
      const limit = Math.max(1, Math.min(100, Math.trunc(toNumberValue(req.query.limit, 25))));
      const generatedAt = new Date().toISOString();
      const board = await store.read((state) => buildLeaderboardView(state, "", "GLOBAL", limit));
      res.json({
        ok: true,
        board: { ...board, generated_at: generatedAt, cache_age_seconds: 0, stale: false, source: "rank_primary" }
      });
    })
  );

  app.post(
    "/v1/service/settle-standard-1v1",
    asyncHandler(async (req, res) => {
      if (!config.verifiedMatchMutationsEnabled) {
        res.status(503).json({ ok: false, err: "rank_mutations_disabled" });
        return;
      }
      try {
        const claims = verifyServiceJwt(bearerToken(req.header("authorization")), config.serviceAuth, "rank:settle");
        if (toStringValue(isRecord(req.body) ? req.body.mode_id : "") !== "STANDARD_1V1") {
          throw new VerifiedReceiptError("rank_mode_invalid");
        }
        const receipt = parseSignedVerifierReceipt(isRecord(req.body) ? req.body.signed_result : null);
        const payload = verifyStandard1v1Receipt(receipt, config.verifier);
        if (toStringValue(isRecord(req.body) ? req.body.rank_event_id : "") !== String(payload.result_id)) {
          throw new VerifiedReceiptError("rank_event_binding_invalid");
        }
        const placements = payload.placements as Record<string, unknown>[];
        const winnerId = String((placements[0]?.player_ids as unknown[] | undefined)?.[0] ?? "");
        const loserId = String((placements[1]?.player_ids as unknown[] | undefined)?.[0] ?? "");
        const currentEpoch = await platformEconomy.getCurrentEpoch();
        if (!currentEpoch) throw new PlatformEconomyError("active_epoch_missing", 503);
        const result = await platformEconomy.settleStandardWax({
          envelope: {
            producerService: String(claims.sub),
            producerEventId: String(payload.result_id),
            eventType: "STANDARD_WAX_SETTLEMENT_V1",
            epochId: String(currentEpoch.epoch_id),
            sourceAuthority: String(payload.authority_method),
            occurredAt: String(payload.verified_at),
            schemaVersion: 1,
            payload
          },
          winnerPlayerId: winnerId,
          loserPlayerId: loserId,
          modeName: "STANDARD",
          noContest: String(payload.terminal_reason) === "NO_CONTEST"
        });
        const status = result.ok === false && result.err === "rank_players_missing" ? 409 : 200;
        res.status(status).json(result);
      } catch (error) {
        if (error instanceof PlatformEconomyError) {
          platformFailure(res, error);
          return;
        }
        if (error instanceof ServiceTrustError || error instanceof VerifiedReceiptError) {
          res.status(error.status).json({ ok: false, err: error.code });
          return;
        }
        throw error;
      }
    })
  );

  app.post(
    "/v1/service/economy/honey-activity",
    asyncHandler(async (req, res) => {
      try {
        const claims = verifyServiceJwt(bearerToken(req.header("authorization")), config.serviceAuth, "economy:produce");
        const body = isRecord(req.body) ? req.body : {};
        const result = await platformEconomy.awardHoneyActivity(producerEnvelope(body, String(claims.sub), "HONEY_ACTIVITY_V1"));
        res.json(result);
      } catch (error) { platformFailure(res, error); }
    })
  );

  app.post(
    "/v1/service/economy/nectar-match",
    asyncHandler(async (req, res) => {
      try {
        const claims = verifyServiceJwt(bearerToken(req.header("authorization")), config.serviceAuth, "economy:produce");
        const body = isRecord(req.body) ? req.body : {};
        const result = await platformEconomy.awardNectarMatch(producerEnvelope(body, String(claims.sub), "NECTAR_MATCH_V1"));
        res.json(result);
      } catch (error) { platformFailure(res, error); }
    })
  );

  app.post(
    "/v1/service/economy/crucible/reserve",
    asyncHandler(async (req, res) => {
      try {
        const claims = verifyServiceJwt(bearerToken(req.header("authorization")), config.serviceAuth, "economy:reserve");
        const body = isRecord(req.body) ? req.body : {};
        const envelope = producerEnvelope(body, String(claims.sub), "CRUCIBLE_RESERVE_V1");
        const payload = envelope.payload;
        const result = await platformEconomy.reserveCrucibleParticipant({ envelope,
          matchId: toStringValue(payload.match_id), contractId: toStringValue(payload.contract_id),
          contractHash: toStringValue(payload.contract_hash), playerId: toStringValue(payload.player_id),
          playerAId: toStringValue(payload.player_a_id), playerBId: toStringValue(payload.player_b_id),
          expiresAt: toStringValue(payload.expires_at) });
        res.json(result);
      } catch (error) { platformFailure(res, error); }
    })
  );

  app.post(
    "/v1/service/economy/crucible/settle",
    asyncHandler(async (req, res) => {
      try {
        const claims = verifyServiceJwt(bearerToken(req.header("authorization")), config.serviceAuth, "economy:settle");
        const body = isRecord(req.body) ? req.body : {};
        const envelope = producerEnvelope(body, String(claims.sub), "CRUCIBLE_SETTLE_V1");
        const payload = envelope.payload;
        const result = await platformEconomy.settleCrucible({ envelope,
          matchId: toStringValue(payload.match_id), resultId: toStringValue(payload.result_id),
          winnerPlayerId: toStringValue(payload.winner_player_id) });
        res.json(result);
      } catch (error) { platformFailure(res, error); }
    })
  );

  app.post(
    "/v1/service/economy/crucible/refund",
    asyncHandler(async (req, res) => {
      try {
        const claims = verifyServiceJwt(bearerToken(req.header("authorization")), config.serviceAuth, "economy:settle");
        const body = isRecord(req.body) ? req.body : {};
        const envelope = producerEnvelope(body, String(claims.sub), "CRUCIBLE_REFUND_V1");
        const payload = envelope.payload;
        const result = await platformEconomy.refundCrucible({ envelope,
          matchId: toStringValue(payload.match_id), resultId: toStringValue(payload.result_id),
          reason: toStringValue(payload.reason) });
        res.json(result);
      } catch (error) { platformFailure(res, error); }
    })
  );

  app.get(
    "/v1/platform/economy/me",
    asyncHandler(async (req, res) => {
      try {
        const token = bearerTokenFromHeader(req.header("authorization"));
        if (!token) throw new PlayerTokenError("token_missing");
        const claims = verifyPlayerAccessToken(token, config.identity, { requiredScope: "economy:read" });
        res.json(await platformEconomy.getPlayerBalances(claims.sub));
      } catch (error) { platformFailure(res, error); }
    })
  );

  app.get(
    "/v1/admin/platform/reconcile",
    requireBearerAuth,
    asyncHandler(async (req, res) => {
      try { res.json(await platformEconomy.reconcile(toStringValue(req.query.epoch_id) || undefined)); }
      catch (error) { platformFailure(res, error); }
    })
  );

  app.post(
    "/v1/admin/platform/capability",
    requireBearerAuth,
    asyncHandler(async (req, res) => {
      try {
        const body = isRecord(req.body) ? req.body : {};
        const capability = toStringValue(body.capability).toUpperCase();
        if (!["NECTAR", "HONEY_EARN", "HONEY_SPEND", "WAX_STANDARD", "WAX_CRUCIBLE"].includes(capability)) {
          throw new PlatformEconomyError("unknown_capability");
        }
        res.json({ ok: true, capability: await platformEconomy.setCapability(
          capability as "NECTAR" | "HONEY_EARN" | "HONEY_SPEND" | "WAX_STANDARD" | "WAX_CRUCIBLE",
          toBooleanValue(body.enabled)
        ) });
      } catch (error) { platformFailure(res, error); }
    })
  );

  app.post(
    "/v1/admin/platform/epoch/draft",
    requireBearerAuth,
    asyncHandler(async (req, res) => {
      try {
        const body = isRecord(req.body) ? req.body : {};
        res.status(201).json({ ok: true, epoch: await platformEconomy.createEpochDraft({
          epochId: toStringValue(body.epoch_id), seasonId: toStringValue(body.season_id),
          artifactDigest: toStringValue(body.artifact_digest), openingHoneyCenti: 0,
          openingWaxMillis: 0, openingNectarMilli: 0
        }) });
      } catch (error) { platformFailure(res, error); }
    })
  );

  app.post(
    "/v1/admin/platform/epoch/:epochId/prepare",
    requireBearerAuth,
    asyncHandler(async (req, res) => {
      try {
        const body = isRecord(req.body) ? req.body : {};
        res.json({ ok: true, epoch: await platformEconomy.prepareEpoch(toStringValue(req.params.epochId), body) });
      } catch (error) { platformFailure(res, error); }
    })
  );

  app.post(
    "/v1/admin/platform/epoch/:epochId/reconcile",
    requireBearerAuth,
    asyncHandler(async (req, res) => {
      try { res.json({ ok: true, epoch: await platformEconomy.markEpochReconciled(toStringValue(req.params.epochId)) }); }
      catch (error) { platformFailure(res, error); }
    })
  );

  app.post(
    "/v1/admin/platform/epoch/:epochId/activate",
    requireBearerAuth,
    asyncHandler(async (req, res) => {
      try { res.json({ ok: true, epoch: await platformEconomy.activateEpoch(toStringValue(req.params.epochId)) }); }
      catch (error) { platformFailure(res, error); }
    })
  );

  app.post(
    "/v1/admin/platform/epoch/:epochId/abort",
    requireBearerAuth,
    asyncHandler(async (req, res) => {
      try { res.json({ ok: true, epoch: await platformEconomy.abortEpoch(toStringValue(req.params.epochId)) }); }
      catch (error) { platformFailure(res, error); }
    })
  );

  app.post(
    "/v1/platform/economy/honey/spend",
    asyncHandler(async (req, res) => {
      try {
        const token = bearerTokenFromHeader(req.header("authorization"));
        if (!token) throw new PlayerTokenError("token_missing");
        const claims = verifyPlayerAccessToken(token, config.identity, { requiredScope: "economy:spend" });
        const body = isRecord(req.body) ? req.body : {};
        const currentEpoch = await platformEconomy.getCurrentEpoch();
        if (!currentEpoch) throw new PlatformEconomyError("active_epoch_missing", 503);
        const requestId = toStringValue(body.request_id);
        if (!validRequestId(requestId)) throw new PlatformEconomyError("invalid_request_id");
        const result = await platformEconomy.spendHoney({
          envelope: {
            producerService: "player-intent",
            producerEventId: `${claims.sub}:${requestId}`,
            eventType: "HONEY_SPEND_V1",
            epochId: String(currentEpoch.epoch_id),
            sourceAuthority: "entap-player-session",
            occurredAt: new Date().toISOString(),
            schemaVersion: 1,
            payload: { player_id: claims.sub, catalog_action_id: toStringValue(body.catalog_action_id) }
          },
          playerId: claims.sub,
          catalogActionId: toStringValue(body.catalog_action_id)
        });
        res.json(result);
      } catch (error) { platformFailure(res, error); }
    })
  );

  const servePlayerJwks = (_req: Request, res: Response): void => {
    if (!identityConfigured) {
      res.status(503).json({ ok: false, err: "player_identity_sessions_not_configured" });
      return;
    }
    res.json({ keys: [playerTokenPublicJwk(config.identity)] });
  };
  app.get("/.well-known/jwks.json", servePlayerJwks);
  app.get("/v1/identity/.well-known/jwks.json", servePlayerJwks);

  app.post(
    "/v1/identity/register",
    asyncHandler(async (req, res) => {
      if (!identityConfigured) {
        res.status(503).json({ ok: false, err: "player_identity_sessions_not_configured" });
        return;
      }
      const payload = isRecord(req.body) ? req.body : {};
      const requestId = toStringValue(payload.request_id);
      const callSign = toStringValue(payload.call_sign) || toStringValue(payload.display_name);
      if (!validRequestId(requestId)) {
        invalidRequest(res, "invalid_request_id", { expected: "8-128 URL-safe characters" });
        return;
      }
      if (!isCallSign(callSign)) {
        invalidRequest(res, "invalid_call_sign", { expected: "^[A-Za-z0-9_]{3,16}$" });
        return;
      }
      const device = isRecord(payload.device) ? payload.device : {};
      const publicKeyJwk = device.public_key_jwk;
      if (!isRecord(publicKeyJwk)) {
        invalidRequest(res, "invalid_device_public_key");
        return;
      }
      try {
        const result = await identitySessions.registerIdentityAndDevice({
          requestId,
          callSign,
          region: toStringValue(payload.region).toUpperCase() || config.rank.defaultRegion,
          publicKeyJwk,
          platform: toStringValue(device.platform).toLowerCase().slice(0, 32) || "unknown",
          deviceLabel: toStringValue(device.label).slice(0, 80),
          installMetadata: isRecord(payload.install_metadata) ? payload.install_metadata : {}
        });
        res.status(result.duplicate ? 200 : 201).json({ ok: true, ...result });
      } catch (error) {
        identityFailure(res, error);
      }
    })
  );

  app.post(
    "/v1/identity/challenge",
    asyncHandler(async (req, res) => {
      if (!identityConfigured) {
        res.status(503).json({ ok: false, err: "player_identity_sessions_not_configured" });
        return;
      }
      const payload = isRecord(req.body) ? req.body : {};
      const deviceId = toStringValue(payload.device_id);
      const requestId = toStringValue(payload.request_id);
      if (!isUuidV7(deviceId)) {
        invalidRequest(res, "invalid_device_id", { expected: "UUIDv7" });
        return;
      }
      if (!validRequestId(requestId)) {
        invalidRequest(res, "invalid_request_id", { expected: "8-128 URL-safe characters" });
        return;
      }
      try {
        const challenge = await identitySessions.issueChallenge(deviceId, requestId);
        res.json({ ok: true, challenge });
      } catch (error) {
        identityFailure(res, error);
      }
    })
  );

  app.post(
    "/v1/identity/session",
    asyncHandler(async (req, res) => {
      if (!identityConfigured) {
        res.status(503).json({ ok: false, err: "player_identity_sessions_not_configured" });
        return;
      }
      const payload = isRecord(req.body) ? req.body : {};
      const challengeId = toStringValue(payload.challenge_id);
      const signature = toStringValue(payload.signature);
      if (!isUuidV7(challengeId) || !signature) {
        invalidRequest(res, "invalid_session_proof");
        return;
      }
      try {
        const session = await identitySessions.createSession(challengeId, signature);
        res.status(201).json({ ok: true, ...session });
      } catch (error) {
        identityFailure(res, error);
      }
    })
  );

  app.post(
    "/v1/identity/session/revoke",
    asyncHandler(async (req, res) => {
      if (!identityConfigured) {
        res.status(503).json({ ok: false, err: "player_identity_sessions_not_configured" });
        return;
      }
      try {
        const token = bearerTokenFromHeader(req.header("authorization"));
        if (!token) {
          throw new PlayerTokenError("token_missing");
        }
        const claims = verifyPlayerAccessToken(token, config.identity);
        const requestedSessionId = toStringValue(isRecord(req.body) ? req.body.session_id : "");
        if (requestedSessionId && requestedSessionId !== claims.sid) {
          res.status(403).json({ ok: false, err: "session_owner_mismatch" });
          return;
        }
        const revoked = await identitySessions.revokeSession(claims.sid, claims.sub,
          toStringValue(isRecord(req.body) ? req.body.reason : "player_request"));
        res.status(revoked ? 200 : 404).json(revoked
          ? { ok: true, session_id: claims.sid, revoked: true }
          : { ok: false, err: "session_not_found" });
      } catch (error) {
        identityFailure(res, error);
      }
    })
  );

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
          economy_epoch: config.economyEpoch,
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
      res.status(410).json({
        ok: false,
        err: "platform_economy_authority_required",
        code: "legacy_rank_action_superseded",
        action: "admin_recompute"
      });
    })
  );

  app.post(
    "/v1/rank/:action",
    requireRankActionAuth,
    asyncHandler(async (req, res) => {
      const action = toStringValue(req.params.action).replace(/^\/+/, "");
      const payload = isRecord(req.body) ? req.body : {};

      // Superseded actions are rejected by requireRankActionAuth before this
      // handler. This assertion retains a fail-closed second line of defense.
      if (isRankEconomyMutationAction(action)) {
        res.status(410).json({ ok: false, err: "platform_economy_authority_required",
          code: "legacy_rank_action_superseded", action });
        return;
      }

      switch (action) {
        case "get_snapshot": {
          const requestedLocalId = toStringValue(payload.local_player_id);
          if (requestedLocalId) {
            if (!requireCanonicalHumanPlayerId(res, requestedLocalId, "local_player_id")) {
              return;
            }
            const result = await store.writeIdentity((state, context) => {
              const requestedExisting = state.players_by_id[requestedLocalId];
              if (requestedExisting) {
                state.local_player_id = requestedLocalId;
                context.recordAuditEvent({
                  event_type: "player_snapshot_requested",
                  player_id: requestedLocalId,
                  payload: { source: "get_snapshot" }
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
          const callSign = toStringValue(payload.call_sign) || toStringValue(payload.display_name);
          if (!isCallSign(callSign)) {
            invalidRequest(res, "invalid_call_sign", { expected: "^[A-Za-z0-9_]{3,16}$" });
            return;
          }
          const region = toStringValue(payload.region);
          const friends = sanitizeFriends(payload.friends);
          if (!requireFriendIds(res, friends)) {
            return;
          }
          const installMetadata = isRecord(payload.install_metadata) ? payload.install_metadata : {};
          const result = await store.registerPlayerIdentity({
            callSign,
            region,
            friends,
            installMetadata
          });
          res.status(result.ok ? 200 : result.err === "call_sign_not_unique" ? 409 : 500).json(
            result.ok && result.player
              ? { ok: true, player: playerSnapshot(result.player) }
              : { ok: false, err: result.err ?? "identity_registration_failed", call_sign: callSign }
          );
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
          const result = await store.writeIdentity((state, context) => {
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
          const result = await store.writeIdentity((state, context) => {
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
          const moneyTier = Math.max(0, Math.trunc(toNumberValue(payload.money_tier, toNumberValue(metadata.money_tier, 0))));
          const eventId = toStringValue(metadata.event_id);
          const blockedReason = matchRewardBlockReason(metadata);
          if (blockedReason) {
            res.status(422).json({ ok: false, err: blockedReason, awarded: false });
            return;
          }

          const result = await store.writeEconomy((state, context) => {
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

            const playerGain = computeGain(playerWaxBefore, opponentWaxBefore, modeName, moneyTier);
            const opponentGain = computeGain(opponentWaxBefore, playerWaxBefore, modeName, moneyTier);
            const playerLoss = computeLoss(playerWaxBefore, opponentWaxBefore, modeName, moneyTier);
            const opponentLoss = computeLoss(opponentWaxBefore, playerWaxBefore, modeName, moneyTier);

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
                money_tier: moneyTier,
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
              money_tier: moneyTier,
              did_player_win: didPlayerWin,
              event_id: eventId
            }, opponentId);
            recordRankChangeAudit(context.recordAuditEvent, "rank_state_changed", opponentBefore, state.players_by_id[opponentId], {
              reason: "match_result",
              mode_name: modeName,
              money_tier: moneyTier,
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

        case "record_contest_result": {
          const playerId = toStringValue(payload.player_id);
          if (!playerId) {
            res.status(400).json({ ok: false, err: "missing_player_id" });
            return;
          }
          if (!requireCanonicalHumanPlayerId(res, playerId, "player_id")) {
            return;
          }

          const metadata = isRecord(payload.metadata) ? payload.metadata : {};
          const contestScope = toStringValue(payload.contest_scope).toUpperCase();
          const placement = Math.max(1, Math.trunc(toNumberValue(payload.placement, 0)));
          const eventId = toStringValue(metadata.event_id);

          const result = await store.writeEconomy((state, context) => {
            if (eventId) {
              const dedupeKey = `${playerId}:${eventId}`;
              if (state.processed_events[dedupeKey]) {
                return {
                  ok: true,
                  duplicate: true,
                  player: playerSnapshot(state.players_by_id[playerId])
                };
              }
            }

            ensurePlayerExists(state, playerId, playerId);
            const playerBefore = state.players_by_id[playerId] ? { ...state.players_by_id[playerId] } : undefined;

            const unixNow = nowUnix();
            applyDecayAll(state, unixNow);

            const player = state.players_by_id[playerId];
            const waxBefore = player.wax_score;
            const waxBonus = computeContestPlacementWax(contestScope, placement);

            if (waxBonus <= 0) {
              return {
                ok: true,
                awarded: false,
                player: playerSnapshot(state.players_by_id[playerId]),
                snapshot: stateSnapshot(state)
              };
            }

            player.wax_score = waxBefore + waxBonus;
            player.last_active_unix = unixNow;
            player.last_decay_day = Math.floor(unixNow / 86_400);
            state.players_by_id[playerId] = normalizePlayerRecord(playerId, player, unixNow);

            recomputeRankings(state);

            if (eventId) {
              const dedupeKey = `${playerId}:${eventId}`;
              state.processed_events[dedupeKey] = unixNow;
              pruneProcessedEvents(state);
            }
            context.recordAuditEvent({
              event_type: "contest_result_recorded",
              player_id: playerId,
              payload: {
                contest_scope: contestScope,
                placement,
                event_id: eventId,
                wax_before: waxBefore,
                wax_after: state.players_by_id[playerId].wax_score,
                wax_bonus: waxBonus
              }
            });
            recordRankChangeAudit(context.recordAuditEvent, "rank_state_changed", playerBefore, state.players_by_id[playerId], {
              reason: "contest_result",
              contest_scope: contestScope,
              placement,
              event_id: eventId
            });

            return {
              ok: true,
              awarded: true,
              player: playerSnapshot(state.players_by_id[playerId]),
              snapshot: stateSnapshot(state)
            };
          });

          res.json(result);
          return;
        }

        case "apply_decay_tick": {
          const result = await store.writeEconomy((state, context) => {
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
          const result = await store.writeEconomy((state, context) => {
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
          const result = await store.writeEconomy((state, context) => {
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
