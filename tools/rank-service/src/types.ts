export interface TierBandDef {
  id: string;
  name: string;
  min_pct: number;
  max_pct: number;
}

export interface RankRuntimeConfig {
  baseGain: number;
  opponentStrengthExponent: number;
  opponentStrengthMin: number;
  opponentStrengthMax: number;
  lossesSubtractWax: boolean;
  lossScale: number;
  modeModifiers: Record<string, number>;
  inactivityGraceDays: number;
  dailyDecayRate: number;
  waxFloor: number;
  playersPerTierToUnlock: number;
  fullOpenTopTierWeight: number;
  fullOpenMiddleWeightMultiplierVsTop: number;
  fullOpenBottomWeightMultiplierVsMiddle: number;
  tierBands: TierBandDef[];
  apexTopCount: number;
  promotionBuffer: number;
  colorBuffer: number;
  tierDemotionGraceSlots: number;
  colorQuintiles: string[];
  mmBaseWaxTolerance: number;
  mmWaxTolerancePerSec: number;
  mmMaxWaxTolerance: number;
  defaultRegion: string;
}

export interface RankServiceConfig {
  port: number;
  bindHost: string;
  apiToken: string;
  databaseUrl: string;
  legacyStatePath: string;
  rank: RankRuntimeConfig;
}

export interface PlayerRecord {
  player_id: string;
  display_name: string;
  region: string;
  wax_score: number;
  last_active_unix: number;
  last_decay_day: number;
  tier_id: string;
  color_id: string;
  rank_position: number;
  percentile: number;
  promotion_history: Record<string, boolean>;
  friends: string[];
  apex_active: boolean;
}

export interface RankState {
  local_player_id: string;
  players_by_id: Record<string, PlayerRecord>;
  processed_events: Record<string, number>;
}

export interface MatchQueueEntry {
  player_id: string;
  wait_seconds?: number;
}

export interface MatchCandidateRow {
  player_id: string;
  display_name: string;
  wax_score: number;
  wax_delta: number;
  tier_id: string;
  color_id: string;
  tier_distance: number;
  color_distance: number;
  wait_seconds: number;
  score: number;
}
