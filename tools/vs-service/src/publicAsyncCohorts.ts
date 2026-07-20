import { DurableCoreError, type JsonRecord } from "./repositories/durableCore.js";
import type { PublishContestInput } from "./repositories/publicContest.js";

type CatalogMap = { map_id: string; sha256: string };

export function buildAsyncCohortInputs(payload: JsonRecord, createdAt: string): PublishContestInput[] {
  const catalog = record(payload.catalog);
  const packs = Object.keys(record(catalog.time_puzzle)).length > 0 ? record(catalog.time_puzzle) : catalog;
  const shared = record(payload.shared);
  const startsAt = text(payload.starts_at) || createdAt;
  const endsAt = text(payload.ends_at);
  const simBuildId = text(payload.sim_build_id);
  const rulesHash = hash(payload.rules_hash);
  const simulationHash = hash(payload.simulation_hash);
  if (!endsAt || !simBuildId || new Date(endsAt).getTime() <= new Date(startsAt).getTime()) {
    throw new DurableCoreError("invalid_async_cohort_window");
  }
  return [definition(3, record(packs.three_map), Number(payload.three_map_generation ?? 1)),
    definition(5, record(packs.five_map), Number(payload.five_map_generation ?? 1))];

  function definition(mapCount: 3 | 5, pack: JsonRecord, generation: number): PublishContestInput {
    const maps = mapsValue(pack.maps);
    if (maps.length !== mapCount || !Number.isSafeInteger(generation) || generation < 1) {
      throw new DurableCoreError("invalid_async_cohort_catalog");
    }
    const familyId = mapCount === 3 ? "ASYNC_3_ROLLING_4P_V1" : "ASYNC_5_ROLLING_4P_V1";
    return {
      seriesKey: `free-${familyId.toLowerCase()}`, generation, family: "ASYNC_MAP_SET", scope: "ROLLING_COHORT",
      mapCount, mapPackId: text(pack.pack_id), mapIds: maps.map((value) => value.map_id),
      contentHashes: Object.fromEntries([["pack", hash(pack.pack_hash)],
        ...maps.map((value, index) => [`map_${index + 1}`, value.sha256])]),
      simBuildId, comparatorId: "TIME_TOTAL_V1", bestEntryPolicy: "BEST_PER_PLAYER",
      attemptPolicy: { submission_window_sec: positive(shared.submission_window_sec, 86_400),
        max_attempts_per_player: positive(shared.max_attempts_per_player, 3), complete_run_required: true,
        rules_hash: rulesHash, simulation_hash: simulationHash,
        map_occurrences: maps },
      closurePolicy: { kind: "QUALIFIED_PLAYER_COUNT", qualified_player_count: 4, roster_capacity: 4,
        cohort_family_id: familyId, auto_rollover: true,
        cohort_window_sec: positive(shared.cohort_window_sec, 7 * 86_400) },
      eligibilityPolicy: { authentication_required: true, authority_required: true, real_identities_only: true,
        payouts_enabled: false }, startsAt, endsAt, createdAt
    };
  }
}

function mapsValue(value: unknown): CatalogMap[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => { const row = record(raw); return { map_id: text(row.map_id), sha256: hash(row.sha256) }; })
    .filter((row) => row.map_id.length > 0);
}
function positive(value: unknown, fallback: number): number {
  const parsed = Number(value); return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}
function hash(value: unknown): string {
  const clean = text(value).toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(clean)) throw new DurableCoreError("invalid_content_hash");
  return clean;
}
function record(value: unknown): JsonRecord {
  return typeof value === "object" && value != null && !Array.isArray(value) ? value as JsonRecord : {};
}
function text(value: unknown): string { return String(value ?? "").trim(); }
