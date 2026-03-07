import { readFile } from "node:fs/promises";
import type { Pool, PoolClient } from "pg";
import { normalizeLoadedState, normalizePlayerRecord } from "./logic.js";
import { runMigrations } from "./db/migrate.js";
import type { PlayerRecord, RankState } from "./types.js";

const META_LOCAL_PLAYER_ID = "local_player_id";
const WRITE_LOCK_KEY = 934_771_112;

interface PlayerRow {
  player_id: string;
  display_name: string;
  region: string;
  wax_score: number | string;
  last_active_unix: number | string;
  last_decay_day: number | string;
  tier_id: string;
  color_id: string;
  rank_position: number | string;
  percentile: number | string;
  promotion_history: unknown;
  friends: unknown;
  apex_active: boolean;
}

interface ProcessedEventRow {
  dedupe_key: string;
  processed_unix: number | string;
}

export class RankStore {
  private readonly pool: Pool;

  private readonly legacyStatePath: string;

  private writeChain: Promise<void> = Promise.resolve();

  constructor(pool: Pool, legacyStatePath: string) {
    this.pool = pool;
    this.legacyStatePath = legacyStatePath;
  }

  async init(): Promise<void> {
    await runMigrations(this.pool);
    await this.importLegacyStateIfNeeded();
  }

  async healthCheck(): Promise<boolean> {
    try {
      await this.pool.query("SELECT 1");
      return true;
    } catch {
      return false;
    }
  }

  async read<T>(reader: (state: RankState) => T): Promise<T> {
    const state = await this.withClient((client) => this.loadState(client, false));
    return reader(state);
  }

  async write<T>(writer: (state: RankState) => T | Promise<T>): Promise<T> {
    let resolveResult: (value: T | PromiseLike<T>) => void;
    let rejectResult: (reason?: unknown) => void;
    const resultPromise = new Promise<T>((resolve, reject) => {
      resolveResult = resolve;
      rejectResult = reject;
    });

    this.writeChain = this.writeChain.then(async () => {
      const client = await this.pool.connect();
      try {
        await client.query("BEGIN");
        await client.query("SELECT pg_advisory_xact_lock($1)", [WRITE_LOCK_KEY]);

        const before = await this.loadState(client, true);
        const next = this.cloneState(before);
        const result = await writer(next);
        await this.persistStateDiff(client, before, next);

        await client.query("COMMIT");
        resolveResult(result);
      } catch (error) {
        try {
          await client.query("ROLLBACK");
        } catch {
          // ignore rollback errors
        }
        rejectResult(error);
      } finally {
        client.release();
      }
    });

    await this.writeChain;
    return resultPromise;
  }

  private async withClient<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      return await fn(client);
    } finally {
      client.release();
    }
  }

  private cloneState(state: RankState): RankState {
    const playersById: Record<string, PlayerRecord> = {};
    for (const [playerId, record] of Object.entries(state.players_by_id)) {
      playersById[playerId] = normalizePlayerRecord(playerId, record, this.toNumber(record.last_active_unix));
    }
    return {
      local_player_id: state.local_player_id,
      players_by_id: playersById,
      processed_events: { ...state.processed_events }
    };
  }

  private toNumber(value: unknown, fallback = 0): number {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  private toLocalPlayerId(value: unknown): string {
    if (typeof value === "string") {
      return value.trim();
    }
    if (typeof value === "object" && value != null && !Array.isArray(value)) {
      const obj = value as Record<string, unknown>;
      if (typeof obj.local_player_id === "string") {
        return obj.local_player_id.trim();
      }
      if (typeof obj.id === "string") {
        return obj.id.trim();
      }
      if (typeof obj.value === "string") {
        return obj.value.trim();
      }
    }
    return "";
  }

  private async loadState(client: PoolClient, includeProcessedEvents: boolean): Promise<RankState> {
    const state: RankState = {
      local_player_id: "",
      players_by_id: {},
      processed_events: {}
    };

    const meta = await client.query<{ value: unknown }>(
      "SELECT value FROM rank_meta WHERE key = $1 LIMIT 1",
      [META_LOCAL_PLAYER_ID]
    );
    if ((meta.rowCount ?? 0) > 0) {
      state.local_player_id = this.toLocalPlayerId(meta.rows[0].value);
    }

    const players = await client.query<PlayerRow>(`
      SELECT
        player_id,
        display_name,
        region,
        wax_score,
        last_active_unix,
        last_decay_day,
        tier_id,
        color_id,
        rank_position,
        percentile,
        promotion_history,
        friends,
        apex_active
      FROM rank_players
    `);
    for (const row of players.rows) {
      state.players_by_id[row.player_id] = normalizePlayerRecord(row.player_id, {
        player_id: row.player_id,
        display_name: row.display_name,
        region: row.region,
        wax_score: this.toNumber(row.wax_score),
        last_active_unix: this.toNumber(row.last_active_unix),
        last_decay_day: Math.trunc(this.toNumber(row.last_decay_day, -1)),
        tier_id: row.tier_id,
        color_id: row.color_id,
        rank_position: Math.trunc(this.toNumber(row.rank_position)),
        percentile: this.toNumber(row.percentile),
        promotion_history: row.promotion_history as Record<string, boolean>,
        friends: row.friends as string[],
        apex_active: Boolean(row.apex_active)
      });
    }

    if (includeProcessedEvents) {
      const events = await client.query<ProcessedEventRow>(
        "SELECT dedupe_key, processed_unix FROM rank_processed_events"
      );
      for (const row of events.rows) {
        state.processed_events[row.dedupe_key] = Math.max(0, Math.trunc(this.toNumber(row.processed_unix)));
      }
    }

    return state;
  }

  private playerEquals(a: PlayerRecord | undefined, b: PlayerRecord | undefined): boolean {
    if (!a || !b) {
      return false;
    }
    return (
      a.player_id === b.player_id &&
      a.display_name === b.display_name &&
      a.region === b.region &&
      a.wax_score === b.wax_score &&
      a.last_active_unix === b.last_active_unix &&
      a.last_decay_day === b.last_decay_day &&
      a.tier_id === b.tier_id &&
      a.color_id === b.color_id &&
      a.rank_position === b.rank_position &&
      a.percentile === b.percentile &&
      a.apex_active === b.apex_active &&
      JSON.stringify(a.promotion_history) === JSON.stringify(b.promotion_history) &&
      JSON.stringify(a.friends) === JSON.stringify(b.friends)
    );
  }

  private async persistStateDiff(client: PoolClient, before: RankState, next: RankState): Promise<void> {
    if (before.local_player_id !== next.local_player_id) {
      if (next.local_player_id.trim() === "") {
        await client.query("DELETE FROM rank_meta WHERE key = $1", [META_LOCAL_PLAYER_ID]);
      } else {
        await client.query(
          `
            INSERT INTO rank_meta (key, value, updated_at)
            VALUES ($1, to_jsonb($2::text), now())
            ON CONFLICT (key)
            DO UPDATE SET value = EXCLUDED.value, updated_at = now()
          `,
          [META_LOCAL_PLAYER_ID, next.local_player_id]
        );
      }
    }

    const beforePlayerIds = Object.keys(before.players_by_id);
    const nextPlayerIds = Object.keys(next.players_by_id);
    const nextPlayerSet = new Set(nextPlayerIds);
    const deletedPlayerIds = beforePlayerIds.filter((id) => !nextPlayerSet.has(id));
    if (deletedPlayerIds.length > 0) {
      await client.query("DELETE FROM rank_players WHERE player_id = ANY($1::text[])", [deletedPlayerIds]);
    }

    for (const playerId of nextPlayerIds) {
      const nextRecord = next.players_by_id[playerId];
      const beforeRecord = before.players_by_id[playerId];
      if (this.playerEquals(beforeRecord, nextRecord)) {
        continue;
      }
      await client.query(
        `
          INSERT INTO rank_players (
            player_id,
            display_name,
            region,
            wax_score,
            last_active_unix,
            last_decay_day,
            tier_id,
            color_id,
            rank_position,
            percentile,
            promotion_history,
            friends,
            apex_active,
            updated_at
          )
          VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12::jsonb, $13, now()
          )
          ON CONFLICT (player_id)
          DO UPDATE SET
            display_name = EXCLUDED.display_name,
            region = EXCLUDED.region,
            wax_score = EXCLUDED.wax_score,
            last_active_unix = EXCLUDED.last_active_unix,
            last_decay_day = EXCLUDED.last_decay_day,
            tier_id = EXCLUDED.tier_id,
            color_id = EXCLUDED.color_id,
            rank_position = EXCLUDED.rank_position,
            percentile = EXCLUDED.percentile,
            promotion_history = EXCLUDED.promotion_history,
            friends = EXCLUDED.friends,
            apex_active = EXCLUDED.apex_active,
            updated_at = now()
        `,
        [
          nextRecord.player_id,
          nextRecord.display_name,
          nextRecord.region,
          nextRecord.wax_score,
          Math.trunc(nextRecord.last_active_unix),
          Math.trunc(nextRecord.last_decay_day),
          nextRecord.tier_id,
          nextRecord.color_id,
          Math.trunc(nextRecord.rank_position),
          nextRecord.percentile,
          JSON.stringify(nextRecord.promotion_history),
          JSON.stringify(nextRecord.friends),
          nextRecord.apex_active
        ]
      );
    }

    const beforeEventKeys = Object.keys(before.processed_events);
    const nextEventKeys = Object.keys(next.processed_events);
    const nextEventSet = new Set(nextEventKeys);
    const deletedEventKeys = beforeEventKeys.filter((key) => !nextEventSet.has(key));
    if (deletedEventKeys.length > 0) {
      await client.query("DELETE FROM rank_processed_events WHERE dedupe_key = ANY($1::text[])", [deletedEventKeys]);
    }

    for (const dedupeKey of nextEventKeys) {
      const beforeUnix = before.processed_events[dedupeKey];
      const nextUnix = next.processed_events[dedupeKey];
      if (beforeUnix === nextUnix) {
        continue;
      }
      await client.query(
        `
          INSERT INTO rank_processed_events (dedupe_key, processed_unix)
          VALUES ($1, $2)
          ON CONFLICT (dedupe_key)
          DO UPDATE SET processed_unix = EXCLUDED.processed_unix
        `,
        [dedupeKey, Math.trunc(nextUnix)]
      );
    }
  }

  private async importLegacyStateIfNeeded(): Promise<void> {
    const legacyRaw = await this.tryReadLegacyState();
    if (!legacyRaw) {
      return;
    }
    const imported = normalizeLoadedState(legacyRaw);
    if (Object.keys(imported.players_by_id).length === 0 && imported.local_player_id.trim() === "") {
      return;
    }

    await this.withClient(async (client) => {
      await client.query("BEGIN");
      try {
        await client.query("SELECT pg_advisory_xact_lock($1)", [WRITE_LOCK_KEY]);

        const existingPlayerCount = await client.query<{ count: string }>("SELECT COUNT(*)::text AS count FROM rank_players");
        if (Number(existingPlayerCount.rows[0]?.count ?? "0") > 0) {
          await client.query("COMMIT");
          return;
        }

        const empty: RankState = {
          local_player_id: "",
          players_by_id: {},
          processed_events: {}
        };
        await this.persistStateDiff(client, empty, imported);
        await client.query("COMMIT");

        // eslint-disable-next-line no-console
        console.log(`imported legacy rank state from ${this.legacyStatePath}`);
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      }
    });
  }

  private async tryReadLegacyState(): Promise<unknown | null> {
    try {
      const text = await readFile(this.legacyStatePath, "utf8");
      return JSON.parse(text) as unknown;
    } catch {
      return null;
    }
  }
}
