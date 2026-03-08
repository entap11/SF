import "dotenv/config";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { RankServiceConfig } from "./types.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DEFAULT_LEGACY_STATE_PATH = path.resolve(__dirname, "../var/rank_state.json");

function parseIntValue(value: string | undefined, fallback: number): number {
  if (!value || value.trim() === "") {
    return fallback;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseFloatValue(value: string | undefined, fallback: number): number {
  if (!value || value.trim() === "") {
    return fallback;
  }
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value == null) {
    return fallback;
  }
  const normalized = value.trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) {
    return true;
  }
  if (["0", "false", "no", "off"].includes(normalized)) {
    return false;
  }
  return fallback;
}

const tierBands = [
  { id: "DRONE", name: "Drone", min_pct: 0.0, max_pct: 0.2 },
  { id: "WORKER", name: "Worker", min_pct: 0.2, max_pct: 0.35 },
  { id: "SOLDIER", name: "Soldier", min_pct: 0.35, max_pct: 0.5 },
  { id: "HONEY_BEE", name: "Honey Bee", min_pct: 0.5, max_pct: 0.65 },
  { id: "BUMBLEBEE", name: "Bumblebee", min_pct: 0.65, max_pct: 0.8 },
  { id: "QUEEN", name: "Queen", min_pct: 0.8, max_pct: 0.9 },
  { id: "YELLOWJACKET", name: "Yellowjacket", min_pct: 0.9, max_pct: 0.94 },
  { id: "RED_WASP", name: "Red Wasp", min_pct: 0.94, max_pct: 0.965 },
  { id: "HORNET", name: "Hornet", min_pct: 0.965, max_pct: 0.98 },
  { id: "BALD_FACED_HORNET", name: "Bald-Faced Hornet", min_pct: 0.98, max_pct: 0.989 },
  { id: "KILLER_BEE", name: "Killer Bee", min_pct: 0.989, max_pct: 0.995 },
  { id: "ASIAN_GIANT_HORNET", name: "Asian Giant Hornet (Murder Hornet)", min_pct: 0.995, max_pct: 0.998 },
  { id: "EXECUTIONER_WASP", name: "Executioner Wasp", min_pct: 0.998, max_pct: 0.999 },
  { id: "SCORPION_WASP", name: "Scorpion Wasp", min_pct: 0.999, max_pct: 1.0 },
  { id: "COW_KILLER", name: "Cow Killer", min_pct: 1.0, max_pct: 1.0 }
];

export const config: RankServiceConfig = {
  port: parseIntValue(process.env.PORT, 8790),
  bindHost: process.env.BIND_HOST?.trim() || "127.0.0.1",
  apiToken: process.env.RANK_API_TOKEN?.trim() || "",
  databaseUrl: process.env.DATABASE_URL?.trim() || "",
  legacyStatePath: process.env.RANK_STATE_PATH?.trim()
    ? path.resolve(process.cwd(), process.env.RANK_STATE_PATH.trim())
    : DEFAULT_LEGACY_STATE_PATH,
  enforceCanonicalPlayerIds: parseBoolean(process.env.RANK_ENFORCE_CANONICAL_PLAYER_IDS, true),
  allowDebugActions: parseBoolean(process.env.RANK_ENABLE_DEBUG_ACTIONS, false),
  rank: {
    baseGain: parseFloatValue(process.env.RANK_BASE_GAIN, 100.0),
    opponentStrengthExponent: parseFloatValue(process.env.RANK_OPPONENT_STRENGTH_EXPONENT, 0.6),
    opponentStrengthMin: parseFloatValue(process.env.RANK_OPPONENT_STRENGTH_MIN, 0.6),
    opponentStrengthMax: parseFloatValue(process.env.RANK_OPPONENT_STRENGTH_MAX, 1.6),
    lossesSubtractWax: parseBoolean(process.env.RANK_LOSSES_SUBTRACT_WAX, true),
    lossScale: parseFloatValue(process.env.RANK_LOSS_SCALE, 0.55),
    freePvpWinWax: parseFloatValue(process.env.RANK_FREE_PVP_WIN_WAX, 10.0),
    freePvpLossWax: parseFloatValue(process.env.RANK_FREE_PVP_LOSS_WAX, 4.0),
    moneyPvpTier1WinWax: parseFloatValue(process.env.RANK_MONEY_PVP_TIER_1_WIN_WAX, 12.0),
    moneyPvpTier1LossWax: parseFloatValue(process.env.RANK_MONEY_PVP_TIER_1_LOSS_WAX, 5.0),
    moneyPvpTier2WinWax: parseFloatValue(process.env.RANK_MONEY_PVP_TIER_2_WIN_WAX, 16.0),
    moneyPvpTier2LossWax: parseFloatValue(process.env.RANK_MONEY_PVP_TIER_2_LOSS_WAX, 7.0),
    moneyPvpTier3WinWax: parseFloatValue(process.env.RANK_MONEY_PVP_TIER_3_WIN_WAX, 20.0),
    moneyPvpTier3LossWax: parseFloatValue(process.env.RANK_MONEY_PVP_TIER_3_LOSS_WAX, 9.0),
    smallContestFirstWax: parseFloatValue(process.env.RANK_SMALL_CONTEST_FIRST_WAX, 3.0),
    smallContestSecondWax: parseFloatValue(process.env.RANK_SMALL_CONTEST_SECOND_WAX, 1.0),
    smallContestThirdWax: parseFloatValue(process.env.RANK_SMALL_CONTEST_THIRD_WAX, 0.0),
    dailyContestFirstWax: parseFloatValue(process.env.RANK_DAILY_CONTEST_FIRST_WAX, 5.0),
    dailyContestSecondWax: parseFloatValue(process.env.RANK_DAILY_CONTEST_SECOND_WAX, 2.0),
    dailyContestThirdWax: parseFloatValue(process.env.RANK_DAILY_CONTEST_THIRD_WAX, 1.0),
    weeklyContestFirstWax: parseFloatValue(process.env.RANK_WEEKLY_CONTEST_FIRST_WAX, 10.0),
    weeklyContestSecondWax: parseFloatValue(process.env.RANK_WEEKLY_CONTEST_SECOND_WAX, 5.0),
    weeklyContestThirdWax: parseFloatValue(process.env.RANK_WEEKLY_CONTEST_THIRD_WAX, 2.0),
    monthlyContestFirstWax: parseFloatValue(process.env.RANK_MONTHLY_CONTEST_FIRST_WAX, 20.0),
    monthlyContestSecondWax: parseFloatValue(process.env.RANK_MONTHLY_CONTEST_SECOND_WAX, 10.0),
    monthlyContestThirdWax: parseFloatValue(process.env.RANK_MONTHLY_CONTEST_THIRD_WAX, 5.0),
    modeModifiers: {
      STANDARD: 1.0,
      TOURNAMENT: 1.5,
      MONEY_MATCH: 2.0,
      STEROIDS_LEAGUE: 3.0
    },
    inactivityGraceDays: parseIntValue(process.env.RANK_INACTIVITY_GRACE_DAYS, 14),
    dailyDecayRate: parseFloatValue(process.env.RANK_DAILY_DECAY_RATE, 0.0075),
    waxFloor: parseFloatValue(process.env.RANK_WAX_FLOOR, 100.0),
    playersPerTierToUnlock: parseIntValue(process.env.RANK_PLAYERS_PER_TIER_TO_UNLOCK, 300),
    fullOpenTopTierWeight: parseFloatValue(process.env.RANK_FULL_OPEN_TOP_TIER_WEIGHT, 1.0),
    fullOpenMiddleWeightMultiplierVsTop: parseFloatValue(process.env.RANK_FULL_OPEN_MIDDLE_WEIGHT_MULTIPLIER, 1.25),
    fullOpenBottomWeightMultiplierVsMiddle: parseFloatValue(process.env.RANK_FULL_OPEN_BOTTOM_WEIGHT_MULTIPLIER, 1.0),
    tierBands,
    apexTopCount: parseIntValue(process.env.RANK_APEX_TOP_COUNT, 5),
    promotionBuffer: parseFloatValue(process.env.RANK_PROMOTION_BUFFER, 0.005),
    colorBuffer: parseFloatValue(process.env.RANK_COLOR_BUFFER, 0.002),
    tierDemotionGraceSlots: parseIntValue(process.env.RANK_TIER_DEMOTION_GRACE_SLOTS, 5),
    colorQuintiles: ["GREEN", "BLUE", "RED", "BLACK", "YELLOW"],
    mmBaseWaxTolerance: parseFloatValue(process.env.RANK_MM_BASE_WAX_TOLERANCE, 120.0),
    mmWaxTolerancePerSec: parseFloatValue(process.env.RANK_MM_WAX_TOLERANCE_PER_SEC, 4.0),
    mmMaxWaxTolerance: parseFloatValue(process.env.RANK_MM_MAX_WAX_TOLERANCE, 800.0),
    defaultRegion: process.env.RANK_DEFAULT_REGION?.trim().toUpperCase() || "GLOBAL"
  }
};

if (!config.databaseUrl) {
  throw new Error("DATABASE_URL is required");
}
