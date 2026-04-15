import { defaultHighlightConfig } from "./config.js";
import type {
  AnalyticsFactor,
  AutoPostTier,
  HighlightConfig,
  HighlightScoringResult,
  MatchMode,
  NormalizedMatchAnalytics
} from "./types.js";

export interface BandResult {
  label: "too_low" | "low" | "goldilocks" | "high" | "excessive";
  scoreRaw: number;
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Math.max(0, Math.min(1, value));
}

function weightedScore(scoreRaw: number, weight: number): number {
  return Math.round(clamp01(scoreRaw) * weight);
}

function bandedGoldilocks(value: number, range: { min: number; sweetMin: number; sweetMax: number; high: number }): BandResult {
  if (value < range.min) {
    return { label: "too_low", scoreRaw: 0.1 };
  }
  if (value < range.sweetMin) {
    return { label: "low", scoreRaw: 0.55 };
  }
  if (value <= range.sweetMax) {
    return { label: "goldilocks", scoreRaw: 1 };
  }
  if (value <= range.high) {
    return { label: "high", scoreRaw: 0.62 };
  }
  return { label: "excessive", scoreRaw: 0.22 };
}

function factorFromBand(band: BandResult): AnalyticsFactor {
  return { label: band.label, score_raw: band.scoreRaw };
}

export function computeSwarmDensity(swarmsSentTotal: number, durationSeconds: number): number {
  if (durationSeconds <= 0) {
    return 0;
  }
  return Math.max(0, swarmsSentTotal) / durationSeconds;
}

export function computeDurationBand(
  mode: MatchMode,
  durationSeconds: number,
  config: HighlightConfig = defaultHighlightConfig
): BandResult {
  return bandedGoldilocks(durationSeconds, config.goldilocksRanges.duration[mode]);
}

export function computeSwarmDensityBand(
  mode: MatchMode,
  playerCount: number,
  swarmsSentTotal: number,
  durationSeconds: number,
  config: HighlightConfig = defaultHighlightConfig
): BandResult {
  const density = computeSwarmDensity(swarmsSentTotal, durationSeconds);
  const key = `${mode}_${playerCount}`;
  const range = config.goldilocksRanges.swarmDensity[key] ?? config.goldilocksRanges.swarmDensity.default;
  return bandedGoldilocks(density, range);
}

export function computeWatchabilityPass(
  matchAnalytics: NormalizedMatchAnalytics,
  config: HighlightConfig = defaultHighlightConfig
): boolean {
  const { match, analytics } = matchAnalytics;
  if (!match.ended_normally || match.disconnect || match.broken_or_unusable === true) {
    return false;
  }
  if (match.duration_seconds < config.scoreThresholds.minimumDurationSeconds) {
    return false;
  }
  if (
    analytics.closeness_factor.label === "severe_blowout" &&
    analytics.closeness_factor.score_raw < config.scoreThresholds.severeBlowoutClosenessRaw
  ) {
    return false;
  }
  return true;
}

function stakeScoreRaw(matchAnalytics: NormalizedMatchAnalytics, config: HighlightConfig): number {
  const { match } = matchAnalytics;
  if (!match.is_money_game && match.stake_amount_usd <= 0) {
    return 0;
  }
  for (const band of config.moneyStakeBands) {
    if (match.stake_amount_usd >= band.minUsd) {
      return band.scoreRaw;
    }
  }
  return 0;
}

function buffScoreRaw(buffCount: number, config: HighlightConfig): number {
  for (const band of config.buffUsageBands) {
    if (buffCount >= band.minBuffs) {
      return band.scoreRaw;
    }
  }
  return 0;
}

function autoPostTier(excitementScore: number, watchabilityPass: boolean, config: HighlightConfig): AutoPostTier {
  if (!watchabilityPass) {
    return "no_auto_post";
  }
  if (excitementScore >= config.scoreThresholds.tier1) {
    return "tier_1";
  }
  if (excitementScore >= config.scoreThresholds.tier2) {
    return "tier_2";
  }
  return "no_auto_post";
}

export function scoreMatch(
  matchAnalytics: NormalizedMatchAnalytics,
  config: HighlightConfig = defaultHighlightConfig
): HighlightScoringResult {
  const { match, analytics } = matchAnalytics;
  const swarmDensityBand = computeSwarmDensityBand(
    match.mode,
    match.player_count,
    match.swarms_sent_total,
    match.duration_seconds,
    config
  );
  const durationBand = computeDurationBand(match.mode, match.duration_seconds, config);
  analytics.swarm_density_factor = factorFromBand(swarmDensityBand);
  analytics.duration_factor = factorFromBand(durationBand);

  const weights = config.scoreWeights;
  const component_scores = {
    stakes: weightedScore(stakeScoreRaw(matchAnalytics, config), weights.stakes),
    mode_player_count: weightedScore(config.modePlayerCountScores[match.mode] ?? 0, weights.mode_player_count),
    buff_usage: weightedScore(buffScoreRaw(match.buffs_used_total, config), weights.buff_usage),
    comeback: weightedScore(analytics.comeback_factor.score_raw, weights.comeback),
    swarm_density: weightedScore(analytics.swarm_density_factor.score_raw, weights.swarm_density),
    duration: weightedScore(analytics.duration_factor.score_raw, weights.duration)
  };
  const excitement_score = Object.values(component_scores).reduce((sum, value) => sum + value, 0);
  const watchability_pass = computeWatchabilityPass(matchAnalytics, config);

  return {
    weights: { ...weights },
    component_scores,
    excitement_score,
    watchability_pass,
    auto_post_tier: autoPostTier(excitement_score, watchability_pass, config),
    scoring_visibility: {
      visible_to_players: false,
      publicly_described: false
    }
  };
}
