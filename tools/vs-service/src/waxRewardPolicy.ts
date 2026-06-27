export type JsonRecord = Record<string, unknown>;

const WAX_MILLIS = 1000;
const BASIS_POINTS_DENOMINATOR = 10_000;

const MODE_GROUP_STANDARD = "STANDARD_COMPETITIVE";
const MODE_GROUP_PROGRESSIVE = "PROGRESSIVE";
const MODE_GROUP_ASYNC = "ASYNC";
const MODE_GROUP_TOURNAMENT = "TOURNAMENT";
const MODE_GROUP_INELIGIBLE = "INELIGIBLE";

const STRENGTH_MUCH_WEAKER = "much_weaker";
const STRENGTH_SLIGHTLY_WEAKER = "slightly_weaker";
const STRENGTH_EQUAL = "equal";
const STRENGTH_SLIGHTLY_STRONGER = "slightly_stronger";
const STRENGTH_MUCH_STRONGER = "much_stronger";

function cleanString(value: unknown): string {
  return String(value ?? "").trim();
}

function numberValue(value: unknown, fallback = 0): number {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

function intValue(value: unknown, fallback = 0): number {
  return Math.trunc(numberValue(value, fallback));
}

function boolValue(value: unknown, fallback = false): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  const normalized = cleanString(value).toLowerCase();
  if (!normalized) {
    return fallback;
  }
  return ["1", "true", "yes", "on"].includes(normalized);
}

function recordValue(value: unknown): JsonRecord {
  return value != null && typeof value === "object" && !Array.isArray(value) ? value as JsonRecord : {};
}

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

export function defaultWaxRewardConfig(): JsonRecord {
  return {
    config_version: 1,
    slightly_stronger_delta: 100,
    much_stronger_delta: 400,
    async_multiplier_bps: 9500,
    repeated_opponent_soft_count: 2,
    repeated_opponent_zero_count: 3,
    close_loss_min_score: 0.8,
    close_loss_max_margin_ratio: 0.10,
    minimum_match_duration_sec: 30,
    standard_win_wax: {
      [STRENGTH_MUCH_WEAKER]: 1,
      [STRENGTH_SLIGHTLY_WEAKER]: 2,
      [STRENGTH_EQUAL]: 3,
      [STRENGTH_SLIGHTLY_STRONGER]: 4,
      [STRENGTH_MUCH_STRONGER]: 5
    },
    standard_loss_wax: {
      [STRENGTH_MUCH_WEAKER]: -2,
      [STRENGTH_SLIGHTLY_WEAKER]: -1,
      [STRENGTH_EQUAL]: 0,
      [STRENGTH_SLIGHTLY_STRONGER]: 0,
      [STRENGTH_MUCH_STRONGER]: 0
    },
    standard_close_loss_wax: {
      [STRENGTH_SLIGHTLY_STRONGER]: 1,
      [STRENGTH_MUCH_STRONGER]: 2
    },
    async_placement_wax: {
      champion: 5,
      runner_up: 3,
      top_25: 1,
      middle: 0,
      bottom_quartile: -1
    },
    tournament_weekly_wax: {
      champion: 25,
      runner_up: 15,
      top_5: 10,
      top_10: 6,
      top_25: 3
    },
    tournament_monthly_wax: {
      champion: 100,
      runner_up: 60,
      top_5: 40,
      top_10: 25,
      top_25: 10
    },
    tournament_seasonal_wax: {
      champion: 500,
      runner_up: 300,
      elite: 150,
      top_100: 75
    }
  };
}

export function waxPolicySnapshot(): JsonRecord {
  return {
    precision: "wax_millis",
    philosophy: "Wax rewards competitive excellence and is never awarded for participation alone.",
    config: defaultWaxRewardConfig()
  };
}

export function classifyWaxModeGroup(modeName: string): string {
  const mode = cleanString(modeName).toUpperCase();
  if (["CRUCIBLE"].includes(mode)) {
    return MODE_GROUP_INELIGIBLE;
  }
  if (["STANDARD", "PVP", "MONEY_MATCH", "1V1", "2V2", "3P_FFA", "4P_FFA", "CTF", "HCTF", "HIDDEN_CTF"].includes(mode)) {
    return MODE_GROUP_STANDARD;
  }
  if (["PROGRESSIVE", "PROGRESSIVE_RUN"].includes(mode)) {
    return MODE_GROUP_PROGRESSIVE;
  }
  if (["ASYNC", "STAGE_RACE", "TIMED_RACE", "MISS_N_OUT", "WMS"].includes(mode)) {
    return MODE_GROUP_ASYNC;
  }
  if (["TOURNAMENT", "WEEKLY", "MONTHLY", "SEASONAL", "YEARLY"].includes(mode)) {
    return MODE_GROUP_TOURNAMENT;
  }
  return MODE_GROUP_INELIGIBLE;
}

export function classifyOpponentStrength(playerRating: number, opponentRating: number, config: JsonRecord = {}): string {
  const merged = { ...defaultWaxRewardConfig(), ...config };
  const delta = opponentRating - playerRating;
  const slight = Math.max(1, numberValue(merged.slightly_stronger_delta, 100));
  const much = Math.max(slight + 1, numberValue(merged.much_stronger_delta, 400));
  if (delta <= -much) {
    return STRENGTH_MUCH_WEAKER;
  }
  if (delta <= -slight) {
    return STRENGTH_SLIGHTLY_WEAKER;
  }
  if (delta >= much) {
    return STRENGTH_MUCH_STRONGER;
  }
  if (delta >= slight) {
    return STRENGTH_SLIGHTLY_STRONGER;
  }
  return STRENGTH_EQUAL;
}

export function evaluateWaxMatch(payload: JsonRecord, config: JsonRecord = {}): JsonRecord {
  const merged = { ...defaultWaxRewardConfig(), ...config };
  const modeGroup = classifyWaxModeGroup(cleanString(payload.mode_name ?? payload.mode));
  const breakdown: JsonRecord = {
    ok: true,
    match_id: cleanString(payload.match_id),
    player_id: cleanString(payload.player_id),
    opponent_id: cleanString(payload.opponent_id),
    mode_group: modeGroup,
    result: boolValue(payload.did_win) ? "win" : "loss",
    opponent_strength_band: STRENGTH_EQUAL,
    close_loss_qualified: false,
    close_loss_score: 0,
    close_loss_reason: "",
    rating_source: cleanString(payload.rating_source),
    rating_confidence: numberValue(payload.rating_confidence),
    base_wax_delta: 0,
    mode_multiplier: 1,
    final_wax_delta: 0,
    final_wax_delta_millis: 0,
    validity_status: "eligible",
    anti_harvest_reason_if_blocked: "",
    config_version: intValue(merged.config_version, 1)
  };
  const blocked = blockedReason(payload, modeGroup);
  if (blocked) {
    breakdown.validity_status = blocked === "suspicious_wax_hold" ? "held_review" : "blocked";
    breakdown.anti_harvest_reason_if_blocked = blocked;
    return breakdown;
  }
  if (modeGroup === MODE_GROUP_TOURNAMENT) {
    return evaluateTournament(payload, merged, breakdown);
  }
  if (modeGroup === MODE_GROUP_ASYNC && boolValue(payload.placement_based)) {
    return evaluateAsyncPlacement(payload, merged, breakdown);
  }
  const strengthBand = classifyOpponentStrength(
    numberValue(payload.player_rating ?? payload.player_wax_score),
    numberValue(payload.opponent_rating ?? payload.opponent_wax_score),
    merged
  );
  breakdown.opponent_strength_band = strengthBand;
  const closeLoss = evaluateCloseLoss(payload, strengthBand, merged);
  breakdown.close_loss_qualified = Boolean(closeLoss.qualified);
  breakdown.close_loss_score = numberValue(closeLoss.score);
  breakdown.close_loss_reason = cleanString(closeLoss.reason);
  const baseDelta = baseMatchDelta(strengthBand, boolValue(payload.did_win), Boolean(closeLoss.qualified), merged);
  breakdown.base_wax_delta = baseDelta;
  const multiplierBps = modeGroup === MODE_GROUP_ASYNC ? intValue(merged.async_multiplier_bps, BASIS_POINTS_DENOMINATOR) : BASIS_POINTS_DENOMINATOR;
  const diminished = applyRepeatedOpponentDiminishing(baseDelta, intValue(payload.repeated_opponent_count), merged);
  const finalDelta = Math.round(intValue(diminished.delta, baseDelta) * multiplierBps / BASIS_POINTS_DENOMINATOR);
  breakdown.mode_multiplier = multiplierBps / BASIS_POINTS_DENOMINATOR;
  breakdown.final_wax_delta = finalDelta;
  breakdown.final_wax_delta_millis = finalDelta * WAX_MILLIS;
  if (cleanString(diminished.reason)) {
    breakdown.validity_status = "diminished";
    breakdown.anti_harvest_reason_if_blocked = cleanString(diminished.reason);
  }
  return breakdown;
}

function blockedReason(payload: JsonRecord, modeGroup: string): string {
  if (modeGroup === MODE_GROUP_INELIGIBLE) {
    return "ineligible_mode";
  }
  if (boolValue(payload.vs_crucible) || cleanString(payload.vs_ruleset).toUpperCase() === "CRUCIBLE") {
    return "crucible_no_participation_wax";
  }
  const blockFlags = ["tutorial", "practice", "custom_match", "private_match", "afk", "immediate_surrender", "no_contest", "refunded", "desync", "invalid_result"];
  for (const flag of blockFlags) {
    if (boolValue(payload[flag])) {
      return flag;
    }
  }
  if (Object.prototype.hasOwnProperty.call(payload, "minimum_quality_met") && !boolValue(payload.minimum_quality_met, true)) {
    return "minimum_quality_not_met";
  }
  const durationSec = numberValue(payload.duration_sec, numberValue(payload.match_duration_ms) / 1000);
  if (durationSec > 0 && durationSec < numberValue(defaultWaxRewardConfig().minimum_match_duration_sec, 30)) {
    return "match_too_short";
  }
  const reviewFlags = ["suspicious_win_trading", "same_account_cluster", "same_device_cluster", "same_ip_cluster", "account_cluster_abuse", "low_effort_farming", "win_trading_signal", "abuse_review_required"];
  for (const flag of reviewFlags) {
    if (boolValue(payload[flag])) {
      return "suspicious_wax_hold";
    }
  }
  if (cleanString(payload.review_status).toLowerCase() === "held") {
    return "suspicious_wax_hold";
  }
  return "";
}

function baseMatchDelta(strengthBand: string, didWin: boolean, closeLoss: boolean, config: JsonRecord): number {
  if (didWin) {
    return intValue(recordValue(config.standard_win_wax)[strengthBand]);
  }
  if (closeLoss) {
    return intValue(recordValue(config.standard_close_loss_wax)[strengthBand]);
  }
  return intValue(recordValue(config.standard_loss_wax)[strengthBand]);
}

function evaluateCloseLoss(payload: JsonRecord, strengthBand: string, config: JsonRecord): JsonRecord {
  if (boolValue(payload.did_win)) {
    return { qualified: false, score: 0, reason: "win" };
  }
  if (![STRENGTH_SLIGHTLY_STRONGER, STRENGTH_MUCH_STRONGER].includes(strengthBand)) {
    return { qualified: false, score: 0, reason: "opponent_not_stronger" };
  }
  const metric = closeLossMetric(payload, config);
  const score = clamp(numberValue(metric.score), 0, 1);
  if (!boolValue(metric.has_metric)) {
    return { qualified: false, score, reason: "missing_close_loss_metric" };
  }
  const minScore = clamp(numberValue(config.close_loss_min_score, 0.8), 0, 1);
  if (score < minScore) {
    return { qualified: false, score, reason: cleanString(metric.reason) || "close_loss_score_too_low" };
  }
  return { qualified: true, score, reason: cleanString(metric.reason) || "qualified" };
}

function closeLossMetric(payload: JsonRecord, config: JsonRecord): JsonRecord {
  if (Object.prototype.hasOwnProperty.call(payload, "close_loss_score")) {
    return { has_metric: true, score: clamp(numberValue(payload.close_loss_score), 0, 1), reason: "explicit_score" };
  }
  if (Object.prototype.hasOwnProperty.call(payload, "close_loss_margin_ratio")) {
    return closeLossScoreFromMarginRatio(numberValue(payload.close_loss_margin_ratio, 1), config, "margin_ratio");
  }
  if (Object.prototype.hasOwnProperty.call(payload, "score_margin")) {
    const scoreTotal = Math.max(1, Math.abs(numberValue(payload.player_score)) + Math.abs(numberValue(payload.opponent_score)));
    return closeLossScoreFromMarginRatio(Math.abs(numberValue(payload.score_margin)) / scoreTotal, config, "score_margin");
  }
  if (Object.prototype.hasOwnProperty.call(payload, "player_score") && Object.prototype.hasOwnProperty.call(payload, "opponent_score")) {
    const playerScore = numberValue(payload.player_score);
    const opponentScore = numberValue(payload.opponent_score);
    const maxScore = Math.max(1, Math.abs(playerScore), Math.abs(opponentScore));
    return closeLossScoreFromMarginRatio(Math.abs(opponentScore - playerScore) / maxScore, config, "score_delta");
  }
  if (Object.prototype.hasOwnProperty.call(payload, "time_margin_ms")) {
    const elapsedMs = Math.max(1, numberValue(payload.elapsed_ms ?? payload.match_duration_ms));
    return closeLossScoreFromMarginRatio(Math.abs(numberValue(payload.time_margin_ms)) / elapsedMs, config, "time_margin");
  }
  if (Object.prototype.hasOwnProperty.call(payload, "objective_progress_ratio")) {
    return { has_metric: true, score: clamp(numberValue(payload.objective_progress_ratio), 0, 1), reason: "objective_progress" };
  }
  if (Object.prototype.hasOwnProperty.call(payload, "survival_ratio")) {
    return { has_metric: true, score: clamp(numberValue(payload.survival_ratio), 0, 1), reason: "survival_ratio" };
  }
  return { has_metric: false, score: 0, reason: "missing_close_loss_metric" };
}

function closeLossScoreFromMarginRatio(marginRatio: number, config: JsonRecord, reason: string): JsonRecord {
  const maxMargin = Math.max(0.001, numberValue(config.close_loss_max_margin_ratio, 0.10));
  const safeMargin = clamp(Math.abs(marginRatio), 0, 1);
  let score = 0;
  if (safeMargin <= maxMargin) {
    score = 1 - (safeMargin / maxMargin * 0.2);
  } else {
    score = Math.max(0, 0.8 - ((safeMargin - maxMargin) / maxMargin));
  }
  return { has_metric: true, score: clamp(score, 0, 1), reason };
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function applyRepeatedOpponentDiminishing(delta: number, repeatedCount: number, config: JsonRecord): JsonRecord {
  const zeroCount = Math.max(1, intValue(config.repeated_opponent_zero_count, 3));
  const softCount = Math.max(1, intValue(config.repeated_opponent_soft_count, 2));
  if (repeatedCount >= zeroCount) {
    return { delta: 0, reason: "repeated_opponent_zeroed" };
  }
  if (repeatedCount >= softCount && delta > 0) {
    return { delta: Math.floor(delta * 0.5), reason: "repeated_opponent_diminished" };
  }
  return { delta, reason: "" };
}

function evaluateAsyncPlacement(payload: JsonRecord, config: JsonRecord, breakdown: JsonRecord): JsonRecord {
  const placement = Math.max(1, intValue(payload.placement));
  const fieldSize = Math.max(1, intValue(payload.field_size, 1));
  const table = recordValue(config.async_placement_wax);
  let delta = intValue(table.middle);
  if (placement === 1) {
    delta = intValue(table.champion, 5);
  } else if (placement === 2) {
    delta = intValue(table.runner_up, 3);
  } else if (placement <= Math.max(1, Math.ceil(fieldSize * 0.25))) {
    delta = intValue(table.top_25, 1);
  } else if (placement > Math.floor(fieldSize * 0.75)) {
    delta = intValue(table.bottom_quartile, -1);
  }
  breakdown.base_wax_delta = delta;
  breakdown.final_wax_delta = delta;
  breakdown.final_wax_delta_millis = delta * WAX_MILLIS;
  return breakdown;
}

function evaluateTournament(payload: JsonRecord, config: JsonRecord, breakdown: JsonRecord): JsonRecord {
  const scope = cleanString(payload.contest_scope ?? payload.tournament_scope).toUpperCase();
  const placement = Math.max(1, intValue(payload.placement));
  const fieldSize = Math.max(1, intValue(payload.field_size, 1));
  let tableKey = "tournament_weekly_wax";
  if (scope === "MONTHLY") {
    tableKey = "tournament_monthly_wax";
  } else if (["SEASONAL", "YEARLY", "CHAMPIONSHIP"].includes(scope)) {
    tableKey = "tournament_seasonal_wax";
  }
  const table = recordValue(config[tableKey]);
  const percentile = placement / fieldSize;
  let delta = 0;
  if (placement === 1) {
    delta = intValue(table.champion);
  } else if (placement === 2) {
    delta = intValue(table.runner_up);
  } else if (tableKey === "tournament_seasonal_wax") {
    if (placement <= Math.max(1, Math.ceil(fieldSize * 0.01))) {
      delta = intValue(table.elite);
    } else if (placement <= 100) {
      delta = intValue(table.top_100);
    }
  } else if (percentile <= 0.05) {
    delta = intValue(table.top_5);
  } else if (percentile <= 0.10) {
    delta = intValue(table.top_10);
  } else if (percentile <= 0.25) {
    delta = intValue(table.top_25);
  }
  breakdown.base_wax_delta = delta;
  breakdown.final_wax_delta = delta;
  breakdown.final_wax_delta_millis = delta * WAX_MILLIS;
  return clone(breakdown);
}
