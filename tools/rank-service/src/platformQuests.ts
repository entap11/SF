import { sha256Canonical } from "./verifiedReceipt.js";

export type QuestObjective = {
  id: string;
  target: number;
  mode_ids?: readonly string[];
  paid_entry?: boolean;
  did_win?: boolean;
  label?: string;
  families?: readonly string[];
  map_counts?: readonly number[];
  scopes?: readonly string[];
};

export type QuestDefinition = {
  id: string;
  version: number;
  title: string;
  cadence: "DAILY" | "WEEKLY";
  starts_at: string;
  ends_at: string;
  objectives: readonly QuestObjective[];
  reward: { honey_centi: number; nectar_milli: number };
};

// Default-off catalog. The approved v1 is injected only through explicit server configuration.
// Only trusted server configuration supplies definitions; never a player request.
export const PLATFORM_QUESTS: readonly QuestDefinition[] = [];

const DAY_MS = 86_400_000;
const ID = /^[a-z][a-z0-9_]{0,63}$/;

export function validateQuestCatalog(input: readonly QuestDefinition[]): readonly QuestDefinition[] {
  const catalog: QuestDefinition[] = JSON.parse(JSON.stringify(input));
  const ids = new Set<string>();
  for (const quest of catalog) {
    const amounts = [quest.reward?.honey_centi, quest.reward?.nectar_milli];
    if (!onlyKeys(quest, ["id", "version", "title", "cadence", "starts_at", "ends_at", "objectives", "reward"])
      || !onlyKeys(quest.reward, ["honey_centi", "nectar_milli"])
      || !ID.test(quest.id) || ids.has(quest.id) || !Number.isSafeInteger(quest.version) || quest.version < 1
      || !quest.title?.trim() || !["DAILY", "WEEKLY"].includes(quest.cadence)
      || !Number.isFinite(Date.parse(quest.starts_at)) || !Number.isFinite(Date.parse(quest.ends_at))
      || Date.parse(quest.ends_at) <= Date.parse(quest.starts_at)
      || !Array.isArray(quest.objectives) || quest.objectives.length < 1 || quest.objectives.length > 16
      || amounts.some((value) => !Number.isSafeInteger(value) || value < 0)
      || !amounts.some((value) => value > 0)) throw new Error("invalid_quest_definition");
    ids.add(quest.id);
    const objectives = new Set<string>();
    for (const objective of quest.objectives) {
      if (!onlyKeys(objective, ["id", "target", "mode_ids", "paid_entry", "did_win", "label", "families", "map_counts", "scopes"])
        || !ID.test(objective.id) || objectives.has(objective.id)
        || !Number.isSafeInteger(objective.target) || objective.target < 1
        || (objective.mode_ids !== undefined && (!Array.isArray(objective.mode_ids)
          || !objective.mode_ids.length || objective.mode_ids.some((mode: string) => !/^[A-Z0-9_]{1,64}$/.test(mode))))
        || (objective.paid_entry !== undefined && typeof objective.paid_entry !== "boolean")
        || (objective.did_win !== undefined && typeof objective.did_win !== "boolean")) {
        throw new Error("invalid_quest_objective");
      }
      for (const key of ["families", "scopes"] as const) {
        const values = objective[key];
        if (values !== undefined && (!Array.isArray(values) || !values.length
          || values.some((value: string) => !/^[A-Z0-9_]{1,64}$/.test(value)))) throw new Error("invalid_quest_filter");
        if (values) Object.freeze(values);
      }
      if (objective.map_counts !== undefined && (!Array.isArray(objective.map_counts)
        || !objective.map_counts.length || objective.map_counts.some((n: number) => !Number.isSafeInteger(n) || n < 1))) {
        throw new Error("invalid_quest_filter");
      }
      if (objective.map_counts) Object.freeze(objective.map_counts);
      objectives.add(objective.id);
      if (objective.mode_ids) Object.freeze(objective.mode_ids);
      Object.freeze(objective);
    }
    Object.freeze(quest.objectives);
    Object.freeze(quest.reward);
    Object.freeze(quest);
  }
  return Object.freeze(catalog);
}

function onlyKeys(value: unknown, keys: readonly string[]): boolean {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    && Object.keys(value).every((key) => keys.includes(key));
}

export function questCycle(quest: QuestDefinition, at: string): { start: string; end: string } {
  const date = new Date(at);
  let start = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
  if (quest.cadence === "WEEKLY") start -= ((date.getUTCDay() + 6) % 7) * DAY_MS;
  return { start: new Date(start).toISOString(),
    end: new Date(Math.min(start + DAY_MS * (quest.cadence === "WEEKLY" ? 7 : 1), Date.parse(quest.ends_at))).toISOString() };
}

export function questActive(quest: QuestDefinition, at: string): boolean {
  return Date.parse(at) >= Date.parse(quest.starts_at) && Date.parse(at) < Date.parse(quest.ends_at);
}

export function questDefinitionHash(quest: QuestDefinition): string { return sha256Canonical(quest); }

export function advanceQuest(quest: QuestDefinition, progress: Record<string, number>,
  fact: Record<string, unknown>): Record<string, number> {
  const next = { ...progress };
  const paid = fact.is_money_match === true || fact.paid_entry === true;
  const won = fact.did_win === true || fact.won === true;
  for (const objective of quest.objectives) {
    if (objective.families && !objective.families.includes(String(fact.family))) continue;
    if (objective.scopes && !objective.scopes.includes(String(fact.scope))) continue;
    if (objective.map_counts && !objective.map_counts.includes(Number(fact.map_count))) continue;
    if (objective.mode_ids && !objective.mode_ids.includes(String(fact.mode_id).toUpperCase())) continue;
    if (objective.paid_entry !== undefined && objective.paid_entry !== paid) continue;
    if (objective.did_win !== undefined && objective.did_win !== won) continue;
    next[objective.id] = Math.min(objective.target, (next[objective.id] ?? 0) + 1);
  }
  return next;
}

export function questComplete(quest: QuestDefinition, progress: Record<string, number>): boolean {
  return quest.objectives.every((objective) => (progress[objective.id] ?? 0) >= objective.target);
}
