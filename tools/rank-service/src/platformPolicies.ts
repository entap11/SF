export type PolicyRecord = Record<string, unknown>;

type HoneySpec = {
  baseCenti: number;
  expectedSeconds: number;
  minSeconds: number;
  normalizeByTime: boolean;
  repeatable: boolean;
};

const HONEY: Record<string, HoneySpec> = {
  "community.challenge": spec(100, 300, 60, false, true),
  "community.featured_contribution": spec(200, 900, 0, false, false),
  "engagement.daily_login": spec(200, 60, 0, false, true),
  "engagement.daily_objectives": spec(200, 1200, 300, false, true),
  "engagement.weekly_objectives": spec(400, 5400, 1200, false, true),
  "engagement.weekly_all_modes": spec(400, 5400, 1200, false, true),
  "competitive.live_free": spec(400, 600, 180, true, true),
  "competitive.live_money": spec(600, 600, 180, true, true),
  "competitive.async_free": spec(400, 600, 180, true, true),
  "competitive.async_money": spec(600, 600, 180, true, true),
  "competitive.tournament_free": spec(400, 600, 180, true, true),
  "competitive.tournament_money": spec(600, 600, 180, true, true),
  "competitive.placement_weekly": spec(800, 0, 0, false, true),
  "competitive.placement_monthly": spec(1600, 0, 0, false, true),
  "competitive.placement_seasonal": spec(3200, 0, 0, false, true),
  "platform.purchase_bundle": spec(1600, 0, 0, false, false),
  "platform.warpath_purchase": spec(1600, 0, 0, false, false),
  "platform.referral_retained": spec(1600, 0, 0, false, false),
  "platform.cross_title_launch": spec(1600, 0, 0, false, false)
};

export type HoneyCatalogItem = {
  costCenti: number;
  entitlements: readonly string[];
};

const HONEY_CATALOG: Record<string, HoneyCatalogItem> = {
  "store_sku:skin_hive_obsidian": { costCenti: 35_000, entitlements: ["skin_hive_obsidian"] },
  "store_sku:skin_lane_goldpulse": { costCenti: 30_000, entitlements: ["skin_lane_goldpulse"] },
  "store_sku:skin_bg_circuit_forge": { costCenti: 28_000, entitlements: ["skin_bg_circuit_forge"] },
  "store_sku:analysis_forensic_replay": { costCenti: 60_000, entitlements: ["analysis_forensic"] },
  "store_sku:analysis_ai_commentary": { costCenti: 50_000, entitlements: ["analysis_ai"] },
  "beta.test": { costCenti: 100, entitlements: [] }
};

export function honeyCatalogItem(actionId: string): HoneyCatalogItem | null {
  return HONEY_CATALOG[actionId.trim().toLowerCase()] ?? null;
}

export function honeyCatalogCostCenti(actionId: string): number {
  return honeyCatalogItem(actionId)?.costCenti ?? 0;
}

function spec(baseCenti: number, expectedSeconds: number, minSeconds: number,
  normalizeByTime: boolean, repeatable: boolean): HoneySpec {
  return { baseCenti, expectedSeconds, minSeconds, normalizeByTime, repeatable };
}

export function opponentKey(raw: unknown): string {
  if (!Array.isArray(raw)) return "";
  return [...new Set(raw.map((value) => String(value ?? "").trim()).filter(Boolean))].sort().join("|");
}

export function evaluateHoneyFact(payload: PolicyRecord, repeatCount24h: number): PolicyRecord {
  const activityKey = text(payload.activity_key);
  const activity = HONEY[activityKey];
  if (!activity) return { ok: false, reason: "unknown_activity", amount_centi: 0, activity_key: activityKey };
  if (payload.completed === false || truthy(payload.early_quit)) {
    return { ok: false, reason: "not_meaningfully_completed", amount_centi: 0, activity_key: activityKey };
  }
  const duration = Math.max(0, integer(payload.duration_sec, activity.expectedSeconds));
  const effective = activity.expectedSeconds > 0 ? (duration || activity.expectedSeconds) : 0;
  if (activity.minSeconds > 0 && effective < activity.minSeconds) {
    return { ok: false, reason: "below_minimum_participation", amount_centi: 0, activity_key: activityKey };
  }
  let repeatBps = 10_000;
  if (activity.repeatable && opponentKey(payload.opponent_ids)) {
    repeatBps = repeatCount24h < 3 ? 10_000 : repeatCount24h < 6 ? 5_000 : 1_000;
  }
  let timeBps = 10_000;
  if (activity.normalizeByTime && activity.expectedSeconds > 0) {
    timeBps = Math.round(Math.min(1.25, Math.max(0.5, effective / activity.expectedSeconds)) * 10_000);
  }
  const multiplierBps = Math.trunc((repeatBps * timeBps) / 10_000);
  const amount = Math.max(0, Math.round((activity.baseCenti * multiplierBps) / 10_000));
  return {
    ok: amount > 0, reason: amount > 0 ? "awarded" : "zero_after_policy", amount_centi: amount,
    activity_key: activityKey, base_centi: activity.baseCenti, effective_seconds: effective,
    multiplier_bps: multiplierBps, repeat_count_24h: repeatCount24h,
    opponent_key: opponentKey(payload.opponent_ids), entap_title: text(payload.entap_title) || "unknown"
  };
}

const INELIGIBLE_MODES = new Set(["", "CRUCIBLE", "TUTORIAL", "PRACTICE", "CUSTOM", "PRIVATE"]);
const ASYNC_MODES = new Set(["ASYNC", "STAGE_RACE", "TIMED_RACE", "MISS_N_OUT", "WMS"]);
const TOURNAMENT_MODES = new Set(["TOURNAMENT", "WEEKLY", "MONTHLY", "SEASONAL", "YEARLY"]);

export function evaluateNectarMatchFact(payload: PolicyRecord, repeatCountToday: number, dailyEarnedMilli: number): PolicyRecord {
  const mode = text(payload.mode_id ?? payload.mode).toUpperCase();
  if (INELIGIBLE_MODES.has(mode) || truthy(payload.vs_crucible)
    || text(payload.ruleset ?? payload.vs_ruleset).toUpperCase() === "CRUCIBLE") {
    return { ok: false, reason: "ineligible_mode", base_nectar_milli: 0, mode_id: mode };
  }
  for (const flag of ["tutorial", "practice", "custom_match", "private_match", "no_contest", "refunded",
    "immediate_surrender", "early_quit", "afk", "insufficient_input", "insufficient_participation", "desync", "invalid_result"]) {
    if (truthy(payload[flag])) return { ok: false, reason: flag, base_nectar_milli: 0, mode_id: mode };
  }
  if (payload.completed === false) return { ok: false, reason: "match_not_completed", base_nectar_milli: 0, mode_id: mode };
  const duration = Math.max(0, number(payload.duration_sec, number(payload.match_duration_ms, 0) / 1000));
  if (duration < 30) return { ok: false, reason: duration <= 0 ? "match_duration_missing" : "match_too_short", base_nectar_milli: 0, mode_id: mode };
  const paid = truthy(payload.is_money_match ?? payload.paid_entry);
  const won = truthy(payload.did_win ?? payload.won);
  let completion = 10;
  let winBonus = 8;
  if (ASYNC_MODES.has(mode)) { completion = paid ? 10 : 8; winBonus = paid ? 8 : 6; }
  else if (TOURNAMENT_MODES.has(mode)) { completion = 12; winBonus = 10; }
  else if (paid) { completion = 12; winBonus = 10; }
  const baseXp = completion + (won ? winBonus : 0);
  let diminishBps = 10_000;
  const reasons: string[] = [];
  if (repeatCountToday > 3) {
    diminishBps = Math.min(diminishBps, Math.max(5_000, 10_000 - ((repeatCountToday - 3) * 1_500)));
    reasons.push("repeated_opponent");
  }
  if (dailyEarnedMilli >= 450_000) { diminishBps = Math.min(diminishBps, 5_000); reasons.push("daily_soft_cap"); }
  const diminishedMilli = Math.max(1_000, Math.round((baseXp * 1000 * diminishBps) / 10_000));
  return {
    ok: true, reason: diminishBps < 10_000 ? "diminished" : "awarded", mode_id: mode,
    completion_nectar: completion, win_bonus_nectar: won ? winBonus : 0,
    base_nectar_milli: baseXp * 1000, diminished_nectar_milli: diminishedMilli,
    diminish_multiplier_bps: diminishBps, diminish_reasons: reasons,
    opponent_key: opponentKey(payload.opponent_ids)
  };
}

export function passLevelForNectarMilli(nectarMilli: number): number {
  let xp = Math.max(0, Math.floor(nectarMilli / 1000));
  const bands = [
    { from: 1, to: 10, required: 50 }, { from: 11, to: 25, required: 65 },
    { from: 26, to: 50, required: 80 }, { from: 51, to: 75, required: 100 },
    { from: 76, to: 90, required: 125 }, { from: 91, to: 100, required: 220 },
    { from: 101, to: 110, required: 250 }, { from: 111, to: 120, required: 275 }
  ];
  let level = 1;
  for (const band of bands) {
    for (let cursor = band.from; cursor <= band.to && level < 120; cursor += 1) {
      if (xp < band.required) return level;
      xp -= band.required;
      level += 1;
    }
  }
  return Math.min(120, level);
}

function text(value: unknown): string { return String(value ?? "").trim(); }
function number(value: unknown, fallback: number): number {
  const parsed = Number(value); return Number.isFinite(parsed) ? parsed : fallback;
}
function integer(value: unknown, fallback: number): number { return Math.trunc(number(value, fallback)); }
function truthy(value: unknown): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  return ["1", "true", "yes", "on"].includes(text(value).toLowerCase());
}
