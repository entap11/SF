import crypto from "node:crypto";
import { gunzipSync } from "node:zlib";
import express, { type Express, type RequestHandler } from "express";
import type { Pool } from "pg";
import { AccountDeletionStore } from "./identity/accountDeletion.js";
import { IdentitySessionError } from "./identity/sessionStore.js";
import { bearerTokenFromHeader, PlayerTokenError, verifyPlayerAccessToken, type PlayerTokenKeyConfig } from "./identity/playerToken.js";

export const MAX_CAPTURE_BYTES = 8 * 1024 * 1024;
export const participantKey = (id: string): string => crypto.createHash("sha256").update(id).digest("hex");
const hash = (body: Buffer): string => crypto.createHash("sha256").update(body).digest("hex");
function fail(code: string, status = 400): never { throw new IdentitySessionError(code, status); }
const record = (x: unknown): x is Record<string, unknown> => !!x && typeof x === "object" && !Array.isArray(x);
const token = (x: unknown, max = 160): x is string => typeof x === "string" && x.length <= max && /^[A-Za-z0-9_.:/ -]*$/.test(x);
const number = (x: unknown): x is number => typeof x === "number" && Number.isFinite(x);
const keys = (obj: Record<string, unknown>, allowed: string): boolean => Object.keys(obj).every(k => allowed.split(" ").includes(k));
const EVENT_KEYS = "t e p k src dst intent ok reason goal score observed_ms decided_ms execute_ms sim_ms tick lane_id policy style tier seed cooldown_ms sloppy id scope target impact_hd impact_ul plan_goal plan_source plan_target plan_reason";
const PROFILE_KEYS = "seat style tier policy aggression think_interval_ms think_jitter_ms opening_delay_ms notice_delay_ms motor_delay_ms global_intent_cooldown_ms human_behavior_enabled";
const META_KEYS = "map_id map_path map_sha256 mode match_type start_utc_ms config_version config_hash local_seat bot_seed shared_match_key end_reason";

export function decodeCapture(body: Buffer): Record<string, any> {
  let value: unknown;
  try { value = JSON.parse(gunzipSync(body, { maxOutputLength: MAX_CAPTURE_BYTES }).toString("utf8")); }
  catch { return fail("invalid_capture_gzip"); }
  if (!record(value) || !keys(value, "schema_version capture_id owner_key build source_sha256 engine platform status sim_ms winner_seat metadata players profiles events frames metrics dropped_events frame_stride") ||
      value.schema_version !== 1 || !/^[a-f0-9]{32}$/.test(String(value.capture_id)) ||
      !/^[a-f0-9]{64}$/.test(String(value.owner_key)) || !token(value.build, 80) || !value.build ||
      !/^[a-f0-9]{64}$/.test(String(value.source_sha256)) || !token(value.engine, 80) || !token(value.platform, 40) ||
      !["completed", "abandoned", "interrupted"].includes(String(value.status)) ||
      !Number.isSafeInteger(value.sim_ms) || Number(value.sim_ms) < 0 || Number(value.sim_ms) > 86400000 ||
      !Number.isInteger(value.winner_seat) || Number(value.winner_seat) < 0 || Number(value.winner_seat) > 4 ||
      !Number.isInteger(value.dropped_events) || Number(value.dropped_events) < 0 ||
      !Number.isInteger(value.frame_stride) || Number(value.frame_stride) < 1) fail("invalid_capture_header");
  if (!record(value.metadata) || !keys(value.metadata, META_KEYS) ||
      !Object.values(value.metadata).every(v => number(v) || token(v)) ||
      !token(value.metadata.map_id) || !token(value.metadata.mode)) fail("invalid_capture_metadata");
  for (const [field, allowed, maximum] of [["events", EVENT_KEYS, 20000], ["profiles", PROFILE_KEYS, 4],
    ["players", "seat is_cpu is_local bot_style bot_tier", 4]] as const) {
    const rows = value[field];
    if (!Array.isArray(rows) || rows.length > maximum || !rows.every(row => record(row) && keys(row, allowed) &&
      Object.values(row).every(v => number(v) || typeof v === "boolean" || token(v)))) fail(`invalid_capture_${field}`);
  }
  if (!Array.isArray(value.frames) || value.frames.length > 3601 || !value.frames.every(frame =>
    record(frame) && keys(frame, "t h l") && number(frame.t) && ["h", "l"].every(key =>
      Array.isArray(frame[key]) && frame[key].length <= 4096 && frame[key].every((row: unknown) =>
        Array.isArray(row) && row.length <= 8 && row.every(number))))) fail("invalid_capture_frames");
  if (!record(value.metrics) || !keys(value.metrics, "players won_match_by_player total_units_produced_by_player total_units_lost_by_player total_swarms_sent_by_player meaningful_actions_by_player hive_damage_dealt_by_player hives_captured_by_player lane_budget_utilization_pct_by_player production_idle_time_s_by_player") ||
      !Object.values(value.metrics).every(row => Array.isArray(row) && row.length <= 4 && row.every(number))) fail("invalid_capture_metrics");
  return value;
}

export function installBetaCaptureRoutes(app: Express, pool: Pool, tokenConfig: PlayerTokenKeyConfig,
  adminAuth: RequestHandler, enabled: () => boolean = () => process.env.SF_BETA_CAPTURE_ENABLED === "true"): void {
  const active = new AccountDeletionStore(pool);
  const route = (fn: (req: express.Request, res: express.Response) => Promise<void>): RequestHandler =>
    (req, res) => {
      res.setHeader("Cache-Control", "no-store");
      void fn(req, res).catch(error => {
        if (error instanceof IdentitySessionError) res.status(error.status).json({ ok: false, err: error.code });
        else if (error instanceof PlayerTokenError) res.status(401).json({ ok: false, err: error.code });
        else res.status(503).json({ ok: false, err: "capture_unavailable" });
      });
    };
  // Register ahead of the service's general JSON parser. Authenticate before decompression.
  app.post("/v1/beta-captures", route(async (req, res) => {
    if (!enabled()) fail("capture_disabled", 503);
    const claims = verifyPlayerAccessToken(bearerTokenFromHeader(req.header("authorization")), tokenConfig);
    await active.assertActiveSession(claims);
    const readBody = express.raw({ type: "application/gzip", limit: "2mb", inflate: false });
    await new Promise<void>((resolve, reject) => readBody(req, res, err => err ? reject(err) : resolve()));
    if (!Buffer.isBuffer(req.body)) fail("gzip_body_required");
    const body = req.body as Buffer;
    const digest = hash(body);
    if (req.header("x-capture-sha256") !== digest) fail("capture_hash_mismatch");
    const capture = decodeCapture(body);
    if (capture.owner_key !== participantKey(claims.sub)) fail("capture_owner_mismatch", 403);
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      // Same deletion/Rank lock: a concurrent deletion cannot race a new archive insert.
      await client.query("SELECT pg_advisory_xact_lock($1)", [934_771_112]);
      await new AccountDeletionStore(client as unknown as Pool).assertActiveSession(claims);
      await client.query(`INSERT INTO sf_beta_participants(player_id, participant_key) VALUES ($1, $2)
        ON CONFLICT (player_id) DO NOTHING`, [claims.sub, capture.owner_key]);
      const existing = await client.query("SELECT sha256 FROM sf_beta_captures WHERE player_id=$1 AND capture_id=$2",
        [claims.sub, capture.capture_id]);
      if (existing.rows.length && existing.rows[0].sha256 !== digest) fail("capture_id_conflict", 409);
      if (!existing.rows.length) {
        const usage = await client.query(`SELECT count(*)::int AS count, coalesce(sum(octet_length(payload_gzip)),0)::bigint AS bytes
          FROM sf_beta_captures WHERE player_id=$1 AND received_at > now() - interval '1 day'`, [claims.sub]);
        if (usage.rows[0].count >= 500 || Number(usage.rows[0].bytes) + body.length > 128 * 1024 * 1024) fail("capture_daily_limit", 429);
        await client.query(`INSERT INTO sf_beta_captures(player_id,capture_id,build,map_id,mode,status,sim_ms,winner_seat,sha256,summary,payload_gzip)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11)`, [claims.sub, capture.capture_id, capture.build,
          capture.metadata.map_id, capture.metadata.mode, capture.status, capture.sim_ms, capture.winner_seat, digest,
          JSON.stringify({ players: capture.players, profiles: capture.profiles, source_sha256: capture.source_sha256,
            metrics: capture.metrics, local_seat: capture.metadata.local_seat, events: capture.events.length, frames: capture.frames.length, dropped_events: capture.dropped_events,
            frame_stride: capture.frame_stride }), body]);
      }
      await client.query("COMMIT");
      res.json({ ok: true, capture_id: capture.capture_id, sha256: digest, duplicate: !!existing.rows.length });
    } catch (error) { await client.query("ROLLBACK"); throw error; }
    finally { client.release(); }
  }));
  app.get("/v1/admin/beta-captures", adminAuth, route(async (req, res) => {
    const after = String(req.query.after || "0");
    if (!/^\d{1,18}$/.test(after)) fail("invalid_cursor");
    const result = await pool.query(`SELECT c.id::text, c.capture_id, p.participant_key, p.cohort, c.received_at,
      c.build,c.map_id,c.mode,c.status,c.sim_ms,c.winner_seat,c.sha256,c.summary
      FROM sf_beta_captures c JOIN sf_beta_participants p USING(player_id)
      WHERE c.id > $1::bigint ORDER BY c.id LIMIT 100`, [after]);
    res.json({ ok: true, captures: result.rows, next: result.rows.at(-1)?.id || after });
  }));
  app.get("/v1/admin/beta-captures/:id", adminAuth, route(async (req, res) => {
    if (!/^\d{1,18}$/.test(req.params.id)) fail("invalid_capture_id");
    const result = await pool.query("SELECT payload_gzip,sha256 FROM sf_beta_captures WHERE id=$1", [req.params.id]);
    if (!result.rows.length) fail("capture_not_found", 404);
    res.setHeader("Content-Type", "application/gzip");
    res.setHeader("X-Capture-SHA256", result.rows[0].sha256);
    res.send(Buffer.from(result.rows[0].payload_gzip));
  }));
  app.put("/v1/admin/beta-participants/:key", adminAuth, express.json({ limit: "1kb" }), route(async (req, res) => {
    if (!/^[a-f0-9]{64}$/.test(req.params.key) || !["unknown", "owner", "new", "intermediate", "experienced"].includes(req.body?.cohort)) fail("invalid_cohort");
    const result = await pool.query("UPDATE sf_beta_participants SET cohort=$1 WHERE participant_key=$2 RETURNING participant_key,cohort", [req.body.cohort, req.params.key]);
    if (!result.rows.length) fail("participant_not_found", 404);
    res.json({ ok: true, participant: result.rows[0] });
  }));
}
