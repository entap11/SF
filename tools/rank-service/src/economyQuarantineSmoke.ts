import type { Pool } from "pg";
import {
  RANK_ECONOMY_MUTATION_ACTIONS,
  RANK_SUPERSEDED_ACTIONS,
  economyDisabledResult,
  economyMutationsEnabled,
  economyResetEnabled,
  guardEconomyMutation,
  isRankEconomyMutationAction,
  isRankSupersededAction,
  rankMutationHttpStatus,
  rankTokenAuthorized
} from "./economyGuard.js";
import { RankStore, RankWriteClassificationError } from "./store.js";
import { assertSafeTestBackend } from "./testBackendGuard.js";
import { adminRecompute } from "./adminRecompute.js";

function expect(condition: unknown, message: string, details?: unknown): void {
  if (condition) {
    return;
  }
  throw new Error(`${message}${details == null ? "" : ` :: ${JSON.stringify(details)}`}`);
}

async function main(): Promise<void> {
  process.env.RANK_ECONOMY_MUTATIONS_ENABLED = "false";
  process.env.RANK_ECONOMY_RESET_ENABLED = "false";

  let productionUrlRejected = false;
  try {
    assertSafeTestBackend("https://rank-production.example/v1/rank", "");
  } catch (error) {
    productionUrlRejected = error instanceof Error && error.message === "unsafe_test_backend";
  }
  expect(productionUrlRejected, "production-looking Rank test URL was not rejected before network activity");
  assertSafeTestBackend("http://127.0.0.1:1/v1/rank", "");

  let poolCalls = 0;
  const blockedPool = {
    connect: async () => {
      poolCalls += 1;
      throw new Error("quarantined mutation reached storage");
    },
    query: async () => {
      poolCalls += 1;
      throw new Error("quarantined mutation reached storage");
    }
  } as unknown as Pool;
  const store = new RankStore(blockedPool, "");

  expect(economyMutationsEnabled() === false, "rank economy mutations must default closed");
  expect(economyResetEnabled() === false, "rank economy reset must default closed");
  expect(JSON.stringify(guardEconomyMutation()) === JSON.stringify(economyDisabledResult()), "rank guard response changed");
  expect(rankTokenAuthorized("", "") === false, "empty rank token authorized an empty credential");
  expect(rankTokenAuthorized("configured", "") === false, "missing rank bearer authorized");
  expect(rankTokenAuthorized("configured", "forged") === false, "forged rank bearer authorized");
  expect(rankTokenAuthorized("configured", "configured") === true, "valid rank bearer was rejected");
  for (const action of [
    "record_match_result", "record_contest_result", "apply_decay_tick", "debug_set_player_wax", "debug_set_last_active"
  ]) {
    expect(isRankEconomyMutationAction(action), `rank route escaped quarantine classification: ${action}`);
  }
  expect(isRankEconomyMutationAction("admin_recompute"), "administrative recompute escaped economy classification");
  expect(RANK_ECONOMY_MUTATION_ACTIONS.size === 6, "rank quarantine action list changed without updating its test");
  expect(isRankSupersededAction("register_player"), "legacy unauthenticated registration was not superseded");
  for (const action of RANK_ECONOMY_MUTATION_ACTIONS) {
    expect(isRankSupersededAction(action), `legacy economy writer was not permanently superseded: ${action}`);
  }
  expect(RANK_SUPERSEDED_ACTIONS.size === 7, "Rank superseded action list changed without updating its test");

  let writerCalled = false;
  const blockedWrite = await store.writeEconomy(() => {
    writerCalled = true;
    return { ok: true };
  });
  expect(writerCalled === false, "rank economy writer ran while quarantined");
  expect(JSON.stringify(blockedWrite) === JSON.stringify(economyDisabledResult()), "rank internal mutation did not fail closed", blockedWrite);
  expect(poolCalls === 0, "rank internal mutation touched storage while quarantined", { poolCalls });
  expect(rankMutationHttpStatus(blockedWrite) === 503, "administrative recompute would not return HTTP 503", blockedWrite);
  const blockedRecompute = await adminRecompute(store);
  expect(blockedRecompute.status === 503 && blockedRecompute.body.code === "economy_disabled",
    "administrative recompute did not return stable HTTP 503 economy_disabled", blockedRecompute);
  expect(poolCalls === 0, "administrative recompute reached storage while quarantined", { poolCalls });

  let unclassifiedRejected = false;
  try {
    await store.write(undefined, () => ({ ok: true }));
  } catch (error) {
    unclassifiedRejected = error instanceof RankWriteClassificationError
      && error.code === "rank_write_classification_required";
  }
  expect(unclassifiedRejected, "generic Rank persistence accepted an unclassified write");
  expect(poolCalls === 0, "unclassified Rank persistence touched storage", { poolCalls });

  const persistedIdentitySql: string[] = [];
  const identityClient = {
    query: async (sqlValue: unknown) => {
      const sql = String(sqlValue);
      if (/\b(?:INSERT|UPDATE|DELETE)\b/i.test(sql)) {
        persistedIdentitySql.push(sql);
      }
      if (sql.includes("SELECT value FROM rank_meta")) {
        return { rows: [], rowCount: 0 };
      }
      if (sql.includes("FROM rank_players")) {
        return {
          rows: [{
            id: "0190f47a-1234-7abc-8def-123456789abc",
            entap_id: "ABC 123",
            call_sign: "Alpha",
            region: "NA",
            wax_score: 200,
            last_active_unix: 1_700_000_000,
            last_decay_day: 19_000,
            tier_id: "DRONE",
            color_id: "GREEN",
            rank_position: 1,
            percentile: 100,
            promotion_history: { DRONE: true },
            friends: [],
            apex_active: false
          }],
          rowCount: 1
        };
      }
      if (sql.includes("FROM rank_processed_events")) {
        return { rows: [], rowCount: 0 };
      }
      return { rows: [], rowCount: 0 };
    },
    release: () => undefined
  };
  const identityPool = {
    connect: async () => identityClient,
    query: async () => ({ rows: [], rowCount: 0 })
  } as unknown as Pool;
  const identityStore = new RankStore(identityPool, "");
  let identityEconomyRejected = false;
  try {
    await identityStore.writeIdentity((state, context) => {
      state.players_by_id["0190f47a-1234-7abc-8def-123456789abc"].wax_score = 999;
      state.players_by_id["0190f47a-1234-7abc-8def-123456789abc"].rank_position = 99;
      context.recordAuditEvent({ event_type: "rank_state_changed" });
      return { ok: true };
    });
  } catch (error) {
    identityEconomyRejected = error instanceof RankWriteClassificationError
      && error.code === "identity_write_cannot_change_economy_state";
  }
  expect(identityEconomyRejected, "identity write classification allowed Wax/Rank mutation");
  expect(persistedIdentitySql.length === 0,
    "rejected identity write persisted Wax, Rank, or economy audit state", persistedIdentitySql);

  let identityAuditRejected = false;
  try {
    await identityStore.writeIdentity((_state, context) => {
      context.recordAuditEvent({ event_type: "match_result_recorded" });
      return { ok: true };
    });
  } catch (error) {
    identityAuditRejected = error instanceof RankWriteClassificationError
      && error.code === "identity_write_cannot_record_economy_audit";
  }
  expect(identityAuditRejected, "identity write classification allowed an economy audit record");
  expect(persistedIdentitySql.length === 0, "rejected economy audit reached storage", persistedIdentitySql);

  const blockedReset = await store.applyEconomyEpoch("beta_2026071301", 100);
  expect(blockedReset.applied === false, "rank reset applied without explicit gates", blockedReset);
  expect(poolCalls === 0, "rank reset touched storage without explicit gates", { poolCalls });

  process.env.RANK_ECONOMY_MUTATIONS_ENABLED = "true";
  process.env.RANK_ECONOMY_RESET_ENABLED = "false";
  const resetWithoutResetGate = await store.applyEconomyEpoch("beta_2026071301", 100);
  expect(resetWithoutResetGate.applied === false, "rank reset applied with only the mutation gate", resetWithoutResetGate);
  expect(poolCalls === 0, "rank reset touched storage with reset gate disabled", { poolCalls });

  process.env.RANK_ECONOMY_MUTATIONS_ENABLED = "false";
  process.env.RANK_ECONOMY_RESET_ENABLED = "false";

  const registrationQueries: Array<{ sql: string; values: unknown[] }> = [];
  const registrationClient = {
    query: async (sqlValue: unknown, valuesValue: unknown[] = []) => {
      const sql = String(sqlValue);
      const values = Array.isArray(valuesValue) ? valuesValue : [];
      registrationQueries.push({ sql, values });
      if (sql.includes("INSERT INTO rank_players")) {
        return {
          rows: [{
            id: "0190f47a-1234-7abc-8def-123456789abc",
            entap_id: "ABC 123",
            call_sign: String(values[0] ?? "Alpha"),
            region: String(values[1] ?? "GLOBAL"),
            wax_score: Number(values[3] ?? -1),
            last_active_unix: 1_700_000_000,
            last_decay_day: -1,
            tier_id: "DRONE",
            color_id: "GREEN",
            rank_position: 0,
            percentile: 0,
            promotion_history: { DRONE: true },
            friends: [],
            apex_active: false
          }]
        };
      }
      return { rows: [], rowCount: 0 };
    },
    release: () => undefined
  };
  const registrationPool = {
    connect: async () => registrationClient,
    query: async () => ({ rows: [], rowCount: 0 })
  } as unknown as Pool;
  const registrationStore = new RankStore(registrationPool, "");
  const registration = await registrationStore.registerPlayerIdentity({
    callSign: "Alpha_Zero",
    region: "NA",
    friends: [],
    installMetadata: { smoke: true }
  });
  expect(registration.ok === true, "identity registration failed while quarantined", registration);
  expect(registration.player?.wax_score === 0, "quarantined identity registration granted nonzero Wax", registration);
  const playerInsert = registrationQueries.find((entry) => entry.sql.includes("INSERT INTO rank_players"));
  expect(Number(playerInsert?.values[3] ?? -1) === 0, "registration SQL did not persist exactly zero Wax", playerInsert);
  const audits = registrationQueries.filter((entry) => entry.sql.includes("INSERT INTO rank_audit_events"));
  expect(audits.length === 1 && audits[0].values[0] === "player_registered",
    "identity exception wrote an unexpected audit record", audits);

  process.env.RANK_ECONOMY_MUTATIONS_ENABLED = "false";
  process.env.RANK_ECONOMY_RESET_ENABLED = "false";
  console.log(JSON.stringify({ ok: true, smoke: "economy_quarantine" }));
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
