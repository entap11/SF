import { validateQuestCatalog, type QuestDefinition, type QuestObjective } from "./platformQuests.js";

export const QUEST_CATALOG_VERSION = "quests_v1";
export const LIVE_QUEST_MODES = ["STANDARD_1V1", "STANDARD_2V2", "STANDARD_3P_FFA", "STANDARD_4P_FFA", "CTF_1V1"];
export const QUEST_BONUS_BPS = 1000;
const duel = (n: number) => live("duel", n, "Standard 1v1 games", ["STANDARD_1V1"]);
const team = (n: number) => live("team", n, "2v2 games", ["STANDARD_2V2"]);
const ffa = (n: number) => live("ffa", n, "FFA games", ["STANDARD_3P_FFA", "STANDARD_4P_FFA"]);
const ctf = (n: number) => live("ctf", n, "CTF games", ["CTF_1V1"]);
const pvp = (n: number) => live("pvp", n, "PvP games", LIVE_QUEST_MODES);
function live(id: string, target: number, label: string, mode_ids: string[]): QuestObjective {
  return { id, target, label, mode_ids, families: ["LIVE"] };
}
function asyncRun(target: number, maps?: number): QuestObjective {
  return { id: maps ? `async${maps}` : "async", target,
    label: maps ? `${maps}-map async runs` : "Async runs", families: ["ASYNC_MAP_SET"],
    map_counts: maps ? [maps] : [3, 5] };
}

// Approved requirements. Rewards are provisional local-test tuning, not a rollout.
export function buildQuestCatalog(startsAt: string, endsAt = "2099-01-01T00:00:00.000Z"): readonly QuestDefinition[] {
  const definitions: QuestDefinition[] = [];
  const add = (id: string, title: string, objectives: QuestObjective[], cadence: "DAILY" | "WEEKLY" = "DAILY") => {
    definitions.push({ id, version: 1, title, cadence, starts_at: startsAt, ends_at: endsAt, objectives,
      reward: cadence === "DAILY" ? { honey_centi: 200, nectar_milli: 40_000 }
        : { honey_centi: 800, nectar_milli: 200_000 } });
  };
  add("daily_on_the_field", "On the Field", [duel(3), team(2), ffa(1)]);
  add("daily_full_session", "Full Session", [duel(2), team(2), ffa(2), ctf(2)]);
  add("daily_duel_duty", "Duel Duty", [duel(4), ctf(2)]);
  add("daily_team_player", "Team Player", [team(3), ffa(2)]);
  add("daily_open_field", "Open Field", [ffa(3), duel(2)]);
  add("daily_flag_duty", "Flag Duty", [ctf(3), team(2)]);
  add("daily_your_own_pace", "Your Own Pace", [asyncRun(3), asyncRun(1, 3), asyncRun(1, 5), ctf(1)]);
  add("daily_short_circuit", "Short Circuit", [asyncRun(2, 3), ffa(1)]);
  add("daily_long_route", "Long Route", [asyncRun(2, 5), pvp(2)]);
  add("daily_two_routes", "Two Routes", [asyncRun(1, 3), asyncRun(1, 5), duel(2)]);
  add("daily_three_laps", "Three Laps", [asyncRun(3, 3), team(1)]);
  add("daily_distance_runner", "Distance Runner", [asyncRun(2, 5), ctf(2)]);
  add("daily_change_of_pace", "Change of Pace", [pvp(4), asyncRun(1)]);
  add("daily_quick_mix", "Quick Mix", [pvp(2), asyncRun(1, 3)]);
  add("daily_long_mix", "Long Mix", [pvp(2), asyncRun(1, 5)]);
  add("daily_duel_and_dash", "Duel and Dash", [duel(2), asyncRun(1, 3)]);
  add("daily_duel_and_distance", "Duel and Distance", [duel(2), asyncRun(1, 5)]);
  add("daily_team_and_trail", "Team and Trail", [team(2), asyncRun(1, 3)]);
  add("daily_free_for_a_run", "Free-for-a-Run", [ffa(2), asyncRun(1, 3)]);
  add("daily_flags_and_laps", "Flags and Laps", [ctf(2), asyncRun(1, 3)]);
  add("daily_solo_squad_sprint", "Solo, Squad, Sprint", [duel(1), team(1), asyncRun(1, 3)]);
  add("daily_duel_brawl_sprint", "Duel, Brawl, Sprint", [duel(1), ffa(1), asyncRun(1, 3)]);
  add("daily_duel_flag_sprint", "Duel, Flag, Sprint", [duel(1), ctf(1), asyncRun(1, 3)]);
  add("daily_squad_brawl_sprint", "Squad, Brawl, Sprint", [team(1), ffa(1), asyncRun(1, 3)]);
  add("weekly_across_the_front", "Across the Front", [duel(12), ffa(8), asyncRun(4, 3)], "WEEKLY");
  add("weekly_team_and_tactics", "Team and Tactics", [team(10), ctf(6), asyncRun(2, 5)], "WEEKLY");
  add("weekly_async_expedition", "Async Expedition", [asyncRun(6, 3), asyncRun(3, 5), duel(6), team(6)], "WEEKLY");
  add("weekly_free_roll_tour", "Free Roll Tour", [
    { id: "free_roll", target: 1, label: "3-map Free Roll", families: ["TIME_PUZZLE"], map_counts: [3],
      scopes: ["DAILY", "WEEKLY", "MONTHLY", "SEASONAL"] },
    // Two distinct entries overall AND one Free Roll: one result alone cannot satisfy both entries.
    { id: "three_map_entries", target: 2, label: "3-map entries (including the Free Roll)",
      families: ["TIME_PUZZLE", "ASYNC_MAP_SET"], map_counts: [3],
      scopes: ["ROLLING_COHORT", "DAILY", "WEEKLY", "MONTHLY", "SEASONAL"] },
    { id: "gauntlet", target: 2, label: "Gauntlet runs", families: ["GAUNTLET"] }, pvp(4)
  ], "WEEKLY");
  return validateQuestCatalog(definitions);
}

// Curated overlapping bundles. Rolling the start across weeks eventually exposes all 24 entries.
export const DAILY_BUNDLES = [[1,13,16], [6,18,20], [5,19,22], [4,14,21], [3,15,17],
  [7,10,23], [8,11,24], [2,14,21], [9,12,17]] as const;
export function weeklyAssignments(catalog: readonly QuestDefinition[], weekStart: string):
  Array<{ definition: QuestDefinition; start: string; end: string }> {
  const start = Date.parse(weekStart);
  const reference = Date.parse("2026-09-28T00:00:00Z");
  const weekIndex = Math.floor((start - reference) / (7 * 86400000));
  const offset = ((weekIndex * 7) % DAILY_BUNDLES.length + DAILY_BUNDLES.length) % DAILY_BUNDLES.length;
  const daily = catalog.filter((quest) => quest.cadence === "DAILY");
  const result: Array<{ definition: QuestDefinition; start: string; end: string }> = [];
  for (let day = 0; day < 7; day += 1) {
    for (const index of DAILY_BUNDLES[(offset + day) % DAILY_BUNDLES.length]) {
      const definition = daily[index - 1];
      if (!definition) throw new Error("quest_catalog_assignment_missing");
      result.push({ definition, start: new Date(start + day * 86400000).toISOString(),
        end: new Date(start + (day + 1) * 86400000).toISOString() });
    }
  }
  for (const definition of catalog.filter((quest) => quest.cadence === "WEEKLY")) {
    result.push({ definition, start: weekStart, end: new Date(start + 7 * 86400000).toISOString() });
  }
  return result;
}
