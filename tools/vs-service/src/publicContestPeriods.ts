import { DurableCoreError, type JsonRecord } from "./repositories/durableCore.js";
import { parseIso, type ContestScope, type PublishContestInput } from "./repositories/publicContest.js";

type Period = { generation: number; starts_at: string; ends_at: string };
type MapEntry = { map_id: string; sha256: string };

export function buildTimeGauntletPeriodInputs(body: JsonRecord, nowIso: string): PublishContestInput[] {
  const catalog = record(body.catalog);
  if (text(catalog.schema) !== "swarmfront.public_contest_catalog.v1") {
    throw new DurableCoreError("invalid_public_contest_catalog");
  }
  const simBuildId = text(body.sim_build_id);
  if (!simBuildId) throw new DurableCoreError("invalid_contest_definition");
  const periods = record(body.periods);
  const inputs: PublishContestInput[] = [];
  for (const [scope, key] of [["WEEKLY", "weekly"], ["MONTHLY", "monthly"],
    ["SEASONAL", "seasonal"]] as Array<[ContestScope, string]>) {
    const period = periodValue(periods[key]);
    for (const mapCount of [3, 5]) {
      const pack = record(record(catalog.time_puzzle)[mapCount === 3 ? "three_map" : "five_map"]);
      const maps = mapEntries(pack.maps, mapCount);
      inputs.push({
        seriesKey: `time-puzzle-${mapCount}-${key}`, generation: period.generation,
        family: "TIME_PUZZLE", scope, mapCount, mapPackId: text(pack.pack_id),
        mapIds: maps.map((map) => map.map_id), contentHashes: contentHashes(pack, maps),
        simBuildId, comparatorId: "TIME_TOTAL_V1", bestEntryPolicy: "BEST_PER_PLAYER",
        attemptPolicy: { submission_window_sec: positiveInteger(body.time_submission_window_sec, 10_800),
          tick_ms: 100, evidence_schema: "swarmfront.time_puzzle_evidence.v1" },
        closurePolicy: { kind: "SERVER_TIME" }, eligibilityPolicy: record(body.eligibility_policy),
        startsAt: period.starts_at, endsAt: period.ends_at, createdAt: nowIso
      });
    }
  }
  const gauntletPeriod = periodValue(periods.weekly);
  const gauntlet = record(catalog.gauntlet);
  const stages = arrayRecords(gauntlet.stages);
  if (stages.length !== 18 || Number(gauntlet.stage_count) !== 18) {
    throw new DurableCoreError("invalid_gauntlet_stage_plan");
  }
  const stageMaps = stages.map((stage) => ({ map_id: text(stage.map_id), sha256: text(stage.map_sha256) }));
  inputs.push({
    seriesKey: "gauntlet-weekly", generation: gauntletPeriod.generation,
    family: "GAUNTLET", scope: "WEEKLY", mapCount: 18,
    mapPackId: text(gauntlet.plan_id), mapIds: stageMaps.map((map) => map.map_id),
    contentHashes: contentHashes({ pack_hash: gauntlet.plan_hash }, stageMaps), simBuildId,
    comparatorId: "GAUNTLET_STARS_V1", bestEntryPolicy: "BEST_PER_PLAYER",
    attemptPolicy: { submission_window_sec: positiveInteger(body.gauntlet_submission_window_sec, 86_400),
      tick_ms: 100, evidence_schema: "swarmfront.gauntlet_evidence.v1", stage_plan: stages,
      stage_plan_hash: text(gauntlet.plan_hash) },
    closurePolicy: { kind: "SERVER_TIME" }, eligibilityPolicy: record(body.eligibility_policy),
    startsAt: gauntletPeriod.starts_at, endsAt: gauntletPeriod.ends_at, createdAt: nowIso
  });
  return inputs;
}

function periodValue(value: unknown): Period {
  const source = record(value);
  const generation = positiveInteger(source.generation, 0);
  const starts_at = text(source.starts_at);
  const ends_at = text(source.ends_at);
  if (generation < 1) throw new DurableCoreError("invalid_contest_generation");
  const starts = parseIso(starts_at, "invalid_contest_starts_at");
  const ends = parseIso(ends_at, "invalid_contest_ends_at");
  if (ends <= starts) throw new DurableCoreError("invalid_contest_window");
  return { generation, starts_at, ends_at };
}

function mapEntries(value: unknown, count: number): MapEntry[] {
  const maps = arrayRecords(value).map((row) => ({ map_id: text(row.map_id), sha256: text(row.sha256) }));
  if (maps.length !== count || maps.some((map) => !map.map_id || !hash(map.sha256))) {
    throw new DurableCoreError("invalid_contest_maps");
  }
  return maps;
}

function contentHashes(pack: JsonRecord, maps: MapEntry[]): JsonRecord {
  const result: JsonRecord = { pack: text(pack.pack_hash) };
  maps.forEach((map, index) => { result[`map_${index + 1}`] = map.sha256; });
  if (Object.values(result).some((value) => !hash(text(value)))) {
    throw new DurableCoreError("invalid_content_hash");
  }
  return result;
}

function positiveInteger(value: unknown, fallback: number): number {
  if (value == null) return fallback;
  if (typeof value === "number" && Number.isSafeInteger(value) && value > 0) return value;
  throw new DurableCoreError("positive_integer_required");
}
function hash(value: string): boolean { return /^[0-9a-f]{64}$/.test(value); }
function text(value: unknown): string { return typeof value === "string" ? value.trim() : ""; }
function record(value: unknown): JsonRecord {
  return typeof value === "object" && value != null && !Array.isArray(value) ? value as JsonRecord : {};
}
function arrayRecords(value: unknown): JsonRecord[] { return Array.isArray(value) ? value.map(record) : []; }
