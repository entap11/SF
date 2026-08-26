export type JsonRecord = Record<string, unknown>;

export type HoneyActivityInput = {
  player_id: string;
  activity_key: string;
  entap_title?: string;
  completed?: boolean;
  early_quit?: boolean;
  duration_sec?: number;
  opponent_ids?: string[];
  occurred_unix?: number;
  metadata?: JsonRecord;
};

export type HoneyActivityHistoryEntry = {
  player_id: string;
  activity_key: string;
  opponent_key: string;
  occurred_unix: number;
  awarded_centi: number;
};

export type HoneyPolicyResult = {
  ok: boolean;
  amount_centi: number;
  activity_key: string;
  tier: string;
  reason?: string;
  base_centi: number;
  expected_seconds: number;
  effective_seconds: number;
  multiplier_bps: number;
  repeat_count_24h: number;
  opponent_key: string;
  entap_title: string;
};

type ActivitySpec = {
  tier: "community" | "engagement" | "competitive_participation" | "competitive_success" | "platform_growth";
  base_centi: number;
  expected_seconds: number;
  min_seconds: number;
  normalize_by_time: boolean;
  repeatable: boolean;
};

const DAY_SEC = 24 * 60 * 60;
const BASIS_POINTS_DENOMINATOR = 10_000;
const COMPETITIVE_HONEY_MIN_SECONDS = 2 * 60;

export const HONEY_REWARD_LADDER_CENTI = {
  community: 100,
  engagement: 200,
  competitive_participation: 400,
  competitive_success: 800,
  platform_growth: 1600
} as const;

const ACTIVITY_SPECS: Record<string, ActivitySpec> = {
  "community.challenge": spec("community", 5 * 60, 60, false, true),
  "community.featured_contribution": spec("engagement", 15 * 60, 0, false, false),
  "engagement.daily_login": spec("engagement", 60, 0, false, true),
  "engagement.daily_objectives": spec("engagement", 20 * 60, 5 * 60, false, true),
  "engagement.weekly_objectives": spec("competitive_participation", 90 * 60, 20 * 60, false, true),
  "engagement.weekly_all_modes": spec("competitive_participation", 90 * 60, 20 * 60, false, true),
  "competitive.live_free": spec("competitive_participation", 10 * 60, COMPETITIVE_HONEY_MIN_SECONDS, true, true),
  "competitive.live_money": customSpec("competitive_participation", 600, 10 * 60, COMPETITIVE_HONEY_MIN_SECONDS, true, true),
  "competitive.async_free": spec("competitive_participation", 10 * 60, COMPETITIVE_HONEY_MIN_SECONDS, true, true),
  "competitive.async_money": customSpec("competitive_participation", 600, 10 * 60, COMPETITIVE_HONEY_MIN_SECONDS, true, true),
  "competitive.tournament_free": spec("competitive_participation", 10 * 60, COMPETITIVE_HONEY_MIN_SECONDS, true, true),
  "competitive.tournament_money": customSpec("competitive_participation", 600, 10 * 60, COMPETITIVE_HONEY_MIN_SECONDS, true, true),
  "competitive.placement_weekly": spec("competitive_success", 0, 0, false, true),
  "competitive.placement_monthly": customSpec("competitive_success", 1600, 0, 0, false, true),
  "competitive.placement_seasonal": customSpec("competitive_success", 3200, 0, 0, false, true),
  "platform.purchase_bundle": spec("platform_growth", 0, 0, false, false),
  "platform.warpath_purchase": spec("platform_growth", 0, 0, false, false),
  "platform.referral_retained": spec("platform_growth", 0, 0, false, false),
  "platform.cross_title_launch": spec("platform_growth", 0, 0, false, false)
};

function spec(tier: ActivitySpec["tier"], expectedSeconds: number, minSeconds: number, normalizeByTime: boolean, repeatable: boolean): ActivitySpec {
  return customSpec(tier, HONEY_REWARD_LADDER_CENTI[tier], expectedSeconds, minSeconds, normalizeByTime, repeatable);
}

function customSpec(tier: ActivitySpec["tier"], baseCenti: number, expectedSeconds: number, minSeconds: number, normalizeByTime: boolean, repeatable: boolean): ActivitySpec {
  return {
    tier,
    base_centi: Math.max(0, Math.trunc(baseCenti)),
    expected_seconds: Math.max(0, Math.trunc(expectedSeconds)),
    min_seconds: Math.max(0, Math.trunc(minSeconds)),
    normalize_by_time: normalizeByTime,
    repeatable
  };
}

function cleanString(value: unknown): string {
  return String(value ?? "").trim();
}

function numberValue(value: unknown, fallback = 0): number {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
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

export function normalizeOpponentKey(opponentIds: unknown): string {
  if (!Array.isArray(opponentIds)) {
    return "";
  }
  return [...new Set(opponentIds.map(cleanString).filter(Boolean))].sort().join("|");
}

export function evaluateHoneyActivity(input: HoneyActivityInput, history: HoneyActivityHistoryEntry[] = [], nowUnix = Math.floor(Date.now() / 1000)): HoneyPolicyResult {
  const activityKey = cleanString(input.activity_key);
  const spec = ACTIVITY_SPECS[activityKey];
  const entapTitle = cleanString(input.entap_title) || "unknown";
  const opponentKey = normalizeOpponentKey(input.opponent_ids);
  if (!activityKey || spec == null) {
    return denied(activityKey, "unknown_activity", opponentKey, entapTitle);
  }
  const completed = boolValue(input.completed, true);
  const earlyQuit = boolValue(input.early_quit, false);
  if (!completed || earlyQuit) {
    return denied(activityKey, "not_meaningfully_completed", opponentKey, entapTitle, spec);
  }
  const rawSeconds = Math.max(0, Math.trunc(numberValue(input.duration_sec, spec.expected_seconds)));
  const effectiveSeconds = spec.expected_seconds > 0 ? (rawSeconds || spec.expected_seconds) : 0;
  if (spec.min_seconds > 0 && effectiveSeconds < spec.min_seconds) {
    return denied(activityKey, "below_minimum_participation", opponentKey, entapTitle, spec, effectiveSeconds);
  }
  const repeatCount = repeatCount24h(input, history, nowUnix, opponentKey);
  const repeatMultiplierBps = repeatMultiplier(spec, repeatCount, opponentKey);
  const timeMultiplierBps = timeMultiplier(spec, effectiveSeconds);
  const multiplierBps = Math.trunc((repeatMultiplierBps * timeMultiplierBps) / BASIS_POINTS_DENOMINATOR);
  const amount = Math.max(0, Math.round((spec.base_centi * multiplierBps) / BASIS_POINTS_DENOMINATOR));
  return {
    ok: amount > 0,
    amount_centi: amount,
    activity_key: activityKey,
    tier: spec.tier,
    reason: amount > 0 ? "awarded" : "zero_after_policy",
    base_centi: spec.base_centi,
    expected_seconds: spec.expected_seconds,
    effective_seconds: effectiveSeconds,
    multiplier_bps: multiplierBps,
    repeat_count_24h: repeatCount,
    opponent_key: opponentKey,
    entap_title: entapTitle
  };
}

export function honeyActivitySpecsSnapshot(): JsonRecord {
  return {
    precision: "centi_honey",
    ladder_centi: { ...HONEY_REWARD_LADDER_CENTI },
    activities: { ...ACTIVITY_SPECS },
    repeat_policy: {
      same_opponent_24h_full_reward_count: 3,
      same_opponent_24h_half_reward_count: 6,
      same_opponent_after_half_reward_bps: 1000
    },
    normalization_policy: {
      repeatable_timed_min_bps: 5000,
      repeatable_timed_max_bps: 12500
    }
  };
}

function denied(activityKey: string, reason: string, opponentKey: string, entapTitle: string, spec?: ActivitySpec, effectiveSeconds = 0): HoneyPolicyResult {
  return {
    ok: false,
    amount_centi: 0,
    activity_key: activityKey,
    tier: spec?.tier ?? "unknown",
    reason,
    base_centi: spec?.base_centi ?? 0,
    expected_seconds: spec?.expected_seconds ?? 0,
    effective_seconds: effectiveSeconds,
    multiplier_bps: 0,
    repeat_count_24h: 0,
    opponent_key: opponentKey,
    entap_title: entapTitle
  };
}

function repeatCount24h(input: HoneyActivityInput, history: HoneyActivityHistoryEntry[], nowUnix: number, opponentKey: string): number {
  if (!opponentKey) {
    return 0;
  }
  const playerId = cleanString(input.player_id);
  const activityKey = cleanString(input.activity_key);
  const since = nowUnix - DAY_SEC;
  return history.filter((entry) => (
    entry.player_id === playerId
    && entry.activity_key === activityKey
    && entry.opponent_key === opponentKey
    && entry.occurred_unix >= since
  )).length;
}

function repeatMultiplier(spec: ActivitySpec, repeatCount: number, opponentKey: string): number {
  if (!spec.repeatable || !opponentKey) {
    return BASIS_POINTS_DENOMINATOR;
  }
  if (repeatCount < 3) {
    return BASIS_POINTS_DENOMINATOR;
  }
  if (repeatCount < 6) {
    return 5000;
  }
  return 1000;
}

function timeMultiplier(spec: ActivitySpec, effectiveSeconds: number): number {
  if (!spec.normalize_by_time || spec.expected_seconds <= 0) {
    return BASIS_POINTS_DENOMINATOR;
  }
  const ratio = effectiveSeconds / spec.expected_seconds;
  const clamped = Math.min(1.25, Math.max(0.5, ratio));
  return Math.round(clamped * BASIS_POINTS_DENOMINATOR);
}
