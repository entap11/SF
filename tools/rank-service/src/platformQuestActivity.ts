import { LIVE_QUEST_MODES } from "./platformQuestCatalog.js";
import type { JsonRecord } from "./platformEconomy.js";

export function eligibleQuestActivity(fact: JsonRecord): boolean {
  if (fact.completed !== true || !Number.isFinite(fact.duration_sec) || Number(fact.duration_sec) < 30) return false;
  if (["early_quit", "afk", "no_contest", "invalid_result", "private_match", "practice", "refunded", "abandoned"]
    .some((flag) => fact[flag] === true)) return false;
  if (fact.family === "LIVE") {
    return LIVE_QUEST_MODES.includes(String(fact.mode_id))
      && ["OBJECTIVE_COMPLETE", "CONQUEST", "TIME_LIMIT", "FLAG_CAPTURE", "ELIMINATION", "FORFEIT"].includes(String(fact.terminal_reason));
  }
  if (fact.family === "GAUNTLET") return fact.natural_finish === true;
  if (fact.family !== "ASYNC_MAP_SET" && fact.family !== "TIME_PUZZLE") return false;
  if (![3, 5].includes(Number(fact.map_count)) || fact.completed_maps !== fact.map_count) return false;
  return fact.family === "ASYNC_MAP_SET" ? fact.scope === "ROLLING_COHORT"
    : ["DAILY", "WEEKLY", "MONTHLY", "SEASONAL"].includes(String(fact.scope));
}
