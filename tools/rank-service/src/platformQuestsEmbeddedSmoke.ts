import assert from "node:assert/strict";
import type { Pool } from "pg";
import { PlatformEconomyError, PlatformEconomyRepository, type JsonRecord, type ProducerEnvelope } from "./platformEconomy.js";
import { questCycle, validateQuestCatalog, type QuestDefinition } from "./platformQuests.js";

// Test-only content. No player-facing catalog is published by this test.
export async function runQuestSmoke(pool: Pool, playerId: string, otherPlayerId: string, epochId: string): Promise<void> {
  let now = new Date("2026-09-29T12:00:00Z");
  const catalog: QuestDefinition[] = [{
    id: "test_daily_variety", version: 1, title: "Test mixed modes", cadence: "DAILY",
    starts_at: "2026-09-29T09:00:00Z", ends_at: "2026-11-01T00:00:00Z",
    objectives: [{ id: "async", mode_ids: ["STAGE_RACE"], target: 3 },
      { id: "pvp", mode_ids: ["STANDARD"], target: 3 }],
    reward: { honey_centi: 250, nectar_milli: 40_000 }
  }, {
    id: "test_weekly_paid", version: 1, title: "Test paid wins", cadence: "WEEKLY",
    starts_at: "2026-09-29T00:00:00Z", ends_at: "2026-11-01T00:00:00Z",
    objectives: [{ id: "wins", mode_ids: ["STANDARD"], target: 2, paid_entry: true, did_win: true }],
    reward: { honey_centi: 100, nectar_milli: 0 }
  }];
  const economy = new PlatformEconomyRepository(pool, catalog, () => now);
  const defaultEconomy = new PlatformEconomyRepository(pool);
  assert.deepEqual((await defaultEconomy.getPlayerQuests(otherPlayerId)).quests, []);
  assert.equal(questCycle(catalog[1], "2026-10-04T23:59:59Z").start, "2026-09-28T00:00:00.000Z");
  assert.equal(questCycle(catalog[1], "2026-10-05T00:00:00Z").start, "2026-10-05T00:00:00.000Z");
  assert.throws(() => validateQuestCatalog([...catalog, catalog[0]]), /invalid_quest_definition/);
  assert.throws(() => validateQuestCatalog([{ ...catalog[0], reward: { honey_centi: -1, nectar_milli: 0 } }]), /invalid_quest_definition/);
  assert.throws(() => validateQuestCatalog([{ ...catalog[0], objectives: [{ id: "bad", target: 0 }] }]), /invalid_quest_objective/);

  let sequence = 0;
  function match(patch: JsonRecord = {}, at = now.toISOString()): ProducerEnvelope {
    sequence += 1;
    return { producerService: "quest-smoke", producerEventId: `match-${sequence}`,
      epochId, eventType: "NECTAR_MATCH_V1", sourceAuthority: "embedded-smoke", occurredAt: at, schemaVersion: 1,
      payload: { player_id: playerId, match_id: `018f0000-0000-7000-8000-${String(1000 + sequence).padStart(12, "0")}`,
        mode_id: "STANDARD", completed: true, duration_sec: 120, did_win: false, ...patch } };
  }
  async function quests(): Promise<JsonRecord[]> { return (await economy.getPlayerQuests(playerId)).quests as JsonRecord[]; }
  async function daily(): Promise<JsonRecord> { return (await quests()).find((row) => row.quest_id === catalog[0].id)!; }
  async function progress(): Promise<number[]> {
    return ((await daily()).objectives as JsonRecord[]).map((objective) => Number(objective.progress));
  }
  async function error(run: () => Promise<unknown>, code: string): Promise<void> {
    await assert.rejects(run, (failure: unknown) => failure instanceof PlatformEconomyError && failure.code === code);
  }
  const claim = { playerId, epochId, questId: catalog[0].id,
    cycleStart: "2026-09-29T00:00:00.000Z", requestId: "daily-claim" };
  await error(() => economy.claimQuest(claim), "quest_not_available");
  for (const patch of [{ duration_sec: 29 }, { completed: false }, { early_quit: true },
    { no_contest: true }, { private_match: true }, { practice: true }, { mode_id: "CRUCIBLE_1V1" },
    { mode_id: "CRUCIBLE" }, { afk: true }, { invalid_result: true }]) {
    await economy.awardNectarMatch(match(patch));
  }
  await economy.awardNectarMatch(match({}, "2026-09-28T23:59:59Z")); // Before catalog launch.
  await economy.awardNectarMatch(match({}, "2026-09-30T00:00:00Z")); // Future fact.
  assert.deepEqual(await progress(), [0, 0]);

  const first = match();
  await economy.awardNectarMatch(first);
  assert.equal((await economy.awardNectarMatch(first)).duplicate, true);
  await economy.awardNectarMatch({ ...first, producerEventId: "same-game-new-event" });
  assert.deepEqual(await progress(), [0, 1], "one game counts once even across producer IDs");
  await economy.awardNectarMatch(match({}, "2026-09-29T08:59:59Z"));
  assert.deepEqual(await progress(), [0, 1], "late pre-launch games cannot advance an existing assignment");
  await error(() => economy.claimQuest(claim), "quest_incomplete");
  await error(() => economy.claimQuest({ ...claim, playerId: otherPlayerId }), "quest_not_available");
  await error(() => economy.claimQuest({ ...claim, epochId: "legacy-pre-platform" }), "old_or_inactive_epoch");
  for (let i = 0; i < 3; i += 1) await economy.awardNectarMatch(match({ mode_id: "STAGE_RACE" }));
  for (let i = 0; i < 3; i += 1) await economy.awardNectarMatch(match());
  assert.deepEqual(await progress(), [3, 3], "progress is capped at each target");
  assert.equal((await daily()).ready_to_claim, true);
  const weekly = (await quests()).find((row) => row.quest_id === catalog[1].id)!;
  assert.equal((weekly.objectives as JsonRecord[])[0].progress, 0, "free losses do not satisfy paid wins");

  // Restart/redeploy cannot change a player's already assigned reward.
  const changed = new PlatformEconomyRepository(pool,
    [{ ...catalog[0], reward: { honey_centi: 999_999, nectar_milli: 0 } }, catalog[1]], () => now);
  assert.deepEqual(((await changed.getPlayerQuests(playerId)).quests as JsonRecord[])[0].reward, catalog[0].reward);
  await economy.setCapability("HONEY_EARN", false);
  await error(() => economy.claimQuest(claim), "economy_capability_disabled");
  assert.equal((await daily()).claimed, false);
  await economy.setCapability("HONEY_EARN", true);
  const before = await economy.getPlayerBalances(playerId);
  // Force failure after journal postings to prove the reward and claim roll back together.
  await pool.query(`CREATE FUNCTION quest_smoke_fail_claim() RETURNS trigger AS $$
    BEGIN IF NEW.claimed_transaction_id IS NOT NULL THEN RAISE EXCEPTION 'quest_test_failure'; END IF; RETURN NEW; END;
    $$ LANGUAGE plpgsql;
    CREATE TRIGGER quest_smoke_fail BEFORE UPDATE ON platform_quest_progress
    FOR EACH ROW EXECUTE FUNCTION quest_smoke_fail_claim();`);
  await assert.rejects(() => economy.claimQuest(claim), /quest_test_failure/);
  assert.equal((await economy.getPlayerBalances(playerId)).honey_centi, before.honey_centi);
  assert.equal((await economy.getPlayerBalances(playerId)).nectar_milli, before.nectar_milli);
  assert.equal((await daily()).claimed, false);
  await pool.query("DROP TRIGGER quest_smoke_fail ON platform_quest_progress; DROP FUNCTION quest_smoke_fail_claim();");

  const receipt = await changed.claimQuest(claim);
  assert.equal(receipt.honey_centi, Number(before.honey_centi) + 250);
  assert.equal(receipt.nectar_milli, Number(before.nectar_milli) + 40_000);
  assert.equal((await daily()).claimed, true);
  assert.equal((await economy.getPlayerBalances(playerId)).nectar_milli, receipt.nectar_milli);
  now = new Date("2026-09-29T13:00:00Z");
  const retry = await economy.claimQuest(claim);
  assert.equal(retry.duplicate, true);
  assert.equal(retry.transaction_id, receipt.transaction_id);
  await error(() => economy.claimQuest({ ...claim, requestId: "second-claim" }), "quest_already_claimed");
  await error(() => economy.claimQuest({ ...claim, questId: catalog[1].id }), "idempotency_conflict");

  now = new Date("2026-09-30T00:00:00Z");
  assert.deepEqual(await progress(), [0, 0], "daily rollover exposes a fresh cycle");
  await economy.awardNectarMatch(match({}, "2026-09-29T23:59:59Z"));
  assert.deepEqual(await progress(), [0, 0], "late delivery belongs to its original cycle");
  await economy.awardNectarMatch(match({ paid_entry: true, did_win: true }));
  await economy.awardNectarMatch(match({ paid_entry: true, did_win: true }));
  const readyWeekly = (await quests()).find((row) => row.quest_id === catalog[1].id)!;
  assert.equal(readyWeekly.ready_to_claim, true);
  now = new Date("2026-10-05T00:00:00Z");
  assert.equal(((await quests()).find((row) => row.quest_id === catalog[1].id)!.objectives as JsonRecord[])[0].progress, 0);
  await error(() => economy.claimQuest({ ...claim, questId: catalog[1].id,
    cycleStart: String(readyWeekly.cycle_start), requestId: "expired-weekly" }), "quest_expired");
  assert.equal((await economy.claimQuest(claim)).transaction_id, receipt.transaction_id, "completed retry survives rollover");
  console.log(JSON.stringify({ ok: true, smoke: "platform_quests", combined_objectives: true,
    duplicate_match_dedupe: true, cycle_rollover: true, frozen_rewards: true, atomic_claim_rollback: true }));
}
