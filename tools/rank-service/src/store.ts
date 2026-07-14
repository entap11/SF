import { readFile } from "node:fs/promises";
import type { Pool, PoolClient } from "pg";
import { config } from "./config.js";
import { entapIdFromSequence, normalizeCallSign, normalizeLoadedState, normalizePlayerRecord, recomputeRankings } from "./logic.js";
import { runMigrations } from "./db/migrate.js";
import { economyResetPermitted, guardEconomyMutation, type EconomyGuardResult } from "./economyGuard.js";
import type {
  PlayerRecord,
  RankAuditEvent,
  RankAuditEventInput,
  RankState,
  RankWriteClassification,
  RankWriteContext
} from "./types.js";

const META_LOCAL_PLAYER_ID = "local_player_id";
const META_ECONOMY_EPOCH = "economy_epoch";
const WRITE_LOCK_KEY = 934_771_112;
const IDENTITY_AUDIT_EVENTS = new Set([
  "player_snapshot_requested",
  "player_friends_updated",
  "player_region_updated"
]);

export class RankWriteClassificationError extends Error {
  readonly code: string;

  constructor(code: string) {
    super(code);
    this.name = "RankWriteClassificationError";
    this.code = code;
  }
}

interface PlayerRow {
  id: string;
  entap_id: string;
  call_sign: string;
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

interface RegisterIdentityInput {
  callSign: string;
  region: string;
  friends: string[];
  installMetadata?: Record<string, unknown>;
}

interface ProcessedEventRow {
  dedupe_key: string;
  processed_unix: number | string;
}

interface AuditEventRow {
  id: number | string;
  event_type: string;
  player_id: string;
  related_player_id: string;
  payload: unknown;
  created_at: Date | string;
}

interface TierColorCountRow {
  tier_id: string;
  color_id: string;
  player_count: number | string;
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

  async applyEconomyEpoch(epoch: string, startingWax: number): Promise<{
    applied: boolean;
    previous_epoch: string;
    economy_epoch: string;
    player_count: number;
  }> {
    if (!economyResetPermitted() || guardEconomyMutation()) {
      return { applied: false, previous_epoch: "", economy_epoch: "", player_count: 0 };
    }
    const cleanEpoch = epoch.trim();
    if (!cleanEpoch) {
      return { applied: false, previous_epoch: "", economy_epoch: "", player_count: 0 };
    }
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("SELECT pg_advisory_xact_lock($1)", [WRITE_LOCK_KEY]);
      const meta = await client.query<{ value: string | null }>(
        "SELECT value #>> '{}' AS value FROM rank_meta WHERE key = $1 LIMIT 1 FOR UPDATE",
        [META_ECONOMY_EPOCH]
      );
      const previousEpoch = String(meta.rows[0]?.value ?? "").trim();
      const playerCountResult = await client.query<{ count: string }>("SELECT COUNT(*)::text AS count FROM rank_players");
      const playerCount = Math.max(0, Number.parseInt(playerCountResult.rows[0]?.count ?? "0", 10) || 0);
      if (previousEpoch === cleanEpoch) {
        await client.query("COMMIT");
        return { applied: false, previous_epoch: previousEpoch, economy_epoch: cleanEpoch, player_count: playerCount };
      }

      const before = await this.loadState(client, true);
      const next = this.cloneState(before);
      const safeStartingWax = Math.max(0, Number.isFinite(startingWax) ? startingWax : 0);
      const currentDay = Math.floor(Date.now() / 1000 / 86_400);
      for (const [playerId, record] of Object.entries(next.players_by_id)) {
        record.wax_score = safeStartingWax;
        record.last_decay_day = currentDay;
        record.tier_id = "DRONE";
        record.color_id = "GREEN";
        record.rank_position = 0;
        record.percentile = 0;
        record.promotion_history = {};
        record.apex_active = false;
        next.players_by_id[playerId] = normalizePlayerRecord(playerId, record, record.last_active_unix);
      }
      next.processed_events = {};
      recomputeRankings(next);
      await this.persistStateDiff(client, before, next, "economy");
      await this.persistAuditEvents(client, [{
        event_type: "beta_economy_epoch_reset",
        payload: {
          previous_epoch: previousEpoch,
          economy_epoch: cleanEpoch,
          player_count: playerCount,
          identities_preserved: true,
          starting_wax: safeStartingWax
        }
      }], "economy");
      await client.query(
        `
          INSERT INTO rank_meta (key, value, updated_at)
          VALUES ($1, to_jsonb($2::text), now())
          ON CONFLICT (key)
          DO UPDATE SET value = EXCLUDED.value, updated_at = now()
        `,
        [META_ECONOMY_EPOCH, cleanEpoch]
      );
      await client.query("COMMIT");
      return { applied: true, previous_epoch: previousEpoch, economy_epoch: cleanEpoch, player_count: playerCount };
    } catch (error) {
      try {
        await client.query("ROLLBACK");
      } catch {
        // ignore rollback errors
      }
      throw error;
    } finally {
      client.release();
    }
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

  async write<T>(
    classification: RankWriteClassification | undefined,
    writer: (state: RankState, context: RankWriteContext) => T | Promise<T>
  ): Promise<T | EconomyGuardResult> {
    if (classification !== "identity" && classification !== "economy") {
      throw new RankWriteClassificationError("rank_write_classification_required");
    }
    if (classification === "economy") {
      const blocked = guardEconomyMutation();
      if (blocked) {
        return blocked;
      }
    }
    return this.writeClassified(classification, writer);
  }

  async writeIdentity<T>(writer: (state: RankState, context: RankWriteContext) => T | Promise<T>): Promise<T> {
    return this.writeClassified("identity", writer);
  }

  async writeEconomy<T>(writer: (state: RankState, context: RankWriteContext) => T | Promise<T>): Promise<T | EconomyGuardResult> {
    return this.write("economy", writer);
  }

  private async writeClassified<T>(
    classification: RankWriteClassification,
    writer: (state: RankState, context: RankWriteContext) => T | Promise<T>
  ): Promise<T> {
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
        const auditEvents: RankAuditEventInput[] = [];
        const context: RankWriteContext = {
          recordAuditEvent: (event: RankAuditEventInput) => {
            if (!event || typeof event.event_type !== "string") {
              return;
            }
            const eventType = event.event_type.trim();
            if (!eventType) {
              return;
            }
            auditEvents.push({
              event_type: eventType,
              player_id: String(event.player_id ?? "").trim(),
              related_player_id: String(event.related_player_id ?? "").trim(),
              payload: this.toRecord(event.payload)
            });
          }
        };
        const result = await writer(next, context);
        if (classification === "identity") {
          this.assertIdentityWriteAllowed(before, next, auditEvents);
        }
        await this.persistStateDiff(client, before, next, classification);
        await this.persistAuditEvents(client, auditEvents, classification);

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

  private toRecord(value: unknown): Record<string, unknown> {
    if (typeof value === "object" && value != null && !Array.isArray(value)) {
      return { ...(value as Record<string, unknown>) };
    }
    return {};
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
        id::text AS id,
        entap_id,
        call_sign,
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
      state.players_by_id[row.id] = normalizePlayerRecord(row.id, {
        id: row.id,
        entap_id: row.entap_id,
        call_sign: row.call_sign,
        player_id: row.id,
        display_name: row.call_sign,
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
      a.id === b.id &&
      a.entap_id === b.entap_id &&
      a.call_sign === b.call_sign &&
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

  private assertIdentityWriteAllowed(before: RankState, next: RankState, auditEvents: RankAuditEventInput[]): void {
    const beforeIds = Object.keys(before.players_by_id).sort();
    const nextIds = Object.keys(next.players_by_id).sort();
    if (JSON.stringify(beforeIds) !== JSON.stringify(nextIds)) {
      throw new RankWriteClassificationError("identity_write_cannot_create_or_delete_players");
    }
    if (JSON.stringify(before.processed_events) !== JSON.stringify(next.processed_events)) {
      throw new RankWriteClassificationError("identity_write_cannot_change_processed_events");
    }
    for (const playerId of beforeIds) {
      const oldRecord = before.players_by_id[playerId];
      const nextRecord = next.players_by_id[playerId];
      const protectedBefore = {
        wax_score: oldRecord.wax_score,
        last_active_unix: oldRecord.last_active_unix,
        last_decay_day: oldRecord.last_decay_day,
        tier_id: oldRecord.tier_id,
        color_id: oldRecord.color_id,
        rank_position: oldRecord.rank_position,
        percentile: oldRecord.percentile,
        promotion_history: oldRecord.promotion_history,
        apex_active: oldRecord.apex_active
      };
      const protectedNext = {
        wax_score: nextRecord.wax_score,
        last_active_unix: nextRecord.last_active_unix,
        last_decay_day: nextRecord.last_decay_day,
        tier_id: nextRecord.tier_id,
        color_id: nextRecord.color_id,
        rank_position: nextRecord.rank_position,
        percentile: nextRecord.percentile,
        promotion_history: nextRecord.promotion_history,
        apex_active: nextRecord.apex_active
      };
      if (JSON.stringify(protectedBefore) !== JSON.stringify(protectedNext)) {
        throw new RankWriteClassificationError("identity_write_cannot_change_economy_state");
      }
    }
    for (const event of auditEvents) {
      if (!IDENTITY_AUDIT_EVENTS.has(event.event_type.trim())) {
        throw new RankWriteClassificationError("identity_write_cannot_record_economy_audit");
      }
    }
  }

  private async persistStateDiff(
    client: PoolClient,
    before: RankState,
    next: RankState,
    classification: RankWriteClassification
  ): Promise<void> {
    if (classification !== "identity" && classification !== "economy") {
      throw new RankWriteClassificationError("rank_write_classification_required");
    }
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
      await client.query("DELETE FROM rank_players WHERE id = ANY($1::uuid[])", [deletedPlayerIds]);
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
            id,
            entap_id,
            call_sign,
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
            $1::uuid, COALESCE(NULLIF($2, ''), rank_entap_id_from_sequence(nextval('rank_entap_id_seq'))), $3, $4, $5, $6, $7, $8, $9, $10, $11, $12::jsonb, $13::jsonb, $14, now()
          )
          ON CONFLICT (id)
          DO UPDATE SET
            entap_id = EXCLUDED.entap_id,
            call_sign = EXCLUDED.call_sign,
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
          nextRecord.id || nextRecord.player_id,
          nextRecord.entap_id,
          normalizeCallSign(nextRecord.call_sign || nextRecord.display_name, `Player_${String(nextRecord.entap_id || "AAA 000").replace(" ", "_")}`),
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

  private async persistAuditEvents(
    client: PoolClient,
    events: RankAuditEventInput[],
    classification: RankWriteClassification
  ): Promise<void> {
    if (classification !== "identity" && classification !== "economy") {
      throw new RankWriteClassificationError("rank_write_classification_required");
    }
    for (const event of events) {
      await client.query(
        `
          INSERT INTO rank_audit_events (event_type, player_id, related_player_id, payload)
          VALUES ($1, $2, $3, $4::jsonb)
        `,
        [
          event.event_type.trim(),
          String(event.player_id ?? "").trim(),
          String(event.related_player_id ?? "").trim(),
          JSON.stringify(this.toRecord(event.payload))
        ]
      );
    }
  }

  async readServiceStats(): Promise<{
    player_count: number;
    processed_event_count: number;
    audit_event_count: number;
  }> {
    return this.withClient(async (client) => {
      const playerCount = await client.query<{ count: string }>("SELECT COUNT(*)::text AS count FROM rank_players");
      const processedCount = await client.query<{ count: string }>("SELECT COUNT(*)::text AS count FROM rank_processed_events");
      const auditCount = await client.query<{ count: string }>("SELECT COUNT(*)::text AS count FROM rank_audit_events");
      return {
        player_count: Math.max(0, Math.trunc(this.toNumber(playerCount.rows[0]?.count))),
        processed_event_count: Math.max(0, Math.trunc(this.toNumber(processedCount.rows[0]?.count))),
        audit_event_count: Math.max(0, Math.trunc(this.toNumber(auditCount.rows[0]?.count)))
      };
    });
  }

  async readTierColorCounts(): Promise<Array<{ tier_id: string; color_id: string; player_count: number }>> {
    return this.withClient(async (client) => {
      const result = await client.query<TierColorCountRow>(
        `
          SELECT tier_id, color_id, COUNT(*)::text AS player_count
          FROM rank_players
          GROUP BY tier_id, color_id
        `
      );
      return result.rows.map((row) => ({
        tier_id: row.tier_id,
        color_id: row.color_id,
        player_count: Math.max(0, Math.trunc(this.toNumber(row.player_count)))
      }));
    });
  }

  async allocateEntapId(): Promise<string> {
    return this.withClient(async (client) => {
      const result = await client.query<{ sequence: string }>("SELECT nextval('rank_entap_id_seq')::text AS sequence");
      return entapIdFromSequence(this.toNumber(result.rows[0]?.sequence));
    });
  }

  async registerPlayerIdentity(input: RegisterIdentityInput): Promise<{ ok: boolean; err?: string; player?: PlayerRecord }> {
    // Explicit quarantine exception: identity creation may persist only a zero-Wax
    // starter record and the narrowly scoped player_registered audit event.
    const economyBlocked = guardEconomyMutation();
    const startingWax = economyBlocked ? 0 : Math.max(config.rank.waxFloor, config.rank.baseGain);
    const callSign = normalizeCallSign(input.callSign, "");
    if (!callSign) {
      return { ok: false, err: "invalid_call_sign" };
    }
    const region = String(input.region || "").trim().toUpperCase() || "GLOBAL";
    const friends = Array.isArray(input.friends) ? input.friends : [];
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const result = await client.query<PlayerRow>(
        `
          WITH identity AS (
            SELECT
              rank_uuid_v7() AS id,
              rank_entap_id_from_sequence(nextval('rank_entap_id_seq')) AS entap_id
          )
          INSERT INTO rank_players (
            id,
            entap_id,
            call_sign,
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
          SELECT
            identity.id,
            identity.entap_id,
            $1,
            $2,
            $4,
            floor(extract(epoch from now()))::bigint,
            -1,
            'DRONE',
            'GREEN',
            0,
            0,
            '{"DRONE": true}'::jsonb,
            $3::jsonb,
            false,
            now()
          FROM identity
          RETURNING
            id::text AS id,
            entap_id,
            call_sign,
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
        `,
        [callSign, region, JSON.stringify(friends), startingWax]
      );
      const row = result.rows[0];
      await client.query(
        `
          INSERT INTO rank_audit_events (event_type, player_id, related_player_id, payload)
          VALUES ($1, $2, '', $3::jsonb)
        `,
        [
          "player_registered",
          row.id,
          JSON.stringify({
            id: row.id,
            entap_id: row.entap_id,
            call_sign: row.call_sign,
            region: row.region,
            source: "identity_register",
            economy_exception: economyBlocked ? "identity_registration_zero_wax" : "",
            install_metadata: this.toRecord(input.installMetadata)
          })
        ]
      );
      await client.query("COMMIT");
      return {
        ok: true,
        player: normalizePlayerRecord(row.id, {
          id: row.id,
          entap_id: row.entap_id,
          call_sign: row.call_sign,
          player_id: row.id,
          display_name: row.call_sign,
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
        })
      };
    } catch (error) {
      try {
        await client.query("ROLLBACK");
      } catch {
        // ignore rollback errors
      }
      const pgError = error as { code?: string; constraint?: string; detail?: string };
      if (pgError.code === "23505") {
        const constraint = String(pgError.constraint ?? "");
        if (constraint.includes("call_sign") || String(pgError.detail ?? "").toLowerCase().includes("call_sign")) {
          return { ok: false, err: "call_sign_not_unique" };
        }
        if (constraint.includes("entap_id") || String(pgError.detail ?? "").toLowerCase().includes("entap_id")) {
          return { ok: false, err: "entap_id_collision" };
        }
      }
      throw error;
    } finally {
      client.release();
    }
  }

  async readAuditTrail(limit: number, playerId = "", eventType = ""): Promise<RankAuditEvent[]> {
    return this.withClient(async (client) => {
      const safeLimit = Math.max(1, Math.min(200, Math.trunc(limit)));
      const clauses: string[] = [];
      const values: Array<string | number> = [];
      let idx = 1;
      if (playerId.trim()) {
        clauses.push(`(player_id = $${idx} OR related_player_id = $${idx})`);
        values.push(playerId.trim());
        idx += 1;
      }
      if (eventType.trim()) {
        clauses.push(`event_type = $${idx}`);
        values.push(eventType.trim());
        idx += 1;
      }
      values.push(safeLimit);
      const where = clauses.length > 0 ? `WHERE ${clauses.join(" AND ")}` : "";
      const result = await client.query<AuditEventRow>(
        `
          SELECT id, event_type, player_id, related_player_id, payload, created_at
          FROM rank_audit_events
          ${where}
          ORDER BY created_at DESC, id DESC
          LIMIT $${idx}
        `,
        values
      );
      return result.rows.map((row) => ({
        id: Math.max(0, Math.trunc(this.toNumber(row.id))),
        event_type: row.event_type,
        player_id: row.player_id ?? "",
        related_player_id: row.related_player_id ?? "",
        payload: this.toRecord(row.payload),
        created_at: row.created_at instanceof Date ? row.created_at.toISOString() : String(row.created_at ?? "")
      }));
    });
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
    if (guardEconomyMutation()) {
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
        await this.persistStateDiff(client, empty, imported, "economy");
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
