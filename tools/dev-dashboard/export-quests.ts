import {
  buildQuestCatalog,
  weeklyAssignments,
  QUEST_CATALOG_VERSION,
  QUEST_BONUS_BPS,
} from "../rank-service/src/platformQuestCatalog.ts";
const quests = buildQuestCatalog("2026-09-28T00:00:00.000Z");
const weeks = Array.from({ length: 9 }, (_, i) => {
  const start = new Date(
    Date.parse("2026-09-28T00:00:00Z") + i * 7 * 86400000,
  ).toISOString();
  return weeklyAssignments(quests, start).map((a) => ({
    quest_id: a.definition.id,
    start: a.start,
    end: a.end,
  }));
});
console.log(
  JSON.stringify({
    quests,
    weeks,
    version: QUEST_CATALOG_VERSION,
    bonus_bps: QUEST_BONUS_BPS,
  }),
);
