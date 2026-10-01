import assert from "node:assert/strict";
import type { Pool } from "pg";
import { buildQuestCatalog, weeklyAssignments } from "./platformQuestCatalog.js";
import { PlatformEconomyRepository, type JsonRecord, type ProducerEnvelope } from "./platformEconomy.js";

export async function runQuestCatalogSmoke(pool: Pool, player: string, other: string, epochId: string): Promise<void> {
  const start = Date.parse("2026-11-02T00:00:00Z");
  const catalog = buildQuestCatalog(new Date(start).toISOString());
  assert.equal(catalog.length, 28);
  const seen = new Set<string>();
  for (let week = 0; week < 9; week++) {
    const assignments = weeklyAssignments(catalog, new Date(start + week * 7 * 86400000).toISOString());
    assert.equal(assignments.length, 25);
    assignments.filter((a) => a.definition.cadence === "DAILY").forEach((a) => seen.add(a.definition.id));
  }
  assert.equal(seen.size, 24);
  let now = new Date(start + 3600000);
  let economy = new PlatformEconomyRepository(pool, catalog, () => now, true);
  let sequence = 0;
  function fact(patch: JsonRecord = {}, playerId = player): ProducerEnvelope {
    sequence++;
    return { producerService: "quest-catalog-smoke", producerEventId: `quest-fact-${sequence}`, epochId,
      eventType: "QUEST_ACTIVITY_V1", sourceAuthority: "verified-test", occurredAt: now.toISOString(), schemaVersion: 1,
      payload: { player_id: playerId, subject_id: `018f0000-0000-7000-8000-${String(100000 + sequence).padStart(12, "0")}`,
        family: "LIVE", mode_id: "STANDARD_1V1", completed: true, duration_sec: 120,
        terminal_reason: "OBJECTIVE_COMPLETE", ...patch } };
  }
  const snapshot = () => economy.getPlayerQuests(player);
  const quests = async () => (await snapshot()).quests as JsonRecord[];
  const tour = async () => (await quests()).find((q) => q.quest_id === "weekly_free_roll_tour")!;
  const progress = async (id: string) => ((await tour()).objectives as JsonRecord[]).find((o) => o.id === id)!.progress;
  const claim = (q: JsonRecord, who = player) => economy.claimQuest({ playerId: who, epochId, questId: String(q.quest_id),
    cycleStart: String(q.cycle_start), requestId: `catalog-${who}-${q.quest_id}-${q.cycle_start}` });
  assert.equal((await quests()).length, 7);
  assert.equal((await pool.query("SELECT count(*)::int AS n FROM platform_quest_progress WHERE player_id=$1 AND week_start=$2", [player,new Date(start).toISOString()])).rows[0].n,25);
  const initial = await snapshot();
  for (const patch of [{ early_quit: true }, { completed: false }, { duration_sec: 29 }, { afk: true },
    { practice: true }, { private_match: true }, { no_contest: true }, { mode_id: "CRUCIBLE_1V1" },
    { family: "GAUNTLET", natural_finish: false },
    { family: "ASYNC_MAP_SET", scope: "ROLLING_COHORT", map_count: 3, completed_maps: 2 }]) {
    assert.equal((await economy.recordQuestActivity(fact(patch))).counted, false);
  }
  assert.deepEqual(await snapshot(), initial);
  const free = fact({ family: "TIME_PUZZLE", scope: "WEEKLY", map_count: 3, completed_maps: 3 });
  await economy.recordQuestActivity(free);
  assert.equal((await economy.recordQuestActivity(free)).duplicate, true);
  assert.equal((await economy.recordQuestActivity({ ...free, producerEventId: "other-transport-id" })).counted, false);
  await assert.rejects(() => economy.recordQuestActivity({ ...free, producerEventId: "altered-fact", payload: { ...free.payload, map_count: 5, completed_maps: 5 } }), /quest_fact_conflict/);
  assert.equal(await progress("free_roll"), 1);
  assert.equal(await progress("three_map_entries"), 1, "Free Roll alone does not satisfy the extra entry");
  const async3 = { family: "ASYNC_MAP_SET", scope: "ROLLING_COHORT", map_count: 3, completed_maps: 3 };
  await economy.recordQuestActivity(fact(async3));
  assert.equal(await progress("three_map_entries"), 2);
  const gauntlet = fact({ family: "GAUNTLET", natural_finish: true });
  await economy.recordQuestActivity(gauntlet);
  await economy.recordQuestActivity({ ...gauntlet, producerEventId: "gauntlet-retry" });
  assert.equal(await progress("gauntlet"), 1);
  await economy.recordQuestActivity(fact({ family: "GAUNTLET", natural_finish: true }));
  assert.equal(await progress("gauntlet"), 2);
  await assert.rejects(() => economy.recordQuestActivity({ ...fact(), occurredAt: new Date(now.getTime()+1).toISOString() }), /quest_future_fact/);
  await assert.rejects(() => economy.recordQuestActivity({ ...fact(), epochId: "legacy-pre-platform" }), /old_or_inactive_epoch/);
  // A restart with changed tuning retains all 25 frozen assignments, even tomorrow's.
  economy = new PlatformEconomyRepository(pool, catalog.map((q) => ({ ...q, reward: { honey_centi: 999999, nectar_milli: 1 } })), () => now, true);
  assert.deepEqual((await quests())[0].reward, { honey_centi: 200, nectar_milli: 40000 });
  economy = new PlatformEconomyRepository(pool, catalog, () => now, true);
  const before = await economy.getPlayerBalances(player);
  let claims = 0;
  let bonusTotal = 0;
  let firstDaily: JsonRecord | undefined;
  // Nine simulated weeks cover the complete rotation, periodic restarts, retries and exact ledger totals.
  for (let week = 0; week < 9; week++) {
    for (let day = 0; day < 7; day++) {
      now = new Date(start + (week * 7 + day) * 86400000 + 3600000);
      for (const mode of ["STANDARD_1V1", "STANDARD_2V2", "STANDARD_3P_FFA", "CTF_1V1"]) {
        for (let n = 0; n < 4; n++) await economy.recordQuestActivity(fact({ mode_id: mode }));
      }
      for (const maps of [3, 5]) for (let n = 0; n < 3; n++) {
        const event = fact({ ...async3, map_count: maps, completed_maps: maps });
        await economy.recordQuestActivity(event);
        assert.equal((await economy.recordQuestActivity(event)).duplicate, true);
      }
      if (day === 0) {
        await economy.recordQuestActivity(fact({ family: "TIME_PUZZLE", scope: "MONTHLY", map_count: 3, completed_maps: 3 }));
        for (let n = 0; n < 2; n++) await economy.recordQuestActivity(fact({ family: "GAUNTLET", natural_finish: true }));
      }
      const ready = (await quests()).filter((q) => q.ready_to_claim);
      assert.equal(ready.filter((q) => q.cadence === "DAILY").length, 3);
      for (const q of ready) {
        if (!firstDaily && q.cadence === "DAILY") firstDaily = q;
        if (claims === 24) {
          const balances = await economy.getPlayerBalances(player);
          await pool.query(`CREATE FUNCTION quest_bonus_fail() RETURNS trigger AS $$
            BEGIN RAISE EXCEPTION 'quest_bonus_rollback'; END; $$ LANGUAGE plpgsql;
            CREATE TRIGGER quest_bonus_fail_trigger BEFORE UPDATE ON platform_quest_weeks
            FOR EACH ROW EXECUTE FUNCTION quest_bonus_fail()`);
          await assert.rejects(() => claim(q), /quest_bonus_rollback/);
          await pool.query("DROP TRIGGER quest_bonus_fail_trigger ON platform_quest_weeks; DROP FUNCTION quest_bonus_fail()");
          assert.deepEqual(await economy.getPlayerBalances(player), balances);
          assert.equal(((await snapshot()).weekly_bonus as JsonRecord).claimed_count, 24);
        }
        const receipt = await claim(q);
        claims++;
        bonusTotal += Number(receipt.weekly_bonus_honey_centi);
        const retry = await claim(q);
        assert.equal(retry.transaction_id, receipt.transaction_id);
        assert.equal(retry.duplicate, true);
        if (Number(receipt.weekly_bonus_honey_centi) > 0) assert.equal(claims % 25, 0);
      }
      const bonus = (await snapshot()).weekly_bonus as JsonRecord;
      assert.equal(bonus.awarded, day === 6);
      if (day === 6) assert.equal(bonus.awarded_honey_centi, 740);
      economy = new PlatformEconomyRepository(pool, catalog, () => now, true);
    }
  }
  assert.equal(claims, 225);
  assert.equal(bonusTotal, 6660);
  const after = await economy.getPlayerBalances(player);
  assert.equal(Number(after.honey_centi)-Number(before.honey_centi), 9*8140);
  assert.equal(Number(after.nectar_milli)-Number(before.nectar_milli), 9*1640000);
  // A second player arrives on Sunday; unseen days still belong to their full-week manifest.
  for (const mode of ["STANDARD_1V1","STANDARD_2V2","STANDARD_4P_FFA","CTF_1V1"]) {
    for (let n=0;n<12;n++) await economy.recordQuestActivity(fact({mode_id:mode}, other));
  }
  for (const maps of [3,5]) for(let n=0;n<6;n++) await economy.recordQuestActivity(fact({...async3,map_count:maps,completed_maps:maps},other));
  await economy.recordQuestActivity(fact({family:"TIME_PUZZLE",scope:"SEASONAL",map_count:3,completed_maps:3},other));
  for(let n=0;n<2;n++) await economy.recordQuestActivity(fact({family:"GAUNTLET",natural_finish:true},other));
  for(const q of (await economy.getPlayerQuests(other)).quests as JsonRecord[]) if(q.ready_to_claim) {
    assert.equal((await claim(q,other)).weekly_bonus_honey_centi,0);
  }
  const incomplete = (await economy.getPlayerQuests(other)).weekly_bonus as JsonRecord;
  assert.equal(incomplete.expected_count,25); assert.equal(incomplete.claimed_count,7); assert.equal(incomplete.awarded,false);
  await assert.rejects(()=>economy.claimQuest({playerId:player,epochId,questId:String(firstDaily!.quest_id),cycleStart:String(firstDaily!.cycle_start),requestId:"new-late-request"}),/quest_already_claimed/);
  assert.equal((await claim(firstDaily!)).duplicate,true);
  const disabled = new PlatformEconomyRepository(pool);
  assert.equal((await disabled.getPlayerQuests(player)).enabled,false);
  await assert.rejects(()=>disabled.recordQuestActivity(fact()),/quests_disabled/);
  console.log(JSON.stringify({ok:true,smoke:"quest_catalog_soak",simulated_weeks:9,claims,activity_facts:sequence,
    all_24_daily_templates:true,weekly_bonus_once:true,missed_days_no_bonus:true,restarts_and_retries:true}));
}
