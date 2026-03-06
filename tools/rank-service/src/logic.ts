import { config } from "./config.js";
import type {
  MatchCandidateRow,
  MatchQueueEntry,
  PlayerRecord,
  RankState,
  TierBandDef
} from "./types.js";

const DAY_SECONDS = 86_400;
const DEFAULT_TIER = "DRONE";
const DEFAULT_COLOR = "GREEN";
const APEX_TIERS = new Set(["EXECUTIONER_WASP", "SCORPION_WASP", "COW_KILLER"]);

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function normalizeId(value: string): string {
  return value.trim();
}

function normalizeTier(value: string): string {
  const v = value.trim().toUpperCase();
  return v || DEFAULT_TIER;
}

function normalizeColor(value: string): string {
  const v = value.trim().toUpperCase();
  return v || DEFAULT_COLOR;
}

function normalizeRegion(value: string): string {
  const v = value.trim().toUpperCase();
  return v || config.rank.defaultRegion;
}

function normalizeDisplayName(displayName: string, playerId: string): string {
  const clean = displayName.trim();
  return clean === "" ? playerId : clean;
}

function normalizeHistory(raw: unknown, currentTier: string): Record<string, boolean> {
  const out: Record<string, boolean> = {};
  if (typeof raw === "object" && raw != null && !Array.isArray(raw)) {
    for (const [key, value] of Object.entries(raw)) {
      const clean = key.trim().toUpperCase();
      if (!clean) {
        continue;
      }
      out[clean] = Boolean(value);
    }
  }
  if (Object.keys(out).length === 0) {
    out[currentTier] = true;
  }
  return out;
}

export function nowUnix(): number {
  return Math.floor(Date.now() / 1000);
}

export function sanitizeFriends(raw: unknown): string[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const out: string[] = [];
  for (const friend of raw) {
    const friendId = String(friend ?? "").trim();
    if (!friendId || out.includes(friendId)) {
      continue;
    }
    out.push(friendId);
  }
  return out;
}

export function orderedTierIds(): string[] {
  return config.rank.tierBands.map((band) => band.id.trim().toUpperCase()).filter((id) => id.length > 0);
}

export function normalizedColorQuintiles(): string[] {
  const out = config.rank.colorQuintiles.map((color) => color.trim().toUpperCase()).filter((color) => color.length > 0);
  return out.length > 0 ? out : ["GREEN", "BLUE", "RED", "BLACK", "YELLOW"];
}

export function tierIndex(tierId: string): number {
  return orderedTierIds().indexOf(tierId.trim().toUpperCase());
}

function openedTierCount(totalPlayers: number): number {
  const tiers = orderedTierIds();
  if (tiers.length === 0) {
    return 0;
  }
  const unlockSize = Math.max(1, config.rank.playersPerTierToUnlock);
  const safeTotal = Math.max(1, totalPlayers);
  const opened = Math.floor(safeTotal / unlockSize) + 1;
  return clamp(opened, 1, tiers.length);
}

function buildEvenBands(activeTiers: string[]): Array<{ id: string; min_pct: number; max_pct: number }> {
  if (activeTiers.length === 0) {
    return [];
  }
  const out: Array<{ id: string; min_pct: number; max_pct: number }> = [];
  const step = 1.0 / activeTiers.length;
  for (let i = 0; i < activeTiers.length; i += 1) {
    const minPct = step * i;
    const maxPct = i === activeTiers.length - 1 ? 1.0 : step * (i + 1);
    out.push({ id: activeTiers[i], min_pct: minPct, max_pct: maxPct });
  }
  return out;
}

function buildFullOpenBands(activeTiers: string[]): Array<{ id: string; min_pct: number; max_pct: number }> {
  if (activeTiers.length < 11) {
    return buildEvenBands(activeTiers);
  }
  const topWeight = Math.max(0.0001, config.rank.fullOpenTopTierWeight);
  const middleWeight = topWeight * Math.max(0.0001, config.rank.fullOpenMiddleWeightMultiplierVsTop);
  const bottomWeight = middleWeight * Math.max(0.0001, config.rank.fullOpenBottomWeightMultiplierVsMiddle);

  const weights: number[] = [];
  let totalWeight = 0;
  for (let i = 0; i < activeTiers.length; i += 1) {
    let w = middleWeight;
    if (i < 5) {
      w = bottomWeight;
    } else if (i >= activeTiers.length - 5) {
      w = topWeight;
    }
    weights.push(w);
    totalWeight += w;
  }
  if (totalWeight <= 0) {
    return buildEvenBands(activeTiers);
  }

  const out: Array<{ id: string; min_pct: number; max_pct: number }> = [];
  let cursor = 0;
  for (let i = 0; i < activeTiers.length; i += 1) {
    const minPct = cursor;
    cursor += weights[i] / totalWeight;
    const maxPct = i === activeTiers.length - 1 ? 1.0 : cursor;
    out.push({ id: activeTiers[i], min_pct: minPct, max_pct: maxPct });
  }
  return out;
}

function tierPercentileBands(totalPlayers: number): Array<{ id: string; min_pct: number; max_pct: number }> {
  const allTiers = orderedTierIds();
  if (allTiers.length === 0) {
    return [];
  }
  const openCount = openedTierCount(totalPlayers);
  const activeTiers = allTiers.slice(0, Math.min(openCount, allTiers.length));
  if (activeTiers.length === 0) {
    return [];
  }
  if (activeTiers.length < allTiers.length) {
    return buildEvenBands(activeTiers);
  }
  return buildFullOpenBands(activeTiers);
}

function tierMinPercentileForPopulation(tierId: string, totalPlayers: number): number {
  const target = normalizeTier(tierId);
  const bands = tierPercentileBands(totalPlayers);
  for (const band of bands) {
    if (normalizeTier(band.id) === target) {
      return clamp(band.min_pct, 0, 1);
    }
  }
  return 0;
}

function isTierOpen(tierId: string, totalPlayers: number): boolean {
  const target = normalizeTier(tierId);
  const bands = tierPercentileBands(totalPlayers);
  return bands.some((band) => normalizeTier(band.id) === target);
}

function resolveTierForPercentile(percentile: number, rankPosition: number, totalPlayers: number): string {
  const p = clamp(percentile, 0, 1);
  const _safeRank = Math.max(1, rankPosition);
  const safeTotal = Math.max(1, totalPlayers);
  const bands = tierPercentileBands(safeTotal);
  if (bands.length === 0) {
    return DEFAULT_TIER;
  }
  for (const band of bands) {
    const tierId = normalizeTier(band.id);
    const minPct = clamp(band.min_pct, 0, 1);
    const maxPct = clamp(band.max_pct, 0, 1);
    if (p >= minPct && (p < maxPct || Math.abs(p - maxPct) < 1e-9 || Math.abs(maxPct - 1.0) < 1e-9)) {
      return tierId;
    }
  }
  return DEFAULT_TIER;
}

function resolveColorForPercentile(percentile: number): string {
  const colors = normalizedColorQuintiles();
  const p = clamp(percentile, 0, 1);
  const colorIndex = clamp(Math.floor(p * colors.length), 0, colors.length - 1);
  return colors[colorIndex];
}

function normalizePlayerHistoryForTier(raw: unknown, tierId: string): Record<string, boolean> {
  return normalizeHistory(raw, normalizeTier(tierId));
}

export function normalizePlayerRecord(playerId: string, rawRecord: Partial<PlayerRecord>, unixNow: number = nowUnix()): PlayerRecord {
  const safePlayerId = normalizeId(playerId);
  const tierId = normalizeTier(String(rawRecord.tier_id ?? DEFAULT_TIER));
  return {
    player_id: safePlayerId,
    display_name: normalizeDisplayName(String(rawRecord.display_name ?? ""), safePlayerId),
    region: normalizeRegion(String(rawRecord.region ?? "")),
    wax_score: Math.max(config.rank.waxFloor, Number(rawRecord.wax_score ?? config.rank.baseGain)),
    last_active_unix: Math.max(0, Number(rawRecord.last_active_unix ?? unixNow)),
    last_decay_day: Number.isFinite(Number(rawRecord.last_decay_day)) ? Math.trunc(Number(rawRecord.last_decay_day)) : -1,
    tier_id: tierId,
    color_id: normalizeColor(String(rawRecord.color_id ?? DEFAULT_COLOR)),
    rank_position: Math.max(0, Math.trunc(Number(rawRecord.rank_position ?? 0))),
    percentile: clamp(Number(rawRecord.percentile ?? 0), 0, 1),
    promotion_history: normalizePlayerHistoryForTier(rawRecord.promotion_history, tierId),
    friends: sanitizeFriends(rawRecord.friends),
    apex_active: Boolean(rawRecord.apex_active)
  };
}

export function newPlayerRecord(playerId: string, displayName: string, region: string, unixNow: number, friends: string[]): PlayerRecord {
  const safePlayerId = normalizeId(playerId);
  return {
    player_id: safePlayerId,
    display_name: normalizeDisplayName(displayName, safePlayerId),
    region: normalizeRegion(region),
    wax_score: Math.max(config.rank.waxFloor, config.rank.baseGain),
    last_active_unix: unixNow,
    last_decay_day: -1,
    tier_id: DEFAULT_TIER,
    color_id: DEFAULT_COLOR,
    rank_position: 0,
    percentile: 0,
    promotion_history: { [DEFAULT_TIER]: true },
    friends: sanitizeFriends(friends),
    apex_active: false
  };
}

export function ensurePlayerExists(state: RankState, playerId: string, displayName = ""): void {
  const cleanId = normalizeId(playerId);
  if (!cleanId || state.players_by_id[cleanId]) {
    return;
  }
  const unixNow = nowUnix();
  state.players_by_id[cleanId] = newPlayerRecord(cleanId, displayName || cleanId, config.rank.defaultRegion, unixNow, []);
}

export function computeGain(playerWax: number, opponentWax: number, modeName: string): number {
  const safePlayer = Math.max(playerWax, 1.0);
  const safeOpponent = Math.max(opponentWax, 1.0);
  const ratio = safeOpponent / safePlayer;
  let modifier = Math.pow(ratio, config.rank.opponentStrengthExponent);
  modifier = clamp(modifier, config.rank.opponentStrengthMin, config.rank.opponentStrengthMax);
  const modeModifier = config.rank.modeModifiers[modeName.trim().toUpperCase()] ?? 1.0;
  return Math.max(0, config.rank.baseGain * modifier * modeModifier);
}

export function computeLoss(playerWax: number, opponentWax: number, modeName: string): number {
  if (!config.rank.lossesSubtractWax) {
    return 0;
  }
  const baseLoss = computeGain(playerWax, opponentWax, modeName);
  return Math.max(0, baseLoss * Math.max(0, config.rank.lossScale));
}

function applyDecay(record: PlayerRecord, unixNow: number): boolean {
  if (unixNow <= 0) {
    return false;
  }
  let lastActiveUnix = Math.max(0, Math.trunc(record.last_active_unix));
  if (lastActiveUnix <= 0) {
    lastActiveUnix = unixNow;
    record.last_active_unix = unixNow;
  }

  const dayNow = Math.floor(unixNow / DAY_SECONDS);
  const lastActiveDay = Math.floor(lastActiveUnix / DAY_SECONDS);
  const graceEndDay = lastActiveDay + Math.max(0, config.rank.inactivityGraceDays);
  if (dayNow <= graceEndDay) {
    return false;
  }

  const lastDecayDay = Math.trunc(record.last_decay_day);
  const startDay = Math.max(graceEndDay + 1, lastDecayDay + 1);
  if (startDay > dayNow) {
    return false;
  }

  const decayDays = dayNow - startDay + 1;
  const waxBefore = Math.max(0, record.wax_score);
  const retention = Math.pow(Math.max(0, 1.0 - config.rank.dailyDecayRate), decayDays);
  const waxAfter = Math.max(config.rank.waxFloor, waxBefore * retention);
  record.wax_score = waxAfter;
  record.last_decay_day = dayNow;
  return true;
}

export function applyDecayAll(state: RankState, unixNow: number): number {
  let applied = 0;
  for (const [playerId, record] of Object.entries(state.players_by_id)) {
    const cloned = normalizePlayerRecord(playerId, record, unixNow);
    if (applyDecay(cloned, unixNow)) {
      applied += 1;
    }
    state.players_by_id[playerId] = cloned;
  }
  return applied;
}

export function sortPlayerIdsDesc(playersById: Record<string, PlayerRecord>): string[] {
  const ids = Object.keys(playersById).filter((id) => id.trim().length > 0);
  ids.sort((a, b) => {
    const aWax = Number(playersById[a]?.wax_score ?? 0);
    const bWax = Number(playersById[b]?.wax_score ?? 0);
    if (Math.abs(aWax - bWax) < 1e-9) {
      return a < b ? -1 : a > b ? 1 : 0;
    }
    return bWax - aWax;
  });
  return ids;
}

function buildPercentileMap(sortedIdsDesc: string[]): Record<string, { rank_position: number; percentile: number }> {
  const out: Record<string, { rank_position: number; percentile: number }> = {};
  const count = Math.max(1, sortedIdsDesc.length);
  if (count === 1 && sortedIdsDesc.length === 1) {
    out[sortedIdsDesc[0]] = { rank_position: 1, percentile: 1.0 };
    return out;
  }
  for (let i = 0; i < sortedIdsDesc.length; i += 1) {
    const id = sortedIdsDesc[i];
    const rankPosition = i + 1;
    const percentile = 1.0 - i / (count - 1);
    out[id] = {
      rank_position: rankPosition,
      percentile: clamp(percentile, 0, 1)
    };
  }
  return out;
}

function percentileStepForPopulation(totalPlayers: number): number {
  if (totalPlayers <= 1) {
    return 1.0;
  }
  return 1.0 / Math.max(1, totalPlayers - 1);
}

function resolveDemotionTier(
  currentTier: string,
  targetTier: string,
  percentile: number,
  totalPlayers: number,
  tiers: string[]
): string {
  const idxCurrent = tiers.indexOf(currentTier);
  let idxTarget = tiers.indexOf(targetTier);
  if (idxCurrent < 0) {
    return targetTier;
  }
  if (idxTarget < 0) {
    idxTarget = 0;
  }

  let idx = idxCurrent;
  while (idx > idxTarget) {
    const currentId = tiers[idx];
    if (!isTierOpen(currentId, totalPlayers)) {
      idx -= 1;
      continue;
    }
    const minPct = tierMinPercentileForPopulation(currentId, totalPlayers);
    const graceSlots = Math.max(0, config.rank.tierDemotionGraceSlots);
    const demotionGracePct = percentileStepForPopulation(totalPlayers) * graceSlots;
    let demotionFloor = minPct - config.rank.promotionBuffer;
    if (graceSlots > 0) {
      demotionFloor = minPct - demotionGracePct;
    }
    if (percentile < demotionFloor) {
      idx -= 1;
      continue;
    }
    break;
  }
  return tiers[idx] ?? DEFAULT_TIER;
}

function resolveColor(
  resolvedTier: string,
  oldTier: string,
  currentColor: string,
  percentile: number,
  tierPromoted: boolean,
  tierDemoted: boolean
): string {
  const colors = normalizedColorQuintiles();
  const targetColor = resolveColorForPercentile(percentile);
  if (tierPromoted || tierDemoted || resolvedTier !== oldTier) {
    return targetColor;
  }

  const idxCurrent = Math.max(0, colors.indexOf(currentColor));
  const idxTarget = colors.indexOf(targetColor);
  if (idxTarget < 0 || idxTarget === idxCurrent) {
    return currentColor;
  }
  if (idxTarget > idxCurrent) {
    return targetColor;
  }

  const globalPct = clamp(percentile, 0, 1);
  const step = 1.0 / Math.max(1, colors.length);
  const currentColorStart = idxCurrent * step;
  if (globalPct < currentColorStart - config.rank.colorBuffer) {
    return targetColor;
  }
  return currentColor;
}

function resolvePromotion(
  record: PlayerRecord,
  percentile: number,
  rankPosition: number,
  totalPlayers: number
): {
  tier_id: string;
  color_id: string;
  promotion_history: Record<string, boolean>;
  apex_active: boolean;
} {
  const tiers = orderedTierIds();
  let currentTier = normalizeTier(record.tier_id);
  let currentTierIndex = tiers.indexOf(currentTier);
  if (currentTierIndex < 0) {
    currentTier = DEFAULT_TIER;
    currentTierIndex = tiers.indexOf(currentTier);
  }

  const targetTier = resolveTierForPercentile(percentile, rankPosition, totalPlayers);
  const targetTierIndex = tiers.indexOf(targetTier);

  let resolvedTier = currentTier;
  let tierPromoted = false;
  let tierDemoted = false;

  if (currentTierIndex < 0) {
    resolvedTier = targetTier;
  } else if (targetTierIndex > currentTierIndex) {
    resolvedTier = targetTier;
    tierPromoted = true;
  } else if (targetTierIndex < currentTierIndex) {
    resolvedTier = resolveDemotionTier(currentTier, targetTier, percentile, totalPlayers, tiers);
    tierDemoted = tiers.indexOf(resolvedTier) < currentTierIndex;
  }

  const history = normalizePlayerHistoryForTier(record.promotion_history, currentTier);
  if (tierPromoted) {
    history[resolvedTier] = true;
  }

  const currentColor = normalizeColor(record.color_id);
  const resolvedColor = resolveColor(
    resolvedTier,
    currentTier,
    currentColor,
    percentile,
    tierPromoted,
    tierDemoted
  );

  return {
    tier_id: resolvedTier,
    color_id: resolvedColor,
    promotion_history: history,
    apex_active: APEX_TIERS.has(resolvedTier)
  };
}

function countPlayersInTier(playersById: Record<string, PlayerRecord>, tierId: string): number {
  let count = 0;
  for (const record of Object.values(playersById)) {
    if (normalizeTier(record.tier_id) === normalizeTier(tierId)) {
      count += 1;
    }
  }
  return count;
}

function findTopPlayerInTier(sortedIds: string[], playersById: Record<string, PlayerRecord>, tierId: string): string {
  for (const playerId of sortedIds) {
    const record = playersById[playerId];
    if (!record) {
      continue;
    }
    if (normalizeTier(record.tier_id) === normalizeTier(tierId)) {
      return playerId;
    }
  }
  return "";
}

function buildTargetTierCounts(
  sortedIds: string[],
  percentileMap: Record<string, { rank_position: number; percentile: number }>
): Record<string, number> {
  const out: Record<string, number> = {};
  for (const tierId of orderedTierIds()) {
    out[tierId] = 0;
  }
  const totalPlayers = sortedIds.length;
  for (const playerId of sortedIds) {
    const rankData = percentileMap[playerId];
    if (!rankData) {
      continue;
    }
    const targetTier = resolveTierForPercentile(rankData.percentile, rankData.rank_position, totalPlayers);
    out[targetTier] = (out[targetTier] ?? 0) + 1;
  }
  return out;
}

function applyTierOverflowPromotionSmoothing(
  state: RankState,
  sortedIds: string[],
  percentileMap: Record<string, { rank_position: number; percentile: number }>,
  unixNow: number
): void {
  const tiers = orderedTierIds();
  if (tiers.length < 2 || sortedIds.length <= 0) {
    return;
  }
  const targetTierCounts = buildTargetTierCounts(sortedIds, percentileMap);
  const openTierIndices: number[] = [];
  for (let i = 0; i < tiers.length; i += 1) {
    if ((targetTierCounts[tiers[i]] ?? 0) > 0) {
      openTierIndices.push(i);
    }
  }

  for (const tierIndex of openTierIndices) {
    if (tierIndex >= tiers.length - 1) {
      continue;
    }
    const tierId = tiers[tierIndex];
    const nextTierId = tiers[tierIndex + 1];
    const tierTarget = Math.max(0, targetTierCounts[tierId] ?? 0);

    // Overflow in a full tier bubbles upward by promoting the top edge.
    let safety = sortedIds.length + 1;
    while (safety > 0 && countPlayersInTier(state.players_by_id, tierId) > tierTarget) {
      safety -= 1;
      const promoteId = findTopPlayerInTier(sortedIds, state.players_by_id, tierId);
      if (!promoteId) {
        break;
      }
      const record = state.players_by_id[promoteId];
      if (!record) {
        break;
      }
      const history = normalizePlayerHistoryForTier(record.promotion_history, nextTierId);
      history[nextTierId] = true;
      record.tier_id = nextTierId;
      record.color_id = resolveColorForPercentile(record.percentile);
      record.promotion_history = history;
      record.apex_active = APEX_TIERS.has(nextTierId);
      state.players_by_id[promoteId] = normalizePlayerRecord(promoteId, record, unixNow);
    }
  }
}

export function recomputeRankings(state: RankState): void {
  const unixNow = nowUnix();
  applyDecayAll(state, unixNow);
  const sortedIds = sortPlayerIdsDesc(state.players_by_id);
  const percentileMap = buildPercentileMap(sortedIds);

  for (const playerId of sortedIds) {
    const raw = state.players_by_id[playerId];
    const record = normalizePlayerRecord(playerId, raw, unixNow);
    const rankData = percentileMap[playerId] ?? { rank_position: 0, percentile: 0 };
    record.rank_position = rankData.rank_position;
    record.percentile = rankData.percentile;

    const resolved = resolvePromotion(record, rankData.percentile, rankData.rank_position, sortedIds.length);
    record.tier_id = resolved.tier_id;
    record.color_id = resolved.color_id;
    record.promotion_history = resolved.promotion_history;
    record.apex_active = resolved.apex_active;

    state.players_by_id[playerId] = normalizePlayerRecord(playerId, record, unixNow);
  }

  applyTierOverflowPromotionSmoothing(state, sortedIds, percentileMap, unixNow);
}

function waxGapToAbove(playersById: Record<string, PlayerRecord>, sortedIdsDesc: string[], playerId: string): number {
  const idx = sortedIdsDesc.indexOf(playerId);
  if (idx <= 0) {
    return 0;
  }
  const waxNow = Number(playersById[playerId]?.wax_score ?? 0);
  const waxAbove = Number(playersById[sortedIdsDesc[idx - 1]]?.wax_score ?? waxNow);
  return Math.max(0, waxAbove - waxNow);
}

function waxGapToBelow(playersById: Record<string, PlayerRecord>, sortedIdsDesc: string[], playerId: string): number {
  const idx = sortedIdsDesc.indexOf(playerId);
  if (idx < 0 || idx + 1 >= sortedIdsDesc.length) {
    return 0;
  }
  const waxNow = Number(playersById[playerId]?.wax_score ?? 0);
  const waxBelow = Number(playersById[sortedIdsDesc[idx + 1]]?.wax_score ?? waxNow);
  return Math.max(0, waxNow - waxBelow);
}

function neighbors(playersById: Record<string, PlayerRecord>, sortedIdsDesc: string[], requesterId: string): Record<string, unknown> {
  const idx = sortedIdsDesc.indexOf(requesterId);
  if (idx < 0) {
    return {};
  }

  const out: Record<string, unknown> = {};
  if (idx > 0) {
    const aboveId = sortedIdsDesc[idx - 1];
    const above = playersById[aboveId];
    const requester = playersById[requesterId];
    const requesterWax = Number(requester?.wax_score ?? 0);
    const aboveWax = Number(above?.wax_score ?? requesterWax);
    out.above = {
      player_id: aboveId,
      display_name: String(above?.display_name ?? aboveId),
      wax_score: aboveWax,
      rank_position: Number(above?.rank_position ?? 0)
    };
    out.wax_gap_to_above = Math.max(0, aboveWax - requesterWax);
  }
  if (idx + 1 < sortedIdsDesc.length) {
    const belowId = sortedIdsDesc[idx + 1];
    const below = playersById[belowId];
    out.below = {
      player_id: belowId,
      display_name: String(below?.display_name ?? belowId),
      wax_score: Number(below?.wax_score ?? 0),
      rank_position: Number(below?.rank_position ?? 0)
    };
  }
  return out;
}

function filterIds(playersById: Record<string, PlayerRecord>, sortedIdsDesc: string[], requesterId: string, filterName: string): string[] {
  const filterKey = filterName.trim().toUpperCase();
  if (filterKey === "GLOBAL") {
    return [...sortedIdsDesc];
  }

  const requester = playersById[requesterId];
  if (!requester) {
    return [...sortedIdsDesc];
  }

  if (filterKey === "REGION") {
    const region = String(requester.region ?? config.rank.defaultRegion);
    return sortedIdsDesc.filter((id) => String(playersById[id]?.region ?? config.rank.defaultRegion) === region);
  }

  if (filterKey === "FRIENDS") {
    const friendSet = new Set(sanitizeFriends(requester.friends));
    return sortedIdsDesc.filter((id) => id === requesterId || friendSet.has(id));
  }

  return [...sortedIdsDesc];
}

export function buildLeaderboardView(
  state: RankState,
  requesterId: string,
  filterName = "GLOBAL",
  limit = 25
): Record<string, unknown> {
  const sortedIdsDesc = sortPlayerIdsDesc(state.players_by_id);
  const filteredIds = filterIds(state.players_by_id, sortedIdsDesc, requesterId, filterName);
  const rows: Record<string, unknown>[] = [];
  const safeLimit = Math.max(1, Math.trunc(limit));

  for (let i = 0; i < Math.min(filteredIds.length, safeLimit); i += 1) {
    const playerId = filteredIds[i];
    const record = state.players_by_id[playerId];
    if (!record) {
      continue;
    }
    rows.push({
      rank_filtered: i + 1,
      rank_global: Number(record.rank_position ?? i + 1),
      player_id: playerId,
      display_name: String(record.display_name ?? playerId),
      region: String(record.region ?? config.rank.defaultRegion),
      wax_score: Number(record.wax_score ?? 0),
      tier_id: String(record.tier_id ?? DEFAULT_TIER),
      color_id: String(record.color_id ?? DEFAULT_COLOR),
      percentile: Number(record.percentile ?? 0),
      apex_active: Boolean(record.apex_active),
      wax_gap_to_above: waxGapToAbove(state.players_by_id, sortedIdsDesc, playerId),
      wax_gap_to_below: waxGapToBelow(state.players_by_id, sortedIdsDesc, playerId)
    });
  }

  const requester = state.players_by_id[requesterId];
  let localContext: Record<string, unknown> = {};
  if (requester) {
    const requesterRank = Number(requester.rank_position ?? 0);
    const requesterTierIndex = tierIndex(String(requester.tier_id ?? DEFAULT_TIER));
    let targetRank = 0;
    for (const playerId of sortedIdsDesc) {
      const row = state.players_by_id[playerId];
      if (!row) {
        continue;
      }
      const rowRank = Number(row.rank_position ?? 0);
      if (rowRank <= 0 || rowRank >= requesterRank) {
        continue;
      }
      const rowTierIndex = tierIndex(String(row.tier_id ?? DEFAULT_TIER));
      if (rowTierIndex > requesterTierIndex) {
        targetRank = rowRank;
        break;
      }
    }
    const placesToNextTier = targetRank > 0 ? requesterRank - targetRank : 0;
    const neighborData = neighbors(state.players_by_id, sortedIdsDesc, requesterId);
    localContext = {
      rank_position: requesterRank,
      wax_score: Number(requester.wax_score ?? 0),
      tier_id: String(requester.tier_id ?? DEFAULT_TIER),
      color_id: String(requester.color_id ?? DEFAULT_COLOR),
      percentile: Number(requester.percentile ?? 0),
      places_to_next_tier: placesToNextTier,
      neighbors: neighborData,
      wax_gap_to_next_player: Number((neighborData.wax_gap_to_above as number | undefined) ?? 0)
    };
  }

  return {
    filter: filterName,
    rows,
    local_context: localContext
  };
}

function colorDistance(requesterColor: string, candidateColor: string): number {
  const colors = normalizedColorQuintiles();
  const requesterIdx = colors.indexOf(normalizeColor(requesterColor));
  const candidateIdx = colors.indexOf(normalizeColor(candidateColor));
  if (requesterIdx < 0 || candidateIdx < 0) {
    return 99_999;
  }
  return Math.abs(candidateIdx - requesterIdx);
}

function tierDistance(requesterTier: string, candidateTier: string): number {
  const requesterIdx = tierIndex(normalizeTier(requesterTier));
  const candidateIdx = tierIndex(normalizeTier(candidateTier));
  if (requesterIdx < 0 || candidateIdx < 0) {
    return 99_999;
  }
  return Math.abs(candidateIdx - requesterIdx);
}

export function findMatchCandidates(state: RankState, requesterId: string, queueEntries: MatchQueueEntry[]): MatchCandidateRow[] {
  const requester = state.players_by_id[requesterId];
  if (!requester) {
    return [];
  }

  const requesterWax = Number(requester.wax_score ?? 0);
  const requesterTier = String(requester.tier_id ?? DEFAULT_TIER);
  const requesterColor = String(requester.color_id ?? DEFAULT_COLOR);

  const rows: MatchCandidateRow[] = [];
  for (const entry of queueEntries) {
    const candidateId = normalizeId(String(entry.player_id ?? ""));
    if (!candidateId || candidateId === requesterId) {
      continue;
    }
    const candidate = state.players_by_id[candidateId];
    if (!candidate) {
      continue;
    }

    const waitSeconds = Math.max(0, Number(entry.wait_seconds ?? 0));
    let waxTolerance = config.rank.mmBaseWaxTolerance + waitSeconds * config.rank.mmWaxTolerancePerSec;
    waxTolerance = clamp(waxTolerance, config.rank.mmBaseWaxTolerance, config.rank.mmMaxWaxTolerance);

    const candidateWax = Number(candidate.wax_score ?? 0);
    const waxDelta = Math.abs(candidateWax - requesterWax);
    if (waxDelta > waxTolerance) {
      continue;
    }

    const candidateTier = String(candidate.tier_id ?? DEFAULT_TIER);
    const candidateColor = String(candidate.color_id ?? DEFAULT_COLOR);
    const rowTierDistance = tierDistance(requesterTier, candidateTier);
    const rowColorDistance = colorDistance(requesterColor, candidateColor);

    let score = 10_000;
    score -= rowTierDistance * 1000;
    score -= rowColorDistance * 100;
    score -= waxDelta;

    rows.push({
      player_id: candidateId,
      display_name: String(candidate.display_name ?? candidateId),
      wax_score: candidateWax,
      wax_delta: waxDelta,
      tier_id: candidateTier,
      color_id: candidateColor,
      tier_distance: rowTierDistance,
      color_distance: rowColorDistance,
      wait_seconds: waitSeconds,
      score
    });
  }

  rows.sort((a, b) => {
    if (a.tier_distance !== b.tier_distance) {
      return a.tier_distance - b.tier_distance;
    }
    if (a.color_distance !== b.color_distance) {
      return a.color_distance - b.color_distance;
    }
    if (Math.abs(a.wax_delta - b.wax_delta) > 1e-9) {
      return a.wax_delta - b.wax_delta;
    }
    if (Math.abs(a.wait_seconds - b.wait_seconds) > 1e-9) {
      return b.wait_seconds - a.wait_seconds;
    }
    return a.player_id.localeCompare(b.player_id);
  });

  return rows;
}

export function playerSnapshot(record: PlayerRecord | undefined): Record<string, unknown> {
  if (!record) {
    return {};
  }
  return {
    player_id: record.player_id,
    display_name: record.display_name,
    region: record.region,
    wax_score: record.wax_score,
    last_active_unix: record.last_active_unix,
    last_decay_day: record.last_decay_day,
    tier_id: record.tier_id,
    color_id: record.color_id,
    rank_position: record.rank_position,
    percentile: record.percentile,
    promotion_history: { ...record.promotion_history },
    friends: [...record.friends],
    apex_active: record.apex_active
  };
}

export function stateSnapshot(state: RankState): Record<string, unknown> {
  const playersById: Record<string, unknown> = {};
  for (const [playerId, record] of Object.entries(state.players_by_id)) {
    playersById[playerId] = playerSnapshot(record);
  }
  return {
    local_player_id: state.local_player_id,
    players_by_id: playersById
  };
}

export function normalizeLoadedState(raw: unknown): RankState {
  const state: RankState = {
    local_player_id: "",
    players_by_id: {},
    processed_events: {}
  };

  if (typeof raw !== "object" || raw == null || Array.isArray(raw)) {
    return state;
  }
  const obj = raw as Record<string, unknown>;

  if (typeof obj.local_player_id === "string") {
    state.local_player_id = obj.local_player_id.trim();
  }

  if (typeof obj.processed_events === "object" && obj.processed_events != null && !Array.isArray(obj.processed_events)) {
    for (const [key, value] of Object.entries(obj.processed_events)) {
      state.processed_events[String(key)] = Math.max(0, Math.trunc(Number(value ?? 0)));
    }
  }

  if (typeof obj.players_by_id === "object" && obj.players_by_id != null && !Array.isArray(obj.players_by_id)) {
    for (const [playerId, record] of Object.entries(obj.players_by_id as Record<string, unknown>)) {
      if (typeof record !== "object" || record == null || Array.isArray(record)) {
        continue;
      }
      state.players_by_id[playerId] = normalizePlayerRecord(playerId, record as Partial<PlayerRecord>);
    }
  }

  recomputeRankings(state);
  return state;
}

export function pruneProcessedEvents(state: RankState, limit = 25_000): void {
  const entries = Object.entries(state.processed_events);
  if (entries.length <= limit) {
    return;
  }
  entries.sort((a, b) => a[1] - b[1]);
  const removeCount = entries.length - limit;
  for (let i = 0; i < removeCount; i += 1) {
    delete state.processed_events[entries[i][0]];
  }
}

export function tierNames(): TierBandDef[] {
  return config.rank.tierBands.map((band) => ({ ...band }));
}
