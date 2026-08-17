import type { Pool, QueryResult } from "pg";
import { PGlite, type PGliteInterface } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { PlatformEconomyError, PlatformEconomyRepository, type JsonRecord, type ProducerEnvelope } from "./platformEconomy.js";
import { RankStore } from "./store.js";

type DbResult<T> = { rows: T[]; affectedRows?: number };
class Adapter {
  constructor(private readonly db: PGliteInterface) {}
  async query<T extends Record<string, unknown> = Record<string, unknown>>(sql: string, params: unknown[] = []): Promise<QueryResult<T>> {
    if (sql.includes("pg_advisory_xact_lock")) return this.normalize({ rows: [{} as T], affectedRows: 1 });
    if (params.length === 0 && sql.split(";").filter((part) => part.trim()).length > 1) {
      const results = await this.db.exec(sql);
      return this.normalize((results.at(-1) ?? { rows: [] }) as DbResult<T>);
    }
    return this.normalize(await this.db.query<T>(sql, params) as DbResult<T>);
  }
  async connect(): Promise<Adapter & { release: () => void }> { return Object.assign(this, { release: () => undefined }); }
  private normalize<T extends Record<string, unknown>>(result: DbResult<T>): QueryResult<T> {
    return { command: "", rowCount: result.rows.length || result.affectedRows || 0, oid: 0, fields: [], rows: result.rows };
  }
}

const PLAYER_A = "018f0000-0000-7000-8000-000000000001";
const PLAYER_B = "018f0000-0000-7000-8000-000000000002";
const EPOCH = "beta_launch_0001";
let eventSequence = 0;

function expect(value: unknown, message: string, details?: unknown): void {
  if (!value) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

async function expectCode(run: () => Promise<unknown>, code: string): Promise<void> {
  try { await run(); } catch (error) {
    expect(error instanceof PlatformEconomyError && error.code === code,
      `expected ${code}`, error instanceof Error ? error.message : error);
    return;
  }
  throw new Error(`expected ${code}`);
}

function envelope(eventType: string, payload: JsonRecord = {}, eventId?: string): ProducerEnvelope {
  eventSequence += 1;
  return {
    producerService: "platform-smoke",
    producerEventId: eventId ?? `smoke-event-${String(eventSequence).padStart(4, "0")}`,
    eventType,
    epochId: EPOCH,
    sourceAuthority: "embedded-smoke",
    occurredAt: new Date().toISOString(),
    schemaVersion: 1,
    payload
  };
}

async function insertPlayer(pool: Pool, id: string, entapId: string, callSign: string, wax = 777): Promise<void> {
  await pool.query(
    `INSERT INTO rank_players
      (id, entap_id, call_sign, player_id, display_name, region, wax_score,
       last_active_unix, last_decay_day, tier_id, color_id, rank_position,
       percentile, promotion_history, friends, apex_active)
     VALUES ($1::uuid, $2, $3, $5, $3, 'GLOBAL', $4, 0, -1, 'WORKER', 'BLUE', 1, 0.5, '{}', '[]', FALSE)`,
    [id, entapId, callSign, wax, id]
  );
}

async function main(): Promise<void> {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.waitReady;
  const pool = new Adapter(db) as unknown as Pool;
  const rank = new RankStore(pool, "/nonexistent-platform-smoke.json");
  await rank.init();
  await insertPlayer(pool, PLAYER_A, "AAA 101", "LedgerA");
  await insertPlayer(pool, PLAYER_B, "AAA 102", "LedgerB", 888);

  const economy = new PlatformEconomyRepository(pool);
  await economy.createEpochDraft({
    epochId: EPOCH,
    seasonId: "BETA_S1",
    artifactDigest: "a".repeat(64),
    openingHoneyCenti: 0,
    openingWaxMillis: 0,
    openingNectarMilli: 0
  });
  await economy.prepareEpoch(EPOCH, {
    mutations_off: true,
    no_active_economic_matches: true,
    no_unresolved_escrow: true,
    outboxes_drained: true,
    reconciliation_green: true,
    backup_restorable: true,
    artifacts_pinned: true
  });
  const prepared = await economy.reconcile(EPOCH);
  expect(prepared.ok === true && Number(prepared.open_crucible_contracts) === 0, "prepared epoch did not reconcile", prepared);
  await economy.markEpochReconciled(EPOCH);
  await economy.activateEpoch(EPOCH);
  const resetRows = await pool.query<{ wax_score: number }>("SELECT wax_score FROM rank_players ORDER BY id");
  expect(resetRows.rows.every((row) => Number(row.wax_score) === 0), "Wax was not reset to zero", resetRows.rows);
  expect(Object.values(await economy.capabilitySnapshot()).every((value) => value === false), "capabilities were not default-off");

  const blockedEnvelope = envelope("HONEY_ACTIVITY_V1", { player_id: PLAYER_A });
  await expectCode(() => economy.issuePlayerAsset({ envelope: blockedEnvelope, playerId: PLAYER_A,
    asset: "HONEY_CENTI", amountUnits: 500, capability: "HONEY_EARN" }), "economy_capability_disabled");
  const blockedReceipts = await pool.query<{ count: string }>(
    "SELECT count(*)::text AS count FROM platform_event_receipts WHERE producer_event_id = $1", [blockedEnvelope.producerEventId]
  );
  expect(blockedReceipts.rows[0]?.count === "0", "failed event left a receipt");

  await economy.setCapability("HONEY_EARN", true);
  await economy.setCapability("HONEY_SPEND", true);
  await economy.setCapability("WAX_STANDARD", true);
  await economy.setCapability("WAX_CRUCIBLE", true);
  await economy.setCapability("NECTAR", true);

  const honeyEnvelope = envelope("HONEY_ACTIVITY_V1", { player_id: PLAYER_A, activity_key: "competitive.live_free" }, "honey-fixed-id");
  const honey = await economy.issuePlayerAsset({ envelope: honeyEnvelope, playerId: PLAYER_A,
    asset: "HONEY_CENTI", amountUnits: 500, capability: "HONEY_EARN" });
  const honeyRetry = await economy.issuePlayerAsset({ envelope: honeyEnvelope, playerId: PLAYER_A,
    asset: "HONEY_CENTI", amountUnits: 500, capability: "HONEY_EARN" });
  expect(honey.duplicate === false && honeyRetry.duplicate === true
    && honey.transaction_id === honeyRetry.transaction_id, "retry did not return original receipt", { honey, honeyRetry });
  await expectCode(() => economy.issuePlayerAsset({
    envelope: { ...honeyEnvelope, payload: { ...honeyEnvelope.payload, altered: true } },
    playerId: PLAYER_A, asset: "HONEY_CENTI", amountUnits: 500, capability: "HONEY_EARN"
  }), "idempotency_conflict");
  await economy.spendHoney({ envelope: envelope("HONEY_SPEND_V1", { player_id: PLAYER_A, catalog_action_id: "beta.test" }),
    playerId: PLAYER_A, catalogActionId: "beta.test" });

  await economy.issuePlayerAsset({
    envelope: envelope("HONEY_ACTIVITY_V1", { player_id: PLAYER_B, activity_key: "store-smoke-funding" }),
    playerId: PLAYER_B, asset: "HONEY_CENTI", amountUnits: 35_000, capability: "HONEY_EARN"
  });
  const catalogEnvelope = envelope("HONEY_SPEND_V1", {
    player_id: PLAYER_B, catalog_action_id: "store_sku:skin_hive_obsidian"
  }, "catalog-fixed-id");
  const catalogSpend = await economy.spendHoney({ envelope: catalogEnvelope, playerId: PLAYER_B,
    catalogActionId: "store_sku:skin_hive_obsidian" });
  const catalogRetry = await economy.spendHoney({ envelope: catalogEnvelope, playerId: PLAYER_B,
    catalogActionId: "store_sku:skin_hive_obsidian" });
  expect(catalogSpend.duplicate === false && catalogRetry.duplicate === true
    && catalogSpend.transaction_id === catalogRetry.transaction_id,
  "catalog retry did not return original entitlement receipt", { catalogSpend, catalogRetry });
  expect(Array.isArray(catalogSpend.granted_entitlements)
    && catalogSpend.granted_entitlements.includes("skin_hive_obsidian"),
  "catalog spend did not atomically grant its entitlement", catalogSpend);
  await expectCode(() => economy.spendHoney({
    envelope: envelope("HONEY_SPEND_V1", {
      player_id: PLAYER_B, catalog_action_id: "store_sku:skin_hive_obsidian"
    }),
    playerId: PLAYER_B, catalogActionId: "store_sku:skin_hive_obsidian"
  }), "catalog_item_already_owned");

  for (const playerId of [PLAYER_A, PLAYER_B]) {
    await economy.issuePlayerAsset({ envelope: envelope("WAX_ISSUANCE_V1", { player_id: playerId }), playerId,
      asset: "WAX_MILLIS", amountUnits: 2000, capability: "WAX_STANDARD" });
    await economy.issuePlayerAsset({ envelope: envelope("NECTAR_AWARD_V1", { player_id: playerId }), playerId,
      asset: "NECTAR_MILLI", amountUnits: 1000, capability: "NECTAR" });
  }

  const matchId = "018f0000-0000-7000-8000-000000000010";
  const contractId = "018f0000-0000-7000-8000-000000000011";
  const expiresAt = new Date(Date.now() + 60_000).toISOString();
  const reserveA = await economy.reserveCrucibleParticipant({
    envelope: envelope("CRUCIBLE_RESERVE_V1", { match_id: matchId, player_id: PLAYER_A }),
    matchId, contractId, contractHash: "b".repeat(64), playerId: PLAYER_A,
    playerAId: PLAYER_A, playerBId: PLAYER_B, expiresAt
  });
  const reserveB = await economy.reserveCrucibleParticipant({
    envelope: envelope("CRUCIBLE_RESERVE_V1", { match_id: matchId, player_id: PLAYER_B }),
    matchId, contractId, contractHash: "b".repeat(64), playerId: PLAYER_B,
    playerAId: PLAYER_A, playerBId: PLAYER_B, expiresAt
  });
  expect(reserveA.startable === false && reserveB.startable === true, "contract startability was not receipt-gated", { reserveA, reserveB });
  const resultId = "018f0000-0000-7000-8000-000000000012";
  const settlementEnvelope = envelope("CRUCIBLE_SETTLE_V1", { match_id: matchId, source_result_id: resultId }, "settlement-fixed-id");
  const settlement = await economy.settleCrucible({ envelope: settlementEnvelope, matchId, resultId, winnerPlayerId: PLAYER_A });
  const settlementRetry = await economy.settleCrucible({ envelope: settlementEnvelope, matchId, resultId, winnerPlayerId: PLAYER_A });
  expect(settlement.duplicate === false && settlementRetry.duplicate === true,
    "settlement retry duplicated", { settlement, settlementRetry });

  const balancesA = await economy.getPlayerBalances(PLAYER_A);
  const balancesB = await economy.getPlayerBalances(PLAYER_B);
  expect(balancesA.honey_centi === 400 && balancesA.wax_millis === 2800 && balancesA.nectar_milli === 1000,
    "winner balances incorrect", balancesA);
  expect(balancesB.wax_millis === 1000, "loser balance incorrect", balancesB);
  expect(balancesB.honey_centi === 0 && Array.isArray(balancesB.entitlements)
    && balancesB.entitlements.includes("skin_hive_obsidian"),
  "authoritative entitlement projection incorrect", balancesB);
  const reserve = await pool.query<{ balance_units: string }>(
    "SELECT balance_units::text FROM platform_economy_accounts WHERE epoch_id = $1 AND owner_id = 'reserve:award'",
    [EPOCH]
  );
  expect(reserve.rows[0]?.balance_units === "200", "award reserve incorrect", reserve.rows[0]);

  let manualDebitRejected = false;
  try {
    await pool.query(
      "UPDATE platform_economy_accounts SET balance_units = 0 WHERE epoch_id = $1 AND owner_id = 'reserve:award'",
      [EPOCH]
    );
  }
  catch { manualDebitRejected = true; }
  expect(manualDebitRejected, "manual award reserve debit was not rejected");
  let journalMutationRejected = false;
  try { await pool.query("DELETE FROM platform_journal_entries"); } catch { journalMutationRejected = true; }
  expect(journalMutationRejected, "immutable journal delete was not rejected");

  const insufficient = envelope("HONEY_SPEND_V1", { player_id: PLAYER_B, catalog_action_id: "too.expensive" });
  await expectCode(() => economy.spendHoney({ envelope: insufficient, playerId: PLAYER_B,
    catalogActionId: "store_sku:analysis_forensic_replay" }), "insufficient_funds");
  const failedReceipt = await pool.query<{ count: string }>(
    "SELECT count(*)::text AS count FROM platform_event_receipts WHERE producer_event_id = $1", [insufficient.producerEventId]
  );
  expect(failedReceipt.rows[0]?.count === "0", "rolled-back insufficient spend left a receipt");

  const report = await economy.reconcile(EPOCH);
  expect(report.ok === true && Number(report.unbalanced_transactions) === 0 && Number(report.account_drift) === 0,
    "ledger failed reconciliation", report);
  await expectCode(() => economy.issuePlayerAsset({
    envelope: { ...envelope("HONEY_ACTIVITY_V1"), epochId: "legacy-pre-platform" },
    playerId: PLAYER_A, asset: "HONEY_CENTI", amountUnits: 1, capability: "HONEY_EARN"
  }), "old_or_inactive_epoch");

  console.log(JSON.stringify({
    ok: true, smoke: "platform_economy", epoch: EPOCH, zero_reset: true,
    capabilities_default_off: true, producer_uniqueness: true, altered_retry_rejected: true,
    original_receipt_returned: true, rollback_atomic: true, journal_immutable: true,
    catalog_entitlements_authoritative: true,
    reserve_account: "reserve:award", reserve_debit_forbidden: true,
    crucible_contract: "1000+1000=1800+200", start_receipt_gated: true,
    reconciliation: report
  }));
  await db.close();
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
