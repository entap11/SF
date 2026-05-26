import type { Pool, PoolClient } from "pg";
import { runMigrations } from "./db/migrate.js";
import {
  newState,
  normalizeProfile,
  recalculateCollegeMembership,
  recalculateSchoolTeams
} from "./logic.js";
import type {
  ActivityEvent,
  AuditEventInput,
  CollegeProgram,
  ScholasticProfile,
  ScholasticState,
  ScholasticTournament,
  SchoolProgram
} from "./types.js";

export interface ScholasticStore {
  init(): Promise<void>;
  healthCheck(): Promise<boolean>;
  read<T>(reader: (state: ScholasticState) => T | Promise<T>): Promise<T>;
  write<T>(writer: (state: ScholasticState, context: { audit: (event: AuditEventInput) => void }) => T | Promise<T>): Promise<T>;
}

const WRITE_LOCK_KEY = 934_771_113;

export class InMemoryScholasticStore implements ScholasticStore {
  private state = newState();

  private writeChain: Promise<void> = Promise.resolve();

  async init(): Promise<void> {}

  async healthCheck(): Promise<boolean> {
    return true;
  }

  async read<T>(reader: (state: ScholasticState) => T | Promise<T>): Promise<T> {
    return reader(cloneState(this.state));
  }

  async write<T>(writer: (state: ScholasticState, context: { audit: (event: AuditEventInput) => void }) => T | Promise<T>): Promise<T> {
    let resolveResult!: (value: T | PromiseLike<T>) => void;
    let rejectResult!: (reason?: unknown) => void;
    const resultPromise = new Promise<T>((resolve, reject) => {
      resolveResult = resolve;
      rejectResult = reject;
    });
    this.writeChain = this.writeChain.then(async () => {
      try {
        const next = cloneState(this.state);
        const result = await writer(next, { audit: () => {} });
        this.state = normalizeState(next);
        resolveResult(result);
      } catch (error) {
        rejectResult(error);
      }
    });
    await this.writeChain;
    return resultPromise;
  }
}

export class PgScholasticStore implements ScholasticStore {
  private readonly pool: Pool;

  private writeChain: Promise<void> = Promise.resolve();

  constructor(pool: Pool) {
    this.pool = pool;
  }

  async init(): Promise<void> {
    await runMigrations(this.pool);
  }

  async healthCheck(): Promise<boolean> {
    try {
      await this.pool.query("SELECT 1");
      return true;
    } catch {
      return false;
    }
  }

  async read<T>(reader: (state: ScholasticState) => T | Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      return reader(await this.loadState(client));
    } finally {
      client.release();
    }
  }

  async write<T>(writer: (state: ScholasticState, context: { audit: (event: AuditEventInput) => void }) => T | Promise<T>): Promise<T> {
    let resolveResult!: (value: T | PromiseLike<T>) => void;
    let rejectResult!: (reason?: unknown) => void;
    const resultPromise = new Promise<T>((resolve, reject) => {
      resolveResult = resolve;
      rejectResult = reject;
    });

    this.writeChain = this.writeChain.then(async () => {
      const client = await this.pool.connect();
      try {
        await client.query("BEGIN");
        await client.query("SELECT pg_advisory_xact_lock($1)", [WRITE_LOCK_KEY]);
        const state = await this.loadState(client);
        const auditEvents: AuditEventInput[] = [];
        const result = await writer(state, {
          audit: (event) => {
            if (event.event_type?.trim()) {
              auditEvents.push(event);
            }
          }
        });
        await this.persistState(client, normalizeState(state));
        await this.persistAudit(client, auditEvents);
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

  private async loadState(client: PoolClient): Promise<ScholasticState> {
    const state = newState();
    const profiles = await client.query<{ player_id: string; profile: ScholasticProfile }>("SELECT player_id, profile FROM scholastic_profiles");
    for (const row of profiles.rows) {
      state.profiles[row.player_id] = normalizeProfile(row.profile);
    }
    const schools = await client.query<{ school_id: string; program: SchoolProgram }>("SELECT school_id, program FROM scholastic_schools");
    for (const row of schools.rows) {
      state.schools[row.school_id] = row.program;
    }
    const colleges = await client.query<{ program_id: string; program: CollegeProgram }>("SELECT program_id, program FROM scholastic_colleges");
    for (const row of colleges.rows) {
      state.colleges[row.program_id] = row.program;
    }
    const tournaments = await client.query<{ tournament_id: string; tournament: ScholasticTournament }>("SELECT tournament_id, tournament FROM scholastic_tournaments");
    for (const row of tournaments.rows) {
      state.tournaments[row.tournament_id] = row.tournament;
    }
    const activity = await client.query<ActivityEvent>(`
      SELECT event_id, player_id, ecosystem, event_date::text, duration_seconds, is_new_player, props
      FROM scholastic_activity_events
      ORDER BY event_date DESC, id DESC
      LIMIT 20000
    `);
    state.activity_events = activity.rows.map((row) => ({
      event_id: row.event_id,
      player_id: row.player_id,
      ecosystem: row.ecosystem,
      event_date: row.event_date,
      duration_seconds: Number(row.duration_seconds),
      is_new_player: Boolean(row.is_new_player),
      props: row.props ?? {}
    }));
    return normalizeState(state);
  }

  private async persistState(client: PoolClient, state: ScholasticState): Promise<void> {
    await client.query("DELETE FROM scholastic_profiles");
    await client.query("DELETE FROM scholastic_schools");
    await client.query("DELETE FROM scholastic_colleges");
    await client.query("DELETE FROM scholastic_tournaments");
    await client.query("DELETE FROM scholastic_activity_events");
    for (const [playerId, profile] of Object.entries(state.profiles)) {
      await client.query(
        "INSERT INTO scholastic_profiles (player_id, profile, updated_at) VALUES ($1, $2, now())",
        [playerId, profile]
      );
    }
    for (const [schoolId, program] of Object.entries(state.schools)) {
      await client.query(
        "INSERT INTO scholastic_schools (school_id, program, updated_at) VALUES ($1, $2, now())",
        [schoolId, program]
      );
    }
    for (const [programId, program] of Object.entries(state.colleges)) {
      await client.query(
        "INSERT INTO scholastic_colleges (program_id, program, updated_at) VALUES ($1, $2, now())",
        [programId, program]
      );
    }
    for (const [tournamentId, tournament] of Object.entries(state.tournaments)) {
      await client.query(
        "INSERT INTO scholastic_tournaments (tournament_id, ecosystem, tournament, updated_at) VALUES ($1, $2, $3, now())",
        [tournamentId, tournament.ecosystem, tournament]
      );
    }
    for (const event of state.activity_events) {
      await client.query(
        `INSERT INTO scholastic_activity_events
          (event_id, player_id, ecosystem, event_date, duration_seconds, is_new_player, props)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (event_id) DO NOTHING`,
        [
          event.event_id,
          event.player_id,
          event.ecosystem,
          event.event_date,
          Math.max(0, Math.floor(Number(event.duration_seconds) || 0)),
          Boolean(event.is_new_player),
          event.props ?? {}
        ]
      );
    }
  }

  private async persistAudit(client: PoolClient, auditEvents: AuditEventInput[]): Promise<void> {
    for (const event of auditEvents) {
      await client.query(
        "INSERT INTO scholastic_audit_events (event_type, player_id, related_id, payload) VALUES ($1, $2, $3, $4)",
        [event.event_type, event.player_id ?? "", event.related_id ?? "", event.payload ?? {}]
      );
    }
  }
}

export function normalizeState(state: ScholasticState): ScholasticState {
  const normalized = cloneState(state);
  for (const [playerId, profile] of Object.entries(normalized.profiles)) {
    normalized.profiles[playerId] = normalizeProfile(profile);
  }
  const profiles = Object.values(normalized.profiles);
  for (const [schoolId, school] of Object.entries(normalized.schools)) {
    normalized.schools[schoolId] = recalculateSchoolTeams(school, profiles);
  }
  for (const [programId, program] of Object.entries(normalized.colleges)) {
    normalized.colleges[programId] = recalculateCollegeMembership(program, profiles);
  }
  return normalized;
}

export function cloneState(state: ScholasticState): ScholasticState {
  return structuredClone(state);
}
